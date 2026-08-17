import { common } from '@kit.AbilityKit';
import { calendarManager } from '@kit.CalendarKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { aiLogError, aiLogInfo } from './AiphoneLogger';
import { HuaweiCalendarAddResult, MailCalendarSuggestion } from './MailToolTypes';

export interface HuaweiTravelCalendarEvent {
  requestKey: string;
  title: string;
  startTime: number;
  endTime: number;
  location: string;
  description: string;
  reminderTime: number[];
}

export interface HuaweiTravelCalendarAddResult extends HuaweiCalendarAddResult {
  duplicate: boolean;
}

export interface HuaweiTravelCalendarConflict {
  requestKey: string;
  conflict: boolean;
  eventId: string;
  eventTitle: string;
  eventStartTime: number;
  eventEndTime: number;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function parseEventTime(value: string): number {
  const parsed = Date.parse(value.trim());
  return Number.isNaN(parsed) ? 0 : parsed;
}

function fallbackEndTime(startMs: number, endMs: number): number {
  if (endMs > startMs) {
    return endMs;
  }
  return startMs + 30 * 60 * 1000;
}

function eventDescription(suggestion: MailCalendarSuggestion): string {
  const parts: string[] = [];
  const description = textOf(suggestion.description).trim();
  if (description.length > 0) {
    parts.push(description);
  }
  parts.push('Source: Appless mail');
  parts.push('Provider: ' + textOf(suggestion.provider));
  parts.push('Thread ID: ' + textOf(suggestion.threadId));
  parts.push('Message ID: ' + textOf(suggestion.messageId));
  return parts.join('\n');
}

export async function addHuaweiCalendarEvent(
  context: common.UIAbilityContext,
  suggestion: MailCalendarSuggestion
): Promise<HuaweiCalendarAddResult> {
  const title = textOf(suggestion.title).trim();
  const startMs = parseEventTime(suggestion.start);
  const endMs = fallbackEndTime(startMs, parseEventTime(suggestion.end));
  if (title.length === 0 || startMs <= 0) {
    throw new Error('日程缺少标题或开始时间。');
  }
  try {
    const calendarMgr = calendarManager.getCalendarManager(context);
    const calendar = await calendarMgr.getCalendar();
    const event: calendarManager.Event = {
      title: title,
      type: calendarManager.EventType.NORMAL,
      startTime: startMs,
      endTime: endMs,
      location: { location: textOf(suggestion.location).trim() },
      reminderTime: [10],
      description: eventDescription(suggestion)
    };
    const eventId = await calendar.addEvent(event);
    aiLogInfo('[AIPhone][HuaweiCalendarAdd] ok=true eventId=' + eventId.toString() +
      ' requestKey=' + textOf(suggestion.requestKey));
    return {
      requestKey: textOf(suggestion.requestKey),
      eventId: eventId.toString(),
      status: 'success',
      message: '已添加日程'
    };
  } catch (error) {
    const businessError = error as BusinessError;
    const message = businessError.message !== undefined ? businessError.message :
      (error instanceof Error ? error.message : JSON.stringify(error));
    aiLogError('[AIPhone][HuaweiCalendarAdd] ok=false message=' + message.substring(0, 240));
    throw new Error(message);
  }
}

function travelEventDescription(input: HuaweiTravelCalendarEvent): string {
  const description = textOf(input.description).trim();
  const key = 'Appless travel key: ' + textOf(input.requestKey).trim();
  return description.length > 0 ? description + '\n' + key : key;
}

function matchingTravelEvent(
  events: calendarManager.Event[],
  input: HuaweiTravelCalendarEvent
): calendarManager.Event | null {
  const key = textOf(input.requestKey).trim();
  for (let index = 0; index < events.length; index++) {
    const event = events[index];
    if (textOf(event.identifier).trim() === key ||
      textOf(event.description).indexOf('Appless travel key: ' + key) >= 0 ||
      (textOf(event.title).trim() === input.title.trim() &&
        event.startTime === input.startTime && event.endTime === input.endTime)) {
      return event;
    }
  }
  return null;
}

function overlappingTravelEvent(
  events: calendarManager.Event[],
  input: HuaweiTravelCalendarEvent
): calendarManager.Event | null {
  for (let index = 0; index < events.length; index++) {
    const event = events[index];
    if (matchingTravelEvent([event], input) !== null) {
      continue;
    }
    if (event.startTime < input.endTime && event.endTime > input.startTime) {
      return event;
    }
  }
  return null;
}

export async function findHuaweiTravelCalendarConflicts(
  context: common.UIAbilityContext,
  inputs: HuaweiTravelCalendarEvent[]
): Promise<HuaweiTravelCalendarConflict[]> {
  if (inputs.length === 0) {
    return [];
  }
  let rangeStart = inputs[0].startTime;
  let rangeEnd = inputs[0].endTime;
  inputs.forEach((input: HuaweiTravelCalendarEvent) => {
    rangeStart = Math.min(rangeStart, input.startTime);
    rangeEnd = Math.max(rangeEnd, input.endTime);
  });
  try {
    const calendarMgr = calendarManager.getCalendarManager(context);
    const calendars = await calendarMgr.getAllCalendars();
    const existingEvents: calendarManager.Event[] = [];
    for (let calendarIndex = 0; calendarIndex < calendars.length; calendarIndex++) {
      const calendarEvents = await calendars[calendarIndex].getEvents(
        calendarManager.EventFilter.filterByTime(rangeStart, rangeEnd)
      );
      calendarEvents.forEach((event: calendarManager.Event) => {
        existingEvents.push(event);
      });
    }
    const conflicts: HuaweiTravelCalendarConflict[] = [];
    inputs.forEach((input: HuaweiTravelCalendarEvent) => {
      const event = overlappingTravelEvent(existingEvents, input);
      conflicts.push({
        requestKey: input.requestKey,
        conflict: event !== null,
        eventId: event === null || event.id === undefined ? '' : event.id.toString(),
        eventTitle: event === null ? '' : textOf(event.title).trim(),
        eventStartTime: event === null ? 0 : event.startTime,
        eventEndTime: event === null ? 0 : event.endTime
      });
    });
    aiLogInfo('[AIPhone][HuaweiTravelCalendarConflict] candidates=' + inputs.length.toString() +
      ' calendars=' + calendars.length.toString() +
      ' existing=' + existingEvents.length.toString() +
      ' conflicts=' + conflicts.filter((item: HuaweiTravelCalendarConflict) => item.conflict).length.toString());
    return conflicts;
  } catch (error) {
    const businessError = error as BusinessError;
    const message = businessError.message !== undefined ? businessError.message :
      (error instanceof Error ? error.message : JSON.stringify(error));
    aiLogError('[AIPhone][HuaweiTravelCalendarConflict] ok=false message=' + message.substring(0, 240));
    throw new Error(message);
  }
}

export async function addHuaweiTravelCalendarEvent(
  context: common.UIAbilityContext,
  input: HuaweiTravelCalendarEvent
): Promise<HuaweiTravelCalendarAddResult> {
  const requestKey = textOf(input.requestKey).trim();
  const title = textOf(input.title).trim();
  if (requestKey.length === 0 || title.length === 0 || input.startTime <= 0 || input.endTime <= input.startTime) {
    throw new Error('出行日程缺少班次、日期或时间。');
  }
  try {
    const calendarMgr = calendarManager.getCalendarManager(context);
    const calendar = await calendarMgr.getCalendar();
    const existingEvents = await calendar.getEvents(
      calendarManager.EventFilter.filterByTime(input.startTime - 60 * 1000, input.endTime + 60 * 1000)
    );
    const existing = matchingTravelEvent(existingEvents, input);
    if (existing !== null) {
      const existingId = existing.id === undefined ? '' : existing.id.toString();
      aiLogInfo('[AIPhone][HuaweiTravelCalendarAdd] ok=true duplicate=true eventId=' + existingId +
        ' requestKey=' + requestKey);
      return {
        requestKey: requestKey,
        eventId: existingId,
        status: 'exists',
        message: '该行程已在系统日历中',
        duplicate: true
      };
    }
    const event: calendarManager.Event = {
      title: title,
      type: calendarManager.EventType.NORMAL,
      startTime: input.startTime,
      endTime: input.endTime,
      location: { location: textOf(input.location).trim() },
      reminderTime: input.reminderTime.length > 0 ? input.reminderTime : [120, 30],
      description: travelEventDescription(input),
      identifier: requestKey
    };
    const eventId = await calendar.addEvent(event);
    aiLogInfo('[AIPhone][HuaweiTravelCalendarAdd] ok=true duplicate=false eventId=' + eventId.toString() +
      ' requestKey=' + requestKey);
    return {
      requestKey: requestKey,
      eventId: eventId.toString(),
      status: 'success',
      message: '已加入系统日历',
      duplicate: false
    };
  } catch (error) {
    const businessError = error as BusinessError;
    const message = businessError.message !== undefined ? businessError.message :
      (error instanceof Error ? error.message : JSON.stringify(error));
    aiLogError('[AIPhone][HuaweiTravelCalendarAdd] ok=false message=' + message.substring(0, 240));
    throw new Error(message);
  }
}
