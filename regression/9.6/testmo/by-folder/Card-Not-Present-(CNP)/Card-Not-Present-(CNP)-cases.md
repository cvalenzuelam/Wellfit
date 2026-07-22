# Card Not Present (CNP)

Cases: **17**

## 1. Validate that, CNP can process successful transactions with VISA Card.

- **Case ID:** 13579
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-1
AC Description: End-to-end CNP accepts a VISA payment when process-card is called with a real ProcessorToken from PaymentTokens, the correct subMerchantId for that environment, and network set to VI, after a successful authenticate.
Preconditions
- {{URL}} points to the environment under test.
- POST {{URL}}/authenticate works and Payment-Bearer-Token is available.
- PaymentTokens has a VISA test row; use ProcessorToken as the body token.
- subMerchantId matches the business (e.g. 159F2670-1B71-4EF6-AD30-0EBF0991E2CC, or another id from merchant data).
- Body includes required sale fields (amount, expirationDate, orderId, payFacFee, optional fields as needed).

### Expected

- HTTP 200 OK.
- Response JSON includes a non-empty transactionId.
- approvalNumber is present (value follows your environment — e.g. sandbox/prelive patterns such as MCPREP where applicable).
- billingDescriptor is present and matches the expected descriptor for that sub-merchant (e.g. statement text like WF *RedHill-Dental when testing that office).
- token and expirationDate are returned and consistent with the test card / token used.

### Steps

Run POST {{URL}}/authenticate, then POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Paste ProcessorToken from PaymentTokens (VISA) into token; set network to VI, set subMerchantId and required fields.
Send the request and confirm status 200 and the Expected JSON fields.

---

## 2. Validate that, CNP can process successful transactions with AMEX Card.

- **Case ID:** 13580
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-2
AC Description: End-to-end CNP accepts an American Express payment when process-card is called with a valid ProcessorToken from PaymentTokens for an AMEX test card, the correct subMerchantId, and network set to the American Express value your API expects (e.g. AX — confirm in internal docs), after a successful authenticate.
Preconditions
- {{URL}} points to the environment under test.
- POST {{URL}}/authenticate works and Payment-Bearer-Token is available.
- PaymentTokens has an AMEX test row; use ProcessorToken as the body token.
- subMerchantId matches the business under test (e.g. 159F2670-1B71-4EF6-AD30-0EBF0991E2CC, or another id from merchant data).
- Body includes required sale fields (amount, expirationDate, orderId, payFacFee, optional fields as needed).

### Expected

- HTTP 200 OK.
- Response JSON includes a non-empty transactionId.
- approvalNumber is present (format per environment / processor).
- billingDescriptor is present and matches the expected statement text for that sub-merchant.
- token and expirationDate are returned and align with the AMEX test token used.

### Steps

Run POST {{URL}}/authenticate, then POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Paste ProcessorToken from PaymentTokens (AMEX test card) into token; set network to the AMEX code from your spec (AX if that is what Wellfit uses).
Set subMerchantId and all required sale fields; send the request.
Confirm 200 and the Expected fields in the response body.

---

## 3. Validate that,  CNP can process successful transactions with Discover card.

- **Case ID:** 13581
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Preconditions
- {{URL}} points to the environment under test.
- POST {{URL}}/authenticate works and Payment-Bearer-Token is available.
- PaymentTokens has a Discover test row; use ProcessorToken as the body token.
- subMerchantId matches the business under test (e.g. 159F2670-1B71-4EF6-AD30-0EBF0991E2CC, or another id from merchant data).
- Body includes required sale fields (amount, expirationDate, orderId, payFacFee, optional fields as needed).

### Expected

- HTTP 200 OK.
- Response JSON includes a non-empty transactionId.
- approvalNumber is present (format per environment / processor).
- billingDescriptor is present and matches the expected statement text for that sub-merchant.
- token and expirationDate are returned and align with the Discover test token used.

### Steps

Run POST {{URL}}/authenticate, then POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Paste ProcessorToken from PaymentTokens (Discover test card) into token; set network to the Discover code from your spec (DI if that is what Wellfit uses).
Set subMerchantId and all required sale fields; send the request.
Confirm 200 and the Expected fields in the response body.

---

