import { http } from '@kit.NetworkKit';
import xml from '@ohos.xml';
import {
  AggregateSearchPost,
  AggregateSearchSource,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const MAX_FEED_BODY_BYTES: number = 2 * 1024 * 1024;
const MAX_FEED_ITEMS: number = 80;
const MAX_SOURCE_POSTS: number = 4;

interface PublicFeedDefinition {
  provider: string;
  urls: string[];
}

interface PublicFeedItem {
  title: string;
  url: string;
  summary: string;
  content: string;
  publishedAt: string;
  author: string;
}

export type PublicFeedEventKind = 'start' | 'end' | 'text' | 'attribute';

export interface PublicFeedEvent {
  kind: PublicFeedEventKind;
  name: string;
  value: string;
  tagName: string;
}

const PUBLIC_FEEDS: PublicFeedDefinition[] = [
  { provider: '中国新闻网', urls: ['https://www.chinanews.com.cn/rss/scroll-news.xml'] },
  { provider: 'IT 之家', urls: ['https://www.ithome.com/rss/'] },
  { provider: '少数派', urls: ['https://sspai.com/feed'] },
  { provider: '爱范儿', urls: ['https://www.ifanr.com/feed'] }
];

function localXmlName(value: string): string {
  const lower = value.trim().toLowerCase();
  const colon = lower.lastIndexOf(':');
  return colon >= 0 ? lower.slice(colon + 1) : lower;
}

function cleanText(value: string): string {
  return value.replace(/<[^>]*>/g, ' ').replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/\s+/g, ' ').trim();
}

function normalizedHttpsUrl(value: string): string {
  const clean = value.trim();
  if (!clean.toLowerCase().startsWith('https://') || /[\\\s\u0000-\u001f]/.test(clean)) return '';
  const fragment = clean.indexOf('#');
  return fragment >= 0 ? clean.slice(0, fragment) : clean;
}

function emptyFeedItem(): PublicFeedItem {
  return { title: '', url: '', summary: '', content: '', publishedAt: '', author: '' };
}

class PublicFeedCollector {
  private inItem: boolean = false;
  private itemCount: number = 0;
  private callbackCountValue: number = 0;
  private item: PublicFeedItem = emptyFeedItem();
  private readonly items: PublicFeedItem[] = [];

  startTag(name: string): boolean {
    this.callbackCountValue += 1;
    const tag = localXmlName(name);
    if (tag === 'item' || tag === 'entry') {
      if (this.itemCount >= MAX_FEED_ITEMS) return false;
      this.inItem = true;
      this.itemCount += 1;
      this.item = emptyFeedItem();
    }
    return true;
  }

  appendText(name: string, value: string): void {
    this.callbackCountValue += 1;
    if (!this.inItem || value.length === 0) return;
    const tag = localXmlName(name);
    if (tag === 'title') this.item.title += value;
    else if (tag === 'link') this.item.url += value;
    else if (tag === 'description' || tag === 'summary') this.item.summary += value;
    else if (tag === 'content' || tag === 'encoded') this.item.content += value;
    else if (tag === 'pubdate' || tag === 'published' || tag === 'updated') this.item.publishedAt += value;
    else if (tag === 'author' || tag === 'creator' || tag === 'name') this.item.author += value;
  }

  attribute(tagName: string, name: string, value: string): void {
    this.callbackCountValue += 1;
    if (!this.inItem || localXmlName(tagName) !== 'link' || localXmlName(name) !== 'href') return;
    this.item.url = value;
  }

  endTag(name: string): boolean {
    this.callbackCountValue += 1;
    const tag = localXmlName(name);
    if (this.inItem && (tag === 'item' || tag === 'entry')) {
      this.items.push(this.item);
      this.inItem = false;
      return this.itemCount < MAX_FEED_ITEMS;
    }
    return true;
  }

  result(): PublicFeedItem[] {
    return this.items;
  }

  callbackCount(): number {
    return this.callbackCountValue;
  }
}

