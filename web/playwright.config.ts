import { defineConfig } from '@playwright/test';

// Uçtan uca testler çalışan servislere bağlanır (docker compose up ya da yerel süreçler).
// Adres: E2E_BASE_URL (varsayılan http://localhost:5173).
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 180_000,
  expect: { timeout: 120_000 },
  reporter: [['list'], ['junit', { outputFile: 'test-results/e2e.xml' }]],
  use: { baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5173', locale: 'tr-TR', trace: 'retain-on-failure' },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});
