import {
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  aggregateSearchSearchSourceIds,
  AggregateSearchPost,
  AggregateSearchResult,
  AggregateSearchSource,
  AggregateSearchVideo,
  WaterfallContinuation,
  WaterfallFeedState,
  WaterfallRankedCandidate,
  WaterfallSourceState
} from '@loop/agent-core';
import {
  DailyBriefDiscoveryItem,
  DailyBriefDemoScenario,
  DailyBriefHighlight,
  DailyBriefHighlightSlot,
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSeverity,
  DailyBriefSnapshot,
  DailyBriefSourceId,
  DailyBriefSourceSummary
} from './DailyBriefTypes';

interface DailyBriefSurfaceModel {
  dailyBrief: DailyBriefSnapshot;
  dailyBriefPreference: DailyBriefPreference;
}

interface DailyBriefPendingModel {
  dailyBriefDate: string;
  dailyBriefMessage: string;
}

interface DailyBriefErrorModel {
  dailyBriefDate: string;
  dailyBriefError: string;
}

interface DailyBriefWaterfallModel {
  aggregateSearch: AggregateSearchResult;
}

interface DailyBriefWaterfallCards {
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
}

interface DailyBriefWaterfallInput {
  query: string;
  sources: string[];
  preferenceDescription: string;
}

interface DailyBriefHistoryArgs {
  direction: 'previous' | 'today' | 'next';
}

interface DailyBriefOpenArgs {
  regenerate: boolean;
}

interface DailyBriefMailArgs {
  provider: string;
  threadId: string;
  messageId: string;
  requestKey: string;
}

interface DailyBriefRouteArgs {
  origin: string;
  destination: string;
  travelMode: string;
  navigate: boolean;
}

interface DailyBriefRideArgs {
  origin: string;
  destination: string;
  city: string;
}

export type DailyBriefOpenDecision = 'open_existing' | 'generate_first' | 'regenerate';
export type DailyBriefHistoryDirection = 'previous' | 'today' | 'next';

export interface DailyBriefMailReadRequest {
  toolId: string;
  args: Object;
}

export interface DailyBriefScenarioToolRequest {
  toolId: string;
  args: Object;
}

type DailyBriefActionValue = Object | string | number | boolean | null | undefined;
type DailyBriefActionRecord = Record<string, DailyBriefActionValue>;

const HIGHLIGHT_SLOTS: DailyBriefHighlightSlot[] = [
  'time_constraint',
  'action_needed',
  'status_alert'
];

const WATERFALL_SOURCES: string[] = aggregateSearchSearchSourceIds();
const DAILY_BRIEF_MAIL_LIMIT = 6;
const DAILY_BRIEF_MAIL_DIGEST_LIMIT = 90;

function twoDigits(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function dailyBriefItem(
  id: string,
  sourceId: DailyBriefSourceId,
  title: string,
  summary: string,
  timeLabel: string,
  startsAt: string,
  dueAt: string,
  leaveBy: string,
  needsAction: boolean,
  severity: DailyBriefSeverity
): DailyBriefItem {
  return {
    id: id,
    sourceId: sourceId,
    sourceRecordId: id,
    title: title,
    summary: summary,
    timeLabel: timeLabel,
    startsAt: startsAt,
    dueAt: dueAt,
    leaveBy: leaveBy,
    completed: false,
    needsAction: needsAction,
    severity: severity
  };
}

function timestamp(value: string): number {
  if (value.trim().length === 0) {
    return Number.MAX_VALUE;
  }
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : Number.MAX_VALUE;
}

function objectiveTime(item: DailyBriefItem): number {
  return Math.min(timestamp(item.startsAt), timestamp(item.dueAt), timestamp(item.leaveBy));
}

function allItems(sections: DailyBriefSection[]): DailyBriefItem[] {
  const items: DailyBriefItem[] = [];
  sections.forEach((section: DailyBriefSection): void => {
    section.items.forEach((value: DailyBriefItem): void => {
      items.push(value);
    });
  });
  return items;
}

function timeCandidates(items: DailyBriefItem[]): DailyBriefItem[] {
  return items.filter((item: DailyBriefItem): boolean =>
    (item.sourceId === 'calendar' || item.sourceId === 'todo' || item.sourceId === 'commute') &&
      objectiveTime(item) < Number.MAX_VALUE)
    .sort((left: DailyBriefItem, right: DailyBriefItem): number =>
      objectiveTime(left) - objectiveTime(right));
}

function actionSourcePriority(sourceId: DailyBriefSourceId): number {
  if (sourceId === 'mail') {
    return 0;
  }
  if (sourceId === 'yesterday') {
    return 1;
  }
  if (sourceId === 'todo') {
    return 2;
  }
  return 3;
}

function actionCandidates(items: DailyBriefItem[]): DailyBriefItem[] {
  return items.filter((item: DailyBriefItem): boolean =>
    (item.sourceId === 'mail' || item.sourceId === 'yesterday' || item.sourceId === 'todo') &&
      item.needsAction && !item.completed)
    .sort((left: DailyBriefItem, right: DailyBriefItem): number => {
      const leftDeadline = timestamp(left.dueAt);
      const rightDeadline = timestamp(right.dueAt);
      if (leftDeadline !== rightDeadline) {
        return leftDeadline - rightDeadline;
      }
      return actionSourcePriority(left.sourceId) - actionSourcePriority(right.sourceId);
    });
}

function severityPriority(severity: DailyBriefSeverity): number {
  if (severity === 'severe') {
    return 0;
  }
  if (severity === 'warn') {
    return 1;
  }
  return severity === 'notice' ? 2 : 3;
}

function statusSourcePriority(sourceId: DailyBriefSourceId): number {
  if (sourceId === 'commute') {
    return 0;
  }
  if (sourceId === 'weather') {
    return 1;
  }
  if (sourceId === 'health') {
    return 2;
  }
  return sourceId === 'spending' ? 3 : 4;
}

function statusCandidates(items: DailyBriefItem[]): DailyBriefItem[] {
  return items.filter((item: DailyBriefItem): boolean =>
    (item.sourceId === 'weather' || item.sourceId === 'commute' ||
      item.sourceId === 'health' || item.sourceId === 'spending') && item.severity !== 'none')
    .sort((left: DailyBriefItem, right: DailyBriefItem): number => {
      const severityDifference = severityPriority(left.severity) - severityPriority(right.severity);
      return severityDifference === 0
        ? statusSourcePriority(left.sourceId) - statusSourcePriority(right.sourceId)
        : severityDifference;
    });
}

function appendUnique(target: DailyBriefItem[], values: DailyBriefItem[]): void {
  values.forEach((value: DailyBriefItem): void => {
    if (!target.some((existing: DailyBriefItem): boolean => existing.id === value.id)) {
      target.push(value);
    }
  });
}

function firstUnused(values: DailyBriefItem[], usedIds: string[]): DailyBriefItem | null {
  for (let index = 0; index < values.length; index += 1) {
    if (usedIds.indexOf(values[index].id) < 0) {
      return values[index];
    }
  }
  return null;
}

function normalizePreference(value: DailyBriefPreference): DailyBriefPreference {
  return {
    topics: value.topics.slice(),
    language: value.language,
    timeBudgetMinutes: value.timeBudgetMinutes,
    formats: value.formats.slice(),
    negativePreference: value.negativePreference,
    targetTime: value.targetTime
  };
}

function actionRecord(value: Object | undefined): DailyBriefActionRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as DailyBriefActionRecord;
}

