# PAY-4087 — Jira STAGE comment (paste Monday)

Copy the block below into Jira when posting STAGE results.

```text
STAGE QA PASS — PAY-4087.

Setup: Payments V2 POST /api/v1/payments ACH on STAGE (Clermont Smiles b7711d60-dbbb-4bc1-9462-000bf1511e88, amount 5.00, Vantiv Pre-Live routing 011075150 / account 1099999999). Raw-account debit + token-based debit (same vault token). Negatives: Worldpay 330 (non–eCheck merchant) and orderId length > 25 → tokenId null.

Verified: API tokenId returned on approved raw + lookup paths; Platform [Payments].[Payments].Token persisted for txns 83999807368660152 and 84087765197147539 = 282e0000-fe2e-a6b8-9d6e-08dee42a5f58; TokenVault BankAccountTokens Id Active matching that GUID. Declined/invalid paths keep tokenId null. AC-1/AC-2/AC-3 proven. PR #324 retry/redeposit not exercised. Evidence in Testmo.
```

## QA verdict (internal — 2026-07-17)

- **PASS WITH CAVEATS** — core persist TokenId E2E proven; #324 not run.
- Board: advance / Done or Ready for Prod per process.
- Postman: `tickets/PAY-4087/PAY-4087-persist-ach-tokenid-STAGE.postman_*.json`
- SQL helper: `tickets/PAY-4087/scripts/verify-ach-token-persisted-STAGE.sql`

## Key evidence IDs

| Path | transactionId | tokenId / Token |
|------|---------------|-----------------|
| Raw approved | 83999807368660152 | 282e0000-fe2e-a6b8-9d6e-08dee42a5f58 |
| Token lookup approved | 84087765197147539 | 282e0000-fe2e-a6b8-9d6e-08dee42a5f58 |
| 330 decline | 8399980748446084 (sample) | null |
| orderId > 25 | (empty txn) WORLDPAY_ERROR | null |
