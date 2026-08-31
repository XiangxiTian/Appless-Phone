import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult, FirecrawlToolOutput } from '@loop/agent-core';
import {
  DeepSearchContext,
  DeepSearchEngine,
  DeepSearchPorts,
  DeepSearchProgress,
  DeepSearchSourceView,
  contextQualifiedSubQueries,
  evaluationFromModelText,
  fallbackAnswer,
  fallbackComplexityOf,
  fallbackGaps,
  fallbackReports,
  genericFallbackSubQueries,
  intentPlanFromModelText,
  queryRecency,
  searchRoundOutcomeOf,
  subQueriesFromModelText,
  usableSource
} from '../main/ets/pages/A2uiHome/deepsearch/DeepSearchEngine';
import { deepSearchCompletionText } from '../main/ets/pages/A2uiHome/components/DeepSearchPanel';

function emptyProgress(): DeepSearchProgress {
  return {
    stages: [],
    sources: [],
    reports: [],
    answer: '',
    complexity: 'complex',
    modelStatus: '',
    running: true,
    error: ''
  };
}

function sourceResult(title: string, url: string, summary: string, status: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Firecrawl',
    toolName: 'web.research.search',
    title: title,
    status: status,
    summary: summary,
    rows: [{ label: 'URL', value: url }, { label: 'Provider 状态', value: status }],
    rawPreview: summary
  };
}

function overviewResult(): DynamicGenericToolResult {
  return {
    sourceTag: 'Firecrawl',
    toolName: 'web.research.search',
    title: '网页研究综述',
    status: 'success',
    summary: '已核验公开来源。',
    rows: [],
    rawPreview: ''
  };
}

function searchOutput(results: DynamicGenericToolResult[]): FirecrawlToolOutput {
  return { title: '网页研究', intent: 'web.research.search', results: results };
}

function mockView(url: string, summary: string, status: string, subQuery: string): DeepSearchSourceView {
  return { title: url, url: url, summary: summary, status: status, round: 1, subQuery: subQuery, deepRead: false };
}

