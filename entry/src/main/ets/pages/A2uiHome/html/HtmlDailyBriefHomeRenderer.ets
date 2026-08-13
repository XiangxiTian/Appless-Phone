import { A2uiAction, WaterfallRankedCandidate } from '@loop/agent-core';
import { url as arkUrl } from '@kit.ArkTS';
import {
  dailyBriefDate,
  dailyBriefDemoScenario,
  dailyBriefMailDigest,
  projectDailyBriefDiscovery,
  projectDailyBriefMailForDate
} from '../dailybrief/DailyBriefCore';
import {
  DailyBriefDiscoveryItem,
  DailyBriefDemoScenario,
  DailyBriefHighlight,
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceId,
  DailyBriefSourceState,
  DailyBriefSourceSummary
} from '../dailybrief/DailyBriefTypes';
import { HtmlHomeAction, HtmlHomeDocument } from './HtmlHomeTypes';

const DAILY_BRIEF_CSS: string = `
:root{color-scheme:light;--paper:#f5f2ee;--panel:#fff;--ink:#211b17;--soft:#5e544c;--muted:#81756b;--line:rgba(33,27,23,.12);--accent:#805947;--accent-soft:#eee3dc;--warn:#9a6a22}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:system-ui,-apple-system,"HarmonyOS Sans SC",sans-serif}.daily-shell{max-width:760px;margin:0 auto;padding:18px 16px calc(30px + env(safe-area-inset-bottom))}.daily-hero{margin:0 2px 14px;padding:4px 0 10px;border-bottom:1px solid var(--line)}.daily-section,.daily-preference,.daily-scenario{margin-bottom:14px;border:1px solid var(--line);border-radius:20px;background:var(--panel);padding:18px}.daily-kicker,.daily-meta,.daily-state,.daily-source{color:var(--muted);font-size:12px;line-height:1.45}.daily-hero h1{margin:3px 0 5px;font-size:24px;line-height:1.12;letter-spacing:-.02em}.daily-hero-row,.daily-section-head,.daily-source-row,.daily-history,.daily-card-actions{display:flex;align-items:center;justify-content:space-between;gap:10px}.daily-button{min-height:42px;border:1px solid var(--line);border-radius:13px;background:var(--panel);color:var(--ink);padding:0 13px;font-size:13px;font-weight:700;transition:transform 140ms cubic-bezier(.23,1,.32,1),background-color 140ms ease}.daily-button:active{transform:scale(.97)}.daily-button.primary{border-color:var(--accent);background:var(--accent);color:#fff}.daily-button.tertiary{min-height:36px;background:#faf8f5}.daily-button:disabled{opacity:.5}.daily-timeline{display:grid;gap:0;margin-bottom:14px}.daily-highlight{position:relative;margin-left:13px;border-left:2px solid var(--accent-soft);padding:0 0 16px 22px}.daily-highlight:last-child{padding-bottom:0}.daily-highlight:before{content:"";position:absolute;left:-7px;top:4px;width:12px;height:12px;border-radius:50%;background:var(--accent)}.daily-highlight b,.daily-item b{display:block;font-size:15px}.daily-highlight p,.daily-item p,.daily-section-message{margin:5px 0 0;color:var(--soft);font-size:13px;line-height:1.55}.daily-highlight p{display:-webkit-box;-webkit-box-orient:vertical;-webkit-line-clamp:2;overflow:hidden}.daily-status-rail{display:grid;grid-auto-flow:column;grid-auto-columns:minmax(152px,1fr);gap:10px;overflow-x:auto;padding:2px 1px 10px;margin-bottom:14px}.daily-status,.daily-discovery-card{border:1px solid var(--line);border-radius:16px;background:var(--panel);padding:14px}.daily-status-icon{display:grid;place-items:center;width:34px;height:34px;margin-bottom:9px;border-radius:11px;background:var(--accent-soft);font-size:18px}.daily-status strong{display:block;margin:4px 0;font-size:14px}.daily-section h2,.daily-preference h2,.daily-scenario h2{margin:0;font-size:19px;letter-spacing:-.01em}.daily-state{border-radius:999px;background:var(--accent-soft);padding:4px 8px}.daily-items,.daily-mail-list,.daily-discovery-list{display:grid;gap:10px;margin-top:12px}.daily-item,.daily-mail-item{border-top:1px solid var(--line);padding-top:11px}.daily-item:first-child,.daily-mail-item:first-child{border-top:0;padding-top:0}.daily-item-action{margin-top:9px}.daily-mail-item{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px 12px;align-items:center}.daily-mail-summary{grid-column:1/2}.daily-mail-item .daily-button{grid-column:2;grid-row:1/3}.daily-mail-title,.daily-mail-summary,.daily-discovery-title,.daily-discovery-summary,.daily-discovery-reason{display:-webkit-box;-webkit-box-orient:vertical;overflow:hidden}.daily-mail-title,.daily-discovery-title{-webkit-line-clamp:2}.daily-mail-summary{-webkit-line-clamp:2}.daily-discovery-summary{-webkit-line-clamp:3}.daily-discovery-reason{-webkit-line-clamp:1}.daily-mail-summary{margin:5px 0 0;color:var(--soft);font-size:13px;line-height:1.5}.daily-scenario-grid{display:grid;grid-template-columns:minmax(0,1.08fr) minmax(0,.92fr);gap:12px;margin-top:14px}.daily-outfit{overflow:hidden;border-radius:16px;background:#e7e1da}.daily-outfit img{display:block;width:100%;aspect-ratio:4/3;object-fit:cover}.daily-outfit-copy{padding:13px}.daily-outfit-copy b{display:block;font-size:15px}.daily-outfit-copy p{margin:5px 0 0;color:var(--soft);font-size:13px;line-height:1.5}.daily-route-card{padding:14px;border-radius:16px;background:#27221f;color:#fff}.daily-route-card .daily-meta{color:rgba(255,255,255,.65)}.daily-route-card h3{margin:7px 0 5px;font-size:17px}.daily-route-card p{margin:0 0 12px;color:rgba(255,255,255,.76);font-size:13px;line-height:1.5}.daily-route-card .daily-button{width:100%;margin-top:8px;border-color:rgba(255,255,255,.18);background:rgba(255,255,255,.1);color:#fff}.daily-local-panel{display:none;margin-top:10px;padding-top:10px;border-top:1px solid rgba(255,255,255,.16);font-size:13px;line-height:1.55}.daily-local-panel.visible{display:block}.daily-discovery-list{grid-template-columns:minmax(0,1fr);gap:12px}.daily-discovery-card{display:grid;grid-template-columns:116px minmax(0,1fr);gap:12px;padding:12px}.daily-discovery-cover{position:relative;min-height:112px;overflow:hidden;border-radius:12px;background:var(--accent-soft)}.daily-discovery-cover img{width:100%;height:100%;object-fit:cover}.daily-discovery-cover span{position:absolute;left:8px;bottom:8px;border-radius:8px;background:rgba(24,20,18,.82);color:#fff;padding:4px 7px;font-size:11px}.daily-discovery-card.no-cover{grid-template-columns:1fr}.daily-discovery-card h3{margin:4px 0 5px;font-size:15px}.daily-discovery-card p{margin:0;color:var(--soft);font-size:13px;line-height:1.5}.daily-discovery-reason{margin-top:5px!important;color:var(--muted)!important}.daily-source-row{align-items:center;margin-top:9px}.daily-source-button{border:0;background:transparent;color:var(--accent);padding:0;font-weight:700;text-align:right}.daily-preference .daily-meta{margin-top:5px}.daily-form{display:grid;gap:12px;margin-top:14px}.daily-form label{display:grid;gap:6px;color:var(--soft);font-size:13px}.daily-form input,.daily-form select,.daily-form textarea{width:100%;min-height:44px;border:1px solid var(--line);border-radius:12px;background:#faf8f5;color:var(--ink);padding:10px 12px;font:inherit}.daily-form textarea{min-height:76px;resize:vertical}.daily-form-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}.daily-history{justify-content:center;margin-top:16px}.daily-empty{text-align:center;padding:48px 20px}.daily-empty h1{font-size:24px}.daily-empty p{color:var(--soft);white-space:pre-wrap}@media(max-width:520px){.daily-form-grid,.daily-scenario-grid{grid-template-columns:1fr}.daily-outfit{display:grid;grid-template-columns:122px minmax(0,1fr)}.daily-outfit img{height:100%;min-height:150px;aspect-ratio:auto}.daily-discovery-card{grid-template-columns:104px minmax(0,1fr)}}@media(max-width:380px){.daily-hero-row{align-items:flex-start;flex-direction:column}.daily-discovery-card{grid-template-columns:1fr}.daily-discovery-cover{min-height:148px}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;transition:none!important}}
.daily-hero-nav{display:flex;align-items:center;justify-content:space-between;min-height:36px;margin-bottom:12px}.daily-hero-nav nav{display:flex;gap:7px}.daily-button.compact{min-height:34px;border-radius:11px;padding:0 11px;font-size:12px}.daily-button.icon{display:grid;place-items:center;width:36px;min-height:36px;padding:0;border-radius:50%;font-size:20px;font-weight:500}.daily-route-card{border:1px solid var(--line);background:#fff;color:var(--ink)}.daily-route-card .daily-meta{color:var(--muted)}.daily-route-card p{color:var(--soft)}.daily-route-card .daily-button{border-color:var(--line);background:#faf8f5;color:var(--ink)}.daily-local-panel{border-top-color:var(--line);color:var(--soft)}.daily-spending-overview{display:grid;grid-template-columns:128px minmax(0,1fr);gap:18px;align-items:center;margin-top:14px;padding:14px;border-radius:16px;background:#faf8f5}.daily-spending-chart{position:relative;display:grid;place-items:center;align-content:center;width:116px;aspect-ratio:1;border-radius:50%;background:conic-gradient(var(--accent) 0 55%,#c98b6c 55% 81%,#d8c8bd 81% 100%);isolation:isolate}.daily-spending-chart:before{content:"";position:absolute;inset:17px;border-radius:50%;background:#faf8f5;z-index:-1}.daily-spending-chart strong{font-size:15px}.daily-spending-chart span{color:var(--muted);font-size:11px}.daily-spending-legend{display:grid;gap:9px}.daily-spending-legend span{display:flex;align-items:center;gap:8px;color:var(--soft);font-size:13px}.daily-spending-legend i{width:9px;height:9px;border-radius:50%;background:var(--accent)}.daily-spending-legend i.ride{background:#c98b6c}.daily-spending-legend i.subscription{background:#d8c8bd}.daily-bills{display:grid;gap:0;margin-top:16px}.daily-bill{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px 12px;align-items:center;border-top:1px solid var(--line);padding:11px 0}.daily-bill>div:first-child{display:grid;gap:3px}.daily-bill span{color:var(--muted);font-size:12px}.daily-bill-panel{display:none;grid-column:1/-1;padding:11px;border-radius:12px;background:var(--accent-soft)}.daily-bill-panel.visible{display:grid;gap:4px}.daily-bill-panel span{line-height:1.5}@media(max-width:520px){.daily-spending-overview{grid-template-columns:112px minmax(0,1fr);gap:12px}.daily-spending-chart{width:104px}}@media(max-width:380px){.daily-hero-row{display:block}.daily-spending-overview{grid-template-columns:1fr}.daily-spending-chart{margin:auto}}
.daily-mail-preview{display:none;grid-column:1/-1;padding:11px;border-radius:12px;background:var(--accent-soft);color:var(--soft);font-size:13px;line-height:1.55}.daily-mail-preview.visible{display:block}.daily-source{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.daily-source-row .daily-button{flex:0 0 auto;white-space:nowrap}
.daily-section-head{min-width:0}.daily-section-head>*:first-child{min-width:0}.daily-discovery-card>div:last-child{min-width:0}.daily-source-row{flex-wrap:nowrap;min-width:0}.daily-section-head .daily-button{flex:0 0 auto;max-width:48%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.daily-section,.daily-discovery-card{min-width:0;max-width:100%;overflow:hidden}
`;