function stringArray(value: DailyBriefActionValue): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const values = value as Object[];
  const normalized: string[] = [];
  for (let index = 0; index < values.length; index += 1) {
    if (typeof values[index] !== 'string') {
      return null;
    }
    normalized.push(values[index] as string);
  }
  return normalized;
}

function normalizePreferenceActionArgs(value: Object | undefined): DailyBriefPreference | null {
  const args = actionRecord(value);
  if (args === null || Object.keys(args).sort().join(',') !==
    'formats,language,negativePreference,targetTime,timeBudgetMinutes,topics') {
    return null;
  }
  const topics = stringArray(args['topics']);
  const formats = stringArray(args['formats']);
  const language = args['language'];
  const timeBudgetMinutes = args['timeBudgetMinutes'];
  const negativePreference = args['negativePreference'];
  const targetTime = args['targetTime'];
  if (topics === null || formats === null ||
    language !== '中文优先' && language !== '中英混合' ||
    typeof timeBudgetMinutes !== 'number' || !Number.isFinite(timeBudgetMinutes) ||
    typeof negativePreference !== 'string' || typeof targetTime !== 'string') {
    return null;
  }
  let normalizedLanguage: '中文优先' | '中英混合' = '中文优先';
  if (language === '中英混合') {
    normalizedLanguage = '中英混合';
  }
  return {
    topics: topics,
    language: normalizedLanguage,
    timeBudgetMinutes: timeBudgetMinutes,
    formats: formats,
    negativePreference: negativePreference,
    targetTime: targetTime
  };
}

function normalizeHistoryActionArgs(value: Object | undefined): DailyBriefHistoryArgs | null {
  const args = actionRecord(value);
  if (args === null || Object.keys(args).join(',') !== 'direction') {
    return null;
  }
  const direction = args['direction'];
  if (direction !== 'previous' && direction !== 'today' && direction !== 'next') {
    return null;
  }
  let normalizedDirection: 'previous' | 'today' | 'next' = 'previous';
  if (direction === 'today') {
    normalizedDirection = 'today';
  } else if (direction === 'next') {
    normalizedDirection = 'next';
  }
  return { direction: normalizedDirection };
}

function normalizeMailActionArgs(value: Object | undefined): DailyBriefMailArgs | null {
  const args = actionRecord(value);
  if (args === null || Object.keys(args).sort().join(',') !== 'messageId,provider,requestKey,threadId') {
    return null;
  }
  const provider = args['provider'];
  const threadId = args['threadId'];
  const messageId = args['messageId'];
  const requestKey = args['requestKey'];
  if (typeof provider !== 'string' || typeof threadId !== 'string' ||
    typeof messageId !== 'string' || typeof requestKey !== 'string' ||
    provider.trim().length === 0 || threadId.trim().length === 0 && messageId.trim().length === 0) {
    return null;
  }
  return {
    provider: provider,
    threadId: threadId,
    messageId: messageId,
    requestKey: requestKey
  };
}

export function dailyBriefHistoryDirection(value: Object | undefined): DailyBriefHistoryDirection | null {
  const normalized = normalizeHistoryActionArgs(value);
  return normalized === null ? null : normalized.direction;
}

export function dailyBriefMailReadRequest(value: Object | undefined): DailyBriefMailReadRequest | null {
  const normalized = normalizeMailActionArgs(value);
  if (normalized === null) {
    return null;
  }
  const provider = normalized.provider.trim().toLowerCase();
  const threadId = normalized.threadId.trim();
  const messageId = normalized.messageId.trim();
  if (provider === 'gmail' && threadId.length > 0 && messageId.length > 0) {
    const args: DailyBriefMailArgs = {
      provider,
      threadId,
      messageId,
      requestKey: 'gmail:' + threadId
    };
    return { toolId: 'gmail.thread.read', args: args as Object };
  }
  if (provider === 'qq' && /^\d+$/.test(messageId)) {
    const args: DailyBriefMailArgs = {
      provider,
      threadId,
      messageId,
      requestKey: 'qq:' + messageId
    };
    return { toolId: 'mail.thread.read', args: args as Object };
  }
  return null;
}

