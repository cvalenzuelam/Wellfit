# PAY-3509 — Story 2.1 Legacy Publisher E2E Run (DEV + STAGE) — 2026-06-15

**Feature:** transaction-limit-compliance-alerts — Story 2.1 (+ 2026-06-11 rail follow-up)
**Jira:** PAY-3509
**Executed by:** Brett Roy (via Tony / Testing Automation)
**Method:** Live `POST /credit-card/process-card` (WorldPay **CERT** — no live settlement) + Event Grid → Storage-Queue capture, per `PAY-3509-Story-2.1-E2E-Legacy-Publisher-Runbook.md`
**Source under test:** GHE `wellfit-payments/src/services/payments-api` @ branch `PAY-3509-rail-aware-transaction-limit-alerts`
**Sub-merchant:** `B7711D60-DBBB-4BC1-9462-000BF1511E88` (Clermont Smiles), `TransactionLimit` set to **$1000.00** by Brett for this run

---

## Summary

| Environment | Outcome |
|---|---|
| **DEV** | ✅ **PASS** — both scenarios captured on the live wire; AC-2/3/4/5/6 confirmed. Rail follow-up confirmed (`rail:"CNP"` on decline). |
| **STAGE** | ✅ **PASS (E2E incl. email)** — card decline processed (NOT skipped by the PV2 guard) → "Card Payment" alert email **delivered**. See STAGE section. |

---

## Capture setup

- Storage queue `e2e-pay3509-debit-capture` (`stplatdev1`, RG `dev-rg-plat-data-wus3`).
- EG event subscription `e2e-pay3509-debit-capture` on domain `dev-evgd-payments` / topic `payments` (RG **`dev-rg-plat-core-wus3`**), filter `Payment.Debit.Submitted`, schema CloudEventSchemaV1_0.
- **Created + deleted via `az rest`** (raw ARM) — the `az eventgrid event-subscription` command group fails with `MissingSubscription` on the operator host; `az rest` PUT/DELETE bypasses it cleanly.
- Both queue + subscription **torn down** after the run. DEV left clean.

## Scenario A — Decline ($1500 > $1000 limit) — ✅ PASS

API response: **HTTP 400** `Payment.InvalidAmount` "This transaction is over your maximum allowed amount (1000.00)." (prompt 4xx, no 500/timeout → fire-and-forget AC-6 ✅).

Captured `Payment.Debit.Submitted` `data` block (orderId `P3509D-144927-16397`, paymentId `8aec6fdd-e4fe-418a-bafd-f2b2ba962df4`):

| Field | Value | AC |
|---|---|---|
| `status` | `"Declined"` | AC-3 ✅ |
| `declineReason` | `"PerTransactionLimitExceeded"` | AC-3 ✅ |
| `configuredTransactionLimit` | `1000.0` | AC-3 ✅ |
| `statusMessage` | `"Amount $1500.00 exceeds configured transaction limit of $1000.00"` | AC-3 ✅ (invariant `$`/`.` format) |
| `rail` | **`"CNP"`** | follow-up ✅ → "Card" label |
| keys (`paymentId`, `subMerchantAccountId`, …) | camelCase | AC-5 ✅ |

## Scenario B — Approved ($9955.44) — ✅ PASS

API response: **HTTP 200**, `transactionId 83999595824051302` (WF *ClermontSmiles).

Captured `data` block (orderId `P3509A-144254-9716`, paymentId `fc441d08-cd1a-4fba-a351-8ad03b9df38f`):

| Field | Value | AC |
|---|---|---|
| `status` | `"Approved"` | AC-4 ✅ |
| `statusMessage` / `declineReason` / `configuredTransactionLimit` | `null` | AC-4 ✅ |
| `rail` | **`null`** | by design — see finding |
| keys | camelCase | AC-5 ✅ |

## AC verdicts (DEV wire)

