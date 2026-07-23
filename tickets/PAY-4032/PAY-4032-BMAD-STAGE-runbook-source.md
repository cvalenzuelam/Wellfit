# PAY-4032 — BMAD Chat STAGE runbook (source paste)

**Captured:** 2026-07-23  
**Source:** BMAD Chat Knowledge Base (`bmachat.com`) — adapted with Chris’s verified STAGE facts + Correct-Course / Solution / Analysis  
**Status:** Design + STAGE skeleton from BMAD. Executable version: `PAY-4032-STAGE-QA-Runbook-Executable.md`

---

## Objective

Validate Payment Management ACH retry/redeposit in STAGE after enabling `PaymentManagement:AchRetry:Enabled`.

Target flow (Solution):

1. ACH return received  
2. PM `PaymentReturnReceivedHandler.ProcessDebitReturn` evaluates eligibility  
3. PM mints retry child  
4. PM calls Wrapper `POST /api/v1/echeck/redeposits`  
5. PM emits retry event(s) (`Payment.Retry.Submitted`)  
6. `payments-func` syncs retry charge  
7. Retry child participates in settlement/funding  

Flag default **OFF** (Solution + Correct-Course).

---

## Critical risks (do not skip)

### Dual-handler double redeposit

Legacy payments-api still may subscribe to the same return event. If PM flag ON before legacy retirement → **two Worldpay redeposits / two consumer debits (NACHA violation)**.

**Gate:** legacy ACH retry OFF/retired + operators agree PM owns retry — **before** enabling PM flag.

### DTO / event contract

Wire fields: `OriginalPaymentId`, `RedepositEligible`, `ProcessorTransactionId`, `TotalRedepositAttempts`.  
Historical wrong DTO: `paymentId`, `isRetryable`, `transactionId`.  
Correct-Course: gate → `RedepositEligible`; NACHA cap → `TotalRedepositAttempts`. Dead-letter / Guid.Empty still risk until DTO fix confirmed deployed.

---

## Verified STAGE systems (from QA pack + BMAD)

| Component | Value |
|-----------|--------|
| Identity token | `https://stage-wf-identity-api.azurewebsites.net/connect/token` |
| Client | `WellfitPaymentManagementAPI` |
| PM API | `https://stage-wf-payment-management-api.azurewebsites.net` |
| Flag | `PaymentManagement:AchRetry:Enabled` on `stage-wf-payment-management-api` → Settings → Environment variables |
| Wrapper | `https://stage-wf-worldpay-wrapper-api.azurewebsites.net` |
| Redeposit | `POST /api/v1/echeck/redeposits` |
| SQL | `stage-platform-wellfit-sqlserver.database.windows.net` |
| Platform | `[Payments].[Payments]`, `[Payments].[ReturnedPayments]`, `[Payments].[AchPaymentDetails]` |
| Payments DB | `[Transactions].[PaymentTransaction]` (+ `ParentTransactionId`, `RootTransactionId`, `RetryAttempt` per solution) |

---

## BMAD step outline (high level)

1. Token (client_credentials)  
2. Confirm flag state (OFF until cutover)  
3. Confirm legacy retry retired  
4. Seed return → FileProcessedEvent within 5 min  
5. PM receives return — validate wire fields bind  
6. Retry child in PaymentTransaction  
7. Wrapper redeposit call  
8. `Payment.Retry.Submitted`  
9. payments-func Charge (Id = RedepositPaymentId)  
10. Settlement / funding progression  

Negatives: flag OFF; event replay; max retry cap (≥2).

---

## BMAD UNKNOWN gaps (for follow-up)

- Exact legacy-handler disable proof method / flag name  
- Whether final DTO reconciliation build is on STAGE  
- Exact App Insights / SB topic queries  
- Full wrapper request schema  
- Exact FileProcessedEvent tooling (filled in executable from PAY-4047)

**Primary BMAD sources cited:** Solution, Correct-Course, Analysis (ACH Information / redeposit), SyncAchCharge EventBase wrapper mismatch note.
