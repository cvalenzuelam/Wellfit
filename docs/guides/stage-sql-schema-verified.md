# STAGE SQL — verified schemas (QA)

**Environment: STAGE only.** Do not assume Preprod/Prod match without a fresh dump.

**Server:** `stage-platform-wellfit-sqlserver.database.windows.net`  
**Rule:** do not invent tables/columns. Prefer this file + `.cursor/rules/wellfit-qa-stage-sql-databases.mdc`.  
**How to refresh:** run the discovery block below on the target DB; paste results; agent updates this file.

---

## Platform (verified 2026-07-16 — Chris)

`SELECT DB_NAME()` → **Platform**

### Schema `Financing`

- `RecurringPaymentTransactionalTable`

### Schema `Payments` (tables)

- AccountUpdaterBatchRecords
- AccountUpdaterInquiryRecords
- AchLimitConfig
- AchLimitConfigAuditLog
- AchPaymentDetails
- AuthorizationCaptures
- Authorizations
- BankAccounts
- ChargebackDetailsHistory
- ChargeBacks
- ChargeBackStatusHistory
- ChargebacksVantivCodes
- DatacapDeployments
- DisbursementRules
- Disbursements
- DisbursementSteps
- EMAFAuthorizationTransactions
- EMAFSettledTransactions
- EmvReceiptData
- FBOReserveTransfers
- FundingBatches
- FundingInstructionFeesXref
- FundingInstructionRejects
- FundingInstructions
- InterchangeCodes
- InterchangeFeeSchedule
- MasterMerchants
- OpsAccountFundingInstructions
- OrganizationDetails
- PayFacFeeRates
- PaymentDeviceActivations
- PaymentDevices
- PaymentFees
- PaymentRequests
- Payments
- PaymentsSettlements
- ProcessedSettlementReports
- ProcessingCosts
- ProvisionedLegalEntities
- ProvisionedSubMerchants
- RefundFees
- Refunds
- RefundsSettlements
- ResponseCodes
- ReturnedPayments
- Reversals
- ROCDevices
- SubMerchantAccounts
- SubMerchants
- SupportedDevices
- Tokenizations
- UnmatchedTransactions
- VAPSettledTransactions
- Voids
- WellfitPaymentCubes
- WellfitPaymentDevices

**Not on Platform:** `[Transactions].[PaymentTransaction]`, `[Transactions].[PaymentMethodACH]`

### `TokenVault.dbo.PaymentTokens` columns (verified STAGE 2026-07-22 — Chris)

**DB: TokenVault** (not Platform — Platform has no `Payments.PaymentTokens`).

| column_name | data_type |
|-------------|-----------|
| Id | uniqueidentifier |
| ProcessorId | int |
| ProcessorToken | nvarchar |
| CardLastFour | nvarchar |
| CardBrand | nvarchar |
| CardExpirationMonth | int |
| CardExpirationYear | int |
| CardZipCode | nvarchar |
| EntityUpdated | datetimeoffset |

**QA use:** body `token` on legacy `POST …/credit-card/process-card` = **`ProcessorToken`**. Filter by `CardBrand` for VISA/MC/AMEX/Discover.

**Reusable STAGE query (all brands):** `regression/9.6/scripts/cnp-payment-tokens-by-brand-STAGE.sql`  
Postman env keys: `tokenVisa`, `tokenAmex`, `tokenDiscover`, `tokenMc` (and `tokenVisaZipSensitive` when ZIP/CVV negatives need it).

### `[Payments].[AchPaymentDetails]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | PaymentId | uniqueidentifier |
| 3 | AccountType | nvarchar |
| 4 | SecCode | nvarchar |
| 5 | EntityCreated | datetimeoffset |
| 6 | EntityUpdated | datetimeoffset |

**Join:** `AchPaymentDetails.PaymentId` = `[Payments].[Payments].Id`

