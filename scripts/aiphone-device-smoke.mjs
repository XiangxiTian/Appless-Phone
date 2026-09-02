#!/usr/bin/env node
import { copyFileSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, extname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline';
import { createHash } from 'node:crypto';
import {
  evaluateHotelSystemActionEvidence,
  foregroundBundleFromAbilityDump,
  hasPopulatedHotelActionEvidence,
  hasVisibleHotelRateRuleEvidence,
  hotelActionEvidenceFromLogs,
  hotelDetailClickLocator,
  hotelMultiAgentSearchEvidence,
  hotelToolLifecycleFromLogs,
  hasSafeHotelSystemIntentOpen,
  isExpectedHotelSystemBundle,
  matchesHotelDetailAccessibleLabel,
  shouldRetryHotelReturnToApp,
  validateHotelDetailBookingEvidence,
  validateHotelSearchActionEvidence,
  validateHotelSurfaceIdentity,
  hotelMultiAgentDetailEvidence,
  restoredHotelSearchSurface
} from './hotel-smoke-evidence.mjs';
import {
  accountScopedPublicPersonaStoreName,
  activeAccountOwnerIdFromPreferences,
  captureCompletionSettled,
  collectExternalAuthJumps,
  composioAuthEvidence,
  DAILY_BRIEF_VISIBLE_MARKERS,
  calendarConfirmationButtonCenter,
  calendarProviderActionEvidence,
  calendarProviderAbsenceEvidence,
  dailyBriefDirectAnalysis,
  dailyBriefDirectEvidence,
  normalizeCalendarQaDate,
  runC19CleanupFinalizer,
  directTextVisibleEvidence,
  dynamicAuthOutcomeAssessment,
  dynamicToolDiscoveryEvidence,
  expandedMailBodyRegionText,
  externalProviderBlocked,
  finalVisibleDateBlockingHits,
  mailThreadReadEvidence,
  modelTransportEvidence,
  multiAgentActionEvidence,
  multiAgentPostCompletionWaitMs,
  multiAgentTurnEvidence,
  scrolledEvidenceAttemptLimit,
  shouldDismissKeyboardBeforeScrolledEvidence,
  shouldPreserveSmokeAppSession,
  socialDraftUiEvidence,
  socialReplyButtonCenter,
  shouldRecoverMailBodyViewport,
  toolExecutionEvidence,
  visibleMailBodyText
} from './multi-agent-smoke-evidence.mjs';
import {
  bimDeleteConfirmationPoint,
  bimScenarioStatus,
  bimSentinelEvidence,
  bimSentinelUsesInAppTimer,
  bimSmokeStatus,
  completeBimScenarios,
  hasBimDirectory,
  hasBimHome,
  hasBimReadOnlyContext,
  hasConversationTranscript,
  hasSnapshotOnlyMainAgent,
  heartCountFromLayout,
  heartPointFromLayout,
  sanitizeBimFailureReason
} from './bim-smoke-evidence.mjs';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const outDir = process.env.AIPHONE_SMOKE_OUT_DIR || join(rootDir, 'tool-gateway', '.smoke');
mkdirSync(outDir, { recursive: true });
const caseEvidenceDir = join(outDir, 'cases');
const evidenceScreens = [];
mkdirSync(caseEvidenceDir, { recursive: true });

function snapshotCaseArtifacts(caseId, attempt, sourcePrefixes, summary) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const destinationDir = join(caseEvidenceDir, caseId);
  mkdirSync(destinationDir, { recursive: true });
  for (const fileName of readdirSync(outDir)) {
    const prefix = sourcePrefixes.find((candidate) =>
      fileName.startsWith(`${candidate}-`) || fileName.startsWith(`${candidate}.`));
    if (prefix === undefined) continue;
    const sourcePath = join(outDir, fileName);
    if (!statSync(sourcePath).isFile()) continue;
    const extension = extname(fileName);
    const stage = fileName.slice(prefix.length + 1, extension.length > 0 ? -extension.length : undefined)
      .replace(/[^a-zA-Z0-9_-]+/g, '-') || 'artifact';
    const destinationPath = join(destinationDir, `${attempt}-${stage}-${timestamp}${extension}`);
    copyFileSync(sourcePath, destinationPath);
    if (extension === '.png') evidenceScreens.push({ caseId, attempt, path: destinationPath });
  }
  writeFileSync(
    join(destinationDir, `${attempt}-summary-${timestamp}.json`),
    JSON.stringify(summary, null, 2)
  );
}

function captureBlockedCase(caseId, attempt, summary) {
  const prefix = `${caseId}-blocked`;
  const layout = dumpLayout(`${prefix}-layout.json`);
  writeFileSync(join(outDir, `${prefix}-layout-text.txt`), collectLayoutText(layout).join('\n') + '\n');
  captureScreen(`${prefix}-screen.png`);
  snapshotCaseArtifacts(caseId, attempt, [prefix], summary);
}

function writeScreenshotIndex() {
  const ordered = [...evidenceScreens].sort((left, right) => {
    const leftMatch = /^([CF])(\d+)(.*)$/.exec(left.caseId);
    const rightMatch = /^([CF])(\d+)(.*)$/.exec(right.caseId);
    if (leftMatch === null || rightMatch === null) return left.caseId.localeCompare(right.caseId);
    return (leftMatch[1] === rightMatch[1] ? 0 : leftMatch[1] === 'C' ? -1 : 1) ||
      Number(leftMatch[2]) - Number(rightMatch[2]) ||
      leftMatch[3].localeCompare(rightMatch[3]) ||
      left.attempt - right.attempt;
  });
  const lines = ['# 真机场景截图索引', ''];
  let previousCaseId = '';
  for (const screen of ordered) {
    if (screen.caseId !== previousCaseId) {
      lines.push(`## ${screen.caseId}`, '');
      previousCaseId = screen.caseId;
    }
    const imagePath = relative(outDir, screen.path);
    lines.push(`![${screen.caseId} attempt ${screen.attempt}](${imagePath})`, '');
  }
  const indexPath = join(outDir, 'screenshots-index.md');
  writeFileSync(indexPath, lines.join('\n'));
  return indexPath;
}

const defaultCases = [
  { id: 'R01', query: '你好', expectsTool: false, expectedToolId: '' },
  { id: 'R02', query: '不要用 DeepSearch，直接回答 1+1', expectsTool: false, expectedToolId: '' },
  { id: 'R03', query: '查证 OpenAI 最近发布的模型，并对比至少两个官方来源', expectsTool: true, expectedToolId: 'web.research.search', verifyDeepSearch: true, retryLimit: 0 },
  { id: 'R04', query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { id: 'R05', query: '帮我查明天北京到上海的航班', expectsTool: true, expectedToolId: 'flight.search' },
  { id: 'R06', query: '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁', expectsTool: true, expectedToolId: 'train.search' },
  { id: 'R07', query: '帮我找2026年9月8日到10日深圳科技园附近的酒店，2位成人1间房', expectsTool: true, expectedToolId: 'hotel.search' },
  { id: 'R08', query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'R09', query: '帮我看从深圳湾万象城到深圳北站打车多少钱', expectsTool: true, expectedToolId: 'ride.estimate' },
  { id: 'R10', query: '帮我点一杯瑞幸生椰拿铁，半糖少冰', expectsTool: true, expectedToolId: 'luckin.order.preview' },
  { id: 'R11', query: '我想看看有关 OpenAI Codex 的相关新闻和讨论', expectsTool: false, expectedToolId: '' }
];

const dynamicCases = [
  {
    query: '帮我查明天深圳天气',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'weather.query'
  }
];

const composioCases = [
  {
    query: '帮我在 GitHub 里找 Appless-Phone 最近的 pr',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search',
    expectedDynamicQualifiedName: 'github_find_pull_requests'
  },
  {
    query: '帮我在 Google Drive 里找专利交底书',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search',
    expectedDynamicQualifiedName: 'googledrive_find_file'
  },
  {
    query: '帮我在 Google Docs 里找 AIPhoneDemo 设计文档',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search',
    expectedDynamicQualifiedName: 'googledocs_search_documents'
  },
  {
    query: '帮我用 Composio Slack 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我查看邮箱里最新的重要邮件',
    expectsTool: true,
    expectedToolId: 'mail.search'
  },
  {
    query: '帮我用 Discord 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我在 LinkedIn 查 AIPhoneDemo 相关动态',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 WhatsApp 查最近提到 AIPhoneDemo 的消息',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 Instagram 查 AIPhoneDemo 相关评论',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 Spotify 搜适合 AIPhoneDemo demo 的播放列表',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我用 TikTok 搜 AIPhoneDemo 相关短视频',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'dynamic.search'
  },
  {
    query: '帮我查看今天的社交聚合消息',
    expectsTool: true,
    expectedToolId: 'social.feed.search'
  }
];

const gmailCases = [
  { query: '帮我看 Gmail 里最新的重要邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { query: '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了', expectsTool: true, expectedToolId: 'gmail.draft.create' },
  { query: '帮我查看我Gmail里和我eccv论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' }
];

const mailCases = [
  { query: '帮我看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { query: '帮我看 QQ 邮箱里最新邮件', expectsTool: true, expectedToolId: 'mail.search' }
];

const googleAppCases = [
  { query: '帮我在 YouTube 搜索 世界杯相关视频', expectsTool: true, expectedToolId: 'youtube.video.search' },
  { query: '帮我查看我的 YouTube 播放列表', expectsTool: true, expectedToolId: 'youtube.mine.playlists' },
  { query: '帮我看本月的 Google Calendar 日程', expectsTool: true, expectedToolId: 'calendar.events.search' },
  { query: '帮我在 2026年7月30日下午3点创建一个标题为 AIPhoneDemo 的30分钟日程', expectsTool: true, expectedToolId: 'calendar.event.create' }
];

const publicPersonaCases = [
  { id: 'P01', description: 'first launch, retained platform terminals, confirmed four-field accounts' },
  { id: 'P02', description: 'confirm selection and prove only selected account reads' },
  { id: 'P03', description: 'leave while reading and keep partial provider state truthful' },
  { id: 'P04', description: 'one main avatar, Markdown save, MBTI re-inference and hide reload' },
  { id: 'P05', description: 'delete locally and prove persona is absent from the next normal prompt' }
];

const smokeRunId = process.env.AIPHONE_SMOKE_RUN_ID ||
  new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const whatsappTestTo = (process.env.AIPHONE_WHATSAPP_TEST_TO || '').trim();
const qaDateValue = new Date();
qaDateValue.setDate(qaDateValue.getDate() + 7);
const qaDate = `${qaDateValue.getFullYear()}年${String(qaDateValue.getMonth() + 1).padStart(2, '0')}月${String(qaDateValue.getDate()).padStart(2, '0')}日`;
const qaDateIso = normalizeCalendarQaDate(qaDate);
if (qaDateIso.length === 0) throw new Error(`Could not normalize C19 QA date: ${qaDate}`);
const qaTitle = `Appless QA ${smokeRunId}`;
const whatsappRecipient = whatsappTestTo.length > 0 ? whatsappTestTo : '{AIPHONE_WHATSAPP_TEST_TO}';

const coreRegressionCases = [
  { id: 'C01', query: '你好', expectsTool: false, expectedToolId: '' },
  { id: 'C02', query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { id: 'C03', query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'C05', query: '帮我查看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search', verifyMailBody: true },
  { id: 'C06', query: '帮我查看我 Gmail 里和 ECCV 论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { id: 'C07', query: '帮我在 B 站和 YouTube 里搜索 Qwen 的官方视频', expectsTool: true, expectedToolId: 'media.video.search' },
  { id: 'C08', query: '我想看看有关 OpenAI Codex 的相关新闻和讨论', expectsTool: false, expectedToolId: '' },
  { id: 'C09', query: '帮我查看我今天 X 和 Slack 上的消息', expectsTool: true, expectedToolId: 'social.feed.search', verifySocialDraft: true },
  { id: 'C10', query: '帮我查看 X 上 OpenAI 最近的公开 post', expectsTool: true, expectedToolId: 'x.post.search' },
  {
    id: 'C11a', query: '帮我搜索附近的咖啡店', expectsTool: true,
    expectedToolId: 'food.search', verifyMemoryRecall: true
  },
  {
    id: 'C11b', query: '请长期记住这一条偏好：我点咖啡时只选燕麦奶。', expectsTool: false,
    expectedToolId: '', expectedLeaderMemoryCapability: 'memory.remember', verifyMemoryRecall: true
  },
  {
    id: 'C11c', query: '按我的长期偏好帮我搜索附近的咖啡店', expectsTool: true,
    expectedToolId: 'food.search', verifyMemoryRecall: true, expectedMemoryPreference: 'oat_milk'
  },
  {
    id: 'C11d', query: '忘掉“我点咖啡时只选燕麦奶”这一条长期偏好。', expectsTool: false,
    expectedToolId: '', expectedLeaderMemoryCapability: 'memory.forget', verifyMemoryRecall: true
  },
  {
    id: 'C11e', query: '再按我现在的长期偏好帮我搜索附近的咖啡店', expectsTool: true,
    expectedToolId: 'food.search', verifyMemoryRecall: true, expectMemoryPreferenceAbsent: 'oat_milk'
  },
  { id: 'C12', query: '我想看世界杯下一场比赛和赛程', expectsTool: true, expectedToolId: 'worldcup.open' },
  { id: 'C13', query: '帮我查明天深圳天气', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'weather.query' },
  { id: 'C14', query: '帮我看从深圳湾万象城到深圳北站打车多少钱', expectsTool: true, expectedToolId: 'ride.estimate' },
  { id: 'C15', query: '帮我点一杯瑞幸生椰拿铁，半糖少冰', expectsTool: true, expectedToolId: 'luckin.order.preview' },
  { id: 'C17', query: '用 PayPal 给罗一格转 1 美元', expectsTool: true, expectedToolId: 'payment.send' },
  {
    id: 'C18',
    query: `帮我给 WhatsApp 测试联系人 ${whatsappRecipient} 发送消息：Appless QA ${smokeRunId}`,
    expectsTool: true,
    expectedToolId: 'whatsapp.message.send',
    blockedWithoutWhatsAppTestTo: true
  },
  { id: 'C19a', query: `帮我查询 ${qaDate} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19b', query: `帮我在 ${qaDate} 下午3点创建标题为 ${qaTitle} 的30分钟日程`, expectsTool: true, expectedToolId: 'calendar.event.create', verifyCalendarCreate: true },
  { id: 'C19c', query: `把 ${qaDate} 的 ${qaTitle} 日程改到下午4点，保持30分钟`, expectsTool: true, expectedToolId: 'calendar.events.search', verifyCalendarUpdate: true },
  { id: 'C19d', query: `帮我查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search' },
  { id: 'C19e', query: `删除 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程`, expectsTool: true, expectedToolId: 'calendar.events.search', verifyCalendarDelete: true },
  { id: 'C19f', query: `再次查询 ${qaDate} 标题为 ${qaTitle} 的 Google Calendar 日程，确认它不存在`, expectsTool: true, expectedToolId: 'calendar.events.search', expectAbsentText: qaTitle },
  {
    id: 'C20',
    query: '帮我找8月8日到10日深圳科技园附近的酒店，2位成人1间房',
    expectsTool: true,
    expectedToolId: 'hotel.search',
    verifyHotelDetail: true,
    hotelCapabilities: ['hotel.detail', 'hotel.booking.open', 'hotel.navigate']
  },
  {
    id: 'C21',
    query: '查一下现在的时间，查好时间之后帮我打车从华为坂田基地打车到秋岗花园，再在明天的这个时间新建一个会议日程',
    expectsTool: true,
    expectedToolId: 'time',
    expectedToolIds: ['time', 'ride.estimate'],
    minimumDataRounds: 2,
    expectedDataRounds: [
      { toolId: 'time', round: 1 },
      { toolId: 'ride.estimate', round: 2 }
    ]
  },
  {
    id: 'C22',
    query: '我现在要打车从深圳华为坂田基地到秋港花园，帮我点一杯瑞幸生椰拿铁，半糖少冰，转账给罗一格5美金',
    expectsTool: true,
    expectedToolId: 'ride.estimate',
    expectedToolIds: ['ride.estimate', 'luckin.order.preview', 'payment.send'],
    minimumDataRounds: 1,
    expectedDataRounds: [
      { toolId: 'ride.estimate', round: 1 }
    ]
  },
  { id: 'C23', query: '我想看看现在热映电影、票房和明星动态', expectsTool: true, expectedToolId: 'movie.open' },
  { id: 'C24', query: '我想查看今日日报', expectsTool: true, expectedToolId: 'daily.brief.open' }
];
const memoryForgetSelectionQueryArg = process.argv.slice(2)
  .find((arg) => arg.startsWith('--memory-forget-query='));
const memoryForgetSelectionQuery = (
  memoryForgetSelectionQueryArg === undefined ?
    process.env.AIPHONE_MEMORY_FORGET_QUERY || '' : memoryForgetSelectionQueryArg.slice('--memory-forget-query='.length)
).trim();
const memoryForgetSelectionCase = {
  id: 'MFS01',
  query: memoryForgetSelectionQuery,
  expectsTool: false,
  expectedToolId: '',
  verifyMemoryRecall: true,
  verifyMemoryForgetSelection: true
};

const retainedFullCases = [
  { id: 'F01', query: '帮我查明天北京到上海的航班', expectsTool: true, expectedToolId: 'flight.search' },
  { id: 'F02', query: '帮我查询明天晚上六点以后深圳北到香港西九龙的高铁', expectsTool: true, expectedToolId: 'train.search' },
  { id: 'F03', query: '帮我查深圳坂田附近麦当劳门店和菜单', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'F04', query: '瑞幸生椰拿铁多少钱', expectsTool: true, expectedToolId: 'food.search' },
  { id: 'F05', query: '用 Google Pay 给罗一格转 1 美元', expectsTool: true, expectedToolId: 'payment.send' },
  { id: 'F06', query: '帮我设置 Stripe 收款账户', expectsTool: true, expectedToolId: 'payment.account.setup' },
  {
    id: 'F07',
    query: '帮我用 Gmail 写一封邮件给 alice@example.com，说我收到了',
    expectsTool: true,
    expectedToolId: 'gmail.draft.create',
    retryLimit: 0
  },
  {
    id: 'F08',
    query: '确认应用刚才的 Gmail 草稿',
    expectsTool: true,
    expectedToolId: 'gmail.draft.apply',
    dependsOnCaseId: 'F07',
    retryLimit: 0
  },
  { id: 'F09', query: '帮我在 YouTube 搜索世界杯相关视频', expectsTool: true, expectedToolId: 'youtube.video.search' },
  { id: 'F10', query: '帮我查看我的 YouTube 播放列表', expectsTool: true, expectedToolId: 'youtube.mine.playlists' },
  { id: 'F11', query: '帮我查看我的 YouTube 订阅', expectsTool: true, expectedToolId: 'youtube.mine.subscriptions' },
  { id: 'F13', query: '帮我在 GitHub 里找 Appless-Phone 最近的 pr', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search', expectedDynamicQualifiedName: 'github_find_pull_requests' },
  { id: 'F14', query: '帮我在 Google Drive 里找专利交底书', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search', expectedDynamicQualifiedName: 'googledrive_find_file' },
  { id: 'F15', query: '帮我在 Google Docs 里找 AIPhoneDemo 设计文档', expectsTool: true, expectedToolId: 'dynamic.search', expectedDiscoveredToolId: 'dynamic.search', expectedDynamicQualifiedName: 'googledocs_search_documents' },
  {
    id: 'F16',
    query: '打开当前应用的 Composio 管理授权设置',
    expectsTool: false,
    expectedToolId: '',
    expectedToolIds: [],
    verifyComposioSettings: true
  }
];

const fullRegressionCases = [...coreRegressionCases, ...retainedFullCases];

function lifecycleOptions(testCase) {
  const expectedToolId = testCase.expectedToolId || '';
  return {
    expectedToolIds: testCase.expectedToolIds ||
      (expectedToolId.length > 0 ? [expectedToolId] : []),
    minimumDataRounds: testCase.minimumDataRounds || 0,
    expectedDependencies: testCase.expectedDependencies || [],
    expectedDataRounds: testCase.expectedDataRounds || [],
    expectedParallelDataToolIds: testCase.expectedParallelDataToolIds || []
  };
}

const coreScenarioManifest = [
  ['C01', []], ['C02', ['travel.search']], ['C03', ['food.search']],
  ['C05', ['mail.search']],
  ['C06', ['gmail.mail.search']], ['C07', ['media.video.search']],
  ['C08', []], ['C09', ['social.feed.search']],
  ['C10', ['x.post.search']],
  ['C11', ['food.search', 'memory.remember', 'memory.forget']],
  ['C12', ['worldcup.open']], ['C13', ['dynamic.search']],
  ['C14', ['ride.estimate']], ['C15', ['luckin.order.preview']],
  ['C17', ['payment.send']],
  ['C18', ['whatsapp.message.send']],
  ['C19', ['calendar.events.search', 'calendar.event.create', 'calendar.event.update', 'calendar.event.delete']],
  ['C20', ['hotel.search']],
  ['C21', ['time', 'ride.estimate']],
  ['C22', ['ride.estimate', 'luckin.order.preview', 'payment.send']],
  ['C23', ['movie.open']],
  ['C24', ['daily.brief.open'], {
    requiredVisibleMarkers: DAILY_BRIEF_VISIBLE_MARKERS,
    automatedDerivedActionIds: [],
    manualDerivedActionIds: [
      'daily.brief.regenerate',
      'daily.brief.preference.save',
      'daily.brief.history.open',
      'daily.brief.mail.read',
      'daily.brief.discovery.open'
    ]
  }]
].map(([id, expectedToolIds, evidence = {}]) => ({ id, expectedToolIds, ...evidence }));

const fullScenarioManifest = retainedFullCases.map((testCase) => ({
  id: testCase.id,
  expectedToolIds: testCase.expectedToolIds ||
    (testCase.expectedToolId.length > 0 ? [testCase.expectedToolId] : []),
  minimumDataRounds: testCase.minimumDataRounds || 0,
  expectedDependencies: testCase.expectedDependencies || [],
  expectedDynamicQualifiedName: testCase.expectedDynamicQualifiedName || ''
}));

const forbiddenSocialHubLegacyMarkers = [
  'SocialInbox',
  'social.reply.send',
  '微信消息收件箱',
  '通知中心桥接',
  '辅助捕获'
];

const forbiddenSyntheticMarkers = [
  '高铁 G 字头',
  '动车 D 字头',
  '直飞航班',
  '早晚低峰',
  '附近咖啡优先',
  '安静办公优先',
  '连锁稳定优先',
  '可查选项',
  ...forbiddenSocialHubLegacyMarkers
];

const visibleDomainMarkers = [
  '北京',
  '上海',
  '深圳',
  '高铁',
  '航班',
  '高铁 · 12306',
  '飞机 · 飞常准',
  '12306',
  '飞常准',
  '餐饮',
  '酒店',
  '咖啡',
  '奶茶',
  '坂田',
  '华为',
  '接入工具',
  'dynamic.search',
  'Composio',
  'GitHub',
  'Notion',
  'Google Drive',
  'Google Docs',
  'Linear',
  'Trello',
  'Asana',
  'HubSpot',
  'Salesforce',
  'Outlook',
  'Discord',
  'LinkedIn',
  'WhatsApp',
  'Instagram',
  'Spotify',
  'TikTok',
  'Ticketmaster',
  'needs_auth',
  'ferry.ticket.search',
  'weather.query',
  'statistics.search',
  'ppt.generate',
  'Gmail',
  'mail.search',
  'Mailbox',
  'QQ Mail',
  'AI 回复草稿',
  'YouTube',
  'youtube.video.search',
  'youtube.mine.playlists',
  'YOUTUBE_API_KEY',
  'Google Calendar',
  'calendar.events.search',
  'calendar.event.create',
  'calendar.event.delete',
  'Google OAuth',
  'whatsapp.message.send',
  'Gmail Web',
  'google.gmail',
  'gmail.mail.search',
  'gmail.draft.create',
  'gmail.open.web',
  'gmail.message.send',
  'Composio Gmail',
  '授权 Gmail',
  '不会模拟 Gmail 邮件',
  'AMAP_MAPS_API_KEY',
  'Authorization',
  'API_KEY',
  '歌者PPT',
  '多展示一些',
  '选最快的',
  'SocialHub',
  '社交工作台',
  'social.feed.search',
  'x.post.search',
  '生成草稿',
  'Slack',
  '企业微信',
  ...DAILY_BRIEF_VISIBLE_MARKERS
];

const forbiddenLayoutActionMarkers = [
  '换个时间',
  '换个车站'
];

const finalLayoutBlockingMarkers = [
  'A2UI 流解析失败',
  '模型正在思考',
  '工具供应商调用异常',
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'Gmail MCP 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request',
  'invalid request data provided',
  'Composio 调用失败',
  'Failed to resolve the host name',
  '同步失败',
  'WhatsApp Business 账号不可用',
  '暂无可展示数据',
  '暂不支持的组件',
  '把一句话变成可执行界面',
  '告诉 AIPhone 你要安排的事',
  '[object Object]',
  '{"version"'
];

const finalLayoutRouteMarkers = [
  '北京',
  '上海'
];

const forbiddenGmailSendSuccessPatterns = [
  { name: 'gmail-send-success-en', pattern: /sent successfully|message sent/i },
  { name: 'gmail-send-success-zh', pattern: /发送成功|已发送成功|邮件已发送/ }
];

const retryableProviderLayoutMarkers = [
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028',
  'invalid request data provided',
  'Composio 调用失败',
  'Failed to resolve the host name',
  '同步失败',
  'WhatsApp Business 账号不可用'
];

function hasTechnicalGmailArgsCard(text) {
  return /(?:^|\n)args\n\{[\s\S]{0,180}"query"/.test(text);
}

const socialHubTruthfulBlockingMarkers = [
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request'
];

const aggregateMediaTruthfulBlockingMarkers = [
  '工具供应商调用异常',
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request'
];

const dailyBriefTruthfulStateMarkers = [
  ...aggregateMediaTruthfulBlockingMarkers,
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'Gmail MCP 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Composio 调用失败',
  'Failed to resolve the host name',
  '同步失败',
  '暂无可展示数据'
];

const argv = process.argv.slice(2);
const hdcCommand = (process.env.AIPHONE_HDC_COMMAND || 'hdc').trim() || 'hdc';
const cleanData = process.env.AIPHONE_SMOKE_CLEAN_DATA === '1' || argv.includes('--clean-data');
const runDynamicCases = argv.includes('--dynamic-tools');
const runComposioCases = argv.includes('--composio-tools');
const runComposioAuthCases = argv.includes('--composio-auth');
const runGoogleApps = argv.includes('--google-apps');
const runFullRegression = argv.includes('--full-regression');
const runCoreRegression = argv.includes('--core-regression');
const runGmailSendManual = argv.includes('--gmail-send-manual');
const runBimSmoke = argv.includes('--bim');
const runPublicPersona = argv.includes('--public-persona');
const runMemoryForgetSelection = argv.includes('--memory-forget-selection');
const listCases = argv.includes('--list-cases');
const memoryCandidateIndicesArg = argv.find((arg) => arg.startsWith('--memory-candidate-indices='));
const memoryCandidateIndexArg = argv.find((arg) => arg.startsWith('--memory-candidate-index='));
const memoryCandidateIndicesRaw = memoryCandidateIndicesArg !== undefined ?
  memoryCandidateIndicesArg.slice('--memory-candidate-indices='.length) :
  (process.env.AIPHONE_MEMORY_CANDIDATE_INDICES ||
    (memoryCandidateIndexArg !== undefined ? memoryCandidateIndexArg.slice('--memory-candidate-index='.length) :
      process.env.AIPHONE_MEMORY_CANDIDATE_INDEX || '1,2'));
const memoryCandidateIndices = [...new Set(String(memoryCandidateIndicesRaw).split(',')
  .map((value) => Number.parseInt(value.trim(), 10)))]
  .filter((value) => Number.isSafeInteger(value) && value > 0)
  .sort((left, right) => left - right);
const queryArgs = argv.filter((arg) => arg !== '--clean-data' &&
  arg !== '--dynamic-tools' &&
  arg !== '--composio-tools' &&
  arg !== '--composio-auth' &&
  arg !== '--google-apps' &&
  arg !== '--full-regression' &&
  arg !== '--core-regression' &&
  arg !== '--gmail-send-manual' &&
  arg !== '--bim' &&
  arg !== '--public-persona' &&
  arg !== '--memory-forget-selection' &&
  !arg.startsWith('--memory-forget-query=') &&
  !arg.startsWith('--memory-candidate-indices=') &&
  !arg.startsWith('--memory-candidate-index=') &&
  arg !== '--list-cases');
const selectedDefaultCases = runMemoryForgetSelection ? [memoryForgetSelectionCase] :
  (runComposioCases ? composioCases :
  (runFullRegression ? fullRegressionCases :
    (runCoreRegression ? coreRegressionCases :
      (runGoogleApps ? defaultCases.concat(googleAppCases) :
        (runDynamicCases ? defaultCases.concat(dynamicCases) : defaultCases)))));
const useDefaultCases = queryArgs.length === 0;
const queries = useDefaultCases ? selectedDefaultCases.map((testCase) => testCase.query) : queryArgs;
const queryRetryLimit = Number.parseInt(process.env.AIPHONE_QUERY_RETRY_LIMIT || '2', 10);
if (listCases) {
  if (runMemoryForgetSelection) {
    console.log(JSON.stringify([{
      id: memoryForgetSelectionCase.id,
      mode: 'memory-forget-selection',
      automated: true,
      defaultCore: false,
      queryConfigured: memoryForgetSelectionQuery.length > 0,
      candidateIndices: memoryCandidateIndices,
      requires: ['AIPHONE_MEMORY_FORGET_QUERY or --memory-forget-query=<query>',
        'one-to-five recalled memories',
        'AIPHONE_MEMORY_CANDIDATE_INDICES or --memory-candidate-indices=1,2 (defaults to 1,2)']
    }], null, 2));
    process.exit(0);
  }
  if (runBimSmoke) {
    console.log(JSON.stringify([{
      id: 'BIM',
      mode: 'device-smoke',
      automated: true,
      preservesAppData: true,
      requires: ['local-model', 'heart-things']
    }], null, 2));
    process.exit(0);
  }
  if (runPublicPersona) {
    console.log(JSON.stringify(publicPersonaCases.map((testCase) => ({
      id: testCase.id,
      description: testCase.description,
      automated: false,
      manualGate: true,
      runner: 'runPublicPersonaSmoke',
      requires: [
        'AIPHONE_PUBLIC_PERSONA_USERNAME',
        'AIPHONE_PUBLIC_PERSONA_MANUAL_RESUME=1',
        'AIPHONE_PUBLIC_PERSONA_SELECTED_URLS + AIPHONE_PUBLIC_PERSONA_UNSELECTED_URLS'
      ],
      providerSuccessRequired: true
    })), null, 2));
    process.exit(0);
  }
  if (runGmailSendManual) {
    const safeThreadId = (process.env.AIPHONE_GMAIL_SAFE_THREAD_ID || '').trim();
    const safeRecipient = (process.env.AIPHONE_GMAIL_SAFE_RECIPIENT || '').trim();
    if (safeThreadId.length === 0 || safeRecipient.length === 0) {
      console.error('Manual Gmail reply-send listing requires AIPHONE_GMAIL_SAFE_THREAD_ID and AIPHONE_GMAIL_SAFE_RECIPIENT.');
      process.exit(2);
    }
    console.log(JSON.stringify([{
      id: 'M01',
      mode: 'manual-only',
      automated: false,
      expectedToolIds: ['gmail.message.send'],
      requiresCurrentVisibleReplySurface: true
    }], null, 2));
    process.exit(0);
  }
  const manifest = queryArgs.length > 0 ? queryArgs.map((query) => {
    const testCase = expectedCaseForQuery(query);
    return {
      id: testCase.id || '',
      expectedToolIds: lifecycleOptions(testCase).expectedToolIds,
      retryLimit: testCase.retryLimit ?? queryRetryLimit
    };
  }) : (runFullRegression ?
    [...coreScenarioManifest, ...fullScenarioManifest] : selectedDefaultCases.map((testCase) => ({
      id: testCase.id || '',
      mode: testCase.verifyDeepSearch === true ? 'deepsearch' : 'agent',
      expectedToolIds: lifecycleOptions(testCase).expectedToolIds,
      retryLimit: testCase.retryLimit ?? queryRetryLimit
    })));
  console.log(JSON.stringify(manifest, null, 2));
  process.exit(0);
}

function publicPersonaConfiguredUrls(value) {
  const urls = [];
  for (const candidate of String(value || '').split(/[\n,]/)) {
    const trimmed = candidate.trim();
    if (!/^https:\/\/[^\s?#]+$/i.test(trimmed) || urls.includes(trimmed)) {
      continue;
    }
    urls.push(trimmed.endsWith('/') ? trimmed.slice(0, -1) : trimmed);
  }
  return urls;
}

const publicPersonaUsername = (process.env.AIPHONE_PUBLIC_PERSONA_USERNAME || '').trim();
const publicPersonaSearchMode = (process.env.AIPHONE_PUBLIC_PERSONA_SEARCH_MODE || 'fuzzy').trim().toLowerCase();
const publicPersonaExpectedPlatform = (process.env.AIPHONE_PUBLIC_PERSONA_EXPECTED_PLATFORM || '').trim().toLowerCase();
const publicPersonaExpectedState = (process.env.AIPHONE_PUBLIC_PERSONA_EXPECTED_STATE || '').trim().toLowerCase();
const publicPersonaSelectedUrls = publicPersonaConfiguredUrls(process.env.AIPHONE_PUBLIC_PERSONA_SELECTED_URLS);
const publicPersonaUnselectedUrls = publicPersonaConfiguredUrls(process.env.AIPHONE_PUBLIC_PERSONA_UNSELECTED_URLS);
const publicPersonaExpectedHapSha256 = (process.env.AIPHONE_PUBLIC_PERSONA_HAP_SHA256 || '').trim().toLowerCase();
const publicPersonaHapPath = join(rootDir, 'entry/build/default/outputs/default/entry-default-signed.hap');
let publicPersonaHapSha256 = '';
try {
  publicPersonaHapSha256 = createHash('sha256').update(readFileSync(publicPersonaHapPath)).digest('hex');
} catch (_error) {}
const publicPersonaAdmissionPlatforms = [
  'weibo', 'github', 'qq', 'inaturalist', 'leetcode_cn', 'gitee', 'stackoverflow', 'gitlab',
  'bitbucket', 'devto', 'keybase', 'lemmy', 'codeberg', 'codeforces', 'leetcode', 'gitea',
  'hackerrank', 'discogs'
];
if (runPublicPersona && !/^[A-Za-z0-9._-]{1,64}$/.test(publicPersonaUsername)) {
  console.error('Public persona smoke requires AIPHONE_PUBLIC_PERSONA_USERNAME; no provider result is synthesized.');
  process.exit(2);
}
if (runPublicPersona && publicPersonaSearchMode !== 'exact' && publicPersonaSearchMode !== 'fuzzy') {
  console.error('AIPHONE_PUBLIC_PERSONA_SEARCH_MODE must be exact or fuzzy.');
  process.exit(2);
}
if (runPublicPersona && publicPersonaExpectedPlatform.length > 0 &&
  !publicPersonaAdmissionPlatforms.includes(publicPersonaExpectedPlatform)) {
  console.error('AIPHONE_PUBLIC_PERSONA_EXPECTED_PLATFORM is not an enabled public persona source.');
  process.exit(2);
}
if (runPublicPersona && publicPersonaExpectedPlatform.length > 0 &&
  (!/^[a-f0-9]{64}$/.test(publicPersonaExpectedHapSha256) ||
    publicPersonaExpectedHapSha256 !== publicPersonaHapSha256)) {
  console.error('AIPHONE_PUBLIC_PERSONA_HAP_SHA256 must match the local signed HAP used for admission.');
  process.exit(2);
}
if (runPublicPersona && publicPersonaExpectedState.length > 0 &&
  !['found', 'not_found'].includes(publicPersonaExpectedState)) {
  console.error('AIPHONE_PUBLIC_PERSONA_EXPECTED_STATE must be found or not_found; unknown cannot pass admission.');
  process.exit(2);
}
if (runPublicPersona && (publicPersonaExpectedPlatform.length > 0) !== (publicPersonaExpectedState.length > 0)) {
  console.error('AIPHONE_PUBLIC_PERSONA_EXPECTED_PLATFORM and AIPHONE_PUBLIC_PERSONA_EXPECTED_STATE are required together.');
  process.exit(2);
}
if (runGmailSendManual) {
  console.error('gmail.message.send is manual-only; use --gmail-send-manual --list-cases to inspect its safe gate.');
  process.exit(2);
}
let target = (process.env.AIPHONE_HDC_TARGET || '').trim();
if (!runBimSmoke && target.length === 0) target = firstTarget();
const timeoutMs = Number.parseInt(process.env.AIPHONE_QUERY_TIMEOUT_MS || '90000', 10);
const mailActionScrollLimit = Number.parseInt(process.env.AIPHONE_MAIL_ACTION_SCROLL_LIMIT || '16', 10);

function isWhatsAppSendQuery(query) {
  return /WhatsApp|Whats\s*App/i.test(query) && /发|发送|消息给|send/i.test(query) && /消息|信息|message/i.test(query);
}

function isMapsRouteQuery(query) {
  return /Google\s*Maps?|GMap|谷歌地图/i.test(query) && /路线|导航|怎么走|directions?|navigate|从.+到/.test(query);
}

function isHotelQuery(query) {
  return /酒店|hotel/i.test(query);
}

function isDailyBriefQuery(query) {
  return /今日日报|今日简报|个人日报/.test(query) &&
    /看|查看|打开|生成|重新生成|重做|刷新/.test(query);
}

function expectedCaseForQuery(query) {
  const focusedCase = defaultCases.find((testCase) => testCase.query === query);
  if (focusedCase !== undefined) {
    return focusedCase;
  }
  const configuredCase = fullRegressionCases.find((testCase) => testCase.query === query);
  if (configuredCase !== undefined) {
    return configuredCase;
  }
  const memoryCapability = expectedLeaderMemoryCapabilityForQuery(query);
  if (memoryCapability.length > 0) {
    return {
      expectsTool: false,
      expectedToolId: '',
      expectedLeaderMemoryCapability: memoryCapability,
      verifyMemoryRecall: true
    };
  }
  if (/^你好$|问候|打招呼/.test(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (isDailyBriefQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'daily.brief.open'
    };
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'none'
    };
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'weather.query'
    };
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'statistics.search'
    };
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'ppt.generate'
    };
  }
  if (isWhatsAppSendQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'whatsapp.message.send'
    };
  }
  if (isSocialFeedQuery(query) &&
    (!isXPostSearchQuery(query) || !/公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return {
      expectsTool: true,
      expectedToolId: 'social.feed.search'
    };
  }
  if (/Composio|GitHub|Notion|Google\s*Drive|Google\s*Docs|Linear|Asana|Trello|HubSpot|Salesforce|Outlook|Spotify|Soptify|TikTok|Ticketmaster/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'dynamic.search'
    };
  }
  if (/PayPal|Google\s*Pay|GPay|支付|转账|付款/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'payment.send'
    };
  }
  if (isAggregateMediaSearchQuery(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return {
      expectsTool: true,
      expectedToolId: 'x.post.search'
    };
  }
  if (isSocialFeedQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'social.feed.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && isMailAggregationQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'mail.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: /写一封|写邮件|起草|草稿|回复|撰写/.test(query) ? 'mail.draft.create' : 'mail.search'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /打开|网页版|网页/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.open.web'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.draft.create'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.draft.create'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.mail.search'
    };
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.playlists'
    };
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.subscriptions'
    };
  }
  if (isYouTubeBilibiliQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/YouTube|油管/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.video.search'
    };
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/世界杯|world\s*cup|worldcup/i.test(query) && /想看|打开|进入|页面|界面|赛程|下一场|下场|什么时候|几点|开始|开赛|前瞻|集锦|球星|数据|对阵|比赛|schedule|fixture|preview|next match/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'worldcup.open'
    };
  }
  if (/热映电影|电影票房|院线电影|电影专页|明星动态/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'movie.open'
    };
  }
  if (/Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query)) {
    if (/删除|取消/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.delete'
      };
    }
    if (/创建|新建|添加|安排|预约/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.create'
      };
    }
    if (/更新|修改|改到|改为|调整/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.update'
      };
    }
    return {
      expectsTool: true,
      expectedToolId: 'calendar.events.search'
    };
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query) && /北京|上海|广州|深圳|杭州|成都|重庆|西安|南京|武汉|厦门|青岛|长沙|昆明|海口|三亚/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'travel.search'
    };
  }
  if (/航班|机票|飞机/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'flight.search'
    };
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'train.search'
    };
  }
  if (isHotelQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'hotel.search',
      verifyHotelDetail: true,
      hotelCapabilities: ['hotel.detail', 'hotel.booking.open', 'hotel.navigate']
    };
  }
  if (/瑞幸|luckin|ruixing/i.test(query) && /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|帮我买|购买一杯|购买瑞幸|来一杯|要一杯/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'luckin.order.preview'
    };
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'food.search'
    };
  }
  return {
    expectsTool: null,
    expectedToolId: ''
  };
}

