# PAY-3509 Story 2.1 — E2E Runbook: Legacy Payments API Publisher Verification

| Field | Value |
|---|---|
| Feature | Transaction Limit Compliance Alerts |
| Story | 2.1 — Legacy Payments API: Enrich Payment.Debit.Submitted with Status Fields |
| Jira | PAY-3509 |
| Runbook Status | Ready to execute |
| Test Type | Live API trigger + Event Grid payload capture / App Insights indirect verification |
| Environment | Azure DEV (`Development` — `22d04286-db4f-411f-bfa5-da1aea40c19e`) |
| Author | Testing Automation Agent (Tony) |
| Date Authored | 2026-06-04 |
| Dependency | Story 1.2 (PAY-3508) must be deployed — Compliance Monitor used for indirect AC verification |

---

> ## ⚠️ UPDATE 2026-06-15 — read before executing
>
> Authored 2026-06-04, **before** the PAY-3509 rail-aware follow-up (2026-06-11). Changes since:
> - **New `rail` field** on every `Payment.Debit.Submitted` (`"CNP"` / `"CP"` from the Legacy card paths). Alert labeling is now **CNP/CP → "Card"**, ACH → "ACH". Pass-criteria JSON below is annotated for `rail`.
> - **Source migrated to GHE.** The Legacy Payments API is now at GHE `wellfit-payments/src/services/payments-api` (was ADO archive `C:\Source\Archive\…`). Publisher unit tests green there: **36/36 (2026-06-15)**.
> - **DEV-only.** STAGE differs entirely and persists real payments — see the new **STAGE Caveats** section at the end before any STAGE attempt.

## Discovery Summary

