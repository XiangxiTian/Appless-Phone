import { describe, expect, it } from '@ohos/hypium';
import {
  acquireTwitchAppToken,
  DefaultTwitchSearchTransport,
  discoverTwitchInterestStreams,
  resetTwitchTokenCacheForTests,
  twitchAppTokenUrl,
  twitchGamesUrl,
  twitchHelixHeaders,
  twitchStreamsUrl,
  twitchTopGamesUrl,
  TwitchHttpResult,
  TwitchRcpHttpMethod,
  TwitchRcpResponse,
  TwitchRcpSession,
  TwitchRcpSessionFactory,
  TwitchSearchConfig,
  TwitchSearchTransport
} from '@loop/agent-core';

interface TwitchRequestFixture {
  method: string;
  url: string;
  body: string;
  authorization: string;
}

interface TwitchGameFixture {
  id: string;
  name: string;
  igdb_id?: string;
}

interface TwitchStreamFixture {
  id: string;
  user_login: string;
  user_name: string;
  game_id: string;
  game_name: string;
  type: string;
  title: string;
  viewer_count: number;
  started_at: string;
  language: string;
  thumbnail_url: string;
  tags: string[];
}

interface TwitchGamesPayloadFixture {
  data: TwitchGameFixture[];
}

interface TwitchStreamsPayloadFixture {
  data: TwitchStreamFixture[];
}

function tokenResponse(token: string, expiresIn: number = 3600): TwitchHttpResult {
  return { code: 200, text: '{"access_token":' + JSON.stringify(token) +
    ',"expires_in":' + expiresIn.toString() + ',"token_type":"bearer"}' };
}

function gamesResponse(data: TwitchGameFixture[]): TwitchHttpResult {
  const payload: TwitchGamesPayloadFixture = { data: data };
  return { code: 200, text: JSON.stringify(payload) };
}

function stream(id: string, login: string, gameId: string, gameName: string,
  viewerCount: number, language: string = 'en'): TwitchStreamFixture {
  return {
    id: id, user_login: login, user_name: login, game_id: gameId, game_name: gameName,
    type: 'live', title: login + ' title', viewer_count: viewerCount,
    started_at: '2026-08-19T08:00:00Z', language: language,
    thumbnail_url: 'https://img.example/' + id + '-{width}x{height}.jpg', tags: ['Live']
  };
}

function streamsResponse(data: TwitchStreamFixture[]): TwitchHttpResult {
  const payload: TwitchStreamsPayloadFixture = { data: data };
  return { code: 200, text: JSON.stringify(payload) };
}

const TECH_GAMES: TwitchGameFixture[] = [
  { id: 'tech-1', name: 'Science & Technology' },
  { id: 'tech-2', name: 'Software and Game Development' },
  { id: 'tech-3', name: 'Makers & Crafting' }
];
const TOP_GAMES: TwitchGameFixture[] = [
  { id: 'chatting', name: 'Just Chatting', igdb_id: '' },
  { id: 'game-1', name: 'Actual Hot Game', igdb_id: 'igdb-1' }
];
const TECH_STREAMS: TwitchStreamFixture[] = [
  stream('tech-stream-2', 'tech-two', 'tech-2', 'Software and Game Development', 200),
  stream('tech-stream-1', 'tech-one', 'tech-1', 'Science & Technology', 300),
  stream('tech-stream-3', 'tech-three', 'tech-3', 'Makers & Crafting', 100)
];
const GAME_STREAMS: TwitchStreamFixture[] = [
  stream('game-stream-1', 'game-one', 'game-1', 'Actual Hot Game', 999)
];
const EMPTY_GAMES: TwitchGameFixture[] = [];

class QueueTransport implements TwitchSearchTransport {
  getResponses: TwitchHttpResult[];
  postResponses: TwitchHttpResult[];
  getIndex: number = 0;
  postIndex: number = 0;
  calls: TwitchRequestFixture[] = [];

  constructor(postResponses: TwitchHttpResult[], getResponses: TwitchHttpResult[]) {
    this.postResponses = postResponses;
    this.getResponses = getResponses;
  }

  async get(url: string, headers: Record<string, string>): Promise<TwitchHttpResult> {
    this.calls.push({ method: 'GET', url: url, body: '', authorization: headers['Authorization'] ?? '' });
    const response = this.getResponses[this.getIndex];
    this.getIndex += 1;
    return response === undefined ? { code: 599, text: 'missing fake GET response' } : response;
  }

  async post(url: string, _headers: Record<string, string>, body: string): Promise<TwitchHttpResult> {
    this.calls.push({ method: 'POST', url: url, body: body, authorization: '' });
    const response = this.postResponses[this.postIndex];
    this.postIndex += 1;
    return response === undefined ? { code: 599, text: 'missing fake POST response' } : response;
  }
}

