import { config } from '../config';
import { request, requestBlob } from './client';
import type {
  AnalysisRecord, CfaSettings, CleanResults, CleanRules, CompareSettings, DatasetOverview, EfaResults, EfaSettings,
  FactorNumberResults, FactorNumberSettings, InvarianceResults, InvarianceSettings, ModelPreview, ModelSpec, ReliabilitySettings,
  RolesBody, ScoreTestResults,
} from './types';

const engine = config.engineUrl;

export async function uploadDataset(file: File): Promise<DatasetOverview> {
  const raw = await file.arrayBuffer();
  return request<DatasetOverview>(engine, '/datasets', { method: 'POST', raw, query: { filename: file.name } });
}

export const loadExample = (name: 'holzinger' | 'bfi') =>
  request<DatasetOverview>(engine, `/datasets/examples/${name}`, { method: 'POST' });

export const saveRoles = (id: string, body: RolesBody) =>
  request<unknown>(engine, `/datasets/${id}/roles`, { method: 'POST', json: body });

export const cleanDataset = (id: string, rules: CleanRules) =>
  request<AnalysisRecord<CleanResults>>(engine, `/datasets/${id}/clean`, { method: 'POST', json: { rules } });

export const runItemAnalysis = (id: string, settings: { r_drop_threshold: number }) =>
  request<AnalysisRecord>(engine, '/analyses/item', { method: 'POST', json: { dataset_id: id, settings } });

export const runSuitability = (id: string, settings: { correlation: 'pearson' | 'polychoric' }) =>
  request<AnalysisRecord>(engine, '/analyses/suitability', { method: 'POST', json: { dataset_id: id, settings } });

export const runFactorNumber = (id: string, settings: FactorNumberSettings) =>
  request<AnalysisRecord<FactorNumberResults>>(engine, '/analyses/factor-number', {
    method: 'POST', json: { dataset_id: id, settings },
  });

// --- Faz 2 -----------------------------------------------------------------------

const post = <T>(path: string, json: unknown) => request<T>(engine, path, { method: 'POST', json });

export const previewModel = (id: string, model?: ModelSpec) =>
  post<ModelPreview>('/models/preview', model ? { dataset_id: id, model } : { dataset_id: id });
export const runEfa = (id: string, settings: EfaSettings) =>
  post<AnalysisRecord<EfaResults>>('/analyses/efa', { dataset_id: id, settings });
export const runCfa = (id: string, settings: CfaSettings) =>
  post<AnalysisRecord>('/analyses/cfa', { dataset_id: id, settings });
export const runCfaCompare = (id: string, settings: CompareSettings) =>
  post<AnalysisRecord>('/analyses/cfa/compare', { dataset_id: id, settings });
export const runReliability = (id: string, settings: ReliabilitySettings) =>
  post<AnalysisRecord>('/analyses/reliability', { dataset_id: id, settings });
export const runInvariance = (id: string, settings: InvarianceSettings) =>
  post<AnalysisRecord<InvarianceResults>>('/analyses/invariance', { dataset_id: id, settings });
export const runInvarianceScores = (id: string, settings: InvarianceSettings & { step: string }) =>
  post<AnalysisRecord<ScoreTestResults>>('/analyses/invariance/score-tests', { dataset_id: id, settings });

// --- Faz 4: simülasyon ---------------------------------------------------------------
export const estimateSimulation = (body: unknown) => post<import('./types').SimEstimate>('/simulations/estimate', body);
export const startSimulation = (body: unknown) => post<import('./types').JobStatus>('/simulations', body);
export const getJob = (id: string) => request<import('./types').JobStatus>(engine, `/jobs/${id}`);
export const cancelJob = (id: string) => request<import('./types').JobStatus>(engine, `/jobs/${id}/cancel`, { method: 'POST' });
export const resumeJob = (id: string) => request<import('./types').JobStatus>(engine, `/jobs/${id}/resume`, { method: 'POST' });
export const getSimResults = (id: string) => request<AnalysisRecord>(engine, `/simulations/${id}/results`);
export const populationFromCfa = (analysisId: string, shift: number) =>
  post<{ population: Record<string, unknown>; notes_tr: string[]; notes_en: string[] }>('/simulations/population/from-cfa', { analysis_id: analysisId, shift });
export async function downloadSimPackage(id: string): Promise<Blob> {
  const res = await fetch(`${engine.replace(/\/$/, '')}/simulations/${id}/package`);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.blob();
}

// --- Faz 5: rapor (M10) ve proje dosyası (M12) ------------------------------------------
export const reportPreview = (analysisIds: string[], lang: 'tr' | 'en') =>
  post<import('./types').ReportPreview>('/reports/preview', { analysis_ids: analysisIds, lang });
export const reportDocx = (analysisIds: string[], lang: 'tr' | 'en', title: string) =>
  requestBlob(engine, '/reports/docx', { method: 'POST', json: { analysis_ids: analysisIds, lang, title } });
export const tableCsv = (analysisId: string, tableId: string, lang: 'tr' | 'en', values: 'formatted' | 'raw') =>
  requestBlob(engine, `/analyses/${analysisId}/tables/${tableId}/csv`, { query: { lang, values } });
export const exportProject = (body: { dataset_id: string; analysis_ids: string[]; include_data: boolean; data_consent: boolean }) =>
  requestBlob(engine, '/projects/export', { method: 'POST', json: body });
export async function importProject(file: File): Promise<import('./types').ProjectSummary> {
  return request(engine, '/projects/import', { method: 'POST', raw: await file.arrayBuffer() });
}
export const reproduceProject = (projectId: string, datasetId?: string) =>
  post<import('./types').ProjectReproduction>(`/projects/${projectId}/reproduce`, datasetId ? { dataset_id: datasetId } : {});
