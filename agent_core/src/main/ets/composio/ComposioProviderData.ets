type ProviderJsonValue = Object | string | number | boolean | null | undefined;
type ProviderRecord = Record<string, ProviderJsonValue>;

interface ProviderDataBudget {
  remaining: number;
}

export interface ComposioProviderArrayTruncation {
  path: string;
  originalCount: number;
  retainedCount: number;
}

export interface ComposioProviderDataMeta {
  truncated: boolean;
  originalChars: number;
  retainedChars: number;
  reason: string;
  arrays: ComposioProviderArrayTruncation[];
  redactedSecretFields: number;
  redactedBinaryFields: number;
}

export interface ComposioProviderDataExtraction {
  data: Object | null;
  meta: ComposioProviderDataMeta;
}

interface ProviderDataState {
  budget: ProviderDataBudget;
  meta: ComposioProviderDataMeta;
}

const PROVIDER_DATA_MAX_DEPTH: number = 12;
const PROVIDER_DATA_MAX_KEYS: number = 256;
const PROVIDER_DATA_MAX_ARRAY_ITEMS: number = 1000;
const PROVIDER_DATA_CONTENT_BUDGET: number = 190000;
const PROVIDER_DATA_MAX_JSON: number = 200000;
const GITHUB_USER_EVENTS_TOOL: string = 'GITHUB_LIST_EVENTS_FOR_USER';

export const GITHUB_USER_EVENTS_NORMALIZED_SCHEMA_VERSION: string = 'github-user-events.v1';

interface GitHubNormalizedEvent {
  kind: string;
  title: string;
  summary: string;
  repo: Object;
  occurredAt: string;
  details: Object;
  visibility?: string;
}

interface GitHubNormalizedData {
  events: Object[];
  count: number;
  metadata: Object;
}

export function githubUserEventsNormalizedOutputSchema(): Object {
  return JSON.parse('{"type":"object","description":"Normalized GitHub activity returned for the requested ' +
    'user. Authenticated self-queries may include private events. Raw mapping: ' +
    'PushEvent=push, WatchEvent=star, ReleaseEvent=release, IssuesEvent=issue, IssueCommentEvent=issue_comment ' +
    'or pull_request_comment, ForkEvent=fork, PullRequestEvent=pull_request, ' +
    'PullRequestReviewEvent=pull_request_review, PullRequestReviewCommentEvent=pull_request_review_comment, ' +
    'CommitCommentEvent=commit_comment, CreateEvent=create, DeleteEvent=delete, DiscussionEvent=discussion, ' +
    'GollumEvent=wiki, MemberEvent=member, PublicEvent=public; other event types use kind=other. ' +
    'WatchEvent action=started means Star.","required":["events","count","metadata"],"properties":{' +
    '"events":{"type":"array","description":"Stable readable activity items without raw actor, avatar, SHA, ' +
    'or payload fields. Private events are retained and marked visibility=private.","items":{"type":"object",' +
    '"required":["kind","title","summary","repo","occurredAt","details","visibility"],"properties":{' +
    '"kind":{"type":"string","description":"Normalized event kind."},' +
    '"title":{"type":"string","description":"Short user-readable event title."},' +
    '"summary":{"type":"string","description":"User-readable event summary."},' +
    '"repo":{"type":"object","description":"Affected repository.","required":["name"],"properties":{' +
    '"name":{"type":"string","description":"owner/repository name."},' +
    '"url":{"type":"string","description":"Repository web URL when available."}}},' +
    '"occurredAt":{"type":"string","description":"Provider event timestamp."},' +
    '"details":{"type":"object","description":"Small kind-specific semantic fields; never the raw payload."},' +
    '"visibility":{"type":"string","enum":["public","private","unknown"],"description":' +
    '"Visibility derived from the provider public field; missing means unknown."}}}},' +
    '"count":{"type":"number","description":"Number of normalized events returned in this response/page, ' +
    'not an all-time total."},"metadata":{"type":"object","description":"Normalization and pagination ' +
    'metadata.","required":["source","schemaVersion","normalized"],"properties":{' +
    '"source":{"type":"string"},"schemaVersion":{"type":"string"},"normalized":{"type":"boolean"},' +
    '"nextPageToken":{"type":"string","description":"Provider pagination token when available."},' +
    '"hasMore":{"type":"boolean","description":"Provider pagination indication when available."}}}}}') as Object;
}

