import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

const AIOS_BASE_WIDTH: number = 430;
const AIOS_BASE_HEIGHT: number = 930;
const AIOS_BASE_TOP_INSET: number = 24;
const AIOS_BASE_BOTTOM_INSET: number = 12;
const AIOS_MAX_HORIZONTAL_SCALE: number = 1.25;
const AIOS_ACTIVITY_TITLES: string[] = ['不确定？随便刷刷', '基础对话', '出行方案规划', '周末聚餐'];
const AIOS_ACTIVITY_PROMPTS: string[] = ['', '', '帮我规划一份出行方案', '继续安排周末聚餐'];
const AIOS_ACTIVITY_COUNT: number = AIOS_ACTIVITY_TITLES.length;
const AIOS_WAVE_HEIGHTS: number[] = [8, 14, 24, 36, 28, 17, 10, 16, 30, 42, 33, 20, 12, 9, 22, 34, 18, 11, 28, 40, 25, 16, 12, 20, 32, 38, 29, 21, 14, 9];
const AIOS_SWIPE_LIMIT: number = 104;
const AIOS_SWIPE_THRESHOLD: number = 48;
const AIOS_HOLD_DELAY_MS: number = 360;
const AIOS_CLOCK_REFRESH_MS: number = 30000;
const AIOS_VOICE_PULSE_INTERVAL_MS: number = 110;
const AIOS_VOICE_PULSE_STEPS: number = 12;
const AIOS_WEEKDAYS: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
const AIOS_SURFACE_RADIUS: number = 34;
// Bottom composer visual controls. c() follows device width so the keyboard cannot shrink the composer.
const AIOS_COMPOSER_WIDTH: number = 387;
const AIOS_COMPOSER_HEIGHT: number = 61;
const AIOS_COMPOSER_RADIUS: number = AIOS_SURFACE_RADIUS;
const AIOS_COMPOSER_TEXT_SIZE: number = 20;
const AIOS_COMPOSER_ICON_SIZE: number = 27;
const AIOS_COMPOSER_ACTIVE_WIDTH: number = 399;
const AIOS_COMPOSER_ACTIVE_HEIGHT: number = 68;
const AIOS_COMPOSER_ACTIVE_RADIUS: number = AIOS_SURFACE_RADIUS;
const AIOS_COMPOSER_KEYBOARD_GAP: number = 14;
const AIOS_COMPOSER_SEND_SIZE: number = 42;
const AIOS_COMPOSER_SEND_ICON_SIZE: number = 18;
const AIOS_COMPOSER_SEND_BACKGROUND: string = '#17191D';
const AIOS_COMPOSER_SEND_SHADOW: string = '#42000000';

@Component
export struct AiosNowHomeView {
  @Prop isVoiceListening: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop systemTopInsetVp: number = 24;
  @Prop systemBottomInsetVp: number = 12;
  @State private viewportWidth: number = AIOS_BASE_WIDTH;
  @State private viewportHeight: number = AIOS_BASE_HEIGHT;
  @State private horizontalUnit: number = 1;
  @State private unit: number = 1;
  @State private originX: number = 0;
  @State private originY: number = 0;
  @State private activeActivity: number = 0;
  @State private dragX: number = 0;
  @State private dragging: boolean = false;
  @State private voiceHolding: boolean = false;
  @State private voicePulseTick: number = 0;
  @State private commandText: string = '';
  @State private keyboardHeightVp: number = 0;
  @State private greetingText: string = '你好';
  @State private dateText: string = '8 月 24 日 · 周一';
  private activityGestureActive: boolean = false;
  private holdTimerId: number = -1;
  private clockTimerId: number = -1;
  private voicePulseTimerId: number = -1;
  private hostWindow: window.Window | null = null;
  private keyboardHeightListener = (height: number): void => {
    this.keyboardHeightVp = Math.max(0, this.getUIContext().px2vp(height));
  };
  onSubmitPrompt: (prompt: string) => void = (_prompt: string): void => {};
  onOpenConversation: () => void = (): void => {};
  onOpenWaterfall: () => void = (): void => {};
  onStartVoiceInput: () => void = (): void => {};
  onStopVoiceInput: () => void = (): void => {};

