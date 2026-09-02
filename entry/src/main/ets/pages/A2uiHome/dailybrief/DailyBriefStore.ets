import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  A2uiAction,
  WaterfallContinuation,
  WaterfallFeedState,
  WaterfallRankedCandidate,
  WaterfallSourceState
} from '@loop/agent-core';
import { defaultDailyBriefPreference } from './DailyBriefCore';
import {
  DailyBriefDiscoveryItem,
  DailyBriefHighlight,
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceSummary
} from './DailyBriefTypes';

export const DAILY_BRIEF_STORE_NAME: string = 'aiphone_daily_brief_store';
const SETTINGS_KEY: string = 'settings_v1';
const SNAPSHOTS_KEY: string = 'snapshots_v1';
const HISTORY_LIMIT: number = 7;
const STRING_LIMIT: number = 4096;

type ActionValue = Object | string | number | boolean | null | undefined;
type ActionRecord = Record<string, ActionValue>;

interface HistoryActionArgs {
  direction: string;
}

interface MailActionArgs {
  provider: string;
  threadId: string;
  messageId: string;
  requestKey: string;
}

function text(value: preferences.ValueType | string | number | boolean | undefined): string {
  return typeof value === 'string' ? value : '';
}

function validText(value: string, limit: number = STRING_LIMIT): boolean {
  return typeof value === 'string' && value.length <= limit;
}

function validTextArray(value: string[], limit: number = STRING_LIMIT): boolean {
  if (!Array.isArray(value)) return false;
  for (let index = 0; index < value.length; index += 1) {
    if (!validText(value[index], limit)) return false;
  }
  return true;
}

function exactKeys(value: Object, keys: string[]): boolean {
  return Object.keys(value).sort().join(',') === keys.slice().sort().join(',');
}

function validDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(value + 'T00:00:00Z');
  return !isNaN(parsed.getTime()) && parsed.toISOString().substring(0, 10) === value;
}

function validTimestamp(value: string): boolean {
  return validText(value) && value.length > 0 && !isNaN(new Date(value).getTime());
}

function validPreference(value: DailyBriefPreference | null | undefined): boolean {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) ||
    !exactKeys(value, [
      'topics', 'language', 'timeBudgetMinutes', 'formats', 'negativePreference', 'targetTime'
    ]) || !Array.isArray(value.topics) || value.topics.length > 8 ||
    !validTextArray(value.topics, 40) || !Array.isArray(value.formats) ||
    !validTextArray(value.formats) ||
    value.language !== '中文优先' && value.language !== '中英混合' ||
    typeof value.timeBudgetMinutes !== 'number' || !Number.isFinite(value.timeBudgetMinutes) ||
    value.timeBudgetMinutes < 0 || !validText(value.negativePreference) ||
    !validText(value.targetTime) || !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value.targetTime)) {
    return false;
  }
  return true;
}

function copyPreference(value: DailyBriefPreference): DailyBriefPreference {
  return {
    topics: value.topics.slice(),
    language: value.language,
    timeBudgetMinutes: value.timeBudgetMinutes,
    formats: value.formats.slice(),
    negativePreference: value.negativePreference,
    targetTime: value.targetTime
  };
}

function actionRecord(value: Object | undefined): ActionRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as ActionRecord;
}

function validActionBase(value: A2uiAction | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    validText(value.id) && validText(value.label) && validText(value.prompt) &&
    validText(value.variant) && validText(value.kind) &&
    (value.sourceSectionId === undefined || validText(value.sourceSectionId));
}

