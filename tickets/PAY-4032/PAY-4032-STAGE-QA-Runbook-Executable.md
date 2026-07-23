# PAY-4032 — STAGE QA runbook (executable)

**Ticket:** PAY-4032 — ACH retry-mint in Payment Management  
**Built from:** BMAD Chat STAGE runbook (2026-07-23) + verified STAGE QA pack + local Postman/fixture  
**BMAD source paste:** `PAY-4032-BMAD-STAGE-runbook-source.md`  
**Companion Postman:** `PAY-4032-ach-redeposit.postman_collection.json` + `postman/PAY-4032-ACH-Redeposit-STAGE.postman_environment.json`  
**ACH return fixture:** `tickets/PAY-4047/scripts/inject-ach-return.sql` (+ FileProcessedEvent Postman from PAY-4047)

---

## Split: what you can run today vs parked

| Lane | What | Runnable now? |
|------|------|----------------|
| **Part A** | Wrapper live redeposit (`POST /api/v1/echeck/redeposits`) | **Yes** — flag-agnostic |
| **Part B** | Full PM chain (flag ON → return → child → wrapper → `Payment.Retry.Submitted` → Charge → settle) | **Only after** legacy retry OFF + DTO fix confirmed on STAGE + coordinated flag ON |

Do **not** enable `PaymentManagement:AchRetry:Enabled` until Part B gates pass (Correct-Course dual-handler risk).

---

## Preconditions (always)

### Auth (Part A + any Wrapper calls)

| Item | STAGE value |
|------|-------------|
| Token URL | `https://stage-wf-identity-api.azurewebsites.net/connect/token` |
| Grant | `client_credentials` |
| Client | `WellfitPaymentManagementAPI` |
| Secret | In Postman env (`Test123!` — STAGE test client) |
| Scope | `WorldpayWrapperAPI.Full` |

Import Postman env **PAY-4032 ACH Redeposit STAGE** → run auth request first (saves `bearerToken` to environment).

### Hosts

| App | Host |
|-----|------|
| Worldpay Wrapper | `https://stage-wf-worldpay-wrapper-api.azurewebsites.net` |
| Payment Management | `https://stage-wf-payment-management-api.azurewebsites.net` |
| payments-func | `stage-wf-payments-func` (Azure Function App) |
| SQL | `stage-platform-wellfit-sqlserver.database.windows.net` |

### Feature flag (Part B only)

1. Azure → App Service **`stage-wf-payment-management-api`**
2. **Settings → Environment variables**
3. `PaymentManagement:AchRetry:Enabled`
4. Expected default: **false / OFF** until cutover

Evidence: screenshot before/after + change ticket.

---

## Part A — Wrapper redeposit (run today)

**Goal:** Prove live Vantiv re-presentment (the HTTP surface PM will call).

1. Import collection + STAGE env; select **PAY-4032 ACH Redeposit STAGE**.
2. Auth → then eCheck sale seed (if needed) → **redeposit** using original `transactionId` / Litle id.
3. Expect Wrapper success path (Approved/Pending/Declined as Pre-Live allows) — **not** `NotImplementedException`.

Carpeta/request names: use the names in the imported collection (auth + redeposit folder). Do not invent.

Evidence: Postman status/body + `transactionId` / correlation.

Bank test data: see `STAGE-Vantiv-eCheck-test-data.md`.

---

## Part B — Full PM retry chain (gated)

### B0 — Gates (STOP if unmet)

| Gate | How |
|------|-----|
| Legacy ACH retry OFF/retired | Operator/Dev confirmation + config/deploy proof — **BMAD ask below if name unknown** |
| DTO fix on STAGE | Real return traffic binds `RedepositEligible` / no Guid.Empty dead-letter — **BMAD ask below** |
| Flag ON approved | Change ticket + screenshot |

### B1 — Seed retryable ACH return

**DB:** Platform (dropdown), **not** Payments.

1. Pick eligible ACH anchor (`ResponseCode = '000'`, AchPaymentDetails, `LEN(TransactionId) <= 20`, no existing return) — or use script auto-pick.
2. Run `tickets/PAY-4047/scripts/inject-ach-return.sql`:
   - `@Commit = 0` preview → `@Commit = 1`
   - Prefer retryable reason (e.g. R01) per AC
