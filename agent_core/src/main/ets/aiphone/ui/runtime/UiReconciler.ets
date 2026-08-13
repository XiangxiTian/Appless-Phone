import {
  canonicalNodeIndex,
  UiCanonicalNode,
  UiCanonicalSurface
} from '../ir/UiCanonicalTypes';

export interface UiReconcileResult {
  surface: UiCanonicalSurface;
  confirmedNodeKeys: string[];
  replacedNodeKeys: string[];
  insertedNodeKeys: string[];
  removedNodeKeys: string[];
}

function cloneSurface(surface: UiCanonicalSurface): UiCanonicalSurface {
  return JSON.parse(JSON.stringify(surface)) as UiCanonicalSurface;
}

function nodeFingerprint(node: UiCanonicalNode): string {
  return JSON.stringify({
    nodeKey: node.nodeKey,
    component: node.component,
    catalogRef: node.catalogRef,
    props: node.props,
    bindings: node.bindings,
    actionRefs: node.actionRefs,
    children: node.children
  });
}

/**
 * Compares speculative and authoritative canonical surfaces by stable nodeKey.
 * The authoritative surface becomes the next layout; overlays are reconciled
 * by SurfaceController separately and therefore never get folded into this diff.
 */
export class UiReconciler {
  reconcile(speculative: UiCanonicalSurface, authoritative: UiCanonicalSurface): UiReconcileResult {
    if (speculative.surfaceId !== authoritative.surfaceId) {
      throw new Error('RECONCILE_SURFACE_MISMATCH');
    }
    const speculativeNodes = canonicalNodeIndex(speculative);
    const authoritativeNodes = canonicalNodeIndex(authoritative);
    const confirmedNodeKeys: string[] = [];
    const replacedNodeKeys: string[] = [];
    const insertedNodeKeys: string[] = [];
    const removedNodeKeys: string[] = [];

    authoritative.nodes.forEach((node: UiCanonicalNode): void => {
      const previous = speculativeNodes.get(node.nodeKey);
      if (previous === undefined) {
        insertedNodeKeys.push(node.nodeKey);
      } else if (nodeFingerprint(previous) === nodeFingerprint(node)) {
        confirmedNodeKeys.push(node.nodeKey);
      } else {
        replacedNodeKeys.push(node.nodeKey);
      }
    });
    speculative.nodes.forEach((node: UiCanonicalNode): void => {
      if (!authoritativeNodes.has(node.nodeKey)) removedNodeKeys.push(node.nodeKey);
    });

    return {
      surface: cloneSurface(authoritative),
      confirmedNodeKeys,
      replacedNodeKeys,
      insertedNodeKeys,
      removedNodeKeys
    };
  }
}
