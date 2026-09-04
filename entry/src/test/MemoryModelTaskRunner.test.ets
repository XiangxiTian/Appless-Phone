import { describe, expect, it } from '@ohos/hypium';
import { A2uiMessage, defaultLocalModelSettings, LocalModelSettings } from '@loop/agent-core';
import { DirectModelCallResult } from '../main/ets/model/LocalModelClient';
import {
  MemoryModelCaller,
  MemoryModelSchemaValidator,
  MemoryModelTaskRunner,
  MemoryModelTaskRunnerLogger,
  MemoryModelTaskType
} from '../main/ets/memory/MemoryModelTaskRunner';

interface RunnerFixtureValue {
  value: string;
}

function successfulDirectResult(raw: string): DirectModelCallResult {
  return { ok: true, raw, error: '', requestDebug: '', assistantDebug: raw };
}

class RunnerFixtureValidator implements MemoryModelSchemaValidator<RunnerFixtureValue> {
  validate(raw: string): RunnerFixtureValue | null {
    if (raw !== '{"value":"valid"}') return null;
    return { value: 'valid' };
  }
}

class ImmediateMemoryModelCaller implements MemoryModelCaller {
  calls: number = 0;
  raw: string;

  constructor(raw: string) {
    this.raw = raw;
  }

  async call(_settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[],
    _systemPrompt: string): Promise<DirectModelCallResult> {
    this.calls += 1;
    return successfulDirectResult(this.raw);
  }
}

class DeferredMemoryModelCaller implements MemoryModelCaller {
  calls: number = 0;
  resolveResult: ((result: DirectModelCallResult) => void) | null = null;

  async call(_settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[],
    _systemPrompt: string): Promise<DirectModelCallResult> {
    this.calls += 1;
    return new Promise<DirectModelCallResult>((resolve: (result: DirectModelCallResult) => void): void => {
      this.resolveResult = resolve;
    });
  }

  resolve(raw: string): void {
    const resolveResult = this.resolveResult;
    if (resolveResult === null) throw new Error('Deferred model call has not started.');
    resolveResult(successfulDirectResult(raw));
  }
}

class NeverMemoryModelCaller implements MemoryModelCaller {
  calls: number = 0;

  async call(_settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[],
    _systemPrompt: string): Promise<DirectModelCallResult> {
    this.calls += 1;
    return new Promise<DirectModelCallResult>(() => {});
  }
}

class ParallelMemoryModelCaller implements MemoryModelCaller {
  calls: number = 0;
  private firstResolve: ((result: DirectModelCallResult) => void) | null = null;
  private secondResolve: ((result: DirectModelCallResult) => void) | null = null;

  async call(_settings: LocalModelSettings, _prompt: string, _history: A2uiMessage[],
    _systemPrompt: string): Promise<DirectModelCallResult> {
    this.calls += 1;
    const callIndex = this.calls;
    return new Promise<DirectModelCallResult>((resolve: (result: DirectModelCallResult) => void): void => {
      if (callIndex === 1) this.firstResolve = resolve;
      if (callIndex === 2) this.secondResolve = resolve;
    });
  }

  resolveFirst(raw: string): void {
    const resolve = this.firstResolve;
    if (resolve === null) throw new Error('First parallel call has not started.');
    resolve(successfulDirectResult(raw));
  }

  resolveSecond(raw: string): void {
    const resolve = this.secondResolve;
    if (resolve === null) throw new Error('Second parallel call has not started.');
    resolve(successfulDirectResult(raw));
  }
}

class RecordingMemoryModelLogger implements MemoryModelTaskRunnerLogger {
  lines: string[] = [];

  info(message: string): void {
    this.lines.push(message);
  }

  error(message: string): void {
    this.lines.push(message);
  }
}

function testSettings(): LocalModelSettings {
  return defaultLocalModelSettings();
}

