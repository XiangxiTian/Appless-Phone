import { describe, expect, it } from '@ohos/hypium';
import {
  EmbeddingPort,
  MemoryHit,
  MemoryCommitGuard,
  MemoryRecord,
  MemoryRememberRequest
} from '@loop/agent-core';
import {
  buildPhoneLocalMemorySearchSql,
  PHONE_LOCAL_MEMORY_DELETE_SQL,
  PHONE_LOCAL_MEMORY_HISTORY_SCHEMA_SQL,
  PHONE_LOCAL_MEMORY_DELETE_HISTORY_SQL,
  PHONE_LOCAL_MEMORY_MAX_CANDIDATE_LIMIT,
  PHONE_LOCAL_MEMORY_MIN_CANDIDATE_LIMIT,
  PHONE_LOCAL_MEMORY_INSERT_SQL,
  PHONE_LOCAL_MEMORY_OPERATION_CANCELED,
  PHONE_LOCAL_MEMORY_DEDUPE_INDEX_SQL,
  PHONE_LOCAL_MEMORY_METADATA_SCHEMA_SQL,
  PHONE_LOCAL_MEMORY_SCHEMA_SQL,
  PHONE_LOCAL_MEMORY_UPDATE_SQL,
  PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL,
  phoneLocalMemoryCandidateLimit,
  PhoneLocalMemorySearchRequest,
  PhoneLocalMemoryStore
} from '../main/ets/memory/PhoneLocalMemoryStore';
import {
  PhoneLocalMemoryLogContext,
  PhoneLocalMemoryLogger,
  PhoneLocalMemoryProvider
} from '../main/ets/memory/PhoneLocalMemoryProvider';

function copyRecord(record: MemoryRecord): MemoryRecord {
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

class FakeEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'bge-small-zh-v1.5:test';
  readonly dimension: number = 512;
  calls: string[] = [];

  async embed(text: string): Promise<number[]> {
    this.calls.push(text);
    const vector: number[] = new Array<number>(this.dimension).fill(0);
    if (text.indexOf('无糖') >= 0 || text.indexOf('不要糖') >= 0 || text.indexOf('咖啡') >= 0) {
      vector[0] = 1;
    }
    if (text.indexOf('博物馆') >= 0 || text.indexOf('旅行') >= 0) vector[1] = 1;
    if (vector[0] === 0 && vector[1] === 0) vector[2] = 1;
    return vector;
  }
}

class FailingEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'bge-small-zh-v1.5:test';
  readonly dimension: number = 512;

  async embed(text: string): Promise<number[]> {
    throw new Error('embedding failed for ' + text);
  }
}

class MutableMemoryCommitGuard implements MemoryCommitGuard {
  active: boolean = true;

  isActive(): boolean {
    return this.active;
  }
}

function requireFakeCommit(guard?: MemoryCommitGuard): void {
  if (guard !== undefined && !guard.isActive()) {
    throw new Error(PHONE_LOCAL_MEMORY_OPERATION_CANCELED);
  }
}

class MemoryTestGate {
  readonly promise: Promise<void>;
  private releasePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void): void => {
      this.releasePromise = resolve;
    });
  }

  open(): void {
    const release = this.releasePromise;
    this.releasePromise = null;
    if (release !== null) release();
  }
}

class CancelingEmbeddingPort implements EmbeddingPort {
  readonly profileId: string = 'bge-small-zh-v1.5:test';
  readonly dimension: number = 512;
  calls: number = 0;
  private guard: MutableMemoryCommitGuard;
  private cancelOnCall: number;

  constructor(guard: MutableMemoryCommitGuard, cancelOnCall: number) {
    this.guard = guard;
    this.cancelOnCall = cancelOnCall;
  }

  async embed(_text: string): Promise<number[]> {
    this.calls += 1;
    const vector: number[] = new Array<number>(this.dimension).fill(0);
    vector[0] = 1;
    if (this.calls === this.cancelOnCall) this.guard.active = false;
    return vector;
  }
}

class CapturingMemoryLogger implements PhoneLocalMemoryLogger {
  entries: PhoneLocalMemoryLogContext[] = [];

