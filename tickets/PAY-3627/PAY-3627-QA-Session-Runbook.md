# PAY-3627 QA Session Walkthrough

**For:** Facilitator running the live QA validation session
**Companion files:**
- `postman/collections/PAY-3627-QA-Session.postman_collection.json` — Postman has every request body/header
- `postman/environments/PAY-3627-Dev-Environment.postman_environment.json` — Postman env vars
- `PAY-3627-AchLimit-Worldpay-MaxTransactionAmount-Testing-Guide.md` — original cURL guide

**Read this top-to-bottom during the session. Postman has the request internals. SQL and App Insights queries are inline below.**

---

## Section 0 — Before you start the session

### 0.1 — Send to QA 24 hours ahead

> Before the session, please confirm:
> 1. Postman installed
> 2. VPN connected to Wellfit dev
> 3. `az login` against a Wellfit dev account
> 4. **EventGrid Data Sender** role on `dev-evgd-payments/topics/accounts` (ping Jason if not)
> 5. App Insights access for `merchant-provisioning-ms` in dev
> 6. SSMS or Azure Data Studio connected to `sqldb-plat-dev-001.database.windows.net` → `Platform` DB (we use the `MerchantProvisioning` and `Payments` schemas)
> 7. Import the two Postman JSON files I'll send separately

### 0.2 — Facilitator prep (10 minutes before)

1. Open Postman → import both JSON files → select **PAY-3627 Dev Environment** (top-right dropdown)
2. Fill in these env vars manually:
   - **`MP_CLIENT_SECRET`** — from Azure KV `kv-ops-common-westus3` → `Identity-MerchantProvisioning-ClientSecret`
   - **`EG_TOKEN`** — run in a terminal:
     ```
     az account get-access-token --resource "https://eventgrid.azure.net" --query accessToken -o tsv
     ```
     Paste the output into the env var. Lasts ~1 hour.
   - **`SUB_MERCHANT_ID`** — leave blank, set in Section 3
3. Open Postman → `00 - Setup` → click **Send** on "Get MP_TOKEN" then "Get PV2_TOKEN". Confirm both return 200.
4. Open Postman Console (View → Show Postman Console). Share-screen it during the session.
5. Open App Insights for `merchant-provisioning-ms` in a browser tab.
6. Open SSMS, connect to `sqldb-plat-dev-001.database.windows.net` → `Platform`.

---

## Section 1 — Frame the session (5 min)

**Say:**
> "We're validating PAY-3627. Quick story: before this fix, when we raised a SubMerchant's ACH per-transaction limit in our system, Worldpay didn't know about it. Worldpay's `MaxTransactionAmount` stayed pinned to the card limit, so ACH payments above the card limit got rejected by Worldpay even though our system said they were allowed. That broken state is **PAY-3610**.
>
> PAY-3627 fixes it by listening for ACH-limit-change events and pushing `MAX(cardLimit, newAchLimit)` into Worldpay automatically.
>
> Today we prove two things:
> 1. The new pipeline works end-to-end (AC1–AC4)
> 2. PAY-3610 stays fixed long-term — an ACH payment above the original card limit now succeeds at Worldpay (AC9)"

Show the pipeline on screen:

```
submerchant-ms
  -> Event Grid (dev-evgd-payments / topic: accounts)
  -> Service Bus (Accounts topic / subscription: merchantprovisioning-api)
  -> AchLimitConfigChangedHandler
  -> Vantiv eCommerce Provisioning API PUT (maxTransactionAmount)
```

**Ground rules:**
1. Always use a fresh SubMerchant. Old dev SubMerchants have accumulated bad state.
2. Don't skip ahead in the Postman folder — each step writes env vars the next reads.
3. When in doubt, check App Insights before declaring a bug.

---

## Section 2 — Confirm tokens (1 min)

**What I'm doing:** Sanity-check we have working tokens.

**Click in Postman:** `00 - Setup → Get MP_TOKEN` (Send), then `Get PV2_TOKEN` (Send).

**Expected result:**
- Both return HTTP 200
- Console shows: `MP_TOKEN captured. Expires in 3600 seconds.` and same for PV2
- "Token returned" test passes (green) on both

**If 401/400:** the secret in the env var is wrong. Fix `MP_CLIENT_SECRET` and retry.

---

