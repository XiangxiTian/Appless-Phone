import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { preferences } from '@kit.ArkData';
import util from '@ohos.util';
import {
  aiLogError,
  aiLogInfo,
  AssetCredentialStore,
  gmailOAuthConfigFromProvider,
  handleGmailOAuthRedirect
} from '@loop/agent-core';
import { configurePersonaStoreFromRaw } from '../model/PersonaStore';
import { loadProviderRuntimeConfig } from './ProviderRuntimeBootstrap';
import {
  BIM_SENTINEL_MOCK_EVENT,
  queueBimSentinelMockHandoff
} from '../pages/A2uiHome/bim/BimDailyReminder';
import {
  claimDueTrainPresaleTask,
  parseTrainPresaleTaskList,
  serializeTrainPresaleTaskList,
  TRAIN_PRESALE_TASK_STORE_NAME,
  TrainPresaleTask,
  TrainPresaleTaskState,
  updateTrainPresaleTask
} from '../pages/A2uiHome/train/TrainPresaleTaskStore';
import { activeAccountOwnerId } from '../account/ActiveAccountOwnerStore';
import { accountScopedStoreName } from '../account/AccountStorageScope';

const DOMAIN = 0x0000;
const A2UI_SYSTEM_TOP_INSET_STORAGE_KEY = 'a2uiSystemTopInsetVp';
const A2UI_SYSTEM_BOTTOM_INSET_STORAGE_KEY = 'a2uiSystemBottomInsetVp';
const A2UI_SYSTEM_TOP_INSET_FALLBACK: number = 24;
const A2UI_SYSTEM_BOTTOM_INSET_FALLBACK: number = 12;
const PERSONA_MANIFEST_RAWFILE = 'personas/personas.json';
const PERSONA_IDS: string[] = [
  'default_companion',
  'food_companion',
  'travel_companion',
  'work_companion',
  'entertainment_companion',
  'game_companion',
  'shopping_companion'
];
const PERSONA_SKILL_PATHS: Record<string, string[]> = {
  'default_companion': ['skills/default-general/SKILL.md'],
  'food_companion': ['skills/food-search/SKILL.md', 'skills/milk-tea/SKILL.md'],
  'travel_companion': ['skills/travel-planning/SKILL.md', 'skills/train-planning/SKILL.md', 'skills/flight-planning/SKILL.md'],
  'work_companion': ['skills/work-assistant/SKILL.md', 'skills/mail-draft/SKILL.md', 'skills/calendar-planning/SKILL.md'],
  'entertainment_companion': ['skills/media-search/SKILL.md', 'skills/worldcup-night/SKILL.md', 'skills/youtube-search/SKILL.md'],
  'game_companion': ['skills/game-research/SKILL.md', 'skills/build-guide/SKILL.md'],
  'shopping_companion': ['skills/shopping-research/SKILL.md', 'skills/budget-compare/SKILL.md']
};
const GMAIL_REVERSED_CLIENT_SCHEME = 'com.googleusercontent.apps.358078200829-covuu6l8dgvs7kaejua7mrkke7e8833b:/oauth2redirect';
const GMAIL_OAUTH_URI_HINTS: string[] = [
  'com.jiuwen.appless:/oauth/google',
  'com.jiuwen.appless://oauth/google',
  'aiphone://oauth/google',
  GMAIL_REVERSED_CLIENT_SCHEME
];
const COMPOSIO_CALLBACK_URI_HINTS: string[] = [
  'aiphone://composio/callback'
];
export const TRAIN_PRESALE_TASKS_KEY: string = 'tasks';
export const TRAIN_PRESALE_PENDING_TASK_KEY: string = 'pending_execution_task_id';
export const TRAIN_PRESALE_HANDOFF_EVENT: string = 'trainPresaleHandoffChanged';
export const WATERFALL_CONVERSATION_TYPED_TEST_EVENT: string = 'waterfallConversationTypedTest';
const TRAIN_PRESALE_REPLACED_REASON: string = '新的开售提醒已到达；请重新打开此任务继续。';

