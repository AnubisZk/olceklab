import { defineConfig } from '@playwright/test';
import base from './playwright.config';
export default defineConfig(base, {
  testDir: './tests/ai-e2e', workers: 1, outputDir: './test-results/ai',
  reporter: [['list'], ['junit', { outputFile: 'test-results/ai.xml' }]],
});
