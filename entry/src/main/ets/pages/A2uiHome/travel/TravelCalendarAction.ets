import {
  A2uiAction,
  A2uiFlightData,
  A2uiRuntimeDataModel,
  A2uiTrainData,
  A2uiTravelOptionData,
  HuaweiTravelCalendarConflict,
  HuaweiTravelCalendarEvent
} from '@loop/agent-core';

export const TRAVEL_CALENDAR_ADD_ACTION_ID: string = 'travel.calendar.add';

type TravelCalendarCollection = 'travel' | 'train' | 'flight';

interface TravelCalendarActionPayload {
  calendarCollection: TravelCalendarCollection;
  id?: string;
  source?: string;
  trainCode?: string;
  flightNo?: string;
  depart?: string;
  depTime?: string;
  from?: string;
  to?: string;
  dep?: string;
  arr?: string;
}

function textOf(value: string | undefined): string {
  return value === undefined ? '' : value.trim();
}

function clockParts(value: string): number[] | null {
  const match = /(\d{1,2}):(\d{2})/.exec(value.trim());
  if (match === null) {
    return null;
  }
  const hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return [hour, minute];
}

function localTravelTime(dateText: string, clockText: string): number {
  const dateMatch = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(dateText.trim());
  const clock = clockParts(clockText);
  if (dateMatch === null || clock === null) {
    return 0;
  }
  const year = Number.parseInt(dateMatch[1], 10);
  const month = Number.parseInt(dateMatch[2], 10);
  const day = Number.parseInt(dateMatch[3], 10);
  const value = new Date(year, month - 1, day, clock[0], clock[1], 0, 0);
  if (value.getFullYear() !== year || value.getMonth() !== month - 1 || value.getDate() !== day) {
    return 0;
  }
  return value.getTime();
}

function travelCalendarEvent(
  source: string,
  serviceNo: string,
  travelDate: string,
  from: string,
  to: string,
  depart: string,
  arrive: string,
  provider: string
): HuaweiTravelCalendarEvent | null {
  const normalizedSource = textOf(source);
  const normalizedServiceNo = textOf(serviceNo);
  const normalizedDate = textOf(travelDate);
  const normalizedFrom = textOf(from);
  const normalizedTo = textOf(to);
  const normalizedDepart = textOf(depart);
  const normalizedArrive = textOf(arrive);
  if ((normalizedSource !== 'train' && normalizedSource !== 'flight') ||
    normalizedServiceNo.length === 0 || normalizedFrom.length === 0 || normalizedTo.length === 0) {
    return null;
  }
  const startTime = localTravelTime(normalizedDate, normalizedDepart);
  let endTime = localTravelTime(normalizedDate, normalizedArrive);
  if (startTime <= 0 || endTime <= 0) {
    return null;
  }
  if (endTime <= startTime) {
    endTime += 24 * 60 * 60 * 1000;
  }
  const sourceLabel = normalizedSource === 'flight' ? '航班' : '高铁';
  const requestKey = [
    'appless-travel', normalizedSource, normalizedDate, normalizedServiceNo,
    normalizedFrom, normalizedTo, normalizedDepart, normalizedArrive
  ].join('|');
  return {
    requestKey: requestKey,
    title: sourceLabel + ' ' + normalizedServiceNo + ' · ' + normalizedFrom + ' → ' + normalizedTo,
    startTime: startTime,
    endTime: endTime,
    location: normalizedFrom,
    description: '路线：' + normalizedFrom + ' → ' + normalizedTo + '\n' +
      '班次：' + normalizedServiceNo + '\n' +
      '来源：' + textOf(provider) + '\n由 Appless 添加。',
    reminderTime: [120, 30]
  };
}

export function travelCalendarEventFromTrain(item: A2uiTrainData): HuaweiTravelCalendarEvent | null {
  return travelCalendarEvent(
    'train', item.trainCode, textOf(item.travelDate), item.from, item.to, item.depart, item.arrive, '12306'
  );
}

export function travelCalendarEventFromFlight(item: A2uiFlightData): HuaweiTravelCalendarEvent | null {
  return travelCalendarEvent(
    'flight', item.flightNo, textOf(item.travelDate), item.dep, item.arr, item.depTime, item.arrTime, '飞常准'
  );
}

export function travelCalendarEventFromOption(item: A2uiTravelOptionData): HuaweiTravelCalendarEvent | null {
  return travelCalendarEvent(
    item.source, item.title, textOf(item.travelDate), item.from, item.to, item.depart, item.arrive,
    item.source === 'flight' ? '飞常准' : '12306'
  );
}

function appendUniqueEvent(events: HuaweiTravelCalendarEvent[], event: HuaweiTravelCalendarEvent | null): void {
  if (event === null) {
    return;
  }
  for (let index = 0; index < events.length; index++) {
    if (events[index].requestKey === event.requestKey) {
      return;
    }
  }
  events.push(event);
}

