import { ComposioConfig } from '../../composio/ComposioConfig';
import {
  ComposioPreservedExecution,
  ComposioSessionClient,
  proxyToolkitAccountsFromAuthConfigs
} from '../../composio/ComposioSessionClient';
import { A2uiLabelValueData } from './A2uiTypes';
import {
  dynamicCompoundControlPrefix,
  dynamicMutationActionPrefix,
  isDynamicCompoundControlToken,
  isDynamicMutationActionToken,
  isUnsafeMcpTool,
  normalizedDynamicToolTokens
} from './DynamicToolRegistry';
import {
  DynamicGenericToolResult,
  DynamicRegistrationMetadata,
  dynamicReceiptFromProviderPayload
} from './DynamicToolTypes';
import {
  composioProviderDataFromObservation,
  extractComposioProviderData,
  githubUserEventsNormalizedOutputSchema
} from '../../composio/ComposioProviderData';

export {
  composioProviderDataFromObservation,
  githubUserEventsNormalizedOutputSchema
} from '../../composio/ComposioProviderData';

interface ComposioExecuteArgs {
  operation?: string;
  qualifiedName?: string;
  toolSlug?: string;
  arguments?: Object;
  fixedToolId?: string;
  fixedArgs?: Object;
}

export interface ComposioRawExecution {
  toolSlug: string;
  observation: string;
}

export interface ComposioSearchTool {
  toolSlug?: string;
  description?: string;
  inputSchema?: string;
  outputSchema?: string;
}

export interface ComposioSearchExecuteClient {
  search(useCase: string): Promise<string>;
  execute(toolSlug: string, args: Object): Promise<string>;
}

interface ComposioSearchObservation {
  source?: string;
  authorizedToolkits?: string[];
  tools?: Object[];
  instruction?: string;
}

interface ComposioInputSchemaProperty {
  type?: string;
  default?: Object | string | number | boolean | null;
  enum?: string[];
  description?: string;
}

interface ComposioInputSchema {
  type?: string;
  required?: string[];
  properties?: Record<string, ComposioInputSchemaProperty>;
}

interface ComposioArrayHit {
  found: boolean;
  label: string;
  items: Object[];
}

interface ComposioExecutionObservation {
  observation: string;
  providerData?: Object;
  providerDataMeta?: Object;
}

interface GitHubOperationSpec {
  operationTarget: string;
  section: string;
  toolSlug: string;
  useCase: string;
}

interface GitHubSchemaValidation {
  ok: boolean;
  message: string;
  schema: Object;
  args: Object;
}

interface GitHubSectionExecution {
  ok: boolean;
  empty: boolean;
  data: Object | null;
  inputSchema: Object;
  receipt: string;
  result: DynamicGenericToolResult;
  provenance: Object;
  providerDataMeta?: Object;
}

interface GitHubNormalizedSection {
  data: Object | null;
  empty: boolean;
}

type GitHubJsonValue = Object | string | number | boolean | null | undefined;
type GitHubJsonRecord = Record<string, GitHubJsonValue>;

const GITHUB_PROFILE_TARGET: string = 'github.profile';
const GITHUB_REPOSITORIES_TARGET: string = 'github.repositories';
const GITHUB_EVENTS_TARGET: string = 'github.events';
const GITHUB_DASHBOARD_TARGET: string = 'github.user.dashboard';
const GITHUB_PROFILE_TOOL: string = 'GITHUB_GET_A_USER';
const GITHUB_REPOSITORIES_TOOL: string = 'GITHUB_LIST_REPOSITORIES_FOR_A_USER';
const GITHUB_EVENTS_TOOL: string = 'GITHUB_LIST_EVENTS_FOR_USER';
const MAX_TRUSTED_GITHUB_SCHEMA_CHARS: number = 3000;

function emptyGitHubRecord(): GitHubJsonRecord {
  return new Object() as GitHubJsonRecord;
}

interface FixedArgumentAlias {
  source: string;
  targets: string[];
}

let composioConfig: ComposioConfig = new ComposioConfig('', 'https://backend.composio.dev/api/v3.1', '', '', '');
let composioClient: ComposioSessionClient | null = null;
let scopedComposioClients: Map<string, ComposioSessionClient> = new Map();
let runtimeComposioUserId: string = '';

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function argumentRecord(value: Object | null | undefined): Record<string, Object | string | number | boolean | null | undefined> {
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return {};
  }
  return value as Record<string, Object | string | number | boolean | null | undefined>;
}

function hasMeaningfulValue(value: Object | string | number | boolean | null | undefined): boolean {
  if (value === undefined || value === null) {
    return false;
  }
  if (typeof value === 'string') {
    return value.trim().length > 0;
  }
  if (Array.isArray(value)) {
    for (let index = 0; index < value.length; index++) {
      if (hasMeaningfulValue(value[index] as Object | string | number | boolean | null | undefined)) {
        return true;
      }
    }
    return false;
  }
  return true;
}

function parsedExecuteArgs(args: Object | null): ComposioExecuteArgs {
  if (args === null) {
    return {};
  }
  return args as ComposioExecuteArgs;
}

function selectedQualifiedName(parsed: ComposioExecuteArgs): string {
  return textOf(parsed.qualifiedName).trim();
}

function composioToolSchema(rawSchema: string | undefined): Object {
  const raw = textOf(rawSchema).trim();
  if (raw.length === 0) {
    return new Object();
  }
  try {
    return JSON.parse(raw) as Object;
  } catch (_error) {
    return new Object();
  }
}

