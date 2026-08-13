import { UiCanonicalNode, UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiDataModelSnapshot, UiDataModelStore, UiDataModelValue } from './UiDataModelStore';
import { UiLayoutStore } from './UiLayoutStore';
import { UiRuntimeOverlaySnapshot, UiRuntimeOverlayStore, UiRuntimePhase } from './UiRuntimeOverlayStore';
import { UiUserOverlaySnapshot, UiUserOverlayStore } from './UiUserOverlayStore';
import {
  UiDataMutationPayload,
  UiMutation,
  UiRuntimeMutationPayload,
  UiUserMutationPayload
} from '../ir/UiMutationTypes';
import { UiRevisionGate, UiRevisionGateSnapshot } from './UiRevisionGate';
import { initialUiRevision, UiRevisionGateResult } from '../ir/UiRevisionTypes';

export interface UiSurfaceSnapshot {
  layout: UiCanonicalSurface | null;
  data: UiDataModelSnapshot | null;
  runtime: UiRuntimeOverlaySnapshot | null;
  user: UiUserOverlaySnapshot | null;
  revisionGate: UiRevisionGateSnapshot | null;
}

export class UiSurfaceController {
  readonly layoutStore: UiLayoutStore;
  readonly dataModelStore: UiDataModelStore;
  readonly runtimeOverlayStore: UiRuntimeOverlayStore;
  readonly userOverlayStore: UiUserOverlayStore;
  readonly revisionGate: UiRevisionGate;

  constructor(
    layoutStore: UiLayoutStore = new UiLayoutStore(),
    dataModelStore: UiDataModelStore = new UiDataModelStore(),
    runtimeOverlayStore: UiRuntimeOverlayStore = new UiRuntimeOverlayStore(),
    userOverlayStore: UiUserOverlayStore = new UiUserOverlayStore(),
    revisionGate: UiRevisionGate = new UiRevisionGate()
  ) {
    this.layoutStore = layoutStore;
    this.dataModelStore = dataModelStore;
    this.runtimeOverlayStore = runtimeOverlayStore;
    this.userOverlayStore = userOverlayStore;
    this.revisionGate = revisionGate;
  }

  commitLayout(surface: UiCanonicalSurface): void {
    this.layoutStore.set(surface);
    this.revisionGate.syncDomain(
      surface.surfaceId,
      surface.runId,
      surface.epoch,
      'layout',
      surface.revision.layout
    );
    this.runtimeOverlayStore.ensure(surface.surfaceId);
    this.userOverlayStore.ensure(surface.surfaceId);
    this.userOverlayStore.retainOrphans(
      surface.surfaceId,
      surface.nodes.map((node: UiCanonicalNode): string => node.nodeKey),
      surface.revision.user
    );
  }

  setDataModel(
    surfaceId: string,
    root: Object,
    revision: number,
    viewModelType: string = '',
    schemaVersion: number = 0,
    provenance: Object | null = null
  ): void {
    this.dataModelStore.setRoot(surfaceId, root, revision, viewModelType, schemaVersion, provenance);
  }

  setDataPath(surfaceId: string, path: string, value: UiDataModelValue, revision: number): boolean {
    return this.dataModelStore.setPath(surfaceId, path, value, revision);
  }

  setRuntimePhase(
    surfaceId: string,
    nodeKey: string,
    phase: UiRuntimePhase,
    revision: number,
    error: string = ''
  ): void {
    this.runtimeOverlayStore.setPhase(surfaceId, nodeKey, phase, revision, error);
  }

  setRuntimeProvenance(surfaceId: string, nodeKey: string, source: string, revision: number): void {
    this.runtimeOverlayStore.setProvenance(surfaceId, nodeKey, source, revision);
  }

