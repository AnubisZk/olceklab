import { beforeEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import bfiOverview from './fixtures/bfi_overview.json';
import bfiClean from './fixtures/bfi_clean.json';
import efaRec from './fixtures/bfi_efa.json';
import holzOverview from './fixtures/holz_overview.json';
import holzClean from './fixtures/holz_clean.json';
import prevDefault from './fixtures/holz_preview_default.json';
import prevCov from './fixtures/holz_preview_cov.json';
import prevSyntax from './fixtures/holz_preview_syntax.json';
import cfaRec from './fixtures/holz_cfa.json';
import cmpRec from './fixtures/holz_compare.json';
import relRec from './fixtures/holz_reliability.json';
import { renderApp, jsonResponse } from './renderApp';
import { palettes } from '../src/theme/tokens';
import { layoutPath } from '../src/components/charts/PathDiagram';
import type { PathData } from '../src/api/types';

// Fikstürler gerçek R motoru çıktısıdır (tests/fixtures/generate.R). Testler arayüzün R'nin
// sayılarını ve biçimli metinlerini değiştirmeden gösterdiğini, istek gövdelerinin ayarları
// doğru taşıdığını ve görünüm işlemlerinin (adlandırma, sıralama, gizleme) sayı üretmediğini denetler.

vi.mock('echarts/core', () => ({ use: vi.fn(), init: vi.fn(() => ({ setOption: vi.fn(), resize: vi.fn(), dispose: vi.fn() })) }));

interface Call { url: URL; method: string; body: Record<string, unknown> }
let calls: Call[] = [];

function mockEngine(example: 'bfi' | 'holzinger') {
  calls = [];
  vi.stubGlobal('fetch', vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const body = typeof init?.body === 'string' ? JSON.parse(init.body) : {};
    calls.push({ url, method: init?.method ?? 'GET', body });
    const p = url.pathname;
    if (p === '/versions') return jsonResponse({ R: 'x', packages: {}, missing: [], platform: '', blas: null, lapack: null, rng_kind: { kind: '', normal_kind: '', sample_kind: '' } });
    if (p.startsWith('/datasets/examples/')) return jsonResponse(example === 'bfi' ? bfiOverview : holzOverview);
    if (p.endsWith('/roles')) return jsonResponse({});
    if (p.endsWith('/clean')) return jsonResponse(example === 'bfi' ? bfiClean : holzClean);
    if (p === '/models/preview') {
      const m = body.model as { syntax?: string; covariances?: unknown[] } | undefined;
      if (m?.syntax) return jsonResponse(prevSyntax);
      if (m?.covariances?.length) return jsonResponse(prevCov);
      return jsonResponse(prevDefault);
    }
    if (p === '/analyses/efa') return jsonResponse(efaRec);
    if (p === '/analyses/cfa') return jsonResponse(cfaRec);
    if (p === '/analyses/cfa/compare') return jsonResponse(cmpRec);
    if (p === '/analyses/reliability') return jsonResponse(relRec);
    return jsonResponse({ error: { code: 'not_found', message_tr: 'yok' } }, 404);
  }));
}

async function loadAndClean(label: string) {
  await userEvent.click(screen.getByRole('button', { name: label }));
  await screen.findByTestId('n-rows');
  await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Temizlemeyi çalıştır' }));
  await screen.findByTestId('clean-summary');
}
type Fmt = Record<string, string>[];
const fmt = (rec: { tables: unknown[] }, i: number, lang: 'tr' | 'en' = 'tr') => (rec.tables[i] as { rows_fmt: Record<'tr' | 'en', Fmt> }).rows_fmt[lang];
const goto = async (name: string) => userEvent.click(screen.getByRole('link', { name: new RegExp(name) }));
const lastBody = (path: string) => [...calls].reverse().find((c) => c.url.pathname === path)!.body;

