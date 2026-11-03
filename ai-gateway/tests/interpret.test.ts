import { readFileSync } from 'node:fs';
import Fastify from 'fastify';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import { checkNumbers, fillAndCheck } from '../src/numberCheck.js';
import { placeholders } from '../src/placeholders.js';
import type { InterpretRequest } from '../src/providers/types.js';

const record = JSON.parse(readFileSync(new URL('./fixtures/cfa.json', import.meta.url), 'utf8'));
const payload: InterpretRequest = { record_id: record.analysis_id, module: record.module, language: 'tr',
  tables: record.tables.map((t: InterpretRequest['tables'][number]) => ({ id: t.id, rows_fmt: t.rows_fmt })) };
const close: (() => Promise<unknown>)[] = [];
afterEach(async () => { await Promise.all(close.splice(0).map(fn => fn())); vi.restoreAllMocks(); });

async function setup(provider = 'api', reply = 'CFI = {{cfa.T1.cfi}}; kavramsal olarak uyumu açıklar.', extra: Record<string, string> = {}) {
  let seen: unknown; let auth: unknown;
  const upstream = Fastify();
  upstream.post('/v1/chat/completions', async (req, res) => {
    seen = req.body; auth = req.headers;
    if (reply === 'ERROR') return res.code(403).send({ error: 'test-secret-key' });
    return { choices: [{ finish_reason: 'stop', message: { content: reply } }] };
  });
  const url = await upstream.listen({ host: '127.0.0.1', port: 0 });
  close.push(() => upstream.close());
  const config = loadConfig({ AI_PROVIDER: provider, AI_API_BASE_URL: `${url}/v1`, AI_API_KEY: 'test-secret-key', AI_API_MODEL: 'test-model',
    OLLAMA_BASE_URL: `${url}/v1`, OLLAMA_MODEL: 'test-model', EVREN_BASE_URL: `${url}/v1`, EVREN_API_KEY: 'test-secret-key', EVREN_MODEL: 'test-model', ...extra });
  const app = buildApp(config); close.push(() => app.close());
  return { app, upstream, seen: () => seen as { messages: { content: string }[]; max_tokens: number }, auth: () => auth as Record<string, string> };
}

describe('sayı kökeni denetimi — gerçek R fikstürü', () => {
  it.each(['999,876', ',987654', '%5', '−%1,0', '[,071; ,114]', '−42', 'iki', 'yüzde elli', 'two', 'fifty percent', '1e9', '１２', '½', 'one hundred'])('uydurulmuş %s reddedilir', text => {
    expect(checkNumbers(text).passed).toBe(false);
    expect(fillAndCheck(`CFI {{cfa.T1.cfi}}. Ek sonuç: ${text}`, placeholders(payload)).check.passed).toBe(false);
  });
  it.each(['tr', 'en'] as const)('R hücreleri aynen doldurulur (%s), aynı sayının modelce kopyalanması reddedilir', language => {
    const p = { ...payload, language }; const map = placeholders(p);
    for (const [key, value] of map) {
      expect(fillAndCheck(`{{${key}}}`, map)).toEqual({ text: value, check: { passed: true, issues: [] } });
    }
    const value = map.get('cfa.T1.cfi')!;
    expect(fillAndCheck(`CFI ${value}`, map).check.passed).toBe(false);
  });
  it('bilinmeyen ve bozuk anahtarlar kapalı kalır; vurgulama ofseti doldurulmuş metne aittir', () => {
    const map = placeholders(payload);
    expect(fillAndCheck('{{absent}}', map).check.passed).toBe(false);
    expect(fillAndCheck('{{cfa.T1.cfi', map).check.passed).toBe(false);
    const r = fillAndCheck('{{cfa.T1.cfi}} ve 999', map);
    const i = r.check.issues[0]; expect(r.text.slice(i.start, i.end)).toBe('999');
  });
});