export interface TrainPresaleHandoffClaimResult {
  taskId: string;
  changed: boolean;
}

export interface TrainPresaleHandoffTransitionResult {
  task: TrainPresaleTask | undefined;
  cleared: boolean;
}

export interface WaterfallConversationTypedTestPayload {
  prompt: string;
}

export function waterfallShareUrlFromWant(want: Want): string {
  const uri = want.uri === undefined ? '' : want.uri.trim();
  const publicMatch = /^https:\/\/jiuwenappless\.com\/s\/([A-Za-z0-9_-]{12})(?:[?#].*)?$/.exec(uri);
  const appMatch = /^com\.jiuwen\.appless:\/\/share\/([A-Za-z0-9_-]{12})(?:[?#].*)?$/.exec(uri);
  const shareId = publicMatch === null ? (appMatch === null ? '' : appMatch[1]) : publicMatch[1];
  return shareId.length > 0 ? 'https://jiuwenappless.com/s/' + shareId : '';
}

function hasUriHint(uri: string, hints: string[]): boolean {
  for (let index = 0; index < hints.length; index++) {
    if (uri.indexOf(hints[index]) === 0) {
      return true;
    }
  }
  return false;
}

function isGmailOAuthRedirectUri(uri: string): boolean {
  return hasUriHint(uri, GMAIL_OAUTH_URI_HINTS);
}

function isComposioCallbackUri(uri: string): boolean {
  return hasUriHint(uri, COMPOSIO_CALLBACK_URI_HINTS);
}

function describeError(error: Error | Object | string | number | boolean | null | undefined): string {
  if (error === undefined || error === null) {
    return '';
  }
  if (error instanceof Error) {
    return error.message;
  }
  if (typeof error === 'string' || typeof error === 'number' || typeof error === 'boolean') {
    return error.toString();
  }
  return JSON.stringify(error);
}

function allOAuthUriHints(): string[] {
  return GMAIL_OAUTH_URI_HINTS.concat(COMPOSIO_CALLBACK_URI_HINTS);
}

function shouldInspectPotentialOAuthText(value: string): boolean {
  return value.indexOf('oauth') >= 0 ||
    value.indexOf('google') >= 0 ||
    value.indexOf('composio') >= 0 ||
    value.indexOf('callback') >= 0 ||
    value.indexOf('/x') >= 0 ||
    value.indexOf('state=') >= 0 ||
    value.indexOf('code=') >= 0;
}

function decodeUriCandidate(value: string): string {
  try {
    return decodeURIComponent(value.replace(/\+/g, ' '));
  } catch (_err) {
    return value;
  }
}

function embeddedUriFromText(value: string): string {
  const decoded = decodeUriCandidate(value);
  const variants: string[] = value === decoded ? [value] : [value, decoded];
  for (let valueIndex = 0; valueIndex < variants.length; valueIndex++) {
    const candidateText = variants[valueIndex];
    const hints = allOAuthUriHints();
    for (let hintIndex = 0; hintIndex < hints.length; hintIndex++) {
      const hint = hints[hintIndex];
      const start = candidateText.indexOf(hint);
      if (start < 0) {
        continue;
      }
      let end = candidateText.length;
      const terminators: string[] = ['"', '\'', ' ', '\n', '\r', '\t', '<', '>', '}'];
      for (let termIndex = 0; termIndex < terminators.length; termIndex++) {
        const termAt = candidateText.indexOf(terminators[termIndex], start);
        if (termAt >= 0 && termAt < end) {
          end = termAt;
        }
      }
      return candidateText.substring(start, end);
    }
  }
  return '';
}

function appendOAuthUriCandidates(candidates: string[], value: Object | string | number | boolean | null | undefined): void {
  if (value === undefined || value === null) {
    return;
  }
  if (typeof value === 'string') {
    if (!shouldInspectPotentialOAuthText(value)) {
      return;
    }
    candidates.push(value);
    const decoded = decodeUriCandidate(value);
    if (decoded !== value) {
      candidates.push(decoded);
    }
    const embedded = embeddedUriFromText(value);
    if (embedded.length > 0) {
      candidates.push(embedded);
    }
    return;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return;
  }
  try {
    appendOAuthUriCandidates(candidates, JSON.stringify(value));
  } catch (_err) {
  }
}

function gmailOAuthWantParameterKeys(want: Want): string {
  const params = want.parameters;
  if (params === undefined || params === null) {
    return '';
  }
  const keys: string[] = [];
  Object.keys(params).forEach((key: string) => {
    keys.push(key);
  });
  return keys.join('|').substring(0, 240);
}

function oauthUriFromWant(want: Want): string {
  const candidates: string[] = [];
  appendOAuthUriCandidates(candidates, want.uri);
  const params = want.parameters;
  if (params !== undefined && params !== null) {
    Object.keys(params).forEach((key: string) => {
      appendOAuthUriCandidates(candidates, params[key]);
    });
  }
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    if (isGmailOAuthRedirectUri(candidate) || isComposioCallbackUri(candidate)) {
      return candidate;
    }
  }
  return '';
}

function preferenceText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

function trainPresaleTaskIdFromWant(want: Want): string | undefined {
  const params = want.parameters;
  if (params === undefined || params === null) {
    return undefined;
  }
  const value = params['trainPresaleTaskId'];
  return typeof value === 'string' && value.trim().length > 0 ? value.trim() : undefined;
}

export function queueBimSentinelMockFromWant(want: Want): boolean {
  const params = want.parameters;
  if (params === undefined || params === null || params['bimDailySentinelMock'] !== true) {
    return false;
  }
  queueBimSentinelMockHandoff();
  return true;
}

export function waterfallConversationTypedTestPromptFromWant(want: Want): string {
  const params = want.parameters;
  if (params === undefined || params === null) return '';
  const value = params['waterfallConversationPrompt'];
  if (typeof value !== 'string') return '';
  const prompt = value.trim();
  return prompt.length > 0 && prompt.length <= 240 ? prompt : '';
}

function trainPresaleTasks(store: preferences.Preferences): TrainPresaleTask[] {
  return parseTrainPresaleTaskList(preferenceText(store.getSync(TRAIN_PRESALE_TASKS_KEY, '')));
}

function trainPresaleTaskIndex(tasks: TrainPresaleTask[], taskId: string): number {
  for (let index = 0; index < tasks.length; index++) {
    if (tasks[index].taskId === taskId) {
      return index;
    }
  }
  return -1;
}

export function claimTrainPresaleHandoff(
  store: preferences.Preferences,
  nowIso: string,
  explicitTaskId?: string
): TrainPresaleHandoffClaimResult {
  const tasks = trainPresaleTasks(store);
  const previousPending = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  const explicit = explicitTaskId === undefined ? '' : explicitTaskId.trim();
  if (explicit.length > 0) {
    const targetIndex = trainPresaleTaskIndex(tasks, explicit);
    if (targetIndex < 0) {
      return { taskId: previousPending, changed: false };
    }
    let updatedTasks = tasks;
    let target = tasks[targetIndex];
    if (target.state === 'scheduled') {
      const claimed = claimDueTrainPresaleTask(tasks, nowIso, explicit);
      if (claimed.task === undefined) {
        return { taskId: previousPending, changed: false };
      }
      updatedTasks = claimed.tasks;
      target = claimed.task;
    } else if (target.state !== 'executing') {
      return { taskId: previousPending, changed: false };
    }
    if (previousPending.length > 0 && previousPending !== explicit) {
      const replacedIndex = trainPresaleTaskIndex(updatedTasks, previousPending);
      if (replacedIndex >= 0 && updatedTasks[replacedIndex].state === 'executing') {
        updatedTasks[replacedIndex] = updateTrainPresaleTask(updatedTasks[replacedIndex], {
          state: 'needs_user',
          lastError: TRAIN_PRESALE_REPLACED_REASON
        });
      }
    }
    store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(updatedTasks));
    store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, target.taskId);
    store.flushSync();
    return { taskId: target.taskId, changed: previousPending !== target.taskId || tasks[targetIndex].state === 'scheduled' };
  }
  const pendingIndex = trainPresaleTaskIndex(tasks, previousPending);
  if (pendingIndex >= 0 && tasks[pendingIndex].state === 'executing') {
    return { taskId: previousPending, changed: false };
  }
  const claimed = claimDueTrainPresaleTask(tasks, nowIso);
  if (claimed.task === undefined) {
    if (previousPending.length > 0) {
      store.deleteSync(TRAIN_PRESALE_PENDING_TASK_KEY);
      store.flushSync();
    }
    return { taskId: '', changed: false };
  }
  store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(claimed.tasks));
  store.putSync(TRAIN_PRESALE_PENDING_TASK_KEY, claimed.task.taskId);
  store.flushSync();
  return { taskId: claimed.task.taskId, changed: true };
}