type DailyBriefActionValue = Object | string | number | boolean | null | undefined;
type DailyBriefActionRecord = Record<string, DailyBriefActionValue>;

export function shouldRenderDailyBriefHomeDocument(document: HtmlHomeDocument): boolean {
  return document.kind === 'daily-brief';
}

export function renderDailyBriefHomeDocument(
  document: HtmlHomeDocument,
  isBusy: boolean = false
): string {
  if (document.dailyBrief === undefined) {
    return renderEmptyDailyBrief(document);
  }
  const snapshot = document.dailyBrief;
  const preference = document.dailyBriefPreference === undefined
    ? snapshot.profile
    : document.dailyBriefPreference;
  return [
    '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />',
    '<title>', escapeHtml(document.title), '</title><style>', DAILY_BRIEF_CSS, '</style></head><body>',
    '<main class="daily-shell">',
    renderHero(document, snapshot, isBusy),
    renderHighlights(snapshot),
    renderStatusRail(snapshot),
    renderScenario(document, snapshot, isBusy),
    renderSections(document, snapshot, isBusy),
    renderDiscovery(document, snapshot, isBusy),
    renderPreference(document, snapshot.profile, preference, isBusy),
    '</main><script>', dailyBriefScript(), '</script></body></html>'
  ].join('');
}

