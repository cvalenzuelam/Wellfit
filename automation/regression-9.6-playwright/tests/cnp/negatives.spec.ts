import { test, expect } from '../../src/fixtures/auth.fixture';
import { PaymentsClient } from '../../src/clients/payments.client';
import { env } from '../../src/config/env';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('CNP — negatives', () => {
  test(
    'expired expirationDate is rejected (TC07 API validation) @smoke',
    {
      annotation: testmoCase(
        'CNP',
        'Validate that, CNP receives an error message when card is expired',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const payments = new PaymentsClient(request);
      const result = await payments.processCard(paymentsBearer, {
        amount: 10.04,
        expirationDate: '0120',
        network: 'VI',
        token: env.tokenVisa,
      });

      expect(result.status, JSON.stringify(result.body)).toBeGreaterThanOrEqual(
        400,
      );
      expect(result.status).toBeLessThan(500);
    },
  );

  parked(test, 'CVV mismatch via eProtect (TC05)', SkipReason.EPROTECT_PAYPAGE);
  parked(test, 'ZIP mismatch via eProtect (TC06)', SkipReason.EPROTECT_PAYPAGE);
  parked(test, 'SQL Amount / PaymentTypeMethod (TC08–TC09)', SkipReason.SQL_MANUAL);
});
