import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  A2uiAction,
  A2uiRuntimeDataModel,
  A2uiSurfaceStore,
  A2uiSurfaceState,
  ActionResultPayload,
  ActionExecutionContext,
  ActionExecutionResult,
  AgentMessage,
  AgentMessageType,
  ConversationContext,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataStepDecision,
  DataTaskExecutor,
  DataTaskPlanner,
  DynamicGenericToolResult,
  HotelDetailRequest,
  HotelDetailResult,
  HotelRatePlan,
  HotelSearchItem,
  HotelSearchRequest,
  HotelSearchResult,
  JsonValue,
  LocalModel,
  LinkedMessageBus,
  MemoryBatchResult,
  MemoryCommitGuard,
  LeaderMemoryToolResult,
  MemoryRecallObservation,
  MemoryWriteResult,
  ObservationDigest,
  TaskErrorPayload,
  TurnResultPayload,
  UiRenderProgressSink,
  UiRenderResult,
  UiTaskRenderer,
  UiRenderResultPayload,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  composioDynamicResultFromObservation,
  createSeedA2uiSurface,
  gmailDraftPreviewA2ui,
  gmailThreadResultsA2ui,
  genericToolResultsA2ui,
  hotelSearchDataResult,
  parseA2uiJsonl,
  parseHotelSearchRequest,
  setJsonPointer
} from '@loop/agent-core';
import {
  PhoneLocalMemoryUpdate,
  PhoneLocalMemoryRuntimePort,
  PhoneLocalRecalledMemory
} from '../main/ets/memory/PhoneLocalMemoryRuntime';
import {
  PhoneLocalMemoryProjectionFact,
  PhoneLocalMemoryProjectionStats
} from '../main/ets/memory/PhoneLocalMemoryStore';
import { PhoneLocalMemoryAvailabilityPort } from '../main/ets/memory/PhoneLocalMemoryAvailability';
import {
  MemoryForgetOverlayRequest,
  MemoryForgetOverlayGateState,
  memoryForgetOverlayBlocked,
  MultiAgentCanaryActionContext,
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime,
  rememberedPersonaAfterOutcome
} from '../main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime';
import { SESSION_COMPACTION_TOKEN_THRESHOLD } from
  '../main/ets/pages/A2uiHome/agent/SessionContextCompaction';
import {
  RegisteredPageActionContext,
  SystemUriOpener
} from '../main/ets/pages/A2uiHome/agent/AiphoneRegisteredActionExecutor';
import {
  MultiAgentSettledOutcome
} from '../main/ets/pages/A2uiHome/agent/MultiAgentRuntimeTypes';
import {
  MEMORY_FORGET_OVERLAY_BASE_BOTTOM_PADDING,
  MEMORY_FORGET_OVERLAY_SCROLL_MAX_HEIGHT,
  memoryForgetOverlayBottomPadding,
  memoryForgetOverlayPersonaName
} from '../main/ets/pages/A2uiHome/components/MemoryForgetOverlay';
import { createHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeSnapshot';
import { HtmlHomeAction, HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';
import {
  MemoryCandidateSelectionData,
  MemoryCandidatesForgetActionArgs
} from '../main/ets/model/MemoryCandidateSelectionSurface';
import {
  RegisteredPageSnapshot,
  registeredPageSourceToolId,
  resolveVirtualRegisteredPageAction
} from '../main/ets/pages/A2uiHome/agent/RegisteredPageActionRoute';
import {
  HotelRuntimeSurfaceWriter,
  HotelSurfaceAuthority,
  HotelVisibility,
  MonotonicHotelIds
} from '../main/ets/pages/A2uiHome/agent/MultiAgentHotelSupport';

const SEARCH_TEXT: string = '帮我找深圳酒店';
function bimSnapshotPrompt(query: string): string {
  return '[BIM_SNAPSHOTS]\n## 展会计划\n- bimId: bim-expo\n- version: 1\n' +
    '- lifecycle: active\n\n展会行程待跟进。\n[/BIM_SNAPSHOTS]\n\n' + query;
}
function bimTravelSnapshotPrompt(query: string): string {
  return '[BIM_SNAPSHOTS]\n## 展会计划\n- bimId: bim-expo\n- version: 1\n' +
    '- lifecycle: active\n\n计划于2026年8月30日从深圳出发去杭州出差。\n' +
    '[/BIM_SNAPSHOTS]\n\n' + query;
}
const SEARCH_INPUT: string = '{"originQuery":"帮我找深圳酒店","place":"深圳",' +
  '"placeType":"CITY","countryCode":"CN","checkInDate":"2026-08-15",' +
  '"stayNights":2,"adultCount":2,"childCount":0,"childAgeDetails":[],' +
  '"roomCount":1,"currency":"CNY","size":10}';
const ANSWER_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"answer":"你好",' +
  '"reasonCode":"greeting"}';
const MANUAL_RECALL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"memory.recall","preferredDensity":"comfortable","requiredSections":[]},' +
  '"leaderToolCall":{"toolId":"memory.recall","query":"咖啡 饮食偏好"}}';
const MANUAL_RECALL_TEN_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"memory.recall","preferredDensity":"comfortable","requiredSections":[]},' +
  '"leaderToolCall":{"toolId":"memory.recall","query":"咖啡 饮食偏好","topK":10}}';
const MEMORY_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["memory.remember"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"memory.remember",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"memoryMutation":{"operation":"remember","facts":[{"fact":"用户喝咖啡时只选择瑞幸。"}]},' +
  '"reasonCode":"stable_preference"}';
const MEMORY_ANSWER_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["memory.remember"],"roundAction":"answer",' +
  '"continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"memoryMutation":{"operation":"remember","facts":[{"fact":"用户喝咖啡时只选择瑞幸。"}]},' +
  '"answer":"当然可以，瑞幸新品和价格我也可以继续帮你查。","reasonCode":"answer_with_memory"}';
const MEMORY_BATCH_UPDATE_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["memory.update"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"memory.update",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"memoryMutation":{"operation":"update","updates":[' +
  '{"memoryId":"memory-coffee","fact":"用户喝咖啡时选择半糖。"},' +
  '{"memoryId":"memory-commute","fact":"用户通勤时偏好地铁。"}]},' +
  '"reasonCode":"stable_preferences_updated"}';
const MEMORY_FORGET_SELECTION_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["memory.forget"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"choose memory to forget",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"memoryClarification":{"operation":"forget"}}';
const HOTEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"hotel-search",' +
  '"goal":"search real hotels","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":' + SEARCH_INPUT + ',"required":true}],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["hotels"]},"reasonCode":"hotel_search"}';
const HOTEL_WITH_MEMORY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search","memory.remember"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[{"localId":"hotel-search",' +
  '"goal":"search real hotels","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":' + SEARCH_INPUT + ',"required":true}],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["hotels"]},' +
  '"memoryMutation":{"operation":"remember","facts":[{"fact":"用户出行时偏好少换乘。"}]},' +
  '"reasonCode":"hotel_search_with_memory"}';
const HOTEL_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"hotel.search",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"酒店结果已就绪","reasonCode":"hotel_ready"}';
const HOTEL_DATA_CALL_DECISION: string = '{"kind":"call","toolId":"hotel.search",' +
  '"args":' + SEARCH_INPUT + ',"summary":"query the registered hotel provider"}';
const HOTEL_ACTION_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search","hotel.navigate"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"hotel-search",' +
  '"goal":"search real hotels","allowedToolIds":["hotel.search"],' +
  '"toolId":"hotel.search","input":' + SEARCH_INPUT + ',"required":true}],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["hotels"]},"actionIntent":{' +
  '"goal":"navigate to the selected hotel",' +
  '"allowedActionIds":["hotel.navigate"]},"reasonCode":"hotel_search_with_navigation"}';
const CALENDAR_UPDATE_ACTION_DRAFT: string = '{"planId":"plan-model-1","runId":"run-model-1",' +
  '"label":"更新日程","steps":[{"stepId":"step-1","actionId":"calendar.event.update",' +
  '"args":{}}]}';
const TWO_TOOL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search","train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"search travel options",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"query":"北京到上海"},"required":true},{"localId":"train",' +
  '"goal":"search trains","allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"query":"北京到上海"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.compare","preferredDensity":"comfortable",' +
  '"requiredSections":["travel","train"]},"reasonCode":"two_tool_compare"}';
const TWO_TOOL_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search","train.search"],"roundAction":"answer","continuationMode":"complete",' +
  '"dataTasks":[],"uiIntent":{"purpose":"travel.compare",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"出行结果已就绪","reasonCode":"two_tool_ready"}';
const INCOMPLETE_TRAVEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"查询下周去上海的综合出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"query":"下周去上海出差"},"required":true}],' +
  '"uiIntent":{"purpose":"出行方案","preferredDensity":"medium",' +
  '"requiredSections":["出行方案"]}}';
const CONTEXTUAL_TRAVEL_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"查询深圳到上海的出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"query":"从深圳到上海，出发日期 2026-08-21，查询高铁和航班"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]}}';
const CONTEXTUAL_TRAVEL_FIELDS_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"查询深圳到上海的出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"origin":"深圳","destination":"上海","departureDate":"2026-08-21"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]}}';
const TIME_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["time"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"current-time","goal":"查询当前设备时间",' +
  '"allowedToolIds":["time"],"toolId":"time","input":{},"required":true}],' +
  '"uiIntent":{"purpose":"time","preferredDensity":"comfortable",' +
  '"requiredSections":["time"]}}';
const TIME_DONE_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["time"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"time","preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"当前设备时间已返回。"}';
const FLIGHT_TRAIN_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search","train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"search flights",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"query":"北京到上海"},"required":true},{"localId":"train",' +
  '"goal":"search trains","allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"query":"北京到上海"},"required":true}],' +
  '"uiIntent":{"purpose":"flight and train","preferredDensity":"comfortable",' +
  '"requiredSections":["flight","train"]},"reasonCode":"flight_train_compare"}';
const FLIGHT_TRAIN_DONE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search","train.search"],"roundAction":"answer","continuationMode":"complete",' +
  '"dataTasks":[],"uiIntent":{"purpose":"flight and train",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"航班和高铁结果已就绪","reasonCode":"flight_train_ready"}';
const C02_QUERY: string = '我明天要从北京去上海，帮我搜索出行方案';
const F01_QUERY: string = '帮我查明天北京到上海的航班';
const F02_QUERY: string = '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁';
const C02_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"搜索从北京到上海的出行方案",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"origin":"北京","destination":"上海","departureDate":"2026-07-23",' +
  '"query":"我明天要从北京去上海，帮我搜索出行方案"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]}}';
const C02_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"综合出行结果已就绪"}';
const F01_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索北京到上海的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"北京","destination":"上海","departureDate":"2026-07-23",' +
  '"query":"' + F01_QUERY + '"},"required":true}],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const F01_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"航班结果已就绪"}';
const BIM_FLIGHT_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索展会出行航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"query":"查询2026年8月30日从深圳到杭州的机票"},"required":true}],'+
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const BIM_FLIGHT_FIELDS_ONLY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索2026年8月30日深圳到杭州的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"深圳","destination":"杭州","departureDate":"2026-08-30"},"required":true}],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const BIM_FLIGHT_MONTH_ONLY_FIELDS_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索2026年8月北京到上海的航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"origin":"北京","destination":"上海","departureDate":"2026-08"},"required":true}],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const BIM_TRAIN_FIELDS_ONLY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"train","goal":"搜索2026年8月30日深圳到杭州的高铁",' +
  '"allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"origin":"深圳","destination":"杭州","departureDate":"2026-08-30"},"required":true}],' +
  '"uiIntent":{"purpose":"train.search","preferredDensity":"comfortable",' +
  '"requiredSections":["train"]}}';
const BIM_FLIGHT_INCOMPLETE_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["flight.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"flight","goal":"搜索展会出行航班",' +
  '"allowedToolIds":["flight.search"],"toolId":"flight.search",' +
  '"input":{"query":"帮我查去展会的机票"},"required":true}],' +
  '"uiIntent":{"purpose":"flight.search","preferredDensity":"comfortable",' +
  '"requiredSections":["flight"]}}';
const F02_QUERY_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"train","goal":"搜索深圳北到香港西九龙的高铁",' +
  '"allowedToolIds":["train.search"],"toolId":"train.search",' +
  '"input":{"origin":"深圳北","destination":"香港西九龙","departureDate":"2026-07-23",' +
  '"query":"' + F02_QUERY + '"},"required":true}],' +
  '"uiIntent":{"purpose":"train.search","preferredDensity":"comfortable",' +
  '"requiredSections":["train"]}}';
const F02_QUERY_DONE: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["train.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"train.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"高铁结果已就绪"}';
const WORLDCUP_ACTION_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["worldcup.open"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"worldcup.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open the World Cup page",' +
  '"allowedActionIds":["worldcup.open"]},"reasonCode":"worldcup_action"}';
const WORLDCUP_ACTION_WITH_MEMORY_DECISION: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["worldcup.open","memory.remember"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"worldcup.open",' +
  '"preferredDensity":"comfortable","requiredSections":[]},"actionIntent":{' +
  '"goal":"open the World Cup page","allowedActionIds":["worldcup.open"]},' +
  '"memoryMutation":{"operation":"remember","facts":[{"fact":"用户关注世界杯比赛。"}]},' +
  '"reasonCode":"worldcup_action_with_memory"}';
const MIXED_DATA_ACTION_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["travel.search","worldcup.open"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"travel","goal":"search travel options",' +
  '"allowedToolIds":["travel.search"],"toolId":"travel.search",' +
  '"input":{"query":"北京到上海"},"required":true}],' +
  '"uiIntent":{"purpose":"travel.search","preferredDensity":"comfortable",' +
  '"requiredSections":["travel"]},"actionIntent":{"goal":"open the World Cup page",' +
  '"allowedActionIds":["worldcup.open"]},"reasonCode":"mixed_data_action"}';
const MAPS_ACTION_DECISION: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["maps.route.open"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"maps.route.open","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"actionIntent":{"goal":"open the requested map route",' +
  '"allowedActionIds":["maps.route.open"]},"reasonCode":"maps_action"}';
const CALENDAR_CREATE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.create"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.create","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{"goal":"review an exact Calendar event",' +
  '"allowedActionIds":["calendar.event.create"]},"reasonCode":"calendar_create_review"}';
const GMAIL_DRAFT_CREATE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.draft.create"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"gmail.draft.create","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{"goal":"create the exact Gmail draft",' +
  '"allowedActionIds":["gmail.draft.create"]},"reasonCode":"gmail_draft_create"}';
const GMAIL_DRAFT_APPLY_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.draft.apply"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"gmail.draft.apply","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{"goal":"apply the current exact Gmail draft",' +
  '"allowedActionIds":["gmail.draft.apply"]},"reasonCode":"gmail_draft_apply"}';
const CALENDAR_UPDATE_SEARCH_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"execute",' +
  '"continuationMode":"dependency",' +
  '"dataTasks":[{"localId":"calendar-search","goal":"find the exact current event",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"产品评审","eventId":"model-forged",' +
  '"requestedAction":{"eventId":"model-forged","title":"forged"}},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]},"reasonCode":"calendar_update_read_first"}';
const CALENDAR_UPDATE_ACTION_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search","calendar.event.update"],"roundAction":"execute",' +
  '"continuationMode":"dependency",' +
  '"dataTasks":[{"localId":"calendar-search","goal":"find the exact current event",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"产品评审","eventId":"model-forged",' +
  '"requestedAction":{"eventId":"model-forged","title":"forged"}},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]},"actionIntent":{' +
  '"goal":"update the one real Calendar event",' +
  '"allowedActionIds":["calendar.event.update"]},"reasonCode":"calendar_update_action"}';
const CALENDAR_UPDATE_PREMATURE_ACTION_MISMATCH_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"execute",' +
  '"continuationMode":"dependency",' +
  '"dataTasks":[{"localId":"calendar-search","goal":"find the exact current event",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"产品评审","timeMin":"2026-07-31T00:00:00+08:00",' +
  '"timeMax":"2026-07-31T23:59:59+08:00","timezone":"Asia/Shanghai"},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]},"actionIntent":{' +
  '"goal":"update the found event to 16:00","allowedActionIds":["calendar.event.update"]}}';
const CALENDAR_UPDATE_REPAIRED_SEARCH_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"execute",' +
  '"continuationMode":"dependency",' +
  '"dataTasks":[{"localId":"calendar-search","goal":"find the exact current event",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"产品评审","timeMin":"2026-07-31T00:00:00+08:00",' +
  '"timeMax":"2026-07-31T23:59:59+08:00","timezone":"Asia/Shanghai"},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]}}';
const CALENDAR_UPDATE_PREMATURE_LATER_ACTION_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.update"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{' +
  '"goal":"update the found event to 16:00","allowedActionIds":["calendar.event.update"]}}';
const CALENDAR_UPDATE_REPAIRED_DONE_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.update"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"answer":"已找到唯一日程，请在卡片中核对并确认更新。"}';
const CALENDAR_UPDATE_DIRECT_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.update"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{"goal":"update without a provider event",' +
  '"allowedActionIds":["calendar.event.update"]},"reasonCode":"calendar_update_zero_data"}';
const CALENDAR_UPDATE_DONE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.update","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已找到唯一日程，请在卡片中核对并确认更新。",' +
  '"reasonCode":"calendar_update_review_ready"}';
const CALENDAR_DELETE_SEARCH_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"execute",' +
  '"continuationMode":"dependency",' +
  '"dataTasks":[{"localId":"calendar-delete-search","goal":"find the exact event before delete",' +
  '"allowedToolIds":["calendar.events.search"],"toolId":"calendar.events.search",' +
  '"input":{"query":"forged title","eventId":"model-forged",' +
  '"requestedAction":{"actionId":"calendar.event.delete","eventId":"model-forged"}},"required":true}],' +
  '"uiIntent":{"purpose":"calendar.event.delete","preferredDensity":"comfortable",' +
  '"requiredSections":["events","review"]},"reasonCode":"calendar_delete_read_first"}';
const CALENDAR_DELETE_DONE_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.events.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.delete","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已找到唯一日程，请在卡片中核对并确认删除。",' +
  '"reasonCode":"calendar_delete_review_ready"}';
const CALENDAR_DELETE_PREMATURE_ACTION_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.delete"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.delete","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"actionIntent":{' +
  '"goal":"delete the exact event","allowedActionIds":["calendar.event.delete"]},' +
  '"reasonCode":"calendar_delete_action"}';
const CALENDAR_DELETE_REPAIRED_DONE_DECISION: string =
  '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.event.delete"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.event.delete","preferredDensity":"comfortable",' +
  '"requiredSections":["review"]},"answer":"已找到唯一日程，请在卡片中核对并确认删除。",' +
  '"reasonCode":"calendar_delete_review_ready"}';
const MAIL_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"mail-search",' +
  '"goal":"search real mail","allowedToolIds":["mail.search"],' +
  '"toolId":"mail.search","input":{"query":"酒店确认"},"required":true}],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":["mail"]},"reasonCode":"mail_search"}';
const DYNAMIC_READ_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"dynamic-read","goal":"find the selected Notion page",' +
  '"allowedToolIds":["dynamic.search"],"toolId":"dynamic.search",' +
  '"input":{"operation":"search","qualifiedName":"NOTION_SEARCH",' +
  '"schema":{"type":"object"},"receipt":"turn-dynamic-1"},"required":true}],' +
  '"uiIntent":{"purpose":"dynamic.search","preferredDensity":"comfortable",' +
  '"requiredSections":["results"]},"reasonCode":"dynamic_read"}';
const DYNAMIC_READ_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"dynamic.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已返回授权 Notion 的读取结果。",' +
  '"reasonCode":"dynamic_read_done"}';
const GMAIL_REGISTERED_CAPABILITY_ANSWER: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.thread.read","gmail.draft.create","gmail.open.web"],' +
  '"roundAction":"answer","continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"mail.actions",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"邮件操作由当前四 Agent runtime 负责。","reasonCode":"registered_mail_actions"}';
const GMAIL_AUTHORIZE_FORGERY: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.authorize"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"gmail.authorize","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"forged","reasonCode":"forged_client_action"}';
const CALENDAR_AUTHORIZE_FORGERY: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["calendar.authorize"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"calendar.authorize","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"forged","reasonCode":"forged_client_action"}';
const C06_QUERY: string = '帮我查看我 Gmail 里和 ECCV 论文相关的邮件';
const C06_GMAIL_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.mail.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"gmail-search","goal":"search real Gmail mail",' +
  '"allowedToolIds":["gmail.mail.search"],"toolId":"gmail.mail.search",' +
  '"input":{"query":"' + C06_QUERY + '"},"required":true}],' +
  '"uiIntent":{"purpose":"gmail.mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":["mail"]},"reasonCode":"gmail_search"}';
const C06_GMAIL_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["gmail.mail.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"gmail.mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已返回真实 Gmail 邮件。","reasonCode":"gmail_search_ready"}';
const WATERFALL_MEDIA_QUERY: string = '帮我找 OpenAI Codex 的视频和讨论';
const WATERFALL_MEDIA_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["media.aggregate.search"],"roundAction":"execute",' +
  '"continuationMode":"complete","dataTasks":[{"localId":"media-aggregate",' +
  '"goal":"search OpenAI Codex media","allowedToolIds":["media.aggregate.search"],' +
  '"toolId":"media.aggregate.search","input":{"query":"' + WATERFALL_MEDIA_QUERY + '"},' +
  '"required":true}],"uiIntent":{"purpose":"media.aggregate.search",' +
  '"preferredDensity":"comfortable","requiredSections":["media"]},' +
  '"reasonCode":"waterfall_media_search"}';
const WATERFALL_MEDIA_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["media.aggregate.search"],"roundAction":"answer",' +
  '"continuationMode":"complete","dataTasks":[],"uiIntent":{"purpose":"media.aggregate.search",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"媒体结果已就绪","reasonCode":"waterfall_media_ready"}';
const C09_SOCIAL_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.feed.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"social.feed.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"已返回真实 SocialHub 消息。","reasonCode":"social_feed_ready"}';
const F04_PRICE_DECISION: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["food.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"food-price","goal":"查询瑞幸生椰拿铁价格",' +
  '"allowedToolIds":["food.search"],"toolId":"food.search",' +
  '"input":{"query":"瑞幸生椰拿铁多少钱"},"required":true}],' +
  '"uiIntent":{"purpose":"food.search","preferredDensity":"comfortable",' +
  '"requiredSections":["food"]}}';
const F04_PRICE_DONE: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":["food.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"food.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"价格查询结果已就绪"}';
const R01_COMMUNITY_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.community.search"],"roundAction":"execute","continuationMode":"complete",' +
  '"dataTasks":[{"localId":"community","goal":"读取 Reddit 社区讨论",' +
  '"allowedToolIds":["social.community.search"],"toolId":"social.community.search",' +
  '"input":{"platform":"reddit","query":"Appless","limit":10},"required":true}],' +
  '"uiIntent":{"purpose":"social.community.search","preferredDensity":"comfortable",' +
  '"requiredSections":["social"]}}';
const R01_COMMUNITY_DONE: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.community.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"social.community.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"社区结果已就绪"}';
const R02_POST_PREVIEW_DECISION: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["social.post.preview"],"roundAction":"execute","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"social.post.preview","preferredDensity":"comfortable",' +
  '"requiredSections":["preview"]},"actionIntent":{"goal":"生成独立公开帖子预览",' +
  '"allowedActionIds":["social.post.preview"]}}';
const FOOD_CONTEXT_ANSWER: string = '{"personaId":"food_companion","skillId":"",' +
  '"requestedCapabilityIds":[],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"conversation",' +
  '"preferredDensity":"comfortable","requiredSections":[]},' +
  '"answer":"已按更新后的瑞幸偏好继续","reasonCode":"memory_context_routed"}';
const MAIL_DIRECT_ANSWER: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"你有一封酒店确认邮件","reasonCode":"mail_search"}';
const WEATHER_DIRECT_CLARIFY: string = '{"personaId":"default_companion","skillId":"",' +
  '"requestedCapabilityIds":["dynamic.search"],"roundAction":"clarify","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"weather","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"请确认天气地点","reasonCode":"weather_missing_location"}';
const MISLEADING_HOTEL_DIRECT_ANSWER: string = '{"personaId":"work_companion","skillId":"",' +
  '"requestedCapabilityIds":["mail.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"mail.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"按邮件能力回答","reasonCode":"mail_search"}';
const UNOBSERVED_HOTEL_DIRECT_ANSWER: string = '{"personaId":"travel_companion","skillId":"",' +
  '"requestedCapabilityIds":["hotel.search"],"roundAction":"answer","continuationMode":"complete","dataTasks":[],' +
  '"uiIntent":{"purpose":"hotel.search","preferredDensity":"comfortable",' +
  '"requiredSections":[]},"answer":"酒店价格是 500 元","reasonCode":"hotel_ready"}';

class QueueModel implements LocalModel {
  readonly prompts: string[] = [];
  readonly systemPrompts: string[] = [];
  private readonly outputs: string[];

  constructor(outputs: string[]) {
    this.outputs = outputs.slice();
  }

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt === undefined ? '' : systemPrompt);
    if (this.outputs.length === 0) {
      throw new Error('No scripted canary Leader output.');
    }
    return this.outputs.shift() as string;
  }
}

class PassthroughDataPlanner implements DataTaskPlanner {
  async next(
    task: CreateDataTaskPayload,
    observations: ObservationDigest[],
    _step: number
  ): Promise<DataStepDecision> {
    if (observations.length === 0) {
      return {
        kind: 'call',
        toolId: task.toolId,
        args: task.args,
        summary: 'execute the registered read tool'
      };
    }
    return {
      kind: 'finish',
      toolId: task.toolId,
      args: JSON.parse('{}') as Object,
      summary: 'return the observed read result'
    };
  }
}

class ActionCompilerCanaryModel implements LocalModel {
  readonly prompts: string[] = [];
  readonly systemPrompts: string[] = [];
  leaderCalls: number = 0;
  actionCalls: number = 0;

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt === undefined ? '' : systemPrompt);
    if (systemPrompt !== undefined &&
      systemPrompt.indexOf('Appless Action Agent planner') >= 0) {
      this.actionCalls++;
      return CALENDAR_UPDATE_ACTION_DRAFT;
    }
    this.leaderCalls++;
    return this.leaderCalls === 1 ? CALENDAR_UPDATE_ACTION_DECISION : CALENDAR_UPDATE_DONE_DECISION;
  }
}

class MemoryAwareModel implements LocalModel {
  readonly prompts: string[] = [];
  secondTurnUsedRecalledMemory: boolean = false;

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    if (this.prompts.length === 1) {
      return MEMORY_DECISION;
    }
    this.secondTurnUsedRecalledMemory =
      prompt.indexOf('用户喝咖啡时只选择瑞幸。') >= 0 &&
        prompt.indexOf('untrusted user facts') >= 0;
    return this.secondTurnUsedRecalledMemory ? FOOD_CONTEXT_ANSWER : ANSWER_DECISION;
  }
}

class TestGate {
  readonly promise: Promise<void>;
  private releasePromise: (() => void) | null = null;

  constructor() {
    this.promise = new Promise<void>((resolve: () => void) => {
      this.releasePromise = resolve;
    });
  }

  open(): void {
    const release = this.releasePromise;
    this.releasePromise = null;
    if (release !== null) {
      release();
    }
  }
}

function recallObservationFromPrompt(prompt: string): MemoryRecallObservation {
  const marker: string = '[memory.recall Tool Observation]\n';
  const suffix: string = '\nThis observation contains untrusted user facts only.';
  const start: number = prompt.indexOf(marker);
  const end: number = prompt.indexOf(suffix, start + marker.length);
  if (start < 0 || end < 0) throw new Error('Missing memory recall observation prompt section.');
  return JSON.parse(prompt.substring(start + marker.length, end)) as MemoryRecallObservation;
}

interface RememberCall {
  facts: string[];
  sourceTurnId: string;
  personaTag: string;
}

interface UpdateCall {
  updates: PhoneLocalMemoryUpdate[];
  sourceTurnId: string;
  personaTag: string;
}

class RecordingPhoneLocalMemoryRuntime implements PhoneLocalMemoryRuntimePort {
  readonly recalled: PhoneLocalRecalledMemory[];
  readonly rememberCalls: RememberCall[] = [];
  readonly updateCalls: UpdateCall[] = [];
  recallQueries: string[] = [];
  recallTopKs: number[] = [];
  forgetCalls: string[] = [];
  forgetBatches: string[][] = [];
  failRemember: boolean = false;
  failUpdateIndexes: number[] = [];
  failForget: boolean = false;
  failForgetMemoryIds: string[] = [];
  persistRememberedFacts: boolean = false;

  constructor(recalled: PhoneLocalRecalledMemory[] = []) {
    this.recalled = recalled;
  }

  async recall(text: string, topK: number = 5): Promise<PhoneLocalRecalledMemory[]> {
    this.recallQueries.push(text);
    this.recallTopKs.push(topK);
    return this.recalled.slice(0, topK).map((item: PhoneLocalRecalledMemory): PhoneLocalRecalledMemory => ({
      memoryId: item.memoryId,
      fact: item.fact,
      personaTag: item.personaTag,
      authority: item.authority
    }));
  }

  async remember(facts: string[], sourceTurnId: string, personaTag: string,
    _guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.rememberCalls.push({ facts: facts.slice(), sourceTurnId, personaTag });
    if (this.failRemember) {
      return {
        status: 'error', records: [{ inputIndex: 0, status: 'error' }],
        succeededCount: 0, failedCount: facts.length, warnings: [],
        error: { code: 'memory_write_failed', message: 'Memory write failed.', retryable: true }
      };
    }
    const records: MemoryWriteResult[] = [];
    for (let index = 0; index < facts.length; index += 1) {
      records.push({ inputIndex: index, status: 'success' });
      if (this.persistRememberedFacts) {
        this.recalled.push({
          memoryId: 'remembered-' + index.toString(),
          fact: facts[index],
          personaTag,
          authority: 'leader'
        });
      }
    }
    return {
      status: 'success', records, succeededCount: facts.length, failedCount: 0, warnings: []
    };
  }

  async update(updates: PhoneLocalMemoryUpdate[], sourceTurnId: string,
    personaTag: string, _guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.updateCalls.push({
      updates: updates.map((item): PhoneLocalMemoryUpdate => ({ memoryId: item.memoryId, fact: item.fact })),
      sourceTurnId,
      personaTag
    });
    const records: MemoryWriteResult[] = [];
    let succeededCount: number = 0;
    for (let index = 0; index < updates.length; index++) {
      if (this.failUpdateIndexes.indexOf(index) >= 0) {
        records.push({
          inputIndex: index,
          status: 'error',
          error: { code: 'memory_update_failed', message: 'Memory update failed.', retryable: true }
        });
      } else {
        records.push({ inputIndex: index, status: 'success' });
        succeededCount++;
      }
    }
    const failedCount: number = updates.length - succeededCount;
    const result: MemoryBatchResult = {
      status: succeededCount > 0 ? 'success' : 'error',
      records,
      succeededCount,
      failedCount,
      warnings: []
    };
    if (succeededCount === 0) {
      result.error = { code: 'memory_update_failed', message: 'Memory update failed.', retryable: true };
    }
    return result;
  }

  async forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.forgetBatches.push(memoryIds.slice());
    const records: MemoryWriteResult[] = [];
    let succeededCount: number = 0;
    for (let index = 0; index < memoryIds.length; index++) {
      const memoryId: string = memoryIds[index];
      this.forgetCalls.push(memoryId);
      if ((guard !== undefined && !guard.isActive()) || this.failForget ||
        this.failForgetMemoryIds.indexOf(memoryId) >= 0) {
        records.push({
          inputIndex: index,
          status: 'error',
          error: { code: 'memory_delete_failed', message: 'Memory delete failed.', retryable: true }
        });
      } else {
        records.push({ inputIndex: index, status: 'success' });
        succeededCount++;
      }
    }
    const failedCount: number = memoryIds.length - succeededCount;
    const result: MemoryBatchResult = {
      status: succeededCount > 0 ? 'success' : 'error', records,
      succeededCount, failedCount, warnings: []
    };
    if (succeededCount === 0) {
      result.error = { code: 'memory_delete_failed', message: 'Memory delete failed.', retryable: true };
    }
    return result;
  }

  async getProjectionStats(_basedOnMemoryMutationAt: number): Promise<PhoneLocalMemoryProjectionStats> {
    return { changedCount: 0, oldestPendingUpdatedAt: null };
  }

  async listProjectionFacts(): Promise<PhoneLocalMemoryProjectionFact[]> {
    return [];
  }
}

class ThrowingRecallMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  async recall(_text: string, _topK: number = 5): Promise<PhoneLocalRecalledMemory[]> {
    throw new Error('private recall failure');
  }
}

class StaticMemoryAvailability implements PhoneLocalMemoryAvailabilityPort {
  private readonly available: boolean;

  constructor(available: boolean) {
    this.available = available;
  }

  isAvailable(): boolean {
    return this.available;
  }
}

class SequencedRecallMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  private readonly outputs: PhoneLocalRecalledMemory[][];
  private readonly failAtIndex: number;

  constructor(outputs: PhoneLocalRecalledMemory[][], failAtIndex: number = -1) {
    super();
    this.outputs = outputs;
    this.failAtIndex = failAtIndex;
  }

  async recall(text: string, topK: number = 5): Promise<PhoneLocalRecalledMemory[]> {
    this.recallQueries.push(text);
    this.recallTopKs.push(topK);
    const index: number = this.recallQueries.length - 1;
    if (index === this.failAtIndex) throw new Error('private sequenced recall failure');
    const selected: PhoneLocalRecalledMemory[] = index < this.outputs.length ? this.outputs[index] : [];
    return selected.map((item: PhoneLocalRecalledMemory): PhoneLocalRecalledMemory => ({
      memoryId: item.memoryId,
      fact: item.fact,
      personaTag: item.personaTag,
      authority: item.authority
    }));
  }
}

class GatedRecallMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  readonly recallStarted: TestGate = new TestGate();
  readonly recallRelease: TestGate = new TestGate();

  async recall(text: string, topK: number = 5): Promise<PhoneLocalRecalledMemory[]> {
    this.recallStarted.open();
    await this.recallRelease.promise;
    return super.recall(text, topK);
  }
}

class GatedCommitMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  readonly commitStarted: TestGate = new TestGate();
  readonly commitRelease: TestGate = new TestGate();
  receivedGuard: MemoryCommitGuard | null = null;
  committed: number = 0;

  async remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.receivedGuard = guard === undefined ? null : guard;
    this.commitStarted.open();
    await this.commitRelease.promise;
    if (guard === undefined || !guard.isActive()) {
      return {
        status: 'error', records: [{ inputIndex: 0, status: 'error' }],
        succeededCount: 0, failedCount: facts.length, warnings: [],
        error: { code: 'memory_commit_canceled', message: 'Memory commit canceled.', retryable: false }
      };
    }
    this.committed++;
    return super.remember(facts, sourceTurnId, personaTag, guard);
  }
}

class FifoGatedMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  readonly firstStarted: TestGate = new TestGate();
  readonly firstRelease: TestGate = new TestGate();
  readonly startedFacts: string[] = [];
  readonly guards: MemoryCommitGuard[] = [];

  async remember(facts: string[], sourceTurnId: string, personaTag: string,
    guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.startedFacts.push(facts[0]);
    if (guard !== undefined) this.guards.push(guard);
    if (this.startedFacts.length === 1) {
      this.firstStarted.open();
      await this.firstRelease.promise;
    }
    if (guard === undefined || !guard.isActive()) {
      return {
        status: 'error', records: [{ inputIndex: 0, status: 'error' }],
        succeededCount: 0, failedCount: facts.length, warnings: [],
        error: { code: 'memory_commit_canceled', message: 'Memory commit canceled.', retryable: false }
      };
    }
    return super.remember(facts, sourceTurnId, personaTag, guard);
  }
}

class GatedForgetMemoryRuntime extends RecordingPhoneLocalMemoryRuntime {
  readonly forgetStarted: TestGate = new TestGate();
  readonly forgetRelease: TestGate = new TestGate();

  async forget(memoryIds: string[], guard?: MemoryCommitGuard): Promise<MemoryBatchResult> {
    this.forgetBatches.push(memoryIds.slice());
    this.forgetStarted.open();
    await this.forgetRelease.promise;
    if (guard === undefined || !guard.isActive()) {
      return {
        status: 'error',
        records: memoryIds.map((_memoryId: string, index: number): MemoryWriteResult => ({
          inputIndex: index, status: 'error'
        })),
        succeededCount: 0, failedCount: memoryIds.length, warnings: []
      };
    }
    this.forgetCalls.push(...memoryIds);
    return {
      status: 'success',
      records: memoryIds.map((_memoryId: string, index: number): MemoryWriteResult => ({
        inputIndex: index, status: 'success'
      })),
      succeededCount: memoryIds.length, failedCount: 0, warnings: []
    };
  }
}

class GatedModel implements LocalModel {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();
  private readonly output: string;

  constructor(output: string) {
    this.output = output;
  }

  async complete(_prompt: string): Promise<string> {
    this.started.open();
    await this.release.promise;
    return this.output;
  }
}

class CanaryHotelExecutor implements DataTaskExecutor {
  readonly calls: string[] = [];
  readonly tasks: CreateDataTaskPayload[] = [];
  readonly detailStarted: TestGate = new TestGate();
  readonly detailRelease: TestGate = new TestGate();

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    this.tasks.push(task);
    if (task.toolId === 'hotel.detail') {
      this.detailStarted.open();
      await this.detailRelease.promise;
      return detailData(task.args as HotelDetailRequest);
    }
    const parsed = parseHotelSearchRequest(task.args);
    if (parsed.value === null) {
      throw new Error('Invalid canary hotel search task.');
    }
    return hotelSearchDataResult(searchResult(parsed.value), []);
  }
}

class TwoToolExecutor implements DataTaskExecutor {
  readonly calls: string[] = [];

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.calls.push(task.toolId);
    const data: Object = task.toolId === 'travel.search' ? JSON.parse(
      '{"title":"出行方案","body":"真实出行结果","summary":"1 result",' +
        '"options":[],"rows":[]}'
    ) as Object : JSON.parse(
      '{"title":"高铁方案","body":"真实高铁结果","summary":"1 result","trains":[]}'
    ) as Object;
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'success',
      sources: [],
      data,
      warnings: []
    };
  }
}

class DeferredFlightTrainExecutor implements DataTaskExecutor {
  readonly started: string[] = [];
  readonly bothStarted: TestGate = new TestGate();
  private readonly flightRelease: TestGate = new TestGate();
  private readonly trainRelease: TestGate = new TestGate();

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.started.push(task.toolId);
    if (this.started.length === 2) {
      this.bothStarted.open();
    }
    if (task.toolId === 'flight.search') {
      await this.flightRelease.promise;
    } else {
      await this.trainRelease.promise;
    }
    return canaryStructuredResult(task.toolId, task.outputSchema);
  }

  releaseFlight(): void {
    this.flightRelease.open();
  }

  releaseTrain(): void {
    this.trainRelease.open();
  }
}

class ErrorHotelExecutor implements DataTaskExecutor {
  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'error',
      sources: [],
      data: new Object(),
      warnings: [],
      error: {
        code: 'PROVIDER_UNAVAILABLE',
        message: 'provider unavailable'
      }
    };
  }
}

class GatedHotelExecutor implements DataTaskExecutor {
  readonly started: TestGate = new TestGate();
  readonly release: TestGate = new TestGate();

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.started.open();
    await this.release.promise;
    const parsed = parseHotelSearchRequest(task.args);
    if (parsed.value === null) {
      throw new Error('Invalid gated hotel task.');
    }
    return hotelSearchDataResult(searchResult(parsed.value), []);
  }
}

class RecordingDynamicExecutor implements DataTaskExecutor {
  readonly tasks: CreateDataTaskPayload[] = [];

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.tasks.push(task);
    const result: DynamicGenericToolResult = {
      sourceTag: 'Composio',
      toolName: 'NOTION_SEARCH',
      title: 'Selected read result',
      status: 'success',
      summary: 'one result',
      rows: [],
      rawPreview: '{"id":"page-real-1"}'
    };
    return {
      toolId: task.toolId,
      outputSchema: task.outputSchema,
      status: 'success',
      sources: [],
      data: JSON.parse(JSON.stringify({ results: [result] })) as Object,
      warnings: []
    };
  }
}

class RecordingGenericExecutor implements DataTaskExecutor {
  readonly tasks: CreateDataTaskPayload[] = [];

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.tasks.push(task);
    return canaryStructuredResult(task.toolId, task.outputSchema);
  }
}

class GmailSearchExecutor implements DataTaskExecutor {
  async execute(_task: CreateDataTaskPayload): Promise<DataResult> {
    return c06GmailSearchResult();
  }
}

interface StructuredToolCallRecord {
  toolId: string;
  prompt: string;
  args: Object;
}

type CanaryJsonRecord = Record<string, JsonValue | undefined>;

function c02DecisionWithInput(inputJson: string): string {
  return '{"personaId":"travel_companion","skillId":"",' +
    '"requestedCapabilityIds":["travel.search"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"travel","goal":"搜索从北京到上海的出行方案",' +
    '"allowedToolIds":["travel.search"],"toolId":"travel.search","input":' + inputJson +
    ',"required":true}],"uiIntent":{"purpose":"travel.search",' +
    '"preferredDensity":"comfortable","requiredSections":["travel"]}}';
}

function canaryStructuredResult(toolId: string, outputSchema: string): DataResult {
  let data: Object;
  if (toolId === 'travel.search') {
    data = JSON.parse('{"title":"出行方案","body":"真实结果","summary":"0 result",' +
      '"options":[],"rows":[]}') as Object;
  } else if (toolId === 'train.search') {
    data = JSON.parse('{"title":"高铁方案","body":"真实结果","summary":"0 result","trains":[]}') as Object;
  } else if (toolId === 'flight.search') {
    data = JSON.parse('{"title":"航班方案","body":"真实结果","summary":"0 result","flights":[]}') as Object;
  } else {
    data = JSON.parse('{"results":[]}') as Object;
  }
  return {
    toolId,
    outputSchema,
    status: 'success',
    sources: [],
    data,
    warnings: []
  };
}

function c06GmailSearchResult(): DataResult {
  return {
    toolId: 'gmail.mail.search',
    outputSchema: 'mailThreads',
    status: 'success',
    sources: [{
      provider: 'Composio Gmail',
      backend: 'oauth_api',
      operation: 'gmail.mail.search',
      fetchedAt: '2026-07-23T10:00:00.000Z'
    }],
    data: JSON.parse('{"threads":[{"provider":"gmail","accountLabel":"Gmail",' +
      '"threadId":"thread-c06-real","messageId":"message-c06-real",' +
      '"subject":"ECCV paper review","from":"reviewer@example.com",' +
      '"to":["author@example.com"],"participants":["reviewer@example.com"],' +
      '"snippet":"ECCV review update","receivedAt":"2026-07-23T09:00:00Z",' +
      '"unread":true,"important":true,"sourceUrl":"https://mail.google.com/",' +
      '"rawProviderRef":"thread-c06-real","requestKey":"gmail:thread-c06-real"}],' +
      '"statuses":[{"provider":"gmail","status":"success","title":"Gmail",' +
      '"message":"1 real result"}],"extras":[],"entityRefs":["thread-c06-real"]}') as Object,
    warnings: []
  };
}

function c09SocialFeedResult(): DataResult {
  return {
    toolId: 'social.feed.search',
    outputSchema: 'socialHubFeed',
    status: 'success',
    sources: [],
    data: JSON.parse('{"items":[{"id":"item-c09-real","platform":"slack","kind":"message",' +
      '"author":"Alice","handle":"alice","text":"hello","timestamp":"2026-07-23T09:00:00Z",' +
      '"url":"","mediaUrl":"","channel":"general","channelId":"C1","threadId":"T1",' +
      '"unread":true}],"connections":[{"platform":"x","status":"connected","displayName":"X",' +
      '"accountId":"x-real","message":"connected"},{"platform":"slack","status":"connected",' +
      '"displayName":"Slack","accountId":"slack-real","message":"connected"}]}') as Object,
    warnings: []
  };
}

function waterfallMediaResult(
  status: 'partial' | 'success' | 'error',
  title: string,
  additionalTitle: string = '',
  includeNeedsAuth: boolean = false
): DataResult {
  const additionalVideo: string = additionalTitle.length === 0 ? '' :
    ',{"id":"' + additionalTitle + '","source":"youtube","provider":"YouTube Data API",' +
    '"title":"' + additionalTitle + '","summary":"OpenAI Codex discussion",' +
    '"url":"https://example.com/' + additionalTitle + '","thumbnail":"",' +
    '"publishedAt":"2026-08-06T00:00:00Z","duration":"2:00","status":"success","rows":[]}';
  const data = JSON.parse(
    '{"query":"' + WATERFALL_MEDIA_QUERY + '","videos":[{"id":"' + title + '",' +
    '"source":"youtube","provider":"YouTube Data API","title":"' + title + '",' +
    '"summary":"OpenAI Codex discussion","url":"https://example.com/' + title + '",' +
    '"thumbnail":"","publishedAt":"2026-08-06T00:00:00Z","duration":"2:00",' +
    '"status":"success","rows":[]}' + additionalVideo + '],"posts":[],"sourceStatuses":[{' +
    '"source":"youtube","label":"YouTube","status":"success","message":"' +
    (additionalTitle.length === 0 ? '1 video' : '2 videos') + '",' +
    '"count":' + (additionalTitle.length === 0 ? '1' : '2') + '}' +
    (includeNeedsAuth ? ',{"source":"x","label":"X","status":"needs_auth",' +
      '"message":"X authorization required","count":0}' : '') + '],"summary":"' +
    (additionalTitle.length === 0 ? '1 video' : '2 videos') + ', 0 discussions"}'
  ) as Object;
  return {
    toolId: 'media.aggregate.search',
    outputSchema: 'aggregateSearch',
    status,
    sources: [{
      provider: 'YouTube Data API',
      backend: 'local_adapter',
      operation: 'search',
      fetchedAt: '2026-08-06T00:00:00Z'
    }],
    data,
    warnings: status === 'error' ? ['YouTube unavailable'] : []
  };
}

function waterfallMediaErrorResult(): DataResult {
  return {
    toolId: 'media.aggregate.search',
    outputSchema: 'aggregateSearch',
    status: 'error',
    sources: [{
      provider: 'YouTube Data API',
      backend: 'local_adapter',
      operation: 'search',
      fetchedAt: '2026-08-06T00:00:00Z'
    }],
    data: JSON.parse('{"query":"' + WATERFALL_MEDIA_QUERY + '","videos":[],"posts":[],' +
      '"sourceStatuses":[{"source":"youtube","label":"YouTube","status":"error",' +
      '"message":"provider unavailable","count":0}],"summary":"0 videos, 0 discussions"}') as Object,
    warnings: ['YouTube unavailable']
  };
}

function c09SocialDecision(inputJson: string): string {
  return '{"personaId":"work_companion","skillId":"",' +
    '"requestedCapabilityIds":["social.feed.search"],"roundAction":"execute","continuationMode":"complete",' +
    '"dataTasks":[{"localId":"social-feed","goal":"read X and Slack messages",' +
    '"allowedToolIds":["social.feed.search"],"toolId":"social.feed.search","input":' +
    inputJson + ',"required":true}],"uiIntent":{"purpose":"social.feed.search",' +
    '"preferredDensity":"comfortable","requiredSections":["messages"]},' +
    '"reasonCode":"social_feed_search"}';
}

class CalendarUpdateExecutor implements DataTaskExecutor {
  readonly tasks: CreateDataTaskPayload[] = [];
  private readonly eventIds: string[];

  constructor(eventIds: string[]) {
    this.eventIds = eventIds.slice();
  }

  async execute(task: CreateDataTaskPayload): Promise<DataResult> {
    this.tasks.push(task);
    const values = task.args as Record<string, Object | string | number | boolean | null | undefined>;
    const rawRequestedAction = values['requestedAction'];
    const query = typeof values['query'] === 'string' ? values['query'] as string : '';
    const requestedAction: Object = rawRequestedAction !== null &&
      rawRequestedAction !== undefined && typeof rawRequestedAction === 'object' &&
      !Array.isArray(rawRequestedAction) ? rawRequestedAction as Object : JSON.parse('{}') as Object;
    const results: DynamicGenericToolResult[] = [];
    this.eventIds.forEach((eventId: string) => {
      const result: DynamicGenericToolResult = {
        sourceTag: 'Composio Google Calendar',
        toolName: 'calendar.events.search',
        title: query,
        status: 'success',
        summary: 'Real provider event.',
        rows: [
          { label: 'Event ID', value: eventId },
          { label: 'Start', value: '2026-07-30T15:00:00+08:00' },
          { label: 'End', value: '2026-07-30T15:30:00+08:00' }
        ],
        rawPreview: '{"id":' + JSON.stringify(eventId) + '}',
        providerPhase: 'execution'
      };
      results.push(result);
    });
    const data = JSON.parse(JSON.stringify({ results, requestedAction })) as Object;
    return {
      toolId: 'calendar.events.search',
      outputSchema: 'calendarEvents',
      status: results.length === 0 ? 'empty' : 'success',
      sources: results.length === 0 ? [] : [{
        provider: 'Composio Google Calendar',
        backend: 'oauth_api',
        operation: 'calendar.events.search',
        fetchedAt: '2026-07-22T00:00:00Z'
      }],
      data,
      warnings: []
    };
  }
}

class RecordingOpener implements SystemUriOpener {
  readonly uris: string[] = [];

  async open(uri: string): Promise<boolean> {
    this.uris.push(uri);
    return true;
  }
}

class RecordingWriter implements UiSurfaceWriter {
  writes: number = 0;

  async write(
    _turnId: string,
    _surfaceId: string,
    _jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    if (lease.isActive()) {
      this.writes++;
    }
  }
}

class ProgressRecordingRenderer implements UiTaskRenderer {
  resultSinkCount: number = 0;
  progressWriteCount: number = 0;

  private render(surfaceId: string, title: string): UiRenderResult {
    const result: DynamicGenericToolResult = {
      sourceTag: 'test',
      toolName: 'time',
      title,
      status: 'success',
      summary: title,
      rows: [],
      rawPreview: ''
    };
    return { jsonl: genericToolResultsA2ui(surfaceId, 'time', [result]) };
  }

  skeleton(_task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    return Promise.resolve(this.render(surfaceId, 'skeleton'));
  }

  async result(
    _task: CreateUiTaskPayload,
    _data: DataResult[],
    _offers: ActionOffer[],
    surfaceId: string,
    progressSink?: UiRenderProgressSink
  ): Promise<UiRenderResult> {
    if (progressSink !== undefined) {
      this.resultSinkCount++;
      await progressSink(this.render(surfaceId, 'partial'));
      this.progressWriteCount++;
    }
    return this.render(surfaceId, 'final');
  }

  error(_task: CreateUiTaskPayload, _message: string, surfaceId: string): Promise<UiRenderResult> {
    return Promise.resolve(this.render(surfaceId, 'error'));
  }

  actionStatus(_payload: Object, surfaceId: string): Promise<UiRenderResult> {
    return Promise.resolve(this.render(surfaceId, 'action'));
  }
}

class TrackingBus extends LinkedMessageBus {
  readonly messages: AgentMessage[] = [];

  publish(message: AgentMessage): void {
    this.messages.push(message);
    super.publish(message);
  }

  count(type: AgentMessageType): number {
    let total = 0;
    this.messages.forEach((message: AgentMessage) => {
      if (message.type === type) {
        total++;
      }
    });
    return total;
  }
}

