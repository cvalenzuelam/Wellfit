# PAY-4033 — E2E Validation Runbook: WFC ACH Information Subscriber

**Feature:** WF Connect ACH Information Subscriber → ACH Transaction Limits
**Service under test:** `submerchant-microservice` (`Submerchant.API`) — first Service Bus consumer in this service
**Code:** wellfit-payments PR #325 (`PAY-4033-wfc-ach-information-subscriber`)
**Companion artifacts:** [`postman/`](./postman/) (collection + DEV/STAGE environments)
**Author:** Tony (wellfit-testing-automation)
**Status:** Ready for pre-bridge consumer smoke; full WFC→consumer path is **deploy-blocked** (see §2).

> **Why a runbook, not a Playwright E2E suite?** This feature has **no UI**. It is a headless, event-driven Service Bus consumer that upserts a database aggregate. The company E2E standard (`06_TESTING_STANDARDS/05_E2E_TESTING.md`) is Playwright/browser-flow oriented and does not apply. The end-to-end "user flow" here is *event in → aggregate upserted → audit row written → downstream event emitted*, validated by injecting an event and inspecting the datastore + telemetry. That is exactly what this runbook drives, and the Postman collection makes the injection + verification repeatable.

---

## 1. What this validates

The complete consumer path for one `WellfitConnect.AchInformation.*` event:

```
[injected event] → accounts SB topic (submerchant-api subscription, filter sys.Label LIKE 'WellfitConnect.AchInformation.%')
    → WfcAchInformationSubscriber.Handle(PaymentsEvent)
        → WellfitConnectAchInformationAcl.Translate  (string→Guid, rename limits, stamp identity, reject poison)
            → UpsertAchLimitConfigFromWfcHandler      (Create or UpdateLimits on SubMerchantId key)
                → Payments.AchLimitConfig row upserted (PerTransactionLimit, DailyLimit, LastModifiedBy)
                → Payments.AchLimitConfigAuditLog row written
                → AchLimitConfigChangedEvent published (post-commit, WP-MAX parity)
```

**Acceptance signals** (all must hold for the happy path):
1. `Payments.AchLimitConfig` has a row for the test `SubMerchantId` with `PerTransactionLimit` / `DailyLimit` matching the injected payload.
2. `LastModifiedBy = 'system:wfc-ach-information-subscriber'`.
3. A new `Payments.AchLimitConfigAuditLog` row exists for the write.
4. No message lands on the `submerchant-api` dead-letter queue.
5. Handler log line `Upserted AchLimitConfig from WFC AchInformation event: SubMerchantId=…` appears in App Insights.

---

## 2. 🚨 Read first — the deploy blocker (routing mismatch)

**The production WFC→consumer path is NOT wired.** WFC publishes `WellfitConnect.AchInformation.Created` to its **own** Event Grid domain `{env}-wellfitconnect` / domain-topic `ach-information`. This consumer's subscription is fed from the **Payments** `{env}-evgd-payments` domain → `accounts` domain-topic → `accounts` SB topic. There is **no WFC→Payments forwarder today**, so a real WFC onboarding event reaches this consumer **zero times**. Remediation (WFC/platform + Jason) is one of: (1) EG cross-domain forwarder WFC `ach-information` → Payments `accounts`; (2) repoint WFC's `eventGridRouting` to the Payments domain/`accounts`; (3) a dedicated SB topic fed from WFC's domain.

**Consequence for testing:** you cannot validate this by asking WFC to onboard a submerchant — the event won't arrive. Instead you **inject** the event onto the Payments side yourself:

- **Method A — direct Service Bus send** to the `accounts` topic (§5). Exercises the subscription filter + consumer + persistence. Does **not** depend on the bridge. **Recommended for consumer validation.**
- **Method B — publish to the Payments `accounts` Event Grid domain** (§6). Exercises the full EG→SB→consumer path and is the closest proxy to what the future WFC→Payments bridge will deliver.

Neither method requires the WFC domain. When the bridge lands, re-run Method B against the real path (publish to the WFC domain) as the final production-parity check.

---

## 3. Prerequisites