function renderEmptyDailyBrief(document: HtmlHomeDocument): string {
  return [
    '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8" />',
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />',
    '<title>', escapeHtml(document.title), '</title><style>', DAILY_BRIEF_CSS, '</style></head><body>',
    '<main class="daily-shell"><section class="daily-hero daily-empty"><div class="daily-kicker">个人日报</div>',
    '<h1>', escapeHtml(document.title), '</h1>',
    document.subtitle.length > 0 ? '<p>' + escapeHtml(document.subtitle) + '</p>' : '',
    '</section></main></body></html>'
  ].join('');
}

function renderHero(document: HtmlHomeDocument, snapshot: DailyBriefSnapshot, isBusy: boolean): string {
  const regenerate = actionById(document, 'daily.brief.regenerate');
  const previous = historyAction(document, 'previous');
  const today = snapshot.date === dailyBriefDate(new Date()) ? null : historyAction(document, 'today');
  return [
    '<header class="daily-hero"><div class="daily-hero-nav"><nav aria-label="日期切换">',
    renderActionButton(previous, isBusy, 'compact', '前一天'),
    renderActionButton(today, isBusy, 'compact', '回今天'),
    '</nav>', renderActionButton(regenerate, isBusy, 'icon', '↻', '重新生成'), '</div>',
    '<div class="daily-kicker">个人日报</div><div class="daily-hero-row"><div>',
    '<h1>', escapeHtml(snapshot.date), '</h1>',
    '<div class="daily-meta">实际生成 · ', escapeHtml(snapshot.generatedAt), '</div>',
    isBusy ? '<div class="daily-meta">重新生成中</div>' : '',
    '</div></div></header>'
  ].join('');
}

