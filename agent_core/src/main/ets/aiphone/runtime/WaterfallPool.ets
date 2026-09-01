import { AggregateSearchSource } from './AggregateSearchTypes';
import { aiLogInfo } from './AiphoneLogger';
import {
  mergeWaterfallPoolCandidates,
  WaterfallCandidate,
  WaterfallFeedState,
  WaterfallFeedUpdate,
  WaterfallPreferenceSnapshot,
  WaterfallContinuation
} from './WaterfallAnythingCore';
import { WaterfallColdStartTopic } from './WaterfallColdStartKeywords';
import {
  WaterfallDiscoveryAdapter,
  WaterfallQueryLanguage,
  WaterfallScheduledDiscoveryAdapter,
  WaterfallSearchAdapter,
  WaterfallSourceAdapterRegistry,
  WaterfallSourcePage,
  WaterfallSourceSubscription
} from './WaterfallSourceAdapter';
import {
  DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY,
  WaterfallSourcePoolContainer,
  WaterfallSourcePoolEntry,
  WaterfallSourcePoolInsertResult,
  WaterfallSourcePoolTakeProfileResult
} from './WaterfallSourcePoolContainer';
import { filterWaterfallPoolCandidates, WaterfallPoolQualityFilterResult } from './WaterfallPoolQualityPolicy';

export const DEFAULT_WATERFALL_POOL_REQUEST_LIMIT: number = 10;
export const DEFAULT_WATERFALL_POOL_DISCOVERY_WATERMARK: number = 50;
const MAX_WATERFALL_POOL_REFILL_ROUNDS: number = 20;

export interface WaterfallPoolOptions {
  sourceCapacity?: number;
  requestLimit?: number;
  discoveryWatermark?: number;
  defaultQueryLanguage?: WaterfallQueryLanguage;
  observer?: WaterfallPoolObserver;
}

export type WaterfallPoolAcceptOrigin = 'search' | 'discovery' | 'scheduled' | 'scheduled_manual' | 'external';

export interface WaterfallPoolAcceptedEvent {
  origin: WaterfallPoolAcceptOrigin;
  keyword: string;
  accepted: WaterfallPoolAcceptedPage;
  sourceSize: number;
  sourceCapacity: number;
}

export type WaterfallPoolObserver = (event: WaterfallPoolAcceptedEvent) => void;

export interface WaterfallPoolAcceptedPage {
  page: WaterfallSourcePage;
  insert: WaterfallSourcePoolInsertResult;
}

export interface WaterfallPoolSupplementResult {
  keyword: string;
  results: WaterfallPoolAcceptedPage[];
}

export interface WaterfallPoolTopicAcceptedPage {
  adapterId: string;
  query: string;
  accepted: WaterfallPoolAcceptedPage;
}

export interface WaterfallPoolTopicSupplementResult {
  topicId: string;
  results: WaterfallPoolTopicAcceptedPage[];
}

export interface WaterfallSearchQueueSnapshot {
  adapterId: string;
  pendingCount: number;
  running: boolean;
  activeQuery: string;
}

export interface WaterfallPoolDrainResult {
  entries: WaterfallSourcePoolEntry[];
  update: WaterfallFeedUpdate;
}

export interface WaterfallPoolAvailabilityWait {
  promise: Promise<boolean>;
  cancel(): void;
}

interface WaterfallPoolAvailabilityWaiter {
  id: number;
  profile: WaterfallPreferenceSnapshot;
  enabledSources: string[];
  resolve: (available: boolean) => void;
}

export interface WaterfallPoolDiscoveryRefillResult {
  adapterId: string;
  sourceId: AggregateSearchSource;
  pages: WaterfallPoolAcceptedPage[];
  reachedWatermark: boolean;
}

function normalizedPositive(value: number | undefined, fallback: number): number {
  return value !== undefined && Number.isFinite(value) && value > 0 ? Math.max(1, Math.floor(value)) : fallback;
}

function emptyInsertResult(rejected: number = 0): WaterfallSourcePoolInsertResult {
  return { inserted: 0, updated: 0, rejected, evicted: [] };
}

function poolErrorMessage(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  return typeof error === 'string' ? error : 'Waterfall pool adapter request failed.';
}

