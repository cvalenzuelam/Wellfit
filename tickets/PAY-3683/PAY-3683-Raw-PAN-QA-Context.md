# PAY-3683 — Card Payment Flow via Payments API V2 (Token or Raw PAN)

**QA context captured from validation session (Stage).** Use this as the working reference for follow-up test cases, App Insights checks, and Postman runs.

---

## Ticket summary

Payments API V2 supports card payments via **token** or **raw PAN** (`cardNumber`) on:

- `POST /v2/cnp/authorize`
- `POST /v2/cnp/charge`

Key validation themes:

| AC area | What to validate |
|--------|------------------|
| **AC-3** | Token-or-PAN validation — neither both missing (400) nor both present (precedence TBD in refinement) |
| **AC-4** | Full PAN and CVV must **not** appear in **Application Insights** after raw PAN charge or authorize |
| **Response masking** | API response masks `cardNumber` and `cvv` in `source` and `debugResponse.vantiv` |

---

## Stage environment

| Item | Value |
|------|--------|
| **Payments API V2 base URL** | `https://stage-platform.wellfit.com/payments-v2` |
| **Postman env var** | `Payments API Stage` |
| **Authenticate** | `POST /authenticate` — use Stage credentials from Postman (`Authenticate_Payment-Stage`) |
| **Test subMerchantId** | `159F2670-1B71-4EF6-AD30-0EBF0991E2CC` (Redhill Stage) |
| **App Insights resource** | **`stage-insights`** (Stage subscription) |
| **Cloud role (payments API)** | `stage-wf-payments-api` |
| **Gateway role** | `stage-platform-wellfit-api-West US` |
| **PAN/CVV test data** | Confluence — Vantiv prelive / Stage test cards (do not paste real values in test cases) |

**Postman collection:** `postman/collections/Payments API V2.postman_collection.json`

---

## Request patterns

### Raw PAN (PAY-3683 flow)

Send **`cardNumber`** + **`cvv`** (not `token`):

```json
{
  "amount": "50",
  "cardNumber": "<Confluence test PAN>",
  "cvv": "<Confluence test CVV>",
  "expirationMonth": 1,
  "expirationYear": 2030,
  "orderId": "<unique-order-id>",
  "subMerchantId": "159F2670-1B71-4EF6-AD30-0EBF0991E2CC",
  "zipCode": "01803"
}
```

### Token flows (existing)

| `tokenType` | Meaning | `token` value |
|-------------|---------|----------------|
| **0** | Pay Page (eProtect) | `paypageRegistrationId` from eProtect paypage |
| **1** | Wellfit stored token | GUID from prior authorize or Token Vault |

Postman note (Wallet / V2): *if paypage → tokenType 0; if Wellfit token → tokenType 1*.

Raw PAN uses **`cardNumber`** field; do not confuse with `token` + `tokenType`.

---

## Response fields (what QA sees)

### Wellfit API (`source` / `response`)

- **`source.cardNumber`**: masked, e.g. `***********0004`
- **`source.cvv`**: `***`
- **`response.transactionId`**: use for App Insights correlation
- **`response.token`**: Wellfit GUID after success
- **`response.cardType`**: string — `"Amex"`, `"Visa"`, etc.

### Vantiv debug (`debugResponse.vantiv`) — if present

- **`card.number`**: masked
- **`card.cardValidationNum`**: `***`
- **`card.type`**: numeric network enum (Vantiv), **not** `tokenType`:

| `card.type` | Network |
|-------------|---------|
| 1 | Visa |
| 2 | American Express |
| 3 | MasterCard |
| 4 | Discover |

- **`tokenResponse.litleToken`**: processor token (not raw PAN); confirm with AC whether allowed in logs

### DB — `[Payments].[Payments].PaymentTypeMethod` (separate enum)

| Value | Method |
|-------|--------|
| 0 | eCheck default |
| 1 | Pay Page |
| 2 | CNP token |
| 3 | Apple Pay |
| 4 | Google Pay |
| 5 | Card Present |

---

## AC-3 — Token-or-PAN validation

**Neither `token` nor `cardNumber`:**

- **Then:** HTTP **400** with clear validation error (one of the two required)
- **Note:** Optional negative / contract test; low real-world use case

**Both `token` and `cardNumber` present:**

- Behavior **pending refinement** (recommendation: token wins, `cardNumber` ignored — confirm with dev)
- Test cases should be **Blocked** until refinement decision

**Test case title pattern:** `Validate that ...`

---

## AC-4 — App Insights: PAN/CVV must not appear

### Pass criteria

