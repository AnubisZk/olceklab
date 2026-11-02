// Yapılandırma yalnızca ortam değişkenlerinden okunur (.env). Belgelenmemiş
// EVREN alanları için varsayılan değer uydurulmaz (AGENTS kuralı 5, SPEC §14).

export const PROVIDERS = ['none', 'local', 'evren'] as const;
export type ProviderName = (typeof PROVIDERS)[number];

export interface GatewayConfig {
  provider: ProviderName;
  host: string;
  port: number;
  allowedOrigins: string[];
  local: { baseUrl: string; model: string | null };
  evren: { baseUrl: string | null; apiKey: string | null; model: string | null };
}

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

const nonEmpty = (v: string | undefined): string | null => (v && v.trim() ? v.trim() : null);

export function loadConfig(env: Record<string, string | undefined> = process.env): GatewayConfig {
  const provider = (nonEmpty(env.AI_PROVIDER) ?? 'none') as ProviderName;
  if (!PROVIDERS.includes(provider)) {
    throw new ConfigError(`AI_PROVIDER geçersiz: "${env.AI_PROVIDER}". Geçerli değerler: ${PROVIDERS.join(', ')}`);
  }

  const port = Number(nonEmpty(env.AI_GATEWAY_PORT) ?? '8787');
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new ConfigError(`AI_GATEWAY_PORT geçersiz: "${env.AI_GATEWAY_PORT}"`);
  }

  const config: GatewayConfig = {
    provider,
    host: nonEmpty(env.AI_GATEWAY_HOST) ?? '0.0.0.0',
    port,
    allowedOrigins: (nonEmpty(env.ALLOWED_ORIGINS) ?? 'http://localhost:5173,http://127.0.0.1:5173').split(',').map((s) => s.trim()).filter(Boolean),
    local: {
      baseUrl: nonEmpty(env.OLLAMA_BASE_URL) ?? 'http://localhost:11434/v1',
      model: nonEmpty(env.OLLAMA_MODEL),
    },
    evren: {
      baseUrl: nonEmpty(env.EVREN_BASE_URL),
      apiKey: nonEmpty(env.EVREN_API_KEY),
      model: nonEmpty(env.EVREN_MODEL),
    },
  };

  if (provider === 'local' && !config.local.model) {
    throw new ConfigError('AI_PROVIDER=local için OLLAMA_MODEL tanımlanmalıdır (SPEC §14, madde 3).');
  }
  if (provider === 'evren') {
    const missing = (['EVREN_BASE_URL', 'EVREN_API_KEY', 'EVREN_MODEL'] as const).filter((k) => !nonEmpty(env[k]));
    if (missing.length) {
      throw new ConfigError(`AI_PROVIDER=evren için eksik değişkenler: ${missing.join(', ')} (SPEC §14, madde 1).`);
    }
  }
  return config;
}
