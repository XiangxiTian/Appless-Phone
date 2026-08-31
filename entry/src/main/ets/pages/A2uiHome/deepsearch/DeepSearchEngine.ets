import {
  A2uiLabelValueData,
  aiLogError,
  aiLogInfo,
  DynamicGenericToolResult,
  FirecrawlToolOutput
} from '@loop/agent-core';

export const DEEP_SEARCH_ROUTE_URL: string = 'pages/A2uiHome/DeepSearch';

export interface DeepSearchRouteParams {
  query: string;
  provider: string;
  baseUrl: string;
  model: string;
  apiKey: string;
  customParametersJson: string;
}

export type DeepSearchStageStatus = 'pending' | 'running' | 'done' | 'warn' | 'error';

export type DeepSearchComplexity = 'simple' | 'complex';

export interface DeepSearchIntentPlan {
  subQueries: string[];
  complexity: DeepSearchComplexity;
}

export interface DeepSearchStageView {
  id: string;
  title: string;
  status: DeepSearchStageStatus;
  detail: string;
  lines: string[];
  elapsedMs: number;
}

export interface DeepSearchSourceView {
  title: string;
  url: string;
  summary: string;
  status: string;
  round: number;
  subQuery: string;
  deepRead: boolean;
}

export interface DeepSearchReportView {
  id: string;
  title: string;
  overview: string;
  findings: string[];
  sources: DeepSearchSourceView[];
  confidence: string;
  expanded: boolean;
}

export interface DeepSearchProgress {
  stages: DeepSearchStageView[];
  sources: DeepSearchSourceView[];
  reports: DeepSearchReportView[];
  answer: string;
  complexity: DeepSearchComplexity;
  modelStatus: string;
  running: boolean;
  error: string;
}

/**
 * 用户侧上下文：位置与时间。启动 DeepSearch 时由宿主获取并注入，
 * 使检索能结合用户所在城市与当天日期回答（如天气、本地信息、当日新闻）。
 * 任一字段缺失时引擎只注入已提供的部分，不会阻断搜索。
 */
export interface DeepSearchContext {
  locationLabel: string;
  dateLabel: string;
  coordinateLabel: string;
}

export interface DeepSearchPorts {
  search: (query: string, recency: string, maxResults: number) => Promise<FirecrawlToolOutput>;
  readPage: (url: string, question: string) => Promise<FirecrawlToolOutput>;
  llm: (systemPrompt: string, prompt: string) => Promise<string>;
}

export interface DeepSearchSearchRoundOutcome {
  sources: DeepSearchSourceView[];
  needsAuth: boolean;
  message: string;
}

export interface DeepSearchEvaluation {
  sufficient: boolean;
  gaps: string[];
}

interface DeepSearchIntentPlanRaw {
  subQueries?: string[];
  complexity?: string;
}

interface DeepSearchEvaluationRaw {
  sufficient?: boolean;
  gaps?: string[];
}

interface DeepSearchReportRaw {
  title?: string;
  overview?: string;
  findings?: string[];
  sourceIndexes?: number[];
}

interface DeepSearchReportsRaw {
  answer?: string;
  reports?: DeepSearchReportRaw[];
}

const STAGE_INTENT: string = 'intent';
const STAGE_SEARCH: string = 'search';
const STAGE_READ: string = 'read';
const STAGE_EVALUATE: string = 'evaluate';
const STAGE_REFINE: string = 'refine';
const STAGE_SYNTHESIZE: string = 'synthesize';

const OVERVIEW_TITLE: string = '网页研究综述';
const MAX_SUB_QUERIES: number = 4;
const RESULTS_PER_QUERY: number = 4;
const MAX_DEEP_READS: number = 4;
const MAX_GAP_QUERIES: number = 2;
const MAX_ANSWER_SOURCES: number = 12;
const MAX_REPORT_SOURCES: number = 3;
const MAX_REPORT_FINDINGS: number = 3;
const MAX_SIMPLE_REPORTS: number = 2;
const SUMMARY_CAP: number = 300;

const SIMPLE_QUERY_MARKERS: string[] = [
  '天气', '气温', '是什么', '是谁', '什么意思', '多少', '哪一年', '何时', '在哪',
  '怎么读', '怎么写', '汇率', '票价', '营业时间', '电话', '地址'
];
const COMPLEX_QUERY_MARKERS: string[] = [
  '局势', '趋势', '分析', '对比', '比较', '综述', '影响', '争议', '历史', '发展',
  '现状', '前景', '评价', '深度', '全面', '梳理', '盘点', '研究'
];

export function fallbackComplexityOf(query: string, subQueryCount: number): DeepSearchComplexity {
  const topic = query.trim();
  if (COMPLEX_QUERY_MARKERS.some((marker: string): boolean => topic.indexOf(marker) >= 0)) {
    return 'complex';
  }
  if (SIMPLE_QUERY_MARKERS.some((marker: string): boolean => topic.indexOf(marker) >= 0)) {
    return 'simple';
  }
  if (subQueryCount <= 1) {
    return 'simple';
  }
  return topic.length <= 12 && subQueryCount <= 2 ? 'simple' : 'complex';
}

