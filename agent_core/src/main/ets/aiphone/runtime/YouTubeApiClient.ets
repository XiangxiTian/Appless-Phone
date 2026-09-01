import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { aiLogInfo } from './AiphoneLogger';
import {
  callComposioYouTubeSearchWithProviderData,
  callComposioYouTubeVideoDetailsBatchWithProviderData
} from './ComposioDynamicBackend';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { WaterfallComment } from './WaterfallAnythingCore';

const YOUTUBE_SEARCH_URL: string = 'https://www.googleapis.com/youtube/v3/search';
const YOUTUBE_VIDEOS_URL: string = 'https://www.googleapis.com/youtube/v3/videos';
const YOUTUBE_COMMENT_THREADS_URL: string = 'https://www.googleapis.com/youtube/v3/commentThreads';
let youtubeSearchDiagnosticSequence: number = 0;

interface YouTubeSearchResponse {
  nextPageToken?: string;
  items?: YouTubeSearchItem[];
}

interface YouTubeSearchItem {
  id?: YouTubeSearchItemId;
  snippet?: YouTubeSnippet;
}

interface YouTubeSearchItemId {
  videoId?: string;
}

interface YouTubeSnippet {
  title?: string;
  description?: string;
  channelTitle?: string;
  publishedAt?: string;
  thumbnails?: YouTubeThumbnails;
}

interface YouTubePopularResponse {
  nextPageToken?: string;
  items?: YouTubePopularItem[];
}

interface YouTubePopularItem {
  id?: string;
  snippet?: YouTubeSnippet;
  statistics?: YouTubeStatistics;
}

interface YouTubeStatistics {
  viewCount?: string;
  likeCount?: string;
  commentCount?: string;
}

interface YouTubeThumbnails {
  medium?: YouTubeThumbnail;
  default?: YouTubeThumbnail;
}

interface YouTubeThumbnail {
  url?: string;
}

interface YouTubeCommentThreadsResponse {
  items?: YouTubeCommentThread[];
}

interface YouTubeCommentThread {
  snippet?: YouTubeCommentThreadSnippet;
}

interface YouTubeCommentThreadSnippet {
  totalReplyCount?: number;
  topLevelComment?: YouTubeTopLevelComment;
}

interface YouTubeTopLevelComment {
  snippet?: YouTubeCommentSnippet;
}

interface YouTubeCommentSnippet {
  textOriginal?: string;
  textDisplay?: string;
  authorDisplayName?: string;
  authorProfileImageUrl?: string;
  likeCount?: number;
  publishedAt?: string;
}

