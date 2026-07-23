# PAY-1127 MyWallet: Removing Stored Cards

Cases: **7**

## 1. Verify that, delete-token API for credit cards request response is successful

- **Case ID:** 67603
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Send a request to the "Delete Token" API with the corresponding token.

---

## 2. Verify that, a card token cannot be deleted without authentication

- **Case ID:** 67604
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Ensure the API returns an unauthorized (HTTP 401) response

---

## 3. Verify that, attempting to delete a token linked to an active subscription retrieves an error message

- **Case ID:** 67605
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Validate that the API returns an error message (HTTP 400/409) with an appropriate reason.

---

## 4. Verify that, attempting to delete a card token linked to an active payment plans retrieves an error message

- **Case ID:** 67606
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Validate that the API returns an error message (HTTP 400/409) with an appropriate reason.

---

## 5. Verify that, a clear error message is displayed when card token cannot be deleted from the Wallet

- **Case ID:** 67607
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Validate that the API returns a proper error response (e.g., HTTP 404)

---

## 6. Verify that, all types of cards can be deleted via API

- **Case ID:** 67608
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Ensure all can be successfully deleted unless restricted.

---

## 7. Verify that, once a deleted card token is removed, the details are also removed from the Wallet DB

- **Case ID:** 67609
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Query the wallet database to confirm that the token no longer exists after deletion.

---

