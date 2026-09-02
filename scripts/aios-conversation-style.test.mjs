import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');

test('uses a softened version of the main wallpaper for base conversation documents', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(home, /isHtmlHomeConversationDocument/);
  assert.match(home, /private useConversationGlassBackdrop\(\): boolean/);
  assert.match(home, /this\.showDeepSearch \|\| this\.showTrainPresalePanel \|\| this\.showCheckoutWeb/);
  assert.match(home, /this\.isAwaitingFirstSurface \|\| isHtmlHomeConversationDocument\(this\.htmlHomeHtml\)/);
  assert.match(home, /Image\(\$rawfile\('aios-home\/assets\/wallpapers\/now-blue\.png'\)\)/);
  assert.match(home, /\['#E0F8FAFD', 0\],[\s\S]*?\['#C2EDF3F9', 0\.46\],[\s\S]*?\['#99F2F3FA', 1\]/);
  assert.doesNotMatch(home, /private AiosConversationHeader\(\)/);
});

test('restores the original conversation chrome while retaining pending bubble colors', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(home, /return this\.hasSendableText\(\) \? A2UI_HOME_SEND_ACTIVE_BACKGROUND : A2UI_HOME_SEND_INACTIVE_BACKGROUND/);
  assert.match(home, /placeholder: this\.inputPlaceholder/);
  assert.match(home, /backgroundColor\(this\.isVoiceListening \? '#A6FFFFFF' : A2UI_HOME_GLASS_BACKGROUND\)/);
  assert.match(home, /backgroundColor\('#8F202A3A'\)/);
  assert.match(home, /backgroundColor\('#DDE9EEF5'\)/);
  assert.match(home, /constraintSize\(\{ minHeight: 60 \}\)/);
  assert.match(home, /padding\(\{ left: 16, right: 16, top: 16, bottom: 17 \}\)/);
  assert.match(home, /shadow\(\{ radius: 38, color: '#29121C2E', offsetX: 0, offsetY: 18 \}\)/);
});