function renderHighlights(snapshot: DailyBriefSnapshot): string {
  const items = snapshot.topThree.map((highlight: DailyBriefHighlight): string => [
    '<article class="daily-highlight"><div class="daily-kicker">',
    escapeHtml(highlightLabel(highlight)), '</div><b>', escapeHtml(highlight.item.title),
    '</b><p>', escapeHtml(dailyBriefVisibleText(itemDetail(highlight.item))), '</p></article>'
  ].join(''));
  return '<section class="daily-timeline" aria-label="Top 3">' + items.join('') + '</section>';
}

function highlightLabel(highlight: DailyBriefHighlight): string {
  if (highlight.slot === 'time_constraint') {
    return '时间约束';
  }
  if (highlight.slot === 'action_needed') {
    return '需要处理';
  }
  return '状态提醒';
}

function renderStatusRail(snapshot: DailyBriefSnapshot): string {
  const statuses: [string, string, DailyBriefSourceId][] = [
    ['☔', '天气', 'weather'], ['🚕', '通勤', 'commute'], ['♥', '健康', 'health'], ['¥', '消费', 'spending']
  ];
  return '<section class="daily-status-rail" aria-label="今日状态">' + statuses.map(
    (entry: [string, string, DailyBriefSourceId]): string => {
      const item = itemBySource(snapshot, entry[2]);
      const section = sectionForSource(snapshot, entry[2]);
      return '<article class="daily-status"><div class="daily-status-icon" aria-hidden="true">' + entry[0] +
        '</div><div class="daily-kicker">' + escapeHtml(entry[1]) + '</div><strong>' +
        escapeHtml(item === null ? '暂无实时数据' : item.title) + '</strong><div class="daily-meta">' +
        escapeHtml(item === null ? (section === null ? '' : section.message) : itemDetail(item)) + '</div></article>';
    }
  ).join('') + '</section>';
}

function renderScenario(document: HtmlHomeDocument, snapshot: DailyBriefSnapshot, isBusy: boolean): string {
  const scenario: DailyBriefDemoScenario = dailyBriefDemoScenario(snapshot.date);
  const route = actionById(document, 'daily.brief.route.open');
  const ride = actionById(document, 'daily.brief.ride.estimate');
  return [
    '<section class="daily-scenario"><div class="daily-section-head"><h2>穿衣与出行</h2>',
    '<span class="daily-state">今日建议</span></div><div class="daily-scenario-grid">',
    '<article class="daily-outfit"><img src="', escapeAttribute(scenario.outfitImage), '" alt="',
    escapeAttribute(scenario.outfitTitle), ' 穿搭照片" /><div class="daily-outfit-copy"><div class="daily-kicker">今日穿衣推荐</div><b>',
    escapeHtml(scenario.outfitTitle), '</b><p>', escapeHtml(scenario.outfitSummary), '</p></div></article>',
    '<article class="daily-route-card"><div class="daily-meta">已识别出行 · ',
    escapeHtml(scenario.departureLabel), '</div><h3>', escapeHtml(scenario.routeLabel), '</h3><p>上车点：',
    escapeHtml(scenario.origin), '<br />下车点：', escapeHtml(scenario.destination), '<br />偏好车型：',
    escapeHtml(scenario.preferredVehicle), '</p>',
    renderActionButton(route, isBusy, '', '查看路线'),
    renderActionButton(ride, isBusy, '', '预估车型'),
    '</article></div></section>'
  ].join('');
}

