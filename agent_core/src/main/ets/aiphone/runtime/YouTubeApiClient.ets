import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';

const YOUTUBE_SEARCH_URL: string = 'https://www.googleapis.com/youtube/v3/search';
const YOUTUBE_VIDEOS_URL: string = 'https://www.googleapis.com/youtube/v3/videos';

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
}

interface YouTubeThumbnails {
  medium?: YouTubeThumbnail;
  default?: YouTubeThumbnail;
}

interface YouTubeThumbnail {
  url?: string;
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
    ['part', 'snippet'],
    ['chart', 'mostPopular'],
    ['maxResults', normalizedYouTubeMaxResults(maxResults).toString()],
    ['key', apiKey]
  ];
  if (pageToken.trim().length > 0) params.push(['pageToken', pageToken.trim()]);
  return YOUTUBE_VIDEOS_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
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

export function youtubeVideoResultsFromSearchPayload(rawJson: string, query: string): DynamicGenericToolResult[] {
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
      sourceTag: 'YouTube Data API',
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
    sourceTag: 'YouTube Data API',
    toolName: 'youtube.video.search',
    title: '没有找到 YouTube 视频',
    status: 'success',
    summary: 'YouTube API 查询成功，但没有返回可展示视频。',
    rows: [{ label: 'Query', value: query }],
    rawPreview: 'query=' + query
  }];
}

export function youtubeVideoResultsFromPopularPayload(rawJson: string): DynamicGenericToolResult[] {
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
    const result: DynamicGenericToolResult = {
      sourceTag: 'YouTube Data API',
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

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

export async function callYouTubeVideoSearch(query: string, apiKey: string, options: YouTubeSearchOptions = defaultYouTubeSearchOptions()): Promise<DynamicGenericToolResult[]> {
  if (apiKey.trim().length === 0) {
    return [{
      sourceTag: 'YouTube Data API',
      toolName: 'youtube.video.search',
      title: '缺少 YouTube API Key',
      status: 'error',
      summary: '请在本地 provider 配置中设置 YOUTUBE_API_KEY。',
      rows: [{ label: 'Credential', value: 'YOUTUBE_API_KEY' }],
      rawPreview: 'missing YOUTUBE_API_KEY'
    }];
  }
  const request = http.createHttp();
  try {
    const response = await request.request(youtubeSearchUrl(
      query,
      apiKey.trim(),
      options.order,
      options.maxResults,
      options.relevanceLanguage === undefined ? '' : options.relevanceLanguage,
      options.pageToken === undefined ? '' : options.pageToken
    ), {
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
    return youtubeVideoResultsFromSearchPayload(text, query);
  } catch (error) {
    const rawMessage = error instanceof Error ? error.message : JSON.stringify(error);
    const lowerMessage = rawMessage.toLowerCase();
    const networkIssue = lowerMessage.includes('timeout') || lowerMessage.includes('timed out')
      || lowerMessage.includes('connect') || rawMessage.includes('2300');
    return [{
      sourceTag: 'YouTube Data API',
      toolName: 'youtube.video.search',
      title: 'YouTube API 调用失败',
      status: 'error',
      summary: networkIssue
        ? '设备无法连接 googleapis.com（超时/不可达）。YouTube 需要可访问 Google 的网络环境。原始错误：' + rawMessage
        : rawMessage,
      rows: [{ label: 'Query', value: query }],
      rawPreview: 'error'
    }];
  } finally {
    request.destroy();
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
