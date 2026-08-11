type CatalogJsonValue = Object | string | number | boolean | null | undefined;
type CatalogJsonRecord = Record<string, CatalogJsonValue>;

export type A2uiCatalogValuePolicy = 'literal' | 'literal-or-path' | 'path-only' | 'legacy-data-path';
export type A2uiCatalogValueType = 'array' | 'boolean' | 'number' | 'object' | 'string';

export interface A2uiCatalogFieldSchema {
  type: A2uiCatalogValueType;
  valuePolicy: A2uiCatalogValuePolicy;
  required?: boolean;
  minLength?: number;
  minItems?: number;
  maxItems?: number;
  fields?: Record<string, A2uiCatalogFieldSchema>;
  items?: A2uiCatalogFieldSchema;
}

export interface A2uiComponentWireSchema {
  fields: Record<string, A2uiCatalogFieldSchema>;
  requireAny?: string[][];
  exactlyOne?: string[][];
  atMostOne?: string[][];
}

interface A2uiCatalogEntry {
  name: string;
  schema?: A2uiComponentWireSchema;
}

interface CatalogResolveResult {
  ok: boolean;
  value: CatalogJsonValue;
}

const MAX_SCHEMA_DEPTH: number = 12;
export const A2UI_CATALOG_RESERVED_COMPONENT_FIELDS: string[] = [
  'id', 'component', 'child', 'children', 'dataPath', 'actions', 'status', 'tone', 'variant', 'path'
];

function objectRecord(value: CatalogJsonValue): CatalogJsonRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as CatalogJsonRecord;
}

function exactKeys(record: CatalogJsonRecord, expected: string[]): boolean {
  const keys = Object.keys(record).sort();
  return keys.join(',') === expected.slice().sort().join(',');
}

function exactAllowedPath(path: string, allowedPaths: string[]): boolean {
  if (path.length === 0) {
    return false;
  }
  return allowedPaths.indexOf(path) >= 0;
}

function bindingPath(value: CatalogJsonValue, allowedPaths: string[]): string | null {
  const binding = objectRecord(value);
  if (binding === null || !exactKeys(binding, ['path']) || typeof binding['path'] !== 'string') {
    return null;
  }
  const path = binding['path'] as string;
  return exactAllowedPath(path, allowedPaths) ? path : null;
}

function pointerSyntax(path: string): boolean {
  return path === '/' || path.startsWith('/');
}

function syntaxBindingPath(value: CatalogJsonValue): string | null {
  const binding = objectRecord(value);
  if (binding === null || !exactKeys(binding, ['path']) || typeof binding['path'] !== 'string') {
    return null;
  }
  const path = binding['path'] as string;
  return pointerSyntax(path) ? path : null;
}

function pointerToken(segment: string): string {
  return segment.split('~1').join('/').split('~0').join('~');
}

function valueAtPointer(model: CatalogJsonValue, path: string): CatalogJsonValue {
  if (!pointerSyntax(path)) {
    return undefined;
  }
  if (path === '/') {
    return model;
  }
  const parts = path.substring(1).split('/');
  let current: CatalogJsonValue = model;
  for (let index = 0; index < parts.length; index++) {
    const key = pointerToken(parts[index]);
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(key)) {
        return undefined;
      }
      const values = current as CatalogJsonValue[];
      const itemIndex = Number(key);
      if (itemIndex >= values.length) {
        return undefined;
      }
      current = values[itemIndex];
      continue;
    }
    const source = objectRecord(current);
    if (source === null || Object.keys(source).indexOf(key) < 0) {
      return undefined;
    }
    current = source[key];
  }
  return current;
}

function failedResolution(): CatalogResolveResult {
  return { ok: false, value: undefined };
}

