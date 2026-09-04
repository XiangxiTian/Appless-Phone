import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  EmbeddingPort,
  aiLogError,
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryDraft,
  MemoryError,
  MemoryHit,
  MemoryRecord,
  MemoryWriteResult,
  MEMORY_RECALL_DEFAULT_TOP_K,
  MEMORY_RECALL_FACT_MAX_CHARS,
  MEMORY_RECALL_MAX_TOP_K,
  memoryRecallTotalMaxChars,
  validMemoryRecallTopK
} from '@loop/agent-core';
import { BertWordPieceTokenizer } from './BertWordPieceTokenizer';
import { BgeMindSporeEmbeddingPort } from './BgeMindSporeEmbeddingPort';
import {
  PhoneLocalMemoryPersonaTagReplaceResult,
  PhoneLocalMemoryProvider
} from './PhoneLocalMemoryProvider';
import {
  ArkDataPhoneLocalMemoryStore,
  PhoneLocalMemoryExpectedRecord,
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats,
  PhoneLocalMemoryStore
} from './PhoneLocalMemoryStore';
import { ArkDataPhoneLocalMemoryBlobStore } from './PhoneLocalMemoryBlobFallbackPort';
import {
  ArkDataPhoneLocalMemoryBackendRegistry,
  PhoneLocalMemoryBackendId,
  PhoneLocalMemoryBackendRegistryPort
} from './PhoneLocalMemoryBackendRegistry';

export const PHONE_LOCAL_MEMORY_OWNER_ID: string = 'local-user-v1';
export const PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID: string = 'global';
export const PHONE_LOCAL_MEMORY_PUBLIC_PERSONA_TAG: string = 'public_persona';
export const PHONE_LOCAL_MEMORY_RECALL_TOP_K: number = MEMORY_RECALL_DEFAULT_TOP_K;
export const PHONE_LOCAL_MEMORY_RECALL_TIMEOUT_MS: number = 2500;
export const PHONE_LOCAL_MEMORY_RECALL_FACT_LIMIT: number = MEMORY_RECALL_FACT_MAX_CHARS;
export const PHONE_LOCAL_MEMORY_RECALL_TOTAL_LIMIT: number = memoryRecallTotalMaxChars(
  MEMORY_RECALL_DEFAULT_TOP_K
);
export const PHONE_LOCAL_MEMORY_RECALL_MAX_TOTAL_LIMIT: number = memoryRecallTotalMaxChars(
  MEMORY_RECALL_MAX_TOP_K
);

const MEMORY_RUNTIME_LOG_DOMAIN: number = 0x0000;
const MEMORY_RUNTIME_LOG_TAG: string = 'MemoryRuntime';
const MEMORY_RUNTIME_LOG_LIMIT: number = 160;

export interface PhoneLocalRecalledMemory {
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: 'leader' | 'seed';
}

/** Lightweight read model for overview and correction flows. It intentionally excludes embeddings. */
export interface PhoneLocalMemorySnapshot {
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: 'leader' | 'seed';
  createdAt: number;
  updatedAt: number;
}

export interface PhoneLocalMemoryRuntimeLogger {
  warn(code: string, operation: string, errorMessage: string): void;
}

export type PhoneLocalMemoryMutationOperation = 'remember' | 'update' | 'forget';

export interface PhoneLocalMemoryMutationEvent {
  operation: PhoneLocalMemoryMutationOperation;
  committedAt: number;
  memoryIds: string[];
}

export interface PhoneLocalMemoryRuntimeOptions {
  /** Account owner scope. Omission preserves the pre-account local-user-v1 scope. */
  ownerId?: string;
  /** Explicit single-store injection retained for unit tests and embedders. It bypasses backend selection. */
  storeFactory?: () => PhoneLocalMemoryStore;
  vectorStoreFactory?: () => PhoneLocalMemoryStore;
  blobStoreFactory?: () => PhoneLocalMemoryStore;
  backendRegistryFactory?: () => PhoneLocalMemoryBackendRegistryPort;
  embedderFactory?: () => Promise<EmbeddingPort>;
  idFactory?: () => string;
  recallTimeoutMs?: number;
  logger?: PhoneLocalMemoryRuntimeLogger;
  /** Runs off the mutation return path. Observer failures never change the memory tool result. */
  onMutationCommitted?: (event: PhoneLocalMemoryMutationEvent) => Promise<void>;
}

