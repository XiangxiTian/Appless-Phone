import {
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiGenericToolResultData,
  AggregateSearchResult,
  AggregateSearchSourceStatus,
  WaterfallFeedState,
  callToolGateway,
  defaultToolGatewayUrl,
  genericToolResults,
  resolveData
} from '@loop/agent-core';
import {
  buildDailyBriefFixtureSections,
  buildDailyBriefFixtureDiscovery,
  dailyBriefDiscoveryWaterfall,
  dailyBriefMailDigest,
  dailyBriefMailReadRequest,
  dailyBriefDate,
  dailyBriefWaterfallInput,
  normalizeDailyBriefWaterfall,
  projectDailyBriefMailForDate,
  projectDailyBriefDiscovery,
  selectDailyBriefTopThree
} from './DailyBriefCore';
import {
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceId,
  DailyBriefSourceState,
  DailyBriefSourceSummary
} from './DailyBriefTypes';

export interface DailyBriefLoadResult {
  sourceId: 'calendar' | 'mail' | 'waterfall';
  state: DailyBriefSourceState;
  message: string;
  items: DailyBriefItem[];
  waterfall: WaterfallFeedState | null;
  retryable: boolean;
}

interface DailyBriefLiveLoadersShape {
  calendar: () => Promise<DailyBriefLoadResult>;
  mail: () => Promise<DailyBriefLoadResult>;
  waterfall: () => Promise<DailyBriefLoadResult>;
}

export type DailyBriefLiveLoaders = DailyBriefLiveLoadersShape;

interface DailyBriefMailActionArgs {
  provider: string;
  threadId: string;
  messageId: string;
  requestKey: string;
}

interface DailyBriefCalendarSearchArgs {
  query: string;
  timeMin: string;
  timeMax: string;
  timezone: string;
  calendarId: string;
}

interface DailyBriefMailSearchArgs {
  providers: string[];
  query: string;
  pageSize: number;
}

interface DailyBriefWaterfallArgs {
  query: string;
  sources: string[];
  preferenceDescription: string;
}

interface DailyBriefHistoryArgs {
  direction: string;
}

export interface DailyBriefGenerationOptions {
  now: Date;
  preference: DailyBriefPreference;
  budgetMs?: number;
  loaders?: DailyBriefLiveLoaders;
}

function preferenceCopy(value: DailyBriefPreference): DailyBriefPreference {
  return {
    topics: value.topics.slice(),
    language: value.language,
    timeBudgetMinutes: value.timeBudgetMinutes,
    formats: value.formats.slice(),
    negativePreference: value.negativePreference,
    targetTime: value.targetTime
  };
}

function actionCopy(value: A2uiAction | undefined): A2uiAction | undefined {
  if (value === undefined || value.id !== 'daily.brief.mail.read') return undefined;
  const request = dailyBriefMailReadRequest(value.args);
  if (request === null) {
    return undefined;
  }
  return {
    id: value.id,
    label: value.label,
    prompt: value.prompt,
    variant: value.variant,
    kind: 'client',
    args: request.args
  };
}

function itemCopy(value: DailyBriefItem): DailyBriefItem {
  const copy: DailyBriefItem = {
    id: value.id,
    sourceId: value.sourceId,
    sourceRecordId: value.sourceRecordId,
    title: value.title,
    summary: value.summary,
    timeLabel: value.timeLabel,
    startsAt: value.startsAt,
    dueAt: value.dueAt,
    leaveBy: value.leaveBy,
    completed: value.completed,
    needsAction: value.needsAction,
    severity: value.severity
  };
  const action = actionCopy(value.action);
  if (action !== undefined) copy.action = action;
  return copy;
}

function loadResultCopy(value: DailyBriefLoadResult): DailyBriefLoadResult {
  return {
    sourceId: value.sourceId,
    state: value.state,
    message: value.message,
    items: value.items.map((item: DailyBriefItem): DailyBriefItem => itemCopy(item)),
    waterfall: normalizeDailyBriefWaterfall(value.waterfall),
    retryable: value.retryable
  };
}

