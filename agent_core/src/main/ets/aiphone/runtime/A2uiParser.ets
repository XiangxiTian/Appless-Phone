import {
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_CONFIRM_PANEL,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_EXPANDABLE_CARD,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_HERO_BANNER,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_LIST,
  A2UI_COMPONENT_MATRIX_HEATMAP,
  A2UI_COMPONENT_MASONRY_GRID,
  A2UI_COMPONENT_MEDIA_SLIDER,
  A2UI_COMPONENT_METRIC_GRID,
  A2UI_COMPONENT_MULTI_SERIES_LINE_CHART,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_SCENE_TABS,
  A2UI_COMPONENT_SCHEDULE_STACK,
  A2UI_COMPONENT_SEGMENTED_RING_CHART,
  A2UI_COMPONENT_SKELETON_CARD,
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2UI_COMPONENT_TRAVEL_OPTIONS,
  A2UI_COMPONENT_MULTI_TASK_BOARD,
  A2uiAction,
  A2uiComponent,
  A2uiEnvelope,
  A2uiStreamParseResult
} from './A2uiTypes';
import { A2uiComponentCatalogSchema } from '../../a2ui/A2uiComponentCatalogSchema';
import { UI_AGENT_LAB_COMPONENT_CATALOG_JSON } from './A2uiComponentCatalogConst';

const KNOWN_COMPONENTS: string[] = [
  A2UI_COMPONENT_SURFACE_ROOT,
  A2UI_COMPONENT_COLUMN,
  A2UI_COMPONENT_ROW,
  A2UI_COMPONENT_TEXT,
  A2UI_COMPONENT_ACTION_BAR,
  A2UI_COMPONENT_ERROR_NOTICE,
  A2UI_COMPONENT_THINKING_STREAM,
  A2UI_COMPONENT_THINKING_CARD,
  A2UI_COMPONENT_TRAIN_OPTIONS,
  A2UI_COMPONENT_FLIGHT_BOARD,
  A2UI_COMPONENT_TRAVEL_OPTIONS,
  A2UI_COMPONENT_MULTI_TASK_BOARD,
  A2UI_COMPONENT_FOOD_CHOICES,
  A2UI_COMPONENT_CONFIRM_PANEL,
  A2UI_COMPONENT_INFO_ROWS,
  A2UI_COMPONENT_TOOL_CONNECT_CARD,
  A2UI_COMPONENT_GENERIC_TOOL_RESULTS,
  A2UI_COMPONENT_SOCIAL_HUB,
  A2UI_COMPONENT_STRIPE_RECEIVING_ACCOUNT_CARD,
  A2UI_COMPONENT_AGGREGATE_SEARCH,
  A2UI_COMPONENT_SCHEDULE_STACK,
  A2UI_COMPONENT_SKELETON_CARD,
  A2UI_COMPONENT_EXPANDABLE_CARD,
  A2UI_COMPONENT_MEDIA_SLIDER,
  A2UI_COMPONENT_SCENE_TABS,
  A2UI_COMPONENT_MASONRY_GRID,
  A2UI_COMPONENT_LIST,
  A2UI_COMPONENT_HERO_BANNER,
  A2UI_COMPONENT_METRIC_GRID,
  A2UI_COMPONENT_SEGMENTED_RING_CHART,
  A2UI_COMPONENT_MULTI_SERIES_LINE_CHART,
  A2UI_COMPONENT_MATRIX_HEATMAP
];

function normalizeString(value: string | Object | undefined | null, fallback: string): string {
  if (value === undefined || value === null) {
    return fallback;
  }
  if (typeof value !== 'string') {
    return JSON.stringify(value);
  }
  if (value.length === 0) {
    return fallback;
  }
  return value;
}

function isKnownComponent(value: string): boolean {
  return KNOWN_COMPONENTS.indexOf(value) >= 0;
}

function normalizeStringList(value: string[] | undefined | null): string[] {
  const result: string[] = [];
  if (value === undefined || value === null || !Array.isArray(value)) {
    return result;
  }
  value.forEach((item: string) => {
    if (item.length > 0) {
      result.push(item);
    }
  });
  return result;
}

type ParserJsonValue = Object | string | number | boolean | null | undefined;
type ParserJsonRecord = Record<string, ParserJsonValue>;

function rawListChildren(value: A2uiComponent): ParserJsonRecord | null {
  const source = value as Object as ParserJsonRecord;
  const children = source['children'];
  if (children === undefined || children === null || typeof children !== 'object' || Array.isArray(children)) {
    return null;
  }
  return children as ParserJsonRecord;
}

const UI_LAB_CATALOG_SCHEMA: A2uiComponentCatalogSchema | null =
  A2uiComponentCatalogSchema.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
