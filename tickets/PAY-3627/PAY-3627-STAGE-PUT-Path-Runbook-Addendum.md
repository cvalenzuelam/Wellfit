# PAY-3627 — STAGE PUT-Driven Testing (Runbook Addendum)

**Companion to:** `PAY-3627-QA-Session-Runbook.md` and `PAY-3627-AchLimit-Worldpay-MaxTransactionAmount-Testing-Guide.md` (same folder)
**Postman:** `postman/collections/PAY-3627-STAGE-PUT-Driven.postman_collection.json` + `postman/environments/PAY-3627-STAGE-Environment.postman_environment.json`
**Date:** 2026-06-22

---

## Why this addendum exists

The DEV runbook drives every AC by **publishing a synthetic `SubMerchant.AchLimitConfig.Updated` CloudEvent** straight to Event Grid. **That is not available in STAGE:** QA does not hold the `EventGrid Data Sender` role on the STAGE `accounts` topic, and we are deliberately **not** opening direct topic publish in STAGE.

This addendum drives the identical AC set through the **real SubMerchant API write endpoint** instead:

```
PUT {SUBMERCHANT_API}/api/submerchants/{id}/ach-limits      (policy: ach-limits-admin)
  -> UpdateAchLimitConfigHandler upserts AchLimitConfig + audit log (single commit)
  -> publishes the REAL SubMerchant.AchLimitConfig.Updated event (best-effort, after commit)
  -> Service Bus topic: accounts / subscription: merchantprovisioning-api
  -> AchLimitConfigChangedHandler -> SubMerchantSyncService.SyncByIdAsync
  -> Vantiv eCommerce Provisioning API PUT (maxTransactionAmount)
```

The PUT path is *more* faithful than the synthetic publish: the publisher computes `prevMax`/`newMax`/`maxTransactionAmountChanged` itself from `MAX(card limit, ACH limit)`, and the write also exercises the `AchLimitConfig` table, audit log, and the PAY-3755 canonical dual-write — none of which the synthetic path touches.

---

## What changes vs the DEV synthetic runbook

| Aspect | DEV synthetic publish | STAGE PUT-driven |
|---|---|---|
| Trigger | Hand-crafted CloudEvent → Event Grid | `PUT /api/submerchants/{id}/ach-limits` |
| QA permission | `EventGrid Data Sender` on `accounts` topic + EG token | OAuth token with **`WellfitSubMerchantAPI.AchLimitsAdmin`** only (client `WellfitUnifiedPaymentsAPI`; it lacks `.Read`) |
| Event payload | QA types `prevMax`/`newMax`/`maxChanged` (can be wrong) | Service computes them from `MAX(card, ach)` |
| `maxChanged` control | Set the flag directly | Induced by **data** (ACH value vs card limit) |
| `AchLimitConfig` + audit rows | Not written (defensive check asserts *unchanged*) | **Written — expected.** The synthetic-path "must be unchanged" check does **not** apply here |
| AC4 (idempotency) | Re-publish identical event (true duplicate delivery) | Re-PUT same value (convergent repeat-safety); literal dedup is unit-tested |

---

## STAGE permissions — verified 2026-06-22

The DEV requirement (QA user holds EG Data Sender) is replaced by **two** things. Both were checked against STAGE Identity / config:

1. **QA's OAuth client must be granted `WellfitSubMerchantAPI.AchLimitsAdmin`** (the write scope behind the `ach-limits-admin` policy). **✅ Confirmed in STAGE:** the scope exists in `[Identity].[ApiScopes]`, and `[Identity].[ClientScopes]` grants it to client **`WellfitUnifiedPaymentsAPI`** (per-env secret in Key Vault — **not** `Test123!`).

   > **Gotcha — `WellfitUnifiedPaymentsAPI` holds `AchLimitsAdmin` but NOT `WellfitSubMerchantAPI.Read` in STAGE.** Consequences baked into the collection:
   > - **Request only `AchLimitsAdmin`** (`SM_SCOPE = WellfitSubMerchantAPI.AchLimitsAdmin`). In the `client_credentials` flow, requesting a scope the client doesn't hold (e.g. adding `.Read`) fails the whole token call with `invalid_scope`.
   > - **You cannot GET the SubMerchant** with this client (the read endpoint needs `.Read`). So the collection does **not** call `GET /api/submerchants/{id}`; it derives the card limit from `BASELINE_MAX` on a **fresh** SubMerchant (where `MAX == card`). For a non-fresh SubMerchant, read `[Payments].[SubMerchants].TransactionLimit` via SQL and set `CARD_LIMIT` manually after step 02.
   >
   > Verify query (run on `stage-platform-wellfit-sqlserver.database.windows.net` / `Platform`):
   > ```sql
   > SELECT C.ClientId, CS.Scope
   >   FROM [Identity].[Clients] C
   >   JOIN [Identity].[ClientScopes] CS ON CS.ClientId = C.Id
   >  WHERE CS.Scope LIKE 'WellfitSubMerchantAPI%' ORDER BY C.ClientId, CS.Scope;
   > ```

