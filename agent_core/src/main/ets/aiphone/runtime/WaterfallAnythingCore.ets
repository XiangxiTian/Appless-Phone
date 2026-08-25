import { extractJsonObjects } from '../../a2ui/A2uiProtocol';

export type WaterfallMediaType = 'video' | 'image_text' | 'post';
export type WaterfallQueryStage = 'original' | 'related' | 'adjacent' | 'done';
export type WaterfallMode = 'search' | 'interest';
export type WaterfallFormat = 'landscape_video' | 'portrait_video' | 'image_text' | 'text';
export type WaterfallRecallRoute = 'search' | 'similar' | 'profile' | 'explore' | 'popular';
export type WaterfallInterestRecallRoute = 'similar' | 'profile' | 'explore' | 'popular';
export type WaterfallCommentLoadState = 'loading' | 'ready' | 'empty' | 'error';

export interface WaterfallComment {
  text: string;
  authorName?: string;
  authorAvatarUrl?: string;
  publishedAt?: string;
  likeCount?: number;
  replyCount?: number;
}

export interface WaterfallCommentsResult {
  state: WaterfallCommentLoadState;
  comments: WaterfallComment[];
}

export interface WaterfallInterestRecallRequest {
  route: WaterfallInterestRecallRoute;
  query: string;
  sources: string[];
  weight: number;
  continuation?: WaterfallContinuation | null;
}

export interface WaterfallPreferenceWeight {
  key: string;
  weight: number;
  updatedAt: number;
}

export interface WaterfallExplicitPreference {
  dimension: 'topic' | 'source' | 'format';
  key: string;
  effect: 'block' | 'downweight' | 'boost';
}

export interface WaterfallPreferenceSnapshot {
  topicWeights: WaterfallPreferenceWeight[];
  sourceWeights: WaterfallPreferenceWeight[];
  formatWeights: WaterfallPreferenceWeight[];
  explicitRules: WaterfallExplicitPreference[];
  sessionTopicWeights?: WaterfallPreferenceWeight[];
  sessionSourceWeights?: WaterfallPreferenceWeight[];
  sessionFormatWeights?: WaterfallPreferenceWeight[];
}

const WATERFALL_EXPLORATION_QUERIES: string[] = ['人工智能', '科技数码', '编程开发', '科学科普'];
const WATERFALL_WESTERN_EXPLORATION_QUERIES: string[] = [
  'tech news', 'artificial intelligence', 'programming', 'computer science'
];

function usesChineseDiscoveryQuery(source: string): boolean {
  return source === 'zhihu' || source === 'bilibili';
}

function usesPopularDiscovery(source: string): boolean {
  return source === 'zhihu' || source === 'github' || source === 'steam' || source === 'cnnews' ||
    source === 'globalnews';
}

export function planWaterfallInterestRecall(
  _profile: WaterfallPreferenceSnapshot,
  _recentPositiveCandidates: WaterfallRankedCandidate[],
  enabledSources: string[],
  round: number = 0
): WaterfallInterestRecallRequest[] {
  const sources: string[] = [];
  enabledSources.forEach((source: string): void => {
    if (source.trim().length > 0 && sources.indexOf(source) < 0) sources.push(source);
  });
  if (sources.length === 0) return [];
  const recallRound = Math.max(0, Math.floor(round));
  const querySourceCount = sources.filter((source: string): boolean =>
    source !== 'youtube' && source !== 'twitch').length;
  let fallbackIndex = 0;
  return sources.map((source: string): WaterfallInterestRecallRequest => {
    if (source === 'youtube') {
      return { route: 'popular', query: '', sources: [source], weight: 1, continuation: null };
    }
    if (source === 'zhihu') {
      const query = WATERFALL_EXPLORATION_QUERIES[
        (recallRound * Math.max(1, querySourceCount) + fallbackIndex++) % WATERFALL_EXPLORATION_QUERIES.length
      ];
      return { route: 'popular', query, sources: [source], weight: 1, continuation: null };
    }
    if (usesPopularDiscovery(source)) {
      fallbackIndex++;
      return { route: 'popular', query: '', sources: [source], weight: 1, continuation: null };
    }
    if (source === 'twitch') {
      return { route: 'explore', query: '', sources: [source], weight: 1, continuation: null };
    }
    // ponytail: ignore profile n-grams as search queries; they leak source names like 知乎
    const pool = usesChineseDiscoveryQuery(source) ?
      WATERFALL_EXPLORATION_QUERIES : WATERFALL_WESTERN_EXPLORATION_QUERIES;
    const query = pool[(recallRound * Math.max(1, querySourceCount) + fallbackIndex++) % pool.length];
    return { route: 'explore', query, sources: [source], weight: 1, continuation: null };
  });
}

export interface WaterfallCandidate {
  id: string;
  source: string;
  provider?: string;
  mediaType: WaterfallMediaType;
  title: string;
  summary: string;
  url: string;
  coverUrl: string;
  mediaUrl?: string;
  feedUrl?: string;
  audioTitle?: string;
  audioMimeType?: string;
  audioDuration?: string;
  audioPublishedAt?: string;
  audioLoadState?: 'loading' | 'ready' | 'error';
  audioError?: string;
  audioRetryable?: boolean;
  providerItemId?: string;
  comments?: WaterfallComment[];
  commentLoadState?: WaterfallCommentLoadState;
  publishedAt: string;
  duration?: string;
  originalIndex: number;
  searchQuery?: string;
  queryStage?: WaterfallQueryStage;
  sourceRank?: number;
  providerScore?: number;
  authorName?: string;
  authorAvatarUrl?: string;
  metrics?: WaterfallMetric[];
  topics?: string[];
  format?: WaterfallFormat;
  recallRoute?: WaterfallRecallRoute;
  recallWeight?: number;
}

export interface WaterfallMetric {
  kind: string;
  value: number;
}

export interface WaterfallRankSignals {
  relevanceTier: number;
  titleHits: number;
  summaryHits: number;
  freshnessTier: number;
}

export interface WaterfallRankedCandidate extends WaterfallCandidate {
  normalizedUrl: string;
  signals: WaterfallRankSignals;
  reason: string;
}

export interface WaterfallOrderInput {
  query: string;
  candidates: WaterfallCandidate[];
  enabledSources: string[];
  shownIds: string[];
  stableIds: string[];
  preferenceDescription: string;
  mode?: WaterfallMode;
  surfaceId?: string;
  profile?: WaterfallPreferenceSnapshot;
}

export type WaterfallContinuationKind = 'cursor' | 'page' | 'offset';

export interface WaterfallContinuation {
  kind: WaterfallContinuationKind;
  value: string;
}

export type WaterfallSourcePhase =
  'loading' | 'success' | 'empty' | 'needs_auth' | 'error' | 'exhausted';

export interface WaterfallSourceState {
  source: string;
  phase: WaterfallSourcePhase;
  continuation: WaterfallContinuation | null;
  inFlight: boolean;
  reservedCount: number;
  message: string;
  query?: string;
  recallRoute?: WaterfallInterestRecallRoute;
  loadMode?: 'native' | 'search';
}

export interface WaterfallFeedState {
  mode?: WaterfallMode;
  interestFallbackStarted?: boolean;
  query: string;
  originalQuery?: string;
  queryStage?: WaterfallQueryStage;
  queryHistory?: string[];
  consecutiveEmptyRounds?: number;
  roundNewItemCount?: number;
  roundActive?: boolean;
  expansionInFlight?: boolean;
  enabledSources: string[];
  preferenceDescription: string;
  profile?: WaterfallPreferenceSnapshot;
  shown: WaterfallRankedCandidate[];
  current: WaterfallRankedCandidate | null;
  stable: WaterfallRankedCandidate[];
  tail: WaterfallRankedCandidate[];
  reserve?: WaterfallRankedCandidate[];
  sources: WaterfallSourceState[];
}

export interface WaterfallLoadRequest {
  source: string;
  continuation: WaterfallContinuation | null;
  limit: number;
  phase: WaterfallSourcePhase;
  message: string;
  mode: 'native' | 'search';
  query?: string;
  route?: WaterfallInterestRecallRoute;
}

export interface WaterfallQueryExpansionRequest {
  stage: 'related' | 'adjacent';
  originalQuery: string;
  currentQuery: string;
  usedQueries: string[];
}

export interface WaterfallFeedUpdate {
  state: WaterfallFeedState;
  loadRequests: WaterfallLoadRequest[];
  expansionRequest?: WaterfallQueryExpansionRequest;
}

