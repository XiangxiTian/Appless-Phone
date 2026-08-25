import { http } from '@kit.NetworkKit';
import {
  AggregateSearchPost,
  AggregateSearchRowData,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const GUARDIAN_API: string = 'https://content.guardianapis.com/search';
const NEWS_API: string = 'https://newsapi.org/v2';
const MAX_BODY_BYTES: number = 2 * 1024 * 1024;
const MAX_POSTS: number = 4;

export interface GlobalNewsConfig {
  guardianApiKey: string;
  newsApiKey: string;
}

type NewsValue = Object | string | number | boolean | null | undefined;
type NewsRecord = Record<string, NewsValue>;

function record(value: NewsValue): NewsRecord | null {
  return value !== null && !Array.isArray(value) && typeof value === 'object' ? value as NewsRecord : null;
}

function array(value: NewsValue): NewsValue[] {
  return Array.isArray(value) ? value as NewsValue[] : [];
}

function cleanText(value: NewsValue): string {
  return typeof value === 'string' ? value.replace(/<[^>]*>/g, ' ').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim() : '';
}

function httpsUrl(value: NewsValue): string {
  const url = cleanText(value);
  if (!url.startsWith('https://') || /[\\\s\u0000-\u001f]/.test(url)) return '';
  const fragment = url.indexOf('#');
  return fragment >= 0 ? url.slice(0, fragment) : url;
}

function limit(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.min(MAX_POSTS, Math.floor(value)) : 0;
}

function addCover(rows: AggregateSearchRowData[], value: NewsValue): void {
  const url = httpsUrl(value);
  if (url.length > 0) rows.push({ label: 'Cover', value: url });
}

function fullerText(primary: NewsValue, fallback: NewsValue): string {
  const primaryText = cleanText(primary);
  const fallbackText = cleanText(fallback);
  return primaryText.length >= fallbackText.length ? primaryText : fallbackText;
}

export function guardianPostsFromPayload(rawJson: string, requestedLimit: number): AggregateSearchPost[] {
  const root = record(JSON.parse(rawJson) as NewsValue);
  const response = root === null ? null : record(root.response);
  const items = response === null || cleanText(response.status) !== 'ok' ? [] : array(response.results);
  const posts: AggregateSearchPost[] = [];
  for (let index = 0; index < items.length && posts.length < limit(requestedLimit); index += 1) {
    const item = record(items[index]);
    if (item === null) continue;
    const title = cleanText(item.webTitle);
    const url = httpsUrl(item.webUrl);
    if (title.length === 0 || url.length === 0) continue;
    const fields = record(item.fields);
    const rows: AggregateSearchRowData[] = [];
    if (fields !== null) addCover(rows, fields.thumbnail);
    posts.push({
      id: 'guardian-' + encodeURIComponent(cleanText(item.id) || url).slice(0, 512),
      source: 'globalnews', provider: 'The Guardian', title: title,
      author: fields === null ? '' : cleanText(fields.byline), handle: '',
      text: fields === null ? '' : fullerText(fields.bodyText, fields.trailText), url: url,
      publishedAt: cleanText(item.webPublicationDate), score: '', commentCount: '', status: 'success', rows: rows
    });
  }
  return posts;
}

export function newsApiPostsFromPayload(rawJson: string, requestedLimit: number): AggregateSearchPost[] {
  const root = record(JSON.parse(rawJson) as NewsValue);
  const items = root === null || cleanText(root.status) !== 'ok' ? [] : array(root.articles);
  const posts: AggregateSearchPost[] = [];
  for (let index = 0; index < items.length && posts.length < limit(requestedLimit); index += 1) {
    const item = record(items[index]);
    if (item === null) continue;
    const source = record(item.source);
    const provider = source === null ? '' : cleanText(source.name);
    const title = cleanText(item.title);
    const url = httpsUrl(item.url);
    if (provider.length === 0 || title.length === 0 || url.length === 0) continue;
    const rows: AggregateSearchRowData[] = [];
    addCover(rows, item.urlToImage);
    posts.push({
      id: 'newsapi-' + encodeURIComponent(url).slice(0, 512), source: 'globalnews', provider: provider,
      title: title, author: cleanText(item.author), handle: '', text: fullerText(item.content, item.description),
      url: url, publishedAt: cleanText(item.publishedAt), score: '', commentCount: '', status: 'success', rows: rows
    });
  }
  return posts;
}

export function mergeGlobalNewsPosts(
  guardian: AggregateSearchPost[],
  newsApi: AggregateSearchPost[],
  requestedLimit: number
): AggregateSearchPost[] {
  const groups: AggregateSearchPost[][] = [guardian, newsApi];
  const posts: AggregateSearchPost[] = [];
  const seen = new Set<string>();
  for (let itemIndex = 0; posts.length < limit(requestedLimit); itemIndex += 1) {
    let appended = false;
    for (let groupIndex = 0; groupIndex < groups.length && posts.length < limit(requestedLimit); groupIndex += 1) {
      if (itemIndex >= groups[groupIndex].length) continue;
      const post = groups[groupIndex][itemIndex];
      if (!seen.has(post.url)) {
        seen.add(post.url);
        posts.push(post);
      }
      appended = true;
    }
    if (!appended) break;
  }
  return posts;
}

function options(extraHeader: Record<string, string>): http.HttpRequestOptions {
  const header: Record<string, string> = {
    'Accept': 'application/json',
    'User-Agent': 'Appless/0.1 (+https://github.com/XiaoLuoLYG/Appless-Phone)'
  };
  Object.keys(extraHeader).forEach((key: string): void => { header[key] = extraHeader[key]; });
  return {
    method: http.RequestMethod.GET,
    header: header,
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: 5000,
    readTimeout: 10000,
    maxLimit: MAX_BODY_BYTES
  };
}

async function requestJson(url: string, header: Record<string, string>): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, options(header));
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('news_http_' + response.responseCode.toString());
    }
    const body = typeof response.result === 'string' ? response.result : '';
    if (body.length === 0 || body.length > MAX_BODY_BYTES) throw new Error('news_invalid_reply');
    return body;
  } finally {
    request.destroy();
  }
}

