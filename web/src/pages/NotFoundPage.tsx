import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { PageHeader } from './PageHeader';

export function NotFoundPage() {
  const { t } = useTranslation();
  return (
    <>
      <PageHeader pageKey="notFound" />
      <Link className="btn" to="/">{t('pages.notFound.back')}</Link>
    </>
  );
}
