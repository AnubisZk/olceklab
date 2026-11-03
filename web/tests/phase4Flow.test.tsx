import { beforeEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import holzOverview from './fixtures/holz_overview.json';
import holzClean from './fixtures/holz_clean.json';
import prevDefault from './fixtures/holz_preview_default.json';
import cfaRec from './fixtures/holz_cfa.json';
import popFromCfa from './fixtures/holz_population.json';
import estimate from './fixtures/sim_estimate.json';
import jobRunning from './fixtures/sim_job_running.json';
import jobDone from './fixtures/sim_job_done.json';
import simRec from './fixtures/sim_results.json';
import tr from '../src/i18n/locales/tr.json';
import { renderApp, jsonResponse } from './renderApp';

// Fikstürler gerçek R motoru çıktısıdır (tests/fixtures/generate.R): küçük bir simülasyon gerçekten çalıştırılmıştır.

vi.mock('echarts/core', () => ({ use: vi.fn(), init: vi.fn(() => ({ setOption: vi.fn(), resize: vi.fn(), dispose: vi.fn() })) }));

interface Call { url: URL; method: string; body: Record<string, unknown> }
let calls: Call[] = [];
let jobPolls = 0;
beforeEach(() => {
  calls = []; jobPolls = 0;
  vi.stubGlobal('fetch', vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const body = typeof init?.body === 'string' ? JSON.parse(init.body) : {};
    calls.push({ url, method: init?.method ?? 'GET', body });
    const p = url.pathname;
    if (p === '/versions') return jsonResponse({ R: 'x', packages: {}, missing: [], platform: '', blas: null, lapack: null, rng_kind: { kind: '', normal_kind: '', sample_kind: '' } });
    if (p.startsWith('/datasets/examples/')) return jsonResponse(holzOverview);
    if (p.endsWith('/roles')) return jsonResponse({});
    if (p.endsWith('/clean')) return jsonResponse(holzClean);
    if (p === '/models/preview') return jsonResponse(prevDefault);
    if (p === '/analyses/cfa') return jsonResponse(cfaRec);
    if (p === '/simulations/population/from-cfa') return jsonResponse(popFromCfa);
    if (p === '/simulations/estimate') return jsonResponse(estimate);
    if (p === '/simulations') return jsonResponse(jobRunning);
    if (p === `/jobs/${jobRunning.job_id}/cancel`) return jsonResponse({ ...jobRunning, status: 'cancelled' });
    if (p === `/jobs/${jobRunning.job_id}`) { jobPolls += 1; return jsonResponse(jobPolls < 2 ? jobRunning : jobDone); }
    if (p === `/simulations/${jobRunning.job_id}/results`) return jsonResponse(simRec);
    return jsonResponse({ error: { code: 'not_found', message_tr: 'yok' } }, 404);
  }));
});

const sent = (path: string) => calls.filter((c) => c.url.pathname === path).map((c) => c.body);
type Fmt = Record<string, string>[];
const fmt = (id: string) => (simRec.tables.find((t) => t.id === id) as unknown as { rows_fmt: Record<'tr', Fmt> }).rows_fmt.tr;