function normalizeAction(value: A2uiAction): A2uiAction | null {
  const supported = value.id === 'daily.brief.regenerate' ||
    value.id === 'daily.brief.preference.save' ||
    value.id === 'daily.brief.history.open' ||
    value.id === 'daily.brief.mail.read' ||
    value.id === 'daily.brief.route.open' ||
    value.id === 'daily.brief.ride.estimate' ||
    value.id === 'daily.brief.discovery.open';
  if (!supported) {
    return null;
  }
  const next: A2uiAction = {
    id: value.id,
    label: value.label,
    prompt: value.prompt,
    variant: value.variant,
    kind: value.kind
  };
  if (value.sourceSectionId !== undefined) {
    next.sourceSectionId = value.sourceSectionId;
  }
  if (value.id === 'daily.brief.regenerate' || value.id === 'daily.brief.discovery.open' ||
    value.id === 'daily.brief.route.open' || value.id === 'daily.brief.ride.estimate') {
    return value.args === undefined ? next : null;
  }
  let normalizedArgs: Object | null = null;
  if (value.id === 'daily.brief.preference.save') {
    normalizedArgs = normalizePreferenceActionArgs(value.args);
  } else if (value.id === 'daily.brief.history.open') {
    normalizedArgs = normalizeHistoryActionArgs(value.args);
  } else {
    normalizedArgs = normalizeMailActionArgs(value.args);
    if (normalizedArgs !== null && dailyBriefMailReadRequest(normalizedArgs) === null) {
      return null;
    }
  }
  if (normalizedArgs === null) {
    return null;
  }
  next.args = normalizedArgs;
  return next;
}

function normalizeActions(values: A2uiAction[]): A2uiAction[] {
  const normalized: A2uiAction[] = [];
  values.forEach((value: A2uiAction): void => {
    const action = normalizeAction(value);
    if (action !== null) {
      normalized.push(action);
    }
  });
  return normalized;
}

function normalizeItem(value: DailyBriefItem): DailyBriefItem {
  const next: DailyBriefItem = {
    id: value.id,
    sourceId: value.sourceId,
    sourceRecordId: value.sourceRecordId,
    title: value.title,
    summary: value.summary,
    timeLabel: value.timeLabel,
    startsAt: value.startsAt,
    dueAt: value.dueAt,
    leaveBy: value.leaveBy,
    completed: value.completed,
    needsAction: value.needsAction,
    severity: value.severity
  };
  if (value.action !== undefined) {
    const action = normalizeAction(value.action);
    if (action !== null) {
      next.action = action;
    }
  }
  return next;
}

function normalizeSection(value: DailyBriefSection): DailyBriefSection {
  return {
    id: value.id,
    title: value.title,
    state: value.state,
    message: value.message,
    items: value.items.map((item: DailyBriefItem): DailyBriefItem => normalizeItem(item))
  };
}

function normalizeCandidate(value: WaterfallRankedCandidate): WaterfallRankedCandidate {
  const next: WaterfallRankedCandidate = {
    id: value.id,
    source: value.source,
    mediaType: value.mediaType,
    title: value.title,
    summary: value.summary,
    url: value.url,
    coverUrl: value.coverUrl,
    publishedAt: value.publishedAt,
    originalIndex: value.originalIndex,
    normalizedUrl: value.normalizedUrl,
    signals: {
      relevanceTier: value.signals.relevanceTier,
      titleHits: value.signals.titleHits,
      summaryHits: value.signals.summaryHits,
      freshnessTier: value.signals.freshnessTier
    },
    reason: value.reason
  };
  if (value.duration !== undefined) {
    next.duration = value.duration;
  }
  if (value.mediaUrl !== undefined &&
    (value.mediaUrl.startsWith('https://') && value.mediaUrl.length > 8 ||
      value.mediaUrl.startsWith('http://') && value.mediaUrl.length > 7)) {
    next.mediaUrl = value.mediaUrl;
  }
  if (value.feedUrl !== undefined && value.feedUrl.startsWith('https://')) next.feedUrl = value.feedUrl;
  if (value.audioTitle !== undefined) next.audioTitle = value.audioTitle;
  if (value.audioMimeType !== undefined) next.audioMimeType = value.audioMimeType;
  if (value.audioDuration !== undefined) next.audioDuration = value.audioDuration;
  if (value.audioPublishedAt !== undefined) next.audioPublishedAt = value.audioPublishedAt;
  if (value.audioLoadState !== undefined) next.audioLoadState = value.audioLoadState;
  if (value.audioError !== undefined) next.audioError = value.audioError;
  if (value.audioRetryable !== undefined) next.audioRetryable = value.audioRetryable;
  return next;
}

function normalizeSource(value: WaterfallSourceState): WaterfallSourceState {
  let continuation: WaterfallContinuation | null = null;
  if (value.continuation !== null) {
    continuation = {
      kind: value.continuation.kind,
      value: value.continuation.value
    };
  }
  return {
    source: value.source,
    phase: value.phase,
    continuation: continuation,
    inFlight: value.inFlight,
    reservedCount: value.reservedCount,
    message: value.message
  };
}

