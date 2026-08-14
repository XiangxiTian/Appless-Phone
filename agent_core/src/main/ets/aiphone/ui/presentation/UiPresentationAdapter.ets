import {
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource
} from './UiPresentationTypes';

export interface UiPresentationAdapter {
  id(): string;
  version(): number;
  supports(source: UiPresentationSource): boolean;
  adapt(source: UiPresentationSource, context: UiPresentationContext): UiPresentationEnvelope;
}

export function envelopeFor(
  adapter: UiPresentationAdapter,
  source: UiPresentationSource,
  viewModelType: string,
  viewModelVersion: number,
  data: Object
): UiPresentationEnvelope {
  return {
    viewModelType,
    viewModelVersion,
    data,
    provenance: {
      toolId: source.toolId,
      outputSchemaRef: source.outputSchemaRef,
      provider: source.provider,
      adapterId: adapter.id(),
      adapterVersion: adapter.version()
    }
  };
}

export function stringAt(value: Object, path: string): string | null {
  const found = valueAt(value, path);
  return typeof found === 'string' ? found : null;
}

export function numberAt(value: Object, path: string): number | null {
  const found = valueAt(value, path);
  return typeof found === 'number' && Number.isFinite(found) ? found : null;
}

export function objectArrayAt(value: Object, path: string): Object[] {
  const found = valueAt(value, path);
  return Array.isArray(found) ? found as Object[] : [];
}

function valueAt(root: Object, path: string): Object | string | number | boolean | null | undefined {
  if (path.length === 0 || path.charAt(0) !== '/') return undefined;
  if (path === '/') return root;
  const segments = path.substring(1).split('/');
  let current: Object | string | number | boolean | null | undefined = root;
  for (let index = 0; index < segments.length; index++) {
    if (current === null || current === undefined || typeof current !== 'object') return undefined;
    const key = segments[index].replace(/~1/g, '/').replace(/~0/g, '~');
    if (Array.isArray(current)) {
      const array = current as (Object | string | number | boolean | null | undefined)[];
      const arrayIndex = Number(key);
      if (!Number.isInteger(arrayIndex) || arrayIndex < 0 || arrayIndex >= array.length) return undefined;
      current = array[arrayIndex];
    } else {
      const record = current as Record<string, Object | string | number | boolean | null | undefined>;
      if (Object.keys(record).indexOf(key) < 0) return undefined;
      current = record[key];
    }
  }
  return current;
}
