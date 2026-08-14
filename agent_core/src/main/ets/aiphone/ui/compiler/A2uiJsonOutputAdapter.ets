import { parseJsonl } from '../../../a2ui/A2uiProtocol';
import { A2uiStreamComponentBatch, A2uiUpdateComponentsStreamScanner } from '../../../a2ui/A2uiUpdateComponentsStreamScanner';
import { UiBinding } from '../ir/UiBindingTypes';
import { UiCandidateValidator } from './UiCandidateValidator';
import { UiCanonicalizer } from './UiCanonicalizer';
import {
  compileFailure,
  UiCompileContext,
  UiCompileError,
  UiCompileMetadata,
  UiCompileResult,
  UiComponentCandidate,
  UiModelCandidate,
  UiModelOutputAdapter
} from './UiModelOutputAdapter';

type JsonRecord = Record<string, Object | string | number | boolean | null | undefined>;

function failure(code: string, message: string, source: string = ''): UiCompileResult {
  const value: UiCompileError = { code, message };
  if (source.length > 0) value.source = source;
  return compileFailure([value]);
}

function stringValue(record: JsonRecord, key: string): string | null {
  const value = record[key];
  return typeof value === 'string' ? value : null;
}

function objectValue(record: JsonRecord, key: string): JsonRecord | null {
  const value = record[key];
  return value !== null && value !== undefined && typeof value === 'object' && !Array.isArray(value)
    ? value as JsonRecord : null;
}

function stringArray(value: Object | string | number | boolean | null | undefined): string[] | null {
  if (!Array.isArray(value)) return null;
  const result: string[] = [];
  for (let index = 0; index < value.length; index++) {
    if (typeof value[index] !== 'string') return null;
    result.push(value[index] as string);
  }
  return result;
}

function componentFromJson(value: Object): UiComponentCandidate | UiCompileError {
  const record = value as JsonRecord;
  const id = stringValue(record, 'id');
  const component = stringValue(record, 'component');
  if (id === null || component === null) {
    return { code: 'COMPONENT_SHAPE_INVALID', message: 'A2UI component requires string id and component' };
  }
  const childrenValue = stringArray(record['children']);
  if (record['children'] !== undefined && childrenValue === null) {
    return { code: 'CHILDREN_SHAPE_INVALID', message: 'children must be a string array', source: id };
  }
  const children = childrenValue === null ? [] : childrenValue;
  const child = stringValue(record, 'child');
  if (child !== null) children.push(child);
  const props: Record<string, Object | string | number | boolean | null> = {};
  ['text', 'variant', 'align', 'justify'].forEach((key: string): void => {
    const value = record[key];
    if (value !== undefined && value !== null) props[key] = value;
  });
  const explicitProps = objectValue(record, 'props');
  if (explicitProps !== null) {
    Object.keys(explicitProps).forEach((key: string): void => {
      const value = explicitProps[key];
      if (value !== undefined) props[key] = value as Object | string | number | boolean | null;
    });
  }
  const actionRefsValue = stringArray(record['actionRefs']);
  if (record['actionRefs'] !== undefined && actionRefsValue === null) {
    return { code: 'ACTION_REFS_SHAPE_INVALID', message: 'actionRefs must be a string array', source: id };
  }
  const bindings: Record<string, UiBinding> = {};
  const explicitBindings = objectValue(record, 'bindings');
  if (explicitBindings !== null) {
    Object.keys(explicitBindings).forEach((key: string): void => {
      const value = objectValue(explicitBindings as JsonRecord, key);
      if (value === null) {
        bindings[key] = { store: 'business', path: '', expectedType: '' };
        return;
      }
      bindings[key] = {
        store: stringValue(value, 'store') as 'business' | 'local' | 'agent',
        path: stringValue(value, 'path') ?? '',
        expectedType: stringValue(value, 'expectedType') ?? ''
      };
    });
  }
  return {
    id,
    component,
    children,
    props: props as Object,
    bindings,
    actionRefs: actionRefsValue === null ? [] : actionRefsValue
  };
}

function upsertComponents(target: UiComponentCandidate[], next: UiComponentCandidate[]): void {
  next.forEach((candidate: UiComponentCandidate): void => {
    let index = -1;
    for (let cursor = 0; cursor < target.length; cursor++) {
      if (target[cursor].id === candidate.id) {
        index = cursor;
        break;
      }
    }
    if (index < 0) target.push(candidate);
    else target[index] = candidate;
  });
}

export class A2uiJsonOutputAdapter implements UiModelOutputAdapter {
  private readonly validator: UiCandidateValidator = new UiCandidateValidator();
  private readonly canonicalizer: UiCanonicalizer = new UiCanonicalizer();
  private readonly scanner: A2uiUpdateComponentsStreamScanner = new A2uiUpdateComponentsStreamScanner();
  private readonly streamedComponents: UiComponentCandidate[] = [];
  private streamedSurfaceId: string = '';
  private streamedVersion: string = '';

  format(): 'a2ui-json' {
    return 'a2ui-json';
  }

  compile(text: string, context: UiCompileContext): UiCompileResult {
    const lines = parseJsonl(text);
    if (lines.length === 0) return failure('JSON_PARSE_EMPTY', 'No complete JSON object found in model output');
    const candidate = this.candidateFromEnvelopes(lines, context);
    if (candidate === null) return failure('A2UI_ENVELOPE_MISSING', 'No createSurface/updateComponents envelope found');
    return this.compileCandidate(candidate, context);
  }

