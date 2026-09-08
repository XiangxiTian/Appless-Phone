import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const source = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url), 'utf8');

function methodBody(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} must exist`);
  const bodyStart = start + signature.length;
  let depth = 1;
  for (let index = bodyStart; index < source.length; index++) {
    if (source[index] === '{') depth++;
    if (source[index] === '}') depth--;
    if (depth === 0) return source.slice(bodyStart, index).replaceAll('(): boolean =>', '() =>');
  }
  throw new Error(`Unclosed ${signature}`);
}

class CoordinatorProbe {
  constructor(options) { this.isActive = options.isActive; this.invalidations = 0; }
  invalidate() { this.invalidations++; }
}

function pageHost() {
  const state = {
    pageAlive: false, pageLifecycleGeneration: 0,
    aboutYouGeneration: 0, aboutYouSocialGeneration: 0,
    aboutYouCoordinatorInstance: null, accountOwnerGeneration: 1,
    accountOwnerId: 'owner', accountSessionStatus: 'authenticated',
    showAboutYouPage: false, waterfallPoolWorkerClient: null,
    waterfallRankingWorkerClient: { dispose() {} },
    requireAccountOwnerId() { return this.accountOwnerId; },
    localMemoryRuntime() { return {}; }, memoryModelTaskRunner() { return {}; },
    memoryOverviewCacheStore() { return {}; },
    restoreAccountSession() { this.accountSessionStatus = 'authenticated'; return Promise.resolve(true); }
  };
  for (const name of ['loadModelPreset', 'loadAggregateSearchPolicy', 'loadBimMotionPreference',
    'readDebugBuildState', 'configureComposioRuntimeForCurrentUser', 'subscribeWaterfallConversationTypedTest',
    'invalidateWaterfallLlmBatchLifecycle', 'stopBimMotionPreference', 'unsubscribeTrainPresaleHandoff',
    'unsubscribeWaterfallConversationTypedTest', 'disposeHotelRuntime', 'cancelInterestPoolRefill', 'disposeWaterfallPoolRuntime',
    'scheduleWaterfallTagGenerationIfSafe']) state[name] = () => {};
  const dependencies = ['LongTermMemoryOverviewCoordinator', 'AccountSessionStatus', 'emptyAboutYouViewModel'];
  for (const [name, signature] of [
    ['aboutToAppear', 'aboutToAppear(): void {'],
    ['aboutToDisappear', 'aboutToDisappear(): void {'],
    ['onPageHide', 'onPageHide(): void {'],
    ['invalidateAboutYou', 'private invalidateAboutYou(): void {'],
    ['aboutYouCoordinator', 'private aboutYouCoordinator(): LongTermMemoryOverviewCoordinator {']
  ]) {
    const method = new Function(...dependencies, `return function() {${methodBody(signature)}}`)(
      CoordinatorProbe, { RESTORING: 'restoring', AUTHENTICATED: 'authenticated' }, () => ({}));
    state[name] = method;
  }
  return state;
}

test('destroying Index retires the coordinator even if the old visible state remains true', () => {
  const page = pageHost();
  page.aboutToAppear();
  page.showAboutYouPage = true;
  const coordinator = page.aboutYouCoordinator();
  assert.equal(coordinator.isActive(), true);

  page.aboutToDisappear();
  assert.equal(page.pageAlive, false);
  assert.equal(page.aboutYouCoordinatorInstance, null);
  assert.equal(coordinator.invalidations, 1);
  assert.equal(page.aboutYouGeneration, 1);
  page.showAboutYouPage = true;
  assert.equal(coordinator.isActive(), false);

  page.aboutToAppear();
  assert.equal(page.pageAlive, true);
  assert.equal(coordinator.isActive(), false);
  assert.equal(page.aboutYouCoordinator().isActive(), true);
});

test('ordinary hiding keeps the overview task live', () => {
  const page = pageHost();
  page.aboutToAppear();
  page.showAboutYouPage = true;
  const coordinator = page.aboutYouCoordinator();
  page.onPageHide();
  assert.equal(page.pageAlive, true);
  assert.equal(coordinator.isActive(), true);
  assert.equal(coordinator.invalidations, 0);
});

test('a failed first correction write exposes overview refresh before retrying', async () => {
  const signature = 'private async correctAboutYou(text: string, claimIndex: number): Promise<void> {';
  const correct = new Function(`return async function(text, claimIndex) {${methodBody(signature)}}`)();
  const state = {
    pageAlive: true, showAboutYouPage: true, aboutYouGeneration: 1,
    aboutYouCorrectionDisabled: false,
    aboutYouOverview: { claims: [{ heading: '偏好' }] },
    aboutYouModel: { updating: false, social: { importing: false },
      overviewState: 'ready', updateError: '', overviewError: '' },
    publishAboutYou() {},
    setAboutYouOverview(overview) { this.aboutYouOverview = overview; },
    aboutYouCoordinator() {
      return { correct: async () => ({ status: 'error', overview: null,
        evidenceIndex: { entries: [] }, message: '长期记忆修改失败，请重试。' }) };
    }
  };
  await correct.call(state, '更改偏好', 0);
  assert.equal(state.aboutYouModel.updating, false);
  assert.equal(state.aboutYouModel.overviewState, 'error');
  assert.equal(state.aboutYouCorrectionDisabled, true);
  assert.equal(state.aboutYouOverview, null);
  assert.equal(state.aboutYouModel.overviewError, '长期记忆修改失败，请重试。');
});


test('public account discovery retains the avatar in the confirmation view model', async () => {
  const body = methodBody('private async searchAboutYouAccounts(username: string, mode: PublicPersonaSearchMode): Promise<void> {')
    .replaceAll(': PublicPersonaProgress', '').replaceAll(': PublicPersonaCandidate', '')
    .replaceAll(': AboutYouCandidate', '').replaceAll(': void', '');
  const search = new Function(`return async function(username, mode) {${body}}`)();
  const candidate = { id: 'github:test', platform: 'github', displayName: 'Test', username: 'test',
    avatarUrl: 'https://example.com/avatar.png', ownershipBand: 'high', selected: true };
  const state = {
    showAboutYouPage: true, aboutYouSocialGeneration: 0, accountOwnerGeneration: 1,
    aboutYouModel: { social: { phase: 'input', importing: false } }, publicPersonaViewModelJson: '{}',
    publicPersonaClient: { discover: async () => [candidate] },
    aboutYouSocialIsCurrent: () => true, publishAboutYou() {}
  };
  await search.call(state, 'test', 'exact');
  assert.equal(state.aboutYouModel.social.phase, 'confirm');
  assert.equal(state.aboutYouModel.social.candidates[0].avatarUrl, candidate.avatarUrl);
});
