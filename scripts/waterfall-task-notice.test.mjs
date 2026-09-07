import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';

const source = new URL('../entry/src/main/ets/pages/A2uiHome/waterfall/WaterfallTaskNotice.ets', import.meta.url);
assert.ok(existsSync(source), 'Waterfall needs a notice for the running home task');
const moduleText = stripTypeScriptTypes(readFileSync(source, 'utf8'));
const { taskNoticeSnapshot, taskNoticeDisplay, emptyTaskNotice, syncTaskNotice, dismissTaskNotice, taskNoticeGestureCanDismiss } =
  await import(`data:text/javascript;base64,${Buffer.from(moduleText).toString('base64')}`);

const weatherReply = '深圳市当前天气：多云，29°C。\n风向 西北，风力 ≤3，湿度 80%。\n\n来源：高德天气 · 2026-09-07 18:00:18';
assert.deepEqual(taskNoticeDisplay(weatherReply), {
  summary: '深圳 · 多云，29°C',
  body: '深圳现在多云，29°C。\n西北风，风力 ≤3，湿度 80%。',
  source: '高德天气 · 2026-09-07 18:00'
});
assert.deepEqual(taskNoticeDisplay('第一段\n\n第二段'), { summary: '第一段', body: '第一段\n\n第二段', source: '' });
assert.equal(taskNoticeDisplay('天气暂时查询失败').body, '天气暂时查询失败');
assert.equal(taskNoticeDisplay('').summary, '');
assert.equal(taskNoticeDisplay('深圳市明天：阵雨，26–31°C。\n\n来源：高德天气').body, '深圳市明天：阵雨，26–31°C。');

const renderer = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets', import.meta.url), 'utf8');
const insetScript = renderer.slice(renderer.indexOf('  var taskInsetAnimation = null;'),
  renderer.indexOf('  window.__aiphoneSetWaterfallActive ='));
const track = {
  style: {}, scrollTop: 320,
  getBoundingClientRect() { return { top: parseFloat(this.style.marginTop) || 0 }; },
  animate() { return { cancel() {} }; }
};
let measurements = 0;
const context = { track, window: { getComputedStyle: () => ({ paddingTop: '76px' }) },
  refreshCardMetrics: () => { measurements++; } };
const { runInNewContext } = await import('node:vm');
runInNewContext(insetScript, context);
context.window.__aiphoneSetWaterfallTaskInset(220, false);
assert.equal(track.style.marginTop, '144px');
assert.equal(track.style.height, 'calc(100dvh - 144px)');
assert.equal(track.scrollTop, 320, 'the inset bridge does not assign scrollTop');
context.window.__aiphoneSetWaterfallTaskInset(220, false);
assert.equal(measurements, 1, 'unchanged task text cannot re-layout the feed');
context.window.__aiphoneSetWaterfallTaskInset(0, true);
assert.equal(track.style.marginTop, '0px');
assert.equal(track.style.height, 'calc(100dvh - 0px)');

const messages = [
  { id: 'old', role: 'assistant', content: '之前的回答' },
  { id: 'q1', role: 'user', content: '今天深圳的天气怎样' }
];
let task = taskNoticeSnapshot(messages, 'q1', true, '');
let notice = syncTaskNotice(emptyTaskNotice(), task, false);
notice = syncTaskNotice(notice, task, true);
assert.equal(notice.mode, 'capsule');
assert.equal(task.reply, '', 'do not reuse the previous task answer');
messages.push({ id: 'a1', role: 'assistant', content: '深圳天气查询结果' });
task = taskNoticeSnapshot(messages, 'q1', false, '');
notice = syncTaskNotice(notice, task, true);
assert.equal(notice.mode, 'preview');
assert.equal(task.reply, '深圳天气查询结果');
assert.equal(taskNoticeSnapshot(messages, 'q1', false, '', '深圳市当前天气：阴，29°C。').reply,
  '深圳市当前天气：阴，29°C。', 'show the real result summary rather than the generic completion message');
assert.equal(taskNoticeSnapshot(messages, 'q1', true, '', '上一轮结果').reply,
  '深圳天气查询结果', 'do not show a settled result while the next task runs');