function slugContainsAny(slug: string, parts: string[]): boolean {
  for (let index = 0; index < parts.length; index++) {
    if (slug.indexOf(parts[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function isSafeGmailDraftMutationSlug(slug: string): boolean {
  return slugContainsAny(slug, ['draft']) &&
    !slugContainsAny(slug, ['send', 'delete', 'publish', 'remove']);
}

function isSafeGmailDraftCreateSlug(slug: string): boolean {
  return isSafeGmailDraftMutationSlug(slug) &&
    slugContainsAny(slug, ['create', 'upsert', 'save']) &&
    !slugContainsAny(slug, ['update', 'edit', 'apply']);
}

function isSafeGmailDraftApplySlug(slug: string): boolean {
  return slug.trim().toLowerCase() === 'gmail_update_draft';
}

function rowsForSearch(payload: ComposioSearchObservation): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  const toolkits = Array.isArray(payload.authorizedToolkits) ? payload.authorizedToolkits.join(', ') : '';
  if (toolkits.length > 0) {
    rows.push({ label: '授权 Toolkit', value: toolkits });
  }
  if (Array.isArray(payload.tools)) {
    payload.tools.forEach((item: Object) => {
      const tool = item as ComposioSearchTool;
      rows.push({
        label: textOf(tool.toolSlug),
        value: textOf(tool.description).substring(0, 240)
      });
    });
  }
  return rows;
}

function lowerText(value: string): string {
  return value.toLowerCase();
}

function containsAny(value: string, needles: string[]): boolean {
  const lower = lowerText(value);
  for (let index = 0; index < needles.length; index++) {
    if (lower.indexOf(lowerText(needles[index])) >= 0) {
      return true;
    }
  }
  return false;
}

function composioToolkitFromPrompt(prompt: string): string {
  const lower = prompt.toLowerCase();
  if (lower.indexOf('composio twitter') >= 0 || lower.indexOf('composio x') >= 0) {
    return 'twitter';
  }
  if (lower.indexOf('composio slack') >= 0) {
    return 'slack';
  }
  if (lower.indexOf('composio discord') >= 0) {
    return 'discord';
  }
  if (lower.indexOf('composio linkedin') >= 0) {
    return 'linkedin';
  }
  if (lower.indexOf('composio whatsapp') >= 0 || lower.indexOf('composio whats app') >= 0) {
    return 'whatsapp';
  }
  if (lower.indexOf('composio instagram') >= 0 || lower.indexOf('composio instgram') >= 0) {
    return 'instagram';
  }
  if (lower.indexOf('gmail') >= 0 || prompt.indexOf('谷歌邮箱') >= 0 || prompt.indexOf('谷歌邮件') >= 0) {
    return 'gmail';
  }
  if (lower.indexOf('google calendar') >= 0 || lower.indexOf('calendar') >= 0 || prompt.indexOf('谷歌日历') >= 0) {
    return 'googlecalendar';
  }
  if (lower.indexOf('youtube') >= 0 || prompt.indexOf('油管') >= 0) {
    return 'youtube';
  }
  if (lower.indexOf('google drive') >= 0) {
    return 'googledrive';
  }
  if (lower.indexOf('google docs') >= 0 || lower.indexOf('google doc') >= 0) {
    return 'googledocs';
  }
  if (lower.indexOf('outlook') >= 0 || lower.indexOf('微软邮箱') >= 0) {
    return 'outlook';
  }
  if (lower.indexOf('slack') >= 0) {
    return 'slack';
  }
  if (lower.indexOf('discord') >= 0) {
    return 'discord';
  }
  if (lower.indexOf('linkedin') >= 0 || prompt.indexOf('领英') >= 0) {
    return 'linkedin';
  }
  if (lower.indexOf('whatsapp') >= 0 || lower.indexOf('whats app') >= 0) {
    return 'whatsapp';
  }
  if (lower.indexOf('instagram') >= 0 || lower.indexOf('instgram') >= 0 || lower.indexOf(' ig ') >= 0) {
    return 'instagram';
  }
  if (lower.indexOf('twitter') >= 0 || lower.indexOf(' x ') >= 0 || lower.indexOf('x/twitter') >= 0) {
    return 'twitter';
  }
  if (lower.indexOf('spotify') >= 0 || lower.indexOf('soptify') >= 0) {
    return 'spotify';
  }
  if (lower.indexOf('tiktok') >= 0 || lower.indexOf('tik tok') >= 0) {
    return 'tiktok';
  }
  if (lower.indexOf('ticketmaster') >= 0 || lower.indexOf('ticket master') >= 0) {
    return 'ticketmaster';
  }
  if (lower.indexOf('hacker news') >= 0 || lower.indexOf('hackernews') >= 0 || prompt.indexOf('黑客新闻') >= 0) {
    return 'hackernews';
  }
  if (lower.indexOf('reddit') >= 0 || prompt.indexOf('红迪') >= 0) {
    return 'reddit';
  }
  if (lower.indexOf('github') >= 0) {
    return 'github';
  }
  if (lower.indexOf('notion') >= 0) {
    return 'notion';
  }
  if (lower.indexOf('linear') >= 0) {
    return 'linear';
  }
  if (lower.indexOf('asana') >= 0) {
    return 'asana';
  }
  if (lower.indexOf('trello') >= 0) {
    return 'trello';
  }
  if (lower.indexOf('hubspot') >= 0) {
    return 'hubspot';
  }
  if (lower.indexOf('salesforce') >= 0) {
    return 'salesforce';
  }
  return '';
}

function promptSearchKeyword(prompt: string): string {
  const trimmed = prompt.trim();
  const mentionedIndex = trimmed.indexOf('提到');
  if (mentionedIndex >= 0) {
    let result = trimmed.substring(mentionedIndex + 2).trim();
    const endIndex = result.indexOf('的消息');
    if (endIndex >= 0) {
      result = result.substring(0, endIndex).trim();
    }
    if (result.length > 0) {
      return result;
    }
  }
  const findIndex = trimmed.lastIndexOf('找');
  if (findIndex >= 0) {
    const result = trimmed.substring(findIndex + 1).trim();
    if (result.length > 0) {
      return result;
    }
  }
  const searchIndex = trimmed.lastIndexOf('查');
  if (searchIndex >= 0) {
    const result = trimmed.substring(searchIndex + 1).trim();
    if (result.length > 0) {
      return result;
    }
  }
  return trimmed;
}

function isoDateDaysAgo(days: number): string {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
}

export function slackSearchQueryForPrompt(prompt: string): string {
  const keyword = promptSearchKeyword(prompt).trim();
  if (prompt.indexOf('提到') >= 0 && keyword.length > 0) {
    return keyword;
  }
  if (containsAny(prompt, ['最近30', '最近 30', '近30', '近 30', '私信', '消息', 'dm', 'direct message'])) {
    return 'after:' + isoDateDaysAgo(30);
  }
  return keyword;
}

function repoNameFromPrompt(prompt: string): string {
  if (prompt.indexOf('Appless-Phone') >= 0) {
    return 'Appless-Phone';
  }
  return '';
}

function ownerNameFromPrompt(prompt: string): string {
  if (prompt.indexOf('XiaoLuoLYG/Appless-Phone') >= 0 || prompt.indexOf('Appless-Phone') >= 0) {
    return 'XiaoLuoLYG';
  }
  return '';
}

const GITHUB_USER_SCOPED_READ_TOOLS: string[] = [
  'github_list_events_for_user',
  'github_get_a_user',
  'github_list_repositories_for_a_user'
];

function isGitHubUserScopedReadTool(toolSlug: string): boolean {
  return GITHUB_USER_SCOPED_READ_TOOLS.indexOf(toolSlug.trim().toLowerCase()) >= 0;
}

function validGitHubLogin(value: string): string {
  const login = value.trim();
  if (login.length === 0 || login.length > 39 || login.startsWith('-') || login.endsWith('-') ||
    login.indexOf('--') >= 0) {
    return '';
  }
  return /^[A-Za-z0-9-]+$/.test(login) ? login : '';
}

function structuredDynamicQuery(args: Object | null): string {
  const query = argumentRecord(args)['query'];
  return typeof query === 'string' ? validGitHubLogin(query) : '';
}

function explicitGitHubUsernameFromPrompt(prompt: string): string {
  const chinese = prompt.match(/github\s*用户\s*[:：]?\s*([^\s,，。；;：:、!?！？/\\()\[\]{}<>"']+)/i);
  if (chinese !== null && chinese.length > 1) {
    return validGitHubLogin(chinese[1]);
  }
  const english = prompt.match(/github\s+user\s*[:：]?\s*([^\s,，。；;：:、!?！？/\\()\[\]{}<>"']+)/i);
  if (english !== null && english.length > 1) {
    return validGitHubLogin(english[1]);
  }
  return '';
}

export function normalizedComposioUseCase(prompt: string, fixedToolId: string = ''): string {
  const keyword = promptSearchKeyword(prompt);
  const toolkit = composioToolkitFromPrompt(prompt);
  if (fixedToolId === 'social.x.profile') {
    return 'Get authenticated X Twitter user profile';
  }
  if (fixedToolId === 'social.x.dm.list') {
    return 'List recent X Twitter direct message events';
  }
  if (fixedToolId === 'social.slack.message.search') {
    return 'Search recent Slack direct messages';
  }
  if (fixedToolId === 'social.slack.message.send') {
    return 'Reply to a Slack message in its thread';
  }
  if (fixedToolId === 'social.instagram.conversations.list') {
    return 'List Instagram messaging conversations';
  }
  if (fixedToolId === 'social.instagram.profile') {
    return 'Get authenticated Instagram user profile';
  }
  if (fixedToolId === 'social.instagram.messages.list') {
    return 'List messages in an Instagram conversation';
  }
  if (fixedToolId === 'social.x.community.search') {
    return 'Search recent public X Twitter posts';
  }
  if (fixedToolId === 'social.linkedin.profile') {
    return 'Get authenticated LinkedIn member profile';
  }
  if (fixedToolId === 'social.linkedin.post.read') {
    return 'Get one LinkedIn post by resource ID';
  }
  if (fixedToolId === 'social.instagram.media.list') {
    return 'List authenticated Instagram creator media';
  }
  if (fixedToolId === 'social.reddit.profile') {
    return 'Get authenticated Reddit user profile';
  }
  if (fixedToolId === 'social.reddit.search') {
    return 'Search public Reddit posts across subreddits';
  }
  if (fixedToolId === 'whatsapp.phone_numbers.list') {
    return 'List WhatsApp Business phone numbers for the authenticated account';
  }
  if (fixedToolId === 'whatsapp.message.send') {
    return 'Send a WhatsApp Business text message';
  }
  if (fixedToolId === 'calendar.events.search') {
    return 'List Google Calendar events';
  }
  if (fixedToolId === 'calendar.event.create') {
    return 'Create a Google Calendar event';
  }
  if (fixedToolId === 'calendar.event.update') {
    return 'Patch a Google Calendar event';
  }
  if (fixedToolId === 'calendar.event.delete') {
    return 'Delete a Google Calendar event by event ID';
  }
  if (fixedToolId === 'youtube.mine.playlists') {
    return 'List my YouTube playlists for the authenticated user';
  }
  if (fixedToolId === 'youtube.mine.subscriptions') {
    return 'List my YouTube subscriptions for the authenticated user';
  }
  if (fixedToolId === 'gmail.draft.create' || fixedToolId === 'gmail.draft.apply') {
    return fixedToolId === 'gmail.draft.apply' ?
      'Update an existing Gmail draft for review' : 'Create a Gmail draft for review';
  }
  if (fixedToolId === 'gmail.reply.send') {
    return 'Reply to an existing Gmail thread';
  }
  if (fixedToolId === 'gmail.message.read') {
    return 'Fetch exactly one Gmail email message by its message ID, not the entire thread';
  }
  if (fixedToolId === 'gmail.thread.read') {
    return 'Read the full Gmail thread content by thread ID';
  }
  if (toolkit === 'gmail') {
    return 'Search Gmail messages for ' + keyword;
  }
  if (toolkit === 'googlecalendar') {
    return 'Search Google Calendar events for ' + keyword;
  }
  if (toolkit === 'youtube') {
    return 'List YouTube account data or search YouTube for ' + keyword;
  }
  if (toolkit === 'twitter') {
    return 'Search X Twitter posts or direct messages for ' + keyword;
  }
  if (toolkit === 'outlook') {
    return 'Search Outlook mail messages for ' + keyword;
  }
  if (toolkit === 'discord') {
    return 'Search Discord messages mentioning ' + keyword;
  }
  if (toolkit === 'linkedin') {
    return 'Find LinkedIn profile or post information about ' + keyword;
  }
  if (toolkit === 'whatsapp') {
    return 'Search WhatsApp messages mentioning ' + keyword;
  }
  if (toolkit === 'instagram') {
    return 'Search Instagram messages, comments, or media about ' + keyword;
  }
  if (toolkit === 'spotify') {
    return 'Search Spotify tracks, albums, or playlists for ' + keyword;
  }
  if (toolkit === 'tiktok') {
    return 'Search TikTok videos for ' + keyword;
  }
  if (toolkit === 'ticketmaster') {
    return 'Search Ticketmaster events for ' + keyword;
  }
  if (toolkit === 'hackernews') {
    return 'Search Hacker News posts for ' + keyword;
  }
  if (toolkit === 'reddit') {
    return 'Search Reddit posts for ' + keyword;
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['最近30', '最近 30', '近30', '近 30', '私信', 'dm', 'direct message'])) {
    return 'List recent Slack direct messages and channel messages from the last 30 days';
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['消息', 'message', 'mention', '提到'])) {
    return 'Search Slack messages mentioning ' + slackSearchQueryForPrompt(prompt);
  }
  if (containsAny(prompt, ['github']) && containsAny(prompt, ['pr', 'pull request', 'pull requests'])) {
    const owner = ownerNameFromPrompt(prompt);
    const repo = repoNameFromPrompt(prompt);
    const repoText = owner.length > 0 && repo.length > 0 ? owner + '/' + repo : (repo.length > 0 ? repo : keyword);
    return 'Find recent pull requests for GitHub repository ' + repoText;
  }
  if (containsAny(prompt, ['google drive'])) {
    return 'Find Google Drive files named or containing ' + keyword;
  }
  if (containsAny(prompt, ['google docs', 'google doc'])) {
    return 'Search Google Docs documents for ' + keyword;
  }
  return prompt;
}

function fixedToolAllowsSideEffectSlug(fixedToolId: string, slug: string): boolean {
  if (fixedToolId === 'gmail.draft.create') {
    return isSafeGmailDraftCreateSlug(slug);
  }
  if (fixedToolId === 'gmail.draft.apply') {
    return isSafeGmailDraftApplySlug(slug);
  }
  if (fixedToolId === 'gmail.reply.send') {
    return slug === 'gmail_reply_to_thread';
  }
  if (fixedToolId === 'calendar.event.create') {
    return slug === 'googlecalendar_create_event';
  }
  if (fixedToolId === 'calendar.event.update') {
    return slug === 'googlecalendar_patch_event';
  }
  if (fixedToolId === 'calendar.event.delete') {
    return slug === 'googlecalendar_delete_event';
  }
  if (fixedToolId === 'whatsapp.message.send') {
    return slug === 'whatsapp_send_message';
  }
  if (fixedToolId === 'social.slack.message.send') {
    return slug === 'slack_chat_post_message';
  }
  return false;
}

function fixedArgumentAliases(toolId: string): FixedArgumentAlias[] {
  if (toolId === 'gmail.mail.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'pageSize', targets: ['pageSize', 'page_size', 'limit', 'count', 'maxResults', 'max_results'] }
    ];
  }
  if (toolId === 'social.x.community.search') {
    return [
      { source: 'query', targets: ['query'] },
      { source: 'maxResults', targets: ['max_results', 'maxResults'] }
    ];
  }
  if (toolId === 'social.linkedin.profile') {
    return [];
  }
  if (toolId === 'social.linkedin.post.read') {
    return [{ source: 'postId', targets: ['post_id'] }];
  }
  if (toolId === 'social.instagram.media.list') {
    return [
      { source: 'igUserId', targets: ['ig_user_id'] },
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'social.reddit.profile') {
    return [{ source: 'username', targets: ['username'] }];
  }
  if (toolId === 'social.reddit.search') {
    return [
      { source: 'searchQuery', targets: ['search_query'] },
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'social.reddit.comments') {
    return [{ source: 'articleId', targets: ['article', 'article_id', 'articleId', 'id'] }];
  }
  if (toolId === 'social.hackernews.item.read') {
    return [{ source: 'itemId', targets: ['item_id', 'itemId', 'id'] }];
  }
  if (toolId === 'gmail.thread.read') {
    return [{ source: 'threadId', targets: ['threadId', 'thread_id', 'id'] }];
  }
  if (toolId === 'gmail.message.read') {
    return [{ source: 'messageId', targets: ['messageId', 'message_id', 'id'] }];
  }
  if (toolId === 'gmail.draft.create' || toolId === 'gmail.draft.apply') {
    return [
      { source: 'draftId', targets: ['draft_id', 'draftId'] },
      { source: 'to', targets: ['to', 'to_addresses', 'recipients', 'emails'] },
      { source: 'recipientEmail', targets: ['recipient_email'] },
      { source: 'subject', targets: ['subject', 'title'] },
      { source: 'body', targets: ['body', 'message', 'content', 'text'] },
      { source: 'threadId', targets: ['threadId', 'thread_id'] },
      { source: 'replyMode', targets: ['replyMode', 'reply_mode', 'mode'] }
    ];
  }
  if (toolId === 'gmail.reply.send') {
    return [
      { source: 'recipientEmail', targets: ['recipient_email'] },
      { source: 'body', targets: ['message_body', 'body', 'message'] },
      { source: 'threadId', targets: ['thread_id', 'threadId'] }
    ];
  }
  if (toolId === 'calendar.events.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'timeRange', targets: ['timeRange', 'time_range'] },
      { source: 'timeMin', targets: ['timeMin', 'time_min', 'start', 'startDateTime', 'start_time'] },
      { source: 'timeMax', targets: ['timeMax', 'time_max', 'end', 'endDateTime', 'end_time'] },
      { source: 'timezone', targets: ['timezone', 'timeZone'] },
      { source: 'calendarId', targets: ['calendarId', 'calendar_id'] }
    ];
  }
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    return [
      { source: 'eventId', targets: ['eventId', 'event_id', 'id'] },
      { source: 'title', targets: ['title', 'summary', 'name'] },
      { source: 'start', targets: ['start_datetime', 'start', 'startDateTime', 'start_time', 'startTime'] },
      { source: 'end', targets: ['end_datetime', 'end', 'endDateTime', 'end_time', 'endTime'] },
      { source: 'timezone', targets: ['timezone', 'timeZone'] },
      { source: 'calendarId', targets: ['calendarId', 'calendar_id'] }
    ];
  }
  if (toolId === 'calendar.event.delete') {
    return [
      { source: 'eventId', targets: ['event_id', 'eventId', 'id'] },
      { source: 'calendarId', targets: ['calendar_id', 'calendarId'] },
      { source: 'sendUpdates', targets: ['send_updates', 'sendUpdates'] }
    ];
  }
  if (toolId === 'whatsapp.phone_numbers.list') {
    return [
      { source: 'wabaId', targets: ['waba_id'] }
    ];
  }
  if (toolId === 'whatsapp.message.send') {
    return [
      { source: 'phoneNumberId', targets: ['phone_number_id'] },
      { source: 'toNumber', targets: ['to_number'] },
      { source: 'text', targets: ['text'] },
      { source: 'previewUrl', targets: ['preview_url'] }
    ];
  }
  if (toolId === 'social.x.dm.list') {
    return [
      { source: 'maxResults', targets: ['max_results', 'maxResults'] },
      { source: 'expansions', targets: ['expansions'] },
      { source: 'eventTypes', targets: ['event_types'] },
      { source: 'userFields', targets: ['user_fields'] },
      { source: 'dmEventFields', targets: ['dm_event_fields'] }
    ];
  }
  if (toolId === 'social.x.profile') {
    return [
      { source: 'userFields', targets: ['user_fields'] }
    ];
  }
  if (toolId === 'social.slack.message.search') {
    return [
      { source: 'query', targets: ['query'] },
      { source: 'sort', targets: ['sort'] },
      { source: 'count', targets: ['count'] }
    ];
  }
  if (toolId === 'social.slack.message.send') {
    return [
      { source: 'channel', targets: ['channel'] },
      { source: 'text', targets: ['text'] },
      { source: 'threadTs', targets: ['thread_ts'] }
    ];
  }
  if (toolId === 'social.instagram.conversations.list') {
    return [
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'social.instagram.profile') {
    return [
      { source: 'igUserId', targets: ['ig_user_id'] }
    ];
  }
  if (toolId === 'social.instagram.messages.list') {
    return [
      { source: 'conversationId', targets: ['conversation_id'] },
      { source: 'limit', targets: ['limit'] }
    ];
  }
  if (toolId === 'x.post.search') {
    return [
      { source: 'query', targets: ['query', 'q', 'search', 'keyword'] },
      { source: 'pageSize', targets: ['pageSize', 'page_size', 'limit', 'count', 'maxResults', 'max_results'] },
      { source: 'expansions', targets: ['expansions'] },
      { source: 'mediaFields', targets: ['media_fields', 'mediaFields'] },
      { source: 'tweetFields', targets: ['tweet_fields', 'tweetFields'] }
    ];
  }
  return [];
}

function fixedWritePreservedArgs(toolId: string): string[] {
  if (toolId === 'gmail.draft.create') {
    return ['to', 'subject', 'body', 'threadId', 'replyMode'];
  }
  if (toolId === 'gmail.draft.apply') {
    return ['draftId', 'to', 'subject', 'body', 'threadId'];
  }
  if (toolId === 'gmail.reply.send') {
    return ['recipientEmail', 'body', 'threadId'];
  }
  if (toolId === 'calendar.event.create' || toolId === 'calendar.event.update') {
    return ['eventId', 'title', 'start', 'end', 'timezone', 'calendarId'];
  }
  if (toolId === 'calendar.event.delete') {
    return ['eventId', 'calendarId', 'sendUpdates'];
  }
  if (toolId === 'whatsapp.message.send') {
    return ['phoneNumberId', 'toNumber', 'text', 'previewUrl'];
  }
  if (toolId === 'social.slack.message.send') {
    return ['channel', 'text', 'threadTs'];
  }
  return [];
}

function shouldPreserveMissingFixedWriteArg(toolId: string, targetName: string): boolean {
  const preserved = fixedWritePreservedArgs(toolId);
  if (preserved.length === 0) {
    return false;
  }
  const aliases = fixedArgumentAliases(toolId);
  for (let index = 0; index < aliases.length; index++) {
    const alias = aliases[index];
    if (preserved.indexOf(alias.source) < 0) {
      continue;
    }
    if (alias.source === targetName || alias.targets.indexOf(targetName) >= 0) {
      return true;
    }
  }
  return false;
}

function missingFixedWriteArgs(fixedToolId: string, fixedArgs: Object | null): string[] {
  const record = argumentRecord(fixedArgs);
  if (fixedToolId === 'gmail.draft.create') {
    const missing: string[] = [];
    ['to', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'gmail.draft.apply') {
    const missing: string[] = [];
    ['draftId', 'to', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'gmail.reply.send') {
    const missing: string[] = [];
    ['threadId', 'recipientEmail', 'body'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'calendar.event.create') {
    const missing: string[] = [];
    ['title', 'start', 'end'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'calendar.event.update') {
    const missing: string[] = [];
    if (!hasMeaningfulValue(record.eventId)) {
      missing.push('eventId');
    }
    if (!hasMeaningfulValue(record.title) && !hasMeaningfulValue(record.start) && !hasMeaningfulValue(record.end)) {
      missing.push('title/start/end');
    }
    return missing;
  }
  if (fixedToolId === 'calendar.event.delete') {
    return hasMeaningfulValue(record.eventId) ? [] : ['eventId'];
  }
  if (fixedToolId === 'whatsapp.message.send') {
    const missing: string[] = [];
    ['phoneNumberId', 'toNumber', 'text'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  if (fixedToolId === 'social.slack.message.send') {
    const missing: string[] = [];
    ['channel', 'text'].forEach((name: string) => {
      if (!hasMeaningfulValue(record[name])) {
        missing.push(name);
      }
    });
    return missing;
  }
  return [];
}

export function composioExactToolSlugForFixedTool(fixedToolId: string): string {
  if (fixedToolId === 'x.post.search') return 'TWITTER_RECENT_SEARCH';
  if (fixedToolId === 'social.x.profile') return 'TWITTER_USER_LOOKUP_ME';
  if (fixedToolId === 'social.x.dm.list') return 'TWITTER_GET_RECENT_DM_EVENTS';
  if (fixedToolId === 'social.slack.message.search') return 'SLACK_SEARCH_MESSAGES';
  if (fixedToolId === 'social.slack.message.send') return 'SLACK_CHAT_POST_MESSAGE';
  if (fixedToolId === 'social.instagram.profile') return 'INSTAGRAM_GET_USER_INFO';
  if (fixedToolId === 'social.instagram.conversations.list') return 'INSTAGRAM_LIST_ALL_CONVERSATIONS';
  if (fixedToolId === 'social.instagram.messages.list') return 'INSTAGRAM_LIST_ALL_MESSAGES';
  if (fixedToolId === 'social.x.community.search') return 'TWITTER_RECENT_SEARCH';
  if (fixedToolId === 'social.linkedin.profile') return 'LINKEDIN_GET_MY_INFO';
  if (fixedToolId === 'social.linkedin.post.read') return 'LINKEDIN_GET_POST_CONTENT';
  if (fixedToolId === 'social.instagram.media.list') return 'INSTAGRAM_GET_IG_USER_MEDIA';
  if (fixedToolId === 'social.reddit.profile') return 'REDDIT_GET_REDDIT_USER_ABOUT';
  if (fixedToolId === 'social.reddit.search') return 'REDDIT_SEARCH_ACROSS_SUBREDDITS';
  if (fixedToolId === 'social.reddit.comments') return 'REDDIT_RETRIEVE_POST_COMMENTS';
  if (fixedToolId === 'social.hackernews.item.read') return 'HACKERNEWS_GET_ITEM';
  if (fixedToolId === 'whatsapp.phone_numbers.list') return 'WHATSAPP_GET_PHONE_NUMBERS';
  if (fixedToolId === 'whatsapp.message.send') return 'WHATSAPP_SEND_MESSAGE';
  if (fixedToolId === 'calendar.events.search') return 'GOOGLECALENDAR_EVENTS_LIST';
  if (fixedToolId === 'calendar.event.create') return 'GOOGLECALENDAR_CREATE_EVENT';
  if (fixedToolId === 'calendar.event.update') return 'GOOGLECALENDAR_PATCH_EVENT';
  if (fixedToolId === 'calendar.event.delete') return 'GOOGLECALENDAR_DELETE_EVENT';
  if (fixedToolId === 'gmail.reply.send') return 'GMAIL_REPLY_TO_THREAD';
  if (fixedToolId === 'gmail.draft.apply') return 'GMAIL_UPDATE_DRAFT';
  if (fixedToolId === 'gmail.message.read') return 'GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID';
  return '';
}

function missingFixedWriteArgsResult(
  prompt: string,
  fixedToolId: string,
  missing: string[]
): DynamicGenericToolResult {
  const rows: A2uiLabelValueData[] = [{ label: 'Tool ID', value: fixedToolId }];
  missing.forEach((name: string) => rows.push({ label: 'Missing', value: name }));
  return {
    sourceTag: 'Composio',
    toolName: fixedToolId,
    title: resultTitleForPrompt(prompt) + ' 参数不完整',
    status: 'error',
    summary: '缺少字段：' + missing.join(', ') + '。固定写工具不会从 prompt 补全这些参数。',
    rows: rows,
    rawPreview: prompt.substring(0, 16000)
  };
}

function mergeFixedArguments(
  target: Record<string, Object | string | number | boolean>,
  schema: ComposioInputSchema,
  fixedToolId: string,
  fixedArgs: Object | null
): void {
  if (fixedToolId.length === 0 || fixedArgs === null) {
    return;
  }
  const record = argumentRecord(fixedArgs);
  if (fixedToolId === 'calendar.events.search' && !schemaHasProperties(schema)) {
    const names: string[][] = [
      ['query', 'q'],
      ['timeMin', 'timeMin'],
      ['timeMax', 'timeMax'],
      ['timezone', 'timeZone'],
      ['calendarId', 'calendarId']
    ];
    names.forEach((pair: string[]) => {
      const value = record[pair[0]];
      if (hasMeaningfulValue(value)) {
        target[pair[1]] = value as Object | string | number | boolean;
      }
    });
    target.singleEvents = true;
    target.orderBy = 'startTime';
    return;
  }
  fixedArgumentAliases(fixedToolId).forEach((alias: FixedArgumentAlias) => {
    const value = record[alias.source];
    const explicitEmptyQuery = alias.source === 'query' && value === '';
    if (!hasMeaningfulValue(value) && !explicitEmptyQuery) {
      return;
    }
    alias.targets.forEach((targetName: string) => setIfSupported(target, schema, targetName, value as Object | string | number | boolean));
    setIfSupported(target, schema, alias.source, value as Object | string | number | boolean);
  });
}

export function composioPreferredToolScore(prompt: string, tool: ComposioSearchTool, fixedToolId: string = ''): number {
  const slug = textOf(tool.toolSlug).toLowerCase();
  const description = textOf(tool.description).toLowerCase();
  if (slug.length === 0 ||
    (isUnsafeComposioExecute(slug, '{}') && !fixedToolAllowsSideEffectSlug(fixedToolId, slug))) {
    return -10000;
  }
  let score = 0;
  const sideEffectSlug = slugContainsAny(slug, ['send', 'delete', 'publish', 'post_tweet', 'create', 'update', 'insert', 'draft', 'patch', 'edit']);
  if (slug.indexOf('search') >= 0 || slug.indexOf('find') >= 0) {
    score += 24;
  }
  if (slug.indexOf('list') >= 0 || slug.indexOf('get') >= 0 || slug.indexOf('fetch') >= 0 || slug.indexOf('retrieve') >= 0) {
    score += 8;
  }
  if (description.indexOf('search') >= 0 || description.indexOf('find') >= 0) {
    score += 6;
  }
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit.length > 0 && slug.indexOf(toolkit) >= 0) {
    score += 160;
  }
  if ((toolkit === 'gmail' || toolkit === 'googlecalendar' || toolkit === 'youtube' || toolkit === 'twitter') &&
    (slug.indexOf('search') >= 0 || slug.indexOf('list') >= 0 || slug.indexOf('get') >= 0 || slug.indexOf('message') >= 0)) {
    score += 90;
  }
  if (sideEffectSlug && !fixedToolAllowsSideEffectSlug(fixedToolId, slug)) {
    score -= 700;
  }
  if (fixedToolId === 'gmail.mail.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list']) && slugContainsAny(slug, ['gmail', 'mail', 'message', 'thread']))) {
    score += 260;
  }
  if (fixedToolId === 'gmail.mail.search' && slug === 'gmail_fetch_emails') {
    score += 500;
  }
  if (fixedToolId === 'gmail.mail.search' &&
    slugContainsAny(slug, ['people', 'person', 'contact', 'profile'])) {
    score -= 800;
  }
  if (fixedToolId === 'gmail.message.read' &&
    (slugContainsAny(slug, ['get', 'read', 'fetch']) && slugContainsAny(slug, ['gmail', 'message']))) {
    score += 400;
  }
  if (fixedToolId === 'gmail.message.read' && slug === 'gmail_fetch_message_by_message_id') {
    score += 1200;
  }
  if (fixedToolId === 'gmail.message.read' &&
    (slug === 'gmail_fetch_message_by_thread_id' || slug === 'gmail_fetch_emails')) {
    score -= 1000;
  }
  if (fixedToolId === 'gmail.thread.read' &&
    (slugContainsAny(slug, ['get', 'read', 'fetch']) && slugContainsAny(slug, ['gmail', 'thread', 'message']))) {
    score += 400;
  }
  if (fixedToolId === 'gmail.thread.read' && slug === 'gmail_fetch_message_by_thread_id') {
    score += 1000;
  }
  if (fixedToolId === 'gmail.thread.read' && slug === 'gmail_fetch_emails') {
    score -= 900;
  }
  if (fixedToolId === 'gmail.draft.create' && isSafeGmailDraftCreateSlug(slug)) {
    score += 700;
  }
  if (fixedToolId === 'gmail.draft.apply' && isSafeGmailDraftApplySlug(slug)) {
    score += 700;
  }
  if (fixedToolId === 'gmail.reply.send' && slug === 'gmail_reply_to_thread') {
    score += 1200;
  }
  if (fixedToolId === 'calendar.events.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list', 'get']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 400;
  }
  if (fixedToolId === 'calendar.event.create' &&
    (slugContainsAny(slug, ['create', 'insert', 'add']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 700;
  }
  if (fixedToolId === 'calendar.event.update' &&
    (slugContainsAny(slug, ['update', 'patch', 'edit']) && slugContainsAny(slug, ['calendar', 'event']))) {
    score += 700;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slugContainsAny(slug, ['playlist']) && slugContainsAny(slug, ['list', 'get', 'search']))) {
    score += 400;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slug.indexOf('user_playlist') >= 0 || slug.indexOf('user_playlists') >= 0 ||
      slug.indexOf('my_playlist') >= 0 || description.indexOf('user playlist') >= 0)) {
    score += 700;
  }
  if (fixedToolId === 'youtube.mine.playlists' &&
    (slug.indexOf('playlist_item') >= 0 || slug.indexOf('playlist_items') >= 0 ||
      description.indexOf('playlist item') >= 0)) {
    score -= 700;
  }
  if (fixedToolId === 'youtube.mine.subscriptions' &&
    (slugContainsAny(slug, ['subscription']) && slugContainsAny(slug, ['list', 'get', 'search']))) {
    score += 400;
  }
  if (fixedToolId === 'x.post.search' &&
    (slugContainsAny(slug, ['search', 'find', 'list']) && slugContainsAny(slug, ['twitter', 'tweet', 'post', 'x_']))) {
    score += 400;
  }
  if (toolkit === 'outlook' && (slug.indexOf('mail') >= 0 || slug.indexOf('message') >= 0 || description.indexOf('mail') >= 0)) {
    score += 90;
  }
  if ((toolkit === 'discord' || toolkit === 'whatsapp' || toolkit === 'instagram') &&
    (slug.indexOf('message') >= 0 || slug.indexOf('comment') >= 0 || description.indexOf('message') >= 0)) {
    score += 80;
  }
  if (toolkit === 'spotify' && (slug.indexOf('track') >= 0 || slug.indexOf('playlist') >= 0 || slug.indexOf('album') >= 0)) {
    score += 70;
  }
  if (toolkit === 'tiktok' && slug.indexOf('video') >= 0) {
    score += 70;
  }
  if (toolkit === 'ticketmaster' && (slug.indexOf('event') >= 0 || description.indexOf('event') >= 0)) {
    score += 80;
  }
  if (toolkit === 'hackernews') {
    if (slug === 'hackernews_search_posts') {
      score += 220;
    }
    if (slug.indexOf('search') >= 0 && (slug.indexOf('post') >= 0 || description.indexOf('post') >= 0)) {
      score += 80;
    }
  }
  if (toolkit === 'reddit') {
    if (slug === 'reddit_search_across_subreddits') {
      score += 260;
    }
    if (slug === 'reddit_search_posts') {
      score += 240;
    }
    if (slug.indexOf('post') >= 0 || description.indexOf('post') >= 0) {
      score += 120;
    }
    if (slug === 'reddit_get_r_top' || slug === 'reddit_retrieve_reddit_post') {
      score -= 260;
    }
    if (slug.indexOf('subreddit') >= 0 && slug !== 'reddit_search_across_subreddits' && slug.indexOf('post') < 0) {
      score -= 180;
    }
  }
  if (containsAny(prompt, ['github']) && containsAny(prompt, ['pr', 'pull request', 'pull requests'])) {
    if (slug === 'github_find_pull_requests') {
      score += 200;
    }
    if (slug.indexOf('pull_request') >= 0) {
      score += 80;
    }
  }
  if (containsAny(prompt, ['google drive'])) {
    if (slug === 'googledrive_find_file') {
      score += 200;
    }
  }
  if (containsAny(prompt, ['google docs', 'google doc'])) {
    if (slug === 'googledocs_search_documents') {
      score += 200;
    }
  }
  if (containsAny(prompt, ['slack']) && containsAny(prompt, ['消息', 'message', 'mention', '提到'])) {
    if (slug === 'slack_search_messages') {
      score += 220;
    }
    if (slug.indexOf('message') >= 0 || slug.indexOf('history') >= 0) {
      score += 80;
    }
    if (slug.indexOf('team') >= 0 || slug.indexOf('channel') >= 0 || slug.indexOf('auth') >= 0) {
      score -= 80;
    }
  }
  return score;
}

function bestToolForPrompt(payload: ComposioSearchObservation, prompt: string, fixedToolId: string = ''): ComposioSearchTool | null {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return null;
  }
  const exactSlug = composioExactToolSlugForFixedTool(fixedToolId).toLowerCase();
  if (exactSlug.length > 0) {
    for (let index = 0; index < payload.tools.length; index++) {
      const exactTool = payload.tools[index] as ComposioSearchTool;
      if (textOf(exactTool.toolSlug).trim().toLowerCase() === exactSlug) {
        return exactTool;
      }
    }
    return null;
  }
  let best: ComposioSearchTool | null = null;
  let bestScore = -10000;
  payload.tools.forEach((item: Object) => {
    const tool = item as ComposioSearchTool;
    const score = composioPreferredToolScore(prompt, tool, fixedToolId);
    if (score > bestScore) {
      bestScore = score;
      best = tool;
    }
  });
  return bestScore > 0 ? best : null;
}

function firstToolSlug(payload: ComposioSearchObservation): string {
  if (!Array.isArray(payload.tools) || payload.tools.length === 0) {
    return '';
  }
  return textOf((payload.tools[0] as ComposioSearchTool).toolSlug);
}

function parsedInputSchema(raw: string): ComposioInputSchema {
  try {
    return JSON.parse(raw.length > 0 ? raw : '{}') as ComposioInputSchema;
  } catch (_error) {
    return {};
  }
}

function propertyNames(schema: ComposioInputSchema): string[] {
  const properties = schema.properties ?? {};
  return Object.keys(properties);
}

function hasProperty(schema: ComposioInputSchema, name: string): boolean {
  const properties = schema.properties ?? {};
  return properties[name] !== undefined;
}

function schemaHasProperties(schema: ComposioInputSchema): boolean {
  const properties = schema.properties ?? {};
  return Object.keys(properties).length > 0;
}

function setIfSupported(
  target: Record<string, Object | string | number | boolean>,
  schema: ComposioInputSchema,
  name: string,
  value: Object | string | number | boolean
): void {
  if (!schemaHasProperties(schema) || hasProperty(schema, name)) {
    target[name] = value;
  }
}

function isPaginationTokenName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower.indexOf('token') >= 0 || lower.indexOf('cursor') >= 0;
}

function isOpaqueIdentifierName(name: string): boolean {
  const lower = name.toLowerCase();
  return lower === 'id' || lower.endsWith('_id') || lower.endsWith('id');
}

function driveQueryFor(keyword: string): string {
  const escaped = keyword.replace(/'/g, "\\'");
  return "name contains '" + escaped + "' and trashed = false";
}

function specialArgumentsForTool(
  toolSlug: string,
  prompt: string,
  schema: ComposioInputSchema,
  dynamicArgs: Object | null
): Record<string, Object | string | number | boolean> {
  const lower = toolSlug.toLowerCase();
  const keyword = promptSearchKeyword(prompt);
  const args: Record<string, Object | string | number | boolean> = {};
  if (isGitHubUserScopedReadTool(lower)) {
    const structured = structuredDynamicQuery(dynamicArgs);
    const username = structured.length > 0 ? structured : explicitGitHubUsernameFromPrompt(prompt);
    if (username.length > 0) {
      setIfSupported(args, schema, 'username', username);
    }
    if (hasProperty(schema, 'page')) {
      args['page'] = 1;
    }
    if (hasProperty(schema, 'per_page')) {
      args['per_page'] = 10;
    }
    return args;
  }
  if (lower === 'github_find_pull_requests') {
    setIfSupported(args, schema, 'owner', ownerNameFromPrompt(prompt));
    setIfSupported(args, schema, 'repo', repoNameFromPrompt(prompt));
    setIfSupported(args, schema, 'state', 'all');
    setIfSupported(args, schema, 'sort', 'updated');
    setIfSupported(args, schema, 'order', 'desc');
    setIfSupported(args, schema, 'page', 1);
    setIfSupported(args, schema, 'per_page', 5);
    setIfSupported(args, schema, 'limit', 5);
    return args;
  }
  if (lower === 'googledrive_find_file') {
    setIfSupported(args, schema, 'q', driveQueryFor(keyword));
    setIfSupported(args, schema, 'pageSize', 5);
    setIfSupported(args, schema, 'page_size', 5);
    setIfSupported(args, schema, 'fields', 'files(id,name,mimeType,webViewLink,modifiedTime),nextPageToken');
    return args;
  }
  if (lower === 'googledocs_search_documents') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'order_by', 'modifiedTime desc');
    setIfSupported(args, schema, 'max_results', 5);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'page_size', 5);
    return args;
  }
  if (lower === 'gmail_fetch_emails') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'max_results', 5);
    setIfSupported(args, schema, 'include_payload', false);
    setIfSupported(args, schema, 'verbose', true);
    return args;
  }
  if (lower === 'gmail_fetch_message_by_message_id') {
    setIfSupported(args, schema, 'user_id', 'me');
    setIfSupported(args, schema, 'format', 'full');
    return args;
  }
  if (lower === 'slack_search_messages') {
    setIfSupported(args, schema, 'query', slackSearchQueryForPrompt(prompt));
    setIfSupported(args, schema, 'sort', 'timestamp');
    setIfSupported(args, schema, 'count', 5);
    return args;
  }
  if (lower === 'hackernews_search_posts') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'size', 5);
    setIfSupported(args, schema, 'page', 0);
    return args;
  }
  if (lower === 'reddit_search_across_subreddits') {
    setIfSupported(args, schema, 'search_query', keyword);
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'count', 5);
    return args;
  }
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit === 'outlook' || toolkit === 'discord' || toolkit === 'linkedin' || toolkit === 'whatsapp' ||
    toolkit === 'instagram' || toolkit === 'spotify' || toolkit === 'tiktok' || toolkit === 'ticketmaster' ||
    toolkit === 'reddit') {
    setIfSupported(args, schema, 'query', keyword);
    setIfSupported(args, schema, 'q', keyword);
    setIfSupported(args, schema, 'search', keyword);
    setIfSupported(args, schema, 'keyword', keyword);
    setIfSupported(args, schema, 'limit', 5);
    setIfSupported(args, schema, 'count', 5);
    setIfSupported(args, schema, 'page_size', 5);
    setIfSupported(args, schema, 'pageSize', 5);
    return args;
  }
  return args;
}

