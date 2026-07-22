# Wellfit Provisioning

Cases: **9**

## 1. Verify that, from Wellfit Provisioning authenticate API is working 200 ok

- **Case ID:** 18564
- **Priority:** Normal
- **Status (at export):** Passed

### Description

Authenticate returns 200 OK and a valid bearer token for subsequent Provisioning API calls.
Preconditions
Stage Merchant Provisioning API is available. Valid API credentials from Postman env / internal test data.

### Expected

HTTP 200 OK. Response body includes bearerToken (non-empty). Token can be used as Authorization: Bearer {token} on protected endpoints.

### Steps

First send POST {{URL}}/authenticate with Content-Type: application/json and body username / password.
Then confirm the response status is 200 OK.
Finally verify the JSON response contains bearerToken and save it for later requests.

---

## 2. Verify that, from Wellfit Provisioning, create new submerchant API is working 200 ok

- **Case ID:** 18565
- **Priority:** Normal
- **Status (at export):** Passed

### Description

Create sub-merchant returns 200 OK and a new wellfitSubMerchantId.
Preconditions
Valid Bearer token from /authenticate. Valid create-sub-merchant payload from Postman collection (LegalEntity, SubMerchant, SubMerchantAccounts).

### Expected

HTTP 200 OK. Response includes wellfitSubMerchantId (non-empty GUID).

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send POST {{URL}}/provisioning/create-sub-merchant with Authorization: Bearer {token}, Content-Type: application/json, and a valid create payload.
Then confirm the response status is 200 OK.
Finally verify the response body contains wellfitSubMerchantId and save it for later requests.

---

## 3. Verify that, from Wellfit Provisioning collection, create update submerchant API is working 200 ok

- **Case ID:** 18566
- **Priority:** Normal
- **Status (at export):** Passed

### Description

Update sub-merchant via create-sub-merchant returns 200 OK with a valid wellfitSubMerchantId.
Preconditions
Valid Bearer token from /authenticate. Existing sub-merchant identifiers from a prior create (e.g. PspMerchantId, OrganizationId). Update payload from Postman MP update request.

### Expected

HTTP 200 OK. Response includes wellfitSubMerchantId (non-empty GUID).

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send POST {{URL}}/provisioning/create-sub-merchant with Authorization: Bearer {token}, Content-Type: application/json, and the update payload (modified LegalEntity / SubMerchant fields for an existing sub-merchant).
Then confirm the response status is 200 OK.
Finally verify the response body contains wellfitSubMerchantId.

---

## 4. Verify that, from Wellfit Provisioning collection, create read submerchant API is working 200 ok

- **Case ID:** 18567
- **Priority:** Normal
- **Status (at export):** Passed

### Description

Retrieve sub-merchant returns 200 OK and the sub-merchant data for a valid wellfitSubMerchantId.
Preconditions
Valid Bearer token from /authenticate. Valid wellfitSubMerchantId from a prior create (Postman env or saved from create response).

### Expected

HTTP 200 OK. Response body includes sub-merchant details for the requested wellfitSubMerchantId.

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send GET {{URL}}/provisioning/retrieve-sub-merchant?wellfitSubMerchantId={id} with Authorization: Bearer {token} and Content-Type: application/json.
Then confirm the response status is 200 OK.
Finally verify the response body matches the sub-merchant created earlier (e.g. merchant name, identifiers).

---

## 5. Verify that, from DB Payments.Submerchant's table, created new submerchant is logged and stored correctly

- **Case ID:** 18568
- **Priority:** Normal
- **Status (at export):** Passed

### Description

After create sub-merchant, a new row exists in [Payments].[SubMerchants] with data matching the API request and response.
Preconditions
Sub-merchant successfully created via POST /provisioning/create-sub-merchant. wellfitSubMerchantId saved from API response. DB access to Stage Payments database.

### Expected

One row found for the new wellfitSubMerchantId. Key fields match the create payload (e.g. merchant name, PspMerchantId, OrganizationId, BillingDescriptor, MerchantCategoryCode).

### Steps