function firstTarget() {
  const result = spawnSync(hdcCommand, ['list', 'targets'], { encoding: 'utf8', timeout: 12000 });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  if (result.error !== undefined) {
    throw new Error(`hdc list targets failed before finding a device: ${result.error.message}`);
  }
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc list targets failed before finding a device: ${output}`);
  }
  const lines = output.split('\n').map((line) => line.trim()).filter((line) => line.length > 0 && !/list of targets/i.test(line));
  if (lines.length === 0) {
    throw new Error(`No hdc target found. Set AIPHONE_HDC_TARGET. hdc output: ${output}`);
  }
  return lines[0];
}

function hdc(args, options = {}) {
  const result = spawnSync(hdcCommand, ['-t', target, ...args], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
    ...options
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (result.error !== undefined) {
    throw new Error(`hdc ${args.join(' ')} failed: ${result.error.message}`);
  }
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc ${args.join(' ')} failed:\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

function deviceLocalIsoDate() {
  const value = hdc(['shell', 'date', '+%Y-%m-%d']).trim();
  if (!/^20\d{2}-\d{2}-\d{2}$/.test(value)) {
    throw new Error(`Could not read ISO local date from target ${target}: ${value}`);
  }
  return value;
}

const expectedDeviceLocalDate = queries.some((query) => isDailyBriefQuery(query)) ? deviceLocalIsoDate() : '';

function appWindowRect() {
  const output = hdc(['shell', 'hidumper', '-s', 'WindowManagerService', '-a', '-a']);
  const line = output.split('\n').find((value) => value.includes('com.jiuwen.appless'));
  if (line === undefined) {
    return null;
  }
  const match = /\[\s*(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\d+)\s+\]/.exec(line);
  if (match === null) {
    return null;
  }
  return {
    x: Number.parseInt(match[1], 10),
    y: Number.parseInt(match[2], 10),
    width: Number.parseInt(match[3], 10),
    height: Number.parseInt(match[4], 10)
  };
}

function moveAppWindowIntoScreenshot() {
  const rect = appWindowRect();
  if (rect === null || rect.y >= 0 && rect.y <= 220) {
    return;
  }
  const x = Math.max(80, Math.floor(rect.x + rect.width / 2));
  const fromY = Math.max(40, rect.y + 40);
  hdc(['shell', 'uitest', 'uiInput', 'drag', String(x), String(fromY), String(x), '120', '2000']);
  spawnSync('sleep', ['1']);
}

function clearHilog() {
  try {
    hdc(['shell', 'hilog', '-r']);
  } catch (error) {
    console.warn(`Could not clear hilog buffer: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function cleanBundleData() {
  try {
    hdc(['shell', 'bm', 'clean', '-n', 'com.jiuwen.appless', '-d']);
    return true;
  } catch (error) {
    console.warn(`Could not clean bundle data: ${error instanceof Error ? error.message : String(error)}`);
    return false;
  }
}

const appPreferencesPath = '/data/app/el2/100/base/com.jiuwen.appless/haps/entry/preferences';
const accountDeviceStateStorePath = `${appPreferencesPath}/appless_account_device_state`;

function publicPersonaSnapshotProbe() {
  const deviceState = hdc(['shell',
    `if [ -f ${accountDeviceStateStorePath} ]; then cat ${accountDeviceStateStorePath}; else echo __ACCOUNT_DEVICE_STATE_ABSENT__; fi`
  ]);
  if (deviceState.includes('__ACCOUNT_DEVICE_STATE_ABSENT__')) {
    return { status: 'BLOCKED', reason: 'account_device_state_absent', ownerId: '', storePath: '' };
  }
  const ownerId = activeAccountOwnerIdFromPreferences(deviceState);
  if (ownerId.length === 0) {
    return { status: 'BLOCKED', reason: 'active_account_owner_absent_or_invalid', ownerId: '', storePath: '' };
  }
  const storeName = accountScopedPublicPersonaStoreName(ownerId);
  const storePath = `${appPreferencesPath}/${storeName}`;
  const output = hdc(['shell',
    `if [ -f ${storePath} ] && grep -q snapshot_v1 ${storePath}; then echo PRESENT; else echo ABSENT; fi`
  ]).trim();
  if (output !== 'PRESENT' && output !== 'ABSENT') {
    return { status: 'BLOCKED', reason: 'scoped_persona_probe_failed', ownerId, storePath };
  }
  return { status: output, reason: '', ownerId, storePath };
}

function publicPersonaSnapshotExists(probe) {
  return probe.status === 'PRESENT';
}

function probeLocalModel() {
  const result = spawnSync(hdcCommand, ['-t', target, 'shell', 'curl', '-sS', '-m', '3', 'http://127.0.0.1:11434/v1/models'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  const hdcUnavailable = /Connect server failed/i.test(output);
  const probeUnavailable = /(?:curl:\s*inaccessible or not found|curl:\s*not found|command not found)/i.test(output);
  const connectionRefused = hdcUnavailable || /Failed to connect|Couldn.t connect|Connection refused|curl:\s*\(7\)/i.test(output);
  const listenerReachable = !connectionRefused && (
    !probeUnavailable &&
    /403|Call is not allowed/i.test(output) ||
    (!probeUnavailable && result.status === 0 && output.length > 0 && !/curl:\s*\(\d+\)/i.test(output))
  );
  return {
    status: result.status,
    hdcUnavailable,
    probeUnavailable,
    listenerReachable,
    connectionRefused,
    output: output.length > 500 ? `${output.slice(0, 500)}...<truncated>` : output
  };
}

function startModelFoundation() {
  const result = spawnSync(hdcCommand, ['-t', target, 'shell', 'aa', 'start', '-b', 'com.huawei.hmos.hmmodelfoundation', '-a', 'EntryAbility'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  return {
    status: result.status,
    output: `${result.stdout || ''}${result.stderr || ''}`.trim()
  };
}

async function ensureLocalModel() {
  const initial = probeLocalModel();
  if (initial.hdcUnavailable) {
    throw new Error(`hdc unavailable before local model probe: ${initial.output}`);
  }
  if (!initial.connectionRefused) {
    return initial;
  }
  const recovery = startModelFoundation();
  await sleep(3000);
  const afterStart = probeLocalModel();
  if (afterStart.hdcUnavailable) {
    throw new Error(`hdc unavailable after model foundation recovery attempt: ${afterStart.output}`);
  }
  return {
    ...afterStart,
    recovery
  };
}

function cleanupHilogProcesses() {
  const targetHilogPattern = `-t ${target} hilog`;
  const killMatching = (signal) => {
    for (const line of activeHilogProcesses()) {
      if (!line.includes(targetHilogPattern)) {
        continue;
      }
      const match = /^(\d+)\s+/.exec(line);
      if (match !== null) {
        if (process.platform === 'win32') {
          const args = ['/PID', match[1], '/T'];
          if (signal === 'KILL') args.push('/F');
          spawnSync('taskkill', args, { encoding: 'utf8' });
        } else {
          spawnSync('kill', [`-${signal}`, match[1]], { encoding: 'utf8' });
        }
      }
    }
  };
  killMatching('TERM');
  if (process.platform === 'win32') {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 300);
  } else {
    spawnSync('sleep', ['0.3']);
  }
  killMatching('KILL');
}

if (runMemoryForgetSelection && memoryForgetSelectionQuery.length === 0) {
  console.error('Memory forget selection smoke requires AIPHONE_MEMORY_FORGET_QUERY or --memory-forget-query=<query>.');
  process.exit(2);
}
if (runMemoryForgetSelection && (memoryCandidateIndices.length === 0 ||
  memoryCandidateIndices.length > 5 || memoryCandidateIndices.join(',') !==
    String(memoryCandidateIndicesRaw).split(',').map((value) => Number.parseInt(value.trim(), 10))
      .sort((left, right) => left - right).join(','))) {
  console.error('Memory candidate indices must be one-to-five unique positive 1-based integers.');
  process.exit(2);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function walk(node, visit) {
  visit(node);
  for (const child of node.children || []) {
    walk(child, visit);
  }
}

function parseBounds(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds || '');
  if (!match) {
    return null;
  }
  const left = Number.parseInt(match[1], 10);
  const top = Number.parseInt(match[2], 10);
  const right = Number.parseInt(match[3], 10);
  const bottom = Number.parseInt(match[4], 10);
  return {
    left,
    top,
    right,
    bottom,
    width: right - left,
    height: bottom - top,
    x: Math.floor((left + right) / 2),
    y: Math.floor((top + bottom) / 2)
  };
}

function center(bounds) {
  const parsed = parseBounds(bounds);
  if (parsed === null) {
    return null;
  }
  return {
    x: parsed.x,
    y: parsed.y
  };
}

function verticallyOverlaps(a, b) {
  return a.top <= b.bottom && b.top <= a.bottom;
}

function attrIsTrue(value) {
  return value === true || value === 'true';
}

function attrIsFalse(value) {
  return value === false || value === 'false';
}

function redactPublicPersonaLayout(value) {
  if (typeof value === 'string') {
    return value.replace(/https:\/\/[^\s"'<>|]+/gi, 'https://<redacted>');
  }
  if (Array.isArray(value)) {
    return value.map((item) => redactPublicPersonaLayout(item));
  }
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, redactPublicPersonaLayout(item)]));
  }
  return value;
}

function dumpLayout(localName = 'latest-layout.json', bundleName = 'com.jiuwen.appless') {
  const remote = '/data/local/tmp/aiphone-smoke-layout.json';
  const local = join(outDir, localName);
  const redact = localName.startsWith('public-persona-');
  let lastError = null;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const args = ['shell', 'uitest', 'dumpLayout', '-p', remote];
      if (bundleName.length > 0) args.push('-b', bundleName);
      hdc(args);
      hdc(['file', 'recv', remote, local]);
      const raw = readFileSync(local, 'utf8').trim();
      if (raw.length === 0) {
        throw new Error('dumpLayout produced an empty file');
      }
      const layout = JSON.parse(raw);
      if (!Array.isArray(layout.children) || layout.children.length === 0) {
        throw new Error('dumpLayout produced an empty accessibility tree');
      }
      if (redact) {
        writeFileSync(local, JSON.stringify(redactPublicPersonaLayout(layout), null, 2));
      }
      return layout;
    } catch (error) {
      lastError = error;
      if (redact) {
        try {
          writeFileSync(local, '{}');
        } catch (_writeError) {
        }
      }
      spawnSync('sleep', ['0.5']);
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

function captureCurrentScreen(localName = 'latest-screen.png') {
  const remote = '/data/local/tmp/aiphone-smoke-screen.png';
  const local = join(outDir, localName);
  hdc(['shell', 'uitest', 'screenCap', '-p', remote]);
  hdc(['file', 'recv', remote, local]);
  return local;
}

function captureScreen(localName = 'latest-screen.png') {
  moveAppWindowIntoScreenshot();
  return captureCurrentScreen(localName);
}

function captureForegroundAbility(localName) {
  const output = hdc(['shell', 'aa', 'dump', '-l']);
  const path = join(outDir, localName);
  writeFileSync(path, output);
  return {
    bundleName: foregroundBundleFromAbilityDump(output),
    path
  };
}

function sanitizeExternalUrlLogs(logText) {
  return String(logText || '')
    .replace(/("(?:bookingUrl|uri|url)"\s*:\s*")[^"]*(")/g, '$1<redacted>$2')
    .replace(/\b(url|uri|bookingUrl)=\S+/g, '$1=<redacted>');
}

function publicPersonaLogDelta(before, after) {
  const previous = String(before || '');
  const current = String(after || '');
  if (previous.length === 0) {
    return { delta: '', baselineMismatch: true };
  }
  const offset = current.indexOf(previous);
  return offset >= 0 ?
    { delta: current.slice(offset + previous.length), baselineMismatch: false } :
    { delta: '', baselineMismatch: true };
}

function publicPersonaStrictLogDelta(before, after) {
  const previous = String(before || '');
  const current = String(after || '');
  if (previous.length === 0) {
    return { matched: false, delta: '' };
  }
  const offset = current.indexOf(previous);
  return offset >= 0 ? { matched: true, delta: current.slice(offset + previous.length) } : { matched: false, delta: '' };
}

function publicPersonaPlatformFromHost(hostname) {
  const host = String(hostname || '').toLowerCase().replace(/^www\./, '');
  if (host === 'space.bilibili.com') return 'bilibili';
  if (host === 'zhihu.com') return 'zhihu';
  if (host === 'weibo.com') return 'weibo';
  if (host === 'github.com') return 'github';
  if (host.endsWith('.qzone.qq.com') || host === 'qzone.qq.com') return 'qq';
  if (host === 'scratch.mit.edu') return 'scratch';
  if (host === 'hackernoon.com') return 'hackernoon';
  if (host === 'inaturalist.org') return 'inaturalist';
  if (host === 'disqus.com') return 'disqus';
  if (host === 'bsky.app') return 'bluesky';
  if (host === 'chess.com') return 'chess';
  if (host === 'boosty.to') return 'boosty';
  if (host === 'tieba.baidu.com') return 'tieba';
  if (host.endsWith('.douban.com') || host === 'douban.com') return 'douban';
  if (host === 'npmjs.com') return 'npm';
  if (host === 'leetcode.cn') return 'leetcode_cn';
  if (host === 'gitee.com') return 'gitee';
  if (host === 'gitcode.com') return 'gitcode';
  if (host === 'yuque.com') return 'yuque';
  if (host === 'cnblogs.com') return 'cnblogs';
  if (host === 'v2ex.com') return 'v2ex';
  if (host === 'matrix-client.matrix.org') return 'matrix';
  if (host.endsWith('.tuchong.com') || host === 'tuchong.com') return 'tuchong';
  if (host === 'stackoverflow.com') return 'stackoverflow';
  if (host === 'gitlab.com') return 'gitlab';
  if (host === 'bitbucket.org') return 'bitbucket';
  if (host === 'hub.docker.com') return 'dockerhub';
  if (host === 'dev.to') return 'devto';
  if (host === 'producthunt.com') return 'producthunt';
  if (host === 'keybase.io') return 'keybase';
  if (host === 'huggingface.co') return 'huggingface';
  if (host === 'blog.csdn.net') return 'csdn';
  if (host === 'medium.com') return 'medium';
  if (host === 'mastodon.social' || host === 'fosstodon.org') return 'mastodon';
  if (host === 'about.me') return 'aboutme';
  if (host === 't.me') return 'telegram';
  if (host === 'behance.net') return 'behance';
  if (host === 'steamcommunity.com') return 'steam';
  if (host === 'lemmy.world') return 'lemmy';
  if (host === 'substack.com') return 'substack';
  if (host === 'codeberg.org') return 'codeberg';
  if (host === 'codeforces.com') return 'codeforces';
  if (host === 'leetcode.com') return 'leetcode';
  if (host === 'picsart.com') return 'picsart';
  if (host === 'dailymotion.com') return 'dailymotion';
  if (host === 'topcoder.com') return 'topcoder';
  if (host === 'mixcloud.com') return 'mixcloud';
  if (host.endsWith('.gravatar.com') || host === 'gravatar.com') return 'gravatar';
  if (host === 'gitea.com') return 'gitea';
  if (host.endsWith('.launchpad.net') || host === 'launchpad.net') return 'launchpad';
  if (host === 'deviantart.com') return 'deviantart';
  if (host === 'hackerrank.com') return 'hackerrank';
  if (host === 'discogs.com') return 'discogs';
  if (host === 'opencollective.com') return 'opencollective';
  if (host === 'misskey.io') return 'misskey';
  if (host === 'x.com' || host === 'twitter.com') return 'x';
  if (host === 'youtube.com') return 'youtube';
  if (host === 'linkedin.com') return 'linkedin';
  return '';
}

function publicPersonaAccountKey(url) {
  try {
    const parsed = new URL(url);
    const platform = publicPersonaPlatformFromHost(parsed.hostname);
    const segments = parsed.pathname.split('/').filter((value) => value.length > 0);
    if (platform.length === 0) return '';
    let username = segments.length === 0 ? '' : segments[segments.length - 1].replace(/^@/, '');
    if (platform === 'tieba') username = parsed.searchParams.get('un') || '';
    if (platform === 'tuchong' && parsed.hostname.toLowerCase() !== 'tuchong.com') {
      username = parsed.hostname.split('.')[0];
    }
    return username.length === 0 ? '' : `${platform}:${username.toLowerCase()}`;
  } catch {
    return '';
  }
}

function publicPersonaCandidateLayoutState(layout) {
  const labels = [
    ['bilibili', '哔哩哔哩'], ['zhihu', '知乎'], ['weibo', '微博'],
    ['github', 'GitHub'], ['qq', 'QQ 空间'], ['tieba', '百度贴吧'], ['douban', '豆瓣'], ['npm', 'NPM'],
    ['scratch', 'Scratch'], ['hackernoon', 'HackerNoon'], ['inaturalist', 'iNaturalist'],
    ['disqus', 'Disqus'], ['bluesky', 'Bluesky'], ['chess', 'Chess.com'], ['boosty', 'Boosty'],
    ['leetcode_cn', '力扣'], ['gitee', 'Gitee'], ['gitcode', 'GitCode'], ['yuque', '语雀'],
    ['cnblogs', '博客园'], ['v2ex', 'V2EX'], ['matrix', 'Matrix'], ['tuchong', '图虫'], ['stackoverflow', 'Stack Overflow'],
    ['gitlab', 'GitLab'], ['bitbucket', 'Bitbucket'], ['dockerhub', 'Docker Hub'], ['devto', 'DEV Community'],
    ['producthunt', 'Product Hunt'], ['keybase', 'Keybase'], ['huggingface', 'Hugging Face'], ['csdn', 'CSDN'],
    ['medium', 'Medium'], ['mastodon', 'Mastodon'], ['aboutme', 'About.me'], ['telegram', 'Telegram'],
    ['behance', 'Behance'], ['steam', 'Steam'],
    ['lemmy', 'Lemmy'], ['substack', 'Substack'], ['codeberg', 'Codeberg'],
    ['codeforces', 'Codeforces'], ['leetcode', 'LeetCode'], ['picsart', 'Picsart'],
    ['dailymotion', 'Dailymotion'], ['topcoder', 'Topcoder'],
    ['mixcloud', 'Mixcloud'], ['gravatar', 'Gravatar'], ['gitea', 'Gitea'],
    ['launchpad', 'Launchpad'], ['deviantart', 'DeviantArt'],
    ['hackerrank', 'HackerRank'], ['discogs', 'Discogs'], ['opencollective', 'Open Collective'], ['misskey', 'Misskey'],
    ['x', 'X'], ['youtube', 'YouTube'], ['linkedin', 'LinkedIn']
  ];
  const rows = [];
  walk(layout, (node) => {
    const bounds = parseBounds((node.attributes || {}).bounds);
    if (bounds === null || bounds.width < 200 || bounds.height < 45 || bounds.height > 300) return;
    const values = [];
    walk(node, (child) => {
      const attrs = child.attributes || {};
      ['text', 'content', 'description', 'hint'].forEach((key) => {
        const value = attrs[key];
        if (typeof value === 'string' && value.trim().length > 0) values.push(value.trim());
      });
    });
    const uniqueValues = [...new Set(values)];
    const line = uniqueValues.join('|');
    const username = /@([A-Za-z0-9][A-Za-z0-9._-]*)/.exec(line);
    const platform = labels.find((entry) => uniqueValues.some((value) => value === entry[1] ||
      value.indexOf('·') >= 0 && value.endsWith(entry[1])));
    const selected = uniqueValues.some((value) => value === '已选');
    const unselected = uniqueValues.some((value) => value === '选择');
    if (username === null || platform === undefined || !selected && !unselected) return;
    const key = `${platform[0]}:${username[1].toLowerCase()}`;
    if (!rows.some((row) => row.key === key)) rows.push({ key, selected });
  });
  return rows;
}

function publicPersonaProbeResultFromLog(log, platform) {
  const pattern = new RegExp(`\\[AIPhone\\]\\[PublicPersonaProbe\\] platform=${platform} result=(found|not_found|unknown)`, 'g');
  let result = '';
  for (const match of String(log || '').matchAll(pattern)) result = match[1];
  return result;
}

function publicPersonaProbeStatesFromLog(log) {
  const states = {};
  const pattern = /\[AIPhone\]\[PublicPersonaProbe\] platform=([a-z0-9_]+) result=(found|not_found|unknown)/g;
  for (const match of String(log || '').matchAll(pattern)) states[match[1]] = match[2];
  return states;
}

function collectLayoutText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    ['text', 'content', 'description', 'hint', 'accessibilityText'].forEach((key) => {
      const value = attrs[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        values.push(value.trim());
      }
    });
  });
  return [...new Set(values)];
}

function findTextCenter(layout, marker) {
  const matches = findTextMatches(layout, marker);
  if (matches.length === 0) {
    return null;
  }
  return {
    x: matches[0].bounds.x,
    y: matches[0].bounds.y
  };
}

function findExactTextCenter(layout, marker) {
  const match = findTextMatches(layout, marker).find((item) =>
    item.text.split('|').some((value) => value.trim() === marker));
  return match === undefined ? null : { x: match.bounds.x, y: match.bounds.y };
}

function findHotelDetailTextCenter(layout, marker) {
  const match = findTextMatches(layout, marker).find((item) =>
    item.text.split('|').some((value) =>
      matchesHotelDetailAccessibleLabel(value, marker)));
  return match === undefined ? null : { x: match.bounds.x, y: match.bounds.y };
}

function findTextMatches(layout, marker) {
  const matches = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null) {
      return;
    }
    const text = ['text', 'content', 'description', 'hint', 'accessibilityText']
      .map((key) => attrs[key])
      .filter((value) => typeof value === 'string' && value.includes(marker))
      .join('|');
    if (text.length > 0) {
      matches.push({
        text,
        bounds
      });
    }
  });
  matches.sort((a, b) => a.bounds.top - b.bounds.top || a.bounds.left - b.bounds.left);
  return matches;
}

