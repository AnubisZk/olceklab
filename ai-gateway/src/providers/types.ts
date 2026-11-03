import type { ProviderName } from '../config.js';
import type { NumberCheck } from '../numberCheck.js';

export interface InterpretRequest {
  module: string;
  record_id: string;
  tables: { id: string; rows_fmt: { tr: Record<string, string>[]; en: Record<string, string>[] } }[];
  language: 'tr' | 'en';
}

export interface InterpretResponse {
  text: string;
  label: string;
  record_id: string;
  language: 'tr' | 'en';
  check: NumberCheck;
  provider: ProviderName;
  model: string;
  timestamp: string;
  prompt: string;
  response: string;
}

export interface AiProvider {
  readonly name: ProviderName;
  interpret(req: InterpretRequest): Promise<InterpretResponse>;
}
