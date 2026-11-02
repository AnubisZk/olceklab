import { GatewayError } from '../errors.js';
import type { GatewayConfig } from '../config.js';
import type { AiProvider } from './types.js';

// Faz 6: OpenAI uyumlu /v1/chat/completions istemcisi (Ollama / llama.cpp).
// Faz 0'da istek göndermez.
export function createLocalProvider(_config: GatewayConfig): AiProvider {
  return {
    name: 'local',
    async interpret() {
      throw new GatewayError('not_implemented', 'Yerel model sağlayıcısı Faz 6 kapsamında uygulanacak.', 501);
    },
  };
}
