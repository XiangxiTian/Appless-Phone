import { UiCatalogLayer } from '../ir/UiCanonicalTypes';

export type UiChildPolicy = 'leaf' | 'single' | 'many';

export interface UiCatalogPropRule {
  type: string;
}

export type UiCatalogPropsSchema = Record<string, UiCatalogPropRule>;

export interface UiCatalogItem {
  name: string;
  layer: UiCatalogLayer;
  version: number;
  groups: string[];
  propsSchema: UiCatalogPropsSchema;
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
    propsSchema: JSON.parse(JSON.stringify(item.propsSchema)) as UiCatalogPropsSchema,
    positionalFields: item.positionalFields.slice(),
    childPolicy: item.childPolicy,
    rendererKey: item.rendererKey,
    allowedEvents: item.allowedEvents.slice(),
    acceptedViewModels: item.acceptedViewModels.slice()
  };
}
