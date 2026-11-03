import { defineConfig } from '@playwright/test';
import base from './playwright.config';

export default defineConfig(base, {
  testDir: './tests/online',
  workers: 1,
  timeout: 600_000,
  outputDir: './test-results/online',
  reporter: [['list'], ['junit', { outputFile: 'test-results/online.xml' }]],
  use: { baseURL: process.env.E2E_BASE_URL ?? 'https://olceklab.netlify.app' },
});
