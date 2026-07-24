import { test, expect } from '@playwright/test';
import { PaymentsClient } from '../../src/clients/payments.client';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('CNP @smoke — Auth', () => {
  test(
    'POST /authenticate returns bearerToken @smoke',
    {
      annotation: testmoCase(
        'CNP',
        'Validate that Payments authenticate returns a bearer token (CNP module setup)',
      ),
    },
    async ({ request }) => {
      const payments = new PaymentsClient(request);
      const token = await payments.authenticate();
      expect(token.length).toBeGreaterThan(20);
    },
  );
});
