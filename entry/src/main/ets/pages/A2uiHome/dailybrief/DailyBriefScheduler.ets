import { workScheduler } from '@kit.BackgroundTasksKit';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { DailyBriefSnapshot } from './DailyBriefTypes';

export const DAILY_BRIEF_WORK_ID: number = 60318;
export const DAILY_BRIEF_WORK_ABILITY: string = 'DailyBriefWorkScheduler';
const DEFAULT_TARGET_TIME: string = '08:30';

export type DailyBriefCatchUpEvent = 'lifecycle' | 'idle';

export interface DailyBriefCatchUpTransition {
  pending: boolean;
  run: boolean;
}

export interface DailyBriefWorkCompletion {
  scheduled: boolean;
  stopError: string;
}

function targetParts(targetTime: string): number[] {
  const normalized = /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(targetTime) ? targetTime : DEFAULT_TARGET_TIME;
  return [Number(normalized.substring(0, 2)), Number(normalized.substring(3, 5))];
}

function targetToday(now: Date, targetTime: string): Date {
  const parts = targetParts(targetTime);
  const target = new Date(now.getTime());
  target.setHours(parts[0], parts[1], 0, 0);
  return target;
}

export function nextDailyBriefTarget(now: Date, targetTime: string): Date {
  const target = targetToday(now, targetTime);
  if (target.getTime() <= now.getTime()) {
    target.setDate(target.getDate() + 1);
  }
  return target;
}

export function shouldCatchUpDailyBrief(
  now: Date,
  targetTime: string,
  hasTodaySnapshot: boolean
): boolean {
  return !hasTodaySnapshot && now.getTime() > targetToday(now, targetTime).getTime();
}

export function shouldStartDailyBriefCatchUp(
  now: Date,
  targetTime: string,
  hasTodaySnapshot: boolean,
  isBusy: boolean
): boolean {
  return !isBusy && shouldCatchUpDailyBrief(now, targetTime, hasTodaySnapshot);
}

export function transitionDailyBriefCatchUp(
  pending: boolean,
  event: DailyBriefCatchUpEvent,
  eligible: boolean,
  isBusy: boolean
): DailyBriefCatchUpTransition {
  if (event === 'idle') {
    const run = pending && !isBusy;
    return { pending: run ? false : pending, run };
  }
  if (!eligible) {
    return { pending: false, run: false };
  }
  return isBusy ? { pending: true, run: false } : { pending: false, run: true };
}

export async function generateDailyBriefSnapshotIfMissing(
  date: string,
  snapshotForDate: (date: string) => DailyBriefSnapshot | null,
  generate: () => Promise<DailyBriefSnapshot>,
  saveSnapshot: (snapshot: DailyBriefSnapshot) => boolean
): Promise<boolean> {
  if (snapshotForDate(date) !== null) return false;
  const generated = await generate();
  if (snapshotForDate(date) !== null) return false;
  return saveSnapshot(generated);
}

export function dailyBriefWorkInfo(
  bundleName: string,
  now: Date,
  targetTime: string
): workScheduler.WorkInfo {
  const nextTarget = nextDailyBriefTarget(now, targetTime);
  return {
    workId: DAILY_BRIEF_WORK_ID,
    bundleName: bundleName,
    abilityName: DAILY_BRIEF_WORK_ABILITY,
    isPersisted: true,
    networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
    earliestStartTime: Math.max(0, nextTarget.getTime() - now.getTime())
  };
}

export function completeDailyBriefWork(
  currentWork: workScheduler.WorkInfo,
  stopCurrent: (work: workScheduler.WorkInfo) => void,
  loadLatestTargetTime: () => string,
  scheduleNext: (targetTime: string) => boolean
): DailyBriefWorkCompletion {
  const stopInfo: workScheduler.WorkInfo = {
    workId: currentWork.workId,
    bundleName: currentWork.bundleName,
    abilityName: currentWork.abilityName,
    networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY
  };
  let stopError: string = '';
  try {
    stopCurrent(stopInfo);
  } catch (error) {
    stopError = error instanceof Error ? error.message : JSON.stringify(error);
  }
  const targetTime = loadLatestTargetTime();
  return {
    scheduled: scheduleNext(targetTime),
    stopError: stopError
  };
}

export function scheduleNextDailyBrief(bundleName: string, now: Date, targetTime: string): boolean {
  const info = dailyBriefWorkInfo(bundleName, now, targetTime);
  try {
    try {
      workScheduler.stopWork(info, true);
    } catch (_error) {
      aiLogInfo('[AIPhone][DailyBriefSchedule] priorWorkCancelled=false');
    }
    workScheduler.startWork(info);
    return true;
  } catch (error) {
    const message = error instanceof Error ? error.message : JSON.stringify(error);
    aiLogError('[AIPhone][DailyBriefSchedule] error=' + message.substring(0, 240));
    return false;
  }
}
