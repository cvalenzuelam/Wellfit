# Testmo export — Run 789 (Release 9.6 Regression STAGE)

Source: `testmo-export-run-789-full.csv` (131 cases).
Split by Testmo **Folder** (module). Add future module exports beside these folders.

| Folder (module) | Cases | Path |
|-----------------|------:|------|
| ACH Payment - Settlement and Funding - Treasury | 10 | `by-folder/ACH-Payment---Settlement-and-Funding---Treasury/` |
| ACH Refund - Settlement and Funding - Treasury | 12 | `by-folder/ACH-Refund---Settlement-and-Funding---Treasury/` |
| Bug/HotFix* PAY-2603   Card Token Vault Fails to Return Wellfit Token | 12 | `by-folder/Bug-HotFix-PAY-2603-Card-Token-Vault-Fails-to-Return-Wellfit-Token/` |
| Card Not Present (CNP) | 17 | `by-folder/Card-Not-Present-(CNP)/` |
| Card Present (CP) | 5 | `by-folder/Card-Present-(CP)/` |
| CNP Payment - Settlement and Funding - Treasury | 9 | `by-folder/CNP-Payment---Settlement-and-Funding---Treasury/` |
| CNP Refund - Settlement and Funding - Treasury | 9 | `by-folder/CNP-Refund---Settlement-and-Funding---Treasury/` |
| CP Payment - Settlement and Funding - Treasury | 9 | `by-folder/CP-Payment---Settlement-and-Funding---Treasury/` |
| CP Refund  - Settlement and Funding - Treasury | 9 | `by-folder/CP-Refund---Settlement-and-Funding---Treasury/` |
| EX8000 | 1 | `by-folder/EX8000/` |
| PAY-1127 MyWallet: Removing Stored Cards | 7 | `by-folder/PAY-1127-MyWallet-Removing-Stored-Cards/` |
| PAY-1128 MyWallet: Adding New Cards | 8 | `by-folder/PAY-1128-MyWallet-Adding-New-Cards/` |
| TokenVault | 13 | `by-folder/TokenVault/` |
| Treasury | 1 | `by-folder/Treasury/` |
| Wellfit Provisioning | 9 | `by-folder/Wellfit-Provisioning/` |

## Layout

```
regression/9.6/testmo/
  testmo-export-run-789-full.csv   # full run export
  README.md
  by-folder/
    Card-Not-Present-CNP/          # this module
      *.csv + *-cases.md + index.json
    <Other-Module>/                # next exports you pass
```

## Module Postman packages

| Module | Postman / docs |
|--------|----------------|
| Card Not Present (CNP) | `../Regression-STAGE/` (module CNP) · cards `../cnp/CNP-STAGE-vantiv-test-cards.md` |
| TokenVault | `../Regression-STAGE/` (module TokenVault) · `../tokenvault/` |

Unified env: **Regression STAGE**. Resume notes: `../SESSION-CONTEXT.md`.

