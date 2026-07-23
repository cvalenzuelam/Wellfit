# ACH Refund - Settlement and Funding - Treasury

Cases: **12**

## 1. Validate that POST  /payments/authenticate API is 200 OK

- **Case ID:** 303923
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

## 2. Validate that ACH Refund with new payment transaction can be successfully sent to the system

- **Case ID:** 303924
- **Status (at export):** Untested

### Steps

Update transaction to status ID 6 in Payments DB

update Transactions.PaymentTransaction set TransactionStatusId = 6 where PaymentTransactionId = '01KS6AMKSH52T7G73EMWF9CBAQ'

Execute  

https://stage-wf-payment-management-api.azurewebsites.net/api/transactions/{{settledAchTransactionId}}/refund
 
curl --location 'https://stage-wf-payment-management-api.azurewebsites.net/api/transactions/01KS6AMKSH52T7G73EMWF9CBAQ/refund' \
--header 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjVCRUE3NEYzQzIzOENBOTY2N0U2NkVBMjI0QkZCMjE5IiwidHlwIjoiYXQrand0In0.eyJpc3MiOiJodHRwczovL3N0YWdlLXBsYXRmb3JtLndlbGxmaXQuY29tIiwibmJmIjoxNzc5NDAyNjcxLCJpYXQiOjE3Nzk0MDI2NzEsImV4cCI6MTc3OTQwNjI3MSwiYXVkIjpbIldlbGxmaXRDb21wbGlhbmNlTW9uaXRvckFQSSIsIldlbGxmaXRQYXltZW50TWFuYWdlbWVudEFQSSIsIldlbGxmaXRQYXltZW50c0FQSSIsIldlbGxmaXRQYXltZW50c1YyQVBJIiwiV2VsbGZpdFN1Yk1lcmNoYW50QVBJIiwiV2VsbGZpdFRva2VuVmF1bHQiLCJXZWxsZml0V2FsbGV0QXBpIl0sInNjb3BlIjpbIldlbGxmaXRDb21wbGlhbmNlTW9uaXRvckFQSS5UZXN0aW5nIiwiV2VsbGZpdFBheW1lbnRNYW5hZ2VtZW50QVBJLkZ1bGwiLCJXZWxsZml0UGF5bWVudHNBUEkuRGV2aWNlUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuZUNvbW1lcmNlUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuRWxlY3Ryb25pY0NoZWNrUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuUmVmdW5kUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNWMkFQSS5GdWxsIiwiV2VsbGZpdFN1Yk1lcmNoYW50QVBJLkFjaExpbWl0c0FkbWluIiwiV2VsbGZpdFRva2VuVmF1bHQuUmVhZEFjY2VzcyIsIldlbGxmaXRUb2tlblZhdWx0LldyaXRlQWNjZXNzIiwiV2VsbGZpdFdhbGxldEFwaS5SZWFkQWNjZXNzIiwiV2VsbGZpdFdhbGxldEFwaS5Xcml0ZUFjY2VzcyJdLCJjbGllbnRfaWQiOiJXZWxsZml0VW5pZmllZFBheW1lbnRzQVBJIiwiY2xpZW50X3JvbGUiOiJGbXBTZXJ2aWNlIn0.E8lO9vhxWmIMrZuC8Rq36DKXMDbNFqT5SvwfnfxUuUbx0QfadsiMWSh7crl_w-JbLtYZ1054po2nnUFmIwwUna0qJn2EYIvTfMpiuxHIAvhd2mS-YKIO2nNMf1rCoLKWUh3rtqrSuFQWK5ysblITHEkTWcBuKIR3Ax1IqULId2KOUuWBln2GRpomhrXz9DXEm7Da5bBaUsZs8V__-QkYO7P5lumHgDQIzN6qbr4se19VO6wIAjWqx_r88XzlaEGUuaBSKADgxvrNTWZNYdc8b5PhkyP4sxcJ0uYWHD27sFerUn87SmYtIHOwck1JbPGo7QsF_oNDsTkQuHZXfRt9FA' \
--header 'Idempotency-Key: token-037' \
--header 'Content-Type: application/json' \
--data '{
   "requestId": "token002",
   "amount": 12.00,
   "reason": "QA test - partial refund"
   
   
}'

