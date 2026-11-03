import { expect, test } from '@playwright/test';

// SPEC §12 Faz 4: simülasyon sayfası → süre tahmini → iş → iptal → sürdür → sonuçlar ve bağımsız paket.
// Ekrandaki metinler motorun R'de biçimlediği metinlerle aynıdır; SİMÜLASYON etiketi sayfada ve sonuçlarda kalıcıdır.

const population = {
  factors: [{ name: 'F1', items: ['y1', 'y2', 'y3'] }, { name: 'F2', items: ['y4', 'y5', 'y6'] }],
  loadings: { y1: 0.7, y2: 0.6, y3: 0.65, y4: 0.7, y5: 0.6, y6: 0.7 },
  factor_cor: [{ a: 'F1', b: 'F2', r: 0.4 }],
  data_type: 'continuous',
  groups: [{ name: 'A' }, { name: 'B', latent_means: { F1: 0.3 } }],
  dif: [{ name: 'y1 kesişim DIF', group: 'B', effects: [{ item: 'y1', type: 'intercept', size: 0.4 }] }],
};

test('Faz 4 akışı: simülasyon işi, iptal/sürdür, sonuçlar ve paket', async ({ page }) => {
  test.setTimeout(600_000);
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();
  await page.getByRole('link', { name: /Simülasyon/ }).click();
  await expect(page.getByRole('note').first()).toContainText('SİMÜLASYON');
  await page.locator('label:has-text("JSON yükle") input[type=file]').setInputFiles({
    name: 'population.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(population)),
  });
  await expect(page.getByLabel('Popülasyon tanımı (JSON)')).toHaveValue(/kesişim DIF/);
  await page.getByLabel('Toplam N listesi').fill('200, 400');
  await page.getByLabel('Tekrar sayısı').fill('40');
  await page.getByLabel('Parça büyüklüğü (tekrar)').fill('10');
  const re = page.waitForResponse((r) => r.url().endsWith('/simulations/estimate'));
  await page.getByRole('button', { name: 'Süreyi tahmin et' }).click();
  const est = await (await re).json();
  await expect(page.getByTestId('sim-estimate')).toContainText(est.text.tr);
  const rs = page.waitForResponse((r) => r.url().endsWith('/simulations') && r.request().method() === 'POST');
  await page.getByRole('button', { name: 'Simülasyonu başlat' }).click();
  const startResponse = await rs;
  const engineUrl = new URL(startResponse.url()).origin;
  const job = await startResponse.json();
  await expect(page.getByTestId('job-progress')).not.toHaveText(/^0 \//);
  await page.getByRole('button', { name: 'İptal et' }).click();
  await expect(page.getByTestId('job-panel')).toHaveAttribute('data-status', 'cancelled');
  await page.getByRole('button', { name: 'Sürdür' }).click();
  await expect(page.getByTestId('job-panel')).toHaveAttribute('data-status', 'done', { timeout: 540_000 });
  const res = await (await page.request.get(`${engineUrl}/simulations/${job.job_id}/results`)).json();
  const t4 = res.tables.find((t: { id: string }) => t.id === 'T4');
  await expect(page.locator('[data-table-id="T4"]')).toContainText(t4.rows_fmt.tr[0].reject_chisq);
  await expect(page.getByRole('note')).toHaveCount(2);
  const pkg = await page.request.get(`${engineUrl}/simulations/${job.job_id}/package`);
  expect(pkg.headers()['content-type']).toBe('application/zip');
});
