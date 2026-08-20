import { describe, it, expect } from '@ohos/hypium';
import {
  DoubanPlaywrightMcpClient,
  DoubanPlaywrightMcpConfig,
  DoubanPlaywrightMcpSessionStart,
  DoubanPlaywrightMcpTransport,
  DoubanPlaywrightToolArgs,
  DoubanPublicSearchRequest,
  McpToolCallResult,
  doubanBrowserEvaluateFunction,
  doubanItemsFromBrowserEvaluate,
  doubanPublicSearchUrl,
  normalizeDoubanPublicSearchRequest
} from '@loop/agent-core';

interface RecordedToolCall {
  name: string;
  args: DoubanPlaywrightToolArgs;
}

interface RecordedBrowserArgs {
  url?: string;
  function?: string;
}

class ScriptedDoubanTransport implements DoubanPlaywrightMcpTransport {
  calls: RecordedToolCall[] = [];
  initialized: boolean = false;
  notified: boolean = false;
  initializeResult: DoubanPlaywrightMcpSessionStart = {
    ok: true,
    httpStatus: 200,
    sessionId: 'douban-session',
    errorMessage: ''
  };

  async initialize(_config: DoubanPlaywrightMcpConfig): Promise<DoubanPlaywrightMcpSessionStart> {
    this.initialized = true;
    return this.initializeResult;
  }

  async notifyInitialized(_config: DoubanPlaywrightMcpConfig, sessionId: string): Promise<void> {
    expect(sessionId).assertEqual('douban-session');
    this.notified = true;
  }

  async callTool(
    _config: DoubanPlaywrightMcpConfig,
    sessionId: string,
    toolName: string,
    args: DoubanPlaywrightToolArgs
  ): Promise<McpToolCallResult> {
    expect(sessionId).assertEqual('douban-session');
    this.calls.push({ name: toolName, args: args });
    if (toolName !== 'browser_evaluate') {
      return successfulMcpResult('ok');
    }
    const functionText = (args as RecordedBrowserArgs).function ?? '';
    const kind = functionText.indexOf("kind: 'movie'") >= 0 ? 'movie' :
      (functionText.indexOf("kind: 'music'") >= 0 ? 'music' : 'book');
    const host = kind === 'movie' ? 'movie.douban.com' :
      (kind === 'music' ? 'music.douban.com' : 'book.douban.com');
    const value = JSON.stringify([{
      id: 'douban-' + kind + '-42',
      kind: kind,
      title: kind + ' result',
      url: 'https://' + host + '/subject/42/',
      imageUrl: 'https://img.example.com/' + kind + '.jpg',
      rating: '9.1',
      ratingCount: '1200',
      summary: 'public subject metadata',
      metadata: 'public subject metadata'
    }]);
    return successfulMcpResult('### Result\n' + JSON.stringify(value) + '\n### Ran Playwright code');
  }
}

function successfulMcpResult(text: string): McpToolCallResult {
  return {
    ok: true,
    httpStatus: 200,
    errorMessage: '',
    result: {
      content: [{ type: 'text', text: text }],
      isError: false
    },
    rawPreview: text
  };
}

function defaultRequest(): DoubanPublicSearchRequest {
  return {
    query: '三体',
    kinds: ['book', 'movie'],
    limit: 4,
    start: 0
  };
}

function configured(): DoubanPlaywrightMcpConfig {
  return {
    mcpUrl: 'https://playwright.example.com/mcp',
    bearerToken: 'gateway-token'
  };
}

export default function doubanPlaywrightMcpClientTest() {
  describe('doubanPlaywrightMcpClient', () => {
    it('bounds the public search request and constructs only fixed Douban vertical URLs', 0, () => {
      const request = normalizeDoubanPublicSearchRequest({
        query: '  三体  ', kinds: [], limit: 99, start: 999
      });

      expect(request.query).assertEqual('三体');
      expect(request.kinds.join(',')).assertEqual('book,movie,music');
      expect(request.limit).assertEqual(15);
      expect(request.start).assertEqual(150);
      expect(doubanPublicSearchUrl('book', '三体', 15))
        .assertEqual('https://search.douban.com/book/subject_search?search_text=%E4%B8%89%E4%BD%93&cat=1001&start=15');
      expect(doubanBrowserEvaluateFunction('movie', 99).indexOf("movie.douban.com")).assertLarger(-1);
      expect(doubanBrowserEvaluateFunction('movie', 99).indexOf('.slice(0, 15)')).assertLarger(-1);
    });

    it('parses the official browser_evaluate result envelope into public subject items', 0, () => {
      const value = JSON.stringify([{
        id: 'douban-book-123', kind: 'book', title: '三体',
        url: 'https://book.douban.com/subject/123/',
        imageUrl: 'https://img.example.com/123.jpg', rating: '9.3', ratingCount: '100',
        summary: '刘慈欣 / 重庆出版社', metadata: '刘慈欣 / 重庆出版社'
      }]);
      const payload = successfulMcpResult(
        '### Result\n' + JSON.stringify(value) + '\n### Ran Playwright code'
      ).result!;
      const items = doubanItemsFromBrowserEvaluate(payload, 'book');

      expect(items.length).assertEqual(1);
      expect(items[0].title).assertEqual('三体');
      expect(items[0].imageUrl).assertEqual('https://img.example.com/123.jpg');
      expect(items[0].rating).assertEqual('9.3');
    });

    it('keeps official Playwright browser tools inside fixed HAP orchestration', 0, async () => {
      const transport = new ScriptedDoubanTransport();
      const result = await new DoubanPlaywrightMcpClient(transport).search(configured(), defaultRequest());

      expect(result.status).assertEqual('success');
      expect(result.items.length).assertEqual(2);
      expect(transport.initialized).assertTrue();
      expect(transport.notified).assertTrue();
      expect(transport.calls.map((call: RecordedToolCall): string => call.name).join(','))
        .assertEqual('browser_navigate,browser_evaluate,browser_navigate,browser_evaluate,browser_close');
      const firstUrl = (transport.calls[0].args as RecordedBrowserArgs).url ?? '';
      expect(firstUrl.indexOf('https://search.douban.com/book/subject_search?')).assertEqual(0);
      expect(transport.calls.some((call: RecordedToolCall): boolean => call.name === 'tools/list')).assertFalse();
    });

    it('reports disabled without opening a Playwright MCP session when no endpoint is configured', 0, async () => {
      const transport = new ScriptedDoubanTransport();
      const result = await new DoubanPlaywrightMcpClient(transport).search({ mcpUrl: '', bearerToken: '' }, defaultRequest());

      expect(result.status).assertEqual('disabled');
      expect(result.message.indexOf('DOUBAN_PLAYWRIGHT_MCP_URL')).assertLarger(-1);
      expect(transport.initialized).assertFalse();
      expect(transport.calls.length).assertEqual(0);
    });

    it('maps cloud ingress auth failures without fabricating results', 0, async () => {
      const transport = new ScriptedDoubanTransport();
      transport.initializeResult = {
        ok: false,
        httpStatus: 401,
        sessionId: '',
        errorMessage: 'Missing Authorization bearer token'
      };
      const result = await new DoubanPlaywrightMcpClient(transport).search(configured(), defaultRequest());

      expect(result.status).assertEqual('needs_auth');
      expect(result.items.length).assertEqual(0);
      expect(transport.calls.length).assertEqual(0);
    });
  });
}
