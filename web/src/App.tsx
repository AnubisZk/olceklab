import { lazy, Suspense, type ComponentType } from 'react';
import { useTranslation } from 'react-i18next';
import { Route, Routes } from 'react-router';
import { Layout } from './components/Layout';
import { pages, type PageKey } from './routes';
import { StartPage } from './pages/StartPage';
import { SettingsPage } from './pages/SettingsPage';
import { PhasePage } from './pages/PhasePage';
import { NotFoundPage } from './pages/NotFoundPage';
import { DataPage } from './pages/DataPage';
// Grafik içeren sayfalar (ECharts) ayrı parçada, ihtiyaç olunca yüklenir.
const ItemsPage = lazy(() => import('./pages/ItemsPage').then((m) => ({ default: m.ItemsPage })));
const FactorNumberPage = lazy(() => import('./pages/FactorNumberPage').then((m) => ({ default: m.FactorNumberPage })));

const implemented: Partial<Record<PageKey, ComponentType>> = {
  start: StartPage,
  settings: SettingsPage,
  data: DataPage,
  items: ItemsPage,
  factorNumber: FactorNumberPage,
};

function Loading() {
  const { t } = useTranslation();
  return <p className="busy" role="status">{t('engine.loading')}</p>;
}

export function App() {
  return (
    <Layout>
      <Suspense fallback={<Loading />}>
      <Routes>
        {pages.map((p) => {
          const Page = implemented[p.key];
          return <Route key={p.key} path={p.path} element={Page ? <Page /> : <PhasePage page={p} />} />;
        })}
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
      </Suspense>
    </Layout>
  );
}