function validPreferenceActionArgs(value: Object | undefined): boolean {
  const args = actionRecord(value);
  if (args === null || !exactKeys(args, [
    'topics', 'language', 'timeBudgetMinutes', 'formats', 'negativePreference', 'targetTime'
  ])) return false;
  const topics = args['topics'];
  const language = args['language'];
  const timeBudgetMinutes = args['timeBudgetMinutes'];
  const formats = args['formats'];
  const negativePreference = args['negativePreference'];
  const targetTime = args['targetTime'];
  return Array.isArray(topics) && validTextArray(topics as string[], 40) && topics.length <= 8 &&
    (language === '中文优先' || language === '中英混合') &&
    typeof timeBudgetMinutes === 'number' && Number.isFinite(timeBudgetMinutes) &&
    timeBudgetMinutes >= 0 && Array.isArray(formats) && validTextArray(formats as string[]) &&
    typeof negativePreference === 'string' && validText(negativePreference) &&
    typeof targetTime === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(targetTime);
}

function validHistoryActionArgs(value: Object | undefined): boolean {
  const args = actionRecord(value);
  if (args === null || !exactKeys(args, ['direction'])) return false;
  const direction = args['direction'];
  return direction === 'previous' || direction === 'today' || direction === 'next';
}

function validMailActionArgs(value: Object | undefined): boolean {
  const args = actionRecord(value);
  if (args === null || !exactKeys(args, ['provider', 'threadId', 'messageId', 'requestKey'])) {
    return false;
  }
  const provider = args['provider'];
  const threadId = args['threadId'];
  const messageId = args['messageId'];
  const requestKey = args['requestKey'];
  return typeof provider === 'string' && validText(provider) && provider.trim().length > 0 &&
    typeof threadId === 'string' && validText(threadId) &&
    typeof messageId === 'string' && validText(messageId) &&
    typeof requestKey === 'string' && validText(requestKey) &&
    (threadId.trim().length > 0 || messageId.trim().length > 0);
}

export function isValidDailyBriefAction(value: A2uiAction | null | undefined): boolean {
  if (!validActionBase(value)) return false;
  const action = value as A2uiAction;
  if (action.id === 'daily.brief.regenerate' || action.id === 'daily.brief.discovery.open' ||
    action.id === 'daily.brief.route.open' || action.id === 'daily.brief.ride.estimate') {
    return action.args === undefined;
  }
  if (action.id === 'daily.brief.preference.save') {
    return validPreferenceActionArgs(action.args);
  }
  if (action.id === 'daily.brief.history.open') {
    return validHistoryActionArgs(action.args);
  }
  if (action.id === 'daily.brief.mail.read') {
    return validMailActionArgs(action.args);
  }
  return false;
}

function copyAction(value: A2uiAction): A2uiAction {
  const next: A2uiAction = {
    id: value.id,
    label: value.label,
    prompt: value.prompt,
    variant: value.variant,
    kind: value.kind
  };
  if (value.sourceSectionId !== undefined) next.sourceSectionId = value.sourceSectionId;
  if (value.args !== undefined) {
    if (value.id === 'daily.brief.preference.save') {
      next.args = copyPreference(value.args as DailyBriefPreference);
    } else if (value.id === 'daily.brief.history.open') {
      const args = value.args as ActionRecord;
      const history: HistoryActionArgs = { direction: args['direction'] as string };
      next.args = history;
    } else if (value.id === 'daily.brief.mail.read') {
      const args = value.args as ActionRecord;
      const mail: MailActionArgs = {
        provider: args['provider'] as string,
        threadId: args['threadId'] as string,
        messageId: args['messageId'] as string,
        requestKey: args['requestKey'] as string
      };
      next.args = mail;
    }
  }
  return next;
}

function validSourceId(value: string): boolean {
  return value === 'calendar' || value === 'todo' || value === 'yesterday' || value === 'mail' ||
    value === 'waterfall' || value === 'weather' || value === 'commute' || value === 'health' ||
    value === 'spending';
}

function validSourceState(value: string): boolean {
  return value === 'success' || value === 'fixture' || value === 'empty' || value === 'needs_auth' ||
    value === 'error' || value === 'timeout';
}

