import {
  AGENT_CORE_DEBUG,
  A2uiAgentRunner,
  ActionExecutionResult,
  CurrentSurfaceSummary,
  DataResult,
  LlmProvider,
  LocalModel,
  LocalModelSettings,
  OpenAiA2uiModel,
  OpenAiCompatibleModel,
  PaymentAccount,
  RuntimeOwner,
  StripeReceivingAccountCardData,
  UserInputPayload,
  defaultLocalModelSettings,
  deepSeekModelSettings,
  resolvedCloudChatModel,
  rideAmapWebKeyForUi,
  summarizeAppliedA2uiSurface
} from '@loop/agent-core';
import { isRollingGoHotelBookingUrl, validHotelBookingOpenArgs } from '@loop/agent-core';
import {
  advanceWaterfallFeed,
  applyWaterfallProfile,
  aggregateSearchInterestSourceIds,
  aggregateSearchSearchSourceIds,
  applyWaterfallExpandedQuery,
  applyWaterfallSourceSelection,
  callConfiguredAggregateSearchContinuation,
  callConfiguredWaterfallComments,
  callConfiguredWaterfallInterestRecall,
  AggregateSearchSource,
  AggregateSearchSourceBatch,
  ApplePodcastEpisodeAudio,
  ApplePodcastResolverFailure,
  applePodcastResolverFailure,
  configureWaterfallEnabledSourcesForRuntime,
  configureWaterfallPreferenceProfileForRuntime,
  configureWaterfallSearchPolicyForRuntime,
  failWaterfallExpansion,
  finalizeInterestWaterfallRecallRanking,
  mergeAggregateSearchContinuationBatch,
  mergeWaterfallBatchDeferredRanking,
  mergeWaterfallFeedSnapshot,
  planWaterfallInterestRecall,
  planWaterfallContinuation,
  resolveApplePodcastEpisode,
  parseWaterfallExpandedQuery,
  WaterfallCandidate,
  WaterfallCommentsResult,
  WaterfallFeedState,
  WaterfallFeedUpdate,
  WaterfallInterestRecallRequest,
  WaterfallInterestRecallBatch,
  WaterfallLoadRequest,
  WaterfallPreferenceWeight,
  WaterfallQueryExpansionRequest,
  WaterfallRankedCandidate,
  WaterfallSourcePhase,
  WaterfallSourceState,
  waterfallCommentSourceSupported,
  waterfallExpansionPrompt,
  waterfallSearchPolicyForRuntime
} from '@loop/agent-core';
import router from '@ohos.router';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { accessibility } from '@kit.AccessibilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { notificationManager } from '@kit.NotificationKit';
import { call } from '@kit.TelephonyKit';
import { mapCommon, petalMaps } from '@kit.MapKit';
import promptAction from '@ohos.promptAction';
import fs from '@ohos.file.fs';
import { geoLocationManager } from '@kit.LocationKit';
import { inputMethod } from '@kit.IMEKit';
import util from '@ohos.util';
import {
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiDataValue,
  A2uiDynamicToolConnectData,
  A2uiFlightData,
  A2uiFoodData,
  A2uiFoodSearchArea,
  A2uiGenericToolResultData,
  A2uiLabelValueData,
  A2uiMessage,
  A2uiRuntimeDataModel,
  A2uiSurfaceState,
  actionsOf,
  componentById,
  genericToolResults,
  A2uiTrainData,
  A2uiTravelOptionData
} from '@loop/agent-core';
import { buildFoodPhoneUri, stripeReceivingAccount } from '@loop/agent-core';
import {
  awaitConnectionTest,
  callDirectModel,
  DirectModelCallResult
} from '../../model/LocalModelClient';
import {
  ActiveSessionContext,
  SessionContextCompactor
} from './agent/SessionContextCompaction';
import { GMAIL_MCP_AUTH_SETUP_URL, GMAIL_WEB_URL, GOOGLE_CALENDAR_WEB_URL, GOOGLE_OAUTH_SETUP_URL } from '@loop/agent-core';
import { A2uiSurfaceStore, createSeedA2uiSurface } from '@loop/agent-core';
import {
  emptySocialHubDraft,
  SocialHubConnectionData,
  SocialHubConnectionStatus,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubPlatform
} from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { sha256Digest } from '@loop/agent-core';
import {
  appendMultiTaskSlot,
  callStructuredTool,
  callToolGateway,
  childSurfaceIdForMultiTaskSlot,
  COMPOSIO_USER_ID_PREFIX,
  ComposioAuthConfigItem,
  ComposioAuthProxyClient,
  configureDidiMcpSandboxForRuntime,
  configureComposioUserId,
  configureLocalPaymentAccountBookJson,
  configureLocalStripeReceivingAgentJson,
  configureLocalToolDebugConfig,
  currentComposioConfig,
  currentComposioUserId,
  decideTrainPresaleExecution,
  defaultToolGatewayUrl,
  isMultiTaskSurface,
  directFirecrawlToolIdForActionId,
  firecrawlHttpUrlOf,
  isRegisteredAiphoneToolId,
  mergeSlotObservationIntoMultiTaskSurface,
  normalizeComposioUserId,
  prepareGmailOAuthAuthorizationUrl,
  prepareGoogleOAuthAuthorizationUrl,
  foodCardHasMcDonaldsSource,
  foodCardHasLuckinSource,
  LuckinFoodMenuProduct,
  McDonaldsFoodMenuRow,
  createMcDonaldsFoodMenuOrder,
  queryMcDonaldsFoodMenuDetail,
  queryMcDonaldsFoodMenuForCard,
  queryMcDonaldsFoodMenuOrder,
  quoteMcDonaldsFoodMenuOrder,
  queryLuckinFoodMenuForCard,
  recheck12306TrainAvailability,
  resolveMultiTaskSlotId,
  resolveLuckinActionPrompt,
  rideDidiMcpSandboxEnabledForRuntime,
  select12306DebugTrain,
  sendLocalSocialHubReply,
  shortComposioUserId,
  TrainPresaleAvailabilityCheck,
  TrainPresaleExecutionDecision,
  TrainPresaleExecutionTask,
  TrainPresaleRecheckRequest,
  wrapSurfaceWithMultiTaskAction
} from '@loop/agent-core';
import {
  NavigationCardSnapshot,
  NavigationCardSnapshotBuildResult,
  PreferencesNavigationCardSnapshotStore,
  buildNavigationCardBindingData,
  navigationCardSnapshotFromFlightOption,
  navigationCardSnapshotFromFoodOption,
  navigationCardSnapshotFromTrainOption,
  navigationCardSnapshotFromTravelOption
} from '@loop/agent-core';
import { AssetCredentialStore } from '@loop/agent-core';
import { buildSystemFoodNavigationUri } from '@loop/agent-core';
import { officialMediaVideoPlaybackUrl } from '@loop/agent-core';
import {
  MailDetail,
  MailCalendarSuggestion,
  MailReplyCommand,
  MailReplyOperationResult,
  HuaweiTravelCalendarConflict,
  HuaweiTravelCalendarEvent,
  addHuaweiCalendarEvent,
  addHuaweiTravelCalendarEvent,
  findHuaweiTravelCalendarConflicts,
  saveConfiguredMailDraft,
  sendConfiguredMailReply
} from '@loop/agent-core';
import {
  TRAVEL_CALENDAR_ADD_ACTION_ID,
  applyTravelCalendarConflictProjection,
  travelCalendarEventFromFlight,
  travelCalendarEventsFromModel,
  travelCalendarEventFromOption,
  travelCalendarEventFromTrain
} from './travel/TravelCalendarAction';
import {
  copyPersonaData,
  leaderPersonaSurfaceUpdate
} from '../../model/PersonaA2ui';
import { DEEP_SEARCH_ROUTE_URL, DeepSearchRouteParams } from './deepsearch/DeepSearchEngine';
import {
  isStableWaterfallContentPreference,
  mergePersonaStablePreference,
  waterfallExplicitPreferencesFromStatement,
  PersonaMemoryUpdateRequest
} from '../../model/PersonaMemoryUpdate';
import { PreferencesPersonaPackStore } from '../../model/PersonaPreferencesStore';
import { allPersonaPacks, personaPackForId, resetPersonaPackText, updatePersonaPackText } from '../../model/PersonaStore';
import { PersonaPack } from '../../model/PersonaTypes';
import { startVoiceInputSession, VoiceInputResult, VoiceInputSession } from '../../model/VoiceInputBridge';
import { BimDetailPage } from './components/BimDetailPage';
import {
  BimHomePage,
  combineBimErrorMessages,
  groupVisibleBims
} from './components/BimHomePage';
import { ComposioAuthPage } from './components/ComposioAuthPage';
import { BimRememberState, HomePage } from './components/HomePage';
import { HtmlHomeSurfaceView } from './components/HtmlHomeSurfaceView';
import { WaterfallVoiceDock } from './components/WaterfallVoiceDock';
import {
  applyWaterfallConversationCommand,
  directWaterfallConversationCommand,
  parseWaterfallConversationCommand,
  waterfallConversationPrompt,
  WaterfallConversationCommand,
  WaterfallConversationState
} from './waterfall/WaterfallConversation';
import {
  cancelScheduledTrainPresaleTask,
  emptyTrainPresaleTrip,
  findMatchingTrainPresaleTask,
  readTrainPresaleDebugBuildState,
  reconcileTrainPresaleTask,
  runTrainPresaleDebugConfirmation,
  scheduleTrainPresaleTask,
  TrainPresaleConfirmationInput,
  TrainPresaleConfirmationResult,
  TrainPresaleDebugRunInput,
  TrainPresalePanelSubmission,
  TrainPresaleScheduleResult,
  TrainPresaleTrip,
  validateTrainPresaleConfirmation,
  validateTrainPresaleTrip
} from './components/TrainPresalePanel';
import {
  CheckoutWebKind,
  isAllowed12306BookingUrl
} from './components/CheckoutWebOverlay';
import { ConfigPage } from './components/ConfigPage';
import { PublicPersonaPage } from './components/PublicPersonaPage';
import { PublicPersonaClient } from '../../publicpersona/PublicPersonaClient';
import { PhoneLocalMemoryRuntime } from '../../memory/PhoneLocalMemoryRuntime';
import {
  PhoneLocalMemoryAvailabilityPort,
  phoneLocalMemoryAvailabilityForContext
} from '../../memory/PhoneLocalMemoryAvailability';
import {
  PublicPersonaCandidate,
  PublicPersonaPhase,
  PublicPersonaProgress,
  PublicPersonaSearchMode,
  PublicPersonaSnapshot,
  parsePublicPersonaMarkdown,
  replacePublicPersonaMbti,
  sanitizePublicPersonaSnapshot
} from '../../publicpersona/PublicPersonaModel';
import {
  PUBLIC_PERSONA_STORE_NAME,
  PublicPersonaStore
} from '../../publicpersona/PublicPersonaStore';
import {
  HotelTurnStatus
} from './agent/MultiAgentHotelSupport';
import {
  MailDetailInPlaceEvent,
  MailDetailWriteLease,
  MemoryCandidateManagerActionResult,
  MultiAgentCanaryOptions,
  MultiAgentCanaryRuntime
} from './agent/MultiAgentCanaryRuntime';
import {
  MEMORY_CANDIDATES_FORGET_ACTION_ID
} from '../../model/MemoryCandidateSelectionSurface';
import {
  MailDetailSuggestionGuard,
  MailDetailUiEvent,
  publishMailDetailThenSuggest
} from './agent/MailDetailInPlaceUpdater';
import {
  MultiAgentSettledOutcome,
  MultiAgentTurnOutcome
} from './agent/MultiAgentRuntimeTypes';
import {
  BimRecord,
  BimStore,
  BIM_STORE_NAME
} from './bim/BimStore';
import {
  emptyWaterfallPreferenceProfile,
  updateWaterfallPreferenceWeight,
  waterfallBehaviorDelta,
  waterfallCandidateFromSavedCard,
  waterfallReactionWeights,
  WaterfallBehaviorEvidence,
  WaterfallCardRecord,
  WaterfallPreferenceProfile,
  WaterfallReactionProjection,
  WaterfallPreferencesStore,
  WATERFALL_PREFERENCES_STORE_NAME
} from './waterfall/WaterfallPreferencesStore';
import {
  buildCtripFlightSearchUrl,
  buildCtripFlightSelectionContext,
  ctripFlightBookingSelection,
  ctripTravelOptionBookingSelection
} from './travel/TravelBookingProvider';
import {
  BimAttentionEvent,
  BimCuratorResult,
  BimForegroundRequest,
  BimTurnEvidence,
  bimDetailSubmitError,
  bimAttentionVisibleText,
  buildBimAttentionPrompt,
  buildBimForegroundRequest,
  explicitBimCreateRequest,
  refreshedSelectedBimRecord,
  runBimSentinel,
  safeBimToolResultSummary,
  selectedBimRecordForRender,
  runBimCurator
} from './bim/BimRuntime';
import {
  BIM_SENTINEL_MOCK_EVENT,
  BimDailyReminder,
  canRunBimSentinelMock,
  consumeBimSentinelMockHandoff,
  isBimReminderLimitMessage,
  queueBimSentinelMockHandoff,
  shouldScheduleBimDailyReminder
} from './bim/BimDailyReminder';
import {
  SystemUriOpener,
  validateRegisteredPageActionArgs
} from './agent/AiphoneRegisteredActionExecutor';
import {
  RegisteredPageSnapshot,
  RegisteredPageSnapshotStore,
  dispatchRegisteredPageActionCandidate,
  registeredPageActionUsesPageBusy
} from './agent/RegisteredPageActionRoute';
import {
  RegisteredPageActionHandler,
  RegisteredPageToolInvocation,
  RegisteredPageToolInvoker
} from './agent/RegisteredPageActionHandler';
import { RegisteredPageActionContext } from './agent/AiphoneRegisteredActionExecutor';
import { socialHubComposioToolkitCandidates } from './components/SocialHubViewData';
import { createHtmlHomeDocument } from './html/HtmlHomeSnapshot';
import { buildMultiTaskHomePayload, renderHtmlHomeDocument } from './html/HtmlHomeRenderer';
import {
  buildWaterfallHomePayload,
  renderAggregateSearchHomeDocument,
  waterfallApplePodcastCandidateFromAction,
  waterfallAdvanceCurrentFromAction,
  waterfallAdvanceVisibleFromAction,
  waterfallBehaviorFromAction,
  waterfallCardActionFromAction,
  waterfallCommentsCandidateFromAction,
  waterfallEnabledSourcesFromAction,
  waterfallSearchExitFromAction,
  waterfallSearchQueryFromAction
} from './html/HtmlAggregateSearchHomeRenderer';
import { createFirecrawlPendingDocument, isFirecrawlToolId } from './html/HtmlFirecrawlHomeRenderer';
import { FoodAddressBookStore, FoodSavedAddressViewModel } from './FoodAddressBookStore';
import { FoodFavoritesStore, FoodFavoriteViewModel } from './FoodFavoritesStore';
import { buildFoodStoreMapSnapshot } from './FoodStoreMapSnapshot';
import { isHtmlHomeActionAllowed } from './html/HtmlHomeActionPolicy';
import {
  HtmlHomeAction,
  HtmlHomeBlock,
  HtmlHomeDocument,
  WaterfallBehaviorActionArgs,
  WaterfallCardActionArgs
} from './html/HtmlHomeTypes';
import {
  ensureReminderNotificationEnabled,
  SystemOneShotScheduler
} from './train/SystemOneShotScheduler';
import {
  transitionBoundTrainPresaleCheckout,
  transitionTrainPresaleHandoff,
  TRAIN_PRESALE_HANDOFF_EVENT,
  TRAIN_PRESALE_PENDING_TASK_KEY,
  TrainPresaleHandoffTransitionResult,
  WATERFALL_CONVERSATION_TYPED_TEST_EVENT,
  WaterfallConversationTypedTestPayload
} from '../../entryability/EntryAbility';
import {
  TRAIN_PRESALE_TASK_STORE_NAME,
  TrainPresaleTask,
  TrainPresaleTaskState,
  TrainPresaleTaskStore
} from './train/TrainPresaleTaskStore';
import { TrainPresaleResumeDrain } from './train/TrainPresaleResumeDrain';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  HTML_HOME_DEBUG_EXPORT_FILE_NAME,
  htmlHomeDebugExportJson,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from './state/A2uiHomeDebugSettings';
import {
  aggregateSearchArgsWithPolicy,
  DEFAULT_AGGREGATE_SEARCH_POLICY
} from './state/AggregateSearchPolicy';
import {
  ConnectionPanelState,
  createTurnConversationSurface,
  createTurnFailureSurface,
  createInitialConnectionPanelState,
  deepSearchRouteDecisionFromModelText,
  deepSearchRouteDecisionPrompt,
  explicitDeepSearchRouteDecision,
  inputTextAfterPromptSubmit,
  nextPendingToolRenderTick,
  runtimeCallbackIsCurrent,
  runtimeOwnerAllowsSurfaceAction,
  runtimeSurfaceIdentityMatches,
  shouldApplySurfaceUpdate,
  shouldShowFirecrawlPendingSurface,
  shouldShowQueryPendingSurface,
  shouldShowWelcome,
  updateConnectionPanelState,
  visibleTurnFailureMessage,
  voiceInputTextAfterRecognition
} from './state/A2uiHomeState';
import {
  A2uiHomeResolvedToolRequest,
  directPaymentToolIdForActionId,
  directRideToolIdForActionId,
  hasAggregateSearchIntent,
  resolveA2uiHomeSubmitToolRequest,
  resolveA2uiHomeToolRequest,
  waterfallSearchQueryForHomePrompt
} from './render/A2uiHomeToolRequest';
import {
  createDailyBriefErrorSurface,
  createDailyBriefLoadingSurface,
  createDailyBriefSurface,
  createDailyBriefWaterfallSurface,
  DailyBriefMailReadRequest,
  dailyBriefDate,
  dailyBriefDemoScenario,
  dailyBriefHistoryDirection,
  dailyBriefMailReadRequest,
  dailyBriefScenarioToolRequest,
  decideDailyBriefOpen,
  selectDailyBriefStoredWinnerBeforeSave,
  selectDailyBriefSnapshotAfterSave,
  shouldApplyDailyBriefGeneration
} from './dailybrief/DailyBriefCore';
import { generateDailyBrief } from './dailybrief/DailyBriefGenerator';
import {
  scheduleNextDailyBrief,
  shouldStartDailyBriefCatchUp,
  transitionDailyBriefCatchUp
} from './dailybrief/DailyBriefScheduler';
import {
  DailyBriefStore,
  isValidDailyBriefAction
} from './dailybrief/DailyBriefStore';
import {
  DailyBriefPreference,
  DailyBriefSnapshot
} from './dailybrief/DailyBriefTypes';
import {
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from './style/A2uiHomeMotion';
import {
  clearUiLabModelSettings,
  configureUiLabModelSettings
} from './lab/UiLabRuntimeConfig';

interface FoodStoreMapLocationActionArgs {
  surfaceId: string;
  searchArea: A2uiFoodSearchArea;
}

const CONNECTION_TEST_PROMPT: string = '连接检查：请返回 A2UI v0.9.1 setup surface，说明 Local API 已可用。';
const TRAVEL_STAGE55_DEVICE_FIXTURE_PURPOSE: string = '阶段5.5恢复验收样例';
const TRAVEL_STAGE55_DEVICE_FIXTURE_RESTORE_COMMAND: string = 'travel-stage55-restore-original';
const ENABLE_MULTI_AGENT_UI_LAYOUT_LLM: boolean = false;
const TOOL_GATEWAY_URL: string = defaultToolGatewayUrl();
const initialConnectionState: ConnectionPanelState = createInitialConnectionPanelState();
const initialSurface: A2uiSurfaceState = createSeedA2uiSurface();
const LOG_SNIPPET_LIMIT: number = 1200;
const DEFAULT_INPUT_PLACEHOLDER: string = '点击输入或按住说话';
const DEEP_SEARCH_AUTO_ROUTE_ENABLED: boolean = false;
const TRAIN_EDIT_QUERY_PLACEHOLDER: string = '请输入具体车站和时间，如：深圳北 18:00 后 到香港西九龙';
const NAVIGATION_CARD_TTL_MS: number = 60 * 60 * 1000;
const PAYMENT_ACCOUNT_STORE_NAME: string = 'aiphone_payment_account_store';
const PAYMENT_ACCOUNT_BOOK_KEY: string = 'payment_account_book';
const STRIPE_RECEIVING_PROFILE_KEY: string = 'stripe_receiving_profile';
const COMPOSIO_AUTH_STORE_NAME: string = 'aiphone_composio_auth_store';
const COMPOSIO_USER_ID_KEY: string = 'composio_user_id';
const MODEL_PRESET_STORE_NAME: string = 'aiphone_model_preset_store';
const MODEL_PRESET_KEY: string = 'model_preset';
const AGGREGATE_SEARCH_POLICY_STORE_NAME: string = 'aiphone_aggregate_search_policy_store';
const AGGREGATE_DOMESTIC_ONLY_KEY: string = 'only_domestic_sources';
const AGGREGATE_MULTILINGUAL_KEY: string = 'include_multilingual_results';
const ANYTHING_DEMO_ROUTE_URL: string = 'pages/A2uiHome/AnythingDemo';
const MOVIE_DEMO_ROUTE_URL: string = 'pages/A2uiHome/MovieDemo';
const UI_AGENT_LAB_ROUTE_URL: string = 'pages/A2uiHome/UiAgentLab';
const READ_CALENDAR_PERMISSION: Permissions = 'ohos.permission.READ_CALENDAR';
const WRITE_CALENDAR_PERMISSION: Permissions = 'ohos.permission.WRITE_CALENDAR';
const APPROX_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PRECISE_LOCATION_PERMISSION: Permissions = 'ohos.permission.LOCATION';
const LOCATION_SERVICE_DISABLED_NOTICE: string = '定位服务未开启，附近结果可能不够准确。';

interface RegisteredPageToolObservation {
  result: A2uiCallResult | null;
}

function fingerprintPart(value: string): string {
  return value.length.toString() + ':' + value;
}

function opaqueSettingsDigest(value: string): string {
  let first = 0x811c9dc5;
  let second = 0x9e3779b9;
  for (let index = 0; index < value.length; index++) {
    const code = value.charCodeAt(index);
    first = Math.imul(first ^ code, 0x01000193);
    second = Math.imul(second ^ (code + index), 0x5bd1e995);
  }
  return (first >>> 0).toString(16) + '-' + (second >>> 0).toString(16);
}

export function hotelModelSettingsFingerprint(settings: LocalModelSettings): string {
  const material = fingerprintPart(settings.provider) + '|' +
    fingerprintPart(settings.baseUrl) + '|' +
    fingerprintPart(settings.apiKey) + '|' +
    fingerprintPart(settings.model) + '|' +
    fingerprintPart(settings.customParametersJson);
  return 'hotel-settings-v1:' + opaqueSettingsDigest(material);
}

export function hotelTurnReadyMessage(status: HotelTurnStatus, title: string): string {
  if (status === 'success') {
    return title + ' 已返回真实酒店结果。';
  }
  if (status === 'partial') {
    return title + ' 已返回部分酒店结果，请查看提示。';
  }
  if (status === 'empty') {
    return title + ' 查询完成，未找到符合条件的酒店。';
  }
  return '';
}

class PageHotelUriOpener implements SystemUriOpener {
  private readonly callback: (uri: string) => Promise<boolean>;

  constructor(callback: (uri: string) => Promise<boolean>) {
    this.callback = callback;
  }

  open(uri: string): Promise<boolean> {
    return this.callback(uri);
  }
}

class PageRegisteredToolInvoker implements RegisteredPageToolInvoker {
  private readonly callback: (
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ) => Promise<RegisteredPageToolInvocation>;

  constructor(callback: (
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ) => Promise<RegisteredPageToolInvocation>) {
    this.callback = callback;
  }

  invoke(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object
  ): Promise<RegisteredPageToolInvocation> {
    return this.callback(toolId, prompt, pageActionId, args);
  }
}

type RideActionArgValue = Object | string | number | boolean | null | undefined;

interface RideCachedProduct {
  productName: string;
  productCategory: string;
  priceText: string;
}

interface RideLocalOrderActionArgs {
  productCategory?: RideActionArgValue;
  product_category?: RideActionArgValue;
  productName?: RideActionArgValue;
  priceText?: RideActionArgValue;
  routeText?: RideActionArgValue;
  pickupLocation?: RideActionArgValue;
  originLocation?: RideActionArgValue;
  destinationLocation?: RideActionArgValue;
  estimateCacheJson?: RideActionArgValue;
  estimateTraceId?: RideActionArgValue;
  estimate_trace_id?: RideActionArgValue;
  traceId?: RideActionArgValue;
}

type HtmlActionValue = Object | string | number | boolean | null | undefined;

interface HtmlDynamicCredentialPayload {
  credentialRef?: HtmlActionValue;
  credentialValue?: HtmlActionValue;
  toolId?: HtmlActionValue;
  prompt?: HtmlActionValue;
}

interface MailCalendarUiEvent {
  sequence: number;
  requestKey: string;
  status: string;
  message: string;
  eventId: string;
  error: string;
}

interface MailCalendarActionArgs {
  requestKey?: HtmlActionValue;
  provider?: HtmlActionValue;
  threadId?: HtmlActionValue;
  messageId?: HtmlActionValue;
}

interface MailCalendarSuggestionSchemaText {
  isWorkRelated: string;
  hasMeeting: string;
  title: string;
  start: string;
  end: string;
  displayTime: string;
  timezone: string;
  location: string;
  description: string;
  confidence: string;
  reason: string;
}

interface MailReplyUiEvent {
  sequence: number;
  requestKey: string;
  operation: string;
  status: string;
  message: string;
  error: string;
}

interface MailReplyAiArgs {
  requestKey?: HtmlActionValue;
  provider?: HtmlActionValue;
  accountLabel?: HtmlActionValue;
  threadId?: HtmlActionValue;
  messageId?: HtmlActionValue;
  to?: HtmlActionValue;
  subject?: HtmlActionValue;
  replyMode?: HtmlActionValue;
  contextSummary?: HtmlActionValue;
}

interface HtmlPinPayload {
  calendarCollection?: HtmlActionValue;
  index?: HtmlActionValue;
  id?: HtmlActionValue;
  source?: HtmlActionValue;
  trainCode?: HtmlActionValue;
  flightNo?: HtmlActionValue;
  name?: HtmlActionValue;
  address?: HtmlActionValue;
  location?: HtmlActionValue;
  distance?: HtmlActionValue;
  depart?: HtmlActionValue;
  depTime?: HtmlActionValue;
  from?: HtmlActionValue;
  to?: HtmlActionValue;
  dep?: HtmlActionValue;
  arr?: HtmlActionValue;
  fromCode?: HtmlActionValue;
  toCode?: HtmlActionValue;
  travelDate?: HtmlActionValue;
}

interface SocialHubReplyPayload {
  text?: HtmlActionValue;
}

interface PaymentCheckoutActionPayload {
  provider?: HtmlActionValue;
  recipient?: HtmlActionValue;
  amountText?: HtmlActionValue;
  currency?: HtmlActionValue;
  note?: HtmlActionValue;
  checkoutUrl?: HtmlActionValue;
  providerSessionId?: HtmlActionValue;
}

interface TrainBookingActionPayload {
  bookingUrl?: HtmlActionValue;
}

interface TrainPresaleScheduleActionPayload {
  trainCode?: HtmlActionValue;
  travelDate?: HtmlActionValue;
  from?: HtmlActionValue;
  fromCode?: HtmlActionValue;
  to?: HtmlActionValue;
  toCode?: HtmlActionValue;
  saleAt?: HtmlActionValue;
}

interface StripeOnboardingActionPayload {
  onboardingUrl?: HtmlActionValue;
}

interface StripeReceivingSavedProfile {
  agentId: string;
  deviceId: string;
  displayName: string;
  email: string;
  country: string;
  businessType: string;
  stripeAccountId: string;
  status: string;
}

interface HtmlPaymentAccountPayload {
  displayName?: HtmlActionValue;
  aliases?: HtmlActionValue;
  paypalEmail?: HtmlActionValue;
  paypalMerchantId?: HtmlActionValue;
  stripeAccountId?: HtmlActionValue;
  stripePaymentLinkUrl?: HtmlActionValue;
}

interface PaymentCaptureArgs {
  provider: string;
  recipient: string;
  amountText: string;
  currency: string;
  note: string;
  phase: string;
  providerSessionId: string;
}

interface PaymentSavedPreviewArgs {
  accountId: string;
  recipient: string;
  provider: string;
  originalQuery: string;
}

interface PaymentFallbackArgs {
  provider: string;
  fundingSource: string;
  recipient: string;
  amountText: string;
  currency: string;
  note: string;
  originalQuery: string;
}

interface LuckinOrderStatusArgs {
  orderId: string;
}

interface LuckinPaymentStatusPatch {
  kind: 'payment-status';
  statusText: string;
  sectionId?: string;
}

interface FoodMenuPatch {
  kind: 'food-menu';
  brand: 'luckin' | 'mcdonalds';
  status: 'ready' | 'error';
  step?: 'menu' | 'detail' | 'quote' | 'order';
  requestKey: string;
  deptId: string;
  storeName: string;
  storeAddress: string;
  storeLocation: string;
  products: LuckinFoodMenuProduct[];
  error: string;
  selectedProductId?: string;
  selectedProductName?: string;
  selectedPictureUrl?: string;
  selectedPriceText?: string;
  quantity?: number;
  rows?: McDonaldsFoodMenuRow[];
  quoteToken?: string;
  canCreate?: boolean;
  orderId?: string;
  payUrl?: string;
  statusText?: string;
}

interface McDonaldsFoodMenuActionPayload {
  surfaceId?: Object | string | number | boolean | null;
  requestKey?: Object | string | number | boolean | null;
  productId?: Object | string | number | boolean | null;
  quantity?: Object | string | number | boolean | null;
  quoteToken?: Object | string | number | boolean | null;
  orderId?: Object | string | number | boolean | null;
}

interface McDonaldsFoodMenuQuoteContext {
  productId: string;
  quantity: number;
  takeWayCode: string;
  quoteToken: string;
}

interface McDonaldsFoodMenuContext {
  surfaceId: string;
  requestKey: string;
  storeCode: string;
  beCode: string;
  storeName: string;
  storeAddress: string;
  storeLocation: string;
  products: LuckinFoodMenuProduct[];
  quote: McDonaldsFoodMenuQuoteContext | null;
  orderId: string;
  payUrl: string;
}

interface LuckinFoodMenuOrderPayload {
  surfaceId?: Object | string | number | boolean | null;
  requestKey?: Object | string | number | boolean | null;
  deptId?: Object | string | number | boolean | null;
  deptName?: Object | string | number | boolean | null;
  address?: Object | string | number | boolean | null;
  location?: Object | string | number | boolean | null;
  productId?: Object | string | number | boolean | null;
  productName?: Object | string | number | boolean | null;
  skuCode?: Object | string | number | boolean | null;
  pictureUrl?: Object | string | number | boolean | null;
}

interface LuckinFoodMenuPreviewArgs {
  deptId: string;
  deptName: string;
  address: string;
  location: string;
  productId: string;
  productName: string;
  skuCode: string;
  pictureUrl: string;
  originalQuery: string;
  previewPrompt: string;
}

interface InlineLuckinPaymentStatusPlan {
  mode: 'single' | 'multi-task';
  slotId: string;
}

interface LuckinOptionSwitchPending {
  prompt: string;
  args: Object | null;
  actionId: string;
  runtimeOwner: RuntimeOwner;
}

interface MultiTaskToolCallContext {
  slotId: string;
  childSurfaceId: string;
}

interface LocationPermissionResult {
  permissions: string[];
  authResults: number[];
}

interface DeviceCoordinates {
  longitude: number;
  latitude: number;
}

interface FoodDeviceLocation extends DeviceCoordinates {
  name: string;
  address: string;
}

interface FoodRelocateSearchArea {
  longitude: number;
  latitude: number;
  radiusMeters: number;
  name: string;
  address: string;
}

interface FoodRelocateActionArgs {
  surfaceId: string;
  searchArea: FoodRelocateSearchArea;
}

function logSnippet(text: string): string {
  if (text.length <= LOG_SNIPPET_LIMIT) {
    return text;
  }
  return text.substring(0, LOG_SNIPPET_LIMIT) + '...<truncated>';
}

function modelPromptWithActionContext(prompt: string, actionId: string, args: Object | null): string {
  if (actionId.length === 0 && args === null) {
    return prompt;
  }
  return prompt + '\n\nAction ID: ' + actionId + '\nStructured action args JSON: ' +
    (args === null ? '{}' : JSON.stringify(args));
}

function stripMailReplyAiText(text: string): string {
  let value = text.trim();
  const finalAnswerIndex = value.lastIndexOf('final_answer:');
  if (finalAnswerIndex >= 0) {
    value = value.substring(finalAnswerIndex + 'final_answer:'.length).trim();
  }
  const finalIndex = value.lastIndexOf('Final:');
  if (finalIndex >= 0) {
    value = value.substring(finalIndex + 'Final:'.length).trim();
  }
  const modelIndex = value.lastIndexOf('MODEL:');
  if (modelIndex >= 0) {
    value = value.substring(modelIndex + 'MODEL:'.length).trim();
  }
  const errorIndex = value.indexOf('\nERROR:');
  if (errorIndex >= 0) {
    value = value.substring(0, errorIndex).trim();
  }
  if (value.startsWith('```')) {
    const firstBreak = value.indexOf('\n');
    const lastFence = value.lastIndexOf('```');
    if (firstBreak >= 0 && lastFence > firstBreak) {
      value = value.substring(firstBreak + 1, lastFence).trim();
    }
  }
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith('“') && value.endsWith('”'))) {
    value = value.substring(1, value.length - 1).trim();
  }
  return value;
}

function jsonObjectTextFromModel(text: string): string {
  let value = text.trim();
  const finalAnswerIndex = value.lastIndexOf('final_answer:');
  if (finalAnswerIndex >= 0) {
    value = value.substring(finalAnswerIndex + 'final_answer:'.length).trim();
  }
  const finalIndex = value.lastIndexOf('Final:');
  if (finalIndex >= 0) {
    value = value.substring(finalIndex + 'Final:'.length).trim();
  }
  if (value.startsWith('```')) {
    const firstBreak = value.indexOf('\n');
    const lastFence = value.lastIndexOf('```');
    if (firstBreak >= 0 && lastFence > firstBreak) {
      value = value.substring(firstBreak + 1, lastFence).trim();
    }
  }
  const left = value.indexOf('{');
  const right = value.lastIndexOf('}');
  if (left >= 0 && right > left) {
    return value.substring(left, right + 1);
  }
  return value;
}

function calendarPermissionGranted(permissions: string[], authResults: number[]): boolean {
  if (authResults.length === 0) {
    return false;
  }
  const readIndex = permissions.indexOf(READ_CALENDAR_PERMISSION);
  const writeIndex = permissions.indexOf(WRITE_CALENDAR_PERMISSION);
  if (permissions.length === 0) {
    return authResults.length >= 2 && authResults[0] === 0 && authResults[1] === 0;
  }
  return readIndex >= 0 && writeIndex >= 0 &&
    authResults.length > readIndex && authResults.length > writeIndex &&
    authResults[readIndex] === 0 && authResults[writeIndex] === 0;
}

function waterfallSourcesForContext(enabledSources: string[], availableSources: AggregateSearchSource[]): string[] {
  return enabledSources.filter((source: string): boolean =>
    availableSources.indexOf(source as AggregateSearchSource) >= 0);
}

@Entry
@Component
struct Index {
  @State showConfigPage: boolean = false;
  @State showComposioAuthPage: boolean = false;
  @State showAdvancedSettings: boolean = false;
  @State showHistory: boolean = false;
  @State baseUrl: string = defaultLocalModelSettings().baseUrl;
  @State apiKey: string = defaultLocalModelSettings().apiKey;
  @State selectedModel: string = defaultLocalModelSettings().model;
  @State customParametersJson: string = defaultLocalModelSettings().customParametersJson;
  @State aggregateDomesticOnly: boolean = DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources;
  @State aggregateMultilingual: boolean = DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults;
  @State foodProviderDelayEnabled: boolean = false;
  @State foodProviderDelayMs: string = '0';
  @State foodPartialThrottleMs: string = A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS.toString();
  @State ignoreToolSurfaceUpdates: boolean = false;
  @State htmlHomeDebugExportEnabled: boolean = false;
  @State htmlHomeDebugExportPath: string = '';
  @State didiMcpSandboxEnabled: boolean = rideDidiMcpSandboxEnabledForRuntime();
  @State isBusy: boolean = false;
  @State connectionStatus: string = initialConnectionState.connectionStatus;
  @State connectionMessage: string = initialConnectionState.connectionMessage;
  @State lastModelRequest: string = initialConnectionState.lastModelRequest;
  @State lastModelOutput: string = initialConnectionState.lastModelOutput;
  @State lastError: string = initialConnectionState.lastError;
  @State refreshTick: number = initialConnectionState.refreshTick;
  @State currentSurface: A2uiSurfaceState = initialSurface;
  @State surfaceRenderTick: number = 0;
  @State isAwaitingFirstSurface: boolean = false;
  @State pendingFirecrawlToolId: string = '';
  @State inputText: string = '';
  @State bimRootIndex: number = 0;
  @State showBimPage: boolean = false;
  @State selectedBimId: string = '';
  @State bimInputText: string = '';
  @State bimRecords: BimRecord[] = [];
  @State selectedBimRecordSnapshot: BimRecord | null = null;
  @State bimDetailRenderTick: number = 0;
  @State bimLoading: boolean = true;
  @State bimStoreError: string = '';
  @State bimUiError: string = '';
  @State bimReduceMotion: boolean = false;
  @State bimSuggestionTitle: string = '';
  @State bimSuggestionReason: string = '';
  @State bimRememberState: BimRememberState = 'ready';
  @State bimRememberError: string = '';
  @State isVoiceListening: boolean = false;
  @State voiceInputMessage: string = '';
  @State waterfallConversationMessage: string = '';
  @State waterfallConversationBusy: boolean = false;
  @State showCheckoutWeb: boolean = false;
  @State checkoutWebKind: CheckoutWebKind = 'payment';
  @State checkoutWebUrl: string = '';
  @State checkoutWebContext: string = '';
  @State trainPresaleCheckoutTaskId: string = '';
  @State showTrainPresalePanel: boolean = false;
  @State showDeepSearch: boolean = false;
  @State deepSearchQuery: string = '';
  @State deepSearchSettingsJson: string = '';
  @State deepSearchContextJson: string = '';
  @State trainPresaleTrip: TrainPresaleTrip = emptyTrainPresaleTrip();
  @State trainPresaleTaskState: string = '';
  @State trainPresaleError: string = '';
  @State trainPresaleWorking: boolean = false;
  @State isDebugBuild: boolean = false;
  @State paymentCheckoutProvider: string = '';
  @State paymentCheckoutProviderSessionId: string = '';
  @State paymentCheckoutRecipient: string = '';
  @State paymentCheckoutAmountText: string = '';
  @State paymentCheckoutCurrency: string = '';
  @State paymentCheckoutNote: string = '';
  @State inputPlaceholder: string = DEFAULT_INPUT_PLACEHOLDER;
  @State messages: A2uiMessage[] = [];
  @State personaPacks: PersonaPack[] = allPersonaPacks();
  @State selectedPersonaId: string = 'food_companion';
  @State personaSoulDraft: string = personaPackForId('food_companion').soul;
  @State personaMemoryDraft: string = personaPackForId('food_companion').memory;
  @State personaSaveMessage: string = '';
  @State composioUserId: string = '';
  @State composioAuthItems: ComposioAuthConfigItem[] = [];
  @State composioAuthMessage: string = '';
  @State composioAuthBusy: boolean = false;
  @State showPublicPersonaPage: boolean = false;
  @State publicPersonaPhase: PublicPersonaPhase = 'input';
  @State publicPersonaCandidates: PublicPersonaCandidate[] = [];
  @State publicPersonaProgress: PublicPersonaProgress | null = null;
  @State publicPersonaSnapshot: PublicPersonaSnapshot | null = null;
  @State publicPersonaRenderTick: number = 0;
  @State publicPersonaError: string = '';
  private publicPersonaJobId: number = 0;
  private publicPersonaInitialized: boolean = false;
  private readonly publicPersonaClient: PublicPersonaClient = new PublicPersonaClient();
  @State mailDetailEventJson: string = '';
  @State mailReplyEventJson: string = '';
  @State mailCalendarEventJson: string = '';
  private mailCalendarSuggestions: Record<string, MailCalendarSuggestion> = {};
  private travelConflictRefreshGeneration: number = 0;
  private htmlHomeCacheKey: string = '';
  private htmlHomeCacheHtml: string = '';
  private promptSubmitMotionGeneration: number = 0;
  private renderedPromptSubmitMotionGeneration: number = 0;
  private readonly registeredPageSnapshotStore: RegisteredPageSnapshotStore =
    new RegisteredPageSnapshotStore();
  private registeredPageRenderGeneration: number = 0;
  @State htmlHomeStableHtml: string = '';
  @State foodLocationLongitude: number = 114.063873;
  @State foodLocationLatitude: number = 22.631273;
  @State foodLocationRadiusMeters: number = 3000;
  @State foodLocationName: string = '坂田';
  @State foodLocationAddress: string = '深圳市龙岗区坂田街道';
  @State locationServiceNotice: string = '';
  private foodLocationOwnerSurfaceId: string = '';
  @State foodStoreMapOpen: boolean = false;
  @State foodStoreMapSnapshotJson: string = '';
  @State foodStoreMapSnapshotTick: number = 0;
  private foodStoreMapOwnerSurfaceId: string = '';
  private foodSavedAddresses: FoodSavedAddressViewModel[] = [];
  private foodAddressBookStoreInstance: FoodAddressBookStore | null = null;
  private foodFavorites: FoodFavoriteViewModel[] = [];
  private foodFavoritesStoreInstance: FoodFavoritesStore | null = null;
  @State multiTaskPayloadJson: string = '';
  @State multiTaskShellHtml: string = '';
  @State multiTaskPayloadTick: number = 0;
  @State waterfallPayloadJson: string = '';
  @State waterfallPayloadTick: number = 0;
  @State waterfallBackRequestTick: number = 0;
  @State waterfallFullscreen: boolean = false;
  @State interestWaterfallFullscreen: boolean = false;
  @State interestWaterfallHtml: string = '';
  @State interestWaterfallPayloadJson: string = '';
  @State interestWaterfallPayloadTick: number = 0;
  @State interestWaterfallBackRequestTick: number = 0;
  private waterfallShellHtml: string = '';
  private waterfallShellSurfaceId: string = '';
  private waterfallFeedState: WaterfallFeedState | null = null;
  private waterfallFeedSurfaceId: string = '';
  private dailyBriefSnapshot: DailyBriefSnapshot | null = null;
  private dailyBriefGeneration: number = 0;
  private dailyBriefCatchUpPending: boolean = false;
  private waterfallContinuationBatchIndex: number = 100;
  private interestWaterfallFeedState: WaterfallFeedState | null = null;
  private interestWaterfallSearchSnapshot: WaterfallFeedState | null = null;
  private interestRecallStarted: boolean = false;
  private interestRecallRound: number = 0;
  private interestExplorationSources: string[] = [];
  private interestWaterfallGeneration: number = 0;
  private interestSourceRequestSeq: Map<string, number> = new Map<string, number>();
  private waterfallConversationState: WaterfallConversationState = { history: [], rules: [], summary: '' };
  private waterfallPreferencesStoreInstance: WaterfallPreferencesStore | null = null;
  private waterfallPreferenceProfile: WaterfallPreferenceProfile = emptyWaterfallPreferenceProfile();
  private waterfallCardRecords: WaterfallCardRecord[] = [];
  private waterfallReactionProjection: WaterfallReactionProjection = {
    topicWeights: [], sourceWeights: [], formatWeights: []
  };
  private waterfallSessionTopicWeights: WaterfallPreferenceWeight[] = [];
  private waterfallSessionSourceWeights: WaterfallPreferenceWeight[] = [];
  private waterfallSessionFormatWeights: WaterfallPreferenceWeight[] = [];
  private waterfallSessionEvidence: WaterfallBehaviorEvidence[] = [];
  private multiTaskActiveSectionId: string = '';
  private multiTaskUserPinnedSection: boolean = false;
  private multiTaskLastMergedRawBySlot: Record<string, string> = {};
  private voiceSession: VoiceInputSession | null = null;
  private voiceSessionSeq: number = 0;
  private voiceBaseInputText: string = '';
  private voiceStopRequested: boolean = false;
  private voiceCompletionHandled: boolean = false;
  private voiceTarget: 'home' | 'waterfall' = 'home';
  private luckinReturnSurface: A2uiSurfaceState | null = null;
  private hotelReturnSurface: A2uiSurfaceState | null = null;
  private multiAgentRuntime: MultiAgentCanaryRuntime | null = null;
  private phoneLocalMemoryRuntime: PhoneLocalMemoryRuntime | null = null;
  private phoneLocalMemoryAvailability: PhoneLocalMemoryAvailabilityPort | null = null;
  private bimStoreInstance: BimStore | null = null;
  private bimCuratorTail: Promise<void> = Promise.resolve();
  private pendingBimEvidence: BimTurnEvidence | null = null;
  @State bimSentinelBusy: boolean = false;
  private bimRootController: SwiperController = new SwiperController();
  private readonly bimAnimationReduceHandler = (enabled: boolean): void => {
    this.bimReduceMotion = enabled;
  };
  private multiAgentModel: LocalModel | null = null;
  private readonly sessionContextCompactor: SessionContextCompactor =
    new SessionContextCompactor((): LocalModel => this.canaryModel());
  private hotelAgentRuntimeFingerprint: string = '';
  private runtimeGeneration: number = 0;
  private readonly mailDetailSuggestionGuard: MailDetailSuggestionGuard =
    new MailDetailSuggestionGuard();
  private activeRuntimeOwner: RuntimeOwner = 'legacy';
  @State luckinInlinePatchJson: string = '';
  @State luckinInlinePatchTick: number = 0;
  private luckinFoodMenuContext: FoodMenuPatch | null = null;
  private mcDonaldsFoodMenuContext: McDonaldsFoodMenuContext | null = null;
  private mcDonaldsFoodMenuQuoteSequence: number = 0;
  private luckinOptionSwitchInFlight: boolean = false;
  private luckinOptionSwitchSeq: number = 0;
  private luckinOptionSwitchPending: LuckinOptionSwitchPending | null = null;
  private trainPresaleTask: TrainPresaleTask | null = null;
  private trainPresaleResumeDrain: TrainPresaleResumeDrain | null = null;
  private trainPresaleHandoffSubscribed: boolean = false;
  private readonly trainPresaleHandoffListener = (): void => {
    this.refreshBoundTrainPresaleCheckoutTask();
    this.requestPendingTrainPresaleResume();
  };
  private waterfallConversationTypedTestSubscribed: boolean = false;
  private readonly waterfallConversationTypedTestListener = (payload: Object): void => {
    this.submitWaterfallConversationTypedTest((payload as WaterfallConversationTypedTestPayload).prompt);
  };
  private bimSentinelMockSubscribed: boolean = false;
  private readonly bimSentinelMockListener = (): void => {
    this.requestPendingBimSentinelMock();
  };

  private isLuckinOptionSwitchArgs(args: Object | null): boolean {
    if (args === null) {
      return false;
    }
    const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
    return this.actionText(raw.attrGroup).length > 0 && this.actionText(raw.attrChoice).length > 0;
  }

  private isLuckinStoreSelectArgs(args: Object | null): boolean {
    if (args === null) {
      return false;
    }
    const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
    return this.actionText(raw.deptId).length > 0;
  }

  private shouldBypassRegisteredPageForLuckinAction(action: A2uiAction): boolean {
    if (action.id === 'luckin.order.create' || action.id === 'luckin.order.status') {
      return true;
    }
    if (action.id !== 'luckin.order.preview') {
      return false;
    }
    const args: Object | null = action.args === undefined ? null : action.args;
    if (this.isLuckinOptionSwitchArgs(args) || this.isLuckinStoreSelectArgs(args)) {
      return true;
    }
    if (!isMultiTaskSurface(this.currentSurface)) {
      return false;
    }
    const sectionId: string = action.sourceSectionId === undefined ? '' : action.sourceSectionId.trim();
    return sectionId.length > 0;
  }

  private luckinConfirmBlockJson(document: HtmlHomeDocument): string {
    for (let index = 0; index < document.blocks.length; index++) {
      if (document.blocks[index].title.indexOf('确认瑞幸订单') >= 0) {
        return JSON.stringify(document.blocks[index]);
      }
    }
    return '';
  }

  private applyLuckinInlineConfirmPatch(surface: A2uiSurfaceState): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    const patchJson = this.luckinConfirmBlockJson(document);
    if (patchJson.length === 0) {
      return false;
    }
    this.storeSurfaceSilently(surface);
    this.htmlHomeCacheKey = this.currentHtmlHomeCacheKey();
    this.htmlHomeCacheHtml = renderHtmlHomeDocument(document, false);
    this.luckinInlinePatchJson = patchJson;
    this.luckinInlinePatchTick = this.luckinInlinePatchTick + 1;
    this.recordRenderedPageSnapshot(surface, document);
    return true;
  }

  private parseSurfaceDataModel(surface: A2uiSurfaceState): A2uiRuntimeDataModel | null {
    try {
      return JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return null;
    }
  }

  private isLuckinPaymentResult(result: A2uiGenericToolResultData): boolean {
    const title = this.actionText(result.title).trim();
    const toolName = this.actionText(result.toolName).trim();
    return title.indexOf('瑞幸订单已创建') >= 0 || toolName === 'luckin.order.create';
  }

  private isLuckinStatusResult(result: A2uiGenericToolResultData): boolean {
    const title = this.actionText(result.title).trim();
    const toolName = this.actionText(result.toolName).trim();
    return toolName === 'luckin.order.status' || title.indexOf('瑞幸订单状态') >= 0;
  }

  private rowValueByLabel(rows: A2uiLabelValueData[], label: string): string {
    for (let index = 0; index < rows.length; index += 1) {
      if (rows[index].label === label) {
        return this.actionText(rows[index].value).trim();
      }
    }
    return '';
  }

  private upsertRow(rows: A2uiLabelValueData[], label: string, value: string): A2uiLabelValueData[] {
    const next = rows.slice();
    for (let index = 0; index < next.length; index += 1) {
      if (next[index].label === label) {
        next[index] = { label: label, value: value };
        return next;
      }
    }
    if (value.length > 0) {
      next.push({ label: label, value: value });
    }
    return next;
  }

  private luckinOrderStatusTextFromResult(result: A2uiGenericToolResultData): string {
    const fromRow = this.rowValueByLabel(result.rows, '订单状态');
    if (fromRow.length > 0) {
      return fromRow;
    }
    const summary = this.actionText(result.summary).trim();
    if (summary.length > 0 && summary !== '已返回订单状态') {
      return summary;
    }
    return '待支付';
  }

  private findLuckinToolResult(results: A2uiGenericToolResultData[], matcher: (result: A2uiGenericToolResultData) => boolean):
    A2uiGenericToolResultData | null {
    for (let index = 0; index < results.length; index += 1) {
      if (matcher(results[index])) {
        return results[index];
      }
    }
    return null;
  }

  private mergeLuckinPaymentStatusSurface(paymentSurface: A2uiSurfaceState, statusSurface: A2uiSurfaceState): A2uiSurfaceState | null {
    const paymentModel = this.parseSurfaceDataModel(paymentSurface);
    const statusModel = this.parseSurfaceDataModel(statusSurface);
    if (paymentModel === null || statusModel === null) {
      return null;
    }
    const paymentResults = paymentModel.genericToolResults ?? [];
    const statusResults = statusModel.genericToolResults ?? [];
    const paymentResult = this.findLuckinToolResult(paymentResults, (result: A2uiGenericToolResultData) => {
      return this.isLuckinPaymentResult(result);
    });
    const statusResult = this.findLuckinToolResult(statusResults, (result: A2uiGenericToolResultData) => {
      return this.isLuckinStatusResult(result);
    });
    if (paymentResult === null || statusResult === null) {
      return null;
    }
    let rows = paymentResult.rows.slice();
    const statusText = this.luckinOrderStatusTextFromResult(statusResult);
    rows = this.upsertRow(rows, '订单状态', statusText);
    const payUrl = this.rowValueByLabel(statusResult.rows, '支付链接');
    const payQr = this.rowValueByLabel(statusResult.rows, '支付二维码');
    if (payUrl.length > 0) {
      rows = this.upsertRow(rows, '支付链接', payUrl);
    }
    if (payQr.length > 0) {
      rows = this.upsertRow(rows, '支付二维码', payQr);
    }
    const mergedResult: A2uiGenericToolResultData = {
      sourceTag: paymentResult.sourceTag,
      toolName: paymentResult.toolName,
      title: paymentResult.title,
      status: paymentResult.status,
      summary: paymentResult.summary,
      rows: rows,
      rawPreview: statusResult.rawPreview.length > 0 ? statusResult.rawPreview : paymentResult.rawPreview
    };
    const nextResults: A2uiGenericToolResultData[] = [];
    paymentResults.forEach((result: A2uiGenericToolResultData) => {
      nextResults.push(this.isLuckinPaymentResult(result) ? mergedResult : result);
    });
    const statusComponent = componentById(statusSurface, 'results');
    const statusActions = statusComponent === null ? [] : actionsOf(statusComponent);
    const nextComponents: A2uiComponent[] = [];
    paymentSurface.components.forEach((component: A2uiComponent) => {
      if (component.id === 'results' && statusActions.length > 0) {
        nextComponents.push({
          id: component.id,
          component: component.component,
          child: component.child,
          children: component.children,
          title: component.title,
          body: component.body,
          status: component.status,
          dataPath: component.dataPath,
          actions: statusActions
        });
        return;
      }
      nextComponents.push(component);
    });
    const nextModel = paymentModel;
    nextModel.genericToolResults = nextResults;
    const nextSurface = this.surfaceSnapshot(paymentSurface);
    nextSurface.components = nextComponents;
    nextSurface.dataModelJson = JSON.stringify(nextModel);
    nextSurface.sequence = Math.max(paymentSurface.sequence, statusSurface.sequence) + 1;
    return nextSurface;
  }

  private luckinPaymentStatusPatchFromSurface(statusSurface: A2uiSurfaceState, sectionId: string = ''): LuckinPaymentStatusPatch | null {
    const statusResults = genericToolResults(statusSurface);
    const statusResult = this.findLuckinToolResult(statusResults, (result: A2uiGenericToolResultData) => {
      return this.isLuckinStatusResult(result);
    });
    if (statusResult === null) {
      return null;
    }
    const patch: LuckinPaymentStatusPatch = {
      kind: 'payment-status',
      statusText: this.luckinOrderStatusTextFromResult(statusResult)
    };
    if (sectionId.length > 0) {
      patch.sectionId = sectionId;
    }
    return patch;
  }

  private publishLuckinPaymentStatusPatch(patch: LuckinPaymentStatusPatch): void {
    this.luckinInlinePatchJson = JSON.stringify(patch);
    this.luckinInlinePatchTick = this.luckinInlinePatchTick + 1;
    aiLogInfo('[AIPhone][LuckinPaymentStatusPatch] status=' + patch.statusText +
      ' sectionId=' + (patch.sectionId ?? ''));
  }

  private applyLuckinInlinePaymentStatusPatch(paymentSurface: A2uiSurfaceState, statusSurface: A2uiSurfaceState): boolean {
    const mergedSurface = this.mergeLuckinPaymentStatusSurface(paymentSurface, statusSurface);
    if (mergedSurface === null) {
      return false;
    }
    const patch = this.luckinPaymentStatusPatchFromSurface(statusSurface);
    if (patch === null) {
      return false;
    }
    this.storeSurfaceSilently(mergedSurface);
    this.htmlHomeCacheKey = this.currentHtmlHomeCacheKey();
    this.htmlHomeCacheHtml = renderHtmlHomeDocument(createHtmlHomeDocument({
      surface: mergedSurface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    }), false);
    this.publishLuckinPaymentStatusPatch(patch);
    return true;
  }

  private embeddedSurfaceFromMultiTaskSlot(surface: A2uiSurfaceState, slotId: string): A2uiSurfaceState | null {
    try {
      const parsed = JSON.parse(surface.dataModelJson) as Record<string, Object | null | undefined>;
      const sectionsValue = parsed.sections;
      if (sectionsValue === undefined || sectionsValue === null ||
        typeof sectionsValue !== 'object' || Array.isArray(sectionsValue)) {
        return null;
      }
      const sections = sectionsValue as Record<string, Record<string, Object | string | number | boolean | null | undefined>>;
      const section = sections[slotId];
      if (section === undefined) {
        return null;
      }
      const embedded = section.embeddedSurface;
      if (embedded === undefined || embedded === null || typeof embedded !== 'object' || Array.isArray(embedded)) {
        return null;
      }
      const record = embedded as Record<string, Object | string | number | boolean | null | undefined>;
      const surfaceId = this.actionText(record.surfaceId).trim();
      if (surfaceId.length === 0) {
        return null;
      }
      const embeddedSurface: A2uiSurfaceState = {
        surfaceId: surfaceId,
        rootId: this.actionText(record.rootId).trim().length > 0 ? this.actionText(record.rootId).trim() : 'root',
        title: this.actionText(record.title).trim(),
        intent: this.actionText(record.intent).trim().length > 0 ? this.actionText(record.intent).trim() : 'general',
        status: this.actionText(record.status).trim().length > 0 ? this.actionText(record.status).trim() : 'ready',
        components: Array.isArray(record.components) ? record.components as A2uiComponent[] : [],
        dataModelJson: this.actionText(record.dataModelJson).trim().length > 0 ? this.actionText(record.dataModelJson).trim() : '{}',
        error: this.actionText(record.error).trim(),
        sequence: typeof record.sequence === 'number' ? record.sequence as number : 0
      };
      return embeddedSurface;
    } catch (_error) {
      return null;
    }
  }

  private mergeLuckinPaymentStatusIntoMultiTaskSurface(
    composite: A2uiSurfaceState,
    slotId: string,
    statusSurface: A2uiSurfaceState
  ): A2uiSurfaceState | null {
    const paymentSurface = this.embeddedSurfaceFromMultiTaskSlot(composite, slotId);
    if (paymentSurface === null) {
      return null;
    }
    const mergedEmbedded = this.mergeLuckinPaymentStatusSurface(paymentSurface, statusSurface);
    if (mergedEmbedded === null) {
      return null;
    }
    try {
      const parsed = JSON.parse(composite.dataModelJson) as Record<string, Object | null | undefined>;
      const sectionsValue = parsed.sections;
      if (sectionsValue === undefined || sectionsValue === null ||
        typeof sectionsValue !== 'object' || Array.isArray(sectionsValue)) {
        return null;
      }
      const sections = sectionsValue as Record<string, Record<string, Object | string | number | boolean | null | undefined>>;
      const section = sections[slotId];
      if (section === undefined) {
        return null;
      }
      section.embeddedSurface = mergedEmbedded as Object;
      const patch = this.luckinPaymentStatusPatchFromSurface(statusSurface);
      if (patch !== null) {
        section.summary = patch.statusText;
      }
      sections[slotId] = section;
      parsed.sections = sections as Object;
      const nextSurface = this.surfaceSnapshot(composite);
      nextSurface.dataModelJson = JSON.stringify(parsed);
      nextSurface.sequence = composite.sequence + 1;
      return nextSurface;
    } catch (_error) {
      return null;
    }
  }

  private applyLuckinInlineMultiTaskPaymentStatusPatch(
    composite: A2uiSurfaceState,
    slotId: string,
    statusSurface: A2uiSurfaceState
  ): boolean {
    const mergedSurface = this.mergeLuckinPaymentStatusIntoMultiTaskSurface(composite, slotId, statusSurface);
    if (mergedSurface === null) {
      return false;
    }
    const patch = this.luckinPaymentStatusPatchFromSurface(statusSurface, slotId);
    if (patch === null) {
      return false;
    }
    this.storeSurfaceSilently(mergedSurface);
    this.htmlHomeCacheKey = this.currentHtmlHomeCacheKey();
    this.publishLuckinPaymentStatusPatch(patch);
    return true;
  }

  private inlineLuckinPaymentStatusPlan(
    toolId: string,
    surface: A2uiSurfaceState,
    multiTaskCtx: MultiTaskToolCallContext | null
  ): InlineLuckinPaymentStatusPlan | null {
    if (toolId !== 'luckin.order.status') {
      return null;
    }
    if (multiTaskCtx === null) {
      if (this.hasLuckinPaymentBlockInSurface(surface)) {
        return { mode: 'single', slotId: '' };
      }
      return null;
    }
    if (this.hasLuckinPaymentBlockInMultiTaskSlot(surface, multiTaskCtx.slotId)) {
      return { mode: 'multi-task', slotId: multiTaskCtx.slotId };
    }
    return null;
  }

  private finishLuckinOptionSwitch(inFlight: boolean = false): void {
    this.luckinOptionSwitchInFlight = inFlight;
    if (inFlight) {
      return;
    }
    const pending = this.luckinOptionSwitchPending;
    if (pending === null) {
      return;
    }
    this.luckinOptionSwitchPending = null;
    void this.callToolById(
      'luckin.order.preview',
      pending.prompt,
      pending.actionId,
      pending.args,
      undefined,
      pending.runtimeOwner
    );
  }

  private clearLuckinOptionSwitchQueue(): void {
    this.luckinOptionSwitchPending = null;
    this.luckinOptionSwitchInFlight = false;
  }

  private syncFoodLocationOwner(surface: A2uiSurfaceState): void {
    if (surface.intent !== 'food' || surface.surfaceId.length === 0) {
      this.foodLocationOwnerSurfaceId = '';
      this.foodStoreMapOwnerSurfaceId = '';
      this.foodStoreMapOpen = false;
      this.foodStoreMapSnapshotJson = '';
      return;
    }
    const sessionCreated = this.foodLocationOwnerSurfaceId !== surface.surfaceId;
    this.foodLocationOwnerSurfaceId = surface.surfaceId;
    if (this.foodStoreMapOwnerSurfaceId !== surface.surfaceId) {
      this.foodStoreMapOwnerSurfaceId = surface.surfaceId;
      this.foodStoreMapOpen = false;
    }
    let locationUpdated = false;
    try {
      const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
      if (model.foodSearchContext !== undefined) {
        const area = model.foodSearchContext.searchArea;
        locationUpdated = this.foodLocationLongitude !== area.longitude ||
          this.foodLocationLatitude !== area.latitude ||
          this.foodLocationRadiusMeters !== area.radiusMeters ||
          this.foodLocationName !== area.name ||
          this.foodLocationAddress !== area.address;
        this.foodLocationLongitude = area.longitude;
        this.foodLocationLatitude = area.latitude;
        this.foodLocationRadiusMeters = area.radiusMeters;
        this.foodLocationName = area.name;
        this.foodLocationAddress = area.address;
      }
    } catch (_error) {
    }
    if (sessionCreated || locationUpdated) {
      this.htmlHomeCacheKey = '';
      this.htmlHomeCacheHtml = '';
      aiLogInfo('[AIPhone][' + (sessionCreated ? 'FoodLocationSessionCreated' : 'FoodLocationSessionUpdated') +
        '] surfaceId=' + surface.surfaceId +
        ' longitude=' + this.foodLocationLongitude.toString() +
        ' latitude=' + this.foodLocationLatitude.toString() +
        ' radiusMeters=' + this.foodLocationRadiusMeters.toString());
    }
  }

  private syncFoodStoreMapSnapshot(surface: A2uiSurfaceState): void {
    if (surface.intent !== 'food' || surface.surfaceId !== this.foodStoreMapOwnerSurfaceId) {
      return;
    }
    const snapshotJson = JSON.stringify(buildFoodStoreMapSnapshot(
      surface,
      this.foodLocationLongitude,
      this.foodLocationLatitude,
      this.foodLocationName,
      this.foodLocationAddress
    ));
    if (snapshotJson === this.foodStoreMapSnapshotJson) {
      return;
    }
    this.foodStoreMapSnapshotJson = snapshotJson;
    this.foodStoreMapSnapshotTick = this.foodStoreMapSnapshotTick + 1;
  }

  private storeSurfaceSilently(surface: A2uiSurfaceState): void {
    this.currentSurface = this.surfaceSnapshot(surface);
    this.syncFoodLocationOwner(this.currentSurface);
    this.syncFoodStoreMapSnapshot(this.currentSurface);
    aiLogInfo('[AIPhone][A2uiHomeSurfaceSilentUpdate] surfaceId=' + surface.surfaceId +
      ' sequence=' + surface.sequence.toString());
  }

  private stripMultiTaskEmbedsForShell(document: HtmlHomeDocument): HtmlHomeDocument {
    const blocks: HtmlHomeBlock[] = [];
    document.blocks.forEach((block: HtmlHomeBlock) => {
      if (block.kind !== 'multi-task-section') {
        blocks.push(block);
        return;
      }
      blocks.push({
        id: block.id,
        kind: block.kind,
        title: block.title,
        subtitle: block.subtitle,
        status: block.status,
        source: block.source,
        toolId: block.toolId,
        sectionId: block.sectionId,
        rawPreview: block.rawPreview,
        metrics: block.metrics,
        rows: block.rows,
        actions: block.actions
      });
    });
    return {
      version: document.version,
      source: document.source,
      kind: document.kind,
      title: document.title,
      subtitle: document.subtitle,
      chips: document.chips,
      metrics: document.metrics,
      timeline: document.timeline,
      blocks: blocks,
      actions: document.actions,
      history: document.history,
      persona: document.persona,
      personaMemory: document.personaMemory,
      rawSurfaceRoot: document.rawSurfaceRoot,
      activeSectionId: '',
      generatedAt: document.generatedAt
    };
  }

  private ensureMultiTaskShellHtml(document: HtmlHomeDocument): void {
    if (this.multiTaskShellHtml.length > 0) {
      return;
    }
    const shellDocument = this.stripMultiTaskEmbedsForShell(document);
    this.multiTaskShellHtml = renderHtmlHomeDocument(shellDocument, false);
  }

  private syncMultiTaskPayloadUpdate(document: HtmlHomeDocument): void {
    if (document.kind !== 'multi-task') {
      this.multiTaskPayloadJson = '';
      return;
    }
    const payload = buildMultiTaskHomePayload(document, this.isBusy);
    this.multiTaskPayloadJson = JSON.stringify(payload);
    this.multiTaskPayloadTick = this.multiTaskPayloadTick + 1;
  }

  private ensureWaterfallShellHtml(document: HtmlHomeDocument): void {
    const surfaceId = document.surfaceId ?? '';
    if (this.waterfallShellHtml.length > 0 && this.waterfallShellSurfaceId === surfaceId) {
      return;
    }
    this.waterfallShellHtml = renderAggregateSearchHomeDocument(document, false, false, true);
    this.waterfallShellSurfaceId = surfaceId;
  }

  private publishWaterfallPayload(document: HtmlHomeDocument): void {
    const payload = buildWaterfallHomePayload(
      document, this.isBusy, this.waterfallFeedState, this.waterfallCardRecords);
    this.waterfallPayloadJson = payload === null ? '' : JSON.stringify(payload);
    this.waterfallPayloadTick = this.waterfallPayloadTick + 1;
  }

  private interestWaterfallDocument(): HtmlHomeDocument {
    const current = this.currentHtmlHomeDocument();
    return {
      version: 1,
      surfaceId: 'waterfall-interest-home',
      source: 'tool',
      kind: 'aggregate-search',
      title: '发现流',
      subtitle: '',
      chips: [],
      metrics: [],
      timeline: [],
      blocks: [],
      actions: [],
      history: [],
      persona: current.persona,
      personaMemory: current.personaMemory,
      rawSurfaceRoot: null,
      waterfall: this.interestWaterfallFeedState ?? undefined,
      generatedAt: new Date().toISOString()
    };
  }

  private publishInterestWaterfallPayload(): void {
    const payload = buildWaterfallHomePayload(
      this.interestWaterfallDocument(), false, this.interestWaterfallFeedState, this.waterfallCardRecords);
    this.interestWaterfallPayloadJson = payload === null ? '' : JSON.stringify(payload);
    this.interestWaterfallPayloadTick = this.interestWaterfallPayloadTick + 1;
  }

  private interestSourceState(result: WaterfallInterestRecallBatch): WaterfallSourceState {
    let phase: WaterfallSourcePhase = 'error';
    if (result.batch.status.status === 'success') {
      phase = result.batch.continuation === null ? 'exhausted' : 'success';
    } else if (result.batch.status.status === 'empty') {
      phase = 'exhausted';
    } else if (result.batch.status.status === 'needs_auth') {
      phase = 'needs_auth';
    }
    return {
      source: result.batch.source,
      phase,
      continuation: result.batch.continuation,
      inFlight: false,
      reservedCount: 0,
      message: result.batch.status.message,
      query: result.request.query,
      recallRoute: result.request.route,
      loadMode: result.request.route === 'popular' ? 'native' : 'search'
    };
  }

  private recentPositiveWaterfallCandidates(): WaterfallRankedCandidate[] {
    const candidates: WaterfallRankedCandidate[] = [];
    for (let index = this.waterfallSessionEvidence.length - 1; index >= 0 && candidates.length < 3; index -= 1) {
      const evidence = this.waterfallSessionEvidence[index];
      if (evidence.behavior === 'quick_skip' || candidates.some(
        (candidate: WaterfallRankedCandidate): boolean => candidate.id === evidence.candidateId)) {
        continue;
      }
      const candidate = this.waterfallCandidate(evidence.candidateId, this.waterfallFeedState) ??
        this.waterfallCandidate(evidence.candidateId, this.interestWaterfallFeedState);
      if (candidate !== null) candidates.push(candidate);
    }
    return candidates;
  }

  private applyInterestWaterfallUpdate(update: WaterfallFeedUpdate): void {
    this.interestWaterfallFeedState = update.state;
    this.publishInterestWaterfallPayload();
    if (update.loadRequests.length > 0) {
      if (update.state.mode === 'search') {
        this.runInterestSearchRequests(update.loadRequests);
        return;
      }
      const requests: WaterfallInterestRecallRequest[] = update.loadRequests.map(
        (request: WaterfallLoadRequest): WaterfallInterestRecallRequest => ({
          route: request.route ?? 'explore',
          query: request.query ?? '',
          sources: [request.source],
          weight: 1,
          continuation: request.continuation
        }));
      this.runInterestRecallRequests(requests);
      return;
    }
    if (update.expansionRequest !== undefined) {
      this.runInterestWaterfallExpansion(update.expansionRequest);
      return;
    }
    this.runNextInterestExplorationIfNeeded();
  }

  private runInterestWaterfallExpansion(request: WaterfallQueryExpansionRequest): void {
    const generation = this.interestWaterfallGeneration;
    this.canaryModel().complete(waterfallExpansionPrompt(request)).then((raw: string): void => {
      const state = this.interestWaterfallFeedState;
      if (generation !== this.interestWaterfallGeneration || state === null || state.mode !== 'search') return;
      const query = parseWaterfallExpandedQuery(raw, state.query);
      this.applyInterestWaterfallUpdate(query.length > 0 ?
        applyWaterfallExpandedQuery(state, request.stage, query, Date.now()) :
        failWaterfallExpansion(state, request.stage));
    }).catch((error: Error): void => {
      const state = this.interestWaterfallFeedState;
      if (generation !== this.interestWaterfallGeneration || state === null || state.mode !== 'search') return;
      aiLogError('[AIPhone][WaterfallDiscoveryExpansionFailed] stage=' + request.stage +
        ' error=' + error.message.substring(0, 240));
      this.applyInterestWaterfallUpdate(failWaterfallExpansion(state, request.stage));
    });
  }

  private runNextInterestExplorationIfNeeded(): void {
    const state = this.interestWaterfallFeedState;
    if (state === null || state.mode === 'search' || this.interestRecallRound >= 3 || state.sources.some(
      (source: WaterfallSourceState): boolean => source.inFlight || source.phase === 'loading')) return;
    let active = state.current !== null && state.enabledSources.indexOf(state.current.source) >= 0 ? 1 : 0;
    active += state.stable.filter((candidate: WaterfallRankedCandidate): boolean =>
      state.enabledSources.indexOf(candidate.source) >= 0).length;
    active += state.tail.filter((candidate: WaterfallRankedCandidate): boolean =>
      state.enabledSources.indexOf(candidate.source) >= 0).length;
    if (active > 8) return;
    const sources = this.interestExplorationSources.filter((source: string): boolean =>
      state.enabledSources.indexOf(source) >= 0);
    if (sources.length > 0) this.runInterestRecall(sources);
  }

  private runInterestRecallRequests(requests: WaterfallInterestRecallRequest[]): void {
    if (requests.length === 0 || this.interestWaterfallFeedState === null) return;
    const generation = this.interestWaterfallGeneration;
    const requestedSources: string[] = [];
    requests.forEach((request: WaterfallInterestRecallRequest): void => {
      request.sources.forEach((source: string): void => {
        if (requestedSources.indexOf(source) < 0) requestedSources.push(source);
      });
    });
    const requestSequences: Map<string, number> = new Map<string, number>();
    requestedSources.forEach((source: string): void => {
      const sequence = (this.interestSourceRequestSeq.get(source) ?? 0) + 1;
      this.interestSourceRequestSeq.set(source, sequence);
      requestSequences.set(source, sequence);
    });
    const policy = waterfallSearchPolicyForRuntime();
    aiLogInfo('[AIPhone][WaterfallInterestRecallStart] generation=' + generation.toString() +
      ' requests=' + requests.length.toString() +
      ' domesticOnly=' + (policy.domesticOnly ? 'true' : 'false') +
      ' multilingual=' + (policy.multilingual ? 'true' : 'false'));
    callConfiguredWaterfallInterestRecall(requests, (result: WaterfallInterestRecallBatch): void => {
      let current = this.interestWaterfallFeedState;
      if (current === null || generation !== this.interestWaterfallGeneration) return;
      const source = result.batch.source;
      if (requestSequences.get(source) !== this.interestSourceRequestSeq.get(source)) return;
      const explorationIndex = this.interestExplorationSources.indexOf(source);
      if (result.request.route !== 'popular' && result.batch.status.status === 'success' &&
        result.batch.continuation === null) {
        if (explorationIndex < 0) this.interestExplorationSources.push(source);
      } else if (result.batch.status.status !== 'success' && explorationIndex >= 0) {
        this.interestExplorationSources.splice(explorationIndex, 1);
      }
      aiLogInfo('[AIPhone][WaterfallInterestRecallBatch] source=' + source +
        ' status=' + result.batch.status.status +
        ' count=' + result.candidates.length.toString() +
        ' route=' + result.request.route + ' query=' + result.request.query);
      current = mergeWaterfallBatchDeferredRanking(
        current, result.candidates, this.interestSourceState(result)).state;
      this.interestWaterfallFeedState = current;
      this.publishInterestWaterfallPayload();
    }).then((): void => {
      let current = this.interestWaterfallFeedState;
      if (current === null || generation !== this.interestWaterfallGeneration) return;
      current.sources.forEach((source: WaterfallSourceState): void => {
        if (requestedSources.indexOf(source.source) >= 0 &&
          requestSequences.get(source.source) === this.interestSourceRequestSeq.get(source.source) &&
          (source.inFlight || source.phase === 'loading')) {
          source.phase = 'exhausted';
          source.inFlight = false;
          source.continuation = null;
          source.reservedCount = 0;
        }
      });
      current = finalizeInterestWaterfallRecallRanking(current, Date.now());
      this.interestWaterfallFeedState = current;
      this.applyInterestWaterfallUpdate(planWaterfallContinuation(current));
      aiLogInfo('[AIPhone][WaterfallInterestRecallReady] generation=' + generation.toString());
    }).catch((error: Error): void => {
      const current = this.interestWaterfallFeedState;
      if (current !== null && generation === this.interestWaterfallGeneration) {
        current.sources.forEach((source: WaterfallSourceState): void => {
          if (requestedSources.indexOf(source.source) >= 0 &&
            requestSequences.get(source.source) === this.interestSourceRequestSeq.get(source.source) &&
            (source.inFlight || source.phase === 'loading')) {
            source.phase = 'error';
            source.inFlight = false;
            source.message = '内容补充失败';
          }
        });
        const finalized = finalizeInterestWaterfallRecallRanking(current, Date.now());
        this.interestWaterfallFeedState = finalized;
        this.applyInterestWaterfallUpdate(planWaterfallContinuation(finalized));
      }
      aiLogError('[AIPhone][WaterfallInterestRecallFailed] generation=' + generation.toString() +
        ' error=' + error.message.substring(0, 240));
    });
  }

  private runInterestRecall(sources: string[] | null = null): void {
    const state = this.interestWaterfallFeedState;
    if (state === null) return;
    const enabledSources = waterfallSourcesForContext(
      sources === null ? state.enabledSources : sources, aggregateSearchInterestSourceIds());
    state.sources.forEach((source: WaterfallSourceState): void => {
      if (enabledSources.indexOf(source.source) < 0 || state.enabledSources.indexOf(source.source) < 0) return;
      source.phase = 'loading';
      source.inFlight = true;
      source.continuation = null;
      source.message = '正在补充内容';
    });
    this.publishInterestWaterfallPayload();
    const requests = planWaterfallInterestRecall(
      this.currentWaterfallPreferenceProfile(), this.recentPositiveWaterfallCandidates(),
      enabledSources, this.interestRecallRound++);
    this.runInterestRecallRequests(requests);
  }

  private runInterestSearchRequests(requests: WaterfallLoadRequest[]): void {
    const generation = this.interestWaterfallGeneration;
    const query = this.interestWaterfallFeedState?.query ?? '';
    callConfiguredAggregateSearchContinuation(query, requests, (batch: AggregateSearchSourceBatch): void => {
      if (generation !== this.interestWaterfallGeneration || this.interestWaterfallFeedState?.mode !== 'search') {
        return;
      }
      this.interestWaterfallFeedState = mergeAggregateSearchContinuationBatch(
        this.interestWaterfallFeedState,
        batch,
        this.waterfallContinuationBatchIndex++,
        Date.now()
      );
      this.publishInterestWaterfallPayload();
    }).then((): void => {
      if (generation !== this.interestWaterfallGeneration || this.interestWaterfallFeedState?.mode !== 'search') {
        return;
      }
      this.applyInterestWaterfallUpdate(planWaterfallContinuation(this.interestWaterfallFeedState));
    }).catch((error: Error): void => {
      aiLogError('[AIPhone][WaterfallDiscoverySearchFailed] generation=' + generation.toString() +
        ' error=' + error.message.substring(0, 240));
    });
  }

  private startInterestWaterfallSearch(query: string): void {
    const current = this.interestWaterfallFeedState;
    if (current === null) return;
    if (this.interestWaterfallSearchSnapshot === null) this.interestWaterfallSearchSnapshot = current;
    this.interestWaterfallGeneration += 1;
    const allSources = aggregateSearchSearchSourceIds();
    const enabledSources = waterfallSourcesForContext(current.enabledSources, allSources);
    this.interestWaterfallFeedState = {
      mode: 'search',
      query,
      originalQuery: query,
      queryStage: 'original',
      queryHistory: [query],
      consecutiveEmptyRounds: 0,
      roundNewItemCount: 0,
      roundActive: true,
      expansionInFlight: false,
      enabledSources,
      preferenceDescription: '',
      profile: this.currentWaterfallPreferenceProfile(),
      shown: [],
      current: null,
      stable: [],
      tail: [],
      reserve: [],
      sources: allSources.map((source: string): WaterfallSourceState => ({
        source,
        phase: enabledSources.indexOf(source) >= 0 ? 'loading' : 'exhausted',
        continuation: null,
        inFlight: enabledSources.indexOf(source) >= 0,
        reservedCount: enabledSources.indexOf(source) >= 0 ? 10 : 0,
        message: enabledSources.indexOf(source) >= 0 ? '正在搜索' : ''
      }))
    };
    this.publishInterestWaterfallPayload();
    this.runInterestSearchRequests(enabledSources.map((source: string): WaterfallLoadRequest => ({
      source,
      continuation: null,
      limit: 10,
      phase: 'loading',
      message: '正在搜索',
      mode: 'search'
    })));
  }

  private exitInterestWaterfallSearch(): void {
    if (this.interestWaterfallSearchSnapshot === null) return;
    this.interestWaterfallGeneration += 1;
    const snapshot = this.interestWaterfallSearchSnapshot;
    this.interestWaterfallSearchSnapshot = null;
    const enabledSources = waterfallSourcesForContext(
      this.waterfallPreferenceProfile.discoveryEnabledSources, aggregateSearchInterestSourceIds());
    const restored = applyWaterfallSourceSelection(snapshot, enabledSources, Date.now()).state;
    restored.profile = this.currentWaterfallPreferenceProfile();
    this.interestWaterfallFeedState = restored;
    this.publishInterestWaterfallPayload();
    const recallSources = enabledSources.filter((source: string): boolean =>
      snapshot.enabledSources.indexOf(source) < 0);
    restored.sources.filter((source: WaterfallSourceState): boolean =>
      restored.enabledSources.indexOf(source.source) >= 0 && (source.inFlight || source.phase === 'loading'))
      .forEach((source: WaterfallSourceState): void => {
        if (recallSources.indexOf(source.source) < 0) recallSources.push(source.source);
      });
    if (recallSources.length > 0) this.runInterestRecall(recallSources);
  }

  private ensureInterestWaterfall(startRecall: boolean = true): void {
    if (this.interestWaterfallFeedState === null) {
      this.interestWaterfallGeneration += 1;
      this.interestRecallRound = 0;
      this.interestExplorationSources = [];
      const interestSources = aggregateSearchInterestSourceIds();
      const enabledSources = waterfallSourcesForContext(
        this.waterfallPreferenceProfile.discoveryEnabledSources, interestSources);
      this.interestWaterfallFeedState = {
        mode: 'interest',
        interestFallbackStarted: true,
        query: '',
        originalQuery: '',
        queryStage: 'done',
        queryHistory: [],
        enabledSources,
        preferenceDescription: '',
        profile: this.currentWaterfallPreferenceProfile(),
        shown: [],
        current: null,
        stable: [],
        tail: [],
        reserve: [],
        sources: interestSources.map(
          (source: string): WaterfallSourceState => ({
          source,
          phase: enabledSources.indexOf(source) >= 0 ? 'loading' : 'exhausted',
          continuation: null,
          inFlight: enabledSources.indexOf(source) >= 0,
          reservedCount: 0,
          message: '正在汇集内容'
        }))
      };
      const document = this.interestWaterfallDocument();
      this.interestWaterfallHtml = renderAggregateSearchHomeDocument(document, false, true);
      this.publishInterestWaterfallPayload();
    }
    if (startRecall && !this.interestRecallStarted) {
      this.interestRecallStarted = true;
      this.runInterestRecall();
    }
  }

  private applyWaterfallUpdate(document: HtmlHomeDocument, update: WaterfallFeedUpdate): void {
    this.waterfallFeedState = update.state;
    this.publishWaterfallPayload(document);
    if (update.loadRequests.length > 0) {
      this.runWaterfallContinuation(document, update.loadRequests);
    } else if (update.expansionRequest !== undefined) {
      this.runWaterfallExpansion(document, update.expansionRequest);
    }
  }

  private runWaterfallExpansion(document: HtmlHomeDocument, request: WaterfallQueryExpansionRequest): void {
    const surfaceId = document.surfaceId ?? '';
    aiLogInfo('[AIPhone][WaterfallExpansionStart] stage=' + request.stage);
    this.canaryModel().complete(waterfallExpansionPrompt(request)).then((raw: string): void => {
      if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
        return;
      }
      const query = parseWaterfallExpandedQuery(raw, this.waterfallFeedState.query);
      if (query.length === 0) {
        aiLogError('[AIPhone][WaterfallExpansionInvalid] stage=' + request.stage);
        this.applyWaterfallUpdate(document, failWaterfallExpansion(this.waterfallFeedState, request.stage));
        return;
      }
      aiLogInfo('[AIPhone][WaterfallExpansionReady] stage=' + request.stage + ' queryChars=' + query.length.toString());
      this.applyWaterfallUpdate(
        document,
        applyWaterfallExpandedQuery(this.waterfallFeedState, request.stage, query, Date.now())
      );
    }).catch((error: Error): void => {
      if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
        return;
      }
      aiLogError('[AIPhone][WaterfallExpansionFailed] stage=' + request.stage +
        ' error=' + error.message.substring(0, 240));
      this.applyWaterfallUpdate(document, failWaterfallExpansion(this.waterfallFeedState, request.stage));
    });
  }

  private runWaterfallContinuation(document: HtmlHomeDocument, requests: WaterfallLoadRequest[]): void {
    const surfaceId = document.surfaceId ?? '';
    const networkRequests = requests.filter((request: WaterfallLoadRequest): boolean =>
      request.mode === 'search' || request.continuation !== null).length;
    aiLogInfo('[AIPhone][WaterfallContinuationRound] sources=' + requests.length.toString() +
      ' network=' + networkRequests.toString() + ' queryStage=' +
      (this.waterfallFeedState?.queryStage ?? 'original'));
    callConfiguredAggregateSearchContinuation(
      this.waterfallFeedState?.query ?? '',
      requests,
      (batch: AggregateSearchSourceBatch): void => {
        if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
          return;
        }
        this.waterfallFeedState = mergeAggregateSearchContinuationBatch(
          this.waterfallFeedState,
          batch,
          this.waterfallContinuationBatchIndex,
          Date.now()
        );
        this.waterfallContinuationBatchIndex++;
        aiLogInfo('[AIPhone][WaterfallContinuationBatch] source=' + batch.source +
          ' count=' + (batch.videos.length + batch.posts.length).toString() +
          ' hasNext=' + (batch.continuation === null ? 'false' : 'true'));
        this.publishWaterfallPayload(document);
      }
    ).then((): void => {
      if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
        return;
      }
      this.applyWaterfallUpdate(document, planWaterfallContinuation(this.waterfallFeedState));
    }).catch((error: Error): void => {
      aiLogError('[AIPhone][WaterfallContinuationFailed] error=' + error.message.substring(0, 240));
    });
  }

  private syncWaterfallPayloadUpdate(document: HtmlHomeDocument): void {
    if (document.kind !== 'aggregate-search' || document.waterfall === undefined) {
      this.waterfallPayloadJson = '';
      this.waterfallFeedState = null;
      this.waterfallFeedSurfaceId = '';
      return;
    }
    const surfaceId = document.surfaceId ?? '';
    if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
      this.waterfallFeedState = document.waterfall;
      this.waterfallFeedSurfaceId = surfaceId;
      this.waterfallContinuationBatchIndex = 100;
    } else {
      this.waterfallFeedState = mergeWaterfallFeedSnapshot(
        this.waterfallFeedState,
        document.waterfall,
        Date.now(),
        false
      ).state;
    }
    this.applyWaterfallUpdate(document, planWaterfallContinuation(this.waterfallFeedState));
  }

  private handleWaterfallClientAction(action: A2uiAction): boolean {
    if (action.id !== 'waterfall.sources.select' && action.id !== 'waterfall.feed.advance' &&
      action.id !== 'waterfall.behavior.record' && action.id !== 'waterfall.card.action' &&
      action.id !== 'waterfall.applepodcasts.resolve' && action.id !== 'waterfall.comments.load') {
      return false;
    }
    const document = this.currentHtmlHomeDocument();
    if (document.kind !== 'aggregate-search' || document.waterfall === undefined) {
      this.logHtmlHomeActionError(action, 'waterfall_surface_required');
      return true;
    }
    const surfaceId = document.surfaceId ?? '';
    if (this.waterfallFeedState === null || this.waterfallFeedSurfaceId !== surfaceId) {
      this.waterfallFeedState = document.waterfall;
      this.waterfallFeedSurfaceId = surfaceId;
    }
    if (action.id === 'waterfall.card.action') {
      const cardAction = waterfallCardActionFromAction(action, surfaceId);
      const candidate = cardAction === null ? null : this.waterfallActionCandidate(
        cardAction.candidateId, this.waterfallFeedState);
      if (cardAction === null || candidate === null) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_card_action');
        return true;
      }
      this.applyWaterfallCardAction(candidate, cardAction);
      return true;
    }
    if (action.id === 'waterfall.applepodcasts.resolve') {
      const candidateId = waterfallApplePodcastCandidateFromAction(action, surfaceId);
      const candidate = candidateId === null ? null : this.waterfallCandidate(candidateId, this.waterfallFeedState);
      if (candidateId === null || candidate === null || candidate.source !== 'applepodcasts' ||
        (candidate.feedUrl ?? '').trim().length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_apple_podcast_candidate');
        return true;
      }
      this.resolveApplePodcastCandidate('search', surfaceId, candidate);
      return true;
    }
    if (action.id === 'waterfall.comments.load') {
      const candidateId = waterfallCommentsCandidateFromAction(action, surfaceId);
      const candidate = candidateId === null ? null : this.waterfallActionCandidate(
        candidateId, this.waterfallFeedState);
      if (candidate === null || !waterfallCommentSourceSupported(candidate.source) ||
        (candidate.providerItemId ?? '').trim().length === 0 || candidate.commentLoadState !== undefined) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_comments_candidate');
        return true;
      }
      this.resolveWaterfallComments('search', surfaceId, candidate);
      return true;
    }
    if (action.id === 'waterfall.sources.select') {
      const selectedSources = waterfallEnabledSourcesFromAction(action, surfaceId);
      if (selectedSources === null) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_source_selection');
        return true;
      }
      const searchEnabledSources = waterfallSourcesForContext(selectedSources, aggregateSearchSearchSourceIds());
      const feedState = this.waterfallFeedState as WaterfallFeedState;
      const next = applyWaterfallSourceSelection(
        feedState,
        searchEnabledSources,
        Date.now()
      );
      this.applyWaterfallUpdate(document, next);
      return true;
    }
    if (action.id === 'waterfall.behavior.record') {
      const behavior = waterfallBehaviorFromAction(action, surfaceId);
      const candidate = behavior === null ? null : this.waterfallCandidate(
        behavior.candidateId, this.waterfallFeedState);
      if (behavior === null || candidate === null) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_behavior');
        return true;
      }
      this.recordWaterfallBehavior(candidate, behavior);
      return true;
    }
    const currentId = waterfallAdvanceCurrentFromAction(action, surfaceId);
    const visibleId = waterfallAdvanceVisibleFromAction(action, surfaceId);
    const current = this.waterfallFeedState.current;
    const targetId = visibleId ?? '';
    if (current === null || (currentId !== null && current.id !== currentId && targetId.length === 0)) {
      this.logHtmlHomeActionError(action, 'stale_waterfall_current');
      return true;
    }
    this.applyWaterfallUpdate(document, advanceWaterfallFeed(this.waterfallFeedState, Date.now(), targetId));
    return true;
  }

  private handleInterestWaterfallClientAction(action: A2uiAction): void {
    const state = this.interestWaterfallFeedState;
    const surfaceId = 'waterfall-interest-home';
    if (action.id === 'waterfall.home.back') {
      this.bimRootController.changeIndex(0, !this.bimReduceMotion);
      return;
    }
    if (action.id === 'waterfall.conversation.submit') {
      if (action.kind === 'client') this.submitWaterfallConversationTypedTest(action.prompt);
      return;
    }
    if (action.id === 'waterfall.search.submit') {
      const query = waterfallSearchQueryFromAction(action, surfaceId);
      if (query === null || state === null) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_search');
      } else {
        this.startInterestWaterfallSearch(query);
      }
      return;
    }
    if (action.id === 'waterfall.search.exit') {
      if (!waterfallSearchExitFromAction(action, surfaceId)) {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_search_exit');
      } else {
        this.exitInterestWaterfallSearch();
      }
      return;
    }
    if (state === null) return;
    if (action.id === 'waterfall.card.action') {
      const cardAction = waterfallCardActionFromAction(action, surfaceId);
      const candidate = cardAction === null ? null : this.waterfallActionCandidate(cardAction.candidateId, state);
      if (cardAction !== null && candidate !== null) this.applyWaterfallCardAction(candidate, cardAction);
      return;
    }
    if (action.id === 'waterfall.applepodcasts.resolve') {
      const candidateId = waterfallApplePodcastCandidateFromAction(action, surfaceId);
      const candidate = candidateId === null ? null : this.waterfallCandidate(candidateId, state);
      if (candidate !== null && candidate.source === 'applepodcasts' &&
        (candidate.feedUrl ?? '').trim().length > 0) {
        this.resolveApplePodcastCandidate('interest', surfaceId, candidate);
      } else {
        this.logHtmlHomeActionError(action, 'invalid_apple_podcast_candidate');
      }
      return;
    }
    if (action.id === 'waterfall.comments.load') {
      const candidateId = waterfallCommentsCandidateFromAction(action, surfaceId);
      const candidate = candidateId === null ? null : this.waterfallActionCandidate(candidateId, state);
      if (candidate !== null && waterfallCommentSourceSupported(candidate.source) &&
        (candidate.providerItemId ?? '').trim().length > 0 && candidate.commentLoadState === undefined) {
        this.resolveWaterfallComments('interest', surfaceId, candidate);
      } else {
        this.logHtmlHomeActionError(action, 'invalid_waterfall_comments_candidate');
      }
      return;
    }
    if (action.id === 'waterfall.sources.select') {
      const selectedSources = waterfallEnabledSourcesFromAction(action, surfaceId);
      if (selectedSources === null) return;
      const interestEnabledSources = waterfallSourcesForContext(
        selectedSources, aggregateSearchInterestSourceIds());
      const addedSources = interestEnabledSources.filter((source: string): boolean =>
        state.enabledSources.indexOf(source) < 0);
      this.waterfallPreferenceProfile = this.waterfallPreferencesStore().saveDiscoveryEnabledSources(
        interestEnabledSources);
      configureWaterfallEnabledSourcesForRuntime(interestEnabledSources as AggregateSearchSource[]);
      const update = applyWaterfallSourceSelection(state, interestEnabledSources, Date.now());
      const plannedSources = update.loadRequests.map((request: WaterfallLoadRequest): string => request.source);
      const recallSources = addedSources.filter((source: string): boolean => plannedSources.indexOf(source) < 0);
      this.applyInterestWaterfallUpdate(update);
      if (recallSources.length > 0) this.runInterestRecall(recallSources);
      return;
    }
    if (action.id === 'waterfall.behavior.record') {
      const behavior = waterfallBehaviorFromAction(action, surfaceId);
      const candidate = behavior === null ? null : this.waterfallCandidate(behavior.candidateId, state);
      if (behavior !== null && candidate !== null) this.recordWaterfallBehavior(candidate, behavior);
      return;
    }
    if (action.id === 'waterfall.feed.advance') {
      const currentId = waterfallAdvanceCurrentFromAction(action, surfaceId);
      const visibleId = waterfallAdvanceVisibleFromAction(action, surfaceId);
      if (state.current === null) return;
      const targetId = visibleId ?? '';
      if (currentId !== null && state.current.id !== currentId && targetId.length === 0) return;
      this.applyInterestWaterfallUpdate(advanceWaterfallFeed(state, Date.now(), targetId));
    }
  }

  private submitWaterfallConversationTypedTest(rawPrompt: string): void {
    const prompt = rawPrompt.trim();
    if (!this.isDebugBuild || this.interestWaterfallFeedState === null || this.bimRootIndex !== 1 ||
      this.interestWaterfallFullscreen || this.waterfallConversationBusy || this.isVoiceListening ||
      prompt.length === 0 || prompt.length > 240) {
      aiLogInfo('[AIPhone][WaterfallConversationRejected] reason=invalid_debug_prompt');
      return;
    }
    aiLogInfo('[AIPhone][WaterfallConversationTypedTest] promptChars=' + prompt.length.toString());
    void this.submitWaterfallConversation(prompt);
  }

  private waterfallCandidate(
    candidateId: string,
    state: WaterfallFeedState | null
  ): WaterfallRankedCandidate | null {
    if (state === null) return null;
    const values = state.shown.concat(
      state.current === null ? [] : [state.current], state.stable, state.tail, state.reserve ?? []);
    for (let index = 0; index < values.length; index += 1) {
      if (values[index].id === candidateId) return values[index];
    }
    return null;
  }

  private waterfallActionCandidate(candidateId: string, state: WaterfallFeedState | null): WaterfallCandidate | null {
    const active = this.waterfallCandidate(candidateId, state);
    if (active !== null) return active;
    for (let index = 0; index < this.waterfallCardRecords.length; index += 1) {
      if (this.waterfallCardRecords[index].candidateId === candidateId) {
        return waterfallCandidateFromSavedCard(this.waterfallCardRecords[index].snapshot);
      }
    }
    return null;
  }

  private applyWaterfallCardAction(candidate: WaterfallCandidate, args: WaterfallCardActionArgs): void {
    this.waterfallCardRecords = this.waterfallPreferencesStore().applyCardAction(
      candidate, args.action, args.active, Date.now(), args.restoreSavedAt);
    this.waterfallReactionProjection = waterfallReactionWeights(this.waterfallCardRecords);
    const current = this.currentHtmlHomeDocument();
    if (args.action === 'save') {
      if (this.waterfallFeedState !== null && current.kind === 'aggregate-search' &&
        (current.surfaceId ?? '') === this.waterfallFeedSurfaceId) this.publishWaterfallPayload(current);
      if (this.interestWaterfallFeedState !== null) this.publishInterestWaterfallPayload();
      return;
    }
    configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
    if (this.waterfallFeedState !== null && current.kind === 'aggregate-search' &&
      (current.surfaceId ?? '') === this.waterfallFeedSurfaceId) {
      this.applyWaterfallUpdate(current, applyWaterfallProfile(
        this.waterfallFeedState, this.currentWaterfallPreferenceProfile(false), Date.now()));
    }
    if (this.interestWaterfallFeedState !== null) {
      this.applyInterestWaterfallUpdate(applyWaterfallProfile(
        this.interestWaterfallFeedState, this.currentWaterfallPreferenceProfile(), Date.now()));
    }
  }

  private activeWaterfallCandidate(
    target: 'search' | 'interest',
    surfaceId: string,
    candidateId: string,
    runtimeOwner: RuntimeOwner,
    runtimeGeneration: number,
    interestGeneration: number
  ): WaterfallCandidate | null {
    if (target === 'search') {
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, runtimeGeneration)) return null;
      const document = this.currentHtmlHomeDocument();
      if (this.waterfallFeedSurfaceId !== surfaceId || document.kind !== 'aggregate-search' ||
        (document.surfaceId ?? '') !== surfaceId) return null;
    } else if (surfaceId !== 'waterfall-interest-home' ||
      this.interestWaterfallGeneration !== interestGeneration) {
      return null;
    }
    const state = target === 'search' ? this.waterfallFeedState : this.interestWaterfallFeedState;
    return this.waterfallActionCandidate(candidateId, state);
  }

  private activeApplePodcastCandidate(
    target: 'search' | 'interest',
    surfaceId: string,
    candidateId: string,
    feedUrl: string,
    runtimeOwner: RuntimeOwner,
    runtimeGeneration: number,
    interestGeneration: number
  ): WaterfallCandidate | null {
    const candidate = this.activeWaterfallCandidate(
      target, surfaceId, candidateId, runtimeOwner, runtimeGeneration, interestGeneration);
    return candidate !== null && candidate.source === 'applepodcasts' &&
      (candidate.feedUrl ?? '').trim() === feedUrl ? candidate : null;
  }

  private publishWaterfallCandidate(target: 'search' | 'interest', surfaceId: string): void {
    if (target === 'interest') {
      if (surfaceId === 'waterfall-interest-home') this.publishInterestWaterfallPayload();
      return;
    }
    const document = this.currentHtmlHomeDocument();
    if (this.waterfallFeedSurfaceId === surfaceId && document.kind === 'aggregate-search' &&
      (document.surfaceId ?? '') === surfaceId) this.publishWaterfallPayload(document);
  }

  private resolveApplePodcastCandidate(
    target: 'search' | 'interest',
    surfaceId: string,
    candidate: WaterfallRankedCandidate
  ): void {
    const feedUrl = (candidate.feedUrl ?? '').trim();
    if (feedUrl.length === 0 || candidate.audioLoadState === 'loading') return;
    const candidateId = candidate.id;
    const runtimeOwner = this.activeRuntimeOwner;
    const runtimeGeneration = this.runtimeGeneration;
    const interestGeneration = this.interestWaterfallGeneration;
    candidate.audioLoadState = 'loading';
    candidate.audioError = '';
    candidate.audioRetryable = true;
    this.publishWaterfallCandidate(target, surfaceId);
    aiLogInfo('[AIPhone][ApplePodcastResolve] phase=loading surface=' + surfaceId + ' candidate=' + candidateId);
    resolveApplePodcastEpisode(feedUrl).then((episode: ApplePodcastEpisodeAudio): void => {
      const current = this.activeApplePodcastCandidate(
        target, surfaceId, candidateId, feedUrl, runtimeOwner, runtimeGeneration, interestGeneration);
      if (current === null) {
        aiLogInfo('[AIPhone][ApplePodcastResolve] phase=stale surface=' + surfaceId + ' candidate=' + candidateId);
        return;
      }
      current.mediaUrl = episode.mediaUrl;
      current.audioTitle = episode.audioTitle;
      current.audioMimeType = episode.audioMimeType;
      current.audioDuration = episode.audioDuration;
      current.audioPublishedAt = episode.audioPublishedAt;
      current.audioLoadState = 'ready';
      current.audioError = '';
      current.audioRetryable = false;
      this.publishWaterfallCandidate(target, surfaceId);
      aiLogInfo('[AIPhone][ApplePodcastResolve] phase=ready surface=' + surfaceId + ' candidate=' + candidateId);
    }).catch((error: Error): void => {
      const current = this.activeApplePodcastCandidate(
        target, surfaceId, candidateId, feedUrl, runtimeOwner, runtimeGeneration, interestGeneration);
      if (current === null) return;
      const failure: ApplePodcastResolverFailure = applePodcastResolverFailure(error);
      current.audioLoadState = 'error';
      current.audioError = failure.message;
      current.audioRetryable = failure.retryable;
      this.publishWaterfallCandidate(target, surfaceId);
      aiLogError('[AIPhone][ApplePodcastResolve] phase=error surface=' + surfaceId + ' candidate=' + candidateId +
        ' code=' + failure.code);
    });
  }

  private resolveWaterfallComments(
    target: 'search' | 'interest',
    surfaceId: string,
    candidate: WaterfallCandidate
  ): void {
    const providerItemId = (candidate.providerItemId ?? '').trim();
    if (providerItemId.length === 0 || candidate.commentLoadState !== undefined) return;
    const candidateId = candidate.id;
    const source = candidate.source as AggregateSearchSource;
    const runtimeOwner = this.activeRuntimeOwner;
    const runtimeGeneration = this.runtimeGeneration;
    const interestGeneration = this.interestWaterfallGeneration;
    candidate.commentLoadState = 'loading';
    this.persistSavedWaterfallCandidate(candidate);
    this.publishWaterfallCandidate(target, surfaceId);
    callConfiguredWaterfallComments(source, providerItemId).then((result: WaterfallCommentsResult): void => {
      const current = this.activeWaterfallCandidate(
        target, surfaceId, candidateId, runtimeOwner, runtimeGeneration, interestGeneration);
      if (current === null || current.source !== source ||
        (current.providerItemId ?? '').trim() !== providerItemId) return;
      current.comments = result.comments.slice(0, 5);
      current.commentLoadState = current.comments.length > 0 ? 'ready' :
        (result.state === 'error' ? 'error' : 'empty');
      this.persistSavedWaterfallCandidate(current);
      this.publishWaterfallCandidate(target, surfaceId);
    }).catch((_error: Error): void => {
      const current = this.activeWaterfallCandidate(
        target, surfaceId, candidateId, runtimeOwner, runtimeGeneration, interestGeneration);
      if (current === null || current.source !== source ||
        (current.providerItemId ?? '').trim() !== providerItemId) return;
      current.comments = [];
      current.commentLoadState = 'error';
      this.persistSavedWaterfallCandidate(current);
      this.publishWaterfallCandidate(target, surfaceId);
    });
  }

  private persistSavedWaterfallCandidate(candidate: WaterfallCandidate): void {
    const saved = this.waterfallCardRecords.find((record: WaterfallCardRecord): boolean =>
      record.candidateId === candidate.id && record.saved);
    if (saved === undefined) return;
    this.waterfallCardRecords = this.waterfallPreferencesStore().applyCardAction(
      candidate, 'save', true, Date.now(), true);
  }

  private recordWaterfallBehavior(
    candidate: WaterfallRankedCandidate,
    args: WaterfallBehaviorActionArgs
  ): void {
    const format = candidate.format ?? (candidate.mediaType === 'video' ? 'landscape_video' :
      (candidate.mediaType === 'image_text' ? 'image_text' : 'text'));
    const event: WaterfallBehaviorEvidence = {
      candidateId: candidate.id,
      topics: (candidate.topics ?? []).slice(),
      source: candidate.source,
      format,
      behavior: args.behavior,
      durationMs: args.durationMs,
      timestamp: args.timestamp
    };
    const delta = waterfallBehaviorDelta(event, this.waterfallSessionEvidence);
    this.waterfallSessionEvidence.push(event);
    if (delta !== 0) {
      event.topics.forEach((topic: string): void => {
        updateWaterfallPreferenceWeight(this.waterfallSessionTopicWeights, topic, delta, event.timestamp);
      });
      updateWaterfallPreferenceWeight(this.waterfallSessionSourceWeights, event.source, delta, event.timestamp);
      updateWaterfallPreferenceWeight(this.waterfallSessionFormatWeights, event.format, delta, event.timestamp);
    }
    configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
    if (this.waterfallFeedState !== null) {
      this.waterfallFeedState.profile = this.currentWaterfallPreferenceProfile(false);
    }
    if (this.interestWaterfallFeedState !== null) {
      this.interestWaterfallFeedState.profile = this.currentWaterfallPreferenceProfile();
    }
    setTimeout((): void => {
      try {
        this.waterfallPreferenceProfile = this.waterfallPreferencesStore().recordBehavior(event);
        configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
        if (this.waterfallFeedState !== null) {
          this.waterfallFeedState.profile = this.currentWaterfallPreferenceProfile(false);
        }
        if (this.interestWaterfallFeedState !== null) {
          this.interestWaterfallFeedState.profile = this.currentWaterfallPreferenceProfile();
        }
      } catch (_error) {
        aiLogError('[AIPhone][WaterfallBehaviorRecord] ok=false candidateId=' + event.candidateId);
      }
    }, 0);
  }

  private scheduleMultiTaskPayloadRefresh(): void {
    if (!isMultiTaskSurface(this.currentSurface)) {
      return;
    }
    setTimeout((): void => {
      if (!isMultiTaskSurface(this.currentSurface)) {
        return;
      }
      const document = this.withMultiTaskActiveSection(this.currentHtmlHomeDocument());
      if (document.kind !== 'multi-task') {
        return;
      }
      this.syncMultiTaskPayloadUpdate(document);
      aiLogInfo('[AIPhone][MultiTaskPayloadRefresh] tick=' + this.multiTaskPayloadTick.toString() +
        ' blocks=' + document.blocks.length.toString() +
        ' active=' + (document.activeSectionId ?? '') +
        ' busy=' + (this.isBusy ? 'true' : 'false'));
    }, 0);
  }

  private syncHtmlHomeStableHtml(): void {
    const document = this.withMultiTaskActiveSection(this.currentHtmlHomeDocument());
    if (document.kind === 'multi-task') {
      this.ensureMultiTaskShellHtml(document);
      this.syncMultiTaskPayloadUpdate(document);
      return;
    }
    if (document.kind === 'aggregate-search' && document.waterfall !== undefined) {
      this.multiTaskShellHtml = '';
      this.ensureWaterfallShellHtml(document);
      this.syncWaterfallPayloadUpdate(document);
      return;
    }
    this.multiTaskShellHtml = '';
    this.waterfallShellHtml = '';
    this.waterfallShellSurfaceId = '';
    this.waterfallPayloadJson = '';
    this.waterfallFeedState = null;
    this.waterfallFeedSurfaceId = '';
    this.htmlHomeStableHtml = this.currentHtmlHomeHtml();
  }

  private hasLuckinConfirmBlockInSurface(surface: A2uiSurfaceState = this.currentSurface): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    return this.luckinConfirmBlockJson(document).length > 0;
  }

  private hasLuckinPaymentBlockInDocument(document: HtmlHomeDocument): boolean {
    for (let index = 0; index < document.blocks.length; index += 1) {
      if (document.blocks[index].title.indexOf('瑞幸订单已创建') >= 0) {
        return true;
      }
    }
    return false;
  }

  private hasLuckinPaymentBlockInSurface(surface: A2uiSurfaceState = this.currentSurface): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    return this.hasLuckinPaymentBlockInDocument(document);
  }

  private hasLuckinPaymentBlockInMultiTaskSlot(surface: A2uiSurfaceState, slotId: string): boolean {
    const document = createHtmlHomeDocument({
      surface: surface,
      messages: this.messages,
      isBusy: false,
      isAwaitingFirstSurface: false
    });
    if (document.kind !== 'multi-task') {
      return false;
    }
    for (let index = 0; index < document.blocks.length; index += 1) {
      const block = document.blocks[index];
      if (block.kind !== 'multi-task-section' || block.embeddedDocument === undefined) {
        continue;
      }
      const sectionId = (block.sectionId ?? block.id).trim();
      if (sectionId !== slotId) {
        continue;
      }
      if (this.hasLuckinPaymentBlockInDocument(block.embeddedDocument)) {
        return true;
      }
    }
    return false;
  }

  private shouldKeepLuckinConfirmWebHtmlStable(): boolean {
    return this.hasLuckinConfirmBlockInSurface();
  }

  private shouldKeepLuckinPaymentWebHtmlStable(): boolean {
    return this.hasLuckinPaymentBlockInSurface();
  }

  private htmlHomeHtmlForView(): string {
    if (this.currentSurface.intent === 'social') {
      return '';
    }
    if (isMultiTaskSurface(this.currentSurface) && this.multiTaskShellHtml.length > 0) {
      return this.multiTaskShellHtml;
    }
    if (this.waterfallShellHtml.length > 0) {
      return this.waterfallShellHtml;
    }
    if (this.shouldKeepLuckinConfirmWebHtmlStable() || this.shouldKeepLuckinPaymentWebHtmlStable()) {
      return this.htmlHomeStableHtml.length > 0 ? this.htmlHomeStableHtml : this.currentHtmlHomeHtml();
    }
    return this.currentHtmlHomeHtml();
  }

  private clearLuckinInlinePatchState(): void {
    this.luckinInlinePatchJson = '';
    this.luckinFoodMenuContext = null;
    this.mcDonaldsFoodMenuContext = null;
    this.clearLuckinOptionSwitchQueue();
  }

  aboutToAppear(): void {
    this.loadModelPreset();
    this.loadAggregateSearchPolicy();
    this.loadBimMotionPreference();
    this.readDebugBuildState();
    this.configureComposioRuntimeForCurrentUser();
    this.loadWaterfallPreferences();
    this.loadFoodAddressBook();
    this.loadFoodFavorites();
    this.loadPublicPersona();
    this.subscribeTrainPresaleHandoff();
    this.subscribeWaterfallConversationTypedTest();
    this.requestPendingTrainPresaleResume();
  }

  onPageShow(): void {
    this.subscribeTrainPresaleHandoff();
    this.subscribeWaterfallConversationTypedTest();
    this.requestPendingTrainPresaleResume();
  }

  onPageHide(): void {
    this.unsubscribeTrainPresaleHandoff();
  }

  aboutToDisappear(): void {
    this.stopBimMotionPreference();
    this.unsubscribeTrainPresaleHandoff();
    this.unsubscribeWaterfallConversationTypedTest();
    this.disposeHotelRuntime();
  }

  private loadBimMotionPreference(): void {
    try {
      this.bimReduceMotion = accessibility.isAnimationReduceEnabledSync();
      accessibility.onAnimationReduceStateChange(this.bimAnimationReduceHandler);
    } catch (_error) {
      this.bimReduceMotion = false;
    }
  }

  private stopBimMotionPreference(): void {
    try {
      accessibility.offAnimationReduceStateChange(this.bimAnimationReduceHandler);
    } catch (_error) {
    }
  }

  private readDebugBuildState(): void {
    this.isDebugBuild = readTrainPresaleDebugBuildState(
      (): boolean | undefined => bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      ).appInfo.debug);
  }

  private personaPackStore(): PreferencesPersonaPackStore | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    return context === null ? null : new PreferencesPersonaPackStore(context);
  }

  private refreshPersonaEditor(personaId: string = this.selectedPersonaId): void {
    this.personaPacks = allPersonaPacks();
    const pack = personaPackForId(personaId);
    this.selectedPersonaId = pack.manifest.id;
    this.personaSoulDraft = pack.soul;
    this.personaMemoryDraft = pack.memory;
  }

  private loadPersonaOverrides(): void {
    const store = this.personaPackStore();
    if (store !== null) {
      store.loadSync();
    }
    this.refreshPersonaEditor(this.selectedPersonaId);
  }

  private publicPersonaStore(): PublicPersonaStore | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    try {
      return new PublicPersonaStore(preferences.getPreferencesSync(context, {
        name: PUBLIC_PERSONA_STORE_NAME
      }));
    } catch (_error) {
      return null;
    }
  }

  private updatePublicPersonaSnapshot(snapshot: PublicPersonaSnapshot | null): void {
    this.publicPersonaSnapshot = snapshot;
    this.publicPersonaRenderTick = this.publicPersonaRenderTick + 1;
  }

  private loadPublicPersona(): void {
    if (this.publicPersonaInitialized) {
      return;
    }
    this.publicPersonaInitialized = true;
    const store = this.publicPersonaStore();
    if (store === null) {
      this.updatePublicPersonaSnapshot(null);
      this.publicPersonaPhase = 'input';
      return;
    }
    this.updatePublicPersonaSnapshot(store.load());
    this.publicPersonaPhase = this.publicPersonaSnapshot !== null ? 'complete' :
      (store.onboardingSeen() ? 'input' : 'welcome');
  }

  private openPublicPersona(): void {
    aiLogInfo('[AIPhone][PublicPersonaEntry] open=true');
    this.loadPublicPersona();
    this.showPublicPersonaPage = true;
  }

  private skipPublicPersonaOnboarding(): void {
    const store = this.publicPersonaStore();
    if (store !== null) {
      store.markOnboardingSeen();
    }
    this.publicPersonaPhase = 'input';
    this.showPublicPersonaPage = false;
  }

  private async runPublicPersonaDiscovery(
    jobId: number,
    username: string,
    mode: PublicPersonaSearchMode
  ): Promise<void> {
    try {
      const candidates = await this.publicPersonaClient.discover(username, mode, (progress: PublicPersonaProgress): void => {
        if (jobId === this.publicPersonaJobId) {
          this.publicPersonaProgress = progress;
          const probeResult = progress.message === '已找到公开账号' ? 'found' :
            progress.message === '未找到该用户名' ? 'not_found' :
              progress.message === '平台暂时无法确认' ? 'unknown' : '';
          if (probeResult.length > 0) {
            aiLogInfo(`[AIPhone][PublicPersonaProbe] platform=${progress.platform} result=${probeResult} ` +
              `provider=${progress.state} completed=${progress.completed}/${progress.total}`);
          }
        }
      });
      if (jobId !== this.publicPersonaJobId) {
        return;
      }
      this.publicPersonaCandidates = candidates;
      this.publicPersonaPhase = 'awaiting_confirmation';
    } catch (error) {
      if (jobId !== this.publicPersonaJobId) {
        return;
      }
      this.publicPersonaError = error instanceof Error ? error.message : '公开账号查找失败';
      this.publicPersonaPhase = 'error';
    }
  }

  private startPublicPersonaDiscovery(username: string, mode: PublicPersonaSearchMode): void {
    const store = this.publicPersonaStore();
    if (store !== null) {
      store.markOnboardingSeen();
    }
    this.publicPersonaJobId++;
    this.publicPersonaPhase = 'discovering';
    this.publicPersonaCandidates = [];
    this.publicPersonaProgress = null;
    this.publicPersonaError = '';
    const jobId = this.publicPersonaJobId;
    void this.runPublicPersonaDiscovery(jobId, username, mode);
  }

  private async runPublicPersonaBuild(jobId: number, selected: PublicPersonaCandidate[]): Promise<void> {
    try {
      const snapshot = await this.publicPersonaClient.buildSnapshot(selected, this.getSettings(), (progress: PublicPersonaProgress): void => {
        if (jobId === this.publicPersonaJobId) {
          this.publicPersonaProgress = progress;
          this.publicPersonaPhase = 'reading';
        }
      });
      if (jobId !== this.publicPersonaJobId) {
        return;
      }
      const store = this.publicPersonaStore();
      if (store === null || !store.save(snapshot)) {
        throw new Error('画像保存失败');
      }
      this.updatePublicPersonaSnapshot(snapshot);
      this.publicPersonaProgress = null;
      this.publicPersonaPhase = 'complete';
    } catch (error) {
      if (jobId !== this.publicPersonaJobId) {
        return;
      }
      this.publicPersonaError = error instanceof Error ? error.message : '画像生成失败';
      this.publicPersonaPhase = 'error';
    }
  }

  private confirmPublicPersona(candidateIds: string[]): void {
    const selected = this.publicPersonaCandidates.map((candidate: PublicPersonaCandidate): PublicPersonaCandidate => ({
      id: candidate.id,
      platform: candidate.platform,
      profileUrl: candidate.profileUrl,
      displayName: candidate.displayName,
      username: candidate.username,
      avatarUrl: candidate.avatarUrl,
      exists: true,
      ownershipConfidence: candidate.ownershipConfidence,
      ownershipBand: candidate.ownershipBand,
      selected: candidateIds.indexOf(candidate.id) >= 0,
      providerState: candidate.providerState,
      fetchedAt: candidate.fetchedAt,
      sourceUrl: candidate.sourceUrl
    }));
    if (candidateIds.length === 0) {
      this.publicPersonaError = '至少选择一个已确认账号';
      return;
    }
    this.publicPersonaJobId++;
    this.publicPersonaPhase = 'reading';
    this.publicPersonaProgress = null;
    this.publicPersonaError = '';
    void this.runPublicPersonaBuild(this.publicPersonaJobId, selected);
  }

  private savePublicPersonaMarkdown(markdown: string): boolean {
    if (this.publicPersonaSnapshot === null) {
      return false;
    }
    if (parsePublicPersonaMarkdown(markdown) === null) {
      this.publicPersonaError = 'Markdown 缺少姓名、摘要或画像固定章节，未保存。';
      return false;
    }
    const updated: PublicPersonaSnapshot = {
      schemaVersion: 1,
      personaMarkdown: markdown,
      primaryAvatarUrl: this.publicPersonaSnapshot.primaryAvatarUrl,
      sources: this.publicPersonaSnapshot.sources,
      generatedAt: this.publicPersonaSnapshot.generatedAt,
      mbtiHidden: this.publicPersonaSnapshot.mbtiHidden
    };
    const safe = sanitizePublicPersonaSnapshot(updated as Object);
    if (safe === null) {
      this.publicPersonaError = 'Markdown 缺少画像固定章节，未保存。';
      return false;
    }
    this.publicPersonaJobId++;
    const store = this.publicPersonaStore();
    if (store === null || !store.save(safe)) {
      this.publicPersonaError = 'Markdown 保存失败，请重试。';
      return false;
    }
    this.updatePublicPersonaSnapshot(safe);
    this.publicPersonaError = '';
    return true;
  }

  private async runPublicPersonaReinference(jobId: number, snapshot: PublicPersonaSnapshot): Promise<void> {
    try {
      const result = await this.publicPersonaClient.reinferMbti(snapshot, this.getSettings());
      if (jobId !== this.publicPersonaJobId || this.publicPersonaSnapshot === null) {
        return;
      }
      const markdown = replacePublicPersonaMbti(snapshot.personaMarkdown, result.mbtiType, result.mbtiConfidence);
      const updated: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: markdown,
        primaryAvatarUrl: snapshot.primaryAvatarUrl,
        sources: snapshot.sources,
        generatedAt: snapshot.generatedAt,
        mbtiHidden: false
      };
      const safe = sanitizePublicPersonaSnapshot(updated as Object);
      if (safe === null) {
        throw new Error('重新推测结果未通过本地校验');
      }
      const store = this.publicPersonaStore();
      if (store === null || !store.save(safe)) {
        throw new Error('MBTI 保存失败');
      }
      this.updatePublicPersonaSnapshot(safe);
      this.publicPersonaError = '';
    } catch (error) {
      if (jobId === this.publicPersonaJobId) {
        this.publicPersonaError = error instanceof Error ? error.message : 'MBTI 重新推测失败';
      }
    }
  }

  private reinferPublicPersonaMbti(): void {
    if (this.publicPersonaSnapshot === null) {
      return;
    }
    this.publicPersonaJobId++;
    const jobId = this.publicPersonaJobId;
    void this.runPublicPersonaReinference(jobId, this.publicPersonaSnapshot);
  }

  private setPublicPersonaMbtiHidden(hidden: boolean): boolean {
    if (this.publicPersonaSnapshot === null) {
      return false;
    }
    const updated: PublicPersonaSnapshot = {
      schemaVersion: 1,
      personaMarkdown: this.publicPersonaSnapshot.personaMarkdown,
      primaryAvatarUrl: this.publicPersonaSnapshot.primaryAvatarUrl,
      sources: this.publicPersonaSnapshot.sources,
      generatedAt: this.publicPersonaSnapshot.generatedAt,
      mbtiHidden: hidden
    };
    const safe = sanitizePublicPersonaSnapshot(updated as Object);
    if (safe === null) {
      this.publicPersonaError = 'MBTI 状态未通过本地校验。';
      return false;
    }
    this.publicPersonaJobId++;
    const store = this.publicPersonaStore();
    if (store === null || !store.save(safe)) {
      this.publicPersonaError = 'MBTI 状态保存失败，请重试。';
      return false;
    }
    this.updatePublicPersonaSnapshot(safe);
    this.publicPersonaError = '';
    return true;
  }

  private deletePublicPersona(): boolean {
    this.publicPersonaJobId++;
    const store = this.publicPersonaStore();
    if (store === null || !store.deleteSnapshot()) {
      this.publicPersonaError = '画像删除失败，请重试。';
      return false;
    }
    this.updatePublicPersonaSnapshot(null);
    this.publicPersonaCandidates = [];
    this.publicPersonaProgress = null;
    this.publicPersonaError = '';
    this.publicPersonaPhase = 'input';
    return true;
  }

  private publicPersonaBusy(): boolean {
    return this.publicPersonaPhase === 'discovering' || this.publicPersonaPhase === 'reading' ||
      this.publicPersonaPhase === 'summarizing';
  }

  private publicPersonaStatus(): string {
    if (this.publicPersonaBusy()) {
      return this.publicPersonaProgress === null ? '正在建立画像' : this.publicPersonaProgress.message;
    }
    if (this.publicPersonaSnapshot !== null) {
      return '画像已生成';
    }
    if (this.publicPersonaPhase === 'error') {
      return '画像暂未完成';
    }
    return '';
  }

  private paymentAccountPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    try {
      return preferences.getPreferencesSync(context, { name: PAYMENT_ACCOUNT_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private composioAuthPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    try {
      return preferences.getPreferencesSync(context, { name: COMPOSIO_AUTH_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private preferenceText(value: preferences.ValueType | string | number | boolean | null | undefined): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }
    return '';
  }

  private savedPaymentAccountsJson(): string {
    const store = this.paymentAccountPreferences();
    if (store === null) {
      return '';
    }
    try {
      return this.preferenceText(store.getSync(PAYMENT_ACCOUNT_BOOK_KEY, ''));
    } catch (_error) {
      return '';
    }
  }

  private savedPaymentAccounts(): PaymentAccount[] {
    const raw = this.savedPaymentAccountsJson().trim();
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as PaymentAccount[];
      return Array.isArray(parsed) ? parsed : [];
    } catch (_error) {
      return [];
    }
  }

  private savedComposioUserId(): string {
    const store = this.composioAuthPreferences();
    if (store === null) {
      return '';
    }
    try {
      const saved = this.preferenceText(store.getSync(COMPOSIO_USER_ID_KEY, '')).trim();
      return saved.length > 0 ? normalizeComposioUserId(saved) : '';
    } catch (_error) {
      return '';
    }
  }

  private async persistComposioUserId(userId: string): Promise<void> {
    const store = this.composioAuthPreferences();
    if (store === null) {
      return;
    }
    store.putSync(COMPOSIO_USER_ID_KEY, userId);
    await store.flush();
  }

  private createComposioUserId(): string {
    return normalizeComposioUserId(COMPOSIO_USER_ID_PREFIX + util.generateRandomUUID(false));
  }

  private ensureComposioUserId(): string {
    if (this.composioUserId.length > 0) {
      return this.composioUserId;
    }
    const configuredRaw = currentComposioUserId().trim();
    if (configuredRaw.length > 0) {
      const configured = normalizeComposioUserId(configuredRaw);
      this.composioUserId = configured;
      configureComposioUserId(configured);
      return configured;
    }
    const saved = this.savedComposioUserId();
    if (saved.length > 0) {
      this.composioUserId = saved;
      configureComposioUserId(saved);
      return saved;
    }
    const generated = this.createComposioUserId();
    this.composioUserId = generated;
    configureComposioUserId(generated);
    this.persistComposioUserId(generated).catch((_error: Error | Object | string | number | boolean | null | undefined) => {});
    return generated;
  }

  private composioAuthClient(): ComposioAuthProxyClient {
    const config = currentComposioConfig();
    if (config.proxyBaseUrl.length > 0) {
      return new ComposioAuthProxyClient(config.proxyBaseUrl, config.proxyApiKey);
    }
    return new ComposioAuthProxyClient(config.baseUrl, config.apiKey, true);
  }

  private configureComposioRuntimeForCurrentUser(): string {
    const userId = this.ensureComposioUserId();
    configureComposioUserId(userId);
    return userId;
  }

  private async refreshComposioAuth(): Promise<void> {
    this.composioAuthBusy = true;
    try {
      const userId = this.configureComposioRuntimeForCurrentUser();
      const result = await this.composioAuthClient().listAuthConfigs(userId);
      this.composioAuthItems = result.items;
      this.composioAuthMessage = result.ok ? '已刷新 Composio 授权状态。' : (result.error.length > 0 ? result.error : 'Composio 授权状态刷新失败。');
    } catch (error) {
      this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
    } finally {
      this.composioAuthBusy = false;
    }
  }

  private async openComposioAuthLink(item: ComposioAuthConfigItem): Promise<void> {
    this.composioAuthBusy = true;
    try {
      const link = await this.composioAuthClient().createLink(this.configureComposioRuntimeForCurrentUser(), item.authConfigId, item.toolkitSlug);
      if (!link.ok) {
        this.composioAuthMessage = link.error.length > 0 ? link.error : 'Composio 授权链接创建失败。';
        return;
      }
      this.composioAuthMessage = '正在打开授权页。';
      await this.openExternalUrl(link.redirectUrl);
    } catch (error) {
      this.composioAuthMessage = error instanceof Error ? error.message : JSON.stringify(error);
    } finally {
      this.composioAuthBusy = false;
    }
  }

  private composioAuthItemForToolkit(slug: string): ComposioAuthConfigItem | null {
    const normalized = this.normalizedComposioToolkitSlug(slug);
    for (let index = 0; index < this.composioAuthItems.length; index++) {
      if (this.normalizedComposioToolkitSlug(this.composioAuthItems[index].toolkitSlug) === normalized) {
        return this.composioAuthItems[index];
      }
    }
    return null;
  }

  private normalizedComposioToolkitSlug(slug: string): string {
    const normalized = slug.trim().toLowerCase();
    if (normalized === 'twitter') {
      return 'x';
    }
    if (normalized === 'calendar') {
      return 'googlecalendar';
    }
    if (normalized === 'microsoftoutlook') {
      return 'outlook';
    }
    if (normalized === 'youtubev3' || normalized === 'youtubedata') {
      return 'youtube';
    }
    return normalized;
  }

  private showComposioAuthList(message: string = ''): void {
    this.showConfigPage = false;
    this.showComposioAuthPage = true;
    if (message.length > 0) {
      this.composioAuthMessage = message;
    }
  }

  private async openSocialHubComposioAuth(platform: string): Promise<void> {
    if (this.composioAuthItems.length === 0) {
      await this.refreshComposioAuth();
    }
    const candidates = socialHubComposioToolkitCandidates(platform);
    for (let index = 0; index < candidates.length; index++) {
      const item = this.composioAuthItemForToolkit(candidates[index]);
      if (item !== null) {
        this.showComposioAuthList('正在打开 ' + platform + ' 授权页。');
        await this.openComposioAuthLink(item);
        return;
      }
    }
    this.showComposioAuthList('Composio 没有返回 ' + platform + ' 的授权配置。');
  }

  private loadPaymentAccounts(): void {
    const raw = this.savedPaymentAccountsJson();
    if (raw.trim().length > 0) {
      configureLocalPaymentAccountBookJson(raw);
    }
  }

  private savedStripeReceivingProfileJson(): string {
    const store = this.paymentAccountPreferences();
    if (store === null) {
      return '';
    }
    try {
      return this.preferenceText(store.getSync(STRIPE_RECEIVING_PROFILE_KEY, ''));
    } catch (_error) {
      return '';
    }
  }

  private loadStripeReceivingProfile(): void {
    const raw = this.savedStripeReceivingProfileJson();
    if (raw.trim().length > 0) {
      configureLocalStripeReceivingAgentJson(raw);
    }
  }

  private splitPaymentAliases(rawAliases: string): string[] {
    const normalized = rawAliases.split('，').join(',');
    const parts = normalized.split(',');
    const aliases: string[] = [];
    for (let index = 0; index < parts.length; index++) {
      const alias = parts[index].trim();
      if (alias.length > 0) {
        aliases.push(alias);
      }
    }
    return aliases;
  }

  private paymentAccountId(displayName: string): string {
    const value = displayName.trim().toLowerCase();
    let result = '';
    let previousSeparator = false;
    for (let index = 0; index < value.length; index++) {
      const char = value.charAt(index);
      const code = value.charCodeAt(index);
      const isAsciiLetter = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      if (isAsciiLetter) {
        result += char;
        previousSeparator = false;
      } else if (code > 127) {
        result += char;
        previousSeparator = false;
      } else if (!previousSeparator && result.length > 0) {
        result += '_';
        previousSeparator = true;
      }
    }
    while (result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result.length > 0 ? result : 'local_payee';
  }

  private paymentAccountFromAction(action: A2uiAction): PaymentAccount | null {
    let payload: HtmlPaymentAccountPayload;
    try {
      payload = JSON.parse(action.prompt) as HtmlPaymentAccountPayload;
    } catch (_error) {
      return null;
    }
    const displayName = this.actionText(payload.displayName).trim();
    const paypalEmail = this.actionText(payload.paypalEmail).trim();
    const paypalMerchantId = this.actionText(payload.paypalMerchantId).trim();
    const stripeAccountId = this.actionText(payload.stripeAccountId).trim();
    const stripePaymentLinkUrl = this.actionText(payload.stripePaymentLinkUrl).trim();
    if (displayName.length === 0 ||
      (paypalEmail.length === 0 && paypalMerchantId.length === 0 && stripeAccountId.length === 0 && stripePaymentLinkUrl.length === 0)) {
      return null;
    }
    return {
      id: this.paymentAccountId(displayName),
      displayName: displayName,
      aliases: this.splitPaymentAliases(this.actionText(payload.aliases)),
      email: '',
      paypalEmail: paypalEmail,
      paypalMerchantId: paypalMerchantId,
      stripeAccountId: stripeAccountId,
      stripePaymentLinkUrl: stripePaymentLinkUrl,
      enabled: true
    };
  }

  private upsertSavedPaymentAccount(accounts: PaymentAccount[], account: PaymentAccount): PaymentAccount[] {
    const next: PaymentAccount[] = [];
    let replaced = false;
    for (let index = 0; index < accounts.length; index++) {
      if (accounts[index].id === account.id) {
        next.push(account);
        replaced = true;
      } else {
        next.push(accounts[index]);
      }
    }
    if (!replaced) {
      next.push(account);
    }
    return next;
  }

  private paymentPreferredProvider(account: PaymentAccount): string {
    const hasPayPal = account.paypalEmail.length > 0 || account.paypalMerchantId.length > 0;
    const hasStripe = account.stripeAccountId.length > 0 || account.stripePaymentLinkUrl.length > 0;
    if (hasPayPal && !hasStripe) {
      return 'paypal';
    }
    if (hasStripe && !hasPayPal) {
      return 'stripe';
    }
    return '';
  }

  private async savePaymentAccount(action: A2uiAction): Promise<void> {
    const account = this.paymentAccountFromAction(action);
    const store = this.paymentAccountPreferences();
    if (account === null || store === null) {
      this.logHtmlHomeActionError(action, 'invalid_payment_account_payload');
      return;
    }
    try {
      const accounts = this.upsertSavedPaymentAccount(this.savedPaymentAccounts(), account);
      const raw = JSON.stringify(accounts);
      store.putSync(PAYMENT_ACCOUNT_BOOK_KEY, raw);
      await store.flush();
      configureLocalPaymentAccountBookJson(raw);
      aiLogInfo('[AIPhone][PaymentAccountSave] ok=true displayName=' + account.displayName);
      const previewArgs: PaymentSavedPreviewArgs = {
        accountId: account.id,
        recipient: account.displayName,
        provider: this.paymentPreferredProvider(account),
        originalQuery: '给 ' + account.displayName + ' 转账'
      };
      await this.callToolById('payment.send', '给 ' + account.displayName + ' 转账', 'payment.account.saved', previewArgs);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '付款对象保存失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][PaymentAccountSave] ok=false reason=' + message);
    }
  }

  private hasStripeReceivingAccountComponent(surface: A2uiSurfaceState): boolean {
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].component === A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD) {
        return true;
      }
    }
    return false;
  }

  private stripeReceivingProfileFromSurface(surface: A2uiSurfaceState): StripeReceivingSavedProfile | null {
    if (!this.hasStripeReceivingAccountComponent(surface)) {
      return null;
    }
    const account: StripeReceivingAccountCardData = stripeReceivingAccount(surface);
    if (account.stripeAccountId.trim().length === 0) {
      return null;
    }
    return {
      agentId: account.agentId,
      deviceId: account.deviceId,
      displayName: account.displayName,
      email: account.email,
      country: account.country,
      businessType: account.businessType,
      stripeAccountId: account.stripeAccountId,
      status: account.status
    };
  }

  private async saveStripeReceivingProfile(surface: A2uiSurfaceState): Promise<void> {
    const profile = this.stripeReceivingProfileFromSurface(surface);
    const store = this.paymentAccountPreferences();
    if (profile === null || store === null) {
      return;
    }
    try {
      const raw = JSON.stringify(profile);
      store.putSync(STRIPE_RECEIVING_PROFILE_KEY, raw);
      await store.flush();
      configureLocalStripeReceivingAgentJson(raw);
      aiLogInfo('[AIPhone][StripeReceivingProfileSave] ok=true accountIdPresent=true status=' + profile.status);
    } catch (error) {
      aiLogError('[AIPhone][StripeReceivingProfileSave] ok=false reason=' + (error instanceof Error ? error.message : JSON.stringify(error)));
    }
  }

  private savePersonaOverrides(): boolean {
    const store = this.personaPackStore();
    return store !== null && store.saveSync();
  }

  private selectPersonaForEdit(personaId: string): void {
    this.refreshPersonaEditor(personaId);
    this.personaSaveMessage = '';
  }

  private savePersonaDraft(): void {
    updatePersonaPackText(this.selectedPersonaId, this.personaSoulDraft, this.personaMemoryDraft);
    this.savePersonaOverrides();
    this.refreshPersonaEditor(this.selectedPersonaId);
    this.personaSaveMessage = '已保存';
  }

  private resetPersonaDraft(): void {
    resetPersonaPackText(this.selectedPersonaId);
    this.savePersonaOverrides();
    this.refreshPersonaEditor(this.selectedPersonaId);
    this.personaSaveMessage = '已恢复默认';
  }

  private applyPersonaMemoryUpdate(update: PersonaMemoryUpdateRequest): boolean {
    const pack = personaPackForId(update.personaId);
    if (pack.manifest.id !== update.personaId) {
      aiLogError('[AIPhone][PersonaMemoryUpdate] ok=false reason=unknown_persona personaId=' + update.personaId);
      return false;
    }
    updatePersonaPackText(
      update.personaId,
      pack.soul,
      mergePersonaStablePreference(pack.memory, update.memoryText)
    );
    if (!this.savePersonaOverrides()) {
      updatePersonaPackText(update.personaId, pack.soul, pack.memory);
      this.refreshPersonaEditor(update.personaId);
      aiLogError('[AIPhone][PersonaMemoryUpdate] ok=false reason=persist_failed personaId=' + update.personaId);
      return false;
    }
    if (update.personaId === 'entertainment_companion' &&
      isStableWaterfallContentPreference(update.memoryText)) {
      try {
        const rules = this.waterfallPreferenceProfile.explicitRules.concat(
          waterfallExplicitPreferencesFromStatement(update.memoryText));
        this.waterfallPreferenceProfile = this.waterfallPreferencesStore().replaceExplicitPreferences(rules);
        configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
        if (this.waterfallFeedState !== null) {
          this.waterfallFeedState.profile = this.currentWaterfallPreferenceProfile(false);
        }
      } catch (_error) {
        aiLogError('[AIPhone][WaterfallPreferenceProjection] ok=false source=memory_update');
      }
    }
    this.refreshPersonaEditor(update.personaId);
    this.personaSaveMessage = '已保存：' + update.summary;
    aiLogInfo('[AIPhone][PersonaMemoryUpdate] ok=true personaId=' + update.personaId + ' summary=' + update.summary);
    return true;
  }

  private isPersonaEditorAction(action: A2uiAction): boolean {
    return action.id === 'persona_memory_edit' || action.id === 'persona_soul_edit';
  }

  private isStripeReceivingActionId(action: A2uiAction): boolean {
    return action.kind === 'client' &&
      (action.id === 'stripe.account.create' ||
        action.id === 'stripe.account.onboard' ||
        action.id === 'stripe.account.refresh');
  }

  private openPersonaEditor(personaId: string, target: string): void {
    this.selectPersonaForEdit(personaId);
    this.showConfigPage = true;
    this.personaSaveMessage = target === 'soul' ? '正在编辑 soul.md' : '正在编辑 memory.md';
  }

  private getSettings(): LocalModelSettings {
    return {
      provider: defaultLocalModelSettings().provider,
      baseUrl: this.baseUrl,
      model: this.selectedModel,
      apiKey: this.apiKey,
      customParametersJson: this.customParametersJson,
      ignoreToolSurfaceUpdates: this.ignoreToolSurfaceUpdates
    };
  }

  private modelPresetPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    try {
      return preferences.getPreferencesSync(context, { name: MODEL_PRESET_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private loadModelPreset(): void {
    const store = this.modelPresetPreferences();
    const preset = store === null ? '' : this.preferenceText(store.getSync(MODEL_PRESET_KEY, ''));
    const settings = deepSeekModelSettings();
    this.baseUrl = settings.baseUrl;
    this.apiKey = settings.apiKey;
    this.selectedModel = resolvedCloudChatModel(preset);
    this.customParametersJson = settings.customParametersJson;
  }

  private saveModelPreset(preset: string): void {
    const store = this.modelPresetPreferences();
    if (store !== null) {
      store.putSync(MODEL_PRESET_KEY, preset);
      store.flushSync();
    }
  }

  private aggregateSearchPolicyPreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    try {
      return preferences.getPreferencesSync(context, { name: AGGREGATE_SEARCH_POLICY_STORE_NAME });
    } catch (_error) {
      return null;
    }
  }

  private preferenceBoolean(value: preferences.ValueType | boolean, fallback: boolean): boolean {
    return typeof value === 'boolean' ? value : fallback;
  }

  private syncAggregateSearchRuntimePolicy(): void {
    configureWaterfallSearchPolicyForRuntime({
      domesticOnly: this.aggregateDomesticOnly,
      multilingual: this.aggregateMultilingual
    });
  }

  private loadAggregateSearchPolicy(): void {
    const store = this.aggregateSearchPolicyPreferences();
    if (store === null) {
      this.aggregateDomesticOnly = DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources;
      this.aggregateMultilingual = DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults;
      this.syncAggregateSearchRuntimePolicy();
      return;
    }
    try {
      this.aggregateDomesticOnly = this.preferenceBoolean(store.getSync(
        AGGREGATE_DOMESTIC_ONLY_KEY,
        DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources
      ), DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources);
      this.aggregateMultilingual = this.preferenceBoolean(store.getSync(
        AGGREGATE_MULTILINGUAL_KEY,
        DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults
      ), DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults);
    } catch (_error) {
      this.aggregateDomesticOnly = DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources;
      this.aggregateMultilingual = DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults;
    }
    this.syncAggregateSearchRuntimePolicy();
  }

  private saveAggregateSearchPolicy(): void {
    this.syncAggregateSearchRuntimePolicy();
    const store = this.aggregateSearchPolicyPreferences();
    if (store === null) {
      return;
    }
    try {
      store.putSync(AGGREGATE_DOMESTIC_ONLY_KEY, this.aggregateDomesticOnly);
      store.putSync(AGGREGATE_MULTILINGUAL_KEY, this.aggregateMultilingual);
      store.flushSync();
    } catch (_error) {
    }
  }

  private currentLocalDate(): string {
    const now = new Date();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    return now.getFullYear().toString() + '-' + month + '-' + day;
  }

  private bimStore(): BimStore {
    if (this.bimStoreInstance === null) {
      const context = this.getUIContext().getHostContext() as common.Context;
      const native = preferences.getPreferencesSync(context, { name: BIM_STORE_NAME });
      this.bimStoreInstance = new BimStore(native);
    }
    return this.bimStoreInstance;
  }

  private waterfallPreferencesStore(): WaterfallPreferencesStore {
    if (this.waterfallPreferencesStoreInstance === null) {
      const context = this.getUIContext().getHostContext() as common.Context;
      const native = preferences.getPreferencesSync(context, { name: WATERFALL_PREFERENCES_STORE_NAME });
      this.waterfallPreferencesStoreInstance = new WaterfallPreferencesStore(native);
    }
    return this.waterfallPreferencesStoreInstance;
  }

  private currentWaterfallPreferenceProfile(includeConversation: boolean = true): WaterfallPreferenceProfile {
    return {
      version: 2,
      sourceRegistryVersion: this.waterfallPreferenceProfile.sourceRegistryVersion,
      topicWeights: this.waterfallPreferenceProfile.topicWeights.concat(
        this.waterfallReactionProjection.topicWeights),
      sourceWeights: this.waterfallPreferenceProfile.sourceWeights.concat(
        this.waterfallReactionProjection.sourceWeights),
      formatWeights: this.waterfallPreferenceProfile.formatWeights.concat(
        this.waterfallReactionProjection.formatWeights),
      explicitRules: this.waterfallPreferenceProfile.explicitRules.concat(
        includeConversation ? this.waterfallConversationState.rules : []),
      recentEvidence: this.waterfallPreferenceProfile.recentEvidence.slice(),
      discoveryEnabledSources: this.waterfallPreferenceProfile.discoveryEnabledSources.slice(),
      enabledSources: this.waterfallPreferenceProfile.discoveryEnabledSources.slice(),
      updatedAt: this.waterfallPreferenceProfile.updatedAt,
      sessionTopicWeights: this.waterfallSessionTopicWeights.slice(),
      sessionSourceWeights: this.waterfallSessionSourceWeights.slice(),
      sessionFormatWeights: this.waterfallSessionFormatWeights.slice()
    };
  }

  private loadWaterfallPreferences(): void {
    try {
      this.waterfallPreferenceProfile = this.waterfallPreferencesStore().loadForNewSession();
      this.waterfallCardRecords = this.waterfallPreferencesStore().loadCardRecords();
      this.waterfallReactionProjection = waterfallReactionWeights(this.waterfallCardRecords);
    } catch (_error) {
      this.waterfallPreferenceProfile = emptyWaterfallPreferenceProfile();
      this.waterfallCardRecords = [];
      this.waterfallReactionProjection = { topicWeights: [], sourceWeights: [], formatWeights: [] };
    }
    configureWaterfallEnabledSourcesForRuntime(
      this.waterfallPreferenceProfile.discoveryEnabledSources as AggregateSearchSource[]);
    configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
  }

  private refreshBimRecords(): void {
    try {
      const records = this.bimStore().list();
      this.bimRecords = records;
      this.selectedBimRecordSnapshot = refreshedSelectedBimRecord(this.selectedBimId, records);
      this.bimDetailRenderTick = this.bimDetailRenderTick + 1;
      this.bimLoading = false;
      this.bimStoreError = '';
    } catch (_error) {
      this.bimLoading = false;
      this.bimStoreError = '心上事暂时无法载入';
    }
  }

  private sameLocalDay(iso: string, now: Date): boolean {
    if (iso.length === 0) return false;
    const value = new Date(iso);
    return !isNaN(value.getTime()) && value.getFullYear() === now.getFullYear() &&
      value.getMonth() === now.getMonth() && value.getDate() === now.getDate();
  }

  private requestDailyBimSentinel(): void {
    if (this.isBusy || this.bimSentinelBusy) return;
    const now = new Date();
    try {
      if (this.sameLocalDay(this.bimStore().lastSentinelSuccessAt(), now)) return;
    } catch (_error) {
      return;
    }
    this.bimSentinelBusy = true;
    void this.runDailyBimSentinel(now);
  }

  private async runDailyBimSentinel(now: Date, scheduleNext: boolean = true): Promise<void> {
    try {
      const events: BimAttentionEvent[] = await runBimSentinel(this.bimStore(), this.canaryModel());
      for (let index = 0; index < events.length; index++) {
        if (this.isBusy) throw new Error('BIM_SENTINEL_FOREGROUND_BUSY');
        await this.submitPrompt(
          buildBimAttentionPrompt(events[index]),
          bimAttentionVisibleText(events[index]),
          '',
          null,
          events[index].bimId
        );
      }
      const checkpointWritten = this.bimStore().markSentinelSuccess(now.toISOString());
      if (!checkpointWritten) {
        throw new Error('BIM_SENTINEL_CHECKPOINT_FAILED');
      }
      if (shouldScheduleBimDailyReminder(checkpointWritten, scheduleNext)) {
        void new BimDailyReminder().scheduleNext(now).catch((error: Error): void => {
          aiLogError('[AIPhone][BimReminder] ' + logSnippet(error.message));
        });
      }
      aiLogInfo('[AIPhone][BimSentinel] mode=' + (scheduleNext ? 'daily' : 'mock') +
        ' events=' + events.length.toString() + ' ok=true');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][BimSentinel] ' + logSnippet(message));
    } finally {
      this.bimSentinelBusy = false;
    }
  }

  private subscribeBimSentinelMock(): void {
    if (this.bimSentinelMockSubscribed) return;
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.on(BIM_SENTINEL_MOCK_EVENT, this.bimSentinelMockListener);
      this.bimSentinelMockSubscribed = true;
    }
  }

  private unsubscribeBimSentinelMock(): void {
    if (!this.bimSentinelMockSubscribed) return;
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.off(BIM_SENTINEL_MOCK_EVENT, this.bimSentinelMockListener);
    }
    this.bimSentinelMockSubscribed = false;
  }

  private requestPendingBimSentinelMock(): void {
    if (!this.isDebugBuild) {
      consumeBimSentinelMockHandoff();
      return;
    }
    if (!canRunBimSentinelMock(this.isDebugBuild, this.isBusy, this.bimSentinelBusy) ||
      !consumeBimSentinelMockHandoff()) return;
    this.bimSentinelBusy = true;
    aiLogInfo('[AIPhone][BimSentinelMockTriggered] ok=true');
    void this.runDailyBimSentinel(new Date(), false);
  }

  private async scheduleBimSentinelMock(): Promise<void> {
    if (!canRunBimSentinelMock(this.isDebugBuild, this.isBusy, this.bimSentinelBusy)) return;
    this.bimSentinelBusy = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await ensureReminderNotificationEnabled(
        (): Promise<boolean> => notificationManager.isNotificationEnabled(),
        (): Promise<void> => notificationManager.requestEnableNotification(context)
      );
      const reminderId = await new BimDailyReminder().scheduleDebug(10);
      aiLogInfo('[AIPhone][BimSentinelMockScheduled] reminderId=' + reminderId.toString() +
        ' delaySeconds=10');
      this.getUIContext().getPromptAction().showToast({ message: '10 秒测试提醒已创建' });
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      if (this.isDebugBuild && isBimReminderLimitMessage(message)) {
        setTimeout((): void => {
          queueBimSentinelMockHandoff();
          this.requestPendingBimSentinelMock();
        }, 10000);
        aiLogInfo('[AIPhone][BimSentinelMockScheduled] transport=in_app_timer delaySeconds=10');
        this.getUIContext().getPromptAction().showToast({ message: '系统提醒已满，10 秒后应用内测试' });
        return;
      }
      aiLogError('[AIPhone][BimSentinelMockScheduled] ok=false error=' + logSnippet(message));
      this.getUIContext().getPromptAction().showToast({ message: '测试提醒创建失败' });
    } finally {
      this.bimSentinelBusy = false;
    }
  }

  private bimVisibleCount(): number {
    const grouped = groupVisibleBims(this.bimRecords);
    return grouped.active.length + grouped.quiet.length;
  }

  private selectedBimRecord(): BimRecord | null {
    return selectedBimRecordForRender(this.selectedBimId, this.selectedBimRecordSnapshot);
  }

  private openBimRoot(): void {
    this.bimUiError = '';
    this.selectedBimId = '';
    this.selectedBimRecordSnapshot = null;
    this.refreshBimRecords();
    this.showBimPage = true;
  }

  private openBimDetail(bimId: string): void {
    this.bimUiError = '';
    this.bimInputText = '';
    this.selectedBimRecordSnapshot = refreshedSelectedBimRecord(bimId, this.bimRecords);
    this.selectedBimId = bimId;
  }

  private closeBimDetail(): void {
    this.bimUiError = '';
    this.bimInputText = '';
    this.selectedBimId = '';
    this.selectedBimRecordSnapshot = null;
  }

  private markBimEnded(bimId: string): void {
    if (this.isBusy) {
      return;
    }
    let saved = false;
    try {
      saved = this.bimStore().markEnded(bimId, new Date().toISOString());
    } catch (_error) {
      saved = false;
    }
    if (!saved) {
      this.bimUiError = '心上事结束状态保存失败';
      return;
    }
    this.bimUiError = '';
    this.refreshBimRecords();
  }

  private reactivateBim(bimId: string): void {
    if (this.isBusy) {
      return;
    }
    let saved = false;
    try {
      saved = this.bimStore().reactivate(bimId, new Date().toISOString());
    } catch (_error) {
      saved = false;
    }
    if (!saved) {
      this.bimUiError = '心上事重新激活失败';
      return;
    }
    this.bimUiError = '';
    this.refreshBimRecords();
  }

  private async deleteEndedBim(bimId: string): Promise<void> {
    if (this.isBusy) {
      return;
    }
    const buttons: [promptAction.Button, promptAction.Button] = [
      { text: '取消', color: '#6B7280' },
      { text: '删除', color: '#B0443F' }
    ];
    let selectedIndex = 0;
    try {
      const selected = await this.getUIContext().getPromptAction().showActionMenu({
        title: '删除这件已结束的心上事？',
        buttons
      });
      selectedIndex = selected.index;
    } catch (_error) {
      return;
    }
    if (selectedIndex !== 1 || this.isBusy) {
      return;
    }
    let deleted = false;
    try {
      deleted = this.bimStore().deleteEnded(bimId);
    } catch (_error) {
      deleted = false;
    }
    if (!deleted) {
      this.bimUiError = '已结束心上事删除失败';
      return;
    }
    this.closeBimDetail();
    this.bimUiError = '';
    this.refreshBimRecords();
  }

  private canaryRuntime(): MultiAgentCanaryRuntime {
    const settings = this.getSettings();
    const fingerprint = hotelModelSettingsFingerprint(settings);
    if (this.multiAgentRuntime !== null &&
      this.hotelAgentRuntimeFingerprint === fingerprint) {
      return this.multiAgentRuntime;
    }
    this.disposeHotelRuntime();
    const provider = new LlmProvider(
      settings.provider,
      settings.apiKey,
      settings.baseUrl,
      settings.model,
      settings.customParametersJson
    );
    const model = new OpenAiCompatibleModel(provider);
    this.multiAgentModel = model;
    const opener = new PageHotelUriOpener((uri: string): Promise<boolean> => {
      if (uri.startsWith('petalmaps://')) {
        return this.openExternalUrl(uri, ['petalmaps']);
      }
      if (!isRollingGoHotelBookingUrl(uri)) {
        return Promise.resolve(false);
      }
      this.rememberHotelReturnSurface();
      this.checkoutWebKind = 'hotel';
      this.checkoutWebUrl = uri;
      this.trainPresaleCheckoutTaskId = '';
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][HotelBookingOpen] host=rollinggo.cn');
      return Promise.resolve(true);
    });
    const pageHandler = new RegisteredPageActionHandler(
      new PageRegisteredToolInvoker((
        toolId: string,
        prompt: string,
        pageActionId: string,
        args: Object
      ): Promise<RegisteredPageToolInvocation> =>
        this.invokeRegisteredPageTool(toolId, prompt, pageActionId, args))
    );
    const options: MultiAgentCanaryOptions = {
      model: model,
      opener: opener,
      structuredToolCall: (
        toolId: string,
        prompt: string,
        args: Object,
        onPartial?: (result: DataResult) => void
      ): Promise<DataResult> => callStructuredTool(
        toolId,
        prompt,
        aggregateSearchArgsWithPolicy(toolId, args, {
          onlyDomesticSources: this.aggregateDomesticOnly,
          includeMultilingualResults: this.aggregateMultilingual
        }),
        onPartial
      ),
      onSurface: (surface: A2uiSurfaceState, generation: number): boolean => {
        const accepted = this.applyRuntimeSurface(surface, 'multi_agent', generation);
        if (accepted) {
          this.isAwaitingFirstSurface = false;
        }
        return accepted;
      },
      onMailDetail: async (
        result: MailDetailInPlaceEvent,
        generation: number,
        lease: MailDetailWriteLease
      ): Promise<void> => {
        const suggestionToken = this.mailDetailSuggestionGuard.beginDetail();
        const surfaceId = this.currentSurface.surfaceId;
        const enrichmentIsCurrent = (): boolean =>
          this.mailDetailSuggestionGuard.isCurrent(suggestionToken) &&
            this.currentSurface.surfaceId === surfaceId &&
            runtimeCallbackIsCurrent(
              this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', generation
            );
        await publishMailDetailThenSuggest(result, {
          initialIsCurrent: (): boolean => lease.isActive() && enrichmentIsCurrent(),
          enrichmentIsCurrent,
          writeEvent: (event: MailDetailUiEvent): void => {
            this.mailDetailEventJson = JSON.stringify(event);
          },
          saveSuggestion: (requestKey: string, suggestion: MailCalendarSuggestion): void => {
            this.mailCalendarSuggestions[requestKey] = suggestion;
          },
          suggest: (detail: MailDetail): Promise<MailCalendarSuggestion> =>
            this.extractMailCalendarSuggestion(detail),
          onSuggestionError: (message: string): void => {
            aiLogError('[AIPhone][MailCalendarSuggestionFailed] ' + message.substring(0, 240));
          }
        });
        const bodyChars = result.detail === undefined ? 0 :
          (result.detail.bodyText.length > 0 ? result.detail.bodyText.length : result.detail.bodyHtml.length);
        aiLogInfo('[AIPhone][MailDetailInPlace] requestKeyChars=' + result.requestKey.length.toString() +
          ' provider=' + result.provider +
          ' identity=' + result.identityDigest +
          ' status=' + result.status + ' bodyChars=' + bodyChars.toString());
      },
      pageAction: (
        actionId: string,
        args: Object,
        context: RegisteredPageActionContext
      ): Promise<ActionExecutionResult> => {
        if (actionId !== 'gmail.message.send') {
          this.prepareVirtualMultiTaskAction(actionId, context);
        }
        return actionId === 'gmail.message.send' ?
          this.executeRegisteredGmailReply(args) : pageHandler.execute(actionId, args, context);
      },
      currentPageSnapshot: (): RegisteredPageSnapshot | null =>
        this.registeredPageSnapshotStore.current(),
      currentHostSurface: (): A2uiSurfaceState | null => this.canaryHostSurface(),
      currentHostGeneration: (): number => this.runtimeGeneration,
      currentLocalDate: (): string => this.currentLocalDate(),
      submitTimeoutMs: 90000,
      actionTimeoutMs: 45000,
      settingsFingerprint: fingerprint,
      focusedRelease: true
    };
    const memoryAvailability = this.localMemoryAvailability();
    options.memoryAvailability = memoryAvailability;
    if (memoryAvailability.isAvailable()) options.memoryRuntime = this.localMemoryRuntime();
    if (ENABLE_MULTI_AGENT_UI_LAYOUT_LLM && provider.isConfigured()) {
      options.uiLayoutPlanner = new A2uiAgentRunner(new OpenAiA2uiModel(provider));
    }
    this.multiAgentRuntime = new MultiAgentCanaryRuntime(options);
    this.hotelAgentRuntimeFingerprint = fingerprint;
    return this.multiAgentRuntime;
  }

  private localMemoryRuntime(): PhoneLocalMemoryRuntime {
    if (this.phoneLocalMemoryRuntime === null) {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.phoneLocalMemoryRuntime = new PhoneLocalMemoryRuntime(context);
    }
    return this.phoneLocalMemoryRuntime;
  }

  private localMemoryAvailability(): PhoneLocalMemoryAvailabilityPort {
    if (this.phoneLocalMemoryAvailability === null) {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.phoneLocalMemoryAvailability = phoneLocalMemoryAvailabilityForContext(context);
    }
    return this.phoneLocalMemoryAvailability;
  }

  private disposeHotelRuntime(): void {
    this.mailDetailSuggestionGuard.invalidate();
    if (this.multiAgentRuntime !== null) {
      this.multiAgentRuntime.dispose();
      this.multiAgentRuntime = null;
    }
    this.multiAgentModel = null;
    this.hotelAgentRuntimeFingerprint = '';
  }

  private canaryModel(): LocalModel {
    this.canaryRuntime();
    if (this.multiAgentModel === null) {
      throw new Error('MULTI_AGENT_MODEL_UNAVAILABLE');
    }
    return this.multiAgentModel;
  }

  private currentPanelState(): ConnectionPanelState {
    return {
      connectionStatus: this.connectionStatus,
      connectionMessage: this.connectionMessage,
      lastModelRequest: this.lastModelRequest,
      lastModelOutput: this.lastModelOutput,
      lastError: this.lastError,
      refreshTick: this.refreshTick
    };
  }

  private applyPanelState(next: ConnectionPanelState): void {
    this.connectionStatus = next.connectionStatus;
    this.connectionMessage = next.connectionMessage;
    this.lastModelRequest = next.lastModelRequest;
    this.lastModelOutput = next.lastModelOutput;
    this.lastError = next.lastError;
    this.refreshTick = next.refreshTick;
  }

  private resetPanelState(): void {
    const next = createInitialConnectionPanelState();
    this.connectionStatus = next.connectionStatus;
    this.connectionMessage = next.connectionMessage;
    this.lastModelRequest = next.lastModelRequest;
    this.lastModelOutput = next.lastModelOutput;
    this.lastError = next.lastError;
    this.refreshTick = next.refreshTick;
  }

  private cloneSurfaceComponents(components: A2uiComponent[]): A2uiComponent[] {
    const next: A2uiComponent[] = [];
    components.forEach((component: A2uiComponent) => {
      next.push({
        id: component.id,
        component: component.component,
        child: component.child,
        children: component.children === undefined ? [] : component.children.slice(),
        title: component.title,
        text: component.text,
        body: component.body,
        status: component.status,
        tone: component.tone,
        variant: component.variant,
        path: component.path,
        dataPath: component.dataPath,
        actions: component.actions === undefined ? [] : component.actions.slice()
      });
    });
    return next;
  }

  private surfaceSnapshot(surface: A2uiSurfaceState): A2uiSurfaceState {
    return {
      surfaceId: surface.surfaceId,
      rootId: surface.rootId,
      title: surface.title,
      intent: surface.intent,
      status: surface.status,
      components: this.cloneSurfaceComponents(surface.components),
      dataModelJson: surface.dataModelJson,
      error: surface.error,
      sequence: surface.sequence,
      runtimeOwner: surface.runtimeOwner,
      runtimeGeneration: surface.runtimeGeneration
    };
  }

  private beginRuntimeTurn(owner: RuntimeOwner): number {
    this.mailDetailSuggestionGuard.invalidate();
    this.runtimeGeneration++;
    this.activeRuntimeOwner = owner;
    return this.runtimeGeneration;
  }

  private ownedSurface(
    surface: A2uiSurfaceState,
    owner: RuntimeOwner,
    generation: number
  ): A2uiSurfaceState {
    const next = this.surfaceSnapshot(surface);
    next.runtimeOwner = owner;
    next.runtimeGeneration = generation;
    return next;
  }

  private canaryHostSurface(): A2uiSurfaceState {
    return this.surfaceSnapshot(this.currentSurface);
  }

  private applyRuntimeSurface(
    surface: A2uiSurfaceState,
    owner: RuntimeOwner,
    generation: number
  ): boolean {
    if (!runtimeCallbackIsCurrent(
      this.activeRuntimeOwner,
      this.runtimeGeneration,
      owner,
      generation
    )) {
      return false;
    }
    return this.applySurface(this.ownedSurface(surface, owner, generation));
  }

  private parsedDataModel(): A2uiRuntimeDataModel | null {
    try {
      return JSON.parse(this.currentSurface.dataModelJson) as A2uiRuntimeDataModel;
    } catch (_error) {
      return null;
    }
  }

  private scheduleTravelCalendarConflictRefresh(): void {
    const model = this.parsedDataModel();
    if (model === null || travelCalendarEventsFromModel(model).length === 0) {
      return;
    }
    this.travelConflictRefreshGeneration = this.travelConflictRefreshGeneration + 1;
    const generation = this.travelConflictRefreshGeneration;
    const surfaceId = this.currentSurface.surfaceId;
    const sequence = this.currentSurface.sequence;
    const dataModelJson = this.currentSurface.dataModelJson;
    void this.refreshTravelCalendarConflicts(generation, surfaceId, sequence, dataModelJson);
  }

  private async refreshTravelCalendarConflicts(
    generation: number,
    surfaceId: string,
    sequence: number,
    dataModelJson: string
  ): Promise<void> {
    try {
      await this.ensureCalendarPermissions();
      const model = JSON.parse(dataModelJson) as A2uiRuntimeDataModel;
      const events = travelCalendarEventsFromModel(model);
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const conflicts = await findHuaweiTravelCalendarConflicts(context, events);
      if (generation !== this.travelConflictRefreshGeneration ||
        this.currentSurface.surfaceId !== surfaceId || this.currentSurface.sequence !== sequence ||
        this.currentSurface.dataModelJson !== dataModelJson) {
        return;
      }
      const changed = applyTravelCalendarConflictProjection(model, conflicts);
      if (changed) {
        const next = this.surfaceSnapshot(this.currentSurface);
        next.dataModelJson = JSON.stringify(model);
        this.currentSurface = next;
        this.surfaceRenderTick = this.surfaceRenderTick + 1;
        this.htmlHomeCacheKey = '';
        this.htmlHomeCacheHtml = '';
        this.syncHtmlHomeStableHtml();
      }
      aiLogInfo('[AIPhone][TravelCalendarConflictProjection] candidates=' + events.length.toString() +
        ' conflicts=' + conflicts.filter((item: HuaweiTravelCalendarConflict) => item.conflict).length.toString() +
        ' changed=' + (changed ? 'true' : 'false'));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][TravelCalendarConflictProjection] ok=false error=' + message.substring(0, 220));
    }
  }

  private currentHtmlHomeDocument(): HtmlHomeDocument {
    if (isFirecrawlToolId(this.pendingFirecrawlToolId) &&
      shouldShowFirecrawlPendingSurface(
        this.isBusy,
        this.pendingFirecrawlToolId,
        this.currentSurface
      )) {
      return createFirecrawlPendingDocument(this.pendingFirecrawlToolId);
    }
    if (shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface) ||
      shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface)) {
      return createHtmlHomeDocument({
        messages: this.messages,
        isBusy: this.isBusy,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputText: this.inputText
      });
    }
    const document = createHtmlHomeDocument({
      surface: this.currentSurface,
      messages: this.messages,
      isBusy: this.isBusy,
      isAwaitingFirstSurface: this.isAwaitingFirstSurface
    });
    if (document.kind !== 'aggregate-search') {
      return document;
    }
    return createHtmlHomeDocument({
      messages: this.messages,
      isBusy: this.isBusy,
      isAwaitingFirstSurface: this.isAwaitingFirstSurface,
      inputText: this.inputText
    });
  }

  private withMultiTaskActiveSection(document: HtmlHomeDocument): HtmlHomeDocument {
    if (document.kind !== 'multi-task') {
      return document;
    }
    const activeSectionId = this.multiTaskActiveSectionId.length > 0 ?
      this.multiTaskActiveSectionId :
      (document.activeSectionId ?? '');
    if (activeSectionId.length === 0) {
      return document;
    }
    document.activeSectionId = activeSectionId;
    return document;
  }

  private currentHtmlHomeCacheKey(): string {
    const needsInputText = shouldShowQueryPendingSurface(this.isBusy, this.isAwaitingFirstSurface);
    return [
      this.currentSurface.surfaceId,
      this.currentSurface.sequence.toString(),
      this.currentSurface.runtimeOwner === undefined ? '' : this.currentSurface.runtimeOwner,
      this.currentSurface.runtimeGeneration === undefined ? '' :
        this.currentSurface.runtimeGeneration.toString(),
      this.surfaceRenderTick.toString(),
      this.currentSurface.status,
      this.isBusy ? 'busy' : 'idle',
      this.isAwaitingFirstSurface ? 'awaiting' : 'ready',
      this.pendingFirecrawlToolId,
      this.messages.length.toString(),
      this.multiTaskActiveSectionId,
      this.foodLocationOwnerSurfaceId,
      this.foodLocationLongitude.toString(),
      this.foodLocationLatitude.toString(),
      this.foodLocationRadiusMeters.toString(),
      this.foodLocationName,
      this.foodLocationAddress,
      JSON.stringify(this.foodSavedAddresses),
      JSON.stringify(this.foodFavorites),
      needsInputText ? this.inputText : ''
    ].join('|');
  }

  private currentHtmlHomeHtml(): string {
    const key = this.currentHtmlHomeCacheKey();
    if (key === this.htmlHomeCacheKey && this.htmlHomeCacheHtml.length > 0) {
      return this.htmlHomeCacheHtml;
    }
    const document = this.withMultiTaskActiveSection(this.currentHtmlHomeDocument());
    const animateLatestUser: boolean = document.kind === 'thinking' && document.source === 'pending' &&
      this.promptSubmitMotionGeneration > this.renderedPromptSubmitMotionGeneration;
    const html = renderHtmlHomeDocument(document, this.isBusy,
      document.kind === 'food' && document.surfaceId === this.foodLocationOwnerSurfaceId ? {
        longitude: this.foodLocationLongitude,
        latitude: this.foodLocationLatitude,
        radiusMeters: this.foodLocationRadiusMeters,
        name: this.foodLocationName,
        address: this.foodLocationAddress
      } : undefined,
      document.kind === 'food' ? this.foodSavedAddresses : [],
      document.kind === 'food' ? this.foodFavorites : [],
      animateLatestUser);
    if (animateLatestUser) {
      this.renderedPromptSubmitMotionGeneration = this.promptSubmitMotionGeneration;
    }
    this.recordRenderedPageSnapshot(this.currentSurface, document);
    if (this.htmlHomeDebugExportEnabled) {
      this.writeHtmlHomeDebugExport(document, 'auto');
    }
    this.htmlHomeCacheKey = key;
    this.htmlHomeCacheHtml = html;
    aiLogInfo('[AIPhone][HtmlHomeDocument] source=' + document.source +
      ' kind=' + document.kind +
      ' chars=' + html.length.toString() +
      ' blocks=' + document.blocks.length.toString() +
      ' contentDigest=' + sha256Digest(html) +
      (document.kind === 'multi-task' ?
        ' activeSectionId=' + (document.activeSectionId ?? 'none') +
        ' multiTaskBlocks=' + document.blocks.filter((block: HtmlHomeBlock) => block.kind === 'multi-task-section').length.toString() :
        '') +
      ' renderTick=' + this.surfaceRenderTick.toString());
    return html;
  }

  private recordRenderedPageSnapshot(
    surface: A2uiSurfaceState,
    document: HtmlHomeDocument
  ): void {
    if (document.surfaceId === undefined || document.surfaceId !== surface.surfaceId) {
      return;
    }
    this.registeredPageRenderGeneration++;
    this.registeredPageSnapshotStore.record(
      this.surfaceSnapshot(surface),
      document,
      this.registeredPageRenderGeneration
    );
  }

  private writeHtmlHomeDebugExport(document: HtmlHomeDocument, reason: string): void {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      this.htmlHomeDebugExportPath = '导出失败：缺少应用上下文';
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=false reason=missing_context');
      return;
    }
    const path = context.filesDir + '/' + HTML_HOME_DEBUG_EXPORT_FILE_NAME;
    let file: fs.File | null = null;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, htmlHomeDebugExportJson(document, this.isBusy));
      fs.closeSync(file);
      file = null;
      this.htmlHomeDebugExportPath = path;
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=true reason=' + reason +
        ' path=' + path +
        ' kind=' + document.kind +
        ' blocks=' + document.blocks.length.toString());
    } catch (error) {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (_closeError) {
        }
      }
      this.htmlHomeDebugExportPath = '导出失败：' + JSON.stringify(error);
      aiLogInfo('[AIPhone][HtmlHomeDebugExport] ok=false reason=' + reason +
        ' error=' + JSON.stringify(error));
    }
  }

  private exportCurrentHtmlHomeDocument(): void {
    this.writeHtmlHomeDebugExport(this.currentHtmlHomeDocument(), 'manual');
  }

  private applySurface(surface: A2uiSurfaceState): boolean {
    const next = this.surfaceSnapshot(surface);
    if (next.runtimeOwner === undefined) {
      next.runtimeOwner = this.activeRuntimeOwner;
    }
    if (next.runtimeGeneration === undefined) {
      next.runtimeGeneration = this.runtimeGeneration;
    }
    if (next.runtimeOwner !== this.activeRuntimeOwner ||
      next.runtimeGeneration !== this.runtimeGeneration ||
      !shouldApplySurfaceUpdate(this.currentSurface, next)) {
      return false;
    }
    if (next.intent !== 'multi-task') {
      this.multiTaskActiveSectionId = '';
      this.multiTaskUserPinnedSection = false;
      this.multiTaskLastMergedRawBySlot = {};
      this.multiTaskPayloadJson = '';
      this.multiTaskShellHtml = '';
    } else if (!this.multiTaskUserPinnedSection) {
      this.multiTaskActiveSectionId = this.readMultiTaskActiveSectionId(next);
    }
    this.currentSurface = next;
    this.syncFoodLocationOwner(next);
    this.syncFoodStoreMapSnapshot(next);
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    if (surface.intent === 'multi-task') {
      this.scheduleMultiTaskPayloadRefresh();
    }
    aiLogInfo('[AIPhone][A2uiHomeSurfaceUpdate] surfaceId=' + surface.surfaceId +
      ' intent=' + surface.intent +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + next.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString() +
      ' multiTaskTick=' + this.multiTaskPayloadTick.toString());
    this.scheduleTravelCalendarConflictRefresh();
    return true;
  }

  private forceApplySurface(surface: A2uiSurfaceState, reason: string): void {
    const next = this.surfaceSnapshot(surface);
    if (next.runtimeOwner === undefined) {
      next.runtimeOwner = this.activeRuntimeOwner;
    }
    if (next.runtimeGeneration === undefined) {
      next.runtimeGeneration = this.runtimeGeneration;
    }
    if (next.runtimeOwner !== this.activeRuntimeOwner ||
      next.runtimeGeneration !== this.runtimeGeneration) {
      return;
    }
    this.currentSurface = next;
    this.syncFoodLocationOwner(next);
    this.syncFoodStoreMapSnapshot(next);
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    this.htmlHomeCacheKey = '';
    this.htmlHomeCacheHtml = '';
    aiLogInfo('[AIPhone][A2uiHomeSurfaceForceUpdate] reason=' + reason +
      ' surfaceId=' + surface.surfaceId +
      ' status=' + surface.status +
      ' components=' + surface.components.length.toString() +
      ' dataChars=' + surface.dataModelJson.length.toString() +
      ' sequence=' + surface.sequence.toString() +
      ' renderTick=' + this.surfaceRenderTick.toString());
    this.scheduleTravelCalendarConflictRefresh();
  }

  private rememberLuckinReturnSurface(reason: string): void {
    if (this.currentSurface.intent !== 'luckin') {
      return;
    }
    this.luckinReturnSurface = this.surfaceSnapshot(this.currentSurface);
    aiLogInfo('[AIPhone][LuckinReturnSurfaceRemember] reason=' + reason +
      ' title=' + this.currentSurface.title +
      ' dataChars=' + this.currentSurface.dataModelJson.length.toString());
  }

  private restoreLuckinReturnSurface(reason: string): void {
    if (this.luckinReturnSurface === null) {
      aiLogInfo('[AIPhone][LuckinReturnSurfaceRestore] reason=' + reason + ' ok=false');
      return;
    }
    const surface = this.surfaceSnapshot(this.luckinReturnSurface);
    this.luckinReturnSurface = null;
    this.showCheckoutWeb = false;
    this.trainPresaleCheckoutTaskId = '';
    this.forceApplySurface(surface, reason);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '已返回瑞幸下单页面。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
    aiLogInfo('[AIPhone][LuckinReturnSurfaceRestore] reason=' + reason + ' ok=true');
  }

  private rememberHotelReturnSurface(): void {
    if (this.currentSurface.intent === 'hotel') {
      this.hotelReturnSurface = this.surfaceSnapshot(this.currentSurface);
    }
  }

  private restoreHotelReturnSurface(reason: string): void {
    if (this.hotelReturnSurface === null) {
      aiLogInfo('[AIPhone][HotelReturnSurfaceRestore] reason=' + reason + ' ok=false');
      return;
    }
    const surface = this.surfaceSnapshot(this.hotelReturnSurface);
    this.hotelReturnSurface = null;
    this.forceApplySurface(surface, reason);
    aiLogInfo('[AIPhone][HotelReturnSurfaceRestore] reason=' + reason + ' ok=true');
  }

  private socialHubComposioAuthItem(platform: SocialHubPlatform): ComposioAuthConfigItem | null {
    const candidates = socialHubComposioToolkitCandidates(platform);
    for (let index = 0; index < candidates.length; index++) {
      const item = this.composioAuthItemForToolkit(candidates[index]);
      if (item !== null) {
        return item;
      }
    }
    return null;
  }

  private composioSocialHubConnection(platform: SocialHubPlatform, displayName: string): SocialHubConnectionData {
    const item = this.socialHubComposioAuthItem(platform);
    if (item === null) {
      return {
        platform: platform,
        status: 'needs_auth',
        displayName: displayName,
        accountId: '',
        message: platform === 'wecom' ? '等待企业微信接入' : '等待 Composio 授权接入'
      };
    }
    const status: SocialHubConnectionStatus = (item.status === 'connected' || item.connectedAccountId.length > 0 || item.canExecute) ?
      'connected' : 'needs_auth';
    return {
      platform: platform,
      status: status,
      displayName: displayName,
      accountId: item.connectedAccountId,
      message: status === 'connected' ?
        ('Composio 已授权' + (item.connectedAccountLabel.length > 0 ? '：' + item.connectedAccountLabel : '')) :
        '等待 Composio 授权接入'
    };
  }

  private defaultSocialHubConnections(): SocialHubConnectionData[] {
    return [
      this.composioSocialHubConnection('x', 'X'),
      this.composioSocialHubConnection('slack', 'Slack'),
      {
        platform: 'wecom',
        status: 'needs_auth',
        displayName: '企业微信',
        accountId: '',
        message: '等待授权接入'
      },
      this.composioSocialHubConnection('discord', 'Discord'),
      this.composioSocialHubConnection('linkedin', 'LinkedIn'),
      this.composioSocialHubConnection('whatsapp', 'WhatsApp'),
      this.composioSocialHubConnection('instagram', 'Instagram'),
      this.composioSocialHubConnection('reddit', 'Reddit')
    ];
  }

  private createSocialHubSurface(): A2uiSurfaceState {
    const store = new A2uiSurfaceStore();
    store.apply({
      version: 'v0.9.1',
      createSurface: {
        surfaceId: 'surface_social_hub',
        root: 'root',
        title: 'SocialHub',
        intent: 'social',
        status: 'ready',
        sendDataModel: true
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateComponents: {
        surfaceId: 'surface_social_hub',
        components: [
          {
            id: 'root',
            component: A2UI_COMPONENT_SURFACE_ROOT,
            child: 'socialHub',
            title: 'SocialHub',
            status: 'ready'
          },
          {
            id: 'socialHub',
            component: A2UI_COMPONENT_SOCIAL_HUB,
            title: 'SocialHub',
            status: 'ready',
            dataPath: '/socialHub/items'
          }
        ]
      }
    });
    store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: 'surface_social_hub',
        path: '/socialHub/connections',
        value: this.defaultSocialHubConnections()
      }
    });
    return store.getSurface();
  }

  private async openSocialHub(): Promise<void> {
    aiLogInfo('[AIPhone][SocialHubEntry] open=true');
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    await this.refreshComposioAuth();
    this.applySurface(this.createSocialHubSurface());
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: 'SocialHub 已打开；正在加载近 30 天私信。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
    await this.callToolById('social.feed.search', '帮我查看最近30天所有已授权应用收到的私信消息', 'social_hub_default');
  }

  private applySocialHubData(path: string, value: A2uiDataValue): void {
    const store = new A2uiSurfaceStore();
    store.seed(this.currentSurface);
    const result = store.apply({
      version: 'v0.9.1',
      updateDataModel: {
        surfaceId: this.currentSurface.surfaceId,
        path: path,
        value: value
      }
    });
    if (!result.ok) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'SocialHub 本地状态更新失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      return;
    }
    this.applySurface(store.getSurface());
  }

  private currentSocialHubItems(): SocialHubItemData[] {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null) {
      return [];
    }
    return Array.isArray(model.socialHub.items) ? model.socialHub.items : [];
  }

  private currentSocialHubSelected(): SocialHubItemData | null {
    const model = this.parsedDataModel();
    if (model === null || model.socialHub === undefined || model.socialHub === null ||
      model.socialHub.selected === undefined || model.socialHub.selected === null ||
      model.socialHub.selected.id.length === 0) {
      return null;
    }
    return model.socialHub.selected;
  }

  private findSocialHubItem(itemId: string): SocialHubItemData | null {
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].id === itemId) {
        return items[index];
      }
    }
    return null;
  }

  private findSocialHubItemByUrl(url: string): SocialHubItemData | null {
    if (url.length === 0) {
      return null;
    }
    const items = this.currentSocialHubItems();
    for (let index = 0; index < items.length; index++) {
      if (items[index].url === url) {
        return items[index];
      }
    }
    return null;
  }

  private hasSocialHubComponent(): boolean {
    for (let index = 0; index < this.currentSurface.components.length; index++) {
      if (this.currentSurface.components[index].component === A2UI_COMPONENT_SOCIAL_HUB) {
        return true;
      }
    }
    return false;
  }

  private isCurrentSocialHubSurface(): boolean {
    const model = this.parsedDataModel();
    return this.currentSurface.intent === 'social' &&
      this.hasSocialHubComponent() &&
      model !== null &&
      model.socialHub !== undefined &&
      model.socialHub !== null &&
      Array.isArray(model.socialHub.items);
  }

  private socialHubDraftError(itemId: string, message: string): SocialHubDraftData {
    const selected = this.currentSocialHubSelected();
    return {
      itemId: itemId,
      platform: selected === null ? 'unknown' : selected.platform,
      text: '',
      status: 'error',
      error: message,
      localOnly: true,
      sent: false
    };
  }

  private socialHubDraftSnippet(text: string): string {
    const trimmed = text.trim();
    if (trimmed.length <= 80) {
      return trimmed;
    }
    return trimmed.substring(0, 80) + '...';
  }

  private selectSocialHubItem(action: A2uiAction): void {
    const item = this.findSocialHubItem(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(action.prompt, '未找到这条真实消息，无法选择。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
  }

  private draftSocialHubReply(action: A2uiAction): void {
    const selected = this.currentSocialHubSelected();
    const itemId = action.prompt.length > 0 ? action.prompt : (selected === null ? '' : selected.id);
    if (itemId.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '请先选择一条真实消息，再生成草稿。'));
      return;
    }
    const item = this.findSocialHubItem(itemId);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '未找到这条真实消息，不能生成草稿。'));
      return;
    }
    const sourceText = item.text.trim();
    if (sourceText.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '选中消息没有正文，不能生成本地草稿预览。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
    const draft: SocialHubDraftData = emptySocialHubDraft();
    draft.itemId = item.id;
    draft.platform = item.platform;
    draft.status = 'draft';
    draft.text = '本地草稿预览（未发送）：\n\n我会基于这条真实消息回复：' + this.socialHubDraftSnippet(sourceText);
    this.applySocialHubData('/socialHub/draft', draft);
  }

  private socialHubReplyText(action: A2uiAction): string {
    if (action.args === undefined || action.args === null) {
      return '';
    }
    const payload = action.args as SocialHubReplyPayload;
    return this.actionText(payload.text).trim();
  }

  private async sendSocialHubReply(action: A2uiAction): Promise<void> {
    const selected = this.currentSocialHubSelected();
    const itemId = action.prompt.length > 0 ? action.prompt : (selected === null ? '' : selected.id);
    const item = this.findSocialHubItem(itemId);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(itemId, '未找到这条真实消息，不能发送回复。'));
      return;
    }
    const text = this.socialHubReplyText(action);
    if (text.length === 0) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(item.id, '请输入要发送的回复内容。'));
      return;
    }
    this.applySocialHubData('/socialHub/selected', item);
    const pending: SocialHubDraftData = emptySocialHubDraft();
    pending.itemId = item.id;
    pending.platform = item.platform;
    pending.status = 'draft';
    pending.text = '正在发送到 ' + (item.platform === 'slack' ? 'Slack' : '社交平台') + '...';
    pending.localOnly = false;
    this.applySocialHubData('/socialHub/draft', pending);
    try {
      this.applySocialHubData('/socialHub/draft', await sendLocalSocialHubReply(item, text));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError(item.id, message));
    }
  }

  private async openSocialHubSource(action: A2uiAction): Promise<void> {
    const item = this.findSocialHubItemByUrl(action.prompt);
    if (item === null) {
      this.applySocialHubData('/socialHub/draft',
        this.socialHubDraftError('', '这条消息没有匹配的来源 URL。'));
      return;
    }
    await this.openExternalUrl(item.url);
  }

  private isSocialHubActionId(action: A2uiAction): boolean {
    return action.kind === 'client' &&
      (action.id === 'social_hub_select_item' ||
        action.id === 'social_hub_draft_reply' ||
        action.id === 'social_hub_send_reply' ||
        action.id === 'social_hub_open_source' ||
        action.id === 'social_hub_authorize');
  }

  private isSocialHubClientAction(action: A2uiAction): boolean {
    return this.isSocialHubActionId(action) && this.isCurrentSocialHubSurface();
  }

  private resetCurrentSession(): void {
    this.disposeHotelRuntime();
    this.showHistory = false;
    this.isBusy = false;
    this.isAwaitingFirstSurface = false;
    this.messages = [];
    this.sessionContextCompactor.reset();
    this.waterfallSessionTopicWeights = [];
    this.waterfallSessionSourceWeights = [];
    this.waterfallSessionFormatWeights = [];
    this.waterfallSessionEvidence = [];
    this.waterfallConversationState = { history: [], rules: [], summary: '' };
    this.waterfallConversationMessage = '';
    this.waterfallConversationBusy = false;
    this.interestWaterfallGeneration += 1;
    this.interestRecallStarted = false;
    this.interestRecallRound = 0;
    this.interestExplorationSources = [];
    this.interestSourceRequestSeq.clear();
    this.interestWaterfallFeedState = null;
    this.interestWaterfallSearchSnapshot = null;
    this.interestWaterfallHtml = '';
    this.interestWaterfallPayloadJson = '';
    configureWaterfallPreferenceProfileForRuntime(this.currentWaterfallPreferenceProfile(false));
    this.registeredPageSnapshotStore.clear();
    this.registeredPageRenderGeneration = 0;
    this.currentSurface = this.surfaceSnapshot(createSeedA2uiSurface());
    this.syncFoodLocationOwner(this.currentSurface);
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.clearLuckinInlinePatchState();
    this.syncHtmlHomeStableHtml();
    this.inputText = '';
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    this.resetPanelState();
  }

  private markChecking(message: string): void {
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'checking',
      message: message,
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private recentMessages(): A2uiMessage[] {
    if (this.messages.length <= 8) {
      return this.messages;
    }
    return this.messages.slice(this.messages.length - 8);
  }

  private async multiAgentInput(text: string, currentUserMessageId: string): Promise<UserInputPayload> {
    const activeContext: ActiveSessionContext = await this.sessionContextCompactor.activeContext(
      this.messages,
      currentUserMessageId
    );
    const surface: CurrentSurfaceSummary = {
      surfaceId: this.currentSurface.surfaceId,
      kind: this.currentSurface.intent,
      status: this.currentSurface.status,
      entityRefs: [],
      actionOfferIds: []
    };
    return {
      text,
      recentMessages: activeContext.recentMessages,
      sessionSummary: activeContext.rollingSummary,
      currentSurfaceSummary: surface,
      recentObservations: []
    };
  }

  private appendMessage(role: string, content: string): string {
    const next = this.messages.slice();
    const messageId: string = Date.now().toString() + '-' + next.length.toString();
    next.push({
      id: messageId,
      role: role,
      content: content
    });
    this.messages = next;
    return messageId;
  }

  private showMemoryResultToast(message: string): void {
    if (!/^已记住\s*\d+\s*条|^已更新长期记忆|^已忘记这条长期记忆/.test(message)) {
      return;
    }
    this.getUIContext().getPromptAction().showToast({
      message,
      duration: 2500,
      alignment: Alignment.Top
    });
  }

  private showMemoryCandidateActionToast(message: string): void {
    if (message.trim().length === 0) return;
    this.getUIContext().getPromptAction().showToast({
      message,
      duration: 2500,
      alignment: Alignment.Top
    });
  }

  private currentDynamicToolConnect(): A2uiDynamicToolConnectData | null {
    const model = this.parsedDataModel();
    if (model === null || model.dynamicToolConnect === undefined || model.dynamicToolConnect === null) {
      return null;
    }
    return model.dynamicToolConnect;
  }

  private dailyBriefStore(): DailyBriefStore | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    return context === null ? null : new DailyBriefStore(context);
  }

  private async openDailyBrief(regenerate: boolean): Promise<boolean> {
    const store = this.dailyBriefStore();
    const now = new Date();
    const date = dailyBriefDate(now);
    if (store === null) {
      this.forceApplySurface(createDailyBriefErrorSurface(date, '日报存储不可用'), 'daily_brief_store_missing');
      return false;
    }
    const existing = store.snapshotForDate(date);
    const preference = store.loadPreference();
    const decision = decideDailyBriefOpen(existing, regenerate);
    this.dailyBriefGeneration += 1;
    const generation = this.dailyBriefGeneration;
    if (decision === 'open_existing') {
      this.dailyBriefSnapshot = existing;
      this.finishForegroundTurn();
      this.forceApplySurface(
        createDailyBriefSurface(existing as DailyBriefSnapshot, preference),
        'daily_brief_open_existing'
      );
      return true;
    }

    this.dailyBriefSnapshot = existing;
    this.isBusy = true;
    try {
      if (existing === null) {
        this.forceApplySurface(createDailyBriefLoadingSurface(date), 'daily_brief_generate_first');
      } else {
        this.forceApplySurface(createDailyBriefSurface(existing, preference), 'daily_brief_regenerate');
      }
      const generated = await generateDailyBrief({ now, preference, budgetMs: 120000 });
      if (!shouldApplyDailyBriefGeneration(generation, this.dailyBriefGeneration)) {
        return false;
      }
      const storedWinner = selectDailyBriefStoredWinnerBeforeSave(
        store.snapshotForDate(date), regenerate
      );
      if (storedWinner !== null) {
        this.finishForegroundTurn();
        this.dailyBriefSnapshot = storedWinner;
        this.forceApplySurface(
          createDailyBriefSurface(storedWinner, preference),
          'daily_brief_stored_winner'
        );
        return true;
      }
      const saved = store.saveSnapshot(generated);
      const selected = selectDailyBriefSnapshotAfterSave(existing, generated, saved);
      this.finishForegroundTurn();
      if (!saved || selected === null) {
        const message = '日报快照保存失败';
        if (existing === null) {
          this.forceApplySurface(createDailyBriefErrorSurface(date, message), 'daily_brief_save_failed');
        }
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: false,
          status: 'error',
          message,
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: message
        }));
        return false;
      }
      this.dailyBriefSnapshot = selected;
      this.forceApplySurface(createDailyBriefSurface(selected, preference), 'daily_brief_generated');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '个人日报已更新。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return true;
    } catch (error) {
      if (!shouldApplyDailyBriefGeneration(generation, this.dailyBriefGeneration)) {
        return false;
      }
      this.finishForegroundTurn();
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      if (existing === null) {
        this.forceApplySurface(createDailyBriefErrorSurface(date, message), 'daily_brief_generate_failed');
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: message.length > 0 ? message : '个人日报生成失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      return false;
    }
  }

  private async handleDailyBriefClientAction(action: A2uiAction): Promise<boolean> {
    const allowed = action.id === 'daily.brief.regenerate' ||
      action.id === 'daily.brief.preference.save' ||
      action.id === 'daily.brief.history.open' ||
      action.id === 'daily.brief.mail.read' ||
      action.id === 'daily.brief.route.open' ||
      action.id === 'daily.brief.ride.estimate' ||
      action.id === 'daily.brief.discovery.open';
    if (!allowed) {
      return false;
    }
    if (!isValidDailyBriefAction(action)) {
      this.logHtmlHomeActionError(action, 'invalid_daily_brief_action');
      return true;
    }
    if (action.id === 'daily.brief.regenerate') {
      await this.openDailyBrief(true);
      return true;
    }
    const store = this.dailyBriefStore();
    if (store === null) {
      this.logHtmlHomeActionError(action, 'daily_brief_store_missing');
      return true;
    }
    if (action.id === 'daily.brief.preference.save') {
      const preference = action.args as DailyBriefPreference;
      if (!store.savePreference(preference)) {
        this.logHtmlHomeActionError(action, 'daily_brief_preference_save_failed');
        return true;
      }
      const context = this.getUIContext().getHostContext() as common.Context;
      scheduleNextDailyBrief(context.applicationInfo.name, new Date(), preference.targetTime);
      if (this.dailyBriefSnapshot !== null) {
        this.forceApplySurface(
          createDailyBriefSurface(this.dailyBriefSnapshot, store.loadPreference()),
          'daily_brief_preference_saved'
        );
      }
      return true;
    }
    if (action.id === 'daily.brief.history.open') {
      const direction = dailyBriefHistoryDirection(action.args);
      if (direction === null) {
        this.logHtmlHomeActionError(action, 'daily_brief_history_invalid');
        return true;
      }
      let selected: DailyBriefSnapshot | null = null;
      if (direction === 'today') {
        selected = store.snapshotForDate(dailyBriefDate(new Date()));
      } else {
        const snapshots = store.loadSnapshots();
        const current = this.dailyBriefSnapshot === null ?
          store.snapshotForDate(dailyBriefDate(new Date())) : this.dailyBriefSnapshot;
        if (current !== null) {
          for (let index = 0; index < snapshots.length; index++) {
            if (snapshots[index].date !== current.date) {
              continue;
            }
            const target = direction === 'previous' ? index - 1 : index + 1;
            if (target >= 0 && target < snapshots.length) {
              selected = snapshots[target];
            }
            break;
          }
        }
      }
      if (selected !== null) {
        this.dailyBriefSnapshot = selected;
        this.forceApplySurface(
          createDailyBriefSurface(selected, store.loadPreference()),
          'daily_brief_history_' + direction
        );
      }
      return true;
    }
    if (action.id === 'daily.brief.mail.read') {
      const request: DailyBriefMailReadRequest | null = dailyBriefMailReadRequest(action.args);
      if (request === null) {
        this.logHtmlHomeActionError(action, 'daily_brief_mail_invalid');
        return true;
      }
      await this.callToolById(
        request.toolId,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        request.args
      );
      return true;
    }
    if (action.id === 'daily.brief.route.open' || action.id === 'daily.brief.ride.estimate') {
      const date = this.dailyBriefSnapshot === null ? dailyBriefDate(new Date()) : this.dailyBriefSnapshot.date;
      const request = dailyBriefScenarioToolRequest(action.id, date);
      if (request === null) {
        this.logHtmlHomeActionError(action, 'daily_brief_scenario_invalid');
        return true;
      }
      if (request.toolId === 'maps.route.open') {
        const scenario = dailyBriefDemoScenario(date);
        try {
          const context = this.getUIContext().getHostContext() as common.Context;
          await petalMaps.openMapRoutePlan(context, {
            originPosition: { longitude: scenario.originLongitude, latitude: scenario.originLatitude },
            originName: scenario.origin,
            destinationPosition: {
              longitude: scenario.destinationLongitude,
              latitude: scenario.destinationLatitude
            },
            destinationName: scenario.destination,
            vehicleType: petalMaps.VehicleType.DRIVING,
            coordinateType: mapCommon.CoordinateType.GCJ02
          });
          aiLogInfo('[AIPhone][DailyBriefRouteOpen] ok=true');
        } catch (error) {
          const businessError = error as BusinessError;
          aiLogError('[AIPhone][DailyBriefRouteOpen] ok=false code=' + businessError.code.toString());
        }
      } else {
        await this.callToolById(request.toolId, action.label, action.id, request.args);
      }
      return true;
    }
    if (this.dailyBriefSnapshot !== null) {
      const surface = createDailyBriefWaterfallSurface(this.dailyBriefSnapshot);
      if (surface !== null) {
        this.forceApplySurface(surface, 'daily_brief_discovery');
      }
    }
    return true;
  }

  private async catchUpDailyBriefIfNeeded(): Promise<void> {
    const store = this.dailyBriefStore();
    const context = this.getUIContext().getHostContext() as common.Context;
    if (store === null || context === null) {
      return;
    }
    const now = new Date();
    const preference = store.loadPreference();
    scheduleNextDailyBrief(context.applicationInfo.name, now, preference.targetTime);
    const existing = store.snapshotForDate(dailyBriefDate(now));
    const eligible = shouldStartDailyBriefCatchUp(
      now, preference.targetTime, existing !== null, false
    );
    const transition = transitionDailyBriefCatchUp(
      this.dailyBriefCatchUpPending, 'lifecycle', eligible, this.isBusy
    );
    this.dailyBriefCatchUpPending = transition.pending;
    if (!transition.run) {
      return;
    }
    await this.openDailyBrief(false);
  }

  private async resumeDailyBriefCatchUpAfterIdle(): Promise<void> {
    await Promise.resolve();
    await this.catchUpDailyBriefIfNeeded();
  }

  private finishForegroundTurn(): void {
    this.isBusy = false;
    const transition = transitionDailyBriefCatchUp(
      this.dailyBriefCatchUpPending, 'idle', false, this.isBusy
    );
    this.dailyBriefCatchUpPending = transition.pending;
    if (transition.run) {
      void this.resumeDailyBriefCatchUpAfterIdle();
    }
  }

  private async openExternalUrl(
    url: string,
    allowedSchemes: string[] = ['https']
  ): Promise<boolean> {
    if (url.length === 0) {
      return false;
    }
    const schemeMatch = /^([A-Za-z][A-Za-z0-9+.-]*):/.exec(url);
    const scheme = schemeMatch === null ? 'unknown' : schemeMatch[1].toLowerCase();
    const urlMeta = ' scheme=' + scheme + ' chars=' + url.length.toString();
    if (allowedSchemes.indexOf(scheme) < 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '无法打开不受信任的外部页面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'external URL scheme is not allowed'
      }));
      aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false' + urlMeta +
        ' code=SCHEME_NOT_ALLOWED');
      return false;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri: url
      });
      aiLogInfo('[AIPhone][A2uiHomeOpenUrl] ok=true' + urlMeta);
      return true;
    } catch (error) {
      const businessError = error as BusinessError;
      const message = '外部页面打开失败：' + businessError.message;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '无法打开外部页面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][A2uiHomeOpenUrl] ok=false' + urlMeta + ' code=' + businessError.code.toString());
      return false;
    }
  }

  private openDeepSearch(query: string, contextJson: string): void {
    const settings = this.getSettings();
    this.deepSearchQuery = query;
    this.deepSearchSettingsJson = JSON.stringify({
      provider: settings.provider,
      baseUrl: settings.baseUrl,
      model: settings.model,
      apiKey: settings.apiKey,
      customParametersJson: settings.customParametersJson,
      ignoreToolSurfaceUpdates: true
    });
    // 先写入 context 再打开面板，确保面板 aboutToAppear 读到完整位置/日期。
    this.deepSearchContextJson = contextJson;
    this.showDeepSearch = true;
    aiLogInfo('[AIPhone][DeepSearchPanelOpened] queryChars=' + query.length.toString() +
      ' context=' + contextJson.length.toString() + 'chars');
  }

  private deepSearchDateLabel(): string {
    const now = new Date();
    const weekdays: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return now.getFullYear().toString() + '年' +
      (now.getMonth() + 1).toString() + '月' +
      now.getDate().toString() + '日 星期' +
      weekdays[now.getDay()];
  }

  private async buildDeepSearchContext(): Promise<string> {
    const dateLabel = this.deepSearchDateLabel();
    try {
      const coordinate = await this.currentDeviceLocation();
      let locationLabel = '';
      try {
        const request: geoLocationManager.ReverseGeoCodeRequest = {
          latitude: Number.parseFloat(coordinate.split(',')[1]),
          longitude: Number.parseFloat(coordinate.split(',')[0]),
          maxItems: 1
        };
        const addresses = await geoLocationManager.getAddressesFromLocation(request);
        if (addresses.length > 0) {
          const address = addresses[0];
          const locality = address.locality === undefined ? '' : address.locality;
          const subArea = address.subAdministrativeArea === undefined ? '' : address.subAdministrativeArea;
          const adminArea = address.administrativeArea === undefined ? '' : address.administrativeArea;
          locationLabel = locality.length > 0 ? locality :
            (subArea.length > 0 ? subArea : adminArea);
        }
      } catch (_geoError) {
        locationLabel = '';
      }
      this.deepSearchContextJson = JSON.stringify({
        locationLabel: locationLabel,
        dateLabel: dateLabel,
        coordinateLabel: coordinate
      });
    } catch (_locationError) {
      // 定位不可用时降级：仅注入日期。
      this.deepSearchContextJson = JSON.stringify({
        locationLabel: '',
        dateLabel: dateLabel,
        coordinateLabel: ''
      });
    }
    return this.deepSearchContextJson;
  }

  private closeDeepSearch(): void {
    this.showDeepSearch = false;
    this.deepSearchQuery = '';
    this.deepSearchSettingsJson = '';
    this.deepSearchContextJson = '';
  }

  private openAnythingDemo(): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      router.pushUrl({ url: ANYTHING_DEMO_ROUTE_URL }, (error) => {
        if (error) {
          aiLogError('[AIPhone][AnythingDemoRouteFailed] ' + JSON.stringify(error));
          resolve(false);
          return;
        }
        resolve(true);
      });
    });
  }

  private openMovieDemo(): Promise<boolean> {
    return new Promise<boolean>((resolve: (value: boolean) => void): void => {
      router.pushUrl({ url: MOVIE_DEMO_ROUTE_URL }, (error) => {
        if (error) {
          aiLogError('[AIPhone][MovieDemoRouteFailed] ' + JSON.stringify(error));
          resolve(false);
          return;
        }
        resolve(true);
      });
    });
  }
  private enqueueBimCurator(evidence: BimTurnEvidence): Promise<BimCuratorResult> {
    const run = this.bimCuratorTail.then((): Promise<BimCuratorResult> => runBimCurator(
      this.bimStore(), this.canaryModel(), evidence, new Date().toISOString()
    ));
    this.bimCuratorTail = run.then((result: BimCuratorResult): void => {
      if (result.error.length > 0) {
        aiLogError('[AIPhone][BimCurator] ' + result.error);
      }
      this.refreshBimRecords();
    }).catch((error: Error): void => {
      aiLogError('[AIPhone][BimCurator] ' + logSnippet(error.message));
    });
    return run;
  }

  private rememberSuggestedBim(): void {
    if (this.pendingBimEvidence === null || this.bimRememberState === 'saving' ||
      this.bimRememberState === 'saved') return;
    const evidence = this.pendingBimEvidence;
    evidence.userConfirmedCreate = true;
    this.bimRememberState = 'saving';
    this.bimRememberError = '';
    this.enqueueBimCurator(evidence).then((result: BimCuratorResult): void => {
      if (result.error.length > 0 || result.createdBimIds.length === 0) {
        this.bimRememberState = 'error';
        this.bimRememberError = '没有记下来，请重试。';
        return;
      }
      this.pendingBimEvidence = null;
      this.bimRememberState = 'saved';
    }).catch((_error: Error): void => {
      this.bimRememberState = 'error';
      this.bimRememberError = '没有记下来，请重试。';
    });
  }

  private openUiAgentLab(): void {
    configureUiLabModelSettings(this.getSettings());
    router.pushUrl({ url: UI_AGENT_LAB_ROUTE_URL }, (error) => {
      if (error) {
        clearUiLabModelSettings();
        aiLogError('[AIPhone][UiAgentLabRouteFailed] code=' + error.code.toString());
        this.getUIContext().getPromptAction().showToast({ message: 'UI Lab 打开失败。' });
        return;
      }
      aiLogInfo('[AIPhone][UiAgentLabRouteOpened]');
    });
  }

  private async submitPrompt(
    prompt: string,
    visibleText: string,
    actionId: string = '',
    actionArgs: Object | null = null,
    sourceBimId: string = ''
  ): Promise<void> {
    const trimmed = prompt.trim();
    if (trimmed.length === 0 || this.isBusy) {
      return;
    }
    const currentUserMessageId: string = this.appendMessage('user', visibleText);
    this.inputText = inputTextAfterPromptSubmit(this.inputText);
    this.isAwaitingFirstSurface = true;
    this.promptSubmitMotionGeneration++;
    this.isBusy = true;
    const waterfallQuery = actionId.length === 0 && sourceBimId.length === 0 ?
      waterfallSearchQueryForHomePrompt(trimmed) : '';
    if (waterfallQuery.length > 0) {
      try {
        this.inputText = inputTextAfterPromptSubmit(this.inputText);
        this.appendMessage('user', visibleText);
        if (this.showDeepSearch) this.closeDeepSearch();
        this.ensureInterestWaterfall(false);
        this.interestRecallStarted = true;
        this.startInterestWaterfallSearch(waterfallQuery);
        this.bimRootController.changeIndex(1, !this.bimReduceMotion);
        aiLogInfo('[AIPhone][WaterfallSearchAutoRouted] queryChars=' + waterfallQuery.length.toString());
      } finally {
        this.isBusy = false;
      }
      return;
    }
    let autoDeep = false;
    if (actionId.length === 0) {
      const explicitDecision = explicitDeepSearchRouteDecision(trimmed);
      if (explicitDecision !== null) {
        autoDeep = explicitDecision === 'deepsearch';
      } else if (!hasAggregateSearchIntent(trimmed)) {
        try {
          const decision = await this.canaryModel().complete(deepSearchRouteDecisionPrompt(trimmed));
          autoDeep = deepSearchRouteDecisionFromModelText(decision) === 'deepsearch';
        } catch (error) {
          const message = error instanceof Error ? error.message : JSON.stringify(error);
          aiLogError('[AIPhone][DeepSearchRouteDecisionFailed] ' + logSnippet(message));
        }
      }
    }
    if (autoDeep && trimmed.length > 0) {
      try {
        const contextJson = await this.buildDeepSearchContext();
        this.openDeepSearch(trimmed, contextJson);
        aiLogInfo('[AIPhone][DeepSearchAutoRouted] queryChars=' + trimmed.length.toString() +
          ' context=' + contextJson.length.toString() + 'chars');
      } finally {
        this.isAwaitingFirstSurface = false;
        this.isBusy = false;
      }
      return;
    }
    // 非 DeepSearch 内容：若面板开着则收起，回到主内容展示 multi-agent 结果。
    if (this.showDeepSearch) {
      this.closeDeepSearch();
    }
    const modelPrompt = modelPromptWithActionContext(trimmed, actionId, actionArgs);
    const request: BimForegroundRequest = buildBimForegroundRequest(
      modelPrompt, [], ''
    );
    if (this.baseUrl.trim().length === 0) {
      aiLogError('[AIPhone][A2uiHomeSubmitBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      this.isAwaitingFirstSurface = false;
      this.isBusy = false;
      return;
    }
    this.pendingBimEvidence = null;
    this.bimSuggestionTitle = '';
    this.bimSuggestionReason = '';
    this.bimRememberState = 'ready';
    this.bimRememberError = '';
    const turnGeneration: number = this.beginRuntimeTurn('multi_agent');
    this.inputPlaceholder = DEFAULT_INPUT_PLACEHOLDER;
    aiLogInfo('[AIPhone][A2uiHomeSubmitPrompt] chars=' + request.prompt.length.toString() +
      ' model=' + this.selectedModel +
      ' baseUrl=' + this.baseUrl);
    this.multiTaskActiveSectionId = '';
    this.multiTaskUserPinnedSection = false;
    this.multiTaskShellHtml = '';
    this.markChecking('正在生成 A2UI...');
    try {
      configureLocalToolDebugConfig({
        foodProviderDelayEnabled: this.foodProviderDelayEnabled,
        foodProviderDelayMs: normalizeFoodProviderDelayMs(this.foodProviderDelayMs),
        foodPartialThrottleMs: normalizeFoodPartialThrottleMs(this.foodPartialThrottleMs)
      });
      this.markChecking('正在生成 A2UI...');
      const input: UserInputPayload = await this.multiAgentInput(request.prompt, currentUserMessageId);
      const outcome: MultiAgentTurnOutcome = await this.canaryRuntime().submit(
        request.prompt,
        input,
        turnGeneration
      );
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', turnGeneration
      )) {
        return;
      }
      const result: MultiAgentSettledOutcome = outcome as MultiAgentSettledOutcome;
      if (!result.ok) {
        throw new Error(result.message.length > 0 ?
          result.message : 'Multi-agent runtime failed to complete the turn.');
      }
      if (result.surfaceId.length > 0 &&
        result.surfaceId === this.currentSurface.surfaceId &&
        result.personaId.length > 0) {
        this.applyRuntimeSurface(
          leaderPersonaSurfaceUpdate(
            this.currentSurface,
            result.personaId,
            result.skillId
          ),
          'multi_agent',
          turnGeneration
        );
      }
      const readyMessage: string = result.message.length > 0 ?
        result.message : this.currentSurface.title;
      this.showMemoryResultToast(readyMessage);
      this.appendMessage('assistant', readyMessage);
      const hasCurrentTurnSurface = this.currentSurface.runtimeOwner === 'multi_agent' &&
        this.currentSurface.runtimeGeneration === turnGeneration;
      if (!hasCurrentTurnSurface) {
        this.applyRuntimeSurface(
          createTurnConversationSurface(turnGeneration),
          'multi_agent',
          turnGeneration
        );
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: readyMessage,
        requestDebug: 'multi-agent-runtime',
        assistantDebug: readyMessage,
        error: ''
      }));
      void this.sessionContextCompactor.compactAfterTurn(this.messages);
    } catch (error) {
      if (this.runtimeGeneration !== turnGeneration) {
        return;
      }
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeModelException] ' + logSnippet(message));
      const visibleError = visibleTurnFailureMessage(message);
      this.appendMessage('assistant', visibleError);
      this.applyRuntimeSurface(
        createTurnFailureSurface(visibleError, turnGeneration),
        'multi_agent',
        turnGeneration
      );
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: visibleError,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      void this.sessionContextCompactor.compactAfterTurn(this.messages);
    } finally {
      if (this.runtimeGeneration === turnGeneration) {
        this.isAwaitingFirstSurface = false;
        this.finishForegroundTurn();
        if (isMultiTaskSurface(this.currentSurface)) {
          this.syncMultiTaskPayloadUpdate(this.withMultiTaskActiveSection(this.currentHtmlHomeDocument()));
          this.scheduleMultiTaskPayloadRefresh();
        }
      }
    }
  }

  private async submitBimPrompt(bimId: string, text: string): Promise<void> {
    const query = text.trim();
    if (query.length === 0) return;
    if (this.isBusy) {
      this.bimUiError = 'Appless 正在处理其他请求';
      return;
    }
    let record: BimRecord | undefined = undefined;
    try {
      record = this.bimStore().get(bimId);
    } catch (_error) {
      this.bimUiError = '心上事暂时无法读取';
      return;
    }
    if (record === undefined) {
      this.bimUiError = '这件心上事不存在';
      return;
    }
    if (record.lifecycle === 'ended') {
      this.bimUiError = '心上事已结束，请先重新激活';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '心上事已结束，请先重新激活',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'BIM_ENDED_REACTIVATION_REQUIRED'
      }));
      return;
    }
    const submitError = bimDetailSubmitError(this.baseUrl);
    if (submitError.length > 0) {
      this.bimUiError = submitError;
      return;
    }
    this.bimUiError = '';
    this.bimInputText = '';
    await this.submitPrompt(query, query, '', null, record.id);
  }

  private async sendPrompt(): Promise<void> {
    await this.submitPrompt(this.inputText, this.inputText);
  }

  private applyInterestConversation(command: WaterfallConversationCommand): void {
    this.waterfallConversationState = applyWaterfallConversationCommand(
      this.waterfallConversationState, command);
    aiLogInfo('[AIPhone][WaterfallConversationApply] operation=' + command.operation +
      ' rules=' + command.rules.length.toString() +
      ' generation=' + this.interestWaterfallGeneration.toString());
    this.waterfallConversationMessage = this.waterfallConversationState.summary;
    this.waterfallConversationBusy = false;
    if (this.interestWaterfallFeedState === null) return;
    this.applyInterestWaterfallUpdate(applyWaterfallProfile(
      this.interestWaterfallFeedState,
      this.currentWaterfallPreferenceProfile(),
      Date.now()
    ));
  }

  private async submitWaterfallConversation(text: string): Promise<void> {
    const utterance = text.trim();
    if (utterance.length === 0 || this.interestWaterfallFeedState === null) {
      aiLogInfo('[AIPhone][WaterfallConversationRejected] reason=empty_or_inactive');
      this.waterfallConversationMessage = '没听清，原来的内容不变';
      return;
    }
    const direct = directWaterfallConversationCommand(utterance);
    if (direct !== null) {
      this.applyInterestConversation(direct);
      return;
    }
    const generation = this.interestWaterfallGeneration;
    this.waterfallConversationBusy = true;
    this.waterfallConversationMessage = utterance;
    try {
      const raw = await this.canaryModel().complete(waterfallConversationPrompt(utterance));
      if (generation !== this.interestWaterfallGeneration || this.interestWaterfallFeedState === null) return;
      const command = parseWaterfallConversationCommand(raw);
      if (command === null) {
        aiLogInfo('[AIPhone][WaterfallConversationRejected] reason=invalid_command generation=' +
          generation.toString());
        this.waterfallConversationBusy = false;
        this.waterfallConversationMessage = '没理解这次调整，原来的内容不变';
        return;
      }
      this.applyInterestConversation(command);
    } catch (_error) {
      if (generation !== this.interestWaterfallGeneration) return;
      aiLogError('[AIPhone][WaterfallConversationRejected] reason=model_error generation=' +
        generation.toString());
      this.waterfallConversationBusy = false;
      this.waterfallConversationMessage = '暂时没调好，原来的内容不变';
    }
  }

  private currentVoiceSession(seq: number): boolean {
    return this.isVoiceListening && this.voiceSessionSeq === seq && !this.voiceCompletionHandled;
  }

  private voiceLiveLabel(text: string): string {
    const next = text.trim();
    return next.length > 0 ? next : '语音识别中';
  }

  private finishVoiceInputWithResult(seq: number, result: VoiceInputResult): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const target = this.voiceTarget;
    const next = voiceInputTextAfterRecognition(this.voiceBaseInputText, result.text);
    this.voiceSession = null;
    this.isVoiceListening = false;
    if (target === 'waterfall') {
      if (result.text.trim().length === 0) {
        this.waterfallConversationMessage = '没听清，原来的内容不变';
      } else {
        this.waterfallConversationMessage = result.text.trim();
        void this.submitWaterfallConversation(result.text);
      }
      return;
    }
    if (next === this.voiceBaseInputText) {
      this.voiceInputMessage = '没有识别到语音内容';
    } else {
      this.inputText = next;
      this.voiceInputMessage = '已加入输入框';
    }
  }

  private finishVoiceInputWithError(seq: number, error: Error | Object | string | number | boolean | null | undefined): void {
    if (!this.currentVoiceSession(seq)) {
      return;
    }
    this.voiceCompletionHandled = true;
    const serialized = error === null || error === undefined ? '' : JSON.stringify(error);
    const message = error instanceof Error ? error.message : (serialized === undefined ? '' : serialized);
    if (this.voiceTarget === 'waterfall') {
      this.waterfallConversationMessage = '语音识别失败，原来的内容不变';
    } else {
      this.voiceInputMessage = message.length > 0 ? '语音输入失败：' + message : '语音输入失败';
    }
    this.voiceSession = null;
    this.isVoiceListening = false;
  }

  private async startVoiceInput(target: 'home' | 'waterfall' = 'home'): Promise<void> {
    if ((target === 'home' && this.isBusy) ||
      (target === 'waterfall' && this.waterfallConversationBusy) || this.isVoiceListening) {
      return;
    }
    const seq = this.voiceSessionSeq + 1;
    this.voiceSessionSeq = seq;
    this.voiceSession = null;
    this.voiceTarget = target;
    this.voiceBaseInputText = target === 'home' ? this.inputText : '';
    this.voiceStopRequested = false;
    this.voiceCompletionHandled = false;
    this.isVoiceListening = true;
    if (target === 'waterfall') this.waterfallConversationMessage = '我在听';
    else this.voiceInputMessage = '语音识别中';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const session = await startVoiceInputSession(context, (text: string) => {
        if (this.currentVoiceSession(seq)) {
          if (target === 'waterfall') this.waterfallConversationMessage = this.voiceLiveLabel(text);
          else this.voiceInputMessage = this.voiceLiveLabel(text);
        }
      });
      if (!this.currentVoiceSession(seq)) {
        session.stop().catch((_error: Error) => {});
        return;
      }
      this.voiceSession = session;
      session.result
        .then((result: VoiceInputResult) => {
          this.finishVoiceInputWithResult(seq, result);
        })
        .catch((error: Error) => {
          this.finishVoiceInputWithError(seq, error);
        });
      if (this.voiceStopRequested) {
        session.stop().catch((_error: Error) => {});
      }
    } catch (error) {
      this.finishVoiceInputWithError(seq, error as Error | Object | string | number | boolean | null | undefined);
    }
  }

  private stopVoiceInput(): void {
    if (!this.isVoiceListening) {
      return;
    }
    this.voiceStopRequested = true;
    if (this.voiceSession === null) {
      if (this.voiceTarget === 'waterfall') this.waterfallConversationMessage = '正在理解';
      else this.voiceInputMessage = '识别整理中';
      return;
    }
    if (this.voiceTarget === 'waterfall') {
      this.waterfallConversationMessage = '正在理解';
    } else if (this.voiceInputMessage === '语音识别中') {
      this.voiceInputMessage = '识别整理中';
    }
    this.voiceSession.stop().catch((_error: Error) => {});
  }

  private htmlPinPayload(action: A2uiAction): HtmlPinPayload {
    if (action.prompt.trim().charAt(0) !== '{') {
      return { index: action.prompt };
    }
    try {
      const payload = JSON.parse(action.prompt) as HtmlPinPayload;
      return payload === null ? { index: action.prompt } : payload;
    } catch (_error) {
      return { index: action.prompt };
    }
  }

  private htmlActionIndex(action: A2uiAction, payload: HtmlPinPayload): number {
    const payloadValue = Number.parseInt(this.actionText(payload.index), 10);
    if (payloadValue === payloadValue && payloadValue >= 0) {
      return payloadValue;
    }
    const value = Number.parseInt(action.prompt, 10);
    return value === value && value >= 0 ? value : -1;
  }

  private htmlPinTravelMatches(item: A2uiTravelOptionData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTravelPayloadHasIdentity(payload)) {
      return false;
    }
    const id = this.actionText(payload.id);
    const source = this.actionText(payload.source);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return id === this.actionText(item.id) &&
      source === this.actionText(item.source) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinTrainMatches(item: A2uiTrainData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinTrainPayloadHasIdentity(payload)) {
      return false;
    }
    const trainCode = this.actionText(payload.trainCode);
    const depart = this.actionText(payload.depart);
    const from = this.actionText(payload.from);
    const to = this.actionText(payload.to);
    return trainCode === this.actionText(item.trainCode) &&
      depart === this.actionText(item.depart) &&
      from === this.actionText(item.from) &&
      to === this.actionText(item.to);
  }

  private htmlPinFlightMatches(item: A2uiFlightData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFlightPayloadHasIdentity(payload)) {
      return false;
    }
    const flightNo = this.actionText(payload.flightNo);
    const depTime = this.actionText(payload.depTime);
    const dep = this.actionText(payload.dep);
    const arr = this.actionText(payload.arr);
    return flightNo === this.actionText(item.flightNo) &&
      depTime === this.actionText(item.depTime) &&
      dep === this.actionText(item.dep) &&
      arr === this.actionText(item.arr);
  }

  private htmlPinFoodMatches(item: A2uiFoodData, payload: HtmlPinPayload): boolean {
    if (!this.htmlPinFoodPayloadHasIdentity(payload)) {
      return false;
    }
    const name = this.actionText(payload.name);
    const address = this.actionText(payload.address);
    const location = this.actionText(payload.location);
    const distance = this.actionText(payload.distance);
    return name === this.actionText(item.name) &&
      address === this.actionText(item.address) &&
      location === this.actionText(item.location) &&
      distance === this.actionText(item.distance);
  }

  private htmlPinTravelPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.id).length + this.actionText(payload.source).length +
      this.actionText(payload.depart).length + this.actionText(payload.from).length +
      this.actionText(payload.to).length > 0;
  }

  private htmlPinTrainPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.trainCode).length + this.actionText(payload.depart).length +
      this.actionText(payload.from).length + this.actionText(payload.to).length > 0;
  }

  private htmlPinFlightPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.flightNo).length + this.actionText(payload.depTime).length +
      this.actionText(payload.dep).length + this.actionText(payload.arr).length > 0;
  }

  private htmlPinFoodPayloadHasIdentity(payload: HtmlPinPayload): boolean {
    return this.actionText(payload.name).length + this.actionText(payload.address).length +
      this.actionText(payload.location).length + this.actionText(payload.distance).length > 0;
  }

  private htmlPinTravelRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTravelOptionData | null {
    if (!Array.isArray(model.travelOptions)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.travelOptions.length; rowIndex++) {
      if (this.htmlPinTravelMatches(model.travelOptions[rowIndex], payload)) {
        return model.travelOptions[rowIndex];
      }
    }
    if (this.htmlPinTravelPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.travelOptions.length ? model.travelOptions[index] : null;
  }

  private htmlPinTrainRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiTrainData | null {
    if (!Array.isArray(model.trains)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.trains.length; rowIndex++) {
      if (this.htmlPinTrainMatches(model.trains[rowIndex], payload)) {
        return model.trains[rowIndex];
      }
    }
    if (this.htmlPinTrainPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.trains.length ? model.trains[index] : null;
  }

  private htmlPinFlightRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFlightData | null {
    if (!Array.isArray(model.flights)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.flights.length; rowIndex++) {
      if (this.htmlPinFlightMatches(model.flights[rowIndex], payload)) {
        return model.flights[rowIndex];
      }
    }
    if (this.htmlPinFlightPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.flights.length ? model.flights[index] : null;
  }

  private htmlPinFoodRow(model: A2uiRuntimeDataModel, payload: HtmlPinPayload, index: number): A2uiFoodData | null {
    if (!Array.isArray(model.foods)) {
      return null;
    }
    for (let rowIndex = 0; rowIndex < model.foods.length; rowIndex++) {
      if (this.htmlPinFoodMatches(model.foods[rowIndex], payload)) {
        return model.foods[rowIndex];
      }
    }
    if (this.htmlPinFoodPayloadHasIdentity(payload)) {
      return null;
    }
    return index >= 0 && index < model.foods.length ? model.foods[index] : null;
  }

  private logHtmlHomeActionError(action: A2uiAction, reason: string): void {
    const argsChars = action.args === undefined ? 0 : JSON.stringify(action.args).length;
    aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id +
      ' ok=false reason=' + reason +
      ' kind=' + action.kind +
      ' promptChars=' + action.prompt.length.toString() +
      ' argsChars=' + argsChars.toString());
    if (action.id === 'html_mail_reply_ai_generate' && action.args !== undefined) {
      const args = action.args as MailReplyAiArgs;
      aiLogError('[AIPhone][HtmlHomeMailReplyAiBlocked] prompt=' + action.prompt +
        ' requestKey=' + this.actionText(args.requestKey) +
        ' provider=' + this.actionText(args.provider) +
        ' threadId=' + this.actionText(args.threadId) +
        ' messageId=' + this.actionText(args.messageId) +
        ' subjectChars=' + this.actionText(args.subject).length.toString() +
        ' contextChars=' + this.actionText(args.contextSummary).length.toString());
    }
  }

  private async handleHtmlPinAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_pin_travel' && action.id !== 'html_pin_train' &&
      action.id !== 'html_pin_flight' && action.id !== 'html_pin_food') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    if (action.id === 'html_pin_travel') {
      const row = this.htmlPinTravelRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_travel_row');
        return true;
      }
      await this.pinTravelNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_train') {
      const row = this.htmlPinTrainRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_train_row');
        return true;
      }
      await this.pinTrainNavigationCard(row);
      return true;
    }
    if (action.id === 'html_pin_flight') {
      const row = this.htmlPinFlightRow(model, payload, index);
      if (row === null) {
        this.logHtmlHomeActionError(action, 'missing_flight_row');
        return true;
      }
      await this.pinFlightNavigationCard(row);
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    await this.pinNavigationCard(row);
    return true;
  }

  private async handleFlightBookingAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'flight.booking.ctrip.open') return false;
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    let bookingUrl = '';
    let bookingContext = '';
    let source = 'flight.search';
    if (this.actionText(payload.source) === 'flight') {
      const travelRow = this.htmlPinTravelRow(model, payload, index);
      if (travelRow === null || travelRow.source !== 'flight') {
        this.logHtmlHomeActionError(action, 'missing_travel_flight_row');
        return true;
      }
      const selection = ctripTravelOptionBookingSelection(travelRow);
      bookingUrl = buildCtripFlightSearchUrl(selection);
      bookingContext = buildCtripFlightSelectionContext(selection);
      source = 'travel.search';
    } else {
      const flightRow = this.htmlPinFlightRow(model, payload, index);
      if (flightRow === null) {
        this.logHtmlHomeActionError(action, 'missing_flight_row');
        return true;
      }
      const selection = ctripFlightBookingSelection(flightRow);
      bookingUrl = buildCtripFlightSearchUrl(selection);
      bookingContext = buildCtripFlightSelectionContext(selection);
    }
    if (bookingUrl.length === 0) {
      this.getUIContext().getPromptAction().showToast({
        message: '这条航班缺少出发机场、到达机场或日期，请重新查询后再订票。'
      });
      aiLogError('[AIPhone][FlightBookingOpen] ok=false reason=missing_trusted_parameters');
      return true;
    }
    this.checkoutWebKind = 'flight';
    this.checkoutWebUrl = bookingUrl;
    this.checkoutWebContext = bookingContext;
    this.trainPresaleCheckoutTaskId = '';
    this.showCheckoutWeb = true;
    aiLogInfo('[AIPhone][FlightBookingOpen] provider=携程 channel=flight_ctrip mode=in_app source=' + source);
    return true;
  }

  private async handleTravelCalendarAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== TRAVEL_CALENDAR_ADD_ACTION_ID) {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    const collection = this.actionText(payload.calendarCollection).trim();
    let event: HuaweiTravelCalendarEvent | null = null;
    if (collection === 'travel') {
      const row = this.htmlPinTravelRow(model, payload, index);
      if (row !== null && (row.source === 'train' || row.source === 'flight')) {
        event = travelCalendarEventFromOption(row);
      }
    } else if (collection === 'train') {
      const row = this.htmlPinTrainRow(model, payload, index);
      if (row !== null) {
        event = travelCalendarEventFromTrain(row);
      }
    } else if (collection === 'flight') {
      const row = this.htmlPinFlightRow(model, payload, index);
      if (row !== null) {
        event = travelCalendarEventFromFlight(row);
      }
    }
    if (event === null) {
      this.getUIContext().getPromptAction().showToast({
        message: '这条行程缺少日期、出发时间或到达时间，请重新查询后再加入日历。'
      });
      this.logHtmlHomeActionError(action, 'missing_travel_calendar_fields');
      return true;
    }
    try {
      await this.ensureCalendarPermissions();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const conflicts = await findHuaweiTravelCalendarConflicts(context, [event]);
      if (conflicts.length > 0 && conflicts[0].conflict) {
        const conflictTitle = conflicts[0].eventTitle.length > 0 ? '“' + conflicts[0].eventTitle + '”' : '已有日程';
        this.getUIContext().getPromptAction().showToast({
          message: '该班次与' + conflictTitle + '时间冲突，未加入日历。'
        });
        this.scheduleTravelCalendarConflictRefresh();
        aiLogInfo('[AIPhone][TravelCalendarAction] ok=false reason=time_conflict eventId=' + conflicts[0].eventId);
        return true;
      }
      const result = await addHuaweiTravelCalendarEvent(context, event);
      this.getUIContext().getPromptAction().showToast({
        message: result.duplicate ? '该行程已在系统日历中，无需重复添加。' :
          '已加入系统日历，并设置出发前 2 小时和 30 分钟提醒。'
      });
      aiLogInfo('[AIPhone][TravelCalendarAction] ok=true duplicate=' +
        (result.duplicate ? 'true' : 'false') + ' eventId=' + result.eventId);
      this.scheduleTravelCalendarConflictRefresh();
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.getUIContext().getPromptAction().showToast({ message: '加入系统日历失败：' + message });
      aiLogError('[AIPhone][TravelCalendarAction] ok=false error=' + message.substring(0, 220));
    }
    return true;
  }

  private async handleHtmlFoodMapAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_open_food_map') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return true;
    }
    await this.openFoodMapRow(action, row);
    return true;
  }

  private async openFoodMapRow(action: A2uiAction, row: A2uiFoodData): Promise<void> {
    const uri = buildSystemFoodNavigationUri(this.actionText(row.location), '', row.name);
    if (uri.length === 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '缺少真实坐标，不能打开地图。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.logHtmlHomeActionError(action, 'missing_food_coordinate');
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      try {
        await context.openLink(uri);
      } catch (_linkError) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: uri
        });
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开系统地图：' + row.name,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][HtmlHomeFoodMap] ok=true uriChars=' + uri.length.toString() + ' name=' + row.name);
    } catch (error) {
      const businessError = error as BusinessError;
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '地图打开失败。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: businessError.message
      }));
      aiLogError('[AIPhone][HtmlHomeFoodMap] ok=false message=' + businessError.message);
    }
  }

  private updateHtmlFoodPhoneState(ok: boolean, message: string): void {
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: ok,
      status: ok ? 'ready' : 'error',
      message: message,
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private foodPhoneErrorCode(error: Object | null | undefined): string {
    if (error === null || error === undefined) {
      return 'unknown';
    }
    const businessError = error as BusinessError;
    const code = businessError.code;
    return code === undefined || code === null ? 'unknown' : code.toString();
  }

  private async handleHtmlFoodCallAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'html_call_food') {
      return false;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.updateHtmlFoodPhoneState(false, '当前餐厅数据不可用，无法拨号。');
      this.logHtmlHomeActionError(action, 'invalid_model');
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=validation result=blocked reason=invalid_model');
      return true;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.updateHtmlFoodPhoneState(false, '未找到当前餐厅，无法拨号。');
      this.logHtmlHomeActionError(action, 'missing_food_row');
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=validation result=blocked reason=missing_food_row');
      return true;
    }
    return await this.callFoodRow(action, row);
  }

  private async callFoodRow(action: A2uiAction, row: A2uiFoodData): Promise<boolean> {
    const displayPhone = this.actionText(row.phone).trim();
    const uri = buildFoodPhoneUri(displayPhone);
    if (uri.length === 0) {
      this.updateHtmlFoodPhoneState(false, '餐厅电话号码无效，无法打开拨号器。');
      this.logHtmlHomeActionError(action, 'invalid_food_phone');
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=validation result=blocked reason=invalid_phone nameChars=' +
        row.name.length.toString());
      return true;
    }
    const buttons: [promptAction.Button, promptAction.Button] = [
      { text: '取消', color: '#6B7280' },
      { text: '拨打电话', color: '#995F4C' }
    ];
    let selectedIndex = 0;
    try {
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=confirmation result=shown nameChars=' + row.name.length.toString());
      const selected = await this.getUIContext().getPromptAction().showActionMenu({
        title: row.name + ' · ' + displayPhone,
        buttons: buttons
      });
      selectedIndex = selected.index;
    } catch (_error) {
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=confirmation result=dismissed nameChars=' + row.name.length.toString());
      return true;
    }
    if (selectedIndex !== 1) {
      aiLogInfo('[AIPhone][FoodPhoneAction] stage=confirmation result=cancelled nameChars=' + row.name.length.toString());
      return true;
    }
    aiLogInfo('[AIPhone][FoodPhoneAction] stage=confirmation result=confirmed nameChars=' + row.name.length.toString());
    if (!call.hasVoiceCapability()) {
      this.updateHtmlFoodPhoneState(false, '当前设备不支持语音通话');
      aiLogInfo('[AIPhone][FoodPhoneLaunch] stage=capability result=unsupported');
      return true;
    }
    const verifiedPhone = uri.substring(4);
    try {
      await new Promise<void>((resolve, reject) => {
        call.makeCall(verifiedPhone, (error: BusinessError) => {
          if (error) {
            reject(error);
            return;
          }
          resolve();
        });
      });
      this.updateHtmlFoodPhoneState(true, '已打开系统拨号器，请由你确认拨号');
      aiLogInfo('[AIPhone][FoodPhoneLaunch] stage=makeCall result=success code=0');
    } catch (error) {
      const code = this.foodPhoneErrorCode(error as Object);
      this.updateHtmlFoodPhoneState(false, '系统拨号器打开失败，请稍后重试。');
      aiLogError('[AIPhone][FoodPhoneLaunch] stage=makeCall result=failed code=' + code);
    }
    return true;
  }

  private actionText(value: HtmlActionValue): string {
    if (value === undefined || value === null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return value.toString();
    }
    return '';
  }

  private emptyMailCalendarSuggestion(detail: MailDetail, reason: string): MailCalendarSuggestion {
    return {
      requestKey: detail.requestKey,
      provider: detail.provider,
      threadId: detail.threadId,
      messageId: detail.messageId,
      isWorkRelated: false,
      hasMeeting: false,
      title: '',
      start: '',
      end: '',
      displayTime: '',
      timezone: 'Asia/Shanghai',
      location: '',
      description: '',
      confidence: 'low',
      reason: reason
    };
  }

  private payloadBool(payload: Record<string, HtmlActionValue>, key: string): boolean {
    const value = payload[key];
    if (typeof value === 'boolean') {
      return value;
    }
    return this.actionText(value).trim().toLowerCase() === 'true';
  }

  private payloadText(payload: Record<string, HtmlActionValue>, key: string): string {
    return this.actionText(payload[key]).trim();
  }

  private cleanMailCalendarDescription(value: string): string {
    const lines: string[] = value.split('\n');
    const kept: string[] = [];
    for (let index = 0; index < lines.length; index++) {
      const line = lines[index].trim();
      if (line.length === 0) {
        continue;
      }
      if (/^(来源|邮件来源|Source|发件人|From)\s*[:：]/i.test(line)) {
        continue;
      }
      kept.push(line);
    }
    return kept.join('\n')
      .replace(/[；;，,。\s]*(来源|邮件来源|Source|发件人|From)\s*[:：][^\n]*$/i, '')
      .trim();
  }

  private mailCalendarSuggestionPrompt(detail: MailDetail): string {
    const schema: MailCalendarSuggestionSchemaText = {
      isWorkRelated: 'boolean，邮件是否与工作/学习/会议协作相关',
      hasMeeting: 'boolean，正文是否明确包含可加入日历的会议/活动/面试/评审等日程',
      title: 'string，适合放入日历的短标题',
      start: 'string，ISO 8601 日期时间，必须含时区，例如 2026-07-10T15:00:00+08:00；无法确定则空字符串',
      end: 'string，ISO 8601 日期时间，必须含时区；无法确定结束时间则按开始后30分钟估计',
      displayTime: 'string，面向界面展示的中文时间，例如 7月10日 15:00-15:30；无法确定则空字符串',
      timezone: 'string，默认 Asia/Shanghai',
      location: 'string，会议地点、线上会议链接或空字符串',
      description: 'string，100字以内会议内容摘要，只写会议/活动本身；不得包含来源、邮件来源、发件人、邮箱等信息',
      confidence: 'string，只能是 high/medium/low',
      reason: 'string，简短说明判断依据'
    };
    return '请分析下面邮件是否为工作相关会议，并抽取可写入手机日历的结构化信息。' +
      '不要调用工具，不要写邮件，不要解释。必须只输出一个 JSON 对象，且完全符合这个 schema：' +
      JSON.stringify(schema) +
      '\n规则：' +
      '\n1. 只有明确有会议、面试、评审、同步会、deadline 日程等时间安排时 hasMeeting=true。' +
      '\n2. 时间必须基于邮件标题和正文，不要编造日期；只有相对日期但无法确定基准日期时 start 置空。' +
      '\n3. 如果有开始时间但没有结束时间，end 使用开始时间后 30 分钟。' +
      '\n4. displayTime 是 start/end 的中文可读表达，不要输出 ISO 原文。' +
      '\n5. description 不要写“来源：...”“邮件来源：...”“From：...”或发件人邮箱，来源由界面单独展示。' +
      '\n6. 如果不是工作相关或没有明确时间，仍输出完整 JSON，但按钮字段应为 false/空字符串。' +
      '\n当前设备时间: ' + new Date().toISOString() +
      '\n邮件主题: ' + detail.subject +
      '\nFrom: ' + detail.from +
      '\nTo: ' + JSON.stringify(detail.to) +
      '\n正文:\n' + detail.bodyText;
  }

  private parseMailCalendarSuggestion(detail: MailDetail, raw: string): MailCalendarSuggestion {
    try {
      const jsonText = jsonObjectTextFromModel(raw);
      const payload = JSON.parse(jsonText) as Record<string, HtmlActionValue>;
      const start = this.payloadText(payload, 'start');
      const end = this.payloadText(payload, 'end');
      const isWorkRelated = this.payloadBool(payload, 'isWorkRelated');
      const hasMeeting = this.payloadBool(payload, 'hasMeeting') && start.length > 0;
      return {
        requestKey: detail.requestKey,
        provider: detail.provider,
        threadId: detail.threadId,
        messageId: detail.messageId,
        isWorkRelated: isWorkRelated,
        hasMeeting: hasMeeting,
        title: this.payloadText(payload, 'title'),
        start: start,
        end: end,
        displayTime: this.payloadText(payload, 'displayTime'),
        timezone: this.payloadText(payload, 'timezone').length > 0 ? this.payloadText(payload, 'timezone') : 'Asia/Shanghai',
        location: this.payloadText(payload, 'location'),
        description: this.cleanMailCalendarDescription(this.payloadText(payload, 'description')),
        confidence: this.payloadText(payload, 'confidence').length > 0 ? this.payloadText(payload, 'confidence') : 'low',
        reason: this.payloadText(payload, 'reason')
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailCalendarSuggestionParseFailed] ' + message.substring(0, 240));
      return this.emptyMailCalendarSuggestion(detail, '日程解析失败：' + message.substring(0, 120));
    }
  }

  private async extractMailCalendarSuggestion(detail: MailDetail): Promise<MailCalendarSuggestion> {
    if (this.baseUrl.trim().length === 0 || detail.bodyText.trim().length === 0) {
      return this.emptyMailCalendarSuggestion(detail, '模型未配置或正文为空。');
    }
    const prompt = this.mailCalendarSuggestionPrompt(detail);
    aiLogInfo('[AIPhone][MailCalendarSuggestionRequest] requestKey=' + detail.requestKey +
      ' subjectChars=' + detail.subject.length.toString() +
      ' bodyChars=' + detail.bodyText.length.toString() +
      ' promptChars=' + prompt.length.toString());
    try {
      const result: DirectModelCallResult = await callDirectModel(
        this.getSettings(),
        prompt,
        this.recentMessages()
      );
      const raw = result.assistantDebug.length > 0 ? result.assistantDebug : result.raw;
      if (!result.ok || raw.trim().length === 0) {
        return this.emptyMailCalendarSuggestion(detail, result.error.length > 0 ? result.error : '模型没有返回日程结构。');
      }
      const suggestion = this.parseMailCalendarSuggestion(detail, raw);
      aiLogInfo('[AIPhone][MailCalendarSuggestionDone] requestKey=' + detail.requestKey +
        ' work=' + (suggestion.isWorkRelated ? 'true' : 'false') +
        ' meeting=' + (suggestion.hasMeeting ? 'true' : 'false') +
        ' start=' + suggestion.start);
      return suggestion;
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailCalendarSuggestionFailed] ' + message.substring(0, 240));
      return this.emptyMailCalendarSuggestion(detail, message);
    }
  }

  private mailReplyAiPrompt(args: MailReplyAiArgs): string {
    const recipients = args.to === undefined ? '' : JSON.stringify(args.to);
    return '请为下面这封邮件生成一段简短、礼貌、工作风格的回复正文。' +
      '不要调用工具，不要保存草稿，不要发送邮件。最后必须只用一行输出，格式为 Final: <回复正文>。' +
      '不要输出 JSON，不要输出 Action。' +
      '\n收件人: ' + recipients +
      '\n主题: ' + this.actionText(args.subject) +
      '\n邮件上下文:\n' + this.actionText(args.contextSummary);
  }

  private mailReplyAiEvent(requestKey: string, status: string, message: string, error: string): void {
    const event: MailReplyUiEvent = {
      sequence: Date.now(),
      requestKey: requestKey,
      operation: 'ai',
      status: status,
      message: message,
      error: error
    };
    this.mailReplyEventJson = JSON.stringify(event);
  }

  private mailReplyOperationEvent(
    requestKey: string,
    operation: string,
    status: string,
    message: string,
    error: string
  ): void {
    const event: MailReplyUiEvent = {
      sequence: Date.now(),
      requestKey,
      operation,
      status,
      message,
      error
    };
    this.mailReplyEventJson = JSON.stringify(event);
  }

  private async executeRegisteredGmailReply(args: Object): Promise<ActionExecutionResult> {
    const command = args as MailReplyCommand;
    const requestKey = this.actionText(command.requestKey).trim();
    if (this.actionText(command.provider).trim().toLowerCase() !== 'gmail') {
      const message = 'Gmail reply provider does not match the current mail surface.';
      this.mailReplyOperationEvent(requestKey, 'send', 'error', '', message);
      return {
        status: 'error',
        errorCode: 'GMAIL_REPLY_PROVIDER_MISMATCH',
        message
      };
    }
    try {
      const result = await sendConfiguredMailReply(command);
      if (result.status !== 'success') {
        this.mailReplyOperationEvent(requestKey, 'send', result.status, '', result.message);
        return {
          status: 'error',
          errorCode: 'GMAIL_REPLY_PROVIDER_ERROR',
          message: result.message
        };
      }
      this.mailReplyOperationEvent(
        result.requestKey,
        result.operation,
        result.status,
        result.message,
        ''
      );
      return { status: 'success', output: result as Object };
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.mailReplyOperationEvent(requestKey, 'send', 'error', '', message);
      aiLogError('[AIPhone][MailReplyOperationFailed] provider=gmail operation=send error=' +
        message.substring(0, 240));
      return {
        status: 'error',
        errorCode: 'GMAIL_REPLY_PROVIDER_ERROR',
        message
      };
    }
  }

  private async generateMailReplyDraft(action: A2uiAction): Promise<void> {
    if (action.args === undefined) {
      this.logHtmlHomeActionError(action, 'missing_mail_reply_ai_args');
      return;
    }
    const requestKey = action.prompt.trim();
    if (requestKey.length === 0) {
      this.logHtmlHomeActionError(action, 'invalid_mail_reply_ai_request_key');
      return;
    }
    if (this.baseUrl.trim().length === 0) {
      this.mailReplyAiEvent(requestKey, 'error', '', '请先填写 Base URL。');
      return;
    }
    const args = action.args as MailReplyAiArgs;
    const prompt = this.mailReplyAiPrompt(args);
    aiLogInfo('[AIPhone][MailReplyAiDraftRequest] requestKey=' + requestKey +
      ' provider=' + this.actionText(args.provider) +
      ' threadId=' + this.actionText(args.threadId) +
      ' messageId=' + this.actionText(args.messageId) +
      ' toCount=' + (Array.isArray(args.to) ? args.to.length : 0).toString() +
      ' subjectChars=' + this.actionText(args.subject).length.toString() +
      ' contextChars=' + this.actionText(args.contextSummary).length.toString() +
      ' promptChars=' + prompt.length.toString());
    try {
      const result: DirectModelCallResult = await callDirectModel(
        this.getSettings(),
        prompt,
        this.recentMessages()
      );
      aiLogInfo('[AIPhone][MailReplyAiDraft] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][MailReplyAiDraftRaw] ' + logSnippet(result.raw));
      if (result.error.length > 0) {
        aiLogError('[AIPhone][MailReplyAiDraftError] ' + logSnippet(result.error));
      }
      if (result.assistantDebug.length > 0) {
        aiLogInfo('[AIPhone][MailReplyAiDraftAssistant] ' + logSnippet(result.assistantDebug));
      }
      const text = stripMailReplyAiText(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw);
      if (!result.ok || text.length === 0) {
        const message = result.error.length > 0 ? result.error : 'AI 回复生成失败。';
        this.mailReplyAiEvent(requestKey, 'error', '', message);
        return;
      }
      this.mailReplyAiEvent(requestKey, 'success', text, '');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][MailReplyAiDraftFailed] error=' + message.substring(0, 240));
      this.mailReplyAiEvent(requestKey, 'error', '', message);
    }
  }

  private mailCalendarEvent(requestKey: string, status: string, message: string, eventId: string, error: string): void {
    const event: MailCalendarUiEvent = {
      sequence: Date.now(),
      requestKey: requestKey,
      status: status,
      message: message,
      eventId: eventId,
      error: error
    };
    this.mailCalendarEventJson = JSON.stringify(event);
  }

  private async ensureCalendarPermissions(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, [READ_CALENDAR_PERMISSION, WRITE_CALENDAR_PERMISSION]);
    if (!calendarPermissionGranted(permission.permissions, permission.authResults)) {
      throw new Error('日历权限未授权');
    }
  }

  private async addSuggestedMailCalendarEvent(action: A2uiAction): Promise<void> {
    if (action.args === undefined) {
      this.logHtmlHomeActionError(action, 'missing_mail_calendar_args');
      return;
    }
    const args = action.args as MailCalendarActionArgs;
    const requestKey = this.actionText(args.requestKey).trim();
    if (requestKey.length === 0 || action.prompt.trim() !== requestKey) {
      this.logHtmlHomeActionError(action, 'invalid_mail_calendar_request_key');
      return;
    }
    const suggestion = this.mailCalendarSuggestions[requestKey];
    if (suggestion === undefined) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '没有找到已解析的日程信息。');
      return;
    }
    if (!suggestion.isWorkRelated || !suggestion.hasMeeting || suggestion.start.trim().length === 0) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '这封邮件没有可添加的会议日程。');
      return;
    }
    if (this.actionText(args.provider).trim() !== suggestion.provider ||
      this.actionText(args.threadId).trim() !== suggestion.threadId ||
      this.actionText(args.messageId).trim() !== suggestion.messageId) {
      this.mailCalendarEvent(requestKey, 'error', '', '', '邮件身份校验失败。');
      return;
    }
    try {
      await this.ensureCalendarPermissions();
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const result = await addHuaweiCalendarEvent(context, suggestion);
      this.mailCalendarEvent(requestKey, result.status, result.message, result.eventId, '');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.mailCalendarEvent(requestKey, 'error', '', '', message);
    }
  }

  private locationPermissionGranted(result: LocationPermissionResult): boolean {
    for (let index = 0; index < result.permissions.length; index++) {
      const permission = result.permissions[index];
      const granted = result.authResults.length > index && result.authResults[index] === 0;
      if ((permission === PRECISE_LOCATION_PERMISSION || permission === APPROX_LOCATION_PERMISSION) && granted) {
        return true;
      }
    }
    return false;
  }

  private async ensureLocationPermission(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const permission = await abilityAccessCtrl.createAtManager()
      .requestPermissionsFromUser(context, [APPROX_LOCATION_PERMISSION, PRECISE_LOCATION_PERMISSION]);
    if (!this.locationPermissionGranted({
      permissions: permission.permissions,
      authResults: permission.authResults
    })) {
      throw new Error('定位权限未授权');
    }
  }

  private async currentDeviceCoordinates(): Promise<DeviceCoordinates> {
    await this.ensureLocationPermission();
    if (!geoLocationManager.isLocationEnabled()) {
      this.locationServiceNotice = LOCATION_SERVICE_DISABLED_NOTICE;
      throw new Error(LOCATION_SERVICE_DISABLED_NOTICE);
    }
    this.locationServiceNotice = '';
    const current = await geoLocationManager.getCurrentLocation();
    const longitude = current.longitude;
    const latitude = current.latitude;
    if (longitude === undefined || latitude === undefined) {
      throw new Error('系统未返回当前位置');
    }
    return { longitude: longitude, latitude: latitude };
  }

  private async currentDeviceLocation(): Promise<string> {
    const current = await this.currentDeviceCoordinates();
    return current.longitude.toString() + ',' + current.latitude.toString();
  }

  private foodGeoAddressText(address: geoLocationManager.GeoAddress): string {
    const placeName = address.placeName === undefined ? '' : address.placeName.trim();
    if (placeName.length > 0) {
      return placeName;
    }
    const parts: string[] = [];
    const candidates: (string | undefined)[] = [
      address.administrativeArea,
      address.locality,
      address.subLocality,
      address.roadName
    ];
    candidates.forEach((candidate: string | undefined) => {
      const part = candidate === undefined ? '' : candidate.trim();
      if (part.length > 0 && parts.indexOf(part) < 0) {
        parts.push(part);
      }
    });
    return parts.join('');
  }

  private async currentFoodDeviceLocation(): Promise<FoodDeviceLocation> {
    const current = await this.currentDeviceCoordinates();
    let addressText = '';
    try {
      const addresses = await geoLocationManager.getAddressesFromLocation({
        latitude: current.latitude,
        longitude: current.longitude,
        maxItems: 1,
        locale: 'zh'
      });
      if (addresses.length > 0) {
        addressText = this.foodGeoAddressText(addresses[0]);
      }
    } catch (error) {
      aiLogError('[AIPhone][FoodCurrentLocationReverseGeocode] ok=false reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
    }
    return {
      longitude: current.longitude,
      latitude: current.latitude,
      name: addressText.length > 0 ? addressText : '当前位置',
      address: addressText
    };
  }

  private mergeLuckinLocationArgs(args: Object | null, location: string): Object {
    const merged: Record<string, Object | string | number | boolean | null | undefined> = {};
    if (args !== null) {
      const raw = args as Record<string, Object | string | number | boolean | null | undefined>;
      Object.keys(raw).forEach((key: string) => {
        merged[key] = raw[key];
      });
    }
    merged.location = location;
    merged.locationSource = 'device_current';
    return merged;
  }

  private async argsWithCurrentLocationForTool(toolId: string, args: Object | null): Promise<Object | null> {
    const requestArgs = aggregateSearchArgsWithPolicy(toolId, args, {
      onlyDomesticSources: this.aggregateDomesticOnly,
      includeMultilingualResults: this.aggregateMultilingual
    });
    if (toolId !== 'luckin.order.preview') {
      return requestArgs;
    }
    if (requestArgs !== null) {
      const raw = requestArgs as Record<string, Object | string | number | boolean | null | undefined>;
      const selectedDeptId = raw.deptId;
      if (this.actionText(selectedDeptId).length > 0) {
        return requestArgs;
      }
      const forceRefresh = this.actionText(raw.locationSource) === 'refresh';
      const existingLocation = this.actionText(raw.location);
      if (existingLocation.length > 0 && !forceRefresh) {
        return requestArgs;
      }
    }
    try {
      const location = await this.currentDeviceLocation();
      aiLogInfo('[AIPhone][LuckinCurrentLocation] source=device chars=' + location.length.toString());
      return this.mergeLuckinLocationArgs(requestArgs, location);
    } catch (error) {
      aiLogError('[AIPhone][LuckinCurrentLocation] ok=false reason=' + (error instanceof Error ? error.message : JSON.stringify(error)));
      return requestArgs;
    }
  }

  private isPaymentCheckoutUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.startsWith('https://checkout.stripe.com/') ||
      lower.startsWith('https://buy.stripe.com/') ||
      lower.startsWith('https://www.paypal.com/') ||
      lower.startsWith('https://www.sandbox.paypal.com/');
  }

  private isStripeOnboardingUrl(url: string): boolean {
    return url.trim().toLowerCase().startsWith('https://connect.stripe.com/');
  }

  private stripeOnboardingUrlForAction(action: A2uiAction): string {
    let fromArgs = '';
    if (action.args !== undefined) {
      const payload = action.args as StripeOnboardingActionPayload;
      fromArgs = this.actionText(payload.onboardingUrl).trim();
    }
    if (fromArgs.length > 0) {
      return fromArgs;
    }
    return action.prompt.trim();
  }

  private paymentCheckoutUrlForAction(action: A2uiAction): string {
    let fromArgs = '';
    if (action.args !== undefined) {
      const payload = action.args as PaymentCheckoutActionPayload;
      fromArgs = this.actionText(payload.checkoutUrl).trim();
    }
    if (fromArgs.length > 0) {
      return fromArgs;
    }
    return action.prompt.trim();
  }

  private trainBookingUrlForAction(action: A2uiAction): string {
    if (action.args === undefined) {
      return '';
    }
    const payload = action.args as TrainBookingActionPayload;
    return this.actionText(payload.bookingUrl).trim();
  }

  private trainPresaleTripForAction(action: A2uiAction): TrainPresaleTrip | null {
    if (action.args === undefined) {
      return null;
    }
    const payload = action.args as TrainPresaleScheduleActionPayload;
    const trip: TrainPresaleTrip = {
      trainCode: this.actionText(payload.trainCode).trim(),
      travelDate: this.actionText(payload.travelDate).trim(),
      fromName: this.actionText(payload.from).trim(),
      fromCode: this.actionText(payload.fromCode).trim(),
      toName: this.actionText(payload.to).trim(),
      toCode: this.actionText(payload.toCode).trim(),
      saleAt: this.actionText(payload.saleAt).trim()
    };
    return trip.trainCode.length > 0 && trip.travelDate.length > 0 && trip.fromName.length > 0 &&
      trip.fromCode.length > 0 && trip.toName.length > 0 && trip.toCode.length > 0 && trip.saleAt.length > 0 ? trip : null;
  }

  private async openTrainPresalePanel(action: A2uiAction): Promise<void> {
    const trip = this.trainPresaleTripForAction(action);
    if (trip === null) {
      this.logHtmlHomeActionError(action, 'invalid_train_presale_args');
      return;
    }
    const validation = validateTrainPresaleTrip(trip, new Date().toISOString());
    if (validation.trip === undefined) {
      this.logHtmlHomeActionError(action, 'invalid_or_stale_train_presale_trip');
      aiLogError('[AIPhone][TrainPresalePanel] validation=' + validation.error);
      return;
    }
    try {
      const store = this.trainPresaleStore();
      if (store === null) {
        throw new Error('缺少应用上下文');
      }
      const existing = findMatchingTrainPresaleTask(store.list(), validation.trip);
      const reconciled = existing === undefined ? undefined :
        await reconcileTrainPresaleTask(existing, store, new SystemOneShotScheduler());
      this.trainPresaleTrip = validation.trip;
      this.trainPresaleTask = reconciled === undefined ? null : reconciled.task;
      this.trainPresaleTaskState = reconciled === undefined ? '' : reconciled.task.state;
      this.trainPresaleError = reconciled === undefined ? '' : reconciled.error;
      this.trainPresaleWorking = false;
      this.showCheckoutWeb = false;
      this.trainPresaleCheckoutTaskId = '';
      this.showTrainPresalePanel = true;
      aiLogInfo('[AIPhone][TrainPresalePanel] train=' + validation.trip.trainCode +
        ' existing=' + (existing === undefined ? 'false' : 'true') + ' open=true');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.logHtmlHomeActionError(action, 'train_presale_store_unavailable');
      aiLogError('[AIPhone][TrainPresalePanel] store=' + message.substring(0, 240));
    }
  }

  private trainPresalePreferences(): preferences.Preferences | null {
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context === null) {
      return null;
    }
    return preferences.getPreferencesSync(context, {
      name: TRAIN_PRESALE_TASK_STORE_NAME
    });
  }

  private trainPresaleStore(): TrainPresaleTaskStore | null {
    const store = this.trainPresalePreferences();
    return store === null ? null : new TrainPresaleTaskStore(store);
  }

  private subscribeTrainPresaleHandoff(): void {
    if (this.trainPresaleHandoffSubscribed) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.on(TRAIN_PRESALE_HANDOFF_EVENT, this.trainPresaleHandoffListener);
      this.trainPresaleHandoffSubscribed = true;
    }
  }

  private unsubscribeTrainPresaleHandoff(): void {
    if (!this.trainPresaleHandoffSubscribed) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.off(TRAIN_PRESALE_HANDOFF_EVENT, this.trainPresaleHandoffListener);
    }
    this.trainPresaleHandoffSubscribed = false;
  }

  private subscribeWaterfallConversationTypedTest(): void {
    if (this.waterfallConversationTypedTestSubscribed) return;
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.on(
        WATERFALL_CONVERSATION_TYPED_TEST_EVENT, this.waterfallConversationTypedTestListener);
      this.waterfallConversationTypedTestSubscribed = true;
    }
  }

  private unsubscribeWaterfallConversationTypedTest(): void {
    if (!this.waterfallConversationTypedTestSubscribed) return;
    const context = this.getUIContext().getHostContext() as common.Context;
    if (context !== null) {
      context.getApplicationContext().eventHub.off(
        WATERFALL_CONVERSATION_TYPED_TEST_EVENT, this.waterfallConversationTypedTestListener);
    }
    this.waterfallConversationTypedTestSubscribed = false;
  }

  private pendingTrainPresaleTaskId(): string {
    const store = this.trainPresalePreferences();
    return store === null ? '' : this.preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  }

  private activeTrainPresaleCheckoutTaskId(): string {
    return this.showCheckoutWeb && this.checkoutWebKind === 'train' ? this.trainPresaleCheckoutTaskId : '';
  }

  private refreshBoundTrainPresaleCheckoutTask(): void {
    if (this.trainPresaleCheckoutTaskId.length === 0) {
      return;
    }
    const store: TrainPresaleTaskStore | null = this.trainPresaleStore();
    const task: TrainPresaleTask | undefined = store === null ? undefined : store.get(this.trainPresaleCheckoutTaskId);
    if (task === undefined || task.state === 'executing') {
      return;
    }
    this.trainPresaleTask = task;
    this.trainPresaleTaskState = task.state;
    this.trainPresaleError = task.lastError;
  }

  private pendingTrainPresaleResumeDrain(): TrainPresaleResumeDrain {
    if (this.trainPresaleResumeDrain === null) {
      this.trainPresaleResumeDrain = new TrainPresaleResumeDrain(
        (): string => this.pendingTrainPresaleTaskId(),
        (): string => this.activeTrainPresaleCheckoutTaskId(),
        async (taskId: string): Promise<void> => this.resumePendingTrainPresaleTask(taskId)
      );
    }
    return this.trainPresaleResumeDrain;
  }

  private requestPendingTrainPresaleResume(): void {
    void this.pendingTrainPresaleResumeDrain().request();
  }

  private displaceTrainPresaleCheckout(nextTaskId: string): void {
    if (!this.showCheckoutWeb || this.checkoutWebKind !== 'train' ||
      this.trainPresaleCheckoutTaskId === nextTaskId) {
      return;
    }
    this.showCheckoutWeb = false;
    this.trainPresaleCheckoutTaskId = '';
  }

  private async resumePendingTrainPresaleTask(taskId: string): Promise<void> {
    const nativeStore = this.trainPresalePreferences();
    if (nativeStore === null) {
      return;
    }
    if (taskId.length === 0 || this.preferenceText(
      nativeStore.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim() !== taskId) {
      return;
    }
    try {
      const store = new TrainPresaleTaskStore(nativeStore);
      const task = store.get(taskId);
      if (task === undefined || task.state !== 'executing') {
        const state: TrainPresaleTaskState = task === undefined || task.state === 'scheduled' ? 'needs_user' : task.state;
        const reason = task === undefined ? '' :
          (task.state === 'scheduled' ? '开售任务交接状态异常，请重新打开任务。' : task.lastError);
        transitionTrainPresaleHandoff(nativeStore, taskId, state, reason);
        aiLogInfo('[AIPhone][TrainPresaleResume] taskId=' + taskId + ' skipped=not_executing');
        return;
      }
      this.displaceTrainPresaleCheckout(taskId);
      this.trainPresaleTask = task;
      this.trainPresaleTaskState = task.state;
      this.trainPresaleTrip = {
        trainCode: task.trainCode,
        travelDate: task.travelDate,
        fromName: task.fromName,
        fromCode: task.fromCode,
        toName: task.toName,
        toCode: task.toCode,
        saleAt: task.saleAt
      };
      this.trainPresaleWorking = true;
      this.trainPresaleError = '';
      this.showTrainPresalePanel = true;
      const request: TrainPresaleRecheckRequest = {
        trainCode: task.trainCode,
        travelDate: task.travelDate,
        fromName: task.fromName,
        fromCode: task.fromCode,
        toName: task.toName,
        toCode: task.toCode,
        seatPriority: task.seatPriority
      };
      const check: TrainPresaleAvailabilityCheck = await recheck12306TrainAvailability(request);
      const executionTask: TrainPresaleExecutionTask = {
        state: task.state,
        trainCode: task.trainCode,
        travelDate: task.travelDate,
        fromName: task.fromName,
        fromCode: task.fromCode,
        toName: task.toName,
        toCode: task.toCode,
        seatPriority: task.seatPriority
      };
      const decision: TrainPresaleExecutionDecision = decideTrainPresaleExecution(executionTask, check);
      if (decision.state === 'needs_user') {
        const transition: TrainPresaleHandoffTransitionResult = transitionTrainPresaleHandoff(
          nativeStore, taskId, 'needs_user', decision.reason);
        const persisted = transition.task;
        if (persisted === undefined || persisted.state !== 'needs_user') {
          throw new Error('余票核验结果保存失败');
        }
        this.trainPresaleTask = persisted;
        this.trainPresaleTaskState = persisted.state;
        this.trainPresaleError = persisted.lastError;
        aiLogError('[AIPhone][TrainPresaleResume] taskId=' + taskId +
          ' status=' + check.status + ' reason=' + decision.reason.substring(0, 240));
        return;
      }
      const latest = store.get(taskId);
      if (latest === undefined || latest.state !== 'executing') {
        if (latest !== undefined) {
          transitionTrainPresaleHandoff(nativeStore, taskId, latest.state, latest.lastError);
        }
        aiLogInfo('[AIPhone][TrainPresaleResume] taskId=' + taskId + ' skipped=state_changed');
        return;
      }
      this.trainPresaleTask = latest;
      this.trainPresaleTaskState = latest.state;
      this.checkoutWebKind = 'train';
      this.checkoutWebUrl = decision.bookingUrl;
      this.trainPresaleCheckoutTaskId = taskId;
      this.showTrainPresalePanel = false;
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][TrainPresaleResume] taskId=' + taskId + ' status=verified');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.trainPresaleError = '开售任务恢复失败：' + message;
      aiLogError('[AIPhone][TrainPresaleResume] taskId=' + taskId + ' error=' + message.substring(0, 240));
    } finally {
      this.trainPresaleWorking = false;
    }
  }

  private closeExecutingTrainCheckout(closingTaskId: string): void {
    if (closingTaskId.length === 0 || closingTaskId !== this.trainPresaleCheckoutTaskId) {
      return;
    }
    const nativeStore = this.trainPresalePreferences();
    if (nativeStore === null) {
      this.trainPresaleError = '无法保存购票页关闭状态，请重新打开应用后继续。';
      return;
    }
    const reason = '已关闭 12306 购票页；尚未进入订单协助，请重新打开任务继续。';
    try {
      const current = new TrainPresaleTaskStore(nativeStore).get(closingTaskId);
      if (current !== undefined && current.state !== 'executing') {
        this.trainPresaleTask = current;
        this.trainPresaleTaskState = current.state;
        this.trainPresaleError = current.lastError;
        this.trainPresaleCheckoutTaskId = '';
        return;
      }
      const transition: TrainPresaleHandoffTransitionResult = transitionBoundTrainPresaleCheckout(
        nativeStore, this.trainPresaleCheckoutTaskId, closingTaskId, reason);
      if (transition.task === undefined || transition.task.state !== 'needs_user') {
        throw new Error('关闭状态保存失败');
      }
      this.trainPresaleTask = transition.task;
      this.trainPresaleTaskState = transition.task.state;
      this.trainPresaleError = transition.task.lastError;
      this.trainPresaleCheckoutTaskId = '';
      this.getUIContext().getPromptAction().showToast({ message: reason });
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.trainPresaleError = '关闭购票页后状态保存失败：' + message;
      aiLogError('[AIPhone][TrainPresaleCheckoutClose] taskId=' + closingTaskId +
        ' error=' + message.substring(0, 240));
    }
  }

  private async confirmTrainPresale(submission: TrainPresalePanelSubmission): Promise<void> {
    if (this.trainPresaleWorking) {
      return;
    }
    this.trainPresaleWorking = true;
    this.trainPresaleError = '';
    const now = new Date();
    const input: TrainPresaleConfirmationInput = {
      source: submission.source,
      trainCode: this.trainPresaleTrip.trainCode,
      travelDate: this.trainPresaleTrip.travelDate,
      fromName: this.trainPresaleTrip.fromName,
      fromCode: this.trainPresaleTrip.fromCode,
      toName: this.trainPresaleTrip.toName,
      toCode: this.trainPresaleTrip.toCode,
      saleAt: this.trainPresaleTrip.saleAt,
      passengerNames: submission.passengerNames,
      seatPriority: submission.seatPriority,
      unpaidOrderAuthorized: submission.unpaidOrderAuthorized,
      debugEnabled: this.isDebugBuild,
      taskId: 'train-presale-' + now.getTime().toString(),
      createdAt: now.toISOString()
    };
    try {
      const store = this.trainPresaleStore();
      if (store === null) {
        throw new Error('缺少应用上下文');
      }
      const validated: TrainPresaleConfirmationResult = validateTrainPresaleConfirmation(input);
      if (validated.task === undefined) {
        this.trainPresaleError = validated.error;
        return;
      }
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await ensureReminderNotificationEnabled(
        (): Promise<boolean> => notificationManager.isNotificationEnabled(),
        (): Promise<void> => notificationManager.requestEnableNotification(context)
      );
      let scheduleResult: TrainPresaleScheduleResult;
      if (submission.source === 'debug') {
        const debugInput: TrainPresaleDebugRunInput = {
          debugEnabled: this.isDebugBuild,
          fromName: this.trainPresaleTrip.fromName,
          fromCode: this.trainPresaleTrip.fromCode,
          toName: this.trainPresaleTrip.toName,
          toCode: this.trainPresaleTrip.toCode,
          passengerNames: submission.passengerNames,
          seatPriority: submission.seatPriority,
          unpaidOrderAuthorized: submission.unpaidOrderAuthorized
        };
        scheduleResult = await runTrainPresaleDebugConfirmation(
          debugInput, store, new SystemOneShotScheduler(), select12306DebugTrain);
      } else {
        scheduleResult = await scheduleTrainPresaleTask(validated.task, store, new SystemOneShotScheduler());
      }
      if (scheduleResult.task === undefined) {
        this.trainPresaleError = scheduleResult.error;
        aiLogError('[AIPhone][TrainPresaleSchedule] taskId=' + input.taskId +
          ' error=' + scheduleResult.error.substring(0, 240));
      } else {
        this.trainPresaleTask = scheduleResult.task;
        if (scheduleResult.task.source === 'debug') {
          this.trainPresaleTrip = {
            trainCode: scheduleResult.task.trainCode,
            travelDate: scheduleResult.task.travelDate,
            fromName: scheduleResult.task.fromName,
            fromCode: scheduleResult.task.fromCode,
            toName: scheduleResult.task.toName,
            toCode: scheduleResult.task.toCode,
            saleAt: scheduleResult.task.saleAt
          };
        }
        this.trainPresaleTaskState = scheduleResult.task.state;
        this.trainPresaleError = scheduleResult.error;
        if (scheduleResult.task.state === 'scheduled') {
          aiLogInfo('[AIPhone][TrainPresaleSchedule] taskId=' + scheduleResult.task.taskId +
            ' reminderId=' + scheduleResult.task.reminderId.toString());
        } else {
          aiLogError('[AIPhone][TrainPresaleSchedule] taskId=' + scheduleResult.task.taskId +
            ' state=' + scheduleResult.task.state + ' error=' + scheduleResult.error.substring(0, 240));
        }
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.trainPresaleError = '提醒创建失败：' + message;
      aiLogError('[AIPhone][TrainPresaleSchedule] taskId=' + input.taskId + ' error=' + message.substring(0, 240));
    } finally {
      this.trainPresaleWorking = false;
    }
  }

  private async cancelTrainPresaleTask(): Promise<void> {
    const task = this.trainPresaleTask;
    const canEndDebug = task !== null && task.source === 'debug' && task.state === 'awaiting_payment';
    if (task === null || (task.state !== 'scheduled' && task.state !== 'needs_user' && !canEndDebug) ||
      this.trainPresaleWorking) {
      return;
    }
    this.trainPresaleWorking = true;
    this.trainPresaleError = '';
    try {
      const store = this.trainPresaleStore();
      if (store === null) {
        throw new Error('缺少应用上下文');
      }
      const result = await cancelScheduledTrainPresaleTask(task, store, new SystemOneShotScheduler());
      this.trainPresaleTask = result.task;
      this.trainPresaleTaskState = result.state;
      this.trainPresaleError = result.error;
      if (result.state === 'cancelled') {
        aiLogInfo('[AIPhone][TrainPresaleCancel] taskId=' + task.taskId + ' ok=true');
      } else {
        aiLogError('[AIPhone][TrainPresaleCancel] taskId=' + task.taskId +
          ' state=' + result.state + ' error=' + result.error.substring(0, 240));
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.trainPresaleError = '取消任务失败：' + message;
      aiLogError('[AIPhone][TrainPresaleCancel] taskId=' + task.taskId + ' error=' + message.substring(0, 240));
    }
    this.trainPresaleWorking = false;
  }

  private luckinPayUrlForAction(action: A2uiAction): string {
    if (action.args !== undefined) {
      const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
      const payOrderUrl = payload.payOrderUrl;
      const qrCodeUrl = payload.payOrderQrCodeUrl;
      if (typeof payOrderUrl === 'string' && payOrderUrl.trim().length > 0) {
        return payOrderUrl.trim();
      }
      if (typeof qrCodeUrl === 'string' && qrCodeUrl.trim().length > 0) {
        return qrCodeUrl.trim();
      }
    }
    return action.prompt.trim();
  }

  private isLuckinPayUrl(url: string): boolean {
    const lower = url.trim().toLowerCase();
    return lower.startsWith('https://') ||
      lower.startsWith('http://') ||
      lower.startsWith('weixin://') ||
      lower.startsWith('weixin');
  }

  private isLuckinPaymentActionId(actionId: string): boolean {
    return actionId === 'luckin.pay.open' ||
      actionId === 'luckin.demo.alipay.open' ||
      actionId === 'luckin.demo.googlepay.open' ||
      actionId === 'luckin.order.status';
  }

  private luckinPaymentOrderIdFromAction(action: A2uiAction): string {
    if (action.args === undefined) {
      return '';
    }
    const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    return this.actionText(payload.orderId).trim();
  }

  private luckinPayUrlFromDocument(document: HtmlHomeDocument): string {
    const pools: A2uiAction[] = [];
    document.actions.forEach((action: HtmlHomeAction) => {
      pools.push(action as A2uiAction);
    });
    document.blocks.forEach((block: HtmlHomeBlock) => {
      block.actions.forEach((action: HtmlHomeAction) => {
        pools.push(action as A2uiAction);
      });
    });
    for (let index = 0; index < pools.length; index += 1) {
      const action = pools[index];
      if (action.id === 'luckin.pay.open') {
        const payUrl = this.luckinPayUrlForAction(action);
        if (this.isLuckinPayUrl(payUrl)) {
          return payUrl;
        }
      }
    }
    for (let blockIndex = 0; blockIndex < document.blocks.length; blockIndex += 1) {
      const block = document.blocks[blockIndex];
      for (let rowIndex = 0; rowIndex < block.rows.length; rowIndex += 1) {
        const row = block.rows[rowIndex];
        if ((row.label === '支付链接' || row.label === '支付二维码') && this.isLuckinPayUrl(row.value)) {
          return row.value.trim();
        }
      }
    }
    return '';
  }

  private luckinCreateArgsFromAction(action: A2uiAction): Object | null {
    if (action.args === undefined) {
      return null;
    }
    const payload = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    const deptId = this.actionText(payload.deptId).trim();
    const productId = this.actionText(payload.productId).trim();
    const skuCode = this.actionText(payload.skuCode).trim();
    if (deptId.length === 0 || productId.length === 0 || skuCode.length === 0) {
      return null;
    }
    return action.args;
  }

  private async resolveLuckinPayUrlForAction(action: A2uiAction): Promise<string> {
    let payUrl = this.luckinPayUrlForAction(action);
    if (this.isLuckinPayUrl(payUrl)) {
      return payUrl;
    }
    const orderId = this.luckinPaymentOrderIdFromAction(action);
    if (orderId.length > 0) {
      this.logLuckinPaymentAction(action, 'refresh_pay_url_start');
      payUrl = await this.refreshLuckinPayUrlForAction(action);
      if (this.isLuckinPayUrl(payUrl)) {
        return payUrl;
      }
    }
    const createArgs = this.luckinCreateArgsFromAction(action);
    if (createArgs !== null) {
      this.logLuckinPaymentAction(action, 'retry_create_start');
      const ok = await this.callToolById('luckin.order.create', '确认创建瑞幸订单', 'luckin.pay.open', createArgs);
      if (ok) {
        payUrl = this.luckinPayUrlFromDocument(this.currentHtmlHomeDocument());
        if (this.isLuckinPayUrl(payUrl)) {
          return payUrl;
        }
      }
    }
    return '';
  }

  private async refreshLuckinPayUrlForAction(action: A2uiAction): Promise<string> {
    const orderId = this.luckinPaymentOrderIdFromAction(action);
    if (orderId.length === 0) {
      return '';
    }
    let args: Object;
    if (action.args === undefined) {
      const statusArgs: LuckinOrderStatusArgs = {
        orderId: orderId
      };
      args = statusArgs as Object;
    } else {
      args = action.args;
    }
    const ok = await this.callToolById('luckin.order.status', '查询瑞幸订单状态', 'luckin.pay.open', args);
    if (!ok) {
      return '';
    }
    return this.luckinPayUrlFromDocument(this.currentHtmlHomeDocument());
  }

  private logLuckinPaymentAction(action: A2uiAction, stage: string, extra: string = ''): void {
    const document = this.currentHtmlHomeDocument();
    const allowed = isHtmlHomeActionAllowed(document, action);
    const suffix = extra.length > 0 ? ' ' + extra : '';
    aiLogInfo('[AIPhone][LuckinPaymentAction] stage=' + stage +
      ' id=' + action.id +
      ' kind=' + action.kind +
      ' busy=' + (this.isBusy ? 'true' : 'false') +
      ' allowed=' + (allowed ? 'true' : 'false') +
      ' surfaceKind=' + document.kind +
      ' orderId=' + this.luckinPaymentOrderIdFromAction(action) +
      ' promptChars=' + action.prompt.length.toString() +
      ' payUrlChars=' + this.luckinPayUrlForAction(action).length.toString() + suffix);
  }

  private paymentCheckoutPayload(action: A2uiAction): PaymentCheckoutActionPayload {
    if (action.args === undefined) {
      return JSON.parse('{}') as PaymentCheckoutActionPayload;
    }
    return action.args as PaymentCheckoutActionPayload;
  }

  private rememberPaymentCheckout(action: A2uiAction, checkoutUrl: string): void {
    const payload = this.paymentCheckoutPayload(action);
    this.checkoutWebUrl = checkoutUrl;
    this.checkoutWebKind = 'payment';
    this.trainPresaleCheckoutTaskId = '';
    this.paymentCheckoutProvider = this.actionText(payload.provider).trim().toLowerCase();
    this.paymentCheckoutProviderSessionId = this.actionText(payload.providerSessionId).trim();
    this.paymentCheckoutRecipient = this.actionText(payload.recipient).trim();
    this.paymentCheckoutAmountText = this.actionText(payload.amountText).trim();
    this.paymentCheckoutCurrency = this.actionText(payload.currency).trim();
    this.paymentCheckoutNote = this.actionText(payload.note).trim();
  }

  private queryValue(url: string, key: string): string {
    const marker = key + '=';
    const queryIndex = url.indexOf('?');
    if (queryIndex < 0) {
      return '';
    }
    const query = url.substring(queryIndex + 1);
    const parts = query.split('&');
    for (let index = 0; index < parts.length; index++) {
      if (parts[index].startsWith(marker)) {
        return decodeURIComponent(parts[index].substring(marker.length));
      }
    }
    return '';
  }

  private async handlePaymentCheckoutReturn(url: string): Promise<void> {
    this.showCheckoutWeb = false;
    this.trainPresaleCheckoutTaskId = '';
    const lower = url.toLowerCase();
    if (lower.indexOf('/cancel') >= 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '支付页面已取消，没有完成扣款。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    if (this.paymentCheckoutProvider !== 'paypal') {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '支付页面已返回 app，请在供应商页面确认支付状态。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    const orderId = this.paymentCheckoutProviderSessionId.length > 0 ?
      this.paymentCheckoutProviderSessionId : this.queryValue(url, 'token');
    if (orderId.length === 0) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: 'PayPal 已返回 app，但缺少 order id，不能 capture。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: url
      }));
      return;
    }
    const args: PaymentCaptureArgs = {
      provider: 'paypal',
      recipient: this.paymentCheckoutRecipient,
      amountText: this.paymentCheckoutAmountText,
      currency: this.paymentCheckoutCurrency,
      note: this.paymentCheckoutNote,
      phase: 'capture',
      providerSessionId: orderId
    };
    await this.callToolById('payment.send', 'PayPal payment approved, capture order ' + orderId, 'payment.capture', args);
  }

  private async saveDynamicCredentialAndTest(action: A2uiAction): Promise<void> {
    let payload: HtmlDynamicCredentialPayload;
    try {
      payload = JSON.parse(action.prompt) as HtmlDynamicCredentialPayload;
    } catch (_error) {
      this.logHtmlHomeActionError(action, 'invalid_dynamic_payload');
      return;
    }
    const credentialRef = this.actionText(payload.credentialRef);
    const credentialValue = this.actionText(payload.credentialValue).trim();
    const data = this.currentDynamicToolConnect();
    let toolId = this.actionText(payload.toolId);
    let testPrompt = this.actionText(payload.prompt);
    if (toolId.length === 0 && data !== null) {
      toolId = data.toolId;
    }
    if (testPrompt.length === 0 && data !== null) {
      testPrompt = data.prompt;
    }
    if (testPrompt.length === 0) {
      testPrompt = toolId;
    }
    if (data === null || credentialRef !== data.credentialRef || toolId !== data.toolId) {
      this.logHtmlHomeActionError(action, 'dynamic_credential_not_allowed');
      return;
    }
    if (credentialRef.length === 0 || credentialValue.length === 0 || toolId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_dynamic_credential');
      return;
    }
    try {
      await new AssetCredentialStore().put(credentialRef, credentialValue);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'checking',
        message: '已保存到本机，正在测试连接。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      await this.callToolById(toolId, testPrompt, 'dynamic_test_connection');
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '凭据保存失败，请检查本机安全存储状态。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][HtmlHomeAction] id=' + action.id + ' ok=false reason=credential_save_failed message=' + message);
    }
  }

  private rideActionArgText(action: A2uiAction, keys: string[]): string {
    const args = action.args as Record<string, RideActionArgValue> | undefined;
    if (args === undefined || args === null) {
      return '';
    }
    for (let index = 0; index < keys.length; index++) {
      const value = args[keys[index]];
      if (value !== undefined && value !== null) {
        const text = String(value).trim();
        if (text.length > 0) {
          return text;
        }
      }
    }
    return '';
  }

  private rideCachedProducts(cacheJson: string): RideCachedProduct[] {
    if (cacheJson.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(cacheJson) as Record<string, Object | string | number | boolean | null | undefined>;
      const productsValue = parsed.products;
      if (!Array.isArray(productsValue)) {
        return [];
      }
      const products: RideCachedProduct[] = [];
      productsValue.forEach((item: Object | string | number | boolean | null | undefined) => {
        if (item === null || item === undefined || typeof item !== 'object' || Array.isArray(item)) {
          return;
        }
        const record = item as Record<string, RideActionArgValue>;
        const productName = String(record.productName === undefined || record.productName === null ? '' : record.productName).trim();
        const productCategory = String(record.productCategory === undefined || record.productCategory === null ? '' : record.productCategory).trim();
        const priceText = String(record.priceText === undefined || record.priceText === null ? '' : record.priceText).trim();
        if (productName.length > 0 || priceText.length > 0) {
          products.push({
            productName: productName.length > 0 ? productName : '车型',
            productCategory: productCategory,
            priceText: priceText
          });
        }
      });
      return products;
    } catch (_error) {
      return [];
    }
  }

  private rideTraceIdFromCache(cacheJson: string): string {
    try {
      const parsed = JSON.parse(cacheJson) as Record<string, RideActionArgValue>;
      const traceId = parsed.traceId;
      return traceId === undefined || traceId === null ? '' : String(traceId).trim();
    } catch (_error) {
      return '';
    }
  }

  private rideConfirmActionFromCache(
    product: RideCachedProduct,
    traceId: string,
    routeText: string,
    pickupLocation: string,
    destinationLocation: string,
    estimateCacheJson: string,
    isPrimary: boolean
  ): A2uiAction {
    const args: RideLocalOrderActionArgs = {
      productCategory: product.productCategory,
      product_category: product.productCategory,
      productName: product.productName,
      priceText: product.priceText,
      routeText: routeText,
      pickupLocation: pickupLocation,
      originLocation: pickupLocation,
      destinationLocation: destinationLocation,
      estimateCacheJson: estimateCacheJson,
      estimateTraceId: traceId,
      estimate_trace_id: traceId,
      traceId: traceId
    };
    return {
      id: 'ride.order.confirm',
      label: '确认叫' + product.productName,
      prompt: '确认下单：' + product.productName + ' ' + product.priceText,
      kind: 'prompt',
      variant: isPrimary ? 'primary' : 'secondary',
      args: args
    };
  }

  private restoreRideVehicleSelection(action: A2uiAction): void {
    const estimateCacheJson = this.rideActionArgText(action, ['estimateCacheJson']);
    const products = this.rideCachedProducts(estimateCacheJson);
    const traceId = this.rideTraceIdFromCache(estimateCacheJson);
    if (products.length === 0 || traceId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_ride_estimate_cache');
      return;
    }
    const model = this.parsedDataModel();
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_ride_surface_model');
      return;
    }
    const routeText = this.rideActionArgText(action, ['routeText', 'route']);
    const pickupLocation = this.rideActionArgText(action, ['pickupLocation', 'originLocation']);
    const destinationLocation = this.rideActionArgText(action, ['destinationLocation']);
    const rows: A2uiLabelValueData[] = [];
    if (routeText.length > 0) {
      rows.push({ label: '路线', value: routeText });
    }
    if (pickupLocation.length > 0) {
      rows.push({ label: '起点坐标', value: pickupLocation });
    }
    if (destinationLocation.length > 0) {
      rows.push({ label: '终点坐标', value: destinationLocation });
    }
    products.forEach((product: RideCachedProduct) => {
      const category = product.productCategory.length > 0 ? '（' + product.productCategory + '）' : '';
      rows.push({ label: product.productName + category, value: product.priceText });
    });
    rows.push({ label: 'traceId', value: traceId.length > 16 ? traceId.substring(0, 8) + '...' + traceId.substring(traceId.length - 6) : traceId });
    rows.push({ label: '来源', value: '滴滴 taxi_estimate（已恢复）' });
    const actions: A2uiAction[] = [];
    products.forEach((product: RideCachedProduct) => {
      if (product.productCategory.length > 0) {
        actions.push(this.rideConfirmActionFromCache(
          product,
          traceId,
          routeText,
          pickupLocation,
          destinationLocation,
          estimateCacheJson,
          actions.length === 0
        ));
      }
    });
    const result: A2uiGenericToolResultData = {
      sourceTag: '滴滴',
      toolName: 'ride.estimate',
      title: '滴滴价格预估',
      status: 'success',
      summary: '已恢复之前查询到的车型选择。',
      rows: rows,
      rawPreview: '{"restored":true}',
      actions: actions
    };
    model.genericToolResults = [result];
    model.summary = {
      text: result.summary,
      toolName: 'ride.estimate',
      dataLabel: 'genericToolResults',
      count: 1
    };
    const nextSurface = this.surfaceSnapshot(this.currentSurface);
    nextSurface.title = '滴滴价格预估';
    nextSurface.status = 'ready';
    nextSurface.dataModelJson = JSON.stringify(model);
    nextSurface.sequence = this.currentSurface.sequence + 1;
    this.applySurface(nextSurface);
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '已恢复车型选择页。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private async handleMemoryCandidateClientAction(action: A2uiAction): Promise<void> {
    const runtime = this.multiAgentRuntime;
    if (runtime === null) {
      this.showMemoryCandidateActionToast('这张记忆选择卡已失效，请重新发起请求。');
      return;
    }
    this.isBusy = true;
    try {
      const result: MemoryCandidateManagerActionResult = await runtime.handleMemoryCandidateAction(action);
      if (!result.handled || !result.presented || !result.notify) return;
      this.showMemoryCandidateActionToast(result.message);
      const completed = result.status === 'success' || result.status === 'partial';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: completed,
        status: completed ? 'ready' : 'error',
        message: result.message,
        requestDebug: 'memory-candidate-client-action',
        assistantDebug: result.message,
        error: completed ? '' : result.message
      }));
      if (completed) this.appendMessage('assistant', result.message);
    } finally {
      this.isBusy = false;
    }
  }

  private async handleClientAction(action: A2uiAction): Promise<void> {
    aiLogInfo('[AIPhone][A2uiHomeClientAction] id=' + action.id);
    if (action.id === 'food_store_map_open') {
      const args = action.args as Record<string, Object | string | number | boolean | null | undefined> | undefined;
      if (args !== undefined && this.actionText(args['surfaceId']) === this.currentSurface.surfaceId &&
        this.currentSurface.intent === 'food') {
        this.foodStoreMapOpen = true;
        this.syncFoodStoreMapSnapshot(this.currentSurface);
        aiLogInfo('[AIPhone][FoodStoreMapOpen] surfaceId=' + this.currentSurface.surfaceId);
      }
      return;
    }
    if (await this.handleStoredFoodFavoriteAction(action)) {
      return;
    }
    if (action.id === 'food_luckin_menu_open') {
      await this.openLuckinFoodMenu(action);
      return;
    }
    if (action.id === 'food_mcd_menu_open') {
      await this.openMcDonaldsFoodMenu(action);
      return;
    }
    if (action.id === 'food_luckin_order_preview') {
      await this.previewLuckinFoodMenuProduct(action);
      return;
    }
    if (action.id === 'food_mcd_menu_detail') {
      await this.openMcDonaldsFoodMenuDetail(action);
      return;
    }
    if (action.id === 'food_mcd_order_quote') {
      await this.quoteMcDonaldsFoodMenuProduct(action);
      return;
    }
    if (action.id === 'food_mcd_order_create') {
      await this.createMcDonaldsFoodMenuProductOrder(action);
      return;
    }
    if (action.id === 'food_mcd_order_status') {
      await this.refreshMcDonaldsFoodMenuOrder(action);
      return;
    }
    if (action.id === 'food_mcd_pay_open') {
      await this.openMcDonaldsFoodMenuPayment(action);
      return;
    }
    if (action.id === 'food_favorite_remove') {
      await this.removeFoodFavorite(action);
      return;
    }
    if (action.id === 'food_favorite_toggle') {
      await this.toggleFoodFavorite(action);
      return;
    }
    if (action.id === 'food_address_book_save') {
      await this.saveCurrentFoodAddress(action);
      return;
    }
    if (action.id === 'food_address_book_delete') {
      await this.deleteFoodAddress(action);
      return;
    }
    if (action.id === 'food_change_location') {
      await this.refreshFoodSearchAtLocation(action);
      return;
    }
    if (action.id === 'food_relocate_current') {
      await this.relocateFoodToCurrentDeviceLocation(action);
      return;
    }
    if (await this.handleDailyBriefClientAction(action)) {
      return;
    }
    if (action.id === 'html_mail_calendar_add') {
      await this.addSuggestedMailCalendarEvent(action);
      return;
    }
    if (action.id === 'html_mail_reply_save' || action.id === 'html_mail_reply_send') {
      if (action.args === undefined) {
        this.logHtmlHomeActionError(action, 'missing_mail_reply_args');
        return;
      }
      const command = action.args as MailReplyCommand;
      const requestKey = this.actionText(command.requestKey).trim();
      const operation = action.id === 'html_mail_reply_save' ? 'draft' : 'send';
      if (requestKey.length === 0 || this.actionText(command.provider).trim().length === 0 ||
        this.actionText(command.body).trim().length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_mail_reply_args');
        return;
      }
      try {
        let result: MailReplyOperationResult;
        if (operation === 'draft') {
          result = await saveConfiguredMailDraft(command);
        } else {
          result = await sendConfiguredMailReply(command);
        }
        this.mailReplyOperationEvent(requestKey, operation, result.status, result.message, '');
      } catch (error) {
        const message = error instanceof Error ? error.message : JSON.stringify(error);
        this.mailReplyOperationEvent(requestKey, operation, 'error', '', message);
        aiLogError('[AIPhone][MailReplyOperationFailed] provider=' + this.actionText(command.provider) +
          ' operation=' + operation + ' error=' + message.substring(0, 240));
      }
      return;
    }
    if (action.id === 'html_mail_reply_ai_generate') {
      await this.generateMailReplyDraft(action);
      return;
    }
    if (this.isPersonaEditorAction(action)) {
      this.openPersonaEditor(action.prompt, action.id === 'persona_soul_edit' ? 'soul' : 'memory');
      return;
    }
    if (action.id === 'stripe.account.open') {
      const onboardingUrl = this.stripeOnboardingUrlForAction(action);
      if (!this.isStripeOnboardingUrl(onboardingUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_stripe_onboarding_url');
        return;
      }
      await this.openExternalUrl(onboardingUrl);
      return;
    }
    if (action.id === 'web.open.source') {
      const url = firecrawlHttpUrlOf(action.prompt);
      if (url.length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_firecrawl_source_url');
        return;
      }
      await this.openExternalUrl(url, ['https', 'http']);
      return;
    }
    if (action.id === 'luckin.demo.googlepay.return') {
      this.restoreLuckinReturnSurface(action.prompt.length > 0 ? action.prompt : action.id);
      return;
    }
    if (action.id === 'hotel.search.restore') {
      if (this.multiAgentRuntime !== null) {
        const restored = this.multiAgentRuntime.restoreSearchSurface();
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: restored,
          status: restored ? 'ready' : 'error',
          message: restored ? '已返回酒店搜索结果。' : '酒店搜索结果已失效。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: restored ? '' : 'hotel search surface restore rejected'
        }));
        if (restored) {
          this.hotelReturnSurface = null;
        }
        return;
      }
      this.restoreHotelReturnSurface(action.prompt.length > 0 ? action.prompt : action.id);
      return;
    }
    if (this.isStripeReceivingActionId(action)) {
      await this.callToolById(
        'payment.account.setup',
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (action.id === 'social_hub_select_item') {
      this.selectSocialHubItem(action);
      return;
    }
    if (action.id === 'social_hub_draft_reply') {
      this.draftSocialHubReply(action);
      return;
    }
    if (action.id === 'social_hub_send_reply') {
      await this.sendSocialHubReply(action);
      return;
    }
    if (action.id === 'social_hub_authorize') {
      await this.openSocialHubComposioAuth(action.prompt);
      return;
    }
    if (action.id === 'social_hub_open_source') {
      await this.openSocialHubSource(action);
      return;
    }
    if (await this.handleHtmlFoodMapAction(action)) {
      return;
    }
    if (await this.handleTravelCalendarAction(action)) {
      return;
    }
    if (await this.handleFlightBookingAction(action)) {
      return;
    }
    if (await this.handleHtmlFoodCallAction(action)) {
      return;
    }
    if (await this.handleHtmlPinAction(action)) {
      return;
    }
    if (action.id === 'html_dynamic_save_and_test') {
      await this.saveDynamicCredentialAndTest(action);
      return;
    }
    if (action.id === 'payment.account.save') {
      await this.savePaymentAccount(action);
      return;
    }
    if (action.id === 'payment.checkout.open') {
      const checkoutUrl = this.paymentCheckoutUrlForAction(action);
      if (!this.isPaymentCheckoutUrl(checkoutUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_payment_checkout_url');
        return;
      }
      this.rememberPaymentCheckout(action, checkoutUrl);
      this.checkoutWebKind = 'payment';
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][PaymentCheckoutOpen] urlChars=' + checkoutUrl.length.toString());
      return;
    }
    if (action.id === 'train.presale.schedule') {
      await this.openTrainPresalePanel(action);
      return;
    }
    if (action.id === 'train.booking.open') {
      const bookingUrl = this.trainBookingUrlForAction(action);
      if (!isAllowed12306BookingUrl(bookingUrl)) {
        this.logHtmlHomeActionError(action, 'invalid_12306_booking_url');
        return;
      }
      this.checkoutWebKind = 'train';
      this.checkoutWebUrl = bookingUrl;
      this.trainPresaleCheckoutTaskId = '';
      this.showCheckoutWeb = true;
      aiLogInfo('[AIPhone][TrainBookingOpen] urlChars=' + bookingUrl.length.toString());
      return;
    }
    if (action.id === 'train.booking.alipay.open') {
      aiLogInfo('[AIPhone][TrainAlipayOpen] chars=' + action.prompt.length.toString());
      const opened = await this.openExternalUrl(action.prompt, ['alipays']);
      if (!opened) {
        this.logHtmlHomeActionError(action, 'alipay_open_failed');
      }
      return;
    }
    if (action.id === 'luckin.pay.open') {
      const payUrl = await this.resolveLuckinPayUrlForAction(action);
      if (!this.isLuckinPayUrl(payUrl)) {
        this.logLuckinPaymentAction(action, 'invalid_pay_url');
        this.logHtmlHomeActionError(action, 'invalid_luckin_pay_url');
        return;
      }
      aiLogInfo('[AIPhone][LuckinWechatPayOpen] chars=' + payUrl.length.toString());
      await this.openExternalUrl(payUrl, ['https', 'weixin']);
      return;
    }
    if (action.id === 'luckin.demo.alipay.open') {
      const url = action.prompt.trim().length > 0 ? action.prompt.trim() : 'alipays://';
      aiLogInfo('[AIPhone][LuckinDemoAlipayOpen] chars=' + url.length.toString());
      await this.openExternalUrl(url, ['alipays']);
      return;
    }
    if (action.id === 'luckin.demo.googlepay.open') {
      this.rememberLuckinReturnSurface(action.id);
      const args: PaymentFallbackArgs = {
        provider: 'paypal',
        fundingSource: 'google_pay',
        recipient: '罗一格',
        amountText: '5',
        currency: 'USD',
        note: 'Luckin Google Pay demo only; does not pay the Luckin order.',
        originalQuery: '用 Google Pay 给罗一格转 5 美金'
      };
      aiLogInfo('[AIPhone][LuckinDemoGooglePayPayment] recipient=' + args.recipient +
        ' amount=' + args.amountText + ' currency=' + args.currency);
      await this.callToolById(
        'payment.send',
        '用 Google Pay 给罗一格转 5 美金',
        action.id,
        args
      );
      return;
    }
    if (action.id === 'gmail.authorize') {
      const authorizeUrl = await prepareGmailOAuthAuthorizationUrl();
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GMAIL_MCP_AUTH_SETUP_URL);
      return;
    }
    if (action.id === 'calendar.authorize') {
      const authorizeUrl = await prepareGoogleOAuthAuthorizationUrl(GOOGLE_OAUTH_SETUP_URL);
      await this.openExternalUrl(authorizeUrl.length > 0 ? authorizeUrl : GOOGLE_OAUTH_SETUP_URL);
      return;
    }
    if (action.id === 'calendar.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GOOGLE_CALENDAR_WEB_URL);
      return;
    }
    if (action.id === 'gmail.open.web') {
      await this.openExternalUrl(action.prompt.length > 0 ? action.prompt : GMAIL_WEB_URL);
      return;
    }
    if (action.id === 'maps.open.web') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'ride.vehicle.change') {
      this.restoreRideVehicleSelection(action);
      return;
    }
    if (action.id === 'ride.open.didi' || action.id === 'ride.open.amap') {
      if (action.prompt.length === 0) {
        this.logHtmlHomeActionError(action, 'missing_ride_app_link');
        return;
      }
      await this.openExternalUrl(
        action.prompt,
        action.id === 'ride.open.didi' ? ['diditaxi'] : ['amapuri']
      );
      return;
    }
    if (action.id === 'media.open.web') {
      const mediaUrl = officialMediaVideoPlaybackUrl(action.prompt);
      if (mediaUrl.length === 0) {
        this.logHtmlHomeActionError(action, 'invalid_media_url');
        return;
      }
      await this.openExternalUrl(mediaUrl);
      return;
    }
    if (action.id === 'dynamic_open_registration') {
      await this.openExternalUrl(action.prompt);
      return;
    }
    if (action.id === 'dynamic_test_connection') {
      const data = this.currentDynamicToolConnect();
      if (data === null || data.toolId.length === 0) {
        return;
      }
      const testPrompt = action.prompt.length > 0 ? action.prompt : (data.prompt.length > 0 ? data.prompt : data.toolId);
      await this.callToolById(data.toolId, testPrompt, action.id);
      return;
    }
  }

  private refreshFoodAddressBookUi(): void {
    this.htmlHomeCacheKey = '';
    this.htmlHomeCacheHtml = '';
    this.surfaceRenderTick = this.surfaceRenderTick + 1;
    this.syncHtmlHomeStableHtml();
  }

  private foodAddressBookStore(): FoodAddressBookStore | null {
    if (this.foodAddressBookStoreInstance !== null) {
      return this.foodAddressBookStoreInstance;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.foodAddressBookStoreInstance = new FoodAddressBookStore(context);
      return this.foodAddressBookStoreInstance;
    } catch (error) {
      aiLogError('[AIPhone][FoodAddressBookStore] phase=open ok=false reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
      return null;
    }
  }

  private loadFoodAddressBook(): void {
    const store = this.foodAddressBookStore();
    this.foodSavedAddresses = store === null ? [] : store.list();
    this.htmlHomeCacheKey = '';
    this.htmlHomeCacheHtml = '';
    aiLogInfo('[AIPhone][FoodAddressBookLoaded] count=' + this.foodSavedAddresses.length.toString());
  }

  private foodFavoritesStore(): FoodFavoritesStore | null {
    if (this.foodFavoritesStoreInstance !== null) {
      return this.foodFavoritesStoreInstance;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.foodFavoritesStoreInstance = new FoodFavoritesStore(context);
      return this.foodFavoritesStoreInstance;
    } catch (error) {
      aiLogError('[AIPhone][FoodFavoritesStore] phase=open ok=false reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
      return null;
    }
  }

  private loadFoodFavorites(): void {
    const store = this.foodFavoritesStore();
    this.foodFavorites = store === null ? [] : store.list();
    this.htmlHomeCacheKey = '';
    this.htmlHomeCacheHtml = '';
    aiLogInfo('[AIPhone][FoodFavoritesLoaded] count=' + this.foodFavorites.length.toString());
  }

  private foodRowForLuckinMenuAction(action: A2uiAction): A2uiFoodData | null {
    if (action.args !== undefined && action.args !== null) {
      const favorite = this.storedFoodFavorite(action);
      if (favorite !== null) {
        return favorite;
      }
    }
    const model = this.parsedDataModel();
    if (model === null) {
      return null;
    }
    const payload = this.htmlPinPayload(action);
    return this.htmlPinFoodRow(model, payload, this.htmlActionIndex(action, payload));
  }

  private publishFoodMenuPatch(patch: FoodMenuPatch): void {
    this.luckinFoodMenuContext = patch.brand === 'luckin' ? patch : null;
    this.luckinInlinePatchJson = JSON.stringify(patch);
    this.luckinInlinePatchTick = this.luckinInlinePatchTick + 1;
    aiLogInfo('[AIPhone][FoodMenuPatch] brand=' + patch.brand + ' status=' + patch.status +
      ' products=' + patch.products.length.toString());
  }

  private async openLuckinFoodMenu(action: A2uiAction): Promise<void> {
    if (this.currentSurface.intent !== 'food') {
      this.logHtmlHomeActionError(action, 'food_surface_required');
      return;
    }
    const row = this.foodRowForLuckinMenuAction(action);
    if (row === null || !foodCardHasLuckinSource(row)) {
      this.logHtmlHomeActionError(action, row === null ? 'missing_food_row' : 'luckin_source_required');
      return;
    }
    const surfaceId = this.currentSurface.surfaceId;
    const requestKey = row.name + '|' + row.address;
    const result = await queryLuckinFoodMenuForCard(row);
    if (this.currentSurface.surfaceId !== surfaceId) {
      aiLogInfo('[AIPhone][LuckinFoodMenuPatch] status=ignored reason=surface_changed');
      return;
    }
    this.publishFoodMenuPatch({
      kind: 'food-menu',
      brand: 'luckin',
      status: result.found ? 'ready' : 'error',
      requestKey: requestKey,
      deptId: result.deptId,
      storeName: result.storeName.length > 0 ? result.storeName : row.name,
      storeAddress: result.storeAddress.length > 0 ? result.storeAddress : row.address,
      storeLocation: result.storeLocation.length > 0 ? result.storeLocation : (row.location ?? ''),
      products: result.products,
      error: result.error
    });
  }

  private async openMcDonaldsFoodMenu(action: A2uiAction): Promise<void> {
    if (this.currentSurface.intent !== 'food') {
      this.logHtmlHomeActionError(action, 'food_surface_required');
      return;
    }
    const row = this.foodRowForLuckinMenuAction(action);
    if (row === null || !foodCardHasMcDonaldsSource(row)) {
      this.logHtmlHomeActionError(action, row === null ? 'missing_food_row' : 'mcd_source_required');
      return;
    }
    const surfaceId = this.currentSurface.surfaceId;
    const requestKey = row.name + '|' + row.address;
    const result = await queryMcDonaldsFoodMenuForCard(row);
    if (this.currentSurface.surfaceId !== surfaceId) {
      aiLogInfo('[AIPhone][McDonaldsFoodMenuPatch] status=ignored reason=surface_changed');
      return;
    }
    this.mcDonaldsFoodMenuContext = {
      surfaceId: surfaceId,
      requestKey: requestKey,
      storeCode: result.storeCode,
      beCode: result.beCode,
      storeName: result.storeName.length > 0 ? result.storeName : row.name,
      storeAddress: result.storeAddress.length > 0 ? result.storeAddress : row.address,
      storeLocation: result.storeLocation.length > 0 ? result.storeLocation : (row.location ?? ''),
      products: result.products,
      quote: null,
      orderId: '',
      payUrl: ''
    };
    this.publishFoodMenuPatch({
      kind: 'food-menu',
      brand: 'mcdonalds',
      status: result.found ? 'ready' : 'error',
      step: 'menu',
      requestKey: requestKey,
      deptId: '',
      storeName: result.storeName.length > 0 ? result.storeName : row.name,
      storeAddress: result.storeAddress.length > 0 ? result.storeAddress : row.address,
      storeLocation: result.storeLocation.length > 0 ? result.storeLocation : (row.location ?? ''),
      products: result.products,
      error: result.error
    });
  }

  private mcDonaldsFoodMenuProduct(
    context: McDonaldsFoodMenuContext,
    productId: string
  ): LuckinFoodMenuProduct | null {
    for (let index = 0; index < context.products.length; index += 1) {
      if (context.products[index].productId === productId) {
        return context.products[index];
      }
    }
    return null;
  }

  private mcDonaldsFoodMenuPatch(
    context: McDonaldsFoodMenuContext,
    step: 'menu' | 'detail' | 'quote' | 'order',
    status: 'ready' | 'error',
    error: string
  ): FoodMenuPatch {
    return {
      kind: 'food-menu',
      brand: 'mcdonalds',
      status: status,
      step: step,
      requestKey: context.requestKey,
      deptId: '',
      storeName: context.storeName,
      storeAddress: context.storeAddress,
      storeLocation: context.storeLocation,
      products: context.products,
      error: error
    };
  }

  private mcDonaldsFoodMenuActionContext(action: A2uiAction): McDonaldsFoodMenuContext | null {
    if (this.currentSurface.intent !== 'food' || action.args === undefined || action.args === null ||
      this.mcDonaldsFoodMenuContext === null) {
      this.logHtmlHomeActionError(action, 'mcd_food_menu_context_required');
      return null;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const surfaceId = this.actionText(payload.surfaceId).trim();
    const requestKey = this.actionText(payload.requestKey).trim();
    const context = this.mcDonaldsFoodMenuContext;
    if (surfaceId !== this.currentSurface.surfaceId || surfaceId !== context.surfaceId ||
      requestKey !== context.requestKey) {
      this.logHtmlHomeActionError(action, 'invalid_mcd_food_menu_context');
      return null;
    }
    return context;
  }

  private async openMcDonaldsFoodMenuDetail(action: A2uiAction): Promise<void> {
    const context = this.mcDonaldsFoodMenuActionContext(action);
    if (context === null || action.args === undefined || action.args === null) {
      return;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const productId = this.actionText(payload.productId).trim();
    const product = this.mcDonaldsFoodMenuProduct(context, productId);
    if (product === null) {
      this.logHtmlHomeActionError(action, 'mcd_food_menu_product_not_found');
      return;
    }
    const surfaceId = context.surfaceId;
    const result = await queryMcDonaldsFoodMenuDetail(context.storeCode, context.beCode, product.productId);
    if (this.currentSurface.surfaceId !== surfaceId || this.mcDonaldsFoodMenuContext !== context) {
      aiLogInfo('[AIPhone][McDonaldsFoodMenuDetailPatch] status=ignored reason=surface_changed');
      return;
    }
    context.quote = null;
    // Some promotional products are absent from query-meal-detail even though
    // query-meals marks them as orderable. Keep the trusted menu product usable
    // with its default configuration and surface the provider warning in Web.
    const patch = this.mcDonaldsFoodMenuPatch(context, 'detail', 'ready', result.error);
    patch.selectedProductId = product.productId;
    patch.selectedProductName = product.name;
    patch.selectedPictureUrl = product.pictureUrl;
    patch.selectedPriceText = result.priceText.length > 0 ? result.priceText : product.priceText;
    patch.quantity = 1;
    patch.rows = result.rows;
    this.publishFoodMenuPatch(patch);
  }

  private async quoteMcDonaldsFoodMenuProduct(action: A2uiAction): Promise<void> {
    const context = this.mcDonaldsFoodMenuActionContext(action);
    if (context === null || action.args === undefined || action.args === null) {
      return;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const productId = this.actionText(payload.productId).trim();
    const quantity = Number(this.actionText(payload.quantity));
    const product = this.mcDonaldsFoodMenuProduct(context, productId);
    if (product === null || !Number.isFinite(quantity) || quantity < 1 || quantity > 20 || Math.floor(quantity) !== quantity) {
      this.logHtmlHomeActionError(action, 'invalid_mcd_food_menu_quote');
      return;
    }
    const surfaceId = context.surfaceId;
    const result = await quoteMcDonaldsFoodMenuOrder(
      context.storeCode, context.beCode, product.productId, quantity
    );
    if (this.currentSurface.surfaceId !== surfaceId || this.mcDonaldsFoodMenuContext !== context) {
      aiLogInfo('[AIPhone][McDonaldsFoodOrderQuotePatch] status=ignored reason=surface_changed');
      return;
    }
    this.mcDonaldsFoodMenuQuoteSequence = this.mcDonaldsFoodMenuQuoteSequence + 1;
    const quoteToken = surfaceId + ':' + this.mcDonaldsFoodMenuQuoteSequence.toString();
    context.quote = result.ready && result.takeWayCode.length > 0 ? {
      productId: product.productId,
      quantity: result.quantity,
      takeWayCode: result.takeWayCode,
      quoteToken: quoteToken
    } : null;
    const patch = this.mcDonaldsFoodMenuPatch(context, 'quote', result.ready ? 'ready' : 'error', result.error);
    patch.selectedProductId = product.productId;
    patch.selectedProductName = product.name;
    patch.selectedPictureUrl = product.pictureUrl;
    patch.selectedPriceText = product.priceText;
    patch.quantity = result.quantity;
    patch.rows = result.rows;
    patch.quoteToken = context.quote === null ? '' : context.quote.quoteToken;
    patch.canCreate = context.quote !== null;
    this.publishFoodMenuPatch(patch);
  }

  private async createMcDonaldsFoodMenuProductOrder(action: A2uiAction): Promise<void> {
    const context = this.mcDonaldsFoodMenuActionContext(action);
    if (context === null || action.args === undefined || action.args === null || context.quote === null) {
      this.logHtmlHomeActionError(action, 'mcd_food_menu_quote_required');
      return;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const productId = this.actionText(payload.productId).trim();
    const quantity = Number(this.actionText(payload.quantity));
    const quoteToken = this.actionText(payload.quoteToken).trim();
    const quote = context.quote;
    const product = this.mcDonaldsFoodMenuProduct(context, productId);
    if (product === null || productId !== quote.productId || quantity !== quote.quantity ||
      quoteToken !== quote.quoteToken) {
      this.logHtmlHomeActionError(action, 'invalid_mcd_food_menu_create');
      return;
    }
    context.quote = null;
    const surfaceId = context.surfaceId;
    const result = await createMcDonaldsFoodMenuOrder(
      context.storeCode, context.beCode, product.productId, quantity, quote.takeWayCode
    );
    if (this.currentSurface.surfaceId !== surfaceId || this.mcDonaldsFoodMenuContext !== context) {
      aiLogInfo('[AIPhone][McDonaldsFoodOrderCreatePatch] status=ignored reason=surface_changed');
      return;
    }
    context.orderId = result.orderId;
    context.payUrl = result.payUrl;
    const patch = this.mcDonaldsFoodMenuPatch(context, 'order', result.ready ? 'ready' : 'error', result.error);
    patch.selectedProductId = product.productId;
    patch.selectedProductName = product.name;
    patch.selectedPictureUrl = product.pictureUrl;
    patch.quantity = quantity;
    patch.rows = result.rows;
    patch.orderId = result.orderId;
    patch.payUrl = result.payUrl;
    patch.statusText = result.statusText;
    this.publishFoodMenuPatch(patch);
  }

  private async refreshMcDonaldsFoodMenuOrder(action: A2uiAction): Promise<void> {
    const context = this.mcDonaldsFoodMenuActionContext(action);
    if (context === null || action.args === undefined || action.args === null) {
      return;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const orderId = this.actionText(payload.orderId).trim();
    if (orderId.length === 0 || orderId !== context.orderId) {
      this.logHtmlHomeActionError(action, 'invalid_mcd_food_menu_order_status');
      return;
    }
    const surfaceId = context.surfaceId;
    const result = await queryMcDonaldsFoodMenuOrder(orderId);
    if (this.currentSurface.surfaceId !== surfaceId || this.mcDonaldsFoodMenuContext !== context) {
      return;
    }
    if (result.payUrl.length > 0) {
      context.payUrl = result.payUrl;
    }
    const patch = this.mcDonaldsFoodMenuPatch(context, 'order', result.ready ? 'ready' : 'error', result.error);
    patch.rows = result.rows;
    patch.orderId = context.orderId;
    patch.payUrl = context.payUrl;
    patch.statusText = result.statusText;
    this.publishFoodMenuPatch(patch);
  }

  private async openMcDonaldsFoodMenuPayment(action: A2uiAction): Promise<void> {
    const context = this.mcDonaldsFoodMenuActionContext(action);
    if (context === null || action.args === undefined || action.args === null) {
      return;
    }
    const payload = action.args as McDonaldsFoodMenuActionPayload;
    const orderId = this.actionText(payload.orderId).trim();
    if (orderId.length === 0 || orderId !== context.orderId || context.payUrl.length === 0) {
      this.logHtmlHomeActionError(action, 'invalid_mcd_food_menu_payment');
      return;
    }
    await this.openExternalUrl(context.payUrl, ['https']);
  }

  private async previewLuckinFoodMenuProduct(action: A2uiAction): Promise<void> {
    if (this.currentSurface.intent !== 'food' || action.args === undefined || action.args === null ||
      this.luckinFoodMenuContext === null) {
      this.logHtmlHomeActionError(action, 'food_menu_context_required');
      return;
    }
    const payload = action.args as LuckinFoodMenuOrderPayload;
    const surfaceId = this.actionText(payload.surfaceId).trim();
    const requestKey = this.actionText(payload.requestKey).trim();
    const deptId = this.actionText(payload.deptId).trim();
    const productId = this.actionText(payload.productId).trim();
    const skuCode = this.actionText(payload.skuCode).trim();
    const context = this.luckinFoodMenuContext;
    if (surfaceId !== this.currentSurface.surfaceId || requestKey !== context.requestKey ||
      deptId !== context.deptId || productId.length === 0 || skuCode.length === 0) {
      this.logHtmlHomeActionError(action, 'invalid_food_menu_order_context');
      return;
    }
    let product: LuckinFoodMenuProduct | null = null;
    for (let index = 0; index < context.products.length; index++) {
      const candidate = context.products[index];
      if (candidate.productId === productId && candidate.skuCode === skuCode) {
        product = candidate;
        break;
      }
    }
    if (product === null) {
      this.logHtmlHomeActionError(action, 'food_menu_product_not_found');
      return;
    }
    const prompt = '点一份' + product.name;
    const previewArgs: LuckinFoodMenuPreviewArgs = {
      deptId: context.deptId,
      deptName: context.storeName,
      address: context.storeAddress,
      location: context.storeLocation,
      productId: product.productId,
      productName: product.name,
      skuCode: product.skuCode,
      pictureUrl: product.pictureUrl,
      originalQuery: prompt,
      previewPrompt: product.name
    };
    await this.callToolById('luckin.order.preview', prompt, action.id, previewArgs as Object);
  }

  private async toggleFoodFavorite(action: A2uiAction): Promise<void> {
    if (this.currentSurface.intent !== 'food') {
      this.logHtmlHomeActionError(action, 'food_surface_required');
      return;
    }
    const model = this.parsedDataModel();
    const payload = this.htmlPinPayload(action);
    const index = this.htmlActionIndex(action, payload);
    if (model === null) {
      this.logHtmlHomeActionError(action, 'invalid_model');
      return;
    }
    const row = this.htmlPinFoodRow(model, payload, index);
    if (row === null) {
      this.logHtmlHomeActionError(action, 'missing_food_row');
      return;
    }
    const store = this.foodFavoritesStore();
    if (store === null) {
      this.logHtmlHomeActionError(action, 'food_favorites_store_unavailable');
      return;
    }
    try {
      const active = await store.toggle(row);
      this.foodFavorites = store.list();
      this.getUIContext().getPromptAction().showToast({ message: active ? '已收藏门店' : '已取消收藏' });
      aiLogInfo('[AIPhone][FoodFavoriteToggle] active=' + (active ? 'true' : 'false') +
        ' count=' + this.foodFavorites.length.toString() + ' name=' + row.name);
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][FoodFavoriteToggle] ok=false reason=' + message.substring(0, 220));
      this.getUIContext().getPromptAction().showToast({ message: '收藏操作失败，请稍后重试。' });
    }
  }

  private async removeFoodFavorite(action: A2uiAction): Promise<void> {
    if (this.currentSurface.intent !== 'food' || action.args === undefined || action.args === null) {
      this.logHtmlHomeActionError(action, 'food_surface_and_args_required');
      return;
    }
    const args = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    const favoriteId = this.actionText(args['favoriteId']).trim();
    if (favoriteId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_favorite_id');
      return;
    }
    const store = this.foodFavoritesStore();
    if (store === null) {
      this.logHtmlHomeActionError(action, 'food_favorites_store_unavailable');
      return;
    }
    try {
      const removed = await store.remove(favoriteId);
      this.foodFavorites = store.list();
      this.getUIContext().getPromptAction().showToast({ message: '已取消收藏' });
      aiLogInfo('[AIPhone][FoodFavoriteRemove] removed=' + (removed ? 'true' : 'false') +
        ' count=' + this.foodFavorites.length.toString());
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][FoodFavoriteRemove] ok=false reason=' + message.substring(0, 220));
      this.getUIContext().getPromptAction().showToast({ message: '取消收藏失败，请稍后重试。' });
    }
  }

  private storedFoodFavorite(action: A2uiAction): FoodFavoriteViewModel | null {
    if (action.args === undefined || action.args === null) {
      return null;
    }
    const args = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    const favoriteId = this.actionText(args['favoriteId']).trim();
    const store = this.foodFavoritesStore();
    return favoriteId.length === 0 || store === null ? null : store.find(favoriteId);
  }

  private async handleStoredFoodFavoriteAction(action: A2uiAction): Promise<boolean> {
    if (action.id !== 'food_favorite_map' && action.id !== 'food_favorite_call' &&
      action.id !== 'food_favorite_pin') {
      return false;
    }
    if (this.currentSurface.intent !== 'food') {
      this.logHtmlHomeActionError(action, 'food_surface_required');
      return true;
    }
    const favorite = this.storedFoodFavorite(action);
    if (favorite === null) {
      this.logHtmlHomeActionError(action, 'missing_food_favorite');
      this.getUIContext().getPromptAction().showToast({ message: '未找到这条收藏记录。' });
      return true;
    }
    if (action.id === 'food_favorite_map') {
      await this.openFoodMapRow(action, favorite);
      return true;
    }
    if (action.id === 'food_favorite_call') {
      await this.callFoodRow(action, favorite);
      return true;
    }
    await this.pinNavigationCard(favorite);
    return true;
  }

  private foodAddressActionArgs(action: A2uiAction): Record<string, Object | string | number | boolean | null | undefined> | null {
    if (action.args === undefined || this.currentSurface.intent !== 'food') {
      return null;
    }
    const args = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    if (this.actionText(args['surfaceId']).trim() !== this.currentSurface.surfaceId) {
      return null;
    }
    return args;
  }

  private async saveCurrentFoodAddress(action: A2uiAction): Promise<void> {
    const args = this.foodAddressActionArgs(action);
    if (args === null) {
      this.logHtmlHomeActionError(action, 'stale_food_address_book');
      return;
    }
    const requestedAddressId = this.actionText(args['addressId']).trim();
    const entry: FoodSavedAddressViewModel = {
      id: requestedAddressId.length > 0 ? requestedAddressId :
        'food-address-' + util.generateRandomUUID(false),
      longitude: this.foodLocationLongitude,
      latitude: this.foodLocationLatitude,
      radiusMeters: this.foodLocationRadiusMeters,
      name: this.foodLocationName.length > 0 ? this.foodLocationName : '常用地址',
      address: this.foodLocationAddress
    };
    const store = this.foodAddressBookStore();
    if (store === null) {
      this.logHtmlHomeActionError(action, 'food_address_book_store_unavailable');
      return;
    }
    try {
      this.foodSavedAddresses = await store.upsert(entry);
      aiLogInfo('[AIPhone][FoodAddressBookSaved] surfaceId=' + this.currentSurface.surfaceId +
        ' addressId=' + entry.id + ' count=' + this.foodSavedAddresses.length.toString());
    } catch (error) {
      aiLogError('[AIPhone][FoodAddressBookSaveError] reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
    }
  }

  private async deleteFoodAddress(action: A2uiAction): Promise<void> {
    const args = this.foodAddressActionArgs(action);
    if (args === null) {
      this.logHtmlHomeActionError(action, 'stale_food_address_book');
      return;
    }
    const addressId = this.actionText(args['addressId']).trim();
    if (addressId.length === 0) {
      this.logHtmlHomeActionError(action, 'missing_food_address_id');
      return;
    }
    const store = this.foodAddressBookStore();
    if (store === null) {
      this.logHtmlHomeActionError(action, 'food_address_book_store_unavailable');
      return;
    }
    try {
      if (!await store.delete(addressId)) {
        this.logHtmlHomeActionError(action, 'unknown_food_address_id');
        return;
      }
      this.foodSavedAddresses = store.list();
      aiLogInfo('[AIPhone][FoodAddressBookDeleted] surfaceId=' + this.currentSurface.surfaceId +
        ' addressId=' + addressId + ' count=' + this.foodSavedAddresses.length.toString());
    } catch (error) {
      aiLogError('[AIPhone][FoodAddressBookDeleteError] reason=' +
        (error instanceof Error ? error.message : JSON.stringify(error)));
    }
  }

  private async refreshFoodSearchAtLocation(action: A2uiAction): Promise<void> {
    if (action.args === undefined || this.currentSurface.intent !== 'food') {
      this.logHtmlHomeActionError(action, 'food_surface_required');
      return;
    }
    const actionArgs = action.args as Record<string, Object | string | number | boolean | null | undefined>;
    const ownerSurfaceId = this.actionText(actionArgs['surfaceId']).trim();
    const model = this.parsedDataModel();
    if (ownerSurfaceId.length === 0 || ownerSurfaceId !== this.currentSurface.surfaceId || model === null ||
      model.foodSearchContext === undefined) {
      this.logHtmlHomeActionError(action, 'stale_food_search_context');
      return;
    }
    const oldContext = model.foodSearchContext;
    const rawNextArea = actionArgs['searchArea'];
    const nextArea = rawNextArea === undefined || rawNextArea === null || Array.isArray(rawNextArea) ?
      null : rawNextArea as Record<string, Object | string | number | boolean | null | undefined>;
    aiLogInfo('[AIPhone][FoodLocationRefreshInput] surfaceId=' + ownerSurfaceId +
      ' oldLongitude=' + oldContext.searchArea.longitude.toString() +
      ' oldLatitude=' + oldContext.searchArea.latitude.toString() +
      ' oldRadiusMeters=' + oldContext.searchArea.radiusMeters.toString() +
      ' nextAreaPresent=' + (nextArea === null ? 'false' : 'true') +
      ' nextLongitude=' + (nextArea === null ? '' : this.actionText(nextArea['longitude']).trim()) +
      ' nextLatitude=' + (nextArea === null ? '' : this.actionText(nextArea['latitude']).trim()) +
      ' nextRadiusMeters=' + (nextArea === null ? '' : this.actionText(nextArea['radiusMeters']).trim()) +
      ' nextNameChars=' + (nextArea === null ? '0' : this.actionText(nextArea['name']).trim().length.toString()));
    const nextArgs: Record<string, Object | string | number | boolean | null | undefined> = {};
    nextArgs['query'] = oldContext.query;
    nextArgs['keyword'] = oldContext.keyword;
    nextArgs['searchArea'] = actionArgs['searchArea'];
    if (oldContext.brandPreference !== undefined) {
      nextArgs['brandPreference'] = oldContext.brandPreference;
    }
    if (oldContext.brandStrict !== undefined) {
      nextArgs['brandStrict'] = oldContext.brandStrict;
    }
    if (oldContext.sweetness !== undefined) {
      nextArgs['sweetness'] = oldContext.sweetness;
    }
    aiLogInfo('[AIPhone][FoodLocationRefresh] surfaceId=' + ownerSurfaceId +
      ' queryChars=' + oldContext.query.length.toString());
    if (nextArea !== null) {
      const nextLongitude = Number(this.actionText(nextArea['longitude']).trim());
      const nextLatitude = Number(this.actionText(nextArea['latitude']).trim());
      const nextRadiusMeters = Number(this.actionText(nextArea['radiusMeters']).trim());
      if (Number.isFinite(nextLongitude) && Number.isFinite(nextLatitude) &&
        nextLongitude >= -180 && nextLongitude <= 180 &&
        nextLatitude >= -90 && nextLatitude <= 90) {
        const optimisticSurface = this.surfaceSnapshot(this.currentSurface);
        const optimisticModel = JSON.parse(optimisticSurface.dataModelJson) as A2uiRuntimeDataModel;
        optimisticModel.foodSearchContext = {
          query: oldContext.query,
          keyword: oldContext.keyword,
          searchArea: {
            longitude: nextLongitude,
            latitude: nextLatitude,
            radiusMeters: Number.isFinite(nextRadiusMeters) && nextRadiusMeters > 0 ?
              nextRadiusMeters : oldContext.searchArea.radiusMeters,
            name: this.actionText(nextArea['name']).trim(),
            address: this.actionText(nextArea['address']).trim()
          }
        };
        if (oldContext.brandPreference !== undefined) {
          optimisticModel.foodSearchContext.brandPreference = oldContext.brandPreference;
        }
        if (oldContext.brandStrict !== undefined) {
          optimisticModel.foodSearchContext.brandStrict = oldContext.brandStrict;
        }
        if (oldContext.sweetness !== undefined) {
          optimisticModel.foodSearchContext.sweetness = oldContext.sweetness;
        }
        optimisticSurface.dataModelJson = JSON.stringify(optimisticModel);
        this.forceApplySurface(optimisticSurface, 'food_location_optimistic');
      }
    }
    await this.callToolById(
      'food.search',
      oldContext.query,
      'food_change_location',
      nextArgs as Object
    );
  }

  private async relocateFoodToCurrentDeviceLocation(action: A2uiAction): Promise<void> {
    const args = this.foodAddressActionArgs(action);
    const model = this.parsedDataModel();
    if (args === null || model === null || model.foodSearchContext === undefined) {
      this.logHtmlHomeActionError(action, 'stale_food_relocate_context');
      return;
    }
    try {
      aiLogInfo('[AIPhone][FoodCurrentLocation] phase=request surfaceId=' + this.currentSurface.surfaceId);
      const current = await this.currentFoodDeviceLocation();
      aiLogInfo('[AIPhone][FoodCurrentLocation] phase=resolved surfaceId=' + this.currentSurface.surfaceId +
        ' longitude=' + current.longitude.toString() +
        ' latitude=' + current.latitude.toString() +
        ' addressChars=' + current.address.length.toString());
      const searchArea: FoodRelocateSearchArea = {
        longitude: current.longitude,
        latitude: current.latitude,
        radiusMeters: model.foodSearchContext.searchArea.radiusMeters,
        name: current.name,
        address: current.address
      };
      const actionArgs: FoodRelocateActionArgs = {
        surfaceId: this.currentSurface.surfaceId,
        searchArea: searchArea
      };
      const refreshAction: A2uiAction = {
        id: 'food_change_location',
        label: '使用当前定位',
        prompt: '使用当前设备位置重新搜索',
        variant: 'secondary',
        kind: 'client',
        args: actionArgs
      };
      await this.refreshFoodSearchAtLocation(refreshAction);
    } catch (error) {
      const reason = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][FoodCurrentLocation] phase=failed reason=' + reason);
      if (reason !== LOCATION_SERVICE_DISABLED_NOTICE) {
        this.getUIContext().getPromptAction().showToast({ message: '重新定位失败，请检查定位权限后重试。' });
      }
    }
  }

  private navigationCardStore(): PreferencesNavigationCardSnapshotStore {
    const context = this.getUIContext().getHostContext() as common.Context;
    return new PreferencesNavigationCardSnapshotStore(context);
  }

  private async refreshNavigationCardForms(snapshot: NavigationCardSnapshot): Promise<void> {
    const store = this.navigationCardStore();
    const formIds = await store.getFormIds();
    if (formIds.length === 0) {
      aiLogInfo('[AIPhone][NavigationCardRefresh] noForms title=' + snapshot.title);
      return;
    }
    const binding = formBindingData.createFormBindingData(buildNavigationCardBindingData(snapshot, Date.now()));
    for (let index = 0; index < formIds.length; index++) {
      const formId = formIds[index];
      try {
        await formProvider.updateForm(formId, binding);
        aiLogInfo('[AIPhone][NavigationCardRefresh] formId=' + formId + ' ok=true');
      } catch (error) {
        const businessError = error as BusinessError;
        aiLogError('[AIPhone][NavigationCardRefresh] formId=' + formId +
          ' ok=false code=' + (businessError.code === undefined || businessError.code === null ? 'unknown' : businessError.code.toString()) +
          ' message=' + businessError.message);
      }
    }
  }

  private async saveNavigationCardResult(result: NavigationCardSnapshotBuildResult, label: string): Promise<void> {
    if (!result.ok || result.snapshot === undefined) {
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: result.error,
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: result.error
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false label=' + label + ' reason=' + result.error);
      return;
    }
    try {
      const store = this.navigationCardStore();
      await store.saveSnapshot(result.snapshot);
      await this.refreshNavigationCardForms(result.snapshot);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已固定为桌面导航卡片：' + (result.snapshot.cardStyle === 'travel' ? result.snapshot.routeText : result.snapshot.title),
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      aiLogInfo('[AIPhone][NavigationCardPin] ok=true title=' + result.snapshot.title +
        ' cardStyle=' + result.snapshot.cardStyle +
        ' transport=' + result.snapshot.transport +
        ' sourceTags=' + result.snapshot.sourceTags.join('/') +
        ' mapUriChars=' + result.snapshot.mapUri.length.toString());
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '导航卡片保存失败',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
      aiLogError('[AIPhone][NavigationCardPin] ok=false saveError=' + message);
    }
  }

  private async pinNavigationCard(item: A2uiFoodData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFoodOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'food.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'food');
  }

  private async pinTravelNavigationCard(item: A2uiTravelOptionData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTravelOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'travel.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), item.source === 'flight' ? 'travel-flight' : 'travel-train');
  }

  private async pinTrainNavigationCard(item: A2uiTrainData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromTrainOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'train.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'train');
  }

  private async pinFlightNavigationCard(item: A2uiFlightData): Promise<void> {
    const now = Date.now();
    await this.saveNavigationCardResult(navigationCardSnapshotFromFlightOption(item, {
      surfaceId: this.currentSurface.surfaceId,
      toolId: 'flight.search',
      updatedAt: now,
      expiresAt: now + NAVIGATION_CARD_TTL_MS
    }), 'flight');
  }

  private focusEditQuery(actionId: string = ''): void {
    if (actionId === 'travel_change_date') {
      this.inputPlaceholder = '请输入新的日期或路线，如：后天北京到上海出行方案';
      this.inputText = '';
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '请在输入框补充新的日期或路线。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      return;
    }
    this.inputPlaceholder = TRAIN_EDIT_QUERY_PLACEHOLDER;
    this.inputText = '';
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: true,
      status: 'ready',
      message: '请在输入框补充具体查询条件。',
      requestDebug: this.lastModelRequest,
      assistantDebug: this.lastModelOutput,
      error: ''
    }));
  }

  private async sendAction(action: A2uiAction): Promise<void> {
    this.mailDetailSuggestionGuard.invalidateForPageAction(action.id);
    if (action.id === 'multi_task.section.activate') {
      this.activateMultiTaskSection(action.prompt);
      return;
    }
    if (this.handleWaterfallClientAction(action)) {
      return;
    }
    if (this.isLuckinPaymentActionId(action.id)) {
      this.logLuckinPaymentAction(action, 'received');
    }
    if (this.isBusy) {
      if (this.isLuckinPaymentActionId(action.id)) {
        this.logLuckinPaymentAction(action, 'ignored_busy');
      }
      aiLogInfo('[AIPhone][A2uiHomeActionIgnored] id=' + action.id + ' reason=busy');
      return;
    }
    if (this.isSocialHubActionId(action) && !this.isCurrentSocialHubSurface()) {
      this.logHtmlHomeActionError(action, 'social_hub_surface_required');
      return;
    }
    if (this.isSocialHubClientAction(action)) {
      await this.handleClientAction(action);
      return;
    }
    if (this.isPersonaEditorAction(action)) {
      await this.handleClientAction(action);
      return;
    }
    const renderedSnapshot = this.registeredPageSnapshotStore.current();
    const document = renderedSnapshot === null ?
      this.currentHtmlHomeDocument() : renderedSnapshot.document;
    if (!isHtmlHomeActionAllowed(document, action)) {
      if (this.isLuckinPaymentActionId(action.id)) {
        this.logLuckinPaymentAction(action, 'blocked_not_allowed');
      }
      this.logHtmlHomeActionError(action, 'not_allowed');
      return;
    }
    if (action.id === MEMORY_CANDIDATES_FORGET_ACTION_ID && action.kind === 'client') {
      await this.handleMemoryCandidateClientAction(action);
      return;
    }
    if (this.isLuckinPaymentActionId(action.id)) {
      this.logLuckinPaymentAction(action, 'dispatch');
    }
    if (this.shouldBypassRegisteredPageForLuckinAction(action)) {
      await this.callLuckinToolDirect(action);
      return;
    }
    await dispatchRegisteredPageActionCandidate(
      action,
      (clicked: A2uiAction): Promise<boolean> => this.runRegisteredPageAction(clicked),
      (legacy: A2uiAction): Promise<void> => this.sendLegacyAction(legacy, document)
    );
  }

  private currentToolRuntimeOwner(): RuntimeOwner {
    return this.activeRuntimeOwner === 'multi_agent' ? 'multi_agent' : 'legacy';
  }

  private async callLuckinToolDirect(action: A2uiAction): Promise<boolean> {
    const args: Object | null = action.args === undefined ? null : action.args;
    const rawPrompt: string = action.prompt.length > 0 ? action.prompt : action.label;
    const prompt: string = resolveLuckinActionPrompt(rawPrompt, args);
    return await this.callToolById(
      action.id,
      prompt,
      action.id,
      args,
      undefined,
      this.currentToolRuntimeOwner()
    );
  }

  private async runRegisteredPageAction(action: A2uiAction): Promise<boolean> {
    const snapshot = this.registeredPageSnapshotStore.current();
    const actionGeneration = this.runtimeGeneration;
    if (snapshot === null || !runtimeSurfaceIdentityMatches(
      this.currentSurface,
      snapshot.surface,
      this.activeRuntimeOwner,
      actionGeneration
    )) {
      return false;
    }
    const runtime = this.canaryRuntime();
    const usesPageBusy = registeredPageActionUsesPageBusy(action.id) &&
      !this.isLuckinOptionSwitchArgs(action.args === undefined ? null : action.args);
    if (usesPageBusy) {
      this.isBusy = true;
    }
    try {
      const ok = await runtime.runPageAction(action);
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
      )) {
        return false;
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok,
        status: ok ? 'ready' : 'error',
        message: ok ? '操作已处理。' : '操作已被当前页面权限拒绝。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ok ? '' : 'registered action 与当前已渲染页面快照不匹配'
      }));
      return ok;
    } finally {
      if (usesPageBusy && runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
      )) {
        this.finishForegroundTurn();
      }
    }
  }

  private async sendLegacyAction(
    action: A2uiAction,
    document: HtmlHomeDocument
  ): Promise<void> {
    if (this.multiAgentRuntime !== null && this.activeRuntimeOwner === 'multi_agent' &&
      action.id === 'hotel.detail') {
      const runtime = this.multiAgentRuntime;
      const actionGeneration = this.runtimeGeneration;
      const snapshot = this.registeredPageSnapshotStore.current();
      const context = runtime.currentActionContext();
      if (snapshot === null || context === null ||
        !runtimeSurfaceIdentityMatches(
          this.currentSurface,
          snapshot.surface,
          this.activeRuntimeOwner,
          actionGeneration
        ) ||
        context.surfaceId !== snapshot.surface.surfaceId ||
        context.sourceToolId !== 'hotel.search' ||
        document.surfaceId !== snapshot.document.surfaceId ||
        document.generatedAt !== snapshot.document.generatedAt ||
        !isHtmlHomeActionAllowed(document, action)) {
        this.logHtmlHomeActionError(action, 'hotel_context_not_current');
        return;
      }
      this.isBusy = true;
      try {
        const ok = await runtime.runAction(action, context);
        if (!runtimeCallbackIsCurrent(
          this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
        )) {
          return;
        }
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: ok,
          status: ok ? 'ready' : 'error',
          message: ok ? '酒店操作已处理。' : '酒店操作已被当前页面权限拒绝。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: ok ? '' : '酒店 action 与当前 surface/document 不匹配'
        }));
      } finally {
        if (runtimeCallbackIsCurrent(
          this.activeRuntimeOwner, this.runtimeGeneration, 'multi_agent', actionGeneration
        )) {
          this.finishForegroundTurn();
        }
      }
      return;
    }
    const kind = action.kind.length > 0 ? action.kind : 'prompt';
    if (this.activeRuntimeOwner === 'multi_agent' ||
      runtimeOwnerAllowsSurfaceAction(this.currentSurface, 'multi_agent')) {
      if (kind === 'client') {
        await this.handleClientAction(action);
      } else if (kind === 'input') {
        this.focusEditQuery(action.id);
      } else if (action.id === 'luckin.order.create' || action.id === 'luckin.order.status') {
        await this.callLuckinToolDirect(action);
      } else {
        this.logHtmlHomeActionError(action, 'runtime_owner_mismatch');
      }
      return;
    }
    const directFirecrawlToolId = directFirecrawlToolIdForActionId(action.id);
    if (directFirecrawlToolId.length > 0) {
      this.isBusy = true;
      try {
        await this.callToolById(
          directFirecrawlToolId,
          action.prompt.length > 0 ? action.prompt : action.label,
          action.id,
          action.args === undefined ? null : action.args
        );
      } finally {
        this.finishForegroundTurn();
      }
      return;
    }
    const directPaymentToolId = directPaymentToolIdForActionId(action.id);
    if (directPaymentToolId.length > 0) {
      await this.callToolById(
        directPaymentToolId,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    const directRideToolId = directRideToolIdForActionId(action.id);
    if (directRideToolId.length > 0) {
      await this.callToolById(
        directRideToolId,
        action.prompt.length > 0 ? action.prompt : action.label,
        action.id,
        action.args === undefined ? null : action.args
      );
      return;
    }
    if (action.id === 'luckin.order.preview' || action.id === 'luckin.order.create' || action.id === 'luckin.order.status') {
      await this.callLuckinToolDirect(action);
      return;
    }
    if (kind === 'client') {
      await this.handleClientAction(action);
      return;
    }
    if (kind === 'input') {
      this.focusEditQuery(action.id);
      return;
    }
    await this.submitPrompt(action.prompt, action.label, action.id, action.args === undefined ? null : action.args);
  }

  private toolSurfaceId(): string {
    if (this.currentSurface.surfaceId.length === 0 || this.currentSurface.status === 'error') {
      return 'surface_model';
    }
    return this.currentSurface.surfaceId;
  }

  private multiTaskToolCallContext(toolId: string): MultiTaskToolCallContext | null {
    if (!isMultiTaskSurface(this.currentSurface)) {
      return null;
    }
    const slotId = resolveMultiTaskSlotId(this.currentSurface, toolId);
    if (slotId.length === 0) {
      return null;
    }
    const context: MultiTaskToolCallContext = {
      slotId: slotId,
      childSurfaceId: childSurfaceIdForMultiTaskSlot(this.currentSurface.surfaceId, slotId)
    };
    return context;
  }

  private prepareVirtualMultiTaskAction(
    actionId: string,
    context: RegisteredPageActionContext
  ): void {
    if (context.virtualAction !== true) {
      return;
    }
    if (isMultiTaskSurface(this.currentSurface)) {
      if (resolveMultiTaskSlotId(this.currentSurface, actionId).length === 0) {
        this.applySurface(copyPersonaData(
          this.currentSurface,
          appendMultiTaskSlot(this.currentSurface, actionId)
        ));
      }
      return;
    }
    const results = genericToolResults(this.currentSurface);
    if (results.length === 0 || results[0].toolName.trim().length === 0) {
      return;
    }
    this.applySurface(copyPersonaData(
      this.currentSurface,
      wrapSurfaceWithMultiTaskAction(
        this.currentSurface,
        results[0].toolName.trim(),
        actionId
      )
    ));
  }

  private applyMultiTaskSlotObservation(
    composite: A2uiSurfaceState,
    slotId: string,
    toolId: string,
    observationRaw: string
  ): A2uiSurfaceState {
    if (this.multiTaskLastMergedRawBySlot[slotId] === observationRaw) {
      return composite;
    }
    this.multiTaskLastMergedRawBySlot[slotId] = observationRaw;
    const activateSlot = !this.multiTaskUserPinnedSection;
    if (activateSlot) {
      this.multiTaskActiveSectionId = slotId;
    }
    const useIncrementalMultiTask = composite.intent === 'multi-task' &&
      this.multiTaskShellHtml.length > 0;
    if (!useIncrementalMultiTask) {
      this.htmlHomeCacheKey = '';
      this.htmlHomeCacheHtml = '';
    }
    const merged = mergeSlotObservationIntoMultiTaskSurface(composite, slotId, toolId, observationRaw, activateSlot);
    return copyPersonaData(composite, merged);
  }

  private readMultiTaskActiveSectionId(surface: A2uiSurfaceState): string {
    try {
      const parsed = JSON.parse(surface.dataModelJson) as Record<string, Object | null | undefined>;
      const boardValue = parsed.multiTask;
      if (boardValue !== undefined && boardValue !== null && typeof boardValue === 'object' && !Array.isArray(boardValue)) {
        const board = boardValue as Record<string, Object | string | number | boolean | null | undefined>;
        const activeSectionId = board.activeSectionId;
        if (typeof activeSectionId === 'string' && activeSectionId.length > 0) {
          return activeSectionId;
        }
      }
    } catch (_error) {
    }
    return '';
  }

  private activateMultiTaskSection(sectionId: string): void {
    if (!isMultiTaskSurface(this.currentSurface) || sectionId.length === 0) {
      return;
    }
    if (this.multiTaskUserPinnedSection && this.multiTaskActiveSectionId === sectionId) {
      return;
    }
    this.multiTaskUserPinnedSection = true;
    this.multiTaskActiveSectionId = sectionId;
  }

  private async callModelRequestedTool(
    surface: A2uiSurfaceState,
    fallbackPrompt: string,
    fallbackActionId: string,
    fallbackArgs: Object | null = null
  ): Promise<void> {
    const request: A2uiHomeResolvedToolRequest = resolveA2uiHomeToolRequest(surface, fallbackPrompt, fallbackActionId, fallbackArgs);
    if (!request.hasTool) {
      aiLogInfo('[AIPhone][A2uiHomeToolRequest] none');
      return;
    }
    aiLogInfo('[AIPhone][A2uiHomeToolRequestFromModel] toolId=' + request.toolId +
      ' modelPromptChars=' + request.modelPromptChars.toString() +
      ' userPromptChars=' + fallbackPrompt.length.toString() +
      ' sentPromptChars=' + request.prompt.length.toString());
    await this.callToolById(request.toolId, request.prompt, request.actionId, request.args);
  }
  private configureDidiMcpSandboxRuntime(isSandbox: boolean): void {
    this.didiMcpSandboxEnabled = isSandbox;
    configureDidiMcpSandboxForRuntime(isSandbox);
    aiLogInfo('[AIPhone][A2uiHomeDidiMcpSandboxToggle] enabled=' + (isSandbox ? 'true' : 'false'));
  }

  private async invokeRegisteredPageTool(
    toolId: string,
    prompt: string,
    pageActionId: string,
    args: Object,
  ): Promise<RegisteredPageToolInvocation> {
    const observation: RegisteredPageToolObservation = { result: null };
    const ok = await this.callToolById(
      toolId,
      prompt,
      pageActionId,
      args,
      (result: A2uiCallResult): void => {
        observation.result = result;
      },
      'multi_agent'
    );
    const observed = observation.result;
    return {
      ok,
      result: observed,
      error: observed === null ?
        (ok ? '' : 'Registered page tool did not complete.') : observed.error
    };
  }

  private async callToolById(
    toolId: string,
    prompt: string,
    actionId: string,
    args: Object | null = null,
    resultObserver?: (result: A2uiCallResult) => void,
    runtimeOwner: RuntimeOwner = 'legacy'
  ): Promise<boolean> {
    const toolGeneration: number = runtimeOwner === 'legacy' ?
      (this.activeRuntimeOwner === 'legacy' && this.isBusy ?
        this.runtimeGeneration : this.beginRuntimeTurn('legacy')) : this.runtimeGeneration;
    if (runtimeOwner !== this.activeRuntimeOwner) {
      return false;
    }
    if (toolId === 'luckin.order.preview' || toolId === 'luckin.order.create' || toolId === 'luckin.order.status') {
      aiLogInfo('[AIPhone][LuckinOrderTrace] stage=dispatch result=received toolId=' + toolId +
        ' actionId=' + actionId +
        ' runtimeOwner=' + runtimeOwner +
        ' promptChars=' + prompt.length.toString());
    }
    const directDetailBimAction = false;
    if (!isRegisteredAiphoneToolId(toolId)) {
      const message = '模型请求了未注册工具：' + toolId;
      aiLogError('[AIPhone][A2uiHomeToolRequestInvalid] toolId=' + toolId);
      if (directDetailBimAction) {
        this.bimUiError = message;
      } else {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: false,
          status: 'error',
          message: message,
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: message
        }));
      }
      return false;
    }

    aiLogInfo('[AIPhone][A2uiHomeToolRequest] toolId=' + toolId +
      ' promptChars=' + prompt.length.toString() +
      ' actionId=' + actionId +
      ' gateway=' + TOOL_GATEWAY_URL);
    if (toolId === 'daily.brief.open') {
      let regenerate = prompt.indexOf('重新生成') >= 0 ||
        prompt.indexOf('重做日报') >= 0 || prompt.indexOf('刷新日报') >= 0;
      if (args !== null) {
        const validation = validateRegisteredPageActionArgs(toolId, args);
        if (!validation.ok) {
          aiLogError('[AIPhone][DailyBriefOpenRejected] code=' + validation.code);
          return false;
        }
        const values = args as Record<string, Object | string | number | boolean | null | undefined>;
        regenerate = regenerate || values['regenerate'] === true;
      }
      return this.openDailyBrief(regenerate);
    }
    if (toolId === 'worldcup.open') {
      aiLogInfo('[AIPhone][AnythingDemoRouteByTool] actionId=' + actionId +
        ' promptChars=' + prompt.length.toString());
      if (!directDetailBimAction) {
        this.markChecking('正在打开世界杯界面...');
      }
      const opened = await this.openAnythingDemo();
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
      )) {
        return false;
      }
      if (!opened) {
        if (directDetailBimAction) {
          this.bimUiError = '无法打开世界杯界面。';
        } else {
          this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
            ok: false,
            status: 'error',
            message: '无法打开世界杯界面。',
            requestDebug: this.lastModelRequest,
            assistantDebug: this.lastModelOutput,
            error: 'Anything demo route could not be opened.'
          }));
        }
        return false;
      }
      if (directDetailBimAction) {
        this.bimUiError = '';
        return true;
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开世界杯界面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.appendMessage('assistant', '已打开世界杯界面。');
      return true;
    }
    if (toolId === 'movie.open') {
      aiLogInfo('[AIPhone][MovieDemoRouteByTool] actionId=' + actionId +
        ' promptChars=' + prompt.length.toString());
      this.markChecking('正在打开电影界面...');
      const opened = await this.openMovieDemo();
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
      )) {
        return false;
      }
      if (!opened) {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: false,
          status: 'error',
          message: '无法打开电影界面。',
          requestDebug: this.lastModelRequest,
          assistantDebug: this.lastModelOutput,
          error: 'Movie demo route could not be opened.'
        }));
        return false;
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: true,
        status: 'ready',
        message: '已打开电影界面。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: ''
      }));
      this.appendMessage('assistant', '已打开电影界面。');
      return true;
    }
    configureDidiMcpSandboxForRuntime(this.didiMcpSandboxEnabled);
    configureLocalToolDebugConfig({
      foodProviderDelayEnabled: this.foodProviderDelayEnabled,
      foodProviderDelayMs: normalizeFoodProviderDelayMs(this.foodProviderDelayMs),
      foodPartialThrottleMs: normalizeFoodPartialThrottleMs(this.foodPartialThrottleMs)
    });
    const personaSourceSurface = directDetailBimAction ? this.canaryHostSurface() : this.currentSurface;
    const multiTaskCtx = directDetailBimAction ? null : this.multiTaskToolCallContext(toolId);
    const inlineLuckinSwitch = !directDetailBimAction &&
      toolId === 'luckin.order.preview' && this.isLuckinOptionSwitchArgs(args) && multiTaskCtx === null;
    const inlinePaymentStatusPlan = directDetailBimAction ?
      null : this.inlineLuckinPaymentStatusPlan(toolId, personaSourceSurface, multiTaskCtx);
    const inlineLuckinPaymentStatus = inlinePaymentStatusPlan !== null;
    if (inlineLuckinSwitch) {
      if (this.luckinOptionSwitchInFlight) {
        this.luckinOptionSwitchPending = {
          prompt: prompt,
          args: args,
          actionId: actionId,
          runtimeOwner: runtimeOwner
        };
        this.luckinOptionSwitchSeq = this.luckinOptionSwitchSeq + 1;
        aiLogInfo('[AIPhone][A2uiHomeLuckinSwitchQueued] reason=in_flight seq=' +
          this.luckinOptionSwitchSeq.toString());
        return false;
      }
      this.luckinOptionSwitchSeq = this.luckinOptionSwitchSeq + 1;
      this.finishLuckinOptionSwitch(true);
    }
    const luckinSwitchSeq = this.luckinOptionSwitchSeq;
    if (!directDetailBimAction && !inlineLuckinSwitch && !inlineLuckinPaymentStatus) {
      this.markChecking('正在调用工具：' + toolId);
    }
    const callArgs = await this.argsWithCurrentLocationForTool(toolId, args);
    if (!runtimeCallbackIsCurrent(
      this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
    )) {
      if (inlineLuckinSwitch) {
        this.finishLuckinOptionSwitch(false);
      }
      return false;
    }
    const firecrawlPending = !directDetailBimAction && isFirecrawlToolId(toolId);
    if (firecrawlPending) {
      this.surfaceRenderTick = nextPendingToolRenderTick(
        this.surfaceRenderTick,
        this.pendingFirecrawlToolId,
        toolId
      );
      this.pendingFirecrawlToolId = toolId;
    }
    const targetSurfaceId = directDetailBimAction ?
      personaSourceSurface.surfaceId :
      (multiTaskCtx !== null ? multiTaskCtx.childSurfaceId : this.toolSurfaceId());
    const suppressFoodLocationPartials = toolId === 'food.search' && actionId === 'food_change_location';
    const result: A2uiCallResult = await callToolGateway(
      TOOL_GATEWAY_URL,
      toolId,
      prompt,
      targetSurfaceId,
      actionId,
      (surface: A2uiSurfaceState, raw: string) => {
        if (suppressFoodLocationPartials) {
          aiLogInfo('[AIPhone][FoodLocationPartialSuppressed] surfaceId=' + surface.surfaceId +
            ' sequence=' + surface.sequence.toString());
          return;
        }
        if (inlineLuckinSwitch || inlineLuckinPaymentStatus) {
          return;
        }
        if (multiTaskCtx !== null) {
          const nextSurface = this.applyMultiTaskSlotObservation(
            this.currentSurface.intent === 'multi-task' &&
              this.currentSurface.surfaceId === personaSourceSurface.surfaceId ?
              this.currentSurface : personaSourceSurface,
            multiTaskCtx.slotId,
            toolId,
            raw
          );
          this.applySurface(nextSurface);
          this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
            ok: true,
            status: 'checking',
            message: '并行任务更新：' + nextSurface.title,
            requestDebug: this.lastModelRequest,
            assistantDebug: raw,
            error: ''
          }));
          return;
        }
        const nextSurface = copyPersonaData(personaSourceSurface, surface);
        if (!this.applyRuntimeSurface(nextSurface, runtimeOwner, toolGeneration)) {
          return;
        }
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'checking',
          message: '工具流式更新：' + nextSurface.title,
          requestDebug: this.lastModelRequest,
          assistantDebug: raw,
          error: ''
        }));
      },
      null,
      callArgs
    );
    if (firecrawlPending) {
      this.surfaceRenderTick = nextPendingToolRenderTick(
        this.surfaceRenderTick,
        this.pendingFirecrawlToolId,
        ''
      );
      this.pendingFirecrawlToolId = '';
    }
    if (runtimeOwner !== this.activeRuntimeOwner || toolGeneration !== this.runtimeGeneration) {
      if (inlineLuckinSwitch) {
        this.finishLuckinOptionSwitch(false);
      }
      return false;
    }

    aiLogInfo('[AIPhone][A2uiHomeToolResult] ok=' + (result.ok ? 'true' : 'false') +
      ' errorChars=' + result.error.length.toString() +
      ' rawChars=' + result.raw.length.toString());
    aiLogInfo('[AIPhone][A2uiHomeToolOutput] ' + logSnippet(result.raw));
    if (resultObserver !== undefined) {
      resultObserver(result);
    }
    if (multiTaskCtx !== null) {
      const mergeBase = this.currentSurface.intent === 'multi-task' &&
        this.currentSurface.surfaceId === personaSourceSurface.surfaceId ?
        this.currentSurface : personaSourceSurface;
      if (inlinePaymentStatusPlan !== null && inlinePaymentStatusPlan.mode === 'multi-task') {
        const statusSurface = this.ownedSurface(
          copyPersonaData(personaSourceSurface, result.surface), runtimeOwner, toolGeneration
        );
        if (result.ok &&
          this.applyLuckinInlineMultiTaskPaymentStatusPatch(mergeBase, inlinePaymentStatusPlan.slotId, statusSurface)) {
          this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
            ok: true,
            status: 'ready',
            message: '订单状态已更新。',
            requestDebug: result.requestDebug,
            assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
            error: ''
          }));
          return true;
        }
        aiLogInfo('[AIPhone][A2uiHomeLuckinPaymentStatusFallback] mode=multi-task ok=' +
          (result.ok ? 'true' : 'false'));
      }
      const nextSurface = result.ok ?
        this.applyMultiTaskSlotObservation(mergeBase, multiTaskCtx.slotId, toolId, result.raw) :
        this.ownedSurface(copyPersonaData(personaSourceSurface, result.surface), runtimeOwner, toolGeneration);
      this.applySurface(nextSurface);
      if (toolId === 'payment.account.setup') {
        await this.saveStripeReceivingProfile(result.surface);
      }
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: result.ok,
        status: result.ok ? 'ready' : 'error',
        message: result.ok ? '并行任务已更新，可在页内切换查看各结果。' : '工具返回异常，请到配置页查看详情。',
        requestDebug: result.requestDebug,
        assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
        error: result.error
      }));
      if (!result.ok) {
        this.appendMessage('assistant', '工具返回异常：' + result.error);
        return false;
      }
      return true;
    }
    const resultSurface = this.ownedSurface(
      copyPersonaData(personaSourceSurface, result.surface), runtimeOwner, toolGeneration
    );
    if (suppressFoodLocationPartials && resultSurface.surfaceId === this.currentSurface.surfaceId &&
      resultSurface.sequence <= this.currentSurface.sequence) {
      const returnedSequence = resultSurface.sequence;
      resultSurface.sequence = this.currentSurface.sequence + 1;
      aiLogInfo('[AIPhone][FoodLocationFinalSequenceRebased] surfaceId=' + resultSurface.surfaceId +
        ' returnedSequence=' + returnedSequence.toString() +
        ' currentSequence=' + this.currentSurface.sequence.toString() +
        ' rebasedSequence=' + resultSurface.sequence.toString());
    }
    if (inlineLuckinSwitch) {
      if (luckinSwitchSeq !== this.luckinOptionSwitchSeq) {
        aiLogInfo('[AIPhone][A2uiHomeLuckinSwitchStale] seq=' + luckinSwitchSeq.toString() +
          ' current=' + this.luckinOptionSwitchSeq.toString());
        this.finishLuckinOptionSwitch(false);
        return false;
      }
      if (result.ok && this.applyLuckinInlineConfirmPatch(resultSurface)) {
        this.finishLuckinOptionSwitch(false);
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'ready',
          message: '规格已更新。',
          requestDebug: result.requestDebug,
          assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
          error: ''
        }));
        return true;
      }
      this.finishLuckinOptionSwitch(false);
      aiLogInfo('[AIPhone][A2uiHomeLuckinSwitchFallback] ok=' + (result.ok ? 'true' : 'false'));
    }
    if (inlineLuckinPaymentStatus) {
      if (result.ok && this.applyLuckinInlinePaymentStatusPatch(personaSourceSurface, resultSurface)) {
        this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
          ok: true,
          status: 'ready',
          message: '订单状态已更新。',
          requestDebug: result.requestDebug,
          assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
          error: ''
        }));
        return true;
      }
      aiLogInfo('[AIPhone][A2uiHomeLuckinPaymentStatusFallback] ok=' + (result.ok ? 'true' : 'false'));
    }
    if (!this.applyRuntimeSurface(resultSurface, runtimeOwner, toolGeneration)) {
      return false;
    }
    if (toolId === 'payment.account.setup') {
      await this.saveStripeReceivingProfile(resultSurface);
      if (!runtimeCallbackIsCurrent(
        this.activeRuntimeOwner, this.runtimeGeneration, runtimeOwner, toolGeneration
      )) {
        return false;
      }
    }
    this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
      ok: result.ok,
      status: result.ok ? 'ready' : 'error',
      message: result.ok ? resultSurface.title + ' 已返回工具结果。' : '工具返回异常，请到配置页查看详情。',
      requestDebug: result.requestDebug,
      assistantDebug: result.raw.length > 0 ? result.raw : this.lastModelOutput,
      error: result.error
    }));
    if (!result.ok) {
      this.appendMessage('assistant', '工具返回异常：' + result.error);
      return false;
    }
    if (!inlineLuckinSwitch && !inlineLuckinPaymentStatus) {
      this.appendMessage('assistant', resultSurface.title + ' 已返回 A2UI 结果。');
    }
    if (toolId === 'gmail.open.web') {
      return this.openExternalUrl(GMAIL_WEB_URL);
    }
    return true;
  }

  private async testConnection(): Promise<void> {
    if (this.isBusy) {
      return;
    }
    const trimmedBaseUrl = this.baseUrl.trim();
    if (trimmedBaseUrl.length === 0) {
      aiLogError('[AIPhone][A2uiHomeConnectionBlocked] missingBaseUrl');
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '请先填写 Base URL。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: 'Base URL 为空'
      }));
      return;
    }

    this.isBusy = true;
    aiLogInfo('[AIPhone][A2uiHomeConnectionTest] model=' + this.selectedModel + ' baseUrl=' + this.baseUrl);
    this.markChecking('正在向模型发起连接检查...');
    try {
      const result: DirectModelCallResult = await awaitConnectionTest(callDirectModel(
        this.getSettings(),
        CONNECTION_TEST_PROMPT,
        this.recentMessages()
      ));
      aiLogInfo('[AIPhone][A2uiHomeConnectionResult] ok=' + (result.ok ? 'true' : 'false') +
        ' errorChars=' + result.error.length.toString() +
        ' rawChars=' + result.raw.length.toString() +
        ' assistantChars=' + result.assistantDebug.length.toString());
      aiLogInfo('[AIPhone][A2uiHomeConnectionOutput] ' + logSnippet(result.assistantDebug.length > 0 ? result.assistantDebug : result.raw));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: result.ok,
        status: result.ok ? 'ready' : 'error',
        message: result.ok ? '模型连接正常，测试返回已更新到当前页面。' : '模型连接异常，请查看最近异常。',
        requestDebug: result.requestDebug,
        assistantDebug: result.assistantDebug.length > 0 ? result.assistantDebug : result.raw,
        error: result.error
      }));
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][A2uiHomeConnectionException] ' + logSnippet(message));
      this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
        ok: false,
        status: 'error',
        message: '模型连接异常，请查看最近异常。',
        requestDebug: this.lastModelRequest,
        assistantDebug: this.lastModelOutput,
        error: message
      }));
    } finally {
      this.finishForegroundTurn();
    }
  }

  onBackPress(): boolean {
    if (this.showConfigPage) {
      this.showConfigPage = false;
      return true;
    }
    if (this.showPublicPersonaPage) {
      this.showPublicPersonaPage = false;
      return true;
    }
    if (this.showBimPage) {
      if (this.selectedBimId.length > 0) {
        this.closeBimDetail();
      } else {
        this.showBimPage = false;
      }
      return true;
    }
    if (!this.showComposioAuthPage) {
      if (this.bimRootIndex === 1) {
        this.interestWaterfallBackRequestTick = this.interestWaterfallBackRequestTick + 1;
        return true;
      }
      if (this.waterfallFullscreen) {
        this.waterfallBackRequestTick = this.waterfallBackRequestTick + 1;
        return true;
      }
    }
    return false;
  }

  @Builder
  private ConfigPageContent() {
    ConfigPage({
      baseUrl: $baseUrl,
      apiKey: $apiKey,
      selectedModel: $selectedModel,
      customParametersJson: $customParametersJson,
      aggregateDomesticOnly: $aggregateDomesticOnly,
      aggregateMultilingual: $aggregateMultilingual,
      foodProviderDelayEnabled: $foodProviderDelayEnabled,
      foodProviderDelayMs: $foodProviderDelayMs,
      foodPartialThrottleMs: $foodPartialThrottleMs,
      ignoreToolSurfaceUpdates: $ignoreToolSurfaceUpdates,
      htmlHomeDebugExportEnabled: $htmlHomeDebugExportEnabled,
      htmlHomeDebugExportPath: this.htmlHomeDebugExportPath,
      didiMcpSandboxEnabled: $didiMcpSandboxEnabled,
      showAdvancedSettings: $showAdvancedSettings,
      connectionStatus: this.connectionStatus,
      connectionMessage: this.connectionMessage,
      isBusy: this.isBusy,
      lastModelRequest: this.lastModelRequest,
      lastModelOutput: this.lastModelOutput,
      lastError: this.lastError,
      refreshTick: this.refreshTick,
      personaPacks: this.personaPacks,
      selectedPersonaId: $selectedPersonaId,
      personaSoulDraft: $personaSoulDraft,
      personaMemoryDraft: $personaMemoryDraft,
      personaSaveMessage: this.personaSaveMessage,
      composioUserId: this.composioUserId,
      composioAuthItems: this.composioAuthItems,
      composioAuthMessage: this.composioAuthMessage,
      composioAuthBusy: this.composioAuthBusy,
      onBack: () => {
        this.showConfigPage = false;
      },
      onSelectModelPreset: (preset: string) => {
        this.saveModelPreset(preset);
      },
      onOpenUiAgentLab: () => {
        this.openUiAgentLab();
      },
      onTestConnection: () => {
        this.testConnection();
      },
      onSelectPersona: (personaId: string) => {
        this.selectPersonaForEdit(personaId);
      },
      onSavePersona: () => {
        this.savePersonaDraft();
      },
      onResetPersona: () => {
        this.resetPersonaDraft();
      },
      onExportHtmlHomeDocument: () => {
        this.exportCurrentHtmlHomeDocument();
      },
      onToggleDidiMcpSandbox: (isOn: boolean) => {
        this.configureDidiMcpSandboxRuntime(isOn);
      },
      onToggleAggregateDomesticOnly: (isOn: boolean) => {
        this.aggregateDomesticOnly = isOn;
        this.saveAggregateSearchPolicy();
      },
      onToggleAggregateMultilingual: (isOn: boolean) => {
        this.aggregateMultilingual = isOn;
        this.saveAggregateSearchPolicy();
      }
    })
  }

  @Builder
  private BimSpace() {
    if (this.selectedBimId.length > 0 && this.selectedBimRecordSnapshot !== null &&
      this.selectedBimRecordSnapshot.id === this.selectedBimId) {
      BimDetailPage({
        record: this.selectedBimRecordSnapshot,
        renderTick: this.bimDetailRenderTick,
        liveSurfaceJson: '',
        isBusy: false,
        isInputEnabled: !this.isBusy,
        isLoading: this.bimLoading,
        workingText: '',
        errorMessage: combineBimErrorMessages(this.bimStoreError, this.bimUiError),
        reduceMotion: this.bimReduceMotion,
        inputText: $bimInputText,
        onBack: (): void => {
          this.closeBimDetail();
        },
        onSubmit: (bimId: string, text: string): void => {
          void this.submitBimPrompt(bimId, text);
        },
        onStop: (_bimId: string): void => {},
        onAction: (action: A2uiAction): void => {
          void this.submitBimPrompt(
            (this.selectedBimRecord() as BimRecord).id,
            modelPromptWithActionContext(
              action.prompt,
              action.id,
              action.args === undefined ? null : action.args
            )
          );
        },
        onMarkEnded: (bimId: string): void => {
          this.markBimEnded(bimId);
        },
        onReactivate: (bimId: string): void => {
          this.reactivateBim(bimId);
        },
        onDelete: (bimId: string): void => {
          void this.deleteEndedBim(bimId);
        }
      })
    } else {
      BimHomePage({
        records: this.bimRecords,
        isLoading: this.bimLoading,
        errorMessage: combineBimErrorMessages(this.bimStoreError, this.bimUiError),
        reduceMotion: this.bimReduceMotion,
        isDebugBuild: this.isDebugBuild,
        sentinelBusy: this.bimSentinelBusy,
        onOpenRecord: (bimId: string): void => {
          this.openBimDetail(bimId);
        },
        onTestSentinel: (): void => {
          void this.scheduleBimSentinelMock();
        }
      })
    }
  }

  @Builder
  private BimPageContent() {
    Column() {
      Row() {
        Button('‹')
          .width(42)
          .height(42)
          .fontSize(28)
          .fontColor('#2B3033')
          .backgroundColor('#CCFFFFFF')
          .borderRadius(21)
          .onClick((): void => {
            if (this.selectedBimId.length > 0) {
              this.closeBimDetail();
            } else {
              this.showBimPage = false;
            }
          })
        Text('心上事')
          .layoutWeight(1)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111415')
          .textAlign(TextAlign.Center)
          .margin({ right: 42 })
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16 })

      Column() {
        this.BimSpace()
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F9FAFB')
  }

  @Builder
  private PublicPersonaPageContent() {
    PublicPersonaPage({
      phase: this.publicPersonaPhase,
      candidates: this.publicPersonaCandidates,
      progress: this.publicPersonaProgress,
      snapshot: this.publicPersonaSnapshot,
      errorMessage: this.publicPersonaError,
      onBack: (): void => {
        this.showPublicPersonaPage = false;
      },
      onChooseSetup: (): void => {
        this.publicPersonaPhase = 'input';
      },
      onSkip: (): void => {
        this.skipPublicPersonaOnboarding();
      },
      onStartDiscovery: (username: string, mode: PublicPersonaSearchMode): void => {
        this.startPublicPersonaDiscovery(username, mode);
      },
      onConfirm: (candidateIds: string[]): void => {
        this.confirmPublicPersona(candidateIds);
      },
      onSaveMarkdown: (markdown: string): boolean => {
        return this.savePublicPersonaMarkdown(markdown);
      },
      onReinferMbti: (): void => {
        this.reinferPublicPersonaMbti();
      },
      onSetMbtiHidden: (hidden: boolean): void => {
        this.setPublicPersonaMbtiHidden(hidden);
      },
      onDelete: (): boolean => {
        return this.deletePublicPersona();
      }
    })
  }

  build() {
    if (this.showComposioAuthPage) {
      ComposioAuthPage({
        userShortId: this.composioUserId,
        items: this.composioAuthItems,
        message: this.composioAuthMessage,
        isBusy: this.composioAuthBusy,
        onBack: () => {
          this.showComposioAuthPage = false;
        },
        onRefresh: () => {
          this.refreshComposioAuth();
        },
        onAuthorize: (item: ComposioAuthConfigItem) => {
          this.openComposioAuthLink(item);
        },
        onOpenExternalAuth: (url: string) => {
          this.openExternalUrl(url);
        }
      })
    } else if (this.showConfigPage) {
      this.ConfigPageContent();
    } else if (this.showPublicPersonaPage) {
      this.PublicPersonaPageContent();
    } else if (this.showBimPage) {
      this.BimPageContent();
    } else {
      Swiper(this.bimRootController) {
      HomePage({
        inputText: $inputText,
        isBusy: this.isBusy,
        showHistory: this.showHistory,
        messages: this.messages,
        currentSurface: this.currentSurface,
        htmlHomeHtml: this.htmlHomeHtmlForView(),
        foodStoreMapOpen: this.foodStoreMapOpen,
        foodStoreMapAmapKey: rideAmapWebKeyForUi(),
        foodStoreMapSnapshotJson: this.foodStoreMapSnapshotJson,
        foodStoreMapSnapshotTick: this.foodStoreMapSnapshotTick,
        multiTaskPayloadJson: this.multiTaskPayloadJson,
        multiTaskPayloadTick: this.multiTaskPayloadTick,
        waterfallPayloadJson: this.waterfallPayloadJson,
        waterfallPayloadTick: this.waterfallPayloadTick,
        waterfallBackRequestTick: this.waterfallBackRequestTick,
        mailDetailEventJson: this.mailDetailEventJson,
        mailReplyEventJson: this.mailReplyEventJson,
        mailCalendarEventJson: this.mailCalendarEventJson,
        surfaceRenderTick: this.surfaceRenderTick,
        luckinInlinePatchJson: this.luckinInlinePatchJson,
        luckinInlinePatchTick: this.luckinInlinePatchTick,
        isAwaitingFirstSurface: this.isAwaitingFirstSurface,
        inputPlaceholder: this.inputPlaceholder,
        isVoiceListening: this.isVoiceListening,
        voiceInputMessage: this.voiceInputMessage,
        showWelcome: shouldShowWelcome(this.isBusy, this.messages.length, this.currentSurface),
        showCheckoutWeb: this.showCheckoutWeb,
        checkoutWebKind: this.checkoutWebKind,
        checkoutWebUrl: this.checkoutWebUrl,
        checkoutWebTaskId: this.trainPresaleCheckoutTaskId,
        checkoutWebContext: this.checkoutWebContext,
        showTrainPresalePanel: this.showTrainPresalePanel,
        showDeepSearch: this.showDeepSearch,
        deepSearchQuery: this.deepSearchQuery,
        deepSearchSettingsJson: this.deepSearchSettingsJson,
        deepSearchContextJson: this.deepSearchContextJson,
        locationServiceNotice: this.locationServiceNotice,
        trainPresaleTrip: this.trainPresaleTrip,
        trainPresaleTask: this.trainPresaleTask,
        trainPresaleTaskState: this.trainPresaleTaskState,
        trainPresaleError: this.trainPresaleError,
        trainPresaleWorking: this.trainPresaleWorking,
        isDebugBuild: this.isDebugBuild,
        bimVisibleCount: this.bimVisibleCount(),
        bimSuggestionTitle: this.bimSuggestionTitle,
        bimSuggestionReason: this.bimSuggestionReason,
        bimRememberState: this.bimRememberState,
        bimRememberError: this.bimRememberError,
        reduceMotion: this.bimReduceMotion,
        onOpenConfig: () => {
          this.showConfigPage = true;
        },
        onOpenPublicPersona: () => {
          this.openPublicPersona();
        },
        onToggleHistory: () => {
          this.showHistory = !this.showHistory;
        },
        onOpenBim: () => {
          this.openBimRoot();
        },
        onResetSession: () => {
          this.resetCurrentSession();
        },
        onCloseFoodStoreMap: () => {
          this.foodStoreMapOpen = false;
        },
        onFoodStoreMapLocationConfirm: (longitude: number, latitude: number,
          name: string, address: string): void => {
          this.foodStoreMapOpen = false;
          const searchArea: A2uiFoodSearchArea = {
            longitude: longitude,
            latitude: latitude,
            radiusMeters: this.foodLocationRadiusMeters,
            name: name,
            address: address
          };
          const args: FoodStoreMapLocationActionArgs = {
            surfaceId: this.currentSurface.surfaceId,
            searchArea: searchArea
          };
          const action: A2uiAction = {
            id: 'food_change_location',
            label: '使用这个位置',
            prompt: '在新位置重新搜索餐饮',
            variant: 'secondary',
            kind: 'client',
            args: args
          };
          void this.refreshFoodSearchAtLocation(action);
        },
        onSendPrompt: () => {
          this.sendPrompt();
        },
        onSendWelcomePrompt: (prompt: string): void => {
          void this.submitPrompt(prompt, prompt);
        },
        onOpenWaterfall: (): void => {
          this.ensureInterestWaterfall();
          this.bimRootController.changeIndex(1, !this.bimReduceMotion);
        },
        onStartVoiceInput: () => {
          this.startVoiceInput();
        },
        onStopVoiceInput: () => {
          this.stopVoiceInput();
        },
        onCloseCheckoutWeb: (closingTaskId: string) => {
          const closedTrainBooking = this.checkoutWebKind === 'train';
          const closedHotelBooking = this.checkoutWebKind === 'hotel';
          const closedFlightBooking = this.checkoutWebKind === 'flight';
          if (closedTrainBooking && closingTaskId.length > 0 &&
            closingTaskId !== this.trainPresaleCheckoutTaskId) {
            aiLogInfo('[AIPhone][TrainPresaleCheckoutClose] taskId=' + closingTaskId + ' ignored=stale');
            return;
          }
          this.showCheckoutWeb = false;
          this.checkoutWebContext = '';
          if (closedHotelBooking) {
            this.restoreHotelReturnSurface('hotel_booking_closed');
          }
          if (closedTrainBooking && closingTaskId.length > 0) {
            this.closeExecutingTrainCheckout(closingTaskId);
          } else if (closedTrainBooking) {
            this.applyPanelState(updateConnectionPanelState(this.currentPanelState(), {
              ok: true,
              status: 'ready',
              message: '订单与支付结果请以 12306 为准。',
              requestDebug: this.lastModelRequest,
              assistantDebug: this.lastModelOutput,
              error: ''
            }));
            this.getUIContext().getPromptAction().showToast({ message: '订单与支付结果请以 12306 为准。' });
          }
          if (closedFlightBooking) {
            this.getUIContext().getPromptAction().showToast({ message: '请核对携程订单后确认是否完成预订。' });
          }
        },
        onCheckoutWebReturn: (url: string) => {
          this.handlePaymentCheckoutReturn(url);
        },
        onTrainPresaleConfirm: (submission: TrainPresalePanelSubmission) => {
          void this.confirmTrainPresale(submission);
        },
        onCloseTrainPresale: () => {
          if (!this.trainPresaleWorking) {
            this.showTrainPresalePanel = false;
          }
        },
        onCloseDeepSearch: () => {
          this.closeDeepSearch();
        },
        onCancelTrainPresaleTask: () => {
          void this.cancelTrainPresaleTask();
        },
        onAction: (action: A2uiAction) => {
          this.sendAction(action);
        },
        onWaterfallFullscreenChange: (active: boolean): void => {
          this.waterfallFullscreen = active;
        }
      })

      Stack({ alignContent: Alignment.Bottom }) {
        Image($r('app.media.home_light_aurora_background'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .hitTestBehavior(HitTestMode.Transparent)
          .align(Alignment.TopStart)

        HtmlHomeSurfaceView({
          html: this.interestWaterfallHtml,
          waterfallPayloadJson: this.interestWaterfallPayloadJson,
          waterfallPayloadTick: this.interestWaterfallPayloadTick,
          waterfallBackRequestTick: this.interestWaterfallBackRequestTick,
          isBusy: false,
          renderTick: this.interestWaterfallPayloadTick,
          onAction: (action: A2uiAction): void => {
            this.handleInterestWaterfallClientAction(action);
          },
          onWaterfallFullscreenChange: (active: boolean): void => {
            this.interestWaterfallFullscreen = active;
          }
        })
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
        .zIndex(1)

        Column() {
          WaterfallVoiceDock({
            isListening: this.isVoiceListening && this.voiceTarget === 'waterfall',
            isBusy: this.waterfallConversationBusy ||
              (this.isVoiceListening && this.voiceTarget !== 'waterfall'),
            reduceMotion: this.bimReduceMotion,
            message: this.waterfallConversationMessage,
            onStart: (): void => {
              void this.startVoiceInput('waterfall');
            },
            onStop: (): void => {
              this.stopVoiceInput();
            }
          })
        }
        .width('100%')
        .margin({ bottom: 20 })
        .zIndex(this.interestWaterfallFullscreen ? 0 : 2)
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .index(this.bimRootIndex)
      .loop(false)
      .indicator(false)
      .disableSwipe(this.bimRootIndex === 1 || this.waterfallFullscreen)
      .duration(this.bimReduceMotion ? 0 : A2UI_MOTION_NORMAL_MS)
      .curve(A2UI_MOTION_MOVE_CURVE)
      .onChange((index: number) => {
        this.bimRootIndex = index;
        if (index === 1) this.ensureInterestWaterfall();
        else inputMethod.getController().hideTextInput().catch((_error: BusinessError): void => {});
      })
    }
  }
}
