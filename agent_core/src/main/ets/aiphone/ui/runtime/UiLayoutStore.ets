import { canonicalSurfaceFingerprint, UiCanonicalNode, UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiBindingSet } from '../ir/UiBindingTypes';

function cloneSurface(surface: UiCanonicalSurface): UiCanonicalSurface {
  return {
    schemaVersion: surface.schemaVersion,
    surfaceId: surface.surfaceId,
    runId: surface.runId,
    epoch: surface.epoch,
    rootNodeKey: surface.rootNodeKey,
    title: surface.title,
    intent: surface.intent,
    catalogVersion: surface.catalogVersion,
    nodes: surface.nodes.map((node: UiCanonicalNode): UiCanonicalNode => ({
      nodeKey: node.nodeKey,
      component: node.component,
      catalogRef: {
        name: node.catalogRef.name,
        version: node.catalogRef.version,
        layer: node.catalogRef.layer
      },
      props: JSON.parse(JSON.stringify(node.props)) as Object,
      bindings: JSON.parse(JSON.stringify(node.bindings)) as UiBindingSet,
      actionRefs: node.actionRefs.slice(),
      children: node.children.slice()
    })),
    revision: {
      epoch: surface.revision.epoch,
      layout: surface.revision.layout,
      data: surface.revision.data,
      runtime: surface.revision.runtime,
      user: surface.revision.user
    }
  };
}

/**
 * Stores only canonical layout. Runtime phases, data and user edits are kept
 * in their dedicated stores so layout fingerprints remain stable.
 */
export class UiLayoutStore {
  private readonly surfaces: Map<string, UiCanonicalSurface> = new Map<string, UiCanonicalSurface>();

  set(surface: UiCanonicalSurface): void {
    if (surface.surfaceId.length === 0) throw new Error('INVALID_SURFACE_ID');
    this.surfaces.set(surface.surfaceId, cloneSurface(surface));
  }

  get(surfaceId: string): UiCanonicalSurface | null {
    const surface = this.surfaces.get(surfaceId);
    return surface === undefined ? null : cloneSurface(surface);
  }

  remove(surfaceId: string): boolean {
    return this.surfaces.delete(surfaceId);
  }

  has(surfaceId: string): boolean {
    return this.surfaces.has(surfaceId);
  }

  fingerprint(surfaceId: string): string | null {
    const surface = this.surfaces.get(surfaceId);
    return surface === undefined ? null : canonicalSurfaceFingerprint(surface);
  }

  surfaceIds(): string[] {
    return Array.from(this.surfaces.keys());
  }
}
