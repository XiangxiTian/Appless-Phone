import { describe, expect, it } from '@ohos/hypium';
import {
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryError,
  MemoryRecord,
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

function memoryRecord(value: PhoneLocalMemorySnapshot): MemoryRecord {
  return {
    memoryId: value.memoryId, ownerId: 'owner', sceneId: 'global', personaTag: value.personaTag,
    authority: value.authority, fact: value.fact, normalizedFact: value.fact, factHash: value.memoryId,
    embedding: [], embeddingProfileId: 'test', sourceTurnId: 'test',
    createdAt: value.createdAt, updatedAt: value.updatedAt
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

class DeferredFinalReadSource extends OverviewSource {
  private releaseRead: (() => void) | undefined;
  private signalStarted: (() => void) | undefined;
  readonly started: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.signalStarted = resolve;
  });
  private readonly readGate: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.releaseRead = resolve;
  });

  async listAllMemorySnapshots(): Promise<PhoneLocalMemorySnapshot[]> {
    const pending = super.listAllMemorySnapshots();
    // Initial generation, pre-write validation, then post-commit evidence read.
    if (this.listCalls === 3) {
      if (this.signalStarted !== undefined) this.signalStarted();
      await this.readGate;
    }
    return await pending;
  }

  release(): void {
    if (this.releaseRead !== undefined) this.releaseRead();
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
  dedupeRememberToMemoryId: string = '';
  onSuccessfulWrite: (() => void) | null = null;

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
    if (this.dedupeRememberToMemoryId.length > 0) {
      for (let position = 0; position < this.source.snapshots.length; position += 1) {
        if (this.source.snapshots[position].memoryId === this.dedupeRememberToMemoryId) {
          return Promise.resolve(this.successBatch(memoryRecord(this.source.snapshots[position])));
        }
      }
    }
    const timestamp = 1000 + this.writeCalls;
    const added: PhoneLocalMemorySnapshot = {
      memoryId: 'added-' + this.writeCalls.toString(), fact: facts[0], personaTag,
      authority: 'leader', createdAt: timestamp, updatedAt: timestamp
    };
    this.source.snapshots.push(added);
    return Promise.resolve(this.successBatch(memoryRecord(added)));
  }

  update(updates: PhoneLocalMemoryUpdate[], _sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.updateCalls += 1;
    this.updatePersonaTags.push(personaTag);
    this.writeCalls += 1;
    if (this.shouldFail(guard)) return Promise.resolve(this.failedBatch());
    let updated: PhoneLocalMemorySnapshot | null = null;
    for (let position = 0; position < this.source.snapshots.length; position += 1) {
      if (this.source.snapshots[position].memoryId === updates[0].memoryId) {
        this.source.snapshots[position].fact = updates[0].fact;
        this.source.snapshots[position].personaTag = personaTag;
        this.source.snapshots[position].updatedAt += 1;
        updated = this.source.snapshots[position];
      }
    }
    return Promise.resolve(updated === null ? this.failedBatch() : this.successBatch(memoryRecord(updated)));
  }

  forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.forgetCalls += 1;
    this.writeCalls += 1;
    if (this.shouldFail(guard)) return Promise.resolve(this.failedBatch());
    let deleted: PhoneLocalMemorySnapshot | null = null;
    for (let position = 0; position < this.source.snapshots.length; position += 1) {
      if (this.source.snapshots[position].memoryId === memoryIds[0]) deleted = this.source.snapshots[position];
    }
    this.source.snapshots = this.source.snapshots.filter(
      (snapshot: PhoneLocalMemorySnapshot): boolean => snapshot.memoryId !== memoryIds[0]
    );
    return Promise.resolve(deleted === null ? this.failedBatch() : this.successBatch(memoryRecord(deleted)));
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

  private successBatch(record: MemoryRecord): MemoryBatchResult {
    const records: MemoryWriteResult[] = [{ inputIndex: 0, status: 'success', record }];
    const callback = this.onSuccessfulWrite;
    this.onSuccessfulWrite = null;
    if (callback !== null) callback();
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
      category: 'interests', heading: '偏好', body: index.entries[0].fact, evidenceMemoryIds
    }];
    const overview: MemoryOverview = {
      title: '你的长期记忆',
      summary: '共 ' + index.entries.length.toString() + ' 条',
      mbtiType: 'INFP', mbtiConfidence: 64,
      tagList: ['咖啡爱好者'],
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
  private signalStarted: (() => void) | undefined;
  readonly started: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.signalStarted = resolve;
  });

  generateOverview(_index: MemoryOverviewEvidenceIndex,
    _isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>> {
    return new Promise<LongTermMemoryModelOutcome<MemoryOverview>>(
      (resolve: (value: LongTermMemoryModelOutcome<MemoryOverview>) => void): void => {
        this.resolveOverview = resolve;
        if (this.signalStarted !== undefined) this.signalStarted();
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

class DeferredCorrectionTaskPort extends OverviewTaskPort {
  private resolvePlan: ((value: LongTermMemoryModelOutcome<MemoryCorrectionPlan>) => void) | undefined;
  private signalStarted: (() => void) | undefined;
  readonly started: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.signalStarted = resolve;
  });

  planCorrection(_feedback: string, _overview: MemoryOverview,
    _index: MemoryOverviewEvidenceIndex,
    _isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>> {
    this.planCalls += 1;
    return new Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>>(
      (resolve: (value: LongTermMemoryModelOutcome<MemoryCorrectionPlan>) => void): void => {
        this.resolvePlan = resolve;
        if (this.signalStarted !== undefined) this.signalStarted();
      }
    );
  }

  releasePlan(plan: MemoryCorrectionPlan): void {
    if (this.resolvePlan !== undefined) {
      this.resolvePlan({ status: 'success', value: plan, message: '', modelCallCount: 1 });
    }
  }
}

class QueuedOverviewRuntime extends OverviewRuntime {
  private releaseWrite: (() => void) | undefined;
  private signalStarted: (() => void) | undefined;
  readonly started: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.signalStarted = resolve;
  });
  private readonly writeGate: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.releaseWrite = resolve;
  });

  async updateIfSnapshotCurrent(update: PhoneLocalMemoryUpdate, sourceTurnId: string, personaTag: string,
    expected: PhoneLocalMemorySnapshot, guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    if (this.signalStarted !== undefined) this.signalStarted();
    await this.writeGate;
    return await super.updateIfSnapshotCurrent(update, sourceTurnId, personaTag, expected, guard);
  }

  release(): void {
    if (this.releaseWrite !== undefined) this.releaseWrite();
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
    status: 'ready', message: '', operations: [],
    claimPatches: [{
      type: 'replace', claimIndex: 1,
      replacementCategory: 'interests', replacementHeading: '更准确的偏好', replacementBody: '只是改写概览', reason: '用户要求换种说法'
    }],
    writeOperationCount: 0,
    baseEvidenceFingerprint: evidenceFingerprint([snapshot('memory-1', '喜欢咖啡')]),
    replacementMbtiType: '', replacementMbtiConfidence: 0,
    replacementTagList: [], replacementSummary: '共 1 条'
  };
}