function retryableMessage(message: string): boolean {
  const lower = message.toLowerCase();
  if (lower.indexOf('needs_input') >= 0 || lower.indexOf('invalid input') >= 0 ||
    lower.indexOf('invalid argument') >= 0 || lower.indexOf('parameter invalid') >= 0 ||
    lower.indexOf('blocked') >= 0 || lower.indexOf('authentication required') >= 0 ||
    lower.indexOf('auth required') >= 0 || lower.indexOf('unauthorized') >= 0 ||
    lower.indexOf('needs_auth') >= 0 || lower.indexOf('oauth') >= 0 ||
    lower.indexOf('authorization') >= 0 || lower.indexOf('authorize') >= 0 ||
    lower.indexOf('not connected') >= 0) return false;
  return lower.indexOf('transport exception') >= 0 || lower.indexOf('transport failure') >= 0 ||
    lower.indexOf('transport failed') >= 0 || lower.indexOf('transport error') >= 0 ||
    lower.indexOf('timeout') >= 0 ||
    lower.indexOf('http 502') >= 0 || lower.indexOf('http 503') >= 0 ||
    lower.indexOf('http 504') >= 0 || lower.indexOf('temporarily unavailable') >= 0;
}

function timeoutResult(sourceId: 'calendar' | 'mail' | 'waterfall'): DailyBriefLoadResult {
  return {
    sourceId: sourceId,
    state: 'timeout',
    message: sourceId + ' exceeded the shared daily brief deadline',
    items: [],
    waterfall: null,
    retryable: true
  };
}

function errorResult(
  sourceId: 'calendar' | 'mail' | 'waterfall',
  error: Error | string
): DailyBriefLoadResult {
  const message = typeof error === 'string' ? error : error.message;
  return {
    sourceId: sourceId,
    state: 'error',
    message: message,
    items: [],
    waterfall: null,
    retryable: retryableMessage(message)
  };
}

async function boundedAttempt(
  sourceId: 'calendar' | 'mail' | 'waterfall',
  loader: () => Promise<DailyBriefLoadResult>,
  deadline: number
): Promise<DailyBriefLoadResult> {
  const remaining = deadline - Date.now();
  if (remaining <= 0) return timeoutResult(sourceId);
  let timer = -1;
  const timeout = new Promise<DailyBriefLoadResult>((resolve: (value: DailyBriefLoadResult) => void): void => {
    timer = setTimeout((): void => resolve(timeoutResult(sourceId)), remaining);
  });
  try {
    return loadResultCopy(await Promise.race([loader(), timeout]));
  } catch (error) {
    return errorResult(sourceId, error instanceof Error ? error : JSON.stringify(error));
  } finally {
    if (timer >= 0) clearTimeout(timer);
  }
}

async function boundedLoad(
  sourceId: 'calendar' | 'mail' | 'waterfall',
  loader: () => Promise<DailyBriefLoadResult>,
  deadline: number
): Promise<DailyBriefLoadResult> {
  let value = await boundedAttempt(sourceId, loader, deadline);
  if (value.retryable && value.state === 'error' && Date.now() < deadline) {
    value = await boundedAttempt(sourceId, loader, deadline);
  }
  return value;
}

function rowValue(result: A2uiGenericToolResultData, label: string): string {
  for (let index = 0; index < result.rows.length; index += 1) {
    if (result.rows[index].label === label) return result.rows[index].value.trim();
  }
  return '';
}

function addMessage(messages: string[], message: string): void {
  const visible = message.trim();
  if (visible.length > 0 && messages.indexOf(visible) < 0) messages.push(visible);
}

function noticeMessage(component: A2uiComponent): string {
  if (component.component !== 'ErrorNotice') return '';
  const title = component.title === undefined ? '' : component.title.trim();
  const body = component.body === undefined ? '' : component.body.trim();
  if (title.length > 0 && body.length > 0) return title + '：' + body;
  return title.length > 0 ? title : body;
}

function visibleCallMessages(call: A2uiCallResult): string[] {
  const messages: string[] = [];
  addMessage(messages, call.error);
  addMessage(messages, call.surface.error);
  call.surface.components.forEach((component: A2uiComponent): void => {
    addMessage(messages, noticeMessage(component));
  });
  return messages;
}

