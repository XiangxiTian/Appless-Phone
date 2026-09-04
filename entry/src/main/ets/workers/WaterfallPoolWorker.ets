import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import {
  AggregateSearchPolicy,
  aiLogInfo,
  configureComposioConfigFromRawJson,
  configureLocalProviderConfigFromRawJson,
  configuredWaterfallSourceAdapters,
  coordinateWaterfallPoolTake,
  WaterfallCandidate,
  WaterfallColdStartTopic,
  WATERFALL_COLD_START_TOPICS,
  WaterfallInterestRecallRequest,
  WaterfallPool,
  WaterfallPoolAcceptedPage,
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
  recallRequests?: WaterfallInterestRecallRequest[];
  preferredQuery?: string;
  removedProfileQueries?: string[];
  profile?: WaterfallPreferenceSnapshot;
  enabledSources?: string[];
  enabledAdapterIds?: string[];
  reopenedSourceIds?: string[];
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
  searchCounts?: WaterfallSourceSearchCount[];
}

interface WaterfallSourceSearchCount {
  sourceId: string;
  searchCount: number;
  searchInsertedCount: number;
  discoveryCount: number;
  discoveryInsertedCount: number;
  poolSize: number;
  poolCapacity: number;
  consecutiveEmptySearches: number;
  autoDisabled: boolean;
}

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
const pendingWaits: Map<number, WaterfallPoolAvailabilityWait> =
  new Map<number, WaterfallPoolAvailabilityWait>();
const cancelledTakeIds: Set<number> = new Set<number>();
let pool: WaterfallPool | null = null;
let started: boolean = false;
const defaultTopicCursorBySource: Map<string, number> = new Map<string, number>();
const searchCountBySource: Map<string, number> = new Map<string, number>();
const searchInsertedCountBySource: Map<string, number> = new Map<string, number>();
const discoveryCountBySource: Map<string, number> = new Map<string, number>();
const discoveryInsertedCountBySource: Map<string, number> = new Map<string, number>();
let coldStartTimerId: number = -1;
let lowWatermarkTopicTimerId: number = -1;
let lowWatermarkTopicRunning: boolean = false;
let lowWatermarkRetryAttempt: number = 0;
let supplyInFlight: boolean = false;
let activated: boolean = false;
let appleInsertedTotal: number = 0;
let appleUpdatedTotal: number = 0;
let appleRejectedTotal: number = 0;
let appleEvictedTotal: number = 0;
let appleTakenTotal: number = 0;

const ACTIVE_SOURCE_CAPACITY: number = 200;
const ACTIVE_DISCOVERY_WATERMARK: number = 80;
const MAX_TAKE_SUPPLY_ATTEMPTS: number = 3;
const MAX_TAKE_WAIT_MS: number = 20000;
const TAKE_SUPPLY_RETRY_DELAYS_MS: number[] = [500, 1500, 3000];

function errorMessage(error: Error | Object | string): string {
  return error instanceof Error ? error.message : (typeof error === 'string' ? error : 'unknown pool error');
}

function poolDiagnosticText(value: string, limit: number = 320): string {
  const normalized = value.replace(/https?:\/\/[^\s]*/gi, '<url>').replace(/[\r\n\t]+/g, ' ').trim();
  const lower = normalized.toLowerCase();
  if (lower.indexOf('client_secret=') >= 0 || lower.indexOf('access_token=') >= 0 ||
    lower.indexOf('authorization:') >= 0 || lower.indexOf('bearer ') >= 0 ||
    lower.indexOf('x-api-key') >= 0 || lower.indexOf('api_key=') >= 0) {
    return '<redacted>';
  }
  return normalized.length <= limit ? normalized : normalized.substring(0, limit) + '...<truncated>';
}

function requirePool(): WaterfallPool {
  if (pool === null) throw new Error('waterfall pool worker is not initialized');
  return pool;
}

function defaultTopicIndexForSource(sourceId: string, sources: string[]): number {
  const existing = defaultTopicCursorBySource.get(sourceId);
  if (existing !== undefined) return existing % WATERFALL_COLD_START_TOPICS.length;
  const sourceIndex = Math.max(0, sources.indexOf(sourceId));
  const initial = Math.floor(sourceIndex * WATERFALL_COLD_START_TOPICS.length /
    Math.max(1, sources.length));
  defaultTopicCursorBySource.set(sourceId, initial);
  return initial;
}

