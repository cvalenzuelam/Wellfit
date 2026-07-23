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
    ├── A. CP Payment … (PARKED)
    ├── B. CP Refund … (PARKED)
    ├── C. CNP Payment …
    ├── D. CNP Refund …
    ├── E. ACH Payment …
    ├── F. ACH Refund …
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
