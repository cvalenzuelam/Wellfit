# PAY-4077 — CN/MP error handling for WorldPay Cert lookup failures

**Spike · Merchant Provisioning · Fix version: R9.6 · Status: WAITING REVIEW**  
Jira: https://wellfit.atlassian.net/browse/PAY-4077  
Related: [PAY-4088](https://wellfit.atlassian.net/browse/PAY-4088) (broader WorldPay PayFac error hygiene — backlog)  
QA subtasks: PAY-4106 (test cases), PAY-4107 (Stage test)

---

## Problem (pre-fix)

When Merchant Provisioning looks up a legal entity / submerchant in **WorldPay Cert** and the ID is missing (common in lower envs: sanitized prod data in DB, never provisioned in Cert), CN/Wellfit Connect showed a **generic** error: `Could not find requested object`.

## What to verify (post-change)

MP returns a **specific** validation error:

| Field | Expected |
|-------|----------|
| `validationErrors[].code` | `WorldPay.ObjectNotFound` |
| `validationErrors[].type` | `Input` |
| `message` | Clear text naming **legal entity** or **SubMerchant** / **CORE(Cert)** + the bad WorldPay id + note that lower envs often have DB rows never provisioned in Cert |

Example (Legal Entity — eCommerce Cert):

```json
{
  "validationErrors": [
    {
      "code": "WorldPay.ObjectNotFound",
      "data": null,
      "message": "legal entity 83999715764802774 was not found in WorldPay eCommerce (Cert). In lower environments this usually means the record exists in the database (sanitized production data) but was never provisioned in WorldPay eCommerce (Cert).",
      "type": "Input"
    }
  ],
  "message": "legal entity 83999715764802774 was not found in WorldPay eCommerce (Cert). ..."
}
```

**Three failure flavors to force:**

1. **Legal Entity — eCommerce (Cert)** → message says `legal entity …`
2. **SubMerchant — eCommerce (Cert)** → similar, says SubMerchant
3. **SubMerchant — CORE (Cert)** → similar, says CORE(Cert)

Brett may still tweak PROD wording (drop “in lower environments” outside lower envs) after QA feedback.

---

## STAGE assets

| Item | Value |
|------|--------|
| **DB** | `stage-platform-wellfit-sqlserver.database.windows.net` → **Platform** |
| **Inspect / chain script** | `tickets/PAY-4077/2026-07-10-merchant-provisioning-info.sql` |
| **API** | `https://stage-wf-merchantprovisioning-api.azurewebsites.net` |
| **Auth** | Postman: `MP authenticate-mp` → Bearer |
| **Retrieve** | `GET /provisioning/retrieve-sub-merchant?wellfitSubMerchantId={id}` |
| **Postman** | `postman/collections/Merchant Provisioning.postman_collection.json` → **MP - read sm** |

Default `@subMerchantId` in Brett’s script (example): `ff890000-523e-7c1e-07e4-08dedeb0a78e`  
Prefer a **fresh** SubMerchant via create if existing data is stale.

---

## How to force each error (Brett)

After listing `ProvisionedLegalEntityProviders` / `ProvisionedSubMerchantProviders` with the script, **bump `ProcessorReference` to a wrong WorldPay id** (keep original to restore):

```sql
-- Legal Entity — eCommerce (Cert)
UPDATE MerchantProvisioning.ProvisionedLegalEntityProviders
SET ProcessorReference = '83999715764802775'  -- wrong / non-existent in Cert
WHERE Id = '<ProvisionedLegalEntityProviders.Id>';

-- SubMerchant — eCommerce (Cert)
UPDATE MerchantProvisioning.ProvisionedSubMerchantProviders
SET ProcessorReference = '83999715764818219'  -- wrong
WHERE Id = '<eCommerce provider row Id>';

-- SubMerchant — CORE (Cert)
UPDATE MerchantProvisioning.ProvisionedSubMerchantProviders
SET ProcessorReference = '112963250'  -- wrong CORE id
WHERE Id = '<CORE provider row Id>';
```

Then call **retrieve-sub-merchant** for that `wellfitSubMerchantId` and assert `WorldPay.ObjectNotFound` + correct entity wording.

**Always restore** original `ProcessorReference` values after the run.

---

## Script notes (`2026-07-10-merchant-provisioning-info.sql`)

1. Set `@subMerchantId`.
2. Leave `@deleteMerchantProvisioningData = 0` for normal inspect (lists LE / SM / providers).
3. Delete path is **dangerous** — only with `@deleteMerchantProvisioningData = 1` and after commenting out `ROLLBACK`; default path ends in `ROLLBACK` even when delete flag is on. Prefer **UPDATE ProcessorReference**, not delete, for this spike.

Search helpers (comment block): `Payments.SubMerchants` / `ProvisionedSubMerchants` by name (e.g. `%North Seattle%`).

---

## Pass criteria (QA)

- [ ] Retrieve with **bad Legal Entity** processor ref → `WorldPay.ObjectNotFound` + legal-entity message (not generic “Could not find requested object”)
- [ ] Retrieve with **bad SubMerchant eCommerce** ref → same code + SubMerchant wording
- [ ] Retrieve with **bad SubMerchant CORE** ref → same code + CORE(Cert) wording
- [ ] (Optional) Happy path retrieve with **valid** refs still succeeds
- [ ] Processor refs restored; no leftover bad data on the test merchant

Out of scope for this spike unless asked: full CN UI polish (PAY-4093), PAY-4088 broader hygiene.
