// Node 24; Windows/Linux. Yalnızca sürüm kontrolündeki motor kaynaklarını paketler.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
let output = resolve(root, 'dist/release');
let engineOnly = false;
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--engine-only') engineOnly = true;
  else if (args[i] === '--output' && args[i + 1]) output = resolve(args[++i]);
  else throw new Error(`Bilinmeyen/eksik seçenek: ${args[i]}`);
}
if (existsSync(output)) throw new Error(`Çıktı zaten var; yeni bir --output dizini seçin: ${output}`);

const engineUrl = process.env.VITE_ENGINE_URL || 'https://osiriszk-olceklab-engine.hf.space';
const parsed = new URL(engineUrl);
if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.search || parsed.hash || parsed.pathname !== '/') {
  throw new Error('VITE_ENGINE_URL kimlik bilgisi içermeyen bir HTTPS kökeni olmalıdır.');
}
const tracked = execFileSync('git', ['ls-files', '-z', 'engine'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
const top = new Set(['.dockerignore', 'renv.lock', 'plumber.R', 'run.R', 'healthcheck.R']);
const files = tracked.filter((file) => {
  const path = file.slice('engine/'.length);
  return top.has(path) || (path.startsWith('R/') && path.endsWith('.R')) ||
    (path.startsWith('tests/') && /\.(R|md|py)$/.test(path)) ||
    /^tests\/testthat\/fixtures\/bidekcet_synthetic\/[^/]+\.xlsx$/.test(path);
});
for (const file of top) {
  if (!files.includes(`engine/${file}`)) throw new Error(`Eksik motor kaynağı: ${file}`);
}
if (!engineOnly) {
  execFileSync(process.execPath, [join(root, 'web/node_modules/vite/bin/vite.js'), 'build'], {
    cwd: join(root, 'web'), stdio: 'inherit',
    env: { ...process.env, VITE_ENGINE_URL: parsed.origin, VITE_DEPLOY_MODE: 'online', VITE_AI_GATEWAY_URL: '' },
  });
}
mkdirSync(join(output, 'hf-space'), { recursive: true });
for (const file of files) {
  const target = join(output, 'hf-space', file.slice('engine/'.length));
  mkdirSync(dirname(target), { recursive: true });
  cpSync(join(root, file), target);
}
for (const file of ['Dockerfile', 'README.md']) cpSync(join(root, 'deploy/hf-space', file), join(output, 'hf-space', file));
if (!engineOnly) {
  cpSync(join(root, 'web/dist'), join(output, 'netlify'), { recursive: true });
  for (const file of ['_headers', '_redirects', 'netlify.toml']) {
    cpSync(join(root, 'deploy/netlify', file), join(output, 'netlify', file));
  }
}
const hashes = {};
function digestTree(dir, prefix = '') {
  for (const entry of readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
    const relative = prefix + entry.name;
    if (entry.isDirectory()) digestTree(join(dir, entry.name), relative + '/');
    else hashes[relative] = createHash('sha256').update(readFileSync(join(dir, entry.name))).digest('hex');
  }
}
digestTree(output);
writeFileSync(join(output, 'manifest.json'), JSON.stringify({
  source_commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  source_dirty: Boolean(execFileSync('git', ['status', '--porcelain', '--untracked-files=no'], { cwd: root, encoding: 'utf8' }).trim()),
  node: process.version, engine_url: parsed.origin, ai_enabled: false,
  validation: 'Docker, R ve canlı test sonuçları ayrıca doğrulanmalıdır; paketleme kabul kanıtı değildir.',
  files: hashes,
}, null, 2) + '\n');
console.log(`Yayın dosyaları: ${output}`);