### Access / roles
- **DEV** Azure subscription access (payments EG domain resource group: `core-wus3`).
- Service Bus **Data Sender** on the `accounts` topic (Method A) — or the topic's shared-access key.
- Event Grid domain **key** for `{env}-evgd-payments` (Method B).
- Read access to the Payments SQL database (verification §7.1).
- App Insights read access for `submerchant-microservice` (verification §7.3).

### The consumer must be running and provisioned
1. `submerchant-microservice` deployed with the PR #325 consumer wired (`Wellfit.ServiceBus`, ACL, handler, subscriber). In DEV this can be a local run or the deployed dev instance.
2. The `submerchant-api` subscription **exists on the `accounts` SB topic**. **DEV state (verified 2026-07-14):** subscription is **Active**; its filter rule `wf-typefilter` is currently the **stale single-type** `sys.Label IN ('WellfitConnect.AchInformation.Created')`. Consequence: `1.1 Created` is delivered; **`1.2 Updated` is dropped at the filter** until the rule is reconciled.
   - **Root cause:** the source of truth is the TOPOLOGY line in `wellfit-payments/src/functions/payments-func/scripts/servicebus-topics/provision-sb-topics.sh:130`. **PR #325 already updated it** to the dual-type comma IN-list `"accounts|submerchant-api|WellfitConnect.AchInformation.Created,WellfitConnect.AchInformation.Updated"` (D14 intent — both create + update; note it is a two-value `IN` list, not the `%` `LIKE` wildcard the solution doc described). The live DEV rule is stale because **`provision-sb-topics.sh dev` has not been re-run since the merge** — this is a provisioning gap, not a code gap.
   - **Canonical fix (preferred):** run `./provision-sb-topics.sh dev` from wellfit-payments — it reconciles the rule to `sys.Label IN ('WellfitConnect.AchInformation.Created','WellfitConnect.AchInformation.Updated')`.
   - **Manual quick fix (matches the script's form; use only if you can't run the script):**
     ```bash
     az servicebus topic subscription rule delete --resource-group dev-rg-plat-core-wus3 \
       --namespace-name dev-sbns-payments-westus3 --topic-name accounts \
       --subscription-name submerchant-api --name wf-typefilter
     az servicebus topic subscription rule create --resource-group dev-rg-plat-core-wus3 \
       --namespace-name dev-sbns-payments-westus3 --topic-name accounts \
       --subscription-name submerchant-api --name wf-typefilter \
       --filter-sql-expression "sys.Label IN ('WellfitConnect.AchInformation.Created','WellfitConnect.AchInformation.Updated')"
     ```
   Confirm the current rule with:
   ```bash
   # DEV values shown; per-env SB namespaces: dev=dev-sbns-payments-westus3 (RG dev-rg-plat-core-wus3),
   # qa=qa-payments-bus, stage=stage-payments-bus, prod=prod-payments-bus
   az servicebus topic subscription show \
     --resource-group dev-rg-plat-core-wus3 \
     --namespace-name dev-sbns-payments-westus3 \
     --topic-name accounts \
     --name submerchant-api \
     --query "{name:name, status:status}" -o table
   az servicebus topic subscription rule list \
     --resource-group dev-rg-plat-core-wus3 \
     --namespace-name dev-sbns-payments-westus3 \
     --topic-name accounts --subscription-name submerchant-api \
     -o table   # expect a correlation/SQL filter matching WellfitConnect.AchInformation.%
   ```
3. `submerchant-microservice` managed identity has **Service Bus Data Receiver** on the subscription.

### Get a valid submerchant id FIRST (required before any injection)
The consumer guards parent existence — an event for a submerchant that doesn't exist dead-letters (`SubMerchant not found`). So **before injecting, obtain and verify a real DEV `SubMerchantId`:**

1. **Get a candidate id** (no list endpoint exists):
   - Ask the submerchant team, or read `[Payments].[SubMerchant]`, **or**
   - Mine App Insights request telemetry for ids other callers have hit:
     ```kusto
     requests
     | where timestamp > ago(30d) and cloud_RoleName == 'Submerchant.API'
     | where url has '/api/submerchants/' and resultCode == 200
     | project url | take 10
     ```
