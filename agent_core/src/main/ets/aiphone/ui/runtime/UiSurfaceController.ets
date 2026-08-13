import { UiCanonicalNode, UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiDataModelSnapshot, UiDataModelStore, UiDataModelValue } from './UiDataModelStore';
import { UiLayoutStore } from './UiLayoutStore';
import { UiRuntimeOverlaySnapshot, UiRuntimeOverlayStore, UiRuntimePhase } from './UiRuntimeOverlayStore';
import { UiUserOverlaySnapshot, UiUserOverlayStore } from './UiUserOverlayStore';
import { UiUserMutationPayload } from '../ir/UiMutationTypes';

export interface UiSurfaceSnapshot {
  layout: UiCanonicalSurface | null;
  data: UiDataModelSnapshot | null;
  runtime: UiRuntimeOverlaySnapshot | null;
  user: UiUserOverlaySnapshot | null;
}

export class UiSurfaceController {
  readonly layoutStore: UiLayoutStore;
  readonly dataModelStore: UiDataModelStore;
  readonly runtimeOverlayStore: UiRuntimeOverlayStore;
  readonly userOverlayStore: UiUserOverlayStore;

  constructor(
    layoutStore: UiLayoutStore = new UiLayoutStore(),
    dataModelStore: UiDataModelStore = new UiDataModelStore(),
    runtimeOverlayStore: UiRuntimeOverlayStore = new UiRuntimeOverlayStore(),
    userOverlayStore: UiUserOverlayStore = new UiUserOverlayStore()
  ) {
    this.layoutStore = layoutStore;
    this.dataModelStore = dataModelStore;
    this.runtimeOverlayStore = runtimeOverlayStore;
    this.userOverlayStore = userOverlayStore;
  }

  commitLayout(surface: UiCanonicalSurface): void {
    this.layoutStore.set(surface);
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
      user: this.userOverlayStore.get(surfaceId)
    };
  }

  removeSurface(surfaceId: string): void {
    this.layoutStore.remove(surfaceId);
    this.dataModelStore.remove(surfaceId);
    this.runtimeOverlayStore.remove(surfaceId);
    this.userOverlayStore.remove(surfaceId);
  }
}
