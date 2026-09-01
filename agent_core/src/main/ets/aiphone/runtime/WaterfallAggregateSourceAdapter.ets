import { aggregateMediaCandidates } from './AggregateSearchClient';
import { AggregateSearchSource, AggregateSearchSourceBatch } from './AggregateSearchTypes';
import { WaterfallContinuation, WaterfallRecallRoute } from './WaterfallAnythingCore';
import {
  WaterfallDiscoveryAdapter,
  WaterfallScheduledDiscoveryAdapter,
  WaterfallScheduledDiscoveryListener,
  WaterfallSearchAdapter,
  WaterfallSourceDiscoveryRequest,
  WaterfallSourcePage,
  WaterfallSourcePagination,
  WaterfallSearchQueryLanguagePolicy,
  WaterfallSourceSearchRequest,
  WaterfallSourceSubscription
} from './WaterfallSourceAdapter';

export type WaterfallAggregateSourceLoader = (
  query: string,
  continuation: WaterfallContinuation | null,
  limit: number
) => Promise<AggregateSearchSourceBatch>;

function errorMessage(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string') {
    return error;
  }
  return 'Source adapter request failed.';
}

function sourcePage(
  adapterId: string,
  sourceId: AggregateSearchSource,
  query: string,
  route: WaterfallRecallRoute,
  batch: AggregateSearchSourceBatch
): WaterfallSourcePage {
  return {
    adapterId,
    sourceId,
    items: aggregateMediaCandidates(batch.videos, batch.posts, 0, query, 'done', route),
    continuation: batch.continuation,
    exhausted: batch.continuation === null,
    status: batch.status.status,
    message: batch.status.message,
    fetchedAt: Date.now(),
    rawCount: batch.rawCount
  };
}

function failedPage(
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
    message: errorMessage(error),
    fetchedAt: Date.now()
  };
}

export class AggregateWaterfallSearchAdapter implements WaterfallSearchAdapter {
  readonly adapterId: string;
  readonly sourceId: AggregateSearchSource;
  readonly kind: 'search' = 'search';
  readonly pagination: WaterfallSourcePagination;
  readonly queryLanguagePolicy: WaterfallSearchQueryLanguagePolicy;
  private readonly loader: WaterfallAggregateSourceLoader;

  constructor(
    adapterId: string,
    sourceId: AggregateSearchSource,
    pagination: WaterfallSourcePagination,
    loader: WaterfallAggregateSourceLoader,
    queryLanguagePolicy: WaterfallSearchQueryLanguagePolicy = 'pool_default'
  ) {
    this.adapterId = adapterId;
    this.sourceId = sourceId;
    this.pagination = pagination;
    this.loader = loader;
    this.queryLanguagePolicy = queryLanguagePolicy;
  }

  async search(request: WaterfallSourceSearchRequest): Promise<WaterfallSourcePage> {
    try {
      const batch = await this.loader(request.query, request.continuation, request.limit);
      return sourcePage(this.adapterId, this.sourceId, request.query, 'search', batch);
    } catch (error) {
      return failedPage(this.adapterId, this.sourceId, error);
    }
  }
}

export class AggregateWaterfallDiscoveryAdapter implements WaterfallDiscoveryAdapter {
  readonly adapterId: string;
  readonly sourceId: AggregateSearchSource;
  readonly kind: 'discovery' = 'discovery';
  readonly pagination: WaterfallSourcePagination;
  protected readonly loader: WaterfallAggregateSourceLoader;

  constructor(
    adapterId: string,
    sourceId: AggregateSearchSource,
    pagination: WaterfallSourcePagination,
    loader: WaterfallAggregateSourceLoader
  ) {
    this.adapterId = adapterId;
    this.sourceId = sourceId;
    this.pagination = pagination;
    this.loader = loader;
  }

