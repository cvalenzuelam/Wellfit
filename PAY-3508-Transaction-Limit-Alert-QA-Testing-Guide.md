# PAY-3508 — ACH Per-Transaction Limit Compliance Alert: QA Testing Guide

**Feature:** transaction-limit-compliance-alerts — Story 1.2  
**Jira:** PAY-3508  
**Date:** 2026-05-29 — **Updated 2026-06-11** for PAY-3508 follow-ups: #257 (sub-merchant name resolution) + #261 (subject consistency)  
**Scope:** compliance-monitor-ms, Service Bus (`payments` topic / `compliance-monitor-api` subscription), SendGrid email

---

## What This Feature Does

When a Payments V2 ACH transaction is declined because it exceeds the sub-merchant's configured
per-transaction limit, the Compliance Monitor sends an email alert to the compliance team.

**Full event chain:**

```
Payments V2 ACH payment submitted
  → Enforcement layer evaluates per-transaction limit
  → Declined with declineReason: "PerTransactionLimitExceeded"
  → Event Grid Domain (dev-evgn-plat) publishes Payment.Debit.Submitted
  → Service Bus topic: payments / subscription: compliance-monitor-api
  → PaymentDebitSubmittedHandler → PerTransactionLimitExceededProcessor
  → Email sent to ComplianceSettings.TransactionLimitAlertRecipient
```

**The processor only fires for the specific case it owns.** Three guard checks run in order:
1. Status must be `"Declined"` — else silent skip at Debug level (AC-1)
2. Decline reason must be `"PerTransactionLimitExceeded"` — else Information-level skip (AC-3)
3. Configured limit must be present — else Information-level skip (AC-4)

If all three pass: email is generated with merchant ID, attempted amount, configured limit,
and percentage above limit, then sent to the configured recipient (AC-2, AC-5, AC-7). Scoped
logging on every path includes `Activity`, `MerchantId`, and `PaymentId` (AC-8).

---

## Deployment Pre-Check

**Before starting:** Verify Story 1.2 is deployed to DEV. If the old Story 1.1 skeleton is
running, none of the skip/sent/failed log messages will appear.

```bash
# Run a quick App Insights query — check which log pattern is emitting for recent events
# If you see "PerTransactionLimitExceededProcessor received..." — Story 1.1 skeleton is running
# If you see "AlertSent" or "AlertSkipped" — Story 1.2 is deployed
```

