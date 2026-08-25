import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { KeyboardAvoidMode } from '@ohos.arkui.UIContext';
import {
  A2uiAction,
  A2uiMessage,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '@loop/agent-core';
import { A2uiButtonView } from './common/A2uiButtonView';
import { HistoryPanelView } from './HistoryPanelView';
import { HtmlHomeSurfaceView } from './HtmlHomeSurfaceView';
import { FoodStoreMapView } from './FoodStoreMapView';
import { A2uiSurfaceView } from './A2uiSurfaceView';
import { CheckoutWebKind, CheckoutWebOverlay } from './CheckoutWebOverlay';
import { DeepSearchPanel } from './DeepSearchPanel';
import {
  emptyTrainPresaleTrip,
  TrainPresalePanel,
  TrainPresalePanelSubmission,
  TrainPresaleTrip
} from './TrainPresalePanel';
import { TrainPresaleTask } from '../train/TrainPresaleTaskStore';
import {
  isPromptInputEnabled,
  nextSendSpinnerRotation
} from '../state/A2uiHomeState';
import {
  A2UI_HOME_FLOATING_RADIUS,
  A2UI_HOME_MAX_WIDTH,
  A2UI_HOME_PAGE_PADDING_TOP,
  A2UI_HOME_PAGE_PADDING_X,
  A2UI_HOME_SECTION_GAP
} from '../style/A2uiHomeLayout';
import {
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from '../style/A2uiHomeMotion';
import { formatBimCount } from './BimHomePage';

const A2UI_HISTORY_EMPTY_HEIGHT: number = 108;
const A2UI_HISTORY_ROW_HEIGHT: number = 76;
const A2UI_HISTORY_MAX_HEIGHT: number = 254;
const A2UI_SEND_SPINNER_INTERVAL_MS: number = 90;
const A2UI_HEADER_BUTTON_GAP: number = 3;
const A2UI_HEADER_BUTTON_SIZE: number = 36;
const A2UI_HEADER_BUTTON_ICON_SIZE: number = 18;
const A2UI_HEART_TARGET_SIZE: number = 44;
const A2UI_HEART_ICON_SIZE: number = 28;
const A2UI_HEADER_LOGO_SIZE: number = 30;
const A2UI_VOICE_DOCK_HEIGHT: number = 72;
const A2UI_VOICE_PULSE_STEPS: number = 12;
const A2UI_VOICE_HOLD_DELAY_MS: number = 360;
const A2UI_VOICE_WAVE_CENTER_INDEX: number = 8;
const A2UI_VOICE_WAVE_INDICES: number[] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
const A2UI_COMPOSER_MIN_HEIGHT: number = 54;
const A2UI_COMPOSER_MAX_HEIGHT: number = 122;
const A2UI_COMPOSER_TEXT_MAX_HEIGHT: number = 110;
const A2UI_COMPOSER_TEXT_LINE_HEIGHT: number = 24;
const A2UI_COMPOSER_TEXT_VERTICAL_PADDING: number = 14;
const A2UI_COMPOSER_TEXT_UNITS_PER_LINE: number = 30;
const A2UI_COMPOSER_TEXT_MAX_LINES: number = 4;
const A2UI_COMPOSER_DOCK_EXTRA_HEIGHT: number = 8;
const A2UI_HOME_COMPOSER_BOTTOM_PADDING: number = 4;
const A2UI_HOME_CLOCK_INTERVAL_MS: number = 30000;
const A2UI_HOME_SHELL_BACKGROUND: string = '#FFFDF9';
const A2UI_HOME_GLASS_BACKGROUND: string = '#B8FFFFFF';
const A2UI_HOME_GLASS_EDGE: string = '#E9DED5';
const A2UI_HOME_GLASS_SHADOW: string = '#248C6A53';
const A2UI_HOME_SEND_INACTIVE_BACKGROUND: string = '#C9C4BF';
const A2UI_HOME_SEND_ACTIVE_BACKGROUND: string = '#995F4C';
const A2UI_HOME_SEND_SHADOW: string = '#38995F4C';
const A2UI_HOME_HEADER_BUTTON_BACKGROUND: string = '#CCFFFFFF';
const A2UI_HOME_HEADER_BUTTON_EDGE: string = '#B8E7D8CE';
const A2UI_HOME_HEADER_BUTTON_SHADOW: string = '#188C6A53';
const A2UI_HOME_AI_LABEL_BACKGROUND: string = '#F6EAE4';
const A2UI_HOME_AI_LABEL_EDGE: string = '#D8B8AA';
const A2UI_HOME_AI_LABEL_TEXT: string = '#714737';

function padHomeClockPart(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

export function homeTimeText(epochMs: number): string {
  const date = new Date(epochMs);
  return padHomeClockPart(date.getHours()) + ':' + padHomeClockPart(date.getMinutes());
}

export function homeDateText(epochMs: number): string {
  const date = new Date(epochMs);
  const weekdays: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日  ' + weekdays[date.getDay()];
}

export function homeGreetingText(epochMs: number): string {
  const hour = new Date(epochMs).getHours();
  if (hour < 5) {
    return '夜深了';
  }
  if (hour < 12) {
    return '早上好';
  }
  if (hour < 14) {
    return '中午好';
  }
  if (hour < 18) {
    return '下午好';
  }
  return '晚上好';
}

export function homePromptTitle(
  epochMs: number,
  isBusy: boolean,
  isVoiceListening: boolean,
  composerFocused: boolean
): string {
  if (isVoiceListening) {
    return '我在听，请继续说';
  }
  if (isBusy) {
    return '正在替你处理';
  }
  if (composerFocused) {
    return '想先从哪件事开始？';
  }

  const hour = new Date(epochMs).getHours();
  if (hour < 5) {
    return '夜深了，还有什么需要我帮你？';
  }
  if (hour < 12) {
    return '今天准备先做什么？';
  }
  if (hour < 14) {
    return '中午想安排点什么？';
  }
  if (hour < 18) {
    return '接下来想处理什么？';
  }
  return '今晚还有什么安排？';
}

export function canStartHomeComposerVoice(isBusy: boolean, inputText: string): boolean {
  return !isBusy && inputText.length === 0;
}

export function homeComposerTextHeight(inputText: string): number {
  let lineCount = 1;
  let lineUnits = 0;
  for (let index = 0; index < inputText.length; index += 1) {
    const charCode = inputText.charCodeAt(index);
    if (charCode === 10) {
      lineCount += 1;
      lineUnits = 0;
    } else {
      const charUnits = charCode <= 127 ? 1 : 2;
      if (lineUnits > 0 && lineUnits + charUnits > A2UI_COMPOSER_TEXT_UNITS_PER_LINE) {
        lineCount += 1;
        lineUnits = charUnits;
      } else {
        lineUnits += charUnits;
      }
    }
    if (lineCount >= A2UI_COMPOSER_TEXT_MAX_LINES) {
      return A2UI_COMPOSER_TEXT_MAX_HEIGHT;
    }
  }
  return Math.max(
    36,
    lineCount * A2UI_COMPOSER_TEXT_LINE_HEIGHT + A2UI_COMPOSER_TEXT_VERTICAL_PADDING
  );
}

export function hasLlmReply(messages: A2uiMessage[]): boolean {
  for (let index = 0; index < messages.length; index += 1) {
    if (messages[index].role === 'assistant' && messages[index].content.trim().length > 0) {
      return true;
    }
  }
  return false;
}

export function shouldShowHomeChrome(waterfallFullscreen: boolean): boolean {
  return !waterfallFullscreen;
}

export function shouldShowDailyBriefReturn(surface: A2uiSurfaceState): boolean {
  return surface.intent !== 'daily-brief' && surface.surfaceId.startsWith('daily-brief-');
}

export type BimRememberState = 'ready' | 'saving' | 'saved' | 'error';

@Component
export struct HomePage {
  @Link inputText: string;
  @Prop isBusy: boolean = false;
  @Prop showHistory: boolean = false;
  @Prop messages: A2uiMessage[] = [];
  @Prop currentSurface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop htmlHomeHtml: string = '';
  @Prop foodStoreMapOpen: boolean = false;
  @Prop foodStoreMapAmapKey: string = '';
  @Prop foodStoreMapSnapshotJson: string = '';
  @Prop foodStoreMapSnapshotTick: number = 0;
  @Prop multiTaskPayloadJson: string = '';
  @Prop multiTaskPayloadTick: number = 0;
  @Prop waterfallPayloadJson: string = '';
  @Prop waterfallPayloadTick: number = 0;
  @Prop waterfallBackRequestTick: number = 0;
  @Prop mailDetailEventJson: string = '';
  @Prop mailReplyEventJson: string = '';
  @Prop mailCalendarEventJson: string = '';
  @Prop surfaceRenderTick: number = 0;
  @Prop luckinInlinePatchJson: string = '';
  @Prop luckinInlinePatchTick: number = 0;
  @Prop isAwaitingFirstSurface: boolean = false;
  @Prop inputPlaceholder: string = '告诉 Appless 你想完成什么';
  @Prop isVoiceListening: boolean = false;
  @Prop voiceInputMessage: string = '';
  @Prop showWelcome: boolean = false;
  @Prop showCheckoutWeb: boolean = false;
  @Prop checkoutWebKind: CheckoutWebKind = 'payment';
  @Prop checkoutWebUrl: string = '';
  @Prop checkoutWebTaskId: string = '';
  @Prop checkoutWebContext: string = '';
  @Prop showTrainPresalePanel: boolean = false;
  @Prop trainPresaleTrip: TrainPresaleTrip = emptyTrainPresaleTrip();
  @Prop trainPresaleTask: TrainPresaleTask | null = null;
  @Prop trainPresaleTaskState: string = '';
  @Prop trainPresaleError: string = '';
  @Prop trainPresaleWorking: boolean = false;
  @Prop isDebugBuild: boolean = false;
  @Prop bimVisibleCount: number = 0;
  @Prop bimSuggestionTitle: string = '';
  @Prop bimSuggestionReason: string = '';
  @Prop bimRememberState: BimRememberState = 'ready';
  @Prop bimRememberError: string = '';
  @Prop reduceMotion: boolean = false;
  @Prop showDeepSearch: boolean = false;
  @Prop deepSearchQuery: string = '';
  @Prop deepSearchSettingsJson: string = '';
  @Prop deepSearchContextJson: string = '';
  @Prop locationServiceNotice: string = '';
  @State sendSpinnerRotation: number = 0;
  @State voicePulseTick: number = 0;
  @State waterfallFullscreen: boolean = false;
  @State heartPressed: boolean = false;
  @State homeClockEpochMs: number = Date.now();
  @State composerFocused: boolean = false;
  private sendSpinnerTimerId: number = -1;
  private homeClockTimerId: number = -1;
  private voiceHoldTimerId: number = -1;
  private voiceHoldActive: boolean = false;
  private previousKeyboardAvoidMode: KeyboardAvoidMode = KeyboardAvoidMode.OFFSET;
  onOpenConfig: () => void = () => {};
  onOpenPublicPersona: () => void = () => {};
  onSendPrompt: () => void = () => {};
  onStartVoiceInput: () => void = () => {};
  onStopVoiceInput: () => void = () => {};
  onResetSession: () => void = () => {};
  onCloseFoodStoreMap: () => void = () => {};
  onFoodStoreMapLocationConfirm: (longitude: number, latitude: number, name: string, address: string) => void =
    (_longitude: number, _latitude: number, _name: string, _address: string): void => {};
  onCloseDeepSearch: () => void = () => {};
  onCloseCheckoutWeb: (taskId: string) => void = (_taskId: string): void => {};
  onCheckoutWebReturn: (url: string) => void = (_url: string): void => {};
  onTrainPresaleConfirm: (submission: TrainPresalePanelSubmission) => void =
    (_submission: TrainPresalePanelSubmission): void => {};
  onCloseTrainPresale: () => void = () => {};
  onCancelTrainPresaleTask: () => void = () => {};
  onOpenBim: () => void = () => {};
  onRememberBim: () => void = () => {};
  onReturnDailyBrief: () => void = () => {};
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onWaterfallFullscreenChange: (active: boolean) => void = (_active: boolean) => {};

  aboutToAppear(): void {
    const uiContext = this.getUIContext();
    this.previousKeyboardAvoidMode = uiContext.getKeyboardAvoidMode();
    uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.startSendSpinnerTimer();
    this.startHomeClockTimer();
  }

  aboutToDisappear(): void {
    this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
    this.stopSendSpinnerTimer();
    this.stopHomeClockTimer();
    this.cancelVoiceHoldTimer();
  }

  private startSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId >= 0) {
      return;
    }
    this.sendSpinnerTimerId = setInterval(() => {
      this.sendSpinnerRotation = nextSendSpinnerRotation(this.sendSpinnerRotation, this.isBusy);
      if (this.isVoiceListening) {
        this.voicePulseTick = (this.voicePulseTick + 1) % A2UI_VOICE_PULSE_STEPS;
      } else if (this.voicePulseTick !== 0) {
        this.voicePulseTick = 0;
      }
    }, A2UI_SEND_SPINNER_INTERVAL_MS);
  }

  private stopSendSpinnerTimer(): void {
    if (this.sendSpinnerTimerId < 0) {
      return;
    }
    clearInterval(this.sendSpinnerTimerId);
    this.sendSpinnerTimerId = -1;
  }

  private startHomeClockTimer(): void {
    this.homeClockEpochMs = Date.now();
    if (this.homeClockTimerId >= 0) {
      return;
    }
    this.homeClockTimerId = setInterval(() => {
      this.homeClockEpochMs = Date.now();
    }, A2UI_HOME_CLOCK_INTERVAL_MS);
  }

  private stopHomeClockTimer(): void {
    if (this.homeClockTimerId < 0) {
      return;
    }
    clearInterval(this.homeClockTimerId);
    this.homeClockTimerId = -1;
  }

  private historyPanelHeight(): number {
    if (!this.showHistory) {
      return 0;
    }
    if (this.messages.length === 0) {
      return A2UI_HISTORY_EMPTY_HEIGHT;
    }
    const contentHeight = A2UI_HISTORY_EMPTY_HEIGHT + this.messages.length * A2UI_HISTORY_ROW_HEIGHT;
    return Math.min(contentHeight, A2UI_HISTORY_MAX_HEIGHT);
  }

  private canResetSession(): boolean {
    return !this.isBusy && (!this.showWelcome || this.inputText.trim().length > 0);
  }

  private useNativeSurface(): boolean {
    return this.currentSurface.intent === 'social';
  }

  private isMultiTaskSurface(): boolean {
    return this.currentSurface.intent === 'multi-task';
  }

  private surfaceTopGap(): number {
    return this.isMultiTaskSurface() ? 2 : A2UI_HOME_SECTION_GAP;
  }

  private voiceWaveHeight(index: number): number {
    const phase = (this.voicePulseTick + index * 2) % A2UI_VOICE_PULSE_STEPS;
    const peak = phase <= 6 ? phase : A2UI_VOICE_PULSE_STEPS - phase;
    return 10 + peak * 4;
  }

  private voiceWaveOpacity(index: number): number {
    const phase = (this.voicePulseTick + index * 2) % A2UI_VOICE_PULSE_STEPS;
    const peak = phase <= 6 ? phase : A2UI_VOICE_PULSE_STEPS - phase;
    return 0.38 + peak * 0.08;
  }

  private voiceRingScale(phaseOffset: number): number {
    const phase = (this.voicePulseTick + phaseOffset) % A2UI_VOICE_PULSE_STEPS;
    return 1 + phase * 0.0025;
  }

  private voiceRingOpacity(phaseOffset: number): number {
    const phase = (this.voicePulseTick + phaseOffset) % A2UI_VOICE_PULSE_STEPS;
    return 0.52 - phase * 0.035;
  }

  private hasSendableText(): boolean {
    return !this.isBusy && this.inputText.trim().length > 0;
  }

  private sendButtonBackground(): string {
    return this.hasSendableText() ? A2UI_HOME_SEND_ACTIVE_BACKGROUND : A2UI_HOME_SEND_INACTIVE_BACKGROUND;
  }

  private cancelVoiceHoldTimer(): void {
    if (this.voiceHoldTimerId < 0) {
      return;
    }
    clearTimeout(this.voiceHoldTimerId);
    this.voiceHoldTimerId = -1;
  }

  private handleComposerHoldTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.cancelVoiceHoldTimer();
      if (this.voiceHoldActive || this.isVoiceListening) {
        this.onStopVoiceInput();
      }
      this.voiceHoldActive = false;
      return;
    }
    if (!canStartHomeComposerVoice(this.isBusy, this.inputText)) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.cancelVoiceHoldTimer();
      this.voiceHoldActive = false;
      this.voiceHoldTimerId = setTimeout(() => {
        this.voiceHoldTimerId = -1;
        if (!canStartHomeComposerVoice(this.isBusy, this.inputText)) {
          return;
        }
        this.voiceHoldActive = true;
        if (!this.isVoiceListening) {
          this.onStartVoiceInput();
        }
      }, A2UI_VOICE_HOLD_DELAY_MS);
    }
  }

  private heartAccessibilityText(): string {
    return this.bimVisibleCount <= 0 ?
      '打开心上事' :
      '打开心上事，共 ' + this.bimVisibleCount.toString() + ' 件';
  }

  private showBimSuggestion(): boolean {
    return !this.isBusy &&
      (this.bimSuggestionTitle.trim().length > 0 || this.bimRememberError.trim().length > 0);
  }

  private bimRememberLabel(): string {
    if (this.bimRememberState === 'saving') {
      return '正在记下';
    }
    return this.bimRememberState === 'saved' ? '♡ 已记在心上' : '♡ 记在心上';
  }

  private handleHeartTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.heartPressed = true;
      return;
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.heartPressed = false;
    }
  }

  @Builder
  private HomeBackdrop() {
    Image($r('app.media.home_light_aurora_background'))
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder
  private AiGeneratedDisclosure() {
    Row() {
      Text('AI生成')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(A2UI_HOME_AI_LABEL_TEXT)
        .maxLines(1)
    }
    .height(26)
    .padding({ left: 10, right: 10 })
    .margin({ left: 10 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(A2UI_HOME_AI_LABEL_BACKGROUND)
    .borderRadius(13)
    .border({ width: 1, color: A2UI_HOME_AI_LABEL_EDGE })
  }

  @Builder
  private WelcomeHero() {
    Column() {
      Column() {
        Text(homeTimeText(this.homeClockEpochMs))
          .fontSize(this.composerFocused ? 38 : 76)
          .fontWeight(FontWeight.Normal)
          .fontColor('#624838')
          .letterSpacing(this.composerFocused ? 0.4 : 1)
          .maxLines(1)
          .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })

        Text(homeDateText(this.homeClockEpochMs))
          .fontSize(this.composerFocused ? 12 : 15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#795C4A')
          .margin({ top: this.composerFocused ? 2 : 8 })
          .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })
      }
      .width('100%')
      .alignItems(this.composerFocused ? HorizontalAlign.Start : HorizontalAlign.Center)
      .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })

      Column() {
        Text(homeGreetingText(this.homeClockEpochMs))
          .fontSize(this.composerFocused ? 16 : 21)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4A3428')
          .maxLines(1)
          .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })

        Text(homePromptTitle(
          this.homeClockEpochMs,
          this.isBusy,
          this.isVoiceListening,
          this.composerFocused
        ))
          .fontSize(this.composerFocused ? 18 : 22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4A3428')
          .lineHeight(this.composerFocused ? 25 : 32)
          .maxLines(2)
          .margin({ top: this.composerFocused ? 4 : 8 })
          .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: this.composerFocused ? 16 : 36 })
      .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: this.composerFocused ? 12 : 28,
      right: this.composerFocused ? 12 : 28,
      top: this.composerFocused ? 0 : 6,
      bottom: 24
    })
    .animation({ duration: 280, curve: A2UI_MOTION_MOVE_CURVE })
  }

  @Builder
  private VoiceWaveBar(index: number) {
    Column() {}
      .width(index === A2UI_VOICE_WAVE_CENTER_INDEX ? 4 : 3)
      .height(this.voiceWaveHeight(index))
      .backgroundColor(index === A2UI_VOICE_WAVE_CENTER_INDEX ? COLOR_ACCENT_DEEP : COLOR_ACCENT)
      .borderRadius(4)
      .opacity(this.voiceWaveOpacity(index))
      .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
  }

  @Builder
  private VoiceWaveRing(color: string, phaseOffset: number) {
    Row() {}
      .width('99%')
      .height(A2UI_VOICE_DOCK_HEIGHT)
      .borderRadius((A2UI_HOME_FLOATING_RADIUS + 4))
      .border({ width: 2, color: color })
      .opacity(this.voiceRingOpacity(phaseOffset))
      .scale({
        x: this.voiceRingScale(phaseOffset),
        y: this.voiceRingScale(phaseOffset)
      })
      .shadow({ radius: 12, color: color, offsetX: 0, offsetY: 0 })
      .hitTestBehavior(HitTestMode.Transparent)
      .animation({ duration: A2UI_SEND_SPINNER_INTERVAL_MS, curve: Curve.Linear })
  }

  @Builder
  private VoiceListeningView() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        ForEach(A2UI_VOICE_WAVE_INDICES, (index: number) => {
          this.VoiceWaveBar(index)
        }, (index: number) => index.toString())
      }
      .width(220)
      .height(48)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(A2UI_VOICE_DOCK_HEIGHT - 8)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.HomeBackdrop()

      Column() {
        if (shouldShowHomeChrome(this.waterfallFullscreen)) {
        Row() {
          Image($r('app.media.logo_appless'))
            .width(A2UI_HEADER_LOGO_SIZE)
            .height(A2UI_HEADER_LOGO_SIZE)
            .objectFit(ImageFit.Contain)

          if (hasLlmReply(this.messages)) {
            this.AiGeneratedDisclosure()
          }

          Blank()
            .layoutWeight(1)

          A2uiButtonView({
            icon: $r('app.media.icon_reset'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary',
            isEnabled: this.canResetSession(),
            customBackgroundColor: A2UI_HOME_HEADER_BUTTON_BACKGROUND,
            customBorderColor: A2UI_HOME_HEADER_BUTTON_EDGE,
            shadowColor: A2UI_HOME_HEADER_BUTTON_SHADOW,
            shadowRadius: 8,
            shadowOffsetY: 3
          })
            .enabled(this.canResetSession())
            .onClick(() => {
              if (!this.canResetSession()) {
                return;
              }
              this.onResetSession();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })

          A2uiButtonView({
            icon: $r('app.media.icon_settings'),
            hasIcon: true,
            shape: 'circle',
            circleSize: A2UI_HEADER_BUTTON_SIZE,
            iconSize: A2UI_HEADER_BUTTON_ICON_SIZE,
            tone: 'secondary',
            customBackgroundColor: A2UI_HOME_HEADER_BUTTON_BACKGROUND,
            customBorderColor: A2UI_HOME_HEADER_BUTTON_EDGE,
            shadowColor: A2UI_HOME_HEADER_BUTTON_SHADOW,
            shadowRadius: 8,
            shadowOffsetY: 3
          })
            .onClick(() => {
              this.onOpenConfig();
            })
            .margin({ left: A2UI_HEADER_BUTTON_GAP })
        }
        .width('100%')
        .height(44)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 0, right: 0 })
        .margin({ bottom: this.showWelcome ? 0 : A2UI_HOME_SECTION_GAP })

        Column() {
          if (this.showHistory) {
            HistoryPanelView({
              messages: this.messages
            })
            .height('100%')
          }
        }
        .width('100%')
        .height(this.historyPanelHeight())
        .opacity(this.showHistory ? 1 : 0)
        .clip(true)
        .margin({ top: this.showHistory ? A2UI_HOME_SECTION_GAP : 0 })
        .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
      }

      if (this.showDeepSearch) {
        DeepSearchPanel({
          query: this.deepSearchQuery,
          settingsJson: this.deepSearchSettingsJson,
          contextJson: this.deepSearchContextJson,
          onClose: this.onCloseDeepSearch
        })
          .layoutWeight(1)
          .margin({ top: A2UI_HOME_SECTION_GAP })
      } else if (this.showTrainPresalePanel) {
        TrainPresalePanel({
          trip: this.trainPresaleTrip,
          task: this.trainPresaleTask,
          taskState: this.trainPresaleTaskState,
          errorMessage: this.trainPresaleError,
          isWorking: this.trainPresaleWorking,
          isDebugBuild: this.isDebugBuild,
          onConfirm: this.onTrainPresaleConfirm,
          onClose: this.onCloseTrainPresale,
          onCancelTask: this.onCancelTrainPresaleTask
        })
          .layoutWeight(1)
          .margin({ top: A2UI_HOME_SECTION_GAP })
      } else if (this.showCheckoutWeb && this.checkoutWebUrl.trim().length > 0) {
        CheckoutWebOverlay({
          kind: this.checkoutWebKind,
          url: this.checkoutWebUrl,
          taskId: this.checkoutWebTaskId,
          contextText: this.checkoutWebContext,
          onClose: this.onCloseCheckoutWeb,
          onReturnUrl: this.onCheckoutWebReturn
        })
          .layoutWeight(1)
          .margin({ top: A2UI_HOME_SECTION_GAP })
          .borderRadius(A2UI_HOME_FLOATING_RADIUS)
          .clip(true)
      } else if (this.showWelcome) {
        this.WelcomeHero()
      } else if (this.foodStoreMapOpen && this.currentSurface.intent === 'food') {
        Column() {
          Row() {
            Button('‹')
              .width(40)
              .height(40)
              .fontSize(28)
              .fontColor('#5E4D43')
              .backgroundColor('#F5EFE9')
              .borderRadius(20)
              .onClick(() => {
                this.onCloseFoodStoreMap();
              })
            Text('店铺地图')
              .layoutWeight(1)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor('#332821')
              .margin({ left: 10 })
          }
          .width('100%')
          .height(48)
          .alignItems(VerticalAlign.Center)

          FoodStoreMapView({
            amapKey: this.foodStoreMapAmapKey,
            snapshotJson: this.foodStoreMapSnapshotJson,
            snapshotTick: this.foodStoreMapSnapshotTick,
            onLocationConfirm: this.onFoodStoreMapLocationConfirm
          })
            .width('100%')
            .layoutWeight(1)
            .borderRadius(18)
            .clip(true)
        }
        .layoutWeight(1)
        .margin({ top: this.surfaceTopGap() })
      } else if (this.useNativeSurface()) {
        A2uiSurfaceView({
          surface: this.currentSurface,
          renderTick: this.surfaceRenderTick,
          isBusy: this.isBusy,
          showPendingSurface: false,
          onAction: this.onAction
        })
        .layoutWeight(1)
        .margin({ top: this.surfaceTopGap() })
      } else {
        Column() {
          HtmlHomeSurfaceView({
            html: this.htmlHomeHtml,
            multiTaskPayloadJson: this.multiTaskPayloadJson,
            multiTaskPayloadTick: this.multiTaskPayloadTick,
            waterfallPayloadJson: this.waterfallPayloadJson,
            waterfallPayloadTick: this.waterfallPayloadTick,
            waterfallBackRequestTick: this.waterfallBackRequestTick,
            mailDetailEventJson: this.mailDetailEventJson,
            mailReplyEventJson: this.mailReplyEventJson,
            mailCalendarEventJson: this.mailCalendarEventJson,
            isBusy: this.isBusy,
            renderTick: this.surfaceRenderTick,
            luckinInlinePatchJson: this.luckinInlinePatchJson,
            luckinInlinePatchTick: this.luckinInlinePatchTick,
            onAction: this.onAction,
            onWaterfallFullscreenChange: (active: boolean): void => {
              this.waterfallFullscreen = active;
              this.onWaterfallFullscreenChange(active);
            }
          })
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .margin({ top: this.waterfallFullscreen ? 0 : this.surfaceTopGap() })
      }

      if (shouldShowHomeChrome(this.waterfallFullscreen)) {
      Column() {
        if (this.locationServiceNotice.length > 0) {
          Text('定位服务未开启，附近结果可能不够准确。')
            .width('100%')
            .fontSize(11)
            .lineHeight(16)
            .fontColor('#7A665B')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 2 })
        }

        PageStateIndicator({
          currentPage: 0,
          reduceMotion: this.reduceMotion
        })
          .margin({ bottom: 2 })

        Stack({ alignContent: Alignment.Center }) {
          if (this.isVoiceListening) {
            this.VoiceWaveRing('#80F39A79', 0)
            this.VoiceWaveRing('#70B68CE8', 4)
            this.VoiceWaveRing('#668EBBF3', 8)
          }

          Row() {
            if (this.isVoiceListening) {
              this.VoiceListeningView()
            } else {
              if (this.inputText.trim().length === 0) {
                Blank()
                  .width(44)
              }

              TextArea({
                placeholder: this.inputPlaceholder,
                text: this.inputText
              })
                .height(homeComposerTextHeight(this.inputText))
                .constraintSize({ minHeight: 36, maxHeight: A2UI_COMPOSER_TEXT_MAX_HEIGHT })
                .layoutWeight(1)
                .fontSize(16)
                .fontColor(COLOR_TEXT)
                .lineHeight(24)
                .maxLines(A2UI_COMPOSER_TEXT_MAX_LINES)
                .textAlign(this.inputText.trim().length === 0 ? TextAlign.Center : TextAlign.Start)
                .enterKeyType(EnterKeyType.Send)
                .placeholderColor(COLOR_MUTED)
                .backgroundColor('#00000000')
                .borderRadius(0)
                .border({ width: 0 })
                .padding({
                  left: 10,
                  right: 0,
                  top: 6,
                  bottom: 8
                })
                .enabled(isPromptInputEnabled(this.isBusy))
                .onFocus(() => {
                  this.composerFocused = true;
                })
                .onBlur(() => {
                  this.composerFocused = false;
                })
                .onChange((value: string) => {
                  if (!isPromptInputEnabled(this.isBusy)) {
                    return;
                  }
                  if (value.length > 0) {
                    this.cancelVoiceHoldTimer();
                    this.voiceHoldActive = false;
                  }
                  this.inputText = value;
                })
                .onSubmit(() => {
                  if (!isPromptInputEnabled(this.isBusy)) {
                    return;
                  }
                  this.onSendPrompt();
                })

              A2uiButtonView({
                icon: this.isBusy ? $r('app.media.icon_wait_spinner') : $r('app.media.arrow_up'),
                hasIcon: true,
                shape: 'circle',
                circleSize: 38,
                iconSize: this.isBusy ? 21 : 17,
                isEnabled: this.hasSendableText(),
                customBackgroundColor: this.sendButtonBackground(),
                customBorderWidth: 0,
                shadowColor: this.hasSendableText() ? A2UI_HOME_SEND_SHADOW : '#00000000',
                shadowRadius: this.hasSendableText() ? 10 : 0,
                iconRotation: this.sendSpinnerRotation
              })
                .animation({
                  duration: this.isBusy ? A2UI_SEND_SPINNER_INTERVAL_MS : 220,
                  curve: this.isBusy ? Curve.Linear : A2UI_MOTION_MOVE_CURVE
                })
                .margin({ left: 6 })
                .enabled(this.hasSendableText())
                .onClick(() => {
                  if (!this.hasSendableText()) {
                    return;
                  }
                  this.onSendPrompt();
                })
            }
          }
          .width('100%')
          .constraintSize({
            minHeight: this.isVoiceListening ? A2UI_VOICE_DOCK_HEIGHT : A2UI_COMPOSER_MIN_HEIGHT,
            maxHeight: this.isVoiceListening ? A2UI_VOICE_DOCK_HEIGHT : A2UI_COMPOSER_MAX_HEIGHT
          })
          .alignItems(VerticalAlign.Center)
          .padding({
            left: this.isVoiceListening ? 10 : 8,
            right: this.isVoiceListening ? 14 : 8,
            top: this.isVoiceListening ? 4 : 5,
            bottom: this.isVoiceListening ? 4 : 5
          })
          .backgroundColor(this.isVoiceListening ? '#A6FFFFFF' : A2UI_HOME_GLASS_BACKGROUND)
          .borderRadius(this.isVoiceListening ? A2UI_HOME_FLOATING_RADIUS + 4 : 28)
          .border({ width: 1, color: this.isVoiceListening ? '#BFD8BCAF' : A2UI_HOME_GLASS_EDGE })
          .shadow({
            radius: this.isVoiceListening ? 24 : 18,
            color: this.isVoiceListening ? '#32995F4C' : A2UI_HOME_GLASS_SHADOW,
            offsetX: 0,
            offsetY: this.isVoiceListening ? 8 : 7
          })
          .animation({ duration: 320, curve: A2UI_MOTION_MOVE_CURVE })
        }
        .width('100%')
        .constraintSize({
          minHeight: this.isVoiceListening ?
            A2UI_VOICE_DOCK_HEIGHT + A2UI_COMPOSER_DOCK_EXTRA_HEIGHT :
            A2UI_COMPOSER_MIN_HEIGHT + A2UI_COMPOSER_DOCK_EXTRA_HEIGHT,
          maxHeight: this.isVoiceListening ?
            A2UI_VOICE_DOCK_HEIGHT + A2UI_COMPOSER_DOCK_EXTRA_HEIGHT :
            A2UI_COMPOSER_MAX_HEIGHT + A2UI_COMPOSER_DOCK_EXTRA_HEIGHT
        })
        .onTouch((event: TouchEvent) => {
          this.handleComposerHoldTouch(event);
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ top: A2UI_HOME_SECTION_GAP, left: 0, right: 0 })
      }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.waterfallFullscreen ? '100%' : A2UI_HOME_MAX_WIDTH })
      .height('100%')
      .padding({
        left: this.waterfallFullscreen ? 0 : A2UI_HOME_PAGE_PADDING_X,
        right: this.waterfallFullscreen ? 0 : A2UI_HOME_PAGE_PADDING_X,
        top: this.waterfallFullscreen ? 0 : A2UI_HOME_PAGE_PADDING_TOP,
        bottom: this.waterfallFullscreen ? 0 : A2UI_HOME_COMPOSER_BOTTOM_PADDING
      })
      .backgroundColor('#00000000')

    }
    .width('100%')
    .height('100%')
    .backgroundColor(A2UI_HOME_SHELL_BACKGROUND)
  }
}

