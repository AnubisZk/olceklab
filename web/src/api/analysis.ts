import { config } from '../config';
import { request } from './client';
import type {
  AnalysisRecord, CfaSettings, CleanResults, CleanRules, CompareSettings, DatasetOverview, EfaResults, EfaSettings,
  FactorNumberResults, FactorNumberSettings, ModelPreview, ModelSpec, ReliabilitySettings, RolesBody,
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