In the [App Insights Logs blade](#tracing-the-pipeline-in-app-insights), run:

```kusto
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "PerTransactionLimit"
| project timestamp, message
| order by timestamp desc
| take 10
```

- `PerTransactionLimitExceededProcessor received...` → ❌ **Story 1.1 skeleton** — stop, wait for deployment
- `AlertSent` / `AlertSkipped` / `AlertFailed` → ✅ **Story 1.2 deployed** — continue

---

## Email Template Pre-Check

Story 1.2 generates the alert email from an HTML template stored in DEV blob storage. If the
template blob is missing, the email content service will throw `StorageException: The specified
blob does not exist` and the alert will log `AlertFailed` instead of `AlertSent`.

Verify the template exists:

```bash
az storage blob exists \
  --account-name stwfdev1 \
  --container-name compliance-monitor \
  --name templates/email-compliance-ach-per-transaction-limit-exceeded.html \
  --auth-mode login \
  --query "exists" -o tsv
```

If `false`, upload it from the **wellfit-resources** repo (the templates were rehomed there in PR #240 — they no longer live in wellfit-payments):

```bash
az storage blob upload \
  --account-name stwfdev1 \
  --container-name compliance-monitor \
  --name templates/email-compliance-ach-per-transaction-limit-exceeded.html \
  --file "<path-to-wellfit-resources>/Content/BlobStorage/BlobStorage/compliance-monitor/templates/email-compliance-ach-per-transaction-limit-exceeded.html" \
  --auth-mode login
```

---

## Prerequisites

### Access

- [ ] `az login` to the Wellfit dev Azure account (DEV subscription `22d04286-db4f-411f-bfa5-da1aea40c19e`)
- [ ] Access to the `brett.roy@wellfit.com` inbox — or wherever `compliance:transactionLimitAlertRecipient` points in DEV (verify in Step 1 below)
- [ ] App Insights access: **dev-appi-westus3** (AppId `79a7536e-dce8-4e75-bea9-7d602e8e9851`) in the Azure portal
- [ ] Optional (Full E2E only): Access to `WellfitPaymentsV2API.Full` scope — ask Jason if you don't have it; SB injection works without it

### Tools

- Azure CLI (`az`) — for SAS token and App Insights queries
- PowerShell or Git Bash — injection commands below are PowerShell; Git Bash also works for `curl`
- SQL Server Management Studio or Azure Data Studio — optional, for SQL verification
- Email client for the `TransactionLimitAlertRecipient` inbox

---

## Step 1 — Confirm DEV App Settings

Verify the `TransactionLimitAlertRecipient` is configured and note where to check for the email:

```bash
az webapp config appsettings list \
  --name dev-app-compliancemonitor \
  --resource-group dev-rg-plat-api-wus3 \
  --query "[?name=='compliance:transactionLimitAlertRecipient']" \
  -o json
```

Expected: a non-empty email address.

> **Note:** After env-app-settings PR #245 is merged and deployed, this key will always be present from the environment config — no manual `az webapp config appsettings set` needed. If testing before PR #245 lands, set it manually:

```bash
az webapp config appsettings set \
  --name dev-app-compliancemonitor \
  --resource-group dev-rg-plat-api-wus3 \
  --settings "compliance:transactionLimitAlertRecipient=brett.roy@wellfit.com"
```

Then restart the app (required — setting is read at startup via `IOptions<T>`):

```bash
az webapp restart \
  --name dev-app-compliancemonitor \
  --resource-group dev-rg-plat-api-wus3
# Wait ~30 seconds for health check
curl -s "https://dev-app-compliancemonitor.azurewebsites.net/health"
# Expected: Ok
```

> **Warning:** Redeployment resets app settings to the environment config. If you apply the setting manually, re-verify after any deployment restarts.

Record the recipient address — you will check this inbox in Step 7.

---

## Step 2 — Get SAS Token (PowerShell)

The Azure CLI cannot send Service Bus messages directly. Use the REST API with an HMAC-SHA256
SAS token. Run this in PowerShell:

```powershell
$conn = az servicebus namespace authorization-rule keys list `
  --resource-group dev-rg-plat-core-wus3 `
  --namespace-name dev-sbns-payments-westus3 `
  --name RootManageSharedAccessKey `
  --query "primaryConnectionString" -o tsv

$keyName = ($conn -split ';' | Where-Object { $_ -match 'SharedAccessKeyName=' }) -replace 'SharedAccessKeyName=',''
$keyValue = ($conn -split ';' | Where-Object { $_ -match 'SharedAccessKey=' }) -replace 'SharedAccessKey=',''

$uri = [System.Uri]::EscapeDataString("https://dev-sbns-payments-westus3.servicebus.windows.net/payments")
$expiry = [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeSeconds()
$stringToSign = "$uri`n$expiry"

$hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($keyValue))
$sig = [System.Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))
$sigEnc = [System.Uri]::EscapeDataString($sig)

$global:SAS_TOKEN = "SharedAccessSignature sr=$uri&sig=$sigEnc&se=$expiry&skn=$keyName"
Write-Output "Token ready (expires in 2 hours)"
```

This stores the token in `$SAS_TOKEN` for use in injection steps below.

---

## Step 3 — Note Baseline SB Queue State

```bash
az servicebus topic subscription show \
  --resource-group dev-rg-plat-core-wus3 \
  --namespace-name dev-sbns-payments-westus3 \
  --topic-name payments \
  --name compliance-monitor-api \
  --query "countDetails" -o json
