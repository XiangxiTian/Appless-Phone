import { reminderAgentManager } from '@kit.BackgroundTasksKit';

const BUNDLE_NAME: string = 'com.example.aiphonedemo';
const ABILITY_NAME: string = 'EntryAbility';
export const BIM_SENTINEL_MOCK_EVENT: string = 'bimSentinelMockRequested';
let bimSentinelMockPending: boolean = false;

export function queueBimSentinelMockHandoff(): void {
  bimSentinelMockPending = true;
}

export function consumeBimSentinelMockHandoff(): boolean {
  const pending = bimSentinelMockPending;
  bimSentinelMockPending = false;
  return pending;
}

export function canRunBimSentinelMock(
  isDebugBuild: boolean,
  mainBusy: boolean,
  sentinelBusy: boolean
): boolean {
  return isDebugBuild && !mainBusy && !sentinelBusy;
}

export function shouldScheduleBimDailyReminder(
  sentinelSucceeded: boolean,
  dailyRun: boolean
): boolean {
  return sentinelSucceeded && dailyRun;
}

export function isBimReminderLimitMessage(message: string): boolean {
  return message.includes('1700002') || message.includes('exceeds the limit');
}

function two(value: number): string {
  return value.toString().padStart(2, '0');
}

function localIso(value: Date): string {
  const minutes = -value.getTimezoneOffset();
  const sign = minutes >= 0 ? '+' : '-';
  const absolute = Math.abs(minutes);
  return value.getFullYear().toString() + '-' + two(value.getMonth() + 1) + '-' +
    two(value.getDate()) + 'T' + two(value.getHours()) + ':' + two(value.getMinutes()) +
    ':' + two(value.getSeconds()) + sign + two(Math.floor(absolute / 60)) + ':' + two(absolute % 60);
}

export function nextBimReminderAt(now: Date): string {
  const next = new Date(now.getTime());
  next.setHours(9, 0, 0, 0);
  if (next.getTime() <= now.getTime()) next.setDate(next.getDate() + 1);
  return localIso(next);
}

export function buildBimDailyReminderRequest(
  fireAt: string
): reminderAgentManager.ReminderRequestCalendar {
  const fireDate = new Date(fireAt);
  if (isNaN(fireDate.getTime())) throw new Error('Invalid reminder time');
  return {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
    dateTime: {
      year: fireDate.getFullYear(),
      month: fireDate.getMonth() + 1,
      day: fireDate.getDate(),
      hour: fireDate.getHours(),
      minute: fireDate.getMinutes(),
      second: fireDate.getSeconds()
    },
    wantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME,
      parameters: { bimDailySentinel: true }
    },
    maxScreenWantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME
    },
    title: '检查心上事',
    content: '看看今天有没有需要关注的事项',
    tapDismissed: true
  };
}

export function buildBimSentinelDebugReminderRequest(
  delaySeconds: number
): reminderAgentManager.ReminderRequestTimer {
  if (!isFinite(delaySeconds) || delaySeconds <= 0 || Math.floor(delaySeconds) !== delaySeconds) {
    throw new Error('Invalid reminder delay');
  }
  return {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
    triggerTimeInSeconds: delaySeconds,
    wantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME,
      parameters: { bimDailySentinel: true, bimDailySentinelMock: true }
    },
    maxScreenWantAgent: {
      pkgName: BUNDLE_NAME,
      abilityName: ABILITY_NAME
    },
    title: '检查心上事（测试）',
    content: '10 秒测试提醒',
    tapDismissed: true
  };
}

export class BimDailyReminder {
  private readonly publish: (request: reminderAgentManager.ReminderRequest) => Promise<number>;

  constructor(
    publish: (request: reminderAgentManager.ReminderRequest) => Promise<number> =
      reminderAgentManager.publishReminder
  ) {
    this.publish = publish;
  }

  async scheduleNext(now: Date): Promise<number> {
    return this.publish(buildBimDailyReminderRequest(nextBimReminderAt(now)));
  }

  async scheduleDebug(delaySeconds: number = 10): Promise<number> {
    return this.publish(buildBimSentinelDebugReminderRequest(delaySeconds));
  }
}