### `[Payments].[ReturnedPayments]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | TimeStamp | datetimeoffset |
| 4 | DateIssued | date |
| 5 | Amount | decimal |
| 6 | ReasonCode | nvarchar |
| 7 | ReasonDescription | nvarchar |
| 8 | OriginalPaymentId | uniqueidentifier |
| 9 | SettlementDate | date |
| 10 | FundingInstructionId | uniqueidentifier |
| 11 | CaseId | nvarchar |
| 12 | FBOFundingInstructionId | uniqueidentifier |
| 13 | ProcessorTransactionId | nvarchar |
| 14 | ProcessingStatus | int |
| 15 | RedepositEligible | bit |
| 16 | TotalRedepositAttempts | int |
| 17 | LastRedepositDate | date |
| 18 | ProcessingNotes | nvarchar |
| 19 | ProcessedTimestamp | datetimeoffset |

**QA notes:** `OriginalPaymentId` → `[Payments].[Payments].Id`. Match live charge via `ProcessorTransactionId` = `Payments.TransactionId`. `ProcessingStatus`: 0 pending / 1 processed / 3 needs review (per ACH return fixture). No `column_id` 3 in STAGE dump (gap/dropped col).

### `[Payments].[Refunds]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | TimeStamp | datetimeoffset |
| 3 | OriginalPaymentId | uniqueidentifier |
| 4 | Amount | decimal |
| 6 | OrderId | nvarchar |
| 7 | TransactionId | nvarchar |
| 8 | ResponseCode | nvarchar |
| 9 | ResponseMessage | nvarchar |
| 10 | SettlementDate | date |
| 11 | Voided | bit |
| 12 | FundingInstructionId | uniqueidentifier |
| 13 | Metadata | nvarchar |
| 14 | PayFacFee | decimal |

**QA notes:** `OriginalPaymentId` → `[Payments].[Payments].Id`. No `column_id` 5 in STAGE dump.

### `[Payments].[Voids]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | TimeStamp | datetimeoffset |
| 3 | OriginalPaymentId | uniqueidentifier |
| 4 | OrderId | nvarchar |
| 5 | TransactionId | nvarchar |
| 6 | ResponseCode | nvarchar |
| 7 | ResponseMessage | nvarchar |
| 8 | Metadata | nvarchar |

**QA notes:** `OriginalPaymentId` → `[Payments].[Payments].Id`. No `Amount` column on Voids (unlike Refunds).

---

## Payments database (verified 2026-07-16 — Chris)

Same server, **different database** named `Payments` (not Platform, not master).  
PM / Payment Management txn rows (ULID `01K…`) live here.

### Schema `AccountUpdater`

- AchNOCs
- ReturnDeactivations
- TokenMigrationFiles
- TokenMigrationRecords
- UnmatchedAchNOCs

### Schema `Fees`

- FeeAssessment
- FeeLifecycleState
- FeeLine
- FeePolicySnapshot
- FeeType
- WaiverReasonCode

### Schema `Payments`

- AchDailyCounter
- AchLimitEnforcementAuditLog
- IdempotencyKeys
- PaymentRequestEvents
- PaymentRequests

### Schema `Returns`

- RedepositAttempts
- ReturnCategory
- ReturnCodeCategoryMap
- ReturnConfigurations

### Schema `Transactions`

- AccountType
- ACHNotificationOfChange
- ACHReturn
- AuthorizationType
- CardBrand
- IdempotencyRecords
- OriginType
- PaymentMethodACH
- PaymentMethodCard
- PaymentTransaction
- PaymentTransactionHistory
- Processor
- Rail
- TransactionMetadata
- TransactionStatus
- TransactionType

### `[AccountUpdater].[ReturnDeactivations]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | TimeStamp | datetimeoffset |
| 3 | WellfitTokenId | uniqueidentifier |
| 4 | OriginalPaymentId | uniqueidentifier |
| 5 | ProcessorTransactionId | nvarchar |
| 6 | OrderId | nvarchar |
| 7 | ReturnCode | nvarchar |
| 8 | AccountLastFour | nvarchar |
| 9 | SourceEventId | nvarchar |
| 10 | Status | int |
| 11 | ResolveBy | datetimeoffset |
| 12 | ResolvedAt | datetimeoffset |
| 13 | ResolutionOutcome | nvarchar |
| 14 | EntityCreatedAt | datetimeoffset |
| 15 | EntityUpdatedAt | datetimeoffset |