  async discover(request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage> {
    return this.loadDiscovery(request);
  }

  protected async loadDiscovery(request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage> {
    try {
      const batch = await this.loader('', request.continuation, request.limit);
      return sourcePage(this.adapterId, this.sourceId, '', 'popular', batch);
    } catch (error) {
      return failedPage(this.adapterId, this.sourceId, error);
    }
  }
}

class ScheduledDiscoverySubscription implements WaterfallSourceSubscription {
  private readonly cancel: () => void;
  private active: boolean = true;

  constructor(cancel: () => void) {
    this.cancel = cancel;
  }

  unsubscribe(): void {
    if (!this.active) {
      return;
    }
    this.active = false;
    this.cancel();
  }
}

export class ScheduledAggregateWaterfallDiscoveryAdapter implements WaterfallScheduledDiscoveryAdapter {
  readonly adapterId: string;
  readonly sourceId: AggregateSearchSource;
  readonly kind: 'scheduled_discovery' = 'scheduled_discovery';
  readonly pagination: WaterfallSourcePagination;
  readonly refreshIntervalMs: number;
  private readonly loader: WaterfallAggregateSourceLoader;
  private readonly scheduledLimit: number;
  private readonly listeners: Map<number, WaterfallScheduledDiscoveryListener> =
    new Map<number, WaterfallScheduledDiscoveryListener>();
  private nextListenerId: number = 1;
  private timerId: number = -1;
  private scheduledRequestRunning: boolean = false;

  constructor(
    adapterId: string,
    sourceId: AggregateSearchSource,
    pagination: WaterfallSourcePagination,
    refreshIntervalMs: number,
    scheduledLimit: number,
    loader: WaterfallAggregateSourceLoader
  ) {
    this.adapterId = adapterId;
    this.sourceId = sourceId;
    this.pagination = pagination;
    this.refreshIntervalMs = Math.max(1, refreshIntervalMs);
    this.scheduledLimit = Math.max(1, scheduledLimit);
    this.loader = loader;
  }

  async discover(request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage> {
    return this.loadDiscovery(request);
  }

  subscribe(listener: WaterfallScheduledDiscoveryListener): WaterfallSourceSubscription {
    const listenerId = this.nextListenerId++;
    this.listeners.set(listenerId, listener);
    if (this.listeners.size === 1) {
      this.scheduleNext();
    }
    return new ScheduledDiscoverySubscription((): void => this.removeListener(listenerId));
  }

  private async loadDiscovery(request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage> {
    try {
      const batch = await this.loader('', request.continuation, request.limit);
      return sourcePage(this.adapterId, this.sourceId, '', 'popular', batch);
    } catch (error) {
      return failedPage(this.adapterId, this.sourceId, error);
    }
  }

  private removeListener(listenerId: number): void {
    this.listeners.delete(listenerId);
    if (this.listeners.size === 0 && this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  private scheduleNext(): void {
    if (this.listeners.size === 0 || this.timerId >= 0) {
      return;
    }
    this.timerId = setTimeout((): void => {
      this.timerId = -1;
      this.publishScheduledSnapshot();
    }, this.refreshIntervalMs);
  }

  private async publishScheduledSnapshot(): Promise<void> {
    if (this.listeners.size === 0 || this.scheduledRequestRunning) {
      this.scheduleNext();
      return;
    }
    this.scheduledRequestRunning = true;
    const page = await this.loadDiscovery({ limit: this.scheduledLimit, continuation: null });
    this.scheduledRequestRunning = false;
    const listeners: WaterfallScheduledDiscoveryListener[] = [];
    this.listeners.forEach((listener: WaterfallScheduledDiscoveryListener): void => {
      listeners.push(listener);
    });
    listeners.forEach((listener: WaterfallScheduledDiscoveryListener): void => {
      try {
        listener(page);
      } catch (_error) {
        // One pool consumer must not prevent other consumers or the next source refresh.
      }
    });
    this.scheduleNext();
  }
}
