import { http } from '@kit.NetworkKit';
import {
  AggregateSearchPost,
  AggregateSearchSourceBatch,
  AggregateSearchSourceStatus
} from './AggregateSearchTypes';

const GITHUB_API: string = 'https://api.github.com';
const MAX_BODY_BYTES: number = 2 * 1024 * 1024;
const MAX_POSTS: number = 4;
const CACHE_MS: number = 15 * 60 * 1000;
const FAMOUS_REPOSITORIES: string[] = ['openai/codex', 'microsoft/vscode'];

let cachedDiscoveryPosts: AggregateSearchPost[] = [];
let cachedDiscoveryAt: number = 0;

type GitHubValue = Object | string | number | boolean | null | undefined;
type GitHubRecord = Record<string, GitHubValue>;

interface GitHubRow {
  label: string;
  value: string;
}

function record(value: GitHubValue): GitHubRecord | null {
  return value !== null && !Array.isArray(value) && typeof value === 'object' ? value as GitHubRecord : null;
}

function array(value: GitHubValue): GitHubValue[] {
  return Array.isArray(value) ? value as GitHubValue[] : [];
}

function text(value: GitHubValue): string {
  return typeof value === 'string' ? value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim() : '';
}

function number(value: GitHubValue): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function httpsGitHubUrl(value: GitHubValue): string {
  const url = text(value);
  return url.startsWith('https://github.com/') && !/[\\\s\u0000-\u001f]/.test(url) ? url.split('#')[0] : '';
}

function limit(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.min(MAX_POSTS, Math.floor(value)) : 0;
}

function row(label: string, value: string): GitHubRow {
  return { label: label, value: value };
}

function repositoryPosts(rawJson: string, typeLabel: string = 'Repository'): AggregateSearchPost[] {
  if (rawJson.length === 0) return [];
  const root = record(JSON.parse(rawJson) as GitHubValue);
  const items = root === null ? [] : array(root.items);
  const posts: AggregateSearchPost[] = [];
  items.forEach((value: GitHubValue): void => {
    const item = record(value);
    if (item === null) return;
    const url = httpsGitHubUrl(item.html_url);
    const title = text(item.full_name);
    if (url.length === 0 || title.length === 0) return;
    const owner = record(item.owner);
    const rows = [row('Type', typeLabel)];
    const language = text(item.language);
    if (language.length > 0) rows.push(row('Language', language));
    rows.push(row('Stars', number(item.stargazers_count).toString()));
    rows.push(row('Forks', number(item.forks_count).toString()));
    const avatar = owner === null ? '' : text(owner.avatar_url);
    if (avatar.startsWith('https://avatars.githubusercontent.com/')) rows.push(row('authorAvatar', avatar));
    posts.push({
      id: 'github-repo-' + number(item.id).toString(), source: 'github', provider: 'GitHub', title: title,
      author: owner === null ? '' : text(owner.login), handle: owner === null ? '' : text(owner.login),
      text: text(item.description), url: url, publishedAt: text(item.updated_at),
      score: number(item.stargazers_count).toString(), commentCount: '', status: 'success', rows: rows
    });
  });
  return posts;
}

export function githubSearchPostsFromPayload(
  repositoriesJson: string,
  requestedLimit: number
): AggregateSearchPost[] {
  return repositoryPosts(repositoriesJson).slice(0, limit(requestedLimit));
}

function releasePost(repoName: string, rawJson: string): AggregateSearchPost | null {
  if (rawJson.length === 0) return null;
  const release = record(JSON.parse(rawJson) as GitHubValue);
  if (release === null) return null;
  const url = httpsGitHubUrl(release.html_url);
  const releaseName = text(release.name) || text(release.tag_name);
  if (url.length === 0 || releaseName.length === 0) return null;
  const author = record(release.author);
  const rows = [row('Type', 'Release'), row('Version', text(release.tag_name))];
  const avatar = author === null ? '' : text(author.avatar_url);
  if (avatar.startsWith('https://avatars.githubusercontent.com/')) rows.push(row('authorAvatar', avatar));
  return {
    id: 'github-release-' + number(release.id).toString(), source: 'github', provider: 'GitHub',
    title: repoName + ' · ' + releaseName,
    author: author === null ? repoName.split('/')[0] : text(author.login),
    handle: author === null ? '' : text(author.login), text: text(release.body), url: url,
    publishedAt: text(release.published_at), score: '', commentCount: '', status: 'success', rows: rows
  };
}