export interface YouTubeSearchOptions {
  order: string;
  maxResults: number;
  relevanceLanguage?: string;
  pageToken?: string;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function normalizedYouTubeOrder(order: string): string {
  const trimmed = order.trim();
  if (trimmed === 'viewCount' || trimmed === 'date' || trimmed === 'rating' || trimmed === 'relevance' || trimmed === 'title') {
    return trimmed;
  }
  return 'relevance';
}

function normalizedYouTubeMaxResults(value: number): number {
  if (value < 1) {
    return 1;
  }
  if (value > 10) {
    return 10;
  }
  return value;
}

export function defaultYouTubeSearchOptions(): YouTubeSearchOptions {
  return {
    order: 'relevance',
    maxResults: 10,
    relevanceLanguage: '',
    pageToken: ''
  };
}

export function normalizeYouTubeRelevanceLanguage(value: string): string {
  const normalized = value.trim().toLowerCase().replace('_', '-');
  if (normalized === 'zh' || normalized === 'zh-hans' || normalized === 'zh-cn') {
    return 'zh-Hans';
  }
  if (normalized === 'en') {
    return 'en';
  }
  return '';
}

export function youtubeSearchUrl(
  query: string,
  apiKey: string,
  order: string = 'relevance',
  maxResults: number = 10,
  relevanceLanguageOrPageToken: string = '',
  pageToken: string = ''
): string {
  const params: string[][] = [
    ['part', 'snippet'],
    ['type', 'video'],
    ['maxResults', normalizedYouTubeMaxResults(maxResults).toString()],
    ['order', normalizedYouTubeOrder(order)],
    ['q', query],
    ['key', apiKey]
  ];
  const normalizedLanguage = normalizeYouTubeRelevanceLanguage(relevanceLanguageOrPageToken);
  if (normalizedLanguage.length > 0) {
    params.push(['relevanceLanguage', normalizedLanguage]);
  }
  // Upstream used the fifth argument for pageToken while this branch used it for language.
  // Accept both call shapes; internal callers pass an explicit sixth argument for pageToken.
  const legacyPageToken = normalizedLanguage.length === 0 &&
    relevanceLanguageOrPageToken.trim().toLowerCase() !== 'auto' ? relevanceLanguageOrPageToken.trim() : '';
  const normalizedPageToken = pageToken.trim().length > 0 ? pageToken.trim() : legacyPageToken;
  if (normalizedPageToken.length > 0) {
    params.push(['pageToken', normalizedPageToken]);
  }
  return YOUTUBE_SEARCH_URL + '?' + params.map((pair: string[]) => encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

export function youtubeMostPopularUrl(
  apiKey: string,
  maxResults: number = 10,
  pageToken: string = ''
): string {
  const params: string[][] = [
    ['part', 'snippet,statistics'],
    ['chart', 'mostPopular'],
    ['maxResults', normalizedYouTubeMaxResults(maxResults).toString()],
    ['key', apiKey]
  ];
  if (pageToken.trim().length > 0) params.push(['pageToken', pageToken.trim()]);
  return YOUTUBE_VIDEOS_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

export function youtubeCommentThreadsUrl(videoId: string, apiKey: string): string {
  const params: string[][] = [
    ['part', 'snippet'],
    ['videoId', videoId.trim()],
    ['order', 'relevance'],
    ['textFormat', 'plainText'],
    ['maxResults', '5'],
    ['key', apiKey.trim()]
  ];
  return YOUTUBE_COMMENT_THREADS_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

export function youtubeCommentsFromThreadsPayload(rawJson: string): WaterfallComment[] {
  const payload = JSON.parse(rawJson) as YouTubeCommentThreadsResponse;
  const items = Array.isArray(payload.items) ? payload.items : [];
  const comments: WaterfallComment[] = [];
  for (let index = 0; index < items.length && comments.length < 5; index++) {
    const thread = items[index].snippet;
    const snippet = thread?.topLevelComment?.snippet;
    const content = textOf(snippet?.textOriginal ?? snippet?.textDisplay).trim();
    if (snippet === undefined || content.length === 0 ||
      comments.some((comment: WaterfallComment): boolean => comment.text === content)) continue;
    comments.push({
      text: content,
      authorName: textOf(snippet.authorDisplayName).trim() || undefined,
      authorAvatarUrl: textOf(snippet.authorProfileImageUrl).trim() || undefined,
      publishedAt: textOf(snippet.publishedAt).trim() || undefined,
      likeCount: snippet.likeCount,
      replyCount: thread?.totalReplyCount
    });
  }
  return comments;
}

function watchUrl(videoId: string): string {
  return 'https://www.youtube.com/watch?v=' + encodeURIComponent(videoId);
}

function thumbnailUrl(snippet: YouTubeSnippet): string {
  if (snippet.thumbnails !== undefined && snippet.thumbnails.medium !== undefined) {
    return textOf(snippet.thumbnails.medium.url);
  }
  if (snippet.thumbnails !== undefined && snippet.thumbnails.default !== undefined) {
    return textOf(snippet.thumbnails.default.url);
  }
  return '';
}

export function youtubeVideoResultsFromSearchPayload(
  rawJson: string,
  query: string,
  sourceTag: string = 'YouTube Data API'
): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as YouTubeSearchResponse;
  const nextPageToken = textOf(payload.nextPageToken).trim();
  const items = Array.isArray(payload.items) ? payload.items : [];
  const results: DynamicGenericToolResult[] = [];
  for (let index = 0; index < items.length; index++) {
    const item = items[index];
    const videoId = item.id === undefined ? '' : textOf(item.id.videoId);
    const snippet = item.snippet;
    if (videoId.length === 0 || snippet === undefined) {
      continue;
    }
    const rows: A2uiLabelValueData[] = [
      { label: 'Channel', value: textOf(snippet.channelTitle) },
      { label: 'Published', value: textOf(snippet.publishedAt) },
      { label: 'Video ID', value: videoId },
      { label: 'Watch URL', value: watchUrl(videoId) }
    ];
    const image = thumbnailUrl(snippet);
    if (image.length > 0) {
      rows.push({ label: 'Thumbnail', value: image });
    }
    const result: DynamicGenericToolResult = {
      sourceTag: sourceTag,
      toolName: 'youtube.video.search',
      title: textOf(snippet.title),
      status: 'success',
      summary: 'YouTube video result for: ' + query,
      rows: rows,
      rawPreview: 'videoId=' + videoId
    };
    if (nextPageToken.length > 0) {
      result.providerData = JSON.parse('{"nextPageToken":' + JSON.stringify(nextPageToken) + '}') as Object;
    }
    results.push(result);
  }
  if (results.length > 0) {
    return results;
  }
  return [{
    sourceTag: sourceTag,
    toolName: 'youtube.video.search',
    title: '没有找到 YouTube 视频',
    status: 'success',
    summary: 'YouTube API 查询成功，但没有返回可展示视频。',
    rows: [{ label: 'Query', value: query }],
    rawPreview: 'query=' + query
  }];
}

export function youtubeVideoResultsFromPopularPayload(
  rawJson: string,
  sourceTag: string = 'YouTube Data API'
): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as YouTubePopularResponse;
  const nextPageToken = textOf(payload.nextPageToken).trim();
  const items = Array.isArray(payload.items) ? payload.items : [];
  const results: DynamicGenericToolResult[] = [];
  items.forEach((item: YouTubePopularItem): void => {
    const videoId = textOf(item.id).trim();
    const snippet = item.snippet;
    if (videoId.length === 0 || snippet === undefined) return;
    const rows: A2uiLabelValueData[] = [
      { label: 'Channel', value: textOf(snippet.channelTitle) },
      { label: 'Published', value: textOf(snippet.publishedAt) },
      { label: 'Video ID', value: videoId },
      { label: 'Watch URL', value: watchUrl(videoId) }
    ];
    const image = thumbnailUrl(snippet);
    if (image.length > 0) rows.push({ label: 'Thumbnail', value: image });
    if (item.statistics !== undefined) {
      if (textOf(item.statistics.viewCount).length > 0) {
        rows.push({ label: 'Views', value: textOf(item.statistics.viewCount) });
      }
      if (textOf(item.statistics.likeCount).length > 0) {
        rows.push({ label: 'Likes', value: textOf(item.statistics.likeCount) });
      }
      if (textOf(item.statistics.commentCount).length > 0) {
        rows.push({ label: 'Comments', value: textOf(item.statistics.commentCount) });
      }
    }
    const result: DynamicGenericToolResult = {
      sourceTag: sourceTag,
      toolName: 'youtube.videos.mostPopular',
      title: textOf(snippet.title),
      status: 'success',
      summary: textOf(snippet.description),
      rows,
      rawPreview: 'videoId=' + videoId
    };
    if (nextPageToken.length > 0) {
      result.providerData = JSON.parse('{"nextPageToken":' + JSON.stringify(nextPageToken) + '}') as Object;
    }
    results.push(result);
  });
  return results;
}

export function youtubeVideoResultsFromComposioPopular(
  result: DynamicGenericToolResult
): DynamicGenericToolResult[] {
  if (result.status !== 'success' || result.providerData === undefined) {
    return [result];
  }
  try {
    return youtubeVideoResultsFromPopularPayload(JSON.stringify(result.providerData), 'Composio YouTube');
  } catch (error) {
    return [{
      sourceTag: 'Composio YouTube',
      toolName: 'youtube.videos.mostPopular',
      title: 'YouTube Popular 数据解析失败',
      status: 'error',
      summary: error instanceof Error ? error.message : JSON.stringify(error),
      rows: [],
      rawPreview: 'invalid provider data',
      providerPhase: 'execution'
    }];
  }
}

export function youtubeVideoResultsFromComposioSearch(
  result: DynamicGenericToolResult,
  query: string
): DynamicGenericToolResult[] {
  if (result.status !== 'success' || result.providerData === undefined) {
    return [result];
  }
  try {
    return youtubeVideoResultsFromSearchPayload(JSON.stringify(result.providerData), query, 'Composio YouTube');
  } catch (error) {
    return [{
      sourceTag: 'Composio YouTube',
      toolName: 'youtube.video.search',
      title: 'YouTube 搜索数据解析失败',
      status: 'error',
      summary: error instanceof Error ? error.message : JSON.stringify(error),
      rows: [],
      rawPreview: 'invalid provider data',
      providerPhase: 'execution'
    }];
  }
}

function resultRowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) return result.rows[index].value.trim();
  }
  return '';
}