export type A2uiParserProfile = 'legacy' | 'ui-lab';

function catalogFieldsJson(value: A2uiComponent, component: string, profile: A2uiParserProfile): string {
  const source = value as Object as ParserJsonRecord;
  const needsPresentationFields = component === A2UI_COMPONENT_METRIC_GRID ||
    component === A2UI_COMPONENT_SEGMENTED_RING_CHART ||
    (component === A2UI_COMPONENT_LIST && source['title'] !== undefined) ||
    (component === A2UI_COMPONENT_EXPANDABLE_CARD && source['rows'] !== undefined) ||
    (component === A2UI_COMPONENT_INFO_ROWS &&
      (source['labelPath'] !== undefined || source['valuePath'] !== undefined || source['timePath'] !== undefined));
  if (profile !== 'ui-lab' && !needsPresentationFields) {
    return '';
  }
  if (UI_LAB_CATALOG_SCHEMA === null || !UI_LAB_CATALOG_SCHEMA.has(component) ||
    !UI_LAB_CATALOG_SCHEMA.validatesRuntimeSyntax(component, value as Object)) {
    throw new Error('A2UI UI Lab component does not match catalog schema: ' + component);
  }
  return UI_LAB_CATALOG_SCHEMA.presentationFieldsJson(component, value as Object);
}

function normalizeActions(value: A2uiAction[] | undefined | null): A2uiAction[] {
  const result: A2uiAction[] = [];
  if (value === undefined || value === null || !Array.isArray(value)) {
    return result;
  }
  value.forEach((action: A2uiAction, index: number) => {
    const label = normalizeString(action.label, '');
    let prompt = normalizeString(action.prompt, '');
    const kind = normalizeString(action.kind, 'prompt');
    if (kind !== 'prompt' && kind !== 'client' && kind !== 'input') {
      throw new Error('A2UI action kind is not registered');
    }
    if (prompt.length === 0) {
      prompt = normalizeString(action.id, '');
    }
    if (label.length === 0 || prompt.length === 0) {
      throw new Error('A2UI action requires label and prompt');
    }
    const variant = normalizeString(action.variant, index === 0 ? 'primary' : 'secondary');
    if (variant !== 'primary' && variant !== 'secondary' && variant !== 'danger') {
      throw new Error('A2UI action variant is not registered');
    }
    const normalized: A2uiAction = {
      id: normalizeString(action.id, 'action_' + index.toString()),
      label: label,
      prompt: prompt,
      variant: variant,
      kind: kind
    };
    if (action.args !== undefined && action.args !== null) {
      normalized.args = action.args;
    }
    const sourceSectionId = normalizeString(action.sourceSectionId, '');
    if (sourceSectionId.length > 0) {
      normalized.sourceSectionId = sourceSectionId;
    }
    result.push(normalized);
  });
  return result;
}

function normalizeComponent(value: A2uiComponent, profile: A2uiParserProfile): A2uiComponent {
  const id = normalizeString(value.id, '');
  const component = normalizeString(value.component, '');
  if (id.length === 0 || component.length === 0) {
    throw new Error('A2UI component requires id and component');
  }
  if (!isKnownComponent(component)) {
    throw new Error('A2UI component is not registered: ' + component);
  }
  const presentationFieldsJson = catalogFieldsJson(value, component, profile);
  const listChildren = rawListChildren(value);
  if (component !== A2UI_COMPONENT_LIST && listChildren !== null) {
    throw new Error('A2UI children object is only supported by List');
  }
  let child = normalizeString(value.child, '');
  let children = normalizeStringList(value.children);
  let dataPath = normalizeString(value.dataPath, '');
  if (component === A2UI_COMPONENT_LIST && listChildren !== null) {
    child = normalizeString(listChildren['componentId'] as string | Object | undefined | null, '');
    dataPath = normalizeString(listChildren['path'] as string | Object | undefined | null, '');
    children = [];
    if (child.length === 0 || dataPath.length === 0) {
      throw new Error('A2UI List children requires path and componentId');
    }
  } else if (component === A2UI_COMPONENT_LIST) {
    throw new Error('A2UI List requires official children path and componentId');
  }
  const normalized: A2uiComponent = {
    id: id,
    component: component,
    child: child,
    children: children,
    title: normalizeString(value.title, ''),
    text: normalizeString(value.text, ''),
    body: normalizeString(value.body, ''),
    status: normalizeString(value.status, 'idle'),
    tone: normalizeString(value.tone, ''),
    variant: normalizeString(value.variant, ''),
    path: normalizeString(value.path, ''),
    dataPath: dataPath,
    actions: normalizeActions(value.actions)
  };
  if (presentationFieldsJson.length > 0) {
    normalized.catalogFieldsJson = presentationFieldsJson;
  }
  return normalized;
}

