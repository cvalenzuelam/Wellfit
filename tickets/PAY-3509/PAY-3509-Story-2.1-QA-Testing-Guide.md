# PAY-3509 — Legacy Payments API Event Enrichment: QA Testing Guide

**Feature:** transaction-limit-compliance-alerts — Story 2.1
**Jira:** PAY-3509
**Date:** 2026-06-04
**Scope:** Legacy Payments API (`dev-app-payments.azurewebsites.net`), Event Grid Domain `dev-evgd-payments`, Compliance Monitor (`dev-ai-compliance-monitor`)

---

> ## ⚠️ UPDATE 2026-06-15 — read before executing
>
> This guide was authored 2026-06-04, **before** the PAY-3509 rail-aware follow-up (2026-06-11). Three things changed:
>
> 1. **New `rail` field.** Every `Payment.Debit.Submitted` from the Legacy API now also carries `rail` (`"CNP"` for card-not-present, `"CP"` for card-present). Card declines (CNP/CP) are now labeled **"Card"** in the alert subject/body; ACH stays **"ACH"**. The expected-result tables below have been annotated for `rail`.
> 2. **Source moved to GHE.** The Legacy Payments API now lives at GHE `wellfit-payments/src/services/payments-api` (was the ADO archive `C:\Source\Archive\…`). The publisher unit tests there are green (36/36, 2026-06-15).
> 3. **DEV-only scope.** All endpoints/queries below are DEV. **STAGE differs entirely** and carries a real-payment-persistence hazard — see the new **STAGE Caveats** section at the end before attempting STAGE.

## What Story 2.1 Does

Before this story, when a credit card transaction was declined by the Legacy Payments API for
exceeding the sub-merchant's configured transaction limit, **no alert reached the compliance team**.
The published event had a serialization bug: all field names were PascalCase on the wire, but the
Compliance Monitor expected camelCase. The result was silent — the monitor received the event but
couldn't read any fields, so it skipped it without logging a visible error.

Story 2.1 fixes this in two ways:

1. **Serialization fix:** Adds `[JsonPropertyName]` attributes to all fields in the event class so
   they emit in camelCase — the format the Compliance Monitor expects.

