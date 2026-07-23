# PAY-2603 — Card Token Vault / Wellfit Token (9.6 STAGE)

Bug/HotFix: Token Vault fails to return Wellfit token (cardZipCode handling).

## Postman

Module **PAY-2603** inside `../Regression-STAGE/` (env **Regression STAGE**).

## Testmo map (12 — all Untested)

| Folder | Case | Runnable? |
|--------|------|-----------|
| TC01 add-token omit zip | 168002 | Yes |
| TC02 add-token with zip | 168003 | Yes |
| TC03 add-token zip `""` | 168004 | Yes (2xx preferred or clear 4xx) |
| TC04 invalid zip ABCDE / 12 | 168005 | Yes (expect 4xx) |
| TC05 omit zip regression | 168006 | Yes |
| TC06 CP without zip → Wellfit token | 168007 | **PARKED** (CP lane) |
| TC07 CP GUID in TokenVault | 168008 | **PARKED** (needs TC06) |
| TC08 CNP with zip | 168009 | Yes |
| TC09 SQL TokenVault GUID | 168010 | Yes |
| TC10 CNP without zip | 168011 | Yes |
| TC11 CNP charge with Wellfit GUID | 213300 | Yes |
| TC12 failure + DevOps alert | 168012 | **PARKED** |

## Notes

- `add-token` may return **Returned existing token.** (idempotent by processorToken) — still PASS for TC01–TC03/TC05.
- **TC04** uses a **unique NUMERIC** `processorToken` per Send (`1111…` + timestamp — not alphanumeric `PAY2603-INVZIP-*`, not `tokenVisa`) so invalid zip is validated instead of idempotent return.
- Table is **`TokenVault.dbo.PaymentTokens`** (not Platform `Payments.PaymentTokens`).
- Auth: same as TokenVault module (`Payment-Bearer-Token`).
- SQL script: `pay-2603-db-checks-STAGE.sql`