function normalizeEnvelope(value: A2uiEnvelope, profile: A2uiParserProfile): A2uiEnvelope {
  const messageCount =
    (value.createSurface !== undefined && value.createSurface !== null ? 1 : 0) +
    (value.updateComponents !== undefined && value.updateComponents !== null ? 1 : 0) +
    (value.updateDataModel !== undefined && value.updateDataModel !== null ? 1 : 0) +
    (value.deleteSurface !== undefined && value.deleteSurface !== null ? 1 : 0);
  if (messageCount !== 1) {
    throw new Error('A2UI envelope must contain exactly one message');
  }

  if (value.createSurface !== undefined && value.createSurface !== null) {
    const surfaceId = normalizeString(value.createSurface.surfaceId, '');
    if (surfaceId.length === 0) {
      throw new Error('createSurface.surfaceId is required');
    }
    return {
      version: normalizeString(value.version, ''),
      createSurface: {
        surfaceId: surfaceId,
        root: normalizeString(value.createSurface.root, 'root'),
        title: normalizeString(value.createSurface.title, 'AIPhone'),
        intent: normalizeString(value.createSurface.intent, 'general'),
        status: normalizeString(value.createSurface.status, 'thinking'),
        sendDataModel: value.createSurface.sendDataModel === true
      }
    };
  }

  if (value.updateComponents !== undefined && value.updateComponents !== null) {
    const surfaceId = normalizeString(value.updateComponents.surfaceId, '');
    if (surfaceId.length === 0 || value.updateComponents.components === undefined || !Array.isArray(value.updateComponents.components)) {
      throw new Error('updateComponents requires surfaceId and components');
    }
    const components: A2uiComponent[] = [];
    value.updateComponents.components.forEach((component: A2uiComponent) => {
      components.push(normalizeComponent(component, profile));
    });
    return {
      version: normalizeString(value.version, ''),
      updateComponents: {
        surfaceId: surfaceId,
        components: components
      }
    };
  }

  if (value.updateDataModel !== undefined && value.updateDataModel !== null) {
    const surfaceId = normalizeString(value.updateDataModel.surfaceId, '');
    const path = normalizeString(value.updateDataModel.path, '');
    if (surfaceId.length === 0 || path.length === 0) {
      throw new Error('updateDataModel requires surfaceId and path');
    }
    return {
      version: normalizeString(value.version, ''),
      updateDataModel: {
        surfaceId: surfaceId,
        path: path,
        value: value.updateDataModel.value
      }
    };
  }

  const surfaceId = normalizeString(value.deleteSurface?.surfaceId, '');
  if (surfaceId.length === 0) {
    throw new Error('deleteSurface.surfaceId is required');
  }
  return {
    version: normalizeString(value.version, ''),
    deleteSurface: {
      surfaceId: surfaceId
    }
  };
}

export function parseA2uiEnvelope(content: string, profile: A2uiParserProfile = 'legacy'): A2uiEnvelope {
  const parsed = JSON.parse(content) as A2uiEnvelope;
  if (parsed === undefined || parsed === null) {
    throw new Error('A2UI envelope is empty');
  }
  return normalizeEnvelope(parsed, profile);
}

export function parseA2uiJsonlChunk(
  chunk: string,
  previousRemainder: string = '',
  profile: A2uiParserProfile = 'legacy'
): A2uiStreamParseResult {
  const text = previousRemainder + chunk;
  const lines = text.split('\n');
  const hasTrailingNewline = text.endsWith('\n');
  const limit = hasTrailingNewline ? lines.length : lines.length - 1;
  const envelopes: A2uiEnvelope[] = [];
  let error = '';

  for (let index = 0; index < limit; index++) {
    const line = lines[index].trim();
    if (line.length === 0) {
      continue;
    }
    try {
      envelopes.push(parseA2uiEnvelope(line, profile));
    } catch (parseError) {
      error = parseError instanceof Error ? parseError.message : 'invalid A2UI stream line';
      break;
    }
  }

  return {
    envelopes: envelopes,
    remainder: hasTrailingNewline ? '' : lines[lines.length - 1],
    error: error
  };
}

export function parseA2uiJsonl(
  content: string,
  profile: A2uiParserProfile = 'legacy'
): A2uiStreamParseResult {
  const result = parseA2uiJsonlChunk(content.endsWith('\n') ? content : content + '\n', '', profile);
  return {
    envelopes: result.envelopes,
    remainder: '',
    error: result.error
  };
}