function findHeaderSettingsCenter(layout) {
  const candidates = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null || !attrIsTrue(attrs.clickable) || attrIsFalse(attrs.enabled)) {
      return;
    }
    if (bounds.top <= 360 && bounds.width >= 32 && bounds.width <= 160 && bounds.height >= 32 && bounds.height <= 160) {
      candidates.push(bounds);
    }
  });
  candidates.sort((left, right) => right.x - left.x);
  return candidates.length > 0 ? { x: candidates[0].x, y: candidates[0].y } : null;
}

function findHeaderPublicPersonaCenter(layout) {
  const candidates = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null || !attrIsTrue(attrs.clickable) || attrIsFalse(attrs.enabled)) return;
    if (bounds.top <= 360 && bounds.width >= 32 && bounds.width <= 160 && bounds.height >= 32 && bounds.height <= 160) {
      candidates.push(bounds);
    }
  });
  candidates.sort((left, right) => right.x - left.x);
  return candidates.length > 1 ? { x: candidates[1].x, y: candidates[1].y } : null;
}

async function findTextCenterWithScroll(marker, localNamePrefix, maxSwipes = 4) {
  for (let attempt = 0; attempt <= maxSwipes; attempt += 1) {
    const layout = dumpLayout(`${localNamePrefix}-${attempt + 1}.json`);
    const text = collectLayoutText(layout).join('\n');
    writeFileSync(join(outDir, `${localNamePrefix}-${attempt + 1}-text.txt`), text + '\n');
    const found = findTextCenter(layout, marker);
    if (found !== null) {
      return found;
    }
    swipeResultsUp();
    await sleep(800);
  }
  return null;
}

async function findExternalAuthActionWithScroll(appName, localNamePrefix, maxSwipes = 5) {
  for (let attempt = 0; attempt <= maxSwipes; attempt += 1) {
    const layout = dumpLayout(`${localNamePrefix}-${attempt + 1}.json`);
    const text = collectLayoutText(layout).join('\n');
    writeFileSync(join(outDir, `${localNamePrefix}-${attempt + 1}-text.txt`), text + '\n');
    const app = findTextMatches(layout, appName).find((item) =>
      item.text.split('|').some((value) => value.trim() === appName));
    const actions = findTextMatches(layout, '授权').filter((item) =>
      item.text.split('|').some((value) => value.trim() === '授权'));
    if (app !== undefined) {
      const action = actions
        .filter((item) => item.bounds.y > app.bounds.y &&
          item.bounds.y - app.bounds.y < 280 &&
          item.bounds.x > app.bounds.x)
        .sort((left, right) =>
          Math.abs(left.bounds.y - app.bounds.y) - Math.abs(right.bounds.y - app.bounds.y))[0];
      if (action !== undefined) {
        return { x: action.bounds.x, y: action.bounds.y };
      }
    }
    swipeResultsUp();
    await sleep(800);
  }
  return null;
}

function collectInputText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if (attrs.type === 'TextInput' || attrs.type === 'TextArea') {
      ['text', 'content', 'description', 'hint'].forEach((key) => {
        const value = attrs[key];
        if (typeof value === 'string' && value.trim().length > 0) {
          values.push(value.trim());
        }
      });
    }
  });
  return values.join('|');
}

function findControls(layout, requireSend = true) {
  let input = null;
  let inputBounds = null;
  let generate = null;
  const clickable = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if ((attrs.type === 'TextInput' || attrs.type === 'TextArea') && input === null && bounds !== null) {
      inputBounds = bounds;
      input = {
        x: bounds.x,
        y: bounds.y
      };
    }
    if (bounds !== null && attrIsTrue(attrs.clickable) && !attrIsFalse(attrs.enabled)) {
      clickable.push({
        type: attrs.type || '',
        text: attrs.text || '',
        bounds
      });
    }
    if (attrs.type === 'Button' && attrs.text === '生成' && bounds !== null) {
      generate = {
        x: bounds.x,
        y: bounds.y
      };
    }
  });
  if (input === null) {
    throw new Error('Could not locate AIPhone input control.');
  }
  if (generate === null && inputBounds !== null) {
    const sendCandidate = clickable
      .filter((item) => item.bounds.left >= inputBounds.right - 4 &&
        item.bounds.left <= inputBounds.right + 360 &&
        verticallyOverlaps(item.bounds, inputBounds) &&
        item.bounds.width >= 24 &&
        item.bounds.width <= 180 &&
        item.bounds.height >= 24 &&
        item.bounds.height <= 180)
      .sort((a, b) => b.bounds.x - a.bounds.x)[0];
    if (sendCandidate) {
      generate = {
        x: sendCandidate.bounds.x,
        y: sendCandidate.bounds.y
      };
    }
  }
  if (generate === null && requireSend) {
    throw new Error('Could not locate AIPhone send control.');
  }
  return { input, generate };
}

async function waitForControls(localName = 'latest-layout.json', attempts = 10, requireSend = true) {
  let lastError = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return findControls(dumpLayout(localName), requireSend);
    } catch (error) {
      lastError = error;
      await sleep(500);
    }
  }
  throw lastError || new Error('Could not locate AIPhone input/generate controls.');
}

function lineMatchesPid(line, pid) {
  if (pid.length === 0) {
    return true;
  }
  return line.indexOf(` ${pid} `) >= 0;
}

async function captureWhile(appPid, runAction, lifecycleOptions = null) {
  const logs = [];
  const child = spawn(hdcCommand, ['-t', target, 'hilog'], {
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  let buffer = '';
  const onData = (chunk) => {
    buffer += chunk;
    const parts = buffer.split('\n');
    buffer = parts.pop() || '';
    for (const line of parts) {
      if (lineMatchesPid(line, appPid) && (line.includes('AIPhone') || line.includes('aiphonedemo') || line.includes('NETSTACK') || line.includes('11434'))) {
        logs.push(line);
      }
    }
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);

  let actionError = null;
  try {
    await sleep(800);
    await runAction();

    const started = Date.now();
    let doneAt = 0;
    while (Date.now() - started < timeoutMs) {
      await sleep(500);
      const text = logs.join('\n');
      const hotelActionEvidence = hotelActionEvidenceFromLogs(text);
      const hasHotelActionEvidence =
        typeof hotelActionEvidence.surfaceId === 'string' &&
        hotelActionEvidence.surfaceId.length > 0;
      const hotelActionEvidencePopulated =
        hasPopulatedHotelActionEvidence(hotelActionEvidence);
      const hotelToolLifecycle = hotelToolLifecycleFromLogs(text);
      const hotelToolLifecycleComplete = hotelToolLifecycle.ok;
      const customCompletion = lifecycleOptions !== null &&
        typeof lifecycleOptions.completionEvidence === 'function' ?
        lifecycleOptions.completionEvidence(text) : null;
      const multiAgentLifecycle = lifecycleOptions === null || customCompletion !== null ? null :
        multiAgentTurnEvidence(text, lifecycleOptions);
      const hasTerminalOutcome =
        /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=/.test(text) ||
        /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text);
      const done = customCompletion !== null ? customCompletion.complete :
        lifecycleOptions === null ?
        (hotelActionEvidencePopulated || hotelToolLifecycleComplete || hasTerminalOutcome) :
        multiAgentLifecycle.complete;
      const hotelActionRequested =
        /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel|LocalToolRequest)\][^\n]*toolId=hotel\.(?:search|detail)/.test(text);
      const hotelRuntimeRequested = hotelActionRequested || hotelToolLifecycle.requested;
      const hasQueryHtmlDocument = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=(?!welcome\b)[^ \n]+[^\n]*chars=\d+[^\n]*blocks=\d+/.test(text);
      if (done && doneAt === 0) {
        doneAt = Date.now();
      }
      const hotelUiReady = customCompletion !== null ? customCompletion.complete :
        lifecycleOptions !== null ? multiAgentLifecycle.complete :
        hotelActionEvidencePopulated ||
        (hotelToolLifecycleComplete && Date.now() - doneAt > 1500) ||
        (hasTerminalOutcome && hasHotelActionEvidence && Date.now() - doneAt > 1500);
      const completionSettled = captureCompletionSettled({
        done,
        doneAt,
        lifecycleOptions,
        customCompletion,
        now: Date.now()
      });
      if (customCompletion !== null && completionSettled) {
        break;
      }
      if (customCompletion !== null && !done && lifecycleOptions.idleActionTimeoutMs > 0 &&
        Date.now() - started > lifecycleOptions.idleActionTimeoutMs &&
        !/\[AIPhone\]\[MultiAgentActionRun\][^\n]*action=(?:mail|gmail)\.thread\.read\b/.test(text)) {
        break;
      }
      if (customCompletion === null && completionSettled && (!hotelRuntimeRequested || hotelUiReady) &&
        (hasQueryHtmlDocument || Date.now() - doneAt > 3000)) {
        break;
      }
      const modelFailed = /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text);
      const hasToolRequest = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text);
      if (lifecycleOptions === null && modelFailed && !hasToolRequest &&
        Date.now() - started > 5000) {
        break;
      }
    }
  } catch (error) {
    actionError = error;
  } finally {
    child.kill('SIGTERM');
    await waitForProcessExit(child, 1500);
    if (child.exitCode === null) {
      child.kill('SIGKILL');
      await waitForProcessExit(child, 1500);
    }
    cleanupHilogProcesses();
  }
  if (actionError !== null) {
    throw actionError;
  }
  return logs;
}

async function captureAppLogsFor(appPid, runAction, durationMs = 2500) {
  const logs = [];
  const child = spawn(hdcCommand, ['-t', target, 'hilog'], {
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  let buffer = '';
  const onData = (chunk) => {
    buffer += chunk;
    const parts = buffer.split('\n');
    buffer = parts.pop() || '';
    for (const line of parts) {
      if (lineMatchesPid(line, appPid) &&
        (line.includes('AIPhone') || line.includes('aiphonedemo'))) {
        logs.push(line);
      }
    }
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);

  let actionError = null;
  try {
    await sleep(800);
    await runAction();
    await sleep(durationMs);
  } catch (error) {
    actionError = error;
  } finally {
    child.kill('SIGTERM');
    await waitForProcessExit(child, 1500);
    if (child.exitCode === null) {
      child.kill('SIGKILL');
      await waitForProcessExit(child, 1500);
    }
    cleanupHilogProcesses();
  }
  if (actionError !== null) {
    throw actionError;
  }
  return logs;
}

function waitForProcessExit(child, timeoutMs) {
  return new Promise((resolve) => {
    let resolved = false;
    const finish = () => {
      if (!resolved) {
        resolved = true;
        resolve();
      }
    };
    child.once('exit', finish);
    setTimeout(finish, timeoutMs);
  });
}

function activeHilogProcesses() {
  const result = process.platform === 'win32' ?
    spawnSync('C:\\Program Files\\PowerShell\\7\\pwsh.exe', [
      '-NoProfile', '-Command',
      "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'hdc.*hilog' } | " +
        'ForEach-Object { "{0} {1}" -f $_.ProcessId, $_.CommandLine }'
    ], { encoding: 'utf8' }) :
    spawnSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' });
  return String(result.stdout || '')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('hdc') && line.includes('hilog'));
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function htmlHomeDocumentEvidence(logs) {
  const documents = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=([^ \n]+)[^\n]*kind=([^ \n]+)[^\n]*chars=(\d+)[^\n]*blocks=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    documents.push({
      source: match[1],
      kind: match[2],
      chars: Number.parseInt(match[3], 10),
      blocks: Number.parseInt(match[4], 10)
    });
  }
  const queryDocuments = documents.filter((document) => document.source !== 'welcome');
  return {
    count: documents.length,
    queryCount: queryDocuments.length,
    maxChars: documents.reduce((max, document) => Math.max(max, document.chars), 0),
    maxBlocks: documents.reduce((max, document) => Math.max(max, document.blocks), 0),
    ok: queryDocuments.some((document) => document.chars > 0 && document.blocks > 0)
  };
}

function htmlHomeSurfaceLoadEvidence(logs) {
  const loads = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeSurfaceLoad\][^\n]*chars=(\d+)[^\n]*renderTick=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    loads.push({
      chars: Number.parseInt(match[1], 10),
      renderTick: Number.parseInt(match[2], 10)
    });
  }
  return {
    count: loads.length,
    maxChars: loads.reduce((max, load) => Math.max(max, load.chars), 0),
    ok: loads.some((load) => load.chars > 0)
  };
}

function analyze(
  query,
  logs,
  expectedTool,
  expectedToolId = '',
  expectedDiscoveredToolId = '',
  expectedDynamicQualifiedName = '',
  expectedToolIds = [],
  minimumDataRounds = 0,
  expectedDependencies = [],
  expectedDataRounds = [],
  expectedParallelDataToolIds = [],
  expectedLeaderMemoryCapability = '',
  verifyMemoryRecall = false
) {
  const text = logs.join('\n');
  const dailyBriefDirect = expectedToolId === 'daily.brief.open' ?
    dailyBriefDirectEvidence(text) : null;
  const multiAgentLifecycle = multiAgentTurnEvidence(text, {
    expectedToolIds,
    minimumDataRounds,
    expectedDependencies,
    expectedDataRounds,
    expectedParallelDataToolIds
  });
  const executionEvidence = toolExecutionEvidence(text, {
    expectedToolIds,
    minimumDataRounds,
    expectedDependencies,
    expectedDataRounds,
    expectedParallelDataToolIds
  });
  const htmlHomeDocument = htmlHomeDocumentEvidence(logs);
  const htmlHomeSurfaceLoad = htmlHomeSurfaceLoadEvidence(logs);
  const escapedToolId = escapeRegExp(expectedToolId);
  const hasExpectedToolId = multiAgentLifecycle.complete &&
    expectedToolIds.every((toolId) => multiAgentLifecycle.toolIds.includes(toolId));
  const dynamicDiscovery = expectedDiscoveredToolId.length === 0 ? null :
    dynamicToolDiscoveryEvidence(text, {
      expectedSelectedToolId: expectedDiscoveredToolId,
      expectedProvider: expectedDiscoveredToolId === 'dynamic.search' ? 'composio' : '',
      expectedQualifiedName: expectedDynamicQualifiedName
    });
  const hasExpectedDiscoveredToolId = dynamicDiscovery === null ? true : dynamicDiscovery.ok;
  const missingConfig = /\[AIPhone\]\[LocalToolMissingConfig\]/.test(text);
  const externalBlocked = externalProviderBlocked(text, multiAgentLifecycle);
  const rawModelSelectedExpectedToolId = expectedToolId.length === 0 ||
    new RegExp(`"toolId":"${escapedToolId}"`).test(text) ||
    new RegExp(`toolId=${escapedToolId}`).test(text);
  const modelSelectedExpectedToolId = expectedToolId.length === 0 ||
    executionEvidence.exactMultiAgentLifecycle ||
    (!executionEvidence.hasMultiAgentInput && rawModelSelectedExpectedToolId);
  const personaCoffeeProof = !isPersonaCoffeeQuery(query) || /饮食搭子上线|饮食搭子/.test(text);
  const memoryRecall = leaderMemoryRecallEvidence(text);
  const leaderMemoryTool = expectedLeaderMemoryCapability.length === 0 ?
    { observed: false, ok: true, capability: '', operation: '', status: '', succeeded: 0, failed: 0,
      identityMatches: true, noActionAgent: true } :
    leaderMemoryToolEvidence(text, expectedLeaderMemoryCapability, multiAgentLifecycle);
  const result = {
    query,
    expectedTool,
    expectedToolId,
    expectedToolIds,
    expectedDiscoveredToolId,
    expectedDynamicQualifiedName,
    dailyBriefDirect,
    dynamicDiscovery,
    multiAgentLifecycle,
    hasExpectedToolId,
    hasExpectedDiscoveredToolId,
    htmlHomeDocument,
    htmlHomeSurfaceLoad,
    htmlLoadError: /\[AIPhone\]\[HtmlHomeSurfaceLoadError\]/.test(text),
    modelSelectedExpectedToolId,
    exactMultiAgentToolLifecycle: executionEvidence.exactMultiAgentLifecycle,
    toolExecutionObserved: executionEvidence.observed,
    personaCoffeeProof,
    memoryRecall,
    leaderMemoryTool,
    directIntent: /\[AIPhone\]\[(ToolRequestByIntent|A2uiHomeToolRequestByIntent)\] toolId=/.test(text),
    localToolRequest: /\[AIPhone\]\[LocalToolRequest\] endpoint=local:\/\/aiphone-tools toolId=/.test(text),
    model200: modelTransportEvidence(text, {
      expectedToolIds,
      minimumDataRounds,
      expectedDependencies
    }),
    modelOk: multiAgentLifecycle.ok,
    toolRequested: multiAgentLifecycle.toolIds.length > 0,
    toolOk: multiAgentLifecycle.ok && multiAgentLifecycle.toolIds.length > 0,
    failedConnect: /failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|server is not running|CURLcode result 7|curl_code":7|os_errno":111/i.test(text),
    providerFailed: /\[AIPhone\]\[LocalTool12306Endpoint\][^\n]*code=[45]\d\d/.test(text) ||
      /\[AIPhone\]\[LocalToolException\]/.test(text) ||
      /\[AIPhone\]\[A2uiHomeToolOutput\][^\n]*"status":"error"/.test(text) ||
      /Google Calendar API 调用失败/.test(text) ||
      /invalid request data provided|Composio 调用失败|WhatsApp Business 账号不可用/i.test(text) ||
      externalBlocked ||
      (multiAgentLifecycle.complete && multiAgentLifecycle.status === 'error') ||
      (missingConfig && expectedToolId !== 'travel.search'),
    modelFailed: !multiAgentLifecycle.ok,
    toolNone: multiAgentLifecycle.complete && multiAgentLifecycle.toolIds.length === 0,
    gmailWebOpened:
      /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel|LocalToolRequest)\][^\n]*toolId=gmail\.open\.web/.test(text) &&
      /\[AIPhone\]\[A2uiHomeOpenUrl\] ok=true scheme=https chars=\d+/.test(text),
    worldCupOpened: /\[AIPhone\]\[AnythingDemoRouteByTool\]/.test(text),
    movieOpened: /\[AIPhone\]\[MovieDemoRouteByTool\]/.test(text),
    syntheticFallback: forbiddenSyntheticMarkers.some((marker) => text.includes(marker))
  };
  const modelPassed = multiAgentLifecycle.ok;
  const expectsDirectText = expectedTool === false;
  const directTextLifecycle = expectsDirectText && multiAgentLifecycle.complete &&
    multiAgentLifecycle.ok && multiAgentLifecycle.status === 'success' &&
    multiAgentLifecycle.textResult && multiAgentLifecycle.surfaceId === 'none' &&
    multiAgentLifecycle.finalUiSurfaceId === '' && multiAgentLifecycle.toolIds.length === 0 &&
    multiAgentLifecycle.dataTasks.length === 0 && multiAgentLifecycle.surfaceIds.length === 0 &&
    result.model200 && !result.directIntent && !result.syntheticFallback;
  const htmlDocumentPassed = result.htmlHomeDocument.ok ||
    (isSocialHubExpectedToolId(expectedToolId) && result.htmlHomeDocument.count > 0) ||
    (expectedToolId === 'worldcup.open' && result.worldCupOpened) ||
    (expectedToolId === 'movie.open' && result.movieOpened);
  const baseWithoutTransport = expectsDirectText ?
    !result.htmlLoadError && directTextLifecycle :
    !result.htmlLoadError &&
      result.htmlHomeSurfaceLoad.ok &&
      !result.syntheticFallback &&
      (!result.directIntent ||
        (expectedToolId === 'worldcup.open' && result.worldCupOpened) ||
        (expectedToolId === 'movie.open' && result.movieOpened)) &&
      htmlDocumentPassed;
  result.modelPassed = modelPassed;
  result.directTextLifecycle = directTextLifecycle;
  result.transportPassed = !result.failedConnect && !result.providerFailed;
  result.basePassedWithoutTransport = baseWithoutTransport;
  const basePassed = result.transportPassed && baseWithoutTransport;
  if (dailyBriefDirect !== null) {
    Object.assign(result, dailyBriefDirectAnalysis(result, dailyBriefDirect));
  } else if (expectedLeaderMemoryCapability.length > 0) {
    result.modelPassed = multiAgentLifecycle.ok && leaderMemoryTool.ok;
    result.transportPassed = true;
    result.basePassedWithoutTransport = directTextLifecycle;
    result.ok = result.modelPassed && directTextLifecycle &&
      (!verifyMemoryRecall || memoryRecall.ok);
  } else if (expectedTool === true) {
    result.ok = basePassed && modelPassed && result.toolRequested && result.toolOk &&
      result.hasExpectedToolId && result.hasExpectedDiscoveredToolId && result.personaCoffeeProof;
  } else if (expectedTool === false) {
    result.ok = basePassed && modelPassed && result.toolNone && !result.toolRequested;
  } else {
    result.ok = basePassed && modelPassed &&
      (result.toolRequested ? result.toolOk : result.toolNone);
  }
  if (verifyMemoryRecall && !memoryRecall.ok) {
    result.ok = false;
  }
  return result;
}

function isGmailWebQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /打开|网页版|网页/.test(query);
}

function isPersonaCoffeeQuery(query) {
  return /点一杯咖啡|来一杯咖啡|买杯咖啡/.test(query);
}

function expectedLeaderMemoryCapabilityForQuery(query) {
  if (/忘掉|忘记|删除.+记忆/.test(query) && /长期偏好|长期记忆/.test(query)) {
    return 'memory.forget';
  }
  if (/长期记住|请记住|帮我记住/.test(query)) {
    return 'memory.remember';
  }
  return '';
}

function memoryPreferenceVisible(text, preference) {
  if (preference === 'oat_milk') {
    return /燕麦奶|燕麦咖啡|燕麦拿铁/.test(text);
  }
  return false;
}

function lineEvidenceFields(line) {
  const fields = {};
  for (const match of String(line || '').matchAll(/\b([A-Za-z][A-Za-z0-9]*)=([^\s]+)/g)) {
    fields[match[1]] = match[2];
  }
  return fields;
}

function leaderMemoryRecallEvidence(text) {
  const lines = String(text || '').split('\n')
    .filter((line) => /\[AIPhone\]\[LeaderMemoryRecall\]/.test(line));
  const line = lines.at(-1) || '';
  const fields = lineEvidenceFields(line);
  const count = /^\d+$/.test(fields.count || '') ? Number.parseInt(fields.count, 10) : -1;
  const durationMs = /^\d+$/.test(fields.durationMs || '') ? Number.parseInt(fields.durationMs, 10) : -1;
  const status = fields.status || '';
  const validCount = status === 'hit' || status === 'success' ? count > 0 :
    (status === 'miss' || status === 'empty' ? count === 0 : false);
  return {
    observed: line.length > 0,
    ok: line.length > 0 && validCount && durationMs >= 0,
    status,
    count,
    durationMs
  };
}

function leaderMemoryToolEvidence(text, expectedCapability, lifecycle) {
  const expectedOperation = String(expectedCapability || '').replace(/^memory\./, '');
  const lines = [...new Set(String(text || '').split('\n')
    .filter((line) => /\[AIPhone\]\[LeaderMemoryTool\]/.test(line))
    .map((line) => line.slice(line.indexOf('[AIPhone][LeaderMemoryTool]'))))];
  const matching = lines.map((line) => ({ line, fields: lineEvidenceFields(line) }))
    .filter((item) => item.fields.operation === expectedOperation);
  const selected = matching.at(-1) || { line: '', fields: {} };
  const fields = selected.fields;
  const succeeded = /^\d+$/.test(fields.succeeded || '') ? Number.parseInt(fields.succeeded, 10) : -1;
  const failed = /^\d+$/.test(fields.failed || '') ? Number.parseInt(fields.failed, 10) : -1;
  const hasIdentity = typeof fields.conversation === 'string' && fields.conversation.length > 0 &&
    typeof fields.turn === 'string' && fields.turn.length > 0 &&
    typeof fields.task === 'string' && fields.task.length > 0;
  const identityMatches = lifecycle !== null && lifecycle !== undefined &&
    lifecycle.conversationId.length > 0 && lifecycle.turnId.length > 0 && hasIdentity &&
    matching.length === 1;
  const successfulTerminal = fields.status === 'success' && succeeded > 0 && failed === 0;
  const noActionAgent = !/\[AIPhone\]\[MultiAgentActionPlan\]/.test(text) &&
    !/\[AIPhone\]\[PersonaMemoryUpdate\]/.test(text);
  return {
    observed: selected.line.length > 0,
    ok: selected.line.length > 0 && identityMatches && successfulTerminal && noActionAgent,
    capability: expectedCapability,
    operation: fields.operation || '',
    status: fields.status || '',
    succeeded,
    failed,
    identityMatches,
    noActionAgent
  };
}

function isGmailEccvQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /eccv/i.test(query);
}

function isQqMailQuery(query) {
  return /QQ\s*邮箱|QQ邮箱/i.test(query);
}

function isMailAggregationQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/i.test(query) && isQqMailQuery(query);
}

function isYouTubeBilibiliQuery(query) {
  return /YouTube|油管/i.test(query) && /B站|B 站|Bilibili|哔哩哔哩/i.test(query);
}

function isAggregateMediaSearchQuery(query) {
  if (isSocialFeedQuery(query)) {
    return false;
  }
  const wantsTopic = /有关|关于|看看|搜索|搜|聚合|整理|汇总|追踪|了解/.test(query);
  const wantsDiscussion = /新闻|讨论|热议|舆论|观点|帖子|po文|post|posts|reaction|reactions|public/i.test(query);
  if (!wantsTopic || !wantsDiscussion) {
    return false;
  }
  const mentionsVideoSource = /YouTube|油管|B站|B 站|Bilibili|哔哩哔哩/i.test(query);
  const mentionsTextSource = /Twitter|推文|x\.com|知乎|Hacker\s*News|HackNews|HackerNews|\bHN\b|Reddit|红迪/i.test(query) ||
    (hasStandaloneXMarker(query) && /上|平台|推文|公开\s*posts?\b|public\s+posts?\b/i.test(query));
  const asksMixedView = /聚合|多来源|多平台|汇总|新闻.*讨论|讨论.*新闻/.test(query) ||
    (/视频.*讨论|讨论.*视频/.test(query) && (!mentionsVideoSource || mentionsTextSource));
  if (mentionsVideoSource && !mentionsTextSource && !asksMixedView) {
    return false;
  }
  if (isXPostSearchQuery(query) && !mentionsVideoSource && !asksMixedView) {
    return false;
  }
  return asksMixedView || mentionsVideoSource && mentionsTextSource || !mentionsVideoSource && !mentionsTextSource;
}

function isSocialFeedQuery(query) {
  return /社交|消息聚合|多平台消息|已授权应用.*私信|私信消息|Slack|企业微信|Discord|LinkedIn|WhatsApp|Instagram|Instgram/i.test(query);
}

function isSocialHubExpectedToolId(expectedToolId) {
  return expectedToolId === 'social.feed.search';
}

function hasStandaloneXMarker(query) {
  return /(^|[^A-Za-z0-9_])X(?=$|[^A-Za-z0-9_])/i.test(query.replace(/Xcode/gi, ''));
}

function isXPostSearchQuery(query) {
  const text = query.replace(/Xcode/gi, '');
  if (/posts?\s*[- ]?\s*processing/i.test(text)) {
    return false;
  }
  const hasPlatform = /Twitter|推文|x\.com/i.test(text) ||
    (hasStandaloneXMarker(text) && /上|平台|推文|公开\s*posts?\b|public\s+posts?\b/i.test(text));
  return hasPlatform && /读|看|查看|查|查询|搜索|搜|最近|公开|read|search|find|recent|latest|public/i.test(text);
}

function hasTruthfulSocialHubState(text) {
  return /SocialHub/.test(text) &&
    /授权状态/.test(text) &&
    /来源\s*·|暂无可读消息/.test(text) &&
    /发信人\s*·|当前.*不提供|读取失败|尚未连接|没有可读消息|暂无可读消息/i.test(text);
}

function hasVisibleSocialHubOutput(text, expectedToolId) {
  if (!hasTruthfulSocialHubState(text)) {
    return false;
  }
  if (expectedToolId === 'x.post.search') {
    return /\bX\b/.test(text);
  }
  if (expectedToolId === 'social.feed.search') {
    return /来源\s*·/.test(text) && /发信人\s*·/.test(text) && /回复/.test(text) ||
      /暂无可读消息/.test(text);
  }
  return false;
}

function hasVisibleAggregateMediaOutput(text) {
  return /聚合搜索/.test(text) &&
    /视频/.test(text) &&
    /讨论/.test(text) &&
    /YouTube/.test(text) &&
    /B 站/.test(text) &&
    /\bX\b/.test(text) &&
    /\bHN\b/.test(text);
}

function isCalendarQuery(query) {
  return /Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query);
}

function isComposioCardQuery(query) {
  return (/GitHub/i.test(query) && /Appless-Phone/i.test(query) && /\bpr\b|pull\s*request/i.test(query)) ||
    (/Google\s*Drive/i.test(query) && /专利交底书/.test(query)) ||
    (/Google\s*Docs?/i.test(query) && /AIPhoneDemo/.test(query)) ||
    (/Composio/i.test(query) && /Slack/i.test(query) && /AIPhoneDemo/.test(query) && !isSocialFeedQuery(query)) ||
    (/Outlook|Spotify|Soptify|TikTok|Ticketmaster/i.test(query) && !isSocialFeedQuery(query));
}

