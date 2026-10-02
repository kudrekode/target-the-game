import { build } from 'vite';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const directory = await mkdtemp(join(tmpdir(), 'target-tests-'));
try {
  await build({ configFile: false, logLevel: 'silent', build: {
    outDir: directory, minify: false,
    lib: { entry: resolve('tests/gameplay.test.ts'), formats: ['es'], fileName: () => 'gameplay.mjs' },
    rollupOptions: { external: ['node:assert/strict'] },
  } });
  await import(pathToFileURL(join(directory, 'gameplay.mjs')).href);
} finally { await rm(directory, { recursive: true, force: true }); }