function fallbackValueForProperty(name: string, property: ComposioInputSchemaProperty, prompt: string): Object | string | number | boolean {
  const lower = name.toLowerCase();
  const keyword = promptSearchKeyword(prompt);
  if (property.default !== undefined && property.default !== null) {
    return property.default;
  }
  if (property.enum !== undefined && property.enum.length > 0) {
    if (property.enum.indexOf('desc') >= 0 && lower.indexOf('order') >= 0) {
      return 'desc';
    }
    if (property.enum.indexOf('updated') >= 0 && lower.indexOf('sort') >= 0) {
      return 'updated';
    }
    if (property.enum.indexOf('timestamp') >= 0 && lower.indexOf('sort') >= 0) {
      return 'timestamp';
    }
    return property.enum[0];
  }
  if (lower === 'query' || lower === 'q' || lower.indexOf('search') >= 0 || lower.indexOf('keyword') >= 0) {
    return keyword;
  }
  if (lower.indexOf('repo') >= 0) {
    return repoNameFromPrompt(prompt);
  }
  if (lower.indexOf('owner') >= 0) {
    return ownerNameFromPrompt(prompt);
  }
  if (lower.indexOf('limit') >= 0 || lower.indexOf('count') >= 0 || lower.indexOf('page_size') >= 0 || lower.indexOf('pagesize') >= 0) {
    return 5;
  }
  if (lower === 'page') {
    return 1;
  }
  if (property.type === 'integer' || property.type === 'number') {
    return 5;
  }
  if (property.type === 'boolean') {
    return false;
  }
  if (property.type === 'array') {
    return [];
  }
  return keyword.length > 0 ? keyword : prompt;
}

