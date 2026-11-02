import { useTranslation } from 'react-i18next';
import { useTheme } from '../theme/ThemeContext';
import { LANGUAGES, type Language } from '../i18n';

export function LanguageSwitch() {
  const { t, i18n } = useTranslation();
  return (
    <div className="segmented" role="group" aria-label={t('language.label')}>
      {LANGUAGES.map((lng: Language) => (
        <button
          key={lng}
          type="button"
          lang={lng}
          aria-pressed={i18n.language === lng}
          onClick={() => void i18n.changeLanguage(lng)}
        >
          {lng.toUpperCase()}
        </button>
      ))}
    </div>
  );
}

export function ThemeToggle() {
  const { t } = useTranslation();
  const { theme, toggleTheme } = useTheme();
  const next = theme === 'dark' ? 'light' : 'dark';
  return (
    <button type="button" className="btn btn-ghost" onClick={toggleTheme} aria-label={t('theme.toggle')} data-theme-current={theme}>
      <span aria-hidden="true">{theme === 'dark' ? '◐' : '◑'}</span> {t(`theme.${next}`)}
    </button>
  );
}
