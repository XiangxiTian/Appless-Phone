import { ActionOffer } from '../agent/action/ActionOfferTypes';
import { AIPHONE_COMPONENT_CATALOG_JSON } from '../aiphone/runtime/A2uiComponentCatalogConst';
import {
  A2UI_COMPONENT_HERO_BANNER,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_LIST,
  A2UI_COMPONENT_SEGMENTED_RING_CHART,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope
} from '../aiphone/runtime/A2uiTypes';
import { A2uiComponentCatalogSchema } from './A2uiComponentCatalogSchema';

type JsonValue = Object | string | number | boolean | null | undefined;
type JsonRecord = Record<string, JsonValue>;

const MAX_LAYOUT_COMPONENTS: number = 24;
const COMPONENT_KEYS: string[] = [
  'actions', 'body', 'child', 'children', 'component', 'dataPath', 'id',
  'path', 'status', 'text', 'title', 'tone', 'variant'
];

interface LayoutBaseline {
  componentLineIndex: number;
  componentEnvelope: A2uiEnvelope;
  rootId: string;
  dataPaths: string[];
  dataValues: Map<string, JsonValue>;
}

export interface A2uiLayoutMergeResult {
  jsonl: string;
  accepted: boolean;
  reason: string;
  diagnostic?: A2uiLayoutMergeDiagnostic;
}

export interface A2uiLayoutMergeDiagnostic {
  componentId: string;
  rule: string;
}

function objectRecord(value: JsonValue): JsonRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as JsonRecord;
}

function exactKeys(record: JsonRecord, allowed: string[]): boolean {
  const keys = Object.keys(record).sort();
  const expected = allowed.slice().sort();
  return keys.join(',') === expected.join(',');
}

function allowedKeys(record: JsonRecord, allowed: string[]): boolean {
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    if (allowed.indexOf(keys[index]) < 0) {
      return false;
    }
  }
  return true;
}

function parseRecord(line: string): JsonRecord | null {
  try {
    return objectRecord(JSON.parse(line) as Object);
  } catch (_error) {
    return null;
  }
}

function baselineOf(lines: string[], surfaceId: string): LayoutBaseline | null {
  let componentLineIndex: number = -1;
  let componentEnvelope: A2uiEnvelope | null = null;
  let rootId: string = '';
  const dataPaths: string[] = [];
  const dataValues: Map<string, JsonValue> = new Map<string, JsonValue>();
  const updatePaths: string[] = [];
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim();
    if (line.length === 0) {
      continue;
    }
    const record = parseRecord(line);
    if (record === null) {
      return null;
    }
    const create = objectRecord(record['createSurface']);
    if (create !== null) {
      if (create['surfaceId'] !== surfaceId || typeof create['root'] !== 'string') {
        return null;
      }
      rootId = create['root'] as string;
    }
    const update = objectRecord(record['updateComponents']);
    if (update !== null) {
      if (componentLineIndex >= 0 || update['surfaceId'] !== surfaceId || !Array.isArray(update['components'])) {
        return null;
      }
      componentLineIndex = index;
      componentEnvelope = record as A2uiEnvelope;
    }
    const data = objectRecord(record['updateDataModel']);
    if (data !== null) {
      if (data['surfaceId'] !== surfaceId || typeof data['path'] !== 'string' ||
        Object.keys(data).indexOf('value') < 0) {
        return null;
      }
      const path = data['path'] as string;
      if (path.length === 0 || updatePaths.indexOf(path) >= 0) {
        return null;
      }
      updatePaths.push(path);
      collectExistingPaths(data['value'], path, dataPaths, dataValues);
    }
  }
  if (componentLineIndex < 0 || componentEnvelope === null || rootId.length === 0 || dataPaths.length === 0) {
    return null;
  }
  return {
    componentLineIndex: componentLineIndex,
    componentEnvelope: componentEnvelope,
    rootId: rootId,
    dataPaths: dataPaths,
    dataValues: dataValues
  };
}

function validDataPath(path: string, baselinePaths: string[]): boolean {
  return baselinePaths.indexOf(path) >= 0;
}

