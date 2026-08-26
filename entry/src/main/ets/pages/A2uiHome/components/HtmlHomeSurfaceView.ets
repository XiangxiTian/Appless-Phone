import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { A2uiAction } from '@loop/agent-core';
import { aiLogError, aiLogInfo } from '@loop/agent-core';
import { sha256Digest } from '@loop/agent-core';
import { COLOR_PAGE } from '../style/A2uiHomeTheme';

type HtmlHomeActionValue = Object | string | number | boolean | null | undefined;

type HtmlHomePostedAction = Record<string, HtmlHomeActionValue>;

const HTML_HOME_DATA_OPEN = '<script id="home-data" type="application/json">';
const HTML_HOME_DATA_CLOSE = '</script>';

function htmlHomeBodyOpenTag(html: string): string {
  const bodyStart = html.indexOf('<body');
  if (bodyStart < 0) return '';
  const bodyEnd = html.indexOf('>', bodyStart);
  return bodyEnd < 0 ? '' : html.substring(bodyStart, bodyEnd);
}

export function isHtmlHomeConversationDocument(html: string): boolean {
  const bodyTag = htmlHomeBodyOpenTag(html);
  return bodyTag.indexOf('data-view="conversation"') >= 0 ||
    bodyTag.indexOf('data-view="conversation-thinking"') >= 0;
}

export function htmlHomeDataPayload(html: string): string {
  const openIndex = html.indexOf(HTML_HOME_DATA_OPEN);
  if (openIndex < 0) return '';
  const payloadStart = openIndex + HTML_HOME_DATA_OPEN.length;
  const closeIndex = html.indexOf(HTML_HOME_DATA_CLOSE, payloadStart);
  return closeIndex < 0 ? '' : html.substring(payloadStart, closeIndex);
}

export function htmlHomeAnimatesLatestUser(html: string): boolean {
  return htmlHomeBodyOpenTag(html).indexOf('data-user-motion="enter"') >= 0;
}

export function waterfallLayerFullscreen(rendererFullscreen: boolean, popupVisible: boolean): boolean {
  return rendererFullscreen || popupVisible;
}

class HtmlHomeActionBridge {
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onWaterfallFullscreenChange: (active: boolean) => void = (_active: boolean) => {};
  onWaterfallSourceOpen: (url: string) => void = (_url: string) => {};

  postAction(raw: string): void {
    const action = parseHtmlHomeAction(raw);
    if (action !== null) {
      if (action.id === 'ride.map.route.log') {
        aiLogInfo('[AIPhone][RideMapRoute] ' + JSON.stringify(action.args));
        return;
      }
      if (action.id === 'luckin.pay.open' ||
        action.id === 'luckin.demo.alipay.open' ||
        action.id === 'luckin.demo.googlepay.open' ||
        action.id === 'luckin.order.status') {
        aiLogInfo('[AIPhone][HtmlHomePostAction] id=' + action.id +
          ' kind=' + action.kind +
          ' promptChars=' + action.prompt.length.toString());
      }
      this.onAction(action);
      return;
    }
    aiLogError('[AIPhone][HtmlHomePostActionParseError] rawChars=' + raw.length.toString());
  }

  setWaterfallFullscreen(raw: string): void {
    this.onWaterfallFullscreenChange(raw === 'true');
  }

  openWaterfallSource(raw: string): void {
    const url = raw.trim();
    if (url.startsWith('https://') || url.startsWith('http://')) this.onWaterfallSourceOpen(url);
  }
}