| AC | Verdict | Evidence |
|---|---|---|
| AC-2 (4 enrichment props, camelCase) | ✅ | Both captures — fields present, camelCase |
| AC-3 (decline-path populated) | ✅ | Scenario A capture |
| AC-4 (success `status:"Approved"`, null decline fields) | ✅ | Scenario B capture |
| AC-5 (camelCase contract) | ✅ | All keys camelCase on both events |
| AC-6 (fire-and-forget; publish failure ≠ blocked response) | ✅ | Prompt HTTP 400 on decline; event still published |
| rail follow-up (`rail` → "Card"/"ACH") | ✅ (publisher leg) | `rail:"CNP"` on decline; "Card" label covered by consumer unit tests (55/55) |

## Finding — `rail` populated only on the decline path

The deployed build sets `rail` **only** at the decline sites (the `ForPerTransactionLimitExceededDecline`
factory, `ProcessCard.cs:77` → `PaymentRail.CardNotPresent`). The **success-path constructor**
(`ProcessCard.cs:131`) does not pass `rail`, so **approved events emit `rail: null`**. Functionally
acceptable — approved events never trigger a compliance alert, so rail has no consumer there — but it's
an event-model inconsistency (the field exists; only one path populates it). Worth noting if anyone later
builds analytics on rail for approved events. **Not a defect against PAY-3509 ACs.**

## STAGE — Guard verification + E2E (2026-06-15)

**Goal:** verify whether the STAGE compliance guard skips the Legacy (non-PV2) publisher — and if not, confirm the alert email fires. Sub-merchant `815C0000-480A-0022-5051-08DD79498B59`, card `TransactionLimit = $30,000`.

**Setup notes:**
- STAGE Legacy API `stage-wf-payments-api` (host `stage-wf-payments-api.azurewebsites.net`); same automation creds work (HTTP 200). App was **momentarily Stopped** on first hit (HTTP 403 "web app is stopped"), came up ~20:26:03Z, retry succeeded.
- Storage-queue wire capture **not available** in STAGE — operator lacks `listKeys` on `stageplatformcore` (`AuthorizationFailed`). Guard verification done via compliance App Insights (appId `27b01e32-…`) instead — no capture needed.

**Trigger:** `POST /credit-card/process-card` amount $30,500 > $30,000 → **HTTP 400** `Payment.InvalidAmount` "over your maximum allowed amount (30000.00)". OrderId `P3509S-152642-8441`, 20:26:48Z.

**Result — guard did NOT skip; email FIRED:**
```
20:26:47.61Z  Sending compliance email To=no-reply@wellfit-stage.com;brett.roy@wellfit.com;
               radhika.kandoori@wellfit.com;ana.oliva@wellfit.com;carlos.parra@wellfit.com
               Subject=Risk Trigger Alert – Card Payment Exceeds Per-Transaction Limit ($30,500.00 > $30,000.00)
20:26:47.87Z  Sent compliance email ... in 264ms
20:26:47.88Z  AlertSent: merchant 815c0000-480a-0022-9be9-08dd79498cd9, reason PerTransactionLimitExceeded, amount 30500.0 exceeds limit 30000.0
```
PaymentId `6b9b90f7-cc97-4c1f-9489-028f9bdd8e23`. **Email delivery confirmed received by Brett.**

**Findings:**
- The PV2 guard **is still active** — an unrelated event at 20:21:10Z was skipped: `PaymentDebitSubmittedHandler … Skipping event without PaymentTransactionId (non-PV2 publisher)`. But **my Legacy event was processed**, i.e., the **STAGE Legacy build now emits `paymentTransactionId`** (differs from the DEV capture, which lacked it). This **corrects** the pre-test assumption (based on the 2026-06-12 run) that the Legacy path would be skipped in STAGE.
- ✅ Rail follow-up works in STAGE: subject labeled **"Card Payment"**.
- **STAGE recipient list = 5 addresses** (incl. radhika.kandoori, ana.oliva, carlos.parra) — they received the test alert.
- **Synthetic record:** no `payment-management` "Created PaymentTransaction" trace found in appId `27b01e32` for the window; cleanup SQL scoped to PaymentId `6B9B90F7-…` handed to Brett (SELECT-first; may be zero rows for a card decline).

