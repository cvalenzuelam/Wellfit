-- PAY-4064 — find STAGE ACH refund candidates (originals only)
-- Server: stage-platform-wellfit-sqlserver.database.windows.net
-- Select database: Payments (dropdown) — do not use master/Platform
--
-- API id = PaymentTransactionId | ACH join = pma.PaymentTransactionId = pt.Id

SELECT TOP 30
    pt.PaymentTransactionId AS ApiTransactionId,
    pt.Id AS PaymentTransactionGuid,
    pt.TransactionStatusId,
    ts.Code AS StatusCode,
    pt.TransactionTypeId,
    pt.Amount,
    pt.RailId,
    pt.ProcessorTransactionId,
    pt.ParentTransactionId,
    pt.TransactionDate,
    pt.StatusTimestamp,
    pt.SubMerchantId,
    pma.RoutingNumber,
    pma.MaskedAccountNumber
FROM [Transactions].[PaymentTransaction] pt
INNER JOIN [Transactions].[PaymentMethodACH] pma
    ON pma.PaymentTransactionId = pt.Id
LEFT JOIN [Transactions].[TransactionStatus] ts
    ON ts.Id = pt.TransactionStatusId
WHERE pt.RailId = 1                    -- ACH
  AND pt.TransactionTypeId = 1         -- DEBIT (not REFUND children)
  AND pt.TransactionStatusId IN (6, 18) -- SETTLED / PARTIALLY_REFUNDED
  AND pt.ParentTransactionId IS NULL
  AND pt.ProcessorTransactionId IS NOT NULL
ORDER BY pt.StatusTimestamp DESC;
