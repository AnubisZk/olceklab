import { useMemo, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { runInvariance, runInvarianceScores } from '../api/analysis';
import type { AnalysisRecord, InvarianceResults, InvarianceSettings, ScoreTestResults } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { RTable } from '../components/RTable';
import { ModelBuilder } from '../components/ModelBuilder';
import { CheckField, NumField, SelectField, toNum } from '../components/Fields';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';
import { modelItems, useSharedModel } from './CfaPage';

// M8 — Ölçme değişmezliği, kısmi değişmezlik sihirbazı (Byrne vd., 1989) ve gizil ortalamalar.
// Serbest bırakma yalnızca kullanıcının açık onayıyla yapılır (SPEC §7 M8).

type Base = Omit<InvarianceSettings, 'model' | 'partial' | 'criteria' | 'seed'>;

function ScoreTable({ rec, onRelease, released }: { rec: AnalysisRecord<ScoreTestResults>; onRelease: (free: string) => void; released: string[] }) {
  const { t } = useTranslation();
  const lang = useLang();
  const tb = rec.tables[0];
  const [pending, setPending] = useState<string | null>(null);
  const cols = tb.columns;
  return (
    <figure className="rtable" data-table-id="score-tests">
      <figcaption className="rtable-title">{lang === 'tr' ? tb.title_tr : tb.title_en}</figcaption>
      <div className="table-wrap">
        <table>
          <thead><tr>{cols.map((c) => <th key={c.key} scope="col" className={c.type === 'number' ? 'num' : undefined}>{lang === 'tr' ? c.label_tr : c.label_en}</th>)}<th scope="col">{t('inv.action')}</th></tr></thead>
          <tbody>
            {rec.results.tests.map((row, i) => {
              const done = released.includes(row.free);
              return (
                <tr key={`${row.free}-${i}`} data-free={row.free}>
                  {cols.map((c) => <td key={c.key} className={c.type === 'number' ? 'num' : undefined}>{tb.rows_fmt[lang][i][c.key]}</td>)}
                  <td>
                    {done ? <span className="muted small">{t('inv.released')}</span> : pending === row.free ? (
                      <span className="confirm">
                        <span className="small">{t('inv.confirmQ', { p: row.free })}</span>{' '}
                        <button type="button" className="btn btn-primary small" onClick={() => { onRelease(row.free); setPending(null); }}>{t('inv.confirm')}</button>{' '}
                        <button type="button" className="btn btn-ghost small" onClick={() => setPending(null)}>{t('inv.cancel')}</button>
                      </span>
                    ) : (
                      <button type="button" className="btn small" aria-label={t('inv.releaseAria', { p: row.free })} onClick={() => setPending(row.free)}>{t('inv.release')}</button>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <p className="table-note">{lang === 'tr' ? tb.note_tr : tb.note_en}</p>
    </figure>
  );
}

export function InvariancePage() {
  const { t } = useTranslation();
  const ds = useDataset();
  const id = ds.overview?.dataset_id;
  const [model, setModel] = useSharedModel(ds.clean ? id : undefined);
  const groupCol = ds.roles ? Object.entries(ds.roles.roles).find(([, r]) => r === 'group')?.[0] : undefined;
  const groupValues = useMemo(() => {
    if (ds.roles?.group_valid_values?.length) return ds.roles.group_valid_values;
    return ds.overview?.columns.find((c) => c.name === groupCol)?.values ?? [];
  }, [ds.roles, ds.overview, groupCol]);
  const [b, setB] = useState<Base>({ approach: 'continuous', estimator: 'ML', likelihood: 'normal', std_lv: true, include_strict: false,
    reference_group: null, srmr_type: 'bentler_nomean', rule: 'none', d_sd: 'pooled' });
  const [crit, setCrit] = useState({ cfi: '-0.01', rmsea: '0.015', srmr_load: '0.030', srmr_int: '0.010', alpha: '0.05' });
  const [partial, setPartial] = useState<string[]>([]);
  const [manual, setManual] = useState('');
  const [alsoIntercept, setAlsoIntercept] = useState(false);
  const [scoreStep, setScoreStep] = useState('');
  const settings = (p: string[]): InvarianceSettings => ({
    ...b, estimator: b.approach === 'categorical' ? 'WLSMV' : b.estimator, model: model!, partial: p,
    criteria: { cfi: toNum(crit.cfi), rmsea: toNum(crit.rmsea), srmr_load: toNum(crit.srmr_load), srmr_int: toNum(crit.srmr_int), alpha: toNum(crit.alpha) },
    seed: 20261030,
  });
  const inv = useMutation({ mutationFn: (p: string[]) => runInvariance(id!, settings(p)), onSuccess: (r) => ds.setResult('invariance', r) });
  const scores = useMutation({ mutationFn: (step: string) => runInvarianceScores(id!, { ...settings(partial), step }), onSuccess: (r) => ds.setResult('invarianceScores', r) });
  const rec = ds.results.invariance as AnalysisRecord<InvarianceResults> | undefined;
  const sc = ds.results.invarianceScores as AnalysisRecord<ScoreTestResults> | undefined;
  const steps = rec ? rec.results.steps.filter((s) => s !== 'configural') : [];
  const firstFail = rec ? rec.results.decisions.findIndex((d) => !(d.cfi_ok && d.rmsea_ok)) : -1;
  const stepForScores = scoreStep || (rec ? steps[Math.max(0, firstFail)] : '');
  const release = (free: string) => {
    const add = [free];
    const m = /^(.+)=~(.+)$/.exec(free);
    if (alsoIntercept && m && b.approach === 'continuous') add.push(`${m[2]}~1`);
    const next = [...partial, ...add.filter((a) => !partial.includes(a))];
    setPartial(next);
    inv.mutate(next);
  };

  return (
    <>
      <PageHeader pageKey="invariance" />
      {!id || !ds.clean ? <NeedsCleanData /> : !groupCol ? (
        <section className="card placeholder"><p>{t('inv.needsGroup')}</p></section>
      ) : (
        <>
          <section className="card">
            <details>
              <summary>{t('rel.modelSummary')}</summary>
              {model ? <ModelBuilder datasetId={id} items={modelItems(ds.roles?.roles)} value={model} onChange={setModel} /> : <Busy label={t('result.running')} />}
            </details>
            <p className="muted small">{t('inv.groupInfo', { col: groupCol })}</p>
          </section>
          <section className="card" aria-labelledby="inv-title">
            <h2 id="inv-title">{t('inv.settingsTitle')}</h2>
            <div className="form-grid">
              <SelectField label={t('inv.approach')} value={b.approach} options={['continuous', 'categorical'] as const} optionLabel={(v) => t(`inv.opt.${v}`)}
                           onChange={(v) => setB({ ...b, approach: v })} />
              <SelectField label={t('cfa.estimator')} value={b.approach === 'categorical' ? 'WLSMV' : b.estimator} disabled={b.approach === 'categorical'}
                           options={(b.approach === 'categorical' ? ['WLSMV'] : ['ML', 'MLR']) as readonly ('ML' | 'MLR' | 'WLSMV')[]}
                           optionLabel={(v) => t(`cfa.opt.${v}`)} onChange={(v) => setB({ ...b, estimator: v as 'ML' | 'MLR', likelihood: v === 'ML' ? b.likelihood : 'normal' })} />
              <SelectField label={t('cfa.likelihood')} value={b.likelihood} options={['normal', 'wishart'] as const} disabled={b.approach === 'categorical' || b.estimator !== 'ML'}
                           optionLabel={(v) => t(`cfa.opt.${v}`)} onChange={(v) => setB({ ...b, likelihood: v })} />
              <SelectField label={t('inv.reference')} value={b.reference_group ?? ''} options={['', ...groupValues] as readonly string[]}
                           optionLabel={(v) => (v === '' ? t('inv.firstGroup') : v)} onChange={(v) => setB({ ...b, reference_group: v || null })} />
              <CheckField label={t('cfa.stdLv')} checked={b.std_lv} disabled={b.approach === 'categorical'} onChange={(v) => setB({ ...b, std_lv: v })} />
              <CheckField label={t('inv.strict')} checked={b.include_strict} onChange={(v) => setB({ ...b, include_strict: v })} />
              <SelectField label={t('inv.srmrType')} value={b.srmr_type} options={['bentler_nomean', 'srmr'] as const} optionLabel={(v) => t(`inv.opt.${v}`)} onChange={(v) => setB({ ...b, srmr_type: v })} />
              <SelectField label={t('inv.rule')} value={b.rule} options={['none', 'and', 'or'] as const} optionLabel={(v) => t(`inv.opt.rule_${v}`)} onChange={(v) => setB({ ...b, rule: v })} />
              <SelectField label={t('inv.dSd')} value={b.d_sd} options={['pooled', 'reference'] as const} optionLabel={(v) => t(`inv.opt.${v}`)} onChange={(v) => setB({ ...b, d_sd: v })} />
              <NumField label={t('inv.critCfi')} value={crit.cfi} step={0.005} onChange={(v) => setCrit({ ...crit, cfi: v })} />
              <NumField label={t('inv.critRmsea')} value={crit.rmsea} step={0.005} onChange={(v) => setCrit({ ...crit, rmsea: v })} />
              <NumField label={t('inv.critSrmrLoad')} value={crit.srmr_load} step={0.005} onChange={(v) => setCrit({ ...crit, srmr_load: v })} />
              <NumField label={t('inv.critSrmrInt')} value={crit.srmr_int} step={0.005} onChange={(v) => setCrit({ ...crit, srmr_int: v })} />
              <NumField label={t('inv.critAlpha')} value={crit.alpha} step={0.01} onChange={(v) => setCrit({ ...crit, alpha: v })} />
            </div>
            <fieldset className="cov-box">
              <legend>{t('inv.partialTitle')}</legend>
              {partial.length === 0 ? <p className="muted small">{t('inv.noPartial')}</p> : (
                <ul className="chips" aria-label={t('inv.partialTitle')}>
                  {partial.map((p) => (
                    <li key={p} className="chip"><span className="mono">{p}</span>
                      <button type="button" className="btn btn-ghost small" aria-label={t('inv.removePartial', { p })} onClick={() => setPartial(partial.filter((x) => x !== p))}>×</button></li>
                  ))}
                </ul>
              )}
              <div className="form-row">
                <label className="field"><span>{t('inv.manualPartial')}</span>
                  <input className="text-input mono" value={manual} placeholder="F=~x1, x1~1, x1|t1" onChange={(e) => setManual(e.target.value)} /></label>
                <button type="button" className="btn" disabled={!manual.trim()} onClick={() => { setPartial([...new Set([...partial, manual.trim()])]); setManual(''); }}>{t('model.covAdd')}</button>
              </div>
            </fieldset>
            <div className="actions">
              <button type="button" className="btn btn-primary" disabled={!model || inv.isPending} onClick={() => inv.mutate(partial)}>{t('inv.run')}</button>
            </div>
            {inv.isPending && <Busy label={t('result.running')} />}
            <ErrorBox error={inv.error} />
            {rec && (
              <div className="result">
                {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
                {!rec.results.latent_means_available && rec.results.steps.includes('scalar') && <p className="warning-line">{t('inv.latentLocked')}</p>}
                <Warnings warnings={rec.warnings} />
                <ResultActions record={rec} />
              </div>
            )}
          </section>
          {rec && steps.length > 0 && (
            <section className="card" aria-labelledby="wiz-title">
              <h2 id="wiz-title">{t('inv.wizardTitle')}</h2>
              <p className="muted small">{t('inv.wizardIntro')}</p>
              <div className="form-row">
                <SelectField label={t('inv.scoreStep')} value={stepForScores} options={steps as readonly string[]} optionLabel={(v) => t(`inv.step.${v}`)} onChange={setScoreStep} />
                <CheckField label={t('inv.alsoIntercept')} checked={alsoIntercept} disabled={b.approach === 'categorical'} onChange={setAlsoIntercept} hint={t('inv.alsoInterceptHint')} />
                <button type="button" className="btn btn-primary" disabled={scores.isPending} onClick={() => scores.mutate(stepForScores)}>{t('inv.runScores')}</button>
              </div>
              {scores.isPending && <Busy label={t('result.running')} />}
              <ErrorBox error={scores.error} />
              {sc && JSON.stringify(((sc.settings.partial as string[] | undefined) ?? [])) !== JSON.stringify(partial) && (
                <p className="warning-line" data-testid="scores-stale">{t('inv.scoresStale')}</p>
              )}
              {sc && <ScoreTable rec={sc} released={partial} onRelease={release} />}
              {sc && <Warnings warnings={sc.warnings} />}
              <p className="warning-line">{t('inv.dataDriven')}</p>
            </section>
          )}
        </>
      )}
    </>
  );
}
