import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';

export function NeedsCleanData() {
  const { t } = useTranslation();
  return (
    <section className="card placeholder">
      <p>{t('result.needsClean')}</p>
      <Link className="btn" to="/data">{t('result.goToData')}</Link>
    </section>
  );
}
