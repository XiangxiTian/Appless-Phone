import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url), 'utf8');
const conversation = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/waterfall/WaterfallConversation.ets', import.meta.url), 'utf8');
const method = source.slice(source.indexOf('  private showWaterfallFeedback('),
  source.indexOf('  private async startVoiceInput('));
const fallback = source.slice(source.indexOf('export function waterfallTagFallbackSettings('),
  source.indexOf('export function hotelTurnReadyMessage('));
const dockSource = readFileSync(new URL('../entry/src/main/ets/pages/A2uiHome/components/WaterfallVoiceDock.ets', import.meta.url), 'utf8');
const placeholder = dockSource.slice(dockSource.indexOf('  private placeholder('), dockSource.indexOf('  private selected('));
let expire;
const context = vm.createContext({
  aggregateSearchInterestSourceIds: () => ['bilibili', 'youtube', 'reddit'],
  WATERFALL_PREFERENCE_TOOL_ID: 'waterfall.preference.adjust',
  CLOUD_CHAT_MODEL_QWEN37_PLUS: 'Qwen3.7-Plus', Error,
  aiLogInfo() {}, aiLogError() {}, Alignment: { Bottom: 'bottom' },
  voiceInputTextAfterRecognition: (base, text) => text.trim() || base,
  setTimeout(callback) { expire = callback; return 1; }, clearTimeout() {}
});
vm.runInContext(stripTypeScriptTypes(conversation.replace(/import\s*\{[\s\S]*?\}\s*from\s*'[^']+';/g, '')
  .replaceAll('export ', '') + fallback.replace('export ', '') + '\nclass Page {\n' + method + '\n}\nglobalThis.Page = Page;\nclass Dock {\n' + placeholder + '\n}\nglobalThis.Dock = Dock;'), context);

function page(reply) {
  const state = new context.Page();
  Object.assign(state, {
    waterfallConversationGeneration: 0, waterfallConversationBusy: false, waterfallVoiceMessage: '', toasts: [],
    waterfallConversationState: { rules: [], history: [], summary: '' },
    interestWaterfallFeedState: {}, bimRootIndex: 1, interestWaterfallComposerHidden: false,
    waterfallPageVisible: true, accountOwnerGeneration: 1, accountOwnerId: 'owner',
    accountDataInitializedOwnerId: 'owner', isBusy: false, applied: [], requests: 0,
    restoreAccountSession: async () => true,
    getSettings: () => ({ model: 'DeepSeek-V4-Flash-0731', baseUrl: 'https://model.example.test', apiKey: 'test' }),
    getUIContext() { return { getPromptAction: () => ({ showToast: toast => this.toasts.push(toast) }) }; },
    waterfallTagModel(settings) { return { complete: async () => { this.requests++; return reply(settings); } }; },
    submitPrompt() { assert.fail('Waterfall must never enter the general task runtime'); },
    applyInterestConversation(command) { this.applied.push(command); }
  });
  return state;
}

const dock = new context.Dock();
Object.assign(dock, { addingTag: false, isListening: false, isBusy: false, message: '语音识别失败，原来的内容不变',
  voiceMessage: '语音没识别成功，请再试一次', selectedTags: ['足球'], tags: ['足球'] });
