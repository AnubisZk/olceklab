import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

// Rapora eklenen sonuçlar (M10). Yalnızca bellekte tutulur; analiz kimliği R motorundaki kayda işaret eder.
export interface ReportItem { analysis_id: string; module: string; created_at: string }

interface ReportContextValue {
  items: ReportItem[];
  add: (item: ReportItem) => void;
  remove: (id: string) => void;
  move: (id: string, delta: -1 | 1) => void;
  has: (id: string) => boolean;
  clear: () => void;
}

const Ctx = createContext<ReportContextValue | null>(null);

export function ReportProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ReportItem[]>([]);
  const add = useCallback((item: ReportItem) => setItems((s) => (s.some((x) => x.analysis_id === item.analysis_id) ? s : [...s, item])), []);
  const remove = useCallback((id: string) => setItems((s) => s.filter((x) => x.analysis_id !== id)), []);
  const move = useCallback((id: string, delta: -1 | 1) => setItems((s) => {
    const i = s.findIndex((x) => x.analysis_id === id); const j = i + delta;
    if (i < 0 || j < 0 || j >= s.length) return s;
    const c = [...s]; [c[i], c[j]] = [c[j], c[i]]; return c;
  }), []);
  const clear = useCallback(() => setItems([]), []);
  const value = useMemo(() => ({ items, add, remove, move, clear, has: (id: string) => items.some((x) => x.analysis_id === id) }), [items, add, remove, move, clear]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useReport(): ReportContextValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useReport, ReportProvider içinde kullanılmalıdır');
  return v;
}
