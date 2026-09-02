import { describe, expect, it } from '@ohos/hypium';
import {
  AggregateSearchPost,
  AggregateSearchSourceBatch,
  AggregateWaterfallDiscoveryAdapter,
  AggregateWaterfallSearchAdapter,
  coordinateWaterfallPoolTake,
  WaterfallCandidate,
  WaterfallColdStartTopic,
  WaterfallFeedState,
  WaterfallPool,
  WaterfallPoolAcceptedEvent,
  WaterfallPoolAvailabilityWait,
  WaterfallPoolTakeCoordinatorCallbacks,
  WaterfallScheduledDiscoveryAdapter,
  WaterfallScheduledDiscoveryListener,
  WaterfallPreferenceSnapshot,
  WaterfallSourceAdapterRegistry,
  WaterfallSourceDiscoveryRequest,
  WaterfallSourcePage,
  WaterfallSourcePoolEntry,
  WaterfallSourceSubscription
} from '@loop/agent-core';

function poolTestCandidate(id: string, source: 'youtube' | 'bilibili' = 'youtube'): WaterfallCandidate {
  return {
    id,
    source,
    provider: 'test',
    mediaType: 'video',
    title: id,
    summary: id,
    url: 'https://example.com/' + id,
    coverUrl: '',
    publishedAt: '',
    originalIndex: 0
  };
}

function poolTestCandidateWithViews(id: string, views: number): WaterfallCandidate {
  const candidate = poolTestCandidate(id, 'bilibili');
  candidate.metrics = [{ kind: 'view', value: views }];
  return candidate;
}

function requiredFirstPoolEntry(pool: WaterfallPool, sourceId: string): WaterfallSourcePoolEntry {
  const container = pool.containerFor(sourceId);
  if (container === null) throw new Error('Missing pool container: ' + sourceId);
  const entry = container.entries()[0];
  if (entry === undefined) throw new Error('Missing pool entry: ' + sourceId);
  return entry;
}

function poolTestBatch(
  source: 'youtube' | 'bilibili',
  ids: string[],
  nextPage: string = ''
): AggregateSearchSourceBatch {
  return {
    source,
    videos: [],
    posts: ids.map((id: string): AggregateSearchPost => ({
      id,
      source,
      provider: 'test',
      title: id,
      author: '',
      handle: '',
      text: id,
      url: 'https://example.com/' + id,
      publishedAt: '',
      score: '',
      commentCount: '',
      status: 'success',
      rows: []
    })),
    status: {
      source,
      label: source,
      status: ids.length > 0 ? 'success' : 'empty',
      message: 'ok',
      count: ids.length
    },
    continuation: nextPage.length > 0 ? { kind: 'cursor', value: nextPage } : null
  };
}

class PoolTestSubscription implements WaterfallSourceSubscription {
  private readonly cancel: () => void;

  constructor(cancel: () => void) {
    this.cancel = cancel;
  }

  unsubscribe(): void {
    this.cancel();
  }
}

class PoolTestScheduledAdapter implements WaterfallScheduledDiscoveryAdapter {
  readonly adapterId: string = 'youtube.scheduled_test';
  readonly sourceId: 'youtube' = 'youtube';
  readonly kind: 'scheduled_discovery' = 'scheduled_discovery';
  readonly pagination: 'none' = 'none';
  readonly refreshIntervalMs: number = 1000;
  discoverCalls: number = 0;
  private listener: WaterfallScheduledDiscoveryListener | null = null;

  discover(_request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage> {
    this.discoverCalls++;
    const id = this.discoverCalls === 1 ? 'manual' : 'manual-' + this.discoverCalls.toString();
    return Promise.resolve(this.page(id));
  }

  subscribe(listener: WaterfallScheduledDiscoveryListener): WaterfallSourceSubscription {
    this.listener = listener;
    return new PoolTestSubscription((): void => {
      this.listener = null;
    });
  }

  publish(id: string): void {
    if (this.listener !== null) {
      this.listener(this.page(id));
    }
  }

  private page(id: string): WaterfallSourcePage {
    return {
      adapterId: this.adapterId,
      sourceId: this.sourceId,
      items: [poolTestCandidate(id)],
      continuation: null,
      exhausted: true,
      status: 'success',
      message: 'ok',
      fetchedAt: 100
    };
  }
}

class PoolTestTakeCallbacks implements WaterfallPoolTakeCoordinatorCallbacks<WaterfallSourcePoolEntry> {
  supplyCalls: number = 0;
  private readonly pool: WaterfallPool;
  private readonly profile: WaterfallPreferenceSnapshot;
  private readonly settleSupply: boolean;

