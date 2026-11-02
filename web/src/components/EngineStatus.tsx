import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { fetchEngineVersions } from '../api/engine';
import { ApiError } from '../api/client';

// R motorunun gerçek sürüm bilgisini gösterir. Motor yanıt vermezse hiçbir
// sürüm ya da sayı göstermez; yalnızca hatayı gösterir (AGENTS kuralı 2).
export function EngineStatus() {
  const { t } = useTranslation();
  const q = useQuery({ queryKey: ['engine', 'versions'], queryFn: ({ signal }) => fetchEngineVersions(signal), retry: false });

  return (
    <section className="card" aria-labelledby="engine-status-title" aria-busy={q.isPending}>
      <header className="card-header">
        <h2 id="engine-status-title">{t('engine.title')}</h2>
        {q.isPending && <span className="pill pill-muted">{t('engine.loading')}</span>}
        {q.isSuccess && <span className="pill pill-ok">{t('engine.ok')}</span>}
        {q.isError && <span className="pill pill-error">{t('engine.error')}</span>}
      </header>

      {q.isError && (
        <div role="alert" className="error-box">
          <p>{q.error instanceof ApiError ? q.error.message : String(q.error)}</p>
          {q.error instanceof ApiError && (
            <p className="muted mono">
              {t('engine.errorCode')}: {q.error.code}
            </p>
          )}
          <button type="button" className="btn" onClick={() => q.refetch()}>
            {t('engine.retry')}
          </button>
        </div>
      )}

      {q.isSuccess && (
        <>
          <dl className="kv">
            <dt>{t('engine.rVersion')}</dt>
            <dd className="mono" data-testid="r-version">{q.data.R}</dd>
            <dt>{t('engine.rng')}</dt>
            <dd className="mono">{q.data.rng_kind.kind} / {q.data.rng_kind.normal_kind} / {q.data.rng_kind.sample_kind}</dd>
          </dl>
          {q.data.missing.length > 0 && (
            <p role="alert" className="error-box">
              {t('engine.missing')}: <span className="mono">{q.data.missing.join(', ')}</span>
            </p>
          )}
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">{t('engine.package')}</th>
                  <th scope="col">{t('engine.version')}</th>
                </tr>
              </thead>
              <tbody>
                {Object.entries(q.data.packages).map(([name, version]) => (
                  <tr key={name}>
                    <td className="mono">{name}</td>
                    <td className="mono">{version}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="table-note">{t('engine.source')}</p>
        </>
      )}
    </section>
  );
}
