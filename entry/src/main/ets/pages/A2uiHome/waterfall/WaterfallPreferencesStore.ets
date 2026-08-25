import { preferences } from '@kit.ArkData';
import {
  aggregateSearchDefaultEnabledSourceIds,
  aggregateSearchDefaultEnabledSourceIdsAfter,
  aggregateSearchRegistryVersion,
  aggregateSearchRegistrySourceIds,
  redditImageDeliveryUrl,
  WaterfallCandidate,
  WaterfallComment,
  WaterfallCommentLoadState,
  WaterfallExplicitPreference,
  WaterfallFormat,
  WaterfallMediaType,
  WaterfallMetric,
  WaterfallPreferenceSnapshot,
  WaterfallPreferenceWeight
} from '@loop/agent-core';

export const WATERFALL_PREFERENCES_STORE_NAME: string = 'aiphone_waterfall_preferences';
export const WATERFALL_PREFERENCES_KEY: string = 'profile.v1';
export const WATERFALL_CARDS_KEY: string = 'cards.v1';
const THIRTY_DAYS_MS: number = 30 * 24 * 60 * 60 * 1000;
const MAX_WEIGHT: number = 20;
const MAX_EVIDENCE: number = 500;
const REGISTERED_SOURCES: string[] = aggregateSearchRegistrySourceIds();

export type WaterfallCardReaction = 'like' | 'dislike' | 'none';
export type WaterfallCardAction = 'like' | 'dislike' | 'save';

export interface WaterfallSavedCard {
  id: string;
  source: string;
  provider?: string;
  mediaType: WaterfallMediaType;
  title: string;
  summary: string;
  url: string;
  coverUrl: string;
  mediaUrl?: string;
  providerItemId?: string;
  comments?: WaterfallComment[];
  commentLoadState?: WaterfallCommentLoadState;
  publishedAt: string;
  authorName: string;
  authorAvatarUrl: string;
  metrics: WaterfallMetric[];
  topics: string[];
  format: WaterfallFormat;
}

export interface WaterfallCardRecord {
  candidateId: string;
  reaction: WaterfallCardReaction;
  reactedAt: number;
  saved: boolean;
  savedAt: number;
  snapshot: WaterfallSavedCard;
}

export interface WaterfallReactionProjection {
  topicWeights: WaterfallPreferenceWeight[];
  sourceWeights: WaterfallPreferenceWeight[];
  formatWeights: WaterfallPreferenceWeight[];
}

interface StoredWaterfallCards {
  version: number;
  records: WaterfallCardRecord[];
}

export interface WaterfallBehaviorEvidence {
  candidateId: string;
  topics: string[];
  source: string;
  format: WaterfallFormat;
  behavior: 'play_complete' | 'read_complete' | 'dwell' | 'quick_skip';
  durationMs: number;
  timestamp: number;
}

export interface WaterfallPreferenceProfile extends WaterfallPreferenceSnapshot {
  version: 2;
  sourceRegistryVersion?: number;
  recentEvidence: WaterfallBehaviorEvidence[];
  discoveryEnabledSources: string[];
  // Compatibility alias for callers migrating to discoveryEnabledSources.
  enabledSources: string[];
  updatedAt: number;
}

interface StoredWaterfallPreferenceProfile extends WaterfallPreferenceSnapshot {
  version: number;
  sourceRegistryVersion?: number;
  recentEvidence: WaterfallBehaviorEvidence[];
  discoveryEnabledSources?: string[];
  enabledSources?: string[];
  updatedAt: number;
}

export function emptyWaterfallPreferenceProfile(): WaterfallPreferenceProfile {
  return {
    version: 2,
    sourceRegistryVersion: aggregateSearchRegistryVersion(),
    topicWeights: [],
    sourceWeights: [],
    formatWeights: [],
    explicitRules: [],
    recentEvidence: [],
    discoveryEnabledSources: aggregateSearchDefaultEnabledSourceIds(),
    enabledSources: aggregateSearchDefaultEnabledSourceIds(),
    updatedAt: 0
  };
}

