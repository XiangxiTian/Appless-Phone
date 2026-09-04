import {
  A2uiMessage,
  LocalModelSettings,
  aiLogError,
  aiLogInfo
} from '@loop/agent-core';
import {
  callDirectModel,
  DirectModelCallResult
} from '../model/LocalModelClient';

export type MemoryModelTaskType = 'public_persona_memory_extract' | 'discovery_memory_projection' |
  'memory_overview' | 'memory_correction_plan';

export type MemoryModelTaskStatus = 'success' | 'error' | 'inactive';

export interface MemoryModelTaskError {
  code: string;
  message: string;
  retryable: boolean;
}

export interface MemoryModelSchemaValidator<T> {
  validate(raw: string): T | null;
}

export interface MemoryModelTaskRequest<T> {
  taskType: MemoryModelTaskType;
  prompt: string;
  systemPrompt: string;
  validator: MemoryModelSchemaValidator<T>;
  isActive?: () => boolean;
}

export interface MemoryModelTaskResult<T> {
  status: MemoryModelTaskStatus;
  taskId: string;
  taskType: MemoryModelTaskType;
  durationMs: number;
  modelCallCount: number;
  repairEnabled: boolean;
  value: T | null;
  error: MemoryModelTaskError | null;
}

export interface MemoryModelCaller {
  call(settings: LocalModelSettings, prompt: string, history: A2uiMessage[],
    systemPrompt: string): Promise<DirectModelCallResult>;
}

export interface MemoryModelTaskRunnerLogger {
  info(message: string): void;
  error(message: string): void;
}

export interface MemoryModelTaskRunnerOptions {
  settingsProvider: () => LocalModelSettings;
  caller?: MemoryModelCaller;
  now?: () => number;
  taskIdFactory?: (taskType: MemoryModelTaskType, generation: number) => string;
  logger?: MemoryModelTaskRunnerLogger;
  timeoutMs?: number;
}

const MEMORY_MODEL_TASK_TIMEOUT_MS: number = 45000;
const MEMORY_MODEL_TIMEOUT_MARKER: string = '__memory_model_timeout__';

class DirectMemoryModelCaller implements MemoryModelCaller {
  async call(settings: LocalModelSettings, prompt: string, history: A2uiMessage[],
    systemPrompt: string): Promise<DirectModelCallResult> {
    return await callDirectModel(settings, prompt, history, systemPrompt);
  }
}

class DefaultMemoryModelTaskRunnerLogger implements MemoryModelTaskRunnerLogger {
  info(message: string): void {
    aiLogInfo(message);
  }

  error(message: string): void {
    aiLogError(message);
  }
}

function boundedTaskErrorMessage(value: string, fallback: string): string {
  const normalized = value.replace(/[\r\n\t]+/g, ' ').trim();
  return (normalized.length > 0 ? normalized : fallback).substring(0, 200);
}

function taskError(code: string, message: string, retryable: boolean): MemoryModelTaskError {
  return { code, message: boundedTaskErrorMessage(message, 'Memory model task failed.'), retryable };
}

export function isMemoryModelTaskType(value: string): boolean {
  return value === 'public_persona_memory_extract' || value === 'discovery_memory_projection' ||
    value === 'memory_overview' || value === 'memory_correction_plan';
}

/**
 * Narrow lifecycle wrapper for memory-only model calls. Prompt construction and schemas stay in
 * their memory domain modules. Repair is intentionally disabled: every run performs at most one
 * model call and reports that count to its caller.
 */
export class MemoryModelTaskRunner {
  private readonly settingsProvider: () => LocalModelSettings;
  private readonly caller: MemoryModelCaller;
  private readonly now: () => number;
  private readonly taskIdFactory: (taskType: MemoryModelTaskType, generation: number) => string;
  private readonly logger: MemoryModelTaskRunnerLogger;
  private readonly timeoutMs: number;
  private invalidateGeneration: number = 0;
  private taskSequence: number = 0;

