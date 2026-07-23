-- Treasury settlement/funding — STAGE (Release 9.6)
-- Server: stage-platform-wellfit-sqlserver.database.windows.net
-- Default DB dropdown: Platform (unless noted)

-- DB dropdown: Platform
-- After charge (before funding): SettlementDate NULL, FundingInstructionId NULL (or empty)
SELECT Id, TransactionId, Amount, PayFacFee, SettlementDate, FundingInstructionId,
       ResponseCode, ResponseMessage, TimeStamp, PaymentTypeMethod
FROM [Payments].[Payments]
WHERE TransactionId = '<transactionId>';


-- DB dropdown: Platform
-- MANUAL UPDATE (run with care on STAGE). Sets SettlementDate so create-funding-batch can pick up the row.
-- Adjust date to a BUSINESS day (not Sat/Sun/holiday) if holiday case matters.

UPDATE [Payments].[Payments]
SET SettlementDate = '2026-07-23'
WHERE TransactionId = '<transactionId>';

SELECT Id, TransactionId, Amount, SettlementDate, FundingInstructionId
FROM [Payments].[Payments]
WHERE TransactionId = '<transactionId>';


-- DB dropdown: Platform
-- After create-funding-batch (~wait a few seconds): SettlementDate set, FundingInstructionId populated
SELECT Id, TransactionId, Amount, PayFacFee, SettlementDate, FundingInstructionId
FROM [Payments].[Payments]
WHERE TransactionId = '<transactionId>';

SELECT TOP 10 *
FROM [Payments].[FundingInstructions]
ORDER BY TimeStamp DESC;


-- DB dropdown: Platform
-- Correlate payment FundingInstructionId to FundingInstructions rows (FIPC / FISC etc.)
SELECT Id, TransactionId, Amount, PayFacFee, FundingInstructionId, SettlementDate
FROM [Payments].[Payments]
WHERE TransactionId = '<transactionId>';

SELECT TOP 20 *
FROM [Payments].[FundingInstructions]
ORDER BY TimeStamp DESC;


-- DB dropdown: Platform
-- After send-funding-batch: recent FundingBatches should show BatchFileName
SELECT TOP 20 Id, MerchantId, BatchFileName, RequestSentTimeStamp
FROM [Payments].[FundingBatches]
ORDER BY RequestSentTimeStamp DESC;
-- If RequestSentTimeStamp column missing, use SELECT TOP 20 * ...


-- Payments DB (ACH):
-- DB dropdown: Payments
-- ACH PM txn (ULID PaymentTransactionId). Confirm status / settlement fields per case.
SELECT TOP 20 *
FROM [Transactions].[PaymentTransaction]
ORDER BY 1 DESC;
-- Filter by PaymentTransactionId from API when known.

