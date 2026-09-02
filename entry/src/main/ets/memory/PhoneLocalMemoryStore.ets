import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import util from '@ohos.util';
import { MemoryAuthority, MemoryCommitGuard, MemoryHit, MemoryRecord } from '@loop/agent-core';

export const PHONE_LOCAL_MEMORY_VECTOR_DB_NAME: string = 'pocketagent_conversation_memory_vector_v2.db';
export const PHONE_LOCAL_MEMORY_TABLE: string = 'conversation_memory';
export const PHONE_LOCAL_MEMORY_HISTORY_TABLE: string = 'conversation_memory_history';
export const PHONE_LOCAL_MEMORY_METADATA_TABLE: string = 'conversation_memory_metadata';
export const PHONE_LOCAL_MEMORY_SCHEMA_VERSION_KEY: string = 'schema_version';
export const PHONE_LOCAL_MEMORY_SCHEMA_VERSION: string = '2';
export const PHONE_LOCAL_MEMORY_VECTOR_DIMENSION: number = 512;
export const PHONE_LOCAL_MEMORY_MIN_CANDIDATE_LIMIT: number = 100;
export const PHONE_LOCAL_MEMORY_MAX_CANDIDATE_LIMIT: number = 1000;
export const PHONE_LOCAL_MEMORY_OPERATION_CANCELED: string = 'memory_operation_canceled';

