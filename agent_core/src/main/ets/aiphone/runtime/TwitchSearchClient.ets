import rcp from '@hms.collaboration.rcp';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from './AiphoneLogger';

const TWITCH_TOKEN_URL: string = 'https://id.twitch.tv/oauth2/token';
const TWITCH_GAMES_URL: string = 'https://api.twitch.tv/helix/games';
const TWITCH_TOP_GAMES_URL: string = 'https://api.twitch.tv/helix/games/top';
const TWITCH_STREAMS_URL: string = 'https://api.twitch.tv/helix/streams';
const DEFAULT_RESULT_LIMIT: number = 10;
const MAX_RESULT_LIMIT: number = 100;
const TOKEN_EXPIRY_SKEW_MS: number = 5 * 60 * 1000;
const TECHNOLOGY_CATEGORY_CACHE_MS: number = 24 * 60 * 60 * 1000;
const TOP_GAME_CACHE_MS: number = 10 * 60 * 1000;
const TECHNOLOGY_STREAM_LIMIT: number = 3;
const TOP_GAME_SCAN_LIMIT: number = 10;

export const TWITCH_TECHNOLOGY_CATEGORY_NAMES: string[] = [
  'Science & Technology',
  'Software and Game Development',
  'Makers & Crafting'
];

type TwitchPayloadValue = Object | string | number | boolean | null | undefined;

interface TwitchGamePayload {
  id?: string;
  name?: string;
  igdb_id?: string;
}

interface TwitchGamesPayload {
  data?: TwitchGamePayload[];
}

interface TwitchStreamPayload {
  id?: string;
  user_login?: string;
  user_name?: string;
  game_id?: string;
  game_name?: string;
  type?: string;
  title?: string;
  viewer_count?: number;
  started_at?: string;
  language?: string;
  thumbnail_url?: string;
  tags?: string[];
}

interface TwitchStreamsPayload {
  data?: TwitchStreamPayload[];
}

interface TwitchTokenPayload {
  access_token?: string;
  expires_in?: number;
}

export interface TwitchSearchConfig {
  clientId: string;
  clientSecret: string;
}

export interface TwitchInterestDiscoveryOptions {
  multilingual?: boolean;
  technologyLimit?: number;
}

export type TwitchInterestStreamKind = 'tech' | 'game';

export interface TwitchChannelSearchItem {
  id: string;
  broadcasterLogin: string;
  broadcasterName: string;
  title: string;
  gameId: string;
  gameName: string;
  language: string;
  isLive: boolean;
  thumbnailUrl: string;
  startedAt: string;
  url: string;
  tags: string[];
  viewerCount: number;
  kind: TwitchInterestStreamKind;
}

export type TwitchSearchStatus = 'success' | 'empty' | 'needs_auth' | 'unsupported' | 'error';
export type TwitchSearchReason = 'success' | 'empty' | 'disabled' | 'auth' | 'rate_limited' | 'provider_error';

export interface TwitchChannelSearchBatch {
  items: TwitchChannelSearchItem[];
  status: TwitchSearchStatus;
  reason: TwitchSearchReason;
  message: string;
  continuation: string | null;
  httpStatus: number;
  retryAfterSeconds?: number;
}

export interface TwitchHttpResult {
  code: number;
  text: string;
  retryAfterSeconds?: number;
}

export interface TwitchSearchTransport {
  get(url: string, headers: Record<string, string>): Promise<TwitchHttpResult>;
  post(url: string, headers: Record<string, string>, body: string): Promise<TwitchHttpResult>;
  close?(): Promise<void>;
}

export interface TwitchRcpResponse {
  statusCode: number;
  text: string;
  headers: Object;
}

export type TwitchRcpHttpMethod = 'GET' | 'POST';

export interface TwitchRcpSession {
  request(
    url: string,
    method: TwitchRcpHttpMethod,
    headers: Record<string, string>,
    body: string
  ): Promise<TwitchRcpResponse>;
  close(): void;
}

export interface TwitchRcpSessionFactory {
  create(): TwitchRcpSession;
}

