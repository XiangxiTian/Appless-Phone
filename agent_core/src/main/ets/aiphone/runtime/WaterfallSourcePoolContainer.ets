import {
  WaterfallCandidate,
  WaterfallCandidatePreferenceScore,
  WaterfallPreferenceSnapshot,
  WaterfallPreferenceWeight,
  scoreWaterfallPreferenceText,
  waterfallTextTokens
} from './WaterfallAnythingCore';

export const DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY: number = 200;

export interface WaterfallSourcePoolEntry {
  key: string;
  sourceId: string;
  insertedAt: number;
  searchKeywords: string[];
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

interface WaterfallPoolTextFeatures {
  normalized: string;
  compact: string;
  tokens: string[];
  cjkBigrams: string[];
  englishTokens: string[];
}

interface WaterfallPoolEntryFeatures {
  title: WaterfallPoolTextFeatures;
  summary: WaterfallPoolTextFeatures;
  topics: WaterfallPoolTextFeatures;
  searchKeywords: WaterfallPoolTextFeatures;
}

interface WaterfallPoolPreparedWeight {
  weight: number;
  variants: WaterfallPoolTextFeatures[];
}

interface WaterfallPoolPreparedProfile {
  base: WaterfallPreferenceSnapshot;
  historicalTopics: WaterfallPoolPreparedWeight[];
  sessionTopics: WaterfallPoolPreparedWeight[];
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
    searchKeywords: candidate.searchKeywords === undefined ? undefined : candidate.searchKeywords.slice(),
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
    searchKeywords: entry.searchKeywords.slice(),
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

function appendUnique(values: string[], value: string, limit: number = 96): void {
  if (value.length > 0 && values.indexOf(value) < 0 && values.length < limit) values.push(value);
}

function normalizedPoolText(value: string): string {
  return value.trim().toLowerCase()
    .replace(/[^a-z0-9+#.\u4e00-\u9fff]+/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function isCjkCharacter(value: string): boolean {
  if (value.length === 0) return false;
  const code = value.charCodeAt(0);
  return code >= 0x4e00 && code <= 0x9fff;
}

function poolTextFeatures(value: string): WaterfallPoolTextFeatures {
  const normalized = normalizedPoolText(value);
  const cjkBigrams: string[] = [];
  let previousCjk = '';
  for (let index = 0; index < normalized.length; index += 1) {
    const character = normalized.substring(index, index + 1);
    if (isCjkCharacter(character)) {
      if (previousCjk.length > 0) appendUnique(cjkBigrams, previousCjk + character);
      previousCjk = character;
    } else {
      previousCjk = '';
    }
  }
  const englishTokens: string[] = [];
  normalized.split(' ').forEach((part: string): void => {
    let hasLatinOrDigit = false;
    for (let index = 0; index < part.length; index += 1) {
      const code = part.charCodeAt(index);
      if ((code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39)) {
        hasLatinOrDigit = true;
        break;
      }
    }
    if (hasLatinOrDigit) appendUnique(englishTokens, part);
  });
  return {
    normalized,
    compact: normalized.replace(/\s+/g, ''),
    tokens: waterfallTextTokens(normalized),
    cjkBigrams,
    englishTokens
  };
}

function poolEntryFeatures(entry: WaterfallSourcePoolEntry): WaterfallPoolEntryFeatures {
  return {
    title: poolTextFeatures(entry.candidate.title),
    summary: poolTextFeatures(entry.candidate.summary),
    topics: poolTextFeatures((entry.candidate.topics ?? []).join(' ')),
    searchKeywords: poolTextFeatures(
      entry.searchKeywords.concat([entry.candidate.searchQuery ?? '']).join(' '))
  };
}

function overlapCount(left: string[], right: string[]): number {
  let count = 0;
  left.forEach((value: string): void => {
    if (right.indexOf(value) >= 0) count += 1;
  });
  return count;
}

function diceSimilarity(left: string[], right: string[]): number {
  if (left.length === 0 || right.length === 0) return 0;
  return 2 * overlapCount(left, right) / (left.length + right.length);
}

function tokenCoverage(query: string[], document: string[]): number {
  if (query.length === 0 || document.length === 0) return 0;
  return overlapCount(query, document) / query.length;
}

function fuzzyTextMatch(query: WaterfallPoolTextFeatures, document: WaterfallPoolTextFeatures): number {
  if (query.normalized.length === 0 || document.normalized.length === 0) return 0;
  const exact = document.normalized.indexOf(query.normalized) >= 0 ||
    (query.compact.length >= 2 && document.compact.indexOf(query.compact) >= 0) ? 1 : 0;
  const coverage = tokenCoverage(query.tokens, document.tokens) * 0.9;
  const cjkDice = diceSimilarity(query.cjkBigrams, document.cjkBigrams) * 0.75;
  const englishDice = diceSimilarity(query.englishTokens, document.englishTokens) * 0.85;
  return Math.max(exact, coverage, cjkDice, englishDice);
}

function fuzzyEntryMatch(query: WaterfallPoolTextFeatures, entry: WaterfallPoolEntryFeatures): number {
  return Math.max(
    fuzzyTextMatch(query, entry.title),
    fuzzyTextMatch(query, entry.topics) * 0.9,
    fuzzyTextMatch(query, entry.searchKeywords) * 0.95,
    fuzzyTextMatch(query, entry.summary) * 0.6
  );
}

function prepareTopicWeights(weights: WaterfallPreferenceWeight[] | undefined): WaterfallPoolPreparedWeight[] {
  return (weights ?? []).map((weight: WaterfallPreferenceWeight): WaterfallPoolPreparedWeight => {
    const variants: WaterfallPoolTextFeatures[] = [poolTextFeatures(weight.key)];
    (weight.aliases ?? []).forEach((alias: string): void => {
      variants.push(poolTextFeatures(alias));
    });
    return { weight: weight.weight, variants };
  });
}

function preparePoolProfile(profile: WaterfallPreferenceSnapshot): WaterfallPoolPreparedProfile {
  return {
    base: {
      topicWeights: [],
      sourceWeights: profile.sourceWeights,
      formatWeights: profile.formatWeights,
      explicitRules: profile.explicitRules,
      sessionTopicWeights: [],
      sessionSourceWeights: profile.sessionSourceWeights,
      sessionFormatWeights: profile.sessionFormatWeights
    },
    historicalTopics: prepareTopicWeights(profile.topicWeights),
    sessionTopics: prepareTopicWeights(profile.sessionTopicWeights)
  };
}

function fuzzyTopicScore(
  entry: WaterfallPoolEntryFeatures,
  weights: WaterfallPoolPreparedWeight[]
): number {
  let score = 0;
  weights.forEach((weight: WaterfallPoolPreparedWeight): void => {
    let best = 0;
    weight.variants.forEach((variant: WaterfallPoolTextFeatures): void => {
      best = Math.max(best, fuzzyEntryMatch(variant, entry));
    });
    score += weight.weight * best;
  });
  return score;
}

function scorePoolEntry(
  entry: WaterfallSourcePoolEntry,
  features: WaterfallPoolEntryFeatures,
  profile: WaterfallPoolPreparedProfile
): WaterfallCandidatePreferenceScore {
  const base = scoreWaterfallPreferenceText(
    entry.candidate.source,
    poolCandidateFormat(entry.candidate),
    entry.candidate.title,
    profile.base
  );
  if (base.blocked) return base;
  const historical = base.historical + fuzzyTopicScore(features, profile.historicalTopics);
  const session = base.session + fuzzyTopicScore(features, profile.sessionTopics);
  let priority = historical;
  if (session !== 0) priority = session > 0 ? 100 + session : -100 + session;
  if (base.explicit === 'boost') priority = 1000000;
  else if (base.explicit === 'downweight') priority = -1000;
  return { blocked: false, priority, historical, session, explicit: base.explicit };
}

function searchKeywords(contextKeyword: string): string[] {
  const values: string[] = [];
  appendKeyword(values, contextKeyword);
  return values;
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

function profileRecallQuery(candidate: WaterfallCandidate): string {
  return candidate.recallRoute === 'profile' ? (candidate.searchQuery ?? '').trim().toLowerCase() : '';
}

function entryHasSearchQuery(entry: WaterfallSourcePoolEntry, normalizedQuery: string): boolean {
  if (normalizedQuery.length === 0) return true;
  for (let index = 0; index < entry.searchKeywords.length; index += 1) {
    if (entry.searchKeywords[index].trim().toLowerCase() === normalizedQuery) return true;
  }
  return profileRecallQuery(entry.candidate) === normalizedQuery;
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
  private readonly featuresByKey: Map<string, WaterfallPoolEntryFeatures> =
    new Map<string, WaterfallPoolEntryFeatures>();

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
        const entrySearchKeywords = existing.searchKeywords.slice();
        appendKeyword(entrySearchKeywords, contextKeyword);
        const updatedCandidate = copyCandidate(candidate);
        updatedCandidate.searchKeywords = entrySearchKeywords.slice();
        const updated: WaterfallSourcePoolEntry = {
          key,
          sourceId: this.sourceId,
          insertedAt: existing.insertedAt,
          searchKeywords: entrySearchKeywords,
          keywords,
          candidate: updatedCandidate
        };
        const index = this.orderedEntries.indexOf(existing);
        if (index >= 0) {
          this.orderedEntries[index] = updated;
        }
        this.entriesByKey.set(key, updated);
        this.featuresByKey.set(key, poolEntryFeatures(updated));
        result.updated++;
        return;
      }
      const entrySearchKeywords = searchKeywords(contextKeyword);
      const insertedCandidate = copyCandidate(candidate);
      insertedCandidate.searchKeywords = entrySearchKeywords.slice();
      const entry: WaterfallSourcePoolEntry = {
        key,
        sourceId: this.sourceId,
        insertedAt,
        searchKeywords: entrySearchKeywords,
        keywords: entryKeywords(candidate, contextKeyword),
        candidate: insertedCandidate
      };
      this.orderedEntries.push(entry);
      this.entriesByKey.set(key, entry);
      this.featuresByKey.set(key, poolEntryFeatures(entry));
      result.inserted++;
      while (this.orderedEntries.length > this.capacity) {
        const evicted = this.orderedEntries.shift();
        if (evicted !== undefined) {
          this.entriesByKey.delete(evicted.key);
          this.featuresByKey.delete(evicted.key);
          result.evicted.push(copyEntry(evicted));
        }
      }
    });
    return result;
  }

