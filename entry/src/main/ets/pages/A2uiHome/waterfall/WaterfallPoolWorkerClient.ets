import { ErrorEvent, MessageEvents, worker } from '@kit.ArkTS';
import {
  AggregateSearchPolicy,
  aiLogInfo,
  WaterfallColdStartTopic,
  WaterfallPreferenceSnapshot,
  WaterfallSourcePoolEntry
} from '@loop/agent-core';

export interface WaterfallPoolWorkerCommand {
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

export type WaterfallPoolWorkerCommandObserver = (command: WaterfallPoolWorkerCommand) => void;

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

interface PendingPoolTake {
  resolve: (entries: WaterfallSourcePoolEntry[]) => void;
  reject: (error: Error) => void;
  dispatchedAtMs: number;
}

export interface WaterfallPoolWorkerTake {
  readonly requestId: number;
  promise: Promise<WaterfallSourcePoolEntry[]>;
  cancel(): void;
}

class DefaultWaterfallPoolWorkerTake implements WaterfallPoolWorkerTake {
  readonly requestId: number;
  readonly promise: Promise<WaterfallSourcePoolEntry[]>;
  private readonly cancelCallback: () => void;

  constructor(requestId: number, promise: Promise<WaterfallSourcePoolEntry[]>, cancelCallback: () => void) {
    this.requestId = requestId;
    this.promise = promise;
    this.cancelCallback = cancelCallback;
  }

  cancel(): void {
    this.cancelCallback();
  }
}

export class WaterfallPoolWorkerClient {
  private workerInstance: worker.ThreadWorker | null = null;
  private readonly providerConfigJson: string;
  private readonly composioConfigJson: string;
  private searchPolicy: AggregateSearchPolicy;
  private readonly commandObserver: WaterfallPoolWorkerCommandObserver | null;
  private readonly pendingTakes: Map<number, PendingPoolTake> = new Map<number, PendingPoolTake>();
  private nextRequestId: number = 1;

  constructor(
    providerConfigJson: string,
    composioConfigJson: string,
    searchPolicy: AggregateSearchPolicy,
    commandObserver: WaterfallPoolWorkerCommandObserver | null = null
  ) {
    this.providerConfigJson = providerConfigJson;
    this.composioConfigJson = composioConfigJson;
    this.searchPolicy = {
      domesticOnly: searchPolicy.domesticOnly,
      multilingual: searchPolicy.multilingual
    };
    this.commandObserver = commandObserver;
  }

  start(initialTopicCount: number, topicIntervalMs: number): void {
    this.post({
      type: 'start',
      initialTopicCount,
      topicIntervalMs
    });
  }

  supplementTopic(topic: WaterfallColdStartTopic): void {
    this.post({ type: 'supplement_topic', topic });
  }

  activate(): void {
    this.post({ type: 'activate' });
  }

  setEnabledAdapters(enabledAdapterIds: string[]): void {
    this.post({ type: 'set_enabled_adapters', enabledAdapterIds: enabledAdapterIds.slice() });
  }

  setSearchPolicy(searchPolicy: AggregateSearchPolicy): void {
    this.searchPolicy = {
      domesticOnly: searchPolicy.domesticOnly,
      multilingual: searchPolicy.multilingual
    };
    if (this.workerInstance !== null || this.commandObserver !== null) {
      this.post({ type: 'set_search_policy', searchPolicy: this.searchPolicy });
    }
  }