@Component
export struct HtmlHomeSurfaceView {
  @Prop @Watch('onHtmlOrBusyChange') html: string = '';
  @Prop @Watch('onMultiTaskPayloadChange') multiTaskPayloadJson: string = '';
  @Prop @Watch('onMultiTaskPayloadChange') multiTaskPayloadTick: number = 0;
  @Prop @Watch('onWaterfallPayloadChange') waterfallPayloadJson: string = '';
  @Prop @Watch('onWaterfallPayloadChange') waterfallPayloadTick: number = 0;
  @Prop @Watch('onWaterfallBackRequest') waterfallBackRequestTick: number = 0;
  @Prop @Watch('onMailDetailEventChange') mailDetailEventJson: string = '';
  @Prop @Watch('onMailReplyEventChange') mailReplyEventJson: string = '';
  @Prop @Watch('onMailCalendarEventChange') mailCalendarEventJson: string = '';
  @Prop @Watch('onHtmlOrBusyChange') isBusy: boolean = false;
  @Prop @Watch('onHtmlOrBusyChange') renderTick: number = 0;
  @Prop luckinInlinePatchJson: string = '';
  @Prop @Watch('onLuckinPatchTickChange') luckinInlinePatchTick: number = 0;
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onWaterfallFullscreenChange: (active: boolean) => void = (_active: boolean) => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private popupController: webview.WebviewController = new webview.WebviewController();
  private bridge: HtmlHomeActionBridge = new HtmlHomeActionBridge();
  private loadedKey: string = '';
  private loadedRenderTick: number = -1;
  private webReady: boolean = false;
  private lastMailDetailEventJson: string = '';
  private lastMailReplyEventJson: string = '';
  private lastMailCalendarEventJson: string = '';
  private lastMultiTaskPayloadJson: string = '';
  private lastMultiTaskPayloadTick: number = -1;
  private lastWaterfallPayloadJson: string = '';
  private lastWaterfallPayloadTick: number = -1;
  private appliedWaterfallBackRequestTick: number = 0;
  private waterfallPayloadPushInFlight: boolean = false;
  private appliedLuckinPatchTick: number = -1;
  private conversationPatchInFlight: boolean = false;
  private rendererWaterfallFullscreen: boolean = false;
  @State private popupVisible: boolean = false;
  @State private popupTitle: string = '支付确认';
  @State private popupUrl: string = 'about:blank';

  aboutToAppear(): void {
    this.bridge.onAction = (action: A2uiAction): void => {
      this.onAction(action);
    };
    this.bridge.onWaterfallFullscreenChange = (active: boolean): void => {
      this.rendererWaterfallFullscreen = active;
      this.publishWaterfallFullscreen();
    };
    this.bridge.onWaterfallSourceOpen = (url: string): void => {
      if (shouldOpenWaterfallSourceExternally(url)) {
        this.openExternalWaterfallSource(url);
        return;
      }
      this.popupTitle = popupTitleFromUrl(url);
      this.popupUrl = url;
      this.popupVisible = true;
      this.publishWaterfallFullscreen();
    };
  }

  private publishWaterfallFullscreen(): void {
    this.onWaterfallFullscreenChange(waterfallLayerFullscreen(
      this.rendererWaterfallFullscreen, this.popupVisible));
  }