export function genericFallbackSubQueries(query: string): string[] {
  const topic = query.trim();
  if (topic.length === 0) {
    return [];
  }
  const queries: string[] = [topic + ' 核心事实与定义'];
  const factualMarkers: string[] = ['谁', '哪些', '多少', '名单', '排名', '比较', '区别', '数据', '原因', '如何'];
  const controversyMarkers: string[] = ['争议', '质疑', '观点', '反对', '分歧', '风险'];
  const timeMarkers: string[] = ['时间线', '历年', '历史', '何时', '截至', '最新', '最近', '进展'];
  const caseMarkers: string[] = ['案例', '事件', '代表', '实例', '实践'];
  if (factualMarkers.some((marker: string): boolean => topic.indexOf(marker) >= 0)) {
    queries.push(topic + ' 权威来源与关键数据');
  }
  if (controversyMarkers.some((marker: string): boolean => topic.indexOf(marker) >= 0)) {
    queries.push(topic + ' 不同观点与争议');
  }
  if (timeMarkers.some((marker: string): boolean => topic.indexOf(marker) >= 0) ||
    caseMarkers.some((marker: string): boolean => topic.indexOf(marker) >= 0)) {
    queries.push(topic + ' 时间线与代表性案例');
  }
  return queries.slice(0, MAX_SUB_QUERIES);
}

/**
 * 将位置/日期上下文拼进搜索子查询：当问题涉及天气、时间、本地信息等
 * 与位置或日期强相关的内容时，为子查询补充城市与日期限定词。
 */
export function contextQualifiedSubQueries(
  subQueries: string[],
  context: DeepSearchContext | null
): string[] {
  if (context === null || context === undefined) {
    return subQueries;
  }
  const location = context.locationLabel.trim();
  const date = context.dateLabel.trim();
  if (location.length === 0 && date.length === 0) {
    return subQueries;
  }
  // 位置名的核心前缀（去掉常见后缀，如"深圳市"→"深圳"），用于识别查询是否已含位置。
  const locationCore = location.replace(/(省|市|区|县|州)$/g, '');
  const qualified: string[] = [];
  for (let index = 0; index < subQueries.length; index++) {
    const query = subQueries[index];
    const alreadyHasLocation = locationCore.length > 0 && query.indexOf(locationCore) >= 0;
    if (location.length > 0 && !alreadyHasLocation) {
      qualified.push(query + ' ' + location);
    } else {
      qualified.push(query);
    }
  }
  return qualified;
}

export function queryRecency(query: string): string {
  const normalized = query.trim();
  if (/(天气|气温|下雨|降雨)/.test(normalized)) {
    return '';
  }
  const currentMarkers: string[] = [
    '最新', '最近', '今日', '今天', '本周', '本月', '今年', '当前', '目前',
    '实时', '进展', '动态', '新闻', '发生了什么', '截至'
  ];
  for (let index = 0; index < currentMarkers.length; index++) {
    if (normalized.indexOf(currentMarkers[index]) >= 0) {
      return 'qdr:d';
    }
  }
  return '';
}

export function parseModelJsonText(raw: string): string {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    return '';
  }
  return raw.substring(start, end + 1);
}

export function intentPlanFromModelText(raw: string): DeepSearchIntentPlan | null {
  const jsonText = parseModelJsonText(raw);
  if (jsonText.length === 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(jsonText) as DeepSearchIntentPlanRaw;
    if (!Array.isArray(parsed.subQueries)) {
      return null;
    }
    const cleaned: string[] = [];
    for (let index = 0; index < parsed.subQueries.length; index++) {
      const item = parsed.subQueries[index];
      if (typeof item === 'string' && item.trim().length > 0 &&
        cleaned.indexOf(item.trim()) < 0) {
        cleaned.push(item.trim());
      }
    }
    if (cleaned.length === 0) {
      return null;
    }
    const subQueries = cleaned.slice(0, MAX_SUB_QUERIES);
    let complexity: DeepSearchComplexity;
    if (parsed.complexity === 'simple' || parsed.complexity === 'complex') {
      complexity = parsed.complexity;
    } else {
      complexity = subQueries.length <= 1 ? 'simple' : 'complex';
    }
    return { subQueries: subQueries, complexity: complexity };
  } catch (_error) {
    return null;
  }
}

export function subQueriesFromModelText(raw: string): string[] {
  const plan = intentPlanFromModelText(raw);
  return plan === null ? [] : plan.subQueries;
}

export function evaluationFromModelText(raw: string): DeepSearchEvaluation | null {
  const jsonText = parseModelJsonText(raw);
  if (jsonText.length === 0) {
    return null;
  }
  try {
    const parsed = JSON.parse(jsonText) as DeepSearchEvaluationRaw;
    if (typeof parsed.sufficient !== 'boolean') {
      return null;
    }
    const gaps: string[] = [];
    if (Array.isArray(parsed.gaps)) {
      for (let index = 0; index < parsed.gaps.length; index++) {
        const item = parsed.gaps[index];
        if (typeof item === 'string' && item.trim().length > 0) {
          gaps.push(item.trim());
        }
      }
    }
    return { sufficient: parsed.sufficient, gaps: gaps.slice(0, MAX_GAP_QUERIES) };
  } catch (_error) {
    return null;
  }
}

function rowValue(rows: A2uiLabelValueData[], label: string): string {
  for (let index = 0; index < rows.length; index++) {
    if (rows[index].label === label) {
      return rows[index].value;
    }
  }
  return '';
}

export function usableSource(source: DeepSearchSourceView): boolean {
  return (source.status === 'success' || source.status === 'partial') &&
    source.summary.trim().length > 0;
}