export function githubDiscoveryPostsFromPayload(
  trendingJson: string,
  releaseJsons: string[],
  requestedLimit: number
): AggregateSearchPost[] {
  if (trendingJson.length === 0 && releaseJsons.every((value: string): boolean => value.length === 0)) {
    throw new Error('github_all_requests_failed');
  }
  const count = limit(requestedLimit);
  const trending = repositoryPosts(trendingJson, 'Trending Repository').slice(0, Math.min(2, count));
  const releases: AggregateSearchPost[] = [];
  for (let index = 0; index < releaseJsons.length && index < FAMOUS_REPOSITORIES.length; index += 1) {
    const post = releasePost(FAMOUS_REPOSITORIES[index], releaseJsons[index]);
    if (post !== null) releases.push(post);
  }
  releases.sort((left: AggregateSearchPost, right: AggregateSearchPost): number =>
    right.publishedAt.localeCompare(left.publishedAt));
  return trending.concat(releases).slice(0, count);
}

function options(): http.HttpRequestOptions {
  return {
    method: http.RequestMethod.GET,
    header: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'Appless/0.1 (+https://github.com/XiaoLuoLYG/Appless-Phone)'
    },
    expectDataType: http.HttpDataType.STRING,
    connectTimeout: 5000,
    readTimeout: 10000,
    maxLimit: MAX_BODY_BYTES
  };
}

async function requestJson(url: string): Promise<string> {
  const request = http.createHttp();
  try {
    const response = await request.request(url, options());
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new Error('github_http_' + response.responseCode.toString());
    }
    const body = typeof response.result === 'string' ? response.result : '';
    if (body.length === 0 || body.length > MAX_BODY_BYTES) throw new Error('github_invalid_reply');
    return body;
  } finally {
    request.destroy();
  }
}

function status(kind: 'success' | 'empty' | 'error', message: string, count: number): AggregateSearchSourceStatus {
  return { source: 'github', label: 'GitHub', status: kind, message: message, count: count };
}

export async function searchPublicGitHub(query: string, requestedLimit: number): Promise<AggregateSearchSourceBatch> {
  const count = limit(requestedLimit);
  try {
    const encoded = encodeURIComponent(query.trim());
    const repositories = await requestJson(GITHUB_API + '/search/repositories?q=' + encoded +
      '%20in%3Aname%2Cdescription&sort=stars&order=desc&per_page=' + count.toString());
    const posts = githubSearchPostsFromPayload(repositories, count);
    const kind = posts.length > 0 ? 'success' : 'empty';
    return { source: 'github', videos: [], posts: posts,
      status: status(kind, 'GitHub 公开搜索返回 ' + posts.length.toString() + ' 条。', posts.length),
      continuation: null, rawCount: posts.length };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'github_request_failed';
    return { source: 'github', videos: [], posts: [],
      status: status('error', 'GitHub 公开搜索失败：' + message.slice(0, 160), 0), continuation: null };
  }
}

export async function discoverPublicGitHub(requestedLimit: number): Promise<AggregateSearchSourceBatch> {
  try {
    if (Date.now() - cachedDiscoveryAt < CACHE_MS && cachedDiscoveryPosts.length > 0) {
      const posts = cachedDiscoveryPosts.slice(0, limit(requestedLimit));
      return { source: 'github', videos: [], posts: posts,
        status: status('success', 'GitHub 热门仓库与版本更新返回 ' + posts.length.toString() + ' 条。', posts.length),
        continuation: null, rawCount: posts.length };
    }
    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const requests: Promise<string>[] = [requestJson(GITHUB_API + '/search/repositories?q=created%3A%3E%3D' +
      since + '&sort=stars&order=desc&per_page=4').catch((): string => '')];
    FAMOUS_REPOSITORIES.forEach((repo: string): void => {
      requests.push(requestJson(GITHUB_API + '/repos/' + repo + '/releases/latest').catch((): string => ''));
    });
    const replies = await Promise.all(requests);
    const posts = githubDiscoveryPostsFromPayload(replies[0], replies.slice(1), requestedLimit);
    if (posts.length > 0) {
      cachedDiscoveryPosts = posts;
      cachedDiscoveryAt = Date.now();
    }
    const kind = posts.length > 0 ? 'success' : 'empty';
    return { source: 'github', videos: [], posts: posts,
      status: status(kind, 'GitHub 热门仓库与版本更新返回 ' + posts.length.toString() + ' 条。', posts.length),
      continuation: null, rawCount: posts.length };
  } catch (error) {
    const message = error instanceof Error ? error.message : 'github_request_failed';
    return { source: 'github', videos: [], posts: [],
      status: status('error', 'GitHub 热门仓库与版本更新失败：' + message.slice(0, 160), 0), continuation: null };
  }
}