2. **Verify it exists** before using it — `GET /api/submerchants/{id}` must return **`200`** (a `204 No Content` means it does NOT exist; do not use it):
   run `0.1 Get token` → `3.1 GET SubMerchant by id`, or the `.http`/curl equivalent.
3. Put the confirmed id in the `subMerchantId` env var. (The DEV env ships defaulted to `ff890000-523e-7c1e-19da-08dee1257f0c`, verified to exist 2026-07-14 — re-verify with step 2 as records change.)

> Skipping this is the most common test failure: injecting for a synthetic/unknown id → the message dead-letters and you chase a "bug" that is just missing test data.

### Tools
- **Postman** (Desktop or CLI/Newman) with the [collection + environment](./postman/) imported.
- **Azure CLI** (`az`) logged in to the target subscription.
- A SQL client (Azure Data Studio / `sqlcmd`) for verification.

---

## 4. Test data

> ✅ **VALIDATED live in DEV 2026-07-14** — happy path confirmed end-to-end against a real submerchant (`ff890000-523e-7c1e-19da-08dee1257f0c`): SB inject → filter → consumer → **Create** → `AchLimitConfig` persisted (perTx=500, daily=2500) → downstream `SubMerchant.AchLimitConfig.Updated` published → merchant-provisioning consumed it. No dead-letter.

> 🚩 **The `SubMerchantId` MUST be a real, existing submerchant — NOT an arbitrary synthetic GUID.** The deployed consumer looks up the parent SubMerchant first; if it doesn't exist it logs `SubMerchant {id} not found for WFC AchInformation upsert`, retries to max-delivery, then **dead-letters**. (This is doc drift: `solution.md` §3.5 shows a plain `Create`/`UpdateLimits` with no parent check; the shipped code guards parent existence.) Operational consequence: a WFC event for a not-yet-provisioned submerchant dead-letters — submerchant provisioning must precede its AchInformation event.
>
> **Getting a real DEV submerchant id:** there is no list endpoint. Options: (a) ask the submerchant team / read `[Payments].[SubMerchant]`; (b) mine App Insights request telemetry — `requests | where cloud_RoleName=='Submerchant.API' | where url has '/api/submerchants/' and resultCode==200 | project url` yields real ids other callers have hit (how the `ff890000-…` id above was found).

| Field (WFC event `data`) | Type | Example | Maps to `AchLimitConfig` |
|---|---|---|---|
| `SubMerchantId` | string (GUID) | `a1a11111-1111-4111-8111-111111111111` | `SubMerchantId` (Guid) |
| `ECheckTransactionLimit` | decimal? | `500.00` | `PerTransactionLimit` |
| `ECheckDailyTransactionLimit` | decimal? | `2500.00` | `DailyLimit` |
| `ECheckRetryAttempts` | byte? | `2` | **ignored by PAY-4033** (consumed by PAY-4072 → ach-returns) |

> **Cross-effect (important):** an injected `WellfitConnect.AchInformation.*` event on `accounts` is **also** picked up by PAY-4072's `ach-returns-api` subscription (same topic, same `%` filter) once that is provisioned. One injection therefore exercises **both** consumers: PAY-4033 writes the two limits into `Payments.AchLimitConfig`; PAY-4072 writes `Returns.ReturnConfigurations.MaxRedepositAttempts` from `ECheckRetryAttempts`. Set `ECheckRetryAttempts` to a valid `0–2` value so PAY-4072 does not log-and-skip, and check both datastores if both consumers are deployed in the target env.

The Postman collection stores the current `SubMerchantId` in the `subMerchantId` environment variable (pre-seeded; change per run).

---

## 5. Method A — Direct Service Bus injection (recommended)

Sends a message straight to the `accounts` topic via the Service Bus REST API, with the SB message `Label` set to the event type so it matches the subscription's `sys.Label` filter. This is the most reliable way to exercise the consumer without depending on Event Grid routing or the missing bridge.