**QA notes (Payments DB only):** `WellfitTokenId` → TokenVault `BankAccountTokens.Id`. Evidence table for hard-return deactivation (e.g. PAY-3811).

### `[Returns].[RedepositAttempts]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | ReturnedPaymentId | uniqueidentifier |
| 3 | OriginalPaymentId | uniqueidentifier |
| 4 | AttemptNumber | int |
| 5 | RedepositPaymentId | uniqueidentifier |
| 6 | RedepositAmount | decimal |
| 7 | ScheduledDate | date |
| 8 | AttemptStatus | int |
| 9 | ResponseCode | nvarchar |
| 10 | ResponseMessage | nvarchar |
| 11 | ReturnReasonCode | nvarchar |
| 12 | EntityCreated | datetimeoffset |
| 13 | EntityUpdated | datetimeoffset |

### `[Returns].[ReturnConfigurations]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | SubMerchantId | uniqueidentifier |
| 3 | ProcessorId | int |
| 4 | MaxRedepositAttempts | int |
| 5 | EntityCreated | datetimeoffset |
| 6 | EntityUpdated | datetimeoffset |

### `[Transactions].[ACHReturn]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | PaymentTransactionId | uniqueidentifier |
| 3 | ReturnReasonCode | nvarchar |
| 4 | ReturnReasonDescription | nvarchar |
| 5 | ReturnDate | date |
| 6 | ReturnTimestamp | datetimeoffset |
| 7 | IsAdministrative | bit |
| 8 | IsRetryable | bit |
| 9 | RetryTransactionId | uniqueidentifier |
| 10 | RetryInitiatedAt | datetimeoffset |
| 11 | RetryInitiatedBy | nvarchar |
| 12 | RawReturnData | nvarchar |
| 13 | EntityCreatedAt | datetimeoffset |

**Join:** `ACHReturn.PaymentTransactionId` = `PaymentTransaction.Id` (GUID).

### `[Transactions].[ACHNotificationOfChange]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | PaymentTransactionId | uniqueidentifier |
| 3 | NocCode | nvarchar |
| 4 | NocCodeDescription | nvarchar |
| 5 | ReceivedDate | date |
| 6 | ReceivedTimestamp | datetimeoffset |
| 7 | OriginalRoutingNumber | nvarchar |
| 8 | CorrectedRoutingNumber | nvarchar |
| 9 | OriginalAccountNumber | nvarchar |
| 10 | CorrectedAccountNumber | nvarchar |
| 11 | OriginalAccountType | tinyint |
| 12 | CorrectedAccountType | tinyint |
| 13 | OriginalName | nvarchar |
| 14 | CorrectedName | nvarchar |
| 15 | IsProcessed | bit |
| 16 | ProcessedAt | datetimeoffset |
| 17 | ProcessedBy | nvarchar |
| 18 | RawNocData | nvarchar |
| 19 | EntityCreatedAt | datetimeoffset |

**Join:** `ACHNotificationOfChange.PaymentTransactionId` = `PaymentTransaction.Id` (GUID).

