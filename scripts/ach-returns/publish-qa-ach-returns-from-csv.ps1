<#
.SYNOPSIS
  Publish ACH eCheck return records from a CSV to Event Grid as CloudEvents.

.DESCRIPTION
  This script loops through rows in a CSV file and for each row constructs a
  message body matching the structure used by the existing
  `publish-ach-return-record-received.ps1` script and publishes it to Event Grid.

.PARAMETER CsvPath
  Path to the CSV file containing echeck return records. The CSV may contain
  headers that map to the message fields (case-insensitive). Unknown fields
  are ignored.

.PARAMETER Topic
  Event Grid topic name (defaults to "wellfit-payments").

.PARAMETER Key
  Event Grid shared access key. If not provided, the script will look for the
  environment variable `EVENTGRID_KEY`.

.PARAMETER DelayMs
  Optional delay in milliseconds between sends (default 0).

.PARAMETER WhatIf
  If provided, the script will print the events it would send without sending.

.EXAMPLE
  $env:EVENTGRID_KEY = '<paste QA key here>'
  ./publish-qa-ach-returns-from-csv.ps1 -WhatIf
  ./publish-qa-ach-returns-from-csv.ps1

.EXAMPLE
  ./publish-qa-ach-returns-from-csv.ps1 -Key '<QA key>' -CsvPath ./test_returns_2025-09-18.csv
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "./test_returns_2025-09-18.csv",

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

