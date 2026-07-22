# STAGE CNP — process-card tokens (numeric ProcessorToken)

Updated 2026-07-22 from TokenVault query (digits only, not expired).

| Env key | ProcessorToken | Brand | Exp | Zip |
|---------|----------------|-------|-----|-----|
| `tokenVisa` | `1111000281821111` | Visa | 12/2034 | 01803 |
| `tokenVisaProven` | `113300101080009` | Visa | 03/2027 | — | Chris eCommerce (confirmed worked) |
| `tokenAmex` | `111300261500004` | Amex | 10/2030 | 75039 |
| `tokenDiscover` | `1114000265160004` | Discover | 10/2030 | 01803 |
| `tokenMc` | `1112000299535454` | Mastercard | 03/2050 | 06002 |
| `tokenVisaZipSensitive` | `1111000281821111` | Visa | 12/2034 | 01803 |

## Skip for process-card

- `WPAC*` / letter tokens
- GUID-like (`76A90000-…`)
- `tokenize-card` on platform payments → 404 on STAGE

## CVV / ZIP negatives

`ProcessorToken` rows (including former `tokenVisaZipSensitive`) **do not** reliably enforce CVV/ZIP on STAGE.

Use Confluence Vantiv PANs via **Pay Page** — see `CNP-STAGE-vantiv-test-cards.md`:

- CVV: `374313304211118` (Amex CID fail) or `4457010000000009` + wrong CVV
- ZIP: `5112000200000002` (Billing Zip mismatch) or `4457010000000009` + wrong zip
