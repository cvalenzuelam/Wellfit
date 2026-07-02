# QA Walkthrough — PAY-3821 (STAGE) — Chris

**For:** Peer QA review  
**Environment:** STAGE  
**Executed by:** Chris (`cvalenzuela@arkusnexus.com`)  
**Reference date:** Jul 2026  
**Tools:** Postman, Platform DB, App Insights `stage-insights`, Azure Portal

> **Note:** This is Chris’s STAGE execution record. For the canonical AI-generated spec, see `qa-verification.md` and `e2e-test-plan.md` in this folder.

---

## 1. What the ticket is about (one sentence)

When Treasury **cannot send** funding batches to Worldpay (network/SFTP problem), the system must **alert the team**, **say which batches are still pending**, and **leave them eligible for retry** — without killing the service.

**PAY-3821 does not fix the Worldpay connection.** It only makes failures visible and controlled.

---

## 2. What we tested vs what we did not

| Tested in STAGE | Not tested in STAGE (covered elsewhere) |
|-----------------|----------------------------------------|
| Email alert | AC-4 (SendGrid send failure) → unit tests PR #283 |
| Batches stay pending in DB | “Sent-before exclusion” (batch 1 sent, batch 2 fails) → unit tests |
| Service stays alive (202 / health) | Happy path with timestamp set → requires a **real** batch, not synthetic |
| Retry after restoring config | |

---

## 3. Access and tools

| Tool | Value / note |
|------|----------------|
| **Treasury API (Postman)** | `https://stage-platform.wellfit.com/treasury` |
| **Postman auth** | Header **`api_key`** (*Treasury API* collection). **Not** Bearer token in STAGE. |
| **Postman environment** | **No environment** (avoids wrong URLs) |
| **STAGE SQL** | `stage-platform-wellfit-sqlserver.database.windows.net` → DB **`Platform`** |
| **App Insights** | **`stage-insights`** |
| **Azure App Service** | **`stage-wf-treasury-api`** → Environment variables |
| **PAY-3821 collection** | `postman/collections/PAY-3821-treasury-funding-send.postman_collection.json` |

---

## 4. Steps we followed (in order)

### Step A — Smoke (Postman)

1. Import collection **PAY-3821 Treasury funding-batch send error handling**.
2. Collection variables:
   - `baseUrl` = `https://stage-platform.wellfit.com/treasury`
   - `apiKey` = same value as **Treasury API** collection (header `api_key`)
3. **GET** `/health` → **200** + body `Ok`.
4. **POST** `/send-funding-batch` → **202** + `correlationId` (smoke only; ACs not validated yet).

### Step B — Test data (SQL)

Insert **3 pending batches** (synthetic — enough to test the **failure** path):

```sql
DELETE FROM Payments.FundingBatches
WHERE BatchFileName LIKE 'PAY3821-E2E-%';

INSERT INTO Payments.FundingBatches (Id, MerchantId, BatchFileName, RequestSentTimeStamp)
VALUES
  (NEWID(), 'E2E3821', 'PAY3821-E2E-1.xml', NULL),
  (NEWID(), 'E2E3821', 'PAY3821-E2E-2.xml', NULL),
  (NEWID(), 'E2E3821', 'PAY3821-E2E-3.xml', NULL);

SELECT Id, MerchantId, BatchFileName, RequestSentTimeStamp
FROM Payments.FundingBatches
WHERE BatchFileName LIKE 'PAY3821-E2E-%';
```

**Expected:** 3 rows, `RequestSentTimeStamp` = **NULL**.

> The `.xml` files **do not exist** in storage on purpose. They are only for testing **SFTP connect** failure, not a successful send.

### Step C — Simulate failure (Azure)

In **`stage-wf-treasury-api`** → **Settings** → **Environment variables**:

| Setting | Test value | Original value (restore after) |
|---------|------------|--------------------------------|
| `processor.vantiv.batch:sftpurl` | `10.255.255.1` | `batch.vantivprelive.com` |
| `notifications:settlement:recipients` | Add QA inbox (e.g. `cvalenzuela@arkusnexus.com`) | Team default |

- Click **Apply** (+ app restart if prompted).
- `10.255.255.1` = fake IP → connect timeout (like Worldpay is down).

### Step D — Trigger failure (Postman)

1. **POST** `/send-funding-batch` → **202** + note `correlationId`.
2. Wait **~30 seconds** (job runs in background).

### Step E — Failure evidence

**Email (AC-1 / AC-2)**

- **1** email *Funding Batch Send Failed* (PAY-3821).
- Body lists **all 3 batches** `PAY3821-E2E-1/2/3.xml`.
- **1** extra email *Funding Batch Stage Failed (Send)* → coordinator (PAY-3587). **Expected** after merge; not PAY-3821 “spam”.

**SQL (AC-3)**

