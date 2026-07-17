-- PAY-4087 — verify ACH TokenId persisted to Platform + matches TokenVault
-- Server: stage-platform-wellfit-sqlserver.database.windows.net
-- Azure Data Studio: pick DB in dropdown (no USE / GO)
--
-- After Postman folder 1 (raw ACH): wait ~30–60s for Platform sync, then run.
-- Replace @OrderId / @TransactionId / @TokenId with values from Postman env.

-- =============================================================================
-- A) Platform DB — charge row must have Token = vault GUID (AC-2 / AC-3)
-- Dropdown: Platform
-- =============================================================================

DECLARE @OrderId       nvarchar(100) = N'QA-PAY4087-RAW-REPLACE';  -- env orderId
DECLARE @TransactionId nvarchar(50)  = N'REPLACE';                 -- env transactionId (optional)
DECLARE @TokenId       uniqueidentifier = NULL;                    -- env achTokenId (optional filter)

SELECT TOP 20
    p.Id,
    p.TimeStamp,
    p.Amount,
    p.OrderId,
    p.TransactionId,
    p.ResponseCode,
    p.ResponseMessage,
    p.Token,
    p.ApprovalNumber,
    p.PaymentType,
    p.PaymentTypeMethod
FROM [Payments].[Payments] p
WHERE
    (@OrderId IS NOT NULL AND p.OrderId = @OrderId)
    OR (@TransactionId IS NOT NULL AND p.TransactionId = @TransactionId)
    OR (@TokenId IS NOT NULL AND p.Token = CONVERT(nvarchar(50), @TokenId))
ORDER BY p.TimeStamp DESC;

-- Expect: Token IS NOT NULL and equals Postman achTokenId (GUID string).

-- =============================================================================
-- B) TokenVault DB — same GUID must exist as Active bank token (AC-3)
-- Dropdown: TokenVault
-- =============================================================================

-- Paste Postman achTokenId into @VaultTokenId (TokenVault session is separate from Platform).
DECLARE @VaultTokenId uniqueidentifier = '00000000-0000-0000-0000-000000000000'; -- replace

SELECT
    t.Id,
    t.Status,
    t.RoutingNumber,
    t.AccountType,
    t.CreatedAt,
    t.UpdatedAt,
    t.DeactivatedAt,
    t.DeactivationReason
FROM [dbo].[BankAccountTokens] t
WHERE t.Id = @VaultTokenId;

-- Expect: 1 row, Status = Active, Id = Platform.Token from query A.