function failedAdapterPage(
  adapterId: string,
  sourceId: AggregateSearchSource,
  error: Error | Object | string | number | boolean | null | undefined
): WaterfallSourcePage {
  return {
    adapterId,
    sourceId,
    items: [],
    continuation: null,
    exhausted: true,
    status: 'error',
    message: poolErrorMessage(error),
    fetchedAt: Date.now()
  };
}

type WaterfallQueuedSearchRunner = (
  query: string,
  continuation: WaterfallContinuation | null
) => Promise<WaterfallPoolAcceptedPage>;

interface WaterfallQueuedSearchTask {
  key: string;
  query: string;
  continuation: WaterfallContinuation | null;
  resolve: (value: WaterfallPoolAcceptedPage) => void;
  reject: (reason: Error) => void;
}

/** Pool-owned FIFO. It serializes one adapter without putting session state in that adapter. */
class WaterfallAdapterSearchQueue {
  readonly adapterId: string;
  private readonly runner: WaterfallQueuedSearchRunner;
  private readonly shouldContinue: () => boolean;
  private readonly pending: WaterfallQueuedSearchTask[] = [];
  private readonly promisesByKey: Map<string, Promise<WaterfallPoolAcceptedPage>> =
    new Map<string, Promise<WaterfallPoolAcceptedPage>>();
  private taskRunning: boolean = false;
  private currentQuery: string = '';

  constructor(adapterId: string, runner: WaterfallQueuedSearchRunner, shouldContinue: () => boolean) {
    this.adapterId = adapterId;
    this.runner = runner;
    this.shouldContinue = shouldContinue;
  }

  enqueue(
    query: string,
    continuation: WaterfallContinuation | null = null
  ): Promise<WaterfallPoolAcceptedPage> {
    const normalizedQuery = query.trim();
    const continuationKey = continuation === null ? 'first' : continuation.kind + ':' + continuation.value;
    const key = normalizedQuery.toLowerCase() + '|' + continuationKey;
    const existing = this.promisesByKey.get(key);
    if (existing !== undefined) {
      return existing;
    }
    let resolveTask: (value: WaterfallPoolAcceptedPage) => void =
      (_value: WaterfallPoolAcceptedPage): void => {};
    let rejectTask: (reason: Error) => void = (_reason: Error): void => {};
    const promise = new Promise<WaterfallPoolAcceptedPage>((resolve, reject): void => {
      resolveTask = resolve;
      rejectTask = reject;
    });
    this.promisesByKey.set(key, promise);
    this.pending.push({
      key,
      query: normalizedQuery,
      continuation,
      resolve: resolveTask,
      reject: rejectTask
    });
    if (this.adapterId === 'youtube.search') {
      aiLogInfo('[AIPhone][WaterfallSearchQueue] adapter=' + this.adapterId +
        ' event=enqueue pending=' + this.pending.length.toString() +
        ' running=' + (this.taskRunning ? 'true' : 'false') +
        ' queryChars=' + normalizedQuery.length.toString() +
        ' continuation=' + (continuation === null ? 'none' : 'present'));
    }
    this.runNext();
    return promise;
  }

  snapshot(): WaterfallSearchQueueSnapshot {
    return {
      adapterId: this.adapterId,
      pendingCount: this.pending.length,
      running: this.taskRunning,
      activeQuery: this.currentQuery
    };
  }

  private runNext(): void {
    if (this.taskRunning) return;
    const task = this.pending.shift();
    if (task === undefined) return;
    this.taskRunning = true;
    this.currentQuery = task.query;
    this.execute(task);
  }

  private async execute(task: WaterfallQueuedSearchTask): Promise<void> {
    const startedAtMs = Date.now();
    if (this.adapterId === 'youtube.search') {
      aiLogInfo('[AIPhone][WaterfallSearchQueue] adapter=' + this.adapterId +
        ' event=start pending=' + this.pending.length.toString() +
        ' queryChars=' + task.query.length.toString() +
        ' continuation=' + (task.continuation === null ? 'none' : 'present'));
    }
    try {
      const accepted = await this.runner(task.query, task.continuation);
      task.resolve(accepted);
      const next = accepted.page.continuation;
      if (next !== null && this.shouldContinue()) {
        void this.enqueue(task.query, next).catch((_error: Error): void => {});
      }
    } catch (error) {
      task.reject(error instanceof Error ? error : new Error('Waterfall search queue task failed.'));
    }
    this.promisesByKey.delete(task.key);
    this.taskRunning = false;
    this.currentQuery = '';
    if (this.adapterId === 'youtube.search') {
      aiLogInfo('[AIPhone][WaterfallSearchQueue] adapter=' + this.adapterId +
        ' event=end elapsedMs=' + (Date.now() - startedAtMs).toString() +
        ' pending=' + this.pending.length.toString());
    }
    this.runNext();
  }
}

