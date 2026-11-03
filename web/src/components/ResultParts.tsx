import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMutation } from '@tanstack/react-query';
import { tableCsv } from '../api/analysis';
import { saveBlob } from '../api/client';
import { useReport } from '../state/ReportContext';
import type { AnalysisRecord, RWarning } from '../api/types';
import { ApiError } from '../api/client';
import { useLang } from '../useLang';
import { AiInterpretation } from './AiInterpretation';

export function Warnings({ warnings }: { warnings: RWarning[] }) {
  const lang = useLang();
  const { t } = useTranslation();
  if (!warnings.length) return null;
  return (
    <section className="warnings" aria-label={t('result.warnings')}>
      <h3>{t('result.warnings')}</h3>
      <ul>
        {warnings.map((w, i) => (
          <li key={`${w.code}-${i}`} data-code={w.code}>{lang === 'tr' ? w.message_tr : w.message_en}</li>
        ))}
      </ul>
    </section>
  );
}

export function ErrorBox({ error }: { error: unknown }) {
  const { t } = useTranslation();
  if (!error) return null;
  const e = error instanceof ApiError ? error : null;
  return (
    <div role="alert" className="error-box">
      <p>{e ? e.message : String(error)}</p>
      {e && <p className="muted mono small">{t('engine.errorCode')}: {e.code}{e.detail ? ` — ${e.detail}` : ''}</p>}
    </div>
  );
}

function downloadText(text: string, filename: string) {
  const url = URL.createObjectURL(new Blob([text], { type: 'text/x-r-source;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export function modulePackages(module: string): string[] {
  if (module === 'cfa') return ['lavaan'];
  if (module === 'cfa_compare') return ['lavaan', 'semTools'];
  if (module === 'reliability') return ['lavaan', 'semTools', 'psych'];
  if (module === 'efa') return ['psych', 'GPArotation'];
  if (module === 'invariance' || module === 'invariance_scores') return ['lavaan', 'semTools'];
  if (module === 'simulation') return ['lavaan', 'semTools', 'psych', 'MASS'];
  return ['psych'];
}

// SPEC §9: her sonuç sayfasında "R kodunu indir" ve "Rapora ekle" düğmeleri.
export function ResultActions({ record }: { record: AnalysisRecord }) {
  const { t } = useTranslation();
  const lang = useLang();
  const report = useReport();
  const inReport = report.has(record.analysis_id);
  const [tid, setTid] = useState(record.tables[0]?.id ?? '');
  const [raw, setRaw] = useState(false);
  const csv = useMutation({
    mutationFn: () => tableCsv(record.analysis_id, tid, lang, raw ? 'raw' : 'formatted'),
    onSuccess: (b) => saveBlob(b, `olceklab_${record.module}_${tid}_${raw ? 'ham' : 'bicimli'}.csv`),
  });
  return (
    <>
    <div className="actions result-actions">
      <button
        type="button"
        className="btn"
        disabled={!record.r_script}
        onClick={() => record.r_script && downloadText(record.r_script, `olceklab_${record.module}_${record.analysis_id.slice(0, 8)}.R`)}
      >
        {t('result.downloadScript')}
      </button>
      <button type="button" className="btn" aria-pressed={inReport}
              onClick={() => (inReport ? report.remove(record.analysis_id) : report.add({ analysis_id: record.analysis_id, module: record.module, created_at: record.created_at }))}>
        {inReport ? t('result.inReport') : t('result.addToReport')}
      </button>
      <span className="muted small mono">
        R {record.engine.R} · {modulePackages(record.module).map((p) => `${p} ${record.engine.packages[p] ?? '—'}`).join(' · ')}{record.seed != null ? ` · seed ${record.seed}` : ''}
      </span>
    </div>
    {record.tables.length > 0 && (
      <div className="actions csv-actions">
        <label className="field"><span>{t('result.csvTable')}</span>
          <select value={tid} onChange={(e) => setTid(e.target.value)}>
            {record.tables.map((tb) => <option key={tb.id} value={tb.id}>{tb.id} · {lang === 'tr' ? tb.title_tr : tb.title_en}</option>)}
          </select></label>
        <label className="rule"><input type="checkbox" checked={raw} onChange={(e) => setRaw(e.target.checked)} /><span>{t('result.csvRaw')}</span></label>
        <button type="button" className="btn" disabled={!tid || csv.isPending} onClick={() => csv.mutate()}>{t('result.csvDownload')}</button>
        <ErrorBox error={csv.error} />
      </div>
    )}
    <AiInterpretation key={record.analysis_id} record={record} />
    </>
  );
}

export function Busy({ label }: { label: string }) {
  return <p className="busy" role="status" aria-live="polite"><span className="spinner" aria-hidden="true" /> {label}</p>;
}
