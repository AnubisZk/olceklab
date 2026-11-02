import { describe, expect, it } from 'vitest';
import tr from '../src/i18n/locales/tr.json';
import en from '../src/i18n/locales/en.json';
import { initI18n } from '../src/i18n';
import { pages } from '../src/routes';

function flatten(obj: unknown, prefix = ''): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj as Record<string, unknown>)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object') Object.assign(out, flatten(v, key));
    else out[key] = String(v);
  }
  return out;
}

describe('çeviri dosyaları', () => {
  const ftr = flatten(tr);
  const fen = flatten(en);

  it('Türkçe ve İngilizce anahtarlar birebir aynı', () => {
    expect(Object.keys(fen).sort()).toEqual(Object.keys(ftr).sort());
  });

  it('boş çeviri yok', () => {
    for (const [k, v] of [...Object.entries(ftr), ...Object.entries(fen)]) {
      expect(v.trim(), k).not.toBe('');
    }
  });

  it('her sayfanın gezinme adı, başlığı ve açıklaması var', () => {
    for (const p of pages) {
      expect(ftr[`nav.${p.key}`]).toBeDefined();
      expect(ftr[`pages.${p.key}.title`]).toBeDefined();
      expect(ftr[`pages.${p.key}.description`]).toBeDefined();
    }
  });

  it('yer tutucular iki dilde aynı', () => {
    const vars = (s: string) => (s.match(/\{\{\s*\w+\s*\}\}/g) ?? []).sort();
    for (const k of Object.keys(ftr)) expect(vars(fen[k]), k).toEqual(vars(ftr[k]));
  });

  it('çeviri metinlerinde rakamla yazılmış istatistik değeri yok', () => {
    // Sayısal sonuçların tek kaynağı R motorudur (AGENTS kuralı 1).
    for (const [k, v] of Object.entries({ ...ftr, ...fen })) {
      expect(/\d[.,]\d/.test(v), k).toBe(false);
    }
  });
});

describe('dil ayarı', () => {
  it('varsayılan dil Türkçedir ve <html lang> güncellenir', async () => {
    const i18n = await initI18n();
    expect(i18n.language).toBe('tr');
    expect(document.documentElement.lang).toBe('tr');
    await i18n.changeLanguage('en');
    expect(document.documentElement.lang).toBe('en');
    await i18n.changeLanguage('tr');
  });
});