## 4. Validate that, CNP can process successful transactions with MasterCard.

- **Case ID:** 13582
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-4
AC Description: End-to-end CNP accepts a MasterCard payment when process-card is called with a valid ProcessorToken from PaymentTokens for a MasterCard test card, the correct subMerchantId, and network set to the MasterCard value your API expects (e.g. MC — confirm in internal docs), after a successful authenticate.
Preconditions
- {{URL}} points to the environment under test.
- POST {{URL}}/authenticate works and Payment-Bearer-Token is available.
- PaymentTokens has a MasterCard test row; use ProcessorToken as the body token.
- subMerchantId matches the business under test (e.g. 159F2670-1B71-4EF6-AD30-0EBF0991E2CC, or another id from merchant data).
- Body includes required sale fields (amount, expirationDate, orderId, payFacFee, optional fields as needed).

### Expected

- HTTP 200 OK.
- Response JSON includes a non-empty transactionId.
- approvalNumber is present (format per environment / processor).
- billingDescriptor is present and matches the expected statement text for that sub-merchant.
- token and expirationDate are returned and align with the MasterCard test token used.

### Steps

Run POST {{URL}}/authenticate, then POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Paste ProcessorToken from PaymentTokens (MasterCard test card) into token; set network to the MasterCard code from your spec (MC if that is what Wellfit uses).
Set subMerchantId and all required sale fields; send the request.
Confirm 200 and the Expected fields in the response body.

---

## 5. Validate that, CNP receives an error message when the CVV does not match.

- **Case ID:** 13583
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-5
AC Description: After authenticate, credit-card/process-card with a valid ProcessorToken from PaymentTokens and a wrong cvv must not return a successful sale; the response must include an error whose message or code clearly ties to CVV / security code validation (per your API’s error model).
Preconditions
- {{URL}} points to the environment under test.
- POST {{URL}}/authenticate works and Payment-Bearer-Token is available.
- PaymentTokens: pick a test row and copy ProcessorToken into the body token (same as a normal sale).
- subMerchantId matches the business under test (e.g. 159F2670-1B71-4EF6-AD30-0EBF0991E2CC, or another id from merchant data).
- network and the rest of the payload match a normal process-card request; the only intentional defect is cvv (value that does not match the valid CVV for that test card, per your test-data notes).

### Expected

- Response indicates failure (HTTP status and/or body flags per internal documentation — not the same happy path as a 200 approval with transactionId / approvalNumber as in successful CNP).
- Error payload is specific enough to attribute the failure to CVV / security code.
- No approved CNP outcome for this request (no successful approval pattern you use for pass cases).

### Steps

Run POST {{URL}}/authenticate, then build POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Set token from PaymentTokens.ProcessorToken, subMerchantId, network, and required fields as in a passing test.
Add or set cvv to an incorrect value for that test card.
Send the request and verify Expected (status, error fields, and message/code for CVV).

---

## 6. Validate that,  CNP receives an error message when the Zipcode does not match.

- **Case ID:** 13584
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-6
AC Description: For a test ProcessorToken that enforces billing ZIP / AVS, credit-card/process-card with a zipCode that does not match what the processor expects must return an error. Other sandbox tokens may ignore ZIP or accept any value — this case applies only to tokens documented to validate ZIP.
Preconditions
- {{URL}} and Payment-Bearer-Token from POST {{URL}}/authenticate are ready.
- PaymentTokens: use a ProcessorToken row that your test-data guide lists as ZIP-sensitive (some test cards accept any CVV/ZIP or skip checks; pick one that does not).
- subMerchantId, network, and required sale fields match a normal process-card call.
- Intentional defect: set zipCode to a value that fails AVS / billing ZIP for that token.

### Expected

- HTTP 409 Conflict (or the status your doc defines for this failure — align with current QA behavior).
- Response body is a JSON array of errors including:
- code: ProcessorResponse.Failure.ZipCode
- message: Billing Zip Code Mismatch
- severity: Error
- type: Business
- No successful approval payload (no normal transactionId / approvalNumber success pattern).

### Steps