function callRetryMessages(call: A2uiCallResult): string[] {
  const messages: string[] = [];
  if (!call.ok || call.error.trim().length > 0) addMessage(messages, call.error);
  if (call.surface.status === 'error' || call.surface.status === 'failed') {
    addMessage(messages, call.surface.error);
  }
  call.surface.components.forEach((component: A2uiComponent): void => {
    if (component.component === 'ErrorNotice' && component.status === 'error') {
      addMessage(messages, noticeMessage(component));
    } else if (call.ok && call.error.trim().length === 0 && call.surface.error.trim().length === 0 &&
      call.surface.status === 'needs_input' && component.component === 'ErrorNotice' &&
      component.status === 'needs_input' && component.title === '工具供应商调用异常' &&
      component.body !== undefined && component.body.trim().length > 0) {
      addMessage(messages, 'Transport exception: ' + component.body.trim());
    }
  });
  return messages;
}

function needsAuthMessage(message: string): boolean {
  const lower = message.toLowerCase();
  return lower.indexOf('authentication required') >= 0 || lower.indexOf('auth required') >= 0 ||
    lower.indexOf('unauthorized') >= 0 || lower.indexOf('needs_auth') >= 0 || lower.indexOf('oauth') >= 0 ||
    lower.indexOf('authorization') >= 0 || lower.indexOf('authorize') >= 0 ||
    lower.indexOf('not connected') >= 0 || message.indexOf('未授权') >= 0 ||
    message.indexOf('需要授权') >= 0;
}

function messagesNeedAuth(messages: string[]): boolean {
  for (let index = 0; index < messages.length; index += 1) {
    if (needsAuthMessage(messages[index])) return true;
  }
  return false;
}

function messagesRetryable(messages: string[]): boolean {
  for (let index = 0; index < messages.length; index += 1) {
    if (retryableMessage(messages[index])) return true;
  }
  return false;
}

function calendarItems(results: A2uiGenericToolResultData[]): DailyBriefItem[] {
  const items: DailyBriefItem[] = [];
  results.forEach((result: A2uiGenericToolResultData): void => {
    if (result.status !== 'success') return;
    const eventId = rowValue(result, 'Event ID');
    if (eventId.length === 0) return;
    const start = rowValue(result, 'Start');
    const end = rowValue(result, 'End');
    items.push({
      id: 'calendar-' + eventId,
      sourceId: 'calendar',
      sourceRecordId: eventId,
      title: result.title,
      summary: result.summary,
      timeLabel: start,
      startsAt: start,
      dueAt: end,
      leaveBy: '',
      completed: false,
      needsAction: false,
      severity: 'none'
    });
  });
  return items;
}

function mailAction(
  provider: string,
  threadId: string,
  messageId: string,
  title: string
): A2uiAction | undefined {
  if (provider.length === 0 || threadId.length === 0 && messageId.length === 0) return undefined;
  const identity = messageId.length > 0 ? messageId : threadId;
  const args: DailyBriefMailActionArgs = {
    provider: provider,
    threadId: threadId,
    messageId: messageId,
    requestKey: provider + ':' + identity
  };
  const request = dailyBriefMailReadRequest(args);
  if (request === null) return undefined;
  return {
    id: 'daily.brief.mail.read',
    label: '查看邮件',
    prompt: '在 App 内查看邮件：' + title,
    variant: 'secondary',
    kind: 'client',
    args: request.args
  };
}

