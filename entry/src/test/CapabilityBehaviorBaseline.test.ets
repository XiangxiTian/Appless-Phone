import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiSummaryData,
  CalendarEventArgs,
  DataResult,
  DataSource,
  DynamicGenericToolResult,
  HotelDetailResult,
  HotelSearchResult,
  McpToolResultPayload,
  calendarEventResultsFromListPayload,
  calendarResultsFromComposioObservation,
  genericToolResultsA2ui,
  hotelDetailA2ui,
  hotelDetailDataResult,
  hotelSearchA2ui,
  hotelSearchDataResult,
  normalizeHotelDetailResult,
  normalizeHotelSearchResult,
  parseHotelDetailRequest,
  parseHotelSearchRequest,
  remainingReadStructuredDataResult
} from '@loop/agent-core';
import {
  A2uiBehaviorSnapshot,
  CALENDAR_CREATE_SUCCESS_A2UI,
  CALENDAR_DELETE_SUCCESS_A2UI,
  CALENDAR_SEARCH_EMPTY_DATA_RESULT,
  CALENDAR_SEARCH_ERROR_DATA_RESULT,
  CALENDAR_SEARCH_SUCCESS_A2UI,
  CALENDAR_SEARCH_SUCCESS_DATA_RESULT,
  CALENDAR_UPDATE_SUCCESS_A2UI,
  CAPABILITY_BEHAVIOR_BASELINE_VERSION,
  DataResultBehaviorSnapshot,
  HOTEL_DETAIL_PARTIAL_A2UI,
  HOTEL_DETAIL_PARTIAL_DATA_RESULT,
  HOTEL_SEARCH_EMPTY_DATA_RESULT,
  HOTEL_SEARCH_ERROR_DATA_RESULT,
  HOTEL_SEARCH_SUCCESS_A2UI,
  HOTEL_SEARCH_SUCCESS_DATA_RESULT
} from './fixtures/CapabilityBehaviorSnapshots';

interface HotelSearchArgsFixture {
  originQuery: string;
  place: string;
  placeType: string;
  countryCode: string;
  checkInDate: string;
  stayNights: number;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
  currency: string;
  size: number;
}

