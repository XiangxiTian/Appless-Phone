import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import {
  AggregateSearchPolicy,
  aiLogInfo,
  configureComposioConfigFromRawJson,
  configureLocalProviderConfigFromRawJson,
  configuredWaterfallSourceAdapters,
  configureWaterfallSearchPolicyForRuntime,
  WaterfallColdStartTopic,
  WATERFALL_COLD_START_TOPICS,
  WaterfallPool,
  WaterfallPoolAcceptedEvent,
  WaterfallPoolAvailabilityWait,
  WaterfallPreferenceSnapshot,
  WaterfallSourcePoolEntry
} from '@loop/agent-core';

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
let pool: WaterfallPool | null = null;
let started: boolean = false;
let coldStartIndex: number = 0;
let coldStartTimerId: number = -1;
let supplyInFlight: boolean = false;
let activated: boolean = false;

const COLD_SOURCE_CAPACITY: number = 20;
const ACTIVE_SOURCE_CAPACITY: number = 200;
const ACTIVE_DISCOVERY_WATERMARK: number = 50;

function errorMessage(error: Error | Object | string): string {
  return error instanceof Error ? error.message : (typeof error === 'string' ? error : 'unknown pool error');
}

function requirePool(): WaterfallPool {
  if (pool === null) throw new Error('waterfall pool worker is not initialized');
  return pool;
}

function enqueueNextTopic(): void {
  if (WATERFALL_COLD_START_TOPICS.length === 0) return;
  const runtime = requirePool();
  const index = coldStartIndex % WATERFALL_COLD_START_TOPICS.length;
  coldStartIndex = (index + 1) % WATERFALL_COLD_START_TOPICS.length;
  void runtime.supplementTopic(WATERFALL_COLD_START_TOPICS[index]).catch((_error: Error): void => {});
}

function scheduleNextTopic(intervalMs: number): void {
  if (!started || coldStartTimerId >= 0) return;
  coldStartTimerId = setTimeout((): void => {
    coldStartTimerId = -1;
    if (!started) return;
    enqueueNextTopic();
    scheduleNextTopic(intervalMs);
  }, intervalMs);
}

function startRuntime(initialTopicCount: number, topicIntervalMs: number): void {
  if (started) return;
  started = true;
  const runtime = requirePool();
  const count = Math.max(0, Math.floor(initialTopicCount));
  for (let index = 0; index < count; index += 1) enqueueNextTopic();
  scheduleNextTopic(Math.max(1000, Math.floor(topicIntervalMs)));
  void runtime.start().catch((_error: Error): void => {});
}

async function supplyRuntime(): Promise<void> {
  if (supplyInFlight) return;
  supplyInFlight = true;
  const runtime = requirePool();
  try {
    enqueueNextTopic();
    await Promise.all([runtime.refillDiscoveries(), runtime.refreshScheduledDiscoveries()]);
  } finally {
    supplyInFlight = false;
  }
}

function activateRuntime(): void {
  if (activated) return;
  activated = true;
  requirePool().expandSourceCapacity(ACTIVE_SOURCE_CAPACITY, ACTIVE_DISCOVERY_WATERMARK);
  enqueueNextTopic();
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

async function takeOrWait(command: WaterfallPoolWorkerCommand): Promise<void> {
  const requestId = command.requestId ?? 0;
  const workerReceivedAtMs = Date.now();
  let workerWaitMs: number = 0;
  let workerTakeMs: number = 0;
  let workerWaitCycles: number = 0;
  try {
    const runtime = requirePool();
    const profile = command.profile as WaterfallPreferenceSnapshot;
    const enabledSources = command.enabledSources ?? [];
    const limit = Math.max(0, Math.floor(command.limit ?? 0));
    let takeStartedAtMs = Date.now();
    let entries = runtime.takeUpToForProfile(profile, enabledSources, limit);
    workerTakeMs += Date.now() - takeStartedAtMs;
    while (entries.length === 0 && limit > 0) {
      const wait = runtime.waitForAvailable(profile, enabledSources);
      pendingWaits.set(requestId, wait);
      workerWaitCycles += 1;
      const waitStartedAtMs = Date.now();
      const available = await wait.promise;
      workerWaitMs += Date.now() - waitStartedAtMs;
      pendingWaits.delete(requestId);
      if (!available) return;
      takeStartedAtMs = Date.now();
      entries = runtime.takeUpToForProfile(profile, enabledSources, limit);
      workerTakeMs += Date.now() - takeStartedAtMs;
    }
    postTakeResult(requestId, entries, workerReceivedAtMs, workerWaitMs, workerTakeMs, workerWaitCycles);
  } catch (error) {
    pendingWaits.delete(requestId);
    postTakeResult(requestId, [], workerReceivedAtMs, workerWaitMs, workerTakeMs, workerWaitCycles,
      errorMessage(error as Error));
  }
}

workerPort.onmessage = (event: MessageEvents): void => {
  const command = event.data as WaterfallPoolWorkerCommand;
  if (command.type === 'initialize') {
    configureLocalProviderConfigFromRawJson(command.providerConfigJson ?? '{}');
    configureComposioConfigFromRawJson(command.composioConfigJson ?? '{}');
    configureWaterfallSearchPolicyForRuntime(command.searchPolicy ?? {
      domesticOnly: false,
      multilingual: true
    });
    pool = new WaterfallPool(configuredWaterfallSourceAdapters(), {
      sourceCapacity: COLD_SOURCE_CAPACITY,
      discoveryWatermark: COLD_SOURCE_CAPACITY,
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
  if (command.type === 'take_or_wait') {
    void takeOrWait(command);
    return;
  }
  if (command.type === 'cancel_take') {
    const requestId = command.requestId ?? 0;
    const wait = pendingWaits.get(requestId);
    if (wait !== undefined) {
      pendingWaits.delete(requestId);
      wait.cancel();
    }
  }
};
