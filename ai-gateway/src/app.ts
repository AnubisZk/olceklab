import Fastify, { type FastifyInstance } from 'fastify';
import type { GatewayConfig } from './config.js';
import { GatewayError } from './errors.js';
import { createProvider } from './providers/index.js';
import type { InterpretRequest } from './providers/types.js';

export function buildApp(config: GatewayConfig): FastifyInstance {
  const app = Fastify({ logger: false, bodyLimit: 1_000_000 });
  const provider = createProvider(config);

  // CORS: yalnızca izin verilen ön yüz kaynakları (SPEC §10).
  app.addHook('onRequest', async (req, reply) => {
    const origin = req.headers.origin;
    if (origin && config.allowedOrigins.includes(origin)) {
      reply.header('Access-Control-Allow-Origin', origin);
      reply.header('Vary', 'Origin');
      reply.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      reply.header('Access-Control-Allow-Headers', 'Content-Type');
    }
    if (req.method === 'OPTIONS') {
      return reply.code(204).send();
    }
  });

  app.get('/health', async () => ({ status: 'ok', service: 'ai-gateway', provider: provider.name }));

  app.post<{ Body: InterpretRequest }>('/v1/interpret', async (req) => provider.interpret(req.body));

  app.setNotFoundHandler(async (req, reply) =>
    reply.code(404).send(new GatewayError('not_found', 'İstenen uç nokta bulunamadı.', 404, `${req.method} ${req.url}`).toBody()),
  );

  app.setErrorHandler(async (err, _req, reply) => {
    if (err instanceof GatewayError) return reply.code(err.statusCode).send(err.toBody());
    return reply
      .code(500)
      .send(new GatewayError('gateway_error', 'Yapay zekâ ağ geçidinde beklenmeyen bir hata oluştu.', 500,
        err instanceof Error ? err.message : String(err)).toBody());
  });

  return app;
}
