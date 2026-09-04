import {
  MemoryCorrectionDiff,
  MemoryCorrectionOperation,
  MemoryCorrectionPlan,
  MemoryOverview,
  MemoryOverviewClaim
} from '../../../memory/MemoryOverview';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_CARD_SHADOW,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_MOTION_CURVE } from '../style/A2uiHomeMotion';
import {
  MANAGEMENT_CARD_SHADOW_OFFSET_Y,
  MANAGEMENT_CARD_SHADOW_RADIUS
} from './ManagementPageVisualStyle';

const PAGE_PADDING: number = 16;
const CARD_RADIUS: number = 18;

export type LongTermMemoryPageStatus = 'loading' | 'empty' | 'error' | 'ready';
export type LongTermMemoryApplyResultStatus =
  'success' | 'presentation_only' | 'conflict' | 'partial' | 'error' | 'inactive';
export const LONG_TERM_MEMORY_CORRECTION_SUCCESS_TOAST: string = '长期记忆已按确认方案修改';

export function shouldScrollLongTermMemoryApplyResultToTop(
  status: LongTermMemoryApplyResultStatus
): boolean {
  return status !== 'inactive';
}

export interface LongTermMemoryOverviewDisplaySection {
  heading: string;
  body: string;
}

export function longTermMemoryOverviewDisplaySections(
  overview: MemoryOverview
): LongTermMemoryOverviewDisplaySection[] {
  return overview.claims.map((claim: MemoryOverviewClaim): LongTermMemoryOverviewDisplaySection => ({
    heading: claim.heading,
    body: claim.body
  }));
}

export function memoryCorrectionPlanTouchesPublicPersona(plan: MemoryCorrectionPlan | null): boolean {
  if (plan === null) return false;
  for (let position = 0; position < plan.operations.length; position += 1) {
    const operation = plan.operations[position];
    if ((operation.type === 'update' || operation.type === 'delete') &&
      operation.personaTag === 'public_persona') return true;
  }
  return false;
}

@Component
export struct LongTermMemoryPage {
  @StorageProp('a2uiSystemTopInsetVp') systemTopInsetVp: number = 24;
  @Prop status: LongTermMemoryPageStatus = 'loading';
  @Prop overview: MemoryOverview | null = null;
  @Prop message: string = '';
  @Prop plan: MemoryCorrectionPlan | null = null;
  @Prop correctionInput: string = '';
  @Prop planning: boolean = false;
  @Prop applying: boolean = false;
  @Prop @Watch('onScrollToTopRequest') scrollToTopTick: number = 0;
  private pageScroller: Scroller = new Scroller();

  onBack: () => void = () => {};
  onRetry: () => void = () => {};
  onCorrectionInputChange: (value: string) => void = (_value: string): void => {};
  onPlanCorrection: () => void = () => {};
  onConfirmPlan: () => void = () => {};
  onCancelPlan: () => void = () => {};

