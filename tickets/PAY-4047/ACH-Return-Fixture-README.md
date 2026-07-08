# ACH Return & NOC test-data fixtures (dev reference)

> **STAGE QA:** For Stage (PAY-4047 and similar), use **`PAY-4047-QA-Context.md`** — the Stage trigger is **`stage-wf-payments-func` → `FileProcessedEvent`**, not the local `operations` Event Grid topic below.

Hand-run SQL scripts that **anchor** ACH **returns** and **NOCs** to **existing live ACH
payments** already in a lower environment, then let you fire the existing event so all
downstream processing runs the real code path. No charge is created and no anchor is
invented — every fixture references a real, settled `'000'` ACH payment. They exercise:

- the Account Updater orchestrator in `payments-func` (`OnNocUpdateReportIngested`, `OnAccountDeactivated`) — **PAY-3790**, in Dev
- the ACH Returns microservice (`ReturnReportIngestedMessageHandler`)

These are **scripts, not deployable objects** — nothing here is in any `.sqlproj`, nothing
deploys to any environment, and there are no stored procedures. A QA engineer opens the file,
sets the inputs at the top, and runs it (sqlcmd / SSMS / Azure Data Studio). Intended for
**local dev and lower environments only** — never run against production data.

## Scripts in this repo

| Script | Path | DB |
|--------|------|-----|
| `inject-ach-return.sql` | `tickets/PAY-4047/scripts/inject-ach-return.sql` | **Platform** |

Other scripts (`inject-ach-noc.sql`, batch variants) — obtain from dev when needed.

| Script (dev) | DB | What it seeds |
|---|---|---|
| `inject-ach-noc.sql` | **STEP 1 Platform → STEP 2 Payments** | one claimable `[AccountUpdater].[AchNOCs]` row (`Status = NULL`), anchored to an existing live `'000'` payment |
| `inject-ach-return-batch.sql` | **Platform** | up to `@Count` pending returns anchored to existing payments (set-based, no charges) |

> **Anchor to existing live payments.** Nothing here creates a `Payments.Payments` charge.
> The fixtures reference real, settled `'000'` ACH payments that already exist in the target
> env.
>
> **Returns** are single-DB: the anchor lives in **Platform** alongside `ReturnedPayments`,
> so each return script auto-selects the anchor and inserts in one connection.
>
> **Anchor guard:** the picker only selects payments whose `TransactionId` is `<= 20` chars,
> because `ReturnedPayments.ProcessorTransactionId` is `nvarchar(20)` (a longer
> `TransactionId` would silently fail the match). Returns also need eligible **un-returned**
> `'000'` payments to exist in the target env.

## How to run (local / generic)

1. Open the script, edit the `DECLARE` inputs at the top (R-code, amount, `@PaymentId`, …).
2. Run with `@Commit = 0` (default) first — it **previews** the rows, then **rolls back**.
3. Set `@Commit = 1` and run again to persist.
4. POST the trigger event (see **Events to POST** below). **Returns:** deliver within **5 minutes** of the SQL insert.

> **Rollback caveat:** `@Commit = 0` only unwinds the *seed*. Once you deliver the event and
> the handler processes the rows, downstream writes do **not** unwind.

## Events to POST (local dev)

### Returns — `Payment.ReturnReport.Ingested` (local only)

POST to the `operations` Event Grid topic. Locally that is the `eventgrid-bridge`:
`POST http://localhost:6500/topics/operations/api/events` — header `Content-Type: application/json` only.

**STAGE uses `FileProcessedEvent` instead** — see `PAY-4047-QA-Context.md`.

```json
{
  "specversion": "1.0",
  "type": "Payment.ReturnReport.Ingested",
  "source": "qa/fixture/ach-return",
  "id": "<new-guid>",
  "subject": "Payment.ReturnReport.Ingested",
  "time": "<utc-iso8601>",
  "datacontenttype": "application/json",
  "data": {
    "eventId": "<new-guid>",
    "fileName": "ECheckReturnReport_QAFIX_<yyyymmdd>.CSV",
    "recordCount": 1,
    "processedAt": "<utc-iso8601, set to now>"
  }
}
```

### NOC — `Account.NocUpdateReport.Ingested`

POST to the Function App's Event Grid webhook:
`POST http://localhost:7071/runtime/webhooks/EventGrid?functionName=OnNocUpdateReportIngested`
— header `aeg-event-type: Notification`. **No time window** for NOCs.
