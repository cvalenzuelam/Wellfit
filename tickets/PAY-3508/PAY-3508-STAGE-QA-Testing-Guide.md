# PAY-3508 — ACH Per-Transaction Limit Compliance Alert: QA Testing Guide (STAGE)

**Feature:** transaction-limit-compliance-alerts — Story 1.2  
**Jira:** [PAY-3508](https://wellfit.atlassian.net/browse/PAY-3508)  
**Adapted from:** `PAY-3508-Transaction-Limit-Alert-QA-Testing-Guide.md` (Brett — DEV)  
**Scope:** compliance-monitor-ms, Service Bus (`payments` topic / `compliance-monitor-api` subscription), SendGrid email  
**Primary test method:** Service Bus injection (5 messages) — same as DEV guide

---

## DEV → STAGE resource map

| DEV (Brett guide) | STAGE (this guide) |
|-------------------|---------------------|
| `dev-app-compliancemonitor` | `stage-wf-compliancemonitor-api` |
| RG `dev-rg-plat-api-wus3` | RG **`stage-platform-api`** |
| `dev-appi-westus3` | **`stage-insights`** |
| `dev-sbns-payments-westus3` | **`stage-payments-bus`** |
| SB RG `dev-rg-plat-core-wus3` | **`stage-platform-core`** |
| Health `dev-app-compliancemonitor...` | `https://stage-wf-compliancemonitor-api.azurewebsites.net/health` |
| Log prefix `ee000001` | Log prefix **`ee350808`** |
| Subscription DEV | Subscription **Staging** |

---

## What This Feature Does

When a Payments V2 ACH transaction is declined because it exceeds the sub-merchant's configured
per-transaction limit, the Compliance Monitor sends an email alert to the compliance team.

SB injection simulates `Payment.Debit.Submitted` CloudEvents **without** a real ACH payment.

---

## Deployment Pre-Check

Verify Story 1.2 is deployed to **STAGE**. If the old Story 1.1 skeleton is running, you will not
see `AlertSent` / `AlertSkipped` / `AlertFailed`.

Open **stage-insights** → Logs:

```kusto
traces
| where timestamp > ago(30m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "PerTransactionLimit"
| project timestamp, message
| order by timestamp desc
| take 10
```

- `PerTransactionLimitExceededProcessor received...` → ❌ Story 1.1 skeleton — stop, wait for deployment
- `AlertSent` / `AlertSkipped` / `AlertFailed` → ✅ Story 1.2 deployed — continue

---

## Email Template Pre-Check (STAGE)

If the email template blob is missing in STAGE storage, logs show `AlertFailed` instead of `AlertSent`.

Confirm with your team which STAGE storage account hosts compliance-monitor templates (DEV used
`stwfdev1`). If `AlertFailed` + `StorageException` appears after MSG-B, ask Brett for the STAGE
blob path or upload the template from **wellfit-resources**:

`templates/email-compliance-ach-per-transaction-limit-exceeded.html`

---

## Prerequisites

### Access

- [ ] `az login` → Azure subscription **Staging**
- [ ] Access to compliance alert inbox (`compliance:transactionLimitAlertRecipient` — Step 1)
- [ ] App Insights: **stage-insights**
- [ ] Azure Cloud Shell (**PowerShell**) or local PowerShell with `az` CLI
- [ ] Permission to list keys on `stage-payments-bus` (or ask Brett to run injection)

### Tools

- Azure CLI (`az`)
- PowerShell — injection script: `PAY-3508-Stage-SB-Injection.ps1`

---

## Step 1 — Confirm STAGE App Settings

Verify `TransactionLimitAlertRecipient` and note which inbox(es) to check:

```powershell
az account set --subscription "Staging"

az webapp config appsettings list `
  --name stage-wf-compliancemonitor-api `
  --resource-group stage-platform-api `
  --query "[?name=='compliance:transactionLimitAlertRecipient']" `
  -o table
```

Multiple addresses use **`;`** as separator. Add your QA email if needed, then **restart**:

```powershell
az webapp config appsettings set `
  --name stage-wf-compliancemonitor-api `
  --resource-group stage-platform-api `
  --settings "compliance:transactionLimitAlertRecipient=<existing list>;your.email@company.com"

az webapp restart `
  --name stage-wf-compliancemonitor-api `
  --resource-group stage-platform-api
```

Wait ~30 seconds. Health check:

```powershell
Invoke-WebRequest -Uri "https://stage-wf-compliancemonitor-api.azurewebsites.net/health" -UseBasicParsing
```

Expected: HTTP 200, body `Ok`.

Record the recipient address(es) — you will check this inbox in Step 7.

---

## Step 2 — Get SAS Token (PowerShell)

Azure CLI cannot POST to Service Bus directly. Generate an HMAC-SHA256 SAS token for topic `payments`.

**Recommended:** skip manual token build and run **`PAY-3508-Stage-SB-Injection.ps1`** (Step 4) — it
generates the token automatically.

**Manual (same session as Step 4):**

```powershell
$keyName = az servicebus namespace authorization-rule keys list `
  --resource-group stage-platform-core `
  --namespace-name stage-payments-bus `
  --name RootManageSharedAccessKey `
  --query "name" -o tsv

$keyValue = az servicebus namespace authorization-rule keys list `
  --resource-group stage-platform-core `
  --namespace-name stage-payments-bus `
  --name RootManageSharedAccessKey `
  --query "primaryKey" -o tsv

$uri = [System.Uri]::EscapeDataString("https://stage-payments-bus.servicebus.windows.net/payments")
$expiry = [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeSeconds()
$stringToSign = "$uri`n$expiry"

$hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($keyValue.Trim()))
$sig = [System.Convert]::ToBase64String($hmac.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign)))
$sigEnc = [System.Uri]::EscapeDataString($sig)

