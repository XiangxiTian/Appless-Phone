import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import {
  McpToolCallResult,
  McpToolContentItem,
  McpToolResultPayload,
  parseMcpJsonRpcResponse
} from './GenericMcpClient';

export type DoubanPublicMediaKind = 'book' | 'movie' | 'music';
export type DoubanPublicSearchStatus = 'success' | 'empty' | 'disabled' | 'needs_auth' | 'error';

export interface DoubanPlaywrightMcpConfig {
  /** Remote official Playwright MCP Streamable HTTP endpoint. */
  mcpUrl: string;
  /** Optional bearer token enforced by the user's cloud ingress. */
  bearerToken: string;
}

export interface DoubanPublicSearchRequest {
  query: string;
  kinds: DoubanPublicMediaKind[];
  limit: number;
  start: number;
}

export interface DoubanPublicSearchItem {
  id: string;
  kind: DoubanPublicMediaKind;
  title: string;
  url: string;
  imageUrl: string;
  rating: string;
  ratingCount: string;
  summary: string;
  metadata: string;
}

export interface DoubanPublicSearchResult {
  status: DoubanPublicSearchStatus;
  items: DoubanPublicSearchItem[];
  message: string;
  rawPreview: string;
}

export interface DoubanPlaywrightMcpSessionStart {
  ok: boolean;
  httpStatus: number;
  sessionId: string;
  errorMessage: string;
}

export interface DoubanPlaywrightMcpTransport {
  initialize(config: DoubanPlaywrightMcpConfig): Promise<DoubanPlaywrightMcpSessionStart>;
  notifyInitialized(config: DoubanPlaywrightMcpConfig, sessionId: string): Promise<void>;
  callTool(
    config: DoubanPlaywrightMcpConfig,
    sessionId: string,
    toolName: string,
    args: DoubanPlaywrightToolArgs
  ): Promise<McpToolCallResult>;
}

export interface DoubanBrowserNavigateArgs {
  url: string;
}

export interface DoubanBrowserEvaluateArgs {
  function: string;
}

export class DoubanEmptyToolArgs {}

export type DoubanPlaywrightToolArgs = DoubanBrowserNavigateArgs | DoubanBrowserEvaluateArgs | DoubanEmptyToolArgs;

interface DoubanHttpResponse {
  status: number;
  text: string;
  sessionId: string;
}

interface DoubanProviderItem {
  id?: string;
  kind?: string;
  title?: string;
  url?: string;
  imageUrl?: string;
  rating?: string | number;
  ratingCount?: string | number;
  summary?: string;
  metadata?: string;
}

interface DoubanKindDefinition {
  kind: DoubanPublicMediaKind;
  searchUrl: string;
  category: string;
  subjectHost: string;
}

interface DoubanMcpInitializeRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: DoubanMcpInitializeParams;
}

interface DoubanMcpNotification {
  jsonrpc: string;
  method: string;
  params: DoubanEmptyMcpParams;
}

interface DoubanMcpToolRequest {
  jsonrpc: string;
  id: number;
  method: string;
  params: DoubanMcpToolParams;
}

class DoubanEmptyMcpCapabilities {}

class DoubanEmptyMcpParams {}

interface DoubanMcpClientInfo {
  name: string;
  version: string;
}

interface DoubanMcpInitializeParams {
  protocolVersion: string;
  capabilities: DoubanEmptyMcpCapabilities;
  clientInfo: DoubanMcpClientInfo;
}

interface DoubanMcpToolParams {
  name: string;
  arguments: DoubanPlaywrightToolArgs;
}

type DoubanMcpRequest = DoubanMcpInitializeRequest | DoubanMcpNotification | DoubanMcpToolRequest;

