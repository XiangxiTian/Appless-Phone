export type UiAgentLabTheme = 'warm' | 'cool';

export interface UiAgentLabThemePayload {
  theme: UiAgentLabTheme;
  generation: number;
}

function scriptString(value: string): string {
  let encoded = '"';
  for (let index = 0; index < value.length; index++) {
    encoded += '\\u' + value.charCodeAt(index).toString(16).padStart(4, '0');
  }
  return encoded + '"';
}

export function uiAgentLabThemeForToggle(enabled: boolean): UiAgentLabTheme {
  return enabled ? 'cool' : 'warm';
}

export function uiAgentLabThemeScript(theme: UiAgentLabTheme, generation: number): string {
  const payload: UiAgentLabThemePayload = {
    theme,
    generation
  };
  return 'window.__applyUiAgentLabTheme(JSON.parse(' +
    scriptString(JSON.stringify(payload)) + '));';
}
