# Treasury

Cases: **1**

## 1. Verify that Funding and Settlement are skipped on holidays and processed on the next business day

- **Case ID:** 304094
- **Status (at export):** Untested

### Expected

No Funding or Settlement activity occurs on Sat/Sun/bank holidays.No errors, exceptions, or DB inserts occur on holidays.All pending settlements/funding accumulated during the holiday window are processed correctly on the next business day's treasury run.

---

