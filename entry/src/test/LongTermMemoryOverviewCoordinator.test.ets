import { describe, expect, it } from '@ohos/hypium';
import {
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryError,
  MemoryWriteResult
} from '@loop/agent-core';
import {
  LongTermMemoryModelOutcome,
  LongTermMemoryOverviewCoordinator,
  LongTermMemoryOverviewTaskPort
} from '../main/ets/memory/LongTermMemoryOverviewCoordinator';
import {
  MemoryCorrectionPlan,
  MemoryOverview,
  MemoryOverviewClaim,
  MemoryOverviewEvidenceIndex,
  MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
  MEMORY_OVERVIEW_PROMPT_VERSION,
  buildMemoryOverviewEvidenceIndex,
  memoryOverviewEvidenceFingerprint
} from '../main/ets/memory/MemoryOverview';
import {
  MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
  MemoryOverviewCacheEntry,
  MemoryOverviewCacheStorePort
} from '../main/ets/memory/MemoryOverviewCacheStore';
import {
  PhoneLocalMemoryOverviewSourcePort,
  PhoneLocalMemoryRuntimePort,
  PhoneLocalMemorySnapshot,
  PhoneLocalMemoryUpdate,
  PhoneLocalRecalledMemory
} from '../main/ets/memory/PhoneLocalMemoryRuntime';
import {
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats
} from '../main/ets/memory/PhoneLocalMemoryStore';

function copySnapshot(value: PhoneLocalMemorySnapshot): PhoneLocalMemorySnapshot {
  return {
    memoryId: value.memoryId,
    fact: value.fact,
    personaTag: value.personaTag,
    authority: value.authority,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt
  };
}

class OverviewSource implements PhoneLocalMemoryOverviewSourcePort {
  snapshots: PhoneLocalMemorySnapshot[] = [];
  listCalls: number = 0;
  getCalls: number = 0;

  listAllMemorySnapshots(): Promise<PhoneLocalMemorySnapshot[]> {
    this.listCalls += 1;
    return Promise.resolve(this.snapshots.map(
      (snapshot: PhoneLocalMemorySnapshot): PhoneLocalMemorySnapshot => copySnapshot(snapshot)
    ));
  }

  getMemorySnapshot(memoryId: string): Promise<PhoneLocalMemorySnapshot | null> {
    this.getCalls += 1;
    for (let position = 0; position < this.snapshots.length; position += 1) {
      if (this.snapshots[position].memoryId === memoryId) {
        return Promise.resolve(copySnapshot(this.snapshots[position]));
      }
    }
    return Promise.resolve(null);
  }
}

class OverviewRuntime implements PhoneLocalMemoryRuntimePort {
  readonly source: OverviewSource;
  rememberCalls: number = 0;
  updateCalls: number = 0;
  forgetCalls: number = 0;
  updatePersonaTags: string[] = [];
  failAtWriteCall: number = -1;
  writeCalls: number = 0;
  mutateBeforeConditionalWrite: boolean = false;
  mutateAtConditionalWriteCall: number = -1;
  conditionalWriteCalls: number = 0;

  constructor(source: OverviewSource) {
    this.source = source;
  }

  recall(_text: string, _topK?: number): Promise<PhoneLocalRecalledMemory[]> {
    return Promise.resolve([]);
  }

  remember(facts: string[], _sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.rememberCalls += 1;
    this.writeCalls += 1;
    if (this.shouldFail(guard)) return Promise.resolve(this.failedBatch());
    const timestamp = 1000 + this.writeCalls;
    this.source.snapshots.push({
      memoryId: 'added-' + this.writeCalls.toString(), fact: facts[0], personaTag,
      authority: 'leader', createdAt: timestamp, updatedAt: timestamp
    });
    return Promise.resolve(this.successBatch());
  }