function searchCountSnapshot(): WaterfallSourceSearchCount[] {
  const counts: WaterfallSourceSearchCount[] = [];
  searchCountBySource.forEach((searchCount: number, sourceId: string): void => {
    const container = pool === null ? null : pool.containerFor(sourceId);
    counts.push({
      sourceId,
      searchCount,
      searchInsertedCount: searchInsertedCountBySource.get(sourceId) ?? 0,
      discoveryCount: discoveryCountBySource.get(sourceId) ?? 0,
      discoveryInsertedCount: discoveryInsertedCountBySource.get(sourceId) ?? 0,
      poolSize: container?.size ?? 0,
      poolCapacity: container?.capacity ?? ACTIVE_SOURCE_CAPACITY,
      consecutiveEmptySearches: pool?.consecutiveEmptySearches(sourceId) ?? 0,
      autoDisabled: pool?.isSourceAutomaticallyDisabled(sourceId) ?? false
    });
  });
  return counts;
}

function postSearchCountSnapshot(): void {
  const response: WaterfallPoolWorkerResponse = {
    type: 'search_counts',
    requestId: 0,
    searchCounts: searchCountSnapshot()
  };
  workerPort.postMessage(response);
}

function logApplePoolAccounting(event: string, requestId: number = 0): void {
  const container = pool === null ? null : pool.containerFor('applepodcasts');
  aiLogInfo('[AIPhone][ApplePodcastAccounting] event=' + event +
    ' requestId=' + requestId.toString() +
    ' insertedTotal=' + appleInsertedTotal.toString() +
    ' updatedTotal=' + appleUpdatedTotal.toString() +
    ' rejectedTotal=' + appleRejectedTotal.toString() +
    ' evictedTotal=' + appleEvictedTotal.toString() +
    ' takenTotal=' + appleTakenTotal.toString() +
    ' poolNow=' + (container?.size ?? 0).toString());
}

function recordPoolSearch(event: WaterfallPoolAcceptedEvent): void {
  if (event.origin === 'external') return;
  const sourceId = event.accepted.page.sourceId;
  if (event.origin === 'search') {
    searchCountBySource.set(sourceId, (searchCountBySource.get(sourceId) ?? 0) + 1);
    searchInsertedCountBySource.set(sourceId,
      (searchInsertedCountBySource.get(sourceId) ?? 0) + event.accepted.insert.inserted);
  } else {
    discoveryCountBySource.set(sourceId, (discoveryCountBySource.get(sourceId) ?? 0) + 1);
    discoveryInsertedCountBySource.set(sourceId,
      (discoveryInsertedCountBySource.get(sourceId) ?? 0) + event.accepted.insert.inserted);
  }
  if (event.sourceAutoDisabled) {
    aiLogInfo('[AIPhone][WaterfallSourceCircuitBreaker] action=notify_ui source=' + sourceId +
      ' consecutiveEmptySearches=' + event.consecutiveEmptySearches.toString());
  }
  if (sourceId === 'applepodcasts') {
    appleInsertedTotal += event.accepted.insert.inserted;
    appleUpdatedTotal += event.accepted.insert.updated;
    appleRejectedTotal += event.accepted.insert.rejected;
    appleEvictedTotal += event.accepted.insert.evicted.length;
    aiLogInfo('[AIPhone][ApplePodcastPipeline] stage=pool_accept origin=' + event.origin +
      ' query=' + JSON.stringify(poolDiagnosticText(event.keyword, 120)) +
      ' pageItems=' + event.accepted.page.items.length.toString() +
      ' inserted=' + event.accepted.insert.inserted.toString() +
      ' updated=' + event.accepted.insert.updated.toString() +
      ' rejected=' + event.accepted.insert.rejected.toString() +
      ' evicted=' + event.accepted.insert.evicted.length.toString() +
      ' poolSize=' + event.sourceSize.toString() + '/' + event.sourceCapacity.toString() +
      ' status=' + event.accepted.page.status +
      ' ids=' + JSON.stringify(event.accepted.page.items.slice(0, 10).map(
        (candidate: WaterfallCandidate): string => candidate.id)));
    logApplePoolAccounting('accept');
  }
  postSearchCountSnapshot();
}

