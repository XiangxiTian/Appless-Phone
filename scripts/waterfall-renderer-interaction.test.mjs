import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const renderer = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets', import.meta.url),
  'utf8'
);
const surfaceView = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/components/HtmlHomeSurfaceView.ets', import.meta.url),
  'utf8'
);
const homePage = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/components/HomePage.ets', import.meta.url),
  'utf8'
);
const voiceDock = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/components/WaterfallVoiceDock.ets', import.meta.url),
  'utf8'
);
const indexPage = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url),
  'utf8'
);
const canaryRuntime = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets', import.meta.url),
  'utf8'
);
const leaderPlanner = readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner.ets', import.meta.url),
  'utf8'
);
const waterfallCore = readFileSync(
  new URL('../agent_core/src/main/ets/aiphone/runtime/WaterfallAnythingCore.ets', import.meta.url),
  'utf8'
);
const toolGateway = readFileSync(
  new URL('../agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets', import.meta.url),
  'utf8'
);
const entryAbility = readFileSync(
  new URL('../entry/src/main/ets/entryability/EntryAbility.ets', import.meta.url),
  'utf8'
);
const appScope = readFileSync(
  new URL('../AppScope/app.json5', import.meta.url),
  'utf8'
);
const cnnewsLogo = readFileSync(
  new URL('../entry/src/main/resources/base/media/logo_cnnews.svg', import.meta.url),
  'utf8'
);
const steamLogo = readFileSync(
  new URL('../entry/src/main/resources/base/media/logo_steam.svg', import.meta.url),
  'utf8'
);

function template(name) {
  const marker = `const ${name}: string = \``;
  const start = renderer.indexOf(marker);
  assert.notEqual(start, -1, `${name} template is missing`);
  const contentStart = start + marker.length;
  const end = renderer.indexOf('\n`;', contentStart);
  assert.notEqual(end, -1, `${name} template is unterminated`);
  return renderer.slice(contentStart, end);
}

const aggregateCss = template('AGGREGATE_CSS');
const aggregateJs = template('AGGREGATE_JS');
const waterfallCss = template('WATERFALL_CSS');
const waterfallJs = template('WATERFALL_JS');
const sourceLabelsJson = JSON.stringify([
  { source: 'youtube', label: 'YouTube' },
  { source: 'bilibili', label: 'B 站' },
  { source: 'applepodcasts', label: 'Apple Podcasts' },
  { source: 'twitch', label: 'Twitch' },
  { source: 'github', label: 'GitHub' },
  { source: 'steam', label: 'Steam' },
  { source: 'cnnews', label: 'CNNews' },
  { source: 'globalnews', label: 'GlobalNews' }
]);
const sourceOnlyJson = JSON.stringify(['applepodcasts', 'twitch']);
const searchSourcesJson = JSON.stringify([
  'youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu', 'applepodcasts', 'twitch',
  'github', 'steam', 'cnnews', 'globalnews'
]);
const interestSourcesJson = JSON.stringify([
  'youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu', 'applepodcasts', 'twitch',
  'github', 'steam', 'cnnews', 'globalnews'
]);
assert.deepEqual(JSON.parse(searchSourcesJson), [
  'youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu', 'applepodcasts', 'twitch',
  'github', 'steam', 'cnnews', 'globalnews'
]);
assert.deepEqual(JSON.parse(searchSourcesJson), JSON.parse(interestSourcesJson));
assert.deepEqual(JSON.parse(interestSourcesJson), [
  'youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu', 'applepodcasts', 'twitch',
  'github', 'steam', 'cnnews', 'globalnews'
]);
assert.doesNotMatch(cnnewsLogo, /<image|data:image\/png/,
  'the grouped CNNews mark must stay vector-only so ArkWeb cannot show broken nested images');
assert.doesNotMatch(steamLogo, /<image|data:image\/png/,
  'the Steam mark must stay vector-only');
const waterfallTemplateWithRegistry = waterfallJs
  .split('${WATERFALL_SOURCE_LABELS_JSON}').join(sourceLabelsJson)
  .split('${WATERFALL_SOURCE_ONLY_SOURCES_JSON}').join(sourceOnlyJson)
  .split('${WATERFALL_SEARCH_SOURCE_IDS_JSON}').join(searchSourcesJson)
  .split('${WATERFALL_INTEREST_SOURCE_IDS_JSON}').join(interestSourcesJson);
const emittedWaterfallJs = Function('return `' + waterfallTemplateWithRegistry + '`;')();
assert.doesNotThrow(() => new vm.Script(emittedWaterfallJs));
const aggregatePostMediaSource = renderer.slice(
  renderer.indexOf('function renderPostMedia'),
  renderer.indexOf('function renderPostLink')
);
assert.match(aggregatePostMediaSource, /class="aggregate-post-media"[^>]*onerror="this\.hidden=true"/,
  'failed remote post media such as Reddit CDN images must not expose a broken image');
const reducedMotionCss = waterfallCss.slice(waterfallCss.lastIndexOf('@media (prefers-reduced-motion: reduce)'));
assert.match(indexPage, /@State interestWaterfallFullscreen:\s*boolean\s*=\s*false/,
  'search and interest Waterfall surfaces must not overwrite one shared fullscreen flag');
assert.match(indexPage, /\.disableSwipe\(this\.bimRootIndex === 1\s*\|\|\s*this\.waterfallFullscreen\)/,
  'the discovery page must keep the root Swiper locked so reader close does not relayout both pages');
assert.doesNotMatch(indexPage, /\.disableSwipe\(false\)/,
  'the native root Swiper must not stay swipeable while Waterfall is fullscreen');
assert.doesNotMatch(indexPage,
  /\.disableSwipe\(this\.waterfallFullscreen\s*\|\|\s*this\.interestWaterfallFullscreen\)/,
  'reader fullscreen must not toggle the native Swiper on every open and close');
assert.doesNotMatch(indexPage, /onWaterfallFullscreenChange:\s*\(_active:\s*boolean\):\s*void\s*=>\s*\{\}/,
  'both Waterfall surfaces must report fullscreen state so the native root Swiper cannot steal gestures');
assert.match(indexPage, /WaterfallVoiceDock\(\{/,
  'the one voice entry must exist only on the main independent discovery layer');
assert.doesNotMatch(indexPage, /if \(!this\.interestWaterfallFullscreen\)\s*\{\s*WaterfallVoiceDock/s,
  'returning to the feed must not remount the voice dock over the WebView');
assert.doesNotMatch(indexPage,
  /WaterfallVoiceDock\([\s\S]*?Visibility\.Hidden/,
  'Visibility.Hidden still relayouts the WebView stack when the dock returns');
assert.doesNotMatch(indexPage,
  /WaterfallVoiceDock\([\s\S]*?\.opacity\(this\.interestWaterfallFullscreen/,
  'opacity 0 still leaves a native layer on top of the reader WebView');
assert.match(indexPage,
  /HtmlHomeSurfaceView\([\s\S]*?\.zIndex\(1\)/,
  'the WebView must stay above a lowered dock so reading is not composited under a native overlay');
assert.match(indexPage,
  /interestWaterfallFullscreen \? 0 : 2/,
  'fullscreen tucks the already-mounted dock behind the WebView instead of covering it');
assert.match(indexPage, /startVoiceInput\('waterfall'\)/,
  'the discovery dock must reuse ASR through its independent target');
assert.match(entryAbility, /waterfallConversationPrompt/,
  'typed device probes must enter through a bounded debug-only ability parameter');
assert.match(indexPage, /!this\.isDebugBuild[\s\S]*reason=invalid_debug_prompt/,
  'typed conversation probes must be rejected outside debug builds');
assert.match(indexPage, /submitWaterfallConversation\(prompt\)/,
  'typed probes must reuse the exact post-recognition conversation path');
assert.doesNotMatch(indexPage, /setWebDebuggingAccess/,
  'typed probes must not expose ArkWeb debugging');
assert.match(indexPage, /requestSequences\.get\(source\) !== this\.interestSourceRequestSeq\.get\(source\)/,
  'a stale per-source discovery response must not overwrite a newer refill');
assert.match(indexPage, /plannedSources\.indexOf\(source\) < 0/,
  're-enabling a source must not start a fresh recall when continuation is already planned');
assert.match(indexPage, /WaterfallInterestRecallBatch[\s\S]*result\.request\.query/,
  'each discovery source must log route, query, and whether it returned cards');
assert.doesNotMatch(indexPage, /waitingForInitialPeers/,
  'the first source with cards must paint immediately instead of waiting for slower peers');
assert.doesNotMatch(waterfallJs, /function interleaveBySource/,
  'feed order must follow native ranking instead of a renderer round-robin');
assert.match(waterfallJs, /function renderedOrderCandidates\(payload\) \{\s*return candidates\(payload\)\.filter/,
  'the renderer must paint payload order after filtering disabled sources');
assert.match(waterfallJs, /insertAdjacentHTML\('beforebegin'/,
  'late source cards must slot in without rebuilding the visible card');
assert.match(toolGateway, /source === 'zhihu' \|\| source === 'bilibili'/,
  'local discovery sources must start before YouTube/Composio can occupy the HTTP pool');
assert.match(waterfallCore, /WATERFALL_WESTERN_EXPLORATION_QUERIES/,
  'X / HN / Reddit must not search Chinese exploration queries');
assert.match(waterfallCore, /'人工智能', '科技数码', '编程开发', '科学科普'/,
  'Chinese discovery sources must search tech queries, not leaked profile tokens');
assert.doesNotMatch(waterfallCore, /影视文化|生活灵感|运动赛事/,
  'discovery exploration must not keep lifestyle and entertainment filler queries');
assert.match(indexPage, /waterfallAdvanceVisibleFromAction/,
  'native advance must accept the visible card, not only the stale current pointer');
assert.match(indexPage,
  /action\.id === 'waterfall\.comments\.load'[\s\S]*?this\.waterfallActionCandidate\(/,
  'saved-only details must resolve comment requests through the existing saved-card candidate path');
assert.match(indexPage, /persistSavedWaterfallCandidate\(current\)/,
  'loaded comments must refresh an existing saved-card snapshot');
assert.match(indexPage, /if \(active > 8\) return/,
  'discovery refill must start before the user can swipe through the last three cards');
assert.match(waterfallCore, /WATERFALL_LOW_WATERMARK: number = 3/,
  'native inventory must refill before the rendered tail is exhausted');
assert.match(waterfallCore, /function limitConsecutiveSources/,
  'a later source must break a same-source run after the frozen window');
assert.match(waterfallCore, /targetId: string = ''/,
  'one advance may catch the feed pointer up to the visible card');
const mergePayloadSource = waterfallJs.slice(
  waterfallJs.indexOf('function mergePayload'),
  waterfallJs.indexOf('function postSourceSelection')
);
assert.match(mergePayloadSource, /advancePending = false;/,
  'a payload that does not move currentId must still unblock the next catch-up');
assert.doesNotMatch(mergePayloadSource, /oldCurrentId !== text\(payload\.currentId\)\) advancePending = false/,
  'holding advancePending until currentId changes deadlocks after a stale no-op');
const fullscreenExpression = surfaceView.match(
  /export function waterfallLayerFullscreen\([^)]*\): boolean \{\s*return ([^;]+);\s*\}/
);
assert.ok(fullscreenExpression,
  'Waterfall fullscreen reporting must combine renderer and native popup layers');
const waterfallLayerFullscreen = Function(
  'rendererFullscreen', 'popupVisible', 'return ' + fullscreenExpression[1]
);
assert.equal(waterfallLayerFullscreen(false, false), false);
assert.equal(waterfallLayerFullscreen(true, false), true);
assert.equal(waterfallLayerFullscreen(false, true), true,
  'closing a source popup must not expose the dock while the reader remains open');
assert.equal(waterfallLayerFullscreen(true, true), true);
assert.match(surfaceView,
  /this\.onWaterfallFullscreenChange\(waterfallLayerFullscreen\(\s*this\.rendererWaterfallFullscreen,\s*this\.popupVisible\s*\)\)/s,
  'SurfaceView must report the combined layer state instead of the last callback');
assert.match(voiceDock, /按住聊聊/);
assert.doesNotMatch(voiceDock, /按住说想看的内容/,
  'the discovery voice entry must read like a light tool, not a full chat composer');
assert.doesNotMatch(voiceDock, /\.width\('100%'\)/,
  'the single voice entry must not occupy the full feed width');
assert.doesNotMatch(voiceDock, /\.width\(216\)|\.height\(46\)/,
  'the voice control must be a round button, not a composer-like bar');
assert.match(voiceDock, /\.width\(48\)[\s\S]*\.height\(48\)/,
  'the voice control needs a quiet 48px touch target, not a dominant floating action button');
assert.match(voiceDock, /\.borderRadius\(24\)/,
  'the voice control must be a circle, not a pill input');
assert.match(voiceDock, /private fillColor\(\): string \{[\s\S]*?return COLOR_CARD;\s*\}/,
  'idle fill must recede into the card surface instead of painting a solid accent disc');
assert.doesNotMatch(voiceDock, /private fillColor\(\): string \{[^}]*return COLOR_ACCENT;/,
  'the idle mic must not compete with the active discovery card');
assert.doesNotMatch(indexPage, /Row\(\) \{\s*WaterfallVoiceDock/,
  'the voice control must overlay the feed instead of consuming a chrome row');
assert.match(indexPage, /Stack\(\{\s*alignContent:\s*Alignment\.Bottom\s*\}\)\s*\{\s*Image\(\$r\('app\.media\.home_light_aurora_background'\)\)[\s\S]*?HtmlHomeSurfaceView[\s\S]*?WaterfallVoiceDock/s,
  'the independent discovery page must reuse the home aurora and pin the round voice button to the feed');
  assert.match(voiceDock, /this\.pressed \? 0\.96 : 1/,
  'the voice entry needs immediate tactile press feedback');
assert.match(voiceDock, /shouldStop = this\.pressed \|\| this\.isListening/,
  'releasing a fast press must stop ASR even before the parent prop catches up');
assert.match(voiceDock, /from '\.\.\/style\/A2uiHomeTheme'/,
  'the independent voice dock must use the same theme source as the home composer');
for (const token of ['COLOR_ACCENT', 'COLOR_ACCENT_DEEP', 'COLOR_ACCENT_SOFT', 'COLOR_CARD',
  'COLOR_CARD_EDGE', 'COLOR_CARD_SHADOW', 'COLOR_MUTED']) {
  assert.match(voiceDock, new RegExp(`\\b${token}\\b`), `voice dock must use ${token}`);
}
assert.doesNotMatch(voiceDock, /COLOR_GLASS/,
  'translucent glass over the warm paper stains the mic button yellow');
assert.doesNotMatch(voiceDock, /#252522|#E9E8E3|#F8F7F3|#DAD9D3/,
  'the discovery voice dock must not introduce a separate black and gray palette');
assert.match(voiceDock, /\.opacity\(this\.isBusy \? 0\.72 : 1\)/,
  'busy voice text must retain readable contrast on the warm surface');
assert.match(waterfallJs, /if \(directDiscovery\) setFullscreen\(true\)/,
  'reader, source sheet, and video detail must hide the independent voice dock');
assert.match(waterfallJs, /if \(directDiscovery\) setFullscreen\(false\)/,
  'returning to the discovery feed must restore the voice dock');
assert.match(aggregateCss, /\.aggregate-status-sheet-summary/);
assert.match(aggregateCss, /\.aggregate-status-sheet/);
assert.match(aggregateCss, /\.aggregate-status-card > summary\s*\{[^}]*border:\s*0/s);
assert.match(aggregateJs, /data-status-close/);
assert.match(waterfallCss, /\.waterfall-entry-floating/);
assert.match(waterfallCss, /\.waterfall-cinema-card/);
assert.match(waterfallCss, /\.waterfall-toolbar-primary/);
assert.match(waterfallCss, /\.waterfall-toolbar-tools/);
assert.match(waterfallCss, /\.waterfall-source-logo/);
assert.match(waterfallCss, /\.waterfall-media-cover/);
assert.match(waterfallCss, /\.waterfall-media-frame/);
assert.match(waterfallCss, /\.waterfall-card--video/);
assert.match(waterfallCss, /\.waterfall-card--portrait/);
assert.match(waterfallCss, /\.waterfall-card--image-text/);
assert.match(waterfallCss, /\.waterfall-card--text/);
assert.match(waterfallCss, /\.waterfall-card--video-fullscreen/);
assert.match(waterfallCss, /\.waterfall-card-shell\s*\{/);
assert.match(waterfallCss, /\.waterfall-card-shell\s*\{[^}]*cursor:\s*default/s,
  'source-only cards must not advertise a whole-card action');
assert.match(waterfallCss, /\.waterfall-card-shell--interactive\s*\{[^}]*cursor:\s*pointer/s,
  'only cards with a reader action may advertise whole-card interaction');
assert.match(waterfallCss,
  /\.waterfall-card-shell,\s*\.waterfall-card-shell \*\s*\{[^}]*-webkit-tap-highlight-color:\s*transparent[^}]*-webkit-user-select:\s*none[^}]*user-select:\s*none/s,
  'card shells must suppress ArkWeb tap flashes and transient text selection');
assert.match(waterfallCss,
  /\.waterfall-card-shell--interactive:active,\s*\.waterfall-card-shell--interactive\.is-pressed\s*\{[^}]*scale\(0\.992\)/s,
  'whole-card press scaling must be limited to interactive cards');
assert.doesNotMatch(waterfallCss, /\.waterfall-card-shell:active\s*\{/,
  'source-only card shells must not shrink on touch');
assert.doesNotMatch(waterfallCss, /\.waterfall-card-ambient/);
assert.doesNotMatch(waterfallCss, /\.waterfall-card-shell\s*\{[^}]*height:\s*min\(70dvh/s);
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-align:\s*center/s,
  'the settled card must stay in the visual center instead of sticking to the page top');
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*height:\s*100dvh/s);
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*height:\s*76dvh/s,
  'cards must size to their format, not a forced viewport slot');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*height:\s*auto[^}]*min-height:\s*0[^}]*margin:\s*0 auto 28px/s,
  'landscape, portrait, image-text, and text cards keep their own height');
assert.match(waterfallCss,
  /\.waterfall-card-shell\s*\{[^}]*height:\s*auto[^}]*min-height:\s*0[^}]*margin:\s*0 14px/s,
  'the white card surface must hug content instead of filling a page slot');
assert.match(waterfallCss,
  /\.waterfall-card--video\.waterfall-card--landscape \.waterfall-cinema-stage\s*\{[^}]*max-height:\s*min\(38dvh, 330px\)/s,
  'landscape video cards keep the 16:9 stage');
assert.match(waterfallCss,
  /\.waterfall-card--video\.waterfall-card--portrait \.waterfall-cinema-stage\s*\{[^}]*width:\s*min\(68%, 270px\)[^}]*max-height:\s*min\(49dvh, 440px\)/s,
  'portrait video cards keep the 9:16 stage');
assert.match(waterfallCss,
  /\.waterfall-card--image-text \.waterfall-cinema-stage\s*\{[^}]*height:\s*min\(40dvh, 360px\)/s);
assert.match(waterfallCss,
  /\.waterfall-card--text \.waterfall-card-shell\s*\{[^}]*min-height:\s*min\(44dvh, 420px\)[^}]*padding:\s*22px/s);
assert.doesNotMatch(waterfallCss, /padding-top:\s*22vh/,
  'a 22vh track pad is the empty band above the first card');
assert.doesNotMatch(waterfallCss, /padding-top:\s*12dvh/,
  'a 12dvh empty band above the first card is not the toolbar inset');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*contain:\s*layout(?!\s+paint)/s,
  'card layout isolation must not clip the shadow into a horizontal line');
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*contain:[^;}]*paint/s);
assert.match(waterfallCss, /\.waterfall-icon svg\s*\{/);
assert.doesNotMatch(waterfallCss, /\.waterfall-top-hotzone\s*\{/);
assert.doesNotMatch(waterfallJs, /data-waterfall-top-hotzone/);
assert.match(waterfallCss, /\.waterfall-toolbar\s*\{[^}]*opacity:\s*1/s);
assert.match(waterfallCss, /\.waterfall-toolbar\s*\{[^}]*left:\s*0[^}]*right:\s*0[^}]*background:\s*linear-gradient/s,
  'discovery chrome must fade into the feed instead of sitting on a solid strip');
