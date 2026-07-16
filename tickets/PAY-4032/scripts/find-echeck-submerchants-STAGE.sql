-- PAY-4032 — find SubMerchants + AccountId for Worldpay Wrapper eCheck sale
-- DB: Platform @ stage-platform-wellfit-sqlserver.database.windows.net
--
-- Brett (2026-07-14) + BMAD PAY-4046:
--   Postman accountId     = [Payments].[SubMerchantAccounts].AccountId  WHERE ProcessorId = 0
--   Postman subMerchantId = [Payments].[SubMerchants].Id (GUID)
--   Shared cert AccountId (lower envs) for ProcessorId 0 = '01334267'
--   DEV example Brett gave: SubMerchantId 2e390000-8d7e-7ced-cade-08debd891c22 / AccountId 01334267
--
-- NOT Azure processor__vantiv__merchantId (01264096) — that is payfac/env config, not the request AccountId.

------------------------------------------------------------
-- A) Known-good CNP cert merchants (PAY-4046 QA query) — use these first
------------------------------------------------------------
SELECT
    sm.Id            AS SubMerchantId,          -- ← Postman {{subMerchantId}}
    sm.SubMerchantName,
    a.ProcessorId,
    CASE a.ProcessorId
        WHEN 0 THEN 'CNP (Worldpay eCommerce)'
        WHEN 1 THEN 'CP  (Worldpay Cloud/device)'
    END              AS Rail,
    a.AccountId,                                -- ← Postman {{accountId}}
    a.AccountState
FROM [Payments].[SubMerchants] AS sm
INNER JOIN [Payments].[SubMerchantAccounts] AS a
    ON a.SubMerchantId = sm.Id
   AND a.AccountState = 2                       -- Enabled
   AND (
        (a.ProcessorId = 0 AND a.AccountId = '01334267'
         AND NOT EXISTS (
             SELECT 1 FROM [Payments].[SubMerchantAccounts] ch
             WHERE ch.SubMerchantId = sm.Id
               AND ch.ProcessorId = 2
               AND ch.AccountState = 2
         ))
     OR (a.ProcessorId = 1 AND a.AccountId = '874767928')
   )
WHERE sm.Enabled = 1
ORDER BY sm.SubMerchantName, a.ProcessorId;

------------------------------------------------------------
-- B) Brett DEV pair — does it exist on this env?
------------------------------------------------------------
SELECT
    sm.Id AS SubMerchantId,
    sm.SubMerchantName,
    sm.Enabled,
    a.Id AS SubMerchantAccountRowId,
    a.ProcessorId,
    a.AccountId,
    a.AccountState
FROM [Payments].[SubMerchants] AS sm
LEFT JOIN [Payments].[SubMerchantAccounts] AS a
    ON a.SubMerchantId = sm.Id
WHERE sm.Id = '2e390000-8d7e-7ced-cade-08debd891c22';

------------------------------------------------------------
-- C) Any ProcessorId 0 row for a specific SubMerchant (swap GUID)
------------------------------------------------------------
-- SELECT sm.Id, sm.SubMerchantName, a.ProcessorId, a.AccountId, a.AccountState
-- FROM [Payments].[SubMerchants] sm
-- INNER JOIN [Payments].[SubMerchantAccounts] a ON a.SubMerchantId = sm.Id
-- WHERE sm.Id = '<guid>'
-- ORDER BY a.ProcessorId;
