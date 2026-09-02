import {
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2uiSurfaceState,
  RuntimeOwner
} from '@loop/agent-core';

export const A2UI_SEND_SPINNER_STEP_DEG: number = 24;

export type A2uiSessionResetCause = 'account_scope_invalidated' | 'user_requested';

/** Account changes discard only live UI state; only the user's reset action erases persisted turns. */
export function sessionResetDeletesPersistedConversation(cause: A2uiSessionResetCause): boolean {
  return cause === 'user_requested';
}

export interface ConnectionPanelState {
  connectionStatus: string;
  connectionMessage: string;
  lastModelRequest: string;
  lastModelOutput: string;
  lastError: string;
  refreshTick: number;
}

export interface ConnectionPanelUpdate {
  ok: boolean;
  status: string;
  message: string;
  requestDebug: string;
  assistantDebug: string;
  error: string;
}

export function createInitialConnectionPanelState(): ConnectionPanelState {
  return {
    connectionStatus: 'idle',
    connectionMessage: '尚未测试模型连接。',
    lastModelRequest: '',
    lastModelOutput: '',
    lastError: '',
    refreshTick: 0
  };
}

export function updateConnectionPanelState(current: ConnectionPanelState, update: ConnectionPanelUpdate): ConnectionPanelState {
  return {
    connectionStatus: update.status,
    connectionMessage: update.message,
    lastModelRequest: update.requestDebug,
    lastModelOutput: update.assistantDebug,
    lastError: update.ok ? '' : update.error,
    refreshTick: current.refreshTick + 1
  };
}

export function shouldApplySurfaceUpdate(current: A2uiSurfaceState, next: A2uiSurfaceState): boolean {
  const currentGeneration: number = current.runtimeGeneration === undefined ? 0 : current.runtimeGeneration;
  const nextGeneration: number = next.runtimeGeneration === undefined ? 0 : next.runtimeGeneration;
  if (nextGeneration < currentGeneration) {
    return false;
  }
  if (nextGeneration > currentGeneration) {
    return true;
  }
  if (nextGeneration === currentGeneration && current.runtimeOwner !== undefined &&
    next.runtimeOwner !== undefined && current.runtimeOwner !== next.runtimeOwner) {
    return false;
  }
  return current.surfaceId !== next.surfaceId || current.sequence !== next.sequence;
}

export function runtimeOwnerAllowsSurfaceAction(
  surface: A2uiSurfaceState,
  owner: RuntimeOwner
): boolean {
  return surface.runtimeOwner === owner;
}

export function runtimeCallbackIsCurrent(
  activeOwner: RuntimeOwner,
  activeGeneration: number,
  callbackOwner: RuntimeOwner,
  callbackGeneration: number
): boolean {
  return activeOwner === callbackOwner && activeGeneration === callbackGeneration;
}

export function runtimeSurfaceIdentityMatches(
  current: A2uiSurfaceState,
  retained: A2uiSurfaceState,
  activeOwner: RuntimeOwner,
  activeGeneration: number
): boolean {
  return activeOwner === 'multi_agent' && Number.isSafeInteger(activeGeneration) &&
    activeGeneration > 0 &&
    current.runtimeOwner === activeOwner &&
    retained.runtimeOwner === activeOwner &&
    current.runtimeGeneration === activeGeneration &&
    retained.runtimeGeneration === activeGeneration &&
    current.surfaceId.trim().length > 0 &&
    current.surfaceId === retained.surfaceId;
}

export function nextSendSpinnerRotation(current: number, isBusy: boolean): number {
  if (!isBusy) {
    return 0;
  }
  return current + A2UI_SEND_SPINNER_STEP_DEG;
}

export function nextPendingToolRenderTick(
  current: number,
  currentToolId: string,
  nextToolId: string
): number {
  return currentToolId === nextToolId ? current : current + 1;
}

export function isPromptInputEnabled(isBusy: boolean): boolean {
  return !isBusy;
}

export type DeepSearchRouteDecision = 'agent' | 'deepsearch';

interface DeepSearchRouteDecisionJson {
  route?: string;
}

export function deepSearchRouteDecisionFromModelText(raw: string): DeepSearchRouteDecision {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return 'agent';
  }
  try {
    const value = JSON.parse(raw.substring(start, end + 1)) as DeepSearchRouteDecisionJson;
    return value.route === 'deepsearch' ? 'deepsearch' : 'agent';
  } catch (_error) {
    return 'agent';
  }
}

