# 9.6 — TokenVault Regression (STAGE)

## Source cases

Canonical CSV (TokenVault folder only): `TokenVault-cases.csv`  
Extracted from Run 789 full export → Folder = TokenVault.

Details: `CASE-REVIEW.md` · Testmo mirror: `../testmo/by-folder/TokenVault/`  
Resume / status: `../SESSION-CONTEXT.md`

Full run archive: `docs/archives/9.6/tokenvault2-full-run-789.csv`


## Postman

Import `../Regression-STAGE/` only (unified collection + one env). Open module **TokenVault**.

## CP / lead support

TC05–TC07 and TC13 need **QA lead support** (physical CP lane that returns `cardToken`). Simulator is not enough. Requests stay in the collection as PARKED.

## Case review (summary)

| # | Case | Verdict | Notes |
|---|------|---------|--------|
| TC01 | V1 process-card + processor token | OK | Use TokenVault `PaymentTokens` numeric token |
| TC02 | V1 process-card + Wellfit GUID | OK / risk | Needs add-token; STAGE may 409 Token not found on some GUIDs |
| TC03 | V1 Pay Page | OK | Same eProtect pattern as CNP |
| TC04 | V1 does **not** write TokenVault | OK | query before/after |
| TC05 | CP returns cardToken GUID | **Blocked** | Physical lane |
| TC06 | CNP with CP cardToken | **Blocked** | Depends on TC05 |
| TC07 | CP persists to TokenVault | **Blocked** | Depends on TC05 |
| TC08 | add-token persists | OK (scaffolded) | **Testmo body empty** in export |
| TC09 | V2 charge processor token | OK | `tokenType: 1` |
| TC10 | V2 charge GUID | OK / confirm | Confirm `tokenType` for GUID with Brett if fails |
| TC11 | V2 charge paypage | OK | `tokenType: 0` |
| TC12 | V2 may save to vault | OK | Scenario A/B manual compare |
| TC13 | CP cardToken field | **Blocked** | Same as TC05 |

### Testmo content gaps to fix later

1. **Case 167997 (TC08)** — Description / Expected / Steps empty in export.
2. Typos in titles (`tokenvalut`, `sucessful`, trailing `'` on TC10).
3. Cases still say `[Payments].[PaymentTokens]` — on STAGE that table is **`TokenVault.dbo.PaymentTokens`**.
4. PAY-2603 hotfix folder (12 cases) is separate — not in this package.

## Run order (STAGE, no hardware)

1. `00. Auth`
2. TC01 → TC04
3. TC08
4. TC09 → TC12 (TC10 needs GUID from TC02/TC08/TC09)

Skip / Blocked: TC05–TC07, TC13 until `cpLaneId` + terminal.

## SQL validation (in collection)

Each TC that needs DB proof has a **Send → Visualize** request. Copy SQL into Azure Data Studio.

| TC | SQL | DB | Expect |
|----|-----|-----|--------|
| 01 | Platform by `lastTransactionId` | Platform | `PaymentTypeMethod = 2` |
| 02 | Platform + TokenVault by GUID | Platform / TokenVault | PTM=2; vault row for GUID |
| 03 | Platform | Platform | `PaymentTypeMethod = 1` |
| 04 | Platform (+ TokenVault optional) | Platform / TokenVault | PTM=2; vault unchanged (API primary) |
| 05–07/13 | PTM=5 + TokenVault by GUID + PTM=2 (TC06) | both | when CP unblocked |
| 08 | TokenVault by GUID | TokenVault | row for `add-token` Id |
| 09–10 | Platform (+ TokenVault if GUID returned) | Platform / TokenVault | payment row |
| 11 | Platform | Platform | PTM=1 (confirm) |
| 12 | TokenVault by ProcessorToken (+ GUID / Platform) | TokenVault / Platform | A: new / B: no duplicate |

**Correct tables:** Platform `[Payments].[Payments]` · TokenVault `dbo.PaymentTokens` (not Platform `Payments.PaymentTokens`).

## Need from Chris / team

- [ ] Re-export TokenVault cases CSV with **Folder** + full Description (if you wanted a fresh-only export)
- [ ] STAGE **CP** `subMerchantId` + **laneId** that returns `cardToken` (not simulator 9999)
- [ ] Confirm V2 `tokenType` when `token` is Wellfit GUID (collection uses `1`)
- [ ] Fill Testmo TC08 (167997) text, or accept scaffolded Expected from this package