async function enqueueLowWatermarkTopics(skipBusyAdapters: boolean = false):
  Promise<WaterfallPoolTopicSupplementResult[]> {
  if (WATERFALL_COLD_START_TOPICS.length === 0) return [];
  const runtime = requirePool();
  const allSources = runtime.enabledSearchSources();
  const lowSources = runtime.enabledSearchSourcesBelowWatermark();
  const tasks = lowSources.map(async (sourceId: string): Promise<WaterfallPoolTopicSupplementResult> => {
    const index = defaultTopicIndexForSource(sourceId, allSources);
    const result = await runtime.supplementSourceTopic(
      sourceId, WATERFALL_COLD_START_TOPICS[index], skipBusyAdapters);
    if (result.results.length > 0) {
      defaultTopicCursorBySource.set(sourceId, (index + 1) % WATERFALL_COLD_START_TOPICS.length);
    }
    return result;
  });
  return Promise.all(tasks);
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
  let dispatched = 0;
  try {
    const results = await enqueueLowWatermarkTopics(true);
    results.forEach((result: WaterfallPoolTopicSupplementResult): void => {
      dispatched += result.results.length;
      result.results.forEach((page: WaterfallPoolTopicAcceptedPage): void => {
        inserted += page.accepted.insert.inserted;
      });
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
      scheduleLowWatermarkTopic(dispatched > 0 ? lowWatermarkRetryDelayMs() : 1000);
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

function startRuntime(_initialTopicCount: number, topicIntervalMs: number): void {
  if (started) return;
  started = true;
  const runtime = requirePool();
  scheduleLowWatermarkTopic();
  scheduleNextTopic(Math.max(1000, Math.floor(topicIntervalMs)));
  void runtime.start().catch((_error: Error): void => {});
}

async function supplyRuntime(): Promise<void> {
  if (supplyInFlight) return;
  supplyInFlight = true;
  const runtime = requirePool();
  try {
    await Promise.all([
      enqueueLowWatermarkTopics(),
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
  postSearchCountSnapshot();
  const appleEntries = entries.filter((entry: WaterfallSourcePoolEntry): boolean =>
    entry.sourceId === 'applepodcasts');
  if (appleEntries.length > 0) {
    appleTakenTotal += appleEntries.length;
    const appleContainer = pool === null ? null : pool.containerFor('applepodcasts');
    aiLogInfo('[AIPhone][ApplePodcastPipeline] stage=pool_take requestId=' + requestId.toString() +
      ' resultTotal=' + entries.length.toString() +
      ' appleTaken=' + appleEntries.length.toString() +
      ' poolRemaining=' + (appleContainer?.size ?? 0).toString() +
      ' ids=' + JSON.stringify(appleEntries.slice(0, 20).map(
        (entry: WaterfallSourcePoolEntry): string => entry.candidate.id)));
    logApplePoolAccounting('take_posted', requestId);
  }
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
    const preferredQuery = command.preferredQuery ?? '';
    const recallRequests = command.recallRequests ?? [];
    // Generic Pool takes are read/supply operations. Only an explicit preferred
    // query (currently a clicked Tag) may start the legacy-shaped recall request.
    // This prevents a source state's last query from being replayed on every
    // Reserve refill; default topics are supplied exclusively by the per-source
    // low-watermark cursor in enqueueLowWatermarkTopics().
    const recallPromise: Promise<WaterfallPoolAcceptedPage[]> | null =
      preferredQuery.trim().length > 0 && recallRequests.length > 0 ?
      runtime.supplementRecallRequests(recallRequests, preferredQuery.length > 0) : null;
    let exactWaitMs = 0;
    let exactTakeMs = 0;
    let exactWaitCycles = 0;
    if (recallPromise !== null && preferredQuery.length > 0) {
      let takeStartedAtMs = Date.now();
      let entries = runtime.takeUpToForProfile(profile, enabledSources, limit, preferredQuery);
      exactTakeMs += Date.now() - takeStartedAtMs;
      const wait = entries.length === 0 ?
        runtime.waitForAvailable(profile, enabledSources, preferredQuery) : null;
      if (wait !== null) {
        pendingWaits.set(requestId, wait);
        exactWaitCycles = 1;
        const waitStartedAtMs = Date.now();
        const available = await Promise.race<boolean>([
          wait.promise,
          recallPromise.then((_pages: WaterfallPoolAcceptedPage[]): boolean => false)
            .catch((_error: Error): boolean => false)
        ]);
        exactWaitMs += Date.now() - waitStartedAtMs;
        pendingWaits.delete(requestId);
        if (available) {
          takeStartedAtMs = Date.now();
          entries = runtime.takeUpToForProfile(profile, enabledSources, limit, preferredQuery);
          exactTakeMs += Date.now() - takeStartedAtMs;
        } else {
          wait.cancel();
        }
      }
      if (entries.length > 0) {
        postTakeResult(requestId, entries, workerReceivedAtMs,
          exactWaitMs, exactTakeMs, exactWaitCycles);
        return;
      }
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
      exactWaitMs + result.waitMs, exactTakeMs + result.takeMs,
      exactWaitCycles + result.waitCycles);
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
      sourceCapacity: ACTIVE_SOURCE_CAPACITY,
      discoveryWatermark: ACTIVE_DISCOVERY_WATERMARK,
      lowWatermarkObserver: (): void => scheduleLowWatermarkTopic(),
      observer: (accepted: WaterfallPoolAcceptedEvent): void => {
        recordPoolSearch(accepted);
        aiLogInfo('[AIPhone][WaterfallPoolWorkerLevel] source=' + accepted.accepted.page.sourceId +
          ' adapter=' + accepted.accepted.page.adapterId +
          ' origin=' + accepted.origin +
          ' size=' + accepted.sourceSize.toString() + '/' + accepted.sourceCapacity.toString() +
          ' inserted=' + accepted.accepted.insert.inserted.toString() +
          ' updated=' + accepted.accepted.insert.updated.toString() +
          ' status=' + accepted.accepted.page.status);
        if (accepted.accepted.page.sourceId === 'youtube') {
          aiLogInfo('[AIPhone][YouTubePoolOutcome] adapter=' + accepted.accepted.page.adapterId +
            ' origin=' + accepted.origin +
            ' query=' + JSON.stringify(poolDiagnosticText(accepted.keyword, 80)) +
            ' pageItems=' + accepted.accepted.page.items.length.toString() +
            ' inserted=' + accepted.accepted.insert.inserted.toString() +
            ' updated=' + accepted.accepted.insert.updated.toString() +
            ' rejected=' + accepted.accepted.insert.rejected.toString() +
            ' status=' + accepted.accepted.page.status +
            ' message=' + JSON.stringify(poolDiagnosticText(accepted.accepted.page.message)));
        }
      }
    });
    searchCountBySource.clear();
    searchInsertedCountBySource.clear();
    discoveryCountBySource.clear();
    discoveryInsertedCountBySource.clear();
    appleInsertedTotal = 0;
    appleUpdatedTotal = 0;
    appleRejectedTotal = 0;
    appleEvictedTotal = 0;
    appleTakenTotal = 0;
    requirePool().sources().forEach((sourceId: string): void => {
      searchCountBySource.set(sourceId, 0);
      searchInsertedCountBySource.set(sourceId, 0);
      discoveryCountBySource.set(sourceId, 0);
      discoveryInsertedCountBySource.set(sourceId, 0);
    });
    postSearchCountSnapshot();
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
  if (command.type === 'supplement_priority_topic' && command.topic !== undefined) {
    void requirePool().supplementPriorityTopic(command.topic).catch((_error: Error): void => {});
    return;
  }
  if (command.type === 'supply') {
    void supplyRuntime().catch((_error: Error): void => {});
    return;
  }
  if (command.type === 'activate') {
    activateRuntime();
    postSearchCountSnapshot();
    return;
  }
  if (command.type === 'set_enabled_adapters') {
    requirePool().setEnabledAdapters(command.enabledAdapterIds ?? [], command.reopenedSourceIds ?? []);
    postSearchCountSnapshot();
    return;
  }
  if (command.type === 'set_search_policy') {
    if (command.searchPolicy !== undefined) {
      applyWaterfallPoolWorkerSearchPolicy(command.searchPolicy);
    }
    return;
  }
  if (command.type === 'remove_profile_queries') {
    requirePool().removeProfileRecallQueries(command.removedProfileQueries ?? []);
    postSearchCountSnapshot();
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
    aiLogInfo('[AIPhone][ApplePodcastPipeline] stage=worker_cancel_take requestId=' + requestId.toString() +
      ' waiting=' + (wait === undefined ? '0' : '1'));
    logApplePoolAccounting('take_cancel_received', requestId);
    if (wait !== undefined) {
      pendingWaits.delete(requestId);
      wait.cancel();
    }
  }
};
