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
  WaterfallCardActionArgs,
  WaterfallCardViewState,
  WaterfallHomePayload,
  WaterfallSavedCardView
} from './HtmlHomeTypes';
import {
  WaterfallCardRecord,
  WaterfallSavedCard
} from '../waterfall/WaterfallPreferencesStore';
import {
  APP_LOGO_APPLE_PODCASTS,
  APP_LOGO_BILIBILI,
  APP_LOGO_CNNEWS,
  APP_LOGO_DOUBAN,
  APP_LOGO_GITHUB,
  APP_LOGO_GLOBALNEWS,
  APP_LOGO_HACKERNEWS,
  APP_LOGO_REDDIT,
  APP_LOGO_STEAM,
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
body.waterfall-direct { background: transparent; }
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
  object-fit: cover;
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
  scroll-snap-type: y mandatory; scrollbar-width: none; background: #eef0f2; touch-action: pan-y;
  padding: calc(64px + env(safe-area-inset-top) + 12px) 0 calc(96px + env(safe-area-inset-bottom));
  scroll-padding-top: calc(64px + env(safe-area-inset-top) + 12px);
  scroll-padding-bottom: calc(96px + env(safe-area-inset-bottom));
}
body.waterfall-direct .waterfall-overlay,
body.waterfall-direct .waterfall-track { background: transparent; }
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
.waterfall-card--video-fullscreen,
.waterfall-card.is-playing { opacity: 1; transform: none; }
.waterfall-cinema-stage {
  position: relative; top: auto; left: auto; right: auto;
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
  left: auto; right: auto; height: min(62dvh, 560px);
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
.waterfall-author { display: inline-flex; min-width: 0; align-items: center; gap: 7px; color: var(--card-muted, var(--muted)); }
.waterfall-author::before { content: ''; width: 1px; height: 14px; margin: 0 2px; background: var(--card-line, var(--line)); }
.waterfall-author-avatar { width: 22px; height: 22px; flex: 0 0 22px; border-radius: 999px; object-fit: cover; }
.waterfall-author-name { max-width: 16ch; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.waterfall-cinema-copy {
  position: relative; z-index: 4; top: auto; left: auto; right: auto; bottom: auto;
  display: flex; min-height: 0; flex-direction: column; overflow: hidden; padding: 18px;
  border: 0; border-radius: 0; background: transparent; box-shadow: none;
}
.waterfall-card--video.waterfall-card--landscape .waterfall-cinema-copy { top: auto; }
.waterfall-card--video.waterfall-card--portrait .waterfall-cinema-copy {
  top: auto; max-height: min(42dvh, 390px); backdrop-filter: none;
}
.waterfall-card--image-text .waterfall-cinema-copy { top: auto; }
.waterfall-card--text .waterfall-cinema-copy {
  top: auto; bottom: auto; max-height: none;
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
.waterfall-signal-rail { display: grid; grid-auto-flow: column; grid-auto-columns: minmax(0, 1fr); gap: 10px; margin-top: 14px; }
.waterfall-signal { display: inline-flex; min-width: 0; align-items: center; gap: 6px; color: var(--card-muted, var(--muted)); font-size: 12px; }
.waterfall-signal .waterfall-icon { width: 16px; height: 16px; color: var(--card-accent, var(--accent)); }
.waterfall-signal .waterfall-icon svg { width: 15px; height: 15px; }
.waterfall-signal b { overflow: hidden; font-variant-numeric: tabular-nums; font-weight: 720; text-overflow: ellipsis; }
.waterfall-reader {
  position: fixed; z-index: 8; inset: 0; display: block; overflow: hidden;
  background: #eef0f2; color: var(--ink); pointer-events: none; visibility: hidden;
  opacity: 0; border-radius: 0; transform: translate3d(0, 8px, 0) scale(0.985);
  transform-origin: center;
  transition: opacity 140ms var(--ease-out), transform 180ms var(--ease-out), visibility 0s linear 180ms;
}
.waterfall-reader.active {
  pointer-events: auto; visibility: visible; opacity: 1;
  transform: none; transition-delay: 0s;
}
.waterfall-reader.active.closing {
  pointer-events: auto; opacity: 0; transform: translate3d(0, 5px, 0) scale(0.99);
}
.waterfall-reader.is-playing,
.waterfall-reader.active.is-playing { transform: none; }
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
  padding: env(safe-area-inset-top) 12px 0;
  background: linear-gradient(180deg, rgba(245, 242, 238, 0.94) 0%, rgba(245, 242, 238, 0.55) 62%,
    rgba(245, 242, 238, 0) 100%);
  border-bottom: 0;
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
  border: 1px solid rgba(255, 255, 255, 0.72); border-radius: 18px;
  background: linear-gradient(145deg, rgba(255, 255, 255, 0.68), rgba(243, 240, 236, 0.54));
  -webkit-backdrop-filter: blur(38px) saturate(145%) brightness(1.08);
  backdrop-filter: blur(38px) saturate(145%) brightness(1.08);
  box-shadow: 0 24px 72px rgba(35, 42, 48, 0.17), inset 0 1px 0 rgba(255, 255, 255, 0.84),
    inset 0 -1px 0 rgba(255, 255, 255, 0.22);
  pointer-events: none;
  transform: translate3d(0, 24px, 0);
  visibility: hidden; opacity: 0;
  transition: opacity 180ms var(--ease-out), transform 220ms var(--ease-drawer), visibility 0s linear 180ms;
}
.waterfall-preferences.active {
  pointer-events: auto; visibility: visible; opacity: 1; transform: translate3d(0, 0, 0);
  transition-delay: 0s;
}
.waterfall-preferences:not(.active) {
  transition: opacity 100ms var(--ease-out), transform 100ms var(--ease-out), visibility 0s linear 100ms !important;
}
.waterfall-preferences:not(.active),
.waterfall-preferences:not(.active) * {
  pointer-events: none !important;
}
.waterfall-preferences .waterfall-toolbar {
  position: static; inset: auto; display: grid; grid-template-columns: 44px minmax(0, 1fr) auto auto; gap: 4px;
  align-items: center; padding: 0; margin: 0 0 8px; pointer-events: auto;
}
.waterfall-preferences .waterfall-toolbar b { font-size: 17px; text-align: left; white-space: nowrap; }
.waterfall-source-bulk { display: inline-flex; align-items: center; margin: 0; }
.waterfall-source-bulk button {
  position: relative; min-width: 44px; min-height: 44px; color: var(--muted);
  border-radius: 10px; padding: 0 7px; font-size: 12px;
}
.waterfall-source-bulk button + button::before {
  content: ''; position: absolute; left: 0; top: 15px; bottom: 15px; width: 1px;
  background: rgba(38, 49, 60, 0.12);
}
.waterfall-source-grid {
  display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 14px;
}
.waterfall-preferences label {
  display: grid; min-width: 0; min-height: 54px; grid-template-columns: 30px minmax(0, 1fr) 34px;
  align-items: center; gap: 8px; border: 0; border-bottom: 1px solid rgba(38, 49, 60, 0.08);
  border-radius: 0; background: transparent; color: #20262c; padding: 7px 2px; font-size: 14px;
  transition: opacity 160ms var(--ease-out), color 160ms var(--ease-out);
}
.waterfall-preferences label:has(input:checked) {
  color: var(--accent);
}
.waterfall-preferences label.is-unavailable { color: #97908a; opacity: 0.58; }
.waterfall-source-copy { display: grid; min-width: 0; gap: 2px; }
.waterfall-source-name { min-width: 0; overflow: visible; white-space: normal; font-weight: 720; line-height: 1.25; }
.waterfall-source-reason { color: #8b817a; font-size: 10px; line-height: 1.25; }
.waterfall-preferences input {
  position: relative; width: 34px; height: 20px; margin: 0; border: 0; border-radius: 10px;
  appearance: none; -webkit-appearance: none; background: #d8d4d0; cursor: pointer;
  transition: background-color 160ms var(--ease-out);
}
.waterfall-preferences input::after {
  content: ''; position: absolute; top: 2px; left: 2px; width: 16px; height: 16px;
  border-radius: 50%; background: #fff; box-shadow: 0 1px 3px rgba(33, 27, 23, 0.22);
  transition: transform 180ms var(--ease-out);
}
.waterfall-preferences input:checked { background: var(--accent); }
.waterfall-preferences input:checked::after { transform: translateX(14px); }
.waterfall-preferences input:disabled { cursor: default; background: #d8d4d0; }
.waterfall-empty {
  min-height: calc(100dvh - 150px); display: grid; place-items: center; align-content: center; gap: 14px;
  color: var(--muted); font-size: 16px; line-height: 1.5;
  padding: calc(72px + env(safe-area-inset-top)) 20px 20px; text-align: center;
}
.waterfall-empty button, .waterfall-status button {
  min-height: 48px; border: 1px solid var(--line-strong); border-radius: 14px; background: var(--panel);
  color: var(--ink); padding: 0 16px; font-size: 14px; font-weight: 720; cursor: pointer;
  transition: transform 140ms ease-out, box-shadow 180ms ease-out;
}
.waterfall-empty button:active, .waterfall-status button:active { transform: scale(0.97); }
.waterfall-status { color: var(--muted); font-size: 14px; line-height: 1.5; padding: 18px 20px 0; text-align: center; }
.waterfall-convergence {
  min-height: calc(100dvh - 150px); display: grid; place-content: center; justify-items: center; gap: 15px;
  padding: calc(72px + env(safe-area-inset-top)) 24px 40px; color: var(--muted); text-align: center;
}
.waterfall-convergence-orbit { display: flex; max-width: 260px; flex-wrap: wrap; justify-content: center; gap: 7px; }
.waterfall-convergence-source {
  position: relative; display: inline-grid; width: 34px; height: 34px; place-items: center;
  opacity: 0.34; transform: translate3d(0, 4px, 0) scale(0.94);
  transition: opacity 220ms var(--ease-out), transform 240ms var(--ease-out);
}
.waterfall-convergence-source .waterfall-source-logo { width: 28px; height: 28px; border-radius: 8px; }
.waterfall-convergence-source.is-loading { opacity: 0.62; animation: waterfall-source-breathe 1.4s ease-in-out infinite alternate; }
.waterfall-convergence-source.is-ready { opacity: 1; transform: none; }
.waterfall-convergence-source.is-failed { opacity: 0.24; transform: none; }
.waterfall-convergence-copy { display: grid; gap: 4px; }
.waterfall-convergence-copy strong { color: var(--ink); font-size: 15px; font-weight: 760; }
.waterfall-convergence-copy span { font-size: 11px; }
@keyframes waterfall-source-breathe { to { opacity: 0.92; transform: translate3d(0, 0, 0) scale(1); } }
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
  display: flex; height: auto; min-height: 0; flex-direction: column; overflow: hidden;
  margin: 0 14px; padding: 12px;
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
  place-items: center; border: 1px solid rgba(153, 95, 76, 0.16) !important;
  border-radius: 999px !important;
  background: rgba(255, 255, 255, 0.88) !important; color: var(--accent) !important;
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
.waterfall-feedback-bar { display: flex; min-width: 0; align-items: center; margin-left: auto; }
.waterfall-feedback-left { display: inline-flex; align-items: center; gap: 0; }
.waterfall-card-action { width: 44px; height: 44px; display: inline-grid; flex: 0 0 44px; place-items: center;
  position: relative; overflow: visible; border: 0; border-radius: 12px; background: transparent; color: var(--muted); padding: 0; cursor: pointer;
  -webkit-tap-highlight-color: transparent; touch-action: manipulation;
}
.waterfall-card-action .waterfall-icon { width: 32px; height: 32px; border-radius: 10px;
  transition: color 160ms var(--ease-out), background-color 160ms var(--ease-out), transform 160ms var(--ease-out);
}
.waterfall-card-action .waterfall-icon svg { width: 19px; height: 19px; }
.waterfall-card-action.is-selected { color: var(--accent); }
.waterfall-card-action.is-selected .waterfall-icon { background: var(--accent-soft); }
.waterfall-card-action--dislike.is-selected { color: #5e6875; }
.waterfall-card-action--dislike.is-selected .waterfall-icon { background: rgba(94, 104, 117, 0.12); }
.waterfall-card-action--save.is-selected .waterfall-icon svg { fill: currentColor; }
.waterfall-card-action:active .waterfall-icon,
.waterfall-card-action.is-pressed .waterfall-icon { transform: scale(0.88); }
.waterfall-card-action.is-celebrating .waterfall-icon { animation: waterfall-action-pop 240ms var(--ease-out) both; }
.waterfall-action-glint {
  position: absolute; inset: 7px; border: 1px solid currentColor; border-radius: 11px; pointer-events: none;
  animation: waterfall-action-glint 260ms var(--ease-out) both;
}
.waterfall-action-spark {
  position: absolute; left: 21px; top: 21px; width: 3px; height: 3px; border-radius: 50%;
  background: currentColor; pointer-events: none;
  animation: waterfall-action-spark 300ms var(--ease-out) both;
}
@keyframes waterfall-action-pop { 0% { transform: scale(0.86); } 58% { transform: scale(1.1); } 100% { transform: none; } }
@keyframes waterfall-action-glint { from { opacity: 0.58; transform: scale(0.72); } to { opacity: 0; transform: scale(1.28); } }
@keyframes waterfall-action-spark {
  from { opacity: 0.88; transform: translate3d(0, 0, 0) scale(1); }
  to { opacity: 0; transform: translate3d(var(--spark-x), var(--spark-y), 0) scale(0.4); }
}
.waterfall-card-action:focus-visible { outline: 2px solid var(--accent); outline-offset: -3px; }
.waterfall-feedback-divider { width: 1px; height: 20px; margin: 0 4px; background: var(--line); }
.waterfall-feedback-bar .waterfall-source-action { border: 0 !important; background: transparent !important; }
.waterfall-feedback-bar .waterfall-source-action .waterfall-icon { width: 32px; height: 32px; border-radius: 10px; }
.waterfall-feedback-bar .waterfall-source-action .waterfall-icon svg { width: 19px; height: 19px; }
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
  padding: env(safe-area-inset-top) 12px 0;
  background: linear-gradient(180deg, rgba(245, 242, 238, 0.94) 0%, rgba(245, 242, 238, 0.55) 62%,
    rgba(245, 242, 238, 0) 100%);
  border-bottom: 0;
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
.waterfall-toolbar-label { font-size: 13px; font-weight: 760; line-height: 1; white-space: nowrap; }
.waterfall-toolbar-title {
  display: inline-flex; max-width: min(42vw, 240px); align-items: center; justify-content: center; padding: 0 12px;
  overflow: hidden; font-size: 15px; font-weight: 780; text-overflow: ellipsis; white-space: nowrap; pointer-events: none;
}
.waterfall-toolbar-secondary {
  width: auto; min-width: 68px; gap: 6px; padding: 0 10px !important;
  border: 0 !important; background: transparent !important;
}
.waterfall-toolbar .waterfall-toolbar-secondary { width: 44px; min-width: 44px; padding: 0 !important; }
.waterfall-toolbar-tools { display: inline-flex; align-items: center; justify-self: end; gap: 0; }
.waterfall-toolbar-title, .waterfall-toolbar-tools {
  transition: opacity 160ms var(--ease-out), transform 200ms var(--ease-out);
}
.waterfall-search-form {
  position: absolute; z-index: 2; top: calc(env(safe-area-inset-top) + 10px); right: 12px; left: 82px;
  height: 44px; display: flex; align-items: center; gap: 8px; border: 1px solid rgba(153, 95, 76, 0.2);
  border-radius: 15px; background: rgba(255, 255, 255, 0.88); padding: 0 13px;
  box-shadow: 0 10px 28px rgba(69, 48, 39, 0.08); opacity: 0; visibility: hidden;
  transform: translate3d(18px, 0, 0) scaleX(0.9); transform-origin: right center; pointer-events: none;
  transition: opacity 160ms var(--ease-out), transform 220ms var(--ease-drawer), visibility 0s linear 220ms;
}
.waterfall-search-form .waterfall-icon { flex: 0 0 auto; color: var(--accent); }
.waterfall-search-form input {
  width: 100%; min-width: 0; height: 40px; border: 0; outline: 0; background: transparent;
  color: var(--ink); padding: 0; font: inherit; font-size: 15px;
}
.waterfall-search-form input::placeholder { color: #91847a; }
.waterfall-toolbar.is-searching .waterfall-toolbar-title,
.waterfall-toolbar.is-searching .waterfall-toolbar-tools { opacity: 0; transform: translate3d(-8px, 0, 0); pointer-events: none; }
.waterfall-toolbar.is-searching .waterfall-search-form {
  opacity: 1; visibility: visible; transform: none; pointer-events: auto; transition-delay: 0s;
}
.waterfall-search-status {
  position: fixed; z-index: 7; top: calc(64px + env(safe-area-inset-top)); left: 50%;
  display: flex; align-items: center; gap: 7px; max-width: calc(100% - 32px); min-height: 30px;
  border: 1px solid rgba(153, 95, 76, 0.12); border-radius: 15px;
  background: rgba(248, 245, 240, 0.9); color: var(--muted); padding: 5px 11px;
  box-shadow: 0 8px 24px rgba(69, 48, 39, 0.07); font-size: 11px; opacity: 0;
  transform: translate3d(-50%, -5px, 0); pointer-events: none;
  transition: opacity 160ms var(--ease-out), transform 180ms var(--ease-out);
}
.waterfall-search-status.active { opacity: 1; transform: translate3d(-50%, 0, 0); }
.waterfall-track.is-search-pending .waterfall-card-shell { opacity: 0.42; }
.waterfall-track.is-search-results-enter .waterfall-card-shell { animation: waterfall-search-result-in 220ms var(--ease-out) both; }
@keyframes waterfall-search-result-in { from { opacity: 0; transform: translate3d(0, 8px, 0); } to { opacity: 1; transform: none; } }
.waterfall-toolbar button:active { background: var(--accent-soft); transform: scale(0.97); }
.waterfall-toolbar .waterfall-toolbar-secondary:active { background: var(--accent-soft) !important; }
.waterfall-edge-fade {
  position: fixed; z-index: 5; left: 0; right: 0; pointer-events: none;
}
.waterfall-edge-fade--top {
  top: 0; height: calc(72px + env(safe-area-inset-top));
  background: linear-gradient(180deg, rgba(245, 242, 238, 0.78) 0%, rgba(245, 242, 238, 0) 100%);
}
.waterfall-edge-fade--bottom {
  bottom: 0; height: 18vh;
  background: linear-gradient(0deg, rgba(245, 242, 238, 0.78) 0%, rgba(245, 242, 238, 0) 100%);
}
.waterfall-preferences .waterfall-toolbar {
  min-height: 44px; background: transparent; border-bottom: 0;
  opacity: 1; transform: none; visibility: visible; transition: none;
}
.waterfall-reader { background: var(--paper); }
.waterfall-reader-head {
  z-index: 10; top: 0; left: 0; right: 0; min-height: calc(64px + env(safe-area-inset-top));
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: env(safe-area-inset-top) 12px 0; background: var(--paper);
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
  background: var(--accent-soft) !important; transform: scale(0.97);
}
.waterfall-reader-body { padding: calc(86px + env(safe-area-inset-top)) 24px calc(56px + env(safe-area-inset-bottom)); }
.waterfall-reader-layout { width: min(100%, 640px); margin: 0 auto; }
.waterfall-reader-copy { width: 100%; }
.waterfall-toolbar button,
.waterfall-reader-head button,
.waterfall-reader-head a,
.waterfall-preferences button {
  -webkit-tap-highlight-color: transparent; touch-action: manipulation; cursor: pointer;
}
.waterfall-reader-media {
  height: min(44dvh, 390px); overflow: hidden; margin-bottom: 28px; border-radius: 16px;
  background: #e7eaed; box-shadow: 0 18px 44px rgba(42,55,69,0.10);
}
.waterfall-reader-media img,
.waterfall-reader-media iframe,
.waterfall-reader-media video { display: block; width: 100%; height: 100%; border: 0; object-fit: cover; }
.waterfall-reader-media--video { height: auto; aspect-ratio: 16 / 9; }
.waterfall-reader--video.waterfall-reader--portrait .waterfall-reader-media--video {
  width: min(72%, 360px); margin-right: auto; margin-left: auto; aspect-ratio: 9 / 16;
}
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
  border: 0; background: transparent; color: rgba(255, 255, 255, 0.94);
  font-size: 13px; font-weight: 760; cursor: pointer; pointer-events: auto;
}
.waterfall-reader-video-play .waterfall-icon {
  width: 44px; height: 44px; border: 1px solid rgba(255, 255, 255, 0.34); border-radius: 999px;
  background: rgba(24, 28, 32, 0.52); box-shadow: 0 8px 20px rgba(20, 24, 28, 0.16);
  backdrop-filter: blur(8px); transition: transform 140ms var(--ease-out), background-color 140ms ease;
}
.waterfall-reader-video-play .waterfall-icon svg { width: 20px; height: 20px; }
.waterfall-reader-video-play span { display: none; }
.waterfall-reader-video-play:active .waterfall-icon { transform: scale(0.95); background: rgba(24, 28, 32, 0.64); }
.waterfall-reader-video-play:focus-visible { outline: 2px solid #fff; outline-offset: -4px; }
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-frame { opacity: 1; pointer-events: auto; }
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-poster,
.waterfall-reader-video-stage.is-playing .waterfall-media-cover,
.waterfall-reader-video-stage.is-playing .waterfall-reader-video-play { opacity: 0; pointer-events: none; }
.waterfall-reader-context {
  display: flex; min-height: 28px; align-items: center; justify-content: space-between; gap: 12px;
  margin-bottom: 20px; color: var(--muted); font-size: 12px;
}
.waterfall-reader-source { display: inline-flex; min-width: 0; align-items: center; gap: 8px; color: var(--accent); text-transform: none; letter-spacing: 0; }
.waterfall-reader-source .waterfall-author { color: var(--muted); font-weight: 650; }
.waterfall-reader-source .waterfall-author-name { max-width: none; overflow: visible; text-overflow: clip; white-space: normal; }
.waterfall-reader-context > span:last-child { flex: 0 0 auto; }
.waterfall-reader-signals {
  display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 14px 8px;
  margin: 0 0 26px; border-top: 1px solid var(--line); padding-top: 16px;
}
.waterfall-reader-signal {
  display: grid; min-width: 0; grid-template-columns: 14px minmax(0, 1fr); align-items: center; gap: 2px 4px;
  color: var(--muted); font-size: 11px;
}
.waterfall-reader-signal .waterfall-icon { width: 14px; height: 14px; color: var(--accent); }
.waterfall-reader-signal .waterfall-icon svg { width: 14px; height: 14px; }
.waterfall-reader-signal b { grid-column: 2; grid-row: 1; overflow-wrap: anywhere; color: var(--ink); font-variant-numeric: tabular-nums; font-size: 13px; font-weight: 760; }
.waterfall-reader-signal-label { grid-column: 1 / -1; font-size: 10px; font-weight: 650; white-space: nowrap; }
.waterfall-reader h2 {
  max-width: 18ch; margin: 0 0 24px; color: var(--ink);
  font-size: clamp(28px, 7.2vw, 38px); line-height: 1.08; letter-spacing: -0.035em;
}
.waterfall-reader p { max-width: 34em; margin: 0; color: #423d38; font-size: 17px; line-height: 1.78; overflow-wrap: anywhere; }
.waterfall-reader p + p { margin-top: 1em; }
.waterfall-comments { margin-top: 20px; border-top: 1px solid var(--line); padding-top: 13px; }
.waterfall-comments-head { display: flex; min-height: 24px; align-items: center; justify-content: space-between; }
.waterfall-comments-head h3 { margin: 0; color: var(--ink); font-size: 13px; line-height: 1.4; font-weight: 780; }
.waterfall-comments-head span { color: var(--muted); font-size: 10px; font-weight: 650; }
.waterfall-comments-list { display: grid; }
.waterfall-comment-row {
  display: grid; width: 100%; min-width: 0; grid-template-columns: 24px minmax(0, 1fr); gap: 8px;
  border: 0; border-bottom: 1px solid rgba(56, 65, 72, 0.07); border-radius: 0;
  background: transparent; color: inherit; padding: 9px 0; text-align: left; cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.waterfall-comment-row:last-child { border-bottom: 0; padding-bottom: 2px; }
.waterfall-comment-row--no-avatar { grid-template-columns: minmax(0, 1fr); }
.waterfall-comment-avatar { width: 24px; height: 24px; border-radius: 50%; object-fit: cover; background: #e7e9e8; }
.waterfall-comment-body { min-width: 0; }
.waterfall-comment-meta { display: flex; min-width: 0; align-items: center; gap: 6px; margin-bottom: 2px;
  color: var(--muted); font-size: 10.5px; line-height: 1.35; }
.waterfall-comment-author { overflow: hidden; color: #56514c; font-weight: 720; text-overflow: ellipsis; white-space: nowrap; }
.waterfall-comment-time { flex: 0 0 auto; }
.waterfall-comment-text {
  display: -webkit-box; overflow: hidden; color: #5a554f; font-size: 13px; line-height: 1.46;
  overflow-wrap: anywhere; -webkit-box-orient: vertical; -webkit-line-clamp: 2;
}
.waterfall-comment-row[aria-expanded="true"] .waterfall-comment-text { display: block; overflow: visible; }
.waterfall-comment-stats { display: flex; gap: 9px; margin-top: 3px; color: var(--muted); font-size: 10px; line-height: 1.3; }
.waterfall-comment-skeleton { display: grid; grid-template-columns: 24px minmax(0, 1fr); gap: 8px; padding: 9px 0; }
.waterfall-comment-skeleton-avatar { width: 24px; height: 24px; border-radius: 50%; }
.waterfall-comment-skeleton-copy { display: grid; gap: 6px; padding-top: 1px; }
.waterfall-comment-skeleton-line { display: block; height: 8px; border-radius: 999px; }
.waterfall-comment-skeleton-line--short { width: 34%; }
.waterfall-comment-skeleton-line--long { width: 88%; }
.waterfall-comment-skeleton-avatar,
.waterfall-comment-skeleton-line {
  background: linear-gradient(90deg, #e9e9e6 22%, #f5f4f1 42%, #e9e9e6 62%); background-size: 220% 100%;
  animation: waterfall-comment-shimmer 1.15s ease-in-out infinite;
}
@keyframes waterfall-comment-shimmer { from { background-position: 100% 0; } to { background-position: -100% 0; } }
.waterfall-reader-copy > .waterfall-feedback-bar { margin-top: 28px; padding-top: 12px; border-top: 1px solid var(--line); }
.waterfall-collection {
  position: fixed; z-index: 9; inset: 0; overflow-x: hidden; overflow-y: auto; visibility: hidden;
  background: var(--paper); color: var(--ink); pointer-events: none; opacity: 0;
  transform: translate3d(0, 8px, 0) scale(0.985); transform-origin: center;
  transition: opacity 140ms var(--ease-out), transform 180ms var(--ease-out), visibility 0s linear 180ms;
}
.waterfall-collection.active { visibility: visible; pointer-events: auto; opacity: 1; transform: none; transition-delay: 0s; }
.waterfall-collection-head {
  position: sticky; z-index: 2; top: 0; display: grid; min-height: calc(64px + env(safe-area-inset-top));
  grid-template-columns: 1fr auto 1fr; align-items: end; padding: env(safe-area-inset-top) 12px 0;
  border-bottom: 1px solid rgba(56, 65, 72, 0.09); background: rgba(245, 242, 238, 0.96); backdrop-filter: blur(14px);
}
.waterfall-collection-head button { display: inline-grid; width: 44px; height: 44px; place-items: center; border: 0;
  border-radius: 14px; background: transparent; color: var(--ink); padding: 0; cursor: pointer; }
.waterfall-collection-head button:last-child { justify-self: end; }
.waterfall-collection-head strong { align-self: center; font-size: 15px; font-weight: 780; }
.waterfall-collection-search { padding: 12px 16px 0; }
.waterfall-collection-search input { width: 100%; height: 42px; border: 1px solid var(--line); border-radius: 13px;
  background: #fff; color: var(--ink); padding: 0 14px; font: inherit; outline: none; }
.waterfall-collection-search input:focus { border-color: rgba(153, 95, 76, 0.45); }
.waterfall-collection-filters { display: flex; align-items: center; gap: 8px; padding: 12px 16px 8px; }
.waterfall-collection-sources { display: flex; min-width: 0; flex: 1 1 auto; gap: 7px; overflow-x: auto; scrollbar-width: none; }
.waterfall-collection-sources::-webkit-scrollbar { display: none; }
.waterfall-collection-sources button, .waterfall-collection-sort { min-height: 32px; flex: 0 0 auto; border: 1px solid var(--line);
  border-radius: 999px; background: transparent; color: var(--muted); padding: 0 12px; font-size: 12px; font-weight: 700; }
.waterfall-collection-sources button.is-selected { border-color: rgba(153, 95, 76, 0.24); background: var(--accent-soft); color: var(--accent); }
.waterfall-collection-sort { border: 0; padding: 0 6px; color: var(--ink); }
.waterfall-collection-list { width: min(100%, 680px); margin: 0 auto; padding: 4px 16px calc(32px + env(safe-area-inset-bottom)); }
.waterfall-collection-row { display: grid; grid-template-columns: 84px minmax(0, 1fr) 44px; align-items: center; gap: 12px;
  min-height: 104px; border-bottom: 1px solid var(--line); cursor: pointer; -webkit-tap-highlight-color: transparent; }
.waterfall-collection-cover { display: grid; width: 84px; height: 72px; place-items: center; overflow: hidden; border-radius: 12px; background: #e7eaed; }
.waterfall-collection-cover > img { width: 100%; height: 100%; object-fit: cover; }
.waterfall-collection-copy { min-width: 0; }
.waterfall-collection-meta { overflow: hidden; color: var(--accent); font-size: 11px; font-weight: 720; text-overflow: ellipsis; white-space: nowrap; }
.waterfall-collection-row h3 { display: -webkit-box; margin: 5px 0 4px; overflow: hidden; color: var(--ink); font-size: 15px;
  line-height: 1.35; font-weight: 700; -webkit-box-orient: vertical; -webkit-line-clamp: 2; }
.waterfall-collection-copy > span { color: var(--muted); font-size: 11px; }
.waterfall-collection-empty { padding: 22vh 16px 0; color: var(--muted); font-size: 14px; text-align: center; }
.waterfall-toast.actionable { display: flex; align-items: center; gap: 16px; pointer-events: auto; }
.waterfall-toast.actionable button { border: 0; background: transparent; color: #f0c7b8; padding: 4px 0; font: inherit; font-weight: 780; }
@media (max-width: 480px) {
  .waterfall-reader-context { display: grid; grid-template-columns: minmax(0, 1fr); gap: 6px; }
  .waterfall-reader-source { flex-wrap: wrap; }
}
@media (max-width: 360px) {
  .waterfall-reader-signals { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
@media (hover: hover) and (pointer: fine) {
  .waterfall-entry button:hover, .waterfall-toolbar button:hover, .waterfall-preferences label:hover {
    transform: translateY(-1px);
  }
}
@media (prefers-reduced-transparency: reduce) {
  .waterfall-preferences {
    background: rgba(248, 248, 246, 0.98);
    -webkit-backdrop-filter: none; backdrop-filter: none;
  }
}
@media (prefers-reduced-motion: reduce) {
  .waterfall-overlay.active { animation: waterfall-overlay-in 140ms var(--ease-out) both !important; }
  .waterfall-overlay.active.closing { animation: none !important; }
  .waterfall-entry button, .waterfall-toolbar button, .waterfall-preferences button,
  .waterfall-preferences label, .waterfall-empty button, .waterfall-status button,
  .waterfall-inline-play, .waterfall-card-action, .waterfall-card-action .waterfall-icon,
  .waterfall-comment-skeleton-avatar, .waterfall-comment-skeleton-line,
  .waterfall-convergence-source, .waterfall-action-glint, .waterfall-action-spark { transition: none; animation: none; }
  .waterfall-action-glint, .waterfall-action-spark { display: none; }
  .waterfall-search-form { transform: none; transition: opacity 140ms var(--ease-out), visibility 0s linear 140ms; }
  .waterfall-track.is-search-results-enter .waterfall-card-shell { animation: none; }
  .waterfall-reader {
    transform: none;
    transition: none !important;
  }
  .waterfall-collection { transform: none; transition: opacity 140ms var(--ease-out), visibility 0s linear 140ms !important; }
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
  function disableArkWebDomTree(scanner) {
    if (!scanner) return;
    scanner.addDomTreeReportedAsync = function () {};
    if (typeof scanner.removeDomTreeReported === 'function') scanner.removeDomTreeReported();
  }
  var arkWebDomTree = window.__arkWebDomTree;
  if (arkWebDomTree) {
    disableArkWebDomTree(arkWebDomTree);
  } else {
    Object.defineProperty(window, '__arkWebDomTree', {
      configurable: true,
      get: function () { return arkWebDomTree; },
      set: function (scanner) { arkWebDomTree = scanner; disableArkWebDomTree(scanner); }
    });
  }
  var overlay = document.getElementById('waterfall-discovery');
  var track = document.getElementById('waterfall-track');
  var preferences = document.getElementById('waterfall-preferences');
  var reader = document.getElementById('waterfall-reader');
  var collection = document.getElementById('waterfall-collection');
  var toolbar = document.getElementById('waterfall-toolbar');
  var waterfallBack = document.querySelector('[data-waterfall-back]');
  var waterfallToolbarTitle = document.getElementById('waterfall-toolbar-title');
  var toast = document.getElementById('waterfall-toast');
  var searchForm = document.getElementById('waterfall-search-form');
  var searchInput = document.getElementById('waterfall-search-input');
  var searchStatus = document.getElementById('waterfall-search-status');
  var state = window.__aiphoneWaterfallInitial || null;
  var directDiscovery = window.__aiphoneWaterfallDirect === true;
  var mode = directDiscovery ? 'discovering' : 'entry';
  var enabledSources = state && state.enabledSources ? state.enabledSources.slice() : [];
  var preferenceBaseline = '';
  var committedPreferenceSources = null;
  var aggregateHtml = state && state.aggregateHtml ? state.aggregateHtml : '';
  var advancePending = false;
  var renderedCurrentId = '';
  var renderedCards = [];
  var alignToCurrent = false;
  var alignToCandidateId = '';
  var closeTimer = null;
  var readerCloseTimer = null;
  var collectionCloseTimer = null;
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
  var readerReturnScrolled = false;
  var preferencesFeedScrollTop = 0;
  var readerStartedAt = 0;
  var readerDurationMs = 0;
  var readerReturnMode = 'discovering';
  var collectionFeedScrollTop = 0;
  var collectionQuery = '';
  var collectionSource = 'all';
  var collectionSort = 'recent';
  var collectionSearchOpen = false;
  var collectionUndoCard = null;
  var pageAnchorIndex = -1;
  var ignoreNextFeedOpen = false;
  var emittedBehavior = {};
  var pendingPayload = null;
  var pendingCardAction = null;
  var preserveLoadedCardOrder = false;
  var preferenceStatusKey = '';
  var knownUnavailableSourceStates = {};
  var searchActive = false;
  var searchSubmitted = false;
  var searchPending = false;
  var searchQuery = '';
  var searchFeedScrollTop = 0;
  var searchSourceStates = [];
  var searchTransitionTimer = null;
  var searchRestorePending = false;
  window.__aiphoneApplyWaterfallUpdate = function (payload) {
    applyCardActionAcknowledgement(payload);
    syncSearchMode(payload);
    if (searchActive && searchPending && payload && text(payload.query) === searchQuery) {
      searchSourceStates = Array.isArray(payload.sources) ? payload.sources.slice() : [];
      if (Array.isArray(payload.candidates) && payload.candidates.length === 0 && payload.replenishing) {
        updateSearchPendingStatus();
        return;
      }
      searchPending = false;
      if (searchInput && typeof searchInput.blur === 'function') searchInput.blur();
      if (toolbar) toolbar.classList.remove('is-searching');
      if (track) {
        track.classList.remove('is-search-pending');
        track.classList.add('is-search-results-enter');
      }
      if (searchStatus) searchStatus.classList.remove('active');
      if (searchTransitionTimer !== null) clearTimeout(searchTransitionTimer);
      searchTransitionTimer = setTimeout(function () {
        if (track) track.classList.remove('is-search-results-enter');
        searchTransitionTimer = null;
      }, 240);
    }
    pendingPayload = payloadAfterCardAction(payload);
    if (mode === 'collection') {
      mergePayload(payload);
      pendingPayload = null;
      renderCollection();
      return;
    }
    if (mode === 'reading') {
      mergePayload(payload);
      syncReaderComments();
      return;
    }
    if (mode === 'reader_closing' || mode === 'source_preferences' ||
      mode === 'collection_closing' || preferenceApplyTimer !== null || interactionActive || scrollActive) return;
    var restoringSearch = searchRestorePending && payload && text(payload.query) !== searchQuery;
    flushPendingPayload();
    if (restoringSearch) restoreSearchScrollAfterPaint();
  };
  function applyCardActionAcknowledgement(payload) {
    if (!pendingCardAction || !payload || !Array.isArray(payload.cardStates)) return false;
    var cardState = payload.cardStates.find(function (value) {
      return text(value.candidateId) === pendingCardAction.candidateId;
    });
    if (!cardState) return false;
    var active = pendingCardAction.action === 'save' ? cardState.saved === true :
      cardState.reaction === pendingCardAction.action;
    if (active !== pendingCardAction.active) return false;
    state.cardStates = payload.cardStates;
    if (Array.isArray(payload.savedCards)) state.savedCards = payload.savedCards;
    syncCardActionControls(pendingCardAction.candidateId);
    pendingCardAction = null;
    preserveLoadedCardOrder = true;
    return true;
  }
  function payloadAfterCardAction(payload) {
    if (!preserveLoadedCardOrder || !payload || !Array.isArray(payload.candidates) || renderedCards.length === 0) {
      return payload;
    }
    var byId = {};
    payload.candidates.forEach(function (item) { byId['$' + text(item.id)] = item; });
    var existing = {};
    renderedCards.forEach(function (card) {
      if (byId['$' + card.id]) existing['$' + card.id] = true;
    });
    var additions = {};
    var anchor = '$tail';
    for (var index = payload.candidates.length - 1; index >= 0; index -= 1) {
      var item = payload.candidates[index];
      var key = '$' + text(item.id);
      if (existing[key]) anchor = key;
      else {
        if (!additions[anchor]) additions[anchor] = [];
        additions[anchor].push(item);
      }
    }
    var ordered = [];
    var appendAdditions = function (key) {
      var values = additions[key] || [];
      for (var valueIndex = values.length - 1; valueIndex >= 0; valueIndex -= 1) ordered.push(values[valueIndex]);
    };
    renderedCards.forEach(function (card) {
      appendAdditions('$' + card.id);
      var item = byId['$' + card.id];
      if (item) ordered.push(item);
    });
    appendAdditions('$tail');
    return Object.assign({}, payload, { candidates: ordered });
  }
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
    if (state && Array.isArray(state.cardStates)) {
      state.cardStates.forEach(function (cardState) { syncCardActionControls(cardState.candidateId); });
    }
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
  function readerParagraphs(value) {
    var normalized = cleanSummary(value).replace(/\\r/g, '');
    if (!normalized) return '';
    var paragraphs = [];
    normalized.split(/\\n{2,}/).forEach(function (block) {
      block.split(/\\n+/).forEach(function (line) {
        var copy = line.trim();
        if (!copy) return;
        if (copy.length <= 150) {
          paragraphs.push(copy);
          return;
        }
        var sentences = copy.match(/[^。！？!?]+[。！？!?]?/g) || [copy];
        var current = '';
        sentences.forEach(function (sentence) {
          var next = current + sentence;
          if (current && next.length > 96) {
            paragraphs.push(current.trim());
            current = sentence;
          } else {
            current = next;
          }
        });
        if (current.trim()) paragraphs.push(current.trim());
      });
    });
    return paragraphs.map(function (paragraph) {
      return '<p>' + escapeHtml(paragraph) + '</p>';
    }).join('');
  }
  function publishedLabel(value) { return text(value).trim().replace(/^(\\d{4}-\\d{2}-\\d{2})T.*$/, '$1'); }
  function sourceLabel(source) {
    var labels = ${WATERFALL_SOURCE_LABELS_JSON};
    for (var index = 0; index < labels.length; index++) {
      if (labels[index].source === source) return labels[index].label;
    }
    return source;
  }
  function cardSourceLabel(item) {
    var primary = sourceLabel(item.source);
    var provider = text(item.provider).trim();
    return (item.source === 'cnnews' || item.source === 'globalnews') && provider && provider !== primary ?
      primary + ' · ' + provider : primary;
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
  function cardStateById(id) {
    var values = state && Array.isArray(state.cardStates) ? state.cardStates : [];
    return values.find(function (value) { return text(value.candidateId) === text(id); }) ||
      { candidateId: text(id), reaction: 'none', saved: false };
  }
  function cardActionButton(item, action, label, icon) {
    var cardState = cardStateById(item.id);
    var selected = action === 'save' ? cardState.saved === true : cardState.reaction === action;
    return '<button type="button" class="waterfall-card-action waterfall-card-action--' + action +
      (selected ? ' is-selected' : '') + '" data-waterfall-card-action="' + action +
      '" data-waterfall-candidate-id="' + escapeHtml(item.id) + '" aria-label="' + label +
      '" aria-pressed="' + (selected ? 'true' : 'false') + '">' + uiIcon(icon) + '</button>';
  }
  function feedbackBarMarkup(item) {
    var source = item.url ? '<a class="waterfall-source-action" href="' +
      escapeHtml(item.url) + '" rel="noopener noreferrer" aria-label="查看来源">' +
      uiIcon('external') + '</a>' : '';
    return '<div class="waterfall-feedback-bar"><div class="waterfall-feedback-left">' +
      cardActionButton(item, 'like', '喜欢', 'thumbsUp') +
      cardActionButton(item, 'dislike', '不喜欢', 'thumbsDown') +
      cardActionButton(item, 'save', '收藏', 'bookmark') +
      '</div><span class="waterfall-feedback-divider" aria-hidden="true"></span>' + source + '</div>';
  }
  function waterfallCommentsSupported(item) {
    return ['youtube', 'bilibili', 'x', 'hackernews', 'reddit'].indexOf(text(item && item.source)) >= 0 &&
      text(item && item.providerItemId).trim().length > 0;
  }
  function commentStatsMarkup(comment) {
    var stats = [];
    if (isFinite(Number(comment.likeCount)) && Number(comment.likeCount) >= 0 && comment.likeCount !== undefined) {
      stats.push('赞 ' + compactMetricValue(Number(comment.likeCount), false));
    }
    if (isFinite(Number(comment.replyCount)) && Number(comment.replyCount) >= 0 && comment.replyCount !== undefined) {
      stats.push('回复 ' + compactMetricValue(Number(comment.replyCount), false));
    }
    return stats.length ? '<span class="waterfall-comment-stats"><span>' +
      stats.map(escapeHtml).join('</span><span>') + '</span></span>' : '';
  }
  function commentRowMarkup(comment, index) {
    var avatar = text(comment.authorAvatarUrl).trim();
    var author = text(comment.authorName).trim();
    var published = publishedLabel(comment.publishedAt);
    var meta = author || published ? '<span class="waterfall-comment-meta">' +
      (author ? '<span class="waterfall-comment-author">' + escapeHtml(author) + '</span>' : '') +
      (published ? '<span class="waterfall-comment-time">' + escapeHtml(published) + '</span>' : '') + '</span>' : '';
    return '<button type="button" class="waterfall-comment-row' + (avatar ? '' : ' waterfall-comment-row--no-avatar') +
      '" data-waterfall-comment-toggle aria-expanded="false" aria-label="展开第 ' + (index + 1) + ' 条评论">' +
      (avatar ? '<img class="waterfall-comment-avatar" src="' + escapeHtml(avatar) +
        '" alt="" loading="lazy" referrerpolicy="no-referrer" onerror="this.hidden=true" />' : '') +
      '<span class="waterfall-comment-body">' + meta + '<span class="waterfall-comment-text">' +
      escapeHtml(comment.text) + '</span>' + commentStatsMarkup(comment) + '</span></button>';
  }
  function commentsMarkup(item) {
    if (item.commentLoadState === 'loading') {
      var skeleton = '<span class="waterfall-comment-skeleton"><span class="waterfall-comment-skeleton-avatar"></span>' +
        '<span class="waterfall-comment-skeleton-copy"><span class="waterfall-comment-skeleton-line waterfall-comment-skeleton-line--short"></span>' +
        '<span class="waterfall-comment-skeleton-line waterfall-comment-skeleton-line--long"></span></span></span>';
      return '<section class="waterfall-comments" aria-label="评论精选"><div class="waterfall-comments-head"><h3>评论精选</h3>' +
        '<span>加载中</span></div><div class="waterfall-comments-list" aria-busy="true">' + skeleton + skeleton + '</div></section>';
    }
    var comments = Array.isArray(item.comments) ? item.comments.filter(function (comment) {
      return comment && text(comment.text).trim().length > 0;
    }).slice(0, 5) : [];
    if (item.commentLoadState !== 'ready' || comments.length === 0) return '';
    return '<section class="waterfall-comments" aria-label="评论精选"><div class="waterfall-comments-head"><h3>评论精选</h3>' +
      '<span>' + comments.length + ' 条</span></div><div class="waterfall-comments-list">' +
      comments.map(commentRowMarkup).join('') + '</div></section>';
  }
  function postCommentsLoad(candidateId) {
    if (!state || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.comments.load', label: '加载评论', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', candidateId: candidateId }
    }));
  }
  function metricLabel(source, kind) {
    if (kind === 'view') return source === 'x' ? '浏览' : '播放';
    if (kind === 'like') return '点赞';
    if (kind === 'favorite') return '收藏';
    if (kind === 'comment') return source === 'x' ? '回复' : '评论';
    if (kind === 'score') return '热度';
    if (kind === 'star') return '星标';
    if (kind === 'fork') return 'Fork';
    if (kind === 'repost') return '转发';
    if (kind === 'quote') return '引用';
    if (kind === 'coin') return '投币';
    if (kind === 'danmaku') return '弹幕';
    if (kind === 'share') return '分享';
    return '';
  }
  function metricIcon(source, kind) {
    if (kind === 'view') return source === 'x' ? 'eye' : 'play';
    if (kind === 'like') return source === 'youtube' || source === 'zhihu' ? 'thumbsUp' : 'heart';
    if (kind === 'favorite') return 'star';
    if (kind === 'comment') return 'comment';
    if (kind === 'star') return 'star';
    if (kind === 'fork') return 'repost';
    return kind === 'score' ? 'upvote' : kind;
  }
  function fullMetricValue(value) {
    return Math.round(value).toString().replace(/\\B(?=(\\d{3})+(?!\\d))/g, ',');
  }
  function compactMetricValue(value, keepOneDecimal) {
    if (value < 10000) return Math.round(value).toString();
    var compact = Math.round(value / 1000) / 10;
    return compact.toFixed(keepOneDecimal || compact % 1 !== 0 ? 1 : 0) + '万';
  }
  function authorMarkup(item) {
    var name = text(item.authorName).trim();
    var avatar = text(item.authorAvatarUrl).trim();
    if (!name && !avatar) return '';
    return '<span class="waterfall-author">' +
      (avatar ? '<img class="waterfall-author-avatar" src="' + escapeHtml(avatar) +
        '" alt="" loading="lazy" referrerpolicy="no-referrer" onerror="this.hidden=true" />' : '') +
      (name ? '<span class="waterfall-author-name">' + escapeHtml(name) + '</span>' : '') + '</span>';
  }
  function metricsMarkup(item, detail) {
    var metrics = Array.isArray(item.metrics) ? item.metrics.filter(function (metric) {
      return metric && metricLabel(item.source, text(metric.kind)) && isFinite(Number(metric.value)) && Number(metric.value) >= 0;
    }) : [];
    if (!metrics.length) return '';
    var visible = detail ? metrics : metrics.slice(0, 4);
    var content = visible.map(function (metric) {
      var kind = text(metric.kind);
      var value = Number(metric.value);
      var label = metricLabel(item.source, kind);
      if (detail) {
        return '<span class="waterfall-reader-signal" data-waterfall-metric="' + escapeHtml(kind) + '">' +
          uiIcon(metricIcon(item.source, kind)) + '<span class="waterfall-reader-signal-label">' +
          escapeHtml(label) + '</span><b>' + escapeHtml(compactMetricValue(value, true)) + '</b></span>';
      }
      return '<span class="waterfall-signal" data-waterfall-metric="' + escapeHtml(kind) + '" aria-label="' +
        escapeHtml(label + ' ' + fullMetricValue(value)) + '">' + uiIcon(metricIcon(item.source, kind)) +
        '<b>' + escapeHtml(compactMetricValue(value)) + '</b></span>';
    }).join('');
    return '<div class="' + (detail ? 'waterfall-reader-signals' : 'waterfall-signal-rail') + '">' + content + '</div>';
  }
  function syncMetricSlots(payload) {
    candidates(payload).forEach(function (item) {
      var card = cardById(item.id);
      if (!card || typeof card.querySelector !== 'function') return;
      var slot = card.querySelector('[data-waterfall-card-metrics]');
      var markup = metricsMarkup(item, false);
      if (slot && slot.innerHTML !== markup) slot.innerHTML = markup;
    });
    if (mode !== 'reading' || !reader || typeof reader.querySelector !== 'function') return;
    var readerItem = candidateById(readerCandidateId);
    var readerSlot = reader.querySelector('[data-waterfall-reader-metrics]');
    var readerMarkup = readerItem ? metricsMarkup(readerItem, true) : '';
    if (readerSlot && readerSlot.innerHTML !== readerMarkup) readerSlot.innerHTML = readerMarkup;
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
  function mountPlayback(frame, kind, url) {
    if (kind === 'iframe') {
      var iframe = document.createElement('iframe');
      iframe.className = 'waterfall-media-frame';
      iframe.title = '视频播放';
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('allow',
        'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
      iframe.src = autoplayVideoUrl(url);
      frame.appendChild(iframe);
      return;
    }
    var video = document.createElement('video');
    video.className = 'waterfall-media-frame';
    video.setAttribute('controls', '');
    video.setAttribute('autoplay', '');
    video.setAttribute('playsinline', '');
    video.src = url;
    frame.appendChild(video);
  }
  function playVideo(control) {
    var stage = control && typeof control.closest === 'function' ?
      control.closest('.waterfall-reader-video-stage') : null;
    if (!stage || typeof stage.getAttribute !== 'function' ||
      typeof stage.querySelector !== 'function') return;
    var frame = stage.querySelector('.waterfall-reader-video-frame');
    var kind = text(stage.getAttribute('data-waterfall-video-kind'));
    var url = text(stage.getAttribute('data-waterfall-video-url'));
    if (!frame || !url) return;
    if (!frame.firstChild) mountPlayback(frame, kind, url);
    stage.classList.add('is-playing');
    var hostCard = typeof stage.closest === 'function' ? stage.closest('.waterfall-card') : null;
    if (hostCard) hostCard.classList.add('is-playing');
    if (reader && reader.contains(stage)) reader.classList.add('is-playing');
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
      if (Math.abs(touch.clientX - tapX) > 24 || Math.abs(touch.clientY - tapY) > 24) {
        setPressed(pressed, false);
        pressed = null;
        return;
      }
      var result = handler(event);
      if (result) {
        handled = true;
        setPressed(pressed, false);
        pressed = null;
        if (result !== 'media' && event.cancelable && typeof event.preventDefault === 'function') {
          event.preventDefault();
        }
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
  function syncSearchTitle() {
    if (!waterfallToolbarTitle) return;
    var title = searchActive && searchSubmitted ? '搜索' : '发现';
    waterfallToolbarTitle.textContent = title;
    if (typeof waterfallToolbarTitle.setAttribute === 'function') {
      waterfallToolbarTitle.setAttribute('title', title);
      waterfallToolbarTitle.setAttribute('aria-label', title);
    }
    if (waterfallBack && typeof waterfallBack.setAttribute === 'function') {
      waterfallBack.setAttribute('aria-label', searchActive && searchSubmitted ? '返回发现' : '返回首页');
    }
  }
  function syncSearchMode(payload) {
    if (!directDiscovery || searchRestorePending || !payload || payload.mode !== 'search') return;
    var query = text(payload.query).trim();
    if (!query) return;
    if (!searchActive || searchQuery !== query) {
      searchFeedScrollTop = track ? track.scrollTop : 0;
      searchActive = true;
      searchSubmitted = true;
      searchPending = true;
      searchQuery = query;
      searchSourceStates = Array.isArray(payload.sources) ? payload.sources.slice() : [];
    }
    syncSearchTitle();
    setFullscreen(true);
    updateSearchPendingStatus();
  }
  function updateSearchPendingStatus() {
    if (!searchStatus || !searchPending) return;
    var active = searchSourceStates.filter(function (source) {
      return enabledSources.indexOf(text(source.source)) >= 0;
    });
    var ready = active.filter(function (source) {
      return source.phase !== 'loading' && source.inFlight !== true;
    }).length;
    searchStatus.innerHTML = uiIcon('search') + '<span>正在搜索“' + escapeHtml(searchQuery) + '”' +
      (ready > 0 ? ' · ' + ready + '/' + active.length : '') + '</span>';
    searchStatus.classList.add('active');
  }
  function openSearch() {
    if (!directDiscovery || !toolbar || !searchInput) return;
    if (!searchActive) {
      searchActive = true;
      searchFeedScrollTop = track ? track.scrollTop : 0;
    }
    toolbar.classList.add('is-searching');
    setFullscreen(true);
    var focus = function () {
      if (typeof searchInput.focus === 'function') searchInput.focus();
    };
    if (typeof window.requestAnimationFrame === 'function') window.requestAnimationFrame(focus);
    else focus();
  }
  function submitSearch() {
    if (!searchInput || !state || !window.AIPhoneHome ||
      typeof window.AIPhoneHome.postAction !== 'function') return;
    var query = text(searchInput.value).trim();
    if (!query || query.length > 160) return;
    searchQuery = query;
    searchSubmitted = true;
    searchPending = true;
    searchRestorePending = false;
    preserveLoadedCardOrder = false;
    pendingPayload = null;
    searchSourceStates = enabledSources.map(function (source) {
      return { source: source, phase: 'loading', inFlight: true };
    });
    syncSearchTitle();
    if (track) track.classList.add('is-search-pending');
    updateSearchPendingStatus();
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.search.submit', label: '搜索', prompt: '', variant: 'secondary', kind: 'client',
      args: { surfaceId: state.surfaceId || '', query: query }
    }));
  }
  function closeSearchUi(restoreNow) {
    searchActive = false;
    searchPending = false;
    syncSearchTitle();
    if (searchInput && typeof searchInput.blur === 'function') searchInput.blur();
    if (toolbar) toolbar.classList.remove('is-searching');
    if (track) track.classList.remove('is-search-pending');
    if (searchStatus) searchStatus.classList.remove('active');
    if (restoreNow && track) track.scrollTop = searchFeedScrollTop;
    setFullscreen(false);
  }
  function restoreSearchScrollAfterPaint() {
    searchRestorePending = false;
    var restore = function () {
      if (!track) return;
      track.scrollTop = searchFeedScrollTop;
      cardMetrics = [];
      updateCardPresentation(true);
    };
    if (typeof window.requestAnimationFrame === 'function') window.requestAnimationFrame(restore);
    else restore();
  }
  function exitSearch() {
    if (!searchActive) return false;
    var submitted = searchSubmitted;
    searchSubmitted = false;
    if (submitted && state && window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
      searchRestorePending = true;
      window.AIPhoneHome.postAction(JSON.stringify({
        id: 'waterfall.search.exit', label: '退出搜索', prompt: '', variant: 'secondary', kind: 'client',
        args: { surfaceId: state.surfaceId || '' }
      }));
    }
    closeSearchUi(!submitted);
    return true;
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
    return candidates(payload).filter(function (item) {
      return enabledSources.indexOf(item.source) >= 0;
    });
  }
  function candidateById(id) {
    var live = candidates(state).find(function (item) { return text(item.id) === text(id); });
    if (live) return live;
    var saved = state && Array.isArray(state.savedCards) ? state.savedCards : [];
    return saved.find(function (item) { return text(item.id) === text(id); }) || null;
  }
  function syncCardActionControls(candidateId) {
    if (typeof document.querySelectorAll !== 'function') return;
    var cardState = cardStateById(candidateId);
    var controls = document.querySelectorAll('[data-waterfall-card-action][data-waterfall-candidate-id="' +
      text(candidateId).replace(/"/g, '\\"') + '"]');
    for (var index = 0; index < controls.length; index += 1) {
      var control = controls[index];
      var action = text(control.getAttribute('data-waterfall-card-action'));
      var selected = action === 'save' ? cardState.saved === true : cardState.reaction === action;
      control.classList.toggle('is-selected', selected);
      control.setAttribute('aria-pressed', selected ? 'true' : 'false');
    }
  }
  function setLocalCardAction(item, action, active) {
    if (!state) return;
    if (!Array.isArray(state.cardStates)) state.cardStates = [];
    var cardState = cardStateById(item.id);
    if (state.cardStates.indexOf(cardState) < 0) state.cardStates.push(cardState);
    if (action === 'save') {
      cardState.saved = active;
      if (!Array.isArray(state.savedCards)) state.savedCards = [];
      var savedIndex = state.savedCards.findIndex(function (saved) { return text(saved.id) === text(item.id); });
      if (active && savedIndex < 0) state.savedCards.unshift(Object.assign({}, item, { savedAt: Date.now() }));
      if (!active && savedIndex >= 0) state.savedCards.splice(savedIndex, 1);
    } else {
      cardState.reaction = active ? action : 'none';
    }
    syncCardActionControls(item.id);
  }
  function postCardAction(candidateId, action, active, restoreSavedAt) {
    if (!state || !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    pendingCardAction = { candidateId: candidateId, action: action, active: active };
    var args = {
      surfaceId: state.surfaceId || '', candidateId: candidateId, action: action, active: active
    };
    if (action === 'save') args.restoreSavedAt = restoreSavedAt === true;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.card.action', label: '卡片操作', prompt: '', variant: 'secondary', kind: 'client',
      args: args
    }));
  }
  function playCardActionFeedback(control, action, active) {
    if (!active || (action !== 'like' && action !== 'save') || !control ||
      typeof control.querySelectorAll !== 'function' || typeof control.appendChild !== 'function') return;
    var old = control.querySelectorAll('.waterfall-action-glint, .waterfall-action-spark');
    for (var oldIndex = 0; oldIndex < old.length; oldIndex += 1) {
      if (old[oldIndex].parentNode) old[oldIndex].parentNode.removeChild(old[oldIndex]);
    }
    control.classList.remove('is-celebrating');
    void control.offsetWidth;
    control.classList.add('is-celebrating');
    var glint = document.createElement('span');
    glint.className = 'waterfall-action-glint';
    control.appendChild(glint);
    var vectors = action === 'save' ? [[-11, -14], [12, -12], [-13, 10], [13, 11]] :
      [[-12, -12], [13, -8], [1, -16]];
    var count = Math.min(4, vectors.length);
    for (var index = 0; index < count; index += 1) {
      var spark = document.createElement('span');
      spark.className = 'waterfall-action-spark';
      spark.style.setProperty('--spark-x', vectors[index][0] + 'px');
      spark.style.setProperty('--spark-y', vectors[index][1] + 'px');
      control.appendChild(spark);
    }
    setTimeout(function () {
      var effects = control.querySelectorAll('.waterfall-action-glint, .waterfall-action-spark');
      for (var effectIndex = 0; effectIndex < effects.length; effectIndex += 1) {
        if (effects[effectIndex].parentNode) effects[effectIndex].parentNode.removeChild(effects[effectIndex]);
      }
    }, 320);
  }
  function handleCardAction(control) {
    if (!control || typeof control.getAttribute !== 'function') return false;
    var candidateId = text(control.getAttribute('data-waterfall-candidate-id'));
    var action = text(control.getAttribute('data-waterfall-card-action'));
    var item = candidateById(candidateId);
    if (action === 'save' && mode === 'collection' && state && Array.isArray(state.savedCards)) {
      item = state.savedCards.find(function (saved) { return text(saved.id) === candidateId; }) || item;
    }
    if (!item || ['like', 'dislike', 'save'].indexOf(action) < 0) return false;
    var cardState = cardStateById(candidateId);
    var active = action === 'save' ? !cardState.saved : cardState.reaction !== action;
    if (action === 'save' && !active) collectionUndoCard = Object.assign({}, item,
      { savedAt: Number(item.savedAt) || Date.now() });
    setLocalCardAction(item, action, active);
    playCardActionFeedback(control, action, active);
    postCardAction(candidateId, action, active, false);
    if (mode === 'collection' && action === 'save' && !active) {
      renderCollection();
      showCollectionUndo();
    }
    return true;
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
  function stopStageMedia(root) {
    if (!root || typeof root.querySelectorAll !== 'function') return;
    var stages = root.querySelectorAll('.waterfall-reader-video-stage.is-playing');
    for (var index = 0; index < stages.length; index += 1) {
      var frame = stages[index].querySelector('.waterfall-reader-video-frame');
      if (frame) frame.innerHTML = '';
      stages[index].classList.remove('is-playing');
    }
    var playing = root.querySelectorAll('.is-playing');
    for (index = 0; index < playing.length; index += 1) {
      playing[index].classList.remove('is-playing');
    }
  }
  function stopReaderMedia() {
    stopStageMedia(reader);
    if (reader && reader.classList) reader.classList.remove('is-playing');
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
    return bestIndex;
  }
  function snapPadding() {
    if (!track || typeof window.getComputedStyle !== 'function') return { top: 0, bottom: 0 };
    var style = window.getComputedStyle(track);
    return {
      top: parseFloat(style.scrollPaddingTop) || parseFloat(style.paddingTop) || 0,
      bottom: parseFloat(style.scrollPaddingBottom) || parseFloat(style.paddingBottom) || 0
    };
  }
  function snapTopForNode(node, index, viewportHeight, padding) {
    var top = typeof node.offsetTop === 'number' ? node.offsetTop : index * viewportHeight;
    var height = typeof node.offsetHeight === 'number' ? node.offsetHeight : viewportHeight;
    var inset = padding || snapPadding();
    var snapport = Math.max(1, viewportHeight - inset.top - inset.bottom);
    return Math.max(0, top + height / 2 - inset.top - snapport / 2);
  }
  function refreshCardMetrics() {
    if (!track || typeof track.querySelectorAll !== 'function') return;
    if (metricTimer !== null) clearTimeout(metricTimer);
    metricTimer = null;
    metricsDirty = false;
    var nodes = track.querySelectorAll('[data-waterfall-id]');
    var viewportHeight = Math.max(1, track.clientHeight);
    var padding = snapPadding();
    cardMetrics = [];
    for (var index = 0; index < nodes.length; index += 1) {
      var node = nodes[index];
      cardMetrics.push({ node: node, snapTop: snapTopForNode(node, index, viewportHeight, padding) });
    }
  }
  function updateCardPresentation(force) {
    if (!track || typeof track.querySelectorAll !== 'function') return 0;
    var nodes = track.querySelectorAll('[data-waterfall-id]');
    if (!nodes || nodes.length === 0) return 0;
    if (cardMetrics.length === 0) refreshCardMetrics();
    else if (cardMetrics.length !== nodes.length) syncCardsAfterPaint();
    if (mode === 'reading' || mode === 'reader_closing' || mode === 'source_preferences') {
      return presentedIndex < 0 ? 0 : presentedIndex;
    }
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
    if (cardMetrics.length === 0) refreshCardMetrics();
    if (index < cardMetrics.length) return cardMetrics[index].snapTop;
    var nodes = typeof track.querySelectorAll === 'function' ? track.querySelectorAll('[data-waterfall-id]') : [];
    var node = nodes && nodes[index];
    if (!node) return index * track.clientHeight;
    return snapTopForNode(node, index, Math.max(1, track.clientHeight));
  }
  function realignPresentedCard(snapToCard) {
    var run = function () {
      if (cardMetrics.length === 0) refreshCardMetrics();
      if (snapToCard && track) track.scrollTop = scrollTopForCard(visibleCardIndex());
      updateCardPresentation(true);
    };
    if (typeof window.requestAnimationFrame === 'function') window.requestAnimationFrame(run);
    else run();
  }
  function freezeFeedMotion() {
    pageAnchorIndex = -1;
    scrollActive = false;
    if (payloadSettleTimer !== null) clearTimeout(payloadSettleTimer);
    payloadSettleTimer = null;
    if (presentationFrame !== null && typeof window.cancelAnimationFrame === 'function') {
      window.cancelAnimationFrame(presentationFrame);
    }
    presentationFrame = null;
  }
  function scheduleIdleFlush(enabledOverride, forceRender) {
    if (payloadSettleTimer !== null) clearTimeout(payloadSettleTimer);
    payloadSettleTimer = setTimeout(function () {
      payloadSettleTimer = null;
      if (mode !== 'discovering' || scrollActive || interactionActive) {
        if (pendingPayload || forceRender) scheduleIdleFlush(enabledOverride, forceRender);
        return;
      }
      var flushed = flushPendingPayload(enabledOverride);
      if (forceRender && !flushed) render();
    }, 240);
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
    var oldEnabledSources = state && state.enabledSources ? state.enabledSources.join('|') : '';
    if (typeof payload.aggregateHtml === 'string' && payload.aggregateHtml !== aggregateHtml) {
      aggregateHtml = payload.aggregateHtml;
      if (!overlay || !overlay.classList.contains('active')) {
        applyDeferredAggregateHtml();
      }
    }
    rememberUnavailableSourceStates(state && state.sources);
    rememberUnavailableSourceStates(payload.sources);
    state = payload;
    syncMetricSlots(payload);
    var payloadSources = payload.enabledSources ? payload.enabledSources.slice() : [];
    if (committedPreferenceSources) {
      if (payloadSources.join('|') === committedPreferenceSources.join('|')) committedPreferenceSources = null;
      else payloadSources = committedPreferenceSources.slice();
    }
    enabledSources = payloadSources;
    if (oldEnabledSources !== enabledSources.join('|')) alignToCurrent = true;
    advancePending = false;
  }
  function syncReaderComments() {
    if (mode !== 'reading' || !readerCandidateId || !reader || typeof reader.querySelector !== 'function') return;
    var slot = reader.querySelector('[data-waterfall-comments-slot]');
    var item = candidateById(readerCandidateId);
    if (slot && item) slot.innerHTML = commentsMarkup(item);
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
    var visibleItem = visibleIndex >= 0 && visibleIndex < items.length ? items[visibleIndex] : null;
    if (mode !== 'discovering' || advancePending || currentIndex < 0 || visibleIndex <= currentIndex ||
      !window.AIPhoneHome || typeof window.AIPhoneHome.postAction !== 'function') return;
    pauseCurrentBehavior(true);
    advancePending = true;
    window.AIPhoneHome.postAction(JSON.stringify({
      id: 'waterfall.feed.advance', label: '下一条', prompt: '', variant: 'secondary', kind: 'client',
      args: {
        surfaceId: state.surfaceId || '', currentId: currentId,
        visibleId: text(visibleItem && visibleItem.id)
      }
    }));
  }
  function closeReader() {
    if (!reader || reader.classList.contains('closing')) return;
    freezeFeedMotion();
    destroyInlinePlayer();
    reader.classList.add('closing');
    readerReturnScrolled = false;
    ignoreNextFeedOpen = true;
    mode = 'reader_closing';
    if (overlay) overlay.classList.remove('reading');
    var completedReturnMode = readerReturnMode;
    if (directDiscovery && completedReturnMode !== 'collection') setFullscreen(false);
    if (playerCleanupTimer !== null) clearTimeout(playerCleanupTimer);
    playerCleanupTimer = setTimeout(function () {
      playerCleanupTimer = null;
      stopReaderMedia();
      if (reader && reader.classList.contains('closing') && reader.style) {
        reader.style.pointerEvents = 'none';
      }
    }, 0);
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
      if (reader.style) reader.style.pointerEvents = '';
      readerCloseTimer = null;
      mode = completedReturnMode;
      if (completedReturnMode === 'collection') {
        if (pendingPayload) {
          mergePayload(pendingPayload);
          pendingPayload = null;
        }
        renderCollection();
      } else if (!readerReturnScrolled && track && track.scrollTop !== readerFeedScrollTop) {
        track.scrollTop = readerFeedScrollTop;
      }
      if (completedReturnMode !== 'collection' && pendingPayload) {
        if (interactionActive || scrollActive) settleInteraction();
        else {
          payloadSettleTimer = setTimeout(function () {
            payloadSettleTimer = null;
            if (interactionActive || scrollActive) settleInteraction();
            else flushPendingPayload();
          }, 0);
        }
      }
      if (completedReturnMode === 'discovering') resumeCurrentBehavior();
      if (completedCandidateId && completedDurationMs >= 8000) {
        postBehavior(completedCandidateId, 'read_complete', completedDurationMs);
      }
    }, 180);
  }
  function openReader(id) {
    if (!reader || !track) return;
    var item = candidateById(id);
    if (!item) return;
    readerReturnMode = mode === 'collection' ? 'collection' : 'discovering';
    stopStageMedia(track);
    destroyInlinePlayer();
    var format = candidateFormat(item);
    var summary = cleanSummary(item.summary) || cleanSummary(item.reason);
    var title = text(item.title).trim() || sourceLabel(item.source) + ' 内容';
    var requestComments = waterfallCommentsSupported(item) && item.commentLoadState === undefined &&
      (!Array.isArray(item.comments) || item.comments.length === 0);
    if (requestComments) item.commentLoadState = 'loading';
    var readerClass = format === 'image_text' ? 'waterfall-reader--image-text' :
      (item.mediaType === 'video' ? 'waterfall-reader--video waterfall-reader--' +
        (format === 'portrait_video' ? 'portrait' : 'landscape') : 'waterfall-reader--text');
    if (readerCloseTimer !== null) clearTimeout(readerCloseTimer);
    readerCloseTimer = null;
    if (advanceTimer !== null) clearTimeout(advanceTimer);
    advanceTimer = null;
    if (playerCleanupTimer !== null) clearTimeout(playerCleanupTimer);
    playerCleanupTimer = null;
    if (overlay) overlay.classList.add('reading');
    freezeFeedMotion();
    if (reader.classList.contains('closing')) {
      reader.classList.remove('closing');
    }
    if (reader.style) reader.style.pointerEvents = '';
    var videoStage = item.mediaType === 'video' ? videoStageMarkup(item, title,
      'waterfall-reader-media waterfall-reader-media--video', 'waterfall-reader-video-poster') : '';
    var media = format === 'image_text' ?
      '<div class="waterfall-reader-media"><img src="' + escapeHtml(item.coverUrl) + '" alt="' +
      escapeHtml(title) + '" referrerpolicy="no-referrer" onerror="this.hidden=true" /></div>' :
      (item.mediaType === 'video' ? videoStage : '');
    var context = '<div class="waterfall-reader-context"><div class="waterfall-reader-source">' +
      sourceLogoMarkup(item.source) + '<span>' + escapeHtml(cardSourceLabel(item)) + '</span>' +
      authorMarkup(item) + '</div><span>' +
      escapeHtml(publishedLabel(item.publishedAt)) + '</span></div>';
    var copy = '<div class="waterfall-reader-copy">' + context + '<h2>' + escapeHtml(title) + '</h2>' +
      '<div data-waterfall-reader-metrics>' + metricsMarkup(item, true) + '</div>' +
      readerParagraphs(summary) +
      '<div data-waterfall-comments-slot>' + commentsMarkup(item) + '</div>' + feedbackBarMarkup(item) + '</div>';
    var content = media + copy;
    var nextId = text(item.id);
    if (readerMountedId !== nextId) {
      reader.innerHTML = '<div class="waterfall-reader-head">' +
        '<button type="button" class="waterfall-chrome-btn" data-waterfall-reader-close ' +
        'aria-label="返回发现流">' + uiIcon('back') +
        '<span class="waterfall-reader-head-label">返回</span></button>' +
        '<strong class="waterfall-reader-head-title">详情</strong><span></span>' +
        '</div><article class="waterfall-reader-body"><div class="waterfall-reader-layout ' +
        readerClass + '">' + content + '</div></article>';
      readerMountedId = nextId;
    } else if (typeof reader.querySelector === 'function') {
      var readerBody = reader.querySelector('.waterfall-reader-body');
      if (readerBody) readerBody.scrollTop = 0;
      syncCardActionControls(item.id);
    }
    pauseCurrentBehavior(false);
    readerFeedScrollTop = track.scrollTop;
    readerCandidateId = text(item.id);
    readerStartedAt = Date.now();
    readerDurationMs = 0;
    mode = 'reading';
    if (directDiscovery && readerReturnMode !== 'collection') setFullscreen(true);
    ignoreNextFeedOpen = false;
    var reveal = function () {
      if (mode === 'reading' && !reader.classList.contains('active')) reader.classList.add('active');
    };
    if (typeof window.requestAnimationFrame === 'function') window.requestAnimationFrame(reveal);
    else reveal();
    if (requestComments) setTimeout(function () { postCommentsLoad(nextId); }, 0);
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
    var title = text(item.title).trim() || sourceLabel(item.source) + ' 内容';
    var cardClass = cardClassName(item);
    var meta = '<div class="waterfall-cinema-meta">' + sourceLogoMarkup(item.source) + '<span>' +
      escapeHtml(cardSourceLabel(item)) + '</span>' + authorMarkup(item) + '</div>';
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
    var openAttr = ' data-waterfall-open="' + escapeHtml(item.id) + '"';
    var shellAttrs = item.mediaType === 'video' || sourceOnly ? '' : ' role="button" tabindex="0"' + openAttr;
    var copyAttrs = item.mediaType === 'video' || sourceOnly ? ' role="button" tabindex="0"' + openAttr : '';
    var shellClass = 'waterfall-card-shell' + (sourceOnly ? '' : ' waterfall-card-shell--interactive');
    if (twitchEmbedUrl) cardClass += ' waterfall-card--inline-player waterfall-card--inline-twitch';
    return '<article class="' + cardClass + '" data-waterfall-id="' + escapeHtml(item.id) + '" data-waterfall-media-type="' +
      escapeHtml(item.mediaType) + '"><div class="' + shellClass + '"' + shellAttrs + '>' + stage +
      '<div class="waterfall-cinema-copy"' + copyAttrs + '>' + meta +
      '<h2>' + escapeHtml(title) + '</h2>' +
      (summary ? '<p>' + escapeHtml(summary) + '</p>' : '') +
      (item.publishedAt ?
        '<div class="waterfall-meta">' + escapeHtml(publishedLabel(item.publishedAt)) + '</div>' : '') +
      '<div data-waterfall-card-metrics>' + metricsMarkup(item, false) + '</div>' +
      '<div class="waterfall-copy-actions">' + reason + feedbackBarMarkup(item) +
      '</div></div></div></article>';
  }
  function savedTimeLabel(value) {
    var elapsed = Math.max(0, Date.now() - Number(value || 0));
    if (elapsed < 3600000) return '刚刚收藏';
    if (elapsed < 86400000) return Math.max(1, Math.floor(elapsed / 3600000)) + ' 小时前';
    return Math.max(1, Math.floor(elapsed / 86400000)) + ' 天前';
  }
  function renderCollection() {
    if (!collection || !state) return;
    var saved = Array.isArray(state.savedCards) ? state.savedCards.slice() : [];
    var sources = [];
    saved.forEach(function (item) {
      if (sources.indexOf(item.source) < 0) sources.push(item.source);
    });
    if (collectionSource !== 'all' && sources.indexOf(collectionSource) < 0) collectionSource = 'all';
    var query = collectionQuery.trim().toLowerCase();
    var visible = saved.filter(function (item) {
      if (collectionSource !== 'all' && item.source !== collectionSource) return false;
      if (!query) return true;
      return [item.title, item.summary, item.authorName, sourceLabel(item.source)].some(function (value) {
        return text(value).toLowerCase().indexOf(query) >= 0;
      });
    }).sort(function (left, right) {
      return collectionSort === 'oldest' ? Number(left.savedAt) - Number(right.savedAt) :
        Number(right.savedAt) - Number(left.savedAt);
    });
    var search = collectionSearchOpen ? '<div class="waterfall-collection-search"><input type="search" ' +
      'data-waterfall-collection-query value="' + escapeHtml(collectionQuery) +
      '" placeholder="搜索收藏" aria-label="搜索收藏" /></div>' : '';
    var chips = '<button type="button" class="' + (collectionSource === 'all' ? 'is-selected' : '') +
      '" data-waterfall-collection-source="all">全部</button>' + sources.map(function (source) {
        return '<button type="button" class="' + (collectionSource === source ? 'is-selected' : '') +
          '" data-waterfall-collection-source="' + escapeHtml(source) + '">' +
          escapeHtml(sourceLabel(source)) + '</button>';
      }).join('');
    var rows = visible.map(function (item) {
      var cover = item.coverUrl ? '<img src="' + escapeHtml(item.coverUrl) + '" alt="" loading="lazy" ' +
        'referrerpolicy="no-referrer" onerror="this.hidden=true" />' : sourceLogoMarkup(item.source);
      return '<article class="waterfall-collection-row" role="button" tabindex="0" ' +
        'data-waterfall-collection-row="' + escapeHtml(item.id) + '"><div class="waterfall-collection-cover">' +
        cover + '</div><div class="waterfall-collection-copy"><div class="waterfall-collection-meta">' +
        escapeHtml(cardSourceLabel(item)) + (item.authorName ? ' · ' + escapeHtml(item.authorName) : '') +
        '</div><h3>' + escapeHtml(text(item.title).trim() || sourceLabel(item.source) + ' 内容') +
        '</h3><span>' + escapeHtml(savedTimeLabel(item.savedAt)) + '</span></div>' +
        cardActionButton(item, 'save', '取消收藏', 'bookmark') + '</article>';
    }).join('');
    var empty = saved.length === 0 ? '<div class="waterfall-collection-empty">还没有收藏</div>' :
      (visible.length === 0 ? '<div class="waterfall-collection-empty">没有匹配的收藏</div>' : '');
    collection.innerHTML = '<div class="waterfall-collection-head"><button type="button" ' +
      'data-waterfall-collection-close aria-label="返回发现流">' + uiIcon('back') +
      '</button><strong>收藏</strong><button type="button" data-waterfall-collection-search ' +
      'aria-label="搜索收藏">' + uiIcon('search') + '</button></div>' + search +
      '<div class="waterfall-collection-filters"><div class="waterfall-collection-sources">' + chips +
      '</div><button type="button" class="waterfall-collection-sort" data-waterfall-collection-sort>' +
      (collectionSort === 'recent' ? '最新' : '最早') + '</button></div><div class="waterfall-collection-list">' +
      rows + empty + '</div>';
  }
  function openCollection() {
    if (!collection || mode !== 'discovering') return;
    pauseCurrentBehavior(false);
    destroyInlinePlayer();
    collectionFeedScrollTop = track ? track.scrollTop : 0;
    freezeFeedMotion();
    renderCollection();
    if (collectionCloseTimer !== null) clearTimeout(collectionCloseTimer);
    collectionCloseTimer = null;
    collection.classList.add('active');
    if (overlay) overlay.classList.add('collection-open');
    mode = 'collection';
    if (directDiscovery) setFullscreen(true);
  }
  function closeCollection() {
    if (!collection || mode !== 'collection') return;
    collection.classList.remove('active');
    mode = 'collection_closing';
    if (directDiscovery) setFullscreen(false);
    if (collectionCloseTimer !== null) clearTimeout(collectionCloseTimer);
    collectionCloseTimer = setTimeout(function () {
      collectionCloseTimer = null;
      if (overlay) overlay.classList.remove('collection-open');
      mode = 'discovering';
      if (track && track.scrollTop !== collectionFeedScrollTop) track.scrollTop = collectionFeedScrollTop;
      realignPresentedCard();
      if (!flushPendingPayload()) resumeCurrentBehavior();
    }, 160);
  }
  function showCollectionUndo() {
    if (!toast || !collectionUndoCard) return;
    toast.innerHTML = '<span>已取消收藏</span><button type="button" data-waterfall-collection-undo>撤销</button>';
    toast.classList.add('active');
    toast.classList.add('actionable');
    if (toastTimer !== null) clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      toast.classList.remove('active');
      toast.classList.remove('actionable');
      collectionUndoCard = null;
      toastTimer = null;
    }, 3200);
  }
  function undoCollectionRemoval() {
    if (!collectionUndoCard) return;
    var card = collectionUndoCard;
    collectionUndoCard = null;
    setLocalCardAction(card, 'save', true);
    var restored = state.savedCards.find(function (item) { return text(item.id) === text(card.id); });
    if (restored) restored.savedAt = card.savedAt;
    postCardAction(text(card.id), 'save', true, true);
    toast.classList.remove('active');
    toast.classList.remove('actionable');
    renderCollection();
  }
  function waterfallSourceState(sourceName, values) {
    var sources = Array.isArray(values) ? values : [];
    return sources.find(function (source) { return text(source.source) === sourceName; }) || null;
  }
  function sourceStateIsUnavailable(source) {
    if (!source) return false;
    var message = text(source.message).toLowerCase();
    return source.phase === 'needs_auth' ||
      /禁用|不支持|未配置|缺少.*(?:凭据|密钥|client)|unsupported|not configured|missing.*(?:credential|secret|client)/i.test(message);
  }
  function rememberUnavailableSourceStates(values) {
    (Array.isArray(values) ? values : []).forEach(function (source) {
      var sourceName = text(source.source);
      if (!sourceName) return;
      if (sourceStateIsUnavailable(source)) knownUnavailableSourceStates[sourceName] = source;
      else delete knownUnavailableSourceStates[sourceName];
    });
  }
  function sourceIsUnavailable(sourceName) {
    var source = waterfallSourceState(sourceName, state && state.sources) || knownUnavailableSourceStates[sourceName];
    return sourceStateIsUnavailable(source);
  }
  function sourceUnavailableReason(sourceName) {
    var source = waterfallSourceState(sourceName, state && state.sources) || knownUnavailableSourceStates[sourceName];
    var message = text(source && source.message).toLowerCase();
    if (source && source.phase === 'needs_auth') return '需要授权';
    if (/缺少|missing/.test(message)) return '缺少服务凭据';
    return '暂不可用';
  }
  function renderSourceConvergence(values, title) {
    var sources = (Array.isArray(values) ? values : []).filter(function (source) {
      return enabledSources.indexOf(text(source.source)) >= 0;
    });
    var ready = sources.filter(function (source) {
      return source.phase !== 'loading' && source.inFlight !== true;
    }).length;
    var icons = sources.map(function (source) {
      var phase = source.phase === 'loading' || source.inFlight === true ? 'is-loading' :
        (source.phase === 'error' || source.phase === 'needs_auth' ? 'is-failed' : 'is-ready');
      return '<span class="waterfall-convergence-source ' + phase + '" aria-label="' +
        escapeHtml(sourceLabel(source.source)) + '">' + sourceLogoMarkup(source.source) + '</span>';
    }).join('');
    return '<div class="waterfall-convergence"><div class="waterfall-convergence-orbit">' + icons +
      '</div><div class="waterfall-convergence-copy"><strong>' + escapeHtml(title) +
      '</strong><span>' + ready + ' / ' + sources.length + ' 个来源已响应</span></div></div>';
  }
  function renderPreferences() {
    if (!preferences || !state) return;
    destroyInlinePlayer();
    var sourceNames = directDiscovery ? ${WATERFALL_INTEREST_SOURCE_IDS_JSON} : ${WATERFALL_SEARCH_SOURCE_IDS_JSON};
    if (preferenceApplyTimer !== null) clearTimeout(preferenceApplyTimer);
    preferenceApplyTimer = null;
    preferenceBaseline = enabledSources.join('|');
    enabledSources = enabledSources.filter(function (sourceName) { return !sourceIsUnavailable(sourceName); });
    var nextStatusKey = sourceNames.map(function (sourceName) {
      return sourceName + ':' + (sourceIsUnavailable(sourceName) ? sourceUnavailableReason(sourceName) : 'ready');
    }).join('|');
    if (!preferences.innerHTML || preferenceStatusKey !== nextStatusKey) {
      preferenceStatusKey = nextStatusKey;
      preferences.innerHTML = '<div class="waterfall-toolbar">' +
        '<button type="button" data-waterfall-close-preferences ' +
        'aria-label="返回发现流">' + uiIcon('back') + '</button><b>内容来源</b>' +
        '<div class="waterfall-source-bulk" role="group" aria-label="批量选择来源">' +
        '<button type="button" data-waterfall-sources-all>全选</button>' +
        '<button type="button" data-waterfall-sources-none>全不选</button></div>' +
        '<button type="button" data-waterfall-apply-preferences>' +
        '完成</button></div>' +
        '<div class="waterfall-source-grid">' + sourceNames.map(function (sourceName) {
          var unavailable = sourceIsUnavailable(sourceName);
          var checked = enabledSources.indexOf(sourceName) >= 0 ? ' checked' : '';
          return '<label' + (unavailable ? ' class="is-unavailable"' : '') + '>' +
            sourceLogoMarkup(sourceName) + '<span class="waterfall-source-copy"><span class="waterfall-source-name">' +
            escapeHtml(sourceLabel(sourceName)) + '</span>' +
            (unavailable ? '<small class="waterfall-source-reason">' +
              escapeHtml(sourceUnavailableReason(sourceName)) + '</small>' : '') +
            '</span><input type="checkbox" data-waterfall-source="' + escapeHtml(sourceName) + '"' + checked +
            (unavailable ? ' disabled' : '') + ' /></label>';
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
    if (track) preferencesFeedScrollTop = track.scrollTop;
    freezeFeedMotion();
    mode = 'source_preferences';
    if (directDiscovery) setFullscreen(true);
  }
  function closePreferences() {
    if (!preferences || mode !== 'source_preferences') return;
    destroyInlinePlayer();
    var changed = preferenceBaseline !== enabledSources.join('|');
    var selectedSources = enabledSources.slice();
    preferences.classList.remove('active');
    if (overlay) overlay.classList.remove('sheet-open');
    mode = 'discovering';
    if (track && track.scrollTop !== preferencesFeedScrollTop) {
      track.scrollTop = preferencesFeedScrollTop;
    }
    enabledSources = selectedSources;
    if (changed) committedPreferenceSources = selectedSources.slice();
    if (changed) preserveLoadedCardOrder = false;
    interactionActive = false;
    scrollActive = false;
    pageAnchorIndex = -1;
    if (preferenceApplyTimer !== null) clearTimeout(preferenceApplyTimer);
    preferenceApplyTimer = null;
    if (changed) {
      if (!flushPendingPayload(selectedSources)) render();
      cardMetrics = [];
    }
    realignPresentedCard(changed);
    if (changed) postSourceSelection();
    if (pendingPayload) scheduleIdleFlush(selectedSources, false);
    if (directDiscovery) setFullscreen(false);
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
        (state.replenishing ? renderSourceConvergence(state.sources, directDiscovery ? '正在获取内容' : '正在补充内容') :
          '<div class="waterfall-status">\\u6b63\\u5728\\u6c47\\u96c6\\u5185\\u5bb9\\u2026</div>');
    }
    var tailStatus = items.length > 0 && state.exhausted ?
      '<div class="waterfall-tail-status"></div>' : '';
    var cardHtml = items.map(renderCandidate);
    var nextHtml = status + empty + cardHtml.join('') + tailStatus;
    var nodes = typeof track.querySelectorAll === 'function' ?
      track.querySelectorAll('[data-waterfall-id]') : [];
    var domChanged = dropRenderedCardsMissingFrom(items, nodes);
    if (domChanged && typeof track.querySelectorAll === 'function') {
      nodes = track.querySelectorAll('[data-waterfall-id]');
    }
    var layoutChanged = domChanged;
    var cardsReplaced = false;
    var canPatch = items.length >= renderedCards.length && renderedCards.length > 0 &&
      (domChanged || nodes.length === renderedCards.length);
    var matched = 0;
    for (var i = 0; canPatch && i < items.length; i++) {
      if (matched < renderedCards.length && text(items[i].id) === renderedCards[matched].id) matched += 1;
    }
    if (matched !== renderedCards.length) canPatch = false;
    if (canPatch) {
      var renderedIndexById = {};
      for (var r = 0; r < renderedCards.length; r++) renderedIndexById['$' + renderedCards[r].id] = r;
      var nextRendered = [];
      for (var j = 0; j < items.length; j++) {
        var id = text(items[j].id);
        if (renderedIndexById['$' + id] !== undefined) continue;
        var beforeNode = null;
        for (var k = j + 1; k < items.length; k++) {
          var ahead = renderedIndexById['$' + text(items[k].id)];
          if (ahead === undefined) continue;
          beforeNode = nodes[ahead];
          break;
        }
        if (beforeNode && typeof beforeNode.insertAdjacentHTML === 'function') {
          beforeNode.insertAdjacentHTML('beforebegin', cardHtml[j]);
        } else {
          var tail = track.querySelector('.waterfall-tail-status');
          if (tail) tail.insertAdjacentHTML('beforebegin', cardHtml[j]);
          else track.insertAdjacentHTML('beforeend', cardHtml[j]);
        }
        layoutChanged = true;
        domChanged = true;
      }
      if (typeof track.querySelectorAll === 'function') {
        nodes = track.querySelectorAll('[data-waterfall-id]');
      }
      var liveById = {};
      for (r = 0; r < nodes.length; r++) {
        var liveId = nodes[r] && typeof nodes[r].getAttribute === 'function' ?
          nodes[r].getAttribute('data-waterfall-id') : '';
        if (liveId) liveById['$' + liveId] = nodes[r];
      }
      for (j = 0; j < items.length; j++) {
        id = text(items[j].id);
        var oldIndex = renderedIndexById['$' + id];
        if (oldIndex === undefined) {
          nextRendered.push({ id: id, html: cardHtml[j] });
          continue;
        }
        if (items[j].source === 'applepodcasts' && renderedCards[oldIndex].html !== cardHtml[j]) {
          var oldNode = liveById['$' + id] || nodes[oldIndex];
          if (activeInlineCard === oldNode || id === activeInlineCandidateId) {
            destroyInlinePlayer(false);
          }
          if (oldNode && 'outerHTML' in oldNode) {
            oldNode.outerHTML = cardHtml[j];
            cardsReplaced = true;
            domChanged = true;
          }
        }
        nextRendered.push({ id: id, html: cardHtml[j] });
      }
      renderedCards = nextRendered;
    } else if (track.innerHTML !== nextHtml) {
      var keepInlineCandidate = activeInlineCandidateId && items.some(function (item) {
        return text(item.id) === activeInlineCandidateId;
      });
      destroyInlinePlayer(keepInlineCandidate ? false : true);
      track.innerHTML = nextHtml;
      domChanged = true;
      layoutChanged = true;
      renderedCards = items.map(function (item, index) {
        return { id: text(item.id), html: cardHtml[index] };
      });
      if (mode !== 'reading' && mode !== 'reader_closing') {
        if (!renderedCurrentId && nextCurrentId) {
          track.scrollTop = scrollTopForCard(Math.max(0, currentIndex));
        } else {
          track.scrollTop = Math.min(nextScrollTop, maxScrollTop);
        }
      }
    }
    if (alignToCurrent || alignToCandidateId) {
      if (mode !== 'reading' && mode !== 'reader_closing') {
        var alignId = alignToCandidateId || nextCurrentId;
        var alignIndex = items.findIndex(function (item) { return text(item.id) === alignId; });
        track.scrollTop = scrollTopForCard(alignIndex >= 0 ? alignIndex : Math.max(0, items.length - 1));
      }
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
    if (cardsReplaced && !layoutChanged) {
      cardMetrics = [];
      refreshCardMetrics();
      updateCardPresentation(true);
    } else if (domChanged) syncCardsAfterPaint();
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
      var settledIndex = mode === 'discovering' ? updateCardPresentation(true) : presentedIndex;
      scrollActive = false;
      if (!interactionActive) pageAnchorIndex = -1;
      if (!interactionActive && mode !== 'reading' && mode !== 'reader_closing' &&
        mode !== 'source_preferences' &&
        !flushPendingPayload() && mode === 'discovering') scheduleAdvance(settledIndex);
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
    if (scrollActive || pendingPayload || pageAnchorIndex >= 0) settleInteraction();
  }, { passive: true });
  document.addEventListener('touchcancel', function () {
    interactionActive = false;
    if (scrollActive || pendingPayload || pageAnchorIndex >= 0) settleInteraction();
  }, { passive: true });
  track.addEventListener('scroll', function () {
    if (mode === 'reader_closing') {
      readerReturnScrolled = true;
      scrollActive = true;
      settleInteraction();
      return;
    }
    if (mode !== 'discovering') return;
    if (cardMetrics.length === 0) refreshCardMetrics();
    scrollActive = true;
    settleInteraction();
    if (presentationFrame !== null) return;
    if (typeof window.requestAnimationFrame === 'function') {
      presentationFrame = window.requestAnimationFrame(function () {
        presentationFrame = null;
        if (metricsDirty) refreshMetricsAfterSettle();
        updateCardPresentation();
      });
      return;
    }
    if (metricsDirty) refreshMetricsAfterSettle();
    updateCardPresentation();
  });
  track.addEventListener('error', function (event) {
    var image = event.target;
    if (!image || !image.classList || !image.classList.contains('waterfall-media-cover') ||
      typeof image.closest !== 'function') return;
    image.hidden = true;
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
    var cardAction = target.closest('[data-waterfall-card-action]');
    if (cardAction) return handleCardAction(cardAction);
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
      return 'media';
    }
    var stage = target.closest('.waterfall-reader-video-stage');
    if (stage) {
      playVideo(stage);
      return 'media';
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
      target.closest('[data-waterfall-card-action]') ||
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
      var cardAction = target.closest('[data-waterfall-card-action]');
      if (cardAction) return handleCardAction(cardAction);
      var comment = target.closest('[data-waterfall-comment-toggle]');
      if (comment && typeof comment.getAttribute === 'function' && typeof comment.setAttribute === 'function') {
        comment.setAttribute('aria-expanded', comment.getAttribute('aria-expanded') === 'true' ? 'false' : 'true');
        return true;
      }
      var source = target.closest('.waterfall-source-action');
      if (source && openSource(source, event)) return true;
      var play = target.closest('[data-waterfall-video-play]');
      if (play) {
        playVideo(play);
        return 'media';
      }
      var stage = target.closest('.waterfall-reader-video-stage');
      if (stage) {
        playVideo(stage);
        return 'media';
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
      if (!target || typeof target.closest !== 'function') return false;
      var selectAll = target.closest('[data-waterfall-sources-all]');
      var selectNone = target.closest('[data-waterfall-sources-none]');
      if (selectAll || selectNone) {
        preferences.querySelectorAll('[data-waterfall-source]').forEach(function (input) {
          input.checked = !!selectAll && !input.disabled;
        });
        enabledSources = Array.prototype.slice.call(
          preferences.querySelectorAll('[data-waterfall-source]:checked')
        ).map(function (node) { return node.getAttribute('data-waterfall-source'); });
        return true;
      }
      if (!target.closest('[data-waterfall-close-preferences], [data-waterfall-apply-preferences]')) return false;
      interactionActive = false;
      if (typeof event.stopPropagation === 'function') event.stopPropagation();
      closePreferences();
      return true;
    });
  }
  if (collection) {
    collection.addEventListener('input', function (event) {
      var input = event.target;
      if (!input || typeof input.matches !== 'function' || !input.matches('[data-waterfall-collection-query]')) return;
      collectionQuery = text(input.value);
      renderCollection();
      var nextInput = collection.querySelector('[data-waterfall-collection-query]');
      if (nextInput && typeof nextInput.focus === 'function') {
        nextInput.focus();
        if (typeof nextInput.setSelectionRange === 'function') {
          nextInput.setSelectionRange(collectionQuery.length, collectionQuery.length);
        }
      }
    });
    bindFastTap(collection, function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== 'function') return false;
      if (target.closest('[data-waterfall-collection-close]')) {
        closeCollection();
        return true;
      }
      if (target.closest('[data-waterfall-collection-search]')) {
        collectionSearchOpen = !collectionSearchOpen;
        if (!collectionSearchOpen) collectionQuery = '';
        renderCollection();
        var searchInput = collection.querySelector('[data-waterfall-collection-query]');
        if (searchInput && typeof searchInput.focus === 'function') searchInput.focus();
        return true;
      }
      var source = target.closest('[data-waterfall-collection-source]');
      if (source) {
        collectionSource = text(source.getAttribute('data-waterfall-collection-source')) || 'all';
        renderCollection();
        return true;
      }
      if (target.closest('[data-waterfall-collection-sort]')) {
        collectionSort = collectionSort === 'recent' ? 'oldest' : 'recent';
        renderCollection();
        return true;
      }
      var cardAction = target.closest('[data-waterfall-card-action]');
      if (cardAction) return handleCardAction(cardAction);
      var row = target.closest('[data-waterfall-collection-row]');
      if (row) {
        openReader(row.getAttribute('data-waterfall-collection-row'));
        return true;
      }
      return false;
    });
    collection.addEventListener('keydown', function (event) {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      var row = event.target && typeof event.target.closest === 'function' ?
        event.target.closest('[data-waterfall-collection-row]') : null;
      if (!row || event.target.closest('[data-waterfall-card-action]')) return;
      if (typeof event.preventDefault === 'function') event.preventDefault();
      openReader(row.getAttribute('data-waterfall-collection-row'));
    });
  }
  if (toast) {
    bindFastTap(toast, function (event) {
      var target = event.target;
      if (!target || typeof target.closest !== 'function' ||
        !target.closest('[data-waterfall-collection-undo]')) return false;
      undoCollectionRemoval();
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
  document.querySelectorAll('[data-waterfall-search-open]').forEach(function (button) {
    bindFastTap(button, function () {
      openSearch();
      return true;
    });
  });
  if (searchForm) {
    searchForm.addEventListener('submit', function (event) {
      if (typeof event.preventDefault === 'function') event.preventDefault();
      submitSearch();
    });
  }
  document.querySelectorAll('[data-waterfall-collection-open]').forEach(function (button) {
    bindFastTap(button, function () {
      openCollection();
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
    if (collection) collection.classList.remove('active');
    if (overlay) {
      overlay.classList.remove('reading');
      overlay.classList.remove('sheet-open');
      overlay.classList.remove('collection-open');
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
    if (mode === 'collection_closing') return true;
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
    if (mode === 'collection') {
      closeCollection();
      return true;
    }
    if (searchActive) return exitSearch();
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

export function waterfallSearchQueryFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.search.submit', surfaceId);
  if (args === null || Object.keys(args).sort().join(',') !== 'query,surfaceId' ||
    typeof args['query'] !== 'string') {
    return null;
  }
  const query = (args['query'] as string).trim();
  return query.length > 0 && query.length <= 160 ? query : null;
}

export function waterfallSearchExitFromAction(action: A2uiAction, surfaceId: string): boolean {
  const args = waterfallArgsFromAction(action, 'waterfall.search.exit', surfaceId);
  return args !== null && Object.keys(args).sort().join(',') === 'surfaceId';
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

export function waterfallCommentsCandidateFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.comments.load', surfaceId);
  if (args === null || Object.keys(args).sort().join(',') !== 'candidateId,surfaceId' ||
    typeof args['candidateId'] !== 'string') {
    return null;
  }
  const candidateId = (args['candidateId'] as string).trim();
  return candidateId.length > 0 ? candidateId : null;
}

export function waterfallAdvanceVisibleFromAction(action: A2uiAction, surfaceId: string): string | null {
  const args = waterfallArgsFromAction(action, 'waterfall.feed.advance', surfaceId);
  if (args === null || typeof args['visibleId'] !== 'string') {
    return null;
  }
  const visibleId = (args['visibleId'] as string).trim();
  return visibleId.length > 0 ? visibleId : null;
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

export function waterfallCardActionFromAction(
  action: A2uiAction,
  surfaceId: string
): WaterfallCardActionArgs | null {
  const args = waterfallArgsFromAction(action, 'waterfall.card.action', surfaceId);
  if (args === null || typeof args['candidateId'] !== 'string' ||
    (args['candidateId'] as string).trim().length === 0 || typeof args['action'] !== 'string' ||
    (args['action'] !== 'like' && args['action'] !== 'dislike' && args['action'] !== 'save') ||
    typeof args['active'] !== 'boolean') return null;
  const keys = Object.keys(args).sort().join(',');
  const hasRestore = keys === 'action,active,candidateId,restoreSavedAt,surfaceId';
  if (keys !== 'action,active,candidateId,surfaceId' && !hasRestore) return null;
  if (hasRestore && (args['action'] !== 'save' || typeof args['restoreSavedAt'] !== 'boolean')) return null;
  return {
    surfaceId,
    candidateId: (args['candidateId'] as string).trim(),
    action: args['action'] as 'like' | 'dislike' | 'save',
    active: args['active'] as boolean,
    restoreSavedAt: hasRestore ? args['restoreSavedAt'] as boolean : false
  };
}

export function buildWaterfallHomePayload(
  document: HtmlHomeDocument,
  isBusy: boolean,
  waterfallState: WaterfallFeedState | null = null,
  cardRecords: WaterfallCardRecord[] = []
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
  const cardStates: WaterfallCardViewState[] = cardRecords.map(
    (record: WaterfallCardRecord): WaterfallCardViewState => ({
      candidateId: record.candidateId,
      reaction: record.reaction,
      saved: record.saved
    }));
  const savedRecords = cardRecords.filter((record: WaterfallCardRecord): boolean => record.saved)
    .sort((left: WaterfallCardRecord, right: WaterfallCardRecord): number => right.savedAt - left.savedAt);
  return {
    surfaceId: document.surfaceId ?? '',
    mode: state.mode ?? 'search',
    query: state.query,
    currentId: state.current === null ? '' : state.current.id,
    aggregateHtml: renderAggregateMainContent(document, isBusy, candidates.length > 0),
    candidates: candidates,
    mediaEmbeds: waterfallMediaEmbeds(document),
    enabledSources: state.enabledSources.slice(),
    sources: state.sources,
    cardStates,
    savedCards: savedRecords.map((record: WaterfallCardRecord): WaterfallSavedCardView => {
      const card: WaterfallSavedCard = record.snapshot;
      const savedCard: WaterfallSavedCardView = {
        id: card.id,
        source: card.source,
        provider: card.provider,
        mediaType: card.mediaType,
        title: card.title,
        summary: card.summary,
        url: card.url,
        coverUrl: card.coverUrl,
        mediaUrl: card.mediaUrl ?? '',
        providerItemId: card.providerItemId,
        comments: card.comments,
        commentLoadState: card.commentLoadState,
        publishedAt: card.publishedAt,
        authorName: card.authorName,
        authorAvatarUrl: card.authorAvatarUrl,
        metrics: card.metrics,
        topics: card.topics,
        format: card.format,
        savedAt: record.savedAt
      };
      return savedCard;
    }),
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
  } else if (name === 'heart') {
    paths = '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8l1.1 1.1L12 21l7.8-7.5 1.1-1.1a5.5 5.5 0 0 0-.1-7.8Z" />';
  } else if (name === 'star') {
    paths = '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z" />';
  } else if (name === 'comment') {
    paths = '<path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4Z" />';
  } else if (name === 'eye') {
    paths = '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12Z" /><circle cx="12" cy="12" r="2.5" />';
  } else if (name === 'thumbsUp') {
    paths = '<path d="M7 10v11H3V10h4Zm0 9h10.5a2 2 0 0 0 2-1.7l1.2-7A2 2 0 0 0 18.7 8H14l.7-3.4A2.2 2.2 0 0 0 12.5 2L7 10v9Z" />';
  } else if (name === 'thumbsDown') {
    paths = '<path d="M7 14V3H3v11h4Zm0-9h10.5a2 2 0 0 1 2 1.7l1.2 7a2 2 0 0 1-2 2.3H14l.7 3.4a2.2 2.2 0 0 1-2.2 2.6L7 14V5Z" />';
  } else if (name === 'bookmark') {
    paths = '<path d="M6 4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18l-6-4-6 4V4Z" />';
  } else if (name === 'search') {
    paths = '<circle cx="11" cy="11" r="7" /><path d="m20 20-4-4" />';
  } else if (name === 'upvote') {
    paths = '<path d="m5 11 7-7 7 7h-4v8H9v-8Z" />';
  } else if (name === 'repost') {
    paths = '<path d="m17 2 4 4-4 4" /><path d="M3 11V9a3 3 0 0 1 3-3h15M7 22l-4-4 4-4" /><path d="M21 13v2a3 3 0 0 1-3 3H3" />';
  } else if (name === 'quote') {
    paths = '<path d="M8 9H4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2v-6Zm10 0h-4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2v-6Z" />';
  } else if (name === 'coin') {
    paths = '<circle cx="12" cy="12" r="9" /><path d="M9 8h4.5a2 2 0 0 1 0 4H9m0 0h5a2 2 0 0 1 0 4H9V8m3-2v2m0 8v2" />';
  } else if (name === 'danmaku') {
    paths = '<rect x="3" y="5" width="18" height="14" rx="3" /><path d="M7 10h6M7 14h10M16 10h1" />';
  } else if (name === 'share') {
    paths = '<circle cx="18" cy="5" r="2" /><circle cx="6" cy="12" r="2" /><circle cx="18" cy="19" r="2" /><path d="m8 11 8-5m-8 7 8 5" />';
  }
  return '<span class="waterfall-icon" aria-hidden="true"><svg viewBox="0 0 24 24" focusable="false">' +
    paths + '</svg></span>';
}

export function renderAggregateSearchHomeDocument(
  document: HtmlHomeDocument,
  isBusy: boolean = false,
  startInDiscovery: boolean = false,
  deferInitialPayload: boolean = false
): string {
  const waterfall = buildWaterfallHomePayload(document, isBusy);
  const waterfallJson = waterfall === null || deferInitialPayload ? 'null' :
    JSON.stringify(waterfall).replace(/</g, '\\u003c');
  const sourceLogosJson = JSON.stringify({
    youtube: APP_LOGO_YOUTUBE,
    bilibili: APP_LOGO_BILIBILI,
    x: APP_LOGO_X,
    hackernews: APP_LOGO_HACKERNEWS,
    reddit: APP_LOGO_REDDIT,
    zhihu: APP_LOGO_ZHIHU,
    applepodcasts: APP_LOGO_APPLE_PODCASTS,
    twitch: APP_LOGO_TWITCH,
    github: APP_LOGO_GITHUB,
    steam: APP_LOGO_STEAM,
    cnnews: APP_LOGO_CNNEWS,
    globalnews: APP_LOGO_GLOBALNEWS
  }).replace(/</g, '\\u003c');
  const uiIconsJson = JSON.stringify({
    back: waterfallUiIconMarkup('back'),
    external: waterfallUiIconMarkup('external'),
    expand: waterfallUiIconMarkup('expand'),
    play: waterfallUiIconMarkup('play'),
    sources: waterfallUiIconMarkup('sources'),
    heart: waterfallUiIconMarkup('heart'),
    star: waterfallUiIconMarkup('star'),
    comment: waterfallUiIconMarkup('comment'),
    eye: waterfallUiIconMarkup('eye'),
    thumbsUp: waterfallUiIconMarkup('thumbsUp'),
    thumbsDown: waterfallUiIconMarkup('thumbsDown'),
    bookmark: waterfallUiIconMarkup('bookmark'),
    search: waterfallUiIconMarkup('search'),
    upvote: waterfallUiIconMarkup('upvote'),
    repost: waterfallUiIconMarkup('repost'),
    quote: waterfallUiIconMarkup('quote'),
    coin: waterfallUiIconMarkup('coin'),
    danmaku: waterfallUiIconMarkup('danmaku'),
    share: waterfallUiIconMarkup('share')
  }).replace(/</g, '\\u003c');
  const waterfallStatus = waterfall !== null && waterfall.replenishing ? '<div class="waterfall-status">正在补充内容</div>' :
    (waterfall !== null && waterfall.exhausted ? '<div class="waterfall-status">本轮内容已结束</div>' : '');
  return [
    '<!doctype html>',
    '<html lang="zh-CN"><head><meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />',
    '<title>', escapeHtml(document.title), '</title>',
    '<style>', AGGREGATE_CSS, WATERFALL_CSS, '</style></head><body',
    startInDiscovery ? ' class="waterfall-direct"' : '', '>',
    '<main class="aggregate-shell">',
    deferInitialPayload ? '' :
      (waterfall === null ? renderAggregateMainContent(document, isBusy, false) : waterfall.aggregateHtml),
    '</main>', waterfall !== null ? '<section id="waterfall-discovery" class="waterfall-overlay' +
      (startInDiscovery ? ' active' : '') + '">' +
      '<div id="waterfall-toolbar" class="waterfall-toolbar">' +
      '<button type="button" class="waterfall-toolbar-primary" aria-label="' +
      (startInDiscovery ? '返回首页' : '返回聚合搜索') + '" data-waterfall-back>' +
      waterfallUiIconMarkup('back') +
      '<span class="waterfall-toolbar-label">返回</span></button>' +
      '<span id="waterfall-toolbar-title" class="waterfall-toolbar-title" aria-label="发现">发现</span>' +
      '<div class="waterfall-toolbar-tools">' +
      (startInDiscovery ? '<button type="button" class="waterfall-toolbar-secondary" ' +
        'aria-label="搜索" data-waterfall-search-open>' + waterfallUiIconMarkup('search') + '</button>' : '') +
      '<button type="button" class="waterfall-toolbar-secondary" ' +
      'aria-label="收藏" data-waterfall-collection-open>' + waterfallUiIconMarkup('bookmark') + '</button>' +
      '<button type="button" class="waterfall-toolbar-secondary" ' +
      'aria-label="内容来源" data-waterfall-preferences>' + waterfallUiIconMarkup('sources') +
      '</button></div>' +
      (startInDiscovery ? '<form id="waterfall-search-form" class="waterfall-search-form" role="search">' +
        waterfallUiIconMarkup('search') + '<input id="waterfall-search-input" type="search" maxlength="160" ' +
        'enterkeyhint="search" autocomplete="off" aria-label="搜索发现内容" placeholder="搜索内容" /></form>' : '') +
      '</div>' +
      (startInDiscovery ? '<div id="waterfall-search-status" class="waterfall-search-status"></div>' : '') +
      '<div id="waterfall-track" class="waterfall-track">' + waterfallStatus + '</div>' +
      '<div class="waterfall-edge-fade waterfall-edge-fade--top" aria-hidden="true"></div>' +
      '<div class="waterfall-edge-fade waterfall-edge-fade--bottom" aria-hidden="true"></div>' +
      '<div id="waterfall-preferences" class="waterfall-preferences"></div>' +
      '<div id="waterfall-reader" class="waterfall-reader"></div>' +
      '<div id="waterfall-collection" class="waterfall-collection"></div>' +
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
  const thumbnail = text(block.mediaEmbed.thumbnail);
  if (text(block.source) === 'youtube' && thumbnail.length > 0) {
    return '<a href="' + escapeAttribute(block.mediaEmbed.embedUrl) +
      '" target="_blank" rel="noopener noreferrer"><img class="aggregate-embed" src="' + escapeAttribute(thumbnail) +
      '" alt="' + escapeAttribute(block.mediaEmbed.title) + '" loading="lazy" decoding="async" referrerpolicy="no-referrer" /></a>';
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
    return '<img class="aggregate-post-media" src="' + escapeAttribute(url) +
      '" alt="帖子图片" loading="lazy" onerror="this.hidden=true" />';
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
  if (source === 'github') {
    return APP_LOGO_GITHUB;
  }
  if (source === 'steam') {
    return APP_LOGO_STEAM;
  }
  if (source === 'cnnews') {
    return APP_LOGO_CNNEWS;
  }
  if (source === 'globalnews') {
    return APP_LOGO_GLOBALNEWS;
  }
  return '';
}

export function shouldShowWaterfallReaderAction(_source: AggregateSearchSource, _mediaType: string): boolean {
  return true;
}

function sourceCssValue(source: string): string {
  const clean = source.trim().toLowerCase();
  if (clean === 'youtube' || clean === 'bilibili' || clean === 'x' || clean === 'hackernews' ||
    clean === 'reddit' || clean === 'zhihu' || clean === 'douban' || clean === 'applepodcasts' ||
    clean === 'twitch' || clean === 'github' || clean === 'steam' || clean === 'cnnews' || clean === 'globalnews') {
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
  if (source === 'github') {
    return 'GitHub';
  }
  if (source === 'steam') {
    return 'Steam';
  }
  if (source === 'cnnews') {
    return 'CNNews';
  }
  if (source === 'globalnews') {
    return 'GlobalNews';
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
