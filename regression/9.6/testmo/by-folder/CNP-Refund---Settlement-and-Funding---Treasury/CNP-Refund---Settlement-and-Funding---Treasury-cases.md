# CNP Refund - Settlement and Funding - Treasury

Cases: **9**

## 1. Validate that POST  CNP /payments API is 200 OK

- **Case ID:** 304015
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get BearerToken key

### Steps

Execute 
POST https://stage-platform.wellfit.com/payments/authenticate

{
   "username": "WellfitUnifiedPaymentsAPI",
   "password": "Testing123!!W3llf1t1!"
}

---

## 2. Validate that CNP partial refund  can be successfully sent to the system

- **Case ID:** 304016
- **Priority:** Normal
- **Status (at export):** Untested

### Steps

Execute  with any amount and submerchant
https://stage-platform.wellfit.com/payments/refund-transaction
{
  "amount": "{{less than total transactionAmount}}"}}
  "orderId": "Postman-Refund{{random-order-id}}",
  "originalTransactionId": "{{originalCNPTransactionId}}"
}

---

## 3. Validate that CNP partial refund is successfully stored as 'Approved' in Payments  DB

- **Case ID:** 304017
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Platform DB

SettlementDate = NULL
FundingInstructions = NULL
Status = Approved

### Steps

Execute the following query in Plafrorm DB, changing the transactionId properly

 
SELECT * From payments.payments where transactionId = '83999403816107069'

---

## 4. Validate that  CNP partial refund gets "SettlementDate"value filled via query through Payments  DB Table

- **Case ID:** 304020
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Platform DB

SettlementDate = ExpectedDate

### Steps

Execute the following query in Plafrorm DB, changing the transactionId properly
 
 
UPDATE Payments.Payments SET SettlementDate = '2026-05-21' where transactionId = '83999403816107069'
Execute to see change reflected

SELECT * From payments.payments where transactionId = '83999403816107069'

---

## 5. Validate that POST treasury/create-funding-batch API can be successfully executed 202 OK

- **Case ID:** 304018
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Preconditions:
ACH Transaction already has a "SettlementDate" manually updated via query

### Expected

202 Accepted Status

{
    "correlationId": "{{correlationId}}",
    "stage": "Create"
}

### Steps

Execute 
POST https://stage-platform.wellfit.com/treasury/create-funding-batch
{}

---

## 6. Validate that  "FundingInstructions" and "SettlementDate" are not NULL for CNP partial refund in Payments  DB Table after creating FundingBatch via API

- **Case ID:** 304019
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Platform DB

SettlementDate = ExpectedDate 
FundingInstructions = Contains FundingID
Status = Approved

### Steps

Execute the following query in Plafrorm DB, changing the transactionId properly
 
SELECT * From payments.payments where transactionId = '83999403816107069'

---

## 7. Validate that Payments.FundingInstructions Table contains proper co-relation of  "FIPC-PayFac", "FISC-NetSettlement" and "Id" against  "fundingInstructionId". "PayFacFee" and "Amount" values from  Platform Payments.Payments DB

- **Case ID:** 304021
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Values match ACH transaction an funding instructions batch
 
We should see FISD for refund in [Payments].[FundingInstructions] table when run treasury (FISD - Funding Instruction Submerchant Debit)

### Steps

Execute the following queryes updating transactionId value properly
 
SELECT [id], [fundingInstructionId], [payFacFee], [amount] From payments.payments where transactionId = '83999403816107069'

 
SELECT TOP 3 * from payments.fundingInstructions order by timestamp desc
Observe values matching

---

## 8. Validate that POST treasury/send-funding-batch API can be successfully executed 202 OK

- **Case ID:** 304022
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Preconditions:
ACH transaction already status 5 Funded, with SettlementDate and FundingInstructionsId

### Expected

202 Accepted Status

{
    "correlationId": "{{correlationId}}",
    "stage": "Create"
}

### Steps

Execute 
POST https://stage-platform.wellfit.com/treasury/send-funding-batch
{}

---

## 9. Validate that Payments.FundingBatches Table contains proper "BatchFileName" value after sending funding batch via API

- **Case ID:** 304023
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get Batch File Name

### Steps

Execute the following query
 
SELECT * FROM Payments.FundingBatches order by requestSentTimestamp desc 
Observe most recent value according to date when you send funding batch

---
