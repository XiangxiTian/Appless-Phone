import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountScopedStoreName } from '../account/AccountStorageScope';
import {
  MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
  MEMORY_OVERVIEW_PROMPT_VERSION,
  MemoryOverview,
  MemoryOverviewClaim
} from './MemoryOverview';

export const MEMORY_OVERVIEW_CACHE_STORE_NAME: string = 'aiphone_memory_overview_cache';
export const MEMORY_OVERVIEW_CACHE_KEY: string = 'overview.v1';
export const MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION: number = 2;

export function memoryOverviewCacheStoreNameForOwner(ownerId: string): string {
  const normalizedOwnerId = ownerId.trim();
  if (normalizedOwnerId.length === 0) throw new Error('Memory overview cache requires an account owner.');
  return accountScopedStoreName(MEMORY_OVERVIEW_CACHE_STORE_NAME, normalizedOwnerId);
}

const MAX_CACHE_TEXT_CHARS: number = 4000;
const MAX_CACHE_CLAIMS: number = 24;
const MAX_CACHE_EVIDENCE_IDS: number = 24;

export interface MemoryOverviewCacheEntry {
  schemaVersion: number;
  promptVersion: string;
  outputSchemaVersion: string;
  generatedAt: number;
  evidenceFingerprint: string;
  overview: MemoryOverview;
}

export interface MemoryOverviewCacheStorePort {
  load(): MemoryOverviewCacheEntry | null;
  save(value: MemoryOverviewCacheEntry): MemoryOverviewCacheEntry | null;
  clear(): void;
}

function validText(value: string, maxChars: number): boolean {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxChars;
}

function validEvidenceFingerprint(value: string): boolean {
  return typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);
}

function copyClaim(claim: MemoryOverviewClaim): MemoryOverviewClaim {
  return {
    heading: claim.heading,
    body: claim.body,
    evidenceMemoryIds: claim.evidenceMemoryIds.slice()
  };
}

function copyOverview(overview: MemoryOverview): MemoryOverview {
  return {
    title: overview.title,
    summary: overview.summary,
    claims: overview.claims.map((claim: MemoryOverviewClaim): MemoryOverviewClaim => copyClaim(claim))
  };
}

function safeOverview(value: MemoryOverview): MemoryOverview | null {
  if (value === null || typeof value !== 'object' || !validText(value.title, MAX_CACHE_TEXT_CHARS) ||
    !validText(value.summary, MAX_CACHE_TEXT_CHARS) || !Array.isArray(value.claims) ||
    value.claims.length < 1 || value.claims.length > MAX_CACHE_CLAIMS) return null;
  const claims: MemoryOverviewClaim[] = [];
  for (let position = 0; position < value.claims.length; position += 1) {
    const claim = value.claims[position];
    if (claim === null || typeof claim !== 'object' || !validText(claim.heading, MAX_CACHE_TEXT_CHARS) ||
      !validText(claim.body, MAX_CACHE_TEXT_CHARS) || !Array.isArray(claim.evidenceMemoryIds) ||
      claim.evidenceMemoryIds.length < 1 || claim.evidenceMemoryIds.length > MAX_CACHE_EVIDENCE_IDS) return null;
    const ids: string[] = [];
    const seen: Set<string> = new Set<string>();
    for (let evidencePosition = 0; evidencePosition < claim.evidenceMemoryIds.length;
      evidencePosition += 1) {
      const memoryId = claim.evidenceMemoryIds[evidencePosition];
      if (typeof memoryId !== 'string' || memoryId.trim().length === 0 || seen.has(memoryId)) return null;
      seen.add(memoryId);
      ids.push(memoryId);
    }
    claims.push({ heading: claim.heading, body: claim.body, evidenceMemoryIds: ids });
  }
  return { title: value.title, summary: value.summary, claims };
}

export function sanitizeMemoryOverviewCacheEntry(
  value: MemoryOverviewCacheEntry
): MemoryOverviewCacheEntry | null {
  if (value === null || typeof value !== 'object' ||
    value.schemaVersion !== MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION ||
    value.promptVersion !== MEMORY_OVERVIEW_PROMPT_VERSION ||
    value.outputSchemaVersion !== MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION ||
    typeof value.generatedAt !== 'number' || !isFinite(value.generatedAt) || value.generatedAt < 0 ||
    !validEvidenceFingerprint(value.evidenceFingerprint)) return null;
  const overview = safeOverview(value.overview);
  if (overview === null) return null;
  return {
    schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
    promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
    outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
    generatedAt: Math.floor(value.generatedAt),
    evidenceFingerprint: value.evidenceFingerprint,
    overview
  };
}

function copyEntry(value: MemoryOverviewCacheEntry): MemoryOverviewCacheEntry {
  return {
    schemaVersion: value.schemaVersion,
    promptVersion: value.promptVersion,
    outputSchemaVersion: value.outputSchemaVersion,
    generatedAt: value.generatedAt,
    evidenceFingerprint: value.evidenceFingerprint,
    overview: copyOverview(value.overview)
  };
}

export class MemoryOverviewCacheStore implements MemoryOverviewCacheStorePort {
  private readonly store: preferences.Preferences;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  static fromContext(context: common.Context,
    storeName: string = MEMORY_OVERVIEW_CACHE_STORE_NAME): MemoryOverviewCacheStore {
    return new MemoryOverviewCacheStore(preferences.getPreferencesSync(context, { name: storeName }));
  }

  load(): MemoryOverviewCacheEntry | null {
    try {
      const stored = this.store.getSync(MEMORY_OVERVIEW_CACHE_KEY, '');
      if (typeof stored !== 'string' || stored.trim().length === 0) return null;
      const safe = sanitizeMemoryOverviewCacheEntry(JSON.parse(stored) as MemoryOverviewCacheEntry);
      return safe === null ? null : copyEntry(safe);
    } catch (_error) {
      return null;
    }
  }

  save(value: MemoryOverviewCacheEntry): MemoryOverviewCacheEntry | null {
    const safe = sanitizeMemoryOverviewCacheEntry(value);
    if (safe === null) return null;
    try {
      this.store.putSync(MEMORY_OVERVIEW_CACHE_KEY, JSON.stringify(safe));
      this.store.flush().catch((error: Error): void => {
        console.warn('[AIPhone][MemoryOverviewCacheFlushFailed] ' + error.message.substring(0, 160));
      });
      return copyEntry(safe);
    } catch (_error) {
      return null;
    }
  }

  clear(): void {
    try {
      this.store.deleteSync(MEMORY_OVERVIEW_CACHE_KEY);
      this.store.flush().catch((error: Error): void => {
        console.warn('[AIPhone][MemoryOverviewCacheFlushFailed] ' + error.message.substring(0, 160));
      });
    } catch (_error) {
      // Cache invalidation is best-effort; the coordinator defensively validates evidence on open.
    }
  }
}
