import { UiCatalogRegistry } from './UiCatalogRegistry';
import { foundationCatalogItems } from './foundation/FoundationCatalog';
import { semanticCatalogItems } from './semantic/SemanticCatalog';
import { extensionCatalogItems } from './extensions/ExtensionCatalogs';

export function createDefaultUiCatalogRegistry(includeExtensions: boolean = false): UiCatalogRegistry {
  const registry = new UiCatalogRegistry();
  registry.registerAll(foundationCatalogItems());
  registry.registerAll(semanticCatalogItems());
  if (includeExtensions) registry.registerAll(extensionCatalogItems());
  return registry;
}