function appendYouTubeStatisticsRows(
  result: DynamicGenericToolResult,
  statistics: YouTubeStatistics
): void {
  result.rows = result.rows.filter((row: A2uiLabelValueData): boolean =>
    row.label !== 'Views' && row.label !== 'Likes' && row.label !== 'Comments');
  if (textOf(statistics.viewCount).length > 0) {
    result.rows.push({ label: 'Views', value: textOf(statistics.viewCount) });
  }
  if (textOf(statistics.likeCount).length > 0) {
    result.rows.push({ label: 'Likes', value: textOf(statistics.likeCount) });
  }
  if (textOf(statistics.commentCount).length > 0) {
    result.rows.push({ label: 'Comments', value: textOf(statistics.commentCount) });
  }
}

export function enrichYouTubeSearchResultsFromStatisticsPayload(
  results: DynamicGenericToolResult[],
  rawJson: string
): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as YouTubePopularResponse;
  const items = Array.isArray(payload.items) ? payload.items : [];
  const statisticsByVideoId: Map<string, YouTubeStatistics> = new Map<string, YouTubeStatistics>();
  items.forEach((item: YouTubePopularItem): void => {
    const videoId = textOf(item.id).trim();
    const statistics = item.statistics;
    if (videoId.length > 0 && statistics !== undefined) {
      statisticsByVideoId.set(videoId, statistics);
    }
  });
  results.forEach((result: DynamicGenericToolResult): void => {
    const statistics = statisticsByVideoId.get(resultRowValue(result, 'Video ID'));
    if (statistics !== undefined) appendYouTubeStatisticsRows(result, statistics);
  });
  return results;
}

