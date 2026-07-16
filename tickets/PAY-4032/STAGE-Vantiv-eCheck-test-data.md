# STAGE / Pre-Live — Vantiv eCheck (ACH) test bank data

Source: Confluence — “Valid Vantiv Cards for Testing” / “OLD Vantiv test cards” (eCheck section).  
Saved for PAY-4032 Worldpay Wrapper `POST /api/v1/echeck/sales` seeding.

## eCheck (Approved)

| Routing | Account |
|---------|---------|
| `011075150` | `1099999999` |
| `011075150` | `1099339999` |

Use these in Worldpay Wrapper eCheck sale bodies (`bankRoutingNumber` / `bankAccountNumber`).  
**Do not** use Apple Pay FPANs or card PANs for eCheck.

## Wrapper STAGE credential keys (Brett 2026-07-14 + BMAD PAY-4046)

| Postman var | Value | Source |
|-------------|-------|--------|
| `accountId` | `01334267` (shared cert, lower envs) | **`[Payments].[SubMerchantAccounts].AccountId` where `ProcessorId = 0`** — NOT Azure `processor__vantiv__merchantId` |
| `subMerchantId` | Wellfit **GUID** | `[Payments].[SubMerchants].Id` — must match that AccountId row. Brett DEV example: `2e390000-8d7e-7ced-cade-08debd891c22` |
| Azure `processor__vantiv__merchantId` | `01264096` | Env-wide payfac config only — **do not** put this in the eCheck sale body as `accountId` |
| `masterSubMerchantId` | `01291508` | Azure only — do not send as Postman `subMerchantId` |

SQL: `tickets/PAY-4032/scripts/find-echeck-submerchants-STAGE.sql` (query A = known-good cert list).

BMAD: PAY-4046 solution (known-good AccountId table) + PAY-4032 Express Lane + worldpay-wrapper contracts.


## Not for eCheck

- Apple Pay sandbox FPANs (Amex/MC/Visa/Discover) — card rail only.
- Random routing `011401533` / account `1234567890` from Brett’s generic template — caused STAGE `330 Invalid Payment Type` in PAY-4032 QA.
