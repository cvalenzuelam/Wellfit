-- MyWallet — STAGE DB checks (Release 9.6)
-- Azure Data Studio: pick DB = Wallet (no USE/GO)
-- Server: stage-platform-wellfit-sqlserver.database.windows.net

-- DB dropdown: Wallet
-- Server: stage-platform-wellfit-sqlserver.database.windows.net
-- Tables known (names only): dbo.Wallet, dbo.Token, dbo.TokenPurgeLog
-- Columns: use SELECT * until schema-verified dump is pasted

SELECT DB_NAME() AS DbName;

SELECT *
FROM [dbo].[Wallet]
WHERE Id = '<walletId>'
   OR UserId = '<userId>';

SELECT *
FROM [dbo].[Token]
WHERE WalletId = '<walletId>'
   OR Id = '<tokenId>';

-- Optional audit / purge
SELECT TOP 50 *
FROM [dbo].[TokenPurgeLog]
WHERE TokenId = '<tokenId>'
   OR WalletId = '<walletId>'
ORDER BY 1 DESC;


-- DB dropdown: Wallet
-- After delete: token should be gone OR marked inactive / present in TokenPurgeLog

SELECT *
FROM [dbo].[Token]
WHERE Id = '<tokenId>'
   OR WalletId = '<walletId>';

SELECT TOP 50 *
FROM [dbo].[TokenPurgeLog]
WHERE TokenId = '<tokenId>'
   OR WalletId = '<walletId>'
ORDER BY 1 DESC;


-- DB dropdown: Wallet
SELECT DB_NAME() AS DbName;

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME IN ('Wallet', 'Token', 'TokenPurgeLog')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Wallet'
ORDER BY ORDINAL_POSITION;

SELECT COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Token'
ORDER BY ORDINAL_POSITION;

