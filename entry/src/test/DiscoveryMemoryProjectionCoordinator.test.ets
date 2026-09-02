import { describe, expect, it } from '@ohos/hypium';
import { LocalModel } from '@loop/agent-core';
import {
  DiscoveryMemoryProjectionCoordinator,
  DiscoveryMemoryProjectionCoordinatorOptions
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjectionCoordinator';
import {
  DiscoveryMemoryProjectionStorePort
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjectionStore';
import {
  DiscoveryMemoryPreferenceProjection,
  DiscoveryMemoryProjectionModelOutput,
  DiscoveryMemoryProjectionModelSignal,
  emptyDiscoveryMemoryPreferenceProjection
} from '../main/ets/pages/A2uiHome/waterfall/DiscoveryMemoryProjection';
import {
  PhoneLocalMemoryMutationEvent,
  PhoneLocalMemoryProjectionSourcePort
} from '../main/ets/memory/PhoneLocalMemoryRuntime';
import {
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats
} from '../main/ets/memory/PhoneLocalMemoryStore';

class ProjectionSource implements PhoneLocalMemoryProjectionSourcePort {
  stats: PhoneLocalMemoryProjectionStats = { changedCount: 0, oldestPendingUpdatedAt: null };
  facts: PhoneLocalMemoryProjectionFact[] = [];
  statsCalls: number = 0;
  listCalls: number = 0;

  getProjectionStats(_watermark: number): Promise<PhoneLocalMemoryProjectionStats> {
    this.statsCalls++;
    return Promise.resolve(this.stats);
  }

  listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]> {
    this.listCalls++;
    return Promise.resolve(this.facts.map((fact: PhoneLocalMemoryProjectionFact): PhoneLocalMemoryProjectionFact => ({
      memoryId: fact.memoryId,
      fact: fact.fact,
      personaTag: fact.personaTag,
      authority: fact.authority,
      updatedAt: fact.updatedAt
    })));
  }
}

class ProjectionStore implements DiscoveryMemoryProjectionStorePort {
  projection: DiscoveryMemoryPreferenceProjection = emptyDiscoveryMemoryPreferenceProjection();
  saveCalls: number = 0;
  onSave: (() => void) | null = null;

  load(): DiscoveryMemoryPreferenceProjection {
    return this.projection;
  }

  save(value: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection | null {
    this.saveCalls++;
    this.projection = value;
    if (this.onSave !== null) this.onSave();
    return value;
  }
}

class DeferredProjectionStatsSource extends ProjectionSource {
  private resolveStats: ((value: PhoneLocalMemoryProjectionStats) => void) | null = null;

  getProjectionStats(_watermark: number): Promise<PhoneLocalMemoryProjectionStats> {
    this.statsCalls++;
    return new Promise<PhoneLocalMemoryProjectionStats>(
      (resolve: (value: PhoneLocalMemoryProjectionStats) => void): void => {
        this.resolveStats = resolve;
      }
    );
  }

  releaseStats(value: PhoneLocalMemoryProjectionStats): void {
    if (this.resolveStats !== null) this.resolveStats(value);
  }
}

class ProjectionModel implements LocalModel {
  calls: number = 0;

  complete(_prompt: string): Promise<string> {
    this.calls++;
    const signals: DiscoveryMemoryProjectionModelSignal[] = [{
      dimension: 'topic',
      key: '人工智能',
      polarity: 'positive',
      strength: 'strong',
      evidenceMemoryIds: ['memory-ai']
    }];
    const output: DiscoveryMemoryProjectionModelOutput = { signals };
    return Promise.resolve(JSON.stringify(output));
  }
}

class DeferredProjectionModel implements LocalModel {
  calls: number = 0;
  private resolveOutput: ((value: string) => void) | null = null;

  complete(_prompt: string): Promise<string> {
    this.calls++;
    return new Promise<string>((resolve: (value: string) => void): void => {
      this.resolveOutput = resolve;
    });
  }

  releaseOutput(): void {
    const signals: DiscoveryMemoryProjectionModelSignal[] = [{
      dimension: 'topic', key: '人工智能', polarity: 'positive', strength: 'strong',
      evidenceMemoryIds: ['memory-ai']
    }];
    const output: DiscoveryMemoryProjectionModelOutput = { signals };
    if (this.resolveOutput !== null) this.resolveOutput(JSON.stringify(output));
  }
}

function settleProjection(): Promise<void> {
  return new Promise<void>((resolve: () => void): void => {
    setTimeout(resolve, 20);
  });
}

export default function discoveryMemoryProjectionCoordinatorTest() {
  describe('discoveryMemoryProjectionCoordinator', () => {
    it('does not call the model below both pending thresholds', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      source.stats = { changedCount: 1, oldestPendingUpdatedAt: 9999 };
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model,
        now: (): number => 10000
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      coordinator.requestRefresh();
      await settleProjection();
      expect(source.statsCalls).assertEqual(1);
      expect(source.listCalls).assertEqual(0);
      expect(model.calls).assertEqual(0);
      expect(store.saveCalls).assertEqual(0);
    });

    it('rebuilds a threshold batch and advances to the included memory timestamp', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      source.stats = { changedCount: 8, oldestPendingUpdatedAt: 1000 };
      source.facts = [{
        memoryId: 'memory-ai',
        fact: '用户喜欢人工智能内容',
        personaTag: 'entertainment_companion',
        authority: 'leader',
        updatedAt: 12345
      }];
      let published: DiscoveryMemoryPreferenceProjection = emptyDiscoveryMemoryPreferenceProjection();
      let publishedCalled: boolean = false;
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model,
        onProjection: (value: DiscoveryMemoryPreferenceProjection): void => {
          published = value;
          publishedCalled = true;
        }
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      coordinator.requestRefresh();
      await settleProjection();
      expect(model.calls).assertEqual(1);
      expect(store.projection.basedOnMemoryMutationAt).assertEqual(12345);
      expect(store.projection.signals.length).assertEqual(1);
      expect(publishedCalled).assertTrue();
      expect(published.signals[0].key).assertEqual('人工智能');
    });

    it('forces forget rebuilding and advances an empty snapshot to commit time', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      store.projection = {
        basedOnMemoryMutationAt: 40000,
        signals: [{
          dimension: 'topic', key: '人工智能', polarity: 'positive', strength: 'strong',
          evidenceMemoryIds: ['forgotten'], baseWeight: 4.5, lastSupportedAt: 40000
        }]
      };
      const options: DiscoveryMemoryProjectionCoordinatorOptions = {
        source,
        store,
        modelProvider: (): LocalModel => model
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator(options);
      const event: PhoneLocalMemoryMutationEvent = {
        operation: 'forget', committedAt: 45678, memoryIds: ['forgotten']
      };
      coordinator.notify(event);
      expect(coordinator.current().signals.length).assertEqual(0);
      await settleProjection();
      expect(source.listCalls).assertEqual(1);
      expect(model.calls).assertEqual(0);
      expect(store.projection.basedOnMemoryMutationAt).assertEqual(45678);
      expect(store.projection.signals.length).assertEqual(0);
    });

    it('stops after pending stats resolve for an inactive owner', 0, async () => {
      const source = new DeferredProjectionStatsSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      let active: boolean = true;
      const coordinator = new DiscoveryMemoryProjectionCoordinator({
        source,
        store,
        modelProvider: (): LocalModel => model,
        isActive: (): boolean => active
      });
      coordinator.requestRefresh();
      await settleProjection();
      expect(source.statsCalls).assertEqual(1);
      active = false;
      source.releaseStats({ changedCount: 8, oldestPendingUpdatedAt: 1000 });
      await settleProjection();
      expect(source.listCalls).assertEqual(0);
      expect(model.calls).assertEqual(0);
      expect(store.saveCalls).assertEqual(0);
    });

    it('does not save or publish a model result after the owner becomes inactive', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new DeferredProjectionModel();
      source.stats = { changedCount: 8, oldestPendingUpdatedAt: 1000 };
      source.facts = [{
        memoryId: 'memory-ai', fact: '用户喜欢人工智能内容', personaTag: 'default_companion',
        authority: 'leader', updatedAt: 12345
      }];
      let active: boolean = true;
      let publishCalls: number = 0;
      const coordinator = new DiscoveryMemoryProjectionCoordinator({
        source,
        store,
        modelProvider: (): LocalModel => model,
        isActive: (): boolean => active,
        onProjection: (_value: DiscoveryMemoryPreferenceProjection): void => {
          publishCalls++;
        }
      });
      coordinator.requestRefresh();
      await settleProjection();
      expect(model.calls).assertEqual(1);
      active = false;
      model.releaseOutput();
      await settleProjection();
      expect(store.saveCalls).assertEqual(0);
      expect(publishCalls).assertEqual(0);
    });

    it('allows an old scoped save but rejects its publish when ownership changes during save', 0, async () => {
      const source = new ProjectionSource();
      const store = new ProjectionStore();
      const model = new ProjectionModel();
      source.stats = { changedCount: 8, oldestPendingUpdatedAt: 1000 };
      source.facts = [{
        memoryId: 'memory-ai', fact: '用户喜欢人工智能内容', personaTag: 'default_companion',
        authority: 'leader', updatedAt: 12345
      }];
      let active: boolean = true;
      let publishCalls: number = 0;
      store.onSave = (): void => {
        active = false;
      };
      const coordinator = new DiscoveryMemoryProjectionCoordinator({
        source,
        store,
        modelProvider: (): LocalModel => model,
        isActive: (): boolean => active,
        onProjection: (_value: DiscoveryMemoryPreferenceProjection): void => {
          publishCalls++;
        }
      });
      coordinator.requestRefresh();
      await settleProjection();
      expect(store.saveCalls).assertEqual(1);
      expect(publishCalls).assertEqual(0);
    });
  });
}