function layoutExpectationsForQuery(query) {
  if (expectedLeaderMemoryCapabilityForQuery(query).length > 0) {
    return [];
  }
  if (isSocialFeedQuery(query) && !isWhatsAppSendQuery(query)) {
    return ['SocialHub', '授权状态'];
  }
  if (/GitHub/i.test(query) && /Appless-Phone/i.test(query) && /\bpr\b|pull\s*request/i.test(query)) {
    return ['Composio 工具结果', 'Composio GitHub 结果', 'GITHUB_FIND_PULL_REQUESTS', 'Appless-Phone'];
  }
  if (/Google\s*Drive/i.test(query) && /专利交底书/.test(query)) {
    return ['Composio 工具结果', 'Composio Google Drive 结果', 'GOOGLEDRIVE_FIND_FILE', '专利交底书'];
  }
  if (/Google\s*Docs?/i.test(query) && /AIPhoneDemo/.test(query)) {
    return ['Composio 工具结果', 'Composio Google Docs 结果', 'GOOGLEDOCS_SEARCH_DOCUMENTS', 'AIPhoneDemo'];
  }
  if (/Composio/i.test(query) && /Slack/i.test(query) && /AIPhoneDemo/.test(query)) {
    return ['Composio 工具结果', 'Composio Slack 结果', 'SLACK_SEARCH_MESSAGES', 'AIPhoneDemo'];
  }
  if (/Outlook/i.test(query)) {
    return ['Composio Outlook 结果', 'Outlook'];
  }
  if (/Discord/i.test(query)) {
    return ['Composio Discord 结果', 'Discord'];
  }
  if (/LinkedIn/i.test(query)) {
    return ['Composio LinkedIn 结果', 'LinkedIn'];
  }
  if (isWhatsAppSendQuery(query)) {
    return ['WhatsApp Business', 'whatsapp.message.send', '确认发送'];
  }
  if (/Spotify|Soptify/i.test(query)) {
    return ['Composio Spotify 结果', 'Spotify'];
  }
  if (/TikTok/i.test(query)) {
    return ['Composio TikTok 结果', 'TikTok'];
  }
  if (/Ticketmaster/i.test(query)) {
    return ['Composio Ticketmaster 结果', 'Ticketmaster'];
  }
  if (/^你好$|问候|打招呼/.test(query)) {
    return ['你好'];
  }
  if (isDailyBriefQuery(query)) {
    return DAILY_BRIEF_VISIBLE_MARKERS;
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return ['接入工具', 'dynamic.search', '没有找到'];
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return ['接入工具', 'weather.query', 'AMAP_MAPS_API_KEY', '高德天气预报', '预报日期'];
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return ['接入工具', 'statistics.search', 'Authorization', '中国国家统计局'];
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return ['接入工具', 'ppt.generate', 'API_KEY', 'unsupported_transport', '歌者PPT'];
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return ['Composio', 'x.post.search', 'Twitter'];
  }
  if (isSocialFeedQuery(query)) {
    return ['SocialHub'];
  }
  if (isMailAggregationQuery(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', 'Outlook', '不会模拟'];
  }
  if (isQqMailQuery(query)) {
    return ['mail.search', 'QQ Mail', '不会模拟'];
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', 'Outlook', '不会模拟'];
  }
  if (isGmailWebQuery(query)) {
    return ['Gmail Web', 'gmail.open.web', 'https://mail.google.com'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return ['gmail.draft.create', 'Composio Gmail', '授权 Gmail', '不会模拟 Gmail 邮件'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return ['gmail.draft.create', 'Composio Gmail', '授权 Gmail', 'Draft saved', 'Saved in Gmail', 'ready_to_apply', '不会模拟 Gmail 邮件'];
  }
  if (isGmailEccvQuery(query)) {
    return ['Composio', 'Gmail', 'gmail.mail.search', '不会模拟 Gmail 邮件'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/i.test(query)) {
    return ['Composio', 'Gmail', 'gmail.mail.search', '不会模拟 Gmail 邮件'];
  }
  if (/PayPal|Google\s*Pay|GPay|支付|转账|付款/i.test(query)) {
    return ['AIPhone Pay', 'PayPal', 'Google Pay', '5 USD', '确认支付'];
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return ['Composio', 'YouTube', 'youtube.mine.playlists', '不会模拟播放列表'];
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return ['Composio', 'YouTube', 'youtube.mine.subscriptions', '不会模拟播放列表'];
  }
  if (isYouTubeBilibiliQuery(query)) {
    return ['YouTube', 'YouTube Data API', '哔哩哔哩', 'Bilibili'];
  }
  if (isAggregateMediaSearchQuery(query)) {
    return ['聚合搜索', '视频', '讨论', 'YouTube', 'B 站', 'X', 'HN', 'Reddit'];
  }
  if (/YouTube|油管/i.test(query)) {
    return ['YouTube', 'youtube.video.search', 'YouTube Data API', 'YOUTUBE_API_KEY'];
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return ['哔哩哔哩', 'media.video.search', '跳转'];
  }
  if (/热映电影|电影票房|院线电影|电影专页|明星动态/.test(query)) {
    return ['电影 Anything OS', '当日票房', '明星正在发生'];
  }
  if (isCalendarQuery(query)) {
    return /删除|取消/.test(query)
      ? ['Composio', 'Google Calendar', 'calendar.event.delete']
      : (/创建|新建|添加|安排|预约/.test(query)
      ? ['Composio', 'Google Calendar', 'calendar.event.create']
      : (/改到|改成|更新|挪到|延期/.test(query)
        ? ['Composio', 'Google Calendar', 'calendar.event.update']
        : ['Composio', 'Google Calendar', 'calendar.events.search']));
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return ['Google Maps', '暂不支持'];
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query)) {
    return ['北京', '上海'];
  }
  if (/航班|机票|飞机/.test(query)) {
    return ['航班', '飞常准', 'flight.search', '来源状态'];
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return ['高铁', '12306', 'train.search'];
  }
  if (isHotelQuery(query)) {
    return ['酒店 · 实时搜索', 'RollingGo'];
  }
  if (/瑞幸|luckin|ruixing/i.test(query) && /点一杯|点杯|点个瑞幸|点瑞幸|帮我点|我要点|下单|下一杯|买一杯|帮我买|购买一杯|购买瑞幸|来一杯|要一杯/.test(query)) {
    return ['瑞幸', 'luckin.order.preview', '选择瑞幸门店', '确认瑞幸订单', '确认下单'];
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
    if (isPersonaCoffeeQuery(query)) {
      return ['饮食搭子', '餐饮', '咖啡', '高德', '百度地图'];
    }
    return ['奶茶', '餐饮', '高德', '腾讯地图', '百度地图', '美团', '淘宝闪购'];
  }
  return [];
}

function swipeResultsUp() {
  hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '2200', '650', '950', '600']);
}

function swipeResultsDown() {
  hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '950', '650', '2200', '600']);
}

function requiredScrolledMarkersForQuery(query, expectedToolId) {
  if (expectedToolId === 'mail.search') {
    if (isQqMailQuery(query)) {
      return ['QQ Mail'];
    }
    return ['Gmail', 'QQ Mail', 'Outlook'];
  }
  if (expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query)) {
    return ['ECCV'];
  }
  if (expectedToolId === 'media.aggregate.search') {
    return ['聚合搜索', '视频', '讨论', 'YouTube', 'B 站', 'X', 'HN', 'Reddit'];
  }
  if (expectedToolId === 'movie.open') {
    return ['电影 Anything OS', '明星正在发生'];
  }
  if (expectedToolId === 'daily.brief.open') {
    return DAILY_BRIEF_VISIBLE_MARKERS;
  }
  return [];
}

async function collectScrolledLayoutEvidence(initialLayout, initialText, index, requiredMarkers, attemptLimit = 5) {
  const texts = [initialText];
  const layoutPaths = [join(outDir, `query-${index + 1}-final-layout.json`)];
  const textPaths = [join(outDir, `query-${index + 1}-final-layout-text.txt`)];
  const screenPaths = [];
  let currentLayout = initialLayout;
  for (let attempt = 0; attempt < attemptLimit; attempt += 1) {
    const combinedText = texts.join('\n');
    if (requiredMarkers.every((marker) => combinedText.includes(marker))) {
      break;
    }
    swipeResultsUp();
    await sleep(900);
    currentLayout = dumpLayout(`query-${index + 1}-scroll-${attempt + 1}-layout.json`);
    const scrolledText = collectLayoutText(currentLayout).join('\n');
    const scrolledTextPath = join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout-text.txt`);
    writeFileSync(scrolledTextPath, scrolledText + '\n');
    const scrolledScreenPath = captureScreen(`query-${index + 1}-scroll-${attempt + 1}-screen.png`);
    texts.push(scrolledText);
    layoutPaths.push(join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout.json`));
    textPaths.push(scrolledTextPath);
    screenPaths.push(scrolledScreenPath);
  }
  const uniqueText = [...new Set(texts.join('\n').split('\n').filter((line) => line.trim().length > 0))].join('\n');
  const combinedTextPath = join(outDir, `query-${index + 1}-scrolled-layout-text.txt`);
  writeFileSync(combinedTextPath, uniqueText + '\n');
  return {
    text: uniqueText,
    currentLayout,
    combinedTextPath,
    layoutPaths,
    textPaths,
    screenPaths,
    requiredMarkers,
    foundMarkers: requiredMarkers.filter((marker) => uniqueText.includes(marker))
  };
}

function expandMatchesForTarget(layout, targetMarker) {
  const expands = findTextMatches(layout, '展开')
    .filter((item) => item.bounds.y > 400 && item.bounds.y < 2450);
  if (targetMarker.length === 0) {
    return expands;
  }
  const targets = findTextMatches(layout, targetMarker);
  if (targets.length === 0) {
    return [];
  }
  return expands
    .filter((expand) => targets.some((target) =>
      Math.abs(expand.bounds.y - target.bounds.y) < 360 ||
      verticallyOverlaps(expand.bounds, target.bounds)))
    .sort((left, right) => {
      const leftDistance = Math.min(...targets.map((target) => Math.abs(left.bounds.y - target.bounds.y)));
      const rightDistance = Math.min(...targets.map((target) => Math.abs(right.bounds.y - target.bounds.y)));
      return leftDistance - rightDistance;
    });
}

function currentMailReadEvidence(logText, sourceToolId, actionContext) {
  const actionIds = ['mail.thread.read', 'gmail.thread.read'];
  const results = actionIds.map((actionId) => mailThreadReadEvidence(
    logText,
    exactActionOptions(actionId, sourceToolId, actionContext)
  ));
  return results.find((result) => result.complete) || results[0];
}

function visibleExpandedMailBody(layout, text) {
  return visibleMailBodyText(expandedMailBodyRegionText(layout)) &&
    !hasTechnicalGmailArgsCard(text);
}

async function verifyMailExpandedBody(layout, index, appPid, actionContext) {
  let currentLayout = layout;
  const sourceToolId = visibleSourceToolId(actionContext);
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const matches = expandMatchesForTarget(currentLayout, '');
    for (let candidate = 0; candidate < matches.length; candidate += 1) {
      const target = matches[candidate].bounds;
      clearHilog();
      const actionLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(target.x), String(target.y)]);
      }, {
        completionEvidence: (text) => currentMailReadEvidence(text, sourceToolId, actionContext),
        idleActionTimeoutMs: 2500,
        postCompletionWaitMs: 0
      });
      const logs = actionLogs.join('\n');
      const evidence = currentMailReadEvidence(logs, sourceToolId, actionContext);
      let expanded = dumpLayout(
        `query-${index + 1}-mail-body-${attempt + 1}-${candidate + 1}-layout.json`
      );
      let text = collectLayoutText(expanded).join('\n');
      for (let poll = 0; poll < 16 && evidence.complete &&
        !visibleExpandedMailBody(expanded, text) &&
        !/邮件正文加载失败|正文读取失败|PROVIDER_|AUTH_REQUIRED/.test(text); poll += 1) {
        await sleep(250);
        expanded = dumpLayout(
          `query-${index + 1}-mail-body-${attempt + 1}-${candidate + 1}-poll-${poll + 1}-layout.json`
        );
        text = collectLayoutText(expanded).join('\n');
      }
      let bodyVisible = visibleExpandedMailBody(expanded, text);
      if (shouldRecoverMailBodyViewport(evidence, bodyVisible)) {
        for (let recovery = 0; recovery < 4 && !bodyVisible; recovery += 1) {
          swipeResultsUp();
          await sleep(450);
          expanded = dumpLayout(
            `query-${index + 1}-mail-body-${attempt + 1}-${candidate + 1}-viewport-${recovery + 1}-layout.json`
          );
          text = collectLayoutText(expanded).join('\n');
          bodyVisible = visibleExpandedMailBody(expanded, text);
        }
      }
      const textPath = join(
        outDir,
        `query-${index + 1}-mail-body-${attempt + 1}-${candidate + 1}-layout-text.txt`
      );
      const logPath = join(
        outDir,
        `query-${index + 1}-mail-body-${attempt + 1}-${candidate + 1}.log`
      );
      writeFileSync(textPath, text + '\n');
      writeFileSync(logPath, logs + '\n');
      if (evidence.ok && evidence.bodyVisible && bodyVisible) {
        return {
          ok: true,
          capability: evidence.dataToolId,
          evidence,
          textPath,
          logPath,
          screenPath: captureScreen(`query-${index + 1}-mail-body-screen.png`)
        };
      }
      const collapse = findTextMatches(expanded, '收起')
        .sort((left, right) => Math.abs(left.bounds.y - target.y) - Math.abs(right.bounds.y - target.y))[0];
      if (collapse !== undefined) {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(collapse.bounds.x), String(collapse.bounds.y)]);
        await sleep(400);
      }
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-body-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'mail.thread.read', reason: 'mail expand button not found' };
}

async function verifySocialDraftAction(layout, index) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const currentText = collectLayoutText(currentLayout).join('\n');
    const currentEvidence = socialDraftUiEvidence(currentLayout);
    if (currentEvidence.ok) {
      const textPath = join(outDir, `query-${index + 1}-social-draft-layout-text.txt`);
      writeFileSync(textPath, currentText + '\n');
      return {
        ...currentEvidence,
        capability: 'social.reply.draft',
        textPath,
        screenPath: captureScreen(`query-${index + 1}-social-draft-screen.png`)
      };
    }
    const center = socialReplyButtonCenter(currentLayout);
    if (center !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      await sleep(1000);
      const resultLayout = dumpLayout(`query-${index + 1}-social-draft-layout.json`);
      const text = collectLayoutText(resultLayout).join('\n');
      const textPath = join(outDir, `query-${index + 1}-social-draft-layout-text.txt`);
      writeFileSync(textPath, text + '\n');
      const evidence = socialDraftUiEvidence(resultLayout);
      return {
        ...evidence,
        capability: 'social.reply.draft',
        textPath,
        screenPath: captureScreen(`query-${index + 1}-social-draft-screen.png`)
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-social-draft-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'social.reply.draft', reason: 'safe draft or reply composer not found' };
}

function exactActionOptions(actionId, sourceToolId, context) {
  return {
    expectedActionId: actionId,
    expectedSourceToolId: sourceToolId || 'invalid',
    currentSurfaceId: context?.surfaceId || 'invalid',
    expectedConversationId: context?.conversationId || 'invalid',
    expectedVirtual: false
  };
}

function visibleSourceToolId(lifecycle) {
  return Array.isArray(lifecycle?.finalUiToolIds) && lifecycle.finalUiToolIds.length === 1
    ? lifecycle.finalUiToolIds[0]
    : '';
}

async function verifyCalendarWriteAction(
  layout, index, appPid, _actionContext, actionId, label, expectedTime = '', onProviderSuccess = undefined
) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const center = calendarConfirmationButtonCenter(currentLayout, label);
    if (center !== null) {
      clearHilog();
      const actionLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      });
      const logs = actionLogs.join('\n');
      const actionEvidence = multiAgentActionEvidence(
        logs, { expectedActionId: actionId, expectedVirtual: false }
      );
      const providerEvidence = calendarProviderActionEvidence(logs, actionEvidence, { expectedTime });
      if (actionId === 'calendar.event.create' && providerEvidence.ok && typeof onProviderSuccess === 'function') {
        onProviderSuccess(providerEvidence.providerEventId);
      }
      const resultLayout = dumpLayout(`query-${index + 1}-${actionId.replaceAll('.', '-')}-layout.json`);
      const suffix = actionId.replaceAll('.', '-');
      const logPath = join(outDir, `query-${index + 1}-${suffix}.log`);
      const textPath = join(outDir, `query-${index + 1}-${suffix}-layout-text.txt`);
      writeFileSync(logPath, logs + '\n');
      writeFileSync(textPath, collectLayoutText(resultLayout).join('\n') + '\n');
      return {
        ok: actionEvidence.ok && providerEvidence.ok,
        capability: actionId,
        actionEvidence,
        providerEvidence,
        expectedTime,
        logPath,
        textPath,
        screenPath: captureScreen(`query-${index + 1}-${suffix}-screen.png`)
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-${actionId.replaceAll('.', '-')}-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: actionId, reason: `${label} button not found` };
}

async function verifyCalendarDeleteAction(layout, index, appPid, _actionContext) {
  let currentLayout = layout;
  let confirmationOpened = false;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const center = findExactTextCenter(currentLayout, '确认删除');
    if (center !== null) {
      clearHilog();
      const actionLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      });
      const resultLayout = dumpLayout(`query-${index + 1}-calendar-delete-layout.json`);
      const logs = actionLogs.join('\n');
      const actionEvidence = multiAgentActionEvidence(
        logs, { expectedActionId: 'calendar.event.delete', expectedVirtual: false }
      );
      const providerEvidence = calendarProviderActionEvidence(logs, actionEvidence);
      const logPath = join(outDir, `query-${index + 1}-calendar-delete.log`);
      const textPath = join(outDir, `query-${index + 1}-calendar-delete-layout-text.txt`);
      writeFileSync(logPath, logs + '\n');
      writeFileSync(textPath, collectLayoutText(resultLayout).join('\n') + '\n');
      return {
        ok: actionEvidence.ok && providerEvidence.ok,
        capability: 'calendar.event.delete.confirm',
        actionEvidence,
        providerEvidence,
        logPath,
        textPath,
        screenPath: captureScreen(`query-${index + 1}-calendar-delete-screen.png`)
      };
    }
    if (!confirmationOpened) {
      const deleteCenter = findExactTextCenter(currentLayout, '删除日程');
      if (deleteCenter !== null) {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(deleteCenter.x), String(deleteCenter.y)]);
        await sleep(600);
        currentLayout = dumpLayout(`query-${index + 1}-calendar-delete-confirmation.json`);
        confirmationOpened = true;
        swipeResultsUp();
        await sleep(800);
        currentLayout = dumpLayout(`query-${index + 1}-calendar-delete-confirmation-ready.json`);
        continue;
      }
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-calendar-delete-scroll-${attempt + 1}.json`);
  }
  return { ok: false, capability: 'calendar.event.delete.confirm', reason: '确认删除 button not found' };
}

async function locateHotelSystemAction(layout, label, index, actionName) {
  let currentLayout = layout;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    swipeResultsDown();
    await sleep(250);
  }
  currentLayout = dumpLayout(`query-${index + 1}-hotel-${actionName}-top-layout.json`);
  for (let attempt = 0; attempt <= 8; attempt += 1) {
    const center = findExactTextCenter(currentLayout, label);
    if (center !== null) {
      return {
        center,
        layout: currentLayout
      };
    }
    if (attempt < 8) {
      swipeResultsUp();
      await sleep(500);
      currentLayout = dumpLayout(
        `query-${index + 1}-hotel-${actionName}-scan-${attempt + 1}-layout.json`
      );
    }
  }
  return {
    center: null,
    layout: currentLayout
  };
}

async function exerciseHotelSystemAction(
  layout,
  index,
  actionId,
  label,
  actionName,
  expectedScheme,
  appPid,
  actionContext
) {
  const located = await locateHotelSystemAction(layout, label, index, actionName);
  const runtime = {
    buttonVisible: located.center !== null,
    systemSurfaceOpened: false,
    evidenceCaptured: false,
    returnedToApp: false
  };
  if (located.center === null) {
    return {
      runtime,
      reason: `exact ${actionId} action button not found`,
      restoredLayout: located.layout
    };
  }

  clearHilog();
  const capturedActionLogs = await captureAppLogsFor(appPid, async () => {
    hdc([
      'shell',
      'uitest',
      'uiInput',
      'click',
      String(located.center.x),
      String(located.center.y)
    ]);
    await sleep(1800);
  });
  const rawActionLogs = capturedActionLogs.join('\n');
  const actionLogs = sanitizeExternalUrlLogs(rawActionLogs);
  const multiAgentAction = multiAgentActionEvidence(
    actionLogs,
    exactActionOptions(actionId, 'hotel.search', actionContext)
  );
  const logPath = join(outDir, `query-${index + 1}-hotel-${actionName}.log`);
  writeFileSync(logPath, actionLogs + '\n');
  const schemeOpened = hasSafeHotelSystemIntentOpen(actionLogs, expectedScheme);
  const externalForeground = captureForegroundAbility(
    `query-${index + 1}-hotel-${actionName}-external-ability.txt`
  );
  const systemSurfaceRecognized = isExpectedHotelSystemBundle(actionId, externalForeground.bundleName);
  const screenPath = captureCurrentScreen(
    `query-${index + 1}-hotel-${actionName}-system-screen.png`
  );
  runtime.systemSurfaceOpened = Boolean(actionContext?.surfaceId) &&
    multiAgentAction.ok && schemeOpened && systemSurfaceRecognized;
  runtime.evidenceCaptured = screenPath.length > 0;
  runtime.multiAgentAction = multiAgentAction;

  // The only injected events on the external surface are bounded Back presses.
  let backPressCount = 0;
  let restoredForeground = {
    bundleName: externalForeground.bundleName,
    path: externalForeground.path
  };
  do {
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    backPressCount += 1;
    await sleep(1400);
    restoredForeground = captureForegroundAbility(
      `query-${index + 1}-hotel-${actionName}-restored-ability-${backPressCount}.txt`
    );
  } while (shouldRetryHotelReturnToApp(restoredForeground.bundleName, backPressCount));
  runtime.returnedToApp = restoredForeground.bundleName === 'com.jiuwen.appless';
  let restoredLayout = located.layout;
  let restoredLayoutPath = '';
  let restoredScreenPath = '';
  if (runtime.returnedToApp) {
    restoredLayoutPath = join(
      outDir,
      `query-${index + 1}-hotel-${actionName}-restored-layout.json`
    );
    restoredLayout = dumpLayout(
      `query-${index + 1}-hotel-${actionName}-restored-layout.json`
    );
    restoredScreenPath = captureScreen(
      `query-${index + 1}-hotel-${actionName}-restored-screen.png`
    );
  }
  return {
    runtime,
    actionEvidence: multiAgentAction,
    schemeOpened,
    systemSurfaceRecognized,
    foregroundBundle: externalForeground.bundleName,
    restoredBundle: restoredForeground.bundleName,
    backPressCount,
    interactionPolicy: 'system map screenshot then Back',
    logPath,
    abilityPath: externalForeground.path,
    screenPath,
    restoredAbilityPath: restoredForeground.path,
    restoredLayoutPath,
    restoredScreenPath,
    restoredLayout
  };
}

async function verifyHotelSystemActions(layout, index, actionEvidence, appPid, actionContext) {
  const validated = validateHotelSearchActionEvidence(actionEvidence);
  let currentLayout = layout;
  const runtime = {};
  let navigationEvidence = {
    skipped: true,
    reason: `hotel.navigate action is ${validated.navigation.status}`
  };
  if (validated.navigation.status === 'visible') {
    navigationEvidence = await exerciseHotelSystemAction(
      currentLayout,
      index,
      'hotel.navigate',
      '导航到酒店',
      'navigate',
      'petalmaps',
      appPid,
      actionContext
    );
    runtime.navigation = navigationEvidence.runtime;
    currentLayout = navigationEvidence.restoredLayout;
  }
  const navigationReport = { ...navigationEvidence };
  delete navigationReport.restoredLayout;
  return {
    ...evaluateHotelSystemActionEvidence(actionEvidence, runtime),
    navigationEvidence: navigationReport
  };
}

async function verifyHotelBookingAction(layout, index, appPid, actionEvidence, actionContext) {
  const validated = validateHotelDetailBookingEvidence(actionEvidence);
  const located = await locateHotelSystemAction(
    layout,
    '在 App 内继续预订',
    index,
    'booking'
  );
  const report = {
    capability: 'hotel.booking.open',
    actionEvidence: validated,
    buttonVisible: located.center !== null,
    foregroundBundle: '',
    headerVisible: false,
    domainVisible: false,
    loginBoundaryReached: false,
    returnedToRoom: false,
    roomSurfaceRestored: false,
    screenPath: '',
    layoutPath: '',
    restoredLayout: located.layout
  };
  if (!validated.ok) {
    report.reason = 'detail surface does not contain exactly one valid hotel.booking.open action';
    return { ...report, ok: false };
  }
  if (located.center === null) {
    report.reason = '在 App 内继续预订 button not found';
    return { ...report, ok: false };
  }

  clearHilog();
  const capturedBookingLogs = await captureAppLogsFor(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(located.center.x), String(located.center.y)]);
    await sleep(2200);
  });
  const bookingLogs = sanitizeExternalUrlLogs(capturedBookingLogs.join('\n'));
  const multiAgentAction = multiAgentActionEvidence(
    bookingLogs,
    exactActionOptions('hotel.booking.open', 'hotel.detail', actionContext)
  );
  const logPath = join(outDir, `query-${index + 1}-hotel-booking.log`);
  writeFileSync(logPath, bookingLogs + '\n');
  const foreground = captureForegroundAbility(`query-${index + 1}-hotel-booking-ability.txt`);
  report.foregroundBundle = foreground.bundleName;
  report.multiAgentAction = multiAgentAction;
  report.screenPath = captureCurrentScreen(`query-${index + 1}-hotel-booking-screen.png`);
  report.layoutPath = join(outDir, `query-${index + 1}-hotel-booking-layout.json`);
  let bookingLayout = dumpLayout(`query-${index + 1}-hotel-booking-layout.json`);
  const bookingText = collectLayoutText(bookingLayout).join('\n');
  report.headerVisible = bookingText.includes('RollingGo 酒店预订');
  report.domainVisible = /rollinggo\.cn/i.test(bookingText) || /rollinggo\.cn/i.test(bookingLogs);
  report.returnedToRoom = foreground.bundleName === 'com.jiuwen.appless';

  const loginCenter = findExactTextCenter(bookingLayout, '登录查看价格');
  if (loginCenter !== null) {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(loginCenter.x), String(loginCenter.y)]);
    await sleep(1400);
    bookingLayout = dumpLayout(`query-${index + 1}-hotel-booking-login-layout.json`);
    const loginText = collectLayoutText(bookingLayout).join('\n');
    report.loginBoundaryReached = /登录|手机号|验证码/.test(loginText);
    captureCurrentScreen(`query-${index + 1}-hotel-booking-login-screen.png`);
  } else {
    report.loginBoundaryReached = report.headerVisible && report.domainVisible;
  }

  const backToRoom = findExactTextCenter(bookingLayout, '返回房型');
  if (backToRoom !== null) {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(backToRoom.x), String(backToRoom.y)]);
    await sleep(1000);
    report.restoredLayout = dumpLayout(`query-${index + 1}-hotel-booking-restored-room-layout.json`);
    const roomText = collectLayoutText(report.restoredLayout).join('\n');
    report.returnedToRoom = report.returnedToRoom && !roomText.includes('RollingGo 酒店预订');
    report.roomSurfaceRestored = /房型与价格规则|价格与取消规则/.test(roomText);
  }
  report.logPath = logPath;
  report.ok = Boolean(actionContext?.surfaceId) && multiAgentAction.ok && report.returnedToRoom &&
    report.headerVisible && report.domainVisible &&
    report.loginBoundaryReached && report.roomSurfaceRestored;
  report.blocked = !report.ok && report.returnedToRoom && report.screenPath.length > 0;
  if (!report.ok && report.reason === undefined) {
    report.reason = 'booking Web surface or room restoration evidence was incomplete';
  }
  return report;
}

async function verifyHotelDetailAction(layout, index, appPid, queryLogs, queryContext) {
  let currentLayout = layout;
  let detailCenter = null;
  let detailLabel = '';
  const searchLayoutText = collectLayoutText(layout).join('\n');
  const pendingSearchCardAbsent =
    !/正在查询 RollingGo|正在等待 RollingGo/.test(searchLayoutText);
  const rawSearchActionEvidence = hotelActionEvidenceFromLogs(queryLogs.join('\n'));
  const searchActionEvidence = validateHotelSearchActionEvidence(rawSearchActionEvidence);
  const unverifiedSystemActions = evaluateHotelSystemActionEvidence(
    rawSearchActionEvidence,
    {}
  );
  const detailClickLocator = hotelDetailClickLocator(rawSearchActionEvidence);
  if (!detailClickLocator.ok) {
    return {
      ok: false,
      capability: 'hotel.detail',
      reason: 'current hotel surface has no exact valid hotel.detail click locator',
      actionEvidence: searchActionEvidence,
      systemActions: unverifiedSystemActions
    };
  }
  for (let attempt = 0; attempt < 8; attempt += 1) {
    for (const label of detailClickLocator.labels) {
      detailCenter = findHotelDetailTextCenter(currentLayout, label);
      if (detailCenter !== null) {
        detailLabel = label;
        break;
      }
    }
    if (detailCenter !== null) {
      break;
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-search-scroll-${attempt + 1}.json`);
  }
  if (detailCenter === null) {
    return {
      ok: false,
      capability: 'hotel.detail',
      reason: 'exact hotel.detail action click label not found in current layout',
      actionEvidence: searchActionEvidence,
      systemActions: unverifiedSystemActions
    };
  }

  clearHilog();
  const detailLogs = await captureWhile(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(detailCenter.x), String(detailCenter.y)]);
    await sleep(1200);
  });
  const rawDetailLogText = detailLogs.join('\n');
  const detailLogText = sanitizeExternalUrlLogs(rawDetailLogText);
  const detailLogPath = join(outDir, `query-${index + 1}-hotel-detail.log`);
  writeFileSync(detailLogPath, detailLogText + '\n');
  const detailEvidence = hotelMultiAgentDetailEvidence(detailLogText, {
    expectedConversationId: queryContext?.conversationId || 'invalid',
    currentSurfaceId: searchActionEvidence.surfaceId
  });
  const multiAgentDetailAction = multiAgentActionEvidence(
    detailLogText,
    exactActionOptions('hotel.detail', visibleSourceToolId(queryContext), queryContext)
  );
  const detailUiContext = detailEvidence.ok ? {
    conversationId: detailEvidence.conversationId,
    turnId: detailEvidence.turnId,
    taskId: detailEvidence.taskId,
    surfaceId: detailEvidence.surfaceId
  } : null;
  await sleep(700);
  currentLayout = dumpLayout(`query-${index + 1}-hotel-rates-layout.json`);

  let rateExpand = findTextCenter(currentLayout, '价格与取消规则');
  for (let attempt = 0; rateExpand === null && attempt < 8; attempt += 1) {
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-rates-scroll-${attempt + 1}.json`);
    rateExpand = findTextCenter(currentLayout, '价格与取消规则');
  }
  if (rateExpand === null) {
    return {
      ok: false,
      capability: 'hotel.detail',
      reason: '价格与取消规则 button not found',
      detailLogPath,
      systemActions: unverifiedSystemActions
    };
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(rateExpand.x), String(rateExpand.y)]);
  await sleep(700);
  swipeResultsUp();
  await sleep(700);
  currentLayout = dumpLayout(`query-${index + 1}-hotel-rate-expanded-layout.json`);
  const text = collectLayoutText(currentLayout).join('\n');
  const textPath = join(outDir, `query-${index + 1}-hotel-rate-expanded-layout-text.txt`);
  writeFileSync(textPath, text + '\n');
  const screenPath = captureScreen(`query-${index + 1}-hotel-rate-expanded-screen.png`);

  const detailActionEvidence = hotelActionEvidenceFromLogs(rawDetailLogText);
  const bookingAction = await verifyHotelBookingAction(
    currentLayout,
    index,
    appPid,
    detailActionEvidence,
    detailUiContext
  );
  currentLayout = bookingAction.restoredLayout;
  const bookingReport = { ...bookingAction };
  delete bookingReport.restoredLayout;

  let backCenter = findTextCenter(currentLayout, '返回酒店结果');
  for (let attempt = 0; backCenter === null && attempt < 8; attempt += 1) {
    swipeResultsDown();
    await sleep(700);
    currentLayout = dumpLayout(`query-${index + 1}-hotel-return-scroll-${attempt + 1}.json`);
    backCenter = findTextCenter(currentLayout, '返回酒店结果');
  }
  if (backCenter === null) {
    return {
      ok: false,
      capability: 'hotel.detail',
      reason: '返回酒店结果 button not found',
      detailLogPath,
      textPath,
      screenPath,
      systemActions: unverifiedSystemActions
    };
  }
  clearHilog();
  const restoreLogs = await captureWhile(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(backCenter.x), String(backCenter.y)]);
    await sleep(1200);
  });
  const restoreLogText = restoreLogs.join('\n');
  await sleep(700);
  const restoredLayout = dumpLayout(`query-${index + 1}-hotel-restored-layout.json`);
  const restoredText = collectLayoutText(restoredLayout).join('\n');
  const restoredTextPath = join(outDir, `query-${index + 1}-hotel-restored-layout-text.txt`);
  writeFileSync(restoredTextPath, restoredText + '\n');
  const restoredScreenPath = captureScreen(`query-${index + 1}-hotel-restored-screen.png`);
  const detailLifecycle = detailEvidence;
  const detailRequested = detailEvidence.ok;
  const detailOk = Boolean(queryContext?.surfaceId) && Boolean(detailUiContext?.surfaceId) &&
    detailEvidence.ok;
  const restoredOk = /酒店结果/.test(restoredText);
  const rawRestoredActionEvidence = hotelActionEvidenceFromLogs(restoreLogText);
  const restoredActionEvidence = validateHotelSearchActionEvidence(rawRestoredActionEvidence);
  const restoredUiContext = restoredHotelSearchSurface(queryContext, rawRestoredActionEvidence);
  const surfaceIdentity = validateHotelSurfaceIdentity(
    searchActionEvidence.surfaceId,
    typeof detailActionEvidence.surfaceId === 'string' ? detailActionEvidence.surfaceId : '',
    restoredActionEvidence.surfaceId
  );
  const systemActions = await verifyHotelSystemActions(
    restoredLayout,
    index,
    rawRestoredActionEvidence,
    appPid,
    restoredUiContext
  );
  return {
    ok: pendingSearchCardAbsent &&
      detailRequested && detailOk && hasVisibleHotelRateRuleEvidence(text) && restoredOk &&
      searchActionEvidence.ok && restoredActionEvidence.ok && surfaceIdentity.ok &&
      bookingAction.ok && systemActions.ok,
    capability: 'hotel.detail',
    detailLabel,
    actionEvidence: searchActionEvidence,
    navigation: searchActionEvidence.navigation,
    booking: bookingAction.actionEvidence.booking,
    bookingAction: bookingReport,
    systemActions,
    surfaceIdentity,
    searchSurfaceId: surfaceIdentity.searchSurfaceId,
    detailSurfaceId: surfaceIdentity.detailSurfaceId,
    restoredSurfaceId: surfaceIdentity.restoredSurfaceId,
    pendingSearchCardAbsent,
    detailRequested,
    detailOk,
    detailLifecycle,
    multiAgentDetailAction,
    restoredOk,
    detailLogPath,
    textPath,
    screenPath,
    restoredTextPath,
    restoredScreenPath
  };
}

async function findVisibleReplyDraftAction(layout, index) {
  let currentLayout = layout;
  let actionText = collectLayoutText(currentLayout).join('\n');
  let actionLayoutPath = '';
  let actionTextPath = '';
  let actionScreenPath = '';
  for (let attempt = 0; attempt < mailActionScrollLimit; attempt += 1) {
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout.json`);
    actionTextPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout-text.txt`);
    writeFileSync(actionLayoutPath, JSON.stringify(currentLayout, null, 2));
    writeFileSync(actionTextPath, actionText + '\n');
    actionScreenPath = captureScreen(`query-${index + 1}-mail-action-${attempt + 1}-screen.png`);
    if (actionText.includes('AI 回复草稿') || actionText.split('\n').includes('回复')) {
      return {
        layout: currentLayout,
        text: actionText,
        layoutPath: actionLayoutPath,
        textPath: actionTextPath,
        screenPath: actionScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionText = collectLayoutText(currentLayout).join('\n');
  }
  return {
    layout: currentLayout,
    text: actionText,
    layoutPath: actionLayoutPath,
    textPath: actionTextPath,
    screenPath: actionScreenPath
  };
}

function mailReplyEditorText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if (String(attrs.type || '').toLowerCase() !== 'textfield') {
      return;
    }
    const value = typeof attrs.text === 'string' ? attrs.text.trim() : '';
    if (value.length > 0) {
      values.push(value);
    }
  });
  return values.join('\n');
}

async function verifyMailReplyComposer(actionEvidence, index) {
  const replyCenter = findExactTextCenter(actionEvidence.layout, '回复');
  if (replyCenter === null) {
    return null;
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(replyCenter.x), String(replyCenter.y)]);
  await sleep(900);
  let composerLayout = dumpLayout(`query-${index + 1}-mail-reply-editor-layout.json`);
  let composerText = collectLayoutText(composerLayout).join('\n');
  const editorLayoutPath = join(outDir, `query-${index + 1}-mail-reply-editor-layout.json`);
  const editorTextPath = join(outDir, `query-${index + 1}-mail-reply-editor-layout-text.txt`);
  writeFileSync(editorTextPath, composerText + '\n');
  const editorScreenPath = captureScreen(`query-${index + 1}-mail-reply-editor-screen.png`);
  const aiCenter = findExactTextCenter(composerLayout, 'AI回复');
  if (aiCenter === null) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: false,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      reason: 'Reply editor opened without an AI reply button.',
      layoutPath: editorLayoutPath,
      layoutTextPath: editorTextPath,
      screenPath: editorScreenPath
    };
  }
  clearHilog();
  hdc(['shell', 'uitest', 'uiInput', 'click', String(aiCenter.x), String(aiCenter.y)]);
  let generated = '';
  for (let attempt = 0; attempt < 45; attempt += 1) {
    await sleep(2000);
    composerLayout = dumpLayout(`query-${index + 1}-mail-reply-ai-layout.json`);
    generated = mailReplyEditorText(composerLayout);
    if (generated.length > 0) {
      break;
    }
  }
  const aiLayoutPath = join(outDir, `query-${index + 1}-mail-reply-ai-layout.json`);
  const aiTextPath = join(outDir, `query-${index + 1}-mail-reply-ai-layout-text.txt`);
  composerText = collectLayoutText(composerLayout).join('\n');
  writeFileSync(aiTextPath, composerText + '\n');
  const aiScreenPath = captureScreen(`query-${index + 1}-mail-reply-ai-screen.png`);
  if (generated.length === 0) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: true,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      reason: 'AI reply button did not populate the editor.',
      layoutPath: aiLayoutPath,
      layoutTextPath: aiTextPath,
      screenPath: aiScreenPath
    };
  }
  let saveCenter = findExactTextCenter(composerLayout, '保存草稿');
  for (let attempt = 0; saveCenter === null && attempt < 5; attempt += 1) {
    hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '1350', '650', '650', '500']);
    await sleep(800);
    composerLayout = dumpLayout(`query-${index + 1}-mail-reply-save-${attempt + 1}-layout.json`);
    saveCenter = findExactTextCenter(composerLayout, '保存草稿');
  }
  if (saveCenter === null) {
    return {
      clicked: true,
      actionVisible: true,
      draftClicked: true,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: true,
      reason: 'AI reply was generated but the save draft button was not reachable.',
      layoutPath: aiLayoutPath,
      layoutTextPath: aiTextPath,
      screenPath: aiScreenPath
    };
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(saveCenter.x), String(saveCenter.y)]);
  let saved = false;
  let savedLayout = composerLayout;
  for (let attempt = 0; attempt < 45; attempt += 1) {
    await sleep(2000);
    savedLayout = dumpLayout(`query-${index + 1}-mail-reply-saved-layout.json`);
    if (!collectLayoutText(savedLayout).includes('编辑回复')) {
      saved = true;
      break;
    }
  }
  const savedLayoutPath = join(outDir, `query-${index + 1}-mail-reply-saved-layout.json`);
  const savedTextPath = join(outDir, `query-${index + 1}-mail-reply-saved-layout-text.txt`);
  const savedText = collectLayoutText(savedLayout).join('\n');
  writeFileSync(savedTextPath, savedText + '\n');
  const savedScreenPath = captureScreen(`query-${index + 1}-mail-reply-saved-screen.png`);
  const draftLogs = hdc(['shell', 'hilog', '-x']);
  const draftLogPath = join(outDir, `query-${index + 1}-mail-draft.log`);
  writeFileSync(draftLogPath, draftLogs);
  const draftToolRequested = draftLogs.includes('id=html_mail_reply_save');
  const draftToolOk = saved && draftToolRequested && !draftLogs.includes('[AIPhone][MailReplyOperationFailed]');
  return {
    clicked: true,
    actionVisible: true,
    draftClicked: true,
    draftToolRequested,
    draftToolOk,
    draftVisible: generated.length > 0,
    draftModelFailed: false,
    draftProviderFailed: !draftToolOk,
    layoutPath: actionEvidence.layoutPath,
    layoutTextPath: actionEvidence.textPath,
    screenPath: actionEvidence.screenPath,
    draftLogPath,
    draftLayoutPath: savedLayoutPath,
    draftTextPath: savedTextPath,
    draftScreenPath: savedScreenPath
  };
}

async function verifyMailExpandedActions(layout, index, appPid, targetMarker = '') {
  let currentLayout = layout;
  let lastExpandedText = '';
  let lastExpandedTextPath = '';
  let lastExpandedLayoutPath = '';
  let lastExpandedScreenPath = '';
  for (let page = 0; page < 6; page += 1) {
    const matches = expandMatchesForTarget(currentLayout, targetMarker);
    for (let matchIndex = 0; matchIndex < matches.length; matchIndex += 1) {
      const clickTarget = matches[matchIndex].bounds;
      hdc(['shell', 'uitest', 'uiInput', 'click', String(clickTarget.x), String(clickTarget.y)]);
      await sleep(900);
      currentLayout = dumpLayout(`query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedLayoutPath = join(outDir, `query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedText = collectLayoutText(currentLayout).join('\n');
      lastExpandedTextPath = join(outDir, `query-${index + 1}-mail-expanded-layout-text.txt`);
      writeFileSync(lastExpandedTextPath, lastExpandedText + '\n');
      lastExpandedScreenPath = captureScreen(`query-${index + 1}-mail-expanded-screen.png`);
      const actionEvidence = await findVisibleReplyDraftAction(currentLayout, index);
      lastExpandedText = actionEvidence.text;
      lastExpandedTextPath = actionEvidence.textPath;
      lastExpandedLayoutPath = actionEvidence.layoutPath;
      lastExpandedScreenPath = actionEvidence.screenPath;
      currentLayout = actionEvidence.layout;
      if (!actionEvidence.text.includes('AI 回复草稿') && !actionEvidence.text.split('\n').includes('回复')) {
        continue;
      }
      const composerEvidence = await verifyMailReplyComposer(actionEvidence, index);
      if (composerEvidence !== null) {
        return {
          ...composerEvidence,
          targetMarker
        };
      }
      const draftCenter = findTextCenter(actionEvidence.layout, 'AI 回复草稿');
      if (draftCenter === null) {
        return {
          clicked: true,
          actionVisible: true,
          draftClicked: false,
          draftToolRequested: false,
          draftToolOk: false,
          draftVisible: false,
          targetMarker,
          reason: 'AI 回复草稿 was visible but no clickable center was found.',
          layoutPath: lastExpandedLayoutPath,
          layoutTextPath: lastExpandedTextPath,
          screenPath: lastExpandedScreenPath
        };
      }
      clearHilog();
      await sleep(300);
      const draftLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(draftCenter.x), String(draftCenter.y)]);
      });
      const draftLogPath = join(outDir, `query-${index + 1}-mail-draft.log`);
      writeFileSync(draftLogPath, draftLogs.join('\n') + '\n');
      const draftLogText = draftLogs.join('\n');
      const draftLayout = dumpLayout(`query-${index + 1}-mail-draft-layout.json`);
      const draftLayoutPath = join(outDir, `query-${index + 1}-mail-draft-layout.json`);
      const draftText = collectLayoutText(draftLayout).join('\n');
      const draftTextPath = join(outDir, `query-${index + 1}-mail-draft-layout-text.txt`);
      writeFileSync(draftTextPath, draftText + '\n');
      const draftScreenPath = captureScreen(`query-${index + 1}-mail-draft-screen.png`);
      const draftToolRequested = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\[AIPhone\]\[LocalToolRequest\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\b(gmail|mail)\.draft\.create\b/.test(draftText);
      const draftToolOk = draftToolRequested &&
        /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\][^\n]*ok=true/.test(draftLogText) &&
        !/failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|CURLcode result 7|curl_code":7|os_errno":111/i.test(draftLogText);
      const draftVisible = /\b(gmail|mail)\.draft\.create\b|Draft saved|Saved in Gmail|Mail Draft Preview|草稿|跳转到Gmail/.test(draftText);
      const draftModelFailed = /\[AIPhone\]\[ModelException\]|\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\][^\n]*ok=false/.test(draftLogText);
      const draftProviderFailed = /Operation timeout|2300028|2300056|Failed to receive data from the peer|QQ IMAP timeout|Gmail 调用失败|QQ 邮箱调用失败/i.test(draftLogText);
      return {
        clicked: true,
        actionVisible: true,
        draftClicked: true,
        draftToolRequested,
        draftToolOk,
        draftVisible,
        draftModelFailed,
        draftProviderFailed,
        targetMarker,
        layoutPath: lastExpandedLayoutPath,
        layoutTextPath: lastExpandedTextPath,
        screenPath: lastExpandedScreenPath,
        draftLogPath,
        draftLayoutPath,
        draftTextPath,
        draftScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-search-scroll-${page + 1}-layout.json`);
  }
  if (lastExpandedText.length === 0) {
    return {
      clicked: false,
      actionVisible: false,
      draftClicked: false,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      targetMarker,
      reason: 'Could not locate a visible mail result expand button.'
    };
  }
  return {
    clicked: true,
    actionVisible: false,
    draftClicked: false,
    draftToolRequested: false,
    draftToolOk: false,
    draftVisible: false,
    targetMarker,
    layoutPath: lastExpandedLayoutPath,
    layoutTextPath: lastExpandedTextPath,
    screenPath: lastExpandedScreenPath
  };
}

