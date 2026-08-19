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
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.icon_microphone'))
          .width(16)
          .height(16)
          .fillColor(this.isListening ? '#FFFFFF' : '#252522')
      }
      .width(30)
      .height(30)
      .borderRadius(10)
      .backgroundColor(this.isListening ? '#FFFFFF1F' : '#E9E8E3')

      Text(this.label())
        .layoutWeight(1)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isListening ? '#F8F7F3' : '#252522')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.isListening) {
        Text('松开生效')
          .fontSize(11)
          .fontColor('#CECDC7')
      }
    }
    .width(216)
    .height(46)
    .padding({ left: 7, right: 12 })
    .backgroundColor(this.isListening ? '#252522' : '#F8F7F3')
    .border({ width: 1, color: this.isListening ? '#252522' : '#DAD9D3' })
    .borderRadius(16)
    .shadow({ radius: 8, color: '#1C262312', offsetX: 0, offsetY: 2 })
    .scale({ x: this.pressed ? 0.98 : 1, y: this.pressed ? 0.98 : 1 })
    .animation({ duration: this.reduceMotion ? 0 : 160, curve: Curve.EaseOut })
    .opacity(this.isBusy ? 0.62 : 1)
    .enabled(!this.isBusy)
    .accessibilityText(this.isListening ? '松开并应用发现流调整' : '按住聊聊，松开即应用')
    .onTouch((event: TouchEvent): void => {
      this.handleTouch(event);
    })
  }
}
