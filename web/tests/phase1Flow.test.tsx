import { beforeEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import overview from './fixtures/bfi_overview.json';
import cleanRec from './fixtures/bfi_clean.json';
import itemRec from './fixtures/bfi_item.json';
import fnRec from './fixtures/bfi_factor_number.json';
import { renderApp, jsonResponse } from './renderApp';
import { palettes } from '../src/theme/tokens';

// Fikstürler gerçek R motoru çıktısıdır (tests/fixtures/generate.R). Testler arayüzün bu
// sayıları değiştirmeden gösterdiğini ve grafiğe aynen aktardığını denetler.

const chartOptions: Record<string, unknown>[] = [];
vi.mock('echarts/core', () => ({
  use: vi.fn(),
  init: vi.fn(() => ({ setOption: (o: Record<string, unknown>) => chartOptions.push(o), resize: vi.fn(), dispose: vi.fn() })),
}));

interface Call { url: URL; method: string; body: unknown }
let calls: Call[] = [];

function mockEngine() {
  calls = [];
  vi.stubGlobal('fetch', vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const method = init?.method ?? 'GET';
    let body: unknown = init?.body;
    if (typeof body === 'string') body = JSON.parse(body);
    calls.push({ url, method, body });
    const p = url.pathname;
    if (p === '/versions') return jsonResponse({ R: 'x', packages: {}, missing: [], platform: '', blas: null, lapack: null, rng_kind: { kind: '', normal_kind: '', sample_kind: '' } });
    if (p === '/datasets/examples/bfi' || p === '/datasets') return jsonResponse(overview);
    if (p.endsWith('/roles')) return jsonResponse({ dataset_id: overview.dataset_id });
    if (p.endsWith('/clean')) return jsonResponse(cleanRec);
    if (p === '/analyses/item') return jsonResponse(itemRec);
    if (p === '/analyses/factor-number') return jsonResponse(fnRec);
    return jsonResponse({ error: { code: 'not_found', message_tr: 'yok' } }, 404);
  }));
}

beforeEach(() => {
  chartOptions.length = 0;
  mockEngine();
});

async function loadAndClean() {
  await userEvent.click(screen.getByRole('button', { name: 'Örnek: bfi (psych)' }));
  expect(await screen.findByTestId('n-rows')).toHaveTextContent(String(overview.n_rows));
  await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Temizlemeyi çalıştır' }));
  return screen.findByTestId('clean-summary');
}