export function travelCalendarEventsFromModel(model: A2uiRuntimeDataModel): HuaweiTravelCalendarEvent[] {
  const events: HuaweiTravelCalendarEvent[] = [];
  const travelOptions = Array.isArray(model.travelOptions) ? model.travelOptions : [];
  const trains = Array.isArray(model.trains) ? model.trains : [];
  const flights = Array.isArray(model.flights) ? model.flights : [];
  travelOptions.forEach((item: A2uiTravelOptionData) => {
    appendUniqueEvent(events, travelCalendarEventFromOption(item));
  });
  trains.forEach((item: A2uiTrainData) => {
    appendUniqueEvent(events, travelCalendarEventFromTrain(item));
  });
  flights.forEach((item: A2uiFlightData) => {
    appendUniqueEvent(events, travelCalendarEventFromFlight(item));
  });
  return events;
}

function conflictForEvent(
  event: HuaweiTravelCalendarEvent | null,
  conflicts: HuaweiTravelCalendarConflict[]
): HuaweiTravelCalendarConflict | null {
  if (event === null) {
    return null;
  }
  for (let index = 0; index < conflicts.length; index++) {
    if (conflicts[index].requestKey === event.requestKey && conflicts[index].conflict) {
      return conflicts[index];
    }
  }
  return null;
}

function applyConflictToTrain(item: A2uiTrainData, conflicts: HuaweiTravelCalendarConflict[]): boolean {
  const conflict = conflictForEvent(travelCalendarEventFromTrain(item), conflicts);
  const nextConflict = conflict !== null;
  const nextTitle = conflict === null ? '' : conflict.eventTitle;
  const changed = item.calendarConflict !== nextConflict || item.calendarConflictTitle !== nextTitle;
  item.calendarConflict = nextConflict;
  item.calendarConflictTitle = nextTitle;
  return changed;
}

function applyConflictToFlight(item: A2uiFlightData, conflicts: HuaweiTravelCalendarConflict[]): boolean {
  const conflict = conflictForEvent(travelCalendarEventFromFlight(item), conflicts);
  const nextConflict = conflict !== null;
  const nextTitle = conflict === null ? '' : conflict.eventTitle;
  const changed = item.calendarConflict !== nextConflict || item.calendarConflictTitle !== nextTitle;
  item.calendarConflict = nextConflict;
  item.calendarConflictTitle = nextTitle;
  return changed;
}

function applyConflictToOption(item: A2uiTravelOptionData, conflicts: HuaweiTravelCalendarConflict[]): boolean {
  const conflict = conflictForEvent(travelCalendarEventFromOption(item), conflicts);
  const nextConflict = conflict !== null;
  const nextTitle = conflict === null ? '' : conflict.eventTitle;
  const changed = item.calendarConflict !== nextConflict || item.calendarConflictTitle !== nextTitle;
  item.calendarConflict = nextConflict;
  item.calendarConflictTitle = nextTitle;
  return changed;
}

export function applyTravelCalendarConflictProjection(
  model: A2uiRuntimeDataModel,
  conflicts: HuaweiTravelCalendarConflict[]
): boolean {
  let changed = false;
  const travelOptions = Array.isArray(model.travelOptions) ? model.travelOptions : [];
  const trains = Array.isArray(model.trains) ? model.trains : [];
  const flights = Array.isArray(model.flights) ? model.flights : [];
  travelOptions.forEach((item: A2uiTravelOptionData) => {
    changed = applyConflictToOption(item, conflicts) || changed;
  });
  trains.forEach((item: A2uiTrainData) => {
    changed = applyConflictToTrain(item, conflicts) || changed;
  });
  flights.forEach((item: A2uiFlightData) => {
    changed = applyConflictToFlight(item, conflicts) || changed;
  });
  return changed;
}

function calendarAction(
  payload: TravelCalendarActionPayload,
  sourceSectionId: string,
  conflict: boolean
): A2uiAction {
  return {
    id: TRAVEL_CALENDAR_ADD_ACTION_ID,
    label: conflict ? '时间冲突' : '加入日历',
    prompt: JSON.stringify(payload),
    kind: 'client',
    variant: conflict ? 'danger' : 'secondary',
    sourceSectionId: sourceSectionId
  };
}

export function travelCalendarActionForTrain(item: A2uiTrainData, sourceSectionId: string): A2uiAction {
  return calendarAction({
    calendarCollection: 'train',
    trainCode: item.trainCode,
    depart: item.depart,
    from: item.from,
    to: item.to
  }, sourceSectionId, item.calendarConflict === true);
}

export function travelCalendarActionForFlight(item: A2uiFlightData, sourceSectionId: string): A2uiAction {
  return calendarAction({
    calendarCollection: 'flight',
    flightNo: item.flightNo,
    depTime: item.depTime,
    dep: item.dep,
    arr: item.arr
  }, sourceSectionId, item.calendarConflict === true);
}

export function travelCalendarActionForOption(item: A2uiTravelOptionData, sourceSectionId: string): A2uiAction {
  return calendarAction({
    calendarCollection: 'travel',
    id: item.id,
    source: item.source,
    depart: item.depart,
    from: item.from,
    to: item.to
  }, sourceSectionId, item.calendarConflict === true);
}