export function transitionTrainPresaleHandoff(
  store: preferences.Preferences,
  taskId: string,
  state: TrainPresaleTaskState,
  reason: string
): TrainPresaleHandoffTransitionResult {
  const pending = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  const tasks = trainPresaleTasks(store);
  const index = trainPresaleTaskIndex(tasks, taskId);
  const current = index < 0 ? undefined : tasks[index];
  if (state === 'executing' || pending !== taskId || current === undefined) {
    return { task: current, cleared: false };
  }
  const updated = updateTrainPresaleTask(current, { state: state, lastError: reason });
  if (updated.state !== state) {
    return { task: current, cleared: false };
  }
  tasks[index] = updated;
  store.putSync(TRAIN_PRESALE_TASKS_KEY, serializeTrainPresaleTaskList(tasks));
  store.flushSync();
  const pendingAfterTaskFlush = preferenceText(store.getSync(TRAIN_PRESALE_PENDING_TASK_KEY, '')).trim();
  if (pendingAfterTaskFlush !== taskId) {
    return { task: tasks[index], cleared: false };
  }
  store.deleteSync(TRAIN_PRESALE_PENDING_TASK_KEY);
  store.flushSync();
  return { task: tasks[index], cleared: true };
}

export function transitionBoundTrainPresaleCheckout(
  store: preferences.Preferences,
  boundCheckoutTaskId: string,
  closingTaskId: string,
  reason: string
): TrainPresaleHandoffTransitionResult {
  if (boundCheckoutTaskId.length === 0 || closingTaskId !== boundCheckoutTaskId) {
    return { task: undefined, cleared: false };
  }
  return transitionTrainPresaleHandoff(store, closingTaskId, 'needs_user', reason);
}