function validItem(value: DailyBriefItem | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    validText(value.id) && validSourceId(value.sourceId) && validText(value.sourceRecordId) &&
    validText(value.title) && validText(value.summary) && validText(value.timeLabel) &&
    validText(value.startsAt) && validText(value.dueAt) && validText(value.leaveBy) &&
    typeof value.completed === 'boolean' && typeof value.needsAction === 'boolean' &&
    (value.severity === 'none' || value.severity === 'notice' || value.severity === 'warn' ||
      value.severity === 'severe') &&
    (value.action === undefined || isValidDailyBriefAction(value.action));
}

function copyItem(value: DailyBriefItem): DailyBriefItem {
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
  if (value.action !== undefined) next.action = copyAction(value.action);
  return next;
}

function validSection(value: DailyBriefSection | null | undefined): boolean {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) ||
    value.id !== 'today' && value.id !== 'yesterday' && value.id !== 'mail' &&
    value.id !== 'weather_commute' && value.id !== 'health' && value.id !== 'spending' ||
    !validText(value.title) || !validSourceState(value.state) || !validText(value.message) ||
    !Array.isArray(value.items) || value.items.length > 20) {
    return false;
  }
  for (let index = 0; index < value.items.length; index += 1) {
    if (!validItem(value.items[index])) return false;
  }
  return true;
}

function copySection(value: DailyBriefSection): DailyBriefSection {
  return {
    id: value.id,
    title: value.title,
    state: value.state,
    message: value.message,
    items: value.items.map((entry: DailyBriefItem): DailyBriefItem => copyItem(entry))
  };
}

function validHighlight(value: DailyBriefHighlight | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    (value.slot === 'time_constraint' || value.slot === 'action_needed' || value.slot === 'status_alert') &&
    validItem(value.item);
}

function copyHighlight(value: DailyBriefHighlight): DailyBriefHighlight {
  return { slot: value.slot, item: copyItem(value.item) };
}

function normalizedHttpUrl(value: string): string {
  let url = value.trim();
  const lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) return '';
  const fragment = url.indexOf('#');
  if (fragment >= 0) url = url.substring(0, fragment);
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) return '';
  const authorityStart = schemeEnd + 3;
  let authorityEnd = url.length;
  const slash = url.indexOf('/', authorityStart);
  const question = url.indexOf('?', authorityStart);
  if (slash >= 0 && slash < authorityEnd) authorityEnd = slash;
  if (question >= 0 && question < authorityEnd) authorityEnd = question;
  const authority = url.substring(authorityStart, authorityEnd).toLowerCase();
  if (authority.length === 0) return '';
  return lower.substring(0, schemeEnd) + '://' + authority + url.substring(authorityEnd);
}

function validCandidate(value: WaterfallRankedCandidate | null | undefined): boolean {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) ||
    !validText(value.id) || !validText(value.source) ||
    value.mediaType !== 'video' && value.mediaType !== 'image_text' && value.mediaType !== 'post' ||
    !validText(value.title) || !validText(value.summary) || !validText(value.url) ||
    !validText(value.coverUrl) || !validText(value.publishedAt) ||
    value.duration !== undefined && !validText(value.duration) ||
    value.mediaUrl !== undefined && normalizedHttpUrl(value.mediaUrl).length === 0 ||
    typeof value.originalIndex !== 'number' || !Number.isFinite(value.originalIndex) ||
    !validText(value.normalizedUrl) || normalizedHttpUrl(value.url) !== value.normalizedUrl ||
    value.signals === null || value.signals === undefined || typeof value.signals !== 'object' ||
    !Number.isFinite(value.signals.relevanceTier) || !Number.isFinite(value.signals.titleHits) ||
    !Number.isFinite(value.signals.summaryHits) || !Number.isFinite(value.signals.freshnessTier) ||
    !validText(value.reason)) {
    return false;
  }
  return true;
}