export const PHONE_LOCAL_MEMORY_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory (' +
    'memory_id TEXT PRIMARY KEY, ' +
    'owner_id TEXT NOT NULL, ' +
    'scene_id TEXT NOT NULL, ' +
    'persona_tag TEXT NOT NULL, ' +
    'authority TEXT NOT NULL, ' +
    'fact TEXT NOT NULL, ' +
    'normalized_fact TEXT NOT NULL, ' +
    'fact_hash TEXT NOT NULL, ' +
    'embedding FLOATVECTOR(512) NOT NULL, ' +
    'embedding_profile_id TEXT NOT NULL, ' +
    'source_turn_id TEXT NOT NULL, ' +
    'created_at INTEGER NOT NULL, ' +
    'updated_at INTEGER NOT NULL' +
  ')';

export const PHONE_LOCAL_MEMORY_HISTORY_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_history (' +
    'history_id TEXT PRIMARY KEY, ' +
    'memory_id TEXT NOT NULL, ' +
    'owner_id TEXT NOT NULL, ' +
    'scene_id TEXT NOT NULL, ' +
    'operation TEXT NOT NULL, ' +
    'fact TEXT NOT NULL, ' +
    'created_at INTEGER NOT NULL' +
  ')';

export const PHONE_LOCAL_MEMORY_METADATA_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_metadata (' +
    'metadata_key TEXT PRIMARY KEY, ' +
    'metadata_value TEXT NOT NULL, ' +
    'updated_at INTEGER NOT NULL' +
  ')';

export const PHONE_LOCAL_MEMORY_DEDUPE_INDEX_SQL: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_memory_dedupe ' +
  'ON conversation_memory(owner_id, embedding_profile_id, fact_hash, normalized_fact)';

export const PHONE_LOCAL_MEMORY_SCOPE_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_conversation_memory_scope ' +
  'ON conversation_memory(owner_id, scene_id, updated_at)';

export const PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_conversation_memory_embedding_cosine ' +
  'ON conversation_memory USING GSDISKANN(embedding COSINE) ' +
  'WITH (queue_size=20, out_degree=60)';

export const PHONE_LOCAL_MEMORY_DELETE_HISTORY_SQL: string =
  'DELETE FROM conversation_memory_history WHERE owner_id = ? AND memory_id = ?';

export const PHONE_LOCAL_MEMORY_INSERT_SQL: string =
  'INSERT INTO conversation_memory (' +
    'memory_id, owner_id, scene_id, persona_tag, authority, fact, normalized_fact, fact_hash, embedding, ' +
    'embedding_profile_id, source_turn_id, created_at, updated_at' +
  ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

export const PHONE_LOCAL_MEMORY_UPDATE_SQL: string =
  'UPDATE conversation_memory SET scene_id = ?, persona_tag = ?, authority = ?, ' +
  'fact = ?, normalized_fact = ?, fact_hash = ?, ' +
  'embedding = ?, embedding_profile_id = ?, source_turn_id = ?, updated_at = ? ' +
  'WHERE owner_id = ? AND memory_id = ?';

export const PHONE_LOCAL_MEMORY_DELETE_SQL: string =
  'DELETE FROM conversation_memory WHERE owner_id = ? AND memory_id = ?';

export const PHONE_LOCAL_MEMORY_PERSONA_TAG_RECORDS_SQL: string =
  'SELECT * FROM conversation_memory WHERE owner_id = ? AND scene_id = ? AND persona_tag = ? ' +
  'ORDER BY updated_at DESC, memory_id ASC';

export const PHONE_LOCAL_MEMORY_DELETE_PERSONA_TAG_HISTORY_SQL: string =
  'DELETE FROM conversation_memory_history WHERE owner_id = ? AND memory_id IN (' +
    'SELECT memory_id FROM conversation_memory WHERE owner_id = ? AND scene_id = ? AND persona_tag = ?)';

export const PHONE_LOCAL_MEMORY_DELETE_PERSONA_TAG_SQL: string =
  'DELETE FROM conversation_memory WHERE owner_id = ? AND scene_id = ? AND persona_tag = ?';

export const PHONE_LOCAL_MEMORY_CLAIM_OWNER_SQL: string =
  'UPDATE conversation_memory SET owner_id = ? WHERE owner_id = ?';

export const PHONE_LOCAL_MEMORY_CLAIM_HISTORY_OWNER_SQL: string =
  'UPDATE conversation_memory_history SET owner_id = ? WHERE owner_id = ?';

export const PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL: string =
  'SELECT COUNT(*) AS changed_count, MIN(updated_at) AS oldest_pending_updated_at ' +
  "FROM conversation_memory WHERE owner_id = ? AND scene_id = ? AND authority = 'leader' AND updated_at > ?";

export const PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL: string =
  'SELECT memory_id, fact, persona_tag, authority, updated_at FROM conversation_memory ' +
  "WHERE owner_id = ? AND scene_id = ? AND authority = 'leader' ORDER BY updated_at ASC, memory_id ASC";

const PHONE_LOCAL_MEMORY_INSERT_HISTORY_SQL: string =
  'INSERT INTO conversation_memory_history (' +
    'history_id, memory_id, owner_id, scene_id, operation, fact, created_at' +
  ') VALUES (?, ?, ?, ?, ?, ?, ?)';

export type PhoneLocalMemoryHistoryOperation = 'add' | 'update';

export interface PhoneLocalMemorySearchRequest {
  ownerId: string;
  sceneIds: string[];
  embeddingProfileId: string;
  queryEmbedding: number[];
  topK: number;
  minScore?: number;
}

export interface PhoneLocalMemoryProjectionStats {
  changedCount: number;
  oldestPendingUpdatedAt: number | null;
}

export interface PhoneLocalMemoryProjectionFact {
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: MemoryAuthority;
  updatedAt: number;
}

export interface PhoneLocalMemoryStore {
  initialize(): Promise<void>;
  findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null>;
  get(ownerId: string, memoryId: string): Promise<MemoryRecord | null>;
  list(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]>;
  getProjectionStats(ownerId: string, sceneId: string,
    basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats>;
  listProjectionFacts(ownerId: string, sceneId: string): Promise<PhoneLocalMemoryProjectionFact[]>;
  search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]>;
  insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void>;
  replace(ownerId: string, record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void>;
  remove(ownerId: string, memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryRecord | null>;
  removeAll(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]>;
  /** Atomically removes one exact persona tag scope and inserts its prepared replacement records. */
  replaceByPersonaTag(ownerId: string, sceneId: string, personaTag: string,
    replacements: MemoryRecord[], guard?: MemoryCommitGuard): Promise<MemoryRecord[]>;
  /** Atomically moves all records and audit history from one owner scope to another. */
  claimOwner(fromOwnerId: string, toOwnerId: string): Promise<number>;
  getMetadata(key: string): Promise<string | null>;
  setMetadata(key: string, value: string): Promise<void>;
}

export function phoneLocalMemoryOperationCanceled(error: Object): boolean {
  return error instanceof Error && error.message === PHONE_LOCAL_MEMORY_OPERATION_CANCELED;
}

function requireActiveCommit(guard?: MemoryCommitGuard): void {
  if (guard === undefined) return;
  let active: boolean = false;
  try {
    active = guard.isActive();
  } catch (_error) {
    active = false;
  }
  if (!active) throw new Error(PHONE_LOCAL_MEMORY_OPERATION_CANCELED);
}

interface WriteWaiter {
  resolve: () => void;
}

class RdbWriteMutex {
  private busy: boolean = false;
  private waiters: WriteWaiter[] = [];

  async acquire(): Promise<void> {
    if (!this.busy) {
      this.busy = true;
      return;
    }
    await new Promise<void>((resolve: () => void): void => {
      this.waiters.push({ resolve });
    });
  }

  release(): void {
    const next = this.waiters.shift();
    if (next !== undefined) {
      next.resolve();
      return;
    }
    this.busy = false;
  }
}

function float32Vector(values: number[]): Float32Array {
  const vector = new Float32Array(values.length);
  for (let index = 0; index < values.length; index += 1) vector[index] = values[index];
  return vector;
}

function recordValues(record: MemoryRecord): relationalStore.ValueType[] {
  return [
    record.memoryId,
    record.ownerId,
    record.sceneId,
    record.personaTag,
    record.authority,
    record.fact,
    record.normalizedFact,
    record.factHash,
    float32Vector(record.embedding),
    record.embeddingProfileId,
    record.sourceTurnId,
    record.createdAt,
    record.updatedAt
  ];
}

function updateValues(ownerId: string, record: MemoryRecord): relationalStore.ValueType[] {
  return [
    record.sceneId,
    record.personaTag,
    record.authority,
    record.fact,
    record.normalizedFact,
    record.factHash,
    float32Vector(record.embedding),
    record.embeddingProfileId,
    record.sourceTurnId,
    record.updatedAt,
    ownerId,
    record.memoryId
  ];
}

function vectorFromValue(value: relationalStore.ValueType): number[] {
  if (!(value instanceof Float32Array)) return [];
  const vector: number[] = [];
  for (let index = 0; index < value.length; index += 1) vector.push(value[index]);
  return vector;
}

function memoryAuthorityFromValue(value: string): MemoryAuthority {
  return value === 'seed' ? 'seed' : 'leader';
}

function recordFromResult(result: relationalStore.ResultSet): MemoryRecord {
  return {
    memoryId: result.getString(result.getColumnIndex('memory_id')),
    ownerId: result.getString(result.getColumnIndex('owner_id')),
    sceneId: result.getString(result.getColumnIndex('scene_id')),
    personaTag: result.getString(result.getColumnIndex('persona_tag')),
    authority: memoryAuthorityFromValue(result.getString(result.getColumnIndex('authority'))),
    fact: result.getString(result.getColumnIndex('fact')),
    normalizedFact: result.getString(result.getColumnIndex('normalized_fact')),
    factHash: result.getString(result.getColumnIndex('fact_hash')),
    embedding: vectorFromValue(result.getValue(result.getColumnIndex('embedding'))),
    embeddingProfileId: result.getString(result.getColumnIndex('embedding_profile_id')),
    sourceTurnId: result.getString(result.getColumnIndex('source_turn_id')),
    createdAt: result.getLong(result.getColumnIndex('created_at')),
    updatedAt: result.getLong(result.getColumnIndex('updated_at'))
  };
}

function recordsFromResult(result: relationalStore.ResultSet): MemoryRecord[] {
  const output: MemoryRecord[] = [];
  try {
    if (!result.goToFirstRow()) return output;
    do {
      output.push(recordFromResult(result));
    } while (result.goToNextRow());
    return output;
  } finally {
    result.close();
  }
}

function projectionFactsFromResult(result: relationalStore.ResultSet): PhoneLocalMemoryProjectionFact[] {
  const output: PhoneLocalMemoryProjectionFact[] = [];
  try {
    if (!result.goToFirstRow()) return output;
    do {
      output.push({
        memoryId: result.getString(result.getColumnIndex('memory_id')),
        fact: result.getString(result.getColumnIndex('fact')),
        personaTag: result.getString(result.getColumnIndex('persona_tag')),
        authority: memoryAuthorityFromValue(result.getString(result.getColumnIndex('authority'))),
        updatedAt: result.getLong(result.getColumnIndex('updated_at'))
      });
    } while (result.goToNextRow());
    return output;
  } finally {
    result.close();
  }
}

function placeholders(count: number): string {
  const values: string[] = [];
  for (let index = 0; index < count; index += 1) values.push('?');
  return values.join(',');
}

export function buildPhoneLocalMemorySearchSql(candidateLimit: number): string {
  const safeLimit = Math.min(PHONE_LOCAL_MEMORY_MAX_CANDIDATE_LIMIT,
    Math.max(PHONE_LOCAL_MEMORY_MIN_CANDIDATE_LIMIT, Math.floor(candidateLimit)));
  return 'SELECT conversation_memory.*, embedding <=> ? AS distance ' +
    'FROM conversation_memory ORDER BY embedding <=> ? LIMIT ' + safeLimit;
}

export function phoneLocalMemoryCandidateLimit(topK: number): number {
  return Math.min(PHONE_LOCAL_MEMORY_MAX_CANDIDATE_LIMIT,
    Math.max(PHONE_LOCAL_MEMORY_MIN_CANDIDATE_LIMIT, topK * 10));
}

export class ArkDataPhoneLocalMemoryStore implements PhoneLocalMemoryStore {
  private context: common.Context;
  private store: relationalStore.RdbStore | null = null;
  private initializing: Promise<void> | null = null;
  private writeMutex: RdbWriteMutex = new RdbWriteMutex();

  constructor(context: common.Context) {
    this.context = context;
  }

  static isSupported(): boolean {
    return relationalStore.isVectorSupported();
  }

  static isVectorSupported(): boolean {
    return relationalStore.isVectorSupported();
  }

  getDatabaseName(): string {
    return PHONE_LOCAL_MEMORY_VECTOR_DB_NAME;
  }

  async initialize(): Promise<void> {
    if (this.store !== null) return;
    if (this.initializing !== null) return this.initializing;
    this.initializing = this.openAndMigrate();
    try {
      await this.initializing;
    } finally {
      this.initializing = null;
    }
  }

  private async openAndMigrate(): Promise<void> {
    if (!relationalStore.isVectorSupported()) {
      throw new Error('ArkData vector RDB is not supported on this device.');
    }
    const config: relationalStore.StoreConfig = {
      name: PHONE_LOCAL_MEMORY_VECTOR_DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
      vector: true
    };
    const opened = await relationalStore.getRdbStore(this.context, config);
    await opened.execute(PHONE_LOCAL_MEMORY_SCHEMA_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_HISTORY_SCHEMA_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_METADATA_SCHEMA_SQL);
    const schemaVersion = await this.metadataValue(opened, PHONE_LOCAL_MEMORY_SCHEMA_VERSION_KEY);
    await opened.execute(PHONE_LOCAL_MEMORY_DEDUPE_INDEX_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_SCOPE_INDEX_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL);
    if (schemaVersion !== PHONE_LOCAL_MEMORY_SCHEMA_VERSION) {
      const txId = await opened.beginTrans();
      try {
        await opened.execute(
          'INSERT OR REPLACE INTO conversation_memory_metadata ' +
          '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
          txId,
          [PHONE_LOCAL_MEMORY_SCHEMA_VERSION_KEY, PHONE_LOCAL_MEMORY_SCHEMA_VERSION, Date.now()]
        );
        await opened.commit(txId);
      } catch (error) {
        await opened.rollback(txId);
        throw error instanceof Error ? error : new Error('Local memory schema marker write failed.');
      }
    }
    this.store = opened;
  }

  private async metadataValue(store: relationalStore.RdbStore, key: string): Promise<string | null> {
    const result = await store.querySql(
      'SELECT metadata_value FROM conversation_memory_metadata WHERE metadata_key = ? LIMIT 1', [key]
    );
    try {
      if (!result.goToFirstRow()) return null;
      return result.getString(result.getColumnIndex('metadata_value'));
    } finally {
      result.close();
    }
  }

  private async readyStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === null) throw new Error('Local memory store did not initialize');
    return this.store;
  }

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    const store = await this.readyStore();
    const result = await store.querySql(
      'SELECT * FROM conversation_memory WHERE owner_id = ? AND embedding_profile_id = ? ' +
      'AND fact_hash = ? AND normalized_fact = ? LIMIT 1',
      [ownerId, embeddingProfileId, factHash, normalizedFact]
    );
    const records = recordsFromResult(result);
    return records.length > 0 ? records[0] : null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    const store = await this.readyStore();
    const result = await store.querySql(
      'SELECT * FROM conversation_memory WHERE owner_id = ? AND memory_id = ? LIMIT 1',
      [ownerId, memoryId]
    );
    const records = recordsFromResult(result);
    return records.length > 0 ? records[0] : null;
  }

  async list(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const store = await this.readyStore();
    if (sceneIds.length === 0) {
      return recordsFromResult(await store.querySql(
        'SELECT * FROM conversation_memory WHERE owner_id = ? ORDER BY updated_at DESC', [ownerId]
      ));
    }
    const args: relationalStore.ValueType[] = [ownerId];
    for (let index = 0; index < sceneIds.length; index += 1) args.push(sceneIds[index]);
    const sql = 'SELECT * FROM conversation_memory WHERE owner_id = ? AND scene_id IN (' +
      placeholders(sceneIds.length) + ') ORDER BY updated_at DESC';
    return recordsFromResult(await store.querySql(sql, args));
  }

  async getProjectionStats(ownerId: string, sceneId: string,
    basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    const result = await (await this.readyStore()).querySql(PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL,
      [ownerId, sceneId, basedOnMemoryMutationAt]);
    try {
      if (!result.goToFirstRow()) return { changedCount: 0, oldestPendingUpdatedAt: null };
      const changedCount = result.getLong(result.getColumnIndex('changed_count'));
      return {
        changedCount,
        oldestPendingUpdatedAt: changedCount > 0 ?
          result.getLong(result.getColumnIndex('oldest_pending_updated_at')) : null
      };
    } finally {
      result.close();
    }
  }

  async listProjectionFacts(ownerId: string, sceneId: string): Promise<PhoneLocalMemoryProjectionFact[]> {
    return projectionFactsFromResult(await (await this.readyStore()).querySql(
      PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL, [ownerId, sceneId]
    ));
  }

  async search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    const store = await this.readyStore();
    const topK = Math.min(100, Math.max(1, Math.floor(request.topK)));
    const candidateLimit = phoneLocalMemoryCandidateLimit(topK);
    const queryVector = float32Vector(request.queryEmbedding);
    const args: relationalStore.ValueType[] = [queryVector, queryVector];

    const result = await store.querySql(buildPhoneLocalMemorySearchSql(candidateLimit), args);
    const hits: MemoryHit[] = [];
    try {
      if (!result.goToFirstRow()) return hits;
      do {
        const record = recordFromResult(result);
        // ArkData's GSDISKANN query can return no rows when scalar predicates are placed before
        // the vector ORDER BY. V1 therefore retrieves a bounded global ANN window and applies
        // scope checks here. This never returns another scope, but can under-recall when more
        // than candidateLimit closer out-of-scope vectors dominate the global window.
        if (record.ownerId !== request.ownerId) continue;
        if (record.embeddingProfileId !== request.embeddingProfileId) continue;
        if (request.sceneIds.length > 0 && request.sceneIds.indexOf(record.sceneId) < 0) continue;
        const distance = result.getDouble(result.getColumnIndex('distance'));
        const score = 1 - distance;
        if (!Number.isFinite(score)) continue;
        if (request.minScore !== undefined && score < request.minScore) continue;
        hits.push({ record, score });
      } while (result.goToNextRow());
      return hits.slice(0, topK);
    } finally {
      result.close();
    }
  }

  async insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      requireActiveCommit(guard);
      const txId = await store.beginTrans();
      try {
        await store.execute(PHONE_LOCAL_MEMORY_INSERT_SQL, txId, recordValues(record));
        await this.insertHistory(store, txId, record, 'add');
        await store.commit(txId);
      } catch (error) {
        await store.rollback(txId);
        const failure: Error = error instanceof Error ? error : new Error('Local memory insert failed.');
        throw failure;
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async replace(ownerId: string, record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    if (record.ownerId !== ownerId) throw new Error('Memory record owner does not match update scope.');
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      const existing = await this.get(ownerId, record.memoryId);
      if (existing === null) throw new Error('Memory record does not exist in owner scope.');
      requireActiveCommit(guard);
      const txId = await store.beginTrans();
      try {
        await store.execute(PHONE_LOCAL_MEMORY_UPDATE_SQL, txId, updateValues(ownerId, record));
        await this.insertHistory(store, txId, record, 'update');
        await store.commit(txId);
      } catch (error) {
        await store.rollback(txId);
        const failure: Error = error instanceof Error ? error : new Error('Local memory update failed.');
        throw failure;
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async remove(ownerId: string, memoryId: string,
    guard?: MemoryCommitGuard): Promise<MemoryRecord | null> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      const existing = await this.get(ownerId, memoryId);
      if (existing === null) return null;
      requireActiveCommit(guard);
      const txId = await store.beginTrans();
      try {
        await store.execute(PHONE_LOCAL_MEMORY_DELETE_SQL, txId, [ownerId, memoryId]);
        await store.execute(PHONE_LOCAL_MEMORY_DELETE_HISTORY_SQL, txId, [ownerId, memoryId]);
        await store.commit(txId);
        return existing;
      } catch (error) {
        await store.rollback(txId);
        const failure: Error = error instanceof Error ? error : new Error('Local memory delete failed.');
        throw failure;
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async removeAll(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const existing = await this.list(ownerId, sceneIds);
    for (let index = 0; index < existing.length; index += 1) {
      await this.remove(ownerId, existing[index].memoryId);
    }
    return existing;
  }

  async replaceByPersonaTag(ownerId: string, sceneId: string, personaTag: string,
    replacements: MemoryRecord[], guard?: MemoryCommitGuard): Promise<MemoryRecord[]> {
    for (let index = 0; index < replacements.length; index += 1) {
      const record = replacements[index];
      if (record.ownerId !== ownerId || record.sceneId !== sceneId || record.personaTag !== personaTag) {
        throw new Error('Memory replacement record does not match persona tag scope.');
      }
    }
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      const existing = recordsFromResult(await store.querySql(PHONE_LOCAL_MEMORY_PERSONA_TAG_RECORDS_SQL,
        [ownerId, sceneId, personaTag]));
      requireActiveCommit(guard);
      const txId = await store.beginTrans();
      try {
        await store.execute(PHONE_LOCAL_MEMORY_DELETE_PERSONA_TAG_HISTORY_SQL, txId,
          [ownerId, ownerId, sceneId, personaTag]);
        await store.execute(PHONE_LOCAL_MEMORY_DELETE_PERSONA_TAG_SQL, txId, [ownerId, sceneId, personaTag]);
        for (let index = 0; index < replacements.length; index += 1) {
          await store.execute(PHONE_LOCAL_MEMORY_INSERT_SQL, txId, recordValues(replacements[index]));
          await this.insertHistory(store, txId, replacements[index], 'add');
        }
        await store.commit(txId);
        return existing;
      } catch (error) {
        await store.rollback(txId);
        throw error instanceof Error ? error : new Error('Local memory persona tag replacement failed.');
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async claimOwner(fromOwnerId: string, toOwnerId: string): Promise<number> {
    const from: string = fromOwnerId.trim();
    const to: string = toOwnerId.trim();
    if (from.length === 0 || to.length === 0) throw new Error('Memory owner claim requires two owner IDs.');
    if (from === to) return 0;
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      const countResult = await store.querySql(
        'SELECT COUNT(*) AS record_count FROM conversation_memory WHERE owner_id = ?', [from]);
      let claimed: number = 0;
      try {
        if (countResult.goToFirstRow()) claimed = countResult.getLong(countResult.getColumnIndex('record_count'));
      } finally {
        countResult.close();
      }
      const txId = await store.beginTrans();
      try {
        await store.execute(PHONE_LOCAL_MEMORY_CLAIM_OWNER_SQL, txId, [to, from]);
        await store.execute(PHONE_LOCAL_MEMORY_CLAIM_HISTORY_OWNER_SQL, txId, [to, from]);
        await store.commit(txId);
        return claimed;
      } catch (error) {
        await store.rollback(txId);
        throw error instanceof Error ? error : new Error('Local memory owner claim failed.');
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async getMetadata(key: string): Promise<string | null> {
    const store = await this.readyStore();
    const result = await store.querySql(
      'SELECT metadata_value FROM conversation_memory_metadata WHERE metadata_key = ? LIMIT 1', [key]
    );
    try {
      if (!result.goToFirstRow()) return null;
      return result.getString(result.getColumnIndex('metadata_value'));
    } finally {
      result.close();
    }
  }

  async setMetadata(key: string, value: string): Promise<void> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      const txId = await store.beginTrans();
      try {
        await store.execute(
          'INSERT OR REPLACE INTO conversation_memory_metadata ' +
          '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
          txId, [key, value, Date.now()]
        );
        await store.commit(txId);
      } catch (error) {
        await store.rollback(txId);
        const failure: Error = error instanceof Error ? error : new Error('Local memory metadata write failed.');
        throw failure;
      }
    } finally {
      this.writeMutex.release();
    }
  }

  private async insertHistory(store: relationalStore.RdbStore, txId: number, record: MemoryRecord,
    operation: PhoneLocalMemoryHistoryOperation): Promise<void> {
    await store.execute(PHONE_LOCAL_MEMORY_INSERT_HISTORY_SQL, txId, [
      util.generateRandomUUID(false),
      record.memoryId,
      record.ownerId,
      record.sceneId,
      operation,
      record.fact,
      Date.now()
    ]);
  }
}
