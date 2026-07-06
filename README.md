# Wellfit QA workspace

Personal QA notes, runbooks, Postman collections, and Cursor rules for Wellfit payments work.

## Folder layout

```
Wellfit/
├── .cursor/rules/          # Cursor QA rules
├── postman/
│   ├── collections/        # Postman collections (.json)
│   └── environments/       # Postman environments (.json) — may contain secrets
├── tickets/                # Jira exports, runbooks, and QA docs by ticket
│   ├── PAY-3508/
│   ├── PAY-3509/
│   ├── PAY-3605/           # Unmatched settlement transaction alerts
│   ├── PAY-3609/
│   ├── PAY-3627/
│   ├── PAY-3683/
│   ├── PAY-3791/
│   └── PAY-3821/           # Treasury funding-batch send error handling
├── docs/
│   └── guides/             # Cross-cutting reference (PDFs, shared guides)
└── assets/screenshots/     # QA screenshots
```

## Quick links

| What | Where |
|------|--------|
| Postman collections | `postman/collections/` |
| Postman environments | `postman/environments/` |
| Ticket runbooks & Jira XML | `tickets/PAY-XXXX/` |
| Treasury funding guide (PDF) | `docs/guides/Treasury_Settlement_Funding_Guide.pdf` |
| PAY-3821 QA walkthrough (Chris) | `tickets/PAY-3821/PAY-3821-STAGE-QA-Walkthrough_Chris.md` |

When asking Cursor for help, `@`-mention the exact file — e.g. `@tickets/PAY-3627/PAY-3627-QA-Session-Runbook.md`.

## Sync (Windows ↔ Mac)

```bash
git pull    # before working
git add .
git commit -m "describe changes"
git push
```

## Postman

Import collections from `postman/collections/` and environments from `postman/environments/`.

Recent additions:

- **PAY-3605** — `PAY-3605-Unmatched-Settlement-Alert.postman_collection.json`, `PAY-3605-Unmatched-Settlement-Alert-DEV.postman_environment.json`
- **PAY-3821** — `PAY-3821-treasury-funding-send.postman_collection.json`, `PAY-3821-STAGE-Get-Treasury-Token.postman_collection.json`
- **MyChart UPP** — `wellfit_upp-MyChart*.json` in the same folders

Ticket context:

- **PAY-3605** — `tickets/PAY-3605/` (`PAY-3605-Story-1.1-E2E-Unmatched-Settlement-Alert-Runbook.md`, `PAY-3605.xml`)
- **PAY-3821** — `tickets/PAY-3821/` (`analysis.md`, `solution.md`, `e2e-test-plan.md`, `qa-verification.md`, `PAY-3821.xml`)