function validWeight(value: WaterfallPreferenceWeight): boolean {
  return value !== null && typeof value.key === 'string' && value.key.trim().length > 0 &&
    typeof value.weight === 'number' && isFinite(value.weight) &&
    typeof value.updatedAt === 'number' && isFinite(value.updatedAt);
}

function validRule(value: WaterfallExplicitPreference): boolean {
  return value !== null &&
    (value.dimension === 'topic' || value.dimension === 'source' || value.dimension === 'format') &&
    typeof value.key === 'string' && value.key.trim().length > 0 &&
    (value.effect === 'block' || value.effect === 'downweight' || value.effect === 'boost');
}

function validEvidence(value: WaterfallBehaviorEvidence): boolean {
  return value !== null && typeof value.candidateId === 'string' && value.candidateId.length > 0 &&
    Array.isArray(value.topics) && typeof value.source === 'string' &&
    (value.format === 'landscape_video' || value.format === 'portrait_video' ||
      value.format === 'image_text' || value.format === 'text') &&
    (value.behavior === 'play_complete' || value.behavior === 'read_complete' ||
      value.behavior === 'dwell' || value.behavior === 'quick_skip') &&
    typeof value.durationMs === 'number' && value.durationMs >= 0 &&
    typeof value.timestamp === 'number' && isFinite(value.timestamp);
}

function validSources(value: string[] | undefined): boolean {
  if (!Array.isArray(value)) return false;
  return value.every((item: string): boolean => typeof item === 'string' && item.trim().length > 0);
}

function validProfile(value: StoredWaterfallPreferenceProfile): boolean {
  if (value === null || (value.version !== 1 && value.version !== 2) || !Array.isArray(value.topicWeights) ||
    !Array.isArray(value.sourceWeights) || !Array.isArray(value.formatWeights) ||
    !Array.isArray(value.explicitRules) || !Array.isArray(value.recentEvidence) ||
    typeof value.updatedAt !== 'number') {
    return false;
  }
  const sources = value.version === 2 ? value.discoveryEnabledSources : value.enabledSources;
  return validSources(sources) &&
    value.topicWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.sourceWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.formatWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.explicitRules.every((item: WaterfallExplicitPreference): boolean => validRule(item)) &&
    value.recentEvidence.every((item: WaterfallBehaviorEvidence): boolean => validEvidence(item)) &&
    (value.sourceRegistryVersion === undefined ||
      (typeof value.sourceRegistryVersion === 'number' && isFinite(value.sourceRegistryVersion) &&
        value.sourceRegistryVersion >= 1));
}

function profileSourceRegistryVersion(value: StoredWaterfallPreferenceProfile | WaterfallPreferenceProfile): number {
  if (value.sourceRegistryVersion === undefined || !isFinite(value.sourceRegistryVersion)) {
    return 1;
  }
  return Math.max(1, Math.floor(value.sourceRegistryVersion));
}

function migratedEnabledSources(
  sources: string[],
  value: StoredWaterfallPreferenceProfile | WaterfallPreferenceProfile
): string[] {
  const enabled = sources.filter((source: string): boolean => REGISTERED_SOURCES.indexOf(source) >= 0);
  aggregateSearchDefaultEnabledSourceIdsAfter(profileSourceRegistryVersion(value)).forEach(
    (source: string): void => {
      if (enabled.indexOf(source) < 0) enabled.push(source);
    });
  return enabled;
}

function copyWeight(value: WaterfallPreferenceWeight): WaterfallPreferenceWeight {
  return { key: value.key, weight: value.weight, updatedAt: value.updatedAt };
}

function copyRule(value: WaterfallExplicitPreference): WaterfallExplicitPreference {
  return { dimension: value.dimension, key: value.key, effect: value.effect };
}

