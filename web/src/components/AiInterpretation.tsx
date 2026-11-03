import { Fragment } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { config } from '../config';
import { interpret, type AiResponse } from '../api/ai';
import { fetchGatewayHealth } from '../api/engine';
import type { AnalysisRecord } from '../api/types';
import { useReport } from '../state/ReportContext';
import { useLang } from '../useLang';

function CheckedText({ response }: { response: AiResponse }) {
  let from = 0;
  const parts = response.check.issues.map((issue, i) => {
    const start = Math.max(from, issue.start); const end = Math.max(start, issue.end);
    const plain = response.text.slice(from, start); from = end;
    return <Fragment key={i}>{plain}<mark className="ai-number-error">{response.text.slice(start, end)}</mark></Fragment>;
  });
  return <p className="ai-text" lang={response.language}>{parts}{response.text.slice(from)}</p>;
}
export function AiInterpretation({ record }: { record: AnalysisRecord }) {
  const { t } = useTranslation(); const lang = useLang(); const report = useReport();
  const health = useQuery({ queryKey: ['gateway', 'health'], queryFn: ({ signal }) => fetchGatewayHealth(signal),
    enabled: config.aiEnabled, retry: false, staleTime: 60000 });
  const result = useMutation({ mutationFn: () => interpret(record, lang), onSuccess: report.logAi });
  if (!config.aiEnabled || !health.isSuccess || health.data.provider === 'none') return null;
  const response = result.data?.record_id === record.analysis_id ? result.data : undefined;
  const approved = response && report.aiTexts.some(x => x.record_id === record.analysis_id && x.text === response.text);
  return <section className="ai-panel" aria-label={t('ai.title')}>
    <p className="muted small">{t('ai.privacy')}</p>
    <button type="button" className="btn" disabled={result.isPending} onClick={() => result.mutate()}>{t(result.isPending ? 'ai.pending' : 'ai.interpret')}</button>
    {result.isError && <p role="alert" className="error-box">{result.error.message}</p>}
    {response && <div aria-live="polite">
      <h3>{response.label}</h3>
      <p className="muted small">{response.provider} · {response.model}</p>
      {!response.check.passed && <p role="alert" className="error-box">{t('ai.failed')}</p>}
      <CheckedText response={response} />
      <button type="button" className="btn" disabled={!response.check.passed || response.check.issues.length > 0 || Boolean(approved)}
        onClick={() => report.approveAi(response, { analysis_id: record.analysis_id, module: record.module, created_at: record.created_at })}>
        {t(approved ? 'ai.approved' : 'ai.approve')}
      </button>
    </div>}
  </section>;
}
