import { readFileSync } from 'node:fs';
import { expect, test } from '@playwright/test';

const engine = process.env.ENGINE_URL ?? 'https://osiriszk-olceklab-engine.hf.space';
// Simülasyon girdileri; beklenen istatistiksel sonuçlar yalnızca R yanıtlarından alınır.
const population = {
  factors: [{ name: 'F1', items: ['y1', 'y2', 'y3'] }, { name: 'F2', items: ['y4', 'y5', 'y6'] }],
  loadings: { y1: 0.7, y2: 0.6, y3: 0.65, y4: 0.7, y5: 0.6, y6: 0.7 },
  factor_cor: [{ a: 'F1', b: 'F2', r: 0.4 }], data_type: 'continuous', groups: [{ name: 'A' }],
};

test('çevrim içi motor: sürümler, CORS ve 2000 tekrar × koşul sınırı', async ({ request, baseURL }) => {
  const origin = new URL(baseURL!).origin;
  const health = await request.get(`${engine}/health`, { headers: { Origin: origin } });
  expect(health.ok()).toBe(true);
  expect((await health.json()).status).toBe('ok');
  expect(health.headers()['access-control-allow-origin']).toBe(origin);
  const versionsResponse = await request.get(`${engine}/versions`);
  expect(versionsResponse.ok()).toBe(true);
  const versions = await versionsResponse.json();
  const lock = JSON.parse(readFileSync(new URL('../../../engine/renv.lock', import.meta.url), 'utf8'));
  expect(versions.R).toBe(lock.R.Version);
  expect(versions.missing).toHaveLength(0);
  for (const [name, version] of Object.entries(versions.packages)) {
    expect(version, name).toBe(lock.Packages[name].Version.replaceAll('-', '.'));
  }
  const preflight = await request.fetch(`${engine}/simulations`, {
    method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type' },
  });
  expect(preflight.status()).toBe(204);
  expect(preflight.headers()['access-control-allow-origin']).toBe(origin);
  for (const method of ['GET', 'OPTIONS', 'POST']) {
    const denied = await request.fetch(`${engine}/health`, { method, headers: { Origin: 'https://blocked.example' } });
    expect(denied.status()).toBe(403);
    expect((await denied.json()).error.code).toBe('origin_not_allowed');
  }
  const limit = await request.post(`${engine}/simulations`, {
    headers: { Origin: origin },
    data: { population, conditions: { N: [300] }, estimators: ['ML'], reps: 2001 },
  });
  expect(limit.status()).toBe(422);
  expect((await limit.json()).error.code).toBe('online_limit');
});

test('canlı akış: temizleme → paralel analiz → DFA → N=300, 20 tekrar → Word', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();
  await page.getByRole('link', { name: /Veri/ }).click();
  await page.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }).click();
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await expect(page.getByText('Kaydedildi')).toBeVisible();
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  await expect(page.getByTestId('clean-summary')).toBeVisible();
  await page.getByRole('link', { name: /Faktör sayısı/ }).click();
  await page.getByLabel('Yineleme sayısı').fill('100');
  const parallelResponse = page.waitForResponse((r) => r.url().endsWith('/analyses/factor-number'));
  await page.getByRole('button', { name: 'Faktör sayısını belirle' }).click();
  const parallel = await parallelResponse;
  expect(parallel.ok()).toBe(true);
  await expect(page.getByTestId('decision')).toHaveText((await parallel.json()).results.decision_tr);
  await page.getByRole('link', { name: /DFA/ }).click();
  const cfaResponse = page.waitForResponse((r) => r.url().endsWith('/analyses/cfa'));
  await page.getByRole('button', { name: "DFA'yı çalıştır" }).click();
  const cfa = await cfaResponse;
  expect(cfa.ok()).toBe(true);
  const record = await cfa.json();
  const chi = record.tables[0].rows_fmt.tr.find((row: { key: string }) => row.key === 'chisq').value;
  await expect(page.locator('[data-table-id="T1"]')).toContainText(chi);
  await page.getByRole('button', { name: 'Bu sonucu rapora ekle' }).click();
  await page.getByRole('link', { name: /Simülasyon/ }).click();
  await page.locator('label:has-text("JSON yükle") input[type=file]').setInputFiles({
    name: 'population.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(population)),
  });
  await page.getByLabel('Toplam N listesi').fill('300');
  await page.getByLabel('Tekrar sayısı').fill('20');
  await page.getByLabel('Parça büyüklüğü (tekrar)').fill('10');
  await page.getByRole('button', { name: 'Simülasyonu başlat' }).click();
  await expect(page.getByTestId('job-panel')).toHaveAttribute('data-status', 'done', { timeout: 300_000 });
  await expect(page.locator('[data-table-id="T1"]')).toBeVisible();
  await page.getByRole('link', { name: /Rapor/ }).click();
  await page.getByRole('button', { name: 'Metni önizle' }).click();
  await expect(page.locator('.report-preview')).toContainText(chi);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Word raporu oluştur (.docx)' }).click();
  const docx = await download;
  expect(await docx.failure()).toBeNull();
  expect(docx.suggestedFilename()).toMatch(/\.docx$/);
  expect(readFileSync((await docx.path())!).subarray(0, 2).toString()).toBe('PK');
});