function resolveLiteralValue(
  value: CatalogJsonValue,
  schema: A2uiCatalogFieldSchema,
  model: CatalogJsonValue,
  depth: number
): CatalogResolveResult {
  if (depth > MAX_SCHEMA_DEPTH) {
    return failedResolution();
  }
  if (schema.type === 'string') {
    const valid = typeof value === 'string' &&
      (schema.minLength === undefined || (value as string).trim().length >= schema.minLength);
    return valid ? { ok: true, value } : failedResolution();
  }
  if (schema.type === 'number') {
    return typeof value === 'number' && Number.isFinite(value as number) ?
      { ok: true, value } : failedResolution();
  }
  if (schema.type === 'boolean') {
    return typeof value === 'boolean' ? { ok: true, value } : failedResolution();
  }
  if (schema.type === 'array') {
    if (!Array.isArray(value) || schema.items === undefined) {
      return failedResolution();
    }
    const values = value as CatalogJsonValue[];
    if ((schema.minItems !== undefined && values.length < schema.minItems) ||
      (schema.maxItems !== undefined && values.length > schema.maxItems)) {
      return failedResolution();
    }
    const output: CatalogJsonValue[] = [];
    for (let index = 0; index < values.length; index++) {
      const item = resolveCatalogValueForModel(values[index], schema.items, model, depth + 1);
      if (!item.ok) {
        return failedResolution();
      }
      output.push(item.value);
    }
    return { ok: true, value: output };
  }
  if (schema.type === 'object') {
    const source = objectRecord(value);
    if (source === null || schema.fields === undefined || !validRequiredFields(source, schema.fields)) {
      return failedResolution();
    }
    const output: CatalogJsonRecord = {};
    const keys = Object.keys(source);
    for (let index = 0; index < keys.length; index++) {
      const key = keys[index];
      const field = schema.fields[key];
      if (field === undefined) {
        return failedResolution();
      }
      const resolved = resolveCatalogValueForModel(source[key], field, model, depth + 1);
      if (!resolved.ok) {
        return failedResolution();
      }
      output[key] = resolved.value;
    }
    return { ok: true, value: output };
  }
  return failedResolution();
}

function resolveCatalogValueForModel(
  value: CatalogJsonValue,
  schema: A2uiCatalogFieldSchema,
  model: CatalogJsonValue,
  depth: number
): CatalogResolveResult {
  if (depth > MAX_SCHEMA_DEPTH) {
    return failedResolution();
  }
  if (schema.valuePolicy === 'literal-or-path' && typeof value === 'string' && pointerSyntax(value as string)) {
    return failedResolution();
  }
  const path = syntaxBindingPath(value);
  if (schema.valuePolicy === 'path-only' || (schema.valuePolicy === 'literal-or-path' && path !== null)) {
    if (path === null) {
      return failedResolution();
    }
    return resolveLiteralValue(valueAtPointer(model, path), schema, model, depth + 1);
  }
  if (schema.valuePolicy !== 'literal' && schema.valuePolicy !== 'literal-or-path') {
    return failedResolution();
  }
  return resolveLiteralValue(value, schema, model, depth + 1);
}

function appendUniquePath(paths: string[], path: string): void {
  if (pointerSyntax(path) && paths.indexOf(path) < 0) {
    paths.push(path);
  }
}

function collectBindingPaths(
  value: CatalogJsonValue,
  schema: A2uiCatalogFieldSchema,
  paths: string[],
  depth: number
): void {
  if (depth > MAX_SCHEMA_DEPTH) {
    return;
  }
  const binding = objectRecord(value);
  if ((schema.valuePolicy === 'path-only' || schema.valuePolicy === 'literal-or-path') &&
    binding !== null && exactKeys(binding, ['path']) && typeof binding['path'] === 'string') {
    appendUniquePath(paths, binding['path'] as string);
    return;
  }
  if (schema.valuePolicy === 'legacy-data-path' && typeof value === 'string') {
    appendUniquePath(paths, value as string);
    return;
  }
  if (schema.type === 'array' && Array.isArray(value) && schema.items !== undefined) {
    const items = value as CatalogJsonValue[];
    for (let index = 0; index < items.length; index++) {
      collectBindingPaths(items[index], schema.items, paths, depth + 1);
    }
    return;
  }
  if (schema.type === 'object' && schema.fields !== undefined) {
    const record = objectRecord(value);
    if (record === null) {
      return;
    }
    const keys = Object.keys(record);
    for (let index = 0; index < keys.length; index++) {
      const field = schema.fields[keys[index]];
      if (field !== undefined) {
        collectBindingPaths(record[keys[index]], field, paths, depth + 1);
      }
    }
  }
}

