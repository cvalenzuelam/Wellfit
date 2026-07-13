# PAY-4077 — STAGE testing guide (simple)

**Spike:** CN/MP error handling when WorldPay Cert lookup fails  
**API:** `https://stage-wf-merchantprovisioning-api.azurewebsites.net`  
**DB:** `stage-platform-wellfit-sqlserver.database.windows.net` → **Platform**  
**Postman:** `tickets/PAY-4077/postman/` (collection + environment)

Goal: confirm retrieve returns `WorldPay.ObjectNotFound` with a clear message (not generic “Could not find requested object”).

---

## 1. Authenticate + create a fresh SubMerchant

1. Import Postman collection + environment from `tickets/PAY-4077/postman/`.
2. Run **1. Authenticate** → expect **200** + bearer token.
3. Run **2. Create SubMerchant** → expect **200/201** + `wellfitSubMerchantId`.
4. Run **3. Retrieve SubMerchant** → expect **Approved** (happy path).

Save the `wellfitSubMerchantId` (example from 2026-07-13 run: `29eb0000-8d3c-7ced-1dea-08dee1003238`).

---

## 2. List provider rows (save originals)

```sql
DECLARE @subMerchantId UNIQUEIDENTIFIER = '<wellfitSubMerchantId>';

DECLARE @provisionedSubMerchantId UNIQUEIDENTIFIER;
SELECT @provisionedSubMerchantId = ProvisionedSubMerchantId
FROM Payments.SubMerchants WHERE Id = @subMerchantId;

DECLARE @provisionedLegalEntityId UNIQUEIDENTIFIER;
SELECT @provisionedLegalEntityId = ProvisionedLegalEntityId
FROM MerchantProvisioning.ProvisionedSubMerchants
WHERE Id = @provisionedSubMerchantId;

SELECT 'LE' AS Src, Id, ProcessorId, ProcessorReference
FROM MerchantProvisioning.ProvisionedLegalEntityProviders
WHERE ProvisionedLegalEntityId = @provisionedLegalEntityId;

SELECT 'SM' AS Src, Id, ProcessorId, ProcessorReference
FROM MerchantProvisioning.ProvisionedSubMerchantProviders
WHERE ProvisionedSubMerchantId = @provisionedSubMerchantId;
```

Write down each row’s `Id` + `ProcessorReference` before changing anything.

Typical mapping after a 3-processor create:

| ProcessorId | Rail | Table to corrupt for ObjectNotFound |
|-------------|------|-------------------------------------|
| 0 | eCommerce (Cert) | LE and/or SM providers |
| 1 | Core (Cert) | **SM** providers (this one fails retrieve) |
| 3 | Core-style `C-…` | SM providers — **retrieve may still Approve** (see note) |

---

## 3. Force errors (one at a time) → Retrieve → Restore

Always: **UPDATE → Retrieve → restore original** before the next case.

### A) Legal Entity / eCommerce

```sql
UPDATE MerchantProvisioning.ProvisionedLegalEntityProviders
SET ProcessorReference = '83999715764802775'  -- bad id
WHERE Id = '<LE ProcessorId=0 Id>';
-- restore original ProcessorReference after retrieve
```

**Expect:** `code: WorldPay.ObjectNotFound` + message about eCommerce (Cert) / legal entity or sub-merchant.

### B) SubMerchant / eCommerce

```sql
UPDATE MerchantProvisioning.ProvisionedSubMerchantProviders
SET ProcessorReference = '83999715764818219'  -- bad id
WHERE Id = '<SM ProcessorId=0 Id>';
```

**Expect:** `WorldPay.ObjectNotFound` + eCommerce (Cert) + sub-merchant.

### C) SubMerchant / Core (Cert)

Use **SM `ProcessorId = 1`** (not `3`):

```sql
UPDATE MerchantProvisioning.ProvisionedSubMerchantProviders
SET ProcessorReference = '999999999'  -- bad id
WHERE Id = '<SM ProcessorId=1 Id>';
```

**Expect:** `WorldPay.ObjectNotFound` + **WorldPay Core (Cert)**.

### Note on ProcessorId = 3

Changing SM `ProcessorId = 3` (`C-…` refs) to a bad value may **not** return `ObjectNotFound` (retrieve still Approved). Prefer `ProcessorId = 1` for Core (Cert) coverage. Mention to Brett if retesting.

---

## 4. Pass criteria

- [ ] Happy-path retrieve works with valid refs  
- [ ] Bad eCommerce LE/SM ref → `WorldPay.ObjectNotFound` + clear message  
- [ ] Bad Core (`ProcessorId=1`) ref → `WorldPay.ObjectNotFound` + Core (Cert)  
- [ ] All `ProcessorReference` values restored  
- [ ] No leftover bad data on the test merchant  

Evidence: Postman responses + SQL updates. Record in Testmo / Jira as needed.

---

## Cleanup reminder

After the run, confirm originals are back:

```sql
-- re-run the SELECT from step 2 and compare to your notes
```
