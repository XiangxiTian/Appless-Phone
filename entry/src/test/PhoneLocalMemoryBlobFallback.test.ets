import { describe, expect, it } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { MemoryRecord } from '@loop/agent-core';
import {
  buildPhoneLocalMemoryBlobSearchSql,
  decodePhoneLocalMemoryEmbeddingBlob,
  encodePhoneLocalMemoryEmbeddingBlob,
  executePhoneLocalMemoryBlobTransaction,
  PHONE_LOCAL_MEMORY_BLOB_DEDUPE_INDEX_SQL,
  PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL,
  PHONE_LOCAL_MEMORY_BLOB_SCOPE_INDEX_SQL,
  PhoneLocalMemoryBlobTransactionPort,
  rankPhoneLocalMemoryBlobRecords
} from '../main/ets/memory/PhoneLocalMemoryBlobFallbackPort';

class BlobTransactionSpy implements PhoneLocalMemoryBlobTransactionPort {
  beginTransactionCalls: number = 0;
  beginTransCalls: number = 0;
  commitCalls: number = 0;
  rollBackCalls: number = 0;
  threeArgumentExecuteCalls: number = 0;
  executeSql: string[] = [];
  executeArgs: relationalStore.ValueType[][] = [];
  failAt: number = -1;

  beginTransaction(): void {
    this.beginTransactionCalls += 1;
  }

  async beginTrans(): Promise<number> {
    this.beginTransCalls += 1;
    return 1;
  }

  async execute(sql: string, args?: relationalStore.ValueType[],
    forbiddenThirdArgument?: relationalStore.ValueType[]): Promise<relationalStore.ValueType> {
    if (forbiddenThirdArgument !== undefined) this.threeArgumentExecuteCalls += 1;
    this.executeSql.push(sql);
    this.executeArgs.push(args ?? []);
    if (this.executeSql.length === this.failAt) throw new Error('injected transaction failure');
    return 0;
  }

  commit(): void {
    this.commitCalls += 1;
  }

  rollBack(): void {
    this.rollBackCalls += 1;
  }
}

function vector(first: number, second: number = 0): number[] {
  const output: number[] = new Array<number>(512).fill(0);
  output[0] = first;
  output[1] = second;
  return output;
}

function record(memoryId: string, ownerId: string, sceneId: string, profileId: string,
  embedding: number[], updatedAt: number): MemoryRecord {
  return {
    memoryId, ownerId, sceneId, personaTag: 'stored_persona', authority: 'leader',
    fact: memoryId, normalizedFact: memoryId, factHash: 'hash-' + memoryId,
    embedding, embeddingProfileId: profileId, sourceTurnId: 'turn-' + memoryId,
    createdAt: 1, updatedAt
  };
}