export function composioArgumentsForTool(
  tool: ComposioSearchTool,
  prompt: string,
  fixedToolId: string = '',
  fixedArgs: Object | null = null,
  dynamicArgs: Object | null = null
): Object {
  const schema = parsedInputSchema(textOf(tool.inputSchema));
  const slug = textOf(tool.toolSlug).trim();
  const args = specialArgumentsForTool(slug, prompt, schema, dynamicArgs);
  mergeFixedArguments(args, schema, fixedToolId, fixedArgs);
  const properties = schema.properties ?? {};
  const names = propertyNames(schema);
  names.forEach((name: string) => {
    if (args[name] !== undefined) {
      return;
    }
    const lower = name.toLowerCase();
    if (isPaginationTokenName(lower)) {
      return;
    }
    if (lower === 'query' || lower === 'q' || lower.indexOf('search') >= 0 || lower.indexOf('keyword') >= 0 ||
      lower.indexOf('limit') >= 0 || lower.indexOf('count') >= 0 ||
      lower.indexOf('page_size') >= 0 || lower.indexOf('pagesize') >= 0 || lower === 'page' ||
      lower.indexOf('sort') >= 0 || lower.indexOf('order') >= 0) {
      args[name] = fallbackValueForProperty(name, properties[name], prompt);
    }
  });
  const required = schema.required ?? [];
  required.forEach((name: string) => {
    if (args[name] === undefined && shouldPreserveMissingFixedWriteArg(fixedToolId, name)) {
      return;
    }
    if (args[name] === undefined && isOpaqueIdentifierName(name)) {
      return;
    }
    if (args[name] === undefined && isGitHubUserScopedReadTool(slug) && name.toLowerCase() === 'username') {
      return;
    }
    if (args[name] === undefined && properties[name] !== undefined) {
      args[name] = fallbackValueForProperty(name, properties[name], prompt);
    }
  });
  return args;
}

function appendRow(rows: A2uiLabelValueData[], label: string, value: string): void {
  const clean = value.trim();
  if (label.trim().length === 0 || clean.length === 0) {
    return;
  }
  rows.push({ label: label, value: clean.substring(0, 360) });
}

function stringField(record: Record<string, Object | string | number | boolean | null | undefined>, names: string[]): string {
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    const text = textOf(value).trim();
    if (text.length > 0) {
      return text;
    }
  }
  return '';
}

function nestedStringField(record: Record<string, Object | string | number | boolean | null | undefined>, names: string[]): string {
  const direct = stringField(record, names);
  if (direct.length > 0 && direct.charAt(0) !== '{') {
    return direct;
  }
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)) {
      const nested = value as Record<string, Object | string | number | boolean | null | undefined>;
      const text = stringField(nested, ['login', 'name', 'display_name', 'real_name', 'username', 'id']);
      if (text.length > 0) {
        return text;
      }
    }
  }
  return '';
}

function itemTitle(item: Object, index: number): string {
  const wrapper = item as Record<string, Object | string | number | boolean | null | undefined>;
  const record = objectRecord(wrapper.data) || wrapper;
  const title = stringField(record, ['title', 'name', 'subject', 'filename', 'file_name', 'display_name', 'event_name']);
  if (title.length > 0) {
    return title;
  }
  const text = stringField(record, ['text', 'message', 'body', 'snippet', 'content', 'description']);
  if (text.length > 0) {
    return text.substring(0, 80);
  }
  const url = stringField(record, ['url', 'html_url', 'web_url', 'webViewLink', 'permalink']);
  if (url.length > 0) {
    return url;
  }
  return '结果 ' + (index + 1).toString();
}

function itemDetail(item: Object): string {
  const wrapper = item as Record<string, Object | string | number | boolean | null | undefined>;
  const record = objectRecord(wrapper.data) || wrapper;
  const parts: string[] = [];
  const number = stringField(record, ['number', 'id']);
  if (number.length > 0) {
    parts.push('#' + number);
  }
  const state = stringField(record, ['state', 'status', 'mimeType']);
  if (state.length > 0) {
    parts.push(state);
  }
  const author = nestedStringField(record, ['author', 'user', 'from', 'owner', 'sender', 'creator', 'artist']);
  if (author.length > 0) {
    parts.push(author);
  }
  const time = stringField(record, ['updated_at', 'updatedAt', 'modifiedTime', 'created_at', 'createdTime', 'timestamp', 'ts', 'date', 'start_time', 'startDateTime', 'receivedDateTime']);
  if (time.length > 0) {
    parts.push(time);
  }
  const channel = nestedStringField(record, ['channel', 'guild', 'server', 'conversation', 'chat', 'venue', 'location']);
  if (channel.length > 0) {
    parts.push(channel);
  }
  const url = stringField(record, ['html_url', 'url', 'web_url', 'webViewLink', 'webLink', 'permalink']);
  if (url.length > 0) {
    parts.push(url);
  }
  const image = stringField(record, ['thumbnail_pic', 'bmiddle_pic', 'original_pic', 'image', 'image_url', 'imageUrl', 'cover', 'thumbnail', 'pic', 'pics', 'images']);
  if (image.length > 0) {
    parts.push(image);
  }
  const snippet = stringField(record, ['snippet', 'text', 'message', 'body', 'content', 'description']);
  if (snippet.length > 0 && parts.join(' ').indexOf(snippet.substring(0, 40)) < 0) {
    parts.push(snippet.substring(0, 180));
  }
  return parts.join(' | ');
}

function objectItems(value: Object | string | number | boolean | null | undefined): Object[] {
  const items: Object[] = [];
  if (!Array.isArray(value)) {
    return items;
  }
  value.forEach((item: Object | string | number | boolean | null | undefined) => {
    if (item !== undefined && item !== null && typeof item === 'object') {
      items.push(item as Object);
    }
  });
  return items;
}

function arrayHit(label: string, value: Object | string | number | boolean | null | undefined): ComposioArrayHit {
  if (Array.isArray(value)) {
    const items = objectItems(value);
    return items.length > 0 ? { found: true, label: label, items: items } : { found: false, label: '', items: [] };
  }
  return { found: false, label: '', items: [] };
}

function firstArrayHit(value: Object | string | number | boolean | null | undefined): ComposioArrayHit {
  if (Array.isArray(value)) {
    return arrayHit('items', value);
  }
  if (value === undefined || value === null || typeof value !== 'object') {
    return { found: false, label: '', items: [] };
  }
  const record = value as Record<string, Object | string | number | boolean | null | undefined>;
  const preferred = ['pull_requests', 'files', 'matches', 'items', 'results', 'documents', 'messages', 'emails', 'mails',
    'posts', 'comments', 'answers', 'articles', 'questions', 'statuses', 'feeds', 'tracks', 'playlists', 'videos', 'events'];
  for (let index = 0; index < preferred.length; index++) {
    const hit = arrayHit(preferred[index], record[preferred[index]]);
    if (hit.found) {
      return hit;
    }
  }
  const nested = ['data', 'messages', 'result', 'response'];
  for (let index = 0; index < nested.length; index++) {
    const hit = firstArrayHit(record[nested[index]]);
    if (hit.found) {
      return hit;
    }
  }
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length; index++) {
    const hit = firstArrayHit(record[keys[index]]);
    if (hit.found) {
      return hit;
    }
  }
  return { found: false, label: '', items: [] };
}

function digitsOnly(value: string): boolean {
  if (value.length === 0) {
    return false;
  }
  for (let index = 0; index < value.length; index++) {
    const char = value.charAt(index);
    if (char < '0' || char > '9') {
      return false;
    }
  }
  return true;
}

export function composioPhoneNumberIdsFromObservation(observation: string): string[] {
  try {
    const hit = firstArrayHit(JSON.parse(observation) as Object);
    const ids: string[] = [];
    hit.items.forEach((item: Object) => {
      const record = item as Record<string, Object | string | number | boolean | null | undefined>;
      const id = textOf(record.id).trim();
      if (digitsOnly(id) && ids.indexOf(id) < 0) {
        ids.push(id);
      }
    });
    return ids;
  } catch (_error) {
    return [];
  }
}

function topLevelMessage(payload: Record<string, Object | string | number | boolean | null | undefined>): string {
  const data = payload.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    const dataRecord = data as Record<string, Object | string | number | boolean | null | undefined>;
    return stringField(dataRecord, ['composio_execution_message', 'message', 'summary']);
  }
  return stringField(payload, ['message', 'summary', 'error']);
}

function objectRecord(value: Object | string | number | boolean | null | undefined): Record<string, Object | string | number | boolean | null | undefined> | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, Object | string | number | boolean | null | undefined>;
  }
  if (typeof value === 'string' && value.trim().charAt(0) === '{') {
    try {
      const parsed = JSON.parse(value) as Object;
      if (typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, Object | string | number | boolean | null | undefined>;
      }
    } catch (_error) {
    }
  }
  return null;
}

function valueLooksLikeGmailDraft(value: Object | string | number | boolean | null | undefined): boolean {
  const record = objectRecord(value);
  if (record === null) {
    return false;
  }
  const id = stringField(record, ['id', 'draftId', 'draft_id']);
  const threadId = stringField(record, ['threadId', 'thread_id']);
  const url = stringField(record, ['display_url', 'url', 'web_url']);
  return id.length > 0 && (threadId.length > 0 || url.indexOf('mail.google.com') >= 0);
}

function successfulGmailDraftPayload(payload: Object, toolSlug: string): boolean {
  const lower = toolSlug.toLowerCase();
  if (lower.indexOf('gmail') < 0 || lower.indexOf('draft') < 0) {
    return false;
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  return valueLooksLikeGmailDraft(record.data) || valueLooksLikeGmailDraft(record.error) || valueLooksLikeGmailDraft(record);
}

function successfulCalendarWritePayload(payload: Object, toolSlug: string): boolean {
  const lower = toolSlug.toLowerCase();
  const deleting = lower === 'googlecalendar_delete_event';
  if (lower !== 'googlecalendar_create_event' && lower !== 'googlecalendar_patch_event' && !deleting) {
    return false;
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  const data = objectRecord(record.data);
  const response = data === null ? null : objectRecord(data.response_data);
  if (response === null ||
    response.success === false || response.success === 'false' ||
    response.successful === false || response.successful === 'false') {
    return false;
  }
  const status = stringField(response, ['status']).toLowerCase();
  if (status.indexOf('fail') >= 0 || status.indexOf('error') >= 0 ||
    status.indexOf('reject') >= 0 || status.indexOf('denied') >= 0 ||
    status.indexOf('invalid') >= 0) {
    return false;
  }
  if (deleting) {
    return response.success === true || response.success === 'true' ||
      response.successful === true || response.successful === 'true' ||
      status === 'success' || status === 'succeeded' || status === 'completed' ||
      status === 'ok' || status === 'deleted';
  }
  return stringField(response, ['id']).length > 0;
}

function executionStatusValue(
  record: Record<string, Object | string | number | boolean | null | undefined>,
  expected: boolean
): boolean {
  if (record.successful === expected || record.success === expected) {
    return true;
  }
  const data = record.data;
  if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return false;
  }
  const dataRecord = data as Record<string, Object | string | number | boolean | null | undefined>;
  return dataRecord.successful === expected || dataRecord.success === expected;
}

function nestedExecutionError(
  record: Record<string, Object | string | number | boolean | null | undefined>
): string {
  const data = record.data;
  if (data === undefined || data === null || typeof data !== 'object' || Array.isArray(data)) {
    return '';
  }
  return stringField(
    data as Record<string, Object | string | number | boolean | null | undefined>,
    ['error']
  );
}

function executionErrorMessage(payload: Object, toolSlug: string = ''): string {
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  if (executionStatusValue(record, false)) {
    const explicitError = stringField(record, ['error']);
    const nestedError = nestedExecutionError(record);
    return explicitError.length > 0 ? explicitError :
      (nestedError.length > 0 ? nestedError : 'Provider returned an unsuccessful execution status.');
  }
  if (successfulGmailDraftPayload(payload, toolSlug)) {
    return '';
  }
  const direct = stringField(record, ['error']);
  if (direct.length > 0) {
    return direct;
  }
  const nestedError = nestedExecutionError(record);
  if (nestedError.length > 0) {
    return nestedError;
  }
  if (executionStatusValue(record, true)) {
    return '';
  }
  if (successfulCalendarWritePayload(payload, toolSlug)) {
    return '';
  }
  if (isUnsafeComposioExecute(toolSlug, '{}')) {
    return 'Provider did not return positive execution evidence.';
  }
  const data = record.data;
  if (data !== undefined && data !== null && typeof data === 'object' && !Array.isArray(data)) {
    return stringField(data as Record<string, Object | string | number | boolean | null | undefined>, ['message']);
  }
  return '';
}

function compactNestedText(record: Record<string, Object | string | number | boolean | null | undefined>, fieldName: string): string {
  const value = record[fieldName];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    const nested = value as Record<string, Object | string | number | boolean | null | undefined>;
    return stringField(nested, ['body', 'text', 'snippet', 'summary', 'title', 'url']);
  }
  return textOf(value);
}