```

Record the `deadLetterMessageCount` — this is your baseline. Any increase after injection
that comes from your test `paymentId`s is a failure. Increases from pre-existing `Payment.Void.Submitted`
messages are normal and should be ignored.

---

## Step 4 — Inject Test Messages

> **Why SB injection instead of a real payment?** The SB injection approach (validated in
> Story 1.1's live test) bypasses the need for a payment client scope and a real merchant with
> a configured limit. It tests the processor logic directly and produces the same observable
> outputs. See **Full E2E Path** below if you want to trigger the full chain via a real payment.

> **Critical:** The `Label` field in `BrokerProperties` must be set to `Payment.Debit.Submitted`.
> Without it, the Wellfit Framework reads `message.Subject = null` and dead-letters the message
> (confirmed root cause from Story 1.1 Run 1).

Run all five injections in PowerShell (continue in the same session as Step 2):

```powershell
$url = "https://dev-sbns-payments-westus3.servicebus.windows.net/payments/messages"
$brokerProps = '{"Label":"Payment.Debit.Submitted","ContentType":"application/cloudevents+json"}'

# Choose fresh GUIDs for this run so you can isolate your entries in App Insights
# These defaults work; replace with New-Guid output if you want unique per-run IDs
$paymentA = "ee000001-0001-0001-0001-000000000001"  # Approved — AC-1 skip
$paymentB = "ee000001-0002-0002-0002-000000000002"  # Declined + PerTxLimit — email alert (AC-2)
$paymentC = "ee000001-0003-0003-0003-000000000003"  # Declined + DailyLimit — wrong reason (AC-3)
$paymentD = "ee000001-0004-0004-0004-000000000004"  # Declined + PerTxLimit + null limit (AC-4)
$paymentE = "ee000001-0005-0005-0005-000000000005"  # Declined + PerTxLimit + $0 limit — N/A percentage (AC-5 edge)
$merchant = "ff000001-0001-0001-0001-000000000001"        # subMerchantAccountId
$subMerchantId = "ff000001-aaaa-aaaa-aaaa-000000000001"   # parent SubMerchant.Id — drives "Name (Id)" (PAY-3508 #257)
$subMerchantName = "BMR Test Clinic"                      # sub-merchant display name (PAY-3508 #257)

