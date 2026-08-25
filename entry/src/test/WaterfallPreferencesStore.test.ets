import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  aggregateSearchSourcesFromArgs,
  configureWaterfallEnabledSourcesForRuntime,
  AggregateSearchSource,
  AggregateSearchSourceMetadata,
  aggregateSearchDefaultEnabledSourceIds,
  aggregateSearchRegistryMetadata,
  aggregateSearchRegistrySourceIds,
  aggregateSearchInterestSourceIds,
  aggregateSearchSearchSourceIds,
  aggregateSearchRegistryVersion,
  WaterfallCandidate,
  WaterfallExplicitPreference,
  WaterfallPreferenceWeight
} from '@loop/agent-core';
import {
  emptyWaterfallPreferenceProfile,
  WATERFALL_CARDS_KEY,
  WATERFALL_PREFERENCES_KEY,
  WaterfallBehaviorEvidence,
  WaterfallCardRecord,
  WaterfallPreferenceProfile,
  WaterfallPreferencesStore,
  waterfallCandidateFromSavedCard,
  waterfallReactionWeights
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

function card(id: string = 'candidate-1'): WaterfallCandidate {
  return {
    id,
    source: 'youtube',
    mediaType: 'video',
    title: 'AI agent demo',
    summary: 'A compact summary',
    url: 'https://www.youtube.com/watch?v=abc123',
    coverUrl: 'https://i.example/cover.jpg',
    publishedAt: '2026-08-24T00:00:00.000Z',
    originalIndex: 0,
    authorName: 'OpenAI',
    topics: ['AI', 'agent'],
    format: 'landscape_video'
  };
}

function projectedWeight(weights: WaterfallPreferenceWeight[], key: string): number {
  for (let index = 0; index < weights.length; index += 1) {
    if (weights[index].key === key) return weights[index].weight;
  }
  return 0;
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
        .assertEqual('youtube,x,applepodcasts,twitch,github,steam,cnnews,globalnews');

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

    it('uses the same registered source set for keyword search and discovery', 0, () => {
      const newSources: AggregateSearchSource[] = ['github', 'steam', 'cnnews', 'globalnews'];
      const metadata = aggregateSearchRegistryMetadata();

      expect(aggregateSearchSearchSourceIds().join(','))
        .assertEqual(aggregateSearchInterestSourceIds().join(','));
      newSources.forEach((source: AggregateSearchSource): void => {
        const row = metadata.filter((item: AggregateSearchSourceMetadata): boolean => item.source === source)[0];
        expect(aggregateSearchSearchSourceIds().indexOf(source)).assertLarger(-1);
        expect(aggregateSearchInterestSourceIds().indexOf(source)).assertLarger(-1);
        expect(row.capabilities.search).assertTrue();
        expect(row.capabilities.interest).assertTrue();
        expect(row.defaultEnabled).assertTrue();
        expect(row.introducedInRegistryVersion).assertEqual(4);
      });
      expect(metadata.filter((item: AggregateSearchSourceMetadata): boolean =>
        ['chinanews', 'ithome', 'sspai', 'ifanr', 'v2ex'].indexOf(item.source) >= 0).length).assertEqual(0);
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
        .assertEqual(aggregateSearchDefaultEnabledSourceIds().join(','));
      expect(emptyWaterfallPreferenceProfile().enabledSources.join(','))
        .assertEqual(aggregateSearchDefaultEnabledSourceIds().join(','));
    });

    it('keeps Like and Dislike mutually exclusive while Save stays independent and undo restores time', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      let records: WaterfallCardRecord[] = store.applyCardAction(card(), 'like', true, 1000);
      expect(records[0].reaction).assertEqual('like');
      expect(records[0].saved).assertFalse();

      records = store.applyCardAction(card(), 'dislike', true, 2000);
      expect(records.length).assertEqual(1);
      expect(records[0].reaction).assertEqual('dislike');

      records = store.applyCardAction(card(), 'dislike', false, 3000);
      expect(records[0].reaction).assertEqual('none');
      records = store.applyCardAction(card(), 'save', true, 4000);
      expect(records[0].saved).assertTrue();
      expect(records[0].savedAt).assertEqual(4000);

      records = store.applyCardAction(card(), 'like', true, 5000);
      expect(records[0].reaction).assertEqual('like');
      expect(records[0].saved).assertTrue();
      records = store.applyCardAction(card(), 'save', false, 6000);
      expect(records[0].saved).assertFalse();
      expect(records[0].savedAt).assertEqual(4000);
      expect(records[0].snapshot.title).assertEqual('AI agent demo');

      records = store.applyCardAction(card(), 'save', true, 7000, true);
      expect(records[0].savedAt).assertEqual(4000);
      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      expect(reopened.loadCardRecords()[0].savedAt).assertEqual(4000);
    });

    it('round-trips direct playback URLs through saved card snapshots', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const hostedVideo = card('hosted-video');
      hostedVideo.url = 'https://videos.example/watch/hosted-video';
      hostedVideo.mediaUrl = 'https://cdn.example/hosted-video.mp4';
      store.applyCardAction(hostedVideo, 'save', true, 1000);

      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const restored = waterfallCandidateFromSavedCard(reopened.loadCardRecords()[0].snapshot);
      expect(restored.mediaUrl).assertEqual('https://cdn.example/hosted-video.mp4');
    });

    it('round-trips detail comment metadata through saved card snapshots', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const commented = card('saved-comments');
      commented.providerItemId = 'video-comments';
      commented.comments = [{ text: 'Useful comment', authorName: 'Reader', likeCount: 7 }];
      commented.commentLoadState = 'ready';
      store.applyCardAction(commented, 'save', true, 1000);

      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const restored = waterfallCandidateFromSavedCard(reopened.loadCardRecords()[0].snapshot);
      expect(restored.providerItemId).assertEqual('video-comments');
      expect(restored.commentLoadState).assertEqual('ready');
      expect(restored.comments?.length).assertEqual(1);
      expect(restored.comments?.[0].authorName).assertEqual('Reader');
    });

    it('restores saved Reddit cards through the reachable image cache', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const reddit = card('reddit-image');
      reddit.source = 'reddit';
      reddit.mediaType = 'image_text';
      reddit.coverUrl = 'https://i.redd.it/reddit-image.jpeg';
      store.applyCardAction(reddit, 'save', true, 1000);

      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      const restored = waterfallCandidateFromSavedCard(reopened.loadCardRecords()[0].snapshot);
      expect(restored.coverUrl).assertEqual(
        'https://wsrv.nl/?url=https%3A%2F%2Fi.redd.it%2Freddit-image.jpeg&output=webp&w=1200');
    });

    it('keeps saved cards when card records exceed the bound', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      store.applyCardAction(card('saved-card'), 'save', true, 1000);
      for (let index = 0; index < 500; index += 1) {
        store.applyCardAction(card('reaction-' + index.toString()), 'like', true, 2000 + index);
      }

      const records = store.loadCardRecords();
      expect(records.length).assertEqual(500);
      expect(records.filter((record: WaterfallCardRecord): boolean =>
        record.candidateId === 'saved-card' && record.saved).length).assertEqual(1);
    });

    it('derives current Reaction weights without counting Save and rejects malformed stored cards', 0, () => {
      const native = new MemoryPreferences();
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      store.applyCardAction(card('liked'), 'like', true, 1000);
      const disliked = card('disliked');
      disliked.source = 'reddit';
      disliked.topics = ['科技'];
      disliked.format = 'text';
      store.applyCardAction(disliked, 'dislike', true, 2000);
      store.applyCardAction(card('saved-only'), 'save', true, 3000);

      const projection = waterfallReactionWeights(store.loadCardRecords());
      expect(projectedWeight(projection.topicWeights, 'AI')).assertEqual(4);
      expect(projectedWeight(projection.topicWeights, 'agent')).assertEqual(4);
      expect(projectedWeight(projection.topicWeights, '科技')).assertEqual(-4);
      expect(projectedWeight(projection.sourceWeights, 'youtube')).assertEqual(4);
      expect(projectedWeight(projection.sourceWeights, 'reddit')).assertEqual(-4);
      expect(projectedWeight(projection.formatWeights, 'landscape_video')).assertEqual(4);
      expect(projectedWeight(projection.formatWeights, 'text')).assertEqual(-4);

      native.putSync(WATERFALL_CARDS_KEY, '{');
      const malformed = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      expect(malformed.loadCardRecords().length).assertEqual(0);
      expect(native.raw(WATERFALL_PREFERENCES_KEY).indexOf('saved-only')).assertEqual(-1);
    });
  });
}
