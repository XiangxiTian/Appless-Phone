import { MemoryBatchResult, MemoryError, MemoryWriteResult } from './MemoryTypes';

function fallbackError(): MemoryError {
  return {
    code: 'memory_write_failed',
    message: 'Memory record could not be saved.',
    retryable: false
  };
}

function firstFailure(results: MemoryWriteResult[]): MemoryWriteResult | null {
  for (let index = 0; index < results.length; index += 1) {
    if (results[index].status === 'error') return results[index];
  }
  return null;
}

/** Pure aggregation for best-effort, non-rollback batch writes. */
export function buildBestEffortMemoryBatchResult(results: MemoryWriteResult[]): MemoryBatchResult {
  const copied = results.slice();
  let succeededCount = 0;
  let failedCount = 0;
  copied.forEach((result: MemoryWriteResult): void => {
    if (result.status === 'success') succeededCount += 1;
    else failedCount += 1;
  });

  const failed = firstFailure(copied);
  if (succeededCount === 0) {
    const error = failed?.error ?? fallbackError();
    return {
      status: 'error',
      records: copied,
      succeededCount,
      failedCount,
      warnings: [],
      error: { code: error.code, message: error.message, retryable: error.retryable }
    };
  }

  const warnings: string[] = [];
  if (failed !== null) {
    const error = failed.error ?? fallbackError();
    const extra = failedCount > 1 ? ' (' + (failedCount - 1).toString() + ' more failures)' : '';
    warnings.push(error.message + extra);
  }
  return {
    status: 'success',
    records: copied,
    succeededCount,
    failedCount,
    warnings
  };
}