assert.match(waterfallCss,
  /\.waterfall-toolbar\s*\{[^}]*grid-template-columns:\s*1fr auto 1fr/s,
  'the fixed search title must stay centered between the back action and toolbar tools');
assert.match(waterfallCss, /\.waterfall-toolbar-label\s*\{[^}]*white-space:\s*nowrap/s,
  'the compact back label must never wrap onto two lines');
assert.match(waterfallCss, /\.waterfall-toolbar button,[^}]*\.waterfall-toolbar-title\s*\{[^}]*border:\s*0[^}]*box-shadow:\s*none/s,
  'persistent top-bar controls must not keep floating button surfaces');
assert.match(waterfallJs, /data-waterfall-open/);
assert.ok(
  waterfallJs.indexOf('window.__aiphoneApplyWaterfallUpdate = function') <
    waterfallJs.indexOf("track.addEventListener('scroll'"),
  'the native update bridge must exist before UI listener setup can abort'
);
assert.doesNotMatch(waterfallJs, />阅读全文</);
assert.match(waterfallJs, /class="waterfall-source-action"[^>]*aria-label="查看来源"/);
assert.match(waterfallJs, /data-waterfall-card-action=/,
  'feed and detail cards must expose the same product reaction controls');
assert.match(waterfallJs, /id: 'waterfall\.card\.action'/,
  'reaction controls must use the bounded native action bridge');
assert.match(waterfallJs, /function renderCollection/,
  'manual saves need one dedicated collection view');
assert.match(waterfallCss, /\.waterfall-card-action\s*\{[^}]*width:\s*44px[^}]*height:\s*44px/s,
  'compact icons must keep a 44px accessible hit target');
assert.match(waterfallCss, /\.waterfall-card-action \.waterfall-icon\s*\{[^}]*width:\s*32px[^}]*height:\s*32px/s,
  'the visible selected surface must stay quieter than the hit target');
assert.match(waterfallCss, /\.waterfall-card-action \.waterfall-icon svg\s*\{[^}]*width:\s*19px[^}]*height:\s*19px/s,
  'card actions must not compete with card content');
assert.match(renderer, /data-waterfall-collection-open/,
  'the discovery toolbar needs an icon-only collection entry');
assert.match(renderer, /data-waterfall-search-open/,
  'direct discovery needs one explicit search entry in its existing toolbar');
assert.match(renderer, /id="waterfall-search-form"/,
  'search must expand in the discovery toolbar instead of opening another page');
assert.match(renderer, /id="waterfall-toolbar-title"/,
  'the persistent discovery title must expose one stateful search indicator');
assert.match(waterfallJs, /function syncSearchTitle\(\)[\s\S]*?searchActive && searchSubmitted \? '搜索' : '发现'[\s\S]*?waterfallToolbarTitle\.textContent/,
  'submitted results must identify search without clipping a repeated keyword in the toolbar');
assert.match(waterfallJs,
  /waterfallBack\.setAttribute\('aria-label', searchActive && searchSubmitted \? '返回发现' : '返回首页'\)/,
  'the back action accessibility label must follow the visible search hierarchy');
assert.match(waterfallJs, /function closeSearchUi[\s\S]*?syncSearchTitle\(\)/,
  'leaving search must restore the discovery title before the feed is revealed');
assert.match(waterfallJs,
  /function syncSearchMode\(payload\)\s*\{\s*if \(!directDiscovery \|\| searchRestorePending \|\|/,
  'late search payloads must not reactivate search while Discovery is being restored');
assert.match(waterfallCss,
  /\.waterfall-toolbar\.is-searching[\s\S]*?\.waterfall-search-form[\s\S]*?transform:\s*none/,
  'the selected A interaction must morph the search field in place');
assert.match(waterfallJs, /id:\s*'waterfall\.search\.submit'/,
  'discovery search must use its bounded native action bridge');
assert.match(waterfallJs, /id:\s*'waterfall\.search\.exit'/,
  'the first back action in search results must restore discovery');
assert.match(canaryRuntime,
  /!focusedRelease \|\|[\s\S]*?definition\.toolId !== 'media\.aggregate\.search'/,
  'natural conversation must not advertise aggregate search in the focused release');
assert.match(leaderPlanner,
  /registeredCapability\(context, 'media\.aggregate\.search'\)[\s\S]*?Aggregate media search is discovery-only/,
  'the leader must not be prompted to invent the discovery-only search capability');
assert.match(waterfallJs, /searchFeedScrollTop/,
  'exiting search must restore the exact pre-search discovery position');
assert.match(waterfallJs, /searchInput\.blur\(\)/,
  'exiting search must release the web input focus before returning home');
assert.match(indexPage,
  /\.onChange\(\(index: number\)[\s\S]*?index === 1[\s\S]*?else inputMethod\.getController\(\)\.hideTextInput\(\)/,
  'returning home must dismiss a keyboard opened by discovery search');
assert.match(indexPage,
  /actionId\.length === 0 && sourceBimId\.length === 0 \?\s*waterfallSearchQueryForHomePrompt\(trimmed\)[\s\S]*?appendMessage\('user', visibleText\)[\s\S]*?ensureInterestWaterfall\(false\)[\s\S]*?startInterestWaterfallSearch\([\s\S]*?bimRootController\.changeIndex\(1/,
  'only Home aggregate intents may preserve the user turn and route directly into Waterfall search');
assert.match(indexPage,
  /if \(document\.kind !== 'aggregate-search'\) \{[\s\S]*?return document;[\s\S]*?return createHtmlHomeDocument\(\{[\s\S]*?messages: this\.messages/,
  'a persisted legacy aggregate surface must fall back to the normal home without deleting conversation history');
assert.match(waterfallJs, /searchPending[\s\S]*?payload[\s\S]*?candidates\.length === 0/,
  'an empty pending payload must leave the current discovery card mounted');
const searchCompletionSource = waterfallJs.slice(
  waterfallJs.indexOf('if (searchActive && searchPending'),
  waterfallJs.indexOf('pendingPayload = payloadAfterCardAction')
);
assert.match(searchCompletionSource, /searchInput\.blur\(\)/,
  'completed search must dismiss its text input focus');
assert.match(searchCompletionSource, /toolbar\.classList\.remove\('is-searching'\)/,
  'completed search must restore collection and source controls');
const openSearchSource = waterfallJs.slice(
  waterfallJs.indexOf('function openSearch'),
  waterfallJs.indexOf('function submitSearch')
);
assert.doesNotMatch(openSearchSource, /if \(!directDiscovery \|\| searchActive/,
  'the restored search control must reopen for query refinement');
const directDiscoveryUpdateSource = indexPage.slice(
  indexPage.indexOf('private applyInterestWaterfallUpdate'),
  indexPage.indexOf('private runNextInterestExplorationIfNeeded')
);
assert.match(directDiscoveryUpdateSource,
  /update\.expansionRequest !== undefined[\s\S]*?runInterestWaterfallExpansion/,
  'discovery search must execute query expansion when continuation planning requests it');
const exitDiscoverySearchSource = indexPage.slice(
  indexPage.indexOf('private exitInterestWaterfallSearch'),
  indexPage.indexOf('private ensureInterestWaterfall')
);
assert.match(exitDiscoverySearchSource,
  /waterfallPreferenceProfile\.discoveryEnabledSources[\s\S]*?applyWaterfallSourceSelection/,
  'Back from search results must reconcile the discovery snapshot with saved source changes');
assert.match(renderer, /id="waterfall-collection"/,
  'the collection must stay inside the existing ArkWeb shell');
assert.match(waterfallJs, /function readerParagraphs/,
  'long detail copy needs conservative paragraph normalization');
assert.doesNotMatch(toolGateway,
  /recall\.route === 'popular' && allowedSources\.indexOf\('zhihu'\)/,
  'Zhihu discovery must use the shared search path that returns likes and comments');
assert.match(waterfallJs, /function playCardActionFeedback/,
  'like and save need one reusable, interruptible feedback motion');
assert.match(waterfallJs, /Math\.min\(4,/,
  'card-action particles must stay capped at four');
assert.match(waterfallJs, /function renderSourceConvergence/,
  'first discovery load must visualize real source convergence');
assert.match(homePage, /struct PageStateIndicator/,
  'home needs one non-clickable status indicator above the composer');
assert.doesNotMatch(indexPage, /PageStateIndicator\s*\(\s*\{/,
  'the page indicator belongs only on home, never over discovery');
assert.match(indexPage, /geoLocationManager\.isLocationEnabled\(\)/,
  'location permission success must still detect a disabled system location service');
assert.match(homePage, /定位服务未开启，附近结果可能不够准确。/,
  'the disabled-location notice must stay contextual above the composer');
assert.match(waterfallJs, /waterfall-reader--image-text/);
assert.match(waterfallJs, /waterfall-reader--text/);
assert.match(waterfallJs, /waterfall-reader--video/);
assert.match(waterfallJs, /waterfall-reader-copy/);
assert.doesNotMatch(waterfallJs, /waterfall-reader-video-card/,
  'video, image-text, and text details must use the same reader structure');
assert.doesNotMatch(waterfallJs, /waterfall-reader-video-copy/,
  'detail copy must not fork into a video-only wrapper');
assert.match(waterfallJs, /requestAnimationFrame/);
assert.doesNotMatch(waterfallJs, /reader\.offsetWidth/,
  'opening details must not force a synchronous full-reader layout');
assert.match(waterfallJs, /addEventListener\('touchstart'/,
  'tap versus swipe must be decided from the touch gesture, not scroll timing');
assert.doesNotMatch(waterfallJs, /lastScrollAt/,
  'scroll timestamps misclassify both delayed synthetic clicks and deliberate taps');
assert.match(aggregateCss, /--ease-in-out:\s*cubic-bezier\(0\.77, 0, 0\.175, 1\)/);
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\s*\{[^}]*clip-path/s,
  'the reader shell must not use clip-path');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\s*\{[^}]*--reader-card/s,
  'the reader shell must not cache a card-sized transform');
assert.doesNotMatch(waterfallCss, /--reader-card-scale/,
  'ArkWeb cannot interpolate a CSS-variable scale into transform:none');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*opacity:\s*0\.14[^}]*scale\(0\.955\)/s,
  'distant cards stay dimmer than the current card');
assert.match(waterfallCss, /\.waterfall-card\.is-adjacent\s*\{[^}]*opacity:\s*0\.42[^}]*scale\(0\.975\)/s,
  'the cards above and below the current card must read as adjacent, not fully faded');
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*translate3d\(0,\s*14px/s,
  'vertical card translation fights the paging scroll');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*transition:\s*opacity 120ms var\(--ease-out\), transform 140ms var\(--ease-out\)/s,
  'class changes need a short settle, not a long trailing scale');
assert.match(waterfallCss, /\.waterfall-card\.is-active,[\s\S]*?transform:\s*none/s,
  'the current card must drop ancestor transforms so in-card iframes can play');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader-hotzone\s*\{/);
assert.doesNotMatch(waterfallJs, /data-waterfall-reader-hotzone/);
assert.match(waterfallCss, /\.waterfall-reader-head\s*\{[^}]*opacity:\s*1/s);
assert.match(waterfallCss, /\.waterfall-reader-head\s*\{[^}]*left:\s*0[^}]*right:\s*0[^}]*background:\s*#eef0f2[^}]*border-bottom:/s,
  'detail controls must stay in an opaque persistent top bar while content scrolls');
assert.match(waterfallCss,
  /\.waterfall-reader-signals\s*\{[^}]*grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)/s,
  'seven detail metrics must fit in two rows at normal phone widths');
assert.match(waterfallCss,
  /@media \(max-width:\s*360px\)[\s\S]*?\.waterfall-reader-signals\s*\{[^}]*grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)/,
  'very narrow detail views must keep metrics within three rows');
assert.match(waterfallCss, /\.waterfall-reader\.active\.closing\s*\{[^}]*pointer-events:\s*auto/s,
  'the closing reader must keep the leftover press until it is actually hidden');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\.active\.closing \.waterfall-reader-body\s*\{[^}]*opacity:\s*0/s,
  'the detail body must remain visible for the shared-card return animation');
assert.match(waterfallCss, /\.waterfall-edge-fade--bottom\s*\{[^}]*bottom:\s*0/s,
  'the feed bottom must fade into the voice control instead of a hard chrome edge');
assert.match(waterfallCss,
  /\.waterfall-track\s*\{[^}]*padding:\s*calc\(64px \+ env\(safe-area-inset-top\) \+ 12px\) 0/s,
  'the first card must sit below the discovery toolbar, not a 12dvh empty band');
assert.doesNotMatch(waterfallCss, /padding-bottom:\s*18dvh/,
  'a viewport-sized bottom pad makes the feed feel empty and breaks the last snap');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-stop:\s*always/s,
  'discovery paging must stop on the next card like Douyin, not skip through a fling');
assert.match(appScope, /"bundleName"\s*:\s*"com\.jiuwen\.appless"/,
  'the only build target must be the canonical Appless bundle');
assert.doesNotMatch(appScope, /com\.example\.aiphonedemo/,
  'the historical example bundle must never return to the active build');
assert.doesNotMatch(waterfallJs, /function applyCardMotion/,
  'per-frame opacity writes stall ArkWeb; paging must stay on CSS snap and class transitions');
assert.match(waterfallJs, /return 'media'/,
  'video play must keep the user activation instead of canceling the tap');
assert.match(waterfallJs, /preferencesFeedScrollTop/,
  'closing source settings must restore the exact feed position');
assert.doesNotMatch(waterfallCss, /\.waterfall-card\.is-active \.waterfall-card-shell\s*\{/,
  'active-card shadow pulses make repeated fast swipes look like card refreshes');
assert.match(waterfallCss, /\.waterfall-overlay\s*\{[^}]*display:\s*none[^}]*background:\s*var\(--paper\)[^}]*opacity:\s*0/s);
assert.match(waterfallCss, /\.waterfall-overlay\.active\s*\{[^}]*display:\s*block[^}]*opacity:\s*1[^}]*animation:\s*waterfall-overlay-in 180ms var\(--ease-out\) both/s);
assert.match(waterfallCss, /\.waterfall-overlay\.active\.closing\s*\{[^}]*opacity:\s*0[^}]*animation:\s*none[^}]*transition:\s*opacity 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-track\s*\{[^}]*background:\s*#eef0f2/s);
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*background:\s*transparent/s);
assert.match(waterfallCss, /\.waterfall-card--text\s*\{[^}]*background:\s*transparent/s);
assert.match(waterfallCss, /\.waterfall-cinema-copy\s*\{[^}]*overflow:\s*hidden/s);
assert.match(waterfallCss, /\n\.waterfall-cinema-copy\s*\{[^}]*display:\s*flex[^}]*flex-direction:\s*column/s);
assert.match(waterfallCss, /\n\.waterfall-copy-actions\s*\{[^}]*margin-top:\s*auto/s);
assert.match(waterfallCss, /\.waterfall-reader-body\s*\{[^}]*overflow-y:\s*auto/s);
assert.match(waterfallCss,
  /\.waterfall-reader-signal b\s*\{[^}]*grid-column:\s*2[^}]*grid-row:\s*1[^}]*overflow-wrap:\s*anywhere/s,
  'detail metrics must use the value column and wrap instead of truncating');
assert.match(waterfallCss,
  /\.waterfall-reader-source \.waterfall-author-name\s*\{[^}]*max-width:\s*none[^}]*overflow:\s*visible[^}]*text-overflow:\s*clip[^}]*white-space:\s*normal/s,
  'detail author data must wrap instead of inheriting card ellipsis');
assert.match(waterfallCss,
  /@media \(max-width:\s*480px\)[\s\S]*?\.waterfall-reader-context\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)[^}]*gap:\s*6px/s,
  'phone details must place metadata on full-width rows instead of squeezing source, author, and date together');
assert.match(waterfallCss, /\.waterfall-reader\s*\{[^}]*opacity:\s*0[^}]*scale\(0\.985\)[^}]*transform-origin:\s*center[^}]*transform 180ms var\(--ease-out\)/s,
  'opening details uses a short center fade, not a full-screen scale from the card');
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*opacity:\s*1[^}]*transform:\s*none/s,
  'the open detail view must drop its transform so the Bilibili iframe can play');
