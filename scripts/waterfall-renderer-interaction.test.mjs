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
const entryAbility = readFileSync(
  new URL('../entry/src/main/ets/entryability/EntryAbility.ets', import.meta.url),
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
  { source: 'twitch', label: 'Twitch' }
]);
const sourceOnlyJson = JSON.stringify(['applepodcasts', 'twitch']);
const searchSourcesJson = JSON.stringify(['youtube', 'bilibili', 'applepodcasts']);
const interestSourcesJson = JSON.stringify(['youtube', 'bilibili', 'applepodcasts', 'twitch']);
const waterfallTemplateWithRegistry = waterfallJs
  .split('${WATERFALL_SOURCE_LABELS_JSON}').join(sourceLabelsJson)
  .split('${WATERFALL_SOURCE_ONLY_SOURCES_JSON}').join(sourceOnlyJson)
  .split('${WATERFALL_SEARCH_SOURCE_IDS_JSON}').join(searchSourcesJson)
  .split('${WATERFALL_INTEREST_SOURCE_IDS_JSON}').join(interestSourcesJson);
const emittedWaterfallJs = Function('return `' + waterfallTemplateWithRegistry + '`;')();
assert.doesNotThrow(() => new vm.Script(emittedWaterfallJs));
const reducedMotionCss = waterfallCss.slice(waterfallCss.lastIndexOf('@media (prefers-reduced-motion: reduce)'));
assert.match(indexPage, /@State interestWaterfallFullscreen:\s*boolean\s*=\s*false/,
  'search and interest Waterfall surfaces must not overwrite one shared fullscreen flag');
assert.match(indexPage, /\.disableSwipe\(this\.waterfallFullscreen\s*\|\|\s*this\.interestWaterfallFullscreen\)/,
  'either Waterfall fullscreen surface must disable the native root Swiper so it cannot steal detail gestures');
assert.doesNotMatch(indexPage, /\.disableSwipe\(false\)/,
  'the native root Swiper must not stay swipeable while Waterfall is fullscreen');
assert.doesNotMatch(indexPage, /onWaterfallFullscreenChange:\s*\(_active:\s*boolean\):\s*void\s*=>\s*\{\}/,
  'both Waterfall surfaces must report fullscreen state so the native root Swiper cannot steal gestures');
assert.match(indexPage, /if \(!this\.interestWaterfallFullscreen\)\s*\{\s*Row\(\)\s*\{\s*WaterfallVoiceDock/s,
  'the one voice entry must exist only on the main independent discovery layer');
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
assert.match(voiceDock, /\.width\(216\)[\s\S]*\.height\(46\)/,
  'the compact dock must keep a large enough touch target without dominating the feed');
assert.match(voiceDock, /\.borderRadius\(16\)/,
  'the compact voice tool must follow the soft card radius instead of looking like a text field');
assert.match(indexPage, /WaterfallVoiceDock\([\s\S]*?\}\)\s*\}\s*\.width\('100%'\)\s*\.justifyContent\(FlexAlign\.Center\)/,
  'the compact voice entry must stay centered below the discovery feed');
assert.match(voiceDock, /this\.pressed \? 0\.98 : 1/,
  'the voice entry needs immediate tactile press feedback');
assert.match(voiceDock, /shouldStop = this\.pressed \|\| this\.isListening/,
  'releasing a fast press must stop ASR even before the parent prop catches up');
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
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-align:\s*center/s);
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*height:\s*100dvh/s);
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*contain:\s*layout(?!\s+paint)/s,
  'card layout isolation must not clip the shadow into a horizontal line');
assert.doesNotMatch(waterfallCss, /\.waterfall-card\s*\{[^}]*contain:[^;}]*paint/s);
assert.match(waterfallCss, /\.waterfall-icon svg\s*\{/);
assert.doesNotMatch(waterfallCss, /\.waterfall-top-hotzone\s*\{/);
assert.doesNotMatch(waterfallJs, /data-waterfall-top-hotzone/);
assert.match(waterfallCss, /\.waterfall-toolbar\s*\{[^}]*opacity:\s*1/s);
assert.match(waterfallCss, /\.waterfall-toolbar\s*\{[^}]*left:\s*0[^}]*right:\s*0[^}]*background:\s*#eef0f2[^}]*border-bottom:/s,
  'discovery controls must live in one persistent top bar instead of floating pills');
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
assert.match(waterfallJs, /waterfall-reader--image-text/);
assert.match(waterfallJs, /waterfall-reader--text/);
assert.match(waterfallJs, /waterfall-reader--video/);
assert.match(waterfallJs, /waterfall-reader-video-card/);
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
assert.match(waterfallCss, /\.waterfall-card\.is-active,\s*\n\.waterfall-card--video-fullscreen\s*\{[^}]*opacity:\s*1[^}]*scale\(1\)/s,
  'the current card must stay fully opaque');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader-hotzone\s*\{/);