$messages = [ordered]@{
    "MSG-A (AC-1 Approved skip)" = "{`"specversion`":`"1.0`",`"type`":`"Payment.Debit.Submitted`",`"source`":`"wellfit-payments-v2-api`",`"id`":`"test-3508-msg-a`",`"time`":`"2026-05-29T12:00:00Z`",`"datacontenttype`":`"application/json`",`"data`":{`"paymentId`":`"$paymentA`",`"subMerchantAccountId`":`"$merchant`",`"amount`":500.00,`"currency`":`"USD`",`"rail`":`"ACH`",`"status`":`"Approved`",`"timeStamp`":`"2026-05-29T12:00:00Z`"}}"
    "MSG-B (AC-2 Email alert)"   = "{`"specversion`":`"1.0`",`"type`":`"Payment.Debit.Submitted`",`"source`":`"wellfit-payments-v2-api`",`"id`":`"test-3508-msg-b`",`"time`":`"2026-05-29T12:01:00Z`",`"datacontenttype`":`"application/json`",`"data`":{`"paymentId`":`"$paymentB`",`"subMerchantAccountId`":`"$merchant`",`"subMerchantId`":`"$subMerchantId`",`"subMerchantName`":`"$subMerchantName`",`"amount`":1500.00,`"currency`":`"USD`",`"rail`":`"ACH`",`"status`":`"Declined`",`"declineReason`":`"PerTransactionLimitExceeded`",`"configuredTransactionLimit`":1000.00,`"timeStamp`":`"2026-05-29T12:01:00Z`"}}"
    "MSG-C (AC-3 Wrong reason)"  = "{`"specversion`":`"1.0`",`"type`":`"Payment.Debit.Submitted`",`"source`":`"wellfit-payments-v2-api`",`"id`":`"test-3508-msg-c`",`"time`":`"2026-05-29T12:02:00Z`",`"datacontenttype`":`"application/json`",`"data`":{`"paymentId`":`"$paymentC`",`"subMerchantAccountId`":`"$merchant`",`"amount`":900.00,`"currency`":`"USD`",`"rail`":`"ACH`",`"status`":`"Declined`",`"declineReason`":`"DailyLimitExceeded`",`"configuredDailyLimit`":1000.00,`"dailyCounterValue`":950.00,`"businessDay`":`"2026-05-29`",`"timeStamp`":`"2026-05-29T12:02:00Z`"}}"
    "MSG-D (AC-4 Null limit)"    = "{`"specversion`":`"1.0`",`"type`":`"Payment.Debit.Submitted`",`"source`":`"wellfit-payments-v2-api`",`"id`":`"test-3508-msg-d`",`"time`":`"2026-05-29T12:03:00Z`",`"datacontenttype`":`"application/json`",`"data`":{`"paymentId`":`"$paymentD`",`"subMerchantAccountId`":`"$merchant`",`"amount`":1200.00,`"currency`":`"USD`",`"rail`":`"ACH`",`"status`":`"Declined`",`"declineReason`":`"PerTransactionLimitExceeded`",`"timeStamp`":`"2026-05-29T12:03:00Z`"}}"
    "MSG-E (AC-5 `$0 limit N/A)" = "{`"specversion`":`"1.0`",`"type`":`"Payment.Debit.Submitted`",`"source`":`"wellfit-payments-v2-api`",`"id`":`"test-3508-msg-e`",`"time`":`"2026-05-29T12:04:00Z`",`"datacontenttype`":`"application/json`",`"data`":{`"paymentId`":`"$paymentE`",`"subMerchantAccountId`":`"$merchant`",`"subMerchantId`":`"$subMerchantId`",`"subMerchantName`":`"$subMerchantName`",`"amount`":200.00,`"currency`":`"USD`",`"rail`":`"ACH`",`"status`":`"Declined`",`"declineReason`":`"PerTransactionLimitExceeded`",`"configuredTransactionLimit`":0.00,`"timeStamp`":`"2026-05-29T12:04:00Z`"}}"
}

foreach ($label in $messages.Keys) {
    $resp = Invoke-WebRequest -Uri $url -Method POST `
        -Headers @{ Authorization = $SAS_TOKEN; BrokerProperties = $brokerProps } `
        -ContentType "application/json" -Body $messages[$label] -UseBasicParsing
    Write-Output "$label : HTTP $($resp.StatusCode)"
    Start-Sleep -Milliseconds 300
}
```

Expected: all five return `HTTP 201`.

---

## Step 5 — Verify SB Queue Clean

Wait 30–60 seconds, then check:

```bash
az servicebus topic subscription show \
  --resource-group dev-rg-plat-core-wus3 \
  --namespace-name dev-sbns-payments-westus3 \
  --topic-name payments \
  --name compliance-monitor-api \
  --query "countDetails" -o json
```

Expected: `activeMessageCount: 0` and `deadLetterMessageCount` unchanged from baseline.
If DLQ increased by 5, the `Label` is missing — see Troubleshooting.

---

## Step 6 — Verify in App Insights

Open Application Insights **dev-appi-westus3** (resource group `dev-rg-plat-api-wus3`) → Logs blade.
All queries below filter to the last 15 minutes and your test paymentIds.

> **Substitute your paymentIds.** The queries below use the default IDs from Step 4 (`ee000001-000X`). If you used different GUIDs, replace `ee000001` with your run's prefix in every query.

### AC-1: Approved → No Alert

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee000001-0001"
| where message contains "AlertSent" or message contains "AlertFailed"
| project timestamp, message
```

**Expected:** 0 rows. An Approved event must produce zero alert activity.

---

