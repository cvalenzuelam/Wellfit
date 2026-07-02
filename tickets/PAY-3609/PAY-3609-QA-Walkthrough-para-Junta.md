# QA Walkthrough — PAY-3609 y tickets relacionados

**Para:** Junta con compañera QA  
**Ambiente principal:** STAGE  
**Recursos:** Postman, Platform DB, App Insights `stage-insights`, Azure Cloud Shell (opcional)

---

## 1. Mapa rápido de tickets

| Ticket | Qué es | ¿QA manual? | Estado en esta sesión |
|--------|--------|-------------|------------------------|
| **PAY-3609** | Verificar alertas ACH per-transaction limit + cobertura tests | **Sí** | Probado en STAGE |
| **PAY-3508** | Implementación original del processor + alerta Compliance (Story 1.2) | Guía de referencia | PAY-3609 reusa el mismo pipeline |
| **PAY-3509** | Card (CNP/CP) con rail correcto en email ("Card" no "ACH") | Otro ticket | No es PAY-3609 |
| **PAY-3213** | ACH Transaction Limits (publisher) — ya en prod | Cerrado | Solo contexto |
| **PAY-3627** | ACH limit → Worldpay MaxTransactionAmount | Otro epic | Colecciones Postman reutilizadas, no es PAY-3609 |

**Mensaje clave para la junta:** PAY-3609 **no es feature nueva**. Confirma que el processor rail-agnostic que ya existía procesa eventos ACH igual que card, con email **ACH**.

---

## 2. PAY-3609 — Story en una frase

Cuando un ACH supera el **per-transaction limit** configurado del sub-merchant, Payments V2 declina → publica evento → Compliance Monitor → email a Compliance con rail **ACH**.

---

## 3. Pipeline (dibujar en la junta)

```
Postman ACH (amount > PerTransactionLimit)
  → Payments V2 enforcement → HTTP 422 per-transaction-limit-exceeded
  → Event Grid → Service Bus (payments / compliance-monitor-api)
  → PerTransactionLimitExceededProcessor
  → SendGrid → inbox compliance:transactionLimitAlertRecipient
```

**Daily limit** es otro processor (`AchDailyLimitExceededProcessor`) — AC-2 valida que per-tx **no** alerta en ese caso.

---

## 4. Acceptance criteria — qué hizo QA vs dev

| AC | Qué valida | QA manual | Evidencia |
|----|------------|-----------|-----------|
| **AC-1** | Per-tx breach → `AlertSent` | ✅ | Postman 422 + App Insights |
| **AC-2** | Daily breach → per-tx `AlertSkipped` | ✅ | Postman 422 daily + App Insights |
| **AC-3** | Routing per-tx vs daily processor | ❌ Dev unit tests | Nota Jira: QA not required |
| **AC-4** | Fixture JSON deserializa | ❌ Dev unit tests | Nota Jira: QA not required |
| **AC-5** | Email rail ACH + campos | ✅ | Screenshots email |
| **AC-6** | Smoke E2E completo | ✅ | Paquete AC-1 + AC-5 + SQL |

**Regresión (opcional):** ACH bajo límite → Approved, sin `AlertSent` per-tx.

---

## 5. Herramientas y accesos

| Herramienta | Uso |
|-------------|-----|
| **Postman** | `ACH payments-v2` → `ach-v2 electronic` (happy) o verbal-in-person (decline rápido) |
| **URL STAGE PV2** | `https://stage-wf-payments-v2-api.azurewebsites.net/api/v1/payments` |
| **Platform DB** | `[Payments].[AchLimitConfig]` — `PerTransactionLimit`, `DailyLimit` |
| **App Insights** | `stage-insights` → Logs, filtro `Wellfit Compliance Monitor` |
| **Azure** | App Service `stage-wf-compliancemonitor-api`, RG `stage-platform-api` |
| **Email** | Lista en `compliance:transactionLimitAlertRecipient` |

### Ver recipient de alertas (PowerShell, una línea)

```powershell
az webapp config appsettings list --name stage-wf-compliancemonitor-api --resource-group stage-platform-api --query "[?name=='compliance:transactionLimitAlertRecipient']" -o table
```

Separador de varios emails: **`;`**

---

## 6. SQL útil (Platform DB)

**Límite del merchant:**

```sql
SELECT SubMerchantId, PerTransactionLimit, DailyLimit
FROM [Payments].[AchLimitConfig]
WHERE SubMerchantId = '<GUID>';
```

**Nota:** JOIN con `SubMerchant.SubMerchants` puede fallar en STAGE; la tabla sola alcanza.

---

## 7. Cómo probamos cada escenario

### AC-1 — Per-transaction exceeded

1. SQL → anotar `PerTransactionLimit` (ej. $5,000).
2. Postman → `amount` **mayor** al límite (ej. $5,500).
3. Esperar **422** + `type`: `per-transaction-limit-exceeded`.
4. App Insights (~60 s):

```kusto
traces
| where timestamp > ago(4h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AlertSent" and message contains "PerTransactionLimitExceeded"
| project timestamp, message
| order by timestamp desc
| take 5
```

**Merchants usados en sesión:**
- `a2a70000-…` — límite $450, test $1,500
- `A372295A-…` (Mesa Valley) — límite $5,000, test $5,500

---

### AC-2 — Daily exceeded (per-tx processor ignora)

