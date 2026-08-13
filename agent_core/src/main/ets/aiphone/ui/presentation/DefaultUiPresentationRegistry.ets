import { UiPresentationAdapterRegistry } from './UiPresentationAdapterRegistry';
import { createChoicePresentationAdapters } from './adapters/ChoicePresentationAdapters';

export function createDefaultUiPresentationAdapterRegistry(): UiPresentationAdapterRegistry {
  const registry = new UiPresentationAdapterRegistry();
  createChoicePresentationAdapters().forEach((adapter): void => registry.register(adapter));
  return registry;
}