function copyEvidence(value: WaterfallBehaviorEvidence): WaterfallBehaviorEvidence {
  return {
    candidateId: value.candidateId,
    topics: value.topics.slice(),
    source: value.source,
    format: value.format,
    behavior: value.behavior,
    durationMs: value.durationMs,
    timestamp: value.timestamp
  };
}

function copyProfile(value: WaterfallPreferenceProfile): WaterfallPreferenceProfile {
  const sources = migratedEnabledSources(value.discoveryEnabledSources, value);
  return {
    version: 2,
    sourceRegistryVersion: aggregateSearchRegistryVersion(),
    topicWeights: value.topicWeights.map(copyWeight),
    sourceWeights: value.sourceWeights.map(copyWeight),
    formatWeights: value.formatWeights.map(copyWeight),
    explicitRules: value.explicitRules.map(copyRule),
    recentEvidence: value.recentEvidence.map(copyEvidence),
    discoveryEnabledSources: sources,
    enabledSources: sources.slice(),
    updatedAt: value.updatedAt
  };
}

function migrateProfile(value: StoredWaterfallPreferenceProfile): WaterfallPreferenceProfile {
  const storedSources = value.version === 2 ? value.discoveryEnabledSources as string[] : value.enabledSources as string[];
  const sources = migratedEnabledSources(storedSources, value);
  return {
    version: 2,
    sourceRegistryVersion: aggregateSearchRegistryVersion(),
    topicWeights: value.topicWeights.map(copyWeight),
    sourceWeights: value.sourceWeights.map(copyWeight),
    formatWeights: value.formatWeights.map(copyWeight),
    explicitRules: value.explicitRules.map(copyRule),
    recentEvidence: value.recentEvidence.map(copyEvidence),
    discoveryEnabledSources: sources,
    enabledSources: sources.slice(),
    updatedAt: value.updatedAt
  };
}

function parsedProfile(raw: string): WaterfallPreferenceProfile {
  if (raw.trim().length === 0) return emptyWaterfallPreferenceProfile();
  try {
    const value = JSON.parse(raw) as StoredWaterfallPreferenceProfile;
    return validProfile(value) ? migrateProfile(value) : emptyWaterfallPreferenceProfile();
  } catch (_error) {
    return emptyWaterfallPreferenceProfile();
  }
}

function validMetric(value: WaterfallMetric): boolean {
  return value !== null && typeof value.kind === 'string' && value.kind.trim().length > 0 &&
    typeof value.value === 'number' && isFinite(value.value);
}

function validComment(value: WaterfallComment): boolean {
  return value !== null && typeof value.text === 'string' &&
    (value.authorName === undefined || typeof value.authorName === 'string') &&
    (value.authorAvatarUrl === undefined || typeof value.authorAvatarUrl === 'string') &&
    (value.publishedAt === undefined || typeof value.publishedAt === 'string') &&
    (value.likeCount === undefined || (typeof value.likeCount === 'number' && isFinite(value.likeCount))) &&
    (value.replyCount === undefined || (typeof value.replyCount === 'number' && isFinite(value.replyCount)));
}

function validSavedCard(value: WaterfallSavedCard): boolean {
  return value !== null && typeof value.id === 'string' && value.id.trim().length > 0 &&
    typeof value.source === 'string' && value.source.trim().length > 0 &&
    (value.provider === undefined || typeof value.provider === 'string') &&
    (value.mediaType === 'video' || value.mediaType === 'image_text' || value.mediaType === 'post') &&
    typeof value.title === 'string' && typeof value.summary === 'string' && typeof value.url === 'string' &&
    typeof value.coverUrl === 'string' &&
    (value.mediaUrl === undefined || typeof value.mediaUrl === 'string') &&
    (value.providerItemId === undefined || typeof value.providerItemId === 'string') &&
    (value.comments === undefined || (Array.isArray(value.comments) &&
      value.comments.every((comment: WaterfallComment): boolean => validComment(comment)))) &&
    (value.commentLoadState === undefined || value.commentLoadState === 'loading' ||
      value.commentLoadState === 'ready' || value.commentLoadState === 'empty' ||
      value.commentLoadState === 'error') &&
    typeof value.publishedAt === 'string' &&
    typeof value.authorName === 'string' && typeof value.authorAvatarUrl === 'string' &&
    Array.isArray(value.metrics) && value.metrics.every((metric: WaterfallMetric): boolean => validMetric(metric)) &&
    Array.isArray(value.topics) && value.topics.every((topic: string): boolean =>
      typeof topic === 'string' && topic.trim().length > 0) &&
    (value.format === 'landscape_video' || value.format === 'portrait_video' ||
      value.format === 'image_text' || value.format === 'text');
}