@Component
export struct PageStateIndicator {
  @Prop currentPage: number = 0;
  @Prop reduceMotion: boolean = false;
  @State private discoveryHintOffset: number = 0;
  private hintTimerId: number = -1;

  aboutToAppear(): void {
    if (this.currentPage !== 0 || this.reduceMotion) return;
    this.hintTimerId = setTimeout((): void => {
      this.discoveryHintOffset = 3;
      this.hintTimerId = setTimeout((): void => {
        this.discoveryHintOffset = 0;
        this.hintTimerId = -1;
      }, 240);
    }, 520);
  }

  aboutToDisappear(): void {
    if (this.hintTimerId >= 0) clearTimeout(this.hintTimerId);
    this.hintTimerId = -1;
  }

  build() {
    Row({ space: 5 }) {
      Row() {}
        .width(this.currentPage === 0 ? 14 : 3)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.currentPage === 0 ? '#8E6558' : '#8A786E')

      Row() {}
        .width(this.currentPage === 1 ? 14 : 3)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.currentPage === 1 ? '#8E6558' : '#8A786E')
        .translate({ x: this.currentPage === 0 ? this.discoveryHintOffset : 0 })
        .animation({ duration: this.reduceMotion ? 0 : 240, curve: A2UI_MOTION_MOVE_CURVE })
    }
    .width('100%')
    .height(10)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .opacity(0.72)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
