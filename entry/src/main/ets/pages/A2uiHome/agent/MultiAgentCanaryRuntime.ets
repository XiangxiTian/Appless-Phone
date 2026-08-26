import {
  ActionArgsValidator,
  ActionCatalog,
  ActionExecutionContext,
  ActionExecutionResult,
  ActionOffer,
  ActionPlanRequestPayload,
  ActionValidationResult,
  A2uiAction,
  A2uiParserProfile,
  A2uiRuntimeDataModel,
  A2uiSurfaceStore,
  A2uiSurfaceState,
  CalendarEventArgs,
  ClientActionAuthorizer,
  CreateDataTaskPayload,
  CreateUiTaskPayload,
  DataResult,
  DataTaskExecutor,
  DataTaskPlanner,
  DataTaskAuthorizationResult,
  DynamicGenericToolResult,
  InputUserPayload,
  JsonValue,
  LeaderDataTaskInputNormalizer,
  LeaderDecisionDataTask,
  LeaderMemoryMutation,
  LeaderMemoryRecallToolExecutor,
  LeaderMemoryRecallToolRequest,
  LeaderMemoryToolExecutionGuard,
  LeaderMemoryToolExecutor,
  LeaderMemoryToolRequest,
  LeaderMemoryToolResult,
  LeaderPersonaMetadata,
  LeaderPlanningContext,
  LeaderSkillMetadata,
  LeaderToolMetadata,
  LinkedMessageBus,
  LocalModel,
  MEMORY_RECALL_DEFAULT_TOP_K,
  MEMORY_RECALL_FACT_MAX_CHARS,
  MEMORY_RECALL_MAX_TOP_K,
  memoryRecallTotalMaxChars,
  MemoryBatchResult,
  MemoryCommitGuard,
  MemorySelectionPayload,
  MemoryRecallItem,
  MEMORY_RECALL_OBSERVATION_QUERY_MAX_CHARS,
  MemoryRecallObservation,
  MemoryWriteResult,
  MailDetail,
  MailDetailRequest,
  RegisteredActionExecutor,
  RecalledMemoryContext,
  SurfaceActionAuthorizer,
  ToolDefinition,
  ToolDefinitionLookup,
  UiLayoutPlanner,
  UiRenderProgressSink,
  UiRenderResult,
  UiSurfaceWriteLease,
  UiSurfaceWriter,
  UiTaskRenderer,
  UserInputPayload,
  VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID,
  VirtualActionIntent,
  VirtualActionIntentResolver,
  allAiphoneToolDefinitions,
  allToolDefinitions,
  aiLogInfo,
  callStructuredTool,
  gmailDraftApplyAction,
  genericToolResultsA2ui,
  isMultiTaskSurface,
  appendMultiTaskSlot,
  mergeSurfaceIntoMultiTaskSurface,
  resolveMultiTaskSlotId,
  normalizedCalendarArgsForPrompt,
  parseA2uiJsonl,
  setJsonPointer,
  toolDefinitionForToolId,
  toolPlanningDescriptionForToolId
} from '@loop/agent-core';
import { leaderPersonaContext } from '../../../model/LeaderPersonaContext';
import {
  PhoneLocalMemoryRuntimePort,
  PhoneLocalRecalledMemory
} from '../../../memory/PhoneLocalMemoryRuntime';
import { PhoneLocalMemoryAvailabilityPort } from '../../../memory/PhoneLocalMemoryAvailability';
import {
  MemoryCandidatesForgetActionArgs,
  MemoryCandidateSelectionItem,
  MemoryCandidateSelectionSurfaceInput,
  MEMORY_CANDIDATES_FORGET_ACTION_ID,
  memoryCandidatesForgetActionArgs,
  memoryCandidateSelectionSurface,
  memoryForgetConfirmationSurface
} from '../../../model/MemoryCandidateSelectionSurface';
import { MultiAgentLeaderPlanner } from './MultiAgentLeaderPlanner';
import { MultiAgentActionPlanCompiler } from './MultiAgentActionPlanCompiler';
import {
  HotelLocalDateProvider
} from './HotelLeaderPlanner';
import { mailDetailIdentityDigest, MultiAgentRuntime } from './MultiAgentRuntime';
import { MultiAgentSettledOutcome, MultiAgentTurnOutcome } from './MultiAgentRuntimeTypes';
import { isHtmlHomeActionAllowed } from '../html/HtmlHomeActionPolicy';
import { HtmlHomeDocument } from '../html/HtmlHomeTypes';
import {
  authorizeHotelDataTask,
  HotelActionContext,
  HotelRuntimeSurfaceWriter,
  HotelSurfaceAuthority,
  HotelVisibility,
  IgnoreHotelSurfaceWriter,
  MonotonicHotelIds,
  PreparedHotelFollowUpIds
} from './MultiAgentHotelSupport';
import { StructuredToolUiRenderer } from './StructuredToolUiRenderer';
import {
  AiphoneRegisteredActionExecutor,
  MailDetailFollowUpPreparer,
  RegisteredPageAction,
  RegisteredPageActionContext,
  SystemUriOpener,
  validateRegisteredPageActionArgs
} from './AiphoneRegisteredActionExecutor';
import {
  RegisteredPageSnapshot,
  registeredPageActionSourceToolId,
  registeredPageSourceToolId,
  registeredPageSnapshotFingerprint,
  resolveRegisteredPageAction,
  resolveVirtualRegisteredPageAction
} from './RegisteredPageActionRoute';
import {
  originalQueryFromBimPrompt
} from '../bim/BimRuntime';

const MEMORY_ACTION_IDS: string[] = [
  'memory.remember',
  'memory.update',
  'memory.forget'
];
const TIME_TOOL_ID: string = 'time';
const TURN_HOST_GENERATION_LIMIT: number = 32;

function memoryPlanningHint(toolId: string): string {
  if (toolId === 'memory.remember') {
    return 'Leader-owned local memory write. Use memoryMutation exactly as ' +
      '{"operation":"remember","facts":["one atomic sentence"]}; facts is a string array with 1-5 items. ' +
      'For a memory-only turn use roundAction="execute", dataTasks=[], no actionIntent, and omit answer.';
  }
  if (toolId === 'memory.update') {
    return 'Leader-owned local memory update. Use memoryMutation exactly as ' +
      '{"operation":"update","memoryId":"one recalled ID","fact":"one atomic sentence"}. ' +
      'For a memory-only turn use roundAction="execute", dataTasks=[], no actionIntent, and omit answer.';
  }
  return 'Leader-owned local memory management. For every forget request use memoryClarification exactly as ' +
    '{"operation":"forget"}; the Host will show all one-to-five memories recalled for this turn with zero ' +
    'selected by default, and only a later user-confirmed management-card action may delete selected records. ' +
    'Never emit an exact forget memoryMutation. Use roundAction="execute", dataTasks=[], no actionIntent, and omit answer.';
}

interface CalendarReviewOutput {
  surfaceId: string;
}

interface GmailDraftApplySurfaceBinding {
  action: A2uiAction;
  actionJson: string;
  runtimeGeneration: number;
  surface: A2uiSurfaceState;
  surfaceId: string;
  surfaceStatus: string;
}

interface GmailDraftApplyCandidate {
  actionJson: string;
  runtimeGeneration: number;
  surfaceId: string;
  surfaceStatus: string;
}

type GmailDraftOutputValue = Object | string | number | boolean | null | undefined;
type GmailDraftOutputRecord = Record<string, GmailDraftOutputValue>;

interface CalendarUpdateRequestArgs extends CalendarEventArgs {
  actionId: string;
}

interface CalendarUpdateSearchArgs {
  query: string;
  date: string;
  timeMin: string;
  timeMax: string;
  timezone: string;
  calendarId: string;
  requestedAction: CalendarUpdateRequestArgs;
}

interface CalendarDeleteRequestArgs {
  actionId: string;
  query: string;
  calendarId: string;
}

interface CalendarDeleteSearchArgs {
  query: string;
  date: string;
  timeMin: string;
  timeMax: string;
  timezone: string;
  calendarId: string;
  requestedAction: CalendarDeleteRequestArgs;
}

interface SocialFeedTaskInput {
  platforms: string[];
}

export interface MultiAgentCanaryOptions {
  model: LocalModel;
  opener: SystemUriOpener;
  pageAction?: RegisteredPageAction;
  currentPageSnapshot?: () => RegisteredPageSnapshot | null;
  currentHostSurface?: () => A2uiSurfaceState | null;
  currentHostGeneration?: () => number;
  onSurface: (surface: A2uiSurfaceState, runtimeGeneration: number) => boolean;
  memoryRuntime?: PhoneLocalMemoryRuntimePort;
  /** Process-lifetime feature gate; omitted preserves existing injected-test behavior. */
  memoryAvailability?: PhoneLocalMemoryAvailabilityPort;
  onMailDetail?: (
    event: MailDetailInPlaceEvent,
    runtimeGeneration: number,
    lease: MailDetailWriteLease
  ) => Promise<void>;
  downstreamWriter?: UiSurfaceWriter;
  uiLayoutPlanner?: UiLayoutPlanner;
  uiRenderer?: UiTaskRenderer;
  surfaceDocumentProjector?: (surface: A2uiSurfaceState) => HtmlHomeDocument;
  a2uiParserProfile?: A2uiParserProfile;
  settingsFingerprint?: string;
  submitTimeoutMs?: number;
  actionTimeoutMs?: number;
  currentLocalDate?: HotelLocalDateProvider;
  dataPlanner?: DataTaskPlanner;
  dataExecutor?: DataTaskExecutor;
  structuredToolCall?: (
    toolId: string,
    prompt: string,
    args: Object,
    onPartial?: (result: DataResult) => void
  ) => Promise<DataResult>;
  /** Host-only planning capability. UI Lab enables trusted operationTarget values; Home keeps this disabled. */
  allowTrustedOperationTargets?: boolean;
  /** Product projection used by the focused release; shared runtime tests keep the complete catalog. */
  focusedRelease?: boolean;
  bus?: LinkedMessageBus;
  conversationId?: string;
}

export interface MailDetailInPlaceEvent {
  requestKey: string;
  provider: string;
  identityDigest: string;
  status: 'success' | 'error';
  detail?: MailDetail;
  error: string;
}

interface PreparedMailDetail {
  request: MailDetailRequest;
  generation: number;
}

interface MailDetailSurfaceState extends PreparedMailDetail {
  uiTaskId: string;
  event: MailDetailInPlaceEvent | null;
  epoch: number;
  canceled: boolean;
}

export interface MailDetailWriteLease {
  isActive(): boolean;
}

const MAIL_DETAIL_STATE_LIMIT: number = 8;

function mailText(value: Object | string | number | boolean | null | undefined): string {
  return typeof value === 'string' ? value : '';
}

function mailStrings(value: Object | string | number | boolean | null | undefined): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const values = value as (Object | string | number | boolean | null | undefined)[];
  const result: string[] = [];
  for (let index = 0; index < values.length; index++) {
    if (typeof values[index] !== 'string') {
      return null;
    }
    result.push(values[index] as string);
  }
  return result;
}

function mailDetailFromData(
  data: DataResult,
  request: MailDetailRequest
): MailDetailInPlaceEvent {
  const identityDigest = mailDetailIdentityDigest(request);
  const providerError = data.error === undefined ? '' : data.error.message;
  if (data.status === 'error') {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: providerError.trim().length > 0 ? providerError : '邮件正文读取失败。'
    };
  }
  if (data.status !== 'success' || data.outputSchema !== 'mailThread' ||
    data.data === null || typeof data.data !== 'object' || Array.isArray(data.data)) {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: '邮件正文数据无效。'
    };
  }
  const values = data.data as Record<string, Object | string | number | boolean | null | undefined>;
  const to = mailStrings(values['to']);
  const cc = mailStrings(values['cc']);
  const body = mailText(values['body']);
  const bodyHtml = mailText(values['bodyHtml']);
  if (mailText(values['requestKey']) !== request.requestKey ||
    mailText(values['provider']) !== request.provider ||
    mailText(values['threadId']) !== request.threadId ||
    mailText(values['messageId']) !== request.messageId ||
    to === null || cc === null || (body.trim().length === 0 && bodyHtml.trim().length === 0)) {
    return {
      requestKey: request.requestKey,
      provider: request.provider,
      identityDigest,
      status: 'error',
      error: '邮件正文身份或内容无效。'
    };
  }
  const detail: MailDetail = {
    requestKey: request.requestKey,
    provider: request.provider,
    threadId: request.threadId,
    messageId: request.messageId,
    internetMessageId: mailText(values['internetMessageId']),
    subject: mailText(values['subject']),
    from: mailText(values['from']),
    replyTo: mailText(values['replyTo']),
    to,
    cc,
    bodyText: body,
    bodyHtml
  };
  return {
    requestKey: request.requestKey,
    provider: request.provider,
    identityDigest,
    status: 'success',
    detail,
    error: ''
  };
}

