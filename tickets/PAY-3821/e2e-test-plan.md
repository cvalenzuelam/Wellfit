# E2E / QA Test Plan — PAY-3821 Treasury funding-batch send error handling

**Work item:** PAY-3821 · **PR:** wellfit-payments #283 · **Repo:** `wellfit-payments` / `src/microservice/treasury-ms`
**Type:** Env-level, black-box behavioral verification (manual, config-inducible) + Postman HTTP companion
**Source spec:** `solution.md`, `analysis.md`, `qa-verification.md` (this folder)
**Companion:** `postman/collections/PAY-3821-treasury-funding-send.postman_collection.json`
**Author:** Tony (Testing Automation) · **Date:** 2026-06-24

---

## 1. Purpose & Scope

PAY-3821 adds error handling to the per-batch Worldpay SFTP send inside
`WorldpayFunding.SendFundingBatch()` (`Infrastructure/Funding/Worldpay/WorldpayFunding.cs`).
On a transport-level failure (`LitleOnlineException` **or** `SocketException`) it must:
log with batch context, send **one** alert email enumerating all unsent batches, and leave
`RequestSentTimeStamp == null` so the unsent batches retry idempotently on the next run.

> **Merged-behavior note (verified vs `origin/main`, commit `568dbdde4`):** the catch block
> **rethrows** after alerting (it does *not* `break`/swallow — that was the earlier `solution.md`
> shape). The `throw;` both stops the run (one connect timeout, not N) **and** lets
> `FundingBatchCoordinator.DispatchAsync`'s outer catch record the **Send stage as failed**
> (Critical log + failed-stage metric + coordinator alert). The hosting `BackgroundService` stays
> alive via PAY-3587's outer catch. **Net: a failure produces _two_ signals** — (a) the PAY-3821
> alert email, and (b) the coordinator's failed-stage record — and the email body is HTML-encoded
> (`<br/>` line breaks, `WebUtility.HtmlEncode` on dynamic values).

This plan formalizes the env-level black-box verification described in `qa-verification.md` into
discrete, evidence-bearing test cases against a **deployed** Treasury API. It is the manual/QA-driven
counterpart to the PR #283 unit tests — it proves the behavior end-to-end against a real service,
real DB, real SendGrid, and real App Insights.

**In scope:** behavior observable from outside the process — HTTP response, DB row state,
App Insights logs, alert-email delivery, service health, recovery.
**Out of scope (covered elsewhere):** which of the two exception types was caught (not externally
distinguishable — unit-covered); the partial-progress "sent-before-failure exclusion" sub-case
(see §6 note — unit-covered); the Worldpay source-IP allowlist root cause (separate track).

---

## 2. Preconditions & Environment

