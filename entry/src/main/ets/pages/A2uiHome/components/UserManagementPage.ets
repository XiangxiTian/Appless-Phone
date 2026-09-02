import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_MOTION_CURVE } from '../style/A2uiHomeMotion';

const USER_PAGE_PADDING: number = 16;
const USER_CARD_RADIUS: number = 18;

export type UserDisplayNameSaveAction = 'disabled' | 'close' | 'save';

export function normalizedUserDisplayName(value: string): string {
  return value.trim();
}

export function canSaveUserDisplayName(draft: string, current: string): boolean {
  return userDisplayNameSaveAction(draft, current) === 'save';
}

export function userDisplayNameSaveAction(draft: string, current: string): UserDisplayNameSaveAction {
  const normalizedDraft = normalizedUserDisplayName(draft);
  if (normalizedDraft.length === 0) {
    return 'disabled';
  }
  return normalizedDraft === normalizedUserDisplayName(current) ? 'close' : 'save';
}

@Component
export struct UserManagementPage {
  @StorageProp('a2uiSystemTopInsetVp') systemTopInsetVp: number = 24;
  @Prop @Watch('onDisplayNameChanged') displayName: string = '华为用户';
  @Prop saveMessage: string = '';
  @Prop isSavingName: boolean = false;
  @Prop hasCustomDisplayName: boolean = false;
  @Prop showLogoutConfirm: boolean = false;
  @State nameDraft: string = '';
  @State hideSaveMessage: boolean = false;
  @State editingName: boolean = false;

  onBack: () => void = () => {};
  onSaveDisplayName: (name: string) => void = (_name: string): void => {};
  onResetDisplayName: () => void = () => {};
  onOpenSocialPersona: () => void = () => {};
  onOpenLongTermMemory: () => void = () => {};
  onRequestLogoutConfirmation: () => void = () => {};
  onCancelLogout: () => void = () => {};
  onLogout: () => void = () => {};

  aboutToAppear(): void {
    this.nameDraft = this.displayName;
  }

  private onDisplayNameChanged(): void {
    this.nameDraft = this.displayName;
    this.hideSaveMessage = false;
    this.editingName = false;
  }

  private saveName(): void {
    const action: UserDisplayNameSaveAction = userDisplayNameSaveAction(this.nameDraft, this.displayName);
    if (action === 'disabled' || this.isSavingName) {
      return;
    }
    this.editingName = false;
    if (action === 'save') {
      this.onSaveDisplayName(normalizedUserDisplayName(this.nameDraft));
    }
  }

  @Builder
  private Header() {
    Row() {
      Button('返回')
        .height(38)
        .width(72)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        .onClick(() => {
          this.onBack();
        })

      Column() {
        Text('用户管理')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text('管理你的名称、画像和本地数据')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 16 })
  }

  @Builder
  private ProfileCard() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.icon_user'))
            .width(28)
            .height(28)
            .objectFit(ImageFit.Contain)
        }
        .width(52)
        .height(52)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(26)

        if (this.editingName) {
          TextInput({ text: this.nameDraft, placeholder: '输入你的名称' })
            .layoutWeight(1)
            .height(44)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .placeholderColor(COLOR_MUTED)
            .backgroundColor(COLOR_PANEL)
            .borderRadius(12)
            .padding({ left: 13, right: 13 })
            .margin({ left: 12, right: 10 })
            .maxLength(40)
            .onChange((value: string) => {
              this.nameDraft = value;
              this.hideSaveMessage = true;
            })
            .onSubmit(() => {
              this.saveName();
            })
        } else {
          Column() {
            Text(this.displayName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('华为账号已登录')
              .fontSize(11)
              .fontColor(COLOR_ACCENT)
              .margin({ top: 5 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12, right: 10 })
        }

        Stack({ alignContent: Alignment.Center }) {
          Image(this.editingName ? $r('app.media.icon_floppy_disk') : $r('app.media.icon_pencil_line'))
            .width(21)
            .height(21)
            .objectFit(ImageFit.Contain)
        }
        .width(42)
        .height(42)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(13)
        .opacity(this.editingName && userDisplayNameSaveAction(this.nameDraft, this.displayName) === 'disabled' ?
          0.45 : 1)
        .enabled(!this.isSavingName && (!this.editingName ||
          userDisplayNameSaveAction(this.nameDraft, this.displayName) !== 'disabled'))
        .accessibilityText(this.editingName ? '保存名称' : '编辑名称')
        .onClick(() => {
          if (this.isSavingName) {
            return;
          }
          if (this.editingName) {
            this.saveName();
          } else {
            this.nameDraft = this.displayName;
            this.hideSaveMessage = true;
            this.editingName = true;
          }
        })
      }
      .width('100%')

      if (this.hasCustomDisplayName && !this.editingName) {
        Button('恢复华为账号名称')
          .height(34)
          .fontSize(12)
          .fontColor(COLOR_ACCENT)
          .backgroundColor(Color.Transparent)
          .padding({ left: 0, right: 0 })
          .margin({ top: 7 })
          .enabled(!this.isSavingName)
          .onClick(() => {
            this.hideSaveMessage = false;
            this.onResetDisplayName();
          })
      }

      if (!this.hideSaveMessage && this.saveMessage.trim().length > 0) {
        Text(this.saveMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 9 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(USER_CARD_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private ActionRow(icon: Resource, title: string, subtitle: string, destructive: boolean, onClick: () => void) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Image(icon)
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
      }
      .width(42)
      .height(42)
      .borderRadius(13)
      .backgroundColor(destructive ? COLOR_ERROR_SOFT : COLOR_ACCENT_SOFT)

      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(destructive ? COLOR_ERROR : COLOR_INK)
        Text(subtitle)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
          .maxLines(2)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12, right: 10 })

      Text('›')
        .fontSize(25)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .constraintSize({ minHeight: 76 })
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(USER_CARD_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .onClick(onClick)
  }

  @Builder
  private LogoutConfirmation() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Text('退出 Appless？')
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)

        Text('退出只会清除 Appless 的登录状态，不会退出设备上的华为账号，也不会删除这个账号的本地数据。')
          .width('100%')
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .lineHeight(21)
          .margin({ top: 12 })

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(COLOR_INK)
            .backgroundColor(COLOR_PANEL)
            .borderRadius(12)
            .onClick(() => {
              this.onCancelLogout();
            })
          Button('退出登录')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(COLOR_ERROR)
            .borderRadius(12)
            .onClick(() => {
              this.onLogout();
            })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('86%')
      .padding(20)
      .backgroundColor(COLOR_CARD)
      .borderRadius(20)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: 20, color: '#33000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 12 }) {
          this.Header()
          this.ProfileCard()

          Text('功能')
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .margin({ top: 10, left: 4 })

          this.ActionRow(
            $r('app.media.icon_social'),
            '社交账号画像',
            '确认公开账号，整理你的兴趣与偏好',
            false,
            () => {
              this.onOpenSocialPersona();
            }
          )
          this.ActionRow(
            $r('app.media.icon_sign_out'),
            '退出登录',
            '保留此账号的本地数据',
            true,
            () => {
              this.onRequestLogoutConfirmation();
            }
          )
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({
          left: USER_PAGE_PADDING,
          right: USER_PAGE_PADDING,
          top: USER_PAGE_PADDING + this.systemTopInsetVp,
          bottom: USER_PAGE_PADDING
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(COLOR_PANEL)

      if (this.showLogoutConfirm) {
        this.LogoutConfirmation()
      }
    }
    .width('100%')
    .height('100%')
  }
}
