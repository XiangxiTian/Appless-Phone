import { UiBindingSet } from './UiBindingTypes';
import { UiRevisionVector } from './UiRevisionTypes';

export type UiCatalogLayer = 'foundation' | 'semantic' | 'extension';

export interface UiCatalogRef {
  name: string;
  version: number;
  layer: UiCatalogLayer;
}

export interface UiCanonicalNode {
  nodeKey: string;
  component: string;
  catalogRef: UiCatalogRef;
  props: Object;
  bindings: UiBindingSet;
  actionRefs: string[];
  children: string[];
}

export interface UiCanonicalSurface {
  schemaVersion: number;
  surfaceId: string;
  runId: string;
  epoch: number;
  rootNodeKey: string;
  title: string;
  intent: string;
  catalogVersion: string;
  nodes: UiCanonicalNode[];
  revision: UiRevisionVector;
}

interface UiCanonicalNodeFingerprint {
  nodeKey: string;
  component: string;
  catalogRef: UiCatalogRef;
  props: Object;
  bindings: UiBindingSet;
  actionRefs: string[];
  children: string[];
}

interface UiCanonicalSurfaceFingerprint {
  schemaVersion: number;
  rootNodeKey: string;
  title: string;
  intent: string;
  catalogVersion: string;
  nodes: UiCanonicalNodeFingerprint[];
}

export function canonicalNodeIndex(surface: UiCanonicalSurface): Map<string, UiCanonicalNode> {
  const result: Map<string, UiCanonicalNode> = new Map<string, UiCanonicalNode>();
  surface.nodes.forEach((node: UiCanonicalNode): void => {
    result.set(node.nodeKey, node);
  });
  return result;
}

export function canonicalSurfaceFingerprint(surface: UiCanonicalSurface): string {
  const nodes = surface.nodes.slice().sort((left: UiCanonicalNode, right: UiCanonicalNode): number => {
    return left.nodeKey < right.nodeKey ? -1 : (left.nodeKey > right.nodeKey ? 1 : 0);
  }).map((node: UiCanonicalNode): UiCanonicalNodeFingerprint => ({
    nodeKey: node.nodeKey,
    component: node.component,
    catalogRef: node.catalogRef,
    props: node.props,
    bindings: node.bindings,
    actionRefs: node.actionRefs,
    children: node.children
  }));
  const fingerprint: UiCanonicalSurfaceFingerprint = {
    schemaVersion: surface.schemaVersion,
    rootNodeKey: surface.rootNodeKey,
    title: surface.title,
    intent: surface.intent,
    catalogVersion: surface.catalogVersion,
    nodes
  };
  return JSON.stringify(fingerprint);
}
