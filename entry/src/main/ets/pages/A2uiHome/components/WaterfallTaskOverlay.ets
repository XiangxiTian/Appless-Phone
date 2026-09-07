import { curves } from '@kit.ArkUI';
import { COLOR_ACCENT, COLOR_TEXT as TASK_TEXT, COLOR_MUTED as TASK_MUTED,
  COLOR_LINE, COLOR_INK, COLOR_BUTTON_TEXT } from '../style/A2uiHomeTheme';
import {
  dismissTaskNotice, emptyTaskNotice, syncTaskNotice, taskNoticeGestureCanDismiss,
  taskNoticeDisplay, WaterfallTaskNoticeState, WaterfallTaskSnapshot
} from '../waterfall/WaterfallTaskNotice';

const TASK_SURFACE: string = '#F0F8EDE6';

@Component
export struct WaterfallTaskOverlay {
  @Prop @Watch('syncNotice') task: WaterfallTaskSnapshot = {
    id: '', prompt: '', reply: '', running: false, failed: false
  };
  @Prop @Watch('syncNotice') active: boolean = false;
  @Prop reduceMotion: boolean = false;
  @Prop progress: string = '正在理解你的问题';
  @State private notice: WaterfallTaskNoticeState = emptyTaskNotice();
  @State private draft: string = '';
  @State private submitting: boolean = false;
  private previewTimer: number = -1;
  private presentedAt: number = 0;
  private backgroundTouchStartedAt: number = 0;
  private tapMode: string = '';
  private touchX: number = 0;
  private touchY: number = 0;
  private panelBottom: number = 0;
  onBottomChange: (bottom: number) => void = (_bottom: number): void => {};
  onBindBackgroundTouch: (handler: (event: TouchEvent) => void) => void =
    (_handler: (event: TouchEvent) => void): void => {};
  onOpenHome: () => void = () => {};
  onSubmit: (text: string, taskId: string) => Promise<boolean> =
    async (_text: string, _taskId: string): Promise<boolean> => false;

  aboutToAppear(): void {
    this.onBindBackgroundTouch((event: TouchEvent): void => { this.backgroundTouch(event); });
    this.syncNotice();
  }
  aboutToDisappear(): void {
    this.clearTimer();
    this.onBottomChange(0);
    this.onBindBackgroundTouch((_event: TouchEvent): void => {});
  }

  private clearTimer(): void {
    if (this.previewTimer >= 0) clearTimeout(this.previewTimer);
    this.previewTimer = -1;
  }

  private syncNotice(): void {
    const next = syncTaskNotice(this.notice, this.task, this.active);
    if (next.id === this.notice.id && next.mode === this.notice.mode && next.running === this.notice.running) return;
    const previewStarted = next.mode === 'preview' && this.notice.mode !== 'preview';
    if (next.mode !== 'preview') this.clearTimer();
    if (next.id !== this.notice.id || next.id.length === 0) this.draft = '';
    this.tapMode = '';
    this.notice = next;
    this.publishBottom();
    if (previewStarted) {
      this.presentedAt = Date.now();
      this.clearTimer();
      this.previewTimer = setTimeout((): void => { this.dismiss(); }, 5000);
    }
  }

