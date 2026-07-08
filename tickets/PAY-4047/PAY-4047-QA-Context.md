# PAY-4047 — ach-returns: nullable Charge.Token & ApprovalNumber on ACH rows

**Bug · ach-returns · STAGE QA PASS (2026-07-08) · Fix: R9.6 · Parent: PAY-4026 · QA: Chris (PAY-4081, PAY-4082)**

Dev PR: [wellfit-payments #305](https://wellfit-technologies-inc.ghe.com/Wellfit/wellfit-payments/pull/305). Design ref: bmad-wellfit #3291 §8.5 “Bug 2”. Fixture ref: bmad #2929.

Jira: https://wellfit.atlassian.net/browse/PAY-4047

---

## Problem

`Charge.Token` and `Charge.ApprovalNumber` are **card-only** fields. On **real ACH/eCheck** payments they are **legitimately NULL**.

Pre-fix EF mapping was non-nullable → `SqlNullValueException` at `SqlDataReader.GetString()` when ach-returns loaded the row during return processing.

**Fix (PR #305):** `string?` + `.IsRequired(false)` on both fields. Dev test: `ChargeNullableCardFieldsIntegrationTests`.

---

## STAGE runbook (Jason — validated 2026-07-08)

### 1 — Anchor payment (Platform SQL)

Find a live settled ACH `'000'` payment with **NULL** `Token` and **NULL** `ApprovalNumber`, `LEN(TransactionId) <= 20`, and **no** existing `[Payments].[ReturnedPayments]` row.

```sql
SELECT TOP 5
    p.Id, p.TransactionId, p.OrderId, p.Amount,
    p.Token, p.ApprovalNumber, p.ResponseCode
FROM [Payments].[Payments] p
JOIN [Payments].[AchPaymentDetails] apd ON apd.PaymentId = p.Id
WHERE p.ResponseCode = '000'
  AND LEN(p.TransactionId) <= 20
  AND p.Token IS NULL
  AND p.ApprovalNumber IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM [Payments].[ReturnedPayments] rp
    WHERE rp.OriginalPaymentId = p.Id
  )
ORDER BY p.TimeStamp DESC;
```

If none exist, create a new test ACH payment in Stage first (Payments V2 ACH submit).

### 2 — Inject return (SQL script)

**Script:** `tickets/PAY-4047/scripts/inject-ach-return.sql`  
**DB:** `stage-platform-wellfit-sqlserver.database.windows.net` → **Platform**

| Pass | `@Commit` | Expected |
|------|-----------|----------|
| Dry run | `0` | Preview + `DRY RUN (rolled back)` — nothing persisted |
| Commit | `1` | `COMMITTED return fixture...` — pending row (`ProcessingStatus = 0`) |

Set `@PaymentId` to pin the anchor. Note commit **UTC timestamp** (5-minute lookback starts here).

### 3 — Trigger report-ingested (HTTP)

**Not** Event Grid topic `operations` (local only — does not exist in Stage).

| Item | Value |
|------|--------|
| **Function App** | `stage-wf-payments-func` |
| **Function** | `FileProcessedEvent` |
| **URL** | `https://stage-wf-payments-func.azurewebsites.net/api/FileProcessedEvent?code=<functionKey>` |
| **Auth** | Function key — `stage-wf-payments-func` → **App keys** → host key **`default`** (or Key Vault; do not commit/paste in tickets) |
| **Body** | `FileName` starting with `ECheckReturnReport_` (e.g. `ECheckReturnReport_QAFIX_<date>.CSV`); `ProcessedAt` = **UTC now** |
| **Timing** | POST within **5 minutes** of SQL insert `TimeStamp` |
| **Pass** | HTTP **200**; response includes `"EventName": "Payment.ReturnReport.Ingested"` |

**Postman:** `postman/collections/PAY-4047-FileProcessedEvent-STAGE.postman_collection.json` + env `tickets/PAY-4047/PAY-4047-FileProcessedEvent-STAGE.postman_environment.json`

### 4 — Verify PAY-4047 fix

**SQL:**

```sql
SELECT Id, OriginalPaymentId, ProcessorTransactionId,
       ReasonCode, ProcessingStatus, TimeStamp
FROM [Payments].[ReturnedPayments]
WHERE OriginalPaymentId = '<anchor PaymentId>';
```

**Pass:** `ProcessingStatus = 1` (Processed) or `3` (NeedsReview) — not `0`.

**App Insights** (`stage-insights`):

```kusto
exceptions
| where timestamp > ago(1h)
| where cloud_RoleName has "ach" or cloud_RoleName has "return"
| where outerMessage has "SqlNullValueException"
    or innermostMessage has "SqlNullValueException"
| project timestamp, operation_Id, outerMessage, cloud_RoleName
| order by timestamp desc
```

**Pass:** 0 rows in test window.

---

## STAGE QA evidence (2026-07-08)

| Run | TransactionId | OrderId | Amount | ProcessingStatus | App Insights |
|-----|---------------|---------|--------|------------------|--------------|
| 1 | `84085454800162514` | `100654830` | 44.33 | 1 | Same outcome |
| 2 | `84085205723518905` | `order-221938327191` | 35.00 | 1 | 0 `SqlNullValueException` |

Screenshots: `assets/screenshots/PAY-4047/`. Evidence in Testmo.

---

## Assets

| Asset | Path | Notes |
|-------|------|-------|
| SQL inject script | `tickets/PAY-4047/scripts/inject-ach-return.sql` | Jason fixture (bmad #2929) |
| Fixture README (dev/local) | `tickets/PAY-4047/ACH-Return-Fixture-README.md` | Local `operations` topic; Stage uses FileProcessedEvent |
| Postman collection | `postman/collections/PAY-4047-FileProcessedEvent-STAGE.postman_collection.json` | Step 3 trigger |
| Postman environment | `tickets/PAY-4047/PAY-4047-FileProcessedEvent-STAGE.postman_environment.json` | Set `functionKey` locally |
| ~~Deprecated~~ CSV + PS1 | `tickets/PAY-4047/scripts/publish-stage-ach-returns-from-csv.ps1` | Old path: `wellfit-datafactory` / `ReturnNotificationReceivedEvent` — superseded |
| QA ACH returns toolkit (QA env) | `scripts/ach-returns/` | Different env (`qa-wf-eventgrid`) |

---

## Environment reference

| Item | Value |
|------|--------|
| **Platform SQL** | `stage-platform-wellfit-sqlserver.database.windows.net` → `Platform` |
| **App Insights** | `stage-insights` — cloud roles matching `ach` / `return` |
| **Event Grid namespace** | `stage-wf-eventgrid` — topics include `wellfit-payments`, `wellfit-datafactory` (not used for this runbook) |

---

## Deprecated / do not use for PAY-4047 Stage

| Approach | Why |
|----------|-----|
| Event Grid topic **`operations`** | Does not exist in Stage (local `eventgrid-bridge` only) |
| `publish-stage-ach-returns-from-csv.ps1` → **`wellfit-datafactory`** | Different event (`ReturnNotificationReceivedEvent`); subscription delivery was blocked 2026-07-07 |

---

## Jira comment template (PASS)

```text
STAGE QA PASS — PAY-4047.

Setup: Jason Stage runbook — inject-ach-return.sql on Platform (anchor = live settled ACH '000' rows with NULL Token/ApprovalNumber). Trigger: POST stage-wf-payments-func FileProcessedEvent within 5 min of SQL commit.

Verified: HTTP 200 + EventName Payment.ReturnReport.Ingested; ReturnedPayments ProcessingStatus = 1; App Insights 0 SqlNullValueException in test window.

Dev CI: PR #305 ChargeNullableCardFieldsIntegrationTests. Evidence in Testmo.
```
