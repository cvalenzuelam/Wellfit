# Wellfit QA workspace

Personal QA notes, runbooks, Postman collections, and Cursor rules for Wellfit payments work.

## Folder layout

```
Wellfit/
├── .cursor/rules/          # Cursor QA rules
├── postman/
│   ├── collections/        # Postman collections (.json)
│   └── environments/       # Postman environments (.json)
├── tickets/                # Jira exports, runbooks, and QA docs by ticket
│   ├── PAY-3508/
│   ├── PAY-3509/
│   ├── PAY-3609/
│   ├── PAY-3627/
│   ├── PAY-3683/
│   ├── PAY-3791/
│   └── PAY-3821/           # Treasury funding-batch send error handling
├── docs/                   # Cross-cutting reference docs (PDFs, guides)
└── assets/screenshots/     # QA screenshots
```

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

- **PAY-3821** — `postman/collections/PAY-3821-treasury-funding-send.postman_collection.json`
- **MyChart UPP** — `wellfit_upp-MyChart*.json` in the same folders

Ticket context for PAY-3821 lives in `tickets/PAY-3821/` (`analysis.md`, `solution.md`, `e2e-test-plan.md`, `qa-verification.md`, `PAY-3821.xml`).
