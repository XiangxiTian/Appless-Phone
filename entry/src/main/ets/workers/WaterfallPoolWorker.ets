import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import {
  AggregateSearchPolicy,
  aiLogInfo,
  configureComposioConfigFromRawJson,
  configureLocalProviderConfigFromRawJson,
  configuredWaterfallSourceAdapters,
  coordinateWaterfallPoolTake,
  WaterfallColdStartTopic,
  WATERFALL_COLD_START_TOPICS,
  WaterfallPool,
  WaterfallPoolAcceptedEvent,
  WaterfallPoolAvailabilityWait,
  WaterfallPoolTopicAcceptedPage,
  WaterfallPoolTopicSupplementResult,
  WaterfallPoolTakeCoordinatorCallbacks,
  WaterfallPoolTakeCoordinatorResult,
  WaterfallPreferenceSnapshot,
  WaterfallSourcePoolEntry
} from '@loop/agent-core';
import { applyWaterfallPoolWorkerSearchPolicy } from './WaterfallPoolWorkerPolicy';

interface WaterfallPoolWorkerCommand {
  type: string;
  requestId?: number;
  providerConfigJson?: string;
  composioConfigJson?: string;
  searchPolicy?: AggregateSearchPolicy;
  topic?: WaterfallColdStartTopic;
  profile?: WaterfallPreferenceSnapshot;
  enabledSources?: string[];
  enabledAdapterIds?: string[];
  limit?: number;
  initialTopicCount?: number;
  topicIntervalMs?: number;
}

interface WaterfallPoolWorkerResponse {
  type: string;
  requestId: number;
  entries?: WaterfallSourcePoolEntry[];
  error?: string;
  workerReceivedAtMs?: number;
  workerWaitMs?: number;
  workerTakeMs?: number;
  workerWaitCycles?: number;
  workerPostedAtMs?: number;
}

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
const pendingWaits: Map<number, WaterfallPoolAvailabilityWait> =
  new Map<number, WaterfallPoolAvailabilityWait>();
const cancelledTakeIds: Set<number> = new Set<number>();
let pool: WaterfallPool | null = null;
let started: boolean = false;
let coldStartIndex: number = 0;
let coldStartTimerId: number = -1;
let lowWatermarkTopicTimerId: number = -1;
let lowWatermarkTopicRunning: boolean = false;
let lowWatermarkRetryAttempt: number = 0;
let supplyInFlight: boolean = false;
let activated: boolean = false;

const COLD_SOURCE_CAPACITY: number = 20;
const ACTIVE_SOURCE_CAPACITY: number = 200;
const ACTIVE_DISCOVERY_WATERMARK: number = 50;
const MAX_TAKE_SUPPLY_ATTEMPTS: number = 3;
const MAX_TAKE_WAIT_MS: number = 20000;
const TAKE_SUPPLY_RETRY_DELAYS_MS: number[] = [500, 1500, 3000];

function errorMessage(error: Error | Object | string): string {
  return error instanceof Error ? error.message : (typeof error === 'string' ? error : 'unknown pool error');
}

function requirePool(): WaterfallPool {
  if (pool === null) throw new Error('waterfall pool worker is not initialized');
  return pool;
}

function enqueueNextTopic(): Promise<WaterfallPoolTopicSupplementResult> {
  if (WATERFALL_COLD_START_TOPICS.length === 0) {
    const empty: WaterfallPoolTopicSupplementResult = { topicId: '', results: [] };
    return Promise.resolve(empty);
  }
  const runtime = requirePool();
  const index = coldStartIndex % WATERFALL_COLD_START_TOPICS.length;
  coldStartIndex = (index + 1) % WATERFALL_COLD_START_TOPICS.length;
  return runtime.supplementTopic(WATERFALL_COLD_START_TOPICS[index]);
}

function lowWatermarkRetryDelayMs(): number {
  if (lowWatermarkRetryAttempt <= 1) return 1000;
  if (lowWatermarkRetryAttempt === 2) return 3000;
  if (lowWatermarkRetryAttempt === 3) return 10000;
  return 30000;
}