assert.match(waterfallCss, /\.waterfall-reader\.active\.closing\s*\{[^}]*opacity:\s*0[^}]*scale\(0\.99\)/s,
  'returning must ease back into the feed instead of cutting');
assert.match(waterfallCss, /\n\.waterfall-reader-layout \{ width: min\(100%, 640px\); margin: 0 auto; \}/,
  'the long scrolling detail content must not remain transformed');
assert.match(waterfallCss, /\.waterfall-media-frame\s*\{[^}]*pointer-events:\s*auto/s);
assert.match(waterfallCss, /\.waterfall-inline-play\s*\{[^}]*min-height:\s*48px/s);
assert.match(waterfallCss, /\.waterfall-inline-play\[hidden\]\s*\{[^}]*display:\s*none/s);
assert.match(waterfallCss, /\.waterfall-inline-audio\s*\{[^}]*top:\s*50%[^}]*bottom:\s*auto[^}]*transform:\s*translateY\(-50%\)[^}]*min-height:\s*48px/s);
assert.match(waterfallCss, /\.waterfall-card--inline-twitch \.waterfall-inline-media-frame\s*\{[^}]*width:\s*100%[^}]*min-width:\s*0[^}]*min-height:\s*300px/s);
assert.match(waterfallCss, /\.waterfall-empty button, \.waterfall-status button\s*\{[^}]*min-height:\s*48px/s);
assert.match(waterfallCss, /\.waterfall-status--empty\s*\{[^}]*min-height:\s*calc\(100dvh - 150px\)[^}]*display:\s*grid/s);
assert.match(aggregateCss, /--ease-out:\s*cubic-bezier\(0\.23, 1, 0\.32, 1\)/);
assert.match(aggregateCss, /--ease-drawer:\s*cubic-bezier\(0\.32, 0\.72, 0, 1\)/);
assert.match(waterfallCss, /\.waterfall-reader\s*\{[^}]*visibility:\s*hidden[^}]*visibility 0s linear 180ms/s);
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*transition-delay:\s*0s/s);
const videoPlayCss = waterfallCss.slice(
  waterfallCss.indexOf('\n.waterfall-reader-video-play {'),
  waterfallCss.indexOf('\n.waterfall-reader-video-stage.is-playing')
);
assert.match(videoPlayCss, /background:\s*transparent/,
  'the play affordance must not tint the whole poster');
assert.match(videoPlayCss, /width:\s*44px[^}]*background:\s*rgba\(24, 28, 32, 0\.52\)/s,
  'the play affordance must be a quiet neutral control instead of a large colored badge');
assert.match(videoPlayCss, /\.waterfall-reader-video-play span\s*\{\s*display:\s*none/,
  'the visible play label must not compete with the video poster');
assert.doesNotMatch(videoPlayCss, /125, 75, 59/,
  'the video play affordance must not use the brown accent');
assert.doesNotMatch(waterfallJs, /querySelector\('\[data-waterfall-reader-close\]'\)/,
  'reopening a card must not stack another tap binder on the close button');
assert.match(waterfallCss,
  /\.waterfall-preferences\s*\{[^}]*transform:\s*translate3d\(0, 24px, 0\)[^}]*opacity:\s*0/s,
  'the source sheet must enter with a short slide and fade');
assert.match(waterfallCss,
  /\.waterfall-preferences\s*\{[^}]*border:\s*1px solid rgba\(255, 255, 255, 0\.72\)[^}]*background:\s*linear-gradient\(145deg, rgba\(255, 255, 255, 0\.68\), rgba\(243, 240, 236, 0\.54\)\)[^}]*backdrop-filter:\s*blur\(38px\) saturate\(145%\) brightness\(1\.08\)/s,
  'source settings must keep the in-page glass material while suppressing feed text behind it');
assert.match(waterfallCss, /@media \(prefers-reduced-transparency: reduce\)[\s\S]*?\.waterfall-preferences\s*\{[^}]*backdrop-filter:\s*none/s,
  'the glass source sheet needs a legible reduced-transparency fallback');
assert.match(waterfallCss,
  /\.waterfall-preferences\.active\s*\{[^}]*transform:\s*translate3d\(0, 0, 0\)[^}]*transition-delay:\s*0s/s);
assert.match(waterfallCss,
  /\.waterfall-preferences:not\(\.active\),\s*\.waterfall-preferences:not\(\.active\) \*\s*\{[^}]*pointer-events:\s*none !important/s,
  'every descendant of the hidden source sheet must stop intercepting Twitch controls');
assert.match(waterfallCss,
  /\.waterfall-preferences:not\(\.active\)\s*\{[^}]*opacity 100ms var\(--ease-out\)[^}]*transform 100ms var\(--ease-out\)[^}]*visibility 0s linear 100ms !important/s,
  'closing source settings must keep one short visible motion without restoring the delayed close phase');
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle\s*\{[^}]*min-height:\s*44px[^}]*cursor:\s*pointer[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-cinema-card a, \.waterfall-read-button\s*\{[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-reader-head button\s*\{[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle:active,[^}]*\.waterfall-reader-head button:active\s*\{[^}]*transform:\s*scale\(0\.97\)/s);
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle:focus-visible,[^}]*outline:\s*2px solid var\(--accent\)/s);
assert.match(reducedMotionCss, /\.waterfall-preferences\s*\{[^}]*transform:\s*none[^}]*opacity 140ms var\(--ease-out\)[^}]*visibility 0s linear 140ms !important/s);
assert.match(reducedMotionCss, /\.waterfall-video-fullscreen-toggle,[^}]*\.waterfall-card-shell,[^}]*\{[^}]*opacity 140ms var\(--ease-out\)[^}]*background-color 140ms ease !important/s);
assert.match(reducedMotionCss,
  /\.waterfall-video-fullscreen-toggle:active,[^}]*\.waterfall-card-shell--interactive:active,[^}]*\.waterfall-card-shell--interactive\.is-pressed,[^}]*\{[^}]*transform:\s*none[^}]*opacity:\s*0\.82/s);
assert.match(reducedMotionCss, /\.waterfall-overlay\.active\s*\{[^}]*animation:\s*waterfall-overlay-in 140ms var\(--ease-out\) both !important/s);
assert.match(waterfallCss, /\.waterfall-cinema-card p\s*\{[^}]*-webkit-line-clamp:\s*3/s);
assert.match(waterfallCss, /\.waterfall-cinema-card h2\s*\{[^}]*-webkit-line-clamp:\s*4/s);
assert.match(waterfallCss, /\.waterfall-card--text h2\s*\{[^}]*-webkit-line-clamp:\s*6/s);
assert.match(waterfallCss,
  /\.waterfall-preferences label\s*\{[^}]*border:\s*0[^}]*border-bottom:\s*1px solid[^}]*border-radius:\s*0[^}]*background:\s*transparent/s,
  'source rows must stay compact and flat instead of becoming rounded cards');
assert.match(waterfallCss,
  /\.waterfall-source-name\s*\{[^}]*overflow:\s*visible[^}]*white-space:\s*normal/s,
  'source names must remain fully readable as the registry grows');
assert.match(waterfallJs, /sourceStateIsUnavailable[\s\S]*?needs_auth[\s\S]*?missing.*credential/i,
  'only definite unavailable sources may be disabled');
assert.doesNotMatch(renderer,
  /选择参与发现与搜索的来源|暂时失败的来源仍可使用|只有确定不可用的来源会被停用/,
  'the compact source sheet must not add an explanatory paragraph');
assert.doesNotMatch(waterfallCss, /\.waterfall-preferences > div:last-child > button/,
  'the source sheet must not end in an oversized full-width done button');
assert.match(waterfallCss, /\.waterfall-toolbar-secondary\s*\{[^}]*border:\s*0/s);
assert.match(waterfallCss, /touch-action:\s*manipulation/,
  'frequent Waterfall controls must opt out of delayed synthetic taps');
assert.match(waterfallJs, /function bindFastTap/,
  'Waterfall controls must share one delegated tap path');
