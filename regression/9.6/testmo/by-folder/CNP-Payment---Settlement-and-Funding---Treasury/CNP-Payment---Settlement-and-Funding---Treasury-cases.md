# CNP Payment - Settlement and Funding - Treasury

Cases: **9**

## 1. Validate that POST  CNP /payments API is 200 OK

- **Case ID:** 303953
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

## 2. Validate that CNP Payment can be successfully sent to the system

- **Case ID:** 303954
- **Priority:** Normal
- **Status (at export):** Untested

### Steps

Execute  with any amount and submerchant
https://stage-platform.wellfit.com/payments/credit-card/process-card
  "amount": {{$randomPrice}},
  "cvv": "349",
  "expirationDate": "0327",
  "network": "VI",
  "orderId": "Postman-{{$randomPrice}}",
  "payFacFee": 0.00,
//  "subMerchantId": "01334270",
//"subMerchantId": "a36c0000-3a32-000d-5a1d-08dd1961183d",
 //"subMerchantId": "1d550000-3a34-000d-889b-08d43c1753a8", //QA -11
//"subMerchantId": "105ABFBF-EE77-48AD-BF89-2C8B9665DE16", // QA -468
"subMerchantId": "4431318D-E50D-4A3B-AAB7-FB65B489F5AF", // Stage -Park West - 101
//"subMerchantId": "159F2670-1B71-4EF6-AD30-0EBF0991E2CC", // Stage -Redhil
//"subMerchantId": "3C8C0000-FF98-0003-AA5B-08D6B3AFD5A4", // Stage -Monet
"token": "BB2D0000-480B-0022-FF16-08DD680F655F", //token guid
 //"token": "113300101080009", //processor token
  "zipCode": "33333",
  "metadata": "{\"test\":\"12218\"}"
}

---

## 3. Validate that CNP transaction is successfully stored as 'Approved' in Payments  DB

- **Case ID:** 303955
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

## 4. Validate that  CNP transaction gets "SettlementDate"value filled via query through Payments  DB Table

- **Case ID:** 303958
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

- **Case ID:** 303956
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

## 6. Validate that  "FundingInstructions" and "SettlementDate" are not NULL for CNP transaction in Payments  DB Table after creating FundingBatch via API

- **Case ID:** 303957
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

- **Case ID:** 303960
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

- **Case ID:** 303961
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

- **Case ID:** 303962
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get Batch File Name

### Steps

Execute the following query
 
SELECT * FROM Payments.FundingBatches order by requestSentTimestamp desc 
Observe most recent value according to date when you send funding batch

---