function compactComposioItem(item: Object): Object {
  const record = item as Record<string, Object | string | number | boolean | null | undefined>;
  const compact: Record<string, Object | string | number | boolean> = {};
  const fields = [
    'id', 'threadId', 'thread_id', 'messageId', 'message_id', 'display_url',
    'sender', 'from', 'to', 'subject', 'title', 'name', 'snippet',
    'messageTimestamp', 'date', 'timestamp', 'publishedAt', 'url'
  ];
  fields.forEach((name: string) => {
    const value = record[name];
    if (value !== undefined && value !== null && typeof value !== 'object') {
      compact[name] = textOf(value).substring(0, 1000);
    }
  });
  const preview = compactNestedText(record, 'preview');
  if (preview.length > 0) {
    compact.preview = preview.substring(0, 1000);
  }
  const directMessageText = stringField(record, ['messageText', 'text', 'description']);
  const messageText = directMessageText.length > 0 ? directMessageText : compactNestedText(record, 'data');
  if (messageText.length > 0) {
    compact.messageText = messageText.substring(0, 1000);
  }
  const snippet = record.snippet;
  if (snippet !== undefined && snippet !== null && typeof snippet === 'object' && !Array.isArray(snippet)) {
    const snippetRecord = snippet as Record<string, Object | string | number | boolean | null | undefined>;
    const title = nestedStringField(snippetRecord, ['localized', 'title']);
    if (title.length > 0) {
      compact.title = title;
    } else {
      appendCompactString(compact, 'title', stringField(snippetRecord, ['title']));
    }
    appendCompactString(compact, 'channelTitle', stringField(snippetRecord, ['channelTitle']));
    appendCompactString(compact, 'publishedAt', stringField(snippetRecord, ['publishedAt']));
    const thumbnail = youtubeThumbnailUrl(snippetRecord);
    if (thumbnail.length > 0) {
      compact.thumbnail = thumbnail;
    }
  }
  return compact;
}

function appendCompactString(target: Record<string, Object | string | number | boolean>, key: string, value: string): void {
  const clean = value.trim();
  if (clean.length > 0 && target[key] === undefined) {
    target[key] = clean.substring(0, 1000);
  }
}

function youtubeThumbnailUrl(record: Record<string, Object | string | number | boolean | null | undefined>): string {
  const thumbnails = record.thumbnails;
  if (thumbnails === undefined || thumbnails === null || typeof thumbnails !== 'object' || Array.isArray(thumbnails)) {
    return '';
  }
  const sizes = thumbnails as Record<string, Object | string | number | boolean | null | undefined>;
  const keys = ['maxres', 'standard', 'high', 'medium', 'default'];
  for (let index = 0; index < keys.length; index++) {
    const item = sizes[keys[index]];
    if (item !== undefined && item !== null && typeof item === 'object' && !Array.isArray(item)) {
      const url = stringField(item as Record<string, Object | string | number | boolean | null | undefined>, ['url']);
      if (url.length > 0) {
        return url;
      }
    }
  }
  return '';
}

function gmailDraftIdFromRecord(
  record: Record<string, Object | string | number | boolean | null | undefined>
): string {
  const message = objectRecord(record.message);
  if (!valueLooksLikeGmailDraft(record) &&
    (message === null || !valueLooksLikeGmailDraft(message))) {
    return '';
  }
  const value = record.draft_id === undefined ?
    (record.draftId === undefined ? record.id : record.draftId) : record.draft_id;
  if (typeof value !== 'string') {
    return '';
  }
  const draftId = value.trim();
  return draftId.length > 0 && draftId.length <= 512 ? draftId : '';
}

function gmailDraftIdForExecute(payload: Object, toolSlug: string): string {
  const normalized = toolSlug.trim().toLowerCase();
  if (normalized.indexOf('gmail') < 0 || !isSafeGmailDraftCreateSlug(normalized)) {
    return '';
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  const data = objectRecord(record.data);
  if (data === null) {
    return '';
  }
  const directId = gmailDraftIdFromRecord(data);
  if (directId.length > 0) {
    return directId;
  }
  const response = objectRecord(data.response_data);
  if (response === null) {
    return '';
  }
  const providerData = objectRecord(response.data);
  const nestedId = providerData === null ? '' : gmailDraftIdFromRecord(providerData);
  return nestedId.length > 0 ? nestedId : gmailDraftIdFromRecord(response);
}

function rawPreviewForExecute(payload: Object, observation: string, gmailDraftId: string): string {
  if (gmailDraftId.length > 0) {
    const identity: Record<string, string> = {};
    identity['draft_id'] = gmailDraftId;
    return JSON.stringify(identity);
  }
  const hit = firstArrayHit(payload);
  if (!hit.found) {
    return observation.substring(0, 16000);
  }
  const items: Object[] = [];
  for (let index = 0; index < hit.items.length && index < 10; index++) {
    items.push(compactComposioItem(hit.items[index]));
  }
  const compact: Record<string, Object[]> = {};
  compact[hit.label] = items;
  return JSON.stringify(compact).substring(0, 16000);
}

function rowsForExecute(
  payload: Object,
  prompt: string,
  toolSlug: string,
  gmailDraftId: string
): A2uiLabelValueData[] {
  const rows: A2uiLabelValueData[] = [];
  appendRow(rows, '执行工具', toolSlug);
  appendRow(rows, '查询', promptSearchKeyword(prompt));
  appendRow(rows, 'Draft ID', gmailDraftId);
  if (gmailDraftId.length > 0) {
    return rows;
  }
  const hit = firstArrayHit(payload);
  if (hit.found) {
    appendRow(rows, '结果数量', hit.items.length.toString());
    for (let index = 0; index < hit.items.length && index < 5; index++) {
      appendRow(rows, itemTitle(hit.items[index], index), itemDetail(hit.items[index]));
    }
    return rows;
  }
  const record = payload as Record<string, Object | string | number | boolean | null | undefined>;
  appendRow(rows, '结果摘要', topLevelMessage(record));
  const keys = Object.keys(record);
  for (let index = 0; index < keys.length && rows.length < 8; index++) {
    const value = record[keys[index]];
    if (value === undefined || value === null || typeof value === 'object') {
      continue;
    }
    appendRow(rows, keys[index], textOf(value));
  }
  if (rows.length <= 2) {
    appendRow(rows, '结果数量', '0');
  }
  return rows;
}

function resultTitleForTool(toolSlug: string): string {
  const lower = toolSlug.toLowerCase();
  if (lower.indexOf('gmail') >= 0) {
    return 'Composio Gmail 结果';
  }
  if (lower.indexOf('googlecalendar') >= 0) {
    return 'Composio Google Calendar 结果';
  }
  if (lower.indexOf('youtube') >= 0) {
    return 'Composio YouTube 结果';
  }
  if (lower.indexOf('twitter') >= 0) {
    return 'Composio Twitter 结果';
  }
  if (lower.indexOf('github') >= 0) {
    return 'Composio GitHub 结果';
  }
  if (lower.indexOf('googledrive') >= 0) {
    return 'Composio Google Drive 结果';
  }
  if (lower.indexOf('googledocs') >= 0) {
    return 'Composio Google Docs 结果';
  }
  if (lower.indexOf('slack') >= 0) {
    return 'Composio Slack 结果';
  }
  if (lower.indexOf('outlook') >= 0) {
    return 'Composio Outlook 结果';
  }
  if (lower.indexOf('discord') >= 0) {
    return 'Composio Discord 结果';
  }
  if (lower.indexOf('linkedin') >= 0) {
    return 'Composio LinkedIn 结果';
  }
  if (lower.indexOf('whatsapp') >= 0) {
    return 'Composio WhatsApp 结果';
  }
  if (lower.indexOf('instagram') >= 0) {
    return 'Composio Instagram 结果';
  }
  if (lower.indexOf('spotify') >= 0) {
    return 'Composio Spotify 结果';
  }
  if (lower.indexOf('tiktok') >= 0) {
    return 'Composio TikTok 结果';
  }
  if (lower.indexOf('ticketmaster') >= 0) {
    return 'Composio Ticketmaster 结果';
  }
  if (lower.indexOf('hackernews') >= 0 || lower.indexOf('hacker_news') >= 0) {
    return 'Composio Hacker News 结果';
  }
  if (lower.indexOf('reddit') >= 0) {
    return 'Composio Reddit 结果';
  }
  return 'Composio 工具结果';
}

function resultTitleForPrompt(prompt: string): string {
  const toolkit = composioToolkitFromPrompt(prompt);
  return toolkit.length > 0 ? resultTitleForTool(toolkit) : 'Composio 工具候选';
}

function executeSummary(toolSlug: string, rows: A2uiLabelValueData[]): string {
  let count = '';
  rows.forEach((row: A2uiLabelValueData) => {
    if (row.label === '结果数量') {
      count = row.value;
    }
  });
  return count.length > 0
    ? 'Composio 已执行 ' + toolSlug + '，返回 ' + count + ' 条可展示结果。'
    : 'Composio 已执行 ' + toolSlug + '，返回真实结果。';
}

export function configureComposioConfigFromRawJson(rawJson: string): void {
  composioConfig = ComposioConfig.fromRawJson(rawJson);
  refreshComposioConnections();
}

export function refreshComposioConnections(): void {
  composioClient = null;
  scopedComposioClients.clear();
}

export function configureComposioUserId(userId: string): void {
  runtimeComposioUserId = userId.trim();
  refreshComposioConnections();
}

export function currentComposioUserId(): string {
  return runtimeComposioUserId.length > 0 ? runtimeComposioUserId : composioConfig.userId;
}

function configForCurrentUser(): ComposioConfig {
  return new ComposioConfig(
    composioConfig.apiKey,
    composioConfig.baseUrl,
    currentComposioUserId(),
    composioConfig.proxyBaseUrl,
    composioConfig.proxyApiKey
  );
}

export function currentComposioConfig(): ComposioConfig {
  return configForCurrentUser();
}

export function isComposioConfigured(): boolean {
  return composioConfig.isConfigured();
}

export function isComposioDynamicPrompt(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  if (lower.indexOf('weibo') >= 0 || prompt.indexOf('微博') >= 0 ||
    lower.indexOf('zhihu') >= 0 || prompt.indexOf('知乎') >= 0) {
    return false;
  }
  return lower.indexOf('notion') >= 0 ||
    lower.indexOf('gmail') >= 0 ||
    lower.indexOf('google calendar') >= 0 ||
    lower.indexOf('calendar') >= 0 ||
    lower.indexOf('youtube') >= 0 ||
    lower.indexOf('twitter') >= 0 ||
    lower.indexOf(' x ') >= 0 ||
    lower.indexOf('x/twitter') >= 0 ||
    lower.indexOf('google drive') >= 0 ||
    lower.indexOf('google docs') >= 0 ||
    lower.indexOf('google doc') >= 0 ||
    lower.indexOf('linear') >= 0 ||
    lower.indexOf('github') >= 0 ||
    lower.indexOf('asana') >= 0 ||
    lower.indexOf('trello') >= 0 ||
    lower.indexOf('hubspot') >= 0 ||
    lower.indexOf('salesforce') >= 0 ||
    lower.indexOf('outlook') >= 0 ||
    lower.indexOf('discord') >= 0 ||
    lower.indexOf('linkedin') >= 0 ||
    lower.indexOf('whatsapp') >= 0 ||
    lower.indexOf('whats app') >= 0 ||
    lower.indexOf('instagram') >= 0 ||
    lower.indexOf('instgram') >= 0 ||
    lower.indexOf('spotify') >= 0 ||
    lower.indexOf('soptify') >= 0 ||
    lower.indexOf('tiktok') >= 0 ||
    lower.indexOf('tik tok') >= 0 ||
    lower.indexOf('ticketmaster') >= 0 ||
    lower.indexOf('ticket master') >= 0 ||
    lower.indexOf('hacker news') >= 0 ||
    lower.indexOf('hackernews') >= 0 ||
    lower.indexOf('reddit') >= 0 ||
    prompt.indexOf('黑客新闻') >= 0 ||
    prompt.indexOf('红迪') >= 0 ||
    prompt.indexOf('谷歌邮箱') >= 0 ||
    prompt.indexOf('谷歌邮件') >= 0 ||
    prompt.indexOf('谷歌日历') >= 0 ||
    prompt.indexOf('油管') >= 0 ||
    lower.indexOf('composio') >= 0;
}

export function shouldAttemptComposioDynamic(prompt: string, operation: string, _configured: boolean): boolean {
  if (operation === 'execute') {
    return isComposioDynamicPrompt(prompt);
  }
  return isComposioDynamicPrompt(prompt);
}

export function proxyToolkitAccountsPreview(payload: Object, toolkitAllowlist: string[] = []): Record<string, string> {
  return proxyToolkitAccountsFromAuthConfigs(payload, toolkitAllowlist);
}

export function isUnsafeComposioExecute(toolSlug: string, _argsJson: string): boolean {
  if (toolSlug.trim().toUpperCase() === 'REDDIT_RETRIEVE_POST_COMMENTS') {
    return false;
  }
  return isUnsafeMcpTool(toolSlug, '');
}

const SELECTED_READ_OPERATIONS: string[] = ['read', 'search', 'list', 'get', 'find', 'fetch'];
const SELECTED_PROVIDER_PREFIXES: string[] = [
  'googlecalendar', 'googledrive', 'googledocs', 'ticketmaster', 'hackernews', 'salesforce',
  'composio', 'instagram', 'linkedin', 'whatsapp', 'github', 'twitter', 'youtube',
  'outlook', 'discord', 'spotify', 'tiktok', 'hubspot', 'notion', 'slack', 'gmail',
  'reddit', 'linear', 'trello', 'asana', 'google', 'calendar', 'drive', 'hacker',
  'news', 'git', 'hub', 'x'
];
const SELECTED_READ_NOUNS: string[] = [
  'phonenumbers', 'pullrequests', 'subscriptions', 'conversations', 'repositories',
  'spreadsheets', 'documents', 'playlists', 'permissions', 'notifications', 'activities',
  'channels', 'messages', 'threads', 'profiles', 'statuses', 'settings', 'comments',
  'replies', 'orders', 'posts', 'tweets', 'events', 'emails', 'accounts', 'members',
  'numbers', 'repository', 'spreadsheet', 'document', 'playlist', 'permission',
  'notification', 'activity', 'channel', 'message', 'thread', 'profile', 'status',
  'event', 'email', 'account', 'member', 'phone', 'conversation', 'subscription',
  'pullrequest', 'pull', 'requests', 'videos', 'video', 'people', 'contacts', 'contact',
  'files', 'pages', 'users', 'items', 'results', 'details', 'information',
  'file', 'page', 'user', 'item', 'result', 'data', 'weather', 'forecast', 'info',
  'code', 'issues', 'issue', 'subreddits', 'subreddit', 'across', 'recent', 'all', 'mine',
  'my', 'by', 'for', 'from', 'in', 'of'
];

function stripSelectedProviderPrefixes(value: string): string {
  let remaining = value;
  let removed = true;
  while (remaining.length > 0 && removed) {
    removed = false;
    for (let index = 0; index < SELECTED_PROVIDER_PREFIXES.length; index++) {
      const prefix = SELECTED_PROVIDER_PREFIXES[index];
      if (remaining === prefix) {
        return '';
      }
      if (remaining.startsWith(prefix) && remaining.length > prefix.length) {
        remaining = remaining.substring(prefix.length);
        removed = true;
        break;
      }
    }
  }
  return remaining;
}

function selectedSemanticTokens(toolSlug: string): string[] {
  const tokens = normalizedDynamicToolTokens(toolSlug);
  while (tokens.length > 0) {
    const stripped = stripSelectedProviderPrefixes(tokens[0]);
    if (stripped.length === 0) {
      tokens.shift();
      continue;
    }
    if (stripped !== tokens[0]) {
      tokens[0] = stripped;
    }
    break;
  }
  return tokens;
}

function readNounPrefix(value: string): string {
  for (let index = 0; index < SELECTED_READ_NOUNS.length; index++) {
    if (value.startsWith(SELECTED_READ_NOUNS[index])) {
      return SELECTED_READ_NOUNS[index];
    }
  }
  return '';
}

function compactReadTailAllowed(value: string): boolean {
  let remaining = value;
  while (remaining.length > 0) {
    const noun = readNounPrefix(remaining);
    if (noun.length > 0) {
      remaining = remaining.substring(noun.length);
      continue;
    }
    if (dynamicCompoundControlPrefix(remaining).length > 0 || dynamicMutationActionPrefix(remaining).length > 0) {
      return false;
    }
    return false;
  }
  return true;
}

function compactSelectedReadOperation(value: string): string {
  for (let index = 0; index < SELECTED_READ_OPERATIONS.length; index++) {
    const operation = SELECTED_READ_OPERATIONS[index];
    if (value.length > operation.length && value.substring(0, operation.length) === operation) {
      return operation;
    }
  }
  return '';
}

function selectedSlugGrammarMessage(toolSlug: string): string {
  const semantic = selectedSemanticTokens(toolSlug);
  if (semantic.length === 0) {
    return 'Selected Composio tool has no semantic operation: ' + toolSlug + '.';
  }
  let operation = semantic[0];
  let compactTail = '';
  if (SELECTED_READ_OPERATIONS.indexOf(operation) < 0) {
    const compactOperation = compactSelectedReadOperation(operation);
    if (compactOperation.length > 0) {
      operation = compactOperation;
      compactTail = semantic[0].substring(compactOperation.length);
    }
  }
  if (SELECTED_READ_OPERATIONS.indexOf(operation) < 0) {
    return 'Selected Composio tool has an unknown operation: ' + toolSlug + '.';
  }
  if (compactTail.length > 0 && !compactReadTailAllowed(compactTail)) {
    return 'Selected Composio tool has an ambiguous compact operation: ' + toolSlug + '.';
  }
  for (let index = 1; index < semantic.length; index++) {
    const token = semantic[index];
    if (isDynamicCompoundControlToken(token)) {
      return 'Selected Composio tool is a compound operation: ' + toolSlug + '.';
    }
    if (isDynamicMutationActionToken(token)) {
      return 'Selected Composio tool is write-like: ' + toolSlug + '.';
    }
    if (SELECTED_READ_NOUNS.indexOf(token) < 0) {
      return 'Selected Composio tool has an unknown semantic token: ' + toolSlug + '.';
    }
  }
  return '';
}

function selectedSlugAuthorizationMessage(
  toolSlug: string,
  fixedToolId: string,
  allowFixedContract: boolean = false
): string {
  const lowerSlug = toolSlug.trim().toLowerCase();
  const exactFixed = composioExactToolSlugForFixedTool(fixedToolId).toLowerCase();
  if (fixedToolId === 'x.post.search' && lowerSlug === exactFixed) {
    return '';
  }
  if (allowFixedContract && ((exactFixed.length > 0 && lowerSlug === exactFixed) ||
    fixedToolAllowsSideEffectSlug(fixedToolId, lowerSlug))) {
    return '';
  }
  return selectedSlugGrammarMessage(toolSlug);
}

function blockedSelectedSlugResult(toolSlug: string, message: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio',
    toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
    title: 'UnsafeActionBlocked',
    status: 'unsafe_action_blocked',
    summary: message,
    rows: [
      { label: 'Blocked action', value: toolSlug.length > 0 ? toolSlug : 'unknown' },
      { label: 'Next step', value: '使用带确认流程的固定工具。' }
    ],
    rawPreview: JSON.stringify({ blocked: true, reason: 'unsafe_action_blocked', toolSlug: toolSlug }),
    providerPhase: 'discovery'
  };
}