class DefaultWaterfallPoolAvailabilityWait implements WaterfallPoolAvailabilityWait {
  readonly promise: Promise<boolean>;
  private readonly cancelWait: () => void;
  private active: boolean = true;

  constructor(promise: Promise<boolean>, cancelWait: () => void) {
    this.promise = promise;
    this.cancelWait = cancelWait;
  }

  cancel(): void {
    if (!this.active) return;
    this.active = false;
    this.cancelWait();
  }
}

/**
 * Parallel pool orchestration layer. Adapters are registered by capability,
 * while every adapter with the same sourceId writes into one shared container.
 */
export class WaterfallPool {
  sourceCapacity: number;
  readonly requestLimit: number;
  discoveryWatermark: number;
  readonly defaultQueryLanguage: WaterfallQueryLanguage;
  private readonly searchAdaptersById: Map<string, WaterfallSearchAdapter> =
    new Map<string, WaterfallSearchAdapter>();
  private readonly searchQueuesByAdapterId: Map<string, WaterfallAdapterSearchQueue> =
    new Map<string, WaterfallAdapterSearchQueue>();
  private readonly discoveryAdaptersById: Map<string, WaterfallDiscoveryAdapter> =
    new Map<string, WaterfallDiscoveryAdapter>();
  private readonly scheduledAdaptersById: Map<string, WaterfallScheduledDiscoveryAdapter> =
    new Map<string, WaterfallScheduledDiscoveryAdapter>();
  private readonly adapterIds: Set<string> = new Set<string>();
  private readonly adapterEnabledById: Map<string, boolean> = new Map<string, boolean>();
  private readonly adapterIdsBySource: Map<string, string[]> = new Map<string, string[]>();
  private readonly containersBySource: Map<string, WaterfallSourcePoolContainer> =
    new Map<string, WaterfallSourcePoolContainer>();
  private readonly sourceOrder: string[] = [];
  private readonly discoveryContinuations: Map<string, WaterfallContinuation> =
    new Map<string, WaterfallContinuation>();
  private readonly discoveryInFlight: Set<string> = new Set<string>();
  private readonly scheduledSubscriptionsByAdapterId: Map<string, WaterfallSourceSubscription> =
    new Map<string, WaterfallSourceSubscription>();
  private readonly availabilityWaiters: Map<number, WaterfallPoolAvailabilityWaiter> =
    new Map<number, WaterfallPoolAvailabilityWaiter>();
  private nextAvailabilityWaiterId: number = 1;
  private started: boolean = false;
  private readonly observer: WaterfallPoolObserver | null;

  constructor(registry: WaterfallSourceAdapterRegistry, options: WaterfallPoolOptions = {}) {
    this.sourceCapacity = normalizedPositive(options.sourceCapacity, DEFAULT_WATERFALL_SOURCE_POOL_CAPACITY);
    this.requestLimit = normalizedPositive(options.requestLimit, DEFAULT_WATERFALL_POOL_REQUEST_LIMIT);
    this.discoveryWatermark = Math.min(
      this.sourceCapacity,
      normalizedPositive(options.discoveryWatermark, DEFAULT_WATERFALL_POOL_DISCOVERY_WATERMARK)
    );
    this.defaultQueryLanguage = options.defaultQueryLanguage ?? 'domestic';
    this.observer = options.observer ?? null;
    registry.search.forEach((adapter: WaterfallSearchAdapter): void => {
      this.registerSource(adapter.adapterId, adapter.sourceId);
      this.searchAdaptersById.set(adapter.adapterId, adapter);
      this.searchQueuesByAdapterId.set(
        adapter.adapterId,
        new WaterfallAdapterSearchQueue(
          adapter.adapterId,
          (query: string, continuation: WaterfallContinuation | null): Promise<WaterfallPoolAcceptedPage> =>
            this.loadSearchAdapter(adapter, query, continuation),
          (): boolean => this.isAdapterEnabled(adapter.adapterId) &&
            (this.containersBySource.get(adapter.sourceId)?.size ?? 0) < this.discoveryWatermark
        )
      );
    });
    registry.discovery.forEach((adapter: WaterfallDiscoveryAdapter): void => {
      this.registerSource(adapter.adapterId, adapter.sourceId);
      this.discoveryAdaptersById.set(adapter.adapterId, adapter);
    });
    registry.scheduledDiscovery.forEach((adapter: WaterfallScheduledDiscoveryAdapter): void => {
      this.registerSource(adapter.adapterId, adapter.sourceId);
      this.scheduledAdaptersById.set(adapter.adapterId, adapter);
    });
  }

