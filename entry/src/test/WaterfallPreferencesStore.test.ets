import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  aggregateSearchSourcesFromArgs,
  configureWaterfallEnabledSourcesForRuntime,
  AggregateSearchSourceMetadata,
  aggregateSearchDefaultEnabledSourceIds,
  aggregateSearchRegistryMetadata,
  aggregateSearchRegistrySourceIds,
  aggregateSearchSearchSourceIds,
  aggregateSearchRegistryVersion,
  WaterfallExplicitPreference,
  WaterfallPreferenceWeight
} from '@loop/agent-core';
import {
  emptyWaterfallPreferenceProfile,
  WATERFALL_PREFERENCES_KEY,
  WaterfallBehaviorEvidence,
  WaterfallPreferenceProfile,
  WaterfallPreferencesStore
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallPreferencesStore';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  flush(): Promise<void> {
    return Promise.resolve();
  }

  raw(key: string): string {
    const value = this.getSync(key, '');
    return typeof value === 'string' ? value : '';
  }
}

interface SearchSourceArgs {
  sources: string[];
  onlyDomesticSources?: boolean;
  includeMultilingualResults?: boolean;
}

interface LegacyPreferenceFixture {
  version: number;
  topicWeights: WaterfallPreferenceWeight[];
  sourceWeights: WaterfallPreferenceWeight[];
  formatWeights: WaterfallPreferenceWeight[];
  explicitRules: WaterfallExplicitPreference[];
  recentEvidence: WaterfallBehaviorEvidence[];
  enabledSources: string[];
  updatedAt: number;
}

function event(
  behavior: 'play_complete' | 'read_complete' | 'dwell' | 'quick_skip',
  timestamp: number,
  id: string = 'candidate-1'
): WaterfallBehaviorEvidence {
  return {
    candidateId: id,
    topics: ['AI'],
    source: 'youtube',
    format: 'landscape_video',
    behavior,
    durationMs: behavior === 'quick_skip' ? 1000 : 8000,
    timestamp
  };
}

function weight(profile: WaterfallPreferenceProfile, key: string): number {
  for (let index = 0; index < profile.topicWeights.length; index += 1) {
    if (profile.topicWeights[index].key === key) return profile.topicWeights[index].weight;
  }
  return 0;
}

function legacyProfile(enabledSources: string[]): LegacyPreferenceFixture {
  return {
    version: 1,
    topicWeights: [],
    sourceWeights: [],
    formatWeights: [],
    explicitRules: [],
    recentEvidence: [],
    enabledSources: enabledSources,
    updatedAt: 1000
  };
}

