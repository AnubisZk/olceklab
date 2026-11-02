import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { runReliability } from '../api/analysis';
import type { Estimator } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { RTable } from '../components/RTable';
import { ModelBuilder } from '../components/ModelBuilder';
import { CheckField, NumField, SelectField, toNum } from '../components/Fields';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';
import { modelItems, useSharedModel } from './CfaPage';

// M7 — Güvenirlik ve geçerlik. Model DFA sayfasıyla paylaşılır.
export function ReliabilityPage() {
  const { t } = useTranslation();
  const ds = useDataset();
  const id = ds.overview?.dataset_id;
  const [model, setModel] = useSharedModel(ds.clean ? id : undefined);
  const [estimator, setEstimator] = useState<Estimator>('ML');
  const [obsVar, setObsVar] = useState(true);
  const [htmt2, setHtmt2] = useState(false);
  const [absolute, setAbsolute] = useState(true);
  const [corr, setCorr] = useState<'pearson' | 'polychoric'>('pearson');
  const [th, setTh] = useState({ cr: '0.70', ave: '0.50', htmt: '0.85' });
  const m = useMutation({
    mutationFn: () => runReliability(id!, {
      model: model!, estimator, obs_var: obsVar, htmt: { htmt2, absolute, correlation: corr },
      thresholds: { cr: toNum(th.cr), ave: toNum(th.ave), htmt: toNum(th.htmt) },
    }),
    onSuccess: (r) => ds.setResult('reliability', r),
  });
  const rec = ds.results.reliability;
  return (
    <>
      <PageHeader pageKey="reliability" />
      {!id || !ds.clean ? <NeedsCleanData /> : (
        <>
          <section className="card">
            <details>
              <summary>{t('rel.modelSummary')}</summary>
              {model ? <ModelBuilder datasetId={id} items={modelItems(ds.roles?.roles)} value={model} onChange={setModel} /> : <Busy label={t('result.running')} />}
            </details>
            <p className="muted small">{t('rel.modelShared')}</p>
          </section>
          <section className="card" aria-labelledby="rel-title">
            <h2 id="rel-title">{t('rel.settingsTitle')}</h2>
            <div className="form-grid">
              <SelectField label={t('cfa.estimator')} value={estimator} options={['ML', 'MLR', 'WLSMV'] as const} optionLabel={(v) => t(`cfa.opt.${v}`)} onChange={setEstimator} />
              <CheckField label={t('rel.obsVar')} checked={obsVar} onChange={setObsVar} hint={obsVar ? t('rel.obsVarTrue') : t('rel.obsVarFalse')} />
              <CheckField label={t('rel.htmt2')} checked={htmt2} onChange={setHtmt2} hint={t('rel.htmt2Hint')} />
              <CheckField label={t('rel.absolute')} checked={absolute} onChange={setAbsolute} hint={t('rel.absoluteHint')} />
              <SelectField label={t('rel.htmtCorr')} value={corr} options={['pearson', 'polychoric'] as const} optionLabel={(v) => t(`fn.opt.${v}`)} onChange={setCorr} />
              <NumField label={t('rel.thCr')} value={th.cr} min={0} max={1} step={0.05} onChange={(v) => setTh({ ...th, cr: v })} />
              <NumField label={t('rel.thAve')} value={th.ave} min={0} max={1} step={0.05} onChange={(v) => setTh({ ...th, ave: v })} />
              <NumField label={t('rel.thHtmt')} value={th.htmt} min={0} max={1} step={0.05} onChange={(v) => setTh({ ...th, htmt: v })} />
            </div>
            <p className="muted small">{t('rel.sources')}</p>
            <div className="actions">
              <button type="button" className="btn btn-primary" disabled={!model || m.isPending} onClick={() => m.mutate()}>{t('rel.run')}</button>
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
        </>
      )}
    </>
  );
}
