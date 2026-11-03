import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nextProvider } from 'react-i18next';
import { App } from '../src/App';
import { initI18n, type Language } from '../src/i18n';
import { ThemeProvider } from '../src/theme/ThemeContext';
import { DatasetProvider } from '../src/state/DatasetContext';
import { ReportProvider } from '../src/state/ReportContext';
import type { ThemeName } from '../src/theme/tokens';

// Component tests exercise rendered behavior; cold Vite transformation of lazy
// routes can exceed Testing Library's wait budget on Windows. Real lazy loading
// remains covered by Playwright, which uses the production application.
let pagesReady: Promise<unknown> | undefined;
function preparePages() {
  return pagesReady ??= Promise.all([
    import('../src/pages/ItemsPage'), import('../src/pages/FactorNumberPage'),
    import('../src/pages/EfaPage'), import('../src/pages/CfaPage'),
    import('../src/pages/InvariancePage'), import('../src/pages/SimulationPage'),
    import('../src/pages/ReportPage'), import('../src/pages/ReliabilityPage'),
  ]);
}

export async function renderApp(path = '/', opts: { lng?: Language; theme?: ThemeName } = {}) {
  await preparePages();
  const i18n = await initI18n(opts.lng ?? 'tr');
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  const utils = render(
    <I18nextProvider i18n={i18n}>
      <ThemeProvider initial={opts.theme ?? 'dark'}>
        <QueryClientProvider client={client}>
          <DatasetProvider>
            <ReportProvider>
            <MemoryRouter initialEntries={[path]}>
              <App />
            </MemoryRouter>
            </ReportProvider>
            </DatasetProvider>
        </QueryClientProvider>
      </ThemeProvider>
    </I18nextProvider>,
  );
  return { ...utils, i18n };
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