  get isStarted(): boolean {
    return this.started;
  }

  sources(): string[] {
    return this.sourceOrder.slice();
  }

  adapterIdsList(): string[] {
    return Array.from(this.adapterIds);
  }

  isAdapterEnabled(adapterId: string): boolean {
    return this.adapterEnabledById.get(adapterId) ?? false;
  }

  setAdapterEnabled(adapterId: string, enabled: boolean): boolean {
    if (!this.adapterIds.has(adapterId)) return false;
    if (this.isAdapterEnabled(adapterId) === enabled) return true;
    this.adapterEnabledById.set(adapterId, enabled);
    const scheduled = this.scheduledAdaptersById.get(adapterId);
    if (scheduled !== undefined) {
      if (enabled && this.started) {
        this.subscribeScheduledAdapter(scheduled);
      } else if (!enabled) {
        this.unsubscribeScheduledAdapter(adapterId);
      }
    }
    if (enabled) this.notifyAvailabilityWaiters();
    return true;
  }

  setEnabledAdapters(enabledAdapterIds: string[]): void {
    const enabled = new Set<string>(enabledAdapterIds);
    this.adapterIds.forEach((adapterId: string): void => {
      this.setAdapterEnabled(adapterId, enabled.has(adapterId));
    });
  }

  containerFor(sourceId: string): WaterfallSourcePoolContainer | null {
    return this.containersBySource.get(sourceId) ?? null;
  }

  expandSourceCapacity(capacity: number, discoveryWatermark: number): boolean {
    const nextCapacity = Math.max(this.sourceCapacity,
      normalizedPositive(capacity, this.sourceCapacity));
    const nextWatermark = Math.max(this.discoveryWatermark, Math.min(nextCapacity,
      normalizedPositive(discoveryWatermark, this.discoveryWatermark)));
    if (nextCapacity === this.sourceCapacity && nextWatermark === this.discoveryWatermark) return false;
    this.sourceCapacity = nextCapacity;
    this.discoveryWatermark = nextWatermark;
    this.containersBySource.forEach((container: WaterfallSourcePoolContainer): void => {
      container.expandCapacity(nextCapacity);
    });
    return true;
  }

  accept(
    page: WaterfallSourcePage,
    keyword: string = '',
    origin: WaterfallPoolAcceptOrigin = 'external'
  ): WaterfallPoolAcceptedPage {
    const container = this.containersBySource.get(page.sourceId);
    if (container === undefined) {
      return { page, insert: emptyInsertResult(page.items.length) };
    }
    const quality: WaterfallPoolQualityFilterResult =
      filterWaterfallPoolCandidates(page.adapterId, page.items);
    const insert = container.put(quality.items, { keyword, insertedAt: page.fetchedAt });
    insert.rejected += quality.rejected;
    const accepted: WaterfallPoolAcceptedPage = {
      page,
      insert
    };
    if (this.observer !== null) {
      try {
        this.observer({
          origin,
          keyword,
          accepted,
          sourceSize: container.size,
          sourceCapacity: container.capacity
        });
      } catch (_error) {
        // Diagnostics must never interrupt ingestion.
      }
    }
    this.notifyAvailabilityWaiters();
    return accepted;
  }

  async supplement(keyword: string): Promise<WaterfallPoolSupplementResult> {
    const query = keyword.trim();
    const tasks: Promise<WaterfallPoolAcceptedPage>[] = [];
    this.searchAdaptersById.forEach((adapter: WaterfallSearchAdapter): void => {
      if (!this.isAdapterEnabled(adapter.adapterId)) return;
      const queue = this.searchQueuesByAdapterId.get(adapter.adapterId);
      if (queue !== undefined) {
        tasks.push(queue.enqueue(query));
      }
    });
    return { keyword: query, results: await Promise.all(tasks) };
  }

