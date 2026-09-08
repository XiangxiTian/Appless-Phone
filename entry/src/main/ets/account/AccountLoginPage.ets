import { AccountSessionStore, requireGlobalAccountSessionStore } from './AccountSessionStore';
import { AccountSessionSnapshot, AccountSessionStatus } from './AccountModels';
import { HuaweiAccountPublicError } from './HuaweiAccountService';

@Component
export struct AccountLoginPage {
  accountSessionStore: AccountSessionStore | null = null;
  @Prop binding: boolean = false;
  onBack: () => void = (): void => {};
  onLoginSuccess: (ownerId: string) => void = (_ownerId: string): void => {};
  @State private isBusy: boolean = false;
  @State private sendingCode: boolean = false;
  @State private phoneMode: boolean = false;
  @State private phone: string = '';
  @State private code: string = '';
  @State private accepted: boolean = false;
  @State private secondsLeft: number = 0;
  @State private errorMessage: string = '';
  @State private statusMessage: string = '';
  private timer: number = -1;
  private retryAt: number = 0;

  private store(): AccountSessionStore {
    return this.accountSessionStore === null ? requireGlobalAccountSessionStore() : this.accountSessionStore;
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) clearInterval(this.timer);
  }

  private consent(): boolean {
    if (this.accepted) return true;
    this.errorMessage = '请先阅读并同意手机号登录说明。';
    return false;
  }

  private async sendCode(): Promise<void> {
    if (this.isBusy || this.sendingCode || Date.now() < this.retryAt || !this.consent()) return;
    this.sendingCode = true;
    this.errorMessage = '';
    this.statusMessage = '';
    try {
      const interval = await this.store().requestPhoneCode(this.phone);
      this.retryAt = Date.now() + interval * 1000;
      this.secondsLeft = interval;
      this.statusMessage = `验证码已发送至 ${this.phone.slice(0, 3)}****${this.phone.slice(-4)}，请查看短信。`;
      if (this.timer >= 0) clearInterval(this.timer);
      this.timer = setInterval(() => {
        this.secondsLeft = Math.max(0, Math.ceil((this.retryAt - Date.now()) / 1000));
        if (this.secondsLeft === 0) { clearInterval(this.timer); this.timer = -1; }
      }, 1000);
    } catch (error) {
      this.errorMessage = error instanceof HuaweiAccountPublicError ? error.message : '验证码发送失败，请稍后重试。';
    } finally { this.sendingCode = false; }
  }

  private async login(method: string): Promise<void> {
    if (this.isBusy || this.sendingCode || method !== 'huawei' && !this.consent()) return;
    this.isBusy = true;
    this.errorMessage = '';
    this.statusMessage = '';
    try {
      let snapshot: AccountSessionSnapshot;
      if (method === 'phone') {
        snapshot = this.binding ? await this.store().bindPhone(this.phone, this.code) :
          await this.store().loginPhone(this.phone, this.code);
      } else { snapshot = await this.store().login(); }
      if (snapshot.status === AccountSessionStatus.AUTHENTICATED && snapshot.ownerId.length > 0) {
        this.code = '';
        this.onLoginSuccess(snapshot.ownerId);
      } else {
        this.errorMessage = snapshot.errorMessage || '登录未完成，请重试。';
      }
    } catch (error) {
      this.errorMessage = error instanceof HuaweiAccountPublicError ? error.message : '操作失败，请稍后重试。';
    } finally { this.isBusy = false; }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text(this.binding ? '绑定手机号' : this.phoneMode ? '手机号登录' : '登录 Appless')
          .fontSize(26).fontWeight(FontWeight.Bold).fontColor('#1F2329')

        Text(this.binding ? '为当前账号添加一种登录方式，原有内容不变。' : this.phoneMode ?
          '未注册的手机号验证后将自动注册。' : '选择登录方式，继续使用 Appless。')
          .fontSize(14).fontColor('#646A73').textAlign(TextAlign.Center).lineHeight(21)

        if (this.phoneMode || this.binding) {
          TextInput({ text: this.phone, placeholder: '请输入手机号' })
            .width('100%').height(48).type(InputType.PhoneNumber).maxLength(11)
            .fontSize(16).backgroundColor('#E8EAED').borderRadius(24)
            .accessibilityText('中国大陆手机号')
            .enabled(!this.isBusy && !this.sendingCode)
            .onChange((value: string) => { this.phone = value; this.code = ''; this.statusMessage = ''; })
          Row({ space: 8 }) {
            TextInput({ text: this.code, placeholder: '短信验证码' })
              .layoutWeight(1).height(48).type(InputType.Number).maxLength(8)
              .fontSize(16).backgroundColor('#E8EAED').borderRadius(24)
              .enabled(!this.isBusy && !this.sendingCode)
              .onChange((value: string) => { this.code = value; })
            Button(this.sendingCode ? '发送中…' : this.secondsLeft > 0 ? `${this.secondsLeft} 秒后重发` : '获取验证码')
              .height(44).fontSize(13).fontColor('#CF0A2C').backgroundColor(Color.Transparent)
              .enabled(!this.isBusy && !this.sendingCode && this.secondsLeft === 0 && /^1[3-9][0-9]{9}$/.test(this.phone))
              .onClick(() => { this.sendCode(); })
          }.width('100%')
          Button(this.isBusy ? '验证中…' : this.binding ? '确认绑定' : '登录')
            .width('100%').height(48).fontSize(16).fontColor(Color.White)
            .backgroundColor('#CF0A2C').borderRadius(24)
            .enabled(!this.isBusy && !this.sendingCode && /^1[3-9][0-9]{9}$/.test(this.phone) && /^[0-9]{4,8}$/.test(this.code))
            .onClick(() => { this.login('phone'); })

          Row({ space: 4 }) {
            Checkbox({ name: 'account-consent' }).select(this.accepted)
              .selectedColor('#CF0A2C').width(18).height(18)
              .enabled(!this.isBusy && !this.sendingCode)
              .accessibilityText('同意手机号登录说明')
              .onChange((checked: boolean) => { this.accepted = checked; })
            Text('我已阅读并同意').fontSize(12).fontColor('#646A73')
            Text('手机号登录说明').fontSize(12).fontColor('#CF0A2C')
              .onClick(() => {
                AlertDialog.show({
                  title: '手机号登录说明',
                  message: '为完成登录或绑定，我们会使用你的手机号并通过短信验证身份。华为认证服务负责验证，阿里云短信认证服务负责发送验证码，当前短信签名为“恒创联众”。未注册的手机号验证成功后将自动注册。请勿将验证码告知他人。',
                  confirm: { value: '知道了', action: () => {} }
                });
              })
          }.width('100%').justifyContent(FlexAlign.Center)

          if (!this.binding) {
            Text('已绑定手机号可直接登录原账号。首次添加手机号，请先用华为账号登录，再到用户管理中绑定。')
              .fontSize(12).fontColor('#646A73').textAlign(TextAlign.Center).lineHeight(18)
          }
          Button(this.binding ? '返回' : '其他登录方式')
            .fontSize(14).fontColor('#646A73').backgroundColor(Color.Transparent)
            .enabled(!this.isBusy && !this.sendingCode)
            .onClick(() => {
              if (this.binding) this.onBack();
              else { this.phoneMode = false; this.errorMessage = ''; this.statusMessage = ''; }
            })
        } else {
          Button(this.isBusy ? '登录中…' : '使用华为账号登录')
            .width('100%').height(48).fontSize(16).fontColor(Color.White)
            .backgroundColor('#CF0A2C').borderRadius(24)
            .enabled(!this.isBusy && !this.sendingCode)
            .onClick(() => { this.login('huawei'); })
          Button('手机号登录')
            .width('100%').height(48).fontSize(16).fontColor('#1F2329')
            .backgroundColor('#E8EAED').borderRadius(24)
            .enabled(!this.isBusy && !this.sendingCode)
            .onClick(() => { this.phoneMode = true; this.errorMessage = ''; })
        }
        if (this.statusMessage.length > 0) {
          Text(this.statusMessage).fontSize(13).fontColor('#646A73').textAlign(TextAlign.Center)
        }
        if (this.errorMessage.length > 0) {
          Text(this.errorMessage).width('100%').fontSize(13).fontColor('#B42318')
            .textAlign(TextAlign.Center).lineHeight(19)
        }
      }
      .width('100%').constraintSize({ minHeight: '100%' }).justifyContent(FlexAlign.Center)
      .padding({ left: 28, right: 28, bottom: 36 })
    }.width('100%').height('100%').backgroundColor('#F7F8FA')
  }
}
