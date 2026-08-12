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
assert.match(waterfallCss, /\.waterfall-card\s*\{[^}]*scroll-snap-stop:\s*normal/s);
assert.match(waterfallCss, /\.waterfall-overlay\s*\{[^}]*background:\s*var\(--paper\)/s);
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
assert.match(reducedMotionCss, /\.waterfall-video-fullscreen-toggle,[^}]*\.waterfall-reader-head button\s*\{[^}]*opacity 140ms var\(--ease-out\)[^}]*background-color 140ms ease !important/s);
assert.match(reducedMotionCss, /\.waterfall-video-fullscreen-toggle:active,[^}]*\.waterfall-reader-head button:active\s*\{[^}]*transform:\s*none[^}]*opacity:\s*0\.82/s);
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
      toggle: (name) => classes.has(name) ? classes.delete(name) : classes.add(name),
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
const backButton = element();
const preferencesButton = element();
const documentListeners = {};
const actions = [];
const fullscreenStates = [];
const document = {
  getElementById: (id) => ({
    'waterfall-discovery': overlay,
    'waterfall-track': track,
    'waterfall-preferences': preferences,
    'waterfall-reader': reader
  })[id] ?? null,
  querySelector: () => null,
  querySelectorAll: (selector) => ({
    '[data-waterfall-back]': [backButton],
    '[data-waterfall-preferences]': [preferencesButton]
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
const window = {
  __aiphoneWaterfallInitial: {
    surfaceId: 'surface-1',
    currentId: 'current',
    enabledSources: ['youtube'],
    aggregateHtml: '',
    candidates: [candidate('current'), imageCandidate, textCandidate],
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
  setTimeout,
  clearTimeout
});
documentListeners.click({
  target: {
    closest: (selector) => selector === '[data-waterfall-enter]' ? {} : null
  }
});
assert.deepEqual(fullscreenStates, ['true']);
assert.match(track.innerHTML, /waterfall-card--video waterfall-card--landscape/);
assert.match(track.innerHTML, /waterfall-card--image-text/);
assert.match(track.innerHTML, /waterfall-card--text/);
assert.doesNotMatch(track.innerHTML, /data-waterfall-play/);
assert.match(track.innerHTML, /data-waterfall-read/);
assert.match(track.innerHTML, /data-waterfall-read="image-current"/);
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

const videoCard = element();
const videoFullscreenButton = {
  textContent: '全屏',
  closest: (selector) => selector === '.waterfall-card--video' ? videoCard : null
};
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-video-fullscreen]' ? videoFullscreenButton : null
  }
});
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), true);
assert.equal(videoFullscreenButton.textContent, '退出全屏');
track.emit('click', {
  target: {
    closest: (selector) => selector === '[data-waterfall-video-fullscreen]' ? videoFullscreenButton : null
  }
});
assert.equal(videoCard.classList.contains('waterfall-card--video-fullscreen'), false);
assert.equal(videoFullscreenButton.textContent, '全屏');

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

const readButton = { getAttribute: (name) => name === 'data-waterfall-read' ? 'text-current' : '' };
track.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-read]' ? readButton : null }
});
assert.equal(reader.classList.contains('active'), true);
assert.equal(track.classList.contains('reader-open'), true);
assert.match(reader.innerHTML, /A long text summary for the dedicated reader/);
reader.emit('click', {
  target: { closest: (selector) => selector === '[data-waterfall-reader-close]' ? {} : null }
});
assert.equal(reader.classList.contains('active'), false);
assert.equal(track.classList.contains('reader-open'), false);

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
const actionCountBeforeHalfScroll = actions.length;
track.emit('scroll');
assert.equal(actions.length, actionCountBeforeHalfScroll);
track.scrollTop = 1960;
track.emit('scroll');
assert.equal(actions.at(-1)?.id, 'waterfall.feed.advance');
assert.equal(actions.at(-1)?.args?.currentId, 'current');

const actionCountBeforeCatchUp = actions.length;
const writesBeforeCurrentAdvance = track.innerHTMLWrites;
window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'image-current',
  candidates: [candidate('current'), imageCandidate, textCandidate, candidate('late')]
});
assert.equal(track.scrollTop, 1960, 'server updates must not snap the user back to the first card');
assert.equal(track.innerHTMLWrites, writesBeforeCurrentAdvance, 'advancing must keep loaded media nodes alive');
assert.equal(actions.length, actionCountBeforeCatchUp + 1, 'a rapid multi-card swipe should continue advancing');
assert.equal(actions.at(-1)?.args?.currentId, 'image-current');

track.scrollTop = 0;
const actionCountBeforeBackScroll = actions.length;
track.emit('scroll');
assert.equal(actions.length, actionCountBeforeBackScroll, 'scrolling back into shown history must stay local');

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
const actionCountBeforeFilteredAdvance = actions.length;
track.scrollTop = 960;
track.emit('scroll');
assert.equal(actions.length, actionCountBeforeFilteredAdvance + 1, 'advance indices must use the filtered card list');
assert.equal(actions.at(-1)?.args?.currentId, 'x-current');

window.__aiphoneApplyWaterfallUpdate({
  ...window.__aiphoneWaterfallInitial,
  currentId: 'last',
  candidates: [candidate('last')],
  replenishing: false,
  exhausted: false
});
assert.match(track.innerHTML, /waterfall-tail-status/);
const actionCountBeforeLastCard = actions.length;
track.scrollTop = 960;
track.emit('scroll');
assert.equal(actions.length, actionCountBeforeLastCard + 1);
assert.equal(actions.at(-1)?.args?.currentId, 'last');
preferencesButton.emit('click');
assert.equal(preferences.classList.contains('active'), true);
backButton.emit('click');
assert.deepEqual(fullscreenStates, ['true', 'false']);
assert.equal(preferences.classList.contains('active'), false);

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
