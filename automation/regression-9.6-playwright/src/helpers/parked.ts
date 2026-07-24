import type { test as baseTest } from '@playwright/test';

type TestApi = typeof baseTest;

/**
 * Register an intentionally skipped case.
 * Do NOT use `test.skip(title, reasonString)` — Playwright treats a string
 * second arg as `skip(condition, description)` and skips the whole suite.
 */
export function parked(t: TestApi, title: string, reason: string): void {
  t(title, async () => {
    t.skip(true, reason);
  });
}
