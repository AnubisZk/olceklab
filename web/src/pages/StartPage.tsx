import { useNavigate } from 'react-router';
import { useMutation } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { loadExample } from '../api/analysis';
import { useDataset } from '../state/DatasetContext';
import { EngineStatus } from '../components/EngineStatus';
import { ErrorBox } from '../components/ResultParts';
import { PageHeader } from './PageHeader';
import { ProjectImport } from './ProjectImport';

export function StartPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const ds = useDataset();
  const example = useMutation({
    mutationFn: () => loadExample('bfi'),
    onSuccess: (o) => { ds.setOverview(o); void navigate('/data'); },
  });
  return (
    <>
      <PageHeader pageKey="start" />
      <section className="card">
        <div className="actions">
          <button type="button" className="btn btn-primary" onClick={() => { ds.reset(); void navigate('/data'); }}>{t('start.newProject')}</button>
          <a className="btn" href="#imp-title">{t('start.importProject')}</a>
          <button type="button" className="btn" disabled={example.isPending} onClick={() => example.mutate()}>{t('start.tryExample')}</button>
        </div>
        <ErrorBox error={example.error} />
      </section>
      <ProjectImport />
      <EngineStatus />
    </>
  );
}