3. Within **5 minutes**, POST **FileProcessedEvent** on `stage-wf-payments-func` (PAY-4047 Postman + function key).

Evidence: ReturnedPayments `Id`, `ProcessorTransactionId`, `OriginalPaymentId`, timestamps.

### B2 — Assert return processed (Platform)

```sql
-- Platform DB
SELECT TOP 20 Id, TimeStamp, Amount, ReasonCode, OriginalPaymentId,
       ProcessorTransactionId, ProcessingStatus
FROM [Payments].[ReturnedPayments]
WHERE ProcessorTransactionId = '<anchor TransactionId>'
ORDER BY TimeStamp DESC;
```

Expect `ProcessingStatus` → `1` (Processed) or `3` (NeedsReview) — not stuck at `0`.

### B3 — Assert PM retry child (Payments DB)

```sql
-- Payments DB
SELECT TOP 20
  Id, PaymentTransactionId, ParentTransactionId, RootTransactionId,
  RetryAttempt, TransactionStatusId, ProcessorTransactionId, Amount,
  EntityCreatedAt, StatusTimestamp, SettlementDate, FundedDate
FROM [Transactions].[PaymentTransaction]
WHERE RootTransactionId = '<original PaymentTransaction.Id GUID>'
   OR ParentTransactionId = '<original PaymentTransaction.Id GUID>'
ORDER BY RetryAttempt, EntityCreatedAt;
```

Expect exactly **one** child with `RetryAttempt >= 1`, lineage set. Unique index intent: one row per `(RootTransactionId, RetryAttempt)`.

If **no child** with flag ON + retryable return → check dead-letter / Guid.Empty / `RedepositEligible` binding (DTO risk).

Columns above verified STAGE (`docs/guides/stage-sql-schema-verified.md`).

### B4 — Wrapper redeposit from PM

Evidence: App Insights on `stage-wf-worldpay-wrapper-api` / PM for `echeck/redeposits` or CreateEcheckRedeposit around the return window. Correlate with child id / processor txn id.

### B5 — `Payment.Retry.Submitted` + Charge mint

Correct-Course: payments-func `SyncAchChargeFunction` on `Payment.Retry.Submitted` → Charge with **`Id == RedepositPaymentId`** (child payment id).

```sql
-- Platform DB — look for charge/payment row tied to redeposit payment id
SELECT TOP 20 Id, TimeStamp, Amount, TransactionId, OrderId, ResponseCode, PaymentTypeMethod
FROM [Payments].[Payments]
WHERE Id = '<RedepositPaymentId / child payment GUID>'
ORDER BY TimeStamp DESC;
```

### B6 — Settlement / funding

Child must not stay forever APPROVED. Confirm progression toward SETTLED / FUNDED (status history / settlement events). Exact status ids: use `[Transactions].[TransactionStatus]` lookup if needed.

---

## Negatives (Part B)

| Test | Setup | Expect |
|------|--------|--------|
| Flag OFF | `AchRetry:Enabled = false` + return | No PM child, no PM-driven redeposit |
| Replay | Same return/event twice | Still one child per `(Root, RetryAttempt)` |
| Cap | `TotalRedepositAttempts >= 2` | No additional mint/redeposit |
| Dual-handler | Flag ON + legacy still ON | **Fail** if two redeposits — environment unsafe |

---

## Evidence checklist (Testmo)

- [ ] Flag screenshot (OFF or approved ON)
- [ ] Legacy-off proof
- [ ] Part A Postman redeposit result
- [ ] Inject SQL + FileProcessedEvent 200
- [ ] ReturnedPayments status
- [ ] PaymentTransaction parent + child (+ RetryAttempt)
- [ ] Wrapper / App Insights redeposit evidence
- [ ] Charge / Payments row for RedepositPaymentId (if Part B)
- [ ] Settlement progression (if Part B)
- [ ] No duplicate redeposit

---

## Still ask BMAD (open gaps)

Use Knowledge Base prompts in chat with Chris when starting Part B — see agent rule `wellfit-qa-ask-bmad-for-context.mdc`.