### AC-2: Declined + PerTransactionLimitExceeded → AlertSent

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AlertSent"
| project timestamp, message,
    Activity = customDimensions["Activity"],
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
```

**Expected:** One row with:
- `message`: `AlertSent: merchant ff000001-..., reason PerTransactionLimitExceeded, amount 1500 exceeds limit 1000`
- `Activity`: `Process Transaction Limit Alert`
- `MerchantId`: `ff000001-0001-0001-0001-000000000001`
- `PaymentId`: `ee000001-0002-0002-0002-000000000002`

> If `AlertFailed` appears instead of `AlertSent`, the email service threw. Most likely cause:
> email template blob missing in DEV storage — see **Email Template Pre-Check** above.

---

### AC-3: DailyLimitExceeded → AlertSkipped (Wrong Reason)

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "NonMatchingRejectionReason"
| project timestamp, message,
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
```

**Expected:** One row: `AlertSkipped: merchant ff000001-..., reason NonMatchingRejectionReason`  
PaymentId: `ee000001-0003-0003-0003-000000000003`

---

### AC-4: Null configuredTransactionLimit → AlertSkipped

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "NoConfiguredLimit"
| project timestamp, message,
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
```

**Expected:** One row: `AlertSkipped: merchant ff000001-..., reason NoConfiguredLimit`  
PaymentId: `ee000001-0004-0004-0004-000000000004`

---

### AC-8: Scoped Logging on All Paths

Confirm `Activity`, `MerchantId`, and `PaymentId` appear in `customDimensions` on every log
entry emitted within `ProcessAsync`. Run this across all five test paymentIds:

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee000001"
| where isnotempty(customDimensions["Activity"])
| project timestamp, message,
    Activity = customDimensions["Activity"],
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
| order by timestamp asc
```

**Expected:** All rows where `Activity` is populated should show `Process Transaction Limit Alert`.

> **Note:** The `PerTransactionLimitExceededProcessor received...` log (Story 1.1 skeleton) had
> `Activity` empty. If Story 1.2 is deployed, that log is gone and all processor-internal logs
> will have the scope. If `Activity` is empty on your results, Story 1.2 is not deployed.

---

### No Unhandled Exceptions

```kusto
exceptions
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where customDimensions contains "ee000001"
| project timestamp, type, outerMessage, customDimensions
```

**Expected:** 0 rows from test paymentIds.

---

### Full Operation Trace (For Any paymentId)

To see the complete processing chain for a single event:

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee000001-0002"   -- substitute any of your test paymentIds
| project timestamp, severityLevel, message, customDimensions
| order by timestamp asc
```

---

## Step 7 — Verify Email Delivery (AC-5, AC-7)

Check the inbox you noted in Step 1 (the `TransactionLimitAlertRecipient` address).

Look for an email triggered by MSG-B:

| Field | Expected |
|---|---|
| Subject | Equals `Risk Trigger Alert – ACH Payment Exceeds Per-Transaction Limit ($1,500.00 > $1,000.00)` — descriptive, with **no** sub-merchant GUID (PAY-3508 #261) |
| To | The `TransactionLimitAlertRecipient` address from Step 1 |
| Body: Merchant Name | `BMR Test Clinic (ff000001-aaaa-aaaa-aaaa-000000000001)` — `Name (Id)` form, from `subMerchantName`/`subMerchantId` on the event (PAY-3508 #257) |
| Body: Sub-Merchant Account ID | `ff000001-0001-0001-0001-000000000001` |
| Body: Attempted amount | `$1,500.00` |
| Body: Configured limit | `$1,000.00` |
| Body: Percentage above limit | `50.0%` (i.e., 50% above) |
| Body: Timestamp | Matches the event timestamp |

The percentage is calculated as `((1500 - 1000) / 1000) × 100 = 50.0%`.

> **Fallback behavior:** if an event arrives without `subMerchantName` (e.g. a pre-#257 publisher), both the
> Merchant Name and Account ID render the account GUID — that's the intended id-fallback, not a failure.

### MSG-E — Zero configured limit → `N/A` percentage (AC-5 edge)

MSG-E injects a `$0.00` configured limit — a real production case (a $0 limit still declines for
`PerTransactionLimitExceeded`). The email is still sent (the limit is not *null*), but "% above" is
mathematically undefined and must render `N/A`, not a misleading `0.0%` (PAY-3508 #257).

| Field | Expected |
|---|---|
| Subject | Equals `Risk Trigger Alert – ACH Payment Exceeds Per-Transaction Limit ($200.00 > $0.00)` |
| Body: Configured limit | `$0.00` |
| Body: Percentage above limit | `N/A` (no trailing `%`) |

> **No email received?** Run:
> ```kusto
> traces
> | where timestamp > ago(15m)
> | where cloud_RoleName == "Wellfit Compliance Monitor"
> | where message contains "AlertFailed"
> ```
> If `AlertFailed` appears, the email service threw — check SendGrid key (`wellfit:sendGrid:accountKey`)
> in DEV app settings. If neither `AlertSent` nor `AlertFailed` appears, Story 1.2 is not deployed.

---

## Full E2E Path (Optional)

The SB injection approach is the primary test method. If you want to validate the end-to-end
flow including the actual payment decline triggering the event:

### Prerequisites for Full E2E

- `WellfitPaymentsV2API.Full` scope granted to `WellfitAutomation` in DEV Identity Server
  (ask Jason — this was flagged as GAP-2 in Story 1.1 E2E report)
- A sub-merchant in DEV with a configured per-transaction ACH limit (see SQL below)
- That sub-merchant's `WellfitTransactionId` known for correlation

### Get Tokens

```bash
IDENTITY_URL="https://dev-platform.wellfit.com/identity"

