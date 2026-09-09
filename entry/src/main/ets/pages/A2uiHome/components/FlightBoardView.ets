import { A2uiAction, A2uiComponent, A2uiSurfaceState, emptyA2uiSurface } from '@loop/agent-core';
import { actionsOf, flightOptions, A2uiFlightOption } from '@loop/agent-core';
import { canCreateNavigationCardFromFlightOption } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DARK,
  COLOR_ACCENT_DEEP,
  COLOR_ACCENT_SOFT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_CARD_GLOW,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_FIELD,
  COLOR_INK,
  COLOR_MUTED,
  COLOR_TEXT
} from '../style/A2uiHomeTheme';
import { componentBodyOf, componentStatusOf, componentTitleOf } from '../render/A2uiRenderData';
import { ctripFlightBookingSelection } from '../travel/TravelBookingProvider';
import {
  travelCalendarActionForFlight,
  travelCalendarEventFromFlight
} from '../travel/TravelCalendarAction';
import { A2UI_PANEL_BACKGROUND_COLOR, A2UI_PANEL_BORDER_COLOR, A2UI_PANEL_CORNER_RADIUS } from '../style/A2uiPanelFrameStyle';
import { ActionBarView } from './ActionBarView';
import { StatusBadgeView } from './StatusBadgeView';
import { A2uiPanelAccentView } from './common/A2uiPanelAccentView';

@Component
export struct FlightBoardView {
  @Prop surface: A2uiSurfaceState = emptyA2uiSurface();
  @Prop component: A2uiComponent = { id: '', component: 'FlightBoard' };
  @Prop renderTick: number = 0;
  @Prop isBusy: boolean = false;
  @State fastestFirst: boolean = false;
  @State expandedFlightKey: string = '';
  onAction: (action: A2uiAction) => void = (_action: A2uiAction) => {};
  onPinFlightNavigationCard: (item: A2uiFlightOption) => void = (_item: A2uiFlightOption) => {};

  private flights(): A2uiFlightOption[] {
    return flightOptions(this.surface, this.component);
  }

  private clockMinutes(value: string): number {
    const match = /(\d{1,2}):(\d{2})/.exec(value);
    return match === null ? 999999 : Number.parseInt(match[1], 10) * 60 + Number.parseInt(match[2], 10);
  }

  private durationMinutes(item: A2uiFlightOption): number {
    const depart = this.clockMinutes(item.depTime);
    const arrive = this.clockMinutes(item.arrTime);
    if (depart >= 999999 || arrive >= 999999) return 999999;
    return arrive >= depart ? arrive - depart : arrive + 24 * 60 - depart;
  }

  private visibleFlights(): A2uiFlightOption[] {
    const next = this.flights().slice();
    if (this.fastestFirst) {
      next.sort((left: A2uiFlightOption, right: A2uiFlightOption) => {
        return this.durationMinutes(left) - this.durationMinutes(right);
      });
    }
    return next;
  }

  private actionForState(action: A2uiAction): A2uiAction {
    const active = action.id === 'client_sort_fastest' && this.fastestFirst;
    if (!active) return action;
    return {
      id: action.id, label: action.label, prompt: action.prompt,
      kind: action.kind, variant: 'activated', args: action.args
    };
  }

  private visibleActions(): A2uiAction[] {
    const actions: A2uiAction[] = [];
    actionsOf(this.component).forEach((action: A2uiAction) => {
      if (action.id === 'client_show_more' || action.id === 'client_filter_available' ||
        action.id === 'travel_retry' || action.id === 'flight_retry_date') return;
      actions.push(this.actionForState(action));
    });
    return actions;
  }

  private handleAction(action: A2uiAction): void {
    if (action.id === 'client_sort_fastest') {
      this.fastestFirst = !this.fastestFirst;
      return;
    }
    this.onAction(action);
  }

  private flightRoute(item: A2uiFlightOption): string {
    const dep = item.dep.length > 0 ? item.dep : '--';
    const arr = item.arr.length > 0 ? item.arr : '--';
    return dep + ' → ' + arr;
  }

  private flightKey(item: A2uiFlightOption): string {
    return item.flightNo + '|' + item.dep + '|' + item.depTime + '|' + item.arrTime;
  }

  private timeText(item: A2uiFlightOption): string {
    const dep = item.depTime.length > 0 ? item.depTime : '--';
    const arr = item.arrTime.length > 0 ? item.arrTime : '--';
    return dep + ' - ' + arr;
  }

  private canAddCalendarReminder(item: A2uiFlightOption): boolean {
    return travelCalendarEventFromFlight(item) !== null;
  }

  private calendarButtonLabel(item: A2uiFlightOption): string {
    if (item.calendarConflict === true) return '时间冲突';
    return this.canAddCalendarReminder(item) ? '加入日历' : '缺少日期或时间，暂不能加入日历';
  }

  private calendarConflictText(item: A2uiFlightOption): string {
    const title = item.calendarConflictTitle === undefined ? '' : item.calendarConflictTitle.trim();
    return title.length > 0 ? '时间冲突 · 与“' + title + '”重叠' : '时间冲突 · 与系统日历已有安排重叠';
  }

  private ctripBookingAction(item: A2uiFlightOption): A2uiAction {
    const selection = ctripFlightBookingSelection(item);
    return {
      id: 'flight.booking.ctrip.open',
      label: '打开携程',
      prompt: JSON.stringify({
        flightNo: item.flightNo,
        depTime: item.depTime,
        dep: item.dep,
        arr: item.arr,
        fromCode: selection.fromCode,
        toCode: selection.toCode,
        travelDate: selection.travelDate
      }),
      kind: 'client',
      variant: 'primary'
    };
  }

