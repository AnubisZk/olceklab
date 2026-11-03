import { readFileSync } from 'node:fs';
import { expect, test } from '@playwright/test';

// SPEC §12 Faz 5 kabulü: "Word raporu açılır; dışa aktarılan R betiği bağımsız çalışır ve aynı sonucu verir".
// Akış: HS1939 → DFA → rapora ekle → önizleme → Word raporu (indirilen dosya .docx zip'idir) → proje dışa aktarma
// → Başlangıç'ta içe aktarma → yeniden üretim (bütün analizler 17 basamakta aynı) → oturuma devam.

test('Faz 5 akışı: Word raporu, CSV, proje dışa/içe aktarma ve yeniden üretim', async ({ page }) => {
  test.setTimeout(300_000);
  await page.goto('/');
  await expect(page.getByText('Çalışıyor')).toBeVisible();
  await page.getByRole('link', { name: /Veri/ }).click();
  await page.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }).click();
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  await expect(page.getByTestId('clean-summary')).toBeVisible();
  await page.getByRole('link', { name: /DFA/ }).click();
  const rc = page.waitForResponse((r) => r.url().endsWith('/analyses/cfa'));
  await page.getByRole('button', { name: "DFA'yı çalıştır" }).click();
  const cfa = await (await rc).json();
  await page.getByRole('button', { name: 'Bu sonucu rapora ekle' }).click();
  const csvDl = page.waitForEvent('download');
  await page.getByRole('button', { name: 'CSV indir' }).first().click();
  expect((await csvDl).suggestedFilename()).toMatch(/_T1_bicimli\.csv$/);
  await page.getByRole('link', { name: /Rapor/ }).click();
  const rp = page.waitForResponse((r) => r.url().endsWith('/reports/preview'));
  await page.getByRole('button', { name: 'Metni önizle' }).click();
  const pv = await (await rp).json();
  const sentence = pv.items[0].results[0].map((s: { text: string }) => s.text).join('');
  await expect(page.locator('.report-preview')).toContainText(sentence);
  const chi = cfa.tables[0].rows_fmt.tr.find((r: { key: string }) => r.key === 'chisq').value;
  expect(sentence).toContain(chi);
  const docxDl = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Word raporu oluştur (.docx)' }).click();
  const docx = await docxDl;
  const bytes = readFileSync((await docx.path())!);
  expect(bytes.subarray(0, 2).toString()).toBe('PK');
  const zipDl = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Projeyi dışa aktar' }).click();
  const zipPath = (await (await zipDl).path())!;
  await page.getByRole('link', { name: /Başlangıç/ }).click();
  await page.getByLabel('Proje dosyası seç').setInputFiles(zipPath);
  await expect(page.getByTestId('project-summary')).toContainText('holzinger.csv');
  await page.getByRole('button', { name: 'Yeniden üret ve karşılaştır' }).click();
  await expect(page.getByTestId('project-result').getByRole('status')).toHaveText('Bütün sonuçlar 17 anlamlı basamakta aynı.');
  await page.getByRole('button', { name: 'Oturuma devam et' }).click();
  await page.getByRole('link', { name: /DFA/ }).click();
  await expect(page.locator('[data-table-id="T1"]')).toContainText(chi);
});
