import { Want } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { describe, expect, it } from '@ohos/hypium';
import {
  BimDailyReminder,
  canRunBimSentinelMock,
  consumeBimSentinelMockHandoff,
  isBimReminderLimitMessage,
  queueBimSentinelMockHandoff,
  nextBimReminderAt,
  shouldScheduleBimDailyReminder
} from '../main/ets/pages/A2uiHome/bim/BimDailyReminder';
import { queueBimSentinelMockFromWant } from '../main/ets/entryability/EntryAbility';

export default function bimDailyReminderTest() {
  describe('bimDailyReminder', () => {
    it('schedules the next local nine o clock', 0, () => {
      expect(nextBimReminderAt(new Date('2026-08-10T10:00:00+08:00')))
        .assertEqual('2026-08-11T09:00:00+08:00');
    });

    it('publishes the next daily reminder only after a successful daily run', 0, () => {
      expect(shouldScheduleBimDailyReminder(true, true)).assertTrue();
      expect(shouldScheduleBimDailyReminder(false, true)).assertFalse();
      expect(shouldScheduleBimDailyReminder(true, false)).assertFalse();
    });

    it('publishes a visible BIM reminder that opens the app', 0, async () => {
      let published: reminderAgentManager.ReminderRequest | undefined;
      const reminder = new BimDailyReminder(
        async (request: reminderAgentManager.ReminderRequest): Promise<number> => {
          published = request;
          return 42;
        }
      );

      expect(await reminder.scheduleNext(new Date('2026-08-10T10:00:00+08:00'))).assertEqual(42);
      expect(published === undefined).assertFalse();
      if (published !== undefined) {
        expect(published.title).assertEqual('检查心上事');
        expect(published.wantAgent === undefined).assertFalse();
        if (published.wantAgent !== undefined) {
          expect(published.wantAgent.abilityName).assertEqual('EntryAbility');
        }
      }
    });

    it('publishes a ten second Sentinel debug timer', 0, async () => {
      let published: reminderAgentManager.ReminderRequest | undefined;
      const reminder = new BimDailyReminder(
        async (request: reminderAgentManager.ReminderRequest): Promise<number> => {
          published = request;
          return 43;
        }
      );

      expect(await reminder.scheduleDebug(10)).assertEqual(43);
      expect(published === undefined).assertFalse();
      if (published !== undefined) {
        const timer = published as reminderAgentManager.ReminderRequestTimer;
        expect(timer.reminderType).assertEqual(
          reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER
        );
        expect(timer.triggerTimeInSeconds).assertEqual(10);
        expect(timer.title).assertEqual('检查心上事（测试）');
        expect(timer.wantAgent?.parameters?.['bimDailySentinelMock']).assertEqual(true);
      }
    });

    it('recognizes only the reminder limit fallback', 0, () => {
      expect(isBimReminderLimitMessage('1700002: reminders exceeds the limit')).assertTrue();
      expect(isBimReminderLimitMessage('network unavailable')).assertFalse();
    });

    it('hands a mock trigger off exactly once', 0, () => {
      consumeBimSentinelMockHandoff();
      queueBimSentinelMockHandoff();
      expect(consumeBimSentinelMockHandoff()).assertTrue();
      expect(consumeBimSentinelMockHandoff()).assertFalse();
    });

    it('queues only an explicit Sentinel mock Want', 0, () => {
      consumeBimSentinelMockHandoff();
      expect(queueBimSentinelMockFromWant({
        parameters: { bimDailySentinelMock: true }
      } as Want)).assertTrue();
      expect(consumeBimSentinelMockHandoff()).assertTrue();
      expect(queueBimSentinelMockFromWant({ parameters: {} } as Want)).assertFalse();
      expect(consumeBimSentinelMockHandoff()).assertFalse();
    });

    it('runs a Sentinel mock only for an idle debug build', 0, () => {
      expect(canRunBimSentinelMock(true, false, false)).assertTrue();
      expect(canRunBimSentinelMock(false, false, false)).assertFalse();
      expect(canRunBimSentinelMock(true, true, false)).assertFalse();
      expect(canRunBimSentinelMock(true, false, true)).assertFalse();
    });
  });
}
