import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { I18nextProvider } from 'react-i18next';
// Yazı tipleri pakete gömülür; çevrimdışı modda dış istek yapılmaz (SPEC §10, SPEC_REVIEW ARCH-3).
import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/600.css';
import '@fontsource/jetbrains-mono/700.css';
import './styles.css';
import { App } from './App';
import { initI18n } from './i18n';
import { ThemeProvider, applyTheme, initialTheme } from './theme/ThemeContext';
import { DatasetProvider } from './state/DatasetContext';

const theme = initialTheme();
applyTheme(theme); // ilk boyamadan önce: tema yanıp sönmesin

const queryClient = new QueryClient({ defaultOptions: { queries: { refetchOnWindowFocus: false } } });

initI18n().then((i18n) => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <I18nextProvider i18n={i18n}>
        <ThemeProvider initial={theme}>
          <QueryClientProvider client={queryClient}>
            <DatasetProvider>
              <BrowserRouter>
                <App />
              </BrowserRouter>
            </DatasetProvider>
          </QueryClientProvider>
        </ThemeProvider>
      </I18nextProvider>
    </StrictMode>,
  );
});