type WaterfallExpansionJsonValue = Object | string | number | boolean | null | undefined;

interface RankedCandidateInternal {
  candidate: WaterfallCandidate;
  normalizedUrl: string;
  signals: WaterfallRankSignals;
}

interface TraditionalRankedCandidateInternal extends RankedCandidateInternal {
  tokens: string[];
  rrf: number;
  bm25: number;
  profile: number;
  session: number;
  freshnessPopularity: number;
  balance: number;
  score: number;
  epsilon: number;
}

interface WaterfallPreferenceScores {
  blocked: boolean;
  profile: number;
  session: number;
}

interface CandidateText {
  title: string;
  summary: string;
}

interface CandidatePreferenceText {
  source: string;
  format: string;
  topic: string;
}

function normalizedText(value: string): string {
  return value.trim().toLowerCase();
}

function appendUniqueToken(tokens: string[], token: string): void {
  const value = token.trim();
  if (value.length > 0 && tokens.indexOf(value) < 0 && tokens.length < 48) {
    tokens.push(value);
  }
}

export function waterfallTextTokens(value: string): string[] {
  const normalized = normalizedText(value);
  const tokens: string[] = [];
  normalized.split(/[^a-z0-9+#.\u4e00-\u9fff]+/).forEach((part: string): void => {
    if (part.length === 0) {
      return;
    }
    let cjkOnly = true;
    for (let index = 0; index < part.length; index += 1) {
      const code = part.charCodeAt(index);
      if (code < 0x4e00 || code > 0x9fff) {
        cjkOnly = false;
        break;
      }
    }
    if (!cjkOnly) {
      appendUniqueToken(tokens, part);
      return;
    }
    if (part.length === 1) {
      appendUniqueToken(tokens, part);
      return;
    }
    const maxSize = Math.min(4, part.length);
    for (let size = 2; size <= maxSize; size += 1) {
      for (let start = 0; start + size <= part.length; start += 1) {
        appendUniqueToken(tokens, part.substring(start, start + size));
      }
    }
  });
  return tokens;
}

