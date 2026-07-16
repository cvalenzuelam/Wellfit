# PAY-4032 — ACH redeposit (retry-mint) test runbook

**Jira:** PAY-4032 — move ACH redeposit-mint off legacy payments-api into Payment Management (Pattern D′)
**Code:** `wellfit-payments` PR #319 (merged) — branch `PAY-4032-ach-retry-mint-payment-management`
**Flag:** `PaymentManagement:AchRetry:Enabled` — **default OFF** everywhere
**Companion:** `PAY-4032-ach-redeposit.postman_collection.json` (same folder)

---

## 1. What is under test

When an ACH debit is **returned** by the bank (NACHA return, e.g. R01 insufficient funds), the business
may **re-present** it — a *redeposit* (retry). PAY-4032 moves the minting of that retry from the legacy
`payments-api` into Payment Management, behind a flag, and wires it to settle and to count toward the
NACHA re-presentment cap (2).

### The retry chain (and where each stage can be triggered)

| # | Stage | Trigger mechanism | HTTP? |
|---|-------|-------------------|-------|
| 1 | ach-returns ingests a return → **PM `PaymentReturnReceivedHandler`** transitions the original to RETURNED and (flag ON + `RedepositEligible`) mints an **APPROVED retry child** in one unit of work | `Payment.Return.Received` on the Azure **Service Bus** `payments` topic | No |
| 2 | PM calls **WorldpayWrapper.API** to re-present at Vantiv | `POST /api/v1/echeck/redeposits` | **Yes** |
| 3 | On approval PM emits **`Payment.Retry.Submitted`** | Event Grid CloudEvent | No |
| 4 | **payments-func `SyncAchChargeFunction`** mints a Platform `Charge` (Id = `RedepositPaymentId`) | `[EventGridTrigger]` CloudEvent | No |
| 5 | Treasury batch-build settles the child (correlates `PaymentId == Charge.Id`) | DB batch pickup | No |
| 6 | **ach-returns** `RedepositAttemptedIntegrationEvent` consumer increments `TotalRedepositAttempts` (the NACHA cap PM honors) | same `Payment.Retry.Submitted` | No |

**Key fact:** the chain has exactly **one real HTTP surface** — stage 2. Everything else is a message.

### 1a. Event-handling code — all shipped in PR #319, and its tests

The event-handling for PAY-4032 (the inbound `Payment.Return.Received` consumer **and** the outbound
`Payment.Retry.Submitted` producer, across three services) all merged in **wellfit-payments PR #319**
(merge commit `97e0e36e0`, 2026-07-09) — the same PR as the WorldpayWrapper call and the DB index.

