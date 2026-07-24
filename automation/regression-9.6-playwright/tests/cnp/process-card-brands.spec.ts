import { test, expect } from '../../src/fixtures/auth.fixture';
import { PaymentsClient } from '../../src/clients/payments.client';
import { cnpBrands } from '../../src/config/env';
import { testmoCase } from '../../src/helpers/testmo';

const testmoByBrand: Record<string, string> = {
  VISA: 'Validate that, CNP can process successful transactions with VISA Card.',
  AMEX: 'Validate that, CNP can process successful transactions with AMEX Card.',
  Discover:
    'Validate that, CNP can process successful transactions with Discover card.',
  MasterCard:
    'Validate that, CNP can process successful transactions with MasterCard.',
};

test.describe('CNP — process-card by brand (TC01–TC04)', () => {
  for (const brand of cnpBrands) {
    test(
      `process-card succeeds with ${brand.name} (${brand.network}) @smoke`,
      {
        annotation: testmoCase(
          'CNP',
          testmoByBrand[brand.name] ??
            `Validate that CNP process-card succeeds with ${brand.name}`,
        ),
      },
      async ({ request, paymentsBearer }) => {
        const payments = new PaymentsClient(request);
        const result = await payments.processCard(paymentsBearer, {
          amount: brand.amount,
          expirationDate: brand.expirationDate,
          network: brand.network,
          token: brand.token,
        });

        expect(result.status, JSON.stringify(result.body)).toBe(200);
        expect(result.transactionId, JSON.stringify(result.body)).toBeTruthy();
      },
    );
  }
});
