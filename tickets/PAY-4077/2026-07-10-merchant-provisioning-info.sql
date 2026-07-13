/*
Search for SubMerchant - Use name partial and manually select - this will drive the find
SELECT *
	FROM Payments.SubMerchants
	WHERE SubMerchantName LIKE '%North Seattle%'
SELECT *
	FROM MerchantProvisioning.ProvisionedSubMerchants
	WHERE Metadata LIKE '%North Seattle%'
Can select an office number for Sync - from running list below - grab from SubMerchants row
SELECT * 
	FROM Payments.OrganizationDetails
	WHERE ID = '1D550000-3A34-000D-889B-08D43C1753A8'
SELECT OfficeNumber, *
	FROM dbo.Practices
	WHERE OrganizationId = '5068093D-AA1F-41F8-AC42-1FC85A92B766'
*/
-- 'FB780000-8D3B-7CED-D634-08DEC656649C' Face
-- 'C6A80000-A5AE-70A8-4F51-08DEC7D901E4' Pickle
-- place subMerchantId here 
DECLARE @subMerchantId UNIQUEIDENTIFIER = 'ff890000-523e-7c1e-07e4-08dedeb0a78e' -- set SubMerchantId
DECLARE @deleteMerchantProvisioningData BIT = 0; -- Change to 1 to allow delete AND comment out the BEGIN TRANSACTION; and ROLLBACK TRANSACTION; in the DELETE section

--- gets ---

DECLARE @provisionedSubMerchantId UNIQUEIDENTIFIER; -- get ProvisionedSubMerchantId
SELECT @provisionedSubMerchantId = ProvisionedSubMerchantId
	FROM Payments.SubMerchants 
	WHERE Id = @subMerchantId

DECLARE @provisionedLegalEntityId UNIQUEIDENTIFIER; -- get ProvisionedLegalEntityId
DECLARE @subMerchantDetailId UNIQUEIDENTIFIER; -- get SubMerchantDetailId
SELECT @provisionedLegalEntityId = ProvisionedLegalEntityId, @subMerchantDetailId = SubMerchantDetailId
	FROM MerchantProvisioning.ProvisionedSubMerchants
	WHERE Id = @provisionedSubMerchantId

DECLARE @legalEntityDetailId UNIQUEIDENTIFIER;
SELECT @legalEntityDetailId = LegalEntityDetailId -- get LegalEntityDetailId
	FROM MerchantProvisioning.ProvisionedLegalEntities
	WHERE Id = @provisionedLegalEntityId;

--- list ---

SELECT 'ProvisionedLegalEntities' AS ProvisionedLegalEntities, * -- list ProvisionedLegalEntities
	FROM MerchantProvisioning.ProvisionedLegalEntities
	WHERE Id = @provisionedLegalEntityId;

SELECT 'LegalEntityDetails' AS LegalEntityDetails, * 
	FROM MerchantProvisioning.LegalEntityDetails LED
		INNER JOIN MerchantProvisioning.AddressDetails AD ON LED.AddressDetailId = AD.Id
	WHERE LED.Id = @legalEntityDetailId;

SELECT 'PrincipalDetails' AS PrincipalDetails,* 
	FROM MerchantProvisioning.PrincipalDetails PD
		INNER JOIN MerchantProvisioning.AddressDetails AD ON PD.AddressDetailId = AD.Id
		INNER JOIN MerchantProvisioning.PersonDetails PED ON PD.PersonDetailId = PED.Id
	WHERE PD.LegalEntityDetailId = @legalEntityDetailId;

SELECT 'ProvisionedLegalEntityProviders' AS ProvisionedLegalEntityProviders, * 
	FROM MerchantProvisioning.ProvisionedLegalEntityProviders
	WHERE ProvisionedLegalEntityId = @provisionedLegalEntityId;;

SELECT 'ProvisionedSubMerchants' AS ProvisionedSubMerchants, * -- list ProvisionedSubMerchants
	FROM MerchantProvisioning.ProvisionedSubMerchants
	WHERE Id = @provisionedSubMerchantId;

SELECT 'SubMerchantDetails' AS SubMerchantDetails, * 
	FROM MerchantProvisioning.SubMerchantDetails SMD
		INNER JOIN MerchantProvisioning.AddressDetails AD ON SMD.AddressDetailId = AD.Id
		INNER JOIN MerchantProvisioning.PersonDetails PED ON SMD.PersonDetailId = PED.Id
		INNER JOIN MerchantProvisioning.ECheckDetails ECD ON SMD.ECheckDetailId = ECD.Id
	WHERE SMD.Id = @subMerchantDetailId;

SELECT 'ProvisionedSubMerchantProviders' AS ProvisionedSubMerchantProviders, * 
	FROM MerchantProvisioning.ProvisionedSubMerchantProviders
	WHERE ProvisionedSubMerchantId = @provisionedSubMerchantId;

SELECT 'SubMerchants' AS SubMerchants, *
	FROM Payments.SubMerchants SM
		INNER JOIN Payments.BankAccounts BA ON SM.BankAccountId = BA.Id
		INNER JOIN Payments.OrganizationDetails OD ON SM.OrganizationDetailId = OD.Id
		INNER JOIN dbo.Organizations O ON OD.OrganizationId = O.Id
	WHERE SM.Id = @subMerchantId;

SELECT 'SubMerchantAccounts' AS SubMerchantAccounts, *
	FROM Payments.SubMerchantAccounts
	WHERE SubMerchantId = @subMerchantId;