## Section 3 — Pre-flight: fresh SubMerchant (5 min)

**What I'm doing:** Create or pick a freshly-provisioned SubMerchant, then verify it has a clean Vantiv record.

**Step 3.1 — Create or pick a SubMerchant**

Use your team's existing Postman scripts to create a new SubMerchant or pick a recent untouched one. Copy the SubMerchantId.

**Step 3.2 — Set the env var**

In Postman, click the env eye icon (top-right) → set `SUB_MERCHANT_ID` = the new SubMerchantId. Save (Ctrl+S).

**Step 3.3 — Confirm SubMerchant + provisioning record exist (SQL)**

Run in SSMS against `Platform` DB. This SubMerchant was created via Merchant Provisioning. The MP-cached Worldpay MAX lives on `[MerchantProvisioning].[SubMerchantDetails]`, reached by joining through `[MerchantProvisioning].[ProvisionedSubMerchants]`.

```sql
SELECT
    sm.Id                       AS SubMerchantId,
    sm.SubMerchantName,
    sm.TransactionLimit         AS CardTransactionLimit,
    psmd.MaxTransactionAmount   AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
LEFT JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
LEFT JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<paste SUB_MERCHANT_ID here>';
```

**Expected result:**
- Exactly 1 row
- `SubMerchantName` populated
- `CardTransactionLimit` is a number (e.g., 10000)
- `MerchantMax` is a number (e.g., 950) — proves MP has a SubMerchantDetail record with a MAX

**If 0 rows:** SubMerchant doesn't exist in Payments DB. Re-check the SubMerchantId.

**If `MerchantMax` IS NULL:** either no `ProvisionedSubMerchants` row (no MP provisioning) or no `SubMerchantDetails` row (provisioning incomplete). Pick a different SubMerchant. Do not continue.

**Also check ACH limits exist (or don't — both are fine, just informational):**

```sql
SELECT
    SubMerchantId,
    PerTransactionLimit,
    DailyLimit,
    LastModifiedUtc,
    LastModifiedBy
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<paste SUB_MERCHANT_ID here>';
```

If 0 rows: no ACH limit configured yet — that's fine for AC1 (we'll set it via the event). If 1 row: note the current `PerTransactionLimit` so you can confirm the AC1 event raises it.

---

## Section 4 — Baseline read (3 min)

**What I'm doing:** Capture the current Vantiv `MaxTransactionAmount`. This becomes `BASELINE_MAX` for all subsequent events.

**Click in Postman:** `02 - Baseline (Step 2) — captures BASELINE_MAX` → **Send**

**Expected result:**
- HTTP 200
- Response JSON contains `providerResponses[paymentProcessor=0].metadataAsProvisioningBase.subMerchant.maxTransactionAmount`
- Console: `BASELINE_MAX captured: 950` (your number will differ)
- All three test assertions pass:
  - "Vantiv provider response present"
  - "paymentProcessor=0 entry exists"
  - "maxTransactionAmount is a number"

**Write `BASELINE_MAX` on the whiteboard** — everyone in the room references this number.

**Sanity check vs. SQL:** the value Postman captured should equal `MerchantMax` from the Section 3.3 query (`[MerchantProvisioning].[SubMerchantDetails].MaxTransactionAmount`). If they disagree, the MP-side cache is drifting from Vantiv — flag it but continue.

---

## Section 5 — AC1: Happy path (10 min)

**What I'm doing:** Publish an event that raises the ACH limit by 1000. The handler should call Vantiv and the MAX should go up.

### 5.1 — Publish the event

**Click in Postman:** `03 - AC1 — Publish AchLimit Raise event` → **Send**

**Expected result:**
- HTTP 200, empty response body
- Console: `AC1 raise: baseline=950, newAchLimit=1950` (numbers will differ)
- "EG publish returned 200" test passes

### 5.2 — Verify Vantiv MAX updated

**Click in Postman:** `04 - AC1 — Verify Vantiv MAX (re-run until updated)` → **Send**

Wait 15 seconds. **Send** again. Repeat until Vantiv updates (typically 10–60 seconds, occasionally up to 2 minutes).

**Expected console output evolution:**

```
Current Vantiv MAX: 950 | baseline=950 | expected after AC1=1950
Vantiv MAX still at baseline — handler has not run yet (or short-circuited). Wait 15s and re-run.
```

