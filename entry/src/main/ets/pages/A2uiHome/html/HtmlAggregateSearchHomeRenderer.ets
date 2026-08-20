import {
  A2uiAction,
  AggregateSearchSource,
  aggregateSearchInterestSourceIds,
  aggregateSearchRegistrySourceIds,
  aggregateSearchSearchSourceIds,
  aggregateSourceLabel as registryAggregateSourceLabel,
  WaterfallFeedState,
  WaterfallRankedCandidate,
  WaterfallSourceState
} from '@loop/agent-core';
import {
  HtmlHomeAction,
  HtmlHomeBlock,
  HtmlHomeDocument,
  HtmlHomeMetric,
  WaterfallBehaviorActionArgs,
  WaterfallHomePayload
} from './HtmlHomeTypes';
import {
  APP_LOGO_APPLE_PODCASTS,
  APP_LOGO_BILIBILI,
  APP_LOGO_DOUBAN,
  APP_LOGO_HACKERNEWS,
  APP_LOGO_REDDIT,
  APP_LOGO_TWITCH,
  APP_LOGO_X,
  APP_LOGO_YOUTUBE,
  APP_LOGO_ZHIHU
} from './AppLogoDataUri';

interface WaterfallSourceDisplayMetadata {
  source: AggregateSearchSource;
  label: string;
}

const WATERFALL_SOURCE_ONLY_SOURCES: AggregateSearchSource[] = ['applepodcasts', 'twitch'];
const WATERFALL_SOURCE_ONLY_SOURCES_JSON: string = JSON.stringify(WATERFALL_SOURCE_ONLY_SOURCES);
const WATERFALL_SEARCH_SOURCE_IDS_JSON: string = JSON.stringify(aggregateSearchSearchSourceIds());
const WATERFALL_INTEREST_SOURCE_IDS_JSON: string = JSON.stringify(aggregateSearchInterestSourceIds());

const WATERFALL_SOURCE_LABELS_JSON: string = JSON.stringify(
  aggregateSearchRegistrySourceIds().map((source: AggregateSearchSource): WaterfallSourceDisplayMetadata => ({
    source: source,
    label: registryAggregateSourceLabel(source)
  }))
);

