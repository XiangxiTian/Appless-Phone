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
const reducedMotionCss = waterfallCss.slice(waterfallCss.lastIndexOf('@media (prefers-reduced-motion: reduce)'));
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
assert.match(waterfallCss, /\.waterfall-top-hotzone\s*\{/);
assert.match(waterfallCss, /\.waterfall-toolbar\s*\{[^}]*opacity:\s*0/s);
assert.match(waterfallCss, /\.waterfall-toolbar\.revealed\s*\{[^}]*opacity:\s*1/s);
assert.match(waterfallJs, /data-waterfall-open/);
assert.doesNotMatch(waterfallJs, />阅读全文</);
assert.match(waterfallJs, /class="waterfall-source-action"[^>]*aria-label="查看来源"/);
assert.match(waterfallJs, /waterfall-reader--image-text/);
assert.match(waterfallJs, /waterfall-reader--text/);
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-stop:\s*normal/s);
assert.match(waterfallCss, /\.waterfall-overlay\s*\{[^}]*display:\s*none[^}]*background:\s*var\(--paper\)[^}]*opacity:\s*0/s);
assert.match(waterfallCss, /\.waterfall-overlay\.active\s*\{[^}]*display:\s*block[^}]*opacity:\s*1[^}]*animation:\s*waterfall-overlay-in 180ms var\(--ease-out\) both/s);
assert.match(waterfallCss, /\.waterfall-overlay\.active\.closing\s*\{[^}]*opacity:\s*0[^}]*animation:\s*none[^}]*transition:\s*opacity 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-track\s*\{[^}]*background:\s*var\(--paper\)/s);
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*background:\s*var\(--paper\)/s);
assert.match(waterfallCss, /\.waterfall-card--text\s*\{[^}]*background:\s*var\(--panel-strong\)/s);
assert.match(waterfallCss, /\.waterfall-cinema-copy\s*\{[^}]*overflow:\s*hidden/s);
assert.match(waterfallCss, /\n\.waterfall-cinema-copy\s*\{[^}]*display:\s*flex[^}]*flex-direction:\s*column/s);
assert.match(waterfallCss, /\n\.waterfall-copy-actions\s*\{[^}]*margin-top:\s*auto/s);
assert.match(waterfallCss, /\.waterfall-reader-body\s*\{[^}]*overflow-y:\s*auto/s);
assert.match(waterfallCss, /\.waterfall-media-frame\s*\{[^}]*pointer-events:\s*auto/s);
assert.match(aggregateCss, /--ease-out:\s*cubic-bezier\(0\.23, 1, 0\.32, 1\)/);
assert.match(aggregateCss, /--ease-drawer:\s*cubic-bezier\(0\.32, 0\.72, 0, 1\)/);
assert.match(waterfallCss, /\.waterfall-reader\s*\{[^}]*visibility:\s*hidden[^}]*opacity:\s*0[^}]*visibility 0s linear 220ms/s);
assert.match(waterfallCss, /\.waterfall-reader\.active\s*\{[^}]*transition-delay:\s*0s/s);
assert.match(waterfallCss, /\.waterfall-preferences\s*\{[^}]*opacity:\s*0[^}]*visibility 0s linear 220ms/s);
assert.match(waterfallCss, /\.waterfall-preferences\.active\s*\{[^}]*transition-delay:\s*0s/s);
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle\s*\{[^}]*min-height:\s*44px[^}]*cursor:\s*pointer[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-cinema-card a, \.waterfall-read-button\s*\{[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-reader-head button\s*\{[^}]*transform 140ms var\(--ease-out\)/s);
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle:active,[^}]*\.waterfall-reader-head button:active\s*\{[^}]*transform:\s*scale\(0\.97\)/s);
assert.match(waterfallCss, /\.waterfall-video-fullscreen-toggle:focus-visible,[^}]*outline:\s*2px solid var\(--accent\)/s);
assert.match(reducedMotionCss, /\.waterfall-reader,[^}]*\.waterfall-preferences\s*\{[^}]*transform:\s*none[^}]*opacity 140ms var\(--ease-out\)[^}]*visibility 0s linear 140ms !important/s);
assert.match(reducedMotionCss, /\.waterfall-video-fullscreen-toggle,[^}]*\.waterfall-card-shell,[^}]*\{[^}]*opacity 140ms var\(--ease-out\)[^}]*background-color 140ms ease !important/s);
assert.match(reducedMotionCss, /\.waterfall-video-fullscreen-toggle:active,[^}]*\.waterfall-card-shell:active,[^}]*\{[^}]*transform:\s*none[^}]*opacity:\s*0\.82/s);
assert.match(reducedMotionCss, /\.waterfall-overlay\.active\s*\{[^}]*animation:\s*waterfall-overlay-in 140ms var\(--ease-out\) both !important/s);
assert.doesNotMatch(waterfallCss, /\.waterfall-cinema-card h2\s*\{[^}]*-webkit-line-clamp/s);
assert.doesNotMatch(waterfallCss, /\.waterfall-cinema-card p\s*\{[^}]*-webkit-line-clamp/s);
assert.match(waterfallCss, /\.waterfall-preferences label\s*\{[^}]*border:\s*0/s);
assert.match(waterfallCss, /\.waterfall-toolbar-secondary\s*\{[^}]*border:\s*0/s);
assert.doesNotMatch(waterfallCss, /\.waterfall-cinema-stage img\s*\{/);
assert.match(surfaceView, /\.mediaPlayGestureAccess\(false\)/);

function element() {
  const classes = new Set();
  const listeners = {};
  let html = '';
  let htmlWrites = 0;
  return {
    scrollTop: 0,
    clientHeight: 1000,
    get innerHTML() { return html; },
    set innerHTML(value) { html = value; htmlWrites += 1; },
    get innerHTMLWrites() { return htmlWrites; },
    classList: {
      add: (name) => classes.add(name),
      remove: (name) => classes.delete(name),
      toggle: (name, force) => {
        if (force === true) { classes.add(name); return true; }
        if (force === false) { classes.delete(name); return false; }
        if (classes.has(name)) { classes.delete(name); return false; }
        classes.add(name); return true;
      },
      contains: (name) => classes.has(name)
    },
    addEventListener: (type, listener) => {
      listeners[type] = listener;
    },
    emit: (type, event = {}) => {
      listeners[type]?.(event);
    },
    querySelectorAll: () => []
  };
}

const overlay = element();
const track = element();
const preferences = element();
const reader = element();
const readerHead = element();
reader.querySelector = (selector) => selector === '.waterfall-reader-head' ? readerHead : null;
const toolbar = element();
const topHotzone = element();
const backButton = element();
const preferencesButton = element();
const documentListeners = {};
const actions = [];
const fullscreenStates = [];
const timers = [];
let now = 1000;
const FakeDate = { now: () => now };
const actionCount = (id) => actions.filter((action) => action.id === id).length;
const schedule = (callback, delay) => {
  const timer = { callback, delay, canceled: false };
  timers.push(timer);
  return timer;
};
const cancel = (timer) => { if (timer) timer.canceled = true; };
const document = {
  hidden: false,
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences,
    'waterfall-reader': reader,
    'waterfall-toolbar': toolbar
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => ({
    '[data-waterfall-back]': [backButton],
    '[data-waterfall-preferences]': [preferencesButton],
    '[data-waterfall-top-hotzone]': [topHotzone]
  })[selector] ?? [],
  addEventListener: (type, listener) => {
    documentListeners[type] = listener;
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
  publishedAt: '',
  reason: '标题命中查询'
});
const imageCandidate = {
  ...candidate('image-current'),
  mediaType: 'image_text',
  coverUrl: 'https://example.test/image.jpg',
  reason: '摘要命中查询'
};
const textCandidate = {
  ...candidate('text-current'),
  mediaType: 'post',
  coverUrl: '',
  summary: 'A long text summary for the dedicated reader',
  reason: '补充 HN 来源'
};
const portraitCandidate = {
  ...candidate('portrait-current'),
  format: 'portrait_video',
  coverUrl: '',
  url: 'https://example.test/portrait'
};
const window = {
  __aiphoneWaterfallInitial: {
    surfaceId: 'surface-1',
    currentId: 'current',
    enabledSources: ['youtube'],
    aggregateHtml: '',
    candidates: [candidate('current'), imageCandidate, textCandidate, portraitCandidate],
    mediaEmbeds: {
      'https://www.youtube.com/watch?v=abc123': 'https://www.youtube.com/embed/abc123?playsinline=1'
    },
    sources: [{ source: 'youtube', phase: 'success' }]
  },
  __aiphoneWaterfallSourceLogos: { youtube: 'data:image/png;base64,logo' },
  AIPhoneHome: {
    postAction: (value) => actions.push(JSON.parse(value)),
    setWaterfallFullscreen: (value) => fullscreenStates.push(value)
  }
};

vm.runInNewContext(template('WATERFALL_JS'), {
  window,
  document,
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
assert.doesNotMatch(track.innerHTML, /data-waterfall-play/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-read/);
assert.match(track.innerHTML, /data-waterfall-open="image-current"/);
assert.match(track.innerHTML, /data-waterfall-open="text-current"/);
assert.match(track.innerHTML, /class="waterfall-source-action"/);
assert.doesNotMatch(track.innerHTML, />查看来源</);
assert.match(track.innerHTML, /<iframe class="waterfall-media-frame"/);
assert.match(track.innerHTML, /src="https:\/\/www\.youtube\.com\/embed\/abc123\?playsinline=1"/);
assert.match(track.innerHTML, /current summary/);
assert.match(track.innerHTML, /current summary tail/);
assert.doesNotMatch(track.innerHTML, /B 站视频搜索结果：/);
assert.match(track.innerHTML, /waterfall-recommendation/);
assert.match(track.innerHTML, /标题命中查询/);
assert.match(track.innerHTML, /data-waterfall-reason/);
assert.match(track.innerHTML, /data-waterfall-media-fallback/);
assert.match(track.innerHTML, /data-waterfall-video-fullscreen/);
topHotzone.emit('click');
assert.equal(toolbar.classList.contains('revealed'), true);
const toolbarTimer = timers.find((timer) => timer.delay === 2600 && !timer.canceled);
assert.ok(toolbarTimer, 'the hidden toolbar must schedule its dismissal after being revealed');
toolbarTimer.callback();
assert.equal(toolbar.classList.contains('revealed'), false);
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
  closest: (selector) => selector === '.waterfall-card--video' ? videoCard : null
};
const sourceTarget = {
  closest: (selector) => selector === '.waterfall-source-action' ? {} :
    (selector === '[data-waterfall-open]' ? videoOpen : null)
};
track.emit('click', { target: sourceTarget });
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false,
  'source actions must not activate their parent card');
const mediaTarget = {
  closest: (selector) => selector === '.waterfall-media-frame' ? {} :
    (selector === '[data-waterfall-open]' ? videoOpen : null)
};
track.emit('click', { target: mediaTarget });
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false,
  'embedded media must not activate its parent card');
