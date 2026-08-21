import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction } from '@loop/agent-core';
import { isHtmlHomeActionAllowed } from '../main/ets/pages/A2uiHome/html/HtmlHomeActionPolicy';
import {
  HtmlHomeAction,
  HtmlHomeBlock,
  HtmlHomeDocument,
  HtmlHomeKind
} from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

interface ThreadOnlyArgsFixture {
  threadId: string;
}

interface BookingUrlArgsFixture {
  bookingUrl: string;
}

interface StripeOnboardingArgsFixture {
  onboardingUrl: string;
}

interface PaymentCaptureArgsFixture {
  provider: string;
  phase: string;
  providerSessionId: string;
}

interface PaymentCheckoutArgsFixture {
  provider: string;
  providerSessionId: string;
}

interface MailReplyArgsFixture {
  requestKey: string;
  provider?: string;
  threadId: string;
  messageId?: string;
  to: string[];
  subject: string;
  body: string;
}

interface MailCalendarArgsFixture {
  requestKey: string;
  provider: string;
  threadId: string;
  messageId: string;
}

interface CalendarDeleteArgsFixture {
  eventId: string;
  calendarId: string;
}

interface LuckinArgsFixture {
  deptId?: string;
  location?: string;
  productId?: string;
  skuCode?: string;
  quantity?: number;
  previewPrompt?: string;
  attrGroup?: string;
  attrChoice?: string;
  locationSource?: string;
  orderId?: string;
}

interface HotelNavigateArgsFixture {
  hotelId: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
}

interface HotelDetailArgsFixture {
  hotelId: number;
  checkInDate: string;
  checkOutDate: string;
  countryCode: string;
  currency: string;
  adultCount: number;
  childCount: number;
  childAgeDetails: number[];
  roomCount: number;
}

interface LuckinShopArgsFixture {
  deptId: string;
  deptName: string;
  address: string;
  distance: string;
  status: string;
}

interface FirecrawlMonitorArgsFixture {
  id: string;
  confirmed?: boolean;
}

interface PhoneArgsFixture {
  phone: string;
}

function action(id: string, prompt: string, kind: string = 'client', args: Object | null = null): A2uiAction {
  const next: A2uiAction = {
    id: id,
    label: id,
    prompt: prompt,
    variant: 'primary',
    kind: kind
  };
  if (args !== null) {
    next.args = args;
  }
  return next;
}

function documentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'dynamic-tools',
    title: 'Tool',
    subtitle: '',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'connect',
      kind: 'dynamic-tool-connect',
      title: 'Weather',
      subtitle: '',
      status: 'needs_auth',
      credentialName: 'Authorization',
      credentialRef: 'dynamic:weather:Authorization',
      toolId: 'weather.query',
      prompt: '深圳天气',
      metrics: [],
      rows: [],
      actions: [{ id: 'dynamic_test_connection', label: '测试连接', prompt: '深圳天气', variant: 'primary', kind: 'client' }]
    }, {
      id: 'food-1',
      kind: 'food-result',
      title: 'Coffee',
      subtitle: '',
      status: 'ready',
      source: 'amap',
      metrics: [],
      rows: [],
      actions: [
        { id: 'html_open_food_map', label: '打开地图', prompt: '{"index":0,"name":"Coffee"}', variant: 'primary', kind: 'client' },
        { id: 'html_call_food', label: '拨打电话', prompt: '{"index":0,"name":"Coffee"}', variant: 'secondary', kind: 'client' }
      ]
    }],
    actions: [{ id: 'gmail.open.web', label: 'Gmail Web', prompt: 'https://mail.google.com/', variant: 'secondary', kind: 'client' }],
    history: [],
    persona: { id: '', name: '', avatarKey: '', status: '', reason: '' },
    personaMemory: { summary: '', preferences: [] },
    rawSurfaceRoot: null,
    generatedAt: '2026-06-26T00:00:00.000Z'
  };
}

function hotelActionDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'hotel';
  const detail: HotelDetailArgsFixture = {
    hotelId: 47675,
    checkInDate: '2026-08-15',
    checkOutDate: '2026-08-17',
    countryCode: 'CN',
    currency: 'CNY',
    adultCount: 2,
    childCount: 0,
    childAgeDetails: [],
    roomCount: 1
  };
  const navigate: HotelNavigateArgsFixture = {
    hotelId: 47675,
    name: '深圳测试酒店',
    address: '深圳市南山区科技南路 88 号',
    latitude: 22.5431,
    longitude: 114.0579
  };
  doc.blocks = [{
    id: 'hotel-47675',
    kind: 'generic-tool-result',
    title: '深圳测试酒店',
    status: 'success',
    source: 'RollingGo',
    metrics: [{ label: 'toolName', value: 'hotel.search' }],
    rows: [{ label: '酒店 ID', value: '47675' }],
    actions: [
      { id: 'hotel.detail', label: '查看实时房型', prompt: '查看实时房型', variant: 'primary', kind: 'prompt', args: detail },
      { id: 'hotel.navigate', label: '导航到酒店', prompt: '导航到酒店', variant: 'secondary', kind: 'prompt', args: navigate }
    ]
  }];
  doc.actions = doc.blocks[0].actions.slice();
  return doc;
}

