# Postman — single import (everything organized)

## Import these 2 files only

| File | Postman name |
|------|----------------|
| `postman/Wellfit-QA-Organized.postman_collection.json` | **Wellfit QA — Organized** |
| `postman/Wellfit-QA-Organized-STAGE.postman_environment.json` | **Wellfit QA — Organized STAGE** |

Then select env **Wellfit QA — Organized STAGE**.

## Tree after import

```
Wellfit QA — Organized
├── 0 — Regression 9.6 STAGE
│   └── Regression - STAGE (Release 9.6)
│       ├── CNP
│       ├── TokenVault
│       ├── Wellfit Provisioning
│       ├── Wallet
│       ├── PAY-2603
│       └── Treasury
├── 1 — Core
│   ├── ACH payments-v2
│   ├── Merchant Provisioning
│   ├── Payments API …
│   ├── TokenVault / Wallet / Paypages / …
└── 2 — Tickets
    └── PAY-XXXX …
```

## After import — clean sidebar

You can **delete** the old loose collections (CNP, TokenVault, Wallet, ACH payments-v2, individual PAY-*, old Regression - STAGE, etc.).  
Everything useful is inside **Wellfit QA — Organized**.

Keep ticket-specific envs only if a ticket needs DEV/other values; for STAGE regression use **Wellfit QA — Organized STAGE**.

## Rebuild note

Source folders (if you need to regenerate Organized later):

- `postman/collections/core/`
- `postman/collections/tickets/`
- `regression/9.6/Regression-STAGE/`