export function explicitDeepSearchRouteDecision(query: string): DeepSearchRouteDecision | null {
  const text = query.trim();
  if (/(不想|不希望|不要|不用|不需要|不必|无需|别|禁止|拒绝|请勿)[^，。；,;!?！？]{0,16}(深度搜索|深度检索|联网搜索|联网|deep\s*search|deepsearch)|(深度搜索|深度检索|联网搜索|deep\s*search|deepsearch)[^，。；,;!?！？]{0,8}(免了|算了|不用了?|不要了?|不需要|无需|别|我?不想用?|我?不希望用?)|\b(do\s*not|don't|dont|skip|avoid|without|no)\b[^,.;!?]{0,16}(deep\s*search|deepsearch)|(deep\s*search|deepsearch)([^,.;!?]{0,16}(is\s+not\s+needed|isn't\s+needed|not\s+needed)|\s*[,;:]?\s*no\s+thanks)/i.test(text)) {
    return 'agent';
  }
  return /(深度搜索|深度检索|联网搜索|deep\s*search|deepsearch)/i.test(text) ? 'deepsearch' : null;
}

export function deepSearchRouteDecisionPrompt(query: string): string {
  return '判断用户请求应由普通 Agent 处理还是进入 DeepSearch。只输出 JSON：' +
    '{"route":"agent"} 或 {"route":"deepsearch"}。' +
    '普通问答、闲聊、出行、餐饮、地图、打车、酒店、媒体聚合搜索走 agent；' +
    '需要最新或实时外部信息（如天气），或需要开放网页多来源检索、深读与事实查证的问题走 deepsearch。' +
    '用户明确要求或拒绝深度搜索时优先服从。用户请求：' + JSON.stringify(query.trim());
}

export function visibleTurnFailureMessage(raw: string): string {
  const normalized = raw.toLowerCase();
  if (normalized.indexOf('429') >= 0 || normalized.indexOf('ratelimit') >= 0 ||
    normalized.indexOf('rate limit') >= 0 || normalized.indexOf('throttling') >= 0 ||
    normalized.indexOf('请求增长过快') >= 0) {
    return '模型请求过于频繁，请稍后重试。';
  }
  return '这次请求没有完成，请稍后重试。';
}

export function createTurnFailureSurface(message: string, generation: number): A2uiSurfaceState {
  return {
    surfaceId: 'surface_turn_error_' + generation.toString(),
    rootId: 'root',
    title: '这次请求没有完成',
    intent: 'general',
    status: 'error',
    components: [
      { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT, child: 'body' },
      { id: 'body', component: A2UI_COMPONENT_COLUMN, children: ['notice'] },
      {
        id: 'notice',
        component: A2UI_COMPONENT_ERROR_NOTICE,
        title: '请稍后再试',
        body: message,
        status: 'error'
      }
    ],
    dataModelJson: '{}',
    error: message,
    sequence: 1,
    runtimeOwner: 'multi_agent',
    runtimeGeneration: generation
  };
}

export function createTurnConversationSurface(generation: number): A2uiSurfaceState {
  return {
    surfaceId: 'surface_turn_conversation_' + generation.toString(),
    rootId: 'root',
    title: 'Appless 回答',
    intent: 'general',
    status: 'ready',
    components: [
      { id: 'root', component: A2UI_COMPONENT_SURFACE_ROOT }
    ],
    dataModelJson: '{}',
    error: '',
    sequence: 1,
    runtimeOwner: 'multi_agent',
    runtimeGeneration: generation
  };
}

export function shouldShowQueryPendingSurface(isBusy: boolean, isAwaitingFirstSurface: boolean): boolean {
  return isBusy && isAwaitingFirstSurface;
}

export function shouldShowDeepSearchPendingSurface(showDeepSearch: boolean, isBusy: boolean): boolean {
  return showDeepSearch && isBusy;
}

export function shouldShowFirecrawlPendingSurface(
  isBusy: boolean,
  pendingToolId: string,
  surface: A2uiSurfaceState
): boolean {
  if (!isBusy || pendingToolId.length === 0) {
    return false;
  }
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.intent === pendingToolId &&
      surface.components[index].component === 'GenericToolResults') {
      return false;
    }
  }
  return true;
}

export function isWelcomeSurface(surface: A2uiSurfaceState): boolean {
  return surface.surfaceId === 'surface_seed' &&
    surface.status === 'idle' &&
    surface.components.length === 0;
}

export function shouldShowWelcome(
  isBusy: boolean,
  messageCount: number,
  surface: A2uiSurfaceState,
  showRestoredConversationOnLanding: boolean
): boolean {
  return !isBusy && (messageCount === 0 || showRestoredConversationOnLanding) && isWelcomeSurface(surface);
}

export function inputTextAfterPromptSubmit(current: string): string {
  return '';
}

export function voiceInputTextAfterRecognition(current: string, recognized: string): string {
  const next = recognized.trim();
  if (next.length === 0) {
    return current;
  }
  const draft = current.trim();
  if (draft.length === 0) {
    return next;
  }
  return draft + ' ' + next;
}

export function connectionStatusLabel(status: string): string {
  if (status === 'checking') {
    return '连接中';
  }
  if (status === 'ready') {
    return '连接正常';
  }
  if (status === 'error') {
    return '连接异常';
  }
  return '未检查';
}
