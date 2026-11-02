import { useTranslation } from 'react-i18next';
import type { PageDef } from '../routes';
import { PageHeader } from './PageHeader';

// Henüz uygulanmamış sayfalar: hiçbir analiz çalışmaz, hiçbir sayı gösterilmez.
export function PhasePage({ page }: { page: PageDef }) {
  const { t } = useTranslation();
  return (
    <>
      {page.key === 'simulation' && (
        <div className="sim-banner" role="note">{t('simulation.banner')}</div>
      )}
      <PageHeader pageKey={page.key} phase={page.phase} />
      <section className="card placeholder">
        <p>{t('phase.placeholder', { phase: page.phase })}</p>
      </section>
    </>
  );
}
