import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { waterfallPreferencePromptExample } from '../waterfall/WaterfallConversation';

const HOME_GLASS_BACKGROUND: string = '#B8FFFFFF';
const HOME_GLASS_EDGE: string = '#E9DED5';
const HOME_GLASS_SHADOW: string = '#248C6A53';
const HOME_SEND_INACTIVE_BACKGROUND: string = '#C9C4BF';
const HOME_SEND_ACTIVE_BACKGROUND: string = '#995F4C';
const HOME_SEND_SHADOW: string = '#38995F4C';

@Component
export struct WaterfallVoiceDock {
  @Link inputText: string;
  @Prop isListening: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop message: string = '';
  @Prop tags: string[] = [];
  @Prop selectedTags: string[] = [];
  @State private pressed: boolean = false;
  @State private addingTag: boolean = false;
  onStart: () => void = () => {};
  onStop: () => void = () => {};
  onSubmit: (text: string) => void = (_text: string): void => {};
  onTag: (tag: string) => void = (_tag: string): void => {};
  onAddTag: (tag: string) => void = (_tag: string): void => {};

  private placeholder(): string {
    if (this.addingTag) return '输入一个兴趣标签';
    if (this.isListening) return this.message.trim().length > 0 ? this.message.trim() : '我在听';
    if (this.isBusy) return '正在理解';
    if (this.message.trim().length > 0) return this.message.trim();
    return waterfallPreferencePromptExample(this.selectedTags, this.tags);
  }

  private selected(tag: string): boolean {
    return this.selectedTags.indexOf(tag) >= 0;
  }

  private submit(): void {
    const text = this.inputText.trim();
    if (text.length === 0 || this.isBusy) return;
    this.inputText = '';
    if (this.addingTag) {
      this.addingTag = false;
      this.onAddTag(text);
      return;
    }
    this.onSubmit(text);
  }

  private handleMicTouch(event: TouchEvent): void {
    if (this.isBusy || this.inputText.trim().length > 0 || this.addingTag) return;
    if (event.type === TouchType.Down) {
      this.pressed = true;
      if (!this.isListening) this.onStart();
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      const shouldStop = this.pressed || this.isListening;
      this.pressed = false;
      if (shouldStop) this.onStop();
    }
  }

  build() {
    Column() {
      Scroll() {
        Row({ space: 7 }) {
          ForEach(this.tags, (tag: string) => {
            Text(tag)
              .height(29)
              .fontSize(12)
              .fontWeight(this.selected(tag) ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.selected(tag) ? COLOR_ACCENT_DEEP : COLOR_TEXT)
              .padding({ left: 12, right: 12 })
              .backgroundColor(this.selected(tag) ? COLOR_ACCENT_SOFT : HOME_GLASS_BACKGROUND)
              .border({ width: 1, color: this.selected(tag) ? COLOR_ACCENT : HOME_GLASS_EDGE })
              .borderRadius(18)
              .animation({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut })
              .accessibilityText(tag + (this.selected(tag) ? '，已增加推荐，点击恢复正常' : '，点击增加推荐'))
              .onClick((): void => {
                if (!this.isBusy) this.onTag(tag);
              })
          }, (tag: string): string => tag)

          Text(this.addingTag ? '取消' : '+')
            .height(29)
            .fontSize(this.addingTag ? 12 : 18)
            .fontColor(this.addingTag ? COLOR_ACCENT_DEEP : COLOR_MUTED)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.addingTag ? COLOR_ACCENT_SOFT : HOME_GLASS_BACKGROUND)
            .border({ width: 1, color: this.addingTag ? COLOR_ACCENT : HOME_GLASS_EDGE })
            .borderRadius(18)
            .accessibilityText(this.addingTag ? '取消添加兴趣标签' : '添加兴趣标签')
            .onClick((): void => {
              if (this.isBusy) return;
              this.addingTag = !this.addingTag;
              this.inputText = '';
            })
        }
        .height(36)
        .padding({ left: 2, right: 2 })
      }
      .width('100%')
      .height(36)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)

      Row() {
        TextArea({ placeholder: this.placeholder(), text: this.inputText })
          .layoutWeight(1)
          .height(44)
          .maxLines(2)
          .fontSize(16)
          .lineHeight(24)
          .fontColor(COLOR_TEXT)
          .textAlign(this.inputText.trim().length === 0 ? TextAlign.Center : TextAlign.Start)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor('#00000000')
          .border({ width: 0 })
          .padding({ left: 10, right: 0, top: 6, bottom: 8 })
          .enterKeyType(EnterKeyType.Send)
          .enabled(!this.isBusy && !this.isListening)
          .onChange((value: string): void => {
            if (!this.isBusy) this.inputText = value;
          })
          .onSubmit((): void => {
            this.submit();
          })

        Stack({ alignContent: Alignment.Center }) {
          Image(this.inputText.trim().length > 0 || this.addingTag ?
            $r('app.media.arrow_up') : $r('app.media.icon_microphone'))
            .width(18)
            .height(18)
            .fillColor(this.inputText.trim().length > 0 || this.addingTag ? '#FFFFFF' :
              (this.isListening || this.pressed ? COLOR_ACCENT_DEEP : '#FFFFFF'))
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor(this.inputText.trim().length > 0 || this.addingTag ? HOME_SEND_ACTIVE_BACKGROUND :
          (this.isListening || this.pressed ? COLOR_ACCENT_SOFT : HOME_SEND_INACTIVE_BACKGROUND))
        .shadow({
          radius: this.inputText.trim().length > 0 || this.addingTag ? 10 : 0,
          color: this.inputText.trim().length > 0 || this.addingTag ? HOME_SEND_SHADOW : '#00000000'
        })
        .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
        .animation({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut })
        .opacity(this.isBusy ? 0.55 : 1)
        .enabled(!this.isBusy)
        .accessibilityText(this.inputText.trim().length > 0 || this.addingTag ? '发送' : '按住语音输入')
        .onClick((): void => {
          if (this.inputText.trim().length > 0 || this.addingTag) this.submit();
        })
        .onTouch((event: TouchEvent): void => {
          this.handleMicTouch(event);
        })
      }
      .width('100%')
      .height(54)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 8, right: 8, top: 5, bottom: 5 })
      .backgroundColor(HOME_GLASS_BACKGROUND)
      .border({ width: 1, color: HOME_GLASS_EDGE })
      .borderRadius(28)
      .shadow({ radius: 18, color: HOME_GLASS_SHADOW, offsetX: 0, offsetY: 7 })
      .margin({ top: 7 })
    }
    .width('100%')
  }
}
