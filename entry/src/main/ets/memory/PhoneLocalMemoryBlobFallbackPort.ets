import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import util from '@ohos.util';
import { MemoryAuthority, MemoryCommitGuard, MemoryHit, MemoryRecord } from '@loop/agent-core';
import {
  PHONE_LOCAL_MEMORY_OPERATION_CANCELED,
  PHONE_LOCAL_MEMORY_VECTOR_DIMENSION,
  PhoneLocalMemoryHistoryOperation,
  PhoneLocalMemorySearchRequest,
  PhoneLocalMemoryStore
} from './PhoneLocalMemoryStore';

export const PHONE_LOCAL_MEMORY_BLOB_DB_NAME: string = 'pocketagent_conversation_memory_blob_v1.db';
export const PHONE_LOCAL_MEMORY_BLOB_TABLE: string = 'conversation_memory_blob';
export const PHONE_LOCAL_MEMORY_BLOB_HISTORY_TABLE: string = 'conversation_memory_blob_history';
export const PHONE_LOCAL_MEMORY_BLOB_METADATA_TABLE: string = 'conversation_memory_blob_metadata';
export const PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY: string = 'schema_version';
export const PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION: string = '1';

export const PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_blob (' +
    'memory_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, scene_id TEXT NOT NULL, ' +
    'persona_tag TEXT NOT NULL, authority TEXT NOT NULL, fact TEXT NOT NULL, ' +
    'normalized_fact TEXT NOT NULL, fact_hash TEXT NOT NULL, embedding BLOB NOT NULL, ' +
    'embedding_profile_id TEXT NOT NULL, source_turn_id TEXT NOT NULL, ' +
    'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)';

export const PHONE_LOCAL_MEMORY_BLOB_HISTORY_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_blob_history (' +
    'history_id TEXT PRIMARY KEY, memory_id TEXT NOT NULL, owner_id TEXT NOT NULL, ' +
    'scene_id TEXT NOT NULL, operation TEXT NOT NULL, fact TEXT NOT NULL, created_at INTEGER NOT NULL)';

export const PHONE_LOCAL_MEMORY_BLOB_METADATA_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_blob_metadata (' +
    'metadata_key TEXT PRIMARY KEY, metadata_value TEXT NOT NULL, updated_at INTEGER NOT NULL)';

export const PHONE_LOCAL_MEMORY_BLOB_DEDUPE_INDEX_SQL: string =
  'CREATE UNIQUE INDEX IF NOT EXISTS idx_conversation_memory_blob_dedupe ' +
  'ON conversation_memory_blob(owner_id, embedding_profile_id, fact_hash, normalized_fact)';

export const PHONE_LOCAL_MEMORY_BLOB_SCOPE_INDEX_SQL: string =
  'CREATE INDEX IF NOT EXISTS idx_conversation_memory_blob_scope ' +
  'ON conversation_memory_blob(owner_id, embedding_profile_id, scene_id, updated_at)';

const BLOB_INSERT_SQL: string =
  'INSERT INTO conversation_memory_blob (' +
    'memory_id, owner_id, scene_id, persona_tag, authority, fact, normalized_fact, fact_hash, embedding, ' +
    'embedding_profile_id, source_turn_id, created_at, updated_at' +
  ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

const BLOB_UPDATE_SQL: string =
  'UPDATE conversation_memory_blob SET scene_id = ?, persona_tag = ?, authority = ?, fact = ?, ' +
  'normalized_fact = ?, fact_hash = ?, embedding = ?, embedding_profile_id = ?, source_turn_id = ?, ' +
  'updated_at = ? WHERE owner_id = ? AND memory_id = ?';

const BLOB_INSERT_HISTORY_SQL: string =
  'INSERT INTO conversation_memory_blob_history ' +
  '(history_id, memory_id, owner_id, scene_id, operation, fact, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)';

export interface PhoneLocalMemoryBlobFallbackPort extends PhoneLocalMemoryStore {
  readonly backendId: 'blob';
  clearAll(): Promise<void>;
}

export interface PhoneLocalMemoryBlobTransactionPort {
  beginTransaction(): void;
  execute(sql: string, args?: relationalStore.ValueType[]): Promise<relationalStore.ValueType>;
  commit(): void;
  rollBack(): void;
}

export interface PhoneLocalMemoryBlobStatement {
  sql: string;
  args?: relationalStore.ValueType[];
}

/** Ordinary RDB uses the legacy transaction lifecycle; txId APIs are reserved for vector RDB. */
export async function executePhoneLocalMemoryBlobTransaction(store: PhoneLocalMemoryBlobTransactionPort,
  statements: PhoneLocalMemoryBlobStatement[]): Promise<void> {
  store.beginTransaction();
  try {
    for (let index = 0; index < statements.length; index += 1) {
      const statement = statements[index];
      if (statement.args === undefined) await store.execute(statement.sql);
      else await store.execute(statement.sql, statement.args);
    }
    store.commit();
  } catch (error) {
    store.rollBack();
    throw error instanceof Error ? error : new Error('BLOB memory transaction failed.');
  }
}

class ArkDataBlobTransactionAdapter implements PhoneLocalMemoryBlobTransactionPort {
  private store: relationalStore.RdbStore;

  constructor(store: relationalStore.RdbStore) {
    this.store = store;
  }

  beginTransaction(): void {
    this.store.beginTransaction();
  }

  async execute(sql: string, args?: relationalStore.ValueType[]): Promise<relationalStore.ValueType> {
    if (args === undefined) return await this.store.execute(sql);
    return await this.store.execute(sql, args);
  }

  commit(): void {
    this.store.commit();
  }

  rollBack(): void {
    this.store.rollBack();
  }
}

interface WriteWaiter {
  resolve: () => void;
}

class BlobWriteMutex {
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
    if (next !== undefined) next.resolve();
    else this.busy = false;
  }
}

function requireActiveCommit(guard?: MemoryCommitGuard): void {
  if (guard === undefined) return;
  let active = false;
  try {
    active = guard.isActive();
  } catch (_error) {
    active = false;
  }
  if (!active) throw new Error(PHONE_LOCAL_MEMORY_OPERATION_CANCELED);
}

function placeholders(count: number): string {
  const output: string[] = [];
  for (let index = 0; index < count; index += 1) output.push('?');
  return output.join(',');
}

function validEmbedding(values: number[]): boolean {
  if (values.length !== PHONE_LOCAL_MEMORY_VECTOR_DIMENSION) return false;
  for (let index = 0; index < values.length; index += 1) {
    if (!Number.isFinite(values[index])) return false;
  }
  return true;
}

/** Encodes exactly 512 finite FP32 values in deterministic little-endian order. */
export function encodePhoneLocalMemoryEmbeddingBlob(values: number[]): Uint8Array {
  if (!validEmbedding(values)) throw new Error('Memory embedding must contain 512 finite values.');
  const bytes = new Uint8Array(PHONE_LOCAL_MEMORY_VECTOR_DIMENSION * 4);
  const view = new DataView(bytes.buffer as ArrayBuffer);
  for (let index = 0; index < values.length; index += 1) {
    const value = Math.fround(values[index]);
    if (!Number.isFinite(value)) throw new Error('Memory embedding cannot be represented as FP32.');
    view.setFloat32(index * 4, value, true);
  }
  return bytes;
}

/** Returns null rather than propagating malformed persisted embedding data. */
export function decodePhoneLocalMemoryEmbeddingBlob(bytes: Uint8Array): number[] | null {
  if (bytes.byteLength !== PHONE_LOCAL_MEMORY_VECTOR_DIMENSION * 4) return null;
  const view = new DataView(bytes.buffer as ArrayBuffer, bytes.byteOffset, bytes.byteLength);
  const values: number[] = [];
  for (let index = 0; index < PHONE_LOCAL_MEMORY_VECTOR_DIMENSION; index += 1) {
    const value = view.getFloat32(index * 4, true);
    if (!Number.isFinite(value)) return null;
    values.push(value);
  }
  return values;
}

export function phoneLocalMemoryBlobDotProduct(left: number[], right: number[]): number | null {
  if (!validEmbedding(left) || !validEmbedding(right)) return null;
  let score = 0;
  for (let index = 0; index < PHONE_LOCAL_MEMORY_VECTOR_DIMENSION; index += 1) {
    score += left[index] * right[index];
  }
  return Number.isFinite(score) ? score : null;
}

function compareHits(left: MemoryHit, right: MemoryHit): number {
  if (left.score !== right.score) return right.score - left.score;
  if (left.record.updatedAt !== right.record.updatedAt) return right.record.updatedAt - left.record.updatedAt;
  if (left.record.memoryId < right.record.memoryId) return -1;
  if (left.record.memoryId > right.record.memoryId) return 1;
  return 0;
}

export function rankPhoneLocalMemoryBlobRecords(records: MemoryRecord[], queryEmbedding: number[],
  topK: number, minScore?: number): MemoryHit[] {
  if (!validEmbedding(queryEmbedding) || !Number.isInteger(topK) || topK < 1 || topK > 20) return [];
  if (minScore !== undefined && !Number.isFinite(minScore)) return [];
  const hits: MemoryHit[] = [];
  for (let index = 0; index < records.length; index += 1) {
    const score = phoneLocalMemoryBlobDotProduct(records[index].embedding, queryEmbedding);
    if (score === null || (minScore !== undefined && score < minScore)) continue;
    hits.push({ record: records[index], score });
  }
  hits.sort(compareHits);
  return hits.slice(0, topK);
}

export function buildPhoneLocalMemoryBlobSearchSql(sceneCount: number): string {
  let sql = 'SELECT * FROM conversation_memory_blob ' +
    'WHERE owner_id = ? AND embedding_profile_id = ?';
  if (sceneCount > 0) sql += ' AND scene_id IN (' + placeholders(sceneCount) + ')';
  return sql + ' ORDER BY updated_at DESC, memory_id ASC';
}

function authorityFromText(value: string): MemoryAuthority {
  return value === 'seed' ? 'seed' : 'leader';
}

function recordFromResult(result: relationalStore.ResultSet): MemoryRecord | null {
  const embedding = decodePhoneLocalMemoryEmbeddingBlob(result.getBlob(result.getColumnIndex('embedding')));
  if (embedding === null) return null;
  return {
    memoryId: result.getString(result.getColumnIndex('memory_id')),
    ownerId: result.getString(result.getColumnIndex('owner_id')),
    sceneId: result.getString(result.getColumnIndex('scene_id')),
    personaTag: result.getString(result.getColumnIndex('persona_tag')),
    authority: authorityFromText(result.getString(result.getColumnIndex('authority'))),
    fact: result.getString(result.getColumnIndex('fact')),
    normalizedFact: result.getString(result.getColumnIndex('normalized_fact')),
    factHash: result.getString(result.getColumnIndex('fact_hash')),
    embedding,
    embeddingProfileId: result.getString(result.getColumnIndex('embedding_profile_id')),
    sourceTurnId: result.getString(result.getColumnIndex('source_turn_id')),
    createdAt: result.getLong(result.getColumnIndex('created_at')),
    updatedAt: result.getLong(result.getColumnIndex('updated_at'))
  };
}

function recordsFromResult(result: relationalStore.ResultSet): MemoryRecord[] {
  const records: MemoryRecord[] = [];
  try {
    if (!result.goToFirstRow()) return records;
    do {
      const record = recordFromResult(result);
      if (record !== null) records.push(record);
    } while (result.goToNextRow());
    return records;
  } finally {
    result.close();
  }
}

function insertValues(record: MemoryRecord): relationalStore.ValueType[] {
  return [record.memoryId, record.ownerId, record.sceneId, record.personaTag, record.authority,
    record.fact, record.normalizedFact, record.factHash, encodePhoneLocalMemoryEmbeddingBlob(record.embedding),
    record.embeddingProfileId, record.sourceTurnId, record.createdAt, record.updatedAt];
}

function updateValues(ownerId: string, record: MemoryRecord): relationalStore.ValueType[] {
  return [record.sceneId, record.personaTag, record.authority, record.fact, record.normalizedFact,
    record.factHash, encodePhoneLocalMemoryEmbeddingBlob(record.embedding), record.embeddingProfileId,
    record.sourceTurnId, record.updatedAt, ownerId, record.memoryId];
}

function historyStatement(record: MemoryRecord,
  operation: PhoneLocalMemoryHistoryOperation): PhoneLocalMemoryBlobStatement {
  return {
    sql: BLOB_INSERT_HISTORY_SQL,
    args: [util.generateRandomUUID(false), record.memoryId, record.ownerId, record.sceneId,
      operation, record.fact, Date.now()]
  };
}

export class ArkDataPhoneLocalMemoryBlobStore implements PhoneLocalMemoryBlobFallbackPort {
  readonly backendId: 'blob' = 'blob';
  private context: common.Context;
  private databaseName: string;
  private store: relationalStore.RdbStore | null = null;
  private initializing: Promise<void> | null = null;
  private writeMutex: BlobWriteMutex = new BlobWriteMutex();

  constructor(context: common.Context, databaseName: string = PHONE_LOCAL_MEMORY_BLOB_DB_NAME) {
    this.context = context;
    this.databaseName = databaseName;
  }

  getDatabaseName(): string {
    return this.databaseName;
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
    const config: relationalStore.StoreConfig = {
      name: this.databaseName,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const opened = await relationalStore.getRdbStore(this.context, config);
    await opened.execute(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_BLOB_HISTORY_SCHEMA_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_BLOB_METADATA_SCHEMA_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_BLOB_DEDUPE_INDEX_SQL);
    await opened.execute(PHONE_LOCAL_MEMORY_BLOB_SCOPE_INDEX_SQL);
    const schemaVersion = await this.metadataValue(opened, PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY);
    if (schemaVersion !== PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION) {
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(opened), [{
          sql: 'INSERT OR REPLACE INTO conversation_memory_blob_metadata ' +
            '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
          args: [PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY, PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION, Date.now()]
        }]);
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory schema marker write failed.');
      }
    }
    this.store = opened;
  }

  private async readyStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === null) throw new Error('BLOB memory store did not initialize.');
    return this.store;
  }

  private async metadataValue(store: relationalStore.RdbStore, key: string): Promise<string | null> {
    const result = await store.querySql(
      'SELECT metadata_value FROM conversation_memory_blob_metadata WHERE metadata_key = ? LIMIT 1', [key]);
    try {
      if (!result.goToFirstRow()) return null;
      return result.getString(result.getColumnIndex('metadata_value'));
    } finally {
      result.close();
    }
  }

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    const records = recordsFromResult(await (await this.readyStore()).querySql(
      'SELECT * FROM conversation_memory_blob WHERE owner_id = ? AND embedding_profile_id = ? ' +
      'AND fact_hash = ? AND normalized_fact = ? LIMIT 1',
      [ownerId, embeddingProfileId, factHash, normalizedFact]));
    return records.length > 0 ? records[0] : null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    const records = recordsFromResult(await (await this.readyStore()).querySql(
      'SELECT * FROM conversation_memory_blob WHERE owner_id = ? AND memory_id = ? LIMIT 1',
      [ownerId, memoryId]));
    return records.length > 0 ? records[0] : null;
  }

  async list(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const args: relationalStore.ValueType[] = [ownerId];
    let sql = 'SELECT * FROM conversation_memory_blob WHERE owner_id = ?';
    if (sceneIds.length > 0) {
      sql += ' AND scene_id IN (' + placeholders(sceneIds.length) + ')';
      for (let index = 0; index < sceneIds.length; index += 1) args.push(sceneIds[index]);
    }
    return recordsFromResult(await (await this.readyStore()).querySql(
      sql + ' ORDER BY updated_at DESC, memory_id ASC', args));
  }

  async search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    if (!Number.isInteger(request.topK) || request.topK < 1 || request.topK > 20) return [];
    if (!validEmbedding(request.queryEmbedding)) return [];
    const args: relationalStore.ValueType[] = [request.ownerId, request.embeddingProfileId];
    for (let index = 0; index < request.sceneIds.length; index += 1) args.push(request.sceneIds[index]);
    // SQL performs scalar isolation before any embedding BLOB is decoded or traversed.
    const records = recordsFromResult(await (await this.readyStore()).querySql(
      buildPhoneLocalMemoryBlobSearchSql(request.sceneIds.length), args));
    return rankPhoneLocalMemoryBlobRecords(records, request.queryEmbedding, request.topK, request.minScore);
  }

  async insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      requireActiveCommit(guard);
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(store), [
          { sql: BLOB_INSERT_SQL, args: insertValues(record) }, historyStatement(record, 'add')
        ]);
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory insert failed.');
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async replace(ownerId: string, record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    if (ownerId !== record.ownerId) throw new Error('Memory record owner does not match update scope.');
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      if (await this.get(ownerId, record.memoryId) === null) {
        throw new Error('Memory record does not exist in owner scope.');
      }
      requireActiveCommit(guard);
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(store), [
          { sql: BLOB_UPDATE_SQL, args: updateValues(ownerId, record) }, historyStatement(record, 'update')
        ]);
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory update failed.');
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
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(store), [{
          sql: 'DELETE FROM conversation_memory_blob WHERE owner_id = ? AND memory_id = ?',
          args: [ownerId, memoryId]
        }, {
          sql: 'DELETE FROM conversation_memory_blob_history WHERE owner_id = ? AND memory_id = ?',
          args: [ownerId, memoryId]
        }]);
        return existing;
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory delete failed.');
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

  async getMetadata(key: string): Promise<string | null> {
    return await this.metadataValue(await this.readyStore(), key);
  }

  async setMetadata(key: string, value: string): Promise<void> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(store), [{
          sql: 'INSERT OR REPLACE INTO conversation_memory_blob_metadata ' +
            '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
          args: [key, value, Date.now()]
        }]);
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory metadata write failed.');
      }
    } finally {
      this.writeMutex.release();
    }
  }

  async clearAll(): Promise<void> {
    const store = await this.readyStore();
    await this.writeMutex.acquire();
    try {
      try {
        await executePhoneLocalMemoryBlobTransaction(new ArkDataBlobTransactionAdapter(store), [
          { sql: 'DELETE FROM conversation_memory_blob' },
          { sql: 'DELETE FROM conversation_memory_blob_history' },
          { sql: 'DELETE FROM conversation_memory_blob_metadata' },
          {
            sql: 'INSERT INTO conversation_memory_blob_metadata ' +
              '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
            args: [PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY, PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION,
              Date.now()]
          }
        ]);
      } catch (error) {
        throw error instanceof Error ? error : new Error('BLOB memory clear failed.');
      }
    } finally {
      this.writeMutex.release();
    }
  }

}