function validCardRecord(value: WaterfallCardRecord): boolean {
  return value !== null && typeof value.candidateId === 'string' && value.candidateId.trim().length > 0 &&
    (value.reaction === 'like' || value.reaction === 'dislike' || value.reaction === 'none') &&
    typeof value.reactedAt === 'number' && isFinite(value.reactedAt) && value.reactedAt >= 0 &&
    typeof value.saved === 'boolean' && typeof value.savedAt === 'number' && isFinite(value.savedAt) &&
    value.savedAt >= 0 && validSavedCard(value.snapshot) && value.snapshot.id === value.candidateId;
}

function copyMetric(value: WaterfallMetric): WaterfallMetric {
  return { kind: value.kind, value: value.value };
}

function copyComment(value: WaterfallComment): WaterfallComment {
  return {
    text: value.text,
    authorName: value.authorName,
    authorAvatarUrl: value.authorAvatarUrl,
    publishedAt: value.publishedAt,
    likeCount: value.likeCount,
    replyCount: value.replyCount
  };
}

function copySavedCard(value: WaterfallSavedCard): WaterfallSavedCard {
  return {
    id: value.id,
    source: value.source,
    provider: value.provider,
    mediaType: value.mediaType,
    title: value.title,
    summary: value.summary,
    url: value.url,
    coverUrl: redditImageDeliveryUrl(value.coverUrl),
    mediaUrl: value.mediaUrl ?? '',
    providerItemId: value.providerItemId,
    comments: value.comments?.slice(0, 5).map(copyComment),
    commentLoadState: value.commentLoadState === 'loading' ? undefined : value.commentLoadState,
    publishedAt: value.publishedAt,
    authorName: value.authorName,
    authorAvatarUrl: value.authorAvatarUrl,
    metrics: value.metrics.map(copyMetric),
    topics: value.topics.slice(),
    format: value.format
  };
}

function copyCardRecord(value: WaterfallCardRecord): WaterfallCardRecord {
  return {
    candidateId: value.candidateId,
    reaction: value.reaction,
    reactedAt: value.reactedAt,
    saved: value.saved,
    savedAt: value.savedAt,
    snapshot: copySavedCard(value.snapshot)
  };
}

function parsedCardRecords(raw: string): WaterfallCardRecord[] {
  if (raw.trim().length === 0) return [];
  try {
    const value = JSON.parse(raw) as StoredWaterfallCards;
    if (value === null || value.version !== 1 || !Array.isArray(value.records) ||
      !value.records.every((record: WaterfallCardRecord): boolean => validCardRecord(record))) return [];
    return value.records.map(copyCardRecord);
  } catch (_error) {
    return [];
  }
}

function formatForCandidate(candidate: WaterfallCandidate): WaterfallFormat {
  return candidate.format ?? (candidate.mediaType === 'video' ? 'landscape_video' :
    (candidate.mediaType === 'image_text' ? 'image_text' : 'text'));
}

