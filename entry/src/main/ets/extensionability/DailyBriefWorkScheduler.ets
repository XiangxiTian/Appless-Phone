import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { loadProviderRuntimeConfig } from '../entryability/ProviderRuntimeBootstrap';
import { dailyBriefDate } from '../pages/A2uiHome/dailybrief/DailyBriefCore';
import { generateDailyBrief } from '../pages/A2uiHome/dailybrief/DailyBriefGenerator';
import {
  completeDailyBriefWork,
  generateDailyBriefSnapshotIfMissing,
  scheduleNextDailyBrief
} from '../pages/A2uiHome/dailybrief/DailyBriefScheduler';
import { DailyBriefStore } from '../pages/A2uiHome/dailybrief/DailyBriefStore';
import { DailyBriefPreference, DailyBriefSnapshot } from '../pages/A2uiHome/dailybrief/DailyBriefTypes';

export default class DailyBriefWorkScheduler extends WorkSchedulerExtensionAbility {
  onWorkStart(work: workScheduler.WorkInfo): void {
    this.generateAndReschedule(work);
  }

  private async generateAndReschedule(work: workScheduler.WorkInfo): Promise<void> {
    try {
      loadProviderRuntimeConfig(this.context, true);
      const now = new Date();
      const store = new DailyBriefStore(this.context);
      const preference: DailyBriefPreference = store.loadPreference();
      const date = dailyBriefDate(now);
      if (store.snapshotForDate(date) === null) {
        const saved = await generateDailyBriefSnapshotIfMissing(
          date,
          (snapshotDate: string): DailyBriefSnapshot | null => store.snapshotForDate(snapshotDate),
          (): Promise<DailyBriefSnapshot> => generateDailyBrief({ now: now, preference: preference }),
          (snapshot: DailyBriefSnapshot): boolean => store.saveSnapshot(snapshot)
        );
        if (!saved && store.snapshotForDate(date) === null) {
          aiLogError('[AIPhone][DailyBriefWork] snapshotSaved=false');
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][DailyBriefWork] error=' + message.substring(0, 240));
    } finally {
      const completed = completeDailyBriefWork(
        work,
        (currentWork: workScheduler.WorkInfo): void => workScheduler.stopWork(currentWork),
        (): string => new DailyBriefStore(this.context).loadPreference().targetTime,
        (targetTime: string): boolean =>
          scheduleNextDailyBrief(this.context.applicationInfo.name, new Date(), targetTime)
      );
      if (completed.stopError.length > 0) {
        aiLogError('[AIPhone][DailyBriefWork] stopError=' + completed.stopError.substring(0, 240));
      }
      aiLogInfo('[AIPhone][DailyBriefWork] nextScheduled=' + (completed.scheduled ? 'true' : 'false'));
    }
  }

  onWorkStop(work: workScheduler.WorkInfo): void {
    aiLogInfo('[AIPhone][DailyBriefWork] stopped workId=' + work.workId.toString());
  }
}
