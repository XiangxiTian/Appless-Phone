#!/usr/bin/env node

import { readdirSync, readFileSync } from 'node:fs';
import { dirname, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const capabilityRoot = resolve(repoRoot, 'agent_core/src/main/ets/capability');
const capabilityPrefix = capabilityRoot + sep;
const checks = [];

function pass(name) {
  checks.push({ name, ok: true });
  console.log(`PASS ${name}`);
}

function fail(name, detail) {
  checks.push({ name, ok: false });
  console.error(`FAIL ${name}`);
  if (detail) {
    console.error(`     ${detail}`);
  }
}

function assert(condition, name, detail = '') {
  if (condition) {
    pass(name);
  } else {
    fail(name, detail);
  }
}

function visit(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = resolve(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...visit(path));
    } else if (entry.isFile() && entry.name.endsWith('.ets')) {
      files.push(path);
    }
  }
  return files;
}

function imports(source) {
  const result = [];
  const pattern = /^\s*import[\s\S]*?\s+from\s+(['"])([^'"]+)\1\s*;?/gm;
  for (const match of source.matchAll(pattern)) {
    result.push({ statement: match[0], modulePath: match[2] });
  }
  return result;
}

function layerOf(path) {
  const relativePath = relative(capabilityRoot, path).split(sep);
  return relativePath[0];
}

function resolvedCapabilityLayer(filePath, modulePath) {
  if (!modulePath.startsWith('.')) {
    return null;
  }
  const resolvedPath = resolve(dirname(filePath), modulePath);
  if (!resolvedPath.startsWith(capabilityPrefix)) {
    return null;
  }
  return layerOf(resolvedPath);
}

const layerRules = {
  contracts: new Set(['contracts']),
  registry: new Set(['contracts', 'registry']),
  runtime: new Set(['contracts', 'policy', 'registry', 'runtime']),
  policy: new Set(['contracts', 'policy', 'registry']),
  backends: new Set(['backends', 'contracts', 'registry']),
  presentation: new Set(['contracts', 'presentation', 'registry']),
  observability: new Set(['contracts', 'observability']),
  discovery: new Set(['compatibility', 'contracts', 'discovery', 'registry']),
  domains: new Set(['aiphone', 'compatibility', 'contracts', 'domains', 'presentation', 'registry'])
};

const files = visit(capabilityRoot);
const violations = [];
files.forEach((filePath) => {
  const layer = layerOf(filePath);
  const allowedLayers = layerRules[layer];
  if (allowedLayers === undefined || layer === 'compatibility' || layer === 'bootstrap') {
    return;
  }
  imports(readFileSync(filePath, 'utf8')).forEach(({ modulePath }) => {
    const importedLayer = resolvedCapabilityLayer(filePath, modulePath);
    if (importedLayer !== null && !allowedLayers.has(importedLayer)) {
      violations.push(`${relative(repoRoot, filePath)} -> ${modulePath}`);
    }
    const transitionalLegacyImport =
      (layer === 'discovery' || layer === 'domains') && modulePath.includes('/aiphone/');
    if (importedLayer === null && modulePath.startsWith('.') && !transitionalLegacyImport) {
      violations.push(`${relative(repoRoot, filePath)} -> ${modulePath} (outside capability)`);
    }
  });
});

assert(
  violations.length === 0,
  'capability layer imports stay within their declared dependency direction',
  violations.join('; ')
);

const compatibilityPaths = files
  .filter((filePath) => layerOf(filePath) === 'compatibility')
  .map((filePath) => relative(repoRoot, filePath));
const legacyImportsOutsideCompatibility = [];
files.forEach((filePath) => {
  if (layerOf(filePath) === 'compatibility') {
    return;
  }
  imports(readFileSync(filePath, 'utf8')).forEach(({ modulePath }) => {
    if (modulePath.includes('/aiphone/') || modulePath.includes('/agent/')) {
      const layer = layerOf(filePath);
      const transitional = layer === 'bootstrap' || layer === 'domains' || layer === 'discovery';
      if (!transitional) {
        legacyImportsOutsideCompatibility.push(`${relative(repoRoot, filePath)} -> ${modulePath}`);
      }
    }
  });
});
assert(
  legacyImportsOutsideCompatibility.length === 0,
  'legacy imports are isolated to compatibility and explicit migration seams',
  legacyImportsOutsideCompatibility.join('; ')
);

const productionFiles = [
  ...visit(resolve(repoRoot, 'agent_core/src/main/ets')).filter((path) => !path.startsWith(capabilityPrefix)),
  ...visit(resolve(repoRoot, 'entry/src/main/ets'))
];
const productionCapabilityImports = [];
productionFiles.forEach((filePath) => {
  imports(readFileSync(filePath, 'utf8')).forEach(({ modulePath }) => {
    if (modulePath.includes('/capability/') || modulePath.endsWith('/capability')) {
      productionCapabilityImports.push(`${relative(repoRoot, filePath)} -> ${modulePath}`);
    }
  });
});
assert(
  productionCapabilityImports.length === 0,
  'production entry points remain isolated from the new Capability Runtime',
  productionCapabilityImports.join('; ')
);

const forbiddenProviderImports = [];
visit(resolve(repoRoot, 'entry/src/main/ets')).forEach((filePath) => {
  imports(readFileSync(filePath, 'utf8')).forEach(({ modulePath }) => {
    if (modulePath.includes('/capability/') && modulePath.includes('/providers/')) {
      forbiddenProviderImports.push(`${relative(repoRoot, filePath)} -> ${modulePath}`);
    }
  });
});
assert(
  forbiddenProviderImports.length === 0,
  'entry pages do not import Capability Provider implementations',
  forbiddenProviderImports.join('; ')
);

console.log(`Checked ${files.length} capability modules (${compatibilityPaths.length} compatibility facades).`);
process.exitCode = checks.some((check) => !check.ok) ? 1 : 0;