function queryTokens(query: string): string[] {
  const clean = normalizedText(query).replace(/[\s,，。！？!?:：；;、/\\()[\]{}"“”‘’]+/g, ' ').trim();
  if (clean.length === 0) {
    return [];
  }
  const tokens: string[] = [];
  clean.split(' ').forEach((token: string) => {
    if (token.length > 0 && tokens.indexOf(token) < 0) {
      tokens.push(token);
    }
  });
  return tokens;
}

function textForCandidate(candidate: WaterfallCandidate): CandidateText {
  return {
    title: normalizedText(candidate.title),
    summary: normalizedText(candidate.summary)
  };
}

function tokenHits(tokens: string[], value: string): number {
  let hits = 0;
  tokens.forEach((token: string) => {
    if (value.indexOf(token) >= 0) {
      hits += 1;
    }
  });
  return hits;
}

function relevanceSignals(query: string, candidate: WaterfallCandidate): WaterfallRankSignals {
  const phrase = normalizedText(query);
  const tokens = queryTokens(query);
  const text = textForCandidate(candidate);
  const titleHits = tokenHits(tokens, text.title);
  const summaryHits = tokenHits(tokens, text.summary);
  let matchedTokens = 0;
  tokens.forEach((token: string): void => {
    if (text.title.indexOf(token) >= 0 || text.summary.indexOf(token) >= 0) {
      matchedTokens += 1;
    }
  });
  const phraseHit = phrase.length > 0 && (text.title.indexOf(phrase) >= 0 || text.summary.indexOf(phrase) >= 0);
  const allTokensHit = tokens.length > 0 && matchedTokens === tokens.length;
  const anyTokenHit = titleHits + summaryHits > 0;
  return {
    relevanceTier: phraseHit || allTokensHit ? 3 : (anyTokenHit ? 2 : 1),
    titleHits: titleHits,
    summaryHits: summaryHits,
    freshnessTier: 0
  };
}

function freshnessTier(publishedAt: string, nowMs: number): number {
  const parsed = Date.parse(publishedAt.trim());
  if (!Number.isFinite(parsed) || parsed > nowMs) {
    return 0;
  }
  const ageMs = nowMs - parsed;
  if (ageMs <= 24 * 60 * 60 * 1000) {
    return 4;
  }
  if (ageMs <= 7 * 24 * 60 * 60 * 1000) {
    return 3;
  }
  if (ageMs <= 30 * 24 * 60 * 60 * 1000) {
    return 2;
  }
  return 1;
}

function normalizedHttpUrl(value: string): string {
  let url = value.trim();
  const lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return '';
  }
  const fragment = url.indexOf('#');
  if (fragment >= 0) {
    url = url.substring(0, fragment);
  }
  const schemeEnd = url.indexOf('://');
  if (schemeEnd < 0) {
    return '';
  }
  const authorityStart = schemeEnd + 3;
  let authorityEnd = url.length;
  const slash = url.indexOf('/', authorityStart);
  const question = url.indexOf('?', authorityStart);
  if (slash >= 0 && slash < authorityEnd) {
    authorityEnd = slash;
  }
  if (question >= 0 && question < authorityEnd) {
    authorityEnd = question;
  }
  const authority = url.substring(authorityStart, authorityEnd).toLowerCase();
  if (authority.length === 0) {
    return '';
  }
  return lower.substring(0, schemeEnd) + '://' + authority + url.substring(authorityEnd);
}

function qualityCompare(left: RankedCandidateInternal, right: RankedCandidateInternal): number {
  if (left.signals.relevanceTier !== right.signals.relevanceTier) {
    return right.signals.relevanceTier - left.signals.relevanceTier;
  }
  if (left.signals.freshnessTier !== right.signals.freshnessTier) {
    return right.signals.freshnessTier - left.signals.freshnessTier;
  }
  if (left.signals.titleHits !== right.signals.titleHits) {
    return right.signals.titleHits - left.signals.titleHits;
  }
  if (left.signals.summaryHits !== right.signals.summaryHits) {
    return right.signals.summaryHits - left.signals.summaryHits;
  }
  return left.candidate.originalIndex - right.candidate.originalIndex;
}

function reasonFor(signals: WaterfallRankSignals): string {
  const parts: string[] = [];
  if (signals.titleHits > 0) {
    parts.push('标题命中查询');
  } else if (signals.summaryHits > 0) {
    parts.push('摘要命中查询');
  } else {
    parts.push('相关内容');
  }
  if (signals.freshnessTier === 4) {
    parts.push('24 小时内发布');
  } else if (signals.freshnessTier === 3) {
    parts.push('7 天内发布');
  } else if (signals.freshnessTier === 2) {
    parts.push('30 天内发布');
  }
  return parts.slice(0, 2).join(' · ');
}

function toRankedCandidate(item: RankedCandidateInternal): WaterfallRankedCandidate {
  return {
    id: item.candidate.id,
    source: item.candidate.source,
    provider: item.candidate.provider,
    mediaType: item.candidate.mediaType,
    title: item.candidate.title,
    summary: item.candidate.summary,
    url: item.candidate.url,
    coverUrl: item.candidate.coverUrl,
    mediaUrl: item.candidate.mediaUrl,
    feedUrl: item.candidate.feedUrl,
    providerItemId: item.candidate.providerItemId,
    comments: item.candidate.comments,
    commentLoadState: item.candidate.commentLoadState,
    audioTitle: item.candidate.audioTitle,
    audioMimeType: item.candidate.audioMimeType,
    audioDuration: item.candidate.audioDuration,
    audioPublishedAt: item.candidate.audioPublishedAt,
    audioLoadState: item.candidate.audioLoadState,
    audioError: item.candidate.audioError,
    audioRetryable: item.candidate.audioRetryable,
    publishedAt: item.candidate.publishedAt,
    duration: item.candidate.duration,
    originalIndex: item.candidate.originalIndex,
    searchQuery: item.candidate.searchQuery,
    queryStage: item.candidate.queryStage,
    sourceRank: item.candidate.sourceRank,
    providerScore: item.candidate.providerScore,
    authorName: item.candidate.authorName,
    authorAvatarUrl: item.candidate.authorAvatarUrl,
    metrics: item.candidate.metrics,
    topics: item.candidate.topics,
    format: item.candidate.format,
    recallRoute: item.candidate.recallRoute,
    recallWeight: item.candidate.recallWeight,
    normalizedUrl: item.normalizedUrl,
    signals: item.signals,
    reason: reasonFor(item.signals)
  };
}

function hasId(ids: string[], id: string): boolean {
  return ids.indexOf(id) >= 0;
}

function bestDuplicate(
  current: RankedCandidateInternal,
  next: RankedCandidateInternal
): RankedCandidateInternal {
  return qualityCompare(current, next) <= 0 ? current : next;
}

function traditionalCandidateGroups(
  input: WaterfallOrderInput,
  nowMs: number
): TraditionalRankedCandidateInternal[] {
  const groups: TraditionalRankedCandidateInternal[] = [];
  input.candidates.forEach((candidate: WaterfallCandidate): void => {
    if (input.enabledSources.indexOf(candidate.source) < 0 || hasId(input.shownIds, candidate.id)) {
      return;
    }
    const normalizedUrl = normalizedHttpUrl(candidate.url);
    const preference = preferenceScores(candidate, input.profile);
    if (normalizedUrl.length === 0 || preference.blocked) {
      return;
    }
    const signals = relevanceSignals(candidate.searchQuery ?? input.query, candidate);
    signals.freshnessTier = freshnessTier(candidate.publishedAt, nowMs);
    let duplicateIndex = -1;
    for (let index = 0; index < groups.length; index += 1) {
      if (groups[index].candidate.id === candidate.id || groups[index].normalizedUrl === normalizedUrl) {
        duplicateIndex = index;
        break;
      }
    }
    const contribution = (candidate.recallWeight ?? 1) /
      (60 + Math.max(1, candidate.sourceRank ?? candidate.originalIndex + 1));
    if (duplicateIndex >= 0) {
      groups[duplicateIndex].rrf += contribution;
      const next: RankedCandidateInternal = { candidate: candidate, normalizedUrl: normalizedUrl, signals: signals };
      const best = bestDuplicate(groups[duplicateIndex], next);
      if (best.candidate.id === candidate.id) {
        groups[duplicateIndex].candidate = candidate;
        groups[duplicateIndex].signals = signals;
        groups[duplicateIndex].tokens = waterfallTextTokens(candidate.title + ' ' + candidate.summary);
        groups[duplicateIndex].profile = preference.profile;
        groups[duplicateIndex].session = preference.session;
      }
      return;
    }
    groups.push({
      candidate: candidate,
      normalizedUrl: normalizedUrl,
      signals: signals,
      tokens: waterfallTextTokens(candidate.title + ' ' + candidate.summary),
      rrf: contribution,
      bm25: 0,
      profile: preference.profile,
      session: preference.session,
      freshnessPopularity: signals.freshnessTier,
      balance: 0,
      score: 0,
      epsilon: stableEpsilon((input.surfaceId ?? '') + '|' + candidate.id)
    });
  });
  if (groups.length === 0) {
    return [];
  }

  return groups;
}

export function rankWaterfallCandidates(
  input: WaterfallOrderInput,
  nowMs: number
): WaterfallRankedCandidate[] {
  const groups = traditionalCandidateGroups(input, nowMs);
  if (groups.length === 0) return [];

  applyBm25(groups, waterfallTextTokens(input.query));
  applyBalance(groups);
  applyTraditionalScores(groups, input.mode ?? 'search');
  const similarities = tfidfSimilarityMatrix(groups);
  const diverse = suppressNearDuplicates(groups, similarities);
  return mmrOrder(diverse, input.mode === 'interest' ? 0.70 : 0.82, similarities, groups)
    .map((item: TraditionalRankedCandidateInternal): WaterfallRankedCandidate => toRankedCandidate(item));
}

function preferenceText(candidate: WaterfallCandidate): CandidatePreferenceText {
  return {
    source: normalizedText(candidate.source),
    format: normalizedText(candidate.format ?? ''),
    topic: normalizedText(candidate.title + ' ' + candidate.summary + ' ' + (candidate.topics ?? []).join(' '))
  };
}

function candidateMatches(candidate: CandidatePreferenceText, dimension: string, key: string): boolean {
  const normalizedKey = normalizedText(key);
  if (normalizedKey.length === 0) {
    return false;
  }
  if (dimension === 'source') {
    return candidate.source === normalizedKey;
  }
  if (dimension === 'format') {
    return candidate.format === normalizedKey;
  }
  return candidate.topic.indexOf(normalizedKey) >= 0;
}

function matchingWeight(
  candidate: CandidatePreferenceText,
  dimension: string,
  weights: WaterfallPreferenceWeight[] | undefined
): number {
  let score = 0;
  (weights ?? []).forEach((weight: WaterfallPreferenceWeight): void => {
    if (candidateMatches(candidate, dimension, weight.key)) {
      score += weight.weight;
    }
  });
  return score;
}

function preferenceScores(
  candidate: WaterfallCandidate,
  profile: WaterfallPreferenceSnapshot | undefined
): WaterfallPreferenceScores {
  if (profile === undefined) {
    return { blocked: false, profile: 0, session: 0 };
  }
  const candidateText = preferenceText(candidate);
  let explicit = 0;
  profile.explicitRules.forEach((rule: WaterfallExplicitPreference): void => {
    if (!candidateMatches(candidateText, rule.dimension, rule.key)) {
      return;
    }
    if (rule.effect === 'block') {
      explicit = -2;
    } else if (rule.effect === 'downweight' && explicit > -2) {
      explicit = -1;
    } else if (rule.effect === 'boost' && explicit === 0) {
      explicit = 1;
    }
  });
  if (explicit === -2) {
    return { blocked: true, profile: 0, session: 0 };
  }
  const historical = matchingWeight(candidateText, 'topic', profile.topicWeights) +
    matchingWeight(candidateText, 'source', profile.sourceWeights) +
    matchingWeight(candidateText, 'format', profile.formatWeights);
  const session = matchingWeight(candidateText, 'topic', profile.sessionTopicWeights) +
    matchingWeight(candidateText, 'source', profile.sessionSourceWeights) +
    matchingWeight(candidateText, 'format', profile.sessionFormatWeights);
  const boundedHistory = Math.max(-10, Math.min(10, historical));
  const boundedSession = Math.max(-10, Math.min(10, session));
  let priorityScore = boundedHistory;
  if (session !== 0) {
    priorityScore = session > 0 ? 100 + boundedSession : -100 + boundedSession;
  }
  if (explicit === 1) {
    priorityScore = 1000000;
  } else if (explicit === -1) {
    priorityScore = -1000;
  }
  return { blocked: false, profile: priorityScore, session: boundedSession };
}

function tokenFrequency(tokens: string[], term: string): number {
  let count = 0;
  tokens.forEach((token: string): void => {
    if (token === term) {
      count += 1;
    }
  });
  return count;
}

function documentFrequency(items: TraditionalRankedCandidateInternal[], term: string): number {
  let count = 0;
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    if (tokenFrequency(item.tokens, term) > 0) {
      count += 1;
    }
  });
  return count;
}

function inverseDocumentFrequency(items: TraditionalRankedCandidateInternal[], term: string): number {
  const frequency = documentFrequency(items, term);
  return Math.log(1 + (items.length - frequency + 0.5) / (frequency + 0.5));
}

function applyBm25(items: TraditionalRankedCandidateInternal[], query: string[]): void {
  let totalLength = 0;
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    totalLength += item.tokens.length;
  });
  const averageLength = Math.max(1, totalLength / items.length);
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    let score = 0;
    query.forEach((term: string): void => {
      const frequency = tokenFrequency(item.tokens, term);
      if (frequency === 0) {
        return;
      }
      const denominator = frequency + 1.2 * (1 - 0.75 + 0.75 * item.tokens.length / averageLength);
      score += inverseDocumentFrequency(items, term) * frequency * 2.2 / denominator;
    });
    item.bm25 = score;
  });
}

function applyBalance(items: TraditionalRankedCandidateInternal[]): void {
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    let sourceMatches = 0;
    let formatMatches = 0;
    items.forEach((other: TraditionalRankedCandidateInternal): void => {
      if (other.candidate.source === item.candidate.source) {
        sourceMatches += 1;
      }
      if (other.candidate.format === item.candidate.format) {
        formatMatches += 1;
      }
    });
    item.balance = 1 / sourceMatches + 1 / Math.max(1, formatMatches);
  });
}

