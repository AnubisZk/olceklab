import { expect, test } from '@playwright/test';

// SPEC §11.5 (Faz 3 kısmı): HolzingerSwineford1939, okul grupları → değişmezlik zinciri → skor testleri →
// onaylı serbest bırakma → kısmi zincir ve gizil ortalamalar. Arayüz metinleri motor yanıtındaki R metinleriyle aynıdır.

test('Faz 3 akışı: değişmezlik, kısmi değişmezlik sihirbazı ve gizil ortalamalar', async ({ page }) => {
  test.setTimeout(240_000);
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();
  await page.getByRole('link', { name: /Veri/ }).click();
  await page.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }).click();
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  await expect(page.getByTestId('clean-summary')).toBeVisible();
  await page.getByRole('link', { name: /Değişmezlik/ }).click();
  await page.getByLabel('Olabilirlik').selectOption('wishart');
  const r1 = page.waitForResponse((r) => r.url().endsWith('/analyses/invariance'));
  await page.getByRole('button', { name: 'Değişmezliği sına' }).click();
  const inv = await (await r1).json();
  expect(inv.settings.lavaan_args ?? inv.settings.steps.scalar.lavaan_args).toBeTruthy();
  await expect(page.locator('[data-table-id="T1"]')).toContainText(inv.tables[0].rows_fmt.tr[2].chisq);
  await expect(page.locator('[data-table-id="T3"]')).toContainText(inv.tables[2].rows_fmt.tr[1].d);
  await page.getByLabel('Skor testi yapılacak adım').selectOption('scalar');
  const r2 = page.waitForResponse((r) => r.url().endsWith('/analyses/invariance/score-tests'));
  await page.getByRole('button', { name: 'Skor testlerini hesapla' }).click();
  const sc = await (await r2).json();
  const first = sc.results.tests[0].free;
  await page.getByRole('button', { name: `${first} kısıtını serbest bırak` }).click();
  const r3 = page.waitForResponse((r) => r.url().endsWith('/analyses/invariance'));
  await page.getByRole('button', { name: 'Onayla' }).click();
  const inv2 = await (await r3).json();
  expect(inv2.settings.partial).toEqual([first]);
  await expect(page.locator('[data-table-id="T2"]')).toContainText(inv2.tables[1].rows_fmt.tr[1].chisq_diff);
});
