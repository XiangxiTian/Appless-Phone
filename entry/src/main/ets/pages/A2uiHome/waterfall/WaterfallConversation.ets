import {
  aggregateSearchInterestSourceIds,
  WATERFALL_PREFERENCE_TOOL_ID,
  WaterfallExplicitPreference
} from '@loop/agent-core';

export type WaterfallPreferenceOperation = 'adjust' | 'undo' | 'reset';
export type WaterfallPreferenceState = 'boost' | 'downweight' | 'neutral';

export interface WaterfallPreferenceItem {
  dimension: 'topic' | 'source' | 'format';
  key: string;
  state: WaterfallPreferenceState;
}

export interface WaterfallPreferenceAdjustment {
  operation: WaterfallPreferenceOperation;
  summary: string;
  preferences: WaterfallPreferenceItem[];
}

export interface WaterfallConversationSnapshot {
  rules: WaterfallExplicitPreference[];
  summary: string;
}

export interface WaterfallConversationState {
  history: WaterfallConversationSnapshot[];
  rules: WaterfallExplicitPreference[];
  summary: string;
}

export interface WaterfallPreferenceTagEvidence {
  behavior: 'play_complete' | 'read_complete' | 'dwell' | 'quick_skip';
  durationMs: number;
  timestamp: number;
}

export interface WaterfallPreferenceTagContent {
  title: string;
  source: string;
  format: string;
  behavior: string;
  durationMs: number;
}

export interface WaterfallPreferenceTagGenerationInput {
  currentTags: string[];
  lockedTags: string[];
  explicitRules: WaterfallExplicitPreference[];
  positiveTopics: string[];
  rejectedTopics: string[];
  personaInterests: string[];
  personaExpertise: string[];
  personaRecentFocus: string[];
  recentContent: WaterfallPreferenceTagContent[];
}

const SOURCES: string[] = aggregateSearchInterestSourceIds();
const FORMATS: string[] = ['landscape_video', 'portrait_video', 'image_text', 'text'];
const MAX_PREFERENCES: number = 8;
const MAX_HISTORY: number = 8;
const DEFAULT_PREFERENCE_TAGS: string[] = ['头条新闻', '科学技术', '商业', '娱乐'];
const MAX_VISIBLE_TAGS: number = 8;

export function waterfallPreferencePromptExample(selectedTags: string[], tags: string[]): string {
  let topic = selectedTags.length > 0 ? selectedTags[0].trim() : '';
  for (let index = 0; topic.length === 0 && index < tags.length; index++) {
    const tag = tags[index].trim();
    if (tag.length > 0 && DEFAULT_PREFERENCE_TAGS.indexOf(tag) < 0) topic = tag;
  }
  return '试试说：多给我推荐点' + (topic.length > 0 ? topic : '足球') + '内容';
}

export function waterfallPreferenceToolIsExclusive(requestedCapabilityIds: string[]): boolean {
  return requestedCapabilityIds.length === 1 &&
    requestedCapabilityIds[0] === WATERFALL_PREFERENCE_TOOL_ID;
}

export function waterfallPreferenceTagSelected(
  rules: WaterfallExplicitPreference[],
  tag: string
): boolean {
  const key = tag.trim();
  return rules.some((rule: WaterfallExplicitPreference): boolean =>
    rule.dimension === 'topic' && rule.key === key && rule.effect === 'boost'
  );
}

export function waterfallVisiblePreferenceTags(
  rules: WaterfallExplicitPreference[],
  suggestions: string[] = []
): string[] {
  const negative: string[] = rules.filter((rule: WaterfallExplicitPreference): boolean =>
    rule.dimension === 'topic' && rule.effect !== 'boost'
  ).map((rule: WaterfallExplicitPreference): string => rule.key);
  const selected: string[] = rules.filter((rule: WaterfallExplicitPreference): boolean =>
    rule.dimension === 'topic' && rule.effect === 'boost' && negative.indexOf(rule.key) < 0
  ).map((rule: WaterfallExplicitPreference): string => rule.key);
  const base = suggestions.length > 0 ? suggestions : DEFAULT_PREFERENCE_TAGS;
  const result: string[] = [];
  selected.forEach((tag: string): void => {
    if (result.indexOf(tag) < 0) result.push(tag);
  });
  base.forEach((tag: string): void => {
    const clean = tag.trim();
    if (clean.length > 0 && clean.length <= 16 && negative.indexOf(clean) < 0 && result.indexOf(clean) < 0) {
      result.push(clean);
    }
  });
  while (result.length > MAX_VISIBLE_TAGS) {
    let removable = -1;
    for (let index = result.length - 1; index >= 0; index--) {
      if (selected.indexOf(result[index]) < 0) {
        removable = index;
        break;
      }
    }
    if (removable < 0) break;
    result.splice(removable, 1);
  }
  return result.slice(0, MAX_VISIBLE_TAGS);
}

