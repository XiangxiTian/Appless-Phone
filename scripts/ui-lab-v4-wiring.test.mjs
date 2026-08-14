import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function read(relativePath) {
  return fs.readFileSync(path.join(repoRoot, relativePath), 'utf8');
}

test('UI Lab defaults to legacy and exposes explicit shadow and visible modes', () => {
  const flags = read('entry/src/main/ets/pages/A2uiHome/lab/v4/UiLabV4FeatureFlags.ets');
  const shell = read('entry/src/main/ets/pages/A2uiHome/lab/UiAgentLabHtml.ets');
  assert.match(flags, /mode:\s*'ui_lab_legacy'/);
  assert.match(shell, /value="ui_lab_legacy">Legacy/);
  assert.match(shell, /value="ui_lab_v4_shadow">V4 Shadow/);
  assert.match(shell, /value="ui_lab_v4_visible">V4 Visible/);
  assert.match(shell, /bridge\(\{type:'setV4Mode',mode:runtimeMode\.value\}\)/);
});

test('UI Lab double-writes accepted host surfaces after the runtime generation gate', () => {
  const harness = read('entry/src/main/ets/pages/A2uiHome/lab/UiAgentLabHarness.ets');
  const page = read('entry/src/main/ets/pages/A2uiHome/UiAgentLab.ets');
  assert.match(harness, /if \(!this\.active \|\| generation !== this\.generation\) return false;/);
  assert.match(harness, /generation,\s*\n\s*surface: cloneSurface\(surface\)/);
  assert.match(page, /new UiLabV4ShadowMirror\(this\.v4Runtime\.surfaceController\)/);
  assert.match(page, /this\.v4Mirror\.apply\(surface, runId, epoch,/);
  assert.match(page, /comparison\.categories\.join\(','\)/);
  assert.match(page, /this\.v4Mode === 'ui_lab_v4_visible' \? comparison\.projected : surface/);
});

test('main UI remains free of the UI Lab v4 runtime', () => {
  const mainPage = read('entry/src/main/ets/pages/A2uiHome/Index.ets');
  const homeState = read('entry/src/main/ets/pages/A2uiHome/state/A2uiHomeState.ets');
  assert.doesNotMatch(mainPage, /UiLabV4|aiphone\/ui/);
  assert.doesNotMatch(homeState, /UiLabV4|UiRunCoordinator|UiSurfaceController/);
});