Authenticate and call POSt {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Use a ZIP-validating ProcessorToken from PaymentTokens; complete subMerchantId, network, and required fields.
Set zipCode to a mismatched value for that card; send the request.
Verify Expected status and error object(s); if the call succeeds, confirm the token is not ZIP-sensitive and swap to a token from the list that does validate ZIP.

---

## 7. Validate that,  CNP receives an error message when card is expired

- **Case ID:** 13585
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-7
AC Description: credit-card/process-card must reject a sale when expirationDate is MMYY but represents a card that is already expired (month/year before the current date). Use a value that is clearly in the past for the run date (e.g. 0325 if testing after March 2025). Do not use non-MMYY strings (e.g. a year-only value); those can trigger format validation instead of a clean “expired” check.
Preconditions
- {{URL}} and Payment-Bearer-Token from POST {{URL}}/authenticate are ready.
- ProcessorToken from PaymentTokens and subMerchantId are set for a normal CNP sale (same as a passing process-card).
- network and required fields are valid; the only intentional defect is expirationDate: MMYY with expiry in the past relative to today.
- Know today’s date so you pick a past MMYY (format like 0327 is not expired while the current calendar is still before April 2027).

### Expected

- HTTP 409 Conflict.
- Response body is a JSON array of errors including:
- code: ExpirationDate.Invalid
- message: Expiration date must be a future date in MMYY format.
- severity: Error
- type: Business
- No successful approval (transactionId / approvalNumber pattern from happy-path responses).

### Steps

Authenticate and send POST {{URL}}/credit-card/process-card with Bearer Payment-Bearer-Token.
Use a valid token (ProcessorToken), subMerchantId, network, and the usual required fields.
Set expirationDate to a past MMYY; send the request.
Confirm 409 and the Expected error code / message.

---

## 8. Validate that, the correct Transaction Amount is stored in the [Payments].[Payments] DB table.

- **Case ID:** 13586
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-8
AC Description: After a successful CNP credit-card/process-card (any card brand), [Payments].[Payments] must contain a row keyed by the API transactionId, and the Amount column must equal the amount sent in the request; PayFacFee should match payFacFee when that field was sent.
Preconditions
- {{URL}} and Payment-Bearer-Token from POST {{URL}}/authenticate are ready.
- ProcessorToken from PaymentTokens, subMerchantId, and network are set for a passing sale (any supported brand).
- amount and payFacFee in the request are known values you will assert in the DB (e.g. 123.00 and 0.00).
- Read access to the Platform database (or equivalent for the environment under test) to run SQL against Payments.Payments.

### Expected

- POST {{URL}}/credit-card/process-card returns 200 OK with a transactionId in the response (same id used for downstream checks).
- Query:
SELECT * FROM [Payments].[Payments] WHERE transactionId = '<transactionId from response>'
returns exactly one row (or follow team rules if multiples are possible).
- Amount on that row matches the request amount (e.g. 123.00 stored for 123 / 123.00 sent, per your precision rules).
- PayFacFee on that row matches the request payFacFee when applicable (e.g. 0.00).
- Id / TimeStamp are present (sanity check that the row was written for this transaction).

### Steps

Authenticate and call POST {{URL}}/credit-card/process-card with a valid token, subMerchantId, network, and explicit amount and payFacFee.
Copy transactionId from the success response.
Run SELECT * FROM [Payments].[Payments] WHERE transactionId = '<that id>' on the correct environment database.
Confirm Amount and PayFacFee (and any other fields your team requires) match the request and Expected.

---

## 9. Validate that, the correct PaymenTypeMethod is stored for the new payment transaction in the [Payments].[Payments] DB table

- **Case ID:** 13588
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-9
AC Description: After a successful CNP sale using a ProcessorToken (credit-card/process-card with token from PaymentTokens), the row in [Payments].[Payments] for that transactionId must have PaymentTypeMethod = 2 (CNP token), not another payment type.
Reference — PaymentTypeMethod on [Payments].[Payments]:
- 0 — Default (eCheck)
- 1 — CNP Pay Page–encrypted card entry
- 2 — CNP token
- 3 — Apple Pay
- 4 — Google Pay
- 5 — CP device
Preconditions
- {{URL}} and Payment-Bearer-Token from POST {{URL}}/authenticate are ready.
- credit-card/process-card uses a token copied from PaymentTokens.ProcessorToken (standard CNP token flow — not Pay Page, wallet, or card-present).
- subMerchantId, network, and required fields are valid so the transaction approves (200 OK).
- Read access to the Platform DB for the environment under test to query Payments.Payments.

### Expected

- API response includes transactionId for the new payment.
- SELECT PaymentTypeMethod, * FROM [Payments].[Payments] WHERE transactionId = '<transactionId from response>' returns a row where PaymentTypeMethod = 2 (CNP token).
- Other columns (e.g. Amount, PayFacFee) align with the request as in your related checks.

### Steps

First run POST {{URL}}/authenticate, then send a successful POST {{URL}}/credit-card/process-card with ProcessorToken from PaymentTokens as token (CNP token flow only).
Then copy transactionId from the API response.
Next, on the correct environment database, run
SELECT PaymentTypeMethod, * FROM [Payments].[Payments] WHERE transactionId = '<that id>'.
Finally confirm PaymentTypeMethod is 2 (CNP token). If it is 1, 3, 4, or 5, the stored payment type is wrong for this flow.

---

## 10. Validate that, a partial refund is able to get successfully processed for CNP transaction

- **Case ID:** 66733
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-10
AC Description: After an approved CNP credit-card/process-card (with a known transactionId on the original sale), POST .../refund-transaction with a refund amount less than the original charge returns 200 OK, returns a new refund transactionId, and sets wasVoided to false. A full refund of the original amount is expected to return wasVoided: true (out of scope for this case; partial only).
Preconditions
- Payment-Bearer-Token is available (**POST {{URL}}/authenticate**).
- A successful CNP payment already exists (200 from credit-card/process-card) and you have the original transactionId (and the orderId used for that sale, if required by your refund payload).
- Refund amount is greater than zero and not greater than the original transaction amount (this case uses an amount strictly less than the original to exercise partial refund).

### Expected

- POST {{URL}}/refund-transaction returns 200 OK.
- Response JSON includes a new transactionId for the refund.
- wasVoided is false for this partial refund.

### Steps

First complete POST {{URL}}/authenticate and confirm Payment-Bearer-Token is set for POST {{URL}}/refund-transaction.
Then build the refund body with originalTransactionId set to the original sale transactionId, amount set to a partial value (less than the original charge but within allowed limits), and orderId (or other required fields) matching your contract.
Next send POST {{URL}}/refund-transaction with Bearer auth and that JSON body.
Finally verify 200 OK, a new refund transactionId in the response, and wasVoided: false.

---

## 11. Validate that,  the correct partial refund Amount and TransactionID is stored in the [Payments].[Refunds] table

- **Case ID:** 286525
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-11
AC Description: After a successful partial refund-transaction, the row in [Payments].[Refunds] for the refund transactionId from the API must show the same Amount and OrderId as the request and link back to the original payment (**OriginalPaymentId** / payments row per schema).
Preconditions
- Bearer token available; CNP sale completed and partial refund API returned 200 with a refund transactionId.
- Access to Platform DB [Payments].[Refunds] (and [Payments].[Payments] if you assert OriginalPaymentId).
Preconditions
- Payment-Bearer-Token from POST {{URL}}/authenticate is available.
- A successful CNP credit-card/process-card exists; you have the original transactionId (and the Id / GUID of that row in [Payments].[Payments] if your team uses it to assert OriginalPaymentId).
- POST {{URL}}/refund-transaction has been executed successfully for a partial amount (amount > 0 and less than the original Amount), using that originalTransactionId, orderId, and refund amount from the request body.
- Read access to the Platform database for the environment under test ([Payments].[Payments] as needed).

### Expected

- Refund API returned 200 OK with a refund transactionId (e.g. in the response body).
- SELECT * FROM [Payments].[Refunds] WHERE transactionId = '<refund transactionId from response>' returns a row.
- TransactionId on that row matches the refund transactionId from the API.
- Amount on that row matches the amount sent in refund-transaction (e.g. 50.00 stored for a 50 refund, per your precision rules).
- OrderId matches the orderId in the refund request.
- OriginalPaymentId (or equivalent) matches the original payment row in [Payments].[Payments] for the originalTransactionId used in the refund.

### Steps

First run authenticate, sale, then partial refund; note refund transactionId and request amount / orderId.
Then query [Payments].[Refunds] by that transactionId.
Finally compare Amount, OrderId, TransactionId, and OriginalPaymentId to the request and original payment.

---

## 12. Validate that, a void transaction (Full refund under the same day window) is able to get successfully processed for CNP transaction

- **Case ID:** 66734
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Description: For an approved CNP sale, POST {{URL}}/refund-transaction with amount equal to the original payment amount (full refund / void under the same-day rules your product uses) returns 200 OK, returns a new refund transactionId, and wasVoided is true.
Preconditions
- Payment-Bearer-Token from POST {{URL}}/authenticate is available.
- A successful credit-card/process-card exists; you have the original transactionId and the original charged amount.
- Refund is executed within the allowed same-day void window for that environment.
- Request amount is not greater than the original and equals the full original payment amount (this case is full coverage, not partial).
- orderId and originalTransactionId in the refund body match your contract (same pattern as successful refund tests).

### Expected

- POST {{URL}}/refund-transaction returns 200 OK.
- Response includes a new transactionId (void / refund id).
- wasVoided is true.

### Steps

First authenticate, confirm the original sale transactionId and amount, and build refund-transaction with amount set to that full original amount, originalTransactionId set to the sale id, and orderId as required.
Then send POST {{URL}}/refund-transaction with Bearer auth.
Finally confirm 200 OK, a new transactionId, and wasVoided: true.

---

## 13. Validate that, the correct void amount and transactionID is stored in the [Payments].[Voids] table

- **Case ID:** 286526
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-13
AC Description: After a successful same-day void (refund-transaction with full original amount, wasVoided: true), [Payments].[Voids] must contain a row for the void transactionId returned by the API, with Amount, OrderId, and OriginalPaymentId consistent with the request and the original [Payments].[Payments] row.
Preconditions
- Bearer token available; CNP sale completed, then full refund-transaction returned 200 with a void transactionId and wasVoided: true.
- Access to Platform [Payments].[Voids] (and [Payments].[Payments] if you check OriginalPaymentId).

### Expected

- SELECT * FROM [Payments].[Voids] WHERE transactionId = '<void transactionId from API>' returns a row.
- TransactionId, Amount, OrderId, and OriginalPaymentId match the refund request and the original payment (per schema / team mapping).

### Steps

First complete authenticate, sale, then full same-day refund-transaction; copy the response transactionId and the amount / orderId / originalTransactionId from the request.
Then run SELECT * FROM [Payments].[Voids] WHERE transactionId = '<that transactionId>' on the correct Platform database.
Finally compare Amount, OrderId, TransactionId, and OriginalPaymentId to the API request and original [Payments].[Payments] row.

---

## 14. Validate that, CNP with Wellfit GUID can process successful transactions with VISA Card.

- **Case ID:** 294866
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-14
AC Description: Pay Page flow: register the card with Worldpay / Vantiv eProtect (POST to …/eProtect/paypage), take paypageRegistrationId from the response, then call POST {{URL}}/credit-card/process-card with payPageRegistrationId (no ProcessorToken from PaymentTokens). For VISA test data from Confluence, the sale should approve and return a normal success payload.
Preconditions
- VISA sandbox accountNumber and cvv from Confluence test cards.
- Paypages request ready: x-www-form-urlencoded with paypageId, reportGroup, orderId, id, accountNumber, cvv (same shape as the Paypages collection).
- Payment-Bearer-Token from POST {{URL}}/authenticate.
- subMerchantId, processor (Vantiv), amount, expirationDate, orderId, payFacFee, network , zipCode, and CVV on process-card as required for Pay Page.

### Expected

Expected
- eProtect response 200 with message: Success (or equivalent) and a non-empty paypageRegistrationId.
- POST {{URL}}/credit-card/process-card returns 200 OK with transactionId, approvalNumber, billingDescriptor, and related fields per your environment.

### Steps

First send POST https://request.eprotect.vantivprelive.com/eProtect/paypage (or the eProtect URL for your stage) with the VISA Paypages form fields and copy paypageRegistrationId.
Then authenticate to {{URL}} and call POST {{URL}}/credit-card/process-card with Bearer token, payPageRegistrationId set to that id, and the rest of the Pay Page body (no DB token).
Finally confirm Expected on both responses.

---

## 15. Validate that, CNP with Wellfit GUID can process successful transactions with AMEX Card.

- **Case ID:** 294867
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-15
AC Description: Pay Page flow for American Express: run the AMEX Paypages request to …/eProtect/paypage, capture paypageRegistrationId, then POST {{URL}}/credit-card/process-card with payPageRegistrationId (not a DB ProcessorToken). Use AMEX test accountNumber / cvv from Confluence and the network value your API expects for AMEX.
Preconditions
- AMEX sandbox PAN and CVV from Confluence.
- Paypages AMEX form body (x-www-form-urlencoded: paypageId, reportGroup, orderId, id, accountNumber, cvv).
- Payment-Bearer-Token from POST {{URL}}/authenticate.
- process-card body includes payPageRegistrationId, subMerchantId, processor: Vantiv, network for AMEX, and required fields (amount, expirationDate, orderId, payFacFee, zipCode, CVV if required).

### Expected

- eProtect returns 200 with paypageRegistrationId and a success-style payload (message: Success or equivalent).
- credit-card/process-card returns 200 OK with transactionId, approvalNumber, billingDescriptor, and related success fields.

### Steps

First execute POST …/eProtect/paypage using the AMEX Paypages parameters and save paypageRegistrationId.
Then call POST {{URL}}/authenticate and POST {{URL}}/credit-card/process-card with Bearer auth, payPageRegistrationId, and valid AMEX network / merchant fields.
Finally verify Expected on both calls.

---

## 16. Validate that, CNP with Wellfit GUID can process successful transactions with DISCOVER Card.

- **Case ID:** 294868
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-16
AC Description: Pay Page flow for Discover: run the Discover Paypages request to …/eProtect/paypage, capture paypageRegistrationId, then POST {{URL}}/credit-card/process-card with payPageRegistrationId (not a DB ProcessorToken). Use Discover test accountNumber / cvv from Confluence and the network value your API expects for Discover.
Preconditions
- Discover sandbox PAN and CVV from Confluence.
- Paypages Discover form body (x-www-form-urlencoded: paypageId, reportGroup, orderId, id, accountNumber, cvv).
- Payment-Bearer-Token from POST {{URL}}/authenticate.
- process-card includes payPageRegistrationId, subMerchantId, processor: Vantiv, network for Discover, and required sale fields.

### Expected

- eProtect returns 200 with paypageRegistrationId and a success-style response.
- credit-card/process-card returns 200 OK with transactionId, approvalNumber, billingDescriptor, and related success fields.

### Steps

First call POST …/eProtect/paypage with the Discover Paypages fields and save paypageRegistrationId.
Then POST {{URL}}/authenticate and POST {{URL}}/credit-card/process-card with Bearer auth, payPageRegistrationId, and valid Discover network / merchant fields.
Finally confirm Expected on both responses.

---

## 17. Validate that, CNP with Wellfit GUID can process successful transactions with Master  Card.

- **Case ID:** 294869
- **Priority:** Normal
- **Status (at export):** Untested

### Description

AC Linked: AC-17
AC Description: Pay Page flow for MasterCard: run the Master Paypages request to …/eProtect/paypage, capture paypageRegistrationId, then POST {{URL}}/credit-card/process-card with payPageRegistrationId (not a DB ProcessorToken). Use MasterCard test accountNumber / cvv from Confluence and the network value your API expects for MasterCard.
Preconditions
- MasterCard sandbox PAN and CVV from Confluence.
- Paypages Master form body (x-www-form-urlencoded: paypageId, reportGroup, orderId, id, accountNumber, cvv).
- Payment-Bearer-Token from POST {{URL}}/authenticate.
- process-card includes payPageRegistrationId, subMerchantId, processor: Vantiv, network for MasterCard, and required sale fields.

### Expected

- eProtect returns 200 with paypageRegistrationId and a success-style response.
- credit-card/process-card returns 200 OK with transactionId, approvalNumber, billingDescriptor, and related success fields.

### Steps

First call POST …/eProtect/paypage with the Master Paypages fields and save paypageRegistrationId.
Then POST {{URL}}/authenticate and POST {{URL}}/credit-card/process-card with Bearer auth, payPageRegistrationId, and valid MasterCard network / merchant fields.
Finally confirm Expected on both responses.

---
