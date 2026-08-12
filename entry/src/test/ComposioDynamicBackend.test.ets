import { describe, it, expect } from '@ohos/hypium';
import {
  callComposioDynamic,
  callComposioGithubOperationTargetForTest,
  callComposioFixedSearchAndExecuteForTest,
  callComposioSearchAndExecute,
  composioDynamicMissingConfigResult,
  composioArgumentsForTool,
  composioDynamicResultFromObservation,
  composioProviderDataFromObservation,
  githubUserEventsNormalizedOutputSchema,
  limitComposioObservation,
  preservedComposioExecutionFromResponse,
  composioPreferredToolScore,
  composioExactToolSlugForFixedTool,
  composioPhoneNumberIdsFromObservation,
  configureComposioConfigFromRawJson,
  gmailDraftPreviewA2ui,
  proxyToolkitAccountsPreview,
  shouldAttemptComposioDynamic,
  configureComposioUserId,
  currentComposioConfig,
  currentComposioUserId,
  ComposioSearchTool,
  ComposioSearchExecuteClient,
  dynamicManifestRegistrationMetadata,
  dynamicReceiptFromProviderPayload,
  isComposioDynamicPrompt,
  isUnsafeComposioExecute,
  normalizedComposioUseCase,
  slackSearchQueryForPrompt,
  xPostStructuredDataResult
} from '@loop/agent-core';
import {
  DataResult,
  DynamicGenericToolResult,
  DynamicMcpTool,
  DynamicRegistrationMetadata
} from '@loop/agent-core';

function looseObject(raw: string): Object {
  return JSON.parse(raw) as Object;
}

function composioTool(raw: string): ComposioSearchTool {
  return JSON.parse(raw) as ComposioSearchTool;
}

interface TestComposioHeader {
  name: string;
  value: string;
}

interface TestComposioMessagePayload {
  headers: TestComposioHeader[];
}

interface TestComposioMessage {
  threadId: string;
  messageId: string;
  sender: string;
  subject: string;
  messageText: string;
  payload: TestComposioMessagePayload;
}

interface TestComposioObservationData {
  messages: TestComposioMessage[];
}

interface TestComposioObservation {
  data: TestComposioObservationData;
  error: null;
}

interface SelectedSlugCase {
  prompt: string;
  slug: string;
}

class RecordingComposioSearchExecuteClient implements ComposioSearchExecuteClient {
  searchObservation: string;
  executionObservation: string;
  searchedUseCases: string[] = [];
  executedSlugs: string[] = [];
  executedArgs: Object[] = [];

  constructor(searchObservation: string, executionObservation: string) {
    this.searchObservation = searchObservation;
    this.executionObservation = executionObservation;
  }

  async search(useCase: string): Promise<string> {
    this.searchedUseCases.push(useCase);
    return this.searchObservation;
  }

  async execute(toolSlug: string, args: Object): Promise<string> {
    this.executedSlugs.push(toolSlug);
    this.executedArgs.push(args);
    return this.executionObservation;
  }
}

class QueuedComposioSearchExecuteClient implements ComposioSearchExecuteClient {
  searchObservations: string[];
  executionObservations: string[];
  searchIndex: number = 0;
  executionIndex: number = 0;
  searchedUseCases: string[] = [];
  executedSlugs: string[] = [];
  executedArgs: Object[] = [];

  constructor(searchObservations: string[], executionObservations: string[]) {
    this.searchObservations = searchObservations;
    this.executionObservations = executionObservations;
  }

  async search(useCase: string): Promise<string> {
    this.searchedUseCases.push(useCase);
    const observation = this.searchIndex < this.searchObservations.length ?
      this.searchObservations[this.searchIndex] : '';
    this.searchIndex++;
    return observation;
  }

  async execute(toolSlug: string, args: Object): Promise<string> {
    this.executedSlugs.push(toolSlug);
    this.executedArgs.push(args);
    const observation = this.executionIndex < this.executionObservations.length ?
      this.executionObservations[this.executionIndex] : '';
    this.executionIndex++;
    return observation;
  }
}

function searchObservationForTool(
  slug: string,
  inputSchema: string = '{}',
  outputSchema: string = '{}'
): string {
  return '{"source":"Composio","authorizedToolkits":["test"],"tools":[{' +
    '"toolSlug":' + JSON.stringify(slug) + ',"description":"selected provider tool",' +
    '"inputSchema":' + JSON.stringify(inputSchema) + ',"outputSchema":' + JSON.stringify(outputSchema) +
    '}],"instruction":"execute selected tool"}';
}

function successfulExecutionObservation(): string {
  return '{"data":{"items":[{"id":"real-1","text":"real provider row","url":"https://example.com/real-1"}]}}';
}

