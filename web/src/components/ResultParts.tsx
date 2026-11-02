import { useTranslation } from 'react-i18next';
import type { AnalysisRecord, RWarning } from '../api/types';
import { ApiError } from '../api/client';
import { useLang } from '../useLang';

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
  return ['psych'];
}

// SPEC §9: her sonuç sayfasında "R kodunu indir" ve "Rapora ekle" düğmeleri.
export function ResultActions({ record }: { record: AnalysisRecord }) {
  const { t } = useTranslation();
  return (
    <div className="actions result-actions">
      <button
        type="button"
        className="btn"
        disabled={!record.r_script}
        onClick={() => record.r_script && downloadText(record.r_script, `olceklab_${record.module}_${record.analysis_id.slice(0, 8)}.R`)}
      >
        {t('result.downloadScript')}
      </button>
      <button type="button" className="btn" disabled title={t('result.reportPhase')}>
        {t('result.addToReport')}
      </button>
      <span className="muted small mono">
        R {record.engine.R} · {modulePackages(record.module).map((p) => `${p} ${record.engine.packages[p] ?? '—'}`).join(' · ')}{record.seed != null ? ` · seed ${record.seed}` : ''}
      </span>
    </div>
  );
}

export function Busy({ label }: { label: string }) {
  return <p className="busy" role="status" aria-live="polite"><span className="spinner" aria-hidden="true" /> {label}</p>;
}
