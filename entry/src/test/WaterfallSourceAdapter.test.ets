import { describe, expect, it } from '@ohos/hypium';
import {
  AggregateSearchSourceBatch,
  AggregateWaterfallSearchAdapter,
  ScheduledAggregateWaterfallDiscoveryAdapter,
  WaterfallContinuation,
  WaterfallSourcePage,
  configuredWaterfallSourceAdapters,
  waterfallAdapterIdsForPlatforms,
  waterfallPlatformAdapterBindings
} from '@loop/agent-core';

function adapterBatch(id: string, continuation: WaterfallContinuation | null): AggregateSearchSourceBatch {
  return {
    source: 'hackernews',
    videos: [],
    posts: [{
      id,
      source: 'hackernews',
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
    }],
    status: {
      source: 'hackernews',
      label: 'HN',
      status: 'success',
      message: 'ok',
      count: 1
    },
    continuation
  };
}

export default function waterfallSourceAdapterTest() {
  describe('WaterfallSourceAdapter', () => {
    it('keeps concurrent search continuation state in each request', 0, async () => {
      const adapter = new AggregateWaterfallSearchAdapter(
        'hackernews.search',
        'hackernews',
        'page',
        (query: string, continuation: WaterfallContinuation | null): Promise<AggregateSearchSourceBatch> =>
          Promise.resolve(adapterBatch(query, continuation))
      );
      const firstContinuation: WaterfallContinuation = { kind: 'page', value: '1' };
      const secondContinuation: WaterfallContinuation = { kind: 'page', value: '8' };
      const pages: WaterfallSourcePage[] = await Promise.all([
        adapter.search({ query: 'alpha', continuation: firstContinuation, limit: 10 }),
        adapter.search({ query: 'beta', continuation: secondContinuation, limit: 10 })
      ]);

      expect(pages[0].items[0].title).assertEqual('alpha');
      expect(pages[0].continuation?.value).assertEqual('1');
      expect(pages[1].items[0].title).assertEqual('beta');
      expect(pages[1].continuation?.value).assertEqual('8');
    });

    it('does not publish when scheduled discovery is pulled manually', 0, async () => {
      let published = 0;
      const adapter = new ScheduledAggregateWaterfallDiscoveryAdapter(
        'hackernews.scheduled',
        'hackernews',
        'none',
        1000,
        10,
        (_query: string, continuation: WaterfallContinuation | null): Promise<AggregateSearchSourceBatch> =>
          Promise.resolve(adapterBatch('manual', continuation))
      );
      const subscription = adapter.subscribe((_page: WaterfallSourcePage): void => {
        published++;
      });

      const page = await adapter.discover({ limit: 10, continuation: null });
      subscription.unsubscribe();

      expect(page.items[0].title).assertEqual('manual');
      expect(published).assertEqual(0);
    });

    it('registers one adapter per real source capability', 0, () => {
      const adapters = configuredWaterfallSourceAdapters();
      const searchIds = adapters.search.map((adapter): string => adapter.adapterId);
      const discoveryIds = adapters.discovery.map((adapter): string => adapter.adapterId);
      const scheduledIds = adapters.scheduledDiscovery.map((adapter): string => adapter.adapterId);

      expect(searchIds.length).assertEqual(10);
      expect(searchIds.indexOf('steam.search')).assertEqual(-1);
      expect(searchIds.indexOf('cnnews.search')).assertEqual(-1);
      expect(adapters.search[1].queryLanguagePolicy).assertEqual('domestic');
      expect(adapters.search[3].queryLanguagePolicy).assertEqual('global');
      expect(adapters.search[0].queryLanguagePolicy).assertEqual('pool_default');
      expect(discoveryIds.join(',')).assertEqual('youtube.most_popular');
      expect(scheduledIds.indexOf('zhihu.hot_list') >= 0).assertTrue();
      expect(scheduledIds.indexOf('steam.news') >= 0).assertTrue();
      expect(scheduledIds.indexOf('globalnews.latest') >= 0).assertTrue();
    });

    it('maps one platform switch to all of its registered adapters', 0, () => {
      const youtube = waterfallAdapterIdsForPlatforms(['youtube']);
      const zhihu = waterfallAdapterIdsForPlatforms(['zhihu']);
      const registered = configuredWaterfallSourceAdapters();
      const registeredIds: string[] = [];
      registered.search.forEach((adapter): void => {
        registeredIds.push(adapter.adapterId);
      });
      registered.discovery.forEach((adapter): void => {
        registeredIds.push(adapter.adapterId);
      });
      registered.scheduledDiscovery.forEach((adapter): void => {
        registeredIds.push(adapter.adapterId);
      });
      const mappedIds: string[] = [];
      waterfallPlatformAdapterBindings().forEach((binding): void => {
        binding.adapterIds.forEach((adapterId: string): void => {
          if (mappedIds.indexOf(adapterId) < 0) mappedIds.push(adapterId);
        });
      });

      expect(youtube.join(',')).assertEqual('youtube.search,youtube.most_popular');
      expect(zhihu.join(',')).assertEqual('zhihu.search,zhihu.hot_list');
      expect(mappedIds.length).assertEqual(registeredIds.length);
      expect(registeredIds.every((adapterId: string): boolean => mappedIds.indexOf(adapterId) >= 0)).assertTrue();
    });
  });
}