assert.doesNotMatch(waterfallJs, /data-waterfall-reader-hotzone/);
assert.match(waterfallCss, /\.waterfall-reader-head\s*\{[^}]*opacity:\s*1/s);
assert.match(waterfallCss, /\.waterfall-reader-head\s*\{[^}]*left:\s*0[^}]*right:\s*0[^}]*background:\s*#eef0f2[^}]*border-bottom:/s,
  'detail controls must stay in an opaque persistent top bar while content scrolls');
assert.match(waterfallCss, /\.waterfall-reader\.active\.closing\s*\{[^}]*pointer-events:\s*auto/s,
  'the closing reader must keep the leftover press until it is actually hidden');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\.active\.closing \.waterfall-reader-body\s*\{[^}]*opacity:\s*0/s,
  'the detail body must remain visible for the shared-card return animation');
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-stop:\s*always/s,
  'discovery paging must stop on the next card like Douyin, not skip through a fling');
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
assert.match(waterfallCss, /\.waterfall-reader\s*\{[^}]*opacity:\s*0[^}]*scale\(0\.985\)[^}]*transform 180ms var\(--ease-out\)/s,
  'opening details must ease up from a slightly smaller card, using literal transforms');
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*opacity:\s*1[^}]*scale\(1\)/s,
  'the open detail view must finish at full size');
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
assert.doesNotMatch(waterfallJs, /querySelector\('\[data-waterfall-reader-close\]'\)/,
  'reopening a card must not stack another tap binder on the close button');
assert.match(waterfallCss, /\.waterfall-preferences\s*\{[^}]*transform:\s*none[^}]*opacity:\s*0[^}]*visibility 0s linear 140ms/s);
assert.match(waterfallCss, /\.waterfall-preferences\.active\s*\{[^}]*transition-delay:\s*0s/s);
assert.match(waterfallCss,
  /\.waterfall-preferences:not\(\.active\),\s*\.waterfall-preferences:not\(\.active\) \*\s*\{[^}]*pointer-events:\s*none !important/s,
  'every descendant of the hidden source sheet must stop intercepting Twitch controls');
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
assert.match(waterfallCss, /\.waterfall-preferences label\s*\{[^}]*border:\s*1px solid/s);
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
assert.match(waterfallJs, /readerMountedId/,
  'reopening the same card must reuse the already-built reader layer');
const renderPreferencesSource = waterfallJs.slice(
  waterfallJs.indexOf('function renderPreferences'),
  waterfallJs.indexOf('function closePreferences')
);
assert.match(renderPreferencesSource, /if \(!preferences\.innerHTML\)/,
  'reopening source settings must not rebuild the sheet');
assert.doesNotMatch(waterfallJs, /CARD_MOUNT_RADIUS/,
  'virtualizing offscreen cards as empty placeholders blanks the feed and breaks snap');
assert.doesNotMatch(waterfallJs, /waterfall-card--placeholder/,
  'every ranked card must keep its real markup so the next page is already painted');
assert.match(waterfallJs, /pageAnchorIndex/,
  'a paging gesture may only travel to the adjacent card');
assert.match(waterfallJs, /shell\.hidden/,
  'the hidden aggregate search page must leave the accessibility tree while discovery is open');
assert.match(waterfallJs, /window\.__aiphoneHandleWaterfallBack\s*=\s*function/);
assert.match(surfaceView, /waterfallBackRequestTick/);
assert.match(surfaceView, /__aiphoneHandleWaterfallBack/);
assert.match(homePage, /waterfallBackRequestTick/);
assert.match(indexPage, /onBackPress\(\): boolean[\s\S]*waterfallBackRequestTick/);
const scrollHandlerSource = waterfallJs.slice(
  waterfallJs.indexOf("track.addEventListener('scroll'"),
  waterfallJs.indexOf("track.addEventListener('error'")
);
assert.match(scrollHandlerSource, /if \(mode !== 'discovering'\) return;/,
  'the hidden discovery feed must ignore scroll work while details are open');
assert.match(scrollHandlerSource, /scheduleAdvance/);
assert.doesNotMatch(scrollHandlerSource, /postAdvanceIfNeeded\(updateCardPresentation\(\)\)/,
  'native bridge work must not run inside the scrolling animation frame');