Discovery was completed during Story 2.1 investigation and is fully documented in
`PAY-3509-Live-Wire-Format-Capture.md`. Findings are summarised here.

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — Manual Testing | ✅ Complete | Live `POST /credit-card/process-card` captured in DEV (2026-06-02). Both outbound events captured on-wire. Auth flow and sub-merchant documented. |
| Phase 2 — Frontend Code Review | N/A | Backend-only feature. No UI surface, no Playwright E2E. |
| Phase 3 — Backend Code Review | ✅ Complete | Source files identified in Legacy Payments API repo. PascalCase emission confirmed (Finding #2). Publisher seams mapped. |
| Phase 4 — Architecture Mapping | ✅ Complete | Two publishers, two Event Grid resources. CloudEvents V1 flat envelope confirmed for `Payment.Debit.Submitted`. See ADR-002 rev. 2026-04-30. |
| Phase 5 — Pre-conditions | ✅ Documented | Auth: `WellfitAutomation/Test123!`. Duplicate gate: 10-minute window, use unique `orderId`. Storage queue infrastructure documented. |

**Key pre-fix finding (what Story 2.1 fixes):**
`Payment.Debit.Submitted` data fields emit PascalCase because `PaymentDebitSubmittedEvent.cs` has no
`[JsonPropertyName]` attributes. `Azure.Messaging.CloudEvent` serializes data via default STJ →
PascalCase wire. Compliance Monitor consumer uses case-sensitive STJ with `[JsonPropertyName("camelCase")]`
→ all fields deserialize to null → `status == null` → silent `AlertSkipped` at Debug level (not
visible in App Insights). Story 2.1 adds `[JsonPropertyName]` to all 22+ properties of the event
class, fixing the wire format.

---

## Code Changes Under Test

Story 2.1 modifies the **Legacy Payments API**, now authoritative in GHE at
`wellfit-payments/src/services/payments-api/` (was ADO archive `C:\Source\Archive\Wellfit\Services\Payments API\`,
which predates the rail follow-up — do not verify against it):

| Change | File | What to Verify |
|---|---|---|
| `[JsonPropertyName]` on all event fields | `PaymentDebitSubmittedEvent.cs` | All 27 properties emit camelCase on wire |
| 4 new enrichment properties | `PaymentDebitSubmittedEvent.cs` | `status`, `statusMessage`, `declineReason`, `configuredTransactionLimit` present in payload |
| **`rail` field** *(follow-up 2026-06-11)* | `PaymentDebitSubmittedEvent.cs` + 3 card sites | `rail` present; stamped `CNP` (ProcessCard, ChargeCnpService) / `CP` (ChargeCardPresent) |
| Decline-path publish call | `ProcessCard.SaveCharge` (inside limit check, before throw) | Event published on declined transactions with enrichment fields populated |
| Success-path publish update | `ProcessCard.SaveCharge` (existing publish point) | Event includes `status: "Approved"`, null decline fields |
| STJ NuGet added | `Patolus.Payments.Application.csproj` | Compile prerequisite — no direct verification needed |

---

## Environment & Infrastructure

### Endpoints

| Resource | URL |
|---|---|
| Legacy Payments API (direct) | `https://dev-app-payments.azurewebsites.net` |
| Auth endpoint | `POST https://dev-app-payments.azurewebsites.net/authenticate` |
| Payment endpoint | `POST https://dev-app-payments.azurewebsites.net/credit-card/process-card` |
| App Insights | Azure Portal → `dev-ai-compliance-monitor` (Compliance Monitor logs) |

### Event Grid Infrastructure

| Resource | Purpose |
|---|---|
| EG Domain `dev-evgd-payments` / topic `payments` | `Payment.Debit.Submitted` is published here |
| EG subscription `e2e-brett-debit-capture` | Temp subscription to storage queue (may still be live from PAY-3509 capture — check before recreating) |
| Storage queue `e2e-brett-debit-capture` | In storage account `stplatdev1`, RG `dev-rg-plat-data-wus3` |
| SB topic `payments` / subscription `compliance-monitor-api` | Compliance Monitor receives events via Service Bus (EGD→SB delivery) |

### Known Infrastructure Notes

- EG Domain topics are **push-only** — no data-plane `:receive` endpoint. Capture requires a push
  destination (Storage Queue) set up in advance.
- `Payment.Debit.Submitted` filter: `filter.includedEventTypes: ["Payment.Debit.Submitted"]`
- Storage queue messages are base64-encoded. Decode before reading.
- The existing temp subscription `e2e-brett-debit-capture` may still be live. Verify before creating
  a duplicate.

---

## Pre-Conditions

### 1. Deployment Check

Verify Story 2.1 is deployed to DEV. Confirm `PaymentDebitSubmittedEvent.cs` in the deployed Legacy
API build includes the `[JsonPropertyName]` attributes.

Run a test approved transaction (Scenario B below) and capture the event from the storage queue.
If the `paymentId` field appears as `paymentId` (camelCase) rather than `PaymentId` (PascalCase),
Story 2.1 is deployed.

### 2. Sub-Merchant with Configured Limit

**Required for Scenario A (decline path).** Identify a DEV sub-merchant that has a
`TransactionLimit` configured in the Legacy Payments API database. Options:

- Query the Legacy Payments API database: `SELECT SubMerchantId, TransactionLimit FROM SubMerchants WHERE TransactionLimit IS NOT NULL AND TransactionLimit > 0`
- Ask the dev who implemented Story 2.1 which sub-merchant they used for local testing.
- If `B7711D60-DBBB-4BC1-9462-000BF1511E88` (Clermont Smiles) has no limit configured, use a
  different sub-merchant.

Store the sub-merchant's `TransactionLimit` value — your test `amount` must exceed it.

### 3. Storage Queue Subscription

Confirm the `e2e-brett-debit-capture` subscription still exists:

```powershell
az eventgrid event-subscription show `
  --name e2e-brett-debit-capture `
  --source-resource-id "/subscriptions/22d04286-db4f-411f-bfa5-da1aea40c19e/resourceGroups/dev-rg-plat-core-wus3/providers/Microsoft.EventGrid/domains/dev-evgd-payments/topics/payments"
```

If it does not exist, create it (see Appendix A).

---

## Test Scenarios

### Scenario A — Decline Path: Amount Exceeds Configured Limit

**Validates:** AC-2, AC-3, AC-5, AC-6

**Goal:** Legacy API publishes `Payment.Debit.Submitted` with `status: "Declined"`, correct
enrichment fields, camelCase keys. Compliance Monitor detects it and logs `AlertSent`/`AlertFailed`.

```powershell
# 1. Authenticate
$auth = Invoke-RestMethod `
  -Uri "https://dev-app-payments.azurewebsites.net/authenticate" `
  -Method POST -ContentType "application/json" `
  -Body (@{username="WellfitAutomation"; password="Test123!"} | ConvertTo-Json)
$tk = $auth.bearerToken

# 2. Set test parameters — replace with your sub-merchant and an amount that exceeds the limit
$subMerchantId = "<SUB_MERCHANT_ID_WITH_CONFIGURED_LIMIT>"
$testAmount    = <LIMIT + 500>   # e.g., if limit is $1000.00, use 1500.00

# 3. Trigger decline (unique orderId avoids 10-minute duplicate gate)
$orderId = "E2E-PAY3509-$(Get-Date -Format 'HHmmss')-$(Get-Random -Maximum 9999)"
$body = @{
  subMerchantId  = $subMerchantId
  token          = "2161645042264113"
  expirationDate = "1227"
  cvv            = "123"
  zipCode        = "12345"
  amount         = $testAmount
  orderId        = $orderId
  orderIdType    = "E2E PAY-3509"
  source         = "PM"
  metadata       = "{'e2e':'pay-3509-decline-path'}"
} | ConvertTo-Json

try {
  Invoke-RestMethod `
    -Uri "https://dev-app-payments.azurewebsites.net/credit-card/process-card" `
    -Method POST `
    -Headers @{Authorization="Bearer $tk"} `
    -ContentType "application/json" `
    -Body $body
} catch {
  # Expect HTTP 422/400 — limit breach returns a rejection response
  Write-Host "Response: $($_.Exception.Response.StatusCode) — expected for limit breach"
  Write-Host $_.ErrorDetails.Message
}

Write-Host "OrderId used: $orderId"
```

**Expected API response:** HTTP 4xx (rejection). The transaction should be declined. Note the exact
status code — if you receive HTTP 200 (Approved), the sub-merchant's limit is not configured or the
amount did not exceed it.

**Wait 15–30 seconds**, then proceed to verification.

---

### Scenario B — Success Path: Approved Transaction

**Validates:** AC-4

**Goal:** Legacy API approved transaction publishes `Payment.Debit.Submitted` with `status: "Approved"`
and null decline fields. Also used as the deployment pre-check (camelCase field verification).

```powershell
# 1. Authenticate (reuse $tk from Scenario A if still valid, or re-auth)
$auth = Invoke-RestMethod `
  -Uri "https://dev-app-payments.azurewebsites.net/authenticate" `
  -Method POST -ContentType "application/json" `
  -Body (@{username="WellfitAutomation"; password="Test123!"} | ConvertTo-Json)
$tk = $auth.bearerToken

# 2. Trigger approved transaction — Clermont Smiles (no limit breach)
$orderId = "E2E-PAY3509-APPR-$(Get-Date -Format 'HHmmss')-$(Get-Random -Maximum 9999)"
$body = @{
  subMerchantId  = "B7711D60-DBBB-4BC1-9462-000BF1511E88"   # Clermont Smiles — approved in prior capture
  token          = "2161645042264113"
  expirationDate = "1227"
  cvv            = "123"
  zipCode        = "12345"
  amount         = 9955.44
  orderId        = $orderId
  orderIdType    = "E2E PAY-3509"
  source         = "PM"
  metadata       = "{'e2e':'pay-3509-success-path'}"
} | ConvertTo-Json

$result = Invoke-RestMethod `
  -Uri "https://dev-app-payments.azurewebsites.net/credit-card/process-card" `
  -Method POST `
  -Headers @{Authorization="Bearer $tk"} `
  -ContentType "application/json" `
  -Body $body

Write-Host "Approved — transactionId: $($result.transactionId)"
Write-Host "OrderId used: $orderId"
```

**Expected API response:** HTTP 200 with `transactionId`. Wait 15–30 seconds, then capture from
storage queue (Verification Method 2) to verify the event includes `status: "Approved"` with
camelCase field keys.

---

## Verification

### Method 1 — Indirect via App Insights (Scenario A only)

**Simplest.** If the camelCase fix works, the Compliance Monitor will deserialize `status: "Declined"`
correctly and attempt to send an alert. If PascalCase bug is still present, `status` deserializes
to null → silent Debug-level skip (not visible).

```kusto
// Run in App Insights Logs blade for dev-ai-compliance-monitor
// Replace <YOUR_PAYMENT_ID> with the paymentId from the captured event (or search by time window)
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "PerTransactionLimit" or message contains "AlertSent" or message contains "AlertFailed" or message contains "AlertSkipped"
| project timestamp, message, customDimensions
| order by timestamp desc
| take 20
```

**Pass criteria:**
- `AlertSent` or `AlertFailed` → Story 2.1 fix working. `AlertFailed` (SendGrid 403 in DEV) is
  still a pass — it proves the event was deserialized and the alert path executed. This matches
  PAY-3508 E2E Run 2 behaviour.
- `AlertSkipped: status null is not Declined` at Debug level (not visible in App Insights) or
  no Compliance Monitor log at all → camelCase fix not deployed or not working.

```kusto
// Scope to your specific test by orderId (correlate paymentId first from the event)
traces
| where timestamp > ago(60m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| extend props = todynamic(tostring(customDimensions))
| where props.PaymentId == "<YOUR_PAYMENT_ID>"
| project timestamp, message, props
| order by timestamp desc
```

---

### Method 2 — Direct Event Capture via Storage Queue (Scenarios A and B)

**Required for AC-5 (camelCase field verification) and Scenario B (success path).**

```powershell
# Peek messages from the storage queue
$messages = az storage message peek `
  --queue-name e2e-brett-debit-capture `
  --account-name stplatdev1 `
  --account-key "<STORAGE_ACCOUNT_KEY>" `
  --num-messages 10 `
  | ConvertFrom-Json

foreach ($msg in $messages) {
  $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($msg.content))
  $event   = $decoded | ConvertFrom-Json
  Write-Host "--- Event ---"
  Write-Host "type:       $($event.type)"
  Write-Host "time:       $($event.time)"
  Write-Host "data keys:  $($event.data.PSObject.Properties.Name -join ', ')"
  Write-Host ($event.data | ConvertTo-Json -Depth 5)
}
```

**Pass criteria for Scenario A (decline):**
```json
// data field keys should be camelCase (not PascalCase)
{
  "paymentId": "...",           // ✅ camelCase (was PaymentId pre-fix)
  "status": "Declined",         // ✅ new field, present
  "declineReason": "PerTransactionLimitExceeded",  // ✅ new field, present
  "configuredTransactionLimit": <limit_value>,     // ✅ new field, present
  "statusMessage": "Amount $X.XX exceeds configured transaction limit of $Y.YY",  // ✅ new field
  "rail": "CNP",                // ✅ follow-up field (CNP for process-card; CP for card-present) → alert labels "Card"
  "subMerchantAccountId": "...", // ✅ camelCase (was SubMerchantAccountId pre-fix)
  "amount": <test_amount>,
  ...
}
```

**Pass criteria for Scenario B (approved):**
```json
{
  "paymentId": "...",            // ✅ camelCase
  "status": "Approved",          // ✅ new field, present
  "statusMessage": null,         // ✅ null on success path
  "declineReason": null,         // ✅ null on success path
  "configuredTransactionLimit": null,  // ✅ null on success path
  "rail": null,                  // ✅ null on the approved path — rail is set ONLY on declines
                                 //    (verified DEV wire 2026-06-15; ProcessCard success ctor doesn't pass rail)
  ...
}
```

**Fail criteria (bug still present):**
```json
{
  "PaymentId": "...",            // ❌ PascalCase — fix not deployed
  // status, declineReason, configuredTransactionLimit fields absent entirely
}
```

---

## AC Validation Checklist

| AC | Description | How to Verify | Pass Signal |
|---|---|---|---|
| AC-1 | Decision Tree: Event Grid infrastructure exists, `PaymentDebitSubmittedEvent` already published | ✅ Already validated during PAY-3509 investigation (2026-06-02). Wire capture confirmed. | Pre-validated |
| AC-2 | Event model: 4 new properties with `[JsonPropertyName]` | Storage queue capture — verify `status`, `statusMessage`, `declineReason`, `configuredTransactionLimit` appear as camelCase keys | Fields present with camelCase keys |
| AC-3 | Decline-path publish: event published with decline fields populated | Scenario A + App Insights `AlertSent`/`AlertFailed` OR storage queue capture shows decline fields | `AlertSent`/`AlertFailed` in App Insights OR correct fields in captured event |
| AC-4 | Success-path: `status: "Approved"`, null decline fields | Scenario B + storage queue capture | `status: "Approved"`, other three fields null |
| AC-5 | Contract alignment: JSON matches fixture schema, camelCase property names | Storage queue capture — compare all field names against expected camelCase schema | All 22+ fields camelCase, new fields match ADR-002 schema |
| AC-6 | Fire-and-forget: publish failure does not block rejection response | Observe Scenario A API response — rejection must be returned even if EG is slow | HTTP 4xx rejection returned promptly (not a timeout or 500) |

---

## STAGE Caveats (read before attempting STAGE)

This runbook is **DEV-only** — every endpoint, resource id, and the `e2e-brett-debit-capture`
subscription above are DEV. STAGE is **not** a `dev`→`stage` substitution (naming differs entirely).
Hazards documented in `PAY-3508-QA-Run-DEV-STAGE-2026-06-12.md`:

| Hazard | Detail | Mitigation before STAGE run |
|---|---|---|
| **Real-payment persistence** | The `payments` topic fans out to `payment-management-api`, which ingests synthetic events as **REAL** `Transactions.PaymentTransaction` / `PaymentMethodACH` / `PaymentTransactionHistory` rows in STAGE and emits downstream `Payment.Debit.StatusChanged`. | Plan DB cleanup up front (2026-06-12 run deleted 30 rows / 10 paymentIds). Prefer a method that avoids topic fan-out (e.g. post directly to the `compliance-monitor-api` subscription) or use a dedicated test topic. |
| **PV2 publisher guard** | STAGE `PaymentDebitSubmittedHandler` **skips events without `paymentTransactionId`** ("non-PV2 publisher"). DEV has no guard. | A Legacy-API-triggered event may be skipped in STAGE; confirm the handler path / include the canonical V2 field if injecting. |
| **Storage-config history** | STAGE compliance previously read templates from the **DEV** account (`wellfitdev`) → 404 → `StorageException` → dead-letter. Fixed via **PAY-3788 / GHE PR #310**, deployed STAGE 2026-06-15. | Confirm the compliance app is on the fixed build before treating any STAGE `StorageException`/DLQ growth as a PAY-3509 defect. |
| **Recipient differs** | STAGE `compliance:transactionLimitAlertRecipient` was an external/contractor address. | Confirm recipient before sending. |
| **No STAGE infra defined here** | STAGE EG/SB/storage resource ids are not in this runbook. | Discover STAGE resources first; do not blind-substitute DEV ids. |

**Bottom line:** a STAGE execution needs a safe method + a documented cleanup script agreed in advance.
Do not run the DEV scenarios above against STAGE verbatim.

## Environment caveats verified 2026-06-15 (Tony)

Discovered while attempting a live DEV run:

- **The capture queue/subscription is ephemeral.** `e2e-brett-debit-capture` (queue + EG subscription) from the 2026-06-02 capture has been **cleaned up** — the queue no longer exists in `stplatdev1`. Re-create per Appendix A each run.
- **EG domain RG corrected.** `dev-evgd-payments` lives in **`dev-rg-plat-core-wus3`** (westus3), *not* `dev-rg-plat-data-wus3` (which is the storage account's RG). The `--source-resource-id` paths above/below have been corrected.
- **`az eventgrid event-subscription` is broken on this operator's CLI host** (az 2.76.0): every `create`/`show` returns `MissingSubscription: …or a valid tenant level resource provider`, despite `Microsoft.EventGrid` being Registered and `--subscription` passed explicitly. Storage + `eventgrid domain` commands work. **Workaround:** create the capture subscription via the **Azure Portal** (Event Grid Domain → topic `payments` → + Event Subscription → Storage Queue endpoint), or from a host with a working CLI.
- **App Insights CLI path unavailable** here — the `application-insights` az extension fails to install (pip crash). Use the **Portal Logs blade** for the Method-1 indirect (decline) queries.
- **Scenario A still needs a DEV sub-merchant with a configured `TransactionLimit`** — none is seeded in repo config; obtain from the Legacy DB or the dev.

## Appendix A — Re-create Storage Queue Subscription (if needed)

```powershell
# Create the storage queue
az storage queue create `
  --name e2e-pay3509-debit-capture `
  --account-name stplatdev1

# Create EG event subscription
az eventgrid event-subscription create `
  --name e2e-pay3509-debit-capture `
  --source-resource-id "/subscriptions/22d04286-db4f-411f-bfa5-da1aea40c19e/resourceGroups/dev-rg-plat-core-wus3/providers/Microsoft.EventGrid/domains/dev-evgd-payments/topics/payments" `
  --endpoint-type storagequeue `
  --endpoint "/subscriptions/22d04286-db4f-411f-bfa5-da1aea40c19e/resourceGroups/dev-rg-plat-data-wus3/providers/Microsoft.Storage/storageAccounts/stplatdev1/queueServices/default/queues/e2e-pay3509-debit-capture" `
  --included-event-types "Payment.Debit.Submitted" `
  --event-delivery-schema cloudeventschemav1_0
```

**Cleanup after testing:**
```powershell
az eventgrid event-subscription delete `
  --name e2e-pay3509-debit-capture `
  --source-resource-id "/subscriptions/22d04286-db4f-411f-bfa5-da1aea40c19e/resourceGroups/dev-rg-plat-core-wus3/providers/Microsoft.EventGrid/domains/dev-evgd-payments/topics/payments"

az storage queue delete `
  --name e2e-pay3509-debit-capture `
  --account-name stplatdev1
```