  private async openExternalWaterfallSource(url: string): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      try {
        await context.openLink(url);
      } catch (_linkError) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: url
        });
      }
      aiLogInfo('[AIPhone][HtmlHomeWaterfallSourceExternal] ok=true urlChars=' + url.length.toString());
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeWaterfallSourceExternalError] ' + JSON.stringify(error));
      this.popupTitle = popupTitleFromUrl(url);
      this.popupUrl = url;
      this.popupVisible = true;
      this.publishWaterfallFullscreen();
    }
  }

  aboutToDisappear(): void {
    this.rendererWaterfallFullscreen = false;
    this.popupVisible = false;
    this.publishWaterfallFullscreen();
  }

  private loadHtmlIfNeeded(): void {
    if (!this.webReady) {
      return;
    }
    const patchPending = this.luckinInlinePatchTick > this.appliedLuckinPatchTick &&
      this.luckinInlinePatchJson.length > 0;
    if (patchPending && this.html === this.loadedKey && this.renderTick === this.loadedRenderTick) {
      return;
    }
    if (this.html.length === 0 ||
      (this.html === this.loadedKey && this.renderTick === this.loadedRenderTick)) {
      return;
    }
    if (this.conversationPatchInFlight) return;
    if (isHtmlHomeConversationDocument(this.loadedKey) &&
      isHtmlHomeConversationDocument(this.html) && this.tryPatchConversation()) {
      return;
    }
    this.loadFullHtml(this.html, this.renderTick);
  }

  private tryPatchConversation(): boolean {
    const targetHtml = this.html;
    const targetRenderTick = this.renderTick;
    const payload = htmlHomeDataPayload(targetHtml);
    if (payload.length === 0) return false;
    const animateUserText = htmlHomeAnimatesLatestUser(targetHtml);
    const encodedPayload = JSON.stringify(payload);
    try {
      this.conversationPatchInFlight = true;
      this.controller.runJavaScript(
        '(function(){' +
        'if(!window.__aiphoneApplyConversationUpdate){throw new Error("CONVERSATION_UPDATE_BRIDGE_MISSING");}' +
        'var applied=window.__aiphoneApplyConversationUpdate(JSON.parse(' + encodedPayload + '),' +
        (animateUserText ? 'true' : 'false') + ');' +
        'if(!applied){throw new Error("CONVERSATION_UPDATE_REJECTED");}' +
        'return "ok";' +
        '})()'
      ).then((): void => {
        this.loadedKey = targetHtml;
        this.loadedRenderTick = targetRenderTick;
        this.conversationPatchInFlight = false;
        aiLogInfo('[AIPhone][HtmlHomeConversationPatch] chars=' + targetHtml.length.toString() +
          ' contentDigest=' + sha256Digest(targetHtml) +
          ' renderTick=' + targetRenderTick.toString() +
          ' animateUserText=' + (animateUserText ? 'true' : 'false'));
        this.loadHtmlIfNeeded();
      }).catch((error: Error): void => {
        this.conversationPatchInFlight = false;
        aiLogError('[AIPhone][HtmlHomeConversationPatchError] ' + JSON.stringify(error));
        if (this.webReady && this.html.length > 0) {
          this.loadFullHtml(this.html, this.renderTick);
        }
      });
      return true;
    } catch (error) {
      this.conversationPatchInFlight = false;
      aiLogError('[AIPhone][HtmlHomeConversationPatchError] ' + JSON.stringify(error));
      return false;
    }
  }

  private loadFullHtml(targetHtml: string, targetRenderTick: number): void {
    try {
      this.webReady = false;
      this.rendererWaterfallFullscreen = false;
      this.publishWaterfallFullscreen();
      this.controller.loadData(targetHtml, 'text/html', 'UTF-8', 'https://aiphone.local/');
      this.loadedKey = targetHtml;
      this.loadedRenderTick = targetRenderTick;
      this.lastMailDetailEventJson = '';
      this.lastMailReplyEventJson = '';
      this.lastMailCalendarEventJson = '';
      this.lastMultiTaskPayloadJson = '';
      this.lastMultiTaskPayloadTick = -1;
      this.lastWaterfallPayloadJson = '';
      this.lastWaterfallPayloadTick = -1;
      this.appliedLuckinPatchTick = this.luckinInlinePatchTick;
      aiLogInfo('[AIPhone][HtmlHomeSurfaceLoad] chars=' + targetHtml.length.toString() +
        ' contentDigest=' + sha256Digest(targetHtml) +
        ' renderTick=' + targetRenderTick.toString() +
        ' busy=' + (this.isBusy ? 'true' : 'false'));
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeSurfaceLoadError] ' + JSON.stringify(error));
    }
  }

  onHtmlOrBusyChange(): void {
    this.loadHtmlIfNeeded();
  }

  onMultiTaskPayloadChange(): void {
    this.pushMultiTaskPayloadIfNeeded();
  }

  onWaterfallPayloadChange(): void {
    this.pushWaterfallPayloadIfNeeded();
  }

  onWaterfallBackRequest(): void {
    if (this.waterfallBackRequestTick <= this.appliedWaterfallBackRequestTick ||
      (!this.webReady && !this.popupVisible)) return;
    this.appliedWaterfallBackRequestTick = this.waterfallBackRequestTick;
    if (this.popupVisible) {
      if (this.popupController.accessBackward()) {
        this.popupController.backward();
      } else {
        this.popupVisible = false;
        this.popupUrl = 'about:blank';
        this.publishWaterfallFullscreen();
      }
      return;
    }
    try {
      this.controller.runJavaScript(
        'try{if(window.__aiphoneHandleWaterfallBack){window.__aiphoneHandleWaterfallBack();}}catch(e){}'
      );
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeWaterfallBackError] ' + JSON.stringify(error));
    }
  }

  private pushWaterfallPayloadIfNeeded(): void {
    if (this.waterfallPayloadJson.length === 0 ||
      (this.waterfallPayloadJson === this.lastWaterfallPayloadJson &&
        this.waterfallPayloadTick === this.lastWaterfallPayloadTick) || this.waterfallPayloadPushInFlight) {
      return;
    }
    if (!this.webReady) {
      aiLogInfo('[AIPhone][HtmlHomeWaterfallPushDeferred] tick=' + this.waterfallPayloadTick.toString() +
        ' payloadChars=' + this.waterfallPayloadJson.length.toString());
      return;
    }
    const payloadJson = this.waterfallPayloadJson;
    const payloadTick = this.waterfallPayloadTick;
    try {
      this.waterfallPayloadPushInFlight = true;
      this.controller.runJavaScript(
        'if (!window.__aiphoneApplyWaterfallUpdate) { throw new Error("WATERFALL_UPDATE_BRIDGE_MISSING"); }' +
        'window.__aiphoneApplyWaterfallUpdate(' + payloadJson + ');'
      ).then((): void => {
        this.lastWaterfallPayloadJson = payloadJson;
        this.lastWaterfallPayloadTick = payloadTick;
        this.waterfallPayloadPushInFlight = false;
        aiLogInfo('[AIPhone][HtmlHomeWaterfallPush] tick=' + payloadTick.toString() +
          ' payloadChars=' + payloadJson.length.toString());
        this.pushWaterfallPayloadIfNeeded();
      }).catch((error: Error): void => {
        this.waterfallPayloadPushInFlight = false;
        aiLogError('[AIPhone][HtmlHomeWaterfallPushError] ' + JSON.stringify(error));
        if (payloadJson !== this.waterfallPayloadJson || payloadTick !== this.waterfallPayloadTick) {
          this.pushWaterfallPayloadIfNeeded();
        }
      });
    } catch (error) {
      this.waterfallPayloadPushInFlight = false;
      aiLogError('[AIPhone][HtmlHomeWaterfallPushError] ' + JSON.stringify(error));
    }
  }

  private pushMultiTaskPayloadIfNeeded(): void {
    if (this.multiTaskPayloadJson.length === 0 ||
      (this.multiTaskPayloadJson === this.lastMultiTaskPayloadJson &&
        this.multiTaskPayloadTick === this.lastMultiTaskPayloadTick)) {
      return;
    }
    if (!this.webReady) {
      aiLogInfo('[AIPhone][HtmlHomeMultiTaskPushDeferred] tick=' + this.multiTaskPayloadTick.toString() +
        ' payloadChars=' + this.multiTaskPayloadJson.length.toString());
      return;
    }
    try {
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMultiTaskUpdate) { window.__aiphoneApplyMultiTaskUpdate(' + this.multiTaskPayloadJson + '); }'
      );
      this.lastMultiTaskPayloadJson = this.multiTaskPayloadJson;
      this.lastMultiTaskPayloadTick = this.multiTaskPayloadTick;
      aiLogInfo('[AIPhone][HtmlHomeMultiTaskPush] tick=' + this.multiTaskPayloadTick.toString() +
        ' payloadChars=' + this.multiTaskPayloadJson.length.toString());
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMultiTaskPushError] ' + JSON.stringify(error));
    }
  }

  private pushMailDetailEventIfNeeded(): void {
    if (!this.webReady || this.mailDetailEventJson.length === 0 ||
      this.mailDetailEventJson === this.lastMailDetailEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailDetailEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailDetail) { window.__aiphoneApplyMailDetail(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailDetailEventJson = this.mailDetailEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailDetailPushError] ' + JSON.stringify(error));
    }
  }

  onMailDetailEventChange(): void {
    this.pushMailDetailEventIfNeeded();
  }

  private pushMailReplyEventIfNeeded(): void {
    if (!this.webReady || this.mailReplyEventJson.length === 0 ||
      this.mailReplyEventJson === this.lastMailReplyEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailReplyEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailReply) { window.__aiphoneApplyMailReply(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailReplyEventJson = this.mailReplyEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailReplyPushError] ' + JSON.stringify(error));
    }
  }

  onMailReplyEventChange(): void {
    this.pushMailReplyEventIfNeeded();
  }

  private pushMailCalendarEventIfNeeded(): void {
    if (!this.webReady || this.mailCalendarEventJson.length === 0 ||
      this.mailCalendarEventJson === this.lastMailCalendarEventJson) {
      return;
    }
    try {
      const encoded = JSON.stringify(this.mailCalendarEventJson);
      this.controller.runJavaScript(
        'if (window.__aiphoneApplyMailCalendar) { window.__aiphoneApplyMailCalendar(JSON.parse(' + encoded + ')); }'
      );
      this.lastMailCalendarEventJson = this.mailCalendarEventJson;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeMailCalendarPushError] ' + JSON.stringify(error));
    }
  }

  onMailCalendarEventChange(): void {
    this.pushMailCalendarEventIfNeeded();
  }

  onLuckinPatchTickChange(): void {
    this.tryApplyLuckinInlinePatch();
  }

  private tryApplyLuckinInlinePatch(): boolean {
    if (!this.webReady || this.luckinInlinePatchTick <= this.appliedLuckinPatchTick ||
      this.luckinInlinePatchJson.length === 0) {
      return false;
    }
    this.appliedLuckinPatchTick = this.luckinInlinePatchTick;
    let script = '';
    try {
      const parsed = JSON.parse(this.luckinInlinePatchJson) as Record<string, Object | string | number | boolean | null | undefined>;
      if (parsed.kind === 'food-menu') {
        script = 'try{if(window.AIPhoneFoodMenu&&AIPhoneFoodMenu.applyPatch){AIPhoneFoodMenu.applyPatch(' +
          JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
      } else if (parsed.kind === 'payment-status') {
        const sectionId = typeof parsed.sectionId === 'string' ? parsed.sectionId.trim() : '';
        if (sectionId.length > 0) {
          script = 'try{if(window.__aiphonePatchEmbeddedLuckinPaymentStatus){window.__aiphonePatchEmbeddedLuckinPaymentStatus(' +
            JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
        } else {
          script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinPaymentStatus){AIPhoneHome.patchLuckinPaymentStatus(' +
            JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
        }
      } else {
        script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinConfirm){AIPhoneHome.patchLuckinConfirm(' +
          JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
      }
    } catch (_error) {
      script = 'try{if(window.AIPhoneHome&&AIPhoneHome.patchLuckinConfirm){AIPhoneHome.patchLuckinConfirm(' +
        JSON.stringify(this.luckinInlinePatchJson) + ');}}catch(e){}';
    }
    try {
      this.controller.runJavaScript(script);
      aiLogInfo('[AIPhone][HtmlHomeLuckinPatch] tick=' + this.luckinInlinePatchTick.toString());
      return true;
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeLuckinPatchError] ' + JSON.stringify(error));
      this.clearLuckinOptionUpdating();
      return false;
    }
  }

  private clearLuckinOptionUpdating(): void {
    try {
      this.controller.runJavaScript('try{if(window.AIPhoneHome&&AIPhoneHome.clearLuckinOptionUpdating){AIPhoneHome.clearLuckinOptionUpdating();}}catch(e){}');
    } catch (error) {
      aiLogError('[AIPhone][HtmlHomeLuckinUpdatingClearError] ' + JSON.stringify(error));
    }
  }

  private async collectHotelSmokeEvidence(): Promise<void> {
    try {
      const evidence = await this.controller.runJavaScript(
        "try{typeof window.collectHotelSmokeEvidence==='function'?window.collectHotelSmokeEvidence():''}catch(e){''}"
      );
      if (evidence.length > 0) {
        aiLogInfo('[AIPhone][HotelHomeActionEvidence] evidence=' + evidence);
      }
    } catch (error) {
      aiLogError('[AIPhone][HotelHomeActionEvidenceError] ' + JSON.stringify(error));
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Web({
        src: 'data:text/html;charset=utf-8,<body style="margin:0;background:transparent"></body>',
        controller: this.controller
      })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mediaPlayGestureAccess(false)
        .multiWindowAccess(true)
        .allowWindowOpenMethod(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'AIPhoneHome',
          // Synchronous proxy calls block the page's JS thread on a cross-process round trip,
          // which stalls scrolling and taps. None of these results are read from the page.
          methodList: [],
          asyncMethodList: ['postAction', 'setWaterfallFullscreen', 'openWaterfallSource'],
          controller: this.controller
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#00000000')
        .opacity(1)
        .onPageEnd(() => {
          this.webReady = true;
          this.loadHtmlIfNeeded();
          this.pushMultiTaskPayloadIfNeeded();
          this.pushWaterfallPayloadIfNeeded();
          this.onWaterfallBackRequest();
          this.pushMailDetailEventIfNeeded();
          this.pushMailReplyEventIfNeeded();
          this.pushMailCalendarEventIfNeeded();
          this.collectHotelSmokeEvidence();
        })
        .onWindowNew((event: OnWindowNewEvent) => {
          this.popupTitle = popupTitleFromUrl(event.targetUrl);
          this.popupUrl = 'about:blank';
          this.popupVisible = true;
          this.publishWaterfallFullscreen();
          event.handler.setWebController(this.popupController);
          aiLogInfo('[AIPhone][HtmlHomeWindowNew] targetChars=' + event.targetUrl.length.toString() +
            ' userTrigger=' + event.isUserTrigger.toString());
        })

      if (this.popupVisible) {
        Column() {
          Row() {
            Column() {
              Text(this.popupTitle)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#211B17')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(popupSubtitleFromTitle(this.popupTitle))
                .fontSize(12)
                .fontColor('#786E66')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 3 })
            }
            .layoutWeight(1)

            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.icon_back'))
                .width(20)
                .height(20)
            }
              .height(44)
              .width(44)
              .backgroundColor('#F5F2EE')
              .borderRadius(22)
              .accessibilityText('返回')
              .onClick(() => {
                if (this.popupController.accessBackward()) {
                  this.popupController.backward();
                } else {
                  this.popupVisible = false;
                  this.popupUrl = 'about:blank';
                  this.publishWaterfallFullscreen();
                }
              })
          }
          .width('100%')
          .height(64)
          .padding({ left: 14, right: 12 })
          .alignItems(VerticalAlign.Center)
          .backgroundColor('#FFFAF4')

          Web({ src: this.popupUrl, controller: this.popupController })
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .multiWindowAccess(true)
            .allowWindowOpenMethod(true)
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(COLOR_PAGE)
            .onWindowExit(() => {
              this.popupVisible = false;
              this.popupUrl = 'about:blank';
              this.publishWaterfallFullscreen();
              aiLogInfo('[AIPhone][HtmlHomeWindowExit]');
            })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(COLOR_PAGE)
      }

    }
      .width('100%')
      .height('100%')
      .backgroundColor('#00000000')
  }
}

