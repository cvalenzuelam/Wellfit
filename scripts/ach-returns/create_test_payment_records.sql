-- Path: c:\Source\Wellfit\Database\Platform\Platform\Payments
-- Define specific GUIDs for testing
DECLARE @PaymentId UNIQUEIDENTIFIER = '12345678-1234-1234-1234-123456789ABC';
DECLARE @AchDetailsId UNIQUEIDENTIFIER = '98765432-9876-9876-9876-987654321DEF';
DECLARE @SubMerchantAccountId UNIQUEIDENTIFIER = '12032023-AAAA-BBBB-CCCC-000000000001';

-- SELECTS to View
SELECT * FROM [Payments].[Payments] WHERE Id IN (@PaymentId)
SELECT * FROM [Payments].[AchPaymentDetails] WHERE PaymentId IN (@PaymentId)
SELECT * FROM [Payments].[ReturnedPayments] WHERE OriginalPaymentId IN (@PaymentId)
SELECT * FROM [Payments].[SubMerchantAccounts] WHERE Id IN (@SubMerchantAccountId)

-- Cleanup existing records if they exist
DELETE FROM [Payments].[ReturnedPayments] WHERE OriginalPaymentId IN (@PaymentId);
DELETE FROM [Payments].[AchPaymentDetails] WHERE PaymentId IN (@PaymentId);
DELETE FROM [Payments].[Payments] WHERE Id IN (@PaymentId);



IF EXISTS (SELECT 1 FROM [Payments].[AchPaymentDetails] WHERE [PaymentId] = @PaymentId)
BEGIN
    DELETE FROM [Payments].[AchPaymentDetails] WHERE [PaymentId] = @PaymentId;
END

IF EXISTS (SELECT 1 FROM [Payments].[Payments] WHERE [Id] = @PaymentId)
BEGIN
    DELETE FROM [Payments].[Payments] WHERE [Id] = @PaymentId;
END

-- Insert into Payments.Payments
INSERT INTO [Payments].[Payments]
(
    [Id],
    [TimeStamp],
    [SubMerchantAccountId],
    [Amount],
    [PayFacFee],
    [PaymentType],
    [AccountSuffix],
    [OrderId],
    [OrderIdType],
    [TransactionId],
    [ResponseCode],
    [ResponseMessage],
    [Token],
    [SettlementDate],
    [Voided],
    [PaymentTypeMethod],
    [ApprovalNumber]
)
VALUES
(
    @PaymentId,                          -- Id
    SYSDATETIMEOFFSET(),                -- TimeStamp
    @SubMerchantAccountId,              -- SubMerchantAccountId
    100.00,                             -- Amount
    2.50,                               -- PayFacFee
    'ACH',                              -- PaymentType
    '1234',                             -- AccountSuffix
    'ORDER-TEST-001',                   -- OrderId
    'STANDARD',                         -- OrderIdType
    '83997656989609888',               -- TransactionId (numeric value for LONG casting)
    '000',                              -- ResponseCode
    'Approved',                         -- ResponseMessage
    'TKN-TEST-001-ACHK',               -- Token
    NULL,                               -- SettlementDate
    0,                                  -- Voided
    0,                                  -- PaymentTypeMethod
    '123456'                           -- ApprovalNumber
);

-- Insert into Payments.AchPaymentDetails
INSERT INTO [Payments].[AchPaymentDetails]
(
    [Id],
    [PaymentId],
    [AccountType],
    [SecCode]
)
VALUES
(
    @AchDetailsId,                      -- Id
    @PaymentId,                         -- PaymentId
    'CHECKING',                         -- AccountType
    'PPD'                              -- SecCode
);

-- Verify the insertions
SELECT 'Payment Record' AS RecordType, * FROM [Payments].[Payments] WHERE [Id] = @PaymentId;
SELECT 'ACH Details' AS RecordType, * FROM [Payments].[AchPaymentDetails] WHERE [PaymentId] = @PaymentId;
