# PAY-3605 Story 1.1 — E2E Runbook: Unmatched Settlement Transaction Alert (DEV + STAGE/QA)

| Field | Value |
|---|---|
| Feature | Unmatched Settlement Transaction Alerts |
| Story | 1.1 — Implement Unmatched Settlement Transaction Alert System |
| Jira | PAY-3605 |
| Service | Treasury API (`treasury-ms`) |
| Runbook Status | Ready to execute (env hosts/role name to confirm — see Environment) |
| Test Type | **Live DB seed + funding-batch trigger** (`POST /create-funding-batch`) → email delivery + App Insights `customEvents` verification. **NOT Playwright** — backend-only feature, no UI. |
| Environments | Azure **DEV** and **STAGE/QA** |
| Author | Testing Automation Agent (Tony) |
| Date Authored | 2026-06-27 |
| Code under test | `treasury-ms` branch `PAY-3605-unmatched-settlement-alerts` (merged) — commits `a1d148d51` + `05ac25659`; code review `04_Implementation/code-review-2026-06-25.md` |
| Companion docs | `00_MAIN/architecture.md` (D1–D11, §1–§7), `00_MAIN/epics.md` Story 1.1, `01_Analysis/d2-provenance-how-we-got-here.md`, `../transaction-limit-compliance-alerts/05_Testing/PAY-3510-Story-2.2-E2E-V2-Publisher-Runbook.md` (sibling backend-E2E pattern) |

---

> ## ⚠️ Read before executing
>
> - **There is no UI and no public API for this feature.** The alert fires *internally* during a funding-batch run. You drive E2E by (1) seeding the `Payments.UnmatchedTransactions` table, (2) triggering a funding-batch run, (3) observing the email + telemetry. The browser/Playwright discovery checklist does **not** apply (Phase 1 manual-browser test = N/A) — this is the same backend-E2E shape as PAY-3508/3509/3510.
> - **The alert reads the WHOLE table, no filter (D2).** Every row currently in `Payments.UnmatchedTransactions` is included — *not just the ones you seed*. A second ADF settlement writer also populates this table, so in a shared non-prod DB it may already hold rows. **SELECT the table first**; the email will enumerate everything open. Scope your seed with a recognizable `TransactionId` prefix so you can identify and clean up your own rows.
> - **Re-alert-until-cleared is intended, not a bug (D2).** Rows are cleared only by ops manually deleting them. If you trigger two runs without deleting, you get **two emails** with the same rows. That is the design — Scenario C proves it on purpose.
> - **`UnmatchedAlertSent` ≠ delivered.** The notifier calls `Wellfit.SendGrid`'s **void** `Send(...)`; the telemetry event records an *accepted attempt*, not delivery. The body is `<pre>` **HTML** — HTML emails can be quarantined. For delivery proof use the **SendGrid Email Activity Feed** + **M365 Quarantine**, not the telemetry event alone. See [[project_compliance_emailservice_false_success]].
> - **In QA the recipient is a real person** (`notifications:settlement:recipients = mark.werner@wellfit.com`). Running Scenario A/C sends Mark a real email each time. Confirm/redirect the recipient before running (see Pre-Conditions).
> - **`batch_id` in the email/telemetry is the funding-*lock* id, not a `FundingBatch` id.** On non-banking days no `FundingBatch` row is generated and the lock row is removed in `finally`; correlating `batch_id` against `FundingBatch` finds nothing. By design (code-review defer item).

---

## Discovery Summary

| Phase | Status | Notes |
|---|---|---|
| Phase 1 — Manual (browser) | **N/A** | Backend-only feature, no UI surface → no Playwright E2E. Replaced by DB-seed + funding-batch trigger. |
| Phase 2 — Frontend review | **N/A** | No frontend. |
| Phase 3 — Backend review | ✅ Complete (2026-06-27, against live `treasury-ms`) | Trigger, hook, orchestrator, notifier, content, config all read from source — see Code Map below. |
| Phase 4 — Architecture mapping | ✅ Complete | `POST /create-funding-batch` → `IFundingBatchCoordinator` (background) → `WorldpayFundingBatchProcessor.CreateFundingBatchAsync` → `UnmatchedAlertOrchestrator.SendAsync` → `UnmatchedAlertNotifier` → `Wellfit.SendGrid` → recipient; + one of three App Insights `customEvents`. |
| Phase 5 — DB setup | ✅ Complete | `Payments.UnmatchedTransactions` schema confirmed (Appendix A) — idempotent seed + cleanup scripts provided. |