### Message contract
- **Endpoint:** `POST https://{sbNamespace}.servicebus.windows.net/accounts/messages`
- **Auth:** `Authorization: SharedAccessSignature …` — the collection's **collection-level pre-request script** generates this SAS token from `sbSharedAccessKeyName` + `sbSharedAccessKey` (see environment file). No manual token minting needed.
- **Header:** `BrokerProperties: {"Label":"WellfitConnect.AchInformation.Created"}` — this becomes `sys.Label`, which the subscription filter matches. (The production EG→SB forwarder sets this via `delivery_attribute_mappings { Subject ← type }`; here we set it directly.)
- **Body:** the CloudEvent envelope the framework deserializes into `PaymentsEvent` (`type`→`EventName`, `data`→`EventData`):

```json
{
  "id": "{{$guid}}",
  "source": "runbook/pay-4033",
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

### Steps
1. Select the **PAY-4033 DEV** environment in Postman; set `subMerchantId` to your synthetic GUID.
2. Run **`1. Inject via Service Bus / 1.1 Created (happy path)`**. Expect HTTP `201 Created` from the SB REST API (message accepted onto the topic — this is *not* the consumer's result).
3. Proceed to **§7 Verification**.

> **Envelope CONFIRMED (2026-07-14)** ✅ — a live DLQ peek on the `accounts` / `submerchant-api` subscription showed the real EG→SB message is a CloudEvent (`{specversion, type, source, id, time, data}`) with the SB `Label` (BrokerProperties.Label) set to the CloudEvent `type`. That is exactly what this request sends (body = CloudEvent, `Label` header = type). No body-shape recalibration is needed. Example real envelope observed: `{"specversion":"1.0","type":"SubMerchant.AchLimitConfig.Updated","source":".../domains/dev-evgd-payments/topics/accounts","id":"probe-004","time":"…","data":{}}`.

---

## 6. Method B — Event Grid domain injection (full path)

Publishes a CloudEvent to the **Payments** `accounts` Event Grid domain. The existing `accounts` EG→SB forwarder then delivers it to the `accounts` SB topic with `Subject ← type` mapping, and the consumer picks it up. This proves the EG→SB leg + the consumer together and is the closest proxy to the future WFC→Payments bridge.

> ✅ **VALIDATED live in DEV 2026-07-14** — published a CloudEvent (`source: "accounts"`, distinct limits 600/2600) to the domain; read-back confirmed `achLimits: { perTransactionLimit: 600, dailyLimit: 2600 }` persisted, DLQ unchanged. Full EG→SB→consumer path works.

- **Endpoint (DEV, confirmed):** `POST https://dev-evgd-payments.westus3-1.eventgrid.azure.net/api/events` (domain `inputSchema = CloudEventSchemaV1_0`). Per-env host = `{env}-evgd-payments.{region}-1.eventgrid.azure.net` (RG `dev-rg-plat-core-wus3`).
- **Auth:** header `aeg-sas-key: {{egDomainKey}}` (get via `az eventgrid domain key list --name dev-evgd-payments --resource-group dev-rg-plat-core-wus3`).
- **Body:** a CloudEvents-schema array. **The domain-topic is selected by the CloudEvent `source` field — set `source: "accounts"`** (confirmed 2026-07-14; the domain has topics `payments`/`accounts`/`operations`). The forwarder maps `type → sys.Label`, which matches the subscription filter. Content-Type `application/cloudevents-batch+json`.

Run **`2. Inject via Event Grid Domain / 2.1 Created (happy path)`**. Expect `200 OK` from Event Grid, then verify via §7.

> When the WFC→Payments bridge lands, add a variant that publishes to the **WFC** domain (`{env}-wellfitconnect` / `ach-information`) to prove the real production path.

---

## 7. Verification

### 7.1 SQL — the source of truth
Run against the Payments database for the target env (Postman cannot run SQL; use a SQL client):