function publicFeedPost(source: AggregateSearchSource, provider: string, item: PublicFeedItem): AggregateSearchPost | null {
  const title = cleanText(item.title);
  const url = normalizedHttpsUrl(cleanText(item.url));
  if (title.length === 0 || url.length === 0) return null;
  const summary = cleanText(item.summary);
  const content = cleanText(item.content);
  return {
    id: source + '-' + encodeURIComponent(url).slice(0, 512),
    source: source,
    provider: provider,
    title: title,
    author: cleanText(item.author),
    handle: '',
    text: content.length >= summary.length ? content : summary,
    url: url,
    publishedAt: cleanText(item.publishedAt),
    score: '',
    commentCount: '',
    status: 'success',
    rows: []
  };
}

function postLimit(limit: number): number {
  if (!Number.isFinite(limit) || limit <= 0) return 0;
  return Math.min(MAX_SOURCE_POSTS, Math.floor(limit));
}

function postMatchesQuery(post: AggregateSearchPost, query: string): boolean {
  const terms = cleanText(query).toLowerCase().split(' ').filter((term: string): boolean => term.length > 0);
  if (terms.length === 0) return true;
  const text = (post.title + ' ' + post.text + ' ' + post.author).toLowerCase();
  return terms.every((term: string): boolean => text.indexOf(term) >= 0);
}

function postsFromCollectedItems(
  source: AggregateSearchSource,
  provider: string,
  items: PublicFeedItem[],
  limit: number,
  query: string = ''
): AggregateSearchPost[] {
  const posts: AggregateSearchPost[] = [];
  const urls = new Set<string>();
  const maxCount = postLimit(limit);
  for (let index = 0; index < items.length && posts.length < maxCount; index += 1) {
    const post = publicFeedPost(source, provider, items[index]);
    if (post !== null && postMatchesQuery(post, query) && !urls.has(post.url)) {
      urls.add(post.url);
      posts.push(post);
    }
  }
  return posts;
}

export function publicFeedPostsFromEvents(
  source: AggregateSearchSource,
  provider: string,
  events: PublicFeedEvent[],
  limit: number,
  query: string = ''
): AggregateSearchPost[] {
  return postsFromCollectedItems(source, provider, publicFeedCollectorFromEvents(events).result(), limit, query);
}

function publicFeedCollectorFromEvents(events: PublicFeedEvent[]): PublicFeedCollector {
  const collector = new PublicFeedCollector();
  let currentTag: string = '';
  for (let index = 0; index < events.length; index += 1) {
    const event = events[index];
    if (event.kind === 'start') {
      if (!collector.startTag(event.name)) break;
      currentTag = event.name;
    }
    if (event.kind === 'text') {
      collector.appendText(event.name.length > 0 ? event.name : currentTag, event.value);
    }
    if (event.kind === 'attribute') collector.attribute(event.tagName, event.name, event.value);
    if (event.kind === 'end') {
      if (!collector.endTag(event.name)) break;
      currentTag = '';
    }
  }
  return collector;
}

export function publicFeedEventCallbackCount(events: PublicFeedEvent[]): number {
  return publicFeedCollectorFromEvents(events).callbackCount();
}

function publicFeedCollectorFromBuffer(body: ArrayBuffer): PublicFeedCollector | null {
  if (body.byteLength === 0 || body.byteLength > MAX_FEED_BODY_BYTES) return null;
  const parser = new xml.XmlPullParser(body, 'utf-8');
  const collector = new PublicFeedCollector();
  let currentTag: string = '';
  parser.parseXml({
    supportDoctype: false,
    ignoreNameSpace: false,
    attributeWithTagCallbackFunction: (tagName: string, name: string, value: string): boolean => {
      collector.attribute(tagName, name, value);
      return true;
    },
    tokenValueCallbackFunction: (eventType: xml.EventType, info: xml.ParseInfo): boolean => {
      if (eventType === xml.EventType.START_TAG) {
        const name = info.getName();
        currentTag = name;
        return collector.startTag(name);
      }
      if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
        collector.appendText(currentTag, info.getText());
      }
      if (eventType === xml.EventType.END_TAG) {
        const keepParsing = collector.endTag(info.getName());
        currentTag = '';
        return keepParsing;
      }
      return true;
    }
  });
  return collector;
}

