import { webview } from '@kit.ArkWeb';
import { A2uiAction, A2uiComponent, A2uiSurfaceState, LocalModelSettings, aiLogError, aiLogInfo } from '@loop/agent-core';
import router from '@ohos.router';
import { clearUiLabModelSettings, uiLabModelSettings } from './lab/UiLabRuntimeConfig';
import {
  UiAgentLabHarness,
  uiAgentLabLayoutDiagnosticText,
  UiAgentLabSurfaceEvent
} from './lab/UiAgentLabHarness';
import {
  createUiAgentLabHtmlShell,
  UiAgentLabDecisionPayload,
  UiAgentLabStatusPayload,
  uiAgentLabDecisionScript,
  uiAgentLabSurfaceScript,
  uiAgentLabStatusScript
} from './lab/UiAgentLabHtml';
import {
  UiAgentLabTheme,
  uiAgentLabThemeForToggle,
  uiAgentLabThemeScript
} from './lab/UiAgentLabTheme';

type UiAgentLabBridgeValue = Object | string | number | boolean | null | undefined;
type UiAgentLabBridgeMessage = Record<string, UiAgentLabBridgeValue>;

class UiAgentLabBridge {
  onBack: () => void = (): void => {};
  onSubmit: (prompt: string) => void = (_prompt: string): void => {};
  onAction: (componentId: string, actionIndex: number) => void =
    (_componentId: string, _actionIndex: number): void => {};
  onToggleDecisionNotes: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onToggleTheme: (enabled: boolean) => void = (_enabled: boolean): void => {};

  postMessage(raw: string): void {
    try {
      const parsed = JSON.parse(raw) as UiAgentLabBridgeMessage;
      if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return;
      }
      const keys = Object.keys(parsed).sort().join(',');
      if (keys === 'type' && parsed['type'] === 'back') {
        this.onBack();
        return;
      }
      if (keys === 'prompt,type' && parsed['type'] === 'submit' && typeof parsed['prompt'] === 'string') {
        const prompt = (parsed['prompt'] as string).trim();
        if (prompt.length > 0 && prompt.length <= 4000) {
          this.onSubmit(prompt);
        }
        return;
      }
      if (keys === 'actionIndex,componentId,type' && parsed['type'] === 'action' &&
        typeof parsed['componentId'] === 'string' && typeof parsed['actionIndex'] === 'number') {
        const componentId = (parsed['componentId'] as string).trim();
        const actionIndex = parsed['actionIndex'] as number;
        if (componentId.length > 0 && componentId.length <= 160 && Number.isSafeInteger(actionIndex) &&
          actionIndex >= 0 && actionIndex < 8) {
          this.onAction(componentId, actionIndex);
        }
        return;
      }
      if (keys === 'enabled,type' && parsed['type'] === 'toggleDecisionNotes' &&
        typeof parsed['enabled'] === 'boolean') {
        this.onToggleDecisionNotes(parsed['enabled'] as boolean);
        return;
      }
      if (keys === 'enabled,type' && parsed['type'] === 'toggleTheme' &&
        typeof parsed['enabled'] === 'boolean') {
        this.onToggleTheme(parsed['enabled'] as boolean);
      }
    } catch (_error) {
    }
  }
}

const UI_AGENT_LAB_SHELL: string = createUiAgentLabHtmlShell();
const UI_AGENT_LAB_BASE_URL: string = 'https://aiphone.local/ui-agent-lab/';

@Entry
@Component
struct UiAgentLab {
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: UiAgentLabBridge = new UiAgentLabBridge();
  private settings: LocalModelSettings = uiLabModelSettings();
  private harness: UiAgentLabHarness | null = null;
  private shellLoadStarted: boolean = false;
  private shellReady: boolean = false;
  private busy: boolean = false;
  private decisionNotesEnabled: boolean = false;
  private theme: UiAgentLabTheme = 'warm';
  private generation: number = 0;
  private pendingSurfaceJson: string = '';
  private nextSurfaceRevision: number = 0;
  private pendingSurfaceRevision: number = 0;
  // Theme application extends this same chain so it cannot race surface pushes.
  private surfacePushChain: Promise<void> = Promise.resolve();
  private currentSurface: A2uiSurfaceState | null = null;
  private pendingStatus: UiAgentLabStatusPayload = {
    state: 'ready',
    message: 'UI Agent 已就绪',
    responseChars: 0
  };
  private pendingDecision: UiAgentLabDecisionPayload = {
    enabled: false,
    text: ''
  };