const fastTapSource = waterfallJs.slice(
  waterfallJs.indexOf('function bindFastTap'),
  waterfallJs.indexOf('function setFullscreen')
);
assert.match(fastTapSource, /addEventListener\('touchend'/,
  'ArkWeb swallows click after nested scrolling, so controls must commit on touchend');
assert.match(fastTapSource, /addEventListener\('click'/,
  'click remains the mouse and fallback path after touchend');
assert.doesNotMatch(fastTapSource, /addEventListener\('(pointerdown|pointerup)'/,
  'pointerup races the native click and must not own the tap');
assert.doesNotMatch(waterfallJs, /function bindImmediateControl/,
  'a pointer-down close must not remove the detail layer while the same press is still active');
assert.doesNotMatch(waterfallCss, /\.waterfall-track\.(reader-open|sheet-open)/,
  'opening an overlay must not flip overflow on the snap scroller');
assert.match(waterfallCss,
  /\.waterfall-overlay\.reading \.waterfall-track,\s*\.waterfall-overlay\.sheet-open \.waterfall-track\s*\{[^}]*pointer-events:\s*none[^}]*touch-action:\s*none/s,
  'open details and the source sheet must freeze the hidden feed without changing overflow');
assert.match(waterfallCss, /\.waterfall-reader\.active\.closing\s*\{[^}]*pointer-events:\s*auto/s,
  'the closing reader must keep the leftover press until it is actually hidden');
assert.match(waterfallCss, /\.waterfall-preferences\s*\{[^}]*z-index:\s*(?:3\d|4\d)/s,
  'the source sheet must stack above the persistent discovery chrome');
assert.doesNotMatch(waterfallJs, /--reader-card-/,
  'opening details must not write a card-sized transform onto the reader shell');
assert.match(renderer, /data-waterfall-back[\s\S]*waterfall-toolbar-label">返回</,
  'discovery back must use the standard 返回 action beside the 发现 title');
assert.doesNotMatch(renderer, /waterfall-toolbar-label">返回发现</,
  'the back action and the current-page title must not repeat the same concept');
assert.match(waterfallJs, /function realignDiscoveryAfterReveal[\s\S]*cardMetrics = \[\][\s\S]*presentedIndex = -1[\s\S]*render\(\)/,
  'revealing a previously hidden track must discard zero-sized card geometry and align the current card');
assert.doesNotMatch(waterfallCss, /\.waterfall-cinema-stage img\s*\{/);
assert.match(surfaceView, /\.mediaPlayGestureAccess\(false\)/);
assert.match(surfaceView, /popupController\.backward\(\)/);
assert.match(surfaceView, /openWaterfallSource/);
assert.match(surfaceView, /shouldOpenWaterfallSourceExternally/);
assert.match(surfaceView, /b23\.tv/,
  'Bilibili short links must bypass the embedded ArkWeb page that can stay blank');
assert.match(surfaceView, /context\.openLink\(url\)/,
  'Bilibili sources must use the system link handler with an ability fallback');
assert.match(surfaceView, /asyncMethodList:\s*\['postAction'/,
  'a synchronous javaScriptProxy call blocks the page JS thread on a cross-process round trip');
assert.doesNotMatch(surfaceView, /methodList:\s*\[[^\]]*'postAction'/,
  'the action bridge must stay off the synchronous proxy list');
assert.match(waterfallJs,
  /Object\.defineProperty\(window, '__arkWebDomTree'/,
  'Waterfall must intercept ArkWeb DOM instrumentation when it is injected after page JS');
assert.match(waterfallJs,
  /scanner\.addDomTreeReportedAsync = function \(\) \{\};/,
  'Waterfall must prevent ArkWeb from starting the full-DOM scanner');
assert.match(waterfallJs,
  /disableArkWebDomTree[\s\S]*scanner\.removeDomTreeReported\(\)/,
  'Waterfall must also detach an ArkWeb scanner that was injected first');
assert.match(waterfallJs, /function syncCardsAfterPaint/,
  'layout reads must wait for the paint that follows a card append');
const afterPaintSource = waterfallJs.slice(
  waterfallJs.indexOf('function syncCardsAfterPaint'),
  waterfallJs.indexOf('function refreshMetricsAfterSettle')
);
assert.doesNotMatch(afterPaintSource, /metricTimer\s*=\s*setTimeout/,
  'a scroll settle must not cancel the pending presentation sync, or no card stays highlighted');
assert.match(afterPaintSource, /afterPaintTimer\s*=\s*setTimeout/,
  'the after-paint sync needs its own timer handle');
assert.match(waterfallJs, /function dropRenderedCardsMissingFrom/,
  'cards leaving the payload must be detached individually instead of rebuilding the feed');
assert.doesNotMatch(waterfallCss, /content-visibility/,
  'hiding the frozen feed with content-visibility forces a full relayout on every open and close');
assert.doesNotMatch(renderer, /id="waterfall-reader"[^>]*aria-live/,
  'a live region on the reader makes ArkWeb rebuild accessibility on every open');
const closeReaderSource = waterfallJs.slice(
  waterfallJs.indexOf('function closeReader'),
  waterfallJs.indexOf('function openReader')
);
assert.doesNotMatch(closeReaderSource, /reader\.innerHTML\s*=\s*['"]{2}/,
  'closing details must not tear down the reader DOM; ArkWeb walks the whole tree on large mutations');
assert.match(closeReaderSource, /stopReaderMedia\(\)/,
  'returning must tear down the player before the feed is shown again');
assert.ok(
  closeReaderSource.indexOf("reader.classList.add('closing')") <
    closeReaderSource.indexOf('stopReaderMedia()'),
  'the close motion must start before player teardown'
);
assert.ok(
  closeReaderSource.indexOf('setFullscreen(false)') <
    closeReaderSource.indexOf('= setTimeout'),
  'native chrome must restore while the reader still covers the feed'
);
assert.ok(
  closeReaderSource.indexOf("overlay.classList.remove('reading')") <
    closeReaderSource.indexOf('= setTimeout'),
  'the feed must accept scrolls as soon as the reader starts closing'
);
assert.match(closeReaderSource, /setTimeout\(function \(\) \{[\s\S]*stopReaderMedia\(\)/,
  'player teardown must wait a turn so the close motion can paint');
assert.match(closeReaderSource, /reader\.style\.pointerEvents = 'none'/,
  'after the leftover close click, the fading reader must stop eating feed scrolls');
assert.ok(
  closeReaderSource.indexOf("reader.classList.remove('active')") <
    closeReaderSource.indexOf('track.scrollTop = readerFeedScrollTop'),
  'feed realignment must wait until the reader layer is gone'
);
assert.doesNotMatch(closeReaderSource, /requestAnimationFrame\(restoreFeed\)/,
  'writing scrollTop on the same frame as close fights native snap');
assert.doesNotMatch(closeReaderSource, /updateCardPresentation\(true\)/,
  'returning to the feed must not force a synchronous card layout pass');
assert.match(waterfallJs, /function scheduleIdleFlush/,
  'deferred payloads must wait for an idle feed instead of rebuilding on reveal');
const applyWaterfallUpdateSource = waterfallJs.slice(
  waterfallJs.indexOf('window.__aiphoneApplyWaterfallUpdate'),
  waterfallJs.indexOf('function flushPendingPayload')
);
assert.match(applyWaterfallUpdateSource, /mode === 'reading'/,
  'live provider updates must wait until details close instead of mutating the hidden feed');
assert.match(applyWaterfallUpdateSource, /mode === 'reader_closing'/,
  'the close motion still defers feed mutations until the reader layer is gone');
assert.match(waterfallJs, /createElement\('iframe'\)/,
  'ArkWeb innerHTML iframes do not start Bilibili playback');
assert.match(waterfallJs, /referrerpolicy', 'origin-when-cross-origin'/,
  'Bilibili player.html needs the same referrer policy as the working media renderer');
assert.match(waterfallJs, /function realignPresentedCard/,
  'sheet close must refresh card presentation after chrome returns');
const realignSource = waterfallJs.slice(
  waterfallJs.indexOf('function realignPresentedCard'),
  waterfallJs.indexOf('function freezeFeedMotion')
);
assert.match(realignSource, /if \(cardMetrics\.length === 0\) refreshCardMetrics/,
  'returning to the feed must not remeasure every card when snap metrics already exist');
assert.match(waterfallJs.slice(
  waterfallJs.indexOf('function closePreferences'),
  waterfallJs.indexOf('function render()')
), /realignPresentedCard/,
  'closing the source sheet must refresh the current card without walking the feed');
const closePreferencesSource = waterfallJs.slice(
  waterfallJs.indexOf('function closePreferences'),
  waterfallJs.indexOf('function render()')
);
assert.match(closePreferencesSource, /changed[\s\S]*?(?:flushPendingPayload\(selectedSources\)|render\(\))/,
  'source changes must update the local feed before the sheet returns control');
assert.ok(
  closePreferencesSource.indexOf('realignPresentedCard(changed)') <
    closePreferencesSource.indexOf('setFullscreen(false)'),
  'sheet close must restore the visible card before returning control'
);
assert.match(waterfallJs, /snapToCard && track\) track\.scrollTop = scrollTopForCard\(visibleCardIndex\(\)\)/,
  'a changed source list must align the rebuilt feed to a real card before the next swipe');
assert.match(waterfallJs, /readerMountedId/,
  'reopening the same card must reuse the already-built reader layer');
const renderPreferencesSource = waterfallJs.slice(
  waterfallJs.indexOf('function renderPreferences'),
  waterfallJs.indexOf('function closePreferences')
);
assert.match(renderPreferencesSource,
  /if \(!preferences\.innerHTML \|\| preferenceStatusKey !== nextStatusKey\)/,
  'reopening source settings rebuilds only when hard availability changes');
assert.doesNotMatch(waterfallJs, /CARD_MOUNT_RADIUS/,
  'virtualizing offscreen cards as empty placeholders blanks the feed and breaks snap');
assert.doesNotMatch(waterfallJs, /waterfall-card--placeholder/,
  'every ranked card must keep its real markup so the next page is already painted');
const visibleCardSource = waterfallJs.slice(
  waterfallJs.indexOf('function visibleCardIndex'),
  waterfallJs.indexOf('function snapTopForNode')
);
assert.doesNotMatch(visibleCardSource, /Math\.abs\(bestIndex - presentedIndex\) > 1/,
  'clamping highlight to ±1 makes the current card lag a full page behind the finger');
assert.doesNotMatch(visibleCardSource, /pageAnchorIndex >= 0/,
  'a paging anchor must not freeze is-active until settle');
assert.match(waterfallJs, /visibleId:/,
  'one advance must tell native which card is actually on screen');
assert.match(waterfallJs, /shell\.hidden/,
  'the hidden aggregate search page must leave the accessibility tree while discovery is open');
assert.match(waterfallJs, /window\.__aiphoneHandleWaterfallBack\s*=\s*function/);
assert.match(surfaceView, /waterfallBackRequestTick/);
assert.match(surfaceView, /__aiphoneHandleWaterfallBack/);
assert.match(homePage, /waterfallBackRequestTick/);
assert.match(indexPage, /onBackPress\(\): boolean[\s\S]*waterfallBackRequestTick/);
assert.match(indexPage,
  /onBackPress\(\): boolean[\s\S]*if \(this\.showConfigPage\) \{[\s\S]*this\.showConfigPage = false;[\s\S]*return true;/,
  'system Back must return from the conditionally rendered settings page');
const scrollHandlerSource = waterfallJs.slice(
  waterfallJs.indexOf("track.addEventListener('scroll'"),
  waterfallJs.indexOf("track.addEventListener('error'")
);
assert.doesNotMatch(scrollHandlerSource, /scheduleAdvance/,
  'scroll frames must only paint presentation; advancing waits for the settled page');
assert.doesNotMatch(scrollHandlerSource, /postAdvanceIfNeeded\(updateCardPresentation\(\)\)/,
  'native bridge work must not run inside the scrolling animation frame');
assert.doesNotMatch(scrollHandlerSource, /track\.scrollTop\s*=/,
  'writing scrollTop during scroll fights the finger and flashes neighboring cards');
assert.doesNotMatch(waterfallJs, /function clampPagingScroll/,
  'live paging clamps retrigger opacity and scale transitions on every frame');
assert.doesNotMatch(waterfallCss, /\.waterfall-track\.is-scrolling/,
  'native scroll snap must remain the single position owner throughout inertia');
assert.doesNotMatch(waterfallCss, /\.waterfall-overlay\.reading \.waterfall-card[\s\S]{0,80}transition:\s*none/,
  'killing card transitions under the reader makes the return snap instead of settle');
assert.doesNotMatch(
  waterfallCss,
  /\.waterfall-overlay\.reading \.waterfall-track,[^}]*scroll-snap-type:\s*none/s,
  'turning snap off under details hitchs the feed when snap comes back'
);
assert.doesNotMatch(waterfallJs, /pagingMoved|feedSnapping|snapPagingCard|pagingStartTop/,
  'touch completion must never compete with native momentum or mandatory snap');
assert.match(waterfallJs, /function freezeFeedMotion/,
  'opening or closing details must cancel in-flight feed presentation');
const freezeFeedSource = waterfallJs.slice(
  waterfallJs.indexOf('function freezeFeedMotion'),
  waterfallJs.indexOf('function beginPagingGesture')
);
assert.match(freezeFeedSource, /payloadSettleTimer/,
  'opening details must cancel the delayed feed settle or cards flash behind the reader');
const openReaderSource = waterfallJs.slice(
  waterfallJs.indexOf('function openReader'),
  waterfallJs.indexOf('function toggleVideoFullscreen')
);
assert.doesNotMatch(openReaderSource, /classList\.remove\('active'\)/,
  'reopening during the close transition must reverse from the current visual state');
assert.match(openReaderSource, /requestAnimationFrame\(reveal\)/,
  'first entry must paint the mounted detail at its resting origin before starting the transition');
const settleSource = waterfallJs.slice(
  waterfallJs.indexOf('function settleInteraction'),
  waterfallJs.indexOf("document.addEventListener('touchstart'")
);
assert.match(settleSource, /scheduleAdvance\(settledIndex\)/,
  'the settled page must still advance the native feed once scrolling stops');
assert.doesNotMatch(settleSource, /is-scrolling|scrollTop\s*=/,
  'settling deferred payloads must not restart snap or rewrite the scroll position');
const touchCompletionSource = waterfallJs.slice(
  waterfallJs.indexOf("document.addEventListener('touchend'"),
  waterfallJs.indexOf("track.addEventListener('scroll'")
);
assert.doesNotMatch(touchCompletionSource, /scrollTop\s*=|snapPagingCard/,
  'touchend and touchcancel must leave momentum and native snap untouched');
const presentationSource = waterfallJs.slice(
  waterfallJs.indexOf('function updateCardPresentation'),
  waterfallJs.indexOf('function refreshMetricsAfterSettle')
);
assert.doesNotMatch(presentationSource, /scrollActive && !force/,
  'freezing opacity classes until settle pops the incoming card from faded to solid');
assert.doesNotMatch(presentationSource, /innerHTML\s*=/,
  'player DOM teardown must not run in the presentation frame');
assert.doesNotMatch(waterfallJs, /data-waterfall-video-direct/,
  'Bilibili iframes must mount only after an explicit play action');
const mediaErrorSource = waterfallJs.slice(
  waterfallJs.indexOf("track.addEventListener('error'"),
  waterfallJs.indexOf("track.addEventListener('ended'")
);
assert.match(mediaErrorSource, /image\.hidden\s*=\s*true/,
  'a failed cover must hide only the broken image');
assert.doesNotMatch(mediaErrorSource, /stage\.hidden|refreshMetricsAfterSettle/,
  'a failed cover must not collapse card geometry or invalidate offsets');
assert.doesNotMatch(waterfallJs, /onerror="this\.parentElement\.hidden=true"/,
  'inline cover fallback must preserve the media stage');
assert.match(renderer, /body\.waterfall-direct\s*\{\s*background:\s*transparent/,
  'direct discovery must let the native aurora show through the Web document');
assert.match(renderer, /body\.waterfall-direct \.waterfall-overlay,[\s\S]*body\.waterfall-direct \.waterfall-track\s*\{\s*background:\s*transparent/,
  'direct discovery must keep the aurora visible between cards instead of a paper wash');
assert.match(renderer, /startInDiscovery \? ' class="waterfall-direct"' : ''/,
  'ordinary aggregate documents must keep their existing opaque body');
assert.doesNotMatch(waterfallJs, /target=\"_blank\"/,
  'source actions must use only the native source-page bridge');
const preferenceChangeSource = waterfallJs.slice(
  waterfallJs.indexOf("input.addEventListener('change'"),
  waterfallJs.indexOf("mode = 'source_preferences'")
);
assert.doesNotMatch(preferenceChangeSource, /postSourceSelection\(\)|render\(\)/,
  'source toggles must not synchronously bridge and rebuild the feed');
assert.doesNotThrow(() => new vm.Script(emittedWaterfallJs), 'generated ArkWeb script must remain valid JavaScript');
assert.match(waterfallJs, /host !== 'twitch\.tv' && host !== 'www\.twitch\.tv'/);
assert.match(waterfallJs, /\^\[a-z0-9_\]\{1,25\}\$/);
assert.match(waterfallJs, /https:\/\/player\.twitch\.tv\/\?channel=/);
assert.match(waterfallJs, /&autoplay=false&muted=false/);
assert.match(waterfallJs, /id: 'waterfall\.applepodcasts\.resolve'/);
assert.match(waterfallJs, /args: \{ surfaceId: state\.surfaceId \|\| '', candidateId: candidateId \}/);
assert.match(waterfallJs, /document\.createElement\('audio'\)/);
assert.match(waterfallJs, /audio\.setAttribute\('preload', 'none'\)/);
assert.match(waterfallJs, /coverFailure = sourceOnly \? 'this\.hidden=true' : 'this\.parentElement\.hidden=true'/,
  'an inline source cover failure must not hide its playback controls');
assert.match(waterfallJs, /id: 'waterfall\.comments\.load'/,
  'detail comments must load through the bounded native action bridge');
assert.match(waterfallJs, /data-waterfall-comments-slot/);
assert.match(waterfallJs, /data-waterfall-comment-toggle/);
assert.match(waterfallCss, /\.waterfall-comment-skeleton/);
assert.match(waterfallCss, /@keyframes waterfall-comment-shimmer/);
assert.match(waterfallCss,
  /\.waterfall-comment-text\s*\{[^}]*-webkit-line-clamp:\s*2/s,
  'comment previews must stay compact until the row is expanded');
assert.match(waterfallJs, /youtube\.com\/embed\/.*\?playsinline=1/);
assert.match(waterfallJs, /player\.bilibili\.com\/player\.html\?bvid=.*&autoplay=0&poster=true&danmaku=0&isOutside=true/);
assert.doesNotMatch(waterfallJs, /TWITCH_CLIENT_(?:ID|SECRET)|access_token/i);

function element() {
  const classes = new Set();
  const listeners = {};
  const children = [];
  let html = '';
  let htmlWrites = 0;
  let appendedHtmlWrites = 0;
  let classToggleWrites = 0;
  let outerHtmlWrites = 0;
  const removedChildren = [];
  const node = {
    scrollTop: 0,
    clientHeight: 1000,
    rect: { top: 0, bottom: 1000 },
    removedChildren,
    parentNode: { removeChild: (child) => { removedChildren.push(child); child.removed = true; } },
    style: {
      transform: '', opacity: '', values: {},
      setProperty(name, value) { this.values[name] = value; }
    },
    get innerHTML() { return html; },
    set innerHTML(value) {
      html = value;
      htmlWrites += 1;
      if (value === '') children.length = 0;
    },
    get outerHTML() { return html; },
    set outerHTML(value) { html = value; outerHtmlWrites += 1; },
    get innerHTMLWrites() { return htmlWrites; },
    get outerHTMLWrites() { return outerHtmlWrites; },
    get appendedHtmlWrites() { return appendedHtmlWrites; },
    get classToggleWrites() { return classToggleWrites; },
    get firstChild() { return children[0] || null; },
    appendChild: (child) => {
      children.push(child);
      const tag = String(child.tagName || 'div').toLowerCase();
      const cls = child.className ? ` class="${child.className}"` : '';
      const src = child.src ? ` src="${child.src}"` : '';
      const extra = Object.entries(child.attrs || {})
        .map(([key, value]) => ` ${key}="${value}"`).join('');
      html += `<${tag}${cls}${src}${extra}></${tag}>`;
      return child;
    },
    contains: () => false,
    insertAdjacentHTML: (_position, value) => { html += value; appendedHtmlWrites += 1; },
    classList: {
      add: (name) => { classToggleWrites += 1; classes.add(name); },
      remove: (name) => { classToggleWrites += 1; classes.delete(name); },
      toggle: (name, force) => {
        classToggleWrites += 1;
        if (force === true) { classes.add(name); return true; }
        if (force === false) { classes.delete(name); return false; }
        if (classes.has(name)) { classes.delete(name); return false; }
        classes.add(name); return true;
      },
      contains: (name) => classes.has(name)
    },
    addEventListener: (type, listener) => {
      const previous = listeners[type];
      listeners[type] = previous ? (event) => {
        previous(event);
        listener(event);
      } : listener;
    },
    emit: (type, event = {}) => {
      listeners[type]?.(event);
    },
    querySelector: () => null,
    getBoundingClientRect: () => node.rect,
    querySelectorAll: () => []
  };
  return node;
}

const overlay = element();
const track = element();
const preferences = element();
const reader = element();
const collection = element();
const readerHead = element();
reader.querySelector = (selector) => selector === '.waterfall-reader-head' ? readerHead : null;
const toolbar = element();
const toast = element();
const backButton = element();
const preferencesButton = element();
const collectionButton = element();
const preferenceBackButton = element();
const preferenceDoneButton = element();
const preferenceAllButton = element();
const preferenceNoneButton = element();
preferenceBackButton.closest = (selector) => selector.includes('[data-waterfall-close-preferences]') ? preferenceBackButton : null;
preferenceDoneButton.closest = (selector) => selector.includes('[data-waterfall-apply-preferences]') ? preferenceDoneButton : null;
preferenceAllButton.closest = (selector) => selector.includes('[data-waterfall-sources-all]') ? preferenceAllButton : null;
preferenceNoneButton.closest = (selector) => selector.includes('[data-waterfall-sources-none]') ? preferenceNoneButton : null;
const sourceInput = (name, checked) => {
  const input = element();
  input.checked = checked;
  input.getAttribute = (attribute) => attribute === 'data-waterfall-source' ? name : '';
  return input;
};
const sourceInputs = [
  sourceInput('youtube', true),
  sourceInput('bilibili', true),
  sourceInput('x', true),
  sourceInput('hackernews', true),
  sourceInput('reddit', true),
  sourceInput('zhihu', true)
];
sourceInputs.at(-1).disabled = true;
preferences.querySelectorAll = (selector) => ({
  '[data-waterfall-source]': sourceInputs,
  '[data-waterfall-source]:checked': sourceInputs.filter((input) => input.checked)
})[selector] ?? [];
const documentListeners = {};
const actions = [];
const openedSources = [];
const fullscreenStates = [];
const timers = [];
const createdFrames = [];
let now = 1000;
const FakeDate = { now: () => now };
const actionCount = (id) => actions.filter((action) => action.id === id).length;
const schedule = (callback, delay) => {
  const timer = { callback, delay, canceled: false };
  timers.push(timer);
  return timer;
};
const cancel = (timer) => { if (timer) timer.canceled = true; };
const runLatestTimer = (delay) => {
  const timer = timers.filter((item) => item.delay === delay && !item.canceled).at(-1);
  assert.ok(timer, `expected an active ${delay}ms timer`);
  timer.canceled = true;
  timer.callback();
};
const finishReaderClose = () => {
  const timer = timers.filter((item) => item.delay === 180 && !item.canceled).at(-1);
  assert.ok(timer, 'reader close must wait for the return motion');
  timer.canceled = true;
  timer.callback();
};
assert.match(waterfallJs, /classList\.toggle\('is-adjacent'/,
  'the visible card and its neighbors must keep distinct opacity classes');
const leftoverFeedClickMustNotOpen = (openTarget) => {
  track.emit('click', {
    target: { closest: (selector) => selector === '[data-waterfall-open]' ? openTarget : null }
  });
  assert.equal(reader.classList.contains('active'), false,
    'a leftover click after returning must not reopen the same card');
};
const openFeedCard = (openTarget) => {
  documentListeners.touchstart({ touches: [{ clientX: 120, clientY: 400 }] });
  track.emit('click', {
    target: { closest: (selector) => selector === '[data-waterfall-open]' ? openTarget : null }
  });
  documentListeners.touchend?.();
};
const document = {
  hidden: false,
  createElement: (tag) => {
    const attrs = {};
    return {
      tagName: String(tag).toUpperCase(),
      className: '',
      title: '',
      src: '',
      attrs,
      setAttribute(name, value) { attrs[name] = value; }
    };
  },
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences,
    'waterfall-reader': reader,
    'waterfall-collection': collection,
    'waterfall-toolbar': toolbar,
    'waterfall-toast': toast
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => ({
    '[data-waterfall-back]': [backButton],
    '[data-waterfall-preferences]': [preferencesButton],
    '[data-waterfall-collection-open]': [collectionButton]
  })[selector] ?? [],
  createElement: (tagName) => {
    assert.ok(tagName === 'iframe' || tagName === 'audio');
    const attributes = {};
    const listeners = {};
    const media = {
      tagName: tagName.toUpperCase(),
      className: '',
      removed: false,
      paused: false,
      attributes,
      setAttribute: (name, value) => { attributes[name] = String(value); },
      addEventListener: (type, listener) => { listeners[type] = listener; },
      emit: (type) => listeners[type]?.(),
      pause: () => { media.paused = true; },
      remove: () => { media.removed = true; }
    };
    createdFrames.push(media);
    return media;
  },
  addEventListener: (type, listener) => {
    const previous = documentListeners[type];
    documentListeners[type] = previous ? (event) => {
      previous(event);
      listener(event);
    } : listener;
  }
};
const candidate = (id) => ({
  id,
  source: 'youtube',
  mediaType: 'video',
  title: id,
  summary: id === 'current' ? 'B 站视频搜索结果：current summary tail' : id,
  url: id === 'current' ? 'https://www.youtube.com/watch?v=abc123' : `https://example.test/${id}`,
  coverUrl: id === 'current' ? 'https://example.test/broken-cover.jpg' : '',
  publishedAt: id === 'current' ? '2026-08-17T01:17:55.000Z' : '',
  reason: '标题命中查询'
});
const imageCandidate = {
  ...candidate('image-current'),
  source: 'zhihu',
  mediaType: 'image_text',
  coverUrl: 'https://example.test/image.jpg',
  reason: '摘要命中查询'
};
const textCandidate = {
  ...candidate('text-current'),
  source: 'hackernews',
  mediaType: 'post',
  coverUrl: '',
  summary: 'A long text summary for the dedicated reader. '.repeat(40) + 'DETAIL_BODY_END',
  reason: '补充 HN 来源'
};
const noCoverImageCandidate = {
  ...imageCandidate,
  id: 'no-cover-image',
  source: 'reddit',
  coverUrl: '',
  summary: 'A Reddit post without a cover should stay a compact text card'
};
const cnNewsCandidate = {
  ...candidate('cnnews-current'),
  source: 'cnnews',
  provider: 'IT 之家',
  mediaType: 'post'
};
const globalNewsCandidate = {
  ...candidate('globalnews-current'),
  source: 'globalnews',
  provider: 'The Guardian',
  mediaType: 'post'
};
const githubCandidate = {
  ...candidate('github-current'),
  source: 'github',
  provider: 'GitHub',
  mediaType: 'post',
  authorName: 'openai',
  metrics: [{ kind: 'star', value: 1200 }, { kind: 'fork', value: 88 }]
};
const steamCandidate = {
  ...candidate('steam-current'),
  source: 'steam',
  provider: 'Steam',
  mediaType: 'post',
  authorName: 'Valve'
};
const portraitCandidate = {
  ...candidate('portrait-current'),
  source: 'bilibili',
  format: 'portrait_video',
  coverUrl: '',
  url: 'https://www.bilibili.com/video/BV1xx411c7mD',
  authorName: '影像实验室',
  authorAvatarUrl: 'https://example.test/avatar.jpg',
  metrics: [
    { kind: 'view', value: 98659 },
    { kind: 'like', value: 361 },
    { kind: 'favorite', value: 178 },
    { kind: 'comment', value: 186 },
    { kind: 'coin', value: 34 },
    { kind: 'danmaku', value: 148 },
    { kind: 'share', value: 28 }
  ]
};
const testUiIcon = '<span class="waterfall-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M4 12h16" /></svg></span>';
const window = {
  innerWidth: 400,
  innerHeight: 1000,
  matchMedia: () => ({ matches: false }),
  location: { hostname: 'aiphone.local' },
  __aiphoneWaterfallInitial: {
    surfaceId: 'surface-1',
    currentId: 'current',
    enabledSources: ['youtube', 'bilibili', 'reddit', 'zhihu', 'hackernews', 'x', 'github', 'steam',
      'cnnews', 'globalnews', 'unknown'],
    aggregateHtml: '',
    candidates: [candidate('current'), imageCandidate, textCandidate, portraitCandidate, noCoverImageCandidate,
      { ...candidate('x-current'), source: 'x', mediaType: 'post' }, githubCandidate, steamCandidate,
      cnNewsCandidate, globalNewsCandidate,
      { ...candidate('unknown-current'), source: 'unknown', mediaType: 'post' }],
    mediaEmbeds: {
      'https://www.youtube.com/watch?v=abc123': 'https://www.youtube.com/embed/abc123?playsinline=1'
    },
    sources: [
      { source: 'youtube', phase: 'success' },
      { source: 'twitch', phase: 'needs_auth', message: '未授权' }
    ]
    ,cardStates: [{ candidateId: 'current', reaction: 'like', saved: true }]
    ,savedCards: [{ ...candidate('current'), savedAt: 1000 }]
  },
  __aiphoneWaterfallSourceLogos: { youtube: 'data:image/png;base64,logo', reddit: 'data:image/png;base64,reddit' },
  __aiphoneWaterfallUiIcons: {
    back: testUiIcon,
    external: testUiIcon,
    expand: testUiIcon,
    play: testUiIcon,
    sources: testUiIcon,
    heart: testUiIcon,
    star: testUiIcon,
    comment: testUiIcon,
    eye: testUiIcon,
    thumbsUp: testUiIcon,
    thumbsDown: testUiIcon,
    bookmark: testUiIcon,
    search: testUiIcon,
    upvote: testUiIcon,
    repost: testUiIcon,
    quote: testUiIcon,
    coin: testUiIcon,
    danmaku: testUiIcon,
    share: testUiIcon
  },
  AIPhoneHome: {
    postAction: (value) => actions.push(JSON.parse(value)),
    setWaterfallFullscreen: (value) => fullscreenStates.push(value),
    openWaterfallSource: (value) => openedSources.push(value)
  }
};

vm.runInNewContext(emittedWaterfallJs, {
  window,
  document,
  URL,
  Date: FakeDate,
  setTimeout: schedule,
  clearTimeout: cancel
});
documentListeners.click({
  target: {
    closest: (selector) => selector === '[data-waterfall-enter]' ? {} : null
  }
});
assert.deepEqual(fullscreenStates, ['true']);
assert.equal(overlay.classList.contains('active'), true);
assert.equal(overlay.classList.contains('closing'), false);
assert.match(track.innerHTML, /waterfall-card--video waterfall-card--landscape/);
assert.match(track.innerHTML, /waterfall-card--image-text/);
assert.match(track.innerHTML, /waterfall-card--text/);
assert.match(track.innerHTML, /waterfall-card--video waterfall-card--portrait/);
assert.match(track.innerHTML, /waterfall-card--text waterfall-tone--reddit" data-waterfall-id="no-cover-image"/);
assert.doesNotMatch(track.innerHTML, /class="waterfall-card-ambient"/,
  'scrolling cards must not paint full-card filtered cover duplicates');
assert.doesNotMatch(track.innerHTML, /waterfall-card-shell--ambient/);
assert.match(track.innerHTML, /waterfall-tone--youtube[^"\n]*" data-waterfall-id="current"/);
assert.match(track.innerHTML, /waterfall-tone--zhihu[^"\n]*" data-waterfall-id="image-current"/);
assert.match(track.innerHTML, />CNNews · IT 之家</,
  'CNNews cards must retain the internal publisher without exposing a second settings source');
assert.match(track.innerHTML, />GlobalNews · The Guardian</,
  'GlobalNews cards must retain the publisher returned by the adapter');
assert.match(track.innerHTML, /data-waterfall-id="github-current"/);
assert.match(track.innerHTML, /data-waterfall-id="steam-current"/);
assert.match(track.innerHTML, /data-waterfall-metric="star" aria-label="星标 1,200"/,
  'GitHub stars must use their provider meaning instead of a generic heat score');
assert.match(track.innerHTML, /data-waterfall-metric="fork" aria-label="Fork 88"/,
  'GitHub forks must survive the shared card renderer');
assert.match(track.innerHTML,
  /<article[^>]*data-waterfall-id="image-current"[^>]*><div class="waterfall-card-shell waterfall-card-shell--interactive" role="button" tabindex="0" data-waterfall-open="image-current">/,
  'ordinary image-text cards such as Zhihu must retain their whole-card reader action');
assert.match(track.innerHTML,
  /<article[^>]*data-waterfall-id="text-current"[^>]*><div class="waterfall-card-shell waterfall-card-shell--interactive" role="button" tabindex="0" data-waterfall-open="text-current">/,
  'ordinary post cards must retain their whole-card reader action');
assert.match(track.innerHTML, /waterfall-tone--hackernews[^"\n]*" data-waterfall-id="text-current"/);
assert.match(track.innerHTML, /waterfall-tone--bilibili[^"\n]*" data-waterfall-id="portrait-current"/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-video-direct/);
assert.doesNotMatch(track.innerHTML, /<iframe class="waterfall-media-frame"/,
  'initial cards must not create off-screen video documents');
assert.match(track.innerHTML, /waterfall-tone--reddit[^"\n]*" data-waterfall-id="no-cover-image"/);
assert.match(track.innerHTML, /waterfall-tone--x[^"\n]*" data-waterfall-id="x-current"/);
assert.match(track.innerHTML, /waterfall-tone--neutral[^"\n]*" data-waterfall-id="unknown-current"/);
assert.match(track.innerHTML, /A Reddit post without a cover should stay a compact text card/);
assert.match(track.innerHTML, /data-waterfall-open="portrait-current"/);
assert.match(track.innerHTML, /data-waterfall-video-play/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-read/);
assert.match(track.innerHTML, /data-waterfall-open="image-current"/);
assert.match(track.innerHTML, /data-waterfall-open="text-current"/);
assert.equal(track.innerHTML.match(/data-waterfall-open="image-current"/g)?.length, 1,
  'an image-text card must expose one keyboard entry into details');
assert.equal(track.innerHTML.match(/data-waterfall-open="text-current"/g)?.length, 1,
  'a text card must expose one keyboard entry into details');
assert.match(track.innerHTML, /class="waterfall-source-action"/);
assert.match(track.innerHTML,
  /waterfall-card-action--like is-selected"[^>]*data-waterfall-candidate-id="current"[^>]*aria-pressed="true"/,
  'persisted product feedback must render independently from platform metrics');
assert.match(track.innerHTML,
  /waterfall-card-action--save is-selected"[^>]*data-waterfall-candidate-id="current"[^>]*aria-pressed="true"/);
const advanceBeforeDislike = actionCount('waterfall.feed.advance');
const dislikeControl = {
  getAttribute: (name) => ({
    'data-waterfall-card-action': 'dislike',
    'data-waterfall-candidate-id': 'current'
  })[name] ?? ''
};
track.emit('click', {
  preventDefault: () => {},
  target: { closest: (selector) => selector === '[data-waterfall-card-action]' ? dislikeControl : null }
});
assert.equal(actions.at(-1)?.id, 'waterfall.card.action');
assert.deepEqual(actions.at(-1)?.args, {
  surfaceId: 'surface-1', candidateId: 'current', action: 'dislike', active: true
});
assert.equal(actionCount('waterfall.feed.advance'), advanceBeforeDislike,
  'dislike must not hide or advance the current card');
collectionButton.emit('click', { preventDefault: () => {}, target: collectionButton });
assert.equal(collection.classList.contains('active'), true);
assert.match(collection.innerHTML, /data-waterfall-collection-search/);
assert.match(collection.innerHTML, /data-waterfall-collection-source="youtube"/);
assert.match(collection.innerHTML, /data-waterfall-collection-row="current"/);
const collectionSaveControl = {
  getAttribute: (name) => ({
    'data-waterfall-card-action': 'save',
    'data-waterfall-candidate-id': 'current'
  })[name] ?? ''
};
collection.emit('click', {
  preventDefault: () => {},
  target: { closest: (selector) => selector === '[data-waterfall-card-action]' ? collectionSaveControl : null }
});
assert.equal(actions.at(-1)?.id, 'waterfall.card.action');
assert.equal(actions.at(-1)?.args?.active, false);
assert.doesNotMatch(collection.innerHTML, /data-waterfall-collection-row="current"/);
assert.match(toast.innerHTML, /data-waterfall-collection-undo/);
toast.emit('click', {
  preventDefault: () => {},
  target: { closest: (selector) => selector === '[data-waterfall-collection-undo]' ? {} : null }
});
assert.equal(actions.at(-1)?.args?.active, true);
assert.equal(actions.at(-1)?.args?.restoreSavedAt, true);
assert.match(collection.innerHTML, /data-waterfall-collection-row="current"/);
collection.emit('click', {
  preventDefault: () => {},
  target: { closest: (selector) => selector === '[data-waterfall-collection-close]' ? {} : null }
});
runLatestTimer(160);
assert.equal(collection.classList.contains('active'), false);
assert.match(track.innerHTML, /referrerpolicy="no-referrer"/);
assert.match(track.innerHTML, /onerror="this\.hidden=true"/);
assert.doesNotMatch(track.innerHTML, />查看来源</);
assert.doesNotMatch(track.innerHTML, /src="https:\/\/www\.youtube\.com\/embed\/abc123/,
  'non-Bilibili players stay lazy until the user asks to play');
assert.doesNotMatch(track.innerHTML,
  /<iframe class="waterfall-media-frame" src="https:\/\/player\.bilibili\.com\/player\.html\?bvid=BV1xx411c7mD/,
  'Bilibili players must stay unmounted until the user explicitly starts playback');
assert.match(track.innerHTML, /current summary/);
assert.match(track.innerHTML, /current summary tail/);
assert.match(track.innerHTML, /2026-08-17/);
assert.doesNotMatch(track.innerHTML, /2026-08-17T01:17:55/);
assert.doesNotMatch(track.innerHTML, /B 站视频搜索结果：/);
assert.match(track.innerHTML, /waterfall-recommendation/);
assert.match(track.innerHTML, /标题命中查询/);
assert.match(track.innerHTML, /data-waterfall-reason/);
assert.match(track.innerHTML, /class="waterfall-author-avatar"[^>]*avatar\.jpg/);
assert.match(track.innerHTML, /class="waterfall-author-name">影像实验室</);
assert.match(track.innerHTML, /class="waterfall-signal-rail"/);
assert.match(track.innerHTML, /data-waterfall-metric="like"/);
assert.match(track.innerHTML, /data-waterfall-metric="favorite"/);
assert.match(track.innerHTML, /aria-label="播放 98,659"/);
assert.doesNotMatch(track.innerHTML, /waterfall-signal-label/,
  'feed cards must use icon and value only instead of adding metric labels');
assert.doesNotMatch(track.innerHTML, /data-waterfall-media-fallback/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-video-fullscreen/);
assert.match(track.innerHTML, /<svg[^>]*viewBox="0 0 24 24"/);
assert.doesNotMatch(track.innerHTML, /[↗⌄⛶]/);
const compactCardNodes = [
  Object.assign(element(), { offsetTop: 18, offsetHeight: 700 }),
  Object.assign(element(), { offsetTop: 746, offsetHeight: 700 }),
  Object.assign(element(), { offsetTop: 1474, offsetHeight: 700 })
];
const gestureCardNodes = window.__aiphoneWaterfallInitial.candidates.map((_, index) =>
  Object.assign(element(), { offsetTop: 18 + index * 728, offsetHeight: 700 }));
const currentMetricSlot = element();
gestureCardNodes[0].getAttribute = (name) => name === 'data-waterfall-id' ? 'current' : '';
gestureCardNodes[0].querySelector = (selector) =>
  selector === '[data-waterfall-card-metrics]' ? currentMetricSlot : null;
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? gestureCardNodes : [];
const likeControl = {
  getAttribute: (name) => ({
    'data-waterfall-card-action': 'like',
    'data-waterfall-candidate-id': 'current'
  })[name] ?? ''
};
track.emit('click', {
  preventDefault: () => {},
  target: { closest: (selector) => selector === '[data-waterfall-card-action]' ? likeControl : null }
});
assert.deepEqual(actions.at(-1)?.args, {
  surfaceId: 'surface-1', candidateId: 'current', action: 'like', active: true
});
const writesBeforeCardActionAck = track.innerHTMLWrites;
const initialCandidates = window.__aiphoneWaterfallInitial.candidates;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [{ ...initialCandidates[0], metrics: [{ kind: 'like', value: 4321 }] },
    initialCandidates[1], initialCandidates[3], initialCandidates[2],
    ...initialCandidates.slice(4)],
  cardStates: [{ candidateId: 'current', reaction: 'like', saved: true }]
});
assert.equal(track.innerHTMLWrites, writesBeforeCardActionAck,
  'a card-action acknowledgement must not rebuild and flash the loaded card tree');
assert.match(currentMetricSlot.innerHTML, /data-waterfall-metric="like"[^>]*aria-label="\u70b9\u8d5e 4,321"/,
  'a card-action acknowledgement must not discard platform metrics arriving in the same payload');
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [{ ...initialCandidates[0], metrics: [{ kind: 'like', value: 4321 }] },
    initialCandidates[1], initialCandidates[3], initialCandidates[2],
    ...initialCandidates.slice(4)],
  cardStates: [{ candidateId: 'current', reaction: 'like', saved: true }]
});
assert.equal(track.innerHTMLWrites, writesBeforeCardActionAck,
  'the next provider update must keep action-reranked loaded cards stable too');
documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 700 }] });
documentListeners.touchmove?.({ touches: [{ clientX: 202, clientY: 560 }] });
const writesBeforeGesturePayload = track.innerHTMLWrites;
const appendsBeforeGesturePayload = track.appendedHtmlWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [initialCandidates[0], initialCandidates[1], candidate('reranked-during-swipe-a'),
    candidate('reranked-during-swipe-b'),
    ...initialCandidates.slice(2)]
});
assert.equal(track.innerHTMLWrites, writesBeforeGesturePayload,
  'a reranked provider tail must not rebuild the feed while the user is swiping');
documentListeners.touchend?.();
track.emit('click', { preventDefault: () => {}, target: { closest: () => null } });
runLatestTimer(96);
assert.equal(track.innerHTMLWrites, writesBeforeGesturePayload,
  'a settled provider update must not replace the visible card tree and reload its media');
assert.equal(track.appendedHtmlWrites, appendsBeforeGesturePayload,
  'a mid-list late card must not rebuild the track by appending at the end');
assert.equal(gestureCardNodes.some((node) => node.appendedHtmlWrites > 0), true,
  'newly ranked cards must slot in beside existing nodes without flashing them');
const sharedAnchorHtml = gestureCardNodes[2].innerHTML;
assert.ok(sharedAnchorHtml.indexOf('reranked-during-swipe-a') < sharedAnchorHtml.indexOf('reranked-during-swipe-b'),
  'multiple late cards inserted before one existing card must keep payload order');
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? gestureCardNodes : [];
track.innerHTML = '';
window.__aiphoneApplyWaterfallUpdate(window.__aiphoneWaterfallInitial);
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? compactCardNodes : [];
window.__aiphoneApplyWaterfallUpdate(window.__aiphoneWaterfallInitial);
const actionCountBeforePassiveUpdate = actionCount('waterfall.feed.advance');
window.__aiphoneApplyWaterfallUpdate(window.__aiphoneWaterfallInitial);
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforePassiveUpdate,
  'a compact first card must not advance merely because the next card is closer to the viewport center');
assert.equal(compactCardNodes[0].classList.contains('is-active'), true);
assert.equal(compactCardNodes[1].classList.contains('is-adjacent'), true);
assert.equal(compactCardNodes[2].classList.contains('is-distant'), false);
assert.equal(compactCardNodes[0].style.opacity, '', 'scroll presentation must not write opacity every frame');
assert.equal(compactCardNodes[0].style.transform, '', 'scroll presentation must not write transforms every frame');
track.querySelectorAll = () => [];
const dwellTimer = timers.find((timer) => timer.delay === 8000 && !timer.canceled);
assert.ok(dwellTimer, 'the visible current card must schedule one dwell timer');
now += 8000;
dwellTimer.callback();
assert.equal(actions.at(-1)?.id, 'waterfall.behavior.record');
assert.equal(actions.at(-1)?.args?.behavior, 'dwell');
assert.equal(actions.at(-1)?.args?.candidateId, 'current');

const videoCard = element();
const videoFullscreenButton = {
  ariaLabel: '全屏播放',
  setAttribute: (name, value) => {
    if (name === 'aria-label') videoFullscreenButton.ariaLabel = value;
  },
  closest: (selector) => selector === '.waterfall-card--video' ? videoCard : null
};
videoCard.querySelector = (selector) => selector === '[data-waterfall-video-fullscreen]' ? videoFullscreenButton : null;
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-video-fullscreen]' ? videoFullscreenButton : null
  }
});
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), true);
assert.equal(track.classList.contains('video-open'), true);
assert.equal(videoFullscreenButton.ariaLabel, '退出全屏');
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-video-fullscreen]' ? videoFullscreenButton : null
  }
});
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false);
assert.equal(track.classList.contains('video-open'), false);
assert.equal(videoFullscreenButton.ariaLabel, '全屏播放');

