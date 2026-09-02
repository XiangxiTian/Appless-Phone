import { AccountSessionStore, requireGlobalAccountSessionStore } from './AccountSessionStore';
import { AccountSessionStatus } from './AccountModels';

@Component
export struct HuaweiAccountLoginPage {
  accountSessionStore: AccountSessionStore | null = null;
  onLoginSuccess: (ownerId: string) => void = (_ownerId: string): void => {};
  @State private isBusy: boolean = false;
  @State private errorMessage: string = '';

  private store(): AccountSessionStore {
    return this.accountSessionStore === null ? requireGlobalAccountSessionStore() : this.accountSessionStore;
  }

  private async login(): Promise<void> {
    if (this.isBusy) {
      return;
    }
    this.isBusy = true;
    this.errorMessage = '';
    try {
      const snapshot = await this.store().login();
      if (snapshot.status === AccountSessionStatus.AUTHENTICATED && snapshot.ownerId.length > 0) {
        this.onLoginSuccess(snapshot.ownerId);
      } else {
        this.errorMessage = snapshot.errorMessage.length > 0 ? snapshot.errorMessage : '登录未完成，请重试。';
      }
    } catch (_error) {
      this.errorMessage = '登录组件尚未完成初始化。';
    } finally {
      this.isBusy = false;
    }
  }

  build() {
    Column({ space: 18 }) {
      Text('登录 Appless')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2329')

      Text('使用设备上的华为账号继续。账号标识只用于本机数据隔离。')
        .fontSize(14)
        .fontColor('#646A73')
        .textAlign(TextAlign.Center)
        .lineHeight(21)

      Button(this.isBusy ? '登录中…' : '使用华为账号登录')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#CF0A2C')
        .borderRadius(24)
        .enabled(!this.isBusy)
        .onClick((): void => {
          this.login();
        })

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(13)
          .fontColor('#B42318')
          .textAlign(TextAlign.Center)
          .lineHeight(19)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 28, right: 28, bottom: 36 })
    .backgroundColor('#F7F8FA')
  }
}
