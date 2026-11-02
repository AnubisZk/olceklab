import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import tr from './locales/tr.json';
import en from './locales/en.json';
import { readPreference, writePreference } from '../storage';

export const LANGUAGES = ['tr', 'en'] as const;
export type Language = (typeof LANGUAGES)[number];
const STORAGE_KEY = 'olceklab.language';

function storedLanguage(): Language {
  const v = readPreference(STORAGE_KEY);
  return v === 'en' || v === 'tr' ? v : 'tr';
}

export function setDocumentLanguage(lng: string): void {
  // lang özniteliği, büyük harfe çevirmede Türkçe i/İ kuralının doğru uygulanması için gereklidir.
  if (typeof document !== 'undefined') document.documentElement.lang = lng;
}

export async function initI18n(lng: Language = storedLanguage()) {
  if (!i18n.isInitialized) {
    await i18n.use(initReactI18next).init({
      resources: { tr: { translation: tr }, en: { translation: en } },
      lng,
      fallbackLng: 'tr',
      supportedLngs: [...LANGUAGES],
      interpolation: { escapeValue: false },
      returnNull: false,
    });
    i18n.on('languageChanged', (l) => {
      setDocumentLanguage(l);
      writePreference(STORAGE_KEY, l);
    });
  } else if (i18n.language !== lng) {
    await i18n.changeLanguage(lng);
  }
  setDocumentLanguage(i18n.language);
  return i18n;
}

export { i18n };
