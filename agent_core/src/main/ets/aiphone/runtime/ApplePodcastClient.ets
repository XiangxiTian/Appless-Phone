import { http } from '@kit.NetworkKit';
import { url as arkUrl } from '@kit.ArkTS';
import util from '@ohos.util';
import xml from '@ohos.xml';
import {
  AggregateSearchPolicy,
  AggregateSearchPost,
  AggregateSearchRowData,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const APPLE_PODCAST_SEARCH_URL: string = 'https://itunes.apple.com/search';
const APPLE_PODCAST_PROVIDER: string = 'Apple Podcasts';
const DEFAULT_RESULT_LIMIT: number = 10;
const MAX_RESULT_LIMIT: number = 50;
const MAX_RSS_BODY_BYTES: number = 10 * 1024 * 1024;
const MAX_RSS_ITEMS: number = 50;

export type ApplePodcastsCountry = 'CN' | 'US';

interface ApplePodcastSearchPayload {
  resultCount?: number;
  results?: ApplePodcastSearchItem[];
}

interface ApplePodcastSearchItem {
  collectionId?: number;
  trackId?: number;
  artistName?: string;
  collectionName?: string;
  collectionViewUrl?: string;
  feedUrl?: string;
  artworkUrl600?: string;
  artworkUrl100?: string;
  primaryGenreName?: string;
  genres?: string[];
  releaseDate?: string;
  trackCount?: number;
  country?: string;
}

export interface ApplePodcastHttpResult {
  code: number;
  text: string;
}

export interface ApplePodcastEpisodeAudio {
  mediaUrl: string;
  audioTitle: string;
  audioMimeType: string;
  audioDuration: string;
  audioPublishedAt: string;
}

export interface ApplePodcastResolverFailure {
  code: string;
  message: string;
  retryable: boolean;
}

interface ApplePodcastRssParseResult {
  episode: ApplePodcastEpisodeAudio | null;
  errorCode: string;
}

class ApplePodcastResolverError extends Error {
  readonly resolverCode: string;

  constructor(code: string) {
    super(code);
    this.name = 'ApplePodcastResolverError';
    this.resolverCode = code;
  }
}

interface ApplePodcastRssItem {
  title: string;
  publishedAt: string;
  duration: string;
  enclosureUrl: string;
  enclosureType: string;
}

export type ApplePodcastRssEventKind = 'start' | 'end' | 'text' | 'attribute';

export interface ApplePodcastRssEvent {
  kind: ApplePodcastRssEventKind;
  name: string;
  value?: string;
  tagName?: string;
}

export function applePodcastRssBodySizeAllowed(byteLength: number): boolean {
  return Number.isFinite(byteLength) && byteLength >= 0 && byteLength <= MAX_RSS_BODY_BYTES;
}

export function applePodcastRssRequestOptions(): http.HttpRequestOptions {
  return {
    method: http.RequestMethod.GET,
    header: { 'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml' },
    usingProtocol: http.HttpProtocol.HTTP1_1,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    connectTimeout: 5000,
    readTimeout: 8000,
    maxLimit: MAX_RSS_BODY_BYTES
  };
}

function cleanText(value: string | undefined): string {
  return value === undefined ? '' : value.trim();
}

function positiveInteger(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value) || value <= 0) {
    return 0;
  }
  return Math.floor(value);
}

function resultLimit(limit: number): number {
  if (!Number.isFinite(limit)) {
    return DEFAULT_RESULT_LIMIT;
  }
  return Math.max(1, Math.min(MAX_RESULT_LIMIT, Math.floor(limit)));
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  if (typeof result === 'number' || typeof result === 'boolean') {
    return result.toString();
  }
  return JSON.stringify(result);
}

/**
 * iTunes `country` selects a storefront rather than filtering content language.
 * Chinese-only aggregate mode uses the CN storefront as a relevance/availability bias;
 * multilingual mode uses the broader US storefront. No `lang` parameter is sent.
 */
export function applePodcastsCountryForPolicy(policy: AggregateSearchPolicy): ApplePodcastsCountry {
  return policy.multilingual ? 'US' : 'CN';
}