  warn(context: PhoneLocalMemoryLogContext): void {
    this.entries.push(context);
  }
}

class FakeMemoryStore implements PhoneLocalMemoryStore {
  records: MemoryRecord[] = [];
  failFact: string = '';
  searchCalls: PhoneLocalMemorySearchRequest[] = [];
  metadata: Map<string, string> = new Map<string, string>();
  insertHook: (() => void) | null = null;

  async initialize(): Promise<void> {}

  async findByFact(ownerId: string, embeddingProfileId: string, factHash: string,
    normalizedFact: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      const record = this.records[index];
      if (record.ownerId === ownerId && record.embeddingProfileId === embeddingProfileId &&
        record.factHash === factHash &&
        record.normalizedFact === normalizedFact) return copyRecord(record);
    }
    return null;
  }

  async get(ownerId: string, memoryId: string): Promise<MemoryRecord | null> {
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId === ownerId && this.records[index].memoryId === memoryId) {
        return copyRecord(this.records[index]);
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
      output.push(copyRecord(record));
    }
    return output;
  }

  async search(request: PhoneLocalMemorySearchRequest): Promise<MemoryHit[]> {
    this.searchCalls.push({
      ownerId: request.ownerId,
      sceneIds: request.sceneIds.slice(),
      embeddingProfileId: request.embeddingProfileId,
      queryEmbedding: request.queryEmbedding.slice(),
      topK: request.topK,
      minScore: request.minScore
    });
    const records = await this.list(request.ownerId, request.sceneIds);
    const hits: MemoryHit[] = [];
    for (let index = 0; index < records.length; index += 1) {
      const record = records[index];
      if (record.embeddingProfileId !== request.embeddingProfileId) continue;
      if (record.embedding.length !== request.queryEmbedding.length) continue;
      let score = 0;
      for (let vectorIndex = 0; vectorIndex < record.embedding.length; vectorIndex += 1) {
        score += record.embedding[vectorIndex] * request.queryEmbedding[vectorIndex];
      }
      if (request.minScore !== undefined && score < request.minScore) continue;
      hits.push({ record, score });
    }
    hits.sort((left: MemoryHit, right: MemoryHit): number => right.score - left.score);
    return hits.slice(0, request.topK);
  }

  async insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    requireFakeCommit(guard);
    if (record.fact === this.failFact) throw new Error('injected insert failure');
    // Keep the fake's uniqueness check and commit in one synchronous section. The real RDB
    // enforces this with a unique index while holding the store write mutex; awaiting the
    // async lookup here would yield and let two test inserts both observe an empty store.
    for (let index = 0; index < this.records.length; index += 1) {
      const existing = this.records[index];
      if (existing.ownerId === record.ownerId && existing.embeddingProfileId === record.embeddingProfileId &&
        existing.factHash === record.factHash && existing.normalizedFact === record.normalizedFact) {
        throw new Error('injected unique constraint');
      }
    }
    if (this.insertHook !== null) this.insertHook();
    this.records.push(copyRecord(record));
  }

  async replace(ownerId: string, record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    requireFakeCommit(guard);
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId !== ownerId || this.records[index].memoryId !== record.memoryId) continue;
      this.records[index] = copyRecord(record);
      return;
    }
    throw new Error('missing record');
  }

  async remove(ownerId: string, memoryId: string,
    guard?: MemoryCommitGuard): Promise<MemoryRecord | null> {
    requireFakeCommit(guard);
    for (let index = 0; index < this.records.length; index += 1) {
      if (this.records[index].ownerId !== ownerId || this.records[index].memoryId !== memoryId) continue;
      const deleted = this.records[index];
      this.records.splice(index, 1);
      return copyRecord(deleted);
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

class LockWaitingMemoryStore extends FakeMemoryStore {
  readonly firstCommitStarted: MemoryTestGate = new MemoryTestGate();
  readonly secondCommitWaiting: MemoryTestGate = new MemoryTestGate();
  readonly releaseFirstCommit: MemoryTestGate = new MemoryTestGate();
  private insertCount: number = 0;

  async insert(record: MemoryRecord, guard?: MemoryCommitGuard): Promise<void> {
    this.insertCount++;
    if (this.insertCount === 1) {
      this.firstCommitStarted.open();
      await this.releaseFirstCommit.promise;
    } else {
      this.secondCommitWaiting.open();
      await this.releaseFirstCommit.promise;
    }
    requireFakeCommit(guard);
    await super.insert(record, guard);
  }
}

function provider(store: FakeMemoryStore, embedder: EmbeddingPort): PhoneLocalMemoryProvider {
  let nextId = 0;
  let now = 1000;
  return new PhoneLocalMemoryProvider(store, embedder, {
    allowedSceneIds: ['global', 'food_companion', 'travel_companion'],
    idFactory: (): string => 'memory-' + (++nextId).toString(),
    clock: (): number => ++now
  });
}

export default function phoneLocalMemoryProviderTest() {
  describe('PhoneLocalMemoryProvider', () => {
    it('declares only the persistent vector schema and cosine ANN index', 0, () => {
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL).assertContain('FLOATVECTOR(512)');
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL.indexOf('BLOB')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL).assertContain('owner_id TEXT NOT NULL');
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL).assertContain('scene_id TEXT NOT NULL');
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL).assertContain('persona_tag TEXT NOT NULL');
      expect(PHONE_LOCAL_MEMORY_SCHEMA_SQL).assertContain('authority TEXT NOT NULL');
      expect(PHONE_LOCAL_MEMORY_HISTORY_SCHEMA_SQL).assertContain('operation TEXT NOT NULL');
      expect(PHONE_LOCAL_MEMORY_METADATA_SCHEMA_SQL).assertContain('metadata_key TEXT PRIMARY KEY');
      expect(PHONE_LOCAL_MEMORY_DEDUPE_INDEX_SQL).assertContain(
        'owner_id, embedding_profile_id, fact_hash, normalized_fact'
      );
      expect(PHONE_LOCAL_MEMORY_DEDUPE_INDEX_SQL.indexOf('scene_id')).assertEqual(-1);
      expect(PHONE_LOCAL_MEMORY_DELETE_HISTORY_SQL).assertContain('owner_id = ? AND memory_id = ?');
      expect(PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL).assertContain('USING GSDISKANN(embedding COSINE)');
      expect(PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL).assertContain('queue_size=20');
      expect(PHONE_LOCAL_MEMORY_VECTOR_INDEX_SQL).assertContain('out_degree=60');
    });

    it('declares execute-compatible scoped DML and database-side cosine topK SQL', 0, () => {
      expect(PHONE_LOCAL_MEMORY_INSERT_SQL).assertContain('INSERT INTO conversation_memory');
      expect(PHONE_LOCAL_MEMORY_UPDATE_SQL).assertContain('WHERE owner_id = ? AND memory_id = ?');
      expect(PHONE_LOCAL_MEMORY_DELETE_SQL).assertContain('WHERE owner_id = ? AND memory_id = ?');
      const searchSql = buildPhoneLocalMemorySearchSql(100);
      expect(searchSql).assertContain('ORDER BY embedding <=> ? LIMIT 100');
      expect(searchSql.indexOf('LIMIT ?')).assertEqual(-1);
      expect(searchSql.indexOf(' WHERE ')).assertEqual(-1);
      expect(buildPhoneLocalMemorySearchSql(0)).assertContain('LIMIT 100');
      expect(buildPhoneLocalMemorySearchSql(5000)).assertContain('LIMIT 1000');
      expect(PHONE_LOCAL_MEMORY_MIN_CANDIDATE_LIMIT).assertEqual(100);
      expect(PHONE_LOCAL_MEMORY_MAX_CANDIDATE_LIMIT).assertEqual(1000);
      expect(phoneLocalMemoryCandidateLimit(2)).assertEqual(100);
      expect(phoneLocalMemoryCandidateLimit(20)).assertEqual(200);
      expect(phoneLocalMemoryCandidateLimit(100)).assertEqual(1000);
    });

    it('keeps successful records when one best-effort insert fails', 0, async () => {
      const store = new FakeMemoryStore();
      store.failFact = '这一条故意失败';
      const result = await provider(store, new FakeEmbeddingPort()).remember({
        ownerId: 'owner-1',
        records: [
          { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' },
          { fact: '这一条故意失败', sceneId: 'global', sourceTurnId: 'turn-1' },
          { fact: '用户旅行时偏好高铁', sceneId: 'travel_companion', sourceTurnId: 'turn-1' }
        ]
      });

      expect(result.status).assertEqual('success');
      expect(result.succeededCount).assertEqual(2);
      expect(result.failedCount).assertEqual(1);
      expect(result.warnings.length).assertEqual(1);
      expect(store.records.length).assertEqual(2);
    });

    it('deduplicates the same normalized fact across scenes inside one owner and profile', 0, async () => {
      const store = new FakeMemoryStore();
      const embedder = new FakeEmbeddingPort();
      const memory = provider(store, embedder);
      const first = await memory.remember({
        ownerId: 'owner-1',
        records: [{ fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' }]
      });
      const second = await memory.remember({
        ownerId: 'owner-1',
        records: [{ fact: '  用户喝咖啡不要糖  ', sceneId: 'travel_companion', sourceTurnId: 'turn-2' }]
      });

      expect(first.status).assertEqual('success');
      expect(second.status).assertEqual('success');
      expect(store.records.length).assertEqual(1);
      expect(embedder.calls.length).assertEqual(1);
      expect(second.records[0].record?.memoryId).assertEqual(first.records[0].record?.memoryId);
    });

    it('keeps valid records when another record fails structural validation', 0, async () => {
      const store = new FakeMemoryStore();
      const result = await provider(store, new FakeEmbeddingPort()).remember({
        ownerId: 'owner-1',
        records: [
          { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' },
          { fact: '这条记忆属于未知场景', sceneId: 'unknown', sourceTurnId: 'turn-1' },
          { fact: '用户旅行时偏好高铁', sceneId: 'travel_companion', sourceTurnId: 'turn-1' }
        ]
      });
      expect(result.status).assertEqual('success');
      expect(result.succeededCount).assertEqual(2);
      expect(result.failedCount).assertEqual(1);
      expect(store.records.length).assertEqual(2);
    });

    it('recovers a concurrent exact duplicate as idempotent success', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      const request: MemoryRememberRequest = {
        ownerId: 'owner-1',
        records: [{ fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' }]
      };
      const results = await Promise.all([memory.remember(request), memory.remember(request)]);
      expect(results[0].status).assertEqual('success');
      expect(results[1].status).assertEqual('success');
      expect(store.records.length).assertEqual(1);
    });

    it('stops a best-effort batch before commit when its generation guard is canceled', 0, async () => {
      const store = new FakeMemoryStore();
      const guard = new MutableMemoryCommitGuard();
      const embedder = new CancelingEmbeddingPort(guard, 2);
      const result = await provider(store, embedder).remember({
        ownerId: 'owner-1', records: [
          { fact: '第一条长期事实', sceneId: 'global', sourceTurnId: 'turn-1' },
          { fact: '第二条长期事实', sceneId: 'global', sourceTurnId: 'turn-1' },
          { fact: '第三条长期事实', sceneId: 'global', sourceTurnId: 'turn-1' }
        ]
      }, guard);

      expect(result.status).assertEqual('success');
      expect(result.succeededCount).assertEqual(1);
      expect(result.failedCount).assertEqual(2);
      expect(result.records[1].error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(result.records[2].error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(store.records.length).assertEqual(1);
      expect(embedder.calls).assertEqual(2);
    });

    it('maps a guard canceled while waiting for the store lock without a second commit', 0,
      async () => {
      const store = new LockWaitingMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      const firstGuard = new MutableMemoryCommitGuard();
      const waitingGuard = new MutableMemoryCommitGuard();
      const first = memory.remember({ ownerId: 'owner-1', records: [{
        fact: '用户喝咖啡时选择无糖。', sceneId: 'global', sourceTurnId: 'turn-lock-1'
      }] }, firstGuard);
      await store.firstCommitStarted.promise;
      const waiting = memory.remember({ ownerId: 'owner-1', records: [{
        fact: '用户旅行时偏好参观博物馆。', sceneId: 'global', sourceTurnId: 'turn-lock-2'
      }] }, waitingGuard);
      await store.secondCommitWaiting.promise;

      waitingGuard.active = false;
      store.releaseFirstCommit.open();
      const results = await Promise.all([first, waiting]);

      expect(results[0].status).assertEqual('success');
      expect(results[1].status).assertEqual('error');
      expect(results[1].records[0].error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(store.records.length).assertEqual(1);
      expect(store.records[0].fact).assertEqual('用户喝咖啡时选择无糖。');
    });

    it('does not interrupt a write after the store transaction boundary is entered', 0, async () => {
      const store = new FakeMemoryStore();
      const guard = new MutableMemoryCommitGuard();
      store.insertHook = (): void => { guard.active = false; };
      const result = await provider(store, new FakeEmbeddingPort()).remember({
        ownerId: 'owner-1', records: [
          { fact: '事务开始后仍应完成的事实', sceneId: 'global', sourceTurnId: 'turn-1' }
        ]
      }, guard);

      expect(result.status).assertEqual('success');
      expect(store.records.length).assertEqual(1);
      expect(guard.active).assertFalse();
    });

    it('hard-filters owner and scene before semantic ranking', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      await memory.remember({ ownerId: 'owner-1', records: [
        { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' },
        { fact: '用户去过咖啡博物馆', sceneId: 'travel_companion', sourceTurnId: 'turn-2' }
      ] });
      await memory.remember({ ownerId: 'owner-2', records: [
        { fact: '其他用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-3' }
      ] });

      const hits = await memory.search({
        ownerId: 'owner-1', text: '帮我点一杯无糖咖啡', sceneIds: ['food_companion'], topK: 5
      });
      expect(hits.length).assertEqual(1);
      expect(hits[0].record.ownerId).assertEqual('owner-1');
      expect(hits[0].record.sceneId).assertEqual('food_companion');
      expect(hits[0].record.fact).assertEqual('用户喝咖啡不要糖');
      expect(store.searchCalls.length).assertEqual(1);
      expect(store.searchCalls[0].embeddingProfileId).assertEqual('bge-small-zh-v1.5:test');
      expect(store.searchCalls[0].topK).assertEqual(5);
    });

    it('uses the trimmed owner consistently for storage and ranking', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      await memory.remember({ ownerId: 'owner-1', records: [
        { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' }
      ] });
      const hits = await memory.search({
        ownerId: ' owner-1 ', text: '无糖咖啡', sceneIds: ['food_companion'], topK: 3
      });
      expect(hits.length).assertEqual(1);
    });

    it('searches all scenes for one owner when sceneIds is empty', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      await memory.remember({ ownerId: 'owner-1', records: [
        { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' },
        { fact: '用户去过咖啡博物馆', sceneId: 'travel_companion', sourceTurnId: 'turn-2' }
      ] });
      await memory.remember({ ownerId: 'owner-2', records: [
        { fact: '其他用户也去过咖啡博物馆', sceneId: 'travel_companion', sourceTurnId: 'turn-3' }
      ] });

      const hits = await memory.search({
        ownerId: 'owner-1', text: '咖啡', sceneIds: [], topK: 5
      });
      expect(hits.length).assertEqual(2);
      expect(hits[0].record.ownerId).assertEqual('owner-1');
      expect(hits[1].record.ownerId).assertEqual('owner-1');
      expect(store.searchCalls[0].sceneIds.length).assertEqual(0);
    });

    it('caps provider search to the public recall maximum of twenty results', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      await memory.search({
        ownerId: 'owner-1', text: '无糖咖啡', sceneIds: [], topK: 1000
      });
      expect(store.searchCalls.length).assertEqual(1);
      expect(store.searchCalls[0].topK).assertEqual(20);
    });

    it('updates one record and forgets it by exact memory id', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      const added = await memory.remember({ ownerId: 'owner-1', records: [
        { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' }
      ] });
      const memoryId = added.records[0].record?.memoryId ?? '';
      const updated = await memory.update({
        ownerId: 'owner-1', memoryId, fact: '用户喝咖啡时偏好半糖', sourceTurnId: 'turn-2'
      });
      expect(updated.status).assertEqual('success');
      expect(updated.record?.fact).assertEqual('用户喝咖啡时偏好半糖');

      const forgotten = await memory.forget('owner-1', memoryId);
      expect(forgotten.status).assertEqual('success');
      expect(await memory.get('owner-1', memoryId)).assertNull();
    });

    it('cancels update after embedding and forget immediately before their commits', 0, async () => {
      const store = new FakeMemoryStore();
      const initial = provider(store, new FakeEmbeddingPort());
      const added = await initial.remember({ ownerId: 'owner-1', records: [
        { fact: '用户原本偏好无糖', sceneId: 'global', sourceTurnId: 'turn-1' }
      ] });
      const memoryId = added.records[0].record?.memoryId ?? '';

      const updateGuard = new MutableMemoryCommitGuard();
      const canceling = provider(store, new CancelingEmbeddingPort(updateGuard, 1));
      const updated = await canceling.update({
        ownerId: 'owner-1', memoryId, fact: '用户现在偏好半糖', sourceTurnId: 'turn-2'
      }, updateGuard);
      expect(updated.status).assertEqual('error');
      expect(updated.error?.code ?? '').assertEqual('memory_operation_canceled');
      expect((await initial.get('owner-1', memoryId))?.fact ?? '').assertEqual('用户原本偏好无糖');

      const forgetGuard = new MutableMemoryCommitGuard();
      forgetGuard.active = false;
      const forgotten = await initial.forget('owner-1', memoryId, forgetGuard);
      expect(forgotten.status).assertEqual('error');
      expect(forgotten.error?.code ?? '').assertEqual('memory_operation_canceled');
      expect(await initial.get('owner-1', memoryId) === null).assertFalse();
    });

    it('prevents another owner from reading updating or forgetting a record by id', 0, async () => {
      const store = new FakeMemoryStore();
      const memory = provider(store, new FakeEmbeddingPort());
      const added = await memory.remember({ ownerId: 'owner-a', records: [
        { fact: '用户喝咖啡不要糖', sceneId: 'food_companion', sourceTurnId: 'turn-1' }
      ] });
      const memoryId = added.records[0].record?.memoryId ?? '';

      expect(await memory.get('owner-b', memoryId)).assertNull();
      const update = await memory.update({
        ownerId: 'owner-b', memoryId, fact: '攻击者修改的记忆', sourceTurnId: 'turn-2'
      });
      expect(update.status).assertEqual('error');
      const forgotten = await memory.forget('owner-b', memoryId);
      expect(forgotten.status).assertEqual('error');
      expect((await memory.get('owner-a', memoryId))?.fact).assertEqual('用户喝咖啡不要糖');
    });

    it('logs bounded diagnostic context without the memory fact', 0, async () => {
      const logger = new CapturingMemoryLogger();
      const memory = new PhoneLocalMemoryProvider(new FakeMemoryStore(), new FailingEmbeddingPort(), {
        allowedSceneIds: ['food_companion'], logger
      });
      const secret = '用户喝咖啡不要糖';
      const result = await memory.remember({ ownerId: 'owner-1', records: [
        { fact: secret, sceneId: 'food_companion', sourceTurnId: 'turn-1' }
      ] });
      expect(result.status).assertEqual('error');
      expect(logger.entries.length).assertEqual(1);
      expect(logger.entries[0].operation).assertEqual('remember');
      expect(logger.entries[0].inputIndex).assertEqual(0);
      expect(logger.entries[0].errorMessage.indexOf(secret)).assertEqual(-1);
      expect(logger.entries[0].errorMessage.length <= 160).assertTrue();
    });

    it('rejects an invalid scene without writing any record', 0, async () => {
      const store = new FakeMemoryStore();
      const result = await provider(store, new FakeEmbeddingPort()).remember({
        ownerId: 'owner-1',
        records: [{ fact: '用户喝咖啡不要糖', sceneId: 'unknown', sourceTurnId: 'turn-1' }]
      });
      expect(result.status).assertEqual('error');
      expect(result.succeededCount).assertEqual(0);
      expect(store.records.length).assertEqual(0);
    });
  });
}
