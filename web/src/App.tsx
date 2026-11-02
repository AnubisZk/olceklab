import { Route, Routes } from 'react-router';
import { Layout } from './components/Layout';
import { pages } from './routes';
import { StartPage } from './pages/StartPage';
import { SettingsPage } from './pages/SettingsPage';
import { PhasePage } from './pages/PhasePage';
import { NotFoundPage } from './pages/NotFoundPage';

export function App() {
  return (
    <Layout>
      <Routes>
        {pages.map((p) => (
          <Route
            key={p.key}
            path={p.path}
            element={p.key === 'start' ? <StartPage /> : p.key === 'settings' ? <SettingsPage /> : <PhasePage page={p} />}
          />
        ))}
        <Route path="*" element={<NotFoundPage />} />
      </Routes>
    </Layout>
  );
}
