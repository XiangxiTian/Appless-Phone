import { WaterfallComment, WaterfallContinuation, WaterfallFeedState } from './WaterfallAnythingCore';

export type AggregateSearchSource = 'youtube' | 'bilibili' | 'x' | 'hackernews' | 'reddit' | 'zhihu' |
  'douban' | 'applepodcasts' | 'twitch' | 'github' | 'steam' | 'cnnews' | 'globalnews';
export type AggregateSearchStatus = 'success' | 'empty' | 'needs_auth' | 'unsupported' | 'error';
export type AggregateSearchLanguageTag = 'zh-Hans' | 'zh-Hant' | 'en';
export type AggregateSearchLanguageFilterMode = 'intrinsic' | 'native' | 'regional' | 'post_filter' | 'none';
export type AggregateSearchSourceContext = 'search' | 'interest';

export interface AggregateSearchSourceCapabilities {
  search: boolean;
  interest: boolean;
}

export interface AggregateSearchPolicy {
  domesticOnly: boolean;
  multilingual: boolean;
}

export interface AggregateSearchSourceMetadata {
  source: AggregateSearchSource;
  isExternal: boolean;
  languages: AggregateSearchLanguageTag[];
  languageFilterMode: AggregateSearchLanguageFilterMode;
  introducedInRegistryVersion: number;
  defaultEnabled: boolean;
  capabilities: AggregateSearchSourceCapabilities;
}

export interface AggregateSearchRowData {
  label: string;
  value: string;
}

export interface AggregateSearchSourceStatus {
  source: AggregateSearchSource;
  label: string;
  status: AggregateSearchStatus;
  message: string;
  count: number;
}

export interface AggregateSearchVideo {
  id: string;
  source: AggregateSearchSource;
  provider: string;
  title: string;
  summary: string;
  url: string;
  thumbnail: string;
  publishedAt: string;
  duration: string;
  status: AggregateSearchStatus;
  rows: AggregateSearchRowData[];
}

export interface AggregateSearchPost {
  id: string;
  source: AggregateSearchSource;
  provider: string;
  title: string;
  author: string;
  handle: string;
  text: string;
  url: string;
  publishedAt: string;
  score: string;
  commentCount: string;
  status: AggregateSearchStatus;
  rows: AggregateSearchRowData[];
  feedUrl?: string;
  comments?: WaterfallComment[];
}

export interface AggregateSearchResult {
  query: string;
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
  sourceStatuses: AggregateSearchSourceStatus[];
  summary: string;
  waterfall?: WaterfallFeedState;
}

export interface AggregateSearchSourceBatch {
  source: AggregateSearchSource;
  videos: AggregateSearchVideo[];
  posts: AggregateSearchPost[];
  status: AggregateSearchSourceStatus;
  continuation: WaterfallContinuation | null;
  rawCount?: number;
}

export function emptyAggregateSearchResult(): AggregateSearchResult {
  return {
    query: '',
    videos: [],
    posts: [],
    sourceStatuses: [],
    summary: ''
  };
}

export function aggregateSourceLabel(source: AggregateSearchSource): string {
  if (source === 'youtube') {
    return 'YouTube';
  }
  if (source === 'bilibili') {
    return 'B 站';
  }
  if (source === 'x') {
    return 'X';
  }
  if (source === 'hackernews') {
    return 'HN';
  }
  if (source === 'reddit') {
    return 'Reddit';
  }
  if (source === 'zhihu') {
    return '知乎';
  }
  if (source === 'douban') {
    return '豆瓣';
  }
  if (source === 'applepodcasts') {
    return 'Apple Podcasts';
  }
  if (source === 'github') {
    return 'GitHub';
  }
  if (source === 'steam') {
    return 'Steam';
  }
  if (source === 'cnnews') {
    return 'CNNews';
  }
  if (source === 'globalnews') {
    return 'GlobalNews';
  }
  return 'Twitch';
}
