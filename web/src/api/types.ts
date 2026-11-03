// R motorunun yanıt yapıları (SPEC §6.2). Ön yüz bu sayıları yalnızca gösterir.

export type Lang = 'tr' | 'en';
export type Role = 'item' | 'group' | 'id' | 'ignore';

export interface RColumn {
  key: string;
  label_tr: string;
  label_en: string;
  type: 'text' | 'number';
}

export interface RTable {
  id: string;
  title_tr: string;
  title_en: string;
  columns: RColumn[];
  rows: Record<string, unknown>[];
  rows_fmt: Record<Lang, Record<string, string>[]>;
  note_tr?: string | null;
  note_en?: string | null;
}

export interface RWarning {
  code: string;
  message_tr: string;
  message_en: string;
}

export interface RFigure<D = Record<string, unknown>> {
  id: string;
  type: string;
  data: D;
}

export interface AnalysisRecord<R = unknown> {
  analysis_id: string;
  module: string;
  dataset_hash: string;
  settings: Record<string, unknown>;
  seed?: number | null;
  rng?: { kind: string; normal_kind: string; sample_kind: string; mc_cores: number | null } | null;
  engine: { R: string; packages: Record<string, string>; blas?: string | null };
  results: R;
  tables: RTable[];
  figures: RFigure[];
  warnings: RWarning[];
  r_script?: string | null;
  created_at: string;
}

export interface ColumnSummary {
  name: string;
  type: 'number' | 'text';
  n_missing: number;
  n_unique: number;
  values: string[];
  min?: number | null;
  max?: number | null;
  integer_valued: boolean;
  suggested_role: Role;
}

export interface ItemSetting {
  min?: number | null;
  max?: number | null;
  reverse?: boolean;
  subscale?: string | null;
}

export interface DatasetOverview {
  dataset_id: string;
  dataset_hash: string;
  filename: string;
  source: { type: 'upload' | 'example'; name?: string; label?: string; delimiter?: string | null };
  n_rows: number;
  n_cols: number;
  columns: ColumnSummary[];
  preview: Record<string, unknown>[];
  identifier_suggestions: { column: string; reason: 'name' | 'tc_kimlik' | 'unique_text' }[];
  suggested_config?: { roles: Record<string, Role>; items: Record<string, ItemSetting> } | null;
}

export interface RolesBody {
  roles: Record<string, Role>;
  items: Record<string, ItemSetting>;
  group_valid_values?: string[];
}

export interface CleanRules {
  invalid_group: boolean;
  out_of_range: boolean;
  missing: boolean;
  straightline: boolean;
  reverse: boolean;
}

export interface CleanResults {
  n_raw: number;
  n_final: number;
  summary_tr: string;
  summary_en: string;
}

export interface FactorNumberSettings {
  extraction: 'pc' | 'fa' | 'both';
  correlation: 'pearson' | 'polychoric';
  reference: 'simulated_normal' | 'resampled_bootstrap' | 'permutation';
  n_iter: number;
  criterion: 'quantile' | 'mean';
  quant: number;
  fm: 'minres' | 'ml' | 'uls' | 'wls' | 'gls' | 'pa';
  seed: number;
}

export interface FactorNumberResults {
  decision_tr: string;
  decision_en: string;
  source: string;
}

export interface ScreeData {
  k: number[];
  pc_observed?: number[] | null;
  pc_reference?: number[] | null;
  fa_observed?: number[] | null;
  fa_reference?: number[] | null;
  criterion: 'quantile' | 'mean';
  labels: Record<Lang, Partial<Record<'pc_observed' | 'pc_reference' | 'fa_observed' | 'fa_reference', string[]>>>;
}

export interface HeatmapData {
  items: string[];
  categories: string[];
  proportions: (number | null)[][];
  counts: (number | null)[][];
  labels: Record<Lang, string[][]>;
}

// --- Faz 2: ölçme modeli, AFA, DFA, güvenirlik -----------------------------------

export interface FactorSpec { name: string; items: string[] }
export interface ModelSpec {
  factors?: FactorSpec[];
  covariances?: [string, string][];
  syntax?: string;
}
export interface ModelPreview {
  syntax: string;
  source: 'builder' | 'syntax';
  factors: FactorSpec[];
  covariances: [string, string][];
  observed: string[];
  warnings: RWarning[];
}

export type EfaFm = 'minres' | 'ml' | 'pa' | 'uls';
export type EfaRotate = 'oblimin' | 'promax' | 'geominQ' | 'varimax' | 'none';
export interface EfaSettings {
  nfactors: number;
  fm: EfaFm;
  rotate: EfaRotate;
  correlation: 'pearson' | 'polychoric';
  n_rotations: number;
  threshold: number;
  seed: number;
}
export interface EfaResults {
  n: number;
  items: string[];
  factors: string[];
  oblique: boolean;
  loadings: Record<string, number[]>;
  salient: Record<string, boolean[]>;
  sorted_items: string[];
  threshold_fmt: Record<Lang, string>;
}