function renderSections(document: HtmlHomeDocument, snapshot: DailyBriefSnapshot, isBusy: boolean): string {
  const sectionIds: string[] = ['today', 'yesterday', 'mail', 'weather_commute', 'health', 'spending'];
  const sections: DailyBriefSection[] = [];
  sectionIds.forEach((id: string): void => {
    for (let index = 0; index < snapshot.sections.length; index += 1) {
      if (snapshot.sections[index].id === id) {
        sections.push(snapshot.sections[index]);
        break;
      }
    }
  });
  return sections.map((section: DailyBriefSection): string => {
    if (section.id === 'mail') return renderMailSection(document, snapshot.date, section, isBusy);
    if (section.id === 'spending') return renderSpendingSection(section, isBusy);
    const state = dailyBriefStateLabel(section.state);
    return [
      '<section class="daily-section"><div class="daily-section-head"><h2>', escapeHtml(section.title), '</h2>',
      state.length === 0 ? '' : '<span class="daily-state">' + escapeHtml(state) + '</span>', '</div>',
      '<p class="daily-section-message">', escapeHtml(section.message), '</p>',
      '<div class="daily-items">', section.items.map((item: DailyBriefItem): string =>
        renderItem(document, item, isBusy)).join(''), '</div></section>'
    ].join('');
  }).join('');
}

function renderSpendingSection(section: DailyBriefSection, isBusy: boolean): string {
  const state = dailyBriefStateLabel(section.state);
  const bills: [string, string, string][] = [
    ['房租', '¥4,800', '8 月 20 日'], ['水电', '¥236.80', '8 月 18 日'], ['话费', '¥99.00', '8 月 16 日']
  ];
  return [
    '<section class="daily-section daily-spending"><div class="daily-section-head"><h2>消费建议</h2>',
    '<span class="daily-state">', escapeHtml(state.length > 0 ? state : '预算内'),
    '</span></div><p class="daily-section-message">', escapeHtml(section.message),
    '</p><div class="daily-spending-overview"><div class="daily-spending-chart" role="img" ',
    'aria-label="昨日支出：餐饮 68.5 元，出行 32 元，订阅 25 元"><strong>¥125.50</strong><span>昨日支出</span></div>',
    '<div class="daily-spending-legend"><span><i class="food"></i>餐饮 ¥68.50</span>',
    '<span><i class="ride"></i>出行 ¥32.00</span><span><i class="subscription"></i>订阅 ¥25.00</span></div></div>',
    '<div class="daily-bills"><div class="daily-kicker">待确认账单</div>',
    bills.map((bill: [string, string, string], index: number): string => [
      '<article class="daily-bill"><div><b>', bill[0], '</b><span>', bill[1], ' · ', bill[2], ' 前</span></div>',
      '<button type="button" class="daily-button tertiary" data-bill-toggle="', index.toString(), '" aria-expanded="false"',
      isBusy ? ' disabled' : '', '>去缴费</button><div class="daily-bill-panel" data-bill-panel="', index.toString(),
      '"><b>', bill[0], ' ', bill[1], '</b><span>尚未支付。确认后才会进入支付流程，本页不会自动扣款。</span></div></article>'
    ].join('')).join(''), '</div></section>'
  ].join('');
}

function renderMailSection(
  document: HtmlHomeDocument,
  date: string,
  section: DailyBriefSection,
  isBusy: boolean
): string {
  const items = projectDailyBriefMailForDate(date, section.items);
  const message = items.length > 0 ? dailyBriefMailDigest(items) : dailyBriefMailStatus(section.state);
  const list = items.length === 0 ? '' : '<div class="daily-mail-list">' + items.map(
    (item: DailyBriefItem): string => {
      const action = item.action === undefined ? null : actionMatching(document, item.action);
      return [
      '<article class="daily-mail-item"><b class="daily-mail-title">', escapeHtml(item.title),
      '</b><p class="daily-mail-summary">', escapeHtml(item.summary), '</p>',
      action === null ? '' : renderActionButton(action, isBusy, 'tertiary'), '</article>'
      ].join('');
    }
  ).join('') + '</div>';
  return '<section class="daily-section daily-mail-section"><div class="daily-section-head"><h2>' +
    escapeHtml(section.title) + '</h2></div><p class="daily-section-message">' + escapeHtml(message) +
    '</p>' + list + '</section>';
}

function dailyBriefMailStatus(state: DailyBriefSourceState): string {
  if (state === 'needs_auth') return '连接邮箱后查看今日邮件';
  if (state === 'error' || state === 'timeout') return '今日邮件暂不可用';
  return '今天没有邮件';
}

function renderItem(document: HtmlHomeDocument, item: DailyBriefItem, isBusy: boolean): string {
  const action = item.action === undefined ? null : actionMatching(document, item.action);
  return [
    '<article class="daily-item"><div class="daily-meta">', escapeHtml(item.timeLabel), '</div><b>',
    escapeHtml(item.title), '</b><p>', escapeHtml(item.summary), '</p>',
    action === null ? '' : '<div class="daily-item-action">' + renderActionButton(action, isBusy) + '</div>',
    '</article>'
  ].join('');
}

