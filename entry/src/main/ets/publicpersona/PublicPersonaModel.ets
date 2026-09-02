export type PublicPersonaPlatform =
  'bilibili' | 'zhihu' | 'weibo' | 'github' |
  'qq' | 'tieba' | 'douban' | 'npm' | 'leetcode_cn' | 'gitee' | 'gitcode' | 'yuque' | 'cnblogs' | 'v2ex' | 'matrix' |
  'tuchong' | 'stackoverflow' | 'gitlab' | 'bitbucket' | 'dockerhub' | 'devto' | 'producthunt' | 'keybase' |
  'huggingface' | 'csdn' | 'medium' | 'mastodon' | 'aboutme' | 'telegram' | 'behance' | 'steam' |
  'scratch' | 'hackernoon' | 'inaturalist' | 'disqus' | 'bluesky' | 'chess' | 'boosty' |
  'lemmy' | 'substack' | 'codeberg' | 'codeforces' | 'leetcode' | 'picsart' | 'dailymotion' | 'topcoder' |
  'mixcloud' | 'gravatar' | 'gitea' | 'launchpad' | 'deviantart' |
  'hackerrank' | 'discogs' | 'opencollective' | 'misskey' |
  'x' | 'youtube' | 'linkedin';

export type PublicPersonaProviderState =
  'idle' | 'running' | 'success' | 'partial' | 'empty' |
  'needs_auth' | 'blocked_by_site' | 'rate_limited' |
  'credits_exhausted' | 'timeout' | 'error';

export type PublicPersonaPhase =
  'welcome' | 'input' | 'discovering' | 'awaiting_confirmation' |
  'reading' | 'summarizing' | 'complete' | 'error';

export type PublicPersonaOwnershipBand = 'high' | 'possible';

export type PublicPersonaSearchMode = 'exact' | 'fuzzy';

export type PublicPersonaProbeState = 'found' | 'not_found' | 'unknown';

export type PublicPersonaProbeCheckType = 'message' | 'status_code';

export interface PublicPersonaJsonIdentity {
  rootPath: string[];
  usernamePath: string[];
  displayNamePath: string[];
  avatarPath: string[];
  bioPath: string[];
  canonicalUrlPath?: string[];
  usernameSuffix?: string;
  upgradePicsartAvatar?: boolean;
}

export interface PublicPersonaProbe {
  platform: PublicPersonaPlatform;
  label: string;
  domains: string[];
  profilePathPatterns: string[];
  displayUrlTemplate: string;
  probeUrlTemplate: string;
  usernamePattern: string;
  caseSensitiveUsername: boolean;
  checkType: PublicPersonaProbeCheckType;
  enabled: boolean;
  usernameClaimed: string;
  usernameUnclaimed: string;
  presenceMarkers: string[];
  missingMarkers: string[];
  errorMarkers: string[];
  requestHeaders?: Record<string, string>;
  jsonIdentity?: PublicPersonaJsonIdentity;
}

export interface PublicPersonaIdentity {
  displayName: string;
  username: string;
  avatarUrl: string;
  canonicalUrl: string;
  linkedUrls: string[];
}

export interface PublicPersonaCandidate {
  id: string;
  platform: PublicPersonaPlatform;
  profileUrl: string;
  displayName: string;
  username: string;
  avatarUrl: string;
  exists: true;
  ownershipConfidence: number;
  ownershipBand: PublicPersonaOwnershipBand;
  selected: boolean;
  providerState: PublicPersonaProviderState;
  fetchedAt: string;
  sourceUrl: string;
}

export interface PublicPersonaPostEvidence {
  url: string;
  title: string;
  text: string;
  publishedAt: string;
  pinned: boolean;
}

export interface PublicPersonaAccountEvidence {
  platform: PublicPersonaPlatform;
  profileUrl: string;
  avatarUrl: string;
  displayName: string;
  username: string;
  bio: string;
  posts: PublicPersonaPostEvidence[];
  sourceUrls: string[];
  fetchedAt: string;
  providerState: PublicPersonaProviderState;
}

export type PublicPersonaMemoryFactKind =
  'identity' | 'expertise' | 'preference' | 'communication_style' | 'recent_focus';

export interface PublicPersonaMemoryCandidate {
  fact: string;
  confidence: number;
  kind: PublicPersonaMemoryFactKind;
}

export interface PublicPersonaMemoryFact extends PublicPersonaMemoryCandidate {
  source: 'public_persona';
  observedAt: string;
}

export interface PublicPersonaInference {
  titleName: string;
  oneLineSummary: string;
  identityAndExperience: string[];
  expertise: string[];
  interestsAndPreferences: string[];
  communicationStyle: string[];
  recentFocus: string[];
  personalityInference: string[];
  mbtiType: string;
  mbtiConfidence: number;
  /** Optional for compatibility with model responses produced before public-persona memory projection. */
  memoryCandidates?: PublicPersonaMemoryCandidate[];
}

export interface PublicPersonaSourceRef {
  platform: PublicPersonaPlatform;
  profileUrl: string;
  avatarUrl: string;
  displayName?: string;
  username?: string;
  sourceUrls: string[];
  fetchedAt: string;
}

export interface PublicPersonaSnapshot {
  schemaVersion: 1;
  personaMarkdown: string;
  primaryAvatarUrl: string;
  sources: PublicPersonaSourceRef[];
  generatedAt: string;
  mbtiHidden: boolean;
  /** Optional so persisted schemaVersion 1 snapshots written by older releases remain readable. */
  memoryFacts?: PublicPersonaMemoryFact[];
  /** Fingerprint of personaMarkdown that the model-derived memoryFacts describe. */
  memoryFactsMarkdownFingerprint?: string;
  /** Current personaMarkdown fingerprint after a successful explicit memory import. */
  importedMarkdownFingerprint?: string;
}

export interface PublicPersonaProgress {
  completed: number;
  total: number;
  found: number;
  notFound: number;
  unknown: number;
  platform: PublicPersonaPlatform;
  state: PublicPersonaProviderState;
  message: string;
}

export interface PublicPersonaProfileUrl {
  platform: PublicPersonaPlatform;
  url: string;
}

const COMMON_PROBE_ERRORS: string[] = [
  'captcha', 'rate limit', 'too many requests', '访问频繁', '安全验证', 'cloudflare', 'just a moment'
];

