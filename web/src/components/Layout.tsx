import type { ReactNode } from 'react';
import { NavLink } from 'react-router';
import { useTranslation } from 'react-i18next';
import { pages } from '../routes';
import { LanguageSwitch, ThemeToggle } from './Controls';

export function Layout({ children }: { children: ReactNode }) {
  const { t } = useTranslation();
  return (
    <div className="app">
      <a className="skip-link" href="#main">{t('app.skipToContent')}</a>
      <header className="topbar">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">Ö/L</span>
          <span>
            <span className="brand-name">{t('app.name')}</span>
            <span className="brand-tagline">{t('app.tagline')}</span>
          </span>
        </div>
        <div className="topbar-controls">
          <LanguageSwitch />
          <ThemeToggle />
        </div>
      </header>
      <nav className="sidenav" aria-label={t('app.mainNav')}>
        <ol>
          {pages.map((p, i) => (
            <li key={p.key}>
              <NavLink to={p.path} end={p.path === '/'}>
                <span className="nav-index mono" aria-hidden="true">{String(i).padStart(2, '0')}</span>
                <span>{t(`nav.${p.key}`)}</span>
              </NavLink>
            </li>
          ))}
        </ol>
      </nav>
      <main id="main" className="content" tabIndex={-1}>
        {children}
      </main>
    </div>
  );
}