export default function waterfallPreferencesStoreTest() {
  describe('waterfallPreferencesStore', () => {
    it('migrates v1 enabled sources and round-trips v2 discovery sources', 0, () => {
      const native = new MemoryPreferences();
      native.putSync(WATERFALL_PREFERENCES_KEY, '{');
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      expect(store.load().version).assertEqual(2);
      native.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify({
        version: 1,
        topicWeights: [],
        sourceWeights: [],
        formatWeights: [],
        explicitRules: [],
        recentEvidence: [],
        enabledSources: ['youtube', 'x'],
        updatedAt: 7
      }));
      const migrated = new WaterfallPreferencesStore(native as Object as preferences.Preferences).load();
      expect(migrated.version).assertEqual(2);
      expect(migrated.discoveryEnabledSources.join(','))
        .assertEqual('youtube,x,applepodcasts,twitch');

      native.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify({ version: 2 }));
      expect(new WaterfallPreferencesStore(native as Object as preferences.Preferences).load().recentEvidence.length)
        .assertEqual(0);

      const saved = store.saveDiscoveryEnabledSources(['youtube', 'youtube', 'reddit']);
      expect(saved.discoveryEnabledSources.join(',')).assertEqual('youtube,reddit');
      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences).load();
      expect(reopened.discoveryEnabledSources.join(',')).assertEqual('youtube,reddit');
    });

    it('never filters search sources through discovery runtime settings', 0, () => {
      configureWaterfallEnabledSourcesForRuntime(['youtube']);
      const args: SearchSourceArgs = {
        sources: ['reddit', 'x'],
        onlyDomesticSources: false,
        includeMultilingualResults: true
      };
      expect(aggregateSearchSourcesFromArgs(args).join(','))
        .assertEqual('reddit,x');
      configureWaterfallEnabledSourcesForRuntime([]);
      const allSources: SearchSourceArgs = {
        sources: [],
        onlyDomesticSources: false,
        includeMultilingualResults: true
      };
      expect(aggregateSearchSourcesFromArgs(allSources).join(','))
        .assertEqual(aggregateSearchSearchSourceIds().join(','));
    });

    it('adds newly registered default sources without re-enabling an older disabled source', 0, () => {
      const native = new MemoryPreferences();
      const oldEnabled = aggregateSearchRegistryMetadata().filter(
        (metadata: AggregateSearchSourceMetadata): boolean =>
          metadata.introducedInRegistryVersion === 1 && metadata.source !== 'x'
      ).map((metadata: AggregateSearchSourceMetadata): string => metadata.source);
      native.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify(legacyProfile(oldEnabled)));

      const migrated = new WaterfallPreferencesStore(native as Object as preferences.Preferences).load();
      expect(migrated.enabledSources.indexOf('x')).assertEqual(-1);
      expect(migrated.enabledSources.indexOf('douban')).assertEqual(-1);
      expect(migrated.enabledSources.indexOf('applepodcasts') >= 0).assertTrue();
      expect(migrated.enabledSources.indexOf('twitch') >= 0).assertTrue();
      expect(migrated.sourceRegistryVersion).assertEqual(aggregateSearchRegistryVersion());

      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const withoutTwitch = migrated.enabledSources.filter((source: string): boolean => source !== 'twitch');
      store.saveEnabledSources(withoutTwitch);
      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences).load();
      expect(reopened.enabledSources.indexOf('twitch')).assertEqual(-1);
      expect(reopened.enabledSources.indexOf('x')).assertEqual(-1);
    });

    it('keeps registry migration metadata internally consistent', 0, () => {
      const metadata = aggregateSearchRegistryMetadata();
      const seen: string[] = [];
      let maxVersion = 1;
      metadata.forEach((item: AggregateSearchSourceMetadata): void => {
        expect(item.introducedInRegistryVersion >= 1).assertTrue();
        expect(seen.indexOf(item.source)).assertEqual(-1);
        seen.push(item.source);
        maxVersion = Math.max(maxVersion, item.introducedInRegistryVersion);
      });
      expect(aggregateSearchRegistryVersion()).assertEqual(maxVersion);
      expect(aggregateSearchRegistrySourceIds().indexOf('douban')).assertEqual(-1);
      expect(aggregateSearchRegistrySourceIds().indexOf('applepodcasts')).assertLarger(-1);
      expect(aggregateSearchRegistrySourceIds().indexOf('twitch')).assertLarger(-1);
      expect(emptyWaterfallPreferenceProfile().enabledSources.join(','))
        .assertEqual(aggregateSearchDefaultEnabledSourceIds().join(','));
    });

    it('resets stored source selection for a new session without losing other preferences', 0, () => {
      const native = new MemoryPreferences();
      const stored = legacyProfile(['twitch']);
      stored.topicWeights = [{ key: 'AI', weight: 4, updatedAt: 900 }];
      stored.sourceWeights = [{ key: 'youtube', weight: 2, updatedAt: 900 }];
      stored.formatWeights = [{ key: 'landscape_video', weight: 1, updatedAt: 900 }];
      stored.explicitRules = [{ dimension: 'source', key: 'x', effect: 'downweight' }];
      stored.recentEvidence = [event('dwell', 900)];
      native.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify(stored));

      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const started = store.loadForNewSession();
      const defaults = aggregateSearchDefaultEnabledSourceIds().join(',');
      expect(started.enabledSources.join(',')).assertEqual(defaults);
      expect(started.topicWeights[0].weight).assertEqual(4);
      expect(started.sourceWeights[0].weight).assertEqual(2);
      expect(started.formatWeights[0].weight).assertEqual(1);
      expect(started.explicitRules[0].effect).assertEqual('downweight');
      expect(started.recentEvidence[0].candidateId).assertEqual('candidate-1');

      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      expect(reopened.load().enabledSources.join(',')).assertEqual(defaults);
      expect(store.recordBehavior(event('read_complete', 2000, 'candidate-2')).enabledSources.join(','))
        .assertEqual(defaults);
      expect(store.replaceExplicitPreferences([
        { dimension: 'topic', key: '科技', effect: 'boost' }
      ]).enabledSources.join(',')).assertEqual(defaults);
    });

    it('applies behavior weights, half-life, repeated quick-skip and clamps dimensions', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const month = 30 * 24 * 60 * 60 * 1000;
      expect(weight(store.recordBehavior(event('play_complete', 1000)), 'AI')).assertEqual(3);
      expect(weight(store.recordBehavior(event('read_complete', 1000 + month)), 'AI')).assertEqual(3.5);
      expect(weight(store.recordBehavior(event('dwell', 1000 + month)), 'AI')).assertEqual(4.5);
      expect(weight(store.recordBehavior(event('quick_skip', 2000 + month)), 'AI')).assertEqual(4.5);
      expect(Math.abs(weight(store.recordBehavior(event('quick_skip', 3000 + month)), 'AI') - 4) < 0.00001)
        .assertTrue();

      for (let index = 0; index < 20; index += 1) {
        store.recordBehavior(event('play_complete', 4000 + month + index, 'positive-' + index.toString()));
      }
      const clamped = store.load();
      expect(weight(clamped, 'AI')).assertEqual(20);
      expect(clamped.sourceWeights[0].weight).assertEqual(20);
      expect(clamped.formatWeights[0].weight).assertEqual(20);
    });

    it('keeps 500 newest evidence and never serializes session or decays explicit rules', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      for (let index = 0; index < 501; index += 1) {
        store.recordBehavior(event('dwell', 1000 + index, 'candidate-' + index.toString()));
      }
      store.applyExplicitPreference({ dimension: 'topic', key: '娱乐八卦', effect: 'block' });
      const profile = store.load();
      expect(profile.recentEvidence.length).assertEqual(500);
      expect(profile.recentEvidence[0].candidateId).assertEqual('candidate-1');
      expect(profile.explicitRules[0].effect).assertEqual('block');
      const raw = native.raw(WATERFALL_PREFERENCES_KEY);
      expect(raw.indexOf('sessionTopicWeights')).assertEqual(-1);
      expect(raw.indexOf('sessionSourceWeights')).assertEqual(-1);
      expect(raw.indexOf('sessionFormatWeights')).assertEqual(-1);
    });

    it('replaces explicit rules without touching implicit weights', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      store.recordBehavior(event('dwell', 1000));
      store.replaceExplicitPreferences([
        { dimension: 'source', key: 'x', effect: 'downweight' },
        { dimension: 'source', key: 'x', effect: 'boost' }
      ]);
      const profile = store.load();
      expect(profile.explicitRules.length).assertEqual(1);
      expect(profile.explicitRules[0].effect).assertEqual('boost');
      expect(weight(profile, 'AI')).assertEqual(1);
      expect(emptyWaterfallPreferenceProfile().discoveryEnabledSources.join(','))
        .assertEqual(aggregateSearchRegistrySourceIds().join(','));
      expect(emptyWaterfallPreferenceProfile().enabledSources.join(','))
        .assertEqual(aggregateSearchRegistrySourceIds().join(','));
    });
  });
}