function updatePlan(memoryId: string, beforeFact: string, afterFact: string,
  personaTag: string, expectedUpdatedAt: number): MemoryCorrectionPlan {
  return {
    status: 'ready', message: '',
    operations: [{
      type: 'update', evidenceIndex: 'M1', memoryId, expectedUpdatedAt,
      personaTag, beforeFact, afterFact, reason: '用户更正'
    }],
    claimPatches: [{
      type: 'replace', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '偏好', replacementBody: afterFact,
      reason: '同步概览'
    }],
    writeOperationCount: 1,
    baseEvidenceFingerprint: evidenceFingerprint([
      snapshot(memoryId, beforeFact, personaTag, expectedUpdatedAt)
    ]),
    replacementMbtiType: '', replacementMbtiConfidence: 0,
    replacementTagList: [], replacementSummary: '共 1 条'
  };
}

function deleteOnlyPlan(memoryId: string, fact: string, updatedAt: number): MemoryCorrectionPlan {
  return {
    status: 'ready', message: '', operations: [{
      type: 'delete', evidenceIndex: 'M1', memoryId, expectedUpdatedAt: updatedAt,
      personaTag: 'global', beforeFact: fact, explicitDeleteEvidence: '删除', reason: '用户明确删除'
    }],
    claimPatches: [{
      type: 'delete', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '', replacementBody: '', reason: '删除空章节'
    }],
    writeOperationCount: 1,
    baseEvidenceFingerprint: evidenceFingerprint([snapshot(memoryId, fact, 'global', updatedAt)]),
    replacementMbtiType: '', replacementMbtiConfidence: 0,
    replacementTagList: [], replacementSummary: '暂无长期记忆'
  };
}

