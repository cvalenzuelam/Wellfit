# TokenVault

Cases: **13** (from tokenvault2.csv → TokenVault folder only)

## 1. Ensure CNP V1 endpoint is able to make a successful payment with processor token

- **Case ID:** 167990
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-1
- AC Description: CNP V1 process-card accepts a valid processor token from PaymentTokens and completes an approved card-not-present charge.
Preconditions
- Stage CNP V1 environment is reachable; {{URL}} is set to https://stage-platform.wellfit.com/payments.
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid processor token exists in [Payments].[PaymentTokens] for the target card network and sub-merchant (e.g. Stage Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).
- Test data aligns with the selected token: matching network (VI / MC / AMEX / Discover code), expirationDate (MMYY), and sub-merchant.

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{URL}}/credit-card/process-card with the processor token in token returns 200 OK with transactionId and approvalNumber.
- A row is created in [Payments].[Payments] for the returned transactionId with the requested amount and orderId, and PaymentTypeMethod = 2 (CNP token).
- CVV and zip code are not required in the request when charging with a processor token.

### Steps

First send POST {{URL}}/authenticate with valid Stage credentials and confirm Payment-Bearer-Token is captured in the Postman environment.
Then retrieve a valid processor token from [Payments].[PaymentTokens] (or approved Confluence / test data) for the intended card network and sub-merchant.
Next send POST {{URL}}/credit-card/process-card with Bearer authorization, the processor token in token, a unique orderId, valid subMerchantId, amount, payFacFee, expirationDate, and matching network; do not send cvv or zipCode.
Finally verify the API response is 200 OK with transactionId and approvalNumber, and query [Payments].[Payments] by TransactionId to confirm the payment was persisted with PaymentTypeMethod = 2.

---

## 2. Ensure CNP V1 endpoint is able to make a successful payment with token GUID

- **Case ID:** 167991
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

Description
- AC Linked: AC-2
- AC Description: CNP V1 process-card accepts a valid Wellfit Token GUID registered in TokenVault and completes an approved card-not-present charge.
Preconditions
- Stage CNP V1 environment is reachable; {{URL}} is set to https://stage-platform.wellfit.com/payments.
- Stage TokenVault is reachable; TokenVault API is set to https://stage-platform.wellfit.com/tokenvault.
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid Token GUID exists in TokenVault, linked to a processor token and card metadata (via POST {{TokenVault API}}/add-token, a prior CP charge-card response cardToken, or approved test data).
- Test data aligns with the GUID’s underlying card: matching network (VI / MC / AMEX / Discover code), expirationDate (MMYY), and sub-merchant (e.g. Stage Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).

### Expected

Expected
- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- Optional setup: POST {{TokenVault API}}/add-token or GET {{TokenVault API}}/get-token-details?tokenId=<GUID> confirms the Token GUID is present in TokenVault with an associated processorToken.
- POST {{URL}}/credit-card/process-card with the Token GUID in token (not a processor token) returns 200 OK with transactionId and approvalNumber (and related success fields per API contract).
- A row is created in [Payments].[Payments] for the returned transactionId with the requested amount and orderId, and PaymentTypeMethod = 2 (CNP token).
- CVV and zip code are not required in the request when charging with a Token GUID.

### Steps

First send POST {{URL}}/authenticate with valid Stage credentials and confirm Payment-Bearer-Token is captured in the Postman environment.
Then obtain a valid Token GUID registered in TokenVault (via POST {{TokenVault API}}/add-token using a processor token from [Payments].[PaymentTokens] and a new GUID, or use an existing GUID from approved test data / a prior CP cardToken response).
Next optionally send GET {{TokenVault API}}/get-token-details?tokenId=<GUID> to confirm the GUID resolves to an associated processor token in TokenVault.
Next send POST {{URL}}/credit-card/process-card with Bearer authorization, the Token GUID in token, a unique orderId, valid subMerchantId, amount, payFacFee, expirationDate, and matching network; do not send cvv or zipCode.
Finally verify the API response is 200 OK with transactionId and approvalNumber, and query [Payments].[Payments] by TransactionId to confirm the payment was persisted with PaymentTypeMethod = 2.

---

## 3. Ensure, CNP V1 endpoint is able  to make a sucessful payment with paypageID

