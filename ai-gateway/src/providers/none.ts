import { GatewayError } from '../errors.js';
import type { AiProvider } from './types.js';

// Varsayılan sağlayıcı. Hiçbir dış istek yapmaz (SPEC M11 kabul: "none modunda hiçbir dış istek gitmez").
export const noneProvider: AiProvider = {
  name: 'none',
  async interpret() {
    throw new GatewayError('ai_disabled', 'Yapay zekâ yorum asistanı kapalı (AI_PROVIDER=none).', 503);
  },
};