function publicFeedPostsFromBuffer(
  source: AggregateSearchSource,
  provider: string,
  body: ArrayBuffer,
  limit: number,
  query: string = ''
): AggregateSearchPost[] {
  const collector = publicFeedCollectorFromBuffer(body);
  if (collector === null) return [];
  return postsFromCollectedItems(source, provider, collector.result(), limit, query);
}

function publicFeedRequestOptions(): http.HttpRequestOptions {
  return {
    method: http.RequestMethod.GET,
    header: {
      'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
      'User-Agent': 'Appless/0.1 (+https://github.com/XiaoLuoLYG/Appless-Phone)'
    },
    usingProtocol: http.HttpProtocol.HTTP1_1,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    connectTimeout: 5000,
    readTimeout: 10000,
    maxLimit: MAX_FEED_BODY_BYTES
  };
}

async function requestPublicFeed(url: string): Promise<ArrayBuffer> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, publicFeedRequestOptions());
    if (response.responseCode < 200 || response.responseCode >= 300) throw new Error('feed_http_' + response.responseCode.toString());
    if (JSON.stringify(response.header).toLowerCase().indexOf('xml') < 0) throw new Error('feed_not_xml');
    if (!(response.result instanceof ArrayBuffer) || response.result.byteLength === 0) throw new Error('feed_empty_reply');
    if (response.result.byteLength > MAX_FEED_BODY_BYTES) throw new Error('feed_body_too_large');
    return response.result;
  } finally {
    request.destroy();
  }
}

function sourceStatus(source: AggregateSearchSource, provider: string, status: 'success' | 'empty' | 'unsupported' | 'error', message: string, count: number): AggregateSearchSourceStatus {
  return { source: source, label: provider, status: status, message: message, count: count };
}

export async function loadCnNewsSource(
  limit: number = MAX_SOURCE_POSTS,
  query: string = ''
): Promise<AggregateSearchSourceBatch> {
  const source: AggregateSearchSource = 'cnnews';
  const providerPosts: AggregateSearchPost[][] = [];
  const posts: AggregateSearchPost[] = [];
  const urls = new Set<string>();
  let errorMessage = '';
  const loadedProviders = await Promise.all(PUBLIC_FEEDS.map(
    async (definition: PublicFeedDefinition): Promise<AggregateSearchPost[]> => {
      const collected: AggregateSearchPost[] = [];
      for (let urlIndex = 0; urlIndex < definition.urls.length; urlIndex += 1) {
        try {
          const parsed = publicFeedPostsFromBuffer(
            source, definition.provider, await requestPublicFeed(definition.urls[urlIndex]), limit, query);
          for (let postIndex = 0; postIndex < parsed.length && collected.length < postLimit(limit); postIndex += 1) {
            collected.push(parsed[postIndex]);
          }
        } catch (error) {
          errorMessage = error instanceof Error ? error.message : 'feed_request_failed';
        }
      }
      return collected;
    }
  ));
  loadedProviders.forEach((collected: AggregateSearchPost[]): void => {
    providerPosts.push(collected);
  });
  for (let itemIndex = 0; posts.length < postLimit(limit); itemIndex += 1) {
    let appended = false;
    for (let providerIndex = 0; providerIndex < providerPosts.length && posts.length < postLimit(limit); providerIndex += 1) {
      if (itemIndex < providerPosts[providerIndex].length) {
        appended = true;
        const post = providerPosts[providerIndex][itemIndex];
        if (!urls.has(post.url)) {
          urls.add(post.url);
          posts.push(post);
        }
      }
    }
    if (!appended) break;
  }
  const status = posts.length > 0 ? 'success' : errorMessage.length > 0 ? 'error' : 'empty';
  const detail = query.trim().length > 0 ? ' 关键词匹配 ' : ' 返回 ';
  const message = status === 'success' ? 'CNNews' + detail + posts.length.toString() + ' 条内容。' :
    status === 'empty' ? 'CNNews 未返回可用内容。' : 'CNNews 加载失败：' + errorMessage.slice(0, 160);
  return { source: source, videos: [], posts: posts,
    status: sourceStatus(source, 'CNNews', status, message, posts.length), continuation: null, rawCount: posts.length };
}