```sql
-- Aggregate row
SELECT SubMerchantId, PerTransactionLimit, DailyLimit, LastModifiedBy, LastModifiedUtc
FROM   [Payments].[AchLimitConfig]
WHERE  SubMerchantId = 'a1a11111-1111-4111-8111-111111111111';   -- your synthetic GUID
-- Expect: PerTransactionLimit=500.00, DailyLimit=2500.00,
--         LastModifiedBy='system:wfc-ach-information-subscriber'

-- Audit trail (one row per applied write)
SELECT TOP 20 *
FROM   [Payments].[AchLimitConfigAuditLog]
WHERE  SubMerchantId = 'a1a11111-1111-4111-8111-111111111111'
ORDER  BY [LastModifiedUtc] DESC;   -- adjust column name to the actual audit timestamp
```

### 7.2 REST read-back — via GET submerchant-by-id (verified 2026-07-14)
There is no dedicated `GET .../ach-limits` (ach-limits is **PUT-only**, policy `ach-limits-admin`), **but** `GET /api/submerchants/{id}` (scope `WellfitSubMerchantAPI.Read`) returns the submerchant **including its ACH limits** (`AchLimitsDto` in the `SubmerchantLookup/GetById` response). So for a real submerchant you can read the persisted limits back over REST — the collection's `3.1` does this (returns `200` with `achLimits.perTransactionLimit` / `achLimits.dailyLimit` for a real id; **`204 No Content`** for an unknown id, since `GetById` returns null). Verified 2026-07-14: the real submerchant returned `achLimits: { perTransactionLimit: 500, dailyLimit: 2500 }`. SQL (§7.1) remains the authoritative check.

**SubMerchant API clients (DEV; secrets are the in-repo dev test creds):**
| Purpose | client_id | secret (dev) | scope | token endpoint |
|---|---|---|---|---|
| SubMerchant read / auth smoke | `WellfitPaymentsV2API` | `Test123!` | `WellfitSubMerchantAPI.Read` | `https://dev-platform.wellfit.com/identity/connect/token` |
| ACH-limits admin (the PUT write path, D8) | `WellfitUnifiedPaymentsAPI` | `Testing123!!W3llf1t1!` (per-env) | `WellfitSubMerchantAPI.AchLimitsAdmin` | same |

The env files default `clientId`/`scope` to the read client; the ach-limits-admin client is in `achLimitsAdminClientId`/`Secret`/`Scope` for driving the REST PUT if you want to exercise that path as a separate cross-check (it writes `AchLimitConfig` directly — not the SB consumer).

### 7.3 App Insights — telemetry (real log strings, verified 2026-07-14)
App Insights component AppId `79a7536e-dce8-4e75-bea9-7d602e8e9851` (`cloud_RoleName == 'Submerchant.API'`). Success emits this sequence:
```kusto
traces
| where timestamp > ago(30m) and cloud_RoleName == 'Submerchant.API'
| where message has "ACH limit config" or message has "AchLimitConfigChanged" or message has "<your-submerchant-id>"
| project timestamp, message, severityLevel
| order by timestamp desc
```
Expected on success (Create path):
- `Creating ACH limit config from WFC AchInformation event for sub-merchant {id}: perTx=500, daily=2500`
- `ACH limit config upserted from WFC AchInformation event for sub-merchant {id}`
- `Published AchLimitConfigChanged: EventType=SubMerchant.AchLimitConfig.Updated Subject=submerchant.{id} ... NewPerTx=500 NewDaily=2500 MaxChanged=False`

On a missing submerchant (poison): `SubMerchant {id} not found for WFC AchInformation upsert — message will be retried then dead-lettered` (severity Warning) followed by exceptions, then DLQ.

