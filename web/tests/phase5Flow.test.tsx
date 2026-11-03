import { beforeEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import holzOverview from './fixtures/holz_overview.json';
import holzClean from './fixtures/holz_clean.json';
import prevDefault from './fixtures/holz_preview_default.json';
import cfaRec from './fixtures/holz_cfa.json';
import preview from './fixtures/holz_report_preview.json';
import projSummary from './fixtures/project_summary.json';
import projRepro from './fixtures/project_reproduction.json';
import tr from '../src/i18n/locales/tr.json';
import { renderApp, jsonResponse } from './renderApp';

// Fikstürler gerçek R motoru çıktısıdır (tests/fixtures/generate.R): rapor önizlemesi ve proje dışa → içe aktarma →
// yeniden üretim motorun kendi kod yolundan geçirilmiştir.

vi.mock('echarts/core', () => ({ use: vi.fn(), init: vi.fn(() => ({ setOption: vi.fn(), resize: vi.fn(), dispose: vi.fn() })) }));

interface Call { url: URL; method: string; body: unknown }
let calls: Call[] = [];
let uploadSource: 'example' | 'upload' = 'example';
const saved: string[] = [];
beforeEach(() => {
  calls = []; saved.length = 0; uploadSource = 'example';
  vi.stubGlobal('URL', Object.assign(URL, { createObjectURL: vi.fn(() => 'blob:x'), revokeObjectURL: vi.fn() }));
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function (this: HTMLAnchorElement) { saved.push(this.download); });
  vi.stubGlobal('fetch', vi.fn(async (input: string, init?: RequestInit) => {
    const url = new URL(input);
    const body = typeof init?.body === 'string' ? JSON.parse(init.body) : init?.body;
    calls.push({ url, method: init?.method ?? 'GET', body });
    const p = url.pathname;
    const blob = (type: string) => new Response(new Blob(['PK'], { type }), { status: 200, headers: { 'Content-Type': type } });
    if (p === '/versions') return jsonResponse({ R: 'x', packages: {}, missing: [], platform: '', blas: null, lapack: null, rng_kind: { kind: '', normal_kind: '', sample_kind: '' } });
    if (p.startsWith('/datasets/examples/')) return jsonResponse(holzOverview);
    if (p === '/datasets') return jsonResponse({ ...holzOverview, source: { type: uploadSource, delimiter: ',' } });
    if (p.endsWith('/roles')) return jsonResponse({});
    if (p.endsWith('/clean')) return jsonResponse(holzClean);
    if (p === '/models/preview') return jsonResponse(prevDefault);
    if (p === '/analyses/cfa') return jsonResponse(cfaRec);
    if (p === '/reports/preview') return jsonResponse(preview);
    if (p === '/reports/docx') return blob('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    if (p.endsWith('/csv')) return blob('text/csv');
    if (p === '/projects/export') return blob('application/zip');
    if (p === '/projects/import') return jsonResponse(projSummary);
    if (p === `/projects/${projSummary.project_id}/reproduce`) return jsonResponse(projRepro);
    return jsonResponse({ error: { code: 'not_found', message_tr: 'yok' } }, 404);
  }));
});

const sent = (path: string) => calls.filter((c) => c.url.pathname === path);

async function cleanHolz(upload = false) {
  await renderApp('/data');
  if (upload) {
    uploadSource = 'upload';
    const input = document.querySelector('input[type=file]') as HTMLInputElement;
    await userEvent.upload(input, new File(['x1,x2\n1,2\n'], 'hs.csv', { type: 'text/csv' }));
  } else {
    await userEvent.click(screen.getByRole('button', { name: 'Örnek: HolzingerSwineford1939 (lavaan)' }));
  }
  await screen.findByTestId('n-rows');
  await userEvent.click(screen.getByRole('button', { name: 'Rolleri kaydet' }));
  await userEvent.click(await screen.findByRole('button', { name: 'Temizlemeyi çalıştır' }));
  await screen.findByTestId('clean-summary');
}
async function runCfa() {
  await userEvent.click(screen.getByRole('link', { name: /DFA/ }));
  await screen.findByTestId('model-syntax');
  await userEvent.click(screen.getByRole('button', { name: "DFA'yı çalıştır" }));
  await waitFor(() => expect(document.querySelector('[data-table-id="T1"]')).not.toBeNull());
}

describe('M10 rapor', () => {
  it('DFA sonucu rapora eklenir; önizleme R metnini italikleriyle gösterir; Word raporu istenir', async () => {
    await cleanHolz();
    await runCfa();
    await userEvent.click(screen.getByRole('button', { name: tr.result.addToReport }));
    expect(screen.getByRole('button', { name: tr.result.inReport })).toHaveAttribute('aria-pressed', 'true');
    await userEvent.click(screen.getByRole('link', { name: /Rapor/ }));
    const list = await screen.findByTestId('report-items');
    expect(within(list).getByText(tr.report.modules.cfa)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: tr.report.preview }));
    await screen.findByRole('heading', { name: tr.report.previewTitle });
    expect(sent('/reports/preview')[0].body).toEqual({ analysis_ids: [cfaRec.analysis_id], lang: 'tr' });
    const seg = preview.items[0].results[0];
    const para = screen.getByText((_, el) => el?.tagName === 'P' && el.textContent === seg.map((s) => s.text).join(''));
    expect(para.querySelectorAll('em')).toHaveLength(seg.filter((s) => s.italic).length);
    for (const r of preview.references) expect(screen.getByText(r)).toBeInTheDocument();
    await userEvent.type(screen.getByRole('textbox', { name: tr.report.docTitle }), 'Tez raporu');
    await userEvent.click(screen.getByRole('button', { name: tr.report.docx }));
    await waitFor(() => expect(saved).toContain('olceklab_rapor.docx'));
    expect(sent('/reports/docx')[0].body).toEqual({ analysis_ids: [cfaRec.analysis_id], lang: 'tr', title: 'Tez raporu' });
  });

  it('rapor sırası değiştirilir ve sonuç çıkarılır', async () => {
    await cleanHolz();
    await runCfa();
    await userEvent.click(screen.getByRole('button', { name: tr.result.addToReport }));
    await userEvent.click(screen.getByRole('link', { name: /Rapor/ }));
    await userEvent.click(await screen.findByRole('button', { name: tr.report.remove }));
    expect(await screen.findByText(tr.report.empty)).toBeInTheDocument();
  });

  it('tablo CSV olarak indirilir (ham değer seçeneği R uç noktasına gider)', async () => {
    await cleanHolz();
    await runCfa();
    await userEvent.selectOptions(screen.getAllByRole('combobox', { name: tr.result.csvTable })[0], 'T2');
    await userEvent.click(screen.getAllByRole('checkbox', { name: tr.result.csvRaw })[0]);
    await userEvent.click(screen.getAllByRole('button', { name: tr.result.csvDownload })[0]);
    await waitFor(() => expect(saved.some((f) => f.endsWith('_T2_ham.csv'))).toBe(true));
    const c = calls.find((x) => x.url.pathname.endsWith('/csv'))!;
    expect(c.url.pathname).toBe(`/analyses/${cfaRec.analysis_id}/tables/T2/csv`);
    expect(Object.fromEntries(c.url.searchParams)).toEqual({ lang: 'tr', values: 'raw' });
  });
});