function savedCardFromCandidate(candidate: WaterfallCandidate): WaterfallSavedCard {
  return {
    id: candidate.id.trim(),
    source: candidate.source.trim(),
    provider: candidate.provider?.trim(),
    mediaType: candidate.mediaType,
    title: candidate.title,
    summary: candidate.summary,
    url: candidate.url,
    coverUrl: candidate.coverUrl,
    mediaUrl: candidate.mediaUrl ?? '',
    providerItemId: candidate.providerItemId,
    comments: candidate.comments?.slice(0, 5).map(copyComment),
    commentLoadState: candidate.commentLoadState === 'loading' ? undefined : candidate.commentLoadState,
    publishedAt: candidate.publishedAt,
    authorName: candidate.authorName ?? '',
    authorAvatarUrl: candidate.authorAvatarUrl ?? '',
    metrics: (candidate.metrics ?? []).map(copyMetric),
    topics: dedupeStrings(candidate.topics ?? []),
    format: formatForCandidate(candidate)
  };
}

export function waterfallCandidateFromSavedCard(value: WaterfallSavedCard): WaterfallCandidate {
  return {
    id: value.id,
    source: value.source,
    provider: value.provider,
    mediaType: value.mediaType,
    title: value.title,
    summary: value.summary,
    url: value.url,
    coverUrl: value.coverUrl,
    mediaUrl: value.mediaUrl ?? '',
    providerItemId: value.providerItemId,
    comments: value.comments?.slice(0, 5).map(copyComment),
    commentLoadState: value.commentLoadState,
    publishedAt: value.publishedAt,
    originalIndex: 0,
    authorName: value.authorName,
    authorAvatarUrl: value.authorAvatarUrl,
    metrics: value.metrics.map(copyMetric),
    topics: value.topics.slice(),
    format: value.format
  };
}

function dedupeStrings(values: string[]): string[] {
  const result: string[] = [];
  values.forEach((value: string): void => {
    const clean = value.trim();
    if (clean.length > 0 && result.indexOf(clean) < 0) result.push(clean);
  });
  return result;
}

function addReactionWeight(
  weights: WaterfallPreferenceWeight[],
  key: string,
  delta: number,
  updatedAt: number
): void {
  const clean = key.trim();
  if (clean.length === 0) return;
  for (let index = 0; index < weights.length; index += 1) {
    if (weights[index].key !== clean) continue;
    weights[index] = {
      key: clean,
      weight: Math.max(-MAX_WEIGHT, Math.min(MAX_WEIGHT, weights[index].weight + delta)),
      updatedAt: Math.max(weights[index].updatedAt, updatedAt)
    };
    return;
  }
  weights.push({ key: clean, weight: delta, updatedAt });
}

export function waterfallReactionWeights(records: WaterfallCardRecord[]): WaterfallReactionProjection {
  const projection: WaterfallReactionProjection = { topicWeights: [], sourceWeights: [], formatWeights: [] };
  records.forEach((record: WaterfallCardRecord): void => {
    if (record.reaction === 'none') return;
    const delta = record.reaction === 'like' ? 4 : -4;
    dedupeStrings(record.snapshot.topics).forEach((topic: string): void => {
      addReactionWeight(projection.topicWeights, topic, delta, record.reactedAt);
    });
    addReactionWeight(projection.sourceWeights, record.snapshot.source, delta, record.reactedAt);
    addReactionWeight(projection.formatWeights, record.snapshot.format, delta, record.reactedAt);
  });
  return projection;
}

export function updateWaterfallPreferenceWeight(
  weights: WaterfallPreferenceWeight[],
  key: string,
  delta: number,
  timestamp: number
): void {
  for (let index = 0; index < weights.length; index += 1) {
    if (weights[index].key !== key) continue;
    const elapsed = Math.max(0, timestamp - weights[index].updatedAt);
    const decayed = weights[index].weight * Math.pow(0.5, elapsed / THIRTY_DAYS_MS);
    weights[index] = {
      key,
      weight: Math.max(-MAX_WEIGHT, Math.min(MAX_WEIGHT, decayed + delta)),
      updatedAt: timestamp
    };
    return;
  }
  weights.push({ key, weight: Math.max(-MAX_WEIGHT, Math.min(MAX_WEIGHT, delta)), updatedAt: timestamp });
}