### 7.4 Dead-letter queue — check the *delta*, not the absolute count
> **DEV baseline (verified 2026-07-14):** the `submerchant-api` DLQ already holds **101 stale `probe-*` messages** (CloudEvent probes with empty `data`, `type=SubMerchant.AchLimitConfig.Updated`, enqueued 2026-05-28) — unrelated to WFC/PAY-4033 and not consumer failures. **Record the starting DLQ count before injecting**, and treat "happy path OK" as *count did not increase* and "poison OK" as *count increased by exactly one*. Purge the stale probes first (see §10) if you want a clean zero baseline.
```bash
az servicebus topic subscription show \
  --resource-group dev-rg-plat-core-wus3 --namespace-name dev-sbns-payments-westus3 \
  --topic-name accounts --name submerchant-api \
  --query "countDetails.deadLetterMessageCount"
```
> 💡 **Easier: watch the DLQ from the Azure Portal.** In practice it's simpler to monitor live from the subscription page: Portal → Service Bus namespace `dev-sbns-payments-westus3` → Topics → `accounts` → Subscriptions → `submerchant-api`. The overview shows **Active** and **Dead-letter message count** (refresh after each inject), and **Service Bus Explorer** on that subscription lets you peek/inspect the dead-lettered messages (body + DeadLetterReason) and receive-and-delete them without any CLI/SAS. Use the `az` count above or the collection's **`3.2 Peek DLQ`** when you want it scripted/automated; use the Portal for quick interactive monitoring.

The collection's **`3. Verify / 3.2 Peek DLQ`** peeks dead-lettered messages via SB REST. For **poison scenarios (§8)** you *expect* the DLQ count to rise by one; for the happy path you expect no change.

### 7.5 Downstream event (optional)
After a successful upsert the consumer publishes `AchLimitConfigChangedEvent` (WP-MAX parity with the REST path). If you have a subscriber/trace on that event in the target env, confirm it fired once per successful apply.

---

## 8. Test scenarios

Run each via the correspondingly-numbered Postman request, then verify.

| # | Request | Input | Expected consumer behavior | Verify |
|---|---|---|---|---|
| **S1** | 1.1 / 2.1 Created | **Existing** submerchant id, `500.00` / `2500.00` | `Create` path → new row | §7.1/§7.2 limits present; §7.3 upsert+published logs; DLQ delta 0 |
| **S1b** | 1.1 Created, synthetic/unknown id | GUID with no SubMerchant record | "SubMerchant not found" → retry → **dead-letter** (verified 2026-07-14) | DLQ delta +1; no row |
| **S2** | 1.2 Updated | Same GUID, `750.00` / `3000.00`, `type=…Updated` | `UpdateLimits` path → row mutated. **DEV: requires broadening the filter to `%` first (§3) — otherwise dropped at the filter, never delivered.** | §7.1 limits updated; new audit row; DLQ delta 0 |
| **S3** | 1.1 Created ×2 (idempotency) | Same GUID + same payload twice | Second is upsert-update; converges | §7.1 single row, expected values; DLQ empty |
| **S4** | 1.3 Poison — bad GUID | `SubMerchantId="not-a-guid"` | ACL throws `InvalidWfcAchInformationException` → `Reject` | §7.4 message on DLQ; **no** row written |
| **S5** | 1.4 Poison — null limits | limits omitted/null | ACL throws → `Reject` | §7.4 DLQ; no row |
| **S6** | 1.5 Negative limit | `ECheckTransactionLimit=-1` | ACL rejects negative (MN-1 fix) → `Reject` | §7.4 DLQ; no row |
| **S7** | 1.6 Non-target type | `type="WellfitConnect.SomethingElse.Created"` | **Method B:** filtered out (never delivered). **Method A direct:** if Label doesn't match `WellfitConnect.AchInformation.%` it never reaches the sub; if forced, consumer logs "Unknown event type" → `Reject` | No row; (B) not delivered; (A) DLQ or filtered |

> **S4–S6 blast radius:** poison messages dead-letter on the `submerchant-api` subscription. Purge the DLQ afterward (§10) so the DLQ alert threshold stays clean.

---

## 9. First-run calibration checklist

These items depend on the live framework/infra and must be confirmed the first time this runbook is executed against a real environment. Record confirmed values here and in the memory note.

