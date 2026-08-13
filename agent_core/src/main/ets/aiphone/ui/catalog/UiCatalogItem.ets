import { UiCatalogLayer } from '../ir/UiCanonicalTypes';

export type UiChildPolicy = 'leaf' | 'single' | 'many';

export interface UiCatalogItem {
  name: string;
  layer: UiCatalogLayer;
  version: number;
  groups: string[];
  propsSchema: Object;
  positionalFields: string[];
  childPolicy: UiChildPolicy;
  rendererKey: string;
  allowedEvents: string[];
  acceptedViewModels: string[];
}

export function cloneUiCatalogItem(item: UiCatalogItem): UiCatalogItem {
  return {
    name: item.name,
    layer: item.layer,
    version: item.version,
    groups: item.groups.slice(),
    propsSchema: JSON.parse(JSON.stringify(item.propsSchema)) as Object,
    positionalFields: item.positionalFields.slice(),
    childPolicy: item.childPolicy,
    rendererKey: item.rendererKey,
    allowedEvents: item.allowedEvents.slice(),
    acceptedViewModels: item.acceptedViewModels.slice()
  };
}