### Code Map (verified against `C:\Source\wellfit-payments\src\microservice\treasury-ms`)

| Element | Location | Behavior to verify E2E |
|---|---|---|
| Trigger endpoint | `Application/Endpoints/Funding/CreateFundingBatch/CreateFundingBatch.cs` | `POST create-funding-batch`, `[Authorize]`, `Policy="fundingPolicy"`; enqueues + returns **202** (or 503 if queue full). Async — work runs on the coordinator. |
| Hook point | `Infrastructure/Funding/Worldpay/WorldpayFundingBatchProcessor.cs` (`CreateFundingBatchAsync`) | After the two settlement data loaders, before the funding-rejects check: `await _unmatchedAlertOrchestrator.SendAsync(fundingLock.Id, cancellationToken);` |
| Orchestrator | `Application/Notifications/UnmatchedAlertOrchestrator.cs` | `if(!Enabled) return;` → reads **whole** `Find<UnmatchedTransaction>()` → empty ⇒ `UnmatchedAlertSuppressed`; non-empty ⇒ `Notify` + `UnmatchedAlertSent`; throw ⇒ swallow + `UnmatchedAlertSendFailed`. |
| Notifier | `Infrastructure/Notifications/UnmatchedAlertNotifier.cs` | `ISendEmail.Send(subject, body, NoReplyEmail, Recipients)`; returns SHA-256 hash of normalized recipients. |
| Content | `Application/Notifications/UnmatchedAlertContent.cs` | `BuildSubject()` / `BuildBody()` — `<pre>` HTML, flat table (widths 34/27/12/12), `[run-metadata]` `schema_version: 2`. |
| Config + kill-switch + fail-fast | `Infrastructure/Features/TreasuryInfrastructureFeature.cs`; `Application/Notifications/UnmatchedAlertOptions.cs` | `notifications:settlement:recipients`, `notifications:noReplyEmail`, `flags:unmatchedSettlementAlert:enabled`; `.Validate(...).ValidateOnStart()`. |

---

## Environment & Infrastructure

> **This runbook targets DEV first** (Brett runs DEV → hands the verified runbook to QA for STAGE/QA). DEV values below are confirmed from `wellfit-environment-app-settings/DevOps/configuration/dev/environment.treasuryapi.json` (2026-06-27). **Do NOT blind-substitute `dev`→`stage`** — STAGE values differ; confirm before any STAGE run.

