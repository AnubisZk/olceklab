import { config } from '../config';
import { request } from './client';
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