let cachedToken: string = '';
let cachedTokenExpiresAtMs: number = 0;
let cachedTokenClientId: string = '';
let cachedTokenClientSecret: string = '';
let tokenRequestPromise: Promise<string> | null = null;
let tokenRequestClientId: string = '';
let tokenRequestClientSecret: string = '';
let cachedTechnologyCategoryIds: string[] = [];
let cachedTechnologyCategoriesExpireAtMs: number = 0;
let cachedTopGameId: string = '';
let cachedTopGameName: string = '';
let cachedTopGameExpiresAtMs: number = 0;
function textOf(value: TwitchPayloadValue): string {
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

function headerValue(headers: Object, key: string): string {
  const record = headers as Record<string, TwitchPayloadValue>;
  const lower = key.toLowerCase();
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (keys[index].toLowerCase() === lower) {
      return textOf(record[keys[index]]);
    }
  }
  return '';
}

function retryAfterSeconds(headers: Object): number | undefined {
  const resetEpochSeconds = Number(headerValue(headers, 'Ratelimit-Reset').trim());
  if (Number.isFinite(resetEpochSeconds) && resetEpochSeconds > 0) {
    return Math.max(0, Math.ceil(resetEpochSeconds - Date.now() / 1000));
  }
  const retryAfter = Number(headerValue(headers, 'Retry-After').trim());
  return Number.isFinite(retryAfter) && retryAfter >= 0 ? Math.floor(retryAfter) : undefined;
}

function normalizedLimit(value: number | undefined): number {
  if (value === undefined || !Number.isFinite(value)) {
    return DEFAULT_RESULT_LIMIT;
  }
  return Math.max(1, Math.min(MAX_RESULT_LIMIT, Math.floor(value)));
}

export function twitchAppTokenUrl(): string {
  return TWITCH_TOKEN_URL;
}