  /** Enqueues one source-appropriate language variant for every search adapter. */
  async supplementTopic(topic: WaterfallColdStartTopic): Promise<WaterfallPoolTopicSupplementResult> {
    const tasks: Promise<WaterfallPoolTopicAcceptedPage>[] = [];
    this.searchAdaptersById.forEach((adapter: WaterfallSearchAdapter): void => {
      if (!this.isAdapterEnabled(adapter.adapterId)) return;
      const query = this.queryForTopic(adapter, topic);
      tasks.push(this.enqueueTopicAdapter(adapter, query));
    });
    return { topicId: topic.id, results: await Promise.all(tasks) };
  }

  searchQueueSnapshots(): WaterfallSearchQueueSnapshot[] {
    const snapshots: WaterfallSearchQueueSnapshot[] = [];
    this.searchQueuesByAdapterId.forEach((queue: WaterfallAdapterSearchQueue): void => {
      snapshots.push(queue.snapshot());
    });
    return snapshots;
  }

  /**
   * Starts source-owned scheduled refresh subscriptions, then fills pull-based
   * discovery sources toward their configured watermark.
   */
  async start(): Promise<WaterfallPoolDiscoveryRefillResult[]> {
    if (!this.started) {
      this.started = true;
      this.scheduledAdaptersById.forEach((adapter: WaterfallScheduledDiscoveryAdapter): void => {
        if (this.isAdapterEnabled(adapter.adapterId)) this.subscribeScheduledAdapter(adapter);
      });
    }
    return this.refillDiscoveries();
  }

  stop(): void {
    this.started = false;
    const adapterIds = Array.from(this.scheduledSubscriptionsByAdapterId.keys());
    adapterIds.forEach((adapterId: string): void => this.unsubscribeScheduledAdapter(adapterId));
    this.cancelAllAvailabilityWaiters();
  }

  async refillDiscoveries(): Promise<WaterfallPoolDiscoveryRefillResult[]> {
    const tasks: Promise<WaterfallPoolDiscoveryRefillResult>[] = [];
    this.discoveryAdaptersById.forEach((adapter: WaterfallDiscoveryAdapter): void => {
      if (!this.isAdapterEnabled(adapter.adapterId)) return;
      tasks.push(this.refillDiscovery(adapter));
    });
    return Promise.all(tasks);
  }

  /** Pulls every scheduled source immediately without publishing to its listeners. */
  async refreshScheduledDiscoveries(): Promise<WaterfallPoolAcceptedPage[]> {
    const tasks: Promise<WaterfallPoolAcceptedPage>[] = [];
    this.scheduledAdaptersById.forEach((adapter: WaterfallScheduledDiscoveryAdapter): void => {
      if (!this.isAdapterEnabled(adapter.adapterId)) return;
      tasks.push(this.loadScheduledAdapter(adapter));
    });
    return Promise.all(tasks);
  }

  takeForProfile(
    profile: WaterfallPreferenceSnapshot,
    enabledSources?: string[],
    limit: number = 2147483647,
    round: number = 0
  ): WaterfallSourcePoolEntry[] {
    const results: WaterfallSourcePoolEntry[] = [];
    const normalizedLimit = Math.max(0, Math.floor(limit));
    this.sourceOrder.forEach((sourceId: string): void => {
      if (results.length >= normalizedLimit) return;
      if (enabledSources !== undefined && enabledSources.indexOf(sourceId) < 0) return;
      if (!this.isSourceEnabled(sourceId)) return;
      const container = this.containersBySource.get(sourceId);
      if (container === undefined) return;
      const sourceStartedAtMs = Date.now();
      const measured: WaterfallSourcePoolTakeProfileResult = container.takeForProfileMeasured(profile);
      const sourceTotalMs = Date.now() - sourceStartedAtMs;
      aiLogInfo('[AIPhone][WaterfallPoolTakeSourceTiming] round=' + round.toString() +
        ' source=' + sourceId +
        ' sizeBefore=' + measured.sizeBefore.toString() +
        ' scanned=' + measured.scannedCount.toString() +
        ' blocked=' + measured.blockedCount.toString() +
        ' scanScoreMs=' + measured.scanScoreMs.toString() +
        ' removeMs=' + measured.removeMs.toString() +
        ' copyMs=' + measured.copyMs.toString() +
        ' containerTotalMs=' + measured.totalMs.toString() +
        ' sourceTotalMs=' + sourceTotalMs.toString() +
        ' selected=' + (measured.entry === null ? '0' : '1'));
      if (measured.entry !== null) {
        results.push(measured.entry);
      }
    });
    return results;
  }