---

## 3. Validate that ACH Refund with existent payment transaction can be successfully sent to the system

- **Case ID:** 303968
- **Status (at export):** Untested

### Steps

Update transaction to status ID 6 in Payments DB

update Transactions.PaymentTransaction set TransactionStatusId = 6 where PaymentTransactionId = '01KS6AMKSH52T7G73EMWF9CBAQ'

Execute  

https://stage-wf-payment-management-api.azurewebsites.net/api/transactions/{{settledAchTransactionId}}/refund
 
curl --location 'https://stage-wf-payment-management-api.azurewebsites.net/api/transactions/01KS6AMKSH52T7G73EMWF9CBAQ/refund' \
--header 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6IjVCRUE3NEYzQzIzOENBOTY2N0U2NkVBMjI0QkZCMjE5IiwidHlwIjoiYXQrand0In0.eyJpc3MiOiJodHRwczovL3N0YWdlLXBsYXRmb3JtLndlbGxmaXQuY29tIiwibmJmIjoxNzc5NDAyNjcxLCJpYXQiOjE3Nzk0MDI2NzEsImV4cCI6MTc3OTQwNjI3MSwiYXVkIjpbIldlbGxmaXRDb21wbGlhbmNlTW9uaXRvckFQSSIsIldlbGxmaXRQYXltZW50TWFuYWdlbWVudEFQSSIsIldlbGxmaXRQYXltZW50c0FQSSIsIldlbGxmaXRQYXltZW50c1YyQVBJIiwiV2VsbGZpdFN1Yk1lcmNoYW50QVBJIiwiV2VsbGZpdFRva2VuVmF1bHQiLCJXZWxsZml0V2FsbGV0QXBpIl0sInNjb3BlIjpbIldlbGxmaXRDb21wbGlhbmNlTW9uaXRvckFQSS5UZXN0aW5nIiwiV2VsbGZpdFBheW1lbnRNYW5hZ2VtZW50QVBJLkZ1bGwiLCJXZWxsZml0UGF5bWVudHNBUEkuRGV2aWNlUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuZUNvbW1lcmNlUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuRWxlY3Ryb25pY0NoZWNrUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNBUEkuUmVmdW5kUGF5bWVudHMiLCJXZWxsZml0UGF5bWVudHNWMkFQSS5GdWxsIiwiV2VsbGZpdFN1Yk1lcmNoYW50QVBJLkFjaExpbWl0c0FkbWluIiwiV2VsbGZpdFRva2VuVmF1bHQuUmVhZEFjY2VzcyIsIldlbGxmaXRUb2tlblZhdWx0LldyaXRlQWNjZXNzIiwiV2VsbGZpdFdhbGxldEFwaS5SZWFkQWNjZXNzIiwiV2VsbGZpdFdhbGxldEFwaS5Xcml0ZUFjY2VzcyJdLCJjbGllbnRfaWQiOiJXZWxsZml0VW5pZmllZFBheW1lbnRzQVBJIiwiY2xpZW50X3JvbGUiOiJGbXBTZXJ2aWNlIn0.E8lO9vhxWmIMrZuC8Rq36DKXMDbNFqT5SvwfnfxUuUbx0QfadsiMWSh7crl_w-JbLtYZ1054po2nnUFmIwwUna0qJn2EYIvTfMpiuxHIAvhd2mS-YKIO2nNMf1rCoLKWUh3rtqrSuFQWK5ysblITHEkTWcBuKIR3Ax1IqULId2KOUuWBln2GRpomhrXz9DXEm7Da5bBaUsZs8V__-QkYO7P5lumHgDQIzN6qbr4se19VO6wIAjWqx_r88XzlaEGUuaBSKADgxvrNTWZNYdc8b5PhkyP4sxcJ0uYWHD27sFerUn87SmYtIHOwck1JbPGo7QsF_oNDsTkQuHZXfRt9FA' \
--header 'Idempotency-Key: token-037' \
--header 'Content-Type: application/json' \
--data '{
   "requestId": "token002",
   "amount": 12.00,
   "reason": "QA test - partial refund"
   
   
}'

