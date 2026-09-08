import {
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryError,
  MemoryRecord
} from '@loop/agent-core';
import {
  MemoryCorrectionOperation,
  MemoryCorrectionPlan,
  MemoryCorrectionClaimPatch,
  MemoryCorrectionUpdateOperation,
  MemoryCorrectionDeleteOperation,
  MemoryCorrectionAddOperation,
  MemoryOverview,
  MemoryOverviewClaim,
  MemoryOverviewEvidenceIndex,
  MEMORY_CORRECTION_SYSTEM_PROMPT,
  MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
  MEMORY_OVERVIEW_PROMPT_VERSION,
  MEMORY_OVERVIEW_SYSTEM_PROMPT,
  buildMemoryOverviewEvidenceIndex,
  memoryOverviewEvidenceFingerprint,
  memoryCorrectionPrompt,
  memoryOverviewPrompt,
  isMemoryOverviewCategory,
  normalizeMemoryOverviewTags,
  parseMemoryCorrectionPlanModelOutput,
  parseMemoryOverviewModelOutput
} from './MemoryOverview';
import {
  MemoryModelSchemaValidator,
  MemoryModelTaskRunner
} from './MemoryModelTaskRunner';
import {
  MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
  MemoryOverviewCacheEntry,
  MemoryOverviewCacheStorePort
} from './MemoryOverviewCacheStore';
import { PHONE_LOCAL_MEMORY_WRITE_CONFLICT_CODE } from './PhoneLocalMemoryProvider';
import {
  PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
  PhoneLocalMemoryOverviewSourcePort,
  PhoneLocalMemoryRuntimePort,
  PhoneLocalMemorySnapshot
} from './PhoneLocalMemoryRuntime';

export type LongTermMemoryOverviewGenerationStatus = 'ready' | 'empty' | 'error' | 'inactive';
export type LongTermMemoryCorrectionPlanStatus = 'ready' | 'no_change' | 'error' | 'inactive';
export type LongTermMemoryCorrectionApplyStatus =
  'success' | 'no_change' | 'presentation_only' | 'conflict' | 'partial' | 'error' | 'inactive';

export interface LongTermMemoryOverviewGenerationResult {
  status: LongTermMemoryOverviewGenerationStatus;
  overview: MemoryOverview | null;
  evidenceIndex: MemoryOverviewEvidenceIndex;
  message: string;
  modelCallCount: number;
  cacheHit: boolean;
}

export interface LongTermMemoryCorrectionPlanResult {
  status: LongTermMemoryCorrectionPlanStatus;
  plan: MemoryCorrectionPlan | null;
  message: string;
  modelCallCount: number;
}

export interface LongTermMemoryCorrectionApplyResult {
  status: LongTermMemoryCorrectionApplyStatus;
  overview: MemoryOverview | null;
  evidenceIndex: MemoryOverviewEvidenceIndex;
  message: string;
  succeededWriteCount: number;
  failedWriteCount: number;
  modelCallCount: number;
}

export interface LongTermMemoryModelOutcome<T> {
  status: 'success' | 'error' | 'inactive';
  value: T | null;
  message: string;
  modelCallCount: number;
}

