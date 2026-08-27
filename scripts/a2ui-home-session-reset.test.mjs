import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const indexSource = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url),
  'utf8'
);

function methodBody(name) {
  const signature = `private ${name}(): void {`;
  const start = indexSource.indexOf(signature);
  assert.notEqual(start, -1, `${name} must exist`);
  const bodyStart = start + signature.length;
  let depth = 1;
  for (let index = bodyStart; index < indexSource.length; index += 1) {
    if (indexSource[index] === '{') depth += 1;
    if (indexSource[index] === '}') depth -= 1;
    if (depth === 0) return indexSource.slice(bodyStart, index);
  }
  throw new Error(`${name} body is incomplete`);
}

test('clearing the current session removes an active DeepSearch surface', () => {
  const state = {
    showDeepSearch: true,
    deepSearchQuery: 'research query',
    deepSearchSettingsJson: '{"model":"test"}',
    deepSearchContextJson: '{"date":"today"}',
    disposeHotelRuntime() {},
    closeDeepSearch() {
      this.showDeepSearch = false;
      this.deepSearchQuery = '';
      this.deepSearchSettingsJson = '';
      this.deepSearchContextJson = '';
    },
    sessionContextCompactor: { reset() {} },
    interestSourceRequestSeq: { clear() {} },
    currentWaterfallPreferenceProfile() { return {}; },
    registeredPageSnapshotStore: { clear() {} },
    surfaceSnapshot(value) { return value; },
    syncFoodLocationOwner() {},
    clearLuckinInlinePatchState() {},
    syncHtmlHomeStableHtml() {},
    resetPanelState() {}
  };
  const reset = new Function(
    'configureWaterfallPreferenceProfileForRuntime',
    'createSeedA2uiSurface',
    'DEFAULT_INPUT_PLACEHOLDER',
    methodBody('resetCurrentSession')
  );

  reset.call(state, () => {}, () => ({ surfaceId: 'surface_seed' }), '输入消息');

  assert.equal(state.showDeepSearch, false);
  assert.equal(state.deepSearchQuery, '');
  assert.equal(state.deepSearchSettingsJson, '');
  assert.equal(state.deepSearchContextJson, '');
});
