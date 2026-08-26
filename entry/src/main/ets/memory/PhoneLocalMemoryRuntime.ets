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
  MemoryWriteResult,
  MEMORY_RECALL_DEFAULT_TOP_K,
  MEMORY_RECALL_FACT_MAX_CHARS,
  MEMORY_RECALL_MAX_TOP_K,
  memoryRecallTotalMaxChars,
  validMemoryRecallTopK
} from '@loop/agent-core';
import { BertWordPieceTokenizer } from './BertWordPieceTokenizer';
import { BgeMindSporeEmbeddingPort } from './BgeMindSporeEmbeddingPort';
import { PhoneLocalMemoryProvider } from './PhoneLocalMemoryProvider';
import { ArkDataPhoneLocalMemoryStore, PhoneLocalMemoryStore } from './PhoneLocalMemoryStore';
import { ArkDataPhoneLocalMemoryBlobStore } from './PhoneLocalMemoryBlobFallbackPort';
import {
  ArkDataPhoneLocalMemoryBackendRegistry,
  PhoneLocalMemoryBackendId,
  PhoneLocalMemoryBackendRegistryPort
} from './PhoneLocalMemoryBackendRegistry';

export const PHONE_LOCAL_MEMORY_OWNER_ID: string = 'local-user-v1';
export const PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID: string = 'global';
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

export interface PhoneLocalMemoryRuntimeLogger {
  warn(code: string, operation: string, errorMessage: string): void;
}

export interface PhoneLocalMemoryRuntimeOptions {
  /** Explicit single-store injection retained for unit tests and embedders. It bypasses backend selection. */
  storeFactory?: () => PhoneLocalMemoryStore;
  vectorStoreFactory?: () => PhoneLocalMemoryStore;
  blobStoreFactory?: () => PhoneLocalMemoryStore;
  backendRegistryFactory?: () => PhoneLocalMemoryBackendRegistryPort;
  embedderFactory?: () => Promise<EmbeddingPort>;
  idFactory?: () => string;
  recallTimeoutMs?: number;
  logger?: PhoneLocalMemoryRuntimeLogger;
}

interface SelectedMemoryStore {
  store: PhoneLocalMemoryStore;
}

export interface PhoneLocalMemoryRuntimePort {
  recall(text: string, topK?: number): Promise<PhoneLocalRecalledMemory[]>;
  remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
  update(memoryId: string, fact: string, sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;
  forget(memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;
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

/**
 * Application-lifetime composition root for phone-local memory.
 * Recall is fail-open; mutations surface initialization/model/storage failures to the caller.
 */
export class PhoneLocalMemoryRuntime implements PhoneLocalMemoryRuntimePort {
  private context: common.Context | null;
  private options: PhoneLocalMemoryRuntimeOptions;
  private providerPromise: Promise<PhoneLocalMemoryProvider> | null = null;
  private logger: PhoneLocalMemoryRuntimeLogger;

  constructor(context: common.Context | null, options: PhoneLocalMemoryRuntimeOptions = {}) {
    this.context = context;
    this.options = options;
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
      return await provider.remember({ ownerId: PHONE_LOCAL_MEMORY_OWNER_ID, records }, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'remember', error);
      return unavailableBatch(facts.length, runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async update(memoryId: string, fact: string, sourceTurnId: string,
    personaTag: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    try {
      const provider = await this.provider();
      return await provider.update({
        ownerId: PHONE_LOCAL_MEMORY_OWNER_ID,
        memoryId,
        fact,
        personaTag: personaTag.length > 0 ? personaTag : PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        authority: 'leader',
        sourceTurnId
      }, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'update', error);
      return unavailableWrite(runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  async forget(memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult> {
    try {
      const provider = await this.provider();
      return await provider.forget(PHONE_LOCAL_MEMORY_OWNER_ID, memoryId, guard);
    } catch (error) {
      this.log('memory_runtime_unavailable', 'forget', error);
      return unavailableWrite(runtimeMemoryError(
        'memory_runtime_unavailable', 'Long-term memory is unavailable on this device.', true
      ));
    }
  }

  private provider(): Promise<PhoneLocalMemoryProvider> {
    if (this.providerPromise === null) this.providerPromise = this.createProvider();
    return this.providerPromise;
  }

  private async createProvider(): Promise<PhoneLocalMemoryProvider> {
    const selected = await this.selectStore();
    const store = selected.store;
    const embedder = this.options.embedderFactory !== undefined ?
      await this.options.embedderFactory() : await this.createDefaultEmbedder();
    // The runtime wrapper fixes every new write to global. Keep the provider compatible with
    // legacy records in another scene so an exact-id update/forget can still complete.
    return new PhoneLocalMemoryProvider(store, embedder, {
      idFactory: this.options.idFactory
    });
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
      ownerId: PHONE_LOCAL_MEMORY_OWNER_ID,
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
