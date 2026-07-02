# PAY-3821 — Manual Test Cases

**Ticket:** PAY-3821 · Treasury funding-batch send error handling  
**Environment:** STAGE (Dev/SBOX also valid per spec)  
**Postman:** `postman/collections/PAY-3821-treasury-funding-send.postman_collection.json`  
**Auth:** header `api_key` (Treasury API pattern — not Bearer in STAGE)

**Not in scope for manual cases:** AC-4 (SendGrid send throws) — unit tests PR #283; AC-2 “sent-before exclusion” partial-progress sub-case — unit tests PR #283.

## Test cases

| File | Title |
|------|--------|
| [TC-01.md](./TC-01.md) | Treasury API health endpoint returns Ok |
| [TC-02.md](./TC-02.md) | send-funding-batch with api_key authentication |
| [TC-03.md](./TC-03.md) | Synthetic pending FundingBatches staged in SQL |
| [TC-04.md](./TC-04.md) | Azure SFTP failure + alert recipients |
| [TC-05.md](./TC-05.md) | send-funding-batch enqueues under broken SFTP |
| [TC-06.md](./TC-06.md) | One PAY-3821 alert email lists all unsent batches |
| [TC-07.md](./TC-07.md) | RequestSentTimeStamp remains NULL after failure |
| [TC-08.md](./TC-08.md) | App Insights failure telemetry |
| [TC-09.md](./TC-09.md) | Service healthy after send failure |
| [TC-10.md](./TC-10.md) | SFTP restore + idempotent retry |

## Traceability

| Test case | Primary AC coverage |
|-----------|---------------------|
| TC-01 | Service health (setup) |
| TC-02 | API auth / enqueue |
| TC-03 | Test data / AC-2, AC-3 setup |
| TC-04 | AC-1 trigger + alert setup |
| TC-05 | AC-1, AC-2 trigger |
| TC-06 | AC-1, AC-2 |
| TC-07 | AC-3 |
| TC-08 | AC-1 |
| TC-09 | AC-3 |
| TC-10 | AC-5 |
| AC-4 | Unit tests PR #283 — no manual case |

## Teardown (after all cases)

- Delete synthetic rows: `DELETE FROM Payments.FundingBatches WHERE BatchFileName LIKE 'PAY3821-E2E-%';`
- Restore Azure settings (`sftpurl`, recipients if changed).
- Confirm no pending `PAY3821-E2E-%` rows remain.