function addPlan(base: PhoneLocalMemorySnapshot, targetClaimIndex: number,
  patchType: 'replace' | 'append'): MemoryCorrectionPlan {
  return {
    status: 'ready', message: '', operations: [{
      type: 'add', localRef: 'A1', targetClaimIndex, afterFact: '开始学习陶艺',
      personaTag: 'global', reason: '用户补充'
    }],
    claimPatches: [{
      type: patchType, claimIndex: targetClaimIndex,
      replacementCategory: 'interests', replacementHeading: patchType === 'append' ? '新兴趣' : '偏好',
      replacementBody: '开始学习陶艺', reason: '同步概览'
    }],
    writeOperationCount: 1, baseEvidenceFingerprint: evidenceFingerprint([base]),
    replacementMbtiType: '', replacementMbtiConfidence: 0,
    replacementTagList: [], replacementSummary: '共 2 条'
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
          mbtiType: '', mbtiConfidence: 0,
          tagList: [], claims: [{ category: 'interests', heading: '偏好', body: '正文', evidenceMemoryIds: ['memory-1', 'forged'] }]
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
          mbtiType: '', mbtiConfidence: 0,
          tagList: [], claims: [{ category: 'interests', heading: '偏好', body: '正文', evidenceMemoryIds: ['memory-1'] }]
        }
      };
      const missing = await coordinator.generateOverview();
      expect(missing.cacheHit).assertFalse();
      expect(taskPort.overviewCalls).assertEqual(2);
    });

    it('persists a presentation-only edit in the overview cache', 0, async () => {
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
      expect(refreshed.overview?.claims[0].body).assertEqual('只是改写概览');
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(cache.saveCalls).assertEqual(2);
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

      const plan = presentationPlan();
      plan.claimPatches[0].replacementCategory = 'recent';
      plan.replacementTagList = ['近期关注'];
      plan.replacementMbtiType = 'ENFP';
      plan.replacementMbtiConfidence = 55;
      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('presentation_only');
      expect(result.overview?.claims[0].body).assertEqual('只是改写概览');
      expect(result.overview?.claims[0].category).assertEqual('recent');
      expect(result.overview?.tagList[0]).assertEqual('近期关注');
      expect(cache.entry?.overview.tagList[0]).assertEqual('近期关注');
      expect(result.overview?.mbtiType).assertEqual('ENFP');
      expect(result.overview?.mbtiConfidence).assertEqual(55);
      expect(cache.entry?.overview.mbtiType).assertEqual('ENFP');
      expect(cache.entry?.overview.mbtiConfidence).assertEqual(55);
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(result.modelCallCount).assertEqual(0);
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
      expect(result.message.indexOf('未执行') >= 0).assertTrue();
      expect(result.message.indexOf('重新进入') >= 0).assertTrue();
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

      expect(source.getCalls).assertEqual(0);
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
        status: 'ready', message: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', explicitDeleteEvidence: '删除', reason: '删除'
          }
        ],
        claimPatches: [{
          type: 'replace', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '偏好', replacementBody: '喜欢茶',
          reason: '同步概览'
        }],
        writeOperationCount: 2, baseEvidenceFingerprint: evidenceFingerprint(source.snapshots),
        replacementMbtiType: '', replacementMbtiConfidence: 0,
        replacementTagList: [], replacementSummary: '共 1 条'
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(1);
      expect(result.message.indexOf('下次进入')).assertLarger(-1);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(source.snapshots[1].fact).assertEqual('竞态写入的新值');
      expect(runtime.forgetCalls).assertEqual(0);
    });

    it('preserves the persona tag and patches the overview without another model call', 0, async () => {
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
      expect(cache.clearCalls).assertEqual(0);
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(result.modelCallCount).assertEqual(0);
      expect(result.overview?.claims[0].body).assertEqual('喜欢茶');
    });

    it('stops after a failed write, counts skipped writes and invalidates coordinator evidence', 0, async () => {
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
        status: 'ready', message: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', explicitDeleteEvidence: '删除', reason: '删除'
          },
          {
            type: 'delete', evidenceIndex: 'M3', memoryId: 'memory-3', expectedUpdatedAt: 300,
            personaTag: 'global', beforeFact: '喜欢电影', explicitDeleteEvidence: '删除', reason: '删除'
          }
        ],
        claimPatches: [{
          type: 'replace', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '偏好', replacementBody: '喜欢茶',
          reason: '同步概览'
        }],
        writeOperationCount: 3, baseEvidenceFingerprint: evidenceFingerprint(source.snapshots),
        replacementMbtiType: '', replacementMbtiConfidence: 0,
        replacementTagList: [], replacementSummary: '共 1 条'
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(2);
      expect(runtime.writeCalls).assertEqual(2);
      expect(source.snapshots.length).assertEqual(3);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(result.overview).assertNull();
    });

    it('does not call the overview model after a partial write', 0, async () => {
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
        status: 'ready', message: '',
        operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'delete', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', explicitDeleteEvidence: '删除', reason: '删除'
          }
        ],
        claimPatches: [{
          type: 'replace', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '偏好', replacementBody: '喜欢茶',
          reason: '同步概览'
        }],
        writeOperationCount: 2, baseEvidenceFingerprint: evidenceFingerprint(source.snapshots),
        replacementMbtiType: '', replacementMbtiConfidence: 0,
        replacementTagList: [], replacementSummary: '共 1 条'
      };

      const result = await coordinator.applyPlan(plan);

      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(1);
      expect(result.message.indexOf('下次进入')).assertLarger(-1);
      expect(result.message.indexOf('已按当前数据重新生成')).assertEqual(-1);
      expect(taskPort.overviewCalls).assertEqual(1);
    });

    it('deletes the final memory as an empty success without regenerating', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      const result = await coordinator.applyPlan(deleteOnlyPlan('memory-1', '喜欢咖啡', 100));
      expect(result.status).assertEqual('success');
      expect(result.overview).assertNull();
      expect(source.snapshots.length).assertEqual(0);
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(cache.entry).assertNull();
    });

    it('appends a new claim and maps the runtime returned add ID', 0, async () => {
      const source = new OverviewSource();
      const base = snapshot('memory-1', '喜欢咖啡', 'global', 100);
      source.snapshots = [base];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const result = await coordinator.applyPlan(addPlan(base, 2, 'append'));
      expect(result.status).assertEqual('success');
      expect(result.overview?.claims.length).assertEqual(2);
      expect(result.overview?.claims[1].evidenceMemoryIds[0]).assertEqual('added-1');
      expect(taskPort.overviewCalls).assertEqual(1);
    });

    it('does not duplicate evidence when remember deduplicates to an existing record', 0, async () => {
      const source = new OverviewSource();
      const base = snapshot('memory-1', '开始学习陶艺', 'global', 100);
      source.snapshots = [base];
      const runtime = new OverviewRuntime(source);
      runtime.dedupeRememberToMemoryId = 'memory-1';
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const result = await coordinator.applyPlan(addPlan(base, 1, 'replace'));
      expect(result.status).assertEqual('success');
      expect(result.overview?.claims[0].evidenceMemoryIds.length).assertEqual(1);
      expect(result.overview?.claims[0].evidenceMemoryIds[0]).assertEqual('memory-1');
    });

    it('invalidates the patched overview when an unrelated memory changes during writes', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢旅行', 'global', 200)
      ];
      const runtime = new OverviewRuntime(source);
      runtime.onSuccessfulWrite = (): void => {
        source.snapshots[1].fact = '喜欢徒步旅行';
        source.snapshots[1].updatedAt += 1;
      };
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      const plan: MemoryCorrectionPlan = updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100);
      plan.baseEvidenceFingerprint = evidenceFingerprint(source.snapshots);
      const result = await coordinator.applyPlan(plan);
      expect(result.status).assertEqual('partial');
      expect(result.overview).assertNull();
      expect(result.evidenceIndex.entries.length).assertEqual(0);
      expect(cache.entry).assertNull();
      expect(taskPort.overviewCalls).assertEqual(1);
    });

    it('direct correction reports its single planning model call and applies immediately', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡', 'global', 100)];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      taskPort.nextPlan = updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100);
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const result = await coordinator.correct('我现在喜欢茶');
      expect(result.status).assertEqual('success');
      expect(result.modelCallCount).assertEqual(1);
      expect(taskPort.planCalls).assertEqual(1);
      expect(taskPort.overviewCalls).assertEqual(1);
      expect(result.overview?.claims[0].body).assertEqual('喜欢茶');
    });

    it('reports committed writes as partial when the page closes after the first commit', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [
        snapshot('memory-1', '喜欢咖啡', 'global', 100),
        snapshot('memory-2', '喜欢旅行', 'global', 200)
      ];
      let active = true;
      const runtime = new OverviewRuntime(source);
      runtime.onSuccessfulWrite = (): void => { active = false; };
      const taskPort = new OverviewTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, isActive: (): boolean => active
      });
      await coordinator.generateOverview();
      const plan: MemoryCorrectionPlan = {
        status: 'ready', message: '', operations: [
          {
            type: 'update', evidenceIndex: 'M1', memoryId: 'memory-1', expectedUpdatedAt: 100,
            personaTag: 'global', beforeFact: '喜欢咖啡', afterFact: '喜欢茶', reason: '更正'
          },
          {
            type: 'update', evidenceIndex: 'M2', memoryId: 'memory-2', expectedUpdatedAt: 200,
            personaTag: 'global', beforeFact: '喜欢旅行', afterFact: '喜欢徒步', reason: '更正'
          }
        ],
        claimPatches: [{
          type: 'replace', claimIndex: 1, replacementCategory: 'interests', replacementHeading: '偏好',
          replacementBody: '喜欢茶和徒步', reason: '同步概览'
        }],
        writeOperationCount: 2, baseEvidenceFingerprint: evidenceFingerprint(source.snapshots),
        replacementMbtiType: '', replacementMbtiConfidence: 0,
        replacementTagList: [], replacementSummary: '共 2 条'
      };
      const result = await coordinator.applyPlan(plan);
      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(1);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(source.snapshots[1].fact).assertEqual('喜欢旅行');
    });

    it('drops a pending model result without caching even after the page reappears', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new DeferredOverviewTaskPort();
      const cache = new OverviewCache();
      let pageAlive = true;
      const coordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, cacheStore: cache, isActive: (): boolean => pageAlive
      });
      const pending = coordinator.generateOverview();
      await taskPort.started;
      pageAlive = false;
      coordinator.invalidate();
      pageAlive = true;
      const staleOverview: MemoryOverview = {
        title: '失效结果', summary: '不应展示',
        mbtiType: '', mbtiConfidence: 0,
        tagList: [], claims: [{ category: 'interests', heading: '失效', body: '失效', evidenceMemoryIds: ['memory-1'] }]
      };
      const staleResult: LongTermMemoryModelOutcome<MemoryOverview> = {
        status: 'success', value: staleOverview, message: '', modelCallCount: 1
      };
      taskPort.releaseOverview(staleResult);

      const result = await pending;
      expect(result.status).assertEqual('inactive');
      expect(result.overview).assertNull();
      expect(cache.saveCalls).assertEqual(0);
      expect(runtime.writeCalls).assertEqual(0);
    });

    it('drops a pending correction plan after destruction and reopening without any write', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new DeferredCorrectionTaskPort();
      const cache = new OverviewCache();
      let pageAlive = true;
      const coordinator = new LongTermMemoryOverviewCoordinator({
        source, runtime, taskPort, cacheStore: cache, isActive: (): boolean => pageAlive
      });
      await coordinator.generateOverview();
      const initialSaves = cache.saveCalls;
      const pending = coordinator.correct('我现在喜欢茶');
      await taskPort.started;
      pageAlive = false;
      coordinator.invalidate();
      pageAlive = true;
      taskPort.releasePlan(updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100));

      const result = await pending;
      expect(result.status).assertEqual('inactive');
      expect(runtime.writeCalls).assertEqual(0);
      expect(source.snapshots[0].fact).assertEqual('喜欢咖啡');
      expect(cache.saveCalls).assertEqual(initialSaves);
    });

    it('rejects a correction waiting at the write boundary after destruction without changing cache', 0,
      async () => {
        const source = new OverviewSource();
        source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
        const runtime = new QueuedOverviewRuntime(source);
        const taskPort = new OverviewTaskPort();
        const cache = new OverviewCache();
        const coordinator = new LongTermMemoryOverviewCoordinator({
          source, runtime, taskPort, cacheStore: cache
        });
        await coordinator.generateOverview();
        const initialSaves = cache.saveCalls;
        const pending = coordinator.applyPlan(updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100));
        await runtime.started;
        coordinator.invalidate();
        runtime.release();

        const result = await pending;
        expect(result.status).assertEqual('inactive');
        expect(result.succeededWriteCount).assertEqual(0);
        expect(source.snapshots[0].fact).assertEqual('喜欢咖啡');
        expect(cache.saveCalls).assertEqual(initialSaves);
        expect(cache.clearCalls).assertEqual(0);
    });

    it('keeps the correction generation across the handoff from planning to applying', 0, async () => {
      const source = new OverviewSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new DeferredCorrectionTaskPort();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort });
      await coordinator.generateOverview();
      const pending = coordinator.correct('我现在喜欢茶');
      await taskPort.started;
      taskPort.releasePlan(updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100));
      // Let planCorrection finish; retire this operation before correct resumes to apply it.
      await Promise.resolve();
      coordinator.invalidate();
      const result = await pending;
      expect(result.status).assertEqual('inactive');
      expect(runtime.writeCalls).assertEqual(0);
      expect(source.snapshots[0].fact).assertEqual('喜欢咖啡');
    });

    it('preserves a reopened page cache when a retired committed task completes its final read', 0, async () => {
      const source = new DeferredFinalReadSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      const pending = coordinator.applyPlan(updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100));
      await source.started;
      coordinator.invalidate();
      const reopened = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await reopened.generateOverview();
      const latestFingerprint = cache.entry?.evidenceFingerprint;
      const clearsBeforeRetiredCompletion = cache.clearCalls;
      source.release();

      const result = await pending;
      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(0);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(cache.entry?.evidenceFingerprint).assertEqual(latestFingerprint);
      expect(cache.entry?.overview.claims[0].body).assertEqual('喜欢茶');
      expect(cache.clearCalls).assertEqual(clearsBeforeRetiredCompletion);
    });

    it('clears its old evidence cache after a committed task is retired', 0, async () => {
      const source = new DeferredFinalReadSource();
      source.snapshots = [snapshot('memory-1', '喜欢咖啡')];
      const runtime = new OverviewRuntime(source);
      const taskPort = new OverviewTaskPort();
      const cache = new OverviewCache();
      const coordinator = new LongTermMemoryOverviewCoordinator({ source, runtime, taskPort, cacheStore: cache });
      await coordinator.generateOverview();
      const pending = coordinator.applyPlan(updatePlan('memory-1', '喜欢咖啡', '喜欢茶', 'global', 100));
      await source.started;
      coordinator.invalidate();
      source.release();

      const result = await pending;
      expect(result.status).assertEqual('partial');
      expect(result.succeededWriteCount).assertEqual(1);
      expect(result.failedWriteCount).assertEqual(0);
      expect(source.snapshots[0].fact).assertEqual('喜欢茶');
      expect(cache.entry).assertNull();
      expect(cache.clearCalls).assertEqual(1);
    });
  });
}
