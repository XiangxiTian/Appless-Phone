export const CAPABILITY_BEHAVIOR_BASELINE_VERSION: string = 'v3.4';

export interface DataResultBehaviorSnapshot {
  name: string;
  toolId: string;
  outputSchema: string;
  status: string;
  sources: string[];
  warnings: string[];
  error: string;
  facts: string[];
}

export interface A2uiBehaviorSnapshot {
  name: string;
  versions: string[];
  surface: string;
  components: string[];
  dataPaths: string[];
  summary: string;
  results: string[];
  actionIds: string[];
  firstRows: string[];
}

const ROLLING_GO_LIMITATION: string =
  'Appless 支持打开 App 内 RollingGo Web 预订；原生订单创建、状态和取消不可用';

export const HOTEL_SEARCH_SUCCESS_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'hotel.search.success.data-result',
  toolId: 'hotel.search',
  outputSchema: 'hotelSearchResults',
  status: 'success',
  sources: ['RollingGo|local_adapter|searchHotels|<fetchedAt>'],
  warnings: [],
  error: '',
  facts: [
    'ok=true',
    'hotels=1',
    'hotelId=47675',
    'destinationId=6046792',
    'price=1100 CNY',
    'stay=2026-08-15→2026-08-17'
  ]
};

export const HOTEL_SEARCH_EMPTY_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'hotel.search.empty.data-result',
  toolId: 'hotel.search',
  outputSchema: 'hotelSearchResults',
  status: 'empty',
  sources: ['RollingGo|local_adapter|searchHotels|<fetchedAt>'],
  warnings: [],
  error: '',
  facts: ['ok=true', 'hotels=0', 'stay=2026-08-15→2026-08-17']
};

export const HOTEL_SEARCH_ERROR_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'hotel.search.error.data-result',
  toolId: 'hotel.search',
  outputSchema: 'hotelSearchResults',
  status: 'error',
  sources: ['RollingGo|local_adapter|searchHotels|<fetchedAt>'],
  warnings: [],
  error: 'HOTEL_PROVIDER_ERROR|true|酒店搜索失败，请稍后重试',
  facts: ['ok=false', 'hotels=0', 'providerError=酒店搜索失败，请稍后重试']
};

export const HOTEL_DETAIL_PARTIAL_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'hotel.detail.partial.data-result',
  toolId: 'hotel.detail',
  outputSchema: 'hotelRatePlans',
  status: 'partial',
  sources: ['RollingGo|local_adapter|getHotelDetail|<fetchedAt>'],
  warnings: ['quote expiry unavailable'],
  error: '',
  facts: [
    'ok=true',
    'hotelId=47675',
    'rates=1',
    'ratePlanId=rate-plan-real-1',
    'averagePrice=550 CNY'
  ]
};

export const CALENDAR_SEARCH_SUCCESS_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'calendar.events.search.success.data-result',
  toolId: 'calendar.events.search',
  outputSchema: 'calendarEvents',
  status: 'success',
  sources: ['Composio Google Calendar|oauth_api|calendar.events.search|<fetchedAt>'],
  warnings: [],
  error: '',
  facts: [
    'results=1',
    'eventId=event-real-1',
    'title=团队同步',
    'start=2026-08-12T10:00:00+08:00',
    'end=2026-08-12T10:30:00+08:00'
  ]
};

export const CALENDAR_SEARCH_EMPTY_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'calendar.events.search.empty.data-result',
  toolId: 'calendar.events.search',
  outputSchema: 'calendarEvents',
  status: 'empty',
  sources: ['Google Calendar API|oauth_api|calendar.events.search|<fetchedAt>'],
  warnings: [],
  error: '',
  facts: [
    'results=1',
    'resultStatus=success',
    'title=没有找到日程',
    'window=2026-08-12T00:00:00+08:00→2026-08-13T00:00:00+08:00'
  ]
};

export const CALENDAR_SEARCH_ERROR_DATA_RESULT: DataResultBehaviorSnapshot = {
  name: 'calendar.events.search.error.data-result',
  toolId: 'calendar.events.search',
  outputSchema: 'calendarEvents',
  status: 'error',
  sources: ['Composio Google Calendar|oauth_api|calendar.events.search|<fetchedAt>'],
  warnings: ['Composio Google Calendar：calendar backend unavailable'],
  error: 'PROVIDER_ERROR|false|calendar backend unavailable',
  facts: ['results=1', 'resultStatus=error', 'title=Google Calendar 调用失败']
};