function copyCandidate(value: WaterfallRankedCandidate): WaterfallRankedCandidate {
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
  if (value.duration !== undefined) next.duration = value.duration;
  if (value.mediaUrl !== undefined) next.mediaUrl = value.mediaUrl;
  if (value.feedUrl !== undefined) next.feedUrl = value.feedUrl;
  if (value.audioTitle !== undefined) next.audioTitle = value.audioTitle;
  if (value.audioMimeType !== undefined) next.audioMimeType = value.audioMimeType;
  if (value.audioDuration !== undefined) next.audioDuration = value.audioDuration;
  if (value.audioPublishedAt !== undefined) next.audioPublishedAt = value.audioPublishedAt;
  if (value.audioLoadState !== undefined) next.audioLoadState = value.audioLoadState;
  if (value.audioError !== undefined) next.audioError = value.audioError;
  if (value.audioRetryable !== undefined) next.audioRetryable = value.audioRetryable;
  return next;
}

function validContinuation(value: WaterfallContinuation | null): boolean {
  return value === null || typeof value === 'object' && !Array.isArray(value) &&
    (value.kind === 'cursor' || value.kind === 'page' || value.kind === 'offset') &&
    validText(value.value);
}

function validWaterfallSource(value: WaterfallSourceState | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    validText(value.source) &&
    (value.phase === 'loading' || value.phase === 'success' || value.phase === 'empty' ||
      value.phase === 'needs_auth' || value.phase === 'error' || value.phase === 'exhausted') &&
    validContinuation(value.continuation) && typeof value.inFlight === 'boolean' &&
    typeof value.reservedCount === 'number' && Number.isFinite(value.reservedCount) &&
    validText(value.message);
}

function validCandidateArray(values: WaterfallRankedCandidate[]): boolean {
  if (!Array.isArray(values)) return false;
  for (let index = 0; index < values.length; index += 1) {
    if (!validCandidate(values[index])) return false;
  }
  return true;
}

function validWaterfall(value: WaterfallFeedState | null): boolean {
  if (value === null) return true;
  if (typeof value !== 'object' || Array.isArray(value) || !validText(value.query) ||
    !validTextArray(value.enabledSources) || !validText(value.preferenceDescription) ||
    !validCandidateArray(value.shown) || value.current !== null && !validCandidate(value.current) ||
    !validCandidateArray(value.stable) || !validCandidateArray(value.tail) || !Array.isArray(value.sources)) {
    return false;
  }
  for (let index = 0; index < value.sources.length; index += 1) {
    if (!validWaterfallSource(value.sources[index])) return false;
  }
  return true;
}

function copyWaterfall(value: WaterfallFeedState | null): WaterfallFeedState | null {
  if (value === null) return null;
  return {
    query: value.query,
    enabledSources: value.enabledSources.slice(),
    preferenceDescription: value.preferenceDescription,
    shown: value.shown.map((entry: WaterfallRankedCandidate): WaterfallRankedCandidate => copyCandidate(entry)),
    current: value.current === null ? null : copyCandidate(value.current),
    stable: value.stable.map((entry: WaterfallRankedCandidate): WaterfallRankedCandidate => copyCandidate(entry)),
    tail: value.tail.map((entry: WaterfallRankedCandidate): WaterfallRankedCandidate => copyCandidate(entry)),
    sources: value.sources.map((entry: WaterfallSourceState): WaterfallSourceState => {
      let continuation: WaterfallContinuation | null = null;
      if (entry.continuation !== null) {
        continuation = { kind: entry.continuation.kind, value: entry.continuation.value };
      }
      return {
        source: entry.source,
        phase: entry.phase,
        continuation: continuation,
        inFlight: entry.inFlight,
        reservedCount: entry.reservedCount,
        message: entry.message
      };
    })
  };
}