function searchRequest(): HotelSearchRequest {
  const parsed = parseHotelSearchRequest(JSON.parse(SEARCH_INPUT) as Object);
  if (parsed.value === null) {
    throw new Error('Invalid hotel search fixture.');
  }
  return parsed.value;
}

function hotelItem(): HotelSearchItem {
  return {
    hotelId: 47675,
    bookingUrl: 'https://rollinggo.cn/pages/hotel/detail/index?id=47675&checkInDate=2026-08-15&checkOutDate=2026-08-17&roomCount=1&adultCount=2&childCount=0',
    name: '深圳测试酒店',
    nameEn: 'Shenzhen Test Hotel',
    brand: '',
    address: '深圳市南山区科技南路 88 号',
    destinationId: '6046792',
    latitude: 22.5431,
    longitude: 114.0579,
    distanceInMeters: 0,
    starRating: 5,
    price: { message: '2 晚参考价', hasPrice: true, currency: 'CNY', lowestPrice: 1100 },
    areaCode: 'NANSHAN',
    description: 'provider description',
    imageUrl: 'https://img.example/hotel.jpg',
    hotelAmenities: ['Wi-Fi'],
    tags: ['商务']
  };
}

function searchResult(query: HotelSearchRequest): HotelSearchResult {
  return {
    ok: true,
    error: '',
    message: '酒店搜索成功',
    query,
    hotels: [hotelItem()]
  };
}

function detailResult(query: HotelDetailRequest): HotelDetailResult {
  const rate: HotelRatePlan = {
    roomName: 'Deluxe',
    roomNameCn: '豪华大床房',
    ratePlanId: 'rate-real-1',
    ratePlanName: '不含早餐',
    averagePrice: 550,
    bedTypeDescription: '1 大床',
    currency: 'CNY',
    mealAmount: 0,
    mealTypeStr: '不含早餐',
    isOnRequest: false,
    cancelPolicy: '免费取消截止至 2026-08-12'
  };
  return {
    ok: true,
    error: '',
    message: '实时房型',
    query,
    hotelId: query.hotelId,
    bookingUrl: hotelItem().bookingUrl,
    name: '深圳测试酒店',
    nameEn: 'Shenzhen Test Hotel',
    checkIn: query.checkInDate,
    checkOut: query.checkOutDate,
    rates: [rate]
  };
}

function detailData(query: HotelDetailRequest): DataResult {
  return {
    toolId: 'hotel.detail',
    outputSchema: 'hotelRatePlans',
    status: 'success',
    sources: [],
    data: detailResult(query),
    warnings: []
  };
}

function canaryOptions(
  model: LocalModel,
  executor: DataTaskExecutor,
  opener: SystemUriOpener,
  surfaces: A2uiSurfaceState[],
  _updates: Object[],
  bus?: LinkedMessageBus,
  actionTimeoutMs: number = 1000
): MultiAgentCanaryOptions {
  return {
    model,
    opener,
    onSurface: (surface: A2uiSurfaceState): boolean => {
      surfaces.push(surface);
      return true;
    },
    dataPlanner: new PassthroughDataPlanner(),
    dataExecutor: executor,
    currentLocalDate: (): string => '2026-07-21',
    bus,
    conversationId: 'canary-test',
    downstreamWriter: new RecordingWriter(),
    submitTimeoutMs: 1000,
    actionTimeoutMs
  };
}

async function flush(rounds: number = 12): Promise<void> {
  for (let index = 0; index < rounds; index++) {
    await new Promise<void>((resolve: () => void) => setTimeout(resolve, 0));
  }
}

function overlayForgetAction(request: MemoryForgetOverlayRequest, indexes: number[]): A2uiAction {
  const keys: string[] = indexes.map((index: number): string => request.candidates[index].candidateKey);
  const args: MemoryCandidatesForgetActionArgs = {
    selectionId: request.selectionId,
    revision: request.revision,
    candidateKeys: keys
  };
  return {
    id: 'memory_candidates_forget',
    label: '确认删除长期记忆',
    prompt: '删除选中的长期记忆',
    variant: 'danger',
    kind: 'client',
    args
  };
}

function sideEffectStatus(result: LeaderMemoryToolResult | null): string {
  return result === null ? '' : result.status;
}

function overlayFact(request: MemoryForgetOverlayRequest | null, index: number): string {
  return request === null || index < 0 || index >= request.candidates.length ? '' : request.candidates[index].fact;
}

function overlayCandidateCount(request: MemoryForgetOverlayRequest | null): number {
  return request === null ? 0 : request.candidates.length;
}

function renderedAction(surface: A2uiSurfaceState, actionId: string): A2uiAction | null {
  const document: HtmlHomeDocument = createHtmlHomeDocument({
    surface,
    messages: [],
    isBusy: false,
    isAwaitingFirstSurface: false
  });
  const candidates: HtmlHomeAction[] = document.actions.slice();
  document.blocks.forEach((block) => {
    candidates.push(...block.actions);
  });
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (candidate.id === actionId && candidate.args !== undefined) {
      return {
        id: candidate.id,
        label: candidate.label,
        prompt: candidate.prompt,
        variant: candidate.variant,
        kind: candidate.kind,
        args: candidate.args
      };
    }
  }
  return null;
}

interface MemoryCandidateSelectionTestModel {
  memoryCandidateSelection: MemoryCandidateSelectionData;
}

function finalMemoryForgetAction(surface: A2uiSurfaceState, candidateIndexes: number[]): A2uiAction | null {
  const template = renderedAction(surface, 'memory_candidates_forget');
  if (template === null) return null;
  const model = JSON.parse(surface.dataModelJson) as MemoryCandidateSelectionTestModel;
  const candidateKeys: string[] = [];
  for (let index = 0; index < candidateIndexes.length; index++) {
    const candidateIndex: number = candidateIndexes[index];
    if (candidateIndex < 0 || candidateIndex >= model.memoryCandidateSelection.candidates.length) return null;
    candidateKeys.push(model.memoryCandidateSelection.candidates[candidateIndex].candidateKey);
  }
  const args: MemoryCandidatesForgetActionArgs = {
    selectionId: model.memoryCandidateSelection.selectionId,
    revision: model.memoryCandidateSelection.revision,
    candidateKeys
  };
  return {
    id: template.id,
    label: '删除已选（' + candidateKeys.length.toString() + '）',
    prompt: template.prompt,
    variant: template.variant,
    kind: template.kind,
    args
  };
}

function promptMarksPersonaPrevious(prompt: string, personaId: string): boolean {
  const start: number = prompt.indexOf('{"personaId":"' + personaId + '"');
  const next: number = start < 0 ? -1 : prompt.indexOf('},{"personaId"', start);
  const segment: string = start < 0 ? '' : prompt.substring(
    start,
    next < 0 ? prompt.length : next
  );
  return segment.indexOf('"previous":true') >= 0;
}

interface RecordedPageAction {
  actionId: string;
  args: Object;
  context: ActionExecutionContext;
}

interface RegisteredPageActionOutputFixture {
  actionId: string;
  pageActionId: string;
  conversationId: string;
  turnId: string;
  surfaceId: string;
  status: string;
  data: Object;
}

function pageSurface(
  sourceToolId: string,
  action: A2uiAction,
  sequence: number
): A2uiSurfaceState {
  const surface = createSeedA2uiSurface();
  const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
  model.summary.toolName = sourceToolId;
  model.summary.dataLabel = 'result';
  surface.surfaceId = 'page-surface-' + sequence.toString();
  surface.rootId = 'root';
  surface.title = sourceToolId;
  surface.intent = sourceToolId;
  surface.status = 'ready';
  surface.sequence = sequence;
  surface.runtimeOwner = 'multi_agent';
  surface.runtimeGeneration = sequence;
  surface.components = [{
    id: 'root',
    component: 'SurfaceRoot',
    actions: [action]
  }];
  surface.dataModelJson = JSON.stringify(model);
  return surface;
}

function defaultGmailDraftProviderResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Gmail API',
    toolName: 'users.drafts.create',
    title: 'Gmail 草稿已创建',
    status: 'success',
    summary: '已在真实 Gmail 账号中创建草稿；尚未发送。',
    rows: [
      { label: 'To', value: 'alice@example.com' },
      { label: 'Subject', value: '' },
      { label: 'Draft ID', value: 'draft-provider-1' },
      { label: 'Message ID', value: 'message-provider-1' }
    ],
    rawPreview: 'draftId=draft-provider-1 messageId=message-provider-1'
  };
}

function realComposioGmailDraftProviderResult(): DynamicGenericToolResult {
  return composioDynamicResultFromObservation(
    'execute',
    '{"data":{' +
      '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-provider-1",' +
      '"id":"draft-provider-1","message":{' +
      '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-provider-1",' +
      '"id":"message-provider-1","labelIds":["DRAFT"],"threadId":"thread-provider-1"}},' +
      '"error":null,"log_id":"log-provider-1"}',
    'GMAIL_CREATE_EMAIL_DRAFT',
    '创建 Gmail 草稿'
  );
}

function providerGmailDraftSurface(
  sequence: number,
  providerResult: DynamicGenericToolResult = defaultGmailDraftProviderResult()
): A2uiSurfaceState {
  const parsed = parseA2uiJsonl(
    gmailDraftPreviewA2ui(
      'gmail-provider-draft',
      providerResult,
      JSON.parse('{"to":["alice@example.com"],"subject":"","body":"我收到了"}') as Object,
      'gmail.draft.create'
    )
  );
  const store = new A2uiSurfaceStore();
  parsed.envelopes.forEach((envelope) => store.apply(envelope));
  const surface = store.getSurface();
  surface.runtimeOwner = 'multi_agent';
  surface.runtimeGeneration = sequence;
  return surface;
}

function successfulGmailDraftTerminalSurface(surface: A2uiSurfaceState): A2uiSurfaceState {
  const terminal = JSON.parse(JSON.stringify(surface)) as A2uiSurfaceState;
  const model = JSON.parse(terminal.dataModelJson) as A2uiRuntimeDataModel;
  model.summary = {
    text: '操作状态：success',
    toolName: 'action',
    dataLabel: 'actionStatus',
    count: 0
  };
  terminal.dataModelJson = JSON.stringify(model);
  terminal.sequence = surface.sequence + 1;
  return terminal;
}

function registeredPageActionOutput(
  actionId: string,
  surface: A2uiSurfaceState,
  context: ActionExecutionContext
): RegisteredPageActionOutputFixture {
  const output: RegisteredPageActionOutputFixture = {
    actionId,
    pageActionId: actionId,
    conversationId: context.conversationId,
    turnId: context.turnId,
    surfaceId: surface.surfaceId,
    status: surface.status,
    data: JSON.parse(surface.dataModelJson) as Object
  };
  return output;
}

function registeredGmailDraftProviderOutput(
  surface: A2uiSurfaceState,
  context: ActionExecutionContext
): RegisteredPageActionOutputFixture {
  const output = registeredPageActionOutput('gmail.draft.create', surface, context);
  const data = output.data as A2uiRuntimeDataModel;
  data.genericToolResults[0].actions = [];
  data.genericToolResults[0].rawPreview = '';
  return output;
}

function currentGmailReplySurface(sequence: number): A2uiSurfaceState {
  const result: DynamicGenericToolResult = {
    sourceTag: 'Gmail API',
    toolName: 'users.threads.get',
    title: 'QA',
    status: 'success',
    summary: 'QA body',
    rows: [
      { label: 'Provider', value: 'gmail' },
      { label: 'From', value: 'Alice <alice@example.com>' },
      { label: 'Thread ID', value: 'thread-real-1' },
      { label: 'Message ID', value: 'message-real-1' }
    ],
    rawPreview: ''
  };
  const parsed = parseA2uiJsonl(
    gmailThreadResultsA2ui('gmail-reply-surface', 'gmail.mail.search', [result])
  );
  const store = new A2uiSurfaceStore();
  parsed.envelopes.forEach((envelope) => store.apply(envelope));
  const surface = store.getSurface();
  surface.runtimeOwner = 'multi_agent';
  surface.runtimeGeneration = sequence;
  return surface;
}

function pageSnapshot(surface: A2uiSurfaceState, generation: number): RegisteredPageSnapshot {
  return {
    surface,
    document: createHtmlHomeDocument({
      surface,
      messages: [],
      isBusy: false,
      isAwaitingFirstSurface: false
    }),
    generation
  };
}

function pendingPageSnapshot(
  surface: A2uiSurfaceState,
  generation: number,
  inputText: string
): RegisteredPageSnapshot {
  return {
    surface,
    document: createHtmlHomeDocument({
      messages: [],
      inputText,
      isBusy: true,
      isAwaitingFirstSurface: true
    }),
    generation
  };
}

function useLastRenderedSurfaceAsHost(
  options: MultiAgentCanaryOptions,
  surfaces: A2uiSurfaceState[]
): void {
  options.currentPageSnapshot = (): RegisteredPageSnapshot | null => surfaces.length === 0 ?
    null : pageSnapshot(surfaces[surfaces.length - 1], surfaces.length);
  options.currentHostSurface = (): A2uiSurfaceState | null => surfaces.length === 0 ?
    null : surfaces[surfaces.length - 1];
  options.currentHostGeneration = (): number => {
    if (surfaces.length === 0) {
      return 0;
    }
    const generation = surfaces[surfaces.length - 1].runtimeGeneration;
    return generation === undefined ? 0 : generation;
  };
}

class AlwaysActiveSurfaceWriteLease implements UiSurfaceWriteLease {
  isActive(): boolean {
    return true;
  }
}