export function normalizeDailyBriefWaterfall(value: WaterfallFeedState | null): WaterfallFeedState | null {
  if (value === null) {
    return null;
  }
  return {
    query: value.query,
    enabledSources: value.enabledSources.slice(),
    preferenceDescription: value.preferenceDescription,
    shown: value.shown.map((candidate: WaterfallRankedCandidate): WaterfallRankedCandidate =>
      normalizeCandidate(candidate)),
    current: value.current === null ? null : normalizeCandidate(value.current),
    stable: value.stable.map((candidate: WaterfallRankedCandidate): WaterfallRankedCandidate =>
      normalizeCandidate(candidate)),
    tail: value.tail.map((candidate: WaterfallRankedCandidate): WaterfallRankedCandidate =>
      normalizeCandidate(candidate)),
    sources: value.sources.map((source: WaterfallSourceState): WaterfallSourceState => normalizeSource(source))
  };
}

function normalizeSnapshot(value: DailyBriefSnapshot): DailyBriefSnapshot {
  const fixtureSections = buildDailyBriefFixtureSections(new Date(value.date + 'T08:31:00'));
  const legacyFixture = value.sections.some((section: DailyBriefSection): boolean =>
    section.id === 'today' && section.items.some((item: DailyBriefItem): boolean =>
      item.id === 'fixture-demo-review' || item.id.indexOf('fixture-') === 0));
  const providerFixture = value.sections.some((section: DailyBriefSection): boolean =>
    (section.id === 'today' || section.id === 'mail') && section.state === 'fixture');
  const sections = value.sections.map((section: DailyBriefSection): DailyBriefSection => {
    const providerSection = section.id === 'today' || section.id === 'mail';
    const providerItems = providerSection ? section.items.filter((item: DailyBriefItem): boolean =>
      item.id.indexOf('fixture-') !== 0 && (section.id !== 'today' || item.sourceId === 'calendar')) : [];
    const legacySection = providerSection ? section.state === 'fixture' || legacyFixture && providerItems.length === 0 :
      legacyFixture && section.state === 'fixture';
    if (!legacySection) {
      const normalized = normalizeSection(section);
      if (providerSection && providerItems.length !== section.items.length) {
        normalized.items = providerItems.map((item: DailyBriefItem): DailyBriefItem => normalizeItem(item));
      }
      return normalized;
    }
    if (section.id === 'today' || section.id === 'mail') {
      return {
        id: section.id,
        title: section.title,
        state: 'empty',
        message: section.id === 'today' ? '重新生成以读取真实日历' : '重新生成以读取真实邮件',
        items: []
      };
    }
    const fallback = fixtureSections.find((item: DailyBriefSection): boolean => item.id === section.id);
    return fallback === undefined ? normalizeSection(section) : normalizeSection(fallback);
  });
  const discovery = value.discovery.length > 0 ? value.discovery : buildDailyBriefFixtureDiscovery(value.date);
  const topThree = legacyFixture || providerFixture ? selectDailyBriefTopThree(sections) : value.topThree;
  const actions = normalizeActions(value.actions);
  if (legacyFixture && actions.every((action: A2uiAction): boolean => action.id !== 'daily.brief.route.open')) {
    actions.push({ id: 'daily.brief.route.open', label: '查看路线', prompt: '查看路线', variant: 'secondary', kind: 'client' });
  }
  if (legacyFixture && actions.every((action: A2uiAction): boolean => action.id !== 'daily.brief.ride.estimate')) {
    actions.push({ id: 'daily.brief.ride.estimate', label: '预估车型', prompt: '预估车型', variant: 'secondary', kind: 'client' });
  }
  if (legacyFixture && discovery.length > 0 && actions.every((action: A2uiAction): boolean =>
      action.id !== 'daily.brief.discovery.open')) {
    actions.push({
      id: 'daily.brief.discovery.open',
      label: '查看完整发现流',
      prompt: '查看完整发现流',
      variant: 'secondary',
      kind: 'client'
    });
  }
  return {
    schemaVersion: 1,
    date: value.date,
    generatedAt: value.generatedAt,
    status: value.status,
    profile: normalizePreference(value.profile),
    topThree: topThree.map((highlight: DailyBriefHighlight): DailyBriefHighlight => {
      return { slot: highlight.slot, item: normalizeItem(highlight.item) };
    }),
    sections: sections,
    discovery: discovery.map((item: DailyBriefDiscoveryItem): DailyBriefDiscoveryItem => {
      return {
        id: item.id,
        source: item.source,
        mediaType: item.mediaType,
        title: item.title,
        summary: item.summary,
        url: item.url,
        reason: item.reason,
        timeBudgetLabel: item.timeBudgetLabel
      };
    }),
    sources: value.sources.map((source: DailyBriefSourceSummary): DailyBriefSourceSummary => {
      return { sourceId: source.sourceId, state: source.state, message: source.message };
    }),
    waterfall: normalizeDailyBriefWaterfall(value.waterfall),
    actions: actions
  };
}

function rootComponent(title: string, actions: A2uiAction[] = []): A2uiComponent {
  return {
    id: 'root',
    component: A2UI_COMPONENT_SURFACE_ROOT,
    title: title,
    actions: actions
  };
}

function dailyBriefSurface(
  surfaceId: string,
  title: string,
  status: string,
  dataModelJson: string,
  error: string,
  components: A2uiComponent[]
): A2uiSurfaceState {
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: title,
    intent: 'daily-brief',
    status: status,
    components: components,
    dataModelJson: dataModelJson,
    error: error,
    sequence: 1
  };
}

export function defaultDailyBriefPreference(): DailyBriefPreference {
  return {
    topics: ['AI 产品', 'HarmonyOS', 'Agent', '推荐系统'],
    language: '中文优先',
    timeBudgetMinutes: 15,
    formats: ['图文', '短视频', '长视频'],
    negativePreference: '降低重复内容和只有热度、缺少信息量的内容',
    targetTime: '08:30'
  };
}