function normalizedSecretKey(key: string): string {
  return key.toLowerCase().replace(/[^a-z0-9]/g, '');
}

function isSecretProviderKey(key: string): boolean {
  const normalized = normalizedSecretKey(key);
  const sensitiveTokenKey = normalized === 'token' || normalized === 'accesstoken' ||
    normalized === 'refreshtoken' || normalized === 'idtoken' || normalized === 'authtoken' ||
    normalized === 'sessiontoken' || normalized === 'csrftoken' || normalized === 'bearertoken';
  return sensitiveTokenKey || normalized.endsWith('apikey') || normalized === 'jwt' || normalized.endsWith('jwt') ||
    normalized === 'passwd' || normalized === 'privatekey' || normalized === 'secretkey' ||
    normalized === 'sessionid' || normalized === 'signature' ||
    normalized === 'signingkey' || normalized.indexOf('credential') >= 0 ||
    normalized.indexOf('secret') >= 0 || normalized.indexOf('password') >= 0 ||
    normalized.indexOf('cookie') >= 0 || normalized.indexOf('authorization') >= 0;
}

function isStructuredAuthObject(key: string, value: ProviderJsonValue): boolean {
  return normalizedSecretKey(key) === 'auth' && value !== null && value !== undefined &&
    typeof value === 'object' && !Array.isArray(value);
}

function isStringAuthField(key: string, value: ProviderJsonValue): boolean {
  const normalized = normalizedSecretKey(key);
  if (normalized !== 'auth' && normalized !== 'bearer') return false;
  if (isStructuredAuthObject(key, value)) return false;
  return true;
}

function isBearerCredentialString(value: ProviderJsonValue): boolean {
  return typeof value === 'string' && /^\s*Bearer\s+\S+/i.test(value);
}

function providerEnvelopeChild(value: ProviderJsonValue): ProviderJsonValue {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) {
    return value;
  }
  const record = value as ProviderRecord;
  const responseData = record['response_data'];
  if (responseData !== undefined && responseData !== null && typeof responseData === 'object') {
    if (!Array.isArray(responseData)) {
      const responseRecord = responseData as ProviderRecord;
      const nestedData = responseRecord['data'];
      if (nestedData !== undefined && nestedData !== null && typeof nestedData === 'object') {
        return nestedData;
      }
    }
    return responseData;
  }
  return value;
}

function preferredProviderData(payload: Object): ProviderJsonValue {
  const root = payload as ProviderRecord;
  let current: ProviderJsonValue = root['data'] === undefined ? payload : root['data'];
  for (let depth = 0; depth < 4; depth++) {
    const responseChild = providerEnvelopeChild(current);
    if (responseChild !== current) {
      current = responseChild;
      continue;
    }
    if (current === null || current === undefined || typeof current !== 'object' || Array.isArray(current)) {
      break;
    }
    const record = current as ProviderRecord;
    const keys = Object.keys(record);
    const data = record['data'];
    const envelopeLike = keys.length <= 5 &&
      keys.every((key: string): boolean =>
        key === 'data' || key === 'error' || key === 'log_id' || key === 'success' || key === 'successful'
      );
    if (envelopeLike && data !== undefined && data !== null && typeof data === 'object') {
      current = data;
      continue;
    }
    break;
  }
  return current;
}

function looksLikeBinaryString(value: string): boolean {
  const clean = value.trim();
  if (clean.length < 512) return false;
  if (clean.toLowerCase().indexOf('data:') === 0 && clean.indexOf(';base64,') > 0) return true;
  return /^[A-Za-z0-9+/=_-]+$/.test(clean) && clean.indexOf(' ') < 0;
}

function boundedProviderString(value: string, state: ProviderDataState): string | undefined {
  if (state.budget.remaining <= 0) return undefined;
  if (looksLikeBinaryString(value)) {
    const omitted = '[omitted binary data]';
    state.budget.remaining -= omitted.length;
    state.meta.redactedBinaryFields++;
    return omitted;
  }
  if (value.length > state.budget.remaining) {
    const remaining = state.budget.remaining;
    state.budget.remaining = 0;
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_size_limit';
    return remaining <= 0 ? undefined : value.substring(0, remaining);
  }
  state.budget.remaining -= value.length;
  return value;
}

