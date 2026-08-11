import {
  A2UI_CATALOG_RESERVED_COMPONENT_FIELDS,
  A2uiComponentCatalogSchema,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';

export type UiAgentLabStatus = 'ready' | 'loading' | 'success' | 'error';

export interface UiAgentLabStatusPayload {
  state: UiAgentLabStatus;
  message: string;
  responseChars: number;
}

export interface UiAgentLabDecisionPayload {
  enabled: boolean;
  text: string;
}

interface UiAgentLabSurfacePayload {
  surface: Object;
  revision: number;
  generation: number;
}

type UiAgentLabDataValue = Object | string | number | boolean | null | undefined;
type UiAgentLabDataRecord = Record<string, UiAgentLabDataValue>;

const UI_AGENT_LAB_CATALOG_SCHEMA: A2uiComponentCatalogSchema | null =
  A2uiComponentCatalogSchema.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON);

function uiAgentLabDataRecord(value: UiAgentLabDataValue): UiAgentLabDataRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as UiAgentLabDataRecord;
}

function decodeUiAgentLabPointerSegment(segment: string): string {
  return segment.split('~1').join('/').split('~0').join('~');
}

export function resolveUiAgentLabDataPath(
  model: UiAgentLabDataValue,
  path: string
): UiAgentLabDataValue {
  if (path.length === 0 || path.charAt(0) !== '/') return undefined;
  if (path === '/') return model;
  const segments = path.substring(1).split('/');
  let current: UiAgentLabDataValue = model;
  for (let index = 0; index < segments.length; index++) {
    const key = decodeUiAgentLabPointerSegment(segments[index]);
    if (Array.isArray(current)) {
      if (!/^(0|[1-9][0-9]*)$/.test(key)) return undefined;
      const values = current as UiAgentLabDataValue[];
      const arrayIndex = Number(key);
      if (arrayIndex >= values.length) return undefined;
      current = values[arrayIndex];
      continue;
    }
    const source = uiAgentLabDataRecord(current);
    if (source === null || Object.keys(source).indexOf(key) < 0) return undefined;
    current = source[key];
  }
  return current;
}

function scriptString(value: string): string {
  let encoded = '"';
  for (let index = 0; index < value.length; index++) {
    encoded += '\\u' + value.charCodeAt(index).toString(16).padStart(4, '0');
  }
  return encoded + '"';
}

export function uiAgentLabStatusScript(payload: UiAgentLabStatusPayload): string {
  const serialized = JSON.stringify(payload);
  return 'window.__applyUiAgentLabStatus(JSON.parse(' + scriptString(serialized) + '));';
}

function boundedUiAgentLabDecisionPayload(payload: UiAgentLabDecisionPayload): UiAgentLabDecisionPayload {
  return {
    enabled: payload.enabled,
    text: payload.text.trim().substring(0, 2400)
  };
}

export function uiAgentLabDecisionScript(payload: UiAgentLabDecisionPayload): string {
  const serialized = JSON.stringify(boundedUiAgentLabDecisionPayload(payload));
  return 'window.__applyUiAgentLabDecision(JSON.parse(' + scriptString(serialized) + '));';
}

export function uiAgentLabSurfaceScript(
  surfaceJson: string,
  revision: number = 0,
  generation: number = 0
): string {
  const payload: UiAgentLabSurfacePayload = {
    surface: JSON.parse(resolveUiAgentLabSurfaceJson(surfaceJson)) as Object,
    revision,
    generation
  };
  return 'window.__applyUiAgentLabSurface(JSON.parse(' +
    scriptString(JSON.stringify(payload)) + '));';
}

export function strictUiAgentLabFiniteNumber(value: UiAgentLabDataValue): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

export function resolveUiAgentLabCatalogFieldsJsonForModel(
  componentName: string,
  presentationFieldsJson: string,
  modelJson: string
): string | null {
  return UI_AGENT_LAB_CATALOG_SCHEMA === null ? null :
    UI_AGENT_LAB_CATALOG_SCHEMA.resolvePresentationFieldsJson(
      componentName,
      presentationFieldsJson,
      modelJson
    );
}

function uiAgentLabListTemplateDescendants(components: UiAgentLabDataValue[]): Set<string> {
  const byId: Map<string, UiAgentLabDataRecord> = new Map<string, UiAgentLabDataRecord>();
  for (let index = 0; index < components.length; index++) {
    const component = uiAgentLabDataRecord(components[index]);
    if (component !== null && typeof component['id'] === 'string') {
      byId.set(component['id'] as string, component);
    }
  }
  const descendants: Set<string> = new Set<string>();
  byId.forEach((component: UiAgentLabDataRecord) => {
    if (component['component'] !== 'List' || typeof component['child'] !== 'string') return;
    const queue: string[] = [component['child'] as string];
    while (queue.length > 0) {
      const id = queue.shift();
      if (id === undefined || descendants.has(id)) continue;
      descendants.add(id);
      const child = byId.get(id);
      if (child === undefined) continue;
      if (typeof child['child'] === 'string') queue.push(child['child'] as string);
      if (Array.isArray(child['children'])) {
        const childIds = child['children'] as UiAgentLabDataValue[];
        for (let index = 0; index < childIds.length; index++) {
          if (typeof childIds[index] === 'string') queue.push(childIds[index] as string);
        }
      }
    }
  });
  return descendants;
}

export function resolveUiAgentLabSurfaceJson(surfaceJson: string): string {
  if (UI_AGENT_LAB_CATALOG_SCHEMA === null) {
    return surfaceJson;
  }
  try {
    const surface = uiAgentLabDataRecord(JSON.parse(surfaceJson) as Object);
    if (surface === null || !Array.isArray(surface['components']) ||
      typeof surface['dataModelJson'] !== 'string') {
      return surfaceJson;
    }
    const components = surface['components'] as UiAgentLabDataValue[];
    const itemScopedIds = uiAgentLabListTemplateDescendants(components);
    const modelJson = surface['dataModelJson'] as string;
    for (let index = 0; index < components.length; index++) {
      const component = uiAgentLabDataRecord(components[index]);
      if (component === null || typeof component['component'] !== 'string' ||
        typeof component['catalogFieldsJson'] !== 'string' ||
        (component['catalogFieldsJson'] as string).length === 0) {
        continue;
      }
      if (typeof component['id'] === 'string' && itemScopedIds.has(component['id'] as string)) {
        continue;
      }
      const resolvedJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        component['component'] as string,
        component['catalogFieldsJson'] as string,
        modelJson
      );
      if (resolvedJson === null) {
        continue;
      }
      const resolved = uiAgentLabDataRecord(JSON.parse(resolvedJson) as Object);
      if (resolved === null) {
        continue;
      }
      const keys = Object.keys(resolved);
      for (let keyIndex = 0; keyIndex < keys.length; keyIndex++) {
        component[keys[keyIndex]] = resolved[keys[keyIndex]];
      }
      component['catalogFieldsJson'] = undefined;
    }
    return JSON.stringify(surface);
  } catch (_error) {
    return surfaceJson;
  }
}