export function parseWaterfallPreferenceTagSuggestions(raw: string): string[] | null {
  let text = raw.trim();
  if (text.startsWith('```') && text.endsWith('```')) {
    const firstBreak = text.indexOf('\n');
    text = firstBreak < 0 ? '' : text.substring(firstBreak + 1, text.length - 3).trim();
  }
  if (!text.startsWith('{') || !text.endsWith('}')) return null;
  try {
    const value = JSON.parse(text) as Record<string, Object>;
    if (value === null || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).join(',') !== 'tags' || !Array.isArray(value['tags'])) return null;
    const tags = value['tags'] as string[];
    if (tags.length < 1 || tags.length > 4) return null;
    const result: string[] = [];
    for (let index = 0; index < tags.length; index++) {
      if (typeof tags[index] !== 'string') return null;
      const tag = tags[index].trim();
      if (tag.length < 1 || tag.length > 16 || result.indexOf(tag) >= 0) return null;
      result.push(tag);
    }
    return result;
  } catch (_error) {
    return null;
  }
}

export function mergeWaterfallPreferenceTagSuggestions(
  currentTags: string[],
  generatedTags: string[]
): string[] {
  const kept = currentTags.slice(0, Math.max(0, 4 - generatedTags.length));
  const merged: string[] = [];
  kept.concat(generatedTags, currentTags).forEach((tag: string): void => {
    const clean = tag.trim();
    if (clean.length > 0 && clean.length <= 16 && merged.indexOf(clean) < 0 && merged.length < 4) {
      merged.push(clean);
    }
  });
  return merged;
}

export function waterfallPreferenceTagsDue(
  evidence: WaterfallPreferenceTagEvidence[],
  lastEvidenceAt: number,
  dirty: boolean,
  lastAttemptedEvidenceAt: number = 0,
  dirtyRevision: number = 0,
  lastAttemptedDirtyRevision: number = -1
): boolean {
  if (dirty && dirtyRevision !== lastAttemptedDirtyRevision) return true;
  const fresh = evidence.filter((item: WaterfallPreferenceTagEvidence): boolean =>
    item.timestamp > Math.max(lastEvidenceAt, lastAttemptedEvidenceAt));
  return fresh.filter((item: WaterfallPreferenceTagEvidence): boolean =>
    item.behavior === 'play_complete' || item.behavior === 'read_complete' ||
      (item.behavior === 'dwell' && item.durationMs >= 8000)).length >= 1;
}

export function waterfallPreferenceTagPrompt(input: WaterfallPreferenceTagGenerationInput): string {
  return '为发现流生成4个简短中文兴趣标签。可保留现有标签，也可按证据替换一个或多个；' +
    'recentContent按新到旧排列；阅读/播放完成及8秒以上停留是强信号，快速划过仅作弱证据。' +
    '若最新强信号指向可信具体主题且现有标签未覆盖，必须用该主题替换一个证据最弱的标签；' +
    '否则可全部保留，不得仅为变化强制替换。' +
    '兼顾宽泛领域与具体兴趣，不得输出敏感属性，不得包含lockedTags或rejectedTopics。' +
    '只输出严格JSON：{"tags":["标签1","标签2","标签3","标签4"]}。\nINPUT=' + JSON.stringify(input);
}

export function waterfallPreferenceTagAdjustment(
  rawTag: string,
  selected: boolean
): WaterfallPreferenceAdjustment | null {
  const tag = rawTag.trim();
  if (tag.length === 0 || tag.length > 16) return null;
  return {
    operation: 'adjust',
    summary: selected ? tag + '已恢复正常' : tag + '内容会多一些',
    preferences: [{ dimension: 'topic', key: tag, state: selected ? 'neutral' : 'boost' }]
  };
}

export function waterfallImmediatePreferenceRecallQuery(
  adjustment: WaterfallPreferenceAdjustment,
  preferenceChanged: boolean = true,
  mode: 'interest' | 'search' = 'interest'
): string {
  if (!preferenceChanged || mode !== 'interest') return '';
  if (adjustment.operation !== 'adjust' || adjustment.preferences.length !== 1) return '';
  const preference = adjustment.preferences[0];
  return preference.dimension === 'topic' && preference.state === 'boost' ? preference.key.trim() : '';
}

function copyRule(rule: WaterfallExplicitPreference): WaterfallExplicitPreference {
  return { dimension: rule.dimension, key: rule.key, effect: rule.effect };
}

function copyRules(rules: WaterfallExplicitPreference[]): WaterfallExplicitPreference[] {
  return rules.map((rule: WaterfallExplicitPreference): WaterfallExplicitPreference => copyRule(rule));
}

function validOperation(value: string): boolean {
  return value === 'adjust' || value === 'undo' || value === 'reset';
}

