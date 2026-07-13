# PAY-3811 — ACH Token Vault deactivation events never reach Event Grid

**Bug · ach-token-vault · Status: In Stage · Fix: R9.6 · QA: Chris (PAY-4011, PAY-4012)**

Jira export: `tickets/PAY-3811/PAY-3811-Jira-Export.pdf`. Related (closed): `tickets/PAY-3790/PAY-3790-Jira-Export.pdf` — Account Updater orchestrator; AC-2 depended on this fix.

**Postman (STAGE):** collection `postman/collections/PAY-3811-OnNocUpdateReportIngested-STAGE.postman_collection.json` + env `postman/environments/PAY-3811-OnNocUpdateReportIngested-STAGE.postman_environment.json` (set `functionKey` locally).

---

## Ticket summary

| Field | Value |
|-------|--------|
| **Type** | Bug (Priority 3) |
| **Labels** | `account-updater`, `ach-token-vault` |
| **Assignee (dev)** | Jay Patel |
| **QA sub-tasks** | PAY-4011 Create test cases · PAY-4012 Test fix — **Chris** |
| **Related** | PAY-3790 (orchestrator NOC correlation — closed) |

---

## Problem

Two vault publishers pass **`["subject"]` as a CloudEvent extension attribute**:

- `NocBankAccountDeactivatedPublisher` → **`Account.BankToken.NocDeactivated`**
- `AchReturnBankAccountDeactivatedPublisher` → **`Account.BankToken.ReturnDeactivated`**

Azure Event Grid rejects **`subject`** as a reserved attribute name → **every publish throws**.

**Wellfit.EventGrid 3.0.4** (`PublishAsyncDomain`) **swallows the exception** and logs **`Successfully published…`** anyway → events **never** reach the EG Domain **`accounts`** topic; logs claim success.

### Before fix (repro — local compose e2e, 2026-06-10)

1. Drive a **NOC deactivation** through the vault.
2. Log shows: `Failed to publish event Account.BankToken.NocDeactivated … ArgumentException … reserved attribute: 'subject'`
3. **Immediately followed by:** `Successfully published…`
4. **Reproducibility:** Always.

### Impact

- Latent until Account Updater orchestrator is promoted.
- Orchestrator **`OnAccountDeactivated`** never fires → **`AccountUpdater.ReturnDeactivations`** stays empty → ACH reporting FR-10 (Bank Account Deactivation report) blank; PAY-3790 AC-2 could not pass.

---

## Expected after fix

| Area | Expected |
|------|----------|
| **Publish shape** | `subject` via the publish overload’s **subject parameter** — **no** reserved extension attrs |
| **Event Grid** | Both deactivation event types arrive on EG Domain **`accounts`** topic |
| **Orchestrator** | Deactivation recorded in **`ReturnDeactivations`** / NOC resolution path |
| **Logging** | Failed publish → **error** log, **never** false success |

---

## Acceptance criteria (QA scope)

| AC | Owner | What to verify |
|----|--------|----------------|
| **AC-1** | Dev (unit tests) | Publishers call publish with correct shape; assert no reserved extension attrs. **Manual QA: skip** — cite CI/PR. |
| **AC-2** | **QA (Dev or Stage)** | Vault deactivation **observable** on **accounts** Service Bus topic; orchestrator persists **`ReturnDeactivations`** row (or NOC resolution evidence). |
| **AC-3** | **QA + dev** | If publish fails, vault logs **error**, not `Successfully published…`. Interim vault-side mitigation OK; framework swallow tracked separately in **wellfit-framework-core**. |

---

## Services & events

| Item | Detail |
|------|--------|
| **Service** | ACH Token Vault (`ach-token-vault`) |
| **Publishers** | `NocBankAccountDeactivatedPublisher`, `AchReturnBankAccountDeactivatedPublisher` |
| **Event types** | `Account.BankToken.NocDeactivated`, `Account.BankToken.ReturnDeactivated` |
| **Destination** | Event Grid Domain → topic **`accounts`** → downstream **Service Bus** subscription |
| **Consumer** | Account Updater orchestrator (`OnAccountDeactivated`) |
| **Framework bug (out of scope)** | `Wellfit.EventGrid 3.0.4` false-success in `PublishAsyncDomain` |

---

## STAGE QA runbook (BMAD — 2026-07-09)

Cursor rule: `.cursor/rules/wellfit-qa-pay-3811.mdc` (globs `tickets/PAY-3811/**`).

### Why NULL-Token ACH fails TC1

