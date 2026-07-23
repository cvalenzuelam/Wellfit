-- Wellfit Provisioning — STAGE DB checks (Release 9.6)
-- Azure Data Studio: pick DB = Platform (no USE/GO)
-- Server: stage-platform-wellfit-sqlserver.database.windows.net

-- DB dropdown: Platform
-- After create/update — expect 1 row for this Id
SELECT *
FROM [Payments].[SubMerchants]
WHERE Id = '<wellfitSubMerchantId>';

-- Related accounts (optional)
SELECT *
FROM [Payments].[SubMerchantAccounts]
WHERE SubMerchantId = '<wellfitSubMerchantId>';

-- If MerchantCategoryCode is not on SubMerchants, check MP details:
SELECT
  sm.Id,
  sm.SubMerchantName,
  sm.ProvisionedSubMerchantId,
  psm.SubMerchantDetailId,
  smd.*
FROM [Payments].[SubMerchants] AS sm
LEFT JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
  ON sm.ProvisionedSubMerchantId = psm.Id
LEFT JOIN [MerchantProvisioning].[SubMerchantDetails] AS smd
  ON psm.SubMerchantDetailId = smd.Id
WHERE sm.Id = '<wellfitSubMerchantId>';


-- DB dropdown: Platform
-- Catalog check (TC09)
SELECT *
FROM [MerchantProvisioning].[MerchantCategoryCodes]
WHERE Code = '8021';

-- SubMerchant after create with MCC 8021
SELECT *
FROM [Payments].[SubMerchants]
WHERE Id = '<wellfitSubMerchantId>';

SELECT
  sm.Id,
  sm.SubMerchantName,
  sm.ProvisionedSubMerchantId,
  smd.*
FROM [Payments].[SubMerchants] AS sm
LEFT JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
  ON sm.ProvisionedSubMerchantId = psm.Id
LEFT JOIN [MerchantProvisioning].[SubMerchantDetails] AS smd
  ON psm.SubMerchantDetailId = smd.Id
WHERE sm.Id = '<wellfitSubMerchantId>';


-- DB dropdown: Platform
-- Run once if SELECT * / joins fail — paste results back to QA
SELECT DB_NAME() AS DbName;

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('SubMerchants', 'MerchantCategoryCodes', 'SubMerchantDetails', 'ProvisionedSubMerchants')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'Payments' AND TABLE_NAME = 'SubMerchants'
ORDER BY ORDINAL_POSITION;

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'MerchantCategoryCodes'
ORDER BY TABLE_SCHEMA, ORDINAL_POSITION;