function decodePointerToken(value: string): string | null {
  let output: string = '';
  for (let index = 0; index < value.length; index++) {
    const next = value.charAt(index);
    if (next !== '~') {
      output += next;
      continue;
    }
    if (index + 1 >= value.length) return null;
    const escaped = value.charAt(index + 1);
    if (escaped === '0') output += '~';
    else if (escaped === '1') output += '/';
    else return null;
    index++;
  }
  return output;
}

function itemValueAtPath(item: JsonValue, path: string): JsonValue {
  if (!path.startsWith('/')) return undefined;
  if (path === '/') return item;
  const encoded = path.substring(1).split('/');
  let current: JsonValue = item;
  for (let index = 0; index < encoded.length; index++) {
    const token = decodePointerToken(encoded[index]);
    if (token === null) return undefined;
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(token)) return undefined;
      const values = current as JsonValue[];
      const itemIndex = Number(token);
      if (itemIndex >= values.length) return undefined;
      current = values[itemIndex];
      continue;
    }
    const source = objectRecord(current);
    if (source === null || Object.keys(source).indexOf(token) < 0) return undefined;
    current = source[token];
  }
  return current;
}

function primitiveTextValue(value: JsonValue): boolean {
  return typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean';
}

function arrayFieldMappingSourceFailure(
  component: string,
  labelPath: string,
  valuePath: string,
  timePath: JsonValue,
  source: JsonValue
): string {
  if (!Array.isArray(source)) return 'mapping_source_not_array';
  const items = source as JsonValue[];
  if (component === A2UI_COMPONENT_SEGMENTED_RING_CHART && items.length === 0) {
    return 'mapping_source_size_invalid';
  }
  let hasInfoValue: boolean = false;
  for (let index = 0; index < items.length; index++) {
    const label = itemValueAtPath(items[index], labelPath);
    const value = itemValueAtPath(items[index], valuePath);
    if (typeof label !== 'string') return 'mapping_label_not_string';
    if (component === A2UI_COMPONENT_INFO_ROWS) {
      if (value !== undefined && value !== null) {
        if (!primitiveTextValue(value)) return 'mapping_value_not_primitive';
        hasInfoValue = true;
      }
      if (timePath !== undefined) {
        const time = itemValueAtPath(items[index], timePath as string);
        if (time !== undefined && time !== null && typeof time !== 'string') return 'mapping_time_not_string';
      }
    } else if (typeof value !== 'number' || !Number.isFinite(value as number)) {
      return 'mapping_value_not_number';
    }
  }
  if (component === A2UI_COMPONENT_INFO_ROWS && items.length > 0 && !hasInfoValue) {
    return 'mapping_value_missing';
  }
  return '';
}

function arrayFieldMappingFailure(
  record: JsonRecord,
  baselineValues: Map<string, JsonValue>,
  itemScopeValues?: JsonValue[]
): string {
  const labelPath = record['labelPath'];
  const valuePath = record['valuePath'];
  const timePath = record['timePath'];
  const hasMapping = labelPath !== undefined || valuePath !== undefined || timePath !== undefined;
  if (!hasMapping) return '';
  const component = record['component'];
  if (component !== A2UI_COMPONENT_INFO_ROWS && component !== A2UI_COMPONENT_SEGMENTED_RING_CHART) {
    return 'mapping_component_unsupported';
  }
  if (typeof labelPath !== 'string' || typeof valuePath !== 'string' ||
    !(labelPath as string).startsWith('/') || !(valuePath as string).startsWith('/')) {
    return 'mapping_paths_invalid';
  }
  if (timePath !== undefined &&
    (component !== A2UI_COMPONENT_INFO_ROWS || typeof timePath !== 'string' || !(timePath as string).startsWith('/'))) {
    return 'mapping_time_path_invalid';
  }
  const dataPath = record['dataPath'];
  if (typeof dataPath !== 'string') return 'mapping_data_path_missing';
  if (itemScopeValues === undefined) {
    return arrayFieldMappingSourceFailure(
      component as string,
      labelPath as string,
      valuePath as string,
      timePath,
      baselineValues.get(dataPath as string)
    );
  }
  for (let index = 0; index < itemScopeValues.length; index++) {
    const failure = arrayFieldMappingSourceFailure(
      component as string,
      labelPath as string,
      valuePath as string,
      timePath,
      itemValueAtPath(itemScopeValues[index], dataPath as string)
    );
    if (failure.length > 0) return failure;
  }
  return '';
}

