import { ConversationContext, LocalModel } from '@loop/agent-core';
import {
  MemoryModelSchemaValidator,
  MemoryModelTaskRunner
} from '../../../memory/MemoryModelTaskRunner';
import {
  PhoneLocalMemoryMutationEvent,
  PhoneLocalMemoryProjectionSourcePort
} from '../../../memory/PhoneLocalMemoryRuntime';
import { PhoneLocalMemoryProjectionFact } from '../../../memory/PhoneLocalMemoryStore';
import {
  DISCOVERY_MEMORY_PROJECTION_COUNT_THRESHOLD,
  DISCOVERY_MEMORY_PROJECTION_WAIT_MS,
  DISCOVERY_MEMORY_PROJECTION_SYSTEM_PROMPT,
  DiscoveryMemoryPreferenceProjection,
  DiscoveryMemoryPreferenceSignal,
  DiscoveryMemoryProjectionPendingStats,
  discoveryMemoryPreferenceProjectionFromModelOutput,
  discoveryMemoryProjectionWithoutEvidence,
  discoveryMemoryProjectionPrompt,
  emptyDiscoveryMemoryPreferenceProjection,
  maxIncludedMemoryMutationAt,
  shouldRebuildDiscoveryMemoryProjection
} from './DiscoveryMemoryProjection';
import { DiscoveryMemoryProjectionStorePort } from './DiscoveryMemoryProjectionStore';

export interface DiscoveryMemoryProjectionCoordinatorOptions {
  source: PhoneLocalMemoryProjectionSourcePort;
  store: DiscoveryMemoryProjectionStorePort;
  modelProvider?: () => LocalModel;
  runner?: MemoryModelTaskRunner;
  onProjection?: (projection: DiscoveryMemoryPreferenceProjection) => void;
  isActive?: () => boolean;
  now?: () => number;
  countThreshold?: number;
  waitThresholdMs?: number;
  logger?: (message: string) => void;
}

class DiscoveryMemoryProjectionSchemaValidator implements
  MemoryModelSchemaValidator<DiscoveryMemoryPreferenceProjection> {
  private readonly facts: PhoneLocalMemoryProjectionFact[];
  private readonly previous: DiscoveryMemoryPreferenceProjection;
  private readonly forcedMutationAt: number;

  constructor(facts: PhoneLocalMemoryProjectionFact[],
    previous: DiscoveryMemoryPreferenceProjection, forcedMutationAt: number) {
    this.facts = facts;
    this.previous = previous;
    this.forcedMutationAt = forcedMutationAt;
  }

  validate(raw: string): DiscoveryMemoryPreferenceProjection | null {
    return discoveryMemoryPreferenceProjectionFromModelOutput(
      raw, this.facts, this.previous, this.forcedMutationAt
    );
  }
}

function copyProjection(value: DiscoveryMemoryPreferenceProjection): DiscoveryMemoryPreferenceProjection {
  return {
    basedOnMemoryMutationAt: value.basedOnMemoryMutationAt,
    signals: value.signals.map((signal: DiscoveryMemoryPreferenceSignal): DiscoveryMemoryPreferenceSignal => ({
      dimension: signal.dimension,
      key: signal.key,
      polarity: signal.polarity,
      strength: signal.strength,
      evidenceMemoryIds: signal.evidenceMemoryIds.slice(),
      baseWeight: signal.baseWeight,
      lastSupportedAt: signal.lastSupportedAt
    }))
  };
}

/**
 * Maintains a replaceable discovery projection without entering the memory-tool critical path.
 * Notification only schedules work; database reads and model calls always happen asynchronously.
 */
export class DiscoveryMemoryProjectionCoordinator {
  private readonly source: PhoneLocalMemoryProjectionSourcePort;
  private readonly store: DiscoveryMemoryProjectionStorePort;
  private readonly modelProvider: (() => LocalModel) | null;
  private readonly runner: MemoryModelTaskRunner | null;
  private readonly onProjection: ((projection: DiscoveryMemoryPreferenceProjection) => void) | null;
  private readonly isActive: () => boolean;
  private readonly now: () => number;
  private readonly countThreshold: number;
  private readonly waitThresholdMs: number;
  private readonly logger: ((message: string) => void) | null;
  private projection: DiscoveryMemoryPreferenceProjection;
  private scheduled: boolean = false;
  private inFlight: boolean = false;
  private pendingCheck: boolean = false;
  private pendingForcedMutationAt: number = 0;

  constructor(options: DiscoveryMemoryProjectionCoordinatorOptions) {
    this.source = options.source;
    this.store = options.store;
    this.modelProvider = options.modelProvider ?? null;
    this.runner = options.runner ?? null;
    if (this.modelProvider === null && this.runner === null) {
      throw new Error('Discovery memory projection requires a memory model runner or model provider.');
    }
    this.onProjection = options.onProjection ?? null;
    this.isActive = options.isActive ?? (() => true);
    this.now = options.now ?? (() => Date.now());
    this.countThreshold = options.countThreshold ?? DISCOVERY_MEMORY_PROJECTION_COUNT_THRESHOLD;
    this.waitThresholdMs = options.waitThresholdMs ?? DISCOVERY_MEMORY_PROJECTION_WAIT_MS;
    this.logger = options.logger ?? null;
    this.projection = this.store.load();
  }

