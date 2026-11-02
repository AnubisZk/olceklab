import { useTranslation } from 'react-i18next';
import type { PageKey } from '../routes';

export function PageHeader({ pageKey, phase }: { pageKey: PageKey | 'notFound'; phase?: number }) {
  const { t } = useTranslation();
  return (
    <header className="page-header">
      <h1>{t(`pages.${pageKey}.title`)}</h1>
      {phase !== undefined && phase > 0 && <span className="pill pill-accent2">{t('phase.badge', { phase })}</span>}
      <p className="muted">{t(`pages.${pageKey}.description`)}</p>
    </header>
  );
}
