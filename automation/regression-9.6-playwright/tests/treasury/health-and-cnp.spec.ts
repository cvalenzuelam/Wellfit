import { test, expect } from '@playwright/test';
import { PaymentsClient } from '../../src/clients/payments.client';
import { TreasuryClient } from '../../src/clients/treasury.client';
import { env } from '../../src/config/env';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('Treasury — shared + CNP Payment API slice (C)', () => {
  test(
    'GET /health @smoke',
    {
      annotation: testmoCase(
        'Treasury',
        'Validate that Treasury /health returns 200 (shared setup)',
      ),
    },
    async ({ request }) => {
      const treasury = new TreasuryClient(request);
      const health = await treasury.health();
      expect(health.status, JSON.stringify(health.body)).toBe(200);
    },
  );

  test(
    'CNP process-card seed for funding path @smoke',
    {
      annotation: [
        ...testmoCase(
          'Treasury',
          'Validate that POST CNP /payments API is 200 OK',
        ),
        {
          type: 'testmo',
          description:
            'Validate that CNP Payment can be successfully sent to the system',
        },
      ],
    },
    async ({ request }) => {
      const payments = new PaymentsClient(request);
      const bearer = await payments.authenticate();
      const charge = await payments.processCard(bearer, {
        amount: 1.15,
        expirationDate: env.expirationDate,
        network: 'VI',
        token: env.tokenVisa,
        subMerchantId: env.subMerchantId,
      });
      expect(charge.status, JSON.stringify(charge.body)).toBe(200);
      expect(charge.transactionId).toBeTruthy();
    },
  );

  test('create + send funding batch (opt-in)', async ({ request }) => {
    test.skip(!env.runTreasuryFunding, SkipReason.TREASURY_FUNDING_OPT_IN);

    const treasury = new TreasuryClient(request);
    const create = await treasury.createFundingBatch();
    expect([200, 202]).toContain(create.status);

    const send = await treasury.sendFundingBatch();
    expect([200, 202]).toContain(send.status);
  });

  parked(
    test,
    'SQL SettlementDate / FundingInstructions (C TC03–TC09)',
    SkipReason.SQL_MANUAL,
  );
  parked(
    test,
    'ACH Payment/Refund seed via payments-v2 (E/F TC02)',
    SkipReason.ACH_V2_SEED_UNSTABLE,
  );
});
