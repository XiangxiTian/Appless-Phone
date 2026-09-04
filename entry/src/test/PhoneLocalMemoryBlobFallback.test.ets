import { describe, expect, it } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { MemoryRecord } from '@loop/agent-core';
import {
  buildPhoneLocalMemoryBlobSearchSql,
  decodePhoneLocalMemoryEmbeddingBlob,
  encodePhoneLocalMemoryEmbeddingBlob,
  executePhoneLocalMemoryBlobConditionalTransaction,
  executePhoneLocalMemoryBlobTransaction,
  phoneLocalMemoryBlobConditionalDeleteValues,
  phoneLocalMemoryBlobConditionalUpdateValues,
  PHONE_LOCAL_MEMORY_BLOB_CONDITIONAL_DELETE_SQL,
  PHONE_LOCAL_MEMORY_BLOB_CONDITIONAL_UPDATE_SQL,
  PHONE_LOCAL_MEMORY_BLOB_DELETE_PERSONA_TAG_HISTORY_SQL,
  PHONE_LOCAL_MEMORY_BLOB_DELETE_PERSONA_TAG_SQL,
  PHONE_LOCAL_MEMORY_BLOB_DEDUPE_INDEX_SQL,
  PHONE_LOCAL_MEMORY_BLOB_SCHEMA_SQL,
  PHONE_LOCAL_MEMORY_BLOB_SCOPE_INDEX_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PERSONA_TAG_RECORDS_SQL,
  PhoneLocalMemoryBlobTransactionPort,
  rankPhoneLocalMemoryBlobRecords
} from '../main/ets/memory/PhoneLocalMemoryBlobFallbackPort';
import {
  PhoneLocalMemoryExpectedRecord
} from '../main/ets/memory/PhoneLocalMemoryStore';

class BlobTransactionSpy implements PhoneLocalMemoryBlobTransactionPort {
  beginTransactionCalls: number = 0;
  beginTransCalls: number = 0;
  commitCalls: number = 0;
  rollBackCalls: number = 0;
  threeArgumentExecuteCalls: number = 0;
  executeSql: string[] = [];
  executeArgs: relationalStore.ValueType[][] = [];
  failAt: number = -1;
  firstResult: relationalStore.ValueType = 0;

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
    return this.executeSql.length === 1 ? this.firstResult : 0;
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
      expect(PHONE_LOCAL_MEMORY_BLOB_PERSONA_TAG_RECORDS_SQL)
        .assertContain('owner_id = ? AND scene_id = ? AND persona_tag = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_CONDITIONAL_UPDATE_SQL)
        .assertContain('fact = ? AND persona_tag = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_CONDITIONAL_UPDATE_SQL)
        .assertContain('created_at = ? AND updated_at = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_CONDITIONAL_DELETE_SQL).assertContain('authority = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_DELETE_PERSONA_TAG_HISTORY_SQL)
        .assertContain('memory_id IN (SELECT memory_id');
      expect(PHONE_LOCAL_MEMORY_BLOB_DELETE_PERSONA_TAG_SQL)
        .assertContain('owner_id = ? AND scene_id = ? AND persona_tag = ?');
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

    it('uses the legacy BLOB lifecycle and skips history when conditional mutation affects zero rows',
      0, async () => {
      const store = new BlobTransactionSpy();
      store.firstResult = 0;
      const changed = await executePhoneLocalMemoryBlobConditionalTransaction(store,
        { sql: 'BLOB CAS', args: ['owner', 'memory'] },
        [{ sql: 'BLOB history', args: ['history'] }]);

      expect(changed).assertFalse();
      expect(store.beginTransactionCalls).assertEqual(1);
      expect(store.beginTransCalls).assertEqual(0);
      expect(store.threeArgumentExecuteCalls).assertEqual(0);
      expect(store.executeSql.length).assertEqual(1);
      expect(store.commitCalls).assertEqual(0);
      expect(store.rollBackCalls).assertEqual(1);
    });

    it('rolls back once when BLOB CAS succeeds but its history write fails', 0, async () => {
      const store = new BlobTransactionSpy();
      store.firstResult = 1;
      store.failAt = 2;
      let rejected = false;
      try {
        await executePhoneLocalMemoryBlobConditionalTransaction(store,
          { sql: 'BLOB CAS', args: ['owner', 'memory'] },
          [{ sql: 'BLOB history', args: ['history'] }]);
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(store.beginTransactionCalls).assertEqual(1);
      expect(store.beginTransCalls).assertEqual(0);
      expect(store.threeArgumentExecuteCalls).assertEqual(0);
      expect(store.executeSql.length).assertEqual(2);
      expect(store.commitCalls).assertEqual(0);
      expect(store.rollBackCalls).assertEqual(1);
    });

    it('keeps BLOB conditional predicate values in exact SQL placeholder order', 0, () => {
      const current = record('memory-1', 'owner-1', 'global', 'profile', vector(1), 20);
      current.fact = 'old fact';
      current.personaTag = 'persona';
      current.authority = 'seed';
      current.createdAt = 10;
      const expected: PhoneLocalMemoryExpectedRecord = {
        memoryId: current.memoryId, fact: current.fact, personaTag: current.personaTag,
        authority: current.authority, createdAt: current.createdAt, updatedAt: current.updatedAt
      };
      const updateValues = phoneLocalMemoryBlobConditionalUpdateValues('owner-1', current, expected);
      const deleteValues = phoneLocalMemoryBlobConditionalDeleteValues('owner-1', expected);
      const suffix = updateValues.slice(updateValues.length - 7);
      expect(suffix[0] as string).assertEqual('owner-1');
      expect(suffix[1] as string).assertEqual('memory-1');
      expect(suffix[2] as string).assertEqual('old fact');
      expect(suffix[3] as string).assertEqual('persona');
      expect(suffix[4] as string).assertEqual('seed');
      expect(suffix[5] as number).assertEqual(10);
      expect(suffix[6] as number).assertEqual(20);
      expect(JSON.stringify(deleteValues)).assertEqual(JSON.stringify(suffix));
    });
  });
}
