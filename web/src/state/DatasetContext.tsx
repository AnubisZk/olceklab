import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import type { AnalysisRecord, CleanResults, DatasetOverview, ModelSpec, RolesBody } from '../api/types';

// Veri seti durumu yalnızca bellekte tutulur; tarayıcı deposuna yazılmaz (SPEC §10).
export type AnalysisKey = 'item' | 'suitability' | 'factorNumber' | 'efa' | 'cfa' | 'cfaCompare' | 'reliability' | 'invariance' | 'invarianceScores';

// DFA ve güvenirlik aynı modeli paylaşır; karşılaştırma için kaydedilen modeller ayrıca tutulur.
export interface SavedModel { name: string; model: ModelSpec }

interface DatasetState {
  overview: DatasetOverview | null;
  roles: RolesBody | null;
  clean: AnalysisRecord<CleanResults> | null;
  results: Partial<Record<AnalysisKey, AnalysisRecord>>;
  model: ModelSpec | null;
  savedModels: SavedModel[];
}

interface DatasetContextValue extends DatasetState {
  setOverview: (o: DatasetOverview) => void;
  setRoles: (r: RolesBody) => void;
  setClean: (c: AnalysisRecord<CleanResults>) => void;
  setResult: (k: AnalysisKey, r: AnalysisRecord) => void;
  setModel: (m: ModelSpec) => void;
  setSavedModels: (m: SavedModel[]) => void;
  reset: () => void;
}

const empty: DatasetState = { overview: null, roles: null, clean: null, results: {}, model: null, savedModels: [] };
const Ctx = createContext<DatasetContextValue | null>(null);

export function DatasetProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<DatasetState>(empty);
  const setOverview = useCallback((overview: DatasetOverview) => setState({ ...empty, overview }), []);
  const setRoles = useCallback((roles: RolesBody) => setState((s) => ({ ...s, roles, clean: null, results: {}, model: null, savedModels: [] })), []);
  const setClean = useCallback((clean: AnalysisRecord<CleanResults>) => setState((s) => ({ ...s, clean, results: {} })), []);
  const setResult = useCallback(
    (k: AnalysisKey, r: AnalysisRecord) => setState((s) => ({ ...s, results: { ...s.results, [k]: r } })),
    [],
  );
  const setModel = useCallback((model: ModelSpec) => setState((s) => ({ ...s, model })), []);
  const setSavedModels = useCallback((savedModels: SavedModel[]) => setState((s) => ({ ...s, savedModels })), []);
  const reset = useCallback(() => setState(empty), []);
  const value = useMemo(
    () => ({ ...state, setOverview, setRoles, setClean, setResult, setModel, setSavedModels, reset }),
    [state, setOverview, setRoles, setClean, setResult, setModel, setSavedModels, reset],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useDataset(): DatasetContextValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useDataset, DatasetProvider içinde kullanılmalıdır');
  return v;
}
