import {
  A2uiAction,
  A2uiComponent,
  A2uiLabelValueData,
  A2uiPersonaData,
  A2uiPersonaMemoryData,
  A2uiSurfaceState,
  WaterfallExplicitPreference
} from '@loop/agent-core';
import { markdownSectionValue, parsePersonaMarkdown } from './PersonaMarkdown';
import { personaManifestIds, personaPackForId } from './PersonaStore';

type RawValue = Object | string | number | boolean | null | undefined;
type RawRecord = Record<string, RawValue>;

export interface PersonaMemorySuggestedAction {
  label: string;
  prompt: string;
  toolId: string;
}

export interface PersonaMemoryUpdateRequest {
  personaId: string;
  summary: string;
  memoryText: string;
  reason: string;
  suggestedAction?: PersonaMemorySuggestedAction;
}

function textOf(value: RawValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function objectOf(value: RawValue): RawRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  return value as RawRecord;
}

function isKnownPersonaId(personaId: string): boolean {
  return personaManifestIds().indexOf(personaId) >= 0;
}

function parseSuggestedAction(raw: RawRecord | null): PersonaMemorySuggestedAction | undefined {
  if (raw === null) {
    return undefined;
  }
  const label = textOf(raw.label);
  const prompt = textOf(raw.prompt);
  if (label.length === 0 || prompt.length === 0) {
    return undefined;
  }
  return {
    label: label,
    prompt: prompt,
    toolId: textOf(raw.toolId)
  };
}

export function parsePersonaMemoryUpdateInput(input: string, activePersonaId: string): PersonaMemoryUpdateRequest | null {
  try {
    const parsed = JSON.parse(input.length > 0 ? input : '{}') as RawRecord;
    const personaId = activePersonaId;
    const memoryText = textOf(parsed.memoryText);
    if (personaId.length === 0 || !isKnownPersonaId(personaId) || memoryText.length === 0) {
      return null;
    }
    const rawSummary = textOf(parsed.summary);
    const summary = rawSummary.length > 0 ? rawSummary : memoryText;
    return {
      personaId: personaId,
      summary: summary,
      memoryText: memoryText,
      reason: textOf(parsed.reason),
      suggestedAction: parseSuggestedAction(objectOf(parsed.suggestedAction))
    };
  } catch (_error) {
    return null;
  }
}

function rerunActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  if (update.suggestedAction === undefined || update.suggestedAction.prompt.length === 0) {
    return [];
  }
  return [{
    id: 'persona_memory_rerun',
    label: update.suggestedAction.label,
    prompt: update.suggestedAction.prompt,
    variant: 'primary',
    kind: 'prompt'
  }];
}

function editActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  return [
    {
      id: 'persona_memory_edit',
      label: '编辑 memory',
      prompt: update.personaId,
      variant: 'secondary',
      kind: 'client'
    },
    {
      id: 'persona_soul_edit',
      label: '编辑 soul',
      prompt: update.personaId,
      variant: 'secondary',
      kind: 'client'
    }
  ];
}

function cardActions(update: PersonaMemoryUpdateRequest): A2uiAction[] {
  return rerunActions(update).concat(editActions(update));
}

function clipped(text: string): string {
  const value = text.trim();
  return value.length <= 240 ? value : value.substring(0, 240) + '...';
}

function markdownSummary(text: string, sectionTitle: string): string {
  const parsed = parsePersonaMarkdown(text);
  const section = markdownSectionValue(parsed.sections, sectionTitle).trim();
  return clipped(section.length > 0 ? section : parsed.body);
}

function durableStatement(text: string): string {
  return text.replace(/\s+/g, ' ').replace(/^[-*]\s*/, '').trim();
}

const WATERFALL_SOURCE_ALIASES: string[][] = [
  ['youtube', 'youtube'],
  ['b站', 'bilibili'],
  ['bilibili', 'bilibili'],
  ['twitter', 'x'],
  [' x ', 'x'],
  ['reddit', 'reddit'],
  ['红迪', 'reddit'],
  ['hacker news', 'hackernews'],
  [' hn ', 'hackernews'],
  ['知乎', 'zhihu']
];

