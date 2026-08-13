import {
  A2uiSurfaceState,
  A2uiComponent,
  LegacyA2uiSurfaceAdapter,
  UiCanonicalSurface,
  UiSurfaceController,
  canonicalSurfaceFingerprint
} from '@loop/agent-core';
import { UiLabV4ProjectionBridge } from './UiLabV4ProjectionBridge';

export type UiLabV4ShadowMismatchCategory = 'canonical' | 'data' | 'phase' | 'user-overlay' | 'revision';

export interface UiLabV4ShadowCompareResult {
  match: boolean;
  categories: UiLabV4ShadowMismatchCategory[];
  canonical: UiCanonicalSurface;
  projected: A2uiSurfaceState;
}

function phaseFor(value: 'shimmer' | 'ready' | 'data'): 'predicted' | 'confirmed' | 'hydrated' {
  if (value === 'shimmer') return 'predicted';
  if (value === 'data') return 'hydrated';
  return 'confirmed';
}

/**
 * UI Lab-only shadow bridge. It intentionally compares and projects without
 * calling the legacy surface store, so the visible legacy path remains the
 * owner until the feature flag is explicitly promoted.
 */
export class UiLabV4ShadowMirror {
  private readonly adapter: LegacyA2uiSurfaceAdapter = new LegacyA2uiSurfaceAdapter();
  private readonly controller: UiSurfaceController;
  private readonly bridge: UiLabV4ProjectionBridge | null;

  constructor(controller: UiSurfaceController = new UiSurfaceController(), bridge: UiLabV4ProjectionBridge | null = null) {
    this.controller = controller;
    this.bridge = bridge;
  }

  apply(legacy: A2uiSurfaceState, runId: string, epoch: number, visible: boolean = false): UiLabV4ShadowCompareResult {
    const canonical = this.adapter.toCanonical(legacy, runId, epoch);
    this.controller.commitLayout(canonical);
    this.migrateData(legacy, canonical);
    this.migrateOverlays(legacy, canonical);
    const projected = this.adapter.toLegacy(canonical, legacy);
    const categories: UiLabV4ShadowMismatchCategory[] = [];
    if (canonicalSurfaceFingerprint(canonical) !==
      canonicalSurfaceFingerprint(this.adapter.toCanonical(projected, runId, epoch))) {
      categories.push('canonical');
    }
    if (legacy.dataModelJson.length > 0 && legacy.dataModelJson !== '{}') {
      try {
        JSON.parse(legacy.dataModelJson);
      } catch (_error) {
        categories.push('data');
      }
    }
    if (legacy.components.some((component): boolean => component.renderState !== undefined)) categories.push('phase');
    if (legacy.components.some((component): boolean => component.pinned === true || component.hidden === true ||
      component.orderHint !== undefined)) categories.push('user-overlay');
    if (projected.sequence !== legacy.sequence) categories.push('revision');
    if (visible && this.bridge !== null) this.bridge.pushCanonicalSurface(canonical);
    return {
      match: categories.length === 0,
      categories,
      canonical,
      projected
    };
  }

  private migrateData(legacy: A2uiSurfaceState, canonical: UiCanonicalSurface): void {
    if (legacy.dataModelJson.length === 0) return;
    try {
      const data = JSON.parse(legacy.dataModelJson) as Object;
      this.controller.setDataModel(canonical.surfaceId, data, 1, 'legacy-a2ui-data', 1, {
        source: 'legacy-a2ui-shadow'
      });
    } catch (_error) {
      return;
    }
  }

  private migrateOverlays(legacy: A2uiSurfaceState, canonical: UiCanonicalSurface): void {
    let runtimeRevision = 0;
    let userRevision = 0;
    legacy.components.forEach((component): void => {
      if (component.renderState !== undefined) {
        this.controller.setRuntimePhase(canonical.surfaceId, component.id, phaseFor(component.renderState), ++runtimeRevision);
      }
      if (component.pinned === true) {
        this.controller.applyUserMutation(canonical.surfaceId, { nodeKey: component.id, operation: 'pin' }, ++userRevision);
      }
      if (component.hidden === true) {
        this.controller.applyUserMutation(canonical.surfaceId, { nodeKey: component.id, operation: 'hide' }, ++userRevision);
      }
    });
    const ordered = legacy.components.filter((component: A2uiComponent): boolean => component.orderHint !== undefined)
      .sort((left: A2uiComponent, right: A2uiComponent): number =>
        (left.orderHint as number) - (right.orderHint as number));
    let afterNodeKey: string | undefined = undefined;
    ordered.forEach((component): void => {
      this.controller.applyUserMutation(canonical.surfaceId, {
        nodeKey: component.id,
        operation: 'move',
        afterNodeKey
      }, ++userRevision);
      afterNodeKey = component.id;
    });
  }
}