describe('M5 AFA sayfası', () => {
  beforeEach(() => mockEngine('bfi'));

  it('ayarlar sayı olarak gönderilir; yük tablosu R metinlerini gösterir', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: bfi (psych)');
    await goto('AFA');
    const n = await screen.findByRole('spinbutton', { name: 'Faktör sayısı' });
    await userEvent.clear(n); await userEvent.type(n, '5');
    await userEvent.click(screen.getByRole('button', { name: "AFA'yı çalıştır" }));
    const t1 = await waitFor(() => document.querySelector('[data-table-id="T1"]') as HTMLElement);
    const s = lastBody('/analyses/efa').settings as Record<string, unknown>;
    expect(s).toMatchObject({ nfactors: 5, fm: 'minres', rotate: 'oblimin', correlation: 'pearson', n_rotations: 20, threshold: 0.3, seed: 20261030 });
    const f1 = efaRec.results.factors[0];
    const firstRow = within(t1).getAllByRole('row')[1];
    expect(within(firstRow).getAllByRole('cell')[0]).toHaveTextContent(fmt(efaRec, 0)[0][f1]);
  });

  it('eşik altını gizleme R\'nin salient işaretine göre yapılır; yeniden adlandırma ve sıralama sayıları değiştirmez', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: bfi (psych)');
    await goto('AFA');
    await userEvent.click(await screen.findByRole('button', { name: "AFA'yı çalıştır" }));
    await waitFor(() => expect(document.querySelector('[data-table-id="T1"]')).not.toBeNull());
    const fac = efaRec.results.factors;
    const cells = () => Array.from(document.querySelectorAll('[data-table-id="T1"] tbody tr')).map((tr) => Array.from(tr.querySelectorAll('td')).slice(0, fac.length).map((td) => td.textContent));
    const before = cells();
    await userEvent.click(screen.getByRole('checkbox', { name: /altındaki katsayıları gizle/ }));
    const hidden = cells();
    efaRec.results.items.forEach((_, i) => fac.forEach((f, j) => {
      const sal = (efaRec.results.salient as Record<string, boolean[]>)[f][i];
      expect(hidden[i][j]).toBe(sal ? before[i][j] : '');
    }));
    await userEvent.click(screen.getByRole('checkbox', { name: /altındaki katsayıları gizle/ }));
    // Ad değiştir ve ilk faktörü sağa taşı
    const nameBox = screen.getByRole('textbox', { name: `${fac[0]} adı` });
    await userEvent.clear(nameBox); await userEvent.type(nameBox, 'Uyumluluk');
    await userEvent.click(screen.getByRole('button', { name: `${fac[0]} sütununu sağa taşı` }));
    const heads = Array.from(document.querySelectorAll('[data-table-id="T1"] thead th[data-factor]')).map((th) => th.textContent);
    expect(heads[0]).toBe(fac[1]); expect(heads[1]).toBe('Uyumluluk');
    const after = cells();
    efaRec.results.items.forEach((_, i) => { expect(after[i][0]).toBe(before[i][1]); expect(after[i][1]).toBe(before[i][0]); });
    // Faktör korelasyon tablosunda da ad görünür; değerler aynıdır
    const t3 = document.querySelector('[data-table-id="T3"]') as HTMLElement;
    expect(within(t3).getAllByRole('columnheader').map((h) => h.textContent)).toContain('Uyumluluk');
    // psych::fa.sort sırası
    await userEvent.click(screen.getByRole('checkbox', { name: /fa\.sort/ }));
    const rowsSorted = Array.from(document.querySelectorAll('[data-table-id="T1"] tbody th')).map((th) => th.textContent);
    expect(rowsSorted).toEqual(efaRec.results.sorted_items);
  });
});