const MCP_PROTOCOL_VERSION: string = '2025-06-18';
const MCP_READ_TIMEOUT_MS: number = 45000;
const DOUBAN_KINDS: DoubanKindDefinition[] = [
  {
    kind: 'book',
    searchUrl: 'https://search.douban.com/book/subject_search',
    category: '1001',
    subjectHost: 'book.douban.com'
  },
  {
    kind: 'movie',
    searchUrl: 'https://search.douban.com/movie/subject_search',
    category: '1002',
    subjectHost: 'movie.douban.com'
  },
  {
    kind: 'music',
    searchUrl: 'https://search.douban.com/music/subject_search',
    category: '1003',
    subjectHost: 'music.douban.com'
  }
];

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

function responseText(value: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof value === 'string') {
    return value;
  }
  if (value instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(value));
  }
  return textOf(value);
}

function headerValue(headers: Object, name: string): string {
  const record = headers as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (keys[index].toLowerCase() === name.toLowerCase()) {
      return textOf(record[keys[index]]).trim();
    }
  }
  return '';
}

async function postMcp(
  config: DoubanPlaywrightMcpConfig,
  sessionId: string,
  body: DoubanMcpRequest
): Promise<DoubanHttpResponse> {
  const request = http.createHttp();
  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      'MCP-Protocol-Version': MCP_PROTOCOL_VERSION
    };
    if (sessionId.length > 0) {
      headers['Mcp-Session-Id'] = sessionId;
    }
    if (config.bearerToken.trim().length > 0) {
      headers.Authorization = 'Bearer ' + config.bearerToken.trim();
    }
    const response = await request.request(config.mcpUrl.trim(), {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: JSON.stringify(body),
      connectTimeout: 10000,
      readTimeout: MCP_READ_TIMEOUT_MS
    });
    return {
      status: response.responseCode,
      text: responseText(response.result),
      sessionId: headerValue(response.header, 'Mcp-Session-Id') || sessionId
    };
  } finally {
    request.destroy();
  }
}

class NetworkDoubanPlaywrightMcpTransport implements DoubanPlaywrightMcpTransport {
  async initialize(config: DoubanPlaywrightMcpConfig): Promise<DoubanPlaywrightMcpSessionStart> {
    const body: DoubanMcpInitializeRequest = {
      jsonrpc: '2.0',
      id: 1,
      method: 'initialize',
      params: {
        protocolVersion: MCP_PROTOCOL_VERSION,
        capabilities: new DoubanEmptyMcpCapabilities(),
        clientInfo: { name: 'pocketagent-douban-playwright-demo', version: '0.1.0' }
      }
    };
    const response = await postMcp(config, '', body);
    const parsed = parseMcpJsonRpcResponse(response.text);
    const ok = response.status >= 200 && response.status < 300 && parsed.ok && response.sessionId.length > 0;
    return {
      ok: ok,
      httpStatus: response.status,
      sessionId: response.sessionId,
      errorMessage: parsed.errorMessage.length > 0 ? parsed.errorMessage :
        (ok ? '' : (response.sessionId.length === 0 ? 'Playwright MCP 未返回 Mcp-Session-Id。' :
          'Playwright MCP initialize HTTP ' + response.status.toString()))
    };
  }

  async notifyInitialized(config: DoubanPlaywrightMcpConfig, sessionId: string): Promise<void> {
    const body: DoubanMcpNotification = {
      jsonrpc: '2.0',
      method: 'notifications/initialized',
      params: new DoubanEmptyMcpParams()
    };
    await postMcp(config, sessionId, body);
  }

  async callTool(
    config: DoubanPlaywrightMcpConfig,
    sessionId: string,
    toolName: string,
    args: DoubanPlaywrightToolArgs
  ): Promise<McpToolCallResult> {
    const body: DoubanMcpToolRequest = {
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: { name: toolName, arguments: args }
    };
    const response = await postMcp(config, sessionId, body);
    const parsed = parseMcpJsonRpcResponse(response.text);
    if (response.status < 200 || response.status >= 300 || !parsed.ok || parsed.result === null) {
      return {
        ok: false,
        httpStatus: response.status,
        errorMessage: parsed.errorMessage.length > 0 ? parsed.errorMessage :
          'Playwright MCP ' + toolName + ' HTTP ' + response.status.toString(),
        result: null,
        rawPreview: response.text.substring(0, 1200)
      };
    }
    return {
      ok: true,
      httpStatus: response.status,
      errorMessage: '',
      result: parsed.result,
      rawPreview: response.text.substring(0, 1200)
    };
  }
}