- **Case ID:** 167996
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-3
- AC Description: CNP V1 process-card accepts a valid eProtect Pay Page registration ID and completes an approved card-not-present charge.
Preconditions
- Stage CNP V1 environment is reachable; {{URL}} is set to https://stage-platform.wellfit.com/payments.
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- eProtect Pay Page (Worldpay/Vantiv prelive) is reachable for the Paypages collection.
- Approved test PAN, CVV, and Pay Page paypageId exist per Confluence / Paypages collection for the target card network (VISA, MasterCard, AMEX, Discover).
- Valid subMerchantId for Stage is available (e.g. Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC or merchant assigned for Pay Page testing).

### Expected

- POST to eProtect …/eProtect/paypage returns 200 OK with paypageRegistrationId (stored as paypage-registration-id in Postman).
- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{URL}}/credit-card/process-card with payPageRegistrationId (not a processor token or Token GUID in token) returns 200 OK with transactionId and approvalNumber (and related success fields per API contract).
- A row is created in [Payments].[Payments] for the returned transactionId with the requested amount and orderId, and PaymentTypeMethod = 1 (Pay Page).
- payPageRegistrationId from the eProtect response is used in the charge request; it is not sourced from [Payments].[PaymentTokens].

### Steps

First send POST to eProtect https://request.eprotect.vantivprelive.com/eProtect/paypage (x-www-form-urlencoded) using the Paypages request for the target card network (e.g. Get PayPageRegistrationId-VISA) with approved test paypageId, PAN, CVV, and orderId, and confirm the response includes paypageRegistrationId saved as paypage-registration-id.
Then send POST {{URL}}/authenticate with valid Stage credentials and confirm Payment-Bearer-Token is captured in the Postman environment.
Next send POST {{URL}}/credit-card/process-card with Bearer authorization, payPageRegistrationId set to the value from the Pay Page response, a unique orderId, valid subMerchantId, amount, payFacFee, expirationDate, matching network (VI / MC / AMEX / Discover code), and zipCode as required for Pay Page; do not use a processor token or Token GUID in token for this flow.
Finally verify the API response is 200 OK with transactionId and approvalNumber, and query [Payments].[Payments] by TransactionId to confirm the payment was persisted with PaymentTypeMethod = 1.

---

## 4. Ensure, Token is not saved into tokenvalut DB when CNP V1 endpoint  runs with processor token ( Right now not saving in future it might be saved)

- **Case ID:** 167992
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-4
- AC Description: After a successful CNP V1 charge using a processor token, TokenVault does not create or update a vault record for that token attributable to the CNP V1 process-card call (current behavior; product may persist in the future)
Preconditions
- Stage CNP V1 environment is reachable; {{URL}} is set to https://stage-platform.wellfit.com/payments.
- Stage TokenVault is reachable; TokenVault API is set to https://stage-platform.wellfit.com/tokenvault.
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid processor token exists in [Payments].[PaymentTokens] (or approved test data) for the target card network and sub-merchant (e.g. Stage Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).
- Test data aligns with the selected token: matching network (VI / MC / AMEX / Discover code), expirationDate (MMYY), and sub-merchant.
- Note: if GET {{TokenVault API}}/query already returns data for the processor token in Stage, baseline the response before the charge and assert no change after (Stage may pre-sync tokens; empty query is not required).

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- GET {{TokenVault API}}/query?processorToken=<processorToken> before the charge captures a baseline response for that processor token.
- POST {{URL}}/credit-card/process-card with the processor token in token returns 200 OK with transactionId and approvalNumber.
- GET {{TokenVault API}}/query?processorToken=<same processorToken> after the charge returns a response unchanged from baseline (no new Token GUID, no new record, no updated timestamps or fields indicating CNP V1 persisted to TokenVault).
- A row is created in [Payments].[Payments] for the returned transactionId with PaymentTypeMethod = 2 (CNP token), confirming the payment succeeded independently of TokenVault persistence.
- CVV and zip code are not sent when charging with a processor token.

### Steps

