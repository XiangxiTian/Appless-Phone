import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  callComposioDynamicWithProviderData,
  callComposioFixedDynamic,
  callComposioFixedDynamicWithProviderData
} from './ComposioDynamicBackend';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { callMediaVideoSearch } from './MediaVideoClient';
import { callBilibiliVideoComments } from './BilibiliApiClient';
import { callYouTubeVideoComments } from './YouTubeApiClient';
import { searchApplePodcasts } from './ApplePodcastClient';
import { loadCnNewsSource } from './PublicFeedClient';
import { discoverPublicGitHub, searchPublicGitHub } from './GitHubPublicClient';
import { discoverSteamNews } from './SteamNewsClient';
import { GlobalNewsConfig, loadGlobalNews } from './GlobalNewsClient';
import {
  DoubanPlaywrightMcpClient,
  DoubanPlaywrightMcpConfig,
  DoubanPublicSearchItem
} from './DoubanPlaywrightMcpClient';
import {
  discoverTwitchInterestStreams,
  searchTwitchChannels,
  TwitchChannelSearchBatch,
  TwitchChannelSearchItem,
  TwitchSearchConfig
} from './TwitchSearchClient';
import { aiLogInfo } from './AiphoneLogger';
import {
  AggregateSearchPolicy,
  AggregateSearchPost,
  AggregateSearchResult,
  AggregateSearchRowData,
  AggregateSearchSource,
  AggregateSearchSourceContext,
  AggregateSearchSourceMetadata,
  AggregateSearchStatus,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  aggregateSourceLabel,
  AggregateSearchSourceBatch
} from './AggregateSearchTypes';
import {
  aggregateSearchRegistryMetadata,
  aggregateSearchRegistryMetadataFor,
  aggregateSearchRegistrySourceIds,
  aggregateSearchSearchSourceIds,
  aggregateSearchSourceIdsForContext
} from './AggregateSearchSourceRegistry';
import {
  WaterfallCandidate,
  WaterfallComment,
  WaterfallCommentsResult,
  WaterfallContinuation,
  WaterfallFeedState,
  WaterfallFormat,
  WaterfallLoadRequest,
  WaterfallMetric,
  WaterfallPreferenceSnapshot,
  WaterfallQueryStage,
  WaterfallRecallRoute,
  WaterfallSourceState,
  WaterfallSourcePhase,
  finalizeDeferredWaterfallRanking,
  mergeWaterfallBatch,
  mergeWaterfallBatchDeferredRanking,
  waterfallTextTokens
} from './WaterfallAnythingCore';

type AggregateArgValue = Object | string | number | boolean | null | undefined;
type AggregateArgRecord = Record<string, AggregateArgValue>;
type DynamicPostValue = Object | string | number | boolean | null | undefined;
type DynamicPostRecord = Record<string, DynamicPostValue>;

interface AggregateMediaSearchArgs {
  query: string;
  sources: string[];
  limit: number;
  page?: number;
  pageToken?: string;
  language?: string;
}

interface AggregateXSearchArgs {
  query: string;
  pageSize: number;
  expansions: string;
  mediaFields: string;
  tweetFields: string;
  userFields?: string;
  cursor?: string;
}

interface AggregateHackerNewsSearchArgs {
  query: string;
  page: number;
  size: number;
}

interface AggregateRedditSearchArgs {
  searchQuery: string;
  limit: number;
  cursor?: string;
}

interface AggregateRedditCommentsArgs {
  articleId: string;
}

interface AggregateHackerNewsItemArgs {
  itemId: string;
}

function decodeHttpUrl(value: string): string {
  return value.replace(/&amp;/g, '&').trim();
}

function isDisplayableImageUrl(value: string): boolean {
  const url = decodeHttpUrl(value).toLowerCase();
  if (!url.startsWith('http')) return false;
  if (url === 'self' || url === 'default' || url === 'nsfw' || url === 'spoiler' || url === 'image') {
    return false;
  }
  if (url.indexOf('v.redd.it/') >= 0 || url.indexOf('/comments/') >= 0 ||
    url.indexOf('reddit.com/gallery') >= 0) {
    return false;
  }
  if (url.indexOf('.jpg') >= 0 || url.indexOf('.jpeg') >= 0 || url.indexOf('.png') >= 0 ||
    url.indexOf('.webp') >= 0 || url.indexOf('.gif') >= 0 || url.indexOf('image') >= 0 ||
    url.indexOf('pic') >= 0 || url.indexOf('thumb') >= 0) {
    return true;
  }
  // ponytail: host heuristic; native fetch+Referer proxy if Reddit CDN still 403s in WebView
  return url.indexOf('i.redd.it/') >= 0 || url.indexOf('preview.redd.it/') >= 0 ||
    url.indexOf('thumbs.redditmedia.com/') >= 0 || url.indexOf('i.imgur.com/') >= 0 ||
    url.indexOf('pbs.twimg.com/') >= 0;
}

export function redditImageDeliveryUrl(value: string): string {
  const url = decodeHttpUrl(value);
  const lower = url.toLowerCase();
  if (!lower.startsWith('https://i.redd.it/') && !lower.startsWith('https://preview.redd.it/') &&
    !lower.startsWith('https://external-preview.redd.it/') &&
    !lower.startsWith('https://thumbs.redditmedia.com/')) {
    return url;
  }
  // ponytail: public cache is enough here; use an owned weserv deployment if an image SLA becomes necessary.
  return 'https://wsrv.nl/?url=' + encodeURIComponent(url) + '&output=webp&w=1200';
}

function appendImageUrl(urls: string[], value: string): void {
  const url = decodeHttpUrl(value);
  if (!isDisplayableImageUrl(url)) return;
  const deliveredUrl = redditImageDeliveryUrl(url);
  if (urls.indexOf(deliveredUrl) >= 0) return;
  urls.push(deliveredUrl);
}

function waterfallPostCoverUrl(post: AggregateSearchPost): string {
  const labels: string[] = ['mediaurl', 'image', 'images', 'thumbnail', 'cover', 'pic', 'picture'];
  for (let index = 0; index < post.rows.length; index++) {
    const label = post.rows[index].label.trim().toLowerCase();
    if (labels.indexOf(label) < 0) continue;
    const parts = post.rows[index].value.trim().split(/\s+/);
    for (let part = 0; part < parts.length; part++) {
      const url = decodeHttpUrl(parts[part]);
      if (isDisplayableImageUrl(url)) return url;
    }
  }
  return '';
}

function playableVideoPageUrl(value: string): boolean {
  const lower = value.trim().toLowerCase();
  return lower.indexOf('youtube.com/watch') >= 0 || lower.indexOf('youtu.be/') >= 0 ||
    lower.indexOf('bilibili.com/video/') >= 0;
}

function waterfallPostVideoUrl(post: AggregateSearchPost): string {
  const labels: string[] = ['video', 'videourl', 'video_url', 'playbackurl', 'playback_url', 'fallback_url'];
  for (let index = 0; index < post.rows.length; index++) {
    const label = post.rows[index].label.trim().toLowerCase();
    const value = post.rows[index].value.trim();
    if (labels.indexOf(label) >= 0 && value.toLowerCase().startsWith('http')) {
      return value.split(/\s+/)[0];
    }
  }
  return '';
}

function waterfallTitle(value: string): string {
  return /^result\s+\d+$/i.test(value.trim()) ? '' : value;
}

function normalizedMetricLabel(value: string): string {
  return value.trim().toLowerCase().replace(/[\s_-]+/g, '');
}

function aggregateRowText(rows: AggregateSearchRowData[], labels: string[]): string {
  for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    const label = normalizedMetricLabel(rows[rowIndex].label);
    for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      if (label === normalizedMetricLabel(labels[labelIndex])) return rows[rowIndex].value.trim();
    }
  }
  return '';
}

function metricNumber(value: string): number | undefined {
  const parsed = Number(value.trim().replace(/,/g, ''));
  return value.trim().length > 0 && Number.isFinite(parsed) && parsed >= 0 ? parsed : undefined;
}

function addMetric(metrics: WaterfallMetric[], kind: string, value: string): void {
  const parsed = metricNumber(value);
  if (parsed !== undefined) metrics.push({ kind: kind, value: parsed });
}

function videoMetrics(video: AggregateSearchVideo): WaterfallMetric[] {
  const metrics: WaterfallMetric[] = [];
  addMetric(metrics, 'view', aggregateRowText(video.rows, ['Views', 'View Count', 'Play']));
  addMetric(metrics, 'like', aggregateRowText(video.rows, ['Likes', 'Like Count']));
  addMetric(metrics, 'favorite', aggregateRowText(video.rows, ['Favorites', 'Favorite Count']));
  addMetric(metrics, 'comment', aggregateRowText(video.rows, ['Comments', 'Comment Count', 'Replies']));
  addMetric(metrics, 'coin', aggregateRowText(video.rows, ['Coins']));
  addMetric(metrics, 'danmaku', aggregateRowText(video.rows, ['Danmaku']));
  addMetric(metrics, 'share', aggregateRowText(video.rows, ['Shares']));
  return metrics;
}

function postMetrics(post: AggregateSearchPost): WaterfallMetric[] {
  const metrics: WaterfallMetric[] = [];
  if (post.source === 'github') {
    addMetric(metrics, 'star', aggregateRowText(post.rows, ['Stars']));
    addMetric(metrics, 'fork', aggregateRowText(post.rows, ['Forks']));
    return metrics;
  }
  const record = post.rows.length > 0 ? dynamicPostRecord(post.rows[0].value) : null;
  const publicMetrics = record === null ? null : dynamicRecord(record.public_metrics);
  if (post.source === 'x' && publicMetrics !== null) {
    addMetric(metrics, 'view', recordText(publicMetrics, ['impression_count']));
    addMetric(metrics, 'like', recordText(publicMetrics, ['like_count']));
    addMetric(metrics, 'comment', recordText(publicMetrics, ['reply_count']));
    addMetric(metrics, 'repost', recordText(publicMetrics, ['retweet_count']));
    addMetric(metrics, 'quote', recordText(publicMetrics, ['quote_count']));
    addMetric(metrics, 'favorite', recordText(publicMetrics, ['bookmark_count']));
    return metrics;
  }
  addMetric(metrics, post.source === 'zhihu' ? 'like' : 'score', post.score);
  addMetric(metrics, 'comment', post.commentCount);
  return metrics;
}

function aggregateAvatar(rows: AggregateSearchRowData[]): string {
  const avatar = aggregateRowText(rows, ['Author Avatar', 'authorAvatar', 'Avatar', 'upic']);
  return avatar.startsWith('http') ? avatar : '';
}

function commentsFromRows(rows: AggregateSearchRowData[]): WaterfallComment[] {
  const comments: WaterfallComment[] = [];
  rows.forEach((row: AggregateSearchRowData): void => {
    const label = row.label.trim().toLowerCase();
    const value = row.value.trim();
    if ((label === 'comment' || label === 'reply') && value.length > 0 && comments.length < 5 &&
      comments.every((comment: WaterfallComment): boolean => comment.text !== value)) {
      comments.push({ text: value });
    }
  });
  return comments;
}

