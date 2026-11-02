import { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { cleanDataset, loadExample, saveRoles, uploadDataset } from '../api/analysis';
import type { CleanRules, ColumnSummary, DatasetOverview, ItemSetting, Role, RolesBody } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useLang } from '../useLang';
import { RTable } from '../components/RTable';
import { Busy, ErrorBox, Warnings } from '../components/ResultParts';
import { PageHeader } from './PageHeader';

const ROLES: Role[] = ['item', 'group', 'id', 'ignore'];
const RULES: (keyof CleanRules)[] = ['invalid_group', 'out_of_range', 'missing', 'straightline', 'reverse'];

interface RoleRow { role: Role; min: string; max: string; reverse: boolean; subscale: string }

// Başlangıç değerleri R'nin döndürdüğü önerilerden alınır (örnek veri için hazır yapılandırma).
function initialRows(o: DatasetOverview): Record<string, RoleRow> {
  const out: Record<string, RoleRow> = {};
  const sc = o.suggested_config;
  for (const c of o.columns) {
    const it: ItemSetting | undefined = sc?.items?.[c.name];
    const role = sc?.roles?.[c.name] ?? c.suggested_role;
    const likert = c.integer_valued && c.n_unique <= 11 && c.min != null && c.max != null;
    out[c.name] = {
      role,
      min: it?.min != null ? String(it.min) : !sc && likert ? String(c.min) : '',
      max: it?.max != null ? String(it.max) : !sc && likert ? String(c.max) : '',
      reverse: it?.reverse ?? false,
      subscale: it?.subscale ?? '',
    };
  }
  return out;
}

function toBody(rows: Record<string, RoleRow>, validGroups: string): RolesBody {
  const roles: Record<string, Role> = {};
  const items: Record<string, ItemSetting> = {};
  for (const [name, r] of Object.entries(rows)) {
    roles[name] = r.role;
    if (r.role === 'item') {
      const it: ItemSetting = { reverse: r.reverse };
      if (r.min !== '' || r.max !== '') { it.min = Number(r.min); it.max = Number(r.max); }
      if (r.subscale.trim()) it.subscale = r.subscale.trim();
      items[name] = it;
    }
  }
  const body: RolesBody = { roles, items };
  const vg = validGroups.split(',').map((s) => s.trim()).filter(Boolean);
  if (vg.length) body.group_valid_values = vg;
  return body;
}

function UploadCard() {
  const { t } = useTranslation();
  const ds = useDataset();
  const fileRef = useRef<HTMLInputElement>(null);
  const upload = useMutation({ mutationFn: uploadDataset, onSuccess: ds.setOverview });
  const example = useMutation({ mutationFn: loadExample, onSuccess: ds.setOverview });
  const busy = upload.isPending || example.isPending;
  return (
    <section className="card" aria-labelledby="upload-title">
      <h2 id="upload-title">{t('data.uploadTitle')}</h2>
      <p className="notice" role="note">{t('data.privacyNotice')}</p>
      <div className="actions">
        <label className="btn btn-primary file-btn">
          {t('data.chooseFile')}
          <input ref={fileRef} type="file" accept=".csv,.txt,.tsv,.xlsx,.xls" disabled={busy}
                 onChange={(e) => { const f = e.target.files?.[0]; if (f) upload.mutate(f); e.target.value = ''; }} />
        </label>
        <button type="button" className="btn" disabled={busy} onClick={() => example.mutate('bfi')}>{t('data.exampleBfi')}</button>
        <button type="button" className="btn" disabled={busy} onClick={() => example.mutate('holzinger')}>{t('data.exampleHolzinger')}</button>
      </div>
      <p className="muted small">{t('data.formats')}</p>
      {busy && <Busy label={t('data.reading')} />}
      <ErrorBox error={upload.error ?? example.error} />
    </section>
  );
}