export default function htmlHomeActionPolicyTest() {
  describe('htmlHomeActionPolicy', () => {
    it('allows exact daily brief snapshot actions', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"daily-brief"') as HtmlHomeKind;
      doc.actions = [
        action('daily.brief.regenerate', '重新生成'),
        action('daily.brief.history.open', '前一天', 'client', JSON.parse('{"direction":"previous"}') as Object),
        action('daily.brief.mail.read', '查看消息', 'client', JSON.parse(
          '{"provider":"gmail","threadId":"thread-1","messageId":"","requestKey":"request-1"}'
        ) as Object),
        action('daily.brief.discovery.open', '查看完整发现流')
      ];

      doc.actions.forEach((value: HtmlHomeAction): void => {
        const candidate: A2uiAction = {
          id: value.id,
          label: value.label,
          prompt: value.prompt,
          variant: value.variant,
          kind: value.kind,
          args: value.args
        };
        expect(isHtmlHomeActionAllowed(doc, candidate)).assertTrue();
      });
    });

    it('validates only bounded edited daily brief preference fields against the base save action', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"daily-brief"') as HtmlHomeKind;
      doc.actions = [action('daily.brief.preference.save', '保存偏好', 'client', JSON.parse(
        '{"topics":["AI 产品"],"language":"中文优先","timeBudgetMinutes":15,' +
        '"formats":["图文"],"negativePreference":"减少重复","targetTime":"08:30"}'
      ) as Object)];
      const valid = JSON.parse(
        '{"topics":["HarmonyOS","Agent"],"language":"中英混合","timeBudgetMinutes":5,' +
        '"formats":["短视频"],"negativePreference":"少看重复内容","targetTime":"07:45"}'
      ) as Object;
      const invalid: Object[] = [
        JSON.parse('{"topics":["AI"],"language":"中文优先","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":"少重复","targetTime":"24:00"}') as Object,
        JSON.parse('{"topics":["1","2","3","4","5","6","7","8","9"],"language":"中文优先","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":"少重复","targetTime":"08:30"}') as Object,
        JSON.parse('{"topics":["AI"],"language":"英文","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":"少重复","targetTime":"08:30"}') as Object,
        JSON.parse('{"topics":["12345678901234567890123456789012345678901"],"language":"中文优先","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":"少重复","targetTime":"08:30"}') as Object,
        JSON.parse('{"topics":["AI"],"language":"中文优先","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":"少重复","targetTime":"08:30","url":"https://evil.example"}') as Object,
        JSON.parse('{"topics":["AI"],"language":"中文优先","timeBudgetMinutes":5,"formats":["图文"],"negativePreference":{"raw":"nested"},"targetTime":"08:30"}') as Object
      ];

      expect(isHtmlHomeActionAllowed(doc,
        action('daily.brief.preference.save', '保存偏好', 'client', valid))).assertTrue();
      invalid.forEach((args: Object): void => {
        expect(isHtmlHomeActionAllowed(doc,
          action('daily.brief.preference.save', '保存偏好', 'client', args))).assertFalse();
      });
      expect(isHtmlHomeActionAllowed(doc,
        action('daily.brief.preference.save.forged', '保存偏好', 'client', valid))).assertFalse();
    });
    it('allows only actions from the current HTML document snapshot', 0, () => {
      const doc = documentFixture();
      const phoneArgs: PhoneArgsFixture = { phone: '075512345678' };

      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://mail.google.com/'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.open.web', 'https://evil.example/'))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":0,"name":"Coffee"}'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_open_food_map', '{"index":99,"name":"Other"}'))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, action('html_call_food', '{"index":0,"name":"Coffee"}'))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_call_food', '{"index":0,"name":"Other"}'))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_call_food', '{"index":0,"name":"Coffee"}', 'client', phoneArgs))).assertFalse();
      doc.blocks[1].actions = doc.blocks[1].actions.filter((item: HtmlHomeAction) => item.id !== 'html_call_food');
      expect(isHtmlHomeActionAllowed(doc, action('html_call_food', '{"index":0,"name":"Coffee"}'))).assertFalse();
    });

    it('allows favorite actions only for the current food surface and a bounded food id', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"food"') as HtmlHomeKind;
      doc.surfaceId = 'food-surface';
      const allowedArgs = JSON.parse('{"surfaceId":"food-surface","favoriteId":"food:nicecoffee@114.1,22.5"}') as Object;
      const wrongSurfaceArgs = JSON.parse('{"surfaceId":"other-surface","favoriteId":"food:nicecoffee@114.1,22.5"}') as Object;
      const invalidIdArgs = JSON.parse('{"surfaceId":"food-surface","favoriteId":"hotel:123"}') as Object;

      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_remove', '取消收藏门店', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_map', '导航到收藏门店', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_call', '拨打收藏门店电话', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_pin', '固定收藏门店', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_luckin_menu_open', '查询菜单', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_menu_open', '查询菜单', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_remove', '取消收藏门店', 'client', wrongSurfaceArgs))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_favorite_remove', '取消收藏门店', 'client', invalidIdArgs))).assertFalse();
    });

    it('allows opening the store map only for the current food surface', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"food"') as HtmlHomeKind;
      doc.surfaceId = 'food-surface';
      const allowedArgs = JSON.parse('{"surfaceId":"food-surface"}') as Object;
      const wrongSurfaceArgs = JSON.parse('{"surfaceId":"other-surface"}') as Object;

      expect(isHtmlHomeActionAllowed(doc,
        action('food_store_map_open', '打开店铺地图', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_store_map_open', '打开店铺地图', 'client', wrongSurfaceArgs))).assertFalse();
    });

    it('allows bounded Luckin menu preview actions only on the current food surface', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"food"') as HtmlHomeKind;
      doc.surfaceId = 'food-surface';
      const allowedArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"deptId":"1001","location":"114.1,22.5","productId":"2002","skuCode":"sku-1"}') as Object;
      const wrongSurfaceArgs = JSON.parse('{"surfaceId":"other-surface","requestKey":"store|address",' +
        '"deptId":"1001","location":"114.1,22.5","productId":"2002","skuCode":"sku-1"}') as Object;
      const invalidLocationArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"deptId":"1001","location":"invalid","productId":"2002","skuCode":"sku-1"}') as Object;

      expect(isHtmlHomeActionAllowed(doc,
        action('food_luckin_order_preview', '去点餐', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_luckin_order_preview', '去点餐', 'client', wrongSurfaceArgs))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_luckin_order_preview', '去点餐', 'client', invalidLocationArgs))).assertFalse();
    });

    it('allows bounded McDonalds Web ordering actions only on the current food surface', 0, () => {
      const doc = documentFixture();
      doc.kind = JSON.parse('"food"') as HtmlHomeKind;
      doc.surfaceId = 'food-surface';
      const detailArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"productId":"9900008139"}') as Object;
      const quoteArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"productId":"9900008139","quantity":2}') as Object;
      const createArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"productId":"9900008139","quantity":2,"quoteToken":"food-surface:1"}') as Object;
      const orderArgs = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"orderId":"order-1"}') as Object;
      const invalidQuantity = JSON.parse('{"surfaceId":"food-surface","requestKey":"store|address",' +
        '"productId":"9900008139","quantity":0}') as Object;

      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_menu_detail', '查看详情', 'client', detailArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_order_quote', '核算价格', 'client', quoteArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_order_create', '确认下单', 'client', createArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_order_status', '刷新订单状态', 'client', orderArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_pay_open', '打开支付页面', 'client', orderArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('food_mcd_order_quote', '核算价格', 'client', invalidQuantity))).assertFalse();
    });

    it('allows only visible Firecrawl source and monitor actions from the current document', 0, () => {
      const doc = documentFixture();
      const visibleMonitorArgs: FirecrawlMonitorArgsFixture = { id: 'monitor-current' };
      const forgedMonitorArgs: FirecrawlMonitorArgsFixture = { id: 'monitor-forged' };
      const visibleSourceAction: A2uiAction = {
        id: 'web.open.source',
        label: '打开来源',
        prompt: 'https://www.firecrawl.dev/monitor',
        variant: 'secondary',
        kind: 'client'
      };
      const sourceActionWithDifferentUrl: A2uiAction = {
        id: 'web.open.source',
        label: '打开来源',
        prompt: 'https://evil.example/',
        variant: 'secondary',
        kind: 'client'
      };
      const visibleMonitorAction: A2uiAction = {
        id: 'web.monitor.detail',
        label: '查看详情',
        prompt: '查看详情',
        variant: 'secondary',
        kind: 'prompt',
        args: visibleMonitorArgs
      };
      const monitorActionWithDifferentId: A2uiAction = {
        id: 'web.monitor.detail',
        label: '查看详情',
        prompt: '查看详情',
        variant: 'secondary',
        kind: 'prompt',
        args: forgedMonitorArgs
      };
      doc.blocks = [{
        id: 'firecrawl-monitor-current',
        kind: 'generic-tool-result',
        title: 'Firecrawl Monitor',
        subtitle: '',
        status: 'success',
        source: 'Firecrawl',
        metrics: [{ label: 'toolName', value: 'web.monitor.list' }],
        rows: [{ label: 'Monitor ID', value: 'monitor-current' }],
        actions: [visibleSourceAction, visibleMonitorAction]
      }];
      doc.actions = doc.blocks[0].actions.slice();

      expect(isHtmlHomeActionAllowed(doc, visibleSourceAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, sourceActionWithDifferentUrl)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, visibleMonitorAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, monitorActionWithDifferentId)).assertFalse();
    });

    it('allows only the visible confirmed Firecrawl monitor mutation', 0, () => {
      const confirmDoc = documentFixture();
      const visibleConfirmArgs: FirecrawlMonitorArgsFixture = {
        id: 'monitor-current',
        confirmed: true
      };
      const unconfirmedArgs: FirecrawlMonitorArgsFixture = {
        id: 'monitor-current'
      };
      const visibleMonitorConfirmAction: A2uiAction = {
        id: 'web.monitor.delete.confirm',
        label: '确认删除',
        prompt: '确认删除',
        variant: 'danger',
        kind: 'prompt',
        args: visibleConfirmArgs
      };
      const confirmActionWithoutConfirmedFlag: A2uiAction = {
        id: 'web.monitor.delete.confirm',
        label: '确认删除',
        prompt: '确认删除',
        variant: 'danger',
        kind: 'prompt',
        args: unconfirmedArgs
      };
      confirmDoc.blocks = [{
        id: 'firecrawl-monitor-delete-confirm',
        kind: 'generic-tool-result',
        title: '确认删除 Monitor',
        subtitle: '',
        status: 'needs_user',
        source: 'Firecrawl',
        metrics: [{ label: 'toolName', value: 'web.monitor.list' }],
        rows: [{ label: 'Monitor ID', value: 'monitor-current' }],
        actions: [visibleMonitorConfirmAction]
      }];
      confirmDoc.actions = confirmDoc.blocks[0].actions.slice();

      expect(isHtmlHomeActionAllowed(confirmDoc, visibleMonitorConfirmAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(confirmDoc, confirmActionWithoutConfirmedFlag)).assertFalse();
    });

    it('allows only the visible 12306 booking action arguments', 0, () => {
      const doc = documentFixture();
      const bookingUrl =
        'https://kyfw.12306.cn/otn/leftTicket/init?linktypeid=dc&fs=test&ts=test&date=2026-07-22&flag=N,N,Y';
      const visibleArgs: BookingUrlArgsFixture = { bookingUrl: bookingUrl };
      const forgedArgs: BookingUrlArgsFixture = { bookingUrl: 'https://evil.example/' };
      const visible: HtmlHomeAction = {
        id: 'train.booking.open',
        label: '去购票',
        prompt: '',
        variant: 'primary',
        kind: 'client',
        args: visibleArgs
      };
      doc.blocks[0].actions = [visible];
      const allowed: A2uiAction = {
        id: 'train.booking.open',
        label: '去购票',
        prompt: '',
        variant: 'primary',
        kind: 'client',
        args: visibleArgs
      };
      const forged: A2uiAction = {
        id: 'train.booking.open',
        label: '去购票',
        prompt: '',
        variant: 'primary',
        kind: 'client',
        args: forgedArgs
      };

      expect(isHtmlHomeActionAllowed(doc, allowed)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, forged)).assertFalse();
    });

    it('allows Calendar delete only for the exact rendered confirmation action', 0, () => {
      const doc = documentFixture();
      const allowed: CalendarDeleteArgsFixture = { eventId: 'event-1', calendarId: 'primary' };
      doc.blocks.push({
        id: 'calendar-event-1',
        kind: 'generic-tool-result',
        title: '产品同步',
        subtitle: '',
        status: 'success',
        source: 'Google Calendar API',
        toolId: 'calendar.events.search',
        metrics: [],
        rows: [{ label: 'Event ID', value: 'event-1' }],
        actions: [action('calendar.event.delete.confirm', '删除日程', 'prompt', allowed)]
      });
      const wrongEvent: CalendarDeleteArgsFixture = { eventId: 'event-2', calendarId: 'primary' };

      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', wrongEvent))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'client', allowed))).assertFalse();

      doc.blocks[doc.blocks.length - 1].actions = [];
      expect(isHtmlHomeActionAllowed(doc,
        action('calendar.event.delete.confirm', '删除日程', 'prompt', allowed))).assertFalse();
    });

    it('allows dynamic credential save only for the current dynamic block', 0, () => {
      const doc = documentFixture();
      const allowedPayload = JSON.stringify({
        credentialRef: 'dynamic:weather:Authorization',
        credentialValue: 'secret',
        toolId: 'weather.query',
        prompt: '深圳天气'
      });
      const blockedPayload = JSON.stringify({
        credentialRef: 'dynamic:other:Authorization',
        credentialValue: 'secret',
        toolId: 'statistics.search',
        prompt: 'GDP'
      });

      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', allowedPayload))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('html_dynamic_save_and_test', blockedPayload))).assertFalse();
    });

    it('checks action args when allowing HTML actions', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'thread-999'
      };
      doc.actions.push({
        id: 'gmail.ai.reply.draft',
        label: 'AI 回复草稿',
        prompt: 'reply',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('gmail.ai.reply.draft', 'reply', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows only exact visible read-only hotel actions', 0, () => {
      const doc = hotelActionDocumentFixture();
      const detail = doc.blocks[0].actions[0] as A2uiAction;
      const navigate = doc.blocks[0].actions[1] as A2uiAction;
      const changedNavigate = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedDetail = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (changedNavigate.args as HotelNavigateArgsFixture).latitude = 23.1;
      (changedDetail.args as HotelDetailArgsFixture).hotelId = 99999;

      expect(isHtmlHomeActionAllowed(doc, detail)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, navigate)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, changedNavigate)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedDetail)).assertFalse();

      const changedAddress = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedLongitude = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedNavigateName = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      const changedNavigateHotel = JSON.parse(JSON.stringify(navigate)) as A2uiAction;
      (changedAddress.args as HotelNavigateArgsFixture).address = '其他地址';
      (changedLongitude.args as HotelNavigateArgsFixture).longitude = 113.1;
      (changedNavigateName.args as HotelNavigateArgsFixture).name = '其他酒店';
      (changedNavigateHotel.args as HotelNavigateArgsFixture).hotelId = 99999;
      expect(isHtmlHomeActionAllowed(doc, changedAddress)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedLongitude)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedNavigateName)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedNavigateHotel)).assertFalse();

      const changedDate = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      const changedGuests = JSON.parse(JSON.stringify(detail)) as A2uiAction;
      (changedDate.args as HotelDetailArgsFixture).checkInDate = '2026-08-16';
      (changedGuests.args as HotelDetailArgsFixture).adultCount = 3;
      expect(isHtmlHomeActionAllowed(doc, changedDate)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, changedGuests)).assertFalse();

      const current = hotelActionDocumentFixture();
      current.blocks[0].actions.splice(2, 1);
      current.actions = current.blocks[0].actions.slice();
      expect(isHtmlHomeActionAllowed(current, changedDetail)).assertFalse();
    });

    it('allows mail reply submissions only for the matching visible mail card', 0, () => {
      const doc = documentFixture();
      const detailIdentity: MailCalendarArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123'
      };
      const template: MailReplyArgsFixture = {
        requestKey: '',
        threadId: 'thread-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: ''
      };
      doc.blocks.push({
        id: 'gmail-message-123',
        kind: 'generic-tool-result',
        title: 'Status update',
        subtitle: '',
        status: 'success',
        source: 'Gmail',
        metrics: [],
        rows: [],
        actions: [{
          id: 'html_mail_detail_read',
          label: '加载正文',
          prompt: 'gmail:thread-123',
          variant: 'secondary',
          kind: 'client',
          args: detailIdentity
        }, {
          id: 'gmail.ai.reply.draft',
          label: 'AI 回复草稿',
          prompt: 'reply',
          variant: 'primary',
          kind: 'prompt',
          args: template
        }]
      });
      const allowed: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };
      const blocked: MailReplyArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-other',
        messageId: 'message-123',
        to: ['alice@example.com'],
        subject: 'Re: Status update',
        body: 'Confirmed.'
      };
      const wrongMessage: MailReplyArgsFixture = JSON.parse(JSON.stringify(allowed)) as MailReplyArgsFixture;
      wrongMessage.messageId = 'message-stale';
      const wrongRequest: MailReplyArgsFixture = JSON.parse(JSON.stringify(allowed)) as MailReplyArgsFixture;
      wrongRequest.requestKey = 'gmail:thread-stale';
      const wrongProvider: MailReplyArgsFixture = JSON.parse(JSON.stringify(allowed)) as MailReplyArgsFixture;
      wrongProvider.provider = 'qq';
      const wrongRecipient: MailReplyArgsFixture = JSON.parse(JSON.stringify(allowed)) as MailReplyArgsFixture;
      wrongRecipient.to = ['mallory@example.com'];
      const emptyBody: MailReplyArgsFixture = JSON.parse(JSON.stringify(allowed)) as MailReplyArgsFixture;
      emptyBody.body = '   ';

      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_save', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', blocked))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', wrongMessage))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-stale', 'client', wrongRequest))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', wrongProvider))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', wrongRecipient))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_send', 'gmail:thread-123', 'client', emptyBody))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_reply_ai_generate', 'gmail:thread-123', 'client', blocked))).assertFalse();
    });

    it('allows mail calendar add only for the matching visible mail card', 0, () => {
      const doc = documentFixture();
      const detailArgs: MailCalendarArgsFixture = {
        requestKey: '',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123'
      };
      doc.blocks.push({
        id: 'gmail-meeting-123',
        kind: 'generic-tool-result',
        title: 'Meeting invite',
        subtitle: '',
        status: 'success',
        source: 'Gmail',
        metrics: [],
        rows: [],
        actions: [{
          id: 'html_mail_detail_read',
          label: '加载正文',
          prompt: 'gmail:thread-123',
          variant: 'secondary',
          kind: 'client',
          args: detailArgs
        }]
      });
      const allowed: MailCalendarArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-123',
        messageId: 'message-123'
      };
      const blocked: MailCalendarArgsFixture = {
        requestKey: 'gmail:thread-123',
        provider: 'gmail',
        threadId: 'thread-other',
        messageId: 'message-123'
      };

      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_calendar_add', 'gmail:thread-123', 'client', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('html_mail_calendar_add', 'gmail:thread-123', 'client', blocked))).assertFalse();
    });

    it('allows only matching payment actions from the current HTML document', 0, () => {
      const doc = documentFixture();
      const expectedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-123'
      };
      const blockedArgs: ThreadOnlyArgsFixture = {
        threadId: 'payment-999'
      };
      doc.actions.push({
        id: 'payment.confirm',
        label: '确认支付',
        prompt: 'confirm',
        variant: 'primary',
        kind: 'prompt',
        args: expectedArgs
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', expectedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.confirm', 'confirm', 'prompt', blockedArgs))).assertFalse();
    });

    it('allows payment account saves only on payment pages with a usable target', 0, () => {
      const doc = documentFixture();
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-save',
        kind: 'generic-tool-result',
        title: '补充金额',
        subtitle: 'Payment target resolved.',
        status: 'ready',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [{ label: '收款方', value: 'Dana' }],
        actions: []
      }];
      const allowed = JSON.stringify({
        displayName: 'Dana',
        aliases: '小丹',
        paypalEmail: 'dana@example.com'
      });
      const missingTarget = JSON.stringify({
        displayName: 'Dana'
      });

      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', missingTarget))).assertFalse();
      doc.kind = 'generic';
      expect(isHtmlHomeActionAllowed(doc, action('payment.account.save', allowed))).assertFalse();
    });

    it('allows PayPal Google Pay capture only for the current checkout order', 0, () => {
      const doc = documentFixture();
      const checkoutArgs: PaymentCheckoutArgsFixture = {
        provider: 'paypal',
        providerSessionId: 'ORDER-1'
      };
      const checkoutAction: HtmlHomeAction = {
        id: 'payment.checkout.open',
        label: '打开确认页',
        prompt: 'https://www.sandbox.paypal.com/checkoutnow?token=ORDER-1',
        variant: 'primary',
        kind: 'client',
        args: checkoutArgs
      };
      doc.kind = 'payment';
      doc.blocks = [{
        id: 'payment-google-pay',
        kind: 'generic-tool-result',
        title: '打开支付确认页',
        subtitle: 'PayPal Google Pay',
        status: 'needs_user',
        source: 'PayPal',
        metrics: [
          { label: 'source', value: 'PayPal' },
          { label: 'toolName', value: 'payment.send' }
        ],
        rows: [
          { label: '支付方式', value: 'PayPal' },
          { label: '付款方式偏好', value: 'Google Pay' }
        ],
        actions: [checkoutAction]
      }];
      const allowed: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-1'
      };
      const wrongOrder: PaymentCaptureArgsFixture = {
        provider: 'paypal',
        phase: 'capture',
        providerSessionId: 'ORDER-2'
      };

      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', allowed))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('payment.capture', 'capture', 'prompt', wrongOrder))).assertFalse();
    });

    it('allows luckin confirm option preview actions with switched attrs', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const createArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1
      };
      const createAction: HtmlHomeAction = {
        id: 'luckin.order.create',
        label: '确认下单',
        prompt: '确认创建瑞幸订单',
        variant: 'primary',
        kind: 'prompt',
        args: createArgs
      };
      doc.blocks = [{
        id: 'luckin-confirm',
        kind: 'generic-tool-result',
        title: '确认瑞幸订单',
        subtitle: '',
        status: 'ready',
        source: '瑞幸',
        metrics: [],
        rows: [],
        actions: [createAction]
      }];
      const optionArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1,
        previewPrompt: '生椰拿铁，少甜，冰',
        attrGroup: '糖度',
        attrChoice: '少甜'
      };
      const invalidOptionArgs: LuckinArgsFixture = {
        deptId: '1001',
        attrGroup: '糖度',
        attrChoice: '少甜'
      };
      const optionPreview = action('luckin.order.preview', '生椰拿铁，少甜，冰', 'prompt', optionArgs);

      expect(isHtmlHomeActionAllowed(doc, optionPreview)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.preview', 'evil', 'prompt', invalidOptionArgs))).assertFalse();
    });

    it('rejects a stale Luckin create after the visible option and SKU change', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const createArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU001',
        quantity: 1
      };
      const createAction: HtmlHomeAction = {
        id: 'luckin.order.create',
        label: '确认下单',
        prompt: '确认创建瑞幸订单',
        variant: 'primary',
        kind: 'prompt',
        args: createArgs
      };
      doc.blocks = [{
        id: 'luckin-confirm',
        kind: 'generic-tool-result',
        title: '确认瑞幸订单',
        subtitle: '',
        status: 'ready',
        source: '瑞幸',
        metrics: [],
        rows: [],
        actions: [createAction]
      }];
      const switchedArgs: LuckinArgsFixture = {
        deptId: '1001',
        location: '114.0,22.5',
        productId: '2002',
        skuCode: 'SKU002',
        previewPrompt: '生椰拿铁，少甜，冰',
        quantity: 1
      };
      const switchedCreate = action('luckin.order.create', '确认创建瑞幸订单', 'prompt', switchedArgs);

      expect(isHtmlHomeActionAllowed(doc, switchedCreate)).assertFalse();
      expect(isHtmlHomeActionAllowed(doc, createAction as A2uiAction)).assertTrue();
    });

    it('allows only the exact visible ride trace and order actions', 0, () => {
      const doc = documentFixture();
      const confirmArgs = JSON.parse(
        '{"productCategory":"express","estimateTraceId":"trace-real-1",' +
        '"pickupLocation":"114.0,22.5","destinationLocation":"114.1,22.6"}'
      ) as Object;
      const cancelArgs = JSON.parse('{"orderId":"ride-order-real-1"}') as Object;
      const confirm: HtmlHomeAction = {
        id: 'ride.order.confirm', label: '确认叫车', prompt: '确认叫车',
        variant: 'primary', kind: 'prompt', args: confirmArgs
      };
      const cancel: HtmlHomeAction = {
        id: 'ride.order.cancel', label: '取消订单', prompt: '取消订单',
        variant: 'danger', kind: 'prompt', args: cancelArgs
      };
      doc.blocks = [{
        id: 'ride-current', kind: 'generic-tool-result', title: '滴滴订单', subtitle: '',
        status: 'success', source: '滴滴', metrics: [], rows: [], actions: [confirm, cancel]
      }];
      const staleTrace = JSON.parse(
        '{"productCategory":"express","estimateTraceId":"trace-stale",' +
        '"pickupLocation":"114.0,22.5","destinationLocation":"114.1,22.6"}'
      ) as Object;
      const wrongOrder = JSON.parse('{"orderId":"ride-order-other"}') as Object;

      expect(isHtmlHomeActionAllowed(doc, confirm as A2uiAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, cancel as A2uiAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(doc,
        action('ride.order.confirm', '确认叫车', 'prompt', staleTrace))).assertFalse();
      expect(isHtmlHomeActionAllowed(doc,
        action('ride.order.cancel', '取消订单', 'prompt', wrongOrder))).assertFalse();
    });

    it('allows luckin relocate refresh preview on luckin pages', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      const args: LuckinArgsFixture = {
        locationSource: 'refresh'
      };
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.preview', '生椰拿铁', 'prompt', args))).assertTrue();
    });

    it('allows luckin payment page actions without exact snapshot match', 0, () => {
      const doc = documentFixture();
      doc.kind = 'luckin';
      doc.blocks = [{
        id: 'luckin-payment',
        kind: 'generic-tool-result',
        title: '瑞幸订单已创建',
        subtitle: '',
        status: 'success',
        source: '瑞幸',
        metrics: [{ label: 'toolName', value: 'luckin.order.create' }],
        rows: [{ label: '订单号', value: 'LK001' }],
        actions: []
      }];
      doc.actions = [];

      const args: LuckinArgsFixture = { orderId: 'LK001' };

      expect(isHtmlHomeActionAllowed(doc, action('luckin.pay.open', 'weixin://wxpay/bizpayurl?pr=abc', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.demo.alipay.open', 'alipays://', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.demo.googlepay.open', 'google pay', 'client', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.order.status', '查询瑞幸订单状态', 'prompt', args))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('luckin.pay.open', '', 'client'))).assertTrue();
    });

    it('allows only the current Stripe onboarding URL to open from HTML', 0, () => {
      const doc = documentFixture();
      doc.blocks.push({
        id: 'stripe-receiving',
        kind: 'StripeReceivingAccountCard',
        title: 'Stripe 收款账户',
        subtitle: '继续认证',
        status: 'onboarding_required',
        source: 'stripe',
        metrics: [],
        rows: [],
        actions: [],
        stripeReceiving: {
          status: 'onboarding_required',
          message: '继续认证',
          stripeAccountId: 'acct_123',
          onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123',
          currentlyDue: []
        }
      });

      const allowedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://connect.stripe.com/setup/s/acct_123'
      };
      const blockedArgs: StripeOnboardingArgsFixture = {
        onboardingUrl: 'https://evil.example/setup'
      };

      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://connect.stripe.com/setup/s/acct_123', 'client', allowedArgs))).assertTrue();
      expect(isHtmlHomeActionAllowed(doc, action('stripe.account.open', 'https://evil.example/setup', 'client', blockedArgs))).assertFalse();
    });

    it('allows luckin actions from embedded multi_task sections', 0, () => {
      const luckinDoc = documentFixture();
      luckinDoc.kind = 'luckin';
      const shopArgs: LuckinShopArgsFixture = {
        deptId: '1001',
        deptName: '瑞幸咖啡 深圳科技园店',
        address: '深圳市南山区科技园',
        distance: '120m',
        status: '营业中'
      };
      const shopBlock: HtmlHomeBlock = {
        id: 'luckin-shop',
        kind: 'generic-tool-result',
        title: '选择瑞幸门店',
        subtitle: '',
        status: 'ready',
        source: '瑞幸',
        metrics: [],
        rows: [],
        actions: [{
          id: 'luckin.order.preview',
          label: '科技园店',
          prompt: '生椰拿铁',
          variant: 'primary',
          kind: 'prompt',
          args: shopArgs
        }]
      };
      luckinDoc.blocks = [shopBlock];
      const multiTaskDoc = documentFixture();
      multiTaskDoc.kind = 'multi-task';
      const multiTaskBlock: HtmlHomeBlock = {
        id: 'slot_0',
        kind: 'multi-task-section',
        title: '瑞幸点单',
        sectionId: 'slot_0',
        toolId: 'luckin.order.preview',
        status: 'ready',
        metrics: [],
        rows: [],
        actions: [],
        embeddedDocument: luckinDoc
      };
      multiTaskDoc.blocks = [multiTaskBlock];

      const shopAction = action('luckin.order.preview', '生椰拿铁', 'prompt', shopArgs);
      expect(isHtmlHomeActionAllowed(multiTaskDoc, shopAction)).assertTrue();
      expect(isHtmlHomeActionAllowed(multiTaskDoc, action('luckin.order.preview', 'evil', 'prompt'))).assertFalse();
    });
  });
}