First configure the Postman environment with URL and TokenVault API for Stage, then send POST {{URL}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured
Next send GET {{TokenVault API}}/query?processorToken=<processorToken> with Bearer authorization and save the full response as the pre-charge baseline for that processor token.
Next send POST {{URL}}/credit-card/process-card with Bearer authorization, the same processor token in token, a unique orderId, valid subMerchantId, amount, payFacFee, expirationDate, and matching network without cvv or zipCode, and verify 200 OK with transactionId and approvalNumber.
Next send GET {{TokenVault API}}/query?processorToken=<same processorToken> again and compare the response to the pre-charge baseline; confirm TokenVault was not created or updated by the CNP V1 payment.
Finally query [Payments].[Payments] by the returned TransactionId to confirm the payment was persisted with PaymentTypeMethod = 2, and document that current behavior expects no TokenVault change until product requirements change.

---

## 5. Ensure, CP V1 endpoint returns token GUID in the response

- **Case ID:** 167993
- **Status:** Untested
- **Flags:** NEEDS_CP

### Description

- AC Linked: AC-5
- AC Description: CP V1 charge-card completes successfully and returns a Wellfit Token GUID in cardToken for downstream CNP and TokenVault flows.
Preconditions
- Stage or Pre Prod CP V1 environment is reachable; {{URL}} is set to the Payments base URL used for Card Present (e.g. https://stage-platform.wellfit.com/payments).
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid subMerchantId and physical laneId are configured for CP testing (e.g. Pre Prod merchant with laneId 1 per team configuration; simulator laneId 9999 may not return cardToken).
- A lane owner with access to the physical payment terminal is available to accept the remote payment when charge-card is invoked.
- CP lane is online and mapped to the configured laneId before the charge is sent.

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{URL}}/credit-card-present/charge-card with Bearer authorization returns 200 OK with responseMessage Approved, transactionId, and approvalNumber.
- The response includes cardToken populated with a Wellfit Token GUID in UUID format (e.g. 12650000-480A-0022-BC3F-08DE89DF3FB2); the value is not a processor token (numeric Worldpay/Vantiv token).
- Response includes approved charge details such as approvedAmount, maskedCardNumber, cardType, and entryMode (e.g. Chip for physical terminal).
- Optional: GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> with TokenVault API configured resolves the GUID to an associated processorToken, confirming the returned GUID is registered in TokenVault.

### Steps

First configure the Postman environment with the CP {{URL}} and send POST {{URL}}/authenticate with valid credentials, then confirm Payment-Bearer-Token is captured in the environment.
Then coordinate with the lane owner who has access to the physical terminal configured for the target laneId (e.g. lane 1) and confirm the device is online before sending the charge.
Next send POST {{URL}}/credit-card-present/charge-card with Bearer authorization, valid subMerchantId, physical laneId, amount, payFacFee, and a unique orderId using the Charge Card request.
Next have the lane owner accept the remote payment on the physical terminal when prompted so Postman receives the final approved response payload.
Next verify the API response is 200 OK with responseMessage Approved, transactionId, and approvalNumber.
Next verify the response includes cardToken as a Wellfit Token GUID in UUID format and that the value is not a processor token.
Finally save cardToken for downstream tests (CNP V1 payment with Token GUID and TokenVault persistence validation), and optionally send GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> to confirm the GUID resolves in TokenVault.

---

## 6. Ensure, CNP V1 endpoint is able to make a successful payment with token GUID which returns on CP response

- **Case ID:** 167994
- **Status:** Untested
- **Flags:** ok

### Description

- AC Linked: AC-6
- AC Description: CNP V1 process-card accepts the Wellfit Token GUID returned as cardToken from a successful CP V1 charge-card and completes an approved card-not-present charge.
- Stage or Pre Prod CNP V1 environment is reachable; {{URL}} is set to the Payments base URL (e.g. https://stage-platform.wellfit.com/payments).
- A successful CP V1 charge-card has already been completed and returned cardToken (Wellfit Token GUID in UUID format, e.g. 12650000-480A-0022-BC3F-08DE89DF3FB2) from test case 5 or an equivalent CP run.
- The cardToken GUID is registered in TokenVault (validated via GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> when TokenVault API is configured).
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- Test data aligns with the underlying card from the CP response: matching network (e.g. VI for Visa), expirationDate (MMYY from CP cardExpirationMonth / cardExpirationYear, e.g. 1231), and valid CNP subMerchantId.

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- Prerequisite CP V1 POST {{URL}}/credit-card-present/charge-card returned Approved with cardToken as a Wellfit Token GUID.
- POST {{URL}}/credit-card/process-card with the CP-returned GUID in token (not a processor token) returns 200 OK with transactionId and approvalNumber.
- A row is created in [Payments].[Payments] for the returned transactionId with the requested amount and orderId, and PaymentTypeMethod = 2 (CNP token).
- CVV and zip code are not sent when charging with the Token GUID from CP.

### Steps

First complete or reference a successful CP V1 POST {{URL}}/credit-card-present/charge-card that returned Approved with cardToken (Wellfit Token GUID), and save the cardToken value from the CP response.
Then send POST {{URL}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured in the Postman environment.
Next optionally send GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> to confirm the CP-returned GUID exists in TokenVault with an associated processorToken.
Next send POST {{URL}}/credit-card/process-card with Bearer authorization, the CP-returned cardToken value in token, a unique orderId, valid subMerchantId, amount, payFacFee, expirationDate, and matching network; do not send cvv or zipCode.
Finally verify the API response is 200 OK with transactionId and approvalNumber, and query [Payments].[Payments] by TransactionId to confirm the payment was persisted with PaymentTypeMethod = 2.

---

## 7. Ensure, Token is able to save into tokenvalut DB when CP V1 endpoint runs

- **Case ID:** 167995
- **Status:** Untested
- **Flags:** NEEDS_CP

### Description

- AC Linked: AC-7
- AC Description: After a successful CP V1 charge-card, the Wellfit Token GUID returned as cardToken is persisted in TokenVault with the associated processor token and card metadata.
Preconditions
- Stage or Pre Prod CP V1 environment is reachable; {{URL}} is set to the Payments base URL used for Card Present (e.g. https://stage-platform.wellfit.com/payments).
- Stage TokenVault is reachable; TokenVault API is set to https://stage-platform.wellfit.com/tokenvault (same platform as CP when validating persistence).
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid subMerchantId and physical laneId are configured for CP testing; a lane owner is available to accept the remote payment on the physical terminal when required.
- Optional baseline: GET {{TokenVault API}}/query?processorToken=<expectedProcessorToken> or DB query confirms the token is not yet present before the CP charge when testing net-new tokenization.

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{URL}}/credit-card-present/charge-card returns 200 OK with responseMessage Approved, transactionId, and cardToken (Wellfit Token GUID in UUID format).
- GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> returns 200 OK with response.processorToken and card metadata (e.g. cardLastFour, brand, expiration) matching the CP charge.
- Optional: GET {{TokenVault API}}/query?processorToken=<processorToken from get-token-details> returns the same GUID / record.
- Optional DB check: a row exists in the TokenVault table for the returned GUID (e.g. Id = cardToken, associated ProcessorToken, card last four, brand, expiration month/year, and created timestamp after the CP charge).

### Steps

First configure the Postman environment with CP {{URL}} and TokenVault API for the same platform (e.g. Stage), then send POST {{URL}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured.
Then coordinate with the lane owner for the physical terminal if required, and optionally capture a pre-charge baseline via GET {{TokenVault API}}/query or DB when verifying net-new token persistence.
Next send POST {{URL}}/credit-card-present/charge-card with Bearer authorization, valid subMerchantId, laneId, amount, and a unique orderId; have the lane owner accept the remote payment when prompted.
Next verify the CP response is 200 OK with Approved, transactionId, and save cardToken (Wellfit Token GUID) from the response.
Next send GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> with Bearer authorization and verify 200 OK with an associated processorToken and card metadata consistent with the CP charge.
Next optionally send GET {{TokenVault API}}/query?processorToken=<processorToken> to confirm the same record is retrievable by processor token.
Finally optionally query the TokenVault database by GUID or ProcessorToken to confirm the row was persisted with expected values and a created timestamp after the CP charge.

---

## 8. Ensure, Token is able to add successfully and able to save into token valut DB when tokenVaultAPI/add-token end point runs

- **Case ID:** 167997
- **Status:** Untested
- **Flags:** EMPTY_DESC, EMPTY_EXPECTED, EMPTY_STEPS

---

## 9. Ensure, CNP V2 ( v2/cnp/charge) endpoint is able to make a successful payment with processor token

- **Case ID:** 167998
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-9
- AC Description: CNP V2 v2/cnp/charge accepts a valid processor token with tokenType 1 and completes an approved card-not-present charge.
Preconditions
- Stage CNP V2 environment is reachable; Payments API Stage is set to the Payments V2 base URL (e.g. https://stage-platform.wellfit.com/payments).
- Valid API credentials exist for POST {{Payments API Stage}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid processor token exists in [Payments].[PaymentTokens] (or approved test data) for the target card network and sub-merchant (e.g. Stage Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).
- Test data aligns with the selected token: matching expirationMonth, expirationYear, and sub-merchant.

### Expected

- POST {{Payments API Stage}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{Payments API Stage}}/v2/cnp/charge with the processor token in token, tokenType 1, valid subMerchantId, amount, expirationMonth, expirationYear, and unique orderId returns 200 OK with status Approved.
- Response response object includes transactionId, approvalNumber, billingDescriptor, responseMessage Approved, and responseCode (e.g. VN000).
- Response may include a Wellfit Token GUID in response.token (UUID format) returned after a successful processor-token charge.
- Optional: a row is created in [Payments].[Payments] for the returned transactionId.

### Steps

First configure the Postman environment with Payments API Stage for Stage and import or open the Payments API V2 collection, then send POST {{Payments API Stage}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured.
Then retrieve a valid processor token from [Payments].[PaymentTokens] (or approved test data) for the intended card network and sub-merchant.
Next send POST {{Payments API Stage}}/v2/cnp/charge with Bearer authorization, the processor token in token, tokenType set to 1, a unique orderId, valid subMerchantId, amount, expirationMonth, and expirationYear per V2 request format.
Next verify the API response is 200 OK with status Approved and response.responseMessage Approved.
Next verify response.transactionId and response.approvalNumber are present and save response.token if returned as a Wellfit Token GUID for downstream V2 / TokenVault tests.
Finally optionally query [Payments].[Payments] by TransactionId to confirm the payment was persisted.

---

## 10. Ensure, CNP V2 ( v2/cnp/charge) endpoint is able to make a successful payment with token GUID'

- **Case ID:** 167999
- **Status:** Untested
- **Flags:** ok

### Description

- AC Linked: AC-10
- AC Description: CNP V2 v2/cnp/charge accepts a valid Wellfit Token GUID registered in TokenVault and completes an approved card-not-present charge.
Preconditions
- Stage CNP V2 environment is reachable; Payments API Stage is set to the Payments V2 base URL (e.g. https://stage-platform.wellfit.com/payments).
- Valid API credentials exist for POST {{Payments API Stage}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid Token GUID exists in TokenVault (e.g. from a prior V2 charge response.token, CP cardToken, or POST {{TokenVault API}}/add-token) and is confirmed via GET {{TokenVault API}}/get-token-details?tokenId=<GUID>.
- Test data aligns with the GUID’s underlying card: matching expirationMonth, expirationYear, and the same subMerchantId / platform used when the GUID was created.

### Expected

- POST {{Payments API Stage}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{Payments API Stage}}/v2/cnp/charge with the Token GUID in token and the correct tokenType for GUID returns 200 OK with status Approved.
- Response response object includes transactionId, approvalNumber, billingDescriptor, and responseMessage Approved.
- A successful charge is completed without sending a processor token or Pay Page registration ID in token.
- Optional: a row is created in [Payments].[Payments] for the returned transactionId.

### Steps

First configure the Postman environment with Payments API Stage and TokenVault API for the same platform, then obtain a valid Token GUID (e.g. 21a70000-bd06-6045-b483-08dd71556023 from a prior V2 processor-token charge, CP cardToken, or add-token) and save the value.
Then send POST {{Payments API Stage}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured.
Next optionally send GET {{TokenVault API}}/get-token-details?tokenId=<GUID> to confirm the GUID exists in TokenVault with an associated processorToken.
Next send POST {{Payments API Stage}}/v2/cnp/charge with Bearer authorization, the Token GUID in token, the correct tokenType for Wellfit GUID, a unique orderId, valid subMerchantId, amount, expirationMonth, and expirationYear; do not use a processor token or Pay Page ID in token.
Next verify the API response is 200 OK with status Approved, response.transactionId, and response.approvalNumber.
Finally optionally query [Payments].[Payments] by TransactionId to confirm the payment was persisted.

---

## 11. Ensure, CNP V2 ( v2/cnp/charge) endpoint is able to make a successful payment with paypageid

- **Case ID:** 168000
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-11
- AC Description: CNP V2 v2/cnp/charge accepts a valid eProtect Pay Page registration ID with tokenType 0 and completes an approved card-not-present charge.
Preconditions
- Stage CNP V2 environment is reachable; Payments API Stage is set to the Payments V2 base URL (e.g. https://stage-platform.wellfit.com/payments).
- Valid API credentials exist for POST {{Payments API Stage}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- eProtect Pay Page (Worldpay/Vantiv prelive) is reachable via Payments API V2 get_paypage_id or the Paypages collection.
- Approved test PAN, CVV, and Pay Page paypageId exist per Confluence / collection for the target card network (e.g. VISA).
- Valid Stage subMerchantId is available (e.g. Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).

### Expected

- POST to eProtect …/eProtect/paypage returns 200 OK with paypageRegistrationId stored as paypage-registration-id.
- POST {{Payments API Stage}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{Payments API Stage}}/v2/cnp/charge with the Pay Page registration ID in token, tokenType 0, valid subMerchantId, amount, expirationMonth, expirationYear, zipCode, and unique orderId returns 200 OK with status Approved.
- Response response object includes transactionId, approvalNumber, billingDescriptor, and responseMessage Approved; source.token matches the Pay Page registration ID used in the request.
- Pay Page registration ID is used in token; it is not sourced from [Payments].[PaymentTokens] or a Wellfit Token GUID.
- Optional: a row is created in [Payments].[Payments] for the returned transactionId.

### Steps

First send POST to eProtect https://request.eprotect.vantivprelive.com/eProtect/paypage using Payments API V2 get_paypage_id (or Paypages) with approved test paypageId, PAN, CVV, and orderId, and confirm paypageRegistrationId is saved as paypage-registration-id.
Then send POST {{Payments API Stage}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured in the Postman environment.
Next send POST {{Payments API Stage}}/v2/cnp/charge with Bearer authorization, token set to paypage-registration-id, tokenType set to 0, a unique orderId, valid subMerchantId, amount, expirationMonth, expirationYear, and zipCode as required for Pay Page.
Next verify the API response is 200 OK with status Approved, response.transactionId, and response.approvalNumber.
Next verify source.token in the response matches the Pay Page registration ID sent in the charge request and that a processor token or Token GUID was not sent in token for this flow.
Finally optionally query [Payments].[Payments] by TransactionId to confirm the payment was persisted.

---

## 12. Ensure, token is able to save into tokenvallt DB when CNP V2 end point runs with processor token ( If token is not present  in DB it will save . If token is already there it will not save)

- **Case ID:** 168001
- **Status:** Untested
- **Flags:** WRONG_DB_ref

### Description

- AC Linked: AC-12
- AC Description: When CNP V2 v2/cnp/charge runs with a processor token (tokenType 1), TokenVault persists the token only if the processor token is not already present; if the processor token already exists in TokenVault, no duplicate record is created.
Preconditions
- Stage CNP V2 environment is reachable; Payments API Stage is set to the Payments V2 base URL (e.g. https://stage-platform.wellfit.com/payments).
- Stage TokenVault is reachable; TokenVault API is set to https://stage-platform.wellfit.com/tokenvault (same platform as CNP V2).
- Valid API credentials exist for POST {{Payments API Stage}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid processor token exists in [Payments].[PaymentTokens] (or approved test data) for the target card network and sub-merchant (e.g. Stage Redhill 159F2670-1B71-4EF6-AD30-0EBF0991E2CC).
- Test data aligns with the selected token: matching expirationMonth, expirationYear, and sub-merchant.

### Expected

- POST {{Payments API Stage}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- Scenario A — processor token not in TokenVault: GET {{TokenVault API}}/query?processorToken=<processorToken> before the charge confirms no existing record (or baseline captured). After POST {{Payments API Stage}}/v2/cnp/charge with tokenType 1 returns Approved, TokenVault contains a new record for that processor token (via query, get-token-details using response.token if returned, or DB). Charge response may include a Wellfit Token GUID in response.token.
- Scenario B — processor token already in TokenVault: Baseline before charge captures existing GUID / record for the processor token. After a successful v2/cnp/charge with the same processor token, TokenVault shows no duplicate record (same GUID, no additional row, no new created timestamp attributable to a second save).
- CNP V2 charge returns 200 OK with status Approved, response.transactionId, and response.approvalNumber in both scenarios.

### Steps

First configure the Postman environment with Payments API Stage and TokenVault API for the same platform, then send POST {{Payments API Stage}}/authenticate with valid credentials and confirm Payment-Bearer-Token is captured.
Then retrieve a valid processor token from [Payments].[PaymentTokens] (or approved test data) and note the value for charge and TokenVault checks.
Next send GET {{TokenVault API}}/query?processorToken=<processorToken> with Bearer authorization and capture the pre-charge baseline (record absent for Scenario A, or existing GUID / record details for Scenario B).
Next send POST {{Payments API Stage}}/v2/cnp/charge with Bearer authorization, the processor token in token, tokenType 1, a unique orderId, valid subMerchantId, amount, expirationMonth, expirationYear, and zipCode if required per V2 Pay Page/processor-token contract, and verify 200 OK with status Approved.
Next for Scenario A (token was not present before charge), verify a new TokenVault record now exists for the processor token and optionally note response.token (GUID) from the charge response.
Next for Scenario B (token was already present before charge), verify TokenVault was not duplicated: the same GUID / single record remains and no additional row was created for that processor token.
Finally optionally query the TokenVault database by ProcessorToken or GUID to confirm persistence behavior matches Scenario A or Scenario B, and optionally query [Payments].[Payments] by TransactionId to confirm the charge was persisted.

---

## 13. Ensure that, CP charge card API retrieves Wellfit Token GUID as "cardToken" value response

- **Case ID:** 168013
- **Status:** Untested
- **Flags:** NEEDS_CP

### Description

- AC Linked: AC-13
- AC Description: CP V1 credit-card-present/charge-card returns a Wellfit Token GUID in the response field cardToken after a successful approved charge.
Preconditions
- Stage or Pre Prod CP V1 environment is reachable; {{URL}} is set to the Payments base URL used for Card Present (e.g. https://stage-platform.wellfit.com/payments).
- Valid API credentials exist for POST {{URL}}/authenticate (e.g. WellfitUnifiedPaymentsAPI).
- A valid subMerchantId and physical laneId are configured for CP testing; a lane owner with access to the physical payment terminal is available to accept the remote payment when required (simulator laneId 9999 may not return cardToken per environment configuration).
- CP lane is online and mapped to the configured laneId before the charge is sent.

### Expected

- POST {{URL}}/authenticate returns 200 OK and a bearer token stored as Payment-Bearer-Token.
- POST {{URL}}/credit-card-present/charge-card with Bearer authorization returns 200 OK with responseMessage Approved, transactionId, and approvalNumber.
- The response includes the field cardToken populated with a Wellfit Token GUID in UUID format (e.g. 12650000-480A-0022-BC3F-08DE89DF3FB2).
- cardToken is not a processor token (numeric Worldpay/Vantiv token such as 2811187237110011); it matches UUID format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
- Optional: GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> resolves the GUID to an associated processorToken, confirming the cardToken value is registered in TokenVault.

### Steps

First configure the Postman environment with the CP {{URL}} and send POST {{URL}}/authenticate with valid credentials, then confirm Payment-Bearer-Token is captured in the environment.
Then coordinate with the lane owner for the physical terminal if required and confirm the device is online for the target laneId (e.g. lane 1) before sending the charge.
Next send POST {{URL}}/credit-card-present/charge-card with Bearer authorization, valid subMerchantId, laneId, amount, payFacFee, and a unique orderId using the Charge Card request.
Next have the lane owner accept the remote payment on the physical terminal when prompted so Postman receives the final approved response payload.
Next verify the API response is 200 OK with responseMessage Approved, transactionId, and approvalNumber.
Next verify the response body includes the field cardToken with a Wellfit Token GUID in UUID format and confirm the value is not a processor token.
Next verify the response body includes the field cardToken with a Wellfit Token GUID in UUID format and confirm the value is not a processor token.
Finally save cardToken for downstream CNP / TokenVault tests and optionally send GET {{TokenVault API}}/get-token-details?tokenId=<cardToken> to confirm the GUID exists in TokenVault with an associated processorToken.

---
