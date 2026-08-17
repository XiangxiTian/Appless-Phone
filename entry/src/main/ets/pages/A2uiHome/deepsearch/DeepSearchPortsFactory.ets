import {
  A2uiMessage,
  callStructuredTool,
  DataResult,
  FirecrawlToolOutput,
  GenericStructuredData,
  LocalModelSettings
} from '@loop/agent-core';
import { callDirectModel, DirectModelCallResult } from '../../../model/LocalModelClient';
import { DeepSearchPorts } from './DeepSearchEngine';

interface DeepSearchResearchArgs {
  query: string;
  recency: string;
  maxResults: number;
}

interface DeepSearchPageReadArgs {
  url: string;
  question: string;
}

function outputOfDataResult(result: DataResult, fallbackTitle: string): FirecrawlToolOutput {
  const data = result.data as GenericStructuredData;
  const results = data !== null && data !== undefined && Array.isArray(data.results) ?
    data.results : [];
  if (results.length === 0 && result.error !== undefined) {
    throw new Error(result.error.message);
  }
  return {
    title: fallbackTitle,
    intent: result.toolId,
    results: results
  };
}

export function deepSearchPortsOf(settings: LocalModelSettings): DeepSearchPorts {
  const search = async (
    query: string,
    recency: string,
    maxResults: number
  ): Promise<FirecrawlToolOutput> => {
    const args: DeepSearchResearchArgs = {
      query: query,
      recency: recency,
      maxResults: maxResults
    };
    const result = await callStructuredTool('web.research.search', query, args);
    return outputOfDataResult(result, '网页研究');
  };
  const readPage = async (url: string, question: string): Promise<FirecrawlToolOutput> => {
    const args: DeepSearchPageReadArgs = { url: url, question: question };
    const result = await callStructuredTool('web.page.read', '', args);
    return outputOfDataResult(result, '网页读取');
  };
  const llm = async (systemPrompt: string, prompt: string): Promise<string> => {
    const history: A2uiMessage[] = [];
    const result: DirectModelCallResult = await callDirectModel(
      settings, prompt, history, systemPrompt
    );
    if (result.ok) {
      return result.raw;
    }
    const detail = result.error.trim().length > 0 ?
      result.error.trim().substring(0, 180) : '模型请求失败';
    throw new Error('模型不可用（' + settings.provider + '/' + settings.model + '）：' + detail);
  };
  return { search: search, readPage: readPage, llm: llm };
}
