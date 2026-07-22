# EX8000

Cases: **1**

## 1. Verify transaction successful on EX8000 device

- **Case ID:** 213134
- **Priority:** Normal
- **Status (at export):** Untested

### Steps

Send CP for a device payment

{
//  "subMerchantId": "01334270",
 //"subMerchantId": "A36C0000-3A32-000D-5A1D-08DD1961183D",
 "subMerchantId": "A372295A-7AEB-4184-B4E9-16AB615237C4", //Stage -468
 //"subMerchantId": "105ABFBF-EE77-48AD-BF89-2C8B9665DE16", //QA -468
  //"subMerchantId": "1D550000-3A34-000D-889B-08D43C1753A8", //QA -11
   //"subMerchantId": "159F2670-1B71-4EF6-AD30-0EBF0991E2CC", //stage -11
  //"subMerchantId": "15C89B01-D2A4-48F8-9C2B-9BA1F2094076", //Stage - Disabled Merchant
  //"subMerchantId": "A372295A-7AEB-4184-B4E9-16AB615237C4", //Pre Prod -468
  "amount": 280,
 //"laneId": 5,//Ingenico
  "laneId": 30,//EX8000
  "orderId": "Radorder31902"
 // "metadata": "{\“clientData\“:\“Test Data\“}"
}
Observe request response successful

---
