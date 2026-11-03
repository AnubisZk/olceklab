import { config } from '../config';
import { getJson } from './client';

export interface HealthResponse {
  status: string;
  service: string;
  time: string;
}

export interface VersionsResponse {
  R: string;
  packages: Record<string, string>;
  missing: string[];
  platform: string;
  blas: string | null;
  lapack: string | null;
  rng_kind: { kind: string; normal_kind: string; sample_kind: string };
}

export interface GatewayHealthResponse {
  status: string;
  service: string;
  provider: 'none' | 'local' | 'api' | 'evren';
  model?: string | null;
}

export const fetchEngineHealth = (signal?: AbortSignal) =>
  getJson<HealthResponse>(config.engineUrl, '/health', signal);

export const fetchEngineVersions = (signal?: AbortSignal) =>
  getJson<VersionsResponse>(config.engineUrl, '/versions', signal);

export const fetchGatewayHealth = (signal?: AbortSignal) =>
  getJson<GatewayHealthResponse>(config.gatewayUrl, '/health', signal);