export function searchRoundOutcomeOf(
  output: FirecrawlToolOutput,
  subQuery: string,
  round: number
): DeepSearchSearchRoundOutcome {
  const sources: DeepSearchSourceView[] = [];
  const seenUrls: string[] = [];
  let needsAuth = false;
  let message = '';
  for (let index = 0; index < output.results.length; index++) {
    const result: DynamicGenericToolResult = output.results[index];
    if (result.status === 'needs_auth') {
      needsAuth = true;
      message = result.summary.trim().length > 0 ? result.summary : 'Firecrawl API key is required.';
      continue;
    }
    if (result.title === OVERVIEW_TITLE) {
      continue;
    }
    const url = rowValue(result.rows, 'URL').trim();
    if (url.length === 0) {
      if (message.length === 0 && result.summary.trim().length > 0 &&
        result.status !== 'success' && result.status !== 'partial') {
        message = result.summary.trim();
      }
      continue;
    }
    if (seenUrls.indexOf(url) >= 0) {
      continue;
    }
    seenUrls.push(url);
    const source: DeepSearchSourceView = {
      title: result.title,
      url: url,
      summary: result.summary,
      status: result.status,
      round: round,
      subQuery: subQuery,
      deepRead: false
    };
    if (!usableSource(source)) {
      if (message.length === 0 && source.summary.trim().length > 0) {
        message = source.summary.trim();
      }
      continue;
    }
    sources.push(source);
  }
  return { sources: sources, needsAuth: needsAuth, message: message };
}

export function fallbackGaps(subQueries: string[], sources: DeepSearchSourceView[]): string[] {
  const gaps: string[] = [];
  for (let index = 0; index < subQueries.length && gaps.length < MAX_GAP_QUERIES; index++) {
    const subQuery = subQueries[index];
    let usable = 0;
    for (let cursor = 0; cursor < sources.length; cursor++) {
      if (sources[cursor].subQuery === subQuery && usableSource(sources[cursor])) {
        usable++;
      }
    }
    if (usable === 0) {
      gaps.push(subQuery + ' 权威来源与反例');
    }
  }
  if (gaps.length === 0) {
    let totalUsable = 0;
    for (let cursor = 0; cursor < sources.length; cursor++) {
      if (usableSource(sources[cursor])) {
        totalUsable++;
      }
    }
    if (totalUsable < 3 && subQueries.length > 0) {
      gaps.push(subQueries[0] + ' 补充证据与来源');
    }
  }
  return gaps;
}

export function fallbackAnswer(
  query: string,
  sources: DeepSearchSourceView[],
  complexity: DeepSearchComplexity
): string {
  const reports = fallbackReports(sources, complexity);
  if (reports.length === 0) {
    return '未获得足够的可核验公开来源，无法可靠回答该问题。请检查搜索配置或稍后重试。';
  }
  if (complexity === 'simple') {
    const lines: string[] = [reports[0].overview];
    for (let findingIndex = 0; findingIndex < reports[0].findings.length; findingIndex++) {
      lines.push(reports[0].findings[findingIndex]);
    }
    return lines.join(' ');
  }
  const lines: string[] = [];
  lines.push('「' + query + '」已按主题整理。');
  for (let index = 0; index < reports.length; index++) {
    const report = reports[index];
    lines.push('');
    lines.push('◆ ' + report.title);
    lines.push(report.overview);
    for (let findingIndex = 0; findingIndex < report.findings.length; findingIndex++) {
      lines.push('- ' + report.findings[findingIndex]);
    }
  }
  return lines.join('\n');
}

function shortText(value: string, cap: number): string {
  const normalized = value.trim().replace(/\s+/g, ' ');
  return normalized.length > cap ? normalized.substring(0, cap) + '…' : normalized;
}

function sourceQuality(source: DeepSearchSourceView): number {
  let score = source.deepRead ? 3 : 0;
  score += source.status === 'success' ? 2 : 1;
  score += source.summary.length > 80 ? 1 : 0;
  score -= source.title.length < 4 ? 1 : 0;
  return score;
}

export function fallbackReports(
  sources: DeepSearchSourceView[],
  complexity: DeepSearchComplexity
): DeepSearchReportView[] {
  if (complexity === 'simple') {
    const candidates: DeepSearchSourceView[] = [];
    for (let index = 0; index < sources.length; index++) {
      if (usableSource(sources[index])) {
        candidates.push(sources[index]);
      }
    }
    if (candidates.length === 0) {
      return [];
    }
    candidates.sort((left: DeepSearchSourceView, right: DeepSearchSourceView): number =>
      sourceQuality(right) - sourceQuality(left));
    const selected = candidates.slice(0, MAX_REPORT_SOURCES);
    const findings: string[] = [];
    for (let index = 0; index < selected.length && findings.length < MAX_REPORT_FINDINGS; index++) {
      findings.push(shortText(selected[index].summary, 100));
    }
    return [{
      id: 'report_0',
      title: '概况',
      overview: selected.length > 1 ?
        '已从 ' + selected.length.toString() + ' 个来源提炼共同信息。' : '已从公开报道提炼核心信息。',
      findings: findings,
      sources: selected,
      confidence: selected.length > 1 ? '多源交叉' : '单一来源',
      expanded: false
    }];
  }
  const reports: DeepSearchReportView[] = [];
  const topics: string[] = [];
  for (let index = 0; index < sources.length; index++) {
    const source = sources[index];
    if (!usableSource(source) || topics.indexOf(source.subQuery) >= 0) {
      continue;
    }
    topics.push(source.subQuery);
  }
  for (let topicIndex = 0; topicIndex < topics.length; topicIndex++) {
    const topic = topics[topicIndex];
    const candidates: DeepSearchSourceView[] = [];
    for (let index = 0; index < sources.length; index++) {
      const source = sources[index];
      if (source.subQuery === topic && usableSource(source)) {
        candidates.push(source);
      }
    }
    candidates.sort((left: DeepSearchSourceView, right: DeepSearchSourceView): number =>
      sourceQuality(right) - sourceQuality(left));
    const selected = candidates.slice(0, MAX_REPORT_SOURCES);
    const findings: string[] = [];
    for (let index = 0; index < selected.length && findings.length < MAX_REPORT_FINDINGS; index++) {
      findings.push(shortText(selected[index].summary, 100));
    }
    reports.push({
      id: 'report_' + topicIndex.toString(),
      title: topic,
      overview: selected.length > 1 ?
        '已从 ' + selected.length.toString() + ' 个来源提炼共同信息。' : '已从公开报道提炼核心信息。',
      findings: findings,
      sources: selected,
      confidence: selected.length > 1 ? '多源交叉' : '单一来源',
      expanded: false
    });
  }
  return reports;
}