export function aggregateMediaCandidates(
  videos: AggregateSearchVideo[],
  posts: AggregateSearchPost[],
  batchIndex: number,
  searchQuery: string = '',
  queryStage: WaterfallQueryStage = 'original',
  recallRoute: WaterfallRecallRoute = 'search',
  recallWeight: number = 1
): WaterfallCandidate[] {
  const candidates: WaterfallCandidate[] = [];
  const sourceCounts: Record<string, number> = {};
  const nextSourceRank = (source: string): number => {
    const rank = (sourceCounts[source] ?? 0) + 1;
    sourceCounts[source] = rank;
    return rank;
  };
  const topicsFor = (title: string, summary: string): string[] =>
    waterfallTextTokens(title + ' ' + summary);
  videos.forEach((video: AggregateSearchVideo, index: number) => {
    const metrics = videoMetrics(video);
    const providerItemId = video.source === 'bilibili' ?
      aggregateRowText(video.rows, ['AID']) :
      aggregateRowText(video.rows, ['Video ID']);
    candidates.push({
      id: video.id,
      source: video.source,
      provider: video.provider,
      mediaType: 'video',
      title: video.title,
      summary: video.summary,
      url: video.url,
      coverUrl: video.thumbnail,
      providerItemId: providerItemId || undefined,
      publishedAt: video.publishedAt,
      duration: video.duration,
      originalIndex: batchIndex * 1000 + index,
      searchQuery: searchQuery,
      queryStage: queryStage,
      sourceRank: nextSourceRank(video.source),
      authorName: aggregateRowText(video.rows, ['Channel', 'Author', 'Owner']) || undefined,
      authorAvatarUrl: aggregateAvatar(video.rows) || undefined,
      metrics: metrics.length > 0 ? metrics : undefined,
      topics: topicsFor(video.title, video.summary),
      format: 'landscape_video',
      recallRoute: recallRoute,
      recallWeight: recallWeight
    });
  });
  posts.forEach((post: AggregateSearchPost, index: number) => {
    const coverUrl = waterfallPostCoverUrl(post);
    const mediaUrl = waterfallPostVideoUrl(post);
    const isVideo = mediaUrl.length > 0 || playableVideoPageUrl(post.url);
    const mediaType = isVideo ? 'video' : (coverUrl.length > 0 ? 'image_text' : 'post');
    const parsedScore = Number(post.score.trim());
    const format: WaterfallFormat = mediaType === 'video' ? 'landscape_video' :
      (mediaType === 'image_text' ? 'image_text' : 'text');
    const metrics = postMetrics(post);
    const comments = (post.comments ?? commentsFromRows(post.rows)).slice(0, 5);
    candidates.push({
      id: post.id,
      source: post.source,
      provider: post.provider,
      mediaType: mediaType,
      title: waterfallTitle(post.title),
      summary: post.text,
      url: post.url,
      coverUrl: coverUrl,
      mediaUrl: mediaUrl,
      feedUrl: post.feedUrl,
      providerItemId: postProviderId(post) || undefined,
      comments: comments.length > 0 ? comments : undefined,
      commentLoadState: comments.length > 0 ? 'ready' : (post.source === 'zhihu' ? 'empty' : undefined),
      publishedAt: post.publishedAt,
      originalIndex: batchIndex * 1000 + videos.length + index,
      searchQuery: searchQuery,
      queryStage: queryStage,
      sourceRank: nextSourceRank(post.source),
      providerScore: post.score.trim().length > 0 && Number.isFinite(parsedScore) ? parsedScore : undefined,
      authorName: post.author || aggregateRowText(post.rows, ['Author', 'authorName']) || undefined,
      authorAvatarUrl: aggregateAvatar(post.rows) || undefined,
      metrics: metrics.length > 0 ? metrics : undefined,
      topics: topicsFor(post.title, post.text),
      format: format,
      recallRoute: recallRoute,
      recallWeight: recallWeight
    });
  });
  return candidates;
}

export interface AggregateZhihuConfig {
  apiKey: string;
}

export interface AggregateExternalProviderConfig {
  doubanPlaywright: DoubanPlaywrightMcpConfig;
  twitch: TwitchSearchConfig;
  globalNews: GlobalNewsConfig;
}

interface AggregateHttpResult {
  code: number;
  text: string;
}

const DEFAULT_AGGREGATE_SEARCH_POLICY: AggregateSearchPolicy = {
  domesticOnly: true,
  multilingual: false
};
export const AGGREGATE_SEARCH_PARTIAL_THROTTLE_MS: number = 5000;
let runtimeEnabledSources: AggregateSearchSource[] = aggregateSearchRegistrySourceIds();
let runtimeExternalProviderConfig: AggregateExternalProviderConfig = {
  doubanPlaywright: { mcpUrl: '', bearerToken: '' },
  twitch: { clientId: '', clientSecret: '' },
  globalNews: { guardianApiKey: '', newsApiKey: '' }
};
let runtimePreferenceProfile: WaterfallPreferenceSnapshot | undefined = undefined;
let runtimeSearchPolicy: AggregateSearchPolicy = {
  domesticOnly: DEFAULT_AGGREGATE_SEARCH_POLICY.domesticOnly,
  multilingual: DEFAULT_AGGREGATE_SEARCH_POLICY.multilingual
};
const X_PUBLIC_SEARCH_MARKER: string = 'X 公开 post 搜索关键词:';
const ZHIHU_SEARCH_URL: string = 'https://developer.zhihu.com/api/v1/content/zhihu_search';
const ZHIHU_HOT_LIST_URL: string = 'https://developer.zhihu.com/api/v1/content/hot_list';

function textOf(value: AggregateArgValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function errorText(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  if (error === undefined || error === null) {
    return '';
  }
  return JSON.stringify(error);
}

export function aggregateXPostSearchPrompt(query: string): string {
  return X_PUBLIC_SEARCH_MARKER + ' ' + query.trim();
}

function cleanAggregateSearchQuery(value: string): string {
  const original = value.trim();
  let query = original;
  ['有关', '关于'].forEach((marker: string) => {
    const start = query.indexOf(marker);
    if (start >= 0 && start + marker.length < query.length) {
      query = query.substring(start + marker.length).trim();
    }
  });
  ['我想看看', '我想看', '帮我看看', '帮我看', '帮我搜索', '帮我搜', '帮我查询', '帮我查',
    '聚合搜索', '搜索', '查询', '看看', '聚合', '汇总', '整理', '了解', '搜', '查'].forEach((prefix: string) => {
    if (query.indexOf(prefix) === 0 && query.length > prefix.length) {
      query = query.substring(prefix.length).trim();
    }
  });
  const tailMarkers: string[] = ['的相关新闻和讨论', '相关新闻和讨论', '的新闻和讨论', '新闻和讨论', '的相关新闻讨论', '相关新闻讨论',
    '新闻讨论', '的相关新闻', '相关新闻', '的相关讨论', '相关讨论', '的新闻', '新闻',
    '的讨论', '讨论', '热议', '观点', '帖子', 'po文', '公开动态',
    '，知乎也看', '，Reddit也看', '，reddit也看'];
  let trimmedTail = true;
  while (trimmedTail) {
    trimmedTail = false;
    for (let index = 0; index < tailMarkers.length; index++) {
      const tail = tailMarkers[index];
      if (query.length > tail.length && query.substring(query.length - tail.length) === tail) {
        query = query.substring(0, query.length - tail.length).trim();
        trimmedTail = true;
      }
    }
  }
  return query.length > 0 ? query : original;
}

export function aggregateSearchQueryFromArgs(prompt: string, args: Object | null): string {
  if (args !== null) {
    const query = cleanAggregateSearchQuery(textOf((args as AggregateArgRecord).query));
    if (query.length > 0) {
      return query;
    }
  }
  return cleanAggregateSearchQuery(prompt);
}

function booleanArg(value: AggregateArgValue, fallback: boolean): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  const normalized = textOf(value).trim().toLowerCase();
  if (normalized === 'true') {
    return true;
  }
  if (normalized === 'false') {
    return false;
  }
  return fallback;
}

export function defaultAggregateSearchPolicy(): AggregateSearchPolicy {
  return {
    domesticOnly: DEFAULT_AGGREGATE_SEARCH_POLICY.domesticOnly,
    multilingual: DEFAULT_AGGREGATE_SEARCH_POLICY.multilingual
  };
}

export function aggregateSearchPolicyFromArgs(args: Object | null): AggregateSearchPolicy {
  if (args === null) {
    return defaultAggregateSearchPolicy();
  }
  const record = args as AggregateArgRecord;
  return {
    domesticOnly: booleanArg(record.onlyDomesticSources,
      booleanArg(record.domesticOnly, DEFAULT_AGGREGATE_SEARCH_POLICY.domesticOnly)),
    multilingual: booleanArg(record.includeMultilingualResults,
      booleanArg(record.multilingual, DEFAULT_AGGREGATE_SEARCH_POLICY.multilingual))
  };
}

function aggregateSearchArgsContainPolicy(args: Object | null): boolean {
  if (args === null) {
    return false;
  }
  const record = args as AggregateArgRecord;
  return record.onlyDomesticSources !== undefined || record.domesticOnly !== undefined ||
    record.includeMultilingualResults !== undefined || record.multilingual !== undefined;
}

function aggregateSearchPolicyForCall(args: Object | null): AggregateSearchPolicy {
  return aggregateSearchArgsContainPolicy(args) ? aggregateSearchPolicyFromArgs(args) : waterfallSearchPolicyForRuntime();
}

export function aggregateSearchSourceMetadata(): AggregateSearchSourceMetadata[] {
  return aggregateSearchRegistryMetadata();
}

function metadataForSource(source: AggregateSearchSource): AggregateSearchSourceMetadata {
  return aggregateSearchRegistryMetadataFor(source);
}

function sourceAllowedByPolicy(source: AggregateSearchSource, policy: AggregateSearchPolicy): boolean {
  const metadata = metadataForSource(source);
  if (policy.domesticOnly && metadata.isExternal) {
    return false;
  }
  if (policy.multilingual || !metadata.isExternal) {
    return true;
  }
  return (metadata.languageFilterMode === 'native' || metadata.languageFilterMode === 'regional' ||
    metadata.languageFilterMode === 'post_filter') &&
    (metadata.languages.indexOf('zh-Hans') >= 0 || metadata.languages.indexOf('zh-Hant') >= 0);
}

export function waterfallInterestSourceAllowedForRuntime(source: string): boolean {
  const candidate = source as AggregateSearchSource;
  return aggregateSearchSourceIdsForContext('interest').indexOf(candidate) >= 0 &&
    runtimeEnabledSources.indexOf(candidate) >= 0 && sourceAllowedByPolicy(candidate, runtimeSearchPolicy);
}

export function configureAggregateExternalProvidersForRuntime(config: AggregateExternalProviderConfig): void {
  runtimeExternalProviderConfig = {
    doubanPlaywright: {
      mcpUrl: config.doubanPlaywright.mcpUrl.trim(),
      bearerToken: config.doubanPlaywright.bearerToken.trim()
    },
    twitch: {
      clientId: config.twitch.clientId.trim(),
      clientSecret: config.twitch.clientSecret.trim()
    },
    globalNews: {
      guardianApiKey: config.globalNews.guardianApiKey.trim(),
      newsApiKey: config.globalNews.newsApiKey.trim()
    }
  };
}

function normalizedAggregateSource(value: string): AggregateSearchSource | null {
  let normalized = value.trim().toLowerCase();
  if (normalized === 'hn' || normalized === 'hacknews' || normalized === 'hacker news') {
    normalized = 'hackernews';
  }
  if (normalized === 'b站' || normalized === 'b 站') {
    normalized = 'bilibili';
  }
  if (normalized === '知乎') {
    normalized = 'zhihu';
  }
  if (normalized === '红迪') {
    normalized = 'reddit';
  }
  return aggregateSearchSearchSourceIds().indexOf(normalized as AggregateSearchSource) >= 0 ?
    normalized as AggregateSearchSource : null;
}

