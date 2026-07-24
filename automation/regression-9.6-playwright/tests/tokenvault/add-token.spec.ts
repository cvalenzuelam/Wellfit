import { test, expect } from '../../src/fixtures/auth.fixture';
import { TokenVaultClient } from '../../src/clients/tokenVault.client';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('TokenVault — add-token / get-token-details (TC08)', () => {
  test(
    'add-token then get-token-details @smoke',
    {
      annotation: testmoCase(
        'TokenVault',
        'Ensure, Token is able to add successfully and able to save into token valut DB when tokenVaultAPI/add-token end point runs',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const vault = new TokenVaultClient(request);
      const added = await vault.addToken(paymentsBearer);
      expect(added.status, JSON.stringify(added.body)).toBe(200);

      const details = await vault.getTokenDetails(paymentsBearer, added.id);
      expect(details.status, JSON.stringify(details.body)).toBe(200);
    },
  );

  parked(test, 'SQL TokenVault PaymentTokens (Visualize)', SkipReason.SQL_MANUAL);
});
