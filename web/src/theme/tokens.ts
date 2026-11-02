// ARES-1 tasarım dili (SPEC §4). Koyu tema şartnamedeki renkleri aynen kullanır.
// Açık temada vurgular koyulaştırılmıştır; çünkü #00E5FF ve #FFB300 beyaz zeminde
// 4.5:1 kontrastı sağlamaz (SPEC_REVIEW ARCH-4, review/verify/V07).

export type ThemeName = 'dark' | 'light';

export interface Palette {
  bg: string;
  surface: string;
  surfaceRaised: string;
  border: string;
  text: string;
  textMuted: string;
  accent: string;
  onAccent: string;
  accent2: string;
  danger: string;
  success: string;
}

export const palettes: Record<ThemeName, Palette> = {
  dark: {
    bg: '#070B10',
    surface: '#0D141C',
    surfaceRaised: '#131D28',
    border: '#243242',
    text: '#E6EDF3',
    textMuted: '#9AA8B6',
    accent: '#00E5FF',
    onAccent: '#070B10',
    accent2: '#FFB300',
    danger: '#FF7A7A',
    success: '#3DDC97',
  },
  light: {
    bg: '#F4F7FA',
    surface: '#FFFFFF',
    surfaceRaised: '#FFFFFF',
    border: '#CBD5DF',
    text: '#0B1620',
    textMuted: '#4A5A6A',
    accent: '#00707F',
    onAccent: '#FFFFFF',
    accent2: '#8A5A00',
    danger: '#B42318',
    success: '#067647',
  },
};

// Gövde yazı tipi tek değişkenden değiştirilebilir (SPEC_REVIEW ARCH-5).
export const fonts = {
  mono: '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
  body: '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace',
};

// Kontrast testi bu çiftleri denetler: [ön plan, arka plan, açıklama].
export const contrastPairs: Array<[keyof Palette, keyof Palette, string]> = [
  ['text', 'bg', 'gövde metni / zemin'],
  ['text', 'surface', 'gövde metni / yüzey'],
  ['text', 'surfaceRaised', 'gövde metni / kart'],
  ['textMuted', 'bg', 'ikincil metin / zemin'],
  ['textMuted', 'surface', 'ikincil metin / yüzey'],
  ['accent', 'bg', 'vurgu / zemin'],
  ['accent', 'surface', 'vurgu / yüzey'],
  ['accent2', 'bg', 'ikinci vurgu / zemin'],
  ['accent2', 'surface', 'ikinci vurgu / yüzey'],
  ['onAccent', 'accent', 'düğme metni / vurgu'],
  ['danger', 'surface', 'hata / yüzey'],
  ['success', 'surface', 'başarı / yüzey'],
];
