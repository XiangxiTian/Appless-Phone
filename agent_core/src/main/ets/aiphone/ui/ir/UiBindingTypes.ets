export type UiBindingStore = 'business' | 'local' | 'agent';

export interface UiBinding {
  store: UiBindingStore;
  path: string;
  expectedType: string;
}

export type UiBindingSet = Record<string, UiBinding>;

export function isValidUiBindingPath(path: string): boolean {
  return path.length > 0 && path.charAt(0) === '/' && path.indexOf('#') < 0;
}