describe('M12 proje dosyası', () => {
  it('dışa aktarma: örnek veride veri eklenmez; temizleme ve ekrandaki sonuçların kimlikleri gider', async () => {
    await cleanHolz();
    await runCfa();
    await userEvent.click(screen.getByRole('link', { name: /Rapor/ }));
    expect(await screen.findByText(tr.report.projectExample)).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: tr.report.exportProject }));
    await waitFor(() => expect(saved.some((f) => f.endsWith('.olceklab.zip'))).toBe(true));
    expect(sent('/projects/export')[0].body).toEqual({ dataset_id: holzOverview.dataset_id, analysis_ids: [holzClean.analysis_id, cfaRec.analysis_id],
                                                       include_data: false, data_consent: false });
  });

  it('yüklenen veride veri dosyası yalnızca açık onayla eklenir', async () => {
    await cleanHolz(true);
    await userEvent.click(screen.getByRole('link', { name: /Rapor/ }));
    await userEvent.click(await screen.findByRole('checkbox', { name: tr.report.includeData }));
    const exp = screen.getByRole('button', { name: tr.report.exportProject });
    expect(exp).toBeDisabled();
    await userEvent.click(screen.getByRole('checkbox', { name: tr.report.consent }));
    expect(exp).toBeEnabled();
    await userEvent.click(exp);
    await waitFor(() => expect(sent('/projects/export')).toHaveLength(1));
    expect(sent('/projects/export')[0].body).toMatchObject({ include_data: true, data_consent: true });
  });

  it('içe aktarma: özet ve karşılaştırma R metinleriyle; oturum geri yüklenir (DFA sonucu yeniden çalıştırılmadan görünür)', async () => {
    await renderApp('/');
    const input = await screen.findByLabelText(tr.project.chooseFile);
    await userEvent.upload(input, new File([new Uint8Array([0x50, 0x4b])], 'p.olceklab.zip', { type: 'application/zip' }));
    const sum = await screen.findByTestId('project-summary');
    expect(within(sum).getByText(projSummary.dataset.text_tr)).toBeInTheDocument();
    expect(sent('/projects/import')[0].body).toBeInstanceOf(ArrayBuffer);
    for (const a of projSummary.analyses) expect(within(sum).getByText(a.title_tr)).toBeInTheDocument();
    await userEvent.click(within(sum).getByRole('button', { name: tr.project.reproduce }));
    const res = await screen.findByTestId('project-result');
    expect(within(res).getByRole('status')).toHaveTextContent(tr.project.allIdentical);
    for (const c of projRepro.comparisons) expect(within(res).getByText(c.text_tr)).toBeInTheDocument();
    expect(within(res).getAllByText(tr.project.st.identical)).toHaveLength(projRepro.comparisons.length);
    await userEvent.click(within(res).getByRole('button', { name: tr.project.continue }));
    expect(await screen.findByTestId('clean-summary')).toBeInTheDocument();
    await userEvent.click(screen.getByRole('link', { name: /DFA/ }));
    const t1 = await waitFor(() => { const el = document.querySelector('[data-table-id="T1"]'); expect(el).not.toBeNull(); return el as HTMLElement; });
    const rec = projRepro.records[0] as unknown as { tables: { rows_fmt: { tr: { key: string; value: string }[] } }[] };
    expect(t1).toHaveTextContent(rec.tables[0].rows_fmt.tr.find((r) => r.key === 'chisq')!.value);
    expect(sent('/analyses/cfa')).toHaveLength(0);
  });
});
