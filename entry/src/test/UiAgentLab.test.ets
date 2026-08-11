import { describe, it, expect } from '@ohos/hypium';
import {
  ActionOffer,
  A2uiSurfaceStore,
  CreateUiTaskPayload,
  DataResult,
  LocalModelSettings,
  defaultLocalModelSettings,
  mergeA2uiLayoutWithStatus,
  parseA2uiEnvelope,
  parseA2uiJsonl,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';
import {
  createUiAgentLabHtmlShell,
  resolveUiAgentLabCatalogFieldsJsonForModel,
  resolveUiAgentLabDataPath,
  resolveUiAgentLabSurfaceJson,
  strictUiAgentLabFiniteNumber,
  UiAgentLabDecisionPayload,
  uiAgentLabDecisionScript,
  uiAgentLabSurfaceScript,
  uiAgentLabStatusScript
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabHtml';
import {
  clearUiLabModelSettings,
  configureUiLabModelSettings,
  uiLabModelSettings
} from '../main/ets/pages/A2uiHome/lab/UiLabRuntimeConfig';
import {
  parseUiAgentLabDecisionOutput,
  UiAgentLabDecisionNotesState,
  UiAgentLabDecisionOutput
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabDecisionNotes';
import {
  buildUiAgentLabSnapshot,
  hydrateUiAgentLabMergedJsonl,
  hydrateUiAgentLabSnapshotForMergedLayout,
  projectClosedUiAgentLabComponents,
  UiAgentLabDecisionStreamGate,
  uiAgentLabDataJsonl,
  uiAgentLabPartialDispatch,
  uiAgentLabProgressWindowAvailable,
  uiAgentLabRejectedLayoutJsonl,
  uiAgentLabLayoutDiagnosticText,
  uiAgentLabLayoutPrompt,
  withUiAgentLabSurfaceStatus
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabHarness';

interface UiLabHydrationShop {
  name: string;
  rank: number;
}

interface UiLabHydrationNote {
  label: string;
  value: number;
}

interface UiLabHydrationData {
  shops: UiLabHydrationShop[];
  notes: UiLabHydrationNote[];
}

interface UiLabDashboardHeader {
  kicker?: string;
  title: string;
  description?: string;
  ariaLabel: string;
}

interface UiLabDashboardMetric {
  label: string;
  value: number;
  unit: string;
  delta: number;
  deltaLabel: string;
}

interface UiLabDashboardMetrics {
  header: UiLabDashboardHeader;
  items: UiLabDashboardMetric[];
}

interface UiLabDashboardSegment {
  label: string;
  bytes: number;
}

interface UiLabDashboardRing {
  header: UiLabDashboardHeader;
  centerLabel: string;
  unitLabel: string;
  segments: UiLabDashboardSegment[];
}

interface UiLabDashboardSeries {
  label: string;
  values: number[];
}

interface UiLabDashboardLine {
  xLabels: string[];
  series: UiLabDashboardSeries[];
}

interface UiLabDashboardHeatmap {
  weekLabels: string[];
  dayLabels: string[];
  values: number[][];
}

interface UiLabDashboardModel {
  metrics: UiLabDashboardMetrics;
  ring: UiLabDashboardRing;
  line: UiLabDashboardLine;
  heatmap: UiLabDashboardHeatmap;
}

function settings(): LocalModelSettings {
  return {
    provider: 'test-provider',
    baseUrl: 'https://example.test/v1/chat/completions',
    model: 'test-model',
    apiKey: 'test-secret',
    customParametersJson: '{"temperature":0}',
    ignoreToolSurfaceUpdates: true
  };
}

export default function uiAgentLabTest() {
  describe('uiAgentLab', () => {
    it('projects only complete streamed branches and keeps model order', 0, () => {
      const components = JSON.parse('[{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","metrics","activity"]},' +
        '{"id":"hero","component":"HeroBanner","title":"GitHub overview"},' +
        '{"id":"metrics","component":"MetricGrid","dataPath":"/results/0/data/metrics"}]') as Object[];
      const projected = projectClosedUiAgentLabComponents(components);

      expect(projected === null).assertFalse();
      const records = projected as Record<string, Object>[];
      expect(records.length).assertEqual(4);
      expect(records.map((record: Record<string, Object>): Object => record['id']).join(','))
        .assertEqual('root,content,hero,metrics');
      expect((records[1]['children'] as string[]).join(',')).assertEqual('hero,metrics');
    });

    it('emits the first partial immediately then uses one fixed progress window', 0, () => {
      expect(uiAgentLabPartialDispatch(false, -1)).assertEqual('immediate');
      expect(uiAgentLabPartialDispatch(true, -1)).assertEqual('schedule');
      expect(uiAgentLabPartialDispatch(true, 0)).assertEqual('none');
      expect(uiAgentLabProgressWindowAvailable(-1)).assertTrue();
      expect(uiAgentLabProgressWindowAvailable(32)).assertFalse();
    });

    it('keeps a valid partial only for timeout and fails closed for a rejected final candidate', 0, () => {
      const baseline = '{"createSurface":{"surfaceId":"surface-policy","status":"ready"}}\n';
      const partial = '{"createSurface":{"surfaceId":"surface-policy","status":"calling_tool"}}\n';
      const progressive = withUiAgentLabSurfaceStatus(partial, 'surface-policy', 'calling_tool');

      expect(uiAgentLabRejectedLayoutJsonl(null, progressive, baseline, 'surface-policy'))
        .assertContain('"status":"ready"');
      expect(uiAgentLabRejectedLayoutJsonl('invalid-final', progressive, baseline, 'surface-policy'))
        .assertEqual(baseline);
    });

    it('opens decision-note streaming only on exact standalone tag boundaries', 0, () => {
      const valid = new UiAgentLabDecisionStreamGate();
      expect(valid.feed('<ui_decision_')).assertEqual('');
      expect(valid.feed('notes>\nsummary\n</ui_decision_notes>')).assertEqual('');
      expect(valid.feed('\n{"version":')).assertEqual('{"version":');
      expect(valid.feed('"v0.9.1"}')).assertEqual('"v0.9.1"}');
      expect(valid.hasProtocolStarted()).assertTrue();
      expect(valid.isInvalid()).assertFalse();

      const invalid = new UiAgentLabDecisionStreamGate();
      invalid.feed('prefix<ui_decision_notes>\nsummary\n</ui_decision_notes>\n{}');
      expect(invalid.isInvalid()).assertTrue();
    });

    it('adds surface revision and lifecycle generation guards to ArkWeb pushes', 0, () => {
      const surfaceJson = '{"surfaceId":"revision-surface","rootId":"root","components":[],' +
        '"dataModelJson":"{}"}';
      const first = uiAgentLabSurfaceScript(surfaceJson, 7, 3);
      const second = uiAgentLabSurfaceScript(surfaceJson, 8, 3);
      const html = createUiAgentLabHtmlShell();

      expect(first === second).assertFalse();
      expect(html).assertContain('var latestSurfaceGeneration=-1,latestSurfaceRevision=-1');
      expect(html).assertContain('if(generation<latestSurfaceGeneration)return');
      expect(html).assertContain('if(revision<=latestSurfaceRevision)return');
    });

    it('builds one interactive HTML shell with the allowlisted bridge', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UiAgentLabBridge.postMessage');
      expect(html).assertContain("type:'back'");
      expect(html).assertContain("type:'submit'");
      expect(html).assertContain('id="status"');
      expect(html).assertContain('等待 UI Agent 生成 Lab 组件');
      expect(html).assertContain('id="composer"');
      expect(html).assertContain('id="toast"');
      expect(html).assertContain('window.__applyUiAgentLabSurface');
      expect(html).assertContain('id="decisionToggle"');
      expect(html).assertContain('id="decisionPanel"');
      expect(html).assertContain('aria-pressed="false"');
      expect(html).assertContain('UI 决策说明');
      expect(html).assertContain("bridge({type:'toggleDecisionNotes',enabled:");
      expect(html.indexOf('id="decisionPanel"')).assertLarger(html.indexOf('</header>'));
      expect(html.indexOf('id="surface"')).assertLarger(html.indexOf('id="decisionPanel"'));
    });

    it('encodes status payload before building executable JavaScript', 0, () => {
      const marker = "x');window.__RAW_STATUS_EXECUTED=true;//";
      const script = uiAgentLabStatusScript({
        state: 'error',
        message: marker,
        responseChars: 0
      });
      expect(script).assertContain('window.__applyUiAgentLabStatus(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script).assertContain('\\u007b');
    });

    it('bounds and encodes decision notes before injecting them into ArkWeb', 0, () => {
      const marker = "</script><script>window.__RAW_DECISION_EXECUTED=true</script>";
      const payload: UiAgentLabDecisionPayload = {
        enabled: true,
        text: marker + 'p'.repeat(2600)
      };
      const script = uiAgentLabDecisionScript(payload);
      expect(script).assertContain('window.__applyUiAgentLabDecision(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script.indexOf('</script>')).assertEqual(-1);
      expect(script).assertContain('\\u007b');
      expect(script.length).assertLess(16000);
    });

    it('encodes a complete surface before injecting it into ArkWeb JavaScript', 0, () => {
      const marker = "</script><script>window.__RAW_SURFACE_EXECUTED=true</script>";
      const surfaceJson = '{"surfaceId":"surface-lab","rootId":"root","components":[' +
        '{"id":"root","component":"Text","text":' + JSON.stringify(marker) + '}],"dataModelJson":"{}"}';
      const script = uiAgentLabSurfaceScript(surfaceJson);
      expect(script).assertContain('window.__applyUiAgentLabSurface(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script.indexOf('</script>')).assertEqual(-1);
      expect(script).assertContain('\\u007b');
      expect(script).assertContain('\\u003c');
    });

    it('strictly separates bounded multiline decision notes from the unchanged A2UI candidate', 0, () => {
      const protocol = '{"version":"v0.9.1","updateComponents":{"surfaceId":"decision-surface",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"hero"},' +
        '{"id":"hero","component":"HeroBanner","title":"Verified result"}]}}';
      const output = '<ui_decision_notes>\n' +
        '选择 HeroBanner，因为它适合概括已验证结果。\n' +
        '/results/0/data/raw 未展示，因为它是不可读的原始字段。\n' +
        '</ui_decision_notes>\n' + protocol;
      const parsed: UiAgentLabDecisionOutput = parseUiAgentLabDecisionOutput(output, true);
      expect(parsed.protocolCandidate).assertEqual(protocol);
      expect(parsed.decisionNotes).assertEqual('选择 HeroBanner，因为它适合概括已验证结果。\n' +
        '/results/0/data/raw 未展示，因为它是不可读的原始字段。');

      const disabled = parseUiAgentLabDecisionOutput(output, false);
      expect(disabled.protocolCandidate).assertEqual(output);
      expect(disabled.decisionNotes === null).assertTrue();

      const protocolOnly = parseUiAgentLabDecisionOutput(protocol, true);
      expect(protocolOnly.protocolCandidate).assertEqual(protocol);
      expect(protocolOnly.decisionNotes === null).assertTrue();
    });

    it('clears accepted decision notes before a later surface update can reuse them', 0, () => {
      const state = new UiAgentLabDecisionNotesState();
      state.update('decision-surface', '选择 HeroBanner 概括结果。');
      expect(state.read('decision-surface') === null).assertFalse();
      state.clear();
      expect(state.read('decision-surface') === null).assertTrue();
    });

    it('does not guess a protocol from prose and recovers only after an exact closing tag', 0, () => {
      const protocol = '{"version":"v0.9.1","updateComponents":{"surfaceId":"decision-surface",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"hero"},' +
        '{"id":"hero","component":"HeroBanner","title":"Verified result"}]}}';
      const oversized = '<ui_decision_notes>\n' + 'x'.repeat(2401) +
        '\n</ui_decision_notes>\n' + protocol;
      const recovered = parseUiAgentLabDecisionOutput(oversized, true);
      expect(recovered.protocolCandidate).assertEqual(protocol);
      expect(recovered.decisionNotes === null).assertTrue();

      const arbitrary = 'unbounded prose\n' + protocol;
      const unguessed = parseUiAgentLabDecisionOutput(arbitrary, true);
      expect(unguessed.protocolCandidate).assertEqual(arbitrary);
      expect(unguessed.decisionNotes === null).assertTrue();

      const extraAfterClose = '<ui_decision_notes>\n说明\n</ui_decision_notes>\nextra\n' + protocol;
      const rejectedExtra = parseUiAgentLabDecisionOutput(extraAfterClose, true);
      expect(rejectedExtra.protocolCandidate).assertEqual(extraAfterClose);
      expect(rejectedExtra.decisionNotes === null).assertTrue();

      const missingClose = '<ui_decision_notes>\n说明\n' + protocol;
      expect(parseUiAgentLabDecisionOutput(missingClose, true).protocolCandidate).assertEqual(missingClose);
    });

    it('keeps the shared merger strict and accepts only the extracted protocol', 0, () => {
      const surfaceId = 'decision-surface';
      const baseline = '{"version":"v0.9.1","createSurface":{"surfaceId":"decision-surface","root":"root"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"decision-surface","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"decision-surface","path":"/summary",' +
        '"value":{"text":"Verified"}}}\n';
      const protocol = '{"version":"v0.9.1","updateComponents":{"surfaceId":"decision-surface",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"hero"},' +
        '{"id":"hero","component":"HeroBanner","title":"Verified"}]}}';
      const notes = '<ui_decision_notes>\n选择 HeroBanner 概括结果；没有有意义的数据被省略\n' +
        '</ui_decision_notes>';
      const parsed = parseUiAgentLabDecisionOutput(notes + '\n' + protocol, true);
      const extracted = mergeA2uiLayoutWithStatus(
        baseline, parsed.protocolCandidate, surfaceId, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      const unstripped = mergeA2uiLayoutWithStatus(
        baseline, notes + '\n' + protocol, surfaceId, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(extracted.accepted).assertTrue();
      expect(unstripped.accepted).assertFalse();
      expect(unstripped.reason).assertEqual('candidate_rejected');
    });

    it('registers only the fixed UI Lab catalog and uses safe DOM text APIs', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const componentNames: string[] = [
        'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar',
        'ErrorNotice', 'ThinkingStream', 'ThinkingCard', 'ScheduleStack',
        'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs',
        'MasonryGrid', 'List', 'HeroBanner', 'MetricGrid',
        'SegmentedRingChart', 'MultiSeriesLineChart', 'MatrixHeatmap'
      ];
      componentNames.forEach((name: string) => {
        expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.' + name + '=');
      });
      const businessComponents: string[] = [
        'TravelOptions', 'TrainOptions', 'FlightBoard', 'FoodChoices',
        'SocialHub', 'StripeReceivingAccountCard', 'ToolConnectCard',
        'GenericToolResults', 'AggregateSearch', 'MultiTaskBoard'
      ];
      businessComponents.forEach((name: string) => {
        expect(html.indexOf('UI_AGENT_LAB_COMPONENT_REGISTRY.' + name + '=')).assertEqual(-1);
      });
      expect(html.indexOf('UI_AGENT_LAB_COMPONENT_REGISTRY.BentoGrid=')).assertEqual(-1);
      expect(html.indexOf('.bento-grid')).assertEqual(-1);
      expect(html).assertContain('.textContent=');
      expect(html).assertContain('info-time');
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
      expect(html).assertContain("return safeError('不支持的组件'");
    });

    it('keeps the complete UI Lab catalog available to the UI model', 0, () => {
      const entries = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as
        Record<string, Object | string>[];
      const names = entries.map((entry: Record<string, Object | string>): string => entry['name'] as string);
      expect(names.length).assertEqual(20);
      expect(names.indexOf('InfoRows') >= 0).assertTrue();
      expect(names.indexOf('List') >= 0).assertTrue();
      expect(names.indexOf('ExpandableCard') >= 0).assertTrue();
      expect(names.indexOf('SegmentedRingChart') >= 0).assertTrue();
      expect(names.indexOf('ThinkingStream')).assertEqual(-1);
    });

    it('formats bounded layout rejection diagnostics for the visible status area', 0, () => {
      const message = uiAgentLabLayoutDiagnosticText({
        componentId: 'profile_info\nignored',
        rule: 'mapping_source_not_array'
      });
      expect(message).assertEqual(
        'UI Agent 候选布局被拒绝（profile_info ignored: mapping_source_not_array），已显示基础布局。'
      );
      expect(message.indexOf('\n')).assertEqual(-1);
      expect(message.indexOf('providerData')).assertEqual(-1);
    });

    it('pre-resolves exact catalog bindings into real MetricGrid and ring inputs', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const metricFields = '{"title":{"path":"/dashboard/title"},"items":[' +
        '{"id":"stars","label":{"path":"/dashboard/metricLabel"},' +
        '"value":{"path":"/dashboard/stars"},"unit":"stars"}]}';
      const ringFields = '{"title":"Languages","segments":[' +
        '{"label":{"path":"/dashboard/ringLabel"},"value":{"path":"/dashboard/arkts"}},' +
        '{"label":"TypeScript","value":{"path":"/dashboard/typescript"}}]}';
      const modelJson = '{"dashboard":{"title":"Repository","metricLabel":"Stars","stars":42,' +
        '"ringLabel":"ArkTS","arkts":8,"typescript":12}}';
      const surfaceJson = '{"surfaceId":"binding-behavior","rootId":"metrics","components":[' +
        '{"id":"metrics","component":"MetricGrid","catalogFieldsJson":' +
          JSON.stringify(metricFields) + '},' +
        '{"id":"ring","component":"SegmentedRingChart","catalogFieldsJson":' +
          JSON.stringify(ringFields) + '}],"dataModelJson":' + JSON.stringify(modelJson) + '}';
      const resolved = JSON.parse(resolveUiAgentLabSurfaceJson(surfaceJson)) as Record<string, Object>;
      const components = resolved['components'] as Object[];
      const metric = components[0] as Record<string, Object | string | undefined>;
      const ring = components[1] as Record<string, Object | string | undefined>;
      const metricItem = (metric['items'] as Object[])[0] as Record<string, Object | string | number>;
      const ringItem = (ring['segments'] as Object[])[0] as Record<string, Object | string | number>;
      const secondRingItem = (ring['segments'] as Object[])[1] as Record<string, Object | string | number>;

      expect(metric['title']).assertEqual('Repository');
      expect(metricItem['label']).assertEqual('Stars');
      expect(metricItem['value']).assertEqual(42);
      expect(ringItem['label']).assertEqual('ArkTS');
      expect(ringItem['value']).assertEqual(8);
      expect(secondRingItem['label']).assertEqual('TypeScript');
      expect(secondRingItem['value']).assertEqual(12);
      expect(metric['catalogFieldsJson'] === undefined).assertTrue();
      expect(ring['catalogFieldsJson'] === undefined).assertTrue();
      expect(html).assertContain('var UI_AGENT_LAB_COMPONENT_CATALOG = ');
      expect(html).assertContain("typeof component.catalogFieldsJson==='string'");
      expect(html).assertContain('function resolveCatalogValue');
      expect(html.indexOf('eval(')).assertEqual(-1);
      expect(html.indexOf('new Function')).assertEqual(-1);
    });

    it('renders List item Text title and body bindings from each item scope', 0, () => {
      const titleFieldsJson = '{"title":{"path":"/kind"}}';
      const bodyFieldsJson = '{"body":{"path":"/summary"}}';
      const surfaceJson = '{"surfaceId":"item-bindings","rootId":"items","components":[' +
        '{"id":"items","component":"List","dataPath":"/events","child":"event-card"},' +
        '{"id":"event-card","component":"Column","children":["event-title","event-body"]},' +
        '{"id":"event-title","component":"Text","catalogFieldsJson":' +
        JSON.stringify(titleFieldsJson) + '},' +
        '{"id":"event-body","component":"Text","catalogFieldsJson":' +
        JSON.stringify(bodyFieldsJson) + '}],"dataModelJson":"{\\"events\\":[' +
        '{\\"kind\\":\\"PushEvent\\",\\"summary\\":\\"Pushed commits\\"},' +
        '{\\"kind\\":\\"IssueEvent\\",\\"summary\\":\\"Opened issue\\"}]}"}';
      const resolvedSurface = JSON.parse(resolveUiAgentLabSurfaceJson(surfaceJson)) as Record<string, Object>;
      const components = resolvedSurface['components'] as Object[];
      const titleTemplate = components[2] as Record<string, Object | string>;
      const bodyTemplate = components[3] as Record<string, Object | string>;
      const firstTitleJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        'Text', titleFieldsJson, '{"kind":"PushEvent","summary":"Pushed commits"}'
      );
      const firstBodyJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        'Text', bodyFieldsJson, '{"kind":"PushEvent","summary":"Pushed commits"}'
      );
      const secondTitleJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        'Text', titleFieldsJson, '{"kind":"IssueEvent","summary":"Opened issue"}'
      );
      const firstTitle = JSON.parse(firstTitleJson as string) as Record<string, string>;
      const firstBody = JSON.parse(firstBodyJson as string) as Record<string, string>;
      const secondTitle = JSON.parse(secondTitleJson as string) as Record<string, string>;
      const html = createUiAgentLabHtmlShell();

      expect(typeof titleTemplate['catalogFieldsJson']).assertEqual('string');
      expect(typeof bodyTemplate['catalogFieldsJson']).assertEqual('string');
      expect(titleTemplate['title'] === undefined).assertTrue();
      expect(firstTitle['title']).assertEqual('PushEvent');
      expect(firstBody['body']).assertEqual('Pushed commits');
      expect(secondTitle['title']).assertEqual('IssueEvent');
      expect(html).assertContain('function resolveCatalogFields(component,context)');
      expect(html).assertContain('context.hasItemScope===true?context.itemScope:context.model');
      expect(html).assertContain("var primitive=typeof value==='string'||typeof value==='number'||typeof value==='boolean'");
      expect(html).assertContain('copy=nonEmptyText(direct,nonEmptyText(body,title))');
      expect(html).assertContain("if(!direct&&title&&body){output.appendChild(node('span','lab-text-title',title))");
      expect(html.indexOf('eval(')).assertEqual(-1);
      expect(html.indexOf('new Function')).assertEqual(-1);
    });

    it('resolves List titles and ExpandableCard rows without implicit item enumeration', 0, () => {
      const listTitleJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        'List', '{"title":{"path":"/heading"}}', '{"heading":"Recent activity"}'
      );
      const rowFieldsJson = resolveUiAgentLabCatalogFieldsJsonForModel(
        'ExpandableCard',
        '{"title":{"path":"/name"},"rows":[' +
          '{"label":"Address","value":{"path":"/address"}},' +
          '{"label":{"path":"/categoryLabel"},"value":{"path":"/category"}}]}',
        '{"name":"North shop","address":"1 Main Street",' +
          '"categoryLabel":"Type","category":"Cafe","internal":{"secret":"hidden"}}'
      );
      const invalidNumericRow = resolveUiAgentLabCatalogFieldsJsonForModel(
        'ExpandableCard',
        '{"rows":[{"label":"Distance","value":{"path":"/distance"}}]}',
        '{"distance":120}'
      );
      const listFields = JSON.parse(listTitleJson as string) as Record<string, string>;
      const rowFields = JSON.parse(rowFieldsJson as string) as Record<string, Object | string>;
      const rows = rowFields['rows'] as Object[];
      const firstRow = rows[0] as Record<string, string>;
      const secondRow = rows[1] as Record<string, string>;
      const html = createUiAgentLabHtmlShell();

      expect(listFields['title']).assertEqual('Recent activity');
      expect(rowFields['title'] as string).assertEqual('North shop');
      expect(firstRow['label']).assertEqual('Address');
      expect(firstRow['value']).assertEqual('1 Main Street');
      expect(secondRow['label']).assertEqual('Type');
      expect(secondRow['value']).assertEqual('Cafe');
      expect(invalidNumericRow).assertNull();
      expect(html).assertContain("node('h3','lab-list-title',title)");
      expect(html).assertContain("var value=hasLegacyDataPath?componentValue(component,context):undefined");
      expect(html).assertContain('var directRows=list(component.rows).slice(0,8)');
    });

    it('rejects numeric strings and non-exact path objects during executable catalog resolution', 0, () => {
      const invalidFields: string[] = [
        '{"items":[{"label":"Stars","value":{"path":"/dashboard/stars"}}]}',
        '{"items":[{"label":"Stars","value":{"path":"/dashboard/count","fallback":0}}]}'
      ];
      const models: string[] = [
        '{"dashboard":{"stars":"42"}}',
        '{"dashboard":{"count":42}}'
      ];
      for (let index = 0; index < invalidFields.length; index++) {
        const source = '{"surfaceId":"invalid-binding","rootId":"metrics","components":[' +
          '{"id":"metrics","component":"MetricGrid","catalogFieldsJson":' +
          JSON.stringify(invalidFields[index]) + '}],"dataModelJson":' + JSON.stringify(models[index]) + '}';
        const resolved = JSON.parse(resolveUiAgentLabSurfaceJson(source)) as Record<string, Object>;
        const component = (resolved['components'] as Object[])[0] as Record<string, Object | string>;
        expect(typeof component['catalogFieldsJson']).assertEqual('string');
        expect(component['items'] === undefined).assertTrue();
      }
    });

    it('rejects pointer-shaped visible literals but resolves exact binding objects', 0, () => {
      const modelJson = '{"summary":{"title":"Repository","route":"/release/notes"}}';
      const directPointer = resolveUiAgentLabCatalogFieldsJsonForModel(
        'HeroBanner', '{"title":"/summary/title"}', modelJson
      );
      const directBodyPointer = resolveUiAgentLabCatalogFieldsJsonForModel(
        'HeroBanner', '{"title":"Repository","body":"/summary/title"}', modelJson
      );
      const boundTitle = resolveUiAgentLabCatalogFieldsJsonForModel(
        'HeroBanner', '{"title":{"path":"/summary/title"}}', modelJson
      );
      const boundSlashValue = resolveUiAgentLabCatalogFieldsJsonForModel(
        'HeroBanner', '{"title":{"path":"/summary/route"}}', modelJson
      );

      expect(directPointer).assertNull();
      expect(directBodyPointer).assertNull();
      expect((JSON.parse(boundTitle as string) as Record<string, string>)['title']).assertEqual('Repository');
      expect((JSON.parse(boundSlashValue as string) as Record<string, string>)['title']).assertEqual('/release/notes');
    });

    it('rejects numeric strings and preserves direct-first legacy-fallback renderer markers', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(strictUiAgentLabFiniteNumber(42)).assertEqual(42);
      expect(strictUiAgentLabFiniteNumber('42')).assertNull();
      expect(strictUiAgentLabFiniteNumber(Number.POSITIVE_INFINITY)).assertNull();
      expect(html).assertContain("return typeof value==='number'&&Number.isFinite(value)?value:null");
      expect(html).assertContain(
        "policy==='literal-or-path'&&typeof value==='string'&&value.charAt(0)==='/'"
      );
      expect(html.indexOf('var next=Number(value)')).assertEqual(-1);
      expect(html).assertContain('Array.isArray(component.items)?component.items:');
      expect(html).assertContain("itemArray(value,'items')");
      expect(html).assertContain('Array.isArray(component.segments)?component.segments:');
      expect(html).assertContain("itemArray(value,'segments')");
      expect(html).assertContain("typeof component.labelPath==='string'&&typeof component.valuePath==='string'");
      expect(html).assertContain('if(mapped){items=items.map(function(item)');
      expect(html).assertContain('label:pointer(item,component.labelPath),value:pointer(item,component.valuePath)');
      expect(html).assertContain('items.forEach(function(item)');
      expect(html.indexOf('items.slice(0,8)')).assertEqual(-1);
      expect(html.indexOf('items.length>8')).assertEqual(-1);
      expect(html).assertContain("typeof component.timePath==='string'?pointer(item,component.timePath):''");
      expect(html).assertContain("nonEmptyText(valueRecord.value,'—')");
      expect(html).assertContain("nonEmptyText(item,'—')");
      expect(html).assertContain("if(segments.length===0||total<=0){wrapper.appendChild(node('p','lab-card-copy','暂无有效构成数据'))");
      expect(html.indexOf('segments.length===0||total<=0')).assertLess(
        html.indexOf("compactNumber(segment.field.value/total*100)+'%'")
      );
      expect(html).assertContain('componentValue(component,context)');
    });

    it('renders dynamic dashboard components with bounded renderer-owned geometry', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.HeroBanner=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MetricGrid=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.SegmentedRingChart=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MultiSeriesLineChart=');
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.MatrixHeatmap=');
      expect(html).assertContain("document.createElementNS('http://www.w3.org/2000/svg',tag)");
      expect(html).assertContain("function segmentedRingPalette(){return [1,2,3,4,5,6].map(function(index){return cssColor('--chart-'+String(index));});}");
      expect(html).assertContain("function heatmapPalette(){return [1,2,3,4,5,6].map(function(index){return cssColor('--chart-'+String(index));});}");
      expect(html).assertContain("if(copy.endsWith('.0'))copy=copy.slice(0,-2)");
      expect(html).assertContain("function formattedBytes(value)");
      expect(html).assertContain("units=['B','KB','MB','GB','TB']");
      expect(html).assertContain("if(field.kind==='bytes')return formattedBytes(field.value)");
      expect(html.indexOf("if(field.kind==='bytes')return copy+'B'")).assertEqual(-1);
      expect(html).assertContain("items.slice(0,6).forEach");
      expect(html).assertContain("itemArray(value,'segments')");
      expect(html).assertContain("list(source.series).slice(0,4)");
      expect(html).assertContain("var rawValues=list(itemRecord.values)");
      expect(html).assertContain("rawValues.slice(0,24)");
      expect(html).assertContain("list(source.values).slice(0,12)");
      expect(html).assertContain("list(source.weeks).slice(0,24)");
      expect(html).assertContain("componentValue(component,context)");
      expect(html).assertContain("raw=source?source.header:undefined,header=record(raw)");
      expect(html).assertContain("nonEmptyText(component.text,fields.kicker)");
      expect(html).assertContain("nonEmptyText(component.title,fields.title)");
      expect(html).assertContain("nonEmptyText(component.body,fields.description)");
      expect(html).assertContain("parent.setAttribute('aria-label',fields.ariaLabel)");
      expect(html).assertContain("left.value-right.value||left.index-right.index");
      expect(html).assertContain("segments[entry.index].renderColor=chartColorAtRank(rank,ranked.length)");
      expect(html).assertContain('--chart-track:');
      expect(html).assertContain("if(segments.length>8){var otherValue=segments.slice(8).reduce");
      expect(html).assertContain("segments=segments.slice(0,8);segments.push({label:'其他'");
      expect(html).assertContain("renderColor:cssColor('--chart-1'),neutral:true");
      expect(html).assertContain("filter(function(entry){return !entry.neutral;})");
      expect(html.indexOf('total+=field.value')).assertLess(html.indexOf('if(segments.length>8)'));
      expect(html.indexOf('ranks.indexOf(segment.field.value)')).assertEqual(-1);
      expect(html).assertContain("function cssColor(name){return getComputedStyle(document.documentElement).getPropertyValue(name).trim();}");
      expect(html).assertContain("track.setAttribute('stroke',cssColor('--chart-track'))");
      expect(html).assertContain("track.setAttribute('stroke-width',String(SEGMENTED_RING_STROKE_WIDTH))");
      expect(html).assertContain("arc.setAttribute('stroke-width',String(SEGMENTED_RING_STROKE_WIDTH))");
      expect(html).assertContain('visibleArcLength=segments.length===1?circumference:Math.max(0,arcLength-SEGMENTED_RING_GAP_LENGTH)');
      expect(html).assertContain("compactNumber(segment.field.value/total*100)+'%'");
      expect(html).assertContain("source?nonEmptyText(source.centerLabel):''");
      expect(html).assertContain("centerValue.textContent=compactNumber(total)");
      expect(html).assertContain("centerUnit.textContent=unitLabel");
      expect(html).assertContain("ringAria=nonEmptyText(ringFields.ariaLabel,ringSummary)");
      expect(html).assertContain("svg.setAttribute('aria-label',ringAria)");
      expect(html).assertContain("ringTitle.textContent=ringAria");
      expect(html).assertContain("rawValues.length!==rawXLabels.length");
      expect(html).assertContain("lineAria=nonEmptyText(lineFields.ariaLabel,lineSummary)");
      expect(html).assertContain("svg.setAttribute('aria-label',lineAria)");
      expect(html).assertContain("lineTitle.textContent=lineAria");
      expect(html).assertContain("wrapper.appendChild(node('p','sr-only',lineSummary))");
      expect(html).assertContain('.sr-only { position:absolute!important;');
      expect(html).assertContain("node('small','metric-unit',unit)");
      expect(html).assertContain("nonEmptyText(source.deltaLabel");
      expect(html).assertContain("metric-delta'+(deltaValue");
      expect(html).assertContain('cell.style.background=heatPalette[level]');
      expect(html).assertContain("grid.setAttribute('role','grid')");
      expect(html).assertContain("cell.setAttribute('role','gridcell')");
      expect(html).assertContain("cell.setAttribute('aria-label',cellLabel)");
      expect(html).assertContain("arc.setAttribute('stroke',segment.renderColor)");
      expect(html.indexOf('source.color')).assertEqual(-1);
      expect(html.indexOf('source.svg')).assertEqual(-1);
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
    });

    it('encodes dashboard component props and dynamic data without embedding raw text', 0, () => {
      const marker = '<svg onload="window.__DASHBOARD_INJECTED=true">';
      const model: UiLabDashboardModel = {
        metrics: {
          header: { kicker: '统计', title: '动态指标', description: '指标说明', ariaLabel: '指标区' },
          items: [{ label: '仓库', value: 24, unit: '个', delta: 3, deltaLabel: '增加 3' }]
        },
        ring: {
          header: { title: '语言分布', ariaLabel: '语言占比图' }, centerLabel: '总量', unitLabel: 'bytes',
          segments: [{ label: 'TypeScript', bytes: 123456 }, { label: 'ArkTS', bytes: 456789 }]
        },
        line: { xLabels: ['一月', '二月'], series: [{ label: '提交', values: [3, 8] }] },
        heatmap: { weekLabels: ['W1', 'W2'], dayLabels: ['一', '二'], values: [[0, 5], [2, 9]] }
      };
      const modelJson = JSON.stringify(model);
      const surfaceJson = '{"surfaceId":"surface-dashboard","rootId":"root","components":[' +
        '{"id":"root","component":"Column","children":["hero","metrics","ring","line","heatmap"]},' +
        '{"id":"hero","component":"HeroBanner","text":"概览","title":' + JSON.stringify(marker) + ',"body":"动态正文"},' +
        '{"id":"metrics","component":"MetricGrid","dataPath":"/metrics"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/ring"},' +
        '{"id":"line","component":"MultiSeriesLineChart","dataPath":"/line"},' +
        '{"id":"heatmap","component":"MatrixHeatmap","dataPath":"/heatmap"}],' +
        '"dataModelJson":' + JSON.stringify(modelJson) + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);

      expect(script).assertContain('window.__applyUiAgentLabSurface(JSON.parse(');
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script.indexOf('动态指标')).assertEqual(-1);
      expect(script.indexOf('TypeScript')).assertEqual(-1);
      expect(script).assertContain('\\u003c');
      expect(script).assertContain('\\u52a8');
    });

    it('renders a paged List by appending every template item in stable item scope', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('UI_AGENT_LAB_COMPONENT_REGISTRY.List=');
      expect(html).assertContain('var LIST_PAGE_SIZE=8');
      expect(html).assertContain('items.slice(visibleCount,nextCount).forEach');
      expect(html).assertContain("more.addEventListener('click',appendPage)");
      expect(html).assertContain("status.textContent='已显示 '+String(visibleCount)+' / '+String(items.length)");
      expect(html).assertContain('more.disabled=visibleCount>=items.length');
      expect(html).assertContain("var row=node('div','lab-list-row')");
      expect(html).assertContain("row.setAttribute('role','listitem')");
      expect(html).assertContain('if(items.length>LIST_PAGE_SIZE)wrapper.appendChild(pager)');
      expect(html).assertContain('.lab-list+.lab-list { padding-top:11px; border-top:1px solid var(--hairline); }');
      expect(html).assertContain('.lab-list-row:last-child { padding-bottom:0; border-bottom:0; }');
      expect(html).assertContain('hasItemScope:true,itemScope:item');
      expect(html).assertContain("component.dataPath==='/'");
      expect(html).assertContain('return context.itemScope');
      expect(html).assertContain("node('p','lab-card-copy','暂无内容')");
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
    });

    it('renders visible text and lists from component props or data paths', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const modelJson = '{"headline":"动态标题","days":[{"label":"动态日期",' +
        '"title":"动态列表","entries":[{"time":"08:30","title":"动态事项"}]}]}';
      const surfaceJson = '{"surfaceId":"surface-dynamic","rootId":"root","components":[' +
        '{"id":"root","component":"Column","children":["headline","schedule"]},' +
        '{"id":"headline","component":"Text","text":"静态回退","dataPath":"/headline"},' +
        '{"id":"schedule","component":"ScheduleStack","dataPath":"/days"}],' +
        '"dataModelJson":' + JSON.stringify(modelJson) + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);
      expect(script.indexOf('动态标题')).assertEqual(-1);
      expect(script.indexOf('动态列表')).assertEqual(-1);
      expect(script.indexOf('静态回退')).assertEqual(-1);
      expect(script).assertContain('\\u52a8');
      expect(script).assertContain('\\u5217');
      expect(html).assertContain('componentValue(component,context)');
      expect(html).assertContain('var direct=nonEmptyText(component.text),title=nonEmptyText(component.title),body=nonEmptyText(component.body)');
      expect(html).assertContain('copy=nonEmptyText(direct,nonEmptyText(body,title))');
      expect(html).assertContain("if(!direct&&title&&body){output.appendChild(node('span','lab-text-title',title));output.appendChild(node('span','lab-text-body',body));return output;}");
      expect(html).assertContain("itemArray(dayRecord,'entries')");
      expect(html).assertContain('text(dayRecord.title');
      expect(html).assertContain('text(eventRecord.title');
      expect(html.indexOf('西湖边喝咖啡')).assertEqual(-1);
      expect(html.indexOf('北山街')).assertEqual(-1);
    });

    it('renders bounded generic expandable data and falls back from an empty parser title', 0, () => {
      const html = createUiAgentLabHtmlShell();
      const marker = '<img src=x onerror="window.__EXPANDABLE_INJECTED=true">';
      const modelJson = '{"title":"季度概览","summary":"保持增长",' +
        '"rows":[{"label":"当前值","value":"可见"}],"groups":[' +
        '{"name":"Alpha","metrics":[{"label":"完成率","value":87},' +
        '{"label":"稳定状态","value":true}],"note":' + JSON.stringify(marker) + '}]}';
      const surfaceJson = '{"surfaceId":"surface-expandable","rootId":"detail","components":[' +
        '{"id":"detail","component":"ExpandableCard","title":"","dataPath":"/payload"}],' +
        '"dataModelJson":' + JSON.stringify('{"payload":' + modelJson + '}') + '}';
      const script = uiAgentLabSurfaceScript(surfaceJson);

      expect(html).assertContain('var title=nonEmptyText(component.title');
      expect(html).assertContain("nonEmptyText(valueRecord?valueRecord.title:undefined");
      expect(html).assertContain('appendExpandableValue(panelInner,value');
      expect(html).assertContain('appendExpandableValue(itemHost,itemRecord');
      expect(html).assertContain("appendExpandableField(objectSection,key,child,budget)");
      expect(html).assertContain('EXPANDABLE_MAX_DEPTH=4');
      expect(html).assertContain('EXPANDABLE_MAX_NODES=72');
      expect(html).assertContain('EXPANDABLE_MAX_ARRAY_ITEMS=12');
      expect(html).assertContain('EXPANDABLE_MAX_OBJECT_FIELDS=16');
      expect(html).assertContain('{remaining:EXPANDABLE_MAX_NODES,notified:false}');
      expect(html).assertContain("key==='title'||key==='name'||key==='label'");
      expect(html).assertContain('.textContent=');
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
      expect(html.indexOf('[object Object]')).assertEqual(-1);
      expect(script.indexOf('季度概览')).assertEqual(-1);
      expect(script.indexOf('完成率')).assertEqual(-1);
      expect(script.indexOf('当前值')).assertEqual(-1);
      expect(script.indexOf(marker)).assertEqual(-1);
      expect(script).assertContain('\\u5b8c');
      expect(script).assertContain('\\u003c');
    });

    it('resolves flat, nested, array and escaped UI Lab data paths', 0, () => {
      const model: Object = JSON.parse('{"headline":"单层值","results":[{"facts":[{"value":"数组嵌套值"}]}],' +
        '"escaped":{"slash/key":{"til~de":"转义值"}}}') as Object;

      expect(resolveUiAgentLabDataPath(model, '/headline')).assertEqual('单层值');
      expect(resolveUiAgentLabDataPath(model, '/results/0/facts/0/value')).assertEqual('数组嵌套值');
      expect(resolveUiAgentLabDataPath(model, '/escaped/slash~1key/til~0de')).assertEqual('转义值');
      expect(resolveUiAgentLabDataPath(model, '/results/1/facts') === undefined).assertTrue();
      expect(resolveUiAgentLabDataPath(model, '/results/00') === undefined).assertTrue();
    });

    it('keeps exact nested snapshot paths and finishes with one generic root data model', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-nested',
        dataTaskIds: ['data-nested'],
        skillId: 'dynamic',
        intent: '展示嵌套结果',
        expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"title":"动态标题","details":{"items":[{"label":"第一项"}]},' +
          '"repositoryMetrics":{"repositoryCount":2},' +
          '"slash/key":{"til~de":"保留转义键"}}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const parsed = parseA2uiJsonl(uiAgentLabDataJsonl('surface-nested', snapshot));
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"surface-nested","root":"root","sendDataModel":true}}'
      ));
      parsed.envelopes.forEach(envelope => store.apply(envelope));
      const model = JSON.parse(store.getSurface().dataModelJson) as Record<string, Object>;
      const results = model['results'] as Object[];
      const first = results[0] as Record<string, Object>;
      const nestedData = first['data'] as Record<string, Object>;

      expect(parsed.error).assertEqual('');
      const paths: string[] = [];
      parsed.envelopes.forEach(envelope => {
        if (envelope.updateDataModel !== undefined) paths.push(envelope.updateDataModel.path);
      });
      expect(paths.length).assertEqual(1);
      expect(paths[0]).assertEqual('/');
      const summary = model['summary'] as Record<string, Object>;
      expect(summary['text']).assertEqual('已获取 1 组真实数据。');
      expect(summary['dataLabel']).assertEqual('uiLabResultSets');
      expect((nestedData['details'] as Record<string, Object>)['items'] !== undefined).assertTrue();
      expect((nestedData['repositoryMetrics'] as Record<string, Object>)['repositoryCount']).assertEqual(2);
      expect((nestedData['slash/key'] as Record<string, Object>)['til~de']).assertEqual('保留转义键');

      const baseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-nested","root":"root",' +
        '"title":"UI Agent Lab","intent":"ui_lab","status":"ready","sendDataModel":true}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-nested","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","facts"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"facts","component":"InfoRows","dataPath":"/results/0/facts"}' +
        ']}}\n' + uiAgentLabDataJsonl('surface-nested', snapshot);
      const candidate = '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-nested",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","facts","item-list"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"facts","component":"InfoRows","dataPath":"/results/0/facts"},' +
        '{"id":"item-list","component":"List","children":' +
        '{"path":"/results/0/data/details/items","componentId":"item-card"}},' +
        '{"id":"item-card","component":"ExpandableCard"}]}}';
      const merged = mergeA2uiLayoutWithStatus(
        baseline,
        candidate,
        'surface-nested',
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      const mergedParsed = parseA2uiJsonl(merged.jsonl, 'ui-lab');
      const mergedStore = new A2uiSurfaceStore();
      mergedParsed.envelopes.forEach(envelope => mergedStore.apply(envelope));
      const mergedModel = JSON.parse(mergedStore.getSurface().dataModelJson) as Record<string, Object>;

      expect(merged.accepted).assertTrue();
      expect(mergedParsed.error).assertEqual('');
      expect((mergedModel['results'] as Object[]).length).assertEqual(1);
      const mergedComponents = mergedStore.getSurface().components;
      expect(mergedComponents[4].component).assertEqual('List');
      expect(mergedComponents[4].dataPath).assertEqual('/results/0/data/details/items');
      expect(mergedComponents[4].child).assertEqual('item-card');
    });

    it('plans with eight samples but hydrates only an accepted List path from full data', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-full-list',
        dataTaskIds: ['data-full-list'],
        skillId: 'dynamic',
        intent: '展示完整列表',
        expectedOutputSchema: 'custom.v1'
      };
      const shops: UiLabHydrationShop[] = [];
      const notes: UiLabHydrationNote[] = [];
      for (let index = 0; index < 24; index++) {
        shops.push({ name: '项目 ' + index.toString(), rank: index });
        notes.push({ label: '备注 ' + index.toString(), value: index });
      }
      const hydrationData: UiLabHydrationData = { shops, notes };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: hydrationData as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const sampledData = snapshot.results[0].data as Record<string, Object>;
      expect((sampledData['shops'] as Object[]).length).assertEqual(8);
      expect((sampledData['notes'] as Object[]).length).assertEqual(8);

      const baseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-full-list","root":"root",' +
        '"title":"UI Agent Lab","intent":"ui_lab","status":"ready","sendDataModel":true}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-full-list","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
        ']}}\n' + uiAgentLabDataJsonl('surface-full-list', snapshot);
      const candidate = '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-full-list",' +
        '"components":[{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["summary","shop-list","notes"]},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"},' +
        '{"id":"shop-list","component":"List","children":' +
        '{"path":"/results/0/data/shops","componentId":"shop-card"}},' +
        '{"id":"shop-card","component":"ExpandableCard"},' +
        '{"id":"notes","component":"InfoRows","dataPath":"/results/0/data/notes"}]}}';
      const merged = mergeA2uiLayoutWithStatus(
        baseline,
        candidate,
        'surface-full-list',
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged.accepted).assertTrue();

      const hydrated = hydrateUiAgentLabSnapshotForMergedLayout(
        snapshot,
        [data],
        merged.jsonl,
        'surface-full-list'
      );
      const hydratedData = hydrated.results[0].data as Record<string, Object>;
      expect((hydratedData['shops'] as Object[]).length).assertEqual(24);
      expect((hydratedData['notes'] as Object[]).length).assertEqual(24);

      const hydratedJsonl = hydrateUiAgentLabMergedJsonl(
        merged.jsonl,
        'surface-full-list',
        snapshot,
        [data]
      );
      const hydratedParsed = parseA2uiJsonl(hydratedJsonl, 'ui-lab');
      const hydratedStore = new A2uiSurfaceStore();
      hydratedParsed.envelopes.forEach(envelope => hydratedStore.apply(envelope));
      const hydratedModel = JSON.parse(hydratedStore.getSurface().dataModelJson) as Record<string, Object>;
      const hydratedResults = hydratedModel['results'] as Object[];
      const firstHydrated = hydratedResults[0] as Record<string, Object>;
      const finalData = firstHydrated['data'] as Record<string, Object>;
      expect(hydratedParsed.error).assertEqual('');
      expect((finalData['shops'] as Object[]).length).assertEqual(24);
      expect((finalData['notes'] as Object[]).length).assertEqual(24);
    });

    it('prefers providerData paths and hydrates the selected provider array without generic rows', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-provider-data',
        dataTaskIds: ['data-provider-data'],
        skillId: 'dynamic',
        intent: '展示 GitHub 活动',
        expectedOutputSchema: 'dynamicToolConnect'
      };
      const events: Object[] = [];
      const xLabels: string[] = [];
      const chartValues: number[] = [];
      for (let index = 0; index < 20; index++) {
        events.push(JSON.parse('{"type":"PushEvent","created_at":"2026-08-04T00:00:00Z",' +
          '"repo":{"name":"repo-' + index.toString() + '"},' +
          '"actor":{"login":"developer"}}') as Object);
        xLabels.push('D' + index.toString());
        chartValues.push(index);
      }
      const data: DataResult = {
        toolId: 'dynamic.search',
        outputSchema: 'dynamicToolConnect',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"providerData":{"events":' + JSON.stringify(events) + ',' +
          '"chart":{"xLabels":' + JSON.stringify(xLabels) + ',"series":[{"label":"Commits",' +
          '"values":' + JSON.stringify(chartValues) + '}]}},' +
          '"results":[{"rows":[{"label":"结果 1","value":""}],"rawPreview":"legacy"}],' +
          '"registration":{"provider":"Composio"}}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const visible = snapshot.results[0].data as Record<string, Object>;
      const sampledProvider = visible['providerData'] as Record<string, Object>;
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);

      expect(Object.keys(visible).length).assertEqual(1);
      expect(visible['results'] === undefined).assertTrue();
      expect((sampledProvider['events'] as Object[]).length).assertEqual(8);
      const sampledChart = sampledProvider['chart'] as Record<string, Object>;
      const sampledSeries = sampledChart['series'] as Object[];
      const sampledFirstSeries = sampledSeries[0] as Record<string, Object>;
      expect((sampledFirstSeries['values'] as number[]).length).assertEqual(8);
      expect(prompt).assertContain('Prefer paths below providerData');
      expect(prompt).assertContain('"events"');
      expect(prompt.indexOf('结果 1')).assertEqual(-1);

      const mergedJsonl = '{"version":"v0.9.1","updateComponents":{' +
        '"surfaceId":"surface-provider-data","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","event-list","chart"]},' +
        '{"id":"hero","component":"HeroBanner","title":"活动概览"},' +
        '{"id":"event-list","component":"List","children":{' +
        '"path":"/results/0/data/providerData/events","componentId":"event-card"}},' +
        '{"id":"event-card","component":"ExpandableCard"},' +
        '{"id":"chart","component":"MultiSeriesLineChart",' +
        '"dataPath":"/results/0/data/providerData/chart"}]}}\n' +
        uiAgentLabDataJsonl('surface-provider-data', snapshot);
      const hydrated = hydrateUiAgentLabSnapshotForMergedLayout(
        snapshot, [data], mergedJsonl, 'surface-provider-data'
      );
      const hydratedVisible = hydrated.results[0].data as Record<string, Object>;
      const hydratedProvider = hydratedVisible['providerData'] as Record<string, Object>;
      const hydratedChart = hydratedProvider['chart'] as Record<string, Object>;
      const hydratedSeries = hydratedChart['series'] as Object[];
      const hydratedFirstSeries = hydratedSeries[0] as Record<string, Object>;
      expect((hydratedProvider['events'] as Object[]).length).assertEqual(20);
      expect((hydratedChart['xLabels'] as string[]).length).assertEqual(20);
      expect((hydratedFirstSeries['values'] as number[]).length).assertEqual(20);
    });

    it('builds a bounded generic snapshot and lets UI Agent choose presentation', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-1',
        dataTaskIds: ['data-1'],
        skillId: 'dynamic',
        intent: '展示真实结果',
        expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time',
        outputSchema: 'custom.v1',
        status: 'success',
        sources: [],
        warnings: [],
        data: JSON.parse('{"headline":"动态标题","count":3,"rows":[{"name":"第一项"}]}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);
      expect(prompt).assertContain('intent="展示真实结果"');
      expect(prompt.indexOf('MUST include at least one suitable chart component')).assertEqual(-1);
      expect(prompt.indexOf('prefer adding SegmentedRingChart')).assertEqual(-1);
      expect(prompt.indexOf('make charts the main body of the layout')).assertEqual(-1);
      expect(prompt).assertContain('"headline":"动态标题"');
      expect(prompt).assertContain('动态标题');
      expect(prompt).assertContain('Choose presentation by the meaning and shape');
      expect(prompt).assertContain('do not prescribe a chart type');
      expect(prompt).assertContain('MUST output exactly one HeroBanner');
      expect(prompt).assertContain('Do not fabricate a HeroBanner summary for an error or no-display-data baseline');
      expect(prompt).assertContain('always the first visible element in the main content container');
      expect(prompt).assertContain('SurfaceRoot.child must reference a Column');
      expect(prompt).assertContain('HeroBanner id must be Column.children[0]');
      expect(prompt).assertContain('leaving sibling components disconnected');
      expect(prompt).assertContain('/summary/count and /summary/text describe the number of DataResult sets');
      expect(prompt).assertContain('not the number of business entities');
      expect(prompt).assertContain('result.data explicitly labels a scalar as count or total');
      expect(prompt).assertContain('result.data.summary text explicitly supports it');
      expect(prompt.indexOf('mock.travel')).assertEqual(-1);
      expect(prompt).assertContain('"count":3');
      expect(prompt.indexOf('allowedDataPaths')).assertEqual(-1);
    });

    it('keeps every prompt JSON section parseable under long paths and a near-budget snapshot', 0, () => {
      const task: CreateUiTaskPayload = {
        taskId: 'ui-prompt-budget', dataTaskIds: ['data-prompt-budget'], skillId: 'dynamic',
        intent: '验证完整 JSON section', expectedOutputSchema: 'custom.v1'
      };
      const data: DataResult = {
        toolId: 'time', outputSchema: 'custom.v1', status: 'success', sources: [], warnings: [],
        data: JSON.parse('{"seed":true}') as Object
      };
      const snapshot = buildUiAgentLabSnapshot(task, [data]);
      const longData = JSON.parse('{}') as Record<string, Object | string>;
      for (let index = 0; index < 96; index++) {
        longData['long_provider_path_' + index.toString().padStart(3, '0') + '_' + 'segment'.repeat(8)] = 'v';
      }
      longData['zz_payload'] = 'p'.repeat(11000);
      snapshot.results[0].data = longData as Object;
      const prompt = uiAgentLabLayoutPrompt(task, snapshot, [] as ActionOffer[]);
      const snapshotPrefix = 'dataSnapshot=';
      const snapshotStart = prompt.indexOf(snapshotPrefix) + snapshotPrefix.length;
      const completeMarker = '\ndataSnapshotComplete=true';
      const snapshotEnd = prompt.indexOf(completeMarker, snapshotStart);
      const parsedSnapshot = JSON.parse(prompt.substring(snapshotStart, snapshotEnd)) as Object;

      expect(prompt.length).assertLess(24001);
      expect(prompt.indexOf('allowedDataPaths')).assertEqual(-1);
      expect(snapshotEnd).assertLarger(snapshotStart);
      expect(parsedSnapshot === null).assertFalse();
      expect(prompt.endsWith('dataSnapshotComplete=true')).assertTrue();
    });

    it('sends only component identity and action index through ArkWeb', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain("bridge({type:'action',componentId:text(component.id),actionIndex:index})");
      expect(html.indexOf("bridge({type:'action',args:")).assertEqual(-1);
    });

    it('keeps compact capsule chrome and animates expandable content without max-height', 0, () => {
      const html = createUiAgentLabHtmlShell();
      expect(html).assertContain('grid-template-rows:auto minmax(0,1fr) auto; gap:0;');
      expect(html).assertContain('.lab-header { min-height:52px; margin-bottom:12px; border-radius:999px;');
      expect(html).assertContain('.composer { border-radius:999px; padding:6px 6px 6px 16px;');
      expect(html).assertContain('.send { width:40px; height:40px; flex:0 0 40px;');
      expect(html).assertContain('.status { min-height:24px; padding:4px 8px;');
      expect(html).assertContain('line-height:16px; display:flex; justify-content:space-between; align-items:center;');
      expect(html).assertContain('.status>span { min-height:16px; display:flex; align-items:center; }');
      expect(html).assertContain('.decision-toggle,.theme-toggle { width:38px; height:38px;');
      expect(html).assertContain('border-radius:50%');
      expect(html).assertContain('[hidden] { display:none!important; }');
      expect(html).assertContain('.shell.decision-notes-visible { grid-template-rows:auto minmax(0,auto) minmax(0,1fr) auto; }');
      expect(html).assertContain('.decision-panel { min-height:0; max-height:min(34vh,260px);');
      expect(html).assertContain('overflow:auto;');
      expect(html).assertContain('.decision-copy { margin:0;');
      expect(html).assertContain('white-space:pre-wrap;');
      expect(html).assertContain('decisionPanel.hidden=!enabled');
      expect(html).assertContain("decisionToggle.disabled=next.state==='loading'");
      expect(html).assertContain("decisionText.textContent=enabled&&typeof source.text==='string'");
      expect(html.indexOf('plannedComponents')).assertEqual(-1);
      expect(html.indexOf('omittedData')).assertEqual(-1);
      expect(html.indexOf('.innerHTML')).assertEqual(-1);
      expect(html.indexOf('grid-template-rows:auto minmax(0,1fr) auto; gap:12px;')).assertEqual(-1);
      expect(html).assertContain('.expandable-panel { display:grid; grid-template-rows:0fr; opacity:0; transform:translateY(-6px);');
      expect(html).assertContain('cubic-bezier(.22,1,.36,1)');
      expect(html).assertContain('.expandable-panel-inner { min-height:0; overflow:hidden;');
      expect(html.indexOf('.expandable-panel { max-height:')).assertEqual(-1);
    });

    it('clones and clears the in-memory model settings snapshot', 0, () => {
      clearUiLabModelSettings();
      const source = settings();
      configureUiLabModelSettings(source);
      source.model = 'mutated-source';
      source.apiKey = 'mutated-source-secret';
      const first = uiLabModelSettings();
      first.model = 'mutated';
      first.apiKey = 'mutated-secret';
      const second = uiLabModelSettings();
      expect(second.model).assertEqual('test-model');
      expect(second.apiKey).assertEqual('test-secret');

      clearUiLabModelSettings();
      const cleared = uiLabModelSettings();
      expect(cleared.model).assertEqual(defaultLocalModelSettings().model);
      expect(cleared.model === 'test-model').assertFalse();
    });
  });
}
