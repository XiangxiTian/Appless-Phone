import { UiCatalogItem, UiCatalogPropsSchema } from '../UiCatalogItem';

function extension(name: string, group: string, viewModel: string, events: string[] = []): UiCatalogItem {
  const propsSchema: UiCatalogPropsSchema = {};
  return {
    name,
    layer: 'extension',
    version: 1,
    groups: ['extension', group],
    propsSchema,
    positionalFields: [],
    childPolicy: 'leaf',
    rendererKey: name,
    allowedEvents: events,
    acceptedViewModels: [viewModel]
  };
}

export function extensionCatalogItems(): UiCatalogItem[] {
  return [
    extension('CalendarMonthGrid', 'calendar', 'ui.calendar-month', ['selectDate']),
    extension('RouteMap', 'maps', 'ui.route-map', ['selectPlace']),
    extension('SeatSelector', 'travel', 'ui.seat-map', ['selectSeat']),
    extension('EmailThread', 'mail', 'ui.email-thread', ['reply']),
    extension('PaymentSummary', 'payment', 'ui.payment-summary'),
    extension('MediaPlayer', 'media', 'ui.media-player', ['play', 'pause'])
  ];
}