IF (@deleteMerchantProvisioningData = 1)
BEGIN
	BEGIN TRANSACTION;

		PRINT ''
		PRINT '--- DELETE ---'

		SELECT * 
			INTO #tempPersonDetailIds
			FROM (
				SELECT PersonDetailId FROM MerchantProvisioning.SubMerchantDetails WHERE Id = @subMerchantDetailId
				UNION
				SELECT PersonDetailId FROM MerchantProvisioning.PrincipalDetails WHERE LegalEntityDetailId = @legalEntityDetailId) AS PD;

		SELECT * 
			INTO #tempAddressDetailIds
			FROM (SELECT AddressDetailId FROM MerchantProvisioning.LegalEntityDetails WHERE Id = @legalEntityDetailId
				UNION 
				SELECT AddressDetailId FROM MerchantProvisioning.SubMerchantDetails WHERE Id = @subMerchantDetailId
				UNION
				SELECT AddressDetailId FROM MerchantProvisioning.PrincipalDetails WHERE LegalEntityDetailId = @legalEntityDetailId) AS PD;

		DELETE FROM MerchantProvisioning.PrincipalDetails -- delete PrincipalDetails
			WHERE LegalEntityDetailId = @legalEntityDetailId;

		DELETE FROM MerchantProvisioning.LegalEntityDetails -- delete LegalEntityDetails
			WHERE Id = @legalEntityDetailId;

		DELETE FROM MerchantProvisioning.SubMerchantDetails -- delete SubMerchantDetails
			WHERE Id = @subMerchantDetailId;

		DELETE FROM MerchantProvisioning.ProvisionedLegalEntityProviders -- delete ProvisionedLegalEntityProviders
			WHERE ProvisionedLegalEntityId = @provisionedLegalEntityId;

		DELETE FROM MerchantProvisioning.ProvisionedSubMerchantProviders -- delete ProvisionedSubMerchantProviders
			WHERE ProvisionedSubMerchantId = @provisionedSubMerchantId;

		DELETE FROM MerchantProvisioning.PersonDetails -- delete persons
			WHERE Id IN (SELECT PersonDetailId FROM #tempPersonDetailIds);

		DELETE FROM MerchantProvisioning.AddressDetails -- delete addresses
			WHERE Id IN (SELECT AddressDetailId FROM #tempAddressDetailIds);

		DELETE FROM MerchantProvisioning.ProvisionedLegalEntities
			WHERE Id = @provisionedLegalEntityId;

		UPDATE Payments.SubMerchants
		SET ProvisionedSubMerchantId = NULL
		WHERE ProvisionedSubMerchantId = @provisionedSubMerchantId;

		DELETE FROM MerchantProvisioning.ProvisionedSubMerchants
			WHERE Id = @provisionedSubMerchantId;

		DROP TABLE #tempPersonDetailIds;
		DROP TABLE #tempAddressDetailIds;

		--- check lists ---

		SELECT 'ProvisionedLegalEntities' AS ProvisionedLegalEntities, * -- list ProvisionedLegalEntities
			FROM MerchantProvisioning.ProvisionedLegalEntities
			WHERE Id = @provisionedLegalEntityId;

		SELECT 'LegalEntityDetails' AS LegalEntityDetails, * 
			FROM MerchantProvisioning.LegalEntityDetails LED
				INNER JOIN MerchantProvisioning.AddressDetails AD ON LED.AddressDetailId = AD.Id
			WHERE LED.Id = @legalEntityDetailId;

		SELECT 'PrincipalDetails' AS PrincipalDetails,* 
			FROM MerchantProvisioning.PrincipalDetails PD
				INNER JOIN MerchantProvisioning.AddressDetails AD ON PD.AddressDetailId = AD.Id
				INNER JOIN MerchantProvisioning.PersonDetails PED ON PD.PersonDetailId = PED.Id
			WHERE PD.LegalEntityDetailId = @legalEntityDetailId;

		SELECT 'ProvisionedLegalEntityProviders' AS ProvisionedLegalEntityProviders, * 
			FROM MerchantProvisioning.ProvisionedLegalEntityProviders
			WHERE ProvisionedLegalEntityId = @provisionedLegalEntityId;;

		SELECT 'ProvisionedSubMerchants' AS ProvisionedSubMerchants, * -- list ProvisionedSubMerchants
			FROM MerchantProvisioning.ProvisionedSubMerchants
			WHERE Id = @provisionedSubMerchantId;

		SELECT 'SubMerchantDetails' AS SubMerchantDetails, * 
			FROM MerchantProvisioning.SubMerchantDetails SMD
				INNER JOIN MerchantProvisioning.AddressDetails AD ON SMD.AddressDetailId = AD.Id
				INNER JOIN MerchantProvisioning.PersonDetails PED ON SMD.PersonDetailId = PED.Id
				INNER JOIN MerchantProvisioning.ECheckDetails ECD ON SMD.ECheckDetailId = ECD.Id
			WHERE SMD.Id = @subMerchantDetailId;

		SELECT 'ProvisionedSubMerchantProviders' AS ProvisionedSubMerchantProviders, * 
			FROM MerchantProvisioning.ProvisionedSubMerchantProviders
			WHERE ProvisionedSubMerchantId = @provisionedSubMerchantId;

	ROLLBACK TRANSACTION;

END