function renderDiscovery(document: HtmlHomeDocument, snapshot: DailyBriefSnapshot, isBusy: boolean): string {
  const completeFeed = actionById(document, 'daily.brief.discovery.open');
  const aggregate = sourceSummary(snapshot, 'waterfall');
  const visible = snapshot.waterfall === null ?
    snapshot.discovery.slice(0, 3) : projectDailyBriefDiscovery(snapshot.waterfall);
  return [
    '<section class="daily-section"><div class="daily-section-head"><h2>为你发现</h2>',
    renderActionButton(completeFeed, isBusy), '</div><p class="daily-section-message">',
    escapeHtml(discoveryStatus(visible.length, aggregate)), '</p><div class="daily-discovery-list">',
    visible.map((item: DailyBriefDiscoveryItem): string =>
      renderDiscoveryItem(item, completeFeed, isBusy, snapshot)).join(''),
    '</div></section>'
  ].join('');
}

function discoveryStatus(count: number, summary: DailyBriefSourceSummary | null): string {
  if (count === 0) return '发现内容暂未生成';
  const partial = summary !== null &&
    (summary.state === 'error' || summary.state === 'timeout' || summary.state === 'needs_auth');
  return '已精选 ' + count.toString() + ' 条' + (partial ? ' · 部分来源稍后补全' : '');
}

function dailyBriefStateLabel(state: DailyBriefSourceState): string {
  if (state === 'success') return '已更新';
  if (state === 'empty') return '暂无数据';
  if (state === 'needs_auth') return '需要授权';
  if (state === 'error') return '暂不可用';
  if (state === 'timeout') return '稍后补全';
  return '';
}

function renderDiscoveryItem(
  item: DailyBriefDiscoveryItem,
  action: HtmlHomeAction | null,
  isBusy: boolean,
  snapshot: DailyBriefSnapshot
): string {
  const host = hostname(item.url);
  const source = host.length > 0 ? item.source + ' · ' + host : item.source;
  const mediaLabel = item.mediaType === 'video' ? '视频' : '讨论';
  const coverUrl = discoveryCoverUrl(snapshot, item);
  const actionLabel = item.mediaType === 'video' ? '进入发现流' : '在 App 内查看';
  const cover = coverUrl.length > 0 ?
    '<div class="daily-discovery-cover"><img src="' + escapeAttribute(coverUrl) + '" alt="' +
      escapeAttribute(item.title + ' 封面') + '" loading="lazy" onerror="this.onerror=null;this.src=\'resource://rawfile/daily/discovery-video-fallback.png\'" />' +
      '<span>视频精华预览</span></div>' : '';
  return [
    '<article class="daily-discovery-card', cover.length === 0 ? ' no-cover' : '', '">', cover,
    '<div><div class="daily-kicker">', escapeHtml(mediaLabel), ' · ', escapeHtml(item.timeBudgetLabel),
    '</div><h3 class="daily-discovery-title">', escapeHtml(item.title),
    '</h3><p class="daily-discovery-summary">', escapeHtml(item.summary),
    '</p><p class="daily-discovery-reason">为你推荐 · ', escapeHtml(item.reason), '</p>',
    '<div class="daily-source-row"><div class="daily-source">', escapeHtml(source), '</div>',
    action === null ? '' : renderActionButton(action, isBusy, 'tertiary', actionLabel), '</div></div></article>'
  ].join('');
}

function discoveryCoverUrl(snapshot: DailyBriefSnapshot, item: DailyBriefDiscoveryItem): string {
  if (item.mediaType === 'video' && snapshot.waterfall === null) {
    return 'resource://rawfile/daily/discovery-video-fallback.png';
  }
  const waterfall = snapshot.waterfall;
  if (waterfall === null) return '';
  const candidates: WaterfallRankedCandidate[] = waterfall.current === null ? [] : [waterfall.current];
  waterfall.stable.forEach((candidate: WaterfallRankedCandidate): void => {
    candidates.push(candidate);
  });
  waterfall.tail.forEach((candidate: WaterfallRankedCandidate): void => {
    candidates.push(candidate);
  });
  waterfall.shown.forEach((candidate: WaterfallRankedCandidate): void => {
    candidates.push(candidate);
  });
  for (let index = 0; index < candidates.length; index += 1) {
    if (candidates[index].id === item.id && candidates[index].mediaType === 'video' &&
      hostname(candidates[index].coverUrl).length > 0) return candidates[index].coverUrl;
  }
  return '';
}

