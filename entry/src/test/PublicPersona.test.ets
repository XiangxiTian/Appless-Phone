import { preferences } from '@kit.ArkData';
import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiMessage,
  DataResult,
  DataResultError,
  DataResultStatus,
  DynamicGenericToolResult,
  GenericStructuredData,
  LocalModelSettings
} from '@loop/agent-core';
import { A2uiLabelValueData } from '@loop/agent-core';
import {
  PublicPersonaSourceRef,
  PublicPersonaSnapshot,
  PublicPersonaCandidate,
  PublicPersonaInference,
  PublicPersonaMemoryCandidate,
  PublicPersonaProgress,
  PublicPersonaIdentity,
  PublicPersonaProbe,
  classifyPublicPersonaProbe,
  normalizePublicPersonaUsername,
  parsePublicPersonaInference,
  parsePublicPersonaMarkdown,
  publicPersonaEditableMarkdown,
  parsePublicProfileUrl,
  publicPersonaCatalog,
  publicPersonaPlatformLabel,
  publicPersonaOwnershipBand,
  publicPersonaMemoryFacts,
  publicPersonaMemoryFactsAreCurrent,
  publicPersonaImportFacts,
  publicPersonaMarkdownFingerprint,
  publicPersonaProfileUrl,
  publicPersonaPreviewMarkdown,
  publicPersonaUsernameFromProfileUrl,
  publicPersonaUsernameAliases,
  projectPublicPersonaMemoryFacts,
  isPublicPersonaImported,
  markPublicPersonaImported,
  publicPersonaSnapshotAfterMarkdownEdit,
  publicPersonaSnapshotWithMemoryFacts,
  parsePublicPersonaMemoryFacts,
  renderPublicPersonaMarkdown,
  replacePublicPersonaMbti,
  sanitizePublicPersonaSnapshot,
  scorePublicPersonaCandidate,
  hasRequiredPublicPersonaSections
} from '../main/ets/publicpersona/PublicPersonaModel';
import {
  PUBLIC_PERSONA_ONBOARDING_KEY,
  PUBLIC_PERSONA_SNAPSHOT_KEY,
  PublicPersonaStore
} from '../main/ets/publicpersona/PublicPersonaStore';
import {
  PublicPersonaClient,
  PublicPersonaModelCaller,
  PublicPersonaToolCaller
} from '../main/ets/publicpersona/PublicPersonaClient';
import {
  PublicPersonaRequestHeaders,
  PublicPersonaHttpCaller,
  PublicPersonaHttpResult,
  probePublicPersonaProfile,
  requestPublicPersonaProfile
} from '../main/ets/publicpersona/PublicPersonaProbeClient';
import { DirectModelCallResult } from '../main/ets/model/LocalModelClient';
import {
  MemoryModelCaller,
  MemoryModelTaskRunner,
  MemoryModelTaskRunnerLogger
} from '../main/ets/memory/MemoryModelTaskRunner';
import {
  publicPersonaDraftAfterDefaultChange,
  publicPersonaImportButtonViewState,
  publicPersonaMarkdownSurfaceKind
} from '../main/ets/pages/A2uiHome/components/PublicPersonaPage';

class MemoryPreferences {
  private values: Map<string, preferences.ValueType> = new Map();
  failPut: boolean = false;
  failDelete: boolean = false;

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    if (this.failPut) {
      throw new Error('put failed');
    }
    this.values.set(key, value);
  }

  deleteSync(key: string): void {
    if (this.failDelete) {
      throw new Error('delete failed');
    }
    this.values.delete(key);
  }

  flushSync(): void {}
}

class DeferredProfileResult {
  promise: Promise<PublicPersonaHttpResult>;
  private resolver: ((value: PublicPersonaHttpResult) => void) | null = null;

  constructor() {
    this.promise = new Promise<PublicPersonaHttpResult>((resolve: (value: PublicPersonaHttpResult) => void) => {
      this.resolver = resolve;
    });
  }

  resolve(value: PublicPersonaHttpResult): void {
    const resolver = this.resolver;
    this.resolver = null;
    if (resolver !== null) resolver(value);
  }
}

interface MarkdownEnvelopeData {
  markdown: string;
}

interface MarkdownEnvelope {
  success: boolean;
  data: MarkdownEnvelopeData;
}

function nativePreferences(): preferences.Preferences {
  return new MemoryPreferences() as Object as preferences.Preferences;
}

function validSnapshot(): PublicPersonaSnapshot {
  const source: PublicPersonaSourceRef = {
    platform: 'github',
    profileUrl: 'https://github.com/ada',
    avatarUrl: 'https://github.com/ada.png',
    displayName: 'Ada Lovelace',
    username: 'ada',
    sourceUrls: ['https://github.com/ada'],
    fetchedAt: '2026-08-06T00:00:00.000Z'
  };
  return {
    schemaVersion: 1,
    personaMarkdown: [
      '# Ada Lovelace', '', '> 喜欢把复杂问题讲清楚。', '',
      '## 身份与经历', '- 软件先驱', '', '## 专长', '- 算法', '',
      '## 兴趣与偏好', '- 数学', '', '## 沟通风格', '- 结构化', '',
      '## 近期关注', '- 公开技术写作', '', '## 性格推断', 'ENTP · 68%', '',
      '## 已确认账号', '- [github](https://github.com/ada) · ada'
    ].join('\n'),
    primaryAvatarUrl: source.avatarUrl,
    sources: [source],
    generatedAt: '2026-08-06T00:00:00.000Z',
    mbtiHidden: false
  };
}

function dataResult(toolId: string, data: Object, status: DataResultStatus = 'success'): DataResult {
  return {
    toolId: toolId,
    outputSchema: 'object',
    status: status,
    sources: [],
    data: data,
    warnings: []
  };
}

function dynamicResult(
  toolName: string,
  status: string,
  rawPreview: string = '',
  rows: A2uiLabelValueData[] = []
): DynamicGenericToolResult {
  return {
    sourceTag: 'firecrawl',
    toolName: toolName,
    title: toolName,
    status: status,
    summary: status,
    rows: rows,
    rawPreview: rawPreview
  };
}

function dynamicDataResult(
  toolId: string,
  results: DynamicGenericToolResult[],
  status: DataResultStatus = 'success'
): DataResult {
  const data: GenericStructuredData = { results: results };
  return dataResult(toolId, data as Object, status);
}

function modelSettings(): LocalModelSettings {
  return {
    provider: 'test',
    baseUrl: 'https://model.invalid/v1',
    model: 'test-model',
    apiKey: '',
    customParametersJson: '{}',
    ignoreToolSurfaceUpdates: false
  };
}

function modelInferenceResult(
  mbtiType: string = 'ENTP',
  memoryCandidates: PublicPersonaMemoryCandidate[] = []
): DirectModelCallResult {
  return {
    ok: true,
    raw: JSON.stringify({
      titleName: 'Ada Lovelace', oneLineSummary: '喜欢把复杂问题讲清楚。',
      identityAndExperience: ['软件先驱'], expertise: ['算法'],
      interestsAndPreferences: ['数学'], communicationStyle: ['结构化'],
      recentFocus: ['公开技术写作'], personalityInference: ['偏好探索新想法'],
      mbtiType: mbtiType, mbtiConfidence: 68, memoryCandidates: memoryCandidates
    }),
    error: '', requestDebug: '', assistantDebug: ''
  };
}

interface ProfileFixture {
  displayName: string;
  username: string;
  avatarUrl: string;
  canonicalUrl?: string;
  linkedUrls?: string[];
  bio?: string;
  posts?: Object[];
  sourceUrls?: string[];
}

interface SearchRowFixture {
  url: string;
}

interface SearchFixture {
  results: SearchRowFixture[];
}

interface PostFixture {
  url: string;
  title: string;
  text: string;
  publishedAt: string;
  pinned: boolean;
}

interface PostsFixture {
  posts: PostFixture[];
}

interface FirecrawlFullReadFixture {
  publicBio: string;
  pinnedPosts: PostFixture[];
  latestPosts: PostFixture[];
}

interface EvidenceFixture {
  bio: string;
  posts: Object[];
  sourceUrls: string[];
}

class PersonaMemoryRunnerCaller implements MemoryModelCaller {
  calls: number = 0;
  raw: string;
  prompt: string = '';
  systemPrompt: string = '';

  constructor(raw: string) {
    this.raw = raw;
  }

  async call(_settings: LocalModelSettings, prompt: string, _history: A2uiMessage[],
    systemPrompt: string): Promise<DirectModelCallResult> {
    this.calls += 1;
    this.prompt = prompt;
    this.systemPrompt = systemPrompt;
    return { ok: true, raw: this.raw, error: '', requestDebug: '', assistantDebug: '' };
  }
}

class PersonaMemoryRunnerLogger implements MemoryModelTaskRunnerLogger {
  lines: string[] = [];

  info(message: string): void {
    this.lines.push(message);
  }

  error(message: string): void {
    this.lines.push(message);
  }
}

interface PublicPersonaMemoryCandidatesFixture {
  memoryCandidates: PublicPersonaMemoryCandidate[];
}