# Payments V2 token
PV2_TOKEN=$(curl -s -X POST "$IDENTITY_URL/connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=WellfitUnifiedPaymentsAPI" \
  -d "client_secret=Testing123!!W3llf1t1!" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
```

### Submit a Payment Above the Limit

Replace `SUB_MERCHANT_ID` with a merchant that has a per-transaction limit (e.g., $100), and
`TEST_AMOUNT` with a value above that limit (e.g., 150):

```bash
SUB_MERCHANT_ID="<your test sub-merchant ID>"
TEST_AMOUNT="150"
PV2_API="https://dev-platform.wellfit.com/payments-v2"

curl -s -w "\nHTTP %{http_code}" -X POST "$PV2_API/api/v1/payments" \
  -H "Authorization: Bearer $PV2_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: qa-3508-$(date +%s)" \
  -d "{
    \"subMerchantId\": \"$SUB_MERCHANT_ID\",
    \"transactionType\": \"Sale\",
    \"amount\": $TEST_AMOUNT,
    \"currency\": \"USD\",
    \"orderId\": \"QA-PAY3508-$(date +%s)\",
    \"orderIdType\": \"Invoice\",
    \"paymentMethod\": {
      \"type\": \"Ach\",
      \"ach\": {
        \"accountNumber\": \"1234567890\",
        \"routingNumber\": \"011000015\",
        \"accountType\": \"Checking\",
        \"secCode\": \"WEB\",
        \"accountFirstName\": \"QA\",
        \"accountLastName\": \"Tester\",
        \"authorization\": {
          \"authorizationType\": \"ELECTRONIC\",
          \"authorizationDate\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
          \"authorizationReference\": \"QA-PAY3508-AUTH\",
          \"signedAuthorizationOnFile\": true
        }
      }
    }
  }"
```

**Expected response:** HTTP 422 with body indicating per-transaction limit exceeded — the
payment is correctly declined by the enforcement layer.

Then wait 30–60 seconds and run the App Insights AC-2 query above, filtering on the `paymentId`
from the response body. You should see `AlertSent` with the real merchant ID and amounts.

---

## SQL Verification Queries

Connect to the **Platform DB** (`sqldb-plat-dev-001.database.windows.net` / `Platform-dialexa`)
for SubMerchant queries and to the **Payments V2 DB** for enforcement audit queries.

### Find Sub-Merchants with a Per-Transaction Limit Configured (Platform DB)

Useful for full E2E — find a test sub-merchant that will actually trigger a per-transaction limit decline:

```sql
SELECT
    sm.Id            AS SubMerchantId,
    sm.Name          AS SubMerchantName,
    al.PerTransactionLimit,
    al.DailyLimit,
    al.EffectiveDate,
    al.LastModifiedBy,
    al.LastModifiedUtc