export function aggregateSearchSourcesFromArgs(
  args: Object | null,
  policy: AggregateSearchPolicy = aggregateSearchPolicyFromArgs(args)
): AggregateSearchSource[] {
  const raw = args === null ? undefined : (args as AggregateArgRecord).sources;
  const explicitSources: AggregateSearchSource[] = [];
  if (Array.isArray(raw)) {
    (raw as AggregateArgValue[]).forEach((item: AggregateArgValue) => {
      const source = normalizedAggregateSource(textOf(item));
      if (source !== null && explicitSources.indexOf(source) < 0) {
        explicitSources.push(source);
      }
    });
  }
  const candidates: AggregateSearchSource[] = !Array.isArray(raw) || explicitSources.length === 0 ?
    aggregateSearchSearchSourceIds() : explicitSources;
  const sources: AggregateSearchSource[] = [];
  candidates.forEach((source: AggregateSearchSource) => {
    if (sourceAllowedByPolicy(source, policy)) {
      sources.push(source);
    }
  });
  return sources;
}

export function aggregateYouTubeRelevanceLanguage(policy: AggregateSearchPolicy): string {
  // Multilingual mode intentionally leaves YouTube unconstrained; relevanceLanguage is a preference, not a hard filter.
  return policy.multilingual ? '' : 'zh-Hans';
}

export function aggregateXSearchQuery(query: string, policy: AggregateSearchPolicy): string {
  const languageQuery = policy.multilingual ?
    '(lang:zh-CN OR lang:zh-TW OR lang:en)' :
    '(lang:zh-CN OR lang:zh-TW)';
  return query.trim() + ' ' + languageQuery;
}

export function configureWaterfallEnabledSourcesForRuntime(sources: AggregateSearchSource[]): void {
  runtimeEnabledSources = [];
  sources.forEach((source: AggregateSearchSource): void => {
    if (aggregateSearchRegistrySourceIds().indexOf(source) >= 0 && runtimeEnabledSources.indexOf(source) < 0) {
      runtimeEnabledSources.push(source);
    }
  });
}

export function configureWaterfallSearchPolicyForRuntime(policy: AggregateSearchPolicy): void {
  runtimeSearchPolicy = {
    domesticOnly: policy.domesticOnly,
    multilingual: policy.multilingual
  };
}

export function waterfallSearchPolicyForRuntime(): AggregateSearchPolicy {
  return {
    domesticOnly: runtimeSearchPolicy.domesticOnly,
    multilingual: runtimeSearchPolicy.multilingual
  };
}

export function configureWaterfallPreferenceProfileForRuntime(
  profile: WaterfallPreferenceSnapshot | undefined
): void {
  runtimePreferenceProfile = profile;
}

export function unsupportedSourceStatus(source: AggregateSearchSource, message: string): AggregateSearchSourceStatus {
  return {
    source: source,
    label: aggregateSourceLabel(source),
    status: 'unsupported',
    message: message,
    count: 0
  };
}

function dedupeVideos(videos: AggregateSearchVideo[]): AggregateSearchVideo[] {
  const seen: string[] = [];
  const kept: AggregateSearchVideo[] = [];
  videos.forEach((video: AggregateSearchVideo) => {
    const key = video.url.length > 0 ? video.url : video.id;
    if (seen.indexOf(key) < 0) {
      seen.push(key);
      kept.push(video);
    }
  });
  return kept;
}

function dedupePosts(posts: AggregateSearchPost[]): AggregateSearchPost[] {
  const seen: string[] = [];
  const kept: AggregateSearchPost[] = [];
  posts.forEach((post: AggregateSearchPost) => {
    const key = post.url.length > 0 ? post.url : post.id;
    if (seen.indexOf(key) < 0) {
      seen.push(key);
      kept.push(post);
    }
  });
  return kept;
}

export function aggregateSearchResultFromParts(
  query: string,
  videos: AggregateSearchVideo[],
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[]
): AggregateSearchResult {
  const keptVideos = dedupeVideos(videos);
  const keptPosts = dedupePosts(posts);
  return {
    query: query,
    videos: keptVideos,
    posts: keptPosts,
    sourceStatuses: statuses,
    summary: keptVideos.length.toString() + ' video' + (keptVideos.length === 1 ? '' : 's') +
      ', ' + keptPosts.length.toString() + ' discussion' + (keptPosts.length === 1 ? '' : 's')
  };
}

function rowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

export function normalizeAggregateSearchStatus(status: string, count: number): AggregateSearchStatus {
  if (status === 'empty') {
    return 'empty';
  }
  if (status === 'success' || status === 'connected') {
    return count > 0 ? 'success' : 'empty';
  }
  if (status === 'needs_auth' || status === 'auth_required') {
    return 'needs_auth';
  }
  if (status === 'unsupported') {
    return 'unsupported';
  }
  return 'error';
}

function statusFor(source: AggregateSearchSource, status: string, message: string, count: number): AggregateSearchSourceStatus {
  return {
    source: source,
    label: aggregateSourceLabel(source),
    status: normalizeAggregateSearchStatus(status, count),
    message: message,
    count: count
  };
}

function dynamicSource(result: DynamicGenericToolResult): AggregateSearchSource {
  return result.sourceTag === 'YouTube Data API' || result.sourceTag === 'Composio YouTube' ? 'youtube' : 'bilibili';
}

function dynamicVideoUrl(result: DynamicGenericToolResult): string {
  const watchUrl = rowValue(result, 'Watch URL');
  if (watchUrl.length > 0) {
    return watchUrl;
  }
  const playbackUrl = rowValue(result, 'Playback URL');
  if (playbackUrl.length > 0) {
    return playbackUrl;
  }
  return rowValue(result, 'Share URL');
}

function videoFromDynamic(source: AggregateSearchSource, result: DynamicGenericToolResult, index: number): AggregateSearchVideo {
  const providerId = rowValue(result, source === 'youtube' ? 'Video ID' : 'BVID');
  const thumbnail = source === 'youtube' && /^[A-Za-z0-9_-]{11}$/.test(providerId) ?
    'https://wsrv.nl/?url=i.ytimg.com/vi/' + providerId + '/mqdefault.jpg' : rowValue(result, 'Thumbnail');
  return {
    id: source + '-' + (providerId.length > 0 ? providerId : index.toString()),
    source: source,
    provider: result.sourceTag,
    title: result.title,
    summary: result.summary,
    url: dynamicVideoUrl(result),
    thumbnail: thumbnail,
    publishedAt: rowValue(result, 'Published'),
    duration: rowValue(result, 'Duration'),
    status: result.status === 'success' ? 'success' : 'error',
    rows: result.rows.slice()
  };
}

function urlFromText(value: string): string {
  const urlStart = value.indexOf('http');
  return urlStart >= 0 ? value.substring(urlStart).split(' ')[0].trim() : '';
}

function imageUrlsFromText(value: string): string[] {
  const matches = value.match(/https?:\/\/[^\s,，"'\]}]+/g);
  if (matches === null) {
    return [];
  }
  const urls: string[] = [];
  matches.forEach((raw: string) => appendImageUrl(urls, raw));
  return urls;
}

function plainPostText(value: string): string {
  return value
    .replace(/<br\s*\/?>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .trim();
}

function parsedDynamicPostRecord(value: string): DynamicPostRecord | null {
  try {
    const parsed = JSON.parse(value) as Object;
    if (parsed === null || Array.isArray(parsed) || typeof parsed !== 'object') {
      return null;
    }
    return parsed as DynamicPostRecord;
  } catch (_error) {
    return null;
  }
}

function dynamicPostRecord(value: string): DynamicPostRecord | null {
  const record = parsedDynamicPostRecord(value);
  if (record === null) {
    return null;
  }
  const data = record.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return data as DynamicPostRecord;
  }
  return record;
}

function recordText(record: DynamicPostRecord, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = textOf(record[names[index]]).trim();
    if (value.length > 0) {
      return value;
    }
  }
  return '';
}

function nestedRecordText(record: DynamicPostRecord, key: string, names: string[]): string {
  const value = record[key];
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  return recordText(value as DynamicPostRecord, names);
}

function dynamicPostText(value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const text = recordText(record, ['full_text', 'selftext', 'text', 'messageText', 'body', 'content', 'excerpt', 'summary', 'description', 'title', 'question']);
    if (text.length > 0) {
      return plainPostText(text);
    }
  }
  return plainPostText(value);
}

function dynamicPostTitle(label: string, value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const title = recordText(record, ['title', 'question', 'name']);
    if (title.length > 0) {
      return plainPostText(title);
    }
    const user = nestedRecordText(record, 'user', ['screen_name', 'name']);
    if (user.length > 0) {
      return user;
    }
  }
  return label;
}

function dynamicPostAuthor(value: string): string {
  const record = dynamicPostRecord(value);
  if (record === null) {
    return '';
  }
  const author = nestedRecordText(record, 'author', ['name', 'headline']);
  if (author.length > 0) {
    return author;
  }
  const user = nestedRecordText(record, 'user', ['screen_name', 'name']);
  return user.length > 0 ? user : recordText(record, ['author', 'screen_name', 'user_name']);
}

function dynamicPostUrl(value: string): string {
  const record = dynamicPostRecord(value);
  if (record !== null) {
    const direct = recordText(record, ['url', 'html_url', 'link', 'share_url', 'permalink', 'url_overridden_by_dest']);
    if (direct.length > 0) {
      return direct.charAt(0) === '/' ? 'https://www.reddit.com' + direct : direct;
    }
  }
  return urlFromText(value);
}

function imageUrlsFromDynamicPost(value: string): string[] {
  const urls = imageUrlsFromText(value);
  const record = dynamicPostRecord(value);
  if (record === null) {
    return urls;
  }
  ['thumbnail_pic', 'bmiddle_pic', 'original_pic', 'image_url', 'cover', 'thumbnail',
    'url_overridden_by_dest', 'preview_image_url'].forEach((key: string) => {
    appendImageUrl(urls, textOf(record[key]));
  });
  const preview = dynamicRecord(record.preview);
  const previewImages = preview === null ? null : preview.images;
  if (Array.isArray(previewImages)) {
    previewImages.forEach((item: DynamicPostValue) => {
      const image = dynamicRecord(item);
      const source = image === null ? null : dynamicRecord(image.source);
      if (source !== null) {
        appendImageUrl(urls, textOf(source.url));
      }
    });
  }
  const metadata = dynamicRecord(record.media_metadata);
  if (metadata !== null) {
    Object.keys(metadata).forEach((key: string) => {
      const sized = dynamicRecord(metadata[key]);
      const source = sized === null ? null : dynamicRecord(sized.s);
      if (source !== null) {
        appendImageUrl(urls, textOf(source.u));
      }
    });
  }
  const pics = record.pics;
  if (Array.isArray(pics)) {
    pics.forEach((item: DynamicPostValue) => {
      if (item === null || item === undefined) {
        return;
      }
      if (typeof item === 'string') {
        appendImageUrl(urls, item);
        return;
      }
      if (typeof item === 'object') {
        appendImageUrl(urls, recordText(item as DynamicPostRecord,
          ['url', 'large_url', 'thumbnail_pic', 'bmiddle_pic', 'original_pic']));
      }
    });
  }
  return urls;
}

