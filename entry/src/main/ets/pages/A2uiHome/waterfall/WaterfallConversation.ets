import { WaterfallExplicitPreference } from '@loop/agent-core';
import { waterfallExplicitPreferencesFromStatement } from '../../../model/PersonaMemoryUpdate';

export type WaterfallConversationOperation = 'apply' | 'undo' | 'reset';

export interface WaterfallConversationCommand {
  operation: WaterfallConversationOperation;
  summary: string;
  rules: WaterfallExplicitPreference[];
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

const SOURCES: string[] = ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'];
const FORMATS: string[] = ['landscape_video', 'portrait_video', 'image_text', 'text'];
const MAX_RULES: number = 8;
const MAX_HISTORY: number = 8;

function copyRule(rule: WaterfallExplicitPreference): WaterfallExplicitPreference {
  return { dimension: rule.dimension, key: rule.key, effect: rule.effect };
}

function copyRules(rules: WaterfallExplicitPreference[]): WaterfallExplicitPreference[] {
  return rules.map((rule: WaterfallExplicitPreference): WaterfallExplicitPreference => copyRule(rule));
}

function validRule(rule: WaterfallExplicitPreference): boolean {
  if (rule === null || (rule.dimension !== 'topic' && rule.dimension !== 'source' && rule.dimension !== 'format') ||
    (rule.effect !== 'block' && rule.effect !== 'downweight' && rule.effect !== 'boost') ||
    typeof rule.key !== 'string') return false;
  const key = rule.key.trim();
  if (key.length === 0 || key.length > 24) return false;
  if (rule.dimension === 'source') return SOURCES.indexOf(key) >= 0;
  if (rule.dimension === 'format') return FORMATS.indexOf(key) >= 0;
  return true;
}

function validOperation(value: string): boolean {
  return value === 'apply' || value === 'undo' || value === 'reset';
}

export function parseWaterfallConversationCommand(raw: string): WaterfallConversationCommand | null {
  const text = raw.trim();
  if (!text.startsWith('{') || !text.endsWith('}')) return null;
  try {
    const value = JSON.parse(text) as WaterfallConversationCommand;
    if (value === null || typeof value.operation !== 'string' || !validOperation(value.operation) ||
      typeof value.summary !== 'string' || value.summary.trim().length === 0 || value.summary.trim().length > 48 ||
      !Array.isArray(value.rules) || value.rules.length > MAX_RULES ||
      !value.rules.every((rule: WaterfallExplicitPreference): boolean => validRule(rule))) return null;
    if (value.operation === 'apply' && value.rules.length === 0) return null;
    if (value.operation !== 'apply' && value.rules.length !== 0) return null;
    return {
      operation: value.operation,
      summary: value.summary.trim(),
      rules: copyRules(value.rules)
    };
  } catch (_error) {
    return null;
  }
}

export function directWaterfallConversationCommand(text: string): WaterfallConversationCommand | null {
  const value = text.trim().replace(/[。！!，,]$/g, '');
  if (value === '撤销' || value === '撤销刚才调整' || value === '撤销刚才的调整') {
    return { operation: 'undo', summary: '已撤销刚才调整', rules: [] };
  }
  if (value === '恢复默认' || value === '清除调整' || value === '重置发现流') {
    return { operation: 'reset', summary: '已恢复默认', rules: [] };
  }
  const rules: WaterfallExplicitPreference[] = [];
  const clauses = value.split(/[。；;，,]/);
  for (let index = 0; index < clauses.length; index += 1) {
    const clause = clauses[index].trim().replace(/^接下来/, '');
    if (clause.length === 0) continue;
    let effectCount = 0;
    if (/不要|不看|别推荐|不喜欢/.test(clause)) effectCount += 1;
    if (/少看|少推荐|少给我看/.test(clause)) effectCount += 1;
    if (/多看|多推荐|优先推荐|喜欢/.test(clause.replace(/不喜欢/g, ''))) effectCount += 1;
    const clauseRules = waterfallExplicitPreferencesFromStatement(clause);
    if (effectCount !== 1 || clauseRules.length === 0) return null;
    clauseRules.forEach(
      (rule: WaterfallExplicitPreference): void => {
        if (validRule(rule)) rules.push(copyRule(rule));
      });
  }
  const localRules = mergedRules([], rules);
  if (localRules.length > 0) {
    return { operation: 'apply', summary: '已按你的想法调整', rules: localRules };
  }
  return null;
}

function mergedRules(
  current: WaterfallExplicitPreference[],
  additions: WaterfallExplicitPreference[]
): WaterfallExplicitPreference[] {
  const result = copyRules(current);
  additions.forEach((addition: WaterfallExplicitPreference): void => {
    for (let index = result.length - 1; index >= 0; index -= 1) {
      if (result[index].dimension === addition.dimension && result[index].key === addition.key) result.splice(index, 1);
    }
    result.push(copyRule(addition));
  });
  return result.slice(Math.max(0, result.length - MAX_RULES));
}

export function applyWaterfallConversationCommand(
  state: WaterfallConversationState,
  command: WaterfallConversationCommand
): WaterfallConversationState {
  if (command.operation === 'reset') return { history: [], rules: [], summary: command.summary };
  if (command.operation === 'undo') {
    const history = state.history.slice(0, Math.max(0, state.history.length - 1));
    const previous = history.length === 0 ? null : history[history.length - 1];
    return {
      history,
      rules: previous === null ? [] : copyRules(previous.rules),
      summary: previous === null ? command.summary : previous.summary
    };
  }
  const rules = mergedRules(state.rules, command.rules);
  const history = state.history.concat([{ rules: copyRules(rules), summary: command.summary }]);
  return {
    history: history.slice(Math.max(0, history.length - MAX_HISTORY)),
    rules,
    summary: command.summary
  };
}

export function waterfallConversationPrompt(text: string): string {
  const utterance = text.trim().slice(0, 200);
  return '把用户对发现流的调整编译成一行 JSON，不要解释。' +
    'schema={"operation":"apply","summary":"中文短句","rules":[{"dimension":"topic|source|format",' +
    '"key":"值","effect":"boost|downweight|block"}]}。' +
    'source 只能是 youtube,bilibili,x,hackernews,reddit,zhihu；format 只能是 landscape_video,' +
    'portrait_video,image_text,text；最多 8 条。不要把某个来源或视频设为默认优先。用户原话=' +
    JSON.stringify(utterance);
}