function dedupeMergeSources(
  existing: DeepSearchSourceView[],
  incoming: DeepSearchSourceView[]
): DeepSearchSourceView[] {
  const merged = existing.slice(0);
  for (let index = 0; index < incoming.length; index++) {
    const candidate = incoming[index];
    let duplicate = false;
    for (let cursor = 0; cursor < merged.length; cursor++) {
      if (merged[cursor].url === candidate.url) {
        duplicate = true;
        break;
      }
    }
    if (!duplicate) {
      merged.push(candidate);
    }
  }
  return merged;
}

function cloneReport(report: DeepSearchReportView): DeepSearchReportView {
  const sources: DeepSearchSourceView[] = [];
  for (let index = 0; index < report.sources.length; index++) {
    sources.push(cloneSource(report.sources[index]));
  }
  return {
    id: report.id,
    title: report.title,
    overview: report.overview,
    findings: report.findings.slice(0),
    sources: sources,
    confidence: report.confidence,
    expanded: report.expanded
  };
}

function cloneStage(stage: DeepSearchStageView): DeepSearchStageView {
  return {
    id: stage.id,
    title: stage.title,
    status: stage.status,
    detail: stage.detail,
    lines: stage.lines.slice(0),
    elapsedMs: stage.elapsedMs
  };
}

function cloneSource(source: DeepSearchSourceView): DeepSearchSourceView {
  return {
    title: source.title,
    url: source.url,
    summary: source.summary,
    status: source.status,
    round: source.round,
    subQuery: source.subQuery,
    deepRead: source.deepRead
  };
}

function initialStages(): DeepSearchStageView[] {
  return [
    { id: STAGE_INTENT, title: '意图拆解', status: 'pending', detail: '', lines: [], elapsedMs: 0 },
    { id: STAGE_SEARCH, title: '多轮联网检索', status: 'pending', detail: '', lines: [], elapsedMs: 0 },
    { id: STAGE_READ, title: '精读网页', status: 'pending', detail: '', lines: [], elapsedMs: 0 },
    { id: STAGE_EVALUATE, title: '信息评估', status: 'pending', detail: '', lines: [], elapsedMs: 0 },
    { id: STAGE_REFINE, title: '动态补充搜索', status: 'pending', detail: '', lines: [], elapsedMs: 0 },
    { id: STAGE_SYNTHESIZE, title: '汇总·交叉验证·生成答案', status: 'pending', detail: '', lines: [], elapsedMs: 0 }
  ];
}

export class DeepSearchEngine {
  private readonly ports: DeepSearchPorts;
  private stages: DeepSearchStageView[] = initialStages();
  private sources: DeepSearchSourceView[] = [];
  private reports: DeepSearchReportView[] = [];
  private answer: string = '';
  private complexity: DeepSearchComplexity = 'complex';
  private simpleFastPath: boolean = false;
  private modelStatus: string = '';
  private modelUnavailable: boolean = false;
  private errorText: string = '';
  private running: boolean = false;
  private cancelled: boolean = false;
  private context: DeepSearchContext = { locationLabel: '', dateLabel: '', coordinateLabel: '' };
  private onProgress: (progress: DeepSearchProgress) => void =
    (_progress: DeepSearchProgress): void => {};

  constructor(ports: DeepSearchPorts) {
    this.ports = ports;
  }

  cancel(): void {
    this.cancelled = true;
  }

  private contextPromptBlock(): string {
    const parts: string[] = [];
    if (this.context.dateLabel.trim().length > 0) {
      parts.push('今天是' + this.context.dateLabel.trim());
    }
    if (this.context.locationLabel.trim().length > 0) {
      parts.push('用户当前位于' + this.context.locationLabel.trim());
    }
    if (this.context.coordinateLabel.trim().length > 0) {
      parts.push('坐标' + this.context.coordinateLabel.trim());
    }
    if (parts.length === 0) {
      return '';
    }
    return '上下文：' + parts.join('，') +
      '。当问题涉及天气、时间、地点、本地信息或当日情况时，检索与回答必须引用以上位置与日期。\n';
  }