export default function composioDynamicBackendTest() {
  describe('composioDynamicBackend', () => {
    it('aggregates the trusted GitHub dashboard from three exact read-only provider tools', 0, async () => {
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"},"page":{"type":"integer"},"per_page":{"type":"integer"}}}';
      const client = new QueuedComposioSearchExecuteClient(
        [
          searchObservationForTool('GITHUB_GET_A_USER', schema),
          searchObservationForTool('GITHUB_LIST_REPOSITORIES_FOR_A_USER', schema),
          searchObservationForTool('GITHUB_LIST_EVENTS_FOR_USER', schema)
        ],
        [
          '{"data":{"login":"sindresorhus","name":"Sindre","bio":"Open source",' +
            '"avatar_url":"https://avatars.example/sindre","html_url":"https://github.com/sindresorhus",' +
            '"followers":10,"following":2,"public_repos":3}}',
          '{"data":{"repositories":[' +
            '{"name":"alpha","full_name":"sindresorhus/alpha","html_url":"https://github.com/sindresorhus/alpha",' +
            '"description":"Alpha repository","language":"TypeScript","stargazers_count":7,"forks_count":2,"updated_at":"2026-07-01T00:00:00Z",' +
            '"pushed_at":"2026-07-02T00:00:00Z"},' +
            '{"name":"beta","full_name":"sindresorhus/beta","html_url":"https://github.com/sindresorhus/beta",' +
            '"description":null,"language":"TypeScript","stargazers_count":5,"forks_count":1,"updated_at":"2026-06-01T00:00:00Z"},' +
            '{"name":"gamma","full_name":"sindresorhus/gamma","html_url":"https://github.com/sindresorhus/gamma",' +
            '"language":"Python","stargazers_count":3,"forks_count":0,"updated_at":"2026-05-01T00:00:00Z"}' +
            ']}}',
          '{"data":{"events":[{"type":"PushEvent","created_at":"2026-08-01T00:00:00Z",' +
            '"repo":{"name":"sindresorhus/alpha"},"payload":{"ref":"refs/heads/main"},"public":true}]}}'
        ]
      );

      const result = await callComposioGithubOperationTargetForTest(
        client, 'github.user.dashboard', 'sindresorhus'
      );
      const dashboard = result.providerData as Record<string, Object | string | number | boolean>;
      const metrics = dashboard['repositoryMetrics'] as Record<string, number>;
      const repositories = dashboard['repositories'] as Array<Record<string, Object | string | number | boolean>>;
      const languages = dashboard['languages'] as Object[];
      const activity = dashboard['recentActivity'] as Array<Record<string, string>>;

      expect(result.status).assertEqual('success');
      expect(result.toolName).assertEqual('github.user.dashboard');
      expect(result.registration?.qualifiedName).assertEqual('github.user.dashboard');
      expect(client.executedSlugs.join(',')).assertEqual(
        'GITHUB_GET_A_USER,GITHUB_LIST_REPOSITORIES_FOR_A_USER,GITHUB_LIST_EVENTS_FOR_USER'
      );
      expect(client.executedArgs.length).assertEqual(3);
      expect(JSON.stringify(client.executedArgs[0])).assertContain('"username":"sindresorhus"');
      expect(dashboard['partial']).assertFalse();
      expect(metrics['returnedRepositoryCount']).assertEqual(3);
      expect(metrics['returnedStars']).assertEqual(15);
      expect(metrics['returnedForks']).assertEqual(3);
      expect(repositories[0]['description']).assertEqual('Alpha repository');
      expect(Object.keys(repositories[1]).indexOf('description')).assertLarger(-1);
      expect(repositories[1]['description']).assertEqual('');
      expect(languages.length).assertEqual(2);
      const primaryLanguage = languages[0] as Record<string, Object | string | number>;
      const secondaryLanguage = languages[1] as Record<string, Object | string | number>;
      expect(primaryLanguage['language']).assertEqual('TypeScript');
      expect(primaryLanguage['repositoryCount']).assertEqual(2);
      expect(primaryLanguage['ratio']).assertEqual(2 / 3);
      expect(secondaryLanguage['language']).assertEqual('Python');
      expect(secondaryLanguage['repositoryCount']).assertEqual(1);
      expect(secondaryLanguage['ratio']).assertEqual(1 / 3);
      const dashboardOutputSchema = JSON.stringify(result.registration?.outputSchema);
      expect(dashboardOutputSchema).assertContain('"ratio":{"type":"number"}');
      expect(dashboardOutputSchema).assertContain('"required":["time","summary"]');
      expect(dashboardOutputSchema).assertContain('"time":{"type":"string"},"summary":{"type":"string"}');
      expect(dashboardOutputSchema).assertContain('"recentActivity":{"type":"array"');
      expect(dashboardOutputSchema.indexOf('"activityMetadata"')).assertEqual(-1);
      expect(activity.length).assertEqual(1);
      expect(activity[0]['summary']).assertEqual('向 sindresorhus/alpha 的 main 分支执行了推送');
      expect(activity[0]['summary'].indexOf('0 个提交')).assertEqual(-1);
      expect(activity[0]['time']).assertEqual('2026-08-01T00:00:00Z');
      expect(dashboard['activityMetadata'] === undefined).assertTrue();
      expect(JSON.stringify(activity[0]).indexOf('title')).assertEqual(-1);
      expect(JSON.stringify(activity[0]).indexOf('kind')).assertEqual(-1);
      expect(JSON.stringify(activity[0]).indexOf('repo')).assertEqual(-1);
      expect(JSON.stringify(activity[0]).indexOf('details')).assertEqual(-1);
      expect(JSON.stringify(activity[0]).indexOf('visibility')).assertEqual(-1);
      expect(JSON.stringify(dashboard).indexOf('contributions')).assertEqual(-1);
    });

    it('distinguishes unknown and explicit zero GitHub push commit counts', 0, () => {
      const observation = '{"data":{"events":[' +
        '{"type":"PushEvent","created_at":"2026-08-04T06:00:00Z",' +
        '"repo":{"name":"owner/unknown"},"payload":{"ref":"refs/heads/main"}},' +
        '{"type":"PushEvent","created_at":"2026-08-04T07:00:00Z",' +
        '"repo":{"name":"owner/zero"},"payload":{"ref":"refs/heads/release","distinct_size":0}}]}}';
      const preserved = composioDynamicResultFromObservation(
        'execute', observation, 'GITHUB_LIST_EVENTS_FOR_USER', 'GitHub user activity', true
      );
      const provider = preserved.providerData as Record<string, Object>;
      const events = provider['events'] as Array<Record<string, Object | string>>;
      const unknown = events[0];
      const explicitZero = events[1];
      const unknownDetails = unknown['details'] as Record<string, Object | string | number>;
      const zeroDetails = explicitZero['details'] as Record<string, Object | string | number>;

      expect(unknown['summary']).assertEqual('向 owner/unknown 的 main 分支执行了推送');
      expect(unknownDetails['commitCount'] === undefined).assertTrue();
      expect((unknown['summary'] as string).indexOf('0 个提交')).assertEqual(-1);
      expect(explicitZero['summary']).assertEqual(
        '向 owner/zero 的 release 分支执行了推送（未包含新提交）'
      );
      expect(zeroDetails['commitCount']).assertEqual(0);
    });

    it('fails closed before execute for absent malformed oversized or expanded GitHub schemas', 0, async () => {
      const validPrefix = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string","description":"';
      const invalidSchemas: string[] = [
        '{}',
        '{not-json',
        validPrefix + 'x'.repeat(3100) + '"}}',
        '{"type":"object","required":["username","installation_id"],"properties":{' +
          '"username":{"type":"string"},"installation_id":{"type":"string"}}}'
      ];
      for (let index = 0; index < invalidSchemas.length; index++) {
        const client = new RecordingComposioSearchExecuteClient(
          searchObservationForTool('GITHUB_GET_A_USER', invalidSchemas[index]),
          '{"data":{"login":"must-not-execute"}}'
        );
        const result = await callComposioGithubOperationTargetForTest(
          client, 'github.profile', 'sindresorhus'
        );
        expect(result.status).assertEqual('error');
        expect(client.executedSlugs.length).assertEqual(0);
      }
    });

    it('reports partial dashboard provenance and fails only when every section fails', 0, async () => {
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"}}}';
      const partialClient = new QueuedComposioSearchExecuteClient(
        [
          searchObservationForTool('GITHUB_GET_A_USER', schema),
          searchObservationForTool('GITHUB_LIST_REPOSITORIES_FOR_A_USER', schema),
          searchObservationForTool('GITHUB_LIST_EVENTS_FOR_USER', '{}')
        ],
        [
          '{"data":{"login":"sindresorhus","followers":10,"deep":' +
            '{"next":'.repeat(20) + '{"value":1}' + '}'.repeat(20) + '}}',
          '{"error":{"message":"repositories unavailable"}}'
        ]
      );
      const partial = await callComposioGithubOperationTargetForTest(
        partialClient, 'github.user.dashboard', 'sindresorhus'
      );
      const partialData = partial.providerData as Record<string, Object | string | number | boolean>;
      const partialMeta = partial.providerDataMeta as Record<string, Object | string | number | boolean>;
      expect(partial.status).assertEqual('partial');
      expect(partialData['partial']).assertTrue();
      expect(partialMeta['truncated']).assertTrue();
      expect(JSON.stringify(partialData['sections'])).assertContain('"status":"error"');
      expect(partialData['profile'] === undefined).assertFalse();
      expect(partialClient.executedSlugs.length).assertEqual(2);

      const missing = '{"source":"Composio","authorizedToolkits":["github"],"tools":[]}';
      const failedClient = new QueuedComposioSearchExecuteClient([missing, missing, missing], []);
      const failed = await callComposioGithubOperationTargetForTest(
        failedClient, 'github.user.dashboard', 'sindresorhus'
      );
      expect(failed.status).assertEqual('error');
      expect((failed.providerData as Record<string, boolean>)['partial']).assertTrue();
      expect(failedClient.executedSlugs.length).assertEqual(0);
    });

    it('normalizes single target identity and rejects unknown targets or invalid usernames without search', 0, async () => {
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"}}}';
      const profileClient = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('github_get_a_user', schema),
        '{"data":{"login":"sindresorhus","public_repos":3}}'
      );
      const profile = await callComposioGithubOperationTargetForTest(
        profileClient, 'github.profile', 'sindresorhus'
      );
      expect(profile.status).assertEqual('success');
      expect(profile.toolName).assertEqual('GITHUB_GET_A_USER');
      expect(profile.registration?.qualifiedName).assertEqual('GITHUB_GET_A_USER');
      expect(profileClient.executedSlugs[0]).assertEqual('GITHUB_GET_A_USER');

      const rejectedClient = new QueuedComposioSearchExecuteClient([], []);
      const unknown = await callComposioGithubOperationTargetForTest(
        rejectedClient, 'github.delete', 'sindresorhus'
      );
      const invalidUser = await callComposioGithubOperationTargetForTest(
        rejectedClient, 'github.profile', 'bad_user'
      );
      expect(unknown.status).assertEqual('unsafe_action_blocked');
      expect(invalidUser.status).assertEqual('error');
      expect(rejectedClient.searchedUseCases.length).assertEqual(0);
      expect(rejectedClient.executedSlugs.length).assertEqual(0);
    });

    it('passes structured dynamic query through a full GitHub user-events discovery and execute', 0, async () => {
      const slug = 'GITHUB_LIST_EVENTS_FOR_USER';
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"},"page":{"type":"integer"},"per_page":{"type":"integer"}}}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservationForTool(slug, schema),
        successfulExecutionObservation()
      );
      await callComposioSearchAndExecute(
        client,
        '请汇总这个 GitHub 账号的公开资料、仓库和最近动态',
        looseObject('{"query":"sindresorhus","platforms":["github"]}')
      );
      const args = client.executedArgs[0] as Record<string, Object | string | number | boolean | null | undefined>;
      expect(client.executedSlugs[0]).assertEqual(slug);
      expect(args['username']).assertEqual('sindresorhus');
      expect(args['page']).assertEqual(1);
      expect(args['per_page']).assertEqual(10);
    });

    it('maps structured query only for the GitHub user-read allowlist', 0, () => {
      const slugs: string[] = [
        'GITHUB_LIST_EVENTS_FOR_USER',
        'GITHUB_GET_A_USER',
        'GITHUB_LIST_REPOSITORIES_FOR_A_USER'
      ];
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"},"page":{"type":"integer"},"per_page":{"type":"integer"}}}';
      for (let index = 0; index < slugs.length; index++) {
        const tool = composioTool('{"toolSlug":' + JSON.stringify(slugs[index]) + ',"inputSchema":' +
          JSON.stringify(schema) + '}');
        const args = composioArgumentsForTool(
          tool,
          '请汇总这个 GitHub 账号的公开资料、仓库和最近动态',
          '',
          null,
          looseObject('{"query":"sindresorhus","platforms":["github"]}')
        ) as Record<string, Object | string | number | boolean | null | undefined>;
        expect(args['username']).assertEqual('sindresorhus');
        expect(args['page']).assertEqual(1);
        expect(args['per_page']).assertEqual(10);
      }
    });

    it('extracts only an explicit GitHub user login when structured query is absent', 0, () => {
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"},"page":{"type":"integer"},"per_page":{"type":"integer"}}}';
      const tool = composioTool('{"toolSlug":"GITHUB_LIST_EVENTS_FOR_USER","inputSchema":' +
        JSON.stringify(schema) + '}');
      const explicit = composioArgumentsForTool(
        tool,
        '请查看 GitHub 用户 sindresorhus 的最近公开活动',
        '',
        null,
        looseObject('{"platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      const ambiguous = composioArgumentsForTool(
        tool,
        '请在 GitHub 上找一位活跃开发者并查看最近公开活动',
        '',
        null,
        looseObject('{"platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(explicit['username']).assertEqual('sindresorhus');
      expect(ambiguous['username'] === undefined).assertTrue();
      expect(JSON.stringify(ambiguous).indexOf('请在 GitHub')).assertEqual(-1);
    });

    it('validates the complete explicit GitHub login token without prefix truncation', 0, () => {
      const schema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"}}}';
      const tool = composioTool('{"toolSlug":"GITHUB_GET_A_USER","inputSchema":' +
        JSON.stringify(schema) + '}');
      const invalid: string[] = [
        'foo_bar',
        'a--b',
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        '-leading',
        'trailing-'
      ];
      for (let index = 0; index < invalid.length; index++) {
        const args = composioArgumentsForTool(
          tool,
          '请查看 GitHub 用户 ' + invalid[index] + ' 的公开资料',
          '',
          null,
          looseObject('{"platforms":["github"]}')
        ) as Record<string, Object | string | number | boolean | null | undefined>;
        expect(args['username'] === undefined).assertTrue();
      }
      const valid = composioArgumentsForTool(
        tool,
        '请查看 GitHub User foo-bar 的公开资料',
        '',
        null,
        looseObject('{"platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(valid['username']).assertEqual('foo-bar');
    });

    it('fails closed for a sentence-shaped dynamic query and omits undeclared pagination', 0, () => {
      const usernameOnlySchema = '{"type":"object","required":["username"],"properties":{' +
        '"username":{"type":"string"}}}';
      const usernameOnlyTool = composioTool('{"toolSlug":"GITHUB_LIST_EVENTS_FOR_USER","inputSchema":' +
        JSON.stringify(usernameOnlySchema) + '}');
      const usernameOnly = composioArgumentsForTool(
        usernameOnlyTool,
        '请汇总这个 GitHub 账号的公开资料、仓库和最近动态',
        '',
        null,
        looseObject('{"query":"sindresorhus","platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      const noSchemaTool = composioTool('{"toolSlug":"GITHUB_LIST_REPOSITORIES_FOR_A_USER","inputSchema":"{}"}');
      const noSchema = composioArgumentsForTool(
        noSchemaTool,
        '请汇总这个 GitHub 账号的公开资料、仓库和最近动态',
        '',
        null,
        looseObject('{"query":"sindresorhus","platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      const sentenceQuery = composioArgumentsForTool(
        usernameOnlyTool,
        '请汇总这个 GitHub 账号的公开资料、仓库和最近动态',
        '',
        null,
        looseObject('{"query":"请查看 sindresorhus 的 GitHub 活动","platforms":["github"]}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(usernameOnly['username']).assertEqual('sindresorhus');
      expect(usernameOnly['page'] === undefined).assertTrue();
      expect(usernameOnly['per_page'] === undefined).assertTrue();
      expect(noSchema['username']).assertEqual('sindresorhus');
      expect(noSchema['page'] === undefined).assertTrue();
      expect(noSchema['per_page'] === undefined).assertTrue();
      expect(sentenceQuery['username'] === undefined).assertTrue();
    });

    it('pins restored social community reads to exact provider slugs', 0, () => {
      expect(composioExactToolSlugForFixedTool('social.x.community.search'))
        .assertEqual('TWITTER_RECENT_SEARCH');
      expect(composioExactToolSlugForFixedTool('social.linkedin.profile'))
        .assertEqual('LINKEDIN_GET_MY_INFO');
      expect(composioExactToolSlugForFixedTool('social.instagram.media.list'))
        .assertEqual('INSTAGRAM_GET_IG_USER_MEDIA');
      expect(composioExactToolSlugForFixedTool('social.reddit.profile'))
        .assertEqual('REDDIT_GET_REDDIT_USER_ABOUT');
      expect(composioExactToolSlugForFixedTool('social.reddit.search'))
        .assertEqual('REDDIT_SEARCH_ACROSS_SUBREDDITS');
      expect(composioExactToolSlugForFixedTool('social.reddit.comments'))
        .assertEqual('REDDIT_RETRIEVE_POST_COMMENTS');
      expect(composioExactToolSlugForFixedTool('social.hackernews.item.read'))
        .assertEqual('HACKERNEWS_GET_ITEM');
    });

    it('passes exact social media and comment fields to provider tools', 0, () => {
      const redditArgs = composioArgumentsForTool({
        toolSlug: 'REDDIT_RETRIEVE_POST_COMMENTS',
        inputSchema: '{"type":"object","properties":{"article_id":{"type":"string"}},"required":["article_id"]}'
      }, '读取 Reddit 评论', 'social.reddit.comments', looseObject('{"articleId":"abc123"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      const currentRedditArgs = composioArgumentsForTool({
        toolSlug: 'REDDIT_RETRIEVE_POST_COMMENTS',
        inputSchema: '{"type":"object","properties":{"article":{"type":"string"}},"required":["article"]}'
      }, '读取 Reddit 评论', 'social.reddit.comments', looseObject('{"articleId":"abc123"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      const xArgs = composioArgumentsForTool({
        toolSlug: 'TWITTER_RECENT_SEARCH',
        inputSchema: '{"type":"object","properties":{"query":{"type":"string"},"max_results":{"type":"number"},' +
          '"expansions":{"type":"string"},"media_fields":{"type":"string"},"tweet_fields":{"type":"string"}}}'
      }, '搜索 X', 'x.post.search', looseObject('{"query":"codex","pageSize":10,' +
        '"expansions":"attachments.media_keys","mediaFields":"url,variants","tweetFields":"attachments"}')) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(redditArgs['article_id']).assertEqual('abc123');
      expect(currentRedditArgs['article']).assertEqual('abc123');
      expect(xArgs['max_results']).assertEqual(10);
      expect(xArgs['expansions']).assertEqual('attachments.media_keys');
      expect(xArgs['media_fields']).assertEqual('url,variants');
      expect(xArgs['tweet_fields']).assertEqual('attachments');
    });

    it('recognizes unsupported high-frequency app queries', 0, () => {
      expect(isComposioDynamicPrompt('帮我在 Notion 里找一下 7 月旅行计划相关页面')).assertTrue();
      expect(isComposioDynamicPrompt('帮我在 Google Docs 里找 AIPhoneDemo 设计文档')).assertTrue();
      expect(isComposioDynamicPrompt('帮我查 Linear 里分配给我的高优先级 bug')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Gmail 查最近重要邮件')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Google Calendar 查本月日程')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio YouTube 查我的播放列表')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio X 查 openai 最近公开 post')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Composio Twitter 查我的私信')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Discord 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我在 LinkedIn 查 AIPhoneDemo 相关动态')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 WhatsApp 查最近提到 AIPhoneDemo 的消息')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Instgram 查 AIPhoneDemo 相关评论')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 soptify 搜适合 demo 的播放列表')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 TikTok 搜 AIPhoneDemo 相关短视频')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Ticketmaster 查深圳本周末演唱会')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Reddit 查 openai codex 讨论')).assertTrue();
      expect(isComposioDynamicPrompt('帮我用 Weibo 查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我用 Composio Weibo 查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我用知乎查 openai codex 讨论')).assertFalse();
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
    });

    it('maps missing config to a truthful result', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicMissingConfigResult('帮我在 Notion 里找签证材料');

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('needs_auth');
      expect(result.summary.indexOf('Composio 未配置')).assertLarger(-1);
      expect(result.rawPreview.indexOf('Notion')).assertLarger(-1);
    });

    it('blocks dynamic Composio side effects while allowing reads', 0, () => {
      expect(isUnsafeComposioExecute('GMAIL_SEND_EMAIL', '{}')).assertTrue();
      expect(isUnsafeComposioExecute('GMAIL_REPLY_TO_THREAD', '{}')).assertTrue();
      expect(isUnsafeComposioExecute('NOTION_CREATE_PAGE', '{"title":"AIPhoneDemo"}')).assertTrue();
      expect(isUnsafeComposioExecute('GITHUB_FIND_PULL_REQUESTS', '{"sort":"updated"}')).assertFalse();
      expect(isUnsafeComposioExecute('REDDIT_RETRIEVE_POST_COMMENTS', '{}')).assertFalse();
    });

    it('executes the selected qualifiedName instead of a prompt-ranked candidate', 0, async () => {
      const client = new RecordingComposioSearchExecuteClient(
        '{"source":"Composio","authorizedToolkits":["github","googledrive"],"tools":[' +
          '{"toolSlug":"GOOGLEDRIVE_SEARCH_FILES","description":"Search Drive files","inputSchema":"{}"},' +
          '{"toolSlug":"GITHUB_LIST_PULL_REQUESTS","description":"List pull requests","inputSchema":"{}"}' +
        '],"instruction":"execute selected tool"}', successfulExecutionObservation()
      );
      const result = await callComposioSearchAndExecute(
        client, 'search Google Drive files',
        looseObject('{"operation":"list","qualifiedName":"GITHUB_LIST_PULL_REQUESTS"}')
      );

      expect(result.status).assertEqual('success');
      expect(result.registration?.qualifiedName).assertEqual('GITHUB_LIST_PULL_REQUESTS');
      expect(client.searchedUseCases[0]).assertEqual('GITHUB_LIST_PULL_REQUESTS');
      expect(client.executedSlugs[0]).assertEqual('GITHUB_LIST_PULL_REQUESTS');
    });

    it('reauthorizes every actual selected Composio slug before execute', 0, async () => {
      const blocked: SelectedSlugCase[] = [
        { prompt: 'use GitHub', slug: 'GITHUB_EXECUTE_WORKFLOW' },
        { prompt: 'use Google Drive', slug: 'google-drive.write-file' },
        { prompt: 'use Notion', slug: 'notionAppendBlock' },
        { prompt: 'use Slack', slug: 'slackuploadfile' },
        { prompt: 'use GitHub', slug: 'COMPOSIO_GITHUB_PUBLISH_RELEASE' },
        { prompt: 'use GitHub', slug: 'GITHUB_SEARCH_AND_DELETE_REPOSITORY' },
        { prompt: 'use GitHub', slug: 'GITHUB_FIND_AND_DELETE_REPOSITORY' },
        { prompt: 'use Google Drive', slug: 'GOOGLEDRIVE_FIND_AND_SHARE_FILE' },
        { prompt: 'use Gmail', slug: 'GMAIL_FETCH_AND_SEND_EMAIL' },
        { prompt: 'use GitHub', slug: 'GITHUB_SYNC_REPOSITORY' },
        { prompt: 'use GitHub', slug: 'GITHUB_BUDGET_REPORT' },
        { prompt: 'use Google Drive', slug: 'GOOGLEDRIVE_SPREADSHEET_EXPORT' },
        { prompt: 'use GitHub', slug: 'GITHUB_GET_AND_MERGE_PULL_REQUEST' },
        { prompt: 'use GitHub', slug: 'github.get-and-archive-repository' },
        { prompt: 'use GitHub', slug: 'githubGetAndTriggerWorkflow' },
        { prompt: 'use GitHub', slug: 'githubGetThenRunWorkflow' },
        { prompt: 'use GitHub', slug: 'github.get-or-copy-repository' },
        { prompt: 'use GitHub', slug: 'GITHUB_GETANDTRIGGERWORKFLOW' },
        { prompt: 'use GitHub', slug: 'GITHUB_GETAWAY' },
        { prompt: 'use GitHub', slug: 'githubGetaway' },
        { prompt: 'use GitHub', slug: 'githubgetaway' }
      ];
      for (let index = 0; index < blocked.length; index++) {
        const current = blocked[index];
        const client = new RecordingComposioSearchExecuteClient(
          searchObservationForTool(current.slug), successfulExecutionObservation()
        );
        const result = await callComposioSearchAndExecute(
          client, current.prompt, looseObject('{"operation":"search"}')
        );
        expect(result.status).assertEqual('unsafe_action_blocked');
        expect(client.executedSlugs.length).assertEqual(0);
      }
      const callerClaimedFixed = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('GMAIL_CREATE_DRAFT'), successfulExecutionObservation()
      );
      const callerClaimedFixedResult = await callComposioSearchAndExecute(
        callerClaimedFixed, 'use Gmail',
        looseObject('{"operation":"search","fixedToolId":"gmail.draft.create",' +
          '"fixedArgs":{"to":["alice@example.com"],"body":"hello"}}')
      );
      expect(callerClaimedFixedResult.status).assertEqual('unsafe_action_blocked');
      expect(callerClaimedFixed.executedSlugs.length).assertEqual(0);

      const allowed: SelectedSlugCase[] = [
        { prompt: 'use GitHub', slug: 'GITHUB_SEARCH_REPOSITORIES' },
        { prompt: 'use GitHub', slug: 'GITHUB_FIND_PULL_REQUESTS' },
        { prompt: 'use GitHub', slug: 'github.list-repositories' },
        { prompt: 'use GitHub', slug: 'githubGetRepository' },
        { prompt: 'use GitHub', slug: 'githubsearchrepositories' },
        { prompt: 'use GitHub', slug: 'COMPOSIO_GITHUB_READ_REPOSITORY' },
        { prompt: 'use Google Drive', slug: 'GOOGLEDRIVE_FIND_FILE' },
        { prompt: 'search Twitter posts', slug: 'TWITTER_SEARCH_POSTS' },
        { prompt: 'use Slack', slug: 'slack.list-channels' },
        { prompt: 'use Gmail', slug: 'GMAIL_FETCH_EMAILS' },
        { prompt: 'use Gmail', slug: 'gmailGetMessage' },
        { prompt: 'use Google Drive', slug: 'googledrivereadfile' },
        { prompt: 'use GitHub', slug: 'COMPOSIO_GITHUB_READ_FILE' },
        { prompt: 'use Google Docs', slug: 'GOOGLEDOCS_SEARCH_DOCUMENTS' },
        { prompt: 'use TikTok', slug: 'TIKTOK_SEARCH_VIDEOS' },
        { prompt: 'use Gmail', slug: 'GMAIL_SEARCH_PEOPLE' },
        { prompt: 'use Gmail', slug: 'GMAIL_SEARCH_CONTACTS' },
        { prompt: 'use GitHub', slug: 'GITHUB_LIST_PULL_REQUESTS' }
      ];
      for (let index = 0; index < allowed.length; index++) {
        const current = allowed[index];
        const client = new RecordingComposioSearchExecuteClient(
          searchObservationForTool(current.slug), successfulExecutionObservation()
        );
        const result = await callComposioSearchAndExecute(
          client, current.prompt, looseObject('{"operation":"search"}')
        );
        expect(result.status).assertEqual('success');
        expect(result.providerPhase).assertEqual('execution');
        expect(client.executedSlugs.length).assertEqual(1);
        expect(client.executedSlugs[0]).assertEqual(current.slug);
      }
      const mixedReadAndWrite = new RecordingComposioSearchExecuteClient(
        '{"source":"Composio","authorizedToolkits":["twitter"],"tools":[' +
          '{"toolSlug":"TWITTER_SEARCH_POSTS","description":"Search public posts",' +
            '"inputSchema":"{}","outputSchema":"{}"},' +
          '{"toolSlug":"TWITTER_CREATE_POST","description":"Create a public post",' +
            '"inputSchema":"{}","outputSchema":"{}"}' +
        '],"instruction":"execute selected tool"}',
        successfulExecutionObservation()
      );
      const mixedResult = await callComposioSearchAndExecute(
        mixedReadAndWrite, 'search Twitter posts', looseObject('{"operation":"search"}')
      );
      expect(mixedResult.status).assertEqual('success');
      expect(mixedResult.providerPhase).assertEqual('execution');
      expect(mixedReadAndWrite.executedSlugs.length).assertEqual(1);
      expect(mixedReadAndWrite.executedSlugs[0]).assertEqual('TWITTER_SEARCH_POSTS');
    });

    it('preserves actual Composio schemas and only genuine bounded receipts', 0, async () => {
      const inputSchema = '{"type":"object","properties":{"query":{"type":"string"}}}';
      const outputSchema = '{"type":"object","properties":{"items":{"type":"array"}}}';
      const observation = '{"request_id":"req.Trace-123","data":{"items":[{' +
        '"id":"tweet-1","text":"payload-secret","token":"sk-live-secret",' +
        '"url":"https://x.com/openai/status/1"}]}}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('TWITTER_RECENT_SEARCH', inputSchema, outputSchema), observation
      );
      const result = await callComposioSearchAndExecute(
        client, 'search Twitter posts', looseObject('{"operation":"search","fixedToolId":"x.post.search"}')
      );
      const registration = result.registration as DynamicRegistrationMetadata;

      expect(JSON.stringify(registration.inputSchema)).assertEqual(inputSchema);
      expect(JSON.stringify(registration.outputSchema)).assertEqual(outputSchema);
      expect(registration.receipt).assertEqual('req.Trace-123');
      expect(registration.receipt.length).assertLess(129);
      expect(registration.receipt.indexOf('payload-secret')).assertEqual(-1);
      expect(registration.receipt.indexOf('sk-live-secret')).assertEqual(-1);

      const noReceiptClient = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('GITHUB_SEARCH_REPOSITORIES'),
        '{"data":{"items":[{"id":"payload-id-is-not-a-receipt","text":"secret-body"}]}}'
      );
      const noReceipt = await callComposioSearchAndExecute(
        noReceiptClient, 'use GitHub', looseObject('{"operation":"search"}')
      );
      expect(noReceipt.registration?.receipt).assertEqual('');
      expect(dynamicReceiptFromProviderPayload(noReceipt.rawPreview)).assertEqual('');
    });

    it('keeps ModelScope schemas distinct and payload data out of receipts', 0, () => {
      const tool: DynamicMcpTool = {
        name: 'weather.search',
        description: 'Read weather',
        inputSchema: looseObject('{"type":"object","properties":{"city":{"type":"string"}}}')
      };
      const providerResult: DynamicGenericToolResult = {
        sourceTag: 'ModelScope Weather',
        toolName: 'weather.search',
        title: 'Weather result',
        status: 'success',
        summary: 'real weather',
        rows: [{ label: 'temperature', value: '31 C' }],
        rawPreview: '{"data":{"token":"secret-token","items":[{"id":"payload-id"}]}}'
      };
      const metadata = dynamicManifestRegistrationMetadata('ModelScope Weather', tool, providerResult);

      expect(JSON.stringify(metadata.inputSchema).indexOf('city')).assertLarger(-1);
      expect(JSON.stringify(metadata.outputSchema)).assertEqual('{}');
      expect(metadata.receipt).assertEqual('');
      expect(metadata.receipt.indexOf('secret-token')).assertEqual(-1);
      expect(metadata.receipt.indexOf('payload-id')).assertEqual(-1);
    });

    it('does not relabel X discovery or fallback responses as post data', 0, async () => {
      const currentPostsClient = new RecordingComposioSearchExecuteClient(
        '{"source":"Composio","authorizedToolkits":["twitter"],"tools":[' +
          '{"toolSlug":"TWITTER_SEARCH_RECENT_COUNTS","description":"Count recent posts",' +
            '"inputSchema":"{}","outputSchema":"{}"},' +
          '{"toolSlug":"TWITTER_RECENT_SEARCH","description":"Search recent posts",' +
            '"inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"query\\"],' +
              '\\"properties\\":{\\"query\\":{\\"type\\":\\"string\\"},' +
              '\\"max_results\\":{\\"type\\":\\"integer\\"}}}","outputSchema":"{}"}' +
        '],"instruction":"execute selected tool"}',
        '{"data":{"posts":[{"id":"tweet-current-1","text":"real post",' +
          '"url":"https://x.com/openai/status/tweet-current-1"}]}}'
      );
      const currentPosts = await callComposioSearchAndExecute(
        currentPostsClient, 'search Twitter public posts',
        looseObject('{"operation":"search","fixedToolId":"x.post.search",' +
          '"fixedArgs":{"query":"OpenAI Codex","pageSize":5}}')
      );
      expect(currentPosts.status).assertEqual('success');
      expect(currentPostsClient.executedSlugs.length).assertEqual(1);
      expect(currentPostsClient.executedSlugs[0]).assertEqual('TWITTER_RECENT_SEARCH');

      const noMatchClient = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('TWITTER_USER_LOOKUP_ME'), successfulExecutionObservation()
      );
      const noMatch = await callComposioSearchAndExecute(
        noMatchClient, 'search Twitter public posts',
        looseObject('{"operation":"search","fixedToolId":"x.post.search"}')
      );
      const noMatchData: DataResult = xPostStructuredDataResult(noMatch);
      expect(noMatch.status).assertEqual('error');
      expect(noMatch.providerPhase).assertEqual('discovery');
      expect(noMatchClient.executedSlugs.length).assertEqual(0);
      expect(noMatchData.status).assertEqual('error');

      const fallbackClient = new RecordingComposioSearchExecuteClient(
        'Composio gateway returned no executable tool', successfulExecutionObservation()
      );
      const fallback = await callComposioSearchAndExecute(
        fallbackClient, 'search Twitter public posts',
        looseObject('{"operation":"search","fixedToolId":"x.post.search"}')
      );
      expect(fallback.status).assertEqual('error');
      expect(fallback.providerPhase).assertEqual('discovery');
      expect(fallbackClient.executedSlugs.length).assertEqual(0);
      expect(xPostStructuredDataResult(fallback).status).assertEqual('error');

      const postsClient = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('TWITTER_RECENT_SEARCH'),
        '{"data":{"posts":[{"id":"tweet-real-1","text":"real post",' +
          '"url":"https://x.com/openai/status/tweet-real-1"}]}}'
      );
      const posts = await callComposioSearchAndExecute(
        postsClient, 'search Twitter public posts',
        looseObject('{"operation":"search","fixedToolId":"x.post.search"}')
      );
      const postData = xPostStructuredDataResult(posts);
      expect(posts.providerPhase).assertEqual('execution');
      expect(postsClient.executedSlugs.length).assertEqual(1);
      expect(postData.status).assertEqual('success');
      expect(JSON.stringify(postData.data).indexOf('tweet-real-1')).assertLarger(-1);
    });

    it('maps Gmail fixed-tool args into the matched Composio schema', 0, () => {
      expect(composioExactToolSlugForFixedTool('gmail.message.read'))
        .assertEqual('GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID');
      const draftTool = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"to\\":{\\"type\\":\\"array\\"},\\"subject\\":{\\"type\\":\\"string\\"},\\"body\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"},\\"reply_mode\\":{\\"type\\":\\"string\\"}}}"}');
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '创建 Gmail 回复草稿',
        'gmail.draft.apply',
        looseObject('{"to":["alice@example.com"],"subject":"Re: Demo","body":"Got it.","threadId":"thread-123","replyMode":"reply"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(JSON.stringify(draftArgs.to)).assertEqual('["alice@example.com"]');
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.body).assertEqual('Got it.');
      expect(draftArgs.thread_id).assertEqual('thread-123');
      expect(draftArgs.reply_mode).assertEqual('reply');

      const threadTool = composioTool('{"toolSlug":"GMAIL_GET_THREAD","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"threadId\\":{\\"type\\":\\"string\\"}}}"}');
      const threadArgs = composioArgumentsForTool(
        threadTool,
        '读取 Gmail 线程',
        'gmail.thread.read',
        looseObject('{"threadId":"thread-999"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(threadArgs.threadId).assertEqual('thread-999');

      const messageTool = composioTool('{"toolSlug":"GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"format\\":{\\"type\\":\\"string\\"},\\"user_id\\":{\\"type\\":\\"string\\"},\\"message_id\\":{\\"type\\":\\"string\\"}}}"}');
      const messageArgs = composioArgumentsForTool(
        messageTool,
        '读取一封 Gmail 邮件',
        'gmail.message.read',
        looseObject('{"messageId":"message-999"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(messageArgs.message_id).assertEqual('message-999');
      expect(messageArgs.user_id).assertEqual('me');
      expect(messageArgs.format).assertEqual('full');

      const replyTool = composioTool('{"toolSlug":"GMAIL_REPLY_TO_THREAD","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"recipient_email\\":{\\"type\\":\\"string\\"},\\"message_body\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"}}}"}');
      const replyArgs = composioArgumentsForTool(
        replyTool,
        '回复 Gmail 线程',
        'gmail.reply.send',
        looseObject('{"recipientEmail":"alice@example.com","body":"Confirmed.","threadId":"thread-999"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(replyArgs.recipient_email).assertEqual('alice@example.com');
      expect(replyArgs.message_body).assertEqual('Confirmed.');
      expect(replyArgs.thread_id).assertEqual('thread-999');

      const searchTool = composioTool('{"toolSlug":"GMAIL_FETCH_EMAILS","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"query\\":{\\"type\\":\\"string\\"},\\"max_results\\":{\\"type\\":\\"number\\"},\\"include_payload\\":{\\"type\\":\\"boolean\\"},\\"verbose\\":{\\"type\\":\\"boolean\\"}}}"}');
      const searchArgs = composioArgumentsForTool(
        searchTool,
        '帮我查看我Gmail里和我eccv论文相关的邮件',
        'gmail.mail.search',
        looseObject('{"query":"ECCV OR paper OR manuscript OR submission OR review"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(searchArgs.query).assertEqual('ECCV OR paper OR manuscript OR submission OR review');
      expect(searchArgs.max_results).assertEqual(5);
      expect(searchArgs.include_payload).assertFalse();
      expect(searchArgs.verbose).assertTrue();
    });

    it('maps Calendar fixed-tool args into create and update schemas', 0, () => {
      const createTool = composioTool('{"toolSlug":"GOOGLECALENDAR_CREATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"summary\\":{\\"type\\":\\"string\\"},\\"startDateTime\\":{\\"type\\":\\"string\\"},\\"endDateTime\\":{\\"type\\":\\"string\\"},\\"timeZone\\":{\\"type\\":\\"string\\"}}}"}');
      const createArgs = composioArgumentsForTool(
        createTool,
        '创建日程',
        'calendar.event.create',
        looseObject('{"title":"AIPhoneDemo","start":"2026-07-30T15:00:00+08:00","end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(createArgs.summary).assertEqual('AIPhoneDemo');
      expect(createArgs.startDateTime).assertEqual('2026-07-30T15:00:00+08:00');
      expect(createArgs.endDateTime).assertEqual('2026-07-30T15:30:00+08:00');
      expect(createArgs.timeZone).assertEqual('Asia/Shanghai');

      const updateTool = composioTool('{"toolSlug":"GOOGLECALENDAR_UPDATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"event_id\\":{\\"type\\":\\"string\\"},\\"summary\\":{\\"type\\":\\"string\\"},\\"start\\":{\\"type\\":\\"string\\"},\\"end\\":{\\"type\\":\\"string\\"}}}"}');
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '更新日程',
        'calendar.event.update',
        looseObject('{"eventId":"evt-1","title":"AIPhoneDemo sync","start":"2026-07-30T16:00:00+08:00","end":"2026-07-30T16:30:00+08:00"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id).assertEqual('evt-1');
      expect(updateArgs.summary).assertEqual('AIPhoneDemo sync');
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end).assertEqual('2026-07-30T16:30:00+08:00');
    });

    it('uses only canonical Calendar list fields when Composio truncates a large schema', 0, () => {
      const listTool = composioTool('{"toolSlug":"GOOGLECALENDAR_EVENTS_LIST","inputSchema":"{}"}');
      const listArgs = composioArgumentsForTool(
        listTool,
        '查看我 2026年8月4日的 Google Calendar 日程',
        'calendar.events.search',
        looseObject('{"query":"","timeMin":"2026-08-04T00:00:00+08:00","timeMax":"2026-08-05T00:00:00+08:00","timezone":"Asia/Shanghai","calendarId":"primary"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(listArgs.timeMin).assertEqual('2026-08-04T00:00:00+08:00');
      expect(listArgs.timeMax).assertEqual('2026-08-05T00:00:00+08:00');
      expect(listArgs.timeZone).assertEqual('Asia/Shanghai');
      expect(listArgs.calendarId).assertEqual('primary');
      expect(listArgs.singleEvents).assertTrue();
      expect(listArgs.orderBy).assertEqual('startTime');
      expect(listArgs.start === undefined).assertTrue();
      expect(listArgs.end === undefined).assertTrue();
      expect(listArgs.query === undefined).assertTrue();
    });

    it('pins fixed tools to their real Composio slugs', 0, () => {
      expect(composioExactToolSlugForFixedTool('social.x.profile')).assertEqual('TWITTER_USER_LOOKUP_ME');
      expect(composioExactToolSlugForFixedTool('social.x.dm.list')).assertEqual('TWITTER_GET_RECENT_DM_EVENTS');
      expect(composioExactToolSlugForFixedTool('social.slack.message.search')).assertEqual('SLACK_SEARCH_MESSAGES');
      expect(composioExactToolSlugForFixedTool('social.slack.message.send')).assertEqual('SLACK_CHAT_POST_MESSAGE');
      expect(composioExactToolSlugForFixedTool('social.instagram.profile')).assertEqual('INSTAGRAM_GET_USER_INFO');
      expect(composioExactToolSlugForFixedTool('social.instagram.conversations.list')).assertEqual('INSTAGRAM_LIST_ALL_CONVERSATIONS');
      expect(composioExactToolSlugForFixedTool('social.instagram.messages.list')).assertEqual('INSTAGRAM_LIST_ALL_MESSAGES');
      expect(composioExactToolSlugForFixedTool('whatsapp.phone_numbers.list')).assertEqual('WHATSAPP_GET_PHONE_NUMBERS');
      expect(composioExactToolSlugForFixedTool('whatsapp.message.send')).assertEqual('WHATSAPP_SEND_MESSAGE');
      expect(composioExactToolSlugForFixedTool('calendar.events.search')).assertEqual('GOOGLECALENDAR_EVENTS_LIST');
      expect(composioExactToolSlugForFixedTool('calendar.event.create')).assertEqual('GOOGLECALENDAR_CREATE_EVENT');
      expect(composioExactToolSlugForFixedTool('calendar.event.update')).assertEqual('GOOGLECALENDAR_PATCH_EVENT');
      expect(composioExactToolSlugForFixedTool('calendar.event.delete')).assertEqual('GOOGLECALENDAR_DELETE_EVENT');
      expect(composioExactToolSlugForFixedTool('gmail.reply.send')).assertEqual('GMAIL_REPLY_TO_THREAD');
      expect(composioExactToolSlugForFixedTool('gmail.draft.apply')).assertEqual('GMAIL_UPDATE_DRAFT');
      expect(composioExactToolSlugForFixedTool('gmail.message.read')).assertEqual('GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID');
      expect(normalizedComposioUseCase('', 'calendar.event.delete')).assertEqual(
        'Delete a Google Calendar event by event ID');
      expect(normalizedComposioUseCase('', 'gmail.message.read')).assertEqual(
        'Fetch exactly one Gmail email message by its message ID, not the entire thread');
    });

    it('rejects a lone read candidate when Gmail reply discovery omits the exact write tool', 0, async () => {
      const searchObservation = '{"source":"Composio","authorizedToolkits":["gmail"],"tools":[' +
        '{"toolSlug":"GMAIL_GET_THREAD","description":"Read a Gmail thread","inputSchema":"{}"}' +
        '],"instruction":"execute selected tool"}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservation,
        '{"successful":true,"data":{"id":"should-not-execute"}}'
      );

      const result = await callComposioFixedSearchAndExecuteForTest(
        client,
        '回复 Gmail 线程',
        'gmail.reply.send',
        looseObject('{"recipientEmail":"alice@example.com","body":"Confirmed.","threadId":"thread-999"}')
      );

      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('GMAIL_REPLY_TO_THREAD')).assertLarger(-1);
      expect(client.executedSlugs.length).assertEqual(0);
    });

    it('executes only the exact Gmail reply write tool returned by discovery', 0, async () => {
      const searchObservation = '{"source":"Composio","authorizedToolkits":["gmail"],"tools":[' +
        '{"toolSlug":"GMAIL_FETCH_EMAILS","description":"Read Gmail messages","inputSchema":"{}"},' +
        '{"toolSlug":"GMAIL_REPLY_TO_THREAD","description":"Reply to a Gmail thread",' +
        '"inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"recipient_email\\":{\\"type\\":\\"string\\"},' +
        '\\"message_body\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"}}}"}' +
        '],"instruction":"execute selected tool"}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservation,
        '{"successful":true,"data":{"id":"message-1","thread_id":"thread-999"}}'
      );

      const result = await callComposioFixedSearchAndExecuteForTest(
        client,
        '回复 Gmail 线程',
        'gmail.reply.send',
        looseObject('{"recipientEmail":"alice@example.com","body":"Confirmed.","threadId":"thread-999"}')
      );

      expect(result.status).assertEqual('success');
      expect(client.executedSlugs.length).assertEqual(1);
      expect(client.executedSlugs[0]).assertEqual('GMAIL_REPLY_TO_THREAD');
    });

    it('rejects non-update Gmail draft tools for the apply contract', 0, async () => {
      const searchObservation = '{"source":"Composio","authorizedToolkits":["gmail"],"tools":[' +
        '{"toolSlug":"GMAIL_CREATE_DRAFT","description":"Create Gmail draft","inputSchema":"{}"},' +
        '{"toolSlug":"GMAIL_EDIT_DRAFT","description":"Edit Gmail draft","inputSchema":"{}"}' +
        '],"instruction":"execute selected tool"}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservation,
        '{"successful":true,"data":{"draft_id":"draft-1"}}'
      );
      const result = await callComposioFixedSearchAndExecuteForTest(
        client,
        '确认应用刚才的 Gmail 草稿',
        'gmail.draft.apply',
        looseObject('{"draftId":"draft-1","to":["alice@example.com"],"subject":"","body":"我收到了"}')
      );
      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('GMAIL_UPDATE_DRAFT')).assertLarger(-1);
      expect(client.executedSlugs.length).assertEqual(0);
    });

    it('maps WhatsApp and Calendar args to exact provider schemas', 0, () => {
      const phoneNumbersTool = composioTool('{"toolSlug":"WHATSAPP_GET_PHONE_NUMBERS","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"limit\\":{\\"type\\":\\"number\\"},\\"waba_id\\":{\\"type\\":\\"string\\"}}}"}');
      const phoneNumberArgs = composioArgumentsForTool(phoneNumbersTool, 'WhatsApp Business phone numbers', 'whatsapp.phone_numbers.list', looseObject('{"wabaId":"123456789"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(phoneNumberArgs.waba_id).assertEqual('123456789');

      const sendTool = composioTool('{"toolSlug":"WHATSAPP_SEND_MESSAGE","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"phone_number_id\\",\\"to_number\\",\\"text\\"],\\"properties\\":{\\"phone_number_id\\":{\\"type\\":\\"string\\"},\\"to_number\\":{\\"type\\":\\"string\\"},\\"text\\":{\\"type\\":\\"string\\"},\\"preview_url\\":{\\"type\\":\\"boolean\\"}}}"}');
      const sendArgs = composioArgumentsForTool(sendTool, 'WhatsApp Business send', 'whatsapp.message.send', looseObject('{"phoneNumberId":"712594308615206","toNumber":"8613800138000","text":"十分钟后到","previewUrl":false}')) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(sendArgs.phone_number_id).assertEqual('712594308615206');
      expect(sendArgs.to_number).assertEqual('8613800138000');
      expect(sendArgs.text).assertEqual('十分钟后到');
      expect(sendArgs.preview_url).assertFalse();

      const slackSendTool = composioTool('{"toolSlug":"SLACK_CHAT_POST_MESSAGE","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"channel\\",\\"text\\"],\\"properties\\":{\\"channel\\":{\\"type\\":\\"string\\"},\\"text\\":{\\"type\\":\\"string\\"},\\"thread_ts\\":{\\"type\\":\\"string\\"}}}"}');
      const slackSendArgs = composioArgumentsForTool(slackSendTool, '回复 Slack 消息', 'social.slack.message.send', looseObject('{"channel":"D123","text":"已确认","threadTs":"1784250000.000100"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(slackSendArgs.channel).assertEqual('D123');
      expect(slackSendArgs.text).assertEqual('已确认');
      expect(slackSendArgs.thread_ts).assertEqual('1784250000.000100');

      const createTool = composioTool('{"toolSlug":"GOOGLECALENDAR_CREATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"start_datetime\\"],\\"properties\\":{\\"summary\\":{\\"type\\":\\"string\\"},\\"start_datetime\\":{\\"type\\":\\"string\\"},\\"end_datetime\\":{\\"type\\":\\"string\\"},\\"timezone\\":{\\"type\\":\\"string\\"},\\"calendar_id\\":{\\"type\\":\\"string\\"}}}"}');
      const createArgs = composioArgumentsForTool(createTool, '创建日程', 'calendar.event.create', looseObject('{"title":"AIPhoneDemo","start":"2026-07-30T15:00:00+08:00","end":"2026-07-30T15:30:00+08:00","timezone":"Asia/Shanghai","calendarId":"primary"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(createArgs.start_datetime).assertEqual('2026-07-30T15:00:00+08:00');
      expect(createArgs.end_datetime).assertEqual('2026-07-30T15:30:00+08:00');

      const deleteTool = composioTool('{"toolSlug":"GOOGLECALENDAR_DELETE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"event_id\\"],\\"properties\\":{\\"event_id\\":{\\"type\\":\\"string\\"},\\"calendar_id\\":{\\"type\\":\\"string\\"},\\"send_updates\\":{\\"type\\":\\"string\\"}}}"}');
      const deleteArgs = composioArgumentsForTool(deleteTool, '删除日程', 'calendar.event.delete', looseObject('{"eventId":"evt-1","calendarId":"primary","sendUpdates":"none"}')) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(deleteArgs.event_id).assertEqual('evt-1');
      expect(deleteArgs.calendar_id).assertEqual('primary');
      expect(deleteArgs.send_updates).assertEqual('none');
    });

    it('extracts only unambiguous WhatsApp phone number ids', 0, () => {
      expect(composioPhoneNumberIdsFromObservation('{"data":{"items":[]}}').length).assertEqual(0);
      expect(composioPhoneNumberIdsFromObservation('{"data":{"items":[{"id":"712594308615206"}]}}')[0]).assertEqual('712594308615206');
      expect(composioPhoneNumberIdsFromObservation('{"data":{"items":[{"id":"1"},{"id":"2"}]}}').length).assertEqual(2);
      expect(composioPhoneNumberIdsFromObservation('not-json').length).assertEqual(0);
    });

    it('uses a bounded Slack query for default recent-message SocialHub prompts', 0, () => {
      const searchTool = composioTool('{"toolSlug":"SLACK_SEARCH_MESSAGES","inputSchema":"{\\"type\\":\\"object\\",\\"properties\\":{\\"query\\":{\\"type\\":\\"string\\"},\\"sort\\":{\\"type\\":\\"string\\"},\\"count\\":{\\"type\\":\\"number\\"}}}"}');
      const args = composioArgumentsForTool(
        searchTool,
        '帮我用 Composio Slack 查最近30天所有已授权应用收到的私信消息',
        '',
        null
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(slackSearchQueryForPrompt('帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息')).assertEqual('AIPhoneDemo');
      expect((args.query as string).indexOf('after:')).assertEqual(0);
      expect(args.sort).assertEqual('timestamp');
      expect(args.count).assertEqual(5);
    });

    it('does not invent opaque provider ids from a natural-language read request', 0, () => {
      const historyTool = composioTool('{"toolSlug":"WHATSAPP_GET_MESSAGE_HISTORY","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"phone_number_id\\"],\\"properties\\":{\\"phone_number_id\\":{\\"type\\":\\"string\\"},\\"limit\\":{\\"type\\":\\"number\\"}}}"}');
      const args = composioArgumentsForTool(
        historyTool,
        '帮我用 WhatsApp 查看我最近的消息',
        '',
        null
      ) as Record<string, Object | string | number | boolean | null | undefined>;

      expect(args.phone_number_id === undefined).assertTrue();
      expect(args.limit).assertEqual(5);
    });

    it('keeps Composio Gmail execute previews compact and parseable', 0, () => {
      const headers: TestComposioHeader[] = [{ name: 'X-Large', value: 'x'.repeat(20000) }];
      const messages: TestComposioMessage[] = [{
        threadId: 'thread-1',
        messageId: 'message-1',
        sender: 'OpenReview <noreply@openreview.net>',
        subject: '[ECCV 2026] Paper Decision Notification',
        messageText: 'ECCV decision '.repeat(2000),
        payload: { headers: headers }
      }];
      const payload: TestComposioObservation = {
        data: {
          messages: messages
        },
        error: null
      };
      const observation = JSON.stringify(payload);
      const result = composioDynamicResultFromObservation('execute', observation, 'GMAIL_FETCH_EMAILS', 'Gmail ECCV');
      const preview = JSON.parse(result.rawPreview) as Record<string, Object[]>;

      expect(result.status).assertEqual('success');
      expect(result.providerData === undefined).assertTrue();
      expect(preview.messages.length).assertEqual(1);
      expect(JSON.stringify(preview).indexOf('[ECCV 2026]')).assertLarger(-1);
      expect(result.rawPreview.length).assertLess(16000);
    });

    it('does not synthesize missing fixed write args from prompt text', 0, () => {
      const draftTool = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"body\\"],\\"properties\\":{\\"body\\":{\\"type\\":\\"string\\"},\\"subject\\":{\\"type\\":\\"string\\"},\\"thread_id\\":{\\"type\\":\\"string\\"}}}"}');
      const draftArgs = composioArgumentsForTool(
        draftTool,
        '帮我给 Alice 写 Gmail 草稿说我收到了',
        'gmail.draft.create',
        looseObject('{"subject":"Re: Demo"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(draftArgs.body === undefined).assertTrue();
      expect(draftArgs.subject).assertEqual('Re: Demo');
      expect(draftArgs.thread_id === undefined).assertTrue();

      const updateTool = composioTool('{"toolSlug":"GOOGLECALENDAR_UPDATE_EVENT","inputSchema":"{\\"type\\":\\"object\\",\\"required\\":[\\"event_id\\",\\"summary\\"],\\"properties\\":{\\"event_id\\":{\\"type\\":\\"string\\"},\\"summary\\":{\\"type\\":\\"string\\"},\\"start\\":{\\"type\\":\\"string\\"},\\"end\\":{\\"type\\":\\"string\\"}}}"}');
      const updateArgs = composioArgumentsForTool(
        updateTool,
        '把刚才的日程改到下午四点',
        'calendar.event.update',
        looseObject('{"start":"2026-07-30T16:00:00+08:00"}')
      ) as Record<string, Object | string | number | boolean | null | undefined>;
      expect(updateArgs.event_id === undefined).assertTrue();
      expect(updateArgs.summary === undefined).assertTrue();
      expect(updateArgs.start).assertEqual('2026-07-30T16:00:00+08:00');
      expect(updateArgs.end === undefined).assertTrue();
    });

    it('returns fixed-tool missing-args errors before Composio auth/config checks', 0, async () => {
      try {
        configureComposioConfigFromRawJson('{}');
        const createResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.create","fixedArgs":{"body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(createResult.toolName).assertEqual('gmail.draft.create');
        expect(createResult.status).assertEqual('error');
        expect(createResult.summary.indexOf('to')).assertLarger(-1);
        expect(createResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(createResult.rows).indexOf('gmail.draft.create')).assertLarger(-1);

        const emptyRecipientResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.create","fixedArgs":{"to":[""],"body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(emptyRecipientResult.toolName).assertEqual('gmail.draft.create');
        expect(emptyRecipientResult.status).assertEqual('error');
        expect(emptyRecipientResult.summary.indexOf('to')).assertLarger(-1);
        expect(emptyRecipientResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(emptyRecipientResult.rows).indexOf('gmail.draft.create')).assertLarger(-1);

        const blankRecipientResult = await callComposioDynamic(
          '确认应用刚才的 Gmail 草稿',
          looseObject('{"fixedToolId":"gmail.draft.apply","fixedArgs":{"draftId":"draft-123",' +
            '"to":["   "],"subject":"Re: Demo","body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(blankRecipientResult.toolName).assertEqual('gmail.draft.apply');
        expect(blankRecipientResult.status).assertEqual('error');
        expect(blankRecipientResult.summary.indexOf('to')).assertLarger(-1);
        expect(blankRecipientResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(blankRecipientResult.rows).indexOf('gmail.draft.apply')).assertLarger(-1);

        const draftResult = await callComposioDynamic(
          '帮我给 Alice 写 Gmail 草稿说我收到了',
          looseObject('{"fixedToolId":"gmail.draft.apply","fixedArgs":{"to":["alice@example.com"],' +
            '"subject":"Re: Demo","body":"Got it."}}')
        ) as DynamicGenericToolResult;
        expect(draftResult.toolName).assertEqual('gmail.draft.apply');
        expect(draftResult.status).assertEqual('error');
        expect(draftResult.summary.indexOf('draftId')).assertLarger(-1);
        expect(draftResult.summary.indexOf('Composio 未配置')).assertEqual(-1);
        expect(JSON.stringify(draftResult.rows).indexOf('Missing')).assertLarger(-1);

        const calendarResult = await callComposioDynamic(
          '把刚才的日程改到下午四点',
          looseObject('{"fixedToolId":"calendar.event.update","fixedArgs":{}}')
        ) as DynamicGenericToolResult;
        expect(calendarResult.toolName).assertEqual('calendar.event.update');
        expect(calendarResult.status).assertEqual('error');
        expect(calendarResult.summary.indexOf('eventId')).assertLarger(-1);
        expect(calendarResult.summary.indexOf('title/start/end')).assertLarger(-1);
      } finally {
        configureComposioConfigFromRawJson('{}');
      }
    });

    it('keeps read/search fixed tools below side-effect Composio matches', 0, () => {
      const calendarRead = composioTool('{"toolSlug":"GOOGLECALENDAR_LIST_EVENTS","description":"List events"}');
      const calendarCreate = composioTool('{"toolSlug":"GOOGLECALENDAR_CREATE_EVENT","description":"Create event"}');
      expect(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarRead, 'calendar.events.search'))
        .assertLarger(composioPreferredToolScore('帮我看今天的 Google Calendar 日程', calendarCreate, 'calendar.events.search'));

      const gmailRead = composioTool('{"toolSlug":"GMAIL_GET_THREAD","description":"Read Gmail thread"}');
      const gmailMessageRead = composioTool('{"toolSlug":"GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID","description":"Fetch one Gmail message by message ID"}');
      const gmailThreadRead = composioTool('{"toolSlug":"GMAIL_FETCH_MESSAGE_BY_THREAD_ID","description":"Fetch Message by Thread ID"}');
      const gmailReply = composioTool('{"toolSlug":"GMAIL_REPLY_TO_THREAD","description":"Reply to Gmail thread"}');
      const gmailDraft = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","description":"Create Gmail draft"}');
      const gmailEmails = composioTool('{"toolSlug":"GMAIL_FETCH_EMAILS","description":"Fetch Gmail emails"}');
      const gmailThreads = composioTool('{"toolSlug":"GMAIL_LIST_THREADS","description":"List Gmail threads"}');
      const gmailPeople = composioTool('{"toolSlug":"GMAIL_SEARCH_PEOPLE","description":"Search Gmail people and contacts"}');
      expect(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailRead, 'gmail.thread.read'))
        .assertLarger(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailDraft, 'gmail.thread.read'));
      expect(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailThreadRead, 'gmail.thread.read'))
        .assertLarger(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailEmails, 'gmail.thread.read'));
      expect(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailMessageRead, 'gmail.message.read'))
        .assertLarger(composioPreferredToolScore('帮我读取这封 Gmail 邮件', gmailThreadRead, 'gmail.message.read'));
      expect(composioPreferredToolScore('回复这封 Gmail 邮件', gmailReply, 'gmail.reply.send'))
        .assertLarger(composioPreferredToolScore('回复这封 Gmail 邮件', gmailDraft, 'gmail.reply.send'));
      expect(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailEmails, 'gmail.mail.search'))
        .assertLarger(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailThreads, 'gmail.mail.search'));
      expect(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailEmails, 'gmail.mail.search'))
        .assertLarger(composioPreferredToolScore('帮我查看我Gmail里和我eccv论文相关的邮件', gmailPeople, 'gmail.mail.search'));

      const playlistList = composioTool('{"toolSlug":"YOUTUBE_LIST_USER_PLAYLISTS","description":"List user playlists"}');
      const playlistItems = composioTool('{"toolSlug":"YOUTUBE_LIST_PLAYLIST_ITEMS","description":"List playlist items"}');
      expect(composioPreferredToolScore('帮我查看我的 YouTube 播放列表', playlistList, 'youtube.mine.playlists'))
        .assertLarger(composioPreferredToolScore('帮我查看我的 YouTube 播放列表', playlistItems, 'youtube.mine.playlists'));
    });

    it('prefers safe Gmail draft slugs over send or delete draft slugs', 0, () => {
      const createDraft = composioTool('{"toolSlug":"GMAIL_CREATE_DRAFT","description":"Create Gmail draft"}');
      const updateDraft = composioTool('{"toolSlug":"GMAIL_UPDATE_DRAFT","description":"Update Gmail draft"}');
      const editDraft = composioTool('{"toolSlug":"GMAIL_EDIT_DRAFT","description":"Edit Gmail draft"}');
      const applyDraft = composioTool('{"toolSlug":"GMAIL_APPLY_DRAFT","description":"Apply Gmail draft"}');
      const sendDraft = composioTool('{"toolSlug":"GMAIL_SEND_DRAFT","description":"Send Gmail draft"}');
      const deleteDraft = composioTool('{"toolSlug":"GMAIL_DELETE_DRAFT","description":"Delete Gmail draft"}');

      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', sendDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', deleteDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', updateDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', editDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('创建 Gmail 回复草稿', createDraft, 'gmail.draft.create'))
        .assertLarger(composioPreferredToolScore('创建 Gmail 回复草稿', applyDraft, 'gmail.draft.create'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', updateDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', sendDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', updateDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', createDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', updateDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', editDraft, 'gmail.draft.apply'));
      expect(composioPreferredToolScore('应用 Gmail 回复草稿', updateDraft, 'gmail.draft.apply'))
        .assertLarger(composioPreferredToolScore('应用 Gmail 回复草稿', applyDraft, 'gmail.draft.apply'));
    });

    it('keeps configured app user id for Composio dynamic calls', 0, () => {
      configureComposioUserId('aiphone-user-device-1');
      expect(currentComposioUserId()).assertEqual('aiphone-user-device-1');
    });

    it('uses raw Composio config without forcing a proxy', 0, () => {
      configureComposioConfigFromRawJson('{"apiKey":"ak_test","baseUrl":"https://backend.composio.dev/api/v3.1","userId":"aiphone-luoyige"}');
      configureComposioUserId('');

      expect(currentComposioUserId()).assertEqual('aiphone-luoyige');
      expect(currentComposioConfig().apiKey).assertEqual('ak_test');
      expect(currentComposioConfig().proxyBaseUrl).assertEqual('');
    });

    it('keeps generic dynamic.search fallback eligible once Composio is configured', 0, () => {
      expect(isComposioDynamicPrompt('帮我查最近重要邮件')).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', false)).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我查最近重要邮件', '', true)).assertFalse();
      expect(shouldAttemptComposioDynamic('随便什么都行', 'execute', false)).assertFalse();
      expect(shouldAttemptComposioDynamic('帮我在 GitHub 里找 Appless-Phone 最近的 pr', 'execute', false)).assertTrue();
    });

    it('maps proxy auth configs to executable toolkit accounts only', 0, () => {
      const payload = JSON.parse('{"ok":true,"userId":"app-user-1","items":[{"authConfigId":"ac_1","toolkitSlug":"github","status":"connected","connectedAccountId":"ca_1","canExecute":true},{"authConfigId":"ac_2","toolkitSlug":"slack","status":"connected","connectedAccountId":"ca_2","canExecute":false},{"authConfigId":"ac_3","toolkitSlug":"notion","status":"needs_auth","connectedAccountId":"ca_3","canExecute":true},{"authConfigId":"ac_4","toolkitSlug":"discord","status":"connected","canExecute":true}]}') as Object;
      const accounts: Record<string, string> = proxyToolkitAccountsPreview(payload, ['github', 'slack', 'notion', 'discord']);

      expect(accounts['github']).assertEqual('ca_1');
      expect(Object.keys(accounts).length).assertEqual(1);
    });

    it('maps a Composio search observation to a generic result', 0, () => {
      const observation = '{"source":"Composio","authorizedToolkits":["notion"],"tools":[{"toolSlug":"NOTION_SEARCH","description":"Search pages","inputSchema":"{}"}],"instruction":"Choose one returned toolSlug"}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation('search', observation);

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('dynamic.search');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('NOTION_SEARCH')).assertLarger(-1);
      expect(result.rawPreview.indexOf('authorizedToolkits')).assertLarger(-1);
    });

    it('maps a Composio execute observation to display rows', 0, () => {
      const observation = '{"data":{"pull_requests":[{"number":39,"title":"Add Composio dynamic backend","state":"merged","html_url":"https://github.com/XiaoLuoLYG/Appless-Phone/pull/39","author":{"login":"XiaoLuoLYG"},"updated_at":"2026-07-06T09:00:00Z"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GITHUB_FIND_PULL_REQUESTS',
        '帮我在 GitHub 里找 Appless-Phone 最近的 pr'
      );

      expect(result.sourceTag).assertEqual('Composio');
      expect(result.toolName).assertEqual('GITHUB_FIND_PULL_REQUESTS');
      expect(result.title).assertEqual('Composio GitHub 结果');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Add Composio dynamic backend')).assertLarger(-1);
    });

    it('normalizes GitHub push star release issue comment and unknown events only for UI Lab', 0, () => {
      const observation = '{"data":{"events":[' +
        '{"type":"PushEvent","public":false,"created_at":"2026-08-04T00:58:39Z",' +
        '"repo":{"id":7,"name":"xojs/eslint-config-xo"},' +
        '"actor":{"id":8,"login":"sindresorhus","avatar_url":"https://avatar"},' +
        '"payload":{"ref":"refs/heads/main","distinct_size":2,"commits":[' +
        '{"sha":"abc123","message":"fix parser"},{"sha":"def456","message":"add tests"}]}}' +
        ',{"type":"WatchEvent","public":true,"created_at":"2026-08-04T01:00:00Z",' +
        '"repo":{"name":"thesysdev/openui"},"payload":{"action":"started"}}' +
        ',{"type":"ReleaseEvent","created_at":"2026-08-04T02:00:00Z",' +
        '"repo":{"name":"xojs/eslint-config-xo"},"payload":{"action":"published",' +
        '"release":{"tag_name":"v1.0.0","name":"First release","html_url":"https://github.com/x/r/1"}}}' +
        ',{"type":"IssuesEvent","created_at":"2026-08-04T03:00:00Z",' +
        '"repo":{"name":"owner/issues"},"payload":{"action":"closed",' +
        '"issue":{"number":12,"title":"Bug","state":"closed","html_url":"https://github.com/i/12"}}}' +
        ',{"type":"IssueCommentEvent","created_at":"2026-08-04T04:00:00Z",' +
        '"repo":{"name":"owner/comments"},"payload":{"action":"created",' +
        '"issue":{"number":13,"title":"Question"},"comment":{"body":"large raw body","html_url":"https://github.com/c/13"}}}' +
        ',{"type":"MysteryEvent","created_at":"2026-08-04T05:00:00Z",' +
        '"repo":{"name":"owner/mystery"},"payload":{"action":"moved","secret":"do-not-show"}}]}}';
      const legacy = composioDynamicResultFromObservation(
        'execute', observation, 'GITHUB_LIST_EVENTS_FOR_USER', 'GitHub user activity'
      );
      const preserved = composioDynamicResultFromObservation(
        'execute', observation, 'GITHUB_LIST_EVENTS_FOR_USER', 'GitHub user activity', true
      );
      const provider = preserved.providerData as Record<string, Object>;
      const events = provider['events'] as Object[];
      const push = events[0] as Record<string, Object | string>;
      const pushDetails = push['details'] as Record<string, Object | string | number>;
      const star = events[1] as Record<string, Object | string>;
      const release = events[2] as Record<string, Object | string>;
      const issue = events[3] as Record<string, Object | string>;
      const comment = events[4] as Record<string, Object | string>;
      const fallback = events[5] as Record<string, Object | string>;
      const metadata = provider['metadata'] as Record<string, Object | string | boolean>;

      expect(legacy.providerData === undefined).assertTrue();
      expect(preserved.providerData === undefined).assertFalse();
      expect(provider['count'] as number).assertEqual(6);
      expect(metadata['schemaVersion']).assertEqual('github-user-events.v1');
      expect(push['kind']).assertEqual('push');
      expect(push['visibility']).assertEqual('private');
      expect(push['title']).assertEqual('更新了 xojs/eslint-config-xo');
      expect(push['summary']).assertContain('main 分支推送了 2 个提交');
      expect(pushDetails['commitCount']).assertEqual(2);
      expect(star['kind']).assertEqual('star');
      expect(star['visibility']).assertEqual('public');
      expect(star['summary']).assertContain('点了 Star');
      expect(release['kind']).assertEqual('release');
      expect(release['visibility']).assertEqual('unknown');
      expect(release['title']).assertContain('v1.0.0');
      expect(issue['kind']).assertEqual('issue');
      expect(issue['title']).assertContain('关闭了');
      expect(comment['kind']).assertEqual('issue_comment');
      expect(comment['title']).assertContain('Issue #13');
      expect(fallback['kind']).assertEqual('other');
      expect(fallback['summary']).assertContain('MysteryEvent');
      expect(JSON.stringify(preserved.providerData).indexOf('结果 1')).assertEqual(-1);
      expect(JSON.stringify(preserved.providerData).indexOf('sindresorhus')).assertEqual(-1);
      expect(JSON.stringify(preserved.providerData).indexOf('abc123')).assertEqual(-1);
      expect(JSON.stringify(preserved.providerData).indexOf('large raw body')).assertEqual(-1);
      expect(JSON.stringify(preserved.providerData).indexOf('do-not-show')).assertEqual(-1);
      expect(JSON.stringify(legacy.rows).indexOf('结果 1')).assertLarger(-1);
    });

    it('distinguishes pull request issue comments and maps secondary GitHub event families', 0, () => {
      const observation = '{"data":{"events":[' +
        '{"type":"IssueCommentEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"edited","issue":{"number":8,"pull_request":{"url":"api"}},' +
        '"comment":{"html_url":"comment"}}}' +
        ',{"type":"PullRequestReviewEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"submitted","pull_request":{"number":9,"title":"PR","html_url":"pr"},' +
        '"review":{"state":"approved","html_url":"review"}}}' +
        ',{"type":"PullRequestReviewCommentEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"deleted","pull_request":{"number":9},' +
        '"comment":{"html_url":"review-comment"}}}' +
        ',{"type":"CommitCommentEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"comment":{"commit_id":"secret-sha","html_url":"commit-comment","body":"raw body"}}}' +
        ',{"type":"DeleteEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"ref_type":"branch","ref":"old"}}' +
        ',{"type":"DiscussionEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"created","discussion":{"number":2,"title":"Ideas","html_url":"discussion"}}}' +
        ',{"type":"GollumEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"pages":[{"title":"Home","sha":"wiki-sha"}]}}' +
        ',{"type":"MemberEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"added","member":{"login":"alice","avatar_url":"avatar"}}}' +
        ',{"type":"PublicEvent","repo":{"name":"o/r"},"created_at":"2026-08-04","payload":{}}' +
        ',{"type":"WatchEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"stopped"}}' +
        ',{"type":"PullRequestEvent","repo":{"name":"o/r"},"created_at":"2026-08-04",' +
        '"payload":{"action":"closed","number":10,"pull_request":{"number":10,"merged":true}}}]}}';
      const provider = composioProviderDataFromObservation(
        observation, 'GITHUB_LIST_EVENTS_FOR_USER'
      ) as Record<string, Object>;
      const events = provider['events'] as Array<Record<string, Object | string>>;
      const encoded = JSON.stringify(provider);

      expect(events[0]['kind']).assertEqual('pull_request_comment');
      expect(events[1]['kind']).assertEqual('pull_request_review');
      expect(events[2]['kind']).assertEqual('pull_request_review_comment');
      expect(events[3]['kind']).assertEqual('commit_comment');
      expect(events[4]['kind']).assertEqual('delete');
      expect(events[5]['kind']).assertEqual('discussion');
      expect(events[6]['kind']).assertEqual('wiki');
      expect(events[7]['kind']).assertEqual('member');
      expect(events[8]['kind']).assertEqual('public');
      expect(events[0]['title']).assertContain('编辑了评论');
      expect(events[2]['title']).assertContain('删除了评论');
      expect(events[9]['kind']).assertEqual('other');
      expect(events[9]['summary']).assertContain('WatchEvent');
      expect(events[10]['kind']).assertEqual('pull_request');
      expect(events[10]['title']).assertContain('合并了');
      expect((events[10]['title'] as string).indexOf('关闭了')).assertEqual(-1);
      expect(encoded.indexOf('secret-sha')).assertEqual(-1);
      expect(encoded.indexOf('raw body')).assertEqual(-1);
      expect(encoded.indexOf('wiki-sha')).assertEqual(-1);
      expect(encoded.indexOf('avatar')).assertEqual(-1);
    });

    it('publishes the normalized GitHub events output contract and accepts a direct event array', 0, () => {
      const schema = githubUserEventsNormalizedOutputSchema();
      const normalized = composioProviderDataFromObservation(
        '{"data":[{"type":"WatchEvent","repo":{"name":"owner/repo"},' +
        '"created_at":"2026-08-05T00:00:00Z","payload":{"action":"started"}}]}',
        'GITHUB_LIST_EVENTS_FOR_USER'
      ) as Record<string, Object | number>;
      const events = normalized['events'] as Array<Record<string, Object | string>>;

      expect(JSON.stringify(schema)).assertContain('WatchEvent=star');
      expect(JSON.stringify(schema)).assertContain('not an all-time total');
      expect(JSON.stringify(schema)).assertContain('visibility');
      expect(normalized['count'] as number).assertEqual(1);
      expect(events[0]['kind']).assertEqual('star');
      expect(events[0]['title']).assertContain('owner/repo');
    });

    it('keeps the provider output schema unchanged on the legacy dynamic execution path', 0, async () => {
      const rawOutputSchema = '{"type":"object","properties":{"events":{' +
        '"type":"array","description":"raw-provider-schema"}}}';
      const client = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('GITHUB_LIST_EVENTS_FOR_USER', '{}', rawOutputSchema),
        '{"data":{"events":[{"type":"PushEvent","public":false,"repo":{"name":"private/repo"}}]}}'
      );
      const result = await callComposioSearchAndExecute(
        client, 'GitHub user events', looseObject('{"query":"sindresorhus"}')
      );
      const registration = result.registration as DynamicRegistrationMetadata;
      const encoded = JSON.stringify(registration.outputSchema);

      expect(encoded).assertContain('raw-provider-schema');
      expect(encoded.indexOf('github-user-events.v1')).assertEqual(-1);
      expect(result.providerData === undefined).assertTrue();
    });

    it('preserves common provider arrays and strings while redacting binary blobs', 0, () => {
      const entries: Object[] = [];
      entries.push(JSON.parse('{"name":"first","description":' + JSON.stringify('ordinary description '.repeat(200)) +
        ',"blob":' + JSON.stringify('A'.repeat(4000)) + '}') as Object);
      for (let index = 1; index < 140; index++) {
        entries.push(JSON.parse('{"name":"item-' + index.toString() + '","value":' + index.toString() + '}') as Object);
      }
      const observation = '{"data":{"response_data":{"data":{"events":' +
        JSON.stringify(entries) + '},"logs":[{"blob":' + JSON.stringify('B'.repeat(4000)) + '}]}},' +
        '"error":null}';
      const preserved = composioDynamicResultFromObservation(
        'execute', observation, 'GITHUB_LIST_REPOSITORIES_FOR_A_USER', 'GitHub repositories', true
      );
      const provider = preserved.providerData as Record<string, Object>;
      const meta = preserved.providerDataMeta as Record<string, Object | string | number | boolean>;
      const events = provider['events'] as Object[];
      const first = events[0] as Record<string, Object | string>;

      expect(events.length).assertEqual(140);
      expect(meta['truncated']).assertFalse();
      expect((first['description'] as string).length).assertEqual(4200);
      expect(first['blob']).assertEqual('[omitted binary data]');
      expect(JSON.stringify(provider).indexOf('logs')).assertEqual(-1);
      expect(JSON.stringify(provider).length).assertLess(64001);
    });

    it('marks providerData metadata when a hard structural limit truncates content', 0, () => {
      const items: Object[] = [];
      for (let index = 0; index < 1100; index++) {
        items.push(JSON.parse('{"name":"item-' + index.toString() + '"}') as Object);
      }
      const observation = '{"data":{"items":' + JSON.stringify(items) + '}}';
      const preserved = composioDynamicResultFromObservation(
        'execute', observation, 'GITHUB_GET_A_USER', 'GitHub profile', true
      );
      const meta = preserved.providerDataMeta as Record<string, Object | string | number | boolean>;
      const provider = preserved.providerData as Record<string, Object>;
      const arrays = meta['arrays'] as Object[];
      const firstArray = arrays[0] as Record<string, Object | string | number>;

      expect(meta['truncated']).assertTrue();
      expect(meta['reason']).assertEqual('provider_data_array_limit');
      expect((provider['items'] as Object[]).length).assertEqual(1000);
      expect(firstArray['originalCount']).assertEqual(1100);
      expect(firstArray['retainedCount']).assertEqual(1000);
    });

    it('keeps structured UI Lab data from a response larger than the legacy 200K observation limit', 0, () => {
      const raw = '{"data":{"events":[{"type":"PushEvent","repo":{"name":"openui"},' +
        '"actor":{"login":"developer"}}],"binary":' + JSON.stringify('A'.repeat(210000)) + '},' +
        '"error":null}';
      const legacy = limitComposioObservation(raw);
      const legacyEnvelope = JSON.parse(legacy) as Record<string, Object | string | boolean>;
      const preserved = preservedComposioExecutionFromResponse(raw);
      const provider = preserved.providerData as Record<string, Object>;
      const events = provider['events'] as Object[];

      expect(raw.length).assertLarger(200000);
      expect(legacyEnvelope['truncated']).assertTrue();
      expect(preserved.observation).assertEqual(legacy);
      expect(events.length).assertEqual(1);
      expect(JSON.stringify(events[0])).assertContain('PushEvent');
      expect(JSON.stringify(provider).indexOf('AAAAAA')).assertEqual(-1);
      expect(preserved.providerDataMeta.truncated).assertFalse();
      expect(preserved.providerDataMeta.redactedBinaryFields).assertEqual(1);
    });

    it('recursively removes normalized credential keys while preserving ordinary business content', 0, () => {
      const observation = '{"data":{"messages":[{"subject":"Quarterly update",' +
        '"body":"ordinary mail body","access_token":"short-access","refresh-token":"short-refresh",' +
        '"apiKey":"short-api","xApiKey":"short-x-api","X-API-Key":"short-header-api",' +
        '"Authorization":"Bearer short-auth","cookie":"sid=short-cookie",' +
        '"set_cookie":"short-set-cookie","password":"short-password","passwd":"short-passwd",' +
        '"client_secret":"short-client-secret","private-key":"short-private-key",' +
        '"credential":"short-credential","auth_token":"short-auth-token","jwt":"short-jwt",' +
        '"idToken":"short-id-token","nextPageToken":"next-page-2","pageToken":"page-3","token_count":17,' +
        '"auth":"Bearer short-auth-field","headerValue":"Bearer short-header-value",' +
        '"session_id":"short-session","signature":"short-signature","signing_key":"short-signing",' +
        '"nested":{"bearer":"short-bearer","sender":"alice@example.com",' +
        '"auth":{"method":"oauth2","account":"alice","accessToken":"nested-access",' +
        '"Authorization":"Bearer nested-auth"}}}]}}';
      const provider = composioProviderDataFromObservation(observation) as Record<string, Object>;
      const encoded = JSON.stringify(provider);

      expect(encoded).assertContain('Quarterly update');
      expect(encoded).assertContain('ordinary mail body');
      expect(encoded).assertContain('alice@example.com');
      expect(encoded.indexOf('short-access')).assertEqual(-1);
      expect(encoded.indexOf('short-refresh')).assertEqual(-1);
      expect(encoded.indexOf('short-api')).assertEqual(-1);
      expect(encoded.indexOf('short-x-api')).assertEqual(-1);
      expect(encoded.indexOf('short-header-api')).assertEqual(-1);
      expect(encoded.indexOf('short-cookie')).assertEqual(-1);
      expect(encoded.indexOf('short-password')).assertEqual(-1);
      expect(encoded.indexOf('short-client-secret')).assertEqual(-1);
      expect(encoded.indexOf('short-auth-token')).assertEqual(-1);
      expect(encoded.indexOf('short-jwt')).assertEqual(-1);
      expect(encoded.indexOf('short-auth-field')).assertEqual(-1);
      expect(encoded.indexOf('short-header-value')).assertEqual(-1);
      expect(encoded.indexOf('short-session')).assertEqual(-1);
      expect(encoded.indexOf('short-signature')).assertEqual(-1);
      expect(encoded.indexOf('short-bearer')).assertEqual(-1);
      expect(encoded.indexOf('nested-access')).assertEqual(-1);
      expect(encoded.indexOf('nested-auth')).assertEqual(-1);
      expect(encoded).assertContain('next-page-2');
      expect(encoded).assertContain('page-3');
      expect(encoded).assertContain('"token_count":17');
      expect(encoded).assertContain('"method":"oauth2"');
      expect(encoded).assertContain('"account":"alice"');
    });

    it('treats Gmail draft payloads with draft ids as successful execute results', 0, () => {
      const observation = '{"data":{' +
        '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-client-1",' +
        '"id":"draft-client-1","message":{' +
        '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-client-1",' +
        '"id":"message-client-1","labelIds":["DRAFT"],"threadId":"thread-client-1"}},' +
        '"error":null,"log_id":"log-client-1"}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 回复草稿'
      );
      const jsonl = gmailDraftPreviewA2ui(
        'gmail_client_response_surface',
        result,
        looseObject('{"to":["alice@example.com"],"subject":"Re: Demo","body":"我收到了"}'),
        'gmail.draft.create'
      );

      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('GMAIL_CREATE_EMAIL_DRAFT')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf(
        '"label":"Draft ID","value":"draft-client-1"'
      )).assertLarger(-1);
      expect(result.rawPreview).assertEqual('{"draft_id":"draft-client-1"}');
      expect(jsonl.indexOf('"id":"gmail.draft.apply"')).assertLarger(-1);
      expect(jsonl.indexOf('"draftId":"draft-client-1"')).assertLarger(-1);
    });

    it('preserves only nested Gmail draft identity across unrelated provider arrays', 0, () => {
      const observation = '{"successful":true,"data":{"response_data":{"data":{' +
        '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-provider-nested-1",' +
        '"id":"draft-provider-nested-1","message":{' +
        '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-provider-nested-1",' +
        '"id":"message-provider-nested-1","labelIds":["DRAFT"],' +
        '"threadId":"thread-provider-nested-1"}},' +
        '"logs":[{"title":"private log title","text":"private log text","body":"private log body"}]}},"error":null}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 草稿'
      );
      const unrelated: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'NOTION_CREATE_DRAFT',
        '创建 Notion 草稿'
      );
      const messageThreadEvidence: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"successful":true,"data":{"response_data":{"data":{"id":"draft-message-thread-1",' +
          '"message":{"id":"message-thread-1","threadId":"thread-evidence-1"},' +
          '"headers":[{"title":"private header title","text":"private header text",' +
          '"body":"private header body"}]}}},"error":null}',
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 草稿'
      );
      const legacy: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"successful":true,"data":{"response_data":{"draft_id":"draft-legacy-1",' +
          '"thread_id":"thread-legacy-1"}},"error":null}',
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 草稿'
      );
      const missingEvidence: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"successful":true,"data":{"response_data":{"data":{"id":"draft-untrusted-1"},' +
          '"logs":[]}},"error":null}',
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 草稿'
      );
      const failed: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"successful":false,"data":{"response_data":{"data":{' +
          '"display_url":"https://mail.google.com/mail/u/0/#drafts/draft-failed-1",' +
          '"id":"draft-failed-1"}}},"error":"provider failed"}',
        'GMAIL_CREATE_EMAIL_DRAFT',
        '创建 Gmail 草稿'
      );
      const originalArgs = looseObject(
        '{"to":["alice@example.com"],"subject":"","body":"我收到了"}'
      );
      const jsonl = gmailDraftPreviewA2ui(
        'gmail_nested_provider_surface',
        result,
        originalArgs,
        'gmail.draft.create'
      );
      const missingEvidenceJsonl = gmailDraftPreviewA2ui(
        'gmail_missing_evidence_surface',
        missingEvidence,
        originalArgs,
        'gmail.draft.create'
      );
      const failedJsonl = gmailDraftPreviewA2ui(
        'gmail_failed_surface',
        failed,
        originalArgs,
        'gmail.draft.create'
      );
      const unrelatedJsonl = gmailDraftPreviewA2ui(
        'gmail_unsafe_slug_surface',
        unrelated,
        originalArgs,
        'gmail.draft.create'
      );

      expect(result.status).assertEqual('success');
      expect(JSON.stringify(result.rows).indexOf('"label":"Draft ID","value":"draft-provider-nested-1"'))
        .assertLarger(-1);
      expect(result.rawPreview.indexOf('draft-provider-nested-1')).assertLarger(-1);
      expect(result.rawPreview.indexOf('private log title')).assertEqual(-1);
      expect(result.rawPreview.indexOf('private log text')).assertEqual(-1);
      expect(result.rawPreview.indexOf('private log body')).assertEqual(-1);
      expect(JSON.stringify(result.rows).indexOf('private log title')).assertEqual(-1);
      expect(JSON.stringify(result.rows).indexOf('private log text')).assertEqual(-1);
      expect(JSON.stringify(result.rows).indexOf('private log body')).assertEqual(-1);
      expect(jsonl.indexOf('"id":"gmail.draft.apply"')).assertLarger(-1);
      expect(jsonl.indexOf('"draftId":"draft-provider-nested-1"')).assertLarger(-1);
      expect(JSON.stringify(messageThreadEvidence.rows)).assertEqual(
        '[{"label":"执行工具","value":"GMAIL_CREATE_EMAIL_DRAFT"},' +
          '{"label":"查询","value":"创建 Gmail 草稿"},' +
          '{"label":"Draft ID","value":"draft-message-thread-1"}]'
      );
      expect(messageThreadEvidence.rawPreview).assertEqual('{"draft_id":"draft-message-thread-1"}');
      expect(messageThreadEvidence.rawPreview.indexOf('private header title')).assertEqual(-1);
      expect(messageThreadEvidence.rawPreview.indexOf('private header text')).assertEqual(-1);
      expect(messageThreadEvidence.rawPreview.indexOf('private header body')).assertEqual(-1);
      expect(JSON.stringify(legacy.rows).indexOf('draft-legacy-1')).assertLarger(-1);
      expect(JSON.stringify(missingEvidence.rows).indexOf('"label":"Draft ID"')).assertEqual(-1);
      expect(missingEvidenceJsonl.indexOf('"id":"gmail.draft.apply"')).assertEqual(-1);
      expect(failed.status).assertEqual('error');
      expect(JSON.stringify(failed.rows).indexOf('"label":"Draft ID"')).assertEqual(-1);
      expect(failedJsonl.indexOf('"id":"gmail.draft.apply"')).assertEqual(-1);
      expect(JSON.stringify(unrelated.rows).indexOf('"label":"Draft ID"')).assertEqual(-1);
      expect(unrelated.rawPreview.indexOf('draft-provider-nested-1')).assertEqual(-1);
      expect(unrelatedJsonl.indexOf('"id":"gmail.draft.apply"')).assertEqual(-1);
    });

    it('accepts the real Calendar write response_data id without a generic success flag', 0, () => {
      const observation = '{"data":{"composio_execution_message":null,' +
        '"response_data":{"id":"event-created-real","summary":"Appless QA",' +
        '"start":{"dateTime":"2026-07-31T15:00:00+08:00"},' +
        '"end":{"dateTime":"2026-07-31T15:30:00+08:00"}}},"error":null}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GOOGLECALENDAR_CREATE_EVENT',
        '创建 Google Calendar 日程'
      );
      const rejected: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"response_data":{"success":false,"id":"event-must-not-pass"}},"error":null}',
        'GOOGLECALENDAR_CREATE_EVENT',
        '创建 Google Calendar 日程'
      );
      const removed: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"response_data":{"successful":true}},"error":null}',
        'GOOGLECALENDAR_DELETE_EVENT',
        '删除 Google Calendar 日程'
      );
      const unconfirmedRemove: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"response_data":{}},"error":null}',
        'GOOGLECALENDAR_DELETE_EVENT',
        '删除 Google Calendar 日程'
      );

      expect(result.status).assertEqual('success');
      expect(result.rawPreview.indexOf('event-created-real')).assertLarger(-1);
      expect(rejected.status).assertEqual('error');
      expect(removed.status).assertEqual('success');
      expect(unconfirmedRemove.status).assertEqual('error');
    });

    it('maps Google Docs file payload to display rows', 0, () => {
      const observation = '{"data":{"files":[{"id":"doc_1","name":"AIPhoneDemo 设计文档","modifiedTime":"2026-07-06T12:41:26.011Z","webViewLink":"https://docs.google.com/document/d/doc_1/edit"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'GOOGLEDOCS_SEARCH_DOCUMENTS',
        '帮我在 Google Docs 里找 AIPhoneDemo 设计文档'
      );

      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('AIPhoneDemo 设计文档')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('docs.google.com')).assertLarger(-1);
    });

    it('maps new Composio app payloads to app-specific result cards', 0, () => {
      const outlookObservation = '{"data":{"messages":[{"subject":"AIPhoneDemo follow-up","from":{"name":"Product Team"},"receivedDateTime":"2026-07-07T08:30:00Z","webLink":"https://outlook.office.com/mail/id/1"}]}}';
      const outlookResult: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        outlookObservation,
        'OUTLOOK_SEARCH_MESSAGES',
        '帮我用 Outlook 查最近和 AIPhoneDemo 相关的邮件'
      );

      expect(outlookResult.title).assertEqual('Composio Outlook 结果');
      expect(outlookResult.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(outlookResult.rows).indexOf('AIPhoneDemo follow-up')).assertLarger(-1);

      const ticketmasterObservation = '{"data":{"events":[{"name":"Shenzhen Live","status":"onsale","start_time":"2026-07-11T20:00:00+08:00","venue":{"name":"Shenzhen Bay Sports Center"},"url":"https://www.ticketmaster.com/event/1"}]}}';
      const ticketmasterResult: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        ticketmasterObservation,
        'TICKETMASTER_SEARCH_EVENTS',
        '帮我用 Ticketmaster 查深圳本周末的演唱会'
      );

      expect(ticketmasterResult.title).assertEqual('Composio Ticketmaster 结果');
      expect(ticketmasterResult.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(ticketmasterResult.rows).indexOf('Shenzhen Live')).assertLarger(-1);
    });

    it('recognizes Hacker News search prompts and maps execute rows', 0, () => {
      expect(isComposioDynamicPrompt('帮我用 Composio Hacker News 搜 openai codex 的帖子')).assertTrue();
      expect(shouldAttemptComposioDynamic('帮我用 Composio Hacker News 搜 openai codex 的帖子', 'execute', false)).assertTrue();

      const observation = '{"data":{"hits":[{"title":"OpenAI Codex discussion","author":"pg","points":128,"num_comments":42,"url":"https://news.ycombinator.com/item?id=123","created_at":"2026-07-09T01:00:00Z"}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'HACKERNEWS_SEARCH_POSTS',
        '帮我用 Composio Hacker News 搜 openai codex 的帖子'
      );

      expect(result.title).assertEqual('Composio Hacker News 结果');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('OpenAI Codex discussion')).assertLarger(-1);

      const itemResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"id":123,"kids":[456],"text":"First real HN reply"}}',
        'HACKERNEWS_GET_ITEM',
        '读取 Hacker News 评论'
      );
      expect(itemResult.rawPreview.indexOf('"kids":[456]')).assertLarger(-1);
      expect(itemResult.rawPreview.indexOf('First real HN reply')).assertLarger(-1);
    });

    it('recognizes Reddit search prompts and maps execute rows', 0, () => {
      expect(isComposioDynamicPrompt('帮我用 Reddit 查 openai codex 讨论')).assertTrue();
      expect(shouldAttemptComposioDynamic('帮我用 Reddit 查 openai codex 讨论', 'execute', false)).assertTrue();

      const observation = '{"data":{"children":[{"data":{"title":"OpenAI Codex on Reddit","author":"dev_user","ups":88,"num_comments":12,"permalink":"/r/OpenAI/comments/1/codex","selftext":"Long discussion"}}]}}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        observation,
        'REDDIT_SEARCH_POSTS',
        '帮我用 Reddit 查 openai codex 讨论'
      );

      expect(result.title).assertEqual('Composio Reddit 结果');
      expect(result.status).assertEqual('success');
      expect(result.summary.indexOf('返回 1 条')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('OpenAI Codex on Reddit')).assertLarger(-1);
    });

    it('keeps Reddit comment text nested in listing children', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"comments_listing":{"data":{"children":[{"kind":"t1","data":{"body":"First real Reddit reply"}}]}}}}',
        'REDDIT_RETRIEVE_POST_COMMENTS',
        '读取 Reddit 评论'
      );

      expect(result.status).assertEqual('success');
      expect(result.rawPreview.indexOf('First real Reddit reply')).assertLarger(-1);
    });

    it('keeps john on the GitHub path instead of Hacker News', 0, () => {
      const prompt = '帮我用 Composio GitHub 查 john 的 PR';

      expect(isComposioDynamicPrompt(prompt)).assertTrue();
      expect(shouldAttemptComposioDynamic(prompt, 'execute', false)).assertTrue();

      const observation = '{"source":"Composio","authorizedToolkits":["github"],"tools":[{"toolSlug":"GITHUB_FIND_PULL_REQUESTS","description":"Search GitHub pull requests","inputSchema":"{}"}]}';
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation('search', observation, '', prompt);

      expect(result.title).assertEqual('Composio GitHub 结果');
      expect(JSON.stringify(result.rows).indexOf('GITHUB_FIND_PULL_REQUESTS')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Hacker News')).assertEqual(-1);
    });

    it('keeps target app identity when Composio has no authorized matching tool', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'search',
        'Composio 没有在已授权 Toolkit 中找到匹配工具。',
        '',
        '帮我用 Discord 查最近提到 AIPhoneDemo 的消息'
      );

      expect(result.title).assertEqual('Composio Discord 结果');
      expect(result.status).assertEqual('error');
      expect(JSON.stringify(result.rows).indexOf('AIPhoneDemo')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('没有在已授权 Toolkit')).assertLarger(-1);
    });

    it('does not treat Composio execute errors as successful results', 0, () => {
      const result: DynamicGenericToolResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":null,"error":"Invalid request data provided","log_id":"log_1"}',
        'GOOGLEDOCS_SEARCH_DOCUMENTS',
        '帮我在 Google Docs 里找 AIPhoneDemo 设计文档'
      );

      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('Invalid request data provided')).assertLarger(-1);
      expect(JSON.stringify(result.rows).indexOf('Invalid request data provided')).assertLarger(-1);
    });

    it('fails closed when a Composio write explicitly reports false without an error string', 0, () => {
      const successfulFalse = composioDynamicResultFromObservation(
        'execute',
        '{"successful":false,"data":null,"error":null}',
        'GMAIL_REPLY_TO_THREAD',
        '回复 Gmail 线程'
      );
      const successFalse = composioDynamicResultFromObservation(
        'execute',
        '{"success":false,"data":{}}',
        'GMAIL_REPLY_TO_THREAD',
        '回复 Gmail 线程'
      );

      expect(successfulFalse.status).assertEqual('error');
      expect(successFalse.status).assertEqual('error');
      expect(JSON.stringify(successfulFalse).indexOf('已发送')).assertEqual(-1);
      expect(JSON.stringify(successFalse).indexOf('已发送')).assertEqual(-1);
    });

    it('fails closed for malformed and absent Composio write results', 0, () => {
      const malformed = composioDynamicResultFromObservation(
        'execute',
        'provider returned an unparseable response',
        'GMAIL_REPLY_TO_THREAD',
        '回复 Gmail 线程'
      );
      const missingResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":null,"error":null}',
        'GMAIL_REPLY_TO_THREAD',
        '回复 Gmail 线程'
      );

      expect(malformed.status).assertEqual('error');
      expect(missingResult.status).assertEqual('error');
      expect(JSON.stringify(malformed).indexOf('已发送')).assertEqual(-1);
      expect(JSON.stringify(missingResult).indexOf('已发送')).assertEqual(-1);
    });

    it('requires positive provider evidence for writes while preserving read payloads', 0, () => {
      const writeResult = composioDynamicResultFromObservation(
        'execute',
        '{"successful":true,"data":{"id":"message-1","thread_id":"thread-999"}}',
        'GMAIL_REPLY_TO_THREAD',
        '回复 Gmail 线程'
      );
      const readResult = composioDynamicResultFromObservation(
        'execute',
        '{"data":{"items":[]}}',
        'GMAIL_FETCH_EMAILS',
        '查看 Gmail 邮件'
      );

      expect(writeResult.status).assertEqual('success');
      expect(readResult.status).assertEqual('success');
    });

    it('propagates an inner Gmail reply failure through the fixed backend result', 0, async () => {
      const client = new RecordingComposioSearchExecuteClient(
        searchObservationForTool('GMAIL_REPLY_TO_THREAD'),
        '{"successful":false,"data":null,"error":null}'
      );

      const result = await callComposioFixedSearchAndExecuteForTest(
        client,
        '回复 Gmail 线程',
        'gmail.reply.send',
        looseObject('{"recipientEmail":"alice@example.com","body":"Confirmed.","threadId":"thread-999"}')
      );

      expect(client.executedSlugs.length).assertEqual(1);
      expect(result.status).assertEqual('error');
      expect(JSON.stringify(result).indexOf('已发送')).assertEqual(-1);
    });
  });
}
