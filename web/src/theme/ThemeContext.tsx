import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { fonts, palettes, type Palette, type ThemeName } from './tokens';
import { readPreference, writePreference } from '../storage';

const STORAGE_KEY = 'olceklab.theme';

const cssVarNames: Record<keyof Palette, string> = {
  bg: '--color-bg',
  surface: '--color-surface',
  surfaceRaised: '--color-surface-raised',
  border: '--color-border',
  text: '--color-text',
  textMuted: '--color-text-muted',
  accent: '--color-accent',
  onAccent: '--color-on-accent',
  accent2: '--color-accent-2',
  danger: '--color-danger',
  success: '--color-success',
};

export function initialTheme(): ThemeName {
  const stored = readPreference(STORAGE_KEY);
  if (stored === 'dark' || stored === 'light') return stored;
  const prefersLight =
    typeof window !== 'undefined' &&
    typeof window.matchMedia === 'function' &&
    window.matchMedia('(prefers-color-scheme: light)').matches;
  return prefersLight ? 'light' : 'dark';
}

export function applyTheme(theme: ThemeName, root: HTMLElement = document.documentElement): void {
  const palette = palettes[theme];
  for (const key of Object.keys(cssVarNames) as Array<keyof Palette>) {
    root.style.setProperty(cssVarNames[key], palette[key]);
  }
  root.style.setProperty('--font-mono', fonts.mono);
  root.style.setProperty('--font-body', fonts.body);
  root.dataset.theme = theme;
  root.style.colorScheme = theme;
}

interface ThemeContextValue {
  theme: ThemeName;
  setTheme: (t: ThemeName) => void;
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

export function ThemeProvider({ children, initial }: { children: ReactNode; initial?: ThemeName }) {
  const [theme, setThemeState] = useState<ThemeName>(() => initial ?? initialTheme());

  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  const setTheme = useCallback((t: ThemeName) => {
    setThemeState(t);
    writePreference(STORAGE_KEY, t);
  }, []);

  const toggleTheme = useCallback(() => {
    setTheme(theme === 'dark' ? 'light' : 'dark');
  }, [theme, setTheme]);

  const value = useMemo(() => ({ theme, setTheme, toggleTheme }), [theme, setTheme, toggleTheme]);
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme, ThemeProvider içinde kullanılmalıdır');
  return ctx;
}
