# Release 9.6 — STAGE regression context (QA)

Last updated: 2026-07-23 (Chris + Cursor) — Treasury ACH C/F STAGE run logged

## Postman (canonical)

**Day-to-day import:** folder **`Wellfit Payments/`** (rebuild: `python3 "Wellfit Payments/rebuild.py"`)

| File | Postman name |
|------|----------------|
| `Wellfit Payments/Wellfit Payments.postman_collection.json` | **Wellfit Payments** |
| `Wellfit Payments/Wellfit Payments STAGE.postman_environment.json` | **Wellfit Payments STAGE** |

Tree:

```
Wellfit Payments
├── 1 — Core
├── 2 — Tickets
└── 3 — Regression
    ├── CNP · TokenVault · Wellfit Provisioning · Wallet · PAY-2603 · Treasury
    └── Treasury
        ├── 00. Shared setup
        ├── A. CP Payment (PARKED)
        ├── B. CP Refund (PARKED)
        ├── C. CNP Payment
        ├── D. CNP Refund
        ├── E. ACH Payment
        ├── F. ACH Refund
        └── G. holiday skip (PARKED)
```

Source of truth for edits: `regression/9.6/Regression-STAGE/` (+ `postman/collections/core|tickets/`).

## 2026-07-23 — Treasury STAGE run (Chris)

### Verdict summary

| Module | Verdict | Notes |
|--------|---------|--------|
| **Treasury E — ACH Payment** | **PASS WITH CAVEATS** | TC02 seed blocked; existent-txn path passed through Funded + send |
| **Treasury F — ACH Refund** | **PASS WITH CAVEATS** | 10 Passed · 1 Blocked · 1 Skipped · 0 Failed |

### Blocked (candidate bugs / infra — review tomorrow)