First create a sub-merchant via POST {{URL}}/provisioning/create-sub-merchant and save wellfitSubMerchantId from the response.
Then query the database: SELECT * FROM [Payments].[SubMerchants] WHERE Id = '{wellfitSubMerchantId}' (or equivalent key column per env schema).
Then confirm exactly one row is returned.
Finally compare DB values against the create request and API response (merchant name, PSP identifiers, billing descriptor, MCC, organization).

---

## 6. Verify that, from Wellfit Provisioning, read merchant category codes API returns 200 OK

- **Case ID:** 304279
- **Priority:** Normal
- **Status (at export):** Passed

### Description

GET merchant category codes returns 200 OK with a list of MCC codes and descriptions.
Preconditions
Valid Bearer token from /authenticate. Stage Merchant Provisioning API available.

### Expected

HTTP 200 OK. Response body includes items array. Each item has code and description (non-empty).

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send GET {{URL}}/merchant-category-codes with Authorization: Bearer {token} and Content-Type: application/json.
Then confirm the response status is 200 OK.
Finally verify the JSON response contains items and each entry includes code and description.

---

## 7. Verify that, from Wellfit Provisioning, create merchant category code API returns 200 OK

- **Case ID:** 304280
- **Priority:** Normal
- **Status (at export):** Untested

### Description

POST merchant category code creates a new MCC and returns the created code and description.
Preconditions
Valid Bearer token from /authenticate. Stage Merchant Provisioning API available. Use a unique code if 1504 already exists in the environment.

### Expected

HTTP 200 OK. Response body:
{
  "code": "1504",
  "description": "Test Code"
}

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send POST {{URL}}/merchant-category-codes with Authorization: Bearer {token}, Content-Type: application/json, and body:
{
  "code": "1504",
  "description": "Test Code"
}
Then confirm the response status is 200 OK.
Finally verify the response body returns code 1504 and description Test Code.

---

## 8. Verify that, from Wellfit Provisioning, delete merchant category code API returns 200 OK

- **Case ID:** 304281
- **Priority:** Normal
- **Status (at export):** Untested

### Description

DELETE merchant category code removes the MCC by code and returns 200 OK.
Preconditions
Valid Bearer token from /authenticate. MCC 1504 exists (created via POST or from prior test data).

### Expected

HTTP 200 OK. Response body is empty or has no error payload.

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then send DELETE {{URL}}/merchant-category-codes?code=1504 with Authorization: Bearer {token} and Content-Type: application/json.
Then confirm the response status is 200 OK.
Finally send GET {{URL}}/merchant-category-codes and verify 1504 is no longer in the items list.

---

## 9. Verify that, when a new sub-merchant is created, its merchant category code is stored and matches MerchantCategoryCodes

- **Case ID:** 304282
- **Priority:** Normal
- **Status (at export):** Untested

### Description

New sub-merchant is saved with the MerchantCategoryCode sent in the create request, aligned with [MerchantProvisioning].[MerchantCategoryCodes].
Preconditions
Valid Bearer token. Valid MCC from catalog (e.g. 8021 — Dentist & Orthodontists). DB access to Stage.

### Expected

Create returns 200 OK with wellfitSubMerchantId. Sub-merchant row has MerchantCategoryCode = 8021. Code exists in [MerchantProvisioning].[MerchantCategoryCodes] with matching Description.

### Steps

First authenticate via POST {{URL}}/authenticate and save bearerToken.
Then confirm MCC 8021 exists: SELECT Code, Description FROM [MerchantProvisioning].[MerchantCategoryCodes] WHERE Code = '8021'.
Then create sub-merchant via POST {{URL}}/provisioning/create-sub-merchant with MerchantCategoryCode: 8021 and MerchantCategoryDetail in the SubMerchant payload; save wellfitSubMerchantId.
Then query: SELECT MerchantCategoryCode FROM [Payments].[SubMerchants] WHERE Id = '{wellfitSubMerchantId}' (adjust column/table name per env if needed).
Then confirm MerchantCategoryCode is 8021.
Finally call GET {{URL}}/provisioning/retrieve-sub-merchant?wellfitSubMerchantId={id} and confirm the response also shows MCC 8021.

---