export default class EntryAbility extends UIAbility {
  private mainWindowStage: window.WindowStage | null = null;
  private pendingWaterfallShareUrl: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.pendingWaterfallShareUrl = waterfallShareUrlFromWant(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    loadProviderRuntimeConfig(this.context, true);
    this.loadPersonaPacks();
    this.handleOAuthWant(want);
    this.claimTrainPresaleTask(want);
    queueBimSentinelMockFromWant(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  private rawfileText(path: string): string {
    const bytes = this.context.resourceManager.getRawFileContentSync(path);
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(bytes);
  }

  private optionalRawfileText(path: string): string {
    try {
      return this.rawfileText(path);
    } catch (_err) {
      return '';
    }
  }

  private loadPersonaPacks(): void {
    try {
      const files: Record<string, string> = {};
      for (let index = 0; index < PERSONA_IDS.length; index++) {
        const personaId = PERSONA_IDS[index];
        files[personaId + '/soul.md'] = this.rawfileText('personas/' + personaId + '/soul.md');
        files[personaId + '/skills.md'] = this.rawfileText('personas/' + personaId + '/skills.md');
        files[personaId + '/memory.md'] = this.rawfileText('personas/' + personaId + '/memory.md');
        const skillManifest = this.optionalRawfileText('personas/' + personaId + '/skills.json');
        if (skillManifest.length > 0) {
          files[personaId + '/skills.json'] = skillManifest;
        }
        const skillPaths = PERSONA_SKILL_PATHS[personaId];
        if (skillPaths !== undefined) {
          for (let skillIndex = 0; skillIndex < skillPaths.length; skillIndex++) {
            const skillPath = skillPaths[skillIndex];
            const skillText = this.optionalRawfileText('personas/' + personaId + '/' + skillPath);
            if (skillText.length > 0) {
              files[personaId + '/' + skillPath] = skillText;
            }
          }
        }
      }
      configurePersonaStoreFromRaw(this.rawfileText(PERSONA_MANIFEST_RAWFILE), files);
      hilog.info(DOMAIN, 'testTag', 'Loaded persona packs. count=%{public}d', PERSONA_IDS.length);
    } catch (err) {
      hilog.info(DOMAIN, 'testTag', 'Persona packs not loaded from rawfile. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    const shareUrl = waterfallShareUrlFromWant(want);
    if (shareUrl.length > 0) {
      this.loadWaterfallShare(shareUrl);
      return;
    }
    const bimSentinelMock = queueBimSentinelMockFromWant(want);
    const waterfallPrompt = waterfallConversationTypedTestPromptFromWant(want);
    const uri = oauthUriFromWant(want);
    loadProviderRuntimeConfig(this.context, !isComposioCallbackUri(uri));
    this.loadPersonaPacks();
    this.handleOAuthWant(want);
    const result = this.claimTrainPresaleTask(want);
    if (result.changed) {
      this.context.getApplicationContext().eventHub.emit(TRAIN_PRESALE_HANDOFF_EVENT);
    }
    if (bimSentinelMock) {
      this.context.getApplicationContext().eventHub.emit(BIM_SENTINEL_MOCK_EVENT);
    }
    if (waterfallPrompt.length > 0) {
      const payload: WaterfallConversationTypedTestPayload = { prompt: waterfallPrompt };
      this.context.getApplicationContext().eventHub.emit(WATERFALL_CONVERSATION_TYPED_TEST_EVENT, payload);
    }
  }

  private claimTrainPresaleTask(want: Want): TrainPresaleHandoffClaimResult {
    try {
      const ownerId: string = activeAccountOwnerId(this.context);
      if (ownerId.length === 0) {
        aiLogInfo('[AIPhone][TrainPresaleClaim] skipped=not_authenticated');
        return { taskId: '', changed: false };
      }
      const store = preferences.getPreferencesSync(this.context, {
        name: accountScopedStoreName(TRAIN_PRESALE_TASK_STORE_NAME, ownerId)
      });
      const result = claimTrainPresaleHandoff(store, new Date().toISOString(), trainPresaleTaskIdFromWant(want));
      if (result.taskId.length > 0) {
        aiLogInfo('[AIPhone][TrainPresaleClaim] taskId=' + result.taskId +
          ' changed=' + (result.changed ? 'true' : 'false'));
      }
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][TrainPresaleClaim] error=' + message.substring(0, 240));
      return { taskId: '', changed: false };
    }
  }

  private handleOAuthWant(want: Want): void {
    const directUri = want.uri === undefined ? '' : want.uri;
    const uri = oauthUriFromWant(want);
    if (isComposioCallbackUri(uri)) {
      aiLogInfo('[AIPhone][ComposioCallbackWantReceived] uriChars=' + uri.length.toString());
      return;
    }
    if (!isGmailOAuthRedirectUri(uri)) {
      const parameterKeys = gmailOAuthWantParameterKeys(want);
      if (directUri.indexOf('oauth') >= 0 || directUri.indexOf('google') >= 0 || parameterKeys.length > 0) {
        aiLogInfo('[AIPhone][GmailOAuthWantIgnored] directUriChars=' + directUri.length.toString() +
          ' directHasCode=' + (directUri.indexOf('code=') >= 0 ? 'true' : 'false') +
          ' directHasState=' + (directUri.indexOf('state=') >= 0 ? 'true' : 'false') +
          ' directHasError=' + (directUri.indexOf('error=') >= 0 ? 'true' : 'false') +
          ' parameterKeys=' + parameterKeys);
      }
      return;
    }
    const config = gmailOAuthConfigFromProvider();
    aiLogInfo('[AIPhone][GmailOAuthWantReceived] uriChars=' + uri.length.toString() +
      ' hasCode=' + (uri.indexOf('code=') >= 0 ? 'true' : 'false') +
      ' hasState=' + (uri.indexOf('state=') >= 0 ? 'true' : 'false') +
      ' hasError=' + (uri.indexOf('error=') >= 0 ? 'true' : 'false') +
      ' clientConfigured=' + (config.clientId.length > 0 ? 'true' : 'false') +
      ' secretConfigured=' + (config.clientSecret.length > 0 ? 'true' : 'false') +
      ' redirectChars=' + config.redirectUri.length.toString());
    handleGmailOAuthRedirect(new AssetCredentialStore(), gmailOAuthConfigFromProvider(), uri)
      .then(() => {
        aiLogInfo('[AIPhone][GmailOAuthWantSaved] ok=true');
        hilog.info(DOMAIN, 'testTag', '%{public}s', 'Gmail OAuth authorization saved.');
      })
      .catch((err: Error | Object | string | number | boolean | null | undefined) => {
        const message = describeError(err);
        aiLogError('[AIPhone][GmailOAuthWantFailed] ' + message);
        hilog.error(DOMAIN, 'testTag', 'Gmail OAuth callback failed. Cause: %{public}s', message);
      });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.mainWindowStage = windowStage;
    try {
      const mainWindow = windowStage.getMainWindowSync();
      let systemTopInsetVp = A2UI_SYSTEM_TOP_INSET_FALLBACK;
      let systemBottomInsetVp = A2UI_SYSTEM_BOTTOM_INSET_FALLBACK;
      try {
        const density = display.getDefaultDisplaySync().densityPixels;
        if (density > 0) {
          const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          const navigationArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          systemTopInsetVp = Math.max(0, systemArea.topRect.height / density);
          systemBottomInsetVp = Math.max(0, navigationArea.bottomRect.height / density);
        }
      } catch (error) {
        hilog.warn(DOMAIN, 'testTag', 'Failed to read system insets. Cause: %{public}s', describeError(error));
      }
      AppStorage.setOrCreate<number>(A2UI_SYSTEM_TOP_INSET_STORAGE_KEY, systemTopInsetVp);
      AppStorage.setOrCreate<number>(A2UI_SYSTEM_BOTTOM_INSET_STORAGE_KEY, systemBottomInsetVp);
      mainWindow.setWindowLayoutFullScreen(true)
        .then((): Promise<void> => {
          return mainWindow.setWindowSystemBarProperties({
            statusBarColor: '#00000000',
            statusBarContentColor: '#211B17',
            navigationBarColor: '#00000000',
            navigationBarContentColor: '#211B17'
          });
        })
        .catch((error: Error): void => {
          hilog.warn(DOMAIN, 'testTag', 'Failed to enable immersive window. Cause: %{public}s', error.message);
        });
    } catch (error) {
      hilog.warn(DOMAIN, 'testTag', 'Failed to access main window. Cause: %{public}s', describeError(error));
    }

    if (this.pendingWaterfallShareUrl.length > 0) {
      this.loadWaterfallShare(this.pendingWaterfallShareUrl);
      return;
    }
    windowStage.loadContent('pages/A2uiHome/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private loadWaterfallShare(url: string): void {
    if (this.mainWindowStage === null) {
      this.pendingWaterfallShareUrl = url;
      return;
    }
    this.pendingWaterfallShareUrl = '';
    const storage = new LocalStorage();
    storage.setOrCreate('waterfallShareUrl', url);
    this.mainWindowStage.loadContent('pages/A2uiHome/SharedWaterfallCard', storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load shared Waterfall card. Cause: %{public}s', JSON.stringify(err));
      }
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    this.mainWindowStage = null;
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    webview.WebCookieManager.saveCookieAsync()
      .catch((_error: Error) => {
        aiLogError('[AIPhone][WebCookieSaveOnBackground] ok=false');
      });
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
