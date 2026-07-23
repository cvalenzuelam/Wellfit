# PAY-1128 MyWallet: Adding New Cards

Cases: **8**

## 1. Verify that, authenticate API req res is successful

- **Case ID:** 67588
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Successful response (HTTP 200/201) and retrieve the access token.

---

## 2. Verify that, create-wallet API req res retrieves a successful response

- **Case ID:** 67589
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Validate the response for expected fields (wallet token ID, creation timestamp).

---

## 3. Verify that, a new card token can be added to a Wallet via API

- **Case ID:** 67590
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Verify that the API response confirms successful addition (HTTP 200/201)

---

## 4. Verify that executing a query from the Wallet DB will retrieve the Wallet and Card token logs

- **Case ID:** 67591
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Query the wallet database to confirm a new entry with the correct user ID, wallet ID, and token details.

---

## 5. Verify that, card number, expiration date, CVV, zip/postal code,  input validations errors are returned via API

- **Case ID:** 67592
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Validate that the API returns appropriate error messages and status codes (HTTP 400)

---

## 6. Verify that, create-card token API returns a confirmation response after successfully adding a new card

- **Case ID:** 67593
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Ensure the response includes a success message, card token, wallet ID, and timestamps
Check the Wallet DB to confirm the card/token entry exists

---

## 7. Verify that the card token generation  is logged in the DB

- **Case ID:** 67594
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

Query the wallet database to confirm a new entry with the correct user ID, wallet ID, and token details.

---

## 8. Validate Wallet Tokenize Transaction - TokenId Stored in Wallet DB

- **Case ID:** 67595
- **Priority:** Normal
- **Status (at export):** Untested

### Expected

The resultant tokenId is correctly generated and stored in the Wallet DB.The tokenId can be queried and found in the Wallet DB.API response: HTTP 200 OK (or equivalent success response indicating successful tokenization and storage).

---