function boundedProviderValue(
  value: ProviderJsonValue,
  depth: number,
  path: string,
  state: ProviderDataState
): ProviderJsonValue {
  if (state.budget.remaining <= 0) return undefined;
  if (value === null || typeof value === 'number' || typeof value === 'boolean') {
    state.budget.remaining -= 8;
    return value;
  }
  if (typeof value === 'string') return boundedProviderString(value, state);
  if (value === undefined) return undefined;
  if (depth >= PROVIDER_DATA_MAX_DEPTH) {
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_depth_limit';
    return undefined;
  }
  if (Array.isArray(value)) {
    const source = value as ProviderJsonValue[];
    const output: ProviderJsonValue[] = [];
    for (let index = 0; index < source.length && index < PROVIDER_DATA_MAX_ARRAY_ITEMS; index++) {
      const item = boundedProviderValue(source[index], depth + 1, path + '/' + index.toString(), state);
      if (item === undefined) {
        if (state.budget.remaining <= 0) break;
        continue;
      }
      output.push(item);
      state.budget.remaining -= 2;
      if (state.budget.remaining <= 0) break;
    }
    if (output.length < source.length) {
      state.meta.truncated = true;
      if (state.meta.reason.length === 0) state.meta.reason =
        source.length > PROVIDER_DATA_MAX_ARRAY_ITEMS ? 'provider_data_array_limit' : 'provider_data_size_limit';
      if (state.meta.arrays.length < 32) {
        state.meta.arrays.push({ path: path, originalCount: source.length, retainedCount: output.length });
      }
    }
    return output as Object;
  }
  const source = value as ProviderRecord;
  const output: ProviderRecord = {};
  const keys = Object.keys(source);
  if (keys.length > PROVIDER_DATA_MAX_KEYS) {
    state.meta.truncated = true;
    if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_key_limit';
  }
  let accepted = 0;
  for (let index = 0; index < keys.length && accepted < PROVIDER_DATA_MAX_KEYS; index++) {
    const key = keys[index];
    const sourceValue = source[key];
    if (isSecretProviderKey(key) || isStringAuthField(key, sourceValue) ||
      isBearerCredentialString(sourceValue)) {
      state.meta.redactedSecretFields++;
      continue;
    }
    if (key.length === 0 || key.length > 160 || key.length + 4 > state.budget.remaining) {
      if (key.length > 160 || key.length + 4 > state.budget.remaining) {
        state.meta.truncated = true;
        if (state.meta.reason.length === 0) state.meta.reason = 'provider_data_size_limit';
      }
      continue;
    }
    state.budget.remaining -= key.length + 4;
    const child = boundedProviderValue(sourceValue, depth + 1, path + '/' + key, state);
    if (child === undefined) {
      if (state.budget.remaining <= 0) break;
      continue;
    }
    output[key] = child;
    accepted++;
    if (state.budget.remaining <= 0) break;
  }
  return output as Object;
}

function providerRecord(value: ProviderJsonValue): ProviderRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as ProviderRecord;
}

function providerText(record: ProviderRecord | null, keys: string[]): string {
  if (record === null) return '';
  for (let index = 0; index < keys.length; index++) {
    const value = record[keys[index]];
    if (typeof value === 'string' && value.trim().length > 0) return value.trim();
    if (typeof value === 'number' || typeof value === 'boolean') return value.toString();
  }
  return '';
}

function providerNumber(record: ProviderRecord | null, keys: string[]): number | undefined {
  if (record === null) return undefined;
  for (let index = 0; index < keys.length; index++) {
    const value = record[keys[index]];
    if (typeof value === 'number' && !Number.isNaN(value)) return value;
  }
  return undefined;
}

function providerBoolean(record: ProviderRecord | null, keys: string[]): boolean | undefined {
  if (record === null) return undefined;
  for (let index = 0; index < keys.length; index++) {
    const value = record[keys[index]];
    if (typeof value === 'boolean') return value;
  }
  return undefined;
}

function putProviderText(target: ProviderRecord, key: string, value: string): void {
  if (value.length > 0) target[key] = value;
}

