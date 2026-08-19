import { describe, it, expect } from '@ohos/hypium';
import {
  WaterfallFeedState,
  WaterfallContinuation,
  WaterfallInterestRecallRequest,
  WaterfallPreferenceSnapshot,
  WaterfallRankedCandidate,
  WaterfallSourcePhase,
  WaterfallSourceState,
  applyWaterfallProfile,
  applyWaterfallSourceSelection,
  mergeWaterfallBatch,
  planWaterfallContinuation,
  planWaterfallInterestRecall
} from '@loop/agent-core';

function candidate(id: string, source: string): WaterfallRankedCandidate {
  return {
    id,
    source,
    mediaType: 'post',
    title: id,
    summary: '',
    url: 'https://' + source + '.test/' + id,
    coverUrl: '',
    publishedAt: '2026-08-19T00:00:00.000Z',
    originalIndex: 0,
    normalizedUrl: 'https://' + source + '.test/' + id,
    signals: { relevanceTier: 1, titleHits: 0, summaryHits: 0, freshnessTier: 1 },
    reason: '相关内容'
  };
}

function source(
  name: string,
  phase: WaterfallSourcePhase = 'success',
  continuation: WaterfallContinuation | null = null,
  inFlight: boolean = false
): WaterfallSourceState {
  return { source: name, phase, continuation, inFlight, reservedCount: 0, message: '' };
}

function interestState(sources: WaterfallSourceState[]): WaterfallFeedState {
  return {
    mode: 'interest',
    query: '',
    queryStage: 'done',
    enabledSources: ['youtube', 'bilibili', 'x', 'reddit'],
    preferenceDescription: '',
    shown: [],
    current: candidate('current', 'youtube'),
    stable: [candidate('stable-1', 'x'), candidate('stable-2', 'reddit')],
    tail: [],
    reserve: [],
    sources
  };
}

function emptyProfile(): WaterfallPreferenceSnapshot {
  return {
    topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: [],
    sessionTopicWeights: [], sessionSourceWeights: [], sessionFormatWeights: []
  };
}

