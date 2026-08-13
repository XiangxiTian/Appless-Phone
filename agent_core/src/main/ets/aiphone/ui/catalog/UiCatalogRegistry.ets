import { UiCatalog, catalogItemsByGroup } from './UiCatalog';
import { UiCatalogItem } from './UiCatalogItem';

export class UiCatalogRegistry {
  private readonly items: Map<string, UiCatalogItem> = new Map<string, UiCatalogItem>();
  private version: string = 'ui-catalog-v1';

  register(item: UiCatalogItem): void {
    if (item.name.length === 0 || item.version <= 0) {
      throw new Error('INVALID_CATALOG_ITEM');
    }
    this.items.set(item.name, item);
  }

  registerAll(items: UiCatalogItem[]): void {
    items.forEach((item: UiCatalogItem): void => this.register(item));
  }

  setVersion(version: string): void {
    if (version.length === 0) throw new Error('INVALID_CATALOG_VERSION');
    this.version = version;
  }

  resolve(name: string): UiCatalogItem | null {
    return this.items.get(name) ?? null;
  }

  list(groups?: string[]): UiCatalogItem[] {
    const all = Array.from(this.items.values());
    if (groups === undefined) return all;
    return catalogItemsByGroup({
      version: this.version,
      items: all,
      capabilityHash: this.capabilityHash()
    }, groups);
  }

  capabilityHash(groups?: string[]): string {
    return this.listWithoutHash(groups)
      .map((item: UiCatalogItem): string => item.name + '@' + item.version.toString())
      .sort()
      .join('|');
  }

  snapshot(groups?: string[]): UiCatalog {
    const items = this.listWithoutHash(groups);
    return {
      version: this.version,
      items,
      capabilityHash: this.capabilityHash(groups)
    };
  }

  private listWithoutHash(groups?: string[]): UiCatalogItem[] {
    const all = Array.from(this.items.values());
    if (groups === undefined) return all;
    const requested: Set<string> = new Set<string>(groups);
    return all.filter((item: UiCatalogItem): boolean => {
      return item.groups.some((group: string): boolean => requested.has(group));
    });
  }
}
