import { AggregateSearchSource, AggregateSearchStatus } from './AggregateSearchTypes';
import {
  WaterfallCandidate,
  WaterfallContinuation
} from './WaterfallAnythingCore';

export type WaterfallSourceAdapterKind = 'search' | 'discovery' | 'scheduled_discovery';
export type WaterfallSourcePagination = 'none' | 'page' | 'cursor';
export type WaterfallQueryLanguage = 'domestic' | 'global';
export type WaterfallSearchQueryLanguagePolicy = WaterfallQueryLanguage | 'pool_default';

export interface WaterfallSourceRequest {
  limit: number;
  continuation: WaterfallContinuation | null;
}

export interface WaterfallSourceSearchRequest extends WaterfallSourceRequest {
  query: string;
}

export type WaterfallSourceDiscoveryRequest = WaterfallSourceRequest;

/**
 * One self-contained response from a source adapter. Search-session state is
 * represented only by request/response continuation values and is owned by the
 * caller, so one configured adapter can serve concurrent sessions safely.
 */
export interface WaterfallSourcePage {
  adapterId: string;
  sourceId: AggregateSearchSource;
  items: WaterfallCandidate[];
  continuation: WaterfallContinuation | null;
  exhausted: boolean;
  status: AggregateSearchStatus;
  message: string;
  fetchedAt: number;
  rawCount?: number;
}

export interface WaterfallSourceAdapter {
  readonly adapterId: string;
  readonly sourceId: AggregateSearchSource;
  readonly kind: WaterfallSourceAdapterKind;
  readonly pagination: WaterfallSourcePagination;
}

/** A configured source object with no mutable search-session state. */
export interface WaterfallSearchAdapter extends WaterfallSourceAdapter {
  readonly kind: 'search';
  /** Selects one query variant when the pool receives a bilingual topic. */
  readonly queryLanguagePolicy: WaterfallSearchQueryLanguagePolicy;

  search(request: WaterfallSourceSearchRequest): Promise<WaterfallSourcePage>;
}

/** A pull-based discovery source. The caller owns any continuation. */
export interface WaterfallDiscoveryAdapter extends WaterfallSourceAdapter {
  readonly kind: 'discovery' | 'scheduled_discovery';

  discover(request: WaterfallSourceDiscoveryRequest): Promise<WaterfallSourcePage>;
}

export type WaterfallScheduledDiscoveryListener = (page: WaterfallSourcePage) => void;

export interface WaterfallSourceSubscription {
  unsubscribe(): void;
}

/**
 * A discovery source that can still be pulled manually, while also publishing
 * snapshots on the cadence intrinsic to that source. Implementations start
 * scheduling when subscribed and stop after the final subscription is removed.
 * A direct discover() call only returns its page and does not notify listeners.
 */
export interface WaterfallScheduledDiscoveryAdapter extends WaterfallDiscoveryAdapter {
  readonly kind: 'scheduled_discovery';
  readonly refreshIntervalMs: number;

  subscribe(listener: WaterfallScheduledDiscoveryListener): WaterfallSourceSubscription;
}

/** Adapter registry consumed by the pool. One source may own several adapters. */
export interface WaterfallSourceAdapterRegistry {
  search: WaterfallSearchAdapter[];
  discovery: WaterfallDiscoveryAdapter[];
  scheduledDiscovery: WaterfallScheduledDiscoveryAdapter[];
}