class FailingTokenTransport implements TwitchSearchTransport {
  async get(_url: string, _headers: Record<string, string>): Promise<TwitchHttpResult> {
    return { code: 200, text: '{"data":[]}' };
  }

  async post(_url: string, _headers: Record<string, string>, _body: string): Promise<TwitchHttpResult> {
    throw new Error('simulated token transport failure');
  }
}

class ClosingQueueTransport extends QueueTransport {
  closeCount: number = 0;

  async close(): Promise<void> {
    this.closeCount += 1;
  }
}

function rcpResponse(result: TwitchHttpResult): TwitchRcpResponse {
  const headers: Record<string, string> = {};
  return { statusCode: result.code, text: result.text, headers: headers };
}

class QueueRcpSessionFactory implements TwitchRcpSessionFactory {
  responses: TwitchRcpResponse[];
  failAtRequest: number;
  responseIndex: number = 0;
  createCount: number = 0;
  closeCount: number = 0;
  requests: TwitchRequestFixture[] = [];

  constructor(responses: TwitchRcpResponse[], failAtRequest: number = 0) {
    this.responses = responses;
    this.failAtRequest = failAtRequest;
  }

  create(): TwitchRcpSession {
    this.createCount += 1;
    return new QueueRcpSession(this);
  }

  async request(
    url: string,
    method: TwitchRcpHttpMethod,
    headers: Record<string, string>,
    body: string
  ): Promise<TwitchRcpResponse> {
    const requestNumber = this.requests.length + 1;
    this.requests.push({
      method: method,
      url: url,
      body: body,
      authorization: headers['Authorization'] ?? ''
    });
    if (this.failAtRequest > 0 && requestNumber === this.failAtRequest) {
      throw new Error('simulated RCP request failure');
    }
    const response = this.responses[this.responseIndex];
    this.responseIndex += 1;
    if (response === undefined) {
      const emptyHeaders: Record<string, string> = {};
      return { statusCode: 599, text: 'missing fake RCP response', headers: emptyHeaders };
    }
    return response;
  }
}

class QueueRcpSession implements TwitchRcpSession {
  private readonly factory: QueueRcpSessionFactory;

  constructor(factory: QueueRcpSessionFactory) {
    this.factory = factory;
  }

  request(
    url: string,
    method: TwitchRcpHttpMethod,
    headers: Record<string, string>,
    body: string
  ): Promise<TwitchRcpResponse> {
    return this.factory.request(url, method, headers, body);
  }

  close(): void {
    this.factory.closeCount += 1;
  }
}

