import { test, expect } from '../../src/fixtures/auth.fixture';
import { PaymentsClient } from '../../src/clients/payments.client';
import { env } from '../../src/config/env';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('CNP — refund / void (TC10, TC12)', () => {
  test(
    'partial refund after process-card @smoke',
    {
      annotation: testmoCase(
        'CNP',
        'Validate that, a partial refund is able to get successfully processed for CNP transaction',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const payments = new PaymentsClient(request);
      const charge = await payments.processCard(paymentsBearer, {
        amount: 15.0,
        expirationDate: env.expirationDate,
        network: 'VI',
        token: env.tokenVisa,
      });
      expect(charge.status, JSON.stringify(charge.body)).toBe(200);
      expect(charge.transactionId).toBeTruthy();

      const refund = await payments.refund(paymentsBearer, {
        amount: 10.0,
        orderId: charge.orderId,
        originalTransactionId: charge.transactionId!,
        wasVoided: false,
      });
      expect(refund.status, JSON.stringify(refund.body)).toBe(200);
    },
  );

  test(
    'same-day void (wasVoided true) @smoke',
    {
      annotation: testmoCase(
        'CNP',
        'Validate that, a void transaction (Full refund under the same day window) is able to get successfully processed for CNP transaction',
      ),
    },
    async ({ request, paymentsBearer }) => {
      const payments = new PaymentsClient(request);
      const charge = await payments.processCard(paymentsBearer, {
        amount: 15.0,
        expirationDate: env.expirationDate,
        network: 'VI',
        token: env.tokenVisa,
      });
      expect(charge.status, JSON.stringify(charge.body)).toBe(200);
      expect(charge.transactionId).toBeTruthy();

      const voidRes = await payments.refund(paymentsBearer, {
        amount: 15.0,
        orderId: charge.orderId,
        originalTransactionId: charge.transactionId!,
        wasVoided: true,
      });
      expect(voidRes.status, JSON.stringify(voidRes.body)).toBe(200);
    },
  );

  parked(test, 'SQL Refunds / Voids tables (TC11, TC13)', SkipReason.SQL_MANUAL);
  parked(
    test,
    'Pay Page Wellfit GUID brands (TC14–TC17)',
    SkipReason.EPROTECT_PAYPAGE,
  );
});