1. `amount` **≤** per-tx limit pero daily ya lleno (ej. $450 con daily $3,000 consumido).
2. Postman → **422** + `type`: `daily-limit-exceeded`.
3. App Insights:

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "AlertSkipped" and message contains "NonMatchingRejectionReason"
| project timestamp, message
| order by timestamp desc
| take 5
```

**No** debe haber `AlertSent` per-tx por ese intento.

**Alternativa:** SB injection (script `PAY-3508-Stage-SB-Injection.ps1`) — requiere permisos Service Bus; nos dio 401 sin rol.

---

### AC-5 — Email

- Tras AC-1, revisar inbox (lista en app setting).
- Subject esperado: `Risk Trigger Alert – **ACH** Payment Exceeds Per-Transaction Limit ($X > $Y)`.
- Body: merchant, account ID, amounts, %, timestamp.

**Ejemplo real:** $5,500.00 > $5,000.00 → 10.0%, Mesa Valley Modern Dentistry.

---

### AC-6 — E2E bundle

Mismas capturas en orden: SQL → Postman 422 → App Insights `AlertSent` → email.

---

### Regresión happy path

1. `amount` bajo límite (ej. $120), merchant con daily disponible.
2. Postman `ach-v2 electronic` → **200** + `responseMessage`: `Approved`.
3. App Insights por `paymentId`:

```kusto
traces
| where timestamp > ago(1h)
| where cloud_RoleName == "Wellfit Compliance Monitor"
| where message contains "<paymentId del response>"
| project timestamp, message
```

**Pass:** solo `Starting ProcessAsync` (o similar), **sin** `AlertSent` per-tx.

**Cuidado:** query general de `AlertSent` muestra **otros** tests en STAGE (ruido).

---

## 8. Test cases en Testmo (6)

| # | Título corto | AC |
|---|--------------|-----|
| 1 | Per-tx breach → AlertSent | AC-1 |
| 2 | Daily breach → AlertSkipped | AC-2 |
| 3 | Email ACH rail + campos | AC-5 |
| 4 | E2E smoke | AC-6 |
| 5 | Happy path sin alert per-tx | Regresión |
| 6 | — | AC-3/AC-4 documentados como dev-only, QA not required |

**Regla de títulos:** empiezan con `Validate that…` — **sin** `(STAGE)` ni `[PAY-3609]` en el título; ticket en **AC Linked**.

---

## 9. Problemas que tuvimos (lecciones)

| Problema | Causa | Solución |
|----------|-------|----------|
| SQL JOIN falla | Schema STAGE usa `[Payments].[AchLimitConfig]` sin `SubMerchant.SubMerchants` | Query simple sin JOIN |
| App Insights vacío | Time range corto o test viejo | `ago(4h)` + Last 4 hours en portal |
| SB injection 401 | Sin permiso SAS / Service Bus | Postman para AC-2 daily, o pedir rol a Brett |
| `az webapp` error | RG incorrecto (`stage-platform-core` vs **`stage-platform-api`**) | `az webapp list` para confirmar |
| Cloud Shell `\` en multilínea | PowerShell usa `` ` `` no `\` | Comandos en una línea |
| Email no llega | Recipient sin tu correo | Agregar a `compliance:transactionLimitAlertRecipient` + **restart** app + re-disparar AC-1 |
| 200 + `340 Invalid Amount` | Pasó enforcement, Worldpay rechazó amount | No es test de límite; subir amount o usar body ACH completo |
| `AlertSent` en happy path query | Logs de **otros** merchants/tests en STAGE | Filtrar por `paymentId` específico |

---

## 10. Archivos de referencia en el repo

| Archivo | Uso |
|---------|-----|
| `PAY-3609.xml` | ACs oficiales Jira |
| `PAY-3508-Transaction-Limit-Alert-QA-Testing-Guide.md` | Guía detallada pipeline + queries |
| `PAY-3508-Stage-SB-Injection.ps1` | SB injection STAGE (si hay permisos) |
| `.cursor/rules/wellfit-qa-test-cases.mdc` | Formato Testmo |

---

## 11. Agenda sugerida para la junta (30–45 min)

1. **5 min** — Qué es PAY-3609 vs PAY-3508/3509 (no feature nueva).
2. **5 min** — Pipeline y tablas/roles (`AchLimitConfig`, Compliance Monitor).
3. **10 min** — Demo AC-1: SQL → Postman 422 → App Insights → email.
4. **5 min** — AC-2: daily 422 + `AlertSkipped` (sin SB si no hay permisos).
5. **5 min** — Regresión happy path + filtrar App Insights por `paymentId`.
6. **5 min** — Test cases Testmo, evidencia por AC, AC-3/AC-4 dev-only.
7. **5 min** — Q&A: accesos STAGE, recipient email, merchants de prueba.

---

## 12. Checklist evidencia Jira (sign-off)

- [ ] AC-1: Postman 422 per-tx + App Insights `AlertSent`
- [ ] AC-2: Postman 422 daily + App Insights `AlertSkipped`
- [ ] AC-3/AC-4: Comentario "QA not required — dev unit tests"
- [ ] AC-5: Email subject + body (ACH)
- [ ] AC-6: Bundle E2E (o referencia a capturas AC-1 + AC-5 + SQL)
- [ ] Regresión: Postman Approved + App Insights sin `AlertSent` para ese `paymentId`

---

## 13. Preguntas que puede hacer tu compañera

**¿Por qué 422 y no 200 con decline en body?**  
El enforcement de límites ACH en PV2 responde 422 Problem Details antes de Worldpay.

**¿Por qué el log usa otro GUID que `subMerchantId`?**  
`AlertSent` suele loguear `subMerchantAccountId`, no siempre el mismo que Postman `subMerchantId`.

**¿Hay que probar en DEV?**  
Ticket en **In Stage**; validamos STAGE. DEV usa misma lógica con otros hosts/DB.

**¿Card y ACH mismo processor?**  
Sí, `PerTransactionLimitExceededProcessor` es rail-agnostic; rail va en el email (PAY-3509 arregló card).
