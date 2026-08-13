import { initialUiRevision, UiRevisionVector } from '../ir/UiRevisionTypes';
import { UiCanonicalNode, UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiBindingSet } from '../ir/UiBindingTypes';
import { UiCatalogRegistry } from '../catalog/UiCatalogRegistry';
import { UiCompileContext, UiComponentCandidate, UiModelCandidate } from './UiModelOutputAdapter';

function revisionFor(epoch: number): UiRevisionVector {
  const revision = initialUiRevision(epoch);
  revision.layout = 1;
  return revision;
}

function cloneBindings(value: Object): Object {
  return JSON.parse(JSON.stringify(value)) as Object;
}

export class UiCanonicalizer {
  canonicalize(candidate: UiModelCandidate, context: UiCompileContext): UiCanonicalSurface {
    const nodes: UiCanonicalNode[] = candidate.components.map((component: UiComponentCandidate): UiCanonicalNode => {
      const item = context.catalogRegistry.resolve(component.component);
      if (item === null) throw new Error('UNKNOWN_COMPONENT:' + component.component);
      return {
        nodeKey: component.id,
        component: component.component,
        catalogRef: { name: item.name, version: item.version, layer: item.layer },
        props: JSON.parse(JSON.stringify(component.props)) as Object,
        bindings: cloneBindings(component.bindings) as UiBindingSet,
        actionRefs: component.actionRefs.slice(),
        children: component.children.slice()
      };
    });
    const catalog = context.catalogRegistry.snapshot(context.catalogGroups);
    return {
      schemaVersion: 1,
      surfaceId: candidate.surfaceId,
      runId: context.runId,
      epoch: context.epoch,
      rootNodeKey: candidate.rootId,
      title: candidate.title,
      intent: candidate.intent,
      catalogVersion: catalog.version,
      nodes,
      revision: revisionFor(context.epoch)
    };
  }
}
