import { UiCatalogItem } from './UiCatalogItem';

export interface UiCatalog {
  version: string;
  items: UiCatalogItem[];
  capabilityHash: string;
}

export function catalogItemsByGroup(catalog: UiCatalog, groups: string[]): UiCatalogItem[] {
  const requested: Set<string> = new Set<string>(groups);
  return catalog.items.filter((item: UiCatalogItem): boolean => {
    return item.groups.some((group: string): boolean => requested.has(group));
  });
}

export function catalogHasComponent(catalog: UiCatalog, component: string, groups?: string[]): boolean {
  const candidates = groups === undefined ? catalog.items : catalogItemsByGroup(catalog, groups);
  return candidates.some((item: UiCatalogItem): boolean => item.name === component);
}