function dynamicRecord(value: DynamicPostValue): DynamicPostRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const record = value as DynamicPostRecord;
  const data = record.data;
  return data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data) ?
    data as DynamicPostRecord : record;
}

function directVideoUrl(value: DynamicPostValue, depth: number = 0): string {
  if (depth > 5 || value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    const clean = value.trim();
    const lower = clean.toLowerCase();
    return clean.startsWith('http') && (lower.indexOf('.mp4') >= 0 || lower.indexOf('.m3u8') >= 0 ||
      lower.indexOf('v.redd.it/') >= 0) ? clean : '';
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      const found = directVideoUrl(value[index], depth + 1);
      if (found.length > 0) {
        return found;
      }
    }
    return '';
  }
  if (typeof value !== 'object') {
    return '';
  }
  const record = value as DynamicPostRecord;
  const preferred = ['fallback_url', 'video_url', 'videoUrl', 'playback_url', 'playbackUrl', 'content_url', 'url'];
  for (let index = 0; index < preferred.length; index++) {
    const found = directVideoUrl(record[preferred[index]], depth + 1);
    if (found.length > 0) {
      return found;
    }
  }
  const nested = ['media', 'secure_media', 'reddit_video', 'video', 'variants', 'attachments', 'includes'];
  for (let index = 0; index < nested.length; index++) {
    const found = directVideoUrl(record[nested[index]], depth + 1);
    if (found.length > 0) {
      return found;
    }
  }
  return '';
}

function appendCommentTexts(value: DynamicPostValue, comments: string[], depth: number = 0): void {
  if (comments.length >= 5 || depth > 5 || value === undefined || value === null) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((item: DynamicPostValue): void => appendCommentTexts(item, comments, depth + 1));
    return;
  }
  const record = dynamicRecord(value);
  if (record === null) {
    return;
  }
  const comment = plainPostText(recordText(record, ['body', 'text', 'messageText', 'comment', 'content']));
  if (comment.length > 0 && comment !== '[deleted]' && comment !== '[removed]' && comments.indexOf(comment) < 0) {
    comments.push(comment);
  }
  ['data', 'items', 'comments', 'replies', 'children'].forEach((key: string): void => appendCommentTexts(record[key], comments, depth + 1));
}

function commentsFromDynamicPost(value: string): string[] {
  const record = dynamicPostRecord(value);
  const comments: string[] = [];
  if (record !== null) {
    ['comments', 'replies', 'top_comments'].forEach((key: string): void => appendCommentTexts(record[key], comments));
  }
  return comments;
}

function dynamicPostPublishedAt(value: string): string {
  const record = dynamicPostRecord(value);
  return record === null ? '' : recordText(record, ['created_at', 'created_utc', 'published_at', 'updated_at', 'time', 'date']);
}

function dynamicPostScore(value: string): string {
  const record = dynamicPostRecord(value);
  return record === null ? '' : recordText(record, ['points', 'score', 'ups', 'attitudes_count', 'voteup_count', 'likes']);
}

function dynamicPostCommentCount(value: string): string {
  const record = dynamicPostRecord(value);
  if (record === null) {
    return '';
  }
  const direct = recordText(record, ['num_comments', 'commentCount', 'comments_count', 'answer_count']);
  if (direct.length > 0) {
    return direct;
  }
  const metrics = dynamicRecord(record.public_metrics);
  return metrics === null ? '' : recordText(metrics, ['reply_count']);
}

function postFromDynamicRow(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult,
  rowIndex: number
): AggregateSearchPost {
  const row = result.rows[rowIndex];
  const url = dynamicPostUrl(row.value);
  const rows = [row];
  const images = imageUrlsFromDynamicPost(row.value);
  if (images.length > 0) {
    rows.push({ label: 'images', value: images.join(' ') });
  }
  const videoUrl = directVideoUrl(dynamicPostRecord(row.value));
  if (videoUrl.length > 0) {
    rows.push({ label: 'video', value: videoUrl });
  }
  commentsFromDynamicPost(row.value).forEach((comment: string): void => {
    rows.push({ label: 'comment', value: comment });
  });
  const text = dynamicPostText(row.value);
  return {
    id: source + '-' + rowIndex.toString(),
    source: source,
    provider: provider,
    title: dynamicPostTitle(row.label, row.value),
    author: dynamicPostAuthor(row.value),
    handle: '',
    text: text.length > 0 ? text : row.value,
    url: url,
    publishedAt: dynamicPostPublishedAt(row.value),
    score: dynamicPostScore(row.value),
    commentCount: dynamicPostCommentCount(row.value),
    status: result.status === 'success' ? 'success' : 'error',
    rows: rows
  };
}

function objectArrayFrom(value: DynamicPostValue): Object[] {
  const items: Object[] = [];
  if (!Array.isArray(value)) {
    return items;
  }
  value.forEach((item: DynamicPostValue) => {
    if (item !== undefined && item !== null && typeof item === 'object') {
      items.push(item as Object);
    }
  });
  return items;
}

function looksLikeDynamicPostObject(item: Object): boolean {
  const record = item as DynamicPostRecord;
  if (recordText(record, ['title', 'name', 'full_text', 'selftext', 'text', 'messageText', 'body', 'content', 'excerpt', 'summary', 'description', 'question']).length > 0) {
    return true;
  }
  const data = record.data;
  return data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data) &&
    recordText(data as DynamicPostRecord, ['title', 'name', 'full_text', 'selftext', 'text', 'body', 'content', 'excerpt', 'summary', 'description', 'question']).length > 0;
}

function firstObjectArray(value: DynamicPostValue): Object[] {
  if (Array.isArray(value)) {
    const direct = objectArrayFrom(value);
    const flattened: Object[] = [];
    let replaced = false;
    direct.forEach((item: Object) => {
      if (looksLikeDynamicPostObject(item)) {
        flattened.push(item);
        return;
      }
      const nested = firstObjectArray(item);
      if (nested.length > 0) {
        replaced = true;
        nested.forEach((nestedItem: Object) => flattened.push(nestedItem));
        return;
      }
      flattened.push(item);
    });
    return replaced ? flattened : direct;
  }
  if (typeof value === 'string') {
    const clean = value.trim();
    if (clean.charAt(0) !== '{' && clean.charAt(0) !== '[') {
      return [];
    }
    try {
      return firstObjectArray(JSON.parse(clean) as DynamicPostValue);
    } catch (_error) {
      return [];
    }
  }
  if (value === undefined || value === null || typeof value !== 'object') {
    return [];
  }
  const record = value as DynamicPostRecord;
  const preferred = ['hits', 'posts', 'items', 'results', 'data', 'children', 'preview'];
  for (let index = 0; index < preferred.length; index++) {
    const items = firstObjectArray(record[preferred[index]]);
    if (items.length > 0) {
      return items;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const items = firstObjectArray(record[keys[index]]);
    if (items.length > 0) {
      return items;
    }
  }
  return [];
}

function postFromDynamicObject(source: AggregateSearchSource, provider: string, item: Object, index: number): AggregateSearchPost {
  const value = JSON.stringify(item);
  const row: AggregateSearchRowData = {
    label: dynamicPostTitle('result ' + (index + 1).toString(), value),
    value: value
  };
  const result: DynamicGenericToolResult = {
    sourceTag: provider,
    toolName: source,
    title: provider,
    status: 'success',
    summary: '',
    rows: [row],
    rawPreview: value
  };
  const post = postFromDynamicRow(source, provider, result, 0);
  post.id = source + '-' + index.toString();
  return post;
}

function postsFromDynamicRawPreview(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult
): AggregateSearchPost[] {
  try {
    const items = firstObjectArray(JSON.parse(result.rawPreview) as DynamicPostValue);
    return items.slice(0, 10).map((item: Object, index: number) => postFromDynamicObject(source, provider, item, index));
  } catch (_error) {
    return [];
  }
}

function shouldKeepDynamicRow(label: string): boolean {
  return label !== '执行工具' &&
    label !== '查询' &&
    label !== '结果数量' &&
    label !== '结果摘要' &&
    label !== '授权 Toolkit' &&
    label !== '阶段' &&
    label !== 'source' &&
    label !== 'truncated' &&
    label !== 'preview';
}

function postsFromDynamicResult(
  source: AggregateSearchSource,
  provider: string,
  result: DynamicGenericToolResult
): AggregateSearchPost[] {
  if (result.status !== 'success') {
    return [];
  }
  const rawPosts = postsFromDynamicRawPreview(source, provider, result);
  if (rawPosts.length > 0) {
    return rawPosts;
  }
  const posts: AggregateSearchPost[] = [];
  for (let rowIndex = 0; rowIndex < result.rows.length; rowIndex++) {
    if (!shouldKeepDynamicRow(result.rows[rowIndex].label)) {
      continue;
    }
    posts.push(postFromDynamicRow(source, provider, result, rowIndex));
  }
  if (posts.length === 0 && result.summary.length > 0) {
    const fallbackResult: DynamicGenericToolResult = {
      sourceTag: result.sourceTag,
      toolName: result.toolName,
      title: result.title,
      status: result.status,
      summary: result.summary,
      rows: [{ label: result.title, value: result.summary }],
      rawPreview: result.rawPreview
    };
    posts.push(postFromDynamicRow(source, provider, fallbackResult, 0));
  }
  return posts;
}

export function hackerNewsPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  return postsFromDynamicResult('hackernews', 'Hacker News', result);
}

export function redditPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  return postsFromDynamicResult('reddit', 'Reddit', result);
}

export function xPostsFromComposioResult(result: DynamicGenericToolResult): AggregateSearchPost[] {
  const posts = postsFromDynamicResult('x', 'X', result);
  appendXMediaRows(posts, xMediaRecords(result.rawPreview));
  appendXAuthorRows(posts, xIncludedRecords(result.rawPreview, 'users'));
  return posts;
}

function xIncludedRecords(value: DynamicPostValue, key: string): Object[] {
  if (typeof value === 'string') {
    try {
      return xIncludedRecords(JSON.parse(value) as DynamicPostValue, key);
    } catch (_error) {
      return [];
    }
  }
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return [];
  }
  const record = value as DynamicPostRecord;
  const includes = dynamicRecord(record.includes);
  if (includes !== null && Array.isArray(includes[key])) {
    return objectArrayFrom(includes[key]);
  }
  const preview = record.preview;
  if (preview !== undefined) {
    const nested = xIncludedRecords(preview, key);
    if (nested.length > 0) {
      return nested;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const nested = xIncludedRecords(record[keys[index]], key);
    if (nested.length > 0) {
      return nested;
    }
  }
  return [];
}

function xMediaRecords(value: DynamicPostValue): Object[] {
  return xIncludedRecords(value, 'media');
}

function stringValues(value: DynamicPostValue): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const values: string[] = [];
  value.forEach((item: DynamicPostValue): void => {
    const text = textOf(item).trim();
    if (text.length > 0) {
      values.push(text);
    }
  });
  return values;
}

