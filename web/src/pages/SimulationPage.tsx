import { useEffect, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import {
  cancelJob, downloadSimPackage, estimateSimulation, getJob, getSimResults, populationFromCfa, resumeJob, startSimulation,
} from '../api/analysis';
import type { BiasHeatmapData, Estimator, JobStatus, ModelSpec, PowerCurveData } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { RTable } from '../components/RTable';
import { CheckField, NumField, SelectField, toNum } from '../components/Fields';
import { Busy, ErrorBox, Warnings } from '../components/ResultParts';
import { BiasHeatmap, PowerChart } from '../components/charts/SimCharts';
import { PageHeader } from './PageHeader';

// M9 — Monte Carlo simülasyonu (SPEC §7 M9, §9 madde 9). Bütün hesaplar R motorunda; bu sayfa yalnızca tanımı
// yazar, işi izler ve R'nin biçimlediği sonuçları gösterir. Sayfa kalıcı SİMÜLASYON etiketini taşır (9.9).

type Pop = Record<string, unknown> & { factors?: { name: string; items: string[] }[]; groups?: { name: string }[]; dif?: unknown[] };

// Başlangıç tanımı (kullanıcı girdisi; sonuç değildir): modeldeki faktörler, yükler ,70, faktör korelasyonları ,30.
export function starterPopulation(model: ModelSpec | null, groups: string[]): Pop {
  const factors = (model?.factors ?? []).filter((f) => f.items.length >= 2).map((f) => ({ name: f.name, items: [...f.items] }));
  const fs = factors.length ? factors : [{ name: 'F1', items: ['y1', 'y2', 'y3'] }, { name: 'F2', items: ['y4', 'y5', 'y6'] }];
  const loadings = Object.fromEntries(fs.flatMap((f) => f.items.map((i) => [i, 0.7])));
  const factor_cor = fs.flatMap((a, i) => fs.slice(i + 1).map((b) => ({ a: a.name, b: b.name, r: 0.3 })));
  const pop: Pop = { factors: fs, loadings, factor_cor, data_type: 'ordinal', category_props: [0.1, 0.2, 0.4, 0.2, 0.1] };
  const g = groups.length >= 2 ? groups.slice(0, 2) : ['A', 'B'];
  pop.groups = [{ name: g[0] }, { name: g[1] }];
  pop.dif = [];
  return pop;
}

function parseList(s: string): number[] { return s.split(/[,;\s]+/).filter(Boolean).map(toNum); }
// "70/30; 50/50" → [[70, 30], [50, 50]]; oranları R normalleştirir ve doğrular.
function parseRatios(s: string): number[][] {
  return s.split(';').map((r) => r.trim()).filter(Boolean).map((r) => r.split('/').map((x) => toNum(x.trim())));
}

function DifForm({ pop, setPop }: { pop: Pop; setPop: (p: Pop) => void }) {
  const { t } = useTranslation();
  const items = (pop.factors ?? []).flatMap((f) => f.items);
  const groups = (pop.groups ?? []).slice(1).map((g) => g.name);
  const ordinal = pop.data_type !== 'continuous';
  const [d, setD] = useState({ name: '', group: groups[0] ?? '', item: items[0] ?? '', type: ordinal ? 'threshold' : 'intercept', size: '0.5' });
  return (
    <fieldset className="cov-box">
      <legend>{t('sim.difTitle')}</legend>
      <div className="form-row">
        <label className="field"><span>{t('sim.difName')}</span><input className="text-input" value={d.name} onChange={(e) => setD({ ...d, name: e.target.value })} /></label>
        <label className="field"><span>{t('sim.difGroup')}</span><select value={d.group} onChange={(e) => setD({ ...d, group: e.target.value })}>{groups.map((g) => <option key={g} value={g}>{g}</option>)}</select></label>
        <label className="field"><span>{t('sim.difItem')}</span><select value={d.item} onChange={(e) => setD({ ...d, item: e.target.value })}>{items.map((i) => <option key={i} value={i}>{i}</option>)}</select></label>
        <label className="field"><span>{t('sim.difType')}</span><select value={d.type} onChange={(e) => setD({ ...d, type: e.target.value })}>
          {(ordinal ? ['threshold', 'loading'] : ['intercept', 'loading']).map((x) => <option key={x} value={x}>{t(`sim.opt.${x}`)}</option>)}</select></label>
        <NumField label={t('sim.difSize')} value={d.size} step={0.05} onChange={(v) => setD({ ...d, size: v })} />
        <button type="button" className="btn" disabled={!d.name.trim() || !d.group || !d.item} onClick={() => {
          setPop({ ...pop, dif: [...(pop.dif ?? []), { name: d.name.trim(), group: d.group, effects: [{ item: d.item, type: d.type, size: toNum(d.size) }] }] });
          setD({ ...d, name: '' });
        }}>{t('sim.difAdd')}</button>
      </div>
      <p className="muted small">{t('sim.difNote')}</p>
    </fieldset>
  );
}

function JobPanel({ id, onDone }: { id: string; onDone: () => void }) {
  const { t } = useTranslation();
  const lang = useLang();
  const q = useQuery({ queryKey: ['job', id], queryFn: () => getJob(id), refetchInterval: (qq) => {
    const s = (qq.state.data as JobStatus | undefined)?.status; return s === 'running' || s === 'queued' ? 1000 : false;
  } });
  const cancel = useMutation({ mutationFn: () => cancelJob(id), onSuccess: () => q.refetch() });
  const resume = useMutation({ mutationFn: () => resumeJob(id), onSuccess: () => q.refetch() });
  const st = q.data;
  useEffect(() => { if (st?.status === 'done') onDone(); }, [st?.status, onDone]);
  if (!st) return <Busy label={t('result.running')} />;
  return (
    <div className="job-panel" data-testid="job-panel" data-status={st.status} data-job-id={id}>
      <p><strong>{t(`sim.status.${st.status}`)}</strong> · <span data-testid="job-progress">{st.text[lang].progress}</span></p>
      <progress max={1} value={st.progress} aria-label={t('sim.progressAria')} />
      <p className="muted small">{t('sim.elapsed')}: {st.text[lang].elapsed} · {t('sim.eta')}: {st.text[lang].eta}</p>
      {st.error && <p className="warning-line">{st.error}</p>}
      <div className="actions">
        <button type="button" className="btn" disabled={!(st.status === 'running' || st.status === 'queued')} onClick={() => cancel.mutate()}>{t('sim.cancel')}</button>
        <button type="button" className="btn" disabled={!['cancelled', 'failed', 'timeout'].includes(st.status)} onClick={() => resume.mutate()}>{t('sim.resume')}</button>
      </div>
    </div>
  );
}

export function SimulationPage() {
  const { t } = useTranslation();
  const lang = useLang();
  const ds = useDataset();
  const groupCol = ds.roles ? Object.entries(ds.roles.roles).find(([, r]) => r === 'group')?.[0] : undefined;
  const groupVals = ds.roles?.group_valid_values?.length ? ds.roles.group_valid_values : (ds.overview?.columns.find((c) => c.name === groupCol)?.values ?? []);
  const [pop, setPopState] = useState<Pop>(() => starterPopulation(ds.model, groupVals));
  const [text, setText] = useState(() => JSON.stringify(pop, null, 2));
  const [jsonError, setJsonError] = useState<string | null>(null);
  const setPop = (p: Pop) => { setPopState(p); setText(JSON.stringify(p, null, 2)); setJsonError(null); };
  const [c, setC] = useState({ N: '300, 600, 1000', ratios: '50/50', reps: '200', seed: '20261030', chunk: '50', paIter: '100', shift: '0' });
  const [est, setEst] = useState<Estimator[]>(['ML']);
  const [powerStep, setPowerStep] = useState<'auto' | 'metric' | 'scalar'>('auto');
  const [an, setAn] = useState({ cfa: true, invariance: true, reliability: true, pa: false, perCell: true });
  const [jobId, setJobId] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const twoGroups = (pop.groups ?? []).length >= 2;
  // Senaryolar: kontrol (değişmez) senaryosu ve dif[] içindekilerin tümü; adlarını R kurar.
  const body = () => ({
    population: pop, conditions: { N: parseList(c.N), ratios: twoGroups ? parseRatios(c.ratios) : undefined },
    estimators: est, reps: toNum(c.reps), seed: toNum(c.seed), chunk_size: toNum(c.chunk),
    analyses: { cfa: an.cfa, invariance: an.invariance && twoGroups, reliability: an.reliability, pa: { enabled: an.pa, n_iter: toNum(c.paIter), per_cell: an.perCell } },
    recommend: { power_step: powerStep },
  });
  const fromCfa = useMutation({ mutationFn: () => populationFromCfa(ds.results.cfa!.analysis_id, toNum(c.shift)), onSuccess: (r) => setPop({ ...r.population, groups: pop.groups, dif: [] }) });
  const estimate = useMutation({ mutationFn: () => estimateSimulation(body()) });
  const start = useMutation({ mutationFn: () => startSimulation(body()), onSuccess: (s) => { setJobId(s.job_id); setDone(false); } });
  const results = useQuery({ queryKey: ['sim-results', jobId], queryFn: () => getSimResults(jobId!), enabled: !!jobId && done });
  const rec = results.data;
  const power = rec?.figures.find((f) => f.type === 'power_curve');
  const bias = rec?.figures.find((f) => f.type === 'bias_heatmap');

  return (
    <>
      <div className="sim-banner" role="note">{t('simulation.banner')}</div>
      <PageHeader pageKey="simulation" />
      <section className="card" aria-labelledby="pop-title">
        <h2 id="pop-title">{t('sim.popTitle')}</h2>
        <div className="actions">
          <button type="button" className="btn" onClick={() => setPop(starterPopulation(ds.model, groupVals))}>{t('sim.fromModel')}</button>
          <button type="button" className="btn" disabled={!ds.results.cfa || fromCfa.isPending} onClick={() => fromCfa.mutate()}>{t('sim.fromCfa')}</button>
          <NumField label={t('sim.shift')} value={c.shift} min={0} max={0.3} step={0.05} onChange={(v) => setC({ ...c, shift: v })} />
          <label className="btn file-btn">{t('sim.importJson')}
            <input type="file" accept=".json,application/json" onChange={async (e) => {
              const f = e.target.files?.[0]; if (!f) return;
              try { setPop(JSON.parse(await f.text()) as Pop); } catch (err) { setJsonError(String(err)); }
            }} /></label>
          <button type="button" className="btn" onClick={() => {
            const url = URL.createObjectURL(new Blob([text], { type: 'application/json' }));
            const a = document.createElement('a'); a.href = url; a.download = 'population.json'; a.click(); URL.revokeObjectURL(url);
          }}>{t('sim.exportJson')}</button>
        </div>
        {fromCfa.data && <ul className="list">{(lang === 'tr' ? fromCfa.data.notes_tr : fromCfa.data.notes_en).map((n) => <li key={n} className="small">{n}</li>)}</ul>}
        <ErrorBox error={fromCfa.error} />
        <label className="field"><span>{t('sim.popJson')}</span>
          <textarea className="syntax-input mono" rows={14} spellCheck={false} value={text} onChange={(e) => setText(e.target.value)}
                    onBlur={() => { try { setPopState(JSON.parse(text) as Pop); setJsonError(null); } catch (err) { setJsonError(String(err)); } }} /></label>
        {jsonError && <p className="warning-line" role="alert">{t('sim.jsonError')}: {jsonError}</p>}
        <p className="muted small">{t('sim.popHelp')}</p>
        {twoGroups && <DifForm pop={pop} setPop={setPop} />}
      </section>

      <section className="card" aria-labelledby="cond-title">
        <h2 id="cond-title">{t('sim.condTitle')}</h2>
        <div className="form-grid">
          <label className="field"><span>{t('sim.Ns')}</span><input className="text-input mono" value={c.N} onChange={(e) => setC({ ...c, N: e.target.value })} /></label>
          <label className="field"><span>{t('sim.ratios')}</span><input className="text-input mono" value={c.ratios} disabled={!twoGroups} onChange={(e) => setC({ ...c, ratios: e.target.value })} /></label>
          <NumField label={t('sim.reps')} value={c.reps} min={1} max={10000} step={100} onChange={(v) => setC({ ...c, reps: v })} />
          <NumField label={t('fn.seed')} value={c.seed} min={1} step={1} onChange={(v) => setC({ ...c, seed: v })} />
          <NumField label={t('sim.chunk')} value={c.chunk} min={1} step={10} onChange={(v) => setC({ ...c, chunk: v })} />
          <SelectField label={t('sim.powerStep')} value={powerStep} options={['auto', 'metric', 'scalar'] as const} disabled={!twoGroups}
                       optionLabel={(o) => t(`sim.opt.${o}`)} onChange={setPowerStep} />
        </div>
        <fieldset className="cov-box">
          <legend>{t('sim.estimators')}</legend>
          <div className="form-row">
            {(['ML', 'MLR', 'WLSMV'] as Estimator[]).map((e) => (
              <CheckField key={e} label={t(`cfa.opt.${e}`)} checked={est.includes(e)} disabled={e === 'WLSMV' && pop.data_type === 'continuous'}
                          onChange={(v) => setEst(v ? [...est, e] : est.filter((x) => x !== e))} />
            ))}
          </div>
          <p className="muted small">{t('sim.crnNote')}</p>
        </fieldset>
        <fieldset className="cov-box">
          <legend>{t('sim.analyses')}</legend>
          <div className="form-row">
            <CheckField label={t('sim.anCfa')} checked={an.cfa} onChange={(v) => setAn({ ...an, cfa: v })} />
            <CheckField label={t('sim.anInv')} checked={an.invariance && twoGroups} disabled={!twoGroups} onChange={(v) => setAn({ ...an, invariance: v })} />
            <CheckField label={t('sim.anRel')} checked={an.reliability} onChange={(v) => setAn({ ...an, reliability: v })} />
            <CheckField label={t('sim.anPa')} checked={an.pa} onChange={(v) => setAn({ ...an, pa: v })} />
            <CheckField label={t('sim.perCell')} checked={an.perCell} disabled={!an.pa} onChange={(v) => setAn({ ...an, perCell: v })} hint={t('sim.perCellHint')} />
            <NumField label={t('sim.paIter')} value={c.paIter} min={10} step={10} disabled={!an.pa} onChange={(v) => setC({ ...c, paIter: v })} />
          </div>
        </fieldset>
        <div className="actions">
          <button type="button" className="btn" disabled={estimate.isPending || !!jsonError} onClick={() => estimate.mutate()}>{t('sim.estimate')}</button>
          <button type="button" className="btn btn-primary" disabled={start.isPending || !!jsonError || !est.length} onClick={() => start.mutate()}>{t('sim.start')}</button>
        </div>
        {estimate.isPending && <Busy label={t('sim.estimating')} />}
        {estimate.data && <p data-testid="sim-estimate">{estimate.data.text[lang]} <span className="muted small">{lang === 'tr' ? estimate.data.note_tr : estimate.data.note_en}</span></p>}
        <ErrorBox error={estimate.error} />
        <ErrorBox error={start.error} />
        {jobId && <JobPanel key={jobId} id={jobId} onDone={() => setDone(true)} />}
      </section>

      {jobId && done && (
        <section className="card" aria-labelledby="simres-title">
          <h2 id="simres-title">{t('sim.resultsTitle')}</h2>
          <div className="sim-banner" role="note">{t('simulation.banner')}</div>
          {results.isFetching && <Busy label={t('result.running')} />}
          <ErrorBox error={results.error} />
          {rec && (
            <div className="result">
              {power && <figure className="chart-figure"><figcaption className="rtable-title">{t('sim.powerTitle')}</figcaption><PowerChart data={power.data as unknown as PowerCurveData} /><p className="table-note">{t('sim.powerNote')}</p></figure>}
              {bias && (() => { const bd = bias.data as unknown as BiasHeatmapData; return (
                <figure className="chart-figure"><figcaption className="rtable-title">{t('sim.biasTitle', { est: bd.estimator })}</figcaption>
                  <BiasHeatmap data={bd} /><p className="table-note">{lang === 'tr' ? bd.note_tr : bd.note_en}</p></figure>); })()}
              {[...rec.tables].sort((a, b) => (a.id === 'T7' ? -1 : b.id === 'T7' ? 1 : 0)).map((tb) => <RTable key={tb.id} table={tb} />)}
              <Warnings warnings={rec.warnings} />
              <div className="actions">
                <button type="button" className="btn" onClick={async () => {
                  const blob = await downloadSimPackage(jobId);
                  const url = URL.createObjectURL(blob); const a = document.createElement('a'); a.href = url; a.download = 'olceklab_simulasyon.zip'; a.click(); URL.revokeObjectURL(url);
                }}>{t('sim.package')}</button>
              </div>
            </div>
          )}
        </section>
      )}
    </>
  );
}
