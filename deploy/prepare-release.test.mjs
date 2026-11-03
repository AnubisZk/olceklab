import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
test('Space paketi kök düzenini, kaynak baytlarını ve sentetik fikstürleri korur', () => {
  const temp = mkdtempSync(join(tmpdir(), 'olceklab-release-'));
  try {
    const output = join(temp, 'release');
    execFileSync(process.execPath, [join(root, 'deploy/prepare-release.mjs'), '--engine-only', '--output', output]);
    const manifest = JSON.parse(readFileSync(join(output, 'manifest.json'), 'utf8'));
    for (const file of ['Dockerfile', 'README.md', '.dockerignore', 'renv.lock', 'R/cors.R', 'tests/testthat.R',
      'tests/testthat/fixtures/bidekcet_synthetic/ortaokul_sentetik.xlsx']) {
      assert.ok(manifest.files[`hf-space/${file}`], file);
    }
    for (const [file, hash] of Object.entries(manifest.files)) {
      assert.equal(createHash('sha256').update(readFileSync(join(output, file))).digest('hex'), hash);
      assert.doesNotMatch(file, /(?:^|\/)(?:\.git|\.env|node_modules|data)(?:\/|$)|bidekcet_sonuc\.csv/);
    }
    assert.deepEqual(readFileSync(join(output, 'hf-space/Dockerfile')), readFileSync(join(root, 'deploy/hf-space/Dockerfile')));
    assert.throws(() => execFileSync(process.execPath,
      [join(root, 'deploy/prepare-release.mjs'), '--engine-only', '--output', output], { stdio: 'pipe' }), /Çıktı zaten var/);
  } finally {
    assert.equal(dirname(resolve(temp)), resolve(tmpdir()));
    rmSync(temp, { recursive: true, force: true });
  }
});

test('yerel ve HF Dockerfile yalnızca çevrim içi ayarlar bakımından farklıdır', () => {
  const local = readFileSync(join(root, 'engine/Dockerfile'), 'utf8').replaceAll('\r\n', '\n');
  const hf = readFileSync(join(root, 'deploy/hf-space/Dockerfile'), 'utf8').replaceAll('\r\n', '\n');
  assert.equal(hf.replace(/# --- Hugging Face Space[^]*?(?=EXPOSE)/, ''), local);
});