| Item | Where | What | Workaround used |
|------|--------|------|-----------------|
| **payments-v2 ACH sale HTTP 500** | `POST {{paymentsV2BaseUrl}}/api/v1/payments` | Treasury **E TC02** + **F TC02** (Testmo #2 new txn) fail on seed | **F TC03** existent txn from Payments DB discovery SQL |
| Host | `https://stage-wf-payments-v2-api.azurewebsites.net` | Idempotency-Key + raw bank `011075150`/`1099999996` | Same body as collection — not a Postman config issue |

**Tomorrow:** open bug or ping dev if 500 persists — blocks “happy path” new-txn ACs for ACH Treasury C/F.

### Skipped (not Fail — document in Testmo)

| Testmo # | Case | Why Skipped |
|----------|------|-------------|
| **F #9** | Funded status **5** after create (303929) | **Partial refund path:** original ULID stays **18** (PARTIALLY_REFUNDED), not **5**. Treasury FI on refund row still proved in #8. |

**Tomorrow:** only chase as bug if product expects status **5** on original after partial refund + create-funding-batch. Otherwise leave **Skipped** with comment.

### Passed with caveats (no bug unless team wants strict AC)

| Item | Detail |
|------|--------|
| **F #5** full refund status **10** | Ran on **separate** txn `01KY8JGEE…` (not partial ULID). Needed two refunds (0.50 partial then 0.65 FULL). `FundedDate` / Platform `SettlementDate`+FI non-null because txn had prior funding (history status 5) — not introduced by refund API. |
| **F partial path** | Main proof txn: `01KY8JERAHG0PZD6XDF5X0E2B8` / Platform charge `84087816562737378` / refund `84087816607357422` / partial **0.50** → status **18**. |

### Treasury F — Testmo final marks (2026-07-23)

| # | Mark |
|---|------|
| 1 Auth | **Passed** |
| 2 New txn | **Blocked** (v2 500) |
| 3 Existent + partial refund | **Passed** |
| 4 Status 18 | **Passed** |
| 5 Full refund 10 | **Passed** (separate txn) |
| 6 SettlementDate | **Passed** |
| 7 create-funding-batch | **Passed** |
| 8 FI on refund | **Passed** |
| 9 Funded 5 | **Skipped** |
| 10 FIPC/FISC | **Passed** |
| 11 send | **Passed** (`correlationId` `0e40dcfc-b1c8-4a88-a554-779395390e85`) |
| 12 FundingBatches | **Passed** (`07-23-2026_23-29-29-7087_DOYXYKKC.xml`) |

### Treasury E — ACH Payment (same session)

| TC | Mark | Notes |
|----|------|--------|
| TC02 seed | **Blocked** | Same payments-v2 **500** |
| TC03–TC10 | **Passed** | Existent txn `01KY8JGEE06Z4SW7C3JD0BGMYK` / `84087816562737956`; Funded **5** + send OK |

### PARKED (no run — not STAGE failures)

| Section | Reason |
|---------|--------|
| **A/B CP** Payment + Refund | Physical CP lane / `cardToken` |
| **G** holiday skip | Calendar timing case 304094 |

### Other modules same day (if filing bugs)

| Module | Fail / Parked | Follow-up |
|--------|---------------|-----------|
| **PAY-2603** TC04 | **Failed** | Invalid zip → HTTP **200 + SqlException** instead of **4xx** (add-token) |
| **PAY-2603** TC06–07, TC12 | **Parked** | CP lane / alert inject |
| **TokenVault** TC05–07, 13 | **Parked** | CP lane |
| **Wallet** B TC03–04 | **Parked** | Subscription fixtures |

### Key STAGE txn IDs (Treasury ACH — keep for SQL/App Insights)

| Use | Payments ULID | Platform processor txn |
|-----|---------------|------------------------|
| Partial refund + treasury F | `01KY8JERAHG0PZD6XDF5X0E2B8` | `84087816562737378` |
| Refund Platform row | — | `84087816607357422` (0.50) |
| Full refund #5 / ACH Payment E | `01KY8JGEE06Z4SW7C3JD0BGMYK` | `84087816562737956` |
| FI batch (F #10) | — | FISC `32220000-a5b1-70a8-2f47-08dee9123d38` @ ~23:29 UTC |

### Collection fixes applied post-run (re-import `Wellfit Payments/`)

- Separate env: `treasuryAchPartialRefundAmount` (0.50) vs `treasuryAchFullRefundAmount` (1.15)
- **F TC05** runnable (full refund on `achFullRefund*` vars, not PARKED)
- **F TC10** FIPC/FISC JOIN SQL (not TOP 3 dump)
- Treasury letters reordered: **A/B CP → C/D CNP → E/F ACH → G**

---

## Status snapshot (other modules)

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

### Treasury — Settlement & Funding

**ACH E/F aligned to `ACH payments-v2`** (2026-07-23): azure `paymentsV2BaseUrl`, `bearer-token`, raw bank `011075150`/`1099999996`. Refunds: Identity `WellfitUnifiedPaymentsAPI` → PM `/api/transactions/{id}/refund` (PAY-4064).

| Section | Notes |
|---------|--------|
| A/B CP Payment + Refund | **PARKED** — physical CP lane |
| C CNP Payment | **Runnable** — see 2026-07-23 run log above for CNP B if done |
| D CNP Refund | **Runnable** — partial refund + funding path |
| E ACH Payment | **Runnable** — TC02 seed **blocked** (v2 500); existent txn OK |
| F ACH Refund | **Runnable** — see Testmo marks in 2026-07-23 section |
| G Holiday skip | **PARKED** — calendar timing (case 304094) |
| Auth | Charges: Bearer · Treasury: header **`api_key`** |
| Host | `https://stage-platform.wellfit.com/treasury` — docs `treasury/` |

## Resume next session

1. Re-import **`Wellfit Payments/`** (collection + env).
2. **Tomorrow bugs/avisos:** payments-v2 ACH **500** (blocks E/F TC02); optional PAY-2603 TC04 SqlException; clarify F #9 Skipped vs product intent.
3. Re-test **E TC02 / F TC02** when v2 is healthy — should unblock Testmo #2.
4. PARKED: CP A/B, G holiday, TokenVault/Wallet/PAY-2603 CP cases.
