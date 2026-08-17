import { describe, expect, it } from '@ohos/hypium';
import { A2uiFlightData, A2uiRuntimeDataModel, HuaweiTravelCalendarConflict } from '@loop/agent-core';
import {
  applyTravelCalendarConflictProjection,
  travelCalendarActionForFlight,
  travelCalendarEventFromFlight,
  travelCalendarEventFromOption,
  travelCalendarEventFromTrain,
  travelCalendarEventsFromModel
} from '../main/ets/pages/A2uiHome/travel/TravelCalendarAction';

export default function travelCalendarActionTest() {
  describe('travelCalendarAction', () => {
    it('builds a flight calendar event with two reminders', 0, () => {
      const event = travelCalendarEventFromFlight({
        flightNo: 'CZ3568', airline: '南方航空', dep: '深圳宝安', arr: '上海虹桥',
        depCode: 'SZX', arrCode: 'SHA', travelDate: '2026-08-28', depTime: '05:55',
        arrTime: '07:55', status: '计划', price: '680'
      });

      expect(event === null).assertFalse();
      expect(event?.title).assertEqual('航班 CZ3568 · 深圳宝安 → 上海虹桥');
      expect(new Date(event?.startTime as number).getHours()).assertEqual(5);
      expect(new Date(event?.endTime as number).getHours()).assertEqual(7);
      expect(event?.reminderTime[0]).assertEqual(120);
      expect(event?.reminderTime[1]).assertEqual(30);
    });

    it('moves an overnight arrival to the next day', 0, () => {
      const event = travelCalendarEventFromOption({
        id: 'flight-ZH1', source: 'flight', sourceTag: '飞机 · 飞常准', title: 'ZH1',
        from: '深圳宝安', to: '乌鲁木齐地窝堡', depart: '23:30', arrive: '04:20',
        duration: '4小时50分', price: '', availability: '', status: '计划', detail: '',
        travelDate: '2026-09-02'
      });

      expect(event === null).assertFalse();
      expect((event?.endTime as number) > (event?.startTime as number)).assertTrue();
      expect(new Date(event?.endTime as number).getDate()).assertEqual(3);
    });

    it('rejects a train row without a travel date', 0, () => {
      const event = travelCalendarEventFromTrain({
        trainCode: 'G100', from: '深圳北', to: '上海虹桥', depart: '08:00', arrive: '14:30',
        duration: '6小时30分', seats: '有票', status: 'available', business: '', first: '',
        second: '有', noSeat: '', hardSeat: '', sleeperSoft: ''
      });

      expect(event === null).assertTrue();
    });

    it('ignores non-travel surface models without travel collections', 0, () => {
      const model = JSON.parse(
        '{"dailyBriefDate":"2026-08-17","dailyBriefMessage":"日报生成中"}'
      ) as A2uiRuntimeDataModel;

      expect(travelCalendarEventsFromModel(model).length).assertEqual(0);
      expect(applyTravelCalendarConflictProjection(model, [])).assertFalse();
    });

    it('creates a row-bound calendar action', 0, () => {
      const action = travelCalendarActionForFlight({
        flightNo: 'CZ3568', airline: '南方航空', dep: '深圳宝安', arr: '上海虹桥',
        travelDate: '2026-08-28', depTime: '05:55', arrTime: '07:55', status: '计划', price: ''
      }, 'flight-results');

      expect(action.id).assertEqual('travel.calendar.add');
      expect(action.label).assertEqual('加入日历');
      expect(action.kind).assertEqual('client');
      expect(action.prompt.indexOf('"calendarCollection":"flight"')).assertLarger(-1);
      expect(action.prompt.indexOf('"flightNo":"CZ3568"')).assertLarger(-1);
      expect(action.sourceSectionId).assertEqual('flight-results');
    });

    it('projects a system calendar conflict onto the matching row', 0, () => {
      const flight: A2uiFlightData = {
        flightNo: 'CZ3568', airline: '南方航空', dep: '深圳宝安', arr: '上海虹桥',
        travelDate: '2026-08-28', depTime: '05:55', arrTime: '07:55', status: '计划', price: ''
      };
      const event = travelCalendarEventFromFlight(flight);
      const model = JSON.parse('{"travelOptions":[],"trains":[],"flights":[]}') as A2uiRuntimeDataModel;
      model.flights.push(flight);
      const conflicts: HuaweiTravelCalendarConflict[] = [{
        requestKey: event?.requestKey as string,
        conflict: true,
        eventId: '42',
        eventTitle: '客户晨会',
        eventStartTime: event?.startTime as number,
        eventEndTime: event?.endTime as number
      }];

      expect(applyTravelCalendarConflictProjection(model, conflicts)).assertTrue();
      expect(model.flights[0].calendarConflict).assertTrue();
      expect(model.flights[0].calendarConflictTitle).assertEqual('客户晨会');
      const action = travelCalendarActionForFlight(model.flights[0], 'flight-results');
      expect(action.label).assertEqual('时间冲突');
      expect(action.variant).assertEqual('danger');
    });
  });
}
