import { buildApp } from './app.js';
import { loadConfig } from './config.js';

const config = loadConfig();
const app = buildApp(config);

app
  .listen({ host: config.host, port: config.port })
  .then((addr) => {
    console.log(`ai-gateway dinliyor: ${addr} (AI_PROVIDER=${config.provider})`);
  })
  .catch((err: unknown) => {
    console.error(err);
    process.exit(1);
  });
