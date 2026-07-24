import { test, expect } from '@playwright/test';
import { env } from '../../src/config/env';
import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('Wallet — auth smoke', () => {
  test(
    'POST /authenticate returns accessToken @smoke',
    {
      annotation: testmoCase(
        'Wallet',
        'Validate that Wallet authenticate returns accessToken (module setup)',
      ),
    },
    async ({ request }) => {
      const res = await request.post(`${env.walletUrl}/authenticate`, {
        data: {
          username: env.walletUsername,
          password: env.walletPassword,
        },
      });
      expect(res.status(), await res.text()).toBe(200);
      const body = (await res.json()) as Record<string, unknown>;
      const token =
        (body.accessToken as string | undefined) ??
        (body.bearerToken as string | undefined) ??
        (body.access_token as string | undefined);
      expect(token, `keys: ${Object.keys(body).join(',')}`).toBeTruthy();
    },
  );

  parked(
    test,
    'Wallet B TC03/TC04 subscription / payment plan',
    SkipReason.WALLET_SUBSCRIPTION_FIXTURE,
  );
});
