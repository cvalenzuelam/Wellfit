# PAY-3811 — ACH Token Vault deactivation events never reach Event Grid

**Bug · ach-token-vault · Status: In Stage · Fix: R9.6 · QA: Chris (PAY-4011, PAY-4012)**

Jira export: `PAY-3811-Jira-Export.pdf`. Blocks PAY-3790 (Account Updater orchestrator — closed; AC-2 depended on this fix).

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

## How to test (QA flow)

### Prerequisites

- Confirm with dev **which env** for PAY-4012 (**Dev** per AC-2 wording; ticket status **In Stage** — align before run).
- Dev documents **how to trigger** each path:
  - **NOC deactivation** (NOC file / account-updater pipeline → vault)
  - **ACH return deactivation** (return code path → vault)
- Access: **App Insights** (vault + orchestrator roles), **Service Bus** peek on accounts topic, **SQL** for orchestrator tables.

### AC-2 — happy path (post-fix)

1. Trigger vault deactivation (NOC or return — one case per event type if both in scope).
2. **Service Bus / EG:** message for `Account.BankToken.NocDeactivated` or `Account.BankToken.ReturnDeactivated` on **accounts** topic — valid CloudEvent, **`subject` in envelope**, not as illegal extension.
3. **Orchestrator:** row in **`AccountUpdater.ReturnDeactivations`** (or dev-confirmed NOC resolution table) tied to the bank token / merchant.
4. **App Insights (vault):** single success publish trace — **no** preceding `ArgumentException` on `subject`.

### AC-3 — logging (post-fix)

- **Before fix:** failure + false success in same request (document as baseline if re-checking pre-deploy).
- **After fix:** inject or natural failure (if dev provides safe trigger) → **error** severity log; **no** `Successfully published…` for a failed publish.

### AC-1

- Reference dev unit tests / PR — no manual case unless asked.

---

## App Insights KQL (starting points)

Vault — find deactivation publish attempts:

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName has "token" or cloud_RoleName has "vault" or cloud_RoleName has "ach"
| where message has "NocDeactivated" or message has "ReturnDeactivated" or message has "BankToken"
| project timestamp, severityLevel, message, operation_Id
| order by timestamp desc
```

Find false-success pattern (pre-fix baseline):

```kusto
traces
| where timestamp > ago(24h)
| where message has "Successfully published" and message has "NocDeactivated"
| join kind=inner (
    exceptions
    | where timestamp > ago(24h)
    | where outerMessage has "subject" or innermostMessage has "reserved attribute"
) on operation_Id
| project timestamp, operation_Id, message, outerMessage
```

Orchestrator — deactivation handler:

```kusto
traces
| where timestamp > ago(1h)
| where message has "OnAccountDeactivated" or message has "ReturnDeactivations"
| project timestamp, message, operation_Id, cloud_RoleName
| order by timestamp desc
```

---

## Suggested Testmo themes (~8 cases when writing PAY-4011)

1. NOC deactivation — event on accounts SB topic (AC-2).
2. Return deactivation — event on accounts SB topic (AC-2).
3. CloudEvent shape — no reserved `subject` extension (AC-2 spot-check).
4. Orchestrator — `ReturnDeactivations` row after NOC path (AC-2).
5. Orchestrator — return path resolution (AC-2).
6. Vault logs — success path, no exception (AC-2).
7. Vault logs — failed publish surfaces as error, not success (AC-3).
8. Regression — ACH reporting / FR-10 not blank when orchestrator + vault both deployed (optional E2E with Integrations).

---

## Blockers / sync with dev

1. **Exact STAGE vs Dev** env for PAY-4012 (AC-2 says Dev; Jira status In Stage).
2. **Trigger steps** for NOC vs return deactivation in non-local env.
3. **Service Bus queue/topic names** and peek permissions for QA.
4. **Orchestrator deployed?** If not in target env, AC-2 may be SB-only + vault logs until orchestrator is live.

---

## Jira

https://wellfit.atlassian.net/browse/PAY-3811