  aboutToAppear(): void {
    this.settings = uiLabModelSettings();
    this.decisionNotesEnabled = false;
    this.theme = 'warm';
    this.pendingDecision = { enabled: false, text: '' };
    const lifecycleGeneration = this.generation;
    this.harness = new UiAgentLabHarness(this.settings, (event: UiAgentLabSurfaceEvent): void => {
      if (lifecycleGeneration !== this.generation) {
        return;
      }
      this.applySurfaceEvent(event);
    });
    this.bridge.onBack = (): void => {
      aiLogInfo('[AIPhone][UiAgentLabBack]');
      router.back();
    };
    this.bridge.onSubmit = (prompt: string): void => {
      this.submitPrompt(prompt);
    };
    this.bridge.onAction = (componentId: string, actionIndex: number): void => {
      this.runSurfaceAction(componentId, actionIndex);
    };
    this.bridge.onToggleDecisionNotes = (enabled: boolean): void => {
      this.toggleDecisionNotes(enabled);
    };
    this.bridge.onToggleTheme = (enabled: boolean): void => {
      this.toggleTheme(enabled);
    };
    aiLogInfo('[AIPhone][UiAgentLabAppear] model=' + this.settings.model +
      ' baseUrlChars=' + this.settings.baseUrl.length.toString());
  }

  aboutToDisappear(): void {
    this.generation++;
    const harness = this.harness;
    this.harness = null;
    if (harness !== null) {
      harness.setDecisionNotesEnabled(false);
      harness.stop();
    }
    this.shellReady = false;
    this.busy = false;
    this.decisionNotesEnabled = false;
    this.theme = 'warm';
    this.pendingDecision = { enabled: false, text: '' };
    this.pendingSurfaceJson = '';
    this.pendingSurfaceRevision = 0;
    this.currentSurface = null;
    clearUiLabModelSettings();
    aiLogInfo('[AIPhone][UiAgentLabDisappear]');
  }

  private loadShellOnce(): void {
    if (this.shellLoadStarted) {
      this.shellReady = true;
      this.pushStatus(this.pendingStatus);
      this.pushDecision(this.pendingDecision);
      this.pushTheme();
      this.pushPendingSurface();
      return;
    }
    this.shellLoadStarted = true;
    try {
      this.controller.loadData(UI_AGENT_LAB_SHELL, 'text/html', 'UTF-8', UI_AGENT_LAB_BASE_URL);
      aiLogInfo('[AIPhone][UiAgentLabShellLoad] chars=' + UI_AGENT_LAB_SHELL.length.toString());
    } catch (_error) {
      aiLogError('[AIPhone][UiAgentLabShellLoadFailed]');
    }
  }

  private pushStatus(payload: UiAgentLabStatusPayload): void {
    this.pendingStatus = payload;
    if (!this.shellReady) {
      return;
    }
    const script = uiAgentLabStatusScript(payload);
    this.controller.runJavaScript(script).catch((_error: Error): void => {
      aiLogError('[AIPhone][UiAgentLabStatusPushFailed] state=' + payload.state);
    });
  }

  private pushDecision(payload: UiAgentLabDecisionPayload): void {
    this.pendingDecision = payload;
    if (!this.shellReady) {
      return;
    }
    const script = uiAgentLabDecisionScript(payload);
    this.controller.runJavaScript(script).catch((_error: Error): void => {
      aiLogError('[AIPhone][UiAgentLabDecisionPushFailed]');
    });
  }

  private toggleDecisionNotes(enabled: boolean): void {
    if (this.busy || this.harness === null) {
      this.pushDecision(this.pendingDecision);
      return;
    }
    this.decisionNotesEnabled = this.harness.setDecisionNotesEnabled(enabled);
    this.pushDecision({
      enabled: this.decisionNotesEnabled,
      text: ''
    });
    aiLogInfo('[AIPhone][UiAgentLabDecisionToggle] enabled=' + this.decisionNotesEnabled.toString());
  }

  private toggleTheme(enabled: boolean): void {
    this.theme = uiAgentLabThemeForToggle(enabled);
    this.pushTheme();
    aiLogInfo('[AIPhone][UiAgentLabThemeToggle] theme=' + this.theme);
  }

  private enqueueShellScript(script: string, failureLog: string): void {
    const lifecycleGeneration = this.generation;
    this.surfacePushChain = this.surfacePushChain.then(async (): Promise<void> => {
      if (!this.shellReady || lifecycleGeneration !== this.generation) return;
      try {
        await this.controller.runJavaScript(script);
      } catch (_error) {
        aiLogError(failureLog);
      }
    });
  }

  private pushTheme(): void {
    if (!this.shellReady) return;
    const lifecycleGeneration = this.generation;
    const script = uiAgentLabThemeScript(this.theme, lifecycleGeneration);
    this.enqueueShellScript(
      script,
      '[AIPhone][UiAgentLabThemePushFailed] theme=' + this.theme
    );
  }

  private pushPendingSurface(): void {
    if (!this.shellReady || this.pendingSurfaceJson.length === 0) {
      return;
    }
    const revision = this.pendingSurfaceRevision;
    const lifecycleGeneration = this.generation;
    const script = uiAgentLabSurfaceScript(this.pendingSurfaceJson, revision, lifecycleGeneration);
    this.enqueueShellScript(
      script,
      '[AIPhone][UiAgentLabSurfacePushFailed] revision=' + revision.toString()
    );
    this.pushTheme();
  }