export function decideDailyBriefOpen(
  existing: DailyBriefSnapshot | null,
  regenerate: boolean
): DailyBriefOpenDecision {
  if (regenerate) {
    return 'regenerate';
  }
  return existing === null ? 'generate_first' : 'open_existing';
}

export function shouldApplyDailyBriefGeneration(started: number, current: number): boolean {
  return started === current;
}

export function selectDailyBriefStoredWinnerBeforeSave(
  stored: DailyBriefSnapshot | null,
  regenerate: boolean
): DailyBriefSnapshot | null {
  return regenerate ? null : stored;
}

export function selectDailyBriefSnapshotAfterSave(
  existing: DailyBriefSnapshot | null,
  generated: DailyBriefSnapshot,
  saved: boolean
): DailyBriefSnapshot | null {
  return saved ? generated : existing;
}

export function dailyBriefDate(now: Date): string {
  return now.getFullYear().toString() + '-' + twoDigits(now.getMonth() + 1) + '-' + twoDigits(now.getDate());
}

export function dailyBriefDemoScenario(date: string): DailyBriefDemoScenario {
  const day = Number(date.substring(date.length - 2));
  if (Number.isFinite(day) && day % 2 === 0) {
    return {
      routeLabel: '秋港花园 → 深圳宝安机场',
      origin: '秋港花园',
      originLongitude: 114.075434,
      originLatitude: 22.668739,
      destination: '深圳宝安机场 T3 航站楼',
      destinationLongitude: 113.811840,
      destinationLatitude: 22.627554,
      departureLabel: '建议 06:45 出发 · 预留值机时间',
      preferredVehicle: '六座舒适型',
      outfitTitle: '机场出行 · 轻便分层',
      outfitSummary: '橄榄绿外套搭白色针织和深蓝旅行裤，空调环境可加围巾。',
      outfitImage: 'resource://rawfile/daily/outfit-airport-real.png'
    };
  }
  if (Number.isFinite(day) && day % 3 === 1) {
    return {
      routeLabel: '秋港花园 → 坂田华为基地 D 区',
      origin: '秋港花园',
      originLongitude: 114.075434,
      originLatitude: 22.668739,
      destination: '坂田华为基地 D 区',
      destinationLongitude: 114.057457,
      destinationLatitude: 22.643890,
      departureLabel: '建议 08:28 出发 · 晴天通勤',
      preferredVehicle: '舒适型',
      outfitTitle: '晴天办公 · 轻盈商务休闲',
      outfitSummary: '浅沙色薄外套搭白色针织和深蓝长裤，适合园区步行与室内会议。',
      outfitImage: 'resource://rawfile/daily/outfit-clear-real.png'
    };
  }
  return {
    routeLabel: '秋港花园 → 坂田华为基地 D 区',
    origin: '秋港花园',
    originLongitude: 114.075434,
    originLatitude: 22.668739,
    destination: '坂田华为基地 D 区',
    destinationLongitude: 114.057457,
    destinationLatitude: 22.643890,
    departureLabel: '建议 08:18 出发 · 雨天提前 12 分钟',
    preferredVehicle: '舒适型',
    outfitTitle: '雨天通勤 · 防水利落',
    outfitSummary: '深蓝防水夹克搭浅蓝衬衫和炭灰长裤，带伞并选择防滑鞋。',
    outfitImage: 'resource://rawfile/daily/outfit-office-real.png'
  };
}

export function dailyBriefScenarioToolRequest(
  actionId: string,
  date: string
): DailyBriefScenarioToolRequest | null {
  const scenario = dailyBriefDemoScenario(date);
  if (actionId === 'daily.brief.route.open') {
    const args: DailyBriefRouteArgs = {
      origin: scenario.origin,
      destination: scenario.destination,
      travelMode: 'driving',
      navigate: true
    };
    return {
      toolId: 'maps.route.open',
      args: args as Object
    };
  }
  if (actionId === 'daily.brief.ride.estimate') {
    const args: DailyBriefRideArgs = {
      origin: scenario.origin,
      destination: scenario.destination,
      city: '深圳'
    };
    return {
      toolId: 'ride.estimate',
      args: args as Object
    };
  }
  return null;
}

export function projectDailyBriefMailForDate(date: string, items: DailyBriefItem[]): DailyBriefItem[] {
  const candidates = items.filter((item: DailyBriefItem): boolean => {
    const receivedAt = new Date(item.startsAt);
    return Number.isFinite(receivedAt.getTime()) && dailyBriefDate(receivedAt) === date;
  }).sort((left: DailyBriefItem, right: DailyBriefItem): number =>
    new Date(right.startsAt).getTime() - new Date(left.startsAt).getTime());
  const selected: DailyBriefItem[] = [];
  const recordIds: string[] = [];
  for (let index = 0; index < candidates.length && selected.length < DAILY_BRIEF_MAIL_LIMIT; index += 1) {
    if (recordIds.indexOf(candidates[index].sourceRecordId) === -1) {
      recordIds.push(candidates[index].sourceRecordId);
      selected.push(candidates[index]);
    }
  }
  return selected;
}

