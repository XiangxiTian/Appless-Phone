import { A2UI_MOTION_CURVE } from '../style/A2uiHomeMotion';

const CARD_HEIGHT: number = 264;
const GUIDE_IMAGE_HEIGHT: number = 156;
const GESTURE_DISTANCE: number = 120;
const SWITCH_THRESHOLD: number = 54;
const SIDE_OFFSET: number = 56;
const SIDE_SCALE: number = 0.94;
const SIDE_OPACITY: number = 0.18;
const SETTLE_MS: number = 240;

@Component
export struct WelcomeCardDeck {
  @Prop reduceMotion: boolean = false;
  @Prop isBusy: boolean = false;
  @Prop isVoiceListening: boolean = false;
  @State private activeIndex: number = 0;
  @State private dragX: number = 0;
  @State private dragging: boolean = false;
  @State private settling: boolean = false;
  private gestureActive: boolean = false;
  private settleTimerId: number = -1;
  private blockClickUntilMs: number = 0;
  onChoosePrompt: (prompt: string) => void = (_prompt: string): void => {};
  onOpenWaterfall: () => void = (): void => {};

  aboutToDisappear(): void {
    this.clearTimers();
  }

  private clearTimers(): void {
    if (this.settleTimerId >= 0) {
      clearTimeout(this.settleTimerId);
      this.settleTimerId = -1;
    }
  }

  private nextIndex(index: number, direction: number): number {
    if (direction > 0) {
      if (index === 0) {
        return 2;
      }
      return index === 2 ? 1 : 0;
    }
    if (index === 0) {
      return 1;
    }
    return index === 1 ? 2 : 0;
  }

  private cardSlot(index: number): number {
    if (index === this.activeIndex) {
      return 0;
    }
    return index === this.nextIndex(this.activeIndex, 1) ? 1 : -1;
  }

  private progress(): number {
    return Math.max(-1, Math.min(1, -this.dragX / GESTURE_DISTANCE));
  }

  private translateX(index: number): number {
    const slot = this.cardSlot(index);
    const progress = this.progress();
    if (progress >= 0) {
      if (slot === 0) {
        return -SIDE_OFFSET * progress;
      }
      if (slot === 1) {
        return SIDE_OFFSET * (1 - progress);
      }
      return -SIDE_OFFSET + 2 * SIDE_OFFSET * progress;
    }

    const amount = -progress;
    if (slot === 0) {
      return SIDE_OFFSET * amount;
    }
    if (slot === -1) {
      return -SIDE_OFFSET * (1 - amount);
    }
    return SIDE_OFFSET - 2 * SIDE_OFFSET * amount;
  }

  private scaleValue(index: number): number {
    const slot = this.cardSlot(index);
    const progress = this.progress();
    const amount = Math.abs(progress);
    if (slot === 0) {
      return 1 - (1 - SIDE_SCALE) * amount;
    }
    const incomingSlot = progress >= 0 ? 1 : -1;
    if (slot === incomingSlot) {
      return SIDE_SCALE + (1 - SIDE_SCALE) * amount;
    }
    return SIDE_SCALE - Math.sin(Math.PI * amount) * 0.05;
  }

  private opacityValue(index: number): number {
    const slot = this.cardSlot(index);
    const progress = this.progress();
    const amount = Math.abs(progress);
    if (slot === 0) {
      return 1 - (1 - SIDE_OPACITY) * amount;
    }
    const incomingSlot = progress >= 0 ? 1 : -1;
    if (slot === incomingSlot) {
      return SIDE_OPACITY + (1 - SIDE_OPACITY) * amount;
    }
    // 第三张卡只在最底层换边，不参与中心区域的视觉竞争。
    return SIDE_OPACITY * (1 - Math.sin(Math.PI * amount) * 0.55);
  }

  private layer(index: number): number {
    const slot = this.cardSlot(index);
    const progress = this.progress();
    const amount = Math.abs(progress);
    const incomingSlot = progress >= 0 ? 1 : -1;
    if (slot === 0) {
      return amount < 0.5 ? 3 : 2;
    }
    if (slot === incomingSlot) {
      return amount < 0.5 ? 2 : 3;
    }
    return 1;
  }