2. **The STAGE SubMerchant API service must be able to publish.** This is **service** config, not a QA permission — verify once. In STAGE the publisher uses an Event Grid **namespace** (`stage-wf-eventgrid`, `westus-1`) with an **access key** from Key Vault `stage-api-configs/common-eventgrid-accesskey`, routing event type `SubMerchant.AchLimitConfig.Updated` to topic `accounts`. *(This is an environment difference from DEV, which uses an EG domain — same code, different config. Behaviour is identical.)* If that key is missing/rotated or the topic/subscription isn't wired, the PUT still returns **200** but no event fires — see the failure mode below.

---

## Test order (important — differs from DEV)

On the PUT path you cannot set `maxTransactionAmountChanged` by hand — you induce it via the ACH value relative to the **card limit**. So the short-circuit ACs must run from a clean baseline (`ACH ≤ card`, i.e. `BASELINE_MAX == CARD_LIMIT`) **before** AC1 raises the MAX. A **fresh SubMerchant** (no ACH config) gives exactly that.

| Step | Postman request | AC | PUT ACH per-tx | Expected Vantiv MAX after |
|---|---|---|---|---|
| 1 | `00 - Setup` (×3 tokens) | — | — | — |
| 2 | `01 - Pre-flight` | — | set `SUB_MERCHANT_ID` (fresh) | — |
| 3 | `02` | — | capture `BASELINE_MAX` (sets `CARD_LIMIT` = `BASELINE_MAX`) | `BASELINE_MAX` (= card on a fresh SM) |
| 4 | `03 - AC3` | AC3 | `= CARD_LIMIT` | **unchanged** (`BASELINE_MAX`) |
| 5 | `04 - AC2` | AC2 | `= CARD_LIMIT − 100` | **unchanged** (`BASELINE_MAX`) |
| 6 | `05 - AC1` | AC1 | `= BASELINE_MAX + 1000` | **`NEW_ACH_LIMIT`** |
| 7 | `06 - Verify` (poll) | AC1 | — | `NEW_ACH_LIMIT` within ~2 min |
| 8 | `07 - AC9` | AC9 | payment `BASELINE_MAX + 1` | HTTP 2xx |
| 9 | `08 - AC4` | AC4 | `= NEW_ACH_LIMIT` (re-PUT) | stable at `NEW_ACH_LIMIT` |
| 10 | `99 - Cleanup` | — | `= CURRENT_ACH` (orig / 0) | back to `BASELINE_MAX` |

