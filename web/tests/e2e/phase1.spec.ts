import { expect, test } from '@playwright/test';

// SPEC §11.5 (Faz 1 kısmı): örnek veri → temizleme → madde analizi → paralel analiz.
// Gerçek R motoruna bağlanır; beklenen sayılar arayüzde değil, motorun yanıtında denetlenir.

test('Faz 1 akışı gerçek R motoruyla çalışır ve paralel analiz grafiği ile tablosu görünür', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();

  await page.getByRole('link', { name: /Veri/ }).click();
  await page.getByRole('button', { name: 'Örnek: bfi (psych)' }).click();
  await expect(page.getByTestId('n-rows')).toHaveText('2800');
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await expect(page.getByText('Kaydedildi')).toBeVisible();

  const cleanResp = page.waitForResponse((r) => r.url().endsWith('/clean'));
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  const clean = await (await cleanResp).json();
  await expect(page.getByTestId('clean-summary')).toHaveText(clean.results.summary_tr);

  await page.getByRole('link', { name: 'Madde analizine geç' }).click();
  const itemResp = page.waitForResponse((r) => r.url().endsWith('/analyses/item'));
  await page.getByRole('button', { name: 'Madde analizini çalıştır' }).click();
  const item = await (await itemResp).json();
  await expect(page.locator('[data-table-id="T1"] tbody tr').first()).toContainText(item.tables[0].rows_fmt.tr[0].r_drop);

  await page.getByRole('link', { name: /Faktör sayısı/ }).click();
  await page.getByLabel('Yineleme sayısı').fill('200');
  const fnResp = page.waitForResponse((r) => r.url().endsWith('/analyses/factor-number'));
  await page.getByRole('button', { name: 'Faktör sayısını belirle' }).click();
  const fn = await (await fnResp).json();
  expect(fn.results.psych_check.ncomp).toBe(fn.results.pc.suggested);
  await expect(page.getByTestId('decision')).toHaveText(fn.results.decision_tr);
  await expect(page.getByRole('img', { name: 'Gözlenen ve referans özdeğerlerin scree grafiği' }).locator('svg')).toBeVisible();
  await expect(page.locator('[data-table-id="T1"]')).toContainText(fn.tables[0].rows_fmt.tr[0].pc_obs);
});
