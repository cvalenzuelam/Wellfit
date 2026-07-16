# PAY-4072 — E2E Validation Runbook: WFC ACH Information → MaxRedepositAttempts

**Feature:** WF Connect ACH Information Subscriber → ACH Retry Config (`MaxRedepositAttempts`)
**Service under test:** `ach-returns-microservice` (`AchReturns.API`)
**Code:** wellfit-payments PR #328 (`PAY-4072-ach-returns-wfc-ach-retry-config`)
**Companion artifacts:** [`postman/`](./postman/) (collection + DEV/STAGE environments)
**Sibling:** [PAY-4033](../../wf-connect-ach-information-subscriber-ach-transaction-limits/testing/E2E_RUNBOOK.md) consumes the **same** event on the **same** `accounts` topic (writes ACH *limits*). One injection exercises both consumers — see §4.
**Author:** Tony (wellfit-testing-automation)
**Status:** Ready for pre-bridge consumer smoke; full WFC→consumer path is **deploy-blocked** (see §2).

> **Why a runbook, not a Playwright E2E suite?** This feature has **no UI**. It is a headless, event-driven Service Bus consumer that upserts one database column. The company E2E standard (`06_TESTING_STANDARDS/05_E2E_TESTING.md`) is Playwright/browser-flow oriented and does not apply. The end-to-end "user flow" here is *event in → `ReturnConfigurations` row upserted*, validated by injecting an event and inspecting the datastore + telemetry. That is exactly what this runbook drives, and the Postman collection makes the injection + verification repeatable.

---

## 1. What this validates

The complete consumer path for one `WellfitConnect.AchInformation.Created` (or `.Updated`) event:

```
[injected event] → accounts SB topic
    (ach-returns-api subscription; filter sys.Label IN
     ('WellfitConnect.AchInformation.Created','WellfitConnect.AchInformation.Updated'))
      → AchInformationMessageHandler.HandleAsync(AchInformationIntegrationEvent)
          → parse SubMerchantId (string→Guid); read eCheckRetryAttempts (byte?)
          → skip if SubMerchantId invalid / eCheckRetryAttempts null / value outside [0,2]
          → GetBySubMerchantAndProcessorAsync(SubMerchantId, ProcessorId=0)
              → no row  → ReturnConfiguration.Create(...) + AddAsync + SaveChangesAsync   (INSERT)
              → row     → UpdateMaxRedepositAttempts(...) + SaveChangesAsync              (UPDATE)
                          (no-op + skip save when value already equal)
              → [Returns].[ReturnConfigurations].MaxRedepositAttempts written for
                (SubMerchantId, ProcessorId=0 = Worldpay_Card_Not_Present)
```

**Acceptance signals** (happy path):
1. `[Returns].[ReturnConfigurations]` has exactly one row for the test `SubMerchantId` with `ProcessorId = 0` and `MaxRedepositAttempts` matching the injected `ECheckRetryAttempts`.
2. On an insert, `EntityCreated` is set and `EntityUpdated` is `NULL`; on an update, `EntityUpdated` is set to the change time.
3. No message lands on the `ach-returns-api` dead-letter queue.
4. Handler log line `AchInformationMessageHandler - upserted MaxRedepositAttempts=… for SubMerchantId … ProcessorId 0` appears in App Insights.

> **Key behavioral note (differs from PAY-4033): this consumer does NOT dead-letter bad input.** Null `ECheckRetryAttempts`, a malformed `SubMerchantId`, or a value outside `[0,2]` are **logged and skipped** — no row written, no exception, no DLQ. A message only reaches the DLQ if the handler *throws* (a transient DB error, or the multi-replica concurrent-insert race that is rethrown so Service Bus redelivery heals into the update path). So for every skip/poison scenario below, the correct expectation is **DLQ empty**, not "DLQ has a message." This is the opposite of PAY-4033, which uses an ACL that rejects poison to the DLQ.

---

## 2. 🚨 Read first — the deploy blocker (routing mismatch)

**The production WFC→consumer path is NOT wired.** WFC publishes `WellfitConnect.AchInformation.Created` to its **own** Event Grid domain `{env}-wellfitconnect` / domain-topic `ach-information`. This consumer's subscription is fed from the **Payments** `{env}-evgd-payments` domain → `accounts` domain-topic → `accounts` SB topic. There is **no WFC→Payments forwarder today**, so a real WFC onboarding event reaches this consumer **zero times**. Remediation (WFC/platform + Jason) is one of: (1) EG cross-domain forwarder WFC `ach-information` → Payments `accounts`; (2) repoint WFC's `eventGridRouting` to the Payments domain/`accounts`; (3) a dedicated SB topic fed from WFC's domain.

