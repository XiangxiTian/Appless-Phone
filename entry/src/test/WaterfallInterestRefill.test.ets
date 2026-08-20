import { describe, it, expect } from '@ohos/hypium';
import {
  WaterfallFeedState,
  WaterfallContinuation,
  WaterfallInterestRecallRequest,
  WaterfallPreferenceSnapshot,
  WaterfallRankedCandidate,
  WaterfallSourcePhase,
  WaterfallSourceState,
  advanceWaterfallFeed,
  applyWaterfallProfile,
  applyWaterfallSourceSelection,
  mergeWaterfallBatch,
  planWaterfallContinuation,
  planWaterfallInterestRecall,
  waterfallInterestRecallLimitForSource
} from '@loop/agent-core';

interface InterestContinuationFixture {
  source: string;
  kind: 'cursor' | 'page';
  value: string;
}

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

function inventoryCount(state: WaterfallFeedState): number {
  return state.shown.length + (state.current === null ? 0 : 1) + state.stable.length +
    state.tail.length + (state.reserve ?? []).length;
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

    it('requests each native continuation after interest advance reaches low inventory', 0, () => {
      const fixtures: InterestContinuationFixture[] = [
        { source: 'youtube', kind: 'cursor', value: 'next-youtube' },
        { source: 'x', kind: 'cursor', value: 'next-x' },
        { source: 'reddit', kind: 'cursor', value: 'next-reddit' },
        { source: 'bilibili', kind: 'page', value: '4' }
      ];
      fixtures.forEach((fixture: InterestContinuationFixture): void => {
        const sourceState = source(fixture.source, 'success', { kind: fixture.kind, value: fixture.value });
        sourceState.query = 'AI 科技';
        sourceState.recallRoute = 'explore';
        sourceState.loadMode = 'search';
        const state = interestState([sourceState]);
        state.enabledSources = [fixture.source];
        state.current = candidate('consumed-' + fixture.source, fixture.source);
        state.stable = [candidate('next-' + fixture.source, fixture.source)];
        const beforeCount = inventoryCount(state);

        const update = advanceWaterfallFeed(state, Date.parse('2026-08-19T01:00:00.000Z'));

        expect(update.loadRequests.length).assertEqual(1);
        expect(update.loadRequests[0].source).assertEqual(fixture.source);
        expect(update.loadRequests[0].continuation?.kind ?? '').assertEqual(fixture.kind);
        expect(update.loadRequests[0].continuation?.value ?? '').assertEqual(fixture.value);
        expect(update.loadRequests[0].query ?? '').assertEqual('AI 科技');
        expect(update.loadRequests[0].route ?? '').assertEqual('explore');
        expect(update.state.sources[0].inFlight).assertTrue();
        expect(update.state.shown[0].id).assertEqual('consumed-' + fixture.source);
        expect(update.state.current?.id ?? '').assertEqual('next-' + fixture.source);
        expect(update.state.stable.length).assertEqual(0);
        expect(inventoryCount(update.state)).assertEqual(beforeCount);
      });
    });

    it('does not refill after interest advance above low water or while a source is in flight', 0, () => {
      const sufficient = interestState([
        source('youtube', 'success', { kind: 'cursor', value: 'next-youtube' })
      ]);
      sufficient.enabledSources = ['youtube'];
      sufficient.current = candidate('full-current', 'youtube');
      sufficient.stable = [candidate('full-1', 'youtube'), candidate('full-2', 'youtube')];
      sufficient.tail = [candidate('full-3', 'youtube'), candidate('full-4', 'youtube')];

      const inFlight = interestState([
        source('youtube', 'success', { kind: 'cursor', value: 'next-youtube' }, true)
      ]);
      inFlight.enabledSources = ['youtube'];
      inFlight.current = candidate('flight-current', 'youtube');
      inFlight.stable = [candidate('flight-next', 'youtube')];

      const sufficientUpdate = advanceWaterfallFeed(sufficient, 1);
      const inFlightUpdate = advanceWaterfallFeed(inFlight, 1);

      expect(sufficientUpdate.loadRequests.length).assertEqual(0);
      expect(inFlightUpdate.loadRequests.length).assertEqual(0);
      expect(inventoryCount(sufficientUpdate.state)).assertEqual(inventoryCount(sufficient));
      expect(inventoryCount(inFlightUpdate.state)).assertEqual(inventoryCount(inFlight));
    });

    it('keeps bounded overflow in reserve before planning an interest continuation', 0, () => {
      const state = interestState([
        source('youtube', 'success', { kind: 'cursor', value: 'next-youtube' })
      ]);
      state.enabledSources = ['youtube'];
      state.current = candidate('bounded-current', 'youtube');
      state.stable = [candidate('bounded-1', 'youtube'), candidate('bounded-2', 'youtube')];
      for (let index = 3; index <= 19; index += 1) {
        state.tail.push(candidate('bounded-' + index.toString(), 'youtube'));
      }
      for (let index = 20; index <= 24; index += 1) {
        state.reserve?.push(candidate('bounded-' + index.toString(), 'youtube'));
      }
      const beforeCount = inventoryCount(state);

      const update = advanceWaterfallFeed(state, 1);

      expect(update.loadRequests.length).assertEqual(0);
      expect((update.state.current === null ? 0 : 1) + update.state.stable.length + update.state.tail.length)
        .assertEqual(20);
      expect(update.state.reserve?.length ?? 0).assertEqual(4);
      expect(update.state.reserve?.[0].id ?? '').assertEqual('bounded-21');
      expect(inventoryCount(update.state)).assertEqual(beforeCount);
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

    it('plans bounded shared discovery queries plus Twitch provider discovery', 0, () => {
      const profile = emptyProfile();
      profile.topicWeights = [
        { key: '科幻', weight: 8, updatedAt: 2 },
        { key: '摄影', weight: 4, updatedAt: 1 }
      ];
      const recent = [candidate('recent-ai', 'x'), candidate('recent-football', 'reddit')];
      recent[0].topics = ['AI'];
      recent[1].topics = ['足球'];

      const requests: WaterfallInterestRecallRequest[] = planWaterfallInterestRecall(
        profile, recent, ['youtube', 'x', 'reddit', 'zhihu', 'bilibili', 'twitch']);
      const nonTwitchSources = 'youtube,x,reddit,zhihu,bilibili';
      const nonTwitchRequests = requests.filter((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.indexOf('twitch') < 0);
      const twitchRequests = requests.filter((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.indexOf('twitch') >= 0);

      expect(nonTwitchRequests.length).assertEqual(5);
      expect(nonTwitchRequests.every((request: WaterfallInterestRecallRequest): boolean =>
        request.sources.join(',') === nonTwitchSources && request.query.length > 0 && request.query.length <= 24 &&
        request.sources.every((source: string): boolean =>
          waterfallInterestRecallLimitForSource(source) === 10))).assertTrue();
      expect(nonTwitchRequests.map((request: WaterfallInterestRecallRequest): string => request.query).join(','))
        .assertEqual('AI,足球,科幻,摄影,AI 科技');
      expect(twitchRequests.length).assertEqual(1);
      expect(twitchRequests[0].query).assertEqual('');
      expect(twitchRequests[0].sources.join(',')).assertEqual('twitch');
      expect(waterfallInterestRecallLimitForSource('twitch')).assertEqual(4);
      expect(requests[requests.length - 1].sources.join(',')).assertEqual('twitch');
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
