import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { previewModel, runCfa, runCfaCompare } from '../api/analysis';
import type { AnalysisRecord, Estimator, ModelSpec, PathData } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { RTable } from '../components/RTable';
import { ModelBuilder } from '../components/ModelBuilder';
import { PathDiagram } from '../components/charts/PathDiagram';
import { CheckField, NumField, SelectField, toNum } from '../components/Fields';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';

const ESTIMATORS: readonly Estimator[] = ['ML', 'MLR', 'WLSMV'];

export function modelItems(roles: Record<string, string> | undefined): string[] {
  return roles ? Object.entries(roles).filter(([, r]) => r === 'item').map(([k]) => k) : [];
}

// Model kurucunun başlangıç durumu: M1'deki alt boyutlardan R'nin kurduğu varsayılan model.
export function useSharedModel(id: string | undefined): [ModelSpec | null, (m: ModelSpec) => void] {
  const ds = useDataset();
  const def = useQuery({
    queryKey: ['default-model', id],
    queryFn: () => previewModel(id!),
    enabled: !!id && !ds.model,
    retry: false,
  });
  const { setModel } = ds;
  useEffect(() => {
    if (ds.model || !id) return;
    if (def.data) setModel({ factors: def.data.factors.map((f) => ({ name: f.name, items: [...f.items] })), covariances: [] });
    else if (def.isError) setModel({ factors: [], covariances: [] });
  }, [def.data, def.isError, ds.model, id, setModel]);
  return [ds.model, ds.setModel];
}

export interface CfaOptions { estimator: Estimator; likelihood: 'normal' | 'wishart'; std_lv: boolean; bs: boolean }

export function CfaOptionsForm({ o, setO, nums, setNums }: {
  o: CfaOptions; setO: (o: CfaOptions) => void; nums: { B: string; seed: string; mi: string }; setNums: (n: { B: string; seed: string; mi: string }) => void;
}) {
  const { t } = useTranslation();
  const bsLocked = o.estimator !== 'ML';
  return (
    <div className="form-grid">
      <SelectField label={t('cfa.estimator')} value={o.estimator} options={ESTIMATORS} optionLabel={(v) => t(`cfa.opt.${v}`)}
                   onChange={(v) => setO({ ...o, estimator: v, likelihood: v === 'ML' ? o.likelihood : 'normal', bs: v === 'ML' ? o.bs : false })} />
      <SelectField label={t('cfa.likelihood')} value={o.likelihood} options={['normal', 'wishart'] as const} disabled={o.estimator !== 'ML'}
                   optionLabel={(v) => t(`cfa.opt.${v}`)} onChange={(v) => setO({ ...o, likelihood: v })} />
      <CheckField label={t('cfa.stdLv')} checked={o.std_lv} onChange={(v) => setO({ ...o, std_lv: v })} />
      <CheckField label={t('cfa.bollenStine')} checked={o.bs} disabled={bsLocked} onChange={(v) => setO({ ...o, bs: v })}
                  hint={bsLocked ? t('cfa.bsLocked') : t('cfa.bsHint')} />
      <NumField label={t('cfa.bootstrapB')} value={nums.B} min={100} step={100} disabled={!o.bs || bsLocked} onChange={(v) => setNums({ ...nums, B: v })} />
      <NumField label={t('fn.seed')} value={nums.seed} min={1} step={1} onChange={(v) => setNums({ ...nums, seed: v })} />
      <NumField label={t('cfa.miTop')} value={nums.mi} min={0} step={1} onChange={(v) => setNums({ ...nums, mi: v })} />
    </div>
  );
}

