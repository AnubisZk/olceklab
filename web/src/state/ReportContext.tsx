import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { AiResponse, ApprovedAiText } from '../api/ai';

// Rapora eklenen sonuçlar (M10). Yalnızca bellekte tutulur; analiz kimliği R motorundaki kayda işaret eder.
export interface ReportItem { analysis_id: string; module: string; created_at: string }

interface ReportContextValue {
  aiTexts: ApprovedAiText[];
  aiLog: AiResponse[];
  logAi: (entry: AiResponse) => void;
  approveAi: (entry: AiResponse, item: ReportItem) => void;
  removeAi: (id: string) => void;
  clearAiLog: () => void;
  items: ReportItem[];
  add: (item: ReportItem) => void;
  remove: (id: string) => void;
  move: (id: string, delta: -1 | 1) => void;
  has: (id: string) => boolean;
  clear: () => void;
}

const Ctx = createContext<ReportContextValue | null>(null);

export function ReportProvider({ children }: { children: ReactNode }) {
  const [aiTexts, setAiTexts] = useState<ApprovedAiText[]>([]);
  const [aiLog, setAiLog] = useState<AiResponse[]>([]);
  const logAi = useCallback((entry: AiResponse) => setAiLog(s => [...s, entry]), []);
  const clearAiLog = useCallback(() => setAiLog([]), []);
  const removeAi = useCallback((id: string) => setAiTexts(s => s.filter(x => x.record_id !== id)), []);
  const [items, setItems] = useState<ReportItem[]>([]);
  const add = useCallback((item: ReportItem) => setItems((s) => (s.some((x) => x.analysis_id === item.analysis_id) ? s : [...s, item])), []);
  const remove = useCallback((id: string) => { setItems(s => s.filter(x => x.analysis_id !== id)); removeAi(id); }, [removeAi]);
  const approveAi = useCallback((entry: AiResponse, item: ReportItem) => {
    if (!entry.check.passed || entry.check.issues.length || entry.record_id !== item.analysis_id) return;
    add(item);
    setAiTexts(s => [...s.filter(x => x.record_id !== entry.record_id), {
      record_id: entry.record_id, text: entry.text, check_passed: true, provider: entry.provider, model: entry.model,
    }]);
  }, [add]);
  const move = useCallback((id: string, delta: -1 | 1) => setItems((s) => {
    const i = s.findIndex((x) => x.analysis_id === id); const j = i + delta;
    if (i < 0 || j < 0 || j >= s.length) return s;
    const c = [...s]; [c[i], c[j]] = [c[j], c[i]]; return c;
  }), []);
  const clear = useCallback(() => { setItems([]); setAiTexts([]); }, []);
  const value = useMemo(() => ({ items, add, remove, move, clear, aiTexts, aiLog, logAi, approveAi, removeAi, clearAiLog,
    has: (id: string) => items.some(x => x.analysis_id === id) }), [items, add, remove, move, clear, aiTexts, aiLog, logAi, approveAi, removeAi, clearAiLog]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useReport(): ReportContextValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useReport, ReportProvider içinde kullanılmalıdır');
  return v;
}