describe('Faz 1 akışı: veri → temizleme → madde analizi → faktör sayısı', () => {
  it('örnek veri önerilen rollerle dolar; kaydedilen gövde R önerisiyle aynı', async () => {
    await renderApp('/data');
    await userEvent.click(screen.getByRole('button', { name: 'Örnek: bfi (psych)' }));
    await screen.findByTestId('n-rows');
    expect(screen.getByRole('combobox', { name: 'A1 Rol' })).toHaveValue('item');
    expect(screen.getByRole('checkbox', { name: 'A1 Ters' })).toBeChecked();
    expect(screen.getByRole('combobox', { name: 'gender Rol' })).toHaveValue('group');
    await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
    await screen.findByText('Kaydedildi');
    const sent = calls.find((c) => c.url.pathname.endsWith('/roles'))!.body as {
      roles: Record<string, string>; items: Record<string, { min?: number; max?: number; reverse: boolean; subscale?: string }>;
    };
    for (const [col, role] of Object.entries(overview.suggested_config.roles)) expect(sent.roles[col]).toBe(role);
    for (const [item, cfg] of Object.entries(overview.suggested_config.items)) {
      expect(sent.items[item]).toEqual({ min: cfg.min, max: cfg.max, reverse: cfg.reverse, subscale: cfg.subscale });
    }
  });

  it('temizleme özeti ve tablolar R metinleriyle gösterilir; dil değişince İngilizce metin gelir', async () => {
    await renderApp('/data');
    const summary = await loadAndClean();
    expect(summary).toHaveTextContent(cleanRec.results.summary_tr);
    const t1 = document.querySelector('[data-table-id="T1"]') as HTMLElement;
    for (const row of cleanRec.tables[0].rows_fmt.tr as Record<string, string>[]) expect(within(t1).getAllByText(row.remaining).length).toBeGreaterThan(0);
    await userEvent.click(screen.getAllByRole('button', { name: 'EN' })[0]);
    expect(await screen.findByTestId('clean-summary')).toHaveTextContent(cleanRec.results.summary_en);
    await userEvent.click(screen.getAllByRole('button', { name: 'TR' })[0]);
  });

  it('madde analizi: tablo hücreleri R biçimidir, ısı haritası R verisini aynen alır', async () => {
    await renderApp('/data');
    await loadAndClean();
    await userEvent.click(screen.getByRole('link', { name: 'Madde analizine geç' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Madde analizini çalıştır' }));
    const t1 = (await waitFor(() => document.querySelector('[data-table-id="T1"]'))) as HTMLElement;
    const fmt = itemRec.tables[0].rows_fmt.tr as Record<string, string>[];
    const firstRow = within(t1).getAllByRole('row')[1];
    expect(firstRow).toHaveTextContent(fmt[0].item);
    expect(firstRow).toHaveTextContent(fmt[0].r_drop);
    expect(firstRow).toHaveTextContent(fmt[0].alpha_drop);
    const heat = chartOptions.at(-1) as { series: { data: [number, number, number | null][] }[] };
    const cell = heat.series[0].data.find(([j, i]) => i === 0 && j === 0)!;
    expect(cell[2]).toBe(itemRec.figures[0].data.proportions[0][0]);
    const codes = Array.from(document.querySelectorAll('.warnings li')).map((li) => li.getAttribute('data-code'));
    expect(codes).toEqual(itemRec.warnings.map((w) => w.code));
  });

  it('faktör sayısı: polikorik seçilince simüle referans kapanır; grafik ve karar metni R çıktısıdır', async () => {
    await renderApp('/data');
    await loadAndClean();
    await userEvent.click(screen.getByRole('link', { name: /Faktör sayısı/ }));
    const corr = await screen.findByRole('combobox', { name: 'Korelasyon' });
    await userEvent.selectOptions(corr, 'polychoric');
    const ref = screen.getByRole('combobox', { name: 'Referans veri' });
    expect(ref).toHaveValue('resampled_bootstrap');
    expect(within(ref).getByRole('option', { name: 'Simüle normal veri' })).toBeDisabled();
    await userEvent.selectOptions(corr, 'pearson');
    await userEvent.click(screen.getByRole('button', { name: 'Faktör sayısını belirle' }));
    expect(await screen.findByTestId('decision')).toHaveTextContent(fnRec.results.decision_tr);

    const sent = calls.find((c) => c.url.pathname === '/analyses/factor-number')!.body as { settings: Record<string, unknown> };
    expect(sent.settings).toMatchObject({ extraction: 'pc', n_iter: 1000, seed: 20261030, quant: 0.95 });

    const opt = chartOptions.at(-1) as { series: { data: number[] }[]; tooltip: { formatter: (p: unknown[]) => string } };
    const fig = fnRec.figures[0].data;
    expect(opt.series.map((s) => s.data)).toEqual([fig.pc_observed, fig.pc_reference, fig.fa_observed, fig.fa_reference]);
    const tip = opt.tooltip.formatter([{ seriesIndex: 0, dataIndex: 0, marker: '' }]);
    expect(tip).toContain(fig.labels.tr.pc_observed[0]);
  });

  it('"R kodunu indir" R motorunun ürettiği betiği aynen indirir', async () => {
    const blobs: Blob[] = [];
    vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: (b: Blob) => { blobs.push(b); return 'blob:x'; }, revokeObjectURL: vi.fn() }));
    await renderApp('/data');
    await loadAndClean();
    await userEvent.click(screen.getByRole('link', { name: /Faktör sayısı/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Faktör sayısını belirle' }));
    await screen.findByTestId('decision');
    await userEvent.click(screen.getByRole('button', { name: 'Bu analizin R kodunu indir' }));
    expect(blobs).toHaveLength(1);
    expect(await blobs[0].text()).toBe(fnRec.r_script);
  });

  it('tema değişince grafik renkleri tema belirteçlerinden yeniden alınır', async () => {
    await renderApp('/data', { theme: 'dark' });
    await loadAndClean();
    await userEvent.click(screen.getByRole('link', { name: /Faktör sayısı/ }));
    await userEvent.click(await screen.findByRole('button', { name: 'Faktör sayısını belirle' }));
    await screen.findByTestId('decision');
    type Opt = { series: { lineStyle: { color: string } }[]; yAxis: { splitLine: { lineStyle: { color: string } } } };
    expect((chartOptions.at(-1) as Opt).series[0].lineStyle.color).toBe(palettes.dark.accent);
    await userEvent.click(screen.getByRole('button', { name: 'Temayı değiştir' }));
    await waitFor(() => expect((chartOptions.at(-1) as Opt).series[0].lineStyle.color).toBe(palettes.light.accent));
    expect((chartOptions.at(-1) as Opt).yAxis.splitLine.lineStyle.color).toBe(palettes.light.border);
  });

  it('boş sayı alanı varsayılana sessizce dönmez; R doğrulasın diye olduğu gibi gönderilir', async () => {
    await renderApp('/data');
    await loadAndClean();
    await userEvent.click(screen.getByRole('link', { name: /Faktör sayısı/ }));
    const n = await screen.findByRole('spinbutton', { name: 'Yineleme sayısı' });
    await userEvent.clear(n);
    await userEvent.type(n, '200');
    expect(n).toHaveValue(200);
    await userEvent.clear(n);
    await userEvent.click(screen.getByRole('button', { name: 'Faktör sayısını belirle' }));
    await screen.findByTestId('decision');
    const sent = calls.filter((c) => c.url.pathname === '/analyses/factor-number').at(-1)!.body as { settings: { n_iter: unknown } };
    expect(sent.settings.n_iter).toBe('');
  });

  it('temizleme yapılmadan analiz sayfası analiz çalıştırmaz', async () => {
    await renderApp('/factor-number');
    expect(screen.getByText(/önce Veri sayfasında/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Faktör sayısını belirle' })).not.toBeInTheDocument();
  });
});

describe('AGENTS kuralı 10: ön yüz sayı biçimlendirmez', () => {
  it('kaynak kodda toFixed / toPrecision / toLocaleString / Intl.NumberFormat yok', () => {
    const files: string[] = [];
    const walk = (d: string) => readdirSync(d).forEach((f: string) => {
      const p = join(d, f);
      if (statSync(p).isDirectory()) walk(p); else if (/\.(ts|tsx)$/.test(p)) files.push(p);
    });
    walk(join(import.meta.dirname, '..', 'src'));
    expect(files.length).toBeGreaterThan(10);
    for (const f of files) {
      expect(readFileSync(f, 'utf8'), f).not.toMatch(/\.toFixed\(|\.toPrecision\(|\.toLocaleString\(|Intl\.NumberFormat/);
    }
  });
});