export const HOTEL_SEARCH_SUCCESS_A2UI: A2uiBehaviorSnapshot = {
  name: 'hotel.search.success.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_hotel_search|酒店搜索|hotel|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'hotel.search|1',
  results: ['hotel.search|success|深圳测试酒店'],
  actionIds: ['dynamic_retry', 'hotel.detail', 'hotel.navigate'],
  firstRows: [
    '酒店 ID=47675',
    'Destination ID=6046792',
    '入住=2026-08-15 → 2026-08-17',
    '客人=2 成人 · 1 间',
    '地址=深圳市南山区',
    '星级=5',
    '参考价=1100 CNY',
    '参考价口径=搜索阶段仅传成人数；完整客人与房间数在实时房型中查询',
    '价格说明=2 晚参考价',
    '设施=Wi-Fi',
    '标签=商务',
    '能力边界=' + ROLLING_GO_LIMITATION,
    '酒店图片=https://img.example/hotel.jpg'
  ]
};

export const HOTEL_DETAIL_PARTIAL_A2UI: A2uiBehaviorSnapshot = {
  name: 'hotel.detail.partial.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_hotel_detail|深圳测试酒店|hotel|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'hotel.detail|1',
  results: ['hotel.detail|success|豪华大床房'],
  actionIds: ['dynamic_retry', 'hotel.search.restore', 'hotel.booking.open'],
  firstRows: [
    '酒店 ID=47675',
    'Rate plan ID=rate-plan-real-1',
    '入住=2026-08-15 → 2026-08-17',
    '客人=2 成人 · 1 间',
    '平均价=550 CNY',
    '床型=1 大床',
    '餐食=不含早餐',
    '供应商确认=当前可订',
    '取消政策=入住前一天可免费取消',
    '税费与有效期=税费拆分与报价有效期：供应商未返回',
    '能力边界=' + ROLLING_GO_LIMITATION,
    '预订说明=房型与价格由 RollingGo 实时提供，最终房型与价格以预订页为准。',
    '部分结果提醒=quote expiry unavailable'
  ]
};

export const CALENDAR_SEARCH_SUCCESS_A2UI: A2uiBehaviorSnapshot = {
  name: 'calendar.events.search.success.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_calendar_search|Google Calendar|dynamic_tool|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'calendar.events.search|1',
  results: ['calendar.events.search|success|团队同步'],
  actionIds: ['dynamic_retry'],
  firstRows: [
    'Event ID=event-real-1',
    'Start=2026-08-12T10:00:00+08:00',
    'End=2026-08-12T10:30:00+08:00',
    'Link=https://calendar.google.com/event?eid=real-1'
  ]
};

export const CALENDAR_CREATE_SUCCESS_A2UI: A2uiBehaviorSnapshot = {
  name: 'calendar.event.create.success.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_calendar_create|Google Calendar|dynamic_tool|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'calendar.event.create|1',
  results: ['calendar.event.create|success|新建评审'],
  actionIds: ['dynamic_retry'],
  firstRows: [
    'Event ID=event-created-1',
    'Start=2026-08-13T15:00:00+08:00',
    'End=2026-08-13T15:30:00+08:00'
  ]
};

export const CALENDAR_UPDATE_SUCCESS_A2UI: A2uiBehaviorSnapshot = {
  name: 'calendar.event.update.success.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_calendar_update|Google Calendar|dynamic_tool|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'calendar.event.update|1',
  results: ['calendar.event.update|success|团队同步（已更新）'],
  actionIds: ['dynamic_retry'],
  firstRows: [
    'Event ID=event-real-1',
    'Start=2026-08-12T11:00:00+08:00',
    'End=2026-08-12T11:30:00+08:00'
  ]
};

export const CALENDAR_DELETE_SUCCESS_A2UI: A2uiBehaviorSnapshot = {
  name: 'calendar.event.delete.success.a2ui',
  versions: ['v0.9.1', 'v0.9.1', 'v0.9.1', 'v0.9.1'],
  surface: 'surface_calendar_delete|Google Calendar|dynamic_tool|ready',
  components: ['SurfaceRoot', 'GenericToolResults'],
  dataPaths: ['/genericToolResults', '/summary'],
  summary: 'calendar.event.delete|1',
  results: ['calendar.event.delete|success|日程已删除'],
  actionIds: ['dynamic_retry'],
  firstRows: ['Event ID=event-real-1']
};
