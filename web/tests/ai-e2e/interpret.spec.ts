import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { test, expect } from '@playwright/test';

test('AI mock → R değerleri → açık onay → etiketli Word ve oturum günlüğü', async ({ page }) => {
  await page.goto('/data');
  await page.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }).click();
  await page.getByRole('button', { name: 'Rolleri kaydet' }).click();
  await expect(page.getByText('Kaydedildi')).toBeVisible();
  await page.getByRole('button', { name: 'Temizlemeyi çalıştır' }).click();
  await expect(page.getByTestId('clean-summary')).toBeVisible();
  await page.getByRole('link', { name: /DFA/ }).click();
  const cfaRequest = page.waitForResponse(r => r.url().endsWith('/analyses/cfa'));
  await page.getByRole('button', { name: "DFA'yı çalıştır" }).click();
  const rec = await (await cfaRequest).json();
  const cfi = rec.tables.find((t: {id: string}) => t.id === 'T1').rows_fmt.tr.find((r: {key: string}) => r.key === 'cfi').value;
  const interpretation = page.waitForResponse(r => r.url().endsWith('/v1/interpret'));
  await page.getByRole('button', { name: 'Yapay zekâ ile yorumla' }).click();
  const ai = await (await interpretation).json();
  expect(ai.check.passed).toBe(true); expect(ai.text).toContain(cfi);
  await page.getByRole('button', { name: 'Rapora ekle (onaylıyorum)' }).click();
  await page.getByRole('link', { name: /Rapor/ }).click();
  const preview = page.waitForResponse(r => r.url().endsWith('/reports/preview'));
  await page.getByRole('button', { name: 'Metni önizle' }).click();
  expect((await (await preview).json()).items[0].ai[0].text).toBe(ai.text);
  await expect(page.locator('.report-preview')).toContainText(ai.label);
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Word raporu oluştur (.docx)' }).click();
  const docx = await download; const path = (await docx.path())!;
  expect(readFileSync(path).subarray(0, 2).toString()).toBe('PK');
  const python = process.env.PYTHON ?? (process.platform === 'win32' ? 'python' : 'python3');
  const xml = execFileSync(python, ['-c', 'import sys,zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read("word/document.xml"))', path], { encoding: 'utf8' });
  expect(xml).toContain(ai.label); expect(xml).toContain(ai.text); expect(xml).toContain('api / test-model');
  const rejected = await page.request.post(`${process.env.ENGINE_URL ?? 'http://localhost:8000'}/reports/preview`, {
    data: { analysis_ids: [rec.analysis_id], ai_texts: [{ record_id: rec.analysis_id, text: ai.text, check_passed: false, provider: 'api', model: 'test-model' }] },
  });
  expect(rejected.status()).toBe(422);
  await page.getByRole('link', { name: /Ayarlar/ }).click();
  const logDownload = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Günlüğü indir (JSON)' }).click();
  const log = JSON.parse(readFileSync((await (await logDownload).path())!, 'utf8'));
  expect(log[0].response).toContain('{{cfa.T1.cfi}}'); expect(log[0].check.passed).toBe(true);
  expect(JSON.stringify(log)).not.toContain('synthetic-test-key');
});
