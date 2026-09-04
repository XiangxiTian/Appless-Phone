import { WaterfallCandidate, WaterfallColdStartTopic, WaterfallPreferenceWeight } from '@loop/agent-core';

export const WATERFALL_LLM_PROFILE_KEY: string = 'llm_profile.v1';
export const WATERFALL_LLM_BATCH_SIZE: number = 5;
export const WATERFALL_LLM_BATCH_MAX_WAIT_MS: number = 30000;
export const WATERFALL_LLM_RESPONSE_FORMAT_JSON: string = '{"type":"json_schema","json_schema":{' +
  '"name":"waterfall_interest_keywords","strict":true,"schema":{"type":"object",' +
  '"additionalProperties":false,"required":["tasks"],"properties":{"tasks":{"type":"array",' +
  '"items":{"type":"object","additionalProperties":false,"required":["taskId","keywords"],' +
  '"properties":{"taskId":{"type":"string"},"keywords":{"type":"array","minItems":3,"maxItems":3,' +
  '"items":{"type":"object","additionalProperties":false,"required":["zh","en"],' +
  '"properties":{"zh":{"type":"string"},"en":{"type":"string"}}}}}}}}}}}';

export interface WaterfallLlmKeyword {
  id: string;
  zh: string;
  en: string;
  heat: number;
  updatedAt: number;
  searchSeeded: boolean;
}

export interface WaterfallLlmCardTask {
  taskId: string;
  candidateId: string;
  title: string;
  summary: string;
  heat: number;
  appliedHeat: number;
  keywordIds: string[];
  completed: boolean;
  updatedAt: number;
}

export interface WaterfallLlmProfile {
  version: number;
  tasks: WaterfallLlmCardTask[];
  keywords: WaterfallLlmKeyword[];
  updatedAt: number;
}

export interface WaterfallLlmKeywordPair {
  zh: string;
  en: string;
}

export interface WaterfallLlmTaskOutput {
  taskId: string;
  keywords: WaterfallLlmKeywordPair[];
}

export interface WaterfallLlmBatchResult {
  profile: WaterfallLlmProfile;
  priorityTopics: WaterfallColdStartTopic[];
}

interface JsonKeywordPair { zh?: string; en?: string; }
interface JsonTaskOutput { taskId?: string; keywords?: JsonKeywordPair[]; }
interface JsonBatchOutput { tasks?: JsonTaskOutput[]; }
interface WaterfallLlmPromptTask { taskId: string; title: string; summary: string; }

function clean(value: string, limit: number = 80): string {
  return value.trim().replace(/\s+/g, ' ').substring(0, limit);
}

function normalized(value: string): string {
  return clean(value).toLowerCase();
}

function copyKeyword(value: WaterfallLlmKeyword): WaterfallLlmKeyword {
  return { id: value.id, zh: value.zh, en: value.en, heat: value.heat,
    updatedAt: value.updatedAt, searchSeeded: value.searchSeeded };
}

function copyTask(value: WaterfallLlmCardTask): WaterfallLlmCardTask {
  return { taskId: value.taskId, candidateId: value.candidateId, title: value.title,
    summary: value.summary, heat: value.heat, appliedHeat: value.appliedHeat,
    keywordIds: value.keywordIds.slice(), completed: value.completed, updatedAt: value.updatedAt };
}

export function emptyWaterfallLlmProfile(): WaterfallLlmProfile {
  return { version: 1, tasks: [], keywords: [], updatedAt: 0 };
}

export function copyWaterfallLlmProfile(value: WaterfallLlmProfile): WaterfallLlmProfile {
  return { version: 1, tasks: value.tasks.map(copyTask), keywords: value.keywords.map(copyKeyword),
    updatedAt: value.updatedAt };
}

export function parseWaterfallLlmProfile(raw: string): WaterfallLlmProfile {
  if (raw.trim().length === 0) return emptyWaterfallLlmProfile();
  try {
    const value = JSON.parse(raw) as WaterfallLlmProfile;
    if (value.version !== 1 || !Array.isArray(value.tasks) || !Array.isArray(value.keywords)) {
      return emptyWaterfallLlmProfile();
    }
    const tasks = value.tasks.filter((task: WaterfallLlmCardTask): boolean =>
      typeof task.taskId === 'string' && typeof task.candidateId === 'string' &&
      typeof task.title === 'string' && typeof task.summary === 'string' &&
      typeof task.heat === 'number' && typeof task.appliedHeat === 'number' &&
      Array.isArray(task.keywordIds) && typeof task.completed === 'boolean' &&
      typeof task.updatedAt === 'number').map(copyTask);
    const keywords = value.keywords.filter((keyword: WaterfallLlmKeyword): boolean =>
      typeof keyword.id === 'string' && typeof keyword.zh === 'string' && typeof keyword.en === 'string' &&
      typeof keyword.heat === 'number' && typeof keyword.updatedAt === 'number' &&
      typeof keyword.searchSeeded === 'boolean').map(copyKeyword);
    return { version: 1, tasks, keywords, updatedAt: Number.isFinite(value.updatedAt) ? value.updatedAt : 0 };
  } catch (_error) {
    return emptyWaterfallLlmProfile();
  }
}