**Consequence for testing:** you cannot validate this by asking WFC to onboard/update a submerchant — the event won't arrive. Instead you **inject** the event onto the Payments side yourself:

- **Method A — direct Service Bus send** to the `accounts` topic (§5). Exercises the subscription filter + consumer + persistence. Does **not** depend on the bridge. **Recommended for consumer validation.**
- **Method B — publish to the Payments `accounts` Event Grid domain** (§6). Exercises the full EG→SB→consumer path and is the closest proxy to what the future WFC→Payments bridge will deliver.

Neither method requires the WFC domain. When the bridge lands, re-run Method B against the real path (publish to the WFC domain) as the final production-parity check.

---

## 3. Prerequisites

### Resource names by env (verified live in `provision-sb-topics.sh:82-87`, 2026-04-21)

| Env | Azure subscription | SB namespace (`sbNamespace`) | SB namespace RG |
|---|---|---|---|
| **dev** | Development | **`dev-sbns-payments-westus3`** (naming outlier) | `dev-rg-plat-core-wus3` |
| qa | QA | `qa-payments-bus` | `qa-platform-core` |
| stage | Staging | `stage-payments-bus` | `stage-platform-core` |
| prod | Production | `prod-payments-bus` | `prod-platform-core` |
| int | Integration | `int-payments-bus` | `int-platform-core` |
| sbox | Sandbox | `sbox-payments-bus` | `sbox-platform-core` |

The `az` examples below use the **dev** values; swap per the table for other envs. The DEV/STAGE Postman environments ship with `sbNamespace` pre-filled to the values above — you still supply the auth key (`sbSharedAccessKey`).

### Access / roles
- **DEV** Azure subscription access (payments EG domain resource group: `core-wus3`; SB namespace RG: `dev-rg-plat-core-wus3`).
- Service Bus **Data Sender** on the `accounts` topic (Method A) — or the topic's shared-access key.
- Event Grid domain **key** for `{env}-evgd-payments` (Method B).
- Read access to the ACH Returns database (verification §7.1) — the DB the `ach-returns-microservice` connects to, `[Returns]` schema.
- App Insights read access for `ach-returns-microservice` (verification §7.3).

### Deployment preconditions — verify, do not create

Everything below is provided by the environment's deployment. This is a **test** runbook: you *verify* these are present, you do **not** provision them. If any check fails, the environment is not correctly deployed — **stop and raise it with DevOps** (see [`../DEVOPS-REQUEST-ach-returns-accounts-subscription.md`](../DEVOPS-REQUEST-ach-returns-accounts-subscription.md)). Do not run provisioning scripts or create Azure resources by hand.

**P1 — the consumer is deployed.** `ach-returns-microservice` is running in the target env with the shipped consumer (`AchInformationMessageHandler` + `AchInformationIntegrationEvent`, `.Updated` mapped in `Program.cs`). Confirmed by a healthy app + the App Insights startup logs.

**P2 — the `ach-returns-api` subscription exists on the `accounts` topic, with the type filter.** This is a deployment-owned Azure resource. Verify (read-only):
```bash
az servicebus topic subscription show \
  --resource-group dev-rg-plat-core-wus3 \
  --namespace-name dev-sbns-payments-westus3 \
  --topic-name accounts \
  --name ach-returns-api \
  --query "{name:name, status:status}" -o table
az servicebus topic subscription rule list \
  --resource-group dev-rg-plat-core-wus3 \
  --namespace-name dev-sbns-payments-westus3 \
  --topic-name accounts --subscription-name ach-returns-api \
  -o table   # expect a SQL rule: sys.Label IN ('WellfitConnect.AchInformation.Created','WellfitConnect.AchInformation.Updated')
```
> **If this returns nothing, the subscription was never provisioned — that is a deployment defect, not a test setup step.** It is **not provisioned in any environment**: no CI/CD pipeline in `wellfit-payments` provisions Service Bus subscriptions, and the `[ServiceBusSubscription]` code attribute is only a runtime *receiver binding* (it does not create the subscription). The subscription must be created by the infra/Terraform pipeline that owns Service Bus, **across all environments** (a fix applied to only one env just moves the failure to the next env on promotion). Stop here and file the DevOps request; do not work around it locally (a hand-created subscription is reconciled away on the next infra apply).

