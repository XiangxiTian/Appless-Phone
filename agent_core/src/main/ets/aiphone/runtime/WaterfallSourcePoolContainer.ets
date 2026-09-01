import {
  WaterfallCandidate,
  WaterfallCandidatePreferenceScore,
  WaterfallPreferenceSnapshot,
  scoreWaterfallPreferenceText,
  waterfallTextTokens
} from './WaterfallAnythingCore';

export const DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY: number = 200;

export interface WaterfallSourcePoolEntry {
  key: string;
  sourceId: string;
  insertedAt: number;
  keywords: string[];
  candidate: WaterfallCandidate;
}

export interface WaterfallSourcePoolInsertContext {
  keyword?: string;
  insertedAt?: number;
}

export interface WaterfallSourcePoolInsertResult {
  inserted: number;
  updated: number;
  rejected: number;
  evicted: WaterfallSourcePoolEntry[];
}

export interface WaterfallSourcePoolTakeProfileResult {
  entry: WaterfallSourcePoolEntry | null;
  sizeBefore: number;
  scannedCount: number;
  blockedCount: number;
  scanScoreMs: number;
  removeMs: number;
  copyMs: number;
  totalMs: number;
}

function copyCandidate(candidate: WaterfallCandidate): WaterfallCandidate {
  return {
    id: candidate.id,
    source: candidate.source,
    provider: candidate.provider,
    mediaType: candidate.mediaType,
    title: candidate.title,
    summary: candidate.summary,
    url: candidate.url,
    coverUrl: candidate.coverUrl,
    imageUrls: candidate.imageUrls === undefined ? undefined : candidate.imageUrls.slice(),
    mediaUrl: candidate.mediaUrl,
    feedUrl: candidate.feedUrl,
    audioTitle: candidate.audioTitle,
    audioMimeType: candidate.audioMimeType,
    audioDuration: candidate.audioDuration,
    audioPublishedAt: candidate.audioPublishedAt,
    audioLoadState: candidate.audioLoadState,
    audioError: candidate.audioError,
    audioRetryable: candidate.audioRetryable,
    providerItemId: candidate.providerItemId,
    comments: candidate.comments === undefined ? undefined : candidate.comments.slice(),
    commentLoadState: candidate.commentLoadState,
    publishedAt: candidate.publishedAt,
    duration: candidate.duration,
    originalIndex: candidate.originalIndex,
    searchQuery: candidate.searchQuery,
    queryStage: candidate.queryStage,
    sourceRank: candidate.sourceRank,
    providerScore: candidate.providerScore,
    authorName: candidate.authorName,
    authorAvatarUrl: candidate.authorAvatarUrl,
    metrics: candidate.metrics === undefined ? undefined : candidate.metrics.slice(),
    topics: candidate.topics === undefined ? undefined : candidate.topics.slice(),
    format: candidate.format,
    recallRoute: candidate.recallRoute,
    recallWeight: candidate.recallWeight
  };
}

function copyEntry(entry: WaterfallSourcePoolEntry): WaterfallSourcePoolEntry {
  return {
    key: entry.key,
    sourceId: entry.sourceId,
    insertedAt: entry.insertedAt,
    keywords: entry.keywords.slice(),
    candidate: copyCandidate(entry.candidate)
  };
}

function appendKeyword(values: string[], value: string): void {
  const normalized = value.trim();
  if (normalized.length > 0 && values.indexOf(normalized) < 0 && values.length < 96) {
    values.push(normalized);
  }
}

function appendKeywords(values: string[], incoming: string[]): void {
  incoming.forEach((value: string): void => appendKeyword(values, value));
}

function entryKeywords(candidate: WaterfallCandidate, contextKeyword: string): string[] {
  const values: string[] = [];
  appendKeywords(values, waterfallTextTokens(contextKeyword));
  appendKeywords(values, waterfallTextTokens(candidate.searchQuery ?? ''));
  appendKeywords(values, candidate.topics ?? []);
  appendKeywords(values, waterfallTextTokens(candidate.title + ' ' + candidate.summary));
  return values;
}

function candidateKey(candidate: WaterfallCandidate): string {
  const id = candidate.id.trim();
  if (id.length > 0) {
    return id;
  }
  return candidate.url.trim();
}

function normalizedInsertedAt(value: number | undefined): number {
  if (value !== undefined && Number.isFinite(value) && value >= 0) {
    return Math.floor(value);
  }
  return Date.now();
}

function normalizedCapacity(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.max(1, Math.floor(value)) :
    DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY;
}

function poolCandidateFormat(candidate: WaterfallCandidate): string {
  return candidate.format ?? (candidate.mediaType === 'video' ? 'landscape_video' :
    (candidate.mediaType === 'image_text' ? 'image_text' : 'text'));
}

function scoreOutranks(
  next: WaterfallCandidatePreferenceScore,
  nextInsertedAt: number,
  current: WaterfallCandidatePreferenceScore,
  currentInsertedAt: number
): boolean {
  if (next.priority !== current.priority) return next.priority > current.priority;
  if (next.session !== current.session) return next.session > current.session;
  if (next.historical !== current.historical) return next.historical > current.historical;
  return nextInsertedAt > currentInsertedAt;
}

/**
 * FIFO storage owned by exactly one source. Duplicate candidates update their
 * data and keyword metadata in place while preserving their original insertion
 * time and FIFO position.
 */
export class WaterfallSourcePoolContainer {
  readonly sourceId: string;
  private capacityValue: number;
  private readonly orderedEntries: WaterfallSourcePoolEntry[] = [];
  private readonly entriesByKey: Map<string, WaterfallSourcePoolEntry> =
    new Map<string, WaterfallSourcePoolEntry>();

