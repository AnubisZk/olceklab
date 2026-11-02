import { beforeEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import holzOverview from './fixtures/holz_overview.json';
import holzClean from './fixtures/holz_clean.json';
import prevDefault from './fixtures/holz_preview_default.json';
import invRec from './fixtures/holz_invariance.json';
import scoreRec from './fixtures/holz_scores.json';
import { renderApp, jsonResponse } from './renderApp';

// Fikstürler gerçek R motoru çıktısıdır (tests/fixtures/generate.R).

vi.mock('echarts/core', () => ({ use: vi.fn(), init: vi.fn(() => ({ setOption: vi.fn(), resize: vi.fn(), dispose: vi.fn() })) }));

interface Call { url: URL; body: Record<string, unknown> }
let calls: Call[] = [];
beforeEach(() => {
  calls = [];
  vi.stubGlobal('fetch', vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const body = typeof init?.body === 'string' ? JSON.parse(init.body) : {};
    calls.push({ url, body });
    const p = url.pathname;
    if (p === '/versions') return jsonResponse({ R: 'x', packages: {}, missing: [], platform: '', blas: null, lapack: null, rng_kind: { kind: '', normal_kind: '', sample_kind: '' } });
    if (p.startsWith('/datasets/examples/')) return jsonResponse(holzOverview);
    if (p.endsWith('/roles')) return jsonResponse({});
    if (p.endsWith('/clean')) return jsonResponse(holzClean);
    if (p === '/models/preview') return jsonResponse(prevDefault);
    if (p === '/analyses/invariance') return jsonResponse(invRec);
    if (p === '/analyses/invariance/score-tests') return jsonResponse(scoreRec);
    return jsonResponse({ error: { code: 'not_found', message_tr: 'yok' } }, 404);
  }));
});

const bodies = (path: string) => calls.filter((c) => c.url.pathname === path).map((c) => c.body.settings as Record<string, unknown>);
type Fmt = Record<string, string>[];
const fmt = (rec: { tables: unknown[] }, i: number) => (rec.tables[i] as { rows_fmt: Record<'tr', Fmt> }).rows_fmt.tr;

async function open() {
  await renderApp('/data');
  await userEvent.click(screen.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }));
  await screen.findByTestId('n-rows');
  await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Temizlemeyi çalıştır' }));
  await screen.findByTestId('clean-summary');
  await userEvent.click(screen.getByRole('link', { name: /Değişmezlik/ }));
}

describe('M8 değişmezlik sayfası ve kısmi değişmezlik sihirbazı', () => {
  it('varsayılan ayarlar gönderilir; adım, karşılaştırma ve gizil ortalama tabloları R metinlerini gösterir', async () => {
    await open();
    await userEvent.click(await screen.findByRole('button', { name: 'Değişmezliği sına' }));
    await waitFor(() => expect(document.querySelector('[data-table-id="T3"]')).not.toBeNull());
    expect(bodies('/analyses/invariance')[0]).toMatchObject({
      approach: 'continuous', estimator: 'ML', likelihood: 'normal', std_lv: true, include_strict: false, srmr_type: 'bentler_nomean',
      rule: 'none', d_sd: 'pooled', partial: [], criteria: { cfi: -0.01, rmsea: 0.015, srmr_load: 0.03, srmr_int: 0.01, alpha: 0.05 },
    });
    expect(document.querySelector('[data-table-id="T1"]')).toHaveTextContent(fmt(invRec, 0)[2].chisq);
    expect(document.querySelector('[data-table-id="T2"]')).toHaveTextContent(fmt(invRec, 1)[1].chisq_diff);
    expect(document.querySelector('[data-table-id="T3"]')).toHaveTextContent(fmt(invRec, 2)[1].d_ci);
  });

  it('kategorik yaklaşımda kestirici WLSMV\'ye kilitlenir ve olabilirlik seçilemez', async () => {
    await open();
    await userEvent.selectOptions(await screen.findByRole('combobox', { name: 'Yaklaşım' }), 'categorical');
    expect(screen.getByRole('combobox', { name: 'Kestirici' })).toBeDisabled();
    expect(screen.getByRole('combobox', { name: 'Olabilirlik' })).toBeDisabled();
    await userEvent.click(screen.getByRole('button', { name: 'Değişmezliği sına' }));
    await waitFor(() => expect(bodies('/analyses/invariance')[0]).toMatchObject({ approach: 'categorical', estimator: 'WLSMV' }));
  });

  it('sihirbaz: skor testleri sıralı gelir; serbest bırakma onay ister ve zinciri yeni group.partial ile yeniden çalıştırır', async () => {
    await open();
    await userEvent.click(await screen.findByRole('button', { name: 'Değişmezliği sına' }));
    await screen.findByRole('heading', { name: 'Kısmi değişmezlik sihirbazı' });
    await userEvent.selectOptions(screen.getByRole('combobox', { name: 'Skor testi yapılacak adım' }), 'scalar');
    await userEvent.click(screen.getByRole('button', { name: 'Skor testlerini hesapla' }));
    const table = await waitFor(() => document.querySelector('[data-table-id="score-tests"]') as HTMLElement);
    expect(bodies('/analyses/invariance/score-tests')[0]).toMatchObject({ step: 'scalar', partial: [] });
    const first = scoreRec.results.tests[0].free;
    const rows = within(table).getAllByRole('row');
    expect(rows[1]).toHaveAttribute('data-free', first);
    expect(rows[1]).toHaveTextContent(fmt(scoreRec, 0)[0].x2);
    await userEvent.click(within(rows[1]).getByRole('button', { name: `${first} kısıtını serbest bırak` }));
    expect(bodies('/analyses/invariance')).toHaveLength(1); // onay olmadan çalışmaz
    expect(screen.getByText(`${first} bütün gruplarda serbest bırakılsın mı?`)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(bodies('/analyses/invariance')).toHaveLength(2));
    expect(bodies('/analyses/invariance')[1].partial).toEqual([first]);
    expect(screen.getByTestId('scores-stale')).toBeInTheDocument();
    expect(screen.getByText('Veri güdümlü serbest bırakmalar bağımsız bir örneklemde doğrulanmalıdır (Byrne vd., 1989).')).toBeInTheDocument();
  });

  it('yükü serbest bırakılan maddenin kesişimi isteğe bağlı olarak eklenir (varsayılan kapalı)', async () => {
    await open();
    await userEvent.click(await screen.findByRole('button', { name: 'Değişmezliği sına' }));
    await screen.findByRole('heading', { name: 'Kısmi değişmezlik sihirbazı' });
    await userEvent.click(screen.getByRole('checkbox', { name: 'Yükü serbest bırakılan maddenin kesişimini de serbest bırak' }));
    await userEvent.click(screen.getByRole('button', { name: 'Skor testlerini hesapla' }));
    const table = await waitFor(() => document.querySelector('[data-table-id="score-tests"]') as HTMLElement);
    const load = scoreRec.results.tests.find((r) => r.free.includes('=~'))!.free;
    const row = within(table).getAllByRole('row').find((r) => r.getAttribute('data-free') === load)!;
    await userEvent.click(within(row).getByRole('button', { name: `${load} kısıtını serbest bırak` }));
    await userEvent.click(screen.getByRole('button', { name: 'Onayla' }));
    await waitFor(() => expect(bodies('/analyses/invariance')).toHaveLength(2));
    expect(bodies('/analyses/invariance')[1].partial).toEqual([load, `${load.split('=~')[1]}~1`]);
  });
});