function validRequiredFields(record: CatalogJsonRecord, fields: Record<string, A2uiCatalogFieldSchema>): boolean {
  const names = Object.keys(fields);
  for (let index = 0; index < names.length; index++) {
    const field = fields[names[index]];
    if (field.required === true && record[names[index]] === undefined) {
      return false;
    }
  }
  return true;
}

function validDeclaredRecord(
  record: CatalogJsonRecord,
  fields: Record<string, A2uiCatalogFieldSchema>,
  allowedPaths: string[],
  depth: number
): boolean {
  if (depth > MAX_SCHEMA_DEPTH || !validRequiredFields(record, fields)) {
    return false;
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const field = fields[keys[index]];
    if (field === undefined || !validCatalogValue(record[keys[index]], field, allowedPaths, depth + 1)) {
      return false;
    }
  }
  return true;
}

function validLiteral(
  value: CatalogJsonValue,
  schema: A2uiCatalogFieldSchema,
  allowedPaths: string[],
  depth: number
): boolean {
  if (depth > MAX_SCHEMA_DEPTH) {
    return false;
  }
  if (schema.type === 'string') {
    return typeof value === 'string' &&
      (schema.minLength === undefined || (value as string).trim().length >= schema.minLength);
  }
  if (schema.type === 'number') {
    return typeof value === 'number' && Number.isFinite(value as number);
  }
  if (schema.type === 'boolean') {
    return typeof value === 'boolean';
  }
  if (schema.type === 'array') {
    if (!Array.isArray(value)) {
      return false;
    }
    const items = value as CatalogJsonValue[];
    if ((schema.minItems !== undefined && items.length < schema.minItems) ||
      (schema.maxItems !== undefined && items.length > schema.maxItems) || schema.items === undefined) {
      return false;
    }
    for (let index = 0; index < items.length; index++) {
      if (!validCatalogValue(items[index], schema.items, allowedPaths, depth + 1)) {
        return false;
      }
    }
    return true;
  }
  if (schema.type === 'object') {
    const record = objectRecord(value);
    return record !== null && schema.fields !== undefined &&
      validDeclaredRecord(record, schema.fields, allowedPaths, depth + 1);
  }
  return false;
}

function validCatalogValue(
  value: CatalogJsonValue,
  schema: A2uiCatalogFieldSchema,
  allowedPaths: string[],
  depth: number
): boolean {
  if (schema.valuePolicy === 'path-only') {
    return bindingPath(value, allowedPaths) !== null;
  }
  if (schema.valuePolicy === 'literal-or-path' && bindingPath(value, allowedPaths) !== null) {
    return true;
  }
  if (schema.valuePolicy === 'literal-or-path' && typeof value === 'string' && pointerSyntax(value as string)) {
    return false;
  }
  if (schema.valuePolicy === 'legacy-data-path') {
    return typeof value === 'string' &&
      ((value as string) === '/' || exactAllowedPath(value as string, allowedPaths));
  }
  if (schema.valuePolicy !== 'literal' && schema.valuePolicy !== 'literal-or-path') {
    return false;
  }
  return validLiteral(value, schema, allowedPaths, depth);
}

function validRequireAny(record: CatalogJsonRecord, groups: string[][] | undefined): boolean {
  if (groups === undefined) {
    return true;
  }
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    const group = groups[groupIndex];
    let found: boolean = false;
    for (let fieldIndex = 0; fieldIndex < group.length; fieldIndex++) {
      if (record[group[fieldIndex]] !== undefined) {
        found = true;
        break;
      }
    }
    if (!found) {
      return false;
    }
  }
  return true;
}