  private finishDrag(): void {
    if (!this.gestureActive || this.settling) {
      return;
    }
    this.gestureActive = false;
    this.dragging = false;
    if (Math.abs(this.dragX) < SWITCH_THRESHOLD) {
      this.blockClickUntilMs = Date.now() + SETTLE_MS;
      this.settling = true;
      this.dragX = 0;
      this.clearTimers();
      this.settleTimerId = setTimeout(() => {
        this.settling = false;
        this.settleTimerId = -1;
      }, this.reduceMotion ? 0 : SETTLE_MS);
      return;
    }

    const direction = this.dragX < 0 ? 1 : -1;
    this.settling = true;
    this.blockClickUntilMs = Date.now() + SETTLE_MS + 60;
    this.clearTimers();
    if (this.reduceMotion) {
      this.activeIndex = this.nextIndex(this.activeIndex, direction);
      this.dragX = 0;
      this.settling = false;
      return;
    }

    // 先让当前卡继续跟随原坐标系退到侧边；到位后再提交索引。
    // 两个坐标系在端点的位置、缩放与透明度完全一致，因此不会跳帧。
    this.dragX = direction > 0 ? -GESTURE_DISTANCE : GESTURE_DISTANCE;
    this.settleTimerId = setTimeout(() => {
      this.activeIndex = this.nextIndex(this.activeIndex, direction);
      this.dragX = 0;
      this.settling = false;
      this.settleTimerId = -1;
    }, SETTLE_MS);
  }

  private choose(index: number, prompt: string, openWaterfall: boolean): void {
    if (index !== this.activeIndex || this.isBusy || this.isVoiceListening || this.settling ||
      Date.now() < this.blockClickUntilMs) {
      return;
    }
    if (openWaterfall) {
      this.onOpenWaterfall();
      return;
    }
    this.onChoosePrompt(prompt);
  }

  @Builder
  private NearbyFoodVisual() {
    Image($r('app.media.home_guide_nearby_food'))
    .width('100%')
    .height(GUIDE_IMAGE_HEIGHT)
    .objectFit(ImageFit.Contain)
    .backgroundColor('#F5EAE3')
    .borderRadius(20)
    .clip(true)
  }

  @Builder
  private WeekendVisual() {
    Image($r('app.media.home_guide_travel_plan'))
    .width('100%')
    .height(GUIDE_IMAGE_HEIGHT)
    .objectFit(ImageFit.Contain)
    .backgroundColor('#E3EFE9')
    .borderRadius(20)
    .clip(true)
  }

  @Builder
  private WaterfallVisual() {
    Image($r('app.media.home_guide_waterfall'))
    .width('100%')
    .height(GUIDE_IMAGE_HEIGHT)
    .objectFit(ImageFit.Contain)
    .backgroundColor('#F0EAF3')
    .borderRadius(20)
    .clip(true)
  }

  @Builder
  private Card(index: number, kicker: string, title: string, prompt: string, openWaterfall: boolean = false) {
    Column() {
      Text(kicker)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#747C7E')
        .maxLines(2)
      Text(title)
        .width('100%')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111415')
        .margin({ top: 6, bottom: 13 })
      if (index === 0) {
        this.NearbyFoodVisual()
      } else if (index === 1) {
        this.WeekendVisual()
      } else {
        this.WaterfallVisual()
      }
    }
    .width('82%')
    .height(CARD_HEIGHT)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 22, right: 9, top: 20, bottom: 11 })
    .backgroundColor('#FFFFFFFF')
    .borderRadius(30)
    .shadow({ radius: 18, color: '#1A000000', offsetX: 0, offsetY: 10 })
    .renderGroup(true)
    .translate({ x: this.translateX(index) })
    .scale({ x: this.scaleValue(index), y: this.scaleValue(index) })
    .opacity(this.opacityValue(index))
    .zIndex(this.layer(index))
    .animation({
      duration: this.reduceMotion || this.dragging ? 0 : SETTLE_MS,
      curve: A2UI_MOTION_CURVE
    })
    .accessibilityText(kicker + '，' + title)
    .onClick(() => {
      this.choose(index, prompt, openWaterfall);
    })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.Card(0, '想找附近值得去的餐厅？', '查附近美食', '附近有什么好吃的')
      this.Card(1, '准备出发，但还没有完整安排？', '规划出行', '帮我查询出行方案并规划一次旅行')
      this.Card(2, '看看今天有什么值得关注的内容', '去发现', '', true)
    }
    .width('100%')
    .height(CARD_HEIGHT + 14)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 4 })
        .onActionStart(() => {
          if (this.settling) {
            return;
          }
          this.gestureActive = true;
          this.dragging = true;
          this.dragX = 0;
        })
        .onActionUpdate((event: GestureEvent) => {
          if (!this.gestureActive || this.settling) {
            return;
          }
          this.dragX = Math.max(-GESTURE_DISTANCE, Math.min(GESTURE_DISTANCE, event.offsetX));
        })
        .onActionEnd(() => {
          this.finishDrag();
        })
        .onActionCancel(() => {
          if (!this.settling) {
            this.gestureActive = false;
            this.dragging = false;
            this.dragX = 0;
          }
        })
    )
  }
}
