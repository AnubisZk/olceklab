import Fastify, { type FastifyInstance } from 'fastify';
import type { GatewayConfig } from './config.js';
import { GatewayError } from './errors.js';
import { createProvider } from './providers/index.js';
import type { InterpretRequest } from './providers/types.js';

export function buildApp(config: GatewayConfig): FastifyInstance {
  const app = Fastify({ logger: false, bodyLimit: config.bodyLimit, trustProxy: (_address, hop) => hop < config.trustProxyHops,
    ajv: { customOptions: { removeAdditional: false } } });
  const provider = createProvider(config);
  const limits = new Map<string, { count: number; expires: number }>();

  // CORS: yalnızca izin verilen ön yüz kaynakları (SPEC §10).
  app.addHook('onRequest', async (req, reply) => {
    const origin = req.headers.origin;
    if (origin && !config.allowedOrigins.includes(origin)) throw new GatewayError('origin_not_allowed', 'Bu kaynaktan gelen isteğe izin verilmiyor.', 403);
    if (origin && config.allowedOrigins.includes(origin)) {
      reply.header('Access-Control-Allow-Origin', origin);
      reply.header('Vary', 'Origin');
      reply.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      reply.header('Access-Control-Allow-Headers', 'Content-Type');
    }
    if (req.method === 'OPTIONS') {
      return reply.code(204).send();
    }
    if (req.method === 'POST' && req.url.split('?')[0] === '/v1/interpret') {
      const now = Date.now();
      for (const [ip, bucket] of limits) if (bucket.expires <= now) limits.delete(ip);
      const bucket = limits.get(req.ip) ?? { count: 0, expires: now + 60000 };
      if (bucket.count >= config.rateLimit || (!limits.has(req.ip) && limits.size >= 10000)) {
        reply.header('Retry-After', '60');
        throw new GatewayError('rate_limit', 'İstek sınırı aşıldı; daha sonra yeniden deneyin.', 429);
      }
      bucket.count++; limits.set(req.ip, bucket);
    }
  });

  app.get('/health', async () => ({ status: 'ok', service: 'ai-gateway', provider: provider.name,
    model: config.provider === 'none' ? null : config[config.provider].model }));

  const rows = { type: 'array', maxItems: 2000, items: { type: 'object', maxProperties: 100,
    additionalProperties: { type: 'string', maxLength: 256 } } };
  app.post<{ Body: InterpretRequest }>('/v1/interpret', { schema: { body: {
    type: 'object', additionalProperties: false, required: ['record_id', 'module', 'language', 'tables'],
    properties: {
      record_id: { type: 'string', minLength: 1, maxLength: 100, pattern: '^[a-zA-Z0-9_-]+$' },
      module: { enum: ['data_clean', 'item_analysis', 'suitability', 'factor_number', 'efa', 'cfa', 'cfa_compare', 'reliability', 'invariance', 'invariance_scores', 'simulation'] },
      language: { enum: ['tr', 'en'] },
      tables: { type: 'array', minItems: 1, maxItems: 30, items: { type: 'object', additionalProperties: false, required: ['id', 'rows_fmt'],
        properties: { id: { type: 'string', pattern: '^T[0-9]+$' }, rows_fmt: { type: 'object', additionalProperties: false, required: ['tr', 'en'], properties: { tr: rows, en: rows } } } } },
    },
  } } }, async (req) => provider.interpret(req.body));

  app.setNotFoundHandler(async (req, reply) =>
    reply.code(404).send(new GatewayError('not_found', 'İstenen uç nokta bulunamadı.', 404, `${req.method} ${req.url}`).toBody()),
  );

  app.setErrorHandler(async (err, _req, reply) => {
    if (err instanceof GatewayError) return reply.code(err.statusCode).send(err.toBody());
    if (err && typeof err === 'object' && 'statusCode' in err && [400, 413].includes(Number(err.statusCode))) {
      return reply.code(Number(err.statusCode)).send(new GatewayError('invalid_request', 'İstek biçimi veya boyutu geçersiz.', Number(err.statusCode)).toBody());
    }
    return reply
      .code(500)
      .send(new GatewayError('gateway_error', 'Yapay zekâ ağ geçidinde beklenmeyen bir hata oluştu.', 500).toBody());
  });

  return app;
}
