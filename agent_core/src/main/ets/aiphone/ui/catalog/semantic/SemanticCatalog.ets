import { UiCatalogItem, UiCatalogPropsSchema } from '../UiCatalogItem';

function semantic(
  name: string,
  viewModels: string[],
  props: string[] = [],
  events: string[] = []
): UiCatalogItem {
  const schema: UiCatalogPropsSchema = {};
  props.forEach((prop: string): void => {
    schema[prop] = { type: 'value-or-binding' };
  });
  return {
    name,
    layer: 'semantic',
    version: 1,
    groups: ['semantic', name.toLowerCase()],
    propsSchema: schema,
    positionalFields: props,
    childPolicy: 'leaf',
    rendererKey: name,
    allowedEvents: events,
    acceptedViewModels: viewModels
  };
}

export function semanticCatalogItems(): UiCatalogItem[] {
  return [
    semantic('ResultCollection', ['ui.result-collection']),
    semantic('ChoiceList', ['ui.option-collection'], ['selectionMode'], ['select']),
    semantic('OptionCard', ['ui.option-item'], ['variant'], ['select']),
    semantic('JourneyOptionList', ['ui.journey-option-collection'], ['selectionMode'], ['select']),
    semantic('ComparisonTable', ['ui.comparison-table']),
    semantic('KeyValueList', ['ui.key-value-group']),
    semantic('MetricGrid', ['ui.metric-grid']),
    semantic('Timeline', ['ui.timeline']),
    semantic('Schedule', ['ui.schedule']),
    semantic('MessageFeed', ['ui.message-feed'], [], ['open', 'select']),
    semantic('ThreadList', ['ui.message-thread']),
    semantic('DetailPanel', ['ui.detail-panel']),
    semantic('Form', ['ui.form-model'], [], ['submit', 'change']),
    semantic('FormField', ['ui.form-field'], ['label'], ['change']),
    semantic('FilterBar', ['ui.filter-model'], [], ['change']),
    semantic('ActionBar', ['ui.action-bar'], [], ['activate']),
    semantic('ApprovalPanel', ['ui.approval-model'], [], ['approve', 'reject']),
    semantic('AccountStatus', ['ui.account-status']),
    semantic('StatusNotice', ['ui.status-value']),
    semantic('ActivityFeed', ['ui.activity-feed']),
    semantic('MediaGallery', ['ui.media-gallery'])
  ];
}
