import { config } from '../config';
import { request } from './client';
import type { AnalysisRecord, Lang } from './types';

export interface AiResponse {
  record_id: string; language: Lang; text: string; label: string;
  check: { passed: boolean; issues: { start: number; end: number; text: string; reason: string }[] };
  provider: string; model: string; timestamp: string; prompt: string; response: string;
}
export interface ApprovedAiText { record_id: string; text: string; check_passed: true; provider: string; model: string }
export function interpret(record: AnalysisRecord, language: Lang) {
  // Deliberate projection: no raw data, filename, hash, scripts, figures or settings.
  return request<AiResponse>(config.gatewayUrl, '/v1/interpret', { method: 'POST', json: {
    record_id: record.analysis_id, module: record.module, language,
    tables: record.tables.map(table => ({ id: table.id, rows_fmt: table.rows_fmt })),
  } });
}
export function exportAiLog(log: AiResponse[], format: 'json' | 'md'): Blob {
  const content = format === 'json' ? JSON.stringify(log, null, 2) : log.map(entry => [
    '# AI interpretation / Yapay zekâ yorumu', `${entry.timestamp} · ${entry.provider} · ${entry.model}`,
    `Record: ${entry.record_id} · Check passed: ${entry.check.passed}`,
    '## Prompt', entry.prompt, '## Response template', entry.response, '## Filled text', entry.text,
    '## Check', JSON.stringify(entry.check, null, 2),
  ].join('\n\n')).join('\n\n---\n\n');
  return new Blob([content], { type: format === 'json' ? 'application/json;charset=utf-8' : 'text/markdown;charset=utf-8' });
}
