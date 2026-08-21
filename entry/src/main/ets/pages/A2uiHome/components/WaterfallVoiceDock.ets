import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_SHADOW,
  COLOR_MUTED
} from '../style/A2uiHomeTheme';

@Component
export struct WaterfallVoiceDock {
  @Prop isListening: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop message: string = '';
  @State private pressed: boolean = false;
  onStart: () => void = () => {};
  onStop: () => void = () => {};

  private label(): string {
    if (this.message.trim().length > 0) return this.message.trim();
    if (this.isListening) return '我在听';
    if (this.isBusy) return '正在调整';
    return '按住聊聊';
  }

  private fillColor(): string {
    if (this.isListening || this.pressed) return COLOR_ACCENT_SOFT;
    return COLOR_CARD;
  }

  private edgeColor(): string {
    return this.isListening ? COLOR_ACCENT : COLOR_CARD_EDGE;
  }

  private iconColor(): string {
    return this.isBusy ? COLOR_MUTED : COLOR_ACCENT_DEEP;
  }

  private handleTouch(event: TouchEvent): void {
    if (this.isBusy) return;
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
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.icon_microphone'))
        .width(20)
        .height(20)
        .fillColor(this.iconColor())
    }
    .width(48)
    .height(48)
    .borderRadius(24)
    .backgroundColor(this.fillColor())
    .border({ width: 1, color: this.edgeColor() })
    .shadow({
      radius: 4,
      color: COLOR_CARD_SHADOW,
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.pressed ? 0.96 : 1, y: this.pressed ? 0.96 : 1 })
    .animation({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut })
    .opacity(this.isBusy ? 0.72 : 1)
    .enabled(!this.isBusy)
    .hitTestBehavior(HitTestMode.Default)
    .accessibilityText(this.label())
    .onTouch((event: TouchEvent): void => {
      this.handleTouch(event);
    })
  }
}