function validItem(value: WaterfallPreferenceItem): boolean {
  if (value === null || typeof value !== 'object' || Array.isArray(value) ||
    Object.keys(value).sort().join(',') !== 'dimension,key,state' ||
    (value.dimension !== 'topic' && value.dimension !== 'source' && value.dimension !== 'format') ||
    (value.state !== 'boost' && value.state !== 'downweight' && value.state !== 'neutral') ||
    typeof value.key !== 'string') return false;
  const key = value.key.trim();
  if (key.length === 0 || key.length > 24) return false;
  if (value.dimension === 'source') return SOURCES.indexOf(key) >= 0;
  if (value.dimension === 'format') return FORMATS.indexOf(key) >= 0;
  return true;
}

function preferenceFeedback(
  operation: WaterfallPreferenceOperation,
  preferences: WaterfallPreferenceItem[]
): string {
  if (operation === 'undo') return '已撤销上次调整';
  if (operation === 'reset') return '推荐偏好已恢复正常';
  if (preferences.length !== 1 || preferences[0].dimension !== 'topic') return '推荐偏好已更新';
  const preference = preferences[0];
  if (preference.state === 'boost') return preference.key + '内容会多一些';
  if (preference.state === 'downweight') return preference.key + '内容会少一些';
  return preference.key + '已恢复正常';
}

export function parseWaterfallPreferenceToolInput(raw: string): WaterfallPreferenceAdjustment | null {
  const text = raw.trim();
  if (!text.startsWith('{') || !text.endsWith('}')) return null;
  try {
    const value = JSON.parse(text) as WaterfallPreferenceAdjustment;
    const keys = Object.keys(value).sort().join(',');
    if (value === null || typeof value !== 'object' || Array.isArray(value) ||
      (keys !== 'operation,preferences' && keys !== 'operation,preferences,summary') ||
      typeof value.operation !== 'string' || !validOperation(value.operation) ||
      (value.summary !== undefined && (typeof value.summary !== 'string' ||
        value.summary.trim().length === 0 || value.summary.trim().length > 48)) ||
      !Array.isArray(value.preferences) ||
      value.preferences.length > MAX_PREFERENCES ||
      !value.preferences.every((item: WaterfallPreferenceItem): boolean => validItem(item))) return null;
    if (value.operation === 'adjust' && value.preferences.length === 0) return null;
    if (value.operation !== 'adjust' && value.preferences.length !== 0) return null;
    const preferences = value.preferences.map((item: WaterfallPreferenceItem): WaterfallPreferenceItem => ({
      dimension: item.dimension,
      key: item.key.trim(),
      state: item.state
    }));
    return {
      operation: value.operation,
      summary: preferenceFeedback(value.operation, preferences),
      preferences
    };
  } catch (_error) {
    return null;
  }
}

function adjustedRules(
  current: WaterfallExplicitPreference[],
  preferences: WaterfallPreferenceItem[]
): WaterfallExplicitPreference[] {
  const result = copyRules(current);
  preferences.forEach((preference: WaterfallPreferenceItem): void => {
    for (let index = result.length - 1; index >= 0; index -= 1) {
      if (result[index].dimension === preference.dimension && result[index].key === preference.key) {
        result.splice(index, 1);
      }
    }
    if (preference.state !== 'neutral') {
      result.push({
        dimension: preference.dimension,
        key: preference.key,
        effect: preference.state
      });
    }
  });
  return result.slice(Math.max(0, result.length - MAX_PREFERENCES));
}

function sameRules(left: WaterfallExplicitPreference[], right: WaterfallExplicitPreference[]): boolean {
  if (left.length !== right.length) return false;
  for (let index = 0; index < left.length; index += 1) {
    if (left[index].dimension !== right[index].dimension || left[index].key !== right[index].key ||
      left[index].effect !== right[index].effect) return false;
  }
  return true;
}

export function applyWaterfallPreferenceAdjustment(
  state: WaterfallConversationState,
  adjustment: WaterfallPreferenceAdjustment
): WaterfallConversationState {
  if (adjustment.operation === 'reset') {
    if (state.rules.length === 0) {
      return { history: state.history.slice(), rules: [], summary: adjustment.summary };
    }
    return {
      history: state.history.concat([{ rules: [], summary: adjustment.summary }])
        .slice(Math.max(0, state.history.length + 1 - MAX_HISTORY)),
      rules: [],
      summary: adjustment.summary
    };
  }
  if (adjustment.operation === 'undo') {
    if (state.history.length <= 1) {
      return { history: state.history.slice(), rules: copyRules(state.rules), summary: adjustment.summary };
    }
    const history = state.history.slice(0, Math.max(0, state.history.length - 1));
    const previous = history.length === 0 ? null : history[history.length - 1];
    return {
      history,
      rules: previous === null ? [] : copyRules(previous.rules),
      summary: adjustment.summary
    };
  }
  const rules = adjustedRules(state.rules, adjustment.preferences);
  if (sameRules(state.rules, rules)) {
    return { history: state.history.slice(), rules, summary: adjustment.summary };
  }
  const history = state.history.concat([{ rules: copyRules(rules), summary: adjustment.summary }]);
  return {
    history: history.slice(Math.max(0, history.length - MAX_HISTORY)),
    rules,
    summary: adjustment.summary
  };
}