notice = dismissTaskNotice(notice);
assert.equal(syncTaskNotice(notice, task, true).mode, 'hidden', 'dismissed results must stay dismissed');

notice = { ...notice, mode: 'sheet' };
messages.push({ id: 'q2', role: 'user', content: '那明天呢' });
task = taskNoticeSnapshot(messages, 'q2', true, '');
notice = syncTaskNotice(notice, task, true);
assert.equal(notice.mode, 'sheet', 'follow-up stays inside the half-screen');
assert.equal(task.reply, '');
task = taskNoticeSnapshot(messages, 'q2', false, '天气暂时查询失败');
notice = syncTaskNotice(notice, task, true);
assert.equal(notice.mode, 'sheet', 'reading a result has no automatic timeout');
assert.equal(task.failed, true);
assert.equal(task.reply, '天气暂时查询失败');
assert.equal(syncTaskNotice(notice, task, false).mode, 'hidden');
assert.equal(syncTaskNotice(emptyTaskNotice(), task, true).mode, 'hidden', 'do not announce old completed tasks on entry');
assert.equal(taskNoticeSnapshot(messages, 'missing', true, '').id, '', 'history/account reset drops the old notice');
assert.equal(dismissTaskNotice({ id: 'q2', running: true, mode: 'sheet' }).mode, 'capsule');

const indexPage = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url), 'utf8');
const submitPrompt = indexPage.slice(indexPage.indexOf('  private async submitPrompt('),
  indexPage.indexOf('  private async submitBimPrompt('));
const genericFailure = '这次请求没有完成，请稍后重试。';
const failedTurn = runInNewContext(stripTypeScriptTypes(`(class { ${submitPrompt} })`), {
  inputTextAfterPromptSubmit: () => '', waterfallSearchQueryForHomePrompt: () => '',
  explicitDeepSearchRouteDecision: () => 'conversation', modelPromptWithActionContext: text => text,
  buildBimForegroundRequest: prompt => ({ prompt }), DEFAULT_INPUT_PLACEHOLDER: '',
  configureLocalToolDebugConfig() {}, normalizeFoodProviderDelayMs: value => value,
  runtimeCallbackIsCurrent: () => true, aiLogInfo() {}, aiLogError() {}, logSnippet: value => value,
  summaryData: surface => surface.summary, visibleTurnFailureMessage: () => genericFailure,
  createTurnFailureSurface: text => ({ text }), updateConnectionPanelState: (_, state) => state,
  isMultiTaskSurface: () => false
});
const weatherFailure = '天气服务缺少访问配置，请完成天气服务的凭据配置后再查询。';
for (const [dataLabel, generation, count, expected] of [
  ['weather.query', 7, 0, weatherFailure], ['weather.query', 6, 0, genericFailure],
  ['weather.query', 7, 1, genericFailure], ['food.search', 7, 0, genericFailure]
]) {
  const host = {
    isBusy: false, inputText: '', baseUrl: 'configured', selectedModel: 'test', runtimeGeneration: 7,
    currentSurface: { runtimeOwner: 'multi_agent', runtimeGeneration: generation,
      summary: { dataLabel, count, text: weatherFailure } },
    restoreAccountSession: async () => true, clearStreamingAssistantMessage() {}, appendMessage: () => 'q',
    beginRuntimeTurn: () => 7, markChecking() {}, multiAgentInput: async () => ({}),
    canaryRuntime: () => ({ submit: async () => ({ ok: false, message: 'runtime failure' }) }),
    completeStreamingAssistantMessage(text) { this.assistantReply = text; },
    applyRuntimeSurface(surface) { this.currentSurface = surface; }, currentPanelState: () => ({}),
    applyPanelState(state) { this.panelState = state; }, sessionContextCompactor: { compactAfterTurn() {} },
    finishForegroundTurn() { this.isBusy = false; }
  };
  await failedTurn.prototype.submitPrompt.call(host, '今天深圳天气', '今天深圳天气');
  assert.equal(host.assistantReply, expected, 'settled runtime failures reach the conversation');
  assert.equal(host.waterfallTaskError, expected, 'the notice keeps the same actionable failure');
  assert.equal(host.panelState.ok, false, 'an actionable weather error remains a failed task');
  assert.equal(host.waterfallTaskRunning, false);
}
const binding = indexPage.match(/task: (taskNoticeSnapshot\([\s\S]*?\)),\n\s+active:/)[1];
const boundSnapshot = new Function('taskNoticeSnapshot', `return function () { return ${binding}; };`)(taskNoticeSnapshot);
const home = { messages, waterfallTaskMessageId: 'q1', waterfallTaskRunning: false,
  waterfallTaskError: '', waterfallTaskResult: '深圳天气查询结果',
  isBusy: true, connectionStatus: 'error', connectionMessage: '无关的连接检查失败',
  appendMessage() {}, sessionContextCompactor: { compactAfterTurn() {} } };
