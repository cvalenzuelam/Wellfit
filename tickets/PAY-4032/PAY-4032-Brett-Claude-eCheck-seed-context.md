# PAY-4032 — context for Brett / Claude (eCheck seed 330)

Saved for Chris to paste to Brett later. English (US team).

---

```text
PAY-4032 — STAGE/DEV QA context for Claude: eCheck seed (1a) blocked on 330

## Goal
Complete Brett’s Part A Postman suite. Folder B (E2E Payment.Return.Received chain) is PARKED — out of scope.
Seed request 1a (POST /api/v1/echeck/sales) is OPTIONAL in the runbook, but we tried hard to unblock it so request 1 could use a real Pre-Live litleTxnId.

## What already PASSES on STAGE (Part A)
- Token: WellfitPaymentManagementAPI / Test123!, scope WorldpayWrapperAPI.Full → 200
- Wrapper host: https://stage-wf-worldpay-wrapper-api.azurewebsites.net
  (note: stage-app-worldpay-wrapper.azurewebsites.net does NOT resolve)
- Request 2: non-numeric transactionId → 200 Failed VALIDATION_ERROR ✅
- Request 3: missing TransactionId → 400 “The TransactionId field is required.” ✅
- App Insights (stage-insights): CreateEcheckSale dependency to payments.vantivprelive.com/vap/communicator/online → HTTP 200 from Vantiv
- Live redeposit path to Vantiv proven (business decline codes like 588/367 are accepted as boundary proof, same as Brett’s DEV run where fresh-sale redeposit = 367 Pass*)

## Seed 1a failure (the blocker we need help on)
POST /api/v1/echeck/sales always returns:
  HTTP 200, status Declined, responseCode 330, message “Invalid Payment Type”
  (transactionId is still minted, e.g. 84087736508895561)

Same 330 on BOTH STAGE and DEV with the same MID/Pre-Live config.

## Config compared (DEV vs STAGE) — IDENTICAL for Vantiv online
App: stage-wf-worldpay-wrapper-api vs dev-app-worldpay-wrapper
- processor__vantiv__merchantId = 01264096 (both)
- processor__vantiv__masterSubMerchantId = 01291508 (both)
- processor__vantiv__url = https://payments.vantivprelive.com/vap/communicator/online (both)
- processor__vantiv__reportGroup = Default Report Group (DEV checked)
- wellfit__featureFlags__WorldpayWrapper__ECheckEnabled = true (STAGE)
- accountId in Postman body was 01264096 (Azure merchantId) — **WRONG per Brett 2026-07-14**
  Correct: AccountId from SubMerchantAccounts where ProcessorId = 0 (shared cert `01334267`)
  Brett DEV pair: SubMerchantId `2e390000-8d7e-7ced-cade-08debd891c22` / AccountId `01334267`
  ClientId WellfitPaymentManagementAPI → Worldpay Wrapper (already confirmed)

So this is NOT “STAGE pointed at wrong URL” and NOT “missing ECheck feature flag”.
Likely root cause of 330 suite: wrong AccountId in body (payfac MID vs SubMerchantAccounts.AccountId).

## Bodies / merchants already tried (all → 330)
Bank data (Confluence eCheck approved):
  routing 011075150 / account 1099999999
  (Brett generic 011401533/1234567890 also 330 earlier)
orderSource tried: ecommerce and echeckppd
amount: 5000 cents

subMerchantId tried:
1. Redhill Wellfit GUID 159F2670-1B71-4EF6-AD30-0EBF0991E2CC
2. masterSubMerchantId 01291508 (Azure) — incorrect per BMAD; still tried early
3. Clermont Smiles Wellfit GUID b7711d60-dbbb-4bc1-9462-000bf1511e88
   (only STAGE merchant with recent ACH ResponseCode 000 in Platform DB last 180d — ACH via other rails, NOT Wrapper)
4. PAY-4077 merchant with provisioning eCheck.enabled = TRUE:
   - Wellfit GUID: 29eb0000-8d3c-7ced-1dea-08dee1003238
   - Worldpay provisionerSpecificSubMerchantId (customerId candidate): 83999715764818888
   Both → 330 on STAGE
5. Same PAY-4077 WP id 83999715764818888 on DEV wrapper → also 330

Conclusion from App Insights create-sub-merchant logs:
- Many dental merchants show eCheck.enabled: false
- PAY-4077 / KaneAI show eCheck.enabled: true in MP provisioning response
- Enabling the MP flag is NOT sufficient for Wrapper online eCheckSale under MID 01264096

Clermont has NO row in MerchantProvisioning.ProvisionedSubMerchantProviders (SQL long-shot empty).

## App Insights / logs
- STAGE: CreateEcheckSale request logged with body (Clermont / later PAY-4077); Vantiv dependency 200; business 330 in response body (XML not stored in Insights).
- DEV: search for Brett’s successful seed litleTxnId 83999769095923222 and “CreateEcheckSale” returned 0 rows (Insights not useful / not linked for that run).

## Brett’s DEV runbook proof we cannot reproduce
Run log 2026-07-13 DEV Pre-Live:
  1a eCheck sale amount 5000 → 000 Approved, litleTxnId 83999769095923222
We do not have the Postman body (especially subMerchantId) from that run in Azure logs.

## Ask for Brett / Claude
1. What exact accountId + subMerchantId (+ orderSource if not ecommerce/echeckppd) produced the DEV seed 000 / txn 83999769095923222?
2. Is there a known STAGE (or shared Pre-Live) subMerchant that can do online eCheck sales via Worldpay Wrapper under MID 01264096?
3. Or confirm QA should close Part A without 1a seed (optional) using token + validations 2/3 + live Vantiv evidence (330/367/588), and treat seed merchant enablement as a separate Worldpay/ops item.

## QA stance (unless Brett says otherwise)
Part A STAGE = PASS for ticket purposes.
1a seed = BLOCKED (env/merchant Pre-Live capability), not a PAY-4032 code defect.
Folder B = PARKED (flag OFF / legacy double-redeposit / B3 DTO rename).
```
