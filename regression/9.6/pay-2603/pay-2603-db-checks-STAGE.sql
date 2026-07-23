-- PAY-2603 — STAGE DB checks
-- Server: stage-platform-wellfit-sqlserver.database.windows.net

-- A) TokenVault — Wellfit GUID from add-token / charge
-- DB dropdown: TokenVault
SELECT Id, ProcessorToken, CardLastFour, CardBrand,
       CardExpirationMonth, CardExpirationYear, CardZipCode, EntityUpdated
FROM [dbo].[PaymentTokens]
WHERE Id = '<wellfitTokenGuid>';

-- B) Platform — CNP charge
-- DB dropdown: Platform
SELECT Id, TransactionId, Amount, PaymentTypeMethod, OrderId, Token, TimeStamp
FROM [Payments].[Payments]
WHERE TransactionId = '<lastTransactionId>';