function isDoubanKind(value: string): boolean {
  return value === 'book' || value === 'movie' || value === 'music';
}

function kindDefinition(kind: DoubanPublicMediaKind): DoubanKindDefinition {
  for (let index = 0; index < DOUBAN_KINDS.length; index++) {
    if (DOUBAN_KINDS[index].kind === kind) {
      return DOUBAN_KINDS[index];
    }
  }
  return DOUBAN_KINDS[0];
}

function normalizedKinds(kinds: DoubanPublicMediaKind[]): DoubanPublicMediaKind[] {
  const result: DoubanPublicMediaKind[] = [];
  kinds.forEach((kind: DoubanPublicMediaKind): void => {
    if (isDoubanKind(kind) && result.indexOf(kind) < 0) {
      result.push(kind);
    }
  });
  return result.length > 0 ? result : ['book', 'movie', 'music'];
}

export function normalizeDoubanPublicSearchRequest(request: DoubanPublicSearchRequest): DoubanPublicSearchRequest {
  return {
    query: request.query.trim().substring(0, 120),
    kinds: normalizedKinds(request.kinds),
    limit: Math.max(1, Math.min(15, Math.floor(request.limit))),
    start: Math.max(0, Math.min(150, Math.floor(request.start)))
  };
}

export function doubanPublicSearchUrl(
  kind: DoubanPublicMediaKind,
  query: string,
  start: number
): string {
  const definition = kindDefinition(kind);
  const page = start > 0 ? '&start=' + encodeURIComponent(start.toString()) : '';
  return definition.searchUrl + '?search_text=' + encodeURIComponent(query.trim()) +
    '&cat=' + definition.category + page;
}

export function doubanBrowserEvaluateFunction(
  kind: DoubanPublicMediaKind,
  limit: number
): string {
  const definition = kindDefinition(kind);
  const boundedLimit = Math.max(1, Math.min(15, Math.floor(limit)));
  return `async () => {
    const deadline = Date.now() + 8000;
    while (document.querySelectorAll('.item-root').length === 0 && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
    return JSON.stringify(Array.from(document.querySelectorAll('.item-root')).slice(0, ${boundedLimit}).map((root, index) => {
    const titleAnchor = root.querySelector('a.title-text') || root.querySelector('.title a') || root.querySelector('a[href*="douban.com/subject/"]');
    const anchors = Array.from(root.querySelectorAll('a[href]'));
    const subjectAnchor = anchors.find((anchor) => {
      try { return new URL(anchor.href).hostname === '${definition.subjectHost}' && anchor.href.includes('/subject/'); } catch (_) { return false; }
    }) || titleAnchor;
    const image = root.querySelector('img');
    const rating = root.querySelector('.rating_nums');
    const ratingCount = root.querySelector('.pl');
    const metadata = root.querySelector('.meta.abstract') || root.querySelector('.meta');
    const title = (titleAnchor?.textContent || '').trim();
    const url = subjectAnchor?.href || '';
    const idMatch = url.match(/\\/subject\\/(\\d+)/);
    return {
      id: idMatch ? 'douban-${kind}-' + idMatch[1] : 'douban-${kind}-' + index,
      kind: '${kind}',
      title,
      url,
      imageUrl: image?.currentSrc || image?.src || '',
      rating: (rating?.textContent || '').trim(),
      ratingCount: (ratingCount?.textContent || '').replace(/[^0-9]/g, ''),
      summary: (metadata?.textContent || '').trim().replace(/\\s+/g, ' '),
      metadata: (metadata?.textContent || '').trim().replace(/\\s+/g, ' ')
    };
    }).filter((item) => item.title && item.url.startsWith('https://') && item.url.includes('/subject/')));
  }`;
}

