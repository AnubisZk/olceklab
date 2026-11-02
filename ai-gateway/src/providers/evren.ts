import { GatewayError } from '../errors.js';
import type { GatewayConfig } from '../config.js';
import type { AiProvider } from './types.js';

// EVREN LLM API'sinin uç noktaları, kimlik doğrulama başlığı ve model adları
// belgelenmeden bağdaştırıcı yazılmaz (SPEC M11, §14 madde 1). Faz 6.
export function createEvrenProvider(_config: GatewayConfig): AiProvider {
  return {
    name: 'evren',
    async interpret() {
      throw new GatewayError(
        'not_implemented',
        'EVREN sağlayıcısı, API belgeleri sağlandıktan sonra Faz 6 kapsamında uygulanacak.',
        501,
      );
    },
  };
}