function waterfallPreferenceEffect(statement: string): 'block' | 'downweight' | 'boost' | '' {
  const text = statement.toLowerCase();
  if (/不要|不看|别推荐|不喜欢/.test(text)) return 'block';
  if (/少看|少推荐|少给我看/.test(text)) return 'downweight';
  if (/喜欢|多看|多推荐|优先推荐/.test(text)) return 'boost';
  return '';
}

export function isStableWaterfallContentPreference(statement: string): boolean {
  const text = statement.trim();
  if (text.length === 0 || /搜索|帮我搜|查询|帮我查|今天聊聊|这次|现在/.test(text)) return false;
  const contentCue = /推荐|给我看|少看|多看|不看|视频|电影|影视|综艺|娱乐|八卦|体育|足球|篮球|新闻|讨论|文章|图文|图片|动漫|动画|游戏|科幻|youtube|b站|bilibili|twitter|reddit|红迪|hacker news|知乎/i;
  return contentCue.test(text) && waterfallPreferenceEffect(' ' + text + ' ') !== '';
}

function removeWaterfallSourceAlias(text: string, alias: string): string {
  const value = alias.trim();
  if (value === 'x' || value === 'hn') {
    return text.replace(new RegExp('(^|\\s)' + value + '(?=\\s|的|内容|$)', 'ig'), ' ');
  }
  return text.replace(new RegExp(value, 'ig'), ' ');
}

function pushWaterfallRule(
  rules: WaterfallExplicitPreference[],
  dimension: 'topic' | 'source' | 'format',
  key: string,
  effect: 'block' | 'downweight' | 'boost'
): void {
  for (let index = 0; index < rules.length; index += 1) {
    if (rules[index].dimension === dimension && rules[index].key === key) return;
  }
  rules.push({ dimension, key, effect });
}

export function waterfallExplicitPreferencesFromStatement(statement: string): WaterfallExplicitPreference[] {
  if (!isStableWaterfallContentPreference(statement)) return [];
  const effect = waterfallPreferenceEffect(' ' + statement + ' ') as 'block' | 'downweight' | 'boost';
  const rules: WaterfallExplicitPreference[] = [];
  let topic = statement.trim();
  const lower = ' ' + statement.toLowerCase() + ' ';
  WATERFALL_SOURCE_ALIASES.forEach((alias: string[]): void => {
    if (lower.indexOf(alias[0]) < 0) return;
    pushWaterfallRule(rules, 'source', alias[1], effect);
    topic = removeWaterfallSourceAlias(topic, alias[0]);
  });
  if (/视频/.test(topic)) {
    pushWaterfallRule(rules, 'format', 'landscape_video', effect);
    pushWaterfallRule(rules, 'format', 'portrait_video', effect);
    topic = topic.replace(/视频/g, ' ');
  }
  if (/图文|图片/.test(topic)) {
    pushWaterfallRule(rules, 'format', 'image_text', effect);
    topic = topic.replace(/图文|图片/g, ' ');
  }
  if (/文章|文字/.test(topic)) {
    pushWaterfallRule(rules, 'format', 'text', effect);
    topic = topic.replace(/文章|文字/g, ' ');
  }
  topic = topic.replace(/以后|我|不要|不看|别推荐|不喜欢|少看|少推荐|少给我看|喜欢|多看|多推荐|优先推荐|给|的内容|内容/g, ' ')
    .replace(/\s+/g, ' ').trim();
  if (topic.length > 0) pushWaterfallRule(rules, 'topic', topic, effect);
  return rules;
}

