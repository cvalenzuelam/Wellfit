# Wallet (MyWallet) — Release 9.6 STAGE

Part of **Regression - STAGE** → module **Wallet**.

## Import

1. Re-import `../Regression-STAGE/Regression-STAGE.postman_collection.json`
2. Re-import / refresh env `../Regression-STAGE/Regression-STAGE.postman_environment.json`
3. Select env **Regression STAGE**

## Testmo map

### A. PAY-1128 Adding New Cards (8 — all Untested)

| Folder | Case ID |
|--------|---------|
| TC01 Auth | 67588 |
| TC02 Create wallet | 67589 |
| TC03 Add card token | 67590 |
| TC04 SQL Wallet/Token | 67591 |
| TC05 Validation negatives | 67592 |
| TC06 Tokenize confirmation | 67593 |
| TC07 SQL token logged | 67594 |
| TC08 SQL TokenId stored | 67595 |

### B. PAY-1127 Removing Stored Cards (7 — all Untested)

| Folder | Case ID | Notes |
|--------|---------|-------|
| TC01 Delete success | 67603 | |
| TC02 Delete no auth → 401 | 67604 | |
| TC03 Subscription delete | 67605 | **PARKED** — needs fixture |
| TC04 Payment plan delete | 67606 | **PARKED** — needs fixture |
| TC05 Delete missing token | 67607 | |
| TC06 Delete all brands | 67608 | VISA/MC/Amex/Discover |
| TC07 SQL after delete | 67609 | |

## Host / auth

- `walletBaseUrl` = `https://stage-platform.wellfit.com/wallet` (health 200; azure twin also alive)
- Client: `WellfitUnifiedPaymentsAPI` (scopes include Wallet Read/Write)
- Token field: **`accessToken`** → env `walletBearerToken`
- `walletSubMerchantId` default from Wallet API collection STAGE comment (`A372295A-…`)

## SQL

- DB dropdown: **Wallet**
- Visualize in A TC04/TC07/TC08 and B TC07
- Script: `wallet-db-checks-STAGE.sql`
- If columns unknown → run discovery Visualize and paste results
