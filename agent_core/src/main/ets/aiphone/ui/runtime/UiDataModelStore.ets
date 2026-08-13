import {
  cloneJsonValue,
  resolveJsonPointer,
  setJsonPointer
} from '../../../agent/action/JsonPointer';
import { JsonValue } from '../../../agent/action/ActionPlanTypes';

export type UiDataModelValue = Object | string | number | boolean | null;

export interface UiDataModelSnapshot {
  surfaceId: string;
  revision: number;
  root: Object;
  viewModelType: string;
  schemaVersion: number;
  provenance: Object | null;
}

function cloneValue(value: UiDataModelValue): UiDataModelValue {
  const result = cloneJsonValue(value as JsonValue);
  if (!result.ok || result.value === undefined) {
    throw new Error('INVALID_DATA_MODEL_VALUE');
  }
  return result.value as UiDataModelValue;
}

function cloneSnapshot(snapshot: UiDataModelSnapshot): UiDataModelSnapshot {
  return {
    surfaceId: snapshot.surfaceId,
    revision: snapshot.revision,
    root: cloneValue(snapshot.root) as Object,
    viewModelType: snapshot.viewModelType,
    schemaVersion: snapshot.schemaVersion,
    provenance: snapshot.provenance === null ? null : cloneValue(snapshot.provenance) as Object
  };
}

/** Stores business/view-model data independently from canonical layout. */
export class UiDataModelStore {
  private readonly models: Map<string, UiDataModelSnapshot> = new Map<string, UiDataModelSnapshot>();

  setRoot(
    surfaceId: string,
    root: Object,
    revision: number,
    viewModelType: string = '',
    schemaVersion: number = 0,
    provenance: Object | null = null
  ): void {
    if (surfaceId.length === 0 || revision < 0) throw new Error('INVALID_DATA_MODEL_META');
    this.models.set(surfaceId, {
      surfaceId,
      revision,
      root: cloneValue(root) as Object,
      viewModelType,
      schemaVersion,
      provenance: provenance === null ? null : cloneValue(provenance) as Object
    });
  }

  setPath(
    surfaceId: string,
    path: string,
    value: UiDataModelValue,
    revision: number
  ): boolean {
    const current = this.models.get(surfaceId);
    if (current === undefined || revision < 0) return false;
    const result = setJsonPointer(current.root as JsonValue, path, value as JsonValue);
    if (!result.ok || result.value === undefined || result.value === null ||
      typeof result.value !== 'object' || Array.isArray(result.value)) {
      return false;
    }
    current.root = cloneValue(result.value as Object) as Object;
    current.revision = revision;
    return true;
  }

  canSetPath(surfaceId: string, path: string, value: UiDataModelValue): boolean {
    const current = this.models.get(surfaceId);
    if (current === undefined) return false;
    const result = setJsonPointer(current.root as JsonValue, path, value as JsonValue);
    return result.ok;
  }

  resolve(surfaceId: string, path: string): UiDataModelValue | undefined {
    const current = this.models.get(surfaceId);
    if (current === undefined) return undefined;
    const result = resolveJsonPointer(current.root as JsonValue, path);
    return result.ok && result.value !== undefined
      ? cloneValue(result.value as UiDataModelValue)
      : undefined;
  }

  get(surfaceId: string): UiDataModelSnapshot | null {
    const current = this.models.get(surfaceId);
    return current === undefined ? null : cloneSnapshot(current);
  }

  restore(snapshot: UiDataModelSnapshot): boolean {
    if (snapshot.surfaceId.length === 0 || snapshot.revision < 0 || snapshot.schemaVersion < 0) return false;
    try {
      this.models.set(snapshot.surfaceId, cloneSnapshot(snapshot));
      return true;
    } catch (_error) {
      return false;
    }
  }

  remove(surfaceId: string): boolean {
    return this.models.delete(surfaceId);
  }
}