interface SelectedMemoryStore {
  store: PhoneLocalMemoryStore;
}

export interface PhoneLocalMemoryProjectionSourcePort {
  getProjectionStats(basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats>;
  listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]>;
}

export interface PhoneLocalMemoryOverviewSourcePort {
  listAllMemorySnapshots(): Promise<PhoneLocalMemorySnapshot[]>;
  getMemorySnapshot(memoryId: string): Promise<PhoneLocalMemorySnapshot | null>;
}

export interface PhoneLocalMemoryRuntimePort extends PhoneLocalMemoryProjectionSourcePort {
  recall(text: string, topK?: number): Promise<PhoneLocalRecalledMemory[]>;
  remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  update(updates: PhoneLocalMemoryUpdate[], sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  updateIfSnapshotCurrent?(update: PhoneLocalMemoryUpdate, sourceTurnId: string, personaTag: string,
    expected: PhoneLocalMemorySnapshot, guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  forgetIfSnapshotCurrent?(memoryId: string, expected: PhoneLocalMemorySnapshot,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
}

export interface PhoneLocalMemoryUpdate {
  memoryId: string;
  fact: string;
}

class HilogPhoneLocalMemoryRuntimeLogger implements PhoneLocalMemoryRuntimeLogger {
  warn(code: string, operation: string, errorMessage: string): void {
    hilog.warn(MEMORY_RUNTIME_LOG_DOMAIN, MEMORY_RUNTIME_LOG_TAG,
      'code=%{public}s operation=%{public}s error=%{public}s', code, operation, errorMessage);
    aiLogError('[AIPhone][PhoneLocalMemoryRuntime] code=' + code +
      ' operation=' + operation + ' error=' + errorMessage);
  }
}

function boundedRuntimeError(error: Object): string {
  let message = error instanceof Error ? error.message : 'Unknown phone-local memory runtime failure.';
  message = message.replace(/[\r\n\t]+/g, ' ').trim();
  if (message.length === 0) message = 'Unknown phone-local memory runtime failure.';
  return message.substring(0, MEMORY_RUNTIME_LOG_LIMIT);
}

function runtimeMemoryError(code: string, message: string, retryable: boolean): MemoryError {
  return { code, message, retryable };
}

function unavailableWrite(error: MemoryError, inputIndex: number = 0): MemoryWriteResult {
  return { inputIndex, status: 'error', error };
}

function unavailableBatch(recordCount: number, error: MemoryError): MemoryBatchResult {
  const records: MemoryWriteResult[] = [];
  const count = Math.max(1, recordCount);
  for (let index = 0; index < count; index += 1) records.push(unavailableWrite(error, index));
  return {
    status: 'error', records, succeededCount: 0, failedCount: count, warnings: [], error
  };
}

function boundedFact(fact: string, remaining: number): string {
  const limit = Math.min(PHONE_LOCAL_MEMORY_RECALL_FACT_LIMIT, remaining);
  return fact.substring(0, Math.max(0, limit));
}

function successfulRecordBatch(records: MemoryRecord[]): MemoryBatchResult {
  const results: MemoryWriteResult[] = [];
  for (let index = 0; index < records.length; index += 1) {
    results.push({ inputIndex: index, status: 'success', record: records[index] });
  }
  return {
    status: 'success', records: results, succeededCount: records.length, failedCount: 0, warnings: []
  };
}

function singleWriteBatch(result: MemoryWriteResult): MemoryBatchResult {
  const success = result.status === 'success';
  const batch: MemoryBatchResult = {
    status: success ? 'success' : 'error',
    records: [result],
    succeededCount: success ? 1 : 0,
    failedCount: success ? 0 : 1,
    warnings: []
  };
  if (!success) {
    batch.error = result.error ?? runtimeMemoryError(
      'memory_write_failed', 'Long-term memory could not be changed.', true
    );
  }
  return batch;
}

function expectedRecord(snapshot: PhoneLocalMemorySnapshot): PhoneLocalMemoryExpectedRecord {
  return {
    memoryId: snapshot.memoryId,
    fact: snapshot.fact,
    personaTag: snapshot.personaTag,
    authority: snapshot.authority,
    createdAt: snapshot.createdAt,
    updatedAt: snapshot.updatedAt
  };
}

function tagMutationFailure(recordCount: number, outcome: PhoneLocalMemoryPersonaTagReplaceResult): MemoryBatchResult {
  return unavailableBatch(recordCount, outcome.error ?? runtimeMemoryError(
    'memory_persona_tag_replace_failed', 'Long-term persona memory could not be changed.', true
  ));
}

/**
 * Application-lifetime composition root for phone-local memory.
 * Recall is fail-open; mutations surface initialization/model/storage failures to the caller.
 */
export class PhoneLocalMemoryRuntime implements PhoneLocalMemoryRuntimePort, PhoneLocalMemoryOverviewSourcePort {
  private context: common.Context | null;
  private options: PhoneLocalMemoryRuntimeOptions;
  private storePromise: Promise<PhoneLocalMemoryStore> | null = null;
  private providerPromise: Promise<PhoneLocalMemoryProvider> | null = null;
  private logger: PhoneLocalMemoryRuntimeLogger;
  private ownerId: string;

  constructor(context: common.Context | null, options: PhoneLocalMemoryRuntimeOptions = {}) {
    this.context = context;
    this.options = options;
    const ownerId: string = options.ownerId?.trim() ?? '';
    this.ownerId = ownerId.length > 0 ? ownerId : PHONE_LOCAL_MEMORY_OWNER_ID;
    this.logger = options.logger ?? new HilogPhoneLocalMemoryRuntimeLogger();
  }

  async recall(text: string, topK: number = MEMORY_RECALL_DEFAULT_TOP_K): Promise<PhoneLocalRecalledMemory[]> {
    const query = text.trim();
    if (query.length === 0 || !validMemoryRecallTopK(topK)) return [];
    try {
      const hits = await this.withTimeout(this.search(query, topK));
      const output: PhoneLocalRecalledMemory[] = [];
      let remaining = memoryRecallTotalMaxChars(topK);
      for (let index = 0; index < hits.length && remaining > 0; index += 1) {
        const fact = boundedFact(hits[index].record.fact, remaining);
        if (fact.length === 0) break;
        output.push({
          memoryId: hits[index].record.memoryId,
          fact,
          personaTag: hits[index].record.personaTag,
          authority: hits[index].record.authority
        });
        remaining -= fact.length;
      }
      return output;
    } catch (error) {
      this.log('memory_recall_unavailable', 'recall', error);
      return [];
    }
  }

  async remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    try {
      const provider = await this.provider();
      const records: MemoryDraft[] = [];
      for (let index = 0; index < facts.length; index += 1) {
        records.push({
          fact: facts[index],
          sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
          personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
          authority: 'leader',
          sourceTurnId
        });
      }
      const result = await provider.remember({ ownerId: this.ownerId, records }, guard);
      const memoryIds: string[] = [];
      let committedAt: number = 0;
      for (let index = 0; index < result.records.length; index += 1) {
        const record = result.records[index].record;
        if (result.records[index].status !== 'success' || record === undefined) continue;
        memoryIds.push(record.memoryId);
        committedAt = Math.max(committedAt, record.updatedAt);
      }
      if (memoryIds.length > 0) this.notifyMutation({ operation: 'remember', committedAt, memoryIds });
      return result;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'remember', error);
      return unavailableBatch(facts.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async update(updates: PhoneLocalMemoryUpdate[], sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    const invalidError: MemoryError = runtimeMemoryError(
      'memory_update_invalid', 'Long-term memory update requires one to five unique record IDs.', false
    );
    if (updates.length < 1 || updates.length > 5) {
      const records: MemoryWriteResult[] = [];
      for (let index = 0; index < updates.length; index++) {
        records.push(unavailableWrite(invalidError, index));
      }
      return {
        status: 'error', records, succeededCount: 0, failedCount: updates.length,
        warnings: [], error: invalidError
      };
    }
    const requestedIds: Set<string> = new Set<string>();
    for (let index = 0; index < updates.length; index++) {
      const memoryId: string = updates[index].memoryId.trim();
      if (memoryId.length === 0 || requestedIds.has(memoryId)) {
        return unavailableBatch(updates.length, invalidError);
      }
      requestedIds.add(memoryId);
    }
    try {
      const provider = await this.provider();
      const records: MemoryWriteResult[] = [];
      const memoryIds: string[] = [];
      let committedAt: number = 0;
      let firstError: MemoryError | undefined;
      for (let index = 0; index < updates.length; index += 1) {
        let result: MemoryWriteResult;
        try {
          result = await provider.update({
            ownerId: this.ownerId,
            memoryId: updates[index].memoryId,
            fact: updates[index].fact,
            personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
            authority: 'leader',
            sourceTurnId
          }, guard);
        } catch (error) {
          this.log('memory_runtime_update_failed', 'update', error);
          result = unavailableWrite(runtimeMemoryError(
            'memory_runtime_update_failed', 'Long-term memory record could not be updated.', true
          ), index);
        }
        result.inputIndex = index;
        records.push(result);
        if (result.status === 'success' && result.record !== undefined) {
          memoryIds.push(result.record.memoryId);
          committedAt = Math.max(committedAt, result.record.updatedAt);
        } else if (firstError === undefined && result.error !== undefined) {
          firstError = result.error;
        }
      }
      const succeededCount: number = memoryIds.length;
      const failedCount: number = updates.length - succeededCount;
      if (succeededCount > 0) {
        this.notifyMutation({ operation: 'update', committedAt, memoryIds });
      }
      const batch: MemoryBatchResult = {
        status: succeededCount > 0 ? 'success' : 'error',
        records,
        succeededCount,
        failedCount,
        warnings: failedCount > 0 && succeededCount > 0 ? ['Some long-term memories could not be updated.'] : []
      };
      if (succeededCount === 0) {
        batch.error = firstError ?? runtimeMemoryError(
          'memory_update_failed', 'Long-term memory could not be updated.', true
        );
      }
      return batch;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'update', error);
      return unavailableBatch(updates.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    const invalidError: MemoryError = runtimeMemoryError(
      'memory_forget_invalid', 'Long-term memory deletion requires one to five unique record IDs.', false
    );
    if (memoryIds.length < 1 || memoryIds.length > 5) {
      return unavailableBatch(memoryIds.length, invalidError);
    }
    const requestedIds: Set<string> = new Set<string>();
    for (let index = 0; index < memoryIds.length; index++) {
      const memoryId: string = memoryIds[index].trim();
      if (memoryId.length === 0 || requestedIds.has(memoryId)) {
        return unavailableBatch(memoryIds.length, invalidError);
      }
      requestedIds.add(memoryId);
    }
    try {
      const provider = await this.provider();
      const records: MemoryWriteResult[] = [];
      const forgottenIds: string[] = [];
      let firstError: MemoryError | undefined;
      for (let index = 0; index < memoryIds.length; index++) {
        let result: MemoryWriteResult;
        try {
          result = await provider.forget(this.ownerId, memoryIds[index], guard);
        } catch (error) {
          this.log('memory_runtime_forget_failed', 'forget', error);
          result = unavailableWrite(runtimeMemoryError(
            'memory_runtime_forget_failed', 'Long-term memory record could not be deleted.', true
          ), index);
        }
        result.inputIndex = index;
        records.push(result);
        if (result.status === 'success' && result.record !== undefined) {
          forgottenIds.push(result.record.memoryId);
        } else if (firstError === undefined && result.error !== undefined) {
          firstError = result.error;
        }
      }
      const succeededCount: number = forgottenIds.length;
      const failedCount: number = memoryIds.length - succeededCount;
      if (succeededCount > 0) {
        this.notifyMutation({ operation: 'forget', committedAt: Date.now(), memoryIds: forgottenIds });
      }
      const batch: MemoryBatchResult = {
        status: succeededCount > 0 ? 'success' : 'error',
        records,
        succeededCount,
        failedCount,
        warnings: failedCount > 0 && succeededCount > 0 ?
          ['Some long-term memories could not be deleted.'] : []
      };
      if (succeededCount === 0) {
        batch.error = firstError ?? runtimeMemoryError(
          'memory_forget_failed', 'Long-term memory could not be deleted.', true
        );
      }
      return batch;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'forget', error);
      return unavailableBatch(memoryIds.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async getProjectionStats(basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    return await (await this.memoryStore()).getProjectionStats(
      this.ownerId,
      PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
      basedOnMemoryMutationAt
    );
  }

  async listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]> {
    return await (await this.memoryStore()).listProjectionFacts(
      this.ownerId,
      PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID
    );
  }

  async listAllMemorySnapshots(): Promise<PhoneLocalMemorySnapshot[]> {
    const records = await (await this.memoryStore()).list(this.ownerId, []);
    const snapshots: PhoneLocalMemorySnapshot[] = [];
    for (let index = 0; index < records.length; index += 1) {
      snapshots.push(this.snapshotFromRecord(records[index]));
    }
    return snapshots;
  }

  async getMemorySnapshot(memoryId: string): Promise<PhoneLocalMemorySnapshot | null> {
    const normalizedMemoryId = memoryId.trim();
    if (normalizedMemoryId.length === 0) return null;
    const record = await (await this.memoryStore()).get(this.ownerId, normalizedMemoryId);
    return record === null ? null : this.snapshotFromRecord(record);
  }

  async updateIfSnapshotCurrent(update: PhoneLocalMemoryUpdate, sourceTurnId: string,
    personaTag: string, expected: PhoneLocalMemorySnapshot,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    if (update.memoryId.trim().length === 0 || update.memoryId.trim() !== expected.memoryId.trim()) {
      return unavailableBatch(1, runtimeMemoryError(
        'memory_update_invalid', 'Conditional memory update requires one exact record snapshot.', false
      ));
    }
    try {
      const result = await (await this.provider()).updateIfCurrent({
        ownerId: this.ownerId,
        memoryId: update.memoryId,
        fact: update.fact,
        personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        authority: 'leader',
        sourceTurnId
      }, expectedRecord(expected), guard);
      const batch = singleWriteBatch(result);
      if (result.status === 'success' && result.record !== undefined) {
        this.notifyMutation({
          operation: 'update', committedAt: result.record.updatedAt, memoryIds: [result.record.memoryId]
        });
      }
      return batch;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'updateIfSnapshotCurrent', error);
      return unavailableBatch(1, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async forgetIfSnapshotCurrent(memoryId: string, expected: PhoneLocalMemorySnapshot,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    if (memoryId.trim().length === 0 || memoryId.trim() !== expected.memoryId.trim()) {
      return unavailableBatch(1, runtimeMemoryError(
        'memory_forget_invalid', 'Conditional memory deletion requires one exact record snapshot.', false
      ));
    }
    try {
      const result = await (await this.provider()).forgetIfCurrent(
        this.ownerId, memoryId, expectedRecord(expected), guard
      );
      const batch = singleWriteBatch(result);
      if (result.status === 'success' && result.record !== undefined) {
        this.notifyMutation({ operation: 'forget', committedAt: Date.now(), memoryIds: [result.record.memoryId] });
      }
      return batch;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'forgetIfSnapshotCurrent', error);
      return unavailableBatch(1, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async replacePublicPersonaFacts(facts: string[], sourceTurnId: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    if (facts.length < 1) {
      return unavailableBatch(facts.length, runtimeMemoryError(
        'memory_request_invalid', 'Public persona memory requires at least one fact.', false
      ));
    }
    try {
      const records: MemoryDraft[] = [];
      for (let index = 0; index < facts.length; index += 1) {
        records.push({
          fact: facts[index],
          sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
          personaTag: PHONE_LOCAL_MEMORY_PUBLIC_PERSONA_TAG,
          authority: 'leader',
          sourceTurnId
        });
      }
      const outcome = await (await this.provider()).replacePersonaTag({
        ownerId: this.ownerId,
        sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        personaTag: PHONE_LOCAL_MEMORY_PUBLIC_PERSONA_TAG,
        records
      }, guard);
      if (outcome.status !== 'success') return tagMutationFailure(facts.length, outcome);
      const result = successfulRecordBatch(outcome.insertedRecords);
      if (outcome.removedRecords.length > 0) {
        const affectedIds: string[] = [];
        for (let index = 0; index < outcome.removedRecords.length; index += 1) {
          affectedIds.push(outcome.removedRecords[index].memoryId);
        }
        for (let index = 0; index < outcome.insertedRecords.length; index += 1) {
          affectedIds.push(outcome.insertedRecords[index].memoryId);
        }
        this.notifyMutation({ operation: 'forget', committedAt: Date.now(), memoryIds: affectedIds });
      } else if (outcome.insertedRecords.length > 0) {
        let committedAt: number = 0;
        const insertedIds: string[] = [];
        for (let index = 0; index < outcome.insertedRecords.length; index += 1) {
          insertedIds.push(outcome.insertedRecords[index].memoryId);
          committedAt = Math.max(committedAt, outcome.insertedRecords[index].updatedAt);
        }
        this.notifyMutation({ operation: 'remember', committedAt, memoryIds: insertedIds });
      }
      return result;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'replacePublicPersonaFacts', error);
      return unavailableBatch(facts.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async deletePublicPersonaFacts(guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    try {
      const outcome = await (await this.provider()).replacePersonaTag({
        ownerId: this.ownerId,
        sceneId: PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        personaTag: PHONE_LOCAL_MEMORY_PUBLIC_PERSONA_TAG,
        records: []
      }, guard);
      if (outcome.status !== 'success') return tagMutationFailure(1, outcome);
      const result = successfulRecordBatch(outcome.removedRecords);
      if (outcome.removedRecords.length > 0) {
        const removedIds: string[] = [];
        for (let index = 0; index < outcome.removedRecords.length; index += 1) {
          removedIds.push(outcome.removedRecords[index].memoryId);
        }
        this.notifyMutation({ operation: 'forget', committedAt: Date.now(), memoryIds: removedIds });
      }
      return result;
    } catch (error) {
      this.log('memory_runtime_unavailable', 'deletePublicPersonaFacts', error);
      return unavailableBatch(1, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  /**
   * First-login migration hook. Both record rows and their history rows move in one store
   * transaction; repeating the claim returns zero and leaves the account scope unchanged.
   */
  async claimLegacyOwner(legacyOwnerId: string = PHONE_LOCAL_MEMORY_OWNER_ID): Promise<number> {
    return await (await this.memoryStore()).claimOwner(legacyOwnerId, this.ownerId);
  }

  getOwnerId(): string {
    return this.ownerId;
  }

  private provider(): Promise<PhoneLocalMemoryProvider> {
    if (this.providerPromise === null) this.providerPromise = this.createProvider();
    return this.providerPromise;
  }

  private snapshotFromRecord(record: MemoryRecord): PhoneLocalMemorySnapshot {
    return {
      memoryId: record.memoryId,
      fact: record.fact,
      personaTag: record.personaTag,
      authority: record.authority,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt
    };
  }

  private memoryStore(): Promise<PhoneLocalMemoryStore> {
    if (this.storePromise === null) {
      this.storePromise = this.selectStore().then((selected: SelectedMemoryStore): PhoneLocalMemoryStore => {
        return selected.store;
      });
    }
    return this.storePromise;
  }

  private async createProvider(): Promise<PhoneLocalMemoryProvider> {
    const store = await this.memoryStore();
    const embedder = this.options.embedderFactory !== undefined ?
      await this.options.embedderFactory() : await this.createDefaultEmbedder();
    // The runtime wrapper fixes every new write to global. Keep the provider compatible with
    // legacy records in another scene so an exact-id update/forget can still complete.
    return new PhoneLocalMemoryProvider(store, embedder, {
      idFactory: this.options.idFactory
    });
  }

  private notifyMutation(event: PhoneLocalMemoryMutationEvent): void {
    const observer = this.options.onMutationCommitted;
    if (observer === undefined) return;
    Promise.resolve<void>(undefined).then((): Promise<void> => observer(event)).then((): void => {},
      (error: Object): void => this.log('memory_mutation_observer_failed', event.operation, error));
  }

  private async selectStore(): Promise<SelectedMemoryStore> {
    if (this.options.storeFactory !== undefined) {
      const store = this.options.storeFactory();
      await store.initialize();
      return { store };
    }
    const registry = this.createBackendRegistry();
    let previousBackend: PhoneLocalMemoryBackendId | null = null;
    try {
      previousBackend = await registry.getSelectedBackend();
    } catch (error) {
      this.log('memory_backend_marker_read_failed', 'initialize', error);
    }

    let selectedStore: PhoneLocalMemoryStore;
    let selectedBackend: PhoneLocalMemoryBackendId;
    if (previousBackend === 'blob') {
      selectedStore = this.createBlobStore();
      await selectedStore.initialize();
      selectedBackend = 'blob';
    } else {
      try {
        selectedStore = this.createVectorStore();
        await selectedStore.initialize();
        await this.probeVectorStore(selectedStore);
        selectedBackend = 'vector';
      } catch (error) {
        this.log('memory_vector_backend_unavailable', 'initialize', error);
        selectedStore = this.createBlobStore();
        await selectedStore.initialize();
        selectedBackend = 'blob';
      }
    }

    // A missing registry marker is the first selection. This intentionally does not guess whether
    // the install predates the registry; an older vector-only install cannot be distinguished from
    // a fresh install on a non-vector device without a separate migration signal.
    const backendChanged = previousBackend !== null && previousBackend !== selectedBackend;
    try {
      await registry.setSelectedBackend(selectedBackend);
    } catch (error) {
      this.log('memory_backend_marker_write_failed', 'initialize', error);
    }
    if (backendChanged) {
      this.logger.warn('memory_backend_changed_data_not_migrated', 'initialize',
        'Memory backend changed and existing data was not migrated.');
    }
    return { store: selectedStore };
  }

  private createVectorStore(): PhoneLocalMemoryStore {
    if (this.options.vectorStoreFactory !== undefined) return this.options.vectorStoreFactory();
    if (this.context === null) throw new Error('Phone-local memory vector store requires an application context.');
    return new ArkDataPhoneLocalMemoryStore(this.context);
  }

  private createBlobStore(): PhoneLocalMemoryStore {
    if (this.options.blobStoreFactory !== undefined) return this.options.blobStoreFactory();
    if (this.context === null) throw new Error('Phone-local memory BLOB store requires an application context.');
    return new ArkDataPhoneLocalMemoryBlobStore(this.context);
  }

  private createBackendRegistry(): PhoneLocalMemoryBackendRegistryPort {
    if (this.options.backendRegistryFactory !== undefined) return this.options.backendRegistryFactory();
    if (this.context === null) throw new Error('Phone-local memory backend registry requires an application context.');
    return new ArkDataPhoneLocalMemoryBackendRegistry(this.context);
  }

  private async probeVectorStore(store: PhoneLocalMemoryStore): Promise<void> {
    const probe: number[] = new Array<number>(512).fill(0);
    probe[0] = 1;
    await store.search({
      ownerId: '__phone_memory_vector_probe__',
      sceneIds: [],
      embeddingProfileId: '__phone_memory_vector_probe__',
      queryEmbedding: probe,
      topK: 1
    });
  }

  private async search(query: string, topK: number): Promise<MemoryHit[]> {
    const provider = await this.provider();
    return await provider.search({
      ownerId: this.ownerId,
      text: query,
      sceneIds: [],
      topK
    });
  }

  private async createDefaultEmbedder(): Promise<EmbeddingPort> {
    if (this.context === null) throw new Error('Phone-local memory requires an application context.');
    const tokenizer = await BertWordPieceTokenizer.fromRawfile(this.context);
    return await BgeMindSporeEmbeddingPort.fromRawfile(this.context, tokenizer);
  }

  private withTimeout<T>(task: Promise<T>): Promise<T> {
    const timeoutMs = Math.max(1, this.options.recallTimeoutMs ?? PHONE_LOCAL_MEMORY_RECALL_TIMEOUT_MS);
    return new Promise<T>((resolve: (value: T) => void, reject: (reason: Error) => void): void => {
      const timerId = setTimeout((): void => reject(new Error('Phone-local memory recall timed out.')), timeoutMs);
      task.then((value: T): void => {
        clearTimeout(timerId);
        resolve(value);
      }, (error: Object): void => {
        clearTimeout(timerId);
        reject(error instanceof Error ? error : new Error('Phone-local memory recall failed.'));
      });
    });
  }

  private log(code: string, operation: string, error: Object): void {
    this.logger.warn(code, operation, boundedRuntimeError(error));
  }
}