  takeUpToForProfile(
    profile: WaterfallPreferenceSnapshot,
    enabledSources: string[],
    limit: number
  ): WaterfallSourcePoolEntry[] {
    const results: WaterfallSourcePoolEntry[] = [];
    const normalizedLimit = Math.max(0, Math.floor(limit));
    const batchStartedAtMs = Date.now();
    const topicWeights = profile.topicWeights.length;
    const sourceWeights = profile.sourceWeights.length;
    const formatWeights = profile.formatWeights.length;
    const explicitRules = profile.explicitRules.length;
    const sessionTopicWeights = (profile.sessionTopicWeights ?? []).length;
    const sessionSourceWeights = (profile.sessionSourceWeights ?? []).length;
    const sessionFormatWeights = (profile.sessionFormatWeights ?? []).length;
    aiLogInfo('[AIPhone][WaterfallPoolTakeBatchStart] limit=' + normalizedLimit.toString() +
      ' enabledSources=' + enabledSources.length.toString() +
      ' topicWeights=' + topicWeights.toString() +
      ' sourceWeights=' + sourceWeights.toString() +
      ' formatWeights=' + formatWeights.toString() +
      ' explicitRules=' + explicitRules.toString() +
      ' sessionTopicWeights=' + sessionTopicWeights.toString() +
      ' sessionSourceWeights=' + sessionSourceWeights.toString() +
      ' sessionFormatWeights=' + sessionFormatWeights.toString());
    let round = 0;
    while (results.length < normalizedLimit) {
      round += 1;
      const roundStartedAtMs = Date.now();
      const batch = this.takeForProfile(profile, enabledSources, normalizedLimit - results.length, round);
      aiLogInfo('[AIPhone][WaterfallPoolTakeRoundTiming] round=' + round.toString() +
        ' requested=' + (normalizedLimit - results.length).toString() +
        ' selected=' + batch.length.toString() +
        ' roundMs=' + (Date.now() - roundStartedAtMs).toString());
      if (batch.length === 0) break;
      batch.forEach((entry: WaterfallSourcePoolEntry): void => {
        results.push(entry);
      });
    }
    aiLogInfo('[AIPhone][WaterfallPoolTakeBatchEnd] limit=' + normalizedLimit.toString() +
      ' selected=' + results.length.toString() +
      ' rounds=' + round.toString() +
      ' totalMs=' + (Date.now() - batchStartedAtMs).toString());
    return results;
  }

  hasAvailableForProfile(profile: WaterfallPreferenceSnapshot, enabledSources: string[]): boolean {
    for (let index = 0; index < this.sourceOrder.length; index += 1) {
      const sourceId = this.sourceOrder[index];
      if (enabledSources.indexOf(sourceId) < 0) continue;
      if (!this.isSourceEnabled(sourceId)) continue;
      if (this.containersBySource.get(sourceId)?.hasForProfile(profile) ?? false) return true;
    }
    return false;
  }

  /** Waits without consuming. The caller rechecks its generation before taking items. */
  waitForAvailable(
    profile: WaterfallPreferenceSnapshot,
    enabledSources: string[]
  ): WaterfallPoolAvailabilityWait {
    if (this.hasAvailableForProfile(profile, enabledSources)) {
      return new DefaultWaterfallPoolAvailabilityWait(Promise.resolve(true), (): void => {});
    }
    const waiterId = this.nextAvailabilityWaiterId++;
    let resolveWait: (available: boolean) => void = (_available: boolean): void => {};
    const promise = new Promise<boolean>((resolve): void => {
      resolveWait = resolve;
    });
    this.availabilityWaiters.set(waiterId, {
      id: waiterId,
      profile,
      enabledSources: enabledSources.slice(),
      resolve: resolveWait
    });
    return new DefaultWaterfallPoolAvailabilityWait(promise, (): void => {
      const waiter = this.availabilityWaiters.get(waiterId);
      if (waiter === undefined) return;
      this.availabilityWaiters.delete(waiterId);
      waiter.resolve(false);
    });
  }