function isXPostReadSlug(toolSlug: string): boolean {
  const compact = normalizedDynamicToolTokens(toolSlug).join('');
  if (compact === 'twitterrecentsearch') {
    return true;
  }
  if (selectedSlugGrammarMessage(toolSlug).length > 0) {
    return false;
  }
  return compact.indexOf('tweet') >= 0 || compact.indexOf('posts') >= 0 || compact.indexOf('status') >= 0;
}

function xDiscoveryFailure(prompt: string, observation: string): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio',
    toolName: 'x.post.search',
    title: 'Composio X post tool unavailable',
    status: 'error',
    summary: 'Composio discovery did not return an executable X post read tool.',
    rows: [{ label: '查询', value: promptSearchKeyword(prompt) }],
    rawPreview: observation.substring(0, 16000),
    providerPhase: 'discovery'
  };
}

export function composioDynamicMissingConfigResult(prompt: string, qualifiedName: string = ''): DynamicGenericToolResult {
  const title = qualifiedName.length > 0 ? 'Composio 未配置' :
    (composioToolkitFromPrompt(prompt).length > 0 ? resultTitleForPrompt(prompt) : 'Composio 未配置');
  const missing = composioConfig.missingConfiguration();
  const summary = 'Composio 未配置' + (missing.length > 0 ? '：' + missing : '') + '，无法查询已授权应用工具。';
  return {
    sourceTag: 'Composio',
    toolName: qualifiedName.length > 0 ? qualifiedName : 'dynamic.search',
    title: title,
    status: qualifiedName.length > 0 ? 'missing_config' : 'needs_auth',
    summary: summary,
    rows: [
      { label: '请求', value: prompt.substring(0, 240) },
      { label: '结果摘要', value: summary }
    ],
    rawPreview: prompt
  };
}

export function composioDynamicResultFromObservation(
  phase: string,
  observation: string,
  toolSlug: string = '',
  prompt: string = '',
  preserveProviderData: boolean = false
): DynamicGenericToolResult {
  try {
    const payload = JSON.parse(observation) as ComposioSearchObservation;
    if (phase === 'execute') {
      const errorMessage = executionErrorMessage(payload as Object, toolSlug);
      const draftId = errorMessage.length === 0 ?
        gmailDraftIdForExecute(payload as Object, toolSlug) : '';
      const rows = rowsForExecute(
        payload as Object,
        prompt,
        toolSlug.length > 0 ? toolSlug : 'dynamic.search',
        draftId
      );
      if (errorMessage.length > 0) {
        return {
          sourceTag: 'Composio',
          toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
          title: 'Composio 调用失败',
          status: 'error',
          summary: 'Composio 执行 ' + (toolSlug.length > 0 ? toolSlug : 'dynamic.search') + ' 失败：' + errorMessage,
          rows: rows,
          rawPreview: observation.substring(0, 16000),
          providerPhase: 'execution'
        };
      }
      const result: DynamicGenericToolResult = {
        sourceTag: 'Composio',
        toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
        title: resultTitleForTool(toolSlug),
        status: 'success',
        summary: executeSummary(toolSlug.length > 0 ? toolSlug : 'dynamic.search', rows),
        rows: rows,
        rawPreview: rawPreviewForExecute(payload as Object, observation, draftId),
        providerPhase: 'execution'
      };
      if (preserveProviderData) {
        const extracted = extractComposioProviderData(observation, toolSlug);
        if (extracted.data !== null) {
          result.providerData = extracted.data;
          result.providerDataMeta = extracted.meta as Object;
        }
      }
      return result;
    }
    const slug = firstToolSlug(payload);
    const rows = rowsForSearch(payload);
    if (prompt.length > 0) {
      appendRow(rows, '查询', promptSearchKeyword(prompt));
    }
    return {
      sourceTag: 'Composio',
      toolName: 'dynamic.search',
      title: phase === 'execute' ? 'Composio 执行结果' : resultTitleForPrompt(prompt),
      status: 'success',
      summary: slug.length > 0 ? 'Composio 找到候选工具：' + slug : 'Composio 返回了真实结果。',
      rows: rows,
      rawPreview: observation.substring(0, 16000),
      providerPhase: 'discovery'
    };
  } catch (_error) {
    const unparseableWrite = phase === 'execute' && isUnsafeComposioExecute(toolSlug, '{}');
    const failed = unparseableWrite || observation.indexOf('失败') >= 0 || observation.indexOf('错误') >= 0 ||
      observation.indexOf('未配置') >= 0 || observation.indexOf('没有') >= 0;
    const rows: A2uiLabelValueData[] = [{ label: '阶段', value: phase }];
    if (prompt.length > 0) {
      appendRow(rows, '查询', promptSearchKeyword(prompt));
    }
    appendRow(rows, '结果摘要', observation);
    return {
      sourceTag: 'Composio',
      toolName: toolSlug.length > 0 ? toolSlug : 'dynamic.search',
      title: prompt.length > 0 ? resultTitleForPrompt(prompt) : (failed ? 'Composio 调用失败' : 'Composio 返回'),
      status: failed ? 'error' : 'success',
      summary: unparseableWrite ? 'Composio 写工具返回了无法验证的非 JSON 结果。' : observation.substring(0, 240),
      rows: rows,
      rawPreview: observation.substring(0, 16000),
      providerPhase: phase === 'execute' ? 'execution' : 'discovery'
    };
  }
}

async function executeComposioObservation(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  toolSlug: string,
  args: Object,
  preserveProviderData: boolean
): Promise<ComposioExecutionObservation> {
  if (preserveProviderData && current instanceof ComposioSessionClient) {
    const preserved: ComposioPreservedExecution = await current.executePreservingProviderData(toolSlug, args);
    const result: ComposioExecutionObservation = { observation: preserved.observation };
    if (preserved.providerData !== null) {
      result.providerData = preserved.providerData;
      result.providerDataMeta = preserved.providerDataMeta as Object;
    }
    return result;
  }
  const observation = await current.execute(toolSlug, args);
  const result: ComposioExecutionObservation = { observation: observation };
  if (preserveProviderData) {
    const extracted = extractComposioProviderData(observation, toolSlug);
    if (extracted.data !== null) {
      result.providerData = extracted.data;
      result.providerDataMeta = extracted.meta as Object;
    }
  }
  return result;
}

async function callComposioSearchAndExecuteParsed(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  prompt: string,
  parsed: ComposioExecuteArgs,
  allowFixedContract: boolean,
  preserveProviderData: boolean = false
): Promise<DynamicGenericToolResult> {
  const fixedToolId = textOf(parsed.fixedToolId).trim();
  const selected = selectedQualifiedName(parsed);
  const searchObservation = await current.search(selected.length > 0 ? selected : normalizedComposioUseCase(prompt, fixedToolId));
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    if (fixedToolId === 'x.post.search') {
      return xDiscoveryFailure(prompt, searchObservation);
    }
    return composioDynamicResultFromObservation('search', searchObservation, '', prompt);
  }
  let tool: ComposioSearchTool | null = null;
  if (selected.length > 0 && Array.isArray(payload.tools)) {
    for (let index = 0; index < payload.tools.length; index++) {
      const candidate = payload.tools[index] as ComposioSearchTool;
      if (textOf(candidate.toolSlug).trim() === selected) {
        tool = candidate;
        break;
      }
    }
    if (tool === null) {
      return {
        sourceTag: 'Composio', toolName: selected, title: 'Composio 工具不可用', status: 'no_tool_found',
        summary: 'Composio 没有返回所选读取工具。', rows: [], rawPreview: searchObservation.substring(0, 16000),
        providerPhase: 'discovery'
      };
    }
  } else {
    tool = bestToolForPrompt(payload, prompt, fixedToolId);
  }
  const expected = composioExactToolSlugForFixedTool(fixedToolId);
  if (tool === null && expected.length > 0) {
    return {
      sourceTag: 'Composio',
      toolName: fixedToolId,
      title: 'Composio 工具不可用',
      status: 'error',
      summary: 'Composio 没有返回必需工具 ' + expected + '。',
      rows: [{ label: 'Expected Tool', value: expected }],
      rawPreview: searchObservation.substring(0, 16000),
      providerPhase: 'discovery'
    };
  }
  if (tool === null && Array.isArray(payload.tools) && payload.tools.length === 1) {
    tool = payload.tools[0] as ComposioSearchTool;
  }
  if (tool === null) {
    if (fixedToolId === 'x.post.search') {
      return xDiscoveryFailure(prompt, searchObservation);
    }
    return composioDynamicResultFromObservation('search', searchObservation, '', prompt);
  }
  const slug = textOf(tool.toolSlug).trim();
  if (fixedToolId === 'x.post.search' && !isXPostReadSlug(slug)) {
    return xDiscoveryFailure(prompt, searchObservation);
  }
  const args = composioArgumentsForTool(tool, prompt, fixedToolId, parsed.fixedArgs ?? null, parsed as Object);
  const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
  if (authorizationMessage.length > 0) {
    return blockedSelectedSlugResult(slug, authorizationMessage);
  }
  const execution = await executeComposioObservation(current, slug, args, preserveProviderData);
  const executionObservation = execution.observation;
  const result = composioDynamicResultFromObservation('execute', executionObservation, slug, prompt);
  if (execution.providerData !== undefined) {
    result.providerData = execution.providerData;
    result.providerDataMeta = execution.providerDataMeta;
  }
  result.registration = {
    provider: 'Composio',
    qualifiedName: slug,
    inputSchema: composioToolSchema(tool.inputSchema),
    outputSchema: preserveProviderData && slug.trim().toUpperCase() === 'GITHUB_LIST_EVENTS_FOR_USER' ?
      githubUserEventsNormalizedOutputSchema() : composioToolSchema(tool.outputSchema),
    receipt: dynamicReceiptFromProviderPayload(executionObservation)
  };
  return result;
}

function githubOperationSpec(operationTarget: string): GitHubOperationSpec | null {
  if (operationTarget === GITHUB_PROFILE_TARGET) {
    return {
      operationTarget: GITHUB_PROFILE_TARGET,
      section: 'profile',
      toolSlug: GITHUB_PROFILE_TOOL,
      useCase: 'Get the public profile for the exact GitHub username.'
    };
  }
  if (operationTarget === GITHUB_REPOSITORIES_TARGET) {
    return {
      operationTarget: GITHUB_REPOSITORIES_TARGET,
      section: 'repositories',
      toolSlug: GITHUB_REPOSITORIES_TOOL,
      useCase: 'List public repositories for the exact GitHub username.'
    };
  }
  if (operationTarget === GITHUB_EVENTS_TARGET) {
    return {
      operationTarget: GITHUB_EVENTS_TARGET,
      section: 'events',
      toolSlug: GITHUB_EVENTS_TOOL,
      useCase: 'List recent public events for the exact GitHub username.'
    };
  }
  return null;
}

export function isGitHubUserOperationTarget(operationTarget: string): boolean {
  return operationTarget === GITHUB_PROFILE_TARGET || operationTarget === GITHUB_REPOSITORIES_TARGET ||
    operationTarget === GITHUB_EVENTS_TARGET || operationTarget === GITHUB_DASHBOARD_TARGET;
}

function githubOperationInputSchema(): Object {
  return JSON.parse('{"type":"object","required":["query","operationTarget"],"properties":{' +
    '"query":{"type":"string","description":"Exact GitHub username."},' +
    '"operationTarget":{"type":"string","enum":["github.profile","github.repositories",' +
    '"github.events","github.user.dashboard"]}}}') as Object;
}

function githubProfileOutputSchema(): Object {
  return JSON.parse('{"type":"object","required":["schemaVersion","username","profile","provenance"],' +
    '"properties":{"schemaVersion":{"type":"string"},"username":{"type":"string"},' +
    '"profile":{"type":"object","required":["login"],"properties":{' +
    '"login":{"type":"string"},"name":{"type":"string"},"bio":{"type":"string"},' +
    '"avatarUrl":{"type":"string"},"url":{"type":"string"},"followers":{"type":"number"},' +
    '"following":{"type":"number"},"publicRepositories":{"type":"number"}}},' +
    '"provenance":{"type":"object"}}}') as Object;
}

function githubRepositoriesOutputSchema(): Object {
  return JSON.parse('{"type":"object","required":["schemaVersion","username","repositories",' +
    '"metrics","languages","provenance"],"properties":{"schemaVersion":{"type":"string"},' +
    '"username":{"type":"string"},"repositories":{"type":"array","items":{"type":"object",' +
    '"required":["name","url","stars","forks"],"properties":{"name":{"type":"string"},' +
    '"fullName":{"type":"string"},"url":{"type":"string"},"description":{"type":"string"},' +
    '"language":{"type":"string"},"stars":{"type":"number"},"forks":{"type":"number"},' +
    '"updatedAt":{"type":"string"},"pushedAt":{"type":"string"}}}},' +
    '"metrics":{"type":"object"},"languages":{"type":"array","items":{"type":"object",' +
    '"required":["language","repositoryCount","ratio"],"properties":{' +
    '"language":{"type":"string"},"repositoryCount":{"type":"number"},"ratio":{"type":"number"}}}},' +
    '"provenance":{"type":"object"}}}') as Object;
}