  update(updates: PhoneLocalMemoryUpdate[], _sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.updateCalls += 1;
    this.updatePersonaTags.push(personaTag);
    this.writeCalls += 1;
    if (this.shouldFail(guard)) return Promise.resolve(this.failedBatch());
    for (let position = 0; position < this.source.snapshots.length; position += 1) {
      if (this.source.snapshots[position].memoryId === updates[0].memoryId) {
        this.source.snapshots[position].fact = updates[0].fact;
        this.source.snapshots[position].personaTag = personaTag;
        this.source.snapshots[position].updatedAt += 1;
      }
    }
    return Promise.resolve(this.successBatch());
  }

  forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.forgetCalls += 1;
    this.writeCalls += 1;
    if (this.shouldFail(guard)) return Promise.resolve(this.failedBatch());
    this.source.snapshots = this.source.snapshots.filter(
      (snapshot: PhoneLocalMemorySnapshot): boolean => snapshot.memoryId !== memoryIds[0]
    );
    return Promise.resolve(this.successBatch());
  }

  updateIfSnapshotCurrent(update: PhoneLocalMemoryUpdate, sourceTurnId: string, personaTag: string,
    expected: PhoneLocalMemorySnapshot, guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.applyConditionalRace(expected.memoryId);
    if (!this.snapshotMatches(expected)) return Promise.resolve(this.conflictBatch());
    return this.update([update], sourceTurnId, personaTag, guard);
  }

  forgetIfSnapshotCurrent(memoryId: string, expected: PhoneLocalMemorySnapshot,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.applyConditionalRace(expected.memoryId);
    if (!this.snapshotMatches(expected)) return Promise.resolve(this.conflictBatch());
    return this.forget([memoryId], guard);
  }

  getProjectionStats(_basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    const stats: PhoneLocalMemoryProjectionStats = { changedCount: 0, oldestPendingUpdatedAt: null };
    return Promise.resolve(stats);
  }

  listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]> {
    return Promise.resolve([]);
  }

  private shouldFail(guard?: MemoryCommitGuard): boolean {
    return (guard !== undefined && !guard.isActive()) || this.writeCalls === this.failAtWriteCall;
  }

  private applyConditionalRace(memoryId: string): void {
    this.conditionalWriteCalls += 1;
    if (!this.mutateBeforeConditionalWrite &&
      this.conditionalWriteCalls !== this.mutateAtConditionalWriteCall) return;
    this.mutateBeforeConditionalWrite = false;
    for (let position = 0; position < this.source.snapshots.length; position += 1) {
      if (this.source.snapshots[position].memoryId !== memoryId) continue;
      this.source.snapshots[position].fact = '竞态写入的新值';
      this.source.snapshots[position].updatedAt += 1;
    }
  }

  private snapshotMatches(expected: PhoneLocalMemorySnapshot): boolean {
    for (let position = 0; position < this.source.snapshots.length; position += 1) {
      const actual = this.source.snapshots[position];
      if (actual.memoryId !== expected.memoryId) continue;
      return actual.fact === expected.fact && actual.personaTag === expected.personaTag &&
        actual.authority === expected.authority && actual.createdAt === expected.createdAt &&
        actual.updatedAt === expected.updatedAt;
    }
    return false;
  }

  private successBatch(): MemoryBatchResult {
    const records: MemoryWriteResult[] = [{ inputIndex: 0, status: 'success' }];
    return { status: 'success', records, succeededCount: 1, failedCount: 0, warnings: [] };
  }

  private failedBatch(): MemoryBatchResult {
    const records: MemoryWriteResult[] = [{ inputIndex: 0, status: 'error' }];
    return {
      status: 'error', records, succeededCount: 0, failedCount: 1, warnings: [],
      error: { code: 'test_write_failed', message: 'Test write failed.', retryable: true }
    };
  }

  private conflictBatch(): MemoryBatchResult {
    const error: MemoryError = {
      code: 'memory_write_conflict', message: 'Memory changed.', retryable: false
    };
    const records: MemoryWriteResult[] = [{ inputIndex: 0, status: 'error', error }];
    return { status: 'error', records, succeededCount: 0, failedCount: 1, warnings: [], error };
  }
}