test('shows the native pending overlay only for the first user turn', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(home, /export function shouldShowNativeFirstConversationPending\(/);
  assert.match(home, /if \(userTurnCount > 1\) return false;/);
  assert.match(home, /\.opacity\(shouldShowNativeFirstConversationPending\(/);
  assert.match(home,
    /if \(shouldShowNativeFirstConversationPending\(this\.isAwaitingFirstSurface, this\.messages\)\) \{/);
});

test('removes the conversation logo and introductory heading without affecting result pages', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  assert.match(home, /if \(!this\.useConversationGlassBackdrop\(\)\) \{\s*Image\(\$r\('app\.media\.logo_appless'\)\)/s);
  assert.doesNotMatch(home, /Text\('和 Appless 聊聊'\)/);
  assert.doesNotMatch(home, /Text\('回答优先，历史内容按需展开'\)/);
  assert.doesNotMatch(renderer, /add\(hero, 'h1', '', '和 Appless 聊聊'\)/);
  assert.match(renderer, /function renderSceneHero\(parent\) \{\s*if \(isThinkingDocument\(\)\) \{ return; \}/s);
});

test('matches the main-page composer and removes the inner conversation backdrop panel', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(home, /const A2UI_COMPOSER_MIN_HEIGHT: number = 61;/);
  assert.match(home, /const A2UI_HOME_GLASS_BACKGROUND: string = '#9EE5E8EA';/);
  assert.match(home, /const A2UI_HOME_GLASS_EDGE: string = '#9EFFFFFF';/);
  assert.match(home, /const A2UI_HOME_GLASS_SHADOW: string = '#26211B25';/);
  assert.match(home, /keyboard\.png/);
  assert.match(home, /video\.fill\.png/);
  assert.match(home, /\.fontSize\(20\)\s*\.fontWeight\(FontWeight\.Medium\)\s*\.fontColor\('#CC20242C'\)/s);
  assert.match(home, /\.textAlign\(TextAlign\.Center\)/);
  assert.match(home, /\.placeholderColor\('#80000000'\)/);
  assert.match(home, /const A2UI_CONVERSATION_RADIUS: number = 24;/);
  assert.match(home, /\.borderRadius\(A2UI_CONVERSATION_RADIUS\)/);
  assert.match(home, /\.width\(this\.isVoiceListening \? '93%' : '90%'\)/);
  assert.doesNotMatch(home, /\.width\('92%'\)\s*\.height\('88%'\)/);
  assert.match(home, /if \(!this\.useConversationGlassBackdrop\(\)\) \{\s*Text\('内容由 AI 生成'\)/s);
});

test('keeps the conversation surface transparent and scopes selected bubble colors', () => {
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  assert.match(
    renderer,
    /body\[data-view="conversation"\],\s*body\[data-view="conversation-thinking"\]\s*\{[\s\S]*?--accent: #17191d;[\s\S]*?background: transparent;\s*backdrop-filter: none;/
  );
  assert.match(renderer, /body\[data-view="conversation"\] \.plain-chat-user-copy/);
  assert.match(renderer, /body\[data-view="conversation-thinking"\] \.plain-chat-response/);
  assert.match(renderer, /background: rgba\(30, 41, 57, 0\.72\)/);
  assert.match(renderer, /background: rgba\(239, 243, 248, 0\.9\)/);
  assert.match(renderer, /body\[data-view="conversation"\] \.plain-chat-user-copy,[\s\S]*?border-radius: 24px;/);
  assert.match(renderer, /--accent: #17191d;/);
  assert.match(renderer, /--accent-soft: rgba\(23, 25, 29, 0\.09\);/);
  assert.doesNotMatch(renderer, /\.plain-chat-user-role\s*\{/);
  assert.match(renderer, /\.conversation-thinking\s*\{\s*min-height: 60px;/s);
  assert.match(renderer, /body\[data-view="conversation-thinking"\] \.plain-chat-response[\s\S]*?min-height: 60px;[\s\S]*?border-radius: 24px;/);
  assert.match(renderer, /function addThinkingScene\([\s\S]*?addPlainChatContext\(section, contextItems\);/);
  assert.doesNotMatch(renderer, /body\[data-view="conversation"\] \.plain-chat-hero h1/);
});

test('uses monochrome native accents for pending chat and page state', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(home, /private conversationAccentColor\(\): string/);
  assert.match(home, /this\.useConversationGlassBackdrop\(\) \? '#17191D' : COLOR_ACCENT/);
  assert.match(home, /monochrome: this\.useConversationGlassBackdrop\(\)/);
  assert.match(home, /@Prop monochrome: boolean = false;/);
  assert.match(home, /this\.monochrome \? '#17191D' : '#8E6558'/);
  assert.match(home, /Image\(\$rawfile\('aios-home\/assets\/brand\/digital-mate-mark-black\.png'\)\)/);
  assert.match(home, /\.fill\('#17191D'\)/);
  assert.match(home, /private headerButtonEdgeColor\(\): string \{\s*return this\.useConversationGlassBackdrop\(\) \? '#2417191D' : A2UI_HOME_HEADER_BUTTON_EDGE;/s);
  assert.match(home, /private headerButtonShadowColor\(\): string \{\s*return this\.useConversationGlassBackdrop\(\) \? '#1F17191D' : A2UI_HOME_HEADER_BUTTON_SHADOW;/s);
  assert.match(home, /customBorderColor: this\.headerButtonEdgeColor\(\)/);
  assert.match(home, /shadowColor: this\.headerButtonShadowColor\(\)/);
});

test('uses the extracted transparent brand mark for assistant identity', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  const asset = new URL(
    'entry/src/main/resources/rawfile/aios-home/assets/brand/digital-mate-mark-black.png',
    root
  );
  assert.equal(existsSync(asset), true);
  assert.match(home, /Image\(\$rawfile\('aios-home\/assets\/brand\/digital-mate-mark-black\.png'\)\)/);
  assert.match(renderer, /plain-chat-assistant-logo/);
  assert.match(renderer,
    /resource:\/\/rawfile\/aios-home\/assets\/brand\/digital-mate-mark-black\.png/);
  assert.doesNotMatch(renderer, /add\(identity, 'div', 'plain-chat-assistant-mark', 'A'\)/);
});

test('uses the same brand mark for assistant turns in expanded context', () => {
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  assert.match(renderer, /plain-chat-context-logo/);
  assert.match(renderer,
    /if \(role === 'assistant'\) \{[\s\S]*?resource:\/\/rawfile\/aios-home\/assets\/brand\/digital-mate-mark-black\.png/);
  assert.doesNotMatch(renderer,
    /add\(turn, 'div', 'plain-chat-role', role === 'assistant' \? 'Appless' : '你'\)/);
});

test('defers tool result pages until the final reply and exposes explicit enter and return controls', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  const index = read('entry/src/main/ets/pages/A2uiHome/Index.ets');
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  assert.match(index, /@State deferredToolResultSurface: A2uiSurfaceState \| null = null;/);
  assert.match(index, /private stageRuntimeToolSurface\(/);
  assert.match(index,
    /if \(this\.shouldDeferRuntimeToolSurface\(surface, owner\)\) \{\s*return this\.stageRuntimeToolSurface/);
  assert.match(index,
    /const assistantMessageId = this\.completeStreamingAssistantMessage\(readyMessage, turnGeneration\);[\s\S]*?this\.revealDeferredToolResultEntry\(turnGeneration, assistantMessageId\);/);
  assert.match(index, /runtimeOwner !== 'multi_agent' && !inlineLuckinSwitch/);
  assert.match(index, /item\.toolResultEntry = entry;/);
  assert.match(renderer, /function syncPlainChatToolResultEntry\(/);
  assert.match(renderer, /plain-chat-tool-result-entry/);
  assert.match(renderer, /syncPlainChatToolResultEntry\(turnBody, item && item\.toolResultEntry\);/);
  assert.doesNotMatch(home, /private ToolResultEntry\(\)/);
  assert.match(home, /private ToolResultReturnButton\(\)/);
  assert.match(home, /Text\('返回对话'\)/);
  assert.match(home, /if \(this\.toolResultFullscreen\) \{/);
  assert.match(home,
    /if \(this\.toolResultFullscreen\) \{[\s\S]*?\.position\(\{ x: 0, y: 0 \}\)/);
  assert.match(home, /if \(shouldShowHomeChrome\(this\.waterfallFullscreen\)\) \{/);
  assert.match(index,
    /this\.ownedSurface\(\s*this\.surfaceSnapshot\(record\.surface\),\s*this\.activeRuntimeOwner,\s*this\.runtimeGeneration\s*\)/s);
});

test('removes the user identity badge while preserving right-aligned user bubbles', () => {
  const home = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  const pending = home.slice(
    home.indexOf('  private FirstConversationPendingView()'),
    home.indexOf('  build() {', home.indexOf('  private FirstConversationPendingView()'))
  );
  assert.doesNotMatch(pending, /Text\('你'\)/);
  assert.match(renderer,
    /\.plain-chat-user-message\s*\{[\s\S]*?display: block;[\s\S]*?max-width: 84%;[\s\S]*?margin: 0 0 0 auto;/);
  assert.doesNotMatch(renderer, /add\(userMessage, 'span', 'plain-chat-user-role', '你'\)/);
  const addPlainChat = renderer.slice(
    renderer.indexOf('  function addPlainChat(parent, history) {'),
    renderer.indexOf('  function thinkingRequest(', renderer.indexOf('  function addPlainChat(parent, history) {'))
  );
  assert.doesNotMatch(addPlainChat, /role\.textContent = '你'/);
});

test('restores completed replies without replaying the streaming reveal', () => {
  const renderer = read('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets');
  const addPlainChat = renderer.slice(
    renderer.indexOf('  function addPlainChat(parent, history) {'),
    renderer.indexOf('  function thinkingRequest(', renderer.indexOf('  function addPlainChat(parent, history) {'))
  );
  assert.match(addPlainChat,
    /add\(response, 'p', 'plain-chat-response-copy', text\(assistant\.content\)\);/);
  assert.doesNotMatch(addPlainChat, /queueConversationAssistantReveal/);
  assert.match(renderer,
    /function replaceAssistantResponse\([\s\S]*?queueConversationAssistantReveal\(currentCopy, expectedText\);/);
});