const presentationSource = waterfallJs.slice(
  waterfallJs.indexOf('function updateCardPresentation'),
  waterfallJs.indexOf('function refreshMetricsAfterSettle')
);
assert.doesNotMatch(presentationSource, /innerHTML\s*=/,
  'player DOM teardown must not run in the presentation frame');
assert.doesNotMatch(waterfallJs, /data-waterfall-video-direct/,
  'Bilibili iframes must mount only after an explicit play action');
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
assert.match(waterfallJs, /youtube\.com\/embed\/.*\?playsinline=1/);
assert.match(waterfallJs, /player\.bilibili\.com\/player\.html\?bvid=.*&autoplay=0&poster=true&danmaku=0&isOutside=true/);
assert.doesNotMatch(waterfallJs, /TWITCH_CLIENT_(?:ID|SECRET)|access_token/i);

function element() {
  const classes = new Set();
  const listeners = {};
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
    set innerHTML(value) { html = value; htmlWrites += 1; },
    get outerHTML() { return html; },
    set outerHTML(value) { html = value; outerHtmlWrites += 1; },
    get innerHTMLWrites() { return htmlWrites; },
    get outerHTMLWrites() { return outerHtmlWrites; },
    get appendedHtmlWrites() { return appendedHtmlWrites; },
    get classToggleWrites() { return classToggleWrites; },
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
const readerHead = element();
reader.querySelector = (selector) => selector === '.waterfall-reader-head' ? readerHead : null;
const toolbar = element();
const toast = element();
const backButton = element();
const preferencesButton = element();
const preferenceBackButton = element();
const preferenceDoneButton = element();
preferenceBackButton.closest = (selector) => selector.includes('[data-waterfall-close-preferences]') ? preferenceBackButton : null;
preferenceDoneButton.closest = (selector) => selector.includes('[data-waterfall-apply-preferences]') ? preferenceDoneButton : null;
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
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences,
    'waterfall-reader': reader,
    'waterfall-toolbar': toolbar,
    'waterfall-toast': toast
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => ({
    '[data-waterfall-back]': [backButton],
    '[data-waterfall-preferences]': [preferencesButton]
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
  summary: 'A long text summary for the dedicated reader',
  reason: '补充 HN 来源'
};
const noCoverImageCandidate = {
  ...imageCandidate,
  id: 'no-cover-image',
  source: 'reddit',
  coverUrl: '',
  summary: 'A Reddit post without a cover should stay a compact text card'
};
const portraitCandidate = {
  ...candidate('portrait-current'),
  source: 'bilibili',
  format: 'portrait_video',
  coverUrl: '',
  url: 'https://www.bilibili.com/video/BV1xx411c7mD'
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
    enabledSources: ['youtube', 'bilibili', 'reddit', 'zhihu', 'hackernews', 'x', 'unknown'],
    aggregateHtml: '',
    candidates: [candidate('current'), imageCandidate, textCandidate, portraitCandidate, noCoverImageCandidate,
      { ...candidate('x-current'), source: 'x', mediaType: 'post' },
      { ...candidate('unknown-current'), source: 'unknown', mediaType: 'post' }],
    mediaEmbeds: {
      'https://www.youtube.com/watch?v=abc123': 'https://www.youtube.com/embed/abc123?playsinline=1'
    },
    sources: [{ source: 'youtube', phase: 'success' }]
  },
  __aiphoneWaterfallSourceLogos: { youtube: 'data:image/png;base64,logo', reddit: 'data:image/png;base64,reddit' },
  __aiphoneWaterfallUiIcons: {
    back: testUiIcon,
    external: testUiIcon,
    expand: testUiIcon,
    play: testUiIcon,
    sources: testUiIcon
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
assert.match(track.innerHTML, /class="waterfall-source-action"/);
assert.match(track.innerHTML, /referrerpolicy="no-referrer"/);
assert.match(track.innerHTML, /onerror="this\.parentElement\.hidden=true"/);
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
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? gestureCardNodes : [];
documentListeners.touchstart({ touches: [{ clientX: 200, clientY: 700 }] });
documentListeners.touchmove?.({ touches: [{ clientX: 202, clientY: 560 }] });
const writesBeforeGesturePayload = track.innerHTMLWrites;
const appendsBeforeGesturePayload = track.appendedHtmlWrites;
const initialCandidates = window.__aiphoneWaterfallInitial.candidates;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [initialCandidates[0], initialCandidates[1], candidate('reranked-during-swipe'),
    ...initialCandidates.slice(2)]
});
assert.equal(track.innerHTMLWrites, writesBeforeGesturePayload,
  'a reranked provider tail must not rebuild the feed while the user is swiping');
documentListeners.touchend?.();
track.emit('click', { preventDefault: () => {}, target: { closest: () => null } });
runLatestTimer(96);
assert.equal(track.innerHTMLWrites, writesBeforeGesturePayload,
  'a settled provider update must not replace the visible card tree and reload its media');
assert.equal(track.appendedHtmlWrites, appendsBeforeGesturePayload + 1,
  'newly ranked cards may append after the stable rendered cards without flashing them');
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

const videoOpen = {
  getAttribute: (name) => name === 'data-waterfall-open' ? 'current' : '',
  getBoundingClientRect: () => ({ top: 80, right: 380, bottom: 760, left: 20, width: 360, height: 680 }),
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
assert.match(reader.innerHTML, /waterfall-reader-video-card/);
assert.match(reader.innerHTML, /waterfall-reader-head-label">返回</);
assert.match(reader.innerHTML, /waterfall-reader-head-title">详情</);
assert.match(reader.innerHTML, /waterfall-reader-video-copy/);
assert.doesNotMatch(reader.innerHTML, /<iframe class="waterfall-media-frame"/,
  'opening video details must not load the remote player before a deliberate play press');
assert.match(reader.innerHTML, /waterfall-reader-video-frame/);
assert.match(reader.innerHTML, /data-waterfall-video-play/);
assert.match(reader.innerHTML, /waterfall-reader-video-fallback/);
assert.match(reader.innerHTML, /current summary tail/);
assert.equal(track.classList.contains('reader-open'), false,
  'opening details must not flip overflow on the underlying snap scroller');
assert.deepEqual(reader.style.values, {},
  'opening details must not pin a card-sized transform on the reader shell');
const videoDetail = element();
const videoFrame = element();
const videoStage = element();
videoStage.getAttribute = (name) => name === 'data-waterfall-video-url' ?
  'https://www.youtube.com/embed/abc123?playsinline=1' : (name === 'data-waterfall-video-kind' ? 'iframe' : '');
videoStage.querySelector = (selector) => selector === '.waterfall-reader-video-frame' ? videoFrame : null;
const playControl = {
  closest: (selector) => selector === '.waterfall-reader-video-card' ? videoDetail :
    (selector === '.waterfall-reader-video-stage' ? videoStage : null)
};
reader.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-video-play]' ? playControl : null }
});
assert.equal(videoDetail.classList.contains('is-playing'), true,
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
finishReaderClose();
assert.equal(overlay.classList.contains('reading'), false,
  'the feed must be tappable again as soon as details hide');
assert.equal(track.innerHTMLWrites, writesBeforeReaderUpdate,
  'returning from details must not synchronously rebuild the discovery feed');
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? readerFeedNodes : [];
runLatestTimer(96);
assert.equal(track.innerHTMLWrites, writesBeforeReaderUpdate,
  'the latest deferred provider update must preserve the revealed card DOM');
assert.equal(track.appendedHtmlWrites, appendsBeforeReaderUpdate + 1,
  'the deferred provider update may append its new card after the return animation settles');
assert.equal(track.scrollTop, 0,
  'a deferred rerank must keep the returned card at its stable rendered position');
assert.doesNotMatch(waterfallCss, /\.waterfall-reader\s*\{[^}]*will-change:\s*transform/s,
  'a long scrolling reader must not stay promoted as one transformed layer');
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*scale\(1\)/s,
  'the open reader must settle at identity scale after the enter motion');
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
documentListeners.keydown({ key: 'Escape' });
finishReaderClose();
const newReturnNodes = Array.from({ length: 9 }, (_, index) =>
  Object.assign(element(), { offsetTop: index * 1000, offsetHeight: 1000 }));
track.querySelectorAll = (selector) => selector === '[data-waterfall-id]' ? newReturnNodes : [];
runLatestTimer(96);
assert.equal(track.scrollTop, 3000,
  'returning after a deferred update must preserve the exact captured feed position');

const bilibiliOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'portrait-current' : '' };
leftoverFeedClickMustNotOpen(bilibiliOpen);
openFeedCard(bilibiliOpen);
assert.match(reader.innerHTML, /waterfall-reader-video-card/);
assert.match(reader.innerHTML, /player\.bilibili\.com\/player\.html\?bvid=BV1xx411c7mD/);
assert.doesNotMatch(reader.innerHTML, /<iframe class="waterfall-media-frame"/);
assert.match(reader.innerHTML, /data-waterfall-video-play/,
  'Bilibili detail must defer its iframe until playback is explicitly requested');