$global:SAS_TOKEN = "SharedAccessSignature sr=$uri&sig=$sigEnc&se=$expiry&skn=$keyName"
Write-Output "Token ready (expires in 2 hours)"
```

If `primaryKey` is empty → no RBAC on Service Bus; use Bearer fallback (see Troubleshooting) or ask Brett.

---

## Step 3 — Note Baseline SB Queue State

```powershell
az servicebus topic subscription show `
  --resource-group stage-platform-core `
  --namespace-name stage-payments-bus `
  --topic-name payments `
  --name compliance-monitor-api `
  --query "countDetails" -o json
```

Record `deadLetterMessageCount` — baseline for Step 5. Your five test messages should **not** increase DLQ by 5.

---

## Step 4 — Inject Test Messages

> **Critical:** `BrokerProperties` must include `Label: Payment.Debit.Submitted`. Without it, messages
> dead-letter (Story 1.1 root cause).

### Option A — Run repo script (recommended)

1. Azure Portal → Cloud Shell → PowerShell
2. Upload `PAY-3508-Stage-SB-Injection.ps1`
3. Execute:

```powershell
./PAY-3508-Stage-SB-Injection.ps1
```

Expected: **5 × HTTP 201**, prefix `ee350808`.

### Option B — Manual injection (same bodies as Brett DEV guide)

Continue in the **same PowerShell session** as Step 2 (`$SAS_TOKEN` must exist):

```powershell
$url = "https://stage-payments-bus.servicebus.windows.net/payments/messages"
$brokerProps = '{"Label":"Payment.Debit.Submitted","ContentType":"application/cloudevents+json"}'

$paymentA = "ee350808-0001-0001-0001-000000000001"  # Approved — AC-1 skip
$paymentB = "ee350808-0002-0002-0002-000000000002"  # Declined + PerTxLimit — email (AC-2)
$paymentC = "ee350808-0003-0003-0003-000000000003"  # DailyLimit — wrong reason (AC-3)
$paymentD = "ee350808-0004-0004-0004-000000000004"  # PerTxLimit + null limit (AC-4)
$paymentE = "ee350808-0005-0005-0005-000000000005"  # PerTxLimit + $0 limit (AC-5 edge)
$merchant = "ff000001-0001-0001-0001-000000000001"
$subMerchantId = "ff000001-aaaa-aaaa-aaaa-000000000001"
$subMerchantName = "BMR Test Clinic"

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

Expected: all five return **HTTP 201**.

---

## Step 5 — Verify SB Queue Clean

Wait 30–60 seconds, then check:

```powershell
az servicebus topic subscription show `
  --resource-group stage-platform-core `
  --namespace-name stage-payments-bus `
  --topic-name payments `
  --name compliance-monitor-api `
  --query "countDetails" -o json
```

Expected: `activeMessageCount: 0` and `deadLetterMessageCount` unchanged from Step 3 baseline.
If DLQ increased by 5, the `Label` is missing — see Troubleshooting.

---

## Step 6 — Verify in App Insights

Open **stage-insights** → Logs. Use prefix **`ee350808`** (not `ee000001` from DEV guide).