| Resource | DEV (confirmed) | STAGE/QA | Source / how to confirm |
|---|---|---|---|
| Treasury host (`create-funding-batch`) | ✅ **`https://dev-app-treasury.azurewebsites.net`** — App Service `dev-app-treasury`, RG `dev-rg-plat-api-wus3`, reachable directly (confirmed 2026-06-29; unauth POST → 401 = route live + `fundingPolicy` enforced) | **TO CONFIRM** | `az webapp list --subscription 22d04286-db4f-411f-bfa5-da1aea40c19e -o table` (filter `*treasury*`) |
| Auth authority | `https://dev-platform.wellfit.com/identity` | STAGE Identity Server | `identity:baseUrl` / `wellfit:authentication:authority` |
| Auth scope for `fundingPolicy` | **`WellfitPaymentsAPI.DynamicFunding`** (claim `scope`) | same | `wellfit:policies` (policy `fundingPolicy`) in treasury config |
| Platform DB (`Payments.UnmatchedTransactions`) | DEV Platform SQL (same DB holding `Payments.*`) | STAGE Platform SQL | Treasury EF connection / Key Vault — get from DBA if not to hand |
| App Insights | ✅ **`dev-appi-westus3`** — appId **`79a7536e-dce8-4e75-bea9-7d602e8e9851`** (InstrumentationKey `d8f5a75e…`, westus3), confirmed 2026-06-29 from `dev-app-treasury` app setting `APPLICATIONINSIGHTS_CONNECTION_STRING`. ⚠️ **NOT** `dev-platform-treasury` (that component, in RG `TestGroup`, receives nothing — it's a dead end). | STAGE Treasury AI | `az webapp config appsettings list --name dev-app-treasury -g dev-rg-plat-api-wus3` → read the `ApplicationId` from `APPLICATIONINSIGHTS_CONNECTION_STRING`. Query within this resource → **no `cloud_RoleName` filter needed**. |
| Email recipient (`notifications:settlement:recipients`) | **`Radhika.Kandoori@wellfit.com`** ⚠️ real person | `mark.werner@wellfit.com` (repo default) | DEV app-config key |
| Sender (`notifications:noReplyEmail`) | **`no-reply@wellfit-qa.com`** | `no-reply@wellfit-qa.com` | DEV app-config key (note: `wellfit:sendGrid:from` is `no-reply@wellfit-dev.com`, but the alert uses `NoReplyEmail`) |
| Kill-switch (`flags:unmatchedSettlementAlert:enabled`) | **not set in DEV app-config → defaults `true`** (enabled) | default `true` | code default `?? true` + repo `appsettings.json` |
| SendGrid account | shared Wellfit SendGrid (key from `kv-ops-common-westus3` `SendGrid-Api-Key`) | same | `wellfit:sendGrid:accountKey` — Activity Feed is the shared account |

> ⚠️ **DEV recipient is `Radhika.Kandoori@wellfit.com` — a real person.** Redirect it to yourself before running A/C (see Pre-Conditions), or you'll send Radhika a real alert on every run.

---

## Pre-Conditions (DEV)

1. **Deployment check.** Confirm the PAY-3605 build is deployed to DEV (merged orchestrator + *removal* of the legacy `"Unmatched Settlement Records Detected"` send). Quick proof: a seeded run produces the **new** subject `[Treasury Settlement] Unmatched transactions …` with a `[run-metadata]` `schema_version: 2` block. Seeing the old `"Unmatched Settlement Records Detected"` subject = old path still live (AC #10 fail / not deployed).
2. **Confirm the DEV Treasury host:**
   ```powershell
   az webapp list --subscription 22d04286-db4f-411f-bfa5-da1aea40c19e --query "[?contains(name,'treasury')].{name:name, host:defaultHostName}" -o table
   ```
   Use the resulting `defaultHostName` as `$treasuryHost` (or reach it via the `dev-platform.wellfit.com` gateway if the App Service isn't directly reachable). The endpoint route is `create-funding-batch`.
3. **Kill-switch ON.** Default `true` in DEV (key not set → code default). Required for A/B/C. (Scenario D flips it OFF.)
4. **Recipient redirect (do this first).** DEV resolves `notifications:settlement:recipients` to **`Radhika.Kandoori@wellfit.com`**. Before A/C, set it to **your own inbox** (semicolon-delimited for multiple, e.g. `brett.roy@wellfit.com`) so you don't email Radhika each run. Change it in **DEV App Configuration** (`notifications:settlement:recipients`) and **restart the Treasury App Service** so `IOptions` re-binds. Revert after the run. (If you can't change app-config, coordinate with Radhika first.)
5. **`fundingPolicy` token.** `create-funding-batch` is `[Authorize]`, `Policy="fundingPolicy"` → the token's principal must carry claim `scope = WellfitPaymentsAPI.DynamicFunding`. Mint from `https://dev-platform.wellfit.com/identity/connect/token` with a client that has that scope (the `WellfitUnifiedPaymentsAPI` client used in the PAY-3510 runbook is the usual candidate — confirm it carries `DynamicFunding`).
6. **DB access** to the DEV Platform SQL to run the seed/cleanup (Appendix A) and `SELECT` the table before/after.
7. **Baseline the table.** `SELECT * FROM [Payments].[UnmatchedTransactions]` first. Any pre-existing rows (e.g. from the ADF settlement writer) WILL be included in the alert (whole-table read). If DEV has unrelated rows you don't want emailed, note them — the alert is all-or-nothing per run.

---

## Test Scenarios

> Trigger (all scenarios) — fire a funding-batch run and wait for the background coordinator to process it:
> ```powershell
> # 1) Token carrying scope WellfitPaymentsAPI.DynamicFunding (satisfies fundingPolicy)
> $auth = Invoke-RestMethod -Uri "https://dev-platform.wellfit.com/identity/connect/token" `
>   -Method POST -ContentType "application/x-www-form-urlencoded" `
>   -Body @{ grant_type="client_credentials"; client_id="<client-with-DynamicFunding>"; client_secret="<secret>" }
> $tk = $auth.access_token
>
> # 2) Trigger (use the host from Pre-Condition 2)
> $resp = Invoke-RestMethod -Uri "$treasuryHost/create-funding-batch" -Method POST `
>   -Headers @{ Authorization = "Bearer $tk" }
> $resp   # → 202 Accepted { correlationId, stage: "Create" }   (503 = coordinator queue full; retry)
> ```
> The endpoint returns **202 immediately**; the orchestrator runs a few seconds later on the coordinator. Watch App Insights for the processor run + the alert event. The `batch_id` in the email is the run's funding-lock id, surfaced in telemetry — not the `correlationId` from this 202 response.

### Scenario A — Mismatches present → one aggregate email + `UnmatchedAlertSent` → **AC 1, 3, 4, 5, 6, 7**

1. **Seed** 4 rows of mixed `TransactionType`, including one with an HTML-special char to prove encoding (AC #5):
   ```sql
   -- See Appendix A for the full idempotent script (prefix 'P3605E2E-' for cleanup scoping).
   ```
2. **SELECT** the table; note the **total** row count = expected `N` (your 4 + any pre-existing).
3. **Trigger** a funding-batch run (above).
4. **Wait** ~15–60 s for the coordinator.

**Pass criteria:**
- **Exactly one** email arrives at the configured recipient (AC #1, #7).
- **Subject** = `[Treasury Settlement] Unmatched transactions YYYY-MM-DD HH:MM UTC (N total)` — minute precision, `N` = total table count (AC #3).
- **Body** is one `<pre>` block: header (`Generated`, `Funding batch`, `Total unmatched`) + one flat table with columns `TransactionType | TransactionId | Amount | ReferenceDate` listing every row; Amount right-aligned `$#,##0.00` (AC #4).
- The HTML-special seed row renders its `&`/`<`/`>` as entities with alignment intact (AC #5).
- **Marker block** at the bottom between `---` fences: `[run-metadata]`, `schema_version: 2`, `batch_id`, `generated_at_utc` (ISO-8601 `Z`), `total_unmatched: N`, `alert_source: treasury-api/unmatched-settlement` — all keys present, fixed order (AC #6).
- **Telemetry** (App Insights `customEvents`): one `UnmatchedAlertSent` with `batch_id`, `total_count = N`, `recipient_hash` (64-hex, **not** a raw address).
- **Delivery proof** (don't stop at telemetry): SendGrid Activity Feed shows the message *delivered*; check M365 quarantine if it doesn't land (HTML body risk).

### Scenario B — Clean run (empty table) → no email + `UnmatchedAlertSuppressed` → **AC 2**

1. **Ensure the table is empty:** `DELETE FROM [Payments].[UnmatchedTransactions]` (⚠️ only in a non-prod env you control, and only if no other team's rows must survive — otherwise coordinate). Re-`SELECT` to confirm 0 rows.
2. **Trigger** a run. Wait.

**Pass criteria:**
- **No email** sent (AC #2).
- Telemetry: one `UnmatchedAlertSuppressed` with `batch_id`; **no** `UnmatchedAlertSent`.

### Scenario C — Re-alert until cleared (the D2 design point) → **AC 2a**

1. Re-seed the same 4 rows (Appendix A). Do **not** delete them between runs.
2. **Trigger** a run → expect email #1 (`UnmatchedAlertSent`).
3. **Trigger a second run** without deleting → expect **email #2** with the same rows (`UnmatchedAlertSent` again).

**Pass criteria:** both runs alert on the same rows — repeated alerting is **expected/intended** (no `ReportedAt`, no dedup). Then delete the rows (Appendix A cleanup) and trigger once more → `UnmatchedAlertSuppressed`, proving the manual delete is the only "dedup."

### Scenario D — Kill-switch OFF → full no-op → **(kill-switch carve-out, AC 11 sibling)**

1. Set `flags:unmatchedSettlementAlert:enabled = false`; restart/redeploy so the host re-binds options. Leave seeded rows in place.
2. **Trigger** a run. Wait.

**Pass criteria:** **no email**, and **no** alert telemetry at all — not even `UnmatchedAlertSuppressed` (the orchestrator returns before the query when `Enabled = false`). Re-enable afterward.

### Not E2E-exercisable here (covered by unit tests — do not burn a live run)

- **`UnmatchedAlertSendFailed`** — forcing a SendGrid failure at runtime isn't safely reproducible: blank/invalid recipient or sender is caught by **startup fail-fast** (`ValidateOnStart`), so the host won't even boot to a run. The swallow-on-failure + `UnmatchedAlertSendFailed` path (AC #8, #9) is covered by `UnmatchedAlertOrchestratorTests` and the patch tests. Treat it as unit-owned; don't try to manufacture it E2E. (Same "can't exercise it live" shape as the PAY-3510 `statusMessage` trap.)
- **Startup fail-fast** (AC #11) — host-startup behavior, covered by `UnmatchedAlertOptionsValidationTests`. Optionally smoke-verify by deploying with a blank `recipients` while `enabled=true` and confirming the host fails to start, but that's a deploy test, not a funding-batch E2E.

---

## Verification

### App Insights (KQL — run inside the **`dev-appi-westus3`** resource, appId `79a7536e-dce8-4e75-bea9-7d602e8e9851`; no role filter needed. NOT `dev-platform-treasury`.)

```kusto
customEvents
| where timestamp > ago(30m)
| where name in ("UnmatchedAlertSent","UnmatchedAlertSuppressed","UnmatchedAlertSendFailed")
| project timestamp, name, customDimensions
| order by timestamp desc
| take 20
```
(If querying across resources instead, add `| where cloud_RoleName == "Wellfit Treasury API"` — confirm the exact role name on first run.)
- Scenario A/C → `UnmatchedAlertSent` (`batch_id`, `total_count`, `recipient_hash`).
- Scenario B → `UnmatchedAlertSuppressed` (`batch_id`).
- Scenario D → none of the three.

Confirm the funding run actually executed (not queue-rejected) by also checking the processor/coordinator traces in the same window.

### Email (delivery, not just acceptance)
- Recipient inbox (or Jira intake) received the message; subject/body/marker as in Scenario A.
- **SendGrid Email Activity Feed** — search the recipient / time window; status = *Delivered* (not just *Processed*).
- **M365 Quarantine** — if not delivered, check here (HTML `<pre>` body can be quarantined). See [[project_compliance_emailservice_false_success]].

---

## AC Validation Checklist (Story 1.1 — `epics.md`)

| AC | Description | Scenario | Pass signal |
|---|---|---|---|
| 1 | Non-empty table → exactly one email with ALL rows | A | one email; row count = table count |
| 2 | Empty table → no email | B | no email; `UnmatchedAlertSuppressed` |
| 2a | Same rows on a later run → alerted again (intended) | C | two emails, same rows |
| 3 | Subject format + minute precision + total N | A | subject matches template |
| 4 | One flat table, `TransactionType` column, no per-type sections | A | body table as specified |
| 5 | Dynamic values HTML-encoded | A (special-char seed) | `&`/`<`/`>` → entities, alignment intact |
| 6 | `[run-metadata]` block, `schema_version: 2`, all keys/fixed order | A | marker block exact |
| 7 | Recipient from config, no hardcode | A | email goes to configured recipient |
| 8 | Send failure → run still completes | **Unit** (`UnmatchedAlertOrchestratorTests`) | not E2E-exercisable (fail-fast) |
| 9 | Send failure → App Insights event | **Unit** | `UnmatchedAlertSendFailed` covered by tests |
| 10 | Legacy `"Unmatched Settlement Records Detected"` email gone | A (deployment check) | only the new subject appears; old never sent |
| 11 | Enabled → fail-fast on blank config; disabled → no gate | D + **Unit** (`UnmatchedAlertOptionsValidationTests`) | D: kill-switch no-op; fail-fast unit-covered |

---

## Caveats

| Hazard | Detail | Mitigation |
|---|---|---|
| **Whole-table read** | The alert lists every open row, including ones a second ADF writer inserted — not just your seed. | SELECT first; scope seed with `TransactionId` prefix `P3605E2E-`; clean up after. |
| **Re-alert every run** | Seeded rows re-email on every subsequent funding run until deleted (by design, D2). | Delete your rows (Appendix A) right after the run so unrelated later runs don't re-email them. |
| **`AlertSent` ≠ delivered** | Notifier wraps `Wellfit.SendGrid` **void** `Send`; HTML `<pre>` body can be quarantined. | Verify via SendGrid Activity Feed + M365 quarantine, not telemetry alone. [[project_compliance_emailservice_false_success]] |
| **Real recipient** | DEV = `Radhika.Kandoori@wellfit.com`; QA = `mark.werner@wellfit.com` — both real people. | Redirect recipient (DEV App Configuration + App Service restart) before A/C; revert after. |
| **`batch_id` = lock id** | Not a `FundingBatch` id; no match if correlating against `FundingBatch` rows; none generated on non-banking days. | Expected; correlate by time + `correlationId`/lock instead. |
| **Async trigger** | 202 returns before processing; queue may be full (503). | Wait + watch App Insights; retry on 503. |
| **DEV vs STAGE parity** | Identical code ⇒ identical behavior; only config (recipient/sender/flag) differs. A STAGE run is a pre-QA parity smoke. | Confirm env config; don't expect behavior differences. [[feedback_env_config_vs_behavior]] |

---

## Appendix A — Seed / Cleanup SQL (`Payments.UnmatchedTransactions`)

Schema (from `wellfit-platform-db/Platform/Platform/Payments/Tables/UnmatchedTransactions.sql`):
`Id` uniqueidentifier PK · `TimeStamp` datetimeoffset(7) · `TransactionType` nvarchar(255) · `TransactionId` nvarchar(40) · `Amount` decimal(18,2) · `ReferenceDate` date — all NOT NULL.

> `TimeStamp` is **NOT NULL but never read** by the alert (D2 — no time filter). Seed it to anything (e.g. now). Do not assume it filters.

```sql
-- ===== SEED (idempotent) — Scenario A/C =====
USE [Platform];  -- confirm DB name per env

-- Cleanup first (idempotent — scoped to this runbook's prefix)
DELETE FROM [Payments].[UnmatchedTransactions] WHERE [TransactionId] LIKE 'P3605E2E-%';

INSERT INTO [Payments].[UnmatchedTransactions]
  ([Id], [TimeStamp], [TransactionType], [TransactionId], [Amount], [ReferenceDate])
VALUES
  (NEWID(), SYSDATETIMEOFFSET(), N'Sales Settlement', 'P3605E2E-0000000001', 123.45, '2026-06-26'),
  (NEWID(), SYSDATETIMEOFFSET(), N'ChargeBack',       'P3605E2E-0000000002',  50.00, '2026-06-25'),
  (NEWID(), SYSDATETIMEOFFSET(), N'Refund',           'P3605E2E-0000000003',   9.99, '2026-06-24'),
  -- HTML-special chars to prove AC #5 encoding (the value, not the id, carries them):
  (NEWID(), SYSDATETIMEOFFSET(), N'Sales & <Adjust>', 'P3605E2E-0000000004', 1000000.00, '2026-06-23');
--                                                                    ^ note: $1,000,000.00 (13 chars) truncates to "$1,000,000…" by design (width 12) — accepted in code review.

SELECT * FROM [Payments].[UnmatchedTransactions] ORDER BY [ReferenceDate] DESC;  -- note total count = N
```

```sql
-- ===== CLEANUP (idempotent) — run after each scenario set =====
DELETE FROM [Payments].[UnmatchedTransactions] WHERE [TransactionId] LIKE 'P3605E2E-%';
SELECT COUNT(*) AS RemainingRunbookRows FROM [Payments].[UnmatchedTransactions] WHERE [TransactionId] LIKE 'P3605E2E-%';  -- expect 0
```

```sql
-- ===== Scenario B (empty-table) =====
-- Only if no other team's rows must survive in this env — otherwise coordinate.
-- DELETE FROM [Payments].[UnmatchedTransactions];
SELECT COUNT(*) AS TotalRows FROM [Payments].[UnmatchedTransactions];  -- expect 0 before triggering
```

---

## Execution Log

| Date | Env | Scenario | Result | Evidence | By |
|---|---|---|---|---|---|
| 2026-06-29 | DEV | A / B / C / D | ✅ **PASS (all four)** | See "DEV run — 2026-06-29" notes below | Brett (Tony-assisted) |
| _pending_ | STAGE/QA | A / B / C / D (redirect recipient off mark.werner first) | — | — | QA |

_(Append a `PAY-3605-QA-Run-<env>-<date>.md` after execution, matching the PAY-3510 run-report format.)_

### DEV run — 2026-06-29 (Brett, Tony-assisted)

**Result: ✅ PASS — all four scenarios.** Verified in App Insights `dev-appi-westus3` (appId `79a7536e-dce8-4e75-bea9-7d602e8e9851`) + inbox.

| Scenario | Evidence |
|---|---|
| A — mismatches → one email | `UnmatchedAlertSent` 16:22:06, `total_count=4`, batch `…08ded5fa8f71`; subject `[Treasury Settlement] Unmatched transactions 2026-06-29 16:22 UTC (4 total)`; body table + marker block (`schema_version: 2`, fixed key order) exact; HTML-encoding (`Sales & <Adjust>`) + amount truncation (`$1,000,000.…`) correct; `recipient_hash` matched SHA-256 of `brett.roy@wellfit.com` → redirect verified (AC 7); no legacy "Unmatched Settlement Records Detected" email (AC 10). |
| B — empty table | `UnmatchedAlertSuppressed` 16:13:46, no email (AC 2). |
| C — re-alert until cleared | 2nd `UnmatchedAlertSent` 16:32:03 batch `…08ded5fbf3b2` on the same rows (two emails); after delete → `UnmatchedAlertSuppressed` 16:33:43 (AC 2a). |
| D — kill-switch OFF | Rows present, yet **zero** `UnmatchedAlert*` telemetry and no alert email — orchestrator short-circuits before the query. |

**Observation (out of scope — for the later cleanup story):** a separate **"Funding Rejects Detected"** email also fires from `WorldpayFundingBatchProcessor.CreateFundingBatchAsync` (~line 99) when `FundingInstructionReject` (`RetryDate == null`) or `ReturnedPayment` (`FundingInstruction == null`) rows exist. It shares the `notifications:settlement:recipients` key and is **NOT** gated by `flags:unmatchedSettlementAlert:enabled`, so it still sends in Scenario D — do not mistake it for a D failure. By design: D3 left it out of PAY-3605 scope. It's the same uninformative one-liner PAY-3605 replaced for unmatched settlements — a natural candidate for the follow-up cleanup story.

**Companion artifacts added:** `PAY-3605-Unmatched-Settlement-Alert.postman_collection.json` + `PAY-3605-Unmatched-Settlement-Alert-DEV.postman_environment.json` (collection auto-mints the token; one-click trigger per scenario).
