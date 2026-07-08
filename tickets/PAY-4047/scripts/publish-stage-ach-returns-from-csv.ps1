<#
.DEPRECATED
  Superseded 2026-07-08 by Jason Stage runbook: inject-ach-return.sql +
  stage-wf-payments-func FileProcessedEvent. This script targeted wellfit-datafactory /
  ReturnNotificationReceivedEvent (subscription delivery was blocked). See PAY-4047-QA-Context.md.

.SYNOPSIS
  Publish ACH return records to STAGE Event Grid (PAY-4047 / ach-returns QA).

.EXAMPLE
  $env:EVENTGRID_KEY = '<paste Stage key here>'
  ./publish-stage-ach-returns-from-csv.ps1 -WhatIf
  ./publish-stage-ach-returns-from-csv.ps1

.EXAMPLE
  ./publish-stage-ach-returns-from-csv.ps1 -Key '<Stage key>' -WhatIf
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "./pay-4047-stage.csv",

    [Parameter(Mandatory = $false)]
    [string]$Topic = "wellfit-datafactory",

    [Parameter(Mandatory = $false)]
    [string]$Key = $env:EVENTGRID_KEY,

    [Parameter(Mandatory = $false)]
    [int]$DelayMs = 0,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest

if (-not (Test-Path -Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 2
}

if ([string]::IsNullOrWhiteSpace($Key)) {
    Write-Error "Event Grid key not provided. Pass -Key or set environment variable EVENTGRID_KEY."
    exit 3
}

$publish_operation_uri = "https://stage-wf-eventgrid.westus-1.eventgrid.azure.net/topics/$($Topic):publish?api-version=2023-06-01-preview"

function Build-ColumnLookup($row) {
    $lookup = @{}
    foreach ($p in $row.PSObject.Properties) {
        $lookup[$p.Name.ToLower()] = $p.Value
    }
    return $lookup
}

function Get-ValueFromRow($lookup, [string[]]$candidates, $default = $null) {
    foreach ($c in $candidates) {
        $key = $c.ToLower()
        if ($lookup.ContainsKey($key) -and $null -ne $lookup[$key] -and ($lookup[$key].ToString().Trim() -ne '')) {
            return $lookup[$key]
        }
    }
    return $default
}

$headers = @{
    "Content-Type"  = "application/cloudevents+json"
    "Authorization" = "SharedAccessKey $Key"
}

$rows = Import-Csv -Path $CsvPath
if (@($rows).Count -eq 0) {
    Write-Warning "CSV contained no rows: $CsvPath"
    exit 0
}

$sent = 0
$failed = 0

foreach ($r in $rows) {
    $lookup = Build-ColumnLookup $r

    $message = [ordered]@{
        CaseId                        = Get-ValueFromRow $lookup @('CaseId', 'caseid', 'case_id', 'case', 'Case ID') ''
        WorldpayPaymentId             = Get-ValueFromRow $lookup @('WorldpayPaymentId', 'worldpaypaymentid', 'worldpay_payment_id', 'PaymentId', 'paymentid', 'Worldpay Payment ID') ''
        MerchantOrderNumber           = Get-ValueFromRow $lookup @('MerchantOrderNumber', 'merchantordernumber', 'merchant_order_number', 'order_number', 'Merchant Order Number') ''
        AccountSuffix                 = Get-ValueFromRow $lookup @('AccountSuffix', 'accountsuffix', 'account_suffix', 'Account Suffix') ''
        ReasonCode                    = Get-ValueFromRow $lookup @('ReasonCode', 'reasoncode', 'reason_code', 'Reason Code') ''
        ReasonDescription             = Get-ValueFromRow $lookup @('ReasonDescription', 'reasondescription', 'reason_description', 'reason', 'Reason Description') ''
        DateIssued                    = Get-ValueFromRow $lookup @('DateIssued', 'dateissued', 'date_issued', 'Date Issued') ''
        DateReceived                  = Get-ValueFromRow $lookup @('DateReceived', 'datereceived', 'date_received', 'Date Received') ''
        ChargebackCurrency            = Get-ValueFromRow $lookup @('ChargebackCurrency', 'chargebackcurrency', 'chargeback_currency', 'currency', 'Chargeback Currency') ''
        ChargebackAmt                 = Get-ValueFromRow $lookup @('ChargebackAmt', 'chargebackamt', 'chargeback_amount', 'amount', 'Chargeback Amt') ''
        TransactionDate               = Get-ValueFromRow $lookup @('TransactionDate', 'transactiondate', 'transaction_date', 'Transaction date') ''
        TransactionPurchaseCurrency   = Get-ValueFromRow $lookup @('TransactionPurchaseCurrency', 'transactionpurchasecurrency', 'transaction_purchase_currency', 'Transaction Purchase Currency') ''
        TransactionPurchaseAmount     = Get-ValueFromRow $lookup @('TransactionPurchaseAmount', 'transactionpurchaseamount', 'transaction_purchase_amount', 'Transaction Purchase Amount') ''
        TransactionSettlementCurrency = Get-ValueFromRow $lookup @('TransactionSettlementCurrency', 'transactionsettlementcurrency', 'transaction_settlement_currency', 'Transaction Settlement Currency') ''
        TransactionSettlementAmount   = Get-ValueFromRow $lookup @('TransactionSettlementAmount', 'transactionsettlementamount', 'transaction_settlement_amount', 'Transaction Settlement Amount') ''
        ActivityDate                  = Get-ValueFromRow $lookup @('ActivityDate', 'activitydate', 'activity_date', 'Activity Date') ''
        MerchantName                  = Get-ValueFromRow $lookup @('MerchantName', 'merchantname', 'merchant_name', 'Merchant Name') ''
        ReportGroup                   = Get-ValueFromRow $lookup @('ReportGroup', 'reportgroup', 'report_group', 'Report Group') ''
        ReportingGroup                = Get-ValueFromRow $lookup @('ReportingGroup', 'reportinggroup', 'reporting_group', 'Reporting Group') ''
        TxnType                       = Get-ValueFromRow $lookup @('TxnType', 'txntype', 'txn_type', 'type', 'Transaction Type') ''
        BatchId                       = Get-ValueFromRow $lookup @('BatchId', 'batchid', 'batch_id', 'Batch Id') ''
        SessionId                     = Get-ValueFromRow $lookup @('SessionId', 'sessionid', 'session_id', 'Session Id') ''
        MerchantTransactionId         = Get-ValueFromRow $lookup @('MerchantTransactionId', 'merchanttransactionid', 'merchant_transaction_id', 'Merchant Transaction Id') ''
        BillingDescriptor             = Get-ValueFromRow $lookup @('BillingDescriptor', 'billingdescriptor', 'billing_descriptor', 'Billing Descriptor') ''
        MerchantId                    = Get-ValueFromRow $lookup @('MerchantId', 'merchantid', 'merchant_id', 'Merchant Id') ([guid]::NewGuid().ToString())
        Presenter                     = Get-ValueFromRow $lookup @('Presenter', 'presenter') 'Wellfit'
        OriginalTraceNumber           = Get-ValueFromRow $lookup @('OriginalTraceNumber', 'originaltracenumber', 'Original Trace Number') ''
        ReturnTraceNumber             = Get-ValueFromRow $lookup @('ReturnTraceNumber', 'returntracenumber', 'Return Trace Number') ''
    }

    # Stage subscription filter: data.eventName String in ReturnNotificationReceivedEvent
    $eventDataJson = ($message | ConvertTo-Json -Depth 10 -Compress)
    $dataJson = '{"eventName":"ReturnNotificationReceivedEvent","EventName":"ReturnNotificationReceivedEvent","eventData":' + $eventDataJson + '}'

    $eventId = [guid]::NewGuid().ToString()
    $timeStr = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $payments_event = @"
{
  "specversion": "1.0",
  "id": "$eventId",
  "type": "ach-return-record-received",
  "source": "wellfit.datafactory",
  "subject": "ach-return-record-received",
  "time": "$timeStr",
  "data": $dataJson
}
"@.Trim()

    Write-Host "--- Publish URI ---"
    Write-Host $publish_operation_uri
    Write-Host "--- JSON CaseId=$($message.CaseId) WorldpayPaymentId=$($message.WorldpayPaymentId) ---"
    Write-Host $payments_event

    if ($WhatIf) {
        Write-Host "--- WHATIF: would send event for CaseId=$($message.CaseId) ---"
        continue
    }

    $maxRetries = 3
    $attempt = 0
    $sentThis = $false
    while (-not $sentThis -and $attempt -lt $maxRetries) {
        $attempt++
        try {
            [void](Invoke-RestMethod -Method Post -Uri $publish_operation_uri -Headers $headers -Body $payments_event -ContentType 'application/cloudevents+json')
            Write-Host "Sent event CaseId=$($message.CaseId) (attempt $attempt)"
            $sent++
            $sentThis = $true
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"
            if ($attempt -lt $maxRetries) { Start-Sleep -Milliseconds (500 * $attempt) }
            else { $failed++; Write-Error "Failed after $attempt attempts." }
        }
    }

    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

Write-Host "Done. Sent: $sent, Failed: $failed"
