import { describe, expect, it } from '@ohos/hypium';
import { A2uiAction, WaterfallFeedState, WaterfallRankedCandidate } from '@loop/agent-core';
import { createDailyBriefSurface, defaultDailyBriefPreference } from
  '../main/ets/pages/A2uiHome/dailybrief/DailyBriefCore';
import {
  parseDailyBriefPreference,
  parseDailyBriefSnapshots,
  replaceDailyBriefSnapshot,
  serializeDailyBriefSnapshots
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefStore';
import {
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceSummary
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefTypes';

interface PoisonedDailyBriefSnapshot extends DailyBriefSnapshot {
  transactionRows: string[];
}

interface PoisonedDailyBriefItem extends DailyBriefItem {
  rawPreview: string;
  mailBody: string;
  healthDetail: string;
}

interface DailyBriefSurfaceModel {
  dailyBrief: DailyBriefSnapshot;
}

function action(id: string, args?: Object): A2uiAction {
  const value: A2uiAction = {
    id: id,
    label: id,
    prompt: id,
    variant: 'secondary',
    kind: 'client'
  };
  if (args !== undefined) value.args = args;
  return value;
}

function item(id: string = 'item-1'): DailyBriefItem {
  return {
    id: id,
    sourceId: 'todo',
    sourceRecordId: id + '-record',
    title: id,
    summary: id + '-summary',
    timeLabel: '09:30',
    startsAt: '2026-08-10T09:30:00+08:00',
    dueAt: '',
    leaveBy: '',
    completed: false,
    needsAction: true,
    severity: 'none'
  };
}

function section(items: DailyBriefItem[] = [item()]): DailyBriefSection {
  return {
    id: 'today',
    title: '今日日程',
    state: 'fixture',
    message: '本地示例待办',
    items: items
  };
}

function source(state: 'success' | 'fixture' | 'empty' | 'needs_auth' | 'error' | 'timeout' = 'fixture'):
  DailyBriefSourceSummary {
  return { sourceId: 'todo', state: state, message: 'source state' };
}

function snapshot(date: string = '2026-08-10', marker: string = 'original'): DailyBriefSnapshot {
  const value = item(marker);
  return {
    schemaVersion: 1,
    date: date,
    generatedAt: date + 'T08:31:00+08:00',
    status: 'complete',
    profile: defaultDailyBriefPreference(),
    topThree: [{ slot: 'action_needed', item: value }],
    sections: [section([value])],
    discovery: [],
    sources: [source()],
    waterfall: null,
    actions: [action('daily.brief.regenerate')]
  };
}

function rankedCandidate(id: string, url: string): WaterfallRankedCandidate {
  return {
    id: id,
    source: 'hackernews',
    mediaType: 'post',
    title: id + ' title',
    summary: id + ' summary',
    url: url,
    coverUrl: '',
    publishedAt: '2026-08-10T00:00:00Z',
    originalIndex: 0,
    normalizedUrl: url,
    signals: {
      relevanceTier: 2,
      titleHits: 0,
      summaryHits: 0,
      freshnessTier: 4
    },
    reason: '来自 hackernews 的内容'
  };
}

function waterfall(candidate: WaterfallRankedCandidate): WaterfallFeedState {
  return {
    query: 'HarmonyOS Agent',
    enabledSources: ['hackernews'],
    preferenceDescription: '中文优先',
    shown: [],
    current: candidate,
    stable: [],
    tail: [],
    sources: []
  };
}

function parsedSnapshots(values: DailyBriefSnapshot[]): DailyBriefSnapshot[] {
  return parseDailyBriefSnapshots(JSON.stringify(values));
}

export default function dailyBriefStoreTest() {
  describe('DailyBriefStore', () => {
    it('returns safe defaults for corrupted persisted JSON', 0, () => {
      const preference = parseDailyBriefPreference('{');

      expect(JSON.stringify(preference)).assertEqual(JSON.stringify(defaultDailyBriefPreference()));
      expect(parseDailyBriefSnapshots('{').length).assertEqual(0);
      expect(parseDailyBriefSnapshots('{}').length).assertEqual(0);
    });

    it('rejects invalid preference limits and target time', 0, () => {
      const valid = defaultDailyBriefPreference();
      const invalidTime = defaultDailyBriefPreference();
      invalidTime.targetTime = '24:00';
      const tooManyTopics = defaultDailyBriefPreference();
      tooManyTopics.topics = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const oversizedTopic = defaultDailyBriefPreference();
      oversizedTopic.topics = ['x'.repeat(41)];

      expect(JSON.stringify(parseDailyBriefPreference(JSON.stringify(valid))))
        .assertEqual(JSON.stringify(valid));
      expect(JSON.stringify(parseDailyBriefPreference(JSON.stringify(invalidTime))))
        .assertEqual(JSON.stringify(defaultDailyBriefPreference()));
      expect(JSON.stringify(parseDailyBriefPreference(JSON.stringify(tooManyTopics))))
        .assertEqual(JSON.stringify(defaultDailyBriefPreference()));
      expect(JSON.stringify(parseDailyBriefPreference(JSON.stringify(oversizedTopic))))
        .assertEqual(JSON.stringify(defaultDailyBriefPreference()));
    });

    it('rejects invalid schema date source state section cap and oversized strings', 0, () => {
      const invalidSchema = snapshot();
      const invalidDate = snapshot('2026-02-30');
      const invalidState = snapshot();
      const invalidSection = snapshot();
      const tooManyItems = snapshot();
      const oversized = snapshot();
      invalidSchema.schemaVersion = 2 as 1;
      invalidState.sources = [{ sourceId: 'todo', state: 'unknown' as 'error', message: '' }];
      invalidSection.sections[0].id = 'other' as 'today';
      tooManyItems.sections[0].items = [];
      for (let index = 0; index < 21; index += 1) {
        tooManyItems.sections[0].items.push(item('item-' + index.toString()));
      }
      oversized.sections[0].items[0].summary = 'x'.repeat(4097);

      expect(parsedSnapshots([invalidSchema]).length).assertEqual(0);
      expect(parsedSnapshots([invalidDate]).length).assertEqual(0);
      expect(parsedSnapshots([invalidState]).length).assertEqual(0);
      expect(parsedSnapshots([invalidSection]).length).assertEqual(0);
      expect(parsedSnapshots([tooManyItems]).length).assertEqual(0);
      expect(parsedSnapshots([oversized]).length).assertEqual(0);
    });

    it('rejects unsupported and malformed persisted actions', 0, () => {
      const unsupported = snapshot();
      unsupported.actions = [action('custom.action')];
      const forgedHistory = snapshot();
      forgedHistory.actions = [action('daily.brief.history.open',
        JSON.parse('{"direction":"today","url":"https://evil.example"}') as Object)];
      const invalidHistory = snapshot();
      invalidHistory.actions = [action('daily.brief.history.open',
        JSON.parse('{"direction":"later"}') as Object)];
      const forgedMail = snapshot();
      forgedMail.actions = [action('daily.brief.mail.read', JSON.parse(
        '{"provider":"gmail","threadId":"thread-1","messageId":"","requestKey":"request-1",' +
          '"rawPreview":"private"}') as Object)];

      expect(parsedSnapshots([unsupported]).length).assertEqual(0);
      expect(parsedSnapshots([forgedHistory]).length).assertEqual(0);
      expect(parsedSnapshots([invalidHistory]).length).assertEqual(0);
      expect(parsedSnapshots([forgedMail]).length).assertEqual(0);
    });

    it('accepts only http discovery records projected from the frozen Waterfall', 0, () => {
      const valid = snapshot();
      const candidate = rankedCandidate('story-1', 'https://example.com/story');
      valid.waterfall = waterfall(candidate);
      valid.discovery = [{
        id: candidate.id,
        source: candidate.source,
        mediaType: candidate.mediaType,
        title: candidate.title,
        summary: candidate.summary,
        url: candidate.url,
        reason: candidate.reason,
        timeBudgetLabel: '3 分钟'
      }];
      const unsafeUrl = JSON.parse(JSON.stringify(valid)) as DailyBriefSnapshot;
      unsafeUrl.discovery[0].url = 'javascript:alert(1)';
      const forgedProjection = JSON.parse(JSON.stringify(valid)) as DailyBriefSnapshot;
      forgedProjection.discovery[0].url = 'https://evil.example/story';

      expect(parsedSnapshots([valid]).length).assertEqual(1);
      expect(parsedSnapshots([unsafeUrl]).length).assertEqual(0);
      expect(parsedSnapshots([forgedProjection]).length).assertEqual(0);
    });

    it('preserves validated direct video media URLs through snapshot storage', 0, () => {
      const valid = snapshot();
      const candidate = rankedCandidate('video-1', 'https://reddit.com/r/demo');
      candidate.mediaType = 'video';
      candidate.source = 'reddit';
      candidate.mediaUrl = 'https://v.redd.it/demo/DASH_720.mp4';
      valid.waterfall = waterfall(candidate);

      const parsed = parsedSnapshots([valid]);

      expect(parsed.length).assertEqual(1);
      expect(parsed[0].waterfall?.current?.mediaUrl ?? '').assertEqual('https://v.redd.it/demo/DASH_720.mp4');
    });

    it('accepts discovery projected from a shown-only frozen Waterfall', 0, () => {
      const valid = snapshot();
      const candidate = rankedCandidate('shown-story', 'https://example.com/shown');
      valid.waterfall = waterfall(candidate);
      valid.waterfall.current = null;
      valid.waterfall.shown = [candidate];
      valid.discovery = [{
        id: candidate.id,
        source: candidate.source,
        mediaType: candidate.mediaType,
        title: candidate.title,
        summary: candidate.summary,
        url: candidate.url,
        reason: candidate.reason,
        timeBudgetLabel: '3 分钟'
      }];

      expect(parsedSnapshots([valid]).length).assertEqual(1);
    });

    it('replaces only the matching date without mutating caller snapshots', 0, () => {
      const first = snapshot('2026-08-09', 'old-first');
      const second = snapshot('2026-08-10', 'old-second');
      const replacement = snapshot('2026-08-09', 'new-first');
      const beforeFirst = JSON.stringify(first);
      const beforeSecond = JSON.stringify(second);
      const beforeReplacement = JSON.stringify(replacement);

      const result = replaceDailyBriefSnapshot([first, second], replacement);

      expect(result.length).assertEqual(2);
      expect(result[0].topThree[0].item.id).assertEqual('new-first');
      expect(JSON.stringify(result[1])).assertEqual(beforeSecond);
      expect(JSON.stringify(first)).assertEqual(beforeFirst);
      expect(JSON.stringify(second)).assertEqual(beforeSecond);
      expect(JSON.stringify(replacement)).assertEqual(beforeReplacement);
    });

    it('keeps the old date when its replacement is invalid', 0, () => {
      const old = snapshot('2026-08-09', 'old');
      const invalid = snapshot('2026-08-09', 'invalid');
      invalid.actions = [action('custom.action')];

      const result = replaceDailyBriefSnapshot([old], invalid);

      expect(result.length).assertEqual(1);
      expect(result[0].topThree[0].item.id).assertEqual('old');
    });

    it('retains the newest seven dates in deterministic ascending order', 0, () => {
      let values: DailyBriefSnapshot[] = [];
      const dates: string[] = [
        '2026-08-08', '2026-08-01', '2026-08-06', '2026-08-03',
        '2026-08-10', '2026-08-02', '2026-08-09', '2026-08-04'
      ];
      for (let index = 0; index < dates.length; index += 1) {
        values = replaceDailyBriefSnapshot(values, snapshot(dates[index], dates[index]));
      }

      expect(values.map((value: DailyBriefSnapshot): string => value.date).join(','))
        .assertEqual('2026-08-02,2026-08-03,2026-08-04,2026-08-06,2026-08-08,2026-08-09,2026-08-10');
    });

    it('preserves canonical frozen snapshots byte for byte except date ordering', 0, () => {
      const older = snapshot('2026-08-09', 'older');
      older.actions = [
        action('daily.brief.history.open', JSON.parse('{"direction":"previous"}') as Object),
        action('daily.brief.mail.read', JSON.parse(
          '{"provider":"gmail","threadId":"thread-1","messageId":"","requestKey":"request-1"}') as Object)
      ];
      const newer = snapshot('2026-08-10', 'newer');
      const expected = JSON.stringify([older, newer]);

      const serialized = serializeDailyBriefSnapshots(
        parseDailyBriefSnapshots(JSON.stringify([newer, older]))
      );

      expect(serialized).assertEqual(expected);
    });

    it('keeps historical unsupported mail content but removes its dead surface actions', 0, () => {
      const historical = snapshot('2026-08-09', 'historical');
      const outlook = item('historical-outlook');
      outlook.sourceId = 'mail';
      outlook.action = action('daily.brief.mail.read', JSON.parse(
        '{"provider":"outlook","threadId":"outlook-thread","messageId":"outlook-message",' +
          '"requestKey":"outlook:outlook-message"}'
      ) as Object);
      const gmail = item('historical-gmail-thread-only');
      gmail.sourceId = 'mail';
      gmail.action = action('daily.brief.mail.read', JSON.parse(
        '{"provider":"gmail","threadId":"gmail-thread","messageId":"",' +
          '"requestKey":"gmail:gmail-thread"}'
      ) as Object);
      const qq = item('historical-qq-invalid');
      qq.sourceId = 'mail';
      qq.action = action('daily.brief.mail.read', JSON.parse(
        '{"provider":"qq","threadId":"","messageId":"not-numeric",' +
          '"requestKey":"qq:not-numeric"}'
      ) as Object);
      historical.topThree = [];
      historical.sections = [{
        id: 'mail', title: '重要邮件', state: 'success', message: '', items: [outlook, gmail, qq]
      }];
      historical.actions = [
        outlook.action as A2uiAction,
        gmail.action as A2uiAction,
        qq.action as A2uiAction
      ];

      const loaded = parseDailyBriefSnapshots(JSON.stringify([historical]));
      expect(loaded.length).assertEqual(1);
      const loadedBefore = JSON.stringify(loaded[0]);
      const surface = createDailyBriefSurface(loaded[0]);
      const model = JSON.parse(surface.dataModelJson) as DailyBriefSurfaceModel;

      expect(model.dailyBrief.sections[0].items.length).assertEqual(3);
      expect(surface.dataModelJson.indexOf('historical-outlook')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('historical-gmail-thread-only')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('historical-qq-invalid')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('daily.brief.mail.read')).assertEqual(-1);
      expect(JSON.stringify(loaded[0])).assertEqual(loadedBefore);
    });

    it('strips raw sensitive keys from persisted JSON without mutating the caller', 0, () => {
      const value = snapshot() as PoisonedDailyBriefSnapshot;
      const poisoned = value.sections[0].items[0] as PoisonedDailyBriefItem;
      poisoned.rawPreview = 'private-preview';
      poisoned.mailBody = 'private-mail-body';
      poisoned.healthDetail = 'private-health-detail';
      value.transactionRows = ['private-transaction'];

      const serialized = serializeDailyBriefSnapshots([value]);

      expect(serialized.indexOf('rawPreview')).assertEqual(-1);
      expect(serialized.indexOf('mailBody')).assertEqual(-1);
      expect(serialized.indexOf('healthDetail')).assertEqual(-1);
      expect(serialized.indexOf('transactionRows')).assertEqual(-1);
      expect(value.transactionRows[0]).assertEqual('private-transaction');
    });
  });
}
