import { describe, expect, it } from '@ohos/hypium';
import { EmbeddingPort, MemoryCommitGuard, MemoryHit, MemoryRecord } from '@loop/agent-core';
import {
  PHONE_LOCAL_MEMORY_BLOB_CLAIM_HISTORY_OWNER_SQL,
  PHONE_LOCAL_MEMORY_BLOB_CLAIM_OWNER_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_FACTS_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_INDEX_SQL,
  PHONE_LOCAL_MEMORY_BLOB_PROJECTION_STATS_SQL
} from '../main/ets/memory/PhoneLocalMemoryBlobFallbackPort';
import {
  PHONE_LOCAL_MEMORY_CLAIM_HISTORY_OWNER_SQL,
  PHONE_LOCAL_MEMORY_CLAIM_OWNER_SQL,
  PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL,
  PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL,
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats,
  PhoneLocalMemorySearchRequest,
  PhoneLocalMemoryStore
} from '../main/ets/memory/PhoneLocalMemoryStore';
import {
  PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
  PHONE_LOCAL_MEMORY_OWNER_ID,
  PhoneLocalMemoryMutationEvent,
  PhoneLocalMemoryRuntime
} from '../main/ets/memory/PhoneLocalMemoryRuntime';

function projectionRecord(memoryId: string, ownerId: string, sceneId: string,
  fact: string, updatedAt: number): MemoryRecord {
  const embedding: number[] = new Array<number>(512).fill(0);
  embedding[0] = 1;
  return {
    memoryId,
    ownerId,
    sceneId,
    personaTag: 'work_companion',
    authority: 'leader',
    fact,
    normalizedFact: fact,
    factHash: 'hash-' + memoryId,
    embedding,
    embeddingProfileId: 'projection-test',
    sourceTurnId: 'turn-' + memoryId,
    createdAt: updatedAt,
    updatedAt
  };
}

class ProjectionEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'projection-test';
  readonly dimension: number = 512;
  calls: number = 0;

  async embed(_text: string): Promise<number[]> {
    this.calls += 1;
    const embedding: number[] = new Array<number>(512).fill(0);
    embedding[0] = 1;
    return embedding;
  }
}

class ProjectionMemoryStore implements PhoneLocalMemoryStore {
  records: MemoryRecord[] = [];
  statsOwnerId: string = '';
  statsSceneId: string = '';
  factsOwnerId: string = '';
  factsSceneId: string = '';

