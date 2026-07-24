import { defineConfig } from '@playwright/test';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '.env') });

/**
 * API-only regression suite (no browser).
 * Mirrors runnable STAGE paths from Wellfit Payments → 3 — Regression.
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  workers: 1,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: 'playwright-report' }],
    ['./src/reporters/testmo-pass-list.ts'],
  ],
  use: {
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
    ignoreHTTPSErrors: true,
  },
  projects: [
    {
      name: 'api-stage',
      testMatch: /.*\.spec\.ts/,
    },
  ],
});