interface HotelDetailArgsFixture {
  hotelId: number;
  checkInDate: string;
  checkOutDate: string;
  countryCode: string;
  currency: string;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

function objectFromJson(json: string): Object {
  return JSON.parse(json) as Object;
}

function searchArgs(): HotelSearchArgsFixture {
  return {
    originQuery: '深圳酒店',
    place: '深圳',
    placeType: 'CITY',
    countryCode: 'CN',
    checkInDate: '2026-08-15',
    stayNights: 2,
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1,
    currency: 'CNY',
    size: 10
  };
}

function detailArgs(): HotelDetailArgsFixture {
  return {
    hotelId: 47675,
    checkInDate: '2026-08-15',
    checkOutDate: '2026-08-17',
    countryCode: 'CN',
    currency: 'CNY',
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1
  };
}

function hotelSearchResult(payloadJson: string): HotelSearchResult {
  const parsed = parseHotelSearchRequest(searchArgs());
  if (parsed.value === null) {
    throw new Error(parsed.error);
  }
  const payload: McpToolResultPayload = {
    isError: false,
    structuredContent: objectFromJson(payloadJson)
  };
  return normalizeHotelSearchResult(payload, parsed.value);
}

function hotelDetailResult(payloadJson: string): HotelDetailResult {
  const parsed = parseHotelDetailRequest(detailArgs());
  if (parsed.value === null) {
    throw new Error(parsed.error);
  }
  const payload: McpToolResultPayload = {
    isError: false,
    structuredContent: objectFromJson(payloadJson)
  };
  return normalizeHotelDetailResult(payload, parsed.value);
}

function hotelSearchSuccess(): HotelSearchResult {
  return hotelSearchResult(
    '{"success":true,"message":"酒店搜索成功","hotelInformationList":[{"hotelId":47675,' +
    '"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0",' +
    '"name":"深圳测试酒店","nameEn":"Shenzhen Test Hotel","brand":"Test","address":"深圳市南山区",' +
    '"destinationId":"6046792","latitude":22.5,"longitude":114,"distanceInMeters":880,"starRating":5,' +
    '"price":{"message":"2 晚参考价","hasPrice":true,"currency":"CNY","lowestPrice":1100},' +
    '"areaCode":"NANSHAN","description":"provider description","imageUrl":"https://img.example/hotel.jpg",' +
    '"hotelAmenities":["Wi-Fi"],"tags":["商务"]}]}'
  );
}

function hotelDetailSuccess(): HotelDetailResult {
  return hotelDetailResult(
    '{"success":true,"hotelId":47675,' +
    '"bookingUrl":"https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0",' +
    '"name":"深圳测试酒店","nameEn":"Shenzhen Test Hotel","checkIn":"2026-08-15",' +
    '"checkOut":"2026-08-17","message":"搜索成功","roomRatePlans":[{"roomName":"豪华大床房",' +
    '"roomNameCn":"豪华大床房","ratePlanId":"rate-plan-real-1","ratePlanName":"不含早餐",' +
    '"averagePrice":550,"bedTypeDescription":"1 大床","currency":"CNY","mealAmount":0,' +
    '"mealTypeStr":"不含早餐","isOnRequest":false,"cancelPolicy":"入住前一天可免费取消"}]}'
  );
}

function hotelSource(operation: string): DataSource {
  return {
    provider: 'RollingGo',
    backend: 'local_adapter',
    operation: operation,
    fetchedAt: '2026-08-10T00:00:00.000Z'
  };
}

function allowAll(_action: A2uiAction): boolean {
  return true;
}

function executionResults(results: DynamicGenericToolResult[]): DynamicGenericToolResult[] {
  results.forEach((result: DynamicGenericToolResult) => result.providerPhase = 'execution');
  return results;
}

interface BaselineCreateSurface {
  surfaceId: string;
  title: string;
  intent: string;
  status: string;
}

interface BaselineUpdateComponents {
  components: A2uiComponent[];
}

interface BaselineUpdateDataModel {
  path: string;
  value: Object;
}

interface BaselineEnvelope {
  version: string;
  createSurface?: BaselineCreateSurface;
  updateComponents?: BaselineUpdateComponents;
  updateDataModel?: BaselineUpdateDataModel;
}

function sourceSnapshot(source: DataSource): string {
  return source.provider + '|' + source.backend + '|' + source.operation + '|<fetchedAt>';
}

function errorSnapshot(result: DataResult): string {
  if (result.error === undefined) {
    return '';
  }
  return result.error.code + '|' + (result.error.retryable === true ? 'true' : 'false') + '|' +
    result.error.message;
}

function dataResultSnapshot(name: string, result: DataResult, facts: string[]): DataResultBehaviorSnapshot {
  return {
    name: name,
    toolId: result.toolId,
    outputSchema: result.outputSchema,
    status: result.status,
    sources: result.sources.map((source: DataSource): string => sourceSnapshot(source)),
    warnings: result.warnings.slice(),
    error: errorSnapshot(result),
    facts: facts.slice()
  };
}

function addActionIds(ids: string[], actions: A2uiAction[] | undefined): void {
  if (actions === undefined) {
    return;
  }
  actions.forEach((action: A2uiAction) => {
    if (ids.indexOf(action.id) < 0) {
      ids.push(action.id);
    }
  });
}

function a2uiSnapshot(name: string, jsonl: string): A2uiBehaviorSnapshot {
  const snapshot: A2uiBehaviorSnapshot = {
    name: name,
    versions: [],
    surface: '',
    components: [],
    dataPaths: [],
    summary: '',
    results: [],
    actionIds: [],
    firstRows: []
  };
  const lines = jsonl.split('\n').filter((line: string): boolean => line.trim().length > 0);
  lines.forEach((line: string) => {
    const envelope = JSON.parse(line) as BaselineEnvelope;
    snapshot.versions.push(envelope.version);
    if (envelope.createSurface !== undefined) {
      const surface = envelope.createSurface;
      snapshot.surface = surface.surfaceId + '|' + surface.title + '|' + surface.intent + '|' + surface.status;
    }
    if (envelope.updateComponents !== undefined) {
      envelope.updateComponents.components.forEach((component: A2uiComponent) => {
        snapshot.components.push(component.component);
        addActionIds(snapshot.actionIds, component.actions);
      });
    }
    if (envelope.updateDataModel !== undefined) {
      const update = envelope.updateDataModel;
      snapshot.dataPaths.push(update.path);
      if (update.path === '/genericToolResults') {
        const results = update.value as A2uiGenericToolResultData[];
        results.forEach((result: A2uiGenericToolResultData) => {
          snapshot.results.push(result.toolName + '|' + result.status + '|' + result.title);
          addActionIds(snapshot.actionIds, result.actions);
        });
        if (results.length > 0) {
          results[0].rows.forEach((row: A2uiLabelValueData) =>
            snapshot.firstRows.push(row.label + '=' + row.value));
        }
      } else if (update.path === '/summary') {
        const summary = update.value as A2uiSummaryData;
        snapshot.summary = summary.toolName + '|' + summary.count.toString();
      }
    }
  });
  return snapshot;
}

function calendarSearchSuccessResults(): DynamicGenericToolResult[] {
  return executionResults(calendarResultsFromComposioObservation(
    'calendar.events.search',
    '{"data":{"items":[{"id":"event-real-1","summary":"团队同步",' +
    '"start":{"dateTime":"2026-08-12T10:00:00+08:00"},' +
    '"end":{"dateTime":"2026-08-12T10:30:00+08:00"},' +
    '"htmlLink":"https://calendar.google.com/event?eid=real-1"}]},"error":null}'
  ));
}

function calendarWindow(): CalendarEventArgs {
  return {
    timeMin: '2026-08-12T00:00:00+08:00',
    timeMax: '2026-08-13T00:00:00+08:00'
  };
}

export default function capabilityBehaviorBaselineTest() {
  describe('capabilityBehaviorBaseline', () => {
    it('matches versioned Hotel and Calendar DataResult and A2UI fixtures', 0, () => {
      const hotelSearch = hotelSearchSuccess();
      const hotelDetail = hotelDetailSuccess();
      const hotelEmpty = hotelSearchResult(
        '{"success":true,"message":"酒店搜索成功","hotelInformationList":[]}'
      );
      const hotelError = hotelSearchResult(
        '{"success":false,"message":"酒店搜索失败，请稍后重试","hotelInformationList":[]}'
      );
      const calendarSuccess = calendarSearchSuccessResults();
      const calendarEmpty = executionResults(calendarEventResultsFromListPayload('{"items":[]}', calendarWindow()));
      const calendarError = executionResults(calendarResultsFromComposioObservation(
        'calendar.events.search', '{"data":null,"error":"calendar backend unavailable"}'
      ));
      const create = calendarResultsFromComposioObservation(
        'calendar.event.create',
        '{"data":{"id":"event-created-1","summary":"新建评审",' +
        '"start":{"dateTime":"2026-08-13T15:00:00+08:00"},' +
        '"end":{"dateTime":"2026-08-13T15:30:00+08:00"}},"error":null}'
      );
      const update = calendarResultsFromComposioObservation(
        'calendar.event.update',
        '{"data":{"id":"event-real-1","summary":"团队同步（已更新）",' +
        '"start":{"dateTime":"2026-08-12T11:00:00+08:00"},' +
        '"end":{"dateTime":"2026-08-12T11:30:00+08:00"}},"error":null}'
      );
      const remove = calendarResultsFromComposioObservation(
        'calendar.event.delete',
        '{"data":{"success":true,"status":"deleted"},"error":null}',
        { eventId: 'event-real-1' }
      );

      const dataSnapshots: DataResultBehaviorSnapshot[] = [
        dataResultSnapshot('hotel.search.success.data-result',
          hotelSearchDataResult(hotelSearch, [hotelSource('searchHotels')]), [
            'ok=' + hotelSearch.ok.toString(),
            'hotels=' + hotelSearch.hotels.length.toString(),
            'hotelId=' + hotelSearch.hotels[0].hotelId.toString(),
            'destinationId=' + hotelSearch.hotels[0].destinationId,
            'price=' + hotelSearch.hotels[0].price.lowestPrice.toString() + ' ' + hotelSearch.hotels[0].price.currency,
            'stay=' + hotelSearch.query.checkInDate + '→' + hotelSearch.query.checkOutDate
          ]),
        dataResultSnapshot('hotel.search.empty.data-result',
          hotelSearchDataResult(hotelEmpty, [hotelSource('searchHotels')]), [
            'ok=' + hotelEmpty.ok.toString(),
            'hotels=' + hotelEmpty.hotels.length.toString(),
            'stay=' + hotelEmpty.query.checkInDate + '→' + hotelEmpty.query.checkOutDate
          ]),
        dataResultSnapshot('hotel.search.error.data-result',
          hotelSearchDataResult(hotelError, [hotelSource('searchHotels')]), [
            'ok=' + hotelError.ok.toString(),
            'hotels=' + hotelError.hotels.length.toString(),
            'providerError=' + hotelError.error
          ]),
        dataResultSnapshot('hotel.detail.partial.data-result',
          hotelDetailDataResult(hotelDetail, [hotelSource('getHotelDetail')], ['quote expiry unavailable']), [
            'ok=' + hotelDetail.ok.toString(),
            'hotelId=' + hotelDetail.hotelId.toString(),
            'rates=' + hotelDetail.rates.length.toString(),
            'ratePlanId=' + hotelDetail.rates[0].ratePlanId,
            'averagePrice=' + hotelDetail.rates[0].averagePrice!.toString() + ' ' + hotelDetail.rates[0].currency
          ]),
        dataResultSnapshot('calendar.events.search.success.data-result',
          remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', calendarSuccess), [
            'results=' + calendarSuccess.length.toString(),
            'eventId=' + calendarSuccess[0].rows[0].value,
            'title=' + calendarSuccess[0].title,
            'start=' + calendarSuccess[0].rows[1].value,
            'end=' + calendarSuccess[0].rows[2].value
          ]),
        dataResultSnapshot('calendar.events.search.empty.data-result',
          remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', calendarEmpty), [
            'results=' + calendarEmpty.length.toString(),
            'resultStatus=' + calendarEmpty[0].status,
            'title=' + calendarEmpty[0].title,
            'window=' + calendarEmpty[0].rows[0].value + '→' + calendarEmpty[0].rows[1].value
          ]),
        dataResultSnapshot('calendar.events.search.error.data-result',
          remainingReadStructuredDataResult('calendar.events.search', 'calendarEvents', calendarError), [
            'results=' + calendarError.length.toString(),
            'resultStatus=' + calendarError[0].status,
            'title=' + calendarError[0].title
          ])
      ];
      const expectedDataSnapshots: DataResultBehaviorSnapshot[] = [
        HOTEL_SEARCH_SUCCESS_DATA_RESULT,
        HOTEL_SEARCH_EMPTY_DATA_RESULT,
        HOTEL_SEARCH_ERROR_DATA_RESULT,
        HOTEL_DETAIL_PARTIAL_DATA_RESULT,
        CALENDAR_SEARCH_SUCCESS_DATA_RESULT,
        CALENDAR_SEARCH_EMPTY_DATA_RESULT,
        CALENDAR_SEARCH_ERROR_DATA_RESULT
      ];
      const a2uiSnapshots: A2uiBehaviorSnapshot[] = [
        a2uiSnapshot('hotel.search.success.a2ui',
          hotelSearchA2ui('surface_hotel_search', hotelSearch, allowAll)),
        a2uiSnapshot('hotel.detail.partial.a2ui',
          hotelDetailA2ui('surface_hotel_detail', hotelDetail, allowAll, ['quote expiry unavailable'])),
        a2uiSnapshot('calendar.events.search.success.a2ui',
          genericToolResultsA2ui('surface_calendar_search', 'calendar.events.search', calendarSuccess)),
        a2uiSnapshot('calendar.event.create.success.a2ui',
          genericToolResultsA2ui('surface_calendar_create', 'calendar.event.create', create)),
        a2uiSnapshot('calendar.event.update.success.a2ui',
          genericToolResultsA2ui('surface_calendar_update', 'calendar.event.update', update)),
        a2uiSnapshot('calendar.event.delete.success.a2ui',
          genericToolResultsA2ui('surface_calendar_delete', 'calendar.event.delete', remove))
      ];
      const expectedA2uiSnapshots: A2uiBehaviorSnapshot[] = [
        HOTEL_SEARCH_SUCCESS_A2UI,
        HOTEL_DETAIL_PARTIAL_A2UI,
        CALENDAR_SEARCH_SUCCESS_A2UI,
        CALENDAR_CREATE_SUCCESS_A2UI,
        CALENDAR_UPDATE_SUCCESS_A2UI,
        CALENDAR_DELETE_SUCCESS_A2UI
      ];

      expect(CAPABILITY_BEHAVIOR_BASELINE_VERSION).assertEqual('v3.4');
      expect(JSON.stringify(dataSnapshots)).assertEqual(JSON.stringify(expectedDataSnapshots));
      expect(JSON.stringify(a2uiSnapshots)).assertEqual(JSON.stringify(expectedA2uiSnapshots));
    });
  });
}
