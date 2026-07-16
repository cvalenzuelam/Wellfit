# STAGE Identity — client → scopes (verified)

**Host:** `https://stage-wf-identity-api.azurewebsites.net/connect/token`  
**Grant:** `client_credentials` (no `scope` param — default scopes returned)  
**Verified:** 2026-07-16

Secrets stay in `wellfit-qa-stage-credentials.mdc` / Postman env — not repeated here.

## Quick pick (QA)

| Need | Prefer client |
|------|----------------|
| PM refunds (`RefundPayments` + `PaymentManagementAPI.Full`) | **WellfitUnifiedPaymentsAPI** |
| Worldpay Wrapper (`WorldpayWrapperAPI.Full`) | **WellfitPaymentManagementAPI** (also has SubMerchant Read only) |
| Onboarding / Merchant Provisioning | **WellfitOnBoardingAPI** |
| eCheck + RefundPayments + Payments V2 (no PM Full) | **WellfitAutomation** |
| Treatment / remote / ecom unified scopes | **WellfitTreatmentAPI** |
| Settlement data | **PDSAccounting** |

**Do not** use `WellfitPaymentManagementAPI` alone for PM **refund** APIs — it does **not** return `WellfitPaymentsAPI.RefundPayments` or `WellfitPaymentManagementAPI.Full`.

## WellfitUnifiedPaymentsAPI

- WellfitComplianceMonitorAPI.Testing
- WellfitPaymentManagementAPI.Full
- WellfitPaymentsAPI.DevicePayments
- WellfitPaymentsAPI.ElectronicCheckPayments
- WellfitPaymentsAPI.RefundPayments
- WellfitPaymentsAPI.eCommercePayments
- WellfitPaymentsV2API.Full
- WellfitSubMerchantAPI.AchLimitsAdmin
- WellfitTokenVault.ReadAccess
- WellfitTokenVault.WriteAccess
- WellfitWalletApi.ReadAccess
- WellfitWalletApi.WriteAccess

## WellfitPaymentManagementAPI

- WellfitSubMerchantAPI.Read
- WorldpayWrapperAPI.Full

## WellfitOnBoardingAPI

- WellfitComplianceMonitorAPI.ReadAccess
- WellfitComplianceMonitorAPI.WriteAccess
- WellfitMerchantProvisioningAPI.ReadAccess
- WellfitMerchantProvisioningAPI.WriteAccess
- WellfitPaymentsAPI.ChargeBacks
- WellfitPaymentsAPI.DeviceManagement
- WellfitPaymentsAPI.MerchantProvisioning
- WellfitUnifiedPaymentsAPI.WellfitPaymentDeviceManagement

## WellfitTreatmentAPI

- WellfitPaymentsAPI.DevicePayments
- WellfitUnifiedPaymentsAPI.DevicePayments
- WellfitUnifiedPaymentsAPI.ElectronicCheckPayments
- WellfitUnifiedPaymentsAPI.LoanPayments
- WellfitUnifiedPaymentsAPI.Refunds
- WellfitUnifiedPaymentsAPI.RemotePayments
- WellfitUnifiedPaymentsAPI.eCommercePayments

## WellfitAutomation

- WellfitPaymentsAPI.DynamicFunding
- WellfitPaymentsAPI.ElectronicCheckPayments
- WellfitPaymentsAPI.RefundPayments
- WellfitPaymentsAPI.eCommercePayments
- WellfitPaymentsV2API.Full
- WellfitUnifiedPaymentsAPI.WellfitFinancingAutomation
- identity

## PDSAccounting

- WellfitUnifiedPaymentsAPI.SettlementData
- identity
- upp

## Refresh

Re-run token without `scope` for each client; replace lists above if Identity changes.
