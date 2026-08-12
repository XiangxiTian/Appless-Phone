import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import { A2uiSurfaceState, LocalModel } from '@loop/agent-core';
import {
  BimLifecycleState,
  BimRecord,
  BimStore
} from '../main/ets/pages/A2uiHome/bim/BimStore';
import {
  BimLoadedContext,
  BimAttentionEvent,
  BimCuratorResult,
  BimSkill,
  BimTurnEvidence,
  bimDetailSubmitError,
  buildBimSnapshotPrompt,
  buildBimAttentionPrompt,
  buildBimForegroundRequest,
  originalQueryFromBimPrompt,
  runBimCurator,
  runBimSentinel,
  bimAttentionVisibleText,
  safeBimToolResultSummary
} from '../main/ets/pages/A2uiHome/bim/BimRuntime';

class SequentialModel implements LocalModel {
  calls: number = 0;
  prompts: string[] = [];
  private readonly values: string[];

  constructor(values: string[]) {
    this.values = values;
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    const value = this.values[Math.min(this.calls, this.values.length - 1)];
    this.calls++;
    return value;
  }
}

class DashboardRepairModel implements LocalModel {
  calls: number = 0;
  prompts: string[] = [];
  private readonly invalidUpdate: string;
  private readonly validUpdate: string;

  constructor(invalidUpdate: string, validUpdate: string) {
    this.invalidUpdate = invalidUpdate;
    this.validUpdate = validUpdate;
  }

  async complete(prompt: string): Promise<string> {
    this.prompts.push(prompt);
    this.calls++;
    if (this.calls === 1) return '{"loadBimIds":["bim-expo"]}';
    return prompt.indexOf('Each dashboard item has exactly kind, title, value, detail, status') >= 0 ?
      this.validUpdate : this.invalidUpdate;
  }
}

class RuntimeMemoryPreferences {
  private readonly values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  flushSync(): void {}
}

function runtimeStoreWith(records: BimRecord[]): BimStore {
  const native = new RuntimeMemoryPreferences() as Object as preferences.Preferences;
  const store = new BimStore(native);
  records.forEach((item: BimRecord): void => { store.create(item); });
  return store;
}

function runtimeRecord(
  id: string,
  title: string,
  lifecycle: BimLifecycleState = 'active',
  lastInteractionAt: string = '2026-08-03T10:00:00+08:00',
  contextMarker: string = title
): BimRecord {
  const surface: A2uiSurfaceState = {
    surfaceId: 'surface-' + id,
    rootId: 'root',
    title,
    intent: 'travel',
    status: 'ready',
    components: [{ id: 'root', component: 'SurfaceRoot' }],
    dataModelJson: '{}',
    error: '',
    sequence: 1
  };
  return {
    id,
    title,
    lifecycle,
    createdAt: '2026-08-01T10:00:00+08:00',
    updatedAt: lastInteractionAt,
    lastInteractionAt,
    lastLifecycleCheckAt: '2026-08-01T10:00:00+08:00',
    relatedBimIds: [],
    contextJson: JSON.stringify({
      summary: contextMarker,
      facts: [],
      constraints: [],
      decisions: []
    }),
    retrievalIndex: {
      summary: title,
      entities: [title],
      timeAnchors: [],
      locations: [title.substring(0, 2)],
      commitments: [],
      keywords: [title, '机票']
    },
    surfaceJson: JSON.stringify(surface),
    snapshotVersion: 1,
    snapshotMarkdown: contextMarker,
    fullContextMarkdown: '# ' + title + '\n\n' + contextMarker
  };
}

function evidence(query: string): BimTurnEvidence {
  return {
    query,
    sourceBimId: '',
    visibleSource: '',
    assistantReply: '已处理',
    surfaceSummary: '',
    toolResultSummary: '',
    userConfirmedCompletion: false,
    userConfirmedCreate: false
  };
}