### `[Transactions].[PaymentTransaction]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | **PaymentTransactionId** | **nvarchar** ← PM API `transactionId` (ULID `01K…`) |
| 3 | ProcessorTransactionId | nvarchar |
| 4 | TraceNumber | nvarchar |
| 5 | OrderId | nvarchar |
| 6 | ParentTransactionId | uniqueidentifier |
| 7 | RootTransactionId | uniqueidentifier |
| 8 | RetryAttempt | tinyint |
| 9 | RailId | tinyint |
| 10 | TransactionTypeId | tinyint |
| 11 | **TransactionStatusId** | **tinyint** ← FK to TransactionStatus.Id |
| 12 | TransactionStatusReason | nvarchar |
| 13 | Amount | decimal |
| 14 | Currency | char |
| 15 | SubMerchantId | uniqueidentifier |
| 16 | SubMerchantAccountId | uniqueidentifier |
| 17 | ProcessorAccountId | nvarchar |
| 18 | TokenId | uniqueidentifier |
| 19 | MerchantReference | nvarchar |
| 20 | TransactionDate | date |
| 21 | TransactionTimestamp | datetimeoffset |
| 22 | StatusTimestamp | datetimeoffset |
| 23 | SettlementDate | date |
| 24 | FundedDate | date |
| 25 | ProcessorId | smallint |
| 26 | ProcessorResponseCode | nvarchar |
| 27 | ProcessorResponseMessage | nvarchar |
| 28 | Product | nvarchar |
| 29 | SubmittedBy | nvarchar |
| 30 | OriginTypeId | tinyint |
| 31 | OriginSystem | nvarchar |
| 32 | OriginUserId | nvarchar |
| 33 | ConsumerPatientName | nvarchar |
| 34 | EntityCreatedAt | datetimeoffset |
| 35 | EntityUpdatedAt | datetimeoffset |

### `[Transactions].[PaymentMethodACH]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | **PaymentTransactionId** | **uniqueidentifier** ← joins to `PaymentTransaction.Id` (GUID), not the nvarchar ULID |
| 2 | AccountTypeId | tinyint |
| 3 | NameOnAccount | nvarchar |
| 4 | MaskedAccountNumber | nvarchar |
| 5 | RoutingNumber | nvarchar |
| 6 | BankName | nvarchar |
| 7 | AuthorizationTypeId | tinyint |
| 8 | AuthorizationDate | datetimeoffset |
| 9 | AuthorizationReference | nvarchar |
| 10 | AuthorizingUserId | nvarchar |
| 11 | SignedAuthorizationOnFile | bit |
| 12 | DisclosureConfirmed | bit |

### `[Transactions].[TransactionStatus]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | tinyint |
| 2 | Code | nvarchar |
| 3 | Name | nvarchar |
| 4 | Description | nvarchar |
| 5 | IsFinal | bit |

**Join rule:** `PaymentMethodACH.PaymentTransactionId` = `PaymentTransaction.Id` (GUID).  
**API id:** `PaymentTransaction.PaymentTransactionId` (nvarchar ULID).

### Lookup values (verified 2026-07-16 — Chris)

#### Rail (`RailId`)

| Id | Code | Name |
|----|------|------|
| 1 | ACH | ACH |
| 2 | CNP | Card Not Present |
| 3 | CP | Card Present |

#### TransactionType (`TransactionTypeId`)

| Id | Code | Name |
|----|------|------|
| 1 | DEBIT | Debit |
| 2 | CREDIT | Credit |
| 3 | AUTHORIZATION | Authorization |
| 4 | CAPTURE | Capture |
| 5 | REFUND | Refund |
| 6 | VOID | Void |
| 7 | RECURRING | Recurring |

#### TransactionStatus (`TransactionStatusId`)

| Id | Code | IsFinal | Notes for QA |
|----|------|---------|--------------|
| 1 | PENDING | 0 | |
| 2 | SUBMITTED | 0 | |
| 3 | APPROVED | 0 | |
| 4 | DECLINED | 1 | |
| 5 | FUNDED | 0 | |
| 6 | SETTLED | 1 | Common ACH refund candidate |
| 7 | RETURNED | 0 | |
| 8 | RETURN_RETRY | 0 | |
| 9 | POST_SETTLE_RETURN | 1 | |
| 10 | REFUNDED | 1 | Fully refunded |
| 11 | VOIDED | 1 | |
| 12 | CANCELLED | 1 | |
| 13 | FAILED | 1 | |
| 14 | TIMED_OUT | 1 | |
| 15 | NOC_RECEIVED | 0 | |
| 16 | UNSETTLED | 0 | |
| 17 | REFUND_FAILED | 1 | |
| 18 | PARTIALLY_REFUNDED | 0 | Remaining balance may still refund |
| 19 | PARTIAL_REFUND_FAILED | 1 | |