  /** Consumes up to maxItems across enabled sources and merges them into the legacy waterfall. */
  drainToWaterfall(
    state: WaterfallFeedState,
    profile: WaterfallPreferenceSnapshot,
    nowMs: number,
    planLoads: boolean = true,
    maxItems: number = 2147483647
  ): WaterfallPoolDrainResult {
    const entries = this.takeUpToForProfile(profile, state.enabledSources, maxItems);
    return {
      entries,
      update: mergeWaterfallPoolCandidates(
        state,
        entries.map((entry: WaterfallSourcePoolEntry): WaterfallCandidate => entry.candidate),
        nowMs,
        planLoads
      )
    };
  }

  private notifyAvailabilityWaiters(): void {
    const ready: WaterfallPoolAvailabilityWaiter[] = [];
    this.availabilityWaiters.forEach((waiter: WaterfallPoolAvailabilityWaiter): void => {
      if (this.hasAvailableForProfile(waiter.profile, waiter.enabledSources)) ready.push(waiter);
    });
    ready.forEach((waiter: WaterfallPoolAvailabilityWaiter): void => {
      if (!this.availabilityWaiters.has(waiter.id)) return;
      this.availabilityWaiters.delete(waiter.id);
      waiter.resolve(true);
    });
  }

  private cancelAllAvailabilityWaiters(): void {
    const waiters: WaterfallPoolAvailabilityWaiter[] = [];
    this.availabilityWaiters.forEach((waiter: WaterfallPoolAvailabilityWaiter): void => {
      waiters.push(waiter);
    });
    this.availabilityWaiters.clear();
    waiters.forEach((waiter: WaterfallPoolAvailabilityWaiter): void => waiter.resolve(false));
  }

  private registerSource(adapterId: string, sourceId: AggregateSearchSource): void {
    if (this.adapterIds.has(adapterId)) {
      throw new Error('Duplicate waterfall adapter id: ' + adapterId);
    }
    this.adapterIds.add(adapterId);
    this.adapterEnabledById.set(adapterId, true);
    const sourceAdapterIds = this.adapterIdsBySource.get(sourceId) ?? [];
    sourceAdapterIds.push(adapterId);
    this.adapterIdsBySource.set(sourceId, sourceAdapterIds);
    if (!this.containersBySource.has(sourceId)) {
      this.containersBySource.set(
        sourceId,
        new WaterfallSourcePoolContainer(sourceId, this.sourceCapacity)
      );
      this.sourceOrder.push(sourceId);
    }
  }

  private async loadSearchAdapter(
    adapter: WaterfallSearchAdapter,
    query: string,
    continuation: WaterfallContinuation | null
  ): Promise<WaterfallPoolAcceptedPage> {
    if (!this.isAdapterEnabled(adapter.adapterId)) {
      return {
        page: {
          adapterId: adapter.adapterId,
          sourceId: adapter.sourceId,
          items: [],
          continuation: null,
          exhausted: true,
          status: 'empty',
          message: 'Adapter is disabled.',
          fetchedAt: Date.now()
        },
        insert: emptyInsertResult()
      };
    }
    try {
      return this.accept(await adapter.search({ query, limit: this.requestLimit, continuation }), query, 'search');
    } catch (error) {
      return this.accept(failedAdapterPage(adapter.adapterId, adapter.sourceId, error), query, 'search');
    }
  }

  private queryForTopic(adapter: WaterfallSearchAdapter, topic: WaterfallColdStartTopic): string {
    const language = adapter.queryLanguagePolicy === 'pool_default' ?
      this.defaultQueryLanguage : adapter.queryLanguagePolicy;
    return language === 'global' ? topic.globalQuery : topic.domesticQuery;
  }

  private async enqueueTopicAdapter(
    adapter: WaterfallSearchAdapter,
    query: string
  ): Promise<WaterfallPoolTopicAcceptedPage> {
    const queue = this.searchQueuesByAdapterId.get(adapter.adapterId);
    if (queue === undefined) {
      return {
        adapterId: adapter.adapterId,
        query,
        accepted: this.accept(
          failedAdapterPage(adapter.adapterId, adapter.sourceId, 'Search adapter queue is unavailable.'),
          query,
          'search'
        )
      };
    }
    return {
      adapterId: adapter.adapterId,
      query,
      accepted: await queue.enqueue(query)
    };
  }