$publish_operation_uri = "https://qa-wf-eventgrid.westus-1.eventgrid.azure.net/topics/$($Topic):publish?api-version=2023-06-01-preview"

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
    "Content-Type" = "application/cloudevents+json"
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

    # Construct message mapping common header names (case-insensitive). Add more candidates as needed.
    $message = [ordered]@{
        CaseId = Get-ValueFromRow $lookup @('CaseId','caseid','case_id','case','Case ID') ''
        WorldpayPaymentId = Get-ValueFromRow $lookup @('WorldpayPaymentId','worldpaypaymentid','worldpay_payment_id','PaymentId','paymentid','Worldpay Payment ID') ''
        MerchantOrderNumber = Get-ValueFromRow $lookup @('MerchantOrderNumber','merchantordernumber','merchant_order_number','order_number','Merchant Order Number') ''
        AccountSuffix = Get-ValueFromRow $lookup @('AccountSuffix','accountsuffix','account_suffix','Account Suffix') ''
        ReasonCode = Get-ValueFromRow $lookup @('ReasonCode','reasoncode','reason_code','Reason Code') ''
        ReasonDescription = Get-ValueFromRow $lookup @('ReasonDescription','reasondescription','reason_description','reason','Reason Description') ''
        DateIssued = Get-ValueFromRow $lookup @('DateIssued','dateissued','date_issued','dateissued','Date Issued') ''
        DateReceived = Get-ValueFromRow $lookup @('DateReceived','datereceived','date_received','Date Received') ''
        ChargebackCurrency = Get-ValueFromRow $lookup @('ChargebackCurrency','chargebackcurrency','chargeback_currency','currency','Chargeback Currency') ''
        ChargebackAmt = Get-ValueFromRow $lookup @('ChargebackAmt','chargebackamt','chargeback_amount','amount','Chargeback Amt') ''
        TransactionDate = Get-ValueFromRow $lookup @('TransactionDate','transactiondate','transaction_date','Transaction date') ''
        TransactionPurchaseCurrency = Get-ValueFromRow $lookup @('TransactionPurchaseCurrency','transactionpurchasecurrency','transaction_purchase_currency','Transaction Purchase Currency') ''
        TransactionPurchaseAmount = Get-ValueFromRow $lookup @('TransactionPurchaseAmount','transactionpurchaseamount','transaction_purchase_amount','Transaction Purchase Amount') ''
        TransactionSettlementCurrency = Get-ValueFromRow $lookup @('TransactionSettlementCurrency','transactionsettlementcurrency','transaction_settlement_currency','Transaction Settlement Currency') ''
        TransactionSettlementAmount = Get-ValueFromRow $lookup @('TransactionSettlementAmount','transactionsettlementamount','transaction_settlement_amount','Transaction Settlement Amount') ''
        ActivityDate = Get-ValueFromRow $lookup @('ActivityDate','activitydate','activity_date','Activity Date') ''
        MerchantName = Get-ValueFromRow $lookup @('MerchantName','merchantname','merchant_name','Merchant Name') ''
        ReportGroup = Get-ValueFromRow $lookup @('ReportGroup','reportgroup','report_group','Report Group') ''
        ReportingGroup = Get-ValueFromRow $lookup @('ReportingGroup','reportinggroup','reporting_group','Reporting Group') ''
        TxnType = Get-ValueFromRow $lookup @('TxnType','txntype','txn_type','type','Transaction Type') ''
        BatchId = Get-ValueFromRow $lookup @('BatchId','batchid','batch_id','Batch Id') ''
        SessionId = Get-ValueFromRow $lookup @('SessionId','sessionid','session_id','Session Id') ''
        MerchantTransactionId = Get-ValueFromRow $lookup @('MerchantTransactionId','merchanttransactionid','merchant_transaction_id','Merchant Transaction Id') ''
        BillingDescriptor = Get-ValueFromRow $lookup @('BillingDescriptor','billingdescriptor','billing_descriptor','Billing Descriptor') ''
        MerchantId = Get-ValueFromRow $lookup @('MerchantId','merchantid','merchant_id','Merchant Id') ([guid]::NewGuid().ToString())
        Presenter = Get-ValueFromRow $lookup @('Presenter','presenter') 'Wellfit'
        OriginalTraceNumber = Get-ValueFromRow $lookup @('OriginalTraceNumber','originaltracenumber','Original Trace Number') ''
        ReturnTraceNumber = Get-ValueFromRow $lookup @('ReturnTraceNumber','returntracenumber','Return Trace Number') ''
    }

    $dataObject = [PSCustomObject]@{
        EventName = 'ReturnNotificationReceivedEvent' # 'ach-return-record-received'
        EventData = $message
    }

    $cloudEvent = [PSCustomObject]@{
        specversion = '1.0'
        id = [guid]::NewGuid().ToString()
        type = 'ach-return-record-received'
        source = 'wellfit.datafactory'
        subject = 'ach-return-record-received'
        time = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
        data = $dataObject
    }

    $payments_event = $cloudEvent | ConvertTo-Json -Depth 10


    Write-Host "--- Publish URI for event id=$($cloudEvent.id) CaseId=$($message.CaseId) ---"
    Write-Host $publish_operation_uri
    Write-Host "--- JSON for event id=$($cloudEvent.id) CaseId=$($message.CaseId) ---"
    Write-Host $payments_event

    if ($WhatIf) {
        Write-Host "--- WHATIF: would send event id=$($cloudEvent.id) for CaseId=$($message.CaseId) ---"
        continue
    }

    # send with retry
    $maxRetries = 3
    $attempt = 0
    $sentThis = $false
    while (-not $sentThis -and $attempt -lt $maxRetries) {
        $attempt++
        try {
            [void](Invoke-RestMethod -Method Post -Uri $publish_operation_uri -Headers $headers -Body $payments_event -ContentType 'application/cloudevents+json')
            Write-Host "Sent event id=$($cloudEvent.id) CaseId=$($message.CaseId) (attempt $attempt)"
            $sent++
            $sentThis = $true
        }
        catch {
            Write-Warning "Attempt $attempt failed for event id=$($cloudEvent.id): $($_.Exception.Message)"
            if ($attempt -lt $maxRetries) { Start-Sleep -Milliseconds (500 * $attempt) }
            else { $failed++; Write-Error "Failed to send event id=$($cloudEvent.id) after $attempt attempts." }
        }
    }

    if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
}

Write-Host "Done. Sent: $sent, Failed: $failed"
