import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { aggregateSearchRegistrySourceIds, WaterfallFormat } from '@loop/agent-core';
import {
  DiscoveryMemoryPreferenceDimension,
  DiscoveryMemoryPreferencePolarity,
  DiscoveryMemoryPreferenceProjection,
  DiscoveryMemoryPreferenceSignal,
  DiscoveryMemoryPreferenceStrength,
  discoveryMemoryBaseWeight,
  emptyDiscoveryMemoryPreferenceProjection
} from './DiscoveryMemoryProjection';

export const DISCOVERY_MEMORY_PROJECTION_STORE_NAME: string = 'aiphone_discovery_memory_projection';
export const DISCOVERY_MEMORY_PROJECTION_KEY: string = 'projection.v1';

export interface DiscoveryMemoryProjectionStorePort {
  load(): DiscoveryMemoryPreferenceProjection;
  save(value: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection | null;
}

const REGISTERED_SOURCES: string[] = aggregateSearchRegistrySourceIds();
const REGISTERED_FORMATS: WaterfallFormat[] = [
  'landscape_video',
  'portrait_video',
  'image_text',
  'text'
];
const MAX_STORED_SIGNALS: number = 24;
const MAX_STORED_EVIDENCE_IDS: number = 16;

function validDimension(value: string): boolean {
  return value === 'topic' || value === 'source' || value === 'format';
}

function validPolarity(value: string): boolean {
  return value === 'positive' || value === 'negative';
}

function validStrength(value: string): boolean {
  return value === 'weak' || value === 'medium' || value === 'strong';
}

function validSignal(signal: DiscoveryMemoryPreferenceSignal): boolean {
  if (signal === null || typeof signal.dimension !== 'string' || !validDimension(signal.dimension) ||
    typeof signal.key !== 'string' || signal.key.trim().length === 0 || signal.key.trim().length > 40 ||
    typeof signal.polarity !== 'string' || !validPolarity(signal.polarity) ||
    typeof signal.strength !== 'string' || !validStrength(signal.strength) ||
    !Array.isArray(signal.evidenceMemoryIds) || signal.evidenceMemoryIds.length === 0 ||
    signal.evidenceMemoryIds.length > MAX_STORED_EVIDENCE_IDS ||
    !signal.evidenceMemoryIds.every((memoryId: string): boolean =>
      typeof memoryId === 'string' && memoryId.trim().length > 0) ||
    typeof signal.baseWeight !== 'number' || !isFinite(signal.baseWeight) ||
    typeof signal.lastSupportedAt !== 'number' || !isFinite(signal.lastSupportedAt) || signal.lastSupportedAt <= 0) {
    return false;
  }
  const key = signal.key.trim();
  if (signal.dimension === 'source' && REGISTERED_SOURCES.indexOf(key) < 0) return false;
  if (signal.dimension === 'format' && REGISTERED_FORMATS.indexOf(key as WaterfallFormat) < 0) return false;
  return Math.abs(signal.baseWeight - discoveryMemoryBaseWeight(signal.strength, signal.polarity)) < 0.000001;
}

function copySignal(signal: DiscoveryMemoryPreferenceSignal): DiscoveryMemoryPreferenceSignal {
  return {
    dimension: signal.dimension as DiscoveryMemoryPreferenceDimension,
    key: signal.key.trim(),
    polarity: signal.polarity as DiscoveryMemoryPreferencePolarity,
    strength: signal.strength as DiscoveryMemoryPreferenceStrength,
    evidenceMemoryIds: signal.evidenceMemoryIds.map((memoryId: string): string => memoryId.trim()),
    baseWeight: signal.baseWeight,
    lastSupportedAt: signal.lastSupportedAt
  };
}

function copyProjection(projection: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection {
  return {
    basedOnMemoryMutationAt: projection.basedOnMemoryMutationAt,
    signals: projection.signals.map((signal: DiscoveryMemoryPreferenceSignal): DiscoveryMemoryPreferenceSignal =>
      copySignal(signal))
  };
}

export function sanitizeDiscoveryMemoryPreferenceProjection(
  value: DiscoveryMemoryPreferenceProjection
): DiscoveryMemoryPreferenceProjection | null {
  if (value === null || typeof value.basedOnMemoryMutationAt !== 'number' ||
    !isFinite(value.basedOnMemoryMutationAt) || value.basedOnMemoryMutationAt < 0 ||
    !Array.isArray(value.signals) || value.signals.length > MAX_STORED_SIGNALS ||
    !value.signals.every((signal: DiscoveryMemoryPreferenceSignal): boolean => validSignal(signal))) return null;
  return copyProjection(value);
}

function parsedProjection(raw: string): DiscoveryMemoryPreferenceProjection {
  if (raw.trim().length === 0) return emptyDiscoveryMemoryPreferenceProjection();
  try {
    const safe = sanitizeDiscoveryMemoryPreferenceProjection(
      JSON.parse(raw) as DiscoveryMemoryPreferenceProjection);
    return safe === null ? emptyDiscoveryMemoryPreferenceProjection() : safe;
  } catch (_error) {
    return emptyDiscoveryMemoryPreferenceProjection();
  }
}

export class DiscoveryMemoryProjectionStore implements DiscoveryMemoryProjectionStorePort {
  private readonly store: preferences.Preferences;
  private projection: DiscoveryMemoryPreferenceProjection | null = null;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  static fromContext(context: common.Context,
    storeName: string = DISCOVERY_MEMORY_PROJECTION_STORE_NAME): DiscoveryMemoryProjectionStore {
    return new DiscoveryMemoryProjectionStore(preferences.getPreferencesSync(context, { name: storeName }));
  }

  load(): DiscoveryMemoryPreferenceProjection {
    if (this.projection === null) {
      const stored = this.store.getSync(DISCOVERY_MEMORY_PROJECTION_KEY, '');
      this.projection = parsedProjection(typeof stored === 'string' ? stored : '');
    }
    return copyProjection(this.projection);
  }

  save(value: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection | null {
    const safe = sanitizeDiscoveryMemoryPreferenceProjection(value);
    if (safe === null) return null;
    this.projection = safe;
    this.store.putSync(DISCOVERY_MEMORY_PROJECTION_KEY, JSON.stringify(this.projection));
    this.store.flush().catch((error: Error): void => {
      console.warn('[AIPhone][DiscoveryMemoryProjectionFlushFailed] ' + error.message.substring(0, 160));
    });
    return copyProjection(this.projection);
  }
}