function renderPreference(
  document: HtmlHomeDocument,
  frozen: DailyBriefPreference,
  visible: DailyBriefPreference,
  isBusy: boolean
): string {
  const save = actionById(document, 'daily.brief.preference.save');
  return [
    '<section class="daily-preference"><h2>基于你的偏好</h2><div class="daily-meta">生成时偏好 · ',
    escapeHtml(frozen.timeBudgetMinutes.toString()), ' 分钟 · ', escapeHtml(frozen.language), '</div>',
    '<form id="daily-preference-form" class="daily-form" data-save-action="',
    save === null ? '' : escapeAttribute(actionJson(save)), '">',
    '<label>关注主题<input name="topics" value="', escapeAttribute(visible.topics.join('，')), '" /></label>',
    '<div class="daily-form-grid"><label>语言<select name="language">',
    preferenceOption('中文优先', visible.language), preferenceOption('中英混合', visible.language),
    '</select></label><label>阅读预算（分钟）<input name="timeBudgetMinutes" type="number" min="0" value="',
    escapeAttribute(visible.timeBudgetMinutes.toString()), '" /></label></div>',
    '<label>内容形式<input name="formats" value="', escapeAttribute(visible.formats.join('，')), '" /></label>',
    '<label>减少推荐<textarea name="negativePreference">', escapeHtml(visible.negativePreference), '</textarea></label>',
    '<label>生成时间<input name="targetTime" type="time" value="', escapeAttribute(visible.targetTime), '" /></label>',
    save === null ? '' : '<button type="submit" class="daily-button primary"' + (isBusy ? ' disabled' : '') + '>保存偏好</button>',
    '</form></section>'
  ].join('');
}

function renderActionButton(
  action: HtmlHomeAction | null,
  isBusy: boolean,
  className: string = '',
  visibleLabel: string = '',
  ariaLabel: string = ''
): string {
  if (action === null) {
    return '';
  }
  return '<button type="button" class="daily-button ' + escapeAttribute(className) + '" data-daily-action="' +
    escapeAttribute(actionJson(action)) + '"' + (ariaLabel.length > 0 ? ' aria-label="' + escapeAttribute(ariaLabel) + '"' : '') +
    (isBusy ? ' disabled' : '') + '>' +
    escapeHtml(visibleLabel.length > 0 ? visibleLabel : action.label) + '</button>';
}

function actionById(document: HtmlHomeDocument, id: string): HtmlHomeAction | null {
  for (let index = 0; index < document.actions.length; index += 1) {
    if (document.actions[index].id === id) {
      return document.actions[index];
    }
  }
  return null;
}

function actionMatching(document: HtmlHomeDocument, expected: A2uiAction): HtmlHomeAction | null {
  const expectedArgs = expected.args === undefined ? '' : JSON.stringify(expected.args);
  for (let index = 0; index < document.actions.length; index += 1) {
    const action = document.actions[index];
    const actionArgs = action.args === undefined ? '' : JSON.stringify(action.args);
    if (action.id === expected.id && action.kind === expected.kind && action.prompt === expected.prompt &&
      actionArgs === expectedArgs) {
      return action;
    }
  }
  return null;
}

function historyAction(document: HtmlHomeDocument, direction: string): HtmlHomeAction | null {
  for (let index = 0; index < document.actions.length; index += 1) {
    const action = document.actions[index];
    if (action.id !== 'daily.brief.history.open' || action.args === undefined) {
      continue;
    }
    const args = action.args as DailyBriefActionRecord;
    if (args['direction'] === direction) {
      return action;
    }
  }
  return null;
}

function itemBySource(snapshot: DailyBriefSnapshot, sourceId: DailyBriefSourceId): DailyBriefItem | null {
  for (let sectionIndex = 0; sectionIndex < snapshot.sections.length; sectionIndex += 1) {
    const items = snapshot.sections[sectionIndex].items;
    for (let itemIndex = 0; itemIndex < items.length; itemIndex += 1) {
      if (items[itemIndex].sourceId === sourceId) {
        return items[itemIndex];
      }
    }
  }
  return null;
}

function sectionForSource(snapshot: DailyBriefSnapshot, sourceId: DailyBriefSourceId): DailyBriefSection | null {
  const sectionId = sourceId === 'weather' || sourceId === 'commute' ? 'weather_commute' : sourceId;
  for (let index = 0; index < snapshot.sections.length; index += 1) {
    if (snapshot.sections[index].id === sectionId) {
      return snapshot.sections[index];
    }
  }
  return null;
}

function sourceSummary(snapshot: DailyBriefSnapshot, sourceId: DailyBriefSourceId): DailyBriefSourceSummary | null {
  for (let index = 0; index < snapshot.sources.length; index += 1) {
    if (snapshot.sources[index].sourceId === sourceId) return snapshot.sources[index];
  }
  return null;
}

function itemDetail(item: DailyBriefItem): string {
  const values: string[] = [];
  if (item.timeLabel.length > 0) {
    values.push(item.timeLabel);
  }
  if (item.summary.length > 0) {
    values.push(item.summary);
  }
  return values.join(' · ');
}

