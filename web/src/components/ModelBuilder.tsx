import { useEffect, useMemo, useState, type DragEvent } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { previewModel } from '../api/analysis';
import type { FactorSpec, ModelSpec } from '../api/types';
import { useLang } from '../useLang';
import { ErrorBox } from './ResultParts';

// DFA model kurucu (SPEC §7 M6). Maddeler faktörlere sürükle-bırak ya da her maddenin yanındaki
// seçim kutusuyla (klavye ile erişilebilir) atanır. lavaan sözdizimi R motorunda üretilir ve
// doğrulanır (/models/preview); ön yüz sözdizimi üretmez.

const POOL = '__pool__';

function nextFactorName(factors: FactorSpec[]): string {
  let k = factors.length + 1;
  while (factors.some((f) => f.name === `F${k}`)) k += 1;
  return `F${k}`;
}

export function ModelBuilder({ datasetId, items, value, onChange }: {
  datasetId: string; items: string[]; value: ModelSpec; onChange: (m: ModelSpec) => void;
}) {
  const { t } = useTranslation();
  const lang = useLang();
  const syntaxMode = value.syntax !== undefined;
  const factors = useMemo(() => value.factors ?? [], [value.factors]);
  const covs = value.covariances ?? [];
  const assigned = new Set(factors.flatMap((f) => f.items));
  const pool = items.filter((i) => !assigned.has(i));
  const [covA, setCovA] = useState('');
  const [covB, setCovB] = useState('');
  const [draft, setDraft] = useState(value.syntax ?? '');
  useEffect(() => { if (value.syntax !== undefined) setDraft(value.syntax); }, [value.syntax]);

  const key = JSON.stringify(value);
  const preview = useQuery({
    queryKey: ['model-preview', datasetId, key],
    queryFn: () => previewModel(datasetId, value),
    enabled: syntaxMode ? !!value.syntax?.trim() : factors.length > 0,
    staleTime: Infinity,
  });

  const setFactors = (fs: FactorSpec[]) => {
    const inModel = new Set(fs.flatMap((f) => f.items));
    onChange({ factors: fs, covariances: covs.filter(([a, b]) => inModel.has(a) && inModel.has(b)) });
  };
  const moveItem = (item: string, target: string) => {
    const fs = factors.map((f) => ({ ...f, items: f.items.filter((i) => i !== item) }));
    if (target !== POOL) {
      const f = fs.find((x) => x.name === target);
      if (f) f.items = items.filter((i) => i === item || f.items.includes(i));
    }
    setFactors(fs);
  };
  const onDrop = (target: string) => (e: DragEvent) => {
    e.preventDefault();
    const item = e.dataTransfer.getData('text/plain');
    if (item) moveItem(item, target);
  };
  const allowDrop = (e: DragEvent) => e.preventDefault();

  const chip = (item: string, current: string) => (
    <li key={item} className="chip" draggable onDragStart={(e) => e.dataTransfer.setData('text/plain', item)} data-item={item}>
      <span className="mono">{item}</span>
      <select aria-label={t('model.moveItem', { item })} value={current} onChange={(e) => moveItem(item, e.target.value)}>
        <option value={POOL}>{t('model.unassigned')}</option>
        {factors.map((f) => <option key={f.name} value={f.name}>{f.name}</option>)}
      </select>
    </li>
  );

  return (
    <div className="model-builder">
      <div className="segmented" role="group" aria-label={t('model.mode')}>
        <button type="button" aria-pressed={!syntaxMode} onClick={() => {
          if (syntaxMode && preview.data?.factors?.length && preview.data.source === 'syntax') {
            onChange({ factors: preview.data.factors.map((f) => ({ name: f.name, items: [...f.items] })), covariances: preview.data.covariances });
          } else if (syntaxMode) onChange({ factors: [], covariances: [] });
        }}>{t('model.builderMode')}</button>
        <button type="button" aria-pressed={syntaxMode} onClick={() => {
          if (!syntaxMode) onChange({ syntax: preview.data?.syntax ?? '' });
        }}>{t('model.syntaxMode')}</button>
      </div>

      {!syntaxMode ? (
        <>
          <div className="builder-grid">
            <section className="builder-col pool" onDragOver={allowDrop} onDrop={onDrop(POOL)} aria-label={t('model.unassigned')}>
              <h4>{t('model.unassigned')} <span className="muted small">({pool.length})</span></h4>
              <ul className="chips">{pool.map((i) => chip(i, POOL))}</ul>
            </section>
            {factors.map((f, k) => (
              <section key={k} className="builder-col factor" onDragOver={allowDrop} onDrop={onDrop(f.name)} data-factor={f.name}>
                <div className="factor-head">
                  <input className="text-input factor-name" aria-label={t('model.factorName', { n: k + 1 })} value={f.name}
                         onChange={(e) => setFactors(factors.map((x, j) => (j === k ? { ...x, name: e.target.value } : x)))} />
                  <button type="button" className="btn btn-ghost small" aria-label={t('model.removeFactor', { name: f.name })}
                          onClick={() => setFactors(factors.filter((_, j) => j !== k))}>×</button>
                </div>
                <ul className="chips">{f.items.map((i) => chip(i, f.name))}</ul>
                {f.items.length === 0 && <p className="muted small">{t('model.dropHere')}</p>}
              </section>
            ))}
          </div>
          <div className="actions">
            <button type="button" className="btn" onClick={() => setFactors([...factors, { name: nextFactorName(factors), items: [] }])}>{t('model.addFactor')}</button>
          </div>
          <fieldset className="cov-box">
            <legend>{t('model.covTitle')}</legend>
            <div className="form-row">
              <label className="field"><span>{t('model.covA')}</span>
                <select value={covA} onChange={(e) => setCovA(e.target.value)}>
                  <option value="">—</option>{[...assigned].map((i) => <option key={i} value={i}>{i}</option>)}
                </select></label>
              <label className="field"><span>{t('model.covB')}</span>
                <select value={covB} onChange={(e) => setCovB(e.target.value)}>
                  <option value="">—</option>{[...assigned].filter((i) => i !== covA).map((i) => <option key={i} value={i}>{i}</option>)}
                </select></label>
              <button type="button" className="btn" disabled={!covA || !covB || covA === covB}
                      onClick={() => { onChange({ factors, covariances: [...covs, [covA, covB]] }); setCovA(''); setCovB(''); }}>{t('model.covAdd')}</button>
            </div>
            {covs.length > 0 && (
              <ul className="list">
                {covs.map(([a, b], k) => (
                  <li key={`${a}-${b}-${k}`}><span className="mono">{a} ~~ {b}</span>{' '}
                    <button type="button" className="btn btn-ghost small" onClick={() => onChange({ factors, covariances: covs.filter((_, j) => j !== k) })}>{t('model.covRemove')}</button>
                  </li>
                ))}
              </ul>
            )}
            <p className="muted small">{t('model.covNote')}</p>
          </fieldset>
        </>
      ) : (
        <div className="field">
          <label className="field">
            <span>{t('model.syntaxLabel')}</span>
            <textarea className="syntax-input mono" rows={8} spellCheck={false} value={draft} onChange={(e) => setDraft(e.target.value)}
                      onBlur={() => onChange({ syntax: draft })} />
          </label>
          <span className="muted small">{t('model.syntaxHint')}</span>
        </div>
      )}

      <div className="syntax-preview">
        <h4>{t('model.previewTitle')}</h4>
        {preview.isFetching && <p className="muted small">{t('result.running')}</p>}
        <ErrorBox error={preview.error} />
        {preview.data && !preview.error && (
          <>
            <pre className="mono" data-testid="model-syntax">{preview.data.syntax}</pre>
            {preview.data.warnings.map((w, i) => <p key={i} className="warning-line" data-code={w.code}>{lang === 'tr' ? w.message_tr : w.message_en}</p>)}
          </>
        )}
      </div>
    </div>
  );
}