export function waterfallLlmSignalHeat(signal: 'dwell' | 'open' | 'like'): number {
  if (signal === 'like') return 5;
  if (signal === 'open') return 3;
  return 1;
}

export function recordWaterfallLlmSignal(
  source: WaterfallLlmProfile,
  candidate: WaterfallCandidate,
  signal: 'dwell' | 'open' | 'like',
  nowMs: number
): WaterfallLlmProfile {
  const profile = copyWaterfallLlmProfile(source);
  const heat = waterfallLlmSignalHeat(signal);
  let task = profile.tasks.find((item: WaterfallLlmCardTask): boolean => item.candidateId === candidate.id);
  if (task === undefined) {
    task = { taskId: 'card-' + nowMs.toString() + '-' + profile.tasks.length.toString(),
      candidateId: candidate.id, title: clean(candidate.title, 240), summary: clean(candidate.summary, 500),
      heat, appliedHeat: 0, keywordIds: [], completed: false, updatedAt: nowMs };
    profile.tasks.push(task);
  } else if (heat > task.heat) {
    task.heat = heat;
    task.updatedAt = nowMs;
  }
  if (task.completed && task.heat > task.appliedHeat) {
    const delta = task.heat - task.appliedHeat;
    task.keywordIds.forEach((keywordId: string): void => {
      const keyword = profile.keywords.find((item: WaterfallLlmKeyword): boolean => item.id === keywordId);
      if (keyword !== undefined) { keyword.heat += delta; keyword.updatedAt = nowMs; }
    });
    task.appliedHeat = task.heat;
  }
  if (profile.tasks.length > 500) profile.tasks = profile.tasks.slice(profile.tasks.length - 500);
  profile.updatedAt = nowMs;
  return profile;
}

export function pendingWaterfallLlmTasks(profile: WaterfallLlmProfile): WaterfallLlmCardTask[] {
  return profile.tasks.filter((task: WaterfallLlmCardTask): boolean => !task.completed).map(copyTask);
}

export function waterfallLlmBatchPrompt(tasks: WaterfallLlmCardTask[]): string {
  const input = tasks.map((task: WaterfallLlmCardTask): WaterfallLlmPromptTask => ({
    taskId: task.taskId, title: task.title, summary: task.summary
  }));
  return '你是内容推荐关键词抽取器。为每个任务提取恰好三个具体、可搜索的兴趣关键词。' +
    '每个关键词必须同时给出简体中文和英文，两个语言表达同一概念。不要输出泛词、平台名或解释。' +
    '严格只输出满足此 schema 的 JSON：' +
    '{"tasks":[{"taskId":"string","keywords":[{"zh":"string","en":"string"},' +
    '{"zh":"string","en":"string"},{"zh":"string","en":"string"}]}]}。输入：' + JSON.stringify(input);
}

export function parseWaterfallLlmBatchOutput(raw: string, tasks: WaterfallLlmCardTask[]): WaterfallLlmTaskOutput[] {
  try {
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return [];
    const parsed = JSON.parse(raw.substring(start, end + 1)) as JsonBatchOutput;
    if (!Array.isArray(parsed.tasks) || parsed.tasks.length !== tasks.length) return [];
    const result: WaterfallLlmTaskOutput[] = [];
    const usedTaskIds: string[] = [];
    for (let index = 0; index < parsed.tasks.length; index += 1) {
      const item = parsed.tasks[index];
      const expected = tasks.find((task: WaterfallLlmCardTask): boolean => task.taskId === item.taskId);
      if (expected === undefined || usedTaskIds.indexOf(item.taskId as string) >= 0 ||
        !Array.isArray(item.keywords) || item.keywords.length !== 3) return [];
      usedTaskIds.push(item.taskId as string);
      const pairs: WaterfallLlmKeywordPair[] = [];
      const usedKeywords: string[] = [];
      for (let pairIndex = 0; pairIndex < item.keywords.length; pairIndex += 1) {
        const pair = item.keywords[pairIndex];
        if (typeof pair.zh !== 'string' || typeof pair.en !== 'string') return [];
        const zh = clean(pair.zh);
        const en = clean(pair.en);
        if (zh.length === 0 || en.length === 0) return [];
        const identity = normalized(zh) + '|' + normalized(en);
        if (usedKeywords.indexOf(identity) >= 0) return [];
        usedKeywords.push(identity);
        pairs.push({ zh, en });
      }
      result.push({ taskId: item.taskId as string, keywords: pairs });
    }
    return result;
  } catch (_error) {
    return [];
  }
}