function putProviderNumber(target: ProviderRecord, key: string, value: number | undefined): void {
  if (value !== undefined) target[key] = value;
}

function putProviderBoolean(target: ProviderRecord, key: string, value: boolean | undefined): void {
  if (value !== undefined) target[key] = value;
}

function githubRepoRecord(event: ProviderRecord): ProviderRecord {
  const repo = providerRecord(event['repo']);
  const name = providerText(repo, ['name', 'full_name']);
  const normalized: ProviderRecord = {};
  normalized['name'] = name.length > 0 ? name : '未知仓库';
  let url = providerText(repo, ['html_url', 'url']);
  if (name.length > 0 && (url.length === 0 || url.indexOf('api.github.com/repos/') >= 0)) {
    url = 'https://github.com/' + name;
  }
  putProviderText(normalized, 'url', url);
  return normalized;
}

function githubBranch(ref: string): string {
  if (ref.indexOf('refs/heads/') === 0) return ref.substring('refs/heads/'.length);
  if (ref.indexOf('refs/tags/') === 0) return ref.substring('refs/tags/'.length);
  return ref;
}

function githubIssueDetails(payload: ProviderRecord | null): ProviderRecord {
  const issue = providerRecord(payload === null ? undefined : payload['issue']);
  const details: ProviderRecord = {};
  putProviderText(details, 'action', providerText(payload, ['action']));
  putProviderNumber(details, 'number', providerNumber(issue, ['number']));
  putProviderText(details, 'issueTitle', providerText(issue, ['title']));
  putProviderText(details, 'state', providerText(issue, ['state']));
  putProviderText(details, 'url', providerText(issue, ['html_url']));
  return details;
}

function githubIssueLabel(payload: ProviderRecord | null): string {
  const issue = providerRecord(payload === null ? undefined : payload['issue']);
  const number = providerNumber(issue, ['number']);
  return number === undefined ? 'Issue' : 'Issue #' + number.toString();
}

function readableIssueAction(action: string): string {
  if (action === 'opened') return '创建了';
  if (action === 'closed') return '关闭了';
  if (action === 'reopened') return '重新打开了';
  if (action === 'labeled') return '标记了';
  if (action === 'unlabeled') return '移除了标签';
  return action.length > 0 ? '更新了（' + action + '）' : '更新了';
}

function readableCommentAction(action: string): string {
  if (action.length === 0 || action === 'created') return '发表了评论';
  if (action === 'edited') return '编辑了评论';
  if (action === 'deleted') return '删除了评论';
  return '更新了评论（' + action + '）';
}

function githubPushEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const branch = githubBranch(providerText(payload, ['ref']));
  const commitsValue = payload === null ? undefined : payload['commits'];
  const commits = Array.isArray(commitsValue) ? commitsValue as ProviderJsonValue[] : [];
  const distinctSize = providerNumber(payload, ['distinct_size', 'size']);
  const commitCount = distinctSize === undefined ? (commits.length > 0 ? commits.length : undefined) : distinctSize;
  const messages: ProviderJsonValue[] = [];
  for (let index = 0; index < commits.length && index < 5; index++) {
    const message = providerText(providerRecord(commits[index]), ['message']);
    if (message.length > 0) messages.push(message);
  }
  const details: ProviderRecord = {};
  putProviderText(details, 'branch', branch);
  putProviderNumber(details, 'commitCount', commitCount);
  if (messages.length > 0) details['commitMessages'] = messages as Object;
  const target = branch.length > 0 ? repoName + ' 的 ' + branch + ' 分支' : repoName;
  const summary = commitCount === undefined ? '向 ' + target + '执行了推送' :
    (commitCount === 0 ? '向 ' + target + '执行了推送（未包含新提交）' :
      '向 ' + target + '推送了 ' + commitCount.toString() + ' 个提交');
  return {
    kind: 'push', title: '更新了 ' + repoName,
    summary: summary,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubWatchEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const details: ProviderRecord = {};
  putProviderText(details, 'action', providerText(payload, ['action']));
  return {
    kind: 'star', title: 'Star 了 ' + repoName, summary: '给 ' + repoName + ' 点了 Star',
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubReleaseEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const release = providerRecord(payload === null ? undefined : payload['release']);
  const tag = providerText(release, ['tag_name', 'name']);
  const details: ProviderRecord = {};
  putProviderText(details, 'action', providerText(payload, ['action']));
  putProviderText(details, 'tag', tag);
  putProviderText(details, 'releaseName', providerText(release, ['name']));
  putProviderText(details, 'url', providerText(release, ['html_url']));
  putProviderText(details, 'publishedAt', providerText(release, ['published_at']));
  putProviderBoolean(details, 'prerelease', providerBoolean(release, ['prerelease']));
  const suffix = tag.length > 0 ? ' ' + tag : '';
  return {
    kind: 'release', title: '发布了 ' + repoName + suffix,
    summary: '在 ' + repoName + ' 发布了版本' + suffix,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubIssuesEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const action = providerText(payload, ['action']);
  const label = githubIssueLabel(payload);
  return {
    kind: 'issue', title: readableIssueAction(action) + ' ' + repoName + ' 的 ' + label,
    summary: '在 ' + repoName + ' ' + readableIssueAction(action) + label,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']),
    details: githubIssueDetails(payload) as Object
  };
}

function githubIssueCommentEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const label = githubIssueLabel(payload);
  const details = githubIssueDetails(payload);
  const issue = providerRecord(payload === null ? undefined : payload['issue']);
  const pullRequest = providerRecord(issue === null ? undefined : issue['pull_request']);
  const comment = providerRecord(payload === null ? undefined : payload['comment']);
  putProviderText(details, 'commentUrl', providerText(comment, ['html_url']));
  const isPullRequest = pullRequest !== null;
  const actionLabel = readableCommentAction(providerText(payload, ['action']));
  const targetLabel = isPullRequest ? label.replace('Issue', 'Pull Request') : label;
  return {
    kind: isPullRequest ? 'pull_request_comment' : 'issue_comment',
    title: actionLabel + '：' + repoName + ' 的 ' + targetLabel,
    summary: '在 ' + repoName + ' 的 ' + targetLabel + ' 下' + actionLabel,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubForkEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const forkee = providerRecord(payload === null ? undefined : payload['forkee']);
  const forkName = providerText(forkee, ['full_name', 'name']);
  const details: ProviderRecord = {};
  putProviderText(details, 'forkName', forkName);
  putProviderText(details, 'url', providerText(forkee, ['html_url']));
  return {
    kind: 'fork', title: 'Fork 了 ' + repoName,
    summary: forkName.length > 0 ? '将 ' + repoName + ' Fork 到 ' + forkName : 'Fork 了 ' + repoName,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function readablePullRequestAction(action: string): string {
  if (action === 'opened') return '创建了';
  if (action === 'closed') return '关闭了';
  if (action === 'reopened') return '重新打开了';
  if (action === 'synchronize') return '更新了';
  if (action === 'merged') return '合并了';
  if (action === 'assigned') return '指派了';
  if (action === 'unassigned') return '取消了指派';
  if (action === 'labeled') return '标记了';
  if (action === 'unlabeled') return '移除了标签';
  if (action === 'review_requested') return '请求评审了';
  if (action === 'review_request_removed') return '取消了评审请求';
  return action.length > 0 ? '更新了（' + action + '）' : '更新了';
}

function githubPullRequestEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const pull = providerRecord(payload === null ? undefined : payload['pull_request']);
  const rawAction = providerText(payload, ['action']);
  const merged = providerBoolean(pull, ['merged']);
  const action = rawAction === 'closed' && merged === true ? 'merged' : rawAction;
  const number = providerNumber(payload, ['number']) ?? providerNumber(pull, ['number']);
  const label = number === undefined ? 'Pull Request' : 'Pull Request #' + number.toString();
  const details: ProviderRecord = {};
  putProviderText(details, 'action', action);
  putProviderNumber(details, 'number', number);
  putProviderText(details, 'pullRequestTitle', providerText(pull, ['title']));
  putProviderText(details, 'state', providerText(pull, ['state']));
  putProviderText(details, 'url', providerText(pull, ['html_url']));
  putProviderBoolean(details, 'merged', merged);
  return {
    kind: 'pull_request', title: readablePullRequestAction(action) + ' ' + repoName + ' 的 ' + label,
    summary: '在 ' + repoName + ' ' + readablePullRequestAction(action) + label,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubPullRequestReviewEvent(
  event: ProviderRecord,
  repo: ProviderRecord,
  payload: ProviderRecord | null,
  comment: boolean
): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const pull = providerRecord(payload === null ? undefined : payload['pull_request']);
  const number = providerNumber(pull, ['number']);
  const label = number === undefined ? 'Pull Request' : 'Pull Request #' + number.toString();
  const details: ProviderRecord = {};
  putProviderText(details, 'action', providerText(payload, ['action']));
  putProviderNumber(details, 'number', number);
  putProviderText(details, 'pullRequestTitle', providerText(pull, ['title']));
  putProviderText(details, 'pullRequestUrl', providerText(pull, ['html_url']));
  if (comment) {
    const reviewComment = providerRecord(payload === null ? undefined : payload['comment']);
    putProviderText(details, 'commentUrl', providerText(reviewComment, ['html_url']));
  } else {
    const review = providerRecord(payload === null ? undefined : payload['review']);
    putProviderText(details, 'reviewState', providerText(review, ['state']));
    putProviderText(details, 'reviewUrl', providerText(review, ['html_url']));
    putProviderText(details, 'submittedAt', providerText(review, ['submitted_at']));
  }
  const actionLabel = comment ? readableCommentAction(providerText(payload, ['action'])) : '';
  return {
    kind: comment ? 'pull_request_review_comment' : 'pull_request_review',
    title: comment ? actionLabel + '：' + repoName + ' 的 ' + label : '评审了 ' + repoName + ' 的 ' + label,
    summary: comment ? '在 ' + repoName + ' 的 ' + label + ' 代码评审中' + actionLabel :
      '评审了 ' + repoName + ' 的 ' + label,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubCommitCommentEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const comment = providerRecord(payload === null ? undefined : payload['comment']);
  const details: ProviderRecord = {};
  putProviderText(details, 'commentUrl', providerText(comment, ['html_url']));
  return {
    kind: 'commit_comment', title: '评论了 ' + repoName + ' 的提交',
    summary: '在 ' + repoName + ' 的一个提交下发表了评论',
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubCreateEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const refType = providerText(payload, ['ref_type']);
  const ref = providerText(payload, ['ref']);
  const objectLabel = refType === 'branch' ? '分支' : (refType === 'tag' ? '标签' :
    (refType === 'repository' ? '仓库' : (refType.length > 0 ? refType : '内容')));
  const details: ProviderRecord = {};
  putProviderText(details, 'refType', refType);
  putProviderText(details, 'ref', ref);
  putProviderText(details, 'description', providerText(payload, ['description']));
  const suffix = ref.length > 0 ? ' ' + ref : '';
  return {
    kind: 'create', title: '在 ' + repoName + ' 创建了 ' + objectLabel + suffix,
    summary: '在 ' + repoName + ' 创建了 ' + objectLabel + suffix,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubDeleteEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const refType = providerText(payload, ['ref_type']);
  const ref = providerText(payload, ['ref']);
  const details: ProviderRecord = {};
  putProviderText(details, 'refType', refType);
  putProviderText(details, 'ref', ref);
  const objectLabel = refType === 'branch' ? '分支' : (refType === 'tag' ? '标签' :
    (refType.length > 0 ? refType : '引用'));
  const target = objectLabel + (ref.length > 0 ? ' ' + ref : '');
  return {
    kind: 'delete', title: '从 ' + repoName + ' 删除了 ' + target,
    summary: '从 ' + repoName + ' 删除了 ' + target,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubDiscussionEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const discussion = providerRecord(payload === null ? undefined : payload['discussion']);
  const number = providerNumber(discussion, ['number']);
  const label = number === undefined ? 'Discussion' : 'Discussion #' + number.toString();
  const action = providerText(payload, ['action']);
  const details: ProviderRecord = {};
  putProviderText(details, 'action', action);
  putProviderNumber(details, 'number', number);
  putProviderText(details, 'discussionTitle', providerText(discussion, ['title']));
  putProviderText(details, 'url', providerText(discussion, ['html_url']));
  const actionLabel = action === 'created' ? '创建了' : (action === 'edited' ? '编辑了' :
    (action === 'deleted' ? '删除了' : (action.length > 0 ? '更新了（' + action + '）' : '更新了')));
  return {
    kind: 'discussion', title: '更新了 ' + repoName + ' 的 ' + label,
    summary: '在 ' + repoName + ' ' + actionLabel + ' ' + label,
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubGollumEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const pagesValue = payload === null ? undefined : payload['pages'];
  const pages = Array.isArray(pagesValue) ? pagesValue as ProviderJsonValue[] : [];
  const pageTitles: ProviderJsonValue[] = [];
  for (let index = 0; index < pages.length && index < 5; index++) {
    const page = providerRecord(pages[index]);
    const title = providerText(page, ['title', 'page_name']);
    if (title.length > 0) pageTitles.push(title);
  }
  const details: ProviderRecord = {};
  details['pageCount'] = pages.length;
  if (pageTitles.length > 0) details['pageTitles'] = pageTitles as Object;
  return {
    kind: 'wiki', title: '更新了 ' + repoName + ' 的 Wiki',
    summary: '更新了 ' + repoName + ' 的 ' + pages.length.toString() + ' 个 Wiki 页面',
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubMemberEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const member = providerRecord(payload === null ? undefined : payload['member']);
  const login = providerText(member, ['login']);
  const action = providerText(payload, ['action']);
  const details: ProviderRecord = {};
  putProviderText(details, 'action', action);
  putProviderText(details, 'member', login);
  return {
    kind: 'member', title: '更新了 ' + repoName + ' 的协作者',
    summary: (action === 'added' ? '将 ' : '更新了 ') + (login.length > 0 ? login + ' ' : '') +
      (action === 'added' ? '添加到 ' + repoName : '在 ' + repoName + ' 的成员关系'),
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubPublicEvent(event: ProviderRecord, repo: ProviderRecord): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const details: ProviderRecord = {};
  return {
    kind: 'public', title: '公开了 ' + repoName, summary: '将仓库 ' + repoName + ' 设为公开',
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubFallbackEvent(event: ProviderRecord, repo: ProviderRecord, payload: ProviderRecord | null): GitHubNormalizedEvent {
  const repoName = providerText(repo, ['name']);
  const rawType = providerText(event, ['type']);
  const details: ProviderRecord = {};
  putProviderText(details, 'eventType', rawType);
  putProviderText(details, 'action', providerText(payload, ['action']));
  return {
    kind: 'other', title: '更新了 ' + repoName,
    summary: '在 ' + repoName + ' 发生了 ' + (rawType.length > 0 ? rawType : 'GitHub 活动'),
    repo: repo as Object, occurredAt: providerText(event, ['created_at']), details: details as Object
  };
}

function githubEventVisibility(event: ProviderRecord): string {
  const isPublic = providerBoolean(event, ['public']);
  if (isPublic === true) return 'public';
  if (isPublic === false) return 'private';
  return 'unknown';
}

function normalizeGitHubEvent(value: ProviderJsonValue): GitHubNormalizedEvent {
  const parsedEvent = providerRecord(value);
  const emptyEvent: ProviderRecord = {};
  const event = parsedEvent === null ? emptyEvent : parsedEvent;
  const rawType = providerText(event, ['type']);
  const repo = githubRepoRecord(event);
  const payload = providerRecord(event['payload']);
  let normalized: GitHubNormalizedEvent;
  if (rawType === 'PushEvent') {
    normalized = githubPushEvent(event, repo, payload);
  } else if (rawType === 'WatchEvent') {
    const action = providerText(payload, ['action']);
    normalized = action.length === 0 || action === 'started' ? githubWatchEvent(event, repo, payload) :
      githubFallbackEvent(event, repo, payload);
  } else if (rawType === 'ReleaseEvent') {
    normalized = githubReleaseEvent(event, repo, payload);
  } else if (rawType === 'IssuesEvent') {
    normalized = githubIssuesEvent(event, repo, payload);
  } else if (rawType === 'IssueCommentEvent') {
    normalized = githubIssueCommentEvent(event, repo, payload);
  } else if (rawType === 'ForkEvent') {
    normalized = githubForkEvent(event, repo, payload);
  } else if (rawType === 'PullRequestEvent') {
    normalized = githubPullRequestEvent(event, repo, payload);
  } else if (rawType === 'PullRequestReviewEvent') {
    normalized = githubPullRequestReviewEvent(event, repo, payload, false);
  } else if (rawType === 'PullRequestReviewCommentEvent') {
    normalized = githubPullRequestReviewEvent(event, repo, payload, true);
  } else if (rawType === 'CommitCommentEvent') {
    normalized = githubCommitCommentEvent(event, repo, payload);
  } else if (rawType === 'CreateEvent') {
    normalized = githubCreateEvent(event, repo, payload);
  } else if (rawType === 'DeleteEvent') {
    normalized = githubDeleteEvent(event, repo, payload);
  } else if (rawType === 'DiscussionEvent') {
    normalized = githubDiscussionEvent(event, repo, payload);
  } else if (rawType === 'GollumEvent') {
    normalized = githubGollumEvent(event, repo, payload);
  } else if (rawType === 'MemberEvent') {
    normalized = githubMemberEvent(event, repo, payload);
  } else if (rawType === 'PublicEvent') {
    normalized = githubPublicEvent(event, repo);
  } else {
    normalized = githubFallbackEvent(event, repo, payload);
  }
  normalized.visibility = githubEventVisibility(event);
  return normalized;
}

function normalizeGitHubUserEvents(value: ProviderJsonValue): ProviderJsonValue {
  const root = providerRecord(value);
  const rawEvents = Array.isArray(value) ? value : (root === null ? undefined : root['events']);
  if (!Array.isArray(rawEvents)) return value;
  const events: ProviderJsonValue[] = [];
  for (let index = 0; index < rawEvents.length; index++) {
    events.push(normalizeGitHubEvent(rawEvents[index] as ProviderJsonValue) as Object);
  }
  const metadata: ProviderRecord = {};
  metadata['source'] = GITHUB_USER_EVENTS_TOOL;
  metadata['schemaVersion'] = GITHUB_USER_EVENTS_NORMALIZED_SCHEMA_VERSION;
  metadata['normalized'] = true;
  const nextPageToken = providerText(root, ['nextPageToken', 'next_page_token', 'pageToken', 'next_cursor']);
  putProviderText(metadata, 'nextPageToken', nextPageToken);
  putProviderBoolean(metadata, 'hasMore', providerBoolean(root, ['hasMore', 'has_more']));
  const normalized: GitHubNormalizedData = {
    events: events as Object[], count: events.length, metadata: metadata as Object
  };
  return normalized as Object;
}

function providerDataForTool(value: ProviderJsonValue, toolSlug: string): ProviderJsonValue {
  if (toolSlug.trim().toUpperCase() === GITHUB_USER_EVENTS_TOOL) return normalizeGitHubUserEvents(value);
  return value;
}

function emptyMeta(originalChars: number): ComposioProviderDataMeta {
  return {
    truncated: false, originalChars: originalChars, retainedChars: 0, reason: '', arrays: [],
    redactedSecretFields: 0, redactedBinaryFields: 0
  };
}

export function extractComposioProviderData(
  observation: string,
  toolSlug: string = ''
): ComposioProviderDataExtraction {
  const meta = emptyMeta(observation.length);
  try {
    const payload = JSON.parse(observation) as Object;
    const preferred = providerDataForTool(preferredProviderData(payload), toolSlug);
    if (preferred === undefined || preferred === null || typeof preferred !== 'object') return { data: null, meta: meta };
    const state: ProviderDataState = { budget: { remaining: PROVIDER_DATA_CONTENT_BUDGET }, meta: meta };
    const bounded = boundedProviderValue(preferred, 0, '', state);
    if (bounded === undefined || bounded === null || typeof bounded !== 'object') return { data: null, meta: meta };
    const retainedChars = JSON.stringify(bounded).length;
    meta.retainedChars = retainedChars;
    if (retainedChars > PROVIDER_DATA_MAX_JSON) {
      meta.truncated = true;
      meta.reason = 'provider_data_size_limit';
      return { data: null, meta: meta };
    }
    return { data: bounded as Object, meta: meta };
  } catch (_error) {
    return { data: null, meta: meta };
  }
}

export function composioProviderDataFromObservation(observation: string, toolSlug: string = ''): Object | null {
  return extractComposioProviderData(observation, toolSlug).data;
}