  private async loadScheduledAdapter(
    adapter: WaterfallScheduledDiscoveryAdapter
  ): Promise<WaterfallPoolAcceptedPage> {
    if (!this.isAdapterEnabled(adapter.adapterId)) {
      return {
        page: {
          adapterId: adapter.adapterId,
          sourceId: adapter.sourceId,
          items: [],
          continuation: null,
          exhausted: true,
          status: 'empty',
          message: 'Adapter is disabled.',
          fetchedAt: Date.now()
        },
        insert: emptyInsertResult()
      };
    }
    try {
      return this.accept(await adapter.discover({ limit: this.requestLimit, continuation: null }), '', 'scheduled_manual');
    } catch (error) {
      return this.accept(failedAdapterPage(adapter.adapterId, adapter.sourceId, error), '', 'scheduled_manual');
    }
  }

  private async loadDiscoveryPage(
    adapter: WaterfallDiscoveryAdapter,
    continuation: WaterfallContinuation | null
  ): Promise<WaterfallSourcePage> {
    try {
      return await adapter.discover({ limit: this.requestLimit, continuation });
    } catch (error) {
      return failedAdapterPage(adapter.adapterId, adapter.sourceId, error);
    }
  }

  private async refillDiscovery(adapter: WaterfallDiscoveryAdapter): Promise<WaterfallPoolDiscoveryRefillResult> {
    const pages: WaterfallPoolAcceptedPage[] = [];
    const container = this.containersBySource.get(adapter.sourceId);
    if (container === undefined || !this.isAdapterEnabled(adapter.adapterId) ||
      this.discoveryInFlight.has(adapter.adapterId)) {
      return {
        adapterId: adapter.adapterId,
        sourceId: adapter.sourceId,
        pages,
        reachedWatermark: container !== undefined && container.size >= this.discoveryWatermark
      };
    }
    this.discoveryInFlight.add(adapter.adapterId);
    try {
      let continuation = this.discoveryContinuations.get(adapter.adapterId) ?? null;
      let rounds = 0;
      while (this.isAdapterEnabled(adapter.adapterId) && container.size < this.discoveryWatermark &&
        rounds < MAX_WATERFALL_POOL_REFILL_ROUNDS) {
        const sizeBefore = container.size;
        const page = await this.loadDiscoveryPage(adapter, continuation);
        const accepted = this.accept(page, '', 'discovery');
        pages.push(accepted);
        rounds++;
        continuation = page.continuation;
        if (continuation === null) {
          this.discoveryContinuations.delete(adapter.adapterId);
        } else {
          this.discoveryContinuations.set(adapter.adapterId, continuation);
        }
        if (page.status !== 'success' || page.exhausted || container.size === sizeBefore) {
          break;
        }
      }
      return {
        adapterId: adapter.adapterId,
        sourceId: adapter.sourceId,
        pages,
        reachedWatermark: container.size >= this.discoveryWatermark
      };
    } finally {
      this.discoveryInFlight.delete(adapter.adapterId);
    }
  }

  private isSourceEnabled(sourceId: string): boolean {
    const adapterIds = this.adapterIdsBySource.get(sourceId) ?? [];
    for (let index = 0; index < adapterIds.length; index += 1) {
      if (this.isAdapterEnabled(adapterIds[index])) return true;
    }
    return false;
  }

  private subscribeScheduledAdapter(adapter: WaterfallScheduledDiscoveryAdapter): void {
    if (this.scheduledSubscriptionsByAdapterId.has(adapter.adapterId)) return;
    const subscription = adapter.subscribe((page: WaterfallSourcePage): void => {
      if (this.started && this.isAdapterEnabled(adapter.adapterId)) {
        this.accept(page, '', 'scheduled');
      }
    });
    this.scheduledSubscriptionsByAdapterId.set(adapter.adapterId, subscription);
  }

  private unsubscribeScheduledAdapter(adapterId: string): void {
    const subscription = this.scheduledSubscriptionsByAdapterId.get(adapterId);
    if (subscription === undefined) return;
    this.scheduledSubscriptionsByAdapterId.delete(adapterId);
    subscription.unsubscribe();
  }
}
