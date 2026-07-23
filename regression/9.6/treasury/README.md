# Treasury — Settlement & Funding (9.6 STAGE)

## ACH alignment (updated)

Treasury **C / D** now follow **`ACH payments-v2`** (not a guessed body):

| Item | Value |
|------|--------|
| Host | `https://stage-wf-payments-v2-api.azurewebsites.net` (`paymentsV2BaseUrl`) |
| Auth | Payments authenticate → `bearer-token` **and** `Payment-Bearer-Token` |
| Sale (primary) | Raw ACH verbal in person — routing `011075150` / account `1099999996` |
| Sale amount | `treasuryAchChargeAmount` (default **120** — not CNP `1.15`) |
| Sale headers | **`Idempotency-Key`** required (auto `achIdempotencyKey` per run) |
| Sale (optional) | Vault token `treasuryAchBankToken` (collection default GUID) |
| Refund auth | Identity `WellfitUnifiedPaymentsAPI` → `Payment-Bearer-Token` (PAY-4064 scopes) |
| Refund partial | PM refund amount `treasuryAchPartialRefundAmount` (default **0.50**) |
| Refund full (#5) | Separate ULIDs: `achFullRefundPaymentTransactionId` + `treasuryAchFullRefundAmount` |
| Treasury | `api_key` on create/send-funding-batch |

## Postman ↔ Testmo (Section D — 12 cases, 1:1)

| Postman TC | Testmo # | Case ID |
|------------|----------|---------|
| TC01 | 1 | 303923 authenticate |
| TC02 | 2 | 303924 **new** txn (seed + SQL6 + Identity + refund) |
| TC03 | 3 | 303968 **existent** txn (discovery + SQL6 + Identity + refund) |
| TC04 | 4 | 303925 status **18** SQL |
| TC05 | 5 | 303969 full refund **10** — separate txn (`achFullRefund*` env vars) |
| TC06 | 6 | 303928 SettlementDate charge + **Refunds** |
| TC07 | 7 | 303926 create-funding-batch |
| TC08 | 8 | 303927 FI on refund row |
| TC09 | 9 | 303929 Funded **5** |
| TC10 | 10 | 303930 FI FIPC/FISC |
| TC11 | 11 | 303931 send-funding-batch |
| TC12 | 12 | 303932 FundingBatches |

## Import

Prefer folder **`Wellfit Payments/`** (rebuild after regression edits).

Or Regression module inside that pack: **3 — Regression → Treasury → F (ACH Refund)**.

Treasury section order: **00 Shared** → **A/B CP** → **C/D CNP** → **E/F ACH** → **G holiday**.
