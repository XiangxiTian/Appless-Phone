import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiComponent,
  aggregateSearchSearchSourceIds,
  WaterfallFeedState,
  WaterfallRankedCandidate
} from '@loop/agent-core';
import {
  buildDailyBriefFixtureSections,
  createDailyBriefErrorSurface,
  createDailyBriefLoadingSurface,
  createDailyBriefSurface,
  createDailyBriefWaterfallSurface,
  dailyBriefHistoryDirection,
  dailyBriefMailReadRequest,
  dailyBriefMailDigest,
  dailyBriefDate,
  dailyBriefDemoScenario,
  dailyBriefScenarioToolRequest,
  buildDailyBriefFixtureDiscovery,
  dailyBriefWaterfallInput,
  decideDailyBriefOpen,
  defaultDailyBriefPreference,
  normalizeDailyBriefWaterfall,
  projectDailyBriefMailForDate,
  projectDailyBriefDiscovery,
  selectDailyBriefStoredWinnerBeforeSave,
  selectDailyBriefSnapshotAfterSave,
  selectDailyBriefTopThree,
  shouldApplyDailyBriefGeneration
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefCore';
import {
  generateDailyBriefSnapshotIfMissing,
  shouldCatchUpDailyBrief
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefScheduler';
import {
  DailyBriefHighlight,
  DailyBriefHighlightSlot,
  DailyBriefItem,
  DailyBriefDemoScenario,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceId
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefTypes';

interface DailyBriefSurfaceModel {
  dailyBrief: DailyBriefSnapshot;
  dailyBriefPreference: DailyBriefPreference;
}

interface PoisonedDailyBriefPreference extends DailyBriefPreference {
  healthDetail: string;
}

interface PoisonedDailyBriefItem extends DailyBriefItem {
  rawPreview: string;
}

interface PoisonedDailyBriefSection extends DailyBriefSection {
  mailBody: string;
}

interface PoisonedDailyBriefSnapshot extends DailyBriefSnapshot {
  transactionRows: string[];
}

interface PoisonedWaterfallFeedState extends WaterfallFeedState {
  rawPreview: string;
}

interface UnsupportedActionArgs {
  rawPreview: string;
}

function item(
  id: string,
  sourceId: DailyBriefSourceId,
  startsAt: string = '',
  dueAt: string = '',
  leaveBy: string = '',
  needsAction: boolean = false,
  severity: 'none' | 'notice' | 'warn' | 'severe' = 'none',
  completed: boolean = false
): DailyBriefItem {
  return {
    id: id,
    sourceId: sourceId,
    sourceRecordId: id + '-record',
    title: id,
    summary: id + '-summary',
    timeLabel: '',
    startsAt: startsAt,
    dueAt: dueAt,
    leaveBy: leaveBy,
    completed: completed,
    needsAction: needsAction,
    severity: severity
  };
}

function section(
  id: 'today' | 'yesterday' | 'mail' | 'weather_commute' | 'health' | 'spending',
  items: DailyBriefItem[]
): DailyBriefSection {
  return { id: id, title: id, state: 'success', message: '', items: items };
}

function mailAt(sourceRecordId: string, startsAt: string, title: string): DailyBriefItem {
  const value = item(sourceRecordId, 'mail', startsAt);
  value.sourceRecordId = sourceRecordId;
  value.title = title;
  value.summary = title + ' 摘要';
  return value;
}

function rankedCandidate(
  id: string,
  mediaType: 'video' | 'image_text' | 'post',
  normalizedUrl: string,
  titleHits: number,
  duration: string = ''
): WaterfallRankedCandidate {
  return {
    id: id,
    source: id.indexOf('video') >= 0 ? 'youtube' : 'hackernews',
    mediaType: mediaType,
    title: id + ' title',
    summary: id + ' summary',
    url: normalizedUrl,
    coverUrl: '',
    publishedAt: '2026-08-10T00:00:00Z',
    duration: duration,
    originalIndex: 0,
    normalizedUrl: normalizedUrl,
    signals: {
      relevanceTier: titleHits > 0 ? 0 : 2,
      titleHits: titleHits,
      summaryHits: 0,
      freshnessTier: 0
    },
    reason: '查询命中理由'
  };
}

function waterfallState(
  current: WaterfallRankedCandidate | null,
  stable: WaterfallRankedCandidate[],
  tail: WaterfallRankedCandidate[]
): WaterfallFeedState {
  return {
    query: 'HarmonyOS Agent 推荐系统',
    enabledSources: ['youtube', 'hackernews'],
    preferenceDescription: '不参与排序',
    shown: [],
    current: current,
    stable: stable,
    tail: tail,
    sources: []
  };
}

function snapshot(profile: DailyBriefPreference): DailyBriefSnapshot {
  return {
    schemaVersion: 1,
    date: '2026-08-10',
    generatedAt: '2026-08-10T08:31:00+08:00',
    status: 'complete',
    profile: profile,
    topThree: [],
    sections: [],
    discovery: [],
    sources: [],
    waterfall: null,
    actions: []
  };
}

function highlightedItemId(
  values: DailyBriefHighlight[],
  slot: DailyBriefHighlightSlot
): string {
  for (let index = 0; index < values.length; index += 1) {
    if (values[index].slot === slot) {
      return values[index].item.id;
    }
  }
  return '';
}

function poisonedSnapshot(): PoisonedDailyBriefSnapshot {
  const profile = defaultDailyBriefPreference() as PoisonedDailyBriefPreference;
  profile.healthDetail = 'private-health-detail';
  const poisonedItem = item('poisoned-mail', 'mail') as PoisonedDailyBriefItem;
  poisonedItem.rawPreview = 'private-raw-preview';
  const poisonedSection = section('mail', [poisonedItem]) as PoisonedDailyBriefSection;
  poisonedSection.mailBody = 'private-mail-body';
  const value = snapshot(profile) as PoisonedDailyBriefSnapshot;
  value.sections = [poisonedSection];
  value.transactionRows = ['private-transaction-row'];
  return value;
}

function actionWithoutArgs(id: string, label: string): A2uiAction {
  return {
    id: id,
    label: label,
    prompt: label,
    variant: 'secondary',
    kind: 'client'
  };
}

function actionWithArgs(id: string, label: string, args: Object): A2uiAction {
  const value = actionWithoutArgs(id, label);
  value.args = args;
  return value;
}

function runtimeArgs(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function surfaceActions(values: A2uiAction[]): A2uiAction[] {
  const value = snapshot(defaultDailyBriefPreference());
  value.actions = values;
  const model = JSON.parse(createDailyBriefSurface(value).dataModelJson) as DailyBriefSurfaceModel;
  return model.dailyBrief.actions;
}

export default function dailyBriefCoreTest() {
  describe('DailyBriefCore', () => {
    it('puts the earliest objective time in the time constraint slot', 0, () => {
      const sections: DailyBriefSection[] = [section('today', [
        item('late-start', 'todo', '2026-08-10T10:00:00'),
        item('early-deadline', 'todo', '', '2026-08-10T09:15:00'),
        item('middle-departure', 'commute', '', '', '2026-08-10T09:30:00')
      ])];

      const highlights = selectDailyBriefTopThree(sections);

      expect(highlights[0].slot).assertEqual('time_constraint');
      expect(highlights[0].item.id).assertEqual('early-deadline');
    });

    it('compares objective times and action deadlines by epoch across offsets', 0, () => {
      const timeHighlights = selectDailyBriefTopThree([section('today', [
        item('later-instant', 'todo', '2026-08-10T09:00:00+00:00'),
        item('earlier-instant', 'todo', '2026-08-10T16:00:00+08:00')
      ])]);
      const actionHighlights = selectDailyBriefTopThree([section('mail', [
        item('later-action', 'mail', '', '2026-08-10T09:00:00+00:00', '', true),
        item('earlier-action', 'mail', '', '2026-08-10T16:00:00+08:00', '', true)
      ])]);

      expect(highlightedItemId(timeHighlights, 'time_constraint')).assertEqual('earlier-instant');
      expect(highlightedItemId(actionHighlights, 'action_needed')).assertEqual('earlier-action');
    });

    it('keeps time action and status candidates inside their source boundaries', 0, () => {
      const highlights = selectDailyBriefTopThree([
        section('today', [
          item('valid-time', 'todo', '2026-08-10T09:00:00', '', '', false, 'severe'),
          item('invalid-action', 'calendar', '', '2026-08-10T10:00:00', '', true)
        ]),
        section('mail', [item('valid-action', 'mail', '', '2026-08-10T12:00:00', '', true)]),
        section('weather_commute', [item('valid-status', 'weather', '', '', '', false, 'notice')])
      ]);

      expect(highlightedItemId(highlights, 'time_constraint')).assertEqual('valid-time');
      expect(highlightedItemId(highlights, 'action_needed')).assertEqual('valid-action');
      expect(highlightedItemId(highlights, 'status_alert')).assertEqual('valid-status');
    });

    it('uses nearest incomplete deadline then mail yesterday todo fallback for action', 0, () => {
      const deadlineSections: DailyBriefSection[] = [
        section('today', [item('todo-later', 'todo', '', '2026-08-10T18:00:00', '', true)]),
        section('yesterday', [item('yesterday-sooner', 'yesterday', '', '2026-08-10T12:00:00', '', true)]),
        section('mail', [item('mail-completed', 'mail', '', '2026-08-10T10:00:00', '', true, 'none', true)])
      ];
      const fallbackSections: DailyBriefSection[] = [
        section('today', [item('todo-fallback', 'todo', '', '', '', true)]),
        section('yesterday', [item('yesterday-fallback', 'yesterday', '', '', '', true)]),
        section('mail', [item('mail-fallback', 'mail', '', '', '', true)])
      ];
      const withoutMail: DailyBriefSection[] = [
        section('today', [item('todo-only-fallback', 'todo', '', '', '', true)]),
        section('yesterday', [item('yesterday-only-fallback', 'yesterday', '', '', '', true)])
      ];
      const onlyTodo: DailyBriefSection[] = [
        section('today', [item('last-todo-fallback', 'todo', '', '', '', true)])
      ];

      const deadline = selectDailyBriefTopThree(deadlineSections);
      const fallback = selectDailyBriefTopThree(fallbackSections);
      const yesterdayFallback = selectDailyBriefTopThree(withoutMail);
      const todoFallback = selectDailyBriefTopThree(onlyTodo);

      expect(highlightedItemId(deadline, 'action_needed')).assertEqual('yesterday-sooner');
      expect(highlightedItemId(fallback, 'time_constraint')).assertEqual('yesterday-fallback');
      expect(highlightedItemId(fallback, 'action_needed')).assertEqual('mail-fallback');
      expect(highlightedItemId(fallback, 'status_alert')).assertEqual('todo-fallback');
      expect(highlightedItemId(yesterdayFallback, 'action_needed')).assertEqual('yesterday-only-fallback');
      expect(highlightedItemId(todoFallback, 'action_needed')).assertEqual('last-todo-fallback');
    });

    it('uses severity then commute weather health spending for status', 0, () => {
      const severitySections: DailyBriefSection[] = [
        section('weather_commute', [
          item('commute-warn', 'commute', '', '', '', false, 'warn'),
          item('weather-warn', 'weather', '', '', '', false, 'warn')
        ]),
        section('spending', [item('spending-severe', 'spending', '', '', '', false, 'severe')])
      ];
      const sourceSections: DailyBriefSection[] = [
        section('weather_commute', [
          item('weather-notice', 'weather', '', '', '', false, 'notice'),
          item('commute-notice', 'commute', '', '', '', false, 'notice')
        ]),
        section('health', [item('health-notice', 'health', '', '', '', false, 'notice')])
      ];
      const warnBeforeNotice: DailyBriefSection[] = [
        section('weather_commute', [
          item('commute-notice', 'commute', '', '', '', false, 'notice'),
          item('weather-warn', 'weather', '', '', '', false, 'warn')
        ])
      ];
      const weatherBeforeHealth: DailyBriefSection[] = [
        section('weather_commute', [item('weather-notice', 'weather', '', '', '', false, 'notice')]),
        section('health', [item('health-notice', 'health', '', '', '', false, 'notice')]),
        section('spending', [item('spending-notice', 'spending', '', '', '', false, 'notice')])
      ];
      const healthBeforeSpending: DailyBriefSection[] = [
        section('health', [item('health-only-notice', 'health', '', '', '', false, 'notice')]),
        section('spending', [item('spending-only-notice', 'spending', '', '', '', false, 'notice')])
      ];
      const spendingOnly: DailyBriefSection[] = [
        section('spending', [item('last-spending-notice', 'spending', '', '', '', false, 'notice')])
      ];

      const severity = selectDailyBriefTopThree(severitySections);
      const source = selectDailyBriefTopThree(sourceSections);

      expect(highlightedItemId(severity, 'status_alert')).assertEqual('spending-severe');
      expect(highlightedItemId(selectDailyBriefTopThree(warnBeforeNotice), 'status_alert'))
        .assertEqual('weather-warn');
      expect(highlightedItemId(source, 'status_alert')).assertEqual('commute-notice');
      expect(highlightedItemId(
        selectDailyBriefTopThree(weatherBeforeHealth),
        'status_alert'
      )).assertEqual('weather-notice');
      expect(highlightedItemId(
        selectDailyBriefTopThree(healthBeforeSpending),
        'status_alert'
      )).assertEqual('health-only-notice');
      expect(highlightedItemId(selectDailyBriefTopThree(spendingOnly), 'status_alert'))
        .assertEqual('last-spending-notice');
    });

    it('fills a missing slot with the next unused item without duplicate highlights', 0, () => {
      const sections: DailyBriefSection[] = [section('today', [
        item('action-only', 'todo', '', '', '', true),
        item('next-unused', 'todo')
      ])];

      const highlights = selectDailyBriefTopThree(sections);

      expect(highlights.length).assertEqual(2);
      expect(highlights[0].slot).assertEqual('time_constraint');
      expect(highlights[0].item.id).assertEqual('next-unused');
      expect(highlights[1].slot).assertEqual('action_needed');
      expect(highlights[1].item.id).assertEqual('action-only');
      expect(highlights[0].item.id === highlights[1].item.id).assertFalse();
    });

    it('returns fewer than three highlights when fewer real items exist', 0, () => {
      const highlights = selectDailyBriefTopThree([
        section('spending', [item('only-item', 'spending')])
      ]);

      expect(highlights.length).assertEqual(1);
      expect(highlights[0].item.id).assertEqual('only-item');
      expect(highlights[0].slot).assertEqual('time_constraint');
    });

    it('derives every fixture date from the supplied device date', 0, () => {
      const first = buildDailyBriefFixtureSections(new Date('2026-08-10T08:31:00+08:00'));
      const next = buildDailyBriefFixtureSections(new Date('2026-08-11T08:31:00+08:00'));
      const firstText = JSON.stringify(first);
      const nextText = JSON.stringify(next);

      expect(dailyBriefDate(new Date('2026-08-10T08:31:00+08:00'))).assertEqual('2026-08-10');
      expect(first.length).assertEqual(6);
      expect(firstText.indexOf('2026-08-10')).assertLarger(-1);
      expect(firstText.indexOf('2026-08-11')).assertEqual(-1);
      expect(nextText.indexOf('2026-08-11')).assertLarger(-1);
      expect(nextText.indexOf('2026-08-10')).assertLarger(-1);
      expect(nextText.indexOf('2026-08-09')).assertEqual(-1);
      expect(firstText.indexOf('日报体验评审')).assertLarger(-1);
      expect(firstText.indexOf('6 小时 20 分')).assertLarger(-1);
      expect(firstText.indexOf('¥68.50')).assertLarger(-1);
    });

    it('keeps only the newest six unique mails from the supplied device date', 0, () => {
      const values: DailyBriefItem[] = [
        mailAt('gmail:m0', '2026-08-10T15:59:59Z', '前一天'),
        mailAt('gmail:m1', '2026-08-10T16:00:00Z', '当天零点'),
        mailAt('qq:101', '2026-08-11T09:00:00+08:00', 'QQ 上午'),
        mailAt('gmail:m2', '2026-08-11T10:00:00+08:00', 'Gmail 上午'),
        mailAt('outlook:m3', '2026-08-11T11:00:00+08:00', 'Outlook 上午'),
        mailAt('gmail:m4', '2026-08-11T12:00:00+08:00', '主题四'),
        mailAt('qq:102', '2026-08-11T13:00:00+08:00', '主题五'),
        mailAt('gmail:m5', '2026-08-11T14:00:00+08:00', '主题六'),
        mailAt('gmail:m6', '2026-08-11T15:00:00+08:00', '主题七'),
        mailAt('gmail:m6', '2026-08-11T15:00:00+08:00', '重复记录'),
        mailAt('gmail:bad', 'not-a-date', '日期不可信'),
        mailAt('gmail:next', '2026-08-11T16:00:00Z', '次日零点')
      ];

      const projected: DailyBriefItem[] = projectDailyBriefMailForDate('2026-08-11', values);

      expect(projected.length).assertEqual(6);
      expect(projected[0].title).assertEqual('主题七');
      expect(projected[5].title).assertEqual('Gmail 上午');
      expect(JSON.stringify(projected).indexOf('前一天')).assertEqual(-1);
      expect(JSON.stringify(projected).indexOf('次日零点')).assertEqual(-1);
      expect(JSON.stringify(projected).indexOf('日期不可信')).assertEqual(-1);
      expect(JSON.stringify(projected).indexOf('重复记录')).assertEqual(-1);
    });

    it('summarizes the projected mail count and topics in at most ninety visible characters', 0, () => {
      const values: DailyBriefItem[] = [
        mailAt('gmail:m1', '2026-08-11T08:00:00+08:00', '掌控您的 Google 账号数据'),
        mailAt('qq:m2', '2026-08-11T09:00:00+08:00', 'AI 投资日报'),
        mailAt('gmail:m3', '2026-08-11T10:00:00+08:00', 'AI 产品日报'),
        mailAt('qq:m4', '2026-08-11T11:00:00+08:00', '这是一封标题非常长并且不应该让日报总结无限增长的邮件通知')
      ];

      const empty: DailyBriefItem[] = [];
      const digest: string = dailyBriefMailDigest(values);
      const digestCharacters: string[] = Array.from(digest);

      expect(dailyBriefMailDigest(empty)).assertEqual('今天没有邮件');
      expect(digest.indexOf('今天共 4 封邮件')).assertEqual(0);
      expect(digest.indexOf('掌控您的 Google 账号数据')).assertLarger(-1);
      expect(digest.indexOf('AI 投资日报')).assertLarger(-1);
      expect(digest.indexOf('AI 产品日报')).assertLarger(-1);
      expect(digestCharacters.length <= 90).assertTrue();
    });

    it('selects the deterministic fixture Top 3 end to end', 0, () => {
      const highlights = selectDailyBriefTopThree(
        buildDailyBriefFixtureSections(new Date('2026-08-10T08:31:00+08:00'))
      );

      expect(highlights.length).assertEqual(3);
      expect(highlightedItemId(highlights, 'time_constraint')).assertEqual('fixture-commute');
      expect(highlightedItemId(highlights, 'action_needed')).assertEqual('fixture-waterfall-follow-up');
      expect(highlightedItemId(highlights, 'status_alert')).assertEqual('fixture-weather-rain');
    });

    it('projects current stable tail order with id and normalized URL dedupe and cap', 0, () => {
      const current = rankedCandidate('current-post', 'post', 'https://example.com/a', 1);
      const sameUrl = rankedCandidate('same-url', 'post', 'https://example.com/a', 0);
      const stable = rankedCandidate('stable-image', 'image_text', 'https://example.com/b', 0);
      const sameId = rankedCandidate('stable-image', 'post', 'https://example.com/c', 1);
      const tail = rankedCandidate('tail-video', 'video', 'https://example.com/d', 0, '08:42');
      const extra = rankedCandidate('extra', 'post', 'https://example.com/e', 1);

      const result = projectDailyBriefDiscovery(waterfallState(
        current,
        [sameUrl, stable],
        [sameId, tail, extra]
      ));

      expect(result.length).assertEqual(3);
      expect(result[0].id).assertEqual('current-post');
      expect(result[1].id).assertEqual('stable-image');
      expect(result[2].id).assertEqual('tail-video');
      expect(result[0].reason).assertEqual('查询命中理由');
      expect(result[1].reason).assertEqual('来自 hackernews 的内容');
      expect(result[0].timeBudgetLabel).assertEqual('3 分钟');
      expect(result[1].timeBudgetLabel).assertEqual('5 分钟');
      expect(result[2].timeBudgetLabel).assertEqual('08:42');
    });

    it('backfills a ranked video when the first three discoveries are discussions', 0, () => {
      const first = rankedCandidate('post-first', 'post', 'https://example.com/first', 1);
      const second = rankedCandidate('post-second', 'post', 'https://example.com/second', 1);
      const third = rankedCandidate('post-third', 'post', 'https://example.com/third', 1);
      const video = rankedCandidate('video-fourth', 'video', 'https://example.com/video', 1, '09:24');

      const result = projectDailyBriefDiscovery(waterfallState(first, [second, third], [video]));

      expect(result.length).assertEqual(3);
      expect(result[0].id).assertEqual('post-first');
      expect(result[2].id).assertEqual('video-fourth');
    });

    it('keeps shown discoveries as the lowest priority frozen snapshot fallback', 0, () => {
      const state = waterfallState(null, [], []);
      state.shown = [rankedCandidate('shown-video', 'video', 'https://example.com/shown', 1, '06:10')];

      const result = projectDailyBriefDiscovery(state);

      expect(result.length).assertEqual(1);
      expect(result[0].id).assertEqual('shown-video');
    });

    it('preserves only safe direct video media URLs in frozen Waterfall snapshots', 0, () => {
      const directVideo = rankedCandidate('reddit-video', 'video', 'https://reddit.com/r/demo', 1, '01:20');
      directVideo.source = 'reddit';
      directVideo.mediaUrl = 'https://v.redd.it/demo/DASH_720.mp4';
      const unsafeVideo = rankedCandidate('unsafe-video', 'video', 'https://example.com/video', 1, '01:20');
      unsafeVideo.mediaUrl = 'javascript:alert(1)';
      const hostlessVideo = rankedCandidate('hostless-video', 'video', 'https://example.com/hostless', 1, '01:20');
      hostlessVideo.mediaUrl = 'https://';

      const safe = normalizeDailyBriefWaterfall(waterfallState(directVideo, [], []));
      const unsafe = normalizeDailyBriefWaterfall(waterfallState(unsafeVideo, [], []));
      const hostless = normalizeDailyBriefWaterfall(waterfallState(hostlessVideo, [], []));

      expect(safe?.current?.mediaUrl ?? '').assertEqual('https://v.redd.it/demo/DASH_720.mp4');
      expect(unsafe?.current?.mediaUrl ?? '').assertEqual('');
      expect(hostless?.current?.mediaUrl ?? '').assertEqual('');
    });

    it('maps adjacent dates to bounded office and airport scenarios', 0, () => {
      const office: DailyBriefDemoScenario = dailyBriefDemoScenario('2026-08-13');
      const airport: DailyBriefDemoScenario = dailyBriefDemoScenario('2026-08-12');

      expect(office.routeLabel).assertEqual('秋港花园 → 坂田华为基地 D 区');
      expect(office.origin).assertEqual('秋港花园');
      expect(office.originLongitude).assertEqual(114.075434);
      expect(office.originLatitude).assertEqual(22.668739);
      expect(office.destination).assertEqual('坂田华为基地 D 区');
      expect(office.destinationLongitude).assertEqual(114.057457);
      expect(office.destinationLatitude).assertEqual(22.643890);
      expect(airport.routeLabel).assertEqual('秋港花园 → 深圳宝安机场');
      expect(airport.preferredVehicle).assertEqual('六座舒适型');
    });

    it('builds exact real route and ride requests from the frozen daily scenario', 0, () => {
      const route = dailyBriefScenarioToolRequest('daily.brief.route.open', '2026-08-13');
      const ride = dailyBriefScenarioToolRequest('daily.brief.ride.estimate', '2026-08-13');

      expect(route?.toolId ?? '').assertEqual('maps.route.open');
      expect(JSON.stringify(route?.args)).assertEqual(
        '{"origin":"秋港花园","destination":"坂田华为基地 D 区","travelMode":"driving","navigate":true}'
      );
      expect(ride?.toolId ?? '').assertEqual('ride.estimate');
      expect(JSON.stringify(ride?.args)).assertEqual(
        '{"origin":"秋港花园","destination":"坂田华为基地 D 区","city":"深圳"}'
      );
      expect(dailyBriefScenarioToolRequest('daily.brief.unknown', '2026-08-13')).assertNull();
    });

    it('fills empty provider sections with useful bounded daily fixtures', 0, () => {
      const sections = buildDailyBriefFixtureSections(new Date('2026-08-13T08:31:00+08:00'));
      const today = sections.find((value: DailyBriefSection): boolean => value.id === 'today');
      const mail = sections.find((value: DailyBriefSection): boolean => value.id === 'mail');
      const spending = sections.find((value: DailyBriefSection): boolean => value.id === 'spending');

      expect(today?.items.length ?? 0).assertLarger(1);
      expect(mail?.items.length ?? 0).assertLarger(2);
      expect(spending?.items.length ?? 0).assertLarger(2);
      expect(mail?.items.every((value: DailyBriefItem): boolean => value.action === undefined) ?? false).assertTrue();
    });

    it('provides a bounded frozen discovery fallback with video and discussion', 0, () => {
      const values = buildDailyBriefFixtureDiscovery('2026-08-13');

      expect(values.length).assertEqual(3);
      expect(values.some((value) => value.mediaType === 'video')).assertTrue();
      expect(values.some((value) => value.mediaType === 'post')).assertTrue();
    });

    it('uses unknown duration only when a video provider omitted it', 0, () => {
      const result = projectDailyBriefDiscovery(waterfallState(
        rankedCandidate('video-unknown', 'video', 'https://example.com/video', 0),
        [],
        []
      ));

      expect(result[0].timeBudgetLabel).assertEqual('时长未知');
    });

    it('builds visible preference input without reordering Waterfall output', 0, () => {
      const preference = defaultDailyBriefPreference();
      const input = dailyBriefWaterfallInput(preference, '个人日报 Demo');
      const first = rankedCandidate('first', 'post', 'https://example.com/first', 0);
      const second = rankedCandidate('second', 'post', 'https://example.com/second', 1);
      const projected = projectDailyBriefDiscovery(waterfallState(first, [second], []));

      expect(input.query).assertEqual('AI 产品 HarmonyOS Agent 推荐系统 个人日报 Demo');
      expect(input.sources.join(',')).assertEqual(aggregateSearchSearchSourceIds().join(','));
      expect(input.preferenceDescription).assertEqual(
        '中文优先；15 分钟内；图文 > 短视频 > 长视频；降低重复内容和只有热度、缺少信息量的内容'
      );
      expect(projected[0].id).assertEqual('first');
      expect(projected[1].id).assertEqual('second');
    });

    it('shows newer editable preference without mutating frozen snapshot profile', 0, () => {
      const frozen = defaultDailyBriefPreference();
      const current = defaultDailyBriefPreference();
      current.timeBudgetMinutes = 5;
      const value = snapshot(frozen);

      const surface = createDailyBriefSurface(value, current);
      const model = JSON.parse(surface.dataModelJson) as DailyBriefSurfaceModel;

      expect(surface.intent).assertEqual('daily-brief');
      expect(model.dailyBrief.profile.timeBudgetMinutes).assertEqual(15);
      expect(model.dailyBriefPreference.timeBudgetMinutes).assertEqual(5);
      expect(value.profile.timeBudgetMinutes).assertEqual(15);
    });

    it('upgrades legacy fixture sections and discovery at the display boundary', 0, () => {
      const value = snapshot(defaultDailyBriefPreference());
      const legacyToday = buildDailyBriefFixtureSections(new Date('2026-08-10T08:31:00+08:00'))[0];
      legacyToday.items = [item('fixture-demo-review', 'todo', '2026-08-10T09:30:00')];
      legacyToday.items[0].title = '个人日报 Demo 评审';
      legacyToday.items[0].summary = '与林然确认演示流程和关键结论';
      const emptyMail = section('mail', []);
      emptyMail.state = 'empty';
      emptyMail.message = '今日邮件暂不可用';
      const realYesterday = section('yesterday', [item('real-provider-item', 'yesterday')]);
      const legacyHealth = section('health', [item('fixture-sleep', 'health')]);
      legacyHealth.state = 'fixture';
      legacyHealth.message = '演示健康摘要';
      const legacySpendingItem = item('fixture-spending', 'spending');
      legacySpendingItem.title = '昨日消费 ¥86.40';
      const legacySpending = section('spending', [legacySpendingItem]);
      legacySpending.state = 'fixture';
      legacySpending.message = '演示消费摘要';
      value.sections = [legacyToday, realYesterday, emptyMail, legacyHealth, legacySpending];
      value.topThree = [{ slot: 'time_constraint', item: legacySpendingItem }];
      value.waterfall = waterfallState(null, [], []);

      const model = JSON.parse(createDailyBriefSurface(value).dataModelJson) as DailyBriefSurfaceModel;
      const serialized = JSON.stringify(model.dailyBrief);

      expect(serialized.indexOf('个人日报 Demo 评审')).assertEqual(-1);
      expect(serialized.indexOf('晨间专注时间')).assertEqual(-1);
      expect(serialized.indexOf('日报界面评审反馈')).assertEqual(-1);
      expect(serialized.indexOf('重新生成以读取真实日历')).assertLarger(-1);
      expect(serialized.indexOf('重新生成以读取真实邮件')).assertLarger(-1);
      expect(serialized.indexOf('今日健康摘要')).assertLarger(-1);
      expect(serialized.indexOf('昨日支出 ¥125.50')).assertLarger(-1);
      expect(serialized.indexOf('餐饮 ¥68.50')).assertLarger(-1);
      expect(serialized.indexOf('演示')).assertEqual(-1);
      expect(serialized.indexOf('昨日消费 ¥86.40')).assertEqual(-1);
      expect(serialized.indexOf('fixture-video-2026-08-10')).assertLarger(-1);
      expect(serialized.indexOf('real-provider-item')).assertLarger(-1);
      expect(serialized.indexOf('daily.brief.discovery.open')).assertLarger(-1);
      const discoverySurface = createDailyBriefWaterfallSurface(value);
      expect(discoverySurface === null).assertFalse();
      expect((discoverySurface?.dataModelJson ?? '').indexOf('fixture-video-2026-08-10')).assertLarger(-1);
      expect((discoverySurface?.dataModelJson ?? '').indexOf('"videos":[{')).assertLarger(-1);
      expect((discoverySurface?.dataModelJson ?? '').indexOf('"posts":[{')).assertLarger(-1);
      expect(value.discovery.length).assertEqual(0);
      expect(value.sections[0].items[0].title).assertEqual('个人日报 Demo 评审');
    });

    it('keeps real Calendar and mail items beside legacy fixture content', 0, () => {
      const value = snapshot(defaultDailyBriefPreference());
      const calendar = section('today', [
        item('fixture-demo-review', 'todo', '2026-08-10T08:30:00+08:00'),
        item('calendar-real', 'calendar', '2026-08-10T09:30:00+08:00')
      ]);
      calendar.state = 'success';
      const mail = section('mail', [item('mail-real', 'mail', '2026-08-10T08:30:00+08:00')]);
      mail.state = 'success';
      value.sections = [calendar, mail];

      const serialized = createDailyBriefSurface(value).dataModelJson;

      expect(serialized.indexOf('calendar-real')).assertLarger(-1);
      expect(serialized.indexOf('mail-real')).assertLarger(-1);
      expect(serialized.indexOf('重新生成以读取真实日历')).assertEqual(-1);
      expect(serialized.indexOf('重新生成以读取真实邮件')).assertEqual(-1);
    });

    it('keeps date and real error text on daily brief loading and error surfaces', 0, () => {
      const loading = createDailyBriefLoadingSurface('2026-08-10');
      const failed = createDailyBriefErrorSurface('2026-08-10', 'mail provider timeout');

      expect(loading.intent).assertEqual('daily-brief');
      expect(loading.status).assertEqual('thinking');
      expect(loading.dataModelJson.indexOf('2026-08-10')).assertLarger(-1);
      expect(failed.intent).assertEqual('daily-brief');
      expect(failed.error).assertEqual('mail provider timeout');
      expect(failed.dataModelJson.indexOf('2026-08-10')).assertLarger(-1);
      expect(failed.dataModelJson.indexOf('mail provider timeout')).assertLarger(-1);
    });

    it('serializes only normalized snapshot fields and no raw sensitive detail keys', 0, () => {
      const surface = createDailyBriefSurface(poisonedSnapshot());
      const serialized = surface.dataModelJson;

      expect(serialized.indexOf('rawPreview')).assertEqual(-1);
      expect(serialized.indexOf('mailBody')).assertEqual(-1);
      expect(serialized.indexOf('healthDetail')).assertEqual(-1);
      expect(serialized.indexOf('transactionRows')).assertEqual(-1);
    });

    it('normalizes the frozen Waterfall before serializing the full feed surface', 0, () => {
      const state = waterfallState(
        rankedCandidate('current-post', 'post', 'https://example.com/a', 1),
        [],
        []
      ) as PoisonedWaterfallFeedState;
      state.rawPreview = 'private-waterfall-preview';
      const value = snapshot(defaultDailyBriefPreference());
      value.waterfall = state;

      const surface = createDailyBriefWaterfallSurface(value);
      const components: A2uiComponent[] = surface === null ? [] : surface.components;
      const root = components[0];

      expect(surface === null).assertFalse();
      expect((surface?.dataModelJson ?? '').indexOf('rawPreview')).assertEqual(-1);
      expect(root.actions?.length ?? 0).assertEqual(1);
      expect(root.actions?.[0].id ?? '').assertEqual('daily.brief.open');
      expect(root.actions?.[0].label ?? '').assertEqual('返回日报');
      expect(JSON.stringify(root.actions?.[0].args)).assertEqual('{"regenerate":false}');
    });

    it('builds a usable full discovery surface from frozen fallback discovery', 0, () => {
      const value = snapshot(defaultDailyBriefPreference());
      value.waterfall = null;
      value.discovery = buildDailyBriefFixtureDiscovery(value.date);

      const surface = createDailyBriefWaterfallSurface(value);
      const serialized = surface?.dataModelJson ?? '';

      expect(surface === null).assertFalse();
      expect(serialized.indexOf('fixture-video-' + value.date)).assertLarger(-1);
      expect(serialized.indexOf('fixture-discussion-' + value.date)).assertLarger(-1);
      expect(serialized.indexOf('resource://rawfile/daily/discovery-video-fallback.png')).assertLarger(-1);
    });

    it('keeps regenerate and discovery actions only when args are absent', 0, () => {
      const actions = surfaceActions([
        actionWithoutArgs('daily.brief.regenerate', 'valid-regenerate'),
        actionWithArgs('daily.brief.regenerate', 'invalid-regenerate-object', runtimeArgs('{}')),
        actionWithArgs('daily.brief.regenerate', 'invalid-regenerate-null', runtimeArgs('null')),
        actionWithoutArgs('daily.brief.discovery.open', 'valid-discovery'),
        actionWithArgs('daily.brief.discovery.open', 'invalid-discovery-object', runtimeArgs('{}')),
        actionWithArgs('daily.brief.discovery.open', 'invalid-discovery-null', runtimeArgs('null'))
      ]);

      expect(actions.length).assertEqual(2);
      expect(actions[0].label).assertEqual('valid-regenerate');
      expect(actions[1].label).assertEqual('valid-discovery');
    });

    it('keeps only runtime-valid preference save args with exact fields', 0, () => {
      const valid = runtimeArgs('{"topics":["AI 产品","Agent"],"language":"中文优先",' +
        '"timeBudgetMinutes":15,"formats":["图文","短视频"],' +
        '"negativePreference":"减少重复","targetTime":"08:30"}');
      const actions = surfaceActions([
        actionWithArgs('daily.brief.preference.save', 'valid-preference', valid),
        actionWithArgs('daily.brief.preference.save', 'nested-topic', runtimeArgs('{"topics":[{"rawPreview":"private"}],"language":"中文优先","timeBudgetMinutes":15,"formats":["图文"],"negativePreference":"减少重复","targetTime":"08:30"}')),
        actionWithArgs('daily.brief.preference.save', 'object-language', runtimeArgs('{"topics":["AI 产品"],"language":{"healthDetail":"private"},"timeBudgetMinutes":15,"formats":["图文"],"negativePreference":"减少重复","targetTime":"08:30"}')),
        actionWithArgs('daily.brief.preference.save', 'forbidden-key', runtimeArgs('{"topics":["AI 产品"],"language":"中文优先","timeBudgetMinutes":15,"formats":["图文"],"negativePreference":"减少重复","targetTime":"08:30","rawPreview":"private"}')),
        actionWithArgs('daily.brief.preference.save', 'array-preference', runtimeArgs('[]'))
      ]);

      expect(actions.length).assertEqual(1);
      expect(actions[0].label).assertEqual('valid-preference');
      expect(JSON.stringify(actions[0].args)).assertEqual(JSON.stringify(valid));
    });

    it('omits null preference args without throwing at the surface boundary', 0, () => {
      const actions = surfaceActions([
        actionWithArgs('daily.brief.preference.save', 'null-preference', runtimeArgs('null'))
      ]);

      expect(actions.length).assertEqual(0);
    });

    it('omits primitive preference args without throwing at the surface boundary', 0, () => {
      const actions = surfaceActions([
        actionWithArgs('daily.brief.preference.save', 'primitive-preference', runtimeArgs('"private"'))
      ]);

      expect(actions.length).assertEqual(0);
    });

    it('keeps only exact history directions with primitive runtime values', 0, () => {
      const actions = surfaceActions([
        actionWithArgs('daily.brief.history.open', 'previous', runtimeArgs('{"direction":"previous"}')),
        actionWithArgs('daily.brief.history.open', 'today', runtimeArgs('{"direction":"today"}')),
        actionWithArgs('daily.brief.history.open', 'next', runtimeArgs('{"direction":"next"}')),
        actionWithArgs('daily.brief.history.open', 'missing-direction', runtimeArgs('{}')),
        actionWithArgs('daily.brief.history.open', 'invalid-direction', runtimeArgs('{"direction":"later"}')),
        actionWithArgs('daily.brief.history.open', 'object-direction', runtimeArgs('{"direction":{"mailBody":"private"}}')),
        actionWithArgs('daily.brief.history.open', 'extra-history-key', runtimeArgs('{"direction":"today","rawPreview":"private"}')),
        actionWithArgs('daily.brief.history.open', 'null-history', runtimeArgs('null'))
      ]);

      expect(actions.length).assertEqual(3);
      expect(actions[0].label).assertEqual('previous');
      expect(actions[1].label).assertEqual('today');
      expect(actions[2].label).assertEqual('next');
    });

    it('keeps mail read only with primitive strings and a complete provider identity', 0, () => {
      const actions = surfaceActions([
        actionWithArgs('daily.brief.mail.read', 'valid-mail', runtimeArgs('{"provider":"gmail","threadId":"thread-1","messageId":"message-1","requestKey":"request-1"}')),
        actionWithArgs('daily.brief.mail.read', 'missing-provider', runtimeArgs('{"threadId":"thread-1","messageId":"","requestKey":"request-1"}')),
        actionWithArgs('daily.brief.mail.read', 'missing-identity', runtimeArgs('{"provider":"gmail","threadId":"","messageId":"","requestKey":"request-1"}')),
        actionWithArgs('daily.brief.mail.read', 'nested-provider', runtimeArgs('{"provider":{"healthDetail":"private"},"threadId":"thread-1","messageId":"","requestKey":"request-1"}')),
        actionWithArgs('daily.brief.mail.read', 'nested-thread', runtimeArgs('{"provider":"gmail","threadId":{"mailBody":"private"},"messageId":"","requestKey":"request-1"}')),
        actionWithArgs('daily.brief.mail.read', 'forbidden-mail-key', runtimeArgs('{"provider":"gmail","threadId":"thread-1","messageId":"","requestKey":"request-1","transactionRows":["private"]}')),
        actionWithArgs('daily.brief.mail.read', 'primitive-mail', runtimeArgs('"private"')),
        actionWithArgs('daily.brief.mail.read', 'null-mail', runtimeArgs('null'))
      ]);

      expect(actions.length).assertEqual(1);
      expect(actions[0].label).assertEqual('valid-mail');
      expect(JSON.stringify(actions[0].args)).assertEqual(
        '{"provider":"gmail","threadId":"thread-1","messageId":"message-1","requestKey":"request-1"}'
      );
    });

    it('omits unsupported snapshot actions instead of dropping their args', 0, () => {
      const value = snapshot(defaultDailyBriefPreference());
      const unsupportedArgs: UnsupportedActionArgs = { rawPreview: 'private-action-preview' };
      const actions: A2uiAction[] = [
        {
          id: 'daily.brief.regenerate',
          label: 'Regenerate',
          prompt: 'Regenerate',
          variant: 'primary',
          kind: 'client'
        },
        {
          id: 'custom.action',
          label: 'Custom unsupported action',
          prompt: 'Custom unsupported action',
          variant: 'secondary',
          kind: 'client',
          args: unsupportedArgs
        }
      ];
      value.actions = actions;

      const serialized = createDailyBriefSurface(value).dataModelJson;

      expect(serialized.indexOf('daily.brief.regenerate')).assertLarger(-1);
      expect(serialized.indexOf('custom.action')).assertEqual(-1);
      expect(serialized.indexOf('Custom unsupported action')).assertEqual(-1);
    });

    it('decides open generate and explicit regeneration from frozen snapshot presence', 0, () => {
      const existing = snapshot(defaultDailyBriefPreference());

      expect(decideDailyBriefOpen(existing, false)).assertEqual('open_existing');
      expect(decideDailyBriefOpen(null, false)).assertEqual('generate_first');
      expect(decideDailyBriefOpen(existing, true)).assertEqual('regenerate');
      expect(decideDailyBriefOpen(null, true)).assertEqual('regenerate');
    });

    it('keeps the old snapshot until the current generated snapshot is saved', 0, () => {
      const oldSnapshot = snapshot(defaultDailyBriefPreference());
      oldSnapshot.generatedAt = '2026-08-10T08:31:00+08:00';
      const generated = snapshot(defaultDailyBriefPreference());
      generated.generatedAt = '2026-08-10T09:00:00+08:00';

      expect(selectDailyBriefSnapshotAfterSave(oldSnapshot, generated, false)?.generatedAt)
        .assertEqual(oldSnapshot.generatedAt);
      expect(selectDailyBriefSnapshotAfterSave(oldSnapshot, generated, true)?.generatedAt)
        .assertEqual(generated.generatedAt);
      expect(selectDailyBriefSnapshotAfterSave(null, generated, false)).assertNull();
      expect(shouldApplyDailyBriefGeneration(4, 5)).assertFalse();
      expect(shouldApplyDailyBriefGeneration(5, 5)).assertTrue();
    });

    it('selects a snapshot written during first generation as the non-regenerate winner', 0, () => {
      const storedDuringGeneration = snapshot(defaultDailyBriefPreference());
      storedDuringGeneration.generatedAt = '2026-08-10T08:31:30+08:00';

      expect(selectDailyBriefStoredWinnerBeforeSave(storedDuringGeneration, false)?.generatedAt)
        .assertEqual('2026-08-10T08:31:30+08:00');
      expect(selectDailyBriefStoredWinnerBeforeSave(storedDuringGeneration, true)).assertNull();
      expect(selectDailyBriefStoredWinnerBeforeSave(null, false)).assertNull();
    });

    it('limits history direction and mail reads to stored finite identities', 0, () => {
      expect(dailyBriefHistoryDirection(runtimeArgs('{"direction":"previous"}')))
        .assertEqual('previous');
      expect(dailyBriefHistoryDirection(runtimeArgs('{"direction":"today"}')))
        .assertEqual('today');
      expect(dailyBriefHistoryDirection(runtimeArgs('{"direction":"next"}')))
        .assertEqual('next');
      expect(dailyBriefHistoryDirection(runtimeArgs('{"direction":"later"}'))).assertNull();
      expect(dailyBriefHistoryDirection(runtimeArgs('{"direction":"today","url":"https://example.com"}')))
        .assertNull();

      const gmail = dailyBriefMailReadRequest(runtimeArgs(
        '{"provider":"gmail","threadId":"thread-1","messageId":"message-1","requestKey":"gmail:thread-1"}'
      ));
      const qq = dailyBriefMailReadRequest(runtimeArgs(
        '{"provider":"qq","threadId":"","messageId":"12345","requestKey":"qq:12345"}'
      ));
      expect(gmail?.toolId).assertEqual('gmail.thread.read');
      expect(qq?.toolId).assertEqual('mail.thread.read');
      expect(JSON.stringify(gmail?.args)).assertEqual(
        '{"provider":"gmail","threadId":"thread-1","messageId":"message-1","requestKey":"gmail:thread-1"}'
      );
      expect(dailyBriefMailReadRequest(runtimeArgs(
        '{"provider":"outlook","threadId":"thread-1","messageId":"message-1","requestKey":"outlook:thread-1"}'
      ))).assertNull();
      expect(dailyBriefMailReadRequest(runtimeArgs(
        '{"provider":"qq","threadId":"","messageId":"abc","requestKey":"qq:abc"}'
      ))).assertNull();
    });

    it('builds the full discovery surface only from the frozen Waterfall state', 0, () => {
      const value = snapshot(defaultDailyBriefPreference());
      value.discovery = [{
        id: 'projected-only',
        source: 'forged',
        mediaType: 'post',
        title: 'must not drive full feed',
        summary: '',
        url: 'https://example.com/projected',
        reason: '',
        timeBudgetLabel: '3 分钟'
      }];
      value.waterfall = waterfallState(
        rankedCandidate('frozen-current-post', 'post', 'https://example.com/frozen', 1),
        [],
        []
      );

      const serialized = createDailyBriefWaterfallSurface(value)?.dataModelJson ?? '';
      expect(serialized.indexOf('frozen-current-post')).assertLarger(-1);
      expect(serialized.indexOf('projected-only')).assertEqual(-1);
    });

    it('uses the Task 6 catch-up predicate and never replaces an existing date', 0, async () => {
      const now = new Date('2026-08-10T09:00:00+08:00');
      let persisted: DailyBriefSnapshot | null = snapshot(defaultDailyBriefPreference());
      let generated = 0;

      expect(shouldCatchUpDailyBrief(now, '08:30', persisted !== null)).assertFalse();
      const saved = await generateDailyBriefSnapshotIfMissing(
        '2026-08-10',
        (_date: string): DailyBriefSnapshot | null => persisted,
        async (): Promise<DailyBriefSnapshot> => {
          generated += 1;
          return snapshot(defaultDailyBriefPreference());
        },
        (next: DailyBriefSnapshot): boolean => {
          persisted = next;
          return true;
        }
      );

      expect(saved).assertFalse();
      expect(generated).assertEqual(0);
      expect((persisted as DailyBriefSnapshot).generatedAt)
        .assertEqual('2026-08-10T08:31:00+08:00');
    });
  });
}
