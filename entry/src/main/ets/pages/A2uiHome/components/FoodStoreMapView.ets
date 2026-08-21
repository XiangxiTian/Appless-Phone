import { webview } from '@kit.ArkWeb';
import { aiLogError, aiLogInfo, sha256Digest } from '@loop/agent-core';
import { renderFoodStoreMapHtml } from '../html/FoodStoreMapHtmlRenderer';

type FoodStoreMapMessageValue = Object | string | number | boolean | null | undefined;

class FoodStoreMapBridge {
  onLocationConfirm: (longitude: number, latitude: number, name: string, address: string) => void =
    (_longitude: number, _latitude: number, _name: string, _address: string): void => {};

  postMessage(raw: string): void {
    try {
      const payload = JSON.parse(raw) as Record<string, FoodStoreMapMessageValue>;
      if (payload['type'] !== 'confirm') {
        return;
      }
      const longitude = Number(payload['longitude']);
      const latitude = Number(payload['latitude']);
      if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
        !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
        return;
      }
      this.onLocationConfirm(
        longitude,
        latitude,
        typeof payload['name'] === 'string' ? payload['name'] as string : '地图选点',
        typeof payload['address'] === 'string' ? payload['address'] as string : ''
      );
    } catch (error) {
      aiLogError('[AIPhone][FoodStoreMapMessageError] ' + JSON.stringify(error));
    }
  }
}

@Component
export struct FoodStoreMapView {
  @Prop amapKey: string = '';
  @Prop @Watch('onSnapshotChange') snapshotJson: string = '';
  @Prop @Watch('onSnapshotChange') snapshotTick: number = 0;
  onLocationConfirm: (longitude: number, latitude: number, name: string, address: string) => void =
    (_longitude: number, _latitude: number, _name: string, _address: string): void => {};
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: FoodStoreMapBridge = new FoodStoreMapBridge();
  private shellLoaded: boolean = false;
  private webReady: boolean = false;
  private lastSnapshotJson: string = '';
  private lastSnapshotTick: number = -1;

  aboutToAppear(): void {
    this.bridge.onLocationConfirm = this.onLocationConfirm;
  }

  private loadShellIfNeeded(): void {
    if (!this.webReady || this.shellLoaded) {
      return;
    }
    const html = renderFoodStoreMapHtml(this.amapKey);
    try {
      this.webReady = false;
      this.shellLoaded = true;
      this.controller.loadData(html, 'text/html', 'UTF-8', 'https://aiphone.local/');
      aiLogInfo('[AIPhone][FoodStoreMapLoad] chars=' + html.length.toString() +
        ' contentDigest=' + sha256Digest(html));
    } catch (error) {
      this.shellLoaded = false;
      aiLogError('[AIPhone][FoodStoreMapLoadError] ' + JSON.stringify(error));
    }
  }

  private pushSnapshotIfNeeded(): void {
    if (!this.webReady || !this.shellLoaded || this.snapshotJson.length === 0 ||
      (this.snapshotJson === this.lastSnapshotJson && this.snapshotTick === this.lastSnapshotTick)) {
      return;
    }
    const snapshotJson = this.snapshotJson;
    const snapshotTick = this.snapshotTick;
    try {
      this.controller.runJavaScript(
        'if(!window.__aiphoneApplyFoodMapSnapshot){throw new Error("FOOD_MAP_BRIDGE_MISSING");}' +
        'window.__aiphoneApplyFoodMapSnapshot(JSON.parse(' + JSON.stringify(snapshotJson) + '));'
      ).then((): void => {
        this.lastSnapshotJson = snapshotJson;
        this.lastSnapshotTick = snapshotTick;
        aiLogInfo('[AIPhone][FoodStoreMapPush] tick=' + snapshotTick.toString() +
          ' payloadChars=' + snapshotJson.length.toString());
        this.pushSnapshotIfNeeded();
      }).catch((error: Error): void => {
        aiLogError('[AIPhone][FoodStoreMapPushError] ' + JSON.stringify(error));
      });
    } catch (error) {
      aiLogError('[AIPhone][FoodStoreMapPushError] ' + JSON.stringify(error));
    }
  }

  onSnapshotChange(): void {
    this.pushSnapshotIfNeeded();
  }

  aboutToDisappear(): void {
    if (!this.webReady) {
      return;
    }
    try {
      this.controller.runJavaScript('try{if(window.__aiphoneDestroyFoodStoreMap){window.__aiphoneDestroyFoodStoreMap();}}catch(e){}');
    } catch (_error) {
    }
  }

  build() {
    Web({
      src: 'data:text/html;charset=utf-8,<body style="margin:0;background:%23f2eee8"></body>',
      controller: this.controller
    })
      .javaScriptAccess(true)
      .domStorageAccess(true)
      .javaScriptProxy({
        object: this.bridge,
        name: 'AIPhoneFoodStoreMap',
        methodList: [],
        asyncMethodList: ['postMessage'],
        controller: this.controller
      })
      .width('100%')
      .height('100%')
      .backgroundColor('#F2EEE8')
      .onPageEnd(() => {
        this.webReady = true;
        this.loadShellIfNeeded();
        this.pushSnapshotIfNeeded();
      })
  }
}