**P3 — the consumer's identity can receive.** `ach-returns-microservice` has **Service Bus Data Receiver** on that subscription (deployment-owned; no action for the tester).

### Tools
- **Postman** (Desktop or CLI/Newman) with the [collection + environment](./postman/) imported.
- **Azure CLI** (`az`) logged in to the target subscription.
- A SQL client (Azure Data Studio / `sqlcmd`) for verification.

---

## 4. Test data

Use **synthetic** `SubMerchantId` GUIDs that do not collide with real submerchant records. Pick a fixed GUID per run so you can query for it deterministically.

| Field (WFC event `data`) | Type | Example | Consumed by PAY-4072? |
|---|---|---|---|
| `SubMerchantId` | string (GUID) | `b2b22222-2222-4222-8222-222222222222` | **Yes** → `ReturnConfigurations.SubMerchantId` |
| `ECheckRetryAttempts` | byte? | `2` | **Yes** → `ReturnConfigurations.MaxRedepositAttempts` (must be 0–2) |
| `ECheckTransactionLimit` | decimal? | `500.00` | No — consumed by PAY-4033 (`AchLimitConfig.PerTransactionLimit`) |
| `ECheckDailyTransactionLimit` | decimal? | `2500.00` | No — consumed by PAY-4033 (`AchLimitConfig.DailyLimit`) |

`ProcessorId` is always `0` (`PaymentProcessor.Worldpay_Card_Not_Present`) — single-processor enrollment, no fan-out.

> **Cross-effect (important):** an injected `WellfitConnect.AchInformation.*` event on `accounts` is **also** picked up by PAY-4033's `submerchant-api` subscription (same topic, overlapping filter) if that consumer is provisioned in the target env. One injection therefore exercises **both** consumers: PAY-4072 writes `ECheckRetryAttempts` → `Returns.ReturnConfigurations.MaxRedepositAttempts`; PAY-4033 writes the two limits → `Payments.AchLimitConfig`. Keep the limit fields present and valid (positive) so you don't trip PAY-4033's poison path, and check both datastores if both consumers are deployed. Use a **distinct synthetic GUID per Jira** if you want to isolate PAY-4072 verification from PAY-4033 noise.

The Postman collection stores the current `SubMerchantId` in the `subMerchantId` environment variable (pre-seeded; change per run).

---

## 5. Method A — Direct Service Bus injection (recommended)

Sends a message straight to the `accounts` topic via the Service Bus REST API, with the SB message `Label` set to the event type so it matches the subscription's `sys.Label` filter. This is the most reliable way to exercise the consumer without depending on Event Grid routing or the missing bridge.

### Message contract
- **Endpoint:** `POST https://{sbNamespace}.servicebus.windows.net/accounts/messages`
- **Auth:** `Authorization: SharedAccessSignature …` — the collection's **collection-level pre-request script** generates this SAS token from `sbSharedAccessKeyName` + `sbSharedAccessKey` (see environment file). No manual token minting needed.
- **Header:** `BrokerProperties: {"Label":"WellfitConnect.AchInformation.Created"}` — this becomes `sys.Label`, which the subscription filter matches. (The production EG→SB forwarder sets this via `delivery_attribute_mappings { Label ← type }`; here we set it directly.)
- **Body:** the CloudEvent envelope the framework's `CloudEventsDeserializer` binds into `AchInformationIntegrationEvent` (from the flat `data` object, case-insensitively):

```json
{
  "id": "{{$guid}}",
  "source": "runbook/pay-4072",
  "specversion": "1.0",
  "type": "WellfitConnect.AchInformation.Created",
  "subject": "AchInformation",
  "time": "{{$isoTimestamp}}",
  "data": {
    "SubMerchantId": "{{subMerchantId}}",
    "ECheckRetryAttempts": 2,
    "ECheckTransactionLimit": 500.00,
    "ECheckDailyTransactionLimit": 2500.00
  }
}
```

> The consumer's `[JsonPropertyName]` values are camelCase (`subMerchantId`, `eCheckRetryAttempts`), but WFC's producer class (`AchInformationEvent`) emits PascalCase and the `CloudEventsDeserializer` binds case-insensitively — so PascalCase (matching the real producer and the PAY-4033 collection) is correct. Only `SubMerchantId` and `ECheckRetryAttempts` are read here; the limit fields are carried so the same injection also drives PAY-4033.