function dailyBriefVisibleText(value: string): string {
  return value.split('获取失败').join('暂不可用').split('获取超时').join('稍后补全');
}

function preferenceOption(value: string, selected: string): string {
  return '<option value="' + escapeAttribute(value) + '"' + (value === selected ? ' selected' : '') + '>' +
    escapeHtml(value) + '</option>';
}

function actionJson(action: HtmlHomeAction): string {
  const value: A2uiAction = {
    id: action.id,
    label: action.label,
    prompt: action.prompt,
    variant: action.variant,
    kind: action.kind
  };
  if (action.args !== undefined) {
    value.args = action.args;
  }
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

function hostname(url: string): string {
  const value = url.trim();
  const lower = value.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return '';
  }
  try {
    const parsed = new arkUrl.URL(value);
    if (parsed.hostname.length > 0) {
      return parsed.hostname;
    }
  } catch (error) {
    if (!(error instanceof Error) || error.message.indexOf('URLSearchParams is not defined') < 0) {
      return '';
    }
  }
  // Local Hypium leaves native URL fields empty; real invalid URLs throw before this fallback.
  return hypiumHttpHostname(value);
}

function hypiumHttpHostname(url: string): string {
  const value = url.trim();
  const lower = value.toLowerCase();
  let start = -1;
  if (lower.startsWith('http://')) {
    start = 7;
  } else if (lower.startsWith('https://')) {
    start = 8;
  }
  if (start < 0) {
    return '';
  }
  let end = value.length;
  const delimiters: string[] = ['/', '?', '#'];
  delimiters.forEach((delimiter: string): void => {
    const index = value.indexOf(delimiter, start);
    if (index >= 0 && index < end) {
      end = index;
    }
  });
  const authority = value.substring(start, end);
  const userEnd = authority.lastIndexOf('@');
  const hostPort = authority.substring(userEnd + 1);
  if (hostPort.startsWith('[')) {
    const bracket = hostPort.indexOf(']');
    if (bracket <= 1 || bracket + 1 < hostPort.length && hostPort.charAt(bracket + 1) !== ':' ||
      !isValidPort(hostPort, bracket + 1)) {
      return '';
    }
    return hostPort.substring(0, bracket + 1);
  }
  const port = hostPort.lastIndexOf(':');
  const host = port < 0 ? hostPort : hostPort.substring(0, port);
  if (host.length === 0 || host.indexOf(':') >= 0 || host.indexOf('[') >= 0 || host.indexOf(']') >= 0 ||
    host.indexOf('\\') >= 0 || !isValidPort(hostPort, port)) {
    return '';
  }
  for (let index = 0; index < host.length; index += 1) {
    if (host.charCodeAt(index) <= 32) {
      return '';
    }
  }
  return host;
}

function isValidPort(hostPort: string, colon: number): boolean {
  if (colon < 0 || colon + 1 === hostPort.length) {
    return true;
  }
  const value = hostPort.substring(colon + 1);
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code < 48 || code > 57) {
      return false;
    }
  }
  return Number(value) <= 65535;
}

function dailyBriefScript(): string {
  return `(function(){
  function post(action){
    if(!action||!window.AIPhoneHome||typeof window.AIPhoneHome.postAction!=='function'){return;}
    window.AIPhoneHome.postAction(JSON.stringify(action));
  }
  document.querySelectorAll('[data-daily-action]').forEach(function(button){
    button.addEventListener('click',function(){try{post(JSON.parse(button.getAttribute('data-daily-action')||''));}catch(_error){}});
  });
  document.querySelectorAll('[data-bill-toggle]').forEach(function(button){
    button.addEventListener('click',function(){var id=button.getAttribute('data-bill-toggle');var panel=document.querySelector('[data-bill-panel="'+id+'"]');if(!panel){return;}var visible=panel.classList.toggle('visible');button.setAttribute('aria-expanded',visible?'true':'false');});
  });
  var form=document.getElementById('daily-preference-form');
  if(form){form.addEventListener('submit',function(event){
    event.preventDefault();
    var raw=form.getAttribute('data-save-action')||'';if(!raw){return;}
    try{
      var action=JSON.parse(raw);var fields=new FormData(form);
      var split=function(value){return String(value||'').split(/[，,]/).map(function(item){return item.trim();}).filter(Boolean);};
      action.args={topics:split(fields.get('topics')),language:String(fields.get('language')||''),timeBudgetMinutes:Number(fields.get('timeBudgetMinutes')),formats:split(fields.get('formats')),negativePreference:String(fields.get('negativePreference')||''),targetTime:String(fields.get('targetTime')||'')};
      post(action);
    }catch(_error){}
  });}
})();`;
}

function escapeHtml(value: string): string {
  return value.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtml(value);
}