export function applePodcastsSearchUrl(
  query: string,
  limit: number = DEFAULT_RESULT_LIMIT,
  country: ApplePodcastsCountry = 'CN'
): string {
  const params: string[][] = [
    ['term', query.trim()],
    ['country', country],
    ['media', 'podcast'],
    ['entity', 'podcast'],
    ['limit', resultLimit(limit).toString()]
  ];
  return APPLE_PODCAST_SEARCH_URL + '?' + params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

function itemGenres(item: ApplePodcastSearchItem): string {
  if (item.genres !== undefined && Array.isArray(item.genres)) {
    const genres = item.genres.map((genre: string): string => genre.trim()).filter(
      (genre: string): boolean => genre.length > 0);
    if (genres.length > 0) {
      return genres.join(' / ');
    }
  }
  return cleanText(item.primaryGenreName);
}

function itemCover(item: ApplePodcastSearchItem): string {
  const large = cleanText(item.artworkUrl600);
  return large.length > 0 ? large : cleanText(item.artworkUrl100);
}

function itemId(item: ApplePodcastSearchItem, index: number): string {
  const collectionId = positiveInteger(item.collectionId);
  if (collectionId > 0) {
    return collectionId.toString();
  }
  const trackId = positiveInteger(item.trackId);
  return trackId > 0 ? trackId.toString() : index.toString();
}

function applePodcastPost(item: ApplePodcastSearchItem, index: number): AggregateSearchPost {
  const title = cleanText(item.collectionName);
  const author = cleanText(item.artistName);
  const appleUrl = cleanText(item.collectionViewUrl);
  const feedUrl = cleanText(item.feedUrl);
  const genre = itemGenres(item);
  const releaseDate = cleanText(item.releaseDate);
  const episodeCount = positiveInteger(item.trackCount);
  const rows: AggregateSearchRowData[] = [];
  const cover = itemCover(item);
  if (cover.length > 0) {
    rows.push({ label: 'Cover', value: cover });
  }
  if (feedUrl.length > 0) {
    rows.push({ label: 'Feed URL', value: feedUrl });
  }
  if (genre.length > 0) {
    rows.push({ label: 'Genre', value: genre });
  }
  if (releaseDate.length > 0) {
    rows.push({ label: 'Latest release', value: releaseDate });
  }
  if (episodeCount > 0) {
    rows.push({ label: 'Episodes', value: episodeCount.toString() });
  }
  const country = cleanText(item.country);
  if (country.length > 0) {
    rows.push({ label: 'Storefront', value: country });
  }
  const summaryParts: string[] = [];
  if (author.length > 0) {
    summaryParts.push(author);
  }
  if (genre.length > 0) {
    summaryParts.push(genre);
  }
  if (episodeCount > 0) {
    summaryParts.push(episodeCount.toString() + ' episodes');
  }
  return {
    id: 'applepodcasts-' + itemId(item, index),
    source: 'applepodcasts',
    provider: APPLE_PODCAST_PROVIDER,
    title: title,
    author: author,
    handle: '',
    text: summaryParts.join(' · '),
    url: appleUrl.length > 0 ? appleUrl : feedUrl,
    publishedAt: releaseDate,
    score: '',
    commentCount: '',
    status: 'success',
    rows: rows,
    feedUrl: feedUrl.length > 0 ? feedUrl : undefined
  };
}

function publicHttpsHost(value: string): string {
  const raw = value.trim();
  if (!raw.toLowerCase().startsWith('https://') || /[\\\s\u0000-\u001f]/.test(raw)) return '';
  const authorityStart = 'https://'.length;
  let authorityEnd = raw.length;
  const delimiters: string[] = ['/', '?', '#'];
  delimiters.forEach((delimiter: string): void => {
    const index = raw.indexOf(delimiter, authorityStart);
    if (index >= 0 && index < authorityEnd) authorityEnd = index;
  });
  const authority = raw.slice(authorityStart, authorityEnd);
  if (authority.length === 0 || authority.indexOf('@') >= 0 || authority.indexOf(':') >= 0) return '';
  const host = authority.toLowerCase().replace(/\.$/, '');
  if (!/^[a-z0-9.-]+$/.test(host) || host.indexOf('.') < 0 || host === 'localhost' ||
    host.endsWith('.localhost') || host.endsWith('.local') || /^\d+(?:\.\d+){3}$/.test(host)) return '';
  try {
    const parsed = new arkUrl.URL(raw);
    const parsedHost = parsed.hostname.toLowerCase().replace(/\.$/, '');
    if (parsedHost.length > 0 && (parsed.protocol !== 'https:' || parsedHost !== host ||
      parsed.username.length > 0 || parsed.password.length > 0)) return '';
  } catch (error) {
    if (!(error instanceof Error) || error.message.indexOf('URLSearchParams is not defined') < 0) return '';
  }
  return host;
}

export function validApplePodcastPublicHttpsUrl(value: string): boolean {
  return publicHttpsHost(value) !== '';
}

function localXmlName(value: string): string {
  const lower = value.trim().toLowerCase();
  const colon = lower.lastIndexOf(':');
  return colon >= 0 ? lower.slice(colon + 1) : lower;
}

function emptyRssItem(): ApplePodcastRssItem {
  return { title: '', publishedAt: '', duration: '', enclosureUrl: '', enclosureType: '' };
}

function episodeTimestamp(value: string): number {
  const parsed = Date.parse(value.trim());
  return Number.isFinite(parsed) ? parsed : 0;
}

class ApplePodcastRssCollector {
  private inItem: boolean = false;
  private itemCount: number = 0;
  private item: ApplePodcastRssItem = emptyRssItem();
  private enclosureUrl: string = '';
  private enclosureType: string = '';
  private best: ApplePodcastEpisodeAudio | null = null;
  private bestTimestamp: number = -1;
  private sawHttpAudioEnclosure: boolean = false;

  startTag(name: string): boolean {
    const tag = localXmlName(name);
    if (tag === 'item' || tag === 'entry') {
      if (this.itemCount >= MAX_RSS_ITEMS) return false;
      this.inItem = true;
      this.itemCount += 1;
      this.item = emptyRssItem();
    } else if (this.inItem && tag === 'enclosure') {
      this.enclosureUrl = '';
      this.enclosureType = '';
    }
    return true;
  }

  appendText(tagName: string, value: string): void {
    if (!this.inItem || value.length === 0) return;
    const tag = localXmlName(tagName);
    if (tag === 'title') this.item.title += value;
    else if (tag === 'pubdate' || tag === 'published' || tag === 'updated') this.item.publishedAt += value;
    else if (tag === 'duration') this.item.duration += value;
  }

  attribute(tagName: string, name: string, value: string): void {
    if (!this.inItem || localXmlName(tagName) !== 'enclosure') return;
    const attribute = localXmlName(name);
    if (attribute === 'url') this.enclosureUrl = value.trim();
    else if (attribute === 'type') this.enclosureType = value.trim().toLowerCase().split(';')[0];
  }

  endTag(name: string): boolean {
    const tag = localXmlName(name);
    if (this.inItem && tag === 'enclosure' && this.item.enclosureUrl.length === 0 &&
      this.enclosureType.startsWith('audio/')) {
      if (validApplePodcastPublicHttpsUrl(this.enclosureUrl)) {
        this.item.enclosureUrl = this.enclosureUrl;
        this.item.enclosureType = this.enclosureType;
      } else if (this.enclosureUrl.trim().toLowerCase().startsWith('http://')) {
        this.sawHttpAudioEnclosure = true;
      }
    }
    if (this.inItem && (tag === 'item' || tag === 'entry')) {
      if (this.item.enclosureUrl.length > 0) {
        const timestamp = episodeTimestamp(this.item.publishedAt);
        if (this.best === null || timestamp > this.bestTimestamp) {
          this.best = {
            mediaUrl: this.item.enclosureUrl,
            audioTitle: this.item.title.trim(),
            audioMimeType: this.item.enclosureType,
            audioDuration: this.item.duration.trim(),
            audioPublishedAt: this.item.publishedAt.trim()
          };
          this.bestTimestamp = timestamp;
        }
      }
      this.inItem = false;
    }
    return this.itemCount < MAX_RSS_ITEMS;
  }

  result(): ApplePodcastEpisodeAudio | null {
    return this.best;
  }

  errorCode(): string {
    if (this.best !== null) return '';
    return this.sawHttpAudioEnclosure ? 'rss_audio_requires_https' : 'rss_audio_enclosure_not_found';
  }
}

function rssResultFromBuffer(buffer: ArrayBuffer): ApplePodcastRssParseResult {
  if (buffer.byteLength === 0) return { episode: null, errorCode: 'rss_empty_reply' };
  if (!applePodcastRssBodySizeAllowed(buffer.byteLength)) {
    return { episode: null, errorCode: 'rss_body_too_large' };
  }
  const parser = new xml.XmlPullParser(buffer, 'utf-8');
  const collector = new ApplePodcastRssCollector();
  parser.parseXml({
    supportDoctype: false,
    ignoreNameSpace: false,
    tagValueCallbackFunction: (name: string, value: string): boolean => {
      collector.appendText(name, value);
      return true;
    },
    attributeWithTagCallbackFunction: (tagName: string, name: string, value: string): boolean => {
      collector.attribute(tagName, name, value);
      return true;
    },
    tokenValueCallbackFunction: (eventType: xml.EventType, info: xml.ParseInfo): boolean => {
      if (eventType === xml.EventType.START_TAG) return collector.startTag(info.getName());
      if (eventType === xml.EventType.END_TAG) return collector.endTag(info.getName());
      return true;
    }
  });
  return { episode: collector.result(), errorCode: collector.errorCode() };
}

function episodeFromRssBuffer(buffer: ArrayBuffer): ApplePodcastEpisodeAudio | null {
  return rssResultFromBuffer(buffer).episode;
}

export function applePodcastEpisodeFromRss(rawXml: string): ApplePodcastEpisodeAudio | null {
  const bytes = util.TextEncoder.create('utf-8').encodeInto(rawXml);
  if (!applePodcastRssBodySizeAllowed(bytes.byteLength)) return null;
  return episodeFromRssBuffer(bytes.buffer as ArrayBuffer);
}

export function applePodcastEpisodeFromRssEvents(events: ApplePodcastRssEvent[]): ApplePodcastEpisodeAudio | null {
  const collector = new ApplePodcastRssCollector();
  for (let index = 0; index < events.length; index += 1) {
    const event = events[index];
    if (event.kind === 'start' && !collector.startTag(event.name)) break;
    if (event.kind === 'text') collector.appendText(event.name, event.value ?? '');
    if (event.kind === 'attribute') collector.attribute(event.tagName ?? '', event.name, event.value ?? '');
    if (event.kind === 'end' && !collector.endTag(event.name)) break;
  }
  return collector.result();
}

export function applePodcastRssErrorFromEvents(events: ApplePodcastRssEvent[]): string {
  const collector = new ApplePodcastRssCollector();
  for (let index = 0; index < events.length; index += 1) {
    const event = events[index];
    if (event.kind === 'start' && !collector.startTag(event.name)) break;
    if (event.kind === 'text') collector.appendText(event.name, event.value ?? '');
    if (event.kind === 'attribute') collector.attribute(event.tagName ?? '', event.name, event.value ?? '');
    if (event.kind === 'end' && !collector.endTag(event.name)) break;
  }
  return collector.errorCode();
}

function applePodcastResolverErrorCode(error: Error): string {
  if (error instanceof ApplePodcastResolverError) return error.resolverCode;
  const raw = error.message.trim();
  if (raw === 'rss_audio_requires_https' || raw === 'rss_body_too_large' ||
    raw === 'rss_audio_enclosure_not_found' || raw === 'rss_empty_reply' ||
    raw === 'rss_network_failure') return raw;
  const lower = raw.toLowerCase();
  if ((lower.indexOf('response body') >= 0 && lower.indexOf('limit') >= 0) ||
    (lower.indexOf('max') >= 0 && lower.indexOf('limit') >= 0)) return 'rss_body_too_large';
  return 'rss_temporary_failure';
}

export function applePodcastResolverFailure(error: Error): ApplePodcastResolverFailure {
  const code = applePodcastResolverErrorCode(error);
  if (code === 'rss_audio_requires_https') {
    return { code: code, message: '该节目仅提供 HTTP 音频，请在来源页收听', retryable: false };
  }
  if (code === 'rss_body_too_large') {
    return { code: code, message: 'RSS 超过 10MB，资源解析失败，请在来源页收听', retryable: false };
  }
  if (code === 'rss_audio_enclosure_not_found') {
    return { code: code, message: '该节目未提供可播放音频，请在来源页收听', retryable: false };
  }
  if (code === 'rss_network_failure') {
    return { code: code, message: 'RSS 网络连接失败，可重试', retryable: true };
  }
  return { code: code, message: '播客音频加载失败，可重试', retryable: true };
}

async function requestApplePodcastRss(feedUrl: string): Promise<ArrayBuffer> {
  if (!validApplePodcastPublicHttpsUrl(feedUrl)) throw new Error('invalid_feed_url');
  const request = http.createHttp();
  try {
    let response: http.HttpResponse;
    try {
      response = await request.request(feedUrl.trim(), applePodcastRssRequestOptions());
    } catch (error) {
      const transportError = error instanceof Error ? error : new Error('rss_network_failure');
      if (applePodcastResolverErrorCode(transportError) === 'rss_body_too_large') {
        throw new ApplePodcastResolverError('rss_body_too_large');
      }
      throw new ApplePodcastResolverError('rss_network_failure');
    }
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('rss_http_' + response.responseCode.toString());
    }
    if (!(response.result instanceof ArrayBuffer)) {
      throw new ApplePodcastResolverError('rss_body_invalid');
    }
    if (!applePodcastRssBodySizeAllowed(response.result.byteLength)) {
      throw new ApplePodcastResolverError('rss_body_too_large');
    }
    return response.result;
  } finally {
    request.destroy();
  }
}

