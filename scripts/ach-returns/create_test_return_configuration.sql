-- Path: C:\Source\Wellfit Payments\ach-returns-microservice\AchReturns.Database
-- Creates a test return configuration record linked to the SubMerchantId from create_test_payment_records.sql

-- Define specific GUIDs for testing
DECLARE @PaymentId UNIQUEIDENTIFIER = '12345678-1234-1234-1234-123456789ABC';
DECLARE @ConfigurationId UNIQUEIDENTIFIER = '87654321-4321-4321-4321-987654321ABC';
DECLARE @SubMerchantId UNIQUEIDENTIFIER = '1D550000-3A34-000D-889B-08D43C1753A8'; -- Same as in create_test_payment_records.sql

-- SELECTS to View
SELECT * FROM [Returns].[RedepositAttempts] WHERE OriginalPaymentId IN (@PaymentId)
SELECT * FROM [Returns].[ReturnConfigurations] WHERE Id IN (@ConfigurationId)

-- Cleanup existing records
DELETE FROM [Returns].[RedepositAttempts];
DELETE FROM [Returns].[ReturnConfigurations];

-- Cleanup existing record if it exists
IF EXISTS (SELECT 1 FROM [Returns].[ReturnConfigurations] 
          WHERE [SubMerchantId] = @SubMerchantId AND [ProcessorId] = 1)
BEGIN
    DELETE FROM [Returns].[ReturnConfigurations] 
    WHERE [SubMerchantId] = @SubMerchantId AND [ProcessorId] = 1;
END

-- Insert return configuration
INSERT INTO [Returns].[ReturnConfigurations]
(
    [Id],
    [SubMerchantId],
    [ProcessorId],
    [MaxRedepositAttempts]
)
VALUES
(
    @ConfigurationId,           -- Id
    @SubMerchantId,            -- SubMerchantId
    0,                         -- ProcessorId (set in platform sql)
    2                          -- MaxRedepositAttempts (default maximum value)
);

-- Verify the insertion
SELECT 'Return Configuration' AS RecordType, * 
FROM [Returns].[ReturnConfigurations] 
WHERE [Id] = @ConfigurationId;
