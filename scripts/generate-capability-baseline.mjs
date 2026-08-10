#!/usr/bin/env node

import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync
} from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const sourcePath = resolve(
  repoRoot,
  'agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets'
);
const fixtureDir = resolve(repoRoot, 'docs/tool-framework/fixtures/capability-runtime-v3');
const toolFixturePath = resolve(fixtureDir, 'tool-specs.json');
const actionFixturePath = resolve(fixtureDir, 'action-links.json');
const fixtureFormat = 'appless.capability.baseline.v1';

function stripComments(source) {
  return source.replace(/\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g, '');
}

function blockBody(source, bodyStart) {
  if (bodyStart < 0) {
    return '';
  }
  let depth = 0;
  for (let index = bodyStart; index < source.length; index++) {
    const character = source.charAt(index);
    if (character === '{') {
      depth++;
    } else if (character === '}') {
      depth--;
      if (depth === 0) {
        return source.slice(bodyStart + 1, index);
      }
    }
  }
  return '';
}

function stringField(body, field) {
  const match = body.match(new RegExp(`\\b${field}\\s*:\\s*'([^']*)'`));
  if (match === null) {
    throw new Error(`Missing ${field} in ToolDefinition body.`);
  }
  return match[1];
}

function stringArrayField(body, field) {
  const match = body.match(new RegExp(`\\b${field}\\s*:\\s*\\[([\\s\\S]*?)\\]`));
  if (match === null) {
    throw new Error(`Missing ${field} in ToolDefinition body.`);
  }
  return [...match[1].matchAll(/'([^']*)'/g)].map((item) => item[1]);
}

function parseToolDefinitions(source) {
  const liveSource = stripComments(source);
  const definitions = [];
  for (const match of liveSource.matchAll(/\btoolId\s*:\s*'([^']+)'/g)) {
    const toolId = match[1];
    const objectStart = liveSource.lastIndexOf('{', match.index);
    const body = blockBody(liveSource, objectStart);
    if (body.length === 0) {
      throw new Error(`Cannot parse ToolDefinition body for ${toolId}.`);
    }
    definitions.push({
      toolId,
      domain: stringField(body, 'domain'),
      intent: stringField(body, 'intent'),
      riskLevel: stringField(body, 'riskLevel'),
      backendPriority: stringArrayField(body, 'backendPriority'),
      authModes: stringArrayField(body, 'authModes'),
      inputSchema: stringField(body, 'inputSchema'),
      outputSchema: stringField(body, 'outputSchema'),
      a2uiComponent: stringField(body, 'a2uiComponent'),
      actions: stringArrayField(body, 'actions')
    });
  }
  if (definitions.length === 0) {
    throw new Error('No ToolDefinition entries found.');
  }
  const ids = definitions.map((definition) => definition.toolId);
  if (new Set(ids).size !== ids.length) {
    throw new Error('Duplicate ToolDefinition IDs found.');
  }
  return definitions;
}

function buildFixtures() {
  const definitions = parseToolDefinitions(readFileSync(sourcePath, 'utf8'));
  const tools = definitions.map((definition) => ({
    toolId: definition.toolId,
    domain: definition.domain,
    intent: definition.intent,
    riskLevel: definition.riskLevel,
    backendPriority: definition.backendPriority,
    authModes: definition.authModes,
    inputSchema: definition.inputSchema,
    outputSchema: definition.outputSchema,
    a2uiComponent: definition.a2uiComponent
  }));
  const actionLinks = [];
  definitions.forEach((definition) => {
    definition.actions.forEach((targetToolId) => {
      actionLinks.push({
        sourceToolId: definition.toolId,
        targetToolId
      });
    });
  });
  return {
    tools: {
      fixtureFormat,
      baseline: 'origin/multiagent-backend@f93a56927dfae13d437909166cb87eae1e60d48c',
      source: 'agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets',
      toolCount: tools.length,
      tools
    },
    links: {
      fixtureFormat,
      baseline: 'origin/multiagent-backend@f93a56927dfae13d437909166cb87eae1e60d48c',
      source: 'agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets',
      linkCount: actionLinks.length,
      links: actionLinks
    }
  };
}

function serialized(value) {
  return JSON.stringify(value, null, 2) + '\n';
}

function writeOrCheck(path, content, checkOnly) {
  if (checkOnly) {
    if (!existsSync(path) || readFileSync(path, 'utf8') !== content) {
      throw new Error(`Fixture is stale: ${path}`);
    }
    return;
  }
  mkdirSync(fixtureDir, { recursive: true });
  writeFileSync(path, content);
}

const checkOnly = process.argv.includes('--check');
const fixtures = buildFixtures();
writeOrCheck(toolFixturePath, serialized(fixtures.tools), checkOnly);
writeOrCheck(actionFixturePath, serialized(fixtures.links), checkOnly);
console.log(`${checkOnly ? 'CHECKED' : 'WROTE'} ${fixtures.tools.toolCount} Tool definitions and ${fixtures.links.linkCount} ActionLinks.`);