const PLATFORMS: PublicPersonaProbe[] = [
  {
    platform: 'bilibili', label: '哔哩哔哩', domains: ['space.bilibili.com'],
    profilePathPatterns: ['/[0-9]+$'], displayUrlTemplate: 'https://space.bilibili.com/{username}',
    probeUrlTemplate: 'https://api.bilibili.com/x/web-interface/card?mid={username}', usernamePattern: '^[0-9]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: '8047632', usernameUnclaimed: '999999999999999999',
    presenceMarkers: ['"card":{'],
    missingMarkers: ['"code":-404', '该账号不存在', '用户不存在'],
    errorMarkers: ['访问频繁', '安全验证', 'captcha', '"code":-352']
  },
  {
    platform: 'zhihu', label: '知乎', domains: ['zhihu.com'],
    profilePathPatterns: ['/people/'], displayUrlTemplate: 'https://www.zhihu.com/people/{username}',
    probeUrlTemplate: 'https://www.zhihu.com/api/v4/members/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: true, checkType: 'message', enabled: false,
    usernameClaimed: 'zhihu', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['"url_token"'],
    missingMarkers: ['你访问的页面不存在', '用户不存在'],
    errorMarkers: ['登录后查看更多', '安全验证', '访问频繁', 'account/unhuman']
  },
  {
    platform: 'weibo', label: '微博', domains: ['weibo.com'],
    profilePathPatterns: ['/u/', '/n/', '/[0-9]+$'], displayUrlTemplate: 'https://weibo.com/n/{username}',
    probeUrlTemplate: 'https://weibo.com/ajax/profile/info?screen_name={username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: true, checkType: 'message', enabled: true,
    usernameClaimed: 'clairekuo', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['{"ok":1,"data":{"user":'],
    missingMarkers: ['该昵称当前没有人使用', '抱歉，您访问的页面不存在'],
    errorMarkers: ['访问频次过高', '安全验证', '登录']
  },
  {
    platform: 'github', label: 'GitHub', domains: ['github.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://github.com/{username}',
    probeUrlTemplate: 'https://api.github.com/users/{username}', usernamePattern: '^[a-zA-Z0-9-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'octocat', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['"login":'],
    missingMarkers: [],
    errorMarkers: ['rate limit', 'captcha', 'verify your account']
  },
  {
    platform: 'qq', label: 'QQ 空间', domains: ['qzone.qq.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://user.qzone.qq.com/{username}',
    probeUrlTemplate: 'https://users.qzone.qq.com/fcg-bin/cgi_get_portrait.fcg?uins={username}',
    usernamePattern: '^[1-9][0-9]{4,9}$', caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: '10001', usernameUnclaimed: '3999999999', presenceMarkers: ['portraitCallBack('],
    missingMarkers: ['"",0]', '"error"'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'scratch', label: 'Scratch', domains: ['scratch.mit.edu'], profilePathPatterns: ['/users/'],
    displayUrlTemplate: 'https://scratch.mit.edu/users/{username}',
    probeUrlTemplate: 'https://api.scratch.mit.edu/users/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'griffpatch', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['username'],
      avatarPath: ['profile', 'images', '90x90'], bioPath: ['profile', 'bio'] }
  },
  {
    platform: 'hackernoon', label: 'HackerNoon', domains: ['hackernoon.com'], profilePathPatterns: ['/u/'],
    displayUrlTemplate: 'https://hackernoon.com/u/{username}',
    probeUrlTemplate: 'https://us-central1-hackernoon-app.cloudfunctions.net/app/profilesApi?handle={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'god', usernameUnclaimed: 'noonewouldeverusethis71', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['profile'], usernamePath: ['handle'], displayNamePath: ['displayName'],
      avatarPath: ['avatar'], bioPath: ['bio'] }
  },
  {
    platform: 'inaturalist', label: 'iNaturalist', domains: ['inaturalist.org'], profilePathPatterns: ['/people/'],
    displayUrlTemplate: 'https://www.inaturalist.org/people/{username}',
    probeUrlTemplate: 'https://api.inaturalist.org/v1/users/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'kueda', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['results', '0'], usernamePath: ['login'], displayNamePath: ['name'],
      avatarPath: ['icon_url'], bioPath: ['description'] }
  },
  {
    platform: 'disqus', label: 'Disqus', domains: ['disqus.com'], profilePathPatterns: ['/by/'],
    displayUrlTemplate: 'https://disqus.com/by/{username}',
    probeUrlTemplate: 'https://disqus.com/api/3.0/users/details?user=username%3A{username}&attach=userFlaggedUser&api_key=E8Uh5l5fHZ6gD8U3KycjAIAk46f68Zw7C6eW8WSjZvCLXebZ7p0r1yrYDrLilk2F',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'blue', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"username"'],
    missingMarkers: ['User matching query does not exist'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['response'], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['avatar', 'large', 'permalink'], bioPath: ['about'] }
  },
  {
    platform: 'bluesky', label: 'Bluesky', domains: ['bsky.app'], profilePathPatterns: ['/profile/'],
    displayUrlTemplate: 'https://bsky.app/profile/{username}.bsky.social',
    probeUrlTemplate: 'https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor={username}.bsky.social',
    usernamePattern: '^[a-zA-Z0-9-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'shamerli', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"did"'],
    missingMarkers: ['Profile not found'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['handle'], displayNamePath: ['displayName'],
      avatarPath: ['avatar'], bioPath: ['description'], usernameSuffix: '.bsky.social' }
  },
  {
    platform: 'chess', label: 'Chess.com', domains: ['chess.com'], profilePathPatterns: ['/member/'],
    displayUrlTemplate: 'https://www.chess.com/member/{username}',
    probeUrlTemplate: 'https://api.chess.com/pub/player/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'sexytwerker69', usernameUnclaimed: 'aublurbrxm', presenceMarkers: ['"player_id"'],
    missingMarkers: ['not found', 'not_found'], errorMarkers: COMMON_PROBE_ERRORS,
    requestHeaders: { 'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
      '(KHTML, like Gecko) Chrome/89.0.4389.114 Safari/537.36' },
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['avatar'], bioPath: ['status'] }
  },
  {
    platform: 'boosty', label: 'Boosty', domains: ['boosty.to'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://boosty.to/{username}',
    probeUrlTemplate: 'https://api.boosty.to/v1/blog/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'soxoj', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"id"'],
    missingMarkers: ['blog_not_found'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['blogUrl'], displayNamePath: ['owner', 'name'],
      avatarPath: ['owner', 'avatarUrl'], bioPath: ['description'] }
  },
  {
    platform: 'tieba', label: '百度贴吧', domains: ['tieba.baidu.com'],
    profilePathPatterns: ['/home/main'], displayUrlTemplate: 'https://tieba.baidu.com/home/main?un={username}',
    probeUrlTemplate: 'https://tieba.baidu.com/i/sys/user_json?un={username}&ie=utf-8',
    usernamePattern: '^[a-zA-Z0-9._-]+$', caseSensitiveUsername: true, checkType: 'message', enabled: false,
    usernameClaimed: 'maigret', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"raw_name"'],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['raw_name'], displayNamePath: ['name_show'],
      avatarPath: ['portrait'], bioPath: [] }
  },
  {
    platform: 'douban', label: '豆瓣', domains: ['douban.com'],
    profilePathPatterns: ['/people/'], displayUrlTemplate: 'https://www.douban.com/people/{username}/',
    probeUrlTemplate: 'https://www.douban.com/people/{username}/', usernamePattern: '^[a-zA-Z0-9._-]+$',
    caseSensitiveUsername: true, checkType: 'message', enabled: false,
    usernameClaimed: 'darkmage', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['db-usr-profile'],
    missingMarkers: ['返回首页'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'npm', label: 'NPM', domains: ['npmjs.com'],
    profilePathPatterns: ['/~'], displayUrlTemplate: 'https://www.npmjs.com/~{username}',
    probeUrlTemplate: 'https://registry.npmjs.org/-/v1/search?text=maintainer:{username}&size=1',
    usernamePattern: '^[a-zA-Z0-9._-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'sindresorhus', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['"objects":[{'], missingMarkers: ['"total":0'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'leetcode_cn', label: '力扣', domains: ['leetcode.cn'],
    profilePathPatterns: ['/u/'], displayUrlTemplate: 'https://leetcode.cn/u/{username}/',
    probeUrlTemplate: 'https://leetcode.cn/graphql/?userSlug={username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'leetcode', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['"userProfilePublicProfile":{'], missingMarkers: ['"userProfilePublicProfile":null'],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['data', 'userProfilePublicProfile'], usernamePath: ['username'],
      displayNamePath: ['profile', 'realName'], avatarPath: ['profile', 'userAvatar'],
      bioPath: ['profile', 'aboutMe'] }
  },
  {
    platform: 'gitee', label: 'Gitee', domains: ['gitee.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://gitee.com/{username}', probeUrlTemplate: 'https://gitee.com/api/v5/users/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'wizzer', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['login'], displayNamePath: ['name'],
      avatarPath: ['avatar_url'], bioPath: ['bio'], canonicalUrlPath: ['html_url'] }
  },
  {
    platform: 'gitcode', label: 'GitCode', domains: ['gitcode.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://gitcode.com/{username}', probeUrlTemplate: 'https://gitcode.com/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'chatgpt', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['rel="canonical"'], missingMarkers: ['AtomGit - 全球开发者的开源社区'],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'yuque', label: '语雀', domains: ['yuque.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.yuque.com/{username}', probeUrlTemplate: 'https://www.yuque.com/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'yuque', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'cnblogs', label: '博客园', domains: ['cnblogs.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.cnblogs.com/{username}', probeUrlTemplate: 'https://www.cnblogs.com/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'adam', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'v2ex', label: 'V2EX', domains: ['v2ex.com'], profilePathPatterns: ['/member/'],
    displayUrlTemplate: 'https://v2ex.com/member/{username}',
    probeUrlTemplate: 'https://v2ex.com/api/members/show.json?username={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'adam', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['username'],
      avatarPath: ['avatar_large'], bioPath: ['tagline'], canonicalUrlPath: ['url'] }
  },
  {
    platform: 'matrix', label: 'Matrix', domains: ['matrix-client.matrix.org'],
    profilePathPatterns: ['/_matrix/client/v3/profile/@'],
    displayUrlTemplate: 'https://matrix-client.matrix.org/_matrix/client/v3/profile/@{username}:matrix.org',
    probeUrlTemplate: 'https://matrix-client.matrix.org/_matrix/client/v3/profile/@{username}:matrix.org',
    usernamePattern: '^[a-zA-Z0-9._=-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'soxoj', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: [], displayNamePath: ['displayname'],
      avatarPath: ['avatar_url'], bioPath: [] }
  },
  {
    platform: 'tuchong', label: '图虫', domains: ['tuchong.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://{username}.tuchong.com/', probeUrlTemplate: 'https://{username}.tuchong.com/',
    usernamePattern: '^[a-zA-Z0-9]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'foto', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [' - 图虫'],
    missingMarkers: ['图虫创意-正版商用素材库'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'stackoverflow', label: 'Stack Overflow', domains: ['stackoverflow.com'],
    profilePathPatterns: ['/users/'], displayUrlTemplate: 'https://stackoverflow.com/users/filter?search={username}',
    probeUrlTemplate: 'https://api.stackexchange.com/2.3/users?order=desc&sort=name&inname={username}&site=stackoverflow',
    usernamePattern: '^[a-zA-Z0-9._-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'maigret', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"items":[{'],
    missingMarkers: ['"items":[]'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'gitlab', label: 'GitLab', domains: ['gitlab.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://gitlab.com/{username}', probeUrlTemplate: 'https://gitlab.com/api/v4/users?username={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'blue', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"username"'],
    missingMarkers: ['[]'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'bitbucket', label: 'Bitbucket', domains: ['bitbucket.org'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://bitbucket.org/{username}/',
    probeUrlTemplate: 'https://api.bitbucket.org/2.0/workspaces/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]{1,30}$', caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'atlassian', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'dockerhub', label: 'Docker Hub', domains: ['hub.docker.com'], profilePathPatterns: ['/u/'],
    displayUrlTemplate: 'https://hub.docker.com/u/{username}/', probeUrlTemplate: 'https://hub.docker.com/v2/users/{username}/',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'jpetazzo', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'devto', label: 'DEV Community', domains: ['dev.to'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://dev.to/{username}',
    probeUrlTemplate: 'https://dev.to/api/users/by_username?url={username}',
    usernamePattern: '^[a-zA-Z][a-zA-Z0-9_-]*$', caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'cassidoo', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['profile_image'], bioPath: ['summary'] }
  },
  {
    platform: 'producthunt', label: 'Product Hunt', domains: ['producthunt.com'], profilePathPatterns: ['/@'],
    displayUrlTemplate: 'https://www.producthunt.com/@{username}', probeUrlTemplate: 'https://www.producthunt.com/@{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'rajiv_ayyangar', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: [':{"data":{"profile":{"__typename"'], missingMarkers: ['We seem to have lost this page'],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'keybase', label: 'Keybase', domains: ['keybase.io'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://keybase.io/{username}',
    probeUrlTemplate: 'https://keybase.io/_/api/1.0/user/lookup.json?usernames={username}',
    usernamePattern: '^[a-zA-Z0-9_]+$', caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'oconnor663', usernameUnclaimed: 'zzzxqv123', presenceMarkers: ['"basics"'],
    missingMarkers: ['"them":[null]'], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'huggingface', label: 'Hugging Face', domains: ['huggingface.co'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://huggingface.co/{username}', probeUrlTemplate: 'https://huggingface.co/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'blue', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'csdn', label: 'CSDN', domains: ['csdn.net'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://blog.csdn.net/{username}', probeUrlTemplate: 'https://blog.csdn.net/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'csdnnews', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['data-username="'],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'medium', label: 'Medium', domains: ['medium.com'], profilePathPatterns: ['/@'],
    displayUrlTemplate: 'https://medium.com/@{username}', probeUrlTemplate: 'https://medium.com/feed/@{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'sindresorhus', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'mastodon', label: 'Mastodon', domains: ['fosstodon.org'], profilePathPatterns: ['/@'],
    displayUrlTemplate: 'https://fosstodon.org/@{username}',
    probeUrlTemplate: 'https://fosstodon.org/api/v1/accounts/lookup?acct={username}',
    usernamePattern: '^[a-zA-Z0-9_]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'kev', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['display_name'],
      avatarPath: ['avatar'], bioPath: ['note'], canonicalUrlPath: ['url'] }
  },
  {
    platform: 'aboutme', label: 'About.me', domains: ['about.me'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://about.me/{username}', probeUrlTemplate: 'https://about.me/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'jeff', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'telegram', label: 'Telegram', domains: ['t.me'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://t.me/{username}', probeUrlTemplate: 'https://t.me/{username}',
    usernamePattern: '^[a-zA-Z][a-zA-Z0-9_]{4,}$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'BotFather', usernameUnclaimed: 'noonewouldevereverusethis9',
    presenceMarkers: ['tgme_page_photo_image'],
    missingMarkers: ['<meta name="robots" content="noindex, nofollow">',
      '<meta property="twitter:title" content="Telegram: Contact'],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'behance', label: 'Behance', domains: ['behance.net'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.behance.net/{username}', probeUrlTemplate: 'https://www.behance.net/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'blue', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS, requestHeaders: { 'User-Agent': 'Curl' }
  },
  {
    platform: 'steam', label: 'Steam', domains: ['steamcommunity.com'], profilePathPatterns: ['/id/'],
    displayUrlTemplate: 'https://steamcommunity.com/id/{username}',
    probeUrlTemplate: 'https://steamcommunity.com/id/{username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'blue', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['profile_header'], missingMarkers: ['The specified profile could not be found'],
    errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'lemmy', label: 'Lemmy', domains: ['lemmy.world'], profilePathPatterns: ['/u/'],
    displayUrlTemplate: 'https://lemmy.world/u/{username}',
    probeUrlTemplate: 'https://lemmy.world/api/v3/user?username={username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'Rooki', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['person_view', 'person'], usernamePath: ['name'], displayNamePath: ['display_name'],
      avatarPath: ['avatar'], bioPath: ['bio'] }
  },
  {
    platform: 'substack', label: 'Substack', domains: ['substack.com'], profilePathPatterns: ['/@'],
    displayUrlTemplate: 'https://substack.com/@{username}',
    probeUrlTemplate: 'https://substack.com/api/v1/user/{username}/public_profile',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'user23', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['handle'], displayNamePath: ['name'],
      avatarPath: ['photo_url'], bioPath: ['bio'] }
  },
  {
    platform: 'codeberg', label: 'Codeberg', domains: ['codeberg.org'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://codeberg.org/{username}',
    probeUrlTemplate: 'https://codeberg.org/api/v1/users/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'forgejo', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['login'], displayNamePath: ['full_name'],
      avatarPath: ['avatar_url'], bioPath: ['description'] }
  },
  {
    platform: 'codeforces', label: 'Codeforces', domains: ['codeforces.com'], profilePathPatterns: ['/profile/'],
    displayUrlTemplate: 'https://codeforces.com/profile/{username}',
    probeUrlTemplate: 'https://codeforces.com/api/user.info?handles={username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'jiangly', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"status":"OK"'],
    missingMarkers: ['"status":"FAILED"'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['result', '0'], usernamePath: ['handle'], displayNamePath: ['firstName'],
      avatarPath: ['avatar'], bioPath: ['organization'] }
  },
  {
    platform: 'leetcode', label: 'LeetCode', domains: ['leetcode.com'], profilePathPatterns: ['/u/'],
    displayUrlTemplate: 'https://leetcode.com/u/{username}',
    probeUrlTemplate: 'https://leetcode.com/graphql/?username={username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: true,
    usernameClaimed: 'soxoj', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"matchedUser"'],
    missingMarkers: ['"matchedUser":null'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['data', 'matchedUser'], usernamePath: ['username'],
      displayNamePath: ['profile', 'realName'], avatarPath: ['profile', 'userAvatar'],
      bioPath: ['profile', 'aboutMe'] }
  },
  {
    platform: 'picsart', label: 'Picsart', domains: ['picsart.com'], profilePathPatterns: ['/u/'],
    displayUrlTemplate: 'https://picsart.com/u/{username}',
    probeUrlTemplate: 'https://api.picsart.com/users/show.json?username={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'adam', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: ['"status":"success"'],
    missingMarkers: ['user_not_found'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['photo'], bioPath: ['about'], upgradePicsartAvatar: true }
  },
  {
    platform: 'dailymotion', label: 'Dailymotion', domains: ['dailymotion.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.dailymotion.com/{username}',
    probeUrlTemplate: 'https://api.dailymotion.com/user/{username}?fields=id,username,screenname,avatar_720_url,description,url',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'DailymotionUSA', usernameUnclaimed: 'rstnodkwzr', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['screenname'],
      avatarPath: ['avatar_720_url'], bioPath: ['description'], canonicalUrlPath: ['url'] }
  },
  {
    platform: 'topcoder', label: 'Topcoder', domains: ['topcoder.com'], profilePathPatterns: ['/members/'],
    displayUrlTemplate: 'https://www.topcoder.com/members/{username}',
    probeUrlTemplate: 'https://api.topcoder.com/v5/members/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'Petr', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['handle'], displayNamePath: ['firstName'],
      avatarPath: ['photoURL'], bioPath: ['description'] }
  },
  {
    platform: 'mixcloud', label: 'Mixcloud', domains: ['mixcloud.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.mixcloud.com/{username}/',
    probeUrlTemplate: 'https://api.mixcloud.com/{username}/', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'jenny', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['pictures', 'large'], bioPath: ['description'], canonicalUrlPath: ['url'] }
  },
  {
    platform: 'gravatar', label: 'Gravatar', domains: ['gravatar.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://gravatar.com/{username}',
    probeUrlTemplate: 'https://en.gravatar.com/{username}.json', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'automattic', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['requestHash'], missingMarkers: ['User not found'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['entry', '0'], usernamePath: ['preferredUsername'],
      displayNamePath: ['displayName'], avatarPath: ['thumbnailUrl'], bioPath: ['aboutMe'],
      canonicalUrlPath: ['profileUrl'] }
  },
  {
    platform: 'gitea', label: 'Gitea', domains: ['gitea.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://gitea.com/{username}',
    probeUrlTemplate: 'https://gitea.com/api/v1/users/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'lunny', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['login'], displayNamePath: ['full_name'],
      avatarPath: ['avatar_url'], bioPath: ['description'], canonicalUrlPath: ['html_url'] }
  },
  {
    platform: 'launchpad', label: 'Launchpad', domains: ['launchpad.net'], profilePathPatterns: ['/~'],
    displayUrlTemplate: 'https://launchpad.net/~{username}',
    probeUrlTemplate: 'https://api.launchpad.net/1.0/~{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'mark', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['name'], displayNamePath: ['display_name'],
      avatarPath: ['logo_link'], bioPath: ['description'], canonicalUrlPath: ['web_link'] }
  },
  {
    platform: 'deviantart', label: 'DeviantArt', domains: ['deviantart.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://www.deviantart.com/{username}',
    probeUrlTemplate: 'https://www.deviantart.com/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'yuumei', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS
  },
  {
    platform: 'hackerrank', label: 'HackerRank', domains: ['hackerrank.com'], profilePathPatterns: ['/profile/'],
    displayUrlTemplate: 'https://www.hackerrank.com/profile/{username}',
    probeUrlTemplate: 'https://www.hackerrank.com/rest/contests/master/hackers/{username}/profile',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'uwi', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['model'], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['avatar'], bioPath: ['short_bio'] }
  },
  {
    platform: 'discogs', label: 'Discogs', domains: ['discogs.com'], profilePathPatterns: ['/user/'],
    displayUrlTemplate: 'https://www.discogs.com/user/{username}',
    probeUrlTemplate: 'https://api.discogs.com/users/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'status_code', enabled: true,
    usernameClaimed: 'discogs', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [],
    missingMarkers: [], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['avatar_url'], bioPath: ['profile'], canonicalUrlPath: ['uri'] }
  },
  {
    platform: 'opencollective', label: 'Open Collective', domains: ['opencollective.com'], profilePathPatterns: ['/'],
    displayUrlTemplate: 'https://opencollective.com/{username}',
    probeUrlTemplate: 'https://api.opencollective.com/graphql/v2?slug={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'sindresorhus', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['"account":{'], missingMarkers: ['"account":null'], errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: ['data', 'account'], usernamePath: ['slug'], displayNamePath: ['name'],
      avatarPath: ['image'], bioPath: ['description'] }
  },
  {
    platform: 'misskey', label: 'Misskey', domains: ['misskey.io'], profilePathPatterns: ['/@'],
    displayUrlTemplate: 'https://misskey.io/@{username}',
    probeUrlTemplate: 'https://misskey.io/api/users/show?username={username}',
    usernamePattern: '^[a-zA-Z0-9_-]+$', caseSensitiveUsername: false, checkType: 'status_code', enabled: false,
    usernameClaimed: 'syuilo', usernameUnclaimed: 'noonewouldeverusethis7', presenceMarkers: [], missingMarkers: [],
    errorMarkers: COMMON_PROBE_ERRORS,
    jsonIdentity: { rootPath: [], usernamePath: ['username'], displayNamePath: ['name'],
      avatarPath: ['avatarUrl'], bioPath: ['description'] }
  },
  {
    platform: 'x', label: 'X', domains: ['x.com', 'twitter.com'],
    profilePathPatterns: ['/'], displayUrlTemplate: 'https://x.com/{username}',
    probeUrlTemplate: 'https://x.com/{username}',
    usernamePattern: '^[a-zA-Z0-9_]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'X', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['profile:username'],
    missingMarkers: ['This account doesn’t exist', '页面不存在'],
    errorMarkers: ['rate limit', 'Bad guest token', 'captcha']
  },
  {
    platform: 'youtube', label: 'YouTube', domains: ['youtube.com'],
    profilePathPatterns: ['/@'], displayUrlTemplate: 'https://www.youtube.com/@{username}',
    probeUrlTemplate: 'https://www.youtube.com/@{username}/about', usernamePattern: '^[a-zA-Z0-9._-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'YouTube', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['visitorData'],
    missingMarkers: ['This page isn’t available', '页面不存在'],
    errorMarkers: ['unusual traffic', 'sign in to confirm']
  },
  {
    platform: 'linkedin', label: 'LinkedIn', domains: ['linkedin.com'],
    profilePathPatterns: ['/in/'], displayUrlTemplate: 'https://www.linkedin.com/in/{username}',
    probeUrlTemplate: 'https://www.linkedin.com/in/{username}', usernamePattern: '^[a-zA-Z0-9_-]+$',
    caseSensitiveUsername: false, checkType: 'message', enabled: false,
    usernameClaimed: 'satyanadella', usernameUnclaimed: 'noonewouldeverusethis7',
    presenceMarkers: ['og:title'],
    missingMarkers: ['Page not found'],
    errorMarkers: ['security verification']
  }
];

const MBTI_TYPES: string[] = [
  'ISTJ', 'ISFJ', 'INFJ', 'INTJ', 'ISTP', 'ISFP', 'INFP', 'INTP',
  'ESTP', 'ESFP', 'ENFP', 'ENTP', 'ESTJ', 'ESFJ', 'ENFJ', 'ENTJ'
];

interface PublicPersonaHostPath {
  host: string;
  path: string;
}

function isPlatform(value: string): boolean {
  for (let index = 0; index < PLATFORMS.length; index++) {
    if (PLATFORMS[index].platform === value) {
      return true;
    }
  }
  return false;
}

function platformForHost(host: string): PublicPersonaPlatform | null {
  const normalized = host.toLowerCase();
  for (let index = 0; index < PLATFORMS.length; index++) {
    const probe = PLATFORMS[index];
    for (let domainIndex = 0; domainIndex < probe.domains.length; domainIndex++) {
      const domain = probe.domains[domainIndex];
      if (probe.platform === 'bilibili') {
        if (normalized === domain) {
          return probe.platform;
        }
        continue;
      }
      if (normalized === domain || normalized.endsWith('.' + domain)) {
        return probe.platform;
      }
    }
  }
  return null;
}

function hostAndPath(value: string): PublicPersonaHostPath | null {
  const schemeEnd = value.indexOf('://');
  if (schemeEnd <= 0) {
    return null;
  }
  const authorityStart = schemeEnd + 3;
  let end = value.length;
  const slash = value.indexOf('/', authorityStart);
  if (slash >= 0 && slash < end) {
    end = slash;
  }
  const authority = value.substring(authorityStart, end);
  if (authority.length === 0 || authority.indexOf('@') >= 0 || authority.indexOf(':') >= 0) {
    return null;
  }
  const path = end < value.length ? value.substring(end) : '/';
  return { host: authority, path: path };
}

function normalizedProfileUrl(value: string): string {
  const trimmed = value.trim();
  if (trimmed.endsWith('/') && trimmed.length > 1) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

function probeForPlatform(platform: PublicPersonaPlatform): PublicPersonaProbe | null {
  for (let index = 0; index < PLATFORMS.length; index++) {
    if (PLATFORMS[index].platform === platform) {
      return PLATFORMS[index];
    }
  }
  return null;
}

function profilePath(value: string): string {
  return value.endsWith('/') && value.length > 1 ? value.substring(0, value.length - 1) : value;
}

function valueFromTemplate(template: string, value: string): string {
  const marker = '{username}';
  const markerIndex = template.indexOf(marker);
  if (markerIndex < 0) {
    return '';
  }
  const prefix = template.substring(0, markerIndex);
  const suffix = template.substring(markerIndex + marker.length);
  if (!value.toLowerCase().startsWith(prefix.toLowerCase()) ||
    !value.toLowerCase().endsWith(suffix.toLowerCase()) || value.length <= prefix.length + suffix.length) {
    return '';
  }
  return value.substring(prefix.length, value.length - suffix.length);
}

function templateProfileUsername(probe: PublicPersonaProbe, host: string, path: string): string {
  const templateParts = hostAndPath(probe.displayUrlTemplate);
  if (templateParts === null || templateParts.path.indexOf('?') >= 0) {
    return '';
  }
  const templateHost = templateParts.host;
  const normalizedPath = profilePath(path);
  const templatePath = profilePath(templateParts.path);
  if (templateHost.indexOf('{username}') >= 0) {
    if (normalizedPath.toLowerCase() !== templatePath.toLowerCase()) {
      return '';
    }
    return valueFromTemplate(templateHost, host);
  }
  const normalizedHost = host.toLowerCase().replace(/^www\./, '');
  const normalizedTemplateHost = templateHost.toLowerCase().replace(/^www\./, '');
  const hostMatches = probe.platform === 'x' ?
    (normalizedHost === 'x.com' || normalizedHost === 'twitter.com') &&
      (normalizedTemplateHost === 'x.com' || normalizedTemplateHost === 'twitter.com') :
    normalizedHost === normalizedTemplateHost;
  if (!hostMatches) {
    return '';
  }
  return valueFromTemplate(templatePath, normalizedPath);
}

function profileUsername(probe: PublicPersonaProbe, host: string, path: string): string {
  const normalized = profilePath(path).toLowerCase();
  if (probe.platform === 'weibo') {
    if ((normalized.indexOf('/u/') === 0 || normalized.indexOf('/n/') === 0) && normalized.substring(3).indexOf('/') < 0) {
      return profilePath(path).substring(3);
    }
    return /^\/[0-9]+$/.test(normalized) ? normalized.substring(1) : '';
  }
  if (probe.platform === 'youtube' && normalized.indexOf('/channel/') === 0 && normalized.substring(9).indexOf('/') < 0) {
    return '';
  }
  if (probe.platform === 'stackoverflow') {
    const match = /^\/users\/[0-9]+\/([^/]+)$/i.exec(profilePath(path));
    return match === null ? '' : match[1];
  }
  return templateProfileUsername(probe, host, path);
}

function profileUsernameAllowed(probe: PublicPersonaProbe, username: string, path: string): boolean {
  if (username.length === 0 || path.indexOf('..') >= 0) {
    return false;
  }
  if (probe.platform === 'github' || probe.platform === 'x') {
    const reserved: string[] = probe.platform === 'github' ?
      ['settings', 'explore', 'topics', 'collections', 'trending', 'events', 'marketplace', 'notifications', 'login', 'signup', 'search', 'about'] :
      ['home', 'explore', 'search', 'i', 'settings', 'notifications', 'messages', 'compose', 'login', 'signup'];
    if (reserved.indexOf(username.toLowerCase()) >= 0) {
      return false;
    }
  }
  try {
    return new RegExp(probe.usernamePattern).test(username);
  } catch (_error) {
    return false;
  }
}

function nonEmptyString(value: Object | string | number | boolean | undefined): string {
  return typeof value === 'string' ? value.trim() : '';
}

function stringArray(value: Object | string | number | boolean | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const values: string[] = [];
  const raw = value as Object[];
  for (let index = 0; index < raw.length; index++) {
    if (typeof raw[index] === 'string' && (raw[index] as string).trim().length > 0) {
      values.push((raw[index] as string).trim());
    }
  }
  return values;
}

function markdownList(values: string[]): string {
  if (values.length === 0) {
    return '- 暂无公开信息';
  }
  return values.map((value: string): string => '- ' + value).join('\n');
}

function validHttps(value: string): boolean {
  return value.startsWith('https://') && value.indexOf(' ') < 0 && value.indexOf('\n') < 0;
}

function validTimestamp(value: string): boolean {
  return value.trim().length >= 10 && value.indexOf(' ') < 0 && value.indexOf('\n') < 0;
}

export function publicPersonaCatalog(): PublicPersonaProbe[] {
  return PLATFORMS.filter((probe: PublicPersonaProbe): boolean => probe.enabled)
    .map((probe: PublicPersonaProbe): PublicPersonaProbe => ({
    platform: probe.platform,
    label: probe.label,
    domains: probe.domains.slice(),
    profilePathPatterns: probe.profilePathPatterns.slice(),
    displayUrlTemplate: probe.displayUrlTemplate,
    probeUrlTemplate: probe.probeUrlTemplate,
    usernamePattern: probe.usernamePattern,
    caseSensitiveUsername: probe.caseSensitiveUsername,
    checkType: probe.checkType,
    enabled: probe.enabled,
    usernameClaimed: probe.usernameClaimed,
    usernameUnclaimed: probe.usernameUnclaimed,
    presenceMarkers: probe.presenceMarkers.slice(),
    missingMarkers: probe.missingMarkers.slice(),
    errorMarkers: probe.errorMarkers.slice(),
    requestHeaders: probe.requestHeaders,
    jsonIdentity: probe.jsonIdentity === undefined ? undefined : {
      rootPath: probe.jsonIdentity.rootPath.slice(),
      usernamePath: probe.jsonIdentity.usernamePath.slice(),
      displayNamePath: probe.jsonIdentity.displayNamePath.slice(),
      avatarPath: probe.jsonIdentity.avatarPath.slice(),
      bioPath: probe.jsonIdentity.bioPath.slice(),
      canonicalUrlPath: probe.jsonIdentity.canonicalUrlPath?.slice(),
      usernameSuffix: probe.jsonIdentity.usernameSuffix,
      upgradePicsartAvatar: probe.jsonIdentity.upgradePicsartAvatar
    }
    }));
}

export function publicPersonaPlatformLabel(platform: PublicPersonaPlatform): string {
  for (let index = 0; index < PLATFORMS.length; index++) {
    if (PLATFORMS[index].platform === platform) {
      return PLATFORMS[index].label;
    }
  }
  return platform;
}

export function normalizePublicPersonaUsername(value: string): string | null {
  const trimmed = value.trim();
  const username = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  if (username.length === 0 || username.length > 64 || !/^[a-zA-Z0-9._-]+$/.test(username)) {
    return null;
  }
  return username;
}

export function publicPersonaProfileUrl(probe: PublicPersonaProbe, username: string): string | null {
  const normalized = normalizePublicPersonaUsername(username);
  if (normalized === null) {
    return null;
  }
  try {
    if (!new RegExp(probe.usernamePattern).test(normalized)) {
      return null;
    }
  } catch (_error) {
    return null;
  }
  if (probe.platform === 'weibo' && /^[0-9]+$/.test(normalized)) {
    return 'https://weibo.com/u/' + normalized;
  }
  return probe.displayUrlTemplate.replace('{username}', normalized);
}

function publicPersonaAliasTokens(value: string): string[] {
  const camelSeparated = value
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2');
  return camelSeparated.toLowerCase().split(/[^a-z0-9\u4e00-\u9fff]+/)
    .filter((token: string): boolean => token.length > 0);
}

export function publicPersonaUsernameAliases(username: string, displayNames: string[]): string[] {
  const aliases: string[] = [];
  const add = (value: string): void => {
    const normalized = value.trim().toLowerCase();
    if (normalized.length > 1 && aliases.indexOf(normalized) < 0 && aliases.length < 24) {
      aliases.push(normalized);
    }
  };
  const addTokenVariants = (tokens: string[]): void => {
    if (tokens.length === 0) {
      return;
    }
    const reversed = tokens.slice().reverse();
    const separators: string[] = ['', '_', '.', '-'];
    for (let index = 0; index < separators.length; index++) {
      add(tokens.join(separators[index]));
      if (tokens.length > 1) {
        add(reversed.join(separators[index]));
      }
    }
  };
  const normalized = normalizePublicPersonaUsername(username);
  if (normalized === null) {
    return aliases;
  }
  add(normalized);
  addTokenVariants(publicPersonaAliasTokens(normalized));
  for (let index = 0; index < displayNames.length; index++) {
    addTokenVariants(publicPersonaAliasTokens(displayNames[index]));
  }
  return aliases;
}

function bodyHasMarker(body: string, markers: string[]): boolean {
  const normalized = body.toLowerCase();
  for (let index = 0; index < markers.length; index++) {
    if (normalized.indexOf(markers[index].toLowerCase()) >= 0) {
      return true;
    }
  }
  return false;
}

export function classifyPublicPersonaProbe(
  probe: PublicPersonaProbe,
  statusCode: number,
  body: string
): PublicPersonaProbeState {
  if (bodyHasMarker(body, probe.errorMarkers)) {
    return 'unknown';
  }
  if (statusCode === 401 || statusCode === 403 || statusCode === 429 || statusCode >= 500 || statusCode <= 0) {
    return 'unknown';
  }
  if (statusCode === 404) {
    return 'not_found';
  }
  if (statusCode === 410) {
    return 'unknown';
  }
  if (probe.platform === 'leetcode' && /"message"\s*:\s*"That user does not exist\."/i.test(body) &&
    body.indexOf('"matchedUser":null') >= 0) {
    return 'not_found';
  }
  if ((probe.platform === 'leetcode' || probe.platform === 'leetcode_cn') &&
    /"errors"\s*:\s*\[\s*\{/.test(body)) {
    return 'unknown';
  }
  const reliableMissing = probe.platform === 'bilibili' && body.indexOf('"code":-404') >= 0 ||
    probe.platform === 'npm' && /"(?:total|objects)"\s*:\s*(?:0|\[\])/.test(body) ||
    probe.platform === 'stackoverflow' && body.indexOf('"items":[]') >= 0 ||
    probe.platform === 'gitlab' && body.trim() === '[]' ||
    probe.platform === 'keybase' && body.indexOf('"them":[null]') >= 0 ||
    (probe.platform === 'leetcode' || probe.platform === 'leetcode_cn') &&
      (body.indexOf('"matchedUser":null') >= 0 ||
        body.indexOf('"userProfilePublicProfile":null') >= 0);
  if (reliableMissing) {
    return 'not_found';
  }
  if (probe.checkType === 'message' && bodyHasMarker(body, probe.missingMarkers)) {
    return 'not_found';
  }
  if (probe.platform === 'tieba' && statusCode >= 200 && statusCode < 300) {
    const match = /"no"\s*:\s*([0-9]+)/.exec(body);
    if (match === null) return 'unknown';
    const code = Number(match[1]);
    return code === 0 ? 'found' : code === 1130029 ? 'not_found' : 'unknown';
  }
  if (probe.checkType === 'message') {
    if (probe.platform === 'youtube' && statusCode >= 200 && statusCode < 300) {
      return 'found';
    }
    return statusCode >= 200 && statusCode < 300 && bodyHasMarker(body, probe.presenceMarkers) ?
      'found' : 'unknown';
  }
  return statusCode >= 200 && statusCode < 300 ? 'found' : 'unknown';
}

export function parsePublicProfileUrl(value: string): PublicPersonaProfileUrl | null {
  const trimmed = value.trim();
  if (/^https:\/\/tieba\.baidu\.com\/home\/main\?un=[a-zA-Z0-9._-]+$/.test(trimmed)) {
    return { platform: 'tieba', url: trimmed };
  }
  if (!/^https:\/\//i.test(trimmed) || trimmed.indexOf('?') >= 0 || trimmed.indexOf('#') >= 0) {
    return null;
  }
  const parts = hostAndPath(trimmed);
  if (parts === null) {
    return null;
  }
  const path = parts.path.endsWith('/') && parts.path.length > 1 ?
    parts.path.substring(0, parts.path.length - 1) : parts.path;
  const platform = platformForHost(parts.host);
  if (platform === null) {
    return null;
  }
  const probe = probeForPlatform(platform);
  const username = probe === null ? '' : profileUsername(probe, parts.host, path);
  if (probe === null || !profileUsernameAllowed(probe, username, path)) {
    return null;
  }
  return { platform: platform, url: normalizedProfileUrl(trimmed) };
}

export function publicPersonaUsernameFromProfileUrl(value: string): string {
  const parsed = parsePublicProfileUrl(value);
  if (parsed === null) {
    return '';
  }
  if (parsed.platform === 'tieba') {
    return parsed.url.substring(parsed.url.indexOf('?un=') + 4);
  }
  const parts = hostAndPath(parsed.url);
  const probe = probeForPlatform(parsed.platform);
  return parts === null || probe === null ? '' : profileUsername(probe, parts.host, parts.path);
}

export function scorePublicPersonaCandidate(
  seed: PublicPersonaIdentity,
  candidate: PublicPersonaIdentity
): number {
  const seedUsername = seed.username.trim().replace(/^@/, '').toLowerCase();
  const candidateUsername = candidate.username.trim().replace(/^@/, '').toLowerCase();
  const seedName = seed.displayName.trim().toLowerCase();
  const candidateName = candidate.displayName.trim().toLowerCase();
  let score = 0;
  const usernameAliases: string[] = [];
  const addAlias = (value: string): void => {
    const alias = value.toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]/g, '');
    if (alias.length > 1 && usernameAliases.indexOf(alias) < 0) {
      usernameAliases.push(alias);
    }
  };
  addAlias(seedUsername);
  const nameTokens = seedName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
  addAlias(nameTokens.join(''));
  addAlias(nameTokens.slice().reverse().join(''));
  for (let index = 0; index < usernameAliases.length; index++) {
    const alias = usernameAliases[index];
    if (candidateUsername === alias) {
      score = Math.max(score, 0.55);
    } else if (candidateUsername.indexOf(alias) >= 0) {
      score = Math.max(score, 0.45);
    }
  }
  if (seedName.length > 0 && seedName === candidateName) {
    score += 0.25;
  }
  const seedLinks = [seed.canonicalUrl].concat(seed.linkedUrls);
  const canonical = candidate.canonicalUrl;
  const crossSiteLink = candidate.linkedUrls.some((url: string): boolean =>
    url !== canonical && seedLinks.indexOf(url) >= 0);
  if (canonical.length > 0 && (canonical === seed.canonicalUrl || crossSiteLink)) {
    score += 0.20;
  }
  if (score === 0 && seedName.length > 0 && candidateName.length > 0) {
    const seedTokens = seedName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
    const candidateTokens = candidateName.split(/[^a-z0-9\u4e00-\u9fff]+/).filter((token: string): boolean => token.length > 1);
    for (let index = 0; index < seedTokens.length; index++) {
      if (candidateTokens.indexOf(seedTokens[index]) >= 0) {
        score = 0.10;
        break;
      }
    }
  }
  return Math.min(1, Number(score.toFixed(2)));
}

export function publicPersonaOwnershipBand(confidence: number): PublicPersonaOwnershipBand | null {
  if (confidence >= 0.75) {
    return 'high';
  }
  if (confidence >= 0.45) {
    return 'possible';
  }
  return null;
}

function inferenceJsonText(raw: string): string {
  const trimmed = raw.trim();
  const start = trimmed.indexOf('{');
  const end = trimmed.lastIndexOf('}');
  return start >= 0 && end > start ? trimmed.substring(start, end + 1) : trimmed;
}

export const PUBLIC_PERSONA_MEMORY_MIN_CONFIDENCE: number = 0.85;

const PUBLIC_PERSONA_SENSITIVE_FACT_PATTERN: RegExp =
  /(政治立场|政治倾向|宗教信仰|性取向|健康状况|疾病诊断|残疾|种族血统|民族血统|精确位置|收入水平|资产状况|political views?|religious beliefs?|sexual orientation|health condition|medical diagnosis|disability|ethnicity|financial status)/i;

const PUBLIC_PERSONA_MEMORY_EXCLUDED_PATTERN: RegExp =
  /(MBTI|性格|人格|心理类型|性格推断|性格猜测|personality type|personality inference)/i;

function publicPersonaMemoryKind(value: string): PublicPersonaMemoryFactKind | null {
  if (value === 'identity' || value === 'expertise' || value === 'preference' ||
    value === 'communication_style' || value === 'recent_focus') {
    return value as PublicPersonaMemoryFactKind;
  }
  return null;
}

function atomicPublicPersonaMemoryFact(value: string, maxLength: number = 200): string | null {
  const fact = value.replace(/\u3000/g, ' ').replace(/\s+/g, ' ').trim();
  const selfContained = /^(用户|该用户|the user)/i.test(fact) ||
    /^截至 \d{4}-\d{2}-\d{2}，(用户|该用户|the user)/i.test(fact);
  if (fact.length === 0 || fact.length > maxLength || PUBLIC_PERSONA_SENSITIVE_FACT_PATTERN.test(fact) ||
    PUBLIC_PERSONA_MEMORY_EXCLUDED_PATTERN.test(fact) || !selfContained) {
    return null;
  }
  for (let index = 0; index < fact.length; index++) {
    if ('。！？?!'.indexOf(fact.charAt(index)) < 0) continue;
    let cursor = index + 1;
    while (cursor < fact.length && ('。！？?!'.indexOf(fact.charAt(cursor)) >= 0 ||
      /\s/.test(fact.charAt(cursor)))) cursor++;
    if (cursor < fact.length) return null;
    break;
  }
  return fact;
}

function parsePublicPersonaMemoryCandidates(
  value: Object | string | number | boolean | undefined,
  maxFactLength: number = 200
): PublicPersonaMemoryCandidate[] {
  if (!Array.isArray(value)) return [];
  const output: PublicPersonaMemoryCandidate[] = [];
  const rawItems = value as Object[];
  for (let index = 0; index < rawItems.length; index++) {
    const item = rawItems[index];
    if (typeof item !== 'object' || item === null || Array.isArray(item)) continue;
    const raw = item as Record<string, Object | string | number | boolean>;
    const fact = atomicPublicPersonaMemoryFact(nonEmptyString(raw['fact']), maxFactLength);
    const confidence = raw['confidence'];
    const kind = publicPersonaMemoryKind(nonEmptyString(raw['kind']));
    if (fact === null || kind === null || typeof confidence !== 'number' ||
      !Number.isFinite(confidence) || confidence < PUBLIC_PERSONA_MEMORY_MIN_CONFIDENCE || confidence > 1) continue;
    output.push({ fact: fact, confidence: confidence, kind: kind });
  }
  return output;
}

/**
 * Converts every qualifying model candidate into a memory-ready fact. It intentionally applies no
 * count limit, time decay, exact deduplication, or semantic deduplication.
 */
function projectPublicPersonaMemoryCandidates(
  candidates: PublicPersonaMemoryCandidate[],
  observedAt: string,
  maxFactLength: number = 200
): PublicPersonaMemoryFact[] {
  if (!validTimestamp(observedAt)) return [];
  const facts: PublicPersonaMemoryFact[] = [];
  const observedDate = observedAt.substring(0, 10);
  for (let index = 0; index < candidates.length; index++) {
    const candidate = candidates[index];
    const fact = atomicPublicPersonaMemoryFact(candidate.fact, maxFactLength);
    const kind = publicPersonaMemoryKind(candidate.kind);
    if (fact === null || kind === null || !Number.isFinite(candidate.confidence) ||
      candidate.confidence < PUBLIC_PERSONA_MEMORY_MIN_CONFIDENCE || candidate.confidence > 1) continue;
    let memoryFact = fact;
    if (kind === 'recent_focus' && memoryFact.indexOf(observedDate) < 0) {
      const withoutTerminal = memoryFact.replace(/[。！？?!]+$/, '');
      memoryFact = '截至 ' + observedDate + '，' + withoutTerminal + '。';
    }
    facts.push({
      fact: memoryFact,
      confidence: candidate.confidence,
      kind: kind,
      source: 'public_persona',
      observedAt: observedAt
    });
  }
  return facts;
}

export function projectPublicPersonaMemoryFacts(
  inference: PublicPersonaInference,
  observedAt: string
): PublicPersonaMemoryFact[] {
  return projectPublicPersonaMemoryCandidates(inference.memoryCandidates ?? [], observedAt);
}

/** Parses a memory-only model response and applies every host confidence, safety, and atomicity filter. */
export function parsePublicPersonaMemoryFacts(
  raw: string,
  observedAt: string
): PublicPersonaMemoryFact[] | null {
  if (!validTimestamp(observedAt)) return null;
  try {
    const parsed = JSON.parse(inferenceJsonText(raw)) as Record<string, Object | string | number | boolean | Object[]>;
    if (!Array.isArray(parsed['memoryCandidates'])) return null;
    const rawCandidates = parsed['memoryCandidates'] as Object[];
    const candidates = parsePublicPersonaMemoryCandidates(rawCandidates);
    if (rawCandidates.length > 0 && candidates.length === 0) return null;
    return projectPublicPersonaMemoryCandidates(candidates, observedAt);
  } catch (_error) {
    return null;
  }
}

export function publicPersonaMemoryFacts(snapshot: PublicPersonaSnapshot): PublicPersonaMemoryFact[] {
  const stored = snapshot.memoryFacts ?? [];
  return stored.map((fact: PublicPersonaMemoryFact): PublicPersonaMemoryFact => ({
    fact: fact.fact,
    confidence: fact.confidence,
    kind: fact.kind,
    source: 'public_persona',
    observedAt: fact.observedAt
  }));
}

export function publicPersonaMemoryFactsAreCurrent(snapshot: PublicPersonaSnapshot): boolean {
  const basis = (snapshot.memoryFactsMarkdownFingerprint ?? '').trim();
  return validPublicPersonaMarkdownFingerprint(basis) &&
    basis === publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
}

function publicPersonaFingerprintHex(value: number): string {
  let hex = (value >>> 0).toString(16);
  while (hex.length < 8) hex = '0' + hex;
  return hex;
}

function canonicalPublicPersonaMarkdown(markdown: string): string {
  return markdown.replace(/\r\n/g, '\n').replace(/\r/g, '\n').trim();
}

/** Stable non-cryptographic content identity used only for local import idempotency. */
export function publicPersonaMarkdownFingerprint(markdown: string): string {
  const canonical = canonicalPublicPersonaMarkdown(markdown);
  let hash = 2166136261;
  for (let index = 0; index < canonical.length; index++) {
    hash ^= canonical.charCodeAt(index);
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
    hash >>>= 0;
  }
  return 'fnv1a32:' + publicPersonaFingerprintHex(hash) + ':' + canonical.length.toString();
}

function validPublicPersonaMarkdownFingerprint(value: string): boolean {
  return /^fnv1a32:[0-9a-f]{8}:[0-9]+$/.test(value);
}

export function isPublicPersonaImported(snapshot: PublicPersonaSnapshot): boolean {
  const imported = (snapshot.importedMarkdownFingerprint ?? '').trim();
  return imported.length > 0 && imported === publicPersonaMarkdownFingerprint(snapshot.personaMarkdown);
}

export function markPublicPersonaImported(snapshot: PublicPersonaSnapshot): PublicPersonaSnapshot {
  return {
    schemaVersion: 1,
    personaMarkdown: snapshot.personaMarkdown,
    primaryAvatarUrl: snapshot.primaryAvatarUrl,
    sources: snapshot.sources,
    generatedAt: snapshot.generatedAt,
    mbtiHidden: snapshot.mbtiHidden,
    memoryFacts: snapshot.memoryFacts,
    memoryFactsMarkdownFingerprint: snapshot.memoryFactsMarkdownFingerprint,
    importedMarkdownFingerprint: publicPersonaMarkdownFingerprint(snapshot.personaMarkdown)
  };
}

/** Clears model candidates when a user saves edited Markdown; explicit import must rebuild them with the model. */
export function publicPersonaSnapshotAfterMarkdownEdit(
  snapshot: PublicPersonaSnapshot,
  markdown: string
): PublicPersonaSnapshot {
  return {
    schemaVersion: 1,
    personaMarkdown: markdown,
    primaryAvatarUrl: snapshot.primaryAvatarUrl,
    sources: snapshot.sources,
    generatedAt: snapshot.generatedAt,
    mbtiHidden: snapshot.mbtiHidden,
    memoryFacts: [],
    memoryFactsMarkdownFingerprint: '',
    importedMarkdownFingerprint: snapshot.importedMarkdownFingerprint
  };
}

function sanitizeRebuiltPublicPersonaMemoryFacts(
  facts: PublicPersonaMemoryFact[]
): PublicPersonaMemoryFact[] {
  const safe: PublicPersonaMemoryFact[] = [];
  for (let index = 0; index < facts.length; index++) {
    const item = facts[index];
    if (item.source !== 'public_persona' || !validTimestamp(item.observedAt)) continue;
    const candidate: PublicPersonaMemoryCandidate = {
      fact: item.kind === 'recent_focus' ?
        item.fact.replace(/^截至 \d{4}-\d{2}-\d{2}，/, '') : item.fact,
      confidence: item.confidence,
      kind: item.kind
    };
    const projected = projectPublicPersonaMemoryCandidates([candidate], item.observedAt, 240);
    if (projected.length > 0) safe.push(projected[0]);
  }
  return safe;
}

export function publicPersonaSnapshotWithMemoryFacts(
  snapshot: PublicPersonaSnapshot,
  facts: PublicPersonaMemoryFact[]
): PublicPersonaSnapshot {
  const safeFacts = sanitizeRebuiltPublicPersonaMemoryFacts(facts);
  return {
    schemaVersion: 1,
    personaMarkdown: snapshot.personaMarkdown,
    primaryAvatarUrl: snapshot.primaryAvatarUrl,
    sources: snapshot.sources,
    generatedAt: snapshot.generatedAt,
    mbtiHidden: snapshot.mbtiHidden,
    memoryFacts: safeFacts,
    memoryFactsMarkdownFingerprint: publicPersonaMarkdownFingerprint(snapshot.personaMarkdown),
    importedMarkdownFingerprint: snapshot.importedMarkdownFingerprint
  };
}

/**
 * Produces a cached explicit-import payload only while its Markdown basis still matches. A stale
 * snapshot deliberately returns no facts so callers cannot bypass the required model rebuild.
 */
export function publicPersonaImportFacts(
  snapshot: PublicPersonaSnapshot,
  importedAt: string
): PublicPersonaMemoryFact[] {
  if (!publicPersonaMemoryFactsAreCurrent(snapshot)) return [];
  const storedFacts = publicPersonaMemoryFacts(snapshot);
  const candidates: PublicPersonaMemoryCandidate[] = storedFacts.map(
    (fact: PublicPersonaMemoryFact): PublicPersonaMemoryCandidate => ({
      fact: fact.kind === 'recent_focus' ?
        fact.fact.replace(/^截至 \d{4}-\d{2}-\d{2}，/, '') : fact.fact,
      confidence: fact.confidence,
      kind: fact.kind
    }));
  return projectPublicPersonaMemoryCandidates(candidates, importedAt, 240);
}

function validPublicPersonaInference(value: PublicPersonaInference, itemLimit: number = 32): boolean {
  const fields: string[] = [value.titleName, value.oneLineSummary];
  const arrays: string[][] = [
    value.identityAndExperience, value.expertise, value.interestsAndPreferences,
    value.communicationStyle, value.recentFocus, value.personalityInference
  ];
  if (value.titleName.length > 64 || value.oneLineSummary.length > 160) return false;
  for (let index = 0; index < arrays.length; index++) {
    if (arrays[index].length > 3) return false;
    for (let item = 0; item < arrays[index].length; item++) {
      if (arrays[index][item].length > itemLimit) return false;
      fields.push(arrays[index][item]);
    }
  }
  let total = 0;
  for (let index = 0; index < fields.length; index++) {
    if (fields[index].indexOf('\n') >= 0 || fields[index].indexOf('\r') >= 0 ||
      PUBLIC_PERSONA_SENSITIVE_FACT_PATTERN.test(fields[index])) return false;
    total += fields[index].length;
  }
  return total <= 800;
}

export function parsePublicPersonaInference(raw: string): PublicPersonaInference | null {
  try {
    const parsed = JSON.parse(inferenceJsonText(raw)) as Record<string, Object | string | number | boolean | Object[]>;
    const memoryCandidates = parsePublicPersonaMemoryCandidates(parsed['memoryCandidates']);
    const firstString = (key: string): string => {
      const values = stringArray(parsed[key]);
      return values.length > 0 ? values[0] : nonEmptyString(parsed[key]);
    };
    const alternateName = firstString('name');
    const alternateMbtiRaw = firstString('MBTI') || firstString('mbti');
    if (alternateName.length > 0) {
      let alternateType = '';
      let alternateConfidence = 0;
      if (alternateMbtiRaw.length > 0) {
        const mbtiMatch = /\b(INFJ|ENFJ|ISFJ|ESFJ|INTJ|ENTJ|ISTJ|ESTJ|ISFP|ESFP|INFP|ENFP|ISTP|ESTP|INTP|ENTP)\b/i.exec(alternateMbtiRaw);
        if (mbtiMatch === null) {
          return null;
        }
        alternateType = mbtiMatch[1].toUpperCase();
        const confidenceMatch = /(\d{1,3})\s*%/.exec(alternateMbtiRaw);
        alternateConfidence = confidenceMatch === null ? 50 : Math.min(100, Number(confidenceMatch[1]));
      }
      const alternateStrings = (key: string): string[] => {
        const value = parsed[key];
        if (Array.isArray(value)) {
          return stringArray(value);
        }
        return nonEmptyString(value).length > 0 ? [nonEmptyString(value)] : [];
      };
      const experience = alternateStrings('education').concat(alternateStrings('occupation'));
      const expertise = alternateStrings('skills').concat(alternateStrings('platforms'));
      const interests = alternateStrings('interests');
      const recent = alternateStrings('projects');
      const summary = firstString('jobTitle') || firstString('occupation') ||
        (expertise.length > 0 ? expertise[0] : '公开资料画像');
      const alternate: PublicPersonaInference = {
        titleName: alternateName,
        oneLineSummary: summary,
        identityAndExperience: experience,
        expertise: expertise,
        interestsAndPreferences: interests,
        communicationStyle: [],
        recentFocus: recent,
        personalityInference: [],
        mbtiType: alternateType,
        mbtiConfidence: alternateConfidence,
        memoryCandidates: memoryCandidates
      };
      return validPublicPersonaInference(alternate, 64) ? alternate : null;
    }
    const arrayFields: string[] = [
      'identityAndExperience', 'expertise', 'interestsAndPreferences',
      'communicationStyle', 'recentFocus', 'personalityInference'
    ];
    for (let index = 0; index < arrayFields.length; index++) {
      if (!Array.isArray(parsed[arrayFields[index]])) {
        return null;
      }
    }
    const type = nonEmptyString(parsed['mbtiType']);
    const confidence = parsed['mbtiConfidence'];
    if (MBTI_TYPES.indexOf(type.toUpperCase()) < 0 || typeof confidence !== 'number' || confidence < 0 || confidence > 100) {
      return null;
    }
    const result: PublicPersonaInference = {
      titleName: nonEmptyString(parsed['titleName']),
      oneLineSummary: nonEmptyString(parsed['oneLineSummary']),
      identityAndExperience: stringArray(parsed['identityAndExperience']),
      expertise: stringArray(parsed['expertise']),
      interestsAndPreferences: stringArray(parsed['interestsAndPreferences']),
      communicationStyle: stringArray(parsed['communicationStyle']),
      recentFocus: stringArray(parsed['recentFocus']),
      personalityInference: stringArray(parsed['personalityInference']),
      mbtiType: type.toUpperCase(),
      mbtiConfidence: Math.round(confidence),
      memoryCandidates: memoryCandidates
    };
    return result.titleName.length > 0 && result.oneLineSummary.length > 0 && validPublicPersonaInference(result) ? result : null;
  } catch (_error) {
    return null;
  }
}

export function renderPublicPersonaMarkdown(
  inference: PublicPersonaInference,
  sources: PublicPersonaSourceRef[]
): string {
  const lines: string[] = [
    '# ' + inference.titleName,
    '',
    '> ' + inference.oneLineSummary,
    '',
    '## 身份与经历',
    markdownList(inference.identityAndExperience),
    '',
    '## 专长',
    markdownList(inference.expertise),
    '',
    '## 兴趣与偏好',
    markdownList(inference.interestsAndPreferences),
    '',
    '## 沟通风格',
    markdownList(inference.communicationStyle),
    '',
    '## 近期关注',
    markdownList(inference.recentFocus),
    '',
    '## 性格推断',
    inference.personalityInference.length > 0 ? markdownList(inference.personalityInference) : '- 暂无足够公开信息',
    '',
    inference.mbtiType.length > 0 ?
      inference.mbtiType + ' · ' + inference.mbtiConfidence.toString() + '%' :
      'MBTI 暂无',
    '',
    '## 已确认账号'
  ];
  for (let index = 0; index < sources.length; index++) {
    const source = sources[index];
    const username = (source.username ?? '').trim() ||
      source.profileUrl.substring(source.profileUrl.lastIndexOf('/') + 1).replace(/^@/, '');
    lines.push('- [' + source.platform + '](' + source.profileUrl + ') · ' + username);
  }
  return lines.join('\n');
}

export function parsePublicPersonaMarkdown(markdown: string): PublicPersonaInference | null {
  if (!hasRequiredPublicPersonaSections(markdown)) {
    return null;
  }
  const result: PublicPersonaInference = {
    titleName: '',
    oneLineSummary: '',
    identityAndExperience: [],
    expertise: [],
    interestsAndPreferences: [],
    communicationStyle: [],
    recentFocus: [],
    personalityInference: [],
    mbtiType: '',
    mbtiConfidence: 0
  };
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  let section = '';
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index].trim();
    if (line.startsWith('# ') && !line.startsWith('## ')) {
      result.titleName = line.substring(2).trim();
      continue;
    }
    if (line.startsWith('> ') && result.oneLineSummary.length === 0) {
      result.oneLineSummary = line.substring(2).trim();
      continue;
    }
    if (line.startsWith('## ')) {
      section = line;
      continue;
    }
    if (section === '## 性格推断') {
      const mbti = /^([EI][NS][TF][JP]) · (\d{1,3})%$/.exec(line);
      if (mbti !== null) {
        result.mbtiType = mbti[1];
        result.mbtiConfidence = Number.parseInt(mbti[2], 10);
        continue;
      }
    }
    if (!line.startsWith('- ')) {
      continue;
    }
    const value = line.substring(2).trim();
    if (value === '暂无公开信息' || value === '暂无足够公开信息') {
      continue;
    }
    if (section === '## 身份与经历') result.identityAndExperience.push(value);
    if (section === '## 专长') result.expertise.push(value);
    if (section === '## 兴趣与偏好') result.interestsAndPreferences.push(value);
    if (section === '## 沟通风格') result.communicationStyle.push(value);
    if (section === '## 近期关注') result.recentFocus.push(value);
    if (section === '## 性格推断') result.personalityInference.push(value);
  }
  return result.titleName.length > 0 && result.oneLineSummary.length > 0 ? result : null;
}

export function publicPersonaEditableMarkdown(editing: boolean, draft: string, saved: string): string {
  return editing ? draft : saved;
}

export function hasRequiredPublicPersonaSections(markdown: string): boolean {
  const required: string[] = [
    '# ', '## 身份与经历', '## 专长', '## 兴趣与偏好', '## 沟通风格',
    '## 近期关注', '## 性格推断', '## 已确认账号'
  ];
  for (let index = 0; index < required.length; index++) {
    if (markdown.indexOf(required[index]) < 0) {
      return false;
    }
  }
  return true;
}

export function publicPersonaPreviewMarkdown(markdown: string, hidden: boolean): string {
  if (!hidden) {
    return markdown;
  }
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const visible: string[] = [];
  let hiddenSection = false;
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    if (line.trim().startsWith('## ')) {
      hiddenSection = line.trim().startsWith('## MBTI');
    }
    if (hiddenSection || line.trim() === 'MBTI 暂无' ||
      /^-?\s*[EI][SN][TF][JP] · [0-9]+%/.test(line.trim())) {
      continue;
    }
    visible.push(line);
  }
  return visible.join('\n');
}

export function replacePublicPersonaMbti(markdown: string, mbtiType: string, confidence: number): string {
  const type = mbtiType.trim().toUpperCase();
  if (MBTI_TYPES.indexOf(type) < 0 || confidence < 0 || confidence > 100) {
    return markdown;
  }
  const lines = markdown.replace(/\r\n/g, '\n').split('\n');
  const replacement = type + ' · ' + Math.round(confidence).toString() + '%';
  let inPersonality = false;
  for (let index = 0; index < lines.length; index++) {
    if (lines[index] === '## 性格推断') {
      inPersonality = true;
      continue;
    }
    if (inPersonality && lines[index].startsWith('## ')) {
      lines.splice(index, 0, replacement);
      return lines.join('\n');
    }
    if (inPersonality && (/^[EI][SN][TF][JP] · [0-9]+%/.test(lines[index]) ||
      lines[index].startsWith('MBTI 暂无'))) {
      lines[index] = replacement;
      return lines.join('\n');
    }
  }
  if (inPersonality) {
    lines.push(replacement);
  }
  return lines.join('\n');
}

export function sanitizePublicPersonaSnapshot(value: Object): PublicPersonaSnapshot | null {
  try {
    const raw = value as Record<string, Object | string | number | boolean | Object[]>;
    if (raw['schemaVersion'] !== 1 || typeof raw['personaMarkdown'] !== 'string' ||
      typeof raw['primaryAvatarUrl'] !== 'string' || typeof raw['generatedAt'] !== 'string' ||
      typeof raw['mbtiHidden'] !== 'boolean' || !hasRequiredPublicPersonaSections(raw['personaMarkdown'])) {
      return null;
    }
    const primaryAvatarUrl = raw['primaryAvatarUrl'] as string;
    const generatedAt = raw['generatedAt'] as string;
    if (primaryAvatarUrl.length > 0 && !validHttps(primaryAvatarUrl) || !validTimestamp(generatedAt)) {
      return null;
    }
    const markdownLines = raw['personaMarkdown'].replace(/\r\n/g, '\n').split('\n');
    let inPersonality = false;
    for (let index = 0; index < markdownLines.length; index++) {
      const line = markdownLines[index].trim();
      if (line === '## 性格推断') {
        inPersonality = true;
        continue;
      }
      if (inPersonality && line.startsWith('## ')) {
        break;
      }
      if (inPersonality) {
        const mbti = /^([A-Za-z]{3,8})\s*·\s*(-?\d+(?:\.\d+)?)%/.exec(line);
        if (mbti !== null && (MBTI_TYPES.indexOf(mbti[1].toUpperCase()) < 0 ||
          Number.parseFloat(mbti[2]) < 0 || Number.parseFloat(mbti[2]) > 100)) {
          return null;
        }
      }
    }
    for (let index = 0; index < markdownLines.length; index++) {
      const mbti = /^-?\s*([A-Za-z]{3,8})\s*·\s*(-?\d+(?:\.\d+)?)%/.exec(markdownLines[index].trim());
      if (mbti !== null && (MBTI_TYPES.indexOf(mbti[1].toUpperCase()) < 0 ||
        Number.parseFloat(mbti[2]) < 0 || Number.parseFloat(mbti[2]) > 100)) {
        return null;
      }
    }
    const rawSources = raw['sources'];
    if (!Array.isArray(rawSources) || rawSources.length === 0) {
      return null;
    }
    const sources: PublicPersonaSourceRef[] = [];
    for (let index = 0; index < rawSources.length; index++) {
      const source = rawSources[index] as Record<string, Object | string | Object[]>;
      const platform = nonEmptyString(source['platform']);
      const profileUrl = nonEmptyString(source['profileUrl']);
      const avatarUrl = nonEmptyString(source['avatarUrl']);
      const displayName = nonEmptyString(source['displayName']);
      const username = nonEmptyString(source['username']);
      const fetchedAt = nonEmptyString(source['fetchedAt']);
      const parsed = parsePublicProfileUrl(profileUrl);
      const sourceUrls = stringArray(source['sourceUrls']);
      if (!isPlatform(platform) || parsed === null || parsed.platform !== (platform as PublicPersonaPlatform) ||
        (avatarUrl.length > 0 && !validHttps(avatarUrl)) || !validTimestamp(fetchedAt) || sourceUrls.length === 0) {
        return null;
      }
      const filteredSourceUrls = sourceUrls.filter((url: string): boolean => validHttps(url));
      if (filteredSourceUrls.length === 0) {
        return null;
      }
      sources.push({
        platform: platform as PublicPersonaPlatform,
        profileUrl: parsed.url,
        avatarUrl: avatarUrl,
        displayName: displayName,
        username: username,
        sourceUrls: filteredSourceUrls,
        fetchedAt: fetchedAt
      });
    }
    const primary = primaryAvatarUrl;
    if (sources.filter((source: PublicPersonaSourceRef): boolean => source.avatarUrl === primary).length === 0) {
      return null;
    }
    const parsedMemoryFacts = projectPublicPersonaMemoryCandidates(
      parsePublicPersonaMemoryCandidates(raw['memoryFacts'], 240), generatedAt, 240);
    const currentMarkdownFingerprint = publicPersonaMarkdownFingerprint(raw['personaMarkdown'] as string);
    const rawMemoryFingerprint = nonEmptyString(raw['memoryFactsMarkdownFingerprint']);
    const memoryFactsMarkdownFingerprint = validPublicPersonaMarkdownFingerprint(rawMemoryFingerprint) ?
      rawMemoryFingerprint : (parsedMemoryFacts.length > 0 ? currentMarkdownFingerprint : '');
    const memoryFacts = memoryFactsMarkdownFingerprint === currentMarkdownFingerprint ? parsedMemoryFacts : [];
    const rawImportedFingerprint = nonEmptyString(raw['importedMarkdownFingerprint']);
    const importedMarkdownFingerprint = validPublicPersonaMarkdownFingerprint(rawImportedFingerprint) ?
      rawImportedFingerprint : '';
    return {
      schemaVersion: 1,
      personaMarkdown: raw['personaMarkdown'] as string,
      primaryAvatarUrl: primary,
      sources: sources,
      generatedAt: generatedAt,
      mbtiHidden: raw['mbtiHidden'] as boolean,
      memoryFacts: memoryFacts,
      memoryFactsMarkdownFingerprint: memoryFactsMarkdownFingerprint === currentMarkdownFingerprint ?
        memoryFactsMarkdownFingerprint : '',
      importedMarkdownFingerprint: importedMarkdownFingerprint
    };
  } catch (_error) {
    return null;
  }
}