let videoOpenLayoutReads = 0;
const videoOpen = {
  getAttribute: (name) => name === 'data-waterfall-open' ? 'current' : '',
  getBoundingClientRect: () => {
    videoOpenLayoutReads += 1;
    return { top: 80, right: 380, bottom: 760, left: 20, width: 360, height: 680 };
  },
  closest: (selector) => selector === '.waterfall-card--video' ? videoCard : null
};
const sourceLink = { href: 'https://www.youtube.com/watch?v=abc123' };
const sourceTarget = {
  closest: (selector) => selector === '.waterfall-source-action' ? sourceLink :
    (selector === '[data-waterfall-open]' ? videoOpen : null)
};
let sourcePrevented = false;
track.emit('click', { target: sourceTarget, preventDefault: () => { sourcePrevented = true; } });
assert.equal(sourcePrevented, true);
assert.deepEqual(openedSources, ['https://www.youtube.com/watch?v=abc123']);
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false,
  'source actions must not activate their parent card');
const mediaTarget = {
  closest: (selector) => selector === '.waterfall-media-frame' ? {} :
    (selector === '[data-waterfall-open]' ? videoOpen : null)
};
track.emit('click', { target: mediaTarget });
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false,
  'embedded media must not activate its parent card');
const feedPlayFrame = element();
const feedPlayStage = element();
feedPlayStage.getAttribute = (name) => name === 'data-waterfall-video-url' ?
  'https://www.youtube.com/embed/abc123?playsinline=1' :
  (name === 'data-waterfall-video-kind' ? 'iframe' : '');
