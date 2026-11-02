import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { AnalysisRecord, CleanResults, DatasetOverview, RolesBody } from '../api/types';

// Veri seti durumu yalnızca bellekte tutulur; tarayıcı deposuna yazılmaz (SPEC §10).
export type AnalysisKey = 'item' | 'suitability' | 'factorNumber';

interface DatasetState {
  overview: DatasetOverview | null;
  roles: RolesBody | null;
  clean: AnalysisRecord<CleanResults> | null;
  results: Partial<Record<AnalysisKey, AnalysisRecord>>;
}

interface DatasetContextValue extends DatasetState {
  setOverview: (o: DatasetOverview) => void;
  setRoles: (r: RolesBody) => void;
  setClean: (c: AnalysisRecord<CleanResults>) => void;
  setResult: (k: AnalysisKey, r: AnalysisRecord) => void;
  reset: () => void;
}

const empty: DatasetState = { overview: null, roles: null, clean: null, results: {} };
const Ctx = createContext<DatasetContextValue | null>(null);

export function DatasetProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<DatasetState>(empty);
  const setOverview = useCallback((overview: DatasetOverview) => setState({ ...empty, overview }), []);
  const setRoles = useCallback((roles: RolesBody) => setState((s) => ({ ...s, roles, clean: null, results: {} })), []);
  const setClean = useCallback((clean: AnalysisRecord<CleanResults>) => setState((s) => ({ ...s, clean, results: {} })), []);
  const setResult = useCallback(
    (k: AnalysisKey, r: AnalysisRecord) => setState((s) => ({ ...s, results: { ...s.results, [k]: r } })),
    [],
  );
  const reset = useCallback(() => setState(empty), []);
  const value = useMemo(
    () => ({ ...state, setOverview, setRoles, setClean, setResult, reset }),
    [state, setOverview, setRoles, setClean, setResult, reset],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useDataset(): DatasetContextValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useDataset, DatasetProvider içinde kullanılmalıdır');
  return v;
}