async function enrichYouTubeSearchResults(
  results: DynamicGenericToolResult[],
  requestId: number
): Promise<DynamicGenericToolResult[]> {
  const videoIds: string[] = [];
  results.forEach((result: DynamicGenericToolResult): void => {
    const videoId = resultRowValue(result, 'Video ID');
    if (videoId.length > 0 && videoIds.indexOf(videoId) < 0) videoIds.push(videoId);
  });
  if (videoIds.length === 0) {
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=statistics-skip videoIds=0');
    return results;
  }
  const startedAtMs = Date.now();
  aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
    ' stage=statistics-composio-start videoIds=' + videoIds.length.toString());
  try {
    const response = await callComposioYouTubeVideoDetailsBatchWithProviderData(videoIds);
    const elapsedMs = Date.now() - startedAtMs;
    if (response.status !== 'success' || response.providerData === undefined) {
      aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
        ' stage=statistics-composio-error elapsedMs=' + elapsedMs.toString() +
        ' status=' + response.status);
      return results;
    }
    const enriched = enrichYouTubeSearchResultsFromStatisticsPayload(
      results, JSON.stringify(response.providerData));
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=statistics-composio-end elapsedMs=' + elapsedMs.toString() +
      ' results=' + enriched.length.toString());
    return enriched;
  } catch (_error) {
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=statistics-composio-exception elapsedMs=' + (Date.now() - startedAtMs).toString());
    return results;
  }
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

