import { useTranslation } from 'react-i18next';
import type { Lang } from './api/types';

export function useLang(): Lang {
  const { i18n } = useTranslation();
  return i18n.language === 'en' ? 'en' : 'tr';
}

// R'den gelen iki dilli alanlardan geçerli dilde olanı seçer.
export function pick<T extends Record<string, unknown>>(obj: T, base: string, lang: Lang): string {
  const v = obj[`${base}_${lang}`];
  return typeof v === 'string' ? v : '';
}