  current(): DiscoveryMemoryPreferenceProjection {
    return copyProjection(this.projection);
  }

  notify(event: PhoneLocalMemoryMutationEvent): void {
    if (!this.active()) return;
    if (event.operation === 'forget') {
      this.pendingForcedMutationAt = Math.max(this.pendingForcedMutationAt, event.committedAt);
      const pruned = discoveryMemoryProjectionWithoutEvidence(this.projection, event.memoryIds);
      const saved = this.store.save(pruned);
      if (saved !== null) this.publish(saved);
    }
    this.requestRefresh();
  }

  requestRefresh(): void {
    if (!this.active()) return;
    this.pendingCheck = true;
    if (this.inFlight || this.scheduled) return;
    this.scheduled = true;
    Promise.resolve<void>(undefined).then((): Promise<void> => {
      this.scheduled = false;
      return this.runNext();
    }).catch((error: Object): void => {
      this.scheduled = false;
      this.log('schedule_failed', error);
    });
  }

  private async runNext(): Promise<void> {
    if (!this.active() || this.inFlight || !this.pendingCheck) return;
    this.inFlight = true;
    this.pendingCheck = false;
    const forcedMutationAt = this.pendingForcedMutationAt;
    this.pendingForcedMutationAt = 0;
    let succeeded = false;
    try {
      if (forcedMutationAt <= 0) {
        const stats = await this.source.getProjectionStats(this.projection.basedOnMemoryMutationAt);
        if (!this.active()) return;
        const pendingStats: DiscoveryMemoryProjectionPendingStats = {
          changedCount: stats.changedCount,
          oldestPendingUpdatedAt: stats.oldestPendingUpdatedAt
        };
        if (!shouldRebuildDiscoveryMemoryProjection(
          pendingStats,
          this.now(),
          this.countThreshold,
          this.waitThresholdMs
        )) {
          succeeded = true;
          return;
        }
      }
      const facts = await this.source.listProjectionFacts();
      if (!this.active()) return;
      const basedOnMemoryMutationAt = maxIncludedMemoryMutationAt(facts, forcedMutationAt);
      let next: DiscoveryMemoryPreferenceProjection = {
        basedOnMemoryMutationAt,
        signals: emptyDiscoveryMemoryPreferenceProjection().signals
      };
      if (facts.length > 0) {
        const prompt = discoveryMemoryProjectionPrompt(facts);
        if (this.runner !== null) {
          const result = await this.runner.run<DiscoveryMemoryPreferenceProjection>({
            taskType: 'discovery_memory_projection',
            prompt,
            systemPrompt: DISCOVERY_MEMORY_PROJECTION_SYSTEM_PROMPT,
            validator: new DiscoveryMemoryProjectionSchemaValidator(
              facts, this.projection, forcedMutationAt
            ),
            isActive: this.isActive
          });
          if (result.status === 'inactive') return;
          if (result.status !== 'success' || result.value === null) {
            throw new Error(result.error?.message ??
              'Discovery memory projection model returned invalid JSON.');
          }
          next = result.value;
        } else {
          const modelProvider = this.modelProvider;
          if (modelProvider === null) throw new Error('Discovery memory projection model is unavailable.');
          const raw = await modelProvider().complete(
            prompt,
            new ConversationContext(),
            DISCOVERY_MEMORY_PROJECTION_SYSTEM_PROMPT
          );
          if (!this.active()) return;
          const parsed = discoveryMemoryPreferenceProjectionFromModelOutput(
            raw,
            facts,
            this.projection,
            forcedMutationAt
          );
          if (parsed === null) throw new Error('Discovery memory projection model returned invalid JSON.');
          next = parsed;
        }
      }
      if (!this.active()) return;
      const saved = this.store.save(next);
      if (saved === null) throw new Error('Discovery memory projection did not pass local validation.');
      if (!this.active()) return;
      this.publish(saved);
      succeeded = true;
    } catch (error) {
      this.log('rebuild_failed', error);
    } finally {
      if (!succeeded && forcedMutationAt > 0) {
        this.pendingForcedMutationAt = Math.max(this.pendingForcedMutationAt, forcedMutationAt);
      }
      this.inFlight = false;
      if (this.pendingCheck || (succeeded && this.pendingForcedMutationAt > 0)) this.requestRefresh();
    }
  }

  private publish(value: DiscoveryMemoryPreferenceProjection): void {
    if (!this.active()) return;
    this.projection = value;
    if (this.onProjection === null) return;
    try {
      this.onProjection(copyProjection(value));
    } catch (error) {
      this.log('projection_listener_failed', error);
    }
  }

  private active(): boolean {
    try {
      return this.isActive();
    } catch (_error) {
      return false;
    }
  }

  private log(code: string, error: Object): void {
    if (this.logger === null) return;
    const message = error instanceof Error ? error.message : `${error}`;
    this.logger('[AIPhone][DiscoveryMemoryProjection] code=' + code + ' detail=' + message.substring(0, 240));
  }
}
