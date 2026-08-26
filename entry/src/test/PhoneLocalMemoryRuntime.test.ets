import { describe, expect, it } from '@ohos/hypium';
import { EmbeddingPort, MemoryCommitGuard, MemoryHit, MemoryRecord } from '@loop/agent-core';
import {
  PHONE_LOCAL_MEMORY_OWNER_ID,
  PhoneLocalMemoryRuntime,
  PhoneLocalMemoryRuntimeLogger
} from '../main/ets/memory/PhoneLocalMemoryRuntime';
import {
  PHONE_LOCAL_MEMORY_OPERATION_CANCELED,
  PhoneLocalMemorySearchRequest,
  PhoneLocalMemoryStore
} from '../main/ets/memory/PhoneLocalMemoryStore';
import {
  PhoneLocalMemoryBackendId,
  PhoneLocalMemoryBackendRegistryPort
} from '../main/ets/memory/PhoneLocalMemoryBackendRegistry';

function copyRuntimeRecord(record: MemoryRecord): MemoryRecord {
  return {
    memoryId: record.memoryId,
    ownerId: record.ownerId,
    sceneId: record.sceneId,
    personaTag: record.personaTag,
    authority: record.authority,
    fact: record.fact,
    normalizedFact: record.normalizedFact,
    factHash: record.factHash,
    embedding: record.embedding.slice(),
    embeddingProfileId: record.embeddingProfileId,
    sourceTurnId: record.sourceTurnId,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt
  };
}

class RuntimeEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'bge-small-zh-v1.5:runtime-test';
  readonly dimension: number = 512;

  async embed(_text: string): Promise<number[]> {
    const vector: number[] = new Array<number>(this.dimension).fill(0);
    vector[0] = 1;
    return vector;
  }
}

class MissingRuntimeEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'bge-small-zh-v1.5:runtime-test';
  readonly dimension: number = 512;

  async embed(_text: string): Promise<number[]> {
    throw new Error('missing model secret path');
  }
}

class RuntimeLogger implements PhoneLocalMemoryRuntimeLogger {
  messages: string[] = [];

  warn(code: string, operation: string, errorMessage: string): void {
    this.messages.push(code + ':' + operation + ':' + errorMessage);
  }
}

class RuntimeCommitGuard implements MemoryCommitGuard {
  active: boolean = true;

  isActive(): boolean {
    return this.active;
  }
}

function requireRuntimeCommit(guard?: MemoryCommitGuard): void {
  if (guard !== undefined && !guard.isActive()) {
    throw new Error(PHONE_LOCAL_MEMORY_OPERATION_CANCELED);
  }
}

class RuntimeMemoryStore implements PhoneLocalMemoryStore {
  records: MemoryRecord[] = [];
  metadata: Map<string, string> = new Map<string, string>();

  async initialize(): Promise<void> {}

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId === ownerId && record.embeddingProfileId === embeddingProfileId &&
        record.factHash === factHash && record.normalizedFact === normalizedFact) {
        return copyRuntimeRecord(record);
      }
    }
    return null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === memoryId) {
        return copyRuntimeRecord(this.records[index]);
      }
    }
    return null;
  }

  async list(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const output: MemoryRecord[] = [];
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId !== ownerId) continue;
      if (sceneIds.length > 0 && sceneIds.indexOf(record.sceneId) < 0) continue;
      output.push(copyRuntimeRecord(record));
    }
    return output;
  }

  async search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    const records = await this.list(request.ownerId, request.sceneIds);
    const output: MemoryHit[] = [];
    for (let index = records.length - 1; index >= 0 && output.length < request.topK; index -= 1) {
      if (records[index].embeddingProfileId === request.embeddingProfileId) {
        output.push({ record: records[index], score: 1 });
      }
    }
    return output;
  }

  async insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    requireRuntimeCommit(guard);
    const duplicate = await this.findByFact(
      record.ownerId, record.embeddingProfileId, record.factHash, record.normalizedFact
    );
    if (duplicate !== null) throw new Error('duplicate');
    this.records.push(copyRuntimeRecord(record));
  }

  async replace(ownerId: string, record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    requireRuntimeCommit(guard);
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === record.memoryId) {
        this.records[index] = copyRuntimeRecord(record);
        return;
      }
    }
    throw new Error('not found');
  }

  async remove(ownerId: string, memoryId: string,
    guard?: MemoryCommitGuard): Promise<MemoryRecord | null> {
    requireRuntimeCommit(guard);
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === memoryId) {
        const record = this.records[index];
        this.records.splice(index, 1);
        return copyRuntimeRecord(record);
      }
    }
    return null;
  }

  async removeAll(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const existing = await this.list(ownerId, sceneIds);
    for (let index = 0; index < existing.length; index += 1) {
      await this.remove(ownerId, existing[index].memoryId);
    }
    return existing;
  }

  async getMetadata(key: string): Promise<string | null> {
    return this.metadata.get(key) ?? null;
  }

  async setMetadata(key: string, value: string): Promise<void> {
    this.metadata.set(key, value);
  }
}

