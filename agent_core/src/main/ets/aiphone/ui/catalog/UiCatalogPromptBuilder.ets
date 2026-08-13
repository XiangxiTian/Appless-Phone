import { UiCatalogItem } from './UiCatalogItem';
import { UiCatalogRegistry } from './UiCatalogRegistry';

export function buildUiCatalogPrompt(registry: UiCatalogRegistry, groups: string[]): string {
  const items: UiCatalogItem[] = registry.list(groups);
  const signatures = items.map((item: UiCatalogItem): string => {
    const props = Object.keys(item.propsSchema).sort().join(',');
    const models = item.acceptedViewModels.slice().sort().join('|');
    return item.name + '(' + props + ')' +
      ' children=' + item.childPolicy +
      ' models=' + models +
      ' events=' + item.allowedEvents.slice().sort().join('|');
  }).sort();
  return 'catalogVersion=' + registry.snapshot(groups).version + '\n' + signatures.join('\n');
}