### AC-1: Approved → No Alert

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee350808-0001"
| where message contains "AlertSent" or message contains "AlertFailed"
| project timestamp, message
```

Expected: **0 rows**.

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

Expected:
- `message`: `AlertSent: merchant ff000001-..., reason PerTransactionLimitExceeded, amount 1500 exceeds limit 1000`
- `Activity`: `Process Transaction Limit Alert`
- `PaymentId`: `ee350808-0002-0002-0002-000000000002`

### AC-3: DailyLimitExceeded → AlertSkipped

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "NonMatchingRejectionReason"
| project timestamp, message,
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
```

Expected: `AlertSkipped` … PaymentId `ee350808-0003-0003-0003-000000000003`

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

Expected: PaymentId `ee350808-0004-0004-0004-000000000004`

### AC-8: Scoped Logging

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee350808"
| where isnotempty(customDimensions["Activity"])
| project timestamp, message,
    Activity = customDimensions["Activity"],
    MerchantId = customDimensions["MerchantId"],
    PaymentId = customDimensions["PaymentId"]
| order by timestamp asc
```

Expected: `Activity` = `Process Transaction Limit Alert` on processor logs.

### No Unhandled Exceptions

```kusto
exceptions
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where customDimensions contains "ee350808"
| project timestamp, type, outerMessage, customDimensions
```

Expected: 0 rows.

### Full trace (any paymentId)

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "ee350808-0002"
| project timestamp, severityLevel, message, customDimensions
| order by timestamp asc
```

---

## Step 7 — Verify Email Delivery (AC-5, AC-7)

Check inbox(es) from Step 1.

### MSG-B

| Field | Expected |
|-------|----------|
| Subject | `Risk Trigger Alert – ACH Payment Exceeds Per-Transaction Limit ($1,500.00 > $1,000.00)` — no GUID in subject |
| Body: Merchant Name | `BMR Test Clinic (ff000001-aaaa-aaaa-aaaa-000000000001)` |
| Body: Sub-Merchant Account ID | `ff000001-0001-0001-0001-000000000001` |
| Body: Attempted amount | `$1,500.00` |
| Body: Configured limit | `$1,000.00` |
| Body: Percentage above limit | `50.0%` |

### MSG-E

| Field | Expected |
|-------|----------|
| Subject | `Risk Trigger Alert – ACH Payment Exceeds Per-Transaction Limit ($200.00 > $0.00)` |
| Body: Percentage above limit | `N/A` (not `0.0%`) |

If no email:

```kusto
traces
| where timestamp > ago(15m)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AlertFailed"
```

---

## Acceptance Criteria Checklist (STAGE)

| AC | Test | Pass condition |
|----|------|----------------|
| AC-1 | MSG-A | 0 `AlertSent`/`AlertFailed` for `ee350808-0001` |
| AC-2 | MSG-B | `AlertSent` with 1500 / 1000 |
| AC-3 | MSG-C | `AlertSkipped` NonMatchingRejectionReason |
| AC-4 | MSG-D | `AlertSkipped` NoConfiguredLimit |
| AC-5 | MSG-B + MSG-E email | Fields above; MSG-E → `N/A` |
| AC-6 | DLQ baseline | No +5 dead letters |
| AC-7 | MSG-B email | Arrives at Step 1 recipient |
| AC-8 | customDimensions | Activity, MerchantId, PaymentId populated |

---

## Troubleshooting (STAGE)

| Symptom | Fix |
|---------|-----|
| SB injection 401 | Regenerate SAS (Step 2); or Bearer token: `az account get-access-token --resource https://servicebus.azure.net`; or ask Brett |
| All 5 messages DLQ | Fix `BrokerProperties` Label |
| No AlertSent/AlertSkipped | Story 1.2 not deployed — Pre-Check |
| `AlertFailed` | Missing email template blob or SendGrid `from` not verified in STAGE |
| `az webapp` empty | Wrong RG — use **`stage-platform-api`** |
| Cloud Shell `\` line break | Use one-line commands or backtick `` ` `` (PowerShell) |

---

## Optional — Full E2E (not required for PAY-3508)

Real ACH via Postman is **optional** in Brett's guide. SB injection is the primary QA path.
See `PAY-3508-Transaction-Limit-Alert-QA-Testing-Guide.md` Full E2E section — replace DEV URLs
with `stage-wf-payments-v2-api.azurewebsites.net` if needed.