export default function twitchSearchClientTest(): void {
  describe('twitchInterestDiscoveryClient', () => {
    it('builds multi-category, top-games and language-aware stream URLs', 0, () => {
      expect(twitchAppTokenUrl()).assertEqual('https://id.twitch.tv/oauth2/token');
      expect(twitchGamesUrl(['Science & Technology', 'Makers & Crafting'])).assertEqual(
        'https://api.twitch.tv/helix/games?name=Science%20%26%20Technology&name=Makers%20%26%20Crafting');
      expect(twitchTopGamesUrl(10)).assertEqual('https://api.twitch.tv/helix/games/top?first=10');
      expect(twitchStreamsUrl(['tech-1', 'tech-2'], 3, false)).assertEqual(
        'https://api.twitch.tv/helix/streams?first=3&game_id=tech-1&game_id=tech-2&language=zh');
      expect(twitchStreamsUrl(['game-1'], 1, true)).assertEqual(
        'https://api.twitch.tv/helix/streams?first=1&game_id=game-1');
      const headers = twitchHelixHeaders(' client-id ', ' app-token ');
      expect(headers['Client-Id']).assertEqual('client-id');
      expect(headers['Authorization']).assertEqual('Bearer app-token');
    });

    it('returns three hottest technology streams and one hottest actual-game stream', 0, async () => {
      resetTwitchTokenCacheForTests();
      const transport = new QueueTransport([tokenResponse('token')], [
        gamesResponse(TECH_GAMES), streamsResponse(TECH_STREAMS), gamesResponse(TOP_GAMES), streamsResponse(GAME_STREAMS)
      ]);
      const batch = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, { multilingual: true }, transport, 1000);
      expect(batch.status).assertEqual('success');
      expect(batch.items.length).assertEqual(4);
      expect(batch.items[0].id).assertEqual('tech-stream-1');
      expect(batch.items[0].viewerCount).assertEqual(300);
      expect(batch.items[0].kind).assertEqual('tech');
      expect(batch.items[3].kind).assertEqual('game');
      expect(transport.calls[2].url.indexOf('language=')).assertEqual(-1);
      expect(transport.calls[3].url).assertEqual('https://api.twitch.tv/helix/games/top?first=10');
      expect(transport.calls[4].url.indexOf('game_id=game-1')).assertLarger(-1);
      expect(batch.message.indexOf('Actual Hot Game')).assertLarger(-1);
    });

    it('caches categories for 24h and top game for 10m', 0, async () => {
      resetTwitchTokenCacheForTests();
      const config: TwitchSearchConfig = { clientId: 'id', clientSecret: 'secret' };
      const transport = new QueueTransport([tokenResponse('token')], [
        gamesResponse(TECH_GAMES), streamsResponse(TECH_STREAMS), gamesResponse(TOP_GAMES), streamsResponse(GAME_STREAMS),
        streamsResponse(TECH_STREAMS), streamsResponse(GAME_STREAMS),
        streamsResponse(TECH_STREAMS), gamesResponse(TOP_GAMES), streamsResponse(GAME_STREAMS)
      ]);
      await discoverTwitchInterestStreams(config, { multilingual: true }, transport, 1000);
      const afterCold = transport.calls.length;
      await discoverTwitchInterestStreams(config, { multilingual: true }, transport, 2000);
      expect(transport.calls.length - afterCold).assertEqual(2);
      const afterWarm = transport.calls.length;
      await discoverTwitchInterestStreams(config, { multilingual: true }, transport, 602001);
      expect(transport.calls.length - afterWarm).assertEqual(3);
      expect(transport.calls[afterWarm + 1].url.indexOf('/helix/games/top')).assertLarger(-1);
    });

    it('accepts partial category resolution and de-duplicates a repeated stream', 0, async () => {
      resetTwitchTokenCacheForTests();
      const duplicateGame: TwitchStreamFixture[] = [
        stream('same-stream', 'same-channel', 'game-1', 'Actual Hot Game', 999)
      ];
      const duplicateTech: TwitchStreamFixture[] = [
        stream('same-stream', 'same-channel', 'tech-1', 'Science & Technology', 100)
      ];
      const partialGames: TwitchGameFixture[] = [{ id: 'tech-1', name: 'Science & Technology' }];
      const transport = new QueueTransport([tokenResponse('token')], [
        gamesResponse(partialGames), streamsResponse(duplicateTech),
        gamesResponse(TOP_GAMES), streamsResponse(duplicateGame)
      ]);
      const batch = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, { multilingual: false }, transport, 1000);
      expect(batch.status).assertEqual('success');
      expect(batch.items.length).assertEqual(1);
      expect(batch.message.indexOf('科技分类解析 1/3')).assertLarger(-1);
      expect(transport.calls[2].url.indexOf('game_id=tech-1')).assertLarger(-1);
      expect(transport.calls[2].url.indexOf('language=zh')).assertLarger(-1);
      expect(transport.calls[4].url.indexOf('language=zh')).assertLarger(-1);
    });

    it('keeps the successful branch when the other discovery branch fails', 0, async () => {
      resetTwitchTokenCacheForTests();
      const gameOnlyTransport = new QueueTransport([tokenResponse('token')], [
        { code: 500, text: '' }, gamesResponse(TOP_GAMES), streamsResponse(GAME_STREAMS)
      ]);
      const gameOnly = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, { multilingual: true }, gameOnlyTransport, 1000);
      expect(gameOnly.status).assertEqual('success');
      expect(gameOnly.items[0].kind).assertEqual('game');
      expect(gameOnly.message.indexOf('部分分支失败')).assertLarger(-1);

      resetTwitchTokenCacheForTests();
      const techOnlyTransport = new QueueTransport([tokenResponse('token')], [
        gamesResponse(TECH_GAMES), streamsResponse(TECH_STREAMS), { code: 500, text: '' }
      ]);
      const techOnly = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, { multilingual: true }, techOnlyTransport, 1000);
      expect(techOnly.status).assertEqual('success');
      expect(techOnly.items.length).assertEqual(3);
      expect(techOnly.items[0].kind).assertEqual('tech');
      expect(techOnly.message.indexOf('部分分支失败')).assertLarger(-1);
    });

    it('distinguishes true empty results from double-empty failures', 0, async () => {
      resetTwitchTokenCacheForTests();
      const emptyTransport = new QueueTransport(
        [tokenResponse('token')], [gamesResponse(EMPTY_GAMES), gamesResponse(EMPTY_GAMES)]);
      const empty = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, {}, emptyTransport, 1000);
      expect(empty.status).assertEqual('empty');

      resetTwitchTokenCacheForTests();
      const failedTransport = new QueueTransport([tokenResponse('token')], [
        { code: 429, text: '', retryAfterSeconds: 30 }, { code: 500, text: '' }
      ]);
      const failed = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, {}, failedTransport, 1000);
      expect(failed.status).assertEqual('error');
      expect(failed.reason).assertEqual('rate_limited');
      expect(failed.retryAfterSeconds).assertEqual(30);
    });

    it('retries the whole discovery operation once after a Helix 401', 0, async () => {
      resetTwitchTokenCacheForTests();
      const transport = new ClosingQueueTransport([tokenResponse('old-token'), tokenResponse('new-token')], [
        gamesResponse(TECH_GAMES), { code: 401, text: '' },
        gamesResponse(TECH_GAMES), streamsResponse(TECH_STREAMS), gamesResponse(TOP_GAMES), streamsResponse(GAME_STREAMS)
      ]);
      const batch = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, { multilingual: true }, transport, 1000);
      expect(batch.status).assertEqual('success');
      const gameResolveCalls = transport.calls.filter((call: TwitchRequestFixture): boolean =>
        call.url.indexOf('/helix/games?') >= 0);
      expect(gameResolveCalls.length).assertEqual(2);
      expect(transport.postIndex).assertEqual(2);
      expect(transport.calls[2].authorization).assertEqual('Bearer old-token');
      expect(transport.calls[5].authorization).assertEqual('Bearer new-token');
      expect(transport.closeCount).assertEqual(1);
    });

    it('does no network work without credentials and classifies token failures as auth', 0, async () => {
      resetTwitchTokenCacheForTests();
      const missingTransport = new QueueTransport([], []);
      const missing = await discoverTwitchInterestStreams(
        { clientId: '', clientSecret: '' }, {}, missingTransport, 1000);
      expect(missingTransport.calls.length).assertEqual(0);
      expect(missing.reason).assertEqual('disabled');

      resetTwitchTokenCacheForTests();
      const tokenFailure = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, {}, new FailingTokenTransport(), 1000);
      expect(tokenFailure.status).assertEqual('needs_auth');
      expect(tokenFailure.reason).assertEqual('auth');
    });

    it('mints once for concurrent requests and refreshes before expiry', 0, async () => {
      resetTwitchTokenCacheForTests();
      const config: TwitchSearchConfig = { clientId: 'client-id', clientSecret: 'client-secret' };
      const transport = new QueueTransport([tokenResponse('token-1'), tokenResponse('token-2')], []);
      const tokens = await Promise.all([
        acquireTwitchAppToken(config, transport, 1000), acquireTwitchAppToken(config, transport, 1000)
      ]);
      expect(tokens.join(',')).assertEqual('token-1,token-1');
      expect(await acquireTwitchAppToken(config, transport, 3000000)).assertEqual('token-1');
      expect(await acquireTwitchAppToken(config, transport, 3301000)).assertEqual('token-2');
      expect(transport.postIndex).assertEqual(2);
    });

    it('reuses one RCP session for a discovery and creates a new one for the next discovery', 0, async () => {
      resetTwitchTokenCacheForTests();
      const responses: TwitchRcpResponse[] = [
        rcpResponse(tokenResponse('token')),
        rcpResponse(gamesResponse(TECH_GAMES)),
        rcpResponse(streamsResponse(TECH_STREAMS)),
        rcpResponse(gamesResponse(TOP_GAMES)),
        rcpResponse(streamsResponse(GAME_STREAMS)),
        rcpResponse(streamsResponse(TECH_STREAMS)),
        rcpResponse(streamsResponse(GAME_STREAMS))
      ];
      const factory = new QueueRcpSessionFactory(responses);
      const transport = new DefaultTwitchSearchTransport(factory);
      const config: TwitchSearchConfig = { clientId: 'id', clientSecret: 'secret' };

      const first = await discoverTwitchInterestStreams(
        config, { multilingual: true }, transport, 1000);
      expect(first.status).assertEqual('success');
      expect(factory.requests.length).assertEqual(5);
      expect(factory.createCount).assertEqual(1);
      expect(factory.closeCount).assertEqual(1);

      const second = await discoverTwitchInterestStreams(
        config, { multilingual: true }, transport, 2000);
      expect(second.status).assertEqual('success');
      expect(factory.requests.length).assertEqual(7);
      expect(factory.createCount).assertEqual(2);
      expect(factory.closeCount).assertEqual(2);
    });

    it('closes the reused RCP session when discovery fails', 0, async () => {
      resetTwitchTokenCacheForTests();
      const factory = new QueueRcpSessionFactory([], 1);
      const transport = new DefaultTwitchSearchTransport(factory);
      const batch = await discoverTwitchInterestStreams(
        { clientId: 'id', clientSecret: 'secret' }, {}, transport, 1000);

      expect(batch.status).assertEqual('needs_auth');
      expect(factory.createCount).assertEqual(1);
      expect(factory.closeCount).assertEqual(1);
    });
  });
}
