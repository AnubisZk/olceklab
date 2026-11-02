// SPEC §9 sayfa akışı. Faz numarası, sayfanın etkinleşeceği fazdır (SPEC §12).
// Yapay zekâ paneli (§9 madde 11) bir rota değil, sonuç sayfalarında yan paneldir (Faz 6).

export type PageKey =
  | 'start'
  | 'data'
  | 'items'
  | 'factorNumber'
  | 'efa'
  | 'cfa'
  | 'reliability'
  | 'invariance'
  | 'simulation'
  | 'report'
  | 'settings';

export interface PageDef {
  key: PageKey;
  path: string;
  phase: number;
}

export const pages: PageDef[] = [
  { key: 'start', path: '/', phase: 0 },
  { key: 'data', path: '/data', phase: 1 },
  { key: 'items', path: '/items', phase: 1 },
  { key: 'factorNumber', path: '/factor-number', phase: 1 },
  { key: 'efa', path: '/efa', phase: 2 },
  { key: 'cfa', path: '/cfa', phase: 2 },
  { key: 'reliability', path: '/reliability', phase: 2 },
  { key: 'invariance', path: '/invariance', phase: 3 },
  { key: 'simulation', path: '/simulation', phase: 4 },
  { key: 'report', path: '/report', phase: 5 },
  { key: 'settings', path: '/settings', phase: 0 },
];