describe('M6 DFA sayfası: model kurucu, ayar kilitleri, sonuç ve karşılaştırma', () => {
  beforeEach(() => mockEngine('holzinger'));

  it('varsayılan model R önizlemesinden gelir; madde taşıma ve hata kovaryansı istek gövdesine yansır', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('DFA');
    expect(await screen.findByTestId('model-syntax')).toHaveTextContent(prevDefault.syntax.split('\n')[0]);
    const visual = document.querySelector('[data-factor="visual"]') as HTMLElement;
    expect(within(visual).getAllByRole('listitem').map((li) => li.getAttribute('data-item'))).toEqual(['x1', 'x2', 'x3']);
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'x3 maddesinin faktörü' }), 'textual');
    await waitFor(() => {
      const m = lastBody('/models/preview').model as { factors: { name: string; items: string[] }[] };
      expect(m.factors.find((f) => f.name === 'textual')!.items).toEqual(['x3', 'x4', 'x5', 'x6']);
      expect(m.factors.find((f) => f.name === 'visual')!.items).toEqual(['x1', 'x2']);
    });
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'x3 maddesinin faktörü' }), 'visual');
    const covBoxes = within(screen.getByRole('group', { name: 'Hata kovaryansları' })).getAllByRole('combobox');
    await userEvent.selectOptions(covBoxes[0], 'x7');
    await userEvent.selectOptions(covBoxes[1], 'x8');
    await userEvent.click(screen.getByRole('button', { name: 'Ekle' }));
    await waitFor(() => expect((lastBody('/models/preview').model as { covariances: string[][] }).covariances).toEqual([['x7', 'x8']]));
    expect(await screen.findByTestId('model-syntax')).toHaveTextContent('x7 ~~ x8');
  });

  it('Bollen–Stine ve Wishart yalnızca ML ile seçilebilir; MLR seçilince kilitlenir', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('DFA');
    const bs = await screen.findByRole('checkbox', { name: 'Bollen–Stine bootstrap' });
    expect(bs).toBeEnabled();
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Kestirici' }), 'MLR');
    expect(bs).toBeDisabled();
    expect(screen.getByRole('combobox', { name: 'Olabilirlik' })).toBeDisabled();
    expect(screen.getByText(/Yalnızca ML kestiricisiyle/)).toBeInTheDocument();
  });

  it('ML + Wishart + Bollen–Stine isteği; uyum tablosu, Bollen–Stine tablosu ve yol şeması R değerlerini gösterir', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('DFA');
    await screen.findByTestId('model-syntax');
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Olabilirlik' }), 'wishart');
    await userEvent.click(screen.getByRole('checkbox', { name: 'Bollen–Stine bootstrap' }));
    const b = screen.getByRole('spinbutton', { name: 'Bootstrap sayısı (B)' });
    await userEvent.clear(b); await userEvent.type(b, '100');
    await userEvent.click(screen.getByRole('button', { name: "DFA'yı çalıştır" }));
    const t1 = await waitFor(() => document.querySelector('[data-table-id="T1"]') as HTMLElement);
    expect(lastBody('/analyses/cfa').settings).toMatchObject({ estimator: 'ML', likelihood: 'wishart', bootstrap: 100, std_lv: false, mi_top: 10 });
    const chi = fmt(cfaRec, 0).find((r) => r.key === 'chisq')!.value;
    expect(within(t1).getByText(chi)).toBeInTheDocument();
    expect(document.querySelector('[data-table-id="T6"]')).not.toBeNull();
    const path = cfaRec.figures[0].data as unknown as PathData;
    const l = path.loadings[1];
    expect(screen.getByTestId(`load-${l.factor}-${l.item}`)).toHaveTextContent(l.label_tr);
  });

  it('kaydedilen iki model karşılaştırılır; fark testi tablosu R metinlerini gösterir', async () => {
    await renderApp('/data');
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('DFA');
    await screen.findByTestId('model-syntax');
    await userEvent.click(screen.getByRole('button', { name: 'Modeli karşılaştırmaya ekle' }));
    await userEvent.click(screen.getByRole('button', { name: 'lavaan sözdizimi' }));
    const ta = screen.getByRole('textbox', { name: 'lavaan model sözdizimi' });
    await userEvent.clear(ta); await userEvent.type(ta, 'g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9');
    await userEvent.tab();
    await userEvent.click(screen.getByRole('button', { name: 'Modeli karşılaştırmaya ekle' }));
    await userEvent.click(screen.getByRole('button', { name: 'Modelleri karşılaştır' }));
    await waitFor(() => expect(calls.some((c) => c.url.pathname === '/analyses/cfa/compare')).toBe(true));
    const sent = lastBody('/analyses/cfa/compare').settings as { models: { name: string; model: { syntax?: string; factors?: unknown[] } }[] };
    expect(sent.models.map((m) => m.name)).toEqual(['Model 1', 'Model 2']);
    expect(sent.models[1].model.syntax).toBe('g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9');
    const t2 = await waitFor(() => document.querySelectorAll('[data-table-id="T2"]')[0] as HTMLElement);
    expect(t2).toHaveTextContent(fmt(cmpRec, 1)[0].chisq_diff);
  });
});

describe('M7 güvenirlik sayfası', () => {
  beforeEach(() => mockEngine('holzinger'));

  it('varsayılan HTMT ayarları (htmt2 = FALSE, absolute = TRUE, Pearson) gönderilir; tablolar R metinlerini gösterir', async () => {
    const { i18n } = await renderApp('/data');
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('Güvenirlik');
    await userEvent.click(await screen.findByRole('button', { name: 'Güvenirlik ve geçerliği hesapla' }));
    const t1 = await waitFor(() => document.querySelector('[data-table-id="T1"]') as HTMLElement);
    expect(lastBody('/analyses/reliability').settings).toMatchObject({
      estimator: 'ML', obs_var: true, htmt: { htmt2: false, absolute: true, correlation: 'pearson' }, thresholds: { cr: 0.7, ave: 0.5, htmt: 0.85 },
    });
    expect(t1).toHaveTextContent(fmt(relRec, 0)[0].omega);
    await i18n.changeLanguage('en');
    await waitFor(() => expect(document.querySelector('[data-table-id="T1"]')).toHaveTextContent(fmt(relRec, 0, 'en')[0].omega));
  });
});

describe('Yol şeması', () => {
  it('her madde ve faktör için konum üretir; renkler tema belirteçlerinden gelir', async () => {
    const data = cfaRec.figures[0].data as unknown as PathData;
    const L = layoutPath(data);
    expect(Object.keys(L.items)).toEqual(data.factors.flatMap((f) => f.items));
    expect(Object.keys(L.factors)).toEqual(data.factors.map((f) => f.name));
    mockEngine('holzinger');
    await renderApp('/data', { theme: 'light' });
    await loadAndClean('Örnek: HolzingerSwineford1939 (lavaan)');
    await goto('DFA');
    await screen.findByTestId('model-syntax');
    await userEvent.click(screen.getByRole('button', { name: "DFA'yı çalıştır" }));
    const svg = await screen.findByTestId('path-diagram');
    expect(svg.querySelector('ellipse')!.getAttribute('stroke')).toBe(palettes.light.accent);
  });
});