function appendXMediaRows(posts: AggregateSearchPost[], media: Object[]): void {
  posts.forEach((post: AggregateSearchPost): void => {
    const record = post.rows.length > 0 ? dynamicPostRecord(post.rows[0].value) : null;
    const attachments = record === null ? null : dynamicRecord(record.attachments);
    const keys = attachments === null ? [] : stringValues(attachments.media_keys);
    for (let mediaIndex = 0; mediaIndex < media.length; mediaIndex++) {
      const mediaRecord = dynamicRecord(media[mediaIndex]);
      if (mediaRecord === null || keys.indexOf(recordText(mediaRecord, ['media_key', 'key'])) < 0) {
        continue;
      }
      const preview = recordText(mediaRecord, ['preview_image_url', 'url']);
      const video = directVideoUrl(mediaRecord);
      if (preview.length > 0) {
        post.rows.push({ label: 'images', value: preview });
      }
      if (video.length > 0) {
        post.rows.push({ label: 'video', value: video });
      }
      break;
    }
  });
}

function appendXAuthorRows(posts: AggregateSearchPost[], users: Object[]): void {
  posts.forEach((post: AggregateSearchPost): void => {
    const record = post.rows.length > 0 ? dynamicPostRecord(post.rows[0].value) : null;
    const authorId = record === null ? '' : recordText(record, ['author_id']);
    for (let index = 0; index < users.length; index++) {
      const user = dynamicRecord(users[index]);
      if (user === null || recordText(user, ['id']) !== authorId) continue;
      post.author = recordText(user, ['name', 'username']);
      post.handle = recordText(user, ['username']);
      const avatar = recordText(user, ['profile_image_url']);
      if (avatar.length > 0) post.rows.push({ label: 'authorAvatar', value: avatar });
      break;
    }
  });
}

function mediaMessage(source: AggregateSearchSource, count: number, results: DynamicGenericToolResult[]): string {
  if (count > 0) {
    return aggregateSourceLabel(source) + ' returned ' + count.toString() + ' rows.';
  }
  if (results.length > 0) {
    return results[0].summary;
  }
  return aggregateSourceLabel(source) + ' returned 0 rows.';
}

function statusFromComposioError(error: Error | Object | string | number | boolean | null | undefined): string {
  const message = errorText(error);
  if (message.indexOf('未配置') >= 0 || message.indexOf('授权') >= 0 ||
    message.indexOf('ACTIVE connected account') >= 0 || message.toLowerCase().indexOf('auth') >= 0) {
    return 'needs_auth';
  }
  return 'error';
}

async function appendComposioPosts(
  source: AggregateSearchSource,
  provider: string,
  prompt: string,
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[],
  fixedToolId: string = '',
  fixedArgs: Object | null = null
): Promise<DynamicGenericToolResult | null> {
  try {
    const result = fixedToolId.length > 0 ?
      await callComposioFixedDynamicWithProviderData(prompt, fixedToolId, fixedArgs) :
      await callComposioDynamicWithProviderData(prompt, null);
    if (result === null) {
      statuses.push(statusFor(source, 'error', 'Composio ' + provider + ' did not run.', 0));
      return null;
    }
    const nextPosts = postsFromDynamicResult(source, provider, result);
    nextPosts.forEach((post: AggregateSearchPost) => posts.push(post));
    statuses.push(statusFor(source, result.status, result.summary, nextPosts.length));
    return result;
  } catch (error) {
    statuses.push(statusFor(
      source,
      statusFromComposioError(error),
      'Composio ' + provider + ' failed: ' + errorText(error),
      0
    ));
    return null;
  }
}

function continuationText(value: DynamicPostValue, names: string[]): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    try {
      return continuationText(JSON.parse(value) as DynamicPostValue, names);
    } catch (_error) {
      return '';
    }
  }
  if (typeof value !== 'object' || Array.isArray(value)) {
    return '';
  }
  const record = value as DynamicPostRecord;
  for (let index = 0; index < names.length; index++) {
    const direct = textOf(record[names[index]]).trim();
    if (direct.length > 0) {
      return direct;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const nested = continuationText(record[keys[index]], names);
    if (nested.length > 0) {
      return nested;
    }
  }
  return '';
}

function continuationNumber(value: DynamicPostValue, names: string[]): number {
  const text = continuationText(value, names);
  const parsed = Number(text);
  return Number.isFinite(parsed) ? parsed : -1;
}

export function aggregateContinuationFromDynamicResult(
  source: AggregateSearchSource,
  result: DynamicGenericToolResult,
  previous: WaterfallContinuation | null
): WaterfallContinuation | null {
  let payload: DynamicPostValue = result.providerData as DynamicPostValue;
  try {
    if (payload === undefined) {
      payload = JSON.parse(result.rawPreview) as DynamicPostValue;
    }
  } catch (_error) {
    return null;
  }
  if (source === 'x') {
    const cursor = continuationText(payload, ['next_token', 'nextToken', 'next_cursor', 'nextCursor']);
    return cursor.length > 0 && (previous === null || cursor !== previous.value) ?
      { kind: 'cursor', value: cursor } : null;
  }
  if (source === 'reddit') {
    const cursor = continuationText(payload, ['after', 'next', 'next_cursor', 'nextCursor']);
    return cursor.length > 0 && (previous === null || cursor !== previous.value) ?
      { kind: 'cursor', value: cursor } : null;
  }
  if (source === 'hackernews') {
    const current = continuationNumber(payload, ['page']);
    const pages = continuationNumber(payload, ['nbPages', 'nb_pages', 'totalPages', 'total_pages']);
    const fallback = previous !== null && previous.kind === 'page' ? Number(previous.value) : -1;
    const page = current >= 0 ? current : fallback;
    return page >= 0 && pages > page + 1 ? { kind: 'page', value: (page + 1).toString() } : null;
  }
  return null;
}

function responseText(value: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(value));
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

export function zhihuSearchUrl(query: string, count: number = 10): string {
  return ZHIHU_SEARCH_URL + '?Query=' + encodeURIComponent(query) + '&Count=' + encodeURIComponent(count.toString());
}

export function zhihuHotListUrl(limit: number = 10): string {
  const bounded = Math.max(1, Math.min(30, Math.floor(limit)));
  return ZHIHU_HOT_LIST_URL + '?Limit=' + encodeURIComponent(bounded.toString());
}

function zhihuTimestamp(): string {
  return Math.floor(Date.now() / 1000).toString();
}

async function requestZhihuSearch(query: string, apiKey: string): Promise<AggregateHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(zhihuSearchUrl(query, 10), {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ' + apiKey.trim(),
        'X-Request-Timestamp': zhihuTimestamp(),
        'Content-Type': 'application/json'
      },
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    return {
      code: response.responseCode,
      text: responseText(response.result)
    };
  } finally {
    request.destroy();
  }
}

async function requestZhihuHotList(limit: number, apiKey: string): Promise<AggregateHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(zhihuHotListUrl(limit), {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json',
        'Authorization': 'Bearer ' + apiKey.trim(),
        'X-Request-Timestamp': zhihuTimestamp(),
        'Content-Type': 'application/json'
      },
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 30000
    });
    return {
      code: response.responseCode,
      text: responseText(response.result)
    };
  } finally {
    request.destroy();
  }
}

function zhihuDataRecord(payload: DynamicPostRecord): DynamicPostRecord {
  const data = payload.Data ?? payload.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return data as DynamicPostRecord;
  }
  return payload;
}

function zhihuItemsFromPayload(rawJson: string): Object[] {
  const payload = JSON.parse(rawJson) as DynamicPostRecord;
  const code = textOf(payload.Code ?? payload.code).trim();
  if (code.length > 0 && code !== '0') {
    throw new Error(recordText(payload, ['Message', 'message', 'msg']) || 'Zhihu API returned Code=' + code);
  }
  const data = zhihuDataRecord(payload);
  const items = data.Items ?? data.items ?? data.Results ?? data.results ?? data.List ?? data.list;
  return Array.isArray(items) ? items as Object[] : [];
}

function zhihuTimeText(value: string): string {
  const stamp = Number(value);
  if (!Number.isFinite(stamp) || stamp <= 0) {
    return value;
  }
  return new Date(stamp * 1000).toISOString();
}

function zhihuPostFromItem(item: Object, index: number): AggregateSearchPost {
  const record = item as DynamicPostRecord;
  const title = plainPostText(recordText(record, ['Title', 'title']));
  const text = plainPostText(recordText(record, ['ContentText', 'contentText', 'content_text', 'Snippet', 'snippet', 'Summary', 'summary', 'Abstract', 'abstract', 'Description', 'description']));
  const url = recordText(record, ['Url', 'url', 'URI', 'uri', 'Link', 'link']);
  const author = recordText(record, ['AuthorName', 'authorName', 'author', 'Source', 'source', 'Site', 'site']);
  const score = recordText(record, ['VoteUpCount', 'voteUpCount', 'Score', 'score', 'Relevance', 'relevance']);
  const commentCount = recordText(record, ['CommentCount', 'commentCount', 'comments_count', 'num_comments']);
  const contentId = recordText(record, ['ContentID', 'contentID', 'id']);
  const rows: AggregateSearchRowData[] = [
    { label: 'author', value: author },
    { label: 'contentType', value: recordText(record, ['ContentType', 'contentType']) },
    { label: 'text', value: text },
    { label: 'url', value: url },
    { label: 'score', value: score },
    { label: 'comments', value: commentCount }
  ];
  if (contentId.length > 0) {
    rows.push({ label: 'Content ID', value: contentId });
  }
  const avatar = recordText(record, ['AuthorAvatar', 'authorAvatar', 'AuthorBadge', 'authorBadge']);
  if (avatar.length > 0) {
    rows.push({ label: 'authorAvatar', value: avatar });
  }
  return {
    id: 'zhihu-' + (contentId || index.toString()),
    source: 'zhihu',
    provider: '知乎',
    title: title.length > 0 ? title : '知乎内容',
    author: author,
    handle: '',
    text: text,
    url: url,
    publishedAt: zhihuTimeText(recordText(record, ['EditTime', 'editTime', 'created_at', 'published_at'])),
    score: score,
    commentCount: commentCount,
    status: 'success',
    rows: rows,
    comments: zhihuCommentsFromItem(record)
  };
}

function zhihuCommentsFromItem(record: DynamicPostRecord): WaterfallComment[] {
  const raw = record.CommentInfoList ?? record.commentInfoList ?? record.comments;
  if (!Array.isArray(raw)) return [];
  const comments: WaterfallComment[] = [];
  raw.forEach((value: DynamicPostValue): void => {
    if (comments.length >= 5) return;
    const item = dynamicRecord(value);
    if (item === null) return;
    const content = plainPostText(recordText(item, ['Content', 'content', 'Text', 'text']));
    if (content.length === 0 || comments.some((comment: WaterfallComment): boolean => comment.text === content)) return;
    const likeCount = metricNumber(recordText(item, ['LikeCount', 'likeCount', 'VoteUpCount', 'voteUpCount']));
    const replyCount = metricNumber(recordText(item, ['ReplyCount', 'replyCount', 'ChildCommentCount']));
    comments.push({
      text: content,
      authorName: recordText(item, ['AuthorName', 'authorName', 'Author', 'author']) || undefined,
      authorAvatarUrl: recordText(item, ['AuthorAvatar', 'authorAvatar']) || undefined,
      publishedAt: zhihuTimeText(recordText(item, ['CreateTime', 'createTime', 'created_at'])) || undefined,
      likeCount: likeCount,
      replyCount: replyCount
    });
  });
  return comments;
}

export function zhihuPostsFromSearchPayload(rawJson: string): AggregateSearchPost[] {
  const posts: AggregateSearchPost[] = [];
  zhihuItemsFromPayload(rawJson).forEach((item: Object, index: number) => {
    const post = zhihuPostFromItem(item, index);
    if (post.title.length > 0 || post.text.length > 0 || post.url.length > 0) {
      posts.push(post);
    }
  });
  return posts;
}

