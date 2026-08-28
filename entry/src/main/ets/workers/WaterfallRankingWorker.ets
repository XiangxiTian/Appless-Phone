import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { finalizeInterestWaterfallRecallRanking, WaterfallFeedState } from '@loop/agent-core';

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

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

workerPort.onmessage = (event: MessageEvents): void => {
  const request = event.data as WaterfallRankingRequest;
  const startedAt = Date.now();
  try {
    const state = finalizeInterestWaterfallRecallRanking(
      request.state, request.nowMs, request.refreshDisplayWindow);
    const response: WaterfallRankingResponse = {
      jobId: request.jobId,
      ok: true,
      state,
      durationMs: Math.max(0, Date.now() - startedAt)
    };
    workerPort.postMessage(response);
  } catch (error) {
    const response: WaterfallRankingResponse = {
      jobId: request.jobId,
      ok: false,
      durationMs: Math.max(0, Date.now() - startedAt),
      error: error instanceof Error ? error.message : 'unknown ranking error'
    };
    workerPort.postMessage(response);
  }
};
