import {
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryError
} from '@loop/agent-core';
import {
  MemoryCorrectionOperation,
  MemoryCorrectionPlan,
  MemoryCorrectionPresentationOperation,
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
export type LongTermMemoryCorrectionPlanStatus = 'ready' | 'needs_clarification' | 'error' | 'inactive';
export type LongTermMemoryCorrectionApplyStatus =
  'success' | 'presentation_only' | 'conflict' | 'partial' | 'error' | 'inactive';

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

  constructor(index: MemoryOverviewEvidenceIndex, overview: MemoryOverview) {
    this.index = index;
    this.overview = overview;
  }

  validate(raw: string): MemoryCorrectionPlan | null {
    return parseMemoryCorrectionPlanModelOutput(raw, this.index, this.overview);
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
      validator: new CorrectionPlanModelValidator(index, overview),
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

function snapshotsMatch(expectedMemoryId: string, expectedUpdatedAt: number,
  expectedFact: string, expectedPersonaTag: string, actual: PhoneLocalMemorySnapshot | null): boolean {
  return actual !== null && actual.memoryId === expectedMemoryId &&
    actual.updatedAt === expectedUpdatedAt && actual.fact === expectedFact &&
    actual.personaTag === expectedPersonaTag;
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

function copyOverviewWithPresentationOperations(overview: MemoryOverview,
  operations: MemoryCorrectionOperation[]): MemoryOverview | null {
  const claims: MemoryOverviewClaim[] = overview.claims.map(
    (claim: MemoryOverviewClaim): MemoryOverviewClaim => ({
    heading: claim.heading,
    body: claim.body,
    evidenceMemoryIds: claim.evidenceMemoryIds.slice()
    })
  );
  for (let position = 0; position < operations.length; position += 1) {
    const operation = operations[position];
    if (operation.type !== 'presentation_only') return null;
    const presentation = operation as MemoryCorrectionPresentationOperation;
    const claimPosition = presentation.claimIndex - 1;
    if (claimPosition < 0 || claimPosition >= claims.length) return null;
    claims[claimPosition].heading = presentation.replacementHeading;
    claims[claimPosition].body = presentation.replacementBody;
  }
  return { title: overview.title, summary: overview.summary, claims };
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
    if (outcome.value.status === 'needs_clarification') {
      return {
        status: 'needs_clarification', plan: outcome.value,
        message: outcome.value.clarificationQuestion, modelCallCount: outcome.modelCallCount
      };
    }
    return {
      status: 'ready', plan: outcome.value, message: '修正方案已生成，请确认后再写入。',
      modelCallCount: outcome.modelCallCount
    };
  }

  async applyPlan(plan: MemoryCorrectionPlan): Promise<LongTermMemoryCorrectionApplyResult> {
    const generation = this.generation;
    if (!this.active(generation)) return this.inactiveApplyResult();
    if (plan.status !== 'ready' || plan.operations.length === 0) {
      return this.applyError('没有可确认的修正操作。');
    }
    if (plan.writeOperationCount === 0) {
      if (this.currentOverview === null) return this.applyError('当前概览已失效，请刷新后重试。');
      const updated = copyOverviewWithPresentationOperations(this.currentOverview, plan.operations);
      if (updated === null) return this.applyError('概览措辞修正方案无效，请重新生成。');
      if (!this.active(generation)) return this.inactiveApplyResult();
      this.currentOverview = updated;
      return {
        status: 'presentation_only', overview: updated,
        evidenceIndex: this.currentEvidenceIndex,
        message: '已修改当前概览的展示措辞，未改动长期记忆。',
        succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
      };
    }
    const actualWriteOperationCount = this.writeOperationCount(plan.operations);
    if (plan.writeOperationCount !== actualWriteOperationCount ||
      actualWriteOperationCount < 1 || actualWriteOperationCount > 5) {
      return this.applyError('一次最多确认五项长期记忆写入。');
    }
    const hasOnlyWrites = this.writeOperationsOnly(plan.operations);
    if (!hasOnlyWrites) return this.applyError('展示修正不能与长期记忆写入同时执行。');
    const conflict = await this.hasFreshnessConflict(plan.operations, generation);
    if (!this.active(generation)) return this.inactiveApplyResult();
    if (conflict) {
      return {
        status: 'conflict', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆已发生变化，本次方案未写入。请重新进入页面后重试。',
        succeededWriteCount: 0, failedWriteCount: 0, modelCallCount: 0
      };
    }
    this.clearCacheBestEffort();
    let succeededWriteCount = 0;
    let failedWriteCount = 0;
    let atomicConflict = false;
    const guard = new OverviewMemoryCommitGuard((): boolean => this.active(generation));
    for (let position = 0; position < plan.operations.length; position += 1) {
      if (!this.active(generation)) return this.inactiveApplyResult();
      const result = await this.applyWriteOperation(plan.operations[position], generation, guard);
      if (!this.active(generation)) return this.inactiveApplyResult();
      if (successfulSingleWrite(result)) {
        succeededWriteCount += 1;
      } else {
        atomicConflict = memoryBatchHasWriteConflict(result);
        failedWriteCount = plan.writeOperationCount - succeededWriteCount;
        break;
      }
    }
    if (atomicConflict && succeededWriteCount === 0) {
      return {
        status: 'conflict', overview: this.currentOverview,
        evidenceIndex: this.currentEvidenceIndex,
        message: '长期记忆已发生变化，本次方案未写入。请重新进入页面后重试。',
        succeededWriteCount: 0, failedWriteCount, modelCallCount: 0
      };
    }
    if (failedWriteCount === 0) {
      const refreshed = await this.generateOverviewForGeneration(generation);
      if (refreshed.status === 'inactive') return this.inactiveApplyResult();
      if (refreshed.status === 'error') {
        return {
          status: 'partial', overview: refreshed.overview,
          evidenceIndex: refreshed.evidenceIndex,
          message: '长期记忆已修改，但概览暂时无法更新；下次打开时将重新生成概览。',
          succeededWriteCount, failedWriteCount: 0, modelCallCount: refreshed.modelCallCount
        };
      }
      return {
        status: 'success', overview: refreshed.overview,
        evidenceIndex: refreshed.evidenceIndex,
        message: '长期记忆已按确认方案修改。',
        succeededWriteCount, failedWriteCount: 0, modelCallCount: refreshed.modelCallCount
      };
    }
    const refreshed = await this.generateOverviewForGeneration(generation);
    if (refreshed.status === 'inactive') return this.inactiveApplyResult();
    const refreshFailed = refreshed.status === 'error';
    return {
      status: succeededWriteCount > 0 ? 'partial' : 'error',
      overview: refreshed.overview,
      evidenceIndex: refreshed.evidenceIndex,
      message: succeededWriteCount > 0 ?
        (atomicConflict ? (refreshFailed ?
          '部分长期记忆已修改，后续因记忆变化未写入，且概览暂时无法更新；下次打开时将重新生成概览。' :
          '部分长期记忆已修改，后续因记忆变化未写入；概览已按当前数据重新生成。') :
          (refreshFailed ?
            '部分长期记忆已修改，其余操作失败，且概览暂时无法更新；下次打开时将重新生成概览。' :
            '部分长期记忆已修改，其余操作失败；概览已按当前数据重新生成。')) :
        (refreshFailed ?
          '长期记忆修改失败，且概览暂时无法更新；下次打开时将重新生成概览。' :
          '长期记忆修改失败，概览已按当前数据重新生成。'),
      succeededWriteCount, failedWriteCount,
      modelCallCount: refreshed.modelCallCount
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
    if (overview === null || !Array.isArray(overview.claims) || overview.claims.length < 1) return false;
    const currentIds: Set<string> = new Set<string>();
    for (let position = 0; position < index.entries.length; position += 1) {
      currentIds.add(index.entries[position].memoryId);
    }
    const coveredIds: Set<string> = new Set<string>();
    for (let position = 0; position < overview.claims.length; position += 1) {
      const ids = overview.claims[position].evidenceMemoryIds;
      if (!Array.isArray(ids) || ids.length < 1) return false;
      for (let evidencePosition = 0; evidencePosition < ids.length; evidencePosition += 1) {
        const memoryId = ids[evidencePosition];
        if (!currentIds.has(memoryId)) return false;
        coveredIds.add(memoryId);
      }
    }
    return coveredIds.size === currentIds.size;
  }

  private writeOperationsOnly(operations: MemoryCorrectionOperation[]): boolean {
    for (let position = 0; position < operations.length; position += 1) {
      if (operations[position].type === 'presentation_only') return false;
    }
    return true;
  }

  private writeOperationCount(operations: MemoryCorrectionOperation[]): number {
    let count = 0;
    for (let position = 0; position < operations.length; position += 1) {
      if (operations[position].type !== 'presentation_only') count += 1;
    }
    return count;
  }

  private async hasFreshnessConflict(operations: MemoryCorrectionOperation[],
    generation: number): Promise<boolean> {
    for (let position = 0; position < operations.length; position += 1) {
      const operation = operations[position];
      if (operation.type !== 'update' && operation.type !== 'delete') continue;
      const target = operation as MemoryCorrectionUpdateOperation | MemoryCorrectionDeleteOperation;
      let snapshot: PhoneLocalMemorySnapshot | null;
      try {
        snapshot = await this.source.getMemorySnapshot(target.memoryId);
      } catch (_error) {
        return true;
      }
      if (!this.active(generation)) return false;
      if (!snapshotsMatch(target.memoryId, target.expectedUpdatedAt, target.beforeFact,
        target.personaTag, snapshot)) return true;
    }
    return false;
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
}
