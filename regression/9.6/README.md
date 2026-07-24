# Release 9.6 — STAGE regression

## Postman — import only this folder

**`Regression-STAGE/`**

- Collection: **Regression - STAGE** (modules: **CNP** + **TokenVault**)
- Environment: **Regression STAGE**

Do **not** import the whole `9.6` tree into Postman.

## Layout

| Path | What |
|------|------|
| `Regression-STAGE/` | **Only** Postman JSON to import |
| `cnp/` | CNP cards, known tokens, Testmo extract, DB check SQL |
| `tokenvault/` | Case review, CSV, TokenVault README |
| `scripts/` | Shared SQL (e.g. PaymentTokens by brand) |
| `testmo/` | Run 789 exports split by folder |
| `SESSION-CONTEXT.md` | QA resume notes (status, hosts, blockers) |

## Playwright automation (API)

Separate suite (does not replace Postman):  
`automation/regression-9.6-playwright/` — Playwright + TypeScript, STAGE API smoke + parked CP/SQL skips. See that folder’s README.

Archives (print runs, full CSVs, old Postman splits): `docs/archives/9.6/` and `docs/archives/9.6-postman-backups/`.