assert.match(reader.innerHTML, />B 站</);
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
assert.match(reader.innerHTML, /A long text summary for the dedicated reader/);
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
assert.match(reader.innerHTML, /https:\/\/example\.test\/image\.jpg/);
assert.match(reader.innerHTML, /onerror="this\.parentElement\.hidden=true"/);
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
track.scrollTop = 200;
track.emit('scroll');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeHalfScroll,
  'the native advance bridge must wait until scrolling settles');
runLatestTimer(72);
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
assert.equal(actions.at(-1)?.args?.currentId, 'current');

const actionCountBeforeCatchUp = actionCount('waterfall.feed.advance');
const writesBeforeCurrentAdvance = track.innerHTMLWrites;
track.scrollTop = 900;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'image-current',
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
runLatestTimer(96);
runLatestTimer(72);
assert.equal(track.scrollTop, 900, 'server updates must not snap the user back to the first card');
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
runLatestTimer(96);
assert.doesNotMatch(track.innerHTML, /waterfall-tail-status/, 'a continuable feed must not render a fake end card');
const actionCountBeforeLastCard = actionCount('waterfall.feed.advance');
track.scrollTop = 960;
track.emit('scroll');
runLatestTimer(72);
runLatestTimer(96);
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
for (let index = 1; index <= 20; index += 1) {
  track.scrollTop = index * 1000;
  track.emit('scroll');
}
const classWritesAfterFastScroll = stressNodes.reduce((sum, node) => sum + node.classToggleWrites, 0);
assert.ok(classWritesAfterFastScroll - classWritesBeforeFastScroll <= 160,
  'fast scrolling must update only the current card and its neighbors, not all cards per frame');
