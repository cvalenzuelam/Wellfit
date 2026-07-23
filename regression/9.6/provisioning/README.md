# Wellfit Provisioning — Release 9.6 STAGE

Part of collection **Regression - STAGE** (module folder **Wellfit Provisioning**).

## Import

Same as CNP / TokenVault:

1. Re-import `../Regression-STAGE/Regression-STAGE.postman_collection.json`
2. Re-import / refresh env `../Regression-STAGE/Regression-STAGE.postman_environment.json`
3. Select env **Regression STAGE**

## Testmo map (9 cases)

| Folder | Case ID | Export status |
|--------|---------|---------------|
| TC01 Auth | 18564 | Passed |
| TC02 Create submerchant | 18565 | Passed |
| TC03 Update submerchant | 18566 | Passed |
| TC04 Retrieve | 18567 | Passed |
| TC05 SQL SubMerchants | 18568 | Passed |
| TC06 GET MCC | 304279 | Passed |
| TC07 POST MCC | 304280 | **Untested** |
| TC08 DELETE MCC | 304281 | **Untested** |
| TC09 MCC 8021 on create + SQL | 304282 | **Untested** |

## Host / auth

- Base: `https://stage-wf-merchantprovisioning-api.azurewebsites.net` (`mpBaseUrl`)
- Client: `WellfitOnBoardingAPI` (`mpUsername` / `mpPassword`)
- Token env key: `mpBearerToken` (does not overwrite CNP `Payment-Bearer-Token`)

## SQL

- DB dropdown: **Platform**
- Visualize requests inside TC05 / TC09 (same pattern as TokenVault)
- Standalone script: `provisioning-db-checks-STAGE.sql`
- If joins/`MerchantCategoryCodes` fail → run discovery Visualize in TC05 and paste columns