export function dailyBriefMailDigest(items: DailyBriefItem[]): string {
  if (items.length === 0) return '今天没有邮件';
  const titles: string[] = [];
  for (let index = 0; index < items.length && titles.length < 3; index += 1) {
    const title = items[index].title.trim();
    if (title.length > 0 && titles.indexOf(title) === -1) titles.push(title);
  }
  const digest = '今天共 ' + items.length.toString() + ' 封邮件' +
    (titles.length > 0 ? '，重点包括：' + titles.join('；') + '。' : '。');
  const characters: string[] = Array.from(digest);
  if (characters.length <= DAILY_BRIEF_MAIL_DIGEST_LIMIT) return digest;
  const bounded = characters.slice(0, DAILY_BRIEF_MAIL_DIGEST_LIMIT - 1).join('');
  const boundary = Math.max(bounded.lastIndexOf('；'), bounded.lastIndexOf('，'));
  return (boundary > 30 ? bounded.substring(0, boundary) : bounded) + '…';
}

export function buildDailyBriefFixtureSections(now: Date): DailyBriefSection[] {
  const date = dailyBriefDate(now);
  const yesterday = new Date(now.getTime());
  yesterday.setDate(yesterday.getDate() - 1);
  const yesterdayDate = dailyBriefDate(yesterday);
  return [
    {
      id: 'today',
      title: '今日日程',
      state: 'fixture',
      message: '今天有 3 项安排',
      items: [
        dailyBriefItem('fixture-focus', 'todo', '晨间专注时间', '整理今日优先级并完成核心事项',
          '09:00', date + 'T09:00:00', '', '', false, 'notice'),
        dailyBriefItem('fixture-review', 'todo', '日报体验评审', '与林然确认关键流程和展示重点',
          '10:30', date + 'T10:30:00', '', '', true, 'none'),
        dailyBriefItem('fixture-sync', 'todo', 'Waterfall 方案同步', '确认媒体聚合与个性化推荐的下一步',
          '15:00', date + 'T15:00:00', '', '', true, 'none')
      ]
    },
    {
      id: 'yesterday',
      title: '昨日延续',
      state: 'fixture',
      message: '昨日未完成事项',
      items: [dailyBriefItem(
        'fixture-waterfall-follow-up',
        'yesterday',
        'Waterfall follow-up',
        '跟进周宁的 Waterfall 反馈',
        '昨日',
        yesterdayDate + 'T16:00:00',
        date + 'T11:00:00',
        '',
        true,
        'none'
      )]
    },
    {
      id: 'mail',
      title: '重要消息',
      state: 'fixture',
      message: '3 条重要消息摘要',
      items: [
        dailyBriefItem('fixture-mail-review', 'mail', '日报界面评审反馈',
          '需要确认顶部日期切换、发现流和出行卡片的最终交互。', '08:42', date + 'T08:42:00', '', '', true, 'notice'),
        dailyBriefItem('fixture-mail-waterfall', 'mail', 'Waterfall 推荐策略更新',
          '新一轮媒体聚合结果已准备，包含视频和讨论内容。', '08:16', date + 'T08:16:00', '', '', false, 'none'),
        dailyBriefItem('fixture-mail-bill', 'mail', '本月生活账单提醒',
          '水电费与话费临近到期，可在消费建议中查看确认预览。', '07:55', date + 'T07:55:00', '', '', true, 'warn')
      ]
    },
    {
      id: 'weather_commute',
      title: '天气与通勤',
      state: 'fixture',
      message: '天气与通勤建议',
      items: [
        dailyBriefItem(
          'fixture-weather-rain',
          'weather',
          '今天有雨',
          '出门记得带伞',
          '有雨',
          '',
          '',
          '',
          false,
          'warn'
        ),
        dailyBriefItem(
          'fixture-commute',
          'commute',
          '通勤约 45 分钟',
          '受降雨影响，建议提前 12 分钟出发',
          '提前 12 分钟',
          '',
          '',
          date + 'T08:33:00',
          false,
          'warn'
        )
      ]
    },
    {
      id: 'health',
      title: '健康',
      state: 'fixture',
      message: '今日健康摘要',
      items: [dailyBriefItem(
        'fixture-sleep',
        'health',
        '昨晚睡眠 6 小时 20 分',
        '今天适合安排一次短休息',
        '6 小时 20 分',
        '',
        '',
        '',
        false,
        'notice'
      )]
    },
    {
      id: 'spending',
      title: '消费建议',
      state: 'fixture',
      message: '昨日支出 ¥125.50，固定账单待确认',
      items: [
        dailyBriefItem('fixture-spending-food', 'spending', '餐饮 ¥68.50',
          '午餐与咖啡支出，仍在本周预算内。', '¥68.50', '', '', '', false, 'notice'),
        dailyBriefItem('fixture-spending-ride', 'spending', '出行 ¥32.00',
          '通勤交通支出，雨天可预留少量弹性预算。', '¥32.00', '', '', '', false, 'notice'),
        dailyBriefItem('fixture-spending-subscription', 'spending', '订阅 ¥25.00',
          '本周有一项数字服务续费。', '¥25.00', '', '', '', false, 'notice')
      ]
    }
  ];
}

export function buildDailyBriefFixtureDiscovery(date: string): DailyBriefDiscoveryItem[] {
  return [
    {
      id: 'fixture-video-' + date,
      source: 'YouTube',
      mediaType: 'video',
      title: 'Agent 产品设计的三个关键取舍',
      summary: '从真实任务链、可解释推荐和用户控制三个角度拆解近期产品实践。',
      url: 'https://www.youtube.com/results?search_query=AI+Agent+product+design',
      reason: '与你关注的 Agent 和推荐系统主题相关',
      timeBudgetLabel: '8 分钟'
    },
    {
      id: 'fixture-discussion-' + date,
      source: '知乎',
      mediaType: 'post',
      title: '个人日报怎样避免信息过载？',
      summary: '讨论聚合展示、优先级和个性化推荐之间的平衡。',
      url: 'https://www.zhihu.com/search?q=%E4%B8%AA%E4%BA%BA%E6%97%A5%E6%8A%A5',
      reason: '与你正在打磨的日报场景直接相关',
      timeBudgetLabel: '3 分钟'
    },
    {
      id: 'fixture-reading-' + date,
      source: 'Hacker News',
      mediaType: 'post',
      title: '多模态摘要如何真正节省阅读时间',
      summary: '聚焦时间点推荐、摘要可信度和原内容回溯能力。',
      url: 'https://news.ycombinator.com/',
      reason: '补充你对媒体聚合与多模态摘要的关注',
      timeBudgetLabel: '4 分钟'
    }
  ];
}