  feed(delta: string, context: UiCompileContext): UiCompileResult | null {
    const result = this.scanner.feed(delta);
    if (result.error.length > 0) {
      this.resetStream();
      return failure('A2UI_STREAM_INVALID', result.error);
    }
    if (result.batches.length === 0) return null;
    result.batches.forEach((batch: A2uiStreamComponentBatch): void => {
      this.streamedSurfaceId = batch.surfaceId;
      this.streamedVersion = batch.version;
      const candidates: UiComponentCandidate[] = [];
      batch.components.forEach((component: Object): void => {
        const parsed = componentFromJson(component);
        if ((parsed as UiCompileError).code === undefined) candidates.push(parsed as UiComponentCandidate);
      });
      upsertComponents(this.streamedComponents, candidates);
    });
    const candidate: UiModelCandidate = {
      surfaceId: this.streamedSurfaceId.length === 0 ? context.surfaceId : this.streamedSurfaceId,
      rootId: 'root',
      title: context.title ?? '',
      intent: context.intent ?? '',
      catalogVersion: this.streamedVersion,
      components: this.streamedComponents.slice(),
      sourceFormat: 'a2ui-json'
    };
    return this.compileCandidate(candidate, context);
  }

  finalize(context: UiCompileContext): UiCompileResult {
    const result = this.scanner.finalize();
    if (result.error.length > 0) {
      this.resetStream();
      return failure('A2UI_STREAM_INCOMPLETE', result.error);
    }
    if (this.streamedComponents.length > 0) {
      const candidate: UiModelCandidate = {
        surfaceId: this.streamedSurfaceId.length === 0 ? context.surfaceId : this.streamedSurfaceId,
        rootId: 'root',
        title: context.title ?? '',
        intent: context.intent ?? '',
        catalogVersion: this.streamedVersion,
        components: this.streamedComponents.slice(),
        sourceFormat: 'a2ui-json'
      };
      const compiled = this.compileCandidate(candidate, context);
      this.resetStream();
      return compiled;
    }
    return failure('A2UI_STREAM_EMPTY', 'No streamed components found');
  }

  resetStream(): void {
    this.scanner.reset();
    this.streamedComponents.splice(0, this.streamedComponents.length);
    this.streamedSurfaceId = '';
    this.streamedVersion = '';
  }

  private compileCandidate(candidate: UiModelCandidate, context: UiCompileContext): UiCompileResult {
    const errors = this.validator.validate(candidate, context);
    if (errors.length > 0) return compileFailure(errors);
    try {
      return {
        ok: true,
        candidate,
        surface: this.canonicalizer.canonicalize(candidate, context),
        errors: [],
        metadata: this.metadata(context)
      };
    } catch (error) {
      return failure('CANONICALIZE_FAILED', String(error));
    }
  }

  private metadata(context: UiCompileContext): UiCompileMetadata {
    return {
      catalogVersion: context.catalogRegistry.snapshot(context.catalogGroups).version,
      viewModelSchemaVersion: 1,
      adapterId: 'a2ui-json',
      adapterVersion: 1
    };
  }

  private candidateFromEnvelopes(lines: string[], context: UiCompileContext): UiModelCandidate | null {
    let surfaceId = context.surfaceId;
    let rootId = 'root';
    let title = context.title ?? '';
    let intent = context.intent ?? '';
    const components: UiComponentCandidate[] = [];
    for (let index = 0; index < lines.length; index++) {
      let parsed: JsonRecord;
      try {
        parsed = JSON.parse(lines[index]) as JsonRecord;
      } catch (_error) {
        continue;
      }
      const create = objectValue(parsed, 'createSurface');
      if (create !== null) {
        const createSurfaceId = stringValue(create, 'surfaceId');
        if (createSurfaceId !== null) surfaceId = createSurfaceId;
        const root = stringValue(create, 'root');
        if (root !== null) rootId = root;
        const nextTitle = stringValue(create, 'title');
        if (nextTitle !== null) title = nextTitle;
        const nextIntent = stringValue(create, 'intent');
        if (nextIntent !== null) intent = nextIntent;
      }
      const update = objectValue(parsed, 'updateComponents');
      if (update !== null) {
        const updateSurfaceId = stringValue(update, 'surfaceId');
        if (updateSurfaceId !== null) surfaceId = updateSurfaceId;
        const rawComponentsValue = update['components'];
        if (!Array.isArray(rawComponentsValue)) continue;
        const rawComponents = rawComponentsValue as Object[];
        const next: UiComponentCandidate[] = [];
        for (let componentIndex = 0; componentIndex < rawComponents.length; componentIndex++) {
          const value: Object = rawComponents[componentIndex];
          if (value === null || typeof value !== 'object' || Array.isArray(value)) continue;
          const parsedComponent = componentFromJson(value as Object);
          if ((parsedComponent as UiCompileError).code !== undefined) return null;
          next.push(parsedComponent as UiComponentCandidate);
        }
        upsertComponents(components, next);
      }
      // patchComponents is an internal/legacy extension; v4 model output must
      // enter Candidate → Validator → Reconciler instead of bypassing IR.
      if (parsed['patchComponents'] !== undefined) return null;
    }
    if (components.length === 0) return null;
    return {
      surfaceId,
      rootId,
      title,
      intent,
      catalogVersion: context.catalogRegistry.snapshot(context.catalogGroups).version,
      components,
      sourceFormat: 'a2ui-json'
    };
  }
}