export type Estimator = 'ML' | 'MLR' | 'WLSMV';
export interface CfaSettings {
  model: ModelSpec;
  estimator: Estimator;
  likelihood: 'normal' | 'wishart';
  std_lv: boolean;
  bootstrap: number;
  seed: number;
  mi_top: number;
}
export interface CompareSettings {
  models: { name: string; model: ModelSpec }[];
  estimator: Estimator;
  likelihood: 'normal' | 'wishart';
  std_lv: boolean;
  seed: number;
}
export interface ReliabilitySettings {
  model: ModelSpec;
  estimator: Estimator;
  obs_var: boolean;
  htmt: { htmt2: boolean; absolute: boolean; correlation: 'pearson' | 'polychoric' };
  thresholds: { cr: number; ave: number; htmt: number };
}

export interface PathLabel { label_tr: string; label_en: string; std: number | null }
export interface PathData {
  factors: { name: string; items: string[] }[];
  loadings: (PathLabel & { factor: string; item: string; r2_label_tr: string; r2_label_en: string })[];
  correlations: (PathLabel & { a: string; b: string })[];
  covariances: (PathLabel & { a: string; b: string })[];
}

// --- Faz 3: ölçme değişmezliği -----------------------------------------------------
export interface InvarianceSettings {
  model: ModelSpec;
  approach: 'continuous' | 'categorical';
  estimator: Estimator;
  likelihood: 'normal' | 'wishart';
  std_lv: boolean;
  include_strict: boolean;
  reference_group: string | null;
  srmr_type: 'bentler_nomean' | 'srmr';
  rule: 'none' | 'and' | 'or';
  d_sd: 'pooled' | 'reference';
  partial: string[];
  criteria: { cfi: number; rmsea: number; srmr_load: number; srmr_int: number; alpha: number };
  seed: number;
}
export interface InvarianceResults {
  groups: string[];
  steps: string[];
  decisions: { cfi_ok: boolean; rmsea_ok: boolean; srmr_ok: boolean; chisq_ok: boolean }[];
  latent_means_available: boolean;
}
export interface ScoreTestResults {
  step: string;
  tests: { parameter: string; groups: string; free: string; x2: number }[];
}

// --- Faz 4: simülasyon -------------------------------------------------------------
export interface JobText { progress: string; elapsed: string; eta: string }
export interface JobStatus {
  job_id: string;
  status: 'queued' | 'running' | 'cancelled' | 'done' | 'failed' | 'timeout';
  chunks_done: number; chunks_total: number; reps_done: number; reps_total: number; progress: number;
  error?: string | null;
  text: Record<Lang, JobText>;
}
export interface SimEstimate { estimated_seconds_upper: number; text: Record<Lang, string>; note_tr: string; note_en: string }
export interface PowerCurveData {
  series: { name: string; name_tr: string; name_en: string; scenario: string; estimator: string; step: string; ratio: string; N: number[]; rate: number[]; labels_tr: string[]; labels_en: string[] }[];
  Ns: number[]; target: number; alpha: number;
  y_ticks: number[]; y_labels_tr: string[]; y_labels_en: string[]; target_label_tr: string; target_label_en: string;
}
export interface BiasHeatmapData {
  estimator: string; params: string[]; conditions: string[];
  values: (number | null)[][]; labels_tr: string[][]; labels_en: string[][]; note_tr: string; note_en: string;
}

// --- Faz 5: rapor ve proje -----------------------------------------------------------
export interface TextSegment { text: string; italic: boolean }
export interface ReportPreviewItem {
  analysis_id: string; module: string; title: string;
  methods: TextSegment[][]; results: TextSegment[][]; limitations: TextSegment[][];
  tables: { id: string; number: number; title: string }[];
}
export interface ReportPreview { lang: Lang; items: ReportPreviewItem[]; references: string[]; note: string }
export interface VersionWarning { component: string; project: string; current: string; message_tr: string; message_en: string }
export interface ProjectSummary {
  project_id: string; created_at: string; format_version: number;
  dataset: { filename: string; hash: string; n_rows: number; n_cols: number; source_type: 'upload' | 'example'; example_name?: string | null; included: boolean; text_tr: string; text_en: string };
  needs_data: boolean;
  analyses: { order: number; module: string; analysis_id: string; title_tr: string; title_en: string }[];
  version_warnings: VersionWarning[];
}
export interface ProjectComparison {
  order: number; module: string; title_tr: string; title_en: string; old_analysis_id: string; new_analysis_id?: string;
  status: 'identical' | 'different' | 'error'; n_values?: number; n_numeric?: number; n_diff?: number; diffs?: string[];
  text_tr: string; text_en: string;
}
export interface ProjectReproduction {
  project_id: string; dataset: DatasetOverview; roles: RolesBody; clean: AnalysisRecord<CleanResults> | null; records: AnalysisRecord[];
  comparisons: ProjectComparison[]; all_identical: boolean; hash_ok: boolean; version_warnings: VersionWarning[];
}
