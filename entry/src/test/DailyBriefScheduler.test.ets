import { describe, expect, it } from '@ohos/hypium';
import { workScheduler } from '@kit.BackgroundTasksKit';
import {
  completeDailyBriefWork,
  dailyBriefWorkInfo,
  generateDailyBriefSnapshotIfMissing,
  nextDailyBriefTarget,
  shouldCatchUpDailyBrief,
  shouldStartDailyBriefCatchUp,
  transitionDailyBriefCatchUp
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefScheduler';
import { defaultDailyBriefPreference } from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefCore';
import { DailyBriefSnapshot } from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefTypes';

class Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void = (_value: T): void => {};

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void): void => {
      this.resolve = resolve;
    });
  }
}

function snapshot(generatedAt: string): DailyBriefSnapshot {
  return {
    schemaVersion: 1,
    date: '2026-08-10',
    generatedAt: generatedAt,
    status: 'complete',
    profile: defaultDailyBriefPreference(),
    topThree: [],
    sections: [],
    discovery: [],
    sources: [],
    waterfall: null,
    actions: []
  };
}

export default function dailyBriefSchedulerTest() {
  describe('DailyBriefScheduler', () => {
    it('schedules today before 08:30 and tomorrow after 08:30', 0, () => {
      const before = nextDailyBriefTarget(new Date(2026, 7, 10, 8, 0, 0, 0), '08:30');
      const after = nextDailyBriefTarget(new Date(2026, 7, 10, 9, 0, 0, 0), '08:30');

      expect(before.getFullYear()).assertEqual(2026);
      expect(before.getMonth()).assertEqual(7);
      expect(before.getDate()).assertEqual(10);
      expect(before.getHours()).assertEqual(8);
      expect(before.getMinutes()).assertEqual(30);
      expect(after.getFullYear()).assertEqual(2026);
      expect(after.getMonth()).assertEqual(7);
      expect(after.getDate()).assertEqual(11);
      expect(after.getHours()).assertEqual(8);
      expect(after.getMinutes()).assertEqual(30);
    });

    it('crosses month and year boundaries with local calendar setters', 0, () => {
      const nextMonth = nextDailyBriefTarget(new Date(2026, 7, 31, 9, 0, 0, 0), '08:30');
      const nextYear = nextDailyBriefTarget(new Date(2026, 11, 31, 9, 0, 0, 0), '08:30');

      expect(nextMonth.getFullYear()).assertEqual(2026);
      expect(nextMonth.getMonth()).assertEqual(8);
      expect(nextMonth.getDate()).assertEqual(1);
      expect(nextYear.getFullYear()).assertEqual(2027);
      expect(nextYear.getMonth()).assertEqual(0);
      expect(nextYear.getDate()).assertEqual(1);
    });

    it('preserves local target time across historical timezone offset boundaries', 0, () => {
      const now = new Date(1986, 4, 3, 9, 0, 0, 0);
      const target = nextDailyBriefTarget(now, '08:30');
      const wallClockDelay = 23 * 60 * 60 * 1000 + 30 * 60 * 1000;
      const offsetAdjustment = (target.getTimezoneOffset() - now.getTimezoneOffset()) * 60 * 1000;

      expect(target.getFullYear()).assertEqual(1986);
      expect(target.getMonth()).assertEqual(4);
      expect(target.getDate()).assertEqual(4);
      expect(target.getHours()).assertEqual(8);
      expect(target.getMinutes()).assertEqual(30);
      expect(target.getTime() - now.getTime()).assertEqual(wallClockDelay + offsetAdjustment);
    });

    it('builds provider-backed persisted work with any network and a non-negative delay', 0, () => {
      const now = new Date(2026, 7, 10, 8, 0, 0, 0);
      const info = dailyBriefWorkInfo('com.example.current', now, '08:30');

      expect(info.workId).assertEqual(60318);
      expect(info.bundleName).assertEqual('com.example.current');
      expect(info.abilityName).assertEqual('DailyBriefWorkScheduler');
      expect(info.isPersisted).assertTrue();
      expect(info.networkType).assertEqual(workScheduler.NetworkType.NETWORK_TYPE_ANY);
      expect(info.earliestStartTime === undefined).assertFalse();
      if (info.earliestStartTime !== undefined) {
        expect(info.earliestStartTime).assertEqual(30 * 60 * 1000);
        expect(info.earliestStartTime >= 0).assertTrue();
      }
    });

    it('stops the sanitized current work before scheduling its replacement', 0, () => {
      const callbackWork: workScheduler.WorkInfo = {
        workId: 60318,
        bundleName: 'com.example.current',
        abilityName: 'DailyBriefWorkScheduler',
        isPersisted: true,
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        earliestStartTime: 1,
        parameters: { callback: 'current' }
      };
      const calls: string[] = [];
      let stopped: workScheduler.WorkInfo = callbackWork;
      const completed = completeDailyBriefWork(
        callbackWork,
        (info: workScheduler.WorkInfo): void => {
          calls.push('stop');
          stopped = info;
        },
        (): string => {
          calls.push('load');
          return '08:30';
        },
        (targetTime: string): boolean => {
          expect(targetTime).assertEqual('08:30');
          calls.push('schedule');
          return true;
        }
      );

      expect(calls.join(',')).assertEqual('stop,load,schedule');
      expect(completed.scheduled).assertTrue();
      expect(completed.stopError).assertEqual('');
      expect(stopped.workId).assertEqual(60318);
      expect(stopped.bundleName).assertEqual('com.example.current');
      expect(stopped.abilityName).assertEqual('DailyBriefWorkScheduler');
      expect(stopped.networkType).assertEqual(workScheduler.NetworkType.NETWORK_TYPE_ANY);
      expect(stopped.isPersisted === undefined).assertTrue();
      expect(stopped.earliestStartTime === undefined).assertTrue();
      expect(stopped.parameters === undefined).assertTrue();

      const failureCalls: string[] = [];
      const recovered = completeDailyBriefWork(
        callbackWork,
        (_info: workScheduler.WorkInfo): void => {
          failureCalls.push('stop');
          throw new Error('stop failed');
        },
        (): string => {
          failureCalls.push('load');
          return '09:47';
        },
        (targetTime: string): boolean => {
          expect(targetTime).assertEqual('09:47');
          failureCalls.push('schedule');
          return true;
        }
      );

      expect(failureCalls.join(',')).assertEqual('stop,load,schedule');
      expect(recovered.scheduled).assertTrue();
      expect(recovered.stopError).assertEqual('stop failed');
    });

    it('loads the latest target after delayed generation before scheduling its replacement', 0, async () => {
      const callbackWork: workScheduler.WorkInfo = {
        workId: 60318,
        bundleName: 'com.example.current',
        abilityName: 'DailyBriefWorkScheduler',
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY
      };
      const generation = new Deferred<void>();
      const calls: string[] = [];
      let storedTargetTime: string = '08:30';
      let scheduledTargetTime: string = '';
      const pending = generation.promise.then(() => completeDailyBriefWork(
        callbackWork,
        (_info: workScheduler.WorkInfo): void => {
          calls.push('stop');
        },
        (): string => {
          calls.push('load');
          return storedTargetTime;
        },
        (targetTime: string): boolean => {
          calls.push('schedule:' + targetTime);
          scheduledTargetTime = targetTime;
          return true;
        }
      ));

      storedTargetTime = '09:47';
      generation.resolve(undefined);

      const completed = await pending;
      expect(calls.join(',')).assertEqual('stop,load,schedule:09:47');
      expect(scheduledTargetTime).assertEqual('09:47');
      expect(completed.scheduled).assertTrue();
      expect(completed.stopError).assertEqual('');
    });

    it('catches up only after the target when today has no snapshot', 0, () => {
      const before = new Date(2026, 7, 10, 8, 29, 59, 999);
      const after = new Date(2026, 7, 10, 8, 30, 0, 1);

      expect(shouldCatchUpDailyBrief(before, '08:30', false)).assertFalse();
      expect(shouldCatchUpDailyBrief(after, '08:30', false)).assertTrue();
      expect(shouldCatchUpDailyBrief(after, '08:30', true)).assertFalse();
    });

    it('keeps the next work schedulable but defers catch-up for any busy foreground turn', 0, () => {
      const now = new Date(2026, 7, 10, 9, 0, 0, 0);
      const nextWork = dailyBriefWorkInfo('com.example.current', now, '08:30');

      expect(nextWork.earliestStartTime === undefined).assertFalse();
      expect(shouldStartDailyBriefCatchUp(now, '08:30', false, true)).assertFalse();
      expect(shouldStartDailyBriefCatchUp(now, '08:30', false, false)).assertTrue();
      expect(shouldStartDailyBriefCatchUp(now, '08:30', true, false)).assertFalse();
    });

    it('marks a busy lifecycle catch-up pending and consumes exactly one later idle retry', 0, () => {
      const now = new Date(2026, 7, 10, 9, 0, 0, 0);
      const scheduled = dailyBriefWorkInfo('com.example.current', now, '08:30');
      const deferred = transitionDailyBriefCatchUp(false, 'lifecycle', true, true);
      const firstIdle = transitionDailyBriefCatchUp(deferred.pending, 'idle', true, false);
      const secondIdle = transitionDailyBriefCatchUp(firstIdle.pending, 'idle', true, false);

      expect(scheduled.earliestStartTime === undefined).assertFalse();
      expect(deferred.pending).assertTrue();
      expect(deferred.run).assertFalse();
      expect(firstIdle.pending).assertFalse();
      expect(firstIdle.run).assertTrue();
      expect(secondIdle.pending).assertFalse();
      expect(secondIdle.run).assertFalse();
    });

    it('falls back to 08:30 for an invalid target time', 0, () => {
      const target = nextDailyBriefTarget(new Date(2026, 7, 10, 8, 0, 0, 0), '25:90');

      expect(target.getDate()).assertEqual(10);
      expect(target.getHours()).assertEqual(8);
      expect(target.getMinutes()).assertEqual(30);
    });

    it('keeps a foreground snapshot written while background generation is pending', 0, async () => {
      const generation = new Deferred<DailyBriefSnapshot>();
      let stored: DailyBriefSnapshot | null = null;
      const pending = generateDailyBriefSnapshotIfMissing(
        '2026-08-10',
        (_date: string): DailyBriefSnapshot | null => stored,
        (): Promise<DailyBriefSnapshot> => generation.promise,
        (value: DailyBriefSnapshot): boolean => {
          stored = value;
          return true;
        }
      );
      stored = snapshot('2026-08-10T08:31:30+08:00');

      generation.resolve(snapshot('2026-08-10T08:31:00+08:00'));

      expect(await pending).assertFalse();
      expect(stored === null).assertFalse();
      if (stored !== null) {
        expect(stored.generatedAt).assertEqual('2026-08-10T08:31:30+08:00');
      }
    });
  });
}