function validExactlyOne(record: CatalogJsonRecord, groups: string[][] | undefined): boolean {
  if (groups === undefined) {
    return true;
  }
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    const group = groups[groupIndex];
    let count: number = 0;
    for (let fieldIndex = 0; fieldIndex < group.length; fieldIndex++) {
      if (record[group[fieldIndex]] !== undefined) {
        count++;
      }
    }
    if (count !== 1) {
      return false;
    }
  }
  return true;
}

function validAtMostOne(record: CatalogJsonRecord, groups: string[][] | undefined): boolean {
  if (groups === undefined) {
    return true;
  }
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    const group = groups[groupIndex];
    let count: number = 0;
    for (let fieldIndex = 0; fieldIndex < group.length; fieldIndex++) {
      if (record[group[fieldIndex]] !== undefined) {
        count++;
      }
    }
    if (count > 1) {
      return false;
    }
  }
  return true;
}

function validRuntimeActions(value: CatalogJsonValue): boolean {
  if (!Array.isArray(value)) {
    return false;
  }
  const actions = value as CatalogJsonValue[];
  const allowedKeys: string[] = ['args', 'id', 'kind', 'label', 'prompt', 'sourceSectionId', 'variant'];
  for (let index = 0; index < actions.length; index++) {
    const action = objectRecord(actions[index]);
    if (action === null || typeof action['id'] !== 'string' || (action['id'] as string).length === 0 ||
      typeof action['label'] !== 'string' || (action['label'] as string).length === 0 ||
      typeof action['prompt'] !== 'string' || (action['prompt'] as string).length === 0 ||
      typeof action['kind'] !== 'string' || typeof action['variant'] !== 'string') {
      return false;
    }
    const keys = Object.keys(action);
    for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
      if (allowedKeys.indexOf(keys[keyIndex]) < 0) {
        return false;
      }
    }
    if (action['sourceSectionId'] !== undefined && typeof action['sourceSectionId'] !== 'string') {
      return false;
    }
    if (action['args'] !== undefined && objectRecord(action['args']) === null) {
      return false;
    }
  }
  return true;
}

function validRuntimeRecord(
  record: CatalogJsonRecord,
  schema: A2uiComponentWireSchema,
  allowedPaths: string[]
): boolean {
  if (!validRequiredFields(record, schema.fields) || !validRequireAny(record, schema.requireAny) ||
    !validExactlyOne(record, schema.exactlyOne) || !validAtMostOne(record, schema.atMostOne)) {
    return false;
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    const field = schema.fields[key];
    if (field === undefined) {
      return false;
    }
    if (key === 'actions' && validRuntimeActions(record[key])) {
      continue;
    }
    if (!validCatalogValue(record[key], field, allowedPaths, 0)) {
      return false;
    }
  }
  return true;
}

export class A2uiComponentCatalogSchema {
  private names: Set<string> = new Set<string>();
  private schemas: Map<string, A2uiComponentWireSchema> = new Map<string, A2uiComponentWireSchema>();
  private schemaEnabled: boolean = false;

  static parse(componentCatalogJson: string): A2uiComponentCatalogSchema | null {
    const catalog = new A2uiComponentCatalogSchema();
    try {
      const items = JSON.parse(componentCatalogJson) as Object[];
      if (!Array.isArray(items) || items.length === 0) {
        return null;
      }
      let schemaCount: number = 0;
      for (let index = 0; index < items.length; index++) {
        const record = objectRecord(items[index]);
        if (record === null || typeof record['name'] !== 'string' ||
          (record['name'] as string).length === 0 || catalog.names.has(record['name'] as string)) {
          return null;
        }
        const name = record['name'] as string;
        catalog.names.add(name);
        const schemaRecord = objectRecord(record['schema']);
        if (schemaRecord !== null) {
          const fields = objectRecord(schemaRecord['fields']);
          if (fields === null) {
            return null;
          }
          catalog.schemas.set(name, record['schema'] as A2uiComponentWireSchema);
          schemaCount++;
        }
      }
      if (schemaCount !== 0 && schemaCount !== items.length) {
        return null;
      }
      catalog.schemaEnabled = schemaCount === items.length;
      return catalog;
    } catch (_error) {
      return null;
    }
  }