  private emit(): void {
    const stages: DeepSearchStageView[] = [];
    for (let index = 0; index < this.stages.length; index++) {
      stages.push(cloneStage(this.stages[index]));
    }
    const sources: DeepSearchSourceView[] = [];
    for (let index = 0; index < this.sources.length; index++) {
      sources.push(cloneSource(this.sources[index]));
    }
    const reports: DeepSearchReportView[] = [];
    for (let index = 0; index < this.reports.length; index++) {
      reports.push(cloneReport(this.reports[index]));
    }
    this.onProgress({
      stages: stages,
      sources: sources,
      reports: reports,
      answer: this.answer,
      complexity: this.complexity,
      modelStatus: this.modelStatus,
      running: this.running,
      error: this.errorText
    });
  }

  private stageOf(id: string): DeepSearchStageView {
    for (let index = 0; index < this.stages.length; index++) {
      if (this.stages[index].id === id) {
        return this.stages[index];
      }
    }
    return this.stages[0];
  }

  private beginStage(id: string, detail: string): number {
    const stage = this.stageOf(id);
    stage.status = 'running';
    stage.detail = detail;
    this.emit();
    return Date.now();
  }

  private stageLine(id: string, line: string): void {
    this.stageOf(id).lines.push(line);
    this.emit();
  }

  private endStage(id: string, status: DeepSearchStageStatus, detail: string, startedAt: number): void {
    const stage = this.stageOf(id);
    stage.status = status;
    stage.detail = detail;
    stage.elapsedMs = Date.now() - startedAt;
    this.emit();
  }

  private failRun(stageId: string, message: string, startedAt: number): void {
    this.endStage(stageId, 'error', message, startedAt);
    this.errorText = message;
    this.running = false;
    this.emit();
    aiLogError('[AIPhone][DeepSearchFailed] stage=' + stageId + ' message=' + message.substring(0, 240));
  }

  private async safeLlm(systemPrompt: string, prompt: string): Promise<string> {
    if (this.modelUnavailable) {
      return '';
    }
    try {
      const raw = await this.ports.llm(systemPrompt, prompt);
      if (raw.trim().length === 0) {
        this.modelUnavailable = true;
        this.modelStatus = '模型未返回内容，已使用本地规则完成整理。';
      }
      return raw;
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      aiLogError('[AIPhone][DeepSearchLlmError] ' + message.substring(0, 240));
      this.modelUnavailable = true;
      this.modelStatus = message.substring(0, 180) + '。已使用本地规则完成整理。';
      this.emit();
      return '';
    }
  }

  private async decomposeIntent(query: string): Promise<string[]> {
    const startedAt = this.beginStage(STAGE_INTENT, '正在拆解检索意图');
    let subQueries: string[] = [];
    let plan: DeepSearchIntentPlan | null = null;
    const contextBlock = this.contextPromptBlock();
    const raw = await this.safeLlm(
      '你是通用研究检索规划助手。只返回 JSON，不要输出任何其他内容。',
      (contextBlock.length > 0 ? contextBlock : '') +
      '用户问题："' + query + '"。请先判断问题复杂度：单一事实、单一维度即可回答的（如查天气、查定义、查某个数字）为 "simple"；' +
      '涉及多个独立维度、需要对比或综述的（如分析局势、梳理争议）为 "complex"。' +
      '再只拆解真正必要的中文搜索子查询：simple 问题只返回 1 个；complex 问题返回 2-4 个，' +
      '不要为了凑数重复或改写同一查询。子查询应共同覆盖回答问题所必需的核心事实、权威证据、时间或数据、分歧或反例；' +
      '只有问题明确询问当前或近期情况时才加入最新、今日等时间词。' +
      '若上下文提供了用户位置与日期，且问题与位置、时间、天气、本地信息相关，子查询必须包含位置与日期限定词。' +
      '返回 JSON：{"complexity":"simple"或"complex","subQueries":["...","..."]}'
    );
    if (this.cancelled) {
      return [];
    }
    if (raw.trim().length > 0) {
      plan = intentPlanFromModelText(raw);
    }
    let mode = '模型拆解';
    if (plan !== null) {
      subQueries = plan.subQueries;
      this.complexity = plan.complexity;
      this.simpleFastPath = plan.complexity === 'simple';
    } else {
      subQueries = genericFallbackSubQueries(query);
      this.complexity = fallbackComplexityOf(query, subQueries.length);
      mode = '模型不可用，使用内置拆解';
      this.stageLine(STAGE_INTENT, '模型拆解失败，回退到基于原问题的通用子查询。');
    }
    const qualified = contextQualifiedSubQueries(subQueries, this.context);
    if (qualified.length > 0 && this.context.locationLabel.trim().length > 0) {
      this.stageLine(STAGE_INTENT, '已结合用户位置（' + this.context.locationLabel.trim() + '）限定检索。');
    }
    subQueries = qualified;
    this.stageLine(STAGE_INTENT, '问题复杂度：' +
      (this.complexity === 'simple' ? '简单（仅整理概况）' : '复杂（按主题整理）'));
    for (let index = 0; index < subQueries.length; index++) {
      this.stageLine(STAGE_INTENT, '子查询 ' + (index + 1).toString() + '：' + subQueries[index]);
    }
    this.endStage(STAGE_INTENT, mode === '模型拆解' ? 'done' : 'warn',
      mode + '，共 ' + subQueries.length.toString() + ' 个子查询', startedAt);
    return subQueries;
  }

