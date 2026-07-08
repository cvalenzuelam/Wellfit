/* ============================================================================
   inject-ach-return.sql  —  ACH Return test-data fixture (script variant)
   ----------------------------------------------------------------------------
   Feature : ach-reporting fixture (bmad #2929) · exercises the ACH Returns
             ingest chain (ach-returns-microservice ReturnReportIngestedMessageHandler)
   DB      : Platform  (schema [Payments])
   Purpose : Anchor a pending ACH return to an EXISTING live '000' ACH payment
             already in the environment so that, when Payment.ReturnReport.Ingested
             is delivered, the handler matches it to that live charge and transitions
             ReturnedPayments.ProcessingStatus (0 -> 1 Processed, or -> 3 NeedsReview).
             NO charge is created — the anchor is a real, settled payment.

   Match contract (verified ReturnReportIngestedMessageHandler / ReturnedPaymentRepository):
     - handler reads ReturnedPayments WHERE TimeStamp >= (event.ProcessedAt - 5 min)
       AND IsPending() (ProcessingStatus NULL or 0)
     - charge lookup: ReturnedPayments.ProcessorTransactionId = Payments.Payments.TransactionId
       AND Payments.ResponseCode = '000'
   So this anchors the ReturnedPayment to an existing live charge via TransactionId.

   ANCHOR SELECTION
     - @PaymentId NULL (default): auto-select the most-recent eligible live ACH '000'
       payment that has no existing ReturnedPayment.
     - @PaymentId explicit: anchor that specific payment (must be eligible).
     Eligibility: ResponseCode='000', has AchPaymentDetails, LEN(TransactionId)<=20
     (ReturnedPayments.ProcessorTransactionId is nvarchar(20), so a longer
     TransactionId would silently fail the match), and no existing ReturnedPayment.

   USAGE  (run against the Platform DB)
     - @Commit = 0 (default): DRY RUN — preview rows, then ROLLBACK.
     - @Commit = 1: COMMIT.
   After committing, POST Payment.ReturnReport.Ingested within 5 min — see README.
   Local-only note: in prod Platform & Payments are separate Azure SQL DBs (no cross-DB);
   the anchor lives in Platform, so this script is single-DB and self-contained.
   Caveat: rollback is only meaningful BEFORE the event is delivered — once the handler
   has processed the row, downstream writes (status, redeposit attempts, published event)
   do not unwind.
   ============================================================================ */

SET NOCOUNT ON;
SET XACT_ABORT ON;

------------------------------------------------------------------------------
-- Parameters
------------------------------------------------------------------------------
DECLARE @Commit          BIT              = 0;          -- 0 = dry-run + rollback, 1 = commit
DECLARE @PaymentId       UNIQUEIDENTIFIER = NULL;       -- *** INPUT: NULL = auto-select most-recent eligible; explicit = anchor that one ***
DECLARE @ReasonCode      NVARCHAR(10)     = N'R01';     -- *** INPUT: NACHA return code *** (R01 NSF / R02 acct closed /
                                                        -- R03 no acct / R04 invalid acct / R05 unauth debit / R10 not authorized /
                                                        -- R16 frozen / R20 non-tx acct / R29 corp not authorized — full list below).
DECLARE @Amount          DECIMAL(18,2)    = NULL;       -- *** INPUT: NULL = use the anchor payment's Amount; non-NULL = partial-return override ***

DECLARE @Now             DATETIMEOFFSET(7) = SYSUTCDATETIME();
DECLARE @Today           DATE             = CAST(SYSUTCDATETIME() AS DATE);
DECLARE @ReturnId        UNIQUEIDENTIFIER = NEWID();
DECLARE @TransactionId   NVARCHAR(40)     = NULL;       -- resolved from the anchor payment
DECLARE @AnchorAmount    DECIMAL(18,2)    = NULL;       -- resolved from the anchor payment

