import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nextProvider } from 'react-i18next';
import { AiInterpretation } from '../src/components/AiInterpretation';
import { ReportProvider, useReport } from '../src/state/ReportContext';
import { initI18n } from '../src/i18n';
import { config } from '../src/config';
import { exportAiLog, type AiResponse } from '../src/api/ai';
import type { AnalysisRecord } from '../src/api/types';
import fixture from './fixtures/holz_cfa.json';
import { jsonResponse } from './renderApp';

vi.mock('../src/config', () => ({ config: { engineUrl: 'http://localhost:8000', gatewayUrl: 'http://localhost:8787', aiEnabled: true, deployMode: 'local' } }));
const record = fixture as unknown as AnalysisRecord;
const cfi = record.tables.find(t => t.id === 'T1')!.rows_fmt.tr.find(r => r.key === 'cfi')!.value;
let provider = 'api'; let valid = true; let sent: Record<string, unknown> | undefined;
function response(): AiResponse {
  return { record_id: record.analysis_id, language: 'tr', text: valid ? `CFI ${cfi}` : 'CFI 999',
    check: { passed: valid, issues: valid ? [] : [{ start: 4, end: 7, text: '999', reason: 'number' }] },
    label: 'Yapay zekâ yorumu — doğrulayınız', provider: 'api', model: 'test-model', timestamp: '2026-11-03T00:00:00Z',
    prompt: 'Use {{cfa.T1.cfi}}', response: valid ? 'CFI {{cfa.T1.cfi}}' : 'CFI 999' };
}
beforeEach(() => {
  config.aiEnabled = true; provider = 'api'; valid = true; sent = undefined;
  vi.stubGlobal('fetch', vi.fn(async (url: string, opts?: RequestInit) => {
    if (url.endsWith('/health')) return jsonResponse({ provider, model: 'test-model' });
    if (url.endsWith('/v1/interpret')) { sent = JSON.parse(opts!.body as string); return jsonResponse(response()); }
    throw new Error(`Unexpected URL: ${url}`);
  }));
});
function State() {
  const report = useReport();
  return <><output data-testid="approval">{JSON.stringify(report.aiTexts)}</output><output data-testid="log">{JSON.stringify(report.aiLog)}</output>
    <button onClick={() => report.remove(record.analysis_id)}>remove record</button><button onClick={report.clearAiLog}>clear log</button></>;
}
async function mount() {
  const i18n = await initI18n('tr');
  return render(<I18nextProvider i18n={i18n}><QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
    <ReportProvider><AiInterpretation record={record} /><State /></ReportProvider>
  </QueryClientProvider></I18nextProvider>);
}
describe('M11 arayüz onayı ve veri sınırı', () => {
  it('yalnız tablo projeksiyonunu gönderir; açık onay gerekir; analiz kaldırılınca onay da kalkar', async () => {
    await mount();
    await userEvent.click(await screen.findByRole('button', { name: 'Yapay zekâ ile yorumla' }));
    await screen.findByText(`CFI ${cfi}`);
    expect(screen.getByTestId('approval')).toHaveTextContent('[]');
    expect(Object.keys(sent!).sort()).toEqual(['language', 'module', 'record_id', 'tables']);
    expect(JSON.stringify(sent)).not.toContain(record.dataset_hash);
    expect(JSON.stringify(sent)).not.toContain('r_script');
    await userEvent.click(screen.getByRole('button', { name: 'Rapora ekle (onaylıyorum)' }));
    expect(screen.getByTestId('approval')).toHaveTextContent(cfi);
    expect(screen.getByTestId('log')).toHaveTextContent('test-model');
    await userEvent.click(screen.getByRole('button', { name: 'remove record' }));
    expect(screen.getByTestId('approval')).toHaveTextContent('[]');
    await userEvent.click(screen.getByRole('button', { name: 'clear log' }));
    expect(screen.getByTestId('log')).toHaveTextContent('[]');
  });
  it('hatalı sayılar işaretlenir ve rapor onayı kapalı kalır', async () => {
    valid = false; await mount();
    await userEvent.click(await screen.findByRole('button', { name: 'Yapay zekâ ile yorumla' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('doğrulanamayan');
    expect(screen.getByText('999').tagName).toBe('MARK');
    expect(screen.getByRole('button', { name: 'Rapora ekle (onaylıyorum)' })).toBeDisabled();
  });
  it('none sağlayıcısında yorum düğmesi yoktur', async () => {
    provider = 'none'; await mount();
    await waitFor(() => expect(fetch).toHaveBeenCalledTimes(1));
    expect(screen.queryByRole('button', { name: 'Yapay zekâ ile yorumla' })).toBeNull();
  });
  it('yapılandırılmadığında ağ geçidine dahi istek göndermez', async () => {
    config.aiEnabled = false; await mount();
    expect(fetch).not.toHaveBeenCalled();
  });
  it.each(['json', 'md'] as const)('günlük %s olarak dışa aktarılır', async format => {
    const blob = exportAiLog([response()], format);
    const content = await new Promise<string>((resolve, reject) => { const reader = new FileReader(); reader.onload = () => resolve(String(reader.result)); reader.onerror = reject; reader.readAsText(blob); });
    expect(content).toContain('test-model'); expect(content).toContain('{{cfa.T1.cfi}}'); expect(content).toContain(cfi);
    expect(content).not.toContain(record.dataset_hash);
  });
});