feedPlayStage.querySelector = (selector) => selector === '.waterfall-reader-video-frame' ?
  feedPlayFrame : null;
feedPlayStage.closest = (selector) => selector === '.waterfall-reader-video-stage' ? feedPlayStage : null;
feedPlayStage.closest = (selector) => selector === '.waterfall-reader-video-stage' ?
  feedPlayStage : null;
track.emit('click', {
  target: {
    closest: (selector) => selector === '.waterfall-reader-video-stage' ? feedPlayStage :
      (selector === '[data-waterfall-open]' ? videoOpen : null)
  }
});
assert.equal(reader.classList.contains('active'), false,
  'tapping the video stage must play in place instead of opening details');
assert.match(feedPlayFrame.innerHTML, /<iframe class="waterfall-media-frame"/,
  'the first tap on a video cover must start playback');
assert.equal(feedPlayStage.classList.contains('is-playing'), true);
documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 700 }] });
documentListeners.touchmove?.({ touches: [{ clientX: 202, clientY: 560 }] });
let swipeReleasePrevented = false;
const delayedSwipeTarget = {
  cancelable: true,
  preventDefault: () => { swipeReleasePrevented = true; },
  target: { closest: (selector) => selector === '[data-waterfall-open]' ? videoOpen : null }
};
track.emit('pointerup', delayedSwipeTarget);
track.emit('touchend', delayedSwipeTarget);
documentListeners.touchend?.();
assert.equal(swipeReleasePrevented, false,
  'delegated fast taps must not cancel the native end of a scrolling gesture');
now += 1000;
track.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-open]' ? videoOpen : null }
});
assert.equal(reader.classList.contains('active'), true,
  'the first click after scrolling must not be swallowed');
assert.equal(overlay.classList.contains('reading'), true,
  'open details must freeze the hidden feed through the overlay, not overflow');
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false,
  'the video card itself must not force fullscreen');
assert.equal(reader.classList.contains('active'), true,
  'the video card itself must open content details');
const writesBeforeReaderUpdate = track.innerHTMLWrites;
const appendsBeforeReaderUpdate = track.appendedHtmlWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('late-before-current'), ...window.__aiphoneWaterfallInitial.candidates.map((item) =>
    item.id === 'current' ? { ...item, summary: `${item.summary} live update` } : item)]
});
assert.equal(track.innerHTMLWrites, writesBeforeReaderUpdate,
  'live provider updates must not rebuild the feed behind an open reader');
assert.match(reader.innerHTML, /waterfall-reader--video/);
assert.match(reader.innerHTML, /class="waterfall-reader-copy"/);
assert.doesNotMatch(reader.innerHTML, /waterfall-reader-video-card|waterfall-reader-video-copy/);
assert.match(reader.innerHTML, /waterfall-reader-head-label">返回</);
assert.match(reader.innerHTML, /waterfall-reader-head-title">详情</);
assert.doesNotMatch(reader.innerHTML, /<iframe class="waterfall-media-frame"/,
  'opening video details must not load the remote player before a deliberate play press');
assert.match(reader.innerHTML, /waterfall-reader-video-frame/);
assert.match(reader.innerHTML, /data-waterfall-video-play/);
assert.match(reader.innerHTML, /waterfall-reader-video-fallback/);
assert.match(reader.innerHTML, /current summary tail/);
assert.equal(track.classList.contains('reader-open'), false,
  'opening details must not flip overflow on the underlying snap scroller');
assert.equal(videoOpenLayoutReads, 0,
  'opening details must not synchronously read card geometry that no reader style consumes');
assert.deepEqual(reader.style.values, {});
const videoFrame = element();
const videoStage = element();
videoStage.getAttribute = (name) => name === 'data-waterfall-video-url' ?
  'https://www.youtube.com/embed/abc123?playsinline=1' : (name === 'data-waterfall-video-kind' ? 'iframe' : '');
videoStage.querySelector = (selector) => selector === '.waterfall-reader-video-frame' ? videoFrame : null;
const playControl = {
  closest: (selector) => selector === '.waterfall-reader-video-stage' ? videoStage : null
};
reader.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-video-play]' ? playControl : null }
});
assert.equal(videoStage.classList.contains('is-playing'), true,
  'video details must reveal the player only after the play control is pressed');
assert.match(videoFrame.innerHTML, /<iframe class="waterfall-media-frame"/);
const readCompleteCountBeforeClose = actions.filter((action) => action.args?.behavior === 'read_complete').length;
now += 8001;
for (let swipe = 0; swipe < 3; swipe += 1) {
  documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 700 }] });
  documentListeners.touchmove?.({ touches: [{ clientX: 202, clientY: 420 }] });
  let readerSwipePrevented = false;
  const readerSwipeTarget = {
    cancelable: true,
    preventDefault: () => { readerSwipePrevented = true; },
    target: { closest: (selector) => selector === '.waterfall-reader-layout' ? {} : null }
  };
  reader.emit('pointerup', readerSwipeTarget);
  reader.emit('touchend', readerSwipeTarget);
  documentListeners.touchend?.();
  assert.equal(readerSwipePrevented, false,
    'detail scrolling must leave the native touch release untouched');
}
const readerFeedNodes = compactCardNodes.concat(gestureCardNodes.slice(compactCardNodes.length));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? readerFeedNodes : [];
let closeFeedTraversalCount = 0;
track.querySelectorAll = (selector) => {
  if (selector !== '[data-waterfall-id]') return [];
  closeFeedTraversalCount += 1;
  return readerFeedNodes;
};
track.scrollTop = 1324;
track.emit('scroll');
timers.filter((timer) => !timer.canceled && (timer.delay === 72 || timer.delay === 180))
  .forEach((timer) => { timer.canceled = true; });
track.scrollTop = 0;
const feedTraversalsBeforeReaderClose = closeFeedTraversalCount;
let readerTapPrevented = false;
const readerCloseTarget = { closest: (selector) => selector === '[data-waterfall-reader-close]' ? {} : null };
now += 100;
const readerCloseEvent = {
  cancelable: true,
  preventDefault: () => { readerTapPrevented = true; },
  target: readerCloseTarget
};
reader.emit('pointerdown', readerCloseEvent);
assert.equal(reader.classList.contains('closing'), false,
  'holding detail back must not remove the reader before the press is released');
assert.equal(readerTapPrevented, false,
  'the detail layer must leave the active pointer sequence intact until the tap is released');
reader.emit('touchstart', {
  touches: [{ clientX: 24, clientY: 80 }],
  target: readerCloseTarget
});
reader.emit('touchend', {
  cancelable: true,
  preventDefault: () => { readerTapPrevented = true; },
  changedTouches: [{ clientX: 24, clientY: 80 }],
  target: readerCloseTarget
});
assert.equal(reader.classList.contains('closing'), true,
  'the first completed back tap after detail scrolling must close on touchend');
assert.equal(readerTapPrevented, true, 'reader back must commit on touchend after nested scrolling');
assert.equal(closeFeedTraversalCount, feedTraversalsBeforeReaderClose,
  'reader back must paint its closing state before any hidden-feed DOM traversal');
assert.equal(compactCardNodes[0].classList.contains('is-active'), true,
  'reader back must restore the visible card before revealing the feed');
track.querySelectorAll = () => [];
reader.emit('click', { preventDefault: () => {}, target: readerCloseTarget });
assert.equal(timers.filter((timer) => timer.delay === 180 && !timer.canceled).length, 1,
  'the delayed synthetic click must not close the reader twice');
assert.equal(actions.filter((action) => action.args?.behavior === 'read_complete').length, readCompleteCountBeforeClose,
  'the native behavior bridge must not block the first frame of the return transition');
const returnScrollSettleCount = timers.filter((timer) => timer.delay === 96 && !timer.canceled).length;
track.scrollTop = 640;
track.emit('scroll');
assert.equal(timers.filter((timer) => timer.delay === 96 && !timer.canceled).length,
  returnScrollSettleCount + 1,
  'the feed must accept a new scroll while the reader is finishing its visual close');
finishReaderClose();
assert.equal(track.scrollTop, 640,
  'closing details must not rewind a return gesture that already moved the feed');
assert.equal(overlay.classList.contains('reading'), false,
  'the feed must be tappable again as soon as details hide');
assert.equal(track.innerHTMLWrites, writesBeforeReaderUpdate,
  'returning from details must not synchronously rebuild the discovery feed');
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? readerFeedNodes : [];
runLatestTimer(96);
assert.equal(timers.filter((timer) => timer.delay === 240 && !timer.canceled).length, 0,
  'reader return must not add a second fixed wait before applying a deferred payload');
assert.equal(track.innerHTMLWrites, writesBeforeReaderUpdate,
  'the latest deferred provider update must preserve the revealed card DOM');
assert.equal(
  track.appendedHtmlWrites > appendsBeforeReaderUpdate ||
    readerFeedNodes.some((node) => node.appendedHtmlWrites > 0),
  true,
  'the deferred provider update may insert its new card without rebuilding the revealed card'
);
assert.equal(track.scrollTop, 640,
  'a deferred rerank must keep the position reached by the return gesture');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\s*\{[^}]*will-change:\s*transform/s,
  'a long scrolling reader must not stay promoted as one transformed layer');
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*transform:\s*none/s,
  'the open reader must drop its transform so nested Bilibili iframes can play');
const readerBodyCss = waterfallCss.slice(
  waterfallCss.indexOf('\n.waterfall-reader-body {'),
  waterfallCss.indexOf('\n.waterfall-reader.active .waterfall-reader-body')
);
assert.doesNotMatch(readerBodyCss, /transform:/,
  'the long reader scroller itself must not be a transformed layer');
assert.equal(actions.filter((action) => action.args?.behavior === 'read_complete').length, readCompleteCountBeforeClose + 1);
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false);
assert.equal(track.classList.contains('video-open'), false);
assert.equal(reader.classList.contains('active'), false);
leftoverFeedClickMustNotOpen(videoOpen);
assert.ok(reader.innerHTML.length > 0,
  'closing details must keep the reader layer mounted');
const readerWritesAfterFirstClose = reader.innerHTMLWrites;
openFeedCard(videoOpen);
assert.equal(reader.classList.contains('active'), true,
  'a new tap on the same card after returning must open details again');
assert.equal(overlay.classList.contains('reading'), true);
assert.equal(reader.innerHTMLWrites, readerWritesAfterFirstClose,
  'reopening the same card must not rebuild the reader');
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
leftoverFeedClickMustNotOpen(videoOpen);
assert.equal(reader.classList.contains('active'), false);

const oldReturnNodes = Array.from({ length: 8 }, (_, index) =>
  Object.assign(element(), { offsetTop: index * 1000, offsetHeight: 1000 }));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? oldReturnNodes : [];
track.scrollTop = 3000;
const nonCurrentOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'text-current' : '' };
openFeedCard(nonCurrentOpen);
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('new-late'), candidate('late-before-current'),
    ...window.__aiphoneWaterfallInitial.candidates]
});
const idleReturnAppendsBeforeClose = track.appendedHtmlWrites +
  oldReturnNodes.reduce((total, node) => total + node.appendedHtmlWrites, 0);
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
assert.equal(track.appendedHtmlWrites + oldReturnNodes.reduce((total, node) => total + node.appendedHtmlWrites, 0),
  idleReturnAppendsBeforeClose,
  'the close task must yield the first feed frame before applying a deferred payload');
assert.equal(timers.filter((timer) => timer.delay === 240 && !timer.canceled).length, 0,
  'an idle reader return must apply the latest payload without a delayed second refresh');
runLatestTimer(0);
assert.equal(track.scrollTop, 3000,
  'returning after a deferred update must preserve the exact captured feed position');

const bilibiliOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'portrait-current' : '' };
leftoverFeedClickMustNotOpen(bilibiliOpen);
openFeedCard(bilibiliOpen);
assert.match(reader.innerHTML, /class="waterfall-reader-copy"/);
assert.doesNotMatch(reader.innerHTML, /waterfall-reader-video-card|waterfall-reader-video-copy/);
assert.match(reader.innerHTML, /player\.bilibili\.com\/player\.html\?bvid=BV1xx411c7mD/);
assert.doesNotMatch(reader.innerHTML, /<iframe class="waterfall-media-frame"/);
assert.match(reader.innerHTML, /data-waterfall-video-play/,
  'Bilibili detail must defer its iframe until playback is explicitly requested');
assert.match(reader.innerHTML, />B 站</);
assert.match(reader.innerHTML, /class="waterfall-author-avatar"[^>]*avatar\.jpg/);
assert.match(reader.innerHTML, /class="waterfall-reader-signals"/);
assert.match(reader.innerHTML, />9\.9万</,
  'detail metrics must use the card-like compact value with one decimal');
assert.doesNotMatch(reader.innerHTML, />98,659</,
  'detail metrics must not expose exact large counts');
assert.match(reader.innerHTML, />投币</);
assert.match(reader.innerHTML, />弹幕</);
assert.match(reader.innerHTML, />分享</);
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
assert.equal(reader.classList.contains('active'), false);

const portraitCard = element();
portraitCard.classList.add('waterfall-card--landscape');
track.emit('load', {
  target: {
    naturalWidth: 900,
    naturalHeight: 1600,
    classList: { contains: (name) => name === 'waterfall-media-cover' },
    closest: (selector) => selector === '[data-waterfall-media-type="video"]' ? portraitCard : null
  }
});
assert.equal(portraitCard.classList.contains('waterfall-card--landscape'), true,
  'cover decoding must not change the snap geometry selected by the payload');
assert.equal(portraitCard.classList.contains('waterfall-card--portrait'), false);

track.scrollTop = 320;
const textOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'text-current' : '' };
leftoverFeedClickMustNotOpen(textOpen);
openFeedCard(textOpen);
now += 4000;
document.hidden = true;
documentListeners.visibilitychange();
now += 12000;
document.hidden = false;
documentListeners.visibilitychange();
now += 4000;
assert.equal(reader.classList.contains('active'), true);
assert.equal(track.classList.contains('reader-open'), false);
assert.equal(overlay.classList.contains('reading'), true);
assert.match(reader.innerHTML, /waterfall-reader--text/);
assert.doesNotMatch(reader.innerHTML, /waterfall-reader-media/);
assert.match(reader.innerHTML, /class="waterfall-reader-copy"/);
assert.match(reader.innerHTML, /A long text summary for the dedicated reader/);
assert.match(reader.innerHTML, /DETAIL_BODY_END/,
  'detail paragraph layout must preserve the complete body tail');
assert.equal(track.scrollTop, 320, 'opening the reader must preserve the feed position');
assert.doesNotMatch(reader.innerHTML, /data-waterfall-reader-hotzone/);
reader.emit('click', {
  target: { closest: (selector) => selector === '.waterfall-reader-layout' ? {} : null }
});
assert.equal(reader.classList.contains('active'), true,
  'tapping inside the detail card must keep it open');
track.scrollTop = 880;
let readerBackdropTapPrevented = false;
reader.emit('click', {
  cancelable: true,
  preventDefault: () => { readerBackdropTapPrevented = true; },
  target: { closest: () => null }
});
assert.equal(reader.classList.contains('closing'), true,
  'tapping outside the detail card must return to the discovery feed');
assert.equal(track.scrollTop, 880,
  'the close tap must not relayout the hidden feed on the same frame');
assert.equal(readerBackdropTapPrevented, true);
reader.emit('click', { preventDefault: () => {}, target: { closest: () => null } });
finishReaderClose();
assert.equal(track.scrollTop, 320,
  'returning from details must restore the feed position captured when the card opened');
assert.equal(reader.classList.contains('active'), false);
assert.equal(track.classList.contains('reader-open'), false);
assert.equal(overlay.classList.contains('reading'), false);
assert.equal(actions.at(-1)?.args?.behavior, 'read_complete');
assert.equal(actions.at(-1)?.args?.durationMs, 8000, 'hidden reader time must not count');

const imageOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'image-current' : '' };
let prevented = false;
track.emit('keydown', {
  key: 'Enter',
  preventDefault: () => { prevented = true; },
  target: { closest: (selector) => selector === '[data-waterfall-open]' ? imageOpen : null }
});
assert.equal(prevented, true);
assert.equal(reader.classList.contains('active'), true);
assert.match(reader.innerHTML, /waterfall-reader--image-text/);
assert.match(reader.innerHTML, /class="waterfall-reader-media"/);
assert.match(reader.innerHTML, /class="waterfall-reader-copy"/);
assert.match(reader.innerHTML, /https:\/\/example\.test\/image\.jpg/);
assert.match(reader.innerHTML, /onerror="this\.hidden=true"/);
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
assert.equal(reader.classList.contains('active'), false);
assert.equal(track.scrollTop, 320, 'closing the reader must restore the same feed position');