-- Resolve the NACHA return description from the input @ReasonCode (canonical NACHA wording).
-- Validates the code in one place so a typo fails fast instead of seeding a bogus reason.
DECLARE @ReasonDesc NVARCHAR(200);
SELECT @ReasonDesc = d FROM (VALUES
    (N'R01', N'Insufficient Funds'),
    (N'R02', N'Account Closed'),
    (N'R03', N'No Account / Unable to Locate Account'),
    (N'R04', N'Invalid Account Number'),
    (N'R05', N'Unauthorized Debit to Consumer Account'),
    (N'R06', N'Returned per ODFI Request'),
    (N'R07', N'Authorization Revoked by Customer'),
    (N'R08', N'Payment Stopped'),
    (N'R09', N'Uncollected Funds'),
    (N'R10', N'Customer Advises Not Authorized'),
    (N'R11', N'Customer Advises Entry Not in Accordance with Terms'),
    (N'R12', N'Branch Sold to Another DFI'),
    (N'R16', N'Account Frozen'),
    (N'R20', N'Non-Transaction Account'),
    (N'R29', N'Corporate Customer Advises Not Authorized')
) AS nacha(c, d) WHERE c = @ReasonCode;
IF @ReasonDesc IS NULL
BEGIN
    RAISERROR(N'Unknown NACHA return code ''%s''. Use a supported R-code (see the lookup in this script).', 16, 1, @ReasonCode);
    RETURN;
END;

------------------------------------------------------------------------------
-- Anchor to an EXISTING live ACH '000' payment (no charge is created).
-- Eligible = settled ACH ('000' + AchPaymentDetails), TransactionId fits the
-- nvarchar(20) match column, and no ReturnedPayment already points at it.
------------------------------------------------------------------------------
SELECT TOP 1
    @PaymentId     = p.[Id],
    @TransactionId = p.[TransactionId],
    @AnchorAmount  = p.[Amount]
FROM [Payments].[Payments] p
JOIN [Payments].[AchPaymentDetails] apd ON apd.[PaymentId] = p.[Id]
WHERE p.[ResponseCode] = '000'
  AND LEN(p.[TransactionId]) <= 20
  AND NOT EXISTS (SELECT 1 FROM [Payments].[ReturnedPayments] rp WHERE rp.[OriginalPaymentId] = p.[Id])
  AND (@PaymentId IS NULL OR p.[Id] = @PaymentId)
ORDER BY p.[TimeStamp] DESC;

IF @PaymentId IS NULL OR @TransactionId IS NULL
BEGIN
    RAISERROR(N'No eligible live ACH ''000'' payment without an existing return was found (TransactionId must be <=20 chars). If @PaymentId was supplied, it is missing, ineligible, or already returned.', 16, 1);
    RETURN;
END;

BEGIN TRAN;

    -- Anchor the ReturnedPayment to the existing payment (pending; ProcessorTransactionId = anchor TransactionId).
    INSERT INTO [Payments].[ReturnedPayments]
        ([Id],[TimeStamp],[CaseId],[DateIssued],[Amount],[ReasonCode],[ReasonDescription],
         [OriginalPaymentId],[SettlementDate],[ProcessorTransactionId],[ProcessingStatus])
    VALUES
        (@ReturnId, @Now, N'QAFIX-' + FORMAT(SYSUTCDATETIME(),'yyyyMMddHHmmss'), @Today, COALESCE(@Amount, @AnchorAmount),
         @ReasonCode, @ReasonDesc, @PaymentId, @Today, @TransactionId, 0 /* pending */);

    -- Preview: the anchored existing payment (read-only) and the inserted ReturnedPayment.
    SELECT N'anchored-existing-payment' AS [marker], p.[Id], p.[TransactionId], p.[Amount], p.[ResponseCode]
    FROM [Payments].[Payments] p WHERE p.[Id] = @PaymentId;

    SELECT N'inserted-returnedpayment' AS [marker], * FROM [Payments].[ReturnedPayments] WHERE [Id] = @ReturnId;

IF @Commit = 1
BEGIN
    COMMIT;
    PRINT N'COMMITTED return fixture: ReturnedPayment ' + CONVERT(NVARCHAR(36),@ReturnId)
        + N' (pending), anchored to existing payment ' + CONVERT(NVARCHAR(36),@PaymentId)
        + N' via TransactionId ' + @TransactionId + N'. Deliver Payment.ReturnReport.Ingested within 5 min — see README.';
END
ELSE
BEGIN
    ROLLBACK;
    PRINT N'DRY RUN (rolled back). Set @Commit = 1 to persist.';
END;
