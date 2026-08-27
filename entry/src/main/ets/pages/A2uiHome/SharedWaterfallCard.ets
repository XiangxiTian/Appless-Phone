import { webview } from '@kit.ArkWeb';

@Entry({ useSharedStorage: true })
@Component
struct SharedWaterfallCard {
  @LocalStorageProp('waterfallShareUrl') shareUrl: string = 'about:blank';
  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Row() {
        Text('Appless')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#241F1B')
        Blank()
        Button('返回首页')
          .type(ButtonType.Normal)
          .fontSize(13)
          .fontColor('#6F645C')
          .backgroundColor('#F1ECE6')
          .borderRadius(18)
          .height(36)
          .padding({ left: 14, right: 14 })
          .onClick((): void => {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/A2uiHome/Index' });
          })
      }
      .width('100%')
      .height(60)
      .padding({ left: 18, right: 14 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FBF8F3')

      Web({ src: this.shareUrl, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F5F0E9')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F0E9')
  }
}