function status(
  kind: 'success' | 'empty' | 'needs_auth' | 'error',
  message: string,
  count: number
): AggregateSearchSourceStatus {
  return { source: 'globalnews', label: 'GlobalNews', status: kind, message: message, count: count };
}

export async function loadGlobalNews(
  config: GlobalNewsConfig,
  query: string,
  requestedLimit: number
): Promise<AggregateSearchSourceBatch> {
  const guardianKey = config.guardianApiKey.trim();
  const newsApiKey = config.newsApiKey.trim();
  if (guardianKey.length === 0 && newsApiKey.length === 0) {
    return { source: 'globalnews', videos: [], posts: [],
      status: status('needs_auth', '未配置 GUARDIAN_API_KEY 或 NEWSAPI_API_KEY。', 0), continuation: null };
  }
  const count = limit(requestedLimit);
  let errors = '';
  const guardianPending: Promise<AggregateSearchPost[]> = guardianKey.length > 0 ?
    (async (): Promise<AggregateSearchPost[]> => {
      const params = query.trim().length > 0 ? '?q=' + encodeURIComponent(query.trim()) + '&order-by=relevance' :
        '?order-by=newest';
      const raw = await requestJson(GUARDIAN_API + params + '&page-size=' + count.toString() +
        '&show-fields=trailText,bodyText,byline,thumbnail&api-key=' + encodeURIComponent(guardianKey), {});
      return guardianPostsFromPayload(raw, count);
    })().catch((error: Error): AggregateSearchPost[] => {
      errors = error instanceof Error ? error.message : 'guardian_request_failed';
      return [];
    }) : Promise.resolve([]);
  const newsApiPending: Promise<AggregateSearchPost[]> = newsApiKey.length > 0 ?
    (async (): Promise<AggregateSearchPost[]> => {
      const url = query.trim().length > 0 ? NEWS_API + '/everything?q=' + encodeURIComponent(query.trim()) +
        '&sortBy=publishedAt&language=en&pageSize=' + count.toString() :
        NEWS_API + '/top-headlines?language=en&pageSize=' + count.toString();
      const header: Record<string, string> = { 'X-Api-Key': newsApiKey };
      return newsApiPostsFromPayload(await requestJson(url, header), count);
    })().catch((error: Error): AggregateSearchPost[] => {
      errors = errors + (errors.length > 0 ? ',' : '') +
        (error instanceof Error ? error.message : 'newsapi_request_failed');
      return [];
    }) : Promise.resolve([]);
  const loaded = await Promise.all([guardianPending, newsApiPending]);
  const guardian = loaded[0];
  const newsApi = loaded[1];
  const posts = mergeGlobalNewsPosts(guardian, newsApi, count);
  const kind = posts.length > 0 ? 'success' : errors.length > 0 ? 'error' : 'empty';
  const message = kind === 'error' ? 'GlobalNews 加载失败：' + errors.slice(0, 160) :
    'GlobalNews 返回 ' + posts.length.toString() + ' 条内容。';
  return { source: 'globalnews', videos: [], posts: posts, status: status(kind, message, posts.length),
    continuation: null, rawCount: posts.length };
}