function githubEventsOutputSchema(): Object {
  return JSON.parse('{"type":"object","required":["schemaVersion","username","recentActivity",' +
    '"activityCount","activityMetadata","provenance"],"properties":{' +
    '"schemaVersion":{"type":"string"},"username":{"type":"string"},' +
    '"recentActivity":{"type":"array"},"activityCount":{"type":"number"},' +
    '"activityMetadata":{"type":"object"},"provenance":{"type":"object"}}}') as Object;
}

export function githubUserDashboardOutputSchema(): Object {
  return JSON.parse('{"type":"object","required":["schemaVersion","username","partial","sections",' +
    '"limitations"],"properties":{"schemaVersion":{"type":"string"},"username":{"type":"string"},' +
    '"partial":{"type":"boolean"},"profile":{"type":"object"},"repositories":{"type":"array"},' +
    '"repositoryMetrics":{"type":"object"},"languages":{"type":"array","items":{"type":"object",' +
    '"required":["language","repositoryCount","ratio"],"properties":{' +
    '"language":{"type":"string"},"repositoryCount":{"type":"number"},"ratio":{"type":"number"}}}},' +
    '"recentActivity":{"type":"array","items":{"type":"object",' +
    '"required":["time","summary"],"properties":{' +
    '"time":{"type":"string"},"summary":{"type":"string"}}}},' +
    '"sections":{"type":"array"},"limitations":{"type":"array","items":{"type":"string"}}}}') as Object;
}

function githubOutputSchemaForTarget(operationTarget: string): Object {
  if (operationTarget === GITHUB_PROFILE_TARGET) return githubProfileOutputSchema();
  if (operationTarget === GITHUB_REPOSITORIES_TARGET) return githubRepositoriesOutputSchema();
  if (operationTarget === GITHUB_EVENTS_TARGET) return githubEventsOutputSchema();
  return githubUserDashboardOutputSchema();
}

function githubRecord(value: GitHubJsonValue): GitHubJsonRecord | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as GitHubJsonRecord;
}

function githubText(record: GitHubJsonRecord | null, names: string[]): string {
  if (record === null) return '';
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (typeof value === 'string' && value.trim().length > 0) return value.trim();
  }
  return '';
}

function githubNumber(record: GitHubJsonRecord | null, names: string[]): number | undefined {
  if (record === null) return undefined;
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (typeof value === 'number' && Number.isFinite(value)) return value;
  }
  return undefined;
}

function githubBoolean(record: GitHubJsonRecord | null, names: string[]): boolean | undefined {
  if (record === null) return undefined;
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (typeof value === 'boolean') return value;
  }
  return undefined;
}

function githubArray(record: GitHubJsonRecord | null, names: string[]): Object[] | null {
  if (record === null) return null;
  for (let index = 0; index < names.length; index++) {
    const value = record[names[index]];
    if (Array.isArray(value)) return value as Object[];
  }
  return null;
}

function putGitHubText(target: GitHubJsonRecord, name: string, value: string): void {
  if (value.length > 0) target[name] = value;
}

function putGitHubNumber(target: GitHubJsonRecord, name: string, value: number | undefined): void {
  if (value !== undefined) target[name] = value;
}

function putGitHubBoolean(target: GitHubJsonRecord, name: string, value: boolean | undefined): void {
  if (value !== undefined) target[name] = value;
}

function githubProfileData(providerData: Object, username: string, provenance: Object): GitHubNormalizedSection {
  const source = githubRecord(providerData);
  const login = githubText(source, ['login']);
  if (login.length === 0) return { data: null, empty: false };
  const profile = emptyGitHubRecord();
  profile['login'] = login;
  putGitHubText(profile, 'name', githubText(source, ['name']));
  putGitHubText(profile, 'bio', githubText(source, ['bio']));
  putGitHubText(profile, 'avatarUrl', githubText(source, ['avatar_url', 'avatarUrl']));
  putGitHubText(profile, 'url', githubText(source, ['html_url', 'url']));
  putGitHubText(profile, 'company', githubText(source, ['company']));
  putGitHubText(profile, 'location', githubText(source, ['location']));
  putGitHubText(profile, 'blog', githubText(source, ['blog']));
  putGitHubText(profile, 'createdAt', githubText(source, ['created_at', 'createdAt']));
  putGitHubText(profile, 'updatedAt', githubText(source, ['updated_at', 'updatedAt']));
  putGitHubNumber(profile, 'followers', githubNumber(source, ['followers']));
  putGitHubNumber(profile, 'following', githubNumber(source, ['following']));
  putGitHubNumber(profile, 'publicRepositories', githubNumber(source, ['public_repos', 'publicRepositories']));
  const data = emptyGitHubRecord();
  data['schemaVersion'] = 'github-user-profile.v1';
  data['username'] = username;
  data['profile'] = profile as Object;
  data['provenance'] = provenance;
  return { data: data as Object, empty: false };
}

function normalizedGitHubRepository(value: Object): Object | null {
  const source = githubRecord(value);
  const name = githubText(source, ['name']);
  const url = githubText(source, ['html_url', 'url']);
  if (name.length === 0 || url.length === 0) return null;
  const repository = emptyGitHubRecord();
  repository['name'] = name;
  repository['url'] = url;
  putGitHubText(repository, 'fullName', githubText(source, ['full_name', 'fullName']));
  repository['description'] = githubText(source, ['description']);
  putGitHubText(repository, 'language', githubText(source, ['language']));
  putGitHubText(repository, 'visibility', githubText(source, ['visibility']));
  putGitHubText(repository, 'updatedAt', githubText(source, ['updated_at', 'updatedAt']));
  putGitHubText(repository, 'pushedAt', githubText(source, ['pushed_at', 'pushedAt']));
  putGitHubNumber(repository, 'stars', githubNumber(source, ['stargazers_count', 'stars']));
  putGitHubNumber(repository, 'forks', githubNumber(source, ['forks_count', 'forks']));
  putGitHubNumber(repository, 'watchers', githubNumber(source, ['watchers_count', 'watchers']));
  putGitHubNumber(repository, 'openIssues', githubNumber(source, ['open_issues_count', 'openIssues']));
  putGitHubBoolean(repository, 'private', githubBoolean(source, ['private']));
  putGitHubBoolean(repository, 'fork', githubBoolean(source, ['fork']));
  putGitHubBoolean(repository, 'archived', githubBoolean(source, ['archived']));
  const topics = githubArray(source, ['topics']);
  if (topics !== null) repository['topics'] = topics as Object;
  return repository as Object;
}

function githubRepositorySortTime(value: Object): string {
  const record = githubRecord(value);
  const pushedAt = githubText(record, ['pushedAt']);
  return pushedAt.length > 0 ? pushedAt : githubText(record, ['updatedAt']);
}

function githubRepositoriesData(providerData: Object, username: string, provenance: Object): GitHubNormalizedSection {
  const source = githubRecord(providerData);
  const rawRepositories = githubArray(source, ['repositories']);
  if (rawRepositories === null) return { data: null, empty: false };
  const repositories: Object[] = [];
  for (let index = 0; index < rawRepositories.length; index++) {
    const normalized = normalizedGitHubRepository(rawRepositories[index]);
    if (normalized !== null) repositories.push(normalized);
  }
  repositories.sort((left: Object, right: Object): number =>
    githubRepositorySortTime(right).localeCompare(githubRepositorySortTime(left))
  );
  let stars = 0;
  let forks = 0;
  let languageRepositoryCount = 0;
  const languageCounts: Map<string, number> = new Map();
  repositories.forEach((repository: Object) => {
    const record = githubRecord(repository);
    stars += githubNumber(record, ['stars']) ?? 0;
    forks += githubNumber(record, ['forks']) ?? 0;
    const language = githubText(record, ['language']);
    if (language.length > 0) {
      languageCounts.set(language, (languageCounts.get(language) ?? 0) + 1);
      languageRepositoryCount++;
    }
  });
  const languages: Object[] = [];
  languageCounts.forEach((count: number, language: string) => {
    const metric = emptyGitHubRecord();
    metric['language'] = language;
    metric['repositoryCount'] = count;
    metric['ratio'] = count / languageRepositoryCount;
    languages.push(metric as Object);
  });
  languages.sort((left: Object, right: Object): number => {
    const leftCount = githubNumber(githubRecord(left), ['repositoryCount']) ?? 0;
    const rightCount = githubNumber(githubRecord(right), ['repositoryCount']) ?? 0;
    return rightCount - leftCount;
  });
  const metrics = emptyGitHubRecord();
  metrics['returnedRepositoryCount'] = repositories.length;
  metrics['returnedStars'] = stars;
  metrics['returnedForks'] = forks;
  const data = emptyGitHubRecord();
  data['schemaVersion'] = 'github-user-repositories.v1';
  data['username'] = username;
  data['repositories'] = repositories as Object;
  data['metrics'] = metrics as Object;
  data['languages'] = languages as Object;
  data['provenance'] = provenance;
  return { data: data as Object, empty: repositories.length === 0 };
}

function githubEventsData(providerData: Object, username: string, provenance: Object): GitHubNormalizedSection {
  const source = githubRecord(providerData);
  const events = githubArray(source, ['events']);
  if (events === null) return { data: null, empty: false };
  const metadata = githubRecord(source === null ? undefined : source['metadata']) ?? emptyGitHubRecord();
  const count = githubNumber(source, ['count']) ?? events.length;
  const data = emptyGitHubRecord();
  data['schemaVersion'] = 'github-user-activity.v1';
  data['username'] = username;
  data['recentActivity'] = events as Object;
  data['activityCount'] = count;
  data['activityMetadata'] = metadata as Object;
  data['provenance'] = provenance;
  return { data: data as Object, empty: events.length === 0 };
}

function normalizeGitHubSection(
  spec: GitHubOperationSpec,
  providerData: Object,
  username: string,
  provenance: Object
): GitHubNormalizedSection {
  if (spec.operationTarget === GITHUB_PROFILE_TARGET) {
    return githubProfileData(providerData, username, provenance);
  }
  if (spec.operationTarget === GITHUB_REPOSITORIES_TARGET) {
    return githubRepositoriesData(providerData, username, provenance);
  }
  return githubEventsData(providerData, username, provenance);
}

function githubErrorResult(toolName: string, message: string, rawPreview: string = ''): DynamicGenericToolResult {
  return {
    sourceTag: 'Composio', toolName: toolName, title: 'GitHub 用户数据读取失败', status: 'error',
    summary: message, rows: [{ label: '结果摘要', value: message.substring(0, 360) }],
    rawPreview: rawPreview.substring(0, 16000), providerPhase: 'discovery'
  };
}

function githubSchemaValidation(tool: ComposioSearchTool, username: string): GitHubSchemaValidation {
  const raw = textOf(tool.inputSchema).trim();
  if (raw.length === 0) {
    return { ok: false, message: 'Composio did not return an input schema.', schema: new Object(), args: new Object() };
  }
  if (raw.length > MAX_TRUSTED_GITHUB_SCHEMA_CHARS) {
    return { ok: false, message: 'Composio input schema exceeds the trusted size limit.', schema: new Object(), args: new Object() };
  }
  let schema: ComposioInputSchema;
  try {
    schema = JSON.parse(raw) as ComposioInputSchema;
  } catch (_error) {
    return { ok: false, message: 'Composio returned an invalid input schema.', schema: new Object(), args: new Object() };
  }
  if (schema.type !== undefined && schema.type !== 'object') {
    return { ok: false, message: 'Composio input schema is not an object.', schema: schema as Object, args: new Object() };
  }
  const properties = schema.properties;
  if (properties === undefined || Object.keys(properties).length === 0 || properties['username'] === undefined ||
    properties['username'].type !== 'string') {
    return { ok: false, message: 'Composio input schema does not declare username:string.', schema: schema as Object, args: new Object() };
  }
  const required = schema.required ?? [];
  if (required.indexOf('username') < 0) {
    return { ok: false, message: 'Composio input schema does not require username.', schema: schema as Object, args: new Object() };
  }
  const constructibleRequired = ['username', 'page', 'per_page'];
  const unsupportedRequired = required.filter((name: string): boolean => constructibleRequired.indexOf(name) < 0);
  if (unsupportedRequired.length > 0) {
    return {
      ok: false,
      message: 'Composio input schema added unsupported required fields: ' + unsupportedRequired.join(', ') + '.',
      schema: schema as Object,
      args: new Object()
    };
  }
  const args = new Object() as Record<string, Object | string | number | boolean>;
  args['username'] = username;
  if (properties['page'] !== undefined) {
    if (properties['page'].type !== 'integer' && properties['page'].type !== 'number') {
      return { ok: false, message: 'Composio page field has an unexpected type.', schema: schema as Object, args: new Object() };
    }
    args['page'] = 1;
  }
  if (properties['per_page'] !== undefined) {
    if (properties['per_page'].type !== 'integer' && properties['per_page'].type !== 'number') {
      return { ok: false, message: 'Composio per_page field has an unexpected type.', schema: schema as Object, args: new Object() };
    }
    args['per_page'] = 10;
  }
  const missingRequired = required.filter((name: string): boolean => args[name] === undefined);
  if (missingRequired.length > 0) {
    return {
      ok: false,
      message: 'Constructed arguments are missing required fields: ' + missingRequired.join(', ') + '.',
      schema: schema as Object,
      args: new Object()
    };
  }
  const unknownArguments = Object.keys(args).filter((name: string): boolean => properties[name] === undefined);
  if (unknownArguments.length > 0) {
    return { ok: false, message: 'Constructed arguments are not declared by the input schema.', schema: schema as Object, args: new Object() };
  }
  return { ok: true, message: '', schema: schema as Object, args: args as Object };
}

function exactGitHubTool(searchObservation: string, spec: GitHubOperationSpec): ComposioSearchTool | null {
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    return null;
  }
  if (!Array.isArray(payload.tools)) return null;
  for (let index = 0; index < payload.tools.length; index++) {
    const candidate = payload.tools[index] as ComposioSearchTool;
    if (textOf(candidate.toolSlug).trim().toUpperCase() === spec.toolSlug) return candidate;
  }
  return null;
}

function githubProvenance(
  spec: GitHubOperationSpec,
  status: string,
  receipt: string = '',
  message: string = ''
): Object {
  const provenance = emptyGitHubRecord();
  provenance['section'] = spec.section;
  provenance['status'] = status;
  provenance['provider'] = 'Composio';
  provenance['source'] = 'GitHub API';
  provenance['operationTarget'] = spec.operationTarget;
  provenance['toolSlug'] = spec.toolSlug;
  provenance['qualifiedName'] = spec.toolSlug;
  if (receipt.length > 0) provenance['receipt'] = receipt;
  if (message.length > 0) provenance['message'] = message.substring(0, 360);
  return provenance as Object;
}

