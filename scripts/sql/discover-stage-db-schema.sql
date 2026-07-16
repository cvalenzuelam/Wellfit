-- STAGE schema discovery — run with the target DB selected in the dropdown
-- Server: stage-platform-wellfit-sqlserver.database.windows.net
-- DBs QA cares about: Platform | Payments | TokenVault | Wallet

SELECT DB_NAME() AS current_db;

SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;
