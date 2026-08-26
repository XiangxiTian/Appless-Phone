import { application, common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { describe, expect, it } from '@ohos/hypium';
import { EmbeddingPort, MemoryRecord } from '@loop/agent-core';
import { BertWordPieceTokenizer } from '../../../main/ets/memory/BertWordPieceTokenizer';
import {
  BGE_SMALL_ZH_EMBEDDING_DIMENSION,
  BgeMindSporeEmbeddingPort
} from '../../../main/ets/memory/BgeMindSporeEmbeddingPort';
import { PhoneLocalMemoryProvider } from '../../../main/ets/memory/PhoneLocalMemoryProvider';
import { ArkDataPhoneLocalMemoryStore } from '../../../main/ets/memory/PhoneLocalMemoryStore';
import {
  ArkDataPhoneLocalMemoryBlobStore,
  PHONE_LOCAL_MEMORY_BLOB_HISTORY_TABLE,
  PHONE_LOCAL_MEMORY_BLOB_METADATA_TABLE,
  PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION,
  PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY,
  PHONE_LOCAL_MEMORY_BLOB_TABLE
} from '../../../main/ets/memory/PhoneLocalMemoryBlobFallbackPort';

const VECTOR_OWNER_ID: string = 'phone-local-vector-regression-owner';
const OTHER_OWNER_ID: string = 'phone-local-vector-regression-other-owner';
const TARGET_SCENE_ID: string = 'vector_target_scene';
const OTHER_SCENE_ID: string = 'vector_other_scene';
const VECTOR_PROFILE_ID: string = 'bge-small-zh-v1.5:device-vector-regression';

const QUERY_TEXT: string = 'vector-query-e0';
const BEST_FACT: string = 'vector-best-e0';
const SECOND_FACT: string = 'vector-second-near-e0';
const ORTHOGONAL_FACT: string = 'vector-orthogonal-e1';
const WRONG_OWNER_FACT: string = 'vector-wrong-owner-exact-e0';
const WRONG_SCENE_FACT: string = 'vector-wrong-scene-exact-e0';

const BLOB_TEST_DB_NAME: string = 'pocketagent_conversation_memory_blob_ohostest_v1.db';
const BLOB_OWNER_ID: string = 'phone-local-blob-regression-owner';
const BLOB_OTHER_OWNER_ID: string = 'phone-local-blob-regression-other-owner';
const BLOB_PROFILE_ID: string = 'device-blob-regression-profile';
const BLOB_TARGET_SCENE_ID: string = 'blob_target_scene';
const BLOB_OTHER_SCENE_ID: string = 'blob_other_scene';

async function testAbilityContext(): Promise<common.Context> {
  const testAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
  return application.createModuleContext(testAbility.context, 'entry');
}

function unitVector(first: number, second: number): number[] {
  const vector: number[] = new Array<number>(BGE_SMALL_ZH_EMBEDDING_DIMENSION).fill(0);
  vector[0] = first;
  vector[1] = second;
  return vector;
}

class ControlledEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = VECTOR_PROFILE_ID;
  readonly dimension: number = BGE_SMALL_ZH_EMBEDDING_DIMENSION;

  async embed(text: string): Promise<number[]> {
    if (text === SECOND_FACT) return unitVector(0.98, 0.2);
    if (text === ORTHOGONAL_FACT) return unitVector(0, 1);
    return unitVector(1, 0);
  }
}

function allFinite(values: number[]): boolean {
  for (let index = 0; index < values.length; index += 1) {
    if (!Number.isFinite(values[index])) return false;
  }
  return true;
}

function blobRecord(memoryId: string, ownerId: string, sceneId: string, personaTag: string,
  fact: string, embedding: number[], timestamp: number): MemoryRecord {
  return {
    memoryId,
    ownerId,
    sceneId,
    personaTag,
    authority: 'leader',
    fact,
    normalizedFact: fact,
    factHash: 'hash-' + memoryId,
    embedding,
    embeddingProfileId: BLOB_PROFILE_ID,
    sourceTurnId: 'turn-' + memoryId,
    createdAt: timestamp,
    updatedAt: timestamp
  };
}

async function blobTableCount(context: common.Context, tableName: string): Promise<number> {
  const store = await relationalStore.getRdbStore(context, {
    name: BLOB_TEST_DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  });
  const result = await store.querySql('SELECT COUNT(*) AS row_count FROM ' + tableName);
  try {
    if (!result.goToFirstRow()) return -1;
    return result.getLong(result.getColumnIndex('row_count'));
  } finally {
    result.close();
  }
}

async function blobHistoryCount(context: common.Context, memoryId: string): Promise<number> {
  const store = await relationalStore.getRdbStore(context, {
    name: BLOB_TEST_DB_NAME,
    securityLevel: relationalStore.SecurityLevel.S1
  });
  const result = await store.querySql(
    'SELECT COUNT(*) AS row_count FROM ' + PHONE_LOCAL_MEMORY_BLOB_HISTORY_TABLE + ' WHERE memory_id = ?',
    [memoryId]
  );
  try {
    if (!result.goToFirstRow()) return -1;
    return result.getLong(result.getColumnIndex('row_count'));
  } finally {
    result.close();
  }
}

