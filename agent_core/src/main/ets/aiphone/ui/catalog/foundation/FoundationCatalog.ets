import { UiCatalogItem } from '../UiCatalogItem';

function foundation(
  name: string,
  childPolicy: 'leaf' | 'single' | 'many',
  props: string[] = [],
  events: string[] = []
): UiCatalogItem {
  const schema: Object = {};
  props.forEach((prop: string): void => {
    (schema as Record<string, Object>)[prop] = { type: 'value' };
  });
  return {
    name,
    layer: 'foundation',
    version: 1,
    groups: ['foundation'],
    propsSchema: schema,
    positionalFields: props,
    childPolicy,
    rendererKey: name,
    allowedEvents: events,
    acceptedViewModels: []
  };
}

export function foundationCatalogItems(): UiCatalogItem[] {
  return [
    foundation('Surface', 'single', ['title']),
    foundation('Stack', 'many'),
    foundation('Row', 'many'),
    foundation('Grid', 'many', ['columns']),
    foundation('Card', 'many', ['tone']),
    foundation('Text', 'leaf', ['text', 'tone']),
    foundation('Icon', 'leaf', ['name']),
    foundation('Image', 'leaf', ['assetKey', 'alt']),
    foundation('Badge', 'leaf', ['text', 'tone']),
    foundation('Divider', 'leaf'),
    foundation('Progress', 'leaf', ['value', 'label']),
    foundation('Spacer', 'leaf', ['size']),
    foundation('Button', 'leaf', ['label'], ['activate']),
    foundation('Tabs', 'leaf', ['items'], ['select'])
  ];
}