function candidateForDiscovery(
  waterfall: WaterfallFeedState | null,
  discovery: DailyBriefDiscoveryItem
): WaterfallRankedCandidate | null {
  if (waterfall === null) return null;
  const candidates: WaterfallRankedCandidate[] = [];
  if (waterfall.current !== null) candidates.push(waterfall.current);
  waterfall.shown.forEach((value: WaterfallRankedCandidate): void => { candidates.push(value); });
  waterfall.stable.forEach((value: WaterfallRankedCandidate): void => { candidates.push(value); });
  waterfall.tail.forEach((value: WaterfallRankedCandidate): void => { candidates.push(value); });
  for (let index = 0; index < candidates.length; index += 1) {
    const value = candidates[index];
    if (value.id === discovery.id && value.url === discovery.url && value.source === discovery.source &&
      value.mediaType === discovery.mediaType && value.title === discovery.title &&
      value.summary === discovery.summary) {
      return value;
    }
  }
  return null;
}

function validDiscovery(value: DailyBriefDiscoveryItem, waterfall: WaterfallFeedState | null): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    validText(value.id) && validText(value.source) &&
    (value.mediaType === 'video' || value.mediaType === 'image_text' || value.mediaType === 'post') &&
    validText(value.title) && validText(value.summary) && validText(value.url) &&
    normalizedHttpUrl(value.url).length > 0 && validText(value.reason) &&
    validText(value.timeBudgetLabel) && candidateForDiscovery(waterfall, value) !== null;
}

function copyDiscovery(value: DailyBriefDiscoveryItem): DailyBriefDiscoveryItem {
  return {
    id: value.id,
    source: value.source,
    mediaType: value.mediaType,
    title: value.title,
    summary: value.summary,
    url: value.url,
    reason: value.reason,
    timeBudgetLabel: value.timeBudgetLabel
  };
}

function validSourceSummary(value: DailyBriefSourceSummary | null | undefined): boolean {
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value) &&
    validSourceId(value.sourceId) && validSourceState(value.state) && validText(value.message);
}

function validSnapshot(value: DailyBriefSnapshot | null | undefined): boolean {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) ||
    value.schemaVersion !== 1 || !validDate(value.date) || !validTimestamp(value.generatedAt) ||
    value.status !== 'complete' && value.status !== 'partial' || !validPreference(value.profile) ||
    !Array.isArray(value.topThree) || value.topThree.length > 3 || !Array.isArray(value.sections) ||
    value.sections.length > 6 || !Array.isArray(value.discovery) || value.discovery.length > 3 ||
    !Array.isArray(value.sources) || !validWaterfall(value.waterfall) || !Array.isArray(value.actions)) {
    return false;
  }
  for (let index = 0; index < value.topThree.length; index += 1) {
    if (!validHighlight(value.topThree[index])) return false;
  }
  for (let index = 0; index < value.sections.length; index += 1) {
    if (!validSection(value.sections[index])) return false;
  }
  for (let index = 0; index < value.discovery.length; index += 1) {
    if (!validDiscovery(value.discovery[index], value.waterfall)) return false;
  }
  for (let index = 0; index < value.sources.length; index += 1) {
    if (!validSourceSummary(value.sources[index])) return false;
  }
  for (let index = 0; index < value.actions.length; index += 1) {
    if (!isValidDailyBriefAction(value.actions[index])) return false;
  }
  return true;
}

function copySnapshot(value: DailyBriefSnapshot): DailyBriefSnapshot {
  return {
    schemaVersion: 1,
    date: value.date,
    generatedAt: value.generatedAt,
    status: value.status,
    profile: copyPreference(value.profile),
    topThree: value.topThree.map((entry: DailyBriefHighlight): DailyBriefHighlight => copyHighlight(entry)),
    sections: value.sections.map((entry: DailyBriefSection): DailyBriefSection => copySection(entry)),
    discovery: value.discovery.map((entry: DailyBriefDiscoveryItem): DailyBriefDiscoveryItem =>
      copyDiscovery(entry)),
    sources: value.sources.map((entry: DailyBriefSourceSummary): DailyBriefSourceSummary => {
      return { sourceId: entry.sourceId, state: entry.state, message: entry.message };
    }),
    waterfall: copyWaterfall(value.waterfall),
    actions: value.actions.map((entry: A2uiAction): A2uiAction => copyAction(entry))
  };
}

