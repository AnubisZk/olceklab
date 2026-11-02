import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { runFactorNumber } from '../api/analysis';
import type { FactorNumberResults, FactorNumberSettings, AnalysisRecord, ScreeData } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { RTable } from '../components/RTable';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { ScreeChart } from '../components/charts/ScreeChart';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';

export const defaultFnSettings: FactorNumberSettings = {
  extraction: 'pc', correlation: 'pearson', reference: 'simulated_normal', n_iter: 1000,
  criterion: 'quantile', quant: 0.95, fm: 'minres', seed: 20261030,
};

function Select<K extends keyof FactorNumberSettings>({ k, s, set, options, disabled }: {
  k: K; s: FactorNumberSettings; set: (p: Partial<FactorNumberSettings>) => void; options: FactorNumberSettings[K][];
  disabled?: (v: FactorNumberSettings[K]) => boolean;
}) {
  const { t } = useTranslation();
  return (
    <label className="field">
      <span>{t(`fn.${k}`)}</span>
      <select value={String(s[k])} onChange={(e) => set({ [k]: e.target.value } as Partial<FactorNumberSettings>)}>
        {options.map((o) => <option key={String(o)} value={String(o)} disabled={disabled?.(o)}>{t(`fn.opt.${String(o)}`)}</option>)}
      </select>
    </label>
  );
}

// Sayı kutuları metin olarak tutulur; böylece silip yeniden yazarken "0200" gibi artık kalmaz.
type NumKey = 'n_iter' | 'quant' | 'seed';
type NumText = Record<NumKey, string>;

function SettingsForm({ s, set, nums, setNums }: {
  s: FactorNumberSettings; set: (p: Partial<FactorNumberSettings>) => void; nums: NumText; setNums: (p: Partial<NumText>) => void;
}) {
  const { t } = useTranslation();
  const setCorr = (p: Partial<FactorNumberSettings>) => {
    // Polikorikte simüle normal referans kullanılamaz (SPEC M4; SPEC_REVIEW PA-4)
    if (p.correlation === 'polychoric' && s.reference === 'simulated_normal') p.reference = 'resampled_bootstrap';
    set(p);
  };
  return (
    <div className="form-grid">
      <Select k="extraction" s={s} set={set} options={['pc', 'fa', 'both']} />
      <Select k="correlation" s={s} set={setCorr} options={['pearson', 'polychoric']} />
      <Select k="reference" s={s} set={set} options={['simulated_normal', 'resampled_bootstrap', 'permutation']}
              disabled={(v) => s.correlation === 'polychoric' && v === 'simulated_normal'} />
      <Select k="criterion" s={s} set={set} options={['quantile', 'mean']} />
      <Select k="fm" s={s} set={set} options={['minres', 'ml', 'uls', 'wls', 'gls', 'pa']} />
      <label className="field"><span>{t('fn.n_iter')}</span>
        <input className="num-input" type="number" min={1} step={100} value={nums.n_iter} onChange={(e) => setNums({ n_iter: e.target.value })} /></label>
      <label className="field"><span>{t('fn.quant')}</span>
        <input className="num-input" type="number" min={0.5} max={0.999} step={0.01} disabled={s.criterion === 'mean'} value={nums.quant} onChange={(e) => setNums({ quant: e.target.value })} /></label>
      <label className="field"><span>{t('fn.seed')}</span>
        <input className="num-input" type="number" min={1} step={1} value={nums.seed} onChange={(e) => setNums({ seed: e.target.value })} /></label>
    </div>
  );
}

function Result({ rec }: { rec: AnalysisRecord<FactorNumberResults> }) {
  const { t } = useTranslation();
  const lang = useLang();
  const scree = rec.figures.find((f) => f.type === 'scree');
  return (
    <div className="result">
      <aside className="decision" aria-label={t('fn.decisionTitle')}>
        <h3>{t('fn.decisionTitle')}</h3>
        <p data-testid="decision">{lang === 'tr' ? rec.results.decision_tr : rec.results.decision_en}</p>
        <p className="muted small">{t('fn.decisionNote')}</p>
      </aside>
      {scree && (
        <figure className="chart-figure">
          <figcaption className="rtable-title">{t('fn.chart.title')}</figcaption>
          <ScreeChart data={scree.data as unknown as ScreeData} />
        </figure>
      )}
      {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
      <Warnings warnings={rec.warnings} />
      <ResultActions record={rec} />
    </div>
  );
}

export function FactorNumberPage() {
  const { t } = useTranslation();
  const ds = useDataset();
  const [s, setS] = useState<FactorNumberSettings>(defaultFnSettings);
  const [nums, setNumsState] = useState<NumText>({
    n_iter: String(defaultFnSettings.n_iter), quant: String(defaultFnSettings.quant), seed: String(defaultFnSettings.seed),
  });
  const id = ds.overview?.dataset_id;
  // Geçersiz metin olduğu gibi gönderilir; R motoru 422 ile reddeder (null gönderilseydi varsayılan sessizce kullanılırdı).
  const toNum = (v: string) => (v.trim() !== '' && Number.isFinite(Number(v)) ? Number(v) : (v as unknown as number));
  const m = useMutation({
    mutationFn: () => runFactorNumber(id!, { ...s, n_iter: toNum(nums.n_iter), quant: toNum(nums.quant), seed: toNum(nums.seed) }),
    onSuccess: (r) => ds.setResult('factorNumber', r),
  });
  const rec = ds.results.factorNumber as AnalysisRecord<FactorNumberResults> | undefined;
  return (
    <>
      <PageHeader pageKey="factorNumber" />
      {!id || !ds.clean ? <NeedsCleanData /> : (
        <section className="card" aria-labelledby="fn-title">
          <h2 id="fn-title">{t('fn.settingsTitle')}</h2>
          <SettingsForm s={s} set={(p) => setS((old) => ({ ...old, ...p }))} nums={nums}
                        setNums={(p) => setNumsState((old) => ({ ...old, ...p }))} />
          <div className="actions">
            <button type="button" className="btn btn-primary" disabled={m.isPending} onClick={() => m.mutate()}>{t('fn.run')}</button>
          </div>
          {m.isPending && <Busy label={t('fn.runningLong')} />}
          <ErrorBox error={m.error} />
          {rec && <Result rec={rec} />}
        </section>
      )}
    </>
  );
}
