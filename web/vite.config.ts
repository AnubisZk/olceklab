/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: { host: '0.0.0.0', port: 5173, strictPort: true },
  preview: { host: '0.0.0.0', port: 5173, strictPort: true },
  test: {
    // JSDOM ve lazy rota derlemelerinin aynı CPU için yarışmasını önler.
    // Yalıtım ve testlerin mevcut bekleme/başarı ölçütleri değişmez.
    maxWorkers: 1,
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
    exclude: ['tests/e2e/**', 'node_modules/**'],
    css: false,
  },
});
