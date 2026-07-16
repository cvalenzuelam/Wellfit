-- PAY-4032 — merchants that PROVED eCheck works on STAGE (approved ACH charges)
-- DB: Platform
-- Prefer these SubMerchantId values over MP ECheckDetails-only rows (those can still 330).

------------------------------------------------------------
-- B2) Recent APPROVED ACH → Postman subMerchantId candidates
------------------------------------------------------------
SELECT TOP 20
    sma.SubMerchantId,
    sm.SubMerchantName,
    COUNT(*)             AS AchApprovedCount,
    MAX(p.TimeStamp)     AS LastAchApprovedAt,
    MAX(p.TransactionId) AS SampleTxnId,
    MAX(p.Amount)        AS SampleAmount
FROM [Payments].[Payments] AS p
INNER JOIN [Payments].[AchPaymentDetails] AS apd
    ON apd.PaymentId = p.Id
INNER JOIN [Payments].[SubMerchantAccounts] AS sma
    ON sma.Id = p.SubMerchantAccountId
INNER JOIN [Payments].[SubMerchants] AS sm
    ON sm.Id = sma.SubMerchantId
WHERE p.ResponseCode = '000'
  AND p.Token IS NULL
  AND p.ApprovalNumber IS NULL
  AND p.TimeStamp >= DATEADD(DAY, -180, SYSUTCDATETIME())
GROUP BY sma.SubMerchantId, sm.SubMerchantName
ORDER BY AchApprovedCount DESC, LastAchApprovedAt DESC;

------------------------------------------------------------
-- D) Worldpay provider ids for a candidate SubMerchant
--    (if Wrapper expects WP customerId instead of Wellfit GUID)
------------------------------------------------------------
DECLARE @sm UNIQUEIDENTIFIER = 'b7711d60-dbbb-4bc1-9462-000bf1511e88'; -- Clermont Smiles (ACH 000 history, still 330 on Wrapper)

SELECT
    sm.Id AS SubMerchantId,
    sm.SubMerchantName,
    psp.*
FROM [Payments].[SubMerchants] AS sm
INNER JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON psm.Id = sm.ProvisionedSubMerchantId
INNER JOIN [MerchantProvisioning].[ProvisionedSubMerchantProviders] AS psp
    ON psp.ProvisionedSubMerchantId = psm.Id
WHERE sm.Id = @sm;
-- Look for Worldpay/Vantiv columns: MerchantId, CustomerId, PspMerchantId, ExternalId, etc.
-- If you see a numeric WP id, we can try that as Postman subMerchantId.
