# Release 9.6 — STAGE regression context (QA)

Last updated: 2026-07-22 (Chris + Cursor)

## Postman (canonical)

Import **only** `Regression-STAGE/`:

| File | Postman name |
|------|----------------|
| `Regression-STAGE.postman_collection.json` | **Regression - STAGE** |
| `Regression-STAGE.postman_environment.json` | **Regression STAGE** |

Modules inside collection: **CNP** · **TokenVault**.

Old split collections live in `docs/archives/9.6-postman-backups/` — do not import those for day-to-day runs.

## Status snapshot

### CNP (~complete)

- Happy path brands + negatives exercised on STAGE.
- Tokens: numeric `TokenVault.dbo.PaymentTokens` (not `WPAC*`).
- CVV negative: token rail often ignores CVV → use Confluence Amex PAN via Pay Page / documented path.
- Pay Page var: use `paypageRegistrationId` (not empty `{{payPageRegistrationId}}`).
- Cards: `cnp/CNP-STAGE-vantiv-test-cards.md`.

### TokenVault (in progress)

| TC | Notes |
|----|--------|
| 01–04 | Runnable; SQL Visualize in collection (Platform / TokenVault) |
| 05–07, 13 | **PARKED** — need QA lead + physical CP lane (`cardToken`); simulator 9999 not enough |
| 08 | `add-token` may return **Returned existing token.** (idempotent by `processorToken`) — still PASS; Testmo 167997 was empty → fill from scaffolded case |
| 09–12 | V2 charges; SQL helpers in collection |
| Infra | `stage-wf-tokenvault-api` / platform `/tokenvault` can return **403 Site Disabled** when App Service stopped → Start in Azure, retry |

**SQL DBs**

- Platform → `[Payments].[Payments]` (`PaymentTypeMethod`: 1 Pay Page, 2 CNP token, 5 CP)
- TokenVault → `dbo.PaymentTokens` (not Platform `Payments.PaymentTokens`)

**ADS tip:** use **Run**, not Estimated Plan (`SHOWPLAN permission denied` is not a query failure).

## Hosts / auth (STAGE)

- Payments: `https://stage-platform.wellfit.com/payments`
- TokenVault: `https://stage-platform.wellfit.com/tokenvault` (backend `stage-wf-tokenvault-api`)
- Client: `WellfitUnifiedPaymentsAPI` (Payments + TokenVault Read/Write)

## Related tickets (recent)

- PAY-4104 / PAY-4149 — NOC publish vs vault consume (separate from 9.6 CNP/TokenVault folder)
- PAY-4087 — ACH eCheck tokenId (closed PASS)

## Resume next session

1. Re-import `Regression-STAGE/` if Postman is stale.
2. Env **Regression STAGE** → TokenVault `00. Auth` → continue TC09–TC12 SQL + any open TokenVault steps.
3. CP TokenVault cases wait on lead lane.