export function zhihuPostsFromHotListPayload(rawJson: string): AggregateSearchPost[] {
  const posts: AggregateSearchPost[] = [];
  zhihuItemsFromPayload(rawJson).forEach((item: Object): void => {
    const record = item as DynamicPostRecord;
    const title = plainPostText(recordText(record, ['Title', 'title']));
    const url = recordText(record, ['Url', 'url']);
    const summary = plainPostText(recordText(record, ['Summary', 'summary']));
    const thumbnail = recordText(record, ['ThumbnailUrl', 'thumbnailUrl']);
    if (title.length === 0 && summary.length === 0 && url.length === 0) {
      return;
    }
    const contentId = recordText(record, ['ContentID', 'contentID', 'id']);
    const identity = contentId || url.split('#')[0] || title + '|' + summary;
    posts.push({
      id: 'zhihu-hot-' + encodeURIComponent(identity).slice(0, 512),
      source: 'zhihu',
      provider: '知乎',
      title: title.length > 0 ? title : '知乎热榜',
      author: '',
      handle: '',
      text: summary,
      url: url,
      publishedAt: '',
      score: '',
      commentCount: '',
      status: 'success',
      rows: [{ label: 'Cover', value: thumbnail }]
    });
  });
  return posts;
}

function statusFromZhihuError(error: Error | Object | string | number | boolean | null | undefined): string {
  const message = errorText(error);
  const lower = message.toLowerCase();
  if (message.indexOf('401') >= 0 || message.indexOf('403') >= 0 ||
    lower.indexOf('authorization') >= 0 || lower.indexOf('auth') >= 0 || message.indexOf('鉴权') >= 0) {
    return 'needs_auth';
  }
  return 'error';
}

async function appendZhihuPosts(
  config: AggregateZhihuConfig,
  query: string,
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[]
): Promise<void> {
  const apiKey = config.apiKey.trim();
  if (apiKey.length === 0) {
    statuses.push(statusFor('zhihu', 'needs_auth', '未配置 ZHIHU_API_KEY（知乎 Access Secret）。', 0));
    return;
  }
  try {
    const response = await requestZhihuSearch(query, apiKey);
    if (response.code < 200 || response.code >= 300) {
      throw new Error('HTTP ' + response.code.toString() + ': ' + response.text.substring(0, 240));
    }
    const nextPosts = zhihuPostsFromSearchPayload(response.text);
    nextPosts.forEach((post: AggregateSearchPost) => posts.push(post));
    statuses.push(statusFor('zhihu', nextPosts.length > 0 ? 'success' : 'empty', '知乎返回 ' + nextPosts.length.toString() + ' 条。', nextPosts.length));
  } catch (error) {
    statuses.push(statusFor('zhihu', statusFromZhihuError(error), '知乎 API 调用失败：' + errorText(error), 0));
  }
}

async function appendZhihuHotListPosts(
  config: AggregateZhihuConfig,
  limit: number,
  posts: AggregateSearchPost[],
  statuses: AggregateSearchSourceStatus[]
): Promise<void> {
  const apiKey = config.apiKey.trim();
  if (apiKey.length === 0) {
    statuses.push(statusFor('zhihu', 'needs_auth', '未配置 ZHIHU_API_KEY（知乎 Access Secret）。', 0));
    return;
  }
  try {
    const response = await requestZhihuHotList(limit, apiKey);
    if (response.code < 200 || response.code >= 300) {
      throw new Error('HTTP ' + response.code.toString() + ': ' + response.text.substring(0, 240));
    }
    const nextPosts = zhihuPostsFromHotListPayload(response.text);
    nextPosts.forEach((post: AggregateSearchPost): void => {
      posts.push(post);
    });
    statuses.push(statusFor('zhihu', nextPosts.length > 0 ? 'success' : 'empty',
      '知乎热榜返回 ' + nextPosts.length.toString() + ' 条。', nextPosts.length));
  } catch (error) {
    statuses.push(statusFor('zhihu', statusFromZhihuError(error), '知乎热榜 API 调用失败：' + errorText(error), 0));
  }
}

function emptyZhihuConfig(): AggregateZhihuConfig {
  return {
    apiKey: ''
  };
}

export type AggregateSearchPartialObserver = (result: AggregateSearchResult) => void;

class AggregateSearchPartialThrottle {
  private readonly intervalMs: number;
  private readonly observer: AggregateSearchPartialObserver;
  private leadingPublished: boolean = false;
  private timerId: number = -1;
  private pending: AggregateSearchResult | null = null;

  constructor(intervalMs: number, observer: AggregateSearchPartialObserver) {
    this.intervalMs = intervalMs > 0 ? intervalMs : 0;
    this.observer = observer;
  }

  publish(snapshot: AggregateSearchResult): void {
    if (snapshot.videos.length === 0 && snapshot.posts.length === 0) return;
    if (this.intervalMs === 0) {
      this.observer(snapshot);
      return;
    }
    if (!this.leadingPublished) {
      this.leadingPublished = true;
      this.observer(snapshot);
      return;
    }
    this.pending = snapshot;
    this.restartTimer();
  }

  finish(): void {
    this.leadingPublished = false;
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.pending = null;
  }

  private restartTimer(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
    }
    this.timerId = setTimeout((): void => {
      this.timerId = -1;
      const pending = this.pending;
      this.pending = null;
      if (pending === null) {
        return;
      }
      this.observer(pending);
    }, this.intervalMs);
  }
}

function waterfallPhaseFor(status: AggregateSearchStatus): WaterfallSourcePhase {
  if (status === 'success') {
    return 'success';
  }
  if (status === 'empty') {
    return 'empty';
  }
  if (status === 'needs_auth') {
    return 'needs_auth';
  }
  return 'error';
}

function sourceStateFor(batch: AggregateSearchSourceBatch): WaterfallSourceState {
  const phase = waterfallPhaseFor(batch.status.status);
  return {
    source: batch.source,
    phase: batch.continuation === null && (phase === 'success' || phase === 'empty') ? 'exhausted' : phase,
    continuation: batch.continuation,
    inFlight: false,
    reservedCount: 0,
    message: batch.status.message
  };
}

function loadingWaterfallState(
  query: string,
  sources: AggregateSearchSource[],
  preferenceDescription: string
): WaterfallFeedState {
  const sourceStates: WaterfallSourceState[] = sources.map((source: AggregateSearchSource): WaterfallSourceState => ({
    source: source,
    phase: 'loading',
    continuation: null,
    inFlight: false,
    reservedCount: 0,
    message: ''
  }));
  return {
    query: query,
    originalQuery: query,
    queryStage: 'original',
    queryHistory: [query],
    consecutiveEmptyRounds: 0,
    roundNewItemCount: 0,
    roundActive: true,
    expansionInFlight: false,
    enabledSources: sources.slice(),
    preferenceDescription: preferenceDescription,
    profile: runtimePreferenceProfile,
    shown: [],
    current: null,
    stable: [],
    tail: [],
    sources: sourceStates
  };
}

function orderedAggregateStatuses(sources: AggregateSearchSource[], statuses: AggregateSearchSourceStatus[]): AggregateSearchSourceStatus[] {
  const ordered: AggregateSearchSourceStatus[] = [];
  sources.forEach((source: AggregateSearchSource): void => {
    statuses.forEach((status: AggregateSearchSourceStatus): void => {
      if (status.source === source && ordered.indexOf(status) < 0) {
        ordered.push(status);
      }
    });
  });
  return ordered;
}

function replaceAggregateStatus(statuses: AggregateSearchSourceStatus[], next: AggregateSearchSourceStatus): void {
  for (let index = 0; index < statuses.length; index++) {
    if (statuses[index].source === next.source) {
      statuses[index] = next;
      return;
    }
  }
  statuses.push(next);
}

function failedAggregateBatch(source: AggregateSearchSource, error: Error | Object | string | number | boolean | null | undefined): AggregateSearchSourceBatch {
  return {
    source: source,
    videos: [],
    posts: [],
    status: statusFor(source, 'error', aggregateSourceLabel(source) + ' 调用失败：' + errorText(error), 0),
    continuation: null
  };
}

function exhaustedAggregateBatch(request: WaterfallLoadRequest): AggregateSearchSourceBatch {
  const source = request.source as AggregateSearchSource;
  const status = request.phase === 'needs_auth' ? 'needs_auth' : (request.phase === 'error' ? 'error' : 'empty');
  return {
    source: source,
    videos: [],
    posts: [],
    status: statusFor(source, status, request.message.length > 0 ? request.message :
      aggregateSourceLabel(source) + ' 已无原生下一页。', 0),
    continuation: null
  };
}

export async function streamAggregateSearchSourceBatches(
  query: string,
  requestedSources: AggregateSearchSource[],
  tasks: Promise<AggregateSearchSourceBatch>[],
  onPartial: AggregateSearchPartialObserver,
  nowMs: number,
  preferenceDescription: string = '',
  partialThrottleMs: number = AGGREGATE_SEARCH_PARTIAL_THROTTLE_MS
): Promise<AggregateSearchResult> {
  const videos: AggregateSearchVideo[] = [];
  const posts: AggregateSearchPost[] = [];
  const statuses: AggregateSearchSourceStatus[] = [];
  let waterfall = loadingWaterfallState(query, requestedSources, preferenceDescription);
  let batchIndex = 0;
  let partialChain: Promise<void> = Promise.resolve();
  const partialThrottle = new AggregateSearchPartialThrottle(partialThrottleMs, onPartial);
  const wrappedTasks: Promise<void>[] = [];
  for (let index = 0; index < tasks.length; index++) {
    const source = requestedSources[index];
    wrappedTasks.push(tasks[index].then((batch: AggregateSearchSourceBatch): Promise<void> => {
      partialChain = partialChain.then((): void => {
        batch.videos.forEach((video: AggregateSearchVideo): void => {
          videos.push(video);
        });
        batch.posts.forEach((post: AggregateSearchPost): void => {
          posts.push(post);
        });
        replaceAggregateStatus(statuses, batch.status);
        waterfall = mergeWaterfallBatchDeferredRanking(
          waterfall,
          aggregateMediaCandidates(
            batch.videos.slice(0, 10), batch.posts.slice(0, 10), batchIndex, query, 'original'
          ),
          sourceStateFor(batch)
        ).state;
        batchIndex += 1;
        const snapshot = aggregateSearchResultFromParts(query, videos, posts, orderedAggregateStatuses(requestedSources, statuses));
        snapshot.waterfall = waterfall;
        partialThrottle.publish(snapshot);
      });
      return partialChain;
    }).catch((error: Error | Object | string | number | boolean | null | undefined): Promise<void> => {
      const failed = failedAggregateBatch(source, error);
      partialChain = partialChain.then((): void => {
        replaceAggregateStatus(statuses, failed.status);
        waterfall = mergeWaterfallBatchDeferredRanking(waterfall, [], sourceStateFor(failed)).state;
        batchIndex += 1;
        const snapshot = aggregateSearchResultFromParts(query, videos, posts, orderedAggregateStatuses(requestedSources, statuses));
        snapshot.waterfall = waterfall;
        partialThrottle.publish(snapshot);
      });
      return partialChain;
    }));
  }
  try {
    await Promise.all(wrappedTasks);
    await partialChain;
  } finally {
    partialThrottle.finish();
  }
  waterfall = finalizeDeferredWaterfallRanking(waterfall, nowMs);
  const result = aggregateSearchResultFromParts(query, videos, posts, orderedAggregateStatuses(requestedSources, statuses));
  result.waterfall = waterfall;
  return result;
}