  private async searchRound(
    stageId: string,
    queries: string[],
    recency: string,
    round: number
  ): Promise<DeepSearchSearchRoundOutcome> {
    let needsAuth = false;
    let message = '';
    for (let index = 0; index < queries.length; index++) {
      if (this.cancelled) {
        break;
      }
      const query = queries[index];
      this.stageLine(stageId, '第 ' + round.toString() + ' 轮检索：' + query);
      let output: FirecrawlToolOutput;
      try {
        output = await this.ports.search(query, recency, RESULTS_PER_QUERY);
      } catch (error) {
        const text = error instanceof Error ? error.message : JSON.stringify(error);
        this.stageLine(stageId, '检索失败：' + text.substring(0, 120));
        continue;
      }
      const outcome = searchRoundOutcomeOf(output, query, round);
      if (outcome.needsAuth) {
        needsAuth = true;
        message = outcome.message;
        break;
      }
      if (outcome.message.length > 0 && outcome.sources.length === 0) {
        this.stageLine(stageId, '无结果：' + outcome.message.substring(0, 120));
      }
      const before = this.sources.length;
      this.sources = dedupeMergeSources(this.sources, outcome.sources);
      const added = this.sources.length - before;
      this.stageLine(stageId, '新增 ' + added.toString() + ' 个来源（去重后累计 ' +
        this.sources.length.toString() + '）');
    }
    return { sources: [], needsAuth: needsAuth, message: message };
  }

  private async readTopSources(query: string): Promise<void> {
    const startedAt = this.beginStage(STAGE_READ, '正在精读高价值网页');
    const targets: DeepSearchSourceView[] = [];
    for (let index = 0; index < this.sources.length && targets.length < MAX_DEEP_READS; index++) {
      const source = this.sources[index];
      if (source.status === 'success' || source.status === 'partial') {
        targets.push(source);
      }
    }
    if (targets.length === 0) {
      this.endStage(STAGE_READ, 'warn', '没有可精读的来源', startedAt);
      return;
    }
    let readCount = 0;
    for (let index = 0; index < targets.length; index++) {
      if (this.cancelled) {
        return;
      }
      const source = targets[index];
      this.stageLine(STAGE_READ, '精读：' + source.title.substring(0, 40));
      let output: FirecrawlToolOutput;
      try {
        output = await this.ports.readPage(
          source.url,
          '围绕用户问题“' + query + '”精读此页面。提取与问题直接相关的事实、日期、人物、数据、证据范围、' +
          '不确定性和相互矛盾之处；区分页面明确陈述与合理推断，不要泛泛总结，也不要编造页面没有的信息。'
        );
      } catch (error) {
        const text = error instanceof Error ? error.message : JSON.stringify(error);
        this.stageLine(STAGE_READ, '精读失败：' + text.substring(0, 120));
        continue;
      }
      if (output.results.length === 0) {
        continue;
      }
      const detail = output.results[0];
      if (detail.status === 'success' && detail.summary.trim().length > 0) {
        source.summary = detail.summary;
        source.deepRead = true;
        readCount++;
        this.stageLine(STAGE_READ, '完成：' + source.title.substring(0, 40));
      } else {
        this.stageLine(STAGE_READ, '跳过（' + detail.status + '）：' + source.title.substring(0, 40));
      }
    }
    this.endStage(STAGE_READ, readCount > 0 ? 'done' : 'warn',
      '成功精读 ' + readCount.toString() + ' / ' + targets.length.toString() + ' 篇', startedAt);
  }

  private sourceDigest(): string {
    const lines: string[] = [];
    let counter = 0;
    for (let index = 0; index < this.sources.length && counter < MAX_ANSWER_SOURCES; index++) {
      const source = this.sources[index];
      if (!usableSource(source)) {
        continue;
      }
      counter++;
      lines.push('[' + counter.toString() + '] ' + source.title + '｜' +
        source.summary.trim().substring(0, SUMMARY_CAP) + '｜' + source.url);
    }
    return lines.join('\n');
  }

  private sourcesForReport(sourceIndexes: number[] | undefined): DeepSearchSourceView[] {
    const selected: DeepSearchSourceView[] = [];
    let digestIndex = 0;
    for (let index = 0; index < this.sources.length && digestIndex < MAX_ANSWER_SOURCES; index++) {
      const source = this.sources[index];
      if (!usableSource(source)) {
        continue;
      }
      digestIndex++;
      if (Array.isArray(sourceIndexes) && sourceIndexes.indexOf(digestIndex) >= 0) {
        selected.push(source);
      }
    }
    if (selected.length > 0) {
      return selected.slice(0, MAX_REPORT_SOURCES);
    }
    for (let index = 0; index < this.sources.length && selected.length < MAX_REPORT_SOURCES; index++) {
      if (usableSource(this.sources[index])) {
        selected.push(this.sources[index]);
      }
    }
    return selected;
  }