describe('M9 simülasyon sayfası', () => {
  it('kalıcı SİMÜLASYON etiketi; başlangıç tanımı ve süre tahmini R metniyle', async () => {
    await renderApp('/simulation');
    const ta0 = await screen.findByRole('textbox', { name: 'Popülasyon tanımı (JSON)' });
    expect(screen.getAllByRole('note')[0]).toHaveTextContent(tr.simulation.banner);
    expect(ta0).toBeInTheDocument();
    const ta = screen.getByRole('textbox', { name: 'Popülasyon tanımı (JSON)' }) as HTMLTextAreaElement;
    expect(JSON.parse(ta.value)).toMatchObject({ data_type: 'ordinal', groups: [{ name: 'A' }, { name: 'B' }], dif: [] });
    await userEvent.click(screen.getByRole('button', { name: 'Süreyi tahmin et' }));
    expect(await screen.findByTestId('sim-estimate')).toHaveTextContent(estimate.text.tr);
    expect(sent('/simulations/estimate')[0]).toMatchObject({
      conditions: { N: [300, 600, 1000], ratios: [[50, 50]] }, estimators: ['ML'], reps: 200, seed: 20261030, chunk_size: 50,
      analyses: { cfa: true, invariance: true, reliability: true, pa: { enabled: false, n_iter: 100, per_cell: true } },
      recommend: { power_step: 'auto' },
    });
    expect((sent('/simulations/estimate')[0].conditions as Record<string, unknown>).scenarios).toBeUndefined();
  });

  it('DIF senaryosu eklenir; oranlar ham hâliyle gider; bozuk JSON çalıştırmayı engeller', async () => {
    await renderApp('/simulation');
    await userEvent.type(await screen.findByRole('textbox', { name: 'Senaryo adı' }), 'y1 eşik');
    await userEvent.click(screen.getByRole('button', { name: 'Ekle' }));
    const ta = screen.getByRole('textbox', { name: 'Popülasyon tanımı (JSON)' }) as HTMLTextAreaElement;
    expect(JSON.parse(ta.value).dif).toEqual([{ name: 'y1 eşik', group: 'B', effects: [{ item: 'y1', type: 'threshold', size: 0.5 }] }]);
    const ratios = screen.getByRole('textbox', { name: 'Grup oranları (ör. 50/50; 70/30)' });
    await userEvent.clear(ratios); await userEvent.type(ratios, '50/50; 70/30');
    await userEvent.click(screen.getByRole('button', { name: 'Süreyi tahmin et' }));
    await screen.findByTestId('sim-estimate');
    expect(sent('/simulations/estimate')[0]).toMatchObject({ conditions: { ratios: [[50, 50], [70, 30]] }, population: { dif: [{ name: 'y1 eşik' }] } });
    await userEvent.clear(ta); await userEvent.type(ta, '{{ bozuk');
    await userEvent.tab();
    expect(await screen.findByRole('alert')).toHaveTextContent('JSON okunamadı');
    expect(screen.getByRole('button', { name: 'Simülasyonu başlat' })).toBeDisabled();
  });

  it('iş başlatılır, R ilerleme metni izlenir; bitince tablolar ve grafikler R değerleriyle gelir', async () => {
    await renderApp('/simulation');
    await userEvent.click(await screen.findByRole('button', { name: 'Simülasyonu başlat' }));
    const panel = await screen.findByTestId('job-panel');
    expect(within(panel).getByTestId('job-progress')).toHaveTextContent(jobRunning.text.tr.progress);
    expect(within(panel).getByRole('button', { name: 'İptal et' })).toBeEnabled();
    await waitFor(() => expect(screen.getByTestId('job-panel')).toHaveAttribute('data-status', 'done'), { timeout: 4000 });
    expect(screen.getByTestId('job-progress')).toHaveTextContent(jobDone.text.tr.progress);
    const t4 = await waitFor(() => { const el = document.querySelector('[data-table-id="T4"]'); expect(el).not.toBeNull(); return el as HTMLElement; });
    expect(t4).toHaveTextContent(fmt('T4')[0].reject_chisq);
    expect(document.querySelector('[data-table-id="T7"]')).toHaveTextContent(fmt('T7')[0].N);
    expect(document.querySelector('[data-table-id="T1"]')).toHaveTextContent(fmt('T1')[0].conv);
    const notes = screen.getAllByRole('note');
    expect(notes.length).toBeGreaterThanOrEqual(2);
    expect(screen.getByRole('heading', { name: 'Simülasyon sonuçları' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Bağımsız R paketini indir (.zip)' })).toBeInTheDocument();
  });

  it('iptal düğmesi iş uç noktasına gider', async () => {
    await renderApp('/simulation');
    await userEvent.click(await screen.findByRole('button', { name: 'Simülasyonu başlat' }));
    const panel = await screen.findByTestId('job-panel');
    await userEvent.click(within(panel).getByRole('button', { name: 'İptal et' }));
    await waitFor(() => expect(calls.some((c) => c.url.pathname === `/jobs/${jobRunning.job_id}/cancel` && c.method === 'POST')).toBe(true));
  });

  it('DFA sonucundan popülasyon: analiz kimliği ve kaydırma gönderilir; R notları gösterilir', async () => {
    await renderApp('/data');
    await userEvent.click(screen.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }));
    await screen.findByTestId('n-rows');
    await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
    await userEvent.click(await screen.findByRole('button', { name: 'Temizlemeyi çalıştır' }));
    await screen.findByTestId('clean-summary');
    await userEvent.click(screen.getByRole('link', { name: /^DFA/ }));
    await screen.findByTestId('model-syntax');
    await userEvent.click(screen.getByRole('button', { name: "DFA'yı çalıştır" }));
    await waitFor(() => expect(document.querySelector('[data-table-id="T1"]')).not.toBeNull());
    await userEvent.click(screen.getByRole('link', { name: /Simülasyon/ }));
    const shift = await screen.findByRole('spinbutton', { name: 'Duyarlılık kaydırması (yüklerden çıkarılır)' });
    await userEvent.clear(shift); await userEvent.type(shift, '0.05');
    await userEvent.click(screen.getByRole('button', { name: 'DFA sonucundan kur' }));
    await screen.findByText(popFromCfa.notes_tr[0]);
    expect(sent('/simulations/population/from-cfa')[0]).toEqual({ analysis_id: cfaRec.analysis_id, shift: 0.05 });
    const ta = screen.getByRole('textbox', { name: 'Popülasyon tanımı (JSON)' }) as HTMLTextAreaElement;
    expect(JSON.parse(ta.value).loadings).toEqual(popFromCfa.population.loadings);
  });
});
