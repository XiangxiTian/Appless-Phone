import {
  MemoryBatchResult,
  MemoryCommitGuard,
  MemoryHit,
  MemoryQuery,
  MemoryRecord,
  MemoryRememberRequest,
  MemoryUpdateRequest,
  MemoryWriteResult
} from './MemoryTypes';

/** Produces vectors using one immutable embedding contract/profile. */
export interface EmbeddingPort {
  readonly profileId: string;
  readonly dimension: number;

  embed(text: string): Promise<number[]>;
}

/**
 * Platform-neutral infer=false memory contract.
 * Storage, vector indexing and model lifecycle belong to platform adapters.
 */
export interface ConversationMemoryPort {
  remember(request: MemoryRememberRequest, guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;

  search(query: MemoryQuery): Promise<MemoryHit[]>;

  get(ownerId: string, memoryId: string): Promise<MemoryRecord | null>;

  update(request: MemoryUpdateRequest, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;

  forget(ownerId: string, memoryId: string, guard?: MemoryCommitGuard): Promise<MemoryWriteResult>;

  forgetAll(ownerId: string, sceneIds?: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult>;
}
