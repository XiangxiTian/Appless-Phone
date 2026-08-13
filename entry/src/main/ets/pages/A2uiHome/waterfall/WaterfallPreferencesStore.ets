import { preferences } from '@kit.ArkData';
import {
  WaterfallExplicitPreference,
  WaterfallFormat,
  WaterfallPreferenceSnapshot,
  WaterfallPreferenceWeight
} from '@loop/agent-core';

export const WATERFALL_PREFERENCES_STORE_NAME: string = 'aiphone_waterfall_preferences';
export const WATERFALL_PREFERENCES_KEY: string = 'profile.v1';
const THIRTY_DAYS_MS: number = 30 * 24 * 60 * 60 * 1000;
const MAX_WEIGHT: number = 20;
const MAX_EVIDENCE: number = 500;
const DEFAULT_SOURCES: string[] = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];

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
  version: 1;
  recentEvidence: WaterfallBehaviorEvidence[];
  enabledSources: string[];
  updatedAt: number;
}

export function emptyWaterfallPreferenceProfile(): WaterfallPreferenceProfile {
  return {
    version: 1,
    topicWeights: [],
    sourceWeights: [],
    formatWeights: [],
    explicitRules: [],
    recentEvidence: [],
    enabledSources: DEFAULT_SOURCES.slice(),
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

function validProfile(value: WaterfallPreferenceProfile): boolean {
  if (value === null || value.version !== 1 || !Array.isArray(value.topicWeights) ||
    !Array.isArray(value.sourceWeights) || !Array.isArray(value.formatWeights) ||
    !Array.isArray(value.explicitRules) || !Array.isArray(value.recentEvidence) ||
    !Array.isArray(value.enabledSources) || typeof value.updatedAt !== 'number') {
    return false;
  }
  return value.topicWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.sourceWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.formatWeights.every((item: WaterfallPreferenceWeight): boolean => validWeight(item)) &&
    value.explicitRules.every((item: WaterfallExplicitPreference): boolean => validRule(item)) &&
    value.recentEvidence.every((item: WaterfallBehaviorEvidence): boolean => validEvidence(item)) &&
    value.enabledSources.every((item: string): boolean => DEFAULT_SOURCES.indexOf(item) >= 0);
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
  return {
    version: 1,
    topicWeights: value.topicWeights.map(copyWeight),
    sourceWeights: value.sourceWeights.map(copyWeight),
    formatWeights: value.formatWeights.map(copyWeight),
    explicitRules: value.explicitRules.map(copyRule),
    recentEvidence: value.recentEvidence.map(copyEvidence),
    enabledSources: value.enabledSources.slice(),
    updatedAt: value.updatedAt
  };
}

function parsedProfile(raw: string): WaterfallPreferenceProfile {
  if (raw.trim().length === 0) return emptyWaterfallPreferenceProfile();
  try {
    const value = JSON.parse(raw) as WaterfallPreferenceProfile;
    return validProfile(value) ? copyProfile(value) : emptyWaterfallPreferenceProfile();
  } catch (_error) {
    return emptyWaterfallPreferenceProfile();
  }
}

function dedupeStrings(values: string[]): string[] {
  const result: string[] = [];
  values.forEach((value: string): void => {
    const clean = value.trim();
    if (clean.length > 0 && result.indexOf(clean) < 0) result.push(clean);
  });
  return result;
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

  saveEnabledSources(sources: string[]): WaterfallPreferenceProfile {
    const profile = this.load();
    profile.enabledSources = dedupeStrings(sources).filter((source: string): boolean =>
      DEFAULT_SOURCES.indexOf(source) >= 0);
    profile.updatedAt = Date.now();
    return this.save(profile);
  }
}