class RuntimeBackendRegistry implements PhoneLocalMemoryBackendRegistryPort {
  selected: PhoneLocalMemoryBackendId | null;
  writes: PhoneLocalMemoryBackendId[] = [];

  constructor(selected: PhoneLocalMemoryBackendId | null = null) {
    this.selected = selected;
  }

  async getSelectedBackend(): Promise<PhoneLocalMemoryBackendId | null> {
    return this.selected;
  }

  async setSelectedBackend(backendId: PhoneLocalMemoryBackendId): Promise<void> {
    this.selected = backendId;
    this.writes.push(backendId);
  }
}

class InitializationFailureStore extends RuntimeMemoryStore {
  async initialize(): Promise<void> {
    throw new Error('private-vector-initialization-detail');
  }
}

class ProbeFailureStore extends RuntimeMemoryStore {
  searchCalls: number = 0;

  async search(_request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    this.searchCalls += 1;
    throw new Error('private-vector-probe-detail');
  }
}

class TransientSearchFailureStore extends RuntimeMemoryStore {
  searchCalls: number = 0;

  async search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    this.searchCalls += 1;
    if (this.searchCalls > 1) throw new Error('transient-search-failure');
    return await super.search(request);
  }
}

function repeatedRuntimeCharacter(character: string, count: number): string {
  let output = '';
  for (let index = 0; index < count; index += 1) output += character;
  return output;
}

let runtimeMemoryIdSequence: number = 0;

function nextRuntimeMemoryId(): string {
  runtimeMemoryIdSequence += 1;
  return 'runtime-memory-' + runtimeMemoryIdSequence.toString();
}

