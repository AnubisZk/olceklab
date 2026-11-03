import { expect, test } from '@playwright/test';

// SPEC §11.5 (Faz 2 kısmı): HolzingerSwineford1939 → temizleme → AFA → DFA (ML, Wishart, Bollen–Stine)
// → rakip model karşılaştırması → güvenirlik. Gerçek R motoruna bağlanır; arayüzdeki metinler motorun
// yanıtındaki R biçimli metinlerle karşılaştırılır.

test('Faz 2 akışı gerçek R motoruyla çalışır; DFA, karşılaştırma ve güvenirlik tabloları R metinlerini gösterir', async ({ page }) => {
  test.setTimeout(240_000);
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();
  await page.getByRole('link', { name: /Veri/ }).click();
  await page.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }).click();
  await expect(page.getByTestId('n-rows')).toHaveText('301');
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  await expect(page.getByTestId('clean-summary')).toBeVisible();

  await page.getByRole('link', { name: /AFA/ }).click();
  await page.getByLabel('Faktör sayısı').fill('3');
  const efaResp = page.waitForResponse((r) => r.url().endsWith('/analyses/efa'));
  await page.getByRole('button', { name: "AFA'yı çalıştır" }).click();
  const efa = await (await efaResp).json();
  await expect(page.locator('[data-table-id="T1"] tbody tr').first()).toContainText(efa.tables[0].rows_fmt.tr[0][efa.results.factors[0]]);

  await page.getByRole('link', { name: /DFA/ }).click();
  await expect(page.getByTestId('model-syntax')).toContainText('visual =~ x1 + x2 + x3');
  await page.getByRole('combobox', { name: /^Olabilirlik/ }).selectOption('wishart');
  await page.getByLabel('Bollen–Stine bootstrap').check();
  await page.getByLabel('Bootstrap sayısı (B)').fill('100');
  const cfaResp = page.waitForResponse((r) => r.url().endsWith('/analyses/cfa'));
  await page.getByRole('button', { name: "DFA'yı çalıştır" }).click();
  const cfa = await (await cfaResp).json();
  expect(cfa.settings.lavaan_args).toMatchObject({ likelihood: 'wishart', test: 'bollen.stine', bootstrap: 100 });
  const chi = cfa.tables[0].rows_fmt.tr.find((r: Record<string, string>) => r.key === 'chisq').value;
  await expect(page.locator('[data-table-id="T1"]').first()).toContainText(chi);
  await expect(page.locator('[data-table-id="T6"]')).toBeVisible();
  await expect(page.getByTestId('path-diagram')).toBeVisible();

  await page.getByLabel('Karşılaştırma için model adı').fill('Üç faktör');
  await page.getByRole('button', { name: 'Modeli karşılaştırmaya ekle' }).click();
  await page.getByRole('button', { name: 'lavaan sözdizimi' }).click();
  await page.getByLabel('lavaan model sözdizimi').fill('g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9');
  await page.getByLabel('Karşılaştırma için model adı').fill('Tek faktör');
  await expect(page.getByTestId('model-syntax')).toContainText('g =~');
  await page.getByRole('button', { name: 'Modeli karşılaştırmaya ekle' }).click();
  const cmpResp = page.waitForResponse((r) => r.url().endsWith('/analyses/cfa/compare'));
  await page.getByRole('button', { name: 'Modelleri karşılaştır' }).click();
  const cmp = await (await cmpResp).json();
  expect(cmp.results.tests).toHaveLength(1);
  await expect(page.getByText(cmp.tables[1].rows_fmt.tr[0].chisq_diff)).toBeVisible();

  await page.getByLabel('lavaan model sözdizimi').fill('visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9');
  await page.getByLabel('Karşılaştırma için model adı').click();
  await expect(page.getByTestId('model-syntax')).toContainText('speed =~');
  await page.getByRole('link', { name: /Güvenirlik/ }).click();
  const relResp = page.waitForResponse((r) => r.url().endsWith('/analyses/reliability'));
  await page.getByRole('button', { name: 'Güvenirlik ve geçerliği hesapla' }).click();
  const rel = await (await relResp).json();
  expect(rel.settings.htmt).toEqual({ htmt2: false, absolute: true, correlation: 'pearson' });
  await expect(page.locator('[data-table-id="T1"]')).toContainText(rel.tables[0].rows_fmt.tr[0].omega);
  await expect(page.locator('[data-table-id="T2"]')).toContainText(rel.tables[1].rows_fmt.tr[1].visual);
});
