export type UiLabV4Mode = 'ui_lab_legacy' | 'ui_lab_v4_shadow' | 'ui_lab_v4_visible';

export interface UiLabV4FeatureFlags {
  mode: UiLabV4Mode;
  diagnosticsEnabled: boolean;
  uiLangEnabled: boolean;
  cacheEnabled: boolean;
}

export function defaultUiLabV4FeatureFlags(): UiLabV4FeatureFlags {
  return {
    mode: 'ui_lab_legacy',
    diagnosticsEnabled: false,
    uiLangEnabled: false,
    cacheEnabled: false
  };
}

export function uiLabV4Visible(flags: UiLabV4FeatureFlags): boolean {
  return flags.mode === 'ui_lab_v4_visible';
}

export function uiLabV4Shadow(flags: UiLabV4FeatureFlags): boolean {
  return flags.mode === 'ui_lab_v4_shadow' || flags.mode === 'ui_lab_v4_visible';
}

export function uiLabV4WithMode(flags: UiLabV4FeatureFlags, mode: UiLabV4Mode): UiLabV4FeatureFlags {
  return {
    mode,
    diagnosticsEnabled: flags.diagnosticsEnabled,
    uiLangEnabled: flags.uiLangEnabled,
    cacheEnabled: flags.cacheEnabled
  };
}
