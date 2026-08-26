import { describe, it, expect } from '@ohos/hypium';
import {
  MemoryDraft,
  MemoryRecord,
  MemoryWriteResult,
  buildBestEffortMemoryBatchResult,
  memoryRecordsPerTurnLimit,
  normalizeMemoryFact,
  normalizedMemoryFactHash,
  validateMemoryDraftBatch
} from '@loop/agent-core';

function record(
  memoryId: string,
  ownerId: string,
  sceneId: string,
  embedding: number[],
  updatedAt: number = 1
): MemoryRecord {
  const fact = 'fact-' + memoryId;
  return {
    memoryId,
    ownerId,
    sceneId,
    personaTag: sceneId,
    authority: 'leader',
    fact,
    normalizedFact: normalizeMemoryFact(fact),
    factHash: normalizedMemoryFactHash(fact),
    embedding,
    embeddingProfileId: 'bge-small-zh-v1.5@probe',
    sourceTurnId: 'turn-1',
    createdAt: 1,
    updatedAt
  };
}

function success(inputIndex: number, value: MemoryRecord): MemoryWriteResult {
  return { inputIndex, status: 'success', record: value };
}

function failure(inputIndex: number, message: string): MemoryWriteResult {
  return {
    inputIndex,
    status: 'error',
    error: { code: 'write_failed', message, retryable: true }
  };
}

export default function conversationMemoryCoreTest() {
  describe('ConversationMemoryCore', () => {
    it('validates and sanitizes one to five atomic Leader facts', 0, () => {
      const drafts: MemoryDraft[] = [
        { fact: '  用户前往北京时优先选择高铁。  ', sceneId: 'travel_companion', sourceTurnId: 'turn-1' },
        { fact: '用户住宿时偏好安静环境。', sceneId: 'travel_companion', sourceTurnId: 'turn-1' }
      ];
      const result = validateMemoryDraftBatch(drafts, {
        allowedSceneIds: ['global', 'travel_companion']
      });

      expect(result.valid).assertTrue();
      expect(result.records.length).assertEqual(2);
      expect(result.records[0].fact).assertEqual('用户前往北京时优先选择高铁。');
      expect(memoryRecordsPerTurnLimit()).assertEqual(5);
    });

    it('rejects empty, oversized, multi-sentence, unknown-scene and excess batches', 0, () => {
      const drafts: MemoryDraft[] = [
        { fact: '用户住在深圳。用户喜欢咖啡。', sceneId: 'unknown scene', sourceTurnId: '' },
        { fact: ' ', sceneId: 'unknown scene', sourceTurnId: '' },
        { fact: '这是一个故意超过三十二个字符上限的长期记忆事实，用于验证长度限制能够生效。',
          sceneId: 'unknown scene', sourceTurnId: '' },
        { fact: '有效事实一', sceneId: 'unknown scene', sourceTurnId: '' },
        { fact: '有效事实二', sceneId: 'unknown scene', sourceTurnId: '' },
        { fact: '有效事实三', sceneId: 'unknown scene', sourceTurnId: '' }
      ];
      const result = validateMemoryDraftBatch(drafts, {
        allowedSceneIds: ['global'],
        maxFactLength: 32
      });

      expect(result.valid).assertFalse();
      expect(result.issues.filter((value): boolean => value.field === 'batch').length).assertEqual(1);
      expect(result.issues.filter((value): boolean => value.code === 'memory_fact_not_atomic').length)
        .assertEqual(1);
      expect(result.issues.filter((value): boolean => value.code === 'memory_fact_too_long').length)
        .assertEqual(1);
      expect(result.issues.filter((value): boolean => value.field === 'sceneId').length).assertEqual(6);
      expect(result.issues.filter((value): boolean => value.field === 'sourceTurnId').length).assertEqual(6);
    });

    it('normalizes exact facts and produces a stable non-cryptographic hash', 0, () => {
      const left = '  USER\u3000prefers   Coffee。 ';
      const right = 'user prefers coffee。';

      expect(normalizeMemoryFact(left)).assertEqual(normalizeMemoryFact(right));
      expect(normalizedMemoryFactHash(left)).assertEqual(normalizedMemoryFactHash(right));
      expect(normalizedMemoryFactHash(left).indexOf('fnv1a32:')).assertEqual(0);
      expect(normalizedMemoryFactHash(left) === normalizedMemoryFactHash('user prefers tea。')).assertFalse();
    });

    it('keeps successful writes and exposes one bounded warning for partial failure', 0, () => {
      const result = buildBestEffortMemoryBatchResult([
        success(0, record('a', 'owner', 'food', [1, 0])),
        failure(1, 'second record failed'),
        failure(2, 'third record failed'),
        success(3, record('d', 'owner', 'travel', [0, 1]))
      ]);

      expect(result.status).assertEqual('success');
      expect(result.succeededCount).assertEqual(2);
      expect(result.failedCount).assertEqual(2);
      expect(result.records.length).assertEqual(4);
      expect(result.warnings.length).assertEqual(1);
      expect(result.warnings[0]).assertEqual('second record failed (1 more failures)');
      expect(result.error === undefined).assertTrue();
    });

    it('returns error only when every memory write fails', 0, () => {
      const result = buildBestEffortMemoryBatchResult([
        failure(0, 'first failure'),
        failure(1, 'second failure')
      ]);

      expect(result.status).assertEqual('error');
      expect(result.succeededCount).assertEqual(0);
      expect(result.failedCount).assertEqual(2);
      expect(result.warnings.length).assertEqual(0);
      expect(result.error?.message ?? '').assertEqual('first failure');
    });

  });
}