export function waterfallExplicitPreferencesFromMemory(memory: string): WaterfallExplicitPreference[] {
  const section = markdownSectionValue(parsePersonaMarkdown(memory).sections, 'Stable Preferences');
  const rules: WaterfallExplicitPreference[] = [];
  section.split('\n').forEach((line: string): void => {
    const statement = line.replace(/^\s*[-*]\s*/, '').trim();
    waterfallExplicitPreferencesFromStatement(statement).forEach(
      (rule: WaterfallExplicitPreference): void => pushWaterfallRule(
        rules, rule.dimension, rule.key, rule.effect));
  });
  return rules;
}

export function mergePersonaStablePreference(memory: string, statement: string): string {
  const value: string = durableStatement(statement);
  if (value.length === 0) {
    return memory;
  }
  const normalized: string = memory.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines: string[] = normalized.split('\n');
  let stableIndex: number = -1;
  let nextSectionIndex: number = lines.length;
  for (let index: number = 0; index < lines.length; index++) {
    if (lines[index].trim() === '## Stable Preferences') {
      stableIndex = index;
      continue;
    }
    if (stableIndex >= 0 && lines[index].indexOf('## ') === 0) {
      nextSectionIndex = index;
      break;
    }
  }
  const entry: string = '- ' + value;
  if (stableIndex < 0) {
    let evidenceIndex: number = -1;
    for (let index: number = 0; index < lines.length; index++) {
      if (lines[index].trim() === '## Evidence') {
        evidenceIndex = index;
        break;
      }
    }
    if (evidenceIndex >= 0) {
      while (evidenceIndex > 0 && lines[evidenceIndex - 1].trim().length === 0) {
        evidenceIndex--;
      }
      lines.splice(evidenceIndex, 0, '## Stable Preferences', entry, '');
      return lines.join('\n');
    }
    const separator: string = normalized.trim().length === 0 ? '' : '\n\n';
    return normalized.trimEnd() + separator + '## Stable Preferences\n' + entry;
  }
  for (let index: number = stableIndex + 1; index < nextSectionIndex; index++) {
    if (lines[index].trim() === entry) {
      return normalized;
    }
  }
  while (nextSectionIndex > stableIndex + 1 && lines[nextSectionIndex - 1].trim().length === 0) {
    nextSectionIndex--;
  }
  lines.splice(nextSectionIndex, 0, entry, '');
  return lines.join('\n');
}

export function memoryUpdateSurface(surfaceId: string, update: PersonaMemoryUpdateRequest): A2uiSurfaceState {
  const pack = personaPackForId(update.personaId);
  const rows: A2uiLabelValueData[] = [
    { label: '已记录', value: update.summary },
    { label: '原因', value: update.reason.length > 0 ? update.reason : '用户更新了该分身的长期偏好。' },
    { label: 'Memory 摘要', value: markdownSummary(update.memoryText, 'Stable Preferences') },
    { label: 'Soul 摘要', value: markdownSummary(pack.soul, 'Identity') }
  ];
  const persona: A2uiPersonaData = {
    id: pack.manifest.id,
    name: pack.manifest.name,
    avatarKey: pack.manifest.avatarKey,
    status: 'online',
    reason: update.reason.length > 0 ? update.reason : '用户更新了该分身的长期偏好。'
  };
  const personaMemory: A2uiPersonaMemoryData = {
    summary: '已记录：' + update.summary,
    preferences: [update.summary]
  };
  const root: A2uiComponent = {
    id: 'root',
    component: 'SurfaceRoot',
    child: 'memory_update',
    title: pack.manifest.name + '已更新记忆',
    status: 'ready'
  };
  const card: A2uiComponent = {
    id: 'memory_update',
    component: 'InfoRows',
    title: pack.manifest.name + '已更新记忆',
    status: 'ready',
    dataPath: '/rows',
    actions: cardActions(update)
  };
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: pack.manifest.name + '已更新记忆',
    intent: 'persona.memory.update',
    status: 'ready',
    components: [root, card],
    dataModelJson: JSON.stringify({
      rows: rows,
      persona: persona,
      personaMemory: personaMemory
    }),
    error: '',
    sequence: Date.now()
  };
}