export default function publicPersonaTest() {
  describe('publicPersonaModel', () => {
    it('prefills untouched drafts without overwriting user input on later account-name updates', 0, () => {
      expect(publicPersonaDraftAfterDefaultChange('', false, '  小罗  ')).assertEqual('小罗');
      expect(publicPersonaDraftAfterDefaultChange('用户手动输入', true, '新账号名'))
        .assertEqual('用户手动输入');
      expect(publicPersonaDraftAfterDefaultChange('', true, '新账号名')).assertEqual('');
    });

    it('uses a parent-scroll-friendly text surface until persona markdown enters edit mode', 0, () => {
      expect(publicPersonaMarkdownSurfaceKind(false)).assertEqual('readonly_text');
      expect(publicPersonaMarkdownSurfaceKind(true)).assertEqual('editable_area');
    });

    it('disables explicit persona import while editing, importing, or already imported', 0, () => {
      expect(publicPersonaImportButtonViewState(false, false, false).label)
        .assertEqual('将画像导入长期记忆');
      expect(publicPersonaImportButtonViewState(false, false, false).enabled).assertTrue();
      expect(publicPersonaImportButtonViewState(false, false, true).enabled).assertFalse();
      expect(publicPersonaImportButtonViewState(false, true, false).label).assertEqual('导入中');
      expect(publicPersonaImportButtonViewState(false, true, false).enabled).assertFalse();
      expect(publicPersonaImportButtonViewState(true, false, false).label).assertEqual('已导入长期记忆');
      expect(publicPersonaImportButtonViewState(true, false, false).enabled).assertFalse();
    });

    it('accepts a username but rejects the old profile URL input contract', 0, () => {
      expect(normalizePublicPersonaUsername('@XiaoLuoLYG')).assertEqual('XiaoLuoLYG');
      expect(normalizePublicPersonaUsername('https://github.com/XiaoLuoLYG')).assertEqual(null);
      expect(normalizePublicPersonaUsername('Yige Luo')).assertEqual(null);
      expect(normalizePublicPersonaUsername('')).assertEqual(null);
    });

    it('builds only deterministic fuzzy aliases from username and public name', 0, () => {
      const aliases = publicPersonaUsernameAliases('XiaoLuoLYG', ['Yige Luo']);

      expect(aliases.indexOf('xiaoluolyg') >= 0).assertTrue();
      expect(aliases.indexOf('yigeluo') >= 0).assertTrue();
      expect(aliases.indexOf('luoyige') >= 0).assertTrue();
      expect(aliases.indexOf('yige_luo') >= 0).assertTrue();
      expect(aliases.indexOf('luo-yige') >= 0).assertTrue();
      expect(aliases.some((value: string): boolean => value.indexOf('1995') >= 0)).assertFalse();
      expect(aliases.length <= 24).assertTrue();
    });

    it('runs the same native username path for yigeluo and elonmusk', 0, async () => {
      const usernames: string[] = ['yigeluo', 'elonmusk'];
      for (let index = 0; index < usernames.length; index++) {
        const username = usernames[index];
        const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
          dataResult(toolId, new Object(), 'empty'),
        async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-10T00:00:00.000Z', 70000, async (url: string) => {
          if (url === 'https://api.github.com/users/' + username) {
            return { statusCode: 200, body: JSON.stringify({
              login: username, name: username, avatar_url: 'https://avatars.githubusercontent.com/u/42',
              html_url: 'https://github.com/' + username, bio: 'Public profile'
            }) };
          }
          return { statusCode: 404, body: 'Not Found' };
        });

        const candidates = await client.discover(username, 'exact', (_value: PublicPersonaProgress): void => {});

        expect(candidates.length).assertEqual(1);
        expect(candidates[0].username).assertEqual(username);
      }
    });

    it('keeps source fixtures and labels in the probe catalog', 0, () => {
      const probes = publicPersonaCatalog();
      const pathProbe: PublicPersonaProbe = {
        platform: 'github', label: 'Path', domains: ['example.com'], profilePathPatterns: ['/people/'],
        displayUrlTemplate: 'https://example.com/people/{username}/',
        probeUrlTemplate: 'https://example.com/api/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
        caseSensitiveUsername: true, checkType: 'message', enabled: true,
        usernameClaimed: 'FooBar', usernameUnclaimed: 'noonewouldeverusethis7',
        presenceMarkers: ['profile'], missingMarkers: ['not found'], errorMarkers: ['captcha']
      };
      const hostProbe: PublicPersonaProbe = {
        platform: 'github', label: 'Host', domains: ['example.com'], profilePathPatterns: ['/'],
        displayUrlTemplate: 'https://{username}.example.com/',
        probeUrlTemplate: 'https://{username}.example.com/', usernamePattern: '^[a-zA-Z0-9]+$',
        caseSensitiveUsername: false, checkType: 'message', enabled: true,
        usernameClaimed: 'foto', usernameUnclaimed: 'noonewouldeverusethis7',
        presenceMarkers: ['profile'], missingMarkers: ['not found'], errorMarkers: ['captcha']
      };

      expect(probes.length).assertEqual(18);
      expect(probes.every((probe: PublicPersonaProbe): boolean =>
        probe.enabled && probe.usernameClaimed.length > 0 && probe.usernameUnclaimed.length > 0 &&
        (probe.checkType === 'message' || probe.checkType === 'status_code'))).assertTrue();
      expect(publicPersonaPlatformLabel('github')).assertEqual('GitHub');
      expect(publicPersonaProfileUrl(pathProbe, 'FooBar')).assertEqual('https://example.com/people/FooBar/');
      expect(publicPersonaProfileUrl(hostProbe, 'foto')).assertEqual('https://foto.example.com/');
    });

    it('keeps only username sources that pass native claimed and unclaimed admission', 0, () => {
      const probes = publicPersonaCatalog();
      const platforms = probes.map((probe: PublicPersonaProbe): string => probe.platform);
      const probeUrl = (platform: string, username: string): string => {
        const probe = probes.filter((value: PublicPersonaProbe): boolean => value.platform === platform)[0];
        return probe.probeUrlTemplate.replace('{username}', username);
      };

      expect(probes.length).assertEqual(18);
      expect(platforms.join(',')).assertEqual(
        'weibo,github,qq,inaturalist,leetcode_cn,gitee,stackoverflow,gitlab,bitbucket,' +
        'devto,keybase,lemmy,codeberg,codeforces,leetcode,gitea,hackerrank,discogs');
      expect(probeUrl('inaturalist', 'kueda')).assertEqual('https://api.inaturalist.org/v1/users/kueda');
      expect(probeUrl('leetcode_cn', 'leetcode')).assertEqual(
        'https://leetcode.cn/graphql/?userSlug=leetcode');
      expect(probeUrl('gitlab', 'blue')).assertEqual('https://gitlab.com/api/v4/users?username=blue');
      expect(probeUrl('keybase', 'blue'))
        .assertEqual('https://keybase.io/_/api/1.0/user/lookup.json?usernames=blue');
      expect(probeUrl('leetcode', 'soxoj')).assertEqual('https://leetcode.com/graphql/?username=soxoj');
      expect(probeUrl('stackoverflow', 'maigret')).assertContain('inname=maigret');
      expect(probes.filter((probe: PublicPersonaProbe): boolean => probe.platform === 'lemmy')[0]
        .usernameClaimed).assertEqual('Rooki');
      expect(probes.every((probe: PublicPersonaProbe): boolean =>
        probe.usernameClaimed.length > 0 && probe.usernameUnclaimed.length > 0 &&
        probe.errorMarkers.length > 0)).assertTrue();
    });

    it('parses path, at-sign, tilde, and subdomain profile templates', 0, () => {
      expect(parsePublicProfileUrl('https://www.douban.com/people/FooBar')?.platform).assertEqual('douban');
      expect(publicPersonaUsernameFromProfileUrl('https://www.douban.com/people/FooBar')).assertEqual('FooBar');
      expect(publicPersonaUsernameFromProfileUrl('https://www.npmjs.com/~sindresorhus')).assertEqual('sindresorhus');
      expect(publicPersonaUsernameFromProfileUrl('https://www.producthunt.com/@rajiv_ayyangar'))
        .assertEqual('rajiv_ayyangar');
      expect(publicPersonaUsernameFromProfileUrl('https://foto.tuchong.com')).assertEqual('foto');
      expect(parsePublicProfileUrl('https://www.douban.com/people/../settings')).assertEqual(null);
    });

    it('classifies deterministic platform probes without treating provider blocks as absence', 0, () => {
      const github = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'github')[0];

      expect(github === undefined).assertFalse();
      expect(publicPersonaProfileUrl(github, 'XiaoLuoLYG')).assertEqual('https://github.com/XiaoLuoLYG');
      expect(classifyPublicPersonaProbe(github, 404, 'Not Found')).assertEqual('not_found');
      expect(classifyPublicPersonaProbe(github, 410, 'Not Found')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(github, 200, 'Not Found')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(github, 429, '')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(github, 200, '{"login":"XiaoLuoLYG"}')).assertEqual('found');
      expect(classifyPublicPersonaProbe(github, 200, '<html>generic shell</html>')).assertEqual('unknown');
      expect(publicPersonaCatalog().every((probe): boolean =>
        typeof probe.caseSensitiveUsername === 'boolean' && probe.errorMarkers.length > 0)).assertTrue();
    });

    it('uses explicit Maigret message absence without accepting errors or soft shells', 0, () => {
      const probe: PublicPersonaProbe = {
        platform: 'github', label: 'Fixture', domains: ['example.com'], profilePathPatterns: ['/people/'],
        displayUrlTemplate: 'https://example.com/people/{username}',
        probeUrlTemplate: 'https://example.com/api/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
        caseSensitiveUsername: true, checkType: 'message', enabled: true,
        usernameClaimed: 'FooBar', usernameUnclaimed: 'noonewouldeverusethis7',
        presenceMarkers: ['account-profile'], missingMarkers: ['missing-account'],
        errorMarkers: ['captcha', 'rate limit']
      };

      expect(classifyPublicPersonaProbe(probe, 200, 'captcha account-profile')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(probe, 429, 'account-profile')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(probe, 404, '')).assertEqual('not_found');
      expect(classifyPublicPersonaProbe(probe, 410, 'missing-account')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(probe, 200, 'missing-account')).assertEqual('not_found');
      expect(classifyPublicPersonaProbe(probe, 200, 'account-profile')).assertEqual('found');
      expect(classifyPublicPersonaProbe(probe, 200, '<html>generic shell</html>')).assertEqual('unknown');
    });

    it('separates public API identities from missing and blocked responses', 0, () => {
      const probes = publicPersonaCatalog();
      const inaturalist = probes.filter((probe: PublicPersonaProbe): boolean => probe.platform === 'inaturalist')[0];
      expect(classifyPublicPersonaProbe(inaturalist, 200, '{"results":[{"login":"kueda"}]}'))
        .assertEqual('found');
      expect(classifyPublicPersonaProbe(inaturalist, 404, 'Not Found')).assertEqual('not_found');
      expect(classifyPublicPersonaProbe(inaturalist, 429, 'Too Many Requests')).assertEqual('unknown');
    });

    it('extracts a native exact profile and only one layer of allowlisted links', 0, async () => {
      const github = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'github')[0];
      const body = JSON.stringify({
        login: 'XiaoLuoLYG', name: 'Yige Luo', avatar_url: 'https://avatars.githubusercontent.com/u/42',
        html_url: 'https://github.com/XiaoLuoLYG', bio: 'Public AI engineer profile', twitter_username: 'luoyige'
      });
      const httpCaller: PublicPersonaHttpCaller = async (_url: string) => ({ statusCode: 200, body: body });

      const result = await probePublicPersonaProfile(github, 'XiaoLuoLYG', httpCaller);

      expect(result.state).assertEqual('found');
      expect(result.identity?.displayName).assertEqual('Yige Luo');
      expect(result.identity?.username).assertEqual('XiaoLuoLYG');
      expect(result.identity?.avatarUrl).assertEqual('https://avatars.githubusercontent.com/u/42');
      expect(result.identity?.canonicalUrl).assertEqual('https://github.com/XiaoLuoLYG');
      expect(result.identity?.linkedUrls.join(',')).assertEqual('https://x.com/luoyige');
      expect(result.bio).assertEqual('Public AI engineer profile');
    });

    it('keeps native absence separate from blocked or rate-limited probes', 0, async () => {
      const github = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'github')[0];
      const notFound = await probePublicPersonaProfile(github, 'missing-user', async (_url: string) => ({
        statusCode: 404, body: 'Not Found'
      }));
      const limited = await probePublicPersonaProfile(github, 'limited-user', async (_url: string) => ({
        statusCode: 429, body: 'rate limit'
      }));
      const blocked = await probePublicPersonaProfile(github, 'blocked-user', async (_url: string) => ({
        statusCode: 200, body: 'Verify your account to continue'
      }));

      expect(notFound.state).assertEqual('not_found');
      expect(limited.state).assertEqual('unknown');
      expect(blocked.state).assertEqual('unknown');
      expect(notFound.identity).assertEqual(null);
      expect(limited.identity).assertEqual(null);
      expect(blocked.identity).assertEqual(null);
    });

    it('activates the Sina visitor cookie before retrying a Weibo public probe', 0, async () => {
      const calls: string[] = [];
      const response = await requestPublicPersonaProfile(
        'https://weibo.com/ajax/profile/info?screen_name=clairekuo',
        async (url: string, method: string, headers: PublicPersonaRequestHeaders, body: string) => {
          calls.push(method + ' ' + url + ' ' + (headers.Cookie ?? '') + ' ' + body);
          if (url.indexOf('genvisitor2') >= 0) {
            return { statusCode: 200,
              body: 'visitor_gray_callback({"data":{"sub":"public-sub","subp":"public-subp"}})' };
          }
          if ((headers.Cookie ?? '').indexOf('SUB=public-sub; SUBP=public-subp') >= 0) {
            return { statusCode: 200, body: '{"ok":1,"data":{"user":{"screen_name":"Claire Kuo"}}}' };
          }
          return { statusCode: 500, body: '' };
        });

      expect(response.body).assertContain('Claire Kuo');
      expect(calls.length).assertEqual(2);
      expect(calls[0]).assertContain('POST https://passport.weibo.com/visitor/genvisitor2');
      expect(calls[1]).assertContain('SUB=public-sub; SUBP=public-subp');
    });

    it('posts the requested username to the LeetCode public GraphQL endpoint', 0, async () => {
      let call = '';
      await requestPublicPersonaProfile('https://leetcode.com/graphql/?username=soxoj',
        async (url: string, method: string, headers: PublicPersonaRequestHeaders, body: string) => {
          call = method + ' ' + url + ' ' + body;
          expect(headers.Accept).assertEqual('application/json');
          return { statusCode: 200, body: '{"data":{"matchedUser":null}}' };
        });

      expect(call).assertContain('POST https://leetcode.com/graphql/');
      expect(call).assertContain('"username":"soxoj"');
    });

    it('posts the requested user slug to the LeetCode CN public profile endpoint', 0, async () => {
      let call = '';
      await requestPublicPersonaProfile('https://leetcode.cn/graphql/?userSlug=leetcode',
        async (url: string, method: string, headers: PublicPersonaRequestHeaders, body: string) => {
          call = method + ' ' + url + ' ' + body;
          expect(headers.Accept).assertEqual('application/json');
          return { statusCode: 200, body: '{"data":{"userProfilePublicProfile":null}}' };
        });

      expect(call).assertContain('POST https://leetcode.cn/graphql/');
      expect(call).assertContain('"userSlug":"leetcode"');
    });

    it('keeps Douban on its desktop public profile instead of the mobile soft shell', 0, async () => {
      await requestPublicPersonaProfile('https://www.douban.com/people/darkmage/',
        async (url: string, _method: string, headers: PublicPersonaRequestHeaders, _body: string) => {
          expect(url).assertEqual('https://www.douban.com/people/darkmage/');
          expect(JSON.stringify(headers)).assertContain('Mozilla/5.0 Chrome/124.0');
          return { statusCode: 200, body: '<div id="db-usr-profile"></div>' };
        });
    });

    it('recognizes Keybase and LeetCode account-level absence payloads', 0, async () => {
      const probes = publicPersonaCatalog();
      const keybase = probes.filter((probe: PublicPersonaProbe): boolean => probe.platform === 'keybase')[0];
      const leetcodeCn = probes.filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'leetcode_cn')[0];
      const keybaseMissing = await probePublicPersonaProfile(keybase, 'zzzxqv123',
        async (_url: string) => ({ statusCode: 200, body: '{"them":[null]}' }));
      const keybaseInvalid = await probePublicPersonaProfile(keybase, 'zzzxqv123',
        async (_url: string) => ({ statusCode: 200, body: '{"status":{"desc":"bad list value"}}' }));
      const leetcodeCnMissing = await probePublicPersonaProfile(leetcodeCn, 'noonewouldeverusethis7',
        async (_url: string) => ({
          statusCode: 200,
          body: '{"data":{"userProfilePublicProfile":null}}'
        }));

      expect(keybaseMissing.state).assertEqual('not_found');
      expect(keybaseInvalid.state).assertEqual('unknown');
      expect(leetcodeCnMissing.state).assertEqual('not_found');
    });

    it('keeps GraphQL soft errors unknown even when the account field is null', 0, async () => {
      const leetcode = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'leetcode')[0];
      const leetcodeCn = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'leetcode_cn')[0];

      expect(classifyPublicPersonaProbe(leetcode, 200,
        '{"errors":[{"message":"rate limited"}],"data":{"matchedUser":null}}')).assertEqual('unknown');
      expect(classifyPublicPersonaProbe(leetcodeCn, 200,
        '{"errors":[{"message":"gateway"}],"data":{"userProfilePublicProfile":null}}'))
        .assertEqual('unknown');
      expect(classifyPublicPersonaProbe(leetcode, 200,
        '{"errors":[{"message":"That user does not exist."}],"data":{"matchedUser":null}}'))
        .assertEqual('not_found');
    });

    it('sends a safe native probe for a valid username containing the search token', 0, async () => {
      const github = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'github')[0];
      let requestedUrl = '';

      const result = await probePublicPersonaProfile(github, 'abc-luoyige-abc',
        async (url: string) => {
          requestedUrl = url;
          return { statusCode: 404, body: 'Not Found' };
        });

      expect(requestedUrl).assertEqual('https://api.github.com/users/abc-luoyige-abc');
      expect(result.state).assertEqual('not_found');
    });

    it('keeps a null rejection inside one native probe as unknown', 0, async () => {
      const github = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'github')[0];

      const result = await probePublicPersonaProfile(github, 'octocat',
        async (_url: string) => Promise.reject(null));

      expect(result.state).assertEqual('unknown');
    });

    it('refreshes an expired X guest token once before accepting the profile response', 0, async () => {
      const calls: string[] = [];
      let activationCount = 0;
      const profileUrl = 'https://twitter.com/i/api/graphql/ZRnOhhXPwue_JGILb9TNug/UserByScreenName?' +
        'variables=%7B%22screen_name%22%3A%22XiaoLuoLYG%22%2C%22withHighlightedLabel%22%3Atrue%7D';
      const response = await requestPublicPersonaProfile(profileUrl,
        async (url: string, method: string, headers: PublicPersonaRequestHeaders, _body: string) => {
          calls.push(method + ' ' + url);
          if (url.indexOf('guest/activate.json') >= 0) {
            activationCount++;
            return { statusCode: 200, body: JSON.stringify({ guest_token: 'guest-' + activationCount.toString() }) };
          }
          if (activationCount === 1) {
            expect(JSON.stringify(headers)).assertContain('"x-guest-token":"guest-1"');
            return { statusCode: 403, body: 'Bad guest token' };
          }
          expect(JSON.stringify(headers)).assertContain('"x-guest-token":"guest-2"');
          return {
            statusCode: 200,
            body: '{"data":{"user":{"result":{"legacy":{"screen_name":"XiaoLuoLYG",' +
              '"name":"Yige Luo","profile_image_url_https":"https://pbs.twimg.com/avatar.jpg",' +
              '"description":"public"}}}}}'
          };
        });

      expect(response.statusCode).assertEqual(200);
      expect(response.body).assertContain('XiaoLuoLYG');
      expect(calls.length).assertEqual(4);
    });

    it('falls back to the account-bound GitHub HTML profile when the API is rate limited', 0, async () => {
      const github = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'github')[0];
      const calls: string[] = [];
      const result = await probePublicPersonaProfile(github, 'octocat', async (url: string) => {
        calls.push(url);
        if (url.indexOf('api.github.com') >= 0) {
          return { statusCode: 403, body: 'API rate limit exceeded' };
        }
        return {
          statusCode: 200,
          body: '<html><head><link rel="canonical" href="https://github.com/octocat">' +
            '<meta property="og:title" content="The Octocat">' +
            '<meta property="og:image" content="https://avatars.githubusercontent.com/u/583231"></head></html>'
        };
      });

      expect(calls.join(',')).assertEqual('https://api.github.com/users/octocat,https://github.com/octocat');
      expect(result.state).assertEqual('found');
      expect(result.identity?.username).assertEqual('octocat');
    });

    it('uses platform-specific probes and never accepts a generic soft-200 page', 0, async () => {
      const httpUrls: string[] = [];
      const progress: PublicPersonaProgress[] = [];
      const httpCaller: PublicPersonaHttpCaller = async (url: string) => {
        httpUrls.push(url);
        if (url === 'https://api.github.com/users/XiaoLuoLYG') {
          return {
            statusCode: 200,
            body: JSON.stringify({
              login: 'XiaoLuoLYG', name: 'Yige Luo',
              avatar_url: 'https://avatars.githubusercontent.com/u/42',
              html_url: 'https://github.com/XiaoLuoLYG', bio: 'Public AI engineer profile'
            })
          };
        }
        return { statusCode: 404, body: 'Not Found' };
      };
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'),
      async (): Promise<DirectModelCallResult> => modelInferenceResult(),
      (): string => '2026-08-10T00:00:00.000Z', 70000, httpCaller);

      const candidates = await client.discover('XiaoLuoLYG', 'exact', (value: PublicPersonaProgress): void => {
        progress.push(value);
      });

      expect(httpUrls.indexOf('https://api.github.com/users/XiaoLuoLYG') >= 0).assertTrue();
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].platform).assertEqual('github');
      expect(candidates[0].displayName).assertEqual('Yige Luo');
      expect(candidates[0].avatarUrl).assertEqual('https://avatars.githubusercontent.com/u/42');
      expect(progress.some((value: PublicPersonaProgress): boolean =>
        value.platform === 'inaturalist' && value.state === 'empty')).assertTrue();
      const terminal = progress[progress.length - 1];
      expect(terminal.found).assertEqual(1);
      const compatibleCount = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        publicPersonaProfileUrl(probe, 'XiaoLuoLYG') !== null).length;
      expect(terminal.found + terminal.notFound + terminal.unknown).assertEqual(compatibleCount);
      expect(terminal.notFound).assertEqual(compatibleCount - 1);
      expect(terminal.unknown).assertEqual(0);
    });

    it('binds high-value public API responses to the requested account', 0, async () => {
      const probes = publicPersonaCatalog();
      const run = async (platform: string, username: string, body: string): Promise<void> => {
        const probe = probes.filter((value: PublicPersonaProbe): boolean => value.platform === platform)[0];
        const result = await probePublicPersonaProfile(probe, username, async (_url: string) => ({
          statusCode: 200, body: body
        }));
        expect(result.state).assertEqual('found');
        expect(result.identity?.username.toLowerCase()).assertEqual(username.toLowerCase());
        expect(result.identity?.avatarUrl.startsWith('https://')).assertTrue();
        expect(parsePublicProfileUrl(result.identity?.canonicalUrl ?? '')?.platform).assertEqual(platform);
      };

      await run('gitlab', 'blue',
        '[{"username":"blue","name":"Blue","avatar_url":"https://gitlab.com/uploads/blue.png",' +
        '"web_url":"https://gitlab.com/blue","bio":"builder"}]');
      await run('gitee', 'wizzer', '{"login":"wizzer","name":"Wizzer",' +
        '"avatar_url":"https://foruda.gitee.com/avatar.png","html_url":"https://gitee.com/wizzer"}');
      await run('devto', 'ben',
        '{"username":"ben","name":"Ben","profile_image":"https://media.dev.to/ben.png","summary":"builder"}');
      await run('keybase', 'blue',
        '{"them":[{"basics":{"username":"blue","username_cased":"Blue"},' +
        '"profile":{"full_name":"Blue User","bio":"keys"},' +
        '"pictures":{"primary":{"url":"https://keybase.io/avatar.png"}}}]}');
    });

    it('extracts account avatars from native profile shapes without Firecrawl', 0, async () => {
      const probes = publicPersonaCatalog();
      const run = async (platform: string, username: string, body: string, expectedAvatar: string): Promise<void> => {
        const probe = probes.filter((value: PublicPersonaProbe): boolean => value.platform === platform)[0];
        const result = await probePublicPersonaProfile(probe, username, async (_url: string) => ({
          statusCode: 200, body: body
        }));
        expect(result.state).assertEqual('found');
        expect(result.identity?.username.toLowerCase()).assertEqual(username.toLowerCase());
        expect(result.identity?.avatarUrl).assertEqual(expectedAvatar);
      };

      await run('leetcode_cn', 'leetcode', '{"data":{"userProfilePublicProfile":{' +
        '"username":"LeetCode","profile":{"realName":"LeetCode",' +
        '"userAvatar":"https://assets.leetcode.cn/avatar.png","aboutMe":"Code"}}}}',
        'https://assets.leetcode.cn/avatar.png');
      await run('discogs', 'discogs', '{"username":"discogs","name":"Discogs",' +
        '"avatar_url":"https://i.discogs.com/avatar.jpeg","uri":"https://www.discogs.com/user/discogs"}',
        'https://i.discogs.com/avatar.jpeg');
    });

    it('rejects a public API identity that is not bound to the requested account', 0, async () => {
      const gitea = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'gitea')[0];
      const mismatch = await probePublicPersonaProfile(gitea, 'lunny', async (_url: string) => ({
        statusCode: 200,
        body: '{"login":"someone-else","avatar_url":"https://gitea.com/a.png"}'
      }));
      const insecureAvatar = await probePublicPersonaProfile(gitea, 'lunny', async (_url: string) => ({
        statusCode: 200,
        body: '{"login":"lunny","avatar_url":"http://gitea.com/a.png"}'
      }));

      expect(mismatch.state).assertEqual('unknown');
      expect(insecureAvatar.state).assertEqual('unknown');
    });

    it('skips a platform when the username is outside its supported format', 0, async () => {
      const bilibili: PublicPersonaProbe = {
        platform: 'bilibili', label: 'Bilibili ID', domains: ['space.bilibili.com'],
        profilePathPatterns: ['/[0-9]+$'], displayUrlTemplate: 'https://space.bilibili.com/{username}',
        probeUrlTemplate: 'https://api.bilibili.com/x/web-interface/card?mid={username}',
        usernamePattern: '^[0-9]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
        usernameClaimed: '8047632', usernameUnclaimed: '999999999999999999',
        presenceMarkers: ['"card":{'], missingMarkers: ['"code":-404'], errorMarkers: ['captcha']
      };
      let calls = 0;
      const result = await probePublicPersonaProfile(bilibili, 'luoyige', async (_url: string) => {
        calls++;
        return { statusCode: 200, body: '' };
      });

      expect(calls).assertEqual(0);
      expect(result.state).assertEqual('unknown');
    });

    it('binds a LeetCode GraphQL identity to the requested username', 0, async () => {
      const leetcode = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        probe.platform === 'leetcode')[0];
      let requestedUrl = '';
      const result = await probePublicPersonaProfile(leetcode, 'soxoj', async (url: string) => {
        requestedUrl = url;
        return { statusCode: 200, body: '{"data":{"matchedUser":{"username":"soxoj","profile":{' +
          '"realName":"Soxoj","userAvatar":"https://assets.leetcode.com/avatar.png","aboutMe":"OSINT"}}}}' };
      });

      expect(requestedUrl).assertEqual('https://leetcode.com/graphql/?username=soxoj');
      expect(result.state).assertEqual('found');
      expect(result.identity?.username).assertEqual('soxoj');
      expect(result.identity?.avatarUrl).assertEqual('https://assets.leetcode.com/avatar.png');
    });

    it('extracts replacement identities from account-bound public APIs', 0, async () => {
      const probes = publicPersonaCatalog();
      const run = async (platform: string, username: string, body: string): Promise<void> => {
        const probe = probes.filter((value: PublicPersonaProbe): boolean => value.platform === platform)[0];
        const result = await probePublicPersonaProfile(probe, username, async (_url: string) => ({
          statusCode: 200, body: body
        }));
        expect(result.state).assertEqual('found');
        expect(result.identity?.username.toLowerCase()).assertEqual(username.toLowerCase());
        expect(result.identity?.avatarUrl.startsWith('https://')).assertTrue();
        expect(parsePublicProfileUrl(result.identity?.canonicalUrl ?? '')?.platform).assertEqual(platform);
      };

      await run('inaturalist', 'kueda', '{"results":[{"login":"kueda","name":"Ken-ichi",' +
        '"icon_url":"https://static.inaturalist.org/avatar.jpg"}]}');
      await run('lemmy', 'Rooki', '{"person_view":{"person":{"name":"Rooki","display_name":"Rooki",' +
        '"avatar":"https://lemmy.world/avatar.png","bio":"admin"}}}');
      await run('codeberg', 'forgejo', '{"login":"forgejo","full_name":"Forgejo",' +
        '"avatar_url":"https://codeberg.org/avatar.png","description":"forge"}');
      await run('stackoverflow', 'maigret', '{"items":[' +
        '{"display_name":"Regis MAIGRET","profile_image":"https://example.com/fuzzy.jpg",' +
        '"link":"https://stackoverflow.com/users/1/regis-maigret"},' +
        '{"display_name":"Maigret","profile_image":"https://www.gravatar.com/avatar/exact",' +
        '"link":"https://stackoverflow.com/users/8034756/maigret"}]}');
      await run('gitea', 'lunny', '{"login":"lunny","full_name":"Lunny Xiao",' +
        '"avatar_url":"https://gitea.com/avatar.png","html_url":"https://gitea.com/lunny"}');
      await run('hackerrank', 'uwi', '{"model":{"username":"uwi","name":"Uwi Tenpen",' +
        '"avatar":"https://d1ce3iv5vajdy.cloudfront.net/avatar.jpg","short_bio":"competitor"}}');
    });

    it('probes every retained exact username template without calling Firecrawl', 0, async () => {
      const httpUrls: string[] = [];
      const toolIds: string[] = [];
      const progress: PublicPersonaProgress[] = [];
      const httpCaller: PublicPersonaHttpCaller = async (url: string) => {
        httpUrls.push(url);
        if (url === 'https://api.github.com/users/123456') {
          return {
            statusCode: 200,
            body: '{"login":"123456","name":"Exact User","avatar_url":"https://avatars.githubusercontent.com/u/123456","html_url":"https://github.com/123456"}'
          };
        }
        return { statusCode: 404, body: 'Not Found' };
      };
      const toolCaller: PublicPersonaToolCaller = async (toolId: string): Promise<DataResult> => {
        toolIds.push(toolId);
        return dataResult(toolId, new Object(), 'empty');
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-10T00:00:00.000Z', 70000, httpCaller);

      const candidates = await client.discover('123456', 'exact', (value: PublicPersonaProgress): void => {
        progress.push(value);
      });

      const compatibleCount = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        publicPersonaProfileUrl(probe, '123456') !== null).length;
      expect(httpUrls.length).assertEqual(compatibleCount);
      expect(toolIds.length).assertEqual(0);
      expect(progress.filter((value: PublicPersonaProgress): boolean => value.state !== 'running').length)
        .assertEqual(compatibleCount);
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].platform).assertEqual('github');
      expect(candidates[0].selected).assertTrue();
      expect(candidates[0].ownershipBand).assertEqual('high');
    });

    it('verifies every fuzzy result with its native platform probe', 0, async () => {
      const toolIds: string[] = [];
      const httpUrls: string[] = [];
      const progress: PublicPersonaProgress[] = [];
      let nativeTerminalCountBeforeSearch = -1;
      let searchArgs = '';
      const httpCaller: PublicPersonaHttpCaller = async (url: string) => {
        httpUrls.push(url);
        if (url === 'https://dev.to/api/users/by_username?url=luoyige') {
          return {
            statusCode: 200,
            body: JSON.stringify({
              username: 'luoyige', name: 'Yige Luo',
              profile_image: 'https://media.dev.to/avatar.jpg', summary: ''
            })
          };
        }
        if (url.indexOf('api.github.com/users/abc-luoyige-0') >= 0) {
          return {
            statusCode: 200,
            body: '{"login":"abc-luoyige-0","name":"Yige Luo","avatar_url":' +
              '"https://avatars.githubusercontent.com/u/42","html_url":"https://github.com/abc-luoyige-0"}'
          };
        }
        return { statusCode: 404, body: 'Not Found' };
      };
      const toolCaller: PublicPersonaToolCaller = async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        toolIds.push(toolId);
        nativeTerminalCountBeforeSearch = progress.filter((value: PublicPersonaProgress): boolean =>
          value.state !== 'running').length;
        searchArgs = JSON.stringify(args);
        const rows: A2uiLabelValueData[] = [];
        for (let index = 0; index < 12; index++) {
          rows.push({ label: 'URL', value: 'https://github.com/abc-luoyige-' + index.toString() });
        }
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '', rows)]);
      };
      const client = new PublicPersonaClient(toolCaller, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
        (): string => '2026-08-10T00:00:00.000Z', 70000, httpCaller);

      const candidates = await client.discover('luoyige', 'fuzzy', (value: PublicPersonaProgress): void => {
        progress.push(value);
      });

      expect(toolIds.join(',')).assertEqual('web.research.search');
      const compatibleCount = publicPersonaCatalog().filter((probe: PublicPersonaProbe): boolean =>
        publicPersonaProfileUrl(probe, 'luoyige') !== null).length;
      expect(nativeTerminalCountBeforeSearch).assertEqual(compatibleCount);
      expect(searchArgs).assertContain('"maxResults":10');
      expect(searchArgs).assertContain('"searchOnly":true');
      expect(searchArgs).assertContain('yigeluo');
      expect(searchArgs).assertContain('luoyige');
      expect(searchArgs).assertContain('github.com');
      expect(candidates.length).assertEqual(2);
      const fuzzy = candidates.filter((candidate: PublicPersonaCandidate): boolean => candidate.platform === 'github');
      expect(fuzzy.length).assertEqual(1);
      expect(fuzzy.every((candidate: PublicPersonaCandidate): boolean =>
        candidate.ownershipBand === 'possible' && !candidate.selected)).assertTrue();
      expect(httpUrls.some((url: string): boolean => url.indexOf('/abc-luoyige-0') >= 0)).assertTrue();
      expect(httpUrls.some((url: string): boolean => url.indexOf('/abc-luoyige-1') >= 0)).assertTrue();
    });

    it('ignores explicit links to a source excluded from native search', 0, async () => {
      const httpUrls: string[] = [];
      let searchArgs = '';
      const httpCaller: PublicPersonaHttpCaller = async (url: string) => {
        httpUrls.push(url);
        if (url === 'https://api.github.com/users/ada-main') {
          return {
            statusCode: 200,
            body: '{"login":"ada-main","name":"Ada Main","avatar_url":"https://github.com/ada.png","html_url":"https://github.com/ada-main","blog":"https://www.linkedin.com/in/ada"}'
          };
        }
        return { statusCode: 404, body: 'Not Found' };
      };
      const client = new PublicPersonaClient(async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        searchArgs = JSON.stringify(args);
        return dataResult(toolId, new Object(), 'empty');
      }, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
      (): string => '2026-08-10T00:00:00.000Z', 70000, httpCaller);

      const candidates = await client.discover('ada-main', 'fuzzy', (_value: PublicPersonaProgress): void => {});

      expect(candidates.some((candidate: PublicPersonaCandidate): boolean =>
        candidate.profileUrl === 'https://x.com/ada')).assertFalse();
      expect(httpUrls.indexOf('https://www.linkedin.com/in/ada')).assertEqual(-1);
      expect(searchArgs.indexOf('"linkedin.com"')).assertEqual(-1);
    });

    it('keeps only native username sources admitted for device verification', 0, () => {
      const platforms = publicPersonaCatalog().map((probe) => probe.platform);

      expect(platforms.length).assertEqual(18);
      expect(platforms.join(',')).assertEqual(
        'weibo,github,qq,inaturalist,leetcode_cn,gitee,stackoverflow,gitlab,bitbucket,' +
        'devto,keybase,lemmy,codeberg,codeforces,leetcode,gitea,hackerrank,discogs'
      );
      expect(platforms.indexOf('npm')).assertEqual(-1);
      expect(platforms.indexOf('douban')).assertEqual(-1);
      expect(platforms.indexOf('scratch')).assertEqual(-1);
      expect(platforms.indexOf('mastodon')).assertEqual(-1);
      expect(platforms.indexOf('x')).assertEqual(-1);
      expect(platforms.indexOf('youtube')).assertEqual(-1);
      expect(platforms.indexOf('zhihu')).assertEqual(-1);
      expect(platforms.indexOf('deviantart')).assertEqual(-1);
      expect(platforms.indexOf('tieba')).assertEqual(-1);
      expect(platforms.indexOf('linkedin')).assertEqual(-1);
      expect(platforms.indexOf('jike' as never)).assertEqual(-1);
      expect(platforms.indexOf('tiktok' as never)).assertEqual(-1);
    });

    it('rejects YouTube channel IDs as username profile URLs', 0, () => {
      expect(parsePublicProfileUrl(
        'https://www.youtube.com/channel/UCBR8-60-B28hp2BmDPdntcQ'
      )).assertEqual(null);
    });

    it('accepts X and YouTube host aliases without changing the requested handle', 0, () => {
      expect(parsePublicProfileUrl('https://twitter.com/FooBar')?.platform).assertEqual('x');
      expect(publicPersonaUsernameFromProfileUrl('https://twitter.com/FooBar')).assertEqual('FooBar');
      expect(parsePublicProfileUrl('https://youtube.com/@FooBar')?.platform).assertEqual('youtube');
      expect(publicPersonaUsernameFromProfileUrl('https://youtube.com/@FooBar')).assertEqual('FooBar');
    });

    it('only accepts an allowlisted public profile URL', 0, () => {
      const accepted = parsePublicProfileUrl('https://github.com/octocat');

      expect(accepted === null).assertFalse();
      expect(accepted?.platform).assertEqual('github');
      expect(accepted?.url).assertEqual('https://github.com/octocat');
      expect(parsePublicProfileUrl('javascript:alert(1)')).assertEqual(null);
      expect(parsePublicProfileUrl('https://github.com/octocat?token=secret')).assertEqual(null);
      expect(parsePublicProfileUrl('https://example.com/octocat')).assertEqual(null);
      const bilibili = parsePublicProfileUrl('https://space.bilibili.com/123456');
      expect(bilibili === null).assertFalse();
      expect(bilibili?.platform).assertEqual('bilibili');
    });

    it('requires HTTPS and a real profile path at the public boundary', 0, () => {
      expect(parsePublicProfileUrl('http://github.com/octocat')).assertEqual(null);
      expect(parsePublicProfileUrl('https://github.com/settings')).assertEqual(null);
      expect(parsePublicProfileUrl('https://x.com/home')).assertEqual(null);
      expect(parsePublicProfileUrl('https://space.bilibili.com/not-a-uid')).assertEqual(null);
      expect(parsePublicProfileUrl('https://www.youtube.com/watch')).assertEqual(null);
    });

    it('preserves case-sensitive usernames from discovered profile URLs', 0, () => {
      expect(publicPersonaUsernameFromProfileUrl('https://www.zhihu.com/people/FooBar')).assertEqual('FooBar');
    });

    it('keeps Bilibili out of the enabled username catalog while retaining URL parsing', 0, () => {
      const bilibili = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'bilibili')[0];
      expect(bilibili === undefined).assertTrue();
      expect(parsePublicProfileUrl('https://space.bilibili.com/123456')?.url)
        .assertEqual('https://space.bilibili.com/123456');
      expect(parsePublicProfileUrl('https://www.bilibili.com/123456')).assertEqual(null);
      expect(parsePublicProfileUrl('https://mirror.space.bilibili.com/123456')).assertEqual(null);
    });

    it('admits Weibo only with the current nickname fixture and visitor markers', 0, () => {
      const weibo = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'weibo')[0];
      expect(weibo === undefined).assertFalse();
      expect(weibo.usernameClaimed).assertEqual('clairekuo');
      expect(weibo.probeUrlTemplate).assertContain('screen_name={username}');
      expect(weibo.missingMarkers.join(',')).assertContain('该昵称当前没有人使用');
    });

    it('binds a claimed Weibo nickname and keeps its explicit absence separate', 0, async () => {
      const weibo = publicPersonaCatalog().filter((probe): boolean => probe.platform === 'weibo')[0];
      const claimed = await probePublicPersonaProfile(weibo, 'clairekuo', async (_url: string) => ({
        statusCode: 200,
        body: '{"ok":1,"data":{"user":{"screen_name":"clairekuo","avatar_hd":' +
          '"https://tvax1.sinaimg.cn/crop.0.0.512.512.1024/example.jpg","description":"public profile"}}}'
      }));
      const unclaimed = await probePublicPersonaProfile(weibo, 'noonewouldeverusethis7',
        async (_url: string) => ({ statusCode: 200, body: '该昵称当前没有人使用' }));
      const mismatched = await probePublicPersonaProfile(weibo, 'clairekuo', async (_url: string) => ({
        statusCode: 200,
        body: '{"ok":1,"data":{"user":{"screen_name":"someoneelse","avatar_hd":' +
          '"https://tvax1.sinaimg.cn/crop.0.0.512.512.1024/example.jpg"}}}'
      }));

      expect(claimed.state).assertEqual('found');
      expect(claimed.identity?.username).assertEqual('clairekuo');
      expect(claimed.identity?.canonicalUrl).assertEqual('https://weibo.com/n/clairekuo');
      expect(claimed.identity?.avatarUrl.startsWith('https://')).assertTrue();
      expect(unclaimed.state).assertEqual('not_found');
      expect(unclaimed.identity).assertEqual(null);
      expect(mismatched.state).assertEqual('unknown');
    });

    it('separates ownership confidence from account existence', 0, () => {
      const seed: PublicPersonaIdentity = {
        displayName: 'Ada Lovelace',
        username: 'ada',
        avatarUrl: 'https://github.com/ada.png',
        canonicalUrl: 'https://github.com/ada',
        linkedUrls: []
      };
      const exact = scorePublicPersonaCandidate(seed, seed);
      const weakCandidate: PublicPersonaIdentity = {
        displayName: 'A. Lovelace',
        username: 'ada_l',
        avatarUrl: 'https://example.com/a.png',
        canonicalUrl: 'https://example.com/ada_l',
        linkedUrls: []
      };
      const weak = scorePublicPersonaCandidate(seed, weakCandidate);

      expect(exact).assertEqual(1);
      expect(publicPersonaOwnershipBand(exact)).assertEqual('high');
      expect(publicPersonaOwnershipBand(0.6)).assertEqual('possible');
      expect(publicPersonaOwnershipBand(0.2)).assertEqual(null);
      expect(weak).assertEqual(0.45);
      expect(publicPersonaOwnershipBand(weak)).assertEqual('possible');
    });

    it('does not award ownership for a candidate self-link', 0, () => {
      const seed: PublicPersonaIdentity = {
        displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://github.com/ada.png',
        canonicalUrl: 'https://github.com/ada', linkedUrls: []
      };
      const selfLinked: PublicPersonaIdentity = {
        displayName: 'Different Name', username: 'ada', avatarUrl: 'https://x.com/ada.png',
        canonicalUrl: 'https://x.com/ada', linkedUrls: ['https://x.com/ada']
      };

      const confidence = scorePublicPersonaCandidate(seed, selfLinked);
      expect(confidence).assertEqual(0.55);
      expect(publicPersonaOwnershipBand(confidence)).assertEqual('possible');
    });

    it('renders fixed markdown sections and a revocable MBTI line', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace',
        oneLineSummary: '喜欢把复杂问题讲清楚。',
        identityAndExperience: ['软件先驱'],
        expertise: ['算法'],
        interestsAndPreferences: ['数学'],
        communicationStyle: ['结构化'],
        recentFocus: ['公开技术写作'],
        personalityInference: ['偏好探索新想法'],
        mbtiType: 'ENTP',
        mbtiConfidence: 68
      }));
      const sources: PublicPersonaSourceRef[] = [{
        platform: 'github',
        profileUrl: 'https://github.com/ada',
        avatarUrl: 'https://github.com/ada.png',
        displayName: 'Ada Lovelace',
        username: 'ada-public',
        sourceUrls: ['https://github.com/ada'],
        fetchedAt: '2026-08-06T00:00:00.000Z'
      }];

      expect(inference === null).assertFalse();
      const markdown = renderPublicPersonaMarkdown(inference as never, sources);
      expect(hasRequiredPublicPersonaSections(markdown)).assertTrue();
      expect(markdown).assertContain('ENTP · 68%');
      expect(markdown.indexOf('基于公开资料的推测')).assertEqual(-1);
      expect(markdown).assertContain('## 已确认账号');
      expect(markdown).assertContain('ada-public');

      const fenced = '```json\n' + JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 68
      }) + '\n```';
      expect(parsePublicPersonaInference(fenced) === null).assertFalse();

      const replaced = replacePublicPersonaMbti(markdown, 'INFJ', 72);
      expect(replaced).assertContain('INFJ · 72%');
      expect(replaced).assertContain('## 已确认账号');

      const unavailable = markdown.replace('ENTP · 68%', 'MBTI 暂无');
      const inferred = replacePublicPersonaMbti(unavailable, 'INTJ', 64);
      expect(inferred).assertContain('INTJ · 64%');
      expect(inferred.indexOf('MBTI 暂无')).assertEqual(-1);
    });

    it('parses edited persona Markdown into the stable display fields', 0, () => {
      const edited = validSnapshot().personaMarkdown
        .replace('喜欢把复杂问题讲清楚。', '把前沿 AI 变成可靠产品。')
        .replace('- 算法', '- AI 工程\n- 多智能体系统');

      const inference: PublicPersonaInference | null = parsePublicPersonaMarkdown(edited);

      expect(inference === null).assertFalse();
      expect((inference as PublicPersonaInference).titleName).assertEqual('Ada Lovelace');
      expect((inference as PublicPersonaInference).oneLineSummary).assertEqual('把前沿 AI 变成可靠产品。');
      expect((inference as PublicPersonaInference).identityAndExperience[0]).assertEqual('软件先驱');
      expect((inference as PublicPersonaInference).expertise.length).assertEqual(2);
      expect((inference as PublicPersonaInference).expertise[1]).assertEqual('多智能体系统');
      expect((inference as PublicPersonaInference).interestsAndPreferences[0]).assertEqual('数学');
      expect((inference as PublicPersonaInference).communicationStyle[0]).assertEqual('结构化');
      expect((inference as PublicPersonaInference).recentFocus[0]).assertEqual('公开技术写作');
      expect((inference as PublicPersonaInference).mbtiType).assertEqual('ENTP');
      expect((inference as PublicPersonaInference).mbtiConfidence).assertEqual(68);
    });

    it('keeps empty generated sections empty in the rich profile', 0, () => {
      const inference: PublicPersonaInference = {
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: '', mbtiConfidence: 0
      };
      const parsed: PublicPersonaInference | null = parsePublicPersonaMarkdown(
        renderPublicPersonaMarkdown(inference, validSnapshot().sources)
      );

      expect(parsed === null).assertFalse();
      expect((parsed as PublicPersonaInference).identityAndExperience.length).assertEqual(0);
      expect((parsed as PublicPersonaInference).personalityInference.length).assertEqual(0);
    });

    it('keeps an intentionally empty Markdown draft while editing', 0, () => {
      const saved: string = validSnapshot().personaMarkdown;

      expect(publicPersonaEditableMarkdown(true, '', saved)).assertEqual('');
      expect(publicPersonaEditableMarkdown(false, '', saved)).assertEqual(saved);
    });

    it('rejects persisted Markdown that cannot render as a profile', 0, () => {
      const missingSummary: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: validSnapshot().personaMarkdown.replace('> 喜欢把复杂问题讲清楚。\n\n', ''),
        primaryAvatarUrl: validSnapshot().primaryAvatarUrl,
        sources: validSnapshot().sources,
        generatedAt: validSnapshot().generatedAt,
        mbtiHidden: false
      };

      expect(parsePublicPersonaMarkdown(missingSummary.personaMarkdown)).assertEqual(null);
      expect(sanitizePublicPersonaSnapshot(missingSummary as Object) === null).assertFalse();
    });

    it('accepts the compact profile schema returned by the local model', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        name: 'Yige Luo', username: 'XiaoLuoLYG', jobTitle: 'AI engineer', education: ['公开教育经历'],
        interests: ['AI'], projects: ['公开项目'], skills: ['ArkTS'], MBTI: 'INTJ 72%'
      }));
      expect(inference === null).assertFalse();
      expect((inference as never as PublicPersonaInference).titleName).assertEqual('Yige Luo');
      expect((inference as never as PublicPersonaInference).mbtiType).assertEqual('INTJ');
      expect((inference as never as PublicPersonaInference).mbtiConfidence).assertEqual(72);
    });

    it('accepts array-valued compact output when MBTI is unavailable', 0, () => {
      const inference = parsePublicPersonaInference(JSON.stringify({
        name: ['Yige Luo'], username: ['XiaoLuoLYG'], platforms: ['github'],
        education: ['University of Cambridge (Master of Engineering)'],
        occupation: ['Senior AI Engineer at Huawei 2012 Lab'],
        interests: ['AI agents and multi-agent systems'], projects: ['GOD - real-time control room'],
        mbti: [], enneagram: [], bigFive: []
      }));
      expect(inference === null).assertFalse();
      expect((inference as never as PublicPersonaInference).titleName).assertEqual('Yige Luo');
      expect((inference as never as PublicPersonaInference).oneLineSummary).assertEqual('Senior AI Engineer at Huawei 2012 Lab');
      expect((inference as never as PublicPersonaInference).interestsAndPreferences[0]).assertEqual('AI agents and multi-agent systems');
      expect((inference as never as PublicPersonaInference).mbtiType).assertEqual('');
      expect((inference as never as PublicPersonaInference).mbtiConfidence).assertEqual(0);
    });

    it('requires inference arrays while allowing explicit empty arrays', 0, () => {
      const completeEmpty = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 0
      }));
      const missingExpertise = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 0
      }));

      expect(completeEmpty === null).assertFalse();
      expect(missingExpertise).assertEqual(null);
    });

    it('projects every high-confidence self-contained public fact without deduplication or a product count cap', 0, () => {
      const memoryCandidates: PublicPersonaMemoryCandidate[] = [];
      for (let index = 0; index < 7; index++) {
        memoryCandidates.push({
          fact: '用户的公开资料展示了第 ' + index.toString() + ' 项专业能力',
          confidence: 0.9,
          kind: 'expertise'
        });
      }
      memoryCandidates.push({ fact: '用户喜欢数学', confidence: 0.92, kind: 'preference' });
      memoryCandidates.push({ fact: '用户对数学感兴趣', confidence: 0.91, kind: 'preference' });
      memoryCandidates.push({ fact: '用户近期关注多智能体工具', confidence: 0.94, kind: 'recent_focus' });
      memoryCandidates.push({ fact: '用户偶尔谈到音乐', confidence: 0.7, kind: 'preference' });
      memoryCandidates.push({ fact: '喜欢结构化沟通', confidence: 0.95, kind: 'communication_style' });
      memoryCandidates.push({ fact: '用户的政治立场明确', confidence: 0.99, kind: 'identity' });
      const inference = parsePublicPersonaInference(JSON.stringify({
        titleName: 'Ada', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: [], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 68, memoryCandidates: memoryCandidates
      })) as PublicPersonaInference;

      const facts = projectPublicPersonaMemoryFacts(inference, '2026-09-01T08:30:00.000Z');

      expect(facts.length).assertEqual(10);
      expect(facts[7].fact).assertEqual('用户喜欢数学');
      expect(facts[8].fact).assertEqual('用户对数学感兴趣');
      expect(facts[9].fact).assertContain('截至 2026-09-01');
      expect(facts[9].fact).assertContain('用户近期关注多智能体工具');
      expect(facts[9].source).assertEqual('public_persona');
      expect(facts[9].observedAt).assertEqual('2026-09-01T08:30:00.000Z');
    });

    it('loads a legacy snapshot without public-persona memory facts', 0, () => {
      const safe = sanitizePublicPersonaSnapshot(validSnapshot() as Object);

      expect(safe === null).assertFalse();
      expect(publicPersonaMemoryFacts(safe as PublicPersonaSnapshot).length).assertEqual(0);
      expect(isPublicPersonaImported(safe as PublicPersonaSnapshot)).assertFalse();
    });

    it('tracks explicit import against a stable normalized Markdown fingerprint', 0, () => {
      const snapshot = validSnapshot();
      expect(publicPersonaMarkdownFingerprint('  # Ada\r\n\r\n> Summary  '))
        .assertEqual(publicPersonaMarkdownFingerprint('# Ada\n\n> Summary'));

      const imported = markPublicPersonaImported(snapshot);
      expect(isPublicPersonaImported(imported)).assertTrue();

      imported.personaMarkdown = imported.personaMarkdown.replace('- 数学', '- 编曲');
      expect(isPublicPersonaImported(imported)).assertFalse();
    });

    it('requires a model rebuild after saved persona Markdown is edited', 0, () => {
      const snapshot = validSnapshot();
      snapshot.memoryFacts = [{
        fact: '用户喜欢旧内容', confidence: 0.95, kind: 'preference',
        source: 'public_persona', observedAt: snapshot.generatedAt
      }];
      snapshot.memoryFactsMarkdownFingerprint = publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
      snapshot.importedMarkdownFingerprint = publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
      const editedMarkdown = snapshot.personaMarkdown
        .replace('- 数学', '- 编曲')
        .replace('ENTP · 68%', '- 偏好探索新想法\nENTP · 68%');
      const edited = publicPersonaSnapshotAfterMarkdownEdit(snapshot, editedMarkdown);

      const facts = publicPersonaImportFacts(edited, '2026-09-02T09:00:00.000Z');

      expect(publicPersonaMemoryFacts(edited).length).assertEqual(0);
      expect(publicPersonaMemoryFactsAreCurrent(edited)).assertFalse();
      expect(isPublicPersonaImported(edited)).assertFalse();
      expect(facts.length).assertEqual(0);
    });

    it('reuses model memory facts only while they still match current persona Markdown', 0, () => {
      const snapshot = validSnapshot();
      snapshot.memoryFacts = [{
        fact: '用户长期关注算法', confidence: 0.93, kind: 'expertise',
        source: 'public_persona', observedAt: snapshot.generatedAt
      }, {
        fact: '截至 2026-08-06，用户近期关注公开技术写作。', confidence: 0.91, kind: 'recent_focus',
        source: 'public_persona', observedAt: snapshot.generatedAt
      }];
      snapshot.memoryFactsMarkdownFingerprint = publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);

      const facts = publicPersonaImportFacts(snapshot, '2026-09-03T10:00:00.000Z');

      expect(facts.length).assertEqual(2);
      expect(facts[0].fact).assertEqual('用户长期关注算法');
      expect(facts[1].fact.indexOf('截至 2026-09-03') === 0).assertTrue();
    });

    it('rejects oversized or sensitive model inference before persistence', 0, () => {
      const tooMany: PublicPersonaInference = {
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要',
        identityAndExperience: [], expertise: ['一', '二', '三', '四'], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [],
        mbtiType: 'ENTP', mbtiConfidence: 68
      };
      const tooLong: PublicPersonaInference = {
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要', identityAndExperience: [],
        expertise: ['这是一个明显超过三十二个字符并且不应被写入本地画像的模型输出字段内容'], interestsAndPreferences: [],
        communicationStyle: [], recentFocus: [], personalityInference: [], mbtiType: 'ENTP', mbtiConfidence: 68
      };
      const sensitive: PublicPersonaInference = {
        titleName: 'Ada Lovelace', oneLineSummary: '公开资料摘要', identityAndExperience: [], expertise: [],
        interestsAndPreferences: [], communicationStyle: [], recentFocus: [], personalityInference: ['政治立场偏保守'],
        mbtiType: 'ENTP', mbtiConfidence: 68
      };

      expect(parsePublicPersonaInference(JSON.stringify(tooMany))).assertEqual(null);
      expect(parsePublicPersonaInference(JSON.stringify(tooLong))).assertEqual(null);
      expect(parsePublicPersonaInference(JSON.stringify(sensitive))).assertEqual(null);
    });

    it('rejects unsupported inference and invalid persisted snapshots', 0, () => {
      expect(parsePublicPersonaInference('{"mbtiType":"not-mbti"}')).assertEqual(null);
      const invalidSnapshot: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: '# Ada',
        primaryAvatarUrl: 'https://example.com/not-owned.png',
        sources: [],
        generatedAt: '2026-08-06T00:00:00.000Z',
        mbtiHidden: false
      };
      expect(sanitizePublicPersonaSnapshot(invalidSnapshot)).assertEqual(null);

      const validSources: PublicPersonaSourceRef[] = [{
        platform: 'bilibili',
        profileUrl: 'https://space.bilibili.com/123456',
        avatarUrl: 'https://i0.hdslb.com/bfs/face/abc.jpg',
        sourceUrls: ['https://space.bilibili.com/123456'],
        fetchedAt: '2026-08-06T00:00:00.000Z'
      }];
      const validSnapshot: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: [
          '# Ada Lovelace',
          '',
          '> 喜欢把复杂问题讲清楚。',
          '',
          '## 身份与经历',
          '- 软件先驱',
          '',
          '## 专长',
          '- 算法',
          '',
          '## 兴趣与偏好',
          '- 数学',
          '',
          '## 沟通风格',
          '- 结构化',
          '',
          '## 近期关注',
          '- 公开技术写作',
          '',
          '## 性格推断',
          'ENTP · 68%',
          '',
          '## 已确认账号',
          '- [bilibili](https://space.bilibili.com/123456) · 123456'
        ].join('\n'),
        primaryAvatarUrl: 'https://i0.hdslb.com/bfs/face/abc.jpg',
        sources: validSources,
        generatedAt: '2026-08-06T00:00:00.000Z',
        mbtiHidden: false
      };
      expect(sanitizePublicPersonaSnapshot(validSnapshot) === null).assertFalse();
    });

    it('rejects invalid edited MBTI and filtered-empty source URLs', 0, () => {
      const baseline = validSnapshot();
      const invalidMbti: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown.replace('ENTP · 68%', 'ENFP · 101%'),
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: baseline.sources,
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };
      const invalidSourceUrls: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown,
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: [{
          platform: 'github', profileUrl: 'https://github.com/ada', avatarUrl: 'https://github.com/ada.png',
          sourceUrls: ['not-a-url'], fetchedAt: baseline.generatedAt
        }],
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };
      const invalidMbtiSection: PublicPersonaSnapshot = {
        schemaVersion: 1,
        personaMarkdown: baseline.personaMarkdown + '\n\n## MBTI 推测\n- XXXX · 50%',
        primaryAvatarUrl: baseline.primaryAvatarUrl,
        sources: baseline.sources,
        generatedAt: baseline.generatedAt,
        mbtiHidden: baseline.mbtiHidden
      };

      expect(sanitizePublicPersonaSnapshot(invalidMbti)).assertEqual(null);
      expect(sanitizePublicPersonaSnapshot(invalidSourceUrls)).assertEqual(null);
      expect(sanitizePublicPersonaSnapshot(invalidMbtiSection)).assertEqual(null);
    });

    it('hides MBTI content from the normal preview while retaining editable Markdown', 0, () => {
      const markdown = validSnapshot().personaMarkdown + '\n\n## MBTI 推测\n- ENTP · 68%';
      const hidden = publicPersonaPreviewMarkdown(markdown, true);
      const visible = publicPersonaPreviewMarkdown(markdown, false);

      expect(hidden.indexOf('## MBTI 推测')).assertEqual(-1);
      expect(hidden.indexOf('ENTP · 68%')).assertEqual(-1);
      expect(visible).assertContain('## MBTI 推测');
    });

    it('hides the empty MBTI placeholder from the normal preview', 0, () => {
      const markdown = validSnapshot().personaMarkdown.replace('ENTP · 68%', 'MBTI 暂无');
      expect(publicPersonaPreviewMarkdown(markdown, true)).assertContain('## 性格推断');
      expect(publicPersonaPreviewMarkdown(markdown, true)).assertContain('## 已确认账号');
      expect(publicPersonaPreviewMarkdown(markdown, true).indexOf('MBTI 暂无')).assertEqual(-1);
    });

    it('persists a snapshot and deletes only the snapshot data', 0, () => {
      const native = nativePreferences();
      const store = new PublicPersonaStore(native);
      const snapshot = validSnapshot();
      snapshot.memoryFacts = [{
        fact: '用户长期关注算法', confidence: 0.93, kind: 'expertise',
        source: 'public_persona', observedAt: snapshot.generatedAt
      }];
      snapshot.memoryFactsMarkdownFingerprint = publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
      snapshot.importedMarkdownFingerprint = publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
      expect(store.onboardingSeen()).assertFalse();
      store.markOnboardingSeen();
      store.save(snapshot);

      const reloaded = new PublicPersonaStore(native).load();
      expect(reloaded === null).assertFalse();
      expect(reloaded?.personaMarkdown).assertContain('Ada Lovelace');
      expect(reloaded?.sources.length).assertEqual(1);
      expect(publicPersonaMemoryFacts(reloaded as PublicPersonaSnapshot)[0].fact)
        .assertEqual('用户长期关注算法');
      expect(isPublicPersonaImported(reloaded as PublicPersonaSnapshot)).assertTrue();

      store.deleteSnapshot();
      expect(store.load()).assertEqual(null);
      expect(store.onboardingSeen()).assertTrue();
      expect(native.getSync(PUBLIC_PERSONA_SNAPSHOT_KEY, '')).assertEqual('');
      expect(native.getSync(PUBLIC_PERSONA_ONBOARDING_KEY, false)).assertTrue();
    });

    it('returns false when a snapshot save or delete cannot be verified', 0, () => {
      const native = new MemoryPreferences();
      const store = new PublicPersonaStore(native as Object as preferences.Preferences);
      native.failPut = true;
      expect(store.save(validSnapshot())).assertFalse();

      native.failPut = false;
      expect(store.save(validSnapshot())).assertTrue();
      native.failDelete = true;
      expect(store.deleteSnapshot()).assertFalse();
    });

    it('treats corrupt stored JSON as an empty persona', 0, () => {
      const native = nativePreferences();
      native.putSync(PUBLIC_PERSONA_SNAPSHOT_KEY, '{');
      expect(new PublicPersonaStore(native).load()).assertEqual(null);
    });

    it('rebuilds edited persona memory facts with one memory-only model call and host filtering', 0, async () => {
      let modelCalls = 0;
      let modelPrompt = '';
      let systemPrompt = '';
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'),
      async (_settings: LocalModelSettings, prompt: string, _history: A2uiMessage[],
        system?: string): Promise<DirectModelCallResult> => {
        modelCalls++;
        modelPrompt = prompt;
        systemPrompt = system ?? '';
        const memoryCandidates: PublicPersonaMemoryCandidate[] = [
          { fact: '用户喜欢编曲', confidence: 0.95, kind: 'preference' },
          { fact: '用户近期关注开源音频工具', confidence: 0.91, kind: 'recent_focus' },
          { fact: '用户偶尔谈到电影', confidence: 0.6, kind: 'preference' },
          { fact: '用户的 MBTI 是 ENTP', confidence: 0.99, kind: 'identity' },
          { fact: '用户的政治立场明确', confidence: 0.99, kind: 'identity' },
          { fact: '喜欢结构化表达', confidence: 0.98, kind: 'communication_style' }
        ];
        const response: PublicPersonaMemoryCandidatesFixture = { memoryCandidates };
        return {
          ok: true,
          raw: JSON.stringify(response),
          error: '', requestDebug: '', assistantDebug: ''
        };
      });
      const snapshot = publicPersonaSnapshotAfterMarkdownEdit(
        validSnapshot(), validSnapshot().personaMarkdown.replace('- 数学', '- 编曲'));

      const facts = await client.rebuildMemoryFacts(snapshot, modelSettings(), '2026-09-04T08:00:00.000Z');
      const rebuilt = publicPersonaSnapshotWithMemoryFacts(snapshot, facts);

      expect(modelCalls).assertEqual(1);
      expect(modelPrompt).assertContain('"personaMarkdown"');
      expect(modelPrompt).assertContain('"memoryObservedAt":"2026-09-04T08:00:00.000Z"');
      expect(systemPrompt).assertContain('用户已保存并确认');
      expect(systemPrompt).assertContain('不设固定上限');
      expect(facts.length).assertEqual(2);
      expect(facts[0].fact).assertEqual('用户喜欢编曲');
      expect(facts[1].fact.indexOf('截至 2026-09-04') === 0).assertTrue();
      expect(publicPersonaMemoryFactsAreCurrent(rebuilt)).assertTrue();
      expect(publicPersonaImportFacts(rebuilt, '2026-09-04T08:00:00.000Z').length).assertEqual(2);
    });

    it('routes edited persona memory rebuild through the memory task runner and rejects invalid schema once',
      0, async () => {
      let legacyModelCalls = 0;
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'),
      async (): Promise<DirectModelCallResult> => {
        legacyModelCalls += 1;
        return { ok: false, raw: '', error: 'legacy path must not run', requestDebug: '', assistantDebug: '' };
      });
      const snapshot = publicPersonaSnapshotAfterMarkdownEdit(
        validSnapshot(), validSnapshot().personaMarkdown.replace('- 数学', '- 编曲'));
      const validCaller = new PersonaMemoryRunnerCaller(
        '{"memoryCandidates":[{"fact":"用户喜欢编曲","confidence":0.95,"kind":"preference"}]}'
      );
      const validLogger = new PersonaMemoryRunnerLogger();
      const validRunner = new MemoryModelTaskRunner({
        settingsProvider: modelSettings,
        caller: validCaller,
        logger: validLogger
      });

      const facts = await client.rebuildMemoryFacts(
        snapshot, modelSettings(), '2026-09-04T08:00:00.000Z', validRunner
      );

      expect(facts.length).assertEqual(1);
      expect(validCaller.calls).assertEqual(1);
      expect(validCaller.prompt).assertContain('"personaMarkdown"');
      expect(validCaller.prompt).assertContain('"memoryObservedAt":"2026-09-04T08:00:00.000Z"');
      expect(validCaller.systemPrompt).assertContain('用户已保存并确认');
      expect(validLogger.lines[0].indexOf('modelCallCount=1')).assertLarger(-1);
      expect(legacyModelCalls).assertEqual(0);

      const invalidCaller = new PersonaMemoryRunnerCaller('{"memoryCandidates":"invalid"}');
      const invalidLogger = new PersonaMemoryRunnerLogger();
      const invalidRunner = new MemoryModelTaskRunner({
        settingsProvider: modelSettings,
        caller: invalidCaller,
        logger: invalidLogger
      });
      let rejected = false;
      try {
        await client.rebuildMemoryFacts(
          snapshot, modelSettings(), '2026-09-04T08:00:00.000Z', invalidRunner
        );
      } catch (_error) {
        rejected = true;
      }
      expect(rejected).assertTrue();
      expect(invalidCaller.calls).assertEqual(1);
      expect(invalidLogger.lines[0].indexOf('memory_model_schema_invalid')).assertLarger(-1);
      expect(invalidLogger.lines[0].indexOf('modelCallCount=1')).assertLarger(-1);
      expect(legacyModelCalls).assertEqual(0);
    });

    it('rejects failed or malformed persona memory rebuild model output', 0, async () => {
      expect(parsePublicPersonaMemoryFacts('{"memoryCandidates":"invalid"}',
        '2026-09-04T08:00:00.000Z')).assertEqual(null);
      expect(parsePublicPersonaMemoryFacts(
        '{"memoryCandidates":[{"fact":"不是自包含事实","confidence":0.2,"kind":"preference"}]}',
        '2026-09-04T08:00:00.000Z')).assertEqual(null);
      expect(parsePublicPersonaMemoryFacts('{"memoryCandidates":[]}',
        '2026-09-04T08:00:00.000Z')?.length ?? -1).assertEqual(0);
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'), async (): Promise<DirectModelCallResult> => ({
          ok: false, raw: '', error: '模型不可用', requestDebug: '', assistantDebug: ''
        }));
      let rejected = false;

      try {
        await client.rebuildMemoryFacts(validSnapshot(), modelSettings(), '2026-09-04T08:00:00.000Z');
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
    });

    it('builds from native probe evidence without calling Firecrawl', 0, async () => {
      const toolIds: string[] = [];
      let modelPrompt = '';
      let systemPrompt = '';
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> => {
        toolIds.push(toolId);
        return dataResult(toolId, new Object(), 'empty');
      }, async (_settings: LocalModelSettings, prompt: string, _history: A2uiMessage[], system?: string): Promise<DirectModelCallResult> => {
        modelPrompt = prompt;
        systemPrompt = system ?? '';
        return modelInferenceResult('ENTP', [{
          fact: '用户长期关注算法与软件工程', confidence: 0.93, kind: 'expertise'
        }]);
      }, (): string => '2026-08-10T00:00:00.000Z', 70000, async (url: string) => {
        if (url === 'https://api.github.com/users/ada') {
          return { statusCode: 200, body: '{"login":"ada","name":"Ada Lovelace","avatar_url":"https://github.com/ada.png","html_url":"https://github.com/ada","bio":"Native public bio"}' };
        }
        return { statusCode: 404, body: 'Not Found' };
      });
      const candidates = await client.discover('ada', 'exact', (_progress): void => {});

      const snapshot = await client.buildSnapshot(candidates, modelSettings(), (_progress): void => {}, '用户确认姓名');

      expect(toolIds.length).assertEqual(0);
      expect(modelPrompt).assertContain('Native public bio');
      expect(modelPrompt).assertContain('"confirmedDisplayName":"用户确认姓名"');
      expect(modelPrompt).assertContain('"memoryObservedAt":"2026-08-10T00:00:00.000Z"');
      expect(systemPrompt).assertContain('"titleName"');
      expect(systemPrompt).assertContain('"personalityInference"');
      expect(systemPrompt).assertContain('"mbtiConfidence"');
      expect(snapshot.sources.length).assertEqual(1);
      expect(snapshot.sources[0].platform).assertEqual('github');
      expect(publicPersonaMemoryFacts(snapshot).length).assertEqual(1);
      expect(publicPersonaMemoryFacts(snapshot)[0].fact).assertEqual('用户长期关注算法与软件工程');
      expect((parsePublicPersonaMarkdown(snapshot.personaMarkdown) as PublicPersonaInference).titleName)
        .assertEqual('用户确认姓名');
    });

    it('keeps discovery evidence isolated when searches finish out of order', 0, async () => {
      const first = new DeferredProfileResult();
      const second = new DeferredProfileResult();
      let githubCalls = 0;
      let modelPrompt = '';
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'),
      async (_settings: LocalModelSettings, prompt: string): Promise<DirectModelCallResult> => {
        modelPrompt = prompt;
        return modelInferenceResult();
      }, (): string => '2026-08-10T00:00:00.000Z', 70000, async (url: string) => {
        if (url === 'https://api.github.com/users/ada') {
          githubCalls++;
          return githubCalls === 1 ? first.promise : second.promise;
        }
        return { statusCode: 404, body: 'Not Found' };
      });

      const oldDiscovery = client.discover('ada', 'exact', (_progress): void => {});
      const newDiscovery = client.discover('ada', 'exact', (_progress): void => {});
      second.resolve({ statusCode: 200, body: '{"login":"ada","name":"Ada","avatar_url":' +
        '"https://github.com/ada.png","html_url":"https://github.com/ada","bio":"new bio"}' });
      const candidates = await newDiscovery;
      first.resolve({ statusCode: 200, body: '{"login":"ada","name":"Ada","avatar_url":' +
        '"https://github.com/ada.png","html_url":"https://github.com/ada","bio":"old bio"}' });
      await oldDiscovery;

      await client.buildSnapshot(candidates, modelSettings(), (_progress): void => {}, 'Ada');
      expect(modelPrompt).assertContain('new bio');
      expect(modelPrompt.indexOf('old bio')).assertEqual(-1);
    });

    it('rejects an empty confirmed display name before reading evidence or calling the model', 0, async () => {
      let toolCalls = 0;
      let modelCalls = 0;
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> => {
        toolCalls++;
        return dataResult(toolId, new Object(), 'empty');
      }, async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult();
      });
      let rejected = false;

      try {
        await client.buildSnapshot([], modelSettings(), (_progress): void => {}, '   ');
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(toolCalls).assertEqual(0);
      expect(modelCalls).assertEqual(0);
    });

    it('uses one plain Markdown page read only when all native evidence is unusable', 0, async () => {
      const calls: string[] = [];
      const selected = [
        { id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada Lovelace', username: 'ada', avatarUrl: '', exists: true, ownershipConfidence: 0.9, ownershipBand: 'high', selected: true, providerState: 'success', fetchedAt: '2026-08-10T00:00:00.000Z', sourceUrl: 'https://github.com/ada' },
        { id: 'x:ada', platform: 'x', profileUrl: 'https://x.com/ada', displayName: 'Ada Lovelace', username: 'ada', avatarUrl: 'https://x.com/ada.png', exists: true, ownershipConfidence: 0.8, ownershipBand: 'high', selected: true, providerState: 'success', fetchedAt: '2026-08-10T00:00:00.000Z', sourceUrl: 'https://x.com/ada' }
      ] as PublicPersonaCandidate[];
      const client = new PublicPersonaClient(async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        calls.push(toolId + ':' + JSON.stringify(args));
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '# Ada Lovelace\n\n![avatar](https://github.com/ada.png)\n\nPublic profile with published AI work.')]);
      }, async (): Promise<DirectModelCallResult> => modelInferenceResult(),
      (): string => '2026-08-10T00:00:00.000Z');

      const snapshot = await client.buildSnapshot(selected, modelSettings(), (_progress): void => {}, 'Ada');

      expect(calls.length).assertEqual(1);
      expect(calls[0]).assertContain('web.page.read');
      expect(calls[0]).assertContain('"question":""');
      expect(calls[0]).assertContain('https://github.com/ada');
      expect(snapshot.sources.length).assertEqual(2);
      expect(snapshot.sources.some((source: PublicPersonaSourceRef): boolean => source.platform === 'x')).assertTrue();
      expect(snapshot.primaryAvatarUrl).assertEqual('https://github.com/ada.png');
    });

    it('does not call the model when confirmed accounts still have no readable content', 0, async () => {
      let modelCalls = 0;
      const selected = [{
        id: 'github:ada', platform: 'github', profileUrl: 'https://github.com/ada', displayName: 'Ada', username: 'ada',
        avatarUrl: 'https://github.com/ada.png', exists: true, ownershipConfidence: 0.9, ownershipBand: 'high',
        selected: true, providerState: 'success', fetchedAt: '2026-08-10T00:00:00.000Z', sourceUrl: 'https://github.com/ada'
      }] as PublicPersonaCandidate[];
      const client = new PublicPersonaClient(async (toolId: string): Promise<DataResult> =>
        dataResult(toolId, new Object(), 'empty'), async (): Promise<DirectModelCallResult> => {
          modelCalls++;
          return modelInferenceResult();
        });
      let rejected = false;

      try {
        await client.buildSnapshot(selected, modelSettings(), (_progress): void => {}, 'Ada');
      } catch (_error) {
        rejected = true;
      }

      expect(rejected).assertTrue();
      expect(modelCalls).assertEqual(0);
    });

    it('reinfers MBTI with at most one plain Markdown page read', 0, async () => {
      const calls: string[] = [];
      let modelCalls = 0;
      const snapshot = validSnapshot();
      snapshot.sources.unshift({
        platform: 'npm', profileUrl: 'https://www.npmjs.com/~ada', avatarUrl: '',
        displayName: 'Ada on NPM', username: 'ada',
        sourceUrls: ['https://www.npmjs.com/~ada'], fetchedAt: '2026-08-10T00:00:00.000Z'
      });
      const client = new PublicPersonaClient(async (toolId: string, _prompt: string, args: Object | null): Promise<DataResult> => {
        calls.push(toolId + ':' + JSON.stringify(args));
        return dynamicDataResult(toolId, [dynamicResult(toolId, 'success', '# Ada\n\n![avatar](https://github.com/ada.png)\n\nPublic profile biography.')]);
      }, async (): Promise<DirectModelCallResult> => {
        modelCalls++;
        return modelInferenceResult('INFJ');
      }, (): string => '2026-08-10T00:00:00.000Z');

      const result = await client.reinferMbti(snapshot, modelSettings());

      expect(calls.length).assertEqual(1);
      expect(calls[0]).assertContain('"question":""');
      expect(calls[0]).assertContain('https://github.com/ada');
      expect(calls[0].indexOf('npmjs.com')).assertEqual(-1);
      expect(result.mbtiType).assertEqual('INFJ');
      expect(modelCalls).assertEqual(1);
    });

    it('reinfers MBTI from a legacy source without saved display fields', 0, async () => {
      const snapshot = validSnapshot();
      snapshot.sources[0].displayName = undefined;
      snapshot.sources[0].username = undefined;
      let requestedUrl = '';
      const client = new PublicPersonaClient(async (_toolId: string, _prompt: string,
        args: Object | null): Promise<DataResult> => {
        requestedUrl = JSON.stringify(args);
        return dynamicDataResult('web.page.read', [dynamicResult('web.page.read', 'success',
          '# Ada\n\n![avatar](https://github.com/ada.png)\n\nPublic profile biography.')]);
      }, async (): Promise<DirectModelCallResult> => modelInferenceResult('INTJ'));

      const result = await client.reinferMbti(snapshot, modelSettings());

      expect(requestedUrl).assertContain('https://github.com/ada');
      expect(result.mbtiType).assertEqual('INTJ');
    });

  });
}