export function waterfallBehaviorDelta(
  event: WaterfallBehaviorEvidence,
  evidence: WaterfallBehaviorEvidence[]
): number {
  if (event.behavior === 'play_complete') return 3;
  if (event.behavior === 'read_complete') return 2;
  if (event.behavior === 'dwell') return 1;
  for (let index = evidence.length - 1; index >= 0; index -= 1) {
    if (evidence[index].behavior !== 'quick_skip') continue;
    if (evidence[index].source === event.source) return -0.5;
    for (let topicIndex = 0; topicIndex < event.topics.length; topicIndex += 1) {
      if (evidence[index].topics.indexOf(event.topics[topicIndex]) >= 0) return -0.5;
    }
  }
  return 0;
}

function dedupeRules(values: WaterfallExplicitPreference[]): WaterfallExplicitPreference[] {
  const result: WaterfallExplicitPreference[] = [];
  values.forEach((value: WaterfallExplicitPreference): void => {
    if (!validRule(value)) return;
    const key = value.key.trim();
    for (let index = result.length - 1; index >= 0; index -= 1) {
      if (result[index].dimension === value.dimension && result[index].key === key) result.splice(index, 1);
    }
    result.push({ dimension: value.dimension, key, effect: value.effect });
  });
  return result;
}

export class WaterfallPreferencesStore {
  private readonly store: preferences.Preferences;
  private profile: WaterfallPreferenceProfile | null = null;
  private cardRecords: WaterfallCardRecord[] | null = null;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  load(): WaterfallPreferenceProfile {
    if (this.profile === null) {
      const value = this.store.getSync(WATERFALL_PREFERENCES_KEY, '');
      this.profile = parsedProfile(typeof value === 'string' ? value : '');
    }
    return copyProfile(this.profile);
  }

  loadForNewSession(): WaterfallPreferenceProfile {
    const profile = this.load();
    profile.discoveryEnabledSources = aggregateSearchDefaultEnabledSourceIds();
    profile.enabledSources = profile.discoveryEnabledSources.slice();
    profile.updatedAt = Date.now();
    return this.save(profile);
  }

  loadCardRecords(): WaterfallCardRecord[] {
    if (this.cardRecords === null) {
      const value = this.store.getSync(WATERFALL_CARDS_KEY, '');
      this.cardRecords = parsedCardRecords(typeof value === 'string' ? value : '');
    }
    return this.cardRecords.map(copyCardRecord);
  }

  private saveCardRecords(records: WaterfallCardRecord[]): WaterfallCardRecord[] {
    let retained = records;
    if (records.length > 500) {
      // ponytail: protect up to 500 favorites; split collection storage if that ceiling becomes real.
      const saved = records.filter((record: WaterfallCardRecord): boolean => record.saved);
      const otherCapacity = Math.max(0, 500 - saved.length);
      const other = records.filter((record: WaterfallCardRecord): boolean => !record.saved);
      retained = saved.length >= 500 ? saved.slice(saved.length - 500) :
        saved.concat(other.slice(Math.max(0, other.length - otherCapacity)));
    }
    this.cardRecords = retained.map(copyCardRecord);
    const stored: StoredWaterfallCards = { version: 1, records: this.cardRecords };
    this.store.putSync(WATERFALL_CARDS_KEY, JSON.stringify(stored));
    this.store.flush().catch((error: Error): void => {
      console.warn('[AIPhone][WaterfallCardsFlushFailed] ' + error.message.substring(0, 160));
    });
    return this.cardRecords.map(copyCardRecord);
  }

