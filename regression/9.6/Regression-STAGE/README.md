# Regression - STAGE

## Import

1. Import the 2 JSON files in this folder (replace if already imported).
2. Select env: **Regression STAGE**

```
Regression - STAGE
├── CNP
├── TokenVault
├── Wellfit Provisioning
├── Wallet
├── PAY-2603
└── Treasury
    ├── 00. Shared setup
    ├── A. CNP Payment …
    ├── B. CNP Refund …
    ├── C. ACH Payment …
    ├── D. ACH Refund …
    ├── E/F CP … (PARKED)
    └── G. Holiday skip (PARKED)

Environment: Regression STAGE
```

## SQL Visualize

| Module | DB dropdown | Notes |
|--------|-------------|--------|
| TokenVault | Platform / TokenVault | Labeled per request |
| Wellfit Provisioning | Platform | TC05 / TC09 |
| Wallet | **Wallet** | See `../wallet/` |
| PAY-2603 | TokenVault / Platform | See `../pay-2603/` |
| Treasury | **Platform** (+ Payments for ACH) | See `../treasury/` — create/send use **`api_key`** |

Azure Data Studio: **Run** (not Estimated Plan).