export default function phoneLocalMemoryBlobFallbackTest() {
  describe('PhoneLocalMemoryBlobFallback', () => {
    it('uses a versioned BLOB schema and scalar scope indexes without a vector index', 0, () => {
      expect(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL).assertContain('embedding BLOB NOT NULL');
      expect(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL.indexOf('FLOATVECTOR')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_BLOB_SCOPE_INDEX_SQL).assertContain(
        'owner_id, embedding_profile_id, scene_id, updated_at'
      );
      expect(PHONE_LOCAL_MEMORY_BLOB_DEDUPE_INDEX_SQL).assertContain(
        'owner_id, embedding_profile_id, fact_hash, normalized_fact'
      );
    });

    it('encodes 512 FP32 values little-endian and round-trips them', 0, () => {
      const values = vector(1, -2.5);
      values[511] = 0.25;
      const bytes = encodePhoneLocalMemoryEmbeddingBlob(values);
      const decoded = decodePhoneLocalMemoryEmbeddingBlob(bytes);

      expect(bytes.byteLength).assertEqual(2048);
      expect(bytes[0]).assertEqual(0);
      expect(bytes[1]).assertEqual(0);
      expect(bytes[2]).assertEqual(128);
      expect(bytes[3]).assertEqual(63);
      expect(decoded === null).assertFalse();
      expect(decoded?.length ?? 0).assertEqual(512);
      expect(decoded?.[0] ?? 0).assertEqual(1);
      expect(decoded?.[1] ?? 0).assertEqual(-2.5);
      expect(decoded?.[511] ?? 0).assertEqual(0.25);
    });

    it('rejects wrong dimensions and safely returns null for malformed or non-finite blobs', 0, () => {
      let rejected = false;
      try {
        encodePhoneLocalMemoryEmbeddingBlob([1]);
      } catch (_error) {
        rejected = true;
      }
      const nanBytes = new Uint8Array(2048);
      new DataView(nanBytes.buffer as ArrayBuffer).setFloat32(0, Number.NaN, true);

      expect(rejected).assertTrue();
      expect(decodePhoneLocalMemoryEmbeddingBlob(new Uint8Array(7)) === null).assertTrue();
      expect(decodePhoneLocalMemoryEmbeddingBlob(nanBytes) === null).assertTrue();
    });

    it('ranks exact cosine scores with threshold topK and stable tie breaks', 0, () => {
      const records: MemoryRecord[] = [
        record('b', 'owner', 'global', 'profile', vector(1), 20),
        record('a', 'owner', 'global', 'profile', vector(1), 20),
        record('newer', 'owner', 'global', 'profile', vector(1), 30),
        record('weak', 'owner', 'global', 'profile', vector(0.4, 0.2), 40),
        record('orthogonal', 'owner', 'global', 'profile', vector(0, 1), 50)
      ];
      const hits = rankPhoneLocalMemoryBlobRecords(records, vector(1), 3, 0.5);

      expect(hits.length).assertEqual(3);
      expect(hits[0].record.memoryId).assertEqual('newer');
      expect(hits[1].record.memoryId).assertEqual('a');
      expect(hits[2].record.memoryId).assertEqual('b');
      expect(rankPhoneLocalMemoryBlobRecords(records, vector(1), 20, 0.3).length).assertEqual(4);
      expect(rankPhoneLocalMemoryBlobRecords(records, vector(1), 21).length).assertEqual(0);
    });

    it('builds parameterized owner profile and optional scene filters before traversal', 0, () => {
      const globalSql = buildPhoneLocalMemoryBlobSearchSql(0);
      const scopedSql = buildPhoneLocalMemoryBlobSearchSql(2);
      expect(globalSql).assertContain('WHERE owner_id = ? AND embedding_profile_id = ?');
      expect(globalSql.indexOf('scene_id IN')).assertEqual(-1);
      expect(globalSql.indexOf('persona_tag')).assertEqual(-1);
      expect(scopedSql).assertContain('scene_id IN (?,?)');
      expect(scopedSql.indexOf('owner_id = ?') < scopedSql.indexOf('scene_id IN')).assertTrue();
    });

    it('uses legacy ordinary-RDB transactions and two-argument execute calls', 0, async () => {
      const store = new BlobTransactionSpy();
      await executePhoneLocalMemoryBlobTransaction(store, [
        { sql: 'INSERT one', args: ['value'] }, { sql: 'DELETE two' }
      ]);

      expect(store.beginTransactionCalls).assertEqual(1);
      expect(store.beginTransCalls).assertEqual(0);
      expect(store.threeArgumentExecuteCalls).assertEqual(0);
      expect(store.executeSql.length).assertEqual(2);
      expect(store.executeArgs[0][0] as string).assertEqual('value');
      expect(store.executeArgs[1].length).assertEqual(0);
      expect(store.commitCalls).assertEqual(1);
      expect(store.rollBackCalls).assertEqual(0);
    });

    it('rolls back the legacy ordinary-RDB transaction when a statement fails', 0, async () => {
      const store = new BlobTransactionSpy();
      store.failAt = 2;
      let rejected = false;
      try {
        await executePhoneLocalMemoryBlobTransaction(store, [
          { sql: 'INSERT one', args: ['value'] }, { sql: 'INSERT two', args: ['value-2'] }
        ]);
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(store.beginTransactionCalls).assertEqual(1);
      expect(store.beginTransCalls).assertEqual(0);
      expect(store.threeArgumentExecuteCalls).assertEqual(0);
      expect(store.commitCalls).assertEqual(0);
      expect(store.rollBackCalls).assertEqual(1);
    });
  });
}