function mailItems(results: A2uiGenericToolResultData[]): DailyBriefItem[] {
  const items: DailyBriefItem[] = [];
  results.forEach((result: A2uiGenericToolResultData, index: number): void => {
    if (result.status !== 'success') return;
    const provider = rowValue(result, 'Provider');
    const threadId = rowValue(result, 'Thread ID');
    const messageId = rowValue(result, 'Message ID');
    if (result.toolName !== 'mail.thread' && provider.length === 0) return;
    const recordId = messageId.length > 0 ? messageId :
      (threadId.length > 0 ? threadId : 'mail-' + index.toString());
    const sourceRecordId = provider.length > 0 ? provider.toLowerCase() + ':' + recordId : recordId;
    const received = rowValue(result, 'Received');
    const sender = rowValue(result, 'From');
    const action = mailAction(provider, threadId, messageId, result.title);
    const item: DailyBriefItem = {
      id: 'mail-' + sourceRecordId,
      sourceId: 'mail',
      sourceRecordId: sourceRecordId,
      title: result.title,
      summary: result.summary.length > 0 ? result.summary : (sender.length > 0 ? '来自：' + sender : ''),
      timeLabel: received,
      startsAt: received,
      dueAt: '',
      leaveBy: '',
      completed: false,
      needsAction: action !== undefined,
      severity: 'none'
    };
    if (action !== undefined) item.action = action;
    items.push(item);
  });
  return items;
}

export function normalizeDailyBriefGenericCall(
  sourceId: 'calendar' | 'mail',
  call: A2uiCallResult
): DailyBriefLoadResult {
  const results = genericToolResults(call.surface);
  const items = sourceId === 'calendar' ? calendarItems(results) : mailItems(results);
  const messages = visibleCallMessages(call);
  const retryEvidence = callRetryMessages(call);
  let hasSuccess = false;
  let hasEmpty = false;
  let hasAuth = false;
  let hasError = !call.ok || call.error.trim().length > 0 || call.surface.error.trim().length > 0 ||
    call.surface.status === 'error' || call.surface.status === 'failed' || messages.length > 0;
  results.forEach((result: A2uiGenericToolResultData): void => {
    if (result.status === 'success') hasSuccess = true;
    else if (result.status === 'empty') {
      hasEmpty = true;
      addMessage(messages, result.summary);
    } else if (result.status === 'needs_auth') {
      hasAuth = true;
      addMessage(messages, result.summary);
    } else {
      hasError = true;
      addMessage(messages, result.summary);
      if (result.status === 'error') addMessage(retryEvidence, result.summary);
    }
  });
  if (results.length === 0 && call.surface.status !== 'ready') hasError = true;
  hasAuth = hasAuth || messagesNeedAuth(messages);
  let state: DailyBriefSourceState = 'empty';
  if (hasAuth) state = 'needs_auth';
  else if (hasError) state = 'error';
  else if (hasSuccess) state = 'success';
  else if (!hasEmpty && results.length > 0) state = 'error';
  if (sourceId === 'calendar' && state === 'success' && items.length === 0) state = 'empty';
  const retryable = state === 'error' && messagesRetryable(retryEvidence);
  const fallback = hasError && call.surface.title.trim().length > 0
    ? call.surface.title.trim() : sourceId + ' returned no visible results';
  const message = messages.length > 0 ? messages.join('；') : fallback;
  return {
    sourceId: sourceId,
    state: state,
    message: message,
    items: items,
    waterfall: null,
    retryable: retryable
  };
}

export function normalizeDailyBriefWaterfallCall(call: A2uiCallResult): DailyBriefLoadResult {
  const aggregate = resolveData(call.surface, '/aggregateSearch') as AggregateSearchResult;
  const waterfall = normalizeDailyBriefWaterfall(aggregate.waterfall === undefined ? null : aggregate.waterfall);
  const messages = visibleCallMessages(call);
  const retryEvidence = callRetryMessages(call);
  let hasSuccess = aggregate.videos.length > 0 || aggregate.posts.length > 0;
  let hasAuth = false;
  let hasError = !call.ok || call.surface.status === 'error' ||
    call.surface.status === 'failed' || call.error.trim().length > 0 || call.surface.error.trim().length > 0 ||
    messages.length > 0;
  aggregate.sourceStatuses.forEach((source: AggregateSearchSourceStatus): void => {
    if (source.status === 'success') hasSuccess = true;
    else if (source.status === 'needs_auth') hasAuth = true;
    else if (source.status === 'error' || source.status === 'unsupported') {
      hasError = true;
      if (source.status === 'error') addMessage(retryEvidence, source.message);
    }
    if (source.status !== 'success' && source.status !== 'empty') addMessage(messages, source.message);
  });
  hasAuth = hasAuth || messagesNeedAuth(messages);
  let state: DailyBriefSourceState = 'empty';
  if (hasError) state = 'error';
  else if (hasAuth) state = 'needs_auth';
  else if (hasSuccess) state = 'success';
  const retryable = state === 'error' && messagesRetryable(retryEvidence);
  addMessage(messages, aggregate.summary);
  const message = messages.length > 0 ? messages.join('；') : 'Waterfall returned no visible results';
  return {
    sourceId: 'waterfall',
    state: state,
    message: message,
    items: [],
    waterfall: waterfall,
    retryable: retryable
  };
}

