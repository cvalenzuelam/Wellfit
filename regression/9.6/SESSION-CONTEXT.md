# Release 9.6 — STAGE regression context (QA)

Last updated: 2026-07-23 (Chris + Cursor) — PAY-2603 module added

## Postman (canonical)

Import **only** `Regression-STAGE/`:

| File | Postman name |
|------|----------------|
| `Regression-STAGE.postman_collection.json` | **Regression - STAGE** |
| `Regression-STAGE.postman_environment.json` | **Regression STAGE** |

Modules: **CNP** · **TokenVault** · **Wellfit Provisioning** · **Wallet** · **PAY-2603** · **Treasury**.

Old split collections live in `docs/archives/9.6-postman-backups/` — do not import those for day-to-day runs.

## Status snapshot

### CNP (~complete)

- Happy path brands + negatives exercised on STAGE.
- Tokens: numeric `TokenVault.dbo.PaymentTokens` (not `WPAC*`).
- Cards: `cnp/CNP-STAGE-vantiv-test-cards.md`.

### TokenVault (in progress / parked CP)

| TC | Notes |
|----|--------|
| 01–04 | Runnable; SQL Visualize (Platform / TokenVault) |
| 05–07, 13 | **PARKED** — physical CP lane |
| 08–12 | Runnable / V2 charges |
| Infra | `/tokenvault` **403 Site Disabled** → Start `stage-wf-tokenvault-api` |

### Wellfit Provisioning

| TC | Notes |
|----|--------|
| 01–06 | Mapped (auth → create → update → retrieve → SQL → GET MCC) |
| 07–09 | Untested at export — create/delete MCC + MCC 8021 |
| Host | `mpBaseUrl` = merchantprovisioning-api |
| Auth | `WellfitOnBoardingAPI` → `mpBearerToken` |

### Wallet / MyWallet (next — 2026-07-23)

| Section | Cases | Notes |
|---------|-------|--------|
| A PAY-1128 Adding | 67588–67595 | All **Untested** — Auth → create → Pay Page tokenize → SQL → negatives |
| B PAY-1127 Removing | 67603–67609 | All **Untested** — delete / 401 / brands / SQL |
| B TC03–TC04 | 67605–67606 | **PARKED** — need subscription / payment-plan linked token fixtures |
| Host | `walletBaseUrl` = `https://stage-platform.wellfit.com/wallet` | Verified health + auth |
| Auth | `WellfitUnifiedPaymentsAPI` → **`accessToken`** → `walletBearerToken` |
| SQL | DB **Wallet** — Visualize; `wallet/wallet-db-checks-STAGE.sql` (columns via SELECT * / discovery) |

**SQL DBs**

- Platform → Payments / SubMerchants / MerchantProvisioning
- TokenVault → `dbo.PaymentTokens`
- **Wallet** → `dbo.Wallet`, `dbo.Token`, `dbo.TokenPurgeLog` (ADS: `wallet_qa` / STAGE Wallet DB)

**ADS tip:** **Run** only — not Estimated Plan.

## Hosts / auth (STAGE)

- Payments: `https://stage-platform.wellfit.com/payments`
- TokenVault: `https://stage-platform.wellfit.com/tokenvault`
- Merchant Provisioning: `https://stage-wf-merchantprovisioning-api.azurewebsites.net`
- Wallet: `https://stage-platform.wellfit.com/wallet`
- Payments / TokenVault / Wallet client: `WellfitUnifiedPaymentsAPI`
- Provisioning client: `WellfitOnBoardingAPI`

### PAY-2603 Bug/HotFix (TokenVault zip / Wellfit GUID)

| TC | Notes |
|----|--------|
| 01–05 | **Runnable** — `POST /add-token` zip matrix (omit / with / `""` / invalid / regression) |
| 06–07 | **PARKED** — CP lane (`cardToken`) |
| 08–11 | **Runnable** — CNP process-card ± zip + GUID charge + SQL |
| 12 | **PARKED** — force Wellfit-token failure + DevOps alert |
| SQL | TokenVault `dbo.PaymentTokens` · Platform `[Payments].[Payments]` — `pay-2603/` |

### Treasury — Settlement & Funding (~59 cases)

| Section | Notes |
|---------|--------|
| A CNP Payment | **Runnable** — charge → set SettlementDate → create/send funding batch + SQL |
| B CNP Refund | **Runnable** — partial refund then same funding path |
| C ACH Payment | Needs `treasuryAchBankToken` in env |
| D ACH Refund | Partial scaffold — seed refund via PAY-4064 pattern |
| E/F CP | **PARKED** — physical CP lane |
| G Holiday skip | **PARKED** — calendar timing (case 304094) |
| Auth | Charges: Bearer · Treasury: header **`api_key`** (not Bearer) |
| Host | `https://stage-platform.wellfit.com/treasury` — docs `treasury/` |

## Resume next session

1. Re-import `Regression-STAGE/` (collection + env) when VPN is back.
2. Pick module: **Wallet**, **PAY-2603**, **Treasury** (start **00. Shared** → **A CNP Payment**), or **Wellfit Provisioning**.
3. Skip PARKED folders until fixtures/lane/calendar exist.
4. ACH Treasury: fill `treasuryAchBankToken` before section C.
5. After first Wallet SQL run, paste columns → `stage-sql-schema-verified.md`.
