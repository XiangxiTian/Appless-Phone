import {
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { A2UI_MOTION_CURVE } from '../style/A2uiHomeMotion';

export const LONG_TERM_MEMORY_PLACEHOLDER_TITLE: string = '长期记忆';
export const LONG_TERM_MEMORY_PLACEHOLDER_MESSAGE: string =
  '记忆查看与修正将在后续版本提供。届时你可以先阅读整理后的总结，再提出需要删除或修正的内容。';

@Component
export struct LongTermMemoryPlaceholderPage {
  @StorageProp('a2uiSystemTopInsetVp') systemTopInsetVp: number = 24;
  onBack: () => void = () => {};

  build() {
    Column() {
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
          Text(LONG_TERM_MEMORY_PLACEHOLDER_TITLE)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text('查看和修正 Appless 记住的内容')
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

      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.icon_history'))
            .width(34)
            .height(34)
            .objectFit(ImageFit.Contain)
        }
        .width(64)
        .height(64)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(32)

        Text('功能准备中')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .margin({ top: 18 })

        Text(LONG_TERM_MEMORY_PLACEHOLDER_MESSAGE)
          .width('100%')
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .lineHeight(22)
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 30, bottom: 30 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(20)
      .border({ width: 1, color: COLOR_CARD_EDGE })
      .margin({ top: 28 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 16 + this.systemTopInsetVp, bottom: 16 })
    .backgroundColor(COLOR_PANEL)
  }
}