function DatasetSummary({ o }: { o: DatasetOverview }) {
  const { t } = useTranslation();
  const ds = useDataset();
  return (
    <section className="card" aria-labelledby="ds-title">
      <header className="card-header">
        <h2 id="ds-title">{o.filename}</h2>
        <button type="button" className="btn btn-ghost" onClick={ds.reset}>{t('data.another')}</button>
      </header>
      <dl className="kv">
        <dt>{t('data.rows')}</dt><dd className="mono" data-testid="n-rows">{o.n_rows}</dd>
        <dt>{t('data.cols')}</dt><dd className="mono">{o.n_cols}</dd>
        {o.source.label && (<><dt>{t('data.source')}</dt><dd>{o.source.label}</dd></>)}
        <dt>SHA-256</dt><dd className="mono small">{o.dataset_hash}</dd>
      </dl>
    </section>
  );
}

function RolesCard({ o }: { o: DatasetOverview }) {
  const { t } = useTranslation();
  const ds = useDataset();
  const [rows, setRows] = useState<Record<string, RoleRow>>(() => initialRows(o));
  const [validGroups, setValidGroups] = useState('');
  useEffect(() => { setRows(initialRows(o)); setValidGroups(''); }, [o]);
  const save = useMutation({
    mutationFn: (body: RolesBody) => saveRoles(o.dataset_id, body).then(() => body),
    onSuccess: ds.setRoles,
  });
  const set = (name: string, patch: Partial<RoleRow>) => setRows((r) => ({ ...r, [name]: { ...r[name], ...patch } }));
  const ids = o.identifier_suggestions;
  const groupCol = Object.entries(rows).find(([, r]) => r.role === 'group')?.[0];
  const groupSummary: ColumnSummary | undefined = o.columns.find((c) => c.name === groupCol);

  return (
    <section className="card" aria-labelledby="roles-title">
      <h2 id="roles-title">{t('data.rolesTitle')}</h2>
      {ids.length > 0 && (
        <div className="notice" role="note">
          <p>{t('data.idDetected')}: <span className="mono">{ids.map((s) => `${s.column} (${t(`data.idReason.${s.reason}`)})`).join(', ')}</span></p>
          <p className="small muted">{t('data.idHeuristic')}</p>
          <button type="button" className="btn" onClick={() => ids.forEach((s) => set(s.column, { role: 'ignore' }))}>
            {t('data.idExclude')}
          </button>
        </div>
      )}
      <div className="table-wrap">
        <table className="roles-table">
          <thead>
            <tr>
              <th scope="col">{t('data.col.name')}</th><th scope="col">{t('data.col.type')}</th>
              <th scope="col" className="num">{t('data.col.missing')}</th><th scope="col">{t('data.col.values')}</th>
              <th scope="col">{t('data.col.role')}</th><th scope="col">{t('data.col.min')}</th>
              <th scope="col">{t('data.col.max')}</th><th scope="col">{t('data.col.reverse')}</th>
              <th scope="col">{t('data.col.subscale')}</th>
            </tr>
          </thead>
          <tbody>
            {o.columns.map((c) => {
              const r = rows[c.name];
              const isItem = r?.role === 'item';
              return (
                <tr key={c.name}>
                  <th scope="row" className="mono">{c.name}</th>
                  <td>{t(`data.type.${c.type}`)}</td>
                  <td className="num mono">{c.n_missing}</td>
                  <td className="mono small values-cell">{c.values.join(', ')}{c.n_unique > c.values.length ? ' …' : ''}</td>
                  <td>
                    <select aria-label={`${c.name} ${t('data.col.role')}`} value={r?.role} onChange={(e) => set(c.name, { role: e.target.value as Role })}>
                      {ROLES.map((ro) => <option key={ro} value={ro}>{t(`data.role.${ro}`)}</option>)}
                    </select>
                  </td>
                  <td><input aria-label={`${c.name} ${t('data.col.min')}`} className="num-input" type="number" step={1} disabled={!isItem} value={r?.min ?? ''} onChange={(e) => set(c.name, { min: e.target.value })} /></td>
                  <td><input aria-label={`${c.name} ${t('data.col.max')}`} className="num-input" type="number" step={1} disabled={!isItem} value={r?.max ?? ''} onChange={(e) => set(c.name, { max: e.target.value })} /></td>
                  <td><input aria-label={`${c.name} ${t('data.col.reverse')}`} type="checkbox" disabled={!isItem} checked={r?.reverse ?? false} onChange={(e) => set(c.name, { reverse: e.target.checked })} /></td>
                  <td><input aria-label={`${c.name} ${t('data.col.subscale')}`} className="text-input" type="text" disabled={!isItem} value={r?.subscale ?? ''} onChange={(e) => set(c.name, { subscale: e.target.value })} /></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {groupSummary && (
        <label className="field">
          <span>{t('data.validGroups')} <span className="muted small">({t('data.observedValues')}: {groupSummary.values.join(', ')})</span></span>
          <input className="text-input" type="text" value={validGroups} placeholder={groupSummary.values.join(', ')} onChange={(e) => setValidGroups(e.target.value)} />
          <span className="muted small">{t('data.validGroupsHelp')}</span>
        </label>
      )}
      <div className="actions">
        <button type="button" className="btn btn-primary" disabled={save.isPending} onClick={() => save.mutate(toBody(rows, validGroups))}>
          {t('data.saveRoles')}
        </button>
        {ds.roles && !save.isPending && !save.error && <span className="pill pill-ok">{t('data.rolesSaved')}</span>}
      </div>
      <ErrorBox error={save.error} />
    </section>
  );
}

function CleanCard({ o }: { o: DatasetOverview }) {
  const { t } = useTranslation();
  const lang = useLang();
  const ds = useDataset();
  const [rules, setRules] = useState<CleanRules>({ invalid_group: true, out_of_range: true, missing: true, straightline: true, reverse: true });
  const clean = useMutation({ mutationFn: () => cleanDataset(o.dataset_id, rules), onSuccess: ds.setClean });
  const rec = ds.clean;
  const summary = useMemo(() => (rec ? (lang === 'tr' ? rec.results.summary_tr : rec.results.summary_en) : ''), [rec, lang]);
  return (
    <section className="card" aria-labelledby="clean-title">
      <h2 id="clean-title">{t('data.cleanTitle')}</h2>
      <p className="muted small">{t('data.cleanOrder')}</p>
      <fieldset className="rules">
        <legend className="sr-only">{t('data.cleanTitle')}</legend>
        {RULES.map((k, i) => (
          <label key={k} className="rule">
            <input type="checkbox" checked={rules[k]} onChange={(e) => setRules((r) => ({ ...r, [k]: e.target.checked }))} />
            <span className="mono nav-index">{i + 1}</span> <span>{t(`data.rule.${k}`)}</span>
          </label>
        ))}
      </fieldset>
      <div className="actions">
        <button type="button" className="btn btn-primary" disabled={clean.isPending} onClick={() => clean.mutate()}>{t('data.runClean')}</button>
      </div>
      {clean.isPending && <Busy label={t('result.running')} />}
      <ErrorBox error={clean.error} />
      {rec && (
        <div className="result">
          <p className="summary-line mono" data-testid="clean-summary">{summary}</p>
          {rec.tables.map((tb) => <RTable key={tb.id} table={tb} />)}
          <Warnings warnings={rec.warnings} />
          <Link className="btn btn-primary" to="/items">{t('data.toItems')}</Link>
        </div>
      )}
    </section>
  );
}

export function DataPage() {
  const ds = useDataset();
  const o = ds.overview;
  return (
    <>
      <PageHeader pageKey="data" />
      {!o && <UploadCard />}
      {o && <DatasetSummary o={o} />}
      {o && <RolesCard o={o} />}
      {o && ds.roles && <CleanCard o={o} />}
    </>
  );
}
