import { useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { importProject, reproduceProject, uploadDataset } from '../api/analysis';
import type { AnalysisRecord, ModelSpec, ProjectReproduction, ProjectSummary } from '../api/types';
import { useDataset, type AnalysisKey } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { Busy, ErrorBox } from '../components/ResultParts';

// M12 içe aktarma: özet → (gerekirse aynı veri dosyası) → R'de yeniden üretim → 17 basamaklı karşılaştırma → oturumu geri yükle.

const moduleKey: Record<string, AnalysisKey> = {
  item_analysis: 'item', suitability: 'suitability', factor_number: 'factorNumber', efa: 'efa', cfa: 'cfa', cfa_compare: 'cfaCompare',
  reliability: 'reliability', invariance: 'invariance', invariance_scores: 'invarianceScores',
};

function modelFromRecord(rec: AnalysisRecord): ModelSpec | null {
  const m = (rec.settings as { model?: { source?: string; syntax?: string; factors?: ModelSpec['factors']; covariances?: ModelSpec['covariances'] } }).model;
  if (!m) return null;
  return m.source === 'syntax' ? { syntax: m.syntax } : { factors: m.factors ?? [], covariances: m.covariances ?? [] };
}

export function ProjectImport() {
  const { t } = useTranslation();
  const lang = useLang();
  const ds = useDataset();
  const navigate = useNavigate();
  const fileRef = useRef<HTMLInputElement>(null);
  const [summary, setSummary] = useState<ProjectSummary | null>(null);
  const [result, setResult] = useState<ProjectReproduction | null>(null);
  const restore = (rp: ProjectReproduction) => {
    ds.setOverview(rp.dataset);
    ds.setRoles(rp.roles);
    if (rp.clean) ds.setClean(rp.clean);
    let model: ModelSpec | null = null;
    for (const rec of rp.records) {
      const k = moduleKey[rec.module];
      if (k) ds.setResult(k, rec);
      if (rec.module === 'cfa' || rec.module === 'reliability' || rec.module === 'invariance') model = modelFromRecord(rec) ?? model;
    }
    if (model) ds.setModel(model);
    setResult(rp);
  };
  const imp = useMutation({ mutationFn: (f: File) => importProject(f), onSuccess: (s) => { setSummary(s); setResult(null); } });
  const rep = useMutation({ mutationFn: (datasetId?: string) => reproduceProject(summary!.project_id, datasetId), onSuccess: restore });
  const withData = useMutation({
    mutationFn: async (f: File) => { const o = await uploadDataset(f); return reproduceProject(summary!.project_id, o.dataset_id); },
    onSuccess: restore,
  });
  const busy = imp.isPending || rep.isPending || withData.isPending;
  return (
    <section className="card" aria-labelledby="imp-title">
      <h2 id="imp-title">{t('project.importTitle')}</h2>
      <p className="muted small">{t('project.importHelp')}</p>
      <div className="actions">
        <label className="btn file-btn">{t('project.chooseFile')}
          <input ref={fileRef} type="file" accept=".zip,application/zip" aria-label={t('project.chooseFile')}
                 onChange={(e) => { const f = e.target.files?.[0]; if (f) imp.mutate(f); e.target.value = ''; }} /></label>
      </div>
      {busy && <Busy label={t('project.working')} />}
      <ErrorBox error={imp.error} />
      {summary && (
        <div className="project-summary" data-testid="project-summary">
          <p><strong>{t('project.dataset')}:</strong> <span className="mono small">{lang === 'tr' ? summary.dataset.text_tr : summary.dataset.text_en}</span></p>
          <p className="small">{summary.dataset.included ? t('project.dataIncluded') : summary.dataset.source_type === 'example' ? t('project.dataExample') : t('project.dataNotIncluded')}</p>
          <ol className="list small">{summary.analyses.map((a) => <li key={a.analysis_id}>{lang === 'tr' ? a.title_tr : a.title_en}</li>)}</ol>
          {summary.version_warnings.length > 0 && (
            <div className="warnings" role="alert" aria-label={t('project.versionWarnings')}>
              <h3>{t('project.versionWarnings')}</h3>
              <ul>{summary.version_warnings.map((w) => <li key={w.component}>{lang === 'tr' ? w.message_tr : w.message_en}</li>)}</ul>
            </div>
          )}
          {summary.needs_data ? (
            <div className="actions">
              <label className="btn btn-primary file-btn">{t('project.uploadSame')}
                <input type="file" accept=".csv,.txt,.tsv,.xlsx,.xls" aria-label={t('project.uploadSame')}
                       onChange={(e) => { const f = e.target.files?.[0]; if (f) withData.mutate(f); e.target.value = ''; }} /></label>
            </div>
          ) : (
            <div className="actions">
              <button type="button" className="btn btn-primary" disabled={busy} onClick={() => rep.mutate(undefined)}>{t('project.reproduce')}</button>
            </div>
          )}
          <ErrorBox error={rep.error ?? withData.error} />
        </div>
      )}
      {result && (
        <div className="project-result" data-testid="project-result">
          <p className={result.all_identical ? 'ok-line' : 'warning-line'} role="status">{result.all_identical ? t('project.allIdentical') : t('project.notAllIdentical')}</p>
          {result.version_warnings.length > 0 && <ul className="list small">{result.version_warnings.map((w) => <li key={w.component}>{lang === 'tr' ? w.message_tr : w.message_en}</li>)}</ul>}
          <table className="rtable-table">
            <thead><tr><th>{t('project.analysis')}</th><th>{t('project.status')}</th><th>{t('project.comparison')}</th></tr></thead>
            <tbody>
              {result.comparisons.map((c) => (
                <tr key={c.order} data-status={c.status}>
                  <td>{lang === 'tr' ? c.title_tr : c.title_en}</td>
                  <td><span className={`pill ${c.status === 'identical' ? 'pill-ok' : 'pill-error'}`}>{t(`project.st.${c.status}`)}</span></td>
                  <td className="small">{lang === 'tr' ? c.text_tr : c.text_en}{c.diffs && c.diffs.length > 0 && <span className="mono muted"> ({c.diffs.join(', ')})</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="actions"><button type="button" className="btn" onClick={() => void navigate('/data')}>{t('project.continue')}</button></div>
        </div>
      )}
    </section>
  );
}