track.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-open]' ? videoOpen : null }
});
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), true,
  'the video card itself must open fullscreen');
documentListeners.keydown({ key: 'Escape' });
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false);
assert.equal(track.classList.contains('video-open'), false);

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
assert.equal(portraitCard.classList.contains('waterfall-card--portrait'), true);
assert.equal(portraitCard.classList.contains('waterfall-card--landscape'), false);

track.scrollTop = 320;
const textOpen = { getAttribute: (name) => name === 'data-waterfall-open' ? 'text-current' : '' };
track.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-open]' ? textOpen : null }
});
now += 4000;
document.hidden = true;
documentListeners.visibilitychange();
now += 12000;
document.hidden = false;
documentListeners.visibilitychange();
now += 4000;
assert.equal(reader.classList.contains('active'), true);
assert.equal(track.classList.contains('reader-open'), true);
assert.match(reader.innerHTML, /waterfall-reader--text/);
assert.doesNotMatch(reader.innerHTML, /waterfall-reader-media/);
assert.match(reader.innerHTML, /A long text summary for the dedicated reader/);
assert.equal(track.scrollTop, 320, 'opening the reader must preserve the feed position');
const readerToolbarTimer = timers.filter((timer) => timer.delay === 2600 && !timer.canceled).at(-1);
assert.ok(readerToolbarTimer, 'the reader toolbar must dismiss after its reveal');
readerToolbarTimer.callback();
assert.equal(readerHead.classList.contains('revealed'), false);
reader.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-reader-close]' ? {} : null }
});
assert.equal(reader.classList.contains('active'), false);
assert.equal(track.classList.contains('reader-open'), false);
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
documentListeners.keydown({ key: 'Escape' });
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