  constructor(sourceId: string, capacity: number = DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY) {
    this.sourceId = sourceId.trim();
    this.capacityValue = normalizedCapacity(capacity);
  }

  get capacity(): number {
    return this.capacityValue;
  }

  get size(): number {
    return this.orderedEntries.length;
  }

  expandCapacity(capacity: number): boolean {
    const next = normalizedCapacity(capacity);
    if (next <= this.capacityValue) return false;
    this.capacityValue = next;
    return true;
  }

  putOne(
    candidate: WaterfallCandidate,
    context: WaterfallSourcePoolInsertContext = {}
  ): WaterfallSourcePoolInsertResult {
    return this.put([candidate], context);
  }

  put(
    candidates: WaterfallCandidate[],
    context: WaterfallSourcePoolInsertContext = {}
  ): WaterfallSourcePoolInsertResult {
    const result: WaterfallSourcePoolInsertResult = {
      inserted: 0,
      updated: 0,
      rejected: 0,
      evicted: []
    };
    const insertedAt = normalizedInsertedAt(context.insertedAt);
    const contextKeyword = context.keyword ?? '';
    candidates.forEach((candidate: WaterfallCandidate): void => {
      const key = candidateKey(candidate);
      if (this.sourceId.length === 0 || candidate.source !== this.sourceId || key.length === 0) {
        result.rejected++;
        return;
      }
      const existing = this.entriesByKey.get(key);
      if (existing !== undefined) {
        const keywords = existing.keywords.slice();
        appendKeywords(keywords, entryKeywords(candidate, contextKeyword));
        const updated: WaterfallSourcePoolEntry = {
          key,
          sourceId: this.sourceId,
          insertedAt: existing.insertedAt,
          keywords,
          candidate: copyCandidate(candidate)
        };
        const index = this.orderedEntries.indexOf(existing);
        if (index >= 0) {
          this.orderedEntries[index] = updated;
        }
        this.entriesByKey.set(key, updated);
        result.updated++;
        return;
      }
      const entry: WaterfallSourcePoolEntry = {
        key,
        sourceId: this.sourceId,
        insertedAt,
        keywords: entryKeywords(candidate, contextKeyword),
        candidate: copyCandidate(candidate)
      };
      this.orderedEntries.push(entry);
      this.entriesByKey.set(key, entry);
      result.inserted++;
      while (this.orderedEntries.length > this.capacity) {
        const evicted = this.orderedEntries.shift();
        if (evicted !== undefined) {
          this.entriesByKey.delete(evicted.key);
          result.evicted.push(copyEntry(evicted));
        }
      }
    });
    return result;
  }

  entries(): WaterfallSourcePoolEntry[] {
    return this.orderedEntries.map((entry: WaterfallSourcePoolEntry): WaterfallSourcePoolEntry => copyEntry(entry));
  }

  hasForProfile(profile: WaterfallPreferenceSnapshot): boolean {
    for (let index = 0; index < this.orderedEntries.length; index += 1) {
      const entry = this.orderedEntries[index];
      const score = scoreWaterfallPreferenceText(
        entry.candidate.source,
        poolCandidateFormat(entry.candidate),
        entry.candidate.title,
        profile
      );
      if (!score.blocked) return true;
    }
    return false;
  }

  /** Selects and removes one item using shared preference semantics and title-only topic matching. */
  takeForProfile(profile: WaterfallPreferenceSnapshot): WaterfallSourcePoolEntry | null {
    return this.takeForProfileMeasured(profile).entry;
  }

  takeForProfileMeasured(profile: WaterfallPreferenceSnapshot): WaterfallSourcePoolTakeProfileResult {
    const totalStartedAtMs = Date.now();
    const sizeBefore = this.orderedEntries.length;
    let scannedCount = 0;
    let blockedCount = 0;
    let selected: WaterfallSourcePoolEntry | null = null;
    let selectedScore: WaterfallCandidatePreferenceScore | null = null;
    let selectedIndex: number = -1;
    const scanStartedAtMs = Date.now();
    this.orderedEntries.forEach((entry: WaterfallSourcePoolEntry, index: number): void => {
      scannedCount += 1;
      const score = scoreWaterfallPreferenceText(
        entry.candidate.source,
        poolCandidateFormat(entry.candidate),
        entry.candidate.title,
        profile
      );
      if (score.blocked) {
        blockedCount += 1;
        return;
      }
      if (selected === null || selectedScore === null ||
        scoreOutranks(score, entry.insertedAt, selectedScore, selected.insertedAt)) {
        selected = entry;
        selectedScore = score;
        selectedIndex = index;
      }
    });
    const scanScoreMs = Date.now() - scanStartedAtMs;
    if (selectedIndex < 0) {
      return {
        entry: null,
        sizeBefore,
        scannedCount,
        blockedCount,
        scanScoreMs,
        removeMs: 0,
        copyMs: 0,
        totalMs: Date.now() - totalStartedAtMs
      };
    }
    const removeStartedAtMs = Date.now();
    const removed = this.orderedEntries.splice(selectedIndex, 1);
    const removeMs = Date.now() - removeStartedAtMs;
    if (removed.length === 0) {
      return {
        entry: null,
        sizeBefore,
        scannedCount,
        blockedCount,
        scanScoreMs,
        removeMs,
        copyMs: 0,
        totalMs: Date.now() - totalStartedAtMs
      };
    }
    const taken = removed[0];
    this.entriesByKey.delete(taken.key);
    const copyStartedAtMs = Date.now();
    const copied = copyEntry(taken);
    const copyMs = Date.now() - copyStartedAtMs;
    return {
      entry: copied,
      sizeBefore,
      scannedCount,
      blockedCount,
      scanScoreMs,
      removeMs,
      copyMs,
      totalMs: Date.now() - totalStartedAtMs
    };
  }
}