export default function multiAgentCanaryRuntimeTest() {
  describe('multiAgentCanaryRuntime', () => {
    it('queues memory overlay only behind real foreground modal state', 0, () => {
      const idle: MemoryForgetOverlayGateState = {
        busy: false, checkout: false, train: false, deepSearch: false, map: false, confirming: false
      };
      const confirming: MemoryForgetOverlayGateState = {
        busy: false, checkout: false, train: false, deepSearch: false, map: false, confirming: true
      };
      const busy: MemoryForgetOverlayGateState = {
        busy: true, checkout: false, train: false, deepSearch: false, map: false, confirming: false
      };
      expect(memoryForgetOverlayBlocked(idle)).assertFalse();
      expect(memoryForgetOverlayBlocked(confirming)).assertTrue();
      expect(memoryForgetOverlayBlocked(busy)).assertTrue();
      expect(memoryForgetOverlayBottomPadding(24))
        .assertEqual(MEMORY_FORGET_OVERLAY_BASE_BOTTOM_PADDING + 24);
      expect(memoryForgetOverlayBottomPadding(-10))
        .assertEqual(MEMORY_FORGET_OVERLAY_BASE_BOTTOM_PADDING);
      expect(MEMORY_FORGET_OVERLAY_SCROLL_MAX_HEIGHT > 0).assertTrue();
    });
    it('maps memory persona tags to user-facing Chinese names without exposing unknown IDs', 0, () => {
      expect(memoryForgetOverlayPersonaName('default_companion')).assertEqual('默认分身');
      expect(memoryForgetOverlayPersonaName('food_companion')).assertEqual('饮食搭子');
      expect(memoryForgetOverlayPersonaName('travel_companion')).assertEqual('旅行搭子');
      expect(memoryForgetOverlayPersonaName('work_companion')).assertEqual('工作分身');
      expect(memoryForgetOverlayPersonaName('entertainment_companion')).assertEqual('娱乐搭子');
      expect(memoryForgetOverlayPersonaName('game_companion')).assertEqual('游戏搭子');
      expect(memoryForgetOverlayPersonaName('shopping_companion')).assertEqual('购物搭子');
      expect(memoryForgetOverlayPersonaName('future_internal_persona')).assertEqual('其他分身');
      expect(memoryForgetOverlayPersonaName('')).assertEqual('');
    });
    it('keeps UI Lab catalog bindings without widening the default parser profile', 0, async () => {
      const jsonl = '{"version":"v0.9.1","createSurface":{"surfaceId":"profile-bindings",' +
        '"root":"root","title":"Bindings","status":"ready"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"profile-bindings","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["copy","hero","line"]},' +
        '{"id":"copy","component":"Text","title":{"path":"/copy/title"}},' +
        '{"id":"hero","component":"HeroBanner","title":{"path":"/hero/title"},' +
        '"body":{"path":"/hero/body"}},' +
        '{"id":"line","component":"MultiSeriesLineChart","title":{"path":"/chart/title"},' +
        '"dataPath":"/chart"}]}}\n';
      const lease: UiSurfaceWriteLease = new AlwaysActiveSurfaceWriteLease();
      const uiLabSurfaces: A2uiSurfaceState[] = [];
      const uiLabWriter = new HotelRuntimeSurfaceWriter(
        'ui-lab-profile',
        new RecordingWriter(),
        (surface: A2uiSurfaceState): boolean => {
          uiLabSurfaces.push(surface);
          return true;
        },
        new HotelSurfaceAuthority(),
        new HotelVisibility(),
        true,
        undefined,
        'ui-lab'
      );
      await uiLabWriter.write('ui-lab-turn', 'profile-bindings', jsonl, lease);
      expect(uiLabSurfaces.length).assertEqual(1);
      const uiLabComponents = uiLabSurfaces[0].components;
      expect(uiLabComponents[2].catalogFieldsJson?.includes('/copy/title')).assertTrue();
      expect(uiLabComponents[3].catalogFieldsJson?.includes('/hero/title')).assertTrue();
      expect(uiLabComponents[3].catalogFieldsJson?.includes('/hero/body')).assertTrue();
      expect(uiLabComponents[4].catalogFieldsJson?.includes('/chart/title')).assertTrue();

      const legacySurfaces: A2uiSurfaceState[] = [];
      const legacyWriter = new HotelRuntimeSurfaceWriter(
        'legacy-profile',
        new RecordingWriter(),
        (surface: A2uiSurfaceState): boolean => {
          legacySurfaces.push(surface);
          return true;
        },
        new HotelSurfaceAuthority(),
        new HotelVisibility(),
        true
      );
      await legacyWriter.write('legacy-turn', 'profile-bindings', jsonl, lease);
      expect(legacySurfaces.length).assertEqual(1);
      const legacyComponents = legacySurfaces[0].components;
      expect(legacyComponents[2].catalogFieldsJson === undefined).assertTrue();
      expect(legacyComponents[3].catalogFieldsJson === undefined).assertTrue();
      expect(legacyComponents[4].catalogFieldsJson === undefined).assertTrue();
    });

    it('keeps the existing runtime behavior', 0, async () => {
      const options = canaryOptions(
        new QueueModel([ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('你好', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('你好');
      runtime.dispose();
    });

    it('carries the originating host generation into a virtual page action callback', 0, async () => {
      let originHostGeneration: number = 0;
      const options = canaryOptions(
        new QueueModel([WORLDCUP_ACTION_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentHostGeneration = (): number => 41;
      options.pageAction = async (
        _actionId: string,
        _args: Object,
        context: RegisteredPageActionContext
      ): Promise<ActionExecutionResult> => {
        originHostGeneration = context.hostGeneration === undefined ? 0 : context.hostGeneration;
        return {
          status: 'success',
          output: JSON.parse('{"status":"opened"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '打开世界杯页面', { text: '' }, 41
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(originHostGeneration).assertEqual(41);
      runtime.dispose();
    });

    it('owns C01 greeting without a tool surface', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      ));

      const outcome = await runtime.submit('你好', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('你好');
      expect(surfaces.length).assertEqual(0);
      runtime.dispose();
    });

    it('executes time from the device clock without calling an external provider', 0, async () => {
      const model = new QueueModel([TIME_DECISION, TIME_DONE_DECISION]);
      const surfaces: A2uiSurfaceState[] = [];
      let externalCalls: number = 0;
      const options = canaryOptions(
        model,
        new RecordingGenericExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        _toolId: string,
        _prompt: string,
        _args: Object
      ): Promise<DataResult> => {
        externalCalls++;
        throw new Error('time must not call an external provider');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('查一下现在的时间', {
        text: ''
      }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(externalCalls).assertEqual(0);
      expect(model.systemPrompts[0].indexOf('"toolId":"time"')).assertLarger(-1);
      expect(surfaces.length).assertLarger(0);
      runtime.dispose();
    });

    it('forwards the UI progress sink through the ordinary mail-detail bridge branch', 0, async () => {
      const renderer = new ProgressRecordingRenderer();
      const options = canaryOptions(
        new QueueModel([TIME_DECISION, TIME_DONE_DECISION]),
        new RecordingGenericExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.uiRenderer = renderer;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('查一下现在的时间', { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(renderer.resultSinkCount).assertEqual(1);
      expect(renderer.progressWriteCount).assertEqual(1);
      runtime.dispose();
    });

    it('owns one independent two-tool turn without a terminal Leader replan', 0, async () => {
      const executor = new TwoToolExecutor();
      const bus = new TrackingBus();
      const model = new QueueModel([TWO_TOOL_DECISION, TWO_TOOL_DONE_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('比较明天北京到上海的出行和高铁', {
        text: ''
      }) as MultiAgentSettledOutcome;

      expect(outcome.kind).assertEqual('settled');
      expect(outcome.status).assertEqual('success');
      expect(executor.calls.sort().join(',')).assertEqual('train.search,travel.search');
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(2);
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('delegates an incomplete travel query without host-side semantic repair', 0, async () => {
      const executor = new TwoToolExecutor();
      const bus = new TrackingBus();
      const model = new QueueModel([INCOMPLETE_TRAVEL_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit(
        '我下周要去上海出差', { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('travel.search');
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(1);
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('accepts a complete model travel query without reparsing conversation wording', 0, async () => {
      const executor = new TwoToolExecutor();
      const model = new QueueModel([CONTEXTUAL_TRAVEL_DECISION]);
      const options = canaryOptions(model, executor, new RecordingOpener(), [], []);
      options.currentLocalDate = (): string => '2026-08-13';
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '我下周要去上海出差', { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('travel.search');
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('passes model travel fields through to the registered adapter', 0, async () => {
      const executor = new TwoToolExecutor();
      const model = new QueueModel([CONTEXTUAL_TRAVEL_FIELDS_DECISION]);
      const options = canaryOptions(model, executor, new RecordingOpener(), [], []);
      options.currentLocalDate = (): string => '2026-08-13';
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '我下周要去上海出差', { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('travel.search');
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('does not reinterpret a travel query wrapped by foreground BIM snapshots', 0, async () => {
      const executor = new TwoToolExecutor();
      const bus = new TrackingBus();
      const model = new QueueModel([INCOMPLETE_TRAVEL_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit(
        '[BIM_SNAPSHOTS]\n\n[/BIM_SNAPSHOTS]\n\n我下周要去上海出差', { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('travel.search');
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(1);
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('keeps independent flight and train reads concurrent until one aggregate surface is ready', 0,
      async () => {
        const executor = new DeferredFlightTrainExecutor();
        const bus = new TrackingBus();
        const surfaces: A2uiSurfaceState[] = [];
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          new QueueModel([FLIGHT_TRAIN_DECISION, FLIGHT_TRAIN_DONE_DECISION]),
          executor,
          new RecordingOpener(),
          surfaces,
          [],
          bus
        ));

        const pending = runtime.submit('比较明天北京到上海的航班和高铁', { text: '' });
        await executor.bothStarted.promise;

        expect(executor.started.join(',')).assertEqual('flight.search,train.search');
        expect(bus.count(AgentMessageType.TASK_RESULT_DATA)).assertEqual(0);
        executor.releaseFlight();
        executor.releaseTrain();
        const outcome = await pending as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('success');
        expect(surfaces.length).assertEqual(2);
        expect(outcome.surfaceId).assertEqual(surfaces[0].surfaceId);
        expect(surfaces[1].surfaceId).assertEqual(surfaces[0].surfaceId);
        expect(surfaces[1].dataModelJson.indexOf('flights')).assertLarger(-1);
        expect(surfaces[1].dataModelJson.indexOf('trains')).assertLarger(-1);
        runtime.dispose();
      });

    it('assembles the approved Action Agent prompt on the production canary model seam', 0, async () => {
      const model = new ActionCompilerCanaryModel();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        new CalendarUpdateExecutor(['event-provider-real-1']),
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit(
        '把 2026年7月30日 的 Appless QA run-1 日程改到下午4点',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('success');
      expect(model.leaderCalls).assertEqual(2);
      expect(model.actionCalls).assertEqual(1);
      const actionPromptIndex = model.systemPrompts.findIndex((value: string): boolean =>
        value.indexOf('Appless Action Agent planner') >= 0
      );
      expect(actionPromptIndex >= 0).assertTrue();
      expect(model.prompts[actionPromptIndex].indexOf('calendar.event.update') >= 0).assertTrue();
      expect(model.prompts[actionPromptIndex].indexOf('update the one real Calendar event') >= 0)
        .assertTrue();
      runtime.dispose();
    });

    it('executes model-authored travel queries while leaving non-travel goals unchanged', 0,
      async () => {
        const calls: StructuredToolCallRecord[] = [];
        const options: MultiAgentCanaryOptions = canaryOptions(
          new QueueModel([
            C02_QUERY_DECISION,
            F01_QUERY_DECISION,
            F02_QUERY_DECISION,
            DYNAMIC_READ_DECISION
          ]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.dataExecutor = undefined;
        options.structuredToolCall = async (
          toolId: string,
          prompt: string,
          args: Object
        ): Promise<DataResult> => {
          calls.push({ toolId, prompt, args });
          const definitionOutput: string = toolId === 'travel.search' ? 'travelOptions' :
            (toolId === 'flight.search' ? 'flights' :
              (toolId === 'train.search' ? 'trains' : 'dynamicToolConnect'));
          return canaryStructuredResult(toolId, definitionOutput);
        };
        const runtime: MultiAgentCanaryRuntime = new MultiAgentCanaryRuntime(options);

        await runtime.submit(C02_QUERY, { text: '' });
        await runtime.submit(F01_QUERY, { text: '' });
        await runtime.submit(F02_QUERY, { text: '' });
        await runtime.submit('搜索我授权的 Notion 页面', { text: '' });

        expect(calls.length).assertEqual(4);
        expect(calls[0].toolId).assertEqual('travel.search');
        expect(calls[0].prompt).assertEqual(C02_QUERY);
        expect(calls[1].toolId).assertEqual('flight.search');
        expect(calls[1].prompt).assertEqual(F01_QUERY);
        expect(calls[2].toolId).assertEqual('train.search');
        expect(calls[2].prompt).assertEqual(F02_QUERY);
        expect(calls[3].toolId).assertEqual('dynamic.search');
        expect(calls[3].prompt).assertEqual('find the selected Notion page');
        const c02Args = calls[0].args as Record<string, Object | string | number | boolean>;
        const flightArgs = calls[1].args as Record<string, Object | string | number | boolean>;
        const trainArgs = calls[2].args as Record<string, Object | string | number | boolean>;
        const dynamicArgs = calls[3].args as Record<string, Object | string | number | boolean>;
        expect(c02Args['query']).assertEqual(C02_QUERY);
        expect(c02Args['departureDate']).assertEqual('2026-07-23');
        expect(c02Args['origin']).assertEqual('北京');
        expect(c02Args['destination']).assertEqual('上海');
        expect(flightArgs['query']).assertEqual(F01_QUERY);
        expect(trainArgs['query']).assertEqual(F02_QUERY);
        expect(dynamicArgs['qualifiedName']).assertEqual('NOTION_SEARCH');
        runtime.dispose();
      });

    it('uses the model query produced from standard recent context before calling the provider', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const model = new QueueModel([CONTEXTUAL_TRAVEL_DECISION]);
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.currentLocalDate = (): string => '2026-08-13';
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return canaryStructuredResult(toolId, 'travelOptions');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('深圳，8月21号', {
        text: '深圳，8月21号',
        recentMessages: [
          { role: 'user', content: '我下周要去上海出差' },
          { role: 'assistant', content: '你从哪座城市出发？另外，下周具体哪一天出发？' },
          { role: 'user', content: '深圳，8月21号' }
        ]
      }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('travel.search');
      expect(calls[0].prompt).assertEqual('从深圳到上海，出发日期 2026-08-21，查询高铁和航班');
      const args = calls[0].args as Record<string, Object | string | number | boolean>;
      expect(args['query']).assertEqual('从深圳到上海，出发日期 2026-08-21，查询高铁和航班');
      runtime.dispose();
    });

    it('uses a self-contained task goal when structured travel input has no query field', 0,
      async () => {
        const calls: StructuredToolCallRecord[] = [];
        const goal: string = '搜索2026年8月28日从深圳到上海的出行方案';
        const decision: string = c02DecisionWithInput(
          '{"origin":"深圳","destination":"上海","date":"2026-08-28"}'
        ).replace('搜索从北京到上海的出行方案', goal);
        const options = canaryOptions(
          new QueueModel([decision]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.dataExecutor = undefined;
        options.structuredToolCall = async (
          toolId: string,
          prompt: string,
          args: Object
        ): Promise<DataResult> => {
          calls.push({ toolId, prompt, args });
          return canaryStructuredResult(toolId, 'travelOptions');
        };
        const runtime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit('飞机吧，上海住3晚', {
          text: '飞机吧，上海住3晚',
          recentMessages: [
            { role: 'user', content: '8月28日从深圳去上海出差' },
            { role: 'assistant', content: '你想坐飞机还是高铁？' }
          ]
        }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('success');
        expect(calls.length).assertEqual(1);
        expect(calls[0].prompt).assertEqual(goal);
        const args = calls[0].args as Record<string, Object | string | number | boolean | undefined>;
        expect(args['origin']).assertEqual('深圳');
        expect(args['destination']).assertEqual('上海');
        expect(args['date']).assertEqual('2026-08-28');
        expect(args['query'] === undefined).assertTrue();
        runtime.dispose();
      });

    it('executes C02 travel Data only once without opening a repeat round', 0, async () => {
      const model = new QueueModel([C02_QUERY_DECISION]);
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls: number = 0;
      const options: MultiAgentCanaryOptions = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        [],
        bus
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        _args: Object
      ): Promise<DataResult> => {
        providerCalls += 1;
        expect(toolId).assertEqual('travel.search');
        expect(prompt).assertEqual(C02_QUERY);
        return canaryStructuredResult(toolId, 'travelOptions');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(C02_QUERY, { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(providerCalls).assertEqual(1);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(1);
      expect(model.prompts.length).assertEqual(1);
      const finalSurface = surfaces[surfaces.length - 1];
      let retainedSkeleton: boolean = false;
      for (let index = 0; index < finalSurface.components.length; index++) {
        const component = finalSurface.components[index];
        retainedSkeleton = retainedSkeleton || component.title === '正在准备结果' ||
          component.text === '正在准备结果' || component.body === '正在准备结果';
      }
      expect(outcome.surfaceId).assertEqual(finalSurface.surfaceId);
      expect(retainedSkeleton).assertFalse();
      runtime.dispose();
    });

    it('rejects prototype member names in travel inputs before the structured provider', 0, async () => {
      const unsafeInputs: string[] = [
        '{"query":"forged","__proto__":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"__proto__":{"polluted":"yes"}}}',
        '{"query":"forged","constructor":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"constructor":{"polluted":"yes"}}}',
        '{"query":"forged","prototype":{"polluted":"yes"}}',
        '{"query":"forged","nested":{"prototype":{"polluted":"yes"}}}'
      ];
      let providerCalls: number = 0;
      for (let index: number = 0; index < unsafeInputs.length; index++) {
        const options: MultiAgentCanaryOptions = canaryOptions(
          new QueueModel([c02DecisionWithInput(unsafeInputs[index]), C02_QUERY_DONE]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.dataExecutor = undefined;
        options.structuredToolCall = async (
          toolId: string,
          _prompt: string,
          _args: Object
        ): Promise<DataResult> => {
          providerCalls += 1;
          return canaryStructuredResult(toolId, 'travelOptions');
        };
        const runtime: MultiAgentCanaryRuntime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit(C02_QUERY, { text: '' }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('error');
        runtime.dispose();
      }
      const clean: CanaryJsonRecord = {};
      expect(providerCalls).assertEqual(0);
      expect(clean['polluted'] === undefined).assertTrue();
    });

    it('uses the shared JSON Pointer boundary for deep clones and non-JSON shapes', 0, () => {
      const shared = JSON.parse('{"value":"shared"}') as CanaryJsonRecord;
      const source = JSON.parse(
        '{"query":"forged","nested":{"keep":true},"list":[{"name":"first"}]}'
      ) as CanaryJsonRecord;
      source['left'] = shared;
      source['right'] = shared;
      const assigned = setJsonPointer(source, '/query', C02_QUERY);

      expect(assigned.ok).assertTrue();
      const cloned = assigned.value as CanaryJsonRecord;
      expect(cloned['query'] as string).assertEqual(C02_QUERY);
      expect(JSON.stringify(cloned['nested'])).assertEqual('{"keep":true}');
      expect(JSON.stringify(cloned['list'])).assertEqual('[{"name":"first"}]');
      expect(cloned['nested'] === source['nested']).assertFalse();
      expect(cloned['list'] === source['list']).assertFalse();
      expect(cloned['left'] === cloned['right']).assertFalse();
      (source['nested'] as CanaryJsonRecord)['keep'] = false;
      expect(JSON.stringify(cloned['nested'])).assertEqual('{"keep":true}');

      const namedArray: JsonValue[] = ['safe'];
      (namedArray as Object as CanaryJsonRecord)['named'] = 'unsafe';
      const namedSource = JSON.parse('{}') as CanaryJsonRecord;
      namedSource['values'] = namedArray;
      expect(setJsonPointer(namedSource, '/query', C02_QUERY).ok).assertFalse();

      const sparseArray: JsonValue[] = [];
      sparseArray.length = 2;
      sparseArray[1] = 'unsafe';
      const sparseSource = JSON.parse('{}') as CanaryJsonRecord;
      sparseSource['values'] = sparseArray;
      expect(setJsonPointer(sparseSource, '/query', C02_QUERY).ok).assertFalse();

      const cyclic: CanaryJsonRecord = {};
      cyclic['self'] = cyclic;
      expect(setJsonPointer(cyclic, '/query', C02_QUERY).ok).assertFalse();
      const clean: CanaryJsonRecord = {};
      expect(clean['polluted'] === undefined).assertTrue();
    });

    it('keeps C13 dynamic read in MultiAgent Data and executes only the selected read slug', 0, async () => {
      const executor = new RecordingDynamicExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([DYNAMIC_READ_DECISION, DYNAMIC_READ_DONE]),
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('搜索我授权的 Notion 页面', { text: '' });

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('dynamic.search');
      expect(executor.tasks[0].allowedToolIds.join(',')).assertEqual('dynamic.search');
      const args = executor.tasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;
      expect(args['operation'] as string).assertEqual('search');
      expect(args['qualifiedName'] as string).assertEqual('NOTION_SEARCH');
      runtime.dispose();
    });

    it('does not unwrap an args envelope for a non SocialHub Data task', 0, async () => {
      const input = '{"args":{"operation":"search","qualifiedName":"NOTION_SEARCH",' +
        '"schema":{"type":"object"},"receipt":"turn-dynamic-1"}}';
      const decision = DYNAMIC_READ_DECISION.replace(
        '{"operation":"search","qualifiedName":"NOTION_SEARCH",' +
          '"schema":{"type":"object"},"receipt":"turn-dynamic-1"}',
        input
      );
      const executor = new RecordingDynamicExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([decision, DYNAMIC_READ_DONE]),
        executor,
        new RecordingOpener(),
        [],
        []
      ));

      const outcome = await runtime.submit('搜索我授权的 Notion 页面', { text: '' });
      const args = executor.tasks[0].args as Record<
        string,
        Object | string | number | boolean | null | undefined
      >;

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(1);
      expect(Object.keys(args).join(',')).assertEqual('args');
      expect(JSON.stringify(args['args'])).assertEqual(
        '{"operation":"search","qualifiedName":"NOTION_SEARCH",' +
          '"schema":{"type":"object"},"receipt":"turn-dynamic-1"}'
      );
      runtime.dispose();
    });

    it('accepts capability preflight clarification while rejecting unobserved direct answers', 0, async () => {
      const model = new QueueModel([
        ANSWER_DECISION,
        MAIL_DIRECT_ANSWER,
        WEATHER_DIRECT_CLARIFY,
        MISLEADING_HOTEL_DIRECT_ANSWER,
        UNOBSERVED_HOTEL_DIRECT_ANSWER
      ]);
      const executor = new CanaryHotelExecutor();
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const greeting = await runtime.submit('你好', { text: '' });
      const mail = await runtime.submit('查一下酒店确认邮件', { text: '' });
      const weather = await runtime.submit('查询天气', { text: '' });
      const misleadingHotel = await runtime.submit('酒店两个字不要误导，查我的邮件', { text: '' });
      const unobservedHotel = await runtime.submit('深圳酒店多少钱', { text: '' });

      expect(greeting.kind).assertEqual('settled');
      expect((greeting as MultiAgentSettledOutcome).message).assertEqual('你好');
      expect(mail.kind).assertEqual('settled');
      expect((mail as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(weather.kind).assertEqual('settled');
      expect((weather as MultiAgentSettledOutcome).status).assertEqual('success');
      expect((weather as MultiAgentSettledOutcome).message).assertEqual('请确认天气地点');
      expect(misleadingHotel.kind).assertEqual('settled');
      expect((misleadingHotel as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(unobservedHotel.kind).assertEqual('settled');
      expect((unobservedHotel as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(executor.calls.length).assertEqual(0);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA ||
          message.type === AgentMessageType.TASK_CREATE_UI ||
          message.type === AgentMessageType.ACTION_PLAN_REQUEST
      ).length).assertEqual(0);
      expect(model.systemPrompts[0].indexOf('"requestedCapabilityIds"') >= 0).assertTrue();
      runtime.dispose();
    });

    it('does not remember a persona from an error terminal outcome', 0, async () => {
      const model = new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION, ANSWER_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        new ErrorHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));

      const failed = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;
      const next = await runtime.submit('你好', {
        text: '',
        previousPersonaId: 'travel_companion'
      }) as MultiAgentSettledOutcome;

      expect(failed.status).assertEqual('error');
      expect(next.status).assertEqual('success');
      expect(promptMarksPersonaPrevious(model.prompts[2], 'travel_companion')).assertFalse();
      runtime.dispose();
    });

    it('does not remember a persona from a canceled in-flight turn', 0, async () => {
      const model = new QueueModel([HOTEL_DECISION, ANSWER_DECISION]);
      const executor = new GatedHotelExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        []
      ));

      const pending = runtime.submit(SEARCH_TEXT, { text: '' }) as
        Promise<MultiAgentSettledOutcome>;
      await executor.started.promise;
      runtime.cancelActiveTurn('user_cancel');
      executor.release.open();
      const canceled = await pending;
      const next = await runtime.submit('你好', {
        text: '',
        previousPersonaId: 'travel_companion'
      }) as MultiAgentSettledOutcome;

      expect(canceled.status).assertEqual('canceled');
      expect(next.status).assertEqual('success');
      expect(promptMarksPersonaPrevious(model.prompts[1], 'travel_companion')).assertFalse();
      runtime.dispose();
    });

    it('provides hotel correlation IDs from the neutral multi-agent support module', 0, () => {
      const ids = new MonotonicHotelIds();

      expect(ids.nextId('turn')).assertEqual('turn-1');
      expect(ids.nextId('task')).assertEqual('task-2');
    });

    it('gives the Leader registry-derived SocialHub, public X, mail, and dynamic selection semantics', 0, async () => {
      const model = new QueueModel([ANSWER_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));

      await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });

      const prompt = model.systemPrompts[0];
      expect(prompt.indexOf('SocialHub inbox')).assertLarger(-1);
      expect(prompt.indexOf('private-message')).assertLarger(-1);
      expect(prompt.indexOf('dataTasks[].input.platforms')).assertLarger(-1);
      expect(prompt.indexOf('exactly one key named platforms')).assertLarger(-1);
      expect(prompt.indexOf('Do not add date, query, or limit')).assertLarger(-1);
      expect(prompt.indexOf('legacy ToolCall uses args.platforms')).assertLarger(-1);
      expect(prompt.indexOf('public X/Twitter posts')).assertLarger(-1);
      expect(prompt.indexOf('mailbox/email/inbox')).assertLarger(-1);
      expect(prompt.indexOf('Composio-backed app/toolkit')).assertLarger(-1);
      expect(prompt.indexOf('github.user.dashboard')).assertEqual(-1);
      expect(prompt.indexOf('Video selection contract')).assertLarger(-1);
      expect(prompt.indexOf('Explicit Google Maps/Google Places/GMap/谷歌地图 requests use exactly maps.place.search'))
        .assertLarger(-1);
      expect(prompt.indexOf('"toolId":"gmail.message.send"')).assertEqual(-1);
      expect(prompt.indexOf('"toolId":"social.feed.search","domain":"social"')).assertLarger(-1);
      expect(prompt.indexOf('"registeredBackends":["local_adapter"]')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"dynamic.search","domain":"dynamic"')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"memory.remember","domain":"memory"')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"memory.update","domain":"memory"')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"memory.forget","domain":"memory"')).assertLarger(-1);
      const catalogStart = prompt.indexOf('Registry capabilities: ');
      const catalogEnd = prompt.indexOf('\nAvailable Data owner IDs: ', catalogStart);
      expect(catalogStart).assertLarger(-1);
      expect(catalogEnd).assertLarger(catalogStart);
      const catalog = prompt.substring(catalogStart, catalogEnd);
      expect(catalog.indexOf('"toolId":"hotel.search"')).assertLarger(-1);
      expect(catalog.indexOf('"toolId":"hotel.detail"')).assertLarger(-1);
      expect(catalog.indexOf('"toolId":"hotel.navigate"')).assertEqual(-1);
      expect(catalog.indexOf('"toolId":"hotel.booking.open"')).assertEqual(-1);
      expect(catalog.indexOf('"toolId":"gmail.message.send"')).assertEqual(-1);
      expect(catalog.indexOf('"toolId":"social.reply.draft"')).assertEqual(-1);
      expect(catalogEnd - catalogStart).assertLess(64001);
      expect(prompt.length + model.prompts[0].length).assertLess(100001);
      expect(model.prompts.length).assertEqual(1);
      runtime.dispose();
    });

    it('exposes trusted GitHub operation targets only for an authorized host profile', 0, async () => {
      const model = new QueueModel([ANSWER_DECISION]);
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.allowTrustedOperationTargets = true;
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('为 GitHub 用户 sindresorhus 生成数据看板', { text: '' });

      expect(model.systemPrompts[0].indexOf('github.user.dashboard')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('operationTarget')).assertLarger(-1);
      runtime.dispose();
    });

    it('executes the production Data task directly without Data or terminal Leader model calls', 0, async () => {
      const model = new QueueModel([HOTEL_DECISION]);
      const executor = new CanaryHotelExecutor();
      const options = canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        []
      );
      options.dataPlanner = undefined;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.length).assertEqual(1);
      expect(executor.calls[0]).assertEqual('hotel.search');
      expect(model.prompts.length).assertEqual(1);
      expect(model.prompts[0].indexOf('You are the Appless Data Agent.')).assertEqual(-1);
      runtime.dispose();
    });

    it('normalizes a BIM business task against the original user query', 0, async () => {
      const model = new QueueModel([HOTEL_DECISION]);
      const executor = new CanaryHotelExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        []
      ));
      const bimPrompt = bimSnapshotPrompt(SEARCH_TEXT);

      const outcome = await runtime.submit(
        bimPrompt, { text: SEARCH_TEXT }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      expect((executor.tasks[0].args as
        Record<string, Object | string | number | boolean>)['originQuery']).assertEqual(SEARCH_TEXT);
      runtime.dispose();
    });

    it('accepts a structured hotel task resolved from conversation context', 0, async () => {
      const contextualInput: string = '{"originQuery":"2026年8月28日上海住3晚",' +
        '"place":"上海","placeType":"CITY","countryCode":"CN",' +
        '"checkInDate":"2026-08-28","stayNights":3,"adultCount":2,' +
        '"childCount":0,"childAgeDetails":[],"roomCount":1,"currency":"CNY","size":10}';
      const executor = new CanaryHotelExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([HOTEL_DECISION.replace(SEARCH_INPUT, contextualInput)]),
        executor,
        new RecordingOpener(),
        [],
        []
      ));

      const outcome = await runtime.submit('飞机吧，上海住3晚', {
        text: '飞机吧，上海住3晚',
        recentMessages: [{ role: 'user', content: '8月28日从深圳去上海出差' }]
      }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      const args = executor.tasks[0].args as
        Record<string, Object | string | number | boolean | null | undefined>;
      expect(args['place']).assertEqual('上海');
      expect(args['checkInDate']).assertEqual('2026-08-28');
      expect(args['stayNights']).assertEqual(3);
      runtime.dispose();
    });

    it('keeps a BIM-resolved travel query for the registered tool', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const model = new QueueModel([BIM_FLIGHT_DECISION]);
      const options: MultiAgentCanaryOptions = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return canaryStructuredResult(toolId, 'flights');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const originalQuery = '帮我查去展会的机票';
      const bimPrompt = bimTravelSnapshotPrompt(originalQuery);

      const outcome = await runtime.submit(bimPrompt, { text: originalQuery }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('flight.search');
      expect(calls[0].prompt).assertEqual('查询2026年8月30日从深圳到杭州的机票');
      expect((calls[0].args as Record<string, Object | string | number | boolean>)['query'])
        .assertEqual('查询2026年8月30日从深圳到杭州的机票');
      runtime.dispose();
    });

    it('uses the self-contained goal for fields-only travel tasks', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const options: MultiAgentCanaryOptions = canaryOptions(
        new QueueModel([BIM_FLIGHT_FIELDS_ONLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return canaryStructuredResult(toolId, 'flights');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const originalQuery = F01_QUERY;
      const bimPrompt = bimSnapshotPrompt(originalQuery);

      const outcome = await runtime.submit(
        bimPrompt, { text: originalQuery }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].prompt).assertEqual('搜索2026年8月30日深圳到杭州的航班');
      expect((calls[0].args as Record<string, Object | string | number | boolean | undefined>)['query'] === undefined)
        .assertTrue();
      runtime.dispose();
    });

    it('preserves BIM flight fields and delegates with the self-contained goal', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const options: MultiAgentCanaryOptions = canaryOptions(
        new QueueModel([BIM_FLIGHT_FIELDS_ONLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return canaryStructuredResult(toolId, 'flights');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const originalQuery = '帮我查从深圳出发去展会的机票';
      const bimPrompt = bimTravelSnapshotPrompt(originalQuery);

      const outcome = await runtime.submit(
        bimPrompt, { text: originalQuery }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('flight.search');
      expect(calls[0].prompt).assertEqual('搜索2026年8月30日深圳到杭州的航班');
      expect((calls[0].args as Record<string, Object | string | number | boolean | undefined>)['query'] === undefined)
        .assertTrue();
      runtime.dispose();
    });

    it('keeps a BIM train task as train rather than rewriting it as flight', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const options: MultiAgentCanaryOptions = canaryOptions(
        new QueueModel([BIM_TRAIN_FIELDS_ONLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return canaryStructuredResult(toolId, 'trains');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const originalQuery = '帮我查去展会的高铁';
      const bimPrompt = bimTravelSnapshotPrompt(originalQuery);

      const outcome = await runtime.submit(bimPrompt, { text: originalQuery }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('train.search');
      expect(calls[0].prompt).assertEqual('搜索2026年8月30日深圳到杭州的高铁');
      expect((calls[0].args as Record<string, Object | string | number | boolean | undefined>)['query'] === undefined)
        .assertTrue();
      runtime.dispose();
    });

    it('delegates travel completeness checks to the registered adapter', 0, async () => {
      let providerCalls: number = 0;
      const options: MultiAgentCanaryOptions = canaryOptions(
        new QueueModel([BIM_FLIGHT_INCOMPLETE_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        _toolId: string,
        _prompt: string,
        _args: Object
      ): Promise<DataResult> => {
        providerCalls += 1;
        return canaryStructuredResult('flight.search', 'flights');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const bimPrompt = bimSnapshotPrompt('帮我查去展会的机票');

      const outcome = await runtime.submit(
        bimPrompt, { text: '帮我查去展会的机票' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(providerCalls).assertEqual(1);
      runtime.dispose();
    });

    it('does not add a second host date parser for structured travel input', 0, async () => {
      let providerCalls: number = 0;
      const options: MultiAgentCanaryOptions = canaryOptions(
        new QueueModel([BIM_FLIGHT_MONTH_ONLY_FIELDS_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        _toolId: string,
        _prompt: string,
        _args: Object
      ): Promise<DataResult> => {
        providerCalls += 1;
        return canaryStructuredResult('flight.search', 'flights');
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const originalQuery = '帮我查从北京到上海 2026年8月的航班';
      const bimPrompt = bimSnapshotPrompt(originalQuery);

      const outcome = await runtime.submit(
        bimPrompt, { text: originalQuery }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(providerCalls).assertEqual(1);
      runtime.dispose();
    });

    it('always projects Luckin order tool descriptions for model selection', 0, async () => {
      const priceModel = new QueueModel([ANSWER_DECISION]);
      const priceRuntime = new MultiAgentCanaryRuntime(canaryOptions(
        priceModel,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));
      await priceRuntime.submit('瑞幸生椰拿铁多少钱', { text: '' });
      const priceCatalogStart = priceModel.systemPrompts[0].indexOf('Registry capabilities: ');
      const priceCatalogEnd = priceModel.systemPrompts[0].indexOf(
        '\nAvailable Data owner IDs: ', priceCatalogStart
      );
      const priceCatalog = priceModel.systemPrompts[0].substring(priceCatalogStart, priceCatalogEnd);
      expect(priceCatalog.indexOf('"toolId":"food.search"')).assertLarger(-1);
      expect(priceCatalog.indexOf('"toolId":"luckin.order.preview"')).assertLarger(-1);
      expect(priceCatalog.indexOf('"toolId":"luckin.order.create"')).assertLarger(-1);
      expect(priceCatalog.indexOf('"toolId":"luckin.order.status"')).assertLarger(-1);
      priceRuntime.dispose();

      const orderModel = new QueueModel([ANSWER_DECISION]);
      const orderRuntime = new MultiAgentCanaryRuntime(canaryOptions(
        orderModel,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));
      await orderRuntime.submit('帮我点一杯瑞幸生椰拿铁，半糖少冰', { text: '' });
      const orderCatalogStart = orderModel.systemPrompts[0].indexOf('Registry capabilities: ');
      const orderCatalogEnd = orderModel.systemPrompts[0].indexOf(
        '\nAvailable Data owner IDs: ', orderCatalogStart
      );
      const orderCatalog = orderModel.systemPrompts[0].substring(orderCatalogStart, orderCatalogEnd);
      expect(orderCatalog.indexOf('"toolId":"luckin.order.preview"')).assertLarger(-1);
      expect(orderCatalog.indexOf('"toolId":"luckin.order.create"')).assertLarger(-1);
      expect(orderCatalog.indexOf('"toolId":"luckin.order.status"')).assertLarger(-1);
      orderRuntime.dispose();

      const statusModel = new QueueModel([ANSWER_DECISION]);
      const statusRuntime = new MultiAgentCanaryRuntime(canaryOptions(
        statusModel,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));
      await statusRuntime.submit('查询瑞幸订单状态', { text: '' });
      const statusCatalogStart = statusModel.systemPrompts[0].indexOf('Registry capabilities: ');
      const statusCatalogEnd = statusModel.systemPrompts[0].indexOf(
        '\nAvailable Data owner IDs: ', statusCatalogStart
      );
      const statusCatalog = statusModel.systemPrompts[0].substring(statusCatalogStart, statusCatalogEnd);
      expect(statusCatalog.indexOf('"toolId":"luckin.order.preview"')).assertLarger(-1);
      expect(statusCatalog.indexOf('"toolId":"luckin.order.create"')).assertLarger(-1);
      expect(statusCatalog.indexOf('"toolId":"luckin.order.status"')).assertLarger(-1);
      statusRuntime.dispose();
    });

    it('projects the fixed community read and standalone post preview contracts', 0, async () => {
      const model = new QueueModel([ANSWER_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      ));

      await runtime.submit('帮我看看 Reddit 上对 Appless 的讨论', { text: '' });

      const prompt = model.systemPrompts[0];
      expect(prompt.indexOf('"toolId":"social.community.search"')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"social.post.preview"')).assertLarger(-1);
      expect(prompt.indexOf('"toolId":"social.reply.draft"')).assertEqual(-1);
      expect(prompt.indexOf(
        'Reddit/LinkedIn/Instagram/public community reading -> social.community.search'
      )).assertLarger(-1);
      expect(prompt.indexOf(
        'Standalone public post draft -> social.post.preview'
      )).assertLarger(-1);
      expect(prompt.indexOf(
        'social.reply.draft only after a selected real inbox/feed item'
      )).assertLarger(-1);
      runtime.dispose();
    });

    it('executes F04 price as food.search without creating an Action plan', 0, async () => {
      const bus = new TrackingBus();
      const executor = new RecordingGenericExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([F04_PRICE_DECISION, F04_PRICE_DONE]),
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('瑞幸生椰拿铁多少钱', { text: '' });

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('food.search');
      expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(0);
      expect(bus.count(AgentMessageType.ACTION_PLAN_DRAFT)).assertEqual(0);
      runtime.dispose();
    });

    it('executes R01 through social.community.search and never x.post.search', 0, async () => {
      const executor = new RecordingGenericExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([R01_COMMUNITY_DECISION, R01_COMMUNITY_DONE]),
        executor,
        new RecordingOpener(),
        [],
        []
      ));

      const outcome = await runtime.submit('帮我看看 Reddit 上对 Appless 的讨论', { text: '' });

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('social.community.search');
      expect(executor.tasks.filter((task: CreateDataTaskPayload): boolean =>
        task.toolId === 'x.post.search'
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('executes R02 as a zero-Data preview Action without provider write authority', 0, async () => {
      const executor = new RecordingGenericExecutor();
      const actionIds: string[] = [];
      const actionArgs: Object[] = [];
      const options = canaryOptions(
        new QueueModel([R02_POST_PREVIEW_DECISION]),
        executor,
        new RecordingOpener(),
        [],
        []
      );
      options.currentHostGeneration = (): number => 1;
      options.pageAction = async (
        actionId: string,
        args: Object,
        _context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        actionIds.push(actionId);
        actionArgs.push(args);
        return {
          status: 'success',
          output: JSON.parse('{"surfaceId":"social-preview"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '帮我为 X 起草一条介绍 Appless 新版本的帖子',
        { text: '' },
        1
      );

      expect(outcome.kind).assertEqual('settled');
      expect(executor.tasks.length).assertEqual(0);
      expect(actionIds.join(',')).assertEqual('social.post.preview');
      expect(JSON.stringify(actionArgs[0])).assertEqual(
        '{"platform":"x","operation":"publish","text":"介绍 Appless 新版本"}'
      );
      expect(actionIds.indexOf('social.reply.draft')).assertEqual(-1);
      expect(actionIds.indexOf('social.post.publish')).assertEqual(-1);
      runtime.dispose();
    });

    it('passes only the Leader selected top-level SocialHub platforms to the Provider', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const bus = new TrackingBus();
      const model = new QueueModel([
        c09SocialDecision('{"platforms":["x","slack"],"date":"2026-07-23"}'),
        c09SocialDecision('{"platforms":["x","slack"]}')
      ]);
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object,
        onPartial?: (result: DataResult) => void
      ): Promise<DataResult> => {
        expect(onPartial === undefined).assertTrue();
        calls.push({ toolId, prompt, args });
        return c09SocialFeedResult();
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });
      const args = calls[0].args as Record<string, Object | string | number | boolean>;
      const platforms = args['platforms'] as Object[];

      expect(outcome.kind).assertEqual('settled');
      expect((outcome as MultiAgentSettledOutcome).status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('social.feed.search');
      expect(Object.keys(args).join(',')).assertEqual('platforms');
      expect(platforms.length).assertEqual(2);
      expect(platforms[0]).assertEqual('x');
      expect(platforms[1]).assertEqual('slack');
      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('LEADER_TASK_INPUT_INVALID')).assertLarger(-1);
      runtime.dispose();
    });

    it('publishes no Data task when the one SocialHub input repair remains invalid', 0, async () => {
      const bus = new TrackingBus();
      const executor = new RecordingDynamicExecutor();
      const model = new QueueModel([
        c09SocialDecision('{"platforms":["x","slack"],"date":"2026-07-23"}'),
        c09SocialDecision('{"platforms":["x","slack"],"date":"2026-07-23"}')
      ]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });
      const errors = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_ERROR
      );

      expect(outcome.kind).assertEqual('settled');
      expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(model.prompts.length).assertEqual(2);
      expect(executor.tasks.length).assertEqual(0);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
      expect(errors.length).assertEqual(1);
      expect((errors[0].payload as TaskErrorPayload).code).assertEqual('LEADER_TASK_INPUT_INVALID');
      runtime.dispose();
    });

    it('keeps the exact input error when repair changes tools UI or JSON shape', 0, async () => {
      const repairs: string[] = [
        MAIL_DECISION,
        c09SocialDecision('{"platforms":["x","slack"]}')
          .replace('"purpose":"social.feed.search"', '"purpose":"forged.ui"'),
        '{'
      ];
      for (let index = 0; index < repairs.length; index++) {
        const bus = new TrackingBus();
        const executor = new RecordingDynamicExecutor();
        const model = new QueueModel([
          c09SocialDecision('{"platforms":["x","slack"],"date":"2026-07-23"}'),
          repairs[index]
        ]);
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          model,
          executor,
          new RecordingOpener(),
          [],
          [],
          bus
        ));

        const outcome = await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });
        const errors = bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.TASK_ERROR
        );

        expect(outcome.kind).assertEqual('settled');
        expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
        expect(model.prompts.length).assertEqual(2);
        expect(executor.tasks.length).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
        expect(errors.length).assertEqual(1);
        expect((errors[0].payload as TaskErrorPayload).code)
          .assertEqual('LEADER_TASK_INPUT_INVALID');
        runtime.dispose();
      }
    });

    it('unwraps one legacy args envelope before passing SocialHub platforms to the Provider', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const options = canaryOptions(
        new QueueModel([
          c09SocialDecision('{"args":{"platforms":["x","slack"]}}'),
          C09_SOCIAL_DONE
        ]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return c09SocialFeedResult();
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });
      const args = calls[0].args as Record<string, Object | string | number | boolean>;
      const platforms = args['platforms'] as Object[];

      expect(outcome.kind).assertEqual('settled');
      expect((outcome as MultiAgentSettledOutcome).status).assertEqual('success');
      expect(Object.keys(args).join(',')).assertEqual('platforms');
      expect(platforms.length).assertEqual(2);
      expect(platforms[0]).assertEqual('x');
      expect(platforms[1]).assertEqual('slack');
      runtime.dispose();
    });

    it('rejects malformed SocialHub platform inputs before Data task publication', 0, async () => {
      const malformed: string[] = [
        '{"args":{"platforms":["x","slack"]},"extra":true}',
        '{"args":[]}',
        '{"platforms":[]}',
        '{"platforms":["x","x"]}',
        '{"platforms":["x","unknown"]}',
        '{"platforms":["all","slack"]}'
      ];
      for (let index = 0; index < malformed.length; index++) {
        const bus = new TrackingBus();
        const executor = new RecordingDynamicExecutor();
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          new QueueModel([c09SocialDecision(malformed[index])]),
          executor,
          new RecordingOpener(),
          [],
          [],
          bus
        ));

        const outcome = await runtime.submit('帮我查看我今天 X 和 Slack 上的消息', { text: '' });

        expect(outcome.kind).assertEqual('settled');
        expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
        expect(executor.tasks.length).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
        runtime.dispose();
      }
    });

    it('rejects a nested SocialHub Data task at authorization', 0, async () => {
      const bus = new TrackingBus();
      const executor = new RecordingDynamicExecutor();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        new QueueModel([ANSWER_DECISION]),
        executor,
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      bus.publish({
        type: AgentMessageType.TASK_CREATE_DATA,
        conversationId: 'canary-test',
        turnId: 'forged-social-turn',
        taskId: 'forged-social-task',
        payload: {
          taskId: 'forged-social-task',
          roundId: 'forged-social-turn:round-1',
          skillId: '',
          goal: 'read social messages',
          allowedToolIds: ['social.feed.search'],
          toolId: 'social.feed.search',
          outputSchema: 'socialHubFeed',
          args: JSON.parse('{"args":{"platforms":["x","slack"]}}') as Object,
          required: true
        } as CreateDataTaskPayload
      });
      await flush();

      expect(executor.tasks.length).assertEqual(0);
      expect(bus.count(AgentMessageType.TASK_ERROR)).assertEqual(1);
      runtime.dispose();
    });

    it('keeps registered Gmail tool and action capabilities inside the canary runtime', 0, async () => {
      const model = new QueueModel([GMAIL_REGISTERED_CAPABILITY_ANSWER]);
      const bus = new TrackingBus();
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      ));

      const outcome = await runtime.submit('继续处理当前 Gmail 邮件', { text: '' });

      expect(outcome.kind).assertEqual('settled');
      expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
      expect(model.systemPrompts[0].indexOf('gmail.thread.read') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('gmail.draft.create') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('gmail.open.web') >= 0).assertTrue();
      expect(model.systemPrompts[0].indexOf('gmail.authorize') >= 0).assertFalse();
      runtime.dispose();
    });

    it('fails closed on forged client-only authorize capabilities without work', 0, async () => {
      const forgeries: string[] = [GMAIL_AUTHORIZE_FORGERY, CALENDAR_AUTHORIZE_FORGERY];
      for (let index = 0; index < forgeries.length; index++) {
        const bus = new TrackingBus();
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          new QueueModel([forgeries[index]]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          [],
          bus
        ));

        const outcome = await runtime.submit('malicious authorize output', { text: '' });

        expect(outcome.kind).assertEqual('settled');
        expect((outcome as MultiAgentSettledOutcome).status).assertEqual('error');
        expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_UI)).assertEqual(0);
        expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(0);
        expect(bus.count(AgentMessageType.ACTION_RUN)).assertEqual(0);
        runtime.dispose();
      }
    });

    it('executes the C06 Gmail search through Data Agent', 0, async () => {
      const calls: StructuredToolCallRecord[] = [];
      const bus = new TrackingBus();
      const options = canaryOptions(
        new QueueModel([C06_GMAIL_DECISION, C06_GMAIL_DONE]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object
      ): Promise<DataResult> => {
        calls.push({ toolId, prompt, args });
        return c06GmailSearchResult();
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(C06_QUERY, { text: '' });
      const tasks = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA
      );
      const results = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_RESULT_DATA
      );
      const task = tasks[0].payload as CreateDataTaskPayload;
      const taskArgs = task.args as Record<string, Object | string | number | boolean>;
      const result = results[0].payload as DataResult;

      expect(outcome.kind).assertEqual('settled');
      expect((outcome as MultiAgentSettledOutcome).status).assertEqual('success');
      expect(tasks.length).assertEqual(1);
      expect(results.length).assertEqual(1);
      expect(task.toolId).assertEqual('gmail.mail.search');
      expect(taskArgs['query']).assertEqual(C06_QUERY);
      expect(result.toolId).assertEqual('gmail.mail.search');
      expect(result.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].toolId).assertEqual('gmail.mail.search');
      expect((calls[0].args as Record<string, Object | string | number | boolean>)['query'])
        .assertEqual(C06_QUERY);
      runtime.dispose();
    });

    it('streams media partials through the structured executor before final DataResult', 0, async () => {
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      const finalGate = new TestGate();
      const providerStatuses: string[] = [];
      const options = canaryOptions(
        new QueueModel([WATERFALL_MEDIA_DECISION, WATERFALL_MEDIA_DONE]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        [],
        bus
      );
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        toolId: string,
        prompt: string,
        args: Object,
        onPartial?: (result: DataResult) => void
      ): Promise<DataResult> => {
        expect(toolId).assertEqual('media.aggregate.search');
        expect(prompt).assertEqual('search OpenAI Codex media');
        expect((args as Record<string, Object | string>)['query']).assertEqual(WATERFALL_MEDIA_QUERY);
        if (onPartial !== undefined) {
          const publish = (result: DataResult): void => {
            providerStatuses.push(result.status);
            onPartial(result);
          };
          publish(waterfallMediaErrorResult());
          publish(waterfallMediaResult('partial', 'first-source'));
          await Promise.resolve();
          publish(waterfallMediaResult('partial', 'late-source', 'first-source', true));
        }
        await finalGate.promise;
        return waterfallMediaResult('partial', 'final-result', '', true);
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const pending = runtime.submit(WATERFALL_MEDIA_QUERY, { text: '' });
      await flush();

      try {
        const partialMessages = bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.TASK_RESULT_DATA_PARTIAL &&
            (message.payload as DataResult).status === 'partial'
        );
        expect(providerStatuses.join(',')).assertEqual('error,partial,partial');
        expect(partialMessages.length).assertEqual(2);
        expect(surfaces.length).assertLarger(1);
        expect(surfaces[1].surfaceId).assertEqual(surfaces[0].surfaceId);
        expect(surfaces[surfaces.length - 1].surfaceId).assertEqual(surfaces[0].surfaceId);
        expect(surfaces[surfaces.length - 1].dataModelJson.indexOf('first-source')).assertLarger(-1);
        expect(surfaces[surfaces.length - 1].dataModelJson.indexOf('late-source')).assertLarger(-1);
        expect(surfaces[surfaces.length - 1].dataModelJson.indexOf('needs_auth')).assertLarger(-1);
      } finally {
        finalGate.open();
      }
      const outcome = await pending as MultiAgentSettledOutcome;
      expect(outcome.status).assertEqual('partial');
      const finalMessages = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_RESULT_DATA
      );
      const resultMessages = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_RESULT_UI &&
          (message.payload as UiRenderResultPayload).state === 'result'
      );
      expect(finalMessages.length).assertEqual(1);
      expect((finalMessages[0].payload as DataResult).status).assertEqual('partial');
      expect(resultMessages.length).assertEqual(1);
      expect((resultMessages[0].payload as UiRenderResultPayload).surfaceId.length).assertLarger(0);
      let firstPartialIndex: number = -1;
      let finalResultIndex: number = -1;
      bus.messages.forEach((message: AgentMessage, index: number): void => {
        if (firstPartialIndex < 0 && message.type === AgentMessageType.TASK_RESULT_DATA_PARTIAL) {
          firstPartialIndex = index;
        }
        if (finalResultIndex < 0 && message.type === AgentMessageType.TASK_RESULT_DATA) {
          finalResultIndex = index;
        }
      });
      expect(firstPartialIndex).assertLarger(-1);
      expect(finalResultIndex).assertLarger(firstPartialIndex);
      runtime.dispose();
    });

    it('settles a direct media task error after its streamed partial', 0, async () => {
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      const options = canaryOptions(
        new QueueModel([WATERFALL_MEDIA_DECISION, WATERFALL_MEDIA_DONE]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        [],
        bus
      );
      options.dataPlanner = undefined;
      options.dataExecutor = undefined;
      options.structuredToolCall = async (
        _toolId: string,
        _prompt: string,
        _args: Object,
        onPartial?: (result: DataResult) => void
      ): Promise<DataResult> => {
        expect(onPartial === undefined).assertFalse();
        if (onPartial !== undefined) {
          onPartial(waterfallMediaResult('partial', 'first-source'));
        }
        throw new Error('provider failed after partial');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        WATERFALL_MEDIA_QUERY,
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const uiErrors = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_RESULT_UI &&
          (message.payload as UiRenderResultPayload).state === 'error'
      );

      expect(bus.count(AgentMessageType.TASK_RESULT_DATA_PARTIAL)).assertEqual(1);
      expect(bus.count(AgentMessageType.TASK_ERROR)).assertEqual(1);
      expect(uiErrors.length).assertEqual(1);
      expect(bus.count(AgentMessageType.TURN_CANCEL)).assertEqual(0);
      expect(outcome.status).assertEqual('error');
      expect(outcome.message).assertEqual('Multi-agent UI rendering failed.');
      expect(outcome.surfaceId.length).assertLarger(0);
      runtime.dispose();
    });

    it('rejects malformed hotel schema at the registered adapter boundary', 0, async () => {
      const mutations: string[] = [
        SEARCH_INPUT.replace('"place":"深圳"', '"place":""'),
        SEARCH_INPUT.replace('2026-08-15', '2026-02-30'),
        SEARCH_INPUT.replace('2026-08-15', '26-08-15'),
        SEARCH_INPUT.replace('"adultCount":2', '"adultCount":0')
      ];
      for (let index = 0; index < mutations.length; index++) {
        const decision: string = HOTEL_DECISION.replace(SEARCH_INPUT, mutations[index]);
        const executor = new CanaryHotelExecutor();
        const bus = new TrackingBus();
        const runtime = new MultiAgentCanaryRuntime(canaryOptions(
          new QueueModel([decision]),
          executor,
          new RecordingOpener(),
          [],
          [],
          bus
        ));

        const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('error');
        expect(executor.calls.length).assertEqual(0);
        expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(1);
        runtime.dispose();
      }
    });

    it('executes one exact phone-local remember mutation', 0, async () => {
      const bus = new TrackingBus();
      const memory = new RecordingPhoneLocalMemoryRuntime();
      const sideEffects: LeaderMemoryToolResult[] = [];
      const options = canaryOptions(
        new QueueModel([MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.memoryRuntime = memory;
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => {
        sideEffects.push(result);
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('我只喝瑞幸咖啡', {
        text: '',
        previousPersonaId: 'food_companion'
      }) as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('success');
      expect(memory.rememberCalls.length).assertEqual(1);
      expect(sideEffects.length).assertEqual(1);
      expect(sideEffects[0].status).assertEqual('success');
      expect(memory.rememberCalls[0].personaTag).assertEqual('food_companion');
      expect(memory.rememberCalls[0].facts.join('|')).assertEqual('用户喝咖啡时只选择瑞幸。');
      expect(outcome.message).assertEqual('好的，我会按你的要求处理长期记忆。');
      expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(0);
      expect(bus.count(AgentMessageType.ACTION_RESULT)).assertEqual(0);
      runtime.dispose();
    });

    it('keeps the normal chat answer when its remember side effect fails', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime();
      memory.failRemember = true;
      let sideEffect: LeaderMemoryToolResult | null = null;
      const options = canaryOptions(
        new QueueModel([MEMORY_ANSWER_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => { sideEffect = result; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('以后我只喝瑞幸，也顺便说说你能做什么', {
        text: '', previousPersonaId: 'food_companion'
      }) as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('当然可以，瑞幸新品和价格我也可以继续帮你查。');
      expect(sideEffectStatus(sideEffect)).assertEqual('error');
      expect(memory.rememberCalls.length).assertEqual(1);
      runtime.dispose();
    });

    it('executes one two-record update mutation and reports partial without splitting the call', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-coffee', fact: '用户喝咖啡时不加糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-commute', fact: '用户通勤时偏好公交。',
        personaTag: 'travel_companion', authority: 'leader'
      }]);
      memory.failUpdateIndexes = [1];
      let sideEffect: LeaderMemoryToolResult | null = null;
      const options = canaryOptions(
        new QueueModel([MEMORY_BATCH_UPDATE_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => { sideEffect = result; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('咖啡改半糖，通勤改地铁', {
        text: '', previousPersonaId: 'food_companion'
      }) as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('好的，我会按你的要求处理长期记忆。');
      expect(sideEffectStatus(sideEffect)).assertEqual('partial');
      expect(memory.updateCalls.length).assertEqual(1);
      expect(memory.updateCalls[0].updates.length).assertEqual(2);
      expect(memory.updateCalls[0].updates[0].memoryId).assertEqual('memory-coffee');
      expect(memory.updateCalls[0].updates[1].memoryId).assertEqual('memory-commute');
      runtime.dispose();
    });

    it('reports persistence failure only through the memory side-effect channel', 0, async () => {
      const bus = new TrackingBus();
      const memory = new RecordingPhoneLocalMemoryRuntime();
      memory.failRemember = true;
      let sideEffect: LeaderMemoryToolResult | null = null;
      const options = canaryOptions(
        new QueueModel([MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.memoryRuntime = memory;
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => { sideEffect = result; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('我只喝瑞幸咖啡', {
        text: '',
        previousPersonaId: 'food_companion'
      }) as MultiAgentSettledOutcome;

      await flush();
      expect(outcome.status).assertEqual('success');
      expect(outcome.message).assertEqual('好的，我会按你的要求处理长期记忆。');
      expect(sideEffectStatus(sideEffect)).assertEqual('error');
      expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(0);
      runtime.dispose();
    });

    it('keeps ordinary session planning but hides and skips all memory capabilities when the model is absent', 0,
      async () => {
        const model = new QueueModel([ANSWER_DECISION]);
        const memory = new RecordingPhoneLocalMemoryRuntime();
        const options = canaryOptions(
          model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
        );
        options.memoryRuntime = memory;
        options.memoryAvailability = new StaticMemoryAvailability(false);
        const runtime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit('请记住，但模型文件缺失时正常回答', {
          text: '请记住，但模型文件缺失时正常回答',
          sessionSummary: '仍然保留的滚动会话摘要'
        }) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual('success');
        expect(memory.recallQueries.length).assertEqual(0);
        expect(memory.rememberCalls.length).assertEqual(0);
        expect(memory.forgetCalls.length).assertEqual(0);
        expect(model.systemPrompts[0].indexOf('memory.remember')).assertEqual(-1);
        expect(model.systemPrompts[0].indexOf('memory.update')).assertEqual(-1);
        expect(model.systemPrompts[0].indexOf('memory.forget')).assertEqual(-1);
        expect(model.systemPrompts[0].indexOf('memory.recall')).assertEqual(-1);
        expect(model.systemPrompts[0].indexOf('"skillId":"food-search"')).assertLarger(-1);
        expect(model.systemPrompts[0].indexOf('"toolIds":["food.search"]')).assertLarger(-1);
        expect(model.prompts[0].indexOf('[memory.recall Tool Observation]')).assertEqual(-1);
        expect(model.prompts[0].indexOf('memory.remember')).assertEqual(-1);
        expect(model.prompts[0].indexOf('memory.update')).assertEqual(-1);
        expect(model.prompts[0].indexOf('memory.forget')).assertEqual(-1);
        expect(model.prompts[0].indexOf('memory.recall')).assertEqual(-1);
        expect(model.prompts[0].indexOf('仍然保留的滚动会话摘要')).assertLarger(-1);
        expect(SESSION_COMPACTION_TOKEN_THRESHOLD).assertEqual(50000);
        expect(model.prompts.length).assertEqual(1);
        runtime.dispose();
      });

    it('keeps forget selection in an overlay across a new turn and confirms through the FIFO sidecar', 0,
      async () => {
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const sideEffects: LeaderMemoryToolResult[] = [];
      let hostGeneration: number = 7;
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-coffee-1',
        fact: '用户喝咖啡时选择半糖。',
        personaTag: 'food_companion',
        authority: 'leader'
      }, {
        memoryId: 'memory-coffee-2',
        fact: '用户喝咖啡时优先选择燕麦奶。',
        personaTag: 'food_companion',
        authority: 'leader'
      }]);
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION, ANSWER_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => hostGeneration;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => {
        overlay = request;
      };
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => {
        sideEffects.push(result);
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 7) as MultiAgentSettledOutcome;
      expect(outcome.memorySelection).assertEqual(undefined);
      expect(outcome.surfaceId).assertEqual('');
      expect(surfaces.length).assertEqual(0);
      expect(overlay === null).assertFalse();
      hostGeneration = 8;
      await runtime.submit('继续正常聊天', { text: '继续正常聊天' }, hostGeneration);
      expect(overlay === null).assertFalse();
      if (overlay === null) {
        runtime.dispose();
        return;
      }
      const selected = overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0, 1]);
      const selectedArgs = selected.args as MemoryCandidatesForgetActionArgs;
      const forgedArgs: MemoryCandidatesForgetActionArgs = {
        selectionId: selectedArgs.selectionId,
        revision: selectedArgs.revision,
        candidateKeys: ['forged-candidate']
      };
      const forged: A2uiAction = {
        id: selected.id, label: selected.label, prompt: selected.prompt,
        variant: selected.variant, kind: selected.kind, args: forgedArgs
      };
      const emptyArgs: MemoryCandidatesForgetActionArgs = {
        selectionId: selectedArgs.selectionId, revision: selectedArgs.revision, candidateKeys: []
      };
      const empty: A2uiAction = {
        id: selected.id, label: selected.label, prompt: selected.prompt,
        variant: selected.variant, kind: selected.kind, args: emptyArgs
      };
      const duplicateArgs: MemoryCandidatesForgetActionArgs = {
        selectionId: selectedArgs.selectionId, revision: selectedArgs.revision,
        candidateKeys: [selectedArgs.candidateKeys[0], selectedArgs.candidateKeys[0]]
      };
      const duplicate: A2uiAction = {
        id: selected.id, label: selected.label, prompt: selected.prompt,
        variant: selected.variant, kind: selected.kind, args: duplicateArgs
      };
      const staleArgs: MemoryCandidatesForgetActionArgs = {
        selectionId: selectedArgs.selectionId, revision: selectedArgs.revision + 1,
        candidateKeys: selectedArgs.candidateKeys.slice()
      };
      const stale: A2uiAction = {
        id: selected.id, label: selected.label, prompt: selected.prompt,
        variant: selected.variant, kind: selected.kind, args: staleArgs
      };
      const rejected = await runtime.handleMemoryCandidateAction(forged);
      const emptyRejected = await runtime.handleMemoryCandidateAction(empty);
      const duplicateRejected = await runtime.handleMemoryCandidateAction(duplicate);
      const staleRejected = await runtime.handleMemoryCandidateAction(stale);
      const deleted = await runtime.handleMemoryCandidateAction(selected);
      const replayed = await runtime.handleMemoryCandidateAction(selected);

      expect(rejected.status).assertEqual('rejected');
      expect(emptyRejected.status).assertEqual('rejected');
      expect(duplicateRejected.status).assertEqual('rejected');
      expect(staleRejected.status).assertEqual('rejected');
      expect(deleted.status).assertEqual('success');
      expect(replayed.status).assertEqual('rejected');
      expect(JSON.stringify(selected.args).indexOf('memoryId')).assertEqual(-1);
      expect(JSON.stringify(selected.args).indexOf('fact')).assertEqual(-1);
      expect(memory.forgetCalls.join(',')).assertEqual('memory-coffee-1,memory-coffee-2');
      expect(memory.forgetBatches.length).assertEqual(1);
      expect(memory.forgetBatches[0].join(',')).assertEqual('memory-coffee-1,memory-coffee-2');
      expect(sideEffects.length).assertEqual(0);
      expect(overlay === null).assertTrue();
      expect(surfaces.length).assertEqual(0);
      runtime.dispose();
    });

    it('keeps the forget overlay when its local delete fails', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-coffee-1', fact: '用户喝咖啡时选择半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-coffee-2', fact: '用户喝咖啡时优先选择燕麦奶。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      memory.failForget = true;
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 8;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 8);
      expect(surfaces.length).assertEqual(0);
      if (overlay !== null) {
        const result = await runtime.handleMemoryCandidateAction(
          overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0])
        );
        expect(result.status).assertEqual('error');
      }
      expect(overlay === null).assertFalse();
      expect(surfaces.length).assertEqual(0);
      runtime.dispose();
    });

    it('removes successful candidates once and keeps failed selected candidates retryable', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-coffee-1', fact: '用户喝咖啡时选择半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-coffee-2', fact: '用户喝咖啡时优先选择燕麦奶。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      memory.failForgetMemoryIds = ['memory-coffee-2'];
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 10;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 10);
      const result = overlay === null ? null :
        await runtime.handleMemoryCandidateAction(
          overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0, 1])
        );

      expect(result?.status).assertEqual('partial');
      expect(result?.message).assertEqual('已删除 1 条，1 条失败，可重试。');
      expect(memory.forgetCalls.join(',')).assertEqual('memory-coffee-1,memory-coffee-2');
      expect(memory.forgetBatches.length).assertEqual(1);
      expect(overlayCandidateCount(overlay)).assertEqual(1);
      expect(surfaces.length).assertEqual(0);
      runtime.dispose();
    });

    it('does not overwrite the current surface when an overlay delete completes', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const memory = new GatedForgetMemoryRuntime([{
        memoryId: 'memory-coffee-1', fact: '用户喝咖啡时选择半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-coffee-2', fact: '用户喝咖啡时优先选择燕麦奶。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 9;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 9);
      if (overlay === null) {
        runtime.dispose();
        return;
      }
      const pending = runtime.handleMemoryCandidateAction(
        overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0, 1])
      );
      await memory.forgetStarted.promise;
      const replacement = createSeedA2uiSurface();
      replacement.surfaceId = 'newer-surface';
      replacement.runtimeOwner = 'multi_agent';
      replacement.runtimeGeneration = 9;
      surfaces.push(replacement);
      memory.forgetRelease.open();
      const result = await pending;

      expect(result.status).assertEqual('success');
      expect(result.presented).assertTrue();
      expect(surfaces[surfaces.length - 1].surfaceId).assertEqual('newer-surface');
      expect(overlay === null).assertTrue();
      expect(memory.forgetCalls.join(',')).assertEqual('memory-coffee-1,memory-coffee-2');
      runtime.dispose();
    });

    it('consumes a partial forget selection when republishing the overlay fails', 0, async () => {
      let overlay: MemoryForgetOverlayRequest | null = null;
      let nonNullPublications: number = 0;
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-partial-a', fact: '用户喜欢半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-partial-b', fact: '用户喜欢燕麦奶。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      memory.failForgetMemoryIds = ['memory-partial-b'];
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 17;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => {
        if (request === null) {
          overlay = null;
          return;
        }
        nonNullPublications++;
        if (nonNullPublications > 1) throw new Error('overlay republish failed');
        overlay = request;
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 17);
      if (overlay === null) {
        runtime.dispose();
        return;
      }
      const action = overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0, 1]);
      const result = await runtime.handleMemoryCandidateAction(action);
      const replay = await runtime.handleMemoryCandidateAction(action);

      expect(result.status).assertEqual('partial');
      expect(result.presented).assertFalse();
      expect(result.notify).assertFalse();
      expect(overlay === null).assertTrue();
      expect(replay.status).assertEqual('rejected');
      expect(memory.forgetBatches.length).assertEqual(1);
      runtime.dispose();
    });

    it('cancels one in-flight forget batch when the memory owner changes', 0, async () => {
      let overlay: MemoryForgetOverlayRequest | null = null;
      const memory = new GatedForgetMemoryRuntime([{
        memoryId: 'memory-owner-1', fact: '用户偏好半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }, {
        memoryId: 'memory-owner-2', fact: '用户偏好燕麦奶。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 19;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 19);
      if (overlay === null) {
        runtime.dispose();
        return;
      }
      const pending = runtime.handleMemoryCandidateAction(
        overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0, 1])
      );
      await memory.forgetStarted.promise;
      runtime.invalidateMemoryOwner();
      memory.forgetRelease.open();
      const result = await pending;

      expect(result.status).assertEqual('rejected');
      expect(memory.forgetBatches.length).assertEqual(1);
      expect(memory.forgetCalls.length).assertEqual(0);
      expect(overlay === null).assertTrue();
      runtime.dispose();
    });

    it('clears a forget selection when its overlay observer rejects publication', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-overlay-failure', fact: '用户偏好半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      const options = canaryOptions(
        new QueueModel([MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 23;
      options.onMemoryForgetOverlay = (_request: MemoryForgetOverlayRequest | null): void => {
        throw new Error('overlay unavailable');
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('忘掉咖啡偏好', {
        text: '忘掉咖啡偏好'
      }, 23) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('error');
      expect(memory.forgetCalls.length).assertEqual(0);
      runtime.dispose();
    });

    it('does not let Action or a new turn wait for or cancel FIFO memory side effects', 0, async () => {
      const memory = new FifoGatedMemoryRuntime();
      const options = canaryOptions(
        new QueueModel([WORLDCUP_ACTION_WITH_MEMORY_DECISION, MEMORY_ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 41;
      options.pageAction = async (
        _actionId: string,
        _args: Object,
        _context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => ({
        status: 'success',
        output: JSON.parse('{"route":"pages/A2uiHome/AnythingDemo","status":"opened"}') as Object
      });
      const runtime = new MultiAgentCanaryRuntime(options);
      const first = runtime.submit('记住我关注世界杯并打开页面', { text: '' }, 41) as
        Promise<MultiAgentSettledOutcome>;
      await memory.firstStarted.promise;
      const actionOutcome = await first;
      const secondOutcome = await runtime.submit('也记住我只喝瑞幸并正常回答', {
        text: '', previousPersonaId: 'food_companion'
      }, 41) as MultiAgentSettledOutcome;

      expect(actionOutcome.status).assertEqual('success');
      expect(secondOutcome.status).assertEqual('success');
      expect(memory.startedFacts.length).assertEqual(1);
      expect(memory.guards.length).assertEqual(1);
      expect(memory.guards[0].isActive()).assertTrue();

      runtime.invalidateMemoryOwner();
      expect(memory.guards[0].isActive()).assertFalse();
      memory.firstRelease.open();
      await flush();
      expect(memory.rememberCalls.length).assertEqual(0);
      runtime.dispose();
    });

    it('does not enqueue a late memory side effect after owner invalidation', 0, async () => {
      const model = new GatedModel(MEMORY_DECISION);
      const memory = new RecordingPhoneLocalMemoryRuntime();
      const options = canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 31;
      const runtime = new MultiAgentCanaryRuntime(options);

      const pending = runtime.submit('记住我只喝瑞幸', { text: '记住我只喝瑞幸' }, 31) as
        Promise<MultiAgentSettledOutcome>;
      await model.started.promise;
      runtime.invalidateMemoryOwner();
      model.release.open();
      const outcome = await pending;
      await flush();

      expect(outcome.status).assertEqual('canceled');
      expect(memory.rememberCalls.length).assertEqual(0);
      runtime.dispose();
    });

    it('does not publish a late forget selection after owner invalidation', 0, async () => {
      const model = new GatedModel(MEMORY_FORGET_SELECTION_DECISION);
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-late-selection', fact: '用户喜欢半糖。',
        personaTag: 'food_companion', authority: 'leader'
      }]);
      let overlayPublications: number = 0;
      const options = canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 32;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => {
        if (request !== null) overlayPublications++;
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const pending = runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 32) as
        Promise<MultiAgentSettledOutcome>;
      await model.started.promise;
      runtime.invalidateMemoryOwner();
      model.release.open();
      const outcome = await pending;
      await flush();

      expect(outcome.status).assertEqual('canceled');
      expect(overlayPublications).assertEqual(0);
      expect(memory.forgetCalls.length).assertEqual(0);
      runtime.dispose();
    });

    it('keeps a successful business surface and settles partial when memory fails', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime();
      memory.failRemember = true;
      let sideEffect: LeaderMemoryToolResult | null = null;
      const surfaces: A2uiSurfaceState[] = [];
      const options = canaryOptions(
        new QueueModel([HOTEL_WITH_MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.memoryRuntime = memory;
      options.onMemorySideEffectResult = (result: LeaderMemoryToolResult): void => { sideEffect = result; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: SEARCH_TEXT }) as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('success');
      expect(outcome.surfaceId.length).assertLarger(0);
      expect(surfaces.length).assertLarger(0);
      expect(memory.rememberCalls.length).assertEqual(1);
      expect(sideEffectStatus(sideEffect)).assertEqual('error');
      runtime.dispose();
    });

    it('uses the Leader-selected persona only as remember metadata', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime();
      const options = canaryOptions(
        new QueueModel([MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit('以后多推荐 AI 视频', {
        text: '',
        previousPersonaId: 'food_companion'
      });

      expect(memory.rememberCalls.length).assertEqual(1);
      expect(memory.rememberCalls[0].personaTag).assertEqual('food_companion');
      runtime.dispose();
    });

    it('writes the normalized Leader fact instead of raw BIM prompt text', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime();
      const options = canaryOptions(
        new QueueModel([MEMORY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      const prompt = bimSnapshotPrompt('以后多推荐 AI 视频');
      await runtime.submit(prompt, {
        text: prompt,
        previousPersonaId: 'food_companion'
      });

      expect(memory.rememberCalls.length).assertEqual(1);
      expect(memory.rememberCalls[0].facts[0]).assertEqual('用户喝咖啡时只选择瑞幸。');
      expect(memory.rememberCalls[0].facts[0].indexOf('BIM_SNAPSHOTS')).assertEqual(-1);
      runtime.dispose();
    });

    it('drops a stale recall before it can submit an older Leader turn', 0, async () => {
      const memory = new GatedRecallMemoryRuntime();
      const options = canaryOptions(
        new QueueModel([ANSWER_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);
      const oldTurn = runtime.submit('older', { text: 'older' }) as Promise<MultiAgentSettledOutcome>;
      await memory.recallStarted.promise;
      const newTurn = runtime.submit('newer', { text: 'newer' }) as Promise<MultiAgentSettledOutcome>;
      memory.recallRelease.open();
      const olderOutcome = await oldTurn;
      const newerOutcome = await newTurn;

      expect(olderOutcome.status).assertEqual('canceled');
      expect(newerOutcome.status).assertEqual('success');
      runtime.dispose();
    });

    it('owns initial fixed Actions through the real Leader actionIntent path', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      const options = canaryOptions(
        new QueueModel([WORLDCUP_ACTION_DECISION, MAPS_ACTION_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.currentHostGeneration = (): number => 1;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"route":"pages/A2uiHome/AnythingDemo","status":"opened"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '打开世界杯页面', { text: '' }, 1
      ) as MultiAgentSettledOutcome;
      const mapsOutcome = await runtime.submit(
        '打开深圳北到香港西九龙的路线', { text: '' }, 1
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(mapsOutcome.status).assertEqual('success');
      expect(calls.length).assertEqual(2);
      expect(calls[0].actionId).assertEqual('worldcup.open');
      expect(JSON.stringify(calls[0].args)).assertEqual(
        '{"route":"pages/A2uiHome/AnythingDemo"}'
      );
      expect(calls[0].context.sourceToolId).assertEqual('virtual.action-intent');
      expect(calls[1].actionId).assertEqual('maps.route.open');
      expect(JSON.stringify(calls[1].args)).assertEqual(
        '{"origin":"深圳北","destination":"香港西九龙","travelMode":"driving","navigate":false}'
      );
      expect(calls[1].context.sourceToolId).assertEqual('virtual.action-intent');
      expect(bus.count(AgentMessageType.ACTION_PLAN_REQUEST)).assertEqual(2);
      expect(bus.count(AgentMessageType.ACTION_RESULT)).assertEqual(2);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
      runtime.dispose();
    });

    it('publishes one real terminal for a mixed Data and virtual Action turn', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      const options = canaryOptions(
        new QueueModel([MIXED_DATA_ACTION_DECISION]),
        new TwoToolExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.currentHostGeneration = (): number => 1;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"route":"pages/A2uiHome/AnythingDemo","status":"opened"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '查询明天北京到上海的出行方案并打开世界杯页面',
        { text: '' },
        1
      ) as MultiAgentSettledOutcome;
      const terminals = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TURN_RESULT
      );
      const terminal = terminals[0].payload as TurnResultPayload;

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('worldcup.open');
      expect(terminals.length).assertEqual(1);
      expect(terminal.roundCount).assertEqual(1);
      expect(terminal.surfaceId).assertEqual(outcome.surfaceId);
      runtime.dispose();
    });

    it('parses only one exact F07 Gmail recipient and nonempty body', 0, () => {
      const exact = resolveVirtualRegisteredPageAction(
        'gmail.draft.create',
        '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了'
      );
      const ambiguous = resolveVirtualRegisteredPageAction(
        'gmail.draft.create',
        '帮我用 Gmail 写一封邮件给 alice@example.com 和 bob@example.com，说我收到了'
      );
      const missingBody = resolveVirtualRegisteredPageAction(
        'gmail.draft.create',
        '帮我用 Gmail 写一封邮件给 alice@example.com'
      );
      const malformed = resolveVirtualRegisteredPageAction(
        'gmail.draft.create',
        '帮我用 Gmail 写一封邮件给 alice@@example.com，说我收到了'
      );

      expect(exact === null).assertFalse();
      expect(JSON.stringify(exact?.args)).assertEqual(
        '{"to":["alice@example.com"],"subject":"","body":"我收到了"}'
      );
      expect(ambiguous === null).assertTrue();
      expect(missingBody === null).assertTrue();
      expect(malformed === null).assertTrue();
    });

    it('keeps the current F07 candidate when a stale create arrives before apply', 0, async () => {
      const calls: RecordedPageAction[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let hostGeneration = 41;
      let providerResultCount = 0;
      let providerActionCount = -1;
      let providerRowsHaveDraftId = false;
      let emulateStalePageAction: boolean = false;
      let staleGenerationReads: number = 0;
      const options = canaryOptions(
        new QueueModel([GMAIL_DRAFT_CREATE_DECISION, GMAIL_DRAFT_APPLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => {
        if (!emulateStalePageAction) {
          return hostGeneration;
        }
        staleGenerationReads++;
        return staleGenerationReads <= 2 ? hostGeneration : hostGeneration + 1;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        let output: Object = JSON.parse('{"providerStatus":"exact"}') as Object;
        if (actionId === 'gmail.draft.create') {
          const createdSurface = providerGmailDraftSurface(
            hostGeneration,
            realComposioGmailDraftProviderResult()
          );
          createdSurface.sequence = 7;
          currentHost = createdSurface;
          output = registeredGmailDraftProviderOutput(createdSurface, context);
          const providerData = (output as RegisteredPageActionOutputFixture).data as A2uiRuntimeDataModel;
          providerResultCount = providerData.genericToolResults.length;
          const providerActions = providerData.genericToolResults[0].actions;
          providerActionCount = providerActions === undefined ? 0 : providerActions.length;
          providerRowsHaveDraftId =
            JSON.stringify(providerData.genericToolResults[0].rows).indexOf('draft-provider-1') >= 0;
        } else if (actionId === 'gmail.draft.apply') {
          const updated = pageSurface('gmail.draft.apply', {
            id: 'gmail.open.web',
            label: '跳转到Gmail',
            prompt: 'https://mail.google.com/mail/u/0/#drafts',
            variant: 'secondary',
            kind: 'client',
            args: JSON.parse('{"url":"https://mail.google.com/mail/u/0/#drafts"}') as Object
          }, hostGeneration);
          currentHost = updated;
          currentSnapshot = pageSnapshot(updated, 2);
        }
        return {
          status: 'success',
          output
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const created = await runtime.submit(
        '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了',
        { text: '' },
        hostGeneration
      ) as MultiAgentSettledOutcome;
      expect(currentHost === null).assertFalse();
      const providerSurface: A2uiSurfaceState = currentHost === null ?
        providerGmailDraftSurface(hostGeneration) : currentHost;
      const providerSurfaceJson = JSON.stringify(providerSurface);
      const terminalSurface = successfulGmailDraftTerminalSurface(providerSurface);
      currentHost = terminalSurface;
      const terminalSnapshot = pageSnapshot(terminalSurface, 2);
      const f07Document = terminalSnapshot.document;
      currentSnapshot = terminalSnapshot;
      const staleAction = resolveVirtualRegisteredPageAction(
        'gmail.draft.create',
        '帮我用 Gmail 写一封邮件给 bob@example.com，说稍后回复'
      );
      currentHost = pageSurface('gmail.thread.read', staleAction!, hostGeneration);
      currentSnapshot = pageSnapshot(currentHost, 3);
      emulateStalePageAction = true;
      const staleAccepted = await runtime.runPageAction(staleAction!);
      emulateStalePageAction = false;
      currentHost = terminalSurface;
      currentSnapshot = terminalSnapshot;
      hostGeneration = 42;
      const applied = await runtime.submit(
        '确认应用刚才的 Gmail 草稿',
        { text: '' },
        hostGeneration
      ) as MultiAgentSettledOutcome;
      const actions: HtmlHomeAction[] = f07Document === null ? [] : f07Document.actions.slice();
      if (f07Document !== null) {
        f07Document.blocks.forEach((block) => actions.push(...block.actions));
      }

      expect(created.status).assertEqual('success');
      expect(staleAccepted).assertFalse();
      expect(providerSurface.sequence).assertEqual(7);
      expect(terminalSurface.sequence).assertEqual(8);
      expect(JSON.stringify(terminalSurface) === providerSurfaceJson).assertFalse();
      expect(providerResultCount).assertEqual(1);
      expect(providerActionCount).assertEqual(0);
      expect(providerRowsHaveDraftId).assertTrue();
      expect(terminalSnapshot.document.source === 'pending').assertFalse();
      expect(terminalSnapshot.document.actions.length +
        terminalSnapshot.document.blocks.length).assertLarger(0);
      expect(applied.status).assertEqual('success');
      expect(calls.length).assertEqual(2);
      expect(calls[0].actionId).assertEqual('gmail.draft.create');
      expect(JSON.stringify(calls[0].args)).assertEqual(
        '{"to":["alice@example.com"],"subject":"","body":"我收到了"}'
      );
      expect(calls[1].actionId).assertEqual('gmail.draft.apply');
      expect(JSON.stringify(calls[1].args)).assertEqual(
        '{"provider":"composio","draftId":"draft-provider-1","to":["alice@example.com"],' +
          '"subject":"","body":"我收到了","threadId":""}'
      );
      expect(actions.filter((action): boolean =>
        action.id === 'gmail.draft.apply'
      ).length).assertEqual(1);
      expect(actions.filter((action): boolean =>
        action.id === 'gmail.open.web'
      ).length).assertEqual(1);
      expect(calls.filter((call: RecordedPageAction): boolean =>
        call.actionId === 'gmail.draft.create'
      ).length).assertEqual(1);
      expect(calls.filter((call: RecordedPageAction): boolean =>
        call.actionId === 'gmail.message.send'
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('keeps the current F07 candidate when a submit origin is invalid or stale', 0, async () => {
      const cases: string[] = ['missing', 'invalid', 'positive_stale'];
      for (let caseIndex = 0; caseIndex < cases.length; caseIndex++) {
        const caseId = cases[caseIndex];
        const calls: RecordedPageAction[] = [];
        let currentHost: A2uiSurfaceState | null = null;
        let currentSnapshot: RegisteredPageSnapshot | null = null;
        let hostGeneration = 41;
        const options = canaryOptions(
          new QueueModel([
            GMAIL_DRAFT_CREATE_DECISION,
            GMAIL_DRAFT_CREATE_DECISION,
            GMAIL_DRAFT_APPLY_DECISION
          ]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
        options.currentHostGeneration = (): number => hostGeneration;
        options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
        options.pageAction = async (
          actionId: string,
          args: Object,
          context: ActionExecutionContext
        ): Promise<ActionExecutionResult> => {
          calls.push({ actionId, args, context });
          let output: Object = JSON.parse('{"providerStatus":"exact"}') as Object;
          if (actionId === 'gmail.draft.create') {
            const createdSurface = providerGmailDraftSurface(hostGeneration);
            currentHost = createdSurface;
            output = registeredGmailDraftProviderOutput(createdSurface, context);
          }
          return { status: 'success', output };
        };
        const runtime = new MultiAgentCanaryRuntime(options);

        const created = await runtime.submit(
          '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了',
          { text: '' },
          hostGeneration
        ) as MultiAgentSettledOutcome;
        const providerSurface: A2uiSurfaceState = currentHost === null ?
          providerGmailDraftSurface(hostGeneration) : currentHost;
        currentHost = successfulGmailDraftTerminalSurface(providerSurface);
        currentSnapshot = pageSnapshot(currentHost, 2);
        hostGeneration = caseId === 'positive_stale' ? 42 : 1;
        const rejected = caseId === 'missing' ?
          await runtime.submit(
            '帮我用 Gmail 写一封邮件给 bob@example.com，说稍后回复',
            { text: '' }
          ) as MultiAgentSettledOutcome : caseId === 'invalid' ?
          await runtime.submit(
            '帮我用 Gmail 写一封邮件给 bob@example.com，说稍后回复',
            { text: '' },
            -1
          ) as MultiAgentSettledOutcome :
          await runtime.submit(
            '帮我用 Gmail 写一封邮件给 bob@example.com，说稍后回复',
            { text: '' },
            41
          ) as MultiAgentSettledOutcome;
        const callsAfterRejected = calls.length;
        hostGeneration = 42;
        const applied = await runtime.submit(
          '确认应用刚才的 Gmail 草稿',
          { text: '' },
          hostGeneration
        ) as MultiAgentSettledOutcome;

        expect(created.status).assertEqual('success');
        expect(rejected.status).assertEqual('error');
        expect(callsAfterRejected).assertEqual(1);
        expect(applied.status).assertEqual('success');
        expect(calls.length).assertEqual(2);
        expect(calls[1].actionId).assertEqual('gmail.draft.apply');
        runtime.dispose();
      }
    });

    it('rejects F08 for a fresh runtime with only a preseeded Gmail draft surface', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      const hostGeneration = 41;
      const applyArgs = JSON.parse(
        '{"provider":"gmail_oauth","draftId":"draft-provider-1","threadId":"thread-provider-1",' +
          '"to":["alice@example.com"],"subject":"Provider draft subject","body":"我收到了"}'
      ) as Object;
      const applyAction: A2uiAction = {
        id: 'gmail.draft.apply',
        label: '应用 Gmail 草稿',
        prompt: '确认应用刚才的 Gmail 草稿',
        variant: 'primary',
        kind: 'prompt',
        args: applyArgs
      };
      const options = canaryOptions(
        new QueueModel([GMAIL_DRAFT_APPLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      const currentHost = pageSurface('gmail.draft.create', applyAction, hostGeneration);
      const currentSnapshot = pageSnapshot(currentHost, 1);
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => hostGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"providerStatus":"exact"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const applied = await runtime.submit(
        '确认应用刚才的 Gmail 草稿',
        { text: '' },
        hostGeneration
      ) as MultiAgentSettledOutcome;

      expect(applied.status).assertEqual('error');
      expect(calls.length).assertEqual(0);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(0);
      runtime.dispose();
    });

    it('rejects F08 when the retained F07 snapshot and current host differ', 0, async () => {
      const calls: RecordedPageAction[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let hostGeneration = 41;
      const options = canaryOptions(
        new QueueModel([GMAIL_DRAFT_CREATE_DECISION, GMAIL_DRAFT_APPLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => hostGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        let output: Object = JSON.parse('{"providerStatus":"exact"}') as Object;
        if (actionId === 'gmail.draft.create') {
          const createdSurface = providerGmailDraftSurface(hostGeneration);
          currentHost = createdSurface;
          currentSnapshot = pageSnapshot(createdSurface, 1);
          output = registeredPageActionOutput(actionId, createdSurface, context);
        }
        return {
          status: 'success',
          output
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const created = await runtime.submit(
        '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了',
        { text: '' },
        hostGeneration
      ) as MultiAgentSettledOutcome;
      currentHost = JSON.parse(JSON.stringify(currentHost)) as A2uiSurfaceState;
      currentHost.title = 'forged-current-host';
      hostGeneration = 42;
      const applied = await runtime.submit(
        '确认应用刚才的 Gmail 草稿',
        { text: '' },
        hostGeneration
      ) as MultiAgentSettledOutcome;

      expect(created.status).assertEqual('success');
      expect(applied.status).assertEqual('error');
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('gmail.draft.create');
      runtime.dispose();
    });

    it('rejects invalid F07 provider data and delayed rendered Gmail authority mismatches', 0, async () => {
      const cases: string[] = [
        'provider_failed',
        'provider_zero',
        'provider_two',
        'draft_id_invalid',
        'provider_invalid',
        'original_args_invalid',
        'snapshot_missing',
        'snapshot_pending',
        'rendered_surface_different',
        'rendered_status_different',
        'rendered_generation_stale',
        'rendered_action_missing',
        'rendered_action_tampered',
        'skip_generation'
      ];
      for (let caseIndex = 0; caseIndex < cases.length; caseIndex++) {
        const caseId = cases[caseIndex];
        const calls: RecordedPageAction[] = [];
        let currentHost: A2uiSurfaceState | null = null;
        let currentSnapshot: RegisteredPageSnapshot | null = null;
        let hostGeneration = 41;
        const options = canaryOptions(
          new QueueModel([GMAIL_DRAFT_CREATE_DECISION, GMAIL_DRAFT_APPLY_DECISION]),
          new CanaryHotelExecutor(),
          new RecordingOpener(),
          [],
          []
        );
        options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
        options.currentHostGeneration = (): number => hostGeneration;
        options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
        options.pageAction = async (
          actionId: string,
          args: Object,
          context: ActionExecutionContext
        ): Promise<ActionExecutionResult> => {
          calls.push({ actionId, args, context });
          const createdSurface = providerGmailDraftSurface(hostGeneration);
          const renderedData = JSON.parse(createdSurface.dataModelJson) as A2uiRuntimeDataModel;
          const renderedActions = renderedData.genericToolResults[0].actions as A2uiAction[];
          if (caseId === 'rendered_action_missing') {
            renderedData.genericToolResults[0].actions = [];
          } else if (caseId === 'rendered_action_tampered') {
            const renderedArgs = renderedActions[0].args as
              Record<string, Object | string | number | boolean | null | undefined>;
            renderedArgs['draftId'] = 'draft-rendered-tampered';
          }
          createdSurface.dataModelJson = JSON.stringify(renderedData);
          currentHost = createdSurface;
          const output = registeredGmailDraftProviderOutput(createdSurface, context);
          const data = output.data as A2uiRuntimeDataModel;
          if (caseId === 'provider_failed') {
            data.genericToolResults[0].status = 'error';
          } else if (caseId === 'provider_zero') {
            data.genericToolResults = [];
          } else if (caseId === 'provider_two') {
            data.genericToolResults.push(
              JSON.parse(JSON.stringify(data.genericToolResults[0]))
            );
          } else if (caseId === 'draft_id_invalid') {
            data.genericToolResults[0].rows = data.genericToolResults[0].rows.filter((row): boolean =>
              row.label !== 'Draft ID'
            );
            data.genericToolResults[0].rawPreview = '{}';
          } else if (caseId === 'provider_invalid') {
            data.genericToolResults[0].sourceTag = 'Unknown provider';
          } else if (caseId === 'original_args_invalid') {
            const originalArgs = args as
              Record<string, Object | string | number | boolean | null | undefined>;
            originalArgs['body'] = '';
          }
          return { status: 'success', output };
        };
        const runtime = new MultiAgentCanaryRuntime(options);

        const created = await runtime.submit(
          '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了',
          { text: '' },
          hostGeneration
        ) as MultiAgentSettledOutcome;
        const providerSurface = currentHost === null ?
          providerGmailDraftSurface(hostGeneration) : currentHost;
        currentHost = successfulGmailDraftTerminalSurface(providerSurface);
        currentSnapshot = pageSnapshot(currentHost, 2);
        if (caseId === 'snapshot_missing') {
          currentSnapshot = null;
        } else if (caseId === 'snapshot_pending') {
          currentSnapshot = pendingPageSnapshot(
            currentHost,
            3,
            '确认应用刚才的 Gmail 草稿'
          );
        } else if (caseId === 'rendered_surface_different') {
          currentHost.surfaceId = 'forged-gmail-surface';
          currentSnapshot = pageSnapshot(currentHost, 3);
        } else if (caseId === 'rendered_status_different') {
          currentHost.status = 'working';
          currentSnapshot = pageSnapshot(currentHost, 3);
        } else if (caseId === 'rendered_generation_stale') {
          currentHost.runtimeGeneration = 40;
          currentSnapshot = pageSnapshot(currentHost, 3);
        }
        hostGeneration = caseId === 'skip_generation' ? 43 : 42;
        const applied = await runtime.submit(
          '确认应用刚才的 Gmail 草稿',
          { text: '' },
          hostGeneration
        ) as MultiAgentSettledOutcome;

        expect(created.status).assertEqual('success');
        expect(applied.status).assertEqual('error');
        expect(calls.length).assertEqual(1);
        expect(calls[0].actionId).assertEqual('gmail.draft.create');
        expect(calls.filter((call): boolean =>
          call.actionId === 'gmail.message.send'
        ).length).assertEqual(0);
        runtime.dispose();
      }
    });

    it('rejects F08 when the Gmail draft host generation is stale', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const args = JSON.parse(
        '{"provider":"gmail_oauth","draftId":"draft-provider-2","threadId":"thread-provider-2",' +
          '"to":["alice@example.com"],"subject":"QA","body":"Exact"}'
      ) as Object;
      const action: A2uiAction = {
        id: 'gmail.draft.apply',
        label: '应用 Gmail 草稿',
        prompt: '确认应用刚才的 Gmail 草稿',
        variant: 'primary',
        kind: 'prompt',
        args
      };
      const surface = pageSurface('gmail.draft.create', action, 9);
      const options = canaryOptions(
        new QueueModel([GMAIL_DRAFT_APPLY_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentHostSurface = (): A2uiSurfaceState | null => surface;
      options.currentHostGeneration = (): number => 10;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => pageSnapshot(surface, 1);
      options.pageAction = async (
        actionId: string,
        pageArgs: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args: pageArgs, context });
        return { status: 'success', output: new Object() };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '确认应用刚才的 Gmail 草稿',
        { text: '' },
        10
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('error');
      expect(calls.length).assertEqual(0);
      runtime.dispose();
    });

    it('renders an exact Calendar create review and calls the provider only after the current click', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      const calls: RecordedPageAction[] = [];
      let current: RegisteredPageSnapshot | null = null;
      let generation = 0;
      const options = canaryOptions(
        new QueueModel([CALENDAR_CREATE_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (surface: A2uiSurfaceState): boolean => {
        surfaces.push(surface);
        generation++;
        current = {
          surface,
          document: createHtmlHomeDocument({
            surface,
            messages: [],
            isBusy: false,
            isAwaitingFirstSurface: false
          }),
          generation
        };
        return true;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '帮我在 2026年7月30日下午3点创建一个title为AIPhoneDemo的30分钟日程',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const exact = renderedAction(surfaces[surfaces.length - 1], 'calendar.event.create');
      const forged = JSON.parse(JSON.stringify(exact)) as A2uiAction;
      (forged.args as Record<string, Object | string | number | boolean | null | undefined>)['title'] = '伪造标题';

      expect(outcome.status).assertEqual('success');
      expect(calls.length).assertEqual(0);
      expect(exact === null).assertFalse();
      expect(await runtime.runPageAction(forged)).assertFalse();
      expect(await runtime.runPageAction(exact as A2uiAction)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('calendar.event.create');
      expect(calls[0].context.pageActionId).assertEqual('calendar.event.create');
      current = null;
      expect(await runtime.runPageAction(exact as A2uiAction)).assertFalse();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('uses one Leader-owned date snapshot for a relative Calendar action', 0, async () => {
      const surfaces: A2uiSurfaceState[] = [];
      let dateCalls: number = 0;
      const options = canaryOptions(
        new QueueModel([CALENDAR_CREATE_DECISION]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.currentLocalDate = (): string => {
        dateCalls++;
        return dateCalls === 1 ? '2026-07-21' : '2030-01-01';
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '帮我在明天下午3点创建一个title为AIPhoneDemo的30分钟日程',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const exact = renderedAction(surfaces[surfaces.length - 1], 'calendar.event.create');

      expect(outcome.status).assertEqual('success');
      expect(exact === null).assertFalse();
      expect(JSON.stringify((exact as A2uiAction).args).indexOf('2026-07-22')).assertLarger(-1);
      expect(dateCalls).assertEqual(1);
      runtime.dispose();
    });

    it('binds Calendar update to one real search event before review and never trusts a model eventId', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-real-1']);
      const model = new QueueModel([CALENDAR_UPDATE_SEARCH_DECISION, CALENDAR_UPDATE_DONE_DECISION]);
      const surfaces: A2uiSurfaceState[] = [];
      const calls: RecordedPageAction[] = [];
      let current: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (surface: A2uiSurfaceState): boolean => {
        surfaces.push(surface);
        current = {
          surface,
          document: createHtmlHomeDocument({
            surface,
            messages: [],
            isBusy: false,
            isAwaitingFirstSurface: false
          }),
          generation: 1
        };
        return true;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '把 2026年7月30日 的 Appless QA run-1 日程改到下午4点',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const review = renderedAction(surfaces[surfaces.length - 1], 'calendar.event.update');
      const taskJson = JSON.stringify(executor.tasks[0].args);

      expect(outcome.status).assertEqual('success');
      expect(review === null).assertFalse();
      expect(model.systemPrompts[0].indexOf(
        'Calendar update contract: for a natural-language update or move without a real Event ID'
      )).assertLarger(-1);
      expect(executor.tasks[0].toolId).assertEqual('calendar.events.search');
      expect(taskJson.indexOf('model-forged')).assertEqual(-1);
      expect(JSON.stringify((review as A2uiAction).args).indexOf('event-provider-real-1')).assertLarger(-1);
      expect(calls.length).assertEqual(0);
      expect(await runtime.runPageAction(review as A2uiAction)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('calendar.event.update');
      expect(JSON.stringify(calls[0].args).indexOf('event-provider-real-1')).assertLarger(-1);
      runtime.dispose();
    });

    it('repairs the device-observed premature C19c update action into the existing read-first flow', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-real-1']);
      const model = new QueueModel([
        CALENDAR_UPDATE_PREMATURE_ACTION_MISMATCH_DECISION,
        CALENDAR_UPDATE_REPAIRED_SEARCH_DECISION,
        CALENDAR_UPDATE_DONE_DECISION
      ]);
      const surfaces: A2uiSurfaceState[] = [];
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        surfaces,
        []
      ));

      const outcome = await runtime.submit(
        '把 2026年7月31日 的产品评审日程改到下午4点',
        { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('calendar.events.search');
      expect(model.prompts.length).assertEqual(3);
      expect(model.prompts[1].indexOf('LEADER_PREMATURE_CALENDAR_UPDATE_ACTION')).assertLarger(-1);
      expect(renderedAction(
        surfaces[surfaces.length - 1], 'calendar.event.update'
      ) === null).assertFalse();
      runtime.dispose();
    });

    it('repairs the device-observed later C19c update action into the existing review surface', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-real-1']);
      const model = new QueueModel([
        CALENDAR_UPDATE_SEARCH_DECISION,
        CALENDAR_UPDATE_PREMATURE_LATER_ACTION_DECISION,
        CALENDAR_UPDATE_REPAIRED_DONE_DECISION
      ]);
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls: number = 0;
      const options = canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.pageAction = async (): Promise<ActionExecutionResult> => {
        providerCalls++;
        return { status: 'success', output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '把 2026年7月31日 的产品评审日程改到下午4点',
        { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.tasks.length).assertEqual(1);
      expect(model.prompts.length).assertEqual(3);
      expect(model.prompts[2].indexOf(
        'LEADER_PREMATURE_CALENDAR_UPDATE_AFTER_SEARCH'
      )).assertLarger(-1);
      expect(renderedAction(
        surfaces[surfaces.length - 1], 'calendar.event.update'
      ) === null).assertFalse();
      expect(providerCalls).assertEqual(0);
      runtime.dispose();
    });

    it('rejects a zero-Data Calendar update decision without host semantic replacement', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-real-1']);
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls: number = 0;
      const options = canaryOptions(
        new QueueModel([CALENDAR_UPDATE_DIRECT_DECISION]), executor, new RecordingOpener(), surfaces, []
      );
      options.pageAction = async (): Promise<ActionExecutionResult> => {
        providerCalls++;
        return { status: 'success', output: JSON.parse('{"eventId":"event-provider-real-1"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '把 2026年7月30日 的 Appless QA run-1 日程改到下午4点', { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('error');
      expect(executor.tasks.length).assertEqual(0);
      expect(providerCalls).assertEqual(0);
      expect(surfaces.some((surface: A2uiSurfaceState): boolean =>
        surface.intent === 'calendar.event.update')).assertFalse();
      runtime.dispose();
    });

    it('searches C19e first and binds delete confirmation only to the exact provider event', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-delete-1']);
      const model = new QueueModel([CALENDAR_DELETE_SEARCH_DECISION, CALENDAR_DELETE_DONE_DECISION]);
      const surfaces: A2uiSurfaceState[] = [];
      const calls: RecordedPageAction[] = [];
      let current: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (surface: A2uiSurfaceState): boolean => {
        surfaces.push(surface);
        current = pageSnapshot(surface, surfaces.length);
        return true;
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"eventId":"event-provider-delete-1","status":"deleted"}') as Object
        };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '删除 2026年7月30日 标题为 Appless QA run-1 的 Google Calendar 日程',
        { text: '' }
      ) as MultiAgentSettledOutcome;
      const exact = renderedAction(
        surfaces[surfaces.length - 1], 'calendar.event.delete.confirm'
      );
      const taskJson = JSON.stringify(executor.tasks[0]);
      expect(exact === null).assertFalse();
      if (exact === null) {
        runtime.dispose();
        return;
      }
      const forged = JSON.parse(JSON.stringify(exact)) as A2uiAction;
      (forged.args as Record<string, Object | string | number | boolean | null | undefined>)['eventId'] =
        'event-model-forged';

      expect(outcome.status).assertEqual('success');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('calendar.events.search');
      expect(model.systemPrompts[0].indexOf(
        'Calendar delete contract: for a natural-language delete without a real Event ID'
      )).assertLarger(-1);
      expect(taskJson.indexOf('Appless QA run-1')).assertLarger(-1);
      expect(taskJson.indexOf('2026-07-30T00:00:00+08:00')).assertLarger(-1);
      expect(taskJson.indexOf('2026-07-31T00:00:00+08:00')).assertLarger(-1);
      expect(taskJson.indexOf('model-forged')).assertEqual(-1);
      expect(JSON.stringify(exact.args).indexOf('event-provider-delete-1'))
        .assertLarger(-1);
      expect(calls.length).assertEqual(0);
      expect(await runtime.runPageAction(forged)).assertFalse();
      expect(calls.length).assertEqual(0);
      expect(await runtime.runPageAction(exact)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('calendar.event.delete');
      expect(calls[0].context.pageActionId).assertEqual('calendar.event.delete.confirm');
      expect(JSON.stringify(calls[0].args).indexOf('event-provider-delete-1')).assertLarger(-1);
      current = null;
      expect(await runtime.runPageAction(exact)).assertFalse();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('repairs a premature C19e delete action after search into the existing review surface', 0, async () => {
      const executor = new CalendarUpdateExecutor(['event-provider-delete-1']);
      const model = new QueueModel([
        CALENDAR_DELETE_SEARCH_DECISION,
        CALENDAR_DELETE_PREMATURE_ACTION_DECISION,
        CALENDAR_DELETE_REPAIRED_DONE_DECISION
      ]);
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls = 0;
      const options = canaryOptions(
        model,
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.pageAction = async (): Promise<ActionExecutionResult> => {
        providerCalls++;
        return { status: 'success', output: JSON.parse('{"status":"deleted"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(
        '删除 2026年7月30日 标题为 Appless QA run-1 的 Google Calendar 日程',
        { text: '' }
      ) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(executor.tasks.length).assertEqual(1);
      expect(executor.tasks[0].toolId).assertEqual('calendar.events.search');
      expect(model.prompts.length).assertEqual(3);
      expect(renderedAction(
        surfaces[surfaces.length - 1], 'calendar.event.delete.confirm'
      ) === null).assertFalse();
      expect(providerCalls).assertEqual(0);
      runtime.dispose();
    });

    it('does not offer C19e delete for zero or multiple provider matches', 0, async () => {
      const matches: string[][] = [[], ['event-provider-delete-1', 'event-provider-delete-2']];
      for (let index = 0; index < matches.length; index++) {
        const surfaces: A2uiSurfaceState[] = [];
        let providerCalls = 0;
        const options = canaryOptions(
          new QueueModel([CALENDAR_DELETE_SEARCH_DECISION, CALENDAR_DELETE_DONE_DECISION]),
          new CalendarUpdateExecutor(matches[index]),
          new RecordingOpener(),
          surfaces,
          []
        );
        options.pageAction = async (): Promise<ActionExecutionResult> => {
          providerCalls++;
          return { status: 'success', output: JSON.parse('{"status":"deleted"}') as Object };
        };
        const runtime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit(
          '删除 2026年7月30日 标题为 Appless QA run-1 的 Google Calendar 日程',
          { text: '' }
        ) as MultiAgentSettledOutcome;

        expect(outcome.status).assertEqual(matches[index].length === 0 ? 'empty' : 'success');
        expect(renderedAction(
          surfaces[surfaces.length - 1], 'calendar.event.delete.confirm'
        )).assertNull();
        expect(providerCalls).assertEqual(0);
        runtime.dispose();
      }
    });

    it('cancels Calendar create planning before review without a provider call or late surface', 0, async () => {
      const model = new GatedModel(CALENDAR_CREATE_DECISION);
      const surfaces: A2uiSurfaceState[] = [];
      let providerCalls = 0;
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        surfaces,
        []
      );
      options.pageAction = async (): Promise<ActionExecutionResult> => {
        providerCalls++;
        return { status: 'success', output: JSON.parse('{"eventId":"unexpected"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const pending = runtime.submit(
        '创建日程；标题：产品评审；时间：2026-07-30 15:00 至 2026-07-30 15:30',
        { text: '' }
      );
      await model.started.promise;
      runtime.cancelActiveTurn('user_cancel');
      model.release.open();
      const outcome = await pending as MultiAgentSettledOutcome;
      await flush();

      expect(outcome.status).assertEqual('canceled');
      expect(surfaces.length).assertEqual(0);
      expect(providerCalls).assertEqual(0);
      runtime.dispose();
    });

    it('recalls a newly saved phone-local fact on the next turn', 0, async () => {
      const model = new MemoryAwareModel();
      const memory = new RecordingPhoneLocalMemoryRuntime();
      memory.persistRememberedFacts = true;
      const options = canaryOptions(
        model,
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);
      const remembered = await runtime.submit('我只喝瑞幸咖啡', {
        text: '', previousPersonaId: 'travel_companion'
      }) as MultiAgentSettledOutcome;
      const continued = await runtime.submit('继续', {
        text: '', previousPersonaId: 'travel_companion'
      }) as MultiAgentSettledOutcome;

      expect(remembered.status).assertEqual('success');
      expect(continued.status).assertEqual('success');
      expect(continued.message).assertEqual('已按更新后的瑞幸偏好继续');
      expect(memory.recallQueries.length).assertEqual(2);
      expect(model.prompts.length).assertEqual(2);
      expect(model.secondTurnUsedRecalledMemory).assertTrue();
      runtime.dispose();
    });

    it('prefetches ranked items without scores then permits one manual recall without consuming a business round', 0,
      async () => {
        const model = new QueueModel([MANUAL_RECALL_DECISION, ANSWER_DECISION]);
        const memory = new RecordingPhoneLocalMemoryRuntime([{
          memoryId: 'memory-coffee', fact: '用户喝咖啡时只选择瑞幸。',
          personaTag: 'food_companion', authority: 'leader'
        }]);
        const bus = new TrackingBus();
        const options = canaryOptions(
          model, new CanaryHotelExecutor(), new RecordingOpener(), [], [], bus
        );
        options.memoryRuntime = memory;
        const runtime = new MultiAgentCanaryRuntime(options);

        const outcome = await runtime.submit('这些记忆呢', {
          text: '这些记忆呢',
          recentMessages: [{ role: 'user', content: '刚才说的饮食习惯' }]
        }) as MultiAgentSettledOutcome;
        const terminals = bus.messages.filter((message: AgentMessage): boolean =>
          message.type === AgentMessageType.TURN_RESULT
        );
        const terminal = terminals[terminals.length - 1].payload as TurnResultPayload;

        expect(outcome.status).assertEqual('success');
        expect(outcome.personaId).assertEqual('default_companion');
        expect(memory.recallQueries.length).assertEqual(2);
        expect(memory.recallQueries[0]).assertEqual('这些记忆呢');
        expect(memory.recallQueries[0].indexOf('刚才说的饮食习惯')).assertEqual(-1);
        expect(memory.recallQueries[1]).assertEqual('咖啡 饮食偏好');
        expect(memory.recallTopKs.join(',')).assertEqual('5,5');
        expect(model.prompts[0].indexOf('"origin":"prefetch"')).assertLarger(-1);
        expect(model.prompts[0].indexOf('"score"')).assertEqual(-1);
        expect(model.prompts[1].indexOf('"origin":"leader"')).assertLarger(-1);
        expect(terminal.roundCount).assertEqual(1);
        runtime.dispose();
      });

    it('keeps prefetch at five and passes an explicit topK ten through manual recall observation', 0, async () => {
      const recalled: PhoneLocalRecalledMemory[] = [];
      for (let index = 0; index < 10; index += 1) {
        recalled.push({
          memoryId: 'memory-top-k-' + index.toString(),
          fact: '召回偏好 ' + index.toString(),
          personaTag: 'food_companion',
          authority: 'leader'
        });
      }
      const model = new QueueModel([MANUAL_RECALL_TEN_DECISION, ANSWER_DECISION]);
      const memory = new RecordingPhoneLocalMemoryRuntime(recalled);
      const options = canaryOptions(model, new CanaryHotelExecutor(), new RecordingOpener(), [], []);
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('这些记忆呢', { text: '这些记忆呢' }) as MultiAgentSettledOutcome;
      const prefetchObservation = recallObservationFromPrompt(model.prompts[0]);
      const manualObservation = recallObservationFromPrompt(model.prompts[1]);

      expect(outcome.status).assertEqual('success');
      expect(memory.recallTopKs.join(',')).assertEqual('5,10');
      expect(prefetchObservation.items.length).assertEqual(5);
      expect(manualObservation.items.length).assertEqual(10);
      runtime.dispose();
    });

    it('keeps a prefetch provenance query longer than the manual 240-char limit', 0, async () => {
      const longQuery: string = '长'.repeat(241);
      const model = new QueueModel([ANSWER_DECISION]);
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-long-query', fact: '用户偏好简洁回答。',
        personaTag: 'work_companion', authority: 'leader'
      }]);
      const options = canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(longQuery, { text: longQuery }) as MultiAgentSettledOutcome;
      const observation = recallObservationFromPrompt(model.prompts[0]);

      expect(outcome.status).assertEqual('success');
      expect(memory.recallQueries[0]).assertEqual(longQuery);
      expect(observation.callId.indexOf('memory-recall-prefetch-')).assertEqual(0);
      expect(observation.query).assertEqual(longQuery);
      expect(observation.items.length).assertEqual(1);
      expect(model.prompts[0].indexOf('legacy-prefetch')).assertEqual(-1);
      runtime.dispose();
    });

    it('searches the full prefetch query while bounding model-visible provenance to 2000 chars', 0, async () => {
      const longQuery: string = '界'.repeat(2000) + '检索尾部';
      const model = new QueueModel([ANSWER_DECISION]);
      const memory = new RecordingPhoneLocalMemoryRuntime([{
        memoryId: 'memory-bounded-query', fact: '用户偏好本地检索。',
        personaTag: 'work_companion', authority: 'leader'
      }]);
      const options = canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(longQuery, { text: longQuery }) as MultiAgentSettledOutcome;
      const observation = recallObservationFromPrompt(model.prompts[0]);

      expect(outcome.status).assertEqual('success');
      expect(memory.recallQueries[0]).assertEqual(longQuery);
      expect(observation.query.length).assertEqual(2000);
      expect(observation.query).assertEqual(longQuery.substring(0, 2000));
      expect(observation.items.length).assertEqual(1);
      expect(model.prompts[0].indexOf('legacy-prefetch')).assertEqual(-1);
      runtime.dispose();
    });

    it('uses only final manual recall candidates for a subsequent forget selection', 0, async () => {
      const prefetch: PhoneLocalRecalledMemory = {
        memoryId: 'memory-prefetch-a', fact: '用户以前偏好美式咖啡。',
        personaTag: 'food_companion', authority: 'leader'
      };
      const refined: PhoneLocalRecalledMemory = {
        memoryId: 'memory-manual-b', fact: '用户现在偏好燕麦拿铁。',
        personaTag: 'food_companion', authority: 'leader'
      };
      const memory = new SequencedRecallMemoryRuntime([[prefetch], [refined]]);
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const options = canaryOptions(
        new QueueModel([MANUAL_RECALL_DECISION, MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 12;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }, 12) as
        MultiAgentSettledOutcome;
      expect(outcome.memorySelection).assertEqual(undefined);
      expect(overlayCandidateCount(overlay)).assertEqual(1);
      expect(surfaces.length).assertEqual(0);
      expect(overlayFact(overlay, 0)).assertEqual('用户现在偏好燕麦拿铁。');
      if (overlay === null) {
        runtime.dispose();
        return;
      }
      const selected = overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0]);
      const selectedArgs = selected.args as MemoryCandidatesForgetActionArgs;
      const forged: A2uiAction = {
        id: selected.id, label: selected.label, prompt: selected.prompt,
        variant: selected.variant, kind: selected.kind,
        args: {
          selectionId: selectedArgs.selectionId,
          revision: selectedArgs.revision,
          candidateKeys: ['memory-prefetch-a']
        } as MemoryCandidatesForgetActionArgs
      };

      expect((await runtime.handleMemoryCandidateAction(forged)).status).assertEqual('rejected');
      expect(memory.forgetCalls.length).assertEqual(0);
      expect((await runtime.handleMemoryCandidateAction(selected)).status).assertEqual('success');
      expect(memory.forgetCalls.join(',')).assertEqual('memory-manual-b');
      runtime.dispose();
    });

    it('uses all expanded final manual recall candidates for forget selection', 0, async () => {
      const prefetch: PhoneLocalRecalledMemory = {
        memoryId: 'memory-prefetch-only', fact: '旧的召回候选。',
        personaTag: 'food_companion', authority: 'leader'
      };
      const refined: PhoneLocalRecalledMemory[] = [];
      for (let index = 0; index < 6; index += 1) {
        refined.push({
          memoryId: 'memory-manual-expanded-' + index.toString(),
          fact: '最终召回候选 ' + index.toString(),
          personaTag: 'food_companion', authority: 'leader'
        });
      }
      const memory = new SequencedRecallMemoryRuntime([[prefetch], refined]);
      const surfaces: A2uiSurfaceState[] = [];
      let overlay: MemoryForgetOverlayRequest | null = null;
      const options = canaryOptions(
        new QueueModel([MANUAL_RECALL_TEN_DECISION, MEMORY_FORGET_SELECTION_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      options.currentHostGeneration = (): number => 13;
      options.onMemoryForgetOverlay = (request: MemoryForgetOverlayRequest | null): void => { overlay = request; };
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('忘掉这些偏好', { text: '忘掉这些偏好' }, 13) as
        MultiAgentSettledOutcome;
      expect(memory.recallTopKs.join(',')).assertEqual('5,10');
      expect(outcome.memorySelection).assertEqual(undefined);
      expect(overlayCandidateCount(overlay)).assertEqual(6);
      expect(surfaces.length).assertEqual(0);
      expect(overlayFact(overlay, 5)).assertEqual('最终召回候选 5');
      if (overlay !== null) {
        expect((await runtime.handleMemoryCandidateAction(overlayForgetAction(
          overlay as MemoryForgetOverlayRequest, [0, 1, 2, 3, 4, 5]
        ))).status).assertEqual('rejected');
        expect(memory.forgetBatches.length).assertEqual(0);
        expect((await runtime.handleMemoryCandidateAction(overlayForgetAction(
          overlay as MemoryForgetOverlayRequest, [0, 1, 2, 3, 4]
        ))).status).assertEqual('success');
        expect(memory.forgetBatches.length).assertEqual(1);
        expect(memory.forgetBatches[0].length).assertEqual(5);
        expect(overlayCandidateCount(overlay)).assertEqual(1);
        if (overlay !== null) {
          expect((await runtime.handleMemoryCandidateAction(
            overlayForgetAction(overlay as MemoryForgetOverlayRequest, [0])
          )).status).assertEqual('success');
        }
      }
      expect(memory.forgetCalls.length).assertEqual(6);
      expect(overlay === null).assertTrue();
      runtime.dispose();
    });

    it('fails open after manual recall error without reusing prefetch candidates for forget', 0, async () => {
      const prefetch: PhoneLocalRecalledMemory = {
        memoryId: 'memory-prefetch-a', fact: '用户以前偏好美式咖啡。',
        personaTag: 'food_companion', authority: 'leader'
      };
      const memory = new SequencedRecallMemoryRuntime([[prefetch]], 1);
      const surfaces: A2uiSurfaceState[] = [];
      const options = canaryOptions(
        new QueueModel([MANUAL_RECALL_DECISION, ANSWER_DECISION]),
        new CanaryHotelExecutor(), new RecordingOpener(), surfaces, []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('忘掉咖啡偏好', { text: '忘掉咖啡偏好' }) as
        MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(outcome.memorySelection).assertUndefined();
      expect(surfaces.length).assertEqual(0);
      expect(memory.forgetCalls.length).assertEqual(0);
      runtime.dispose();
    });

    it('continues to a normal answer after a failed automatic recall observation', 0, async () => {
      const model = new QueueModel([ANSWER_DECISION]);
      const options = canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = new ThrowingRecallMemoryRuntime();
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit('你好', { text: '你好' }) as MultiAgentSettledOutcome;

      expect(outcome.status).assertEqual('success');
      expect(model.prompts[0].indexOf('"status":"error"')).assertLarger(-1);
      expect(model.prompts[0].indexOf('"items":[]')).assertLarger(-1);
      runtime.dispose();
    });

    it('publishes only the previous turn persona as the next-turn hint', 0, async () => {
      const model = new QueueModel([ANSWER_DECISION, ANSWER_DECISION]);
      const runtime = new MultiAgentCanaryRuntime(canaryOptions(
        model, new CanaryHotelExecutor(), new RecordingOpener(), [], []
      ));

      await runtime.submit('第一轮', { text: '第一轮' });
      await runtime.submit('第二轮', { text: '第二轮' });

      expect(model.prompts[0].indexOf('"lastTurnPersonaId":""')).assertLarger(-1);
      expect(model.prompts[1].indexOf(
        '"lastTurnPersonaId":"default_companion"'
      )).assertLarger(-1);
      runtime.dispose();
    });

    it('removes the BIM snapshot wrapper before automatic memory recall', 0, async () => {
      const memory = new RecordingPhoneLocalMemoryRuntime();
      const options = canaryOptions(
        new QueueModel([ANSWER_DECISION]), new CanaryHotelExecutor(), new RecordingOpener(), [], []
      );
      options.memoryRuntime = memory;
      const runtime = new MultiAgentCanaryRuntime(options);

      await runtime.submit(bimSnapshotPrompt('继续查这些'), { text: '继续查这些' });

      expect(memory.recallQueries.length).assertEqual(1);
      expect(memory.recallQueries[0]).assertEqual('继续查这些');
      expect(memory.recallQueries[0].indexOf('BIM_SNAPSHOTS')).assertEqual(-1);
      runtime.dispose();
    });

    it('keeps C20 search navigation detail booking and return under the canary runtime', 0, async () => {
      const executor = new CanaryHotelExecutor();
      const opener = new RecordingOpener();
      const bus = new TrackingBus();
      const surfaces: A2uiSurfaceState[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let renderGeneration = 0;
      const options = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        executor,
        opener,
        surfaces,
        [],
        bus
      );
      options.onSurface = (
        surface: A2uiSurfaceState,
        runtimeGeneration: number
      ): boolean => {
        if (currentHost !== null &&
          (currentHost.runtimeOwner !== 'multi_agent' ||
            currentHost.runtimeGeneration !== runtimeGeneration)) {
          return false;
        }
        surfaces.push(surface);
        currentHost = surface;
        renderGeneration++;
        currentSnapshot = pageSnapshot(surface, renderGeneration);
        return true;
      };
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => currentHost === null ||
        currentHost.runtimeGeneration === undefined ? 0 : currentHost.runtimeGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }) as MultiAgentSettledOutcome;
      const searchContext = runtime.currentActionContext();
      const originalSearchSurfaceId = surfaces[surfaces.length - 1].surfaceId;
      expect(outcome.status).assertEqual('success');
      expect(searchContext?.sourceToolId).assertEqual('hotel.search');
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      const normalizedSearch = executor.tasks[0].args as Record<string, Object | string | number | boolean | null | undefined>;
      expect(normalizedSearch.originQuery).assertEqual(SEARCH_TEXT);
      expect(normalizedSearch.checkInDate).assertEqual('2026-08-15');
      expect(normalizedSearch.stayNights).assertEqual(2);
      expect(normalizedSearch.checkOutDate).assertEqual(undefined);

      const navigate = renderedAction(surfaces[surfaces.length - 1], 'hotel.navigate');
      expect(navigate === null).assertFalse();
      expect(await runtime.runAction(navigate!, searchContext!)).assertTrue();
      expect(opener.uris[0].indexOf('petalmaps://')).assertEqual(0);
      expect(runtime.restoreSearchSurface()).assertTrue();
      const restoredSearchContext = runtime.currentActionContext();
      expect(restoredSearchContext?.sourceToolId).assertEqual('hotel.search');

      const detail = renderedAction(surfaces[surfaces.length - 1], 'hotel.detail');
      expect(detail === null).assertFalse();
      const forgedDetail = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (forgedDetail.args as Record<string, Object | string | number | boolean | null | undefined>)['hotelId'] =
        999999;
      const mismatchedDetailContext: MultiAgentCanaryActionContext = {
        conversationId: restoredSearchContext!.conversationId,
        turnId: restoredSearchContext!.turnId + '-forged',
        surfaceId: restoredSearchContext!.surfaceId,
        sourceToolId: restoredSearchContext!.sourceToolId
      };
      expect(await runtime.runAction(forgedDetail, restoredSearchContext!)).assertFalse();
      expect(await runtime.runAction(detail!, mismatchedDetailContext)).assertFalse();
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.search');
      let detailSettled = false;
      const detailPending = runtime.runAction(detail!, restoredSearchContext!);
      detailPending.then((_ok: boolean): void => {
        detailSettled = true;
      });
      expect(await runtime.runAction(detail!, restoredSearchContext!)).assertFalse();
      const concurrentDifferentDetail = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (concurrentDifferentDetail.args as Record<string, Object | string | number | boolean | null | undefined>)[
        'hotelId'
      ] = 999999;
      expect(await runtime.runAction(concurrentDifferentDetail, restoredSearchContext!)).assertFalse();
      expect(runtime.currentActionContext()?.sourceToolId === 'hotel.search').assertFalse();
      await flush();
      expect(executor.calls.join(',')).assertEqual('hotel.search,hotel.detail');
      await executor.detailStarted.promise;
      await flush();
      expect(runtime.currentActionContext()?.sourceToolId === 'hotel.search').assertFalse();
      expect(bus.count(AgentMessageType.TASK_CREATE_UI)).assertEqual(2);
      expect(bus.count(AgentMessageType.TASK_CREATE_DATA)).assertEqual(2);
      const detailUiMessage = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_UI &&
        (message.payload as CreateUiTaskPayload).intent === 'hotel.detail'
      )[0];
      const detailDataMessage = bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.TASK_CREATE_DATA &&
        (message.payload as CreateDataTaskPayload).toolId === 'hotel.detail'
      )[0];
      const detailUiTask = detailUiMessage.payload as CreateUiTaskPayload;
      const detailDataTask = detailDataMessage.payload as CreateDataTaskPayload;
      expect(detailUiTask.dataTaskIds[0]).assertEqual(detailDataTask.taskId);
      expect(detailUiTask.taskId).assertEqual('hotel-detail-ui-2');
      expect(detailDataTask.taskId).assertEqual('hotel-detail-data-1');
      expect(detailDataTask.roundId).assertEqual(detailDataMessage.turnId + ':round-1');
      expect(detailUiMessage.turnId).assertEqual(detailDataMessage.turnId);
      expect(detailUiMessage.turnId === restoredSearchContext?.turnId).assertFalse();
      expect(detailSettled).assertFalse();
      executor.detailRelease.open();
      expect(await detailPending).assertTrue();

      const detailContext = runtime.currentActionContext();
      expect(detailContext?.sourceToolId).assertEqual('hotel.detail');
      expect(detailContext?.surfaceId === originalSearchSurfaceId).assertFalse();
      const booking = renderedAction(surfaces[surfaces.length - 1], 'hotel.booking.open');
      expect(booking === null).assertFalse();
      expect(booking?.id).assertEqual('hotel.booking.open');
      expect((booking?.args as Record<string, string>).bookingUrl).assertEqual(hotelItem().bookingUrl);
      expect(await runtime.runAction(booking!, restoredSearchContext!)).assertFalse();
      expect(await runtime.runAction(booking!, detailContext!)).assertTrue();
      expect(opener.uris[opener.uris.length - 1].indexOf('https://rollinggo.cn/')).assertEqual(0);
      expect(runtime.currentActionContext()?.surfaceId).assertEqual(detailContext?.surfaceId);
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.detail');

      const visibleDetail = surfaces[surfaces.length - 1];
      const newerHost = pageSurface('hotel.detail', booking!, 202);
      currentHost = newerHost;
      currentSnapshot = pageSnapshot(newerHost, renderGeneration + 1);
      expect(runtime.restoreSearchSurface()).assertFalse();
      expect(surfaces[surfaces.length - 1].surfaceId).assertEqual(visibleDetail.surfaceId);
      const legacyHost = pageSurface('hotel.detail', booking!, 101);
      legacyHost.runtimeOwner = 'legacy';
      currentHost = legacyHost;
      currentSnapshot = pageSnapshot(legacyHost, renderGeneration + 2);
      expect(runtime.restoreSearchSurface()).assertFalse();
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.detail');
      currentHost = visibleDetail;
      currentSnapshot = pageSnapshot(visibleDetail, renderGeneration + 3);
      expect(runtime.restoreSearchSurface()).assertTrue();
      expect(surfaces[surfaces.length - 1].surfaceId).assertEqual(originalSearchSurfaceId);
      expect(registeredPageSourceToolId(surfaces[surfaces.length - 1])).assertEqual('hotel.search');
      expect(runtime.currentActionContext()?.sourceToolId).assertEqual('hotel.search');
      runtime.dispose();
    });

    it('runs hotel detail only for the exact current host search surface', 0, async () => {
      const executor = new CanaryHotelExecutor();
      const surfaces: A2uiSurfaceState[] = [];
      let currentHost: A2uiSurfaceState | null = null;
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      let renderGeneration = 0;
      const options = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        executor,
        new RecordingOpener(),
        surfaces,
        []
      );
      options.onSurface = (
        surface: A2uiSurfaceState,
        runtimeGeneration: number
      ): boolean => {
        if (currentHost !== null &&
          (currentHost.runtimeOwner !== 'multi_agent' ||
            currentHost.runtimeGeneration !== runtimeGeneration)) {
          return false;
        }
        surfaces.push(surface);
        currentHost = surface;
        renderGeneration++;
        currentSnapshot = pageSnapshot(surface, renderGeneration);
        return true;
      };
      options.currentHostSurface = (): A2uiSurfaceState | null => currentHost;
      options.currentHostGeneration = (): number => currentHost === null ||
        currentHost.runtimeGeneration === undefined ? 0 : currentHost.runtimeGeneration;
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);

      const outcome = await runtime.submit(SEARCH_TEXT, { text: '' }, 101) as MultiAgentSettledOutcome;
      const searchSurface = surfaces[surfaces.length - 1];
      const searchSnapshot = pageSnapshot(searchSurface, renderGeneration);
      const context = runtime.currentActionContext();
      const detail = renderedAction(searchSurface, 'hotel.detail');
      const newerSurface = pageSurface('hotel.search', detail!, 202);
      currentHost = newerSurface;
      currentSnapshot = pageSnapshot(newerSurface, renderGeneration + 1);

      expect(outcome.status).assertEqual('success');
      expect(await runtime.runAction(detail!, context!)).assertFalse();
      expect(executor.calls.join(',')).assertEqual('hotel.search');
      expect(executor.tasks.length).assertEqual(1);

      currentHost = searchSurface;
      currentSnapshot = searchSnapshot;
      const detailPending = runtime.runAction(detail!, context!);
      await executor.detailStarted.promise;
      expect(executor.calls.join(',')).assertEqual('hotel.search,hotel.detail');
      expect(executor.tasks.length).assertEqual(2);
      executor.detailRelease.open();
      expect(await detailPending).assertTrue();
      runtime.dispose();
    });

    it('routes exact declared and existing adapted product buttons through one ActionAgent run', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return {
          status: 'success',
          output: JSON.parse('{"providerStatus":"exact"}') as Object
        };
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);
      const routes: Array<[string, string, string, Object, string]> = [
        ['social.feed.search', 'social.reply.draft', 'social.reply.draft',
          JSON.parse('{"itemId":"post-1","platform":"x","instruction":"draft"}') as Object, 'prompt'],
        ['mail.search', 'mail.draft.create', 'mail.draft.create',
          JSON.parse('{"provider":"qq","to":"a@example.com","subject":"QA","body":"draft"}') as Object, 'prompt'],
        ['gmail.thread.read', 'gmail.draft.create', 'gmail.draft.create',
          JSON.parse('{"to":"a@example.com","subject":"QA","body":"draft"}') as Object, 'prompt'],
        ['gmail.draft.create', 'gmail.draft.apply', 'gmail.draft.apply',
          JSON.parse('{"provider":"gmail_oauth","draftId":"draft-1","threadId":"thread-1",' +
            '"to":"a@example.com","subject":"QA","body":"exact"}') as Object, 'prompt'],
        ['gmail.draft.apply', 'gmail.open.web', 'gmail.open.web',
          JSON.parse('{"url":"https://mail.google.com/"}') as Object, 'client'],
        ['luckin.order.preview', 'luckin.order.preview', 'luckin.order.preview',
          JSON.parse('{"deptId":"shop-1","location":"114.0,22.5"}') as Object, 'prompt'],
        ['payment.send', 'payment.confirm', 'payment.send',
          JSON.parse('{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
            '"currency":"USD","phase":"confirm"}') as Object, 'prompt'],
        ['payment.account.setup', 'stripe.account.create', 'payment.account.setup',
          JSON.parse('{"country":"US","businessType":"individual"}') as Object, 'client']
      ];

      for (let index = 0; index < routes.length; index++) {
        const route = routes[index];
        const clicked: A2uiAction = {
          id: route[1],
          label: route[1],
          prompt: route[1],
          variant: 'primary',
          kind: route[4],
          args: route[3]
        };
        const surface = pageSurface(route[0], clicked, index + 1);
        const document = createHtmlHomeDocument({
          surface,
          messages: [],
          isBusy: false,
          isAwaitingFirstSurface: false
        });
        currentSnapshot = { surface, document, generation: index + 1 };
        expect(await runtime.runPageAction(clicked)).assertTrue();
        expect(calls[index].actionId).assertEqual(route[2]);
        expect(JSON.stringify(calls[index].args)).assertEqual(JSON.stringify(route[3]));
        expect((calls[index].context as RegisteredPageActionContext).hostGeneration)
          .assertEqual(index + 1);
      }
      expect(calls.length).assertEqual(routes.length);
      expect(bus.messages.filter((message: AgentMessage): boolean =>
        message.type === AgentMessageType.ACTION_RESULT &&
          JSON.stringify(message.payload).indexOf('"status":"paused"') >= 0
      ).length).assertEqual(0);
      runtime.dispose();
    });

    it('does not block Gmail send from the exact current search result reply surface', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const bus = new TrackingBus();
      const surface = currentGmailReplySurface(29);
      const document = createHtmlHomeDocument({
        surface,
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        [],
        bus
      );
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => ({
        surface,
        document,
        generation: 29
      });
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return { status: 'success', output: JSON.parse('{"providerStatus":"sent"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);
      const args = JSON.parse(
        '{"requestKey":"gmail:thread-real-1","provider":"gmail","accountLabel":"",' +
          '"threadId":"thread-real-1","messageId":"message-real-1",' +
          '"to":["alice@example.com"],"subject":"Re: QA","body":"Exact reply",' +
          '"replyMode":"reply","contextSummary":"QA body"}'
      ) as Object;
      const clicked: A2uiAction = {
        id: 'html_mail_reply_send',
        label: '发送回复',
        prompt: 'gmail:thread-real-1',
        variant: 'primary',
        kind: 'client',
        args
      };

      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(calls.length).assertEqual(1);
      expect(calls[0].actionId).assertEqual('gmail.message.send');
      expect(JSON.stringify(bus.messages).indexOf('ACTION_BLOCKED')).assertEqual(-1);
      runtime.dispose();
    });

    it('rejects a legacy-stamped surface action and accepts the exact multi-agent owner', 0, async () => {
      const calls: RecordedPageAction[] = [];
      const action: A2uiAction = {
        id: 'mail.draft.create',
        label: '创建草稿',
        prompt: '创建草稿',
        variant: 'primary',
        kind: 'prompt',
        args: JSON.parse(
          '{"provider":"qq","to":"a@example.com","subject":"QA","body":"draft"}'
        ) as Object
      };
      const surface = pageSurface('mail.search', action, 30);
      const document = createHtmlHomeDocument({
        surface,
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      let current: RegisteredPageSnapshot = { surface, document, generation: 30 };
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => current;
      options.pageAction = async (
        actionId: string,
        args: Object,
        context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push({ actionId, args, context });
        return { status: 'success', output: JSON.parse('{"status":"drafted"}') as Object };
      };
      const runtime = new MultiAgentCanaryRuntime(options);

      surface.runtimeOwner = 'legacy';
      current = { surface, document, generation: 30 };
      expect(await runtime.runPageAction(action)).assertFalse();
      surface.runtimeOwner = 'multi_agent';
      current = { surface, document, generation: 31 };
      expect(await runtime.runPageAction(action)).assertTrue();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('rejects stale mutated client-only and deferred page actions before callback', 0, async () => {
      const calls: string[] = [];
      let currentSnapshot: RegisteredPageSnapshot | null = null;
      const options = canaryOptions(
        new QueueModel([]),
        new CanaryHotelExecutor(),
        new RecordingOpener(),
        [],
        []
      );
      options.pageAction = async (
        actionId: string,
        _args: Object,
        _context: ActionExecutionContext
      ): Promise<ActionExecutionResult> => {
        calls.push(actionId);
        return { status: 'success', output: new Object() };
      };
      options.currentPageSnapshot = (): RegisteredPageSnapshot | null => currentSnapshot;
      const runtime = new MultiAgentCanaryRuntime(options);
      const args = JSON.parse('{"provider":"stripe","recipient":"real-user","amountText":"5.00",' +
        '"currency":"USD","phase":"confirm"}') as Object;
      const clicked: A2uiAction = {
        id: 'payment.confirm',
        label: 'payment.confirm',
        prompt: 'payment.confirm',
        variant: 'primary',
        kind: 'prompt',
        args
      };
      const surface = pageSurface('payment.send', clicked, 10);
      const document = createHtmlHomeDocument({
        surface,
        messages: [],
        isBusy: false,
        isAwaitingFirstSurface: false
      });
      currentSnapshot = { surface, document, generation: 10 };
      const mutated: A2uiAction = {
        id: clicked.id,
        label: clicked.label,
        prompt: clicked.prompt,
        variant: clicked.variant,
        kind: clicked.kind,
        args: JSON.parse('{"provider":"stripe","recipient":"mallory","amountText":"5000",' +
          '"currency":"USD","phase":"confirm"}') as Object
      };
      const clientOnly: A2uiAction = {
        id: 'payment.cancel',
        label: 'payment.cancel',
        prompt: 'payment.cancel',
        variant: 'secondary',
        kind: 'client',
        args
      };
      const deferred: A2uiAction = {
        id: 'gmail.message.send',
        label: 'gmail.message.send',
        prompt: 'gmail.message.send',
        variant: 'primary',
        kind: 'prompt',
        args
      };

      expect(await runtime.runPageAction(clicked)).assertTrue();
      expect(await runtime.runPageAction(mutated)).assertFalse();
      expect(await runtime.runPageAction(clientOnly)).assertFalse();
      expect(await runtime.runPageAction(deferred)).assertFalse();
      currentSnapshot = { surface, document, generation: 9 };
      expect(await runtime.runPageAction(clicked)).assertFalse();
      expect(calls.length).assertEqual(1);
      runtime.dispose();
    });

    it('cancels and times out the exact C20 child turn without a late success', 1000, async () => {
      const timeoutExecutor = new CanaryHotelExecutor();
      const timeoutBus = new TrackingBus();
      const timeoutSurfaces: A2uiSurfaceState[] = [];
      const timeoutOptions = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        timeoutExecutor,
        new RecordingOpener(),
        timeoutSurfaces,
        [],
        timeoutBus,
        20
      );
      useLastRenderedSurfaceAsHost(timeoutOptions, timeoutSurfaces);
      const timeoutRuntime = new MultiAgentCanaryRuntime(timeoutOptions);
      await timeoutRuntime.submit(SEARCH_TEXT, { text: '' });
      const timeoutDetail = renderedAction(
        timeoutSurfaces[timeoutSurfaces.length - 1],
        'hotel.detail'
      );
      const timedOut = timeoutRuntime.runAction(
        timeoutDetail!,
        timeoutRuntime.currentActionContext()!
      );
      await timeoutExecutor.detailStarted.promise;
      expect(await timedOut).assertFalse();
      expect(timeoutBus.count(AgentMessageType.TURN_CANCEL) >= 2).assertTrue();
      timeoutExecutor.detailRelease.open();
      await flush();
      timeoutRuntime.dispose();

      const cancelExecutor = new CanaryHotelExecutor();
      const cancelBus = new TrackingBus();
      const cancelSurfaces: A2uiSurfaceState[] = [];
      const cancelOptions = canaryOptions(
        new QueueModel([HOTEL_DECISION, HOTEL_DONE_DECISION]),
        cancelExecutor,
        new RecordingOpener(),
        cancelSurfaces,
        [],
        cancelBus
      );
      useLastRenderedSurfaceAsHost(cancelOptions, cancelSurfaces);
      const cancelRuntime = new MultiAgentCanaryRuntime(cancelOptions);
      await cancelRuntime.submit(SEARCH_TEXT, { text: '' });
      const cancelDetail = renderedAction(
        cancelSurfaces[cancelSurfaces.length - 1],
        'hotel.detail'
      );
      const canceled = cancelRuntime.runAction(
        cancelDetail!,
        cancelRuntime.currentActionContext()!
      );
      await cancelExecutor.detailStarted.promise;
      cancelRuntime.cancelActiveTurn('user_cancel');
      expect(await canceled).assertFalse();
      expect(cancelBus.count(AgentMessageType.TURN_CANCEL) >= 2).assertTrue();
      cancelExecutor.detailRelease.open();
      await flush();
      cancelRuntime.dispose();
    });
  });
}