class MailDetailBridgeLease implements MailDetailWriteLease {
  private readonly active: () => boolean;

  constructor(active: () => boolean) {
    this.active = active;
  }

  isActive(): boolean {
    return this.active();
  }
}

class MailDetailInPlaceBridge implements UiTaskRenderer, UiSurfaceWriter, MailDetailFollowUpPreparer {
  private readonly renderer: UiTaskRenderer;
  private readonly mailRenderer: UiTaskRenderer;
  private readonly writer: UiSurfaceWriter;
  private readonly currentGeneration: () => number;
  private readonly callback: ((
    event: MailDetailInPlaceEvent,
    generation: number,
    lease: MailDetailWriteLease
  ) => Promise<void>) | null;
  private readonly prepared: Map<string, PreparedMailDetail> = new Map<string, PreparedMailDetail>();
  private readonly canceledPrepared: Map<string, PreparedMailDetail> = new Map<string, PreparedMailDetail>();
  private readonly surfaces: Map<string, MailDetailSurfaceState> = new Map<string, MailDetailSurfaceState>();
  private epoch: number = 1;
  private disposed: boolean = false;

  constructor(
    renderer: UiTaskRenderer,
    writer: UiSurfaceWriter,
    currentGeneration: () => number,
    callback?: (
      event: MailDetailInPlaceEvent,
      generation: number,
      lease: MailDetailWriteLease
    ) => Promise<void>
  ) {
    this.renderer = renderer;
    this.mailRenderer = new StructuredToolUiRenderer(null, 6000);
    this.writer = writer;
    this.currentGeneration = currentGeneration;
    this.callback = callback === undefined ? null : callback;
  }

  private stateCount(): number {
    return this.prepared.size + this.canceledPrepared.size + this.surfaces.size;
  }

  private pruneCanceledState(): void {
    while (this.stateCount() >= MAIL_DETAIL_STATE_LIMIT && this.canceledPrepared.size > 0) {
      const first = this.canceledPrepared.keys().next();
      if (first.done) {
        break;
      }
      this.canceledPrepared.delete(first.value);
    }
    if (this.stateCount() < MAIL_DETAIL_STATE_LIMIT) {
      return;
    }
    const entries = this.surfaces.entries();
    let next = entries.next();
    while (!next.done && this.stateCount() >= MAIL_DETAIL_STATE_LIMIT) {
      if (next.value[1].canceled) {
        this.surfaces.delete(next.value[0]);
      }
      next = entries.next();
    }
  }

  prepare(uiTaskId: string, request: MailDetailRequest): boolean {
    const actionId = request.provider === 'gmail' ? 'gmail.thread.read' : 'mail.thread.read';
    const generation = this.currentGeneration();
    this.pruneCanceledState();
    if (this.disposed || this.callback === null || this.stateCount() >= MAIL_DETAIL_STATE_LIMIT ||
      uiTaskId.trim().length === 0 || !Number.isSafeInteger(generation) || generation <= 0 ||
      !validateRegisteredPageActionArgs(actionId, request).ok) {
      return false;
    }
    this.prepared.set(uiTaskId, {
      request: {
        requestKey: request.requestKey,
        provider: request.provider,
        threadId: request.threadId,
        messageId: request.messageId,
        subject: request.subject
      },
      generation
    });
    return true;
  }

  async skeleton(task: CreateUiTaskPayload, surfaceId: string): Promise<UiRenderResult> {
    const prepared = this.prepared.get(task.taskId);
    const canceled = this.canceledPrepared.get(task.taskId);
    const mailTask = task.dataTaskIds.length === 1 && task.expectedOutputSchema === 'mailThread' &&
      (task.intent === 'mail.thread.read' || task.intent === 'gmail.thread.read');
    if (prepared === undefined && canceled !== undefined && mailTask) {
      this.canceledPrepared.delete(task.taskId);
      this.surfaces.set(surfaceId, {
        uiTaskId: task.taskId,
        request: canceled.request,
        generation: canceled.generation,
        event: null,
        epoch: this.epoch,
        canceled: true
      });
      return this.mailRenderer.skeleton(task, surfaceId);
    }
    if (prepared === undefined || !mailTask ||
      this.disposed) {
      return this.renderer.skeleton(task, surfaceId);
    }
    this.prepared.delete(task.taskId);
    this.surfaces.set(surfaceId, {
      uiTaskId: task.taskId,
      request: prepared.request,
      generation: prepared.generation,
      event: null,
      epoch: this.epoch,
      canceled: false
    });
    return this.mailRenderer.skeleton(task, surfaceId);
  }

  async result(
    task: CreateUiTaskPayload,
    data: DataResult[],
    offers: ActionOffer[],
    surfaceId: string,
    progressSink?: UiRenderProgressSink
  ): Promise<UiRenderResult> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined || state.uiTaskId !== task.taskId) {
      return this.renderer.result(task, data, offers, surfaceId, progressSink);
    }
    if (data.length !== 1 || data[0].toolId !== task.intent) {
      state.event = {
        requestKey: state.request.requestKey,
        provider: state.request.provider,
        identityDigest: mailDetailIdentityDigest(state.request),
        status: 'error',
        error: '邮件正文结果关联无效。'
      };
      return this.mailRenderer.error(task, state.event.error, surfaceId);
    }
    state.event = mailDetailFromData(data[0], state.request);
    return state.event.status === 'success' ?
      this.mailRenderer.result(task, data, [], surfaceId) :
      this.mailRenderer.error(task, state.event.error, surfaceId);
  }

  async error(task: CreateUiTaskPayload, message: string, surfaceId: string): Promise<UiRenderResult> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined || state.uiTaskId !== task.taskId) {
      return this.renderer.error(task, message, surfaceId);
    }
    state.event = {
      requestKey: state.request.requestKey,
      provider: state.request.provider,
      identityDigest: mailDetailIdentityDigest(state.request),
      status: 'error',
      error: message.trim().length > 0 ? message : '邮件正文读取失败。'
    };
    return this.mailRenderer.error(task, state.event.error, surfaceId);
  }

  actionStatus(payload: Object, surfaceId: string): Promise<UiRenderResult> {
    return this.renderer.actionStatus(payload, surfaceId);
  }

  async write(
    turnId: string,
    surfaceId: string,
    jsonl: string,
    lease: UiSurfaceWriteLease
  ): Promise<void> {
    const state = this.surfaces.get(surfaceId);
    if (state === undefined) {
      if (!lease.isActive()) {
        return;
      }
      return this.writer.write(turnId, surfaceId, jsonl, lease);
    }
    if (state.canceled || state.event === null || !lease.isActive() || this.disposed) {
      if (state.canceled || !lease.isActive() || this.disposed) {
        this.surfaces.delete(surfaceId);
      }
      return;
    }
    const event = state.event;
    if (this.callback === null) {
      throw new Error('Mail detail callback is unavailable.');
    }
    const expectedEpoch = state.epoch;
    const writeLease: MailDetailWriteLease = new MailDetailBridgeLease((): boolean =>
      !this.disposed && this.epoch === expectedEpoch && lease.isActive() &&
        this.surfaces.get(surfaceId) === state && !state.canceled
    );
    try {
      await this.callback(event, state.generation, writeLease);
      if (!writeLease.isActive()) {
        return;
      }
      if (event.status === 'error') {
        throw new Error(event.error);
      }
    } finally {
      if (this.surfaces.get(surfaceId) === state) {
        this.surfaces.delete(surfaceId);
      }
    }
  }

  actionSettled(ok: boolean): void {
    if (ok) {
      this.prepared.clear();
      return;
    }
    this.epoch++;
    this.prepared.forEach((prepared: PreparedMailDetail, taskId: string) => {
      this.canceledPrepared.set(taskId, prepared);
    });
    this.prepared.clear();
    this.surfaces.forEach((surface: MailDetailSurfaceState) => {
      surface.canceled = true;
    });
    this.pruneCanceledState();
  }

  dispose(): void {
    this.disposed = true;
    this.epoch++;
    this.prepared.clear();
    this.canceledPrepared.clear();
    this.surfaces.clear();
  }
}

export interface MultiAgentCanaryActionContext {
  conversationId: string;
  turnId: string;
  surfaceId: string;
  sourceToolId: string;
  pageActionId?: string;
}

class CanaryToolLookup implements ToolDefinitionLookup {
  find(toolId: string): ToolDefinition | null {
    return toolDefinitionForToolId(toolId);
  }
}

interface PendingMemoryForgetCandidate {
  candidateKey: string;
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: 'leader' | 'seed';
}

interface PendingMemoryForgetSelection {
  selectionId: string;
  conversationId: string;
  originTurnId: string;
  sourceTaskId: string;
  personaId: string;
  hostGeneration: number;
  surfaceId: string;
  revision: number;
  deletedCount: number;
  candidates: PendingMemoryForgetCandidate[];
  inFlight: boolean;
  consumed: boolean;
}

export interface MemoryCandidateManagerActionResult {
  handled: boolean;
  status: 'success' | 'partial' | 'error' | 'rejected';
  message: string;
  presented: boolean;
  notify: boolean;
}

class RejectClientAction implements ClientActionAuthorizer {
  allows(_actionId: string, _args: Object): boolean {
    return false;
  }
}

function calendarNow(currentLocalDate: string | undefined): Date | null {
  if (currentLocalDate === undefined || currentLocalDate.length !== 10 ||
    currentLocalDate.charCodeAt(4) !== 45 || currentLocalDate.charCodeAt(7) !== 45) {
    return null;
  }
  const digitIndexes: number[] = [0, 1, 2, 3, 5, 6, 8, 9];
  for (let index = 0; index < digitIndexes.length; index++) {
    const code: number = currentLocalDate.charCodeAt(digitIndexes[index]);
    if (code < 48 || code > 57) {
      return null;
    }
  }
  const year: number = Number(currentLocalDate.substring(0, 4));
  const month: number = Number(currentLocalDate.substring(5, 7));
  const day: number = Number(currentLocalDate.substring(8, 10));
  const utc: Date = new Date(Date.UTC(year, month - 1, day));
  if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 ||
    utc.getUTCFullYear() !== year || utc.getUTCMonth() + 1 !== month || utc.getUTCDate() !== day) {
    return null;
  }
  const timestamp: number = Date.parse(currentLocalDate + 'T00:00:00+08:00');
  return Number.isNaN(timestamp) ? null : new Date(timestamp);
}

function calendarUpdateSearchArgs(input: string, now: Date): CalendarUpdateSearchArgs | null {
  const normalized = normalizedCalendarArgsForPrompt('calendar.event.update', input, {}, now, true);
  const query = normalized.query === undefined ? '' : normalized.query.trim();
  const title = normalized.title === undefined ? '' : normalized.title.trim();
  const start = normalized.start === undefined ? '' : normalized.start.trim();
  if (query.length === 0 || (title.length === 0 && start.length === 0)) {
    return null;
  }
  return {
    query,
    date: normalized.date === undefined ? '' : normalized.date,
    timeMin: normalized.timeMin === undefined ? '' : normalized.timeMin,
    timeMax: normalized.timeMax === undefined ? '' : normalized.timeMax,
    timezone: normalized.timezone === undefined ? '' : normalized.timezone,
    calendarId: normalized.calendarId === undefined ? '' : normalized.calendarId,
    requestedAction: {
      actionId: 'calendar.event.update',
      title,
      start,
      end: normalized.end === undefined ? '' : normalized.end,
      timezone: normalized.timezone === undefined ? '' : normalized.timezone,
      calendarId: normalized.calendarId === undefined ? '' : normalized.calendarId
    }
  };
}