  async initialize(): Promise<void> {}

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId === ownerId && record.embeddingProfileId === embeddingProfileId &&
        record.factHash === factHash && record.normalizedFact === normalizedFact) return record;
    }
    return null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === memoryId) {
        return this.records[index];
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
      output.push(record);
    }
    return output;
  }

  async getProjectionStats(ownerId: string, sceneId: string,
    basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    this.statsOwnerId = ownerId;
    this.statsSceneId = sceneId;
    const facts = await this.listProjectionFacts(ownerId, sceneId);
    let changedCount: number = 0;
    let oldestPendingUpdatedAt: number | null = null;
    for (let index = 0; index < facts.length; index += 1) {
      if (facts[index].updatedAt <= basedOnMemoryMutationAt) continue;
      changedCount += 1;
      oldestPendingUpdatedAt = oldestPendingUpdatedAt === null ? facts[index].updatedAt :
        Math.min(oldestPendingUpdatedAt, facts[index].updatedAt);
    }
    return { changedCount, oldestPendingUpdatedAt };
  }

  async listProjectionFacts(ownerId: string, sceneId: string): Promise<PhoneLocalMemoryProjectionFact[]> {
    this.factsOwnerId = ownerId;
    this.factsSceneId = sceneId;
    const output: PhoneLocalMemoryProjectionFact[] = [];
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId !== ownerId || record.sceneId !== sceneId || record.authority !== 'leader') continue;
      output.push({
        memoryId: record.memoryId,
        fact: record.fact,
        personaTag: record.personaTag,
        authority: record.authority,
        updatedAt: record.updatedAt
      });
    }
    return output;
  }

  async search(_request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    return [];
  }

  async insert(record: MemoryRecord, _guard?: MemoryCommitGuard): Promise<void> {
    this.records.push(record);
  }

  async replace(ownerId: string, record: MemoryRecord, _guard?: MemoryCommitGuard): Promise<void> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === record.memoryId) {
        this.records[index] = record;
        return;
      }
    }
    throw new Error('not found');
  }

  async remove(ownerId: string, memoryId: string,
    _guard?: MemoryCommitGuard): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId !== ownerId || this.records[index].memoryId !== memoryId) continue;
      const record = this.records[index];
      this.records.splice(index, 1);
      return record;
    }
    return null;
  }

  async removeAll(ownerId: string, sceneIds: string[]): Promise<MemoryRecord[]> {
    const records = await this.list(ownerId, sceneIds);
    for (let index = 0; index < records.length; index += 1) {
      await this.remove(ownerId, records[index].memoryId);
    }
    return records;
  }

  async replaceByPersonaTag(ownerId: string, sceneId: string, personaTag: string,
    replacements: MemoryRecord[], _guard?: MemoryCommitGuard): Promise<MemoryRecord[]> {
    const removed: MemoryRecord[] = [];
    const retained: MemoryRecord[] = [];
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId === ownerId && record.sceneId === sceneId && record.personaTag === personaTag) {
        removed.push(record);
      } else {
        retained.push(record);
      }
    }
    this.records = retained.concat(replacements);
    return removed;
  }

  async claimOwner(fromOwnerId: string, toOwnerId: string): Promise<number> {
    let claimed: number = 0;
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId !== fromOwnerId) continue;
      this.records[index].ownerId = toOwnerId;
      claimed += 1;
    }
    return claimed;
  }

  async getMetadata(_key: string): Promise<string | null> {
    return null;
  }

  async setMetadata(_key: string, _value: string): Promise<void> {}
}