function CfaResult({ rec }: { rec: AnalysisRecord }) {
  const path = rec.figures.find((f) => f.type === 'path');
  return (
    <div className="result">
      {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
      {path && <PathDiagram data={path.data as unknown as PathData} />}
      <Warnings warnings={rec.warnings} />
      <ResultActions record={rec} />
    </div>
  );
}

function CompareSection({ id, o, seed }: { id: string; o: CfaOptions; seed: string }) {
  const { t } = useTranslation();
  const ds = useDataset();
  const m = useMutation({
    mutationFn: () => runCfaCompare(id, { models: ds.savedModels, estimator: o.estimator, likelihood: o.likelihood, std_lv: o.std_lv, seed: toNum(seed) }),
    onSuccess: (r) => ds.setResult('cfaCompare', r),
  });
  const rec = ds.results.cfaCompare;
  return (
    <section className="card" aria-labelledby="cmp-title">
      <h2 id="cmp-title">{t('cfa.compareTitle')}</h2>
      <p className="muted small">{t('cfa.compareNote')}</p>
      {ds.savedModels.length === 0 ? <p className="muted">{t('cfa.noSaved')}</p> : (
        <ul className="list saved-models">
          {ds.savedModels.map((sm, k) => (
            <li key={sm.name}>
              <strong>{sm.name}</strong>{' '}
              <span className="muted small mono">{sm.model.syntax ? t('cfa.syntaxModel') : (sm.model.factors ?? []).map((f) => `${f.name}(${f.items.length})`).join(' · ')}</span>{' '}
              <button type="button" className="btn btn-ghost small" onClick={() => ds.setSavedModels(ds.savedModels.filter((_, j) => j !== k))}>{t('cfa.removeSaved')}</button>
            </li>
          ))}
        </ul>
      )}
      <div className="actions">
        <button type="button" className="btn btn-primary" disabled={ds.savedModels.length < 2 || m.isPending} onClick={() => m.mutate()}>{t('cfa.runCompare')}</button>
      </div>
      {m.isPending && <Busy label={t('result.running')} />}
      <ErrorBox error={m.error} />
      {rec && (
        <div className="result">
          {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
          <Warnings warnings={rec.warnings} />
          <ResultActions record={rec} />
        </div>
      )}
    </section>
  );
}

export function CfaPage() {
  const { t } = useTranslation();
  const ds = useDataset();
  const id = ds.overview?.dataset_id;
  const [model, setModel] = useSharedModel(ds.clean ? id : undefined);
  const [o, setO] = useState<CfaOptions>({ estimator: 'ML', likelihood: 'normal', std_lv: false, bs: false });
  const [nums, setNums] = useState({ B: '1000', seed: '20261030', mi: '10' });
  const [name, setName] = useState('');
  const m = useMutation({
    mutationFn: () => runCfa(id!, {
      model: model!, estimator: o.estimator, likelihood: o.likelihood, std_lv: o.std_lv,
      bootstrap: o.bs ? toNum(nums.B) : 0, seed: toNum(nums.seed), mi_top: toNum(nums.mi),
    }),
    onSuccess: (r) => ds.setResult('cfa', r),
  });
  const saveForCompare = () => {
    const nm = name.trim() || t('cfa.modelN', { n: ds.savedModels.length + 1 });
    if (!model || ds.savedModels.some((s) => s.name === nm)) return;
    ds.setSavedModels([...ds.savedModels, { name: nm, model }]);
    setName('');
  };
  const items = modelItems(ds.roles?.roles);
  return (
    <>
      <PageHeader pageKey="cfa" />
      {!id || !ds.clean ? <NeedsCleanData /> : (
        <>
          <section className="card" aria-labelledby="model-title">
            <h2 id="model-title">{t('model.title')}</h2>
            {model ? <ModelBuilder datasetId={id} items={items} value={model} onChange={setModel} /> : <Busy label={t('result.running')} />}
            <div className="form-row">
              <label className="field"><span>{t('cfa.saveName')}</span>
                <input className="text-input" value={name} placeholder={t('cfa.modelN', { n: ds.savedModels.length + 1 })} onChange={(e) => setName(e.target.value)} /></label>
              <button type="button" className="btn" disabled={!model} onClick={saveForCompare}>{t('cfa.saveForCompare')}</button>
            </div>
          </section>
          <section className="card" aria-labelledby="cfa-title">
            <h2 id="cfa-title">{t('cfa.settingsTitle')}</h2>
            <CfaOptionsForm o={o} setO={setO} nums={nums} setNums={setNums} />
            <div className="actions">
              <button type="button" className="btn btn-primary" disabled={!model || m.isPending} onClick={() => m.mutate()}>{t('cfa.run')}</button>
            </div>
            {m.isPending && <Busy label={o.bs ? t('cfa.runningBs') : t('result.running')} />}
            <ErrorBox error={m.error} />
            {ds.results.cfa && <CfaResult rec={ds.results.cfa} />}
          </section>
          <CompareSection id={id} o={o} seed={nums.seed} />
        </>
      )}
    </>
  );
}
