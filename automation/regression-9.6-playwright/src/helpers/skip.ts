/**
 * Central skip reasons — keep Testmo / Postman PARKED in sync.
 */
export const SkipReason = {
  CP_PHYSICAL_LANE:
    'PARKED: Card Present requires physical lane / cardToken (TokenVault TC05–07/13, PAY-2603 TC06–07/12, Treasury A/B)',
  HOLIDAY_CALENDAR:
    'PARKED: Treasury holiday skip needs calendar timing window',
  SQL_MANUAL:
    'Manual: SQL Visualize / Azure Data Studio assertions not in API suite yet',
  WALLET_SUBSCRIPTION_FIXTURE:
    'PARKED: Wallet B TC03/TC04 need subscription / payment-plan fixtures',
  EPROTECT_PAYPAGE:
    'Deferred: eProtect paypage (CVV/ZIP/Pay Page GUID) — run in Postman until browser form helper lands',
  TREASURY_FUNDING_OPT_IN:
    'Skipped unless RUN_TREASURY_FUNDING=1 (mutates STAGE funding batches)',
  ACH_V2_SEED_UNSTABLE:
    'Known STAGE caveat: payments-v2 ACH sale often HTTP 500 — use existent txn path in Postman',
  PAY2603_INVALID_ZIP_BUG:
    'Known FAIL on STAGE: invalid zip returns 200+SqlException instead of 4xx (track in PAY-2603)',
} as const;
