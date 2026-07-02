# QA Verification — PAY-3821 Treasury funding-batch send error handling

**Work item:** PAY-3821 · **PR:** wellfit-payments #283 · **Type:** env-level, black-box (Task T4)
**Spec:** `solution.md` (this folder), `## QA verification` · **Created:** 2026-06-23

## What this verifies

The unit tests (PR #283) prove the control-flow logic with the SFTP boundary stubbed. This T4 pass
proves the behaviour **end-to-end against a real deployed Treasury service**: that a genuine Worldpay
SFTP failure is caught, alerted **once**, logged with batch context, stops the run, and leaves unsent
batches eligible for the next run's idempotent retry.

The failure condition is **config-inducible — no test harness needed.**

## Environment

- **Dev or SBOX** (do NOT run against PROD). Per the Wellfit DEV/STAGE convention, QA owns STAGE/SBOX.
- Treasury API (role *Wellfit Treasury API*) deployed and reachable.
- App Insights for the Treasury API accessible.
- A **team-reachable inbox** configured as `notifications:settlement:recipients`.

## Trigger options (pick one)

1. **Natural (while it lasts):** Dev/SBOX currently reproduce the exact `SocketException` via the
   Worldpay source-IP allowlist gap — just trigger `POST send-funding-batch` as-is.
2. **Deterministic — `SocketException` branch:** point `processor:vantiv:batch:sftpurl` at a
   non-routable host in the env overlay → guaranteed connect timeout.
3. **Deterministic — `LitleOnlineException` branch:** set a wrong `sftpPassword` → `SshAuthenticationException`
   → the SDK wraps it → `LitleOnlineException`.

> Which of the two exception types was caught is **not** externally distinguishable by design — that
> distinction is covered by the unit tests. Pick whichever trigger is convenient.

## Preconditions

- `FundingBatches` rows staged with `BatchFileName IS NOT NULL` and `RequestSentTimeStamp IS NULL`.
  Stage **≥3 rows** to exercise the multi-batch "stop and enumerate" case (SQL-stageable in Dev — see
  the Treasury funding SQL fixture).
- It is a **banking day** (otherwise `IsBankingDay()` skips the loop and nothing runs).
- `notifications:settlement:recipients` points at a reachable inbox.

## Procedure

1. Stage the `FundingBatches` rows (≥3, per preconditions).
2. Apply the failure trigger (option 1, 2, or 3 above).
3. Invoke the funding-batch send (`POST send-funding-batch`).
4. Observe the results below.
5. **Restore** the config to good values and re-trigger to confirm recovery.

## Pass / fail assertions

| # | Assertion | AC |
|---|---|---|
| 1 | **Exactly one** alert email: the failed batch is named, **all** unsent batches are enumerated (Id + filename), and batches sent *before* the failure are **absent**. | AC-1, AC-2 |
| 2 | App Insights **error** log (role *Wellfit Treasury API*) carries `BatchId`, `BatchFileName`, SFTP host, and the unsent-batch list. | AC-1 |
| 3 | `RequestSentTimeStamp` remains **NULL** for the failed + stranded rows; **set** for any batch sent before the failure. | AC-3 |
| 4 | Service is **healthy** afterwards — endpoint still returns `202`, no host-loop death. | AC-3 |
| 5 | After restoring config and re-triggering, batches **send and stamp normally** (idempotent retry intact). | AC-5 |

## ⚠️ Email-delivery caveat (do not skip)

"An alert email was sent" must be verified by **actual delivery**, not by the service logging a send.
The SendGrid wrapper's `Send` is fire-and-forget `void` — it returning successfully only means SendGrid
**accepted** the request (HTTP 202), **not** that the message was delivered. Confirm via **SendGrid
Activity** AND the **recipient inbox / M365 quarantine**. (We have been bitten by treating "accepted"
as "delivered" on prior alert work.)

## References

- Production change + unit tests: wellfit-payments PR **#283**
- Spec / decisions: `solution.md` (this folder), `## QA verification`, `## Acceptance criteria`
- Coordinate with **PAY-3587 H2** (Treasury `BackgroundService` outer-try) — overlapping ground.