export default function phoneLocalMemoryRuntimeTest() {
  describe('PhoneLocalMemoryRuntime', () => {
    it('starts empty and does not write fixed facts or seed metadata across restart', 0, async () => {
      const store = new RuntimeMemoryStore();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });
      const hits = await runtime.recall('工作邮件和晚间足球');
      expect(hits.length).assertEqual(0);
      expect(store.records.length).assertEqual(0);
      expect(store.metadata.size).assertEqual(0);

      const restarted = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });
      const restartedHits = await restarted.recall('饮品');
      expect(restartedHits.length).assertEqual(0);
      expect(store.records.length).assertEqual(0);
      expect(store.metadata.size).assertEqual(0);
    });

    it('writes leader facts globally and bounds the recalled projection', 0, async () => {
      const store = new RuntimeMemoryStore();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });
      await runtime.recall('initialize');
      const facts: string[] = [];
      for (let index = 0; index < 5; index += 1) {
        facts.push('偏好' + index.toString() + repeatedRuntimeCharacter('x', 230));
      }
      const written = await runtime.remember(facts, 'turn-runtime-1', 'work_companion');
      // Simulate legacy/corrupt overlong rows to verify the projection boundary independently
      // of the write validator.
      for (let index = store.records.length - 5; index < store.records.length; index += 1) {
        store.records[index].fact = repeatedRuntimeCharacter('长', 300);
      }
      const hits = await runtime.recall('偏好');
      let factCharacters = 0;
      for (let index = 0; index < hits.length; index += 1) factCharacters += hits[index].fact.length;

      expect(written.status).assertEqual('success');
      expect(hits.length).assertEqual(5);
      expect(factCharacters).assertEqual(1200);
      expect(hits[0].fact.length).assertEqual(240);
      expect(hits[0].personaTag).assertEqual('work_companion');
      expect(hits[0].authority).assertEqual('leader');
      expect(store.records[store.records.length - 1].sceneId).assertEqual('global');
    });

    it('uses explicit recall topK bounds and scales the bounded projection past five items', 0, async () => {
      const store = new RuntimeMemoryStore();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });
      await runtime.recall('initialize');
      const facts: string[] = [];
      for (let index = 0; index < 20; index += 1) {
        facts.push('召回边界偏好 ' + index.toString());
      }
      for (let offset = 0; offset < facts.length; offset += 5) {
        await runtime.remember(
          facts.slice(offset, offset + 5),
          'turn-runtime-top-k-' + offset.toString(),
          'work_companion'
        );
      }

      const defaultHits = await runtime.recall('召回边界偏好');
      const oneHit = await runtime.recall('召回边界偏好', 1);
      const tenHits = await runtime.recall('召回边界偏好', 10);
      const twentyHits = await runtime.recall('召回边界偏好', 20);

      expect(defaultHits.length).assertEqual(5);
      expect(oneHit.length).assertEqual(1);
      expect(tenHits.length).assertEqual(10);
      expect(twentyHits.length).assertEqual(20);
    });

    it('times out recall without exposing the query or retrying inside the turn', 0, async () => {
      const store = new RuntimeMemoryStore();
      const logger = new RuntimeLogger();
      let factoryCalls = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: (): Promise<EmbeddingPort> => {
          factoryCalls += 1;
          return new Promise<EmbeddingPort>((_resolve: (value: EmbeddingPort) => void): void => {});
        },
        idFactory: nextRuntimeMemoryId,
        recallTimeoutMs: 5,
        logger
      });
      const query = 'timeout private query';
      const hits = await runtime.recall(query);

      expect(hits.length).assertEqual(0);
      expect(factoryCalls).assertEqual(1);
      expect(logger.messages.length).assertEqual(1);
      expect(logger.messages[0].indexOf(query)).assertEqual(-1);
    });

    it('fails recall open but reports mutation failure when the model is unavailable', 0, async () => {
      const store = new RuntimeMemoryStore();
      const logger = new RuntimeLogger();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new MissingRuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId,
        logger
      });
      const query = 'private recall query';
      const hits = await runtime.recall(query);
      const mutation = await runtime.remember(['用户偏好简洁回复。'], 'turn-runtime-2', 'work_companion');

      expect(hits.length).assertEqual(0);
      expect(mutation.status).assertEqual('error');
      expect(logger.messages.length).assertEqual(0);
    });

    it('selects and caches the BLOB backend when vector initialization fails', 0, async () => {
      const blobStore = new RuntimeMemoryStore();
      const registry = new RuntimeBackendRegistry();
      const logger = new RuntimeLogger();
      let vectorFactories = 0;
      let blobFactories = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => {
          vectorFactories += 1;
          return new InitializationFailureStore();
        },
        blobStoreFactory: (): PhoneLocalMemoryStore => {
          blobFactories += 1;
          return blobStore;
        },
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId,
        logger
      });

      await runtime.recall('first');
      await runtime.recall('second');

      expect(vectorFactories).assertEqual(1);
      expect(blobFactories).assertEqual(1);
      expect(registry.selected ?? '').assertEqual('blob');
      expect(blobStore.records.length).assertEqual(0);
      expect(blobStore.metadata.size).assertEqual(0);
      expect(logger.messages.join('|')).assertContain('memory_vector_backend_unavailable');
    });

    it('falls back after a vector capability probe failure', 0, async () => {
      const vectorStore = new ProbeFailureStore();
      const blobStore = new RuntimeMemoryStore();
      const registry = new RuntimeBackendRegistry();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => vectorStore,
        blobStoreFactory: (): PhoneLocalMemoryStore => blobStore,
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });

      await runtime.recall('probe fallback');
      expect(vectorStore.searchCalls).assertEqual(1);
      expect(registry.selected ?? '').assertEqual('blob');
      expect(blobStore.records.length).assertEqual(0);
      expect(blobStore.metadata.size).assertEqual(0);
    });

    it('keeps a previously selected BLOB backend sticky when vector is available again', 0, async () => {
      const blobStore = new RuntimeMemoryStore();
      const registry = new RuntimeBackendRegistry('blob');
      let vectorFactories = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => {
          vectorFactories += 1;
          return new RuntimeMemoryStore();
        },
        blobStoreFactory: (): PhoneLocalMemoryStore => blobStore,
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });

      await runtime.recall('sticky blob');
      expect(vectorFactories).assertEqual(0);
      expect(registry.selected ?? '').assertEqual('blob');
      expect(blobStore.records.length).assertEqual(0);
      expect(blobStore.metadata.size).assertEqual(0);
    });

    it('detects an unmigrated backend change without manufacturing memory records', 0, async () => {
      const blobStore = new RuntimeMemoryStore();
      const registry = new RuntimeBackendRegistry('vector');
      const logger = new RuntimeLogger();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => new InitializationFailureStore(),
        blobStoreFactory: (): PhoneLocalMemoryStore => blobStore,
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId,
        logger
      });

      await runtime.recall('changed backend');
      const restarted = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => new InitializationFailureStore(),
        blobStoreFactory: (): PhoneLocalMemoryStore => blobStore,
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId,
        logger
      });
      await restarted.recall('changed backend restart');
      expect(blobStore.records.length).assertEqual(0);
      expect(blobStore.metadata.size).assertEqual(0);
      expect(registry.selected ?? '').assertEqual('blob');
      expect(logger.messages.join('|')).assertContain('memory_backend_changed_data_not_migrated');
    });

    it('does not switch or instantiate BLOB after a transient vector search failure', 0, async () => {
      const vectorStore = new TransientSearchFailureStore();
      const registry = new RuntimeBackendRegistry();
      let blobFactories = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        vectorStoreFactory: (): PhoneLocalMemoryStore => vectorStore,
        blobStoreFactory: (): PhoneLocalMemoryStore => {
          blobFactories += 1;
          return new RuntimeMemoryStore();
        },
        backendRegistryFactory: (): PhoneLocalMemoryBackendRegistryPort => registry,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: nextRuntimeMemoryId
      });

      const hits = await runtime.recall('transient');
      expect(hits.length).assertEqual(0);
      expect(vectorStore.searchCalls).assertEqual(2);
      expect(blobFactories).assertEqual(0);
      expect(registry.selected ?? '').assertEqual('vector');
    });

    it('forwards the commit guard through remember update and forget', 0, async () => {
      const store = new RuntimeMemoryStore();
      let nextId = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new RuntimeEmbeddingPort(),
        idFactory: (): string => 'runtime-guard-memory-' + (++nextId).toString()
      });
      await runtime.recall('initialize');
      const activeGuard = new RuntimeCommitGuard();
      const added = await runtime.remember(
        ['用户偏好先给结论。'], 'turn-runtime-guard-1', 'work_companion', activeGuard
      );
      const memoryId = added.records[0].record?.memoryId ?? '';
      expect(added.status).assertEqual('success');
      expect(memoryId.length > 0).assertTrue();
      const beforeCount = store.records.length;
      const canceledGuard = new RuntimeCommitGuard();
      canceledGuard.active = false;

      const remembered = await runtime.remember(
        ['这条取消后的事实不能落库。'], 'turn-runtime-guard-2', 'work_companion', canceledGuard
      );
      const updated = await runtime.update(
        memoryId, '用户偏好详细说明。', 'turn-runtime-guard-3', 'work_companion', canceledGuard
      );
      const forgotten = await runtime.forget(memoryId, canceledGuard);

      expect(remembered.error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(updated.error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(forgotten.error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(store.records.length).assertEqual(beforeCount);
      expect((await store.get(PHONE_LOCAL_MEMORY_OWNER_ID, memoryId))?.fact ?? '')
        .assertEqual('用户偏好先给结论。');
    });
  });
}
