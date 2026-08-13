import { isValidUiBindingPath, UiBinding } from '../ir/UiBindingTypes';
import { UiCatalogItem } from '../catalog/UiCatalogItem';
import { UiCatalogRegistry } from '../catalog/UiCatalogRegistry';
import {
  createDefaultUiPresentationSchemaRegistry,
  UiPresentationSchemaRegistry
} from '../presentation/UiPresentationSchemaRegistry';
import {
  UiCompileContext,
  UiCompileError,
  UiComponentCandidate,
  UiModelCandidate
} from './UiModelOutputAdapter';

function error(code: string, message: string, source: string = ''): UiCompileError {
  const value: UiCompileError = { code, message };
  if (source.length > 0) value.source = source;
  return value;
}

function catalogItem(
  registry: UiCatalogRegistry,
  groups: string[],
  component: string
): UiCatalogItem | null {
  const items = registry.list(groups);
  for (let index = 0; index < items.length; index++) {
    if (items[index].name === component) return items[index];
  }
  return null;
}

function validateBindings(
  candidate: UiComponentCandidate,
  item: UiCatalogItem,
  schemas: UiPresentationSchemaRegistry,
  errors: UiCompileError[]
): void {
  Object.keys(candidate.bindings).forEach((property: string): void => {
    const binding: UiBinding = candidate.bindings[property];
    if (binding === undefined || (binding.store !== 'business' && binding.store !== 'local' && binding.store !== 'agent') ||
      !isValidUiBindingPath(binding.path) || binding.expectedType.length === 0) {
      errors.push(error('INVALID_BINDING', 'Invalid binding for ' + candidate.id + '.' + property, property));
      return;
    }
    if (binding.store === 'business' && (item.acceptedViewModels.length === 0 ||
      !item.acceptedViewModels.some((schemaId: string): boolean => schemas.allows(schemaId, binding.path)))) {
      errors.push(error('INVALID_BINDING_SCHEMA', 'Business binding requires a registered Presentation View Model schema path', property));
    }
  });
}

function validateProps(candidate: UiComponentCandidate, item: UiCatalogItem, errors: UiCompileError[]): void {
  const schema = item.propsSchema as Record<string, Object>;
  Object.keys(candidate.props).forEach((property: string): void => {
    if (Object.keys(schema).indexOf(property) < 0) {
      errors.push(error('UNKNOWN_PROP', 'Unknown prop ' + property + ' on ' + candidate.component, property));
    }
  });
}

function validateCycles(components: UiComponentCandidate[], errors: UiCompileError[]): void {
  const byId: Map<string, UiComponentCandidate> = new Map<string, UiComponentCandidate>();
  components.forEach((candidate: UiComponentCandidate): void => byId.set(candidate.id, candidate));
  const visiting: Set<string> = new Set<string>();
  const visited: Set<string> = new Set<string>();
  const visit = (id: string): void => {
    if (visiting.has(id)) {
      errors.push(error('COMPONENT_CYCLE', 'Component cycle contains ' + id, id));
      return;
    }
    if (visited.has(id)) return;
    const candidate = byId.get(id);
    if (candidate === undefined) return;
    visiting.add(id);
    candidate.children.forEach((child: string): void => visit(child));
    visiting.delete(id);
    visited.add(id);
  };
  components.forEach((candidate: UiComponentCandidate): void => visit(candidate.id));
}

export class UiCandidateValidator {
  validate(candidate: UiModelCandidate, context: UiCompileContext): UiCompileError[] {
    const errors: UiCompileError[] = [];
    const schemas = context.presentationSchemas ?? createDefaultUiPresentationSchemaRegistry();
    if (candidate.surfaceId.length === 0 || candidate.surfaceId !== context.surfaceId) {
      errors.push(error('SURFACE_MISMATCH', 'Candidate surface does not match the active surface'));
    }
    if (candidate.rootId.length === 0) errors.push(error('ROOT_MISSING', 'Candidate rootId is empty'));
    const ids: Set<string> = new Set<string>();
    candidate.components.forEach((component: UiComponentCandidate): void => {
      if (component.id.length === 0) {
        errors.push(error('COMPONENT_ID_MISSING', 'Component id is empty'));
        return;
      }
      if (ids.has(component.id)) errors.push(error('DUPLICATE_COMPONENT_ID', 'Duplicate component id ' + component.id, component.id));
      ids.add(component.id);
      const item = catalogItem(context.catalogRegistry, context.catalogGroups, component.component);
      if (item === null) {
        errors.push(error('UNKNOWN_COMPONENT', 'Component is not in the selected Catalog: ' + component.component, component.component));
        return;
      }
      if (item.childPolicy === 'leaf' && component.children.length > 0) {
        errors.push(error('CHILD_POLICY_VIOLATION', component.component + ' cannot have children', component.id));
      }
      if (item.childPolicy === 'single' && component.children.length > 1) {
        errors.push(error('CHILD_POLICY_VIOLATION', component.component + ' accepts only one child', component.id));
      }
      validateProps(component, item, errors);
      validateBindings(component, item, schemas, errors);
      component.actionRefs.forEach((actionRef: string): void => {
        if (actionRef.length === 0) errors.push(error('INVALID_ACTION_REF', 'Empty actionRef', component.id));
      });
    });
    candidate.components.forEach((component: UiComponentCandidate): void => {
      component.children.forEach((child: string): void => {
        if (!ids.has(child)) errors.push(error('ORPHAN_CHILD', 'Unknown child ' + child, component.id));
      });
    });
    if (!ids.has(candidate.rootId)) errors.push(error('UNKNOWN_ROOT', 'Root component does not exist', candidate.rootId));
    validateCycles(candidate.components, errors);
    return errors;
  }
}
