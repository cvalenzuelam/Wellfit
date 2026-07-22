# STAGE CNP — Vantiv / Worldpay Pre-Live test cards (from Confluence)

Source: Confluence test-card table (Chris, 2026-07-22). Use with **eProtect Pay Page** or raw PAN flows — **not** assumed for `ProcessorToken` in TokenVault.

`Any Any` under CVV/ZIP = processor usually **ignores** CVV and ZIP for that PAN. Do not use those for TC05/TC06.

## ACH (eCheck) — approved

| Routing | Account |
|---------|---------|
| `011075150` | `1099999999` |
| `011075150` | `1099339999` |

## Cards — Approved (happy path / Pay Page)

| PAN | Brand | CVV | ZIP | Notes |
|-----|-------|-----|-----|-------|
| `4457010000000009` | Visa | `349` | `01803` | **Also** used for CVV + ZIP/AVS checks (see below) |
| `4100200300011001` | Visa | `463` | — | Exp `05/21` (old) |
| `4457000400000006` | Visa | Any | Any | |
| `4457000200000008` | Visa | Any | Any | PDS / Hansa |
| `5112000300000001` | MasterCard | Any | Any | |
| `5435101234510196` | MasterCard | `987` | — | Exp `11/21` |
| `6011010100000002` | Discover | Any | Any | May Call Discover |
| `6011010140000004` | Discover | Any | Any | Paypages Discover |
| `375000026600004` | Amex | Any | Any | Approved; Paypages AMEX |
| `375001010000003` | Amex | Any | Any | Pick Up Card |
| `375001014000009` | Amex | Any | — | Exp `05/21` Approved |
| Prepaid Master/Visa rows | — | Any | Any | e.g. `5592106621450897` (Paypages “VISA” body) |

## Negatives used by 9.6 CNP regression

| Case | PAN | Brand | What Confluence says | How we test in Postman |
|------|-----|-------|----------------------|-------------------------|
| **TC05 CVV** | `374313304211118` | Amex | Decline CVV/CID Fail | eProtect → process-card (network AX) → expect CVV/CID decline (not 200 approval) |
| **TC05 alt** | `4457010000000009` | Visa | CVV + ZIP/AVS validation | eProtect with **wrong** CVV (not `349`) → expect eProtect CVV error (`881`–`883`) or no Success |
| **TC06 ZIP** | `5112000200000002` | MasterCard | Billing Zip Code mismatch | eProtect → process-card (network MC) → expect ZIP / Billing Zip mismatch (~409) |
| **TC06 alt** | `4457010000000009` | Visa | CVV + ZIP/AVS | eProtect CVV `349` → process-card with `zipCode` ≠ `01803` |
| **TC07 Expired** | `5112001900000003` | MasterCard | Expired Card | Optional Pay Page path; primary TC07 still uses `expirationDate: 0120` on token (API `ExpirationDate.Invalid`) |

## Other programmed declines (reference)

| PAN | Brand | Behavior |
|-----|-------|----------|
| `4457010100000008` | Visa | Insufficient Funds (CVV `992`, exp `0616`, ZIP `03038`) |
| `5112010100000002` | MasterCard | Invalid Account Number |
| `4457013200000001` | Visa | Do Not Honor |
| `4457012400000001` | Visa | Invalid transaction |
| `4457002900000007` | Visa | Generic Decline |
| `4457002800000008` | Visa | Invalid Transaction |
| `5112001800000004` | MasterCard | Invalid Merchant |
| `5112001700000005` | MasterCard | Invalid Account Number |
| `4457002700000009` | Visa | Issuer Unavailable |
| `375000030000001` | Amex | Call Issuer |
| `6011000400000000` | Discover | Call Discover |
| `4457002100000005` | Visa | Insufficient Funds |

## Pay Page eProtect failure PANs

| PAN | Brand | Message pattern |
|-----|-------|-----------------|
| `6011010000000003` | Discover | Invalid Card Number |
| `375001000000005` | Amex | Technical difficulties |
| `4457010200000007` | Visa | Technical difficulties |

eProtect response codes (Confluence): `870` Success; `871`–`876` / `881`–`883` Invalid Card Number–style; other → technical difficulties; **`889` Failure**.

## Amount-triggered errors (PAN `4895281000000006` Visa CVV `123` exp `12/25`)

| Amount | Code | Message |
|--------|------|---------|
| $1.02 | 20 | Declined |
| $2.59 | 23 | Duplicate |
| $2.67 | 21 | Expired |
| $0.04 | 24 | Declined - Pick Up Card |
| $2.69 | 24 | Stolen Card |
| $0.41 | 24 | Lost Card |
| $30.00 | 25 | Call Issuer |
| $2.52 | 101 | Invalid Amount |
| $2.53 | 101 | Invalid Card |
| $2.60 / $0.40 | 101 / 103 | Invalid Request |
| $0.57 | 105 | Not Authorized |
| $2.55 | 1002 | Host Error |

## QA rule

- **Token** `process-card` (`ProcessorToken`): often **ignores** CVV/ZIP even if you send them — do not use for TC05/TC06 proof.
- **Pay Page** + Confluence PANs above: use for CVV/ZIP/AVS negatives.
- STAGE Pay Page `paypageId`: `XhybNHfFjYF3aTRR` (Paypages collection).