function resultText(payload: McpToolResultPayload): string {
  if (!Array.isArray(payload.content)) {
    return '';
  }
  const parts: string[] = [];
  payload.content.forEach((item: McpToolContentItem): void => {
    const text = textOf(item.text).trim();
    if (text.length > 0) {
      parts.push(text);
    }
  });
  return parts.join('\n');
}

function evaluateResultSection(text: string): string {
  const marker = '### Result';
  const markerIndex = text.indexOf(marker);
  let section = markerIndex >= 0 ? text.substring(markerIndex + marker.length).trim() : text.trim();
  const nextHeading = section.indexOf('\n### ');
  if (nextHeading >= 0) {
    section = section.substring(0, nextHeading).trim();
  }
  if (section.startsWith('```')) {
    const firstLine = section.indexOf('\n');
    const closing = section.lastIndexOf('```');
    if (firstLine >= 0 && closing > firstLine) {
      section = section.substring(firstLine + 1, closing).trim();
    }
  }
  return section;
}

function providerItemsFromEvaluatePayload(payload: McpToolResultPayload): Object[] {
  let value = JSON.parse(evaluateResultSection(resultText(payload))) as Object | string;
  if (typeof value === 'string') {
    value = JSON.parse(value) as Object;
  }
  return Array.isArray(value) ? value as Object[] : [];
}

function itemFromProvider(value: Object, fallbackKind: DoubanPublicMediaKind, index: number): DoubanPublicSearchItem | null {
  const item = value as DoubanProviderItem;
  const kindValue = textOf(item.kind).trim().toLowerCase();
  let kind: DoubanPublicMediaKind = fallbackKind;
  if (kindValue === 'book') {
    kind = 'book';
  } else if (kindValue === 'movie') {
    kind = 'movie';
  } else if (kindValue === 'music') {
    kind = 'music';
  }
  const title = textOf(item.title).trim();
  const url = textOf(item.url).trim();
  if (title.length === 0 || !url.toLowerCase().startsWith('https://') || url.indexOf('/subject/') < 0) {
    return null;
  }
  return {
    id: textOf(item.id).trim() || 'douban-' + kind + '-' + index.toString(),
    kind: kind,
    title: title,
    url: url,
    imageUrl: textOf(item.imageUrl).trim(),
    rating: textOf(item.rating).trim(),
    ratingCount: textOf(item.ratingCount).trim(),
    summary: textOf(item.summary).trim(),
    metadata: textOf(item.metadata).trim()
  };
}

export function doubanItemsFromBrowserEvaluate(
  payload: McpToolResultPayload,
  kind: DoubanPublicMediaKind
): DoubanPublicSearchItem[] {
  const items: DoubanPublicSearchItem[] = [];
  providerItemsFromEvaluatePayload(payload).forEach((value: Object, index: number): void => {
    const item = itemFromProvider(value, kind, index);
    if (item !== null) {
      items.push(item);
    }
  });
  return items;
}

function failedToolMessage(result: McpToolCallResult, fallback: string): string {
  if (result.errorMessage.trim().length > 0) {
    return result.errorMessage.trim();
  }
  if (result.result !== null) {
    const provider = resultText(result.result).trim();
    if (provider.length > 0) {
      return provider.substring(0, 400);
    }
  }
  return fallback;
}

function roundRobin(groups: DoubanPublicSearchItem[][], limit: number): DoubanPublicSearchItem[] {
  const items: DoubanPublicSearchItem[] = [];
  let itemIndex = 0;
  while (items.length < limit) {
    let added = false;
    for (let groupIndex = 0; groupIndex < groups.length && items.length < limit; groupIndex++) {
      if (itemIndex < groups[groupIndex].length) {
        items.push(groups[groupIndex][itemIndex]);
        added = true;
      }
    }
    if (!added) {
      break;
    }
    itemIndex += 1;
  }
  return items;
}

function authFailure(status: number, message: string): boolean {
  const lower = message.toLowerCase();
  return status === 401 || status === 403 || lower.indexOf('authorization') >= 0 ||
    lower.indexOf('unauthorized') >= 0 || lower.indexOf('bearer token') >= 0;
}

