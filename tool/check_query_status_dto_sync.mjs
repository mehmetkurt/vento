#!/usr/bin/env node
/**
 * TD-W3-05 — Ensure the duplicated Status API / SPA DTO contract files stay
 * byte-identical. Docker builds use `context: .` per repo, so a parent npm
 * workspace package is forbidden; instead both repos keep a copy of:
 *
 *   src/contract/status-verify-dto.ts
 *
 * Exit 0 when identical; exit 1 with a clear diff hint otherwise.
 */
import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const REL = 'src/contract/status-verify-dto.ts';
const apiPath = join(root, 'vento_query_api', REL);
const spaPath = join(root, 'vento_query_spa', REL);

function fail(message) {
  console.error(`[check_query_status_dto_sync] FAIL: ${message}`);
  process.exit(1);
}

function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

for (const path of [apiPath, spaPath]) {
  if (!existsSync(path)) {
    fail(`missing file: ${relative(root, path)}`);
  }
}

const apiBytes = readFileSync(apiPath);
const spaBytes = readFileSync(spaPath);
const apiHash = sha256(apiBytes);
const spaHash = sha256(spaBytes);

if (apiHash !== spaHash) {
  console.error('[check_query_status_dto_sync] FAIL: DTO contract copies differ.');
  console.error(`  API: ${relative(root, apiPath)}`);
  console.error(`       sha256=${apiHash}  bytes=${apiBytes.length}`);
  console.error(`  SPA: ${relative(root, spaPath)}`);
  console.error(`       sha256=${spaHash}  bytes=${spaBytes.length}`);
  console.error(
    'Copy the canonical file into BOTH repos (or regenerate both) so they match byte-for-byte.',
  );
  process.exit(1);
}

console.log(
  `[check_query_status_dto_sync] OK: identical (${apiBytes.length} bytes, sha256=${apiHash})`,
);
process.exit(0);