const nativeVideoCard = { getAttribute: (name) => name === 'data-waterfall-id' ? 'current' : '' };
track.emit('ended', {
  target: {
    tagName: 'VIDEO', duration: 12,
    closest: (selector) => selector === '[data-waterfall-id]' ? nativeVideoCard : null
  }
});
assert.equal(actions.at(-1)?.args?.behavior, 'play_complete');
assert.equal(actions.at(-1)?.args?.durationMs, 12000);
const behaviorCountBeforeIframeEnd = actionCount('waterfall.behavior.record');
track.emit('ended', { target: { tagName: 'IFRAME', closest: () => nativeVideoCard } });
assert.equal(actionCount('waterfall.behavior.record'), behaviorCountBeforeIframeEnd,
  'iframe playback completion must never be invented');

track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? [
  Object.assign(element(), { offsetTop: 18, offsetHeight: 700 }),
  Object.assign(element(), { offsetTop: 746, offsetHeight: 700 }),
  Object.assign(element(), { offsetTop: 1474, offsetHeight: 700 }),
  Object.assign(element(), { offsetTop: 2202, offsetHeight: 700 })
] : [];
track.scrollTop = 0;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
assert.equal(track.scrollTop, 0);
const writesAfterChangedUpdate = track.innerHTMLWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
assert.equal(track.innerHTMLWrites, writesAfterChangedUpdate, 'unchanged media cards must not be rebuilt');
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')],
  replenishing: true
});
assert.equal(track.innerHTMLWrites, writesAfterChangedUpdate, 'replenishing toggles must not rebuild cards');
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')],
  replenishing: false
});
assert.equal(track.innerHTMLWrites, writesAfterChangedUpdate, 'replenishing settling must not rebuild cards');
const actionCountBeforeHalfScroll = actionCount('waterfall.feed.advance');
track.scrollTop = 180;
track.emit('scroll');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeHalfScroll);
track.scrollTop = 728;
track.emit('scroll');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeHalfScroll,
  'the native advance bridge must wait until scrolling settles');
runLatestTimer(96);
runLatestTimer(72);
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
assert.equal(actions.at(-1)?.args?.currentId, 'current');
assert.equal(actions.at(-1)?.args?.visibleId, 'image-current',
  'a settled page must report the visible card so native can catch up in one step');

const actionCountBeforeCatchUp = actionCount('waterfall.feed.advance');
const writesBeforeCurrentAdvance = track.innerHTMLWrites;
track.scrollTop = 1200;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'image-current',
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
runLatestTimer(72);
assert.equal(track.scrollTop, 1200, 'server updates must not snap the user back to the first card');
assert.equal(track.innerHTMLWrites, writesBeforeCurrentAdvance, 'advancing must keep loaded media nodes alive');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeCatchUp + 1,
  'a rapid multi-card swipe should continue advancing');
assert.equal(actions.at(-1)?.args?.currentId, 'image-current');

track.scrollTop = 0;
const actionCountBeforeBackScroll = actionCount('waterfall.feed.advance');
track.emit('scroll');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeBackScroll,
  'scrolling back into shown history must stay local');

const xCurrent = { ...candidate('x-current'), source: 'x', mediaType: 'post' };
const xNext = { ...candidate('x-next'), source: 'x', mediaType: 'post' };
track.scrollTop = 2960;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'x-current',
  enabledSources: ['x'],
  candidates: [candidate('disabled-one'), candidate('disabled-two'), xCurrent, xNext]
});
runLatestTimer(96);
assert.equal(track.scrollTop, 0, 'source filtering must align to the enabled current card instead of an empty tail');
const actionCountBeforeFilteredAdvance = actionCount('waterfall.feed.advance');
track.scrollTop = 960;
track.emit('scroll');
runLatestTimer(96);
runLatestTimer(72);
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeFilteredAdvance + 1,
  'advance indices must use the filtered card list');
assert.equal(actions.at(-1)?.args?.currentId, 'x-current');

window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'last',
  candidates: [candidate('last')],
  replenishing: false,
  exhausted: false
});
assert.doesNotMatch(track.innerHTML, /waterfall-tail-status/, 'a continuable feed must not render a fake end card');
const actionCountBeforeLastCard = actionCount('waterfall.feed.advance');
track.scrollTop = 960;
track.emit('scroll');
runLatestTimer(96);
runLatestTimer(72);
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeLastCard + 1);
assert.equal(actions.at(-1)?.args?.currentId, 'last');

const stressCandidates = Array.from({ length: 60 }, (_, index) => candidate(`stress-${index}`));
const stressNodes = stressCandidates.map((_, index) =>
  Object.assign(element(), { offsetTop: index * 1000, offsetHeight: 1000 }));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? stressNodes : [];
track.scrollTop = 0;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'stress-0',
  candidates: stressCandidates
});
const classWritesBeforeFastScroll = stressNodes.reduce((sum, node) => sum + node.classToggleWrites, 0);
const pagingTimerCountBeforeFastScroll = timers.filter((timer) => timer.delay === 72 || timer.delay === 180).length;
for (let index = 1; index <= 20; index += 1) {
  track.scrollTop = index * 1000;
  track.emit('scroll');
}
const classWritesAfterFastScroll = stressNodes.reduce((sum, node) => sum + node.classToggleWrites, 0);
assert.ok(classWritesAfterFastScroll - classWritesBeforeFastScroll <= 160,
  'fast scrolling must update only the current card and its neighbors, not all cards per frame');
assert.equal(
  timers.filter((timer) => timer.delay === 72 || timer.delay === 180).length,
  pagingTimerCountBeforeFastScroll,
  'scroll frames must not churn advance and media-cleanup timers before the page settles'
);
timers.filter((timer) => !timer.canceled && (timer.delay === 72 || timer.delay === 180))
  .forEach((timer) => { timer.canceled = true; });
runLatestTimer(96);

preferencesButton.emit('click');
assert.equal(preferences.classList.contains('active'), true);
assert.equal(overlay.classList.contains('sheet-open'), true,
  'the source sheet must freeze the feed through the overlay, not overflow');
const preferenceWritesAfterFirstOpen = preferences.innerHTMLWrites;
const sourceSelectionCountBeforeToggle = actionCount('waterfall.sources.select');
assert.match(preferences.innerHTML, /data-waterfall-sources-all/);
assert.match(preferences.innerHTML, /data-waterfall-sources-none/);
assert.match(preferences.innerHTML,
  /<div class="waterfall-toolbar">[\s\S]*?<div class="waterfall-source-bulk"[\s\S]*?data-waterfall-sources-none[\s\S]*?data-waterfall-apply-preferences[\s\S]*?<div class="waterfall-source-grid">/,
  'bulk source actions must stay inside the source sheet toolbar');
preferences.emit('click', { preventDefault: () => {}, target: preferenceNoneButton });
assert.equal(sourceInputs.every((input) => !input.checked), true,
  'select none must clear every available source locally');
preferences.emit('click', { preventDefault: () => {}, target: preferenceAllButton });
assert.equal(sourceInputs.filter((input) => !input.disabled).every((input) => input.checked), true,
  'select all must enable every available source');
assert.equal(sourceInputs.filter((input) => input.disabled).every((input) => !input.checked), true,
  'select all must leave unavailable sources disabled');
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle,
  'bulk selection must wait for Done before crossing the native bridge');
sourceInputs[0].checked = false;
sourceInputs[0].emit('change');
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle,
  'toggling a source must stay local so the control responds immediately');
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'queued-preference-payload',
  candidates: [{ ...candidate('queued-preference-payload'), source: 'bilibili' }],
  enabledSources: sourceInputs.map((input) => input.getAttribute('data-waterfall-source'))
});
const preferenceTouch = { clientX: 120, clientY: 120 };
documentListeners.touchstart({ touches: [preferenceTouch], target: preferenceDoneButton });
preferences.emit('touchstart', { touches: [preferenceTouch], target: preferenceDoneButton });
let preferenceTapPrevented = false;
let preferenceTouchStopped = false;
const preferenceTouchEnd = {
  cancelable: true,
  changedTouches: [preferenceTouch],
  preventDefault: () => { preferenceTapPrevented = true; },
  stopPropagation: () => { preferenceTouchStopped = true; },
  target: preferenceDoneButton
};
preferences.emit('touchend', preferenceTouchEnd);
assert.match(track.innerHTML, /queued-preference-payload/,
  'closing source settings must apply the selected sources before an immediate swipe can start');
if (!preferenceTouchStopped) {
  documentListeners.touchend?.(preferenceTouchEnd);
  runLatestTimer(96);
} else {
  const deferredPreferenceTimer = timers.filter((timer) => timer.delay === 240 && !timer.canceled).at(-1);
  if (deferredPreferenceTimer) {
    deferredPreferenceTimer.canceled = true;
    deferredPreferenceTimer.callback();
  }
}
assert.match(track.innerHTML, /queued-preference-payload/,
  'closing source settings must let the queued payload flush after the exit motion');
assert.equal(preferences.classList.contains('active'), false);
assert.equal(overlay.classList.contains('sheet-open'), false,
  'the source sheet and feed lock must close in the same interaction');
assert.equal(preferenceTapPrevented, true, 'source done must use the single native click path');
assert.equal(preferenceTouchStopped, true,
  'source settings must consume the closing touchend before the document settles a queued stale payload');
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle + 1,
  'source selection must commit without a delayed close phase');
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle + 1);
preferencesButton.emit('click');
assert.equal(sourceInputs[0].checked, false,
  'a queued payload must not revert the source selection made before closing');
assert.equal(preferences.innerHTMLWrites, preferenceWritesAfterFirstOpen,
  'reopening source settings must not rebuild the sheet');
sourceInputs[1].checked = false;
sourceInputs[1].emit('change');
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-preference-payload',
  candidates: [{ ...candidate('late-preference-payload'), source: 'x' }],
  enabledSources: sourceInputs.map((input) => input.getAttribute('data-waterfall-source'))
});
assert.match(track.innerHTML, /late-preference-payload/,
  'a source response after close must apply immediately instead of waiting on an exit timer');
preferencesButton.emit('click');
assert.equal(sourceInputs[1].checked, false,
  'a payload arriving during the exit motion must not revert the source selection');
let preferenceBackPrevented = false;
preferences.emit('click', {
  preventDefault: () => { preferenceBackPrevented = true; },
  target: preferenceBackButton
});
assert.equal(preferences.classList.contains('active'), false);
assert.equal(preferenceBackPrevented, true, 'source back must use the delegated native click path');
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  sources: [{ source: 'youtube', phase: 'success' }]
});
preferencesButton.emit('click');
assert.match(preferences.innerHTML, /data-waterfall-source="twitch" disabled/,
  'a later partial source update must not re-enable a known unavailable source');
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-preference-payload',
  candidates: [{ ...candidate('late-preference-payload'), source: 'x' }],
  enabledSources: sourceInputs.filter((input) => input.checked)
    .map((input) => input.getAttribute('data-waterfall-source'))
});
preferencesButton.emit('click');
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true']);
assert.equal(preferences.classList.contains('active'), false);
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true', 'false']);
assert.equal(overlay.classList.contains('active'), true, 'the overlay must remain mounted while it fades out');
assert.equal(overlay.classList.contains('closing'), true);
assert.equal(timers.at(-1)?.delay, 140);
timers.at(-1)?.callback();
assert.equal(overlay.classList.contains('active'), false);
assert.equal(overlay.classList.contains('closing'), false);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: [],
  aggregateHtml: '',
  candidates: [candidate('current'), candidate('next')],
  sources: [{ source: 'youtube', phase: 'success' }],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /data-waterfall-empty-sources/);
assert.doesNotMatch(track.innerHTML, /本轮内容已结束/);

const statusDetails = { open: true };
const statusListeners = {};
const statusDocument = {
  querySelectorAll: () => [],
  getElementById: () => null,
  addEventListener: (type, listener) => { statusListeners[type] = listener; }
};
vm.runInNewContext(aggregateJs, {
  document: statusDocument,
  window: {}
});
statusListeners.click({
  target: {
    closest: (selector) => selector === '[data-status-close]' ? {
      closest: () => statusDetails
    } : null
  }
});
assert.equal(statusDetails.open, false);
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-empty-sources]' ? {} : null
  }
});
assert.equal(preferences.classList.contains('active'), true);
assert.match(preferences.innerHTML, /class="waterfall-source-logo"/);
assert.match(preferences.innerHTML, /data:image\/png;base64,logo/);
assert.match(preferences.innerHTML, /data-waterfall-source="youtube"/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [{ source: 'youtube', phase: 'success' }],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /至少开启一个来源/,
  'provider updates must stay deferred while the source sheet is interactive');
sourceInputs.forEach((input) => { input.checked = false; });
sourceInputs[0].checked = true;
sourceInputs[0].emit('change');
preferences.emit('click', { preventDefault: () => {}, target: preferenceBackButton });
assert.match(track.innerHTML, /本轮内容已结束/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.match(track.innerHTML, /data-waterfall-empty-sources[^>]*>调整内容来源<\/button>/);
preferences.classList.remove('active');
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-empty-sources]' ? {} : null
  }
});
assert.equal(preferences.classList.contains('active'), true,
  'terminal empty state must allow reopening source preferences');
assert.match(preferences.innerHTML, /data-waterfall-source="youtube"/);
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [],
  replenishing: true,
  exhausted: false
});
assert.match(track.innerHTML, /正在补充内容/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /本轮内容已结束/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [{
    source: 'youtube',
    phase: 'error',
    continuation: { kind: 'cursor', value: 'next' },
    inFlight: false
  }],
  replenishing: false,
  exhausted: false
});
assert.match(track.innerHTML, /正在汇集内容…/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /本轮内容已结束/);

const disabledCandidate = candidate('disabled-x');
disabledCandidate.source = 'x';
window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [disabledCandidate],
  sources: [
    { source: 'youtube', phase: 'exhausted', continuation: null, inFlight: false },
    { source: 'x', phase: 'loading', continuation: null, inFlight: true }
  ],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /本轮内容已结束/);
assert.doesNotMatch(track.innerHTML, /disabled-x/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['x'],
  aggregateHtml: '',
  candidates: [disabledCandidate],
  sources: [
    { source: 'youtube', phase: 'exhausted', continuation: null, inFlight: false },
    { source: 'x', phase: 'success', continuation: null, inFlight: false }
  ],
  replenishing: false,
  exhausted: false
});
assert.match(track.innerHTML, /disabled-x/);
assert.doesNotMatch(track.innerHTML, /本轮内容已结束/);

track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? compactCardNodes : [];
window.__aiphoneApplyWaterfallUpdate(window.__aiphoneWaterfallInitial);
documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 700 }] });
track.scrollTop = 596;
track.emit('scroll');
assert.equal(track.scrollTop, 596,
  'live scroll must follow the finger instead of snapping mid-gesture');
assert.equal(track.classList.contains('is-scrolling'), false,
  'native snap and card transitions must remain enabled while the feed moves');
assert.equal(compactCardNodes[1].classList.contains('is-active'), true,
  'the incoming card must highlight on the scroll frame, not after settle');
assert.equal(compactCardNodes[0].classList.contains('is-active'), false,
  'the outgoing card must not stay fully opaque under the moving feed');
documentListeners.touchend?.();
assert.equal(track.scrollTop, 596,
  'touchend must not overwrite the native inertial position');
track.scrollTop = 1324;
track.emit('scroll');
assert.equal(track.scrollTop, 1324,
  'post-touchend inertia must continue without a JavaScript snap-back');
assert.equal(compactCardNodes[2].classList.contains('is-active'), true,
  'highlight must follow the nearest snap during inertia without waiting for settle');
assert.equal(compactCardNodes[1].classList.contains('is-active'), false,
  'the previous card must dim as soon as the next snap is closer');

const mediaStage = { hidden: false };
const failedCover = {
  hidden: false,
  classList: { contains: (name) => name === 'waterfall-media-cover' },
  closest: (selector) => selector === '.waterfall-cinema-stage' ? mediaStage : null
};
const timerCountBeforeCoverError = timers.length;
track.emit('error', { target: failedCover });
assert.equal(failedCover.hidden, true, 'a broken cover image must hide itself');
assert.equal(mediaStage.hidden, false, 'the fixed media stage must keep its geometry');
assert.equal(timers.length, timerCountBeforeCoverError,
  'preserving the stage means a cover error must not schedule a metric refresh');

documentListeners.touchend?.();
runLatestTimer(96);
const keptCandidate = candidate('kept-card');
const trailingCandidate = candidate('trailing-card');
const rebuildNodes = Array.from({ length: 3 }, (_, index) =>
  Object.assign(element(), { offsetTop: 18 + index * 728, offsetHeight: 700 }));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? rebuildNodes : [];
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'kept-card',
  candidates: [keptCandidate, candidate('dropped-card'), trailingCandidate]
});
assert.match(track.innerHTML, /kept-card/, 'the ranked payload must reach the feed before the drop case');
const droppedFeedNodes = Array.from({ length: 3 }, (_, index) =>
  Object.assign(element(), { offsetTop: 18 + index * 728, offsetHeight: 700 }));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? droppedFeedNodes : [];
const writesBeforeDrop = track.innerHTMLWrites;
const appendsBeforeDrop = track.appendedHtmlWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'kept-card',
  candidates: [keptCandidate, trailingCandidate, candidate('appended-card')]
});
assert.equal(track.innerHTMLWrites, writesBeforeDrop,
  'a card leaving the ranked payload must not rebuild the whole feed under the user');
assert.equal(droppedFeedNodes[1].removed, true,
  'only the card that left the payload may be detached');
assert.equal(droppedFeedNodes[0].removed, undefined,
  'the card the user is looking at must survive a payload that drops a neighbor');
assert.equal(track.appendedHtmlWrites, appendsBeforeDrop + 1,
  'newly ranked cards must still append after the surviving cards');
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

const commentsCandidate = {
  ...candidate('comments-current'),
  providerItemId: 'youtube-comments-video'
};
const commentsPayload = (overrides = {}) => ({
  surfaceId: 'surface-1',
  currentId: 'comments-current',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [{ ...commentsCandidate, ...overrides }],
  mediaEmbeds: {},
  sources: [{ source: 'youtube', phase: 'success' }],
  replenishing: false,
  exhausted: false
});
window.__aiphoneApplyWaterfallUpdate(commentsPayload());
const commentsOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'comments-current' : '' };
const commentActionsBeforeOpen = actionCount('waterfall.comments.load');
openFeedCard(commentsOpen);
assert.equal(reader.classList.contains('active'), true,
  'detail content must open before comment data is available');
assert.match(reader.innerHTML, /评论精选/);
assert.match(reader.innerHTML, /waterfall-comment-skeleton/,
  'supported details must paint a compact loading state immediately');
