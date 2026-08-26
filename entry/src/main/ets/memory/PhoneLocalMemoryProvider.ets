import util from '@ohos.util';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  buildBestEffortMemoryBatchResult,
  ConversationMemoryPort,
  EmbeddingPort,
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryDraft,
  MemoryError,
  MemoryHit,
  MemoryQuery,
  MemoryRecord,
  MemoryRememberRequest,
  MemoryUpdateRequest,
  MemoryWriteResult,
  MEMORY_RECALL_MAX_TOP_K,
  normalizeMemoryFact,
  normalizedMemoryFactHash,
  validateMemoryDraftBatch
} from '@loop/agent-core';
import {
  phoneLocalMemoryOperationCanceled,
  PhoneLocalMemoryStore,
  PHONE_LOCAL_MEMORY_VECTOR_DIMENSION
} from './PhoneLocalMemoryStore';

const DEFAULT_MEMORY_MAX_FACT_LENGTH: number = 240;

const MEMORY_LOG_DOMAIN: number = 0x0000;
const MEMORY_LOG_TAG: string = 'PhoneMemory';
const MEMORY_LOG_MESSAGE_LIMIT: number = 160;

export interface PhoneLocalMemoryLogContext {
  code: string;
  operation: string;
  inputIndex: number;
  errorMessage: string;
}

export interface PhoneLocalMemoryLogger {
  warn(context: PhoneLocalMemoryLogContext): void;
}

export interface PhoneLocalMemoryProviderOptions {
  allowedSceneIds?: string[];
  maxFactLength?: number;
  clock?: () => number;
  idFactory?: () => string;
  logger?: PhoneLocalMemoryLogger;
}

function memoryError(code: string, message: string, retryable: boolean = false): MemoryError {
  return { code, message, retryable };
}

function failedWrite(inputIndex: number, error: MemoryError): MemoryWriteResult {
  return { inputIndex, status: 'error', error };
}

function successfulWrite(inputIndex: number, record: MemoryRecord): MemoryWriteResult {
  return { inputIndex, status: 'success', record };
}

function commitIsActive(guard?: MemoryCommitGuard): boolean {
  if (guard === undefined) return true;
  try {
    return guard.isActive();
  } catch (_error) {
    return false;
  }
}

function canceledWrite(inputIndex: number): MemoryWriteResult {
  return failedWrite(inputIndex, memoryError(
    'memory_operation_canceled', 'Memory operation was canceled before local commit.'
  ));
}

class HilogPhoneLocalMemoryLogger implements PhoneLocalMemoryLogger {
  warn(context: PhoneLocalMemoryLogContext): void {
    hilog.warn(MEMORY_LOG_DOMAIN, MEMORY_LOG_TAG,
      'code=%{public}s operation=%{public}s inputIndex=%{public}d error=%{public}s',
      context.code, context.operation, context.inputIndex, context.errorMessage);
  }
}

function boundedErrorMessage(error: Object, secret: string = ''): string {
  let message = error instanceof Error ? error.message : 'Unknown local memory failure.';
  if (secret.length > 0) message = message.split(secret).join('[redacted]');
  message = message.replace(/[\r\n\t]+/g, ' ').trim();
  if (message.length === 0) return 'Unknown local memory failure.';
  return message.substring(0, MEMORY_LOG_MESSAGE_LIMIT);
}

function normalizedVector(values: number[], expectedDimension: number): number[] {
  if (values.length !== expectedDimension) {
    throw new Error('Embedding dimension mismatch');
  }
  let squaredNorm = 0;
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!Number.isFinite(value)) throw new Error('Embedding contains a non-finite value');
    squaredNorm += value * value;
  }
  if (squaredNorm <= 0) throw new Error('Embedding has zero norm');
  const norm = Math.sqrt(squaredNorm);
  const output: number[] = [];
  for (let index = 0; index < values.length; index += 1) output.push(values[index] / norm);
  return output;
}

function invalidBatchResult(request: MemoryRememberRequest, message: string): MemoryBatchResult {
  const error = memoryError('memory_request_invalid', message);
  const records: MemoryWriteResult[] = [];
  const count = Math.max(1, request.records.length);
  for (let index = 0; index < count; index += 1) records.push(failedWrite(index, error));
  return buildBestEffortMemoryBatchResult(records);
}

export class PhoneLocalMemoryProvider implements ConversationMemoryPort {
  private store: PhoneLocalMemoryStore;
  private embedder: EmbeddingPort;
  private allowedSceneIds: string[];
  private maxFactLength: number;
  private clock: () => number;
  private idFactory: () => string;
  private logger?: PhoneLocalMemoryLogger;