  has(componentName: string): boolean {
    return this.names.has(componentName);
  }

  usesWireSchema(): boolean {
    return this.schemaEnabled;
  }

  validates(componentName: string, component: Object, allowedPaths: string[]): boolean {
    if (!this.schemaEnabled) {
      return this.names.has(componentName);
    }
    const schema = this.schemas.get(componentName);
    const record = objectRecord(component);
    if (schema === undefined || record === null || record['component'] !== componentName ||
      !validDeclaredRecord(record, schema.fields, allowedPaths, 0)) {
      return false;
    }
    return validRequireAny(record, schema.requireAny) && validExactlyOne(record, schema.exactlyOne) &&
      validAtMostOne(record, schema.atMostOne);
  }

  bindingPaths(componentName: string, component: Object): string[] {
    const schema = this.schemas.get(componentName);
    const record = objectRecord(component);
    const paths: string[] = [];
    if (schema === undefined || record === null) {
      return paths;
    }
    const keys = Object.keys(schema.fields);
    for (let index = 0; index < keys.length; index++) {
      if (record[keys[index]] !== undefined) {
        collectBindingPaths(record[keys[index]], schema.fields[keys[index]], paths, 0);
      }
    }
    return paths;
  }

  validatesSyntax(componentName: string, component: Object): boolean {
    return this.validates(componentName, component, this.bindingPaths(componentName, component));
  }

  validatesRuntimeSyntax(componentName: string, component: Object): boolean {
    const schema = this.schemas.get(componentName);
    const record = objectRecord(component);
    if (schema === undefined || record === null) {
      return false;
    }
    return validRuntimeRecord(record, schema, this.bindingPaths(componentName, component));
  }

  presentationFieldsJson(componentName: string, component: Object): string {
    const schema = this.schemas.get(componentName);
    const record = objectRecord(component);
    if (schema === undefined || record === null) {
      return '';
    }
    const output: CatalogJsonRecord = {};
    const keys = Object.keys(schema.fields);
    for (let index = 0; index < keys.length; index++) {
      const key = keys[index];
      if (A2UI_CATALOG_RESERVED_COMPONENT_FIELDS.indexOf(key) < 0 && record[key] !== undefined) {
        output[key] = record[key];
      }
    }
    return Object.keys(output).length === 0 ? '' : JSON.stringify(output);
  }

  resolvePresentationFieldsJson(
    componentName: string,
    presentationFieldsJson: string,
    modelJson: string
  ): string | null {
    const schema = this.schemas.get(componentName);
    if (schema === undefined || presentationFieldsJson.length === 0 || modelJson.length === 0) {
      return null;
    }
    try {
      const fields = objectRecord(JSON.parse(presentationFieldsJson) as Object);
      const model = JSON.parse(modelJson) as CatalogJsonValue;
      if (fields === null) {
        return null;
      }
      const output: CatalogJsonRecord = {};
      const keys = Object.keys(fields);
      for (let index = 0; index < keys.length; index++) {
        const key = keys[index];
        const fieldSchema = schema.fields[key];
        if (fieldSchema === undefined || A2UI_CATALOG_RESERVED_COMPONENT_FIELDS.indexOf(key) >= 0) {
          return null;
        }
        const resolved = resolveCatalogValueForModel(fields[key], fieldSchema, model, 0);
        if (!resolved.ok) {
          return null;
        }
        output[key] = resolved.value;
      }
      return JSON.stringify(output);
    } catch (_error) {
      return null;
    }
  }
}
