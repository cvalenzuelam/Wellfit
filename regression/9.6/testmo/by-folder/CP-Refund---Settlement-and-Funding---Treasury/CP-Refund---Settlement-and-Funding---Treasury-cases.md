# CP Refund  - Settlement and Funding - Treasury

Cases: **9**

## 1. Validate that POST  CP /payments API is 200 OK

- **Case ID:** 304065
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

## 2. Validate that CP partial refund  can be successfully sent to the system

- **Case ID:** 304066
- **Priority:** Normal
- **Status (at export):** Untested

### Steps

Execute  with any amount and submerchant
https://sbox-platform.wellfit.com/payments/credit-card-present/charge-card

{
//  "subMerchantId": "01334270",
 //"subMerchantId": "A36C0000-3A32-000D-5A1D-08DD1961183D",
 //"subMerchantId": "A372295A-7AEB-4184-B4E9-16AB615237C4", //Stage -468
 //"subMerchantId": "105ABFBF-EE77-48AD-BF89-2C8B9665DE16", //QA -468
  //"subMerchantId": "1D550000-3A34-000D-889B-08D43C1753A8", //QA -11
   //"subMerchantId": "159F2670-1B71-4EF6-AD30-0EBF0991E2CC", //stage -11
  //"subMerchantId": "15C89B01-D2A4-48F8-9C2B-9BA1F2094076", //Stage - Disabled Merchant
  "subMerchantId": "A372295A-7AEB-4184-B4E9-16AB615237C4", //Pre Prod -468
  "amount": 80,
 "laneId": 1,//Ingenico
 // "laneId": 30,//EX8000  
  "orderId": "Radorder11185"
 // "metadata": "{\“clientData\“:\“Test Data\“}"
}

---

## 3. Validate that CP partial refund is successfully stored as 'Approved' in Payments  DB

- **Case ID:** 304067
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

## 4. Validate that  CP partial refund gets "SettlementDate"value filled via query through Payments  DB Table

- **Case ID:** 304070
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

- **Case ID:** 304068
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

## 6. Validate that  "FundingInstructions" and "SettlementDate" are not NULL for CP partial refund in Payments  DB Table after creating FundingBatch via API

- **Case ID:** 304069
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

- **Case ID:** 304071
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Values match ACH transaction an funding instructions batch

### Steps

Execute the following queryes updating transactionId value properly
 
SELECT [id], [fundingInstructionId], [payFacFee], [amount] From payments.payments where transactionId = '83999403816107069'

 
SELECT TOP 3 * from payments.fundingInstructions order by timestamp desc
Observe values matching

---

## 8. Validate that POST treasury/send-funding-batch API can be successfully executed 202 OK

- **Case ID:** 304072
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

- **Case ID:** 304073
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get Batch File Name

### Steps

Execute the following query
 
SELECT * FROM Payments.FundingBatches order by requestSentTimestamp desc 
Observe most recent value according to date when you send funding batch

---