  constructor(pool: WaterfallPool, profile: WaterfallPreferenceSnapshot, settleSupply: boolean) {
    this.pool = pool;
    this.profile = profile;
    this.settleSupply = settleSupply;
  }

  take(): WaterfallSourcePoolEntry[] {
    return [];
  }

  waitForAvailable(): WaterfallPoolAvailabilityWait {
    return this.pool.waitForAvailable(this.profile, ['youtube']);
  }

  requestSupply(): void {
    this.supplyCalls++;
    if (this.settleSupply) this.pool.settleAvailabilityWaiters();
  }

  isCancelled(): boolean {
    return false;
  }

  onWaitStarted(_wait: WaterfallPoolAvailabilityWait): void {
  }

  onWaitFinished(_wait: WaterfallPoolAvailabilityWait): void {
  }
}

export default function waterfallPoolTest() {
  describe('WaterfallPool', () => {
    it('shares one source container across adapter capabilities', 0, () => {
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', ['search']))
      );
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', ['discovery']))
      );
      const registry: WaterfallSourceAdapterRegistry = {
        search: [search], discovery: [discovery], scheduledDiscovery: []
      };
      const pool = new WaterfallPool(registry);

      expect(pool.sources().length).assertEqual(1);
      expect(pool.sources()[0]).assertEqual('youtube');
      expect(pool.containerFor('youtube')?.capacity).assertEqual(200);
    });

    it('expands every source container and raises the discovery watermark', 0, () => {
      const youtube = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', []))
      );
      const bilibili = new AggregateWaterfallSearchAdapter(
        'bilibili.search_test', 'bilibili', 'page',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('bilibili', []))
      );
      const pool = new WaterfallPool(
        { search: [youtube, bilibili], discovery: [], scheduledDiscovery: [] },
        { sourceCapacity: 20, discoveryWatermark: 20 }
      );

      expect(pool.expandSourceCapacity(200, 50)).assertTrue();
      expect(pool.sourceCapacity).assertEqual(200);
      expect(pool.discoveryWatermark).assertEqual(50);
      expect(pool.containerFor('youtube')?.capacity).assertEqual(200);
      expect(pool.containerFor('bilibili')?.capacity).assertEqual(200);
      expect(pool.expandSourceCapacity(20, 20)).assertFalse();
    });

    it('supplements every search source and routes results into source containers', 0, async () => {
      const youtube = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', ['yt-' + query]))
      );
      const bilibili = new AggregateWaterfallSearchAdapter(
        'bilibili.search_test', 'bilibili', 'page',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('bilibili', ['bili-' + query]))
      );
      const pool = new WaterfallPool({
        search: [youtube, bilibili], discovery: [], scheduledDiscovery: []
      });

      const result = await pool.supplement('人工智能');

      expect(result.results.length).assertEqual(2);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      expect(pool.containerFor('bilibili')?.size).assertEqual(1);
      expect(requiredFirstPoolEntry(pool, 'youtube').keywords.indexOf('人工智能') >= 0).assertTrue();
    });

    it('rejects bilibili search items below 2000 views when entering the pool', 0, () => {
      const bilibili = new AggregateWaterfallSearchAdapter(
        'bilibili.search', 'bilibili', 'page',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('bilibili', []))
      );
      const pool = new WaterfallPool({
        search: [bilibili], discovery: [], scheduledDiscovery: []
      });

      pool.accept({
        adapterId: 'bilibili.search',
        sourceId: 'bilibili',
        items: [
          poolTestCandidateWithViews('low', 1999),
          poolTestCandidateWithViews('enough', 2000),
          poolTestCandidate('missing', 'bilibili')
        ],
        continuation: null,
        exhausted: true,
        status: 'success',
        message: 'ok',
        fetchedAt: 100
      });

      expect(pool.containerFor('bilibili')?.size).assertEqual(2);
      expect(pool.containerFor('bilibili')?.entries().map((entry: WaterfallSourcePoolEntry): string =>
        entry.candidate.id).join(',')).assertEqual('enough,missing');
    });

    it('keeps disabled adapter data while skipping new requests and pool output', 0, async () => {
      let calls = 0;
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => {
          calls++;
          return Promise.resolve(poolTestBatch('youtube', [query]));
        }
      );
      const pool = new WaterfallPool({
        search: [search], discovery: [], scheduledDiscovery: []
      });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      await pool.supplement('cached');

      expect(pool.setAdapterEnabled('youtube.search_test', false)).assertTrue();
      expect((await pool.supplement('disabled')).results.length).assertEqual(0);
      expect(calls).assertEqual(1);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      expect(pool.takeUpToForProfile(profile, ['youtube'], 1).length).assertEqual(0);

      pool.setAdapterEnabled('youtube.search_test', true);
      expect(pool.takeUpToForProfile(profile, ['youtube'], 1).length).assertEqual(1);
      expect(pool.containerFor('youtube')?.size).assertEqual(0);
    });

    it('selects one language variant per adapter for a bilingual topic', 0, async () => {
      const queries: string[] = [];
      const domestic = new AggregateWaterfallSearchAdapter(
        'bilibili.search_test', 'bilibili', 'page',
        (query, _continuation, _limit) => {
          queries.push('domestic:' + query);
          return Promise.resolve(poolTestBatch('bilibili', ['domestic-result']));
        },
        'domestic'
      );
      const global = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => {
          queries.push('global:' + query);
          return Promise.resolve(poolTestBatch('youtube', ['global-result']));
        },
        'global'
      );
      const topic: WaterfallColdStartTopic = {
        id: 'ai', domesticQuery: '人工智能', globalQuery: 'artificial intelligence'
      };
      const pool = new WaterfallPool({
        search: [domestic, global], discovery: [], scheduledDiscovery: []
      });

      const result = await pool.supplementTopic(topic);

      expect(result.results.length).assertEqual(2);
      expect(queries.indexOf('domestic:人工智能') >= 0).assertTrue();
      expect(queries.indexOf('global:artificial intelligence') >= 0).assertTrue();
    });

    it('serializes keywords inside one adapter and coalesces duplicate queued searches', 0, async () => {
      let active = 0;
      let maximumActive = 0;
      let calls = 0;
      const order: string[] = [];
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        async (query, _continuation, _limit) => {
          calls++;
          active++;
          maximumActive = Math.max(maximumActive, active);
          order.push(query);
          await new Promise<void>((resolve): void => {
            setTimeout(resolve, 5);
          });
          active--;
          return poolTestBatch('youtube', [query]);
        }
      );
      const pool = new WaterfallPool({
        search: [search], discovery: [], scheduledDiscovery: []
      });

      await Promise.all([
        pool.supplement('first'),
        pool.supplement('second'),
        pool.supplement('second')
      ]);

      expect(calls).assertEqual(2);
      expect(maximumActive).assertEqual(1);
      expect(order.join(',')).assertEqual('first,second');
      expect(pool.searchQueueSnapshots()[0].pendingCount).assertEqual(0);
      expect(pool.searchQueueSnapshots()[0].running).assertFalse();
    });

    it('runs different adapter queues concurrently', 0, async () => {
      let active = 0;
      let maximumActive = 0;
      const delayedLoader = async (
        source: 'youtube' | 'bilibili',
        query: string
      ): Promise<AggregateSearchSourceBatch> => {
        active++;
        maximumActive = Math.max(maximumActive, active);
        await new Promise<void>((resolve): void => {
          setTimeout(resolve, 5);
        });
        active--;
        return poolTestBatch(source, [query]);
      };
      const youtube = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => delayedLoader('youtube', query)
      );
      const bilibili = new AggregateWaterfallSearchAdapter(
        'bilibili.search_test', 'bilibili', 'page',
        (query, _continuation, _limit) => delayedLoader('bilibili', query)
      );
      const pool = new WaterfallPool({
        search: [youtube, bilibili], discovery: [], scheduledDiscovery: []
      });

      await pool.supplement('parallel');

      expect(maximumActive).assertEqual(2);
    });

    it('consumes enabled-source pool items into the legacy waterfall', 0, async () => {
      const youtube = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', ['yt-' + query]))
      );
      const bilibili = new AggregateWaterfallSearchAdapter(
        'bilibili.search_test', 'bilibili', 'page',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('bilibili', ['bili-' + query]))
      );
      const pool = new WaterfallPool({
        search: [youtube, bilibili], discovery: [], scheduledDiscovery: []
      });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const state: WaterfallFeedState = {
        mode: 'interest',
        query: '',
        enabledSources: ['youtube'],
        preferenceDescription: '',
        profile,
        shown: [], current: null, stable: [], tail: [], reserve: [], sources: []
      };
      await pool.supplement('AI');

      const drained = pool.drainToWaterfall(state, profile, 1000, false);

      expect(drained.entries.length).assertEqual(1);
      expect(drained.entries[0].candidate.source).assertEqual('youtube');
      expect(drained.update.state.current?.source).assertEqual('youtube');
      expect(pool.containerFor('youtube')?.size).assertEqual(0);
      expect(pool.containerFor('bilibili')?.size).assertEqual(1);
    });

    it('waits for profile-compatible content without consuming it before the caller resumes', 0, async () => {
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', [query]))
      );
      const pool = new WaterfallPool({
        search: [search], discovery: [], scheduledDiscovery: []
      });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const wait = pool.waitForAvailable(profile, ['youtube']);

      await pool.supplement('available');
      const available = await wait.promise;

      expect(available).assertTrue();
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      expect(pool.takeUpToForProfile(profile, ['youtube'], 1).length).assertEqual(1);
      expect(pool.containerFor('youtube')?.size).assertEqual(0);
    });

    it('takes multiple ranked items from one source up to the requested refill target', 0, async () => {
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) =>
          Promise.resolve(poolTestBatch('youtube', ['one', 'two', 'three']))
      );
      const pool = new WaterfallPool({
        search: [search], discovery: [], scheduledDiscovery: []
      });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      await pool.supplement('batch');

      const taken = pool.takeUpToForProfile(profile, ['youtube'], 2);

      expect(taken.length).assertEqual(2);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
    });

    it('cancels an empty pool wait without consuming later content', 0, async () => {
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', [query]))
      );
      const pool = new WaterfallPool({
        search: [search], discovery: [], scheduledDiscovery: []
      });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const wait = pool.waitForAvailable(profile, ['youtube']);

      wait.cancel();
      expect(await wait.promise).assertFalse();
      await pool.supplement('after-cancel');
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
    });

    it('settles an empty availability wait when one production round finishes without content', 0, async () => {
      const pool = new WaterfallPool({ search: [], discovery: [], scheduledDiscovery: [] });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const wait = pool.waitForAvailable(profile, ['youtube']);

      pool.settleAvailabilityWaiters();

      expect(await wait.promise).assertFalse();
    });

    it('returns an empty result after three failed Worker supply rounds', 0, async () => {
      const pool = new WaterfallPool({ search: [], discovery: [], scheduledDiscovery: [] });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const callbacks = new PoolTestTakeCallbacks(pool, profile, true);

      const result = await coordinateWaterfallPoolTake(callbacks, {
        maxAttempts: 3,
        maxWaitMs: 1000,
        retryDelaysMs: [0, 0, 0]
      });

      expect(result.entries.length).assertEqual(0);
      expect(result.attempts).assertEqual(3);
      expect(result.waitCycles).assertEqual(3);
      expect(result.cancelled).assertFalse();
      expect(callbacks.supplyCalls).assertEqual(3);
    });

    it('returns an empty result when the Worker take deadline is reached', 0, async () => {
      const pool = new WaterfallPool({ search: [], discovery: [], scheduledDiscovery: [] });
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      const callbacks = new PoolTestTakeCallbacks(pool, profile, false);

      const result = await coordinateWaterfallPoolTake(callbacks, {
        maxAttempts: 3,
        maxWaitMs: 5,
        retryDelaysMs: [0, 0, 0]
      });

      expect(result.entries.length).assertEqual(0);
      expect(result.attempts).assertEqual(1);
      expect(result.deadlineReached).assertTrue();
    });

    it('refills pull discovery until the source watermark is reached', 0, async () => {
      let page = 0;
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => {
          page++;
          return Promise.resolve(poolTestBatch(
            'youtube',
            page === 1 ? ['one', 'two'] : ['three', 'four'],
            page === 1 ? 'next' : ''
          ));
        }
      );
      const pool = new WaterfallPool(
        { search: [], discovery: [discovery], scheduledDiscovery: [] },
        { requestLimit: 2, discoveryWatermark: 3 }
      );

      const result = await pool.refillDiscoveries();

      expect(page).assertEqual(2);
      expect(pool.containerFor('youtube')?.size).assertEqual(4);
      expect(result[0].reachedWatermark).assertTrue();
    });

    it('automatically refills pull discovery after consumption lowers its source waterline', 0, async () => {
      let calls = 0;
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => {
          calls++;
          return Promise.resolve(poolTestBatch('youtube', ['item-' + calls.toString()]));
        }
      );
      const pool = new WaterfallPool(
        { search: [], discovery: [discovery], scheduledDiscovery: [] },
        { requestLimit: 1, discoveryWatermark: 1 }
      );
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      await pool.start();

      expect(pool.takeUpToForProfile(profile, ['youtube'], 1).length).assertEqual(1);
      await new Promise<void>((resolve): void => {
        setTimeout(resolve, 10);
      });

      expect(calls).assertEqual(2);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      pool.stop();
    });

    it('retries a failed pull discovery in the background until its waterline is restored', 0, async () => {
      let calls = 0;
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_retry_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => {
          calls++;
          if (calls === 1) return Promise.reject(new Error('temporary discovery failure'));
          return Promise.resolve(poolTestBatch('youtube', ['recovered']));
        }
      );
      const pool = new WaterfallPool(
        { search: [], discovery: [discovery], scheduledDiscovery: [] },
        { requestLimit: 1, discoveryWatermark: 1, discoveryRetryDelaysMs: [1] }
      );

      await pool.start();
      await new Promise<void>((resolve): void => {
        setTimeout(resolve, 20);
      });

      expect(calls).assertEqual(2);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      pool.stop();
    });

    it('cancels a pending discovery retry when the pool stops', 0, async () => {
      let calls = 0;
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_stop_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => {
          calls++;
          return Promise.reject(new Error('persistent discovery failure'));
        }
      );
      const pool = new WaterfallPool(
        { search: [], discovery: [discovery], scheduledDiscovery: [] },
        { requestLimit: 1, discoveryWatermark: 1, discoveryRetryDelaysMs: [10] }
      );

      await pool.start();
      pool.stop();
      await new Promise<void>((resolve): void => {
        setTimeout(resolve, 30);
      });

      expect(calls).assertEqual(1);
    });

    it('bounds an adapter request that never settles', 0, async () => {
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_timeout_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => new Promise<AggregateSearchSourceBatch>(
          (_resolve, _reject): void => {})
      );
      const pool = new WaterfallPool(
        { search: [search], discovery: [], scheduledDiscovery: [] },
        { adapterTimeoutMs: 5 }
      );

      const result = await pool.supplement('timeout');

      expect(result.results.length).assertEqual(1);
      expect(result.results[0].page.status).assertEqual('error');
      expect(result.results[0].page.message.indexOf('timed out') >= 0).assertTrue();
    });

    it('notifies the producer once consumption leaves an enabled source below its waterline', 0, async () => {
      let refillRequests = 0;
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', []))
      );
      const pool = new WaterfallPool(
        { search: [search], discovery: [], scheduledDiscovery: [] },
        {
          discoveryWatermark: 2,
          lowWatermarkObserver: (): void => {
            refillRequests++;
          }
        }
      );
      const profile: WaterfallPreferenceSnapshot = {
        topicWeights: [], sourceWeights: [], formatWeights: [], explicitRules: []
      };
      pool.accept({
        adapterId: search.adapterId,
        sourceId: search.sourceId,
        items: [poolTestCandidate('one')],
        continuation: null,
        exhausted: true,
        status: 'success',
        message: 'ok',
        fetchedAt: 100
      });
      await pool.start();

      expect(pool.takeUpToForProfile(profile, ['youtube'], 1).length).assertEqual(1);
      expect(refillRequests).assertEqual(1);
      pool.stop();
    });

    it('does not request from a disabled pull discovery adapter', 0, async () => {
      let calls = 0;
      const discovery = new AggregateWaterfallDiscoveryAdapter(
        'youtube.discovery_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => {
          calls++;
          return Promise.resolve(poolTestBatch('youtube', ['one']));
        }
      );
      const pool = new WaterfallPool(
        { search: [], discovery: [discovery], scheduledDiscovery: [] },
        { requestLimit: 1, discoveryWatermark: 1 }
      );

      pool.setAdapterEnabled(discovery.adapterId, false);
      await pool.refillDiscoveries();
      expect(calls).assertEqual(0);
      expect(pool.containerFor('youtube')?.size).assertEqual(0);

      pool.setAdapterEnabled(discovery.adapterId, true);
      await pool.refillDiscoveries();
      expect(calls).assertEqual(1);
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
    });

    it('accepts scheduled snapshots only while the pool is started', 0, async () => {
      const scheduled = new PoolTestScheduledAdapter();
      const pool = new WaterfallPool({
        search: [], discovery: [], scheduledDiscovery: [scheduled]
      });

      await pool.start();
      scheduled.publish('first');
      pool.stop();
      scheduled.publish('after-stop');

      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      expect(requiredFirstPoolEntry(pool, 'youtube').candidate.id).assertEqual('first');
    });

    it('unsubscribes and restores a scheduled adapter when its switch changes', 0, async () => {
      const scheduled = new PoolTestScheduledAdapter();
      const pool = new WaterfallPool({
        search: [], discovery: [], scheduledDiscovery: [scheduled]
      });
      await pool.start();

      pool.setAdapterEnabled(scheduled.adapterId, false);
      scheduled.publish('disabled');
      expect(pool.containerFor('youtube')?.size).assertEqual(0);

      pool.setAdapterEnabled(scheduled.adapterId, true);
      scheduled.publish('enabled');
      expect(pool.containerFor('youtube')?.size).assertEqual(1);
      expect(requiredFirstPoolEntry(pool, 'youtube').candidate.id).assertEqual('enabled');
    });

    it('can refresh scheduled sources manually without waiting for their timer', 0, async () => {
      const scheduled = new PoolTestScheduledAdapter();
      const pool = new WaterfallPool({
        search: [], discovery: [], scheduledDiscovery: [scheduled]
      });

      const results = await pool.refreshScheduledDiscoveries();

      expect(results.length).assertEqual(1);
      expect(requiredFirstPoolEntry(pool, 'youtube').candidate.id).assertEqual('manual');
      expect(pool.isStarted).assertFalse();
    });

    it('allows consecutive forced scheduled refreshes while due refreshes remain throttled', 0, async () => {
      const scheduled = new PoolTestScheduledAdapter();
      const pool = new WaterfallPool({
        search: [], discovery: [], scheduledDiscovery: [scheduled]
      });

      const firstDue = await pool.refreshScheduledDiscoveriesIfDue();
      const secondDue = await pool.refreshScheduledDiscoveriesIfDue();
      const firstForced = await pool.refreshScheduledDiscoveries();
      const secondForced = await pool.refreshScheduledDiscoveries();

      expect(firstDue.length).assertEqual(1);
      expect(secondDue.length).assertEqual(0);
      expect(firstForced.length).assertEqual(1);
      expect(secondForced.length).assertEqual(1);
      expect(scheduled.discoverCalls).assertEqual(3);
      expect(pool.containerFor('youtube')?.size).assertEqual(3);
    });

    it('observes accepted pages without coupling diagnostics to ingestion', 0, async () => {
      const origins: string[] = [];
      const search = new AggregateWaterfallSearchAdapter(
        'youtube.search_test', 'youtube', 'cursor',
        (_query, _continuation, _limit) => Promise.resolve(poolTestBatch('youtube', ['observed']))
      );
      const pool = new WaterfallPool(
        { search: [search], discovery: [], scheduledDiscovery: [] },
        {
          observer: (event: WaterfallPoolAcceptedEvent): void => {
            origins.push(event.origin + ':' + event.sourceSize.toString());
          }
        }
      );

      await pool.supplement('测试');

      expect(origins.join(',')).assertEqual('search:1');
    });
  });
}