  constructor(options: MemoryModelTaskRunnerOptions) {
    this.settingsProvider = options.settingsProvider;
    this.caller = options.caller ?? new DirectMemoryModelCaller();
    this.now = options.now ?? (() => Date.now());
    this.taskIdFactory = options.taskIdFactory ?? ((taskType: MemoryModelTaskType, generation: number): string =>
      'memory-task-' + taskType + '-' + this.now().toString() + '-' + generation.toString());
    this.logger = options.logger ?? new DefaultMemoryModelTaskRunnerLogger();
    const timeoutMs = options.timeoutMs ?? MEMORY_MODEL_TASK_TIMEOUT_MS;
    this.timeoutMs = isFinite(timeoutMs) && timeoutMs > 0 ? timeoutMs : MEMORY_MODEL_TASK_TIMEOUT_MS;
  }

  invalidate(): void {
    this.invalidateGeneration += 1;
  }

  async run<T>(request: MemoryModelTaskRequest<T>): Promise<MemoryModelTaskResult<T>> {
    this.taskSequence += 1;
    const sequence = this.taskSequence;
    const generation = this.invalidateGeneration;
    const startedAt = this.now();
    const taskId = this.taskIdFactory(request.taskType, sequence);
    let modelCallCount = 0;
    if (!isMemoryModelTaskType(request.taskType as string)) {
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'error', null,
        taskError('memory_task_type_not_allowed', 'Model task is outside the memory-only allowlist.', false));
    }
    if (!this.active(generation, request.isActive)) {
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'inactive', null,
        taskError('memory_task_inactive', 'Memory model task is no longer active.', false));
    }
    let result: DirectModelCallResult;
    try {
      modelCallCount += 1;
      result = await this.callWithTimeout(
        this.caller.call(this.settingsProvider(), request.prompt, [], request.systemPrompt)
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Memory model call failed.';
      if (message === MEMORY_MODEL_TIMEOUT_MARKER) {
        return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'error', null,
          taskError('memory_model_timeout', 'Memory model task timed out.', true));
      }
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'error', null,
        taskError('memory_model_call_failed', message, true));
    }
    if (!this.active(generation, request.isActive)) {
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'inactive', null,
        taskError('memory_task_inactive', 'Memory model task is no longer active.', false));
    }
    if (!result.ok) {
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'error', null,
        taskError('memory_model_call_failed', result.error, true));
    }
    let value: T | null = null;
    try {
      value = request.validator.validate(result.raw);
    } catch (_error) {
      value = null;
    }
    if (value === null) {
      return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'error', null,
        taskError('memory_model_schema_invalid', 'Memory model output did not match the required schema.', false));
    }
    return this.finish<T>(request.taskType, taskId, startedAt, modelCallCount, 'success', value, null);
  }

  private active(generation: number, guard?: () => boolean): boolean {
    if (generation !== this.invalidateGeneration) return false;
    if (guard === undefined) return true;
    try {
      return guard();
    } catch (_error) {
      return false;
    }
  }

  private async callWithTimeout(request: Promise<DirectModelCallResult>): Promise<DirectModelCallResult> {
    let timerId = -1;
    const timeout = new Promise<DirectModelCallResult>((_resolve,
      reject: (reason?: Error) => void): void => {
      timerId = setTimeout((): void => reject(new Error(MEMORY_MODEL_TIMEOUT_MARKER)), this.timeoutMs);
    });
    try {
      return await Promise.race<DirectModelCallResult>([request, timeout]);
    } finally {
      if (timerId >= 0) clearTimeout(timerId);
    }
  }

  private finish<T>(taskType: MemoryModelTaskType, taskId: string, startedAt: number,
    modelCallCount: number, status: MemoryModelTaskStatus, value: T | null,
    error: MemoryModelTaskError | null): MemoryModelTaskResult<T> {
    const durationMs = Math.max(0, this.now() - startedAt);
    const code = error === null ? 'ok' : error.code;
    // Deliberately excludes prompt, raw model output, and memory text.
    const line = '[AIPhone][MemoryModelTask] taskId=' + taskId + ' taskType=' + taskType +
      ' status=' + status + ' durationMs=' + durationMs.toString() +
      ' modelCallCount=' + modelCallCount.toString() + ' repairEnabled=false code=' + code;
    if (status === 'error') this.logger.error(line); else this.logger.info(line);
    return {
      status,
      taskId,
      taskType,
      durationMs,
      modelCallCount,
      repairEnabled: false,
      value,
      error
    };
  }
}