export default function phoneLocalMemoryDeviceTest() {
  describe('PhoneLocalMemoryDevice', () => {
    it('persists and traverses 512-dimensional FP32 BLOB memory with scoped CRUD', 0, async () => {
      const context = await testAbilityContext();
      const store = new ArkDataPhoneLocalMemoryBlobStore(context, BLOB_TEST_DB_NAME);
      let initialized: boolean = false;
      try {
        await store.initialize();
        initialized = true;
        await store.clearAll();

        expect(store.getDatabaseName()).assertEqual(BLOB_TEST_DB_NAME);
        expect(await store.getMetadata(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY))
          .assertEqual(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION);

        const first = blobRecord('blob-memory-first', BLOB_OWNER_ID, BLOB_TARGET_SCENE_ID,
          'persona-red', 'blob-first-near-e0', unitVector(0.8, 0.6), 1000);
        const second = blobRecord('blob-memory-second', BLOB_OWNER_ID, BLOB_TARGET_SCENE_ID,
          'persona-blue', 'blob-second-exact-e0', unitVector(1, 0), 2000);
        const otherScene = blobRecord('blob-memory-other-scene', BLOB_OWNER_ID, BLOB_OTHER_SCENE_ID,
          'persona-green', 'blob-other-scene-exact-e0', unitVector(1, 0), 3000);
        const otherOwner = blobRecord('blob-memory-other-owner', BLOB_OTHER_OWNER_ID, BLOB_TARGET_SCENE_ID,
          'persona-blue', 'blob-other-owner-exact-e0', unitVector(1, 0), 4000);
        await store.insert(first);
        await store.insert(second);
        await store.insert(otherScene);
        await store.insert(otherOwner);

        const roundTrip = await store.get(BLOB_OWNER_ID, first.memoryId);
        expect(roundTrip === null).assertFalse();
        expect((roundTrip as MemoryRecord).embedding.length).assertEqual(BGE_SMALL_ZH_EMBEDDING_DIMENSION);
        expect(Math.abs((roundTrip as MemoryRecord).embedding[0] - Math.fround(0.8)) < 0.000001).assertTrue();
        expect(Math.abs((roundTrip as MemoryRecord).embedding[1] - Math.fround(0.6)) < 0.000001).assertTrue();

        const targetList = await store.list(BLOB_OWNER_ID, [BLOB_TARGET_SCENE_ID]);
        expect(targetList.length).assertEqual(2);
        expect(targetList[0].memoryId).assertEqual(second.memoryId);
        expect(targetList[1].memoryId).assertEqual(first.memoryId);

        const hits = await store.search({
          ownerId: BLOB_OWNER_ID,
          embeddingProfileId: BLOB_PROFILE_ID,
          queryEmbedding: unitVector(1, 0),
          sceneIds: [BLOB_TARGET_SCENE_ID],
          topK: 2
        });
        expect(hits.length).assertEqual(2);
        expect(hits[0].record.memoryId).assertEqual(second.memoryId);
        expect(hits[1].record.memoryId).assertEqual(first.memoryId);
        expect(hits[0].score).assertEqual(1);
        expect(Math.abs(hits[1].score - 0.8) < 0.000001).assertTrue();
        expect(hits[0].record.personaTag).assertEqual('persona-blue');
        expect(hits[1].record.personaTag).assertEqual('persona-red');

        const topOne = await store.search({
          ownerId: BLOB_OWNER_ID,
          embeddingProfileId: BLOB_PROFILE_ID,
          queryEmbedding: unitVector(1, 0),
          sceneIds: [BLOB_TARGET_SCENE_ID],
          topK: 1
        });
        expect(topOne.length).assertEqual(1);
        expect(topOne[0].record.memoryId).assertEqual(second.memoryId);

        const thresholded = await store.search({
          ownerId: BLOB_OWNER_ID,
          embeddingProfileId: BLOB_PROFILE_ID,
          queryEmbedding: unitVector(1, 0),
          sceneIds: [BLOB_TARGET_SCENE_ID],
          topK: 2,
          minScore: 0.9
        });
        expect(thresholded.length).assertEqual(1);
        expect(thresholded[0].record.memoryId).assertEqual(second.memoryId);

        const isolatedOwner = await store.search({
          ownerId: BLOB_OTHER_OWNER_ID,
          embeddingProfileId: BLOB_PROFILE_ID,
          queryEmbedding: unitVector(1, 0),
          sceneIds: [BLOB_TARGET_SCENE_ID],
          topK: 2
        });
        expect(isolatedOwner.length).assertEqual(1);
        expect(isolatedOwner[0].record.memoryId).assertEqual(otherOwner.memoryId);

        const replaced = blobRecord(first.memoryId, BLOB_OWNER_ID, BLOB_TARGET_SCENE_ID,
          'persona-red', 'blob-first-reembedded-e1', unitVector(0, 1), first.createdAt);
        replaced.updatedAt = 5000;
        await store.replace(BLOB_OWNER_ID, replaced);
        expect(await blobHistoryCount(context, first.memoryId)).assertEqual(2);
        const reembeddedHits = await store.search({
          ownerId: BLOB_OWNER_ID,
          embeddingProfileId: BLOB_PROFILE_ID,
          queryEmbedding: unitVector(0, 1),
          sceneIds: [BLOB_TARGET_SCENE_ID],
          topK: 1
        });
        expect(reembeddedHits.length).assertEqual(1);
        expect(reembeddedHits[0].record.memoryId).assertEqual(first.memoryId);
        expect(reembeddedHits[0].record.fact).assertEqual('blob-first-reembedded-e1');
        expect(reembeddedHits[0].score).assertEqual(1);

        const removed = await store.remove(BLOB_OWNER_ID, first.memoryId);
        expect(removed === null).assertFalse();
        expect(await store.get(BLOB_OWNER_ID, first.memoryId) === null).assertTrue();
        expect(await blobHistoryCount(context, first.memoryId)).assertEqual(0);

        await store.setMetadata('device_test_marker', 'ready');
        expect(await store.getMetadata('device_test_marker')).assertEqual('ready');

        await store.clearAll();
        expect(await blobTableCount(context, PHONE_LOCAL_MEMORY_BLOB_TABLE)).assertEqual(0);
        expect(await blobTableCount(context, PHONE_LOCAL_MEMORY_BLOB_HISTORY_TABLE)).assertEqual(0);
        expect(await blobTableCount(context, PHONE_LOCAL_MEMORY_BLOB_METADATA_TABLE)).assertEqual(1);
        expect(await store.getMetadata('device_test_marker') === null).assertTrue();
        expect(await store.getMetadata(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION_KEY))
          .assertEqual(PHONE_LOCAL_MEMORY_BLOB_SCHEMA_VERSION);
      } finally {
        if (initialized) await store.clearAll();
      }
    });

    it('satisfies the cosine index query contract for scoped database top-k', 0, async () => {
      const context = await testAbilityContext();
      const store = new ArkDataPhoneLocalMemoryStore(context);
      let initialized: boolean = false;
      try {
        // initialize() proves the FLOATVECTOR table and COSINE GSDISKANN DDL are accepted.
        await store.initialize();
        initialized = true;
        await store.removeAll(VECTOR_OWNER_ID, []);
        await store.removeAll(OTHER_OWNER_ID, []);

        let nextId: number = 0;
        const memory = new PhoneLocalMemoryProvider(store, new ControlledEmbeddingPort(), {
          allowedSceneIds: [TARGET_SCENE_ID, OTHER_SCENE_ID],
          idFactory: (): string => 'vector-device-memory-' + nextId++
        });

        const scopedRecords = await memory.remember({
          ownerId: VECTOR_OWNER_ID,
          records: [
            { fact: BEST_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-best' },
            { fact: SECOND_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-second' },
            { fact: ORTHOGONAL_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-orthogonal' },
            { fact: WRONG_SCENE_FACT, sceneId: OTHER_SCENE_ID, sourceTurnId: 'vector-turn-other-scene' }
          ]
        });
        expect(scopedRecords.status).assertEqual('success');
        expect(scopedRecords.succeededCount).assertEqual(4);

        const otherOwnerRecord = await memory.remember({
          ownerId: OTHER_OWNER_ID,
          records: [
            { fact: WRONG_OWNER_FACT, sceneId: TARGET_SCENE_ID, sourceTurnId: 'vector-turn-other-owner' }
          ]
        });
        expect(otherOwnerRecord.status).assertEqual('success');
        expect(otherOwnerRecord.succeededCount).assertEqual(1);

        const hits = await memory.search({
          ownerId: VECTOR_OWNER_ID,
          text: QUERY_TEXT,
          sceneIds: [TARGET_SCENE_ID],
          topK: 2
        });

        expect(hits.length).assertEqual(2);
        expect(hits[0].record.fact).assertEqual(BEST_FACT);
        expect(hits[1].record.fact).assertEqual(SECOND_FACT);
        expect(hits[0].score > hits[1].score).assertTrue();
        expect(hits[0].record.ownerId).assertEqual(VECTOR_OWNER_ID);
        expect(hits[1].record.ownerId).assertEqual(VECTOR_OWNER_ID);
        expect(hits[0].record.sceneId).assertEqual(TARGET_SCENE_ID);
        expect(hits[1].record.sceneId).assertEqual(TARGET_SCENE_ID);
      } finally {
        if (initialized) {
          await store.removeAll(VECTOR_OWNER_ID, []);
          await store.removeAll(OTHER_OWNER_ID, []);
        }
      }
    });

    it('loads the packaged BGE model and produces one finite 512-dimensional embedding', 0, async () => {
      const context = await testAbilityContext();
      const tokenizer = await BertWordPieceTokenizer.fromRawfile(context);
      const embedder = await BgeMindSporeEmbeddingPort.fromRawfile(context, tokenizer);
      const embedding = await embedder.embed('本地记忆模型真机冒烟测试');

      expect(embedding.length).assertEqual(BGE_SMALL_ZH_EMBEDDING_DIMENSION);
      expect(allFinite(embedding)).assertTrue();
    });
  });
}
