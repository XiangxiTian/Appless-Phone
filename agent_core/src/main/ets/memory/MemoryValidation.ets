import {
  MemoryDraft,
  MemoryDraftBatchValidationOptions,
  MemoryDraftBatchValidationResult,
  MemoryValidationIssue
} from './MemoryTypes';

const MAX_MEMORY_RECORDS_PER_TURN = 5;
const DEFAULT_MAX_FACT_LENGTH = 240;
const MAX_SCENE_ID_LENGTH = 64;
const MAX_PERSONA_TAG_LENGTH = 64;
const MAX_SOURCE_TURN_ID_LENGTH = 128;

function compactWhitespace(value: string): string {
  return value.replace(/\u3000/g, ' ').replace(/\s+/g, ' ').trim();
}

/** Exact-dedup normalization only; it deliberately performs no semantic rewriting. */
export function normalizeMemoryFact(fact: string): string {
  return compactWhitespace(fact).toLowerCase();
}

function hex32(value: number): string {
  let hex = (value >>> 0).toString(16);
  while (hex.length < 8) hex = '0' + hex;
  return hex;
}

/** Stable non-cryptographic FNV-1a hash of the exact normalized fact. */
export function normalizedMemoryFactHash(fact: string): string {
  const normalized = normalizeMemoryFact(fact);
  let hash = 2166136261;
  for (let index = 0; index < normalized.length; index += 1) {
    hash ^= normalized.charCodeAt(index);
    // FNV prime multiplication expressed with shifts to stay deterministic in JS runtimes.
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
    hash >>>= 0;
  }
  return 'fnv1a32:' + hex32(hash);
}

function validScopedId(value: string, maxLength: number): boolean {
  if (value.length === 0 || value.length > maxLength) return false;
  return /^[A-Za-z0-9][A-Za-z0-9._:-]*$/.test(value);
}

function hasMultipleSentences(fact: string): boolean {
  for (let index = 0; index < fact.length; index += 1) {
    if ('。！？?!'.indexOf(fact.charAt(index)) < 0) continue;
    let cursor = index + 1;
    while (cursor < fact.length &&
      ('。！？?!'.indexOf(fact.charAt(cursor)) >= 0 || /\s/.test(fact.charAt(cursor)))) {
      cursor += 1;
    }
    if (cursor < fact.length) return true;
    return false;
  }
  return false;
}

function issue(
  inputIndex: number,
  field: 'batch' | 'fact' | 'sceneId' | 'personaTag' | 'authority' | 'sourceTurnId',
  code: string,
  message: string
): MemoryValidationIssue {
  return { inputIndex, field, code, message };
}

/**
 * Performs strict structural validation of the Leader's 1-5 atomic facts.
 * Atomic meaning is still a model contract; this rejects common multi-sentence leakage.
 */
export function validateMemoryDraftBatch(
  records: MemoryDraft[],
  options: MemoryDraftBatchValidationOptions = {}
): MemoryDraftBatchValidationResult {
  const issues: MemoryValidationIssue[] = [];
  const sanitized: MemoryDraft[] = [];
  const allowedScenes = options.allowedSceneIds ?? [];
  const maxFactLength = Math.max(1, options.maxFactLength ?? DEFAULT_MAX_FACT_LENGTH);

  if (records.length < 1 || records.length > MAX_MEMORY_RECORDS_PER_TURN) {
    issues.push(issue(-1, 'batch', 'memory_record_count_invalid',
      'A remember action must contain between 1 and 5 memory records.'));
  }

  records.forEach((record: MemoryDraft, index: number): void => {
    const fact = compactWhitespace(record.fact);
    const sceneId = record.sceneId.trim();
    const personaTag = (record.personaTag ?? sceneId).trim();
    const authority = record.authority ?? 'leader';
    const sourceTurnId = record.sourceTurnId.trim();

    if (fact.length === 0) {
      issues.push(issue(index, 'fact', 'memory_fact_empty', 'Memory fact must not be empty.'));
    } else if (fact.length > maxFactLength) {
      issues.push(issue(index, 'fact', 'memory_fact_too_long',
        'Memory fact exceeds the configured maximum length.'));
    } else if (/\r|\n/.test(record.fact) || hasMultipleSentences(fact)) {
      issues.push(issue(index, 'fact', 'memory_fact_not_atomic',
        'Memory fact must be one single-line sentence.'));
    }

    if (!validScopedId(sceneId, MAX_SCENE_ID_LENGTH)) {
      issues.push(issue(index, 'sceneId', 'memory_scene_invalid', 'Memory sceneId is invalid.'));
    } else if (allowedScenes.length > 0 && allowedScenes.indexOf(sceneId) < 0) {
      issues.push(issue(index, 'sceneId', 'memory_scene_unknown', 'Memory sceneId is not allowed.'));
    }

    if (!validScopedId(personaTag, MAX_PERSONA_TAG_LENGTH)) {
      issues.push(issue(index, 'personaTag', 'memory_persona_tag_invalid',
        'Memory personaTag is invalid.'));
    }

    if (authority !== 'leader' && authority !== 'seed') {
      issues.push(issue(index, 'authority', 'memory_authority_invalid', 'Memory authority is invalid.'));
    }

    if (!validScopedId(sourceTurnId, MAX_SOURCE_TURN_ID_LENGTH)) {
      issues.push(issue(index, 'sourceTurnId', 'memory_source_turn_invalid',
        'Memory sourceTurnId is invalid.'));
    }

    sanitized.push({ fact, sceneId, personaTag, authority, sourceTurnId });
  });

  return {
    valid: issues.length === 0,
    records: sanitized,
    issues
  };
}

export function memoryRecordsPerTurnLimit(): number {
  return MAX_MEMORY_RECORDS_PER_TURN;
}