timers.filter((timer) => !timer.canceled && (timer.delay === 72 || timer.delay === 180))
  .forEach((timer) => { timer.canceled = true; });
runLatestTimer(96);

preferencesButton.emit('click');
assert.equal(preferences.classList.contains('active'), true);
assert.equal(overlay.classList.contains('sheet-open'), true,
  'the source sheet must freeze the feed through the overlay, not overflow');
const preferenceWritesAfterFirstOpen = preferences.innerHTMLWrites;
const sourceSelectionCountBeforeToggle = actionCount('waterfall.sources.select');
sourceInputs[0].checked = false;
sourceInputs[0].emit('change');
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle,
  'toggling a source must stay local so the control responds immediately');
let preferenceTapPrevented = false;
preferences.emit('click', {
  cancelable: true,
  preventDefault: () => { preferenceTapPrevented = true; },
  target: preferenceDoneButton
});
assert.equal(preferences.classList.contains('active'), false);
assert.equal(overlay.classList.contains('sheet-open'), true,
  'the source sheet must keep the feed inert until the release click can no longer fall through');
assert.equal(preferenceTapPrevented, true, 'source done must use the single native click path');
preferences.emit('click', { preventDefault: () => {}, target: preferenceDoneButton });
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle,
  'closing the sheet must paint before applying the heavier feed update');
runLatestTimer(140);
assert.equal(overlay.classList.contains('sheet-open'), false,
  'the feed must unlock after the source sheet close transition');
assert.equal(actionCount('waterfall.sources.select'), sourceSelectionCountBeforeToggle + 1);
preferencesButton.emit('click');
assert.equal(preferences.innerHTMLWrites, preferenceWritesAfterFirstOpen,
  'reopening source settings must not rebuild the sheet');
let preferenceBackPrevented = false;
preferences.emit('click', {
  preventDefault: () => { preferenceBackPrevented = true; },
  target: preferenceBackButton
});
assert.equal(preferences.classList.contains('active'), false);
assert.equal(preferenceBackPrevented, true, 'source back must use the delegated native click path');
runLatestTimer(140);
preferencesButton.emit('click');
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true']);
assert.equal(preferences.classList.contains('active'), false);
runLatestTimer(140);
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
runLatestTimer(140);
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
runLatestTimer(140);

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
track.scrollTop = 1324;
track.emit('scroll');
assert.ok(track.scrollTop <= 596,
  'a paging fling must stop on the next card instead of skipping through empty space');
assert.equal(compactCardNodes[1].classList.contains('is-active'), true,
  'one gesture may only promote the adjacent card');
assert.equal(compactCardNodes[2].classList.contains('is-active'), false,
  'the card after next must stay unselected until a new gesture');

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
runLatestTimer(140);

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