After every PUT, run `06 - Verify` (it's the shared read). `06` only asserts the value is numeric and logs it against `BASELINE_MAX`/`NEW_ACH_LIMIT` — interpret per the row above; the sign-off table below is the authority.

> AC2/AC3 assume `CARD_LIMIT == BASELINE_MAX`, which holds only on a **fresh** SubMerchant (no ACH config). If you use a non-fresh SubMerchant, its existing `ACH > card` makes `BASELINE_MAX > card`, and AC2/AC3 would *lower* the MAX instead of holding it — read the real card limit via SQL (`[Payments].[SubMerchants].TransactionLimit`), set `CARD_LIMIT` manually after step 02, or just use a fresh SubMerchant.

---

## How each AC is satisfied on the PUT path

- **AC1 (raise):** `BASELINE_MAX` is already `MAX(card, currentAch)`, so `BASELINE_MAX + 1000` always exceeds the card limit → publisher emits `maxChanged=true` → Vantiv updates. Robust without needing the card value.
- **AC2 (`maxChanged=false`):** ACH below card → `MAX(card, ach) = card = prevMax` → `false` → consumer short-circuits (`AchLimitConfigChangedHandler` returns before the Vantiv call).
- **AC3 (ACH = card):** ACH equal to card → same `false` short-circuit.
- **AC4 (idempotency):** The consumer has **no dedup store** — `SyncByIdAsync` sets an **absolute** MAX, so idempotency is by convergence. Re-PUT the same value → `maxChanged=false` → stable MAX, no double-write, no exception. The literal at-least-once *duplicate-delivery* path (same `(SubMerchantId, LastModifiedUtc)` delivered twice) is **not** reproducible from PUT (each PUT stamps a fresh timestamp) and is covered by `AchLimitConfigChangedHandlerTests`. Record AC4 accordingly — it is covered, not skipped.
- **AC9 (PAY-3610):** Unchanged from DEV — submit a payment for `BASELINE_MAX + 1` after AC1; expect 2xx.

---

## DB verification (STAGE)

Same `Platform` DB queries as the DEV runbook Appendix B, against the STAGE server: **`stage-platform-wellfit-sqlserver.database.windows.net` → `Platform`** (Azure AD auth). Two differences on this path:

1. **`AchLimitConfig` + `AchLimitConfigAuditLog` WILL change on every PUT.** That is correct here. The DEV runbook's §5.3/§10.2 "AchLimitConfig must be unchanged" assertion is **synthetic-path only** — do not apply it to the PUT path. Expect: `PerTransactionLimit`/`DailyLimit` reflect each PUT, and one audit row per changed field.
2. **MP-cached MAX (`[MerchantProvisioning].[SubMerchantDetails].MaxTransactionAmount`)** should track the live Vantiv MAX after each non-short-circuited PUT (the PAY-3755 dual-write). Use the DEV runbook's B3 query.

**No-MP-read fallback:** if QA can't get the `merchant-provisioning` read token in STAGE, skip `MP_TOKEN`/`02`/`06` and verify the MAX via SQL on `[MerchantProvisioning].[SubMerchantDetails].MaxTransactionAmount` instead (post-PAY-3755 the cache mirrors Vantiv). Note step `02` also seeds `CARD_LIMIT` from the live MAX — if you skip it, set `BASELINE_MAX` and `CARD_LIMIT` manually from SQL.

---

## Primary failure mode on this path: "200 PUT but MAX never moves"

Because publish is **best-effort** (`EventPublisherExtensions.PublishAchLimitConfigChangedAsync` catches and logs at Warning, never rethrows), a publish failure is invisible at the HTTP layer — the PUT still returns **200**. If `06 - Verify` never shows the expected MAX:

1. **Confirm the event was published** — App Insights for the **SubMerchant API** (STAGE), `customEvents`:
   ```kusto
   customEvents
   | where timestamp > ago(15m)
   | where name == "AchLimitConfigChangedPublished"
   | order by timestamp desc
   ```
   No row → publish failed. Then check traces for the Warning:
   ```kusto
   traces
   | where timestamp > ago(15m)
   | where message has "Failed to publish" and message has "SubMerchant.AchLimitConfig.Updated"
   | order by timestamp desc
   ```
   A row here → the STAGE EG access key / topic wiring is the problem (see permission #2 above), not the feature.
2. **If the event published but Vantiv didn't move** — fall through to the DEV runbook §5.4 / Appendices C–D (merchant-provisioning-ms handler traces, Service Bus `accounts` → `merchantprovisioning-api` active/dead-letter counts). Note STAGE Service Bus namespace is `stage-payments-bus.servicebus.windows.net`.

---

## Sign-off (STAGE PUT path)

| AC | Description | Pass / Fail | Notes |
|----|---|---|---|
| AC1 | PUT ACH above card → Vantiv MAX raised to `NEW_ACH_LIMIT` within 2 min |  |  |
| AC2 | PUT ACH below card → `maxChanged=false` → MAX unchanged |  |  |
| AC3 | PUT ACH = card → `maxChanged=false` → MAX unchanged |  |  |
| AC4 | Re-PUT AC1 value → MAX stable, no double-update, no exception (convergent idempotency; dedup unit-tested) |  |  |
| AC9 | **PAY-3610** — ACH payment > `BASELINE_MAX` returns 2xx |  |  |

**SubMerchant API publish confirmed in App Insights (`AchLimitConfigChangedPublished`):** ☐ Yes  ☐ No
**Tester:** _______________   **Date:** _______________   **STAGE SubMerchantId used:** _______________