export async function callYouTubeVideoSearch(
  query: string,
  _apiKey: string,
  options: YouTubeSearchOptions = defaultYouTubeSearchOptions()
): Promise<DynamicGenericToolResult[]> {
  const requestId = ++youtubeSearchDiagnosticSequence;
  const adapterStartedAtMs = Date.now();
  aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
    ' stage=adapter-start queryChars=' + query.trim().length.toString() +
    ' continuation=' + ((options.pageToken ?? '').trim().length > 0 ? 'present' : 'none'));
  try {
    const composioStartedAtMs = Date.now();
    const result = await callComposioYouTubeSearchWithProviderData(
      query,
      normalizedYouTubeOrder(options.order),
      normalizedYouTubeMaxResults(options.maxResults),
      normalizeYouTubeRelevanceLanguage(options.relevanceLanguage ?? ''),
      options.pageToken ?? ''
    );
    const mapped = youtubeVideoResultsFromComposioSearch(result, query);
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=composio-end elapsedMs=' + (Date.now() - composioStartedAtMs).toString() +
      ' status=' + result.status + ' results=' + mapped.length.toString());
    const enriched = await enrichYouTubeSearchResults(mapped, requestId);
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=adapter-end elapsedMs=' + (Date.now() - adapterStartedAtMs).toString() +
      ' results=' + enriched.length.toString());
    return enriched;
  } catch (_error) {
    aiLogInfo('[AIPhone][YouTubeAdapterStage] requestId=' + requestId.toString() +
      ' stage=adapter-exception elapsedMs=' + (Date.now() - adapterStartedAtMs).toString());
    throw _error instanceof Error ? _error : new Error('YouTube adapter request failed.');
  }
}

export async function callYouTubeMostPopularVideos(
  apiKey: string,
  maxResults: number = 10,
  pageToken: string = ''
): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [{
      sourceTag: 'YouTube Data API', toolName: 'youtube.videos.mostPopular', title: '缺少 YouTube API Key',
      status: 'error', summary: '请在本地 provider 配置中设置 YOUTUBE_API_KEY。',
      rows: [{ label: 'Credential', value: 'YOUTUBE_API_KEY' }], rawPreview: 'missing YOUTUBE_API_KEY'
    }];
  }
  const request = http.createHttp();
  try {
    const response = await request.request(youtubeMostPopularUrl(apiKey.trim(), maxResults, pageToken), {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'application/json' },
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    });
    const text = responseText(response.result);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('HTTP ' + response.responseCode.toString() + ': ' + text.substring(0, 240));
    }
    return youtubeVideoResultsFromPopularPayload(text);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return [{
      sourceTag: 'YouTube Data API', toolName: 'youtube.videos.mostPopular', title: 'YouTube API 调用失败',
      status: 'error', summary: message, rows: [], rawPreview: 'error'
    }];
  } finally {
    request.destroy();
  }
}

export async function callYouTubeVideoComments(videoId: string, apiKey: string): Promise<WaterfallComment[]> {
  if (videoId.trim().length === 0 || apiKey.trim().length === 0) throw new Error('Missing YouTube comment credentials.');
  const request = http.createHttp();
  try {
    const response = await request.request(youtubeCommentThreadsUrl(videoId, apiKey), {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'application/json' },
      usingProtocol: http.HttpProtocol.HTTP1_1,
      connectTimeout: 10000,
      readTimeout: 20000
    });
    const text = responseText(response.result);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('HTTP ' + response.responseCode.toString() + ': ' + text.substring(0, 240));
    }
    return youtubeCommentsFromThreadsPayload(text);
  } finally {
    request.destroy();
  }
}