export function parseHtmlHomeAction(raw: string): A2uiAction | null {
  try {
    const parsed = JSON.parse(raw) as HtmlHomePostedAction;
    const keys = Object.keys(parsed);
    if (keys.indexOf('id') < 0 || keys.indexOf('label') < 0 ||
      keys.indexOf('prompt') < 0 || keys.indexOf('kind') < 0) {
      return null;
    }
    const action: A2uiAction = {
      id: actionText(parsed['id']),
      label: actionText(parsed['label']),
      prompt: actionText(parsed['prompt']),
      variant: actionText(parsed['variant']),
      kind: actionText(parsed['kind']),
      args: actionObject(parsed['args'])
    };
    const sourceSectionId = typeof parsed['sourceSectionId'] === 'string' ?
      (parsed['sourceSectionId'] as string).trim() : '';
    if (sourceSectionId.length > 0) {
      action.sourceSectionId = sourceSectionId;
    }
    return action;
  } catch (error) {
    return null;
  }
}

function actionText(value: HtmlHomeActionValue): string {
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

function actionObject(value: HtmlHomeActionValue): Object | undefined {
  if (value === undefined || value === null || typeof value !== 'object') {
    return undefined;
  }
  return value;
}

export function shouldOpenWaterfallSourceExternally(raw: string): boolean {
  const url = raw.trim().toLowerCase();
  return url.startsWith('https://b23.tv/') || url.startsWith('http://b23.tv/') ||
    url.startsWith('https://bilibili.com/') || url.startsWith('http://bilibili.com/') ||
    url.startsWith('https://www.bilibili.com/') || url.startsWith('http://www.bilibili.com/') ||
    url.startsWith('https://m.bilibili.com/') || url.startsWith('http://m.bilibili.com/');
}

export function popupTitleFromUrl(url: string): string {
  const lower = url.toLowerCase();
  if (lower.indexOf('google.com/maps/') >= 0 || lower.indexOf('maps.google.com/') >= 0) {
    return 'Google Maps 路线';
  }
  if (lower.indexOf('google') >= 0 || lower.indexOf('gpay') >= 0) {
    return 'Google Pay 确认';
  }
  if (lower.indexOf('paypal') >= 0) {
    return 'PayPal 确认';
  }
  if (lower.indexOf('checkout.stripe.com/') >= 0 || lower.indexOf('alipay') >= 0) {
    return '支付确认';
  }
  return '内容详情';
}

export function popupSubtitleFromTitle(title: string): string {
  if (title === 'Google Maps 路线') {
    return '路线由 Google Maps 实时提供';
  }
  return title === '内容详情' ? '来自原始来源' : '安全确认页面';
}