  entries(): WaterfallSourcePoolEntry[] {
    return this.orderedEntries.map((entry: WaterfallSourcePoolEntry): WaterfallSourcePoolEntry => copyEntry(entry));
  }

  removeProfileRecallQueries(normalizedQueries: string[]): number {
    let removed = 0;
    for (let index = this.orderedEntries.length - 1; index >= 0; index -= 1) {
      const entry = this.orderedEntries[index];
      const query = (entry.candidate.searchQuery ?? '').trim().toLowerCase();
      const remaining = entry.searchKeywords.filter((keyword: string): boolean =>
        normalizedQueries.indexOf(keyword.trim().toLowerCase()) < 0);
      const removedProvenance = remaining.length !== entry.searchKeywords.length;
      const removedPrimary = entry.candidate.recallRoute === 'profile' && normalizedQueries.indexOf(query) >= 0;
      if (!removedProvenance && !removedPrimary) continue;
      if (remaining.length === 0) {
        this.orderedEntries.splice(index, 1);
        this.entriesByKey.delete(entry.key);
        this.featuresByKey.delete(entry.key);
        removed += 1;
        continue;
      }
      entry.searchKeywords = remaining;
      entry.candidate.searchKeywords = remaining.slice();
      if (removedPrimary) entry.candidate.searchQuery = remaining[0];
      this.featuresByKey.set(entry.key, poolEntryFeatures(entry));
    }
    return removed;
  }

