import { A2uiSurfaceState, RuntimeOwner } from '@loop/agent-core';

export const A2UI_SEND_SPINNER_STEP_DEG: number = 24;

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

export function shouldRouteDeepSearch(
  deepSearchEnabled: boolean,
  prompt: string,
  actionId: string
): boolean {
  return deepSearchEnabled && prompt.trim().length > 0 && actionId.length === 0;
}

export const DEEP_SEARCH_AUTO_DISABLED_ACTION_PREFIXES: string[] = [
  'media.',
  'social.',
  'travel.',
  'train.',
  'flight.',
  'hotel.',
  'food.',
  'ride.',
  'local.',
  'map.',
  'movie.',
  'video.',
  'entertainment.',
  'shopping.',
  'mail.',
  'calendar.',
  'gmail.'
];

/**
 * 既有搜索类的内容关键词：命中任一即走原 multi-agent 流程，不路由到 DeepSearch。
 * 覆盖媒体（影视/音乐/视频/播客）、社交（微博/小红书/抖音/B站）、出行（机票/火车/
 * 打车/酒店/导航）、本地生活（美食/外卖/咖啡/奶茶）、地图与地点等范畴。
 */
const BUILTIN_SEARCH_MARKERS: string[] = [
  // 媒体类
  '电影', '电视剧', '综艺', '动漫', '动画', '纪录片', '音乐', '歌手', '专辑', '歌曲',
  'MV', '短视频', '视频', '直播', '抖音', 'B站', 'bilibili', 'YouTube', '视频号',
  '播客', '剧集', '追剧', '影评', '评分', '票房', '上线', '上映', '开播',
  // 社交类
  '微博', '热搜', '小红书', '朋友圈', '社交', '发帖', '动态', '粉丝', '关注',
  '推特', 'X平台', 'ins', 'Instagram', '帖子',
  // 出行类
  '机票', '航班', '火车', '高铁', '动车', '车票', '打车', '网约车', '出租车',
  '滴滴', '出行', '导航', '路线', '自驾', '地图', '酒店', '民宿', '订房', '入住',
  '公交', '地铁', '时刻表', '班次', '票价', '里程',
  // 本地生活类
  '美食', '餐厅', '饭店', '外卖', '咖啡', '奶茶', '点餐', '菜单', '附近', '周边',
  '本地', '商场', '超市', '门店', '营业时间', '地址在哪', '怎么去', '团购', '优惠券',
  '探店', '吃喝玩乐',
  // 购物类
  '购物', '商品', '下单', '购买', '付款', '支付', '订单', '快递', '物流', '比价',
  '购物车', '优惠', '折扣'
];

export function matchesBuiltinSearchCategory(text: string): boolean {
  const normalized = text.trim().toLowerCase();
  if (normalized.length === 0) {
    return false;
  }
  for (let index = 0; index < BUILTIN_SEARCH_MARKERS.length; index++) {
    if (normalized.indexOf(BUILTIN_SEARCH_MARKERS[index].toLowerCase()) >= 0) {
      return true;
    }
  }
  return false;
}

export function autoDeepSearchQuery(text: string): string {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return '';
  }
  return trimmed.length > 240 ? trimmed.substring(0, 240) : trimmed;
}

export function shouldAutoRouteDeepSearch(prompt: string, actionId: string): boolean {
  const trimmed = prompt.trim();
  if (trimmed.length === 0 || actionId.length > 0) {
    return false;
  }
  for (let index = 0; index < DEEP_SEARCH_AUTO_DISABLED_ACTION_PREFIXES.length; index++) {
    if (actionId.startsWith(DEEP_SEARCH_AUTO_DISABLED_ACTION_PREFIXES[index])) {
      return false;
    }
  }
  // 既有搜索类范畴（媒体/社交/出行/本地生活/地图等）不路由，其余内容自动进入 DeepSearch。
  return !matchesBuiltinSearchCategory(trimmed);
}

export function shouldShowQueryPendingSurface(isBusy: boolean, isAwaitingFirstSurface: boolean): boolean {
  return isBusy && isAwaitingFirstSurface;
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

export function shouldShowWelcome(isBusy: boolean, messageCount: number, surface: A2uiSurfaceState): boolean {
  return !isBusy && messageCount === 0 && isWelcomeSurface(surface);
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
    return '检查中';
  }
  if (status === 'ready') {
    return '连接正常';
  }
  if (status === 'error') {
    return '连接异常';
  }
  return '未检查';
}
