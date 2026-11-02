import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { runItemAnalysis, runSuitability } from '../api/analysis';
import type { HeatmapData } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { RTable } from '../components/RTable';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { HeatmapChart } from '../components/charts/HeatmapChart';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';

function ItemCard({ id }: { id: string }) {
  const { t } = useTranslation();
  const ds = useDataset();
  const [thr, setThr] = useState('0.3');
  const m = useMutation({ mutationFn: () => runItemAnalysis(id, { r_drop_threshold: thr.trim() !== '' && Number.isFinite(Number(thr)) ? Number(thr) : (thr as unknown as number) }), onSuccess: (r) => ds.setResult('item', r) });
  const rec = ds.results.item;
  const heat = rec?.figures.find((f) => f.type === 'heatmap');
  return (
    <section className="card" aria-labelledby="item-title">
      <h2 id="item-title">{t('items.itemTitle')}</h2>
      <div className="form-row">
        <label className="field">
          <span>{t('items.rThreshold')}</span>
          <input className="num-input" type="number" step={0.05} min={0} max={1} value={thr} onChange={(e) => setThr(e.target.value)} />
        </label>
        <button type="button" className="btn btn-primary" disabled={m.isPending} onClick={() => m.mutate()}>{t('items.run')}</button>
      </div>
      {m.isPending && <Busy label={t('result.running')} />}
      <ErrorBox error={m.error} />
      {rec && (
        <div className="result">
          {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
          {heat && (
            <figure className="chart-figure">
              <figcaption className="rtable-title">{t('items.heatmapTitle')}</figcaption>
              <HeatmapChart data={heat.data as unknown as HeatmapData} />
            </figure>
          )}
          <Warnings warnings={rec.warnings} />
          <ResultActions record={rec} />
        </div>
      )}
    </section>
  );
}

function SuitabilityCard({ id }: { id: string }) {
  const { t } = useTranslation();
  const ds = useDataset();
  const [corr, setCorr] = useState<'pearson' | 'polychoric'>('pearson');
  const m = useMutation({ mutationFn: () => runSuitability(id, { correlation: corr }), onSuccess: (r) => ds.setResult('suitability', r) });
  const rec = ds.results.suitability;
  return (
    <section className="card" aria-labelledby="suit-title">
      <h2 id="suit-title">{t('items.suitTitle')}</h2>
      <div className="form-row">
        <label className="field">
          <span>{t('fn.correlation')}</span>
          <select value={corr} onChange={(e) => setCorr(e.target.value as 'pearson' | 'polychoric')}>
            <option value="pearson">{t('fn.opt.pearson')}</option>
            <option value="polychoric">{t('fn.opt.polychoric')}</option>
          </select>
        </label>
        <button type="button" className="btn btn-primary" disabled={m.isPending} onClick={() => m.mutate()}>{t('items.runSuit')}</button>
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

export function ItemsPage() {
  const ds = useDataset();
  const id = ds.overview?.dataset_id;
  return (
    <>
      <PageHeader pageKey="items" />
      {!id || !ds.clean ? <NeedsCleanData /> : (<><ItemCard id={id} /><SuitabilityCard id={id} /></>)}
    </>
  );
}
