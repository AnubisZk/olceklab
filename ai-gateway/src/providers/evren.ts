import { createOpenAICompatible } from './openaiCompatible.js';
import type { GatewayConfig } from '../config.js';
import type { AiProvider } from './types.js';

// Kullanıcının 3 Kasım 2026 tarihli EVREN panel belgesi: chat/completions,
// X-API-Key. Kullanım şartlarını uygulama kullanıcı adına kabul etmez.
export function createEvrenProvider(config: GatewayConfig): AiProvider {
  return createOpenAICompatible(config, 'evren');
}
