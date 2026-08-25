import { http } from '@kit.NetworkKit';
import {
  AggregateSearchPost,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const STEAM_APP_IDS: number[] = [730, 570, 440];
const MAX_BODY_BYTES: number = 2 * 1024 * 1024;
const MAX_POSTS: number = 4;
const CACHE_MS: number = 15 * 60 * 1000;

type SteamValue = Object | string | number | boolean | null | undefined;
type SteamRecord = Record<string, SteamValue>;

let cachedPosts: AggregateSearchPost[] = [];
let cachedAt: number = 0;

function record(value: SteamValue): SteamRecord | null {
  return value !== null && !Array.isArray(value) && typeof value === 'object' ? value as SteamRecord : null;
}

function array(value: SteamValue): SteamValue[] {
  return Array.isArray(value) ? value as SteamValue[] : [];
}

function text(value: SteamValue): string {
  return typeof value === 'string' ? value.replace(/<[^>]*>/g, ' ').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim() : '';
}

function number(value: SteamValue): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function limit(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.min(MAX_POSTS, Math.floor(value)) : 0;
}

function httpsUrl(value: SteamValue): string {
  const url = text(value);
  return url.startsWith('https://') && !/[\\\s\u0000-\u001f]/.test(url) ? url.split('#')[0] : '';
}

export function steamNewsPostsFromPayload(rawJson: string, requestedLimit: number): AggregateSearchPost[] {
  const root = record(JSON.parse(rawJson) as SteamValue);
  const appNews = root === null ? null : record(root.appnews);
  const items = appNews === null ? [] : array(appNews.newsitems);
  const posts: AggregateSearchPost[] = [];
  const seenIds = new Set<string>();
  const seenUrls = new Set<string>();
  for (let index = 0; index < items.length && posts.length < limit(requestedLimit); index += 1) {
    const item = record(items[index]);
    if (item === null) continue;
    const id = text(item.gid);
    const title = text(item.title);
    const url = httpsUrl(item.url);
    if (id.length === 0 || title.length === 0 || url.length === 0 || seenIds.has(id) || seenUrls.has(url)) continue;
    seenIds.add(id);
    seenUrls.add(url);
    const timestamp = number(item.date);
    posts.push({
      id: 'steam-news-' + id, source: 'steam', provider: 'Steam', title: title,
      author: text(item.author), handle: '', text: text(item.contents), url: url,
      publishedAt: timestamp > 0 ? new Date(timestamp * 1000).toISOString() : '',
      score: '', commentCount: '', status: 'success', rows: []
    });
  }
  return posts;
}

function options(): http.HttpRequestOptions {
  return {
    method: http.RequestMethod.GET,
    header: { 'Accept': 'application/json', 'User-Agent': 'Appless/0.1' },
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: 5000,
    readTimeout: 10000,
    maxLimit: MAX_BODY_BYTES
  };
}

async function requestAppNews(appId: number): Promise<string> {
  const request = http.createHttp();
  try {
    const url = 'https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=' + appId.toString() +
      '&count=4&format=json';
    const response = await request.request(url, options());
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('steam_http_' + response.responseCode.toString());
    }
    const body = typeof response.result === 'string' ? response.result : '';
    if (body.length === 0 || body.length > MAX_BODY_BYTES) throw new Error('steam_invalid_reply');
    return body;
  } finally {
    request.destroy();
  }
}

function matches(post: AggregateSearchPost, query: string): boolean {
  const terms = query.trim().toLowerCase().split(/\s+/).filter((term: string): boolean => term.length > 0);
  const content = (post.title + ' ' + post.text + ' ' + post.author).toLowerCase();
  return terms.every((term: string): boolean => content.indexOf(term) >= 0);
}

function status(kind: 'success' | 'empty' | 'error', message: string, count: number): AggregateSearchSourceStatus {
  return { source: 'steam', label: 'Steam', status: kind, message: message, count: count };
}

export async function discoverSteamNews(query: string, requestedLimit: number): Promise<AggregateSearchSourceBatch> {
  let errorMessage = '';
  if (Date.now() - cachedAt >= CACHE_MS || cachedPosts.length === 0) {
    const next: AggregateSearchPost[] = [];
    const seen = new Set<string>();
    const replies = await Promise.all(STEAM_APP_IDS.map((appId: number): Promise<string> =>
      requestAppNews(appId).catch((error: Error): string => {
        errorMessage = error.message;
        return '';
      })));
    replies.forEach((reply: string): void => {
      if (reply.length === 0) return;
      steamNewsPostsFromPayload(reply, MAX_POSTS).forEach((post: AggregateSearchPost): void => {
        if (!seen.has(post.url)) {
          seen.add(post.url);
          next.push(post);
        }
      });
    });
    if (next.length > 0) {
      next.sort((left: AggregateSearchPost, right: AggregateSearchPost): number =>
        right.publishedAt.localeCompare(left.publishedAt));
      cachedPosts = next;
      cachedAt = Date.now();
    }
  }
  const posts = cachedPosts.filter((post: AggregateSearchPost): boolean => matches(post, query))
    .slice(0, limit(requestedLimit));
  const kind = posts.length > 0 ? 'success' : errorMessage.length > 0 ? 'error' : 'empty';
  const message = kind === 'error' ? 'Steam 新闻加载失败：' + errorMessage.slice(0, 160) :
    'Steam 返回 ' + posts.length.toString() + ' 条新闻。';
  return { source: 'steam', videos: [], posts: posts, status: status(kind, message, posts.length),
    continuation: null, rawCount: posts.length };
}