then eventually:

```
Current Vantiv MAX: 1950 | baseline=950 | expected after AC1=1950
Vantiv MAX matches NEW_ACH_LIMIT — AC1 happy path passed.
```

**Pass criteria:** "AC1 — Vantiv MAX updated to NEW_ACH_LIMIT" test passes (green).

### 5.3 — Verify local DB MerchantMax updated — **PAY-3755 bug-fix proof**

**What I'm doing:** Confirm the local `[MerchantProvisioning].[SubMerchantDetails].MaxTransactionAmount` was written to match Vantiv. This is the explicit Definition of Done for PAY-3755 — before the fix, Vantiv would update but this column stayed stale. Run inline here (not deferred to Section 10) so you catch a regression at the moment of the test.

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    sm.TransactionLimit       AS CardTransactionLimit,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**Pass criteria:**
- `MerchantMax` = `NEW_ACH_LIMIT` (e.g., 1950) — **matches what Vantiv now reports**
- `CardTransactionLimit` = original card limit (unchanged — we never touched the card limit)

**If `MerchantMax` is still at `BASELINE_MAX`:** the bug PAY-3755 is fixing has regressed. Vantiv received the update but the canonical sync did not write the local row. Capture the App Insights `operation_Id` (Section 5.4) and flag immediately — do not continue with AC2/AC3/AC4.

**Also verify (defensive):** the consumer did NOT write to `[Payments].[AchLimitConfig]`. That table is owned by `submerchant-microservice`; the Postman synthetic-event path bypasses its publisher, so `SubMerchantSyncService` (which only owns `[Payments].[SubMerchants]` + `[MerchantProvisioning].[SubMerchantDetails]` + processor PUTs) must not have touched it.

```sql
SELECT
    PerTransactionLimit,
    DailyLimit,
    LastModifiedUtc,
    LastModifiedBy
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>';
```

**Pass criteria:** `PerTransactionLimit`, `DailyLimit`, `LastModifiedUtc`, and `LastModifiedBy` are **all unchanged from the Section 3.3 pre-flight query** (or 0 rows in both, if the SubMerchant has no ACH config). If any value moved, the canonical sync wrote to a table outside its bounded context — flag as a real bug, do not continue.

### 5.4 — If 2 minutes pass with no change, diagnose live

Open App Insights → `merchant-provisioning-ms` → Logs blade. Run these queries one at a time.

**Did the handler receive the event?**

```kusto
traces
| where timestamp > ago(10m)
| where message has_any ("AchLimitConfig", "VantivWorldpay", "MaxTransactionAmount", "AchLimitConfigChanged")
| order by timestamp desc
| take 50
```

- If rows appear → the handler ran. Check the next query for exceptions.
- If no rows → event didn't reach the handler. Service Bus or EG issue. Skip to Service Bus check below.

**Did the handler throw?**

```kusto
exceptions
| where timestamp > ago(10m)
| where outerMessage has_any ("AchLimit", "Vantiv", "maxTransactionAmount", "Provisioning")
| project timestamp, outerMessage, innermostMessage, operation_Id
| order by timestamp desc
```