  applyCardAction(
    candidate: WaterfallCandidate,
    action: WaterfallCardAction,
    active: boolean,
    timestamp: number,
    restoreSavedAt: boolean = false
  ): WaterfallCardRecord[] {
    if (candidate.id.trim().length === 0 || candidate.source.trim().length === 0 ||
      !isFinite(timestamp) || timestamp <= 0) return this.loadCardRecords();
    const records = this.loadCardRecords();
    let recordIndex = -1;
    for (let index = 0; index < records.length; index += 1) {
      if (records[index].candidateId === candidate.id) {
        recordIndex = index;
        break;
      }
    }
    if (recordIndex < 0 && !active) return records;
    if (recordIndex < 0) {
      records.push({
        candidateId: candidate.id,
        reaction: 'none',
        reactedAt: 0,
        saved: false,
        savedAt: 0,
        snapshot: savedCardFromCandidate(candidate)
      });
      recordIndex = records.length - 1;
    }
    const record = records[recordIndex];
    record.snapshot = savedCardFromCandidate(candidate);
    if (action === 'save') {
      if (active) {
        record.savedAt = restoreSavedAt && record.savedAt > 0 ? record.savedAt : timestamp;
      }
      record.saved = active;
    } else if (active) {
      record.reaction = action;
      record.reactedAt = timestamp;
    } else if (record.reaction === action) {
      record.reaction = 'none';
      record.reactedAt = timestamp;
    }
    return this.saveCardRecords(records);
  }

  private save(profile: WaterfallPreferenceProfile): WaterfallPreferenceProfile {
    this.profile = copyProfile(profile);
    this.store.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify(this.profile));
    this.store.flush().catch((error: Error): void => {
      console.warn('[AIPhone][WaterfallPreferencesFlushFailed] ' + error.message.substring(0, 160));
    });
    return copyProfile(this.profile);
  }

  recordBehavior(event: WaterfallBehaviorEvidence): WaterfallPreferenceProfile {
    if (!validEvidence(event)) return this.load();
    const profile = this.load();
    const delta = waterfallBehaviorDelta(event, profile.recentEvidence);
    if (delta !== 0) {
      dedupeStrings(event.topics).forEach((topic: string): void => {
        updateWaterfallPreferenceWeight(profile.topicWeights, topic, delta, event.timestamp);
      });
      updateWaterfallPreferenceWeight(profile.sourceWeights, event.source, delta, event.timestamp);
      updateWaterfallPreferenceWeight(profile.formatWeights, event.format, delta, event.timestamp);
    }
    profile.recentEvidence.push(copyEvidence(event));
    if (profile.recentEvidence.length > MAX_EVIDENCE) {
      profile.recentEvidence = profile.recentEvidence.slice(profile.recentEvidence.length - MAX_EVIDENCE);
    }
    profile.updatedAt = event.timestamp;
    return this.save(profile);
  }

  applyExplicitPreference(preference: WaterfallExplicitPreference): WaterfallPreferenceProfile {
    const profile = this.load();
    profile.explicitRules = dedupeRules(profile.explicitRules.concat([preference]));
    profile.updatedAt = Date.now();
    return this.save(profile);
  }

  replaceExplicitPreferences(values: WaterfallExplicitPreference[]): WaterfallPreferenceProfile {
    const profile = this.load();
    profile.explicitRules = dedupeRules(values);
    profile.updatedAt = Date.now();
    return this.save(profile);
  }

  saveDiscoveryEnabledSources(sources: string[]): WaterfallPreferenceProfile {
    const profile = this.load();
    profile.discoveryEnabledSources = dedupeStrings(sources).filter((source: string): boolean =>
      REGISTERED_SOURCES.indexOf(source) >= 0);
    profile.enabledSources = profile.discoveryEnabledSources.slice();
    profile.updatedAt = Date.now();
    return this.save(profile);
  }

  saveEnabledSources(sources: string[]): WaterfallPreferenceProfile {
    return this.saveDiscoveryEnabledSources(sources);
  }
}
