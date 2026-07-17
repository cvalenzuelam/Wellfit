# STAGE / Preprod hosts (QA) — verified & TBD

**Update when Chris confirms.** Prefer this over inventing `stage-*` twins.

## STAGE (known / used in QA)

| Service | Host / note | Status |
|---------|-------------|--------|
| Identity (Azure) | `https://stage-wf-identity-api.azurewebsites.net` | Verified (token works) |
| Identity (platform) | `https://stage-platform.wellfit.com/identity` | Known alternate |
| Payment Management API | `https://stage-wf-payment-management-api.azurewebsites.net` | Verified (PAY-4064) |
| Payments V2 API | `https://stage-platform.wellfit.com/payments-v2` | Verified alive (401 without token; PAY-3683 / PAY-4087). Alternate: `https://stage-wf-payments-v2-api.azurewebsites.net` |
| Worldpay Wrapper API | `https://stage-wf-worldpay-wrapper-api.azurewebsites.net` | Known (credentials rule) |
| Platform host (general) | `https://stage-platform.wellfit.com` | Known |
| Treasury | `https://stage-platform.wellfit.com/treasury` | Known (PAY-3821) |
| Payments func | `stage-wf-payments-func` (Azure Function App) | Known (ACH return FileProcessedEvent) |
| SQL server | `stage-platform-wellfit-sqlserver.database.windows.net` | Verified |
| SQL DBs | `Platform`, `Payments`, `TokenVault`, … | Verified |
| App Insights | `stage-insights` (RG often `stage-platform-core`) | Known (Azure portal rules) |

## Preprod / Sbox (partial — from tickets / ADS)

| Service | Host / note | Status |
|---------|-------------|--------|
| SQL server | `sbox-platform-wellfit-sqlserver.database.windows.net` | Seen in ADS connections |
| Payment Management API | `https://sbox-wf-payment-management-api.azurewebsites.net` | From PAY-4064 Jira |
| Identity | TBD | Ask Chris |
| Worldpay Wrapper | TBD | Ask Chris |
| App Insights | TBD | Ask Chris |

## ADS connection names Chris uses

- `platform_stage`, `payments_stage`, `tokenVault_stage`
- `platform_qa`, `payments_qa`, `tokenVault_qa` (likely other env — confirm)
- `wallet_qa`, `logs_qa`

## Gaps to fill with Chris

1. STAGE: any other APIs QA hits often (Compliance, Orchestrator, Account Updater HTTP, etc.)
2. Sbox/Preprod: Identity + Wrapper + Insights
3. Confirm `payments_qa` / `platform_qa` = which environment