function valueRange(items: TraditionalRankedCandidateInternal[], field: string): number[] {
  let minimum = Number.MAX_VALUE;
  let maximum = -Number.MAX_VALUE;
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    let value = item.rrf;
    if (field === 'bm25') value = item.bm25;
    if (field === 'profile') value = item.profile;
    if (field === 'session') value = item.session;
    if (field === 'freshness') value = item.freshnessPopularity;
    if (field === 'balance') value = item.balance;
    minimum = Math.min(minimum, value);
    maximum = Math.max(maximum, value);
  });
  return [minimum, maximum];
}

function normalizedValue(value: number, range: number[]): number {
  return range[0] === range[1] ? 0 : (value - range[0]) / (range[1] - range[0]);
}

function applyTraditionalScores(items: TraditionalRankedCandidateInternal[], mode: WaterfallMode): void {
  const rrfRange = valueRange(items, 'rrf');
  const bm25Range = valueRange(items, 'bm25');
  const profileRange = valueRange(items, 'profile');
  const sessionRange = valueRange(items, 'session');
  const freshnessRange = valueRange(items, 'freshness');
  const balanceRange = valueRange(items, 'balance');
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    if (mode === 'interest') {
      item.score = 0.50 * normalizedValue(item.profile, profileRange) +
        0.25 * normalizedValue(item.session, sessionRange) +
        0.15 * normalizedValue(item.freshnessPopularity, freshnessRange) +
        0.10 * normalizedValue(item.balance, balanceRange);
      return;
    }
    const searchProfile = item.profile + item.session * 10;
    let searchProfileMinimum = profileRange[0] + sessionRange[0] * 10;
    let searchProfileMaximum = profileRange[1] + sessionRange[1] * 10;
    item.score = 0.55 * normalizedValue(item.rrf, rrfRange) +
      0.30 * normalizedValue(item.bm25, bm25Range) +
      0.10 * normalizedValue(item.freshnessPopularity, freshnessRange) +
      0.05 * normalizedValue(searchProfile, [searchProfileMinimum, searchProfileMaximum]);
  });
}

function tfidfSimilarityMatrix(items: TraditionalRankedCandidateInternal[]): number[][] {
  const frequencies: Map<string, number> = new Map<string, number>();
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    item.tokens.forEach((term: string): void => {
      frequencies.set(term, (frequencies.get(term) ?? 0) + 1);
    });
  });
  const idfs: Map<string, number> = new Map<string, number>();
  frequencies.forEach((frequency: number, term: string): void => {
    idfs.set(term, Math.log(1 + (items.length - frequency + 0.5) / (frequency + 0.5)));
  });
  const tokenSets: Set<string>[] = [];
  const norms: number[] = [];
  items.forEach((item: TraditionalRankedCandidateInternal): void => {
    let squaredNorm = 0;
    item.tokens.forEach((term: string): void => {
      const value = idfs.get(term) ?? 0;
      squaredNorm += value * value;
    });
    tokenSets.push(new Set<string>(item.tokens));
    norms.push(Math.sqrt(squaredNorm));
  });
  const similarities: number[][] = [];
  for (let left = 0; left < items.length; left += 1) {
    const row: number[] = [];
    for (let right = 0; right < items.length; right += 1) {
      let dot = 0;
      items[left].tokens.forEach((term: string): void => {
        if (!tokenSets[right].has(term)) return;
        const value = idfs.get(term) ?? 0;
        dot += value * value;
      });
      row.push(norms[left] === 0 || norms[right] === 0 ? 0 : dot / (norms[left] * norms[right]));
    }
    similarities.push(row);
  }
  return similarities;
}

function traditionalCompare(
  left: TraditionalRankedCandidateInternal,
  right: TraditionalRankedCandidateInternal
): number {
  if (Math.abs(left.score - right.score) > 0.0000001) {
    return right.score - left.score;
  }
  if (left.candidate.source === right.candidate.source && left.candidate.providerScore !== undefined &&
    right.candidate.providerScore !== undefined && left.candidate.providerScore !== right.candidate.providerScore) {
    return right.candidate.providerScore - left.candidate.providerScore;
  }
  if (left.epsilon !== right.epsilon) {
    return right.epsilon - left.epsilon;
  }
  return left.candidate.originalIndex - right.candidate.originalIndex;
}

function suppressNearDuplicates(
  items: TraditionalRankedCandidateInternal[],
  similarities: number[][]
): TraditionalRankedCandidateInternal[] {
  const remaining = items.slice();
  remaining.sort(traditionalCompare);
  const kept: TraditionalRankedCandidateInternal[] = [];
  remaining.forEach((item: TraditionalRankedCandidateInternal): void => {
    let duplicate = false;
    kept.forEach((other: TraditionalRankedCandidateInternal): void => {
      if (!duplicate && item.tokens.length >= 5 && other.tokens.length >= 5 &&
        similarities[items.indexOf(item)][items.indexOf(other)] >= 0.88) {
        duplicate = true;
      }
    });
    if (!duplicate) {
      kept.push(item);
    }
  });
  return kept;
}