**STAGE AC verdict:** AC-2/3/5/6 (publisher) inferred ✅ via processed-not-skipped + "Card Payment" label; end-to-end alert email ✅ delivered. Raw-wire field capture not performed (storage perms).

## Notes / follow-ups

- **Sub-merchant limit:** Clermont Smiles (`B7711D60…`) now has `TransactionLimit = $1000.00` (set by Brett). This will **decline** the previously-working $9,955 approved smoke test until reverted — **revert when done** if other DEV tests depend on it being unlimited.
- **DEV data:** Scenario B persisted an approved payment in DEV payment-management (topic fan-out — normal DEV behavior); Scenario A was a rejected attempt (no persisted payment). No DEV cleanup performed (DEV is the sanctioned test env).
- **Alert-email delivery — investigated 2026-06-15 (NOT delivered despite "AlertSent"):** Brett reported the alert emails never arrive even though the app logs success. Findings:
  - The decline alert fired and logged `Sending… → Sent compliance email To=brett.roy@wellfit.com in 470ms Subject="Risk Trigger Alert – Card Payment Exceeds Per-Transaction Limit ($1,500.00 > $1,000.00)" → AlertSent` (App Insights, 19:49:26–27Z). Note: subject shows **"Card Payment"** → rail follow-up label working end-to-end.
  - **Root-cause class: false success.** `EmailService.SendAsync` (`Application/Services/EmailService.cs:55-65`) calls `ISendEmail.Send(...)` — which (`Wellfit.SendGrid.Components.SendGridEmailSender.Send`) returns **`void`** — and logs "Sent" purely because no exception was thrown. The SendGrid HTTP status is never inspected. App Insights records **no `api.sendgrid.com` dependency** at all, so a non-2xx is invisible. `AlertSent` therefore reflects *acceptance attempt*, not delivery.
  - **Direct SendGrid probe (Tony, restricted `mail.send` key):** a manual `POST /v3/mail/send` from `no-reply@wellfit-qa.com` → `brett.roy@wellfit.com` returned **HTTP 202 Accepted**, **`X-Message-Id: TqPlM4XFS-yOArqT0_Kswg`**. That plain-text test **DID arrive** in Brett's inbox.
  - **Disambiguation:** plain-text direct send arrives; HTML-templated compliance email does not. So delivery to the inbox works in general → the compliance-email failure is specific to that path (templated HTML body, or M365 content filtering/quarantine of the HTML), **or** the templated send returns a non-2xx that the void wrapper swallows. The `EmailService` observability fix (below) is required to tell which.
  - **Could not check directly:** SendGrid Suppressions / mail_settings (sandbox) — API key is least-privileged (`mail.send` only → `access forbidden`). Use the SendGrid **Email Activity Feed** (search message-id `TqPlM4XFS-yOArqT0_Kswg`) for the authoritative Delivered/Dropped/Bounced verdict, and check **M365 Quarantine** for the compliance alerts.
  - **Code fix drafted** (separate from PAY-3509 rail scope — own ticket/branch recommended): make `EmailService` send via the SendGrid SDK client and inspect `Response.StatusCode` + `X-Message-Id`; log structured success/failure and throw on non-2xx so `AlertFailed`/SB-redelivery engages instead of a lying `AlertSent`.
- **STAGE:** not attempted — see `PAY-3509-Story-2.1-E2E-Legacy-Publisher-Runbook.md` → STAGE Caveats (real-payment persistence + DB cleanup obligation; PV2 `paymentTransactionId` guard; PAY-3788/PR #310 storage fix).

## Related automated coverage (2026-06-15)

- Publisher unit suite (`payments-api/Tests/Unit`, net462): **36/36 pass**.
- Consumer scope (`compliance-monitor-ms`, PerTransactionLimit + EmailContent + event serialization): **55/55 pass**.