  hasForProfile(profile: WaterfallPreferenceSnapshot, preferredQuery: string = ''): boolean {
    const preferred = preferredQuery.trim().toLowerCase();
    const prepared = preparePoolProfile(profile);
    for (let index = 0; index < this.orderedEntries.length; index += 1) {
      const entry = this.orderedEntries[index];
      if (!entryHasSearchQuery(entry, preferred)) continue;
      const features = this.featuresByKey.get(entry.key) ?? poolEntryFeatures(entry);
      const score = scorePoolEntry(entry, features, prepared);
      if (!score.blocked) return true;
    }
    return false;
  }

  /** Selects and removes one item using field-weighted lexical fuzzy matching. */
  takeForProfile(
    profile: WaterfallPreferenceSnapshot,
    preferredQuery: string = ''
  ): WaterfallSourcePoolEntry | null {
    return this.takeForProfileMeasured(profile, preferredQuery).entry;
  }

  takeForProfileMeasured(
    profile: WaterfallPreferenceSnapshot,
    preferredQuery: string = ''
  ): WaterfallSourcePoolTakeProfileResult {
    const totalStartedAtMs = Date.now();
    const sizeBefore = this.orderedEntries.length;
    let scannedCount = 0;
    let blockedCount = 0;
    let selected: WaterfallSourcePoolEntry | null = null;
    let selectedScore: WaterfallCandidatePreferenceScore | null = null;
    let selectedIndex: number = -1;
    const preferred = preferredQuery.trim().toLowerCase();
    const prepared = preparePoolProfile(profile);
    const scanStartedAtMs = Date.now();
    this.orderedEntries.forEach((entry: WaterfallSourcePoolEntry, index: number): void => {
      scannedCount += 1;
      if (!entryHasSearchQuery(entry, preferred)) return;
      const features = this.featuresByKey.get(entry.key) ?? poolEntryFeatures(entry);
      const score = scorePoolEntry(entry, features, prepared);
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
    this.featuresByKey.delete(taken.key);
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