function rememberDiagnostic(
  diagnostics: A2uiLayoutMergeDiagnostic[],
  componentId: string,
  rule: string
): void {
  if (diagnostics.length === 0) {
    diagnostics.push({ componentId: componentId, rule: rule });
  }
}

function listChildren(record: JsonRecord): JsonRecord | null {
  if (record['component'] !== A2UI_COMPONENT_LIST) {
    return null;
  }
  const children = objectRecord(record['children']);
  if (children === null || !exactKeys(children, ['componentId', 'path']) ||
    typeof children['componentId'] !== 'string' || (children['componentId'] as string).length === 0 ||
    typeof children['path'] !== 'string' || (children['path'] as string).length === 0) {
    return null;
  }
  return children;
}

function pointerToken(value: string): string {
  return value.replace(/~/g, '~0').replace(/\//g, '~1');
}

function childPath(path: string, token: string): string {
  return path === '/' ? '/' + token : path + '/' + token;
}

function collectExistingPaths(
  value: JsonValue,
  path: string,
  output: string[],
  pathValues?: Map<string, JsonValue>
): void {
  if (output.indexOf(path) < 0) output.push(path);
  if (pathValues !== undefined) pathValues.set(path, value);
  if (value === null || value === undefined || typeof value !== 'object') return;
  if (Array.isArray(value)) {
    const items = value as JsonValue[];
    for (let index = 0; index < items.length; index++) {
      collectExistingPaths(items[index], childPath(path, index.toString()), output, pathValues);
    }
    return;
  }
  const source = value as JsonRecord;
  const keys = Object.keys(source);
  for (let index = 0; index < keys.length; index++) {
    collectExistingPaths(source[keys[index]], childPath(path, pointerToken(keys[index])), output, pathValues);
  }
}

function listItemScopePaths(value: JsonValue): string[] | null {
  if (!Array.isArray(value)) return null;
  const items = value as JsonValue[];
  if (items.length === 0) return ['/'];
  const paths: string[] = [];
  collectExistingPaths(items[0], '/', paths);
  for (let index = 1; index < items.length; index++) {
    const itemPaths: string[] = [];
    collectExistingPaths(items[index], '/', itemPaths);
    for (let pathIndex = paths.length - 1; pathIndex >= 0; pathIndex--) {
      if (itemPaths.indexOf(paths[pathIndex]) < 0) paths.splice(pathIndex, 1);
    }
  }
  return paths;
}

function childIds(record: JsonRecord): string[] | null {
  if (record['component'] === A2UI_COMPONENT_LIST) {
    if (record['child'] !== undefined || record['dataPath'] !== undefined) {
      return null;
    }
    const dynamicChildren = listChildren(record);
    return dynamicChildren === null ? null : [dynamicChildren['componentId'] as string];
  }
  if (record['child'] !== undefined && record['children'] !== undefined) {
    return null;
  }
  const ids: string[] = [];
  if (record['child'] !== undefined) {
    if (typeof record['child'] !== 'string' || (record['child'] as string).length === 0) {
      return null;
    }
    ids.push(record['child'] as string);
  }
  if (record['children'] !== undefined) {
    if (!Array.isArray(record['children'])) {
      return null;
    }
    const children = record['children'] as Object[];
    for (let index = 0; index < children.length; index++) {
      if (typeof children[index] !== 'string' || (children[index] as string).length === 0 ||
        ids.indexOf(children[index] as string) >= 0) {
        return null;
      }
      ids.push(children[index] as string);
    }
  }
  return ids;
}

function validComponentFields(record: JsonRecord): boolean {
  const stringKeys: string[] = [
    'body', 'component', 'dataPath', 'id', 'path', 'status',
    'text', 'title', 'tone', 'variant'
  ];
  for (let index = 0; index < stringKeys.length; index++) {
    const value = record[stringKeys[index]];
    if (value !== undefined && typeof value !== 'string') {
      return false;
    }
  }
  return true;
}

function offerMap(offers: ActionOffer[]): Map<string, ActionOffer> | null {
  const mapped: Map<string, ActionOffer> = new Map<string, ActionOffer>();
  for (let index = 0; index < offers.length; index++) {
    const offer = offers[index];
    if (offer.offerId.length === 0 || offer.actionId.length === 0 || offer.label.length === 0 ||
      mapped.has(offer.offerId)) {
      return null;
    }
    mapped.set(offer.offerId, offer);
  }
  return mapped;
}

function actionFor(offer: ActionOffer): A2uiAction | null {
  try {
    return {
      id: offer.actionId,
      label: offer.label,
      prompt: offer.label,
      variant: offer.variant,
      kind: 'prompt',
      args: JSON.parse(JSON.stringify(offer.args)) as Object
    };
  } catch (_error) {
    return null;
  }
}

function resolvedActions(
  value: JsonValue,
  offers: Map<string, ActionOffer>,
  usedOffers: Set<string>
): A2uiAction[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const references = value as Object[];
  const actions: A2uiAction[] = [];
  for (let index = 0; index < references.length; index++) {
    const reference = objectRecord(references[index]);
    if (reference === null || !exactKeys(reference, ['offerId']) || typeof reference['offerId'] !== 'string') {
      return null;
    }
    const offerId = reference['offerId'] as string;
    const offer = offers.get(offerId);
    if (offer === undefined || usedOffers.has(offerId)) {
      return null;
    }
    const action = actionFor(offer);
    if (action === null) {
      return null;
    }
    usedOffers.add(offerId);
    actions.push(action);
  }
  return actions;
}

function candidateComponents(
  value: JsonValue,
  rootId: string,
  baselinePaths: string[],
  baselineValues: Map<string, JsonValue>,
  offers: ActionOffer[],
  componentCatalogJson: string,
  diagnostics: A2uiLayoutMergeDiagnostic[]
): A2uiComponent[] | null {
  if (!Array.isArray(value)) {
    return null;
  }
  const rawComponents = value as Object[];
  if (rawComponents.length === 0 || rawComponents.length > MAX_LAYOUT_COMPONENTS) {
    return null;
  }
  const catalog = A2uiComponentCatalogSchema.parse(componentCatalogJson);
  const availableOffers = offerMap(offers);
  if (catalog === null || availableOffers === null) {
    return null;
  }
  const byId: Map<string, JsonRecord> = new Map<string, JsonRecord>();
  const childrenById: Map<string, string[]> = new Map<string, string[]>();
  const parentCount: Map<string, number> = new Map<string, number>();
  const listTemplateIds: Set<string> = new Set<string>();
  const output: A2uiComponent[] = [];
  const usedOffers: Set<string> = new Set<string>();
  let heroCount: number = 0;
  for (let index = 0; index < rawComponents.length; index++) {
    const record = objectRecord(rawComponents[index]);
    if (record === null || typeof record['id'] !== 'string' || (record['id'] as string).length === 0) {
      return null;
    }
    const id = record['id'] as string;
    if (typeof record['component'] !== 'string' || !catalog.has(record['component'] as string)) {
      rememberDiagnostic(diagnostics, id, 'component_not_allowed');
      return null;
    }
    const componentName = record['component'] as string;
    if ((catalog.usesWireSchema() && !catalog.validatesSyntax(componentName, record)) ||
      (!catalog.usesWireSchema() &&
        (!allowedKeys(record, COMPONENT_KEYS) || !validComponentFields(record)))) {
      rememberDiagnostic(diagnostics, id, 'component_schema_invalid');
      return null;
    }
    if (record['component'] === A2UI_COMPONENT_HERO_BANNER) {
      heroCount++;
      if (heroCount > 1) return null;
    }
    if (byId.has(id)) {
      rememberDiagnostic(diagnostics, id, 'duplicate_component_id');
      return null;
    }
    if (record['component'] === A2UI_COMPONENT_LIST) {
      if (record['actions'] !== undefined) {
        return null;
      }
      const dynamicChildren = listChildren(record);
      if (dynamicChildren === null ||
        !validDataPath(dynamicChildren['path'] as string, baselinePaths)) {
        return null;
      }
      listTemplateIds.add(dynamicChildren['componentId'] as string);
    }
    const childList = childIds(record);
    if (childList === null) {
      return null;
    }
    let clone: A2uiComponent;
    try {
      clone = JSON.parse(JSON.stringify(record)) as A2uiComponent;
    } catch (_error) {
      return null;
    }
    if (record['actions'] !== undefined) {
      const actions = resolvedActions(record['actions'], availableOffers, usedOffers);
      if (actions === null) {
        return null;
      }
      clone.actions = actions;
    }
    byId.set(id, record);
    childrenById.set(id, childList);
    parentCount.set(id, 0);
    output.push(clone);
  }
  if (!byId.has(rootId)) {
    return null;
  }
  const listIds: string[] = [];
  const itemScopePathsById: Map<string, string[]> = new Map<string, string[]>();
  const itemScopeValuesById: Map<string, JsonValue[]> = new Map<string, JsonValue[]>();
  listTemplateIds.forEach((templateId: string) => {
    const template = byId.get(templateId);
    if (template === undefined || template['component'] === A2UI_COMPONENT_LIST ||
      template['component'] === A2UI_COMPONENT_HERO_BANNER || template['actions'] !== undefined) {
      listIds.push('');
    }
  });
  if (listIds.indexOf('') >= 0) {
    return null;
  }
  byId.forEach((record: JsonRecord, id: string) => {
    if (record['component'] === A2UI_COMPONENT_LIST) {
      listIds.push(id);
    }
  });
  for (let index = 0; index < listIds.length; index++) {
    const listRecord = byId.get(listIds[index]);
    const dynamicChildren = listRecord === undefined ? null : listChildren(listRecord);
    const scopeValue = dynamicChildren === null ? undefined :
      baselineValues.get(dynamicChildren['path'] as string);
    const scopePaths = dynamicChildren === null ? null : listItemScopePaths(scopeValue);
    if (scopePaths === null) return null;
    const scopeValues = scopeValue as JsonValue[];
    const descendants: string[] = (childrenById.get(listIds[index]) ?? []).slice();
    const checked: Set<string> = new Set<string>();
    while (descendants.length > 0) {
      const descendantId = descendants.shift();
      if (descendantId === undefined || checked.has(descendantId)) {
        return null;
      }
      checked.add(descendantId);
      itemScopePathsById.set(descendantId, scopePaths);
      itemScopeValuesById.set(descendantId, scopeValues);
      const descendant = byId.get(descendantId);
      if (descendant === undefined || descendant['component'] === A2UI_COMPONENT_LIST ||
        descendant['component'] === A2UI_COMPONENT_HERO_BANNER || descendant['actions'] !== undefined) {
        return null;
      }
      const grandchildren = childrenById.get(descendantId) ?? [];
      for (let childIndex = 0; childIndex < grandchildren.length; childIndex++) {
        descendants.push(grandchildren[childIndex]);
      }
    }
  }
  for (let index = 0; index < output.length; index++) {
    const component = output[index];
    const record = byId.get(component.id);
    const allowedPaths = itemScopePathsById.get(component.id) ?? baselinePaths;
    if (record === undefined) {
      return null;
    }
    const mappingFailure = arrayFieldMappingFailure(
      record,
      baselineValues,
      itemScopeValuesById.get(component.id)
    );
    if (mappingFailure.length > 0) {
      rememberDiagnostic(diagnostics, component.id, mappingFailure);
      return null;
    }
    if (catalog.usesWireSchema() && !catalog.validates(component.component, record, allowedPaths)) {
      return null;
    }
    if (component.dataPath !== undefined &&
      (typeof component.dataPath !== 'string' ||
        (component.dataPath !== '/' && !validDataPath(component.dataPath, allowedPaths)))) {
      return null;
    }
    if (component.dataPath === '/' && !itemScopePathsById.has(component.id)) {
      return null;
    }
  }
  const ids = Array.from(byId.keys());
  for (let index = 0; index < ids.length; index++) {
    const children = childrenById.get(ids[index]);
    if (children === undefined) {
      return null;
    }
    for (let childIndex = 0; childIndex < children.length; childIndex++) {
      const child = children[childIndex];
      if (!byId.has(child)) {
        return null;
      }
      parentCount.set(child, (parentCount.get(child) ?? 0) + 1);
    }
  }
  for (let index = 0; index < ids.length; index++) {
    const expectedParents = ids[index] === rootId ? 0 : 1;
    if (parentCount.get(ids[index]) !== expectedParents) {
      return null;
    }
  }
  const visited: Set<string> = new Set<string>();
  const queue: string[] = [rootId];
  while (queue.length > 0) {
    const id = queue.shift();
    if (id === undefined || visited.has(id)) {
      return null;
    }
    visited.add(id);
    const children = childrenById.get(id);
    if (children === undefined) {
      return null;
    }
    for (let index = 0; index < children.length; index++) {
      queue.push(children[index]);
    }
  }
  return visited.size === output.length ? output : null;
}

function candidateEnvelope(
  candidateJsonl: string,
  surfaceId: string,
  baseline: LayoutBaseline,
  offers: ActionOffer[],
  componentCatalogJson: string,
  diagnostics: A2uiLayoutMergeDiagnostic[]
): A2uiEnvelope | null {
  const lines = candidateJsonl.trim().split(/\r?\n/);
  if (lines.length !== 1) {
    return null;
  }
  const record = parseRecord(lines[0]);
  if (record === null || !exactKeys(record, ['version', 'updateComponents'])) {
    return null;
  }
  const update = objectRecord(record['updateComponents']);
  if (update === null || !exactKeys(update, ['components', 'surfaceId']) || update['surfaceId'] !== surfaceId) {
    return null;
  }
  const components = candidateComponents(
    update['components'],
    baseline.rootId,
    baseline.dataPaths,
    baseline.dataValues,
    offers,
    componentCatalogJson,
    diagnostics
  );
  if (components === null) {
    return null;
  }
  return {
    version: baseline.componentEnvelope.version,
    updateComponents: {
      surfaceId: surfaceId,
      components: components
    }
  };
}

export function mergeA2uiLayout(
  baselineJsonl: string,
  candidateJsonl: string,
  surfaceId: string,
  offers: ActionOffer[],
  componentCatalogJson: string = AIPHONE_COMPONENT_CATALOG_JSON
): string {
  const result = mergeA2uiLayoutWithStatus(
    baselineJsonl,
    candidateJsonl,
    surfaceId,
    offers,
    componentCatalogJson
  );
  if (!result.accepted) {
    return baselineJsonl;
  }
  return result.jsonl;
}

export function mergeA2uiLayoutWithStatus(
  baselineJsonl: string,
  candidateJsonl: string,
  surfaceId: string,
  offers: ActionOffer[],
  componentCatalogJson: string = AIPHONE_COMPONENT_CATALOG_JSON
): A2uiLayoutMergeResult {
  if (baselineJsonl.length === 0 || candidateJsonl.length === 0 || surfaceId.length === 0) {
    return { jsonl: baselineJsonl, accepted: false, reason: 'empty_input' };
  }
  const lines = baselineJsonl.split('\n');
  const baseline = baselineOf(lines, surfaceId);
  if (baseline === null) {
    return { jsonl: baselineJsonl, accepted: false, reason: 'invalid_baseline' };
  }
  const diagnostics: A2uiLayoutMergeDiagnostic[] = [];
  const candidate = candidateEnvelope(
    candidateJsonl,
    surfaceId,
    baseline,
    offers,
    componentCatalogJson,
    diagnostics
  );
  if (candidate === null) {
    const rejected: A2uiLayoutMergeResult = {
      jsonl: baselineJsonl,
      accepted: false,
      reason: 'candidate_rejected'
    };
    if (diagnostics.length > 0) rejected.diagnostic = diagnostics[0];
    return rejected;
  }
  lines[baseline.componentLineIndex] = JSON.stringify(candidate);
  return { jsonl: lines.join('\n'), accepted: true, reason: 'accepted' };
}
