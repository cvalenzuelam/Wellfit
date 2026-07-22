# Bug/HotFix* PAY-2603   Card Token Vault Fails to Return Wellfit Token

Cases: **12**

## 1. Verify that, Add Token API works successfully without cardZipCode

- **Case ID:** 168002
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Precondition: 
Valid card data is available.

### Expected

API responds with 200 OK (or equivalent success).
A token is created and returned.
cardZipCode is treated as optional.

### Steps

Send a POST /add-token request with valid card details, omitting the cardZipCode field.
Observe the API response.

---

## 2. Validate that, a token is created successfully when cardZipCode is provided

- **Case ID:** 168003
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Token is created and returned successfully.

### Steps

Send a POST /add-token request with valid card details including cardZipCode.
Observe the response.

---

## 3. Validate that, the API accepts a request when cardZipCode is sent as an empty string

- **Case ID:** 168004
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

API either processes it as if cardZipCode was omitted (preferred) or returns a clear validation error.

### Steps

Send a POST /add-token request with cardZipCode = ""
Observe the response

---

## 4. Validate that, the API rejects invalid cardZipCode values

- **Case ID:** 168005
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

API returns a validation error and no token is created.

### Steps

Send a POST /add-token request with cardZipCode = "ABCDE" or "12"
Observe the response

---

## 5. Validate that, the API no longer fails when cardZipCode is omitted

- **Case ID:** 168006
- **Priority:** Normal
- **Status (at export):** Untested

---

## 6. Validate that, the Token Vault generates and returns a Wellfit token for a valid CP charge API request without ZipCodeField

- **Case ID:** 168007
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Token Vault generates and returns a Wellfit token successfully.
cardZipCode is not required.

### Steps

Send a CP charge API request for a card-present transaction with valid card details and omit cardZipCode.
Observe the API response

---

## 7. Validate that, Wellfit Token retrieved in CP charge API response is stored in Token Vauld dbo Tokens table

- **Case ID:** 168008
- **Priority:** Normal
- **Status (at export):** Untested

---

## 8. Validate that, a Wellfit token is generated successfully for a valid CNP request with ZipCodeField

- **Case ID:** 168009
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Token Vault generates and returns a Wellfit token successfully.
Behavior matches pre-fix baseline.

### Steps

Send a request for a CNP transaction with valid card details including cardZipCode
Observe the API response

---

## 9. Validate that, Wellfit Token retrieved in CNP API response is stored in Token Vauld dbo Tokens table

- **Case ID:** 168010
- **Priority:** Normal
- **Status (at export):** Untested

---

## 10. Validate that, a Wellfit token is generated successfully for a valid CNP request without ZipCodeField

- **Case ID:** 168011
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Token Vault generates and returns a Wellfit token successfully.
Behavior matches pre-fix baseline.

### Steps

Send a CNP request for omitting cardZipCode
Observe the API response

---

## 11. Validate that, a transaction is generated successfully for a valid CNP request with Wellfit Token

- **Case ID:** 213300
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

CNP returns a Wellfit token successfully.
Behavior matches pre-fix baseline.

### Steps

Send a CNP request with GUID token
Observe the API response

---

## 12. Validate that, the Token Vault returns a Processor token and generates a DevOps alert when Wellfit token generation fails for a CP request

- **Case ID:** 168012
- **Priority:** Normal
- **Status (at export):** Untested

### Description

Precondition: Force or simulate a failure in Wellfit token generation

---