**ACH refund candidate filter (STAGE):** `RailId = 1`, `TransactionTypeId = 1` (DEBIT), `TransactionStatusId IN (6, 18)`, `ParentTransactionId IS NULL`, `ProcessorTransactionId` present.

#### OriginType (`OriginTypeId`) — verified 2026-07-16

| Id | Code | Name | RailId |
|----|------|------|--------|
| 1 | WEB | Web | 1 (ACH) |
| 2 | TEL | Telephone | 1 (ACH) |
| 3 | PPD | PPD | 1 (ACH) |
| 4 | CCD | CCD | 1 (ACH) |
| 5 | ECOM | E-Commerce | 2 (CNP) |
| 6 | MOTO | MOTO | 2 (CNP) |
| 7 | POS | Point of Sale | 3 (CP) |
| 8 | TAP_TO_PAY | Tap to Pay | 3 (CP) |

---

## TokenVault database (verified tables 2026-07-16 — Chris)

Same STAGE server, DB **TokenVault**.

### Schema `dbo` (QA-relevant)

| table_name | Use |
|------------|-----|
| **BankAccountTokens** | Primary ACH bank tokens |
| **BankAccountTokenLog** | Token audit / changes |
| **PaymentTokens** | CNP card tokens — full cols under `TokenVault.dbo.PaymentTokens` section |

### Ops / ignore for QA

- IndexMaintenanceLog
- PostOptimizationLog
- QueryStoreBaseline
- `tmp_ms_xx_BankAccountTokens_*` (temp/migration)

### `[dbo].[BankAccountTokens]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | RoutingNumber | nvarchar |
| 3 | EncryptedAccountNumber | nvarchar |
| 4 | AccountHash | nvarchar |
| 5 | FirstName | nvarchar |
| 6 | LastName | nvarchar |
| 7 | AccountHolderName | nvarchar |
| 8 | AccountType | nvarchar |
| 9 | Status | nvarchar |
| 10 | CreatedAt | datetime2 |
| 11 | LastNocProcessedAt | datetime2 |
| 12 | LastNocId | nvarchar |
| 13 | LastNocAction | nvarchar |
| 14 | Version | int |
| 15 | UpdatedAt | datetime2 |
| 16 | UpdatedBy | nvarchar |
| 17 | DeactivationReason | nvarchar |
| 18 | DeactivatedAt | datetime2 |

**QA note:** Platform `[Payments].[Payments].Token` (GUID) links to `BankAccountTokens.Id` when tokenized ACH.

### `[dbo].[BankAccountTokenLog]` columns (verified 2026-07-16)

| column_id | column_name | data_type |
|-----------|-------------|-----------|
| 1 | Id | uniqueidentifier |
| 2 | TokenId | uniqueidentifier |
| 3 | EventType | nvarchar |
| 4 | EventTimestamp | datetime2 |
| 5 | EventSource | nvarchar |
| 6 | EventStatus | nvarchar |
| 7 | FailureReason | nvarchar |
| 8 | EventDetails | nvarchar |
| 9 | NocId | nvarchar |
| 10 | NocAction | nvarchar |
| 11 | ReturnCode | nvarchar |
| 12 | TokenStatusBefore | nvarchar |
| 13 | TokenStatusAfter | nvarchar |
| 14 | IdempotencyKey | nvarchar |

---

## Discovery template (run per DB)

```sql
SELECT DB_NAME() AS current_db;

SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;

-- For a specific table:
-- SELECT c.column_id, c.name AS column_name, ty.name AS data_type, c.max_length, c.is_nullable
-- FROM sys.columns c
-- JOIN sys.types ty ON ty.user_type_id = c.user_type_id
-- JOIN sys.tables t ON t.object_id = c.object_id
-- JOIN sys.schemas s ON s.schema_id = t.schema_id
-- WHERE s.name = 'Transactions' AND t.name = 'PaymentTransaction'
-- ORDER BY c.column_id;
```