FROM Payments.AchLimitConfig al
JOIN SubMerchant.SubMerchants sm ON sm.Id = al.SubMerchantId
WHERE al.PerTransactionLimit BETWEEN 1 AND 500   -- low limits, easy to trigger in test
ORDER BY al.PerTransactionLimit ASC
```

Use any `SubMerchantId` from this result as your test merchant. Submit an ACH payment for
`PerTransactionLimit + 1` to trigger the decline.

### Look Up a Specific Sub-Merchant's Configured Limit

```sql
SELECT
    al.SubMerchantId,
    al.PerTransactionLimit,
    al.DailyLimit,
    al.EffectiveDate
FROM Payments.AchLimitConfig al
WHERE al.SubMerchantId = '<your SubMerchantId>'
```

This is the `configuredTransactionLimit` value you will see in the `Payment.Debit.Submitted`
event payload and in the email body.

### Verify the Enforcement Audit Log Recorded the Decline (Payments V2 DB)

After submitting a payment via the Full E2E path, confirm the enforcement layer recorded the
decline with `decisionReason = 'PerTransactionLimitExceeded'`:

```sql
SELECT TOP 10
    SubMerchantId,
    TransactionId,
    Amount,
    PerTxLimit,
    Decision,
    DecisionReason,
    CreatedUtc
FROM Payments.AchLimitEnforcementAuditLog
WHERE SubMerchantId = '<your SubMerchantId>'
  AND Decision = 'Declined'
  AND DecisionReason = 'PerTransactionLimitExceeded'
ORDER BY CreatedUtc DESC
```

This row confirms the enforcement layer fired and published the event that should trigger the
compliance alert. If the row exists but no `AlertSent` appears in App Insights, the event did
not reach the compliance monitor (check SB subscription and Event Grid routing).

### Check for Recent Per-Transaction Limit Declines in DEV (Useful for Baseline)

```sql
SELECT TOP 20
    SubMerchantId,
    Amount,
    PerTxLimit,
    DecisionReason,
    CreatedUtc
FROM Payments.AchLimitEnforcementAuditLog
WHERE DecisionReason = 'PerTransactionLimitExceeded'
ORDER BY CreatedUtc DESC
```

If you see rows from the past hour, it means real payments are being declined in DEV —
you may already see real `AlertSent` entries in App Insights (not from your test injections).

---

## Tracing the Pipeline in App Insights

App Insights for the compliance monitor: **dev-appi-westus3** (resource group `dev-rg-plat-api-wus3`)  
App Insights AppId: `79a7536e-dce8-4e75-bea9-7d602e8e9851`  
Cloud role name in telemetry: `Wellfit Compliance Monitor`

### Did the processor receive the event?

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message has_any ("AlertSent", "AlertSkipped", "AlertFailed", "PerTransactionLimit")
| project timestamp, severityLevel, message,
    PaymentId = customDimensions["PaymentId"],
    Activity = customDimensions["Activity"]
| order by timestamp desc
| take 50
```

### Did an alert email go out recently?

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AlertSent"
| project timestamp, message,
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
| order by timestamp desc
```

### Did anything fail?

```kusto
exceptions
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| project timestamp, type, outerMessage, innermostMessage,
    PaymentId = customDimensions["PaymentId"],
    MerchantId = customDimensions["MerchantId"]
| order by timestamp desc
```

### Full trace for a specific paymentId

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where customDimensions["PaymentId"] == "<paste paymentId here>"
| project timestamp, severityLevel, message, customDimensions
| order by timestamp asc
```

### Is the service running?

```kusto
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AzureServiceBusConsumer started"
| project timestamp, message
| order by timestamp desc
| take 5
```

Should show a recent startup. If empty, the service is down — check the App Service in portal.

---

## Acceptance Criteria Checklist

