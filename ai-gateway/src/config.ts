// Yapılandırma yalnızca ortam değişkenlerinden okunur (.env). Belgelenmemiş
// EVREN alanları için varsayılan değer uydurulmaz (AGENTS kuralı 5, SPEC §14).

export const PROVIDERS = ['none', 'local', 'api', 'evren'] as const;
export type ProviderName = (typeof PROVIDERS)[number];

export interface GatewayConfig {
  provider: ProviderName;
  host: string;
  port: number;
  allowedOrigins: string[];
  rateLimit: number;
  maxOutputTokens: number;
  bodyLimit: number;
  timeoutMs: number;
  trustProxyHops: number;
  api: { baseUrl: string | null; apiKey: string | null; model: string | null };
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
function integer(env: Record<string, string | undefined>, key: string, fallback: number, min = 1, max = 1_000_000) {
  const n = Number(env[key] ?? fallback);
  if (!Number.isSafeInteger(n) || n < min || n > max) throw new ConfigError(`${key} geçerli bir sınır olmalıdır.`);
  return n;
}

export function loadConfig(env: Record<string, string | undefined> = process.env): GatewayConfig {
  const provider = (nonEmpty(env.AI_PROVIDER) ?? 'none') as ProviderName;
  if (!PROVIDERS.includes(provider)) {
    throw new ConfigError(`AI_PROVIDER geçersiz. Geçerli değerler: ${PROVIDERS.join(', ')}`);
  }

  const port = Number(nonEmpty(env.AI_GATEWAY_PORT) ?? '8787');
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new ConfigError('AI_GATEWAY_PORT geçersiz.');
  }

  const config: GatewayConfig = {
    provider,
    host: nonEmpty(env.AI_GATEWAY_HOST) ?? '0.0.0.0',
    port,
    rateLimit: integer(env, 'AI_RATE_LIMIT_PER_MINUTE', 10),
    maxOutputTokens: integer(env, 'AI_MAX_OUTPUT_TOKENS', 1000, 1, 16384),
    bodyLimit: integer(env, 'AI_BODY_LIMIT_BYTES', 500000, 1024, 2000000),
    timeoutMs: integer(env, 'AI_REQUEST_TIMEOUT_MS', 60000, 100, 120000),
    trustProxyHops: integer(env, 'AI_TRUST_PROXY_HOPS', 0, 0, 5),
    api: { baseUrl: nonEmpty(env.AI_API_BASE_URL), apiKey: nonEmpty(env.AI_API_KEY), model: nonEmpty(env.AI_API_MODEL) },
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
  if (provider === 'api') {
    const missing = ['AI_API_BASE_URL', 'AI_API_KEY', 'AI_API_MODEL'].filter(k => !nonEmpty(env[k]));
    if (missing.length) throw new ConfigError(`AI_PROVIDER=api için eksik değişkenler: ${missing.join(', ')}`);
  }
  const base = provider === 'api' ? config.api.baseUrl : provider === 'local' ? config.local.baseUrl : provider === 'evren' ? config.evren.baseUrl : null;
  if (base) {
    try {
      const url = new URL(base);
      if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) throw new Error();
    } catch { throw new ConfigError('Sağlayıcı temel adresi geçersiz.'); }
  }
  if (provider === 'evren') {
    const missing = (['EVREN_BASE_URL', 'EVREN_API_KEY', 'EVREN_MODEL'] as const).filter((k) => !nonEmpty(env[k]));
    if (missing.length) {
      throw new ConfigError(`AI_PROVIDER=evren için eksik değişkenler: ${missing.join(', ')} (SPEC §14, madde 1).`);
    }
  }
  return config;
}