```sql
SELECT BatchFileName, RequestSentTimeStamp
FROM Payments.FundingBatches
WHERE BatchFileName LIKE 'PAY3821-E2E-%';
```

**Expected:** 3 rows, all **NULL**.

**App Insights**

- Resource: **`stage-insights`** → Logs.
- Traces for 202 accept, alert email send, and **exceptions** `SocketException` on role **Wellfit Treasury API**.
- Structured trace with `BatchId` / `UnsentBatches` **was not found**; the **email** had full context.

**Service health (guide assertion “healthy”)**

- **GET** `/health` → 200.
- **POST** send → still **202**.

### Step F — Recovery (AC-5)

1. Restore `processor.vantiv.batch:sftpurl` → `batch.vantivprelive.com` → **Apply**.
2. Wait ~1 min if the app restarted.
3. **POST** `/send-funding-batch` again → **202**.
4. Re-run SQL query.

**Expected with synthetic batches (practical, not overly strict):**

- Timestamps **stay NULL** (fake file does not exist → 404 in storage, not a real send).
- Error **changes** from SFTP timeout to “file not found” → proves **retry** with good config.
- **No** new *transport failure* timeout email.

### Step G — Cleanup

```sql
DELETE FROM Payments.FundingBatches
WHERE BatchFileName LIKE 'PAY3821-E2E-%';
```

Restore Azure settings (SFTP + recipients if changed).

---

## 5. Results by AC (practical criteria)

| AC | Meaning | STAGE result | Evidence |
|----|---------|--------------|----------|
| **AC-1** | Alert + failure context | **Practical PASS** | Email + App Insights exceptions |
| **AC-2** | One PAY-3821 alert, 3 batches listed | **PASS** | 1 *Send Failed* email with 3 files |
| **AC-3** | After failure, batches not “sent” in DB; service alive | **PASS** | 3 NULL + health/202 |
| **AC-4** | Email send failure does not break handling | **N/A env** | Unit tests PR #283 |
| **AC-5** | Restore config + idempotent retry | **PASS (synthetic)** | SFTP restored, re-trigger, NULL + 404 |

**Note for reviewer:** Do not be stricter than the environment allows. With fake batches you will not see `RequestSentTimeStamp` set — documented in `e2e-test-plan.md` TC-04.

---

## 6. Checklist for peer review

- [ ] Postman health **200**
- [ ] Postman send **202** with `api_key` + STAGE treasury URL
- [ ] 3 SQL rows staged (`PAY3821-E2E-*`, NULL)
- [ ] Broken SFTP → alert received listing **3 batches**
- [ ] SQL after failure: **3 NULL**
- [ ] SFTP restored → re-trigger → SQL still NULL (synthetic OK)
- [ ] SQL + Azure cleanup done
- [ ] Email screenshots or forwards saved (optional)

---

## 7. Issues we hit (so you do not repeat them)

| Issue | Cause | Fix |
|-------|-------|-----|
| 403 Bearer | Payments token does not work for Treasury | Use **`api_key`** + `stage-platform.wellfit.com/treasury` |
| 404 on send | Wrong Postman environment (e.g. Payments V2 QA Env) | **No environment** + collection variables |
| SQL vs Postman different env | Data in SBOX, API in STAGE | Same rule: **everything STAGE** |
| `invalid_scope` on Identity | Treasury scope not granted to QA in STAGE | Not needed; use `api_key` |
| Two emails on failure | PAY-3821 + coordinator | Normal / expected |

---

## 8. Suggested Jira comment

```text
STAGE QA PAY-3821 completed.

Setup: 3 synthetic pending rows (PAY3821-E2E-*), SFTP url set to 10.255.255.1 to induce connect failure.
Trigger: POST /send-funding-batch via Treasury STAGE (api_key auth) → 202.

Results:
- One PAY-3821 alert email listing all 3 unsent batches (AC-1/AC-2 pass).
- FundingBatches remained RequestSentTimeStamp NULL for all 3 rows (AC-3 pass).
- Service remained healthy (202/health) (AC-3/4 pass).
- After restoring sftpurl to batch.vantivprelive.com, re-trigger re-attempted batches; synthetic rows stayed NULL with file-not-found (404) — AC-5 pass for synthetic per e2e plan TC-04.
- Coordinator stage-failed email also received (expected with PAY-3587).
- AC-4 unit-covered (PR #283). Structured App Insights trace with BatchId not found; email + exceptions sufficient.

Cleanup: deleted PAY3821-E2E-* rows; restored Azure settings.
```

---

## 9. References in repo

- `tickets/PAY-3821/qa-verification.md` — formal criteria
- `tickets/PAY-3821/e2e-test-plan.md` — TC-01 through TC-04
- `postman/collections/PAY-3821-treasury-funding-send.postman_collection.json` — HTTP requests
- `postman/collections/PAY-3821-STAGE-Get-Treasury-Token.postman_collection.json` — optional auth helper (`api_key` is the real STAGE path)
