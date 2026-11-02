import { useTranslation } from 'react-i18next';
import { EngineStatus } from '../components/EngineStatus';
import { PageHeader } from './PageHeader';

export function StartPage() {
  const { t } = useTranslation();
  return (
    <>
      <PageHeader pageKey="start" />
      <section className="card">
        <div className="actions">
          <button type="button" className="btn btn-primary" disabled>{t('start.newProject')}</button>
          <button type="button" className="btn" disabled>{t('start.importProject')}</button>
          <button type="button" className="btn" disabled>{t('start.tryExample')}</button>
        </div>
        <p className="muted small">{t('start.actionsPhase')}</p>
      </section>
      <EngineStatus />
    </>
  );
}
