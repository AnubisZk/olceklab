import type { ProviderName } from '../config.js';

export interface InterpretRequest {
  module: string;
  results: unknown;
  tables: unknown;
  language: 'tr' | 'en';
}

export interface InterpretResponse {
  text: string;
  label: string;
}

export interface AiProvider {
  readonly name: ProviderName;
  interpret(req: InterpretRequest): Promise<InterpretResponse>;
}
