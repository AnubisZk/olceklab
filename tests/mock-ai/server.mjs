// Test-only server. No external model calls or statistical computations.
import { createServer } from 'node:http';
const server = createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  if (req.method !== 'POST' || req.url !== '/v1/chat/completions') { res.writeHead(404).end('{}'); return; }
  let raw = ''; for await (const chunk of req) { raw += chunk; if (raw.length > 500000) { res.writeHead(413).end('{}'); return; } }
  const body = JSON.parse(raw);
  const key = '{{cfa.T1.cfi}}';
  if (!body.messages.some(message => message.content.includes(key))) { res.writeHead(422).end('{}'); return; }
  res.end(JSON.stringify({ choices: [{ finish_reason: 'stop', message: { content: `CFI = ${key}. Uyum ölçütleri kuramsal gerekçelerle birlikte değerlendirilmelidir.` } }] }));
});
server.listen(8790, '0.0.0.0');