  takeOrWait(
    profile: WaterfallPreferenceSnapshot,
    enabledSources: string[],
    limit: number
  ): WaterfallPoolWorkerTake {
    const requestId = this.nextRequestId++;
    const dispatchedAtMs = Date.now();
    let settled = false;
    let resolveTake: (entries: WaterfallSourcePoolEntry[]) => void =
      (_entries: WaterfallSourcePoolEntry[]): void => {};
    let rejectTake: (error: Error) => void = (_error: Error): void => {};
    const promise = new Promise<WaterfallSourcePoolEntry[]>((resolve, reject): void => {
      resolveTake = resolve;
      rejectTake = reject;
    });
    this.pendingTakes.set(requestId, {
      resolve: (entries: WaterfallSourcePoolEntry[]): void => {
        if (settled) return;
        settled = true;
        resolveTake(entries);
      },
      reject: (error: Error): void => {
        if (settled) return;
        settled = true;
        rejectTake(error);
      },
      dispatchedAtMs
    });
    try {
      this.post({
        type: 'take_or_wait',
        requestId,
        profile,
        enabledSources: enabledSources.slice(),
        limit
      });
    } catch (error) {
      this.pendingTakes.delete(requestId);
      rejectTake(error instanceof Error ? error : new Error('waterfall pool worker dispatch failed'));
    }
    return new DefaultWaterfallPoolWorkerTake(
      requestId,
      promise,
      (): void => {
        const pending = this.pendingTakes.get(requestId);
        if (pending === undefined) return;
        this.pendingTakes.delete(requestId);
        pending.resolve([]);
        this.post({ type: 'cancel_take', requestId });
      }
    );
  }

  dispose(): void {
    const disposed = new Error('waterfall pool worker disposed');
    this.pendingTakes.forEach((pending: PendingPoolTake): void => pending.reject(disposed));
    this.pendingTakes.clear();
    if (this.workerInstance !== null) {
      try {
        this.workerInstance.terminate();
      } catch (_error) {
      }
    }
    this.workerInstance = null;
  }

  private ensureWorker(): worker.ThreadWorker {
    if (this.workerInstance !== null) return this.workerInstance;
    const instance = new worker.ThreadWorker(
      'entry/ets/workers/WaterfallPoolWorker.ets', { name: 'waterfall-pool' });
    instance.onmessage = (event: MessageEvents): void => {
      this.handleMessage(event.data as WaterfallPoolWorkerResponse);
    };
    instance.onmessageerror = (_event: MessageEvents): void => {
      this.failPending(new Error('waterfall pool worker message serialization failed'));
    };
    instance.onerror = (error: ErrorEvent): void => {
      this.workerInstance = null;
      this.failPending(new Error(error.message || 'waterfall pool worker failed'));
    };
    this.workerInstance = instance;
    const initialize: WaterfallPoolWorkerCommand = {
      type: 'initialize',
      providerConfigJson: this.providerConfigJson,
      composioConfigJson: this.composioConfigJson,
      searchPolicy: this.searchPolicy
    };
    instance.postMessage(initialize);
    return instance;
  }

  private post(command: WaterfallPoolWorkerCommand): void {
    if (this.commandObserver !== null) {
      this.commandObserver(command);
      return;
    }
    this.ensureWorker().postMessage(command);
  }

  private handleMessage(response: WaterfallPoolWorkerResponse): void {
    if (response.type !== 'take_result') return;
    const pending = this.pendingTakes.get(response.requestId);
    if (pending === undefined) return;
    this.pendingTakes.delete(response.requestId);
    const receivedAtMs = Date.now();
    const workerReceivedAtMs = response.workerReceivedAtMs ?? receivedAtMs;
    const workerPostedAtMs = response.workerPostedAtMs ?? receivedAtMs;
    aiLogInfo('[AIPhone][WaterfallPoolTimingWorker] requestId=' + response.requestId.toString() +
      ' dispatchToWorkerMs=' + Math.max(0, workerReceivedAtMs - pending.dispatchedAtMs).toString() +
      ' waitMs=' + (response.workerWaitMs ?? 0).toString() +
      ' takeMs=' + (response.workerTakeMs ?? 0).toString() +
      ' waitCycles=' + (response.workerWaitCycles ?? 0).toString() +
      ' workerToMainMs=' + Math.max(0, receivedAtMs - workerPostedAtMs).toString() +
      ' totalMs=' + Math.max(0, receivedAtMs - pending.dispatchedAtMs).toString() +
      ' count=' + (response.entries ?? []).length.toString());
    if (response.error !== undefined && response.error.length > 0) {
      pending.reject(new Error(response.error));
      return;
    }
    pending.resolve(response.entries ?? []);
  }

  private failPending(error: Error): void {
    const pending: PendingPoolTake[] = [];
    this.pendingTakes.forEach((value: PendingPoolTake): void => {
      pending.push(value);
    });
    this.pendingTakes.clear();
    pending.forEach((value: PendingPoolTake): void => value.reject(error));
  }
}