function exactVisibleTextMatches(layout, marker) {
  return findTextMatches(layout, marker).filter((item) =>
    item.text.split('|').some((value) => value.trim() === marker) &&
    item.bounds.width > 0 && item.bounds.height > 0 && item.bounds.y >= 0 && item.bounds.y <= 2600);
}

function exactClickableTextMatches(layout, marker) {
  const matches = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null || !attrIsTrue(attrs.clickable) || attrIsFalse(attrs.enabled) ||
      bounds.width <= 0 || bounds.height <= 0 || bounds.y < 0 || bounds.y > 2600) return;
    const exact = ['text', 'content', 'description', 'hint', 'accessibilityText']
      .some((key) => typeof attrs[key] === 'string' && attrs[key].trim() === marker);
    if (exact) matches.push({ text: marker, bounds });
  });
  matches.sort((left, right) => left.bounds.top - right.bounds.top || left.bounds.left - right.bounds.left);
  return matches;
}

function sanitizedMemorySelectionLog(text) {
  return sanitizeExternalUrlLogs(text)
    .replace(/"candidateMemoryIds"\s*:\s*\[[^\]]*\]/g, '"candidateMemoryIds":["<redacted>"]')
    .replace(/"memoryId"\s*:\s*"[^"]*"/g, '"memoryId":"<redacted>"')
    .replace(/"fact"\s*:\s*"[^"]*"/g, '"fact":"<redacted>"')
    .replace(/\bmemoryId=\S+/g, 'memoryId=<redacted>')
    .replace(/\bfact=\S+/g, 'fact=<redacted>');
}

function memorySelectionShownEvidence(text, lifecycle) {
  const matches = String(text || '').split('\n')
    .filter((line) => /\[AIPhone\]\[MemorySelection\]/.test(line))
    .map((line) => ({ line, fields: lineEvidenceFields(line) }))
    .filter((item) => item.fields.operation === 'forget' && item.fields.status === 'shown');
  const unique = new Map();
  matches.forEach((item) => {
    const key = [item.fields.conversation, item.fields.turn, item.fields.task, item.fields.count].join('|');
    unique.set(key, item);
  });
  const selected = [...unique.values()].at(-1);
  const count = selected !== undefined && /^\d+$/.test(selected.fields.count || '') ?
    Number.parseInt(selected.fields.count, 10) : -1;
  return {
    ok: unique.size === 1 && count >= 1 && count <= 5 && lifecycle.complete === true,
    count
  };
}

async function finalMemoryCandidateCardEvidence(layout, index, maxSwipes = 6) {
  let currentLayout = layout;
  for (let reset = 0; reset < 3; reset += 1) {
    swipeResultsDown();
    await sleep(350);
  }
  const labels = new Set();
  let cardVisible = false;
  for (let attempt = 0; attempt <= maxSwipes; attempt += 1) {
    if (attempt > 0 || currentLayout === layout) {
      currentLayout = dumpLayout(`query-${index + 1}-memory-final-count-${attempt + 1}.json`);
    }
    const values = collectLayoutText(currentLayout);
    cardVisible = cardVisible || values.includes('选择要忘记的长期记忆');
    values.filter((value) => /^候选\s+\d+$/.test(value)).forEach((value) => labels.add(value));
    if (!cardVisible) break;
    swipeResultsUp();
    await sleep(450);
  }
  return { cardVisible, count: labels.size };
}