### Steps
1. Select the **PAY-4072 DEV** environment in Postman; set `subMerchantId` to your synthetic GUID.
2. Run **`1. Inject via Service Bus / 1.1 Created (happy path)`**. Expect HTTP `201 Created` from the SB REST API (message accepted onto the topic — this is *not* the consumer's result).
3. Proceed to **§7 Verification**.

> **First-run calibration:** the exact body envelope the `Wellfit.ServiceBus` consumer expects (raw CloudEvent vs a wrapper, and how `data` binds to `AchInformationIntegrationEvent`) is set by the framework version in `ach-returns-microservice`. If §7 shows the message dead-lettering with a deserialization error, capture the DLQ message body (§7.4) and compare it to a message produced by the real forwarder (or by an existing working consumer on `accounts`), then adjust the body shape here. Record the confirmed shape in §9.

---

## 6. Method B — Event Grid domain injection (full path)

Publishes a CloudEvent to the **Payments** `accounts` Event Grid domain. The existing `accounts` EG→SB forwarder then delivers it to the `accounts` SB topic with `Label ← type` mapping, and the consumer picks it up. This proves the EG→SB leg + the consumer together and is the closest proxy to the future WFC→Payments bridge.

- **Endpoint:** `POST https://{egDomainEndpoint}/api/events` where `egDomainEndpoint` = `{env}-evgd-payments.{region}-1.eventgrid.azure.net` (confirm the exact host in the Portal / `provision-eg-subs.sh`).
- **Auth:** header `aeg-sas-key: {{egDomainKey}}`.
- **Body:** a CloudEvents-schema array. For an EG **domain**, routing to the `accounts` domain-topic is by the event `source`/domain-topic per the domain's schema — confirm the exact domain-topic addressing against a known-good publisher to `accounts`. The collection ships a best-known CloudEvents body; treat the domain-topic addressing as a first-run calibration item.

Run **`2. Inject via Event Grid Domain / 2.1 Created (happy path)`**. Expect `200 OK` from Event Grid, then verify via §7.

> When the WFC→Payments bridge lands, add a variant that publishes to the **WFC** domain (`{env}-wellfitconnect` / `ach-information`) to prove the real production path.

---

## 7. Verification

### 7.1 SQL — the source of truth
Run against the ACH Returns database for the target env (Postman cannot run SQL; use a SQL client):

```sql
-- Aggregate row (expect exactly one per SubMerchantId, ProcessorId = 0)
SELECT Id, SubMerchantId, ProcessorId, MaxRedepositAttempts, EntityCreated, EntityUpdated
FROM   [Returns].[ReturnConfigurations]
WHERE  SubMerchantId = 'b2b22222-2222-4222-8222-222222222222'   -- your synthetic GUID
ORDER  BY EntityCreated DESC;
-- Happy-path insert : MaxRedepositAttempts = <injected value>, ProcessorId = 0,
--                     EntityUpdated IS NULL
-- Happy-path update : MaxRedepositAttempts = <new value>, EntityUpdated IS NOT NULL

-- Fan-out guard: exactly one row for this SubMerchantId, always ProcessorId = 0
SELECT ProcessorId, COUNT(*) AS Rows
FROM   [Returns].[ReturnConfigurations]
WHERE  SubMerchantId = 'b2b22222-2222-4222-8222-222222222222'
GROUP  BY ProcessorId;
-- Expect: single row, ProcessorId = 0
```

> There is **no audit-log table** and **no downstream event** for this write (unlike PAY-4033). The row itself plus `EntityCreated`/`EntityUpdated` is the audit trail.

### 7.2 No REST read-back exists
`ReturnConfigurations` is internal reference data with no public read endpoint for `MaxRedepositAttempts`. Verify via SQL (§7.1) and telemetry (§7.3) only. (If a diagnostic endpoint is added later, add a `3.x` request to the collection and note the route in §9.)

### 7.3 App Insights — telemetry
Confirm the handler logged the outcome. The message string discriminates every branch:
```kusto
traces
| where timestamp > ago(30m)
| where message has "AchInformationMessageHandler"
| project timestamp, message, severityLevel
| order by timestamp desc
```
Expected message per scenario:

| Scenario | Log fragment | Severity |
|---|---|---|
| Happy insert/update | `upserted MaxRedepositAttempts=… ProcessorId 0` | Information |
| Redelivery, value unchanged | `already {N} … No change; skipping save` | Debug |
| Null `ECheckRetryAttempts` | `ECheckRetryAttempts is null … Skipping` | Information |
| Out-of-range value | `out of range [0, 2] … Skipping` | Warning |
| Malformed `SubMerchantId` | `invalid SubMerchantId … Skipping` | Warning |
| Concurrent-insert race (multi-replica only) | `concurrent insert race … rethrowing so Service Bus redelivery takes the update path` | Warning |

### 7.4 Dead-letter queue — must be empty for every scenario in §8
```bash
az servicebus topic subscription show \
  --resource-group dev-rg-plat-core-wus3 --namespace-name dev-sbns-payments-westus3 \
  --topic-name accounts --name ach-returns-api \
  --query "countDetails.deadLetterMessageCount"
```
The collection's **`3. Verify / 3.1 Peek DLQ`** peeks dead-lettered messages via SB REST. For **all** scenarios in §8 (happy *and* skip/poison), expect **zero** — this consumer skips bad input rather than dead-lettering it. A non-empty DLQ means either a deserialization failure (adjust §5 body, first-run calibration) or a genuine handler exception (transient DB error / concurrent-insert race) — investigate via §7.3.

---

## 8. Test scenarios

Run each via the correspondingly-numbered Postman request, then verify. **Every scenario expects an empty DLQ.**

| # | Request | Input | Expected consumer behavior | Verify |
|---|---|---|---|---|
| **S1** | 1.1 Created | New GUID, `ECheckRetryAttempts=2` | `Create` path → new row, `MaxRedepositAttempts=2`, `EntityUpdated NULL` | §7.1 row present; §7.3 `upserted`; §7.4 DLQ empty |
| **S2** | 1.2 Updated | Same GUID, `ECheckRetryAttempts=1`, `type=…Updated` | `UpdateMaxRedepositAttempts` → `MaxRedepositAttempts=1`, `EntityUpdated` set | §7.1 value=1, `EntityUpdated` not null; DLQ empty |
| **S3** | 1.1 Created ×2 (idempotency) | Same GUID + same value twice | Second delivery: `UpdateMaxRedepositAttempts` no-ops → save skipped | §7.1 single row unchanged; §7.3 `No change; skipping save`; DLQ empty |
| **S4** | 1.3 Skip — null retry attempts | `ECheckRetryAttempts` omitted/null | Log info + return (skip) — no write | §7.1 **no** PAY-4072 row created/changed; §7.3 `null … Skipping`; DLQ empty |
| **S5** | 1.4 Skip — out of range | `ECheckRetryAttempts=3` | Log warn + return (skip); CHECK constraint never reached | §7.1 no change; §7.3 `out of range`; DLQ empty |
| **S6** | 1.5 Skip — boundary 0 | New GUID, `ECheckRetryAttempts=0` | Valid boundary → `Create` with `MaxRedepositAttempts=0` | §7.1 row with `MaxRedepositAttempts=0`; DLQ empty |
| **S7** | 1.6 Skip — malformed SubMerchantId | `SubMerchantId="not-a-guid"` | Log warn + return (skip) — no write | §7.1 no row for that value; §7.3 `invalid SubMerchantId`; DLQ empty |
| **S8** | 1.7 Non-target event type (filter negative) | `Label="WellfitConnect.SomethingElse.Created"` | Not delivered to `ach-returns-api` (filter excludes it) | No row; not delivered; DLQ empty |

> **Boundary coverage note:** S1 (=2) and S6 (=0) cover the valid `[0,2]` boundaries; S5 (=3) covers the first out-of-range value. `MaxRedepositAttempts=1` is exercised as the update target in S2. The DB `CHK_ReturnConfigurations_MaxAttempts` is never exercised by any path — the handler rejects out-of-range before SQL.

---

## 9. First-run calibration checklist

These items depend on the live framework/infra and must be confirmed the first time this runbook is executed against a real environment. Record confirmed values here and in the memory note.

- [x] Exact SB namespace name per env — resolved from `provision-sb-topics.sh:82-87` (see the resource-names table in §3; dev = `dev-sbns-payments-westus3`). Still confirm the `accounts` topic / namespace auth rule + key.
- [ ] SB message body shape the consumer deserializes (raw CloudEvent vs wrapper; how `data` binds to `AchInformationIntegrationEvent`). See §5 first-run note.
- [ ] `accounts` EG domain endpoint host and the domain-topic addressing for Method B.
- [ ] Subscription filter confirmed as `sys.Label IN (…Created,…Updated)` (assumed) — confirm via the rule list in §3.
- [ ] ACH Returns database name / connection for the §7.1 query (the DB `ach-returns-microservice` targets).
- [ ] Whether PAY-4033 `submerchant-api` is also provisioned on `accounts` in this env (cross-effect §4).
- [ ] `.Updated` actually publishes from WFC (S2 uses a hand-crafted `.Updated` today; the type is mapped to the same handler via `Program.cs`).

---

## 10. Environment safety & cleanup

### DEV is the default target
Prefer DEV. Behavior is identical across envs (config differs, not code) — a STAGE run is a pre-QA parity smoke, not a different code path.

### STAGE / PROD caution
- **Do not inject onto the shared `accounts` topic in PROD.** In STAGE, understand that a `WellfitConnect.AchInformation.*` message also drives **PAY-4033's** `submerchant-api` consumer (writes `AchLimitConfig`). Use synthetic `SubMerchantId`s only, and coordinate with QA.
- Only `ach-returns-api` + `submerchant-api` subscribe to these event types on `accounts` — other `accounts` subscriptions are not hit. Blast radius is limited to the two WFC-ACH consumers.

### Cleanup
```sql
DELETE FROM [Returns].[ReturnConfigurations] WHERE SubMerchantId = '<synthetic-guid>';
-- If PAY-4033 also consumed the event (limits), also clean:
-- DELETE FROM [Payments].[AchLimitConfigAuditLog] WHERE SubMerchantId = '<synthetic-guid>';
-- DELETE FROM [Payments].[AchLimitConfig]         WHERE SubMerchantId = '<synthetic-guid>';
```
The DLQ should be empty throughout; if a deserialization failure put a message there during calibration, purge the `ach-returns-api` DLQ (receive-and-delete, or the Portal SB explorer) so the DLQ alert threshold stays clean.

---

## 11. Appendix — event schema reference

Publisher class (verified on WFC `origin/main`): `wellfit-connect-service/Application/Events/AchInformationEvent.cs`

```csharp
[EventType("WellfitConnect.AchInformation.Created")]
public class AchInformationEvent
{
    public string    SubMerchantId               { get; set; }   // string, not Guid
    public byte?     ECheckRetryAttempts         { get; set; }    // → MaxRedepositAttempts (PAY-4072)
    public decimal?  ECheckTransactionLimit      { get; set; }    // → PerTransactionLimit (PAY-4033)
    public decimal?  ECheckDailyTransactionLimit { get; set; }    // → DailyLimit (PAY-4033)
}
```
- WFC subject on publish: `"AchInformation"` (CloudEvent subject; not the routing topic).
- The publisher defaults unset numeric fields with `?? 0`, so an unconfigured `ECheckRetryAttempts` may arrive as `0`, not null — a valid value here (S6). To exercise the **null-skip** path (S4) you must omit the field entirely, which is why the S4 request drops `ECheckRetryAttempts` rather than sending `0`.
- No `.Updated` companion class exists upstream yet; the consumer handles it identically via the `Program.cs` `ServiceBusRegistrationInfo.MessageTypes["…Updated"] = typeof(AchInformationIntegrationEvent)` mapping (S2 exercises the shape today via a hand-crafted `.Updated` type).

Consumer surface (verified in wellfit-payments PR #328):
- `AchReturns.API/Events/IntegrationEvents/AchInformationIntegrationEvent.cs` — `[ServiceBusSubscription("accounts","ach-returns-api", MessageType="WellfitConnect.AchInformation.Created", RequiresSessions=false)]`
- `AchReturns.API/EventHandlers/AchInformationMessageHandler.cs` — the upsert + skip logic
- `AchReturns.API/Database/Ach/Models/ReturnConfigurations/ReturnConfiguration.cs` — `Create` / `UpdateMaxRedepositAttempts` (returns `bool` did-mutate) / `[0,2]` guard
- `src/database/payments-db/Payments/Tables/Returns/ReturnConfigurations.sql` — `CHK_ReturnConfigurations_MaxAttempts BETWEEN 0 AND 2`, `UQ_ReturnConfigurations_SubMerchant_Processor (SubMerchantId, ProcessorId)`

See [`../solution.md`](../solution.md) §3–§8 for the handler/repository/entity source and the routing/deploy plan, and [`../analysis.md`](../analysis.md) for the verified schema and locked scope.