  aboutToAppear(): void {
    this.refreshClock();
    this.clockTimerId = setInterval((): void => this.refreshClock(), AIOS_CLOCK_REFRESH_MS);
    this.voicePulseTimerId = setInterval((): void => this.advanceVoicePulse(), AIOS_VOICE_PULSE_INTERVAL_MS);
    void this.subscribeKeyboardHeight();
  }

  aboutToDisappear(): void {
    this.clearHoldTimer();
    this.unsubscribeKeyboardHeight();
    if (this.clockTimerId >= 0) {
      clearInterval(this.clockTimerId);
      this.clockTimerId = -1;
    }
    if (this.voicePulseTimerId >= 0) {
      clearInterval(this.voicePulseTimerId);
      this.voicePulseTimerId = -1;
    }
  }

  private async subscribeKeyboardHeight(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      const hostWindow = await window.getLastWindow(context);
      this.hostWindow = hostWindow;
      hostWindow.on('keyboardHeightChange', this.keyboardHeightListener);
    } catch (_error) {
      this.hostWindow = null;
    }
  }

  private unsubscribeKeyboardHeight(): void {
    if (this.hostWindow === null) return;
    try {
      this.hostWindow.off('keyboardHeightChange', this.keyboardHeightListener);
    } catch (_error) {
    }
    this.hostWindow = null;
    this.keyboardHeightVp = 0;
  }

  private d(value: number): number {
    return value * this.unit;
  }

  private w(value: number): number {
    return value * this.horizontalUnit;
  }

  private c(value: number): number {
    return value * this.horizontalUnit;
  }

  private refreshClock(): void {
    const now = new Date();
    const hour = now.getHours();
    this.greetingText = hour < 5 ? '夜深了' : hour < 11 ? '早上好' : hour < 14 ? '中午好' :
      hour < 18 ? '下午好' : '晚上好';
    this.dateText = (now.getMonth() + 1).toString() + ' 月 ' + now.getDate().toString() +
      ' 日 · ' + AIOS_WEEKDAYS[now.getDay()];
  }

  private x(value: number): number {
    return this.originX + this.w(value);
  }

  private y(value: number): number {
    return this.originY + this.d(value);
  }

  private updateViewport(width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return;
    const safeHeight = Math.max(1, height - this.systemTopInsetVp - this.systemBottomInsetVp);
    const baseSafeHeight = AIOS_BASE_HEIGHT - AIOS_BASE_TOP_INSET - AIOS_BASE_BOTTOM_INSET;
    const widthScale = width / AIOS_BASE_WIDTH;
    const heightScale = safeHeight / baseSafeHeight;
    this.viewportWidth = width;
    this.viewportHeight = height;
    this.horizontalUnit = Math.min(widthScale, AIOS_MAX_HORIZONTAL_SCALE);
    this.unit = Math.min(this.horizontalUnit, heightScale);
    this.originX = (width - AIOS_BASE_WIDTH * this.horizontalUnit) / 2;
    this.originY = this.systemTopInsetVp - AIOS_BASE_TOP_INSET * this.unit +
      (safeHeight - baseSafeHeight * this.unit) / 2;
  }

  private activitySlot(index: number): number {
    const forwardDistance = (index - this.activeActivity + AIOS_ACTIVITY_COUNT) % AIOS_ACTIVITY_COUNT;
    if (forwardDistance === 0) return 0;
    return forwardDistance === 1 ? 1 : -1;
  }

  private cardTop(index: number): number {
    const slot = this.activitySlot(index);
    return slot === 0 ? 24 : slot === 1 ? 13 : 5;
  }

  private cardLeft(index: number): number {
    const slot = this.activitySlot(index);
    return slot === 0 ? 0 : slot === 1 ? 6 : 22;
  }

  private cardWidth(index: number): number {
    const slot = this.activitySlot(index);
    return slot === 0 ? 386 : slot === 1 ? 374 : 342;
  }

  private clearHoldTimer(): void {
    if (this.holdTimerId >= 0) {
      clearTimeout(this.holdTimerId);
      this.holdTimerId = -1;
    }
  }

  private beginVoiceTouch(): void {
    if (this.commandText.trim().length > 0) return;
    this.clearHoldTimer();
    this.holdTimerId = setTimeout((): void => {
      this.holdTimerId = -1;
      this.voiceHolding = true;
      this.onStartVoiceInput();
    }, AIOS_HOLD_DELAY_MS);
  }

  private endVoiceTouch(_cancelled: boolean): void {
    if (this.holdTimerId >= 0) {
      this.clearHoldTimer();
      return;
    }
    if (this.voiceHolding || this.isVoiceListening) {
      this.voiceHolding = false;
      this.onStopVoiceInput();
    }
  }

  private finishActivityDrag(): void {
    if (!this.activityGestureActive) return;
    this.activityGestureActive = false;
    this.dragging = false;
    if (Math.abs(this.dragX) >= this.w(AIOS_SWIPE_THRESHOLD)) {
      const delta = this.dragX < 0 ? 1 : AIOS_ACTIVITY_COUNT - 1;
      this.activeActivity = (this.activeActivity + delta) % AIOS_ACTIVITY_COUNT;
    }
    this.dragX = 0;
  }

  private submitCommand(): void {
    const prompt = this.commandText.trim();
    if (prompt.length === 0) return;
    this.commandText = '';
    this.onSubmitPrompt(prompt);
  }

  private composerBottomOffset(): number {
    if (this.keyboardHeightVp <= 0) {
      return this.systemBottomInsetVp + this.c(this.voiceHolding || this.isVoiceListening ? 34 : 38);
    }
    return this.keyboardHeightVp + this.c(AIOS_COMPOSER_KEYBOARD_GAP);
  }

  private keyboardEditing(): boolean {
    return this.keyboardHeightVp > 0;
  }

  private advanceVoicePulse(): void {
    if (this.reduceMotion || (!this.voiceHolding && !this.isVoiceListening)) {
      if (this.voicePulseTick !== 0) this.voicePulseTick = 0;
      return;
    }
    this.voicePulseTick = (this.voicePulseTick + 1) % AIOS_VOICE_PULSE_STEPS;
  }

  private voiceWaveHeight(baseHeight: number, index: number): number {
    const phase = (this.voicePulseTick + index * 2) % AIOS_VOICE_PULSE_STEPS;
    const peak = phase <= AIOS_VOICE_PULSE_STEPS / 2 ? phase : AIOS_VOICE_PULSE_STEPS - phase;
    return Math.max(6, baseHeight * (0.48 + peak * 0.09));
  }

  @Builder
  private StatusChrome() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width(this.w(112)).height(this.d(34)).borderRadius(this.d(18))
        .backgroundColor('#050506').position({ x: this.x(159), y: this.y(12) })
      Row()
        .width(this.d(7)).height(this.d(7)).borderRadius(this.d(4))
        .backgroundColor('#151923').border({ width: this.d(1), color: '#232A38' })
        .position({ x: this.x(250), y: this.y(25) })
      Row({ space: this.w(7) }) {
        Image($rawfile('aios-home/assets/icons/sf-symbols/cellularbars.png'))
          .width(this.w(18)).height(this.d(12)).fillColor('#FFFFFF').objectFit(ImageFit.Contain)
        Image($rawfile('aios-home/assets/icons/sf-symbols/wifi.png'))
          .width(this.w(17)).height(this.d(12)).fillColor('#FFFFFF').objectFit(ImageFit.Contain)
        Image($rawfile('aios-home/assets/icons/sf-symbols/battery.100percent.png'))
          .width(this.w(25)).height(this.d(12)).fillColor('#FFFFFF').objectFit(ImageFit.Contain)
      }
      .position({ x: this.x(337), y: this.y(23) })
    }
    .width('100%').height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private Header() {
    Column({ space: this.d(9) }) {
      Text(this.greetingText)
        .fontSize(this.d(72)).fontWeight(FontWeight.Bolder).fontColor('#FFFFFF')
        .letterSpacing(this.d(-2.8)).lineHeight(this.d(72))
      Text(this.dateText)
        .fontSize(this.d(21)).fontWeight(FontWeight.Bold).fontColor('#DBFFFFFF')
        .letterSpacing(this.d(0.08)).lineHeight(this.d(26))
    }
    .width(this.w(380)).height(this.d(122)).alignItems(HorizontalAlign.Center)
    .position({ x: this.x(25), y: this.y(82) })
  }

  @Builder
  private ActivityObjects(index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      if (index === 0) {
        Image($rawfile('daily/discovery-video-fallback.jpeg'))
          .width(this.w(346)).height(this.d(141)).objectFit(ImageFit.Cover).borderRadius(this.d(24))
          .position({ x: 0, y: 0 }).zIndex(1)
        Row()
          .width(this.w(346)).height(this.d(141)).borderRadius(this.d(24))
          .linearGradient({
            angle: 96,
            colors: [['#D50A101B', 0], ['#80131D2C', 0.52], ['#151A2B48', 1]]
          })
          .position({ x: 0, y: 0 }).zIndex(2)

        Row({ space: this.w(7) }) {
          Text('科技')
            .fontSize(this.d(12)).fontWeight(FontWeight.Bold).fontColor('#EFFFFFFF')
            .padding({ left: this.w(10), right: this.w(10), top: this.d(6), bottom: this.d(6) })
            .borderRadius(this.d(14)).backgroundColor('#4DFFFFFF')
          Text('生活')
            .fontSize(this.d(12)).fontWeight(FontWeight.Bold).fontColor('#EFFFFFFF')
            .padding({ left: this.w(10), right: this.w(10), top: this.d(6), bottom: this.d(6) })
            .borderRadius(this.d(14)).backgroundColor('#4DFFFFFF')
          Text('灵感')
            .fontSize(this.d(12)).fontWeight(FontWeight.Bold).fontColor('#EFFFFFFF')
            .padding({ left: this.w(10), right: this.w(10), top: this.d(6), bottom: this.d(6) })
            .borderRadius(this.d(14)).backgroundColor('#4DFFFFFF')
        }
        .position({ x: this.w(18), y: this.d(14) }).zIndex(3)

        Row() {
          Column({ space: this.d(3) }) {
            Text('为你混合推荐')
              .fontSize(this.d(20)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').lineHeight(this.d(24))
            Text('不知道看什么，就从这里开始')
              .fontSize(this.d(13)).fontWeight(FontWeight.Medium).fontColor('#DFFFFFFF').lineHeight(this.d(18))
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Stack({ alignContent: Alignment.Center }) {
            Text('→')
              .fontSize(this.d(20)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }
          .width(this.d(42)).height(this.d(42)).borderRadius(this.d(21)).backgroundColor('#70FFFFFF')
        }
        .width(this.w(310)).alignItems(VerticalAlign.Center)
        .position({ x: this.w(18), y: this.d(77) }).zIndex(3)
      } else if (index === 1) {
        Stack({ alignContent: Alignment.TopStart }) {
          Column({ space: this.d(10) }) {
            Row({ space: this.w(11) }) {
              Text('A')
                .width(this.d(38)).height(this.d(38)).fontSize(this.d(20)).fontColor('#9A5E4D')
                .textAlign(TextAlign.Center).backgroundColor('#EAF7EEEA').borderRadius(this.d(13))
              Column({ space: this.d(2) }) {
                Text('有什么想问的？')
                  .fontSize(this.d(18)).fontWeight(FontWeight.Bold).fontColor('#2F3542').lineHeight(this.d(22))
                Text('问问题、想点子，或者一起做计划')
                  .fontSize(this.d(12)).fontWeight(FontWeight.Medium).fontColor('#8A4C5360').lineHeight(this.d(17))
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width(this.w(326)).height(this.d(61)).padding({ left: this.w(14), right: this.w(14) })
            .borderRadius(this.d(21)).backgroundColor('#DDF7F9FC').alignItems(VerticalAlign.Center)

            Row() {
              Text('直接开始对话')
                .fontSize(this.d(15)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              Blank()
              Text('→')
                .fontSize(this.d(19)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            }
            .width(this.w(326)).height(this.d(48)).padding({ left: this.w(17), right: this.w(17) })
            .borderRadius(this.d(20))
            .linearGradient({
              angle: 100,
              colors: [['#A35F6F85', 0], ['#9A786A8E', 0.56], ['#998365A1', 1]]
            })
            .alignItems(VerticalAlign.Center)
          }
          .width(this.w(326)).alignItems(HorizontalAlign.Start).position({ x: this.w(10), y: this.d(7) })
        }
        .width(this.w(346)).height(this.d(141)).borderRadius(this.d(24))
        .linearGradient({
          angle: 150,
          colors: [['#CFFFFFFF', 0], ['#AEEBF0F7', 0.54], ['#B7EFE8F5', 1]]
        })
      } else if (index === 2) {
        Image($rawfile('aios-home/assets/activity/shanghai/agent-report-cover.png'))
          .width(this.w(179)).height(this.d(137)).objectFit(ImageFit.Cover).borderRadius(this.d(24))
          .position({ x: 0, y: 0 }).zIndex(3)
        Image($rawfile('aios-home/assets/activity/shanghai/travel-itinerary.png'))
          .width(this.w(157)).height(this.d(90)).objectFit(ImageFit.Cover).borderRadius(this.d(24))
          .position({ x: this.w(189), y: 0 }).zIndex(2)
        Image($rawfile('aios-home/assets/activity/shanghai/flight-itinerary.png'))
          .width(this.w(145)).height(this.d(41)).objectFit(ImageFit.Cover).borderRadius(this.d(20))
          .position({ x: this.w(201), y: this.d(100) }).zIndex(4)
      } else {
        Image($rawfile('aios-home/assets/activity/weekend-dinner/restaurant.png'))
          .width(this.w(179)).height(this.d(137)).objectFit(ImageFit.Cover).borderRadius(this.d(24))
          .position({ x: 0, y: 0 }).zIndex(3)
        Image($rawfile('aios-home/assets/activity/weekend-dinner/route-map.png'))
          .width(this.w(157)).height(this.d(90)).objectFit(ImageFit.Cover).borderRadius(this.d(24))
          .position({ x: this.w(189), y: 0 }).zIndex(2)
        Image($rawfile('aios-home/assets/activity/weekend-dinner/dishes.png'))
          .width(this.w(145)).height(this.d(41)).objectFit(ImageFit.Cover).borderRadius(this.d(20))
          .position({ x: this.w(201), y: this.d(100) }).zIndex(4)
      }
    }
    .width(this.w(346)).height(this.d(141)).position({ x: this.w(20), y: this.d(77) })
  }

  @Builder
  private ActivityCard(index: number) {
    Stack({ alignContent: Alignment.TopStart }) {
      Text(AIOS_ACTIVITY_TITLES[index])
        .fontSize(this.d(29)).fontWeight(FontWeight.Bold).fontColor('#20243A')
        .letterSpacing(this.d(-1)).lineHeight(this.d(33))
        .position({ x: this.w(24), y: this.d(21) }).zIndex(5)
      this.ActivityObjects(index)
    }
    .width(this.w(this.cardWidth(index))).height(this.d(260)).borderRadius(this.d(AIOS_SURFACE_RADIUS))
    .linearGradient({
      angle: 145,
      colors: index === 0 ? [['#B9D4EE', 0], ['#C5CEF1', 0.52], ['#D8CBED', 1]] :
        index === 1 ? [['#D7E5F2', 0], ['#DADFF1', 0.54], ['#E4D9EE', 1]] :
          index === 2 ? [['#C7DFF0', 0], ['#CBD8EE', 0.54], ['#D8CDEB', 1]] :
            [['#C9E2DA', 0], ['#D8E0D2', 0.48], ['#EAD8C7', 1]]
    })
    .shadow({ radius: this.d(36), color: '#2468447A', offsetX: 0, offsetY: this.d(18) })
    .clip(true)
    .position({ x: this.w(this.cardLeft(index)), y: this.d(this.cardTop(index)) })
    .translate({ x: this.activitySlot(index) === 0 ? this.dragX : 0 })
    .scale({ x: this.activitySlot(index) === -1 ? 0.985 : 1, y: this.activitySlot(index) === -1 ? 0.985 : 1 })
    .opacity(this.activitySlot(index) === -1 ? 0.56 : 1)
    .zIndex(this.activitySlot(index) === 0 ? 3 : this.activitySlot(index) === 1 ? 2 : 1)
    .animation({ duration: this.reduceMotion || this.dragging ? 0 : 320, curve: Curve.EaseOut })
    .onClick((): void => {
      if (index !== this.activeActivity || this.dragging) return;
      if (index === 0) {
        this.onOpenWaterfall();
        return;
      }
      if (index === 1) {
        this.onOpenConversation();
        return;
      }
      this.onSubmitPrompt(AIOS_ACTIVITY_PROMPTS[index]);
    })
  }

  @Builder
  private ActivityDeck() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.ActivityCard(0)
      this.ActivityCard(1)
      this.ActivityCard(2)
      this.ActivityCard(3)
    }
    .width(this.w(386)).height(this.d(284)).position({ x: this.x(22), y: this.y(222) })
    .opacity(this.keyboardEditing() ? 0 : 1)
    .hitTestBehavior(this.keyboardEditing() ? HitTestMode.None : HitTestMode.Default)
    .animation({ duration: this.reduceMotion ? 0 : 180, curve: Curve.EaseOut })
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: this.w(4) })
        .onActionStart((): void => {
          this.activityGestureActive = true;
          this.dragging = true;
          this.dragX = 0;
        })
        .onActionUpdate((event: GestureEvent): void => {
          if (!this.activityGestureActive) return;
          this.dragX = Math.max(-this.w(AIOS_SWIPE_LIMIT), Math.min(this.w(AIOS_SWIPE_LIMIT), event.offsetX));
        })
        .onActionEnd((): void => this.finishActivityDrag())
        .onActionCancel((): void => {
          this.activityGestureActive = false;
          this.dragging = false;
          this.dragX = 0;
        })
    )
  }

  @Builder
  private AttentionEmptyState() {
    Row({ space: this.w(12) }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('✓')
          .fontSize(this.d(18)).fontWeight(FontWeight.Bold).fontColor('#C9232826')
      }
      .width(this.d(42)).height(this.d(42)).borderRadius(this.d(21)).backgroundColor('#80FFFFFF')

      Column({ space: this.d(2) }) {
        Text('暂无待处理事项')
          .width('100%').fontSize(this.d(18)).fontWeight(FontWeight.Bold).fontColor('#E8202522')
          .lineHeight(this.d(24)).maxLines(1)
        Text('新的待办会显示在这里')
          .width('100%').fontSize(this.d(14)).fontColor('#9E2A332F').lineHeight(this.d(19)).maxLines(1)
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width(this.w(386)).height(this.d(88))
    .padding({ left: this.w(16), right: this.w(16) })
    .alignItems(VerticalAlign.Center)
    .borderRadius(this.d(24))
    .backgroundColor('#52FFFFFF')
    .border({ width: this.d(1), color: '#70FFFFFF' })
    .shadow({ radius: this.d(22), color: '#12233145', offsetX: 0, offsetY: this.d(10) })
  }

  @Builder
  private AttentionSection() {
    Column({ space: this.d(10) }) {
      Text('需要处理')
        .width('100%').fontSize(this.d(22)).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .letterSpacing(this.d(-0.65)).padding({ left: this.w(4) })
      Row() {
        this.AttentionEmptyState()
      }
      .width(this.w(386)).alignItems(VerticalAlign.Top)
    }
    .width(this.w(386)).alignItems(HorizontalAlign.Start).position({ x: this.x(22), y: this.y(531) })
    .opacity(this.keyboardEditing() ? 0 : 1)
    .hitTestBehavior(this.keyboardEditing() ? HitTestMode.None : HitTestMode.Default)
    .animation({ duration: this.reduceMotion ? 0 : 180, curve: Curve.EaseOut })
  }

  @Builder
  private VoiceWaveform() {
    Row({ space: this.w(2) }) {
      ForEach(AIOS_WAVE_HEIGHTS, (height: number, index: number) => {
        Row()
          .width(this.w(2))
          .height(this.c(this.voiceWaveHeight(height, index)))
          .borderRadius(this.c(2)).backgroundColor('#C72C303B')
          .animation({ duration: this.reduceMotion ? 0 : AIOS_VOICE_PULSE_INTERVAL_MS, curve: Curve.EaseInOut })
      })
    }
    .width(this.w(151)).height(this.c(44)).justifyContent(FlexAlign.Center).alignItems(VerticalAlign.Center)
  }

  @Builder
  private VoiceDock() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.voiceHolding || this.isVoiceListening) {
        this.VoiceWaveform()
      } else {
        Image($rawfile('aios-home/assets/icons/sf-symbols/keyboard.png'))
          .width(this.c(AIOS_COMPOSER_ICON_SIZE)).height(this.c(AIOS_COMPOSER_ICON_SIZE))
          .objectFit(ImageFit.Contain).fillColor('#80000000')
          .position({ x: this.w(20), y: this.c(17) })
        TextInput({ text: this.commandText, placeholder: '点击输入或按住说话' })
          .width(this.w(280)).height(this.c(48))
          .fontSize(this.c(AIOS_COMPOSER_TEXT_SIZE)).fontWeight(FontWeight.Medium)
          .fontColor('#CC20242C').placeholderColor('#80000000')
          .textAlign(TextAlign.Center).enterKeyType(EnterKeyType.Send)
          .backgroundColor('#00000000').border({ width: 0 }).borderRadius(0)
          .padding({ left: 0, right: 0, top: 0, bottom: 0 })
          .onChange((value: string): void => { this.commandText = value; })
          .onSubmit((): void => this.submitCommand())
        if (this.commandText.trim().length === 0) {
          Image($rawfile('aios-home/assets/icons/sf-symbols/video.fill.png'))
            .width(this.c(AIOS_COMPOSER_ICON_SIZE)).height(this.c(AIOS_COMPOSER_ICON_SIZE))
            .objectFit(ImageFit.Contain).fillColor('#80000000')
            .position({ x: this.w(349), y: this.c(17) })
            .hitTestBehavior(HitTestMode.None)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Image($r('app.media.arrow_up'))
              .width(this.c(AIOS_COMPOSER_SEND_ICON_SIZE)).height(this.c(AIOS_COMPOSER_SEND_ICON_SIZE))
              .objectFit(ImageFit.Contain)
          }
          .width(this.c(AIOS_COMPOSER_SEND_SIZE)).height(this.c(AIOS_COMPOSER_SEND_SIZE))
          .borderRadius(this.c(AIOS_COMPOSER_SEND_SIZE / 2))
          .backgroundColor(AIOS_COMPOSER_SEND_BACKGROUND)
          .shadow({ radius: this.c(10), color: AIOS_COMPOSER_SEND_SHADOW, offsetX: 0, offsetY: this.c(4) })
          .position({ x: this.w(337), y: this.c(9.5) })
          .animation({ duration: this.reduceMotion ? 0 : 220, curve: Curve.EaseOut })
          .onClick((): void => this.submitCommand())
        }
      }
    }
    .width(this.w(this.voiceHolding || this.isVoiceListening ? AIOS_COMPOSER_ACTIVE_WIDTH : AIOS_COMPOSER_WIDTH))
    .height(this.c(this.voiceHolding || this.isVoiceListening ? AIOS_COMPOSER_ACTIVE_HEIGHT : AIOS_COMPOSER_HEIGHT))
    .borderRadius(this.d(this.voiceHolding || this.isVoiceListening ?
      AIOS_COMPOSER_ACTIVE_RADIUS : AIOS_COMPOSER_RADIUS))
    .backgroundColor(this.voiceHolding || this.isVoiceListening ? '#B8E5E9ED' : '#9EE5E8EA')
    .border({ width: this.c(1), color: this.voiceHolding || this.isVoiceListening ? '#C7FFFFFF' : '#9EFFFFFF' })
    .shadow({ radius: this.c(38), color: '#26211B25', offsetX: 0, offsetY: this.c(14) })
    .position({
      x: this.x(this.voiceHolding || this.isVoiceListening ? 15.5 : 21.5),
      y: this.viewportHeight - this.composerBottomOffset() -
        this.c(this.voiceHolding || this.isVoiceListening ? AIOS_COMPOSER_ACTIVE_HEIGHT : AIOS_COMPOSER_HEIGHT)
    })
    .animation({ duration: this.reduceMotion ? 0 : 320, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) this.beginVoiceTouch();
      if (event.type === TouchType.Up) this.endVoiceTouch(false);
      if (event.type === TouchType.Cancel) this.endVoiceTouch(true);
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($rawfile('aios-home/assets/wallpapers/now-blue.png'))
        .width('100%').height('100%').objectFit(ImageFit.Cover)
      this.Header()
      this.ActivityDeck()
      this.AttentionSection()
      this.StatusChrome()
      this.VoiceDock()
    }
    .width('100%').height('100%').backgroundColor('#0B1018').clip(true)
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const width = parseFloat(newArea.width.toString());
      const height = parseFloat(newArea.height.toString());
      this.updateViewport(width, height);
    })
  }
}
