import { ErrorEvent, MessageEvents, worker } from '@kit.ArkTS';
import { WaterfallFeedState } from '@loop/agent-core';

export interface WaterfallRankingWorkerResult {
  state: WaterfallFeedState;
  workerDurationMs: number;
  queuedDurationMs: number;
}

interface WaterfallRankingRequest {
  jobId: number;
  state: WaterfallFeedState;
  nowMs: number;
  refreshDisplayWindow: boolean;
}

interface WaterfallRankingResponse {
  jobId: number;
  ok: boolean;
  state?: WaterfallFeedState;
  durationMs: number;
  error?: string;
}

interface PendingWaterfallRankingJob {
  jobId: number;
  lane: string;
  state: WaterfallFeedState;
  nowMs: number;
  refreshDisplayWindow: boolean;
  queuedAtMs: number;
  resolve: (result: WaterfallRankingWorkerResult | null) => void;
  reject: (error: Error) => void;
}

export class WaterfallRankingWorkerClient {
  private workerInstance: worker.ThreadWorker | null = null;
  private activeJob: PendingWaterfallRankingJob | null = null;
  private queuedJobs: Map<string, PendingWaterfallRankingJob> = new Map<string, PendingWaterfallRankingJob>();
  private nextJobId: number = 0;

  rank(
    lane: string,
    state: WaterfallFeedState,
    nowMs: number,
    refreshDisplayWindow: boolean
  ): Promise<WaterfallRankingWorkerResult | null> {
    return new Promise<WaterfallRankingWorkerResult | null>((resolve, reject): void => {
      this.nextJobId += 1;
      const job: PendingWaterfallRankingJob = {
        jobId: this.nextJobId,
        lane,
        state,
        nowMs,
        refreshDisplayWindow,
        queuedAtMs: Date.now(),
        resolve,
        reject
      };
      if (this.activeJob === null) {
        this.dispatch(job);
        return;
      }
      const superseded = this.queuedJobs.get(lane);
      if (superseded !== undefined) superseded.resolve(null);
      this.queuedJobs.set(lane, job);
    });
  }

  dispose(): void {
    const disposed = new Error('waterfall ranking worker disposed');
    if (this.activeJob !== null) this.activeJob.reject(disposed);
    this.activeJob = null;
    this.queuedJobs.forEach((job: PendingWaterfallRankingJob): void => job.reject(disposed));
    this.queuedJobs.clear();
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
      'entry/ets/workers/WaterfallRankingWorker.ets', { name: 'waterfall-ranking' });
    instance.onmessage = (event: MessageEvents): void => {
      this.handleMessage(event.data as WaterfallRankingResponse);
    };
    instance.onmessageerror = (_event: MessageEvents): void => {
      this.failActive(new Error('waterfall ranking worker message serialization failed'));
    };
    instance.onerror = (error: ErrorEvent): void => {
      this.workerInstance = null;
      this.failActive(new Error(error.message || 'waterfall ranking worker failed'));
    };
    this.workerInstance = instance;
    return instance;
  }

  private dispatch(job: PendingWaterfallRankingJob): void {
    this.activeJob = job;
    const request: WaterfallRankingRequest = {
      jobId: job.jobId,
      state: job.state,
      nowMs: job.nowMs,
      refreshDisplayWindow: job.refreshDisplayWindow
    };
    try {
      this.ensureWorker().postMessage(request);
    } catch (error) {
      this.failActive(error instanceof Error ? error : new Error('waterfall ranking worker dispatch failed'));
    }
  }

  private handleMessage(response: WaterfallRankingResponse): void {
    const active = this.activeJob;
    if (active === null || response.jobId !== active.jobId) return;
    this.activeJob = null;
    if (response.ok && response.state !== undefined) {
      active.resolve({
        state: response.state,
        workerDurationMs: response.durationMs,
        queuedDurationMs: Math.max(0, Date.now() - active.queuedAtMs - response.durationMs)
      });
    } else {
      active.reject(new Error(response.error ?? 'waterfall ranking worker returned no state'));
    }
    this.dispatchNext();
  }

  private failActive(error: Error): void {
    const active = this.activeJob;
    this.activeJob = null;
    if (active !== null) active.reject(error);
    this.dispatchNext();
  }

  private dispatchNext(): void {
    if (this.activeJob !== null || this.queuedJobs.size === 0) return;
    const activeLane = this.queuedJobs.get('active');
    if (activeLane !== undefined) {
      this.queuedJobs.delete('active');
      this.dispatch(activeLane);
      return;
    }
    const iterator = this.queuedJobs.values();
    const next = iterator.next();
    if (next.done || next.value === undefined) return;
    this.queuedJobs.delete(next.value.lane);
    this.dispatch(next.value);
  }
}
