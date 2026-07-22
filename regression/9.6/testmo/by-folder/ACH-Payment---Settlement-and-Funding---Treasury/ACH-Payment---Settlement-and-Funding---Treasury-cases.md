# ACH Payment - Settlement and Funding - Treasury

Cases: **10**

## 1. Validate that POST  /payments/authenticate API is 200 OK

- **Case ID:** 303899
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

## 2. Validate that ACH Payment can be successfully sent to the system

- **Case ID:** 303900
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get BearerToken key

### Steps

Execute  with any amount and submerchant

https://stage-wf-payments-v2-api.azurewebsites.net/api/v1/payments

{
  "subMerchantId": "A372295A-7AEB-4184-B4E9-16AB615237C4", 
  "transactionType": "Sale",
  "amount": 90,
  "currency": "USD",
  "orderId": "ORD-2025-033",
  "orderIdType": "Invoice",
  "paymentMethod": {
    "type": "Ach",
    "ach": {
       "token": "86620000-05d5-2235-d31a-08de9b0feb51",
        "secCode": "WEB",

 
       //ACH payment raw details - token stored in TokenVault.BankAccountTokens,
        "authorization": {
            "AuthorizationType": "VERBAL_IN_PERSON",
            "AuthorizationDate": "2026-04-06T09:15:00-05:00",
            "AuthorizationReference": "VISIT-20260406-DB",
            "SignedAuthorizationOnFile": null,
            "AuthorizingUserId": "front-desk-02",
            "DisclosureConfirmed": true
        }
    }
  },
  "metadata": "{\"invoiceId\": \"INV-002\", \"customerId\": \"CUST-67890\"}"
}

---

## 3. Validate that ACH transaction is successfully stored as status 3 'Approved' in Payments and Platform DB Tables

- **Case ID:** 303906
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Payments DB

StatusId = 3 'Approved' for ACH transaction
SettlementDate = NULL
FundedDate = NULL

Platform DB

SettlementDate = NULL
FundingInstructions = NULL
Status = Approved

### Steps

Execute the following querys in Payments DB, changing the paymentTransactionId properly

SELECT TOP 5* From Payments.PaymentRequests where paymentTransactionId = '01KS5SA4WQ2B7K302W50A5DN6C'
 
SELECT TOP 5* FROM Transactions.PaymentTransactionHistory where PaymentTransactionId = '2113c14b-e3dd-4e8a-8fd3-7bc0c98cde0c' order by entityCreatedAt DESC

 
SELECT *   FROM [Transactions].[PaymentTransaction] where PaymentTransactionId = '01KS5SA4WQ2B7K302W50A5DN6C'
Execute the following query in Plafrorm DB, changing the transactionId properly

 
SELECT * From payments.payments where transactionId = '83999403816107069'

---

## 4. Validate that  ACH transaction gets "SettlementDate"value filled via query through Payments  DB Table

- **Case ID:** 303909
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

- **Case ID:** 303907
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

## 6. Validate that  "FundingInstructions" and "SettlementDate" are not NULL for ACH transactionid in Payments  DB Table after creating FundingBatch via API

- **Case ID:** 303908
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

- **Case ID:** 303915
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

## 8. Validate that ACH transaction is successfully stored as status 5 'Funded' in Payments DB Tables

- **Case ID:** 303914
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Payments DB

StatusId = 5 'Funded' for ACH transaction
SettlementDate = previously manual update
FundedDate = NULL

### Steps

Execute the following querys in Payments DB, changing the paymentTransactionId properly

SELECT TOP 5* From Payments.PaymentRequests where paymentTransactionId = '01KS5SA4WQ2B7K302W50A5DN6C'
 
SELECT TOP 5* FROM Transactions.PaymentTransactionHistory where PaymentTransactionId = '2113c14b-e3dd-4e8a-8fd3-7bc0c98cde0c' order by entityCreatedAt DESC

 
SELECT *   FROM [Transactions].[PaymentTransaction] where PaymentTransactionId = '01KS5SA4WQ2B7K302W50A5DN6C'
Execute the following query in Plafrorm DB, changing the transactionId properly

 
SELECT * From payments.payments where transactionId = '83999403816107069'

---

## 9. Validate that POST treasury/send-funding-batch API can be successfully executed 202 OK

- **Case ID:** 303916
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

## 10. Validate that Payments.FundingBatches Table contains proper "BatchFileName" value after sending funding batch via API

- **Case ID:** 303917
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Get Batch File Name

### Steps

Execute the following query
 
SELECT * FROM Payments.FundingBatches order by requestSentTimestamp desc 
Observe most recent value according to date when you send funding batch

---