export default function deepSearchEngineTest() {
  describe('deepSearchEngine', () => {
    it('adapts generic fallback subqueries to question complexity', 0, () => {
      const simple = genericFallbackSubQueries('量子纠缠是什么');
      expect(simple.length).assertEqual(1);
      expect(simple[0].indexOf('量子纠缠是什么') >= 0).assertTrue();

      const factual = genericFallbackSubQueries('谁拿过网球大满贯');
      expect(factual.length).assertEqual(2);
      expect(factual[1].indexOf('权威来源') >= 0).assertTrue();

      const complex = genericFallbackSubQueries('比较历年代表案例、关键数据和不同观点争议');
      expect(complex.length).assertEqual(4);
      expect(complex[2].indexOf('争议') >= 0).assertTrue();
      expect(complex[3].indexOf('时间线') >= 0).assertTrue();
      expect(genericFallbackSubQueries('').length).assertEqual(0);
    });

    it('infers recency only for explicitly current questions', 0, () => {
      expect(queryRecency('我想知道谁拿过网球大满贯')).assertEqual('');
      expect(queryRecency('历史上谁获得过网球大满贯')).assertEqual('');
      expect(queryRecency('今天深圳天气怎么样')).assertEqual('');
      expect(queryRecency('最近的网球大满贯冠军是谁')).assertEqual('qdr:d');
      expect(queryRecency('截至今天的赛事进展')).assertEqual('qdr:d');
    });

    it('parses, deduplicates, and caps adaptive model subqueries', 0, () => {
      const single = subQueriesFromModelText('{"subQueries":["事实"]}');
      expect(single.length).assertEqual(1);
      expect(single[0]).assertEqual('事实');

      const cleaned = subQueriesFromModelText('{"subQueries":["事实"," ","权威来源","事实"]}');
      expect(cleaned.length).assertEqual(2);
      expect(cleaned[1]).assertEqual('权威来源');

      const capped = subQueriesFromModelText(
        '{"subQueries":["事实","权威来源","数据","争议","第五条"]}'
      );
      expect(capped.length).assertEqual(4);
      expect(subQueriesFromModelText('模型出错了').length).assertEqual(0);
    });

    it('parses intent plans with explicit or inferred complexity', 0, () => {
      const explicitSimple = intentPlanFromModelText(
        '{"complexity":"simple","subQueries":["深圳今天天气"]}'
      );
      expect(explicitSimple === null).assertFalse();
      expect(explicitSimple!.complexity).assertEqual('simple');
      expect(explicitSimple!.subQueries.length).assertEqual(1);

      const explicitComplex = intentPlanFromModelText(
        '{"complexity":"complex","subQueries":["国际局势 核心事实","国际局势 各方立场"]}'
      );
      expect(explicitComplex === null).assertFalse();
      expect(explicitComplex!.complexity).assertEqual('complex');

      const inferredSimple = intentPlanFromModelText('{"subQueries":["单一事实"]}');
      expect(inferredSimple!.complexity).assertEqual('simple');
      const inferredComplex = intentPlanFromModelText('{"subQueries":["维度一","维度二"]}');
      expect(inferredComplex!.complexity).assertEqual('complex');
      expect(intentPlanFromModelText('{"subQueries":[]}') === null).assertTrue();
      expect(intentPlanFromModelText('不是JSON') === null).assertTrue();
    });

    it('classifies fallback complexity from query markers', 0, () => {
      expect(fallbackComplexityOf('深圳今天天气', 1)).assertEqual('simple');
      expect(fallbackComplexityOf('量子纠缠是什么', 1)).assertEqual('simple');
      expect(fallbackComplexityOf('分析最近国际局势变化', 3)).assertEqual('complex');
      expect(fallbackComplexityOf('对比历年经济数据趋势', 2)).assertEqual('complex');
      expect(fallbackComplexityOf('某个冷门问题', 1)).assertEqual('simple');
    });

    it('parses evaluation JSON with gaps', 0, () => {
      const evaluation = evaluationFromModelText('{"sufficient":false,"gaps":["补充权威来源"]}');
      expect(evaluation === null).assertFalse();
      expect(evaluation!.sufficient).assertFalse();
      expect(evaluation!.gaps[0]).assertEqual('补充权威来源');
      expect(evaluationFromModelText('{"gaps":[]}') === null).assertTrue();
    });

    it('extracts sources, skips overview, and deduplicates URLs', 0, () => {
      const outcome = searchRoundOutcomeOf(searchOutput([
        overviewResult(),
        sourceResult('来源A', 'https://a.example.com/1', '摘要A', 'success'),
        sourceResult('来源A重复', 'https://a.example.com/1', '重复摘要', 'success'),
        sourceResult('来源B', 'https://b.example.com/2', '摘要B', 'partial'),
        sourceResult('失败来源', 'https://blocked.example.com', '站点拒绝访问', 'blocked_by_site')
      ]), '核心事实', 1);
      expect(outcome.sources.length).assertEqual(2);
      expect(outcome.needsAuth).assertFalse();
      expect(outcome.message).assertEqual('站点拒绝访问');
      expect(outcome.sources[0].url).assertEqual('https://a.example.com/1');
      expect(outcome.sources[0].subQuery).assertEqual('核心事实');
    });

    it('flags authentication errors', 0, () => {
      const outcome = searchRoundOutcomeOf(searchOutput([
        sourceResult('鉴权', '', 'Firecrawl API key is required.', 'needs_auth')
      ]), '核心事实', 1);
      expect(outcome.needsAuth).assertTrue();
      expect(outcome.sources.length).assertEqual(0);
    });

    it('computes fallback gaps for uncovered subqueries', 0, () => {
      const gaps = fallbackGaps(['核心事实', '权威来源'], [
        mockView('https://a.example.com', '摘要', 'success', '核心事实')
      ]);
      expect(gaps.length).assertEqual(1);
      expect(gaps[0].indexOf('权威来源')).assertEqual(0);
    });

    it('builds concise grouped fallback reports without raw URLs', 0, () => {
      const sources = [
        mockView('https://a.example.com', '摘要A', 'success', '核心事实'),
        mockView('https://b.example.com', '', 'success', '权威来源'),
        mockView('https://c.example.com', '摘要C', 'error', '权威来源')
      ];
      expect(usableSource(sources[0])).assertTrue();
      expect(usableSource(sources[1])).assertFalse();
      expect(usableSource(sources[2])).assertFalse();
      const answer = fallbackAnswer('我想知道谁拿过网球大满贯', sources, 'complex');
      const reports = fallbackReports(sources, 'complex');
      expect(answer.indexOf('核心事实') >= 0).assertTrue();
      expect(answer.indexOf('摘要A') >= 0).assertTrue();
      expect(answer.indexOf('https://a.example.com') >= 0).assertFalse();
      expect(reports.length).assertEqual(1);
      expect(reports[0].sources.length).assertEqual(1);
    });

    it('merges simple-question fallback into a single overview report', 0, () => {
      const sources = [
        mockView('https://a.example.com', '深圳今天多云，气温 26-31 度。', 'success', '深圳今天天气'),
        mockView('https://b.example.com', '今天深圳有阵雨，注意带伞。', 'success', '深圳天气预报'),
        mockView('https://c.example.com', '', 'success', '深圳天气预报')
      ];
      const reports = fallbackReports(sources, 'simple');
      expect(reports.length).assertEqual(1);
      expect(reports[0].title).assertEqual('概况');
      expect(reports[0].sources.length).assertEqual(2);
      const answer = fallbackAnswer('深圳今天天气', sources, 'simple');
      expect(answer.indexOf('按主题整理') >= 0).assertFalse();
      expect(answer.indexOf('◆') >= 0).assertFalse();
      expect(answer.length > 0).assertTrue();
      expect(fallbackReports([], 'simple').length).assertEqual(0);
    });

    it('runs a question-aware factual pipeline with unrestricted search and supplemental search', 0, async () => {
      let searchCalls = 0;
      let readCalls = 0;
      let llmCalls = 0;
      const recencies: string[] = [];
      const readQuestions: string[] = [];
      const evaluationPrompts: string[] = [];
      const ports: DeepSearchPorts = {
        search: async (query: string, recency: string, _maxResults: number): Promise<FirecrawlToolOutput> => {
          searchCalls++;
          recencies.push(recency);
          return searchOutput([
            overviewResult(),
            sourceResult('来源 ' + query, 'https://facts.example.com/' + searchCalls.toString(),
              query + ' 的摘要', 'success')
          ]);
        },
        readPage: async (url: string, question: string): Promise<FirecrawlToolOutput> => {
          readCalls++;
          readQuestions.push(question);
          return searchOutput([sourceResult('精读', url, '精读后的详细摘要：' + question, 'success')]);
        },
        llm: async (systemPrompt: string, prompt: string): Promise<string> => {
          llmCalls++;
          if (systemPrompt.indexOf('规划') >= 0) {
            return '{"complexity":"complex","subQueries":["大满贯冠军名单","权威网球记录","不同年代冠军","定义与范围"]}';
          }
          if (systemPrompt.indexOf('评估') >= 0) {
            evaluationPrompts.push(prompt);
            return '{"sufficient":false,"gaps":["补充冠军名单来源"]}';
          }
          return '{"answer":"多个来源交叉印证了历届大满贯冠军记录。","reports":[{"title":"冠军名单","overview":"来源汇总了相关冠军记录。","findings":["多个来源提供了可核验记录。"]}]}';
        }
      };
      const engine = new DeepSearchEngine(ports);
      let lastProgress: DeepSearchProgress = emptyProgress();
      await engine.run('我想知道谁拿过网球大满贯', (progress: DeepSearchProgress): void => {
        lastProgress = progress;
      });
      const final: DeepSearchProgress = lastProgress;
      expect(final.running).assertFalse();
      expect(final.error.length).assertEqual(0);
      expect(final.complexity).assertEqual('complex');
      expect(final.reports.length).assertEqual(1);
      expect(final.reports[0].overview.indexOf('冠军记录') >= 0).assertTrue();
      expect(final.answer.indexOf('交叉印证') >= 0).assertTrue();
      expect(searchCalls).assertEqual(5);
      expect(recencies[0]).assertEqual('');
      expect(recencies[recencies.length - 1]).assertEqual('');
      expect(readCalls > 0).assertTrue();
      expect(readQuestions[0].indexOf('我想知道谁拿过网球大满贯') >= 0).assertTrue();
      expect(evaluationPrompts[0].indexOf('我想知道谁拿过网球大满贯') >= 0).assertTrue();
      expect(llmCalls >= 3).assertTrue();
      expect(final.sources.length).assertEqual(5);
    });

    it('uses recent filtering for explicitly current questions', 0, async () => {
      let receivedRecency = '';
      const ports: DeepSearchPorts = {
        search: async (_query: string, recency: string, _maxResults: number): Promise<FirecrawlToolOutput> => {
          receivedRecency = recency;
          return searchOutput([sourceResult('当前来源', 'https://current.example.com', '当前摘要', 'success')]);
        },
        readPage: async (_url: string, _question: string): Promise<FirecrawlToolOutput> => searchOutput([]),
        llm: async (systemPrompt: string, _prompt: string): Promise<string> => {
          if (systemPrompt.indexOf('规划') >= 0) {
            return '{"complexity":"simple","subQueries":["最近赛事"]}';
          }
          return '{"sufficient":true,"gaps":[]}';
        }
      };
      const engine = new DeepSearchEngine(ports);
      await engine.run('最近的网球大满贯冠军是谁', (_progress: DeepSearchProgress): void => {});
      expect(receivedRecency).assertEqual('qdr:d');
    });

    it('answers simple questions with an overview and capped reports', 0, async () => {
      const synthesisPrompts: string[] = [];
      let readCalls = 0;
      let llmCalls = 0;
      const ports: DeepSearchPorts = {
        search: async (query: string, _recency: string, _maxResults: number): Promise<FirecrawlToolOutput> =>
          searchOutput([
            sourceResult('天气来源', 'https://weather.example.com/' + query, '深圳多云 26-31 度。', 'success')
          ]),
        readPage: async (url: string, _question: string): Promise<FirecrawlToolOutput> => {
          readCalls++;
          return searchOutput([sourceResult('精读', url, '今天深圳多云，偶有阵雨，气温 26-31 度。', 'success')]);
        },
        llm: async (systemPrompt: string, prompt: string): Promise<string> => {
          llmCalls++;
          if (systemPrompt.indexOf('规划') >= 0) {
            return '{"complexity":"simple","subQueries":["深圳今天天气"]}';
          }
          if (systemPrompt.indexOf('评估') >= 0) {
            return '{"sufficient":true,"gaps":[]}';
          }
          synthesisPrompts.push(prompt);
          return '{"answer":"深圳今天多云，偶有阵雨，气温 26 到 31 度。","reports":[' +
            '{"title":"细节一","overview":"概况一","findings":["事实一"]},' +
            '{"title":"细节二","overview":"概况二","findings":["事实二"]},' +
            '{"title":"细节三","overview":"概况三","findings":["事实三"]}]}';
        }
      };
      const engine = new DeepSearchEngine(ports);
      let final: DeepSearchProgress = emptyProgress();
      await engine.run('深圳今天天气', (progress: DeepSearchProgress): void => { final = progress; });
      const result: DeepSearchProgress = final;
      expect(result.running).assertFalse();
      expect(result.error.length).assertEqual(0);
      expect(result.complexity).assertEqual('simple');
      expect(result.answer.indexOf('26-31 度') >= 0).assertTrue();
      expect(result.reports.length).assertEqual(1);
      expect(readCalls).assertEqual(0);
      expect(llmCalls).assertEqual(1);
      expect(synthesisPrompts.length).assertEqual(0);
    });

    it('reports authentication failure clearly', 0, async () => {
      const ports: DeepSearchPorts = {
        search: async (_query: string, _recency: string, _maxResults: number): Promise<FirecrawlToolOutput> =>
          searchOutput([sourceResult('鉴权', '', 'Firecrawl API key is required.', 'needs_auth')]),
        readPage: async (_url: string, _question: string): Promise<FirecrawlToolOutput> => searchOutput([]),
        llm: async (_systemPrompt: string, _prompt: string): Promise<string> => ''
      };
      const engine = new DeepSearchEngine(ports);
      let final: DeepSearchProgress = emptyProgress();
      await engine.run('历史网球冠军', (progress: DeepSearchProgress): void => { final = progress; });
      const authResult: DeepSearchProgress = final;
      expect(authResult.error.indexOf('FIRECRAWL_API_KEY') >= 0).assertTrue();
      expect(deepSearchCompletionText(authResult)).assertEqual(authResult.error);
    });

    it('uses local grouped fallback when the model is unavailable', 0, async () => {
      const ports: DeepSearchPorts = {
        search: async (query: string, _recency: string, _maxResults: number): Promise<FirecrawlToolOutput> =>
          searchOutput([sourceResult('来源', 'https://fallback.example.com/' + query, '摘要', 'success')]),
        readPage: async (url: string, _question: string): Promise<FirecrawlToolOutput> =>
          searchOutput([sourceResult('精读', url, '精读摘要', 'success')]),
        llm: async (_systemPrompt: string, _prompt: string): Promise<string> => ''
      };
      const engine = new DeepSearchEngine(ports);
      let final: DeepSearchProgress = emptyProgress();
      await engine.run('我想知道谁拿过网球大满贯', (progress: DeepSearchProgress): void => { final = progress; });
      const result: DeepSearchProgress = final;
      expect(result.error.length).assertEqual(0);
      expect(result.modelStatus.length > 0).assertTrue();
      expect(result.reports.length > 0).assertTrue();
      expect(result.reports[0].findings[0]).assertEqual('精读摘要');
    });

    it('qualifies subqueries with location context', 0, () => {
      const context: DeepSearchContext = {
        locationLabel: '深圳市',
        dateLabel: '2026年8月14日 星期五',
        coordinateLabel: '22.5431,114.0579'
      };
      const qualified = contextQualifiedSubQueries(['今天天气'], context);
      expect(qualified.length).assertEqual(1);
      expect(qualified[0].indexOf('深圳市') >= 0).assertTrue();
      // 已含位置前缀的不重复拼（"深圳" 是 "深圳市" 的前缀）
      const already = contextQualifiedSubQueries(['深圳今天天气'], context);
      expect(already[0].indexOf('深圳市') >= 0).assertFalse();
      expect(already[0].indexOf('深圳') >= 0).assertTrue();
      // 无上下文时原样返回
      expect(contextQualifiedSubQueries(['今天天气'], null)[0]).assertEqual('今天天气');
    });

    it('injects context into the intent prompt and search queries', 0, async () => {
      let intentPrompt = '';
      const capturedQueries: string[] = [];
      const ports: DeepSearchPorts = {
        search: async (query: string, _recency: string, _maxResults: number): Promise<FirecrawlToolOutput> => {
          capturedQueries.push(query);
          return searchOutput([sourceResult('来源', 'https://ctx.example.com', '摘要', 'success')]);
        },
        readPage: async (url: string, _question: string): Promise<FirecrawlToolOutput> =>
          searchOutput([sourceResult('精读', url, '精读摘要', 'success')]),
        llm: async (systemPrompt: string, prompt: string): Promise<string> => {
          if (systemPrompt.indexOf('规划') >= 0) {
            intentPrompt = prompt;
            return '{"complexity":"simple","subQueries":["今天天气"]}';
          }
          return '{"sufficient":true,"gaps":[]}';
        }
      };
      const context: DeepSearchContext = {
        locationLabel: '深圳市',
        dateLabel: '2026年8月14日 星期五',
        coordinateLabel: '22.5431,114.0579'
      };
      const engine = new DeepSearchEngine(ports);
      let final: DeepSearchProgress = emptyProgress();
      await engine.run('今天天气怎么样', (progress: DeepSearchProgress): void => { final = progress; }, context);
      expect(intentPrompt.indexOf('深圳市') >= 0).assertTrue();
      expect(intentPrompt.indexOf('2026年8月14日') >= 0).assertTrue();
      expect(capturedQueries.length).assertEqual(1);
      expect(capturedQueries[0].indexOf('深圳市') >= 0).assertTrue();
      expect(final.error.length).assertEqual(0);
    });

    it('degrades gracefully when context location is unavailable', 0, async () => {
      const capturedQueries: string[] = [];
      const ports: DeepSearchPorts = {
        search: async (query: string, _recency: string, _maxResults: number): Promise<FirecrawlToolOutput> => {
          capturedQueries.push(query);
          return searchOutput([sourceResult('来源', 'https://nodate.example.com', '摘要', 'success')]);
        },
        readPage: async (url: string, _question: string): Promise<FirecrawlToolOutput> =>
          searchOutput([sourceResult('精读', url, '精读摘要', 'success')]),
        llm: async (systemPrompt: string, _prompt: string): Promise<string> =>
          systemPrompt.indexOf('规划') >= 0 ? '{"complexity":"simple","subQueries":["事件"]}' : '{"sufficient":true,"gaps":[]}'
      };
      const context: DeepSearchContext = { locationLabel: '', dateLabel: '', coordinateLabel: '' };
      const engine = new DeepSearchEngine(ports);
      let final: DeepSearchProgress = emptyProgress();
      await engine.run('某个事件', (progress: DeepSearchProgress): void => { final = progress; }, context);
      expect(final.error.length).assertEqual(0);
      expect(capturedQueries.length).assertEqual(1);
      expect(capturedQueries[0].indexOf('深圳市') >= 0).assertFalse();
    });
  });
}
