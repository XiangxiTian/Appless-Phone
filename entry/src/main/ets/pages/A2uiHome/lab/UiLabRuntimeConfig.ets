import { LocalModelSettings, defaultLocalModelSettings } from '@loop/agent-core';

let currentSettings: LocalModelSettings | null = null;

function cloneSettings(settings: LocalModelSettings): LocalModelSettings {
  return {
    provider: settings.provider,
    baseUrl: settings.baseUrl,
    model: settings.model,
    apiKey: settings.apiKey,
    customParametersJson: settings.customParametersJson,
    ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
  };
}

export function configureUiLabModelSettings(settings: LocalModelSettings): void {
  currentSettings = cloneSettings(settings);
}

export function uiLabModelSettings(): LocalModelSettings {
  return cloneSettings(currentSettings === null ? defaultLocalModelSettings() : currentSettings);
}

export function clearUiLabModelSettings(): void {
  currentSettings = null;
}