  private backgroundTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) this.backgroundTouchStartedAt = Date.now();
    if (event.type === TouchType.Up && this.active &&
      taskNoticeGestureCanDismiss(this.notice.mode, this.presentedAt, this.backgroundTouchStartedAt)) this.dismiss();
  }

  private panelTouch(event: TouchEvent): void {
    event.stopPropagation();
    if (event.type === TouchType.Down && event.touches.length > 0) {
      this.tapMode = this.notice.mode;
      this.touchX = event.touches[0].screenX;
      this.touchY = event.touches[0].screenY;
    } else if (event.type === TouchType.Cancel || (event.type === TouchType.Move && event.touches.length > 0 &&
      (Math.abs(event.touches[0].screenX - this.touchX) > 8 || Math.abs(event.touches[0].screenY - this.touchY) > 8))) {
      this.tapMode = '';
    }
  }

  private dismiss(): void {
    this.clearTimer();
    const next = dismissTaskNotice(this.notice);
    if (next.mode !== this.notice.mode) this.notice = next;
    this.tapMode = '';
    this.publishBottom();
  }

  private publishBottom(): void {
    this.onBottomChange(this.active && (this.notice.mode === 'sheet' || this.notice.mode === 'preview') ?
      this.panelBottom + 8 : 0);
  }

  private open(event: ClickEvent): void {
    if (event.source === SourceType.TouchScreen && this.tapMode !== this.notice.mode) return;
    this.clearTimer();
    this.tapMode = '';
    this.notice = { id: this.notice.id, running: this.notice.running, mode: 'sheet' };
    this.publishBottom();
  }

  private openHome(event: ClickEvent): void {
    if (event.source === SourceType.TouchScreen && this.tapMode !== 'sheet') return;
    this.dismiss();
    this.onOpenHome();
  }

  private noticeTransition(sheet: boolean = false): TransitionEffect {
    return TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: this.reduceMotion ? 0 : -8 }))
        .animation({ duration: this.reduceMotion ? 120 : (sheet ? 280 : 240),
          curve: curves.cubicBezierCurve(0.23, 1, 0.32, 1) }),
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: this.reduceMotion ? 0 : -4 }))
        .animation({ duration: this.reduceMotion ? 100 : 140, curve: Curve.EaseOut })
    );
  }

  private async submit(): Promise<void> {
    const text = this.draft.trim();
    if (text.length === 0 || this.task.running || this.submitting) return;
    this.submitting = true;
    this.draft = '';
    try {
      if (!await this.onSubmit(text, this.task.id) && this.draft.length === 0) this.draft = text;
    } catch (_) {
      if (this.draft.length === 0) this.draft = text;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private statusIcon() {
    if (this.task.running) {
      LoadingProgress().width(12).height(12).color(TASK_MUTED).enableLoading(!this.reduceMotion)
        .accessibilityLevel('no')
    } else {
      SymbolGlyph(this.task.failed ? $r('sys.symbol.exclamationmark') : $r('sys.symbol.checkmark'))
        .fontSize(12).fontColor([COLOR_ACCENT]).accessibilityLevel('no')
    }
  }

  @Builder
  private status() {
    Row({ space: 8 }) {
      this.statusIcon()
      Text(this.task.running ? '正在处理' : (this.task.failed ? '暂未完成' : '已完成'))
        .fontSize(12).fontColor(TASK_MUTED)
    }
  }

  @Builder
  private sheet() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        this.statusIcon()
        Text(this.task.prompt).fontSize(11).fontColor(COLOR_INK).layoutWeight(1)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.xmark')).fontSize(12).fontColor([TASK_MUTED])
        }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
          .accessibilityText('收起任务结果')
          .onClick((): void => { this.dismiss(); })
      }.width('100%')
      Column({ space: 0 }) {
        if (this.task.running) {
          Text(this.progress).fontSize(12).fontColor(TASK_TEXT).width('100%').margin({ bottom: 8 })
        }
        Scroll() {
          Text(taskNoticeDisplay(this.task.reply).body ||
            (this.task.running ? '任务在主屏继续执行，结果会同步到这里。' : '结果已保存在对话中。'))
            .fontSize(15).lineHeight(22).fontColor(COLOR_INK).width('100%')
        }.width('100%').constraintSize({ minHeight: 44, maxHeight: 132 })
          .scrollBar(BarState.Off).align(Alignment.TopStart)
        Row({ space: 8 }) {
          Text(taskNoticeDisplay(this.task.reply).source).fontSize(10.5).fontColor(TASK_TEXT).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('app.media.arrow_up')).width(14).height(14).fillColor(COLOR_ACCENT).rotate({ angle: 45 })
        }.width('100%').padding({ top: 16, bottom: 12 })
      }.width('100%').padding({ right: 8 })
        .accessibilityText('任务结果，点按回到主屏查看完整对话')
        .onClick((event: ClickEvent): void => { this.openHome(event); })
      Divider().color(COLOR_LINE).strokeWidth(0.75)
      Row({ space: 8 }) {
        TextInput({ text: this.draft, placeholder: '继续追问…' })
          .layoutWeight(1).height(44).padding({ left: 0, right: 8 }).fontSize(12).fontColor(TASK_TEXT)
          .placeholderColor(TASK_TEXT).caretColor(COLOR_ACCENT).backgroundColor(Color.Transparent).borderRadius(0)
          .enterKeyType(EnterKeyType.Send).maxLength(2000)
          .accessibilityText('任务追问输入框')
          .onChange((value: string): void => { this.draft = value; })
          .onSubmit((): void => { void this.submit(); })
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.arrow_up')).fillColor(COLOR_BUTTON_TEXT)
            .width(28).height(28).padding(7).backgroundColor(COLOR_ACCENT).borderRadius(14)
        }.width(44).height(44).padding(0).backgroundColor(Color.Transparent)
          .enabled(this.draft.trim().length > 0 && !this.task.running && !this.submitting)
          .accessibilityText('发送追问')
          .onClick((): void => { void this.submit(); })
      }.width('100%').padding({ top: 2 })
    }
    .width('100%').padding({ left: 18, right: 10, bottom: 4 })
    .backgroundEffect({ radius: 20, color: TASK_SURFACE })
    .borderRadius({ topLeft: 18, topRight: 18, bottomLeft: 14, bottomRight: 14 })
    .border({ width: 0.5, color: '#D6C1B6' })
    .shadow({ radius: 18, offsetY: 6, color: '#248C6A53' })
    .onTouch((event: TouchEvent): void => { this.panelTouch(event); })
    .transition(this.noticeTransition(true))
  }

  build() {
    if (this.active && this.notice.mode !== 'hidden') {
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.notice.mode === 'sheet') {
          this.sheet()
        } else if (this.notice.mode === 'preview') {
          Row() {
          Row({ space: 12 }) {
            this.statusIcon()
            Text(this.task.reply.length > 0 ? taskNoticeDisplay(this.task.reply).summary : '点开查看结果')
              .layoutWeight(1).fontSize(12).fontColor(COLOR_INK)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(12).fontColor([COLOR_ACCENT])
              .accessibilityLevel('no')
          }
          .width('100%').height(40).padding({ left: 18, right: 18 })
          .backgroundEffect({ radius: 20, color: TASK_SURFACE })
          .borderRadius(20)
          .border({ width: 0.5, color: '#D6C1B6' })
          .shadow({ radius: 14, offsetY: 5, color: '#248C6A53' })
          }.width('100%').height(44)
          .accessibilityText('任务已结束，点击查看详情并追问')
          .onClick((event: ClickEvent): void => { this.open(event); })
          .onTouch((event: TouchEvent): void => { this.panelTouch(event); })
          .transition(this.noticeTransition())
        } else {
          Row() {
            Row() { this.status() }
              .height(32).padding({ left: 12, right: 14 }).backgroundColor('#FFFFFF')
              .borderRadius(16).border({ width: 0.5, color: '#18000000' })
          }.height(44)
          .accessibilityText('主屏任务正在执行，点击查看')
          .onClick((event: ClickEvent): void => { this.open(event); })
          .onTouch((event: TouchEvent): void => { this.panelTouch(event); })
          .transition(this.noticeTransition())
        }
      }
      .width('100%').padding({ left: 20, right: 20 })
      .onAreaChange((_old: Area, area: Area): void => {
        this.panelBottom = Number(area.globalPosition.y) + Number(area.height);
        this.publishBottom();
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