  constructor(store: PhoneLocalMemoryStore, embedder: EmbeddingPort,
    options: PhoneLocalMemoryProviderOptions = {}) {
    if (embedder.dimension !== PHONE_LOCAL_MEMORY_VECTOR_DIMENSION) {
      throw new Error('Phone-local memory requires a 512-dimensional embedding profile');
    }
    this.store = store;
    this.embedder = embedder;
    this.allowedSceneIds = options.allowedSceneIds?.slice() ?? [];
    this.maxFactLength = options.maxFactLength ?? DEFAULT_MEMORY_MAX_FACT_LENGTH;
    this.clock = options.clock ?? (() => Date.now());
    this.idFactory = options.idFactory ?? (() => util.generateRandomUUID(false));
    this.logger = options.logger ?? new HilogPhoneLocalMemoryLogger();
  }

  async remember(request: MemoryRememberRequest, guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    const ownerId = request.ownerId.trim();
    if (ownerId.length === 0) {
      return invalidBatchResult(request, 'Memory ownerId must not be empty.');
    }
    if (request.records.length < 1 || request.records.length > 5) {
      return invalidBatchResult(request, 'A remember action must contain between 1 and 5 memory records.');
    }
    const results: MemoryWriteResult[] = [];
    for (let index = 0; index < request.records.length; index += 1) {
      if (!commitIsActive(guard)) {
        results.push(canceledWrite(index));
        continue;
      }
      const validation = validateMemoryDraftBatch([request.records[index]], {
        allowedSceneIds: this.allowedSceneIds,
        maxFactLength: this.maxFactLength
      });
      if (!validation.valid) {
        results.push(failedWrite(index, memoryError(
          'memory_request_invalid', validation.issues[0].message
        )));
        continue;
      }
      results.push(await this.rememberOne(ownerId, validation.records[0], index, guard));
    }
    return buildBestEffortMemoryBatchResult(results);
  }

  private async rememberOne(ownerId: string, draft: MemoryDraft, inputIndex: number,
    guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    const normalizedFact = normalizeMemoryFact(draft.fact);
    const factHash = normalizedMemoryFactHash(draft.fact);
    try {
      const duplicate = await this.store.findByFact(
        ownerId, this.embedder.profileId, factHash, normalizedFact
      );
      if (duplicate !== null) return successfulWrite(inputIndex, duplicate);
      const embedding = normalizedVector(await this.embedder.embed(draft.fact), this.embedder.dimension);
      if (!commitIsActive(guard)) return canceledWrite(inputIndex);
      const now = this.clock();
      const memoryId = this.idFactory().trim();
      if (memoryId.length === 0 || memoryId.length > 128) {
        throw new Error('Memory id factory returned an invalid identifier');
      }
      const record: MemoryRecord = {
        memoryId,
        ownerId,
        sceneId: draft.sceneId,
        personaTag: draft.personaTag ?? draft.sceneId,
        authority: draft.authority ?? 'leader',
        fact: draft.fact,
        normalizedFact,
        factHash,
        embedding,
        embeddingProfileId: this.embedder.profileId,
        sourceTurnId: draft.sourceTurnId,
        createdAt: now,
        updatedAt: now
      };
      await this.store.insert(record, guard);
      return successfulWrite(inputIndex, record);
    } catch (error) {
      if (phoneLocalMemoryOperationCanceled(error)) {
        this.log('memory_operation_canceled', 'remember', inputIndex,
          'Memory operation was canceled before local commit.');
        return canceledWrite(inputIndex);
      }
      try {
        const duplicate = await this.store.findByFact(
          ownerId, this.embedder.profileId, factHash, normalizedFact
        );
        if (duplicate !== null) return successfulWrite(inputIndex, duplicate);
      } catch (lookupError) {
        this.log('memory_dedupe_read_failed', 'remember', inputIndex,
          boundedErrorMessage(lookupError, draft.fact));
      }
      this.log('memory_write_failed', 'remember', inputIndex, boundedErrorMessage(error, draft.fact));
      return failedWrite(inputIndex, memoryError(
        'memory_write_failed', 'One memory record could not be saved.', true
      ));
    }
  }

  async search(query: MemoryQuery): Promise<MemoryHit[]> {
    const ownerId = query.ownerId.trim();
    const text = query.text.trim();
    if (ownerId.length === 0 || text.length === 0 || query.topK <= 0) return [];
    try {
      const queryEmbedding = normalizedVector(
        await this.embedder.embed(text), this.embedder.dimension
      );
      const normalizedQuery: MemoryQuery = {
        ownerId,
        text,
        sceneIds: query.sceneIds.slice(),
        topK: Math.min(MEMORY_RECALL_MAX_TOP_K, Math.max(1, Math.floor(query.topK)))
      };
      if (query.minScore !== undefined) normalizedQuery.minScore = query.minScore;
      return await this.store.search({
        ownerId: normalizedQuery.ownerId,
        sceneIds: normalizedQuery.sceneIds,
        embeddingProfileId: this.embedder.profileId,
        queryEmbedding,
        topK: normalizedQuery.topK,
        minScore: normalizedQuery.minScore
      });
    } catch (error) {
      this.log('memory_search_failed', 'search', -1, boundedErrorMessage(error, query.text));
      return [];
    }
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    if (ownerId.trim().length === 0 || memoryId.trim().length === 0) return null;
    try {
      return await this.store.get(ownerId.trim(), memoryId.trim());
    } catch (error) {
      this.log('memory_read_failed', 'get', -1, boundedErrorMessage(error));
      return null;
    }
  }