export function createDefaultDailyBriefLoaders(
  now: Date,
  preference: DailyBriefPreference
): DailyBriefLiveLoaders {
  const stamp = now.getTime().toString();
  const start = new Date(now.getTime());
  start.setHours(0, 0, 0, 0);
  const end = new Date(start.getTime());
  end.setDate(end.getDate() + 1);
  const waterfallInput = dailyBriefWaterfallInput(preference, '个人日报');
  const calendarArgs: DailyBriefCalendarSearchArgs = {
    query: '',
    timeMin: start.toISOString(),
    timeMax: end.toISOString(),
    timezone: 'Asia/Shanghai',
    calendarId: 'primary'
  };
  const mailArgs: DailyBriefMailSearchArgs = {
    providers: ['gmail', 'qq', 'outlook'],
    query: 'newer_than:1d',
    pageSize: 10
  };
  const waterfallArgs: DailyBriefWaterfallArgs = {
    query: waterfallInput.query,
    sources: waterfallInput.sources,
    preferenceDescription: waterfallInput.preferenceDescription
  };
  return {
    calendar: async (): Promise<DailyBriefLoadResult> => normalizeDailyBriefGenericCall('calendar', await callToolGateway(
      defaultToolGatewayUrl(),
      'calendar.events.search',
      '生成个人日报：读取今日日程',
      'daily-brief-calendar-' + stamp,
      '',
      (): void => {},
      null,
      calendarArgs
    )),
    mail: async (): Promise<DailyBriefLoadResult> => normalizeDailyBriefGenericCall('mail', await callToolGateway(
      defaultToolGatewayUrl(),
      'mail.search',
      '生成个人日报：读取最近的重要邮件',
      'daily-brief-mail-' + stamp,
      '',
      (): void => {},
      null,
      mailArgs
    )),
    waterfall: async (): Promise<DailyBriefLoadResult> => normalizeDailyBriefWaterfallCall(await callToolGateway(
      defaultToolGatewayUrl(),
      'media.aggregate.search',
      waterfallInput.query,
      'daily-brief-waterfall-' + stamp,
      '',
      (): void => {},
      null,
      waterfallArgs
    ))
  };
}

function fixtureSources(): DailyBriefSourceSummary[] {
  const ids: DailyBriefSourceId[] = ['todo', 'yesterday', 'weather', 'commute', 'health', 'spending'];
  return ids.map((sourceId: DailyBriefSourceId): DailyBriefSourceSummary => ({
    sourceId: sourceId,
    state: 'fixture',
    message: '本地固定内容'
  }));
}

function baseAction(id: string, label: string): A2uiAction {
  return { id: id, label: label, prompt: label, variant: 'secondary', kind: 'client' };
}

function snapshotActions(
  preference: DailyBriefPreference,
  mail: DailyBriefItem[],
  hasDiscovery: boolean
): A2uiAction[] {
  const actions: A2uiAction[] = [baseAction('daily.brief.regenerate', '重新生成')];
  const save = baseAction('daily.brief.preference.save', '保存偏好');
  save.args = preferenceCopy(preference);
  actions.push(save);
  const directions: string[] = ['previous', 'today'];
  directions.forEach((direction: string): void => {
    const history = baseAction('daily.brief.history.open', direction);
    const args: DailyBriefHistoryArgs = { direction: direction };
    history.args = args;
    actions.push(history);
  });
  actions.push(baseAction('daily.brief.route.open', '查看路线'));
  actions.push(baseAction('daily.brief.ride.estimate', '预估车型'));
  mail.forEach((item: DailyBriefItem): void => {
    if (item.action !== undefined) actions.push(actionCopy(item.action) as A2uiAction);
  });
  if (hasDiscovery) actions.push(baseAction('daily.brief.discovery.open', '查看完整发现流'));
  return actions;
}