assert.equal(dock.placeholder(), '试试说：多给我推荐点足球内容', 'idle guidance must survive stale feedback');
dock.isListening = true; dock.voiceMessage = '我想多看科技'; dock.message = dock.voiceMessage;
assert.equal(dock.placeholder(), '我想多看科技');
dock.isListening = false; dock.isBusy = true;
assert.equal(dock.placeholder(), '正在理解');
assert.doesNotMatch(dockSource, /HOME_SEND_INACTIVE_BACKGROUND|#C9C4BF/, 'an available microphone must use the theme color');

const adjustment = '{"operation":"adjust","preferences":[{"dimension":"topic","key":"足球","state":"boost"}]}';
const denied = page(() => adjustment);
denied.restoreAccountSession = async () => false;
await denied.submitWaterfallConversation('多推荐足球内容');
assert.equal(denied.requests, 0);
assert.equal(denied.applied.length, 0);
assert.equal(denied.waterfallConversationBusy, false);
const preference = page(() => adjustment);
await preference.submitWaterfallConversation('多推荐足球内容');
assert.equal(preference.applied[0]?.preferences[0].key, '足球');
assert.equal(preference.requests, 1);
assert.equal(preference.waterfallConversationBusy, false);

for (const failure of ['HTTP 403', 'HTTP 500', 'fallback_403']) {
  const retry = page(settings => {
    if (settings.model !== 'Qwen3.7-Plus') throw new Error(failure === 'HTTP 500' ? failure : 'HTTP 403');
    assert.equal(settings.baseUrl, retry.getSettings().baseUrl);
    assert.equal(settings.apiKey, retry.getSettings().apiKey);
    if (failure === 'fallback_403') throw new Error('HTTP 403');
    return adjustment;
  });
  await retry.submitWaterfallConversation('多推荐足球内容');
  assert.equal(retry.requests, failure === 'HTTP 500' ? 1 : 2, 'only 403 permits one fallback request');
  assert.equal(retry.applied.length, failure === 'HTTP 403' ? 1 : 0);
  assert.equal(retry.waterfallConversationBusy, false);
}

for (const stage of ['initial', 'fallback', 'invalidated']) {
  let settle;
  const timed = page(settings => {
    if (stage === 'fallback' && settings.model !== 'Qwen3.7-Plus') throw new Error('HTTP 403');
    return new Promise((resolve, reject) => { settle = stage === 'fallback' ? () => resolve(adjustment) : () => reject(new Error('HTTP 403')); });
  });
  const task = timed.submitWaterfallConversation('多推荐足球内容');
  await new Promise(setImmediate);
  if (stage === 'invalidated') timed.waterfallConversationGeneration++;
  else { expire(); await task; }
  settle();
  await task;
  await new Promise(setImmediate);
  assert.equal(timed.requests, stage === 'fallback' ? 2 : 1, 'expired or invalidated requests must not start a fallback');
  assert.equal(timed.applied.length, 0, 'late fallback results must not update preferences');
}

for (const prompt of ['帮我搜索明天去上海的机票', '帮我找附近的餐厅', '搜索世界杯']) {
  const unrelated = page(() => 'null');
  unrelated.isBusy = true; // Home work must not block this independent composer.
  await unrelated.submitWaterfallConversation(prompt);
  assert.equal(unrelated.requests, 1);
  assert.equal(unrelated.applied.length, 0);
  assert.equal(unrelated.toasts[0]?.message, '聊聊想看的内容，其他事请回首页');
  assert.equal(unrelated.toasts[0]?.alignment, 'bottom');
  assert.equal(unrelated.toasts[0]?.offset.dy, '-110vp');
  assert.equal(unrelated.waterfallVoiceMessage, '');
}
for (const raw of ['{"operation":"reset","preferences":[]}', '{"operation":"undo","preferences":[]}']) {
  const state = page(() => raw);
  await state.submitWaterfallConversation('恢复推荐偏好');
  assert.equal(state.applied[0]?.operation, JSON.parse(raw).operation);
}
for (const raw of ['garbage', '{"operation":"adjust","preferences":[{"dimension":"source","key":"unknown","state":"boost"}]}']) {
  const invalid = page(() => raw);
  await invalid.submitWaterfallConversation('多推荐足球内容');
  assert.equal(invalid.applied.length, 0);
  assert.ok(invalid.toasts[0]?.message);
  assert.equal(invalid.waterfallVoiceMessage, '');
}
let resolve;
const pending = page(() => new Promise(done => { resolve = done; }));
const first = pending.submitWaterfallConversation('多推荐足球内容');
await Promise.resolve();
await pending.submitWaterfallConversation('少看科技内容');
assert.equal(pending.requests, 1, 'duplicate submissions must not start another request');
pending.waterfallConversationGeneration++; // Session reset/account change invalidates the result.
pending.waterfallConversationBusy = true; // A newer request owns this state.
resolve(adjustment);
await first;
assert.equal(pending.applied.length, 0);
assert.equal(pending.waterfallConversationBusy, true);

let lateReply;
const timeout = page(() => new Promise(done => { lateReply = done; }));
const run = timeout.submitWaterfallConversation('多推荐足球内容');
await new Promise(setImmediate);
expire();
await run;
assert.equal(timeout.applied.length, 0);
assert.equal(timeout.waterfallConversationBusy, false);
assert.ok(timeout.toasts[0]?.message);
assert.equal(timeout.waterfallVoiceMessage, '');
lateReply(adjustment);
await new Promise(setImmediate);
assert.equal(timeout.applied.length, 0, 'a timed-out reply must never change preferences');
for (const failure of ['empty', 'error']) {
  const voice = page(() => adjustment);
  Object.assign(voice, { isVoiceListening: true, voiceSessionSeq: 1, voiceCompletionHandled: false,
    voiceTarget: 'waterfall', voiceBaseInputText: '', waterfallVoiceMessage: '正在理解' });
  if (failure === 'empty') voice.finishVoiceInputWithResult(1, { text: '' });
  else voice.finishVoiceInputWithError(1, new Error('test ASR error'));
  assert.equal(voice.isVoiceListening, false);
  assert.equal(voice.waterfallVoiceMessage, '');
  assert.equal(voice.toasts.length, 1);
  assert.equal(voice.toasts[0].alignment, 'bottom');
  assert.doesNotMatch(voice.toasts[0].message, /原来的内容不变/);
  assert.equal(voice.requests, 0);
}
console.log('Waterfall conversation checks passed');