function mmrOrder(
  items: TraditionalRankedCandidateInternal[],
  lambda: number,
  similarities: number[][],
  corpus: TraditionalRankedCandidateInternal[]
): TraditionalRankedCandidateInternal[] {
  const pool = items.slice();
  const selected: TraditionalRankedCandidateInternal[] = [];
  while (pool.length > 0) {
    let bestIndex = 0;
    let bestScore = -Number.MAX_VALUE;
    for (let index = 0; index < pool.length; index += 1) {
      let similarity = 0;
      selected.forEach((other: TraditionalRankedCandidateInternal): void => {
        similarity = Math.max(similarity, similarities[corpus.indexOf(pool[index])][corpus.indexOf(other)]);
      });
      const score = lambda * pool[index].score - (1 - lambda) * similarity + pool[index].epsilon;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    selected.push(pool.splice(bestIndex, 1)[0]);
  }
  return selected;
}

function stableEpsilon(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967295 * 0.000001;
}

const WATERFALL_STABLE_LIMIT: number = 2;
const WATERFALL_LOW_WATERMARK: number = 3;
const WATERFALL_TARGET_INVENTORY: number = 20;
const WATERFALL_MAX_REQUEST: number = 10;

function copySourceState(source: WaterfallSourceState): WaterfallSourceState {
  return {
    source: source.source,
    phase: source.phase,
    continuation: source.continuation,
    inFlight: source.inFlight,
    reservedCount: source.reservedCount,
    message: source.message,
    query: source.query,
    recallRoute: source.recallRoute,
    loadMode: source.loadMode
  };
}

function copySources(sources: WaterfallSourceState[]): WaterfallSourceState[] {
  return sources.map((source: WaterfallSourceState): WaterfallSourceState => copySourceState(source));
}

function copyState(state: WaterfallFeedState): WaterfallFeedState {
  return {
    mode: state.mode ?? 'search',
    interestFallbackStarted: state.interestFallbackStarted ?? false,
    query: state.query,
    originalQuery: state.originalQuery ?? state.query,
    queryStage: state.queryStage ?? 'original',
    queryHistory: (state.queryHistory ?? [state.query]).slice(),
    consecutiveEmptyRounds: state.consecutiveEmptyRounds ?? 0,
    roundNewItemCount: state.roundNewItemCount ?? 0,
    roundActive: state.roundActive ?? state.sources.some(
      (source: WaterfallSourceState): boolean => source.phase === 'loading'),
    expansionInFlight: state.expansionInFlight ?? false,
    enabledSources: state.enabledSources.slice(),
    preferenceDescription: state.preferenceDescription,
    profile: state.profile,
    shown: state.shown.slice(),
    current: state.current,
    stable: state.stable.slice(),
    tail: state.tail.slice(),
    reserve: (state.reserve ?? []).slice(),
    sources: copySources(state.sources)
  };
}

function idsOf(items: WaterfallRankedCandidate[]): string[] {
  return items.map((item: WaterfallRankedCandidate): string => item.id);
}

function addUniqueId(ids: string[], id: string): void {
  if (ids.indexOf(id) < 0) {
    ids.push(id);
  }
}

function fixedDisplayIds(state: WaterfallFeedState): string[] {
  const ids: string[] = state.shown.map((item: WaterfallRankedCandidate): string => item.id);
  if (state.current !== null) {
    addUniqueId(ids, state.current.id);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => addUniqueId(ids, item.id));
  return ids;
}

function fixedDisplayUrls(state: WaterfallFeedState): string[] {
  const urls: string[] = state.shown.map((item: WaterfallRankedCandidate): string => item.normalizedUrl);
  if (state.current !== null) {
    urls.push(state.current.normalizedUrl);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => {
    urls.push(item.normalizedUrl);
  });
  return urls;
}

function filterEnabled(items: WaterfallRankedCandidate[], enabledSources: string[]): WaterfallRankedCandidate[] {
  return items.filter((item: WaterfallRankedCandidate): boolean => enabledSources.indexOf(item.source) >= 0);
}

function trailingSourceRun(items: WaterfallRankedCandidate[]): number {
  if (items.length === 0) {
    return 0;
  }
  const lastSource = items[items.length - 1].source;
  let run = 1;
  for (let index = items.length - 2; index >= 0; index -= 1) {
    if (items[index].source !== lastSource) {
      break;
    }
    run += 1;
  }
  return run;
}

function limitConsecutiveSources(
  items: WaterfallRankedCandidate[],
  maxRun: number,
  prefix: WaterfallRankedCandidate[]
): WaterfallRankedCandidate[] {
  let lastSource = prefix.length > 0 ? prefix[prefix.length - 1].source : '';
  let run = trailingSourceRun(prefix);
  const remaining = items.slice();
  const ordered: WaterfallRankedCandidate[] = [];
  while (remaining.length > 0) {
    let pick = 0;
    if (run >= maxRun && lastSource.length > 0) {
      for (let index = 0; index < remaining.length; index += 1) {
        if (remaining[index].source !== lastSource) {
          pick = index;
          break;
        }
      }
    }
    const item = remaining.splice(pick, 1)[0];
    if (item.source === lastSource) {
      run += 1;
    } else {
      lastSource = item.source;
      run = 1;
    }
    ordered.push(item);
  }
  return ordered;
}

function frozenPrefix(state: WaterfallFeedState): WaterfallRankedCandidate[] {
  const prefix: WaterfallRankedCandidate[] = [];
  if (state.current !== null) {
    prefix.push(state.current);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => {
    prefix.push(item);
  });
  return prefix;
}

function rankUnshownCandidates(
  state: WaterfallFeedState,
  candidates: WaterfallCandidate[],
  shownIds: string[],
  stableIds: string[],
  nowMs: number
): WaterfallRankedCandidate[] {
  const enabled = rankWaterfallCandidates({
    query: state.query,
    candidates: candidates,
    enabledSources: state.enabledSources,
    shownIds: shownIds,
    stableIds: stableIds,
    preferenceDescription: state.preferenceDescription,
    mode: state.mode ?? 'search',
    profile: state.profile
  }, nowMs);
  const disabledSources: string[] = [];
  candidates.forEach((candidate: WaterfallCandidate): void => {
    if (state.enabledSources.indexOf(candidate.source) < 0 && disabledSources.indexOf(candidate.source) < 0) {
      disabledSources.push(candidate.source);
    }
  });
  if (disabledSources.length === 0) {
    return enabled;
  }
  return enabled.concat(rankWaterfallCandidates({
    query: state.query,
    candidates: candidates,
    enabledSources: disabledSources,
    shownIds: shownIds,
    stableIds: stableIds,
    preferenceDescription: state.preferenceDescription,
    mode: state.mode ?? 'search',
    profile: state.profile
  }, nowMs));
}

function sourceFor(sources: WaterfallSourceState[], source: string): WaterfallSourceState | null {
  for (let index = 0; index < sources.length; index++) {
    if (sources[index].source === source) {
      return sources[index];
    }
  }
  return null;
}

function replaceSource(sources: WaterfallSourceState[], next: WaterfallSourceState): void {
  for (let index = 0; index < sources.length; index++) {
    if (sources[index].source === next.source) {
      sources[index] = next;
      return;
    }
  }
  sources.push(next);
}

function isTerminal(source: WaterfallSourceState): boolean {
  return source.phase === 'needs_auth' || source.phase === 'error' || source.phase === 'exhausted';
}

function refreshStableWindow(state: WaterfallFeedState): void {
  while (state.stable.length < WATERFALL_STABLE_LIMIT && state.tail.length > 0) {
    let nextIndex = -1;
    for (let index = 0; index < state.tail.length; index++) {
      if (state.enabledSources.indexOf(state.tail[index].source) >= 0) {
        nextIndex = index;
        break;
      }
    }
    if (nextIndex < 0) {
      break;
    }
    state.stable.push(state.tail.splice(nextIndex, 1)[0]);
  }
  if (state.stable.length > WATERFALL_STABLE_LIMIT) {
    state.tail = state.stable.splice(WATERFALL_STABLE_LIMIT).concat(state.tail);
  }
}

function refreshCurrentAndStable(state: WaterfallFeedState): void {
  refreshStableWindow(state);
  if (state.current === null && state.stable.length > 0) {
    state.current = state.stable.shift() as WaterfallRankedCandidate;
  }
  refreshStableWindow(state);
}

function activeInventoryCount(state: WaterfallFeedState): number {
  let count = state.current !== null && state.enabledSources.indexOf(state.current.source) >= 0 ? 1 : 0;
  count += filterEnabled(state.stable, state.enabledSources).length;
  count += filterEnabled(state.tail, state.enabledSources).length;
  return count;
}

function totalCandidateCount(state: WaterfallFeedState): number {
  return state.shown.length + (state.current === null ? 0 : 1) + state.stable.length +
    state.tail.length + (state.reserve ?? []).length;
}

function trimWaterfallInventory(state: WaterfallFeedState): void {
  const enabled = state.enabledSources;
  const activeTail: WaterfallRankedCandidate[] = [];
  const disabledTail: WaterfallRankedCandidate[] = [];
  state.tail.forEach((candidate: WaterfallRankedCandidate): void => {
    (enabled.indexOf(candidate.source) >= 0 ? activeTail : disabledTail).push(candidate);
  });
  const currentCount = state.current !== null && enabled.indexOf(state.current.source) >= 0 ? 1 : 0;
  const activeStableCount = filterEnabled(state.stable, enabled).length;
  const keep = Math.max(0, WATERFALL_TARGET_INVENTORY - currentCount - activeStableCount);
  state.tail = activeTail.slice(0, keep).concat(disabledTail);
  state.reserve = activeTail.slice(keep);
}

function promoteReserveToTarget(state: WaterfallFeedState): void {
  const reserve = (state.reserve ?? []).slice();
  if (reserve.length === 0) {
    return;
  }
  const needed = WATERFALL_TARGET_INVENTORY - activeInventoryCount(state);
  if (needed <= 0) {
    return;
  }
  const promoted: WaterfallRankedCandidate[] = [];
  const remaining: WaterfallRankedCandidate[] = [];
  reserve.forEach((candidate: WaterfallRankedCandidate): void => {
    if (promoted.length < needed && state.enabledSources.indexOf(candidate.source) >= 0) {
      promoted.push(candidate);
    } else {
      remaining.push(candidate);
    }
  });
  state.tail = state.tail.concat(promoted);
  state.reserve = remaining;
  refreshStableWindow(state);
}

function nextExpansionStage(stage: WaterfallQueryStage): 'related' | 'adjacent' | null {
  if (stage === 'original') {
    return 'related';
  }
  return stage === 'related' ? 'adjacent' : null;
}

function expansionRequest(state: WaterfallFeedState): WaterfallQueryExpansionRequest | undefined {
  const stage = nextExpansionStage(state.queryStage ?? 'original');
  if (stage === null || state.expansionInFlight === true) {
    return undefined;
  }
  state.expansionInFlight = true;
  return {
    stage: stage,
    originalQuery: state.originalQuery ?? state.query,
    currentQuery: state.query,
    usedQueries: (state.queryHistory ?? [state.query]).slice()
  };
}

function markWaterfallDone(state: WaterfallFeedState): void {
  state.queryStage = 'done';
  state.expansionInFlight = false;
  state.sources.forEach((source: WaterfallSourceState): void => {
    if (state.enabledSources.indexOf(source.source) >= 0) {
      source.phase = 'exhausted';
      source.continuation = null;
      source.inFlight = false;
      source.reservedCount = 0;
    }
  });
}

function finishWaterfallRound(state: WaterfallFeedState): void {
  if (state.roundActive !== true || state.sources.some((source: WaterfallSourceState): boolean =>
    source.inFlight || source.phase === 'loading')) {
    return;
  }
  const newItems = state.roundNewItemCount ?? 0;
  if ((state.queryStage ?? 'original') === 'original') {
    state.consecutiveEmptyRounds = 0;
  } else {
    state.consecutiveEmptyRounds = newItems === 0 ? (state.consecutiveEmptyRounds ?? 0) + 1 : 0;
  }
  state.roundNewItemCount = 0;
  state.roundActive = false;
}

interface WaterfallLoadPlan {
  requests: WaterfallLoadRequest[];
  expansion?: WaterfallQueryExpansionRequest;
}

function planWaterfallLoads(state: WaterfallFeedState): WaterfallLoadPlan {
  const requests: WaterfallLoadRequest[] = [];
  if (state.enabledSources.length === 0) {
    return { requests: requests };
  }
  finishWaterfallRound(state);
  if ((state.consecutiveEmptyRounds ?? 0) >= 2) {
    state.sources.forEach((source: WaterfallSourceState): void => {
      source.continuation = null;
      source.inFlight = false;
      source.reservedCount = 0;
      if (state.enabledSources.indexOf(source.source) >= 0) {
        source.phase = 'exhausted';
      }
    });
    if ((state.queryStage ?? 'original') === 'adjacent' || (state.queryStage ?? 'original') === 'done') {
      markWaterfallDone(state);
      return { requests: requests };
    }
    return { requests: requests, expansion: expansionRequest(state) };
  }
  promoteReserveToTarget(state);
  if (activeInventoryCount(state) > WATERFALL_LOW_WATERMARK) {
    return { requests: requests };
  }
  if (state.sources.some((source: WaterfallSourceState): boolean =>
    source.inFlight || source.phase === 'loading')) {
    return { requests: requests };
  }

  const hasContinuation = state.sources.some((source: WaterfallSourceState): boolean =>
    state.enabledSources.indexOf(source.source) >= 0 && source.continuation !== null && !isTerminal(source));
  if (!hasContinuation) {
    state.sources.forEach((source: WaterfallSourceState): void => {
      if (state.enabledSources.indexOf(source.source) >= 0 && source.phase === 'success') {
        source.phase = 'exhausted';
      }
    });
    if ((state.queryStage ?? 'original') === 'adjacent' || (state.queryStage ?? 'original') === 'done') {
      markWaterfallDone(state);
      return { requests: requests };
    }
    return { requests: requests, expansion: expansionRequest(state) };
  }

  state.sources.forEach((source: WaterfallSourceState): void => {
    if (source.inFlight || source.phase === 'loading') {
      return;
    }
    requests.push({
      source: source.source,
      continuation: source.continuation,
      limit: WATERFALL_MAX_REQUEST,
      phase: source.phase,
      message: source.message,
      mode: 'native'
    });
    source.inFlight = true;
    source.reservedCount += WATERFALL_MAX_REQUEST;
  });
  state.roundNewItemCount = 0;
  state.roundActive = true;
  return { requests: requests };
}

function planWaterfallInterestLoads(state: WaterfallFeedState): WaterfallLoadRequest[] {
  if (state.current === null && !state.sources.some((source: WaterfallSourceState): boolean =>
    state.enabledSources.indexOf(source.source) >= 0 && (source.inFlight || source.phase === 'loading'))) {
    refreshCurrentAndStable(state);
  }
  promoteReserveToTarget(state);
  if (activeInventoryCount(state) > WATERFALL_LOW_WATERMARK) return [];
  const requests: WaterfallLoadRequest[] = [];
  state.sources.forEach((source: WaterfallSourceState): void => {
    if (state.enabledSources.indexOf(source.source) < 0 || source.inFlight || source.phase === 'loading' ||
      source.phase === 'empty' || isTerminal(source)) return;
    requests.push({
      source: source.source,
      continuation: source.continuation,
      limit: WATERFALL_MAX_REQUEST,
      phase: source.phase,
      message: source.message,
      mode: source.loadMode ??
        (source.source === 'youtube' && source.recallRoute === 'popular' ? 'native' : 'search'),
      query: source.query ?? '',
      route: source.recallRoute ?? 'explore'
    });
    source.inFlight = true;
    source.reservedCount += WATERFALL_MAX_REQUEST;
  });
  return requests;
}

function finalizeUpdate(state: WaterfallFeedState): WaterfallFeedUpdate {
  if ((state.mode ?? 'search') === 'interest') {
    return { state: state, loadRequests: planWaterfallInterestLoads(state) };
  }
  const plan = planWaterfallLoads(state);
  return { state: state, loadRequests: plan.requests, expansionRequest: plan.expansion };
}

export function planWaterfallContinuation(state: WaterfallFeedState): WaterfallFeedUpdate {
  return finalizeUpdate(copyState(state));
}

function rankedToCandidates(items: WaterfallRankedCandidate[]): WaterfallCandidate[] {
  return items.map((item: WaterfallRankedCandidate): WaterfallCandidate => ({
    id: item.id,
    source: item.source,
    provider: item.provider,
    mediaType: item.mediaType,
    title: item.title,
    summary: item.summary,
    url: item.url,
    coverUrl: item.coverUrl,
    mediaUrl: item.mediaUrl,
    feedUrl: item.feedUrl,
    providerItemId: item.providerItemId,
    comments: item.comments,
    commentLoadState: item.commentLoadState,
    audioTitle: item.audioTitle,
    audioMimeType: item.audioMimeType,
    audioDuration: item.audioDuration,
    audioPublishedAt: item.audioPublishedAt,
    audioLoadState: item.audioLoadState,
    audioError: item.audioError,
    audioRetryable: item.audioRetryable,
    publishedAt: item.publishedAt,
    duration: item.duration,
    originalIndex: item.originalIndex,
    searchQuery: item.searchQuery,
    queryStage: item.queryStage,
    sourceRank: item.sourceRank,
    providerScore: item.providerScore,
    authorName: item.authorName,
    authorAvatarUrl: item.authorAvatarUrl,
    metrics: item.metrics,
    topics: item.topics,
    format: item.format,
    recallRoute: item.recallRoute,
    recallWeight: item.recallWeight
  }));
}

export function applyWaterfallProfile(
  state: WaterfallFeedState,
  profile: WaterfallPreferenceSnapshot,
  nowMs: number
): WaterfallFeedUpdate {
  const next = copyState(state);
  next.profile = profile;
  next.tail = limitConsecutiveSources(
    rankUnshownCandidates(
      next,
      rankedToCandidates(next.tail).concat(rankedToCandidates(next.reserve ?? [])),
      fixedDisplayIds(next),
      idsOf(next.stable),
      nowMs
    ),
    WATERFALL_STABLE_LIMIT,
    frozenPrefix(next)
  );
  next.reserve = [];
  trimWaterfallInventory(next);
  return finalizeUpdate(next);
}

function deferredRankedCandidate(candidate: WaterfallCandidate): WaterfallRankedCandidate {
  return {
    id: candidate.id,
    source: candidate.source,
    provider: candidate.provider,
    mediaType: candidate.mediaType,
    title: candidate.title,
    summary: candidate.summary,
    url: candidate.url,
    coverUrl: candidate.coverUrl,
    mediaUrl: candidate.mediaUrl,
    feedUrl: candidate.feedUrl,
    providerItemId: candidate.providerItemId,
    comments: candidate.comments,
    commentLoadState: candidate.commentLoadState,
    audioTitle: candidate.audioTitle,
    audioMimeType: candidate.audioMimeType,
    audioDuration: candidate.audioDuration,
    audioPublishedAt: candidate.audioPublishedAt,
    audioLoadState: candidate.audioLoadState,
    audioError: candidate.audioError,
    audioRetryable: candidate.audioRetryable,
    publishedAt: candidate.publishedAt,
    duration: candidate.duration,
    originalIndex: candidate.originalIndex,
    searchQuery: candidate.searchQuery,
    queryStage: candidate.queryStage,
    sourceRank: candidate.sourceRank,
    providerScore: candidate.providerScore,
    authorName: candidate.authorName,
    authorAvatarUrl: candidate.authorAvatarUrl,
    metrics: candidate.metrics,
    topics: candidate.topics,
    format: candidate.format,
    recallRoute: candidate.recallRoute,
    recallWeight: candidate.recallWeight,
    normalizedUrl: normalizedHttpUrl(candidate.url),
    signals: {
      relevanceTier: 0,
      titleHits: 0,
      summaryHits: 0,
      freshnessTier: 0
    },
    reason: '等待最终排序'
  };
}

function deferredInventory(state: WaterfallFeedState): WaterfallRankedCandidate[] {
  const items: WaterfallRankedCandidate[] = state.shown.slice();
  if (state.current !== null) {
    items.push(state.current);
  }
  return items.concat(state.stable).concat(state.tail).concat(state.reserve ?? []);
}

interface BoundedInterestRankingCorpus {
  active: WaterfallCandidate[];
  overflow: WaterfallCandidate[];
}

function boundedInterestRankingCorpus(
  state: WaterfallFeedState,
  candidates: WaterfallCandidate[],
  activeLimit: number
): BoundedInterestRankingCorpus {
  const fixedIds = fixedDisplayIds(state);
  const fixedUrls = fixedDisplayUrls(state);
  const sourceOrder = state.enabledSources.slice();
  const sourceBuckets: WaterfallCandidate[][] = sourceOrder.map((): WaterfallCandidate[] => []);
  const acceptedIds: string[] = [];
  const acceptedUrls: string[] = [];
  candidates.forEach((candidate: WaterfallCandidate): void => {
    const sourceIndex = sourceOrder.indexOf(candidate.source);
    const normalizedUrl = normalizedHttpUrl(candidate.url);
    if (sourceIndex < 0 || fixedIds.indexOf(candidate.id) >= 0 || acceptedIds.indexOf(candidate.id) >= 0 ||
      (normalizedUrl.length > 0 &&
        (fixedUrls.indexOf(normalizedUrl) >= 0 || acceptedUrls.indexOf(normalizedUrl) >= 0))) {
      return;
    }
    sourceBuckets[sourceIndex].push(candidate);
    acceptedIds.push(candidate.id);
    if (normalizedUrl.length > 0) acceptedUrls.push(normalizedUrl);
  });

  const offsets: number[] = sourceBuckets.map((): number => 0);
  const ordered: WaterfallCandidate[] = [];
  let added = true;
  while (added) {
    added = false;
    for (let index = 0; index < sourceBuckets.length; index += 1) {
      if (offsets[index] < sourceBuckets[index].length) {
        ordered.push(sourceBuckets[index][offsets[index]]);
        offsets[index] += 1;
        added = true;
      }
    }
  }
  const limit = Math.max(0, Math.min(activeLimit, WATERFALL_TARGET_INVENTORY));
  return { active: ordered.slice(0, limit), overflow: ordered.slice(limit) };
}

export function mergeWaterfallBatchDeferredRanking(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  refreshDisplayWindow: boolean = true
): WaterfallFeedUpdate {
  const next = copyState(state);
  const previousCount = totalCandidateCount(next);
  const received = copySourceState(sourceState);
  replaceSource(next.sources, received);
  if ((next.reserve ?? []).length > 0) {
    next.tail = next.tail.concat(next.reserve ?? []);
    next.reserve = [];
  }

  const occupied = deferredInventory(next);
  const occupiedIds = idsOf(occupied);
  const occupiedUrls = occupied.map((item: WaterfallRankedCandidate): string => item.normalizedUrl)
    .filter((url: string): boolean => url.length > 0);
  incoming.forEach((candidate: WaterfallCandidate): void => {
    const normalizedUrl = normalizedHttpUrl(candidate.url);
    if (occupiedIds.indexOf(candidate.id) >= 0 ||
      (normalizedUrl.length > 0 && occupiedUrls.indexOf(normalizedUrl) >= 0)) {
      return;
    }
    next.tail.push(deferredRankedCandidate(candidate));
    occupiedIds.push(candidate.id);
    if (normalizedUrl.length > 0) {
      occupiedUrls.push(normalizedUrl);
    }
  });
  if (refreshDisplayWindow) {
    refreshCurrentAndStable(next);
  }
  trimWaterfallInventory(next);
  next.roundNewItemCount = (next.roundNewItemCount ?? 0) +
    Math.max(0, totalCandidateCount(next) - previousCount);
  return { state: next, loadRequests: [] };
}

export function finalizeDeferredWaterfallRanking(
  state: WaterfallFeedState,
  nowMs: number
): WaterfallFeedState {
  const next = copyState(state);
  const unshown = rankedToCandidates(
    (next.current === null ? [] : [next.current])
      .concat(next.stable)
      .concat(next.tail)
      .concat(next.reserve ?? [])
  );
  const allSources: string[] = [];
  unshown.forEach((candidate: WaterfallCandidate): void => {
    if (allSources.indexOf(candidate.source) < 0) {
      allSources.push(candidate.source);
    }
  });
  next.current = null;
  next.stable = [];
  next.tail = rankWaterfallCandidates({
    query: next.query,
    candidates: unshown,
    enabledSources: allSources,
    shownIds: idsOf(next.shown),
    stableIds: [],
    preferenceDescription: next.preferenceDescription,
    mode: next.mode ?? 'search',
    profile: next.profile
  }, nowMs);
  next.reserve = [];
  refreshCurrentAndStable(next);
  trimWaterfallInventory(next);
  return next;
}

export function finalizeInterestWaterfallRecallRanking(
  state: WaterfallFeedState,
  nowMs: number
): WaterfallFeedState {
  const next = copyState(state);
  const fixedActiveCount = (next.current !== null && next.enabledSources.indexOf(next.current.source) >= 0 ? 1 : 0) +
    filterEnabled(next.stable, next.enabledSources).length;
  const availableTailSlots = Math.max(0, WATERFALL_TARGET_INVENTORY - fixedActiveCount);
  const corpus = boundedInterestRankingCorpus(
    next, rankedToCandidates(next.tail.concat(next.reserve ?? [])), availableTailSlots);
  next.tail = rankWaterfallCandidates({
    query: next.query,
    candidates: corpus.active,
    enabledSources: next.enabledSources,
    shownIds: fixedDisplayIds(next),
    stableIds: idsOf(next.stable),
    preferenceDescription: next.preferenceDescription,
    mode: 'interest',
    profile: next.profile
  }, nowMs).slice(0, availableTailSlots);
  next.reserve = [];
  refreshCurrentAndStable(next);
  trimWaterfallInventory(next);
  next.reserve = corpus.overflow.map(
    (candidate: WaterfallCandidate): WaterfallRankedCandidate => deferredRankedCandidate(candidate));
  return next;
}

function finalizeDeferredWaterfallTailRanking(
  state: WaterfallFeedState,
  nowMs: number
): WaterfallFeedState {
  const next = copyState(state);
  const candidates = rankedToCandidates(next.tail.concat(next.reserve ?? []));
  const allSources: string[] = [];
  candidates.forEach((candidate: WaterfallCandidate): void => {
    if (allSources.indexOf(candidate.source) < 0) {
      allSources.push(candidate.source);
    }
  });
  next.tail = rankWaterfallCandidates({
    query: next.query,
    candidates: candidates,
    enabledSources: allSources,
    shownIds: fixedDisplayIds(next),
    stableIds: idsOf(next.stable),
    preferenceDescription: next.preferenceDescription,
    mode: next.mode ?? 'search',
    profile: next.profile
  }, nowMs);
  next.reserve = [];
  refreshCurrentAndStable(next);
  trimWaterfallInventory(next);
  return next;
}

function sortTail(state: WaterfallFeedState, incoming: WaterfallCandidate[], nowMs: number): WaterfallRankedCandidate[] {
  const fixedIds = fixedDisplayIds(state);
  const fixedUrls = fixedDisplayUrls(state);
  const filteredIncoming: WaterfallCandidate[] = incoming.filter((candidate: WaterfallCandidate): boolean => {
    if (fixedIds.indexOf(candidate.id) >= 0) {
      return false;
    }
    return fixedUrls.indexOf(normalizedHttpUrl(candidate.url)) < 0;
  });
  const occupied: WaterfallRankedCandidate[] = state.shown.slice();
  if (state.current !== null) {
    occupied.push(state.current);
  }
  state.stable.forEach((item: WaterfallRankedCandidate): void => {
    occupied.push(item);
  });
  const candidates: WaterfallCandidate[] = rankedToCandidates(occupied)
    .concat(rankedToCandidates(state.tail))
    .concat(rankedToCandidates(state.reserve ?? []))
    .concat(filteredIncoming);
  // ponytail: cap same-source runs at the frozen window; full MMR source-sim if this over-mixes.
  return limitConsecutiveSources(
    rankUnshownCandidates(state, candidates, fixedIds, idsOf(state.stable), nowMs),
    WATERFALL_STABLE_LIMIT,
    frozenPrefix(state)
  );
}

function placeInitialBatch(state: WaterfallFeedState, incoming: WaterfallCandidate[], nowMs: number): void {
  const candidates = rankedToCandidates(state.stable)
    .concat(rankedToCandidates(state.tail))
    .concat(rankedToCandidates(state.reserve ?? []))
    .concat(incoming);
  state.stable = [];
  state.tail = rankUnshownCandidates(state, candidates, idsOf(state.shown), [], nowMs);
  state.reserve = [];
  refreshCurrentAndStable(state);
  trimWaterfallInventory(state);
}

export function mergeWaterfallBatch(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  nowMs: number,
  planLoads: boolean = true
): WaterfallFeedUpdate {
  const next = mergeWaterfallBatchState(state, incoming, sourceState, nowMs);
  return planLoads ? finalizeUpdate(next) : { state: next, loadRequests: [] };
}

function mergeWaterfallBatchState(
  state: WaterfallFeedState,
  incoming: WaterfallCandidate[],
  sourceState: WaterfallSourceState,
  nowMs: number
): WaterfallFeedState {
  const next = copyState(state);
  const previousCount = totalCandidateCount(next);
  const received = copySourceState(sourceState);
  received.inFlight = false;
  received.reservedCount = 0;
  replaceSource(next.sources, received);
  if (next.current === null) {
    placeInitialBatch(next, incoming, nowMs);
  } else {
    // ponytail: small feed snapshots use a linear scan; add indexed URLs only if the pool grows materially.
    next.tail = sortTail(next, incoming, nowMs);
    refreshStableWindow(next);
    trimWaterfallInventory(next);
  }
  next.roundNewItemCount = (next.roundNewItemCount ?? 0) +
    Math.max(0, totalCandidateCount(next) - previousCount);
  return next;
}

function normalizedQuery(value: string): string {
  return value.trim().replace(/\s+/g, ' ').toLowerCase();
}

export function parseWaterfallExpandedQuery(raw: string, currentQuery: string): string {
  try {
    const objects = extractJsonObjects(raw);
    if (objects.length !== 1) {
      return '';
    }
    const parsed = JSON.parse(objects[0]) as Record<string, WaterfallExpansionJsonValue>;
    if (Object.keys(parsed).length !== 1 || typeof parsed.query !== 'string') {
      return '';
    }
    const query = parsed.query.trim().replace(/\s+/g, ' ');
    if (query.length === 0 || query.length > 120 || normalizedQuery(query) === normalizedQuery(currentQuery)) {
      return '';
    }
    return query;
  } catch (_error) {
    return '';
  }
}

export function waterfallExpansionPrompt(request: WaterfallQueryExpansionRequest): string {
  const used = request.usedQueries.join(' | ');
  if (request.stage === 'related') {
    return 'Return exactly one JSON object {"query":"..."}. Generate one concise search query using a synonym, alias, or closely related entity for the original topic. ' +
      'Stay on the same topic and do not repeat any used query. Original: ' + request.originalQuery +
      '. Current: ' + request.currentQuery + '. Used: ' + used;
  }
  return 'Return exactly one JSON object {"query":"..."}. Generate one concise search query for an immediately adjacent parent or child topic. ' +
    'Do not switch to an unrelated topic and do not repeat any used query. Original: ' + request.originalQuery +
    '. Current: ' + request.currentQuery + '. Used: ' + used;
}

export function applyWaterfallExpandedQuery(
  state: WaterfallFeedState,
  stage: 'related' | 'adjacent',
  query: string,
  _nowMs: number
): WaterfallFeedUpdate {
  const next = copyState(state);
  const normalized = normalizedQuery(query);
  const used = (next.queryHistory ?? [next.query]).map((item: string): string => normalizedQuery(item));
  if (normalized.length === 0 || normalized.length > 120 || used.indexOf(normalized) >= 0) {
    markWaterfallDone(next);
    return { state: next, loadRequests: [] };
  }
  next.query = query.trim().replace(/\s+/g, ' ');
  next.queryStage = stage;
  next.queryHistory = (next.queryHistory ?? [state.query]).concat([next.query]);
  next.expansionInFlight = false;
  next.roundNewItemCount = 0;
  next.roundActive = true;
  next.sources.forEach((source: WaterfallSourceState): void => {
    source.phase = 'loading';
    source.continuation = null;
    source.inFlight = true;
    source.reservedCount = WATERFALL_MAX_REQUEST;
    source.message = '';
  });
  const requests = next.sources.map((source: WaterfallSourceState): WaterfallLoadRequest => ({
    source: source.source,
    continuation: null,
    limit: WATERFALL_MAX_REQUEST,
    phase: 'loading',
    message: '',
    mode: 'search'
  }));
  return { state: next, loadRequests: requests };
}

export function failWaterfallExpansion(
  state: WaterfallFeedState,
  stage: 'related' | 'adjacent'
): WaterfallFeedUpdate {
  const next = copyState(state);
  if (stage === 'related') {
    next.queryStage = 'related';
    next.expansionInFlight = false;
    return finalizeUpdate(next);
  }
  markWaterfallDone(next);
  return { state: next, loadRequests: [] };
}

export function mergeWaterfallFeedSnapshot(
  state: WaterfallFeedState,
  incoming: WaterfallFeedState,
  nowMs: number,
  planLoads: boolean = true
): WaterfallFeedUpdate {
  let next = copyState(state);
  const candidates = rankedToCandidates(
    (incoming.current === null ? [] : [incoming.current]).concat(
      incoming.stable, incoming.tail, incoming.reserve ?? [])
  );
  const partial = incoming.sources.some((source: WaterfallSourceState): boolean =>
    source.inFlight || source.phase === 'loading');
  incoming.sources.forEach((source: WaterfallSourceState): void => {
    next = mergeWaterfallBatchDeferredRanking(
      next,
      candidates.filter((candidate: WaterfallCandidate): boolean => candidate.source === source.source),
      source,
      partial
    ).state;
  });
  if (!partial) {
    next = finalizeDeferredWaterfallTailRanking(next, nowMs);
  }
  return planLoads ? finalizeUpdate(next) : { state: next, loadRequests: [] };
}

export function advanceWaterfallFeed(
  state: WaterfallFeedState,
  nowMs: number,
  targetId: string = ''
): WaterfallFeedUpdate {
  const next = copyState(state);
  const target = targetId.trim();
  let steps = 0;
  const maxSteps = totalCandidateCount(next);
  while (next.current !== null && steps < maxSteps) {
    if (target.length === 0) {
      next.shown.push(next.current);
      next.current = null;
      refreshCurrentAndStable(next);
      break;
    }
    if (next.current.id === target) {
      break;
    }
    const remaining: WaterfallRankedCandidate[] = next.stable.concat(next.tail).concat(next.reserve ?? []);
    let found = false;
    for (let index = 0; index < remaining.length; index += 1) {
      if (remaining[index].id === target) {
        found = true;
        break;
      }
    }
    if (!found) {
      break;
    }
    next.shown.push(next.current);
    next.current = null;
    refreshCurrentAndStable(next);
    steps += 1;
  }
  return finalizeUpdate(next);
}

export function applyWaterfallSourceSelection(
  state: WaterfallFeedState,
  enabledSources: string[],
  nowMs: number
): WaterfallFeedUpdate {
  const next = copyState(state);
  const missingSources = enabledSources.filter((source: string): boolean =>
    next.sources.every((existing: WaterfallSourceState): boolean => existing.source !== source));
  missingSources.forEach((source: string): void => {
    next.sources.push({
      source,
      phase: 'loading',
      continuation: null,
      inFlight: true,
      reservedCount: WATERFALL_MAX_REQUEST,
      message: ''
    });
  });
  next.enabledSources = enabledSources.slice();
  if (next.current !== null && enabledSources.indexOf(next.current.source) < 0) {
    next.shown.push(next.current);
    next.current = null;
  }
  const allUnshown = rankedToCandidates(next.stable)
    .concat(rankedToCandidates(next.tail))
    .concat(rankedToCandidates(next.reserve ?? []));
  next.stable = [];
  next.tail = rankUnshownCandidates(
    next,
    allUnshown,
    idsOf(next.shown).concat(next.current === null ? [] : [next.current.id]),
    [],
    nowMs
  );
  next.reserve = [];
  refreshCurrentAndStable(next);
  trimWaterfallInventory(next);
  if ((next.mode ?? 'search') === 'search' && missingSources.length > 0) {
    next.roundActive = true;
    return {
      state: next,
      loadRequests: missingSources.map((source: string): WaterfallLoadRequest => ({
        source,
        continuation: null,
        limit: WATERFALL_MAX_REQUEST,
        phase: 'loading',
        message: '',
        mode: 'search'
      }))
    };
  }
  return finalizeUpdate(next);
}
