import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
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

export default function waterfallPreferencesStoreTest() {
  describe('waterfallPreferencesStore', () => {
    it('recovers malformed profiles and round-trips deduplicated enabled sources', 0, () => {
      const native = new MemoryPreferences();
      native.putSync(WATERFALL_PREFERENCES_KEY, '{');
      const store = new WaterfallPreferencesStore(native as Object as preferences.Preferences);
      expect(store.load().version).assertEqual(1);
      native.putSync(WATERFALL_PREFERENCES_KEY, JSON.stringify({ version: 2 }));
      expect(new WaterfallPreferencesStore(native as Object as preferences.Preferences).load().recentEvidence.length)
        .assertEqual(0);

      const saved = store.saveEnabledSources(['youtube', 'youtube', 'x']);
      expect(saved.enabledSources.join(',')).assertEqual('youtube,x');
      const reopened = new WaterfallPreferencesStore(native as Object as preferences.Preferences).load();
      expect(reopened.enabledSources.join(',')).assertEqual('youtube,x');
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
      expect(emptyWaterfallPreferenceProfile().enabledSources.length).assertEqual(6);
    });
  });
}
