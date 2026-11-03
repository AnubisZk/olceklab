import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { exportProject, reportDocx, reportPreview } from '../api/analysis';
import { saveBlob } from '../api/client';
import type { Lang, TextSegment } from '../api/types';
import { useDataset } from '../state/DatasetContext';
import { useReport } from '../state/ReportContext';
import { useLang } from '../useLang';
import { Busy, ErrorBox } from '../components/ResultParts';
import { SelectField } from '../components/Fields';
import { PageHeader } from './PageHeader';

// M10 rapor ve M12 proje dosyası. Metinler ve tablolar R motorunda üretilir; bu sayfa yalnızca sırayı ve seçenekleri tutar.

function Segments({ segs }: { segs: TextSegment[] }) {
  return <p>{segs.map((s, i) => (s.italic ? <em key={i}>{s.text}</em> : <span key={i}>{s.text}</span>))}</p>;
}

function ProjectExport() {
  const { t } = useTranslation();
  const ds = useDataset();
  const [withData, setWithData] = useState(false);
  const [consent, setConsent] = useState(false);
  const example = ds.overview?.source.type === 'example';
  const ids = [ds.clean?.analysis_id, ...Object.values(ds.results).map((r) => r?.analysis_id)].filter((x): x is string => !!x);
  const m = useMutation({
    mutationFn: () => exportProject({ dataset_id: ds.overview!.dataset_id, analysis_ids: ids, include_data: withData && !example, data_consent: consent }),
    onSuccess: (b) => saveBlob(b, `${(ds.overview?.filename ?? 'proje').replace(/\.[^.]+$/, '')}.olceklab.zip`),
  });
  return (
    <section className="card" aria-labelledby="proj-title">
      <h2 id="proj-title">{t('report.projectTitle')}</h2>
      <p className="muted small">{t('report.projectHelp')}</p>
      {!ds.clean ? <p className="muted">{t('report.projectNeedsClean')}</p> : (
        <>
          <p className="small">{t('report.projectCount', { count: ids.length })}</p>
          {example ? <p className="muted small">{t('report.projectExample')}</p> : (
            <div className="form-row">
              <label className="rule"><input type="checkbox" checked={withData} onChange={(e) => { setWithData(e.target.checked); if (!e.target.checked) setConsent(false); }} />
                <span>{t('report.includeData')}</span></label>
              <label className="rule"><input type="checkbox" checked={consent} disabled={!withData} onChange={(e) => setConsent(e.target.checked)} />
                <span>{t('report.consent')}</span></label>
            </div>
          )}
          <div className="actions">
            <button type="button" className="btn" disabled={m.isPending || (withData && !consent)} onClick={() => m.mutate()}>{t('report.exportProject')}</button>
          </div>
          {m.isPending && <Busy label={t('report.exporting')} />}
          <ErrorBox error={m.error} />
        </>
      )}
    </section>
  );
}

export function ReportPage() {
  const { t } = useTranslation();
  const uiLang = useLang();
  const report = useReport();
  const [lang, setLang] = useState<Lang>(uiLang);
  const [title, setTitle] = useState('');
  const ids = report.items.map((x) => x.analysis_id);
  const preview = useMutation({ mutationFn: () => reportPreview(ids, lang) });
  const docx = useMutation({ mutationFn: () => reportDocx(ids, lang, title), onSuccess: (b) => saveBlob(b, 'olceklab_rapor.docx') });
  return (
    <>
      <PageHeader pageKey="report" />
      <section className="card" aria-labelledby="rep-title">
        <h2 id="rep-title">{t('report.itemsTitle')}</h2>
        {!report.items.length ? <p className="muted">{t('report.empty')}</p> : (
          <ol className="report-list" data-testid="report-items">
            {report.items.map((it, i) => (
              <li key={it.analysis_id} data-module={it.module}>
                <span>{t(`report.modules.${it.module}`, { defaultValue: it.module })}</span>
                <span className="muted small mono"> {it.analysis_id.slice(0, 8)}</span>
                <span className="report-item-actions">
                  <button type="button" className="btn btn-small" disabled={i === 0} aria-label={t('report.up')} onClick={() => report.move(it.analysis_id, -1)}>↑</button>
                  <button type="button" className="btn btn-small" disabled={i === report.items.length - 1} aria-label={t('report.down')} onClick={() => report.move(it.analysis_id, 1)}>↓</button>
                  <button type="button" className="btn btn-small" aria-label={t('report.remove')} onClick={() => report.remove(it.analysis_id)}>✕</button>
                </span>
              </li>
            ))}
          </ol>
        )}
        <div className="form-row">
          <SelectField label={t('report.lang')} value={lang} options={['tr', 'en'] as const} optionLabel={(o) => (o === 'tr' ? 'Türkçe' : 'English')} onChange={setLang} />
          <label className="field"><span>{t('report.docTitle')}</span>
            <input className="text-input" value={title} placeholder={t('report.docTitlePlaceholder')} onChange={(e) => setTitle(e.target.value)} /></label>
        </div>
        <div className="actions">
          <button type="button" className="btn" disabled={!ids.length || preview.isPending} onClick={() => preview.mutate()}>{t('report.preview')}</button>
          <button type="button" className="btn btn-primary" disabled={!ids.length || docx.isPending} onClick={() => docx.mutate()}>{t('report.docx')}</button>
        </div>
        <p className="muted small">{t('report.noAi')}</p>
        {(preview.isPending || docx.isPending) && <Busy label={t('result.running')} />}
        <ErrorBox error={preview.error} />
        <ErrorBox error={docx.error} />
      </section>
      {preview.data && (
        <section className="card report-preview" aria-labelledby="prev-title" lang={preview.data.lang}>
          <h2 id="prev-title">{t('report.previewTitle')}</h2>
          <p className="muted small">{preview.data.note}</p>
          {preview.data.items.map((it) => (
            <article key={it.analysis_id} data-module={it.module}>
              <h3>{it.title}</h3>
              {it.methods.length > 0 && <><h4>{lang === 'tr' ? 'Yöntem' : 'Method'}</h4>{it.methods.map((p, i) => <Segments key={i} segs={p} />)}</>}
              {it.results.length > 0 && <><h4>{lang === 'tr' ? 'Bulgular' : 'Results'}</h4>{it.results.map((p, i) => <Segments key={i} segs={p} />)}</>}
              {it.limitations.length > 0 && <><h4>{lang === 'tr' ? 'Sınırlılıklar' : 'Limitations'}</h4>{it.limitations.map((p, i) => <Segments key={i} segs={p} />)}</>}
              <ul className="list small">{it.tables.map((tb) => <li key={tb.id}>{lang === 'tr' ? 'Tablo' : 'Table'} {tb.number}. <em>{tb.title}</em></li>)}</ul>
            </article>
          ))}
          {(preview.data.references ?? []).length > 0 && (
            <><h3>{lang === 'tr' ? 'Kaynakça' : 'References'}</h3><ul className="list small">{preview.data.references.map((r) => <li key={r}>{r}</li>)}</ul></>
          )}
        </section>
      )}
      <ProjectExport />
    </>
  );
}
