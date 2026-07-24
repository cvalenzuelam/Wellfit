import { test, expect } from '@playwright/test';
import { env } from '../../src/config/env';
import { testmoCase } from '../../src/helpers/testmo';

test.describe('Wellfit Provisioning — auth smoke', () => {
  test(
    'POST /authenticate 200 @smoke',
    {
      annotation: testmoCase(
        'Wellfit Provisioning',
        'Verify that, from Wellfit Provisioning authenticate API is working 200 ok',
      ),
    },
    async ({ request }) => {
      const res = await request.post(`${env.mpUrl}/authenticate`, {
        data: {
          username: env.mpUsername,
          password: env.mpPassword,
        },
      });
      expect(res.status(), await res.text()).toBe(200);
    },
  );
});