function encodedQuery(params: string[][]): string {
  return params.map((pair: string[]): string =>
    encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

export function twitchGamesUrl(names: string[]): string {
  const params: string[][] = [];
  names.forEach((name: string): void => {
    const clean = name.trim();
    if (clean.length > 0) {
      params.push(['name', clean]);
    }
  });
  return params.length > 0 ? TWITCH_GAMES_URL + '?' + encodedQuery(params) : TWITCH_GAMES_URL;
}

export function twitchTopGamesUrl(limit: number = TOP_GAME_SCAN_LIMIT): string {
  return TWITCH_TOP_GAMES_URL + '?first=' + normalizedLimit(limit).toString();
}

export function twitchStreamsUrl(
  gameIds: string[],
  limit: number,
  multilingual: boolean
): string {
  const params: string[][] = [['first', normalizedLimit(limit).toString()]];
  gameIds.forEach((gameId: string): void => {
    const clean = gameId.trim();
    if (clean.length > 0) {
      params.push(['game_id', clean]);
    }
  });
  if (!multilingual) {
    params.push(['language', 'zh']);
  }
  return TWITCH_STREAMS_URL + '?' + encodedQuery(params);
}

export function twitchHelixHeaders(clientId: string, accessToken: string): Record<string, string> {
  return {
    'Accept': 'application/json',
    'Client-Id': clientId.trim(),
    'Authorization': 'Bearer ' + accessToken.trim()
  };
}

function twitchChannelUrl(login: string): string {
  return login.length > 0 ? 'https://www.twitch.tv/' + encodeURIComponent(login) : 'https://www.twitch.tv/';
}

function normalizedTags(value: string[] | undefined): string[] {
  if (value === undefined || !Array.isArray(value)) {
    return [];
  }
  const tags: string[] = [];
  value.forEach((tag: string): void => {
    const trimmed = tag.trim();
    if (trimmed.length > 0 && tags.indexOf(trimmed) < 0) {
      tags.push(trimmed);
    }
  });
  return tags;
}

function streamFromPayload(item: TwitchStreamPayload, kind: TwitchInterestStreamKind): TwitchChannelSearchItem | null {
  const id = textOf(item.id).trim();
  const login = textOf(item.user_login).trim();
  const displayName = textOf(item.user_name).trim();
  if (id.length === 0 || (login.length === 0 && displayName.length === 0) || textOf(item.type).trim() !== 'live') {
    return null;
  }
  const rawViewerCount = Number(item.viewer_count);
  return {
    id: id,
    broadcasterLogin: login,
    broadcasterName: displayName.length > 0 ? displayName : login,
    title: textOf(item.title).trim(),
    gameId: textOf(item.game_id).trim(),
    gameName: textOf(item.game_name).trim(),
    language: textOf(item.language).trim().toLowerCase(),
    isLive: true,
    thumbnailUrl: textOf(item.thumbnail_url).trim().replace('{width}', '640').replace('{height}', '360'),
    startedAt: textOf(item.started_at).trim(),
    url: twitchChannelUrl(login),
    tags: normalizedTags(item.tags),
    viewerCount: Number.isFinite(rawViewerCount) && rawViewerCount >= 0 ? Math.floor(rawViewerCount) : 0,
    kind: kind
  };
}

function streamsFromPayload(rawJson: string, kind: TwitchInterestStreamKind): TwitchChannelSearchItem[] {
  const payload = JSON.parse(rawJson) as TwitchStreamsPayload;
  const rawItems = payload.data !== undefined && Array.isArray(payload.data) ? payload.data : [];
  const items: TwitchChannelSearchItem[] = [];
  rawItems.forEach((rawItem: TwitchStreamPayload): void => {
    const item = streamFromPayload(rawItem, kind);
    if (item !== null) {
      items.push(item);
    }
  });
  items.sort((left: TwitchChannelSearchItem, right: TwitchChannelSearchItem): number =>
    right.viewerCount - left.viewerCount || left.id.localeCompare(right.id));
  return items;
}

function gamesFromPayload(rawJson: string): TwitchGamePayload[] {
  const payload = JSON.parse(rawJson) as TwitchGamesPayload;
  return payload.data !== undefined && Array.isArray(payload.data) ? payload.data : [];
}

function failedBatch(
  status: TwitchSearchStatus,
  reason: TwitchSearchReason,
  message: string,
  httpStatus: number,
  retryAfter: number | undefined = undefined
): TwitchChannelSearchBatch {
  const batch: TwitchChannelSearchBatch = {
    items: [], status: status, reason: reason, message: message,
    continuation: null, httpStatus: httpStatus
  };
  if (retryAfter !== undefined) {
    batch.retryAfterSeconds = retryAfter;
  }
  return batch;
}

class SystemTwitchRcpSession implements TwitchRcpSession {
  private readonly session: rcp.Session = rcp.createSession();

  async request(
    url: string,
    method: TwitchRcpHttpMethod,
    headers: Record<string, string>,
    body: string
  ): Promise<TwitchRcpResponse> {
    const request = new rcp.Request(url, method, headers);
    if (body.length > 0) {
      request.content = body;
    }
    request.configuration = {
      transfer: {
        timeout: {
          connectMs: 10000,
          transferMs: 30000,
          inactivityMs: 30000
        }
      }
    };
    const response = await this.session.fetch(request);
    const responseBody = response.toString();
    return {
      statusCode: response.statusCode,
      text: responseBody === null ? '' : responseBody,
      headers: response.headers
    };
  }

  close(): void {
    this.session.close();
  }
}

class SystemTwitchRcpSessionFactory implements TwitchRcpSessionFactory {
  create(): TwitchRcpSession {
    return new SystemTwitchRcpSession();
  }
}

export class DefaultTwitchSearchTransport implements TwitchSearchTransport {
  private readonly sessionFactory: TwitchRcpSessionFactory;
  private session: TwitchRcpSession | null = null;

  constructor(sessionFactory: TwitchRcpSessionFactory = new SystemTwitchRcpSessionFactory()) {
    this.sessionFactory = sessionFactory;
  }

  async get(url: string, headers: Record<string, string>): Promise<TwitchHttpResult> {
    return this.request(url, 'GET', headers, '');
  }

  async post(url: string, headers: Record<string, string>, body: string): Promise<TwitchHttpResult> {
    return this.request(url, 'POST', headers, body);
  }

  async close(): Promise<void> {
    const session = this.session;
    this.session = null;
    if (session !== null) {
      session.close();
    }
  }

  private operationSession(): TwitchRcpSession {
    if (this.session === null) {
      this.session = this.sessionFactory.create();
    }
    return this.session;
  }

  private async request(
    url: string,
    method: TwitchRcpHttpMethod,
    headers: Record<string, string>,
    body: string
  ): Promise<TwitchHttpResult> {
    const session = this.operationSession();
    const startedAtMs = Date.now();
    const host = url.indexOf(TWITCH_TOKEN_URL) === 0 ? 'id.twitch.tv' : 'api.twitch.tv';
    let phase = host === 'id.twitch.tv' ? 'oauth-token' : 'helix';
    if (host === 'api.twitch.tv') {
      if (url.indexOf('/helix/games/top') >= 0) {
        phase = 'helix-top-games';
      } else if (url.indexOf('/helix/games') >= 0) {
        phase = 'helix-games';
      } else if (url.indexOf('/helix/streams') >= 0) {
        phase = 'helix-streams';
      }
    }
    const methodLabel = method === 'POST' ? 'POST' : 'GET';
    try {
      const response = await session.request(url, method, headers, body);
      const httpOk = response.statusCode >= 200 && response.statusCode < 300;
      const httpLog = '[AIPhone][TwitchHttp] ok=' + (httpOk ? 'true' : 'false') +
        ' phase=' + phase + ' host=' + host + ' method=' + methodLabel +
        ' status=' + response.statusCode.toString() +
        ' elapsedMs=' + (Date.now() - startedAtMs).toString();
      if (httpOk) {
        aiLogInfo(httpLog);
      } else {
        aiLogError(httpLog);
      }
      return {
        code: response.statusCode,
        text: response.text,
        retryAfterSeconds: retryAfterSeconds(response.headers)
      };
    } catch (error) {
      const businessError = error as BusinessError;
      const code = businessError.code === undefined || businessError.code === null ?
        'unknown' : businessError.code.toString();
      const rawMessage = businessError.message !== undefined ? businessError.message :
        (error instanceof Error ? error.message : 'unknown');
      const lowerMessage = rawMessage.toLowerCase();
      const containsSensitiveMarker = lowerMessage.indexOf('client_secret') >= 0 ||
        lowerMessage.indexOf('access_token') >= 0 || lowerMessage.indexOf('authorization') >= 0 ||
        lowerMessage.indexOf('bearer ') >= 0;
      const safeMessage = containsSensitiveMarker ? '<redacted>' :
        rawMessage.replace(/https?:\/\/[^\s]*/gi, '<url>').substring(0, 160);
      aiLogError('[AIPhone][TwitchHttp] ok=false phase=' + phase + ' host=' + host +
        ' method=' + methodLabel + ' code=' + code +
        ' elapsedMs=' + (Date.now() - startedAtMs).toString() + ' message=' + safeMessage);
      throw new Error(safeMessage);
    }
  }
}

function tokenMatches(config: TwitchSearchConfig): boolean {
  return cachedTokenClientId === config.clientId.trim() && cachedTokenClientSecret === config.clientSecret.trim();
}

function invalidateTwitchToken(accessToken: string = ''): void {
  if (accessToken.length > 0 && cachedToken !== accessToken) {
    return;
  }
  cachedToken = '';
  cachedTokenExpiresAtMs = 0;
  cachedTokenClientId = '';
  cachedTokenClientSecret = '';
}

export function resetTwitchTokenCacheForTests(): void {
  invalidateTwitchToken();
  tokenRequestPromise = null;
  tokenRequestClientId = '';
  tokenRequestClientSecret = '';
  cachedTechnologyCategoryIds = [];
  cachedTechnologyCategoriesExpireAtMs = 0;
  cachedTopGameId = '';
  cachedTopGameName = '';
  cachedTopGameExpiresAtMs = 0;
}

async function mintTwitchAppToken(
  config: TwitchSearchConfig,
  transport: TwitchSearchTransport,
  nowMs: number
): Promise<string> {
  const body = 'client_id=' + encodeURIComponent(config.clientId.trim()) +
    '&client_secret=' + encodeURIComponent(config.clientSecret.trim()) + '&grant_type=client_credentials';
  const response = await transport.post(twitchAppTokenUrl(), {
    'Accept': 'application/json',
    'Content-Type': 'application/x-www-form-urlencoded'
  }, body);
  if (response.code < 200 || response.code >= 300) {
    throw new Error('Twitch app token request failed with HTTP ' + response.code.toString() + '.');
  }
  let payload: TwitchTokenPayload;
  try {
    payload = JSON.parse(response.text) as TwitchTokenPayload;
  } catch (_error) {
    throw new Error('Twitch app token response was not valid JSON.');
  }
  const accessToken = textOf(payload.access_token).trim();
  const expiresInSeconds = Number(payload.expires_in);
  if (accessToken.length === 0 || !Number.isFinite(expiresInSeconds) || expiresInSeconds <= 0) {
    throw new Error('Twitch app token response was missing access_token or expires_in.');
  }
  const lifetimeMs = Math.floor(expiresInSeconds * 1000);
  const skewMs = Math.min(TOKEN_EXPIRY_SKEW_MS, Math.max(1000, Math.floor(lifetimeMs / 10)));
  cachedToken = accessToken;
  cachedTokenExpiresAtMs = nowMs + Math.max(0, lifetimeMs - skewMs);
  cachedTokenClientId = config.clientId.trim();
  cachedTokenClientSecret = config.clientSecret.trim();
  return accessToken;
}

export async function acquireTwitchAppToken(
  config: TwitchSearchConfig,
  transport: TwitchSearchTransport,
  nowMs: number = Date.now()
): Promise<string> {
  if (tokenMatches(config) && cachedToken.length > 0 && nowMs < cachedTokenExpiresAtMs) {
    return cachedToken;
  }
  const clientId = config.clientId.trim();
  const clientSecret = config.clientSecret.trim();
  if (tokenRequestPromise !== null && tokenRequestClientId === clientId &&
    tokenRequestClientSecret === clientSecret) {
    return tokenRequestPromise;
  }
  const pending = mintTwitchAppToken(config, transport, nowMs);
  tokenRequestPromise = pending;
  tokenRequestClientId = clientId;
  tokenRequestClientSecret = clientSecret;
  try {
    return await pending;
  } finally {
    if (tokenRequestPromise === pending) {
      tokenRequestPromise = null;
      tokenRequestClientId = '';
      tokenRequestClientSecret = '';
    }
  }
}

interface TwitchDiscoveryOperationResult {
  batch: TwitchChannelSearchBatch;
  resolvedTechnologyCategoryIds: string[];
  resolvedTopGameId: string;
  resolvedTopGameName: string;
}

function discoveryOperationResult(batch: TwitchChannelSearchBatch): TwitchDiscoveryOperationResult {
  return {
    batch: batch,
    resolvedTechnologyCategoryIds: [],
    resolvedTopGameId: '',
    resolvedTopGameName: ''
  };
}

function helixFailure(response: TwitchHttpResult, phase: string): TwitchChannelSearchBatch | null {
  if (response.code >= 200 && response.code < 300) {
    return null;
  }
  if (response.code === 401) {
    return failedBatch('needs_auth', 'auth',
      'Twitch ' + phase + ' 请求的 app access token 被 Helix 拒绝。', response.code);
  }
  if (response.code === 429) {
    const suffix = response.retryAfterSeconds === undefined ? '' :
      '，建议 ' + response.retryAfterSeconds.toString() + ' 秒后重试';
    return failedBatch('error', 'rate_limited',
      'Twitch ' + phase + ' 请求达到速率限制' + suffix + '。', response.code, response.retryAfterSeconds);
  }
  return failedBatch('error', 'provider_error',
    'Twitch ' + phase + ' 请求返回 HTTP ' + response.code.toString() + '。', response.code);
}

async function discoveryGet(
  transport: TwitchSearchTransport,
  url: string,
  headers: Record<string, string>,
  phase: string
): Promise<TwitchHttpResult> {
  try {
    return await transport.get(url, headers);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    throw new Error('Twitch ' + phase + ' 请求失败：' + message.substring(0, 160));
  }
}

function uniqueStreamItems(
  technologyItems: TwitchChannelSearchItem[],
  gameItems: TwitchChannelSearchItem[]
): TwitchChannelSearchItem[] {
  const items: TwitchChannelSearchItem[] = [];
  const seenIds: string[] = [];
  const seenUrls: string[] = [];
  technologyItems.concat(gameItems).forEach((item: TwitchChannelSearchItem): void => {
    const normalizedUrl = item.url.trim().toLowerCase();
    if (seenIds.indexOf(item.id) >= 0 || (normalizedUrl.length > 0 && seenUrls.indexOf(normalizedUrl) >= 0)) {
      return;
    }
    seenIds.push(item.id);
    if (normalizedUrl.length > 0) {
      seenUrls.push(normalizedUrl);
    }
    items.push(item);
  });
  return items;
}

async function executeTwitchInterestDiscovery(
  clientId: string,
  accessToken: string,
  options: TwitchInterestDiscoveryOptions,
  transport: TwitchSearchTransport,
  nowMs: number,
  forceRefresh: boolean
): Promise<TwitchDiscoveryOperationResult> {
  const headers = twitchHelixHeaders(clientId, accessToken);
  const multilingual = options.multilingual === true;
  const technologyLimit = options.technologyLimit === undefined ? TECHNOLOGY_STREAM_LIMIT :
    Math.max(1, Math.min(10, Math.floor(options.technologyLimit)));
  let technologyCategoryIds = !forceRefresh && nowMs < cachedTechnologyCategoriesExpireAtMs ?
    cachedTechnologyCategoryIds.slice() : [];
  let resolvedTechnologyCategoryIds: string[] = [];
  let resolvedTopGameId = '';
  let resolvedTopGameName = '';
  let technologyItems: TwitchChannelSearchItem[] = [];
  let gameItems: TwitchChannelSearchItem[] = [];
  let technologyFailure: TwitchChannelSearchBatch | null = null;
  let gameFailure: TwitchChannelSearchBatch | null = null;
  let technologyCategoryDetail = '';

  if (technologyCategoryIds.length === 0) {
    try {
      const response = await discoveryGet(
        transport, twitchGamesUrl(TWITCH_TECHNOLOGY_CATEGORY_NAMES), headers, '科技分类解析');
      const failure = helixFailure(response, '科技分类解析');
      if (failure !== null) {
        if (failure.httpStatus === 401) return discoveryOperationResult(failure);
        technologyFailure = failure;
      } else {
        try {
          const games = gamesFromPayload(response.text);
          games.forEach((game: TwitchGamePayload): void => {
            const id = textOf(game.id).trim();
            if (id.length > 0 && technologyCategoryIds.indexOf(id) < 0) {
              technologyCategoryIds.push(id);
            }
          });
          resolvedTechnologyCategoryIds = technologyCategoryIds.slice();
          technologyCategoryDetail = '科技分类解析 ' + technologyCategoryIds.length.toString() + '/' +
            TWITCH_TECHNOLOGY_CATEGORY_NAMES.length.toString();
        } catch (error) {
          const message = error instanceof Error ? error.message : JSON.stringify(error);
          technologyFailure = failedBatch('error', 'provider_error',
            'Twitch 科技分类响应解析失败：' + message.substring(0, 160), response.code);
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      technologyFailure = failedBatch('error', 'provider_error', message.substring(0, 200), 0);
    }
  } else {
    technologyCategoryDetail = '科技分类缓存命中 ' + technologyCategoryIds.length.toString();
  }
  if (technologyCategoryIds.length > 0 && technologyFailure === null) {
    try {
      const technologyResponse = await discoveryGet(
        transport, twitchStreamsUrl(technologyCategoryIds, technologyLimit, multilingual), headers, '科技直播');
      const failure = helixFailure(technologyResponse, '科技直播');
      if (failure !== null) {
        if (failure.httpStatus === 401) return discoveryOperationResult(failure);
        technologyFailure = failure;
      } else {
        try {
          technologyItems = streamsFromPayload(technologyResponse.text, 'tech').slice(0, technologyLimit);
        } catch (error) {
          const message = error instanceof Error ? error.message : JSON.stringify(error);
          technologyFailure = failedBatch('error', 'provider_error',
            'Twitch 科技直播响应解析失败：' + message.substring(0, 160), technologyResponse.code);
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      technologyFailure = failedBatch('error', 'provider_error', message.substring(0, 200), 0);
    }
  } else if (technologyCategoryIds.length === 0 && technologyFailure === null) {
    technologyCategoryDetail = '未解析到科技分类';
  }

  let topGameId = !forceRefresh && nowMs < cachedTopGameExpiresAtMs ? cachedTopGameId : '';
  let topGameName = topGameId.length > 0 ? cachedTopGameName : '';
  if (topGameId.length === 0) {
    try {
      const topGamesResponse = await discoveryGet(
        transport, twitchTopGamesUrl(TOP_GAME_SCAN_LIMIT), headers, '热门游戏');
      const failure = helixFailure(topGamesResponse, '热门游戏');
      if (failure !== null) {
        if (failure.httpStatus === 401) return discoveryOperationResult(failure);
        gameFailure = failure;
      } else {
        try {
          const games = gamesFromPayload(topGamesResponse.text).filter((game: TwitchGamePayload): boolean =>
            textOf(game.id).trim().length > 0);
          // igdb_id is an engineering heuristic for a playable game, not a Twitch API category guarantee.
          const actualGames = games.filter((game: TwitchGamePayload): boolean =>
            textOf(game.igdb_id).trim().length > 0);
          const selected = actualGames.length > 0 ? actualGames[0] : (games.length > 0 ? games[0] : undefined);
          if (selected !== undefined) {
            topGameId = textOf(selected.id).trim();
            topGameName = textOf(selected.name).trim();
            resolvedTopGameId = topGameId;
            resolvedTopGameName = topGameName;
          }
        } catch (error) {
          const message = error instanceof Error ? error.message : JSON.stringify(error);
          gameFailure = failedBatch('error', 'provider_error',
            'Twitch 热门游戏响应解析失败：' + message.substring(0, 160), topGamesResponse.code);
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      gameFailure = failedBatch('error', 'provider_error', message.substring(0, 200), 0);
    }
  }

  if (topGameId.length > 0 && gameFailure === null) {
    try {
      const gameResponse = await discoveryGet(
        transport, twitchStreamsUrl([topGameId], 1, multilingual), headers, '热门游戏直播');
      const failure = helixFailure(gameResponse, '热门游戏直播');
      if (failure !== null) {
        if (failure.httpStatus === 401) return discoveryOperationResult(failure);
        gameFailure = failure;
      } else {
        try {
          gameItems = streamsFromPayload(gameResponse.text, 'game').slice(0, 1);
        } catch (error) {
          const message = error instanceof Error ? error.message : JSON.stringify(error);
          gameFailure = failedBatch('error', 'provider_error',
            'Twitch 热门游戏直播响应解析失败：' + message.substring(0, 160), gameResponse.code);
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      gameFailure = failedBatch('error', 'provider_error', message.substring(0, 200), 0);
    }
  }

  const items = uniqueStreamItems(technologyItems, gameItems);
  const topGameDetail = topGameName.length > 0 ? '，热门游戏为 ' + topGameName : '，热门游戏目录为空';
  const failures: TwitchChannelSearchBatch[] = [];
  if (technologyFailure !== null) failures.push(technologyFailure);
  if (gameFailure !== null) failures.push(gameFailure);
  const failureDetail = failures.length > 0 ? ' 部分分支失败：' +
    failures.map((failure: TwitchChannelSearchBatch): string => failure.message).join('；') : '';
  let status: TwitchSearchStatus = items.length > 0 ? 'success' : 'empty';
  let reason: TwitchSearchReason = items.length > 0 ? 'success' : 'empty';
  let httpStatus = 200;
  let retryAfter: number | undefined = undefined;
  if (items.length === 0 && failures.length > 0) {
    status = 'error';
    const rateLimited = failures.filter((failure: TwitchChannelSearchBatch): boolean =>
      failure.reason === 'rate_limited');
    reason = rateLimited.length > 0 ? 'rate_limited' : 'provider_error';
    httpStatus = failures[0].httpStatus;
    retryAfter = rateLimited.length > 0 ? rateLimited[0].retryAfterSeconds : undefined;
  }
  const batch: TwitchChannelSearchBatch = {
    items: items,
    status: status,
    reason: reason,
    message: 'Twitch 发现流返回科技直播 ' + technologyItems.length.toString() + ' 条、游戏直播 ' +
      gameItems.length.toString() + ' 条，' + technologyCategoryDetail + topGameDetail + '。' + failureDetail,
    continuation: null,
    httpStatus: httpStatus
  };
  if (retryAfter !== undefined) batch.retryAfterSeconds = retryAfter;
  return {
    batch: batch,
    resolvedTechnologyCategoryIds: resolvedTechnologyCategoryIds,
    resolvedTopGameId: resolvedTopGameId,
    resolvedTopGameName: resolvedTopGameName
  };
}

function commitDiscoveryCaches(result: TwitchDiscoveryOperationResult, nowMs: number): void {
  if (result.resolvedTechnologyCategoryIds.length > 0) {
    cachedTechnologyCategoryIds = result.resolvedTechnologyCategoryIds.slice();
    cachedTechnologyCategoriesExpireAtMs = nowMs + TECHNOLOGY_CATEGORY_CACHE_MS;
  }
  if (result.resolvedTopGameId.length > 0) {
    cachedTopGameId = result.resolvedTopGameId;
    cachedTopGameName = result.resolvedTopGameName;
    cachedTopGameExpiresAtMs = nowMs + TOP_GAME_CACHE_MS;
  }
}

/**
 * Host-driven Twitch discovery for the interest feed. It intentionally has no
 * query argument: technology categories and the hottest current game are
 * resolved through Helix and cached inside this provider.
 */
async function discoverTwitchInterestStreamsWithoutClosing(
  config: TwitchSearchConfig,
  options: TwitchInterestDiscoveryOptions,
  transport: TwitchSearchTransport,
  nowMs: number
): Promise<TwitchChannelSearchBatch> {
  const clientId = config.clientId.trim();
  const clientSecret = config.clientSecret.trim();
  if (clientId.length === 0 || clientSecret.length === 0) {
    const missing: string[] = [];
    if (clientId.length === 0) missing.push('TWITCH_CLIENT_ID');
    if (clientSecret.length === 0) missing.push('TWITCH_CLIENT_SECRET');
    return failedBatch('unsupported', 'disabled',
      'Twitch 来源已禁用：缺少 ' + missing.join(' / ') + '；未发起网络请求。', 0);
  }
  const normalizedConfig: TwitchSearchConfig = { clientId: clientId, clientSecret: clientSecret };
  let accessToken: string;
  try {
    accessToken = await acquireTwitchAppToken(normalizedConfig, transport, nowMs);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return failedBatch('needs_auth', 'auth',
      'Twitch app access token 获取失败：' + message.substring(0, 160), 0);
  }
  let result: TwitchDiscoveryOperationResult;
  try {
    result = await executeTwitchInterestDiscovery(clientId, accessToken, options, transport, nowMs, false);
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    return failedBatch('error', 'provider_error', message.substring(0, 200), 0);
  }
  if (result.batch.httpStatus === 401) {
    invalidateTwitchToken(accessToken);
    try {
      accessToken = await acquireTwitchAppToken(normalizedConfig, transport, nowMs);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      return failedBatch('needs_auth', 'auth',
        'Twitch app access token 刷新失败：' + message.substring(0, 160), 0);
    }
    try {
      result = await executeTwitchInterestDiscovery(clientId, accessToken, options, transport, nowMs, true);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      return failedBatch('error', 'provider_error',
        'Twitch Helix 刷新令牌后重试失败：' + message.substring(0, 160), 0);
    }
  }
  if (result.batch.status === 'success' || result.batch.status === 'empty') {
    commitDiscoveryCaches(result, nowMs);
  }
  return result.batch;
}

async function closeTwitchSearchTransport(transport: TwitchSearchTransport): Promise<void> {
  if (transport.close === undefined) {
    return;
  }
  try {
    await transport.close();
  } catch (_error) {
    aiLogError('[AIPhone][TwitchHttp] transport close failed');
  }
}

export async function discoverTwitchInterestStreams(
  config: TwitchSearchConfig,
  options: TwitchInterestDiscoveryOptions = {},
  transport: TwitchSearchTransport = new DefaultTwitchSearchTransport(),
  nowMs: number = Date.now()
): Promise<TwitchChannelSearchBatch> {
  try {
    return await discoverTwitchInterestStreamsWithoutClosing(config, options, transport, nowMs);
  } finally {
    await closeTwitchSearchTransport(transport);
  }
}