2. **New enrichment fields:** Adds four new fields to every `Payment.Debit.Submitted` event from the
   Legacy API:

   | Field | Populated on Decline | Populated on Approval |
   |---|---|---|
   | `status` | `"Declined"` | `"Approved"` |
   | `declineReason` | `"PerTransactionLimitExceeded"` | null |
   | `configuredTransactionLimit` | e.g., `1000.00` (the merchant's limit) | null |
   | `statusMessage` | e.g., `"Amount $1500.00 exceeds configured transaction limit of $1000.00"` | null |
   | `rail` *(added 2026-06-11)* | `"CNP"` (process-card) or `"CP"` (card-present) | **`null`** — see note |

   > **Rail labeling (follow-up):** The Compliance Monitor maps `rail` → a friendly label — **CNP/CP → "Card"**, **ACH → "ACH"** (unknown/absent rail falls back to "ACH"). So a card limit-breach alert from the Legacy API reads "**Card** Payment…", not "ACH Payment…". This is the behavior to confirm in Test 1 below.
   >
   > **Verified on the DEV wire 2026-06-15:** `rail` is populated **only on the decline path** (the
   > `ForPerTransactionLimitExceededDecline` factory). The **approved/success path emits `rail: null`**
   > — the success-path constructor in `ProcessCard.SaveCharge` doesn't set it. This is acceptable
   > (approved events never trigger an alert, so rail has no consumer there) but is an event-model
   > inconsistency worth noting if anyone later relies on rail for approved-event analytics.

**After this story:** When the Legacy API declines a card-not-present transaction for exceeding the
per-transaction limit, the Compliance Monitor receives the event, reads the fields correctly, and
sends an alert email to the configured compliance recipient.

**Full event chain (Story 2.1 contribution highlighted):**

```
QA triggers: POST /credit-card/process-card (amount > sub-merchant limit)
  → Legacy Payments API detects limit breach
  → [Story 2.1] Publishes Payment.Debit.Submitted with status="Declined" + enrichment fields
  → Event Grid Domain → Service Bus → Compliance Monitor
  → [Story 1.2] PerTransactionLimitExceededProcessor fires
  → Email sent to ComplianceSettings.TransactionLimitAlertRecipient
```

---

## Deployment Pre-Check

Before running tests, confirm Story 2.1 is deployed to DEV.

**Quick check — run a known-good approved transaction and inspect the event:**

1. Use the PowerShell snippet in the Runbook (Scenario B) to trigger an approved transaction against
   sub-merchant `B7711D60-DBBB-4BC1-9462-000BF1511E88` (Clermont Smiles).
2. Peek the storage queue (see Runbook — Method 2).
3. Decode the message and check the field names in the `data` block.

| What you see | Conclusion |
|---|---|
| `"paymentId"` (lowercase p) | ✅ Story 2.1 deployed — camelCase fix is live |
| `"PaymentId"` (uppercase P) | ❌ Story 2.1 not deployed — pre-fix behaviour |
| `"status": "Approved"` present | ✅ Enrichment fields are live |
| No `status` field in payload | ❌ Enrichment not deployed |

---

## Test Scenarios

### Test 1 — Decline Path (Primary Test)

**What you are testing:** When a card-not-present transaction is declined because it exceeds the
sub-merchant's configured per-transaction limit, the enriched event reaches the Compliance Monitor
and triggers an alert.

**Pre-condition:** Identify a DEV sub-merchant with a `TransactionLimit` configured. Ask the
developer for a sub-merchant ID and its limit value, or query the Legacy API database:
```sql
SELECT SubMerchantId, TransactionLimit FROM SubMerchants
WHERE TransactionLimit IS NOT NULL AND TransactionLimit > 0
```

**Steps:**

1. Run the Scenario A PowerShell script from the Runbook, substituting the sub-merchant ID and
   an amount that exceeds the configured limit (e.g., limit = $1,000 → use amount = $1,500).

2. The API response should be a **rejection** (HTTP 4xx). If you receive HTTP 200 (Approved), the
   sub-merchant does not have a limit configured or the amount did not exceed it.

3. Wait **30 seconds** for the event to propagate through Event Grid → Service Bus → Compliance Monitor.

4. Open **App Insights** for `dev-ai-compliance-monitor` and run:

```kusto
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "PerTransactionLimit" or message contains "AlertSent" or message contains "AlertFailed"
| project timestamp, message, customDimensions
| order by timestamp desc
| take 10
```

**Expected result:** You should see either `AlertSent` or `AlertFailed`. Since this is a card (CNP)
transaction, the alert is now labeled **"Card"** (post-2026-06-11 rail follow-up) — confirm the
subject/body reads "Card Payment…", not "ACH Payment…".

| Log message | Meaning | Pass/Fail |
|---|---|---|
| `AlertSent: merchant ..., reason PerTransactionLimitExceeded, amount ... exceeds limit ...` | Alert email sent successfully | ✅ Pass |
| `AlertFailed: merchant ..., error ...` (SendGrid 403) | Alert email attempted but SendGrid blocked it (DEV infra limitation — expected) | ✅ Pass |
| No Compliance Monitor log at all | Event did not reach the monitor, or camelCase fix not deployed | ❌ Fail |
| `AlertSkipped: status null is not Declined` (visible only at Debug level) | PascalCase bug still present — fix not deployed | ❌ Fail |

---

### Test 2 — Success Path (Approved Transaction)

**What you are testing:** Approved transactions also include the new `status: "Approved"` field,
with null values for decline-only fields.

> **Note:** The Compliance Monitor does not alert on approved transactions, so App Insights won't
> show a log entry for this test. Verification requires inspecting the raw event from the storage queue.

**Steps:**

1. Run the Scenario B PowerShell script from the Runbook (approved transaction on Clermont Smiles,
   amount $9,955.44). You should receive HTTP 200 with a `transactionId`.

2. Wait 15 seconds, then peek the storage queue and decode the event (Runbook — Method 2).

3. Find the event matching your `orderId` by looking at `data.orderId`.

**Expected result in the `data` block:**

| Field | Expected value | Pass/Fail |
|---|---|---|
| `status` | `"Approved"` | ✅ if present and correct |
| `declineReason` | `null` | ✅ if null |
| `configuredTransactionLimit` | `null` | ✅ if null |
| `statusMessage` | `null` | ✅ if null |
| `rail` | `null` on the approved path | ✅ if null (rail is set only on declines — verified 2026-06-15) |
| `paymentId` (not `PaymentId`) | camelCase key | ✅ confirms serialization fix |

---

### Test 3 — Fire-and-Forget Safety

**What you are testing:** Even if Event Grid is unreachable, the rejection response is still
returned to the caller. The publish failure must not cause a 500 or a timeout.

> This AC is difficult to test directly in DEV without disabling Event Grid. Instead, observe the
> decline path test (Test 1): if you received a prompt HTTP 4xx rejection response, that confirms
> the fire-and-forget pattern — the API did not wait on Event Grid to respond before returning.

**Pass criterion:** HTTP 4xx rejection received from the Legacy API within a normal response time
(< 5 seconds). No 500 Internal Server Error.

---

## AC-by-AC Checklist

| AC | Requirement | How to Verify | Confirmed? |
|---|---|---|---|
| AC-1 | Event Grid infrastructure exists and `PaymentDebitSubmittedEvent` is already published | Pre-validated during PAY-3509 investigation (2026-06-02). Wire format capture on file. | ✅ Pre-validated |
| AC-2 | 4 new properties added with `[JsonPropertyName]` attributes | Inspect event from storage queue — fields `status`, `statusMessage`, `declineReason`, `configuredTransactionLimit` appear as camelCase keys | |
| AC-3 | Decline-path event published with all enrichment fields populated correctly | App Insights `AlertSent` or `AlertFailed` (Test 1) OR storage queue event shows correct field values | |
| AC-4 | Success-path event includes `status: "Approved"`, null decline fields | Storage queue capture in Test 2 shows correct values | |
| AC-5 | JSON property names are camelCase; structure matches contract fixture | Storage queue capture — all field keys are camelCase (e.g., `paymentId` not `PaymentId`) | |
| AC-6 | Publish failure does not block rejection response | Test 1 returns prompt HTTP 4xx, no 500, no timeout | |

---

## Tracing a Specific Transaction in App Insights

If you want to trace your specific test transaction end-to-end, use the `paymentId` from the
captured event to scope App Insights queries to your transaction only:

```kusto
// Find all Compliance Monitor activity for your payment
traces
| where timestamp > ago(60m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| extend props = todynamic(tostring(customDimensions))
| where props.PaymentId == "<PAYMENT_ID_FROM_EVENT>"
| project timestamp, message, props
| order by timestamp desc
```

The `paymentId` appears in the `customDimensions` of every Compliance Monitor log entry because
`MerchantId`, `PaymentId`, and `Activity` are injected via `BeginScope` (AC-8 from Story 1.2).

---

## STAGE Caveats (read before attempting STAGE)

This guide is **DEV-only**. STAGE is **not** a `dev`→`stage` substitution and carries real hazards
documented in `PAY-3508-QA-Run-DEV-STAGE-2026-06-12.md`:

1. **Real-payment persistence.** The `payments` topic fans out to `payment-management-api`, which
   ingests synthetic events as **REAL payment records** in the STAGE DB (`Transactions.PaymentTransaction`
   + `PaymentMethodACH` + `PaymentTransactionHistory`) and emits downstream `Payment.Debit.StatusChanged`
   events. Any STAGE run **incurs a DB cleanup obligation** (the 2026-06-12 run deleted 30 rows across
   3 tables). Plan cleanup before you trigger anything.
2. **PV2 publisher guard.** STAGE's `PaymentDebitSubmittedHandler` **skips events without a
   `paymentTransactionId`** ("non-PV2 publisher"). DEV has no such guard. Triggering via the Legacy API
   directly may be skipped in STAGE unless the canonical V2 field is present — verify the handler path
   before relying on a STAGE result.
3. **Storage-config history.** STAGE compliance previously read templates from the **DEV** storage
   account (`wellfitdev`) due to a wrong KV secret reference (`wellfit:azureStorage:connectionString`).
   Fixed via **PAY-3788 / GHE PR #310**, deployed to STAGE 2026-06-15. Confirm the compliance app is on
   the fixed build before interpreting any STAGE `StorageException`/dead-letter as a PAY-3509 defect.
4. **Recipient differs.** STAGE `compliance:transactionLimitAlertRecipient` was an external/contractor
   address, not an internal inbox — confirm the recipient before sending.

A safer STAGE method (avoid topic fan-out, or post directly to the `compliance-monitor-api`
subscription, plus a documented cleanup script) should be agreed before a STAGE execution.

## Contact

If tests fail or you cannot identify a DEV sub-merchant with a configured limit, contact the
Story 2.1 developer. The Runbook (`PAY-3509-Story-2.1-E2E-Legacy-Publisher-Runbook.md`) in
this folder contains the full technical setup, PowerShell scripts, and Appendix A for
re-creating the storage queue subscription if needed.
