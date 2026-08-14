import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  emptyA2uiSurface
} from '../../runtime/A2uiTypes';
import { isValidUiBindingPath, UiBindingSet } from '../ir/UiBindingTypes';
import { UiCanonicalNode, UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { initialUiRevision } from '../ir/UiRevisionTypes';

function legacyComponentName(component: string): string {
  if (component === 'SurfaceRoot') return 'Surface';
  if (component === 'Column') return 'Stack';
  if (component === 'Row') return 'Row';
  if (component === 'Text') return 'Text';
  if (component === 'ActionBar') return 'ActionBar';
  if (component === 'MetricGrid') return 'MetricGrid';
  return component;
}

function propsFor(component: A2uiComponent): Object {
  const props: Record<string, Object | string | number | boolean | null> = {};
  if (component.title !== undefined) props['title'] = component.title;
  if (component.text !== undefined) props['text'] = component.text;
  if (component.body !== undefined) props['body'] = component.body;
  if (component.status !== undefined) props['status'] = component.status;
  if (component.tone !== undefined) props['tone'] = component.tone;
  if (component.variant !== undefined) props['variant'] = component.variant;
  if (component.path !== undefined) props['path'] = component.path;
  if (component.catalogFieldsJson !== undefined) props['catalogFieldsJson'] = component.catalogFieldsJson;
  return props as Object;
}

function childrenFor(component: A2uiComponent): string[] {
  const children = component.children === undefined ? [] : component.children.slice();
  if (component.child !== undefined && children.indexOf(component.child) < 0) children.push(component.child);
  return children;
}

function bindingsFor(component: A2uiComponent): UiBindingSet {
  const bindings: UiBindingSet = {};
  if (component.dataPath !== undefined && isValidUiBindingPath(component.dataPath)) {
    bindings['data'] = { store: 'business', path: component.dataPath, expectedType: 'unknown' };
  }
  return bindings;
}

function actionRefsFor(component: A2uiComponent): string[] {
  return component.actions === undefined
    ? []
    : component.actions.map((action: A2uiAction): string => action.id);
}

function revisionFor(surface: A2uiSurfaceState, epoch: number) {
  const revision = initialUiRevision(epoch);
  revision.layout = Math.max(1, surface.sequence);
  return revision;
}

function canonicalNode(component: A2uiComponent): UiCanonicalNode {
  return {
    nodeKey: component.id,
    component: legacyComponentName(component.component),
    catalogRef: {
      name: component.component,
      version: 1,
      layer: 'extension'
    },
    props: propsFor(component),
    bindings: bindingsFor(component),
    actionRefs: actionRefsFor(component),
    children: childrenFor(component)
  };
}

function cloneLegacyComponent(component: A2uiComponent): A2uiComponent {
  return JSON.parse(JSON.stringify(component)) as A2uiComponent;
}

function legacyComponent(node: UiCanonicalNode, base?: A2uiComponent): A2uiComponent {
  const props = node.props as Record<string, Object | string | number | boolean | null | undefined>;
  const legacyNames: string[] = ['SurfaceRoot', 'Column', 'Row', 'Text', 'ActionBar', 'MetricGrid'];
  const component: A2uiComponent = base === undefined ? {
    id: node.nodeKey,
    component: node.component
  } : cloneLegacyComponent(base);
  component.id = node.nodeKey;
  component.component = legacyNames.indexOf(node.catalogRef.name) >= 0 ? node.catalogRef.name : node.component;
  component.children = node.children.slice();
  component.child = undefined;
  const baseActions = base === undefined || base.actions === undefined ? [] : base.actions;
  component.actions = node.actionRefs.map((actionId: string): A2uiAction => {
    const preserved = baseActions.find((action: A2uiAction): boolean => action.id === actionId);
    return preserved === undefined ? {
      id: actionId,
      label: '',
      prompt: '',
      variant: '',
      kind: ''
    } : JSON.parse(JSON.stringify(preserved)) as A2uiAction;
  });
  if (typeof props['title'] === 'string') component.title = props['title'] as string;
  if (typeof props['text'] === 'string') component.text = props['text'] as string;
  if (typeof props['body'] === 'string') component.body = props['body'] as string;
  if (typeof props['status'] === 'string') component.status = props['status'] as string;
  if (typeof props['tone'] === 'string') component.tone = props['tone'] as string;
  if (typeof props['variant'] === 'string') component.variant = props['variant'] as string;
  if (typeof props['path'] === 'string') component.path = props['path'] as string;
  if (typeof props['catalogFieldsJson'] === 'string') component.catalogFieldsJson = props['catalogFieldsJson'] as string;
  const dataBinding = node.bindings['data'];
  if (dataBinding !== undefined) component.dataPath = dataBinding.path;
  return component;
}

export class LegacyA2uiSurfaceAdapter {
  toCanonical(surface: A2uiSurfaceState, runId: string = '', epoch: number = 0): UiCanonicalSurface {
    const rootId = surface.rootId.length > 0
      ? surface.rootId
      : (surface.components.length > 0 ? surface.components[0].id : 'root');
    return {
      schemaVersion: 1,
      surfaceId: surface.surfaceId,
      runId,
      epoch,
      rootNodeKey: rootId,
      title: surface.title,
      intent: surface.intent,
      catalogVersion: 'legacy-a2ui-v1',
      nodes: surface.components.map((component: A2uiComponent): UiCanonicalNode => canonicalNode(component)),
      revision: revisionFor(surface, epoch)
    };
  }

  toLegacy(surface: UiCanonicalSurface, base?: A2uiSurfaceState): A2uiSurfaceState {
    const result = base === undefined ? emptyA2uiSurface(surface.surfaceId) : JSON.parse(JSON.stringify(base)) as A2uiSurfaceState;
    const baseComponents: Map<string, A2uiComponent> = new Map<string, A2uiComponent>();
    result.components.forEach((component: A2uiComponent): void => {
      baseComponents.set(component.id, component);
    });
    result.surfaceId = surface.surfaceId;
    result.rootId = surface.rootNodeKey;
    result.title = surface.title;
    result.intent = surface.intent;
    result.components = surface.nodes.map((node: UiCanonicalNode): A2uiComponent =>
      legacyComponent(node, baseComponents.get(node.nodeKey)));
    result.sequence = surface.revision.layout;
    return result;
  }
}