export async function resolveApplePodcastEpisode(feedUrl: string): Promise<ApplePodcastEpisodeAudio> {
  const result = rssResultFromBuffer(await requestApplePodcastRss(feedUrl));
  if (result.episode === null) throw new ApplePodcastResolverError(result.errorCode);
  return result.episode;
}

export function applePodcastPostsFromPayload(rawJson: string, limit: number = DEFAULT_RESULT_LIMIT): AggregateSearchPost[] {
  const payload = JSON.parse(rawJson) as ApplePodcastSearchPayload;
  if (payload.results === undefined || !Array.isArray(payload.results)) {
    return [];
  }
  const posts: AggregateSearchPost[] = [];
  const maxCount = resultLimit(limit);
  for (let index = 0; index < payload.results.length && posts.length < maxCount; index++) {
    const post = applePodcastPost(payload.results[index], index);
    if (post.title.length > 0 && post.url.length > 0) {
      posts.push(post);
    }
  }
  return posts;
}

function sourceStatus(status: 'success' | 'empty' | 'error', message: string, count: number): AggregateSearchSourceStatus {
  return {
    source: 'applepodcasts',
    label: APPLE_PODCAST_PROVIDER,
    status: status,
    message: message,
    count: count
  };
}

export function applePodcastBatchFromHttpResult(
  response: ApplePodcastHttpResult,
  limit: number = DEFAULT_RESULT_LIMIT
): AggregateSearchSourceBatch {
  if (response.code < 200 || response.code >= 300) {
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts HTTP ' + response.code.toString() + '。', 0),
      continuation: null
    };
  }
  try {
    const posts = applePodcastPostsFromPayload(response.text, limit);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: posts,
      status: sourceStatus(posts.length > 0 ? 'success' : 'empty',
        'Apple Podcasts 返回 ' + posts.length.toString() + ' 条节目。', posts.length),
      continuation: null
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts 响应解析失败：' + message.substring(0, 160), 0),
      continuation: null
    };
  }
}

async function requestApplePodcasts(url: string): Promise<ApplePodcastHttpResult> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'application/json'
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

export async function searchApplePodcasts(
  query: string,
  policy: AggregateSearchPolicy,
  limit: number = DEFAULT_RESULT_LIMIT
): Promise<AggregateSearchSourceBatch> {
  const trimmedQuery = query.trim();
  if (trimmedQuery.length === 0) {
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('empty', 'Apple Podcasts 查询词为空。', 0),
      continuation: null
    };
  }
  try {
    const response = await requestApplePodcasts(applePodcastsSearchUrl(
      trimmedQuery, limit, applePodcastsCountryForPolicy(policy)));
    return applePodcastBatchFromHttpResult(response, limit);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return {
      source: 'applepodcasts',
      videos: [],
      posts: [],
      status: sourceStatus('error', 'Apple Podcasts 调用失败：' + message.substring(0, 160), 0),
      continuation: null
    };
  }
}