class OverviewTaskPort implements LongTermMemoryOverviewTaskPort {
  overviewCalls: number = 0;
  planCalls: number = 0;
  nextPlan: MemoryCorrectionPlan | null = null;

  generateOverview(index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>> {
    this.overviewCalls += 1;
    if (!isActive()) {
      const inactive: LongTermMemoryModelOutcome<MemoryOverview> = {
        status: 'inactive', value: null, message: '', modelCallCount: 0
      };
      return Promise.resolve(inactive);
    }
    const evidenceMemoryIds: string[] = [];
    for (let position = 0; position < index.entries.length; position += 1) {
      evidenceMemoryIds.push(index.entries[position].memoryId);
    }
    const claims: MemoryOverviewClaim[] = index.entries.length === 0 ? [] : [{
      heading: '偏好', body: index.entries[0].fact, evidenceMemoryIds
    }];
    const overview: MemoryOverview = {
      title: '你的长期记忆',
      summary: '共 ' + index.entries.length.toString() + ' 条',
      claims
    };
    const success: LongTermMemoryModelOutcome<MemoryOverview> = {
      status: 'success',
      value: overview,
      message: '',
      modelCallCount: 1
    };
    return Promise.resolve(success);
  }

  planCorrection(_userFeedback: string, _overview: MemoryOverview,
    _index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>> {
    this.planCalls += 1;
    if (!isActive()) {
      const inactive: LongTermMemoryModelOutcome<MemoryCorrectionPlan> = {
        status: 'inactive', value: null, message: '', modelCallCount: 0
      };
      return Promise.resolve(inactive);
    }
    const result: LongTermMemoryModelOutcome<MemoryCorrectionPlan> = {
      status: this.nextPlan === null ? 'error' : 'success',
      value: this.nextPlan,
      message: this.nextPlan === null ? 'No plan.' : '',
      modelCallCount: 1
    };
    return Promise.resolve(result);
  }
}

class DeferredOverviewTaskPort implements LongTermMemoryOverviewTaskPort {
  private resolveOverview: ((value: LongTermMemoryModelOutcome<MemoryOverview>) => void) | undefined;

  generateOverview(_index: MemoryOverviewEvidenceIndex,
    _isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>> {
    return new Promise<LongTermMemoryModelOutcome<MemoryOverview>>(
      (resolve: (value: LongTermMemoryModelOutcome<MemoryOverview>) => void): void => {
        this.resolveOverview = resolve;
      }
    );
  }

  planCorrection(_feedback: string, _overview: MemoryOverview,
    _index: MemoryOverviewEvidenceIndex,
    _isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>> {
    const result: LongTermMemoryModelOutcome<MemoryCorrectionPlan> = {
      status: 'error', value: null, message: '', modelCallCount: 0
    };
    return Promise.resolve(result);
  }

  releaseOverview(value: LongTermMemoryModelOutcome<MemoryOverview>): void {
    const resolve = this.resolveOverview;
    if (resolve !== undefined) resolve(value);
  }
}

class FailSecondOverviewTaskPort extends OverviewTaskPort {
  generateOverview(index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>> {
    if (this.overviewCalls < 1) return super.generateOverview(index, isActive);
    this.overviewCalls += 1;
    const result: LongTermMemoryModelOutcome<MemoryOverview> = {
      status: 'error', value: null, message: 'Overview refresh failed.', modelCallCount: 1
    };
    return Promise.resolve(result);
  }
}

class OverviewCache implements MemoryOverviewCacheStorePort {
  entry: MemoryOverviewCacheEntry | null = null;
  loadCalls: number = 0;
  saveCalls: number = 0;
  clearCalls: number = 0;

  load(): MemoryOverviewCacheEntry | null {
    this.loadCalls += 1;
    return this.entry;
  }

  save(value: MemoryOverviewCacheEntry): MemoryOverviewCacheEntry | null {
    this.saveCalls += 1;
    this.entry = value;
    return value;
  }

  clear(): void {
    this.clearCalls += 1;
    this.entry = null;
  }
}

class ThrowingOverviewCache implements MemoryOverviewCacheStorePort {
  load(): MemoryOverviewCacheEntry | null {
    throw new Error('read failed');
  }

  save(_value: MemoryOverviewCacheEntry): MemoryOverviewCacheEntry | null {
    throw new Error('write failed');
  }

  clear(): void {
    throw new Error('clear failed');
  }
}

class UnclearableOverviewCache extends OverviewCache {
  clear(): void {
    this.clearCalls += 1;
    throw new Error('clear failed');
  }
}

function snapshot(memoryId: string, fact: string, personaTag: string = 'global',
  updatedAt: number = 100): PhoneLocalMemorySnapshot {
  return {
    memoryId, fact, personaTag, authority: 'leader', createdAt: 50, updatedAt
  };
}

function evidenceFingerprint(snapshots: PhoneLocalMemorySnapshot[]): string {
  return memoryOverviewEvidenceFingerprint(buildMemoryOverviewEvidenceIndex(snapshots));
}

function presentationPlan(): MemoryCorrectionPlan {
  return {
    status: 'ready', clarificationQuestion: '',
    operations: [{
      type: 'presentation_only', claimIndex: 1,
      replacementHeading: '更准确的偏好', replacementBody: '只是改写概览', reason: '用户要求换种说法'
    }],
    diffs: [{
      type: 'presentation_only', target: 'C1', before: '偏好\n喜欢咖啡',
      after: '更准确的偏好\n只是改写概览', willWrite: false
    }],
    writeOperationCount: 0
  };
}

function updatePlan(memoryId: string, beforeFact: string, afterFact: string,
  personaTag: string, expectedUpdatedAt: number): MemoryCorrectionPlan {
  return {
    status: 'ready', clarificationQuestion: '',
    operations: [{
      type: 'update', evidenceIndex: 'M1', memoryId, expectedUpdatedAt,
      personaTag, beforeFact, afterFact, reason: '用户更正'
    }],
    diffs: [{
      type: 'update', target: 'M1', before: beforeFact, after: afterFact, willWrite: true
    }],
    writeOperationCount: 1
  };
}

export default function longTermMemoryOverviewCoordinatorTest(): void {
  describe('LongTermMemoryOverviewCoordinator', () => {
    it('returns empty without invoking the model', 0, async () => {
      const source = new OverviewSource();
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });

      const result = await coordinator.generateOverview();

      expect(result.status).assertEqual('empty');
      expect(result.modelCallCount).assertEqual(0);
      expect(taskPort.overviewCalls).assertEqual(0);
    });

    it('returns cached content synchronously and hydrates evidence without another model call', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢电影', 'global', 200)
      ];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });

      const first = await coordinator.generateOverview();
      const reopened = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      const immediate = reopened.cachedOverviewResult();

      expect(first.cacheHit).assertFalse();
      expect(first.modelCallCount).assertEqual(1);
      expect(immediate?.cacheHit).assertTrue();
      expect(immediate?.overview?.claims[0].body).assertEqual('喜欢咖啡');
      expect(immediate?.evidenceIndex.entries.length).assertEqual(0);
      expect(source.listCalls).assertEqual(1);

      source.snapshots.reverse();
      const hydrated = await reopened.generateOverview();
      expect(hydrated.cacheHit).assertTrue();
      expect(hydrated.modelCallCount).assertEqual(0);
      expect(hydrated.evidenceIndex.entries.length).assertEqual(2);
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(cache.saveCalls).assertEqual(1);
    });

    it('regenerates on the next open after a memory mutation clears the cache', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      cache.clear();
      source.snapshots[0].fact = '喜欢茶';
      source.snapshots[0].updatedAt += 1;
      const reopened = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      expect(reopened.cachedOverviewResult()).assertNull();
      const regenerated = await reopened.generateOverview();
      expect(regenerated.cacheHit).assertFalse();
      expect(regenerated.modelCallCount).assertEqual(1);
      expect(regenerated.overview?.claims[0].body).assertEqual('喜欢茶');
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('regenerates when the same memory ID has different content or timestamps', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const firstCoordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, cacheStore: cache
      });
      await firstCoordinator.generateOverview();
      source.snapshots[0].fact = '喜欢茶';
      source.snapshots[0].updatedAt = 101;
      const reopened = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });

      const immediate = reopened.cachedOverviewResult();
      const hydrated = await reopened.generateOverview();

      expect(immediate?.cacheHit).assertTrue();
      expect(hydrated.cacheHit).assertFalse();
      expect(hydrated.modelCallCount).assertEqual(1);
      expect(hydrated.overview?.claims[0].body).assertEqual('喜欢茶');
      expect(cache.clearCalls).assertEqual(1);
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('does not reuse a stale cache when best-effort clear fails', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new UnclearableOverviewCache();
      const firstCoordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, cacheStore: cache
      });
      await firstCoordinator.generateOverview();
      source.snapshots[0].personaTag = 'changed-tag';
      source.snapshots[0].updatedAt = 101;
      const reopened = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });

      const hydrated = await reopened.generateOverview();

      expect(hydrated.cacheHit).assertFalse();
      expect(hydrated.modelCallCount).assertEqual(1);
      expect(cache.clearCalls).assertEqual(1);
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('rejects cached overviews with forged or missing evidence', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢电影', 'global', 200)
      ];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      cache.entry = {
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 1,
        evidenceFingerprint: evidenceFingerprint(source.snapshots),
        overview: {
          title: '伪造缓存', summary: '缺少来源',
          claims: [{ heading: '偏好', body: '正文', evidenceMemoryIds: ['memory-1', 'forged'] }]
        }
      };
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      const forged = await coordinator.generateOverview();
      expect(forged.cacheHit).assertFalse();
      expect(taskPort.overviewCalls).assertEqual(1);

      cache.entry = {
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 2,
        evidenceFingerprint: evidenceFingerprint(source.snapshots),
        overview: {
          title: '不完整缓存', summary: '缺少来源',
          claims: [{ heading: '偏好', body: '正文', evidenceMemoryIds: ['memory-1'] }]
        }
      };
      const missing = await coordinator.generateOverview();
      expect(missing.cacheHit).assertFalse();
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('restores the cached base overview after a presentation-only edit', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      const edited = await coordinator.applyPlan(presentationPlan());
      expect(edited.overview?.claims[0].body).assertEqual('只是改写概览');

      const refreshed = await coordinator.generateOverview();
      expect(refreshed.cacheHit).assertTrue();
      expect(refreshed.modelCallCount).assertEqual(0);
      expect(refreshed.overview?.claims[0].body).assertEqual('喜欢咖啡');
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(cache.saveCalls).assertEqual(1);
    });

    it('continues through cache read and write failures', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, cacheStore: new ThrowingOverviewCache()
      });
      const result = await coordinator.generateOverview();
      expect(result.status).assertEqual('ready');
      expect(result.cacheHit).assertFalse();
      expect(taskPort.overviewCalls).assertEqual(1);
    });

    it('applies presentation-only changes without touching memory', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();

      const result = await coordinator.applyPlan(presentationPlan());

      expect(result.status).assertEqual('presentation_only');
      expect(result.overview?.claims[0].body).assertEqual('只是改写概览');
      expect(runtime.writeCalls).assertEqual(0);
      expect(source.getCalls).assertEqual(0);
    });

    it('rejects the whole plan when a target changed after planning', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'public_persona', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      source.snapshots[0].fact = '已经不喝咖啡';

      const result = await coordinator.applyPlan(
        updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'public_persona', 100)
      );

      expect(result.status).assertEqual('conflict');
      expect(result.message.indexOf('未写入') >= 0).assertTrue();
      expect(result.message.indexOf('重新进入页面') >= 0).assertTrue();
      expect(runtime.writeCalls).assertEqual(0);
    });

    it('does not overwrite a value that changes after preflight but before the conditional write', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      runtime.mutateBeforeConditionalWrite = true;
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();

      const result = await coordinator.applyPlan(
        updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100)
      );

      expect(source.getCalls).assertEqual(1);
      expect(result.status).assertEqual('conflict');
      expect(result.succeededWriteCount).assertEqual(0);
      expect(source.snapshots[0].fact).assertEqual('竞态写入的新值');
      expect(runtime.updateCalls).assertEqual(0);
    });

    it('returns partial and stops later writes when a subsequent conditional delete conflicts', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢旅行', 'global', 200)
      ];
      const runtime = new OverviewRuntime(source);
      runtime.mutateAtConditionalWriteCall = 2;
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const plan: MemoryCorrectionPlan = {
        status: 'ready', clarificationQuestion: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', reason: '删除'
          }
        ],
        diffs: [], writeOperationCount: 2
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(1);
      expect(result.message.indexOf('因记忆变化未写入')).assertLarger(-1);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(source.snapshots[1].fact).assertEqual('竞态写入的新值');
      expect(runtime.forgetCalls).assertEqual(0);
    });

    it('preserves the original persona tag and regenerates after a confirmed update', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'public_persona', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();

      const result = await coordinator.applyPlan(
        updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'public_persona', 100)
      );

      expect(result.status).assertEqual('success');
      expect(runtime.updatePersonaTags[0]).assertEqual('public_persona');
      expect(cache.clearCalls).assertEqual(1);
      expect(taskPort.overviewCalls).assertEqual(2);
      expect(result.modelCallCount).assertEqual(1);
      expect(result.overview?.claims[0].body).assertEqual('喜欢茶');
    });

    it('stops after a failed write, counts skipped writes and regenerates current data', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢旅行', 'global', 200),
        snapshot('memory-3', '喜欢电影', 'global', 300)
      ];
      const runtime = new OverviewRuntime(source);
      runtime.failAtWriteCall = 2;
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const plan: MemoryCorrectionPlan = {
        status: 'ready', clarificationQuestion: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', reason: '删除'
          },
          {
            type: 'delete', evidenceIndex: 'M3', memoryId: 'memory-3', expectedUpdatedAt: 300,
            personaTag: 'global', beforeFact: '喜欢电影', reason: '删除'
          }
        ],
        diffs: [], writeOperationCount: 3
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(2);
      expect(runtime.writeCalls).assertEqual(2);
      expect(source.snapshots.length).assertEqual(3);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('does not claim regeneration when overview refresh fails after a partial write', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢旅行', 'global', 200)
      ];
      const runtime = new OverviewRuntime(source);
      runtime.failAtWriteCall = 2;
      const taskPort = new FailSecondOverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const plan: MemoryCorrectionPlan = {
        status: 'ready', clarificationQuestion: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', reason: '删除'
          }
        ],
        diffs: [], writeOperationCount: 2
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(1);
      expect(result.message.indexOf('概览暂时无法更新')).assertLarger(-1);
      expect(result.message.indexOf('已按当前数据重新生成')).assertEqual(-1);
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('drops a model result after the page generation is invalidated', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new DeferredOverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      const pending = coordinator.generateOverview();
      coordinator.invalidate();
      const staleOverview: MemoryOverview = {
        title: '失效结果', summary: '不应展示',
        claims: [{ heading: '失效', body: '失效', evidenceMemoryIds: ['memory-1'] }]
      };
      const staleResult: LongTermMemoryModelOutcome<MemoryOverview> = {
        status: 'success', value: staleOverview, message: '', modelCallCount: 1
      };
      taskPort.releaseOverview(staleResult);

      const result = await pending;
      expect(result.status).assertEqual('inactive');
      expect(result.overview).assertNull();
    });
  });
}
