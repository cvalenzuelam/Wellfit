import { test, expect } from '../../src/fixtures/auth.fixture';
import { PaymentsClient } from '../../src/clients/payments.client';
import { TokenVaultClient } from '../../src/clients/tokenVault.client';
import { env } from '../../src/config/env';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('TokenVault — CNP charge with processor token / GUID (TC01–TC02)', () => {
  test(
    'process-card with processor token @smoke',
    {
      annotation: testmoCase(
        'TokenVault',
        'Ensure CNP V1 endpoint is able to make a successful payment with processor token',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const payments = new PaymentsClient(request);
      const result = await payments.processCard(paymentsBearer, {
        amount: 11.01,
        expirationDate: env.expirationDate,
        network: 'VI',
        token: env.tokenVisa,
      });
      expect(result.status, JSON.stringify(result.body)).toBe(200);
      expect(result.transactionId).toBeTruthy();
    },
  );

  test(
    'add-token GUID then process-card with Wellfit token @smoke',
    {
      annotation: testmoCase(
        'TokenVault',
        'Ensure CNP V1 endpoint is able to make a successful payment with token GUID',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const payments = new PaymentsClient(request);
      const vault = new TokenVaultClient(request);

      const added = await vault.addToken(paymentsBearer);
      expect(added.status, JSON.stringify(added.body)).toBe(200);

      const result = await payments.processCard(paymentsBearer, {
        amount: 11.02,
        expirationDate: env.expirationDate,
        network: 'VI',
        token: added.id,
      });
      expect(result.status, JSON.stringify(result.body)).toBe(200);
      expect(result.transactionId).toBeTruthy();
    },
  );

  parked(test, 'Pay Page tokenType path (TC03 / TC11)', SkipReason.EPROTECT_PAYPAGE);
  parked(test, 'SQL PaymentTypeMethod asserts', SkipReason.SQL_MANUAL);
});