const AGGREGATE_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --panel: rgba(255, 255, 255, 0.88);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --line-strong: rgba(24, 32, 27, 0.22);
  --video: #1d6a96;
  --video-soft: rgba(29, 106, 150, 0.12);
  --post: #9b5333;
  --post-soft: rgba(155, 83, 51, 0.12);
  --status: #526c45;
  --status-soft: rgba(82, 108, 69, 0.13);
  --notice: #8d3d3d;
  --notice-soft: rgba(141, 61, 61, 0.12);
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
}
* { box-sizing: border-box; }
button { font: inherit; }
body {
  margin: 0;
  min-height: 100vh;
  background: linear-gradient(180deg, rgba(255,255,255,0.72) 0%, rgba(255,255,255,0) 28%), var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", Arial, sans-serif;
  letter-spacing: 0;
}
h1, h2, h3, p { margin: 0; }
.aggregate-shell {
  width: min(100%, 980px);
  margin: 0 auto;
  padding: 20px 16px 40px;
}
.aggregate-hero {
  position: relative;
  display: flex;
  min-height: 170px;
  flex-direction: column;
  justify-content: flex-end;
  overflow: hidden;
  border-radius: 18px;
  padding: 18px;
  color: #fff;
  background:
    linear-gradient(90deg, rgba(17, 24, 20, 0.82), rgba(17, 24, 20, 0.34)),
    url("https://images.unsplash.com/photo-1495020689067-958852a7765e?auto=format&fit=crop&w=1400&q=80") center / cover;
  box-shadow: var(--shadow);
}
.aggregate-kicker {
  color: rgba(255, 255, 255, 0.78);
  font-size: 12px;
  line-height: 1.3;
}
.aggregate-hero h1 {
  margin-top: 8px;
  font-size: 34px;
  line-height: 1.04;
  font-weight: 830;
  overflow-wrap: anywhere;
  text-wrap: balance;
}
.aggregate-hero p {
  margin-top: 8px;
  max-width: 42rem;
  color: rgba(255, 255, 255, 0.78);
  font-size: 14px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.aggregate-keyword {
  display: inline-flex;
  width: fit-content;
  max-width: 100%;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  border: 1px solid rgba(255, 255, 255, 0.28);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.16);
  padding: 7px 10px;
  backdrop-filter: blur(14px);
}
.aggregate-keyword span {
  color: rgba(255, 255, 255, 0.72);
  font-size: 11px;
  line-height: 1;
}
.aggregate-keyword b {
  min-width: 0;
  color: #fff;
  font-size: 13px;
  line-height: 1.2;
  font-weight: 760;
  overflow-wrap: anywhere;
}
.aggregate-grid {
  display: grid;
  gap: 18px;
}
.aggregate-section {
  min-width: 0;
}
.aggregate-source-overview {
  margin: 16px 0 18px;
}
.aggregate-source-overview .aggregate-status-list {
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 8px;
}
.aggregate-source-overview .aggregate-card {
  border: 0;
  background: transparent;
  padding: 0;
  box-shadow: none;
}
.aggregate-status-card > summary {
  position: relative;
  display: grid;
  min-height: 52px;
  place-items: center;
  border: 0;
  border-radius: 0;
  background: transparent;
  padding: 0;
  list-style: none;
  cursor: pointer;
  transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), opacity 140ms ease-out;
}
.aggregate-status-card > summary:active {
  transform: scale(0.96);
  opacity: 0.86;
}
.aggregate-status-card > summary::-webkit-details-marker {
  display: none;
}
.aggregate-status-dot {
  width: 9px;
  height: 9px;
  border-radius: 999px;
  background: var(--status);
  box-shadow: 0 0 0 3px rgba(82, 108, 69, 0.14);
}
.aggregate-status-card[data-status="error"] .aggregate-status-dot,
.aggregate-status-card[data-status="unsupported"] .aggregate-status-dot,
.aggregate-status-card[data-status="needs_auth"] .aggregate-status-dot {
  background: var(--notice);
  box-shadow: 0 0 0 3px rgba(141, 61, 61, 0.14);
}
.aggregate-status-card[open] {
  position: relative;
  z-index: 12;
}
.aggregate-status-card {
  border: 0;
  border-radius: 0;
  background: transparent;
  padding: 0;
  box-shadow: none;
}
.aggregate-status-card[open]::before {
  content: '';
  position: fixed;
  z-index: 14;
  inset: 0;
  background: rgba(33, 27, 23, 0.18);
  backdrop-filter: blur(2px);
}
.aggregate-status-sheet {
  position: fixed;
  z-index: 15;
  left: 14px;
  right: 14px;
  bottom: calc(14px + env(safe-area-inset-bottom));
  max-height: min(62dvh, 520px);
  overflow-y: auto;
  border: 1px solid var(--line);
  border-radius: 24px;
  background: var(--panel-strong);
  box-shadow: var(--shadow);
  padding: 18px 18px 20px;
  animation: aggregate-status-sheet-in 220ms cubic-bezier(0.32, 0.72, 0, 1) both;
}
@keyframes aggregate-status-sheet-in {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}
.aggregate-status-sheet-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.aggregate-status-sheet-head strong {
  display: block;
  color: var(--ink);
  font-size: 16px;
  line-height: 1.25;
}
.aggregate-status-sheet-head span,
.aggregate-status-sheet-summary {
  display: block;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
}
.aggregate-status-sheet-head span {
  margin-top: 4px;
}
.aggregate-status-sheet button {
  flex: 0 0 auto;
  min-height: 44px;
  border: 1px solid var(--line-strong);
  border-radius: 12px;
  background: var(--paper);
  color: var(--ink);
  padding: 0 13px;
  font-size: 13px;
  font-weight: 720;
}
.aggregate-status-sheet-summary {
  margin: 12px 0 0;
  border-radius: 10px;
  background: var(--accent-soft);
  padding: 9px 10px;
  overflow-wrap: anywhere;
}
.aggregate-status-detail {
  margin-top: 12px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.aggregate-status-detail summary {
  display: flex;
  min-height: 44px;
  align-items: center;
  color: var(--accent);
  font-size: 13px;
  font-weight: 760;
  cursor: pointer;
  list-style: none;
}
.aggregate-status-detail summary::-webkit-details-marker {
  display: none;
}
.aggregate-status-detail summary::after {
  content: '⌄';
  margin-left: auto;
}
.aggregate-status-detail[open] summary::after {
  content: '⌃';
}
.aggregate-status-detail-copy {
  max-height: min(24dvh, 220px);
  overflow-y: auto;
  margin: 0;
  border-radius: 10px;
  background: var(--paper);
  color: var(--ink-soft);
  padding: 10px;
  font-size: 12px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.aggregate-status-summary:focus-visible,
.aggregate-status-detail summary:focus-visible,
.aggregate-status-sheet button:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 3px;
}
@media (hover: hover) and (pointer: fine) {
  .aggregate-status-card > summary:hover {
    transform: translateY(-1px);
  }
}
@media (prefers-reduced-motion: reduce) {
  .aggregate-status-card > summary {
    transition: opacity 140ms ease-out;
  }
  .aggregate-status-card > summary:active,
  .aggregate-status-card > summary:hover {
    transform: none;
  }
  .aggregate-status-sheet {
    animation: aggregate-status-sheet-fade 160ms ease-out both;
  }
}
@keyframes aggregate-status-sheet-fade {
  from { opacity: 0; }
  to { opacity: 1; }
}
.aggregate-section-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 10px;
}
.aggregate-section-head h2 {
  font-size: 18px;
  line-height: 1.2;
  font-weight: 780;
}
.aggregate-meta {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.35;
}
.aggregate-filter-rail {
  display: flex;
  gap: 8px;
  margin: -2px 0 18px;
  overflow-x: auto;
  padding: 4px 2px 10px;
  scrollbar-width: none;
}
.aggregate-filter-rail::-webkit-scrollbar {
  display: none;
}
.aggregate-filter {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  border: 1px solid var(--line);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.74);
  color: var(--muted);
  min-height: 36px;
  padding: 9px 12px;
  font-size: 12px;
  font-weight: 720;
  line-height: 1;
  cursor: pointer;
}
.aggregate-filter.active {
  border-color: var(--line-strong);
  background: #18201b;
  color: #fff;
}
.aggregate-filter .aggregate-app-icon {
  width: 18px;
  height: 18px;
  flex-basis: 18px;
  border-radius: 6px;
  font-size: 8px;
}
.aggregate-video-rail {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 12px;
}
.aggregate-post-list,
.aggregate-status-list,
.aggregate-notice-list {
  display: grid;
  gap: 10px;
}
.aggregate-card {
  --source-accent: var(--post);
  --source-soft: var(--post-soft);
  --source-surface: var(--panel);
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 12px;
  background: var(--source-surface);
  box-shadow: var(--shadow);
}
.aggregate-result-card {
  border-color: var(--source-soft);
  background:
    linear-gradient(145deg, rgba(255,255,255,0.78), rgba(255,255,255,0.3)),
    radial-gradient(circle at top left, var(--source-soft), transparent 58%),
    var(--source-surface);
}
.aggregate-card[data-kind="aggregate-video"] {
  border-color: rgba(29, 106, 150, 0.24);
}
.aggregate-card[data-kind="aggregate-post"] {
  border-color: rgba(155, 83, 51, 0.24);
}
.aggregate-card[data-kind="aggregate-source-status"] {
  border-color: rgba(82, 108, 69, 0.24);
}
.aggregate-card[data-kind="aggregate-source-status"][data-status="error"],
.aggregate-card[data-kind="aggregate-source-status"][data-status="unsupported"],
.aggregate-card[data-kind="aggregate-source-status"][data-status="needs_auth"] {
  border-color: rgba(141, 61, 61, 0.24);
}
.aggregate-card[data-source="youtube"],
.aggregate-filter[data-filter="youtube"] {
  --source-accent: #b34038;
  --source-soft: rgba(179, 64, 56, 0.14);
  --source-surface: #fff1ed;
}
.aggregate-card[data-source="bilibili"],
.aggregate-filter[data-filter="bilibili"] {
  --source-accent: #2f85a7;
  --source-soft: rgba(47, 133, 167, 0.16);
  --source-surface: #edf8fb;
}
.aggregate-card[data-source="x"],
.aggregate-filter[data-filter="x"] {
  --source-accent: #22272b;
  --source-soft: rgba(34, 39, 43, 0.12);
  --source-surface: #f4f4f1;
}
.aggregate-card[data-source="hackernews"],
.aggregate-filter[data-filter="hackernews"] {
  --source-accent: #b9682f;
  --source-soft: rgba(185, 104, 47, 0.15);
  --source-surface: #fff4e7;
}
.aggregate-card[data-source="reddit"],
.aggregate-filter[data-filter="reddit"] {
  --source-accent: #d44f24;
  --source-soft: rgba(212, 79, 36, 0.15);
  --source-surface: #fff3ed;
}
.aggregate-card[data-source="zhihu"],
.aggregate-filter[data-filter="zhihu"] {
  --source-accent: #2e68ad;
  --source-soft: rgba(46, 104, 173, 0.14);
  --source-surface: #eef5ff;
}
.aggregate-card-top {
  display: flex;
  align-items: center;
  gap: 8px;
}
.aggregate-app-icon {
  position: relative;
  display: inline-flex;
  width: 26px;
  height: 26px;
  flex: 0 0 26px;
  align-items: center;
  justify-content: center;
  border-radius: 0;
  background: transparent;
  overflow: hidden;
}
.aggregate-app-icon img {
  width: 100%;
  height: 100%;
  display: block;
  object-fit: contain;
}
.aggregate-status-card .aggregate-app-icon {
  width: 28px;
  height: 28px;
  flex-basis: 28px;
}
.aggregate-source-overview .aggregate-status-dot {
  position: absolute;
  right: calc(50% - 19px);
  bottom: 6px;
  width: 7px;
  height: 7px;
  box-shadow: 0 0 0 2px var(--paper);
}
.aggregate-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border-radius: 999px;
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
  font-weight: 760;
}
.aggregate-card[data-kind="aggregate-video"] .aggregate-tag {
  background: var(--video-soft);
  color: var(--video);
}
.aggregate-card[data-kind="aggregate-post"] .aggregate-tag {
  background: var(--post-soft);
  color: var(--post);
}
.aggregate-card[data-kind="aggregate-source-status"] .aggregate-tag {
  background: var(--status-soft);
  color: var(--status);
}
.aggregate-card[data-kind="aggregate-source-status"][data-status="error"] .aggregate-tag,
.aggregate-card[data-kind="aggregate-source-status"][data-status="unsupported"] .aggregate-tag,
.aggregate-card[data-kind="aggregate-source-status"][data-status="needs_auth"] .aggregate-tag {
  background: var(--notice-soft);
  color: var(--notice);
}
.aggregate-card h3 {
  margin-top: 9px;
  font-size: 16px;
  line-height: 1.3;
  font-weight: 780;
  overflow-wrap: anywhere;
}
.aggregate-card p {
  margin-top: 8px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
  overflow-wrap: anywhere;
}
.aggregate-post-card {
  padding: 0;
  cursor: pointer;
  overflow: hidden;
}
.aggregate-post-card summary {
  padding: 12px;
  list-style: none;
}
.aggregate-post-card summary::-webkit-details-marker {
  display: none;
}
.aggregate-post-title-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin-top: 10px;
}
.aggregate-post-title-row h3 {
  flex: 1;
  margin-top: 0;
}
.aggregate-expand-cue {
  flex: 0 0 auto;
  border: 1px solid var(--source-soft);
  border-radius: 999px;
  background: rgba(255,255,255,0.62);
  color: var(--source-accent);
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
  font-weight: 760;
}
.aggregate-expand-cue::after {
  content: '展开';
}
.aggregate-post-card[open] .aggregate-expand-cue::after {
  content: '收起';
}
.aggregate-summary-snippet {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  border-left: 3px solid var(--source-accent);
  padding-left: 10px;
  color: var(--ink);
  white-space: pre-wrap;
}
.aggregate-post-card[open] .aggregate-summary-snippet {
  display: none;
}
.aggregate-post-expanded {
  display: grid;
  gap: 12px;
  border-top: 1px solid var(--line);
  padding: 12px;
}
.aggregate-expanded-text {
  color: var(--ink);
  margin-top: 0;
  font-size: 14px;
  line-height: 1.65;
  white-space: pre-wrap;
}
.aggregate-post-media-grid {
  display: grid;
  gap: 8px;
}
.aggregate-post-media {
  width: 100%;
  max-height: 360px;
  border: 1px solid var(--line);
  border-radius: 12px;
  background: #e8ebe7;
  object-fit: cover;
}
.aggregate-link-preview {
  display: grid;
  gap: 4px;
  border: 1px solid var(--source-soft);
  border-radius: 12px;
  background: rgba(255,255,255,0.58);
  padding: 10px;
  color: var(--ink);
  text-decoration: none;
}
.aggregate-link-preview b {
  font-size: 13px;
  line-height: 1.25;
}
.aggregate-link-host {
  color: var(--muted);
  font-size: 11px;
  line-height: 1.2;
  overflow-wrap: anywhere;
}
.aggregate-post-metadata {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.aggregate-post-metadata span {
  display: inline-flex;
  align-items: baseline;
  gap: 4px;
  border-radius: 999px;
  background: rgba(255,255,255,0.58);
  color: var(--muted);
  padding: 5px 8px;
  font-size: 11px;
  line-height: 1;
}
.aggregate-post-metadata b {
  color: var(--source-accent);
  font-weight: 760;
}
.aggregate-embed {
  width: 100%;
  aspect-ratio: 16 / 9;
  margin-top: 12px;
  border: 0;
  border-radius: 12px;
  background: #d7dde1;
}
.aggregate-rows {
  display: grid;
  gap: 7px;
  margin-top: 12px;
}
.aggregate-row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding-top: 7px;
}
.aggregate-row b {
  display: block;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.25;
  font-weight: 700;
}
.aggregate-row span {
  display: block;
  margin-top: 4px;
  font-size: 13px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.aggregate-card[hidden],
.aggregate-section[hidden],
#aggregate-filter-empty[hidden] {
  display: none;
}
#aggregate-filter-empty {
  border: 1px dashed var(--line-strong);
  border-radius: 14px;
  color: var(--muted);
  padding: 14px;
  font-size: 13px;
}
@media (min-width: 900px) {
  .aggregate-grid {
    grid-template-columns: minmax(0, 1.05fr) minmax(300px, 0.8fr);
    align-items: start;
  }
}
.aggregate-shell {
  width: min(100%, 840px);
  padding: 14px 14px calc(96px + env(safe-area-inset-bottom));
}
.aggregate-hero {
  min-height: 180px;
  border-radius: 20px;
}
.aggregate-hero h1 {
  font-size: 32px;
}
.aggregate-card {
  border-radius: 16px;
  box-shadow: none;
}
.aggregate-filter,
.aggregate-post-card summary,
.aggregate-link-preview {
  transition: transform 150ms cubic-bezier(0.23, 1, 0.32, 1), opacity 150ms ease-out;
}
.aggregate-filter:active,
.aggregate-post-card summary:active,
.aggregate-link-preview:active {
  transform: scale(0.98);
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
`;

const AGGREGATE_JS: string = `
(function () {
  var activeFilter = 'all';
  function applyFilter(value) {
    var buttons = document.querySelectorAll('.aggregate-filter');
    var cards = document.querySelectorAll('.aggregate-result-card');
    var sections = document.querySelectorAll('[data-filter-section]');
    var empty = document.getElementById('aggregate-filter-empty');
    var visible = 0;
    cards.forEach(function (card) {
      var kind = card.getAttribute('data-kind') || '';
      var source = card.getAttribute('data-source') || '';
      var keep = value === 'all' ||
        (value === 'video' && kind === 'aggregate-video') ||
        (value === 'article' && kind === 'aggregate-post') ||
        source === value;
      card.hidden = !keep;
      if (keep) {
        visible += 1;
      }
    });
    buttons.forEach(function (button) {
      button.classList.toggle('active', button.getAttribute('data-filter') === value);
    });
    sections.forEach(function (section) {
      var sectionVisible = false;
      section.querySelectorAll('.aggregate-result-card').forEach(function (card) {
        if (!card.hidden) {
          sectionVisible = true;
        }
      });
      section.hidden = value !== 'all' && !sectionVisible;
    });
    if (empty !== null) {
      empty.hidden = visible > 0;
    }
  }
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') return;
    var statusClose = target.closest('[data-status-close]');
    if (statusClose) {
      var statusCard = statusClose.closest('.aggregate-status-card');
      if (statusCard) statusCard.open = false;
      return;
    }
    var button = target.closest('.aggregate-filter');
    if (!button) return;
    activeFilter = button.getAttribute('data-filter') || 'all';
    applyFilter(activeFilter);
  });
  window.__aiphoneRefreshAggregateSearch = function () { applyFilter(activeFilter); };
  applyFilter(activeFilter);
})();
`;

const WATERFALL_CSS: string = `
.waterfall-entry,
.waterfall-entry-floating {
  position: fixed; z-index: 8; left: 50%; bottom: calc(14px + env(safe-area-inset-bottom));
  display: flex; width: auto; max-width: calc(100% - 28px); margin: 0;
  pointer-events: none; transform: translateX(-50%);
}
.waterfall-entry button {
  display: inline-flex; width: auto; min-height: 44px; align-items: center; justify-content: center;
  border: 1px solid rgba(47, 78, 111, 0.22); border-radius: 999px;
  background: rgba(248, 251, 255, 0.98); box-shadow: 0 10px 28px rgba(47, 78, 111, 0.16);
  color: #2f4e6f; padding: 0 17px; font-size: 13px; font-weight: 760; cursor: pointer;
  pointer-events: auto; backdrop-filter: blur(14px);
  transition: transform 150ms cubic-bezier(0.23, 1, 0.32, 1), box-shadow 180ms ease-out;
}
.waterfall-overlay {
  position: fixed; inset: 0; z-index: 20; display: none; overflow: hidden;
  background: var(--paper); color: var(--ink); opacity: 0;
}
.waterfall-overlay.active {
  display: block; opacity: 1; animation: waterfall-overlay-in 180ms var(--ease-out) both;
}
.waterfall-overlay.active.closing { opacity: 0; animation: none; transition: opacity 140ms var(--ease-out); }
@keyframes waterfall-overlay-in { from { opacity: 0; } to { opacity: 1; } }
.waterfall-track {
  height: 100dvh; overflow-x: hidden; overflow-y: auto; overscroll-behavior-y: none;
  scroll-snap-type: y mandatory; scroll-padding-block: 18px; scrollbar-width: none;
  background: #eef0f2; padding: 18px 0 44px; touch-action: pan-y;
}
.waterfall-track::-webkit-scrollbar { display: none; }
.waterfall-card {
  position: relative; width: min(100%, 720px); height: auto; min-height: 0; margin: 0 auto 28px;
  scroll-snap-align: center; scroll-snap-stop: always; overflow: visible;
  background: transparent; isolation: isolate; contain: layout;
  opacity: 0.14; transform: translate3d(0, 0, 0) scale(0.955); transform-origin: center;
  transition: opacity 120ms var(--ease-out), transform 140ms var(--ease-out);
}
.waterfall-card.is-adjacent { opacity: 0.42; transform: translate3d(0, 0, 0) scale(0.975); }
.waterfall-card.is-active,
.waterfall-card--video-fullscreen { opacity: 1; transform: translate3d(0, 0, 0) scale(1); }
.waterfall-cinema-stage {
  position: absolute; top: max(88px, calc(62px + env(safe-area-inset-top))); left: 14px; right: 14px;
  height: min(48dvh, 420px); overflow: hidden; border: 1px solid var(--line); border-radius: 22px;
  background: linear-gradient(145deg, #e8edf2, #f4f6f8); box-shadow: 0 12px 32px rgba(39, 50, 62, 0.1);
}
.waterfall-media-cover {
  position: absolute; z-index: 1; inset: 0; display: block; width: 100%; height: 100%; object-fit: cover;
}
.waterfall-media-cover[hidden] { display: none; }
.waterfall-media-frame {
  position: absolute; z-index: 2; inset: 0; display: block; width: 100%; height: 100%;
  border: 0; background: #e8edf2; pointer-events: auto;
}
.waterfall-inline-play {
  position: absolute; z-index: 4; left: 50%; top: 50%; display: inline-flex; min-width: 72px; min-height: 48px;
  align-items: center; justify-content: center; transform: translate(-50%, -50%);
  border: 1px solid rgba(255, 255, 255, 0.62); border-radius: 999px;
  background: rgba(22, 28, 34, 0.84); box-shadow: 0 10px 30px rgba(12, 18, 24, 0.28);
  color: #fff; padding: 0 18px; font-size: 13px; font-weight: 780; cursor: pointer;
  backdrop-filter: blur(12px); transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.waterfall-inline-play:active { transform: translate(-50%, -50%) scale(0.96); }
.waterfall-inline-play:focus-visible { outline: 2px solid var(--accent); outline-offset: 3px; }
.waterfall-inline-play[hidden] { display: none; }
.waterfall-inline-audio {
  position: absolute; z-index: 4; left: 18px; right: 18px; top: 50%; bottom: auto; display: block;
  transform: translateY(-50%);
  width: calc(100% - 36px); min-height: 48px;
}
.waterfall-inline-error {
  position: absolute; z-index: 4; left: 18px; right: 18px; bottom: 18px;
  overflow: hidden; color: #fff; font-size: 12px; line-height: 1.4; text-align: center;
  text-overflow: ellipsis; white-space: nowrap; text-shadow: 0 1px 4px rgba(0, 0, 0, 0.72);
}
.waterfall-toast {
  position: fixed; z-index: 8; left: 50%; bottom: calc(28px + env(safe-area-inset-bottom));
  max-width: calc(100vw - 40px); padding: 12px 16px; border-radius: 14px;
  background: rgba(28, 34, 40, 0.94); color: #fff; font-size: 13px; line-height: 1.45; text-align: center;
  pointer-events: none; opacity: 0; transform: translate(-50%, 12px);
  transition: opacity 160ms var(--ease-out), transform 180ms var(--ease-out);
}
.waterfall-toast.active { opacity: 1; transform: translate(-50%, 0); }
.waterfall-card--inline-twitch .waterfall-cinema-stage { height: 300px; min-height: 300px; }
.waterfall-card--inline-twitch .waterfall-inline-media-frame {
  width: 100%; min-width: 0; height: 300px; min-height: 300px;
}
.waterfall-cinema-stage::after {
  content: ''; position: absolute; z-index: 3; inset: 68% 0 0;
  background: linear-gradient(180deg, rgba(244, 246, 248, 0), rgba(244, 246, 248, 0.32));
  pointer-events: none;
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-stage {
  height: min(42dvh, 360px);
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-stage::after {
  display: none;
}
.waterfall-card--video.waterfall-card--portrait .waterfall-cinema-stage {
  left: max(28px, 7vw); right: max(28px, 7vw); height: min(62dvh, 560px);
}
.waterfall-card--video.waterfall-card--portrait .waterfall-media-cover { object-position: center; }
.waterfall-video-fullscreen-toggle {
  position: absolute; z-index: 7; top: max(100px, calc(74px + env(safe-area-inset-top))); right: 28px;
  min-height: 44px; border: 0; border-radius: 999px; background: rgba(20, 24, 28, 0.78); color: #fff;
  padding: 0 14px; font-size: 12px; font-weight: 760; cursor: pointer;
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.waterfall-card--video-fullscreen {
  position: fixed; z-index: 40; inset: 0; width: 100%; height: 100dvh; min-height: 100dvh;
  margin: 0; contain: none; background: #000;
}
.waterfall-card--video-fullscreen .waterfall-cinema-stage {
  inset: 0; height: 100dvh !important; border: 0; border-radius: 0; box-shadow: none;
}
.waterfall-card--video-fullscreen .waterfall-cinema-copy { display: none; }
.waterfall-card--video-fullscreen .waterfall-video-fullscreen-toggle {
  top: calc(12px + env(safe-area-inset-top)); right: 16px;
}
.waterfall-card--image-text .waterfall-cinema-stage { height: min(50dvh, 440px); }
.waterfall-card--text { background: transparent; color: var(--ink); }
.waterfall-cinema-meta {
  display: inline-flex; min-height: 32px; align-items: center; gap: 8px;
  margin-bottom: 18px;
  color: #303841; font-size: 12px; font-weight: 740;
}
.waterfall-cinema-copy {
  position: absolute; z-index: 4; top: min(52dvh, 468px); left: 14px; right: 14px; bottom: calc(14px + env(safe-area-inset-bottom));
  display: flex; min-height: 0; flex-direction: column; overflow: hidden; padding: 18px;
  border: 1px solid var(--line); border-radius: 22px; background: rgba(255, 255, 255, 0.96);
  box-shadow: 0 12px 32px rgba(39, 50, 62, 0.08);
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-copy { top: min(calc(42dvh + 106px), 466px); }
.waterfall-card--video.waterfall-card--portrait .waterfall-cinema-copy {
  top: auto; max-height: min(42dvh, 390px); backdrop-filter: blur(18px);
}
.waterfall-card--image-text .waterfall-cinema-copy { top: min(55dvh, 488px); }
.waterfall-card--text .waterfall-cinema-copy {
  top: max(96px, calc(72px + env(safe-area-inset-top))); bottom: calc(14px + env(safe-area-inset-bottom)); max-height: none;
  display: flex; flex-direction: column; justify-content: flex-start;
}
.waterfall-cinema-card h2 {
  display: -webkit-box; max-width: none; margin-top: 0; overflow: hidden;
  -webkit-box-orient: vertical; -webkit-line-clamp: 4;
  color: var(--ink); font-size: clamp(26px, 7vw, 36px); line-height: 1.08; letter-spacing: -0.028em;
  font-weight: 800; overflow-wrap: anywhere; text-wrap: balance;
}
.waterfall-card--text h2 {
  max-width: 16ch; font-size: clamp(32px, 9vw, 46px); -webkit-line-clamp: 6;
}
.waterfall-cinema-card p {
  display: block; min-height: 0; max-width: none; flex: 1 1 auto; margin-top: 10px; overflow: hidden;
  color: #525c67; font-size: 14px; line-height: 1.5; overflow-wrap: anywhere;
  white-space: pre-wrap;
}
.waterfall-card--text p { color: #525c67; font-size: 16px; line-height: 1.62; }
.waterfall-copy-actions {
  display: flex; min-width: 0; flex: 0 0 auto; align-items: flex-end; justify-content: space-between;
  gap: 14px; margin-top: auto; padding-top: 16px;
}
.waterfall-card--text .waterfall-copy-actions { margin-top: auto; padding-bottom: 4px; }
.waterfall-action-group { display: inline-flex; flex: 0 0 auto; align-items: center; gap: 8px; }
.waterfall-cinema-card a, .waterfall-read-button {
  display: inline-flex; min-height: 44px; align-items: center; justify-content: center; width: fit-content;
  border: 1px solid #2f4e6f; border-radius: 999px; background: #2f4e6f; color: #fff;
  padding: 0 16px; font-size: 13px; font-weight: 780; text-decoration: none; cursor: pointer;
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.waterfall-cinema-card a { border-color: var(--line-strong); background: var(--panel); color: #2f4e6f; }
.waterfall-recommendation { min-width: 0; max-width: 26ch; color: var(--muted); font-size: 11px; line-height: 1.4; }
.waterfall-meta { margin-top: 7px; color: #747f8a; font-size: 12px; line-height: 1.35; }
.waterfall-reader {
  position: fixed; z-index: 8; inset: 0; display: block; overflow: hidden;
  background: #eef0f2; color: var(--ink); pointer-events: none; visibility: hidden;
  opacity: 0; border-radius: 0; transform: translate3d(0, 8px, 0) scale(0.985);
  transform-origin: center;
  transition: opacity 140ms var(--ease-out), transform 180ms var(--ease-out), visibility 0s linear 180ms;
}
.waterfall-reader.active {
  pointer-events: auto; visibility: visible; opacity: 1;
  transform: translate3d(0, 0, 0) scale(1); transition-delay: 0s;
}
.waterfall-reader.active.closing {
  pointer-events: auto; opacity: 0; transform: translate3d(0, 5px, 0) scale(0.99);
}
.waterfall-reader-body {
  height: 100dvh; overflow-y: auto; padding: calc(72px + env(safe-area-inset-top)) 24px calc(40px + env(safe-area-inset-bottom));
  overscroll-behavior-y: contain; opacity: 1; transition: none;
}
.waterfall-reader.active .waterfall-reader-body { opacity: 1; }
.waterfall-reader-head {
  position: fixed; z-index: 10; top: 0; left: 0; right: 0;
  min-height: calc(64px + env(safe-area-inset-top));
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: env(safe-area-inset-top) 12px 0; background: #eef0f2;
  border-bottom: 1px solid rgba(56, 65, 72, 0.09);
}
.waterfall-reader-head button {
  min-width: 44px; min-height: 44px; border: 0; border-radius: 14px; background: transparent; color: var(--ink);
  font-size: 13px; font-weight: 760;
  transition: transform 140ms var(--ease-out), background-color 140ms ease;
}
.waterfall-reader-source { color: #65696a; font-size: 12px; font-weight: 780; letter-spacing: 0.06em; text-transform: uppercase; }
.waterfall-reader h2 { max-width: 13ch; margin: 20px 0; font-size: clamp(34px, 9vw, 52px); line-height: 1.05; letter-spacing: -0.045em; }
.waterfall-reader p { margin: 0; color: #393d3f; font-size: 17px; line-height: 1.78; white-space: pre-wrap; }
.waterfall-source-logo {
  display: inline-flex; width: 28px; height: 28px; flex: 0 0 28px;
  align-items: center; justify-content: center; overflow: hidden; border-radius: 9px;
  background: rgba(255, 255, 255, 0.92); color: var(--ink);
  font-size: 11px; font-weight: 780;
}
.waterfall-source-logo img {
  display: block; width: 100%; height: 100%; object-fit: contain;
}
.waterfall-toolbar {
  position: fixed; z-index: 6; top: 0; left: 0; right: 0;
  min-height: calc(64px + env(safe-area-inset-top));
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: env(safe-area-inset-top) 12px 0; background: #eef0f2;
  border-bottom: 1px solid rgba(56, 65, 72, 0.09);
  pointer-events: auto;
}
.waterfall-toolbar button, .waterfall-preferences button {
  display: inline-flex; min-height: 44px; align-items: center; justify-content: center;
  border: 0; border-radius: 14px; background: transparent;
  color: #20262c; padding: 0 10px; font-size: 13px; font-weight: 720; cursor: pointer;
  pointer-events: auto;
  transition: transform 140ms var(--ease-out), background-color 140ms ease;
}
.waterfall-entry button,
.waterfall-toolbar button,
.waterfall-preferences button,
.waterfall-preferences label,
.waterfall-cinema-card a,
.waterfall-read-button,
.waterfall-inline-play,
.waterfall-reader-head button,
.waterfall-reader-head a,
.waterfall-empty button,
.waterfall-status button {
  touch-action: manipulation; -webkit-tap-highlight-color: transparent;
}
.waterfall-toolbar-primary {
  min-width: 76px; box-shadow: none;
  color: #20262c !important; font-weight: 780 !important;
}
.waterfall-toolbar-tools {
  display: inline-flex; align-items: center; gap: 8px;
  pointer-events: auto;
}
.waterfall-toolbar-secondary {
  width: 48px; min-width: 48px; padding: 0 !important;
  border: 0 !important; background: transparent !important; box-shadow: none;
}
.waterfall-source-control-logos { display: flex; align-items: center; justify-content: center; }
.waterfall-source-control-logos .waterfall-source-logo {
  width: 24px; height: 24px; min-width: 24px; flex-basis: 24px; border: 0; border-radius: 8px;
}
.waterfall-toolbar button:active, .waterfall-entry button:active, .waterfall-preferences button:active {
  transform: scale(0.96);
}
.waterfall-video-fullscreen-toggle:active,
.waterfall-cinema-card a:active,
.waterfall-read-button:active,
.waterfall-inline-play:active,
.waterfall-reader-head button:active {
  transform: scale(0.97);
}
.waterfall-video-fullscreen-toggle:focus-visible,
.waterfall-toolbar button:focus-visible, .waterfall-entry button:focus-visible,
.waterfall-preferences button:focus-visible, .waterfall-preferences input:focus-visible,
.waterfall-empty button:focus-visible, .waterfall-status button:focus-visible, .waterfall-read-button:focus-visible,
.waterfall-reader-head button:focus-visible {
  outline: 2px solid var(--accent); outline-offset: 3px;
}
.waterfall-preferences {
  position: fixed; z-index: 32; inset: auto 14px calc(14px + env(safe-area-inset-bottom)) 14px;
  display: block; max-height: min(72dvh, 560px); overflow-y: auto; padding: 14px;
  border: 1px solid rgba(38, 49, 60, 0.10); border-radius: 22px; background: #f9fafb;
  box-shadow: 0 18px 48px rgba(39, 50, 62, 0.16); pointer-events: none; transform: none;
  visibility: hidden; opacity: 0;
  transition: opacity 140ms var(--ease-out), visibility 0s linear 140ms;
}
.waterfall-preferences.active {
  pointer-events: auto; visibility: visible; opacity: 1; transition-delay: 0s;
}
.waterfall-preferences:not(.active),
.waterfall-preferences:not(.active) * {
  pointer-events: none !important;
}
.waterfall-preferences .waterfall-toolbar {
  position: static; inset: auto; display: grid; grid-template-columns: 44px 1fr auto; gap: 8px;
  align-items: center; padding: 0; margin: 0 0 14px; pointer-events: auto;
}
.waterfall-preferences .waterfall-toolbar b { font-size: 17px; text-align: center; }
.waterfall-source-grid {
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px;
}
.waterfall-preferences label {
  display: grid; min-width: 0; min-height: 60px; grid-template-columns: 32px minmax(0, 1fr) 20px;
  align-items: center; gap: 10px; border: 1px solid rgba(38, 49, 60, 0.08); border-radius: 16px;
  background: #fff; color: #20262c; padding: 10px; font-size: 14px;
  transition: transform 140ms cubic-bezier(0.23, 1, 0.32, 1), border-color 180ms ease-out;
}
.waterfall-preferences label:has(input:checked) { border-color: rgba(47, 78, 111, 0.22); background: #f0f4f7; }
.waterfall-source-name { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-weight: 720; }
.waterfall-preferences input { width: 18px; height: 18px; margin: 0; accent-color: var(--accent); }
.waterfall-empty {
  min-height: calc(100dvh - 150px); display: grid; place-items: center; align-content: center; gap: 14px;
  color: var(--muted); font-size: 16px; line-height: 1.5; padding: 20px; text-align: center;
}
.waterfall-empty button, .waterfall-status button {
  min-height: 48px; border: 1px solid var(--line-strong); border-radius: 14px; background: var(--panel);
  color: var(--ink); padding: 0 16px; font-size: 14px; font-weight: 720; cursor: pointer;
  transition: transform 140ms ease-out, box-shadow 180ms ease-out;
}
.waterfall-empty button:active, .waterfall-status button:active { transform: scale(0.97); }
.waterfall-status { color: var(--muted); font-size: 14px; line-height: 1.5; padding: 18px 20px 0; text-align: center; }
.waterfall-status--empty {
  min-height: calc(100dvh - 150px); display: grid; place-items: center; align-content: center; gap: 14px;
  padding: 20px;
}
.waterfall-tail-status {
  min-height: 100dvh; display: grid; place-items: center; scroll-snap-align: start;
  color: var(--muted); font-size: 14px; line-height: 1.5; padding: 24px; text-align: center;
}
/* Light single-card discovery presentation. */
.waterfall-card {
  --card-surface: #f1f2f0; --card-strong: #e7e9e6; --card-soft: #f6f6f3;
  --card-stage: #e3e6e3; --card-ink: #252a2d; --card-muted: #62696d;
  --card-accent: #496678; --card-line: rgba(52, 73, 87, 0.14); --card-shadow: rgba(52, 73, 87, 0.12);
}
.waterfall-tone--zhihu {
  --card-surface: #eff3f6; --card-strong: #e4ebf0; --card-soft: #f5f7f8; --card-stage: #e5ebef;
  --card-ink: #252a2d; --card-muted: #62696d; --card-accent: #1677b8; --card-line: rgba(22, 82, 122, 0.13); --card-shadow: rgba(22, 82, 122, 0.12);
}
.waterfall-tone--bilibili {
  --card-surface: #f4f1f2; --card-strong: #ece6e8; --card-soft: #f8f6f7; --card-stage: #ebe6e8;
  --card-ink: #292729; --card-muted: #686267; --card-accent: #c64f72; --card-line: rgba(138, 52, 78, 0.12); --card-shadow: rgba(138, 52, 78, 0.11);
}
.waterfall-tone--reddit {
  --card-surface: #f4f1ef; --card-strong: #ece6e2; --card-soft: #f8f6f4; --card-stage: #ebe6e2;
  --card-ink: #2b2826; --card-muted: #6b6561; --card-accent: #d34d1d; --card-line: rgba(146, 65, 30, 0.12); --card-shadow: rgba(146, 65, 30, 0.11);
}
.waterfall-tone--youtube {
  --card-surface: #f4f1f1; --card-strong: #ece5e5; --card-soft: #f8f6f6; --card-stage: #ebe5e5;
  --card-ink: #2b2828; --card-muted: #6b6464; --card-accent: #bd3733; --card-line: rgba(132, 48, 44, 0.12); --card-shadow: rgba(132, 48, 44, 0.11);
}
.waterfall-tone--hackernews {
  --card-surface: #f4f2ed; --card-strong: #ebe7dc; --card-soft: #f8f7f3; --card-stage: #eae6dc;
  --card-ink: #2b2a27; --card-muted: #6b6860; --card-accent: #a96216; --card-line: rgba(125, 83, 24, 0.12); --card-shadow: rgba(125, 83, 24, 0.11);
}
.waterfall-tone--x {
  --card-surface: #f1f2f2; --card-strong: #e5e8e9; --card-soft: #f6f7f7; --card-stage: #e5e7e8;
  --card-ink: #262a2c; --card-muted: #62686b; --card-accent: #303b43; --card-line: rgba(45, 56, 64, 0.12); --card-shadow: rgba(45, 56, 64, 0.11);
}
.waterfall-card-shell {
  position: relative; top: auto; right: auto; bottom: auto; left: auto;
  display: flex; height: auto; min-height: 0; flex-direction: column; overflow: hidden; margin: 0 14px; padding: 12px;
  border: 1px solid rgba(56, 65, 72, 0.07); border-radius: 24px;
  background: #fbfcfd;
  color: var(--card-ink);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.92), 0 12px 30px var(--card-shadow);
  cursor: default; touch-action: pan-y;
  transition: transform 140ms var(--ease-out), box-shadow 180ms ease-out;
}
.waterfall-card-shell,
.waterfall-card-shell * {
  -webkit-tap-highlight-color: transparent;
  -webkit-user-select: none;
  user-select: none;
}
.waterfall-card-shell--interactive { cursor: pointer; }
.waterfall-card--video .waterfall-card-shell { background: #fbfcfd; }
.waterfall-card--text .waterfall-card-shell { background: var(--card-soft); }
.waterfall-card-shell--interactive:active,
.waterfall-card-shell--interactive.is-pressed { transform: scale(0.992); }
.waterfall-card-shell--interactive:focus-visible,
.waterfall-source-action:focus-visible,
.waterfall-reader-head a:focus-visible {
  outline: 2px solid var(--accent); outline-offset: 3px;
}
.waterfall-track.video-open { overflow: hidden; scroll-snap-type: none; }
.waterfall-overlay.reading .waterfall-track,
.waterfall-overlay.sheet-open .waterfall-track {
  pointer-events: none; touch-action: none;
}
.waterfall-card--video-fullscreen .waterfall-card-shell {
  position: fixed; z-index: 40; inset: 0; width: 100%; height: 100dvh; padding: 0;
  border: 0; border-radius: 0; background: #171716; box-shadow: none; transform: none;
}
.waterfall-cinema-stage {
  position: relative; top: auto; right: auto; left: auto; flex: 0 0 auto;
  height: min(46dvh, 400px); border: 0; border-radius: 20px;
  background: var(--card-stage); box-shadow: none;
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-stage {
  width: 100%; height: auto; max-height: min(38dvh, 330px); aspect-ratio: 16 / 9;
}
.waterfall-card--video.waterfall-card--portrait .waterfall-cinema-stage {
  right: auto; left: auto; width: min(68%, 270px); height: auto; max-height: min(49dvh, 440px);
  aspect-ratio: 9 / 16; align-self: center;
}
.waterfall-card--video.waterfall-card--portrait .waterfall-media-cover { object-fit: contain; }
.waterfall-card--image-text .waterfall-cinema-stage { height: min(40dvh, 360px); }
.waterfall-cinema-stage::after { display: none; }
.waterfall-cinema-copy {
  position: relative; z-index: 4; top: auto; right: auto; bottom: auto; left: auto;
  display: flex; min-height: 0; flex: 0 0 auto; flex-direction: column; overflow: visible;
  padding: 16px 4px 4px; border: 0; border-radius: 0; background: transparent; box-shadow: none;
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-copy,
.waterfall-card--video.waterfall-card--portrait .waterfall-cinema-copy,
.waterfall-card--image-text .waterfall-cinema-copy,
.waterfall-card--text .waterfall-cinema-copy {
  top: auto; bottom: auto; max-height: none; backdrop-filter: none;
}
.waterfall-card--text { background: transparent; }
.waterfall-card--text .waterfall-card-shell { min-height: min(44dvh, 420px); padding: 22px; }
.waterfall-card--text .waterfall-cinema-copy { flex: 1 1 auto; padding: 0; }
.waterfall-cinema-meta { margin-bottom: 12px; }
.waterfall-cinema-card h2 {
  margin: 0; color: var(--card-ink); font-size: clamp(24px, 6.3vw, 32px); line-height: 1.13;
  letter-spacing: -0.022em; font-weight: 700;
}
.waterfall-card--text h2 { max-width: 17ch; font-size: clamp(25px, 6.8vw, 32px); }
.waterfall-cinema-card p {
  display: -webkit-box; flex: 0 0 auto; margin-top: 10px; overflow: hidden; color: var(--card-muted);
  font-size: 15px; line-height: 1.58; white-space: normal; -webkit-box-orient: vertical; -webkit-line-clamp: 3;
}
.waterfall-card--text p { font-size: 15px; line-height: 1.65; -webkit-line-clamp: 4; }
.waterfall-copy-actions {
  align-items: center; margin-top: 8px; padding-top: 8px; border-top: 0;
}
.waterfall-card--text .waterfall-copy-actions { margin-top: auto; }
.waterfall-action-group { margin-left: auto; }
.waterfall-recommendation {
  overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.waterfall-source-action {
  display: inline-grid; width: 44px !important; min-width: 44px; min-height: 44px;
  place-items: center; border: 0 !important; border-radius: 999px !important;
  background: rgba(255,255,255,0.46) !important; color: var(--card-accent) !important;
  padding: 0 !important; text-decoration: none; cursor: pointer;
  transition: transform 140ms var(--ease-out), background-color 180ms ease;
}
.waterfall-icon { display: inline-grid; place-items: center; pointer-events: none; }
.waterfall-icon svg {
  display: block; width: 20px; height: 20px; fill: none; stroke: currentColor; stroke-width: 1.9;
  stroke-linecap: round; stroke-linejoin: round;
}
.waterfall-video-controls {
  position: absolute; z-index: 7; top: 26px; right: 26px; display: flex; align-items: center; gap: 10px;
}
.waterfall-source-action:active { transform: scale(0.97); }
.waterfall-video-fullscreen-toggle {
  position: relative; top: auto; right: auto; width: 44px; min-width: 44px; padding: 0;
  background: rgba(20, 24, 28, 0.72); font-size: 0;
}
.waterfall-exit-fullscreen-icon { display: none; }
.waterfall-video-source-action { display: none !important; }
.waterfall-card--video-fullscreen .waterfall-video-controls {
  position: fixed; top: calc(12px + env(safe-area-inset-top)); right: 16px; left: 16px;
  justify-content: space-between;
}
.waterfall-card--video-fullscreen .waterfall-enter-fullscreen-icon { display: none; }
.waterfall-card--video-fullscreen .waterfall-exit-fullscreen-icon { display: inline-grid; }
.waterfall-card--video-fullscreen .waterfall-video-source-action {
  display: inline-grid !important; background: rgba(20, 24, 28, 0.72) !important; color: #fff !important;
}
.waterfall-card--video-fullscreen .waterfall-cinema-stage {
  position: absolute; inset: 0; width: 100%; height: 100dvh !important; border-radius: 0;
  background: #171716;
}
.waterfall-card--video-fullscreen .waterfall-media-cover,
.waterfall-card--video-fullscreen .waterfall-media-frame { object-fit: contain; }
.waterfall-toolbar {
  top: 0; left: 0; right: 0; min-height: calc(64px + env(safe-area-inset-top));
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: env(safe-area-inset-top) 12px 0; background: #eef0f2;
  border-bottom: 1px solid rgba(56, 65, 72, 0.09);
  opacity: 1; transform: none; visibility: visible; pointer-events: auto;
}
.waterfall-toolbar button,
.waterfall-toolbar-title {
  min-width: 44px; min-height: 44px; border: 0; border-radius: 14px;
  background: transparent; color: var(--ink); box-shadow: none;
  backdrop-filter: none;
}
.waterfall-toolbar-primary {
  width: auto; min-width: 76px; justify-content: flex-start !important; gap: 6px;
  justify-self: start; padding: 0 10px !important; font-size: 13px !important;
}
.waterfall-toolbar-label { font-size: 13px; font-weight: 760; line-height: 1; }
.waterfall-toolbar-title {
  display: inline-flex; align-items: center; justify-content: center; padding: 0 16px;
  font-size: 15px; font-weight: 780; pointer-events: none;
}
.waterfall-toolbar-secondary {
  width: auto; min-width: 68px; gap: 6px; padding: 0 10px !important;
  border: 0 !important; background: transparent !important;
}
.waterfall-toolbar-tools { justify-self: end; }
.waterfall-toolbar button:active { background: #dde3e8; transform: scale(0.97); }
.waterfall-toolbar .waterfall-toolbar-secondary:active { background: #dde3e8 !important; }
.waterfall-track { padding-top: calc(76px + env(safe-area-inset-top)); }
.waterfall-preferences .waterfall-toolbar {
  min-height: 44px; background: transparent; border-bottom: 0;
  opacity: 1; transform: none; visibility: visible; transition: none;
}
.waterfall-reader { background: #eef0f2; }
.waterfall-reader-head {
  z-index: 10; top: 0; left: 0; right: 0; min-height: calc(64px + env(safe-area-inset-top));
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: env(safe-area-inset-top) 12px 0; background: #eef0f2;
  border-bottom: 1px solid rgba(56, 65, 72, 0.09);
  opacity: 1; transform: none; visibility: visible;
  transition: opacity 120ms var(--ease-out), transform 140ms var(--ease-out);
}
.waterfall-reader-head button,
.waterfall-reader-head a {
  display: inline-flex; width: auto !important; min-width: 44px; min-height: 44px;
  align-items: center; justify-content: center; gap: 6px; border: 0 !important; border-radius: 14px !important;
  background: transparent !important; color: var(--ink); padding: 0 10px !important; text-decoration: none;
  box-shadow: none; backdrop-filter: none;
  touch-action: manipulation;
}
.waterfall-reader-head button { justify-self: start; }
.waterfall-reader-head > :last-child { justify-self: end; }
.waterfall-reader-head-title { align-self: center; font-size: 15px; font-weight: 780; }
.waterfall-reader-head-label { font-size: 13px; font-weight: 760; line-height: 1; }
.waterfall-reader-head button:active,
.waterfall-reader-head a:active,
.waterfall-reader-head button.is-pressed,
.waterfall-reader-head a.is-pressed,
.waterfall-toolbar button.is-pressed,
.waterfall-preferences button.is-pressed {
  background: #dde3e8 !important; transform: scale(0.97);
}
.waterfall-reader-body { padding: calc(82px + env(safe-area-inset-top)) 22px calc(48px + env(safe-area-inset-bottom)); }
.waterfall-reader-layout { width: min(100%, 640px); margin: 0 auto; }
.waterfall-toolbar button,
.waterfall-reader-head button,
.waterfall-reader-head a,
.waterfall-preferences button {
  -webkit-tap-highlight-color: transparent; touch-action: manipulation; cursor: pointer;
}
.waterfall-reader-media {
  height: min(44dvh, 390px); overflow: hidden; margin-bottom: 24px; border-radius: 22px;
  background: #e7eaed; box-shadow: 0 10px 28px rgba(42,55,69,0.09);
}
.waterfall-reader-media img,
.waterfall-reader-media iframe,
.waterfall-reader-media video { display: block; width: 100%; height: 100%; border: 0; object-fit: cover; }
.waterfall-reader-media--video { height: auto; margin-bottom: 0; aspect-ratio: 16 / 9; background: #e6e3dd; box-shadow: none; }
.waterfall-reader--video.waterfall-reader--portrait .waterfall-reader-media--video {
  width: min(72%, 360px); margin-right: auto; margin-left: auto; aspect-ratio: 9 / 16;
}
.waterfall-reader-video-card {
  overflow: hidden; border: 1px solid rgba(56,65,72,0.07); border-radius: 24px; padding: 12px;
  background: #fbfcfd;
  box-shadow: 0 20px 48px rgba(42,55,69,0.12);
}
.waterfall-reader-video-copy { padding: 18px 8px 10px; }
.waterfall-reader-video-stage { position: relative; }
.waterfall-reader-video-poster { position: absolute; z-index: 1; inset: 0; }
.waterfall-reader-video-fallback {
  position: absolute; z-index: 0; inset: 0; display: grid; place-content: center; justify-items: center; gap: 10px;
  background: #ebe8e2; color: var(--muted); font-size: 13px; font-weight: 720;
}
.waterfall-reader-video-frame {
  position: absolute; z-index: 2; inset: 0; opacity: 0; pointer-events: none;
  transition: opacity 180ms var(--ease-out);
}
.waterfall-reader-video-frame .waterfall-media-frame { position: absolute; inset: 0; }
.waterfall-reader-video-play {
  position: absolute; z-index: 3; inset: 0; display: grid; place-content: center; justify-items: center; gap: 9px;
  border: 0; background: linear-gradient(180deg, rgba(20,20,18,0.02), rgba(20,20,18,0.20)); color: #fff;
  font-size: 13px; font-weight: 760; cursor: pointer;
}
.waterfall-reader-video-play .waterfall-icon {
  width: 54px; height: 54px; border-radius: 999px; background: rgba(20,20,18,0.72);
  box-shadow: 0 10px 28px rgba(20,20,18,0.24); backdrop-filter: blur(14px);
}
.waterfall-reader-video-play .waterfall-icon svg { width: 24px; height: 24px; }
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-frame { opacity: 1; pointer-events: auto; }
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-poster,
.waterfall-reader-video-stage.is-playing .waterfall-media-cover,
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-play { opacity: 0; pointer-events: none; }
.waterfall-reader--video .waterfall-reader-context { margin-bottom: 14px; }
.waterfall-reader--video h2 { max-width: 18ch; margin: 0 0 12px; font-size: clamp(27px, 7vw, 38px); line-height: 1.12; }
.waterfall-reader--video p { font-size: 15px; line-height: 1.68; }
.waterfall-reader-context { display: flex; align-items: center; justify-content: space-between; gap: 12px; color: var(--muted); }
.waterfall-reader-source { display: inline-flex; align-items: center; gap: 8px; color: var(--accent); text-transform: none; letter-spacing: 0; }
.waterfall-reader h2 { max-width: 14ch; margin: 16px 0 20px; font-size: clamp(34px, 8.8vw, 50px); line-height: 1.08; }
.waterfall-reader p { color: #423d38; font-size: 17px; line-height: 1.82; }
.waterfall-reader--text h2 { max-width: 12ch; }
@media (hover: hover) and (pointer: fine) {
  .waterfall-entry button:hover, .waterfall-toolbar button:hover, .waterfall-preferences label:hover {
    transform: translateY(-1px);
  }
}
@media (prefers-reduced-motion: reduce) {
  .waterfall-overlay.active { animation: waterfall-overlay-in 140ms var(--ease-out) both !important; }
  .waterfall-overlay.active.closing { animation: none !important; }
  .waterfall-entry button, .waterfall-toolbar button, .waterfall-preferences button,
  .waterfall-preferences label, .waterfall-empty button, .waterfall-status button,
  .waterfall-inline-play { transition: none; }
  .waterfall-reader {
    transform: none;
    transition: none !important;
  }
  .waterfall-preferences {
    transform: none;
    transition: opacity 140ms var(--ease-out), visibility 0s linear 140ms !important;
  }
  .waterfall-reader.active,
  .waterfall-preferences.active { transition-delay: 0s !important; }
  .waterfall-reader-body {
    transform: none !important;
    transition: opacity 140ms var(--ease-out) !important;
  }
  .waterfall-reader-layout,
  .waterfall-reader.active .waterfall-reader-layout,
  .waterfall-reader.active.closing .waterfall-reader-layout {
    transform: none !important;
    transition: opacity 140ms var(--ease-out) !important;
  }
  .waterfall-video-fullscreen-toggle,
  .waterfall-card-shell,
  .waterfall-cinema-card a,
  .waterfall-read-button,
  .waterfall-inline-play,
  .waterfall-reader-head button,
  .waterfall-reader-head a,
  .waterfall-reader-head,
  .waterfall-toolbar {
    transition: opacity 140ms var(--ease-out), background-color 140ms ease !important;
  }
  .waterfall-entry button:active, .waterfall-toolbar button:active, .waterfall-preferences button:active,
  .waterfall-preferences label:active, .waterfall-empty button:active { transform: none; }
  .waterfall-video-fullscreen-toggle:active,
  .waterfall-card-shell--interactive:active,
  .waterfall-card-shell--interactive.is-pressed,
  .waterfall-cinema-card a:active,
  .waterfall-read-button:active,
  .waterfall-inline-play:active,
  .waterfall-reader-head button:active { transform: none; opacity: 0.82; }
  .waterfall-reader-head,
  .waterfall-toolbar { transform: none !important; }
  .waterfall-card,
  .waterfall-card.is-adjacent,
  .waterfall-card.is-active { transform: none !important; }
}
`;

const WATERFALL_JS: string = `
(function () {
  var overlay = document.getElementById('waterfall-discovery');
  var track = document.getElementById('waterfall-track');
  var preferences = document.getElementById('waterfall-preferences');
  var reader = document.getElementById('waterfall-reader');
  var toolbar = document.getElementById('waterfall-toolbar');
  var toast = document.getElementById('waterfall-toast');
  var state = window.__aiphoneWaterfallInitial || null;
  var directDiscovery = window.__aiphoneWaterfallDirect === true;
  var mode = directDiscovery ? 'discovering' : 'entry';
  var enabledSources = state && state.enabledSources ? state.enabledSources.slice() : [];
  var preferenceBaseline = '';
  var aggregateHtml = state && state.aggregateHtml ? state.aggregateHtml : '';
  var advancePending = false;
  var renderedCurrentId = '';
  var renderedCards = [];
  var alignToCurrent = false;
  var alignToCandidateId = '';
  var closeTimer = null;
  var readerCloseTimer = null;
  var preferenceApplyTimer = null;
  var presentationFrame = null;
  var advanceTimer = null;
  var playerCleanupTimer = null;
  var metricTimer = null;
  var payloadSettleTimer = null;
  var metricsDirty = false;
  var cardMetrics = [];
  var presentedIndex = -1;
  var interactionActive = false;
  var scrollActive = false;
  var afterPaintPending = false;
  var afterPaintTimer = null;
  var fullscreenVideoCard = null;
  var behaviorTimer = null;
  var behaviorCandidateId = '';
  var behaviorStartedAt = 0;
  var behaviorDurationMs = 0;
  var readerCandidateId = '';
  var readerMountedId = '';
  var readerFeedScrollTop = 0;
  var readerStartedAt = 0;
  var readerDurationMs = 0;
  var pageAnchorIndex = -1;
  var pagingClamp = false;
  var ignoreNextFeedOpen = false;
  var emittedBehavior = {};
  var pendingPayload = null;
  window.__aiphoneApplyWaterfallUpdate = function (payload) {
    pendingPayload = payload;
    if (mode === 'reading' || mode === 'reader_closing' || mode === 'source_preferences' ||
      mode === 'source_preferences_closing' || interactionActive || scrollActive) return;
    flushPendingPayload();
  };
  function flushPendingPayload(enabledOverride) {
    if (!pendingPayload) return false;
    if (payloadSettleTimer !== null) clearTimeout(payloadSettleTimer);
    payloadSettleTimer = null;
    scrollActive = false;
    var payload = pendingPayload;
    pendingPayload = null;
    var previousCurrentId = state ? text(state.currentId) : '';
    mergePayload(payload);
    if (enabledOverride) enabledSources = enabledOverride.slice();
    if (!render()) scheduleAdvance(updateCardPresentation());
    if (previousCurrentId !== text(state && state.currentId)) {
      pauseCurrentBehavior(false);
      behaviorCandidateId = '';
      behaviorDurationMs = 0;
    }
    resumeCurrentBehavior();
    return true;
  }
  var activeInlinePlayer = null;
  var activeInlineButton = null;
  var activeInlineCard = null;
  var activeInlineCandidateId = '';
  var shownAudioErrors = {};
  var toastTimer = null;
  function text(value) { return value === null || value === undefined ? '' : String(value); }
  function escapeHtml(value) { return text(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;'); }
  function cleanSummary(value) {
    return text(value).trim().replace(/^[^：:\\n]{0,16}(?:搜索结果|检索结果|结果摘要)[ ：:]*/i, '').trim();
  }
  function publishedLabel(value) { return text(value).trim().replace(/^(\\d{4}-\\d{2}-\\d{2})T.*$/, '$1'); }
  function sourceLabel(source) {
    var labels = ${WATERFALL_SOURCE_LABELS_JSON};
    for (var index = 0; index < labels.length; index++) {
      if (labels[index].source === source) return labels[index].label;
    }
    return source;
  }
  function sourceTone(source) {
    var key = text(source).trim().toLowerCase();
    return ['youtube', 'bilibili', 'reddit', 'zhihu', 'hackernews', 'x'].indexOf(key) >= 0 ? key : 'neutral';
  }
  function sourceLogoMarkup(source) {
    var logos = window.__aiphoneWaterfallSourceLogos || {};
    var logo = text(logos[source]);
    var fallback = escapeHtml(sourceLabel(source).slice(0, 2));
    return '<span class="waterfall-source-logo" aria-hidden="true">' +
      (logo ? '<img src="' + escapeHtml(logo) + '" alt="" />' : fallback) + '</span>';
  }
  function uiIcon(name) {
    var icons = window.__aiphoneWaterfallUiIcons || {};
    return text(icons[name]);
  }
  function videoEmbedForUrl(value) {
    var raw = text(value).trim();
    if (!raw) return '';
    try {
      var parsed = new URL(raw);
      var host = parsed.hostname.toLowerCase();
      if (host === 'youtu.be') {
        var shortId = parsed.pathname.split('/').filter(Boolean)[0] || '';
        return shortId ? 'https://www.youtube.com/embed/' + encodeURIComponent(shortId) + '?playsinline=1' : '';
      }
      if (host.indexOf('youtube.com') >= 0) {
        var youtubeId = parsed.searchParams.get('v') || '';
        return youtubeId ? 'https://www.youtube.com/embed/' + encodeURIComponent(youtubeId) + '?playsinline=1' : '';
      }
      if (host.indexOf('bilibili.com') >= 0) {
        var parts = parsed.pathname.split('/').filter(Boolean);
        var bvid = parts.find(function (part) { return part.indexOf('BV') === 0; }) || '';
        return bvid ? 'https://player.bilibili.com/player.html?bvid=' + encodeURIComponent(bvid) + '&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true' : '';
      }
    } catch (_error) {}
    return '';
  }
  function videoPlaybackData(item) {
    var embeds = state && state.mediaEmbeds ? state.mediaEmbeds : {};
    var embedUrl = text(embeds[item.url]) || videoEmbedForUrl(item.url);
    return embedUrl ? { kind: 'iframe', url: embedUrl } :
      (text(item.mediaUrl) ? { kind: 'video', url: text(item.mediaUrl) } : null);
  }
  function videoStageMarkup(item, title, classes, posterClass) {
    var playback = videoPlaybackData(item);
    var poster = '<div class="waterfall-reader-video-fallback">' + sourceLogoMarkup(item.source) +
      '<span>播放视频</span></div>' + (item.coverUrl ? '<img class="' + posterClass + '" src="' +
      escapeHtml(item.coverUrl) + '" alt="' + escapeHtml(title) +
      '" loading="lazy" decoding="async" referrerpolicy="no-referrer" onerror="this.hidden=true" />' : '');
    if (!playback) return item.coverUrl ? '<div class="' + classes + '">' + poster + '</div>' : '';
    var play = '<button type="button" class="waterfall-reader-video-play" ' +
      'data-waterfall-video-play aria-label="播放视频">' + uiIcon('play') + '<span>播放视频</span></button>';
    return '<div class="' + classes + ' waterfall-reader-video-stage" data-waterfall-video-kind="' +
      playback.kind + '" data-waterfall-video-url="' + escapeHtml(playback.url) + '">' + poster +
      '<div class="waterfall-reader-video-frame"></div>' + play + '</div>';
  }
  function autoplayVideoUrl(value) {
    var url = text(value);
    return url.indexOf('autoplay=0') >= 0 ? url.replace('autoplay=0', 'autoplay=1') :
      url + (url.indexOf('?') >= 0 ? '&' : '?') + 'autoplay=1';
  }
  function playVideo(control) {
    var stage = control && typeof control.closest === 'function' ? control.closest('.waterfall-reader-video-stage') : null;
    if (!stage || typeof stage.getAttribute !== 'function' || typeof stage.querySelector !== 'function') return;
    var frame = stage.querySelector('.waterfall-reader-video-frame');
    var kind = text(stage.getAttribute('data-waterfall-video-kind'));
    var url = text(stage.getAttribute('data-waterfall-video-url'));
    if (!frame || !url) return;
    if (!frame.innerHTML) {
      frame.innerHTML = kind === 'iframe' ? '<iframe class="waterfall-media-frame" src="' +
        escapeHtml(autoplayVideoUrl(url)) + '" title="视频播放" allow="autoplay; encrypted-media; fullscreen; picture-in-picture" ' +
        'allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe>' :
        '<video class="waterfall-media-frame" src="' + escapeHtml(url) + '" controls autoplay playsinline></video>';
    }
    stage.classList.add('is-playing');
    var videoCard = control.closest('.waterfall-reader-video-card');
    if (videoCard) videoCard.classList.add('is-playing');
    var player = frame.querySelector('video');
    if (player && typeof player.play === 'function') player.play();
  }
  function openSource(link, event) {
    var url = link ? text(link.href || (typeof link.getAttribute === 'function' ? link.getAttribute('href') : '')) : '';
    if (!url || !window.AIPhoneHome || typeof window.AIPhoneHome.openWaterfallSource !== 'function') return false;
    if (event && typeof event.preventDefault === 'function') event.preventDefault();
    window.AIPhoneHome.openWaterfallSource(url);
    return true;
  }
  function bindFastTap(target, handler) {
    if (!target || typeof target.addEventListener !== 'function') return;
    var tapX = 0;
    var tapY = 0;
    var tapping = false;
    var handled = false;
    var pressed = null;
    function pressNode(event) {
      var node = event.target;
      if (!node || typeof node.closest !== 'function') return null;
      return node.closest('button, a, [role="button"], [data-waterfall-open]');
    }
    function setPressed(node, on) {
      if (!node || !node.classList) return;
      node.classList.toggle('is-pressed', on);
    }
    target.addEventListener('touchstart', function (event) {
      if (!event) return;
      var touch = event.touches && event.touches[0];
      if (!touch) return;
      tapX = touch.clientX;
      tapY = touch.clientY;
      tapping = true;
      handled = false;
      pressed = pressNode(event);
      setPressed(pressed, true);
    }, { passive: true });
    target.addEventListener('touchcancel', function () {
      tapping = false;
      setPressed(pressed, false);
      pressed = null;
    }, { passive: true });
    target.addEventListener('touchend', function (event) {
      if (!event) {
        tapping = false;
        setPressed(pressed, false);
        pressed = null;
        return;
      }
      var touch = event.changedTouches && event.changedTouches[0];
      var wasTapping = tapping;
      tapping = false;
      if (!wasTapping || !touch) {
        setPressed(pressed, false);
        pressed = null;
        return;
      }
      if (Math.abs(touch.clientX - tapX) > 12 || Math.abs(touch.clientY - tapY) > 12) {
        setPressed(pressed, false);
        pressed = null;
        return;
      }
      if (handler(event)) {
        handled = true;
        setPressed(pressed, false);
        pressed = null;
        if (event.cancelable && typeof event.preventDefault === 'function') event.preventDefault();
        return;
      }
      setPressed(pressed, false);
      pressed = null;
    });
    target.addEventListener('click', function (event) {
      if (!event) return;
      if (handled) {
        handled = false;
        if (typeof event.preventDefault === 'function') event.preventDefault();
        return;
      }
      if (handler(event) && typeof event.preventDefault === 'function') event.preventDefault();
    });
  }

  function showNewAudioError(items) {
    if (!toast) return;
    for (var resetIndex = 0; resetIndex < items.length; resetIndex++) {
      var loadingItem = items[resetIndex];
      if (loadingItem.source === 'applepodcasts' && loadingItem.audioLoadState === 'loading') {
        shownAudioErrors[text(loadingItem.id)] = '';
      }
    }
    for (var index = 0; index < items.length; index++) {
      var item = items[index];
      var message = text(item.audioError).trim();
      if (item.source !== 'applepodcasts' || item.audioLoadState !== 'error' || !message) continue;
      var key = text(item.id);
      if (shownAudioErrors[key] === message) continue;
      shownAudioErrors[key] = message;
      toast.textContent = message;
      toast.classList.add('active');
      if (toastTimer !== null) clearTimeout(toastTimer);
      toastTimer = setTimeout(function () {
        toast.classList.remove('active');
        toastTimer = null;
      }, 2600);
      return;
    }
  }
  function twitchEmbedForUrl(value) {
    var raw = text(value).trim();
    if (!raw) return '';
    try {
      var parsed = new URL(raw);
      var host = parsed.hostname.toLowerCase();
      var parts = parsed.pathname.split('/').filter(Boolean);
      var login = parts.length === 1 ? parts[0] : '';
      var reserved = ['directory', 'downloads', 'jobs', 'p', 'search', 'settings', 'subscriptions', 'videos'];
      var parent = text(window.location && window.location.hostname).trim().toLowerCase();
      if (parsed.protocol !== 'https:' || (host !== 'twitch.tv' && host !== 'www.twitch.tv') ||
        parsed.port || parsed.username || parsed.password || parsed.search || parsed.hash ||
        !/^[a-z0-9_]{1,25}$/i.test(login) || reserved.indexOf(login.toLowerCase()) >= 0 ||
        !/^[a-z0-9.-]+$/i.test(parent)) return '';
      return 'https://player.twitch.tv/?channel=' + encodeURIComponent(login.toLowerCase()) +
        '&parent=' + encodeURIComponent(parent) + '&autoplay=false&muted=false';
    } catch (_error) {}
    return '';
  }
  function resolvedAudioUrl(value) {
    var raw = text(value).trim();
    if (!raw) return '';
    try {
      var parsed = new URL(raw);
      var host = parsed.hostname.toLowerCase();
      if (parsed.protocol !== 'https:' || parsed.port || parsed.username || parsed.password || !host ||
        host === 'localhost' || host.slice(-10) === '.localhost' || host.slice(-6) === '.local' ||
        host.indexOf(':') >= 0 || /^[0-9]+(?:\\.[0-9]+){3}$/.test(host)) return '';
      return raw;
    } catch (_error) {}
    return '';
  }
  function cardById(id) {
    if (!track || typeof track.querySelectorAll !== 'function') return null;
    var cards = track.querySelectorAll('[data-waterfall-id]');
    for (var index = 0; index < cards.length; index++) {
      if (typeof cards[index].getAttribute === 'function' && text(cards[index].getAttribute('data-waterfall-id')) === text(id)) {
        return cards[index];
      }
    }
    return null;
  }
  function destroyInlinePlayer(clearCandidate) {
    var player = activeInlinePlayer;
    var button = activeInlineButton;
    activeInlinePlayer = null;
    activeInlineButton = null;
    activeInlineCard = null;
    if (clearCandidate !== false) activeInlineCandidateId = '';
    if (player && typeof player.pause === 'function') player.pause();
    if (player && typeof player.remove === 'function') player.remove();
    if (button) {
      button.hidden = false;
      button.disabled = false;
    }
  }
  function mountTwitchPlayer(item, button, card, stage) {
    var embedUrl = twitchEmbedForUrl(item.url);
    if (!embedUrl || !button || !card || !stage || typeof document.createElement !== 'function') return;
    destroyInlinePlayer(false);
    var frame = document.createElement('iframe');
    frame.className = 'waterfall-media-frame waterfall-inline-media-frame';
    frame.setAttribute('data-inline-source', 'twitch');
    frame.setAttribute('title', 'Twitch 直播播放器');
    frame.setAttribute('loading', 'eager');
    frame.setAttribute('allow', 'autoplay; encrypted-media; fullscreen; picture-in-picture');
    frame.setAttribute('allowfullscreen', '');
    frame.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
    if (typeof frame.addEventListener === 'function') {
      frame.addEventListener('error', function () {
        if (activeInlinePlayer === frame) destroyInlinePlayer();
      }, { once: true });
    }
    frame.setAttribute('src', embedUrl);
    stage.appendChild(frame);
    activeInlinePlayer = frame;
    activeInlineButton = button;
    activeInlineCard = card;
    button.hidden = true;
  }
  function mountApplePodcastAudio(item, button, card, stage) {
    var mediaUrl = resolvedAudioUrl(item.mediaUrl);
    if (!mediaUrl || !button || !card || !stage || typeof document.createElement !== 'function') return;
    destroyInlinePlayer(false);
    var audio = document.createElement('audio');
    audio.className = 'waterfall-inline-audio';
    audio.setAttribute('controls', '');
    audio.setAttribute('preload', 'none');
    audio.setAttribute('playsinline', '');
    audio.setAttribute('title', text(item.audioTitle).trim() || 'Apple Podcasts 音频');
    if (typeof audio.addEventListener === 'function') {
      audio.addEventListener('error', function () {
        if (activeInlinePlayer === audio) {
          destroyInlinePlayer();
          button.textContent = '重试';
        }
      }, { once: true });
    }
    audio.setAttribute('src', mediaUrl);
    stage.appendChild(audio);
    activeInlinePlayer = audio;
    activeInlineButton = button;
    activeInlineCard = card;
    button.hidden = true;
  }
  function syncActiveInlinePlayer() {
    if (!activeInlineCandidateId || activeInlinePlayer) return;
    var item = candidateById(activeInlineCandidateId);
    var card = cardById(activeInlineCandidateId);
    if (!item || !card) {
      destroyInlinePlayer();
      return;
    }
    if (typeof card.querySelector !== 'function') return;
    var stage = card.querySelector('.waterfall-cinema-stage');
    if (!stage) return;
    if (item.source === 'twitch') {
      mountTwitchPlayer(item, card.querySelector('[data-waterfall-inline-play]'), card, stage);
    } else if (item.source === 'applepodcasts' && item.audioLoadState === 'ready') {
      mountApplePodcastAudio(item, card.querySelector('[data-waterfall-apple-play]'), card, stage);
    }
  }
  function activateTwitchPlayer(button) {
    if (!button || typeof button.getAttribute !== 'function' || typeof button.closest !== 'function') return;
    var candidateId = text(button.getAttribute('data-waterfall-inline-play'));
    var item = candidateById(candidateId);
    var stage = button.closest('.waterfall-cinema-stage');
    var card = button.closest('[data-waterfall-id]');
    if (!item || item.source !== 'twitch' || !stage || !card) return;
    destroyInlinePlayer();
    activeInlineCandidateId = candidateId;
    mountTwitchPlayer(item, button, card, stage);
  }
  function postApplePodcastResolve(candidateId) {
    if (!state || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.applepodcasts.resolve', label: '加载播客', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', candidateId: candidateId }
    }));
  }
  function activateApplePodcast(button) {
    if (!button || typeof button.getAttribute !== 'function' || typeof button.closest !== 'function') return;
    var candidateId = text(button.getAttribute('data-waterfall-apple-play'));
    var item = candidateById(candidateId);
    if (!item || item.source !== 'applepodcasts' || !text(item.feedUrl).trim()) return;
    destroyInlinePlayer();
    activeInlineCandidateId = candidateId;
    if (item.audioLoadState === 'ready' && resolvedAudioUrl(item.mediaUrl)) {
      syncActiveInlinePlayer();
      return;
    }
    button.disabled = true;
    button.textContent = '加载中';
    postApplePodcastResolve(candidateId);
  }
  function setFullscreen(active) {
    if (window.AIPhoneHome && typeof window.AIPhoneHome.setWaterfallFullscreen === 'function') {
      window.AIPhoneHome.setWaterfallFullscreen(active ? 'true' : 'false');
    }
  }
  function candidates(payload) {
    if (!payload) return [];
    var values = payload.candidates || [];
    var seen = {};
    return values.filter(function (item) {
      var key = text(item.id) || text(item.normalizedUrl);
      if (!key || seen[key]) return false;
      seen[key] = true;
      return true;
    });
  }
  function renderedOrderCandidates(payload) {
    var items = candidates(payload).filter(function (item) {
      return enabledSources.indexOf(item.source) >= 0;
    });
    if (renderedCards.length === 0) return items;
    var indexed = {};
    items.forEach(function (item) { indexed['$' + text(item.id)] = item; });
    var ordered = [];
    var included = {};
    renderedCards.forEach(function (rendered) {
      var key = '$' + rendered.id;
      if (!indexed[key]) return;
      ordered.push(indexed[key]);
      included[key] = true;
    });
    items.forEach(function (item) {
      var key = '$' + text(item.id);
      if (included[key]) return;
      ordered.push(item);
      included[key] = true;
    });
    return ordered;
  }
  function candidateById(id) {
    return candidates(state).find(function (item) { return text(item.id) === text(id); }) || null;
  }
  function candidateFormat(item) {
    if (item && item.mediaType === 'video') {
      return text(item.format) === 'portrait_video' ? 'portrait_video' : 'landscape_video';
    }
    return item && item.mediaType === 'image_text' && text(item.coverUrl).trim() ? 'image_text' : 'text';
  }
  function cardClassName(item) {
    var format = candidateFormat(item);
    var cardClass = item.mediaType === 'video' ?
      'waterfall-card waterfall-cinema-card waterfall-card--video waterfall-card--' +
        (format === 'portrait_video' ? 'portrait' : 'landscape') :
      (format === 'image_text' ?
        'waterfall-card waterfall-cinema-card waterfall-card--image-text' :
        'waterfall-card waterfall-cinema-card waterfall-card--text');
    return cardClass + ' waterfall-tone--' + sourceTone(item.source);
  }
  function setSearchShellHidden(hidden) {
    var shell = document.querySelector('.aggregate-shell');
    if (!shell) return;
    shell.hidden = hidden === true;
  }
  function applyDeferredAggregateHtml() {
    if (!aggregateHtml) return;
    var shell = document.querySelector('.aggregate-shell');
    if (!shell) return;
    shell.innerHTML = aggregateHtml;
    if (window.__aiphoneRefreshAggregateSearch) window.__aiphoneRefreshAggregateSearch();
  }
  function stopReaderMedia() {
    if (!reader || typeof reader.querySelector !== 'function') return;
    var frame = reader.querySelector('.waterfall-reader-video-frame');
    if (frame) frame.innerHTML = '';
    var playing = reader.querySelector('.is-playing');
    if (playing && playing.classList) playing.classList.remove('is-playing');
  }
  function visibleCardIndex() {
    if (!track) return 0;
    if (cardMetrics.length === 0) refreshCardMetrics();
    if (cardMetrics.length === 0) return 0;
    var bestIndex = 0;
    var bestDistance = Infinity;
    for (var index = 0; index < cardMetrics.length; index += 1) {
      var distance = Math.abs(cardMetrics[index].snapTop - track.scrollTop);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    if (presentedIndex >= 0 && presentedIndex < cardMetrics.length) {
      if (Math.abs(bestIndex - presentedIndex) > 1) {
        bestIndex = bestIndex > presentedIndex ? presentedIndex + 1 : presentedIndex - 1;
      }
      var currentTop = cardMetrics[presentedIndex].snapTop;
      var next = cardMetrics[presentedIndex + 1];
      var previous = cardMetrics[presentedIndex - 1];
      if (next && track.scrollTop >= currentTop + (next.snapTop - currentTop) * 0.32) {
        bestIndex = presentedIndex + 1;
      } else if (previous && track.scrollTop <= previous.snapTop + (currentTop - previous.snapTop) * 0.32) {
        bestIndex = presentedIndex - 1;
      } else {
        bestIndex = presentedIndex;
      }
    }
    if (pageAnchorIndex >= 0) {
      var lo = Math.max(0, pageAnchorIndex - 1);
      var hi = Math.min(cardMetrics.length - 1, pageAnchorIndex + 1);
      if (bestIndex < lo) bestIndex = lo;
      if (bestIndex > hi) bestIndex = hi;
    }
    return bestIndex;
  }
  function refreshCardMetrics() {
    if (!track || typeof track.querySelectorAll !== 'function') return;
    if (metricTimer !== null) clearTimeout(metricTimer);
    metricTimer = null;
    metricsDirty = false;
    var nodes = track.querySelectorAll('[data-waterfall-id]');
    var viewportHeight = Math.max(1, track.clientHeight);
    cardMetrics = [];
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      var top = typeof node.offsetTop === 'number' ? node.offsetTop : index * viewportHeight;
      var height = typeof node.offsetHeight === 'number' && node.offsetHeight > 0 ? node.offsetHeight : viewportHeight;
      cardMetrics.push({ node: node, snapTop: Math.max(0, top - Math.max(0, viewportHeight - height) / 2) });
    }
  }
  function updateCardPresentation(force) {
    if (!track || typeof track.querySelectorAll !== 'function') return 0;
    var nodes = track.querySelectorAll('[data-waterfall-id]');
    if (!nodes || nodes.length === 0) return 0;
    if (cardMetrics.length === 0) refreshCardMetrics();
    else if (cardMetrics.length !== nodes.length) syncCardsAfterPaint();
    var activeIndex = visibleCardIndex();
    if (!force && activeIndex === presentedIndex) return activeIndex;
    if (activeIndex > nodes.length - 1) activeIndex = nodes.length - 1;
    var start = activeIndex - 1;
    var end = activeIndex + 1;
    if (presentedIndex >= 0) {
      if (presentedIndex - 1 < start) start = presentedIndex - 1;
      if (presentedIndex + 1 > end) end = presentedIndex + 1;
    }
    if (start < 0) start = 0;
    if (end > nodes.length - 1) end = nodes.length - 1;
    for (var index = start; index <= end; index += 1) {
      var node = nodes[index];
      if (!node || !node.classList) continue;
      var distance = Math.abs(index - activeIndex);
      if (node.classList.contains('is-active') !== (distance === 0)) {
        node.classList.toggle('is-active', distance === 0);
      }
      if (node.classList.contains('is-adjacent') !== (distance === 1)) {
        node.classList.toggle('is-adjacent', distance === 1);
      }
    }
    presentedIndex = activeIndex;
    return activeIndex;
  }
  function syncCardsAfterPaint() {
    metricsDirty = true;
    var sync = function () {
      afterPaintTimer = null;
      afterPaintPending = false;
      if (metricsDirty) refreshCardMetrics();
      scheduleAdvance(updateCardPresentation(true));
    };
    // Reading layout in the same task that appended cards forces a full synchronous
    // relayout of the feed, so the read waits until the browser has painted. This keeps
    // its own timer: sharing metricTimer lets a scroll cancel the pending presentation.
    if (typeof window.requestAnimationFrame !== 'function') {
      sync();
      return;
    }
    if (afterPaintPending) return;
    afterPaintPending = true;
    window.requestAnimationFrame(function () {
      if (afterPaintTimer !== null) clearTimeout(afterPaintTimer);
      afterPaintTimer = setTimeout(sync, 0);
    });
  }
  function refreshMetricsAfterSettle() {
    metricsDirty = true;
    if (metricTimer !== null) clearTimeout(metricTimer);
    metricTimer = setTimeout(function () {
      metricTimer = null;
      if (metricsDirty) refreshCardMetrics();
    }, 96);
  }
  function cleanupInactivePlayers() {
    if (!track || mode !== 'discovering' || typeof track.querySelectorAll !== 'function') return;
    var nodes = track.querySelectorAll('[data-waterfall-id]');
    var inlineCard = activeInlineCard || cardById(activeInlineCandidateId);
    if (activeInlineCandidateId && nodes[presentedIndex] !== inlineCard) destroyInlinePlayer();
    for (var index = 0; index < nodes.length; index += 1) {
      if (index === presentedIndex || typeof nodes[index].querySelector !== 'function') continue;
      var stage = nodes[index].querySelector('.waterfall-reader-video-stage.is-playing');
      if (!stage) continue;
      var frame = stage.querySelector('.waterfall-reader-video-frame');
      if (frame) frame.innerHTML = '';
      stage.classList.remove('is-playing');
    }
  }
  function scheduleAdvance(index) {
    if (advanceTimer !== null) clearTimeout(advanceTimer);
    advanceTimer = setTimeout(function () {
      advanceTimer = null;
      postAdvanceIfNeeded(index);
    }, 72);
    if (playerCleanupTimer !== null) clearTimeout(playerCleanupTimer);
    playerCleanupTimer = setTimeout(function () {
      playerCleanupTimer = null;
      cleanupInactivePlayers();
    }, 180);
  }
  function scrollTopForCard(index) {
    if (!track || index < 0) return 0;
    var nodes = typeof track.querySelectorAll === 'function' ? track.querySelectorAll('[data-waterfall-id]') : [];
    var node = nodes && nodes[index];
    if (!node || typeof node.offsetTop !== 'number') return index * track.clientHeight;
    var height = typeof node.offsetHeight === 'number' && node.offsetHeight > 0 ? node.offsetHeight : track.clientHeight;
    return Math.max(0, node.offsetTop - Math.max(0, track.clientHeight - height) / 2);
  }
  function clampPagingScroll() {
    if (pageAnchorIndex < 0 || !track || cardMetrics.length === 0) return;
    var lo = Math.max(0, pageAnchorIndex - 1);
    var hi = Math.min(cardMetrics.length - 1, pageAnchorIndex + 1);
    var minTop = cardMetrics[lo].snapTop;
    var maxTop = cardMetrics[hi].snapTop;
    if (track.scrollTop <= maxTop && track.scrollTop >= minTop) return;
    pagingClamp = true;
    track.scrollTop = track.scrollTop > maxTop ? maxTop : minTop;
    pagingClamp = false;
  }
  function snapPagingCard() {
    if (pageAnchorIndex < 0 || !track || mode !== 'discovering') return;
    if (cardMetrics.length === 0) refreshCardMetrics();
    var index = visibleCardIndex();
    var top = scrollTopForCard(index);
    if (Math.abs(track.scrollTop - top) > 1) {
      pagingClamp = true;
      track.scrollTop = top;
      pagingClamp = false;
    }
    updateCardPresentation(true);
  }
  function beginPagingGesture() {
    if (mode !== 'discovering') return;
    if (cardMetrics.length === 0) refreshCardMetrics();
    pageAnchorIndex = presentedIndex < 0 ? 0 : presentedIndex;
  }
  function postBehavior(id, behavior, durationMs) {
    var item = candidateById(id);
    var key = text(id) + '|' + behavior;
    if (!item || emittedBehavior[key] || !state || !window.AIPhoneHome ||
      typeof window.AIPhoneHome.postAction !== 'function') return;
    emittedBehavior[key] = true;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.behavior.record', label: '行为', prompt: '', variant: 'secondary', kind: 'client',
      args: {
        surfaceId: state.surfaceId || '', candidateId: text(item.id), topics: item.topics || [],
        source: text(item.source), format: candidateFormat(item), behavior: behavior,
        durationMs: Math.max(0, Math.round(durationMs)), timestamp: Date.now()
      }
    }));
  }
  function clearBehaviorTimer() {
    if (behaviorTimer !== null) clearTimeout(behaviorTimer);
    behaviorTimer = null;
  }
  function pauseCurrentBehavior(emitQuickSkip) {
    if (behaviorStartedAt > 0) behaviorDurationMs += Math.max(0, Date.now() - behaviorStartedAt);
    behaviorStartedAt = 0;
    clearBehaviorTimer();
    if (emitQuickSkip && behaviorCandidateId && behaviorDurationMs < 2000) {
      postBehavior(behaviorCandidateId, 'quick_skip', behaviorDurationMs);
    }
  }
  function resumeCurrentBehavior() {
    if (mode !== 'discovering' || document.hidden || !state || !state.currentId) return;
    var nextId = text(state.currentId);
    if (behaviorCandidateId && behaviorCandidateId !== nextId) {
      pauseCurrentBehavior(true);
      behaviorDurationMs = 0;
    }
    behaviorCandidateId = nextId;
    if (behaviorStartedAt > 0 || emittedBehavior[nextId + '|dwell']) return;
    behaviorStartedAt = Date.now();
    clearBehaviorTimer();
    behaviorTimer = setTimeout(function () {
      behaviorDurationMs += Math.max(0, Date.now() - behaviorStartedAt);
      behaviorStartedAt = Date.now();
      postBehavior(behaviorCandidateId, 'dwell', behaviorDurationMs);
      behaviorTimer = null;
    }, Math.max(0, 8000 - behaviorDurationMs));
  }
  function mergePayload(payload) {
    if (!payload) return;
    var oldCurrentId = state ? text(state.currentId) : '';
    var oldEnabledSources = state && state.enabledSources ? state.enabledSources.join('|') : '';
    if (typeof payload.aggregateHtml === 'string' && payload.aggregateHtml !== aggregateHtml) {
      aggregateHtml = payload.aggregateHtml;
      if (!overlay || !overlay.classList.contains('active')) {
        applyDeferredAggregateHtml();
      }
    }
    state = payload;
    enabledSources = payload.enabledSources ? payload.enabledSources.slice() : [];
    if (oldEnabledSources !== enabledSources.join('|')) alignToCurrent = true;
    if (!oldCurrentId || oldCurrentId !== text(payload.currentId)) advancePending = false;
  }
  function postSourceSelection() {
    if (!state || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.sources.select', label: '内容来源', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', enabledSources: enabledSources }
    }));
  }
  function postAdvanceIfNeeded(presentedIndex) {
    var items = renderedOrderCandidates(state);
    if (!track) return;
    var currentId = state ? text(state.currentId) : '';
    var currentIndex = items.findIndex(function (item) { return text(item.id) === currentId; });
    var visibleIndex = typeof presentedIndex === 'number' ? presentedIndex : visibleCardIndex();
    if (mode !== 'discovering' || advancePending || currentIndex < 0 || visibleIndex <= currentIndex ||
      !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    pauseCurrentBehavior(true);
    advancePending = true;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.feed.advance', label: '下一条', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', currentId: currentId }
    }));
  }
  function closeReader() {
    if (!reader || reader.classList.contains('closing')) return;
    destroyInlinePlayer();
    reader.classList.add('closing');
    ignoreNextFeedOpen = true;
    mode = 'reader_closing';
    stopReaderMedia();
    var completedCandidateId = readerCandidateId;
    if (readerCandidateId && readerStartedAt > 0) {
      readerDurationMs += Math.max(0, Date.now() - readerStartedAt);
    }
    var completedDurationMs = readerDurationMs;
    readerCandidateId = '';
    readerStartedAt = 0;
    readerDurationMs = 0;
    if (readerCloseTimer !== null) clearTimeout(readerCloseTimer);
    readerCloseTimer = setTimeout(function () {
      reader.classList.remove('active');
      reader.classList.remove('closing');
      if (overlay) overlay.classList.remove('reading');
      readerCloseTimer = null;
      if (track) {
        if (track.scrollTop !== readerFeedScrollTop) track.scrollTop = readerFeedScrollTop;
      }
      mode = 'discovering';
      if (directDiscovery) setFullscreen(false);
      if (pendingPayload) {
        settleInteraction();
      }
      resumeCurrentBehavior();
      if (completedCandidateId && completedDurationMs >= 8000) {
        postBehavior(completedCandidateId, 'read_complete', completedDurationMs);
      }
    }, 180);
  }
  function openReader(id) {
    if (!reader || !track) return;
    var item = candidates(state).find(function (candidate) { return text(candidate.id) === text(id); });
    if (!item || ${WATERFALL_SOURCE_ONLY_SOURCES_JSON}.indexOf(item.source) >= 0) return;
    destroyInlinePlayer();
    var format = candidateFormat(item);
    var summary = cleanSummary(item.summary) || cleanSummary(item.reason);
    var title = text(item.title).trim() || sourceLabel(item.source) + ' 内容';
    var readerClass = format === 'image_text' ? 'waterfall-reader--image-text' :
      (item.mediaType === 'video' ? 'waterfall-reader--video waterfall-reader--' +
        (format === 'portrait_video' ? 'portrait' : 'landscape') : 'waterfall-reader--text');
    if (readerCloseTimer !== null) clearTimeout(readerCloseTimer);
    readerCloseTimer = null;
    if (advanceTimer !== null) clearTimeout(advanceTimer);
    advanceTimer = null;
    if (playerCleanupTimer !== null) clearTimeout(playerCleanupTimer);
    playerCleanupTimer = null;
    reader.classList.remove('active');
    reader.classList.remove('closing');
    var videoStage = item.mediaType === 'video' ? videoStageMarkup(item, title,
      'waterfall-reader-media waterfall-reader-media--video', 'waterfall-reader-video-poster') : '';
    var media = format === 'image_text' ?
      '<div class="waterfall-reader-media"><img src="' + escapeHtml(item.coverUrl) + '" alt="' +
      escapeHtml(title) + '" referrerpolicy="no-referrer" onerror="this.parentElement.hidden=true" /></div>' :
      (item.mediaType === 'video' ? videoStage : '');
    var sourceAction = item.url ? '<a class="waterfall-source-action" href="' + escapeHtml(item.url) +
      '" rel="noopener noreferrer" aria-label="查看来源">' + uiIcon('external') + '</a>' : '<span></span>';
    var context = '<div class="waterfall-reader-context"><div class="waterfall-reader-source">' +
      sourceLogoMarkup(item.source) + '<span>' + escapeHtml(sourceLabel(item.source)) + '</span></div><span>' +
      escapeHtml(publishedLabel(item.publishedAt)) + '</span></div>';
    var copy = context + '<h2>' + escapeHtml(title) + '</h2>' +
      (summary ? '<p>' + escapeHtml(summary) + '</p>' : '');
    var content = item.mediaType === 'video' ? '<section class="waterfall-reader-video-card">' + media +
      '<div class="waterfall-reader-video-copy">' + copy + '</div></section>' : media + copy;
    var nextId = text(item.id);
    if (readerMountedId !== nextId) {
      reader.innerHTML = '<div class="waterfall-reader-head">' +
        '<button type="button" class="waterfall-chrome-btn" data-waterfall-reader-close ' +
        'aria-label="返回发现流">' + uiIcon('back') +
        '<span class="waterfall-reader-head-label">返回</span></button>' +
        '<strong class="waterfall-reader-head-title">详情</strong>' + sourceAction +
        '</div><article class="waterfall-reader-body"><div class="waterfall-reader-layout ' +
        readerClass + '">' + content + '</div></article>';
      readerMountedId = nextId;
    } else if (typeof reader.querySelector === 'function') {
      var readerBody = reader.querySelector('.waterfall-reader-body');
      if (readerBody) readerBody.scrollTop = 0;
    }
    pauseCurrentBehavior(false);
    readerFeedScrollTop = track.scrollTop;
    readerCandidateId = text(item.id);
    readerStartedAt = Date.now();
    readerDurationMs = 0;
    mode = 'reading';
    if (directDiscovery) setFullscreen(true);
    ignoreNextFeedOpen = false;
    if (overlay) overlay.classList.add('reading');
    reader.classList.add('active');
  }
  function toggleVideoFullscreen(videoCard) {
    if (!videoCard) return;
    var active = !videoCard.classList.contains('waterfall-card--video-fullscreen');
    videoCard.classList.toggle('waterfall-card--video-fullscreen', active);
    if (track) track.classList.toggle('video-open', active);
    fullscreenVideoCard = active ? videoCard : null;
    var button = typeof videoCard.querySelector === 'function' ?
      videoCard.querySelector('[data-waterfall-video-fullscreen]') : null;
    if (button && typeof button.setAttribute === 'function') {
      button.setAttribute('aria-label', active ? '退出全屏' : '全屏播放');
    }
    if (active) {
      pauseCurrentBehavior(false);
      mode = 'video_fullscreen';
    } else {
      mode = 'discovering';
      updateCardPresentation();
      resumeCurrentBehavior();
    }
    if (directDiscovery) setFullscreen(active);
  }
  function renderCandidate(item, index) {
    var format = candidateFormat(item);
    var sourceOnly = ${WATERFALL_SOURCE_ONLY_SOURCES_JSON}.indexOf(item.source) >= 0;
    var coverFailure = sourceOnly ? 'this.hidden=true' : 'this.parentElement.hidden=true';
    var cover = item.coverUrl ? '<img class="waterfall-media-cover" src="' + escapeHtml(item.coverUrl) + '" alt="' + escapeHtml(item.title) +
      '" loading="lazy" decoding="async" referrerpolicy="no-referrer" onerror="' + coverFailure + '" />' : '';
    var rawSummary = cleanSummary(item.summary);
    var summary = rawSummary || cleanSummary(item.reason);
    var reasonText = rawSummary && cleanSummary(item.reason) !== rawSummary ? cleanSummary(item.reason) : '';
    var link = item.url ? '<a class="waterfall-source-action" href="' + escapeHtml(item.url) +
      '" rel="noopener noreferrer" aria-label="查看来源">' + uiIcon('external') + '</a>' : '';
    var title = text(item.title).trim() || sourceLabel(item.source) + ' 内容';
    var cardClass = cardClassName(item);
    var meta = '<div class="waterfall-cinema-meta">' + sourceLogoMarkup(item.source) + '<span>' +
      escapeHtml(sourceLabel(item.source)) + '</span></div>';
    var twitchEmbedUrl = item.source === 'twitch' ? twitchEmbedForUrl(text(item.url)) : '';
    var inlinePlay = twitchEmbedUrl ? '<button type="button" class="waterfall-inline-play" data-waterfall-inline-play="' +
      escapeHtml(item.id) + '" aria-label="播放 Twitch 直播">播放</button>' : '';
    var applePlayable = item.source === 'applepodcasts' && text(item.feedUrl).trim().length > 0;
    var appleLoading = item.audioLoadState === 'loading';
    var appleRetryable = item.audioRetryable !== false;
    var applePlay = applePlayable && !(item.audioLoadState === 'error' && !appleRetryable) ?
      '<button type="button" class="waterfall-inline-play" data-waterfall-apple-play="' +
      escapeHtml(item.id) + '" aria-label="播放 Apple Podcasts"' + (appleLoading ? ' disabled' : '') + '>' +
      (appleLoading ? '加载中' : (item.audioLoadState === 'error' ? '重试' :
        (item.audioLoadState === 'ready' ? '播放' : '加载节目'))) + '</button>' : '';
    var appleError = applePlayable && item.audioLoadState === 'error' && text(item.audioError).trim() ?
      '<span class="waterfall-inline-error">' + escapeHtml(item.audioError) + '</span>' : '';
    var inlineControls = inlinePlay + applePlay + appleError;
    var stage = item.mediaType === 'video' ? videoStageMarkup(item, title,
      'waterfall-cinema-stage', 'waterfall-media-cover') :
      ((cover || inlineControls) ? '<div class="waterfall-cinema-stage">' + cover + inlineControls + '</div>' : '');
    var reason = reasonText ? '<span class="waterfall-recommendation" aria-label="推荐理由" data-waterfall-reason>' +
      escapeHtml(reasonText) + '</span>' : '<span></span>';
    var openAttributes = sourceOnly ? '' : ' role="button" tabindex="0" data-waterfall-open="' +
      escapeHtml(item.id) + '"';
    var shellClass = 'waterfall-card-shell' + (sourceOnly ? '' : ' waterfall-card-shell--interactive');
    if (twitchEmbedUrl) cardClass += ' waterfall-card--inline-player waterfall-card--inline-twitch';
    return '<article class="' + cardClass + '" data-waterfall-id="' + escapeHtml(item.id) + '" data-waterfall-media-type="' +
      escapeHtml(item.mediaType) + '"><div class="' + shellClass + '"' + openAttributes + '>' +
      stage + '<div class="waterfall-cinema-copy">' + meta + '<h2>' + escapeHtml(title) + '</h2>' +
      (summary ? '<p>' + escapeHtml(summary) + '</p>' : '') +
      (item.publishedAt ? '<div class="waterfall-meta">' + escapeHtml(publishedLabel(item.publishedAt)) + '</div>' : '') +
      '<div class="waterfall-copy-actions">' + reason + '<div class="waterfall-action-group">' +
      link + '</div></div></div></div></article>';
  }
  function renderPreferences() {
    if (!preferences || !state) return;
    destroyInlinePlayer();
    var sourceNames = directDiscovery ? ${WATERFALL_INTEREST_SOURCE_IDS_JSON} : ${WATERFALL_SEARCH_SOURCE_IDS_JSON};
    if (preferenceApplyTimer !== null) clearTimeout(preferenceApplyTimer);
    preferenceApplyTimer = null;
    preferenceBaseline = enabledSources.join('|');
    if (!preferences.innerHTML) {
      preferences.innerHTML = '<div class="waterfall-toolbar">' +
        '<button type="button" data-waterfall-close-preferences ' +
        'aria-label="返回发现流">' + uiIcon('back') + '</button><b>内容来源</b>' +
        '<button type="button" data-waterfall-apply-preferences>' +
        '完成</button></div>' +
        '<div class="waterfall-source-grid">' + sourceNames.map(function (sourceName) {
          var checked = enabledSources.indexOf(sourceName) >= 0 ? ' checked' : '';
          return '<label>' + sourceLogoMarkup(sourceName) + '<span class="waterfall-source-name">' +
            escapeHtml(sourceLabel(sourceName)) + '</span><input type="checkbox" data-waterfall-source="' +
            escapeHtml(sourceName) + '"' + checked + ' /></label>';
        }).join('') + '</div>';
      preferences.querySelectorAll('[data-waterfall-source]').forEach(function (input) {
        input.addEventListener('change', function () {
          enabledSources = Array.prototype.slice.call(
            preferences.querySelectorAll('[data-waterfall-source]:checked')
          ).map(function (node) { return node.getAttribute('data-waterfall-source'); });
        });
      });
    } else {
      preferences.querySelectorAll('[data-waterfall-source]').forEach(function (input) {
        input.checked = enabledSources.indexOf(input.getAttribute('data-waterfall-source')) >= 0;
      });
    }
    preferences.classList.add('active');
    if (overlay) overlay.classList.add('sheet-open');
    mode = 'source_preferences';
    if (directDiscovery) setFullscreen(true);
  }
  function closePreferences() {
    if (!preferences || mode !== 'source_preferences') return;
    destroyInlinePlayer();
    var changed = preferenceBaseline !== enabledSources.join('|');
    var selectedSources = enabledSources.slice();
    preferences.classList.remove('active');
    mode = 'source_preferences_closing';
    if (preferenceApplyTimer !== null) clearTimeout(preferenceApplyTimer);
    preferenceApplyTimer = setTimeout(function () {
      preferenceApplyTimer = null;
      if (overlay) overlay.classList.remove('sheet-open');
      mode = 'discovering';
      if (directDiscovery) setFullscreen(false);
      var flushed = flushPendingPayload(selectedSources);
      enabledSources = selectedSources;
      if (changed) {
        postSourceSelection();
        if (!flushed) render();
      }
    }, 140);
  }
  function render() {
    if (!track || !state) return false;
    var items = renderedOrderCandidates(state);
    showNewAudioError(items);
    var nextCurrentId = state ? text(state.currentId) : '';
    var nextScrollTop = track.scrollTop;
    var viewportHeight = Math.max(1, track.clientHeight);
    var currentIndex = items.findIndex(function (item) { return text(item.id) === nextCurrentId; });
    var maxScrollTop = typeof track.scrollHeight === 'number' && track.scrollHeight > viewportHeight ?
      track.scrollHeight - viewportHeight : Math.max(0, items.length - 1) * viewportHeight;
    var empty = enabledSources.length === 0 ? '<div class="waterfall-empty"><span>至少开启一个来源</span><button type="button" data-waterfall-empty-sources>打开内容来源</button></div>' : '';
    var status = '';
    if (enabledSources.length > 0 && items.length === 0) {
      status = state.exhausted ? '<div class="waterfall-status waterfall-status--empty"><span>\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f</span>' +
        '<button type="button" data-waterfall-empty-sources>调整内容来源</button></div>' :
        (state.replenishing ? '<div class="waterfall-status">\\u6b63\\u5728\\u8865\\u5145\\u5185\\u5bb9</div>' :
          '<div class="waterfall-status">\\u6b63\\u5728\\u6c47\\u96c6\\u5185\\u5bb9\\u2026</div>');
    }
    var tailStatus = items.length > 0 && state.exhausted ?
      '<div class="waterfall-tail-status"></div>' : '';
    var cardHtml = items.map(renderCandidate);
    var nextHtml = status + empty + cardHtml.join('') + tailStatus;
    var nodes = typeof track.querySelectorAll === 'function' ?
      track.querySelectorAll('[data-waterfall-id]') : [];
    var domChanged = dropRenderedCardsMissingFrom(items, nodes);
    var canPatch = items.length >= renderedCards.length && renderedCards.length > 0 &&
      (domChanged || nodes.length === renderedCards.length);
    for (var i = 0; canPatch && i < renderedCards.length; i++) {
      if (text(items[i].id) !== renderedCards[i].id) canPatch = false;
    }
    if (canPatch) {
      for (var j = 0; j < items.length; j++) {
        if (j < renderedCards.length) {
          if (items[j].source === 'applepodcasts' && renderedCards[j].html !== cardHtml[j]) {
            if (activeInlineCard === nodes[j] || text(items[j].id) === activeInlineCandidateId) {
              destroyInlinePlayer(false);
            }
            nodes[j].outerHTML = cardHtml[j];
            renderedCards[j].html = cardHtml[j];
          }
        } else {
          var tail = track.querySelector('.waterfall-tail-status');
          if (tail) tail.insertAdjacentHTML('beforebegin', cardHtml[j]);
          else track.insertAdjacentHTML('beforeend', cardHtml[j]);
          renderedCards.push({ id: text(items[j].id), html: cardHtml[j] });
          domChanged = true;
        }
      }
    } else if (track.innerHTML !== nextHtml) {
      var keepInlineCandidate = activeInlineCandidateId && items.some(function (item) {
        return text(item.id) === activeInlineCandidateId;
      });
      destroyInlinePlayer(keepInlineCandidate ? false : true);
      track.innerHTML = nextHtml;
      domChanged = true;
      renderedCards = items.map(function (item, index) {
        return { id: text(item.id), html: cardHtml[index] };
      });
      if (!renderedCurrentId && nextCurrentId) {
        track.scrollTop = scrollTopForCard(Math.max(0, currentIndex));
      } else {
        track.scrollTop = Math.min(nextScrollTop, maxScrollTop);
      }
    }
    if (alignToCurrent || alignToCandidateId) {
      var alignId = alignToCandidateId || nextCurrentId;
      var alignIndex = items.findIndex(function (item) { return text(item.id) === alignId; });
      track.scrollTop = scrollTopForCard(alignIndex >= 0 ? alignIndex : Math.max(0, items.length - 1));
      alignToCurrent = false;
      alignToCandidateId = '';
    }
    renderedCurrentId = nextCurrentId;
    var tailNode = typeof track.querySelector === 'function' ? track.querySelector('.waterfall-tail-status') : null;
    if (tailNode) {
      tailNode.textContent = '\\u672c\\u8f6e\\u5185\\u5bb9\\u5df2\\u7ed3\\u675f';
    }
    var sourceControl = document.querySelector('.waterfall-source-control-logos');
    if (sourceControl) {
      var sourceLogoHtml = items.length > 0 ? sourceLogoMarkup(items[0].source) : '';
      if (sourceControl.innerHTML !== sourceLogoHtml) sourceControl.innerHTML = sourceLogoHtml;
    }
    if (domChanged) syncCardsAfterPaint();
    else updateCardPresentation(false);
    syncActiveInlinePlayer();
    return domChanged;
  }
  function dropRenderedCardsMissingFrom(items, nodes) {
    if (renderedCards.length === 0 || nodes.length !== renderedCards.length) return false;
    var present = {};
    for (var index = 0; index < items.length; index += 1) present['$' + text(items[index].id)] = true;
    var kept = [];
    var removed = false;
    for (var rendered = 0; rendered < renderedCards.length; rendered += 1) {
      if (present['$' + renderedCards[rendered].id]) {
        kept.push(renderedCards[rendered]);
        continue;
      }
      var node = nodes[rendered];
      if (renderedCards[rendered].id === activeInlineCandidateId) destroyInlinePlayer();
      if (node && node.parentNode && typeof node.parentNode.removeChild === 'function') {
        node.parentNode.removeChild(node);
      }
      removed = true;
    }
    if (!removed) return false;
    renderedCards = kept;
    return true;
  }
  function realignDiscoveryAfterReveal() {
    var realign = function () {
      alignToCurrent = true;
      cardMetrics = [];
      presentedIndex = -1;
      render();
    };
    if (typeof window.requestAnimationFrame === 'function') window.requestAnimationFrame(realign);
    else realign();
  }
  function settleInteraction() {
    if (payloadSettleTimer !== null) clearTimeout(payloadSettleTimer);
    payloadSettleTimer = setTimeout(function () {
      payloadSettleTimer = null;
      scrollActive = false;
      if (!interactionActive) pageAnchorIndex = -1;
      if (!interactionActive && mode !== 'reading' && mode !== 'reader_closing' &&
        mode !== 'source_preferences' && mode !== 'source_preferences_closing') flushPendingPayload();
    }, 96);
  }
  document.addEventListener('touchstart', function () {
    ignoreNextFeedOpen = false;
    if (payloadSettleTimer !== null) clearTimeout(payloadSettleTimer);
    payloadSettleTimer = null;
    interactionActive = true;
    beginPagingGesture();
  }, { passive: true });
  document.addEventListener('touchend', function () {
    interactionActive = false;
    snapPagingCard();
    if (scrollActive || pendingPayload || pageAnchorIndex >= 0) settleInteraction();
  }, { passive: true });
  document.addEventListener('touchcancel', function () {
    interactionActive = false;
    snapPagingCard();
    if (scrollActive || pendingPayload || pageAnchorIndex >= 0) settleInteraction();
  }, { passive: true });
  track.addEventListener('scroll', function () {
    if (pagingClamp) return;
    if (mode !== 'discovering') return;
    if (cardMetrics.length === 0) refreshCardMetrics();
    clampPagingScroll();
    scrollActive = true;
    settleInteraction();
    if (presentationFrame !== null) return;
    if (typeof window.requestAnimationFrame === 'function') {
      presentationFrame = window.requestAnimationFrame(function () {
        presentationFrame = null;
        if (metricsDirty) refreshMetricsAfterSettle();
        scheduleAdvance(updateCardPresentation());
      });
      return;
    }
    if (metricsDirty) refreshMetricsAfterSettle();
    scheduleAdvance(updateCardPresentation());
  });
  track.addEventListener('error', function (event) {
    var image = event.target;
    if (!image || !image.classList || !image.classList.contains('waterfall-media-cover') ||
      typeof image.closest !== 'function') return;
    var stage = image.closest('.waterfall-cinema-stage');
    if (stage) stage.hidden = true;
    refreshMetricsAfterSettle();
  }, true);
  track.addEventListener('ended', function (event) {
    var media = event.target;
    if (!media || text(media.tagName).toLowerCase() !== 'video' || typeof media.closest !== 'function') return;
    var card = media.closest('[data-waterfall-id]');
    if (!card || typeof card.getAttribute !== 'function') return;
    postBehavior(card.getAttribute('data-waterfall-id'), 'play_complete',
      typeof media.duration === 'number' && isFinite(media.duration) ? media.duration * 1000 : 0);
  }, true);
  bindFastTap(track, function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function') return false;
    var applePlay = target.closest('[data-waterfall-apple-play]');
    if (applePlay) {
      activateApplePodcast(applePlay);
      return true;
    }
    var inlinePlay = target.closest('[data-waterfall-inline-play]');
    if (inlinePlay) {
      activateTwitchPlayer(inlinePlay);
      return true;
    }
    var source = target.closest('.waterfall-source-action');
    if (source) {
      destroyInlinePlayer();
      openSource(source, event);
      return true;
    }
    var play = target.closest('[data-waterfall-video-play]');
    if (play) {
      playVideo(play);
      return true;
    }
    var fullscreen = target.closest('[data-waterfall-video-fullscreen]');
    if (fullscreen) {
      var videoCard = fullscreen.closest('.waterfall-card--video');
      toggleVideoFullscreen(videoCard);
      return true;
    }
    if (target.closest('.waterfall-media-frame')) return false;
    var open = target.closest('[data-waterfall-open]');
    if (open) {
      if (ignoreNextFeedOpen) {
        ignoreNextFeedOpen = false;
        return true;
      }
      var item = candidateById(open.getAttribute('data-waterfall-open'));
      if (!item) return false;
      openReader(item.id);
      return true;
    }
    if (target.closest('[data-waterfall-empty-sources]')) {
      renderPreferences();
      return true;
    }
    return false;
  });
  track.addEventListener('keydown', function (event) {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    var target = event.target;
    if (!target || typeof target.closest !== 'function' ||
      target.closest('.waterfall-source-action') || target.closest('.waterfall-media-frame') ||
      target.closest('[data-waterfall-video-fullscreen]')) return;
    var open = target.closest('[data-waterfall-open]');
    if (!open) return;
    if (typeof event.preventDefault === 'function') event.preventDefault();
    var item = candidateById(open.getAttribute('data-waterfall-open'));
    if (!item) return;
    openReader(item.id);
  });
  if (reader) {
    bindFastTap(reader, function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== 'function') return false;
      if (target.closest('[data-waterfall-reader-close]')) {
        closeReader();
        return true;
      }
      var source = target.closest('.waterfall-source-action');
      if (source && openSource(source, event)) return true;
      var play = target.closest('[data-waterfall-video-play]');
      if (play) {
        playVideo(play);
        return true;
      }
      if (!target.closest('.waterfall-reader-layout')) {
        closeReader();
        return true;
      }
      return false;
    });
  }
  if (preferences) {
    bindFastTap(preferences, function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== 'function' ||
        !target.closest('[data-waterfall-close-preferences], [data-waterfall-apply-preferences]')) return false;
      closePreferences();
      return true;
    });
  }
  bindFastTap(document, function (event) {
    var target = event.target;
    if (!target || typeof target.closest !== 'function' || !target.closest('[data-waterfall-enter]')) return false;
    if (closeTimer !== null) clearTimeout(closeTimer);
    closeTimer = null;
    mode = 'discovering';
    overlay.classList.remove('closing');
    overlay.classList.add('active');
    setSearchShellHidden(true);
    setFullscreen(true);
    render();
    realignDiscoveryAfterReveal();
    resumeCurrentBehavior();
    return true;
  });
  document.querySelectorAll('[data-waterfall-back]').forEach(function (button) {
    bindFastTap(button, function () {
      window.__aiphoneHandleWaterfallBack();
      return true;
    });
  });
  document.querySelectorAll('[data-waterfall-preferences]').forEach(function (button) {
    bindFastTap(button, function () {
      renderPreferences();
      return true;
    });
  });
  function closeDiscovery() {
    destroyInlinePlayer();
    if (directDiscovery && state && window.AIPhoneHome &&
      typeof window.AIPhoneHome.postAction === 'function') {
      pauseCurrentBehavior(false);
      setFullscreen(false);
      window.AIPhoneHome.postAction(JSON.stringify({
        id: 'waterfall.home.back', label: '返回首页', prompt: '', variant: 'secondary', kind: 'client',
        args: { surfaceId: state.surfaceId || '' }
      }));
      return;
    }
    mode = 'entry';
    pauseCurrentBehavior(false);
    if (preferences) preferences.classList.remove('active');
    if (overlay) {
      overlay.classList.remove('reading');
      overlay.classList.remove('sheet-open');
    }
    if (closeTimer !== null) clearTimeout(closeTimer);
    overlay.classList.add('closing');
    closeTimer = setTimeout(function () {
      overlay.classList.remove('active');
      overlay.classList.remove('closing');
      setSearchShellHidden(false);
      applyDeferredAggregateHtml();
      closeTimer = null;
    }, 140);
    setFullscreen(false);
  }
  window.__aiphoneHandleWaterfallBack = function () {
    if (mode === 'reader_closing') return true;
    if (mode === 'source_preferences_closing') return true;
    if (mode === 'reading') {
      closeReader();
      return true;
    }
    if (fullscreenVideoCard) {
      toggleVideoFullscreen(fullscreenVideoCard);
      return true;
    }
    if (mode === 'source_preferences') {
      closePreferences();
      return true;
    }
    if (mode === 'discovering') {
      closeDiscovery();
      return true;
    }
    return false;
  };
  document.addEventListener('keydown', function (event) {
    if (event.key !== 'Escape') return;
    window.__aiphoneHandleWaterfallBack();
  });
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      destroyInlinePlayer();
      pauseCurrentBehavior(false);
      if (readerCandidateId && readerStartedAt > 0) {
        readerDurationMs += Math.max(0, Date.now() - readerStartedAt);
        readerStartedAt = 0;
      }
      return;
    }
    if (mode === 'reading' && readerCandidateId) readerStartedAt = Date.now();
    else resumeCurrentBehavior();
  });
  if (state) {
    mergePayload(state);
    if (directDiscovery && overlay) {
      overlay.classList.add('active');
      setSearchShellHidden(true);
      render();
      realignDiscoveryAfterReveal();
      resumeCurrentBehavior();
    }
  }
})();
`;

export function shouldRenderAggregateSearchHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'aggregate-search';
}

type WaterfallActionValue = Object | string | number | boolean | null | undefined;

function waterfallArgsFromAction(
  action: A2uiAction,
  actionId: string,
  surfaceId: string
): Record<string, WaterfallActionValue> | null {
  if (action.id !== actionId || action.kind !== 'client' || action.args === undefined) {
    return null;
  }
  const args = action.args as Record<string, WaterfallActionValue>;
  if (typeof args['surfaceId'] !== 'string' || args['surfaceId'] !== surfaceId) {
    return null;
  }
  return args;
}

export function waterfallEnabledSourcesFromAction(action: A2uiAction, surfaceId: string): string[] | null {
  const args = waterfallArgsFromAction(action, 'waterfall.sources.select', surfaceId);
  if (args === null || !Array.isArray(args['enabledSources'])) {
    return null;
  }
  const rawSources = args['enabledSources'] as WaterfallActionValue[];
  const enabledSources: string[] = [];
  for (let index = 0; index < rawSources.length; index += 1) {
    if (typeof rawSources[index] !== 'string') {
      return null;
    }
    const source = (rawSources[index] as string).trim();
    if (source.length === 0) {
      return null;
    }
    if (enabledSources.indexOf(source) < 0) {
      enabledSources.push(source);
    }
  }
  return enabledSources;
}

export function waterfallAdvanceCurrentFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.feed.advance', surfaceId);
  if (args === null || typeof args['currentId'] !== 'string') {
    return null;
  }
  const currentId = (args['currentId'] as string).trim();
  return currentId.length > 0 ? currentId : null;
}

export function waterfallApplePodcastCandidateFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.applepodcasts.resolve', surfaceId);
  if (args === null || Object.keys(args).sort().join(',') !== 'candidateId,surfaceId' ||
    typeof args['candidateId'] !== 'string') {
    return null;
  }
  const candidateId = (args['candidateId'] as string).trim();
  return candidateId.length > 0 ? candidateId : null;
}

export function waterfallBehaviorFromAction(
  action: A2uiAction,
  surfaceId: string
): WaterfallBehaviorActionArgs | null {
  const args = waterfallArgsFromAction(action, 'waterfall.behavior.record', surfaceId);
  if (args === null || typeof args['candidateId'] !== 'string' ||
    (args['candidateId'] as string).trim().length === 0 || !Array.isArray(args['topics']) ||
    typeof args['source'] !== 'string' || (args['source'] as string).trim().length === 0 ||
    typeof args['format'] !== 'string' ||
    (args['format'] !== 'landscape_video' && args['format'] !== 'portrait_video' &&
      args['format'] !== 'image_text' && args['format'] !== 'text') ||
    typeof args['behavior'] !== 'string' ||
    (args['behavior'] !== 'play_complete' && args['behavior'] !== 'read_complete' &&
      args['behavior'] !== 'dwell' && args['behavior'] !== 'quick_skip') ||
    typeof args['durationMs'] !== 'number' || !isFinite(args['durationMs'] as number) ||
    (args['durationMs'] as number) < 0 || typeof args['timestamp'] !== 'number' ||
    !isFinite(args['timestamp'] as number) || (args['timestamp'] as number) <= 0) {
    return null;
  }
  const rawTopics = args['topics'] as WaterfallActionValue[];
  const topics: string[] = [];
  for (let index = 0; index < rawTopics.length; index += 1) {
    if (typeof rawTopics[index] !== 'string' || (rawTopics[index] as string).trim().length === 0) return null;
    const topic = (rawTopics[index] as string).trim();
    if (topics.indexOf(topic) < 0) topics.push(topic);
  }
  return {
    surfaceId,
    candidateId: (args['candidateId'] as string).trim(),
    topics,
    source: (args['source'] as string).trim(),
    format: args['format'] as 'landscape_video' | 'portrait_video' | 'image_text' | 'text',
    behavior: args['behavior'] as 'play_complete' | 'read_complete' | 'dwell' | 'quick_skip',
    durationMs: args['durationMs'] as number,
    timestamp: args['timestamp'] as number
  };
}

export function buildWaterfallHomePayload(
  document: HtmlHomeDocument,
  isBusy: boolean,
  waterfallState: WaterfallFeedState | null = null
): WaterfallHomePayload | null {
  const state = waterfallState ?? document.waterfall;
  if (state === undefined) {
    return null;
  }
  const candidates: WaterfallRankedCandidate[] = [];
  const seen: string[] = [];
  const append = (candidate: WaterfallRankedCandidate | null): void => {
    if (candidate === null || seen.indexOf(candidate.id) >= 0 || seen.indexOf(candidate.normalizedUrl) >= 0) {
      return;
    }
    seen.push(candidate.id);
    if (candidate.normalizedUrl.length > 0) {
      seen.push(candidate.normalizedUrl);
    }
    candidates.push(candidate);
  };
  state.shown.forEach(append);
  append(state.current);
  state.stable.forEach(append);
  state.tail.forEach(append);
  const remainingCandidates: WaterfallRankedCandidate[] = [];
  if (state.current !== null) {
    remainingCandidates.push(state.current);
  }
  state.stable.forEach((candidate: WaterfallRankedCandidate): void => {
    remainingCandidates.push(candidate);
  });
  state.tail.forEach((candidate: WaterfallRankedCandidate): void => {
    remainingCandidates.push(candidate);
  });
  const activeCandidates = remainingCandidates.filter((candidate: WaterfallRankedCandidate): boolean =>
    state.enabledSources.indexOf(candidate.source) >= 0);
  const relevantSources = state.sources.filter((source: WaterfallSourceState): boolean =>
    state.enabledSources.indexOf(source.source) >= 0);
  const replenishing = relevantSources.some((source: WaterfallSourceState): boolean =>
    source.inFlight || source.phase === 'loading') || state.expansionInFlight === true;
  const exhausted = (state.queryStage ?? 'done') === 'done' && activeCandidates.length === 0 && state.enabledSources.length > 0 &&
    relevantSources.length === state.enabledSources.length && relevantSources.every((source: WaterfallSourceState): boolean =>
    source.continuation === null && (source.phase === 'empty' || source.phase === 'needs_auth' ||
    source.phase === 'error' || source.phase === 'exhausted' || source.phase === 'success'));
  return {
    surfaceId: document.surfaceId ?? '',
    query: state.query,
    currentId: state.current === null ? '' : state.current.id,
    aggregateHtml: renderAggregateMainContent(document, isBusy, candidates.length > 0),
    candidates: candidates,
    mediaEmbeds: waterfallMediaEmbeds(document),
    enabledSources: state.enabledSources.slice(),
    sources: state.sources,
    replenishing: replenishing,
    exhausted: exhausted
  };
}

function waterfallMediaEmbeds(document: HtmlHomeDocument): Record<string, string> {
  const embeds: Record<string, string> = {};
  document.blocks.forEach((block: HtmlHomeBlock): void => {
    if (block.mediaEmbed === undefined || block.mediaEmbed === null ||
      block.mediaEmbed.pageUrl.length === 0 || block.mediaEmbed.embedUrl.length === 0) {
      return;
    }
    embeds[block.mediaEmbed.pageUrl] = block.mediaEmbed.embedUrl;
  });
  return embeds;
}

function renderAggregateMainContent(
  document: HtmlHomeDocument,
  isBusy: boolean,
  entryAvailable: boolean
): string {
  const videos = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-video');
  const posts = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-post');
  const statuses = document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'aggregate-source-status');
  return [
    '<header class="aggregate-hero">',
    '<div class="aggregate-kicker">多源搜索</div>',
    '<h1>', escapeHtml(document.title), '</h1>',
    renderKeywordBadge(document.subtitle),
    '<p>视频和讨论一起看', isBusy ? ' · 正在更新' : '', '</p>',
    '</header>',
    statuses.length > 0 ? '<section class="aggregate-section aggregate-source-overview"><div class="aggregate-section-head"><h2>来源</h2><div class="aggregate-meta">状态摘要</div></div><div class="aggregate-status-list">' + statuses.map(renderAggregateBlock).join('') + '</div></section>' : '',
    '<div class="waterfall-entry waterfall-entry-floating">', entryAvailable ? '<button type="button" class="waterfall-entry-action" aria-label="进入发现流" data-waterfall-enter>进入发现流</button>' : '', '</div>',
    renderFilterRail(),
    '<div id="aggregate-filter-empty" hidden>没有匹配结果</div>',
    '<div class="aggregate-grid">',
    '<section class="aggregate-section" data-filter-section="video">',
    '<div class="aggregate-section-head"><h2>视频</h2><div class="aggregate-meta">', escapeHtml(videos.length.toString()), ' 条</div></div>',
    '<div class="aggregate-video-rail">', videos.map(renderAggregateBlock).join(''), '</div>',
    '</section>',
    '<section class="aggregate-section" data-filter-section="article">',
    '<div class="aggregate-section-head"><h2>讨论</h2><div class="aggregate-meta">', escapeHtml(posts.length.toString()), ' 条</div></div>',
    '<div class="aggregate-post-list">', posts.map(renderAggregateBlock).join(''), '</div>',
    '</section>',
    '</div>'
  ].join('');
}

function waterfallUiIconMarkup(name: string): string {
  let paths = '';
  if (name === 'back') {
    paths = '<path d="m15 18-6-6 6-6" />';
  } else if (name === 'external') {
    paths = '<path d="M14 5h5v5" /><path d="M10 14 19 5" />' +
      '<path d="M19 13v5a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1h5" />';
  } else if (name === 'expand') {
    paths = '<path d="M8 3H3v5M16 3h5v5M8 21H3v-5M16 21h5v-5" />';
  } else if (name === 'play') {
    paths = '<path d="m9 7 8 5-8 5Z" />';
  } else if (name === 'sources') {
    paths = '<path d="M4 7h5M13 7h7M4 17h9M17 17h3" />' +
      '<circle cx="11" cy="7" r="2" /><circle cx="15" cy="17" r="2" />';
  }
  return '<span class="waterfall-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false">' +
    paths + '</svg></span>';
}

export function renderAggregateSearchHomeDocument(
  document: HtmlHomeDocument,
  isBusy: boolean = false,
  startInDiscovery: boolean = false
): string {
  const waterfall = buildWaterfallHomePayload(document, isBusy);
  const waterfallJson = waterfall === null ? 'null' : JSON.stringify(waterfall).replace(/</g, '\\u003c');
  const sourceLogosJson = JSON.stringify({
    youtube: APP_LOGO_YOUTUBE,
    bilibili: APP_LOGO_BILIBILI,
    x: APP_LOGO_X,
    hackernews: APP_LOGO_HACKERNEWS,
    reddit: APP_LOGO_REDDIT,
    zhihu: APP_LOGO_ZHIHU,
    applepodcasts: APP_LOGO_APPLE_PODCASTS,
    twitch: APP_LOGO_TWITCH
  }).replace(/</g, '\\u003c');
  const uiIconsJson = JSON.stringify({
    back: waterfallUiIconMarkup('back'),
    external: waterfallUiIconMarkup('external'),
    expand: waterfallUiIconMarkup('expand'),
    play: waterfallUiIconMarkup('play'),
    sources: waterfallUiIconMarkup('sources')
  }).replace(/</g, '\\u003c');
  const waterfallStatus = waterfall !== null && waterfall.replenishing ? '<div class="waterfall-status">正在补充内容</div>' :
    (waterfall !== null && waterfall.exhausted ? '<div class="waterfall-status">本轮内容已结束</div>' : '');
  return [
    '<!doctype html>',
    '<html lang="zh-CN"><head><meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />',
    '<title>', escapeHtml(document.title), '</title>',
    '<style>', AGGREGATE_CSS, WATERFALL_CSS, '</style></head><body>',
    '<main class="aggregate-shell">',
    waterfall === null ? renderAggregateMainContent(document, isBusy, false) : waterfall.aggregateHtml,
    '</main>', waterfall !== null ? '<section id="waterfall-discovery" class="waterfall-overlay' +
      (startInDiscovery ? ' active' : '') + '">' +
      '<div id="waterfall-toolbar" class="waterfall-toolbar">' +
      '<button type="button" class="waterfall-toolbar-primary" aria-label="' +
      (startInDiscovery ? '返回首页' : '返回聚合搜索') + '" data-waterfall-back>' +
      waterfallUiIconMarkup('back') +
      '<span class="waterfall-toolbar-label">返回</span></button>' +
      '<span class="waterfall-toolbar-title">发现</span>' +
      '<div class="waterfall-toolbar-tools">' +
      '<button type="button" class="waterfall-toolbar-secondary" ' +
      'aria-label="内容来源" data-waterfall-preferences>' + waterfallUiIconMarkup('sources') +
      '<span class="waterfall-toolbar-label">设置</span></button></div></div>' +
      '<div id="waterfall-track" class="waterfall-track">' + waterfallStatus + '</div>' +
      '<div id="waterfall-preferences" class="waterfall-preferences"></div>' +
      '<div id="waterfall-reader" class="waterfall-reader"></div>' +
      '<div id="waterfall-toast" class="waterfall-toast" role="status" aria-live="polite"></div></section>' : '',
    '<script>', AGGREGATE_JS, waterfall !== null ? 'window.__aiphoneWaterfallDirect=' +
      (startInDiscovery ? 'true' : 'false') + ';window.__aiphoneWaterfallSourceLogos=' + sourceLogosJson +
      ';window.__aiphoneWaterfallUiIcons=' + uiIconsJson +
      ';window.__aiphoneWaterfallInitial=' + waterfallJson + ';' + WATERFALL_JS : '', '</script></body></html>'
  ].join('');
}

function renderKeywordBadge(value: string): string {
  const keyword = compactSubtitle(value);
  if (keyword.length === 0) {
    return '';
  }
  return '<div class="aggregate-keyword"><span>关键词</span><b>' + escapeHtml(keyword) + '</b></div>';
}

function renderAggregateBlock(block: HtmlHomeBlock): string {
  if (block.kind === 'aggregate-source-status') {
    return renderStatusBlock(block);
  }
  if (block.kind === 'aggregate-post') {
    return renderPostBlock(block);
  }
  return [
    '<article class="aggregate-card aggregate-result-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(text(block.source))), '" data-status="', escapeAttribute(text(block.status)), '">',
    renderCardTop(block),
    '<h3>', escapeHtml(block.title), '</h3>',
    text(block.subtitle).length > 0 ? '<p>' + escapeHtml(text(block.subtitle)) + '</p>' : '',
    renderEmbed(block),
    renderRows(block),
    '</article>'
  ].join('');
}

function renderPostBlock(block: HtmlHomeBlock): string {
  const body = postBodyText(block);
  const media = renderPostMedia(block);
  const link = renderPostLink(block);
  const meta = renderPostMeta(block);
  const title = /^result\s+\d+$/i.test(block.title.trim()) ? '' : block.title;
  return [
    '<details class="aggregate-card aggregate-result-card aggregate-post-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(text(block.source))), '" data-status="', escapeAttribute(text(block.status)), '">',
    '<summary>',
    renderCardTop(block),
    '<div class="aggregate-post-title-row">', title.length > 0 ? '<h3>' + escapeHtml(title) + '</h3>' : '', '<span class="aggregate-expand-cue"></span></div>',
    body.length > 0 ? '<p class="aggregate-summary-snippet">' + escapeHtml(body) + '</p>' : '',
    '</summary>',
    '<div class="aggregate-post-expanded">',
    media,
    body.length > 0 ? '<p class="aggregate-expanded-text">' + escapeHtml(body) + '</p>' : '',
    link,
    meta,
    '</div>',
    '</details>'
  ].join('');
}

function renderStatusBlock(block: HtmlHomeBlock): string {
  const source = text(block.source);
  const sourceName = aggregateSourceLabel(source, text(block.title).length > 0 ? text(block.title) : '来源');
  const phase = aggregateStatusLabel(text(block.status));
  const fullMessage = text(block.subtitle);
  const compactMessage = compactStatusMessage(fullMessage);
  const count = rowValue(block, ['count']);
  const countLabel = count.length > 0 ? '已返回 ' + count + ' 条' : '返回数量暂不可用';
  const statusLabel = '来源状态：' + sourceName;
  const debugRows = renderRows(block);
  return [
    '<details class="aggregate-card aggregate-status-card" data-kind="', escapeHtml(block.kind), '" data-source="', escapeAttribute(sourceCssValue(source)), '" data-status="', escapeAttribute(text(block.status)), '">',
    '<summary class="aggregate-status-summary" aria-label="', escapeAttribute(statusLabel + '，' + phase + '，' + countLabel), '" title="', escapeAttribute(statusLabel), '">',
    sourceIconMarkup(source), '<span class="aggregate-status-dot"></span></summary>',
    '<div class="aggregate-status-sheet" role="dialog" aria-label="', escapeAttribute(statusLabel), '">',
    '<div class="aggregate-status-sheet-head"><div><strong>', escapeHtml(statusLabel), '</strong><span>', escapeHtml(phase), ' · ', escapeHtml(countLabel), '</span></div><button type="button" class="aggregate-status-close" data-status-close aria-label="关闭来源状态">关闭</button></div>',
    '<p class="aggregate-status-sheet-summary">', escapeHtml(fullMessage.length > 0 ? compactMessage : '暂无额外诊断信息'), '</p>',
    fullMessage.length > 0 || debugRows.length > 0 ? '<details class="aggregate-status-detail"><summary>查看详情</summary>' +
      (fullMessage.length > 0 ? '<p class="aggregate-status-detail-copy" aria-label="' + escapeAttribute(fullMessage) +
      '" title="' + escapeAttribute(fullMessage) + '" data-status-detail="' + escapeAttribute(fullMessage) + '">' +
      escapeHtml(fullMessage) + '</p>' : '') + debugRows + '</details>' :
      '<p class="aggregate-status-detail-copy">详细信息暂不可用</p>',
    '</div>',
    '</details>'
  ].join('');
}

function aggregateStatusLabel(status: string): string {
  if (status === 'loading') {
    return '加载中';
  }
  if (status === 'success' || status === 'ready') {
    return '已完成';
  }
  if (status === 'partial') {
    return '部分返回';
  }
  if (status === 'error') {
    return '部分失败';
  }
  if (status === 'needs_auth') {
    return '需授权';
  }
  if (status === 'empty') {
    return '无结果';
  }
  if (status === 'unsupported') {
    return '暂不支持';
  }
  if (status === 'exhausted') {
    return '本轮结束';
  }
  return status.length > 0 ? status : '状态暂不可用';
}

function compactStatusMessage(value: string): string {
  const clean = value.replace(/\s+/g, ' ').trim();
  if (clean.length <= 120) {
    return clean;
  }
  const boundary = clean.search(/[。！？.!?]/);
  if (boundary >= 0 && boundary < 120) {
    return clean.slice(0, boundary + 1);
  }
  return clean.slice(0, 116).replace(/\s+$/, '') + '…';
}

function renderCardTop(block: HtmlHomeBlock): string {
  return '<div class="aggregate-card-top">' + sourceIconMarkup(text(block.source)) +
    '<div class="aggregate-tag">' + escapeHtml(blockTitle(block)) + '</div></div>';
}

function renderFilterRail(): string {
  return '<nav class="aggregate-filter-rail" aria-label="聚合筛选">' + [
    renderFilterButton('all', '全部', '', true),
    renderFilterButton('video', '视频', '', false),
    renderFilterButton('article', '文章', '', false),
    renderFilterButton('youtube', 'YouTube', 'youtube', false),
    renderFilterButton('bilibili', 'B 站', 'bilibili', false),
    renderFilterButton('x', 'X', 'x', false),
    renderFilterButton('hackernews', 'HN', 'hackernews', false),
    renderFilterButton('reddit', 'Reddit', 'reddit', false),
    renderFilterButton('zhihu', '知乎', 'zhihu', false)
  ].join('') + '</nav>';
}

function renderFilterButton(value: string, label: string, source: string, active: boolean): string {
  return '<button type="button" class="aggregate-filter' + (active ? ' active' : '') +
    '" data-filter="' + escapeAttribute(value) + '">' +
    (source.length > 0 ? sourceIconMarkup(source) : '') +
    '<span>' + escapeHtml(label) + '</span></button>';
}

function renderEmbed(block: HtmlHomeBlock): string {
  if (block.mediaEmbed === undefined || block.mediaEmbed === null || text(block.mediaEmbed.embedUrl).length === 0) {
    return '';
  }
  return '<iframe class="aggregate-embed" src="' + escapeAttribute(block.mediaEmbed.embedUrl) +
    '" title="' + escapeAttribute(block.mediaEmbed.title) +
    '" loading="lazy" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>';
}

function postBodyText(block: HtmlHomeBlock): string {
  const subtitle = text(block.subtitle);
  if (subtitle.length > 0) {
    return subtitle;
  }
  return rowValue(block, ['text', 'content', 'body']);
}

function renderPostMedia(block: HtmlHomeBlock): string {
  const urls = postMediaUrls(block);
  if (urls.length === 0) {
    return '';
  }
  return '<div class="aggregate-post-media-grid">' + urls.map((url: string) => {
    return '<img class="aggregate-post-media" src="' + escapeAttribute(url) + '" alt="帖子图片" loading="lazy" />';
  }).join('') + '</div>';
}

function renderPostLink(block: HtmlHomeBlock): string {
  const url = postLinkUrl(block);
  if (url.length === 0) {
    return '';
  }
  return '<a class="aggregate-link-preview" href="' + escapeAttribute(url) +
    '" target="_blank" rel="noopener noreferrer"><span class="aggregate-link-host">' +
    escapeHtml(hostLabel(url)) + '</span><b>打开原文</b></a>';
}

function renderPostMeta(block: HtmlHomeBlock): string {
  const chips: string[] = [];
  appendPostMeta(chips, '作者', rowValue(block, ['author']));
  appendPostMeta(chips, '账号', rowValue(block, ['handle']));
  appendPostMeta(chips, '时间', rowValue(block, ['publishedAt', 'time']));
  appendPostMeta(chips, '热度', rowValue(block, ['score']));
  appendPostMeta(chips, '评论', rowValue(block, ['commentCount', 'comments']));
  if (chips.length === 0) {
    return '';
  }
  return '<div class="aggregate-post-metadata">' + chips.join('') + '</div>';
}

function appendPostMeta(chips: string[], label: string, value: string): void {
  if (value.length === 0) {
    return;
  }
  chips.push('<span><b>' + escapeHtml(label) + '</b>' + escapeHtml(value) + '</span>');
}

function renderRows(block: HtmlHomeBlock): string {
  const rows = block.metrics.concat(block.rows).slice(0, 6);
  if (rows.length === 0) {
    return '';
  }
  return '<div class="aggregate-rows">' + rows.map(renderRow).join('') + '</div>';
}

function renderRow(row: HtmlHomeMetric): string {
  return '<div class="aggregate-row"><b>' + escapeHtml(row.label) + '</b><span>' + escapeHtml(row.value) + '</span></div>';
}

function blockTitle(block: HtmlHomeBlock): string {
  if (block.kind === 'aggregate-video') {
    return '视频';
  }
  if (block.kind === 'aggregate-post') {
    return aggregateSourceLabel(text(block.source), '讨论');
  }
  return '来源状态';
}

function sourceIconMarkup(source: string): string {
  const clean = sourceCssValue(source);
  const logo = sourceLogoUrl(clean);
  if (logo.length === 0) {
    return '';
  }
  return '<span class="aggregate-app-icon" data-source="' + escapeAttribute(clean) + '" aria-label="' +
    escapeAttribute(aggregateSourceLabel(clean, '来源')) + '"><img src="' + escapeAttribute(logo) +
    '" alt="" loading="lazy" /></span>';
}

function sourceLogoUrl(source: string): string {
  if (source === 'youtube') {
    return APP_LOGO_YOUTUBE;
  }
  if (source === 'bilibili') {
    return APP_LOGO_BILIBILI;
  }
  if (source === 'x') {
    return APP_LOGO_X;
  }
  if (source === 'hackernews') {
    return APP_LOGO_HACKERNEWS;
  }
  if (source === 'reddit') {
    return APP_LOGO_REDDIT;
  }
  if (source === 'zhihu') {
    return APP_LOGO_ZHIHU;
  }
  if (source === 'douban') {
    return APP_LOGO_DOUBAN;
  }
  if (source === 'applepodcasts') {
    return APP_LOGO_APPLE_PODCASTS;
  }
  if (source === 'twitch') {
    return APP_LOGO_TWITCH;
  }
  return '';
}

export function shouldShowWaterfallReaderAction(source: AggregateSearchSource, _mediaType: string): boolean {
  return WATERFALL_SOURCE_ONLY_SOURCES.indexOf(source) < 0;
}

function sourceCssValue(source: string): string {
  const clean = source.trim().toLowerCase();
  if (clean === 'youtube' || clean === 'bilibili' || clean === 'x' || clean === 'hackernews' ||
    clean === 'reddit' || clean === 'zhihu' || clean === 'douban' || clean === 'applepodcasts' ||
    clean === 'twitch') {
    return clean;
  }
  return 'unknown';
}

function aggregateSourceLabel(source: string, fallback: string): string {
  if (source === 'youtube') {
    return 'YouTube';
  }
  if (source === 'bilibili') {
    return 'B 站';
  }
  if (source === 'x') {
    return 'X';
  }
  if (source === 'hackernews') {
    return 'HN';
  }
  if (source === 'reddit') {
    return 'Reddit';
  }
  if (source === 'zhihu') {
    return '知乎';
  }
  if (source === 'douban') {
    return '豆瓣';
  }
  if (source === 'applepodcasts') {
    return 'Apple Podcasts';
  }
  if (source === 'twitch') {
    return 'Twitch';
  }
  return fallback;
}

function rowValue(block: HtmlHomeBlock, labels: string[]): string {
  const rows = block.metrics.concat(block.rows);
  for (let index = 0; index < rows.length; index++) {
    const row = rows[index];
    const label = row.label.trim().toLowerCase();
    for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      if (label === labels[labelIndex].trim().toLowerCase()) {
        return text(row.value);
      }
    }
  }
  return '';
}

function postMediaUrls(block: HtmlHomeBlock): string[] {
  const urls: string[] = [];
  block.rows.forEach((row: HtmlHomeMetric) => {
    const label = row.label.trim().toLowerCase();
    if (label !== 'mediaurl' && label !== 'image' && label !== 'images' && label !== 'thumbnail' &&
      label !== 'cover' && label !== 'pic' && label !== 'picture') {
      return;
    }
    extractUrls(row.value).forEach((url: string) => {
      if (urls.indexOf(url) < 0) {
        urls.push(url);
      }
    });
  });
  block.rows.forEach((row: HtmlHomeMetric) => {
    extractUrls(row.value).forEach((url: string) => {
      if (isImageUrl(url) && urls.indexOf(url) < 0) {
        urls.push(url);
      }
    });
  });
  return urls;
}

function postLinkUrl(block: HtmlHomeBlock): string {
  const explicitUrl = rowValue(block, ['url', 'link']);
  if (explicitUrl.length > 0) {
    return explicitUrl;
  }
  const urls = extractUrls(postBodyText(block));
  return urls.length > 0 ? urls[0] : '';
}

function extractUrls(value: string): string[] {
  const matches = text(value).match(/https?:\/\/[^\s,，]+/g);
  if (matches === null) {
    return [];
  }
  return matches.map((url: string) => trimUrl(url));
}

function trimUrl(url: string): string {
  let clean = url;
  while (clean.length > 0) {
    const last = clean.charAt(clean.length - 1);
    if (last !== ')' && last !== ']' && last !== '}' && last !== '"' && last !== '\'' &&
      last !== '。' && last !== '，' && last !== ',' && last !== '.') {
      break;
    }
    clean = clean.substring(0, clean.length - 1);
  }
  return clean;
}

function isImageUrl(url: string): boolean {
  const lower = url.toLowerCase();
  return lower.indexOf('.jpg') >= 0 ||
    lower.indexOf('.jpeg') >= 0 ||
    lower.indexOf('.png') >= 0 ||
    lower.indexOf('.webp') >= 0 ||
    lower.indexOf('.gif') >= 0 ||
    lower.indexOf('image') >= 0 ||
    lower.indexOf('pic') >= 0;
}

function hostLabel(url: string): string {
  let clean = url;
  const scheme = clean.indexOf('://');
  if (scheme >= 0) {
    clean = clean.substring(scheme + 3);
  }
  const slash = clean.indexOf('/');
  if (slash >= 0) {
    clean = clean.substring(0, slash);
  }
  return clean.length > 0 ? clean : url;
}

function text(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function compactSubtitle(value: string): string {
  const clean = value.trim();
  if (clean.length <= 36) {
    return clean;
  }
  const comma = clean.indexOf('，');
  if (comma > 0 && comma <= 36) {
    return clean.substring(0, comma);
  }
  return clean.substring(0, 36) + '...';
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value);
}
