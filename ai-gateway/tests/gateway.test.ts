import { afterEach, describe, expect, it, vi } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { buildApp } from '../src/app.js';
import { ConfigError, loadConfig } from '../src/config.js';

afterEach(() => {
  vi.restoreAllMocks();
});

function noFetch() {
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async () => {
    throw new Error('Dış istek yapılmamalı');
  });
}

describe('yapılandırma', () => {
  it('varsayılan sağlayıcı none', () => {
    const c = loadConfig({});
    expect(c.provider).toBe('none');
    expect(c.port).toBe(8787);
    expect(c.local.baseUrl).toBe('http://localhost:11434/v1');
    expect(c.allowedOrigins).toEqual(['http://localhost:5173', 'http://127.0.0.1:5173']);
  });

  it('geçersiz sağlayıcı reddedilir', () => {
    expect(() => loadConfig({ AI_PROVIDER: 'openai' })).toThrow(ConfigError);
  });

  it('local için model adı zorunlu; uydurulmaz', () => {
    expect(() => loadConfig({ AI_PROVIDER: 'local' })).toThrow(/OLLAMA_MODEL/);
    expect(loadConfig({ AI_PROVIDER: 'local', OLLAMA_MODEL: 'test-model' }).local.model).toBe('test-model');
  });

  it('evren için belgelenmemiş değerlere varsayılan atanmaz', () => {
    expect(() => loadConfig({ AI_PROVIDER: 'evren' })).toThrow(/EVREN_BASE_URL, EVREN_API_KEY, EVREN_MODEL/);
    const c = loadConfig({});
    expect(c.evren).toEqual({ baseUrl: null, apiKey: null, model: null });
  });
});

describe('uç noktalar', () => {
  it('GET /health sağlayıcıyı bildirir', async () => {
    const fetchSpy = noFetch();
    const app = buildApp(loadConfig({}));
    const r = await app.inject({ method: 'GET', url: '/health' });
    expect(r.statusCode).toBe(200);
    expect(r.json()).toEqual({ status: 'ok', service: 'ai-gateway', provider: 'none' });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('none modunda yorum isteği 503 ai_disabled döner ve dış istek yapılmaz', async () => {
    const fetchSpy = noFetch();
    const app = buildApp(loadConfig({}));
    const r = await app.inject({
      method: 'POST', url: '/v1/interpret',
      payload: { module: 'cfa', results: { a: 1 }, tables: [], language: 'tr' },
    });
    expect(r.statusCode).toBe(503);
    expect(r.json().error.code).toBe('ai_disabled');
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it.each([
    ['local', { AI_PROVIDER: 'local', OLLAMA_MODEL: 'm' }],
    ['evren', { AI_PROVIDER: 'evren', EVREN_BASE_URL: 'https://example.invalid', EVREN_API_KEY: 'k', EVREN_MODEL: 'm' }],
  ])('%s sağlayıcısı Faz 0\'da 501 döner ve dış istek yapmaz', async (_name, env) => {
    const fetchSpy = noFetch();
    const app = buildApp(loadConfig(env));
    const r = await app.inject({ method: 'POST', url: '/v1/interpret', payload: { module: 'cfa', results: {}, tables: [], language: 'tr' } });
    expect(r.statusCode).toBe(501);
    expect(r.json().error.code).toBe('not_implemented');
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('bilinmeyen yol standart hata biçimiyle 404 döner', async () => {
    const app = buildApp(loadConfig({}));
    const r = await app.inject({ method: 'GET', url: '/yok' });
    expect(r.statusCode).toBe(404);
    expect(r.json()).toEqual({ error: { code: 'not_found', message_tr: 'İstenen uç nokta bulunamadı.', detail: 'GET /yok' } });
  });

  it('CORS yalnızca izin verilen kaynağa açık', async () => {
    const app = buildApp(loadConfig({ ALLOWED_ORIGINS: 'http://localhost:5173' }));
    const ok = await app.inject({ method: 'GET', url: '/health', headers: { origin: 'http://localhost:5173' } });
    expect(ok.headers['access-control-allow-origin']).toBe('http://localhost:5173');
    const bad = await app.inject({ method: 'GET', url: '/health', headers: { origin: 'http://evil.example' } });
    expect(bad.headers['access-control-allow-origin']).toBeUndefined();
    const pre = await app.inject({ method: 'OPTIONS', url: '/v1/interpret', headers: { origin: 'http://localhost:5173' } });
    expect(pre.statusCode).toBe(204);
  });
});

describe('kaynak kod denetimi', () => {
  it('Faz 0 sağlayıcıları ağ kütüphanesi içe aktarmaz ve fetch çağırmaz', () => {
    const dir = join(import.meta.dirname, '..', 'src', 'providers');
    for (const f of readdirSync(dir)) {
      const src = readFileSync(join(dir, f), 'utf8');
      expect(src, f).not.toMatch(/from ['"](node:)?(http|https|net|tls|undici)['"]/);
      expect(src, f).not.toMatch(/\bfetch\s*\(/);
    }
  });
});