  async update(request: MemoryUpdateRequest, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    const ownerId = request.ownerId.trim();
    const existing = await this.get(ownerId, request.memoryId);
    if (existing === null) {
      return failedWrite(0, memoryError('memory_not_found', 'Memory record was not found.'));
    }
    const validation = validateMemoryDraftBatch([{
      fact: request.fact,
      sceneId: existing.sceneId,
      personaTag: request.personaTag ?? existing.personaTag,
      authority: request.authority ?? existing.authority,
      sourceTurnId: request.sourceTurnId
    }], {
      allowedSceneIds: this.allowedSceneIds,
      maxFactLength: this.maxFactLength
    });
    if (!validation.valid) {
      return failedWrite(0, memoryError('memory_request_invalid', validation.issues[0].message));
    }
    try {
      const fact = validation.records[0].fact;
      const embedding = normalizedVector(await this.embedder.embed(fact), this.embedder.dimension);
      if (!commitIsActive(guard)) return canceledWrite(0);
      const updated: MemoryRecord = {
        memoryId: existing.memoryId,
        ownerId: existing.ownerId,
        sceneId: existing.sceneId,
        personaTag: validation.records[0].personaTag ?? existing.personaTag,
        authority: validation.records[0].authority ?? existing.authority,
        fact,
        normalizedFact: normalizeMemoryFact(fact),
        factHash: normalizedMemoryFactHash(fact),
        embedding,
        embeddingProfileId: this.embedder.profileId,
        sourceTurnId: request.sourceTurnId,
        createdAt: existing.createdAt,
        updatedAt: this.clock()
      };
      await this.store.replace(ownerId, updated, guard);
      return successfulWrite(0, updated);
    } catch (error) {
      if (phoneLocalMemoryOperationCanceled(error)) {
        this.log('memory_operation_canceled', 'update', 0,
          'Memory operation was canceled before local commit.');
        return canceledWrite(0);
      }
      this.log('memory_update_failed', 'update', 0, boundedErrorMessage(error, request.fact));
      return failedWrite(0, memoryError('memory_update_failed', 'Memory record could not be updated.', true));
    }
  }

  async forget(ownerId: string, memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    if (ownerId.trim().length === 0 || memoryId.trim().length === 0) {
      return failedWrite(0, memoryError('memory_request_invalid', 'Memory owner and id must not be empty.'));
    }
    try {
      if (!commitIsActive(guard)) return canceledWrite(0);
      const deleted = await this.store.remove(ownerId.trim(), memoryId.trim(), guard);
      if (deleted === null) {
        return failedWrite(0, memoryError('memory_not_found', 'Memory record was not found.'));
      }
      return successfulWrite(0, deleted);
    } catch (error) {
      if (phoneLocalMemoryOperationCanceled(error)) {
        this.log('memory_operation_canceled', 'forget', 0,
          'Memory operation was canceled before local commit.');
        return canceledWrite(0);
      }
      this.log('memory_delete_failed', 'forget', 0, boundedErrorMessage(error));
      return failedWrite(0, memoryError('memory_delete_failed', 'Memory record could not be deleted.', true));
    }
  }

  async forgetAll(ownerId: string, sceneIds: string[] = [],
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    if (ownerId.trim().length === 0) {
      return invalidBatchResult({ ownerId, records: [] }, 'Memory ownerId must not be empty.');
    }
    let existing: MemoryRecord[];
    try {
      existing = await this.store.list(ownerId.trim(), sceneIds);
    } catch (error) {
      this.log('memory_read_failed', 'forgetAll', -1, boundedErrorMessage(error));
      return invalidBatchResult({ ownerId, records: [] }, 'Memory records could not be loaded.');
    }
    if (existing.length === 0) {
      return {
        status: 'success', records: [], succeededCount: 0, failedCount: 0, warnings: []
      };
    }
    const results: MemoryWriteResult[] = [];
    for (let index = 0; index < existing.length; index += 1) {
      const result = await this.forget(ownerId.trim(), existing[index].memoryId, guard);
      result.inputIndex = index;
      results.push(result);
    }
    return buildBestEffortMemoryBatchResult(results);
  }

  private log(code: string, operation: string, inputIndex: number, errorMessage: string): void {
    if (this.logger !== undefined) this.logger.warn({ code, operation, inputIndex, errorMessage });
  }
}
