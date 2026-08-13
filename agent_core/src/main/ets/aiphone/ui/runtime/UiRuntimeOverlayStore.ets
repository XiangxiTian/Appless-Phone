export type UiRuntimePhase = 'predicted' | 'confirmed' | 'hydrated' | 'error';

export interface UiRuntimeOverlaySnapshot {
  surfaceId: string;
  revision: number;
  nodePhases: Record<string, UiRuntimePhase>;
  nodeErrors: Record<string, string>;
  provenance: Record<string, string>;
}

function cloneRecord<T>(value: Record<string, T>): Record<string, T> {
  const result: Record<string, T> = {};
  Object.keys(value).forEach((key: string): void => {
    result[key] = value[key];
  });
  return result;
}

function emptyOverlay(surfaceId: string): UiRuntimeOverlaySnapshot {
  return {
    surfaceId,
    revision: 0,
    nodePhases: {},
    nodeErrors: {},
    provenance: {}
  };
}

/** Ephemeral render state; it must never enter canonical layout fingerprints. */
export class UiRuntimeOverlayStore {
  private readonly overlays: Map<string, UiRuntimeOverlaySnapshot> = new Map<string, UiRuntimeOverlaySnapshot>();

  ensure(surfaceId: string): UiRuntimeOverlaySnapshot {
    const current = this.overlays.get(surfaceId);
    if (current !== undefined) return this.snapshotValue(current);
    const created = emptyOverlay(surfaceId);
    this.overlays.set(surfaceId, created);
    return this.snapshotValue(created);
  }

  setPhase(surfaceId: string, nodeKey: string, phase: UiRuntimePhase, revision: number, error: string = ''): void {
    const current = this.ensure(surfaceId);
    current.nodePhases[nodeKey] = phase;
    current.revision = revision;
    if (phase === 'error' && error.length > 0) {
      current.nodeErrors[nodeKey] = error;
    } else {
      delete current.nodeErrors[nodeKey];
    }
    this.overlays.set(surfaceId, current);
  }

  setProvenance(surfaceId: string, nodeKey: string, source: string, revision: number): void {
    const current = this.ensure(surfaceId);
    current.provenance[nodeKey] = source;
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  get(surfaceId: string): UiRuntimeOverlaySnapshot | null {
    const current = this.overlays.get(surfaceId);
    return current === undefined ? null : this.snapshotValue(current);
  }

  clearNode(surfaceId: string, nodeKey: string, revision: number): void {
    const current = this.ensure(surfaceId);
    delete current.nodePhases[nodeKey];
    delete current.nodeErrors[nodeKey];
    delete current.provenance[nodeKey];
    current.revision = revision;
    this.overlays.set(surfaceId, current);
  }

  remove(surfaceId: string): boolean {
    return this.overlays.delete(surfaceId);
  }

  private snapshotValue(value: UiRuntimeOverlaySnapshot): UiRuntimeOverlaySnapshot {
    return {
      surfaceId: value.surfaceId,
      revision: value.revision,
      nodePhases: cloneRecord(value.nodePhases),
      nodeErrors: cloneRecord(value.nodeErrors),
      provenance: cloneRecord(value.provenance)
    };
  }
}