async function executeGitHubSection(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  spec: GitHubOperationSpec,
  username: string
): Promise<GitHubSectionExecution> {
  const useCase = spec.useCase + ' Required tool slug: ' + spec.toolSlug + '.';
  let searchObservation = '';
  let tool: ComposioSearchTool | null = null;
  try {
    for (let attempt = 0; attempt < 3 && tool === null; attempt++) {
      searchObservation = await current.search(useCase);
      tool = exactGitHubTool(searchObservation, spec);
    }
  } catch (error) {
    const message = 'Composio GitHub tool search failed: ' + textOf(error) + '.';
    const result = githubErrorResult(spec.toolSlug, message);
    return {
      ok: false, empty: false, data: null, inputSchema: new Object(), receipt: '', result: result,
      provenance: githubProvenance(spec, 'error', '', message)
    };
  }
  if (tool === null) {
    const message = 'Composio search did not return the exact required tool ' + spec.toolSlug + '.';
    const result = githubErrorResult(spec.toolSlug, message, searchObservation);
    return {
      ok: false, empty: false, data: null, inputSchema: new Object(), receipt: '', result: result,
      provenance: githubProvenance(spec, 'error', '', message)
    };
  }
  const validation = githubSchemaValidation(tool, username);
  if (!validation.ok) {
    const result = githubErrorResult(spec.toolSlug, validation.message, searchObservation);
    return {
      ok: false, empty: false, data: null, inputSchema: validation.schema, receipt: '', result: result,
      provenance: githubProvenance(spec, 'error', '', validation.message)
    };
  }
  try {
    const execution = await executeComposioObservation(current, spec.toolSlug, validation.args, true);
    const providerResult = composioDynamicResultFromObservation(
      'execute', execution.observation, spec.toolSlug, username
    );
    const receipt = dynamicReceiptFromProviderPayload(execution.observation);
    if (providerResult.status !== 'success') {
      return {
        ok: false, empty: false, data: null, inputSchema: validation.schema, receipt: receipt,
        result: providerResult,
        provenance: githubProvenance(spec, 'error', receipt, providerResult.summary),
        providerDataMeta: execution.providerDataMeta
      };
    }
    if (execution.providerData === undefined) {
      const message = 'Composio returned no structured provider data for ' + spec.toolSlug + '.';
      const result = githubErrorResult(spec.toolSlug, message, execution.observation);
      return {
        ok: false, empty: false, data: null, inputSchema: validation.schema, receipt: receipt, result: result,
        provenance: githubProvenance(spec, 'error', receipt, message),
        providerDataMeta: execution.providerDataMeta
      };
    }
    const successProvenance = githubProvenance(spec, 'success', receipt);
    const normalized = normalizeGitHubSection(spec, execution.providerData, username, successProvenance);
    if (normalized.data === null) {
      const message = 'Composio provider data did not match the expected ' + spec.section + ' shape.';
      const result = githubErrorResult(spec.toolSlug, message, execution.observation);
      return {
        ok: false, empty: false, data: null, inputSchema: validation.schema, receipt: receipt, result: result,
        provenance: githubProvenance(spec, 'error', receipt, message),
        providerDataMeta: execution.providerDataMeta
      };
    }
    const status = normalized.empty ? 'empty' : 'success';
    const provenance = githubProvenance(spec, status, receipt);
    const normalizedRecord = githubRecord(normalized.data);
    if (normalizedRecord !== null) normalizedRecord['provenance'] = provenance;
    providerResult.toolName = spec.toolSlug;
    providerResult.title = 'GitHub 用户' + spec.section;
    providerResult.summary = normalized.empty ? 'GitHub ' + spec.section + ' 返回空结果。' :
      'GitHub ' + spec.section + ' 数据读取成功。';
    providerResult.providerData = normalized.data;
    providerResult.providerDataMeta = execution.providerDataMeta;
    return {
      ok: true, empty: normalized.empty, data: normalized.data, inputSchema: validation.schema,
      receipt: receipt, result: providerResult, provenance: provenance,
      providerDataMeta: execution.providerDataMeta
    };
  } catch (error) {
    const message = 'Composio GitHub execution failed: ' + textOf(error) + '.';
    const result = githubErrorResult(spec.toolSlug, message);
    return {
      ok: false, empty: false, data: null, inputSchema: validation.schema, receipt: '', result: result,
      provenance: githubProvenance(spec, 'error', '', message)
    };
  }
}

function registrationForGitHubTarget(
  operationTarget: string,
  toolName: string,
  inputSchema: Object,
  receipt: string
): DynamicRegistrationMetadata {
  return {
    provider: 'Composio', qualifiedName: toolName, inputSchema: inputSchema,
    outputSchema: githubOutputSchemaForTarget(operationTarget), receipt: receipt,
    selectedToolId: 'dynamic.search'
  };
}

function attachGitHubRegistration(
  result: DynamicGenericToolResult,
  operationTarget: string,
  toolName: string,
  inputSchema: Object,
  receipt: string
): DynamicGenericToolResult {
  result.registration = registrationForGitHubTarget(
    operationTarget, toolName, inputSchema, receipt
  );
  return result;
}

async function callComposioGitHubTargetWithClient(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  operationTarget: string,
  username: string
): Promise<DynamicGenericToolResult> {
  if (!isGitHubUserOperationTarget(operationTarget)) {
    const result = githubErrorResult(operationTarget, 'Unknown trusted GitHub operationTarget: ' + operationTarget + '.');
    result.status = 'unsafe_action_blocked';
    return attachGitHubRegistration(
      result, operationTarget, operationTarget, githubOperationInputSchema(), ''
    );
  }
  if (validGitHubLogin(username).length === 0) {
    return attachGitHubRegistration(
      githubErrorResult(operationTarget, 'GitHub username must be an exact valid login.'),
      operationTarget, operationTarget, githubOperationInputSchema(), ''
    );
  }
  if (operationTarget !== GITHUB_DASHBOARD_TARGET) {
    const spec = githubOperationSpec(operationTarget) as GitHubOperationSpec;
    const section = await executeGitHubSection(current, spec, username);
    return attachGitHubRegistration(
      section.result, operationTarget, spec.toolSlug, section.inputSchema, section.receipt
    );
  }
  const specs: GitHubOperationSpec[] = [
    githubOperationSpec(GITHUB_PROFILE_TARGET) as GitHubOperationSpec,
    githubOperationSpec(GITHUB_REPOSITORIES_TARGET) as GitHubOperationSpec,
    githubOperationSpec(GITHUB_EVENTS_TARGET) as GitHubOperationSpec
  ];
  const sections: GitHubSectionExecution[] = [];
  for (let index = 0; index < specs.length; index++) {
    sections.push(await executeGitHubSection(current, specs[index], username));
  }
  const dashboard = emptyGitHubRecord();
  dashboard['schemaVersion'] = 'github-user-dashboard.v1';
  dashboard['username'] = username;
  dashboard['partial'] = sections.some((section: GitHubSectionExecution): boolean => !section.ok);
  dashboard['sections'] = sections.map((section: GitHubSectionExecution): Object => section.provenance) as Object;
  dashboard['limitations'] = [
    'Recent events are a bounded activity feed, not an all-time contribution calendar.',
    'Repository metrics summarize only repositories returned by this provider page.'
  ] as Object;
  let successfulSections = 0;
  const profile = sections[0].data === null ? null : githubRecord(sections[0].data);
  const repositories = sections[1].data === null ? null : githubRecord(sections[1].data);
  const events = sections[2].data === null ? null : githubRecord(sections[2].data);
  if (sections[0].ok && profile !== null) {
    dashboard['profile'] = profile['profile'];
    successfulSections++;
  }
  if (sections[1].ok && repositories !== null) {
    dashboard['repositories'] = repositories['repositories'];
    dashboard['repositoryMetrics'] = repositories['metrics'];
    dashboard['languages'] = repositories['languages'];
    successfulSections++;
  }
  if (sections[2].ok && events !== null) {
    const recentActivity = events['recentActivity'];
    const dashboardActivity: Object[] = [];
    if (Array.isArray(recentActivity)) {
      recentActivity.forEach((item: Object) => {
        const event = githubRecord(item);
        const activity = emptyGitHubRecord();
        activity['time'] = githubText(event, ['occurredAt']);
        activity['summary'] = githubText(event, ['summary', 'title']);
        dashboardActivity.push(activity as Object);
      });
    }
    dashboard['recentActivity'] = dashboardActivity as Object;
    successfulSections++;
  }
  const failedSections = specs.length - successfulSections;
  const rawPreview = emptyGitHubRecord();
  rawPreview['operationTarget'] = operationTarget;
  rawPreview['username'] = username;
  rawPreview['sections'] = dashboard['sections'];
  const combinedMeta = emptyGitHubRecord();
  combinedMeta['truncated'] = sections.some((section: GitHubSectionExecution): boolean =>
    githubBoolean(githubRecord(section.providerDataMeta), ['truncated']) === true
  );
  combinedMeta['sections'] = sections.map((section: GitHubSectionExecution): Object =>
    section.providerDataMeta ?? new Object()
  ) as Object;
  const result: DynamicGenericToolResult = {
    sourceTag: 'Composio',
    toolName: GITHUB_DASHBOARD_TARGET,
    title: 'GitHub 用户数据看板',
    status: successfulSections === specs.length ? 'success' : (successfulSections > 0 ? 'partial' : 'error'),
    summary: successfulSections === specs.length ? 'GitHub 用户资料、仓库和最近活动读取成功。' :
      (successfulSections > 0 ? 'GitHub 用户看板部分可用：' + failedSections.toString() + ' 个分区失败。' :
        'GitHub 用户看板的三个分区均读取失败。'),
    rows: [
      { label: 'GitHub 用户', value: username },
      { label: '成功分区', value: successfulSections.toString() },
      { label: '失败分区', value: failedSections.toString() }
    ],
    rawPreview: JSON.stringify(rawPreview),
    providerPhase: 'execution',
    providerData: dashboard as Object,
    providerDataMeta: combinedMeta as Object
  };
  return attachGitHubRegistration(
    result, operationTarget, GITHUB_DASHBOARD_TARGET, githubOperationInputSchema(), ''
  );
}

export async function callComposioGithubOperationTargetForTest(
  current: ComposioSearchExecuteClient,
  operationTarget: string,
  username: string
): Promise<DynamicGenericToolResult> {
  return callComposioGitHubTargetWithClient(current, operationTarget, username);
}

export async function callComposioGithubOperationTarget(
  operationTarget: string,
  username: string,
  prompt: string
): Promise<DynamicGenericToolResult> {
  if (!isGitHubUserOperationTarget(operationTarget)) {
    const result = githubErrorResult(operationTarget, 'Unknown trusted GitHub operationTarget: ' + operationTarget + '.');
    result.status = 'unsafe_action_blocked';
    return attachGitHubRegistration(
      result, operationTarget, operationTarget, githubOperationInputSchema(), ''
    );
  }
  if (validGitHubLogin(username).length === 0) {
    return attachGitHubRegistration(
      githubErrorResult(operationTarget, 'GitHub username must be an exact valid login.'),
      operationTarget, operationTarget, githubOperationInputSchema(), ''
    );
  }
  if (!composioConfig.isConfigured()) {
    const missing = composioDynamicMissingConfigResult(prompt, operationTarget);
    return attachGitHubRegistration(
      missing, operationTarget, operationTarget, githubOperationInputSchema(), ''
    );
  }
  const current = await clientForPrompt('GitHub ' + prompt);
  return callComposioGitHubTargetWithClient(current, operationTarget, username);
}

export async function callComposioSearchAndExecute(
  current: ComposioSearchExecuteClient | ComposioSessionClient,
  prompt: string,
  requestArgs: Object | null
): Promise<DynamicGenericToolResult> {
  return callComposioSearchAndExecuteParsed(current, prompt, parsedExecuteArgs(requestArgs), false);
}

export async function callComposioFixedSearchAndExecuteForTest(
  current: ComposioSearchExecuteClient,
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object
): Promise<DynamicGenericToolResult> {
  const parsed: ComposioExecuteArgs = {
    fixedToolId: fixedToolId,
    fixedArgs: fixedArgs
  };
  return callComposioSearchAndExecuteParsed(current, prompt, parsed, true);
}

export async function callComposioFixedRaw(
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object
): Promise<ComposioRawExecution> {
  const current = await clientForPrompt(prompt);
  const searchObservation = await current.search(normalizedComposioUseCase(prompt, fixedToolId));
  let payload: ComposioSearchObservation;
  try {
    payload = JSON.parse(searchObservation) as ComposioSearchObservation;
  } catch (_error) {
    throw new Error('Composio returned an invalid tool search response.');
  }
  const tool = bestToolForPrompt(payload, prompt, fixedToolId);
  if (tool === null) {
    const expected = composioExactToolSlugForFixedTool(fixedToolId);
    throw new Error(expected.length > 0 ? 'Composio did not find required tool ' + expected + '.' : 'Composio did not find a matching tool.');
  }
  const toolSlug = textOf(tool.toolSlug).trim();
  const toolArgs = composioArgumentsForTool(tool, prompt, fixedToolId, fixedArgs);
  const authorizationMessage = selectedSlugAuthorizationMessage(toolSlug, fixedToolId, true);
  if (authorizationMessage.length > 0) {
    throw new Error(authorizationMessage);
  }
  const observation = await current.execute(toolSlug, toolArgs);
  const result: ComposioRawExecution = {
    toolSlug: toolSlug,
    observation: observation
  };
  return result;
}

async function client(): Promise<ComposioSessionClient> {
  if (composioClient === null) {
    composioClient = new ComposioSessionClient(configForCurrentUser());
    await composioClient.initialize();
  }
  return composioClient;
}

async function clientForPrompt(prompt: string): Promise<ComposioSessionClient> {
  const toolkit = composioToolkitFromPrompt(prompt);
  if (toolkit.length === 0) {
    return client();
  }
  let scoped = scopedComposioClients.get(toolkit);
  if (scoped === undefined) {
    scoped = new ComposioSessionClient(configForCurrentUser(), [toolkit]);
    await scoped.initialize();
    scopedComposioClients.set(toolkit, scoped);
  }
  return scoped;
}

async function callComposioParsed(
  prompt: string,
  parsed: ComposioExecuteArgs,
  allowFixedContract: boolean,
  preserveProviderData: boolean = false
): Promise<DynamicGenericToolResult | null> {
  const fixedToolId = textOf(parsed.fixedToolId).trim();
  const missingFixedArgs = missingFixedWriteArgs(fixedToolId, parsed.fixedArgs ?? null);
  if (missingFixedArgs.length > 0) {
    return missingFixedWriteArgsResult(prompt, fixedToolId, missingFixedArgs);
  }
  const operation = textOf(parsed.operation).trim();
  if (selectedQualifiedName(parsed).length === 0 &&
    !shouldAttemptComposioDynamic(prompt, operation, composioConfig.isConfigured())) {
    return null;
  }
  if (operation === 'execute') {
    const slug = textOf(parsed.toolSlug).trim();
    const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
    if (authorizationMessage.length > 0) {
      return blockedSelectedSlugResult(slug, authorizationMessage);
    }
  }
  if (!composioConfig.isConfigured()) {
    return composioDynamicMissingConfigResult(prompt, selectedQualifiedName(parsed));
  }
  const current = selectedQualifiedName(parsed).length > 0 ? await client() : await clientForPrompt(prompt);
  if (operation === 'execute') {
    const slug = textOf(parsed.toolSlug).trim();
    const authorizationMessage = selectedSlugAuthorizationMessage(slug, fixedToolId, allowFixedContract);
    if (authorizationMessage.length > 0) {
      return blockedSelectedSlugResult(slug, authorizationMessage);
    }
    const execution = await executeComposioObservation(
      current, slug, parsed.arguments ?? new Object(), preserveProviderData
    );
    const result = composioDynamicResultFromObservation('execute', execution.observation, slug, prompt);
    if (execution.providerData !== undefined) {
      result.providerData = execution.providerData;
      result.providerDataMeta = execution.providerDataMeta;
    }
    return result;
  }
  return callComposioSearchAndExecuteParsed(current, prompt, parsed, allowFixedContract, preserveProviderData);
}

export async function callComposioDynamic(prompt: string, args: Object | null): Promise<DynamicGenericToolResult | null> {
  return callComposioParsed(prompt, parsedExecuteArgs(args), false);
}

export async function callComposioDynamicWithProviderData(
  prompt: string,
  args: Object | null
): Promise<DynamicGenericToolResult | null> {
  return callComposioParsed(prompt, parsedExecuteArgs(args), false, true);
}

export async function callComposioFixedDynamic(
  prompt: string,
  fixedToolId: string,
  fixedArgs: Object | null
): Promise<DynamicGenericToolResult | null> {
  const parsed: ComposioExecuteArgs = {
    fixedToolId: fixedToolId,
    fixedArgs: fixedArgs ?? new Object()
  };
  return callComposioParsed(prompt, parsed, true);
}
