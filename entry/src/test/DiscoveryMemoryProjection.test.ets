import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  DISCOVERY_MEMORY_PREFERENCE_HALF_LIFE_MS,
  DISCOVERY_MEMORY_PROJECTION_WAIT_MS,
  DiscoveryMemoryPreferenceProjection,
  DiscoveryMemoryProjectionFact,
  DiscoveryMemoryProjectionModelOutput,
  DiscoveryMemoryProjectionModelSignal,
  discoveryMemoryBaseWeight,
  discoveryMemoryEffectiveWeight,
  discoveryMemoryPreferenceProjectionFromModelOutput,
  discoveryMemoryProjectionPrompt,
  discoveryMemoryProjectionSnapshot,
  discoveryMemoryProjectionWithoutEvidence,
  maxIncludedMemoryMutationAt,
  projectionSignalsFromModelOutput,
  shouldRebuildDiscoveryMemoryProjection
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjection';
import {
  DISCOVERY_MEMORY_PROJECTION_KEY,
  DiscoveryMemoryProjectionStore
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjectionStore';

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

function facts(): DiscoveryMemoryProjectionFact[] {
  return [
    { memoryId: 'm-ai', fact: '用户喜欢人工智能内容', updatedAt: 1000, authority: 'leader' },
    { memoryId: 'm-video', fact: '用户不喜欢竖屏短视频', updatedAt: 2000, authority: 'leader' }
  ];
}

export default function discoveryMemoryProjectionTest() {
  describe('discoveryMemoryProjection', () => {
    it('uses count or oldest pending time without a dirty flag', 0, () => {
      expect(shouldRebuildDiscoveryMemoryProjection({ changedCount: 8, oldestPendingUpdatedAt: 999 }, 1000))
        .assertTrue();
      expect(shouldRebuildDiscoveryMemoryProjection({ changedCount: 2, oldestPendingUpdatedAt: 1000 },
        1000 + DISCOVERY_MEMORY_PROJECTION_WAIT_MS)).assertTrue();
      expect(shouldRebuildDiscoveryMemoryProjection({ changedCount: 2, oldestPendingUpdatedAt: 1000 }, 2000))
        .assertFalse();
      expect(shouldRebuildDiscoveryMemoryProjection({ changedCount: 0, oldestPendingUpdatedAt: 0 },
        1000 + DISCOVERY_MEMORY_PROJECTION_WAIT_MS)).assertFalse();
    });

    it('parses constrained signals and derives host-owned weights and support time', 0, () => {
      const modelSignals: DiscoveryMemoryProjectionModelSignal[] = [
        { dimension: 'topic', key: ' 人工智能 ', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['m-ai', 'invented'] },
        { dimension: 'format', key: 'portrait_video', polarity: 'negative', strength: 'medium',
          evidenceMemoryIds: ['m-video'] },
        { dimension: 'source', key: 'unknown', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['m-ai'] }
      ];
      const modelOutput: DiscoveryMemoryProjectionModelOutput = { signals: modelSignals };
      const raw = 'result: ' + JSON.stringify(modelOutput);
      const signals = projectionSignalsFromModelOutput(raw, facts());
      expect(signals === null).assertFalse();
      expect(signals?.length).assertEqual(2);
      expect(signals?.[0].key).assertEqual('人工智能');
      expect(signals?.[0].baseWeight).assertEqual(4.5);
      expect(signals?.[0].lastSupportedAt).assertEqual(1000);
      expect(signals?.[0].evidenceMemoryIds.join(',')).assertEqual('m-ai');
      expect(signals?.[1].baseWeight).assertEqual(-3);
    });

    it('does not let duplicate evidence naively add or conflicts amplify a key', 0, () => {
      const modelSignals: DiscoveryMemoryProjectionModelSignal[] = [
        { dimension: 'topic', key: 'AI', polarity: 'positive', strength: 'weak', evidenceMemoryIds: ['m-ai'] },
        { dimension: 'topic', key: 'ai', polarity: 'positive', strength: 'strong', evidenceMemoryIds: ['m-ai'] },
        { dimension: 'format', key: 'portrait_video', polarity: 'positive', strength: 'medium',
          evidenceMemoryIds: ['m-video'] },
        { dimension: 'format', key: 'portrait_video', polarity: 'negative', strength: 'medium',
          evidenceMemoryIds: ['m-video'] }
      ];
      const modelOutput: DiscoveryMemoryProjectionModelOutput = { signals: modelSignals };
      const raw = JSON.stringify(modelOutput);
      const signals = projectionSignalsFromModelOutput(raw, facts());
      expect(signals?.length).assertEqual(1);
      expect(signals?.[0].baseWeight).assertEqual(4.5);
    });

    it('applies a 180 day half-life when converting to waterfall weights', 0, () => {
      const projection: DiscoveryMemoryPreferenceProjection = {
        basedOnMemoryMutationAt: 2000,
        signals: [{
          dimension: 'topic',
          key: 'AI',
          polarity: 'positive',
          strength: 'strong',
          evidenceMemoryIds: ['m-ai'],
          baseWeight: discoveryMemoryBaseWeight('strong', 'positive'),
          lastSupportedAt: 1000
        }]
      };
      expect(discoveryMemoryEffectiveWeight(projection.signals[0], 1000 + DISCOVERY_MEMORY_PREFERENCE_HALF_LIFE_MS))
        .assertEqual(2.25);
      const snapshot = discoveryMemoryProjectionSnapshot(
        projection, 1000 + DISCOVERY_MEMORY_PREFERENCE_HALF_LIFE_MS);
      expect(snapshot.topicWeights[0].weight).assertEqual(2.25);
      expect(snapshot.topicWeights[0].updatedAt).assertEqual(1000);
      expect(snapshot.explicitRules.length).assertEqual(0);
    });

    it('uses already loaded fact timestamps for the successful watermark', 0, () => {
      expect(maxIncludedMemoryMutationAt(facts())).assertEqual(2000);
      expect(maxIncludedMemoryMutationAt(facts(), 3000)).assertEqual(3000);
    });

    it('removes any signal that cites explicitly forgotten evidence before rebuilding', 0, () => {
      const projection: DiscoveryMemoryPreferenceProjection = {
        basedOnMemoryMutationAt: 2000,
        signals: [{
          dimension: 'topic', key: '人工智能', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['m-ai', 'm-other'], baseWeight: 4.5, lastSupportedAt: 2000
        }, {
          dimension: 'format', key: 'portrait_video', polarity: 'negative', strength: 'medium',
          evidenceMemoryIds: ['m-video'], baseWeight: -3, lastSupportedAt: 2000
        }]
      };
      const pruned = discoveryMemoryProjectionWithoutEvidence(projection, ['m-ai']);
      expect(pruned.basedOnMemoryMutationAt).assertEqual(2000);
      expect(pruned.signals.length).assertEqual(1);
      expect(pruned.signals[0].key).assertEqual('portrait_video');
    });

    it('retains unmentioned old support but removes forgotten or updated evidence', 0, () => {
      const previous: DiscoveryMemoryPreferenceProjection = {
        basedOnMemoryMutationAt: 1000,
        signals: [{
          dimension: 'topic', key: '人工智能', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['m-ai'], baseWeight: 4.5, lastSupportedAt: 1000
        }]
      };
      const unchanged = discoveryMemoryPreferenceProjectionFromModelOutput(
        '{"signals":[]}', facts(), previous);
      expect(unchanged?.signals.length).assertEqual(1);
      const updatedFacts = facts();
      updatedFacts[0].updatedAt = 3000;
      const afterUpdate = discoveryMemoryPreferenceProjectionFromModelOutput(
        '{"signals":[]}', updatedFacts, previous);
      expect(afterUpdate?.signals.length).assertEqual(0);
      const afterForget = discoveryMemoryPreferenceProjectionFromModelOutput(
        '{"signals":[]}', [facts()[1]], previous, 4000);
      expect(afterForget?.signals.length).assertEqual(0);
      expect(afterForget?.basedOnMemoryMutationAt).assertEqual(4000);
    });

    it('round-trips only the watermark and validated signals', 0, () => {
      const native = new MemoryPreferences();
      const store = new DiscoveryMemoryProjectionStore(native as Object as preferences.Preferences);
      const modelSignals: DiscoveryMemoryProjectionModelSignal[] = [{
        dimension: 'topic', key: 'AI', polarity: 'positive', strength: 'medium', evidenceMemoryIds: ['m-ai']
      }];
      const modelOutput: DiscoveryMemoryProjectionModelOutput = { signals: modelSignals };
      const signals = projectionSignalsFromModelOutput(JSON.stringify(modelOutput), facts());
      const saved = store.save({ basedOnMemoryMutationAt: 2000, signals: signals ?? [] });
      expect(saved === null).assertFalse();
      const raw = native.raw(DISCOVERY_MEMORY_PROJECTION_KEY);
      expect(raw.indexOf('basedOnMemoryMutationAt') >= 0).assertTrue();
      expect(raw.indexOf('projectionGeneratedAt')).assertEqual(-1);
      expect(raw.indexOf('dirty')).assertEqual(-1);
      const reopened = new DiscoveryMemoryProjectionStore(native as Object as preferences.Preferences).load();
      expect(reopened.basedOnMemoryMutationAt).assertEqual(2000);
      expect(reopened.signals[0].baseWeight).assertEqual(3);

      native.putSync(DISCOVERY_MEMORY_PROJECTION_KEY, '{');
      const malformed = new DiscoveryMemoryProjectionStore(native as Object as preferences.Preferences).load();
      expect(malformed.signals.length).assertEqual(0);
      expect(malformed.basedOnMemoryMutationAt).assertEqual(0);
    });

    it('builds a bounded prompt with the registered vocabulary and semantic deduplication contract', 0, () => {
      const prompt = discoveryMemoryProjectionPrompt(facts());
      expect(prompt.indexOf('evidenceMemoryIds') >= 0).assertTrue();
      expect(prompt.indexOf('youtube') >= 0).assertTrue();
      expect(prompt.indexOf('portrait_video') >= 0).assertTrue();
      expect(prompt.indexOf('m-ai') >= 0).assertTrue();
      expect(prompt.indexOf('同一语义只输出一个 key') >= 0).assertTrue();
      expect(prompt.indexOf('不要同时输出跨语言同义词或翻译别名') >= 0).assertTrue();
      expect(prompt.indexOf('优先沿用证据记忆的原文语言') >= 0).assertTrue();
    });
  });
}
