import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const source = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url), 'utf8');
function method(name) {
  const start = source.indexOf(`  private ${name}(`);
  assert.notEqual(start, -1, name);
  const end = source.indexOf('\n  private ', start + 1);
  return source.slice(start, end);
}
const methods = ['ensureWaterfallPoolRuntime', 'invalidateAccountScopedState', 'applyWaterfallAutoDisabledSources'];
if (source.includes('  private disposeWaterfallPoolRuntime(')) methods.push('disposeWaterfallPoolRuntime');
const compiled = ts.transpileModule(`class Page { ${methods.map(method).join('\n')} } exports.Page = Page;`, {
  compilerOptions: { target: ts.ScriptTarget.ES2020 }
}).outputText;

test('account logout disposes its pool and rejects late callbacks after another account signs in', () => {
  const workers = [];
  class Pool {
    constructor(_provider, _composio, _policy, _commands, observer) {
      this.notify = observer;
      this.disposed = false;
      workers.push(this);
    }
    setEnabledAdapters() {}
    dispose() { this.disposed = true; }
  }
  const exports = {};
  runInNewContext(compiled, {
    exports, WaterfallPoolWorkerClient: Pool,
    localProviderConfigSnapshotJsonForWorker: () => '{}', composioConfigSnapshotJsonForWorker: () => '{}',
    waterfallSearchPolicyForRuntime: () => ({}), emptyAccountProfileSnapshot: () => ({}),
    effectiveAccountDisplayName: () => '', emptyDiscoveryMemoryPreferenceProjection: () => ({}),
    emptyWaterfallPreferenceProfile: () => ({ discoveryEnabledSources: ['source'] }),
    configureWaterfallEnabledSourcesForRuntime() {}, aiLogInfo() {}
  });
  const page = new exports.Page();
  Object.assign(page, {
    accountOwnerId: 'first', accountOwnerGeneration: 1, waterfallPoolWorkerClient: null,
    waterfallPoolStarted: true, waterfallPoolActivated: true, interestWaterfallFeedState: null,
    waterfallPreferenceProfile: { discoveryEnabledSources: ['source'] },
    invalidateWaterfallLlmBatchLifecycle() {}, invalidateMemoryModelTaskRunnerForAccount() {}, invalidateAboutYou() {},
    unsubscribeTrainPresaleHandoff() {}, disposeHotelRuntime() {}, resetWaterfallConversationStateFromProfile() {},
    resetCurrentSession() {}, cancelInterestPoolRefill() {}, currentWaterfallPoolAdapterIds: () => [],
    syncWaterfallPoolAdapterSelection() {}, updatePublicPersonaSnapshot() {},
    waterfallPreferencesStore() { throw new Error('late callback accessed account storage'); }
  });
  page.ensureWaterfallPoolRuntime();
  const old = workers[0];
  page.invalidateAccountScopedState(false);
  page.accountOwnerId = '';
  assert.equal(old.disposed, true, 'logout must stop the old account worker');
  assert.equal(page.waterfallPoolStarted, false);
  assert.equal(page.waterfallPoolActivated, false);
  old.notify([{ sourceId: 'source', autoDisabled: true }]);
  page.accountOwnerId = 'second';
  page.ensureWaterfallPoolRuntime();
  assert.equal(workers.length, 2, 'next account needs a fresh pool');
  old.notify([{ sourceId: 'source', autoDisabled: true }]);
  let saves = 0;
  page.waterfallPreferencesStore = () => ({ saveDiscoveryEnabledSources: sources => {
    saves++;
    return { discoveryEnabledSources: sources };
  } });
  workers[1].notify([{ sourceId: 'source', autoDisabled: true }]);
  assert.equal(saves, 1, 'current account callbacks still work');
});