async function aggregateMediaSourceBatch(
  source: AggregateSearchSource,
  query: string,
  youtubeApiKey: string,
  continuation: WaterfallContinuation | null = null,
  limit: number = 10,
  policy: AggregateSearchPolicy = runtimeSearchPolicy
): Promise<AggregateSearchSourceBatch> {
  const mediaArgs: AggregateMediaSearchArgs = {
    query: query,
    sources: [source],
    limit: limit,
    language: source === 'youtube' ? aggregateYouTubeRelevanceLanguage(policy) : ''
  };
  if (source === 'youtube' && continuation !== null && continuation.kind === 'cursor') {
    mediaArgs.pageToken = continuation.value;
  }
  const currentPage = source === 'bilibili' && continuation !== null && continuation.kind === 'page' ?
    Math.max(1, Number(continuation.value)) : 1;
  if (source === 'bilibili') {
    mediaArgs.page = currentPage;
  }
  const mediaResults = await callMediaVideoSearch(query, mediaArgs as Object, youtubeApiKey);
  return aggregateVideoSourceBatchFromDynamicResults(source, mediaResults, continuation, limit);
}

export function aggregateVideoSourceBatchFromDynamicResults(
  source: AggregateSearchSource,
  mediaResults: DynamicGenericToolResult[],
  continuation: WaterfallContinuation | null = null,
  limit: number = 10
): AggregateSearchSourceBatch {
  const videos: AggregateSearchVideo[] = [];
  mediaResults.forEach((result: DynamicGenericToolResult, index: number): void => {
    if (result.status !== 'success' || dynamicSource(result) !== source || videos.length >= limit) {
      return;
    }
    const video = videoFromDynamic(source, result, index);
    if (video.url.length > 0) {
      videos.push(video);
    }
  });
  const matching = mediaResults.filter((result: DynamicGenericToolResult): boolean => dynamicSource(result) === source);
  const rawStatus = videos.length > 0 ? 'success' : (matching.length > 0 ? matching[0].status : 'empty');
  let next: WaterfallContinuation | null = null;
  if (source === 'youtube' && matching.length > 0 && matching[0].providerData !== undefined) {
    const token = continuationText(matching[0].providerData as DynamicPostValue, ['nextPageToken']);
    if (token.length > 0 && (continuation === null || token !== continuation.value)) {
      next = { kind: 'cursor', value: token };
    }
  } else if (source === 'bilibili' && videos.length >= limit) {
    const currentPage = continuation !== null && continuation.kind === 'page' ?
      Math.max(1, Number(continuation.value)) : 1;
    next = { kind: 'page', value: (currentPage + 1).toString() };
  }
  return {
    source: source,
    videos: videos,
    posts: [],
    status: statusFor(source, rawStatus, mediaMessage(source, videos.length, matching), videos.length),
    continuation: next
  };
}

async function aggregateComposioSourceBatch(
  source: AggregateSearchSource,
  provider: string,
  prompt: string,
  fixedToolId: string = '',
  fixedArgs: Object | null = null,
  previous: WaterfallContinuation | null = null,
  limit: number = 10
): Promise<AggregateSearchSourceBatch> {
  const posts: AggregateSearchPost[] = [];
  const statuses: AggregateSearchSourceStatus[] = [];
  const result = await appendComposioPosts(source, provider, prompt, posts, statuses, fixedToolId, fixedArgs);
  return {
    source: source,
    videos: [],
    posts: posts.slice(0, limit),
    status: statuses.length > 0 ? statuses[0] : statusFor(source, 'empty', provider + ' returned 0 rows.', 0),
    continuation: result === null ? null : aggregateContinuationFromDynamicResult(source, result, previous)
  };
}

function postRecord(post: AggregateSearchPost): DynamicPostRecord | null {
  return post.rows.length > 0 ? dynamicPostRecord(post.rows[0].value) : null;
}