| AC | What to Test | Test Method | Pass Condition |
|----|---|---|---|
| AC-1 | Status ≠ Declined → no email | MSG-A (Approved) — App Insights AC-1 query | 0 `AlertSent`/`AlertFailed` rows for paymentA |
| AC-2 | Limit breach → email sent | MSG-B (Declined + PerTxLimit + $1500/$1000) — `AlertSent` in App Insights | `AlertSent` row present with correct amounts |
| AC-3 | Wrong decline reason → skip | MSG-C (Declined + DailyLimitExceeded) — `AlertSkipped` in App Insights | `AlertSkipped: reason NonMatchingRejectionReason` present |
| AC-4 | Null configured limit → skip | MSG-D (Declined + PerTxLimit + no limit value) — `AlertSkipped` in App Insights | `AlertSkipped: reason NoConfiguredLimit` present |
| AC-5 | Email content fields correct | MSG-B + MSG-E — Email inbox check | MSG-B: subject is descriptive with **no** GUID (#261); body shows `Merchant Name: BMR Test Clinic (…)` + `Sub-Merchant Account ID`, `$1,500.00`, `$1,000.00`, `50.0%`. MSG-E: `$0.00` limit → percentage `N/A` (#257) |
| AC-6 | Email failure swallowed | Unit test + E2E DLQ baseline check (Step 3 vs Step 5): `deadLetterMessageCount` must not increase | `AlertFailed` logged; SB DLQ count unchanged from baseline; unit test: `ProcessAsync_WhenEmailServiceThrows_DoesNotPropagate` |
| AC-7 | Recipient from app settings | MSG-B — Email received at `TransactionLimitAlertRecipient` address | Email arrives at address confirmed in Step 1 |
| AC-8 | Scoped logging keys | Any test message — AC-8 App Insights query | `Activity`, `MerchantId`, `PaymentId` present in `customDimensions` on all log entries |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| SB injection returns 401 | SAS token expired or wrong resource URI | Regenerate token (Step 2); verify URI is `...servicebus.windows.net/payments` (without `/messages`) |
| All 5 messages DLQ'd (counts go up by 5) | `Label` missing from `BrokerProperties` | Confirm the `BrokerProperties` header is exactly `{"Label":"Payment.Debit.Submitted","ContentType":"application/cloudevents+json"}` |
| App Insights shows "received" log, no AlertSent/AlertSkipped | Story 1.1 skeleton is running | Story 1.2 not deployed — check with dev team; run Deployment Pre-Check |
| `AlertFailed` appears instead of `AlertSent` | Email template blob missing | Run Email Template Pre-Check; upload blob from feature branch |
| `AlertFailed` with `SendGridException` (403) | `from` address not verified with SendGrid | `wellfit:sendGrid:from` must be `no-reply@wellfit-qa.com` — the only verified sender on the DEV key. `no-reply@wellfit-dev.com` and `no-reply@wellfit-stage.com` return 403. Fixed in env-app-settings PR #245; if testing before merge, update `wellfit:sendGrid:from` in DEV app settings manually. |
| `AlertFailed` with `SendGridException` (key error) | SendGrid API key inactive | Check `wellfit:sendGrid:accountKey` in DEV app settings; verify key starts with `SG.` and is active in SendGrid portal |
| No traces at all for your paymentIds | Compliance monitor is down | Check App Service health: `curl -s https://dev-app-compliancemonitor.azurewebsites.net/health` — expect `Ok`; restart if needed |
| AC-8 query shows empty `Activity` field | Story 1.1 skeleton still running | `BeginScope` was added in Story 1.2; empty `Activity` = old code deployed |
| `compliance:transactionLimitAlertRecipient` setting reverts to empty after redeploy | Setting was applied via CLI, not in `wellfit-environment-app-settings` | Add key to the `wellfit-environment-app-settings` repo for the DEV environment (Story 1.2 Completion Notes item) |
| Full E2E returns 401 from Payments V2 | `WellfitAutomation` doesn't have `WellfitPaymentsV2API.Full` scope | Ask Jason to grant scope in DEV Identity Server; use SB injection as workaround |
| Full E2E returns 422 `per-transaction-limit` | Per-transaction limit lower than test amount | Use SQL query to find configured limit, then set amount = limit + 1; or use SB injection with explicit amounts instead |