function findKeyword(profile: WaterfallLlmProfile, pair: WaterfallLlmKeywordPair): WaterfallLlmKeyword | undefined {
  const zh = normalized(pair.zh);
  const en = normalized(pair.en);
  return profile.keywords.find((item: WaterfallLlmKeyword): boolean =>
    normalized(item.zh) === zh || normalized(item.en) === en);
}

export function applyWaterfallLlmBatch(
  source: WaterfallLlmProfile,
  output: WaterfallLlmTaskOutput[],
  nowMs: number
): WaterfallLlmBatchResult {
  const profile = copyWaterfallLlmProfile(source);
  const priorityTopics: WaterfallColdStartTopic[] = [];
  output.forEach((item: WaterfallLlmTaskOutput): void => {
    const task = profile.tasks.find((candidate: WaterfallLlmCardTask): boolean =>
      candidate.taskId === item.taskId && !candidate.completed);
    if (task === undefined || item.keywords.length !== 3) return;
    item.keywords.forEach((pair: WaterfallLlmKeywordPair): void => {
      let keyword = findKeyword(profile, pair);
      if (keyword === undefined) {
        keyword = { id: 'keyword-' + nowMs.toString() + '-' + profile.keywords.length.toString(),
          zh: clean(pair.zh), en: clean(pair.en), heat: 0, updatedAt: nowMs, searchSeeded: false };
        profile.keywords.push(keyword);
      }
      keyword.heat += task.heat;
      keyword.updatedAt = nowMs;
      if (task.keywordIds.indexOf(keyword.id) < 0) task.keywordIds.push(keyword.id);
      if (!keyword.searchSeeded) {
        keyword.searchSeeded = true;
        priorityTopics.push({ id: keyword.id, domesticQuery: keyword.zh, globalQuery: keyword.en });
      }
    });
    task.appliedHeat = task.heat;
    task.completed = true;
    task.title = '';
    task.summary = '';
    task.updatedAt = nowMs;
  });
  if (profile.keywords.length > 1000) {
    profile.keywords.sort((left: WaterfallLlmKeyword, right: WaterfallLlmKeyword): number =>
      right.heat - left.heat || right.updatedAt - left.updatedAt);
    profile.keywords = profile.keywords.slice(0, 1000);
  }
  profile.updatedAt = nowMs;
  return { profile, priorityTopics };
}

export function waterfallLlmTopWeights(profile: WaterfallLlmProfile, limit: number = 10): WaterfallPreferenceWeight[] {
  const ranked = profile.keywords.slice().sort(
    (left: WaterfallLlmKeyword, right: WaterfallLlmKeyword): number =>
      right.heat - left.heat || right.updatedAt - left.updatedAt || left.id.localeCompare(right.id)
  ).slice(0, Math.max(0, limit));
  const maximum = ranked.length > 0 ? Math.max(1, ranked[0].heat) : 1;
  return ranked.map((keyword: WaterfallLlmKeyword): WaterfallPreferenceWeight => ({
    key: keyword.zh,
    aliases: [keyword.en],
    weight: keyword.heat * 10 / maximum,
    updatedAt: keyword.updatedAt
  }));
}

/** Ranking deliberately ignores heat: heat controls recall volume, not repeated exposure. */
export function waterfallLlmTopEqualWeights(
  profile: WaterfallLlmProfile,
  limit: number = 10
): WaterfallPreferenceWeight[] {
  return waterfallLlmTopWeights(profile, limit).map(
    (weight: WaterfallPreferenceWeight): WaterfallPreferenceWeight => ({
      key: weight.key,
      aliases: weight.aliases === undefined ? undefined : weight.aliases.slice(),
      weight: 1,
      updatedAt: weight.updatedAt
    })
  );
}
