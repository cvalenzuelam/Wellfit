-- 9.6 CNP regression — Platform DB checks (STAGE)
-- Pick database: Platform
-- Replace TransactionId values from Postman env after each run.

-- TC: Amount + PaymentTypeMethod on charge
-- PaymentTypeMethod: 2 = CNP token, 1 = Pay Page
SELECT Id, TransactionId, Amount, PaymentTypeMethod, OrderId, ResponseCode, TimeStamp
FROM [Payments].[Payments]
WHERE TransactionId = '<lastTransactionId>';

-- TC: Partial refund row
SELECT r.Id, r.TransactionId, r.Amount, r.OrderId, r.OriginalPaymentId, r.TimeStamp
FROM [Payments].[Refunds] r
INNER JOIN [Payments].[Payments] p ON p.Id = r.OriginalPaymentId
WHERE p.TransactionId = '<refundOriginalTransactionId>'
ORDER BY r.TimeStamp DESC;

-- TC: Void row
SELECT v.Id, v.TransactionId, v.OrderId, v.OriginalPaymentId, v.TimeStamp
FROM [Payments].[Voids] v
INNER JOIN [Payments].[Payments] p ON p.Id = v.OriginalPaymentId
WHERE p.TransactionId = '<voidOriginalTransactionId>'
ORDER BY v.TimeStamp DESC;

-- Optional: find ProcessorTokens for env tokenVisa / tokenAmex / ...
-- (DB name may be Platform or Payments — confirm PaymentTokens location on STAGE)
-- SELECT TOP 20 * FROM [Payments].[PaymentTokens] ORDER BY 1 DESC;