- [x] SB namespace per env — **resolved:** dev=`dev-sbns-payments-westus3` (RG `dev-rg-plat-core-wus3`), qa=`qa-payments-bus`, stage=`stage-payments-bus`, prod=`prod-payments-bus`. Still confirm the `accounts` topic auth rule name/key (Send + Listen). Precedent: the PAY-3507/PAY-3508 live-SB-injection runbooks (`03_Features/transaction-limit-compliance-alerts/05_Testing/`) drive the same direct-send technique against the `payments` topic.
- [x] SB message body shape — **resolved 2026-07-14** via DLQ peek: CloudEvent body + `Label`=`type`. See §5.
- [x] `accounts` EG domain endpoint + addressing — **resolved 2026-07-14:** `dev-evgd-payments.westus3-1.eventgrid.azure.net`, CloudEvents schema, domain-topic selected via `source: "accounts"`. Validated end-to-end (see §6).
- [x] Subscription filter is `sys.Label` — **confirmed 2026-07-14** (rule `wf-typefilter`). Note it is currently exact-match `.Created` in DEV, not the broadened `%` (see §3).
- [x] SubMerchant API ACH-limits route/client — **resolved 2026-07-14:** ach-limits is PUT-only (no GET); read client `WellfitPaymentsV2API`/`Test123!`/`WellfitSubMerchantAPI.Read`, ach-limits-admin client `WellfitUnifiedPaymentsAPI`/`Testing123!!W3llf1t1!`(dev)/`WellfitSubMerchantAPI.AchLimitsAdmin`. Upsert verified via SQL, not REST. See §7.2.
- [ ] Audit-log timestamp/column names for the §7.1 query.
- [ ] Whether PAY-4072 `ach-returns-api` is also provisioned on `accounts` in this env (cross-effect §4).

---

## 10. Environment safety & cleanup

### DEV is the default target
Prefer DEV. Behavior is identical across envs (config differs, not code) — a STAGE run is a pre-QA parity smoke, not a different code path.

### STAGE / PROD caution
- **Do not inject onto the shared `accounts` topic in PROD.** In STAGE, understand that a `WellfitConnect.AchInformation.*` message also drives **PAY-4072's** `ach-returns-api` consumer (writes `ReturnConfigurations`). Use synthetic `SubMerchantId`s only, and coordinate with QA.
- The `%` Label filter means only `submerchant-api` + `ach-returns-api` receive these events — other `accounts` subscriptions (e.g. `merchant-provisioning-api` on `SubMerchant.AchLimitConfig.Updated`) are not hit. Blast radius is limited to the two WFC-ACH consumers.

### Cleanup
```sql
DELETE FROM [Payments].[AchLimitConfigAuditLog] WHERE SubMerchantId = '<synthetic-guid>';
DELETE FROM [Payments].[AchLimitConfig]         WHERE SubMerchantId = '<synthetic-guid>';
-- If PAY-4072 also consumed the event:
-- DELETE FROM [Returns].[ReturnConfigurations] WHERE SubMerchantId = '<synthetic-guid>';
```
Purge the `submerchant-api` DLQ after poison scenarios (receive-and-delete the dead-lettered messages, or use the SB explorer in the Portal).

---

## 11. Appendix — event schema reference

Publisher class (verified on WFC `origin/main`): `wellfit-connect-service/Application/Events/AchInformationEvent.cs`

```csharp
[EventType("WellfitConnect.AchInformation.Created")]
public class AchInformationEvent
{
    public string    SubMerchantId               { get; set; }   // string, not Guid
    public byte?     ECheckRetryAttempts         { get; set; }    // PAY-4072 (ignored by PAY-4033)
    public decimal?  ECheckTransactionLimit      { get; set; }    // → PerTransactionLimit
    public decimal?  ECheckDailyTransactionLimit { get; set; }    // → DailyLimit
}
```
- WFC subject on publish: `"AchInformation"` (CloudEvent subject; not the routing topic).
- The publisher defaults unset limits with `?? 0`, so an unconfigured limit arrives as `0`, not null. `0`-vs-null enforcement semantics are a deferred product question (not tested here — nothing enforces ACH limits in prod yet).
- No `.Updated` companion class exists upstream yet; the consumer handles it identically when WFC ships it (S2 exercises the shape today via a hand-crafted `.Updated` type).

See [`../solution.md`](../solution.md) §3.4–§3.6 for the ACL/handler/subscriber source, and [`../analysis.md`](../analysis.md) §2.3 for the verified schema.
