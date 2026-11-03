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
const EfaPage = lazy(() => import('./pages/EfaPage').then((m) => ({ default: m.EfaPage })));
const CfaPage = lazy(() => import('./pages/CfaPage').then((m) => ({ default: m.CfaPage })));
const InvariancePage = lazy(() => import('./pages/InvariancePage').then((m) => ({ default: m.InvariancePage })));
const SimulationPage = lazy(() => import('./pages/SimulationPage').then((m) => ({ default: m.SimulationPage })));
const ReportPage = lazy(() => import('./pages/ReportPage').then((m) => ({ default: m.ReportPage })));
const ReliabilityPage = lazy(() => import('./pages/ReliabilityPage').then((m) => ({ default: m.ReliabilityPage })));

const implemented: Partial<Record<PageKey, ComponentType>> = {
  start: StartPage,
  settings: SettingsPage,
  data: DataPage,
  items: ItemsPage,
  factorNumber: FactorNumberPage,
  efa: EfaPage,
  cfa: CfaPage,
  reliability: ReliabilityPage,
  invariance: InvariancePage,
  simulation: SimulationPage,
  report: ReportPage,
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