  private async evaluateCoverage(query: string, subQueries: string[]): Promise<string[]> {
    const startedAt = this.beginStage(STAGE_EVALUATE, '正在评估信息覆盖度');
    let usableCount = 0;
    for (let index = 0; index < this.sources.length; index++) {
      if (usableSource(this.sources[index])) {
        usableCount++;
      }
    }
    this.stageLine(STAGE_EVALUATE, '可用来源 ' + usableCount.toString() + ' / ' +
      this.sources.length.toString());
    let evaluation: DeepSearchEvaluation | null = null;
    const raw = await this.safeLlm(
      '你是通用研究质量评估助手。只返回 JSON，不要输出任何其他内容。',
      '用户问题："' + query + '"\n子查询列表：' + JSON.stringify(subQueries) +
      '\n已获得的来源：\n' + this.sourceDigest() +
      '\n请评估这些来源是否足够、是否相互印证并能直接回答用户问题。检查覆盖范围、证据强度、' +
      '时间或口径差异、相互矛盾和缺失信息。若不足，给出最多 ' +
      MAX_GAP_QUERIES.toString() + ' 个针对缺口的中文补充查询。' +
      '返回 JSON：{"sufficient":true/false,"gaps":["..."]}'
    );
    if (this.cancelled) {
      return [];
    }
    if (raw.trim().length > 0) {
      evaluation = evaluationFromModelText(raw);
    }
    let gaps: string[];
    if (evaluation !== null) {
      gaps = evaluation.sufficient ? [] : evaluation.gaps;
      this.stageLine(STAGE_EVALUATE, evaluation.sufficient ?
        '模型评估：覆盖充分' : '模型评估：需补充 ' + gaps.length.toString() + ' 个查询');
      this.endStage(STAGE_EVALUATE, 'done', '模型评估完成', startedAt);
    } else {
      gaps = fallbackGaps(subQueries, this.sources);
      this.stageLine(STAGE_EVALUATE, '模型评估不可用，使用启发式评估；缺口 ' +
        gaps.length.toString() + ' 个');
      this.endStage(STAGE_EVALUATE, 'warn', '启发式评估完成', startedAt);
    }
    return gaps.slice(0, MAX_GAP_QUERIES);
  }

  private async synthesize(query: string): Promise<void> {
    const startedAt = this.beginStage(STAGE_SYNTHESIZE, '正在交叉验证并生成综述');
    const digest = this.sourceDigest();
    if (digest.length === 0) {
      this.answer = fallbackAnswer(query, this.sources, this.complexity);
      this.endStage(STAGE_SYNTHESIZE, 'error', '没有可用来源，无法生成综述', startedAt);
      return;
    }
    const contextBlock = this.contextPromptBlock();
    const simplePrompt =
      (contextBlock.length > 0 ? contextBlock : '') +
      '用户问题："' + query + '"。这是一个简单问题。以下是编号来源：\n' + digest +
      '\n请输出 JSON：{"answer":"用 2-4 句话直接回答问题的概况，必要时说明范围或不确定性",' +
      '"reports":[{"title":"补充细节主题","overview":"一句话结论","findings":["最多三条关键事实"],"sourceIndexes":[1,2]}]}。' +
      'answer 必须直接回答问题本身，不要按主题罗列；reports 仅在确有值得展开的补充细节时给出，' +
      '最多 ' + MAX_SIMPLE_REPORTS.toString() + ' 个，没有就返回空数组。每条事实必须能由来源支持，' +
      'sourceIndexes 填写支持该报告的编号来源，不要输出 URL。';
    const complexPrompt =
      (contextBlock.length > 0 ? contextBlock : '') +
      '用户问题："' + query + '"。这是一个复杂问题。以下是编号来源：\n' + digest +
      '\n请输出 JSON：{"answer":"用 2-3 句话给出总览结论","reports":[{"title":"主题或子任务","overview":"直接回答该主题的一句话结论，必要时说明范围或不确定性","findings":["最多三条合并后的关键事实"],"sourceIndexes":[1,2]}]}。' +
      '按主题或子任务组织报告，主题数量必须与问题的真实维度匹配（通常 2-4 个），' +
      '相近主题必须合并，禁止为凑数拆分；合并重复信息，指出重要分歧和证据限制；' +
      '每条事实必须能由来源支持，sourceIndexes 填写支持该报告的编号来源，不要输出 URL。';
    const raw = await this.safeLlm(
      '你是通用研究报告撰写助手。只依据给定来源回答，禁止编造来源中不存在的事实。',
      this.complexity === 'simple' ? simplePrompt : complexPrompt
    );
    if (this.cancelled) {
      return;
    }
    if (raw.trim().length > 0) {
      const parsed = parseModelJsonText(raw);
      try {
        const decoded = JSON.parse(parsed) as DeepSearchReportsRaw;
        const modelReports: DeepSearchReportRaw[] = Array.isArray(decoded.reports) ?
          decoded.reports as DeepSearchReportRaw[] : [];
        const modelAnswer = typeof decoded.answer === 'string' ? decoded.answer.trim() : '';
        if (modelReports.length === 0 && modelAnswer.length === 0) {
          this.reports = fallbackReports(this.sources, this.complexity);
          this.answer = fallbackAnswer(query, this.sources, this.complexity);
        } else {
          this.reports = [];
          const reportCap = this.complexity === 'simple' ? MAX_SIMPLE_REPORTS : modelReports.length;
          for (let reportIndex = 0;
            reportIndex < modelReports.length && this.reports.length < reportCap;
            reportIndex++) {
            const modelReport = modelReports[reportIndex];
            if (modelReport === undefined || modelReport === null) {
              continue;
            }
            const title = typeof modelReport.title === 'string' && modelReport.title.trim().length > 0 ?
              shortText(modelReport.title, 48) : '研究结论';
            const overview = typeof modelReport.overview === 'string' && modelReport.overview.trim().length > 0 ?
              shortText(modelReport.overview, 180) : '已根据可核验来源整理相关信息。';
            const findings: string[] = [];
            if (Array.isArray(modelReport.findings)) {
              for (let findingIndex = 0;
                findingIndex < modelReport.findings.length && findings.length < MAX_REPORT_FINDINGS;
                findingIndex++) {
                if (typeof modelReport.findings[findingIndex] === 'string' &&
                  modelReport.findings[findingIndex].trim().length > 0) {
                  findings.push(shortText(modelReport.findings[findingIndex], 120));
                }
              }
            }
            const reportSources = this.sourcesForReport(modelReport.sourceIndexes);
            this.reports.push({
              id: 'report_' + reportIndex.toString(),
              title: title,
              overview: overview,
              findings: findings.length > 0 ? findings : ['已从来源中提炼与问题直接相关的事实。'],
              sources: reportSources,
              confidence: reportSources.length > 1 ? '多源交叉' : '单一来源',
              expanded: false
            });
          }
          if (modelAnswer.length > 0) {
            this.answer = shortText(modelAnswer, 600);
          } else if (this.reports.length > 0) {
            this.answer = this.reports[0].overview;
          } else {
            this.answer = fallbackAnswer(query, this.sources, this.complexity);
          }
          if (this.reports.length === 0 && this.complexity === 'complex') {
            this.reports = fallbackReports(this.sources, this.complexity);
          }
        }
        this.endStage(STAGE_SYNTHESIZE, 'done', this.complexity === 'simple' ?
          '已生成概况回答' : '已生成结构化主题摘要', startedAt);
      } catch (_error) {
        this.answer = raw.trim();
        this.reports = fallbackReports(this.sources, this.complexity);
        this.endStage(STAGE_SYNTHESIZE, 'warn', '模型结果已降级为主题摘要', startedAt);
      }
    } else {
      this.reports = fallbackReports(this.sources, this.complexity);
      this.answer = fallbackAnswer(query, this.sources, this.complexity);
      this.endStage(STAGE_SYNTHESIZE, 'warn', '使用规则生成主题摘要', startedAt);
    }
  }