export default function bimRuntimeTest() {
  describe('bimRuntime', () => {
    it('injects every non-ended Snapshot and no Full Context', 0, () => {
      const records = [
        runtimeRecord('active', 'Active'),
        runtimeRecord('quiet', 'Quiet', 'quiet'),
        runtimeRecord('tucked', 'Tucked', 'tucked'),
        runtimeRecord('ended', 'Ended', 'ended')
      ];
      records[0].snapshotMarkdown = 'ACTIVE_SNAPSHOT';
      records[0].fullContextMarkdown = 'FULL_CONTEXT_SECRET';

      const prompt: string = buildBimSnapshotPrompt('帮我看看安排', records);

      expect(prompt.indexOf('[BIM_SNAPSHOTS]')).assertEqual(0);
      expect(prompt.indexOf('ACTIVE_SNAPSHOT')).assertLarger(-1);
      expect(prompt.indexOf('- lifecycle: quiet')).assertLarger(-1);
      expect(prompt.indexOf('- lifecycle: tucked')).assertLarger(-1);
      expect(prompt.indexOf('- lifecycle: ended')).assertEqual(-1);
      expect(prompt.indexOf('FULL_CONTEXT_SECRET')).assertEqual(-1);
      expect(prompt.endsWith('帮我看看安排')).assertTrue();
    });

    it('keeps every valid Snapshot byte in the foreground prompt', 0, () => {
      const records: BimRecord[] = [];
      for (let index = 0; index < 10; index++) {
        const record = runtimeRecord('bim-' + index.toString(), '事项 ' + index.toString());
        record.snapshotMarkdown = index.toString() + ':' + 'x'.repeat(2990) + ':tail-' + index.toString();
        records.push(record);
      }

      const prompt: string = buildBimSnapshotPrompt('继续处理', records);

      expect(prompt.length < 40000).assertTrue();
      expect(prompt.indexOf('- bimId: bim-0')).assertLarger(-1);
      expect(prompt.indexOf('- bimId: bim-9')).assertLarger(-1);
      expect(prompt.indexOf(':tail-0')).assertLarger(-1);
      expect(prompt.indexOf(':tail-9')).assertLarger(-1);
      expect(prompt.indexOf('[Snapshot truncated]')).assertEqual(-1);
      expect(prompt.endsWith('继续处理')).assertTrue();
    });

    it('removes credential metadata from Curator evidence summaries', 0, () => {
      const summary: string = safeBimToolResultSummary(
        'ObservationDigest\ntoolId: dynamic.search\nCredential: dynamic:test:API_KEY\nresult count: 0'
      );

      expect(summary.indexOf('Credential')).assertEqual(-1);
      expect(summary.indexOf('toolId: dynamic.search')).assertLarger(-1);
    });

    it('creates one snapshot-only foreground request with BIM source metadata', 0, () => {
      const request = buildBimForegroundRequest(
        '继续看看酒店', [runtimeRecord('bim-trip', '东京旅行')], 'bim-trip'
      );

      expect(request.prompt.indexOf('[BIM_SNAPSHOTS]')).assertEqual(0);
      expect(request.prompt.indexOf('[BIM_CONTEXT]')).assertEqual(-1);
      expect(request.query).assertEqual('继续看看酒店');
      expect(request.sourceBimId).assertEqual('bim-trip');
      expect(originalQueryFromBimPrompt(request.prompt)).assertEqual('继续看看酒店');
    });

    it('keeps BIM detail input visible when model configuration is missing', 0, () => {
      expect(bimDetailSubmitError('')).assertEqual('请先填写 Base URL。');
      expect(bimDetailSubmitError(' https://example.com/v1 ')).assertEqual('');
    });

    it('loads Full Context only for explicit existing BIM IDs', 0, () => {
      const first = runtimeRecord('bim-a', '事项 A');
      const second = runtimeRecord('bim-b', '事项 B');
      second.fullContextMarkdown = '# 事项 B\n\n完整内容 B';
      const store = runtimeStoreWith([first, second]);

      const loaded: BimLoadedContext[] = new BimSkill(store).load(['bim-b', 'missing', 'bim-b']);

      expect(loaded.length).assertEqual(1);
      expect(loaded[0].id).assertEqual('bim-b');
      expect(loaded[0].fullContextMarkdown).assertEqual('# 事项 B\n\n完整内容 B');
    });

    it('curates a selected BIM with two model calls and one versioned publish', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const model = new SequentialModel([
        '{"loadBimIds":["bim-trip"]}',
        '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
          '"fullContextMarkdown":"# 东京旅行\\n\\n四人同行",' +
          '"snapshotMarkdown":"东京旅行四人同行，酒店尚未预订。",' +
          '"context":{"summary":"四人同行","facts":["同行四人"],' +
          '"constraints":[],"decisions":[],"dashboardItems":[]},' +
          '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],' +
          '"timeAnchors":[],"locations":["东京"],"commitments":[],' +
          '"keywords":["旅行"]},"relatedBimIds":[]}],"creates":[]}'
      ]);

      const result: BimCuratorResult = await runBimCurator(
        store, model, evidence('改成四个人'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.join(',')).assertEqual('bim-trip');
      expect(store.get('bim-trip')?.snapshotVersion).assertEqual(2);
      expect(store.get('bim-trip')?.snapshotMarkdown)
        .assertEqual('东京旅行四人同行，酒店尚未预订。');
      expect(model.prompts[0].indexOf('# 东京旅行')).assertEqual(-1);
      expect(model.prompts[1].indexOf('# 东京旅行')).assertLarger(-1);
    });

    it('publishes one complete next version from a natural exhibition change', 0, async () => {
      const store = runtimeStoreWith([
        runtimeRecord(
          'bim-expo', '上海展会计划', 'active',
          '2026-08-12T10:00:00+08:00',
          '计划：下个月去上海参加展会；状态：待跟进准备。'
        )
      ]);
      const validUpdate = '{"updates":[{"bimId":"bim-expo","expectedVersion":1,"title":"杭州展会计划",' +
          '"fullContextMarkdown":"# 杭州展会计划\\n\\n展会地点改为杭州，日期为2026年8月30日。' +
          '第一阶段报名已完成，下一步确认展位。",' +
          '"snapshotMarkdown":"杭州展会定于2026年8月30日；第一阶段报名已完成；下一步确认展位。",' +
          '"context":{"summary":"杭州展会准备中",' +
          '"facts":["地点：杭州","日期：2026年8月30日"],"constraints":[],' +
          '"decisions":["第一阶段报名已完成"],"dashboardItems":[' +
          '{"kind":"timeline","title":"展会日期","value":"2026年8月30日",' +
          '"detail":"杭州","status":"已确定"},' +
          '{"kind":"progress","title":"报名进度","value":"第一阶段",' +
          '"detail":"报名已完成","status":"已完成"},' +
          '{"kind":"task","title":"下一步","value":"确认展位",' +
          '"detail":"","status":"待处理"}]},' +
          '"retrievalIndex":{"summary":"杭州展会计划",' +
          '"entities":["展会"],"timeAnchors":["2026年8月30日"],' +
          '"locations":["杭州"],"commitments":["确认展位"],' +
          '"keywords":["展会","报名","展位"]},"relatedBimIds":[]}],"creates":[]}';
      const invalidUpdate = validUpdate.replace(
        '"dashboardItems":[{"kind":"timeline","title":"展会日期","value":"2026年8月30日",' +
        '"detail":"杭州","status":"已确定"},{"kind":"progress","title":"报名进度",' +
        '"value":"第一阶段","detail":"报名已完成","status":"已完成"},{"kind":"task",' +
        '"title":"下一步","value":"确认展位","detail":"","status":"待处理"}]',
        '"dashboardItems":[{"type":"date","label":"展会日期","value":"2026年8月30日"}]'
      );
      const model = new DashboardRepairModel(invalidUpdate, validUpdate);

      const result = await runBimCurator(
        store,
        model,
        evidence('展会计划有变，地点改到杭州了，时间是8.30号，第一阶段报名已经完成，下一步就要确认展位了。'),
        '2026-08-12T11:30:00+08:00'
      );

      const updated = store.get('bim-expo');
      expect(result.updatedBimIds.join(',')).assertEqual('bim-expo');
      expect(store.list().length).assertEqual(1);
      expect(updated?.snapshotVersion).assertEqual(2);
      expect(updated?.title).assertEqual('杭州展会计划');
      expect(updated?.snapshotMarkdown.indexOf('2026年8月30日')).assertLarger(-1);
      expect(updated?.fullContextMarkdown.indexOf('确认展位')).assertLarger(-1);
      expect(updated?.fullContextMarkdown.indexOf('上海')).assertEqual(-1);
      expect(updated?.contextJson.indexOf('报名已完成')).assertLarger(-1);
      expect(updated?.contextJson.indexOf('确认展位')).assertLarger(-1);
    });

    it('retries malformed Curator output once and preserves old state', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const model = new SequentialModel([
        '{"loadBimIds":["bim-trip"]}', 'bad', 'bad'
      ]);

      const result: BimCuratorResult = await runBimCurator(
        store, model, evidence('更新行程'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.length).assertEqual(0);
      expect(result.error.length > 0).assertTrue();
      expect(model.calls).assertEqual(3);
      expect(store.get('bim-trip')?.snapshotVersion).assertEqual(1);
    });

    it('retries malformed Curator selection once before loading context', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const update = '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
        '"fullContextMarkdown":"# 东京旅行\\n\\n待确认酒店",' +
        '"snapshotMarkdown":"东京旅行酒店待确认。",' +
        '"context":{"summary":"酒店待确认","facts":[],"constraints":[],"decisions":[],"dashboardItems":[]},' +
        '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],"timeAnchors":[],' +
        '"locations":["东京"],"commitments":[],"keywords":["酒店"]},' +
        '"relatedBimIds":[]}],"creates":[]}';
      const model = new SequentialModel(['bad', '{"loadBimIds":["bim-trip"]}', update]);

      const result = await runBimCurator(
        store, model, evidence('更新酒店安排'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.join(',')).assertEqual('bim-trip');
      expect(model.calls).assertEqual(3);
    });

    it('does not treat a completion question as proof of completion', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const update = '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
        '"fullContextMarkdown":"# 东京旅行\\n\\n已出票",' +
        '"snapshotMarkdown":"东京旅行已出票。",' +
        '"context":{"summary":"已出票","facts":["已出票"],"constraints":[],"decisions":[],"dashboardItems":[]},' +
        '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],"timeAnchors":[],' +
        '"locations":["东京"],"commitments":[],"keywords":["机票"]},' +
        '"relatedBimIds":[]}],"creates":[]}';
      const model = new SequentialModel(['{"loadBimIds":["bim-trip"]}', update]);

      const result = await runBimCurator(
        store, model, evidence('是否已出票？'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.length).assertEqual(0);
      expect(store.get('bim-trip')?.snapshotVersion).assertEqual(1);
    });

    it('does not treat a conditional completion phrase as an assertion', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const update = '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
        '"fullContextMarkdown":"# 东京旅行\\n\\n已出票",' +
        '"snapshotMarkdown":"东京旅行已出票。",' +
        '"context":{"summary":"已出票","facts":["已出票"],"constraints":[],"decisions":[],"dashboardItems":[]},' +
        '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],"timeAnchors":[],' +
        '"locations":["东京"],"commitments":[],"keywords":["机票"]},' +
        '"relatedBimIds":[]}],"creates":[]}';
      const model = new SequentialModel(['{"loadBimIds":["bim-trip"]}', update]);

      const result = await runBimCurator(
        store, model, evidence('如果已出票就提醒我选座'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.length).assertEqual(0);
      expect(store.get('bim-trip')?.snapshotVersion).assertEqual(1);
    });

    it('does not trust free-form completion language without host confirmation', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const update = '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
        '"fullContextMarkdown":"# 东京旅行\\n\\n已出票",' +
        '"snapshotMarkdown":"东京旅行已出票。",' +
        '"context":{"summary":"已出票","facts":["已出票"],"constraints":[],"decisions":[],"dashboardItems":[]},' +
        '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],"timeAnchors":[],' +
        '"locations":["东京"],"commitments":[],"keywords":["机票"]},' +
        '"relatedBimIds":[]}],"creates":[]}';
      const model = new SequentialModel(['{"loadBimIds":["bim-trip"]}', update]);

      const result = await runBimCurator(
        store, model, evidence('已经出票'), '2026-08-10T10:00:00+08:00'
      );

      expect(result.updatedBimIds.length).assertEqual(0);
      expect(store.get('bim-trip')?.snapshotVersion).assertEqual(1);
    });

    it('requires a known successful write receipt rather than matching summary prose', 0, async () => {
      const update = '{"updates":[{"bimId":"bim-trip","expectedVersion":1,"title":"东京旅行",' +
        '"fullContextMarkdown":"# 东京旅行\\n\\n已完成",' +
        '"snapshotMarkdown":"东京旅行已完成。",' +
        '"context":{"summary":"已完成","facts":["已完成"],"constraints":[],"decisions":[],"dashboardItems":[]},' +
        '"retrievalIndex":{"summary":"东京旅行","entities":["东京"],"timeAnchors":[],' +
        '"locations":["东京"],"commitments":[],"keywords":["旅行"]},' +
        '"relatedBimIds":[]}],"creates":[]}';
      const fakeStore = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const fakeEvidence = evidence('更新旅行');
      fakeEvidence.toolResultSummary = '普通摘要提到了已完成';
      const fake = await runBimCurator(
        fakeStore,
        new SequentialModel(['{"loadBimIds":["bim-trip"]}', update]),
        fakeEvidence,
        '2026-08-10T10:00:00+08:00'
      );

      const receiptStore = runtimeStoreWith([runtimeRecord('bim-trip', '东京旅行')]);
      const receiptEvidence = evidence('更新旅行');
      receiptEvidence.toolResultSummary = 'ObservationDigest\ntoolId: calendar.event.create\n' +
        'result 1: 行程 | status=success | summary=已完成';
      const receipt = await runBimCurator(
        receiptStore,
        new SequentialModel(['{"loadBimIds":["bim-trip"]}', update]),
        receiptEvidence,
        '2026-08-10T10:00:00+08:00'
      );

      expect(fake.updatedBimIds.length).assertEqual(0);
      expect(receipt.updatedBimIds.join(',')).assertEqual('bim-trip');
    });

    it('creates a BIM only after host confirmation of an explicit remember request', 0, async () => {
      const createOutput = '{"updates":[],"creates":[{"id":"bim-new","title":"签证办理",' +
        '"fullContextMarkdown":"# 签证办理\\n\\n持续跟进",' +
        '"snapshotMarkdown":"持续跟进签证办理。",' +
        '"context":{"summary":"持续跟进签证办理","facts":[],' +
        '"constraints":[],"decisions":[]},' +
        '"retrievalIndex":{"summary":"签证办理","entities":["签证"],' +
        '"timeAnchors":[],"locations":[],"commitments":["持续跟进"],' +
        '"keywords":["签证"]}}]}';
      const deniedStore = runtimeStoreWith([]);
      const deniedModel = new SequentialModel(['{"loadBimIds":[]}', createOutput]);

      const denied: BimCuratorResult = await runBimCurator(
        deniedStore, deniedModel, evidence('把签证办理记在心上'), '2026-08-10T10:00:00+08:00'
      );

      expect(denied.createdBimIds.length).assertEqual(0);
      expect(deniedStore.list().length).assertEqual(0);
      expect(deniedModel.prompts.length).assertEqual(1);
      const allowedStore = runtimeStoreWith([]);
      const allowedModel = new SequentialModel(['{"loadBimIds":[]}', createOutput]);
      const confirmed = evidence('把签证办理记在心上');
      confirmed.userConfirmedCreate = true;
      const allowed: BimCuratorResult = await runBimCurator(
        allowedStore, allowedModel, confirmed,
        '2026-08-10T10:00:00+08:00'
      );
      expect(allowed.createdBimIds.join(',')).assertEqual('bim-new');
      expect(allowedStore.get('bim-new')?.snapshotMarkdown).assertEqual('持续跟进签证办理。');
      expect(allowedModel.prompts[1].indexOf(
        'context and retrievalIndex MUST be JSON objects, never strings'
      )).assertLarger(-1);
      expect(allowedModel.prompts[1].indexOf(
        'The top-level updates/creates wrapper is mandatory; never return a bare update or create item.'
      )).assertLarger(-1);
      expect(allowedModel.prompts[1].indexOf(
        '{"updates":[{"bimId":"...","expectedVersion":1,"title":"..."'
      )).assertLarger(-1);
      expect(allowedModel.prompts[1].indexOf(
        '"creates":[{"id":"...","title":"..."'
      )).assertLarger(-1);
      expect(allowedModel.prompts[1].indexOf(
        '"context":{"summary":"...","facts":[],"constraints":[],"decisions":[],"dashboardItems":[]}'
      )).assertLarger(-1);
      expect(allowedModel.prompts[1].indexOf(
        '"retrievalIndex":{"summary":"...","entities":[],"timeAnchors":[],"locations":[],' +
        '"commitments":[],"keywords":[]}'
      )).assertLarger(-1);
    });

    it('merges attentions per BIM without modifying stored state', 0, async () => {
      const store = runtimeStoreWith([
        runtimeRecord('bim-a', '东京旅行'),
        runtimeRecord('bim-b', '婚宴宾客')
      ]);
      const model = new SequentialModel([
        '{"loadBimIds":["bim-a","bim-b"]}',
        '{"events":[{"bimId":"bim-a","attentions":["确认酒店"]},' +
          '{"bimId":"bim-a","attentions":["检查航班"]},' +
          '{"bimId":"bim-b","attentions":["确认人数"]}]}'
      ]);

      const events: BimAttentionEvent[] = await runBimSentinel(store, model);

      expect(events.length).assertEqual(2);
      expect(events[0].bimId).assertEqual('bim-a');
      expect(events[0].attentions.join(',')).assertEqual('确认酒店,检查航班');
      expect(events[1].bimId).assertEqual('bim-b');
      expect(store.get('bim-a')?.snapshotVersion).assertEqual(1);
      expect(store.get('bim-b')?.snapshotVersion).assertEqual(1);
      expect(model.prompts[0].indexOf('# 东京旅行')).assertEqual(-1);
      expect(model.prompts[1].indexOf('# 东京旅行')).assertLarger(-1);
    });

    it('accepts the observed Sentinel action format with a unique BIM title', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-a', '东京旅行')]);
      const model = new SequentialModel([
        'Execution: serial\nAction: loadBimIds[["东京旅行"]]',
        '{"events":[]}'
      ]);

      const events: BimAttentionEvent[] = await runBimSentinel(store, model);

      expect(events.length).assertEqual(0);
      expect(model.prompts.length).assertEqual(2);
    });

    it('builds separate visible and hidden Attention Event messages', 0, () => {
      const event: BimAttentionEvent = {
        bimId: 'bim-a',
        title: '东京旅行',
        observedAt: '2026-08-10T09:00:00+08:00',
        attentions: ['确认酒店', '检查航班']
      };

      expect(bimAttentionVisibleText(event)).assertEqual('来自心上事「东京旅行」');
      expect(buildBimAttentionPrompt(event).indexOf(
        '[BIM_ATTENTION]\n{"bimId":"bim-a"'
      )).assertEqual(0);
    });

    it('adds the host observation time to each Attention Event', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-a', '东京旅行')]);
      const model = new SequentialModel([
        '{"loadBimIds":["bim-a"]}',
        '{"events":[{"bimId":"bim-a","attentions":["确认酒店"]}]}'
      ]);

      const events = await runBimSentinel(store, model, '2026-08-10T09:00:00+08:00');

      expect(events[0].observedAt).assertEqual('2026-08-10T09:00:00+08:00');
      expect(buildBimAttentionPrompt(events[0]).indexOf(
        '"observedAt":"2026-08-10T09:00:00+08:00"'
      )).assertLarger(-1);
    });

    it('rejects an oversized Sentinel attention before foreground submission', 0, async () => {
      const store = runtimeStoreWith([runtimeRecord('bim-a', '东京旅行')]);
      const model = new SequentialModel([
        '{"loadBimIds":["bim-a"]}',
        '{"events":[{"bimId":"bim-a","attentions":["' + 'x'.repeat(1000) + '"]}]}'
      ]);
      let error = '';

      try {
        await runBimSentinel(store, model);
      } catch (caught) {
        error = caught instanceof Error ? caught.message : 'unknown';
      }

      expect(error).assertEqual('BIM_SENTINEL_ATTENTION_INVALID');
    });
  });
}