assert.equal(boundSnapshot.call(home).running, false, 'unrelated page actions cannot restart the completed task');
assert.equal(boundSnapshot.call(home).failed, false, 'unrelated connection errors cannot replace the task result');
assert.equal(syncTaskNotice({ id: 'q1', running: false, mode: 'hidden' }, boundSnapshot.call(home), true).mode, 'hidden');
const completeDeepSearch = indexPage.slice(indexPage.indexOf('  private completeDeepSearch('),
  indexPage.indexOf('  private openAnythingDemo('));
const completion = runInNewContext(stripTypeScriptTypes(`(class { ${completeDeepSearch} })`), { aiLogInfo() {} });
home.waterfallTaskRunning = true;
home.waterfallTaskError = '上一轮任务失败';
completion.prototype.completeDeepSearch.call(home, '新的研究结果');
assert.equal(boundSnapshot.call(home).reply, '新的研究结果');
assert.equal(boundSnapshot.call(home).failed, false, 'a successful search clears the preceding task error');
completion.prototype.completeDeepSearch.call(home, '本次检索失败', '本次检索失败');
assert.equal(boundSnapshot.call(home).failed, true, 'a real search error remains a failure');
const homePage = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/components/HomePage.ets', import.meta.url), 'utf8');
const readiness = homePage.match(/startReady: ([^,\n]+)/)[1];
const ready = new Function(`return ${readiness};`);
assert.equal(ready.call({ deepSearchLoadingReady: false, waterfallActive: false }), true, 'background search cannot wait for the hidden main WebView');
assert.equal(ready.call({ deepSearchLoadingReady: false, waterfallActive: true }), false, 'foreground search preserves the existing readiness order');
assert.match(renderer, /\.waterfall-track\s*\{\s*position: relative;/, 'snap offsets must be relative to the inset track');
const replyHandler = indexPage.slice(indexPage.indexOf('private async submitWaterfallTaskReply('),
  indexPage.indexOf('private async submitWaterfallConversation('));
assert.ok(replyHandler.includes("this.submitPrompt(text.trim(), text.trim(), '', null, '', true)"), 'half-screen replies use the home runtime and preserve its draft');
assert.ok(!replyHandler.includes('changeIndex('), 'half-screen replies cannot force home navigation');
console.log('Waterfall task notice lifecycle and home follow-up checks passed');

assert.equal(taskNoticeGestureCanDismiss('preview', 1000, 900), false, 'a gesture already in flight cannot hide a new result');
assert.equal(taskNoticeGestureCanDismiss('preview', 1000, 2799), false, 'new results get a readable interval even while scrolling');
assert.equal(taskNoticeGestureCanDismiss('preview', 1000, 2800), true, 'a later background gesture dismisses the result');
assert.equal(taskNoticeGestureCanDismiss('sheet', 1000, 1100), true);
assert.equal(taskNoticeGestureCanDismiss('capsule', 1000, 5000), false);
assert.equal(taskNoticeGestureCanDismiss('hidden', 1000, 5000), false);
assert.ok(!indexPage.includes('waterfallTaskInteractionTick'), 'background gestures must not invalidate the root page');