AchReturns builds `Payment.Return.Received` with `TokenId` only if `[Payments].[Payments].Token` parses as a GUID (`Guid.TryParse`). If `Token` is null/non-GUID → vault **Acknowledge, no deactivation**.

**Tokenized** ⇔ `Payments.Payments.Token` = `TokenVault.dbo.BankAccountTokens.Id` (`Status=Active`).  
`PaymentMethodACH` / card `Tokenizations` / `BankAccounts` are irrelevant for this link.

### Chris attempt 2026-07-09

- R02 inject + `FileProcessedEvent` → `ReturnedPayments` status 1; AchReturns `Payment.Return.Received` OK.
- `ReturnDeactivations` empty; no vault `ReturnDeactivated` / `OnAccountDeactivated` — anchor `Token` was NULL (PAY-4047-style payment).

### (F) Wiring check first

SB: `payments` → `ach-tokenvault-api` (`Payment.Return.Received`); `accounts` → `ach-tokenvault-api` (`Account.NoC.Received`).

```kusto
traces | where timestamp > datetime(2026-07-09)
| where message has "AchReturnReceivedIntegrationEvent"
```

Use **vault** App Insights role (`ach-tokenvault-api`), not the func app. Empty → env blocker. Empty TokenId in message → wired; fix Token data.

### (B) Anchor

Option 1: find ACH payment whose `Token` ∈ Active `BankAccountTokens.Id`.  
Option 2: `UPDATE` disposable payment `Token` to an Active vault GUID (e.g. QA Tester `73850000-5622-EA37-EDEC-08DED213101F`).

### (C)–(D) TC1

Same PAY-4047 path: `inject-ach-return.sql` R02 + `FileProcessedEvent` within 5 min on **tokenized** anchor.

Pass: vault “Hard return” + `Published AchReturnBankAccountDeactivatedEvent`; 0 reserved-attribute errors; token Inactive + `DeactivatedAt`; one `[AccountUpdater].[ReturnDeactivations]` row (`WellfitTokenId`, `ReturnCode=R02`, `SourceEventId`=ReturnedPaymentId); `OnAccountDeactivated` fired.

### TC2 / TC3 / out of scope

- **TC2 NOC:** `Account.NoC.Received` with matched vault TokenId → NocDeactivated + token Inactive + NOC resolved Deactivated (not ReturnDeactivations).
- **TC3:** R01/R09 on tokenized anchor → token stays Active; no deactivation row.
- **AC-3** framework swallow: out of scope. **AC-1** unit tests only.

---

## App Insights KQL (starting points)

Vault — return ingest / deactivation:

```kusto
traces
| where timestamp > ago(2h)
| where message has "AchReturnReceivedIntegrationEvent"
    or message has "Hard return code"
    or message has "Published AchReturnBankAccountDeactivatedEvent"
    or message has "ReturnDeactivated"
| project timestamp, severityLevel, message, cloud_RoleName
| order by timestamp desc
```

Reserved-attribute regression (must be zero post-fix):

```kusto
traces
| where timestamp > ago(2h)
| where message has "reserved attribute" or message has "Failed to publish event Account.BankToken"
| project timestamp, message, cloud_RoleName
| order by timestamp desc
```

Orchestrator:

```kusto
traces
| where timestamp > ago(2h)
| where message has "OnAccountDeactivated" or message has "ReturnDeactivations"
| project timestamp, message, operation_Id, cloud_RoleName
| order by timestamp desc
```

---

## Suggested Testmo themes (~8 cases when writing PAY-4011)

1. STAGE wiring — vault receives `AchReturnReceivedIntegrationEvent` (F).
2. Tokenized anchor — `Payments.Token` = Active `BankAccountTokens.Id` (B).
3. TC1 hard return R02 — vault publish + token Inactive (C/D).
4. TC1 — no reserved-attribute publish failure (PAY-3811 fix).
5. TC1 — `ReturnDeactivations` row + `OnAccountDeactivated` (D).
6. TC3 soft return R01/R09 — no deactivation (E).
7. TC2 NOC deactivation path (E) when harness available.
8. AC-1 unit tests / PR #290 — cite CI (no manual). AC-3 out of scope.

---

## Blockers / sync with dev

1. Vault SB subscriptions + ach-tokenvault-api running on STAGE (F).
2. Tokenized anchor (`Token` GUID) — not NULL ACH (B).
3. Orchestrator `OnAccountDeactivated` + EG `accounts` subscription for full E2E row.
4. TC2 NOC inject / direct publish harness if needed.

---

## Jira

https://wellfit.atlassian.net/browse/PAY-3811