export default function phoneLocalMemoryProjectionSourceTest() {
  describe('PhoneLocalMemoryProjectionSource', () => {
    it('uses indexed scalar queries that never select embeddings', 0, () => {
      expect(PHONE_LOCAL_MEMORY_PROJECTION_STATS_SQL).assertContain(
        "owner_id = ? AND scene_id = ? AND authority = 'leader' AND updated_at > ?"
      );
      expect(PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL).assertContain(
        'memory_id, fact, persona_tag, authority, updated_at'
      );
      expect(PHONE_LOCAL_MEMORY_PROJECTION_FACTS_SQL.indexOf('embedding')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_STATS_SQL).assertContain(
        "owner_id = ? AND scene_id = ? AND authority = 'leader' AND updated_at > ?"
      );
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_FACTS_SQL.indexOf('embedding')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_BLOB_PROJECTION_INDEX_SQL).assertContain(
        'owner_id, scene_id, updated_at'
      );
    });

    it('claims current records and history rows for both persistence backends', 0, () => {
      expect(PHONE_LOCAL_MEMORY_CLAIM_OWNER_SQL).assertContain(
        'UPDATE conversation_memory SET owner_id = ? WHERE owner_id = ?');
      expect(PHONE_LOCAL_MEMORY_CLAIM_HISTORY_OWNER_SQL).assertContain(
        'UPDATE conversation_memory_history SET owner_id = ? WHERE owner_id = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_CLAIM_OWNER_SQL).assertContain(
        'UPDATE conversation_memory_blob SET owner_id = ? WHERE owner_id = ?');
      expect(PHONE_LOCAL_MEMORY_BLOB_CLAIM_HISTORY_OWNER_SQL).assertContain(
        'UPDATE conversation_memory_blob_history SET owner_id = ? WHERE owner_id = ?');
    });

    it('reads only the fixed local owner and global scene without loading the embedder', 0, async () => {
      const store = new ProjectionMemoryStore();
      store.records.push(projectionRecord('old', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '用户喜欢人工智能。', 100));
      store.records.push(projectionRecord('new', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '用户喜欢编程。', 300));
      store.records.push(projectionRecord('legacy-scene', PHONE_LOCAL_MEMORY_OWNER_ID,
        'travel_companion', '用户偏好高铁。', 400));
      store.records.push(projectionRecord('other-owner', 'other-owner',
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '其他用户偏好。', 500));
      const legacySeed = projectionRecord('legacy-seed', PHONE_LOCAL_MEMORY_OWNER_ID,
        PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID, '旧测试种子偏好。', 600);
      legacySeed.authority = 'seed';
      store.records.push(legacySeed);
      const embedder = new ProjectionEmbeddingPort();
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => embedder
      });

      const stats = await runtime.getProjectionStats(150);
      const facts = await runtime.listProjectionFacts();

      expect(stats.changedCount).assertEqual(1);
      expect(stats.oldestPendingUpdatedAt ?? 0).assertEqual(300);
      expect(facts.length).assertEqual(2);
      expect(store.statsOwnerId).assertEqual(PHONE_LOCAL_MEMORY_OWNER_ID);
      expect(store.statsSceneId).assertEqual(PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID);
      expect(store.factsOwnerId).assertEqual(PHONE_LOCAL_MEMORY_OWNER_ID);
      expect(store.factsSceneId).assertEqual(PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID);
      expect(embedder.calls).assertEqual(0);
    });

    it('reports successful mutations asynchronously without blocking memory results', 0, async () => {
      const store = new ProjectionMemoryStore();
      const events: PhoneLocalMemoryMutationEvent[] = [];
      const neverCompletes = new Promise<void>((_resolve: () => void): void => {});
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new ProjectionEmbeddingPort(),
        idFactory: (): string => 'memory-event',
        onMutationCommitted: async (event: PhoneLocalMemoryMutationEvent): Promise<void> => {
          events.push(event);
          await neverCompletes;
        }
      });

      const remembered = await runtime.remember(['用户喜欢人工智能。'], 'turn-event', 'work_companion');
      await Promise.resolve<void>(undefined);

      expect(remembered.status).assertEqual('success');
      expect(events.length).assertEqual(1);
      expect(events[0].operation).assertEqual('remember');
      expect(events[0].memoryIds[0]).assertEqual('memory-event');
      expect(events[0].committedAt > 0).assertTrue();
    });

    it('publishes one update event for all successful records in a partial batch', 0, async () => {
      const store = new ProjectionMemoryStore();
      store.records.push(projectionRecord(
        'memory-update-a', PHONE_LOCAL_MEMORY_OWNER_ID, PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        '用户喝咖啡时不加糖。', 100
      ));
      store.records.push(projectionRecord(
        'memory-update-b', PHONE_LOCAL_MEMORY_OWNER_ID, PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        '用户通勤时偏好公交。', 200
      ));
      const events: PhoneLocalMemoryMutationEvent[] = [];
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new ProjectionEmbeddingPort(),
        onMutationCommitted: async (event: PhoneLocalMemoryMutationEvent): Promise<void> => {
          events.push(event);
        }
      });

      const updated = await runtime.update([{
        memoryId: 'memory-update-a', fact: '用户喝咖啡时选择半糖。'
      }, {
        memoryId: 'missing-memory', fact: '这条不存在的记忆不会被更新。'
      }, {
        memoryId: 'memory-update-b', fact: '用户通勤时偏好地铁。'
      }], 'turn-update-batch', 'travel_companion');
      await Promise.resolve<void>(undefined);
      const updatedA = await store.get(PHONE_LOCAL_MEMORY_OWNER_ID, 'memory-update-a');
      const updatedB = await store.get(PHONE_LOCAL_MEMORY_OWNER_ID, 'memory-update-b');
      const maximumUpdatedAt: number = Math.max(updatedA?.updatedAt ?? 0, updatedB?.updatedAt ?? 0);

      expect(updated.status).assertEqual('success');
      expect(updated.succeededCount).assertEqual(2);
      expect(updated.failedCount).assertEqual(1);
      expect(events.length).assertEqual(1);
      expect(events[0].operation).assertEqual('update');
      expect(events[0].memoryIds.join(','))
        .assertEqual('memory-update-a,memory-update-b');
      expect(events[0].committedAt).assertEqual(maximumUpdatedAt);
    });

    it('publishes one forget event for all successful records in a partial batch', 0, async () => {
      const store = new ProjectionMemoryStore();
      store.records.push(projectionRecord(
        'memory-forget-a', PHONE_LOCAL_MEMORY_OWNER_ID, PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        '用户喜欢人工智能。', 100
      ));
      store.records.push(projectionRecord(
        'memory-forget-b', PHONE_LOCAL_MEMORY_OWNER_ID, PHONE_LOCAL_MEMORY_GLOBAL_SCENE_ID,
        '用户喜欢开源硬件。', 200
      ));
      const events: PhoneLocalMemoryMutationEvent[] = [];
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new ProjectionEmbeddingPort(),
        onMutationCommitted: async (event: PhoneLocalMemoryMutationEvent): Promise<void> => {
          events.push(event);
        }
      });

      const forgotten = await runtime.forget([
        'memory-forget-a', 'missing-memory', 'memory-forget-b'
      ]);
      await Promise.resolve<void>(undefined);

      expect(forgotten.status).assertEqual('success');
      expect(forgotten.succeededCount).assertEqual(2);
      expect(forgotten.failedCount).assertEqual(1);
      expect(events.length).assertEqual(1);
      expect(events[0].operation).assertEqual('forget');
      expect(events[0].memoryIds.join(',')).assertEqual('memory-forget-a,memory-forget-b');
      expect(events[0].committedAt > 0).assertTrue();
    });

    it('publishes one projection event for each whole public persona replace or delete', 0, async () => {
      const store = new ProjectionMemoryStore();
      const events: PhoneLocalMemoryMutationEvent[] = [];
      let nextId: number = 0;
      const runtime = new PhoneLocalMemoryRuntime(null, {
        storeFactory: (): PhoneLocalMemoryStore => store,
        embedderFactory: async (): Promise<EmbeddingPort> => new ProjectionEmbeddingPort(),
        idFactory: (): string => 'persona-memory-' + (++nextId).toString(),
        onMutationCommitted: async (event: PhoneLocalMemoryMutationEvent): Promise<void> => {
          events.push(event);
        }
      });

      const initialFacts: string[] = [];
      for (let index = 0; index < 7; index += 1) {
        initialFacts.push('用户公开资料中的高置信度事实 ' + index.toString() + '。');
      }
      const initial = await runtime.replacePublicPersonaFacts(
        initialFacts, 'persona-import-1'
      );
      await Promise.resolve<void>(undefined);
      const replaced = await runtime.replacePublicPersonaFacts(
        ['用户公开资料显示喜欢开源硬件。'], 'persona-import-2'
      );
      await Promise.resolve<void>(undefined);
      const deleted = await runtime.deletePublicPersonaFacts();
      await Promise.resolve<void>(undefined);

      expect(initial.status).assertEqual('success');
      expect(initial.succeededCount).assertEqual(7);
      expect(replaced.status).assertEqual('success');
      expect(replaced.succeededCount).assertEqual(1);
      expect(deleted.status).assertEqual('success');
      expect(deleted.succeededCount).assertEqual(1);
      expect(events.length).assertEqual(3);
      expect(events[0].operation).assertEqual('remember');
      expect(events[0].memoryIds.length).assertEqual(7);
      expect(events[1].operation).assertEqual('forget');
      expect(events[1].memoryIds.length).assertEqual(8);
      expect(events[2].operation).assertEqual('forget');
      expect(events[2].memoryIds.length).assertEqual(1);
      expect(store.records.length).assertEqual(0);
    });
  });
}