  private applySurfaceEvent(event: UiAgentLabSurfaceEvent): void {
    const surface: A2uiSurfaceState = event.surface;
    this.currentSurface = surface;
    this.pendingSurfaceJson = JSON.stringify(surface);
    this.nextSurfaceRevision++;
    this.pendingSurfaceRevision = this.nextSurfaceRevision;
    this.pushPendingSurface();
    if (surface.status === 'ready') {
      this.busy = false;
      const notes = event.decisionNotes;
      this.pushDecision({
        enabled: this.decisionNotesEnabled,
        text: this.decisionNotesEnabled && notes !== undefined && notes !== null ? notes : ''
      });
      if (event.layoutDiagnostic !== undefined) {
        this.pushStatus({
          state: 'error',
          message: uiAgentLabLayoutDiagnosticText(event.layoutDiagnostic),
          responseChars: this.pendingSurfaceJson.length
        });
      } else {
        this.pushStatus({
          state: 'success',
          message: 'UI Agent 已使用实验组件完成排版。',
          responseChars: this.pendingSurfaceJson.length
        });
      }
      aiLogInfo('[AIPhone][UiAgentLabSurface] turnChars=' + event.turnId.length.toString() +
        ' status=ready components=' + surface.components.length.toString());
      return;
    }
    if (surface.status === 'error') {
      this.busy = false;
      this.pushDecision({ enabled: this.decisionNotesEnabled, text: '' });
      this.pushStatus({
        state: 'error',
        message: 'UI Agent 排版失败，请检查模型连接。',
        responseChars: 0
      });
      aiLogError('[AIPhone][UiAgentLabSurface] status=error');
      return;
    }
    if (surface.status === 'calling_tool') {
      aiLogInfo('[AIPhone][UiAgentLabSurface] turnChars=' + event.turnId.length.toString() +
        ' status=calling_tool components=' + surface.components.length.toString());
    }
    this.pushStatus({ state: 'loading', message: 'UI Agent 正在排版…', responseChars: 0 });
  }

  private async submitPrompt(prompt: string): Promise<void> {
    if (this.busy) {
      return;
    }
    const harness = this.harness;
    if (harness === null) {
      this.pushStatus({ state: 'error', message: 'UI Agent runtime 不可用。', responseChars: 0 });
      return;
    }
    this.busy = true;
    this.pushDecision({ enabled: this.decisionNotesEnabled, text: '' });
    this.pushStatus({ state: 'loading', message: '正在提交给 UI Agent…', responseChars: 0 });
    aiLogInfo('[AIPhone][UiAgentLabSubmit] promptChars=' + prompt.length.toString());
    try {
      const outcome = await harness.submit(prompt);
      if (!outcome.ok && this.harness === harness) {
        this.busy = false;
        this.pushStatus({
          state: 'error',
          message: outcome.message.length > 0 ? outcome.message : 'UI Agent 请求未完成。',
          responseChars: 0
        });
      }
    } catch (error) {
      if (this.harness === harness) {
        this.busy = false;
        this.pushStatus({
          state: 'error',
          message: error instanceof Error ? error.message : 'UI Agent 请求失败。',
          responseChars: 0
        });
      }
    }
  }

  private trustedAction(componentId: string, actionIndex: number): A2uiAction | null {
    const surface = this.currentSurface;
    if (surface === null) return null;
    let component: A2uiComponent | null = null;
    for (let index = 0; index < surface.components.length; index++) {
      if (surface.components[index].id === componentId) {
        component = surface.components[index];
        break;
      }
    }
    if (component === null || component.actions === undefined || actionIndex >= component.actions.length) return null;
    return component.actions[actionIndex];
  }

  private async runSurfaceAction(componentId: string, actionIndex: number): Promise<void> {
    if (this.busy || this.harness === null) return;
    this.pushDecision({ enabled: this.decisionNotesEnabled, text: '' });
    const action = this.trustedAction(componentId, actionIndex);
    if (action === null || action.args === undefined) {
      this.pushStatus({ state: 'error', message: '当前操作未通过页面校验。', responseChars: 0 });
      return;
    }
    const harness = this.harness;
    this.busy = true;
    this.pushStatus({ state: 'loading', message: '正在执行「' + action.label + '」…', responseChars: 0 });
    try {
      const ok = await harness.runAction(action);
      if (this.harness === harness) {
        this.busy = false;
        this.pushStatus({
          state: ok ? 'success' : 'error',
          message: ok ? '操作已完成。' : '该操作未通过 runtime 校验。',
          responseChars: this.pendingSurfaceJson.length
        });
      }
    } catch (error) {
      if (this.harness === harness) {
        this.busy = false;
        this.pushStatus({
          state: 'error',
          message: error instanceof Error ? error.message : '操作执行失败。',
          responseChars: 0
        });
      }
    }
  }

  build() {
    Column() {
      Web({
        src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23ebe8e2"></body>',
        controller: this.controller
      })
        .javaScriptAccess(true)
        .domStorageAccess(false)
        .javaScriptProxy({
          object: this.bridge,
          name: 'UiAgentLabBridge',
          methodList: ['postMessage'],
          controller: this.controller
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#ebe8e2')
        .onPageEnd(() => {
          this.loadShellOnce();
        })
    }
    .width('100%')
    .height('100%')
  }
}