function sortedSnapshots(values: DailyBriefSnapshot[]): DailyBriefSnapshot[] {
  const result: DailyBriefSnapshot[] = [];
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!validSnapshot(value)) continue;
    const copy = copySnapshot(value);
    let replaced = false;
    for (let existing = 0; existing < result.length; existing += 1) {
      if (result[existing].date === copy.date) {
        result[existing] = copy;
        replaced = true;
        break;
      }
    }
    if (!replaced) result.push(copy);
  }
  result.sort((left: DailyBriefSnapshot, right: DailyBriefSnapshot): number =>
    left.date < right.date ? -1 : left.date > right.date ? 1 : 0);
  return result.length <= HISTORY_LIMIT ? result : result.slice(result.length - HISTORY_LIMIT);
}

export function parseDailyBriefPreference(raw: string): DailyBriefPreference {
  try {
    const parsed = JSON.parse(raw) as DailyBriefPreference;
    return validPreference(parsed) ? copyPreference(parsed) : defaultDailyBriefPreference();
  } catch (_error) {
    return defaultDailyBriefPreference();
  }
}

export function parseDailyBriefSnapshots(raw: string): DailyBriefSnapshot[] {
  try {
    const parsed = JSON.parse(raw) as DailyBriefSnapshot[];
    return Array.isArray(parsed) ? sortedSnapshots(parsed) : [];
  } catch (_error) {
    return [];
  }
}

export function serializeDailyBriefSnapshots(values: DailyBriefSnapshot[]): string {
  return JSON.stringify(sortedSnapshots(values));
}

export function replaceDailyBriefSnapshot(
  values: DailyBriefSnapshot[],
  next: DailyBriefSnapshot
): DailyBriefSnapshot[] {
  if (!validSnapshot(next)) return sortedSnapshots(values);
  const candidates: DailyBriefSnapshot[] = [];
  for (let index = 0; index < values.length; index += 1) {
    if (values[index].date !== next.date) candidates.push(values[index]);
  }
  candidates.push(next);
  return sortedSnapshots(candidates);
}

export class DailyBriefStore {
  private store: preferences.Preferences | null = null;

  constructor(context: common.Context, storeName: string = DAILY_BRIEF_STORE_NAME) {
    try {
      this.store = preferences.getPreferencesSync(context, { name: storeName });
    } catch (_error) {
      this.store = null;
    }
  }

  loadPreference(): DailyBriefPreference {
    if (this.store === null) return defaultDailyBriefPreference();
    try {
      return parseDailyBriefPreference(text(this.store.getSync(SETTINGS_KEY, '')));
    } catch (_error) {
      return defaultDailyBriefPreference();
    }
  }

  savePreference(value: DailyBriefPreference): boolean {
    if (this.store === null || !validPreference(value)) return false;
    try {
      this.store.putSync(SETTINGS_KEY, JSON.stringify(copyPreference(value)));
      this.store.flushSync();
      return true;
    } catch (_error) {
      return false;
    }
  }

  loadSnapshots(): DailyBriefSnapshot[] {
    if (this.store === null) return [];
    try {
      return parseDailyBriefSnapshots(text(this.store.getSync(SNAPSHOTS_KEY, '')));
    } catch (_error) {
      return [];
    }
  }

  snapshotForDate(date: string): DailyBriefSnapshot | null {
    if (!validDate(date)) return null;
    const values = this.loadSnapshots();
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].date === date) return copySnapshot(values[index]);
    }
    return null;
  }

  saveSnapshot(value: DailyBriefSnapshot): boolean {
    if (this.store === null || !validSnapshot(value)) return false;
    try {
      const replacement = replaceDailyBriefSnapshot(this.loadSnapshots(), value);
      const json = serializeDailyBriefSnapshots(replacement);
      this.store.putSync(SNAPSHOTS_KEY, json);
      this.store.flushSync();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