async function runLowWatermarkTopic(): Promise<void> {
  if (!started || lowWatermarkTopicRunning) return;
  const runtime = requirePool();
  if (!runtime.hasEnabledSearchSourceBelowWatermark()) {
    lowWatermarkRetryAttempt = 0;
    return;
  }
  lowWatermarkTopicRunning = true;
  let inserted = 0;
  try {
    const result = await enqueueNextTopic();
    result.results.forEach((page: WaterfallPoolTopicAcceptedPage): void => {
      inserted += page.accepted.insert.inserted;
    });
  } catch (_error) {
  } finally {
    lowWatermarkTopicRunning = false;
    if (!started || !runtime.hasEnabledSearchSourceBelowWatermark()) {
      lowWatermarkRetryAttempt = 0;
      return;
    }
    if (inserted > 0) {
      lowWatermarkRetryAttempt = 0;
      scheduleLowWatermarkTopic(0);
    } else {
      lowWatermarkRetryAttempt++;
      scheduleLowWatermarkTopic(lowWatermarkRetryDelayMs());
    }
  }
}

function scheduleLowWatermarkTopic(delayMs: number = 0): void {
  if (!started || lowWatermarkTopicTimerId >= 0 || lowWatermarkTopicRunning) return;
  lowWatermarkTopicTimerId = setTimeout((): void => {
    lowWatermarkTopicTimerId = -1;
    if (!started) return;
    void runLowWatermarkTopic().catch((_error: Error): void => {});
  }, Math.max(0, Math.floor(delayMs)));
}

function scheduleNextTopic(intervalMs: number): void {
  if (!started || coldStartTimerId >= 0) return;
  coldStartTimerId = setTimeout((): void => {
    coldStartTimerId = -1;
    if (!started) return;
    scheduleLowWatermarkTopic();
    scheduleNextTopic(intervalMs);
  }, intervalMs);
}

function startRuntime(initialTopicCount: number, topicIntervalMs: number): void {
  if (started) return;
  started = true;
  const runtime = requirePool();
  const count = Math.max(0, Math.floor(initialTopicCount));
  for (let index = 0; index < count; index += 1) {
    void enqueueNextTopic().catch((_error: Error): void => {});
  }
  scheduleNextTopic(Math.max(1000, Math.floor(topicIntervalMs)));
  void runtime.start().catch((_error: Error): void => {});
}

async function supplyRuntime(): Promise<void> {
  if (supplyInFlight) return;
  supplyInFlight = true;
  const runtime = requirePool();
  try {
    await Promise.all([
      enqueueNextTopic(),
      runtime.refillDiscoveries(),
      runtime.refreshScheduledDiscoveriesIfDue()
    ]);
  } finally {
    supplyInFlight = false;
    runtime.settleAvailabilityWaiters();
  }
}

function activateRuntime(): void {
  if (activated) return;
  activated = true;
  requirePool().expandSourceCapacity(ACTIVE_SOURCE_CAPACITY, ACTIVE_DISCOVERY_WATERMARK);
  scheduleLowWatermarkTopic();
  void supplyRuntime().catch((_error: Error): void => {});
}

function postTakeResult(
  requestId: number,
  entries: WaterfallSourcePoolEntry[],
  workerReceivedAtMs: number,
  workerWaitMs: number,
  workerTakeMs: number,
  workerWaitCycles: number,
  error: string = ''
): void {
  const response: WaterfallPoolWorkerResponse = {
    type: 'take_result',
    requestId,
    entries,
    workerReceivedAtMs,
    workerWaitMs,
    workerTakeMs,
    workerWaitCycles,
    workerPostedAtMs: Date.now()
  };
  if (error.length > 0) response.error = error;
  workerPort.postMessage(response);
}

class WorkerPoolTakeCallbacks implements WaterfallPoolTakeCoordinatorCallbacks<WaterfallSourcePoolEntry> {
  private readonly runtime: WaterfallPool;
  private readonly profile: WaterfallPreferenceSnapshot;
  private readonly enabledSources: string[];
  private readonly limit: number;
  private readonly requestId: number;

  constructor(
    runtime: WaterfallPool,
    profile: WaterfallPreferenceSnapshot,
    enabledSources: string[],
    limit: number,
    requestId: number
  ) {
    this.runtime = runtime;
    this.profile = profile;
    this.enabledSources = enabledSources;
    this.limit = limit;
    this.requestId = requestId;
  }

  take(): WaterfallSourcePoolEntry[] {
    return this.runtime.takeUpToForProfile(this.profile, this.enabledSources, this.limit);
  }

  waitForAvailable(): WaterfallPoolAvailabilityWait {
    return this.runtime.waitForAvailable(this.profile, this.enabledSources);
  }

  requestSupply(): void {
    void supplyRuntime().catch((_error: Error): void => {});
  }

  isCancelled(): boolean {
    return cancelledTakeIds.has(this.requestId);
  }