export default function memoryModelTaskRunnerTest() {
  describe('MemoryModelTaskRunner', () => {
    it('allows memory tasks, validates schema once, and emits only redacted lifecycle metadata', 0, async () => {
      const caller = new ImmediateMemoryModelCaller('{"value":"valid"}');
      const logger = new RecordingMemoryModelLogger();
      let now = 100;
      const runner = new MemoryModelTaskRunner({
        settingsProvider: testSettings,
        caller,
        logger,
        now: (): number => {
          now += 5;
          return now;
        },
        taskIdFactory: (type: MemoryModelTaskType, sequence: number): string =>
          'test-' + type + '-' + sequence.toString()
      });
      const result = await runner.run<RunnerFixtureValue>({
        taskType: 'memory_overview',
        prompt: 'PRIVATE_MEMORY_PROMPT',
        systemPrompt: 'PRIVATE_SYSTEM_PROMPT',
        validator: new RunnerFixtureValidator()
      });
      expect(result.status).assertEqual('success');
      expect(result.modelCallCount).assertEqual(1);
      expect(result.repairEnabled).assertFalse();
      expect(result.taskId).assertEqual('test-memory_overview-1');
      expect(result.value?.value).assertEqual('valid');
      expect(logger.lines.length).assertEqual(1);
      expect(logger.lines[0].indexOf('PRIVATE_MEMORY_PROMPT')).assertEqual(-1);
      expect(logger.lines[0].indexOf('{"value":"valid"}')).assertEqual(-1);
    });

    it('rejects task types outside the memory-only allowlist without a model call', 0, async () => {
      const caller = new ImmediateMemoryModelCaller('{"value":"valid"}');
      const runner = new MemoryModelTaskRunner({ settingsProvider: testSettings, caller });
      const result = await runner.run<RunnerFixtureValue>({
        taskType: 'mail_summary' as MemoryModelTaskType,
        prompt: 'mail',
        systemPrompt: 'mail',
        validator: new RunnerFixtureValidator()
      });
      expect(result.status).assertEqual('error');
      expect(result.error?.code).assertEqual('memory_task_type_not_allowed');
      expect(result.modelCallCount).assertEqual(0);
      expect(caller.calls).assertEqual(0);
    });

    it('returns schema errors without an implicit repair call', 0, async () => {
      const caller = new ImmediateMemoryModelCaller('{"value":"wrong"}');
      const runner = new MemoryModelTaskRunner({ settingsProvider: testSettings, caller });
      const result = await runner.run<RunnerFixtureValue>({
        taskType: 'memory_correction_plan',
        prompt: 'correction',
        systemPrompt: 'memory only',
        validator: new RunnerFixtureValidator()
      });
      expect(result.status).assertEqual('error');
      expect(result.error?.code).assertEqual('memory_model_schema_invalid');
      expect(result.modelCallCount).assertEqual(1);
      expect(result.repairEnabled).assertFalse();
      expect(caller.calls).assertEqual(1);
    });

    it('drops a late result after explicit generation invalidation', 0, async () => {
      const caller = new DeferredMemoryModelCaller();
      const runner = new MemoryModelTaskRunner({ settingsProvider: testSettings, caller });
      const pending = runner.run<RunnerFixtureValue>({
        taskType: 'public_persona_memory_extract',
        prompt: 'persona',
        systemPrompt: 'memory only',
        validator: new RunnerFixtureValidator()
      });
      runner.invalidate();
      caller.resolve('{"value":"valid"}');
      const result = await pending;
      expect(result.status).assertEqual('inactive');
      expect(result.error?.code).assertEqual('memory_task_inactive');
      expect(result.modelCallCount).assertEqual(1);
    });

    it('does not cancel a different concurrent memory task when a new run starts', 0, async () => {
      const caller = new ParallelMemoryModelCaller();
      const runner = new MemoryModelTaskRunner({ settingsProvider: testSettings, caller });
      const overview = runner.run<RunnerFixtureValue>({
        taskType: 'memory_overview',
        prompt: 'overview',
        systemPrompt: 'memory only',
        validator: new RunnerFixtureValidator()
      });
      const projection = runner.run<RunnerFixtureValue>({
        taskType: 'discovery_memory_projection',
        prompt: 'projection',
        systemPrompt: 'memory only',
        validator: new RunnerFixtureValidator()
      });
      caller.resolveSecond('{"value":"valid"}');
      caller.resolveFirst('{"value":"valid"}');
      const overviewResult = await overview;
      const projectionResult = await projection;
      expect(overviewResult.status).assertEqual('success');
      expect(projectionResult.status).assertEqual('success');
      expect(caller.calls).assertEqual(2);
    });

    it('times out with a retryable error and still reports one model call', 0, async () => {
      const caller = new NeverMemoryModelCaller();
      const runner = new MemoryModelTaskRunner({ settingsProvider: testSettings, caller, timeoutMs: 5 });
      const result = await runner.run<RunnerFixtureValue>({
        taskType: 'discovery_memory_projection',
        prompt: 'projection',
        systemPrompt: 'memory only',
        validator: new RunnerFixtureValidator()
      });
      expect(result.status).assertEqual('error');
      expect(result.error?.code).assertEqual('memory_model_timeout');
      expect(result.error?.retryable).assertTrue();
      expect(result.modelCallCount).assertEqual(1);
    });
  });
}