describe('yerel sahte OpenAI uyumlu sunucu', () => {
  it.each(['api', 'local', 'evren'])('%s gerçek HTTP akışı; anahtar ve ham veri isteme/loga girmez', async provider => {
    const s = await setup(provider);
    const response = await s.app.inject({ method: 'POST', url: '/v1/interpret', payload });
    expect(response.statusCode).toBe(200); const out = response.json();
    expect(out.check.passed).toBe(true);
    expect(out.text).toContain(placeholders(payload).get('cfa.T1.cfi'));
    expect(s.seen().max_tokens).toBe(1000);
    expect(out.prompt).toContain('{{cfa.T1.cfi}}');
    expect(out.prompt).not.toContain(record.analysis_id);
    expect(out.prompt).not.toContain(placeholders(payload).get('cfa.T1.cfi'));
    expect(JSON.stringify(out)).not.toContain('test-secret-key');
    expect(out).not.toHaveProperty('ip');
    if (provider === 'api') expect(s.auth().authorization).toBe('Bearer test-secret-key');
    if (provider === 'evren') expect(s.auth()['x-api-key']).toBe('test-secret-key');
    if (provider === 'local') { expect(s.auth().authorization).toBeUndefined(); expect(s.auth()['x-api-key']).toBeUndefined(); }
  });
  it('bozuk sayılar yanıt olarak gösterilir fakat onaylanamaz', async () => {
    const s = await setup('api', 'CFI {{cfa.T1.cfi}}, iki faktör ve %5.');
    const r = await s.app.inject({ method: 'POST', url: '/v1/interpret', payload });
    expect(r.json().check.passed).toBe(false); expect(r.json().check.issues).toHaveLength(2);
  });
  it('sağlayıcı hata gövdesi ve anahtarı sızmaz', async () => {
    const s = await setup('api', 'ERROR');
    const r = await s.app.inject({ method: 'POST', url: '/v1/interpret', payload });
    expect(r.statusCode).toBe(502); expect(r.body).not.toContain('test-secret-key');
    expect(r.json().error.detail).toBeNull();
  });
  it('sağlayıcı başarılı yanıtında anahtarı yansıtsa da silinir', async () => {
    const s = await setup('api', 'test-secret-key');
    const r = await s.app.inject({ method: 'POST', url: '/v1/interpret', payload });
    expect(r.body).not.toContain('test-secret-key');
  });
  it('IP sınırı, gövde sınırı, bilinmeyen alan ve CORS reddi', async () => {
    const s = await setup('api', undefined, { AI_RATE_LIMIT_PER_MINUTE: '1' });
    const first = await s.app.inject({ method: 'POST', url: '/v1/interpret', payload }); expect(first.statusCode).toBe(200);
    const limited = await s.app.inject({ method: 'POST', url: '/v1/interpret', headers: { 'x-forwarded-for': 'other' }, payload }); expect(limited.statusCode).toBe(429);
    const bad = await s.app.inject({ method: 'POST', url: '/v1/interpret', remoteAddress: '127.0.0.2', payload: { ...payload, raw_data: ['PRIVATE'] } }); expect(bad.statusCode).toBe(400);
    const cors = await s.app.inject({ method: 'POST', url: '/v1/interpret', headers: { origin: 'https://evil.example' }, payload }); expect(cors.statusCode).toBe(403);
    const big = await s.app.inject({ method: 'POST', url: '/v1/interpret', remoteAddress: '127.0.0.3', headers: { 'content-type': 'application/json' }, payload: JSON.stringify({ a: 'x'.repeat(500001) }) }); expect(big.statusCode).toBe(413);
  });
  it('eksik API ayarı başlatmayı engeller', () => {
    expect(() => loadConfig({ AI_PROVIDER: 'api' })).toThrow(/AI_API_BASE_URL, AI_API_KEY, AI_API_MODEL/);
    expect(() => loadConfig({ AI_RATE_LIMIT_PER_MINUTE: '0' })).toThrow();
  });
});
