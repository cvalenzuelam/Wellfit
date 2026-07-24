import { test as base, APIRequestContext } from '@playwright/test';
import { PaymentsClient } from '../clients/payments.client';

type AuthFixtures = {
  paymentsBearer: string;
};

/**
 * Worker-scoped bearer so brand/refund suites share one authenticate call.
 */
export const test = base.extend<AuthFixtures>({
  paymentsBearer: [
    async ({ playwright }, use) => {
      const ctx: APIRequestContext = await playwright.request.newContext();
      try {
        const token = await new PaymentsClient(ctx).authenticate();
        await use(token);
      } finally {
        await ctx.dispose();
      }
    },
    { scope: 'worker' },
  ],
});

export { expect } from '@playwright/test';
