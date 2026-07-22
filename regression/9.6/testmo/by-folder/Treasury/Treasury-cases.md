# Treasury

Cases: **1**

## 1. Verify that Funding and Settlement are skipped on holidays and processed on the next business day

- **Case ID:** 304094
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Ensure that Funding and Settlement processes do not execute on Saturdays, Sundays, or bank holidays without producing errors or DB entries, and that all skipped settlements are correctly processed when treasury runs on the next business day.

Preconditions:
- Test environment is configured with the holiday calendar (weekends + bank holidays) loaded correctly.
- Treasury/Funding/Settlement jobs are scheduled and operational.
- User has access to the Treasury API,  and the settlement/funding DB tables.
- Sample transactions are available to trigger funding/settlement.

### Expected

- No Funding or Settlement activity occurs on Sat/Sun/bank holidays.
- No errors, exceptions, or DB inserts occur on holidays.
- All pending settlements/funding accumulated during the holiday window are processed correctly on the next business day's treasury run.

---