| # | Precondition | Notes |
|---|---|---|
| P1 | **Build under test is a `main`-based build (PR #283).** | ⚠️ Load-bearing. **Verified 2026-06-24:** PR #283 (commit `568dbdde4`) **is merged to `origin/main`** — the target line for this work item (it is intentionally **not** carried on `release/9.5`). Test against an env deployed from `main` (or a branch containing `568dbdde4`). Confirm the deployed commit first — a pre-#283 build exhibits the **old** behavior (unhandled exception, no alert) and fails every assertion. |
| P2 | **Dev or SBOX only — never PROD.** | Per Wellfit DEV/STAGE convention QA owns STAGE/SBOX. This induces real Worldpay SFTP failures. |
| P3 | Treasury API (role *Wellfit Treasury API*) deployed and reachable. | Base URL for the env overlay. |
| P4 | App Insights for the Treasury API accessible. | Query by `correlationId` (returned from the trigger) and by role. |
| P5 | `notifications:settlement:recipients` resolves to a **team-reachable inbox**. | Semicolon-delimited if multiple. Needed to confirm actual delivery. |
| P6 | A valid JWT bearer token for the `fundingPolicy` scope. | `POST /send-funding-batch` is `[Authorize]`, `Policy = "fundingPolicy"`. Obtain per the env's identity provider; set as the Postman `bearerToken` variable. |
| P7 | It is a **banking day** (in the env's calendar). | `IsBankingDay()` gates the loop; off a banking day nothing runs and the test is inconclusive. |
| P8 | SQL access to the Treasury/Platform DB for staging + assertions. | SSMS / sqlcmd / Azure Data Studio. |

---

## 3. Test Data Staging

**Ready-to-run scripts (this folder, `sql/`):**

| Script | Purpose |
|---|---|
| `sql/01-stage-pending-batches.sql` | Idempotent — clears prior PAY-3821 markers, stages 3 synthetic pending batches |
| `sql/02-inspect-state.sql` | `SELECT` row state + count summary; run before (baseline) and after each trigger |
| `sql/03-cleanup.sql` | Teardown — deletes the synthetic rows |

Schema verified against `wellfit-platform-db .../Payments/Tables/FundingBatches.sql`:
`Id` (uniqueidentifier, PK), `MerchantId` (nvarchar(10), **NOT NULL**), `RequestSentTimeStamp`
(datetimeoffset, NULL), `BatchFileName` (nvarchar(255), NULL), `ResponseReceivedTimeStamp`
(datetimeoffset, NULL), `TransactionId` (nvarchar(25), NULL).

Stage rows in `Payments.FundingBatches` with `BatchFileName IS NOT NULL` and `RequestSentTimeStamp
IS NULL` so they are selected by the send loop's predicate
(`b.RequestSentTimeStamp == null && b.BatchFileName != null`). Stage **≥3** rows to exercise the
multi-batch enumeration case (TC-03). The scripts use marker prefix `PAY3821-E2E-` and synthetic
`MerchantId = 'E2E3821'` (never `*LOCK*`).

> **⚠️ Synthetic rows verify the FAILURE path only.** A config-induced transport failure throws at
> SFTP **connect**, *before* the batch file is read — so a non-existent `BatchFileName` is fine for
> TC-02/TC-03. They do **not** verify the happy-path/recovery **stamp** (TC-01/TC-04): a successful
> upload needs a *real* batch file produced by `/create-funding-batch` against genuine settlement
> data. With synthetic rows, restoring config in TC-04 proves only that the rows remain **eligible
> and are re-attempted** (still `RequestSentTimeStamp NULL`) — not that they stamp. To verify the
> stamp, generate a real batch first or run TC-01/TC-04 in a controlled env with a transmittable file.
> Also note: synthetic rows match the `ProcessFundingBatchResponse` predicate too — clean up promptly
> (script 03) so the response stage doesn't emit "Error Processing Funding Batch" noise.

The funding-send loop does **not** require matching response/instruction data — it only needs
pending `FundingBatches` rows with a file name. Run `sql/01-stage-pending-batches.sql`, capture the
echoed rows as evidence, then `sql/02-inspect-state.sql` for the baseline.

---

## 4. Failure Triggers (pick one per run)

| Option | How | Branch exercised |
|---|---|---|
| **T-a Natural** (while it lasts) | Dev/SBOX currently reproduce the `SocketException` via the Worldpay source-IP allowlist gap. Just trigger `POST /send-funding-batch` as-is. | `SocketException` |
| **T-b Deterministic — socket** | Point `processor:vantiv:batch:sftpUrl` at a non-routable host in the env overlay → guaranteed connect timeout. | `SocketException` |
| **T-c Deterministic — Litle** | Set a wrong `sftpPassword` → `SshAuthenticationException` → SDK wraps → `LitleOnlineException`. | `LitleOnlineException` |

Which exception type was caught is **not** externally distinguishable by design — both paths produce
identical observable behavior. Pick whichever trigger is convenient; the unit tests cover the
type-discrimination.

---

## 5. Test Cases

> **Async note:** `POST /send-funding-batch` returns **202 Accepted** with `{ correlationId, stage:"Send" }`
> *immediately* (or **503** if the coordinator queue is full). The actual SFTP send + PAY-3821 failure
> handling run later on the `IFundingBatchCoordinator` background service. **202 does not mean the send
> succeeded** — it means the work was enqueued. Use the returned `correlationId` to locate the async
> outcome in App Insights. Allow a short settle time (e.g., the connect-timeout duration ~20s+) before
> asserting on logs / DB / email.

### TC-01 — Happy-path baseline & smoke (AC-3 happy path)
**Goal:** With good config and real pending batches, confirm normal send still works and stamps.
| Step | Action | Expected |
|---|---|---|
| 1 | `GET /health` | `200 OK`, body `"Ok"` |
| 2 | Stage ≥1 *real* pending batch (or defer to TC-04) | row present, `RequestSentTimeStamp NULL` |
| 3 | `POST /send-funding-batch` (Bearer) | `202`, body has `correlationId`, `stage:"Send"` |
| 4 | Wait, then query DB | `RequestSentTimeStamp` **set** for the sent batch |
| 5 | App Insights by `correlationId` | no error event for the send path; no failure alert email |

**Pass:** all expected met. *(May be satisfied by the recovery leg of TC-04 instead.)*

### TC-02 — Single-batch transport failure (AC-1)
**Goal:** A genuine SFTP failure is caught, alerted once, logged with context, does not propagate.
| Step | Action | Expected |
|---|---|---|
| 1 | Stage exactly 1 pending synthetic batch (§3) | `RequestSentTimeStamp NULL` |
| 2 | Apply trigger T-a/T-b/T-c (§4) | config applied |
| 3 | `POST /send-funding-batch` (Bearer) | `202` + `correlationId` captured |
| 4 | Wait for settle (~connect-timeout) | — |
| 5 | **Email:** check the configured inbox **and** SendGrid Activity | **Exactly one** alert email; subject `Error - Funding Batch Send Failed`; body names the failed batch `Id (BatchFileName)` + reason |
| 6 | **App Insights** error log (role *Wellfit Treasury API*), filter by `correlationId` | error event carries `BatchId`, `BatchFileName`, SFTP `Host`, and the unsent-batch list |
| 7 | **App Insights** coordinator record | the rethrow surfaces a **Send-stage-failed** signal (Critical log + failed-stage metric / coordinator alert) — the *second* failure signal |
| 8 | **DB:** query the staged row (script 02) | `RequestSentTimeStamp` remains **NULL** |
| 9 | **Health:** `GET /health` + re-`POST` | service healthy, `200`/`202` — `BackgroundService` stayed alive (PAY-3587 outer catch); no host-loop death |

**Pass:** one-and-only-one PAY-3821 alert email; the orchestrator error log carries full context; a
coordinator failed-stage signal is present (rethrow by design); row stays NULL; service alive.

### TC-03 — Multi-batch blast radius & "stop the run" (AC-2)
**Goal:** On transport failure with multiple pending batches, the run stops after the failing batch,
exactly one alert is sent, and **all** unsent batches are enumerated.
| Step | Action | Expected |
|---|---|---|
| 1 | Stage **≥3** pending synthetic batches (§3) | 3 rows, all `RequestSentTimeStamp NULL` |
| 2 | Apply trigger T-b (deterministic socket) | dead host configured |
| 3 | `POST /send-funding-batch` (Bearer) | `202` + `correlationId` |
| 4 | Wait for settle | — |
| 5 | **Email** (inbox + SendGrid Activity) | **Exactly one** email (not one-per-batch); body **enumerates every unsent batch** `Id (BatchFileName)` |
| 6 | **App Insights** by `correlationId` | single error event; `UnsentBatches` list includes all 3; `UnsentCount = 3` |
| 7 | **DB:** all 3 rows | all remain `RequestSentTimeStamp NULL` |
| 8 | **Timing sanity** | run stopped after the first failure — ~**one** connect timeout, **not** 3× (proves stop-the-run via rethrow, not a serial `continue` that retries every batch) |

**Pass:** one email, all unsent enumerated, all rows NULL, single connect-timeout duration, plus a
coordinator failed-stage signal (per TC-02 step 7).

> **Honest limitation (AC-2 "sent-before exclusion"):** a config-induced dead-host timeout throws on
> the **first** batch, so all N are unsent and none were "sent before the failure." Reproducing the
> *partial-progress* case (batch 1 sent+stamped, batch 2 fails, batch 1 excluded from the alert) env-
> level would require a trigger that lets ≥1 batch succeed and then fails mid-run — impractical with a
> single dead host. That sub-assertion is covered by the PR #283 unit test
> `SendFundingBatch_OnTransportFailure_StopsRunAndAlertsWithAllUnsentBatches`. Note this in results
> rather than marking AC-2 fully env-verified.

### TC-04 — Recovery / idempotent retry (AC-5)
**Goal:** After restoring good config, the stranded batches send and stamp normally.
| Step | Action | Expected |
|---|---|---|
| 1 | Starting from TC-02/03 end state (rows still NULL) | stranded rows present |
| 2 | **Restore** config to good values (revert T-b/T-c) | good config |
| 3 | `POST /send-funding-batch` (Bearer) | `202` + `correlationId` |
| 4 | Wait, query DB (script 02) | **Real batch file:** previously-stranded rows now have `RequestSentTimeStamp` **set**. **Synthetic rows:** rows remain `NULL` but are **re-selected and re-attempted** (the send now fails at file-read, not connect — that's expected for a fake file, and that exception is *uncaught*). |
| 5 | App Insights / email | no new *transport-failure* alert for the recovered run |

**Pass (real file):** retry semantics intact — rows re-selected and sent + stamped, no new retry machinery.
**Pass (synthetic):** rows re-selected and re-attempted (idempotent re-eligibility proven); full stamp
verification requires a real batch file — see §3.

### TC-05 — Notification-send resilience (AC-4) — *optional, unit-covered*
**Goal:** A throwing `_email.Send` in the failure path is swallowed + logged; original handling completes.
Env-level reproduction requires breaking SendGrid (e.g., invalid API key) **while** SFTP is also broken —
generally impractical and risky in a shared env. **Recommended:** rely on the PR #283 unit test
`SendFundingBatch_WhenEmailSendThrows_OriginalHandlingStillCompletes`. If attempted env-level, expect:
no email, a `Failed to send funding-batch failure notification` error log, and the run still stops
cleanly (service healthy). Mark as "unit-covered" unless explicitly exercised.

---

## 6. Traceability Matrix

| AC (solution.md) | Description | Coverage |
|---|---|---|
| AC-1 | Caught failure → log w/ BatchId+File+Host + alert email | **TC-02** (env) + unit (`...SocketException...`, `...LitleOnlineException...`). ⚠️ Merged code **rethrows** (not swallow) so the coordinator records a failed Send stage — TC-02 step 7 asserts that second signal. |
| AC-2 | Multi-batch → stop after failing batch, one alert, all unsent enumerated, sent-before excluded | **TC-03** (env: stop + enumerate) + unit (`...StopsRunAndAlertsWithAllUnsentBatches` for the exclusion sub-case) |
| AC-3 | Success stamps as today; rows stay NULL on failure; service healthy | **TC-01** (happy) + **TC-02/03** step 7-8 (NULL + health) |
| AC-4 | Throwing email send swallowed + logged; original handling completes | unit (`...WhenEmailSendThrows...`); **TC-05** optional env |
| AC-5 | Restore + re-trigger → send + stamp (idempotent retry) | **TC-04** (env) |

---

## 7. Evidence Capture Checklist

For each executed test case, capture and attach to the Jira ticket / test run:

- [ ] The exact staging SQL run + a `SELECT` of the staged rows (before)
- [ ] The trigger applied (config key + value, or "natural allowlist gap")
- [ ] Postman: the `202` response body (with `correlationId`) — or screenshot
- [ ] App Insights: the error event filtered by `correlationId` (screenshot/JSON) showing `BatchId`, `BatchFileName`, `Host`, unsent list
- [ ] **SendGrid Activity** entry for the alert (status = Delivered, not just Processed) — see caveat §9
- [ ] Recipient inbox screenshot of the alert email (subject + enumerated body)
- [ ] DB `SELECT` of the rows *after* (showing `RequestSentTimeStamp` state)
- [ ] `GET /health` `200` after the failure run (service alive)
- [ ] Recovery: DB `SELECT` showing rows stamped after restore
- [ ] Config restored to original values (teardown confirmation)

---

## 8. Teardown

1. **Restore** any changed config keys (`processor:vantiv:batch:sftpUrl`, `sftpPassword`) to original values.
2. Re-run `POST /send-funding-batch` once to confirm recovery (this is TC-04).
3. Remove synthetic rows: `DELETE FROM Payments.FundingBatches WHERE BatchFileName LIKE 'PAY3821-E2E-%';`
4. Confirm no synthetic rows remain pending that could be picked up by a scheduled run.

---

## 9. Caveats & Notes

- **⚠️ Email "accepted" ≠ "delivered".** The `Wellfit.SendGrid` wrapper's `Send` is fire-and-forget
  `void`; a successful return only means SendGrid **accepted** the request (HTTP 202). "An alert email
  was sent" MUST be verified by **actual delivery** — confirm via **SendGrid Activity** *and* the
  **recipient inbox / M365 quarantine**. (Prior alert work was bitten by treating accepted as delivered.)
- **202 is the endpoint enqueue ack, not the send result.** All real outcomes are async on the
  background coordinator — always assert via App Insights `correlationId` + DB + inbox, never from the
  HTTP response alone.
- **Coordinate with PAY-3587 H2** (Treasury `BackgroundService` outer-try): overlapping ground. H2 keeps
  the host loop alive; PAY-3821 handles/logs/alerts at the send site. After this change, the loop should
  have nothing fatal to swallow — TC-02/03 step 8 (service healthy) is the shared assertion.
- **Banking-day gate:** if TC results are "nothing happened," confirm P7 first before logging a failure.

---

## 10. Sign-off

| Field | Value |
|---|---|
| Build / commit under test | _(fill — must include PR #283)_ |
| Environment | _(Dev / SBOX)_ |
| Executed by | _(name)_ |
| Date executed | _(date)_ |
| Result (TC-01..05) | _(pass / fail / n-a per case)_ |
| Defects raised | _(links)_ |