  @Builder
  private FlightDetailPanel(item: A2uiFlightOption) {
    Column() {
      Row() {
        Text('路线')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .width(58)
        Text(this.flightRoute(item))
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 4, bottom: 4 })
      Row() {
        Text('时间')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .width(58)
        Text(this.timeText(item))
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({ top: 4, bottom: 4 })
      if (item.status.length > 0) {
        Row() {
          Text('状态')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .width(58)
          Text(item.status)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ top: 4, bottom: 4 })
      }
      Text('航班信息来自飞常准；点击后将打开携程 App，票价、余票和订单状态以携程实时信息为准。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ top: 8 })
      Button('打开携程')
        .enabled(!this.isBusy)
        .height(42)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_BUTTON_TEXT)
        .backgroundColor(COLOR_ACCENT_DEEP)
        .borderRadius(11)
        .margin({ top: 10 })
        .onClick(() => {
          this.onAction(this.ctripBookingAction(item));
        })
      Button(canCreateNavigationCardFromFlightOption(item) ? '固定为导航卡片' : '缺少坐标，不能固定')
        .enabled(canCreateNavigationCardFromFlightOption(item) && !this.isBusy)
        .height(38)
        .width('100%')
        .fontSize(13)
        .fontColor(canCreateNavigationCardFromFlightOption(item) ? COLOR_ACCENT_DARK : COLOR_MUTED)
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(10)
        .border({ width: 1, color: canCreateNavigationCardFromFlightOption(item) ? COLOR_ACCENT : COLOR_CARD_EDGE })
        .margin({ top: 10 })
        .onClick(() => {
          this.onPinFlightNavigationCard(item);
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(COLOR_FIELD)
    .borderRadius(10)
    .border({ width: { left: 3 }, color: COLOR_ACCENT })
    .margin({ top: 10 })
  }

  build() {
    Column() {
      A2uiPanelAccentView()

      Column() {
      Row() {
        Column() {
          Text(componentTitleOf(this.component, '航班候选'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          if (componentBodyOf(this.component).length > 0) {
            Text(componentBodyOf(this.component))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(20)
              .margin({ top: 7 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        StatusBadgeView({
          status: componentStatusOf(this.component, this.surface.status),
          label: ''
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.visibleFlights().length === 0) {
        Text('暂无可展示航班')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding({ top: 14, bottom: 4 })
      } else {
        ForEach(this.visibleFlights(), (item: A2uiFlightOption) => {
          Column() {
            Row() {
              Column() {
                Text(item.flightNo.length > 0 ? item.flightNo : '--')
                  .fontSize(19)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_INK)
                Text(item.airline.length > 0 ? item.airline : '航空公司待确认')
                  .fontSize(12)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(18)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (item.price.length > 0) {
                Text('¥' + item.price)
                  .fontSize(12)
                  .fontColor(COLOR_ACCENT_DARK)
                  .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                  .backgroundColor(COLOR_ACCENT_SOFT)
                  .borderRadius(8)
                  .margin({ right: 8 })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Row() {
              Text(this.flightRoute(item))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT)
                .layoutWeight(1)
              Text(item.status.length > 0 ? item.status : '计划')
                .fontSize(12)
                .fontColor(COLOR_ACCENT_DARK)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 12 })

            Text(this.timeText(item))
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 6 })

            if (item.calendarConflict === true) {
              Text(this.calendarConflictText(item))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_ERROR)
                .padding({ left: 9, right: 9, top: 6, bottom: 6 })
                .backgroundColor(COLOR_ERROR_SOFT)
                .borderRadius(8)
                .margin({ top: 9 })
            }

            Button(this.calendarButtonLabel(item))
              .enabled(this.canAddCalendarReminder(item) && !this.isBusy)
              .height(38)
              .width('100%')
              .fontSize(13)
              .fontColor(item.calendarConflict === true ? COLOR_BUTTON_TEXT :
                (this.canAddCalendarReminder(item) ? COLOR_ACCENT_DARK : COLOR_MUTED))
              .backgroundColor(item.calendarConflict === true ? COLOR_ERROR : COLOR_ACCENT_SOFT)
              .borderRadius(10)
              .border({
                width: 1,
                color: item.calendarConflict === true ? COLOR_ERROR :
                  (this.canAddCalendarReminder(item) ? COLOR_ACCENT : COLOR_CARD_EDGE)
              })
              .margin({ top: 10 })
              .onClick(() => {
                this.onAction(travelCalendarActionForFlight(item, this.component.id));
              })

            if (this.expandedFlightKey === this.flightKey(item)) {
              this.FlightDetailPanel(item)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(16)
          .border({ width: item.calendarConflict === true ? 2 : 1,
            color: item.calendarConflict === true ? COLOR_ERROR : COLOR_CARD_EDGE })
          .shadow({ radius: 20, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 9 })
          .margin({ top: 10 })
          .onClick(() => {
            const key = this.flightKey(item);
            this.expandedFlightKey = this.expandedFlightKey === key ? '' : key;
          })
        }, (item: A2uiFlightOption) => this.flightKey(item) + '-' + this.renderTick.toString())
      }

      ActionBarView({
        actions: this.visibleActions(),
        isBusy: this.isBusy,
        onAction: (action: A2uiAction) => {
          this.handleAction(action);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 18, bottom: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(A2UI_PANEL_BACKGROUND_COLOR)
    .borderRadius(A2UI_PANEL_CORNER_RADIUS)
    .border({ width: 1, color: A2UI_PANEL_BORDER_COLOR })
    .shadow({ radius: 22, color: COLOR_CARD_GLOW, offsetX: 0, offsetY: 10 })
    .margin({ bottom: 12 })
  }
}