export function selectDailyBriefTopThree(sections: DailyBriefSection[]): DailyBriefHighlight[] {
  const items = allItems(sections);
  const preferred: DailyBriefItem[][] = [
    timeCandidates(items),
    actionCandidates(items),
    statusCandidates(items)
  ];
  const selected: (DailyBriefItem | null)[] = [null, null, null];
  const usedIds: string[] = [];
  for (let index = 0; index < preferred.length; index += 1) {
    selected[index] = firstUnused(preferred[index], usedIds);
    if (selected[index] !== null) {
      usedIds.push((selected[index] as DailyBriefItem).id);
    }
  }

  const pool: DailyBriefItem[] = [];
  preferred.forEach((values: DailyBriefItem[]): void => appendUnique(pool, values));
  appendUnique(pool, items);
  for (let index = 0; index < selected.length; index += 1) {
    if (selected[index] === null) {
      selected[index] = firstUnused(pool, usedIds);
      if (selected[index] !== null) {
        usedIds.push((selected[index] as DailyBriefItem).id);
      }
    }
  }

  const highlights: DailyBriefHighlight[] = [];
  HIGHLIGHT_SLOTS.forEach((slot: DailyBriefHighlightSlot, index: number): void => {
    if (selected[index] !== null) {
      highlights.push({ slot: slot, item: selected[index] as DailyBriefItem });
    }
  });
  return highlights;
}

export function dailyBriefWaterfallInput(
  preference: DailyBriefPreference,
  todayTopic: string
): DailyBriefWaterfallInput {
  const queryParts = preference.topics.slice();
  if (todayTopic.trim().length > 0) {
    queryParts.push(todayTopic.trim());
  }
  return {
    query: queryParts.join(' '),
    sources: WATERFALL_SOURCES.slice(),
    preferenceDescription: preference.language + '；' + preference.timeBudgetMinutes.toString() +
      ' 分钟内；' + preference.formats.join(' > ') + '；' + preference.negativePreference
  };
}

export function projectDailyBriefDiscovery(state: WaterfallFeedState): DailyBriefDiscoveryItem[] {
  const ordered: WaterfallRankedCandidate[] = [];
  if (state.current !== null) {
    ordered.push(state.current);
  }
  state.stable.forEach((candidate: WaterfallRankedCandidate): void => {
    ordered.push(candidate);
  });
  state.tail.forEach((candidate: WaterfallRankedCandidate): void => {
    ordered.push(candidate);
  });
  state.shown.forEach((candidate: WaterfallRankedCandidate): void => {
    ordered.push(candidate);
  });

  const seenIds: string[] = [];
  const seenUrls: string[] = [];
  const unique: WaterfallRankedCandidate[] = [];
  for (let index = 0; index < ordered.length; index += 1) {
    const candidate = ordered[index];
    if (seenIds.indexOf(candidate.id) >= 0 ||
      (candidate.normalizedUrl.length > 0 && seenUrls.indexOf(candidate.normalizedUrl) >= 0)) {
      continue;
    }
    seenIds.push(candidate.id);
    if (candidate.normalizedUrl.length > 0) {
      seenUrls.push(candidate.normalizedUrl);
    }
    unique.push(candidate);
  }
  const selected = unique.slice(0, 3);
  if (selected.length === 3 && selected.every((candidate: WaterfallRankedCandidate): boolean =>
    candidate.mediaType !== 'video')) {
    const video = unique.find((candidate: WaterfallRankedCandidate): boolean => candidate.mediaType === 'video');
    if (video !== undefined) selected[2] = video;
  }
  const result: DailyBriefDiscoveryItem[] = [];
  selected.forEach((candidate: WaterfallRankedCandidate): void => {
    let timeBudgetLabel = candidate.mediaType === 'post' ? '3 分钟' : '5 分钟';
    if (candidate.mediaType === 'video') {
      timeBudgetLabel = candidate.duration === undefined || candidate.duration.trim().length === 0
        ? '时长未知'
        : candidate.duration;
    }
    result.push({
      id: candidate.id,
      source: candidate.source,
      mediaType: candidate.mediaType,
      title: candidate.title,
      summary: candidate.summary,
      url: candidate.url,
      reason: candidate.signals.titleHits > 0 || candidate.signals.summaryHits > 0
        ? candidate.reason
        : '来自 ' + candidate.source + ' 的内容',
      timeBudgetLabel: timeBudgetLabel
    });
  });
  return result;
}

export function createDailyBriefSurface(
  snapshot: DailyBriefSnapshot,
  visiblePreference: DailyBriefPreference = snapshot.profile
): A2uiSurfaceState {
  const normalizedSnapshot = normalizeSnapshot(snapshot);
  const model: DailyBriefSurfaceModel = {
    dailyBrief: normalizedSnapshot,
    dailyBriefPreference: normalizePreference(visiblePreference)
  };
  return dailyBriefSurface(
    'daily-brief-' + snapshot.date,
    '个人日报',
    'ready',
    JSON.stringify(model),
    '',
    [rootComponent('个人日报', normalizedSnapshot.actions)]
  );
}