  applyMutation(mutation: UiMutation): UiRevisionGateResult {
    if (mutation.kind === 'layout') {
      return {
        accepted: false,
        reason: 'INVALID_MUTATION',
        revision: this.revisionGate.current(mutation.meta.surfaceId) ?? initialUiRevision(mutation.meta.epoch)
      };
    }
    if (mutation.kind === 'data') {
      const payload = mutation.payload as UiDataMutationPayload;
      if (payload.path.length === 0 || !this.dataModelStore.canSetPath(
        mutation.meta.surfaceId,
        payload.path,
        payload.value
      )) {
        return {
          accepted: false,
          reason: 'INVALID_MUTATION',
          revision: this.revisionGate.current(mutation.meta.surfaceId) ?? initialUiRevision(mutation.meta.epoch)
        };
      }
    }
    const gateResult = this.revisionGate.evaluate(mutation.meta, mutation.kind);
    if (!gateResult.accepted) return gateResult;
    if (mutation.kind === 'data') {
      const payload = mutation.payload as UiDataMutationPayload;
      this.setDataPath(mutation.meta.surfaceId, payload.path, payload.value, mutation.meta.nextRevision.data);
    } else if (mutation.kind === 'runtime') {
      const payload = mutation.payload as UiRuntimeMutationPayload;
      this.setRuntimePhase(
        mutation.meta.surfaceId,
        payload.nodeKey,
        payload.phase,
        mutation.meta.nextRevision.runtime,
        payload.error === undefined ? '' : payload.error
      );
    } else if (mutation.kind === 'user') {
      this.applyUserMutation(
        mutation.meta.surfaceId,
        mutation.payload as UiUserMutationPayload,
        mutation.meta.nextRevision.user
      );
    }
    return gateResult;
  }

  applyUserMutation(surfaceId: string, mutation: UiUserMutationPayload, revision: number): void {
    if (mutation.operation === 'pin') {
      this.userOverlayStore.setPinned(surfaceId, mutation.nodeKey, true, revision);
    } else if (mutation.operation === 'unpin') {
      this.userOverlayStore.setPinned(surfaceId, mutation.nodeKey, false, revision);
    } else if (mutation.operation === 'hide') {
      this.userOverlayStore.setHidden(surfaceId, mutation.nodeKey, true, revision);
    } else if (mutation.operation === 'show') {
      this.userOverlayStore.setHidden(surfaceId, mutation.nodeKey, false, revision);
    } else if (mutation.operation === 'move') {
      this.userOverlayStore.move(surfaceId, mutation.nodeKey, mutation.afterNodeKey, revision);
    }
  }

  snapshot(surfaceId: string): UiSurfaceSnapshot {
    return {
      layout: this.layoutStore.get(surfaceId),
      data: this.dataModelStore.get(surfaceId),
      runtime: this.runtimeOverlayStore.get(surfaceId),
      user: this.userOverlayStore.get(surfaceId),
      revisionGate: this.revisionGate.snapshot(surfaceId)
    };
  }

  exportSnapshot(surfaceId: string): UiSurfaceSnapshot | null {
    const snapshot = this.snapshot(surfaceId);
    if (snapshot.layout === null && snapshot.data === null && snapshot.runtime === null &&
      snapshot.user === null && snapshot.revisionGate === null) return null;
    return snapshot;
  }

  exportSnapshotJson(surfaceId: string): string {
    const snapshot = this.exportSnapshot(surfaceId);
    return snapshot === null ? '' : JSON.stringify(snapshot);
  }

  restoreSnapshot(snapshot: UiSurfaceSnapshot): boolean {
    try {
      if (snapshot.layout !== null) this.commitLayout(snapshot.layout);
      if (snapshot.data !== null && !this.dataModelStore.restore(snapshot.data)) return false;
      if (snapshot.runtime !== null && !this.runtimeOverlayStore.restore(snapshot.runtime)) return false;
      if (snapshot.user !== null && !this.userOverlayStore.restore(snapshot.user)) return false;
      if (snapshot.revisionGate !== null && !this.revisionGate.restore(snapshot.revisionGate)) return false;
      return true;
    } catch (_error) {
      return false;
    }
  }

  restoreSnapshotJson(snapshotJson: string): boolean {
    if (snapshotJson.length === 0) return false;
    try {
      return this.restoreSnapshot(JSON.parse(snapshotJson) as UiSurfaceSnapshot);
    } catch (_error) {
      return false;
    }
  }

  removeSurface(surfaceId: string): void {
    this.layoutStore.remove(surfaceId);
    this.dataModelStore.remove(surfaceId);
    this.runtimeOverlayStore.remove(surfaceId);
    this.userOverlayStore.remove(surfaceId);
    this.revisionGate.remove(surfaceId);
  }
}
