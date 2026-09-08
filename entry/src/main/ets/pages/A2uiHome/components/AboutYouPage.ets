import { webview } from '@kit.ArkWeb';
import { util } from '@kit.ArkTS';
import { aiLogInfo, aiLogError } from '@loop/agent-core';
import { AboutYouAction, AboutYouViewModel, parseAboutYouAction, aboutYouAllowsNavigation } from './AboutYouPageModel';
import { buildAboutYouDocumentUrl, buildAboutYouUpdate } from '../html/AboutYouRenderer';

class AboutYouBridge {
  receive: (raw: string) => void = (_raw: string): void => {};
  postAction(raw: string): void { this.receive(raw); }
}

interface AboutYouPlatformResource {
  platform: string;
  resource: Resource;
  mime: string;
}

let aboutYouCachedPlatformLogos: Record<string, string> | null = null;

@Component
export struct AboutYouPage {
  @StorageProp('a2uiSystemTopInsetVp') @Watch('pushModel') systemTopInsetVp: number = 24;
  @StorageProp('a2uiSystemBottomInsetVp') @Watch('pushModel') systemBottomInsetVp: number = 12;
  @Prop @Watch('pushModel') viewModelJson: string = '';
  onAction: (action: AboutYouAction) => void = (_action: AboutYouAction): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: AboutYouBridge = new AboutYouBridge();
  private token: string = Date.now().toString(36) + Math.random().toString(36).slice(2);
  private documentSource: string = buildAboutYouDocumentUrl(this.token);
  private loaded: boolean = false;
  private ready: boolean = false;
  private alive: boolean = false;
  private pushing: boolean = false;
  private pendingScript: string = '';

  aboutToAppear(): void {
    this.alive = true;
    this.loadPlatformLogos();
    this.bridge.receive = (raw: string): void => {
      if (!this.alive || !this.loaded) return;
      const action = parseAboutYouAction(raw, this.token);
      if (action === null) return;
      if (action.type === 'ready') {
        aiLogInfo('[AIPhone][AboutYouWeb] bridge_ready');
        this.ready = true;
        this.pushModel();
      } else if (this.ready) {
        this.onAction(action);
      }
    };
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.ready = false;
    this.bridge.receive = (_raw: string): void => {};
  }

  pushModel(): void {
    if (!this.alive || !this.ready) return;
    let presentationJson = this.viewModelJson;
    try {
      const model = JSON.parse(this.viewModelJson) as AboutYouViewModel;
      model.platformLogos = aboutYouCachedPlatformLogos ?? {};
      presentationJson = JSON.stringify(model);
    } catch (_error) {
      aiLogError('[AIPhone][AboutYouWeb] presentation_parse_failed');
    }
    this.pendingScript = buildAboutYouUpdate(presentationJson, this.systemTopInsetVp, this.systemBottomInsetVp);
    this.drainModel();
  }

  private loadPlatformLogos(): void {
    if (aboutYouCachedPlatformLogos !== null) return;
    const context = this.getUIContext().getHostContext();
    if (context === undefined) return;
    const resources: AboutYouPlatformResource[] = [
      { platform: 'bilibili', resource: $r('app.media.logo_bilibili'), mime: 'image/svg+xml' },
      { platform: 'zhihu', resource: $r('app.media.logo_zhihu'), mime: 'image/svg+xml' },
      { platform: 'weibo', resource: $r('app.media.logo_weibo'), mime: 'image/svg+xml' },
      { platform: 'github', resource: $r('app.media.logo_github'), mime: 'image/svg+xml' },
      { platform: 'x', resource: $r('app.media.logo_x'), mime: 'image/svg+xml' },
      { platform: 'youtube', resource: $r('app.media.logo_youtube'), mime: 'image/svg+xml' },
      { platform: 'linkedin', resource: $r('app.media.logo_linkedin'), mime: 'image/svg+xml' },
      { platform: 'douban', resource: $r('app.media.logo_douban'), mime: 'image/png' },
      { platform: 'steam', resource: $r('app.media.logo_steam'), mime: 'image/svg+xml' }
    ];
    const logos: Record<string, string> = {};
    const encoder = new util.Base64Helper();
    for (let index = 0; index < resources.length; index++) {
      const entry = resources[index];
      try {
        const bytes = context.resourceManager.getMediaContentSync(entry.resource.id);
        logos[entry.platform] = 'data:' + entry.mime + ';base64,' + encoder.encodeToStringSync(bytes);
      } catch (_error) {
        aiLogInfo('[AIPhone][AboutYouWeb] platform_logo_unavailable platform=' + entry.platform);
      }
    }
    aboutYouCachedPlatformLogos = logos;
  }

  private verifyDocumentReady(): void {
    if (!this.alive || !this.loaded) return;
    this.controller.runJavaScript('Boolean(window.AboutYou && typeof window.AboutYou.receive === "function")')
      .then((result: string): void => {
        if (!this.alive) return;
        if (result === 'true') {
          this.ready = true;
          aiLogInfo('[AIPhone][AboutYouWeb] document_ready');
          this.pushModel();
        } else {
          aiLogInfo('[AIPhone][AboutYouWeb] document_not_ready');
        }
      }).catch((_error: Error): void => {
        aiLogError('[AIPhone][AboutYouWeb] document_probe_failed');
      });
  }

  private drainModel(): void {
    if (this.pushing || !this.alive || !this.ready || this.pendingScript.length === 0) return;
    const script = this.pendingScript;
    this.pendingScript = '';
    this.pushing = true;
    this.controller.runJavaScript(script).then((result: string): void => {
      if (result !== 'true') aiLogError('[AIPhone][AboutYouWeb] payload_not_applied');
    }).catch((_error: Error): void => {
      aiLogError('[AIPhone][AboutYouWeb] payload_apply_failed');
    }).finally((): void => {
      this.pushing = false;
      this.drainModel();
    });
  }

  build() {
    Stack() {
      Image($r('app.media.home_light_aurora_background'))
        .width('100%').height('100%').objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None)
      Web({ src: this.documentSource, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(false)
        .fileAccess(false)
        .multiWindowAccess(false)
        .allowWindowOpenMethod(false)
        .javaScriptProxy({ object: this.bridge, name: 'AboutYouHost', methodList: [],
          asyncMethodList: ['postAction'], controller: this.controller })
        .onControllerAttached((): void => {
          aiLogInfo('[AIPhone][AboutYouWeb] controller_attached');
          this.loaded = true;
        })
        .onPageEnd(() => {
          this.verifyDocumentReady();
        })
        .onLoadIntercept((event) => {
          if (event === undefined || event === null) return true;
          const url = event.data.getRequestUrl();
          const allowed = aboutYouAllowsNavigation(url, this.documentSource);
          if (!allowed) {
            const colon = url.indexOf(':');
            const scheme = colon >= 0 ? url.slice(0, Math.min(colon, 16)) : 'unknown';
            // Log only scheme and length; data URLs contain the document and bridge token.
            aiLogInfo('[AIPhone][AboutYouWeb] navigation_blocked scheme=' + scheme +
              ' urlLength=' + url.length.toString());
          }
          return !allowed;
        })
        .width('100%').height('100%').backgroundColor('#00000000')
    }.width('100%').height('100%')
  }
}