export function createDailyBriefLoadingSurface(date: string): A2uiSurfaceState {
  const model: DailyBriefPendingModel = {
    dailyBriefDate: date,
    dailyBriefMessage: '日报生成中'
  };
  return dailyBriefSurface(
    'daily-brief-' + date,
    '日报生成中',
    'thinking',
    JSON.stringify(model),
    '',
    [rootComponent('日报生成中')]
  );
}

export function createDailyBriefErrorSurface(date: string, message: string): A2uiSurfaceState {
  const model: DailyBriefErrorModel = {
    dailyBriefDate: date,
    dailyBriefError: message
  };
  return dailyBriefSurface(
    'daily-brief-' + date,
    '个人日报生成失败',
    'error',
    JSON.stringify(model),
    message,
    [rootComponent('个人日报生成失败')]
  );
}

export function createDailyBriefWaterfallSurface(snapshot: DailyBriefSnapshot): A2uiSurfaceState | null {
  const normalizedSnapshot = normalizeSnapshot(snapshot);
  const waterfall = dailyBriefDiscoveryWaterfall(normalizedSnapshot);
  if (waterfall === null) {
    return null;
  }
  const cards = dailyBriefWaterfallCards(waterfall);
  const aggregateSearch: AggregateSearchResult = {
    query: waterfall.query,
    videos: cards.videos,
    posts: cards.posts,
    sourceStatuses: [],
    summary: '个人日报完整发现流',
    waterfall: waterfall
  };
  const model: DailyBriefWaterfallModel = { aggregateSearch: aggregateSearch };
  const args: DailyBriefOpenArgs = { regenerate: false };
  const returnAction: A2uiAction = {
    id: 'daily.brief.open',
    label: '返回日报',
    prompt: '返回日报',
    variant: 'secondary',
    kind: 'client',
    args: args
  };
  return {
    surfaceId: 'daily-brief-waterfall-' + snapshot.date,
    rootId: 'root',
    title: '为你发现',
    intent: 'aggregate_search',
    status: 'ready',
    components: [
      {
        id: 'root',
        component: A2UI_COMPONENT_SURFACE_ROOT,
        child: 'waterfall',
        actions: [returnAction]
      },
      {
        id: 'waterfall',
        component: A2UI_COMPONENT_AGGREGATE_SEARCH,
        title: '为你发现'
      }
    ],
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: 1
  };
}

export function dailyBriefDiscoveryWaterfall(snapshot: DailyBriefSnapshot): WaterfallFeedState | null {
  const frozen = normalizeDailyBriefWaterfall(snapshot.waterfall);
  if (frozen !== null && (frozen.current !== null || frozen.shown.length > 0 ||
    frozen.stable.length > 0 || frozen.tail.length > 0)) return frozen;
  if (snapshot.discovery.length === 0) return null;
  const candidates = snapshot.discovery.map((item: DailyBriefDiscoveryItem, index: number): WaterfallRankedCandidate => ({
    id: item.id,
    source: item.source,
    mediaType: item.mediaType,
    title: item.title,
    summary: item.summary,
    url: item.url,
    coverUrl: item.mediaType === 'video' ? 'resource://rawfile/daily/discovery-video-fallback.png' : '',
    publishedAt: snapshot.generatedAt,
    duration: item.timeBudgetLabel,
    originalIndex: index,
    normalizedUrl: item.url,
    signals: { relevanceTier: 1, titleHits: 1, summaryHits: 1, freshnessTier: 1 },
    reason: item.reason
  }));
  return {
    query: '个人日报精选',
    enabledSources: candidates.map((item: WaterfallRankedCandidate): string => item.source),
    preferenceDescription: snapshot.profile.topics.join('、'),
    shown: [],
    current: candidates[0],
    stable: candidates.slice(1),
    tail: [],
    sources: []
  };
}

function dailyBriefWaterfallCards(state: WaterfallFeedState): DailyBriefWaterfallCards {
  const candidates: WaterfallRankedCandidate[] = state.shown.slice();
  if (state.current !== null) candidates.push(state.current);
  candidates.push(...state.stable, ...state.tail);
  const videos: AggregateSearchVideo[] = [];
  const posts: AggregateSearchPost[] = [];
  candidates.forEach((candidate: WaterfallRankedCandidate): void => {
    const source = dailyBriefAggregateSource(candidate.source);
    if (candidate.mediaType === 'video') {
      videos.push({
        id: candidate.id, source: source, provider: candidate.source, title: candidate.title,
        summary: candidate.summary, url: candidate.url, thumbnail: candidate.coverUrl,
        publishedAt: candidate.publishedAt, duration: candidate.duration ?? '', status: 'success', rows: []
      });
      return;
    }
    posts.push({
      id: candidate.id, source: source, provider: candidate.source, title: candidate.title,
      author: '', handle: '', text: candidate.summary, url: candidate.url,
      publishedAt: candidate.publishedAt, score: '', commentCount: '', status: 'success', rows: []
    });
  });
  const result: DailyBriefWaterfallCards = { videos: videos, posts: posts };
  return result;
}

function dailyBriefAggregateSource(value: string): AggregateSearchSource {
  const source = value.toLowerCase().replace(/\s/g, '');
  if (source.indexOf('youtube') >= 0) return 'youtube';
  if (source.indexOf('bilibili') >= 0 || source.indexOf('哔哩') >= 0) return 'bilibili';
  if (source.indexOf('zhihu') >= 0 || source.indexOf('知乎') >= 0) return 'zhihu';
  if (source.indexOf('reddit') >= 0) return 'reddit';
  if (source === 'x' || source.indexOf('twitter') >= 0) return 'x';
  return 'hackernews';
}