export default function waterfallInterestRefillTest() {
  describe('waterfallInterestRefill', () => {
    it('promotes reserve before issuing an interest refill', 0, () => {
      const state = interestState([
        source('youtube', 'success', { kind: 'cursor', value: 'next-youtube' })
      ]);
      state.reserve = [candidate('reserve', 'bilibili')];

      const update = planWaterfallContinuation(state);

      expect(update.state.tail.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('reserve');
      expect(update.loadRequests.length).assertEqual(0);
      expect(update.expansionRequest === undefined).assertTrue();
    });

    it('refills only enabled non-terminal sources and preserves each continuation', 0, () => {
      const state = interestState([
        source('youtube', 'success', { kind: 'cursor', value: 'next-youtube' }),
        source('bilibili', 'success', { kind: 'page', value: '3' }),
        source('x', 'success', { kind: 'offset', value: '20' }, true),
        source('reddit', 'exhausted', null),
        source('zhihu', 'success', { kind: 'page', value: '2' })
      ]);
      state.sources[0].query = 'AI';
      state.sources[0].recallRoute = 'similar';
      state.sources[0].loadMode = 'search';

      const update = planWaterfallContinuation(state);

      expect(update.loadRequests.map((request): string => request.source).join(','))
        .assertEqual('youtube,bilibili');
      expect(update.loadRequests.map((request): string => request.continuation?.value ?? '').join(','))
        .assertEqual('next-youtube,3');
      expect(update.loadRequests[0].query ?? '').assertEqual('AI');
      expect(update.loadRequests[0].route ?? '').assertEqual('similar');
      expect(update.state.sources.filter((item: WaterfallSourceState): boolean => item.inFlight)
        .map((item: WaterfallSourceState): string => item.source).join(','))
        .assertEqual('youtube,bilibili,x');
      expect(update.expansionRequest === undefined).assertTrue();
    });

    it('re-enables one discovery source through one continuation request', 0, () => {
      const state = interestState([
        source('youtube', 'exhausted'),
        source('bilibili', 'success', { kind: 'page', value: '3' }),
        source('x', 'exhausted'),
        source('reddit', 'exhausted')
      ]);
      state.enabledSources = ['youtube', 'x', 'reddit'];

      const update = applyWaterfallSourceSelection(
        state, ['youtube', 'bilibili', 'x', 'reddit'], Date.parse('2026-08-19T01:00:00.000Z'));

      expect(update.loadRequests.length).assertEqual(1);
      expect(update.loadRequests[0].source).assertEqual('bilibili');
      expect(update.loadRequests[0].continuation?.value ?? '').assertEqual('3');
    });

    it('ends honestly when every enabled interest source is terminal', 0, () => {
      const state = interestState([
        source('youtube', 'exhausted'),
        source('bilibili', 'empty'),
        source('x', 'needs_auth'),
        source('reddit', 'error')
      ]);

      const update = planWaterfallContinuation(state);

      expect(update.loadRequests.length).assertEqual(0);
      expect(update.expansionRequest === undefined).assertTrue();
      expect(update.state.sources.some((item: WaterfallSourceState): boolean => item.inFlight)).assertFalse();
    });

    it('plans one equal-priority bounded discovery query per source', 0, () => {
      const profile = emptyProfile();
      profile.topicWeights = [
        { key: '科幻', weight: 8, updatedAt: 2 },
        { key: '摄影', weight: 4, updatedAt: 1 }
      ];
      const recent = [candidate('recent-ai', 'x'), candidate('recent-football', 'reddit')];
      recent[0].topics = ['AI'];
      recent[1].topics = ['足球'];

      const requests: WaterfallInterestRecallRequest[] = planWaterfallInterestRecall(
        profile, recent, ['youtube', 'x', 'reddit', 'zhihu', 'bilibili']);
      const fallbackQueries = requests.filter((request: WaterfallInterestRecallRequest): boolean =>
        request.route !== 'popular').map((request: WaterfallInterestRecallRequest): string => request.query);

      expect(requests.length).assertEqual(5);
      expect(requests.every((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.length === 1 && request.weight === 1 && request.query.length <= 24)).assertTrue();
      expect(requests.filter((request: WaterfallInterestRecallRequest): boolean => request.route === 'popular')
        .map((request: WaterfallInterestRecallRequest): string => request.sources[0]).join(','))
        .assertEqual('youtube');
      expect(fallbackQueries.join(',')).assertEqual('AI,足球,科幻,摄影');
      expect(fallbackQueries.indexOf('AI 科技 电影 体育 游戏')).assertEqual(-1);
    });

    it('waits for every initial discovery source before fixing the visible window', 0, () => {
      let state = interestState([
        source('youtube', 'loading', null, true),
        source('reddit', 'loading', null, true)
      ]);
      state.current = null;
      state.stable = [];
      const youtube = candidate('youtube-old', 'youtube');
      youtube.publishedAt = '2020-01-01T00:00:00.000Z';
      const reddit = candidate('reddit-new', 'reddit');

      state = mergeWaterfallBatch(
        state, [youtube], source('youtube', 'exhausted'), Date.parse('2026-08-19T01:00:00.000Z'), false
      ).state;
      expect(state.current === null).assertTrue();

      state = mergeWaterfallBatch(
        state, [reddit], source('reddit', 'exhausted'), Date.parse('2026-08-19T01:00:00.000Z'), false
      ).state;
      expect(state.current?.source ?? '').assertEqual('reddit');
      expect(state.stable.map((item: WaterfallRankedCandidate): string => item.source).join(','))
        .assertEqual('youtube');
    });

    it('shows collected discovery candidates when the remaining sources terminate', 0, () => {
      const state = interestState([
        source('youtube', 'exhausted'), source('reddit', 'error')
      ]);
      state.current = null;
      state.stable = [];
      state.tail = [candidate('youtube-ready', 'youtube')];

      const update = planWaterfallContinuation(state);

      expect(update.state.current?.id ?? '').assertEqual('youtube-ready');
      expect(update.loadRequests.length).assertEqual(0);
    });

    it('applies a session profile only to the unseen tail', 0, () => {
      const state = interestState([source('youtube', 'exhausted')]);
      const first = candidate('first', 'youtube');
      const preferred = candidate('preferred', 'youtube');
      first.topics = ['摄影'];
      preferred.topics = ['AI'];
      state.tail = [first, preferred];
      const profile = emptyProfile();
      profile.sessionTopicWeights = [{ key: 'AI', weight: 8, updatedAt: 1 }];
      const currentId = state.current?.id ?? '';
      const stableIds = state.stable.map((item: WaterfallRankedCandidate): string => item.id).join(',');

      const update = applyWaterfallProfile(state, profile, Date.parse('2026-08-19T01:00:00.000Z'));

      expect(update.state.current?.id ?? '').assertEqual(currentId);
      expect(update.state.stable.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual(stableIds);
      expect(update.state.tail.map((item: WaterfallRankedCandidate): string => item.id).join(','))
        .assertEqual('preferred,first');
      expect(update.expansionRequest === undefined).assertTrue();
    });
  });
}