  onWaitStarted(wait: WaterfallPoolAvailabilityWait): void {
    pendingWaits.set(this.requestId, wait);
  }

  onWaitFinished(_wait: WaterfallPoolAvailabilityWait): void {
    pendingWaits.delete(this.requestId);
  }
}

async function takeOrWait(command: WaterfallPoolWorkerCommand): Promise<void> {
  const requestId = command.requestId ?? 0;
  const workerReceivedAtMs = Date.now();
  try {
    const runtime = requirePool();
    const profile = command.profile as WaterfallPreferenceSnapshot;
    const enabledSources = command.enabledSources ?? [];
    const limit = Math.max(0, Math.floor(command.limit ?? 0));
    if (limit === 0) {
      postTakeResult(requestId, [], workerReceivedAtMs, 0, 0, 0);
      return;
    }
    const callbacks = new WorkerPoolTakeCallbacks(runtime, profile, enabledSources, limit, requestId);
    const result: WaterfallPoolTakeCoordinatorResult<WaterfallSourcePoolEntry> =
      await coordinateWaterfallPoolTake(callbacks, {
        maxAttempts: MAX_TAKE_SUPPLY_ATTEMPTS,
        maxWaitMs: MAX_TAKE_WAIT_MS,
        retryDelaysMs: TAKE_SUPPLY_RETRY_DELAYS_MS,
        startedAtMs: workerReceivedAtMs
      });
    if (result.cancelled) return;
    postTakeResult(requestId, result.entries, workerReceivedAtMs,
      result.waitMs, result.takeMs, result.waitCycles);
  } catch (error) {
    pendingWaits.delete(requestId);
    postTakeResult(requestId, [], workerReceivedAtMs, 0, 0, 0,
      errorMessage(error as Error));
  } finally {
    cancelledTakeIds.delete(requestId);
  }
}

workerPort.onmessage = (event: MessageEvents): void => {
  const command = event.data as WaterfallPoolWorkerCommand;
  if (command.type === 'initialize') {
    configureLocalProviderConfigFromRawJson(command.providerConfigJson ?? '{}');
    configureComposioConfigFromRawJson(command.composioConfigJson ?? '{}');
    applyWaterfallPoolWorkerSearchPolicy(command.searchPolicy ?? {
      domesticOnly: false,
      multilingual: true
    });
    pool = new WaterfallPool(configuredWaterfallSourceAdapters(), {
      sourceCapacity: COLD_SOURCE_CAPACITY,
      discoveryWatermark: COLD_SOURCE_CAPACITY,
      lowWatermarkObserver: (): void => scheduleLowWatermarkTopic(),
      observer: (accepted: WaterfallPoolAcceptedEvent): void => {
        aiLogInfo('[AIPhone][WaterfallPoolWorkerLevel] source=' + accepted.accepted.page.sourceId +
          ' adapter=' + accepted.accepted.page.adapterId +
          ' origin=' + accepted.origin +
          ' size=' + accepted.sourceSize.toString() + '/' + accepted.sourceCapacity.toString() +
          ' inserted=' + accepted.accepted.insert.inserted.toString() +
          ' updated=' + accepted.accepted.insert.updated.toString() +
          ' status=' + accepted.accepted.page.status);
      }
    });
    return;
  }
  if (command.type === 'start') {
    startRuntime(command.initialTopicCount ?? 5, command.topicIntervalMs ?? 10000);
    return;
  }
  if (command.type === 'supplement_topic' && command.topic !== undefined) {
    void requirePool().supplementTopic(command.topic).catch((_error: Error): void => {});
    return;
  }
  if (command.type === 'supply') {
    void supplyRuntime().catch((_error: Error): void => {});
    return;
  }
  if (command.type === 'activate') {
    activateRuntime();
    return;
  }
  if (command.type === 'set_enabled_adapters') {
    requirePool().setEnabledAdapters(command.enabledAdapterIds ?? []);
    return;
  }
  if (command.type === 'set_search_policy') {
    if (command.searchPolicy !== undefined) {
      applyWaterfallPoolWorkerSearchPolicy(command.searchPolicy);
    }
    return;
  }
  if (command.type === 'take_or_wait') {
    void takeOrWait(command);
    return;
  }
  if (command.type === 'cancel_take') {
    const requestId = command.requestId ?? 0;
    cancelledTakeIds.add(requestId);
    const wait = pendingWaits.get(requestId);
    if (wait !== undefined) {
      pendingWaits.delete(requestId);
      wait.cancel();
    }
  }
};
