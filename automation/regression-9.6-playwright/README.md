# Regression 9.6 — Playwright + TypeScript (STAGE API)

API automation suite for **Wellfit Payments → 3 — Regression**, kept in a **separate folder** from Postman.

| Manual (source of truth for clicks) | This suite |
|-------------------------------------|------------|
| `Wellfit Payments/` + `regression/9.6/Regression-STAGE/` | `automation/regression-9.6-playwright/` |

## Scope (senior QA cut)

### Automate now (API, STAGE)

| Module | Covered |
|--------|---------|
| **CNP** | Auth, process-card VI/AX/DI/MC, expired negative, partial refund, void |
| **TokenVault** | add-token, get-token-details, charge with processor token + Wellfit GUID |
| **PAY-2603** | add-token omit/with/empty zip |
| **Treasury** | `/health`, CNP charge seed; create/send funding **opt-in** |
| **Wallet / Provisioning** | Auth smoke |

### Skipped on purpose (not Fail)

| Area | Why |
|------|-----|
| **All CP** (TokenVault TC05–07/13, PAY-2603 TC06–07/12, Treasury A/B) | Physical lane / `cardToken` |
| **Treasury G holiday** | Calendar window |
| **SQL Visualize** | Azure Data Studio / ADS — keep in Postman for now |
| **eProtect Pay Page** (CVV/ZIP/TC14–17) | Form post + registrationId — Postman until helper lands |
| **Wallet B TC03–04** | Subscription fixtures |
| **ACH v2 new-txn seed** | Known STAGE 500 caveat — existent-txn path stays Postman |
| **PAY-2603 TC04 invalid zip** | Known STAGE bug (200 + SqlException) |
| **Treasury funding create/send** | Off unless `RUN_TREASURY_FUNDING=1` |

## Setup

```bash
cd automation/regression-9.6-playwright
cp .env.example .env   # optional — defaults match STAGE Postman
npm install
npx playwright install   # installs browsers; suite is API-only
```

## Run

```bash
npm test                 # full suite (skips stay skipped)
npm run test:smoke       # @smoke tagged only — ends with Testmo PASS list
npm run test:cnp
npm run test:tokenvault
npm run test:pay2603
npm run test:treasury
npm run report           # HTML report
```

After `test:smoke`, the console prints **TESTMO — mark as PASS** with the case titles that passed (copy those into Testmo). Failed cases are listed separately so you do not mark them Pass.

Opt-in funding mutation:

```bash
RUN_TREASURY_FUNDING=1 npm run test:treasury
```

## Design notes

- **Playwright `APIRequestContext`** — no UI; same runner you can later extend for eProtect browser flows.
- **`workers: 1`** — STAGE processor / token side effects are safer serial.
- Clients under `src/clients/` mirror Postman bodies (authenticate → `bearerToken`, Treasury `api_key`).
- Parked cases live in `tests/parked/` so the suite **documents** gaps instead of pretending coverage.

## Not in v1

- DB asserts (mssql driver)
- eProtect paypage helper
- Full Treasury ACH E/F orchestration
- CI pipeline wiring (add when STAGE secrets are in the runner)

## Mapping

Postman folder names ↔ specs:

```
3 — Regression / CNP          → tests/cnp/*
3 — Regression / TokenVault   → tests/tokenvault/*
3 — Regression / PAY-2603     → tests/pay-2603/*
3 — Regression / Treasury     → tests/treasury/* + tests/parked/*
3 — Regression / Wallet       → tests/wallet/*
3 — Regression / Provisioning → tests/provisioning/*
```