- KQL search for **full PAN** and **literal CVV** in telemetry for the operation → **0 rows**
- **Acceptable:** last 4 (`0004`), masks (`***`, `***********0004`), `orderId`, `transactionId`, Wellfit token GUID
- **Fail:** full 15–16 digit PAN or CVV in `traces`, `requests`, `dependencies`, `exceptions`, `customDimensions`

### Workflow

1. Run charge or authorize in Postman; note `orderId`, `transactionId`, timestamp
2. Wait **2–5 minutes**
3. Open **`stage-insights`** → **Logs**
4. Find operation → copy **`operation_Id`**
5. Run PAN/CVV search query
6. Attach screenshot (0 rows) as evidence

### Example session data (Stage)

| Flow | orderId | transactionId | operation_Id (example) |
|------|---------|---------------|-------------------------|
| Charge (earlier) | `100597429` | `83999549198030699` | `10f332b46ad28ecc6548a22474470042` |
| Authorize AMEX raw PAN | `100884856` | (from response) | from `/v2/cnp/authorize` query |
| Charge AMEX raw PAN | `100329248` | `83999549237833117` | from `/v2/cnp/charge` query |

Example AMEX test PAN used in session: `375900000000004` (authorize), `375000266000004` (charge) — confirm against Confluence; CVV commonly `349`.

---

## App Insights KQL — copy/paste

### Find charge

```kusto
requests
| where timestamp > ago(15m)
| where url has "/v2/cnp/charge"
| project timestamp, operation_Id, url, resultCode, duration, cloud_RoleName
| order by timestamp desc
| take 20
```

### Find authorize

```kusto
requests
| where timestamp > ago(15m)
| where url has "/v2/cnp/authorize"
| project timestamp, operation_Id, url, resultCode, duration, cloud_RoleName
| order by timestamp desc
| take 20
```

### Find by orderId / transactionId

```kusto
union traces, requests, dependencies, exceptions
| where timestamp > ago(30m)
| where tostring(customDimensions) contains "<orderId-or-transactionId>"
    or message contains "<orderId-or-transactionId>"
| project timestamp, itemType, operation_Id, message, customDimensions
| order by timestamp desc
```

### Full operation trace

```kusto
union traces, requests, dependencies, exceptions, customEvents
| where operation_Id == "<operation_Id>"
| project timestamp, itemType, message, name, url, customDimensions, outerMessage, innermostMessage
| order by timestamp asc
```

### AC-4 PAN/CVV check (replace placeholders)

```kusto
let testPan = "<full-PAN-sent-in-request>";
let testCvv = "<CVV-sent-in-request>";
let op = "<operation_Id>";
union traces, requests, dependencies, exceptions, customEvents
| where operation_Id == op
| extend blob = strcat(
    coalesce(tostring(message), ""),
    coalesce(tostring(customDimensions), ""),
    coalesce(tostring(outerMessage), ""),
    coalesce(tostring(innermostMessage), "")
)
| where blob contains testPan or blob contains testCvv
| project timestamp, itemType, message, customDimensions
```

**Pass:** 0 rows.

Use **`operation_Id` from `stage-wf-payments-api`** (not only the gateway row).

---

## AC-4 test case examples (English / TestRail style)

**Validate that full PAN and CVV do not appear in App Insights after raw PAN charge on Stage**

**Validate that full PAN and CVV do not appear in App Insights after raw PAN authorize on Stage**

**Validate that declined raw PAN charge does not leak PAN or CVV into App Insights**

Structure: Title → `### Description` (AC Linked, AC Description) → **Preconditions** → **Expected** → **Steps** (First / Then / Next / Finally).

---

## AC-3 test case examples (English / TestRail style)

**Validate that charge returns HTTP 400 when neither token nor cardNumber is supplied**

**Validate that authorize returns HTTP 400 when neither token nor cardNumber is supplied**

**Validate that charge behavior is defined when both token and cardNumber are supplied (pending refinement)**

**Validate that authorize behavior is defined when both token and cardNumber are supplied (pending refinement)**

---

## Related repo files

- `postman/collections/Payments API V2.postman_collection.json`
- `Payments V2 Env.postman_environment.json`
- `.cursor/rules/wellfit-qa-test-cases.mdc` — test case format rules
- `PAY-3627-QA-Session-Runbook.md` — App Insights query patterns (different service, same KQL approach)

---

## Open items / follow-up

- [ ] Confirm AC-3 behavior when **both** `token` and `cardNumber` are sent
- [ ] Confirm whether **`litleToken`** in debug/logs is acceptable per PCI AC
- [ ] Confirm **`PaymentTypeMethod`** in DB for raw PAN charge vs token charge
- [ ] Run AC-4 for both **authorize** and **charge** with evidence screenshots
- [ ] Optional: AC-3 negative (neither token nor cardNumber) on both endpoints

---

*Last updated from QA chat session — Stage validation, June 2026.*
