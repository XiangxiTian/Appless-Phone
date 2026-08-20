import { describe, it, expect } from '@ohos/hypium';
import {
  AggregateSearchPost,
  AggregateSearchPolicy,
  AggregateSearchResult,
  AggregateSearchSourceBatch,
  AggregateSearchStatus,
  AggregateSearchSource,
  AggregateSearchSourceMetadata,
  AggregateSearchSourceStatus,
  AggregateSearchVideo,
  AGGREGATE_SEARCH_PARTIAL_THROTTLE_MS,
  AggregateZhihuConfig,
  WaterfallCandidate,
  WaterfallContinuation,
  WaterfallFeedState,
  WaterfallRankedCandidate,
  WaterfallLoadRequest,
  WaterfallInterestRecallRequest,
  WaterfallPreferenceSnapshot,
  WaterfallQueryStage,
  WaterfallSourcePhase,
  WaterfallSourceState,
  advanceWaterfallFeed,
  aggregateContinuationFromDynamicResult,
  callAggregateSearch,
  callAggregateSearchContinuation,
  callAggregateSearchContinuationForContext,
  configureWaterfallEnabledSourcesForRuntime,
  configureWaterfallPreferenceProfileForRuntime,
  configureWaterfallSearchPolicyForRuntime,
  applyWaterfallSourceSelection,
  applyWaterfallExpandedQuery,
  failWaterfallExpansion,
  finalizeInterestWaterfallRecallRanking,
  aggregateSearchQueryFromArgs,
  aggregateSearchPolicyFromArgs,
  aggregateSearchSourceMetadata,
  aggregateSearchInterestSourceIds,
  aggregateSearchRegistrySourceIds,
  aggregateSearchSearchSourceIds,
  aggregateYouTubeRelevanceLanguage,
  aggregateMediaCandidates,
  aggregateXSearchQuery,
  streamAggregateSearchSourceBatches,
  aggregateSearchResultFromParts,
  aggregateSearchSourcesFromArgs,
  aggregateXPostSearchPrompt,
  hackerNewsPostsFromComposioResult,
  normalizeAggregateSearchStatus,
  redditPostsFromComposioResult,
  unsupportedSourceStatus,
  xPostsFromComposioResult,
  zhihuPostsFromSearchPayload,
  zhihuSearchUrl,
  mergeWaterfallBatch,
  mergeWaterfallBatchDeferredRanking,
  mergeWaterfallFeedSnapshot,
  planWaterfallContinuation,
  parseWaterfallExpandedQuery,
  planWaterfallInterestRecall,
  rankWaterfallCandidates,
  waterfallSearchPolicyForRuntime
} from '@loop/agent-core';

interface QueryArgsFixture {
  query: string;
  sources?: string[];
  limit?: number;
  preferenceDescription?: string;
  onlyDomesticSources?: boolean;
  includeMultilingualResults?: boolean;
}

function video(id: string, url: string): AggregateSearchVideo {
  return {
    id: id,
    source: 'youtube',
    provider: 'YouTube',
    title: 'Video ' + id,
    summary: '',
    url: url,
    thumbnail: '',
    publishedAt: '',
    duration: '',
    status: 'success',
    rows: []
  };
}

function post(id: string, url: string): AggregateSearchPost {
  return {
    id: id,
    source: 'hackernews',
    provider: 'HN',
    title: 'Post ' + id,
    author: '',
    handle: '',
    text: '',
    url: url,
    publishedAt: '',
    score: '',
    commentCount: '',
    status: 'success',
    rows: []
  };
}

function waterfallCandidate(
  id: string,
  source: string,
  title: string,
  summary: string,
  url: string,
  publishedAt: string,
  originalIndex: number
): WaterfallCandidate {
  return {
    id: id,
    source: source,
    mediaType: 'post',
    title: title,
    summary: summary,
    url: url,
    coverUrl: '',
    publishedAt: publishedAt,
    originalIndex: originalIndex
  };
}

function traditionalCandidate(
  id: string,
  source: string,
  title: string,
  summary: string,
  url: string,
  sourceRank: number,
  originalIndex: number
): WaterfallCandidate {
  const candidate = waterfallCandidate(
    id, source, title, summary, url, '2026-08-06T10:00:00.000Z', originalIndex
  );
  candidate.sourceRank = sourceRank;
  candidate.topics = [];
  candidate.format = 'text';
  candidate.recallRoute = 'search';
  candidate.recallWeight = 1;
  return candidate;
}

function emptyPreferenceProfile(): WaterfallPreferenceSnapshot {
  return {
    topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: [],
    sessionTopicWeights: [], sessionSourceWeights: [], sessionFormatWeights: []
  };
}

const WATERFALL_NOW_MS: number = Date.parse('2026-08-06T12:00:00.000Z');

function rankedWaterfallCandidate(id: string, source: string, title: string, index: number): WaterfallRankedCandidate {
  const candidate = waterfallCandidate(id, source, title, '', 'https://' + source + '.test/' + id, '2026-08-06T10:00:00.000Z', index);
  return rankWaterfallCandidates({
    query: 'openai codex', candidates: [candidate], enabledSources: [source], shownIds: [], stableIds: [], preferenceDescription: ''
  }, WATERFALL_NOW_MS)[0];
}

function sourceState(source: string, continuation: WaterfallContinuation | null, phase: WaterfallSourcePhase = 'success', inFlight: boolean = false, reservedCount: number = 0): WaterfallSourceState {
  return {
    source: source,
    phase: phase,
    continuation: continuation,
    inFlight: inFlight,
    reservedCount: reservedCount,
    message: ''
  };
}

function feedState(current: WaterfallRankedCandidate | null, stable: WaterfallRankedCandidate[], tail: WaterfallRankedCandidate[], sources: WaterfallSourceState[]): WaterfallFeedState {
  return {
    query: 'openai codex',
    enabledSources: sources.map((item) => item.source),
    preferenceDescription: '',
    shown: [],
    current: current,
    stable: stable,
    tail: tail,
    sources: sources
  };
}

function exhaustedFeed(stage: WaterfallQueryStage, emptyRounds: number = 0): WaterfallFeedState {
  const state = feedState(null, [], [], [
    sourceState('youtube', null, 'exhausted'),
    sourceState('bilibili', null, 'exhausted'),
    sourceState('x', null, 'exhausted'),
    sourceState('hackernews', null, 'exhausted'),
    sourceState('reddit', null, 'exhausted'),
    sourceState('zhihu', null, 'exhausted')
  ]);
  state.queryStage = stage;
  state.originalQuery = 'openai codex';
  state.consecutiveEmptyRounds = emptyRounds;
  state.roundActive = true;
  state.roundNewItemCount = 0;
  return state;
}

function aggregateBatch(source: AggregateSearchSource, id: string, status: AggregateSearchStatus = 'success'): AggregateSearchSourceBatch {
  const videos: AggregateSearchVideo[] = status === 'success' ? [{
    id: id,
    source: source,
    provider: source,
    title: 'OpenAI Codex ' + id,
    summary: 'batch ' + id,
    url: 'https://' + source + '.test/' + id,
    thumbnail: '',
    publishedAt: '2026-08-06T10:00:00.000Z',
    duration: '',
    status: 'success',
    rows: []
  }] : [];
  return {
    source: source,
    videos: videos,
    posts: [],
    status: {
      source: source,
      label: source,
      status: status,
      message: status === 'success' ? '返回 1 条。' : 'source ' + status,
      count: videos.length
    },
    continuation: null
  };
}

class DeferredAggregateBatch {
  readonly promise: Promise<AggregateSearchSourceBatch>;
  private resolvePromise: ((batch: AggregateSearchSourceBatch) => void) | null = null;

  constructor() {
    this.promise = new Promise<AggregateSearchSourceBatch>((
      resolve: (batch: AggregateSearchSourceBatch) => void
    ): void => {
      this.resolvePromise = resolve;
    });
  }

  finish(batch: AggregateSearchSourceBatch): void {
    const resolve = this.resolvePromise;
    this.resolvePromise = null;
    if (resolve !== null) {
      resolve(batch);
    }
  }
}

async function waitForAggregateThrottle(milliseconds: number): Promise<void> {
  await new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, milliseconds);
  });
}

async function settleAggregateSearchMicrotasks(): Promise<void> {
  for (let index = 0; index < 8; index++) {
    await Promise.resolve();
  }
}

function waterfallInventoryIds(state: WaterfallFeedState | undefined): string[] {
  if (state === undefined) {
    return [];
  }
  const ids = state.shown.map((item: WaterfallRankedCandidate): string => item.id);
  if (state.current !== null) {
    ids.push(state.current.id);
  }
  return ids.concat(state.stable.map((item: WaterfallRankedCandidate): string => item.id))
    .concat(state.tail.map((item: WaterfallRankedCandidate): string => item.id))
    .concat((state.reserve ?? []).map((item: WaterfallRankedCandidate): string => item.id));
}

