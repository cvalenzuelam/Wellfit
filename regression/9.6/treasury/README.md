# Treasury — Settlement & Funding (9.6 STAGE)

## Postman

Module **Treasury** in `../Regression-STAGE/` · env **Regression STAGE**.

## Auth

| Call | Auth |
|------|------|
| `/payments/*` charges & refunds | Bearer (`Payment-Bearer-Token` from payments authenticate) |
| `/treasury/create-funding-batch` & `/send-funding-batch` | Header **`api_key`** (`treasuryApiKey`) — **not** Bearer |
| `/treasury/health` | none |

Host: `https://stage-platform.wellfit.com/treasury`

## Testmo coverage (~59 cases)

| Section | Folder | Runnable? |
|---------|--------|-----------|
| A | CNP Payment - Settlement and Funding - Treasury (9) | Yes |
| B | CNP Refund - Settlement and Funding - Treasury (9) | Yes |
| C | ACH Payment - Settlement and Funding - Treasury (10) | Needs `treasuryAchBankToken` |
| D | ACH Refund - Settlement and Funding - Treasury (12) | Partial — refund seed manual/PAY-4064 |
| E | CP Payment … Treasury (9) | **PARKED** CP lane |
| F | CP Refund … Treasury (9) | **PARKED** |
| G | Treasury holiday skip (1) | **PARKED** calendar timing |

## Typical order (CNP Payment)

1. Shared / section Auth  
2. process-card → save `treasuryTransactionId`  
3. SQL confirm SettlementDate NULL  
4. SQL UPDATE SettlementDate (business day)  
5. POST create-funding-batch → 202  
6. SQL FundingInstructionId filled  
7. POST send-funding-batch → 202  
8. SQL FundingBatches.BatchFileName  

## Gap before ACH Payment

Fill env `treasuryAchBankToken` = active `TokenVault.dbo.BankAccountTokens.Id` for STAGE ACH.

## SQL

`treasury-db-checks-STAGE.sql` · Visualize requests inside each TC.