function postProviderId(post: AggregateSearchPost): string {
  const rowId = aggregateRowText(post.rows, ['Content ID', 'Provider ID']);
  if (rowId.length > 0) return rowId;
  const record = postRecord(post);
  if (record !== null) {
    const id = recordText(record, ['id', 'objectID', 'object_id', 'story_id']);
    if (id.length > 0) {
      return id;
    }
  }
  const reddit = post.url.match(/\/comments\/([^/]+)/);
  if (reddit !== null) {
    return reddit[1];
  }
  const queryId = post.url.match(/[?&]id=([^&#]+)/);
  return queryId === null ? '' : queryId[1];
}

function commentTextsFromResult(result: DynamicGenericToolResult): string[] {
  const comments: string[] = [];
  try {
    appendCommentTexts(JSON.parse(result.rawPreview) as DynamicPostValue, comments);
  } catch (_error) {}
  if (comments.length < 5) {
    result.rows.forEach((row: AggregateSearchRowData): void => {
      appendCommentTexts(parsedDynamicPostRecord(row.value), comments);
    });
  }
  return comments.slice(0, 5);
}

function childIdsFromResult(result: DynamicGenericToolResult): string[] {
  try {
    const value = JSON.parse(result.rawPreview) as DynamicPostValue;
    const record = dynamicRecord(value);
    const data = record === null ? null : dynamicRecord(record.data);
    let kids: DynamicPostValue[] = [];
    if (data !== null && Array.isArray(data.kids)) {
      kids = data.kids as DynamicPostValue[];
    } else if (record !== null && Array.isArray(record.kids)) {
      kids = record.kids as DynamicPostValue[];
    }
    return kids.slice(0, 5).map((item: DynamicPostValue): string => textOf(item).trim()).filter((id: string): boolean => id.length > 0);
  } catch (_error) {
    return [];
  }
}

export function waterfallCommentSourceSupported(source: string): boolean {
  return source === 'youtube' || source === 'bilibili' || source === 'x' ||
    source === 'hackernews' || source === 'reddit';
}

function commentResult(comments: WaterfallComment[]): WaterfallCommentsResult {
  const visible = comments.filter((comment: WaterfallComment): boolean => comment.text.trim().length > 0).slice(0, 5);
  return { state: visible.length > 0 ? 'ready' : 'empty', comments: visible };
}

function textComments(values: string[]): WaterfallComment[] {
  return values.slice(0, 5).map((value: string): WaterfallComment => ({ text: value }));
}

export async function loadWaterfallComments(
  source: AggregateSearchSource,
  providerItemId: string,
  youtubeApiKey: string = ''
): Promise<WaterfallCommentsResult> {
  const id = providerItemId.trim();
  if (!waterfallCommentSourceSupported(source) || id.length === 0) return { state: 'empty', comments: [] };
  try {
    if (source === 'youtube') return commentResult(await callYouTubeVideoComments(id, youtubeApiKey));
    if (source === 'bilibili') return commentResult(await callBilibiliVideoComments(id));
    if (source === 'reddit') {
      const args: AggregateRedditCommentsArgs = { articleId: id };
      const result = await callComposioFixedDynamic('帮我用 Composio Reddit 读取帖子评论', 'social.reddit.comments', args as Object);
      if (result !== null && result.status === 'success') {
        return commentResult(textComments(commentTextsFromResult(result)));
      }
      return { state: 'empty', comments: [] };
    }
    if (source === 'x') {
      const args: AggregateXSearchArgs = {
        query: 'conversation_id:' + id + ' -is:retweet', pageSize: 10,
        expansions: 'author_id', mediaFields: '', tweetFields: 'id,text,author_id,created_at,conversation_id',
        userFields: 'id,name,username,profile_image_url'
      };
      const result = await callComposioFixedDynamic('帮我用 Composio X 读取公开回复', 'x.post.search', args as Object);
      if (result !== null && result.status === 'success') {
        return commentResult(xPostsFromComposioResult(result).filter((reply: AggregateSearchPost): boolean =>
          postProviderId(reply) !== id).slice(0, 5).map((reply: AggregateSearchPost): WaterfallComment => ({
          text: reply.text,
          authorName: reply.author || undefined,
          authorAvatarUrl: aggregateAvatar(reply.rows) || undefined,
          publishedAt: reply.publishedAt || undefined
        })));
      }
      return { state: 'empty', comments: [] };
    }
    if (source === 'hackernews') {
      const parentArgs: AggregateHackerNewsItemArgs = { itemId: id };
      const parent = await callComposioFixedDynamic('帮我用 Composio Hacker News 读取帖子', 'social.hackernews.item.read', parentArgs as Object);
      if (parent === null || parent.status !== 'success') {
        return { state: 'empty', comments: [] };
      }
      const childIds = childIdsFromResult(parent);
      const comments: string[] = [];
      for (let index = 0; index < childIds.length; index++) {
        const childArgs: AggregateHackerNewsItemArgs = { itemId: childIds[index] };
        const child = await callComposioFixedDynamic('帮我用 Composio Hacker News 读取评论', 'social.hackernews.item.read', childArgs as Object);
        if (child !== null && child.status === 'success') {
          commentTextsFromResult(child).forEach((text: string): void => {
            if (comments.length < 5 && comments.indexOf(text) < 0) comments.push(text);
          });
        }
      }
      return commentResult(textComments(comments));
    }
  } catch (_error) {
    return { state: 'error', comments: [] };
  }
  return { state: 'empty', comments: [] };
}

async function aggregateZhihuSourceBatch(config: AggregateZhihuConfig, query: string): Promise<AggregateSearchSourceBatch> {
  const posts: AggregateSearchPost[] = [];
  const statuses: AggregateSearchSourceStatus[] = [];
  await appendZhihuPosts(config, query, posts, statuses);
  return {
    source: 'zhihu',
    videos: [],
    posts: posts.slice(0, 10),
    status: statuses.length > 0 ? statuses[0] : statusFor('zhihu', 'empty', '知乎返回 0 条。', 0),
    continuation: null
  };
}

export async function aggregateZhihuHotListBatch(
  config: AggregateZhihuConfig,
  limit: number = 10
): Promise<AggregateSearchSourceBatch> {
  const posts: AggregateSearchPost[] = [];
  const statuses: AggregateSearchSourceStatus[] = [];
  await appendZhihuHotListPosts(config, limit, posts, statuses);
  return {
    source: 'zhihu',
    videos: [],
    posts: posts.slice(0, limit),
    status: statuses.length > 0 ? statuses[0] : statusFor('zhihu', 'empty', '知乎热榜返回 0 条。', 0),
    continuation: null
  };
}

function doubanPost(item: DoubanPublicSearchItem): AggregateSearchPost {
  const rows: AggregateSearchRowData[] = [];
  if (item.imageUrl.length > 0) {
    rows.push({ label: 'Cover', value: item.imageUrl });
  }
  rows.push({ label: 'Content type', value: item.kind });
  if (item.rating.length > 0) {
    rows.push({ label: 'Rating', value: item.rating });
  }
  if (item.ratingCount.length > 0) {
    rows.push({ label: 'Rating count', value: item.ratingCount });
  }
  if (item.metadata.length > 0 && item.metadata !== item.summary) {
    rows.push({ label: 'Metadata', value: item.metadata });
  }
  return {
    id: item.id,
    source: 'douban',
    provider: '豆瓣公开书影音（Experimental）',
    title: item.title,
    author: '',
    handle: '',
    text: item.summary,
    url: item.url,
    publishedAt: '',
    score: item.rating,
    commentCount: '',
    status: 'success',
    rows: rows
  };
}

async function aggregateDoubanSourceBatch(query: string, limit: number): Promise<AggregateSearchSourceBatch> {
  const result = await new DoubanPlaywrightMcpClient().search(runtimeExternalProviderConfig.doubanPlaywright, {
    query: query,
    kinds: ['book', 'movie', 'music'],
    limit: limit,
    start: 0
  });
  const posts = result.items.map((item: DoubanPublicSearchItem): AggregateSearchPost => doubanPost(item));
  const status: AggregateSearchStatus = result.status === 'disabled' ? 'unsupported' : result.status;
  return {
    source: 'douban',
    videos: [],
    posts: posts,
    status: statusFor('douban', status, result.message, posts.length),
    continuation: null
  };
}

function twitchItemAllowedByPolicy(item: TwitchChannelSearchItem, policy: AggregateSearchPolicy): boolean {
  if (policy.multilingual) {
    return true;
  }
  const language = item.language.trim().toLowerCase();
  return language.length === 0 || language === 'zh' || language.indexOf('zh-') === 0;
}

function twitchPost(item: TwitchChannelSearchItem): AggregateSearchPost {
  const rows: AggregateSearchRowData[] = [];
  if (item.thumbnailUrl.length > 0) {
    rows.push({ label: 'Thumbnail', value: item.thumbnailUrl });
  }
  rows.push({ label: 'Live', value: item.isLive ? 'true' : 'false' });
  rows.push({ label: 'Kind', value: item.kind });
  rows.push({ label: 'Viewers', value: item.viewerCount.toString() });
  if (item.gameName.length > 0) {
    rows.push({ label: 'Game', value: item.gameName });
  }
  if (item.language.length > 0) {
    rows.push({ label: 'Language', value: item.language });
  }
  if (item.startedAt.length > 0) {
    rows.push({ label: 'Started', value: item.startedAt });
  }
  if (item.tags.length > 0) {
    rows.push({ label: 'Tags', value: item.tags.join(' / ') });
  }
  const details: string[] = [item.isLive ? '正在直播' : '近期频道'];
  if (item.kind === 'tech') {
    details.push('科技热门');
  } else if (item.kind === 'game') {
    details.push('游戏热门');
  } else {
    details.push('关键词搜索');
  }
  if (item.gameName.length > 0) {
    details.push(item.gameName);
  }
  return {
    id: 'twitch-' + item.id,
    source: 'twitch',
    provider: 'Twitch',
    title: item.title.length > 0 ? item.title : item.broadcasterName,
    author: item.broadcasterName,
    handle: item.broadcasterLogin,
    text: details.join(' · '),
    url: item.url,
    publishedAt: item.startedAt,
    score: item.viewerCount.toString(),
    commentCount: '',
    status: 'success',
    rows: rows
  };
}

async function aggregateTwitchSourceBatch(
  query: string,
  continuation: WaterfallContinuation | null,
  limit: number,
  policy: AggregateSearchPolicy,
  context: AggregateSearchSourceContext
): Promise<AggregateSearchSourceBatch> {
  const cursor = continuation !== null && continuation.kind === 'cursor' ? continuation.value : null;
  const result: TwitchChannelSearchBatch = context === 'interest' ? await discoverTwitchInterestStreams(
    runtimeExternalProviderConfig.twitch, { multilingual: policy.multilingual, technologyLimit: 3 }
  ) : await searchTwitchChannels(runtimeExternalProviderConfig.twitch, query, limit, cursor);
  const posts = result.items.filter((item: TwitchChannelSearchItem): boolean =>
    twitchItemAllowedByPolicy(item, policy)).map((item: TwitchChannelSearchItem): AggregateSearchPost =>
    twitchPost(item));
  let message = result.message;
  if (!policy.multilingual && result.items.length > posts.length) {
    message += ' 中文频道过滤后保留 ' + posts.length.toString() + ' 条。';
  }
  aiLogInfo('[AIPhone][TwitchPostFilter] multilingual=' + (policy.multilingual ? 'true' : 'false') +
    ' raw=' + result.items.length.toString() + ' kept=' + posts.length.toString() +
    ' status=' + result.status);
  const status: AggregateSearchStatus = result.status === 'success' && posts.length === 0 ? 'empty' : result.status;
  return {
    source: 'twitch',
    videos: [],
    posts: posts,
    status: statusFor('twitch', status, message, posts.length),
    continuation: result.continuation === null ? null : { kind: 'cursor', value: result.continuation },
    rawCount: result.items.length
  };
}

function aggregateSourceBatch(
  source: AggregateSearchSource,
  query: string,
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig,
  continuation: WaterfallContinuation | null,
  limit: number,
  policy: AggregateSearchPolicy = runtimeSearchPolicy,
  context: AggregateSearchSourceContext = 'search'
): Promise<AggregateSearchSourceBatch> {
  if (source === 'youtube' || source === 'bilibili') {
    return aggregateMediaSourceBatch(source, query, youtubeApiKey, continuation, limit, policy);
  }
  if (source === 'applepodcasts') {
    return searchApplePodcasts(query, policy, limit);
  }
  if (source === 'douban') {
    return aggregateDoubanSourceBatch(query, limit);
  }
  if (source === 'twitch') {
    return aggregateTwitchSourceBatch(query, continuation, limit, policy, context);
  }
  if (source === 'cnnews') {
    return loadCnNewsSource(limit, context === 'search' ? query : '');
  }
  if (source === 'github') {
    return context === 'interest' ? discoverPublicGitHub(limit) : searchPublicGitHub(query, limit);
  }
  if (source === 'steam') {
    return discoverSteamNews(context === 'search' ? query : '', limit);
  }
  if (source === 'globalnews') {
    return loadGlobalNews(runtimeExternalProviderConfig.globalNews, context === 'search' ? query : '', limit);
  }
  if (source === 'x') {
    const args: AggregateXSearchArgs = {
      query: aggregateXSearchQuery(query, policy),
      pageSize: limit,
      expansions: 'attachments.media_keys,author_id',
      mediaFields: 'media_key,type,url,preview_image_url,variants,width,height',
      tweetFields: 'id,text,author_id,created_at,public_metrics,attachments,conversation_id',
      userFields: 'id,name,username,profile_image_url'
    };
    if (continuation !== null && continuation.kind === 'cursor') {
      args.cursor = continuation.value;
    }
    return aggregateComposioSourceBatch(
      source, 'X', '帮我用 Composio X 搜索 ' + query + ' 的公开 post',
      'x.post.search', args as Object, continuation, limit
    );
  }
  if (source === 'hackernews') {
    const page = continuation !== null && continuation.kind === 'page' ? Number(continuation.value) : 0;
    const args: AggregateHackerNewsSearchArgs = { query: query, page: page, size: limit };
    return aggregateComposioSourceBatch(
      source, 'Hacker News', '帮我用 Composio Hacker News 查 ' + query,
      'social.hackernews.search', args as Object, continuation, limit
    );
  }
  if (source === 'reddit') {
    const args: AggregateRedditSearchArgs = { searchQuery: query, limit: limit };
    if (continuation !== null && continuation.kind === 'cursor') {
      args.cursor = continuation.value;
    }
    return aggregateComposioSourceBatch(
      source, 'Reddit', '帮我用 Composio Reddit 查 ' + query + ' 的帖子',
      'social.reddit.search', args as Object, continuation, limit
    );
  }
  return aggregateZhihuSourceBatch(zhihuConfig, query);
}

export type AggregateSearchBatchObserver = (batch: AggregateSearchSourceBatch) => void;

export type AggregateSearchSourceLoader = (
  source: AggregateSearchSource,
  query: string,
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig,
  continuation: WaterfallContinuation | null,
  limit: number,
  policy: AggregateSearchPolicy,
  context?: AggregateSearchSourceContext
) => Promise<AggregateSearchSourceBatch>;

export async function callAggregateSearchContinuation(
  query: string,
  requests: WaterfallLoadRequest[],
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig,
  onBatch: AggregateSearchBatchObserver,
  loadSource: AggregateSearchSourceLoader = aggregateSourceBatch
): Promise<void> {
  return callAggregateSearchContinuationForContext(
    'search', query, requests, youtubeApiKey, zhihuConfig, onBatch, loadSource
  );
}

export async function callAggregateSearchContinuationForContext(
  context: 'search' | 'interest',
  query: string,
  requests: WaterfallLoadRequest[],
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig,
  onBatch: AggregateSearchBatchObserver,
  loadSource: AggregateSearchSourceLoader = aggregateSourceBatch
): Promise<void> {
  const availableSources = aggregateSearchSourceIdsForContext(context);
  const availableRequests = requests.filter((request: WaterfallLoadRequest): boolean => {
    const source = request.source as AggregateSearchSource;
    if (availableSources.indexOf(source) < 0) {
      return false;
    }
    return context !== 'interest' || waterfallInterestSourceAllowedForRuntime(source);
  });
  await Promise.all(availableRequests.map((request: WaterfallLoadRequest): Promise<void> => {
    if (request.mode === 'native' && request.continuation === null) {
      onBatch(exhaustedAggregateBatch(request));
      return Promise.resolve();
    }
    return loadSource(
      request.source as AggregateSearchSource,
      query,
      youtubeApiKey,
      zhihuConfig,
      request.continuation,
      request.limit,
      runtimeSearchPolicy,
      context
    ).then((batch: AggregateSearchSourceBatch): void => onBatch(batch)).catch(
      (error: Error | Object | string | number | boolean | null | undefined): void => {
        const failed = failedAggregateBatch(request.source as AggregateSearchSource, error);
        onBatch(failed);
      }
    );
  }));
}

export function mergeAggregateSearchContinuationBatch(
  state: WaterfallFeedState,
  batch: AggregateSearchSourceBatch,
  batchIndex: number,
  nowMs: number
): WaterfallFeedState {
  return mergeWaterfallBatch(
    state,
    aggregateMediaCandidates(
      batch.videos.slice(0, 10),
      batch.posts.slice(0, 10),
      batchIndex,
      state.query,
      state.queryStage ?? 'original'
    ),
    sourceStateFor(batch),
    nowMs,
    false
  ).state;
}

export async function callAggregateSearch(
  prompt: string,
  args: Object | null,
  youtubeApiKey: string,
  zhihuConfig: AggregateZhihuConfig = emptyZhihuConfig(),
  onPartial: AggregateSearchPartialObserver | null = null,
  nowMs: number = Date.now()
): Promise<AggregateSearchResult> {
  const query = aggregateSearchQueryFromArgs(prompt, args);
  const policy = aggregateSearchPolicyForCall(args);
  const sources = aggregateSearchSourcesFromArgs(args, policy);
  configureWaterfallSearchPolicyForRuntime(policy);
  const preferenceDescription = args === null ? '' : textOf((args as AggregateArgRecord).preferenceDescription).trim();
  const tasks: Promise<AggregateSearchSourceBatch>[] = [];
  sources.forEach((source: AggregateSearchSource): void => {
    tasks.push(aggregateSourceBatch(source, query, youtubeApiKey, zhihuConfig, null, 10, policy));
  });
  const observer: AggregateSearchPartialObserver = onPartial === null ? (() => {}) : onPartial;
  return streamAggregateSearchSourceBatches(query, sources, tasks, observer, nowMs, preferenceDescription);
}