  async run(
    query: string,
    onProgress: (progress: DeepSearchProgress) => void,
    context: DeepSearchContext | null = null
  ): Promise<void> {
    if (this.running) {
      return;
    }
    this.onProgress = onProgress;
    this.context = context === null || context === undefined ?
      { locationLabel: '', dateLabel: '', coordinateLabel: '' } : context;
    this.stages = initialStages();
    this.sources = [];
    this.reports = [];
    this.answer = '';
    this.complexity = 'complex';
    this.simpleFastPath = false;
    this.modelStatus = '';
    this.modelUnavailable = false;
    this.errorText = '';
    this.cancelled = false;
    this.running = true;
    this.emit();
    aiLogInfo('[AIPhone][DeepSearchStart] query=' + query);

    const subQueries = await this.decomposeIntent(query);
    if (this.cancelled) {
      return;
    }

    const recency = queryRecency(query);
    const searchStartedAt = this.beginStage(STAGE_SEARCH, '正在执行多轮联网检索');
    const firstRound = await this.searchRound(STAGE_SEARCH, subQueries, recency, 1);
    if (this.cancelled) {
      return;
    }
    if (firstRound.needsAuth) {
      this.failRun(STAGE_SEARCH,
        'Firecrawl API key 未配置：请在 tool-gateway/.env.local 填写 FIRECRAWL_API_KEY，' +
        '再运行 node scripts/sync-provider-config.mjs 并重装应用。', searchStartedAt);
      return;
    }
    if (this.sources.length === 0) {
      const detail = firstRound.message.length > 0 ? firstRound.message : '联网检索没有返回任何来源。';
      this.failRun(STAGE_SEARCH, detail, searchStartedAt);
      return;
    }
    this.endStage(STAGE_SEARCH, 'done',
      '共获得 ' + this.sources.length.toString() + ' 个去重来源', searchStartedAt);

    if (this.simpleFastPath) {
      const skippedAt = Date.now();
      this.endStage(STAGE_READ, 'done', '简单问题无需精读网页', skippedAt);
      this.endStage(STAGE_EVALUATE, 'done', '简单问题无需覆盖评估', skippedAt);
      this.endStage(STAGE_REFINE, 'done', '简单问题无需补充检索', skippedAt);
      const synthesizeStartedAt = this.beginStage(STAGE_SYNTHESIZE, '正在整理搜索摘要');
      this.reports = fallbackReports(this.sources, this.complexity);
      this.answer = fallbackAnswer(query, this.sources, this.complexity);
      this.endStage(STAGE_SYNTHESIZE, 'done', '已生成概况回答', synthesizeStartedAt);
      this.running = false;
      this.emit();
      aiLogInfo('[AIPhone][DeepSearchDone] sources=' + this.sources.length.toString() +
        ' answerChars=' + this.answer.length.toString());
      return;
    }

    await this.readTopSources(query);
    if (this.cancelled) {
      return;
    }

    const gaps = await this.evaluateCoverage(query, subQueries);
    if (this.cancelled) {
      return;
    }

    const refineStartedAt = this.beginStage(STAGE_REFINE, gaps.length > 0 ?
      '正在补充检索缺口' : '');
    if (gaps.length > 0) {
      const secondRound = await this.searchRound(STAGE_REFINE, gaps, recency, 2);
      if (this.cancelled) {
        return;
      }
      if (secondRound.needsAuth) {
        this.stageLine(STAGE_REFINE, '补充检索需要 Firecrawl API key，已跳过。');
      }
      this.endStage(STAGE_REFINE, 'done',
        '补充后共 ' + this.sources.length.toString() + ' 个来源', refineStartedAt);
    } else {
      this.endStage(STAGE_REFINE, 'done', '覆盖充分，无需补充检索', refineStartedAt);
    }

    await this.synthesize(query);
    this.running = false;
    this.emit();
    aiLogInfo('[AIPhone][DeepSearchDone] sources=' + this.sources.length.toString() +
      ' answerChars=' + this.answer.length.toString());
  }
}
