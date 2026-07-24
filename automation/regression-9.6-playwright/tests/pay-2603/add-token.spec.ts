import { test, expect } from '../../src/fixtures/auth.fixture';
import { TokenVaultClient } from '../../src/clients/tokenVault.client';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('PAY-2603 — add-token zip optional (TC01–TC03, TC05)', () => {
  test(
    'add-token without cardZipCode @smoke',
    {
      annotation: testmoCase(
        'PAY-2603',
        'Verify that, Add Token API works successfully without cardZipCode',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const vault = new TokenVaultClient(request);
      const result = await vault.addToken(paymentsBearer, { omitZip: true });
      expect(result.status, JSON.stringify(result.body)).toBe(200);
    },
  );

  test(
    'add-token with cardZipCode @smoke',
    {
      annotation: testmoCase(
        'PAY-2603',
        'Validate that, a token is created successfully when cardZipCode is provided',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const vault = new TokenVaultClient(request);
      const result = await vault.addToken(paymentsBearer, {
        cardZipCode: '01803',
      });
      expect(result.status, JSON.stringify(result.body)).toBe(200);
    },
  );

  test('add-token with empty string cardZipCode', async ({
    request,
    paymentsBearer,
  }) => {
    const vault = new TokenVaultClient(request);
    const result = await vault.addToken(paymentsBearer, { cardZipCode: '' });
    expect(result.status, JSON.stringify(result.body)).toBe(200);
  });

  parked(
    test,
    'invalid cardZipCode rejected (TC04)',
    SkipReason.PAY2603_INVALID_ZIP_BUG,
  );
  parked(
    test,
    'CP add-token / alert inject (TC06–07, TC12)',
    SkipReason.CP_PHYSICAL_LANE,
  );
  parked(test, 'SQL PaymentTokens asserts (TC09)', SkipReason.SQL_MANUAL);
});