assert.equal(actionCount('waterfall.comments.load'), commentActionsBeforeOpen,
  'opening details must return before the native comment request is dispatched');
runLatestTimer(0);
assert.equal(actionCount('waterfall.comments.load'), commentActionsBeforeOpen + 1);
assert.deepEqual(Object.keys(actions.at(-1)?.args ?? {}).sort(), ['candidateId', 'surfaceId']);
assert.equal(actions.at(-1)?.args?.candidateId, 'comments-current');

const commentsSlot = element();
const readerMetricSlot = element();
reader.querySelector = (selector) => selector === '.waterfall-reader-head' ? readerHead :
  (selector === '[data-waterfall-comments-slot]' ? commentsSlot :
    (selector === '[data-waterfall-reader-metrics]' ? readerMetricSlot : null));
window.__aiphoneApplyWaterfallUpdate(commentsPayload({
  commentLoadState: 'ready',
  metrics: [{ kind: 'like', value: 9876 }],
  comments: Array.from({ length: 6 }, (_, index) => ({
    text: index === 0 ? '<b>第一条评论</b>' : `第 ${index + 1} 条评论`,
    authorName: index === 0 ? '评论者' : '',
    authorAvatarUrl: index === 0 ? 'https://img.example/avatar.png' : '',
    publishedAt: index === 0 ? '2026-08-24T00:00:00.000Z' : '',
    likeCount: index === 0 ? 12 : undefined,
    replyCount: index === 0 ? 3 : undefined
  }))
}));
assert.equal((commentsSlot.innerHTML.match(/data-waterfall-comment-toggle/g) ?? []).length, 5,
  'detail comments must show at most five rows');
assert.match(readerMetricSlot.innerHTML, /data-waterfall-metric="like"/,
  'detail metrics must update alongside an asynchronous comment payload');
assert.match(commentsSlot.innerHTML, /&lt;b&gt;第一条评论&lt;\/b&gt;/);
assert.doesNotMatch(commentsSlot.innerHTML, /第 6 条评论/);
let commentExpanded = 'false';
const commentRow = {
  getAttribute: (name) => name === 'aria-expanded' ? commentExpanded : '',
  setAttribute: (name, value) => { if (name === 'aria-expanded') commentExpanded = value; },
  closest: (selector) => selector === '[data-waterfall-comment-toggle]' ? commentRow : null
};
reader.emit('click', { target: commentRow });
assert.equal(commentExpanded, 'true', 'tapping a comment row must expand its two-line preview');
reader.emit('click', { target: commentRow });
assert.equal(commentExpanded, 'false', 'tapping the expanded row must collapse it');
window.__aiphoneApplyWaterfallUpdate(commentsPayload({ commentLoadState: 'empty', comments: [] }));
assert.equal(commentsSlot.innerHTML, '', 'empty or unavailable comments must occupy no detail space');
reader.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-reader-close]' ? {} : null }
});
finishReaderClose();
reader.querySelector = (selector) => selector === '.waterfall-reader-head' ? readerHead : null;

function inlinePlayerFixture(source, id) {
  const card = element();
  const stage = {
    children: [],
    appendChild: (child) => { stage.children.push(child); }
  };
  const button = {
    hidden: false,
    disabled: false,
    textContent: '播放',
    getAttribute: (name) => name === (source === 'applepodcasts' ? 'data-waterfall-apple-play' :
      'data-waterfall-inline-play') ? id : '',
    closest: (selector) => {
      if (source === 'applepodcasts' && selector === '[data-waterfall-apple-play]') return button;
      if (source === 'twitch' && selector === '[data-waterfall-inline-play]') return button;
      if (selector === '.waterfall-cinema-stage') return stage;
      if (selector === '[data-waterfall-id]') return card;
      return null;
    }
  };
  card.getAttribute = (name) => name === 'data-waterfall-id' ? id : '';
  card.querySelector = (selector) => {
    if (selector === '.waterfall-cinema-stage') return stage;
    if (source === 'applepodcasts' && selector === '[data-waterfall-apple-play]') return button;
    if (source === 'twitch' && selector === '[data-waterfall-inline-play]') return button;
    return null;
  };
  return { button, card, stage };
}

const appleCandidate = {
  ...candidate('apple-podcast-1'),
  source: 'applepodcasts',
  mediaType: 'image_text',
  url: 'https://podcasts.apple.com/us/podcast/apple-events-video/id275834665',
  feedUrl: 'https://feeds.example.com/apple-events.xml',
  coverUrl: 'https://img.example/apple-podcast.jpg'
};
const twitchCandidate = {
  ...candidate('twitch-channel-1'),
  source: 'twitch',
  mediaType: 'image_text',
  url: 'https://www.twitch.tv/example',
  coverUrl: 'https://img.example/twitch.jpg'
};
const sourcePayload = (appleOverrides = {}) => ({
  surfaceId: 'surface-1',
  currentId: 'apple-podcast-1',
  enabledSources: ['applepodcasts', 'twitch'],
  aggregateHtml: '',
  candidates: [{ ...appleCandidate, ...appleOverrides }, twitchCandidate],
  mediaEmbeds: {},
  sources: [{ source: 'applepodcasts', phase: 'success' }, { source: 'twitch', phase: 'success' }],
  replenishing: false,
  exhausted: false
});
window.__aiphoneApplyWaterfallUpdate(sourcePayload());
assert.match(track.innerHTML, /data-waterfall-apple-play="apple-podcast-1"/);
assert.match(track.innerHTML, /data-waterfall-apple-play="apple-podcast-1"[^>]*>加载节目<\/button>/);
assert.match(track.innerHTML, /data-waterfall-inline-play="twitch-channel-1"/);
assert.match(track.innerHTML,
  /<article[^>]*data-waterfall-id="apple-podcast-1"[^>]*><div class="waterfall-card-shell">/,
  'Apple Podcasts source-only cards must use a non-interactive shell');
assert.match(track.innerHTML,
  /<article[^>]*data-waterfall-id="twitch-channel-1"[^>]*><div class="waterfall-card-shell">/,
  'Twitch source-only cards must use a non-interactive shell');
assert.match(track.innerHTML,
  /data-waterfall-id="apple-podcast-1"[\s\S]*?class="waterfall-cinema-copy" role="button" tabindex="0" data-waterfall-open="apple-podcast-1"/,
  'Apple Podcasts card copy must open details without swallowing inline playback');
assert.match(track.innerHTML,
  /data-waterfall-id="twitch-channel-1"[\s\S]*?class="waterfall-cinema-copy" role="button" tabindex="0" data-waterfall-open="twitch-channel-1"/,
  'Twitch card copy must open details without swallowing inline playback');
assert.doesNotMatch(track.innerHTML,
  /<article[^>]*data-waterfall-id="(?:apple-podcast-1|twitch-channel-1)"[^>]*><div class="[^"]*waterfall-card-shell--interactive/,
  'source-only media cards must not inherit whole-card press feedback');
assert.doesNotMatch(track.innerHTML, /<audio|player\.twitch\.tv/,
  'new-source players must not load before an explicit click');

const applePlayer = inlinePlayerFixture('applepodcasts', 'apple-podcast-1');
const twitchPlayer = inlinePlayerFixture('twitch', 'twitch-channel-1');
const sourceCards = [applePlayer.card, twitchPlayer.card];
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? sourceCards : [];
track.querySelector = () => null;
const framesBeforeInlinePlay = createdFrames.length;
const actionsBeforeApplePlay = actions.length;
track.emit('click', { target: applePlayer.button });
assert.equal(createdFrames.length, framesBeforeInlinePlay, 'Apple click must resolve RSS before creating media');
assert.equal(actions.length, actionsBeforeApplePlay + 1);
assert.equal(actions.at(-1)?.id, 'waterfall.applepodcasts.resolve');
assert.deepEqual(Object.keys(actions.at(-1)?.args ?? {}).sort(), ['candidateId', 'surfaceId']);
assert.equal(actions.at(-1)?.args?.candidateId, 'apple-podcast-1');
assert.equal(applePlayer.button.disabled, true);

window.__aiphoneApplyWaterfallUpdate(sourcePayload({ audioLoadState: 'loading' }));
assert.equal(createdFrames.length, framesBeforeInlinePlay);
window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'ready',
  mediaUrl: 'https://cdn.example.com/episode.mp3',
  audioTitle: 'Resolved episode',
  audioMimeType: 'audio/mpeg'
}));
assert.equal(createdFrames.length, framesBeforeInlinePlay + 1, 'ready RSS metadata must mount one audio element');
const appleAudio = createdFrames.at(-1);
assert.equal(appleAudio.tagName, 'AUDIO');
assert.equal(appleAudio.attributes.preload, 'none');
assert.equal(appleAudio.attributes.src, 'https://cdn.example.com/episode.mp3');
assert.equal(applePlayer.button.hidden, true);

track.emit('click', { target: twitchPlayer.button });
const twitchFrame = createdFrames.at(-1);
assert.equal(appleAudio.paused, true, 'switching providers must pause the previous podcast');
assert.equal(appleAudio.removed, true, 'switching providers must destroy the previous podcast');
assert.equal(applePlayer.button.hidden, false);
assert.equal(twitchPlayer.button.hidden, true);
assert.equal(twitchFrame.tagName, 'IFRAME');
assert.equal(twitchFrame.attributes.src,
  'https://player.twitch.tv/?channel=example&parent=aiphone.local&autoplay=false&muted=false');
assert.equal(twitchFrame.attributes['data-inline-source'], 'twitch');

track.emit('click', {
  target: { closest: (selector) => selector === '.waterfall-source-action' ? { href: 'https://www.twitch.tv/example' } : null }
});
assert.equal(twitchFrame.removed, true, 'opening the source link must destroy the active inline player');
assert.equal(twitchPlayer.button.hidden, false);

track.emit('click', { target: twitchPlayer.button });
const offscreenFrame = createdFrames.at(-1);
twitchPlayer.card.rect = { top: 1001, bottom: 2001 };
track.emit('scroll');
runLatestTimer(96);
runLatestTimer(180);
assert.equal(offscreenFrame.removed, true, 'scrolling the active card outside the viewport must destroy its iframe');
twitchPlayer.card.rect = { top: 0, bottom: 1000 };

track.emit('click', { target: twitchPlayer.button });
const hiddenFrame = createdFrames.at(-1);
document.hidden = true;
documentListeners.visibilitychange();
assert.equal(hiddenFrame.removed, true, 'hiding the document must destroy the inline player');
document.hidden = false;
documentListeners.visibilitychange();

track.emit('click', { target: twitchPlayer.button });
const preferencesFrame = createdFrames.at(-1);
preferencesButton.emit('click');
assert.equal(preferencesFrame.removed, true, 'opening source preferences must destroy the inline player');
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });

track.emit('click', { target: twitchPlayer.button });
const readerFrame = createdFrames.at(-1);
const openReaderLifecycleSource = waterfallJs.slice(
  waterfallJs.indexOf('function openReader'), waterfallJs.indexOf('function toggleVideoFullscreen'));
assert.match(openReaderLifecycleSource, /destroyInlinePlayer\(\)/,
  'opening the ordinary release reader must destroy the active inline player first');
document.hidden = true;
documentListeners.visibilitychange();
assert.equal(readerFrame.removed, true, 'the active player used by the reader lifecycle test must be cleaned up');
document.hidden = false;
documentListeners.visibilitychange();

for (let backAttempt = 0; backAttempt < 3; backAttempt += 1) {
  const handled = window.__aiphoneHandleWaterfallBack();
  timers.filter((timer) => (timer.delay === 140 || timer.delay === 180) && !timer.canceled)
    .forEach((timer) => { timer.canceled = true; timer.callback(); });
  if (!handled) break;
}
documentListeners.touchend?.();

window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'error',
  audioError: '播客音频加载失败，可重试',
  audioRetryable: true
}));
const pendingSettleTimer = timers.filter((timer) => timer.delay === 96 && !timer.canceled).at(-1);
if (pendingSettleTimer) {
  pendingSettleTimer.canceled = true;
  pendingSettleTimer.callback();
}
assert.match(applePlayer.card.outerHTML, /data-waterfall-apple-play="apple-podcast-1"[^>]*>重试<\/button>/);
assert.match(applePlayer.card.outerHTML, /播客音频加载失败，可重试/);
assert.doesNotMatch(applePlayer.card.outerHTML, /<audio/);
assert.equal(toast.textContent, '播客音频加载失败，可重试');
assert.equal(toast.classList.contains('active'), true);
const toastTimerCount = timers.filter((timer) => timer.delay === 2600).length;
window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'error',
  audioError: '播客音频加载失败，可重试',
  audioRetryable: true
}));
assert.equal(timers.filter((timer) => timer.delay === 2600).length, toastTimerCount,
  'the same candidate and message must not show twice');

window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'loading',
  audioError: '',
  audioRetryable: true
}));
window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'error',
  audioError: '播客音频加载失败，可重试',
  audioRetryable: true
}));
assert.equal(timers.filter((timer) => timer.delay === 2600).length, toastTimerCount + 1,
  'a new loading attempt must allow the same candidate and message to toast again');
assert.equal(toast.textContent, '播客音频加载失败，可重试');

window.__aiphoneApplyWaterfallUpdate(sourcePayload({
  audioLoadState: 'error',
  audioError: '该节目仅提供 HTTP 音频，请在来源页收听',
  audioRetryable: false
}));
assert.doesNotMatch(applePlayer.card.outerHTML, /data-waterfall-apple-play="apple-podcast-1"/);
assert.match(applePlayer.card.outerHTML, /该节目仅提供 HTTP 音频，请在来源页收听/);
assert.equal(toast.textContent, '该节目仅提供 HTTP 音频，请在来源页收听');
assert.equal(toast.classList.contains('active'), true);

const lateCoverWithoutImage = {
  ...imageCandidate,
  id: 'late-cover',
  coverUrl: ''
};
track.querySelectorAll = () => [];
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-cover',
  enabledSources: ['zhihu'],
  candidates: [lateCoverWithoutImage]
});
const lateCoverNode = Object.assign(element(), { offsetTop: 18, offsetHeight: 880 });
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? [lateCoverNode] : [];
const writesBeforeLateCover = track.innerHTMLWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-cover',
  enabledSources: ['zhihu'],
  candidates: [{ ...lateCoverWithoutImage, coverUrl: 'https://example.test/late-cover.jpg' }]
});
assert.equal(track.innerHTMLWrites, writesBeforeLateCover,
  'same-ID media enrichment must not rebuild the whole feed');
assert.equal(lateCoverNode.appendedHtmlWrites, 0,
  'same-ID media enrichment must preserve the card node under the user');
assert.equal(lateCoverNode.removed, undefined,
  'same-ID media enrichment must not detach the visible card');

const lateCoverLiveNode = Object.assign(element(), { offsetTop: 18, offsetHeight: 880 });
lateCoverLiveNode.classList.add('is-active');
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? [lateCoverLiveNode] : [];
timers.filter((timer) => !timer.canceled && timer.delay === 96)
  .forEach((timer) => { timer.canceled = true; });
const writesBeforeGestureCover = track.innerHTMLWrites;
const appendsBeforeGestureCover = lateCoverLiveNode.appendedHtmlWrites;
documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 640 }] });
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-cover',
  enabledSources: ['zhihu'],
  candidates: [{ ...lateCoverWithoutImage, coverUrl: 'https://example.test/late-cover-2.jpg' }]
});
assert.equal(track.innerHTMLWrites, writesBeforeGestureCover,
  'same-ID cover enrichment must wait until the paging gesture settles');
assert.equal(lateCoverLiveNode.appendedHtmlWrites, appendsBeforeGestureCover,
  'a finger-down gesture must not replace the card under the user');
documentListeners.touchend?.();
runLatestTimer(96);
assert.equal(lateCoverLiveNode.appendedHtmlWrites, appendsBeforeGestureCover,
  'settling the gesture must not replace the card afterward');
assert.equal(lateCoverLiveNode.removed, undefined);

const readerCoverNode = Object.assign(element(), { offsetTop: 18, offsetHeight: 880 });
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? [readerCoverNode] : [];
const readerCoverOpen = {
  getAttribute: (name) => name === 'data-waterfall-open' ? 'late-cover' : '',
  getBoundingClientRect: () => ({ top: 120, right: 360, bottom: 640, left: 40, width: 320, height: 520 })
};
openFeedCard(readerCoverOpen);
assert.equal(reader.classList.contains('active'), true);
const writesBeforeReaderCover = track.innerHTMLWrites;
const appendsBeforeReaderCover = readerCoverNode.appendedHtmlWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'late-cover',
  enabledSources: ['zhihu'],
  candidates: [{ ...lateCoverWithoutImage, coverUrl: 'https://example.test/late-cover-3.jpg' }]
});
assert.equal(track.innerHTMLWrites, writesBeforeReaderCover);
assert.equal(readerCoverNode.appendedHtmlWrites, appendsBeforeReaderCover,
  'same-ID cover enrichment must preserve the feed card while details are open');
documentListeners.keydown({ key: 'Escape' });
assert.equal(reader.classList.contains('closing'), true);
assert.equal(reader.classList.contains('active'), true);
const reopenCoverOpen = {
  getAttribute: (name) => name === 'data-waterfall-open' ? 'late-cover' : '',
  getBoundingClientRect: () => ({ top: 40, right: 300, bottom: 480, left: 20, width: 280, height: 440 })
};
openFeedCard(reopenCoverOpen);
assert.equal(reader.classList.contains('closing'), false,
  'reopening during the close motion must reverse from the current visual state');
assert.equal(reader.classList.contains('active'), true);
assert.deepEqual(reader.style.values, {});
assert.equal(timers.filter((timer) => timer.delay === 180 && !timer.canceled).length, 0,
  'reopening must cancel the close timer so the layer cannot hide mid-reverse');
assert.equal(readerCoverNode.appendedHtmlWrites, appendsBeforeReaderCover,
  'an interrupted reopen must preserve the feed card node');
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
assert.equal(timers.filter((timer) => timer.delay === 240 && !timer.canceled).length, 0);
runLatestTimer(0);
assert.equal(readerCoverNode.appendedHtmlWrites, appendsBeforeReaderCover,
  'returning from details must preserve the existing feed card node');