export default function aggregateSearchClientTest() {
  describe('aggregateSearchClient', () => {
    it('extracts query and source defaults', 0, () => {
      configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
      const args: QueryArgsFixture = { query: 'openai codex', sources: ['youtube', 'x'], limit: 3 };

      expect(aggregateSearchQueryFromArgs('我想看看相关新闻', args)).assertEqual('openai codex');
      expect(aggregateSearchQueryFromArgs('我想看看有关 openai codex 的相关新闻和讨论', null)).assertEqual('openai codex');
      expect(aggregateSearchQueryFromArgs('openai codex 新闻讨论', null)).assertEqual('openai codex');
      expect(aggregateSearchSourcesFromArgs(args).join(',')).assertEqual('');
      expect(aggregateSearchSourcesFromArgs(null).join(',')).assertEqual('bilibili,zhihu');
      expect(aggregateSearchSourcesFromArgs({
        query: 'ignored', sources: ['twitch'],
        onlyDomesticSources: false, includeMultilingualResults: true
      } as QueryArgsFixture).join(',')).assertEqual(aggregateSearchSearchSourceIds().join(','));
    });

    it('applies all four deterministic aggregate source policy combinations', 0, () => {
      const domesticChinese: QueryArgsFixture = {
        query: 'codex', onlyDomesticSources: true, includeMultilingualResults: false
      };
      const domesticMultilingual: QueryArgsFixture = {
        query: 'codex', onlyDomesticSources: true, includeMultilingualResults: true
      };
      const globalChinese: QueryArgsFixture = {
        query: 'codex', onlyDomesticSources: false, includeMultilingualResults: false
      };
      const globalMultilingual: QueryArgsFixture = {
        query: 'codex', onlyDomesticSources: false, includeMultilingualResults: true
      };
      expect(aggregateSearchSourcesFromArgs(domesticChinese).join(',')).assertEqual('bilibili,zhihu');
      expect(aggregateSearchSourcesFromArgs(domesticMultilingual).join(',')).assertEqual('bilibili,zhihu');
      expect(aggregateSearchSourcesFromArgs(globalChinese).join(','))
        .assertEqual('youtube,bilibili,x,zhihu,applepodcasts');
      expect(aggregateSearchSourcesFromArgs(globalMultilingual).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
      expect(aggregateYouTubeRelevanceLanguage(aggregateSearchPolicyFromArgs(globalChinese))).assertEqual('zh-Hans');
      expect(aggregateYouTubeRelevanceLanguage(aggregateSearchPolicyFromArgs(globalMultilingual))).assertEqual('');
    });

    it('preserves the runtime policy when an internal aggregate call omits policy fields', 0, async () => {
      configureWaterfallSearchPolicyForRuntime({ domesticOnly: false, multilingual: true });
      try {
        const result = await callAggregateSearch(
          'daily brief', { query: 'daily brief', sources: ['youtube'] } as QueryArgsFixture,
          '', { apiKey: '' }, null, WATERFALL_NOW_MS
        );
        const policy = waterfallSearchPolicyForRuntime();
        expect(result.sourceStatuses.length).assertEqual(1);
        expect(result.sourceStatuses[0].source).assertEqual('youtube');
        expect(policy.domesticOnly).assertFalse();
        expect(policy.multilingual).assertTrue();
        expect(aggregateSearchSourcesFromArgs(
          { query: 'codex', sources: ['hackernews'] } as QueryArgsFixture, policy
        ).join(',')).assertEqual('hackernews');
      } finally {
        configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
        configureWaterfallSearchPolicyForRuntime({ domesticOnly: true, multilingual: false });
      }
    });

    it('keeps explicit sources subordinate to settings and exposes source tags', 0, () => {
      const blocked: QueryArgsFixture = {
        query: 'codex', sources: ['youtube', 'hackernews', 'reddit', 'bilibili'],
        onlyDomesticSources: false, includeMultilingualResults: false
      };
      const metadata = aggregateSearchSourceMetadata();
      const emptyExplicitSources: QueryArgsFixture = {
        query: 'codex', sources: [], onlyDomesticSources: false, includeMultilingualResults: true
      };
      const invalidExplicitSources: QueryArgsFixture = {
        query: 'codex', sources: ['news', 'discussion'],
        onlyDomesticSources: false, includeMultilingualResults: true
      };
      const partiallyValidSources: QueryArgsFixture = {
        query: 'codex', sources: ['news', 'youtube', 'discussion'],
        onlyDomesticSources: false, includeMultilingualResults: true
      };
      const policyBlockedSources: QueryArgsFixture = {
        query: 'codex', sources: ['youtube'],
        onlyDomesticSources: true, includeMultilingualResults: false
      };
      expect(aggregateSearchSourcesFromArgs(blocked).join(',')).assertEqual('youtube,bilibili');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.isExternal).length).assertEqual(6);
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'hackernews')[0].languages.join(','))
        .assertEqual('en');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'reddit')[0].languageFilterMode)
        .assertEqual('none');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'x')[0].languageFilterMode)
        .assertEqual('native');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'applepodcasts')[0].languageFilterMode)
        .assertEqual('regional');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'twitch')[0].languageFilterMode)
        .assertEqual('post_filter');
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'twitch')[0]
        .capabilities.search).assertFalse();
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === 'twitch')[0]
        .capabilities.interest).assertTrue();
      expect(aggregateSearchSourcesFromArgs(emptyExplicitSources).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
      expect(aggregateSearchSourcesFromArgs(invalidExplicitSources).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
      expect(aggregateSearchSourcesFromArgs(partiallyValidSources).join(',')).assertEqual('youtube');
      expect(aggregateSearchSourcesFromArgs(policyBlockedSources).length).assertEqual(0);
    });

    it('falls back after an earlier query when category labels appear as sources', 0, () => {
      const firstQuery: QueryArgsFixture = { query: 'codex' };
      const secondQuery: QueryArgsFixture = {
        query: 'codex', sources: ['news', 'discussion'],
        onlyDomesticSources: false, includeMultilingualResults: true
      };

      expect(aggregateSearchSourcesFromArgs(firstQuery).join(',')).assertEqual('bilibili,zhihu');
      expect(aggregateSearchSourcesFromArgs(secondQuery).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
    });

    it('builds X language expressions from the selected aggregate policy', 0, () => {
      expect(aggregateXSearchQuery('openai codex', {
        domesticOnly: false, multilingual: false
      })).assertEqual('openai codex (lang:zh-CN OR lang:zh-TW)');
      expect(aggregateXSearchQuery('openai codex', {
        domesticOnly: false, multilingual: true
      })).assertEqual('openai codex (lang:zh-CN OR lang:zh-TW OR lang:en)');
    });

    it('keeps discovery runtime settings out of search source selection', 0, () => {
      configureWaterfallEnabledSourcesForRuntime(['youtube', 'x']);
      const args: QueryArgsFixture = {
        query: 'AI',
        sources: ['youtube', 'reddit', 'x'],
        onlyDomesticSources: false,
        includeMultilingualResults: true
      };
      expect(aggregateSearchSourcesFromArgs(args).join(','))
        .assertEqual('youtube,reddit,x');
      configureWaterfallEnabledSourcesForRuntime([]);
      const allSources: QueryArgsFixture = {
        query: 'AI',
        onlyDomesticSources: false,
        includeMultilingualResults: true
      };
      expect(aggregateSearchSourcesFromArgs(allSources).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
      configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
    });

    it('applies the runtime preference profile to initial provider batches', 0, async () => {
      configureWaterfallPreferenceProfileForRuntime({
        topicWeights: [], sourceWeights: [], formatWeights: [],
        explicitRules: [{ dimension: 'source', key: 'x', effect: 'block' }]
      });
      const result = await streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'x'],
        [Promise.resolve(aggregateBatch('youtube', 'youtube-kept')),
          Promise.resolve(aggregateBatch('x', 'x-blocked'))],
        (_partial: AggregateSearchResult): void => {},
        WATERFALL_NOW_MS
      );
      const visible = (result.waterfall?.current === null ? [] : [result.waterfall?.current])
        .concat(result.waterfall?.stable ?? [], result.waterfall?.tail ?? []);
      expect(visible.some((item: WaterfallRankedCandidate | undefined): boolean => item?.source === 'x'))
        .assertFalse();
      configureWaterfallPreferenceProfileForRuntime(undefined);
    });

    it('deduplicates URLs and keeps source issue statuses', 0, () => {
      const status: AggregateSearchSourceStatus = unsupportedSourceStatus('zhihu', '未配置 ZHIHU_API_KEY（知乎 Access Secret）。');
      const result = aggregateSearchResultFromParts(
        'openai codex',
        [video('v1', 'https://example.test/a'), video('v2', 'https://example.test/a')],
        [post('p1', 'https://news.ycombinator.com/item?id=123'), post('p2', 'https://news.ycombinator.com/item?id=123')],
        [status]
      );

      expect(result.videos.length).assertEqual(1);
      expect(result.posts.length).assertEqual(1);
      expect(result.sourceStatuses[0].source).assertEqual('zhihu');
      expect(result.sourceStatuses[0].status).assertEqual('unsupported');
      expect(result.summary).assertEqual('1 video, 1 discussion');
    });

    it('normalizes source connection statuses truthfully', 0, () => {
      expect(normalizeAggregateSearchStatus('empty', 0)).assertEqual('empty');
      expect(normalizeAggregateSearchStatus('connected', 0)).assertEqual('empty');
      expect(normalizeAggregateSearchStatus('needs_auth', 0)).assertEqual('needs_auth');
      expect(normalizeAggregateSearchStatus('auth_required', 0)).assertEqual('needs_auth');
      expect(normalizeAggregateSearchStatus('unsupported', 0)).assertEqual('unsupported');
      expect(normalizeAggregateSearchStatus('limited', 0)).assertEqual('error');
      expect(normalizeAggregateSearchStatus('disabled', 0)).assertEqual('error');
    });

    it('builds X keyword prompts without converting OpenAI topics into handles', 0, () => {
      expect(aggregateXPostSearchPrompt('openai codex')).assertEqual('X 公开 post 搜索关键词: openai codex');
    });

    it('maps official Zhihu search payloads into post cards', 0, () => {
      const posts = zhihuPostsFromSearchPayload('{"code":0,"data":{"Items":[{"Title":"OpenAI Codex 有哪些讨论","ContentText":"<em>Codex</em> 的开发者讨论摘要","Url":"https://www.zhihu.com/question/1","AuthorName":"知乎用户","AuthorAvatar":"https://pic.example.com/avatar.jpg","VoteUpCount":12,"CommentCount":3,"EditTime":1780000000}]}}');

      expect(zhihuSearchUrl('openai codex').indexOf('/api/v1/content/zhihu_search')).assertLarger(-1);
      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('zhihu');
      expect(posts[0].title).assertEqual('OpenAI Codex 有哪些讨论');
      expect(posts[0].author).assertEqual('知乎用户');
      expect(posts[0].text.indexOf('<em>')).assertEqual(-1);
      expect(posts[0].score).assertEqual('12');
      expect(posts[0].commentCount).assertEqual('3');
      expect(JSON.stringify(posts[0].rows).indexOf('avatar.jpg')).assertLarger(-1);
      expect(aggregateMediaCandidates([], posts, 0)[0].mediaType).assertEqual('post');
    });

    it('preserves Twitch viewer count as the provider ranking score', 0, () => {
      const twitchPost: AggregateSearchPost = {
        id: 'twitch-stream-1', source: 'twitch', provider: 'Twitch', title: 'Live coding',
        author: 'coder', handle: 'coder', text: '正在直播 · 科技热门',
        url: 'https://www.twitch.tv/coder', publishedAt: '2026-08-19T08:00:00Z',
        score: '321', commentCount: '', status: 'success',
        rows: [{ label: 'Kind', value: 'tech' }, { label: 'Viewers', value: '321' }]
      };
      const candidate = aggregateMediaCandidates([], [twitchPost], 0)[0];
      expect(candidate.providerScore).assertEqual(321);
      expect(candidate.source).assertEqual('twitch');
    });

    it('turns dynamic text rows into readable post cards with images', 0, () => {
      const posts = hackerNewsPostsFromComposioResult({
        sourceTag: 'MCP',
        toolName: 'search_content',
        title: 'MCP 工具结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [
          { label: 'statuses 1', value: '{"text":"<p>OpenAI Codex 新讨论</p>","user":{"screen_name":"AI Daily"},"url":"https://news.ycombinator.com/item?id=1","thumbnail_pic":"https://img.example.com/codex.jpg","comments_count":4}' }
        ],
        rawPreview: 'raw'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('AI Daily');
      expect(posts[0].author).assertEqual('AI Daily');
      expect(posts[0].text.indexOf('<p>')).assertEqual(-1);
      expect(posts[0].text.indexOf('OpenAI Codex 新讨论')).assertLarger(-1);
      expect(posts[0].commentCount).assertEqual('4');
      expect(JSON.stringify(posts[0].rows).indexOf('codex.jpg')).assertLarger(-1);
    });

    it('maps Reddit Composio payloads from raw JSON into post cards', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"results":[{"kind":"Listing","data":{"children":[{"kind":"t3","data":{"title":"OpenAI Codex on Reddit","author":"dev_user","selftext":"Long Reddit discussion","permalink":"/r/OpenAI/comments/1/codex","ups":88,"num_comments":12,"thumbnail":"https://img.example.com/reddit.png","created_utc":1780000000}}]}}]}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('reddit');
      expect(posts[0].provider).assertEqual('Reddit');
      expect(posts[0].title).assertEqual('OpenAI Codex on Reddit');
      expect(posts[0].author).assertEqual('dev_user');
      expect(posts[0].url).assertEqual('https://www.reddit.com/r/OpenAI/comments/1/codex');
      expect(posts[0].score).assertEqual('88');
      expect(posts[0].commentCount).assertEqual('12');
      expect(posts[0].text).assertEqual('Long Reddit discussion');
      expect(JSON.stringify(posts[0].rows).indexOf('reddit.png')).assertLarger(-1);
    });

    it('keeps distinct raw-preview posts through Waterfall ranking', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit results',
        status: 'success',
        summary: '2 results',
        rows: [],
        rawPreview: '{"data":{"children":[{"data":{"title":"First Codex post","selftext":"First discussion","permalink":"/r/OpenAI/comments/1/codex"}},{"data":{"title":"Second Codex post","selftext":"Second discussion","permalink":"/r/OpenAI/comments/2/codex"}}]}}'
      });
      const candidates = aggregateMediaCandidates([], posts, 0);
      const ranked = rankWaterfallCandidates({
        query: 'codex', candidates: candidates, enabledSources: ['reddit'], shownIds: [], stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(posts.length).assertEqual(2);
      expect(ranked.length).assertEqual(2);
    });

    it('keeps real comment excerpts and direct video media from social results', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"data":{"children":[{"data":{"title":"Video discussion","selftext":"Main post",' +
          '"permalink":"/r/OpenAI/comments/3/codex","media":{"reddit_video":{"fallback_url":' +
          '"https://v.redd.it/demo/DASH_720.mp4"}},"comments":{"items":[{"data":{"messageText":' +
          '"First useful reply"}},{"text":"Second useful reply"}]}}}]}}'
      });
      const candidates = aggregateMediaCandidates([], posts, 0);

      expect(JSON.stringify(posts[0].rows).indexOf('First useful reply')).assertLarger(-1);
      expect(JSON.stringify(posts[0].rows).indexOf('Second useful reply')).assertLarger(-1);
      expect(candidates[0].mediaType).assertEqual('video');
      expect(candidates[0].mediaUrl).assertEqual('https://v.redd.it/demo/DASH_720.mp4');
      expect(candidates[0].summary.indexOf('First useful reply')).assertLarger(-1);
    });

    it('maps Reddit Composio preview wrappers into post cards', 0, () => {
      const posts = redditPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'REDDIT_SEARCH_POSTS',
        title: 'Composio Reddit 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [
          { label: 'source', value: 'Composio' },
          { label: 'truncated', value: 'true' },
          { label: 'preview', value: '{"data":{"children":[{"data":{"title":"Readable Reddit post","author":"coder","selftext":"Readable body","permalink":"/r/OpenAI/comments/2/codex","ups":9,"num_comments":2}}]}}' }
        ],
        rawPreview: '{"source":"Composio","truncated":true,"preview":"{\\"data\\":{\\"children\\":[{\\"data\\":{\\"title\\":\\"Readable Reddit post\\",\\"author\\":\\"coder\\",\\"selftext\\":\\"Readable body\\",\\"permalink\\":\\"/r/OpenAI/comments/2/codex\\",\\"ups\\":9,\\"num_comments\\":2}}]}}"}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('Readable Reddit post');
      expect(posts[0].text).assertEqual('Readable body');
      expect(posts[0].url).assertEqual('https://www.reddit.com/r/OpenAI/comments/2/codex');
      expect(posts[0].score).assertEqual('9');
      expect(posts[0].commentCount).assertEqual('2');
    });

    it('maps X Composio payloads into aggregate discussion cards', 0, () => {
      const posts = xPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'x.post.search',
        title: 'Composio Twitter 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"data":[{"id":"x-1","text":"OpenAI Codex update","author_id":"user-1","created_at":"2026-07-20T01:00:00.000Z"}]}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('x');
      expect(posts[0].provider).assertEqual('X');
      expect(posts[0].text).assertEqual('OpenAI Codex update');
      expect(posts[0].publishedAt).assertEqual('2026-07-20T01:00:00.000Z');
    });

    it('joins X media expansions to playable and image cards', 0, () => {
      const posts = xPostsFromComposioResult({
        sourceTag: 'Composio', toolName: 'TWITTER_RECENT_SEARCH', title: 'Composio X 结果',
        status: 'success', summary: '返回 2 条', rows: [],
        rawPreview: '{"data":[{"id":"x-video","text":"Video post","attachments":{"media_keys":["m1"]}},' +
          '{"id":"x-image","text":"Image post","attachments":{"media_keys":["m2"]}}],"includes":{"media":[' +
          '{"media_key":"m1","type":"video","preview_image_url":"https://img.test/video.jpg","variants":[' +
          '{"content_type":"video/mp4","bit_rate":832000,"url":"https://video.test/demo.mp4"}]},' +
          '{"media_key":"m2","type":"photo","url":"https://img.test/photo.jpg"}]}}'
      });
      const candidates = aggregateMediaCandidates([], posts, 0);

      expect(candidates[0].mediaType).assertEqual('video');
      expect(candidates[0].mediaUrl).assertEqual('https://video.test/demo.mp4');
      expect(candidates[0].coverUrl).assertEqual('https://img.test/video.jpg');
      expect(candidates[1].mediaType).assertEqual('image_text');
      expect(candidates[1].coverUrl).assertEqual('https://img.test/photo.jpg');
    });

    it('maps compact X Composio messageText into the card body', 0, () => {
      const posts = xPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'TWITTER_RECENT_SEARCH',
        title: 'Composio X 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"posts":[{"id":"tweet-current-1","messageText":"real post","url":"https://x.com/user/status/tweet-current-1"}]}'
      });

      expect(posts.length).assertEqual(1);
      expect(posts[0].text).assertEqual('real post');
      expect(posts[0].url).assertEqual('https://x.com/user/status/tweet-current-1');
    });

    it('uses the first real social image as the Waterfall cover', 0, () => {
      const posts = xPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'x.post.search',
        title: 'Composio X 结果',
        status: 'success',
        summary: '返回 1 条',
        rows: [],
        rawPreview: '{"posts":[{"id":"x-media-1","text":"带图片的帖子","url":"https://x.com/user/status/x-media-1","pics":[{"url":"https://img.example.com/one.jpg"},{"url":"https://img.example.com/two.jpg"}]}]}'
      });
      const candidate = aggregateMediaCandidates([], posts, 0)[0];

      expect(candidate.mediaType).assertEqual('image_text');
      expect(candidate.coverUrl).assertEqual('https://img.example.com/one.jpg');
    });

    it('skips non-success Hacker News rows', 0, () => {
      const posts = hackerNewsPostsFromComposioResult({
        sourceTag: 'Composio',
        toolName: 'HACKERNEWS_SEARCH_POSTS',
        title: 'Composio Hacker News 结果',
        status: 'needs_auth',
        summary: 'Composio 未配置：Hacker News 需要授权。',
        rows: [
          { label: '请求', value: '帮我用 Composio Hacker News 搜 openai codex 的帖子' },
          { label: '结果摘要', value: 'Composio 未配置：Hacker News 需要授权。' }
        ],
        rawPreview: 'raw'
      });

      expect(posts.length).assertEqual(0);
    });

    it('uses only provider-returned cursors and pages for social continuation', 0, () => {
      const x = aggregateContinuationFromDynamicResult('x', {
        sourceTag: 'Composio', toolName: 'TWITTER_RECENT_SEARCH', title: 'X', status: 'success',
        summary: '返回 10 条', rows: [], rawPreview: '{"meta":{"next_token":"x-next"}}'
      }, null);
      const hackerNews = aggregateContinuationFromDynamicResult('hackernews', {
        sourceTag: 'Composio', toolName: 'HACKERNEWS_SEARCH_POSTS', title: 'HN', status: 'success',
        summary: '返回 10 条', rows: [], rawPreview: '{"data":{"page":0,"nbPages":3,"hits":[]}}'
      }, { kind: 'page', value: '0' });
      const reddit = aggregateContinuationFromDynamicResult('reddit', {
        sourceTag: 'Composio', toolName: 'REDDIT_SEARCH_POSTS', title: 'Reddit', status: 'success',
        summary: '返回 10 条', rows: [], rawPreview: '{"data":{"after":"reddit-next","children":[]}}'
      }, null);
      const exhausted = aggregateContinuationFromDynamicResult('x', {
        sourceTag: 'Composio', toolName: 'TWITTER_RECENT_SEARCH', title: 'X', status: 'success',
        summary: '返回 2 条', rows: [], rawPreview: '{"data":[]}'
      }, { kind: 'cursor', value: 'old' });
      const repeated = aggregateContinuationFromDynamicResult('reddit', {
        sourceTag: 'Composio', toolName: 'REDDIT_SEARCH_POSTS', title: 'Reddit', status: 'success',
        summary: '返回 10 条', rows: [], rawPreview: '{"data":{"after":"same"}}',
        providerData: JSON.parse('{"after":"same"}') as Object
      }, { kind: 'cursor', value: 'same' });

      expect(x?.kind).assertEqual('cursor');
      expect(x?.value).assertEqual('x-next');
      expect(hackerNews?.kind).assertEqual('page');
      expect(hackerNews?.value).assertEqual('1');
      expect(reddit?.kind).assertEqual('cursor');
      expect(reddit?.value).assertEqual('reddit-next');
      expect(exhausted).assertEqual(null);
      expect(repeated).assertEqual(null);
    });

    it('ranks exact and token query matches before weak matches', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('old-weak', 'x', 'Compiler notes', 'A general compiler note', 'https://x.test/weak', '2026-07-01T00:00:00.000Z', 3),
          waterfallCandidate('reddit-token', 'reddit', 'Codex tools for agents', 'A partial topic match', 'https://reddit.test/token', '2026-08-05T00:00:00.000Z', 2),
          waterfallCandidate('hn-exact', 'hackernews', 'Codex tools for OpenAI', 'All query terms in the title', 'https://news.test/exact', '2026-08-05T00:00:00.000Z', 1),
          waterfallCandidate('yt-exact', 'youtube', 'OpenAI Codex release', 'The exact topic is in the title', 'https://youtube.test/exact', '2026-08-06T10:00:00.000Z', 0)
        ],
        enabledSources: ['youtube', 'hackernews', 'reddit', 'x'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('yt-exact,hn-exact,reddit-token,old-weak');
      expect(ranked[0].reason).assertEqual('标题命中查询 · 24 小时内发布');
    });

    it('does not count the same token twice toward an all-token match', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('repeated-openai', 'youtube', 'OpenAI update', 'OpenAI news',
            'https://youtube.test/repeated-openai', '2026-08-06T10:00:00.000Z', 0)
        ],
        enabledSources: ['youtube'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked[0].signals.relevanceTier).assertEqual(2);
      expect(ranked[0].signals.titleHits).assertEqual(1);
      expect(ranked[0].signals.summaryHits).assertEqual(1);
    });

    it('uses freshness then original order without random output', 0, () => {
      const candidates = [
        waterfallCandidate('same-old', 'youtube', 'OpenAI Codex', 'Same title', 'https://youtube.test/old', '2026-07-10T00:00:00.000Z', 0),
        waterfallCandidate('same-new', 'bilibili', 'OpenAI Codex', 'Same title', 'https://bilibili.test/new', '2026-08-06T11:00:00.000Z', 1),
        waterfallCandidate('same-invalid-date', 'x', 'OpenAI Codex', 'Same title', 'https://x.test/invalid', 'not-a-date', 2)
      ];
      candidates.forEach((candidate: WaterfallCandidate): void => {
        candidate.sourceRank = 1;
      });
      const first = rankWaterfallCandidates({
        query: 'openai codex', candidates: candidates, enabledSources: ['youtube', 'bilibili', 'x'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS);
      const second = rankWaterfallCandidates({
        query: 'openai codex', candidates: candidates, enabledSources: ['youtube', 'bilibili', 'x'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(first.map((item) => item.id).join(',')).assertEqual('same-new,same-old,same-invalid-date');
      expect(second.map((item) => item.id).join(',')).assertEqual(first.map((item) => item.id).join(','));
      expect(first[2].reason).assertEqual('标题命中查询');
    });

    it('deduplicates normalized links across video and post', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('duplicate-post', 'x', 'OpenAI Codex', 'Older duplicate', 'https://EXAMPLE.test/watch?id=7#comments', '2026-07-01T00:00:00.000Z', 1),
          waterfallCandidate('duplicate-video', 'youtube', 'OpenAI Codex', 'Newer duplicate', 'HTTPS://example.test/watch?id=7#top', '2026-08-06T10:00:00.000Z', 0),
          waterfallCandidate('different-query', 'reddit', 'OpenAI Codex', '', 'https://example.test/watch?id=8#top', '2026-08-06T10:00:00.000Z', 2)
        ],
        enabledSources: ['youtube', 'x', 'reddit'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('duplicate-video,different-query');
      expect(ranked[0].normalizedUrl).assertEqual('https://example.test/watch?id=7');
    });

    it('keeps only enabled sources and truthful reason signals', 0, () => {
      const ranked = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [
          waterfallCandidate('valid', 'youtube', 'OpenAI Codex', '', 'https://youtube.test/valid', '', 0),
          waterfallCandidate('disabled', 'x', 'OpenAI Codex', '', 'https://x.test/disabled', '2026-08-06T11:00:00.000Z', 1),
          waterfallCandidate('relative', 'youtube', 'OpenAI Codex', '', '/relative', '2026-08-06T11:00:00.000Z', 2),
          waterfallCandidate('empty-url', 'youtube', 'OpenAI Codex', '', '', '2026-08-06T11:00:00.000Z', 3)
        ],
        enabledSources: ['youtube'],
        shownIds: [],
        stableIds: [],
        preferenceDescription: 'only show official'
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item) => item.id).join(',')).assertEqual('valid');
      expect(ranked[0].reason).assertEqual('标题命中查询');
    });

    it('maps video image-text and post fields without inventing data', 0, () => {
      const videos: AggregateSearchVideo[] = [{
        id: 'video-1', source: 'youtube', provider: 'YouTube', title: 'Video title', summary: 'Video summary',
        url: 'https://youtube.test/video-1', thumbnail: 'https://img.test/video.jpg', publishedAt: '2026-08-06T10:00:00.000Z',
        duration: '1:00', status: 'success', rows: []
      }];
      const posts: AggregateSearchPost[] = [{
        id: 'post-1', source: 'x', provider: 'X', title: 'Post title', author: 'author', handle: '@author', text: 'Post body',
        url: 'https://x.test/post-1', publishedAt: '2026-08-06T09:00:00.000Z', score: '1', commentCount: '2', status: 'success',
        rows: [{ label: 'image', value: 'https://img.test/post.jpg' }]
      }, {
        id: 'post-2', source: 'x', provider: 'X', title: 'Post without image', author: '', handle: '', text: 'Body',
        url: 'https://x.test/post-2', publishedAt: '', score: '', commentCount: '', status: 'success', rows: []
      }];
      const candidates = aggregateMediaCandidates(videos, posts, 0);
      const ranked = rankWaterfallCandidates({
        query: 'Video title', candidates: candidates, enabledSources: ['youtube', 'x'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS);

      expect(candidates.length).assertEqual(3);
      expect(candidates[0].mediaType).assertEqual('video');
      expect(candidates[0].coverUrl).assertEqual('https://img.test/video.jpg');
      expect(ranked[0].duration).assertEqual('1:00');
      expect(candidates[1].mediaType).assertEqual('image_text');
      expect(candidates[1].summary).assertEqual('Post body');
      expect(candidates[2].mediaType).assertEqual('post');
      expect(candidates[2].coverUrl).assertEqual('');
      expect(candidates[2].providerScore === undefined).assertTrue();
    });

    it('keeps provider rank score topics format and recall provenance on candidates', 0, () => {
      const videos: AggregateSearchVideo[] = [
        {
          id: 'video-1', source: 'youtube', provider: 'YouTube', title: '端侧大模型部署', summary: '手机 AI 推理',
          url: 'https://youtube.test/video-1', thumbnail: '', publishedAt: '2026-08-06T10:00:00.000Z',
          duration: '1:00', status: 'success', rows: []
        },
        {
          id: 'video-2', source: 'youtube', provider: 'YouTube', title: '端侧模型优化', summary: '量化实践',
          url: 'https://youtube.test/video-2', thumbnail: '', publishedAt: '2026-08-06T09:00:00.000Z',
          duration: '2:00', status: 'success', rows: []
        }
      ];
      const posts: AggregateSearchPost[] = [{
        id: 'post-1', source: 'x', provider: 'X', title: '端侧 AI 讨论', author: '', handle: '', text: '设备端推理',
        url: 'https://x.test/post-1', publishedAt: '2026-08-06T08:00:00.000Z', score: '42', commentCount: '3',
        status: 'success', rows: []
      }];

      const candidates = aggregateMediaCandidates(videos, posts, 0, '端侧 AI', 'original');
      const first = JSON.parse(JSON.stringify(candidates[0])) as Record<string, Object | string | number | boolean | null>;
      const second = JSON.parse(JSON.stringify(candidates[1])) as Record<string, Object | string | number | boolean | null>;
      const postCandidate = JSON.parse(JSON.stringify(candidates[2])) as Record<string, Object | string | number | boolean | null>;
      const topics = first['topics'] as string[];

      expect(first['sourceRank'] as number).assertEqual(1);
      expect(second['sourceRank'] as number).assertEqual(2);
      expect(postCandidate['sourceRank'] as number).assertEqual(1);
      expect(postCandidate['providerScore'] as number).assertEqual(42);
      expect(topics.indexOf('端侧') >= 0).assertTrue();
      expect(first['format'] as string).assertEqual('landscape_video');
      expect(first['recallRoute'] as string).assertEqual('search');
      expect(first['recallWeight'] as number).assertEqual(1);
    });

    it('sums RRF contributions before exact identity aggregation', 0, () => {
      const duplicateUrl = 'https://example.test/shared';
      const ranked: WaterfallRankedCandidate[] = rankWaterfallCandidates({
        query: 'AI agent',
        candidates: [
          traditionalCandidate('single', 'reddit', 'AI agent', '', 'https://reddit.test/single', 1, 0),
          traditionalCandidate('shared-youtube', 'youtube', 'AI agent', '', duplicateUrl, 2, 1),
          traditionalCandidate('shared-x', 'x', 'AI agent', '', duplicateUrl, 8, 2)
        ],
        enabledSources: ['youtube', 'x', 'reddit'], shownIds: [], stableIds: [], preferenceDescription: '',
        mode: 'search', surfaceId: 'surface-rrf', profile: emptyPreferenceProfile()
      }, WATERFALL_NOW_MS);

      expect(ranked[0].normalizedUrl).assertEqual(duplicateUrl);
      expect(ranked.length).assertEqual(2);
    });

    it('uses Chinese BM25 terms when a continuous query is split across title and summary', 0, () => {
      const ranked: WaterfallRankedCandidate[] = rankWaterfallCandidates({
        query: '端侧大模型推理',
        candidates: [
          traditionalCandidate('unrelated', 'x', '海外电影资讯', '本周院线票房', 'https://x.test/unrelated', 1, 0),
          traditionalCandidate('relevant', 'youtube', '端侧大模型部署', '设备推理实践', 'https://youtube.test/relevant', 1, 1)
        ],
        enabledSources: ['youtube', 'x'], shownIds: [], stableIds: [], preferenceDescription: '',
        mode: 'search', surfaceId: 'surface-bm25', profile: emptyPreferenceProfile()
      }, WATERFALL_NOW_MS);

      expect(ranked[0].id).assertEqual('relevant');
    });

    it('keeps an exact search hit above a profile-favored unrelated topic', 0, () => {
      const profile = emptyPreferenceProfile();
      profile.topicWeights = [{ key: '电影', weight: 20, updatedAt: WATERFALL_NOW_MS }];
      const exact = traditionalCandidate(
        'exact', 'youtube', 'HarmonyOS 端侧开发', '系统能力', 'https://youtube.test/exact-search', 1, 0
      );
      exact.topics = ['harmonyos', '端侧'];
      const favored = traditionalCandidate(
        'favored', 'x', '科幻电影推荐', '本周新片', 'https://x.test/favored', 1, 1
      );
      favored.topics = ['电影', '科幻'];
      const ranked: WaterfallRankedCandidate[] = rankWaterfallCandidates({
        query: 'HarmonyOS 端侧开发', candidates: [favored, exact], enabledSources: ['youtube', 'x'],
        shownIds: [], stableIds: [], preferenceDescription: '', mode: 'search', surfaceId: 'surface-profile', profile
      }, WATERFALL_NOW_MS);

      expect(ranked[0].id).assertEqual('exact');
    });

    it('uses explicit rules before session and historical weights', 0, () => {
      const profile = emptyPreferenceProfile();
      profile.topicWeights = [
        { key: '降权', weight: 10000, updatedAt: WATERFALL_NOW_MS },
        { key: '历史', weight: 10000, updatedAt: WATERFALL_NOW_MS }
      ];
      profile.sessionTopicWeights = [{ key: '会话', weight: 1, updatedAt: WATERFALL_NOW_MS }];
      profile.explicitRules = [
        { dimension: 'topic', key: '屏蔽', effect: 'block' },
        { dimension: 'topic', key: '降权', effect: 'downweight' },
        { dimension: 'topic', key: '加权', effect: 'boost' }
      ];
      const ranked: WaterfallRankedCandidate[] = rankWaterfallCandidates({
        query: '',
        candidates: [
          traditionalCandidate('blocked', 'x', '屏蔽', '', 'https://x.test/blocked', 1, 0),
          traditionalCandidate('down', 'x', '降权', '', 'https://x.test/down', 1, 1),
          traditionalCandidate('boost', 'x', '加权', '', 'https://x.test/boost', 1, 2),
          traditionalCandidate('session', 'x', '会话', '', 'https://x.test/session', 1, 3),
          traditionalCandidate('history', 'x', '历史', '', 'https://x.test/history', 1, 4)
        ],
        enabledSources: ['x'], shownIds: [], stableIds: [], preferenceDescription: '',
        mode: 'interest', surfaceId: 'surface-priority', profile
      }, WATERFALL_NOW_MS);

      expect(ranked.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('boost,session,history,down');
    });

    it('removes a near duplicate before MMR keeps a distinct relevant source', 0, () => {
      const ranked: WaterfallRankedCandidate[] = rankWaterfallCandidates({
        query: 'OpenAI Codex agent',
        candidates: [
          traditionalCandidate('dup-a', 'youtube', 'OpenAI Codex agent 工具发布', '全新 agent 工具能力介绍', 'https://youtube.test/dup-a', 1, 0),
          traditionalCandidate('dup-b', 'x', 'OpenAI Codex agent 工具发布', '全新 agent 工具能力介绍', 'https://x.test/dup-b', 1, 1),
          traditionalCandidate('distinct', 'reddit', 'Codex 多代理实践', '开发者讨论任务编排', 'https://reddit.test/distinct', 1, 2)
        ],
        enabledSources: ['youtube', 'x', 'reddit'], shownIds: [], stableIds: [], preferenceDescription: '',
        mode: 'search', surfaceId: 'surface-mmr', profile: emptyPreferenceProfile()
      }, WATERFALL_NOW_MS);

      expect(ranked.length).assertEqual(2);
      expect(ranked.some((item: WaterfallRankedCandidate): boolean => item.id === 'distinct')).assertTrue();
      expect(ranked.filter((item: WaterfallRankedCandidate): boolean => item.id.indexOf('dup-') === 0).length).assertEqual(1);
    });

    it('ranks a full personalized multi-source batch inside the UI watchdog budget', 0, () => {
      const sourceNames = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];
      const candidates: WaterfallCandidate[] = [];
      const profile = emptyPreferenceProfile();
      for (let index = 0; index < 500; index += 1) {
        profile.topicWeights.push({
          key: '偏好主题-' + index.toString(),
          weight: index % 2 === 0 ? 1 : -0.5,
          updatedAt: WATERFALL_NOW_MS
        });
      }
      for (let index = 0; index < 60; index += 1) {
        const candidate = traditionalCandidate(
          'stress-' + index.toString(),
          sourceNames[index % sourceNames.length],
          'OpenAI Codex 性能回归 ' + index.toString(),
          '偏好主题-' + index.toString() + ' 端侧交互排序摘要',
          'https://stress.test/' + index.toString(),
          index + 1,
          index
        );
        candidate.topics = ['偏好主题-' + index.toString(), '端侧交互'];
        candidates.push(candidate);
      }
      const startedAt = Date.now();
      const ranked = rankWaterfallCandidates({
        query: 'OpenAI Codex', candidates, enabledSources: sourceNames, shownIds: [], stableIds: [],
        preferenceDescription: '', mode: 'search', surfaceId: 'surface-stress', profile
      }, WATERFALL_NOW_MS);

      expect(ranked.length).assertEqual(60);
      expect(Date.now() - startedAt).assertLess(2000);
    });

    it('plans bounded personalized interest requests without Twitch', 0, () => {
      const profile = emptyPreferenceProfile();
      profile.topicWeights = [
        { key: '科幻', weight: 8, updatedAt: WATERFALL_NOW_MS },
        { key: '摄影', weight: 4, updatedAt: WATERFALL_NOW_MS }
      ];
      const recent = [
        rankedWaterfallCandidate('seed-1', 'youtube', 'AI 视频', 0),
        rankedWaterfallCandidate('seed-2', 'x', '足球', 1)
      ];
      recent[0].topics = ['AI'];
      recent[1].topics = ['足球'];
      const requests: WaterfallInterestRecallRequest[] =
        planWaterfallInterestRecall(profile, recent, ['youtube', 'x', 'reddit']);
      expect(requests.every((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.every((source: string): boolean =>
        ['youtube', 'x', 'reddit'].indexOf(source) >= 0))).assertTrue();
      expect(requests.length <= 7).assertTrue();
      expect(requests.every((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.indexOf('twitch') < 0)).assertTrue();
    });

    it('uses provider discovery for Twitch plus technology exploration for an empty profile', 0, () => {
      const requests: WaterfallInterestRecallRequest[] =
        planWaterfallInterestRecall(emptyPreferenceProfile(), [], ['youtube', 'x', 'twitch']);
      expect(requests[0].query).assertEqual('AI 科技');
      expect(requests[0].sources.join(',')).assertEqual('youtube,x');
      expect(requests[1].query).assertEqual('');
      expect(requests[1].sources.join(',')).assertEqual('twitch');
      expect(requests.some((request: WaterfallInterestRecallRequest): boolean => request.route === 'explore' &&
        request.query === 'AI 科技' && request.sources.join(',') === 'youtube,x')).assertTrue();
      expect(requests.some((request: WaterfallInterestRecallRequest): boolean => request.route === 'explore' &&
        request.query === '' && request.sources.join(',') === 'twitch')).assertTrue();
      expect(requests.every((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.indexOf('reddit') < 0)).assertTrue();
      expect(aggregateSearchSearchSourceIds().indexOf('twitch')).assertEqual(-1);
      expect(aggregateSearchInterestSourceIds().indexOf('twitch')).assertLarger(-1);
    });

    it('dispatches Twitch provider discovery after personalized and technology recall', 0, () => {
      const profile = emptyPreferenceProfile();
      profile.topicWeights = [{ key: '科幻', weight: 8, updatedAt: WATERFALL_NOW_MS }];
      const recent = [rankedWaterfallCandidate('recent-game', 'youtube', '游戏直播', 0)];
      recent[0].topics = ['游戏'];
      const requests = planWaterfallInterestRecall(profile, recent, ['youtube', 'x', 'twitch']);

      expect(requests[0].route).assertEqual('similar');
      expect(requests[0].query).assertEqual('游戏');
      expect(requests[1].route).assertEqual('profile');
      expect(requests[1].query).assertEqual('科幻');
      expect(requests[2].route).assertEqual('explore');
      expect(requests[2].query).assertEqual('AI 科技');
      expect(requests[3].route).assertEqual('explore');
      expect(requests[3].query).assertEqual('');
      expect(requests[3].sources.join(',')).assertEqual('twitch');
      expect(requests.filter((request: WaterfallInterestRecallRequest): boolean => request.route === 'explore')
        .reduce((sum: number, request: WaterfallInterestRecallRequest): number => sum + request.weight, 0))
        .assertEqual(10);
    });

    it('keeps interest batches on the shared ranker without starting search expansion', 0, () => {
      const source = sourceState('youtube', null, 'exhausted');
      const state = feedState(null, [], [], [source]);
      state.mode = 'interest';
      state.query = '';
      state.queryStage = 'done';
      state.profile = emptyPreferenceProfile();
      const first = waterfallCandidate(
        'interest-first', 'youtube', 'AI 视频', '', 'https://youtube.test/interest-first',
        '2026-08-06T10:00:00.000Z', 0
      );
      first.topics = ['AI'];
      first.recallRoute = 'profile';
      first.recallWeight = 30;
      const merged = mergeWaterfallBatch(state, [first], source, WATERFALL_NOW_MS);
      const advanced = advanceWaterfallFeed(merged.state, WATERFALL_NOW_MS);

      expect(merged.state.current?.id).assertEqual('interest-first');
      expect(merged.loadRequests.length).assertEqual(0);
      expect(merged.expansionRequest).assertEqual(undefined);
      expect(advanced.loadRequests.length).assertEqual(0);
      expect(advanced.expansionRequest).assertEqual(undefined);
    });

    it('shows the first deferred interest batch without suppressing or reordering later partials', 0, () => {
      const sources = ['youtube', 'x'].map((source: string): WaterfallSourceState =>
        sourceState(source, null, 'loading', true, 10));
      const state = feedState(null, [], [], sources);
      state.mode = 'interest';
      state.query = '';
      state.profile = emptyPreferenceProfile();
      const firstBatch = [
        waterfallCandidate('visible', 'youtube', 'Visible first card', '', 'https://youtube.test/visible', '', 0),
        waterfallCandidate('stable-a', 'youtube', 'Stable card A', '', 'https://youtube.test/stable-a', '', 1),
        waterfallCandidate('stable-b', 'youtube', 'Stable card B', '', 'https://youtube.test/stable-b', '', 2),
        waterfallCandidate('dup-a', 'youtube', 'OpenAI Codex agent tools release',
          'New agent tools capability overview', 'https://youtube.test/dup-a', '', 3)
      ];
      let partial = mergeWaterfallBatchDeferredRanking(
        state, firstBatch, sourceState('youtube', null, 'exhausted')).state;
      partial = mergeWaterfallBatchDeferredRanking(partial, [
        waterfallCandidate('dup-b', 'x', 'OpenAI Codex agent tools release',
          'New agent tools capability overview', 'https://x.test/dup-b', '', 4)
      ], sourceState('x', null, 'exhausted')).state;

      expect(partial.current?.id).assertEqual('visible');
      expect(partial.stable.map((candidate: WaterfallRankedCandidate): string => candidate.id).join(','))
        .assertEqual('stable-a,stable-b');
      expect(partial.tail.filter((candidate: WaterfallRankedCandidate): boolean =>
        candidate.id.indexOf('dup-') === 0).length).assertEqual(2);
      expect(partial.tail.every((candidate: WaterfallRankedCandidate): boolean =>
        candidate.reason === '等待最终排序')).assertTrue();

      const finalized = finalizeInterestWaterfallRecallRanking(partial, WATERFALL_NOW_MS);
      expect(finalized.current?.id).assertEqual('visible');
      expect(finalized.stable.map((candidate: WaterfallRankedCandidate): string => candidate.id).join(','))
        .assertEqual('stable-a,stable-b');
      expect(finalized.tail.filter((candidate: WaterfallRankedCandidate): boolean =>
        candidate.id.indexOf('dup-') === 0).length).assertEqual(1);
    });

    it('bounds final interest inventory across four or more partial sources', 0, () => {
      const sourceNames = ['youtube', 'bilibili', 'x', 'reddit', 'zhihu', 'twitch'];
      let state = feedState(null, [], [], sourceNames.map((source: string): WaterfallSourceState =>
        sourceState(source, null, 'loading', true, 10)));
      state.mode = 'interest';
      state.query = '';
      state.profile = emptyPreferenceProfile();
      sourceNames.forEach((source: string, sourceIndex: number): void => {
        const candidates: WaterfallCandidate[] = [];
        for (let item = 0; item < 10; item += 1) {
          const id = source + '-' + item.toString();
          candidates.push(waterfallCandidate(
            id, source, 'Unique ' + id, '', 'https://' + source + '.test/' + id, '', sourceIndex * 10 + item));
        }
        state = mergeWaterfallBatchDeferredRanking(
          state, candidates, sourceState(source, null, 'exhausted')).state;
      });

      expect(waterfallInventoryIds(state).length).assertEqual(60);
      const finalized = finalizeInterestWaterfallRecallRanking(state, WATERFALL_NOW_MS);
      const active = (finalized.current === null ? [] : [finalized.current])
        .concat(finalized.stable, finalized.tail);
      expect(active.length).assertEqual(20);
      expect(finalized.reserve?.length).assertEqual(40);
      expect(waterfallInventoryIds(finalized).length).assertEqual(60);
      expect(active.some((candidate: WaterfallRankedCandidate): boolean => candidate.source === 'twitch')).assertTrue();
    });

    it('keeps promoting interest reserve without starting search loads', 0, () => {
      const source = sourceState('youtube', null, 'exhausted');
      const state = feedState(null, [], [], [source]);
      state.mode = 'interest';
      state.query = '';
      state.queryStage = 'done';
      state.profile = emptyPreferenceProfile();
      const candidates: WaterfallCandidate[] = [];
      for (let index = 0; index < 30; index += 1) {
        candidates.push(waterfallCandidate(
          'interest-' + index.toString(), 'youtube', 'AI ' + index.toString(), '',
          'https://youtube.test/interest-' + index.toString(), '2026-08-06T10:00:00.000Z', index
        ));
      }
      let update = mergeWaterfallBatch(state, candidates, source, WATERFALL_NOW_MS);
      expect(update.state.reserve?.length).assertEqual(10);
      for (let index = 0; index < 5; index += 1) {
        update = advanceWaterfallFeed(update.state, WATERFALL_NOW_MS);
      }

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.expansionRequest).assertEqual(undefined);
      expect((update.state.current === null ? 0 : 1) + update.state.stable.length +
        update.state.tail.length).assertEqual(20);
      expect(update.state.reserve?.length).assertEqual(5);
    });

    it('starts the feed from the first displayable source batch', 0, () => {
      const source = sourceState('youtube', null);
      const update = mergeWaterfallBatch(feedState(null, [], [], [source]), [
        waterfallCandidate('first', 'youtube', 'OpenAI Codex first', '', 'https://youtube.test/first', '2026-08-06T10:00:00.000Z', 0),
        waterfallCandidate('second', 'youtube', 'OpenAI Codex second', '', 'https://youtube.test/second', '2026-08-06T09:00:00.000Z', 1)
      ], source, WATERFALL_NOW_MS);

      expect(update.state.current?.id).assertEqual('first');
      expect(update.state.stable.map((item) => item.id).join(',')).assertEqual('second');
    });

    it('does not rerank shown items or the next two items', 0, () => {
      const current = rankedWaterfallCandidate('current-1', 'youtube', 'OpenAI Codex current', 1);
      const nextOne = rankedWaterfallCandidate('next-1', 'youtube', 'OpenAI Codex next one', 2);
      const nextTwo = rankedWaterfallCandidate('next-2', 'youtube', 'OpenAI Codex next two', 3);
      const tailOld = rankedWaterfallCandidate('tail-old', 'youtube', 'OpenAI Codex old tail', 6);
      const state = feedState(current, [nextOne, nextTwo], [tailOld], [sourceState('youtube', null)]);
      state.shown = [rankedWaterfallCandidate('shown-1', 'youtube', 'Shown item', 0)];
      const update = mergeWaterfallBatch(state, [
        waterfallCandidate('late-exact', 'youtube', 'OpenAI Codex', 'Late exact', 'https://youtube.test/late-exact', '2026-08-06T11:59:00.000Z', 5)
      ], sourceState('youtube', null), WATERFALL_NOW_MS);

      expect(update.state.shown.map((item) => item.id).join(',')).assertEqual('shown-1');
      expect(update.state.current?.id).assertEqual('current-1');
      expect(update.state.stable.map((item) => item.id).join(',')).assertEqual('next-1,next-2');
      expect(update.state.tail.map((item) => item.id).join(',')).assertEqual('late-exact,tail-old');
    });

    it('moves the two-item stable window after advancing', 0, () => {
      const state = feedState(
        rankedWaterfallCandidate('current-1', 'youtube', 'OpenAI Codex current', 1),
        [rankedWaterfallCandidate('next-1', 'youtube', 'OpenAI Codex next one', 2), rankedWaterfallCandidate('next-2', 'youtube', 'OpenAI Codex next two', 3)],
        [rankedWaterfallCandidate('tail-old', 'youtube', 'OpenAI Codex old tail', 4)],
        [sourceState('youtube', null)]
      );
      const update = advanceWaterfallFeed(state, WATERFALL_NOW_MS);

      expect(update.state.shown.map((item) => item.id).join(',')).assertEqual('current-1');
      expect(update.state.current?.id).assertEqual('next-1');
      expect(update.state.stable.map((item) => item.id).join(',')).assertEqual('next-2,tail-old');
      expect(update.state.tail.length).assertEqual(0);
    });

    it('reranks the remaining interest inventory from the latest behavior profile after advancing', 0, () => {
      const consumed = rankedWaterfallCandidate('consumed', 'youtube', 'OpenAI Codex watched', 0);
      const youtubeNext = rankedWaterfallCandidate('youtube-next', 'youtube', 'OpenAI Codex video', 1);
      const xNext = rankedWaterfallCandidate('x-next', 'x', 'OpenAI Codex discussion', 2);
      const redditNext = rankedWaterfallCandidate('reddit-next', 'reddit', 'OpenAI Codex thread', 3);
      const state = feedState(consumed, [youtubeNext, xNext], [redditNext], [
        sourceState('youtube', null, 'exhausted'), sourceState('x', null, 'exhausted'),
        sourceState('reddit', null, 'exhausted')
      ]);
      state.mode = 'interest';
      state.profile = emptyPreferenceProfile();
      const beforeBehavior = advanceWaterfallFeed(state, WATERFALL_NOW_MS).state;
      state.profile.sessionSourceWeights = [{ key: 'x', weight: 3, updatedAt: WATERFALL_NOW_MS }];

      const update = advanceWaterfallFeed(state, WATERFALL_NOW_MS);

      expect(beforeBehavior.current?.id).assertEqual('youtube-next');
      expect(update.state.shown.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('consumed');
      expect(update.state.current?.id).assertEqual('x-next');
      expect(update.state.current?.id === beforeBehavior.current?.id).assertFalse();
      expect(waterfallInventoryIds(update.state).indexOf('consumed')).assertEqual(0);
      expect(update.state.stable.concat(update.state.tail, update.state.reserve ?? [])
        .some((item: WaterfallRankedCandidate): boolean => item.id === 'consumed')).assertFalse();
    });

    it('keeps interest advance ranking deterministic when the profile is unchanged', 0, () => {
      const state = feedState(
        rankedWaterfallCandidate('deterministic-current', 'youtube', 'OpenAI Codex current', 0),
        [
          rankedWaterfallCandidate('deterministic-youtube', 'youtube', 'OpenAI Codex video', 1),
          rankedWaterfallCandidate('deterministic-x', 'x', 'OpenAI Codex post', 2)
        ],
        [rankedWaterfallCandidate('deterministic-reddit', 'reddit', 'OpenAI Codex thread', 3)],
        [sourceState('youtube', null, 'exhausted'), sourceState('x', null, 'exhausted'),
          sourceState('reddit', null, 'exhausted')]
      );
      state.mode = 'interest';
      state.profile = emptyPreferenceProfile();

      const first = advanceWaterfallFeed(state, WATERFALL_NOW_MS).state;
      const second = advanceWaterfallFeed(state, WATERFALL_NOW_MS).state;

      expect(waterfallInventoryIds(first).join(',')).assertEqual(waterfallInventoryIds(second).join(','));
    });

    it('reranks only the bounded active interest window and preserves overflow reserve', 0, () => {
      const remaining: WaterfallRankedCandidate[] = [];
      for (let index = 0; index < 59; index += 1) {
        remaining.push(rankedWaterfallCandidate(
          'bounded-' + index.toString(), index % 2 === 0 ? 'youtube' : 'x',
          'OpenAI Codex bounded ' + index.toString(), index + 1));
      }
      const state = feedState(
        rankedWaterfallCandidate('bounded-current', 'youtube', 'OpenAI Codex current', 0),
        remaining.slice(0, 2), remaining.slice(2, 19),
        [sourceState('youtube', null, 'exhausted'), sourceState('x', null, 'exhausted')]
      );
      state.mode = 'interest';
      state.profile = emptyPreferenceProfile();
      state.reserve = remaining.slice(19);

      const first = advanceWaterfallFeed(state, WATERFALL_NOW_MS).state;
      const firstReserveHead = first.reserve?.[0].id ?? '';
      const second = advanceWaterfallFeed(first, WATERFALL_NOW_MS).state;
      const third = advanceWaterfallFeed(second, WATERFALL_NOW_MS).state;
      const activeCount = (first.current === null ? 0 : 1) + first.stable.length + first.tail.length;
      const secondActive = (second.current === null ? [] : [second.current]).concat(second.stable, second.tail);

      expect(activeCount).assertEqual(20);
      expect(first.reserve?.length).assertEqual(39);
      expect(second.reserve?.length).assertEqual(38);
      expect(third.reserve?.length).assertEqual(37);
      expect(secondActive.some((item: WaterfallRankedCandidate): boolean => item.id === firstReserveHead)).assertTrue();
      expect(waterfallInventoryIds(first).length).assertEqual(60);
      expect(waterfallInventoryIds(second).length).assertEqual(60);
      expect(waterfallInventoryIds(third).length).assertEqual(60);
      expect(first.shown.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('bounded-current');
      expect(third.shown.length).assertEqual(3);
    });

    it('reorders all unshown items after an explicit source toggle', 0, () => {
      const state = feedState(
        rankedWaterfallCandidate('youtube-current', 'youtube', 'OpenAI Codex YouTube', 0),
        [rankedWaterfallCandidate('x-next', 'x', 'OpenAI Codex X', 1)],
        [rankedWaterfallCandidate('youtube-tail', 'youtube', 'OpenAI Codex YouTube tail', 2)],
        [sourceState('youtube', null), sourceState('x', null)]
      );
      const update = applyWaterfallSourceSelection(state, ['x'], WATERFALL_NOW_MS);

      expect(update.state.shown.map((item) => item.id).join(',')).assertEqual('youtube-current');
      expect(update.state.current?.id).assertEqual('x-next');
      expect(update.state.stable.length).assertEqual(0);
      expect(update.state.tail.map((item) => item.id).join(',')).assertEqual('youtube-tail');
    });

    it('keeps an explicit empty source selection across a late snapshot', 0, () => {
      const incoming = feedState(
        rankedWaterfallCandidate('youtube-current', 'youtube', 'OpenAI Codex YouTube', 0),
        [rankedWaterfallCandidate('youtube-next', 'youtube', 'OpenAI Codex YouTube next', 1)],
        [],
        [sourceState('youtube', null)]
      );
      const disabled = applyWaterfallSourceSelection(incoming, [], WATERFALL_NOW_MS).state;
      const late = mergeWaterfallFeedSnapshot(disabled, incoming, WATERFALL_NOW_MS);

      expect(late.state.enabledSources.length).assertEqual(0);
      expect(planWaterfallContinuation(disabled).expansionRequest).assertEqual(undefined);
      expect(late.state.current).assertEqual(null);
      expect(late.state.stable.length).assertEqual(0);
      expect(late.state.tail.map((item) => item.id).join(',')).assertEqual('youtube-next');
    });

    it('merges partial snapshots cheaply and ranks a settled snapshot once', 0, () => {
      const duplicateA = rankWaterfallCandidates({
        query: 'OpenAI Codex agent',
        candidates: [traditionalCandidate(
          'snapshot-dup-a', 'youtube', 'OpenAI Codex agent 工具发布', '全新 agent 工具能力介绍',
          'https://youtube.test/snapshot-dup-a', 1, 0
        )],
        enabledSources: ['youtube'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const duplicateB = rankWaterfallCandidates({
        query: 'OpenAI Codex agent',
        candidates: [traditionalCandidate(
          'snapshot-dup-b', 'reddit', 'OpenAI Codex agent 工具发布', '全新 agent 工具能力介绍',
          'https://reddit.test/snapshot-dup-b', 1, 1
        )],
        enabledSources: ['reddit'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const tailDuplicateA = rankWaterfallCandidates({
        query: 'OpenAI Codex agent',
        candidates: [traditionalCandidate(
          'snapshot-tail-dup-a', 'youtube', 'Codex agent 任务编排实践', '多代理 agent 任务编排实践介绍',
          'https://youtube.test/snapshot-tail-dup-a', 2, 2
        )],
        enabledSources: ['youtube'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const tailDuplicateB = rankWaterfallCandidates({
        query: 'OpenAI Codex agent',
        candidates: [traditionalCandidate(
          'snapshot-tail-dup-b', 'reddit', 'Codex agent 任务编排实践', '多代理 agent 任务编排实践介绍',
          'https://reddit.test/snapshot-tail-dup-b', 2, 3
        )],
        enabledSources: ['reddit'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const distinct = rankedWaterfallCandidate('snapshot-distinct', 'reddit', 'OpenAI Codex release notes', 4);
      const loading = feedState(null, [], [], [
        sourceState('youtube', null, 'loading', true),
        sourceState('reddit', null, 'loading', true)
      ]);
      const incomingPartial = feedState(duplicateA, [duplicateB], [], [
        sourceState('youtube', null),
        sourceState('reddit', null, 'loading', true)
      ]);

      const partial = mergeWaterfallFeedSnapshot(loading, incomingPartial, WATERFALL_NOW_MS, false);
      expect(waterfallInventoryIds(partial.state).filter(
        (id: string): boolean => id.indexOf('snapshot-dup-') === 0).length).assertEqual(2);
      expect(partial.state.tail.concat(partial.state.stable).every(
        (item: WaterfallRankedCandidate): boolean => item.reason === '等待最终排序')).assertTrue();
      expect(partial.state.sources[1].inFlight).assertTrue();

      const incomingFinal = feedState(duplicateA, [duplicateB], [tailDuplicateA, tailDuplicateB, distinct], [
        sourceState('youtube', null),
        sourceState('reddit', null)
      ]);
      const finalUpdate = mergeWaterfallFeedSnapshot(partial.state, incomingFinal, WATERFALL_NOW_MS, false);
      const finalIds = waterfallInventoryIds(finalUpdate.state);
      expect(finalUpdate.state.current?.id).assertEqual('snapshot-dup-a');
      expect(finalUpdate.state.stable[0].id).assertEqual('snapshot-dup-b');
      expect(finalIds.filter((id: string): boolean => id.indexOf('snapshot-dup-') === 0).length).assertEqual(2);
      expect(finalIds.filter((id: string): boolean => id.indexOf('snapshot-tail-dup-') === 0).length).assertEqual(1);
      expect(finalIds.indexOf('snapshot-distinct') >= 0).assertTrue();
    });

    it('keeps the rendered current and stable window while finalizing only the tail', 0, () => {
      const fixedCurrent = rankedWaterfallCandidate('fixed-current', 'youtube', 'Pinned current', 0);
      const fixedStable = [
        rankedWaterfallCandidate('fixed-stable-1', 'youtube', 'Pinned next one', 1),
        rankedWaterfallCandidate('fixed-stable-2', 'reddit', 'Pinned next two', 2)
      ];
      const local = feedState(
        fixedCurrent,
        fixedStable,
        [rankedWaterfallCandidate('old-unrelated', 'youtube', 'Cooking guide', 3)],
        [sourceState('youtube', null), sourceState('reddit', null)]
      );
      const unrelated = rankedWaterfallCandidate('new-unrelated', 'youtube', 'Travel guide', 4);
      const exact = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [traditionalCandidate(
          'new-exact', 'reddit', 'OpenAI Codex exact result', 'OpenAI Codex agent details',
          'https://reddit.test/final-exact', 1, 5
        )],
        enabledSources: ['reddit'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const exactDuplicate = rankWaterfallCandidates({
        query: 'openai codex',
        candidates: [traditionalCandidate(
          'new-exact-duplicate', 'reddit', 'OpenAI Codex exact duplicate', 'OpenAI Codex agent details',
          'https://reddit.test/final-exact', 2, 6
        )],
        enabledSources: ['reddit'], shownIds: [], stableIds: [], preferenceDescription: ''
      }, WATERFALL_NOW_MS)[0];
      const incomingFinal = feedState(unrelated, [exact, exactDuplicate], [], [
        sourceState('youtube', null), sourceState('reddit', null)
      ]);

      const update = mergeWaterfallFeedSnapshot(local, incomingFinal, WATERFALL_NOW_MS, false);
      expect(update.state.current?.id).assertEqual('fixed-current');
      expect(update.state.stable.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('fixed-stable-1,fixed-stable-2');
      expect(update.state.tail[0].id).assertEqual('new-exact');
      expect(update.state.tail.filter((item: WaterfallRankedCandidate): boolean =>
        item.normalizedUrl === 'https://reddit.test/final-exact').length).assertEqual(1);
    });

    it('restores unseen candidates only after the user reopens a source', 0, () => {
      const incoming = feedState(
        rankedWaterfallCandidate('youtube-current', 'youtube', 'OpenAI Codex YouTube', 0),
        [rankedWaterfallCandidate('youtube-next', 'youtube', 'OpenAI Codex YouTube next', 1)],
        [],
        [sourceState('youtube', null)]
      );
      const disabled = applyWaterfallSourceSelection(incoming, [], WATERFALL_NOW_MS).state;
      const reopened = applyWaterfallSourceSelection(disabled, ['youtube'], WATERFALL_NOW_MS).state;

      expect(reopened.enabledSources.join(',')).assertEqual('youtube');
      expect(reopened.current?.id).assertEqual('youtube-next');
    });

    it('searches a newly enabled source missing from the current feed state', 0, () => {
      const state = feedState(null, [], [], [sourceState('youtube', null, 'exhausted')]);
      const update = applyWaterfallSourceSelection(state, ['youtube', 'x'], WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(1);
      expect(update.loadRequests[0].source).assertEqual('x');
      expect(update.loadRequests[0].mode).assertEqual('search');
      expect(update.state.sources.map((source: WaterfallSourceState): string => source.source).join(','))
        .assertEqual('youtube,x');
    });

    it('keeps twenty ready items and starts one six-source refill only after reserve is insufficient', 0, () => {
      const sourceNames = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];
      const sources = sourceNames.map((source: string) =>
        sourceState(source, { kind: source === 'x' ? 'cursor' : 'page', value: '2' }));
      const incoming: WaterfallCandidate[] = [];
      for (let index = 0; index < 60; index++) {
        const source = sourceNames[index % sourceNames.length];
        incoming.push(waterfallCandidate(
          'item-' + index.toString(), source, 'OpenAI Codex ' + index.toString(), '',
          'https://' + source + '.test/item-' + index.toString(), '2026-08-06T10:00:00.000Z', index
        ));
      }
      const seeded = mergeWaterfallBatch(feedState(null, [], [], sources), incoming, sources[0], WATERFALL_NOW_MS);

      expect((seeded.state.current === null ? 0 : 1) + seeded.state.stable.length + seeded.state.tail.length).assertEqual(20);
      expect(seeded.state.reserve?.length).assertEqual(40);
      const repeated = mergeWaterfallFeedSnapshot(seeded.state, seeded.state, WATERFALL_NOW_MS, false);
      expect(repeated.state.reserve?.length).assertEqual(40);
      let state = seeded.state;
      for (let index = 0; index < 17; index++) {
        state = advanceWaterfallFeed(state, WATERFALL_NOW_MS).state;
      }
      const fromReserve = planWaterfallContinuation(state);

      expect(fromReserve.loadRequests.length).assertEqual(0);
      expect((fromReserve.state.current === null ? 0 : 1) + fromReserve.state.stable.length + fromReserve.state.tail.length).assertEqual(20);
      expect(fromReserve.state.reserve?.length).assertEqual(23);

      const low = feedState(
        rankedWaterfallCandidate('low-current', 'youtube', 'OpenAI Codex current', 100),
        [
          rankedWaterfallCandidate('low-next-1', 'x', 'OpenAI Codex next', 101),
          rankedWaterfallCandidate('low-next-2', 'reddit', 'OpenAI Codex next', 102)
        ],
        [],
        sources
      );
      low.enabledSources = ['youtube'];
      const refill = planWaterfallContinuation(low);

      expect(refill.loadRequests.length).assertEqual(6);
      expect(refill.loadRequests.map((request) => request.source).join(',')).assertEqual(sourceNames.join(','));
      expect(refill.loadRequests.every((request) => request.limit === 10)).assertTrue();
    });

    it('retains deferred reserve candidates across later partial source batches', 0, () => {
      const sourceNames = ['youtube', 'bilibili', 'x', 'reddit'];
      let state = feedState(null, [], [], sourceNames.map((source: string): WaterfallSourceState =>
        sourceState(source, null, 'loading', true, 10)));
      for (let batch = 0; batch < sourceNames.length; batch++) {
        const incoming: WaterfallCandidate[] = [];
        for (let item = 0; item < 10; item++) {
          const id = 'deferred-' + batch.toString() + '-' + item.toString();
          incoming.push(waterfallCandidate(
            id, sourceNames[batch], 'Unique item ' + id, 'Source batch ' + batch.toString(),
            'https://' + sourceNames[batch] + '.test/' + id, '2026-08-06T10:00:00.000Z', batch * 10 + item
          ));
        }
        state = mergeWaterfallBatchDeferredRanking(
          state, incoming, sourceState(sourceNames[batch], null)
        ).state;
      }

      expect(waterfallInventoryIds(state).length).assertEqual(40);
      expect((state.current === null ? 0 : 1) + state.stable.length + state.tail.length).assertEqual(20);
      expect(state.reserve?.length).assertEqual(20);
    });

    it('requests ten items per source when inventory reaches three', 0, () => {
      const source = sourceState('youtube', { kind: 'cursor', value: 'next-cursor' });
      const state = feedState(
        rankedWaterfallCandidate('current', 'youtube', 'OpenAI Codex current', 0),
        [rankedWaterfallCandidate('stable', 'youtube', 'OpenAI Codex stable', 1)],
        [rankedWaterfallCandidate('tail-1', 'youtube', 'OpenAI Codex tail 1', 2)],
        [source]
      );
      const update = mergeWaterfallBatch(state, [], source, WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(1);
      expect(update.loadRequests[0].limit).assertEqual(10);
      expect(update.state.sources[0].inFlight).assertTrue();
    });

    it('does not start another round while one source is in flight', 0, () => {
      const reserved = sourceState('youtube', { kind: 'cursor', value: 'reserved' }, 'success', true, 4);
      const available = sourceState('x', { kind: 'page', value: 'page-2' });
      const state = feedState(
        rankedWaterfallCandidate('current', 'youtube', 'OpenAI Codex current', 0),
        [rankedWaterfallCandidate('stable', 'youtube', 'OpenAI Codex stable', 1)],
        [rankedWaterfallCandidate('tail', 'x', 'OpenAI Codex tail', 2), rankedWaterfallCandidate('tail-2', 'x', 'OpenAI Codex tail 2', 3)],
        [reserved, available]
      );
      const update = mergeWaterfallBatch(state, [], available, WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(0);
    });

    it('allows only one in-flight request per source', 0, () => {
      const source = sourceState('youtube', { kind: 'cursor', value: 'next-cursor' }, 'success', true, 5);
      const state = feedState(
        rankedWaterfallCandidate('current', 'youtube', 'OpenAI Codex current', 0),
        [rankedWaterfallCandidate('stable', 'youtube', 'OpenAI Codex stable', 1)],
        [],
        [source]
      );
      const update = advanceWaterfallFeed(state, WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.state.sources[0].inFlight).assertTrue();
    });

    it('marks a source exhausted when it has no continuation', 0, () => {
      const source = sourceState('youtube', null, 'success');
      const update = mergeWaterfallBatch(feedState(null, [], [], [source]), [], source, WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.state.sources[0].phase).assertEqual('exhausted');
    });

    it('ends the round when every enabled source is exhausted', 0, () => {
      const sources = [sourceState('youtube', null, 'exhausted'), sourceState('x', null, 'exhausted')];
      const update = advanceWaterfallFeed(feedState(null, [], [], sources), WATERFALL_NOW_MS);

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.state.current).assertEqual(null);
      expect(update.state.sources.map((item) => item.phase).join(',')).assertEqual('exhausted,exhausted');
    });

    it('expands from original query to related query and then adjacent topic', 0, () => {
      const related = planWaterfallContinuation(exhaustedFeed('original'));
      expect(related.loadRequests.length).assertEqual(0);
      expect(related.expansionRequest?.stage).assertEqual('related');

      const relatedSearch = applyWaterfallExpandedQuery(
        related.state, 'related', 'OpenAI Codex agent tools', WATERFALL_NOW_MS
      );
      expect(relatedSearch.state.query).assertEqual('OpenAI Codex agent tools');
      expect(relatedSearch.state.queryStage).assertEqual('related');
      expect(relatedSearch.loadRequests.length).assertEqual(6);
      expect(relatedSearch.loadRequests.every((request) => request.continuation === null)).assertTrue();

      const adjacent = planWaterfallContinuation(exhaustedFeed('related'));
      expect(adjacent.expansionRequest?.stage).assertEqual('adjacent');
    });

    it('ends after adjacent search and two consecutive rounds add no globally new content', 0, () => {
      const firstEmpty = planWaterfallContinuation(exhaustedFeed('adjacent', 1));
      expect(firstEmpty.expansionRequest).assertEqual(undefined);
      expect(firstEmpty.state.queryStage).assertEqual('done');
      expect(firstEmpty.state.sources.every((source) => source.phase === 'exhausted')).assertTrue();
    });

    it('moves to the next expansion stage after two empty paginated rounds', 0, () => {
      const state = feedState(null, [], [], [sourceState('youtube', { kind: 'cursor', value: 'still-more' })]);
      state.queryStage = 'related';
      state.originalQuery = 'openai codex';
      state.queryHistory = ['openai codex', 'OpenAI Codex agent tools'];
      state.consecutiveEmptyRounds = 1;
      state.roundActive = true;
      state.roundNewItemCount = 0;
      const update = planWaterfallContinuation(state);

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.expansionRequest?.stage).assertEqual('adjacent');
      expect(update.state.queryStage).assertEqual('related');
      expect(update.state.sources[0].continuation).assertEqual(null);
    });

    it('parses exactly one safe expanded query and rejects malformed or unchanged output', 0, () => {
      expect(parseWaterfallExpandedQuery('{"query":"OpenAI Codex agent tools"}', 'openai codex')).assertEqual(
        'OpenAI Codex agent tools'
      );
      expect(parseWaterfallExpandedQuery('```json\n{"query":"OpenAI Codex ecosystem"}\n```', 'openai codex')).assertEqual(
        'OpenAI Codex ecosystem'
      );
      expect(parseWaterfallExpandedQuery('{"query":"openai codex"}', 'openai codex')).assertEqual('');
      expect(parseWaterfallExpandedQuery('not json', 'openai codex')).assertEqual('');
      expect(parseWaterfallExpandedQuery('{"query":"' + 'x'.repeat(121) + '"}', 'openai codex')).assertEqual('');
    });

    it('falls through one failed related expansion but ends after adjacent expansion fails', 0, () => {
      const related = failWaterfallExpansion(exhaustedFeed('original'), 'related');
      expect(related.expansionRequest?.stage).assertEqual('adjacent');
      const adjacent = failWaterfallExpansion(related.state, 'adjacent');
      expect(adjacent.expansionRequest).assertEqual(undefined);
      expect(adjacent.state.queryStage).assertEqual('done');
    });

    it('counts duplicate expanded results as zero globally new items', 0, () => {
      const original = rankedWaterfallCandidate('original', 'youtube', 'OpenAI Codex', 0);
      const state = feedState(original, [], [], [sourceState('youtube', null, 'exhausted')]);
      const expanded = applyWaterfallExpandedQuery(state, 'related', 'OpenAI agent tools', WATERFALL_NOW_MS).state;
      const duplicate = waterfallCandidate(
        'duplicate-id', 'youtube', 'Same result', '', original.url + '#again',
        '2026-08-06T11:00:00.000Z', 2
      );
      duplicate.searchQuery = 'OpenAI agent tools';
      duplicate.queryStage = 'related';
      const merged = mergeWaterfallBatch(
        expanded, [duplicate], sourceState('youtube', null, 'exhausted'), WATERFALL_NOW_MS, false
      ).state;

      expect(merged.roundNewItemCount).assertEqual(0);
      expect(merged.tail.length + (merged.reserve?.length ?? 0)).assertEqual(0);
    });

    it('keeps auth and error source states truthful while another source refills', 0, () => {
      const sources = [
        sourceState('youtube', { kind: 'cursor', value: 'next' }),
        sourceState('x', null, 'needs_auth'),
        sourceState('reddit', null, 'error')
      ];
      const state = feedState(
        rankedWaterfallCandidate('current', 'youtube', 'OpenAI Codex current', 0),
        [rankedWaterfallCandidate('next-1', 'youtube', 'OpenAI Codex next', 1),
          rankedWaterfallCandidate('next-2', 'youtube', 'OpenAI Codex next', 2)],
        [],
        sources
      );
      const update = planWaterfallContinuation(state);

      expect(update.loadRequests.map((request) => request.source).join(',')).assertEqual('youtube,x,reddit');
      expect(update.state.sources.map((source) => source.phase).join(',')).assertEqual('success,needs_auth,error');
    });

    it('executes only real native continuations while all six sources finish the round', 0, async () => {
      const sourceNames: AggregateSearchSource[] = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];
      const sources = sourceNames.map((source: AggregateSearchSource): WaterfallSourceState =>
        sourceState(source, source === 'bilibili' ? { kind: 'page', value: '2' } : null));
      const low = feedState(
        rankedWaterfallCandidate('current', 'youtube', 'OpenAI Codex current', 0),
        [rankedWaterfallCandidate('next-1', 'x', 'OpenAI Codex next', 1),
          rankedWaterfallCandidate('next-2', 'reddit', 'OpenAI Codex next', 2)],
        [],
        sources
      );
      const requests: WaterfallLoadRequest[] = planWaterfallContinuation(low).loadRequests;
      const received: string[] = [];
      const loaded: string[] = [];
      const loadSource = (
        source: AggregateSearchSource,
        _query: string,
        _youtubeApiKey: string,
        _zhihuConfig: AggregateZhihuConfig,
        _continuation: WaterfallContinuation | null,
        _limit: number
      ): Promise<AggregateSearchSourceBatch> => {
        loaded.push(source);
        return Promise.resolve(aggregateBatch(source, 'network-' + source));
      };

      await callAggregateSearchContinuation(
        'openai codex', requests, '', { apiKey: '' },
        (batch: AggregateSearchSourceBatch): void => {
          if (batch.videos.length > 0) {
            received.push(batch.videos[0].id);
          }
        },
        loadSource
      );

      expect(requests.length).assertEqual(6);
      expect(loaded.join(',')).assertEqual('bilibili');
      expect(received.join(',')).assertEqual('network-bilibili');
    });

    it('executes all six sources for a related or adjacent search query', 0, async () => {
      const expanded = applyWaterfallExpandedQuery(
        exhaustedFeed('original'), 'related', 'OpenAI Codex agent tools', WATERFALL_NOW_MS
      );
      const loaded: string[] = [];
      await callAggregateSearchContinuation(
        expanded.state.query, expanded.loadRequests, '', { apiKey: '' },
        (_batch: AggregateSearchSourceBatch): void => {},
        (source: AggregateSearchSource): Promise<AggregateSearchSourceBatch> => {
          loaded.push(source);
          return Promise.resolve(aggregateBatch(source, 'expanded-' + source));
        }
      );

      expect(loaded.join(',')).assertEqual('youtube,bilibili,x,hackernews,reddit,zhihu');
    });

    it('dispatches Twitch only for interest continuation context', 0, async () => {
      configureWaterfallEnabledSourcesForRuntime(['youtube', 'twitch']);
      configureWaterfallSearchPolicyForRuntime({ domesticOnly: false, multilingual: true });
      const requests: WaterfallLoadRequest[] = [{
        source: 'youtube', continuation: null, limit: 10, phase: 'loading', message: '', mode: 'search'
      }, {
        source: 'twitch', continuation: null, limit: 10, phase: 'loading', message: '', mode: 'search'
      }];
      const ordinaryLoaded: string[] = [];
      const interestLoaded: string[] = [];
      const loaderFor = (loaded: string[]) => (
        source: AggregateSearchSource
      ): Promise<AggregateSearchSourceBatch> => {
        loaded.push(source);
        return Promise.resolve(aggregateBatch(source, 'context-' + source));
      };

      try {
        await callAggregateSearchContinuation(
          '', requests, '', { apiKey: '' },
          (_batch: AggregateSearchSourceBatch): void => {}, loaderFor(ordinaryLoaded)
        );
        await callAggregateSearchContinuationForContext(
          'interest', '', requests, '', { apiKey: '' },
          (_batch: AggregateSearchSourceBatch): void => {}, loaderFor(interestLoaded)
        );

        expect(ordinaryLoaded.join(',')).assertEqual('youtube');
        expect(interestLoaded.join(',')).assertEqual('youtube,twitch');
      } finally {
        configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
        configureWaterfallSearchPolicyForRuntime({ domesticOnly: true, multilingual: false });
      }
    });

    it('intersects interest recalls with enabled sources and the runtime search policy', 0, async () => {
      configureWaterfallEnabledSourcesForRuntime(['bilibili', 'youtube', 'hackernews', 'twitch']);
      configureWaterfallSearchPolicyForRuntime({ domesticOnly: true, multilingual: false });
      const requests: WaterfallLoadRequest[] = ['bilibili', 'zhihu', 'youtube', 'hackernews', 'twitch'].map(
        (source: string): WaterfallLoadRequest => ({
          source: source, continuation: null, limit: 10, phase: 'loading', message: '', mode: 'search'
        })
      );
      const loaded: string[] = [];
      try {
        await callAggregateSearchContinuationForContext(
          'interest', '', requests, '', { apiKey: '' },
          (_batch: AggregateSearchSourceBatch): void => {},
          (source: AggregateSearchSource): Promise<AggregateSearchSourceBatch> => {
            loaded.push(source);
            return Promise.resolve(aggregateBatch(source, 'filtered-' + source));
          }
        );
        expect(loaded.join(',')).assertEqual('bilibili');
      } finally {
        configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
        configureWaterfallSearchPolicyForRuntime({ domesticOnly: true, multilingual: false });
      }
    });

    it('passes the configured multilingual policy into interest recall source loading', 0, async () => {
      const configured: AggregateSearchPolicy = { domesticOnly: false, multilingual: true };
      configureWaterfallSearchPolicyForRuntime(configured);
      const observed: AggregateSearchPolicy[] = [];
      const requests: WaterfallLoadRequest[] = [{
        source: 'twitch', continuation: null, limit: 10, phase: 'loading', message: '', mode: 'search'
      }];

      await callAggregateSearchContinuationForContext(
        'interest', '', requests, '', { apiKey: '' },
        (_batch: AggregateSearchSourceBatch): void => {},
        (
          source: AggregateSearchSource,
          _query: string,
          _youtubeApiKey: string,
          _zhihuConfig: AggregateZhihuConfig,
          _continuation: WaterfallContinuation | null,
          _limit: number,
          policy: AggregateSearchPolicy
        ): Promise<AggregateSearchSourceBatch> => {
          observed.push(policy);
          return Promise.resolve(aggregateBatch(source, 'policy-' + source));
        }
      );

      expect(observed.length).assertEqual(1);
      expect(observed[0].domesticOnly).assertFalse();
      expect(observed[0].multilingual).assertTrue();
      expect(waterfallSearchPolicyForRuntime().multilingual).assertTrue();
      configureWaterfallSearchPolicyForRuntime({ domesticOnly: true, multilingual: false });
    });

    it('emits a partial aggregate snapshot as soon as one source resolves', 0, async () => {
      let resolveYoutube: (batch: AggregateSearchSourceBatch) => void = (_batch: AggregateSearchSourceBatch): void => {};
      const youtube = new Promise<AggregateSearchSourceBatch>((resolve: (batch: AggregateSearchSourceBatch) => void): void => {
        resolveYoutube = resolve;
      });
      const snapshots: AggregateSearchResult[] = [];
      let completed = false;
      const bilibiliBatch = aggregateBatch('bilibili', 'bilibili-first');
      bilibiliBatch.videos.push({
        id: 'bilibili-second', source: 'bilibili', provider: 'bilibili', title: 'OpenAI Codex bilibili-second', summary: 'batch bilibili-second',
        url: 'https://bilibili.test/bilibili-second', thumbnail: '', publishedAt: '2026-08-06T09:00:00.000Z', duration: '', status: 'success', rows: []
      });
      bilibiliBatch.videos.push({
        id: 'bilibili-third', source: 'bilibili', provider: 'bilibili', title: 'OpenAI Codex bilibili-third', summary: 'batch bilibili-third',
        url: 'https://bilibili.test/bilibili-third', thumbnail: '', publishedAt: '2026-08-06T08:00:00.000Z', duration: '', status: 'success', rows: []
      });
      const finalPromise = streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'bilibili', 'x'],
        [youtube, Promise.resolve(bilibiliBatch), Promise.resolve(aggregateBatch('x', 'x-auth', 'needs_auth'))],
        (result: AggregateSearchResult): void => {
          snapshots.push(result);
        },
        WATERFALL_NOW_MS,
        '',
        0
      ).then((result: AggregateSearchResult): AggregateSearchResult => {
        completed = true;
        return result;
      });

      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 0);
      });
      expect(snapshots.length).assertLarger(0);
      expect(snapshots[0].videos[0].source).assertEqual('bilibili');
      expect(snapshots[0].waterfall?.sources[0].phase).assertEqual('loading');
      expect(completed).assertFalse();

      resolveYoutube(aggregateBatch('youtube', 'youtube-second'));
      const result = await finalPromise;
      expect(snapshots.length).assertEqual(3);
      expect(result.videos.length).assertEqual(4);
      expect(result.waterfall?.current === null).assertFalse();
      expect(result.sourceStatuses[2].status).assertEqual('needs_auth');
      expect(result.waterfall?.sources.every((item) => item.continuation === null)).assertTrue();
    });

    it('defers duplicate suppression until the complete aggregate result is finalized', 0, async () => {
      const firstBatch = aggregateBatch('youtube', 'dup-a');
      firstBatch.videos[0].title = 'OpenAI Codex agent 工具发布';
      firstBatch.videos[0].summary = '全新 agent 工具能力介绍';
      firstBatch.videos.push({
        id: 'dup-b', source: 'reddit', provider: 'reddit', title: 'OpenAI Codex agent 工具发布',
        summary: '全新 agent 工具能力介绍', url: 'https://reddit.test/dup-b', thumbnail: '',
        publishedAt: '2026-08-06T09:00:00.000Z', duration: '', status: 'success', rows: []
      });
      const deferred = new DeferredAggregateBatch();
      const snapshots: AggregateSearchResult[] = [];
      const finalPromise = streamAggregateSearchSourceBatches(
        'OpenAI Codex agent',
        ['youtube', 'reddit'],
        [Promise.resolve(firstBatch), deferred.promise],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS,
        '',
        0
      );

      await settleAggregateSearchMicrotasks();
      expect(snapshots.length).assertEqual(1);
      const partialIds = waterfallInventoryIds(snapshots[0].waterfall);
      expect(partialIds.filter((id: string): boolean => id.indexOf('dup-') === 0).length).assertEqual(2);

      deferred.finish(aggregateBatch('reddit', 'distinct'));
      const result = await finalPromise;
      const finalIds = waterfallInventoryIds(result.waterfall);
      expect(finalIds.filter((id: string): boolean => id.indexOf('dup-') === 0).length).assertEqual(1);
      expect(finalIds.indexOf('distinct') >= 0).assertTrue();
    });

    it('emits only the first partial during a burst and returns the complete final snapshot', 0, async () => {
      const snapshots: AggregateSearchResult[] = [];
      const result = await streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'bilibili', 'x'],
        [
          Promise.resolve(aggregateBatch('youtube', 'youtube-first')),
          Promise.resolve(aggregateBatch('bilibili', 'bilibili-second')),
          Promise.resolve(aggregateBatch('x', 'x-third'))
        ],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS
      );

      expect(snapshots.length).assertEqual(1);
      expect(snapshots[0].videos.length).assertEqual(1);
      expect(result.videos.length).assertEqual(3);
      expect(result.sourceStatuses.length).assertEqual(3);
    });

    it('uses a five-second default and emits the first partial without waiting for the timer', 0, async () => {
      expect(AGGREGATE_SEARCH_PARTIAL_THROTTLE_MS).assertEqual(5000);
      const deferred = new DeferredAggregateBatch();
      const snapshots: AggregateSearchResult[] = [];
      let completed = false;
      const finalPromise = streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'bilibili'],
        [Promise.resolve(aggregateBatch('youtube', 'youtube-first')), deferred.promise],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS,
        '',
        100
      ).then((result: AggregateSearchResult): AggregateSearchResult => {
        completed = true;
        return result;
      });

      await settleAggregateSearchMicrotasks();
      expect(snapshots.length).assertEqual(1);
      expect(snapshots[0].videos[0].id).assertEqual('youtube-first');
      expect(completed).assertFalse();

      deferred.finish(aggregateBatch('bilibili', 'bilibili-final'));
      const result = await finalPromise;
      expect(result.videos.length).assertEqual(2);
      expect(completed).assertTrue();
    });

    it('restarts the trailing debounce and emits only the latest pending partial after silence', 0, async () => {
      const secondBatch = new DeferredAggregateBatch();
      const thirdBatch = new DeferredAggregateBatch();
      const finalBatch = new DeferredAggregateBatch();
      const snapshots: AggregateSearchResult[] = [];
      const finalPromise = streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'bilibili', 'x', 'reddit'],
        [
          Promise.resolve(aggregateBatch('youtube', 'youtube-first')),
          secondBatch.promise,
          thirdBatch.promise,
          finalBatch.promise
        ],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS,
        '',
        200
      );

      await settleAggregateSearchMicrotasks();
      expect(snapshots.length).assertEqual(1);

      secondBatch.finish(aggregateBatch('bilibili', 'bilibili-second'));
      await settleAggregateSearchMicrotasks();
      await waitForAggregateThrottle(50);
      thirdBatch.finish(aggregateBatch('x', 'x-third'));
      await settleAggregateSearchMicrotasks();
      await waitForAggregateThrottle(170);
      expect(snapshots.length).assertEqual(1);

      await waitForAggregateThrottle(70);
      expect(snapshots.length).assertEqual(2);
      expect(snapshots[0].videos.length).assertEqual(1);
      expect(snapshots[1].videos.length).assertEqual(3);
      expect(snapshots[1].videos[2].id).assertEqual('x-third');

      finalBatch.finish(aggregateBatch('reddit', 'reddit-final'));
      const result = await finalPromise;
      expect(result.videos.length).assertEqual(4);
    });

    it('cancels a pending partial timer before returning final without leaking later updates', 0, async () => {
      const snapshots: AggregateSearchResult[] = [];
      const result = await streamAggregateSearchSourceBatches(
        'openai codex',
        ['youtube', 'bilibili'],
        [
          Promise.resolve(aggregateBatch('youtube', 'youtube-first')),
          Promise.resolve(aggregateBatch('bilibili', 'bilibili-pending'))
        ],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS,
        '',
        100
      );

      expect(result.videos.length).assertEqual(2);
      expect(snapshots.length).assertEqual(1);
      await waitForAggregateThrottle(130);
      expect(snapshots.length).assertEqual(1);
    });

    it('preserves preference metadata across partial and final snapshots without changing ranking', 0, async () => {
      const preferenceDescription = '中文优先；15 分钟内；图文 > 短视频 > 长视频';
      const args: QueryArgsFixture = {
        query: 'HarmonyOS Agent 推荐系统',
        sources: ['youtube'],
        preferenceDescription: preferenceDescription
      };
      const snapshots: AggregateSearchResult[] = [];
      const result = await streamAggregateSearchSourceBatches(
        args.query,
        args.sources as AggregateSearchSource[],
        [Promise.resolve(aggregateBatch('youtube', 'harmonyos-agent'))],
        (snapshot: AggregateSearchResult): void => {
          snapshots.push(snapshot);
        },
        WATERFALL_NOW_MS,
        args.preferenceDescription as string
      );
      const withoutPreference = rankWaterfallCandidates({
        query: args.query,
        candidates: aggregateMediaCandidates(result.videos, result.posts, 0),
        enabledSources: args.sources as AggregateSearchSource[],
        shownIds: [],
        stableIds: [],
        preferenceDescription: ''
      }, WATERFALL_NOW_MS);
      const withPreference = rankWaterfallCandidates({
        query: args.query,
        candidates: aggregateMediaCandidates(result.videos, result.posts, 0),
        enabledSources: args.sources as AggregateSearchSource[],
        shownIds: [],
        stableIds: [],
        preferenceDescription: args.preferenceDescription as string
      }, WATERFALL_NOW_MS);

      expect(snapshots.length).assertEqual(1);
      expect(snapshots[0].waterfall?.preferenceDescription).assertEqual(preferenceDescription);
      expect(result.waterfall?.preferenceDescription).assertEqual(preferenceDescription);
      expect(withPreference.map((item) => item.id).join(',')).assertEqual(withoutPreference.map((item) => item.id).join(','));
    });
  });
}