- "Bank Account Number" length error → known bad-data issue, use a fresh SubMerchant.
- 403 from SubMerchant API → Platform DB identity script (PR #142) not deployed.

**Full operation trace (copy operation_Id from any matching trace):**

```kusto
union traces, exceptions, requests, dependencies
| where operation_Id == "<paste operation_Id here>"
| order by timestamp asc
```

**Service Bus check (Azure portal, not KQL):**
`Service Bus namespace dev-sbns-payments-westus3` → Topics → `accounts` → Subscriptions → `merchantprovisioning-api`
- Active Message Count > 0 and not draining → consumer is down
- Dead-letter Count > 0 → handler is throwing — see exceptions query above

**Mark AC1 ✅ on the sign-off table only after the verify request's assertion passes.**

---

## Section 6 — AC9: PAY-3610 regression (10 min) — the headline test

**What I'm doing:** Submit an ACH payment for `BASELINE_MAX + 1`. Before PAY-3627 this would have been rejected by Worldpay. After AC1 raised Vantiv MAX, this should succeed.

**Click in Postman:** `05 - AC9 — Submit ACH payment above BASELINE_MAX (PAY-3610 regression)` → **Send**

**Expected result:**
- HTTP 2xx (200 or 201)
- "AC9 — Worldpay accepts ACH payment > BASELINE_MAX (PAY-3610 fixed)" test passes

**If you get HTTP 422:**

Read the response body. If it mentions `per-transaction-limit`:

> "That's the SubMerchant API layer, not Worldpay. PAY-3627 is the Worldpay layer — we already proved that works in AC1 when Vantiv MAX went up. This 422 means the SubMerchant's application-level ACH limit hasn't been raised. **PAY-3610 is still proven fixed by AC1.**"

To re-run AC9 after seeing a 422: raise the SubMerchant's ACH per-transaction limit via your SubMerchant API to at least `BASELINE_MAX + 1`, then re-Send.

**Mark AC9 ✅ on the sign-off table when you get a 2xx.** This is the long-term confirmation that PAY-3610 stays fixed.

---

## Section 7 — AC2: Short-circuit on `maxTransactionAmountChanged=false` (5 min)

**What I'm doing:** Publish an event with `maxTransactionAmountChanged=false`. The handler should skip the Vantiv call entirely.

### 7.1 — Publish

**Click in Postman:** `06 - AC2 — Short-circuit (maxTransactionAmountChanged=false)` → **Send**

**Expected:** HTTP 200, empty body.

### 7.2 — Wait 30 seconds, then verify Vantiv unchanged

**Click in Postman:** `04 - AC1 — Verify Vantiv MAX` → **Send**

**Expected console:**

```
Current Vantiv MAX: 1950 | baseline=950 | expected after AC1=1950
Vantiv MAX matches NEW_ACH_LIMIT — AC1 happy path passed.
```

(Yes, "AC1 happy path passed" still — that's correct, the test asserts MAX = NEW_ACH_LIMIT. AC2 success means MAX **stayed** at NEW_ACH_LIMIT, didn't drop.)

**Pass criteria:** `CURRENT_MAX` equals `NEW_ACH_LIMIT` (unchanged from before AC2). If it dropped or changed, the handler isn't respecting `maxTransactionAmountChanged=false` — real bug.

**Optional SQL cross-check** (confirms MP cache also didn't move):

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

`MerchantMax` should still equal `NEW_ACH_LIMIT`. No movement from AC1's state.

**Mark AC2 ✅.**

---

## Section 8 — AC3: Short-circuit when ACH = card limit (5 min)

**What I'm doing:** Publish an event where ACH limit equals current MAX. Handler should skip Vantiv call.

### 8.1 — Publish

**Click in Postman:** `07 - AC3 — Short-circuit (ACH = card limit)` → **Send**

**Expected:** HTTP 200, empty body.

### 8.2 — Wait 30 seconds, verify unchanged

**Click in Postman:** `04 - AC1 — Verify Vantiv MAX` → **Send**

**Pass criteria:** `CURRENT_MAX` still equals `NEW_ACH_LIMIT`.

### 8.3 — Optional SQL cross-check (confirms MP cache also didn't move)

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

`MerchantMax` should still equal `NEW_ACH_LIMIT`. No movement from AC1's state — the short-circuit prevented any write.

**Mark AC3 ✅.**

---

## Section 9 — AC4: Idempotency (5 min)

**What I'm doing:** Re-publish the AC1 event. Handler should remain stable — no double-update, no exception.

### 9.1 — Re-publish

**Click in Postman:** `08 - AC4 — Idempotency (re-publish AC1 event)` → **Send**

**Expected:** HTTP 200, empty body.

### 9.2 — Wait 30 seconds, verify stable

**Click in Postman:** `04 - AC1 — Verify Vantiv MAX` → **Send**

**Pass criteria:** `CURRENT_MAX` still equals `NEW_ACH_LIMIT` — stable.

### 9.3 — Confirm no new exceptions in App Insights

```kusto
exceptions
| where timestamp > ago(5m)
| where outerMessage has_any ("AchLimit", "Vantiv", "maxTransactionAmount")
| project timestamp, outerMessage, innermostMessage
| order by timestamp desc
```

**Expected:** no rows (or only rows from earlier in the session, not in the last 5 min).

### 9.4 — Optional SQL cross-check (confirms MP cache also didn't move on redelivery)

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

`MerchantMax` should still equal `NEW_ACH_LIMIT` — stable across the duplicate event. If it changed, the canonical sync isn't idempotent under redelivery, which is a real bug.

**Mark AC4 ✅.**

---

## Section 10 — SQL cache verification (5 min, recommended)

**What I'm doing:** Confirm MP's local cache + the ACH limit config + the audit trail in `Platform` DB all reflect what we just did.

### 10.1 — MP-cached Worldpay MAX matches Vantiv

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    sm.SubMerchantName,
    sm.TransactionLimit       AS CardTransactionLimit,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**Expected after AC1–AC4:**
- `MerchantMax` = `NEW_ACH_LIMIT` (e.g., 1950) — matches what Vantiv reports
- `CardTransactionLimit` = baseline card limit (unchanged — we never touched the card limit)

### 10.2 — ACH limit config — informational (depends on test path)

```sql
SELECT
    SubMerchantId,
    PerTransactionLimit,
    DailyLimit,
    EffectiveDate,
    LastModifiedUtc,
    LastModifiedBy
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>';
```

**Expected — depends on how the test was driven:**

- **Synthetic-event path (this runbook's default):** `PerTransactionLimit` / `DailyLimit` / `LastModifiedUtc` / `LastModifiedBy` **unchanged from the Section 3.3 pre-flight query**. The Postman EG-publish bypasses `submerchant-microservice`'s publisher, so this table is never written by the test. **If you observe any change here it is a real bug** — `SubMerchantSyncService` should not own this table; see Section 5.3's defensive check.
- **API-driven path (only if QA actually called the SubMerchant API to update the ACH limit alongside or instead of publishing synthetic events):** `PerTransactionLimit` = `NEW_ACH_LIMIT`, `DailyLimit` = `NEW_ACH_LIMIT * 3`, `LastModifiedBy` reflects the SubMerchant API user.

### 10.3 — Audit trail of ACH limit changes

```sql
SELECT TOP 20
    SubMerchantId,
    FieldChanged,
    PreviousValue,
    NewValue,
    ChangedBy,
    ChangedUtc
FROM [Payments].[AchLimitConfigAuditLog]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>'
ORDER BY ChangedUtc DESC;
```

**Expected:** rows recording each `PerTransactionLimit` / `DailyLimit` change you made during the session. Useful for the sign-off paper trail.

### 10.4 — If `MerchantMax` doesn't match Vantiv

Re-run Postman `04 - Verify` to get the live Vantiv MAX. If they disagree:

- **MP cache lower than Vantiv:** handler updated Vantiv but failed to write the local row. Real bug.
- **MP cache higher than Vantiv:** handler updated local cache but Vantiv call failed. Real bug.

Either way — flag it, capture `operation_Id` from App Insights, and continue.

---

## Section 11 — Cleanup (3 min) — mandatory

**What I'm doing:** Reset Vantiv MAX back to `BASELINE_MAX` so the SubMerchant is in a known state for future tests.

### 11.1 — Publish reset event

**Click in Postman:** `99 - Cleanup — Reset Vantiv MAX to BASELINE_MAX` → **Send**

**Expected:** HTTP 200, empty body.

### 11.2 — Wait 30 seconds, verify reset

**Click in Postman:** `04 - AC1 — Verify Vantiv MAX` → **Send**

**Expected console:**

```
Current Vantiv MAX: 950 | baseline=950 | expected after AC1=1950
```

The "AC1 — Vantiv MAX updated to NEW_ACH_LIMIT" test will now **fail** (red) — that's expected, we just reset away from `NEW_ACH_LIMIT` back to `BASELINE_MAX`.

**Pass criteria:** `CURRENT_MAX` equals `BASELINE_MAX`. (Ignore the failed assertion — that test was AC1's pass condition, not the cleanup's.)

### 11.3 — Confirm MP cache also reset

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**Expected:**
- `MerchantMax` = `BASELINE_MAX` (back to original)

---

## Section 12 — AC10 + AC11: HTTP card-change tests (optional, ~15 min) — additional coverage

**What I'm doing:** Verify the HTTP `create/update-sub-merchant` path also writes both local DB columns and pushes to processors, and that `OverlayAchLimitIfPresent` correctly applies `MAX(newCard, currentAch)` on the HTTP path.

**Why optional:** PAY-3627 and PAY-3755 are scoped to the event-driven path. Sections 5–11 cover that exhaustively. Post-PAY-3755 both paths share `SubMerchantSyncService.SyncAsync`, so a passing Sections 5–11 gives **indirect** confidence in the HTTP path. Run AC10 + AC11 if you want **direct** end-to-end HTTP coverage. Skip if you don't have a Postman `update-sub-merchant` request prepared.

**Prerequisites:**
- Section 11 cleanup completed — Vantiv MAX = `BASELINE_MAX`, both local DB columns = `BASELINE_MAX`.
- A Postman request that calls `POST /provisioning/create-sub-merchant` in **update mode** (with `WellfitSubMerchantId = SUB_MERCHANT_ID` in the body). The body must include the full LegalEntity + SubMerchant + Accounts payload — your team's existing SubMerchant-update tooling should provide a template. Only `SubMerchant.MaxTransactionAmount` varies between the two ACs.
- For AC11 specifically: `[Payments].[AchLimitConfig].PerTransactionLimit > 0`. Check Section 3.3 pre-flight query result. If null or 0, skip AC11.

### 12.1 — Capture current ACH limit

Run in SSMS — captures `CURRENT_ACH` for use in both ACs.

```sql
SELECT PerTransactionLimit AS CurrentAch
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>';
```

Write `CURRENT_ACH` on the whiteboard. (If 0 rows or null, AC11 is N/A — AC10 still runs.)

### 12.2 — AC10: card raise above ACH (Vantiv MAX should = new card)

**What I'm doing:** Set `SubMerchant.MaxTransactionAmount` (the card limit) to a value clearly above `CURRENT_ACH`. The orchestration should compute `MAX(newCard, CURRENT_ACH) = newCard` and push newCard to all processors.

**Setup:** in your `update-sub-merchant` Postman request, set:
- `WellfitSubMerchantId` = `{{SUB_MERCHANT_ID}}`
- `SubMerchant.MaxTransactionAmount` = `BASELINE_MAX * 2` (or any value > `CURRENT_ACH`). Call this `NEW_CARD_HIGH`.
- All other fields: copy from the SubMerchant's current state (retrieve via `provisioning/retrieve-sub-merchant?wellfitSubMerchantId={{SUB_MERCHANT_ID}}&includeProcessorData=false` if needed).

**Send the request. Expected:** HTTP 200 with a `CreateSubMerchantResponse` body.

**Verify Vantiv (Postman):** `04 - AC1 — Verify Vantiv MAX` → **Send**. Expected `CURRENT_MAX` = `NEW_CARD_HIGH`.

**Verify local DB (SQL — both columns should move together):**

```sql
SELECT
    sm.TransactionLimit       AS CardTransactionLimit,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**Pass criteria:** `CardTransactionLimit` = `MerchantMax` = `NEW_CARD_HIGH`. Both columns moved in lockstep (the dual-write invariant) and both equal the new card value (the overlay didn't override because `currentAch < newCard`).

**Mark AC10 ✅.**

### 12.3 — AC11: card drop below ACH (overlay kicks in; Vantiv MAX should stay at CURRENT_ACH)

**Skip if `CURRENT_ACH` from 12.1 is null or 0.**

**What I'm doing:** Set `SubMerchant.MaxTransactionAmount` to a value clearly **below** `CURRENT_ACH`. The orchestration's `OverlayAchLimitIfPresent` should fetch the live ACH limit, compute `MAX(newCardLow, CURRENT_ACH) = CURRENT_ACH`, and push `CURRENT_ACH` to all processors. This is the inverse of AC1 — proves the overlay works on the HTTP path.

**Setup:** in the same `update-sub-merchant` Postman request, set:
- `SubMerchant.MaxTransactionAmount` = `CURRENT_ACH - 100` (or any value `< CURRENT_ACH` but `> 0`). Call this `NEW_CARD_LOW`.

**Send the request. Expected:** HTTP 200.

**Verify Vantiv:** `04 - AC1 — Verify Vantiv MAX` → **Send**. Expected `CURRENT_MAX` = `CURRENT_ACH` — **not** `NEW_CARD_LOW`. The overlay forced MAX up to the ACH ceiling.

**Verify local DB (same query as 12.2):**

**Pass criteria:** `CardTransactionLimit` = `MerchantMax` = `CURRENT_ACH`. The overlay correctly took the higher value; both DB columns moved together; the operator's `NEW_CARD_LOW` value is **not** what landed at any sink. **This is the HTTP-path equivalent of the PAY-3755 dual-write proof and the PAY-3627 overlay invariant.**

**If `MerchantMax` = `NEW_CARD_LOW`:** the HTTP path bypassed `OverlayAchLimitIfPresent`. Regression of PAY-3627's overlay — flag immediately.

**Mark AC11 ✅.**

### 12.4 — Cleanup (optional but recommended)

If you ran AC10 / AC11, the SubMerchant is now in a non-baseline state (card limit moved). To return to the Section-11 baseline state, send a final `update-sub-merchant` request with `SubMerchant.MaxTransactionAmount` = `BASELINE_MAX`. Re-run the SQL from 12.2 — both columns should read `MAX(BASELINE_MAX, CURRENT_ACH)`.

---

## Section 13 — Sign-off (5 min) — fill in live with the group

| AC | Description | Pass / Fail | Notes |
|----|---|---|---|
| AC1 | Happy path — Vantiv MAX raised to `NEW_ACH_LIMIT` within 2 min |  |  |
| AC2 | Short-circuit on `maxTransactionAmountChanged=false` — MAX unchanged |  |  |
| AC3 | Short-circuit when ACH = card limit — MAX unchanged |  |  |
| AC4 | Idempotency — duplicate event, no double-update, no exception |  |  |
| AC9 | **PAY-3610 regression** — ACH payment > `BASELINE_MAX` returns 2xx |  |  |
| AC10 | HTTP card raise above ACH — `NEW_CARD_HIGH` flows to Vantiv + both DB columns |  | optional |
| AC11 | HTTP card drop below ACH — overlay forces MAX to `CURRENT_ACH` (not the lower card value) |  | optional |

**PAY-3610 long-term status:** ☐ Confirmed fixed   ☐ Regressed   ☐ Inconclusive (note why)

**Tester:** _______________   **Date:** _______________   **SubMerchantId used:** _______________

---

## Section 14 — Wrap (5 min)

Ask the room:
1. Anything surprising about the flow?
2. What in the guide/runbook needs clarifying for next time (when QA runs this without you)?
3. Any failure mode hit today that isn't in the troubleshooting table below?

Capture action items:
- Guide/runbook gaps
- Bad-data SubMerchants to add to the "do not use" list
- Whether to invest in automating this E2E

---

## Appendix A — Failure mode quick reference

| What you see | Don't say | Say instead | Fix |
|---|---|---|---|
| Vantiv MAX doesn't update in 2 min | "PAY-3627 broken" | "Let's check App Insights" | Run the handler-traces KQL in Section 5.4 |
| AC9 returns 422 "per-transaction-limit" | "PAY-3610 not fixed" | "That's SubMerchant API, not Worldpay" | Raise SubMerchant ACH limit via API |
| EG publish returns 403 | "Service down" | "EG Data Sender role missing" | Ping Jason for role grant |
| EG publish returns 401 | — | "EG_TOKEN expired" | Re-run the `az account get-access-token` command and update env var |
| `retrieve-sub-merchant` returns 500 | "MP API broken" | "MP can't reach SubMerchant API" | Check Platform DB identity script (PR #142) is deployed |
| `retrieve-sub-merchant` returns 400 "No data found" | "Bug" | "SubMerchant not fully provisioned" | Make a fresh SubMerchant — Section 3 |
| App Insights: handler ran but skipped Vantiv | "Bug" | "Stale-publisher guard fired" | `previousMaxTransactionAmount` in event didn't match actual Vantiv — re-baseline (Section 4) |
| App Insights: Vantiv 400 "Bank Account Number" | "Bug" | "SubMerchant has bad bank data" | Fresh SubMerchant — do NOT reuse `ff080000-3a37-000d-b0aa-08de31f4c24c` (Clermont Smiles) |
| MP_TOKEN / PV2_TOKEN 401 mid-session | — | "Token expired (~1hr lifetime)" | Re-Send the token request in `00 - Setup` |

---

## Appendix B — All SQL queries used in this session

**Connection details for all queries:**
- Server: `sqldb-plat-dev-001.database.windows.net`
- Database: `Platform`
- Auth: Azure AD (your Wellfit dev account)
- Schemas used: `Payments`, `MerchantProvisioning`

**MP-cached Worldpay MAX lives on:** `[MerchantProvisioning].[SubMerchantDetails].MaxTransactionAmount`. Reach it from the Payments-side SubMerchantId by joining through `[MerchantProvisioning].[ProvisionedSubMerchants]`.

**B1. Pre-flight: SubMerchant + provisioning chain (Section 3.3)**

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    sm.SubMerchantName,
    sm.TransactionLimit       AS CardTransactionLimit,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
LEFT JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
LEFT JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**B2. ACH limit config — current state (Sections 3.3, 10.2)**

```sql
SELECT
    SubMerchantId,
    PerTransactionLimit,
    DailyLimit,
    EffectiveDate,
    LastModifiedUtc,
    LastModifiedBy
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>';
```

**B3. MP cache check — after any event publish (Sections 7.2, 10.1, 11.3)**

```sql
SELECT
    sm.Id                     AS SubMerchantId,
    sm.TransactionLimit       AS CardTransactionLimit,
    psmd.MaxTransactionAmount AS MerchantMax
FROM [Payments].[SubMerchants] AS sm
JOIN [MerchantProvisioning].[ProvisionedSubMerchants] AS psm
    ON sm.ProvisionedSubMerchantId = psm.Id
JOIN [MerchantProvisioning].[SubMerchantDetails] AS psmd
    ON psm.SubMerchantDetailId = psmd.Id
WHERE sm.Id = '<SUB_MERCHANT_ID>';
```

**B4. ACH limit audit trail (Section 10.3)**

```sql
SELECT TOP 20
    SubMerchantId,
    FieldChanged,
    PreviousValue,
    NewValue,
    ChangedBy,
    ChangedUtc
FROM [Payments].[AchLimitConfigAuditLog]
WHERE SubMerchantId = '<SUB_MERCHANT_ID>'
ORDER BY ChangedUtc DESC;
```

---

## Appendix C — All App Insights KQL queries used in this session

**App Insights resource:** `merchant-provisioning-ms` in the dev Azure subscription. Use the **Logs** blade.

**C1. Did the handler receive the event? (Section 5.4)**

```kusto
traces
| where timestamp > ago(10m)
| where message has_any ("AchLimitConfig", "VantivWorldpay", "MaxTransactionAmount", "AchLimitConfigChanged")
| order by timestamp desc
| take 50
```

**C2. Did the handler throw? (Section 5.4, 9.3)**

```kusto
exceptions
| where timestamp > ago(10m)
| where outerMessage has_any ("AchLimit", "Vantiv", "maxTransactionAmount", "Provisioning")
| project timestamp, outerMessage, innermostMessage, operation_Id
| order by timestamp desc
```

**C3. Full operation trace (Section 5.4)**

```kusto
union traces, exceptions, requests, dependencies
| where operation_Id == "<paste operation_Id from C1 or C2>"
| order by timestamp asc
```

**C4. Service health check**

```kusto
requests
| where timestamp > ago(15m)
| summarize count() by bin(timestamp, 1m)
| order by timestamp desc
```

Empty result → service likely down. Check the container app in Azure portal.

---

## Appendix D — Service Bus check (Azure portal, not query)

Portal path:
`Service Bus namespace dev-sbns-payments-westus3 → Topics → accounts → Subscriptions → merchantprovisioning-api`

- **Active Message Count > 0 and not draining:** merchant-provisioning-ms is down or not consuming messages
- **Dead-letter Count > 0:** handler is throwing on every retry — check Appendix C2 (exceptions query)

---

## Appendix E — Postman quick reference

| Task | How |
|---|---|
| Open Postman console (live logs) | View → Show Postman Console (Alt+Ctrl+C) |
| See request body / headers / scripts | Open the request — Body, Headers, Pre-request Script, Tests tabs |
| Inspect current env var values | Click the eye icon next to the env dropdown (top-right) |
| Refresh a token mid-session | Open `00 - Setup` → re-Send the token request |
| Force-refresh `EG_TOKEN` | Terminal: `az account get-access-token --resource "https://eventgrid.azure.net" --query accessToken -o tsv` → paste into env |
| Reset state if anything gets weird | Run `99 - Cleanup`, then re-run `02 - Baseline` |