export function createUiAgentLabHtmlShell(): string {
  return `<!doctype html>
<html lang="zh-CN" data-theme="warm">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no" />
  <style>
    :root { color-scheme:light; }
    :root,:root[data-theme="warm"] {
      --page:#f1ece5; --canvas:#f7f4ef; --surface:#fffdf9; --surface-raised:#ffffff; --surface-inset:#f4eee7;
      --ink:#241e1a; --text:#4b423c; --muted:#756c66; --label:#8b8178; --subtle:#9a9088; --hairline:#e4ddd5;
      --cobalt:#94614d; --cobalt-deep:#744637; --cobalt-soft:#f2e5df; --on-accent:#fffaf7;
      --accent-border:rgba(148,97,77,.18); --accent-shadow:rgba(116,70,55,.24);
      --success:#2f7754; --success-soft:#e4f1e8; --warning:#a36a36; --warning-soft:#f8e9db; --error:#a94d45; --error-soft:#f7e5e1;
      --purple:#765fba; --purple-soft:#eee9fb; --mint:#62ad99; --mint-soft:rgba(111,205,186,.18); --peach:#bc7148; --peach-soft:rgba(246,184,144,.22); --blue-soft:rgba(85,118,255,.12);
      --regular-glass:rgba(255,253,249,.82); --clear-glass:rgba(255,253,249,.42); --control-fill:rgba(255,255,255,.78);
      --card-fill:rgba(255,255,255,.66); --card-fill-strong:rgba(255,255,255,.78); --card-fill-soft:rgba(255,255,255,.42);
      --edge-strong:rgba(255,255,255,.90); --edge-medium:rgba(255,255,255,.80); --edge-soft:rgba(255,255,255,.70); --glass-highlight:rgba(255,255,255,.48); --hover-fill:rgba(36,30,26,.05);
      --ambient-one:#dec5ad; --ambient-two:#efd1b8; --ambient-three:#c9d9c5;
      --hero-start:rgba(255,251,245,.96); --hero-end:rgba(237,223,210,.86); --hero-kicker:#94614d; --hero-title:#33271f; --hero-body:#74665c; --hero-orbit:rgba(148,97,77,.08);
      --skeleton:#e2d9d0; --skeleton-shimmer:rgba(255,255,255,.52); --thumbnail-base:#e5ddd5; --thumbnail-blue:#8ba3ec; --thumbnail-peach:#f4b58e; --thumbnail-mint:#68c8b5; --media-base:#ddd8d2;
      --toast-bg:#2b2521; --toast-fg:#fffaf5; --toast-shadow:rgba(33,27,23,.20);
      --chart-track:#eee7df; --chart-1:#eee8e2; --chart-2:#dce7fb; --chart-3:#bcd0f3; --chart-4:#8eade2; --chart-5:#6689c8; --chart-6:#4568a7; --chart-grid:rgba(111,103,98,.14);
      --series-1:#5576ff; --series-2:#f0a16f; --series-3:#6fcdba; --series-4:#8d79e7;
      --avatar-start:#6f88f9; --avatar-end:#8c6cd9; --avatar-shadow:rgba(85,94,190,.20);
      --day-one-bg:#fee2d3; --day-one-fg:#9d4e27; --day-two-bg:#f0e4df; --day-two-fg:#845140;
      --placeholder:#928983; --focus-ring:rgba(148,97,77,.30);
      --device-shadow:0 22px 52px rgba(61,49,41,.12); --surface-shadow:0 12px 26px rgba(61,49,41,.055); --shadow-soft:0 14px 32px rgba(61,49,41,.08);
      --button-shadow:0 10px 22px rgba(116,70,55,.24); --control-shadow:0 2px 6px rgba(38,30,24,.16); --focus-subtle:rgba(94,89,85,.42);
    }
    :root[data-theme="cool"] {
      --page:#e7e9ee; --canvas:#eef1f5; --surface:#fbfcff; --surface-raised:#ffffff; --surface-inset:#e9eef6;
      --ink:#20242b; --text:#444a55; --muted:#747985; --label:#858b97; --subtle:#969ca7; --hairline:#dce1e9;
      --cobalt:#3976f6; --cobalt-deep:#2259c7; --cobalt-soft:#e4edff; --on-accent:#ffffff;
      --accent-border:rgba(57,118,246,.18); --accent-shadow:rgba(42,101,230,.24);
      --success:#2e9874; --success-soft:#e2f4ee; --warning:#b56d42; --warning-soft:#fff0e5; --error:#a64040; --error-soft:#ffefec;
      --purple:#6d5ee8; --purple-soft:#eeeaff; --mint:#4cae96; --mint-soft:rgba(111,205,186,.17); --peach:#bd7247; --peach-soft:rgba(246,184,144,.18); --blue-soft:rgba(85,118,255,.14);
      --regular-glass:rgba(249,251,255,.74); --clear-glass:rgba(249,251,255,.36); --control-fill:rgba(255,255,255,.78);
      --card-fill:rgba(255,255,255,.65); --card-fill-strong:rgba(255,255,255,.76); --card-fill-soft:rgba(255,255,255,.42);
      --edge-strong:rgba(255,255,255,.90); --edge-medium:rgba(255,255,255,.80); --edge-soft:rgba(255,255,255,.70); --glass-highlight:rgba(255,255,255,.48); --hover-fill:rgba(32,36,43,.05);
      --ambient-one:#9fc2ff; --ambient-two:#ffc3aa; --ambient-three:#9de1c7;
      --hero-start:rgba(54,93,166,.96); --hero-end:rgba(42,54,82,.94); --hero-kicker:#c9d9ff; --hero-title:#ffffff; --hero-body:#dde6f7; --hero-orbit:rgba(157,188,244,.14);
      --skeleton:#dfe3e8; --skeleton-shimmer:rgba(255,255,255,.58); --thumbnail-base:#d9dff2; --thumbnail-blue:#8ba3ec; --thumbnail-peach:#f4b58e; --thumbnail-mint:#68c8b5; --media-base:#dfe3e8;
      --toast-bg:#252a33; --toast-fg:#f8faff; --toast-shadow:rgba(27,34,46,.22);
      --chart-track:#edf0f4; --chart-1:#d9dee6; --chart-2:#c7d7f0; --chart-3:#a8c3eb; --chart-4:#7da5df; --chart-5:#527fd0; --chart-6:#315eae; --chart-grid:rgba(72,82,98,.14);
      --series-1:#3976f6; --series-2:#70c8b5; --series-3:#f1a078; --series-4:#7b68d9;
      --avatar-start:#6f88f9; --avatar-end:#8c6cd9; --avatar-shadow:rgba(85,94,190,.20);
      --day-one-bg:#fee2d3; --day-one-fg:#9d4e27; --day-two-bg:#e1e6ff; --day-two-fg:#4565da;
      --placeholder:#8e929a; --focus-ring:rgba(57,118,246,.30);
      --device-shadow:0 22px 52px rgba(46,56,72,.14); --surface-shadow:0 12px 26px rgba(46,56,72,.07); --shadow-soft:0 14px 32px rgba(46,56,72,.10);
      --button-shadow:0 10px 22px rgba(42,101,230,.24); --control-shadow:0 2px 6px rgba(38,46,60,.16); --focus-subtle:rgba(57,118,246,.38);
    }
    * { box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
    .sr-only { position:absolute!important; width:1px!important; height:1px!important; padding:0!important; margin:-1px!important; overflow:hidden!important; clip:rect(0,0,0,0)!important; white-space:nowrap!important; border:0!important; }
    html,body { width:100%; height:100%; margin:0; overflow:hidden; font-family:HarmonyOS Sans SC,system-ui,sans-serif; color:var(--ink); }
    body { background:var(--page); }
    button,input { font:inherit; }
    .ambient { position:fixed; inset:0; overflow:hidden; pointer-events:none; }
    .blob { position:absolute; border-radius:999px; filter:blur(48px); opacity:.58; }
    .blob.blue { width:62vw; height:34vh; left:-18vw; top:-8vh; background:var(--ambient-one); }
    .blob.peach { width:58vw; height:40vh; right:-22vw; top:18vh; background:var(--ambient-two); }
    .blob.mint { width:64vw; height:35vh; left:12vw; bottom:-16vh; background:var(--ambient-three); }
    .shell { position:relative; z-index:1; height:100%; padding:calc(14px + env(safe-area-inset-top,0px)) 14px calc(18px + env(safe-area-inset-bottom,0px)); display:grid; grid-template-rows:auto minmax(0,1fr) auto; gap:0; }
    .shell.decision-notes-visible { grid-template-rows:auto minmax(0,auto) minmax(0,1fr) auto; }
    [hidden] { display:none!important; }
    .glass { background:linear-gradient(135deg,var(--regular-glass),var(--clear-glass)); border:1px solid var(--edge-strong); box-shadow:var(--device-shadow),inset 0 1px 0 var(--glass-highlight); backdrop-filter:blur(22px) saturate(1.14); -webkit-backdrop-filter:blur(22px) saturate(1.14); }
    .lab-header { min-height:52px; margin-bottom:12px; border-radius:999px; display:flex; align-items:center; padding:6px 12px 6px 6px; }
    .back { width:38px; height:38px; border:0; border-radius:50%; background:var(--control-fill); color:var(--ink); font-size:20px; cursor:pointer; box-shadow:inset 0 0 0 1px var(--edge-medium); }
    .title { flex:1 1 auto; margin-left:12px; min-width:0; }
    .title h1 { margin:0; font-size:21px; letter-spacing:-.02em; }
    .title p { margin:3px 0 0; color:var(--muted); font-size:12px; }
    .decision-toggle,.theme-toggle { width:38px; height:38px; flex:0 0 38px; margin-left:8px; border:0; border-radius:50%; background:var(--control-fill); color:var(--text); cursor:pointer; box-shadow:inset 0 0 0 1px var(--edge-medium); display:flex; align-items:center; justify-content:center; }
    .decision-toggle svg,.theme-toggle svg,.send svg { width:19px; height:19px; display:block; fill:currentColor; }
    .decision-toggle[aria-pressed="true"] { color:var(--on-accent); background:linear-gradient(145deg,var(--cobalt),var(--cobalt-deep)); box-shadow:var(--button-shadow),inset 0 1px 0 var(--glass-highlight); }
    .theme-toggle { color:var(--cobalt); }
    .decision-toggle:disabled { opacity:.45; box-shadow:none; cursor:default; }
    .decision-panel { min-height:0; max-height:min(34vh,260px); margin-bottom:12px; border-radius:24px; padding:14px 15px; overflow:auto; overscroll-behavior:contain; }
    .decision-panel-header { display:flex; align-items:center; justify-content:space-between; gap:12px; margin-bottom:11px; }
    .decision-panel-title { margin:0; font-size:14px; }
    .decision-panel-badge { border-radius:999px; padding:4px 8px; color:var(--cobalt); background:var(--cobalt-soft); font-size:10px; }
    .decision-copy { margin:0; color:var(--text); font-size:12px; line-height:1.65; white-space:pre-wrap; overflow-wrap:anywhere; }
    .surface-viewport { min-height:0; border-radius:30px; overflow:auto; overscroll-behavior:contain; padding:18px; text-align:left; }
    .surface-root,.lab-column { width:100%; display:flex; flex-direction:column; gap:12px; }
    .lab-list { display:flex; flex-direction:column; gap:10px; min-width:0; }
    .lab-list+.lab-list { padding-top:11px; border-top:1px solid var(--hairline); }
    .lab-list-title { margin:0; color:var(--ink); font-size:15px; line-height:1.35; overflow-wrap:anywhere; }
    .lab-list-items { display:flex; flex-direction:column; min-width:0; }
    .lab-list-row { min-width:0; padding:11px 0; border-bottom:1px solid var(--hairline); }
    .lab-list-row:first-child { padding-top:0; }
    .lab-list-row:last-child { padding-bottom:0; border-bottom:0; }
    .list-pager { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:2px 4px 0; }
    .list-page-status { color:var(--muted); font-size:12px; }
    .list-more { min-height:34px; border:0; border-radius:999px; padding:0 14px; color:var(--on-accent); background:linear-gradient(145deg,var(--cobalt),var(--cobalt-deep)); }
    .list-more:disabled { color:var(--muted); background:var(--card-fill-soft); box-shadow:inset 0 0 0 1px var(--hairline); }
    .lab-row { width:100%; display:flex; gap:10px; align-items:stretch; overflow-x:auto; }
    .lab-row>* { min-width:0; flex:1 1 0; }
    .empty { min-height:100%; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding:28px; }
    .empty strong { display:block; font-size:17px; margin-bottom:8px; }
    .empty span { color:var(--muted); font-size:13px; line-height:1.6; }
    .lab-text { margin:0; white-space:pre-wrap; overflow-wrap:anywhere; color:var(--ink); font-size:15px; line-height:1.55; }
    .lab-text-title { display:block; margin-bottom:3px; color:var(--muted); font-size:11px; line-height:1.35; }
    .lab-text-body { display:block; }
    .lab-card { border-radius:22px; padding:16px; background:var(--card-fill); border:1px solid var(--edge-medium); box-shadow:var(--surface-shadow); }
    .lab-card-title { margin:0 0 7px; font-size:15px; line-height:1.35; }
    .lab-card-copy { margin:0; color:var(--muted); font-size:13px; line-height:1.55; white-space:pre-wrap; overflow-wrap:anywhere; }
    .info-rows { display:flex; flex-direction:column; gap:9px; }
    .info-row { display:grid; grid-template-columns:minmax(72px,.72fr) minmax(0,1.28fr); gap:12px; padding-bottom:9px; border-bottom:1px solid var(--hairline); }
    .info-row:last-child { border-bottom:0; padding-bottom:0; }
    .info-label { color:var(--muted); font-size:12px; }
    .info-value { font-size:13px; text-align:right; overflow-wrap:anywhere; }
    .info-time { grid-column:2; margin-top:-7px; color:var(--muted); font-size:11px; text-align:right; overflow-wrap:anywhere; }
    .action-bar { display:flex; flex-wrap:wrap; gap:9px; }
    .action-button { min-height:42px; flex:1 1 120px; border:0; border-radius:16px; padding:0 14px; background:linear-gradient(145deg,var(--cobalt),var(--cobalt-deep)); color:var(--on-accent); box-shadow:var(--button-shadow); }
    .action-button.secondary { color:var(--ink); background:var(--card-fill-strong); box-shadow:inset 0 0 0 1px var(--hairline); }
    .error-card { border-color:var(--error); background:var(--error-soft); }
    .error-card .lab-card-title { color:var(--error); }
    .thinking-card { position:relative; overflow:hidden; }
    .thinking-card:after { content:""; position:absolute; inset:0; transform:translateX(-110%); background:linear-gradient(90deg,transparent,var(--skeleton-shimmer),transparent); animation:shimmer 1.7s infinite; pointer-events:none; }
    @keyframes shimmer { to { transform:translateX(110%); } }
    .progress-track { height:7px; margin:11px 0; overflow:hidden; border-radius:999px; background:var(--hover-fill); }
    .progress-fill { height:100%; border-radius:inherit; background:linear-gradient(90deg,var(--cobalt),var(--mint)); }
    .event-list { list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:11px; }
    .event-item { display:grid; grid-template-columns:10px 1fr; gap:10px; align-items:start; color:var(--muted); font-size:12px; }
    .event-dot { width:8px; height:8px; margin-top:5px; border-radius:50%; background:var(--mint); box-shadow:0 0 0 4px var(--mint-soft); }
    .schedule-stack { display:flex; flex-direction:column; gap:11px; }
    .schedule-card { border-radius:20px; padding:15px; background:linear-gradient(145deg,var(--card-fill-strong),var(--clear-glass)); border:1px solid var(--edge-medium); }
    .schedule-chip { display:inline-flex; border-radius:999px; padding:5px 9px; background:var(--cobalt-soft); color:var(--cobalt); font-size:10px; font-weight:700; letter-spacing:.08em; }
    .schedule-card h3 { margin:10px 0 5px; font-size:16px; }
    .schedule-card p { margin:0 0 9px; color:var(--muted); font-size:12px; }
    .schedule-event { display:flex; gap:10px; padding:7px 0; border-top:1px solid var(--hairline); font-size:12px; }
    .schedule-event time { flex:0 0 46px; color:var(--muted); }
    .skeleton-card { display:grid; grid-template-columns:58px 1fr; gap:13px; align-items:center; }
    .skeleton-media,.skeleton-bar { display:block; border-radius:12px; background:linear-gradient(90deg,var(--skeleton),var(--skeleton-shimmer),var(--skeleton)); background-size:220% 100%; animation:skeleton 1.45s infinite; }
    .skeleton-media { width:58px; height:58px; }
    .skeleton-copy { display:flex; flex-direction:column; gap:8px; }
    .skeleton-bar { height:10px; }
    .skeleton-bar.short { width:58%; }
    @keyframes skeleton { to { background-position:-220% 0; } }
    .expandable-trigger { width:100%; border:0; background:transparent; color:var(--ink); padding:0; display:flex; align-items:center; justify-content:space-between; text-align:left; }
    .expandable-trigger span:last-child { font-size:22px; transition:transform .32s cubic-bezier(.22,1,.36,1); }
    .expandable-card.is-open .expandable-trigger span:last-child { transform:rotate(45deg); }
    .expandable-panel { display:grid; grid-template-rows:0fr; opacity:0; transform:translateY(-6px); transition:grid-template-rows .34s cubic-bezier(.22,1,.36,1),opacity .22s cubic-bezier(.22,1,.36,1),transform .34s cubic-bezier(.22,1,.36,1); }
    .expandable-panel-inner { min-height:0; overflow:hidden; margin-top:0; padding-top:0; border-top:1px solid transparent; transition:margin-top .34s cubic-bezier(.22,1,.36,1),padding-top .34s cubic-bezier(.22,1,.36,1),border-color .22s cubic-bezier(.22,1,.36,1); }
    .expandable-card.is-open .expandable-panel { grid-template-rows:1fr; opacity:1; transform:translateY(0); }
    .expandable-card.is-open .expandable-panel-inner { margin-top:12px; padding-top:12px; border-color:var(--hairline); }
    .expandable-data { display:flex; flex-direction:column; gap:9px; min-width:0; }
    .expandable-data+.expandable-data,.expandable-data>.expandable-data { margin-top:4px; }
    .expandable-data-title { margin:0; color:var(--ink); font-size:13px; line-height:1.4; overflow-wrap:anywhere; }
    .expandable-item { padding:10px 0 0; border-top:1px solid var(--hairline); }
    .expandable-item:first-child { padding-top:0; border-top:0; }
    .expandable-field { display:grid; grid-template-columns:minmax(72px,.72fr) minmax(0,1.28fr); gap:12px; }
    .expandable-field-label { color:var(--muted); font-size:12px; overflow-wrap:anywhere; }
    .expandable-field-value { font-size:13px; text-align:right; white-space:pre-wrap; overflow-wrap:anywhere; }
    .expandable-limit { color:var(--muted); font-size:11px; line-height:1.45; }
    .hero-banner { position:relative; overflow:hidden; min-height:132px; border-radius:25px; padding:22px; display:flex; flex-direction:column; justify-content:flex-end; background:linear-gradient(145deg,var(--hero-start),var(--hero-end)); color:var(--hero-title); box-shadow:var(--shadow-soft); }
    .hero-banner:after { content:""; position:absolute; width:150px; height:150px; right:-46px; top:-68px; border-radius:50%; border:25px solid var(--hero-orbit); }
    .hero-kicker { position:relative; z-index:1; margin:0 0 6px; color:var(--hero-kicker); font-size:11px; font-weight:700; letter-spacing:.08em; }
    .hero-title { position:relative; z-index:1; margin:0; max-width:88%; font-size:24px; line-height:1.15; letter-spacing:-.025em; overflow-wrap:anywhere; }
    .hero-body { position:relative; z-index:1; margin:8px 0 0; max-width:92%; color:var(--hero-body); font-size:12px; line-height:1.5; white-space:pre-wrap; overflow-wrap:anywhere; }
    .viz-card { min-width:0; }
    .viz-header { margin-bottom:13px; }
    .viz-kicker { margin:0 0 4px; color:var(--cobalt); font-size:10px; font-weight:700; letter-spacing:.07em; }
    .viz-header .lab-card-copy { margin-top:4px; }
    .metric-grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:9px; }
    .metric-item { min-width:0; border-radius:17px; padding:13px; background:var(--surface-inset); }
    .metric-label { display:block; color:var(--muted); font-size:11px; line-height:1.35; overflow-wrap:anywhere; }
    .metric-value { display:block; margin-top:6px; font-size:21px; line-height:1.1; letter-spacing:-.03em; overflow-wrap:anywhere; }
    .metric-unit { margin-left:4px; color:var(--muted); font-size:11px; font-weight:500; letter-spacing:0; }
    .metric-delta { display:block; margin-top:6px; color:var(--muted); font-size:10px; }
    .metric-delta.is-positive { color:var(--success); }
    .metric-delta.is-negative { color:var(--error); }
    .ring-layout { display:grid; grid-template-columns:minmax(118px,.8fr) minmax(0,1.2fr); gap:14px; align-items:center; }
    .ring-svg { display:block; width:100%; max-width:156px; margin:auto; overflow:visible; }
    .ring-center-value { fill:var(--ink); font-size:15px; font-weight:700; text-anchor:middle; }
    .ring-center-label,.ring-center-unit { fill:var(--muted); font-size:7px; text-anchor:middle; }
    .chart-legend { display:flex; flex-direction:column; gap:8px; min-width:0; }
    .legend-item { display:grid; grid-template-columns:9px minmax(0,1fr) auto; gap:7px; align-items:center; min-width:0; font-size:11px; }
    .legend-swatch { width:9px; height:9px; border-radius:50%; }
    .legend-label { min-width:0; color:var(--muted); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
    .legend-value { color:var(--ink); font-variant-numeric:tabular-nums; }
    .line-svg { display:block; width:100%; height:auto; overflow:visible; }
    .line-grid { stroke:var(--chart-grid); stroke-width:1; }
    .line-series { fill:none; stroke-width:2.5; stroke-linecap:round; stroke-linejoin:round; }
    .line-labels { display:flex; justify-content:space-between; gap:6px; margin:4px 7px 0 20px; color:var(--muted); font-size:9px; }
    .line-legend { display:flex; flex-wrap:wrap; gap:7px 12px; margin-top:10px; }
    .line-legend .legend-item { display:flex; flex:0 1 auto; }
    .heatmap-layout { display:grid; grid-template-columns:auto minmax(0,1fr); gap:5px; align-items:stretch; }
    .heatmap-row-labels { display:grid; gap:3px; color:var(--muted); font-size:9px; text-align:right; }
    .heatmap-row-label { min-height:0; display:flex; align-items:center; justify-content:flex-end; white-space:nowrap; }
    .heatmap-main { min-width:0; }
    .heatmap-column-labels,.heatmap-grid { display:grid; gap:3px; }
    .heatmap-column-labels { margin-bottom:4px; color:var(--muted); font-size:8px; text-align:center; }
    .heatmap-column-label { overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
    .heatmap-cell { width:100%; aspect-ratio:1/1; border-radius:3px; background:var(--chart-1); }
    .heatmap-scale { display:flex; justify-content:flex-end; gap:3px; margin-top:8px; }
    .heatmap-scale span { width:10px; height:10px; border-radius:3px; }
    @media (max-width:360px) { .ring-layout { grid-template-columns:112px minmax(0,1fr); gap:10px; } .hero-title { font-size:21px; } .decision-panel { max-height:30vh; } }
    .media-slider { display:flex; gap:11px; overflow-x:auto; scroll-snap-type:x mandatory; padding-bottom:3px; }
    .media-card { min-width:76%; scroll-snap-align:start; border:0; border-radius:20px; padding:0; overflow:hidden; text-align:left; color:var(--ink); background:var(--card-fill); }
    .media-frame { height:112px; display:flex; align-items:center; justify-content:center; background:linear-gradient(135deg,var(--thumbnail-blue),var(--thumbnail-peach) 52%,var(--thumbnail-mint)); color:var(--text); font-size:11px; letter-spacing:.08em; }
    .media-title { display:block; padding:12px 13px 14px; font-size:13px; font-weight:650; }
    .scene-tabs { display:flex; gap:8px; margin-bottom:10px; }
    .scene-tab { flex:1; min-height:38px; border:0; border-radius:14px; background:var(--card-fill-soft); color:var(--muted); font-size:12px; }
    .scene-tab.is-active { background:var(--cobalt); color:var(--on-accent); }
    .scene-panel { display:none; }
    .scene-panel.is-active { display:block; }
    .scene-metrics { display:flex; flex-wrap:wrap; gap:7px; margin-top:10px; }
    .scene-metric { border-radius:999px; padding:6px 9px; background:var(--mint-soft); color:var(--success); font-size:11px; }
    .masonry-grid { columns:2; column-gap:10px; }
    .masonry-card { break-inside:avoid; margin:0 0 10px; border-radius:19px; padding:14px; background:var(--card-fill); border:1px solid var(--edge-soft); }
    .masonry-card:nth-child(3n+1) { background:var(--mint-soft); }
    .masonry-card:nth-child(3n+2) { background:var(--peach-soft); }
    .masonry-card:nth-child(3n) { background:var(--blue-soft); }
    .masonry-card.tone-mint { background:var(--mint-soft); }
    .masonry-card.tone-peach { background:var(--peach-soft); }
    .masonry-card.tone-blue { background:var(--blue-soft); }
    .masonry-card.is-tall { min-height:150px; }
    .composer { border-radius:999px; padding:6px 6px 6px 16px; display:flex; align-items:center; gap:10px; }
    .composer input { min-width:0; flex:1; height:38px; border:0; outline:0; background:transparent; color:var(--ink); font-size:15px; }
    .composer input::placeholder { color:var(--placeholder); }
    .send { width:40px; height:40px; flex:0 0 40px; display:grid; place-items:center; border:0; border-radius:50%; background:linear-gradient(145deg,var(--cobalt),var(--cobalt-deep)); color:var(--on-accent); cursor:pointer; box-shadow:var(--button-shadow),inset 0 1px 0 var(--glass-highlight); }
    .send svg { width:20px; height:20px; display:block; fill:currentColor; }
    .send:disabled { opacity:.48; box-shadow:none; }
    .status { min-height:24px; padding:4px 8px; color:var(--muted); font-size:11px; line-height:16px; display:flex; justify-content:space-between; align-items:center; }
    .status>span { min-height:16px; display:flex; align-items:center; }
    .status[data-state="success"] { color:var(--success); }
    .status[data-state="error"] { color:var(--error); }
    .toast { position:fixed; z-index:5; left:50%; bottom:calc(92px + env(safe-area-inset-bottom,0px)); max-width:calc(100% - 48px); transform:translate(-50%,16px); opacity:0; pointer-events:none; border-radius:999px; padding:10px 15px; background:var(--toast-bg); color:var(--toast-fg); box-shadow:0 10px 28px var(--toast-shadow); font-size:12px; transition:opacity .18s ease,transform .18s ease; }
    .toast.is-visible { opacity:1; transform:translate(-50%,0); }
  </style>
</head>
<body>
  <div class="ambient"><i class="blob blue"></i><i class="blob peach"></i><i class="blob mint"></i></div>
  <div class="shell">
    <header class="lab-header glass">
      <button id="back" class="back" type="button" aria-label="返回设置">&#8249;</button>
      <div class="title"><h1>UI Lab</h1><p>POCKETAGENT</p></div>
      <button id="decisionToggle" class="decision-toggle" type="button" aria-label="显示 UI 决策说明" aria-pressed="false" title="UI 决策说明"><svg viewBox="0 0 256 256" aria-hidden="true"><path d="M128,80a48,48,0,1,0,48,48A48.05,48.05,0,0,0,128,80Zm0,80a32,32,0,1,1,32-32A32,32,0,0,1,128,160Zm88-29.84q.06-2.16,0-4.32l14.92-18.64a8,8,0,0,0,1.48-7.06,107.21,107.21,0,0,0-10.88-26.25,8,8,0,0,0-6-3.93l-23.72-2.64q-1.48-1.56-3-3L186,40.54a8,8,0,0,0-3.94-6,107.71,107.71,0,0,0-26.25-10.87,8,8,0,0,0-7.06,1.49L130.16,40Q128,40,125.84,40L107.2,25.11a8,8,0,0,0-7.06-1.48A107.6,107.6,0,0,0,73.89,34.51a8,8,0,0,0-3.93,6L67.32,64.27q-1.56,1.49-3,3L40.54,70a8,8,0,0,0-6,3.94,107.71,107.71,0,0,0-10.87,26.25,8,8,0,0,0,1.49,7.06L40,125.84Q40,128,40,130.16L25.11,148.8a8,8,0,0,0-1.48,7.06,107.21,107.21,0,0,0,10.88,26.25,8,8,0,0,0,6,3.93l23.72,2.64q1.49,1.56,3,3L70,215.46a8,8,0,0,0,3.94,6,107.71,107.71,0,0,0,26.25,10.87,8,8,0,0,0,7.06-1.49L125.84,216q2.16.06,4.32,0l18.64,14.92a8,8,0,0,0,7.06,1.48,107.21,107.21,0,0,0,26.25-10.88,8,8,0,0,0,3.93-6l2.64-23.72q1.56-1.48,3-3L215.46,186a8,8,0,0,0,6-3.94,107.71,107.71,0,0,0,10.87-26.25,8,8,0,0,0-1.49-7.06Zm-16.1-6.5a73.93,73.93,0,0,1,0,8.68,8,8,0,0,0,1.74,5.48l14.19,17.73a91.57,91.57,0,0,1-6.23,15L187,173.11a8,8,0,0,0-5.1,2.64,74.11,74.11,0,0,1-6.14,6.14,8,8,0,0,0-2.64,5.1l-2.51,22.58a91.32,91.32,0,0,1-15,6.23l-17.74-14.19a8,8,0,0,0-5-1.75h-.48a73.93,73.93,0,0,1-8.68,0,8,8,0,0,0-5.48,1.74L100.45,215.8a91.57,91.57,0,0,1-15-6.23L82.89,187a8,8,0,0,0-2.64-5.1,74.11,74.11,0,0,1-6.14-6.14,8,8,0,0,0-5.1-2.64L46.43,170.6a91.32,91.32,0,0,1-6.23-15l14.19-17.74a8,8,0,0,0,1.74-5.48,73.93,73.93,0,0,1,0-8.68,8,8,0,0,0-1.74-5.48L40.2,100.45a91.57,91.57,0,0,1,6.23-15L69,82.89a8,8,0,0,0,5.1-2.64,74.11,74.11,0,0,1,6.14-6.14A8,8,0,0,0,82.89,69L85.4,46.43a91.32,91.32,0,0,1,15-6.23l17.74,14.19a8,8,0,0,0,5.48,1.74,73.93,73.93,0,0,1,8.68,0,8,8,0,0,0,5.48-1.74L155.55,40.2a91.57,91.57,0,0,1,15,6.23L173.11,69a8,8,0,0,0,2.64,5.1,74.11,74.11,0,0,1,6.14,6.14,8,8,0,0,0,5.1,2.64l22.58,2.51a91.32,91.32,0,0,1,6.23,15l-14.19,17.74A8,8,0,0,0,199.87,123.66Z" /></svg></button>
      <button id="themeToggle" class="theme-toggle" type="button" aria-label="启用现代冷色主题" aria-pressed="false" title="切换界面主题"><svg viewBox="0 0 256 256" aria-hidden="true"><path d="M48,64a8,8,0,0,1,8-8H72V40a8,8,0,0,1,16,0V56h16a8,8,0,0,1,0,16H88V88a8,8,0,0,1-16,0V72H56A8,8,0,0,1,48,64ZM184,192h-8v-8a8,8,0,0,0-16,0v8h-8a8,8,0,0,0,0,16h8v8a8,8,0,0,0,16,0v-8h8a8,8,0,0,0,0-16Zm56-48H224V128a8,8,0,0,0-16,0v16H192a8,8,0,0,0,0,16h16v16a8,8,0,0,0,16,0V160h16a8,8,0,0,0,0-16ZM219.31,80,80,219.31a16,16,0,0,1-22.62,0L36.68,198.63a16,16,0,0,1,0-22.63L176,36.69a16,16,0,0,1,22.63,0l20.68,20.68A16,16,0,0,1,219.31,80Zm-54.63,32L144,91.31l-96,96L68.68,208ZM208,68.69,187.31,48l-32,32L176,100.69Z" /></svg></button>
    </header>
    <aside id="decisionPanel" class="decision-panel glass" aria-label="UI 决策说明" hidden>
      <div class="decision-panel-header"><h2 class="decision-panel-title">UI 决策说明</h2><span class="decision-panel-badge">有限摘要</span></div>
      <p id="decisionText" class="decision-copy"></p>
    </aside>
    <main class="surface-viewport glass" id="surface"><div class="empty"><strong>实验 Surface</strong><span>等待 UI Agent 生成 Lab 组件</span></div></main>
    <section>
      <div id="status" class="status" data-state="ready"><span id="statusText">模型已就绪</span><span id="responseMeta"></span></div>
      <form id="composer" class="composer glass"><input id="prompt" maxlength="4000" autocomplete="off" placeholder="输入提示词，与真实模型对话" /><button id="send" class="send" type="submit" aria-label="发送"><svg viewBox="0 0 256 256" aria-hidden="true"><path d="M205.66,117.66a8,8,0,0,1-11.32,0L136,59.31V216a8,8,0,0,1-16,0V59.31L61.66,117.66a8,8,0,0,1-11.32-11.32l72-72a8,8,0,0,1,11.32,0l72,72A8,8,0,0,1,205.66,117.66Z" /></svg></button></form>
    </section>
  </div>
  <div id="toast" class="toast" role="status" aria-live="polite"></div>
  <script>
    (function(){
      'use strict';
      var UI_AGENT_LAB_COMPONENT_REGISTRY = Object.create(null);
      var UI_AGENT_LAB_COMPONENT_CATALOG = ${UI_AGENT_LAB_COMPONENT_CATALOG_JSON};
      var UI_AGENT_LAB_SCHEMA_BY_NAME = Object.create(null);
      UI_AGENT_LAB_COMPONENT_CATALOG.forEach(function(entry){
        if(entry&&typeof entry.name==='string'&&record(entry.schema))UI_AGENT_LAB_SCHEMA_BY_NAME[entry.name]=entry.schema;
      });
      var UI_AGENT_LAB_RESERVED_FIELDS = ${JSON.stringify(A2UI_CATALOG_RESERVED_COMPONENT_FIELDS)};
      var shell=document.querySelector('.shell'),surfaceHost=document.getElementById('surface');
      var decisionToggle=document.getElementById('decisionToggle'),themeToggle=document.getElementById('themeToggle'),decisionPanel=document.getElementById('decisionPanel');
      var decisionText=document.getElementById('decisionText');
      var toast=document.getElementById('toast'),toastTimer=0;
      var bridge=function(message){
        try { if(window.UiAgentLabBridge&&UiAgentLabBridge.postMessage){ UiAgentLabBridge.postMessage(JSON.stringify(message)); } } catch(_e){}
      };
      function text(value,fallback){
        if(typeof value==='string'||typeof value==='number'||typeof value==='boolean')return String(value);
        return typeof fallback==='string'?fallback:'';
      }
      function nonEmptyText(value,fallback){
        var candidate=text(value);
        return candidate.trim().length>0?candidate:text(fallback);
      }
      function record(value){return value&&typeof value==='object'&&!Array.isArray(value)?value:null;}
      function list(value){return Array.isArray(value)?value:[];}
      function cssColor(name){return getComputedStyle(document.documentElement).getPropertyValue(name).trim();}
      function node(tag,className,content){
        var next=document.createElement(tag);
        if(className)next.className=className;
        if(content!==undefined&&content!==null)next.textContent=text(content);
        return next;
      }
      function clear(parent){while(parent.firstChild)parent.removeChild(parent.firstChild);}
      function showToast(message){
        toast.textContent=text(message,'UI Lab 本地交互');
        toast.classList.add('is-visible');
        if(toastTimer)window.clearTimeout(toastTimer);
        toastTimer=window.setTimeout(function(){toast.classList.remove('is-visible');},1600);
      }
      function pointer(model,path){
        if(typeof path!=='string'||path.length===0||path.charAt(0)!=='/')return undefined;
        if(path==='/')return model;
        var parts=path.substring(1).split('/'),current=model;
        for(var index=0;index<parts.length;index++){
          var key=parts[index].replace(/~1/g,'/').replace(/~0/g,'~');
          if(Array.isArray(current)){
            if(!/^(0|[1-9][0-9]*)$/.test(key))return undefined;
            var arrayIndex=Number(key); if(arrayIndex>=current.length)return undefined;
            current=current[arrayIndex];
          }else{
            var currentRecord=record(current);
            if(!currentRecord||!Object.prototype.hasOwnProperty.call(currentRecord,key))return undefined;
            current=currentRecord[key];
          }
        }
        return current;
      }
      function exactBinding(value){
        var source=record(value),keys=source?Object.keys(source):[];
        return source&&keys.length===1&&keys[0]==='path'&&typeof source.path==='string'&&source.path.charAt(0)==='/'?source.path:null;
      }
      function resolveCatalogValue(value,schema,model,depth){
        if(!record(schema)||depth>12)return {ok:false};
        var policy=schema.valuePolicy,binding=exactBinding(value),candidate=value;
        if(policy==='literal-or-path'&&typeof value==='string'&&value.charAt(0)==='/')return {ok:false};
        if(policy==='path-only'||(policy==='literal-or-path'&&binding!==null)){
          if(binding===null)return {ok:false};
          candidate=pointer(model,binding);
          if(candidate===undefined)return {ok:false};
        }else if(policy!=='literal'&&policy!=='literal-or-path')return {ok:false};
        if(schema.type==='string')return typeof candidate==='string'&&(schema.minLength===undefined||candidate.trim().length>=schema.minLength)?{ok:true,value:candidate}:{ok:false};
        if(schema.type==='number')return typeof candidate==='number'&&Number.isFinite(candidate)?{ok:true,value:candidate}:{ok:false};
        if(schema.type==='boolean')return typeof candidate==='boolean'?{ok:true,value:candidate}:{ok:false};
        if(schema.type==='array'){
          if(!Array.isArray(candidate)||!record(schema.items)||(schema.minItems!==undefined&&candidate.length<schema.minItems)||(schema.maxItems!==undefined&&candidate.length>schema.maxItems))return {ok:false};
          var output=[];for(var index=0;index<candidate.length;index++){var item=resolveCatalogValue(candidate[index],schema.items,model,depth+1);if(!item.ok)return {ok:false};output.push(item.value);}return {ok:true,value:output};
        }
        if(schema.type==='object'){
          var source=record(candidate),fields=record(schema.fields);if(!source||!fields)return {ok:false};
          var names=Object.keys(fields);for(var requiredIndex=0;requiredIndex<names.length;requiredIndex++){if(fields[names[requiredIndex]].required===true&&!Object.prototype.hasOwnProperty.call(source,names[requiredIndex]))return {ok:false};}
          var keys=Object.keys(source),result=Object.create(null);for(var keyIndex=0;keyIndex<keys.length;keyIndex++){var key=keys[keyIndex],field=fields[key];if(!record(field))return {ok:false};var resolved=resolveCatalogValue(source[key],field,model,depth+1);if(!resolved.ok)return {ok:false};result[key]=resolved.value;}return {ok:true,value:result};
        }
        return {ok:false};
      }
      function resolveCatalogFields(component,context){
        var schema=UI_AGENT_LAB_SCHEMA_BY_NAME[component.component],fields=record(schema&&schema.fields),source=null;
        try{source=record(JSON.parse(component.catalogFieldsJson));}catch(_error){return null;}
        if(!fields||!source)return null;
        var model=context.hasItemScope===true?context.itemScope:context.model,output=Object.assign({},component),keys=Object.keys(source);
        for(var index=0;index<keys.length;index++){var key=keys[index];if(UI_AGENT_LAB_RESERVED_FIELDS.indexOf(key)>=0||!record(fields[key]))return null;var resolved=resolveCatalogValue(source[key],fields[key],model,0);if(!resolved.ok)return null;output[key]=resolved.value;}
        delete output.catalogFieldsJson;return output;
      }
      function componentValue(component,context){
        if(context.hasItemScope===true){
          if(typeof component.dataPath!=='string'||component.dataPath.length===0||component.dataPath==='/')return context.itemScope;
          return pointer(context.itemScope,component.dataPath);
        }
        return typeof component.dataPath==='string'&&component.dataPath.length>0?pointer(context.model,component.dataPath):undefined;
      }
      function card(title,body,className){
        var result=node('article','lab-card'+(className?' '+className:''));
        if(text(title))result.appendChild(node('h3','lab-card-title',title));
        if(text(body))result.appendChild(node('p','lab-card-copy',body));
        return result;
      }
      function childIds(component){
        if(typeof component.child==='string'&&component.child)return [component.child];
        return list(component.children).filter(function(value){return typeof value==='string'&&value.length>0;});
      }
      function appendChildren(parent,component,context,trail){
        childIds(component).forEach(function(id){parent.appendChild(renderById(id,context,trail));});
      }
      function itemArray(value,key){
        if(Array.isArray(value))return value;
        var source=record(value);
        return source&&Array.isArray(source[key])?source[key]:[];
      }
      function svgNode(tag,className){
        var next=document.createElementNS('http://www.w3.org/2000/svg',tag);
        if(className)next.setAttribute('class',className);
        return next;
      }
      function finiteNumber(value){
        return typeof value==='number'&&Number.isFinite(value)?value:null;
      }
      function numericField(source){
        if(!source)return null;
        var keys=['value','bytes','percent','count'];
        for(var index=0;index<keys.length;index++){
          var next=finiteNumber(source[keys[index]]);if(next!==null)return {value:next,kind:keys[index]};
        }
        return null;
      }
      function compactNumber(value){
        var absolute=Math.abs(value),divisor=1,suffix='';
        if(absolute>=1000000000){divisor=1000000000;suffix='B';}
        else if(absolute>=1000000){divisor=1000000;suffix='M';}
        else if(absolute>=1000){divisor=1000;suffix='K';}
        var scaled=value/divisor,precision=Math.abs(scaled)>=100||Number.isInteger(scaled)?0:1;
        var copy=scaled.toFixed(precision);if(copy.endsWith('.0'))copy=copy.slice(0,-2);return copy+suffix;
      }
      function formattedBytes(value){
        var absolute=Math.abs(value),units=['B','KB','MB','GB','TB'],unitIndex=0,scaled=absolute;
        while(scaled>=1024&&unitIndex<units.length-1){scaled/=1024;unitIndex++;}
        if(value<0)scaled=-scaled;
        var precision=Math.abs(scaled)>=100||Number.isInteger(scaled)?0:1,copy=scaled.toFixed(precision);
        if(copy.endsWith('.0'))copy=copy.slice(0,-2);return copy+units[unitIndex];
      }
      function formattedNumber(field){
        if(field.kind==='bytes')return formattedBytes(field.value);
        var copy=compactNumber(field.value);
        if(field.kind==='percent')return copy+'%';
        return copy;
      }
      function headerFields(value){
        var source=record(value),raw=source?source.header:undefined,header=record(raw);
        return {
          kicker:header?text(header.kicker):'',
          title:header?text(header.title):text(raw),
          description:header?text(header.description):'',
          ariaLabel:header?text(header.ariaLabel):''
        };
      }
      function appendVisualHeader(parent,component,value){
        var fields=headerFields(value),kicker=nonEmptyText(component.text,fields.kicker),title=nonEmptyText(component.title,fields.title),body=nonEmptyText(component.body,fields.description);
        if(fields.ariaLabel)parent.setAttribute('aria-label',fields.ariaLabel);
        if(!kicker&&!title&&!body)return;
        var header=node('header','viz-header');
        if(kicker)header.appendChild(node('p','viz-kicker',kicker));
        if(title)header.appendChild(node('h3','lab-card-title',title));
        if(body)header.appendChild(node('p','lab-card-copy',body));
        parent.appendChild(header);
      }
      var SEGMENTED_RING_STROKE_WIDTH=7,SEGMENTED_RING_GAP_LENGTH=2.5;
      function segmentedRingPalette(){return [1,2,3,4,5,6].map(function(index){return cssColor('--chart-'+String(index));});}
      function seriesPalette(){return [1,2,3,4].map(function(index){return cssColor('--series-'+String(index));});}
      function heatmapPalette(){return [1,2,3,4,5,6].map(function(index){return cssColor('--chart-'+String(index));});}
      function blendedChartColor(left,right,ratio){
        function channel(color,offset){return parseInt(color.substring(offset,offset+2),16);}
        function hex(value){return Math.round(value).toString(16).padStart(2,'0');}
        var red=channel(left,1)+(channel(right,1)-channel(left,1))*ratio;
        var green=channel(left,3)+(channel(right,3)-channel(left,3))*ratio;
        var blue=channel(left,5)+(channel(right,5)-channel(left,5))*ratio;
        return '#'+hex(red)+hex(green)+hex(blue);
      }
      function chartColorAtRank(rank,count){
        var palette=segmentedRingPalette();
        if(count<=1)return palette[palette.length-1];
        var position=rank/(count-1)*(palette.length-1);
        if(count<=palette.length)return palette[Math.round(position)];
        var lower=Math.floor(position),upper=Math.ceil(position);
        return lower===upper?palette[lower]:blendedChartColor(palette[lower],palette[upper],position-lower);
      }
      UI_AGENT_LAB_COMPONENT_REGISTRY.SurfaceRoot=function(component,context,trail){
        var root=node('section','surface-root'); appendChildren(root,component,context,trail); return root;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.Column=function(component,context,trail){
        var column=node('div','lab-column'); appendChildren(column,component,context,trail); return column;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.Row=function(component,context,trail){
        var row=node('div','lab-row'); appendChildren(row,component,context,trail); return row;
      };
      var LIST_PAGE_SIZE=8;
      UI_AGENT_LAB_COMPONENT_REGISTRY.List=function(component,context,trail){
        var wrapper=node('section','lab-list'),items=componentValue(component,context),templateId=text(component.child);
        var title=nonEmptyText(component.title);if(title)wrapper.appendChild(node('h3','lab-list-title',title));
        if(!Array.isArray(items)||items.length===0){wrapper.appendChild(node('p','lab-card-copy','暂无内容'));return wrapper;}
        if(!templateId){wrapper.appendChild(safeError('List 缺少模板','没有可用的 componentId。'));return wrapper;}
        var itemHost=node('div','lab-list-items'),pager=node('div','list-pager'),status=node('span','list-page-status');itemHost.setAttribute('role','list');
        var more=node('button','list-more','加载更多'),visibleCount=0;more.type='button';
        function appendPage(){
          var nextCount=Math.min(visibleCount+LIST_PAGE_SIZE,items.length);
          items.slice(visibleCount,nextCount).forEach(function(item){
            var itemContext={surface:context.surface,model:context.model,byId:context.byId,hasItemScope:true,itemScope:item};
            var row=node('div','lab-list-row');row.setAttribute('role','listitem');row.appendChild(renderById(templateId,itemContext,trail));itemHost.appendChild(row);
          });
          visibleCount=nextCount;status.textContent='已显示 '+String(visibleCount)+' / '+String(items.length);
          more.disabled=visibleCount>=items.length;more.textContent=more.disabled?'已显示全部':'加载更多';
        }
        more.addEventListener('click',appendPage);pager.appendChild(status);pager.appendChild(more);
        wrapper.appendChild(itemHost);if(items.length>LIST_PAGE_SIZE)wrapper.appendChild(pager);appendPage();
        return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.HeroBanner=function(component,context){
        var value=componentValue(component,context),fields=headerFields(value),wrapper=node('article','hero-banner');
        var kicker=nonEmptyText(component.text,fields.kicker),title=nonEmptyText(component.title,fields.title),body=nonEmptyText(component.body,fields.description);
        if(fields.ariaLabel)wrapper.setAttribute('aria-label',fields.ariaLabel);
        if(kicker)wrapper.appendChild(node('p','hero-kicker',kicker));
        if(title)wrapper.appendChild(node('h2','hero-title',title));
        if(body)wrapper.appendChild(node('p','hero-body',body));
        return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.MetricGrid=function(component,context){
        var value=componentValue(component,context),wrapper=node('section','lab-card viz-card'),grid=node('div','metric-grid');
        appendVisualHeader(wrapper,component,value);
        var items=Array.isArray(component.items)?component.items:(Array.isArray(value)?value:itemArray(value,'items')),rendered=0;
        items.slice(0,6).forEach(function(item){
          var source=record(item),field=numericField(source);if(!source||field===null)return;
          var label=nonEmptyText(source.label,source.name);if(!label)return;
          var metric=node('article','metric-item');metric.appendChild(node('span','metric-label',label));
          var metricValue=node('strong','metric-value',formattedNumber(field)),unit=nonEmptyText(source.unit);if(unit)metricValue.appendChild(node('small','metric-unit',unit));metric.appendChild(metricValue);
          var deltaValue=finiteNumber(source.delta),delta=nonEmptyText(source.deltaLabel,deltaValue===null?'':(deltaValue>0?'+':'')+compactNumber(deltaValue));
          if(delta){var deltaClass='metric-delta'+(deltaValue!==null&&deltaValue>0?' is-positive':deltaValue!==null&&deltaValue<0?' is-negative':'');metric.appendChild(node('span',deltaClass,delta));}
          grid.appendChild(metric);rendered++;
        });
        if(rendered===0)grid.appendChild(node('p','lab-card-copy','暂无有效数据'));
        wrapper.appendChild(grid);return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.SegmentedRingChart=function(component,context){
        var value=componentValue(component,context),source=record(value),wrapper=node('section','lab-card viz-card');appendVisualHeader(wrapper,component,value);
        var mapped=typeof component.labelPath==='string'&&typeof component.valuePath==='string',items=Array.isArray(component.segments)?component.segments:(Array.isArray(value)?value:itemArray(value,'segments')),segments=[],total=0;
        if(mapped){items=items.map(function(item){return {label:pointer(item,component.labelPath),value:pointer(item,component.valuePath)};});}
        items.forEach(function(item){
          var source=record(item),field=numericField(source);if(!source||field===null||field.value<0)return;
          var label=nonEmptyText(source.label,source.name);if(!label)return;
          segments.push({label:label,field:field});total+=field.value;
        });
        if(segments.length===0||total<=0){wrapper.appendChild(node('p','lab-card-copy','暂无有效构成数据'));return wrapper;}
        if(segments.length>8){var otherValue=segments.slice(8).reduce(function(sum,segment){return sum+segment.field.value;},0);segments=segments.slice(0,8);segments.push({label:'其他',field:{value:otherValue,kind:'number'},renderColor:cssColor('--chart-1'),neutral:true});}
        var ranked=segments.map(function(segment,index){return {index:index,value:segment.field.value,neutral:segment.neutral===true};}).filter(function(entry){return !entry.neutral;}).sort(function(left,right){return left.value-right.value||left.index-right.index;});
        ranked.forEach(function(entry,rank){segments[entry.index].renderColor=chartColorAtRank(rank,ranked.length);});
        var layout=node('div','ring-layout'),svg=svgNode('svg','ring-svg'),legend=node('div','chart-legend');
        var ringFields=headerFields(value),ringSummary=segments.map(function(segment){return segment.label+' '+compactNumber(segment.field.value/total*100)+'%';}).join(', '),ringAria=nonEmptyText(ringFields.ariaLabel,ringSummary);
        svg.setAttribute('viewBox','0 0 120 120');svg.setAttribute('role','img');svg.setAttribute('aria-label',ringAria);
        var ringTitle=svgNode('title','');ringTitle.textContent=ringAria;svg.appendChild(ringTitle);
        var track=svgNode('circle','');track.setAttribute('cx','60');track.setAttribute('cy','60');track.setAttribute('r','44');track.setAttribute('fill','none');track.setAttribute('stroke',cssColor('--chart-track'));track.setAttribute('stroke-width',String(SEGMENTED_RING_STROKE_WIDTH));svg.appendChild(track);
        var circumference=2*Math.PI*44,consumed=0;
        segments.forEach(function(segment,index){
          var arcLength=circumference*segment.field.value/total,visibleArcLength=segments.length===1?circumference:Math.max(0,arcLength-SEGMENTED_RING_GAP_LENGTH),arc=svgNode('circle','');
          arc.setAttribute('cx','60');arc.setAttribute('cy','60');arc.setAttribute('r','44');arc.setAttribute('fill','none');
          arc.setAttribute('stroke',segment.renderColor);arc.setAttribute('stroke-width',String(SEGMENTED_RING_STROKE_WIDTH));
          arc.setAttribute('stroke-linecap','butt');arc.setAttribute('stroke-dasharray',String(visibleArcLength)+' '+String(circumference-visibleArcLength));
          arc.setAttribute('stroke-dashoffset',String(-circumference*consumed/total));arc.setAttribute('transform','rotate(-90 60 60)');svg.appendChild(arc);consumed+=segment.field.value;
          var entry=node('div','legend-item'),swatch=node('span','legend-swatch');swatch.style.background=segment.renderColor;
          entry.appendChild(swatch);entry.appendChild(node('span','legend-label',segment.label));entry.appendChild(node('span','legend-value',compactNumber(segment.field.value/total*100)+'%'));legend.appendChild(entry);
        });
        var centerLabel=source?nonEmptyText(source.centerLabel):'',unitLabel=source?nonEmptyText(source.unitLabel):'';
        if(centerLabel){var centerTop=svgNode('text','ring-center-label');centerTop.setAttribute('x','60');centerTop.setAttribute('y','49');centerTop.textContent=centerLabel;svg.appendChild(centerTop);}
        var centerValue=svgNode('text','ring-center-value');centerValue.setAttribute('x','60');centerValue.setAttribute('y',centerLabel||unitLabel?'65':'64');centerValue.textContent=compactNumber(total);svg.appendChild(centerValue);
        if(unitLabel){var centerUnit=svgNode('text','ring-center-unit');centerUnit.setAttribute('x','60');centerUnit.setAttribute('y','77');centerUnit.textContent=unitLabel;svg.appendChild(centerUnit);}
        layout.appendChild(svg);layout.appendChild(legend);wrapper.appendChild(layout);return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.MultiSeriesLineChart=function(component,context){
        var value=componentValue(component,context),source=record(value),wrapper=node('section','lab-card viz-card');appendVisualHeader(wrapper,component,value);
        if(!source){wrapper.appendChild(node('p','lab-card-copy','暂无有效数据'));return wrapper;}
        var rawXLabels=list(source.xLabels).length?list(source.xLabels):list(source.labels),xLabels=rawXLabels.slice(0,24);
        var inputSeries=list(source.series).slice(0,4),series=[],minimum=Infinity,maximum=-Infinity,pointCount=0;
        inputSeries.forEach(function(item,index){
          var itemRecord=record(item);if(!itemRecord)return;
          var rawValues=list(itemRecord.values);if(rawXLabels.length&&rawValues.length!==rawXLabels.length)return;
          var values=rawValues.slice(0,24),points=[];
          values.forEach(function(raw,pointIndex){var next=finiteNumber(raw);if(next===null)return;points.push({index:pointIndex,value:next});minimum=Math.min(minimum,next);maximum=Math.max(maximum,next);pointCount=Math.max(pointCount,pointIndex+1);});
          if(points.length)series.push({label:nonEmptyText(itemRecord.label,itemRecord.name),points:points,index:index});
        });
        if(series.length===0||!Number.isFinite(minimum)||!Number.isFinite(maximum)){wrapper.appendChild(node('p','lab-card-copy','暂无有效数据'));return wrapper;}
        if(maximum===minimum){maximum+=1;minimum-=1;}
        pointCount=Math.max(pointCount,xLabels.length,2);var width=320,height=150,left=20,right=8,top=10,bottom=16,plotWidth=width-left-right,plotHeight=height-top-bottom;
        var lineSummary=series.map(function(entry,index){var label=nonEmptyText(entry.label,'系列 '+String(index+1)),values=entry.points.map(function(point){return compactNumber(point.value);}).join(', ');return label+': '+values;}).join('; ');
        var lineFields=headerFields(value),lineAria=nonEmptyText(lineFields.ariaLabel,lineSummary),svg=svgNode('svg','line-svg');svg.setAttribute('viewBox','0 0 '+String(width)+' '+String(height));svg.setAttribute('role','img');svg.setAttribute('aria-label',lineAria);
        var lineTitle=svgNode('title','');lineTitle.textContent=lineAria;svg.appendChild(lineTitle);
        [0,.5,1].forEach(function(ratio){var line=svgNode('line','line-grid'),y=top+plotHeight*ratio;line.setAttribute('x1',String(left));line.setAttribute('x2',String(width-right));line.setAttribute('y1',String(y));line.setAttribute('y2',String(y));svg.appendChild(line);});
        var linePalette=seriesPalette();
        series.forEach(function(entry,seriesIndex){
          var polyline=svgNode('polyline','line-series'),coordinates=[];
          entry.points.forEach(function(point){var x=left+plotWidth*(point.index/Math.max(1,pointCount-1)),y=top+plotHeight*(1-(point.value-minimum)/(maximum-minimum));coordinates.push(String(x)+','+String(y));});
          polyline.setAttribute('points',coordinates.join(' '));polyline.setAttribute('stroke',linePalette[seriesIndex%linePalette.length]);svg.appendChild(polyline);
        });
        wrapper.appendChild(svg);wrapper.appendChild(node('p','sr-only',lineSummary));
        if(xLabels.length){var labels=node('div','line-labels'),indices=xLabels.length===1?[0]:[0,Math.floor((xLabels.length-1)/2),xLabels.length-1];indices.filter(function(item,index,self){return self.indexOf(item)===index;}).forEach(function(labelIndex){labels.appendChild(node('span','',text(xLabels[labelIndex])));});wrapper.appendChild(labels);}
        var legend=node('div','line-legend');series.forEach(function(entry,index){if(!entry.label)return;var item=node('span','legend-item'),swatch=node('i','legend-swatch');swatch.style.background=linePalette[index%linePalette.length];item.appendChild(swatch);item.appendChild(node('span','legend-label',entry.label));legend.appendChild(item);});if(legend.firstChild)wrapper.appendChild(legend);
        return wrapper;
      };
      function heatmapCellValue(value){var source=record(value);return source?numericField(source):finiteNumber(value)===null?null:{value:finiteNumber(value),kind:'value'};}
      function heatmapRows(source){
        var direct=list(source.values).slice(0,12),rows=[];
        if(direct.length){direct.forEach(function(row){rows.push(list(row).slice(0,24));});return rows;}
        var weeks=list(source.weeks).slice(0,24),columns=[];weeks.forEach(function(week){var weekRecord=record(week);columns.push(Array.isArray(week)?week:itemArray(weekRecord,'values').length?itemArray(weekRecord,'values'):itemArray(weekRecord,'days'));});
        var rowCount=Math.min(12,columns.reduce(function(maximum,column){return Math.max(maximum,column.length);},0));
        for(var rowIndex=0;rowIndex<rowCount;rowIndex++){var row=[];columns.forEach(function(column){row.push(column[rowIndex]);});rows.push(row);}
        return rows;
      }
      UI_AGENT_LAB_COMPONENT_REGISTRY.MatrixHeatmap=function(component,context){
        var value=componentValue(component,context),source=record(value),wrapper=node('section','lab-card viz-card');appendVisualHeader(wrapper,component,value);
        if(!source){wrapper.appendChild(node('p','lab-card-copy','暂无有效数据'));return wrapper;}
        var rows=heatmapRows(source),columnCount=rows.reduce(function(maximum,row){return Math.max(maximum,row.length);},0);
        if(rows.length===0||columnCount===0){wrapper.appendChild(node('p','lab-card-copy','暂无有效数据'));return wrapper;}
        columnCount=Math.min(24,columnCount);var maximum=0;
        rows.forEach(function(row){row.slice(0,columnCount).forEach(function(raw){var field=heatmapCellValue(raw);if(field!==null)maximum=Math.max(maximum,field.value);});});
        var rowLabels=list(source.rowLabels).length?list(source.rowLabels).slice(0,12):list(source.dayLabels).slice(0,12);
        var columnLabels=list(source.columnLabels).length?list(source.columnLabels).slice(0,24):list(source.weekLabels).slice(0,24);
        var layout=node('div','heatmap-layout'),rowLabelHost=node('div','heatmap-row-labels'),main=node('div','heatmap-main'),columnHost=node('div','heatmap-column-labels'),grid=node('div','heatmap-grid');
        grid.setAttribute('role','grid');
        rowLabelHost.style.gridTemplateRows='repeat('+String(rows.length)+',minmax(0,1fr))';columnHost.style.gridTemplateColumns='repeat('+String(columnCount)+',minmax(0,1fr))';grid.style.gridTemplateColumns='repeat('+String(columnCount)+',minmax(0,1fr))';
        rows.forEach(function(_row,index){rowLabelHost.appendChild(node('span','heatmap-row-label',text(rowLabels[index])));});
        for(var columnIndex=0;columnIndex<columnCount;columnIndex++)columnHost.appendChild(node('span','heatmap-column-label',text(columnLabels[columnIndex])));
        var heatPalette=heatmapPalette();
        rows.forEach(function(row,rowIndex){for(var columnIndex=0;columnIndex<columnCount;columnIndex++){
          var field=heatmapCellValue(row[columnIndex]),level=field===null||field.value<=0||maximum<=0?0:Math.min(5,Math.ceil(field.value/maximum*5)),cell=node('span','heatmap-cell');cell.style.background=heatPalette[level];
          var rowLabel=text(rowLabels[rowIndex]),columnLabel=text(columnLabels[columnIndex]),cellLabel=(rowLabel?rowLabel+' ':'')+(columnLabel?columnLabel+' ':'')+(field===null?'无数据':compactNumber(field.value));cell.setAttribute('role','gridcell');cell.setAttribute('aria-label',cellLabel);
          grid.appendChild(cell);
        }});
        main.appendChild(columnHost);main.appendChild(grid);layout.appendChild(rowLabelHost);layout.appendChild(main);wrapper.appendChild(layout);
        var scale=node('div','heatmap-scale');heatPalette.forEach(function(color){var step=node('span','');step.style.background=color;scale.appendChild(step);});wrapper.appendChild(scale);return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.Text=function(component,context){
        var value=componentValue(component,context);
        var primitive=typeof value==='string'||typeof value==='number'||typeof value==='boolean';
        if(primitive)return node('p','lab-text',text(value));
        var direct=nonEmptyText(component.text),title=nonEmptyText(component.title),body=nonEmptyText(component.body),copy=nonEmptyText(direct,nonEmptyText(body,title));
        var output=node('div','lab-text');
        if(!direct&&title&&body){output.appendChild(node('span','lab-text-title',title));output.appendChild(node('span','lab-text-body',body));return output;}
        output.textContent=copy;return output;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.InfoRows=function(component,context){
        var wrapper=card(component.title,'','info-card'),rows=node('div','info-rows');
        var value=componentValue(component,context),items=Array.isArray(value)?value:[];
        var mapped=typeof component.labelPath==='string'&&typeof component.valuePath==='string';
        if(mapped)items=items.map(function(item){return {label:pointer(item,component.labelPath),value:pointer(item,component.valuePath),time:typeof component.timePath==='string'?pointer(item,component.timePath):''};});
        if(items.length===0){var source=record(value);if(source){Object.keys(source).slice(0,16).forEach(function(key){items.push({label:key,value:source[key]});});}}
        items.slice(0,24).forEach(function(item,index){
          var valueRecord=record(item),row=node('div','info-row');
          row.appendChild(node('span','info-label',valueRecord?text(valueRecord.label,'项目 '+String(index+1)):'项目 '+String(index+1)));
          row.appendChild(node('span','info-value',valueRecord?nonEmptyText(valueRecord.value,'—'):nonEmptyText(item,'—')));
          var time=valueRecord?text(valueRecord.time).trim():'';
          if(time)row.appendChild(node('span','info-time',time));
          rows.appendChild(row);
        });
        if(items.length===0)rows.appendChild(node('p','lab-card-copy','暂无信息'));
        wrapper.appendChild(rows); return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.ActionBar=function(component,context){
        var bar=node('div','action-bar'),value=componentValue(component,context);
        var actions=list(component.actions); if(actions.length===0)actions=itemArray(value,'actions');
        actions.slice(0,8).forEach(function(action,index){
          var actionRecord=record(action),label=actionRecord?text(actionRecord.label,'操作 '+String(index+1)):'操作 '+String(index+1);
          var button=node('button','action-button'+(index===0?'':' secondary'),label); button.type='button';
          button.addEventListener('click',function(){
            bridge({type:'action',componentId:text(component.id),actionIndex:index});
          }); bar.appendChild(button);
        });
        if(actions.length===0)bar.appendChild(node('p','lab-card-copy','暂无可用动作'));
        return bar;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.ErrorNotice=function(component,context){
        var value=record(componentValue(component,context));
        return card(text(component.title,value?text(value.title,'出现问题'):'出现问题'),text(component.body,value?text(value.message,value.error):''),'error-card');
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.ThinkingStream=function(component,context){
        var wrapper=card(component.title||'生成进度',''),events=node('ol','event-list');
        itemArray(componentValue(component,context),'items').slice(0,16).forEach(function(item){
          var itemRecord=record(item),entry=node('li','event-item'); entry.appendChild(node('span','event-dot'));
          entry.appendChild(node('span','',itemRecord?text(itemRecord.title,itemRecord.message):text(item))); events.appendChild(entry);
        });
        if(!events.firstChild){var pending=node('li','event-item');pending.appendChild(node('span','event-dot'));pending.appendChild(node('span','','正在组织界面…'));events.appendChild(pending);}
        wrapper.appendChild(events); return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.ThinkingCard=function(component,context){
        var value=record(componentValue(component,context));
        var wrapper=card(component.title||'正在生成',component.body||component.text||(value?text(value.label):''),'thinking-card');
        if(value&&Number.isFinite(Number(value.progress))){var track=node('div','progress-track'),fill=node('div','progress-fill');fill.style.width=String(Math.max(0,Math.min(100,Number(value.progress))))+'%';track.appendChild(fill);wrapper.appendChild(track);}
        var events=value?itemArray(value,'events'):[];if(events.length){var stream=node('ol','event-list');events.slice(0,12).forEach(function(event){var eventRecord=record(event),entry=node('li','event-item');entry.appendChild(node('span','event-dot'));entry.appendChild(node('span','',eventRecord?text(eventRecord.title,eventRecord.detail):text(event)));stream.appendChild(entry);});wrapper.appendChild(stream);}
        return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.ScheduleStack=function(component,context){
        var wrapper=node('section','schedule-stack'),days=itemArray(componentValue(component,context),'days');
        days.slice(0,12).forEach(function(day,index){
          var dayRecord=record(day)||Object.create(null),article=node('article','schedule-card');
          article.appendChild(node('span','schedule-chip',text(dayRecord.label,'DAY '+String(index+1).padStart(2,'0'))));
          article.appendChild(node('h3','',text(dayRecord.title,'日程 '+String(index+1))));
          if(text(dayRecord.summary,dayRecord.subtitle))article.appendChild(node('p','',text(dayRecord.summary,dayRecord.subtitle)));
          itemArray(dayRecord,'entries').slice(0,12).forEach(function(event){
            var eventRecord=record(event)||Object.create(null),row=node('div','schedule-event');
            row.appendChild(node('time','',text(eventRecord.time,eventRecord.label)));
            row.appendChild(node('span','',text(eventRecord.title,text(eventRecord.value,eventRecord.detail))));
            article.appendChild(row);
          });
          if(text(dayRecord.metric))article.appendChild(node('strong','scene-metric',dayRecord.metric));
          wrapper.appendChild(article);
        });
        if(days.length===0)wrapper.appendChild(card(component.title||'日程',component.body||'暂无日程数据'));
        return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.SkeletonCard=function(){
        var wrapper=node('article','lab-card skeleton-card'),media=node('span','skeleton-media'),copy=node('span','skeleton-copy');
        copy.appendChild(node('i','skeleton-bar'));copy.appendChild(node('i','skeleton-bar short'));copy.appendChild(node('i','skeleton-bar'));
        wrapper.appendChild(media);wrapper.appendChild(copy);wrapper.setAttribute('role','status');wrapper.setAttribute('aria-label','内容加载中');return wrapper;
      };
      var EXPANDABLE_MAX_DEPTH=4,EXPANDABLE_MAX_NODES=72,EXPANDABLE_MAX_ARRAY_ITEMS=12,EXPANDABLE_MAX_OBJECT_FIELDS=16;
      function appendExpandableLimit(parent,budget,message){
        if(budget.notified)return;
        budget.notified=true;
        parent.appendChild(node('p','expandable-limit',message||'其余内容已折叠，避免页面过长。'));
      }
      function takeExpandableBudget(parent,budget){
        if(budget.remaining<=0){appendExpandableLimit(parent,budget);return false;}
        budget.remaining-=1;return true;
      }
      function expandableIdentity(source){
        if(!source)return '';
        return nonEmptyText(source.title,nonEmptyText(source.name,source.label));
      }
      function appendExpandableField(parent,label,value,budget){
        if(!takeExpandableBudget(parent,budget))return false;
        var row=node('div','expandable-field');
        row.appendChild(node('span','expandable-field-label',label));
        row.appendChild(node('span','expandable-field-value',value===null?'—':text(value)));
        parent.appendChild(row);return true;
      }
      function appendExpandableValue(parent,value,label,depth,budget){
        if(depth>EXPANDABLE_MAX_DEPTH){appendExpandableLimit(parent,budget,'嵌套内容已达到显示深度上限。');return false;}
        if(value===undefined)return false;
        if(value===null||typeof value==='string'||typeof value==='number'||typeof value==='boolean'){
          return appendExpandableField(parent,label||'值',value,budget);
        }
        if(Array.isArray(value)){
          if(!takeExpandableBudget(parent,budget))return false;
          var arraySection=node('section','expandable-data');
          if(nonEmptyText(label))arraySection.appendChild(node('h4','expandable-data-title',label));
          var visible=value.slice(0,EXPANDABLE_MAX_ARRAY_ITEMS);
          visible.forEach(function(item,index){
            if(budget.remaining<=0){appendExpandableLimit(arraySection,budget);return;}
            var itemRecord=record(item),itemHost=node('article','expandable-item');
            if(itemRecord){
              var itemTitle=expandableIdentity(itemRecord)||'项目 '+String(index+1);
              itemHost.appendChild(node('h5','expandable-data-title',itemTitle));
              appendExpandableValue(itemHost,itemRecord,'',depth+1,budget);
            }else{
              appendExpandableValue(itemHost,item,'项目 '+String(index+1),depth+1,budget);
            }
            if(itemHost.firstChild)arraySection.appendChild(itemHost);
          });
          if(value.length===0)arraySection.appendChild(node('p','lab-card-copy','暂无内容'));
          if(value.length>visible.length)arraySection.appendChild(node('p','expandable-limit','还有 '+String(value.length-visible.length)+' 项未显示。'));
          parent.appendChild(arraySection);return true;
        }
        var source=record(value);
        if(!source)return false;
        if(!takeExpandableBudget(parent,budget))return false;
        var objectSection=node('section','expandable-data'),identity=expandableIdentity(source);
        if(nonEmptyText(label))objectSection.appendChild(node('h4','expandable-data-title',identity?label+': '+identity:label));
        var keys=Object.keys(source),visibleKeys=keys.slice(0,EXPANDABLE_MAX_OBJECT_FIELDS),rendered=false;
        visibleKeys.forEach(function(key){
          if(budget.remaining<=0){appendExpandableLimit(objectSection,budget);return;}
          var child=source[key];
          if((key==='title'||key==='name'||key==='label')&&text(child)===identity)return;
          if(child===null||typeof child==='string'||typeof child==='number'||typeof child==='boolean'){
            rendered=appendExpandableField(objectSection,key,child,budget)||rendered;
          }else{
            rendered=appendExpandableValue(objectSection,child,key,depth+1,budget)||rendered;
          }
        });
        if(keys.length>visibleKeys.length)objectSection.appendChild(node('p','expandable-limit','还有 '+String(keys.length-visibleKeys.length)+' 个字段未显示。'));
        if(!rendered&&keys.length===0)objectSection.appendChild(node('p','lab-card-copy','暂无内容'));
        parent.appendChild(objectSection);return true;
      }
      UI_AGENT_LAB_COMPONENT_REGISTRY.ExpandableCard=function(component,context){
        var hasLegacyDataPath=typeof component.dataPath==='string'&&component.dataPath.length>0;
        var value=hasLegacyDataPath?componentValue(component,context):undefined,valueRecord=record(value),wrapper=node('article','lab-card expandable-card');
        var title=nonEmptyText(component.title,nonEmptyText(valueRecord?valueRecord.title:undefined,nonEmptyText(valueRecord?valueRecord.name:undefined,nonEmptyText(valueRecord?valueRecord.label:undefined,'展开详情'))));
        var trigger=node('button','expandable-trigger'),label=node('span','',title),icon=node('span','','+');
        trigger.type='button';trigger.setAttribute('aria-expanded','false');trigger.appendChild(label);trigger.appendChild(icon);
        var panel=node('div','expandable-panel'),panelInner=node('div','expandable-panel-inner'),body=nonEmptyText(component.body),rendered=false;
        panel.setAttribute('aria-hidden','true');
        if(body){panelInner.appendChild(node('p','lab-card-copy',body));rendered=true;}
        var directRows=list(component.rows).slice(0,8),directRowsHost=node('section','expandable-data');
        directRows.forEach(function(item){
          var row=record(item);if(!row)return;
          appendExpandableField(directRowsHost,text(row.label),row.value,{remaining:1,notified:false});
        });
        if(directRowsHost.firstChild){panelInner.appendChild(directRowsHost);rendered=true;}
        if(value!==undefined)rendered=appendExpandableValue(panelInner,value,'',0,{remaining:EXPANDABLE_MAX_NODES,notified:false})||rendered;
        if(!rendered)panelInner.appendChild(node('p','lab-card-copy','暂无详细信息'));
        panel.appendChild(panelInner);
        trigger.addEventListener('click',function(){var open=wrapper.classList.toggle('is-open');trigger.setAttribute('aria-expanded',open?'true':'false');panel.setAttribute('aria-hidden',open?'false':'true');});
        wrapper.appendChild(trigger);wrapper.appendChild(panel);return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.MediaSlider=function(component,context){
        var slider=node('div','media-slider'),items=itemArray(componentValue(component,context),'items');
        items.slice(0,12).forEach(function(item,index){
          var itemRecord=record(item)||Object.create(null),button=node('button','media-card');button.type='button';
          button.appendChild(node('span','media-frame',text(itemRecord.kind,'MEDIA '+String(index+1))));
          var label=text(itemRecord.title,itemRecord.label);button.appendChild(node('span','media-title',label||'媒体卡片 '+String(index+1)));
          button.addEventListener('click',function(){showToast(label||'媒体预览');});slider.appendChild(button);
        });
        if(items.length===0)slider.appendChild(card(component.title||'媒体',component.body||'暂无媒体内容'));
        return slider;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.SceneTabs=function(component,context){
        var wrapper=node('section','lab-card'),tabs=node('div','scene-tabs'),panels=node('div','scene-panels');
        var items=itemArray(componentValue(component,context),'items');
        function activate(selected){
          Array.prototype.forEach.call(tabs.children,function(tab,index){tab.classList.toggle('is-active',index===selected);tab.setAttribute('aria-selected',index===selected?'true':'false');});
          Array.prototype.forEach.call(panels.children,function(panel,index){panel.classList.toggle('is-active',index===selected);});
        }
        items.slice(0,6).forEach(function(item,index){
          var itemRecord=record(item)||Object.create(null),tab=node('button','scene-tab',text(itemRecord.label,itemRecord.title)||'场景 '+String(index+1));tab.type='button';tab.setAttribute('role','tab');
          var panel=node('article','scene-panel'),title=text(itemRecord.title,itemRecord.label);panel.appendChild(node('h3','lab-card-title',title));panel.appendChild(node('p','lab-card-copy',text(itemRecord.summary,itemRecord.body)));
          var metrics=node('div','scene-metrics');itemArray(itemRecord,'metrics').slice(0,8).forEach(function(metric){metrics.appendChild(node('span','scene-metric',text(record(metric)?text(record(metric).value,record(metric).label):metric)));});panel.appendChild(metrics);
          tab.addEventListener('click',function(){activate(index);});tabs.appendChild(tab);panels.appendChild(panel);
        });
        if(items.length===0)return card(component.title||'场景',component.body||'暂无场景数据');
        wrapper.appendChild(tabs);wrapper.appendChild(panels);activate(0);return wrapper;
      };
      UI_AGENT_LAB_COMPONENT_REGISTRY.MasonryGrid=function(component,context){
        var grid=node('section','masonry-grid'),items=itemArray(componentValue(component,context),'items');
        items.slice(0,20).forEach(function(item,index){var itemRecord=record(item)||Object.create(null),tone=text(itemRecord.tone),height=text(itemRecord.height);var className='masonry-card'+((tone==='blue'||tone==='peach'||tone==='mint')?' tone-'+tone:'')+(height==='tall'?' is-tall':'');grid.appendChild(card(text(itemRecord.title,'卡片 '+String(index+1)),text(itemRecord.body,itemRecord.summary),className));});
        if(items.length===0)grid.appendChild(card(component.title||'信息卡片',component.body||'暂无卡片数据','masonry-card'));return grid;
      };
      function safeError(title,body){return card(title,body,'error-card');}
      function renderById(id,context,trail){
        if(trail.length>=64)return safeError('组件树过深','UI Lab 已停止渲染。');
        if(trail.indexOf(id)>=0)return safeError('组件循环引用','组件 '+text(id)+' 无法渲染。');
        var component=context.byId[id];
        if(!component)return safeError('组件缺失','找不到组件 '+text(id)+'。');
        if(!UI_AGENT_LAB_SCHEMA_BY_NAME[component.component])return safeError('不支持的组件','UI Lab catalog 不包含 '+text(component.component)+'。');
        if(typeof component.catalogFieldsJson==='string'&&component.catalogFieldsJson.length>0){
          var resolvedComponent=resolveCatalogFields(component,context);
          if(!resolvedComponent)return safeError('组件属性无效',text(component.component)+' 的 catalog 属性无法安全解析。');
          component=resolvedComponent;
        }
        var renderer=UI_AGENT_LAB_COMPONENT_REGISTRY[component.component];
        if(typeof renderer!=='function')return safeError('不支持的组件','UI Lab catalog 不包含 '+text(component.component)+'。');
        try{return renderer(component,context,trail.concat([id]));}catch(_error){return safeError('组件渲染失败',text(component.component)+' 未能安全渲染。');}
      }
      var latestSurfaceGeneration=-1,latestSurfaceRevision=-1,latestThemeGeneration=-1,latestSurfaceSource=null;
      function renderSurfaceSource(source){
        var components=list(source.components),byId=Object.create(null);
        components.slice(0,96).forEach(function(component){var item=record(component);if(item&&typeof item.id==='string'&&item.id&&!byId[item.id])byId[item.id]=item;});
        var model=Object.create(null);try{model=typeof source.dataModelJson==='string'?JSON.parse(source.dataModelJson):(record(source.dataModel)||Object.create(null));}catch(_error){model=Object.create(null);}
        clear(surfaceHost);
        if(typeof source.rootId!=='string'||!source.rootId){surfaceHost.appendChild(safeError('Surface 无根节点','UI Agent 没有提供 rootId。'));return;}
        surfaceHost.appendChild(renderById(source.rootId,{surface:source,model:model,byId:byId,hasItemScope:false,itemScope:undefined},[]));
      }
      window.__applyUiAgentLabSurface=function(next){
        var payload=record(next),source=payload?record(payload.surface):null;
        var generation=payload?payload.generation:undefined,revision=payload?payload.revision:undefined;
        if(!source||!Number.isSafeInteger(generation)||!Number.isSafeInteger(revision)||generation<0||revision<0)return;
        if(generation<latestSurfaceGeneration)return;
        if(generation>latestSurfaceGeneration){latestSurfaceGeneration=generation;latestSurfaceRevision=-1;}
        if(revision<=latestSurfaceRevision)return;
        latestSurfaceRevision=revision;
        latestSurfaceSource=source;renderSurfaceSource(source);
      };
      function applyTheme(theme){
        document.documentElement.dataset.theme=theme;
        themeToggle.setAttribute('aria-pressed',theme==='cool'?'true':'false');
        themeToggle.setAttribute('aria-label',theme==='cool'?'切换到奶油咖啡主题':'启用现代冷色主题');
        if(latestSurfaceSource)renderSurfaceSource(latestSurfaceSource);
      }
      window.__applyUiAgentLabTheme=function(next){
        var source=record(next),theme=source?source.theme:undefined,generation=source?source.generation:undefined;
        if(!source||Object.keys(source).sort().join(',')!=='generation,theme'||(theme!=='warm'&&theme!=='cool')||!Number.isSafeInteger(generation)||generation<0)return;
        if(generation<latestThemeGeneration||generation<latestSurfaceGeneration)return;
        latestThemeGeneration=generation;applyTheme(theme);
      };
      window.__applyUiAgentLabDecision=function(next){
        var source=record(next),enabled=source!==null&&source.enabled===true;
        decisionToggle.dataset.enabled=enabled?'true':'false';
        decisionToggle.setAttribute('aria-pressed',enabled?'true':'false');
        decisionToggle.setAttribute('aria-label',enabled?'隐藏 UI 决策说明':'显示 UI 决策说明');
        decisionPanel.hidden=!enabled;shell.classList.toggle('decision-notes-visible',enabled);
        decisionText.textContent=enabled&&typeof source.text==='string'?source.text.substring(0,2400):'';
      };
      var status=document.getElementById('status'),statusText=document.getElementById('statusText'),responseMeta=document.getElementById('responseMeta');
      var prompt=document.getElementById('prompt'),send=document.getElementById('send');
      window.__applyUiAgentLabStatus=function(next){
        if(!next||typeof next.state!=='string')return;
        status.dataset.state=next.state;
        statusText.textContent=typeof next.message==='string'?next.message:'';
        responseMeta.textContent=Number(next.responseChars)>0?String(next.responseChars)+' chars':'';
        send.disabled=next.state==='loading';prompt.disabled=next.state==='loading';decisionToggle.disabled=next.state==='loading';
      };
      document.getElementById('back').addEventListener('click',function(){bridge({type:'back'});});
      decisionToggle.addEventListener('click',function(){
        if(decisionToggle.disabled)return;
        bridge({type:'toggleDecisionNotes',enabled:decisionToggle.dataset.enabled!=='true'});
      });
      themeToggle.addEventListener('click',function(){
        var enabled=document.documentElement.dataset.theme!=='cool';
        applyTheme(enabled?'cool':'warm');
        bridge({type:'toggleTheme',enabled:enabled});
      });
      document.getElementById('composer').addEventListener('submit',function(event){
        event.preventDefault();var value=prompt.value.trim();if(!value||send.disabled)return;
        window.__applyUiAgentLabStatus({state:'loading',message:'模型正在响应…',responseChars:0});
        bridge({type:'submit',prompt:value});
      });
    })();
  </script>
</body>
</html>`;
}