/** Injectable boundary used by coordinator tests. Production uses MemoryModelTaskRunner. */
export interface LongTermMemoryOverviewTaskPort {
  generateOverview(index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>>;
  planCorrection(userFeedback: string, overview: MemoryOverview,
    index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>>;
}

export interface LongTermMemoryOverviewCoordinatorOptions {
  source: PhoneLocalMemoryOverviewSourcePort;
  runtime: PhoneLocalMemoryRuntimePort;
  runner?: MemoryModelTaskRunner;
  taskPort?: LongTermMemoryOverviewTaskPort;
  cacheStore?: MemoryOverviewCacheStorePort;
  isActive?: () => boolean;
  now?: () => number;
}

class OverviewModelValidator implements MemoryModelSchemaValidator<MemoryOverview> {
  private readonly index: MemoryOverviewEvidenceIndex;

  constructor(index: MemoryOverviewEvidenceIndex) {
    this.index = index;
  }

  validate(raw: string): MemoryOverview | null {
    return parseMemoryOverviewModelOutput(raw, this.index);
  }
}

class CorrectionPlanModelValidator implements MemoryModelSchemaValidator<MemoryCorrectionPlan> {
  private readonly index: MemoryOverviewEvidenceIndex;
  private readonly overview: MemoryOverview;
  private readonly userFeedback: string;

  constructor(index: MemoryOverviewEvidenceIndex, overview: MemoryOverview, userFeedback: string) {
    this.index = index;
    this.overview = overview;
    this.userFeedback = userFeedback;
  }

  validate(raw: string): MemoryCorrectionPlan | null {
    return parseMemoryCorrectionPlanModelOutput(raw, this.index, this.overview, this.userFeedback);
  }
}

class MemoryModelTaskRunnerOverviewPort implements LongTermMemoryOverviewTaskPort {
  private readonly runner: MemoryModelTaskRunner;

  constructor(runner: MemoryModelTaskRunner) {
    this.runner = runner;
  }

  async generateOverview(index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryOverview>> {
    const result = await this.runner.run<MemoryOverview>({
      taskType: 'memory_overview',
      prompt: memoryOverviewPrompt(index),
      systemPrompt: MEMORY_OVERVIEW_SYSTEM_PROMPT,
      validator: new OverviewModelValidator(index),
      isActive
    });
    return {
      status: result.status,
      value: result.value,
      message: result.error === null ? '' : result.error.message,
      modelCallCount: result.modelCallCount
    };
  }

  async planCorrection(userFeedback: string, overview: MemoryOverview,
    index: MemoryOverviewEvidenceIndex,
    isActive: () => boolean): Promise<LongTermMemoryModelOutcome<MemoryCorrectionPlan>> {
    const result = await this.runner.run<MemoryCorrectionPlan>({
      taskType: 'memory_correction_plan',
      prompt: memoryCorrectionPrompt(userFeedback, overview, index),
      systemPrompt: MEMORY_CORRECTION_SYSTEM_PROMPT,
      validator: new CorrectionPlanModelValidator(index, overview, userFeedback),
      isActive
    });
    return {
      status: result.status,
      value: result.value,
      message: result.error === null ? '' : result.error.message,
      modelCallCount: result.modelCallCount
    };
  }
}

class OverviewMemoryCommitGuard implements MemoryCommitGuard {
  private readonly active: () => boolean;

  constructor(active: () => boolean) {
    this.active = active;
  }

  isActive(): boolean {
    return this.active();
  }
}

function emptyEvidenceIndex(): MemoryOverviewEvidenceIndex {
  return { entries: [] };
}

function successfulSingleWrite(result: MemoryBatchResult): boolean {
  return result.status === 'success' && result.succeededCount === 1 && result.failedCount === 0;
}

function memoryBatchHasWriteConflict(result: MemoryBatchResult): boolean {
  if (result.error?.code === PHONE_LOCAL_MEMORY_WRITE_CONFLICT_CODE) return true;
  for (let position = 0; position < result.records.length; position += 1) {
    if (result.records[position].error?.code === PHONE_LOCAL_MEMORY_WRITE_CONFLICT_CODE) return true;
  }
  return false;
}

interface AddedMemoryReference {
  localRef: string;
  memoryId: string;
}

interface CommittedMemoryRecord {
  operationIndex: number;
  record: MemoryRecord;
}

function claimPatchForIndex(patches: MemoryCorrectionClaimPatch[], claimIndex: number):
  MemoryCorrectionClaimPatch | null {
  for (let position = 0; position < patches.length; position += 1) {
    if (patches[position].claimIndex === claimIndex) return patches[position];
  }
  return null;
}

function addedMemoryId(references: AddedMemoryReference[], localRef: string): string | null {
  for (let position = 0; position < references.length; position += 1) {
    if (references[position].localRef === localRef) return references[position].memoryId;
  }
  return null;
}

function copyOverviewWithCorrectionPlan(overview: MemoryOverview, plan: MemoryCorrectionPlan,
  addedReferences: AddedMemoryReference[]): MemoryOverview | null {
  const claims: MemoryOverviewClaim[] = overview.claims.map(
    (claim: MemoryOverviewClaim): MemoryOverviewClaim => ({
    category: claim.category,
    heading: claim.heading,
    body: claim.body,
    evidenceMemoryIds: claim.evidenceMemoryIds.slice()
    })
  );
  for (let operationPosition = 0; operationPosition < plan.operations.length; operationPosition += 1) {
    const operation = plan.operations[operationPosition];
    if (operation.type === 'delete') {
      for (let claimPosition = 0; claimPosition < claims.length; claimPosition += 1) {
        claims[claimPosition].evidenceMemoryIds = claims[claimPosition].evidenceMemoryIds.filter(
          (memoryId: string): boolean => memoryId !== operation.memoryId
        );
      }
      continue;
    }
    if (operation.type === 'add') {
      const memoryId = addedMemoryId(addedReferences, operation.localRef);
      const targetPosition = operation.targetClaimIndex - 1;
      if (memoryId === null || targetPosition < 0 || targetPosition > claims.length) return null;
      if (targetPosition < claims.length && claims[targetPosition].evidenceMemoryIds.indexOf(memoryId) < 0) {
        claims[targetPosition].evidenceMemoryIds.push(memoryId);
      }
    }
  }
  const patchedClaims: MemoryOverviewClaim[] = [];
  for (let claimPosition = 0; claimPosition < claims.length; claimPosition += 1) {
    const patch = claimPatchForIndex(plan.claimPatches, claimPosition + 1);
    if (patch !== null && patch.type === 'delete') continue;
    if (patch !== null) {
      claims[claimPosition].category = patch.replacementCategory;
      claims[claimPosition].heading = patch.replacementHeading;
      claims[claimPosition].body = patch.replacementBody;
    }
    if (claims[claimPosition].evidenceMemoryIds.length < 1) return null;
    patchedClaims.push(claims[claimPosition]);
  }
  const appendPatch = claimPatchForIndex(plan.claimPatches, claims.length + 1);
  if (appendPatch !== null) {
    if (appendPatch.type !== 'append') return null;
    const appendEvidenceIds: string[] = [];
    for (let position = 0; position < plan.operations.length; position += 1) {
      const operation = plan.operations[position];
      if (operation.type !== 'add' || operation.targetClaimIndex !== claims.length + 1) continue;
      const memoryId = addedMemoryId(addedReferences, operation.localRef);
      if (memoryId === null) return null;
      if (appendEvidenceIds.indexOf(memoryId) < 0) appendEvidenceIds.push(memoryId);
    }
    if (appendEvidenceIds.length < 1) return null;
    patchedClaims.push({
      category: appendPatch.replacementCategory,
      heading: appendPatch.replacementHeading,
      body: appendPatch.replacementBody,
      evidenceMemoryIds: appendEvidenceIds
    });
  }
  if (patchedClaims.length < 1) return null;
  return {
    title: overview.title, summary: plan.replacementSummary,
    mbtiType: plan.replacementMbtiType, mbtiConfidence: plan.replacementMbtiConfidence,
    tagList: plan.replacementTagList.slice(), claims: patchedClaims
  };
}

/**
 * Coordinates overview generation and confirmed corrections without entering the Leader flow.
 * It stores only the current parsed state; prompts and raw model output are never logged here.
 */
export class LongTermMemoryOverviewCoordinator {
  private readonly source: PhoneLocalMemoryOverviewSourcePort;
  private readonly runtime: PhoneLocalMemoryRuntimePort;
  private readonly taskPort: LongTermMemoryOverviewTaskPort;
  private readonly hostIsActive: () => boolean;
  private readonly now: () => number;
  private readonly cacheStore: MemoryOverviewCacheStorePort | null;
  private generation: number = 0;
  private writeSequence: number = 0;
  private applyingCorrection: boolean = false;
  private currentOverview: MemoryOverview | null = null;
  private currentEvidenceIndex: MemoryOverviewEvidenceIndex = emptyEvidenceIndex();

  constructor(options: LongTermMemoryOverviewCoordinatorOptions) {
    this.source = options.source;
    this.runtime = options.runtime;
    if (options.taskPort !== undefined) {
      this.taskPort = options.taskPort;
    } else if (options.runner !== undefined) {
      this.taskPort = new MemoryModelTaskRunnerOverviewPort(options.runner);
    } else {
      throw new Error('Long-term memory overview requires a memory model task port.');
    }
    this.hostIsActive = options.isActive ?? (() => true);
    this.now = options.now ?? (() => Date.now());
    this.cacheStore = options.cacheStore ?? null;
  }

  invalidate(): void {
    this.generation += 1;
  }

  isApplyingCorrection(): boolean {
    return this.applyingCorrection;
  }

  async generateOverview(): Promise<LongTermMemoryOverviewGenerationResult> {
    const generation = this.generation;
    return await this.generateOverviewForGeneration(generation);
  }

  /** Synchronous fast path so the page can paint a persisted overview before evidence hydration. */
  cachedOverviewResult(): LongTermMemoryOverviewGenerationResult | null {
    const cached = this.loadCache();
    if (cached === null) return null;
    this.currentOverview = cached.overview;
    this.currentEvidenceIndex = emptyEvidenceIndex();
    return {
      status: 'ready', overview: cached.overview, evidenceIndex: this.currentEvidenceIndex,
      message: '', modelCallCount: 0, cacheHit: true
    };
  }

  async planCorrection(userFeedback: string): Promise<LongTermMemoryCorrectionPlanResult> {
    const generation = this.generation;
    if (!this.active(generation)) return this.inactivePlanResult();
    if (this.currentOverview === null || this.currentEvidenceIndex.entries.length === 0) {
      return {
        status: 'error', plan: null, message: '请先生成长期记忆概览。', modelCallCount: 0
      };
    }
    const feedback = userFeedback.trim();
    if (feedback.length === 0) {
      return { status: 'error', plan: null, message: '请输入需要修正的内容。', modelCallCount: 0 };
    }
    const outcome = await this.taskPort.planCorrection(
      feedback, this.currentOverview, this.currentEvidenceIndex,
      (): boolean => this.active(generation)
    );
    if (!this.active(generation) || outcome.status === 'inactive') return this.inactivePlanResult();
    if (outcome.status !== 'success' || outcome.value === null) {
      return {
        status: 'error', plan: null,
        message: outcome.message.length > 0 ? outcome.message : '修正方案生成失败，请重试。',
        modelCallCount: outcome.modelCallCount
      };
    }
    if (outcome.value.status === 'no_change') {
      return {
        status: 'no_change', plan: outcome.value,
        message: outcome.value.message, modelCallCount: outcome.modelCallCount
      };
    }
    return {
      status: 'ready', plan: outcome.value, message: '',
      modelCallCount: outcome.modelCallCount
    };
  }

  async correct(userFeedback: string): Promise<LongTermMemoryCorrectionApplyResult> {
    const generation = this.generation;
    const planned = await this.planCorrection(userFeedback);
    if (!this.active(generation) || planned.status === 'inactive') return this.inactiveApplyResult();
    if (planned.status === 'error' || planned.plan === null) {
      const failed = this.applyError(planned.message);
      failed.modelCallCount = planned.modelCallCount;
      return failed;
    }
    if (planned.status === 'no_change') {
      return {
        status: 'no_change', overview: this.currentOverview, evidenceIndex: this.currentEvidenceIndex,
        message: planned.message, succeededWriteCount: 0, failedWriteCount: 0,
        modelCallCount: planned.modelCallCount
      };
    }
    this.applyingCorrection = true;
    try {
      const applied = await this.applyPlan(planned.plan);
      applied.modelCallCount += planned.modelCallCount;
      return applied;
    } finally {
      this.applyingCorrection = false;
    }
  }

  async applyPlan(plan: MemoryCorrectionPlan): Promise<LongTermMemoryCorrectionApplyResult> {
    const generation = this.generation;
    if (!this.active(generation)) return this.inactiveApplyResult();
    if (plan.status === 'no_change') {
      return {
        status: 'no_change', overview: this.currentOverview, evidenceIndex: this.currentEvidenceIndex,
        message: plan.message, succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
      };
    }
    if (plan.status !== 'ready' || plan.claimPatches.length === 0 || this.currentOverview === null) {
      return this.applyError('没有可执行的修正。');
    }
    const actualWriteOperationCount = this.writeOperationCount(plan.operations);
    if (plan.writeOperationCount !== actualWriteOperationCount ||
      actualWriteOperationCount < 0 || actualWriteOperationCount > 5) {
      return this.applyError('一次最多执行五项长期记忆写入。');
    }
    const freshIndex = await this.readEvidenceIndex(generation);
    if (!this.active(generation)) return this.inactiveApplyResult();
    if (freshIndex === null || memoryOverviewEvidenceFingerprint(freshIndex) !== plan.baseEvidenceFingerprint) {
      this.clearCacheBestEffort();
      return {
        status: 'conflict', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆已发生变化，本次修改未执行。请重新进入页面后再修改。',
        succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
      };
    }
    const symbolicReferences: AddedMemoryReference[] = [];
    const projectedMemoryIds: Set<string> = new Set<string>();
    for (let position = 0; position < freshIndex.entries.length; position += 1) {
      projectedMemoryIds.add(freshIndex.entries[position].memoryId);
    }
    for (let position = 0; position < plan.operations.length; position += 1) {
      const operation = plan.operations[position];
      if (operation.type === 'delete') projectedMemoryIds.delete(operation.memoryId);
      if (operation.type === 'add') {
        const symbolicId = '__memory_correction_' + operation.localRef;
        projectedMemoryIds.add(symbolicId);
        symbolicReferences.push({ localRef: operation.localRef, memoryId: symbolicId });
      }
    }
    const projectedOverview = copyOverviewWithCorrectionPlan(
      this.currentOverview, plan, symbolicReferences
    );
    if ((projectedMemoryIds.size > 0 &&
      (projectedOverview === null || !this.validOverviewForMemoryIds(projectedOverview, projectedMemoryIds))) ||
      (projectedMemoryIds.size === 0 && projectedOverview !== null)) {
      return this.applyError('概览修正结果无法完整对应长期记忆，请重新提交修改意见。');
    }
    if (actualWriteOperationCount === 0) {
      const updated = copyOverviewWithCorrectionPlan(this.currentOverview, plan, []);
      if (updated === null || !this.validOverviewForIndex(updated, freshIndex)) {
        return this.applyError('概览修正结果无效，请重新提交修改意见。');
      }
      this.saveCacheBestEffort(updated, plan.baseEvidenceFingerprint);
      if (!this.active(generation)) return this.inactiveApplyResult();
      this.currentOverview = updated;
      this.currentEvidenceIndex = freshIndex;
      return {
        status: 'presentation_only', overview: updated, evidenceIndex: freshIndex,
        message: '概览已更新。', succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
      };
    }
    let succeededWriteCount = 0;
    let failedWriteCount = 0;
    let atomicConflict = false;
    const addedReferences: AddedMemoryReference[] = [];
    const committedRecords: CommittedMemoryRecord[] = [];
    const guard = new OverviewMemoryCommitGuard((): boolean => this.active(generation));
    for (let position = 0; position < plan.operations.length; position += 1) {
      if (!this.active(generation)) {
        return succeededWriteCount > 0 ?
          this.committedButInactive(succeededWriteCount, plan.writeOperationCount - succeededWriteCount) :
          this.inactiveApplyResult();
      }
      const result = await this.applyWriteOperation(plan.operations[position], generation, guard);
      if (successfulSingleWrite(result)) {
        succeededWriteCount += 1;
        const operation = plan.operations[position];
        const record = result.records.length > 0 ? result.records[0].record : undefined;
        if (record === undefined) {
          failedWriteCount = plan.writeOperationCount - succeededWriteCount;
          break;
        }
        committedRecords.push({ operationIndex: position, record });
        if (operation.type === 'add') {
          addedReferences.push({ localRef: operation.localRef, memoryId: record.memoryId });
        }
      } else {
        if (!this.active(generation)) {
          return succeededWriteCount > 0 ?
            this.committedButInactive(succeededWriteCount, plan.writeOperationCount - succeededWriteCount) :
            this.inactiveApplyResult();
        }
        atomicConflict = memoryBatchHasWriteConflict(result);
        failedWriteCount = plan.writeOperationCount - succeededWriteCount;
        break;
      }
      if (!this.active(generation)) {
        return succeededWriteCount > 0 ?
          this.committedButInactive(succeededWriteCount, plan.writeOperationCount - succeededWriteCount) :
          this.inactiveApplyResult();
      }
    }
    if (atomicConflict && succeededWriteCount === 0) {
      this.clearCacheBestEffort();
      return {
        status: 'conflict', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆已发生变化，本次修改未执行。请重新进入页面后再修改。',
        succeededWriteCount: 0, failedWriteCount, modelCallCount: 0
      };
    }
    if (failedWriteCount === 0) {
      const resultingIndex = await this.readEvidenceIndex(generation);
      if (!this.active(generation)) {
        return this.committedButInactive(succeededWriteCount, 0);
      }
      const expectedIndex = this.expectedEvidenceIndexAfterWrites(plan, committedRecords);
      if (resultingIndex !== null && expectedIndex !== null && resultingIndex.entries.length === 0 &&
        expectedIndex.entries.length === 0) {
        this.clearCacheBestEffort();
        this.currentOverview = null;
        this.currentEvidenceIndex = resultingIndex;
        return {
          status: 'success', overview: null, evidenceIndex: resultingIndex,
          message: '已更新 ' + succeededWriteCount.toString() + ' 条长期记忆。',
          succeededWriteCount, failedWriteCount: 0, modelCallCount: 0
        };
      }
      const updated = resultingIndex === null ? null :
        copyOverviewWithCorrectionPlan(this.currentOverview, plan, addedReferences);
      if (resultingIndex === null || expectedIndex === null ||
        memoryOverviewEvidenceFingerprint(resultingIndex) !== memoryOverviewEvidenceFingerprint(expectedIndex) ||
        updated === null || !this.validOverviewForIndex(updated, resultingIndex)) {
        this.clearCacheBestEffort();
        this.currentOverview = null;
        this.currentEvidenceIndex = emptyEvidenceIndex();
        return {
          status: 'partial', overview: null, evidenceIndex: emptyEvidenceIndex(),
          message: '长期记忆已修改，概览将在下次进入时重新整理。',
          succeededWriteCount, failedWriteCount: 0, modelCallCount: 0
        };
      }
      const resultingFingerprint = memoryOverviewEvidenceFingerprint(resultingIndex);
      this.saveCacheBestEffort(updated, resultingFingerprint);
      this.currentOverview = updated;
      this.currentEvidenceIndex = resultingIndex;
      return {
        status: 'success', overview: updated, evidenceIndex: resultingIndex,
        message: '已更新 ' + succeededWriteCount.toString() + ' 条长期记忆。',
        succeededWriteCount, failedWriteCount: 0, modelCallCount: 0
      };
    }
    this.clearCacheBestEffort();
    this.currentOverview = null;
    this.currentEvidenceIndex = emptyEvidenceIndex();
    return {
      status: succeededWriteCount > 0 ? 'partial' : 'error',
      overview: null,
      evidenceIndex: emptyEvidenceIndex(),
      message: succeededWriteCount > 0 ?
        '部分记忆已修改，概览将在下次进入时重新整理。' :
        (atomicConflict ? '长期记忆已发生变化，本次修改未执行。请重新进入页面后再修改。' :
          '长期记忆修改失败，请重试。'),
      succeededWriteCount, failedWriteCount,
      modelCallCount: 0
    };
  }

  private active(generation: number): boolean {
    if (generation !== this.generation) return false;
    try {
      return this.hostIsActive();
    } catch (_error) {
      return false;
    }
  }

  private async generateOverviewForGeneration(
    generation: number
  ): Promise<LongTermMemoryOverviewGenerationResult> {
    if (!this.active(generation)) return this.inactiveGenerationResult();
    let snapshots: PhoneLocalMemorySnapshot[];
    try {
      snapshots = await this.source.listAllMemorySnapshots();
    } catch (_error) {
      if (!this.active(generation)) return this.inactiveGenerationResult();
      if (this.currentOverview !== null) {
        return {
          status: 'ready', overview: this.currentOverview,
          evidenceIndex: this.currentEvidenceIndex,
          message: '已显示上次概览，记忆依据暂时无法读取。', modelCallCount: 0, cacheHit: true
        };
      }
      return {
        status: 'error', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆暂时无法读取，请重试。', modelCallCount: 0, cacheHit: false
      };
    }
    if (!this.active(generation)) return this.inactiveGenerationResult();
    const cached = this.loadCache();
    if (snapshots.length === 0) {
      if (cached !== null) this.clearCacheBestEffort();
      this.currentOverview = null;
      this.currentEvidenceIndex = emptyEvidenceIndex();
      return {
        status: 'empty', overview: null, evidenceIndex: this.currentEvidenceIndex,
        message: '还没有长期记忆。', modelCallCount: 0, cacheHit: false
      };
    }
    let index: MemoryOverviewEvidenceIndex;
    try {
      index = buildMemoryOverviewEvidenceIndex(snapshots);
    } catch (_error) {
      return {
        status: 'error', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆数据暂时无法整理，请重试。', modelCallCount: 0, cacheHit: false
      };
    }
    const evidenceFingerprint = memoryOverviewEvidenceFingerprint(index);
    if (cached !== null && cached.evidenceFingerprint === evidenceFingerprint &&
      this.validOverviewForIndex(cached.overview, index)) {
      if (!this.active(generation)) return this.inactiveGenerationResult();
      this.currentOverview = cached.overview;
      this.currentEvidenceIndex = index;
      return {
        status: 'ready', overview: cached.overview, evidenceIndex: index,
        message: '', modelCallCount: 0, cacheHit: true
      };
    }
    if (cached !== null) this.clearCacheBestEffort();
    const outcome = await this.taskPort.generateOverview(index, (): boolean => this.active(generation));
    if (!this.active(generation) || outcome.status === 'inactive') return this.inactiveGenerationResult();
    if (outcome.status !== 'success' || outcome.value === null) {
      return {
        status: 'error', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: outcome.message.length > 0 ? outcome.message : '长期记忆概览生成失败，请重试。',
        modelCallCount: outcome.modelCallCount, cacheHit: false
      };
    }
    if (!this.validOverviewForIndex(outcome.value, index)) {
      return {
        status: 'error', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆概览证据不完整，请重试。',
        modelCallCount: outcome.modelCallCount, cacheHit: false
      };
    }
    this.saveCacheBestEffort(outcome.value, evidenceFingerprint);
    if (!this.active(generation)) return this.inactiveGenerationResult();
    this.currentOverview = outcome.value;
    this.currentEvidenceIndex = index;
    return {
      status: 'ready', overview: outcome.value, evidenceIndex: index,
      message: '', modelCallCount: outcome.modelCallCount, cacheHit: false
    };
  }

  private loadCache(): MemoryOverviewCacheEntry | null {
    if (this.cacheStore === null) return null;
    try {
      const cached = this.cacheStore.load();
      if (cached === null || cached.schemaVersion !== MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION ||
        cached.promptVersion !== MEMORY_OVERVIEW_PROMPT_VERSION ||
        cached.outputSchemaVersion !== MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION) return null;
      return cached;
    } catch (_error) {
      return null;
    }
  }

  private saveCacheBestEffort(overview: MemoryOverview, evidenceFingerprint: string): void {
    if (this.cacheStore === null) return;
    try {
      this.cacheStore.save({
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: this.now(),
        evidenceFingerprint,
        overview
      });
    } catch (_error) {
      // Cache persistence must never block the model-backed overview path.
    }
  }

  private clearCacheBestEffort(): void {
    if (this.cacheStore === null) return;
    try {
      this.cacheStore.clear();
    } catch (_error) {
      // Cache invalidation must never change the memory mutation result.
    }
  }

  private validOverviewForIndex(overview: MemoryOverview,
    index: MemoryOverviewEvidenceIndex): boolean {
    const currentIds: Set<string> = new Set<string>();
    for (let position = 0; position < index.entries.length; position += 1) {
      currentIds.add(index.entries[position].memoryId);
    }
    return this.validOverviewForMemoryIds(overview, currentIds);
  }

  private validOverviewForMemoryIds(overview: MemoryOverview, currentIds: Set<string>): boolean {
    if (overview === null || overview.title.trim().length === 0 || overview.summary.trim().length === 0 ||
      !Array.isArray(overview.claims) || overview.claims.length < 1 || overview.claims.length > 24 ||
      normalizeMemoryOverviewTags(overview.tagList) === null) return false;
    const coveredIds: Set<string> = new Set<string>();
    for (let position = 0; position < overview.claims.length; position += 1) {
      if (!isMemoryOverviewCategory(overview.claims[position].category) ||
        overview.claims[position].heading.trim().length === 0 ||
        overview.claims[position].body.trim().length === 0) return false;
      const ids = overview.claims[position].evidenceMemoryIds;
      if (!Array.isArray(ids) || ids.length < 1) return false;
      const claimIds: Set<string> = new Set<string>();
      for (let evidencePosition = 0; evidencePosition < ids.length; evidencePosition += 1) {
        const memoryId = ids[evidencePosition];
        if (!currentIds.has(memoryId) || claimIds.has(memoryId)) return false;
        claimIds.add(memoryId);
        coveredIds.add(memoryId);
      }
    }
    return coveredIds.size === currentIds.size;
  }

  private writeOperationCount(operations: MemoryCorrectionOperation[]): number {
    return operations.length;
  }

  private async readEvidenceIndex(generation: number): Promise<MemoryOverviewEvidenceIndex | null> {
    try {
      const snapshots = await this.source.listAllMemorySnapshots();
      if (!this.active(generation)) return null;
      return buildMemoryOverviewEvidenceIndex(snapshots);
    } catch (_error) {
      return null;
    }
  }

  private expectedEvidenceIndexAfterWrites(plan: MemoryCorrectionPlan,
    committedRecords: CommittedMemoryRecord[]): MemoryOverviewEvidenceIndex | null {
    const snapshots: PhoneLocalMemorySnapshot[] = [];
    for (let position = 0; position < this.currentEvidenceIndex.entries.length; position += 1) {
      const entry = this.currentEvidenceIndex.entries[position];
      snapshots.push({
        memoryId: entry.memoryId, fact: entry.fact, personaTag: entry.personaTag,
        authority: entry.authority, createdAt: entry.createdAt, updatedAt: entry.updatedAt
      });
    }
    for (let position = 0; position < plan.operations.length; position += 1) {
      const operation = plan.operations[position];
      let committed: MemoryRecord | null = null;
      for (let recordPosition = 0; recordPosition < committedRecords.length; recordPosition += 1) {
        if (committedRecords[recordPosition].operationIndex === position) {
          committed = committedRecords[recordPosition].record;
          break;
        }
      }
      if (committed === null) return null;
      if (operation.type === 'delete') {
        for (let snapshotPosition = snapshots.length - 1; snapshotPosition >= 0; snapshotPosition -= 1) {
          if (snapshots[snapshotPosition].memoryId === operation.memoryId) snapshots.splice(snapshotPosition, 1);
        }
        continue;
      }
      const next: PhoneLocalMemorySnapshot = {
        memoryId: committed.memoryId,
        fact: committed.fact,
        personaTag: committed.personaTag,
        authority: committed.authority,
        createdAt: committed.createdAt,
        updatedAt: committed.updatedAt
      };
      let replaced = false;
      for (let snapshotPosition = 0; snapshotPosition < snapshots.length; snapshotPosition += 1) {
        if (snapshots[snapshotPosition].memoryId !== next.memoryId) continue;
        snapshots[snapshotPosition] = next;
        replaced = true;
        break;
      }
      if (!replaced) snapshots.push(next);
    }
    try {
      return buildMemoryOverviewEvidenceIndex(snapshots);
    } catch (_error) {
      return null;
    }
  }

  private async applyWriteOperation(operation: MemoryCorrectionOperation, generation: number,
    guard: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.writeSequence += 1;
    const sourceTurnId = 'memory-overview-correction-' + this.now().toString() + '-' +
      this.writeSequence.toString();
    if (operation.type === 'update') {
      const update = operation as MemoryCorrectionUpdateOperation;
      const expected = this.expectedSnapshotForTarget(update);
      if (expected === null || this.runtime.updateIfSnapshotCurrent === undefined) {
        return this.conditionalMutationUnavailable();
      }
      return await this.runtime.updateIfSnapshotCurrent(
        { memoryId: update.memoryId, fact: update.afterFact },
        sourceTurnId, update.personaTag, expected, guard
      );
    }
    if (operation.type === 'delete') {
      const deletion = operation as MemoryCorrectionDeleteOperation;
      const expected = this.expectedSnapshotForTarget(deletion);
      if (expected === null || this.runtime.forgetIfSnapshotCurrent === undefined) {
        return this.conditionalMutationUnavailable();
      }
      return await this.runtime.forgetIfSnapshotCurrent(deletion.memoryId, expected, guard);
    }
    if (operation.type === 'add') {
      const addition = operation as MemoryCorrectionAddOperation;
      return await this.runtime.remember(
        [addition.afterFact], sourceTurnId, PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, guard
      );
    }
    const error: MemoryError = {
      code: 'memory_overview_operation_invalid',
      message: 'Unsupported long-term memory correction operation.',
      retryable: false
    };
    return {
      status: 'error',
      records: [{ inputIndex: 0, status: 'error', error }],
      succeededCount: 0,
      failedCount: 1,
      warnings: [],
      error
    };
  }

  private expectedSnapshotForTarget(
    target: MemoryCorrectionUpdateOperation | MemoryCorrectionDeleteOperation
  ): PhoneLocalMemorySnapshot | null {
    for (let position = 0; position < this.currentEvidenceIndex.entries.length; position += 1) {
      const entry = this.currentEvidenceIndex.entries[position];
      if (entry.memoryId !== target.memoryId || entry.evidenceIndex !== target.evidenceIndex) continue;
      if (entry.updatedAt !== target.expectedUpdatedAt || entry.fact !== target.beforeFact ||
        entry.personaTag !== target.personaTag) return null;
      return {
        memoryId: entry.memoryId,
        fact: entry.fact,
        personaTag: entry.personaTag,
        authority: entry.authority,
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt
      };
    }
    return null;
  }

  private conditionalMutationUnavailable(): MemoryBatchResult {
    const error: MemoryError = {
      code: 'memory_conditional_write_unavailable',
      message: 'Conditional long-term memory mutation is unavailable.',
      retryable: true
    };
    return {
      status: 'error', records: [{ inputIndex: 0, status: 'error', error }],
      succeededCount: 0, failedCount: 1, warnings: [], error
    };
  }

  private inactiveGenerationResult(): LongTermMemoryOverviewGenerationResult {
    return {
      status: 'inactive', overview: null, evidenceIndex: emptyEvidenceIndex(),
      message: '', modelCallCount: 0, cacheHit: false
    };
  }

  private inactivePlanResult(): LongTermMemoryCorrectionPlanResult {
    return { status: 'inactive', plan: null, message: '', modelCallCount: 0 };
  }

  private inactiveApplyResult(): LongTermMemoryCorrectionApplyResult {
    return {
      status: 'inactive', overview: null, evidenceIndex: emptyEvidenceIndex(), message: '',
      succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
    };
  }

  private applyError(message: string): LongTermMemoryCorrectionApplyResult {
    return {
      status: 'error', overview: this.currentOverview,
      evidenceIndex: this.currentEvidenceIndex, message,
      succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
    };
  }

  private committedButInactive(succeededWriteCount: number,
    failedWriteCount: number): LongTermMemoryCorrectionApplyResult {
    // A newly opened page may already have cached the post-commit evidence while
    // this retired task awaited its final read. Only invalidate our old basis.
    const cached = this.loadCache();
    if (cached !== null && cached.evidenceFingerprint ===
      memoryOverviewEvidenceFingerprint(this.currentEvidenceIndex)) {
      this.clearCacheBestEffort();
    }
    this.currentOverview = null;
    this.currentEvidenceIndex = emptyEvidenceIndex();
    return {
      status: 'partial', overview: null, evidenceIndex: emptyEvidenceIndex(),
      message: '部分记忆已修改，概览将在下次进入时重新整理。',
      succeededWriteCount, failedWriteCount, modelCallCount: 0
    };
  }
}