| Service | File | Role | Automated test (in #319) |
|---------|------|------|--------------------------|
| PM | `Infrastructure/EventHandlers/PaymentReturnReceivedHandler.cs` | inbound consumer; mints the retry child | `PaymentReturnReceivedHandlerTests` (unit) + `PaymentReturnReceivedHandlerIntegrationTests` (Testcontainers SQL) |
| PM | `Infrastructure/EventHandlers/Events/PaymentReturnReceivedEvent.cs` | inbound event DTO (B3 add-only fields) | via handler tests |
| PM | `Events/PaymentRetrySubmittedEvent.cs` | outbound `Payment.Retry.Submitted` event | emit / no-emit asserted in handler unit tests |
| PM | `Events/RetryEventPublisherExtensions.cs` | publisher | handler tests (`publisher.Verify`) |
| payments-func | `Functions/SyncAchCharge/SyncAchChargeFunction.cs` | `[EventGridTrigger]`; mints the Charge | `SyncAchChargeFunctionDeserializationTests` |
| payments-func | `Functions/SyncAchCharge/Models/PaymentRetrySubmittedEventDto.cs` | inbound DTO | deserialization tests |
| payments-func | `scripts/eventgrid-subscriptions/provision-eg-subs.sh` | EG subscription wiring | infra script — no unit test |
| legacy payments-api | `AchReturnReceivedEventHandler.cs`, `PaymentEventPublisher.cs`, `RedepositAttempted/RedepositAttemptedEvent.cs` | retiring legacy path | existing payments-api tests |

**Test coverage of the event handling, stated plainly:**
- **This runbook's live/manual tests do NOT touch the event handling.** Part A (Postman) exercises
  **only** the WorldpayWrapper HTTP boundary (stage 2).
- The event-driven stages (1, 3, 4) are covered by the **automated** unit + integration tests above,
  which shipped in #319 and run in CI.
- The only **manual/E2E** exercise of the event chain is **Part B, which is parked** (flag OFF / legacy
  double-redeposit / B3 rename). So there is no runnable runbook test for the event handling today.

---

## 2. Coverage map — what already exists vs. what these artifacts add

| Layer | Status | Covers |
|-------|--------|--------|
| Unit (`PaymentManagement.API.Tests`) | ✅ 1287 pass (PR #319) | mint gate, approve-only emit, declined-does-not-emit, event body build |
| Unit (WorldpayWrapper) | ✅ green | `long.TryParse` fail-fast, factory-never-called on bad input |
| Unit (payments-func) | ✅ green | `Payment.Retry.Submitted` deserialization / branch-on-type |
| Integration (`PaymentReturnReceivedHandlerIntegrationTests`, Testcontainers SQL) | ✅ | full DB pipeline + retry child minted in one UoW — **but `IWorldpayService` is MOCKED** |
| **Live Vantiv re-presentment** (`echeckRedeposit` by `litleTxnId`) | ❌ **gap** | — → **Postman, Part A** |
| **Full event chain end-to-end** (flag ON → emit → func → Charge → settle) | ❌ not runnable yet | — → **E2E, Part B (parked)** |

The two artifacts here target the two ❌ rows. The logic in stages 1/3/4 is already well covered by the
mocked integration + unit suites; the untested residue is the **real network call** and the **wiring**.

---

## 3. Part A — Postman: WorldpayWrapper redeposit boundary (run today)

**Goal:** prove the live Vantiv re-presentment that the integration test mocks. Flag-agnostic (this
endpoint is independent of `PaymentManagement:AchRetry:Enabled`).

**Environment:** local **CNP sandbox** (fully fakeable — see §3.1), Worldpay **Pre-Live**, or DEV.

### 3.1 — Can we fake the returned eCheck? (yes, at two of three tiers)

There are three tiers of "Worldpay" behind the wrapper, selected by the `UseCnpSandbox` flag +
`processor:*` config on WorldpayWrapper.API:

| Tier | Backend | Fakeable? | How |
|------|---------|-----------|-----|
| 1 | Local `vantivsdk/sandbox` container (`UseCnpSandbox=true`, `processor:sandbox`) | **Fully** | Sandbox is **amount-driven** and **does not validate the referenced txn** — a redeposit carries no amount → `000 Approved` for **any** `litleTxnId`, even a fabricated one |
| 2 | Worldpay **Pre-Live** (`payments.vantivprelive.com`, default config) | **Partly** | Seed a real txn first (see below). Pre-Live honors the real cert **deck** (specific amount+account pairings) — that part needs deck data, not arbitrary values |
| 3 | Worldpay Production | No | never test here |

**Tier 1 is the answer to "can we fake it":** point the wrapper at the local sandbox and the redeposit
call accepts a made-up `originalLitleTxnId` and returns `000`. This is already exercised in CI
(`CnpSandboxIntegrationTests.EcheckRedeposit_ThroughSandbox_ReturnsApprovedResponse`, which redeposits a
hard-coded `82919473291827364`). What Tier 1 certifies: our endpoint + `CnpRequestMapper` → SDK →
`CnpResponseMapper` chain. What it does **not** certify: that real Vantiv actually re-presents a
genuinely-returned eCheck — only Tier 2/Pre-Live does, and that piece is largely Worldpay's concern.

**Sandbox magic amounts (echeckSale):** the sandbox returns `response = amount % 1000` (last 3 digits of
the cents amount) and ignores account/routing. So you can mint a seed txn with any outcome:

| Amount (cents) | Response | Meaning |
|---|---|---|
| 5000 | 000 | Approved |
| 1001 | 001 | Transaction Received |
| 1110 | 110 | Insufficient Funds |
| 301 | 301 | Invalid Account Number |
| 900 | 900 | Invalid Bank Routing Number |
| 965 | 965 | Daily Sale Limit Exceeded |

To run the wrapper against Tier 1 locally: start `vantivsdk/sandbox` (exposes 8888), set
`processor:UseCnpSandbox=true` and `processor:sandbox:url=http://localhost:<port>/communicator/online`
(username/password/merchantId = `sandbox`/`sandbox`/`default`).

### Preconditions
1. **Tier 1 (recommended to run today):** wrapper pointed at the sandbox (above). `originalLitleTxnId`
   can be **anything numeric**. Optionally seed a real one via request **1a** (eCheck sale).
   **Tier 2:** a genuinely-returned eCheck's `litleTxnId`, or seed one via request 1a.
2. `accountId` (Vantiv account credential key) and `subMerchantId` (WP `customerId`).
3. A bearer token satisfying **`requireWorldpayWrapperAccess`** (`ECheckFeatureGate` on for that env).
   Use collection request **0** or paste into `bearerToken`.

### Steps & expected results

| Req | Action | Expected |
|-----|--------|----------|
| 0 | Get token (`client_credentials`) | 200, `access_token` captured |
| 1a | *(optional)* eCheck **sale** to seed a real `litleTxnId` (amount 5000 → approved) | 200; `responseCode = 000`; `transactionId` captured into `originalLitleTxnId` |
| 1 | Redeposit with a valid numeric `transactionId` | 200; `status = Approved`, `responseCode ∈ {000, 001}` — **Tier 1: always 000**; Tier 2: data-dependent, record the actual code |
| 2 | Redeposit with `transactionId = "not-a-number"` | 200; `status = Failed`, `responseCode = VALIDATION_ERROR` (fail-fast, never hits Vantiv) |
| 3 | Redeposit omitting `transactionId` | 400 `ValidationProblemDetails` (model binding) |

> Requests 2 and 3 are deterministic (input-hardening, commit `652df537e`) regardless of tier.
> Request 1 is deterministic on Tier 1 (sandbox → 000) and data-dependent on Tier 2 (real Pre-Live) —
> record the actual response code in the results table (§5).

---

## 4. Part B — E2E full chain (PARKED)

**Goal:** drive stages 1→6 from a single injected `Payment.Return.Received` and observe the child mint,
the Charge, settlement, and the attempt increment.

### Why it has to wait (three hard blockers)

1. **Flag OFF.** `PaymentManagement:AchRetry:Enabled` defaults OFF; with it off, stage 1 never mints,
   so there is nothing downstream to observe.
2. **Legacy still consumes the same return.** Legacy `payments-api` also handles the return; flipping
   the flag ON in a shared env with legacy still live risks a **double redeposit**. No hard
   mutual-exclusion exists (B2) — the flag staying OFF until legacy retirement (Slice 6) is the guard.
3. **B3 inbound DTO field-name mismatch not fixed.** Confirmed single-source chain: ach-returns
   `AchReturnReceivedPublisher` emits **one** CloudEvent `Payment.Return.Received`, `Data =`
   `AchReturnReceivedEvent` (no `[JsonPropertyName]` → serialized PascalCase); its original-payment id
   field is **`OriginalPaymentId`** and there is **no `paymentId`/`PaymentId` field at all**. Legacy
   payments-api consumes this off Event Grid and keys on `ReturnedPaymentId` (present) → works. The new
   impl bridges the same CloudEvent onto the Service Bus `payments` topic (EG→SB bridge is new-impl-only),
   where PM binds the original-payment lookup to **`paymentId`** → nothing on the wire matches →
   `Guid.Empty` → dead-letter.
   **This is a field-NAME mismatch (`OriginalPaymentId` vs `paymentId`), not a casing difference** —
   case-insensitive CloudEvent binding cannot fix it. PR #319 is **add-only** (`RedepositEligible` /
   `TotalRedepositAttempts` / `ReturnedPaymentId` — these already match the publisher's names); the
   remaining gap is the primary id. Fix = PM binds `OriginalPaymentId` (or keys off `ReturnedPaymentId`
   like legacy). Prerequisite for flag-ON with real events; **no ticket exists**.

Plus: **STAGE cannot synthetically publish** (QA can't inject the trigger there) — only DEV can, via
`az`/SB REST. So even after the blockers clear, the first E2E is a DEV exercise.

### When unblocked — procedure

Prereqs: DEV; flag ON; B3 rename merged; SB `payments` subscription + EG subs
(`Payment.Retry.Submitted` in `provision-eg-subs.sh`) provisioned; seed an **original ACH DEBIT** in
`APPROVED` or `SETTLED` and capture its `Payments.Id` (`originalPaymentId`) and the
`ReturnedPayments.Id` (`returnedPaymentId`).

1. **Inject** `Payment.Return.Received` (flat body, `RedepositEligible = true`, `TotalRedepositAttempts = 0`).
   Preferred: drive it through **ach-returns** (real publisher, correct field casing) rather than a hand-rolled
   message. The Postman **request 4** is a reference SB-REST template only — verify the `MessageType`
   routing property against `provision-sb-topics.sh` before relying on it.
2. **Assert (SQL / Payments DB):**
   - original → `RETURNED`; an `ACHReturns` row exists.
   - a **child** `PaymentTransaction` with `ParentTransactionId = original`, `RetryAttempt = 1`,
     `TransactionStatusId = APPROVED`, `ProcessorTransactionId` = the redeposit txn.
   - the child's unique filtered index `UQ_PaymentTransaction_Root_RetryAttempt` accepted the insert.
3. **Assert (Charge / payments-func):** a Platform `Charge` with `Id = RedepositPaymentId`, `Rail = ACH`,
   response `000` (via App Insights `SyncAchChargeFunction` trace + DB).
4. **Assert (settlement):** treasury batch picks up the Charge by `PaymentId == Charge.Id`; child settles.
5. **Assert (cap):** ach-returns increments `TotalRedepositAttempts`; a re-run past cap (2) does **not** mint.
6. **Approve-only:** a **declined** redeposit still mints the child + persists but emits **no**
   `Payment.Retry.Submitted` (declined never burns a re-presentment slot).

### 4a. DEV synthetic smoke — runnable ahead of the full unblock

The three "hard blockers" above frame the *real-traffic, flag-ON-for-real* scenario. A **one-off DEV
smoke using a synthetic injected event** is reachable much sooner, because you control the payload:
- **B3 rename is NOT required** — craft the inject to the DTO shape PM binds today (`paymentId`
  camelCase + `RedepositEligible`/`TotalRedepositAttempts` PascalCase). It only matters for *real*
  ach-returns traffic.
- **Legacy double-redeposit** only bites if legacy is also consuming in DEV — control it (below).

So this proves the **wiring** (consume → mint → emit → Charge), not real ach-returns field-casing.

**Ticket reality (checked 2026-07-13):** the B3-rename and Slice-6 tickets do **not exist**; PAY-4032 is
In Stage with QA subtasks PAY-4099 / PAY-4100 active. The full unblock is unscheduled — this smoke is the
only near-term option.

**Owner actions required (not self-serve):**
- **A.** Flip `PaymentManagement:AchRetry:Enabled = ON` in **DEV PM config only** (config vault / app
  settings — whoever owns DEV PM config). Flip it back OFF after the run.
- **B.** Ensure legacy payments-api `AchReturnReceivedEventHandler` is **not** also consuming in DEV (else
  double-mint) — disable its subscription for the run, or accept + reconcile the dup.

**Infra prereqs:** `az login`; **Service Bus Data Sender** on `dev-sbns-payments-westus3` `payments`
topic; **Payments DB read** on `sqldb-plat-dev-001` / `Payments` (both per `scripts/e2e-ach-lifecycle/envs/dev.env`).

**Steps** (reuse the `e2e-ach-lifecycle` harness for seed + asserts; it has no return step, so step 3 is new):

1. **Seed a real original ACH debit** — run harness `./run.sh dev` steps `01-fetch-token` → `02-post-pv2-debit`
   → `03-wait-for-pm-sync` (optionally `05b-force-settle-debit`). Capture the original `Payments.Id`
   (`originalPaymentId`) and its `ReturnedPayments.Id` (`returnedPaymentId`). Original must be APPROVED or SETTLED.
2. **Confirm flag ON** (owner action A) and legacy quiet (owner action B).
3. **Inject `Payment.Return.Received`** onto the SB `payments` topic — body crafted to the current DTO
   (`paymentId=originalPaymentId`, `RedepositEligible=true`, `TotalRedepositAttempts=0`,
   `ReturnedPaymentId=returnedPaymentId`). Use Postman **request 4** (SAS template) *or* add a harness step
   mirroring `02-post-pv2-debit`'s publish. (New work — not in the harness today.)
4. **Assert — Payments DB:** original → `RETURNED`; child `PaymentTransaction` with
   `ParentTransactionId=originalPaymentId`, `RetryAttempt=1`, `APPROVED`; an `ACHReturns` row exists.
5. **Assert — payments-func:** a `Charge` with `Id=RedepositPaymentId`, `Rail=ACH`, `000` (App Insights
   `SyncAchChargeFunction` trace + DB).
6. **Assert — NACHA cap:** ach-returns increments `TotalRedepositAttempts`; re-inject past cap (2) mints no child.
7. **Cleanup:** remove synthetic rows; owner flips the flag back OFF.

**What this does NOT prove:** real ach-returns field-name binding (B3 — `OriginalPaymentId` vs `paymentId`) and real Vantiv re-presentment
of a genuinely-returned txn — those still need B3 + a real returned txn respectively.

---

## 4b. DEV connection facts (verified 2026-07-13)

- **Base URL:** `https://dev-app-worldpay-wrapper.azurewebsites.net` (Azure app `dev-app-worldpay-wrapper`,
  RG `dev-rg-plat-api-wus3`). The `dev2-wf-worldpay-wrapper-api` hostname in the checked-in terraform
  state is **stale/dead** — ignore it. Deployments are managed in Octopus (project "Worldpay Wrapper
  API", space "Platform"), not by the repo's terraform workspaces.
- **DEV fronts real Worldpay Pre-Live** (`UseCnpSandbox=false`), confirmed empirically: a redeposit of a
  fresh (non-returned) sale returns `367` (see run log). The local `vantivsdk/sandbox` is localhost-only
  and never deployed, so it is not reachable on DEV.
- **Auth:** token from `https://dev-platform.wellfit.com/identity/connect/token`, `client_credentials`,
  **scope `WorldpayWrapperAPI.Full`** (required by policy `requireWorldpayWrapperAccess`). The entitled
  S2S client is **`WellfitPaymentManagementAPI`** (the client PM uses). The generic DEV clients in
  `scripts/e2e-ach-lifecycle/envs/dev.env` (`WellfitUnifiedPaymentsAPI`, `WellfitAutomation`) are **NOT**
  granted this scope — both return `invalid_scope`. Use a client that holds `WorldpayWrapperAPI.Full`.
- Endpoint is also gated by `[ECheckFeatureGate]` — enabled in DEV (sale + redeposit both processed).

## 5. Results table

### Run log — DEV (Pre-Live), 2026-07-13

| Req/Step | Expected | Actual | Pass/Fail | Notes |
|----------|----------|--------|-----------|-------|
| 0 token | 200 + access_token | 200 | Pass | scope `WorldpayWrapperAPI.Full` |
| 1a eCheck sale (amount 5000) | 200, 000 Approved, litleTxnId | 200, `000` Approved, litleTxnId `83999769095923222` | Pass | seeds a real Pre-Live txn |
| 1 redeposit (fresh sale) | 200 Approved 000 **or** state-rejection | 200, **Declined `367`** "Deposit has not been returned for insufficient/non-sufficient funds" | Pass* | *Correct Vantiv behavior + faithful mapper round-trip. The `000` leg needs a genuinely NSF-returned txn; a fresh sale is not redepositable on Pre-Live. This is the key boundary proof the mocked integration test cannot give. |
| 2 non-numeric txn id | 200 Failed VALIDATION_ERROR | 200, Failed, `VALIDATION_ERROR`, exact message | Pass | fail-fast guard (commit `652df537e`) |
| 3 missing txn id | 400 model-validation | 400, "The TransactionId field is required." (framework input-error array) | Pass | shape is Wellfit input-error list, not classic ValidationProblemDetails |
| B-* full chain | (parked) | — | — | blocked: flag OFF / legacy double-redeposit / B3 rename |

**Conclusion:** the PAY-4032 code path the team owns — request mapping → real Vantiv call →
`CnpResponseMapper` → wrapper response — is verified against live Pre-Live. The only leg not reachable
from a fresh seed is an *approved* (`000`) redeposit, which by Vantiv rule requires a transaction
actually returned for NSF (or the localhost sandbox).

---

## 6. Blockers & references

- **Flag / legacy / B3** — see §4. Full E2E is gated on all three + DEV-only injection.
- **B3 inbound DTO rename** — separate follow-up ticket; prerequisite for flag-ON with real traffic.
- **Legacy retirement (Slice 6)** — separate future PR; the only hard guard against double-redeposit is
  the flag staying OFF until then.
- Source of truth for the contracts used above:
  - `WorldpayWrapper.API/.../CreateEcheckRedeposit/*` (endpoint + request/response)
  - `PaymentManagement.API/Infrastructure/EventHandlers/Events/PaymentReturnReceivedEvent.cs` (inbound)
  - `PaymentManagement.API/Events/PaymentRetrySubmittedEvent.cs` (outbound)
  - `payments-func/.../SyncAchCharge/SyncAchChargeFunction.cs`
