import { createOpenAICompatible } from './openaiCompatible.js';
import type { GatewayConfig } from '../config.js';
import type { AiProvider } from './types.js';

export function createLocalProvider(config: GatewayConfig): AiProvider {
  return createOpenAICompatible(config, 'local');
}
