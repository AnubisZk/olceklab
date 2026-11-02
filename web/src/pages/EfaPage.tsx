import { useMemo, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { runEfa } from '../api/analysis';
import type { AnalysisRecord, EfaFm, EfaResults, EfaRotate, EfaSettings, RTable as RTableData } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { RTable } from '../components/RTable';
import { CheckField, NumField, SelectField, toNum } from '../components/Fields';
import { Busy, ErrorBox, ResultActions, Warnings } from '../components/ResultParts';
import { PageHeader } from './PageHeader';
import { NeedsCleanData } from './NeedsCleanData';

// M5 — AFA. Faktörlerin yeniden adlandırılması ve sıralanması yalnızca görünümdür (SPEC §7 M5):
// sayılar ve işaretler değişmez; R'nin biçimlediği metinler olduğu gibi gösterilir.

const FMS: readonly EfaFm[] = ['minres', 'ml', 'pa', 'uls'];
const ROTATIONS: readonly EfaRotate[] = ['oblimin', 'promax', 'geominQ', 'varimax', 'none'];

export interface FactorView { order: string[]; names: Record<string, string> }

// Faktör sütunlarını görünüm sırasına koyar ve başlıklarını görünüm adlarıyla değiştirir.
export function relabelTable(table: RTableData, factors: string[], view: FactorView): RTableData {
  const isF = (k: string) => factors.includes(k);
  const cols = table.columns.filter((c) => !isF(c.key));
  const firstF = table.columns.findIndex((c) => isF(c.key));
  if (firstF < 0) return table;
  const fcols = view.order.map((k) => table.columns.find((c) => c.key === k)!).filter(Boolean)
    .map((c) => ({ ...c, label_tr: view.names[c.key] || c.key, label_en: view.names[c.key] || c.key }));
  const before = table.columns.slice(0, firstF).filter((c) => !isF(c.key));
  const after = cols.filter((c) => !before.includes(c));
  const rename = (rows: Record<string, string>[]) => rows.map((r) => (r.factor && isF(r.factor) ? { ...r, factor: view.names[r.factor] || r.factor } : r));
  const order = table.rows.map((r) => r.factor as string | undefined);
  let rowsIdx = table.rows.map((_, i) => i);
  if (order.every((f) => f && isF(f))) rowsIdx = view.order.map((k) => order.indexOf(k)).filter((i) => i >= 0);
  return {
    ...table,
    columns: [...before, ...fcols, ...after],
    rows: rowsIdx.map((i) => table.rows[i]),
    rows_fmt: { tr: rename(rowsIdx.map((i) => table.rows_fmt.tr[i])), en: rename(rowsIdx.map((i) => table.rows_fmt.en[i])) },
  };
}

function LoadingsTable({ rec, view, hide, sorted }: { rec: AnalysisRecord<EfaResults>; view: FactorView; hide: boolean; sorted: boolean }) {
  const { t } = useTranslation();
  const lang = useLang();
  const t1 = rec.tables[0];
  const items = rec.results.items;
  const rowOrder = sorted ? rec.results.sorted_items.map((it) => items.indexOf(it)) : items.map((_, i) => i);
  const extra = t1.columns.filter((c) => c.key !== 'item' && !rec.results.factors.includes(c.key));
  return (
    <figure className="rtable" data-table-id="T1">
      <figcaption className="rtable-title">{lang === 'tr' ? t1.title_tr : t1.title_en}</figcaption>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th scope="col">{t('efa.item')}</th>
              {view.order.map((f) => <th key={f} scope="col" className="num" data-factor={f}>{view.names[f] || f}</th>)}
              {extra.map((c) => <th key={c.key} scope="col" className="num">{lang === 'tr' ? c.label_tr : c.label_en}</th>)}
            </tr>
          </thead>
          <tbody>
            {rowOrder.map((i) => (
              <tr key={items[i]}>
                <th scope="row">{items[i]}</th>
                {view.order.map((f) => {
                  const salient = rec.results.salient[f][i];
                  return (
                    <td key={f} className={`num${salient ? ' salient' : ''}`} data-salient={salient ? 'true' : 'false'}>
                      {hide && !salient ? '' : t1.rows_fmt[lang][i][f]}
                    </td>
                  );
                })}
                {extra.map((c) => <td key={c.key} className="num">{t1.rows_fmt[lang][i][c.key]}</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {(lang === 'tr' ? t1.note_tr : t1.note_en) && <p className="table-note">{lang === 'tr' ? t1.note_tr : t1.note_en}</p>}
    </figure>
  );
}

function FactorViewControls({ factors, view, setView }: { factors: string[]; view: FactorView; setView: (v: FactorView) => void }) {
  const { t } = useTranslation();
  const move = (k: number, d: -1 | 1) => {
    const o = [...view.order]; const j = k + d;
    if (j < 0 || j >= o.length) return;
    [o[k], o[j]] = [o[j], o[k]];
    setView({ ...view, order: o });
  };
  return (
    <fieldset className="factor-view">
      <legend>{t('efa.viewTitle')}</legend>
      <div className="form-row">
        {view.order.map((f, k) => (
          <div key={f} className="factor-view-item">
            <label className="field"><span>{t('efa.factorName', { key: f })}</span>
              <input className="text-input" value={view.names[f] ?? f} onChange={(e) => setView({ ...view, names: { ...view.names, [f]: e.target.value } })} /></label>
            <div className="segmented">
              <button type="button" aria-label={t('efa.moveLeft', { key: f })} disabled={k === 0} onClick={() => move(k, -1)}>←</button>
              <button type="button" aria-label={t('efa.moveRight', { key: f })} disabled={k === factors.length - 1} onClick={() => move(k, 1)}>→</button>
            </div>
          </div>
        ))}
      </div>
      <p className="muted small">{t('efa.viewNote')}</p>
    </fieldset>
  );
}

function Result({ rec }: { rec: AnalysisRecord<EfaResults> }) {
  const { t } = useTranslation();
  const lang = useLang();
  const factors = rec.results.factors;
  const [view, setView] = useState<FactorView>(() => ({ order: [...factors], names: Object.fromEntries(factors.map((f) => [f, f])) }));
  const [hide, setHide] = useState(false);
  const [sorted, setSorted] = useState(false);
  const others = useMemo(() => rec.tables.slice(1).map((tb) => relabelTable(tb, factors, view)), [rec, factors, view]);
  return (
    <div className="result">
      {factors.length > 1 && <FactorViewControls factors={factors} view={view} setView={setView} />}
      <div className="form-row">
        <CheckField label={t('efa.hideBelow', { thr: rec.results.threshold_fmt[lang] })} checked={hide} onChange={setHide} />
        <CheckField label={t('efa.sortItems')} checked={sorted} onChange={setSorted} />
      </div>
      <LoadingsTable rec={rec} view={view} hide={hide} sorted={sorted} />
      {others.map((tb) => <RTable key={tb.id} table={tb} />)}
      <Warnings warnings={rec.warnings} />
      <ResultActions record={rec} />
    </div>
  );
}

export function EfaPage() {
  const { t } = useTranslation();
  const ds = useDataset();
  const id = ds.overview?.dataset_id;
  const fn = ds.results.factorNumber?.results as { pc?: { suggested?: number } | null; fa?: { suggested?: number } | null } | undefined;
  const suggested = fn?.fa?.suggested ?? fn?.pc?.suggested;
  const [s, setS] = useState<Omit<EfaSettings, 'nfactors' | 'n_rotations' | 'threshold' | 'seed'>>({ fm: 'minres', rotate: 'oblimin', correlation: 'pearson' });
  const [nums, setNums] = useState({ nfactors: String(suggested && suggested > 0 ? suggested : 1), n_rotations: '20', threshold: '0.3', seed: '20261030' });
  const m = useMutation({
    mutationFn: () => runEfa(id!, { ...s, nfactors: toNum(nums.nfactors), n_rotations: toNum(nums.n_rotations), threshold: toNum(nums.threshold), seed: toNum(nums.seed) }),
    onSuccess: (r) => ds.setResult('efa', r),
  });
  const rec = ds.results.efa as AnalysisRecord<EfaResults> | undefined;
  return (
    <>
      <PageHeader pageKey="efa" />
      {!id || !ds.clean ? <NeedsCleanData /> : (
        <section className="card" aria-labelledby="efa-title">
          <h2 id="efa-title">{t('efa.settingsTitle')}</h2>
          <div className="form-grid">
            <NumField label={t('efa.nfactors')} value={nums.nfactors} min={1} step={1} onChange={(v) => setNums({ ...nums, nfactors: v })} />
            <SelectField label={t('efa.fm')} value={s.fm} options={FMS} optionLabel={(v) => t(`efa.opt.${v}`)} onChange={(v) => setS({ ...s, fm: v })} />
            <SelectField label={t('efa.rotate')} value={s.rotate} options={ROTATIONS} optionLabel={(v) => t(`efa.opt.${v}`)} onChange={(v) => setS({ ...s, rotate: v })} />
            <SelectField label={t('efa.correlation')} value={s.correlation} options={['pearson', 'polychoric'] as const}
                         optionLabel={(v) => t(`fn.opt.${v}`)} onChange={(v) => setS({ ...s, correlation: v })} />
            <NumField label={t('efa.n_rotations')} value={nums.n_rotations} min={1} step={1} onChange={(v) => setNums({ ...nums, n_rotations: v })} />
            <NumField label={t('efa.threshold')} value={nums.threshold} min={0} max={1} step={0.05} onChange={(v) => setNums({ ...nums, threshold: v })} />
            <NumField label={t('fn.seed')} value={nums.seed} min={1} step={1} onChange={(v) => setNums({ ...nums, seed: v })} />
          </div>
          {suggested ? <p className="muted small" data-testid="efa-suggested">{t('efa.fromFactorNumber', { n: suggested })}</p> : null}
          {s.correlation === 'polychoric' && s.fm === 'ml' && <p className="warning-line">{t('efa.polyMlWarning')}</p>}
          <div className="actions">
            <button type="button" className="btn btn-primary" disabled={m.isPending} onClick={() => m.mutate()}>{t('efa.run')}</button>
          </div>
          {m.isPending && <Busy label={t('result.running')} />}
          <ErrorBox error={m.error} />
          {rec && <Result key={rec.analysis_id} rec={rec} />}
        </section>
      )}
    </>
  );
}