  private onScrollToTopRequest(): void {
    setTimeout((): void => {
      this.pageScroller.scrollEdge(Edge.Top);
    }, 0);
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
        Text(this.plan === null ? '长期记忆' : '确认修正方案')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text(this.plan === null ? '查看概览并修正 Appless 记住的内容' : '确认后才会修改长期记忆')
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
  private LoadingState() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(34)
        .height(34)
        .color(COLOR_ACCENT)
      Text('正在整理长期记忆…')
        .fontSize(14)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .padding({ top: 56, bottom: 56 })
    .backgroundColor(COLOR_CARD_RAISED)
    .borderRadius(CARD_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: MANAGEMENT_CARD_SHADOW_RADIUS, color: COLOR_CARD_SHADOW,
      offsetX: 0, offsetY: MANAGEMENT_CARD_SHADOW_OFFSET_Y })
  }

  @Builder
  private MessageState(title: string, detail: string, error: boolean) {
    Column() {
      Text(title)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(error ? COLOR_ERROR : COLOR_INK)
      Text(detail)
        .width('100%')
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(21)
        .textAlign(TextAlign.Center)
        .margin({ top: 10 })
      if (error) {
        Button('重试')
          .height(40)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(11)
          .margin({ top: 18 })
          .onClick(() => {
            this.onRetry();
          })
      }
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 34, bottom: 34 })
    .backgroundColor(error ? COLOR_ERROR_SOFT : COLOR_CARD_RAISED)
    .borderRadius(CARD_RADIUS)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: MANAGEMENT_CARD_SHADOW_RADIUS, color: COLOR_CARD_SHADOW,
      offsetX: 0, offsetY: MANAGEMENT_CARD_SHADOW_OFFSET_Y })
  }

  @Builder
  private OverviewSection(section: LongTermMemoryOverviewDisplaySection) {
    Column() {
      Text(section.heading)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text(section.body)
        .width('100%')
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(22)
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private OverviewContent(overview: MemoryOverview) {
    Column({ space: 12 }) {
      Column() {
        Text(overview.title)
          .width('100%')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text(overview.summary)
          .width('100%')
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .lineHeight(22)
          .margin({ top: 10 })

        ForEach(longTermMemoryOverviewDisplaySections(overview),
          (section: LongTermMemoryOverviewDisplaySection, sectionIndex: number) => {
            Divider()
              .color(COLOR_LINE)
              .margin({ top: 16, bottom: 14 })
            this.OverviewSection(section)
          }, (_section: LongTermMemoryOverviewDisplaySection, sectionIndex: number): string =>
            sectionIndex.toString())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(17)
      .backgroundColor(COLOR_CARD_RAISED)
      .borderRadius(CARD_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: MANAGEMENT_CARD_SHADOW_RADIUS, color: COLOR_CARD_SHADOW,
        offsetX: 0, offsetY: MANAGEMENT_CARD_SHADOW_OFFSET_Y })

      Column() {
        Text('哪里需要修改？')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        Text('可以说明哪些内容不准确、需要删除，或只是希望换一种概览表述。')
          .width('100%')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 6 })
        TextArea({ text: this.correctionInput, placeholder: '例如：我已经不喝咖啡了，请修正相关记忆' })
          .width('100%')
          .height(112)
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor(COLOR_FIELD)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .padding(12)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.onCorrectionInputChange(value);
          })
        Button(this.planning ? '正在生成方案…' : '生成修正方案')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(12)
          .margin({ top: 12 })
          .enabled(!this.planning && !this.applying && this.correctionInput.trim().length > 0)
          .onClick(() => {
            this.onPlanCorrection();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(COLOR_CARD_RAISED)
      .borderRadius(CARD_RADIUS)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .shadow({ radius: MANAGEMENT_CARD_SHADOW_RADIUS, color: COLOR_CARD_SHADOW,
        offsetX: 0, offsetY: MANAGEMENT_CARD_SHADOW_OFFSET_Y })
    }
    .width('100%')
  }

  @Builder
  private PlanContent(plan: MemoryCorrectionPlan) {
    Column({ space: 12 }) {
      if (plan.status === 'needs_clarification') {
        Column() {
          Text('还需要确认')
            .width('100%')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(plan.clarificationQuestion)
            .width('100%')
            .fontSize(14)
            .fontColor(COLOR_TEXT)
            .lineHeight(22)
            .margin({ top: 10 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(17)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(CARD_RADIUS)
        .border({ width: 1, color: COLOR_CARD_EDGE })
      } else {
        if (memoryCorrectionPlanTouchesPublicPersona(plan)) {
          Text('这些修改包含社交账号画像导入的记忆；重新导入社交画像可能覆盖这项修改。')
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_ERROR)
            .lineHeight(20)
            .padding(13)
            .backgroundColor(COLOR_ERROR_SOFT)
            .borderRadius(12)
        }

        ForEach(plan.diffs, (diff: MemoryCorrectionDiff, diffIndex: number) => {
          Column() {
            Row() {
              Text(diff.willWrite ? '将修改长期记忆' : '仅修改当前概览')
                .fontSize(11)
                .fontColor(diff.willWrite ? COLOR_ERROR : COLOR_MUTED)
            }
            .width('100%')

            if (diff.before.length > 0) {
              Text('修改前')
                .fontSize(11)
                .fontColor(COLOR_MUTED)
                .margin({ top: 12 })
              Text(diff.before)
                .width('100%')
                .fontSize(13)
                .fontColor(COLOR_TEXT)
                .lineHeight(20)
                .margin({ top: 4 })
            }
            if (diff.after.length > 0) {
              Text('修改后')
                .fontSize(11)
                .fontColor(COLOR_MUTED)
                .margin({ top: 12 })
              Text(diff.after)
                .width('100%')
                .fontSize(13)
                .fontColor(COLOR_INK)
                .lineHeight(20)
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(15)
          .backgroundColor(COLOR_CARD_RAISED)
          .borderRadius(CARD_RADIUS)
          .border({ width: 1, color: COLOR_CARD_EDGE })
        }, (_diff: MemoryCorrectionDiff, diffIndex: number): string => diffIndex.toString())

        if (plan.writeOperationCount === 0) {
          Text('这个方案只调整当前概览的展示措辞，不会改动长期记忆。再次进入页面会恢复基础概览。')
            .width('100%')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(20)
            .padding(13)
            .backgroundColor(COLOR_PANEL)
            .borderRadius(12)
        }
      }

      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_CARD)
          .borderRadius(12)
          .border({ width: 1, color: COLOR_CARD_EDGE })
          .enabled(!this.applying)
          .onClick(() => {
            this.onCancelPlan();
          })
        if (plan.status === 'ready') {
          Button(this.applying ? '正在修改…' : '确认修改')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor(COLOR_ACCENT)
            .borderRadius(12)
            .enabled(!this.applying)
            .onClick(() => {
              this.onConfirmPlan();
            })
        }
      }
      .width('100%')
      .margin({ top: 4, bottom: 8 })
    }
    .width('100%')
  }

  build() {
    Scroll(this.pageScroller) {
      Column() {
        this.Header()

        if (this.plan !== null) {
          this.PlanContent(this.plan)
        } else if (this.status === 'loading') {
          this.LoadingState()
        } else if (this.status === 'empty') {
          this.MessageState('还没有长期记忆', this.message.length > 0 ? this.message :
            '继续使用 Appless 后，确认保存的长期偏好会出现在这里。', false)
        } else if (this.status === 'error') {
          this.MessageState('概览暂时不可用', this.message.length > 0 ? this.message :
            '请稍后重试。', true)
        } else if (this.overview !== null) {
          this.OverviewContent(this.overview)
        }

        if (this.plan === null && this.status === 'ready' && this.message.length > 0) {
          Text(this.message)
            .width('100%')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .textAlign(TextAlign.Center)
            .margin({ top: 12, bottom: 4 })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({
        left: PAGE_PADDING,
        right: PAGE_PADDING,
        top: PAGE_PADDING + this.systemTopInsetVp,
        bottom: PAGE_PADDING
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PAGE)
  }
}
