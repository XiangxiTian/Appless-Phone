export type MemoryOperationStatus = 'success' | 'error';
export type MemoryAuthority = 'leader' | 'seed';

export interface MemoryError {
  code: string;
  message: string;
  retryable: boolean;
}

/**
 * Host-owned turn/generation guard checked immediately before an irreversible local commit.
 * Once a store transaction has started, cancellation does not attempt to interrupt it.
 */
export interface MemoryCommitGuard {
  isActive(): boolean;
}

/**
 * A normalized, single-sentence fact prepared by the Leader.
 * The memory provider stores this value with infer=false semantics.
 */
export interface MemoryDraft {
  fact: string;
  sceneId: string;
  personaTag?: string;
  authority?: MemoryAuthority;
  sourceTurnId: string;
}

export interface MemoryRecord {
  memoryId: string;
  ownerId: string;
  sceneId: string;
  personaTag: string;
  authority: MemoryAuthority;
  fact: string;
  normalizedFact: string;
  factHash: string;
  embedding: number[];
  embeddingProfileId: string;
  sourceTurnId: string;
  createdAt: number;
  updatedAt: number;
}

export interface MemoryRememberRequest {
  ownerId: string;
  records: MemoryDraft[];
}

export interface MemoryUpdateRequest {
  ownerId: string;
  memoryId: string;
  fact: string;
  personaTag?: string;
  authority?: MemoryAuthority;
  sourceTurnId: string;
}

export interface MemoryQuery {
  ownerId: string;
  text: string;
  /** Empty means all scenes owned by ownerId. */
  sceneIds: string[];
  topK: number;
  minScore?: number;
}

export interface MemoryHit {
  record: MemoryRecord;
  score: number;
}

export interface MemoryWriteResult {
  inputIndex: number;
  status: MemoryOperationStatus;
  record?: MemoryRecord;
  error?: MemoryError;
}

/**
 * Best-effort batch semantics:
 * - at least one success => success, with at most one bounded warning;
 * - zero successes => error;
 * - successful records are never rolled back because another item failed.
 */
export interface MemoryBatchResult {
  status: MemoryOperationStatus;
  records: MemoryWriteResult[];
  succeededCount: number;
  failedCount: number;
  warnings: string[];
  error?: MemoryError;
}

export interface MemoryValidationIssue {
  inputIndex: number;
  field: 'batch' | 'fact' | 'sceneId' | 'personaTag' | 'authority' | 'sourceTurnId';
  code: string;
  message: string;
}

export interface MemoryDraftBatchValidationOptions {
  /** When present and non-empty, sceneId must be included in this allowlist. */
  allowedSceneIds?: string[];
  maxFactLength?: number;
}

export interface MemoryDraftBatchValidationResult {
  valid: boolean;
  records: MemoryDraft[];
  issues: MemoryValidationIssue[];
}