export class DoubanPlaywrightMcpClient {
  private readonly transport: DoubanPlaywrightMcpTransport;

  constructor(transport: DoubanPlaywrightMcpTransport = new NetworkDoubanPlaywrightMcpTransport()) {
    this.transport = transport;
  }

  async search(
    config: DoubanPlaywrightMcpConfig,
    request: DoubanPublicSearchRequest
  ): Promise<DoubanPublicSearchResult> {
    const endpoint = config.mcpUrl.trim();
    if (endpoint.length === 0) {
      return {
        status: 'disabled',
        items: [],
        message: '未配置 DOUBAN_PLAYWRIGHT_MCP_URL；豆瓣公开书影音 Playwright MCP Demo 已停用。',
        rawPreview: ''
      };
    }
    const normalized = normalizeDoubanPublicSearchRequest(request);
    if (normalized.query.length === 0) {
      return { status: 'empty', items: [], message: '豆瓣公开书影音搜索词为空。', rawPreview: '' };
    }
    try {
      const session = await this.transport.initialize(config);
      if (!session.ok) {
        return {
          status: authFailure(session.httpStatus, session.errorMessage) ? 'needs_auth' : 'error',
          items: [],
          message: session.errorMessage,
          rawPreview: ''
        };
      }
      await this.transport.notifyInitialized(config, session.sessionId);
      const groups: DoubanPublicSearchItem[][] = [];
      const warnings: string[] = [];
      const perKindLimit = Math.min(15, Math.ceil(normalized.limit / normalized.kinds.length) + 1);
      let rawPreview = '';
      try {
        for (let index = 0; index < normalized.kinds.length; index++) {
          const kind = normalized.kinds[index];
          const navigateArgs: DoubanBrowserNavigateArgs = {
            url: doubanPublicSearchUrl(kind, normalized.query, normalized.start)
          };
          const navigate = await this.transport.callTool(
            config, session.sessionId, 'browser_navigate', navigateArgs
          );
          if (!navigate.ok || navigate.result === null || navigate.result.isError === true) {
            warnings.push(kind + ': ' + failedToolMessage(navigate, 'browser_navigate 失败'));
            groups.push([]);
            continue;
          }
          const evaluateArgs: DoubanBrowserEvaluateArgs = {
            function: doubanBrowserEvaluateFunction(kind, perKindLimit)
          };
          const evaluated = await this.transport.callTool(
            config, session.sessionId, 'browser_evaluate', evaluateArgs
          );
          rawPreview = evaluated.rawPreview;
          if (!evaluated.ok || evaluated.result === null || evaluated.result.isError === true) {
            warnings.push(kind + ': ' + failedToolMessage(evaluated, 'browser_evaluate 失败'));
            groups.push([]);
            continue;
          }
          try {
            groups.push(doubanItemsFromBrowserEvaluate(evaluated.result, kind));
          } catch (error) {
            warnings.push(kind + ': 结果解析失败 ' + (error instanceof Error ? error.message : JSON.stringify(error)));
            groups.push([]);
          }
        }
      } finally {
        try {
          await this.transport.callTool(
            config, session.sessionId, 'browser_close', new DoubanEmptyToolArgs()
          );
        } catch (_error) {}
      }
      const items = roundRobin(groups, normalized.limit);
      if (items.length === 0 && warnings.length > 0) {
        return {
          status: 'error',
          items: [],
          message: '豆瓣公开书影音 Playwright MCP Demo 失败：' + warnings.join('；'),
          rawPreview: rawPreview
        };
      }
      return {
        status: items.length > 0 ? 'success' : 'empty',
        items: items,
        message: '豆瓣公开书影音 Playwright MCP Demo 返回 ' + items.length.toString() + ' 条。' +
          (warnings.length > 0 ? ' 部分失败：' + warnings.join('；') : ''),
        rawPreview: rawPreview
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      return {
        status: authFailure(0, message) ? 'needs_auth' : 'error',
        items: [],
        message: '豆瓣 Playwright MCP 调用失败：' + message,
        rawPreview: ''
      };
    }
  }
}
