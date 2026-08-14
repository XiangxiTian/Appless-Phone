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

interface UiLabV4LegacyProvenance {
  source: string;
}

function jsonEqual(left: Object, right: Object): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function legacyPhaseFor(value: 'predicted' | 'confirmed' | 'hydrated' | 'error'): 'shimmer' | 'ready' | 'data' {
  if (value === 'predicted') return 'shimmer';
  if (value === 'hydrated') return 'data';
  return 'ready';
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
    this.controller.dataModelStore.remove(canonical.surfaceId);
    this.controller.runtimeOverlayStore.remove(canonical.surfaceId);
    this.controller.userOverlayStore.remove(canonical.surfaceId);
    this.controller.commitLayout(canonical);
    this.migrateData(legacy, canonical);
    this.migrateOverlays(legacy, canonical);
    const projected = this.adapter.toLegacy(canonical, legacy);
    this.materializeOverlays(projected);
    const categories: UiLabV4ShadowMismatchCategory[] = [];
    if (canonicalSurfaceFingerprint(canonical) !==
      canonicalSurfaceFingerprint(this.adapter.toCanonical(projected, runId, epoch))) {
      categories.push('canonical');
    }
    if (!this.dataMatches(legacy)) categories.push('data');
    if (!this.phaseMatches(legacy, projected)) categories.push('phase');
    if (!this.userOverlayMatches(legacy, projected)) categories.push('user-overlay');
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
    try {
      const data = JSON.parse(legacy.dataModelJson.length === 0 ? '{}' : legacy.dataModelJson) as Object;
      const provenance: UiLabV4LegacyProvenance = { source: 'legacy-a2ui-shadow' };
      this.controller.setDataModel(canonical.surfaceId, data, 1, 'legacy-a2ui-data', 1, provenance);
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

  private materializeOverlays(projected: A2uiSurfaceState): void {
    const runtime = this.controller.snapshot(projected.surfaceId).runtime;
    const user = this.controller.snapshot(projected.surfaceId).user;
    const order: Map<string, number> = new Map<string, number>();
    if (user !== null) {
      user.orderedNodeKeys.forEach((nodeKey: string, index: number): void => {
        order.set(nodeKey, index);
      });
    }
    projected.components.forEach((component: A2uiComponent): void => {
      const phase = runtime === null ? undefined : runtime.nodePhases[component.id];
      if (phase !== undefined) component.renderState = legacyPhaseFor(phase);
      if (user !== null) {
        if (user.pinnedNodeKeys.indexOf(component.id) >= 0) component.pinned = true;
        else component.pinned = undefined;
        if (user.hiddenNodeKeys.indexOf(component.id) >= 0) component.hidden = true;
        else component.hidden = undefined;
        const orderHint = order.get(component.id);
        if (orderHint === undefined) component.orderHint = undefined;
        else component.orderHint = orderHint;
      }
    });
  }

  private dataMatches(legacy: A2uiSurfaceState): boolean {
    try {
      const expected = JSON.parse(legacy.dataModelJson.length === 0 ? '{}' : legacy.dataModelJson) as Object;
      const actual = this.controller.snapshot(legacy.surfaceId).data;
      return actual !== null && jsonEqual(expected, actual.root);
    } catch (_error) {
      return false;
    }
  }

  private phaseMatches(legacy: A2uiSurfaceState, projected: A2uiSurfaceState): boolean {
    const projectedById: Map<string, A2uiComponent> = new Map<string, A2uiComponent>();
    projected.components.forEach((component: A2uiComponent): void => {
      projectedById.set(component.id, component);
    });
    return legacy.components.every((component: A2uiComponent): boolean => {
      const next = projectedById.get(component.id);
      return next !== undefined && next.renderState === component.renderState;
    });
  }

  private userOverlayMatches(legacy: A2uiSurfaceState, projected: A2uiSurfaceState): boolean {
    const projectedById: Map<string, A2uiComponent> = new Map<string, A2uiComponent>();
    projected.components.forEach((component: A2uiComponent): void => {
      projectedById.set(component.id, component);
    });
    return legacy.components.every((component: A2uiComponent): boolean => {
      const next = projectedById.get(component.id);
      return next !== undefined && next.pinned === component.pinned && next.hidden === component.hidden &&
        next.orderHint === component.orderHint;
    });
  }
}
