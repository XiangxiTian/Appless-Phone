import { UiPresentationAdapterRegistry } from './UiPresentationAdapterRegistry';
import { createChoicePresentationAdapters } from './adapters/ChoicePresentationAdapters';
import { createJourneyPresentationAdapters } from './adapters/JourneyPresentationAdapters';
import { createMessagingPresentationAdapters } from './adapters/MessagingPresentationAdapters';
import { createGenericPresentationAdapters } from './adapters/GenericPresentationAdapters';

export function createDefaultUiPresentationAdapterRegistry(): UiPresentationAdapterRegistry {
  const registry = new UiPresentationAdapterRegistry();
  createChoicePresentationAdapters().forEach((adapter): void => registry.register(adapter));
  createJourneyPresentationAdapters().forEach((adapter): void => registry.register(adapter));
  createMessagingPresentationAdapters().forEach((adapter): void => registry.register(adapter));
  createGenericPresentationAdapters().forEach((adapter): void => registry.register(adapter));
  return registry;
}
