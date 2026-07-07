# PAY-4047 — ach-returns: nullable Charge.Token & ApprovalNumber on ACH rows

**Bug · ach-returns · Status: In Stage · Fix: R9.6 · Parent: PAY-4026 (Express Lane Q2) · QA: Chris (PAY-4081, PAY-4082)**

Jira export: `PAY-4047-Jira-Export.pdf`. Dev PR: [wellfit-payments #305](https://wellfit-technologies-inc.ghe.com/Wellfit/wellfit-payments/pull/305). Design ref: bmad-wellfit #3291 §8.5 “Bug 2”.

---

## Ticket summary

| Field | Value |
|-------|--------|
| **Type** | Bug (Priority 3) |
| **Labels** | `express-lane` |
| **Assignee (dev)** | Jason Thomas |
| **QA sub-tasks** | PAY-4082 Create test cases · PAY-4081 Test fix — **Chris** |
| **Repo / service** | `wellfit-payments` · **AchReturns.API** |

---

## Problem

`Charge.Token` and `Charge.ApprovalNumber` (`AchReturns.API/Database/Platform/Models/Charges/Charge.cs`) are **card-only** fields (vault token + auth/approval code). On **real ACH/eCheck** payments they are **legitimately NULL** on 100% of rows.

EF Core mapping (`ChargeMapping.cs`) had both as **non-nullable `string`**. Newer **Microsoft.Data.SqlClient** (via WF framework) throws when materializing those rows:

```text
SqlNullValueException: Data is Null. This method or property cannot be called on Null values.
  at SqlDataReader.GetString()
```

**Surfaced in:** ACH return / NOC fixture **e2e in Stage** — the e2e path had **sidestepped** the bug rather than proving the fix.

---

## Fix (dev)

| Change | Detail |
|--------|--------|
| Model | `Charge.Token` and `Charge.ApprovalNumber` → **`string?`** |
| Mapping | `.IsRequired(false)` on both in `ChargeMapping.cs` |
| Dev test | `AchReturns.API.Tests/Integration/ChargeNullableCardFieldsIntegrationTests.cs` — seeds `[Payments].[Payments]` with NULL Token/ApprovalNumber via raw ADO, reads via `PlatformDbContext` |

**Before fix:** integration test fails with `SqlNullValueException` (same as production).  
**After fix:** row materializes; Token and ApprovalNumber read back as **null**.

---

## What QA validates (no formal AC list in Jira — derived from Verification)

| Theme | Pass criteria |
|-------|----------------|
| **EF materialization** | ach-returns reads a **real ACH** payment row (NULL Token + NULL ApprovalNumber) **without** `SqlNullValueException` |
| **Return / NOC path** | STAGE flow that loads Charge for an ACH return or NOC **completes** (no 500 from null mapping) |
| **Regression** | Card rows with populated Token/ApprovalNumber still load correctly |
| **Observability** | No `SqlNullValueException` / `GetString` on null in App Insights for the test operation |
| **Dev-only** | Tier 1 integration test in PR #305 — cite CI; do not duplicate as manual case unless asked |

---

## Data model (SQL)

ACH payments live in **`[Payments].[Payments]`**. Card-only columns on the Charge mapping:

| Column | ACH rows | Card rows |
|--------|----------|-----------|
| **Token** | **NULL** (expected) | vault / processor token |
| **ApprovalNumber** | **NULL** (expected) | auth / approval code |

**PaymentTypeMethod** (reference): `0` = eCheck default (ACH), `1` Pay Page, `2` CNP token, etc.

### Find candidate ACH rows (Stage)

```sql
SELECT TOP 20
    Id, TransactionId, OrderId, Amount,
    Token, ApprovalNumber, PaymentType, PaymentTypeMethod, TimeStamp
FROM [Payments].[Payments]
WHERE Token IS NULL
  AND ApprovalNumber IS NULL
ORDER BY TimeStamp DESC;
```

Pick a row tied to a return/NOC scenario dev provides, or use one from a fresh ACH sale in Stage.

---

## Stage environment

| Item | Value |
|------|--------|
| **SQL** | `stage-platform-wellfit-sqlserver.database.windows.net` → **`Platform`** |
| **Service** | **ach-returns** / AchReturns.API (confirm base URL and auth with dev) |
| **App Insights** | **`stage-insights`** — cloud role likely `stage-wf-ach-returns` or similar (confirm) |
| **Related flows** | ACH return ingestion, NOC / account-updater fixture e2e (same family as PAY-3811) |
| **ACH payment API** | Payments V2 ACH submit — see `PAY-3627-STAGE-PUT-Driven` request **07** for ACH sale pattern |

### Postman (uploaded 2026-07-07)

| Asset | Path |
|-------|------|
| **PAY-2452 ACH Refunds collection** | `postman/collections/PAY-2452-ACH-Refunds-QA.postman_collection.json` |
| **Local Dev env** | `postman/environments/PAY-2452-ACH-Refunds-Local-Dev.postman_environment.json` |
| **STAGE env** | `postman/environments/PAY-2452-ACH-Refunds-STAGE.postman_environment.json` |
| **Screenshots** | `assets/screenshots/PAY-4047/` |

**Ticket note:** material uploaded as “3797 / ach returns” is **PAY-2452** (Payment Management refunds) + context for **PAY-4047** (AchReturns.API). **PAY-3797** is a different bug (v2 card **capture** drift) — not this flow.

### Services map (do not confuse)

| Service | API | PAY-4047? |
|---------|-----|-----------|
| **Payment Management API** | `POST …/api/transactions/{id}/refund` | **No** — refunds workflow (PAY-2452) |
| **AchReturns.API** | Event-driven — **`AchReturnReceivedEvent`** | **Yes** — loads `Charge` from SQL (NULL Token bug) |
| **Payments V2 API** | ACH sale | Creates payment row only |

Collection folder **8. Blocking Rule** states: bank return status requires **`AchReturnReceivedEvent`** processed first — **cannot trigger via refund POST**. That event is the **PAY-4047** exercise path; ask Jason for Stage fixture steps.

### Stage URLs (from collection + screenshots)

| Item | Value |
|------|--------|
| **Identity** | `https://stage-wf-identity-api.azurewebsites.net/connect/token` |
| **Payment Management** | `https://stage-wf-payment-management-api.azurewebsites.net` |
| **Auth client** | `WellfitPaymentManagementAPI` (secret in collection — rotate in Postman env, do not commit) |
| **Example txn id (screenshots)** | `01KS3A0CGDW7TY6C5KCW2AX857` |
| **Refund example** | `POST {{payments-management-api}}/api/transactions/{{settledAchTransactionId}}/refund` |

---

## How to test (QA flow)

### 1 — Baseline data check

First confirm the payment row you will use has **NULL** Token and ApprovalNumber in SQL (query above).

### 2 — Trigger ach-returns read path (STAGE)

Use the **return or NOC fixture path** dev documents for Stage (same e2e that originally surfaced Bug 2). Typical pattern:

1. Existing ACH payment row (NULL card fields) in `[Payments].[Payments]`.
2. Ingest **ACH return** or drive **NOC** processing so AchReturns.API loads the Charge via EF.
3. API/worker completes — **not** HTTP 500 / unhandled exception.

**Before fix:** `SqlNullValueException` in logs when loading the row.  
**After fix:** processing continues; Charge fields null in memory/response as expected.

### 3 — App Insights

Search by `operation_Id`, `transactionId`, or `PaymentId`:

```kusto
exceptions
| where timestamp > ago(2h)
| where cloud_RoleName has "ach" or cloud_RoleName has "return"
| where outerMessage has "SqlNullValueException"
    or innermostMessage has "SqlNullValueException"
    or message has "GetString"
| project timestamp, operation_Id, outerMessage, innermostMessage, cloud_RoleName
| order by timestamp desc
```

**Pass:** 0 rows for your test window after fix.

Trace the happy operation:

```kusto
requests
| where timestamp > ago(2h)
| where cloud_RoleName has "ach" or cloud_RoleName has "return"
| project timestamp, operation_Id, url, resultCode, duration
| order by timestamp desc
| take 30
```

### 4 — Card regression (optional)

Load or process a **card** payment where Token and ApprovalNumber are **non-null** — still materializes and return flow unaffected.

---

## Suggested Testmo themes (~8 cases for PAY-4082)

1. SQL — identify ACH row with NULL Token + ApprovalNumber (precondition case).
2. ACH return path — Charge loads without exception (primary fix).
3. NOC / return fixture e2e — end-to-end Stage pass (regression of Bug 2 scenario).
4. App Insights — no `SqlNullValueException` on test operation.
5. API/worker — no 500 on ACH row materialization.
6. Card payment regression — non-null Token/ApprovalNumber still OK.
7. Service health — ach-returns healthy after test run.
8. Dev integration test — PR #305 `ChargeNullableCardFieldsIntegrationTests` (note CI evidence; manual N/A).

---

## Chris session notes (2026-07-07)

| Step | Result |
|------|--------|
| SQL — ACH row NULL Token/ApprovalNumber | ✅ e.g. `Id=1ec7efc7-…`, `TransactionId=84087676722070924`, `ORD-2025-002` |
| App Insights — SqlNullValueException (30d) | Empty — no historical crash |
| App Insights — txn `84087676722070924` | Only `Payments.V2.API` + `PaymentManagement.API` (payment **created**, ach-returns **not invoked**) |
| PAY-2452 Postman | Imported — refunds on Payment Management; **not** direct ach-returns trigger |

## Blockers / sync with dev

1. **AchReturnReceivedEvent** / NOC fixture in Stage (PAY-4047 primary path) — Jason.
2. **App Insights cloud role** name for ach-returns.
3. Seed script `postman/seed-refund-test-data.sql` referenced by PAY-2452 collection — **not in repo**; Stage uses real txn ids or dev seed.

---

## Jira

https://wellfit.atlassian.net/browse/PAY-4047