function mergeSections(
  now: Date,
  calendar: DailyBriefLoadResult,
  mail: DailyBriefLoadResult,
  selectedMail: DailyBriefItem[]
): DailyBriefSection[] {
  const sections = buildDailyBriefFixtureSections(now);
  sections.forEach((section: DailyBriefSection): void => {
    if (section.id === 'today') {
      section.items = calendar.items.map((item: DailyBriefItem): DailyBriefItem => itemCopy(item));
      section.state = calendar.items.length > 0 ? 'success' : calendar.state;
      section.message = calendar.items.length > 0 ? '今天有 ' + calendar.items.length.toString() + ' 项安排' :
        (calendar.state === 'needs_auth' ? '连接日历后查看今日日程' :
          (calendar.state === 'error' || calendar.state === 'timeout' ? '今日日程暂不可用' : '今天没有日程'));
    } else if (section.id === 'mail') {
      if (selectedMail.length > 0) {
        section.state = 'success';
        section.message = dailyBriefMailDigest(selectedMail);
        section.items = selectedMail.map((item: DailyBriefItem): DailyBriefItem => itemCopy(item));
      } else {
        section.state = mail.state;
        section.message = mail.state === 'needs_auth' ? '连接邮箱后查看今日邮件' :
          (mail.state === 'error' || mail.state === 'timeout' ? '今日邮件暂不可用' : '今天没有邮件');
        section.items = [];
      }
    }
  });
  return sections;
}

export async function generateDailyBrief(
  options: DailyBriefGenerationOptions
): Promise<DailyBriefSnapshot> {
  const budgetMs = options.budgetMs === undefined ? 60000 : Math.max(0, options.budgetMs);
  const deadline = Date.now() + budgetMs;
  const loaders = options.loaders === undefined
    ? createDefaultDailyBriefLoaders(options.now, options.preference)
    : options.loaders;
  const calendarPending = boundedLoad('calendar', loaders.calendar, deadline);
  const mailPending = boundedLoad('mail', loaders.mail, deadline);
  const waterfallPending = boundedLoad('waterfall', loaders.waterfall, deadline);
  const loaded = await Promise.all([calendarPending, mailPending, waterfallPending]);
  const calendar = loaded[0];
  const mail = loaded[1];
  const waterfall = loaded[2];
  const selectedMail = projectDailyBriefMailForDate(dailyBriefDate(options.now), mail.items);
  const sections = mergeSections(options.now, calendar, mail, selectedMail);
  const sources = fixtureSources();
  sources.push(
    { sourceId: 'calendar', state: calendar.state, message: calendar.message },
    { sourceId: 'mail', state: mail.state, message: mail.message },
    { sourceId: 'waterfall', state: waterfall.state, message: waterfall.message }
  );
  const profile = preferenceCopy(options.preference);
  const discovery = waterfall.waterfall === null ? buildDailyBriefFixtureDiscovery(dailyBriefDate(options.now)) :
    projectDailyBriefDiscovery(waterfall.waterfall);
  const snapshot: DailyBriefSnapshot = {
    schemaVersion: 1,
    date: dailyBriefDate(options.now),
    generatedAt: options.now.toISOString(),
    status: calendar.state === 'success' && mail.state === 'success' && waterfall.state === 'success'
      ? 'complete' : 'partial',
    profile: profile,
    topThree: selectDailyBriefTopThree(sections),
    sections: sections,
    discovery: discovery,
    sources: sources,
    waterfall: waterfall.waterfall,
    actions: snapshotActions(profile, selectedMail, discovery.length > 0)
  };
  if (snapshot.waterfall === null && snapshot.discovery.length > 0) {
    snapshot.waterfall = dailyBriefDiscoveryWaterfall(snapshot);
  }
  return snapshot;
}