---

## 4. Validate that ACH partial refund is successfully stored as status  'Partial Refund' 18  in Payments and Platform DB Tables

- **Case ID:** 303925
- **Status (at export):** Untested

### Expected

Payments DB

StatusId = 18 'Partial Refund' for ACH transaction
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

## 5. Validate that ACH full refund is successfully stored as status  'Full Refund' 10  in Payments and Platform DB Tables

- **Case ID:** 303969
- **Status (at export):** Untested

### Expected

Payments DB

StatusId = 10 'Full Refund' for ACH transaction
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

## 6. Validate that  ACH refund  gets "SettlementDate"value filled via query through Payments/Platform  DB Table

- **Case ID:** 303928
- **Status (at export):** Untested

### Expected

Platform DB

SettlementDate = ExpectedDate

### Steps

Execute the following query in Plafrorm DB, changing the transactionId properly
 
 
UPDATE Payments.Refunds SET SettlementDate = '2026-05-21' where transactionId = '83999403816107069'

Execute to see change reflected

SELECT * From payments.Refunds where transactionId = '83999403816107069'

---

## 7. Validate that POST treasury/create-funding-batch API can be successfully executed 202 OK

- **Case ID:** 303926
- **Status (at export):** Untested

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

## 8. Validate that  "FundingInstructions" and "SettlementDate" are not NULL for ACH Refund in Payments  DB Table after creating FundingBatch via API

- **Case ID:** 303927
- **Status (at export):** Untested

### Expected

Platform DB

SettlementDate = ExpectedDate 
FundingInstructions = Contains FundingID
Status = Approved

### Steps

Execute the following query in Plafrorm DB, changing the transactionId properly
 
SELECT * From payments.refunds where transactionId = '83999403816107069'

---

## 9. Validate that ACH Refund is successfully stored as status 5 'Funded' in Payments DB Tables

- **Case ID:** 303929
- **Status (at export):** Untested

### Expected

Payments DB

StatusId = 5 'Funded' for ACH transaction
SettlementDate = previously manual update
FundedDate = NULL

### Steps

Execute the following querys in Payments DB, changing the paymentTransactionId properly


SELECT TOP 5* From Payments.PaymentRequests where paymentTransactionId = '01KS5SA4WQ2B7K302W50A5DN6C'
 
select top 10  *from Transactions.PaymentTransactionHistory order by entityCreatedAt desc
 

select top 10  *from Transactions.PaymentTransaction order by entityCreatedAt desc

Execute the following query in Plafrorm DB, changing the transactionId properly


 
SELECT * From payments.refunds where transactionId = '83999403816107069'

---

## 10. Validate that Payments.FundingInstructions Table contains proper co-relation of  "FIPC-PayFac", "FISC-NetSettlement" and "Id" against  "fundingInstructionId". "PayFacFee" and "Amount" values from  Platform Payments.Payments DB

- **Case ID:** 303930
- **Status (at export):** Untested

### Expected

Values match ACH transaction an funding instructions batch

### Steps

Execute the following queryes updating transactionId value properly
 
SELECT [id], [fundingInstructionId], [payFacFee], [amount] From payments.refunds where transactionId = '83999403816107069'

 
SELECT TOP 3 * from payments.fundingInstructions order by timestamp desc

Observe values matching

---

## 11. Validate that POST treasury/send-funding-batch API can be successfully executed 202 OK

- **Case ID:** 303931
- **Status (at export):** Untested

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

## 12. Validate that Payments.FundingBatches Table contains proper "BatchFileName" value after sending funding batch via API

- **Case ID:** 303932
- **Status (at export):** Untested

### Expected

Get Batch File Name

### Steps

Execute the following query
 
SELECT * FROM Payments.FundingBatches order by requestSentTimestamp desc 

Observe most recent value according to date when you send funding batch

---