async function verifyMemoryForgetSelectionAction(layout, index, appPid, lifecycle, initialLogText) {
  let currentLayout = layout;
  const candidateLabels = collectLayoutText(currentLayout)
    .filter((value) => /^候选\s+\d+$/.test(value));
  const uniqueCandidateLabels = [...new Set(candidateLabels)];
  const allCandidateLabels = uniqueCandidateLabels;
  const selectionShown = memorySelectionShownEvidence(initialLogText, lifecycle);
  const recallEvidence = leaderMemoryRecallEvidence(initialLogText);
  const authoritativeCandidateCount = selectionShown.ok ? selectionShown.count :
    (recallEvidence.ok ? recallEvidence.count : -1);
  const cardVisible = collectLayoutText(layout).includes('选择要忘记的长期记忆');
  const initialValid = cardVisible && selectionShown.ok && uniqueCandidateLabels.length >= 1 &&
    memoryCandidateIndices.every((candidateIndex) => candidateIndex <= authoritativeCandidateCount);
  if (!initialValid) {
    return {
      ok: false,
      cardVisible,
      candidateCount: authoritativeCandidateCount,
      visibleCandidateCount: allCandidateLabels.length,
      clickedCandidateIndices: memoryCandidateIndices,
      clicked: false,
      toolOk: false,
      confirmationVisible: false,
      noActionAgent: false,
      reason: 'Memory management card, one-to-five candidates, or the selected row action was not visible.'
    };
  }

  for (let selectedIndex = 0; selectedIndex < memoryCandidateIndices.length; selectedIndex += 1) {
    const requestedLabel = `候选 ${memoryCandidateIndices[selectedIndex]}`;
    let selectedLabel = exactVisibleTextMatches(currentLayout, requestedLabel)[0];
    for (let attempt = 0; selectedLabel === undefined && attempt < 4; attempt += 1) {
      swipeResultsUp();
      await sleep(800);
      currentLayout = dumpLayout(
        `query-${index + 1}-memory-selection-${selectedIndex + 1}-scroll-${attempt + 1}.json`
      );
      selectedLabel = exactVisibleTextMatches(currentLayout, requestedLabel)[0];
    }
    const toggleButtons = exactClickableTextMatches(currentLayout, '选择');
    const toggleButton = selectedLabel === undefined ? undefined : toggleButtons
      .filter((item) => item.bounds.x > selectedLabel.bounds.x)
      .sort((left, right) =>
        Math.abs(left.bounds.y - selectedLabel.bounds.y) - Math.abs(right.bounds.y - selectedLabel.bounds.y))[0];
    if (toggleButton === undefined) {
      return {
        ok: false, cardVisible, candidateCount: authoritativeCandidateCount,
        visibleCandidateCount: allCandidateLabels.length,
        clickedCandidateIndices: memoryCandidateIndices.slice(0, selectedIndex), clicked: false,
        toolOk: false, confirmationVisible: false, noActionAgent: false,
        reason: `Could not toggle candidate index ${memoryCandidateIndices[selectedIndex]}.`
      };
    }
    hdc(['shell', 'uitest', 'uiInput', 'click', String(toggleButton.bounds.x), String(toggleButton.bounds.y)]);
    await sleep(800);
    currentLayout = dumpLayout(
      `query-${index + 1}-memory-selection-selected-${selectedIndex + 1}-layout.json`
    );
  }

  const expectedDeleteLabel = `删除已选（${memoryCandidateIndices.length}）`;
  let deleteButton = exactClickableTextMatches(currentLayout, expectedDeleteLabel)[0];
  for (let attempt = 0; deleteButton === undefined && attempt < 4; attempt += 1) {
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-memory-delete-scroll-${attempt + 1}.json`);
    deleteButton = exactClickableTextMatches(currentLayout, expectedDeleteLabel)[0];
  }
  if (deleteButton === undefined) {
    return {
      ok: false, cardVisible, candidateCount: authoritativeCandidateCount,
      visibleCandidateCount: allCandidateLabels.length,
      clickedCandidateIndices: memoryCandidateIndices, clicked: false, toolOk: false,
      confirmationVisible: false, noActionAgent: false,
      reason: `Selected state did not expose ${expectedDeleteLabel}.`
    };
  }

  clearHilog();
  const actionLogs = await captureWhile(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(deleteButton.bounds.x), String(deleteButton.bounds.y)]);
  }, {
    completionEvidence: (text) => {
      const evidence = leaderMemoryToolEvidence(text, 'memory.forget', lifecycle);
      return {
        complete: evidence.ok && evidence.succeeded === memoryCandidateIndices.length && evidence.failed === 0
      };
    },
    idleActionTimeoutMs: 5000,
    postCompletionWaitMs: 1200
  });
  const actionLogText = actionLogs.join('\n');
  writeFileSync(
    join(outDir, `query-${index + 1}-memory-selection-action.log`),
    sanitizedMemorySelectionLog(actionLogText) + '\n'
  );
  await sleep(500);
  const confirmationLayout = dumpLayout(`query-${index + 1}-memory-selection-confirmation-layout.json`);
  const confirmationText = collectLayoutText(confirmationLayout).join('\n');
  writeFileSync(
    join(outDir, `query-${index + 1}-memory-selection-confirmation-text.txt`),
    confirmationText + '\n'
  );
  const tool = leaderMemoryToolEvidence(actionLogText, 'memory.forget', lifecycle);
  const exactToolCount = tool.ok && tool.succeeded === memoryCandidateIndices.length && tool.failed === 0;
  const combinedLogs = `${initialLogText}\n${actionLogText}`;
  const noActionAgent = !/\[AIPhone\]\[(?:MultiAgentActionPlan|MultiAgentActionRun|PersonaMemoryUpdate)\]/.test(combinedLogs) &&
    !/ActionAgent/.test(combinedLogs);
  const finalCard = await finalMemoryCandidateCardEvidence(confirmationLayout, index);
  const remainingCandidateCount = finalCard.count;
  const expectedRemainingCount = authoritativeCandidateCount - memoryCandidateIndices.length;
  const confirmationVisible = expectedRemainingCount === 0 ?
    new RegExp(`已删除\\s*${memoryCandidateIndices.length}\\s*条长期记忆`).test(confirmationText) :
    finalCard.cardVisible && remainingCandidateCount === expectedRemainingCount;
  return {
    ok: initialValid && exactToolCount && confirmationVisible && noActionAgent,
    cardVisible,
    candidateCount: authoritativeCandidateCount,
    visibleCandidateCount: allCandidateLabels.length,
    clickedCandidateIndices: memoryCandidateIndices,
    clicked: true,
    toolOk: exactToolCount,
    confirmationVisible,
    noActionAgent,
    reason: ''
  };
}

async function runQuery(query, index, expectedTool, expectedCaseOverride = null, preserveAppSession = false) {
  const expectedCase = expectedCaseOverride || (useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query));
  const expectsDirectText = expectedTool === false;
  const expectedToolId = expectedCase.expectedToolId || '';
  const lifecycle = lifecycleOptions(expectedCase);
  const expectedToolIds = lifecycle.expectedToolIds;
  const minimumDataRounds = lifecycle.minimumDataRounds;
  const expectedDependencies = lifecycle.expectedDependencies;
  const expectedDataRounds = lifecycle.expectedDataRounds;
  const expectedParallelDataToolIds = lifecycle.expectedParallelDataToolIds;
  clearHilog();
  if (!preserveAppSession) {
    hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
    if (cleanData) {
      cleanBundleData();
    }
    hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.jiuwen.appless']);
  }
  await sleep(3000);
  moveAppWindowIntoScreenshot();
  const appPid = hdc(['shell', 'pidof', 'com.jiuwen.appless']).trim().split(/\s+/)[0] || '';
  const controls = await waitForControls('latest-layout.json', 10, false);
  const directTextBaselineName = `query-${index + 1}-direct-text-baseline-layout.json`;
  let directTextBaselineLayout = null;
  const logs = await captureWhile(appPid, async () => {
    let typed = false;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(controls.input.x), String(controls.input.y)]);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
      hdc(['shell', 'uitest', 'uiInput', 'inputText',
        String(controls.input.x), String(controls.input.y), query]);
      await sleep(1200);
      const inputText = collectInputText(dumpLayout(`query-${index + 1}-input-attempt-${attempt + 1}.json`));
      if (inputText.includes(query)) {
        typed = true;
        break;
      }
    }
    if (!typed) {
      throw new Error(`Could not type full query into AIPhone input: ${query}`);
    }
    const submitControls = await waitForControls(`query-${index + 1}-submit-layout.json`, 2);
    if (expectsDirectText) {
      directTextBaselineLayout = dumpLayout(directTextBaselineName);
      if (!collectInputText(directTextBaselineLayout).includes(query)) {
        throw new Error(`Direct-text baseline lost the typed query: ${query}`);
      }
    }
    hdc(['shell', 'uitest', 'uiInput', 'click', String(submitControls.generate.x), String(submitControls.generate.y)]);
  }, expectedToolId === 'daily.brief.open' ? {
    completionEvidence: (text) => dailyBriefDirectEvidence(text)
  } : {
    expectedToolIds,
    minimumDataRounds,
    expectedDependencies,
    expectedDataRounds,
    expectedParallelDataToolIds,
    postCompletionWaitMs: multiAgentPostCompletionWaitMs(expectedCase.id)
  });
  const safeLogText = expectedCase.verifyMemoryForgetSelection === true ?
    sanitizedMemorySelectionLog(logs.join('\n')) : sanitizeExternalUrlLogs(logs.join('\n'));
  const safeLogs = safeLogText.split('\n');
  const logPath = join(outDir, `query-${index + 1}.log`);
  writeFileSync(logPath, safeLogText + '\n');
  const expectedDiscoveredToolId = expectedCase.expectedDiscoveredToolId || '';
  const expectedDynamicQualifiedName = expectedCase.expectedDynamicQualifiedName || '';
  const expectedLeaderMemoryCapability = expectedCase.expectedLeaderMemoryCapability || '';
  const summary = analyze(
    query,
    safeLogs,
    expectedTool,
    expectedToolId,
    expectedDiscoveredToolId,
    expectedDynamicQualifiedName,
    expectedToolIds,
    minimumDataRounds,
    expectedDependencies,
    expectedDataRounds,
    expectedParallelDataToolIds,
    expectedLeaderMemoryCapability,
    expectedCase.verifyMemoryRecall === true
  );
  summary.caseId = expectedCase.id || '';
  summary.expectedLeaderMemoryCapability = expectedLeaderMemoryCapability;
  summary.hotelCapabilities = expectedCase.hotelCapabilities || [];
  summary.logPath = logPath;
  const layout = dumpLayout(`query-${index + 1}-final-layout.json`);
  const layoutTextValues = collectLayoutText(layout);
  const layoutText = layoutTextValues.join('\n');
  const layoutTextPath = join(outDir, `query-${index + 1}-final-layout-text.txt`);
  writeFileSync(layoutTextPath, layoutText + '\n');
  if (expectedCase.verifyMemoryForgetSelection === true) {
    const memorySelection = await verifyMemoryForgetSelectionAction(
      layout, index, appPid, summary.multiAgentLifecycle, safeLogText
    );
    summary.memoryForgetSelection = memorySelection;
    summary.layoutPath = join(outDir, `query-${index + 1}-final-layout.json`);
    summary.layoutTextPath = layoutTextPath;
    summary.layoutTextExposed = memorySelection.ok;
    summary.layoutBlockingHits = [];
    summary.layoutOk = memorySelection.ok;
    summary.screenPath = captureScreen(`query-${index + 1}-memory-forget-selection-final-screen.png`);
    summary.ok = summary.ok && memorySelection.ok;
    return summary;
  }
  const directTextEvidence = expectsDirectText && directTextBaselineLayout !== null ? directTextVisibleEvidence(
    safeLogText,
    directTextBaselineLayout,
    layout,
    query,
    {
      conversationId: summary.multiAgentLifecycle.conversationId,
      turnId: summary.multiAgentLifecycle.turnId,
      expectedToolIds,
      minimumDataRounds,
      expectedDependencies
    }
  ) : (expectsDirectText ?
    { ok: false, replyChars: 0, baselineMessageCount: 0, finalMessageCount: 0,
      failures: ['missing_direct_text_baseline'], skipped: false } :
    { ok: true, replyChars: 0, baselineMessageCount: 0, finalMessageCount: 0,
      failures: [], skipped: true });
  const memoryReplyPattern = expectedLeaderMemoryCapability === 'memory.remember' ?
    /已记住\s*\d+\s*条长期记忆/ :
    (expectedLeaderMemoryCapability === 'memory.update' ? /已更新长期记忆/ :
      (expectedLeaderMemoryCapability === 'memory.forget' ? /已忘记这条长期记忆/ : null));
  const visibleMemoryReply = memoryReplyPattern === null ? '' :
    layoutTextValues.find((value) => memoryReplyPattern.test(value)) || '';
  summary.directTextBaselineLayoutPath = expectsDirectText ?
    join(outDir, directTextBaselineName) : '';
  summary.directTextVisible = {
    ok: directTextEvidence.ok || visibleMemoryReply.length > 0,
    replyChars: visibleMemoryReply.length > 0 ? visibleMemoryReply.length : directTextEvidence.replyChars,
    baselineMessageCount: directTextEvidence.baselineMessageCount,
    finalMessageCount: directTextEvidence.finalMessageCount,
    failures: visibleMemoryReply.length > 0 ? [] : directTextEvidence.failures,
    skipped: directTextEvidence.skipped === true
  };
  const expectedMarkers = layoutExpectationsForQuery(query);
  if (shouldDismissKeyboardBeforeScrolledEvidence(expectedToolId)) {
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    await sleep(500);
  }
  const scrollEvidence = await collectScrolledLayoutEvidence(
    layout,
    layoutText,
    index,
    requiredScrolledMarkersForQuery(query, expectedToolId),
    scrolledEvidenceAttemptLimit(expectedToolId)
  );
  const evidenceText = scrollEvidence.text;
  const evidenceLayout = scrollEvidence.currentLayout;
  if (isPersonaCoffeeQuery(query) && /饮食搭子上线|饮食搭子/.test(evidenceText)) {
    summary.personaCoffeeProof = true;
    if (expectedTool === true &&
      summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.toolExecutionObserved &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId) {
      summary.ok = true;
    }
  }
  const expectedHits = expectedMarkers.filter((marker) => evidenceText.includes(marker));
  const expectedMisses = expectedMarkers.filter((marker) => !evidenceText.includes(marker));
  const dynamicAuthOutcome = dynamicAuthOutcomeAssessment({
    discovery: summary.dynamicDiscovery,
    lifecycle: summary.multiAgentLifecycle,
    expectedQualifiedName: expectedDynamicQualifiedName,
    layoutText: evidenceText
  });
  summary.dynamicAuthOutcome = dynamicAuthOutcome;
  summary.allowsCorrelatedDynamicAuth = dynamicAuthOutcome.allowsCorrelatedDynamicAuth;
  const calendarMarkersOk = !isCalendarQuery(query) || expectedMisses.length === 0;
  const composioCardMarkersOk = summary.allowsCorrelatedDynamicAuth ||
    !isComposioCardQuery(query) || expectedMisses.length === 0;
  const forbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyMarkers.filter((marker) => evidenceText.includes(marker));
  const isSocialHubCase = isSocialHubExpectedToolId(expectedToolId);
  const socialHubVisibleOutput = isSocialHubCase && hasVisibleSocialHubOutput(evidenceText, expectedToolId);
  const allowsSocialHubTruthfulState = socialHubVisibleOutput && hasTruthfulSocialHubState(evidenceText);
  const aggregateMediaVisibleOutput = expectedToolId === 'media.aggregate.search' && hasVisibleAggregateMediaOutput(evidenceText);
  const worldCupVisibleOutput = expectedToolId === 'worldcup.open' && evidenceText.includes('世界杯 Anything OS');
  const movieVisibleOutput = expectedToolId === 'movie.open' && evidenceText.includes('电影 Anything OS');
  const dailyBriefEvidence = expectedToolId === 'daily.brief.open' ?
    dailyBriefDirectEvidence(safeLogText, evidenceText) : null;
  const dailyBriefDateBlockingHits = expectedToolId === 'daily.brief.open' ?
    finalVisibleDateBlockingHits(evidenceText, expectedToolId, expectedDeviceLocalDate) : [];
  const dailyBriefVisibleOutput = dailyBriefEvidence?.ok === true && dailyBriefDateBlockingHits.length === 0;
  summary.dailyBriefDirectEvidence = dailyBriefEvidence;
  summary.dailyBriefDateBlockingHits = dailyBriefDateBlockingHits;
  const allowsExternalGmailWeb = isGmailWebQuery(query) && summary.gmailWebOpened === true;
  const allowsAggregateMailProviderFailure = expectedToolId === 'mail.search' &&
    !isQqMailQuery(query) &&
    /Gmail/.test(evidenceText) &&
    /QQ Mail/.test(evidenceText) &&
    /Outlook/.test(evidenceText);
  const allowsPartialTravelSourceFailure = expectedToolId === 'travel.search' &&
    summary.toolOk === true &&
    (evidenceText.includes('来源状态') || evidenceText.includes('飞常准')) &&
    (evidenceText.includes('耗时') || /\bG\d+\b/.test(evidenceText) || evidenceText.includes('高铁 · 12306'));
  const layoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
    if (allowsPartialTravelSourceFailure && marker === '查询失败') {
      return false;
    }
    if (allowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
      return false;
    }
    if (aggregateMediaVisibleOutput && aggregateMediaTruthfulBlockingMarkers.includes(marker)) {
      return false;
    }
    if (dailyBriefVisibleOutput && dailyBriefTruthfulStateMarkers.includes(marker)) {
      return false;
    }
    if (allowsAggregateMailProviderFailure && (/^(Gmail|QQ)/.test(marker) || marker === 'Operation timeout' || marker === '2300028')) {
      return false;
    }
    return evidenceText.includes(marker);
  });
  if (expectedToolId === 'gmail.mail.search' && hasTechnicalGmailArgsCard(evidenceText)) {
    layoutBlockingHits.push('gmail-technical-args-card');
  }
  layoutBlockingHits.push(...dailyBriefDateBlockingHits);
  if (expectedToolId === 'gmail.draft.create') {
    for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
      if (blockingPattern.pattern.test(evidenceText)) {
        layoutBlockingHits.push(blockingPattern.name);
      }
    }
  }
  const providerLayoutFailed = retryableProviderLayoutMarkers.some((marker) => evidenceText.includes(marker));
  summary.providerFailed = summary.providerFailed || (providerLayoutFailed && !allowsSocialHubTruthfulState &&
    !aggregateMediaVisibleOutput && !dailyBriefVisibleOutput && !allowsAggregateMailProviderFailure);
  summary.layoutPath = join(outDir, `query-${index + 1}-final-layout.json`);
  summary.layoutTextPath = layoutTextPath;
  summary.layoutScrolledTextPath = scrollEvidence.combinedTextPath;
  summary.layoutScrolledRequiredMarkers = scrollEvidence.requiredMarkers;
  summary.layoutScrolledFoundMarkers = scrollEvidence.foundMarkers;
  summary.layoutScrollTextPaths = scrollEvidence.textPaths;
  summary.layoutScrollScreenPaths = scrollEvidence.screenPaths;
  const evidenceToolName = (expectedToolId.length > 0 ? expectedToolId : 'no-tool').replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '');
  summary.screenPath = captureScreen(`query-${index + 1}-${evidenceToolName}-final-screen.png`);
  summary.layoutExpectedHits = expectedHits;
  summary.layoutExpectedMisses = expectedMisses;
  summary.socialHubVisibleOutput = socialHubVisibleOutput;
  summary.layoutForbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyHits;
  summary.layoutBlockingHits = layoutBlockingHits;
  summary.gmailEccvKeywordVisible = !isGmailEccvQuery(query) || /eccv/i.test(evidenceText);
  const aggregateMediaMarkersOk = expectedToolId !== 'media.aggregate.search' || expectedMisses.length === 0;
  summary.layoutTextExposed = expectsDirectText ?
    summary.directTextVisible.ok :
    (summary.allowsCorrelatedDynamicAuth ||
      (isSocialHubCase ?
        socialHubVisibleOutput :
        (worldCupVisibleOutput || movieVisibleOutput || dailyBriefVisibleOutput ||
          expectedMarkers.length === 0 || expectedHits.length > 0) &&
        calendarMarkersOk &&
        composioCardMarkersOk &&
        aggregateMediaMarkersOk &&
        summary.gmailEccvKeywordVisible));
  summary.memoryPreferenceApplied = expectedCase.expectedMemoryPreference === undefined ?
    true : memoryPreferenceVisible(evidenceText, expectedCase.expectedMemoryPreference);
  summary.memoryPreferenceAbsent = expectedCase.expectMemoryPreferenceAbsent === undefined ?
    true : !memoryPreferenceVisible(evidenceText, expectedCase.expectMemoryPreferenceAbsent);
  summary.layoutTextExposed = summary.layoutTextExposed && summary.memoryPreferenceApplied &&
    summary.memoryPreferenceAbsent;
  summary.mailAggregateVisible = expectedToolId !== 'mail.search' ||
    (isMailAggregationQuery(query) ? (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText) && /Outlook/.test(evidenceText)) :
      (isQqMailQuery(query) ? /QQ Mail/.test(evidenceText) : (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText) && /Outlook/.test(evidenceText))));
  const expectsMailDraftAction = expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query);
  summary.mailExpandedActions = expectsMailDraftAction
    ? await verifyMailExpandedActions(evidenceLayout, index, appPid, isGmailEccvQuery(query) ? 'ECCV' : '')
    : {
      clicked: false,
      actionVisible: true,
      draftClicked: false,
      draftToolRequested: true,
      draftToolOk: true,
      draftVisible: true
    };
  summary.mailExpandedBody = expectedCase.verifyMailBody === true
    ? await verifyMailExpandedBody(evidenceLayout, index, appPid, summary.multiAgentLifecycle)
    : { ok: true, skipped: true };
  summary.socialDraftAction = expectedCase.verifySocialDraft === true
    ? await verifySocialDraftAction(evidenceLayout, index)
    : { ok: true, skipped: true };
  summary.calendarCreateAction = expectedCase.verifyCalendarCreate === true
    ? await verifyCalendarWriteAction(
      evidenceLayout, index, appPid, summary.multiAgentLifecycle,
      'calendar.event.create', '确认创建', '', () => { c19CleanupRequired = true; }
    )
    : { ok: true, skipped: true };
  summary.calendarUpdateAction = expectedCase.verifyCalendarUpdate === true
    ? await verifyCalendarWriteAction(
      evidenceLayout, index, appPid, summary.multiAgentLifecycle,
      'calendar.event.update', '确认更新', '16:00'
    )
    : { ok: true, skipped: true };
  summary.calendarDeleteAction = expectedCase.verifyCalendarDelete === true
    ? await verifyCalendarDeleteAction(evidenceLayout, index, appPid, summary.multiAgentLifecycle)
    : { ok: true, skipped: true };
  summary.hotelDetailAction = expectedCase.verifyHotelDetail === true
    ? await verifyHotelDetailAction(evidenceLayout, index, appPid, safeLogs, summary.multiAgentLifecycle)
    : { ok: true, skipped: true };
  summary.providerFailed = summary.providerFailed || summary.hotelDetailAction.bookingAction?.blocked === true;
  const combinedHotelSearchEvidence = expectedCase.verifyHotelDetail === true
    ? hotelMultiAgentSearchEvidence(safeLogText)
    : null;
  summary.hotelSearchLifecycle = combinedHotelSearchEvidence?.lifecycle || summary.multiAgentLifecycle;
  summary.hotelProviderEvidence = combinedHotelSearchEvidence?.provider ||
    { requested: false, ok: false, surfaceId: '', providerResponse: false, blocks: 0 };
  summary.expectedAbsentText = expectedCase.expectAbsentText || '';
  summary.absenceEvidence = summary.expectedAbsentText.length === 0 ? { ok: true, skipped: true } :
    calendarProviderAbsenceEvidence(safeLogText, summary.multiAgentLifecycle, {
      title: summary.expectedAbsentText,
      date: qaDateIso
    });
  summary.absenceVerified = summary.absenceEvidence.ok;
  if (expectedLeaderMemoryCapability.length > 0) {
    summary.mailAggregateVisible = true;
    summary.layoutTextExposed = summary.directTextVisible.ok && summary.leaderMemoryTool.ok;
    summary.layoutOk = layoutBlockingHits.length === 0 &&
      forbiddenSocialHubLegacyHits.length === 0 &&
      summary.layoutTextExposed;
    summary.ok = summary.ok && summary.layoutOk &&
      summary.mailExpandedBody.ok &&
      summary.socialDraftAction.ok &&
      summary.calendarCreateAction.ok &&
      summary.calendarUpdateAction.ok &&
      summary.calendarDeleteAction.ok &&
      summary.hotelDetailAction.ok &&
      summary.absenceVerified;
    return summary;
  }
  summary.modelFailed = summary.modelFailed || summary.mailExpandedActions.draftModelFailed === true;
  summary.providerFailed = summary.providerFailed || summary.mailExpandedActions.draftProviderFailed === true;
  if (expectsMailDraftAction) {
    summary.layoutTextExposed = summary.layoutTextExposed &&
      summary.mailAggregateVisible &&
      summary.mailExpandedActions.actionVisible &&
      summary.mailExpandedActions.draftClicked &&
      summary.mailExpandedActions.draftToolRequested &&
      summary.mailExpandedActions.draftToolOk &&
      summary.mailExpandedActions.draftVisible;
  } else {
    summary.layoutTextExposed = summary.layoutTextExposed && summary.mailAggregateVisible;
  }
  const allowsHtmlDocumentOnly = !expectsDirectText && !isSocialHubCase && !expectsMailDraftAction && expectedToolId !== 'mail.search' &&
    expectedToolId !== 'media.aggregate.search' && summary.htmlHomeDocument.ok;
  summary.layoutOk = layoutBlockingHits.length === 0 &&
    forbiddenSocialHubLegacyHits.length === 0 &&
    (isSocialHubCase ? socialHubVisibleOutput : (allowsExternalGmailWeb || summary.layoutTextExposed || allowsHtmlDocumentOnly));
  const layoutEvidenceRecovered = expectedTool === true &&
    !summary.basePassedWithoutTransport &&
    summary.htmlHomeSurfaceLoad.ok &&
    !summary.htmlLoadError &&
    !summary.syntheticFallback &&
    summary.layoutOk;
  summary.layoutEvidenceRecovered = layoutEvidenceRecovered;
  if (expectedCase.verifyHotelDetail === true) {
    summary.ok = combinedHotelSearchEvidence?.ok === true &&
      summary.htmlHomeSurfaceLoad.ok &&
      !summary.htmlLoadError &&
      !summary.syntheticFallback &&
      !summary.providerFailed &&
      expectedMisses.length === 0 &&
      summary.layoutOk &&
      summary.hotelDetailAction.ok;
  } else if (isSocialHubCase) {
    const socialHubRecovered = socialHubVisibleOutput &&
      summary.htmlHomeSurfaceLoad.ok &&
      !summary.htmlLoadError &&
      !summary.syntheticFallback &&
      summary.layoutOk;
    if (socialHubRecovered) {
      summary.basePassedWithoutTransport = true;
    }
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.toolExecutionObserved &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      (summary.transportPassed === true || allowsSocialHubTruthfulState) &&
      summary.layoutOk;
  } else if (expectedToolId === 'worldcup.open') {
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.worldCupOpened === true &&
      worldCupVisibleOutput &&
      summary.layoutOk;
  } else if (expectedToolId === 'movie.open') {
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.movieOpened === true &&
      movieVisibleOutput &&
      summary.layoutOk;
  } else if (expectedToolId === 'daily.brief.open') {
    summary.ok = dailyBriefVisibleOutput &&
      summary.basePassedWithoutTransport === true &&
      summary.dailyBriefRequestObserved === true &&
      summary.dailyBriefExecutionObserved === true &&
      summary.layoutOk;
  } else if (layoutEvidenceRecovered) {
    summary.basePassedWithoutTransport = true;
    summary.ok = summary.modelPassed === true &&
      summary.transportPassed === true &&
      summary.toolRequested &&
      summary.toolExecutionObserved &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      summary.personaCoffeeProof === true &&
      summary.layoutOk;
  } else {
    summary.ok = summary.ok && summary.layoutOk;
  }
  summary.ok = summary.ok &&
    summary.mailExpandedBody.ok &&
    summary.socialDraftAction.ok &&
    summary.calendarCreateAction.ok &&
    summary.calendarUpdateAction.ok &&
    summary.calendarDeleteAction.ok &&
    summary.hotelDetailAction.ok &&
    summary.absenceVerified;
  return summary;
}

async function runDeepSearchSmoke(testCase, index) {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.jiuwen.appless']);
  await sleep(3000);
  moveAppWindowIntoScreenshot();
  const appPid = hdc(['shell', 'pidof', 'com.jiuwen.appless']).trim().split(/\s+/)[0] || '';
  const controls = await waitForControls(`query-${index + 1}-deepsearch-start-layout.json`, 10, false);
  const logs = await captureAppLogsFor(appPid, async () => {
    let typed = false;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
      hdc(['shell', 'uitest', 'uiInput', 'inputText',
        String(controls.input.x), String(controls.input.y), testCase.query]);
      await sleep(1200);
      const inputText = collectInputText(dumpLayout(
        `query-${index + 1}-deepsearch-input-attempt-${attempt + 1}.json`
      ));
      if (inputText.includes(testCase.query)) {
        typed = true;
        break;
      }
    }
    if (!typed) {
      throw new Error('Could not type the DeepSearch query.');
    }
    const submitControls = await waitForControls(`query-${index + 1}-deepsearch-submit-layout.json`, 2);
    hdc(['shell', 'uitest', 'uiInput', 'click',
      String(submitControls.generate.x), String(submitControls.generate.y)]);
  }, Number.parseInt(process.env.AIPHONE_DEEPSEARCH_TIMEOUT_MS || '75000', 10));
  const safeLogs = sanitizeExternalUrlLogs(logs.join('\n'));
  const logPath = join(outDir, `query-${index + 1}-deepsearch.log`);
  writeFileSync(logPath, safeLogs + '\n');
  const layoutPath = join(outDir, `query-${index + 1}-deepsearch-final-layout.json`);
  const layout = dumpLayout(`query-${index + 1}-deepsearch-final-layout.json`);
  const layoutText = collectLayoutText(layout).join('\n');
  const panelOpened = safeLogs.includes('[AIPhone][DeepSearchPanelOpened]');
  const autoRouted = safeLogs.includes('[AIPhone][DeepSearchAutoRouted]');
  const started = safeLogs.includes('[AIPhone][DeepSearchStart]');
  const providerRequested = /\[AIPhone\]\[FirecrawlMcp\][^\n]*toolId=web\.research\.search/.test(safeLogs);
  const done = /\[AIPhone\]\[DeepSearchDone\] sources=[1-9]\d*/.test(safeLogs);
  const failed = safeLogs.includes('[AIPhone][DeepSearchFailed]');
  const panelVisible = /DeepSearch|深度搜索|联网检索|研究进度|来源/.test(layoutText);
  const routeOk = panelOpened && autoRouted && started;
  const routeModelBlocked = safeLogs.includes('[AIPhone][DeepSearchRouteDecisionFailed]');
  const providerBlocked = routeOk && failed && panelVisible && (providerRequested ||
    /Firecrawl API key is required|needs_auth|Operation timeout|Failed to resolve|network/i.test(safeLogs));
  const status = routeOk && providerRequested && done && panelVisible ? 'PASS' :
    (routeModelBlocked || providerBlocked ? 'BLOCKED' : 'FAIL');
  return {
    caseId: testCase.id,
    query: testCase.query,
    expectedTool: true,
    expectedToolId: 'web.research.search',
    expectedToolIds: ['web.research.search'],
    status,
    ok: status === 'PASS',
    routeOk,
    providerRequested,
    done,
    failed,
    panelVisible,
    routeModelBlocked,
    providerBlocked,
    logPath,
    layoutPath,
    screenPath: captureScreen(`query-${index + 1}-deepsearch-final-screen.png`),
    reason: routeModelBlocked ? 'The route model provider failed before DeepSearch could start.' :
      (providerBlocked ? 'DeepSearch external provider did not return usable sources.' :
        (status === 'FAIL' ? 'DeepSearch routing or panel evidence is incomplete.' : ''))
  };
}

async function waitForComposioAuthEvidence() {
  const requiredMarkers = ['应用授权', '当前用户'];
  const authActionLabels = ['授权', '重新授权'];
  const authStatusLabels = [
    '待授权',
    '已连接',
    '异常',
    '已停用'
  ];
  const toolkitMarkers = [
    'GitHub',
    'Notion',
    'Google Drive',
    'Google Docs',
    'Slack',
    'OAuth',
    'Composio ·'
  ];
  const appNames = [
    'Gmail',
    'GitHub',
    'Google Calendar',
    'Google Drive',
    'Google Docs',
    'Slack',
    'Notion',
    'Linear',
    'Asana',
    'Trello',
    'Outlook',
    'Discord',
    'LinkedIn',
    'WhatsApp',
    'Instagram',
    'YouTube',
    'X',
    'Spotify',
    'TikTok',
    'Ticketmaster',
    'HubSpot',
    'Salesforce',
    'Reddit'
  ];
  let last = null;
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const layout = dumpLayout(`composio-auth-page-${attempt + 1}.json`);
    const layoutTextValues = collectLayoutText(layout);
    const text = layoutTextValues.join('\n');
    const textPath = join(outDir, `composio-auth-page-${attempt + 1}-text.txt`);
    writeFileSync(textPath, text + '\n');
    last = {
      layout,
      text,
      layoutPath: join(outDir, `composio-auth-page-${attempt + 1}.json`),
      textPath,
      markerHits: requiredMarkers.filter((marker) => text.includes(marker)),
      authActionHits: authActionLabels.filter((marker) => layoutTextValues.includes(marker)),
      authStatusHits: authStatusLabels.filter((marker) => layoutTextValues.includes(marker)),
      toolkitHits: toolkitMarkers.filter((marker) => text.includes(marker)),
      appNameHits: appNames.filter((marker) => layoutTextValues.includes(marker)),
      authConfigNameLeaks: layoutTextValues.filter((value) => /^auth_config_/i.test(value))
    };
    if (last.markerHits.length === requiredMarkers.length &&
      last.authActionHits.length > 0 &&
      last.authStatusHits.length > 0 &&
      last.appNameHits.length > 0 &&
      last.authConfigNameLeaks.length === 0) {
      return last;
    }
    await sleep(1000);
  }
  return last;
}

async function runComposioAuthSmoke() {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
  if (cleanData) {
    cleanBundleData();
  }
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.jiuwen.appless']);
  await sleep(3000);
  moveAppWindowIntoScreenshot();

  const homeLayout = dumpLayout('composio-auth-home-layout.json');
  writeFileSync(join(outDir, 'composio-auth-home-layout-text.txt'), collectLayoutText(homeLayout).join('\n') + '\n');
  const settings = findHeaderSettingsCenter(homeLayout);
  if (settings === null) {
    throw new Error('Could not locate the home header settings button for Composio auth smoke.');
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(settings.x), String(settings.y)]);
  await sleep(1200);
  for (let attempt = 0; attempt < 3; attempt += 1) {
    swipeResultsDown();
    await sleep(300);
  }

  const configLayout = dumpLayout('composio-auth-config-collapsed.json');
  const configText = collectLayoutText(configLayout).join('\n');
  writeFileSync(join(outDir, 'composio-auth-config-collapsed-text.txt'), configText + '\n');
  if (!configText.includes('管理授权')) {
    const expandAuth = findTextCenter(configLayout, '展开');
    if (expandAuth !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(expandAuth.x), String(expandAuth.y)]);
      await sleep(800);
    }
  }

  let authButton = findTextCenter(configLayout, '管理授权');
  if (authButton === null) {
    authButton = await findTextCenterWithScroll('管理授权', 'composio-auth-config-layout');
  }
  if (authButton === null) {
    throw new Error('Could not locate the Config page 管理授权 button.');
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(authButton.x), String(authButton.y)]);

  const evidence = await waitForComposioAuthEvidence();
  if (evidence === null) {
    throw new Error('Could not capture Composio auth page layout evidence.');
  }
  const externalAuthAppHits = [];
  const externalApps = [
    {
      name: 'QQ 邮箱',
      url: 'https://wx.mail.qq.com/list/readtemplate?name=app_intro.html#/agreement/authorizationCode'
    },
    {
      name: '瑞幸咖啡',
      url: 'https://open01.luckincoffeecdn.com/'
    },
    {
      name: '滴滴出行',
      url: 'https://mcp.didichuxing.com'
    }
  ];
  const externalAuthJumps = await collectExternalAuthJumps(externalApps, async (app, index) => {
    const actionCenter = await findExternalAuthActionWithScroll(app.name, `external-auth-${index + 1}`, 10);
    if (actionCenter !== null) {
      externalAuthAppHits.push(app.name);
      clearHilog();
      hdc(['shell', 'uitest', 'uiInput', 'click', String(actionCenter.x), String(actionCenter.y)]);
      await sleep(1500);
      const logs = hdc(['shell', 'hilog', '-d']);
      const windowDump = hdc(['shell', 'hidumper', '-s', 'WindowManagerService', '-a', '-a']);
      const focusMatch = /Focus window:\s*(\d+)/.exec(windowDump);
      const focusWindowId = focusMatch === null ? '' : focusMatch[1];
      const focusWindowLine = focusWindowId.length === 0 ? '' :
        (windowDump.split('\n').find((line) => line.includes(` ${focusWindowId} `)) || '');
      const intentLogSeen = logs.includes(`[AIPhone][A2uiHomeOpenUrl] ok=true url=${app.url}`);
      const browserFocused = /browser|quark/i.test(focusWindowLine);
      const opened = intentLogSeen || browserFocused;
      const logPath = join(outDir, `external-auth-${index + 1}-open.log`);
      writeFileSync(logPath,
        logs.split('\n').filter((line) => line.includes('[AIPhone][A2uiHomeOpenUrl]')).join('\n') +
        `\nfocusWindow=${focusWindowLine}\n`);
      const jump = {
        app: app.name,
        url: app.url,
        opened,
        intentLogSeen,
        browserFocused,
        logPath
      };
      let backPressCount = 0;
      let restoredForeground = { bundleName: '', path: '' };
      do {
        hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
        backPressCount += 1;
        await sleep(1400);
        restoredForeground = captureForegroundAbility(
          `external-auth-${index + 1}-return-ability-${backPressCount}.txt`
        );
      } while (shouldRetryHotelReturnToApp(restoredForeground.bundleName, backPressCount));
      return Object.assign(jump, {
        returned: restoredForeground.bundleName === 'com.jiuwen.appless',
        backPressCount,
        returnAbilityPath: restoredForeground.path
      });
    }
    return {
      app: app.name,
      url: app.url,
      opened: false,
      reason: 'authorization action not found'
    };
  });
  const screenPath = captureScreen('composio-auth-page-screen.png');
  const assessment = composioAuthEvidence({
    textValues: collectLayoutText(evidence.layout),
    externalAuthJumps
  });
  const summary = {
    mode: 'composio-auth',
    ok: assessment.status === 'PASS',
    uiOk: assessment.uiOk,
    providerOk: assessment.providerOk,
    status: assessment.status,
    requiredMarkers: ['应用授权', '当前用户'],
    markerHits: evidence.markerHits,
    authActionHits: evidence.authActionHits,
    authStatusHits: evidence.authStatusHits,
    toolkitHits: evidence.toolkitHits,
    appNameHits: evidence.appNameHits,
    externalAuthAppHits,
    externalAuthJumps,
    authConfigNameLeaks: evidence.authConfigNameLeaks,
    layoutPath: evidence.layoutPath,
    textPath: evidence.textPath,
    screenPath
  };
  writeFileSync(join(outDir, 'composio-auth-summary.json'), JSON.stringify(summary, null, 2));
  return summary;
}

function bimUnavailableReason(logText, layoutText = '') {
  const evidence = `${logText}\n${layoutText}`;
  const match = evidence.match(/\[AIPhone\]\[(?:ModelResult|A2uiHomeModelResult)\] ok=false[^\n]*|\[AIPhone\]\[A2uiHomeSubmitBlocked\][^\n]*|请先填写 Base URL|模型连接异常|模型服务不可用|需要供应商配置|需要配置：|授权(?:失败|已过期|不可用)/);
  return match === null ? '' : match[0];
}

function bimScenario(id, ok, blockedReason, evidence = {}) {
  const status = bimScenarioStatus(ok, blockedReason);
  const safeBlockedReason = sanitizeBimFailureReason(blockedReason);
  return {
    id,
    status,
    ok: status === 'PASS',
    ...(safeBlockedReason.length > 0 ? { reason: safeBlockedReason } : {}),
    ...evidence
  };
}

function writeBimLayout(prefix, layout) {
  const text = collectLayoutText(layout).join('\n');
  const textPath = join(outDir, `${prefix}-layout-text.txt`);
  writeFileSync(textPath, text + '\n');
  return { text, textPath };
}

async function waitForBimLayout(prefix, predicate, attempts = 12) {
  let latest = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const layout = dumpLayout(`${prefix}-${attempt + 1}-layout.json`);
    const written = writeBimLayout(`${prefix}-${attempt + 1}`, layout);
    latest = { layout, ...written };
    if (predicate(layout, written.text)) return latest;
    await sleep(400);
  }
  return latest;
}

async function submitBimPrompt(query, prefix) {
  clearHilog();
  const appPid = hdc(['shell', 'pidof', 'com.jiuwen.appless']).trim().split(/\s+/)[0] || '';
  const controls = await waitForControls(`${prefix}-controls-layout.json`);
  let typed = false;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(controls.input.x), String(controls.input.y)]);
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
    hdc(['shell', 'uitest', 'uiInput', 'text', query]);
    await sleep(700);
    if (collectInputText(dumpLayout(`${prefix}-input-${attempt + 1}-layout.json`)).includes(query)) {
      typed = true;
      break;
    }
  }
  if (!typed) throw new Error(`Could not type full BIM query: ${query}`);
  const logs = await captureWhile(appPid, async () => {
    const submit = await waitForControls(`${prefix}-submit-layout.json`, 2);
    hdc(['shell', 'uitest', 'uiInput', 'click', String(submit.generate.x), String(submit.generate.y)]);
  }, {
    idleActionTimeoutMs: 0,
    completionEvidence: (text) => ({
      complete: /\[AIPhone\]\[MultiAgentTurnResult\][^\n]*\bstatus=(?:success|partial|empty|error|canceled)\b/.test(text) ||
        bimUnavailableReason(text).length > 0
    })
  });
  const safeLogText = sanitizeExternalUrlLogs(logs.join('\n'));
  const logPath = join(outDir, `${prefix}.log`);
  writeFileSync(logPath, safeLogText + '\n');
  const final = await waitForBimLayout(`${prefix}-final`, () => true, 1);
  final.screenPath = captureScreen(`${prefix}-final-screen.png`);
  return { logs: safeLogText, logPath, ...final };
}

function tapBimText(layout, text, label) {
  const point = findTextCenter(layout, text);
  if (point === null) throw new Error(`Could not find ${label}.`);
  hdc(['shell', 'uitest', 'uiInput', 'click', String(point.x), String(point.y)]);
}

function tapBimHeart(layout) {
  const point = heartPointFromLayout(layout);
  if (point === null) throw new Error('Heart entry was not visible.');
  hdc(['shell', 'uitest', 'uiInput', 'click', String(point.x), String(point.y)]);
}

async function runBimSentinelMockSmoke() {
  const testPoint = await findTextCenterWithScroll(
    '10秒测试 Sentinel', 'bim-sentinel-action', 6
  );
  if (testPoint === null) throw new Error('Sentinel debug action was not visible.');

  clearHilog();
  const appPid = hdc(['shell', 'pidof', 'com.jiuwen.appless']).trim().split(/\s+/)[0] || '';
  let reminderScreenPath = '';
  let reminderLayoutPath = '';
  let reminderMissing = false;
  const logs = await captureWhile(appPid, async () => {
    hdc(['shell', 'uitest', 'uiInput', 'click', String(testPoint.x), String(testPoint.y)]);
    await sleep(900);
    const permissionLayout = dumpLayout('bim-sentinel-permission-layout.json', '');
    let inAppTimer = bimSentinelUsesInAppTimer(collectLayoutText(permissionLayout));
    const allow = findExactTextCenter(permissionLayout, '允许');
    if (allow !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(allow.x), String(allow.y)]);
      await sleep(900);
      const scheduledLayout = dumpLayout('bim-sentinel-scheduled-layout.json', '');
      inAppTimer = bimSentinelUsesInAppTimer(collectLayoutText(scheduledLayout));
    }
    await sleep(11000);
    if (inAppTimer) return;
    hdc(['shell', 'uitest', 'uiInput', 'swipe', '220', '20', '220', '1800', '800']);
    await sleep(1200);
    const reminderLayout = dumpLayout('bim-sentinel-reminder-layout.json', '');
    reminderLayoutPath = join(outDir, 'bim-sentinel-reminder-layout.json');
    writeFileSync(
      join(outDir, 'bim-sentinel-reminder-layout-text.txt'),
      collectLayoutText(reminderLayout).join('\n') + '\n'
    );
    const reminder = findTextCenter(reminderLayout, '检查心上事（测试）');
    if (reminder === null) {
      reminderMissing = true;
      return;
    }
    reminderScreenPath = captureCurrentScreen('bim-sentinel-reminder-screen.png');
    hdc(['shell', 'uitest', 'uiInput', 'click', String(reminder.x), String(reminder.y)]);
  }, {
    idleActionTimeoutMs: 0,
    completionEvidence: (text) => ({
      complete: bimSentinelEvidence(text).completed ||
        /\[AIPhone\]\[BimSentinelMockScheduled\] ok=false/.test(text) ||
        /\[AIPhone\]\[BimSentinel\] (?!mode=mock)/.test(text)
    })
  });
  const safeLogText = sanitizeExternalUrlLogs(logs.join('\n'));
  const logPath = join(outDir, 'bim-sentinel.log');
  writeFileSync(logPath, safeLogText + '\n');
  const evidence = bimSentinelEvidence(safeLogText);
  if (reminderMissing && evidence.transport !== 'in_app_timer') {
    throw new Error('Sentinel test reminder was not visible.');
  }
  if (reminderMissing) {
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    await sleep(700);
  }
  return {
    ...evidence,
    logPath,
    reminderLayoutPath,
    reminderScreenPath
  };
}

async function openBimMarker(marker, prefix) {
  let current = await waitForBimLayout(`${prefix}-current`, () => true, 1);
  if (hasBimHome(current.layout)) {
    tapBimHeart(current.layout);
    current = await waitForBimLayout(`${prefix}-directory`, (_layout, text) =>
      hasBimDirectory(_layout) && text.includes(marker), 30);
  }
  if (hasBimDirectory(current.layout)) {
    tapBimText(current.layout, marker, marker + ' row');
    current = await waitForBimLayout(`${prefix}-detail`, (_layout, text) =>
      text.includes(marker) && /当前 Snapshot · v\d+/.test(text), 30);
  }
  if (!current.text.includes(marker) || !/当前 Snapshot · v\d+/.test(current.text)) {
    throw new Error('Could not open the created BIM detail.');
  }
  const fullContextPoint = await findTextCenterWithScroll(
    '完整上下文', `${prefix}-full-context`, 4
  );
  if (fullContextPoint === null) throw new Error('Full Context was not visible in BIM detail.');
  const fullContext = await waitForBimLayout(`${prefix}-full-context-visible`, () => true, 1);
  if (!hasBimReadOnlyContext(current.layout, fullContext.layout) ||
    hasConversationTranscript(current.layout) || hasConversationTranscript(fullContext.layout)) {
    throw new Error('BIM detail was not read-only or contained conversation transcript.');
  }
  const fullContextScreenPath = captureScreen(`${prefix}-full-context-screen.png`);

  hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
  const directory = await waitForBimLayout(`${prefix}-return-directory`, (_layout, text) =>
    hasBimDirectory(_layout) && text.includes(marker), 20);
  tapBimText(directory.layout, marker, marker + ' row');
  current = await waitForBimLayout(`${prefix}-return-detail`, (_layout, text) =>
    text.includes(marker) && /当前 Snapshot · v\d+/.test(text), 20);
  return { ...current, readOnlyContext: true, fullContextScreenPath };
}

async function cleanupBimMarker(marker, prefix) {
  let detail = await openBimMarker(marker, prefix);
  if (!detail.text.includes('已结束')) {
    tapBimText(detail.layout, '结束', '结束 button');
    detail = await waitForBimLayout(`${prefix}-ended`, (_layout, text) =>
      text.includes(marker) && text.includes('已结束') && text.includes('删除'), 30);
  }
  tapBimText(detail.layout, '删除', '删除 button');
  const prompt = await waitForBimLayout(`${prefix}-confirm`, (_layout, text) =>
    text.includes('删除这件已结束的心上事？'), 20);
  const confirm = bimDeleteConfirmationPoint(prompt.layout);
  if (confirm === null) throw new Error('Delete confirmation action was not visible.');
  hdc(['shell', 'uitest', 'uiInput', 'click', String(confirm.x), String(confirm.y)]);
  const directory = await waitForBimLayout(`${prefix}-done`, (_layout, text) =>
    hasBimDirectory(_layout) && !text.includes(marker), 30);
  directory.screenPath = captureScreen(`${prefix}-screen.png`);
  return directory;
}

async function runBimDeviceSmoke() {
  const scenarios = [];
  let currentScenarioId = 'home';
  let failedScenarioId = '';
  let failureReason = '';
  let created = false;
  let cleanupComplete = false;
  const marker = 'BIM双机验收' + smokeRunId.replace(/\D/g, '').slice(-6);
  try {
    if (queryArgs.length > 0) throw new Error('--bim does not accept query arguments.');
    if (target.length === 0) target = firstTarget();
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
    hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
    hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.jiuwen.appless']);
    await sleep(3000);
    moveAppWindowIntoScreenshot();

    const initial = await waitForBimLayout('bim-initial-home', (layout) =>
      hasBimHome(layout) && heartCountFromLayout(layout) !== null, 30);
    const initialCount = heartCountFromLayout(initial.layout);
    initial.screenPath = captureScreen('bim-initial-home-screen.png');
    const homeOk = hasBimHome(initial.layout) && initialCount !== null;
    scenarios.push(bimScenario('home', homeOk, '', {
      heartCount: initialCount,
      screenPath: initial.screenPath
    }));
    if (!homeOk) {
      failureReason = 'BIM Home or heart count was not visible.';
      return;
    }

    currentScenarioId = 'main-agent';
    const main = await submitBimPrompt('解释一下量子计算', 'bim-main');
    const mainBlocked = bimUnavailableReason(main.logs, main.text);
    const mainOk = hasSnapshotOnlyMainAgent(main.logs) && hasBimHome(main.layout);
    scenarios.push(bimScenario('main-agent', mainOk, mainBlocked, {
      screenPath: main.screenPath,
      logPath: main.logPath
    }));
    if (!mainOk || mainBlocked.length > 0) {
      failureReason = mainBlocked || 'Main Agent did not finish exactly once without legacy BIM routing.';
      return;
    }

    currentScenarioId = 'curator-create';
    const create = await submitBimPrompt(
      `请帮我记在心上，标题必须是“${marker}”：验证完成后可以结束并删除。`,
      'bim-curator-create'
    );
    const createBlocked = bimUnavailableReason(create.logs, create.text);
    const confirmation = await waitForBimLayout('bim-curator-confirmation', (layout) =>
      findExactTextCenter(layout, '♡ 记在心上') !== null, 30);
    const beforeConfirmCount = heartCountFromLayout(confirmation.layout);
    const remember = findExactTextCenter(confirmation.layout, '♡ 记在心上');
    if (remember === null || beforeConfirmCount !== initialCount) {
      throw new Error('BIM was created before the remember confirmation.');
    }
    confirmation.screenPath = captureScreen('bim-curator-confirmation-screen.png');
    hdc(['shell', 'uitest', 'uiInput', 'click', String(remember.x), String(remember.y)]);
    const published = await waitForBimLayout('bim-curator-published', (layout) => {
      const count = heartCountFromLayout(layout);
      return hasBimHome(layout) && count !== null && count > initialCount;
    }, 180);
    const publishedCount = heartCountFromLayout(published.layout);
    created = publishedCount !== null && publishedCount > initialCount;
    const createOk = created && !/\[AIPhone\]\[(?:BimRoute|BimGate)\]/.test(create.logs);
    published.screenPath = captureScreen('bim-curator-published-screen.png');
    scenarios.push(bimScenario('curator-create', createOk, createBlocked, {
      beforeCount: initialCount,
      confirmationCount: beforeConfirmCount,
      confirmationScreenPath: confirmation.screenPath,
      afterCount: publishedCount,
      screenPath: published.screenPath,
      logPath: create.logPath
    }));
    if (!createOk || createBlocked.length > 0) {
      failureReason = createBlocked || 'Asynchronous Curator did not publish one new BIM.';
      return;
    }

    currentScenarioId = 'directory';
    tapBimHeart(published.layout);
    const directory = await waitForBimLayout('bim-directory', (layout, text) =>
      hasBimDirectory(layout) && text.includes(marker), 30);
    directory.screenPath = captureScreen('bim-directory-screen.png');
    const directoryOk = hasBimDirectory(directory.layout) && directory.text.includes(marker);
    scenarios.push(bimScenario('directory', directoryOk, '', { screenPath: directory.screenPath }));
    if (!directoryOk) {
      failureReason = 'Heart directory did not show the asynchronously created BIM.';
      return;
    }

    currentScenarioId = 'sentinel';
    const sentinel = await runBimSentinelMockSmoke();
    const sentinelOk = sentinel.scheduled && sentinel.triggered && sentinel.completed;
    scenarios.push(bimScenario('sentinel', sentinelOk, '', sentinel));
    if (!sentinelOk) {
      failureReason = 'Sentinel reminder did not complete the scheduled, triggered, and finished chain.';
      return;
    }

    currentScenarioId = 'detail';
    const detail = await openBimMarker(marker, 'bim-detail');
    detail.screenPath = captureScreen('bim-detail-screen.png');
    const detailOk = detail.readOnlyContext &&
      !hasConversationTranscript(detail.layout) &&
      detail.text.includes(marker);
    scenarios.push(bimScenario('detail', detailOk, '', {
      screenPath: detail.screenPath,
      fullContextScreenPath: detail.fullContextScreenPath
    }));
    if (!detailOk) {
      failureReason = 'Detail did not show read-only Snapshot and Full Context.';
      return;
    }

    currentScenarioId = 'cleanup';
    const cleaned = await cleanupBimMarker(marker, 'bim-cleanup');
    cleanupComplete = !cleaned.text.includes(marker);
    scenarios.push(bimScenario('cleanup', cleanupComplete, '', { screenPath: cleaned.screenPath }));
    if (!cleanupComplete) failureReason = 'Created BIM was not deleted after validation.';
  } catch (error) {
    failureReason = sanitizeBimFailureReason(error);
    failedScenarioId = currentScenarioId;
    if (!scenarios.some((scenario) => scenario.id === currentScenarioId)) {
      scenarios.push(bimScenario(currentScenarioId, false, '', { reason: failureReason }));
    }
  } finally {
    if (created && !cleanupComplete) {
      try {
        const recovered = await cleanupBimMarker(marker, 'bim-cleanup-recovery');
        cleanupComplete = !recovered.text.includes(marker);
        const cleanup = scenarios.find((scenario) => scenario.id === 'cleanup');
        const recoveredScenario = bimScenario('cleanup', cleanupComplete, '', {
          screenPath: recovered.screenPath,
          recovered: true
        });
        if (cleanup === undefined) scenarios.push(recoveredScenario);
        else Object.assign(cleanup, recoveredScenario);
      } catch (cleanupError) {
        const cleanupReason = sanitizeBimFailureReason(cleanupError);
        if (!scenarios.some((scenario) => scenario.id === 'cleanup')) {
          scenarios.push(bimScenario('cleanup', false, '', { reason: cleanupReason }));
        }
        if (failureReason.length === 0) failureReason = cleanupReason;
      }
    }
    return finishBimSmoke(scenarios, failureReason, failedScenarioId);
  }
}

function finishBimSmoke(scenarios, failureReason, failedId = '') {
  const safeFailureReason = sanitizeBimFailureReason(failureReason || 'BIM smoke did not complete.');
  const completedScenarios = completeBimScenarios(scenarios, safeFailureReason, failedId);
  const ok = completedScenarios.every((scenario) => scenario.status === 'PASS');
  const summary = {
    caseId: 'BIM',
    status: bimSmokeStatus(completedScenarios.map((scenario) => scenario.status)),
    ok,
    scenarios: completedScenarios,
    ...(ok ? {} : { reason: safeFailureReason })
  };
  snapshotCaseArtifacts('BIM', 1, ['bim'], summary);
  writeFileSync(join(outDir, 'bim-summary.json'), JSON.stringify(summary, null, 2));
  return summary;
}

async function tapPublicPersonaText(marker, localName, attempts = 18) {
  let lastLayout = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      lastLayout = dumpLayout(`${localName}-${attempt + 1}.json`);
    } catch (_error) {
      await sleep(700);
      continue;
    }
    const center = findTextCenter(lastLayout, marker);
    if (center !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      await sleep(500);
      return { center, layout: lastLayout };
    }
    await sleep(700);
  }
  return { center: null, layout: lastLayout };
}

async function waitForPublicPersonaTerminal(localName) {
  let last = null;
  let lastPath = '';
  const maxAttempts = Number.parseInt(process.env.AIPHONE_PUBLIC_PERSONA_MAX_ATTEMPTS || '180', 10);
  for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
    lastPath = join(outDir, `${localName}-${attempt + 1}.json`);
    last = dumpLayout(`${localName}-${attempt + 1}.json`);
    const text = collectLayoutText(last).join('\n');
    if (text.includes('确认这些账号') || text.includes('暂时没有能确认的公开账号') ||
      text.includes('这次没有完成') || text.includes('你的画像')) {
      return { layout: last, text, attempts: attempt + 1, path: lastPath };
    }
    await sleep(1000);
  }
  return { layout: last, text: last === null ? '' : collectLayoutText(last).join('\n'), attempts: maxAttempts, path: lastPath };
}

async function waitForPublicPersonaManualResume(message = '完成当前画像页面的手动步骤后按 Enter 继续取证：') {
  if (!process.stdin.isTTY) {
    return false;
  }
  const reader = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => {
    reader.question(message, () => {
      reader.close();
      resolve(true);
    });
  });
}

async function waitForPublicPersonaReadingState(localName) {
  let last = null;
  let lastPath = '';
  for (let attempt = 0; attempt < 90; attempt += 1) {
    lastPath = join(outDir, `${localName}-${attempt + 1}.json`);
    last = dumpLayout(`${localName}-${attempt + 1}.json`);
    const text = collectLayoutText(last).join('\n');
    if (/正在整理你的画像|正在读取|正在生成/.test(text)) {
      return { layout: last, text, path: lastPath, attempts: attempt + 1 };
    }
    await sleep(1000);
  }
  return { layout: last, text: last === null ? '' : collectLayoutText(last).join('\n'), path: lastPath, attempts: 90 };
}

function publicPersonaMbtiLine(text) {
  const match = /[EI][NS][TF][JP] · \d+%/.exec(text);
  return match === null ? '' : match[0];
}

function publicPersonaSeedHandle(url) {
  try {
    const path = new URL(url).pathname.replace(/\/+$/, '');
    const segments = path.split('/').filter((value) => value.length > 0);
    return segments.length === 0 ? '' : segments[segments.length - 1].replace(/^@/, '');
  } catch {
    return '';
  }
}

function publicPersonaRequestMarker(text) {
  const match = /\b(?:request|turn|conversation|message|prompt)[_-]?id\s*[:=]\s*["']?([A-Za-z0-9][A-Za-z0-9_-]{3,})/i.exec(text);
  return match === null ? '' : match[1];
}

function publicPersonaPromptAssemblySafe() {
  const source = readFileSync(join(rootDir, 'entry/src/main/ets/pages/A2uiHome/Index.ets'), 'utf8');
  const start = source.indexOf('  private async submitPrompt(');
  const end = source.indexOf('\n  private ', start + 1);
  if (start < 0 || end <= start) {
    return false;
  }
  return !/publicPersonaSnapshot|publicPersonaStore|aiphone_public_persona|snapshot_v1/.test(source.slice(start, end));
}

function publicPersonaMainAvatarEvidence(layout) {
  let count = 0;
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    const type = String(node.type || node.componentType || attrs.type || '');
    if (bounds !== null && /image/i.test(type) && bounds.width >= 70 && bounds.width <= 100 &&
      bounds.height >= 70 && bounds.height <= 100 && bounds.top < 720) {
      count += 1;
    }
  });
  return count === 1;
}

function publicPersonaLayoutContainsType(layout, pattern) {
  let found = false;
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const type = String(node.type || node.componentType || attrs.type || '');
    if (pattern.test(type)) found = true;
  });
  return found;
}

async function enterPublicPersonaFromHome(existingSnapshot = false) {
  let opened = await tapPublicPersonaText('我的画像', 'public-persona-open', 2);
  if (opened.center === null && opened.layout !== null) {
    const center = findHeaderPublicPersonaCenter(opened.layout);
    if (center !== null) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(center.x), String(center.y)]);
      await sleep(500);
      opened = { center, layout: opened.layout };
    }
  }
  if (opened.center === null) {
    return { ok: false, reason: 'public persona entry not found' };
  }
  const layout = dumpLayout('public-persona-opened-after-tap.json');
  const layoutText = collectLayoutText(layout).join('\n');
  const onboarding = layoutText.includes('开始设置');
  let input = layoutText.includes('开始查找') || layoutText.includes('输入一个你常用的用户名');
  if (onboarding) {
    await tapPublicPersonaText('开始设置', 'public-persona-setup');
  }
  if (existingSnapshot && input === false) {
    const restart = await tapPublicPersonaText('重新认识我', 'public-persona-restart');
    if (restart.center !== null) input = true;
  }
  if (input === false) {
    const retry = await tapPublicPersonaText('重新输入', 'public-persona-retry-input');
    if (retry.center !== null) input = true;
  }
  return { ok: input || onboarding, onboarding, input };
}

async function startPublicPersonaDiscoveryOnDevice() {
  const layout = dumpLayout('public-persona-input-layout.json');
  const input = findTextMatches(layout, '例如 XiaoLuoLYG')[0] ||
    findTextMatches(layout, '输入一个你常用的用户名')[0];
  if (input === undefined) {
    return { ok: false, reason: 'public persona username input not found' };
  }
  hdc(['shell', 'uitest', 'uiInput', 'click', String(input.bounds.x), String(input.bounds.y)]);
  hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
  hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
  hdc(['shell', 'uitest', 'uiInput', 'text', publicPersonaUsername]);
  hdc(['shell', 'uitest', 'uiInput', 'keyEvent', 'Back']);
  await sleep(250);
  if (publicPersonaSearchMode === 'exact') {
    const mode = await tapPublicPersonaText('精确', 'public-persona-exact-mode');
    if (mode.center === null) return { ok: false, reason: '精确 mode button not found' };
  }
  const started = await tapPublicPersonaText('开始查找', 'public-persona-start');
  return started.center === null ? { ok: false, reason: '开始查找 button not found' } : { ok: true };
}

async function runPublicPersonaSmoke() {
  const nativeAdmission = publicPersonaExpectedPlatform.length > 0 &&
    publicPersonaExpectedState.length > 0;
  if (nativeAdmission) {
    const installOutput = hdc(['install', '-r', publicPersonaHapPath]);
    if (!/install bundle successfully/i.test(installOutput)) {
      throw new Error('Could not install the verified public persona HAP for admission.');
    }
  }
  const initialSnapshotProbe = publicPersonaSnapshotProbe();
  if (initialSnapshotProbe.status === 'BLOCKED') {
    const reason = initialSnapshotProbe.reason;
    const summary = {
      mode: 'public-persona',
      username: '<redacted>',
      snapshotState: 'BLOCKED',
      blocked: reason,
      cases: publicPersonaCases.map((testCase) => ({
        id: testCase.id,
        status: 'BLOCKED',
        ok: false,
        manualGate: true,
        reason
      })),
      ok: false
    };
    writeFileSync(join(outDir, 'public-persona-summary.json'), JSON.stringify(summary, null, 2));
    return summary;
  }
  if (publicPersonaSnapshotExists(initialSnapshotProbe) && !nativeAdmission) {
    const reason = 'existing_persona_snapshot';
    const summary = {
      mode: 'public-persona',
      username: '<redacted>',
      snapshotState: 'PRESENT',
      blocked: reason,
      cases: publicPersonaCases.map((testCase) => ({
        id: testCase.id,
        status: 'BLOCKED',
        ok: false,
        manualGate: true,
        reason
      })),
      ok: false
    };
    writeFileSync(join(outDir, 'public-persona-summary.json'), JSON.stringify(summary, null, 2));
    return summary;
  }
  let snapshotCreatedThisRun = false;
  let snapshotDeleted = false;
  try {
    clearHilog();
    hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
    hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.jiuwen.appless']);
    await sleep(3000);
    moveAppWindowIntoScreenshot();
    const cases = [];
    const manualResume = process.env.AIPHONE_PUBLIC_PERSONA_MANUAL_RESUME === '1' && Boolean(process.stdin.isTTY);
    const firstLaunchProbe = publicPersonaSnapshotProbe();
    if (firstLaunchProbe.status === 'BLOCKED') {
      const reason = firstLaunchProbe.reason;
      const blockedSummary = {
        mode: 'public-persona', username: '<redacted>', snapshotState: 'BLOCKED', blocked: reason,
        cases: publicPersonaCases.map((testCase) => ({
          id: testCase.id, status: 'BLOCKED', ok: false, manualGate: true, reason
        })),
        ok: false
      };
      writeFileSync(join(outDir, 'public-persona-summary.json'), JSON.stringify(blockedSummary, null, 2));
      return blockedSummary;
    }
    const firstLaunch = await enterPublicPersonaFromHome(
      nativeAdmission && publicPersonaSnapshotExists(firstLaunchProbe));
    let p01 = { id: 'P01', status: 'BLOCKED', ok: false, manualGate: true, reason: firstLaunch.reason || '' };
    const p02 = {
      id: 'P02', status: 'BLOCKED', ok: false, manualGate: true,
      reason: manualResume ? 'manual confirmation not yet evidenced' : 'requires explicit manual resume'
    };
    let p02Result = p02;
    let p02Baseline = '';
    let selectedProfileUrls = [];
    let knownUnselectedProfileUrls = [];
    let selectionMode = 'unavailable';
    let selectionStepEvidence = false;
    let selectionLayoutEvidence = false;
    let selectionSetsMatch = false;
    let selectionLayoutPath = null;
    let p01Terminal = { layout: null, text: '', attempts: 0, path: '' };
    let discoveryLogs = [];
    if (firstLaunch.ok) {
      const appPid = hdc(['shell', 'pidof', 'com.jiuwen.appless']).trim();
      discoveryLogs = await captureAppLogsFor(appPid, async () => {
        await sleep(250);
        const started = await startPublicPersonaDiscoveryOnDevice();
        p01Terminal = started.ok ? await waitForPublicPersonaTerminal('public-persona-p01') : p01Terminal;
      }, 250);
      const summaryMatch = /明确结果 (\d+) · 找到 (\d+) · 未找到 (\d+) · 未完成 (\d+)/.exec(p01Terminal.text);
      let explicitCount = summaryMatch === null ? -1 : Number(summaryMatch[1]);
      let foundCount = summaryMatch === null ? -1 : Number(summaryMatch[2]);
      let notFoundCount = summaryMatch === null ? -1 : Number(summaryMatch[3]);
      let unknownCount = summaryMatch === null ? -1 : Number(summaryMatch[4]);
      const totalMatch = /已尝试 (\d+) 个公开平台/.exec(p01Terminal.text);
      let attemptedTotal = totalMatch === null ? -1 : Number(totalMatch[1]);
      let attemptedAll = attemptedTotal > 0 && explicitCount === foundCount + notFoundCount &&
        foundCount + notFoundCount + unknownCount === attemptedTotal;
      const candidateLayout = p01Terminal.layout === null ? null : p01Terminal.layout;
      const candidateText = candidateLayout === null ? p01Terminal.text : collectLayoutText(candidateLayout).join('\n');
      const candidateRows = candidateLayout === null ? [] : publicPersonaCandidateLayoutState(candidateLayout);
      const candidateExists = candidateRows.length > 0 &&
        !candidateText.includes('暂时没有能确认的公开账号') && !candidateText.includes('这次没有完成');
      const seedHandle = publicPersonaUsername.replace(/^@/, '');
      const seedCandidateVisible = seedHandle.length > 0 && (publicPersonaExpectedPlatform.length > 0 ?
        candidateRows.some((row) => row.key === `${publicPersonaExpectedPlatform}:${seedHandle.toLowerCase()}`) :
        candidateText.includes('@' + seedHandle));
      const discoveryProviderLog = sanitizeExternalUrlLogs(discoveryLogs.join('\n'));
      writeFileSync(join(outDir, 'public-persona-discovery.log'), discoveryProviderLog + '\n');
      const probeStates = publicPersonaProbeStatesFromLog(discoveryProviderLog);
      writeFileSync(join(outDir, 'public-persona-probe-states.json'), JSON.stringify(probeStates, null, 2));
      const loggedStates = Object.values(probeStates);
      const loggedTerminal = /completed=(\d+)\/\1(?:\D|$)/.exec(discoveryProviderLog);
      if (!attemptedAll && loggedTerminal !== null && loggedStates.length === Number(loggedTerminal[1])) {
        attemptedTotal = Number(loggedTerminal[1]);
        foundCount = loggedStates.filter((state) => state === 'found').length;
        notFoundCount = loggedStates.filter((state) => state === 'not_found').length;
        unknownCount = loggedStates.filter((state) => state === 'unknown').length;
        explicitCount = foundCount + notFoundCount;
        attemptedAll = explicitCount + unknownCount === attemptedTotal;
      }
      const admissionMode = publicPersonaExpectedPlatform.length > 0 && publicPersonaExpectedState.length > 0;
      const actualExpectedState = admissionMode ?
        probeStates[publicPersonaExpectedPlatform] ||
          publicPersonaProbeResultFromLog(discoveryProviderLog, publicPersonaExpectedPlatform) : '';
      const expectedStateMatched = admissionMode && actualExpectedState === publicPersonaExpectedState;
      const expectedCandidateMatched = publicPersonaExpectedState === 'found' ? seedCandidateVisible :
        publicPersonaExpectedState === 'not_found' && !seedCandidateVisible;
      clearHilog();
      p02Baseline = hdc(['shell', 'hilog', '-d']);
      const manualCandidateConfirmed = manualResume && candidateExists && await waitForPublicPersonaManualResume(
        '请逐张核对候选卡的头像、平台 logo、显示名、@用户名和主页链接；确认无误后按 Enter：'
      );
      const candidateCardEvidence = {
        avatar: manualCandidateConfirmed,
        platformLogo: manualCandidateConfirmed,
        displayName: manualCandidateConfirmed,
        username: manualCandidateConfirmed,
        profileUrl: manualCandidateConfirmed,
        manualCandidateConfirmed
      };
      const candidateFieldsConfirmed = Object.values(candidateCardEvidence).every(Boolean);
      selectionStepEvidence = manualCandidateConfirmed && seedCandidateVisible &&
        await waitForPublicPersonaManualResume(
          '请在当前确认页实际选择账号，并核对选中/排除列表后按 Enter：'
        );
      const configuredInput = publicPersonaSelectedUrls.length > 0 && publicPersonaUnselectedUrls.length > 0;
      const requestedSelectedUrls = configuredInput ? publicPersonaSelectedUrls.slice() : [];
      const requestedUnselectedUrls = publicPersonaUnselectedUrls.slice();
      const expectedSelectedKeys = requestedSelectedUrls.map((url) => publicPersonaAccountKey(url));
      const expectedUnselectedKeys = requestedUnselectedUrls.map((url) => publicPersonaAccountKey(url));
      const invalidConfiguredAccount = expectedSelectedKeys.some((key) => key.length === 0) ||
        expectedUnselectedKeys.some((key) => key.length === 0);
      const uniqueExpectedSelectedKeys = [...new Set(expectedSelectedKeys)];
      const uniqueExpectedUnselectedKeys = [...new Set(expectedUnselectedKeys)];
      const selectionLayout = selectionStepEvidence ? dumpLayout('public-persona-p01-selection.json') : null;
      selectionLayoutPath = selectionLayout === null ? null : join(outDir, 'public-persona-p01-selection.json');
      const layoutCandidates = selectionLayout === null ? [] : publicPersonaCandidateLayoutState(selectionLayout);
      const layoutKeys = layoutCandidates.map((row) => row.key);
      const expectedKeys = [...new Set(uniqueExpectedSelectedKeys.concat(uniqueExpectedUnselectedKeys))];
      const layoutKeySetMatches = expectedKeys.length > 0 && layoutCandidates.length === expectedKeys.length &&
        layoutKeys.filter((key) => expectedKeys.includes(key)).length === expectedKeys.length;
      const selectedStateMatches = uniqueExpectedSelectedKeys.length > 0 && uniqueExpectedUnselectedKeys.length > 0 &&
        layoutCandidates.filter((row) => uniqueExpectedSelectedKeys.includes(row.key) && row.selected).length === uniqueExpectedSelectedKeys.length &&
        layoutCandidates.filter((row) => uniqueExpectedUnselectedKeys.includes(row.key) && !row.selected).length === uniqueExpectedUnselectedKeys.length;
      selectionSetsMatch = !invalidConfiguredAccount && uniqueExpectedSelectedKeys.length > 0 &&
        uniqueExpectedUnselectedKeys.length > 0 &&
        uniqueExpectedSelectedKeys.filter((key) => uniqueExpectedUnselectedKeys.includes(key)).length === 0 &&
        layoutKeySetMatches && selectedStateMatches;
      selectionLayoutEvidence = selectionStepEvidence && selectionSetsMatch;
      const providerLog = discoveryProviderLog + '\n' + sanitizeExternalUrlLogs(hdc(['shell', 'hilog', '-d']));
      const allSourcesTerminal = unknownCount === 0;
      const providerBlocked = !allSourcesTerminal || candidateText.includes('模糊搜索未完成') ||
        /AUTH_REQUIRED|needs_auth|blocked_by_site|credits_exhausted|timeout|调用失败|login wall/i.test(providerLog);
      const admissionOk = admissionMode && attemptedAll && allSourcesTerminal && expectedStateMatched && expectedCandidateMatched;
      const normalOk = attemptedAll && candidateExists && candidateFieldsConfirmed && !providerBlocked;
      p01 = {
        id: 'P01',
        status: (admissionMode ? admissionOk : normalOk) ? 'PASS' : 'BLOCKED',
        ok: admissionMode ? admissionOk : normalOk, manualGate: !admissionMode,
        attemptedAll,
        attemptedTotal,
        explicitCount,
        foundCount,
        notFoundCount,
        unknownCount,
        allSourcesTerminal,
        candidateCardEvidence,
        candidateFieldsConfirmed,
        seedCandidateVisible,
        admissionMode,
        expectedPlatform: publicPersonaExpectedPlatform,
        expectedState: publicPersonaExpectedState,
        actualExpectedState,
        expectedStateMatched,
        expectedCandidateMatched,
        selectionStepEvidence,
        selectionLayoutEvidence,
        selectionSetsMatch,
        selectionLayoutPath,
        providerBlocked,
        attempts: p01Terminal.attempts,
        layoutPath: p01Terminal.path,
        screenPath: captureScreen('P01-public-persona.png')
      };
      if (selectionLayoutEvidence && configuredInput) {
        selectionMode = 'configured_urls';
        selectedProfileUrls = publicPersonaSelectedUrls.slice();
        knownUnselectedProfileUrls = publicPersonaUnselectedUrls.slice();
      }
    }
    cases.push(p01);
    snapshotCaseArtifacts('P01', 1, ['public-persona-p01'], p01);
    if (publicPersonaExpectedPlatform.length > 0 && publicPersonaExpectedState.length > 0) {
      const row = {
        platform: publicPersonaExpectedPlatform,
        fixtureClass: (process.env.AIPHONE_PUBLIC_PERSONA_FIXTURE_CLASS ||
          (publicPersonaExpectedState === 'found' ? 'claimed' : 'unclaimed')).trim(),
        username: '<redacted>',
        hapSha256: publicPersonaHapSha256,
        device: target,
        status: p01.ok ? 'PASS' : 'BLOCKED',
        bodyLength: null,
        matchedRule: 'structured_progress',
        state: p01.actualExpectedState,
        timestamp: new Date().toISOString()
      };
      writeFileSync(join(outDir, 'public-persona-native-row.json'), JSON.stringify(row, null, 2));
      const summary = {
        mode: 'public-persona-native-admission', username: '<redacted>', searchMode: publicPersonaSearchMode,
        cases: [p01], row, cleanup_required: false, ok: p01.ok
      };
      writeFileSync(join(outDir, 'public-persona-summary.json'), JSON.stringify(summary, null, 2));
      return summary;
    }

    const p03 = {
      id: 'P03', status: 'BLOCKED', ok: false, manualGate: true,
      reason: 'no_safe_job_token', leaveWhileBusyEvidence: false,
      taskContinuedEvidence: false, jobEvidence: 'unavailable', jobIdPresent: false
    };
    let p03Result = p03;
    if (manualResume && p01.ok && selectionMode !== 'unavailable' && selectionStepEvidence && selectionLayoutEvidence &&
      await waitForPublicPersonaManualResume(
        '请在候选页点击“确认并生成画像”，等待画像终态可见后按 Enter：'
      )) {
      const terminal = await waitForPublicPersonaTerminal('public-persona-p02');
      const afterRaw = hdc(['shell', 'hilog', '-d']);
      const deltaResult = publicPersonaLogDelta(p02Baseline, afterRaw);
      const deltaRaw = deltaResult.delta;
      const baselineMismatch = deltaResult.baselineMismatch;
      const profileMarkers = selectedProfileUrls.flatMap((url) => {
        try {
          const parsed = new URL(url);
          return [url, `${parsed.hostname}${parsed.pathname}`];
        } catch {
          return [url];
        }
      });
      const correlationMarker = profileMarkers.some((marker) => marker.length > 0 && deltaRaw.includes(marker));
      const webPageReadObserved = /web\.page\.read/.test(deltaRaw);
      const knownUnselectedPresent = knownUnselectedProfileUrls.filter((url) => {
        if (deltaRaw.includes(url)) {
          return true;
        }
        try {
          const parsed = new URL(url);
          return deltaRaw.includes(`${parsed.hostname}${parsed.pathname}`);
        } catch {
          return false;
        }
      });
      const knownUnselectedAbsent = knownUnselectedProfileUrls.length > 0 && knownUnselectedPresent.length === 0;
      const deltaLogPath = join(outDir, 'public-persona-p02-delta.log');
      writeFileSync(deltaLogPath, JSON.stringify({
        webPageReadObserved, correlationMarker, selectedProfileCount: selectedProfileUrls.length,
        selectionMode, knownUnselectedCount: knownUnselectedProfileUrls.length, knownUnselectedAbsent,
        baselineMismatch
      }, null, 2));
      const completedLayout = terminal.text.includes('你的画像') && !terminal.text.includes('确认这些账号');
      const createdSnapshotProbe = publicPersonaSnapshotProbe();
      snapshotCreatedThisRun = completedLayout && publicPersonaSnapshotExists(createdSnapshotProbe);
      const completedText = terminal.text.toLowerCase();
      const selectedHandles = selectedProfileUrls.map((url) => publicPersonaSeedHandle(url).toLowerCase()).filter(Boolean);
      const unselectedHandles = knownUnselectedProfileUrls.map((url) => publicPersonaSeedHandle(url).toLowerCase()).filter(Boolean);
      const selectedSourcesVisible = selectedHandles.length > 0 && selectedHandles.every((handle) => completedText.includes('@' + handle));
      const unselectedSourcesAbsent = unselectedHandles.length > 0 && unselectedHandles.every((handle) => !completedText.includes('@' + handle));
      const selectedReadEvidence = selectionLayoutEvidence && selectionMode === 'configured_urls' &&
        selectedSourcesVisible && unselectedSourcesAbsent && snapshotCreatedThisRun;
      p02Result = {
        id: 'P02', status: selectedReadEvidence && completedLayout ? 'PASS' : 'BLOCKED',
        ok: selectedReadEvidence && completedLayout, manualGate: true,
        selectedReadEvidence, completedLayout, snapshotCreatedThisRun,
        selectedProfileUrls: selectedProfileUrls.length, selectionMode, correlationMarker,
        selectedSourcesVisible, unselectedSourcesAbsent, webPageReadObserved,
        knownUnselectedCount: knownUnselectedProfileUrls.length, knownUnselectedAbsent, baselineMismatch,
        selectionLayoutEvidence, deltaLogPath,
        screenPath: captureScreen('P02-public-persona.png')
      };
    }
    cases.push(p02Result);
    snapshotCaseArtifacts('P02', 1, ['public-persona-p02'], p02Result);
    cases.push(p03Result);
    snapshotCaseArtifacts('P03', 1, ['public-persona-p03'], p03Result);

    let p04Result = {
      id: 'P04', status: 'BLOCKED', ok: false, manualGate: true,
      reason: 'requires manual edit/save/reload/reinfer/hide evidence',
      oneMainAvatar: null, markdownPresent: null, mbtiPresent: null,
      editSaveReload: false, saveExitEvidence: false, reenterReloadEvidence: false,
      mbtiReinferred: false, mbtiHiddenReloaded: false,
      screenPath: null
    };
    if (manualResume && p02Result.ok && await waitForPublicPersonaManualResume(
      '请编辑 persona.md 加入 P04-smoke-edit，点击保存并退出编辑态；回到画像页后按 Enter：'
    )) {
      const afterSaveExitLayout = dumpLayout('public-persona-p04-after-save-exit.json');
      const afterSaveExitText = collectLayoutText(afterSaveExitLayout).join('\n');
      const saveExitEvidence = !publicPersonaLayoutContainsType(afterSaveExitLayout, /TextArea/i) &&
        afterSaveExitText.includes('persona.md');
      const reenterReady = saveExitEvidence && await waitForPublicPersonaManualResume(
        '请离开画像页后重新进入画像页（可再进入编辑页），确认已保存内容后按 Enter：'
      );
      const savedReloadedLayout = reenterReady ? dumpLayout('public-persona-p04-saved-reloaded.json') : null;
      const savedReloadedText = savedReloadedLayout === null ? '' : collectLayoutText(savedReloadedLayout).join('\n');
      const reenterReloadEvidence = reenterReady && savedReloadedLayout !== null &&
        savedReloadedText.includes('persona.md');
      const editSaveReload = saveExitEvidence && reenterReloadEvidence &&
        savedReloadedText.includes('P04-smoke-edit');
      const mbtiBefore = publicPersonaMbtiLine(savedReloadedText);
      const reinferReady = reenterReloadEvidence && await waitForPublicPersonaManualResume(
        '请点击 MBTI 触发重新推测，等待结果可见后按 Enter：'
      );
      const reinferLayout = reinferReady ? dumpLayout('public-persona-p04-reinferred.json') : null;
      const reinferText = reinferLayout === null ? '' : collectLayoutText(reinferLayout).join('\n');
      const mbtiReinferred = reinferReady && publicPersonaMbtiLine(reinferText).length > 0 &&
        publicPersonaMbtiLine(reinferText) !== mbtiBefore;
      const hideReady = reinferReady && await waitForPublicPersonaManualResume(
        '请点击隐藏 MBTI，离开再返回后按 Enter：'
      );
      const hiddenLayout = hideReady ? dumpLayout('public-persona-p04-hidden-reloaded.json') : null;
      const hiddenText = hiddenLayout === null ? '' : collectLayoutText(hiddenLayout).join('\n');
      const mbtiHiddenReloaded = hideReady && !/## MBTI 推测|[EI][NS][TF][JP] · \d+%/.test(hiddenText);
      const oneMainAvatar = hiddenLayout !== null && publicPersonaMainAvatarEvidence(hiddenLayout);
      const p04Ok = oneMainAvatar && editSaveReload && mbtiReinferred && mbtiHiddenReloaded;
      p04Result = {
        id: 'P04', status: p04Ok ? 'PASS' : 'BLOCKED', ok: p04Ok, manualGate: true,
        oneMainAvatar, markdownPresent: savedReloadedText.includes('persona.md'),
        mbtiPresent: mbtiBefore.length > 0, editSaveReload, saveExitEvidence, reenterReloadEvidence,
        mbtiReinferred, mbtiHiddenReloaded,
        afterSaveExitLayoutPath: join(outDir, 'public-persona-p04-after-save-exit.json'),
        savedReloadedLayoutPath: savedReloadedLayout === null ? null : join(outDir, 'public-persona-p04-saved-reloaded.json'),
        reinferLayoutPath: reinferLayout === null ? null : join(outDir, 'public-persona-p04-reinferred.json'),
        hiddenLayoutPath: hiddenLayout === null ? null : join(outDir, 'public-persona-p04-hidden-reloaded.json'),
        screenPath: hiddenLayout === null ? null : captureScreen('P04-public-persona.png')
      };
    }
    cases.push(p04Result);
    snapshotCaseArtifacts('P04', 1, ['public-persona-p04'], p04Result);

    let p05Result = {
      id: 'P05', status: 'BLOCKED', ok: false, manualGate: true,
      reason: snapshotCreatedThisRun ? 'cleanup_required: explicit manual delete not evidenced' : 'snapshot_not_created_this_run',
      localDeleteOk: null, promptPersonaAbsent: null, promptEvidence: 'not_attempted',
      promptAssemblySafe: publicPersonaPromptAssemblySafe(),
      cleanup_required: snapshotCreatedThisRun, screenPath: null
    };
    if (manualResume && snapshotCreatedThisRun && await waitForPublicPersonaManualResume(
      '请手动点击“删除画像”并确认删除；返回首页后按 Enter：'
    )) {
      const deletedSnapshotProbe = publicPersonaSnapshotProbe();
      const localDeleteOk = deletedSnapshotProbe.status === 'ABSENT';
      snapshotDeleted = localDeleteOk;
      let promptPersonaAbsent = null;
      let promptEvidence = 'not_attempted';
      let promptEvidencePath = null;
      const p05PromptBaseline = localDeleteOk ? hdc(['shell', 'hilog', '-d']) : '';
      if (localDeleteOk && await waitForPublicPersonaManualResume(
        '删除后发送一条普通对话，确认请求未带入画像上下文；完成后按 Enter：'
      )) {
        const promptAfterRaw = hdc(['shell', 'hilog', '-d']);
        const promptDeltaResult = publicPersonaStrictLogDelta(p05PromptBaseline, promptAfterRaw);
        const promptDelta = promptDeltaResult.delta;
        const requestMarker = publicPersonaRequestMarker(promptDelta);
        const requestMarkerObserved = promptDeltaResult.matched && requestMarker.length > 0 &&
          /model|chat|inference|prompt/i.test(promptDelta);
        const personaMarkerObserved = /snapshot_v1|persona\.md|public persona|MBTI 推测/i.test(promptDelta);
        const promptAssemblySafe = publicPersonaPromptAssemblySafe();
        promptPersonaAbsent = requestMarkerObserved && promptAssemblySafe && !personaMarkerObserved;
        promptEvidence = promptPersonaAbsent ? 'request_canary_absent' : 'request_canary_unproven';
        promptEvidencePath = join(outDir, 'public-persona-p05-prompt-canary.log');
        writeFileSync(promptEvidencePath, JSON.stringify({
          requestMarkerObserved, personaMarkerObserved, requestMarker: requestMarker.length > 0 ? '<present>' : '<absent>'
        }, null, 2));
      }
      const p05Ok = localDeleteOk && promptPersonaAbsent === true;
      p05Result = {
        id: 'P05', status: p05Ok ? 'PASS' : 'BLOCKED', ok: p05Ok, manualGate: true,
        reason: deletedSnapshotProbe.status === 'BLOCKED' ? deletedSnapshotProbe.reason : '',
        snapshotState: deletedSnapshotProbe.status,
        localDeleteOk, promptPersonaAbsent, promptEvidence, promptEvidencePath,
        promptAssemblySafe: publicPersonaPromptAssemblySafe(),
        cleanup_required: !localDeleteOk, screenPath: captureScreen('P05-public-persona.png')
      };
    }
    cases.push(p05Result);
    snapshotCaseArtifacts('P05', 1, ['public-persona-p05'], p05Result);
    const summary = {
      mode: 'public-persona', username: '<redacted>', searchMode: publicPersonaSearchMode, cases,
      cleanup_required: snapshotCreatedThisRun && !snapshotDeleted,
      ok: cases.every((item) => item.ok)
    };
    writeFileSync(join(outDir, 'public-persona-summary.json'), JSON.stringify(summary, null, 2));
    return summary;
  } finally {
    try {
      hdc(['shell', 'aa', 'force-stop', 'com.jiuwen.appless']);
      clearHilog();
      hdc(['shell', 'rm', '-f', '/data/local/tmp/aiphone-smoke-layout.json', '/data/local/tmp/aiphone-smoke-screen.png']);
    } catch (error) {
      console.warn(`Could not finalize public persona smoke process cleanup: ${error instanceof Error ? error.message : String(error)}`);
    }
  }
}

console.log(`cleanData: ${cleanData ? 'true' : 'false'}`);

if (runPublicPersona) {
  const summary = await runPublicPersonaSmoke();
  console.log(JSON.stringify(summary, null, 2));
  process.exit(summary.ok ? 0 : 1);
}

if (runComposioAuthCases) {
  const summary = await runComposioAuthSmoke();
  console.log(JSON.stringify(summary, null, 2));
  if (!summary.ok) {
    process.exit(1);
  }
  if (!runComposioCases && queryArgs.length === 0) {
    process.exit(0);
  }
}
if (runBimSmoke) {
  const summary = await runBimDeviceSmoke();
  console.log(JSON.stringify(summary, null, 2));
  console.log(`screenshotIndex: ${writeScreenshotIndex()}`);
  if (!summary.ok) process.exit(1);
  process.exit(0);
}
const modelHealth = await ensureLocalModel();
console.log(`modelHealth: ${JSON.stringify(modelHealth, null, 2)}`);

const summaries = [];
let c19CreateSucceeded = true;
let c19UpdateSucceeded = true;
let c19CleanupRequired = false;
const c19Requested = useDefaultCases && selectedDefaultCases.some((testCase) => /^C19/.test(testCase.id || ''));
let c11CleanupRequired = false;
const c11Requested = useDefaultCases && selectedDefaultCases.some((testCase) => /^C11/.test(testCase.id || ''));
try {
for (let index = 0; index < queries.length; index += 1) {
  const query = queries[index];
  console.log(`\n[${index + 1}/${queries.length}] ${query}`);
  const inferredCase = useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query);
  if (inferredCase.blockedWithoutWhatsAppTestTo === true && whatsappTestTo.length === 0) {
    const blockedSummary = {
      caseId: inferredCase.id || '',
      query,
      expectedTool: inferredCase.expectsTool,
      expectedToolId: inferredCase.expectedToolId || '',
      status: 'BLOCKED',
      ok: false,
      reason: 'AIPHONE_WHATSAPP_TEST_TO is missing; no recipient was guessed and no message action was opened.'
    };
    summaries.push(blockedSummary);
    captureBlockedCase(inferredCase.id || `query-${index + 1}`, 1, blockedSummary);
    console.log(JSON.stringify(blockedSummary, null, 2));
    continue;
  }
  if (inferredCase.verifyComposioSettings === true) {
    const settingsSummary = await runComposioAuthSmoke();
    settingsSummary.caseId = inferredCase.id || '';
    settingsSummary.query = inferredCase.query;
    settingsSummary.expectedTool = false;
    settingsSummary.expectedToolId = '';
    settingsSummary.expectedToolIds = [];
    settingsSummary.status = settingsSummary.status || (settingsSummary.ok ? 'PASS' : 'FAIL');
    summaries.push(settingsSummary);
    snapshotCaseArtifacts(
      inferredCase.id || `query-${index + 1}`,
      1,
      ['composio-auth', 'external-auth'],
      settingsSummary
    );
    console.log(JSON.stringify(settingsSummary, null, 2));
    continue;
  }
  if (inferredCase.verifyDeepSearch === true) {
    const deepSearchSummary = await runDeepSearchSmoke(inferredCase, index);
    summaries.push(deepSearchSummary);
    snapshotCaseArtifacts(
      inferredCase.id || `query-${index + 1}`,
      1,
      [`query-${index + 1}-deepsearch`],
      deepSearchSummary
    );
    console.log(JSON.stringify(deepSearchSummary, null, 2));
    continue;
  }
  const blockedC19Write = (['C19c', 'C19d', 'C19e'].includes(inferredCase.id || '') && !c19CreateSucceeded) ||
    (['C19d', 'C19e'].includes(inferredCase.id || '') && !c19UpdateSucceeded);
  if (blockedC19Write) {
    const reason = !c19CreateSucceeded ?
      'C19 create did not produce a real provider Event ID; later C19 writes were not attempted.' :
      'C19 update did not produce a real provider Event ID; later C19 writes were not attempted.';
    const blockedSummary = {
      caseId: inferredCase.id || '',
      query,
      expectedTool: inferredCase.expectsTool,
      expectedToolId: inferredCase.expectedToolId || '',
      status: 'BLOCKED',
      ok: false,
      reason
    };
    summaries.push(blockedSummary);
    captureBlockedCase(inferredCase.id || `query-${index + 1}`, 1, blockedSummary);
    console.log(JSON.stringify(blockedSummary, null, 2));
    continue;
  }
  const expectedTool = inferredCase.expectsTool;
  const previousCase = index > 0 ?
    (useDefaultCases ? selectedDefaultCases[index - 1] : expectedCaseForQuery(queries[index - 1])) : null;
  const preserveC11Session = /^C11[b-e]$/.test(inferredCase.id || '') &&
    /^C11[a-d]$/.test(previousCase?.id || '');
  const preserveAppSession = preserveC11Session || shouldPreserveSmokeAppSession(
    inferredCase,
    previousCase,
    summaries.at(-1) || null
  );
  const caseRetryLimit = inferredCase.retryLimit ?? queryRetryLimit;
  let summary = null;
  for (let attempt = 0; attempt <= caseRetryLimit; attempt += 1) {
    summary = await runQuery(query, index, expectedTool, inferredCase, preserveAppSession);
    summary.attempt = attempt + 1;
    summary.retryLimit = caseRetryLimit;
    snapshotCaseArtifacts(
      inferredCase.id || `query-${index + 1}`,
      attempt + 1,
      [`query-${index + 1}`],
      summary
    );
    const missingScrolledMarkers = Array.isArray(summary.layoutScrolledRequiredMarkers) &&
      Array.isArray(summary.layoutScrolledFoundMarkers) &&
      summary.layoutScrolledRequiredMarkers.some((marker) => !summary.layoutScrolledFoundMarkers.includes(marker));
    const retryableFailure = summary.providerFailed || summary.modelFailed || missingScrolledMarkers;
    if (summary.ok || summary.allowsCorrelatedDynamicAuth || !retryableFailure || attempt === caseRetryLimit) {
      break;
    }
    console.warn(`retryable failure for query ${index + 1}, retrying attempt ${attempt + 2}/${caseRetryLimit + 1}`);
  }
  if (summary === null) {
    throw new Error(`No summary produced for query: ${query}`);
  }
  summary.status = summary.ok ? 'PASS' : (summary.allowsCorrelatedDynamicAuth ? 'BLOCKED' :
    (summary.providerFailed ? 'BLOCKED' : 'FAIL'));
  summaries.push(summary);
  console.log(JSON.stringify(summary, null, 2));
  if (inferredCase.id === 'C19b') {
    c19CreateSucceeded = summary.calendarCreateAction?.ok === true;
    c19CleanupRequired = c19CreateSucceeded;
  }
  if (inferredCase.id === 'C19c') {
    c19UpdateSucceeded = summary.calendarUpdateAction?.ok === true;
  }
  if (inferredCase.id === 'C19e' && summary.calendarDeleteAction?.ok === true) {
    c19CleanupRequired = false;
  }
  if (inferredCase.id === 'C11b' && summary.leaderMemoryTool?.ok === true) {
    c11CleanupRequired = true;
  }
  if (inferredCase.id === 'C11d' && summary.leaderMemoryTool?.ok === true) {
    c11CleanupRequired = false;
  }
}
} finally {
  if (c19Requested) {
    const cleanupDelete = coreRegressionCases.find((testCase) => testCase.id === 'C19e');
    const cleanupAbsence = coreRegressionCases.find((testCase) => testCase.id === 'C19f');
    const finalizer = await runC19CleanupFinalizer({
      cleanupRequired: c19CleanupRequired && cleanupDelete !== undefined,
      runDelete: async () => {
        if (cleanupDelete === undefined) throw new Error('C19 cleanup delete case missing');
        const cleanup = await runQuery(cleanupDelete.query, queries.length, cleanupDelete.expectsTool, cleanupDelete);
        cleanup.caseId = 'C19e-cleanup';
        cleanup.status = cleanup.ok ? 'PASS' : (cleanup.providerFailed ? 'BLOCKED' : 'FAIL');
        snapshotCaseArtifacts(cleanup.caseId, 1, [`query-${queries.length + 1}`], cleanup);
        return cleanup;
      },
      runAbsence: async () => {
        if (cleanupAbsence === undefined) throw new Error('C19 final absence case missing');
        const absence = await runQuery(cleanupAbsence.query, queries.length + 1, cleanupAbsence.expectsTool, cleanupAbsence);
        absence.caseId = 'C19f-final-cleanup';
        absence.status = absence.ok ? 'PASS' : (absence.providerFailed ? 'BLOCKED' : 'FAIL');
        snapshotCaseArtifacts(absence.caseId, 1, [`query-${queries.length + 2}`], absence);
        return absence;
      }
    });
    if (finalizer.cleanup.skipped !== true) {
      summaries.push(finalizer.cleanup);
      c19CleanupRequired = finalizer.cleanup.calendarDeleteAction?.ok !== true;
      console.log(JSON.stringify(finalizer.cleanup, null, 2));
    }
    if (finalizer.absence !== undefined) {
      summaries.push(finalizer.absence);
      console.log(JSON.stringify(finalizer.absence, null, 2));
    }
  }
  if (c11Requested && c11CleanupRequired) {
    const cleanupCase = coreRegressionCases.find((testCase) => testCase.id === 'C11d');
    if (cleanupCase !== undefined) {
      try {
        const cleanup = await runQuery(
          cleanupCase.query, queries.length + 2, cleanupCase.expectsTool, cleanupCase, true
        );
        cleanup.caseId = 'C11d-cleanup';
        cleanup.status = cleanup.ok ? 'PASS' : 'FAIL';
        summaries.push(cleanup);
        snapshotCaseArtifacts(cleanup.caseId, 1, [`query-${queries.length + 3}`], cleanup);
        c11CleanupRequired = cleanup.leaderMemoryTool?.ok !== true;
        console.log(JSON.stringify(cleanup, null, 2));
      } catch (error) {
        const cleanup = {
          caseId: 'C11d-cleanup', status: 'FAIL', ok: false,
          reason: error instanceof Error ? error.message : String(error)
        };
        summaries.push(cleanup);
        console.log(JSON.stringify(cleanup, null, 2));
      }
    }
  }
}

const finalLayout = dumpLayout('final-layout.json');
const finalScreenPath = captureScreen('final-screen.png');
const finalLayoutTextValues = collectLayoutText(finalLayout);
const finalLayoutText = finalLayoutTextValues.join('\n');
const finalLayoutTextPath = join(outDir, 'final-layout-text.txt');
writeFileSync(finalLayoutTextPath, finalLayoutText + '\n');
const finalLayoutDomainHits = visibleDomainMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutSyntheticHits = forbiddenSyntheticMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutForbiddenActionHits = forbiddenLayoutActionMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalQuery = queries.length > 0 ? queries[queries.length - 1] : '';
const finalAllowsPartialTravel = /出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(finalQuery);
const finalSummary = summaries.length > 0 ? summaries[summaries.length - 1] : null;
const finalAllowsLeaderMemoryText = finalSummary !== null && finalSummary.leaderMemoryTool?.ok === true;
const finalAllowsExternalGmailWeb = isGmailWebQuery(finalQuery) &&
  finalSummary !== null &&
  finalSummary.gmailWebOpened === true;
const finalAllowsCorrelatedDynamicAuth =
  finalSummary !== null &&
  finalSummary.allowsCorrelatedDynamicAuth === true;
const finalAllowsSocialHubTruthfulState =
  finalSummary !== null &&
  isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
  hasVisibleSocialHubOutput(finalLayoutText, finalSummary.expectedToolId);
const finalAllowsAggregateMailProviderFailure =
  finalSummary !== null &&
  finalSummary.expectedToolId === 'mail.search' &&
  finalSummary.mailAggregateVisible === true;
const finalAggregateMediaVisibleOutput =
  finalSummary !== null &&
  finalSummary.expectedToolId === 'media.aggregate.search' &&
  hasVisibleAggregateMediaOutput(finalLayoutText);
const finalDailyBriefVisibleOutput =
  finalSummary !== null &&
  finalSummary.expectedToolId === 'daily.brief.open' &&
  finalSummary.dailyBriefDirectEvidence?.ok === true;
const finalAllowsSourceFailure =
  finalAllowsPartialTravel &&
  finalSummary !== null &&
  finalSummary.expectedToolId === 'travel.search' &&
  finalSummary.toolOk === true &&
  (finalLayoutText.includes('来源状态') || finalLayoutText.includes('飞常准')) &&
  finalLayoutText.includes('耗时');
const finalLayoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
  if (finalAllowsCorrelatedDynamicAuth &&
    (marker === '需要供应商配置' || marker === '需要配置：')) {
    return false;
  }
  if (finalAllowsPartialTravel && (marker === '需要供应商配置' || marker === '需要配置：')) {
    return false;
  }
  if (finalAllowsSourceFailure && marker === '查询失败') {
    return false;
  }
  if (finalAllowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
    return false;
  }
  if (finalAggregateMediaVisibleOutput && aggregateMediaTruthfulBlockingMarkers.includes(marker)) {
    return false;
  }
  if (finalDailyBriefVisibleOutput && dailyBriefTruthfulStateMarkers.includes(marker)) {
    return false;
  }
  if (finalAllowsAggregateMailProviderFailure && /^(Gmail|QQ)/.test(marker)) {
    return false;
  }
  return finalLayoutText.includes(marker);
});
if (finalSummary !== null && finalSummary.expectedToolId === 'gmail.mail.search' && hasTechnicalGmailArgsCard(finalLayoutText)) {
  finalLayoutBlockingHits.push('gmail-technical-args-card');
}
const allowsVisibleDate = finalSummary !== null &&
  (finalSummary.expectedToolId.startsWith('calendar.') || finalSummary.expectedToolId.startsWith('hotel.') ||
    (finalSummary.expectedToolId === 'dynamic.search' &&
      finalSummary.expectedDiscoveredToolId === 'weather.query' && finalLayoutText.includes('高德天气')));
if (finalSummary !== null && finalSummary.expectedToolId === 'daily.brief.open') {
  finalLayoutBlockingHits.push(...(finalSummary.dailyBriefDateBlockingHits || ['daily-brief-date']));
} else if (!allowsVisibleDate) {
  finalLayoutBlockingHits.push(...finalVisibleDateBlockingHits(
    finalLayoutText,
    finalSummary?.expectedToolId || ''
  ));
}
if (finalSummary !== null && finalSummary.expectedToolId === 'gmail.draft.create') {
  for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
    if (blockingPattern.pattern.test(finalLayoutText)) {
      finalLayoutBlockingHits.push(blockingPattern.name);
    }
  }
}
const finalLayoutRouteHits = finalLayoutRouteMarkers.filter((marker) => finalLayoutText.includes(marker));
const hilogProcesses = activeHilogProcesses();
const finalExpectsDirectText = finalSummary !== null && finalSummary.expectedTool === false;
let finalDirectTextVisible = {
  ok: false, replyChars: 0, baselineMessageCount: 0, finalMessageCount: 0,
  failures: ['not_direct_text'], skipped: true
};
if (finalExpectsDirectText && typeof finalSummary.logPath === 'string' &&
  typeof finalSummary.directTextBaselineLayoutPath === 'string') {
  try {
    const evidence = directTextVisibleEvidence(
      readFileSync(finalSummary.logPath, 'utf8'),
      JSON.parse(readFileSync(finalSummary.directTextBaselineLayoutPath, 'utf8')),
      finalLayout,
      finalQuery,
      {
        conversationId: finalSummary.multiAgentLifecycle?.conversationId || '',
        turnId: finalSummary.multiAgentLifecycle?.turnId || '',
        expectedToolIds: finalSummary.expectedToolIds || []
      }
    );
    finalDirectTextVisible = {
      ok: evidence.ok,
      replyChars: evidence.replyChars,
      baselineMessageCount: evidence.baselineMessageCount,
      finalMessageCount: evidence.finalMessageCount,
      failures: evidence.failures,
      skipped: false
    };
  } catch (_error) {
    finalDirectTextVisible = {
      ok: false, replyChars: 0, baselineMessageCount: 0, finalMessageCount: 0,
      failures: ['direct_text_baseline_unavailable'], skipped: false
    };
  }
}
const finalMemoryCapability = finalSummary?.expectedLeaderMemoryCapability || '';
const finalMemoryReplyPattern = finalMemoryCapability === 'memory.remember' ?
  /已记住\s*\d+\s*条长期记忆/ :
  (finalMemoryCapability === 'memory.update' ? /已更新长期记忆/ :
    (finalMemoryCapability === 'memory.forget' ? /已忘记这条长期记忆/ : null));
const finalMemoryReplyVisible = finalMemoryReplyPattern !== null && finalMemoryReplyPattern.test(finalLayoutText);
const finalMemorySelectionVisibleOutput = finalSummary?.memoryForgetSelection?.ok === true;
if (finalAllowsLeaderMemoryText && finalMemoryReplyVisible) {
  finalDirectTextVisible = {
    ok: true,
    replyChars: 1,
    baselineMessageCount: finalDirectTextVisible.baselineMessageCount,
    finalMessageCount: finalDirectTextVisible.finalMessageCount,
    failures: [],
    skipped: false
  };
}
const finalOutputPresent = finalMemorySelectionVisibleOutput ? true : finalExpectsDirectText ? finalDirectTextVisible.ok :
  (finalAllowsCorrelatedDynamicAuth || finalAllowsSocialHubTruthfulState ||
    finalAllowsExternalGmailWeb || finalAllowsLeaderMemoryText || finalDailyBriefVisibleOutput ||
    finalLayoutDomainHits.length > 0 ||
    (finalSummary !== null &&
      !isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
      finalSummary.htmlHomeDocument !== undefined &&
      finalSummary.htmlHomeDocument.ok === true));
const visibleOutput = {
  layoutPath: join(outDir, 'final-layout.json'),
  screenPath: finalScreenPath,
  textPath: finalLayoutTextPath,
  domainHits: finalLayoutDomainHits,
  routeHits: finalLayoutRouteHits,
  syntheticHits: finalLayoutSyntheticHits,
  forbiddenActionHits: finalLayoutForbiddenActionHits,
  blockingHits: finalLayoutBlockingHits,
  directTextVisible: finalDirectTextVisible,
  ok: finalOutputPresent &&
    finalLayoutSyntheticHits.length === 0 &&
    finalLayoutForbiddenActionHits.length === 0 &&
    finalLayoutBlockingHits.length === 0
};
const processCleanup = {
  activeHilogProcesses: hilogProcesses,
  ok: hilogProcesses.length === 0
};

const summaryPath = join(outDir, 'summary.json');
const screenshotIndexPath = writeScreenshotIndex();
writeFileSync(summaryPath, JSON.stringify({
  target,
  expectedDeviceLocalDate,
  timeoutMs,
  cleanData,
  modelHealth,
  memoryCleanup: { required: c11CleanupRequired, ok: !c11CleanupRequired },
  summaries,
  visibleOutput,
  processCleanup
}, null, 2));
console.log(`\nsummary: ${summaryPath}`);
console.log(`screenshots: ${screenshotIndexPath}`);
console.log(`memoryCleanup: ${JSON.stringify({ required: c11CleanupRequired, ok: !c11CleanupRequired }, null, 2)}`);
console.log(`visibleOutput: ${JSON.stringify(visibleOutput, null, 2)}`);
console.log(`processCleanup: ${JSON.stringify(processCleanup, null, 2)}`);
const failed = summaries.filter((summary) => !summary.ok);
process.exitCode = failed.length === 0 && !c11CleanupRequired && visibleOutput.ok && processCleanup.ok ? 0 : 1;