track.scrollTop = 600;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
assert.equal(track.scrollTop, 600);
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
track.emit('scroll');
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeHalfScroll);
track.scrollTop = 1960;
track.emit('scroll');
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
assert.equal(actions.at(-1)?.args?.currentId, 'current');

const actionCountBeforeCatchUp = actionCount('waterfall.feed.advance');
const writesBeforeCurrentAdvance = track.innerHTMLWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'image-current',
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
assert.equal(track.scrollTop, 1960, 'server updates must not snap the user back to the first card');
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
assert.equal(track.scrollTop, 0, 'source filtering must align to the enabled current card instead of an empty tail');
const actionCountBeforeFilteredAdvance = actionCount('waterfall.feed.advance');
track.scrollTop = 960;
track.emit('scroll');
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
assert.equal(actionCount('waterfall.feed.advance'), actionCountBeforeLastCard + 1);
assert.equal(actions.at(-1)?.args?.currentId, 'last');
preferencesButton.emit('click');
assert.equal(preferences.classList.contains('active'), true);
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true', 'false']);
assert.equal(preferences.classList.contains('active'), false);
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
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

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
  sources: [],
  replenishing: false,
  exhausted: true
});
assert.match(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-empty-sources/);

window.__aiphoneApplyWaterfallUpdate({
  surfaceId: 'surface-1',
  enabledSources: ['youtube'],
  aggregateHtml: '',
  candidates: [],
  sources: [],
  replenishing: true,
  exhausted: false
});
assert.match(track.innerHTML, /\\u6b63\\u5728\\u8865\\u5145\\u5185\\u5bb9/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

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
assert.match(track.innerHTML, /\\u6b63\\u5728\\u6c47\\u96c6\\u5185\\u5bb9\\u2026/);
assert.doesNotMatch(track.innerHTML, /至少开启一个来源/);
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);

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
assert.match(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
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
assert.doesNotMatch(track.innerHTML, /\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f/);
