import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');

test('mounts the native ArkUI AIOS home and keeps its app callbacks', () => {
  const homePage = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(homePage, /if \(this\.showWelcome\) \{\s*AiosNowHomeView\(/s);
  assert.match(homePage, /systemTopInsetVp: this\.systemTopInsetVp/);
  assert.match(homePage, /systemBottomInsetVp: this\.systemBottomInsetVp/);
  assert.match(homePage, /onSubmitPrompt:[\s\S]*?this\.chooseWelcomePrompt\(prompt\)/);
  assert.match(homePage, /onOpenConversation:[\s\S]*?this\.onOpenConversation\(\)/);
  assert.match(homePage, /onOpenWaterfall:[\s\S]*?this\.onOpenWaterfall\(\)/);
  assert.doesNotMatch(homePage, /AiosPrototypeHomeView/);
});

test('keeps the welcome layout at full scale while the keyboard is visible', () => {
  const homePage = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(homePage, /@Prop @Watch\('onShowWelcomeChanged'\) showWelcome: boolean/);
  assert.match(homePage,
    /this\.showWelcome \? KeyboardAvoidMode\.NONE : KeyboardAvoidMode\.RESIZE/);
  assert.match(homePage, /private onShowWelcomeChanged\(\): void \{\s*this\.applyKeyboardAvoidMode\(\);/s);
});

test('uses responsive viewport and safe-area calculations instead of a fixed runtime canvas', () => {
  const view = read('entry/src/main/ets/pages/A2uiHome/components/AiosNowHomeView.ets');
  assert.match(view, /onAreaChange/);
  assert.match(view, /parseFloat\(newArea\.width\.toString\(\)\)/);
  assert.match(view, /parseFloat\(newArea\.height\.toString\(\)\)/);
  assert.match(view, /safeHeight = Math\.max\(1, height - this\.systemTopInsetVp - this\.systemBottomInsetVp\)/);
  assert.match(view, /baseSafeHeight = AIOS_BASE_HEIGHT - AIOS_BASE_TOP_INSET - AIOS_BASE_BOTTOM_INSET/);
  assert.match(view, /this\.horizontalUnit = Math\.min\(widthScale, AIOS_MAX_HORIZONTAL_SCALE\)/);
  assert.match(view, /this\.unit = Math\.min\(this\.horizontalUnit, heightScale\)/);
  assert.match(view, /this\.originX = \(width - AIOS_BASE_WIDTH \* this\.horizontalUnit\) \/ 2/);
  assert.match(view, /\.width\(this\.w\(386\)\)\.height\(this\.d\(284\)\)/);
  assert.doesNotMatch(view, /@kit\.ArkWeb|\bWeb\s*\(/);
});

test('fills compact-height phones horizontally without overflowing tall layouts', () => {
  const metrics = (width, height, top = 24, bottom = 12) => {
    const horizontal = Math.min(width / 430, 1.25);
    const vertical = Math.min(horizontal, (height - top - bottom) / (930 - 24 - 12));
    return { horizontal, vertical, cardWidth: 386 * horizontal, cardHeight: 260 * vertical };
  };
  const reference = metrics(430, 930);
  assert.equal(reference.horizontal, 1);
  assert.equal(reference.vertical, 1);
  const compact = metrics(430, 640);
  assert.ok(compact.cardWidth / 430 > 0.89);
  assert.ok(compact.cardHeight < reference.cardHeight);
  const foldable = metrics(800, 800);
  assert.equal(foldable.horizontal, 1.25);
  assert.ok(foldable.cardWidth < 800);
});

test('recreates the reference carousel, attention section and inline voice composer in ArkUI', () => {
  const view = read('entry/src/main/ets/pages/A2uiHome/components/AiosNowHomeView.ets');
  assert.match(view, /const AIOS_SURFACE_RADIUS: number = 34;/);
  assert.match(view, /const AIOS_COMPOSER_RADIUS: number = AIOS_SURFACE_RADIUS;/);
  assert.match(view, /const AIOS_COMPOSER_ACTIVE_RADIUS: number = AIOS_SURFACE_RADIUS;/);
  assert.match(view, /borderRadius\(this\.d\(AIOS_SURFACE_RADIUS\)\)/);
  assert.match(view, /\.borderRadius\(this\.d\(this\.voiceHolding \|\| this\.isVoiceListening \?/);
  assert.match(view, /PanGesture\(\{ fingers: 1, direction: PanDirection\.Horizontal/);
  assert.match(view, /private StatusChrome\(\)[\s\S]*?hitTestBehavior\(HitTestMode\.None\)/);
  assert.match(view, /const delta = this\.dragX < 0 \? 1 : AIOS_ACTIVITY_COUNT - 1/);
  assert.match(view, /this\.activeActivity = \(this\.activeActivity \+ delta\) % AIOS_ACTIVITY_COUNT/);
  assert.match(view, /private AttentionEmptyState\(\)/);
  assert.match(view, /Text\('暂无待处理事项'\)/);
  assert.match(view, /Text\('新的待办会显示在这里'\)/);
  assert.match(view, /this\.holdTimerId = setTimeout/);
  assert.match(view, /this\.voicePulseTimerId = setInterval\(\(\): void => this\.advanceVoicePulse\(\)/);
  assert.match(view, /this\.voicePulseTick = \(this\.voicePulseTick \+ 1\) % AIOS_VOICE_PULSE_STEPS/);
  assert.match(view, /\.height\(this\.c\(this\.voiceWaveHeight\(height, index\)\)\)/);
  assert.match(view, /TextInput\(\{ text: this\.commandText, placeholder: '点击输入或按住说话' \}\)/);
  assert.match(view, /\.onSubmit\(\(\): void => this\.submitCommand\(\)\)/);
  assert.match(view, /if \(this\.commandText\.trim\(\)\.length === 0\) \{\s*Image\(\$rawfile\('aios-home\/assets\/icons\/sf-symbols\/video\.fill\.png'\)\)/s);
  assert.match(view, /Image\(\$r\('app\.media\.arrow_up'\)\)/);
  assert.match(view, /backgroundColor\(AIOS_COMPOSER_SEND_BACKGROUND\)/);
  assert.match(view, /AIOS_COMPOSER_SEND_BACKGROUND: string = '#17191D'/);
  assert.match(view, /\.onClick\(\(\): void => this\.submitCommand\(\)\)/);
  assert.match(view, /private beginVoiceTouch\(\): void \{\s*if \(this\.commandText\.trim\(\)\.length > 0\) return;/s);
  assert.doesNotMatch(view, /private CommandSheet\(\)/);
  assert.doesNotMatch(view, /commandVisible/);
  assert.match(view, /hostWindow\.on\('keyboardHeightChange', this\.keyboardHeightListener\)/);
  assert.match(view, /return this\.keyboardHeightVp \+ this\.c\(AIOS_COMPOSER_KEYBOARD_GAP\)/);
  assert.match(view, /private c\(value: number\): number \{\s*return value \* this\.horizontalUnit;/s);
  assert.match(view, /\.fontSize\(this\.c\(AIOS_COMPOSER_TEXT_SIZE\)\)\.fontWeight\(FontWeight\.Medium\)/);
  assert.match(view, /this\.viewportHeight - this\.composerBottomOffset\(\)/);
  assert.match(view, /private keyboardEditing\(\): boolean \{\s*return this\.keyboardHeightVp > 0;/s);
  assert.match(view, /private ActivityDeck\(\)[\s\S]*?\.opacity\(this\.keyboardEditing\(\) \? 0 : 1\)/);
  assert.match(view, /private AttentionSection\(\)[\s\S]*?\.opacity\(this\.keyboardEditing\(\) \? 0 : 1\)/);
});

test('uses a greeting, opens discovery from the lead card, and removes the collaboration card', () => {
  const view = read('entry/src/main/ets/pages/A2uiHome/components/AiosNowHomeView.ets');
  assert.match(view,
    /AIOS_ACTIVITY_TITLES: string\[\] = \['不确定？随便刷刷', '基础对话', '出行方案规划', '周末聚餐'\]/);
  assert.match(view, /AIOS_ACTIVITY_PROMPTS: string\[\] = \['', '', '帮我规划一份出行方案'/);
  assert.match(view, /this\.greetingText = hour < 5 \? '夜深了'/);
  assert.match(view, /if \(index === 0\) \{\s*this\.onOpenWaterfall\(\)/s);
  assert.match(view, /if \(index === 1\) \{\s*this\.onOpenConversation\(\)/s);
  assert.match(view, /this\.ActivityCard\(3\)/);
  assert.match(view, /Text\('为你混合推荐'\)/);
  assert.match(view, /Text\('不知道看什么，就从这里开始'\)/);
  assert.match(view, /Text\('直接开始对话'\)/);
  assert.match(view, /this\.AttentionEmptyState\(\)/);
  assert.doesNotMatch(view, /Text\('上海出差'\)/);
  assert.doesNotMatch(view, /Text\(index === 0 \? '上海出差' : 'AIOS 协作'\)/);
  assert.doesNotMatch(view, /this\.AttentionCard\(1\)/);
});

test('uses a home affordance in conversation and opens a ready basic chat from the guide card', () => {
  const homePage = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  const index = read('entry/src/main/ets/pages/A2uiHome/Index.ets');
  assert.match(homePage, /icon: \$r\('app\.media\.icon_home'\)/);
  assert.match(homePage, /A2UI_HOME_SEND_ACTIVE_BACKGROUND: string = '#17191D'/);
  assert.match(homePage, /A2UI_HOME_SEND_SHADOW: string = '#42000000'/);
  assert.doesNotMatch(homePage, /icon: \$r\('app\.media\.icon_reset'\)/);
  assert.match(index, /private openBasicConversation\(\): void/);
  assert.match(index, /this\.appendMessage\('assistant', '你好，有什么我可以帮你的吗？'\)/);
  assert.match(index, /createTurnConversationSurface\(this\.runtimeGeneration\)/);
  assert.match(index, /onOpenConversation:[\s\S]*?this\.openBasicConversation\(\)/);
});

test('uses the original prototype visual assets directly from rawfile', () => {
  const view = read('entry/src/main/ets/pages/A2uiHome/components/AiosNowHomeView.ets');
  assert.match(view, /wallpapers\/now-blue\.png/);
  assert.match(view, /daily\/discovery-video-fallback\.jpeg/);
  assert.match(view, /activity\/shanghai\/travel-itinerary\.png/);
  assert.match(view, /activity\/weekend-dinner\/restaurant\.png/);
  assert.doesNotMatch(view, /profile\/lin-crocodile\.png/);
});

test('lets travel and dining result pages own the full viewport behind the native composer', () => {
  const homePage = read('entry/src/main/ets/pages/A2uiHome/components/HomePage.ets');
  assert.match(homePage, /export function isImmersiveResultHtml/);
  assert.match(homePage, /html\.indexOf\('itinerary-shell'\) >= 0/);
  assert.match(homePage, /html\.indexOf\('editorial-food-shell'\) >= 0/);
  assert.match(homePage, /!this\.useImmersiveResultSurface\(\)/);
  assert.match(homePage, /\['#B9D3FF', 0\]/);
  assert.match(homePage, /\['#FFECD5', 0\]/);
});
