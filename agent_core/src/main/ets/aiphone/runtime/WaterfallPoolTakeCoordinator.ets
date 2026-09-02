import { WaterfallPoolAvailabilityWait } from './WaterfallPool';

export interface WaterfallPoolTakeCoordinatorOptions {
  maxAttempts: number;
  maxWaitMs: number;
  retryDelaysMs: number[];
  startedAtMs?: number;
}

export interface WaterfallPoolTakeCoordinatorCallbacks<T> {
  take(): T[];
  waitForAvailable(): WaterfallPoolAvailabilityWait;
  requestSupply(): void;
  isCancelled(): boolean;
  onWaitStarted(wait: WaterfallPoolAvailabilityWait): void;
  onWaitFinished(wait: WaterfallPoolAvailabilityWait): void;
}

export interface WaterfallPoolTakeCoordinatorResult<T> {
  entries: T[];
  attempts: number;
  waitCycles: number;
  waitMs: number;
  takeMs: number;
  cancelled: boolean;
  deadlineReached: boolean;
}

function normalizedCount(value: number, fallback: number): number {
  return Number.isFinite(value) && value > 0 ? Math.max(1, Math.floor(value)) : fallback;
}

function delayMsForAttempt(retryDelaysMs: number[], attempt: number): number {
  if (retryDelaysMs.length === 0) return 0;
  const index = Math.min(Math.max(0, attempt - 1), retryDelaysMs.length - 1);
  return Math.max(0, Math.floor(retryDelaysMs[index]));
}

function waitForDelay(delayMs: number): Promise<void> {
  if (delayMs <= 0) return Promise.resolve();
  return new Promise<void>((resolve): void => {
    setTimeout(resolve, delayMs);
  });
}

export async function coordinateWaterfallPoolTake<T>(
  callbacks: WaterfallPoolTakeCoordinatorCallbacks<T>,
  options: WaterfallPoolTakeCoordinatorOptions
): Promise<WaterfallPoolTakeCoordinatorResult<T>> {
  const maxAttempts = normalizedCount(options.maxAttempts, 1);
  const maxWaitMs = normalizedCount(options.maxWaitMs, 1);
  const startedAtMs = options.startedAtMs ?? Date.now();
  const deadlineMs = startedAtMs + maxWaitMs;
  let attempts = 0;
  let waitCycles = 0;
  let waitMs = 0;
  let takeMs = 0;
  let takeStartedAtMs = Date.now();
  let entries = callbacks.take();
  takeMs += Date.now() - takeStartedAtMs;

  while (entries.length === 0 && attempts < maxAttempts) {
    if (callbacks.isCancelled()) {
      return { entries: [], attempts, waitCycles, waitMs, takeMs, cancelled: true, deadlineReached: false };
    }
    const remainingWaitMs = deadlineMs - Date.now();
    if (remainingWaitMs <= 0) break;
    attempts++;
    const wait = callbacks.waitForAvailable();
    callbacks.onWaitStarted(wait);
    waitCycles++;
    const waitStartedAtMs = Date.now();
    const deadlineTimerId = setTimeout((): void => wait.cancel(), remainingWaitMs);
    callbacks.requestSupply();
    const available = await wait.promise;
    clearTimeout(deadlineTimerId);
    callbacks.onWaitFinished(wait);
    waitMs += Date.now() - waitStartedAtMs;
    if (callbacks.isCancelled()) {
      return { entries: [], attempts, waitCycles, waitMs, takeMs, cancelled: true, deadlineReached: false };
    }
    if (!available) {
      if (attempts < maxAttempts && Date.now() < deadlineMs) {
        await waitForDelay(delayMsForAttempt(options.retryDelaysMs, attempts));
      }
      continue;
    }
    takeStartedAtMs = Date.now();
    entries = callbacks.take();
    takeMs += Date.now() - takeStartedAtMs;
  }

  return {
    entries,
    attempts,
    waitCycles,
    waitMs,
    takeMs,
    cancelled: false,
    deadlineReached: entries.length === 0 && Date.now() >= deadlineMs
  };
}