function calendarDeleteSearchArgs(input: string, now: Date): CalendarDeleteSearchArgs | null {
  if (input.indexOf('删除') < 0) {
    return null;
  }
  const titleMatch = /标题为\s*(.+?)\s*的\s*Google\s+Calendar\s*日程/i.exec(input);
  const chineseDate = /(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日/.exec(input);
  const isoDate = /(\d{4})-(\d{1,2})-(\d{1,2})/.exec(input);
  const dateMatch = chineseDate === null ? isoDate : chineseDate;
  if (titleMatch === null || dateMatch === null) {
    return null;
  }
  const title = titleMatch[1].trim();
  const month = Number(dateMatch[2]);
  const day = Number(dateMatch[3]);
  const year = Number(dateMatch[1]);
  const checked = new Date(Date.UTC(year, month - 1, day));
  if (title.length === 0 || title.length > 240 || year < 2000 || year > 2100 ||
    month < 1 || month > 12 || day < 1 ||
    checked.getUTCFullYear() !== year || checked.getUTCMonth() + 1 !== month ||
    checked.getUTCDate() !== day) {
    return null;
  }
  const date = year.toString().padStart(4, '0') + '-' +
    month.toString().padStart(2, '0') + '-' + day.toString().padStart(2, '0');
  const normalized = normalizedCalendarArgsForPrompt('calendar.events.search', input, {
    query: title,
    date,
    timezone: 'Asia/Shanghai',
    calendarId: 'primary'
  }, now);
  return {
    query: title,
    date,
    timeMin: normalized.timeMin === undefined ? '' : normalized.timeMin,
    timeMax: normalized.timeMax === undefined ? '' : normalized.timeMax,
    timezone: normalized.timezone === undefined ? '' : normalized.timezone,
    calendarId: normalized.calendarId === undefined ? 'primary' : normalized.calendarId,
    requestedAction: {
      actionId: 'calendar.event.delete',
      query: title,
      calendarId: normalized.calendarId === undefined ? 'primary' : normalized.calendarId
    }
  };
}

function unwrapSingleArgsEnvelope(input: Object): Object {
  const source = input as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(source);
  if (keys.length !== 1 || keys[0] !== 'args') {
    return input;
  }
  const args = source['args'];
  return args !== null && args !== undefined && typeof args === 'object' && !Array.isArray(args) ?
    args as Object : input;
}

function normalizedSocialFeedTaskInput(input: Object): Object {
  const source = input as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = Object.keys(source);
  const raw: Object | string | number | boolean | null | undefined = source['platforms'];
  if (keys.length !== 1 || keys[0] !== 'platforms' || !Array.isArray(raw) || raw.length === 0) {
    throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
  }
  const rawPlatforms: Object[] = raw as Object[];
  const allowed: string[] = ['x', 'slack', 'wecom', 'discord', 'linkedin', 'whatsapp', 'instagram', 'all'];
  const platforms: string[] = [];
  for (let index = 0; index < rawPlatforms.length; index++) {
    const value: Object = rawPlatforms[index];
    if (typeof value !== 'string') {
      throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
    }
    const platform = value.trim().toLowerCase();
    if (allowed.indexOf(platform) < 0 || platforms.indexOf(platform) >= 0) {
      throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
    }
    platforms.push(platform);
  }
  if (platforms.indexOf('all') >= 0 && platforms.length !== 1) {
    throw new Error('SOCIAL_FEED_PLATFORMS_INVALID');
  }
  const result: SocialFeedTaskInput = { platforms };
  return result;
}

function validSocialFeedTaskInput(input: Object): boolean {
  try {
    normalizedSocialFeedTaskInput(input);
    return true;
  } catch (_error) {
    return false;
  }
}

function normalizeCanaryTaskInput(
  input: InputUserPayload,
  task: LeaderDecisionDataTask,
  currentLocalDate: string
): Object {
  const cloned = setJsonPointer(task.input as JsonValue, '', task.input as JsonValue);
  if (!cloned.ok || cloned.value === undefined || cloned.value === null ||
    typeof cloned.value !== 'object' || Array.isArray(cloned.value)) {
    throw new Error(cloned.errorCode.length > 0 ? cloned.errorCode : 'TASK_INPUT_INVALID');
  }
  const safeInput: Object = cloned.value as Object;
  const originalInput: InputUserPayload = {
    text: originalQueryFromBimPrompt(input.text),
    recentMessages: input.recentMessages,
    sessionSummary: input.sessionSummary,
    lastTurnPersonaId: input.lastTurnPersonaId,
    memoryRecallObservation: input.memoryRecallObservation,
    currentSurfaceSummary: input.currentSurfaceSummary,
    recentObservations: input.recentObservations,
    orderedContinuationAuthorized: input.orderedContinuationAuthorized
  };
  // MultiAgentLeaderPlanner owns the date snapshot and replaces task.input with
  // the normalized value. LeaderAgent receives the same host-only authority
  // for its defense-in-depth pass and never calls an independent clock.
  if (task.toolId === 'social.feed.search') {
    return normalizedSocialFeedTaskInput(unwrapSingleArgsEnvelope(safeInput));
  }
  if (task.toolId !== 'calendar.events.search') {
    return safeInput;
  }
  const timestamp: number = Date.parse(currentLocalDate + 'T00:00:00+08:00');
  if (Number.isNaN(timestamp)) {
    throw new Error('CURRENT_LOCAL_DATE_INVALID');
  }
  const now = new Date(timestamp);
  const update = calendarUpdateSearchArgs(originalInput.text, now);
  if (update !== null) {
    return update as Object;
  }
  const remove = calendarDeleteSearchArgs(originalInput.text, now);
  if (remove !== null) {
    return remove as Object;
  }
  const source = safeInput as Record<string, Object | string | number | boolean | null | undefined>;
  const safe: Record<string, Object | string | number | boolean> = {};
  Object.keys(source).forEach((key: string) => {
    const value = source[key];
    if (key !== 'eventId' && key !== 'requestedAction' && value !== null && value !== undefined) {
      safe[key] = value as Object | string | number | boolean;
    }
  });
  return normalizedCalendarArgsForPrompt('calendar.events.search', originalInput.text, safe, now) as Object;
}

function authorizeCanaryDataTask(task: CreateDataTaskPayload): DataTaskAuthorizationResult {
  if (task.toolId === TIME_TOOL_ID) {
    const validTime = task.required && task.outputSchema === 'genericToolResults' &&
      task.allowedToolIds.length === 1 && task.allowedToolIds[0] === TIME_TOOL_ID &&
      Object.keys(task.args).length === 0;
    return {
      ok: validTime,
      code: validTime ? '' : 'DATA_TASK_UNAUTHORIZED',
      message: validTime ? '' : 'Time requires the exact device-local read tool.'
    };
  }
  if (task.toolId === 'dynamic.search') {
    const validDynamic = task.required && task.outputSchema === 'dynamicToolConnect' &&
      task.allowedToolIds.length === 1 && task.allowedToolIds[0] === 'dynamic.search';
    return {
      ok: validDynamic,
      code: validDynamic ? '' : 'DATA_TASK_UNAUTHORIZED',
      message: validDynamic ? '' : 'Dynamic data tasks require the exact read-only virtual tool.'
    };
  }
  if (task.toolId === 'hotel.search' || task.toolId === 'hotel.detail') {
    return authorizeHotelDataTask(task);
  }
  const definition = toolDefinitionForToolId(task.toolId);
  let valid: boolean = definition !== null && definition.riskLevel === 'read' &&
    definition.outputSchema === task.outputSchema && task.required &&
    definition.backendPriority.indexOf('system_intent') < 0 &&
    task.allowedToolIds.length > 0;
  const allowed: Set<string> = new Set<string>();
  for (let index = 0; valid && index < task.allowedToolIds.length; index++) {
    const toolId: string = task.allowedToolIds[index];
    const allowedDefinition = toolDefinitionForToolId(toolId);
    if (allowed.has(toolId) || allowedDefinition === null ||
      allowedDefinition.riskLevel !== 'read' ||
      allowedDefinition.backendPriority.indexOf('system_intent') >= 0) {
      valid = false;
    } else {
      allowed.add(toolId);
    }
  }
  valid = valid && allowed.has(task.toolId);
  if (valid && task.toolId === 'social.feed.search') {
    valid = validSocialFeedTaskInput(task.args);
  }
  return {
    ok: valid,
    code: valid ? '' : 'DATA_TASK_UNAUTHORIZED',
    message: valid ? '' : 'Data task is outside the registered read allowlist.'
  };
}

class CanaryStructuredDataExecutor implements DataTaskExecutor {
  private readonly structuredToolCall: (
    toolId: string,
    prompt: string,
    args: Object,
    onPartial?: (result: DataResult) => void
  ) => Promise<DataResult>;

  constructor(structuredToolCall?: (
    toolId: string,
    prompt: string,
    args: Object,
    onPartial?: (result: DataResult) => void
  ) => Promise<DataResult>) {
    this.structuredToolCall = structuredToolCall === undefined ? callStructuredTool : structuredToolCall;
  }

  async execute(
    task: CreateDataTaskPayload,
    onPartial?: (result: DataResult) => void
  ): Promise<DataResult> {
    if (task.toolId === TIME_TOOL_ID) {
      const now = new Date();
      const localTime = now.toLocaleString();
      const observationSummary = now.getFullYear().toString() + '-' +
        (now.getMonth() + 1).toString().padStart(2, '0') + '-' +
        now.getDate().toString().padStart(2, '0') + ' ' +
        now.getHours().toString().padStart(2, '0') + ':' +
        now.getMinutes().toString().padStart(2, '0');
      const result: DynamicGenericToolResult = {
        sourceTag: 'HarmonyOS device',
        toolName: TIME_TOOL_ID,
        title: '当前时间',
        status: 'success',
        summary: localTime,
        rows: [{ label: '本地时间', value: localTime }],
        rawPreview: ''
      };
      return {
        toolId: TIME_TOOL_ID,
        outputSchema: 'genericToolResults',
        status: 'success',
        sources: [{
          provider: 'HarmonyOS device',
          backend: 'local_adapter',
          operation: 'time.now',
          fetchedAt: now.toISOString()
        }],
        data: JSON.parse(JSON.stringify({
          summary: observationSummary,
          results: [result]
        })) as Object,
        warnings: []
      };
    }
    let prompt: string = task.goal;
    if (task.toolId === 'travel.search' || task.toolId === 'train.search' ||
      task.toolId === 'flight.search') {
      const values = task.args as Record<string, Object | string | number | boolean | null | undefined>;
      const query = values['query'];
      if (typeof query === 'string' && query.trim().length > 0) {
        prompt = query.trim();
      }
    }
    const result = task.toolId === 'media.aggregate.search' && onPartial !== undefined ?
      await this.structuredToolCall(task.toolId, prompt, task.args, onPartial) :
      await this.structuredToolCall(task.toolId, prompt, task.args);
    if (task.toolId !== 'calendar.events.search' || result.status === 'error') {
      return result;
    }
    const taskValues = task.args as Record<string, Object | string | number | boolean | null | undefined>;
    const requestedAction = taskValues['requestedAction'];
    if (requestedAction === null || requestedAction === undefined ||
      typeof requestedAction !== 'object' || Array.isArray(requestedAction)) {
      return result;
    }
    const data = result.data as Record<string, Object | string | number | boolean | null | undefined>;
    data['requestedAction'] = requestedAction;
    return result;
  }
}

function surfaceFromJsonl(jsonl: string): A2uiSurfaceState | null {
  const parsed = parseA2uiJsonl(jsonl);
  if (parsed.error.length > 0) {
    return null;
  }
  const store = new A2uiSurfaceStore();
  for (let index = 0; index < parsed.envelopes.length; index++) {
    if (!store.apply(parsed.envelopes[index]).ok) {
      return null;
    }
  }
  return store.getSurface();
}

function calendarReviewSurface(
  surfaceId: string,
  actionId: string,
  args: Object
): A2uiSurfaceState | null {
  const values = args as Record<string, Object | string | number | boolean | null | undefined>;
  const review: DynamicGenericToolResult = {
    sourceTag: 'Composio Google Calendar',
    toolName: actionId,
    title: actionId === 'calendar.event.create' ? '确认创建日程' : '确认更新日程',
    status: 'confirm_required',
    summary: '请核对当前日程参数；只有点击此卡片上的精确操作才会调用 Provider。',
    rows: [
      { label: 'Title', value: typeof values['title'] === 'string' ? values['title'] : '' },
      { label: 'Start', value: typeof values['start'] === 'string' ? values['start'] : '' },
      { label: 'End', value: typeof values['end'] === 'string' ? values['end'] : '' }
    ],
    rawPreview: JSON.stringify(args),
    actions: [{
      id: actionId,
      label: actionId === 'calendar.event.create' ? '确认创建' : '确认更新',
      prompt: actionId,
      variant: 'primary',
      kind: 'prompt',
      args
    }]
  };
  return surfaceFromJsonl(genericToolResultsA2ui(
    surfaceId, actionId, [review], 'calendar', review.title
  ));
}

class CanaryArgsValidator implements ActionArgsValidator {
  validate(actionId: string, args: Object): ActionValidationResult {
    return validateRegisteredPageActionArgs(actionId, args);
  }
}

class CanarySurfaceAuthorizer implements SurfaceActionAuthorizer {
  private readonly hotel: HotelSurfaceAuthority;

  constructor(hotel: HotelSurfaceAuthority) {
    this.hotel = hotel;
  }

  allows(
    conversationId: string,
    turnId: string,
    surfaceId: string,
    actionId: string,
    args: Object
  ): boolean {
    return this.hotel.allows(conversationId, turnId, surfaceId, actionId, args);
  }
}

function isSuccessfulRegisteredActionTerminal(surface: A2uiSurfaceState): boolean {
  try {
    const model = JSON.parse(surface.dataModelJson) as A2uiRuntimeDataModel;
    return model.summary.text === '操作状态：success' &&
      model.summary.toolName === 'action' &&
      model.summary.dataLabel === 'actionStatus' &&
      model.summary.count === 0;
  } catch (_error) {
    return false;
  }
}

function gmailDraftApplySurfaceBinding(
  snapshot: RegisteredPageSnapshot | null,
  currentHost: A2uiSurfaceState | null
): GmailDraftApplySurfaceBinding | null {
  const surfaceGeneration = snapshot === null ? 0 : snapshot.surface.runtimeGeneration;
  if (snapshot === null || currentHost === null ||
    !Number.isSafeInteger(snapshot.generation) || snapshot.generation <= 0 ||
    typeof surfaceGeneration !== 'number' ||
    !Number.isSafeInteger(surfaceGeneration) || surfaceGeneration <= 0 ||
    snapshot.surface.runtimeOwner !== 'multi_agent' ||
    currentHost.runtimeOwner !== 'multi_agent' ||
    currentHost.runtimeGeneration !== surfaceGeneration ||
    snapshot.surface.surfaceId !== currentHost.surfaceId ||
    snapshot.document.surfaceId !== snapshot.surface.surfaceId ||
    snapshot.document.generatedAt.trim().length === 0 ||
    (registeredPageSourceToolId(snapshot.surface) !== 'gmail.draft.create' &&
      !isSuccessfulRegisteredActionTerminal(snapshot.surface))) {
    return null;
  }
  const currentHostSnapshot: RegisteredPageSnapshot = {
    surface: currentHost,
    document: snapshot.document,
    generation: snapshot.generation
  };
  if (registeredPageSnapshotFingerprint(currentHostSnapshot) !==
    registeredPageSnapshotFingerprint(snapshot)) {
    return null;
  }
  const candidates: A2uiAction[] = [];
  const append = (
    id: string,
    label: string,
    prompt: string,
    variant: string,
    kind: string,
    args: Object | undefined
  ): void => {
    if (id !== 'gmail.draft.apply' || args === undefined) {
      return;
    }
    const clicked: A2uiAction = { id, label, prompt, variant, kind, args };
    if (!isHtmlHomeActionAllowed(snapshot.document, clicked)) {
      return;
    }
    const route = resolveRegisteredPageAction('gmail.draft.create', clicked);
    if (route !== null && route.pageActionId === 'gmail.draft.apply' &&
      route.action.id === 'gmail.draft.apply' && route.action.args !== undefined) {
      candidates.push(route.action);
    }
  };
  snapshot.document.actions.forEach((candidate) => {
    append(
      candidate.id, candidate.label, candidate.prompt,
      candidate.variant, candidate.kind, candidate.args
    );
  });
  snapshot.document.blocks.forEach((block) => {
    block.actions.forEach((candidate) => {
      append(
        candidate.id, candidate.label, candidate.prompt,
        candidate.variant, candidate.kind, candidate.args
      );
    });
  });
  if (candidates.length !== 1) {
    return null;
  }
  const actionJson = JSON.stringify(candidates[0]);
  return {
    action: candidates[0],
    actionJson,
    runtimeGeneration: surfaceGeneration,
    surface: JSON.parse(JSON.stringify(currentHost)) as A2uiSurfaceState,
    surfaceId: snapshot.surface.surfaceId,
    surfaceStatus: snapshot.surface.status
  };
}

function isSuccessfulGmailDraftTerminalTransition(
  providerSurface: A2uiSurfaceState,
  terminalSurface: A2uiSurfaceState
): boolean {
  if (terminalSurface.sequence !== providerSurface.sequence + 1) {
    return false;
  }
  let providerModel: A2uiRuntimeDataModel;
  let terminalModel: A2uiRuntimeDataModel;
  try {
    providerModel = JSON.parse(providerSurface.dataModelJson) as A2uiRuntimeDataModel;
    terminalModel = JSON.parse(terminalSurface.dataModelJson) as A2uiRuntimeDataModel;
  } catch (_error) {
    return false;
  }
  if (providerModel.summary.dataLabel === 'actionStatus' ||
    !isSuccessfulRegisteredActionTerminal(terminalSurface)) {
    return false;
  }
  terminalModel.summary = providerModel.summary;
  const normalizedTerminal = JSON.parse(JSON.stringify(terminalSurface)) as A2uiSurfaceState;
  normalizedTerminal.sequence = providerSurface.sequence;
  normalizedTerminal.dataModelJson = JSON.stringify(terminalModel);
  const normalizedProvider = JSON.parse(JSON.stringify(providerSurface)) as A2uiSurfaceState;
  normalizedProvider.dataModelJson = JSON.stringify(providerModel);
  return JSON.stringify(normalizedTerminal) === JSON.stringify(normalizedProvider);
}

function gmailDraftCreateOutputCandidate(
  result: ActionExecutionResult,
  context: ActionExecutionContext,
  originalArgs: Object,
  runtimeGeneration: number
): GmailDraftApplyCandidate | null {
  if (result.status !== 'success' || result.output === undefined ||
    result.output === null || typeof result.output !== 'object' || Array.isArray(result.output) ||
    !Number.isSafeInteger(runtimeGeneration) || runtimeGeneration <= 0 ||
    !validateRegisteredPageActionArgs('gmail.draft.create', originalArgs).ok) {
    return null;
  }
  const output = result.output as GmailDraftOutputRecord;
  const data = output['data'];
  if (output['actionId'] !== 'gmail.draft.create' ||
    output['pageActionId'] !== 'gmail.draft.create' ||
    output['conversationId'] !== context.conversationId ||
    output['turnId'] !== context.turnId ||
    typeof output['surfaceId'] !== 'string' ||
    (output['surfaceId'] as string).trim().length === 0 ||
    typeof output['status'] !== 'string' ||
    data === null || data === undefined || typeof data !== 'object' || Array.isArray(data)) {
    return null;
  }
  const model = data as A2uiRuntimeDataModel;
  if (!Array.isArray(model.genericToolResults) || model.genericToolResults.length !== 1 ||
    model.genericToolResults[0].status !== 'success') {
    return null;
  }
  const candidate = gmailDraftApplyAction(
    model.genericToolResults[0] as DynamicGenericToolResult,
    originalArgs
  );
  if (candidate === null || candidate.args === undefined ||
    !validateRegisteredPageActionArgs('gmail.draft.apply', candidate.args).ok) {
    return null;
  }
  const route = resolveRegisteredPageAction('gmail.draft.create', candidate);
  if (route === null || route.pageActionId !== 'gmail.draft.apply' ||
    route.action.id !== 'gmail.draft.apply' || route.action.args === undefined ||
    !validateRegisteredPageActionArgs('gmail.draft.apply', route.action.args).ok) {
    return null;
  }
  return {
    actionJson: JSON.stringify(route.action),
    runtimeGeneration,
    surfaceId: (output['surfaceId'] as string).trim(),
    surfaceStatus: (output['status'] as string).trim()
  };
}

function exactCurrentGmailDraftApplyAction(
  authority: GmailDraftApplySurfaceBinding | null,
  currentHost: A2uiSurfaceState | null,
  hostGeneration: number
): A2uiAction | null {
  if (authority === null || currentHost === null ||
    hostGeneration !== authority.runtimeGeneration + 1 ||
    (JSON.stringify(currentHost) !== JSON.stringify(authority.surface) &&
      !isSuccessfulGmailDraftTerminalTransition(authority.surface, currentHost))) {
    return null;
  }
  return authority.action;
}

class CanaryVirtualActionIntentResolver implements VirtualActionIntentResolver {
  private readonly currentGmailDraftApply: () => A2uiAction | null;

  constructor(currentGmailDraftApply: () => A2uiAction | null) {
    this.currentGmailDraftApply = currentGmailDraftApply;
  }

  async resolve(request: ActionPlanRequestPayload): Promise<VirtualActionIntent | null> {
    if (request.virtual !== true || request.dataTaskIds.length !== 0 ||
      request.allowedActionIds.length !== 1 ||
      request.personaId === undefined || request.inputText === undefined) {
      return null;
    }
    const actionId = request.allowedActionIds[0];
    let action: A2uiAction | null = null;
    if (actionId === 'gmail.draft.apply') {
      action = request.inputText.trim() === '确认应用刚才的 Gmail 草稿' ?
        this.currentGmailDraftApply() : null;
    } else {
      const now: Date | null = calendarNow(request.currentLocalDate);
      if (now === null) return null;
      action = resolveVirtualRegisteredPageAction(actionId, request.inputText, now);
    }
    if (action === null || action.args === undefined) return null;
    const offer: ActionOffer = {
      offerId: 'initial-action:' + actionId,
      actionId: actionId,
      label: actionId,
      variant: 'primary',
      args: action.args
    };
    return { sourceToolId: VIRTUAL_ACTION_INTENT_SOURCE_TOOL_ID, offer, autoRun: true };
  }
}

const rejectPageAction: RegisteredPageAction = async (
  _actionId: string,
  _args: Object,
  _context: ActionExecutionContext
): Promise<ActionExecutionResult> => ({
  status: 'error',
  errorCode: 'ACTION_PAGE_ROUTE_UNAVAILABLE',
  message: 'Registered page action is unavailable.'
});

class CanaryRegisteredExecutor implements RegisteredActionExecutor {
  private readonly aiphone: AiphoneRegisteredActionExecutor;
  private readonly onSurface: (surface: A2uiSurfaceState, context: ActionExecutionContext) => void;
  private readonly currentGmailDraftApply: () => A2uiAction | null;
  private sequence: number = 0;

  constructor(
    aiphone: AiphoneRegisteredActionExecutor,
    onSurface: (surface: A2uiSurfaceState, context: ActionExecutionContext) => void,
    currentGmailDraftApply: () => A2uiAction | null
  ) {
    this.aiphone = aiphone;
    this.onSurface = onSurface;
    this.currentGmailDraftApply = currentGmailDraftApply;
  }

  async execute(
    actionId: string,
    args: Object,
    context: ActionExecutionContext
  ): Promise<ActionExecutionResult> {
    if (actionId === 'calendar.event.create' && context.virtualAction === true) {
      this.sequence++;
      const surfaceId = 'calendar-review:' + this.sequence.toString();
      const surface = calendarReviewSurface(surfaceId, actionId, args);
      if (surface === null) {
        return {
          status: 'error',
          errorCode: 'CALENDAR_REVIEW_RENDER_FAILED',
          message: 'Calendar review surface could not be rendered.'
        };
      }
      this.onSurface(surface, context);
      const output: CalendarReviewOutput = { surfaceId };
      return { status: 'success', output };
    }
    if (actionId === 'gmail.draft.apply' && context.virtualAction === true) {
      const current = this.currentGmailDraftApply();
      if (current === null || current.args === undefined ||
        JSON.stringify(current.args) !== JSON.stringify(args)) {
        return {
          status: 'error',
          errorCode: 'GMAIL_DRAFT_SURFACE_STALE',
          message: 'Gmail draft no longer matches the exact current surface.'
        };
      }
    }
    return this.aiphone.execute(actionId, args, context);
  }
}

class PhoneLocalLeaderMemoryToolExecutor implements LeaderMemoryToolExecutor,
  LeaderMemoryRecallToolExecutor {
  private readonly runtime: PhoneLocalMemoryRuntimePort | null;
  private readonly recallObserver: ((
    request: LeaderMemoryRecallToolRequest,
    observation: MemoryRecallObservation
  ) => void) | null;

  constructor(
    runtime: PhoneLocalMemoryRuntimePort | null,
    recallObserver?: (
      request: LeaderMemoryRecallToolRequest,
      observation: MemoryRecallObservation
    ) => void
  ) {
    this.runtime = runtime;
    this.recallObserver = recallObserver === undefined ? null : recallObserver;
  }

  async recall(
    request: LeaderMemoryRecallToolRequest,
    guard: LeaderMemoryToolExecutionGuard
  ): Promise<MemoryRecallObservation> {
    if (!guard.isActive() || this.runtime === null) {
      return this.observedRecall(request, 'error', []);
    }
    try {
      const recalled: PhoneLocalRecalledMemory[] = await this.runtime.recall(request.query, request.topK);
      if (!guard.isActive()) return this.observedRecall(request, 'error', []);
      return this.observedRecall(
        request,
        recalled.length === 0 ? 'empty' : 'success',
        recalled
      );
    } catch (_error) {
      return this.observedRecall(request, 'error', []);
    }
  }

  private observedRecall(
    request: LeaderMemoryRecallToolRequest,
    status: 'success' | 'empty' | 'error',
    recalled: PhoneLocalRecalledMemory[]
  ): MemoryRecallObservation {
    const observation: MemoryRecallObservation = this.recallObservation(request, status, recalled);
    const observer = this.recallObserver;
    if (observer !== null) {
      try {
        observer(request, observation);
      } catch (_error) {
        // Observation bookkeeping must never turn a read-only recall into a turn failure.
      }
    }
    return observation;
  }

  private recallObservation(
    request: LeaderMemoryRecallToolRequest,
    status: 'success' | 'empty' | 'error',
    recalled: PhoneLocalRecalledMemory[]
  ): MemoryRecallObservation {
    const items: MemoryRecallItem[] = [];
    let remaining: number = memoryRecallTotalMaxChars(request.topK);
    for (let index = 0; index < recalled.length && items.length < request.topK && remaining > 0; index++) {
      const memory: PhoneLocalRecalledMemory = recalled[index];
      const fact: string = memory.fact.substring(0, Math.min(MEMORY_RECALL_FACT_MAX_CHARS, remaining));
      if (fact.length === 0) break;
      items.push({
        memoryId: memory.memoryId,
        fact,
        personaTag: memory.personaTag,
        authority: memory.authority
      });
      remaining -= fact.length;
    }
    return {
      callId: request.callId,
      origin: request.origin,
      query: request.query.substring(0, MEMORY_RECALL_OBSERVATION_QUERY_MAX_CHARS),
      status: status === 'success' && items.length === 0 ? 'empty' : status,
      items
    };
  }

  async execute(
    request: LeaderMemoryToolRequest,
    guard: LeaderMemoryToolExecutionGuard
  ): Promise<LeaderMemoryToolResult> {
    if (!guard.isActive()) {
      return this.result(request, 'error', 'Long-term memory operation was canceled.', 0, 0);
    }
    if (this.runtime === null) {
      return this.result(request, 'error', 'Long-term memory is unavailable on this device.', 0, 1);
    }
    const commitGuard: MemoryCommitGuard = new LeaderMemoryCommitGuard(guard);
    const mutation: LeaderMemoryMutation = request.mutation;
    if (mutation.operation === 'remember') {
      const facts: string[] = mutation.facts.map((item): string => item.fact);
      const result: MemoryBatchResult = await this.runtime.remember(
        facts, request.turnId, request.personaId, commitGuard
      );
      if (result.succeededCount <= 0 || result.status === 'error') {
        return this.result(
          request,
          'error',
          result.error === undefined ? 'Long-term memory could not be saved.' : result.error.message,
          result.succeededCount,
          result.failedCount
        );
      }
      if (result.failedCount > 0) {
        return this.result(
          request,
          'partial',
          '已记住 ' + result.succeededCount.toString() + ' 条，' +
            result.failedCount.toString() + ' 条保存失败。',
          result.succeededCount,
          result.failedCount
        );
      }
      return this.result(
        request,
        'success',
        '已记住 ' + result.succeededCount.toString() + ' 条长期记忆。',
        result.succeededCount,
        result.failedCount
      );
    }
    const result: MemoryWriteResult = mutation.operation === 'update' ?
      await this.runtime.update(
        mutation.memoryId, mutation.fact, request.turnId, request.personaId, commitGuard
      ) : await this.runtime.forget(mutation.memoryId, commitGuard);
    if (result.status === 'error') {
      return this.result(
        request,
        'error',
        result.error === undefined ? 'Long-term memory could not be changed.' : result.error.message,
        0,
        1
      );
    }
    return this.result(
      request,
      'success',
      mutation.operation === 'update' ? '已更新长期记忆。' : '已忘记这条长期记忆。',
      1,
      0
    );
  }

  private result(
    request: LeaderMemoryToolRequest,
    status: 'success' | 'partial' | 'error',
    message: string,
    succeeded: number,
    failed: number
  ): LeaderMemoryToolResult {
    aiLogInfo('[AIPhone][LeaderMemoryTool] conversation=' + request.conversationId +
      ' turn=' + request.turnId + ' task=' + request.sourceTaskId +
      ' operation=' + request.mutation.operation + ' status=' + status +
      ' succeeded=' + succeeded.toString() + ' failed=' + failed.toString());
    return { status, message };
  }
}

class LeaderMemoryCommitGuard implements MemoryCommitGuard {
  private readonly leaderGuard: LeaderMemoryToolExecutionGuard;

  constructor(leaderGuard: LeaderMemoryToolExecutionGuard) {
    this.leaderGuard = leaderGuard;
  }

  isActive(): boolean {
    return this.leaderGuard.isActive();
  }
}

class CallbackMemoryCommitGuard implements MemoryCommitGuard {
  private readonly active: () => boolean;

  constructor(active: () => boolean) {
    this.active = active;
  }

  isActive(): boolean {
    return this.active();
  }
}

class AlwaysActiveLeaderMemoryToolExecutionGuard implements LeaderMemoryToolExecutionGuard {
  isActive(): boolean {
    return true;
  }
}

function canaryPlanningContext(
  previousPersonaId: string,
  _prompt: string = '',
  allowTrustedOperationTargets: boolean = false,
  focusedRelease: boolean = false,
  memoryAvailable: boolean = true
): LeaderPlanningContext {
  const definitions: ToolDefinition[] = focusedRelease ? allAiphoneToolDefinitions() : allToolDefinitions();
  const tools: LeaderToolMetadata[] = definitions
    .filter((definition: ToolDefinition): boolean =>
      definition.toolId !== 'gmail.message.send' &&
        definition.toolId !== 'social.reply.draft' &&
        definition.toolId !== 'hotel.navigate' &&
        definition.toolId !== 'hotel.booking.open' &&
        (!focusedRelease ||
          (definition.toolId !== 'web.research.search' &&
            definition.toolId !== 'web.page.read' &&
            definition.toolId !== 'media.aggregate.search'))
    )
    .map(
    (definition: ToolDefinition): LeaderToolMetadata => {
      const actions = definition.actions.filter(
        (actionId: string): boolean => toolDefinitionForToolId(actionId) !== null
      );
      return {
        toolId: definition.toolId,
        domain: definition.domain,
        intent: definition.intent,
        riskLevel: definition.riskLevel,
        registeredBackends: definition.backendPriority.slice(),
        inputSchema: definition.inputSchema,
        outputSchema: definition.outputSchema,
        actions,
        planningHint: toolPlanningDescriptionForToolId(definition.toolId, allowTrustedOperationTargets)
      };
    }
  );
  if (!focusedRelease) {
    tools.push({
      toolId: 'dynamic.search',
      domain: 'dynamic',
      intent: 'dynamic.search',
      riskLevel: 'read',
      registeredBackends: ['mcp_remote', 'oauth_api'],
      inputSchema: 'dynamicToolSearchQuery',
      outputSchema: 'dynamicToolConnect',
      actions: [],
      planningHint: toolPlanningDescriptionForToolId('dynamic.search', allowTrustedOperationTargets)
    });
  }
  for (let index = 0; memoryAvailable && index < MEMORY_ACTION_IDS.length; index += 1) {
    tools.push({
      toolId: MEMORY_ACTION_IDS[index],
      domain: 'memory',
      intent: MEMORY_ACTION_IDS[index],
      riskLevel: 'draft',
      registeredBackends: ['local_adapter'],
      inputSchema: 'leaderMemoryMutation',
      outputSchema: 'leaderMemoryToolResult',
      actions: [],
      planningHint: memoryPlanningHint(MEMORY_ACTION_IDS[index])
    });
  }
  return {
    tools,
    personas: scopedLeaderPersonas(previousPersonaId, tools, memoryAvailable)
  };
}

function instructionsWithoutMemoryCapabilityIds(value: string): string {
  return value.split('\n').filter((line: string): boolean =>
    MEMORY_ACTION_IDS.every((toolId: string): boolean => line.indexOf(toolId) < 0) &&
      line.indexOf('memory.recall') < 0
  ).join('\n');
}

function scopedLeaderPersonas(
  previousPersonaId: string,
  tools: LeaderToolMetadata[],
  memoryAvailable: boolean = true
): LeaderPersonaMetadata[] {
  const visibleToolIds: Set<string> = new Set<string>();
  for (let index = 0; index < tools.length; index++) {
    visibleToolIds.add(tools[index].toolId);
  }
  return leaderPersonaContext(previousPersonaId).map((persona: LeaderPersonaMetadata): LeaderPersonaMetadata => ({
    personaId: persona.personaId,
    name: persona.name,
    domains: persona.domains.slice(),
    previous: persona.previous,
    activeSkills: persona.activeSkills.map((skill: LeaderSkillMetadata): LeaderSkillMetadata => ({
      skillId: skill.skillId,
      description: skill.description,
      instructions: memoryAvailable ? skill.instructions :
        instructionsWithoutMemoryCapabilityIds(skill.instructions),
      status: skill.status,
      toolIds: memoryAvailable ? skill.toolIds.slice() : skill.toolIds.filter(
        (toolId: string): boolean => MEMORY_ACTION_IDS.indexOf(toolId) < 0
      )
    })).filter((skill: LeaderSkillMetadata): boolean =>
      skill.toolIds.every((toolId: string): boolean => visibleToolIds.has(toolId))
    )
  }));
}

export function rememberedPersonaAfterOutcome(
  currentPersonaId: string,
  outcome: MultiAgentTurnOutcome,
  isLatestSubmission: boolean
): string {
  if (!isLatestSubmission ||
    outcome.kind !== 'settled' ||
    (outcome.status !== 'success' && outcome.status !== 'partial' && outcome.status !== 'empty') ||
    outcome.personaId.trim().length === 0) {
    return currentPersonaId;
  }
  return outcome.personaId;
}

export class MultiAgentCanaryRuntime {
  private readonly runtime: MultiAgentRuntime;
  private readonly memoryRuntime: PhoneLocalMemoryRuntimePort | null;
  private readonly memoryAvailable: boolean;
  private readonly authority: HotelSurfaceAuthority;
  private readonly followUpIds: PreparedHotelFollowUpIds;
  private readonly surfaceWriter: HotelRuntimeSurfaceWriter;
  private readonly conversationId: string;
  private readonly aiphoneExecutor: AiphoneRegisteredActionExecutor;
  private readonly mailDetailBridge: MailDetailInPlaceBridge;
  private readonly currentPageSnapshot: () => RegisteredPageSnapshot | null;
  private readonly currentHostSurface: () => A2uiSurfaceState | null;
  private readonly currentHostGeneration: () => number;
  private readonly onHostSurface: (surface: A2uiSurfaceState, runtimeGeneration: number) => boolean;
  private readonly turnHostGenerations: Map<string, number> = new Map<string, number>();
  private readonly validOriginTurnIds: Set<string> = new Set<string>();
  private readonly turnHostGenerationOrder: string[] = [];
  private pageGeneration: number = 0;
  private pageFingerprint: string = '';
  private gmailDraftApplyCandidate: GmailDraftApplyCandidate | null = null;
  private pendingMemoryForgetSelection: PendingMemoryForgetSelection | null = null;
  private readonly manualRecallItemsBySourceTaskId: Map<string, RecalledMemoryContext[]> =
    new Map<string, RecalledMemoryContext[]>();
  private memorySelectionSequence: number = 0;
  private surfaceGeneration: number = 0;
  private lastLeaderPersonaId: string = '';
  private submissionSequence: number = 0;
  private hotelDetailAdmissionSequence: number = 0;
  private lastHotelDetailAdmissionRunId: string = '';

  constructor(options: MultiAgentCanaryOptions) {
    const conversationId: string = options.conversationId === undefined ?
      'aiphone-canary-' + Date.now().toString() : options.conversationId;
    this.conversationId = conversationId;
    this.memoryAvailable = options.memoryAvailability === undefined ? true :
      options.memoryAvailability.isAvailable();
    this.memoryRuntime = this.memoryAvailable && options.memoryRuntime !== undefined ?
      options.memoryRuntime : null;
    this.onHostSurface = options.onSurface;
    this.currentPageSnapshot = options.currentPageSnapshot === undefined ?
      (): RegisteredPageSnapshot | null => null : options.currentPageSnapshot;
    this.currentHostSurface = options.currentHostSurface === undefined ?
      (): A2uiSurfaceState | null => {
        const snapshot = this.currentPageSnapshot();
        return snapshot === null ? null : snapshot.surface;
      } : options.currentHostSurface;
    this.currentHostGeneration = options.currentHostGeneration === undefined ?
      (): number => {
        const current = this.currentHostSurface();
        return current === null || current.runtimeGeneration === undefined ?
          0 : current.runtimeGeneration;
      } : options.currentHostGeneration;
    const currentGmailDraftApply = (): A2uiAction | null =>
      this.currentGmailDraftApplyAction();
    const ids = new MonotonicHotelIds();
    const followUpIds = new PreparedHotelFollowUpIds(ids);
    this.followUpIds = followUpIds;
    this.authority = new HotelSurfaceAuthority();
    const visibility = new HotelVisibility();
    const onOwnedSurface = (
      surface: A2uiSurfaceState,
      _generation: number,
      turnId: string
    ): boolean => {
      const hostGeneration = this.turnHostGenerations.get(turnId);
      if (hostGeneration === undefined || hostGeneration <= 0) {
        return false;
      }
      surface.runtimeOwner = 'multi_agent';
      surface.runtimeGeneration = hostGeneration;
      return options.onSurface(surface, hostGeneration);
    };
    const lookup = new CanaryToolLookup();
    const catalog = new ActionCatalog(
      lookup,
      new CanarySurfaceAuthorizer(this.authority),
      new RejectClientAction(),
      new CanaryArgsValidator()
    );
    const writer = new HotelRuntimeSurfaceWriter(
      conversationId,
      options.downstreamWriter === undefined ?
        new IgnoreHotelSurfaceWriter() : options.downstreamWriter,
      onOwnedSurface,
      this.authority,
      visibility,
      true,
      options.surfaceDocumentProjector,
      options.a2uiParserProfile
    );
    this.surfaceWriter = writer;
    const structuredRenderer = new StructuredToolUiRenderer(
      options.uiLayoutPlanner === undefined ? null : options.uiLayoutPlanner,
      6000
    );
    const primaryRenderer: UiTaskRenderer = options.uiRenderer === undefined ?
      structuredRenderer : options.uiRenderer;
    const mailDetailBridge = new MailDetailInPlaceBridge(
      primaryRenderer,
      writer,
      this.currentHostGeneration,
      options.onMailDetail
    );
    this.mailDetailBridge = mailDetailBridge;
    const configuredPageAction: RegisteredPageAction = options.pageAction === undefined ?
      rejectPageAction : options.pageAction;
    const pageAction: RegisteredPageAction = async (
      actionId: string,
      args: Object,
      context: RegisteredPageActionContext
    ): Promise<ActionExecutionResult> => {
      const originHostGeneration = this.turnHostGenerations.get(context.turnId);
      const currentHostGeneration = this.currentHostGeneration();
      if (!this.validOriginTurnIds.has(context.turnId) || originHostGeneration === undefined ||
        !Number.isSafeInteger(originHostGeneration) || originHostGeneration <= 0 ||
        !Number.isSafeInteger(currentHostGeneration) || currentHostGeneration <= 0 ||
        originHostGeneration !== currentHostGeneration) {
        return {
          status: 'error',
          errorCode: 'BIM_PAGE_ACTION_GENERATION_STALE',
          message: 'Page action no longer belongs to the current turn.'
        };
      }
      context.hostGeneration = originHostGeneration;
      if (actionId === 'gmail.draft.create') {
        this.gmailDraftApplyCandidate = null;
      }
      const result = await configuredPageAction(actionId, args, context);
      if (actionId === 'gmail.draft.create') {
        this.rememberGmailDraftApplyCandidate(result, context, args);
      }
      return result;
    };
    const aiphoneExecutor = new AiphoneRegisteredActionExecutor(
      catalog,
      options.opener,
      followUpIds,
      pageAction,
      mailDetailBridge
    );
    this.aiphoneExecutor = aiphoneExecutor;
    const allowTrustedOperationTargets = options.allowTrustedOperationTargets === true;
    const initialContext = canaryPlanningContext(
      this.lastLeaderPersonaId, '', allowTrustedOperationTargets, options.focusedRelease === true,
      this.memoryAvailable
    );
    const dataTaskInputNormalizer: LeaderDataTaskInputNormalizer = (
      input: InputUserPayload,
      task: LeaderDecisionDataTask,
      currentLocalDate: string
    ): Object => normalizeCanaryTaskInput(input, task, currentLocalDate);
    const leaderPlanner = new MultiAgentLeaderPlanner(
      options.model,
      undefined,
      dataTaskInputNormalizer
    );
    const leaderMemoryTools = new PhoneLocalLeaderMemoryToolExecutor(
      this.memoryRuntime,
      (
        request: LeaderMemoryRecallToolRequest,
        observation: MemoryRecallObservation
      ): void => this.recordManualRecallObservation(request, observation)
    );
    this.runtime = new MultiAgentRuntime({
      conversationId,
      bus: options.bus,
      planner: leaderPlanner,
      planningContext: initialContext,
      planningContextProvider: (prompt: string): LeaderPlanningContext =>
        canaryPlanningContext(
          this.lastLeaderPersonaId, prompt, allowTrustedOperationTargets, options.focusedRelease === true,
          this.memoryAvailable
        ),
      currentLocalDateProvider: options.currentLocalDate,
      dataTaskInputNormalizer,
      dataAuthorizer: authorizeCanaryDataTask,
      dataPlanner: options.dataPlanner,
      dataExecutor: options.dataExecutor === undefined ?
        new CanaryStructuredDataExecutor(options.structuredToolCall) : options.dataExecutor,
      uiRenderer: mailDetailBridge,
      surfaceWriter: mailDetailBridge,
      actionCatalog: catalog,
      actionCompiler: new MultiAgentActionPlanCompiler(options.model),
      actionExecutor: new CanaryRegisteredExecutor(
        aiphoneExecutor,
        (surface: A2uiSurfaceState, context: ActionExecutionContext): void => {
          const hostGeneration = this.turnHostGenerations.get(context.turnId);
          if (hostGeneration === undefined || hostGeneration <= 0) {
            return;
          }
          let nextSurface: A2uiSurfaceState = surface;
          const current: A2uiSurfaceState | null = this.currentHostSurface();
          if (surface.intent === 'calendar' && current !== null && isMultiTaskSurface(current)) {
            let slotId: string = resolveMultiTaskSlotId(current, 'calendar.event.create');
            let composite: A2uiSurfaceState = current;
            if (slotId.length === 0) {
              composite = appendMultiTaskSlot(composite, 'calendar.event.create');
              slotId = resolveMultiTaskSlotId(composite, 'calendar.event.create');
            }
            nextSurface = mergeSurfaceIntoMultiTaskSurface(
              composite, slotId, 'calendar.event.create', surface, false
            );
          }
          nextSurface.runtimeOwner = 'multi_agent';
          nextSurface.runtimeGeneration = hostGeneration;
          options.onSurface(nextSurface, hostGeneration);
        },
        currentGmailDraftApply
      ),
      virtualActionResolver: new CanaryVirtualActionIntentResolver(currentGmailDraftApply),
      memoryToolExecutor: this.memoryAvailable ? leaderMemoryTools : undefined,
      memoryRecallToolExecutor: this.memoryAvailable ? leaderMemoryTools : undefined,
      submitTimeoutMs: options.submitTimeoutMs,
      actionTimeoutMs: options.actionTimeoutMs,
      settingsFingerprint: options.settingsFingerprint,
      surfaceTurnActivator: (turnId: string, hostGeneration: number): void => {
        this.rememberTurnHostGeneration(turnId, hostGeneration);
        writer.activateAutomaticTurn(turnId);
      },
      directActionAdmission: (action: A2uiAction, context: ActionExecutionContext): boolean =>
        this.admitHotelDetailFollowUp(action, context),
      turnGenerationObserver: (turnId: string, hostGeneration: number): void => {
        this.rememberTurnHostGeneration(turnId, hostGeneration);
      }
    });
  }

  submit(
    text: string,
    context: UserInputPayload,
    hostGeneration: number = 0
  ): Promise<MultiAgentTurnOutcome> {
    const capturedGeneration = Number.isSafeInteger(hostGeneration) && hostGeneration > 0 ?
      hostGeneration : 0;
    this.manualRecallItemsBySourceTaskId.clear();
    this.pendingMemoryForgetSelection = null;
    if (capturedGeneration > 0 &&
      capturedGeneration === this.currentHostGeneration() &&
      text.trim() !== '确认应用刚才的 Gmail 草稿') {
      this.gmailDraftApplyCandidate = null;
    }
    this.submissionSequence++;
    const submissionSequence: number = this.submissionSequence;
    if (!this.memoryAvailable) {
      const input: UserInputPayload = {
        text: context.text,
        recentMessages: context.recentMessages,
        sessionSummary: context.sessionSummary,
        lastTurnPersonaId: this.lastLeaderPersonaId,
        currentSurfaceSummary: context.currentSurfaceSummary,
        recentObservations: context.recentObservations
      };
      return this.runtime.submit(text, input, capturedGeneration)
        .then((outcome: MultiAgentTurnOutcome): MultiAgentTurnOutcome => {
          this.lastLeaderPersonaId = rememberedPersonaAfterOutcome(
            this.lastLeaderPersonaId,
            outcome,
            submissionSequence === this.submissionSequence
          );
          return outcome;
        });
    }
    let recalledForSubmission: RecalledMemoryContext[] = [];
    const recallStartedAt: number = Date.now();
    const guardRecallGeneration: boolean = this.memoryRuntime !== null && capturedGeneration > 0 &&
      capturedGeneration === this.currentHostGeneration();
    const prefetchQuery: string = originalQueryFromBimPrompt(text).trim();
    const prefetchRequest: LeaderMemoryRecallToolRequest = {
      callId: 'memory-recall-prefetch-' + submissionSequence.toString(),
      conversationId: this.conversationId,
      turnId: 'pending-' + submissionSequence.toString(),
      sourceTaskId: 'host-prefetch',
      origin: 'prefetch',
      query: prefetchQuery,
      topK: MEMORY_RECALL_DEFAULT_TOP_K
    };
    const recallExecutor = new PhoneLocalLeaderMemoryToolExecutor(this.memoryRuntime);
    const emptyObservation: MemoryRecallObservation = {
      callId: prefetchRequest.callId,
      origin: 'prefetch',
      query: prefetchQuery.substring(0, MEMORY_RECALL_OBSERVATION_QUERY_MAX_CHARS),
      status: 'empty',
      items: []
    };
    const recallGuard: LeaderMemoryToolExecutionGuard = new AlwaysActiveLeaderMemoryToolExecutionGuard();
    const recall: Promise<MemoryRecallObservation> = prefetchQuery.length === 0 ?
      Promise.resolve(emptyObservation) : recallExecutor.recall(prefetchRequest, recallGuard);
    return recall.then((observation: MemoryRecallObservation): Promise<MultiAgentTurnOutcome> => {
      if (submissionSequence !== this.submissionSequence ||
        (guardRecallGeneration && capturedGeneration !== this.currentHostGeneration())) {
        aiLogInfo('[AIPhone][LeaderMemoryRecall] status=canceled count=0 durationMs=' +
          Math.max(0, Date.now() - recallStartedAt).toString());
        const canceled: MultiAgentSettledOutcome = {
          kind: 'settled',
          ok: false,
          status: 'canceled',
          surfaceId: '',
          message: 'Memory recall no longer belongs to the current turn.',
          personaId: this.lastLeaderPersonaId,
          skillId: ''
        };
        return Promise.resolve(canceled);
      }
      aiLogInfo('[AIPhone][LeaderMemoryRecall] status=' + observation.status +
        ' count=' + observation.items.length.toString() + ' durationMs=' +
        Math.max(0, Date.now() - recallStartedAt).toString());
      const input: UserInputPayload = {
        text: context.text,
        recentMessages: context.recentMessages,
        sessionSummary: context.sessionSummary,
        recalledMemories: observation.items.map((memory: MemoryRecallItem): RecalledMemoryContext => ({
          memoryId: memory.memoryId,
          fact: memory.fact,
          personaTag: memory.personaTag,
          authority: memory.authority
        })),
        lastTurnPersonaId: this.lastLeaderPersonaId,
        memoryRecallObservation: observation,
        currentSurfaceSummary: context.currentSurfaceSummary,
        recentObservations: context.recentObservations
      };
      recalledForSubmission = input.recalledMemories === undefined ? [] : input.recalledMemories;
      return this.runtime.submit(text, input, capturedGeneration);
    })
      .then((outcome: MultiAgentTurnOutcome): MultiAgentTurnOutcome => {
        this.lastLeaderPersonaId = rememberedPersonaAfterOutcome(
          this.lastLeaderPersonaId,
          outcome,
          submissionSequence === this.submissionSequence
        );
        if (submissionSequence === this.submissionSequence && outcome.ok &&
          outcome.memorySelection !== undefined) {
          const manualRecalled = this.manualRecallItemsBySourceTaskId.get(
            outcome.memorySelection.sourceTaskId
          );
          const trustedRecalled: RecalledMemoryContext[] = manualRecalled === undefined ?
            recalledForSubmission : manualRecalled;
          const surface = this.installMemoryForgetSelection(
            outcome.memorySelection, trustedRecalled, capturedGeneration
          );
          this.manualRecallItemsBySourceTaskId.delete(outcome.memorySelection.sourceTaskId);
          if (surface !== null) outcome.surfaceId = surface.surfaceId;
        }
        return outcome;
      });
  }

  private recordManualRecallObservation(
    request: LeaderMemoryRecallToolRequest,
    observation: MemoryRecallObservation
  ): void {
    if (request.origin !== 'leader' || request.sourceTaskId.trim().length === 0 ||
      observation.callId !== request.callId || observation.origin !== 'leader' ||
      observation.query !== request.query) {
      return;
    }
    const recalled: RecalledMemoryContext[] = observation.items.map(
      (item: MemoryRecallItem): RecalledMemoryContext => ({
        memoryId: item.memoryId,
        fact: item.fact,
        personaTag: item.personaTag,
        authority: item.authority
      })
    );
    this.manualRecallItemsBySourceTaskId.set(request.sourceTaskId, recalled);
  }

  private installMemoryForgetSelection(
    selection: MemorySelectionPayload,
    recalled: RecalledMemoryContext[],
    hostGeneration: number
  ): A2uiSurfaceState | null {
    if (selection.operation !== 'forget' || selection.originTurnId.trim().length === 0 ||
      selection.sourceTaskId.trim().length === 0 || selection.personaId.trim().length === 0 ||
      selection.candidates.length < 1 || selection.candidates.length > MEMORY_RECALL_MAX_TOP_K ||
      !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
      this.currentHostGeneration() !== hostGeneration ||
      this.turnHostGenerations.get(selection.originTurnId) !== hostGeneration ||
      !this.validOriginTurnIds.has(selection.originTurnId)) {
      aiLogInfo('[AIPhone][MemorySelection] operation=forget status=rejected reason=invalid_context');
      return null;
    }
    const pendingCandidates: PendingMemoryForgetCandidate[] = [];
    const surfaceCandidates: MemoryCandidateSelectionItem[] = [];
    const seenMemoryIds: Set<string> = new Set<string>();
    this.memorySelectionSequence++;
    const selectionId = 'memory-selection-' + this.memorySelectionSequence.toString() + '-' + Date.now().toString();
    for (let index = 0; index < selection.candidates.length; index++) {
      const candidate = selection.candidates[index];
      if (candidate.memoryId.trim().length === 0 || candidate.fact.trim().length === 0 ||
        candidate.fact.length > 240 || seenMemoryIds.has(candidate.memoryId)) {
        aiLogInfo('[AIPhone][MemorySelection] operation=forget status=rejected reason=invalid_candidate');
        return null;
      }
      let recalledCandidate: RecalledMemoryContext | null = null;
      for (let recalledIndex = 0; recalledIndex < recalled.length; recalledIndex++) {
        const item = recalled[recalledIndex];
        if (item.memoryId === candidate.memoryId && item.fact === candidate.fact &&
          item.personaTag === candidate.personaTag && item.authority === candidate.authority) {
          recalledCandidate = item;
          break;
        }
      }
      if (recalledCandidate === null) {
        aiLogInfo('[AIPhone][MemorySelection] operation=forget status=rejected reason=not_recalled');
        return null;
      }
      seenMemoryIds.add(candidate.memoryId);
      const candidateKey = 'candidate-' + (index + 1).toString() + '-' + this.memorySelectionSequence.toString();
      pendingCandidates.push({
        candidateKey,
        memoryId: recalledCandidate.memoryId,
        fact: recalledCandidate.fact,
        personaTag: recalledCandidate.personaTag,
        authority: recalledCandidate.authority
      });
      surfaceCandidates.push({
        candidateKey,
        fact: recalledCandidate.fact,
        personaTag: recalledCandidate.personaTag,
        authority: recalledCandidate.authority
      });
    }
    const surfaceId = 'memory-selection:' + selectionId;
    const surfaceInput: MemoryCandidateSelectionSurfaceInput = {
      selectionId,
      revision: 1,
      candidates: surfaceCandidates
    };
    const surface = memoryCandidateSelectionSurface(surfaceId, surfaceInput);
    surface.runtimeOwner = 'multi_agent';
    surface.runtimeGeneration = hostGeneration;
    const pending: PendingMemoryForgetSelection = {
      selectionId,
      conversationId: this.conversationId,
      originTurnId: selection.originTurnId,
      sourceTaskId: selection.sourceTaskId,
      personaId: selection.personaId,
      hostGeneration,
      surfaceId,
      revision: 1,
      deletedCount: 0,
      candidates: pendingCandidates,
      inFlight: false,
      consumed: false
    };
    this.pendingMemoryForgetSelection = pending;
    if (!this.onHostSurface(surface, hostGeneration)) {
      this.pendingMemoryForgetSelection = null;
      aiLogInfo('[AIPhone][MemorySelection] operation=forget status=rejected reason=surface_rejected');
      return null;
    }
    aiLogInfo('[AIPhone][MemorySelection] conversation=' + this.conversationId +
      ' turn=' + selection.originTurnId + ' task=' + selection.sourceTaskId +
      ' operation=forget status=shown count=' + pendingCandidates.length.toString());
    return surface;
  }

  async handleMemoryCandidateAction(action: A2uiAction): Promise<MemoryCandidateManagerActionResult> {
    if (action.id !== MEMORY_CANDIDATES_FORGET_ACTION_ID) {
      return {
        handled: false, status: 'rejected', message: '', presented: false, notify: false
      };
    }
    const args: MemoryCandidatesForgetActionArgs | null = memoryCandidatesForgetActionArgs(action);
    const pending = this.pendingMemoryForgetSelection;
    const currentPendingSurface: boolean = pending !== null && this.currentMemorySelectionSurface(pending);
    if (args === null || pending === null || !this.validMemoryManagerAction(
      pending, args.selectionId, args.revision
    )) {
      aiLogInfo('[AIPhone][MemorySelectionAction] operation=forget status=rejected action=delete');
      return {
        handled: true, status: 'rejected', message: '这张记忆管理卡已失效，请重新发起请求。',
        presented: currentPendingSurface, notify: currentPendingSurface
      };
    }
    const selected: PendingMemoryForgetCandidate[] = [];
    for (let keyIndex = 0; keyIndex < args.candidateKeys.length; keyIndex++) {
      const candidate = pending.candidates.find(
        (item: PendingMemoryForgetCandidate): boolean => item.candidateKey === args.candidateKeys[keyIndex]
      );
      if (candidate === undefined) {
        return {
          handled: true, status: 'rejected', message: '这张记忆管理卡已失效，请重新发起请求。',
          presented: currentPendingSurface, notify: currentPendingSurface
        };
      }
      selected.push(candidate);
    }
    if (selected.length === 0 || selected.length > 5 || this.memoryRuntime === null) {
      return {
        handled: true, status: 'rejected', message: '请先选择要删除的长期记忆。',
        presented: currentPendingSurface, notify: currentPendingSurface
      };
    }
    pending.inFlight = true;
    const guard: MemoryCommitGuard = new CallbackMemoryCommitGuard((): boolean =>
      this.pendingMemoryForgetSelection === pending && !pending.consumed && pending.inFlight &&
      this.currentHostGeneration() === pending.hostGeneration && this.currentMemorySelectionSurface(pending));
    const successfulKeys: Set<string> = new Set<string>();
    let failedCount: number = 0;
    for (let index = 0; index < selected.length; index++) {
      const result: MemoryWriteResult = await this.memoryRuntime.forget(selected[index].memoryId, guard);
      if (result.status === 'success') successfulKeys.add(selected[index].candidateKey);
      else failedCount++;
    }
    const succeededCount = successfulKeys.size;
    const stillCurrent: boolean = this.pendingMemoryForgetSelection === pending &&
      this.currentMemorySelectionSurface(pending);
    const logStatus = succeededCount === 0 ? 'error' : (failedCount > 0 ? 'partial' : 'success');
    aiLogInfo('[AIPhone][LeaderMemoryTool] conversation=' + pending.conversationId +
      ' turn=' + pending.originTurnId + ' task=' + pending.sourceTaskId +
      ' operation=forget status=' + logStatus + ' succeeded=' + succeededCount.toString() +
      ' failed=' + failedCount.toString());
    if (!stillCurrent) {
      pending.consumed = true;
      if (this.pendingMemoryForgetSelection === pending) this.pendingMemoryForgetSelection = null;
      return {
        handled: true,
        status: succeededCount === 0 ? 'rejected' : (failedCount > 0 ? 'partial' : 'success'),
        message: '这张记忆管理卡已失效，请重新发起请求。',
        presented: false,
        notify: false
      };
    }
    pending.inFlight = false;
    pending.deletedCount += succeededCount;
    if (succeededCount > 0) {
      pending.candidates = pending.candidates.filter(
        (candidate: PendingMemoryForgetCandidate): boolean => !successfulKeys.has(candidate.candidateKey)
      );
    }
    pending.revision++;
    let presented: boolean = false;
    if (pending.candidates.length === 0) {
      pending.consumed = true;
      this.pendingMemoryForgetSelection = null;
      const confirmation = memoryForgetConfirmationSurface(
        'memory-forget-confirmation:' + pending.selectionId,
        pending.deletedCount
      );
      confirmation.runtimeOwner = 'multi_agent';
      confirmation.runtimeGeneration = pending.hostGeneration;
      presented = this.onHostSurface(confirmation, pending.hostGeneration);
    } else {
      presented = this.publishPendingMemorySelection(pending);
      if (!presented) this.pendingMemoryForgetSelection = null;
    }
    const message = succeededCount === 0 ? '删除长期记忆失败，已选记录仍可重试。' :
      (failedCount > 0 ? '已删除 ' + succeededCount.toString() + ' 条，' +
        failedCount.toString() + ' 条失败，可重试。' :
        '已删除 ' + succeededCount.toString() + ' 条长期记忆。');
    return {
      handled: true,
      status: succeededCount === 0 ? 'error' : (failedCount > 0 ? 'partial' : 'success'),
      message,
      presented,
      notify: presented
    };
  }

  private validMemoryManagerAction(
    pending: PendingMemoryForgetSelection,
    selectionId: string,
    revision: number
  ): boolean {
    return !pending.consumed && !pending.inFlight && selectionId === pending.selectionId &&
      revision === pending.revision && pending.conversationId === this.conversationId &&
      this.currentHostGeneration() === pending.hostGeneration &&
      this.turnHostGenerations.get(pending.originTurnId) === pending.hostGeneration &&
      this.validOriginTurnIds.has(pending.originTurnId) && this.currentMemorySelectionSurface(pending);
  }

  private publishPendingMemorySelection(pending: PendingMemoryForgetSelection): boolean {
    const candidates: MemoryCandidateSelectionItem[] = pending.candidates.map(
      (candidate: PendingMemoryForgetCandidate): MemoryCandidateSelectionItem => ({
        candidateKey: candidate.candidateKey,
        fact: candidate.fact,
        personaTag: candidate.personaTag,
        authority: candidate.authority
      })
    );
    const surfaceInput: MemoryCandidateSelectionSurfaceInput = {
      selectionId: pending.selectionId,
      revision: pending.revision,
      candidates
    };
    const surface = memoryCandidateSelectionSurface(pending.surfaceId, surfaceInput);
    surface.runtimeOwner = 'multi_agent';
    surface.runtimeGeneration = pending.hostGeneration;
    return this.onHostSurface(surface, pending.hostGeneration);
  }

  private currentMemorySelectionSurface(pending: PendingMemoryForgetSelection): boolean {
    const current = this.currentHostSurface();
    return current !== null && current.runtimeOwner === 'multi_agent' &&
      current.runtimeGeneration === pending.hostGeneration && current.surfaceId === pending.surfaceId;
  }

  runAction(action: A2uiAction, context: MultiAgentCanaryActionContext): Promise<boolean> {
    if (action.id === 'hotel.detail' && !this.currentHotelDetailContext(context)) {
      return Promise.resolve(false);
    }
    const execution: ActionExecutionContext = {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId,
      planId: '',
      runId: '',
      stepId: '',
      pageActionId: context.pageActionId
    };
    const admissionSequence: number = this.hotelDetailAdmissionSequence;
    const actionResult = this.runtime.runAction(action, execution, this.currentHostGeneration());
    const ownerRunId: string = action.id === 'hotel.detail' &&
      this.hotelDetailAdmissionSequence !== admissionSequence ? this.lastHotelDetailAdmissionRunId : '';
    return actionResult
      .then((ok: boolean): boolean => {
        if (action.id === 'hotel.detail' && !ok && ownerRunId.length > 0) {
          this.authority.clearHotelDetailFollowUp(ownerRunId);
        }
        this.mailDetailBridge.actionSettled(ok);
        return ok;
      });
  }

  runPageAction(
    clicked: A2uiAction
  ): Promise<boolean> {
    const snapshot = this.currentPageSnapshot();
    const currentHost = this.currentHostSurface();
    const hostGeneration = this.currentHostGeneration();
    if (snapshot === null || currentHost === null) {
      return Promise.resolve(false);
    }
    const surface = snapshot.surface;
    const document = snapshot.document;
    const generation = snapshot.generation;
    if (!Number.isSafeInteger(generation) || generation <= 0 ||
      !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
      surface.runtimeOwner !== 'multi_agent' || currentHost.runtimeOwner !== 'multi_agent' ||
      surface.runtimeGeneration !== hostGeneration ||
      currentHost.runtimeGeneration !== hostGeneration ||
      currentHost.surfaceId !== surface.surfaceId ||
      surface.surfaceId.trim().length === 0 || clicked.args === undefined ||
      document.surfaceId === undefined || document.surfaceId !== surface.surfaceId ||
      document.generatedAt.trim().length === 0 ||
      !isHtmlHomeActionAllowed(document, clicked)) {
      return Promise.resolve(false);
    }
    const sourceToolId = registeredPageActionSourceToolId(surface, document, clicked);
    const route = resolveRegisteredPageAction(sourceToolId, clicked);
    if (route === null || route.action.args === undefined) {
      return Promise.resolve(false);
    }
    const fingerprint = registeredPageSnapshotFingerprint(snapshot);
    if (generation < this.pageGeneration ||
      (generation === this.pageGeneration && fingerprint !== this.pageFingerprint)) {
      return Promise.resolve(false);
    }
    if (generation > this.pageGeneration) {
      this.pageGeneration = generation;
      this.pageFingerprint = fingerprint;
    }
    const turnId = 'page-turn-' + generation.toString();
    this.rememberTurnHostGeneration(turnId, hostGeneration);
    this.authority.activate(
      this.conversationId,
      turnId,
      surface.surfaceId,
      sourceToolId,
      document,
      route.action
    );
    const context: MultiAgentCanaryActionContext = {
      conversationId: this.conversationId,
      turnId,
      surfaceId: surface.surfaceId,
      sourceToolId,
      pageActionId: route.pageActionId
    };
    return this.runAction(route.action, context);
  }

  currentActionContext(action?: A2uiAction): MultiAgentCanaryActionContext | null {
    const context = action !== undefined && action.args !== undefined ?
      this.authority.contextFor(action.id, action.args) : this.authority.context();
    if (context === null) {
      return null;
    }
    return {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId
    };
  }

  cancelActiveTurn(reason: string): void {
    this.runtime.cancelActiveTurn(reason);
  }

  restoreSearchSurface(): boolean {
    return this.surfaceWriter.restoreLatestSearchSurface();
  }

  dispose(): void {
    this.submissionSequence++;
    this.runtime.dispose();
    this.aiphoneExecutor.dispose();
    this.mailDetailBridge.dispose();
    this.pageGeneration = 0;
    this.pageFingerprint = '';
    this.gmailDraftApplyCandidate = null;
    this.pendingMemoryForgetSelection = null;
    this.manualRecallItemsBySourceTaskId.clear();
    this.surfaceGeneration = 0;
    this.turnHostGenerations.clear();
    this.validOriginTurnIds.clear();
    this.turnHostGenerationOrder.splice(0, this.turnHostGenerationOrder.length);
  }

  private currentHotelDetailContext(context: MultiAgentCanaryActionContext): boolean {
    const snapshot = this.currentPageSnapshot();
    const currentHost = this.currentHostSurface();
    const hostGeneration = this.currentHostGeneration();
    if (snapshot === null || currentHost === null ||
      !Number.isSafeInteger(hostGeneration) || hostGeneration <= 0 ||
      !Number.isSafeInteger(snapshot.generation) || snapshot.generation <= 0) {
      return false;
    }
    const surface = snapshot.surface;
    const exact = currentHost.runtimeOwner === 'multi_agent' &&
      surface.runtimeOwner === 'multi_agent' &&
      currentHost.runtimeGeneration === hostGeneration &&
      surface.runtimeGeneration === hostGeneration &&
      currentHost.surfaceId === surface.surfaceId &&
      surface.surfaceId === context.surfaceId &&
      snapshot.document.surfaceId === surface.surfaceId &&
      context.sourceToolId === 'hotel.search' &&
      registeredPageSourceToolId(surface) === context.sourceToolId;
    return exact;
  }

  private admitHotelDetailFollowUp(action: A2uiAction, context: ActionExecutionContext): boolean {
    if (action.id !== 'hotel.detail') {
      return true;
    }
    const hotelContext: HotelActionContext = {
      conversationId: context.conversationId,
      turnId: context.turnId,
      surfaceId: context.surfaceId,
      sourceToolId: context.sourceToolId
    };
    if (!this.authority.beginHotelDetailFollowUp(hotelContext, action, context.runId)) {
      return false;
    }
    this.followUpIds.prepare();
    this.hotelDetailAdmissionSequence++;
    this.lastHotelDetailAdmissionRunId = context.runId;
    return true;
  }

  private rememberTurnHostGeneration(turnId: string, hostGeneration: number): void {
    if (turnId.trim().length === 0) {
      return;
    }
    if (Number.isSafeInteger(hostGeneration) && hostGeneration > 0) {
      this.validOriginTurnIds.add(turnId);
    }
    let capturedGeneration = hostGeneration;
    if (!Number.isSafeInteger(capturedGeneration) || capturedGeneration <= 0) {
      const retained = this.turnHostGenerations.get(turnId);
      if (retained !== undefined && retained > 0) {
        capturedGeneration = retained;
      } else {
        this.surfaceGeneration++;
        capturedGeneration = this.surfaceGeneration;
      }
    }
    if (!this.turnHostGenerations.has(turnId)) {
      this.turnHostGenerationOrder.push(turnId);
    }
    this.turnHostGenerations.set(turnId, capturedGeneration);
    while (this.turnHostGenerationOrder.length > TURN_HOST_GENERATION_LIMIT) {
      const removedTurnId = this.turnHostGenerationOrder[0];
      this.turnHostGenerationOrder.splice(0, 1);
      this.turnHostGenerations.delete(removedTurnId);
      this.validOriginTurnIds.delete(removedTurnId);
    }
  }

  private rememberGmailDraftApplyCandidate(
    result: ActionExecutionResult,
    context: ActionExecutionContext,
    originalArgs: Object
  ): void {
    const runtimeGeneration = this.turnHostGenerations.get(context.turnId);
    this.gmailDraftApplyCandidate = runtimeGeneration === undefined ? null :
      gmailDraftCreateOutputCandidate(result, context, originalArgs, runtimeGeneration);
  }

  private currentGmailDraftApplyAction(): A2uiAction | null {
    const candidate = this.gmailDraftApplyCandidate;
    const currentHost = this.currentHostSurface();
    const current = gmailDraftApplySurfaceBinding(
      this.currentPageSnapshot(),
      currentHost
    );
    if (candidate === null || current === null ||
      current.runtimeGeneration !== candidate.runtimeGeneration ||
      current.surfaceId !== candidate.surfaceId ||
      current.surfaceStatus !== candidate.surfaceStatus ||
      current.actionJson !== candidate.actionJson) {
      return null;
    }
    return exactCurrentGmailDraftApplyAction(
      current,
      currentHost,
      this.currentHostGeneration()
    );
  }
}
