import {
  createDefaultUiPresentationAdapterRegistry,
  UiRunCoordinator
} from '@loop/agent-core';
import { UiLabV4FeatureFlags, UiLabV4Mode } from './UiLabV4FeatureFlags';
import { UiLabV4HostAdapter, UiLabV4HostCallbacks } from './UiLabV4HostAdapter';

export interface UiLabV4RuntimeBundle {
  mode: UiLabV4Mode;
  host: UiLabV4HostAdapter;
  coordinator: UiRunCoordinator;
}

export function createUiLabV4Runtime(
  flags: UiLabV4FeatureFlags,
  callbacks: UiLabV4HostCallbacks
): UiLabV4RuntimeBundle {
  const host = new UiLabV4HostAdapter(callbacks);
  const coordinator = new UiRunCoordinator(host, createDefaultUiPresentationAdapterRegistry());
  return { mode: flags.mode, host, coordinator };
}
