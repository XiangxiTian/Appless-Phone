import { describe, expect, it } from '@ohos/hypium';
import {
  ActionOffer,
  AIPHONE_COMPONENT_CATALOG_JSON,
  buildA2uiLayoutSystemPrompt,
  mergeA2uiLayout,
  mergeA2uiLayoutWithStatus,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';

const SURFACE_ID: string = 'surface-layout-test';
const BASELINE: string =
  '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-layout-test","root":"root","title":"酒店搜索"}}\n' +
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"results"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"}]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/genericToolResults","value":[]}}\n' +
  '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{"text":"真实结果"}}}\n';

const VALID_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"column"},' +
  '{"id":"column","component":"Column","children":["title","results","actions"]},' +
  '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"},' +
  '{"id":"results","component":"GenericToolResults","dataPath":"/genericToolResults"},' +
  '{"id":"actions","component":"ActionBar","actions":[{"offerId":"detail:1"}]}' +
  ']}}';

const LAB_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"MasonryGrid","dataPath":"/genericToolResults"}' +
  ']}}';

const BENTO_CANDIDATE: string =
  '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
  '{"id":"root","component":"SurfaceRoot","child":"lab-grid"},' +
  '{"id":"lab-grid","component":"BentoGrid","dataPath":"/genericToolResults"}' +
  ']}}';

interface ComponentCatalogEntry {
  name: string;
  usage: string;
  schema: ComponentWireSchema;
}

interface ComponentFieldSchema {
  type: string;
  valuePolicy: string;
  required?: boolean;
  minLength?: number;
  minItems?: number;
  maxItems?: number;
  fields?: Record<string, ComponentFieldSchema>;
  items?: ComponentFieldSchema;
}

interface ComponentWireSchema {
  fields: Record<string, ComponentFieldSchema>;
  requireAny?: string[][];
  exactlyOne?: string[][];
  atMostOne?: string[][];
}

const LAB_COMPONENT_NAMES: string[] = [
  'SurfaceRoot', 'Column', 'Row', 'Text', 'InfoRows', 'ActionBar', 'ErrorNotice',
  'ThinkingCard', 'ScheduleStack', 'SkeletonCard', 'ExpandableCard', 'MediaSlider', 'SceneTabs',
  'MasonryGrid', 'List',
  'HeroBanner', 'MetricGrid', 'SegmentedRingChart', 'MultiSeriesLineChart', 'MatrixHeatmap'
];

interface HotelIdArg {
  hotelId: number;
}

function offers(): ActionOffer[] {
  const args: HotelIdArg = { hotelId: 1 };
  const offer: ActionOffer = {
    offerId: 'detail:1',
    actionId: 'hotel.detail',
    label: '查看实时房型',
    variant: 'primary',
    args: args
  };
  return [offer];
}

export default function a2uiLayoutMergerTest() {
  describe('A2uiLayoutMerger', () => {
    it('replaces only components and resolves immutable offer references', 0, () => {
      const merged: string = mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      const baselineLines: string[] = BASELINE.trim().split('\n');
      const mergedLines: string[] = merged.trim().split('\n');
      expect(merged === BASELINE).assertFalse();
      expect(mergedLines[0]).assertEqual(baselineLines[0]);
      expect(mergedLines[2]).assertEqual(baselineLines[2]);
      expect(mergedLines[3]).assertEqual(baselineLines[3]);
      expect(mergedLines[1].includes('"id":"hotel.detail"')).assertTrue();
      expect(mergedLines[1].includes('"offerId"')).assertFalse();
      expect(mergedLines[1].includes('"hotelId":1')).assertTrue();
    });

    it('reports accepted and fallback merge outcomes without changing jsonl', 0, () => {
      const accepted = mergeA2uiLayoutWithStatus(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      const rejected = mergeA2uiLayoutWithStatus(BASELINE, '{}', SURFACE_ID, offers());
      expect(accepted.accepted).assertTrue();
      expect(accepted.reason).assertEqual('accepted');
      expect(accepted.jsonl).assertEqual(mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers()));
      expect(rejected.accepted).assertFalse();
      expect(rejected.reason).assertEqual('candidate_rejected');
      expect(rejected.jsonl).assertEqual(BASELINE);
    });

    it('gives UI Lab only the envelope skeleton while retaining the generic renderer example', 0, () => {
      const prompt = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
      const genericPrompt = buildA2uiLayoutSystemPrompt(SURFACE_ID, AIPHONE_COMPONENT_CATALOG_JSON);
      const uiLabSkeleton =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[...]}}';
      const genericExample =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}' +
        ']}}';
      const example =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","info","result-list"]},' +
        '{"id":"hero","component":"HeroBanner",' +
        '"title":"REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS"},' +
        '{"id":"info","component":"InfoRows","dataPath":"/summary"},' +
        '{"id":"result-list","component":"List","children":{"path":"/results","componentId":"result-card"}},' +
        '{"id":"result-card","component":"ExpandableCard"}' +
        ']}}';
      const uiLabBaseline =
        '{"version":"v0.9.1","createSurface":{"surfaceId":"surface-layout-test","root":"root"}}\n' +
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"summary"},' +
        '{"id":"summary","component":"Text","dataPath":"/summary/text"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{}}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/results","value":[]}}\n';
      expect(prompt.includes(example)).assertFalse();
      expect(prompt.includes(uiLabSkeleton)).assertTrue();
      expect(prompt.includes('never output the ellipsis literally')).assertTrue();
      expect(prompt.includes('The following is a complete protocol-shape example only')).assertFalse();
      expect(prompt.includes('REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS')).assertFalse();
      expect(prompt.includes('For repeated array items')).assertTrue();
      expect(prompt.includes('official A2UI v0.9 List shape')).assertTrue();
      expect(prompt.includes('"name":"ThinkingStream"')).assertFalse();
      expect(prompt.includes('compact Text template bound only to that field')).assertTrue();
      expect(prompt.includes('Use List for repeated named entities')).assertTrue();
      expect(prompt.includes('use ExpandableCard direct rows')).assertTrue();
      expect(prompt.includes('value must be path-only')).assertTrue();
      expect(prompt.includes('do not generate dataPath="/"')).assertTrue();
      expect(prompt.includes('Prefer one InfoRows binding over List or ExpandableCard')).assertFalse();
      expect(prompt.includes('Array<{label,value,time?}>')).assertTrue();
      expect(prompt.includes('When dataPath points to an ordinary object, omit labelPath, valuePath, and timePath')).assertTrue();
      expect(prompt.includes('Never invent /key or /value for an ordinary object')).assertTrue();
      expect(prompt.includes('paired labelPath/valuePath plus optional timePath')).assertTrue();
      expect(prompt.includes('be relative to each array item rather than the root snapshot')).assertTrue();
      expect(prompt.includes('name fields that actually exist in the sampled items')).assertTrue();
      expect(prompt.includes('make charts the main body of the layout')).assertTrue();
      expect(prompt.includes('use as many different chart component types as the data can meaningfully support')).assertTrue();
      expect(prompt.includes('Every chart must add a distinct view')).assertTrue();
      expect(prompt.includes('Do not repeat the same metric, invent or calculate values')).assertTrue();
      expect(prompt.includes('force a specific chart type')).assertTrue();
      expect(genericPrompt.includes(genericExample)).assertTrue();
      expect(genericPrompt.includes('The following is a complete protocol-shape example only')).assertTrue();
      expect(genericPrompt.includes('For repeated array items')).assertTrue();
      expect(genericPrompt.includes('List with one ExpandableCard')).assertTrue();
      expect(genericPrompt.includes('compact Text template bound only to that field')).assertFalse();
      expect(genericPrompt.includes('make charts the main body of the layout')).assertFalse();
      expect(prompt.includes('Use "component", never "type"')).assertTrue();
      expect(prompt.includes('nested "props" or "properties" object')).assertTrue();
      expect(prompt.includes('Derive every binding path only from the exact structure present in dataSnapshot')).assertTrue();
      expect(prompt.includes('checks that each path exists in that sampled snapshot')).assertTrue();
      expect(prompt.includes('title:{"path":"/summary/title"} is correct')).assertTrue();
      expect(prompt.includes('title:"/summary/title" is wrong')).assertTrue();
      expect(prompt.includes('Path declaration fields stay strings')).assertTrue();
      expect(prompt.includes('dataPath:"/items"')).assertTrue();
      expect(prompt.includes('labelPath:"/label"')).assertTrue();
      expect(prompt.includes('valuePath:"/value"')).assertTrue();
      expect(prompt.includes('timePath:"/time"')).assertTrue();
      expect(prompt.includes('valuePolicy "literal-or-path"')).assertTrue();
      expect(prompt.includes('For "path-only"')).assertTrue();
      expect(prompt.includes('never output a numeric literal, numeric string')).assertTrue();
      expect(prompt.includes('MetricGrid may use legacy dataPath or direct items')).assertTrue();
      expect(prompt.includes('SegmentedRingChart accepts one or more comparable categories')).assertTrue();
      expect(prompt.includes('array dataPath with paired item-relative labelPath/valuePath')).assertTrue();
      expect(prompt.includes('renderer expands the complete source array')).assertTrue();
      expect(prompt.includes('One category may render as a 100% ring')).assertTrue();
      expect(prompt.includes('1-8 categories are usually easiest to read')).assertTrue();
      expect(prompt.includes('still pass every category without calculating, merging, or truncating them')).assertTrue();
      expect(prompt.includes('renderer keeps the first 8 and combines the remaining values as Other')).assertTrue();
      expect(prompt.includes('direct segments 不是 List 或重复模板')).assertTrue();
      expect(prompt.includes('renderer 不会按源数组自动展开')).assertTrue();
      expect(prompt.includes('必须按数组下标显式枚举全部可用类别')).assertTrue();
      expect(prompt.includes('各 value path 互不重复')).assertTrue();
      expect(prompt.includes('禁止只写 index 0 后期待 renderer 自动展开')).assertTrue();
      expect(prompt.includes('rendered once per item')).assertTrue();
      expect(prompt.includes('MUST output exactly one HeroBanner')).assertTrue();
      expect(prompt.includes('Do not fabricate a HeroBanner summary for an error or no-display-data baseline')).assertTrue();
      expect(prompt.includes('always the first visible element in the main content container')).assertTrue();
      expect(prompt.includes('SurfaceRoot.child must reference a Column')).assertTrue();
      expect(prompt.includes('HeroBanner id must be Column.children[0]')).assertTrue();
      expect(prompt.includes('leaving sibling components disconnected')).assertTrue();
      expect(prompt.includes('Every HeroBanner visible string must be rewritten from the current verified results')).assertFalse();
      expect(prompt.includes('never copy the REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS placeholder')).assertFalse();
      expect(prompt.includes('sampled array length')).assertTrue();
      expect(prompt.includes('/summary/count and /summary/text describe how many DataResult sets')).assertTrue();
      expect(prompt.includes('result.data explicitly labels a scalar as count or total')).assertTrue();
      expect(prompt.includes('result.data.summary text explicitly supports it')).assertTrue();
      expect(prompt.includes('must not mechanically list toolId')).assertTrue();
      expect(prompt.includes('each result gets its own card')).assertFalse();
      expect(prompt.includes('output no SVG')).assertTrue();
      expect(prompt.includes('renderer owns all chart geometry and styling')).assertTrue();
      expect(example.includes('"type"')).assertFalse();
      expect(example.includes('"props"')).assertFalse();
      expect(example.includes('"child":"content"')).assertTrue();
      expect(example.includes('"children":["hero","info","result-list"]')).assertTrue();
      expect(example.includes('"title":"REPLACE_WITH_A_SYNTHESIS_OF_VERIFIED_RESULTS"')).assertTrue();
      expect(example.includes('"text"')).assertFalse();
      expect(example.includes('"body"')).assertFalse();
      expect(example.includes('"path":"/results","componentId":"result-card"')).assertTrue();
      expect(example.includes('"id":"result-card","component":"ExpandableCard"')).assertTrue();
      expect(example.includes('餐馆')).assertFalse();
      expect(example.includes('food')).assertFalse();
      expect(example.includes('GitHub')).assertFalse();
      expect(mergeA2uiLayout(
        uiLabBaseline,
        example,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === uiLabBaseline).assertFalse();
    });

    it('adds bounded presentation decision notes only for the enabled UI Lab mode', 0, () => {
      const disabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON);
      const enabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, UI_AGENT_LAB_COMPONENT_CATALOG_JSON, true);
      const genericEnabled = buildA2uiLayoutSystemPrompt(SURFACE_ID, AIPHONE_COMPONENT_CATALOG_JSON, true);
      expect(disabled.includes('Output exactly one compact JSON line')).assertTrue();
      expect(disabled.includes('<ui_decision_notes>')).assertFalse();
      expect(enabled.includes('exact standalone line <ui_decision_notes>')).assertTrue();
      expect(enabled.includes('exact standalone line </ui_decision_notes>')).assertTrue();
      expect(enabled.includes('exactly one compact A2UI updateComponents JSON line')).assertTrue();
      expect(enabled.includes('exactly two labeled stages in this order')).assertTrue();
      expect(enabled.includes('我拿到了哪些数据')).assertTrue();
      expect(enabled.includes('enumerate every meaningful DataResult field or array grouping')).assertTrue();
      expect(enabled.includes('exact JSON Pointer')).assertTrue();
      expect(enabled.includes('我要把它们放到什么组件里')).assertTrue();
      expect(enabled.includes('map every inventoried path or grouping to the selected component')).assertTrue();
      expect(enabled.includes('at most 2400 characters')).assertTrue();
      expect(enabled.includes('reason it was omitted')).assertFalse();
      expect(enabled.includes('remaining items or grouping')).assertFalse();
      expect(enabled.includes('没有有意义的数据被省略')).assertFalse();
      expect(enabled.includes('bounded presentation summary only')).assertTrue();
      expect(enabled.includes('Never provide hidden reasoning, chain-of-thought')).assertTrue();
      expect(enabled.includes('step-by-step analysis')).assertTrue();
      expect(genericEnabled.includes('Output exactly one compact JSON line')).assertTrue();
      expect(genericEnabled.includes('<ui_decision_notes>')).assertFalse();
    });

    it('keeps the business catalog as the default', 0, () => {
      const merged: string = mergeA2uiLayout(BASELINE, VALID_CANDIDATE, SURFACE_ID, offers());
      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"GenericToolResults"')).assertTrue();
    });

    it('accepts UI Lab components only when the UI Lab catalog is selected', 0, () => {
      const merged: string = mergeA2uiLayout(
        BASELINE,
        LAB_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"MasonryGrid"')).assertTrue();
      expect(mergeA2uiLayout(BASELINE, LAB_CANDIDATE, SURFACE_ID, [])).assertEqual(BASELINE);
    });

    it('keeps the UI Lab allowlist fixed and excludes renderer-only ThinkingStream', 0, () => {
      const catalog = JSON.parse(UI_AGENT_LAB_COMPONENT_CATALOG_JSON) as ComponentCatalogEntry[];
      expect(catalog.length).assertEqual(20);
      for (let index = 0; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(catalog[index].name).assertEqual(LAB_COMPONENT_NAMES[index]);
      }
      let heroUsage: string = '';
      for (let index = 0; index < catalog.length; index++) {
        expect(Object.keys(catalog[index].schema.fields).length > 1).assertTrue();
        if (catalog[index].name === 'HeroBanner') heroUsage = catalog[index].usage;
      }
      const infoRowsUsage = catalog[4].usage;
      const expandableUsage = catalog[10].usage;
      const listUsage = catalog[14].usage;
      expect(infoRowsUsage.includes('dataPath 指向普通对象时必须省略')).assertTrue();
      expect(infoRowsUsage.includes('renderer 会把对象自身的真实字段名和值逐项转成 rows')).assertTrue();
      expect(infoRowsUsage.includes('禁止虚构 /key、/value')).assertTrue();
      expect(infoRowsUsage.includes('Array<{label,value,time?}>')).assertTrue();
      expect(infoRowsUsage.includes('labelPath 与 valuePath')).assertTrue();
      expect(infoRowsUsage.includes('可选 timePath')).assertTrue();
      expect(infoRowsUsage.includes('所有 mapping path 必须是 item 中真实存在的字段')).assertTrue();
      expect(infoRowsUsage.includes('labelPath 必须为每个 item 解析出 string')).assertTrue();
      expect(infoRowsUsage.includes('valuePath/timePath 允许个别 item 缺失或为 null')).assertTrue();
      expect(infoRowsUsage.includes('非空数组至少一个 item 必须有 primitive value')).assertTrue();
      expect(infoRowsUsage.includes('单个事实表或已经整理好的 label/value 信息行')).assertTrue();
      expect(infoRowsUsage.includes('重复的具名实体应使用 List')).assertTrue();
      expect(infoRowsUsage.includes('优先于 List 或 ExpandableCard')).assertFalse();
      expect(expandableUsage.includes('direct rows')).assertTrue();
      expect(expandableUsage.includes('省略 dataPath 不会隐式展示整个 item')).assertTrue();
      expect(expandableUsage.includes('新生成不得使用 dataPath=/')).assertTrue();
      expect(listUsage.includes('{path:ARRAY_PATH,componentId:TEMPLATE_ID}')).assertTrue();
      expect(listUsage.includes('可选 title')).assertTrue();
      expect(heroUsage.includes('主内容容器中的第一个可见元素')).assertTrue();
      expect(heroUsage.includes('必须且只能生成一个 HeroBanner')).assertTrue();
      expect(heroUsage.includes('错误或无可展示数据的 baseline 不得强造 HeroBanner 概述')).assertTrue();
      expect(heroUsage.includes('SurfaceRoot.child 必须指向 Column')).assertTrue();
      expect(heroUsage.includes('Column.children[0]')).assertTrue();
      expect(heroUsage.includes('不得让 root 只连接 HeroBanner 而留下孤立组件')).assertTrue();
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes('"name":"BentoGrid"')).assertFalse();
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes('"name":"ThinkingStream"')).assertFalse();
      const metric = catalog[16].schema;
      const infoRows = catalog[4].schema;
      const expandable = catalog[10].schema;
      const list = catalog[14].schema;
      const metricItems = metric.fields['items'];
      const metricItemFields = metricItems.items?.fields;
      const ringSegments = catalog[17].schema.fields['segments'];
      const ringItemFields = ringSegments.items?.fields;
      expect(metric.requireAny?.[0].join(',')).assertEqual('dataPath,items');
      expect(metric.exactlyOne?.[0].join(',')).assertEqual('dataPath,items');
      expect(metricItems.maxItems).assertEqual(6);
      expect(metricItems.valuePolicy).assertEqual('literal');
      expect(metricItemFields?.['label'].valuePolicy).assertEqual('literal-or-path');
      expect(metricItemFields?.['value'].type).assertEqual('number');
      expect(metricItemFields?.['value'].valuePolicy).assertEqual('path-only');
      expect(infoRows.fields['labelPath'].valuePolicy).assertEqual('literal');
      expect(infoRows.fields['labelPath'].minLength).assertEqual(1);
      expect(infoRows.fields['valuePath'].valuePolicy).assertEqual('literal');
      expect(infoRows.fields['timePath'].valuePolicy).assertEqual('literal');
      const expandableRows = expandable.fields['rows'];
      const expandableRowFields = expandableRows.items?.fields;
      expect(expandableRows.type).assertEqual('array');
      expect(expandableRows.minItems).assertEqual(1);
      expect(expandableRows.maxItems).assertEqual(8);
      expect(expandableRowFields?.['label'].valuePolicy).assertEqual('literal-or-path');
      expect(expandableRowFields?.['value'].type).assertEqual('string');
      expect(expandableRowFields?.['value'].valuePolicy).assertEqual('path-only');
      expect(expandable.atMostOne?.[0].join(',')).assertEqual('dataPath,rows');
      expect(list.fields['title'].valuePolicy).assertEqual('literal-or-path');
      expect(ringItemFields?.['label'].valuePolicy).assertEqual('literal-or-path');
      expect(ringItemFields?.['value'].valuePolicy).assertEqual('path-only');
      expect(catalog[17].schema.fields['labelPath'].valuePolicy).assertEqual('literal');
      expect(catalog[17].schema.fields['valuePath'].valuePolicy).assertEqual('literal');
      expect(catalog[17].usage.includes('已验证的占比、ratio 或类别构成信息')).assertTrue();
      expect(catalog[17].usage.includes('单类别可显示 100% 环图')).assertTrue();
      expect(catalog[17].usage.includes('通常 1-8 个类别的可读性最佳')).assertTrue();
      expect(catalog[17].usage.includes('完整展开源数组')).assertTrue();
      expect(catalog[17].usage.includes('direct segments 不是 List 或重复模板')).assertTrue();
      expect(catalog[17].usage.includes('dataPath 指向类别对象数组')).assertTrue();
      expect(catalog[17].usage.includes('每个 direct segment 的 label 与 value 必须对应同一源项')).assertTrue();
      expect(catalog[17].usage.includes('各 value path 互不重复')).assertTrue();
      expect(catalog[17].usage.includes('禁止只写 index 0 后期待 renderer 自动展开')).assertTrue();
      expect(catalog[17].usage.includes('超过 8 个类别时仍必须传入完整数据')).assertTrue();
      expect(catalog[17].usage.includes('UI Agent 不得自行计算、合并或截断')).assertTrue();
      expect(catalog[17].usage.includes('renderer 会保留前 8 项并把其余项求和显示为固定的“其他”')).assertTrue();
      expect(catalog[17].schema.exactlyOne?.[0].join(',')).assertEqual('dataPath,segments');

      const thinkingCandidate =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","thinking"]},' +
        '{"id":"hero","component":"HeroBanner","title":"Verified"},' +
        '{"id":"thinking","component":"ThinkingStream","dataPath":"/genericToolResults"}]}}';
      const thinkingRejected = mergeA2uiLayoutWithStatus(
        BASELINE, thinkingCandidate, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(thinkingRejected.accepted).assertFalse();
      expect(thinkingRejected.diagnostic?.componentId).assertEqual('thinking');
      expect(thinkingRejected.diagnostic?.rule).assertEqual('component_not_allowed');
      expect(UI_AGENT_LAB_COMPONENT_CATALOG_JSON.includes(
        '"segments":{"type":"array","valuePolicy":"literal","minItems":1,"maxItems"'
      )).assertFalse();
      expect(ringSegments.maxItems === undefined).assertTrue();
      for (let index = 15; index < LAB_COMPONENT_NAMES.length; index++) {
        expect(AIPHONE_COMPONENT_CATALOG_JSON.includes('"name":"' + LAB_COMPONENT_NAMES[index] + '"')).assertFalse();
      }
      expect(mergeA2uiLayout(
        BASELINE,
        BENTO_CANDIDATE,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('accepts constrained UI Lab presentation components and rejects unsafe shapes', 0, () => {
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","metrics","ring","line","heat"]},' +
        '{"id":"hero","component":"HeroBanner","text":"OVERVIEW","title":"Summary","body":"Verified results."},' +
        '{"id":"metrics","component":"MetricGrid","title":"Metrics","dataPath":"/genericToolResults"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/genericToolResults"},' +
        '{"id":"line","component":"MultiSeriesLineChart","dataPath":"/genericToolResults"},' +
        '{"id":"heat","component":"MatrixHeatmap","body":"Activity","dataPath":"/genericToolResults"}' +
        ']}}';
      const duplicateHero = valid.replace(
        '"children":["hero","metrics","ring","line","heat"]',
        '"children":["hero","hero-2","metrics","ring","line","heat"]'
      ).replace(
        '{"id":"metrics"',
        '{"id":"hero-2","component":"HeroBanner","title":"Second"},{"id":"metrics"'
      );
      const invalid: string[] = [
        valid.replace(',"title":"Summary"', ''),
        valid.replace('"title":"Summary"', '"title":"Summary","dataPath":"/summary"'),
        duplicateHero,
        valid.replace('"title":"Metrics","dataPath":"/genericToolResults"', '"title":"Metrics"'),
        valid.replace('"component":"SegmentedRingChart","dataPath"', '"component":"SegmentedRingChart","actions":[],"dataPath"'),
        valid.replace('"component":"MultiSeriesLineChart","dataPath"', '"component":"MultiSeriesLineChart","children":[],"dataPath"'),
        valid.replace('"component":"MatrixHeatmap","body"', '"component":"MatrixHeatmap","path":"M0 0","body"')
      ];

      expect(mergeA2uiLayout(
        BASELINE,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === BASELINE).assertFalse();
      expect(mergeA2uiLayout(BASELINE, valid, SURFACE_ID, [])).assertEqual(BASELINE);
      for (let index = 0; index < invalid.length; index++) {
        expect(mergeA2uiLayout(
          BASELINE,
          invalid[index],
          SURFACE_ID,
          [],
          UI_AGENT_LAB_COMPONENT_CATALOG_JSON
        )).assertEqual(BASELINE);
      }
    });

    it('validates direct chart fields recursively from the catalog and exact host paths', 0, () => {
      const bindingBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary/text","value":"Verified"}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/followers","value":42}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/stars","value":7}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/metrics/starLabel","value":"Stars"}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/typescript","value":80}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/arkts","value":20}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","metrics","ring"]},' +
        '{"id":"hero","component":"HeroBanner","title":{"path":"/summary/text"}},' +
        '{"id":"metrics","component":"MetricGrid","title":"Repository metrics","items":[' +
        '{"id":"followers","label":"Followers","value":{"path":"/metrics/followers"}},' +
        '{"id":"stars","label":{"path":"/metrics/starLabel"},"value":{"path":"/metrics/stars"}}]},' +
        '{"id":"ring","component":"SegmentedRingChart","segments":[' +
        '{"id":"typescript","label":"TypeScript","value":{"path":"/languages/typescript"}},' +
        '{"id":"arkts","label":"ArkTS","value":{"path":"/languages/arkts"}}]}' +
        ']}}';
      const merged = mergeA2uiLayout(
        bindingBaseline,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === bindingBaseline).assertFalse();
      expect(merged.includes('"items"')).assertTrue();
      expect(merged.includes('"segments"')).assertTrue();
      expect(merged.includes('"title":{"path":"/summary/text"}')).assertTrue();
      expect(merged.includes('"properties"')).assertFalse();

      const singleSegment = valid.replace(
        ',{"id":"arkts","label":"ArkTS","value":{"path":"/languages/arkts"}}',
        ''
      );
      const singleSegmentMerged = mergeA2uiLayoutWithStatus(
        bindingBaseline,
        singleSegment,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(singleSegmentMerged.accepted).assertTrue();
      expect(singleSegmentMerged.reason).assertEqual('accepted');
      expect(singleSegmentMerged.jsonl === bindingBaseline).assertFalse();
      expect(singleSegmentMerged.jsonl.includes('"component":"HeroBanner"')).assertTrue();
      expect(singleSegmentMerged.jsonl.includes('"component":"MetricGrid"')).assertTrue();
      expect(singleSegmentMerged.jsonl.includes('"component":"SegmentedRingChart"')).assertTrue();
      expect(singleSegmentMerged.jsonl.includes('"label":"TypeScript"')).assertTrue();

      const manySegmentBaseline = bindingBaseline +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/java","value":7}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/go","value":6}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/rust","value":5}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/python","value":4}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/kotlin","value":3}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/swift","value":2}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages/cpp","value":1}}\n';
      const manySegments = valid.replace(
        '{"id":"arkts","label":"ArkTS","value":{"path":"/languages/arkts"}}]}',
        '{"id":"arkts","label":"ArkTS","value":{"path":"/languages/arkts"}},' +
          '{"id":"java","label":"Java","value":{"path":"/languages/java"}},' +
          '{"id":"go","label":"Go","value":{"path":"/languages/go"}},' +
          '{"id":"rust","label":"Rust","value":{"path":"/languages/rust"}},' +
          '{"id":"python","label":"Python","value":{"path":"/languages/python"}},' +
          '{"id":"kotlin","label":"Kotlin","value":{"path":"/languages/kotlin"}},' +
          '{"id":"swift","label":"Swift","value":{"path":"/languages/swift"}},' +
          '{"id":"cpp","label":"C++","value":{"path":"/languages/cpp"}}]}'
      );
      const manySegmentMerged = mergeA2uiLayoutWithStatus(
        manySegmentBaseline,
        manySegments,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(manySegmentMerged.accepted).assertTrue();
      expect(manySegmentMerged.jsonl.includes('"label":"C++"')).assertTrue();

      const invalid: string[] = [
        valid.replace('{"path":"/metrics/followers"}', '42'),
        valid.replace('{"path":"/metrics/followers"}', '"42"'),
        valid.replace('{"path":"/metrics/followers"}', '{"expression":"metrics.followers"}'),
        valid.replace('{"path":"/metrics/followers"}', '{"FunctionCall":{"name":"read"}}'),
        valid.replace('{"path":"/metrics/followers"}', '{"path":"/metrics/followers","fallback":0}'),
        valid.replace('"label":"Followers"', '"label":12'),
        valid.replace('"label":"Followers"', '"label":"Followers","color":"red"'),
        valid.replace('"component":"MetricGrid","title"',
          '"component":"MetricGrid","dataPath":"/genericToolResults","title"'),
        valid.replace('"component":"SegmentedRingChart","segments"',
          '"component":"SegmentedRingChart","dataPath":"/genericToolResults","segments"'),
        valid.replace(
          '"segments":[{"id":"typescript","label":"TypeScript","value":{"path":"/languages/typescript"}},' +
            '{"id":"arkts","label":"ArkTS","value":{"path":"/languages/arkts"}}]',
          '"segments":[]'
        ),
        valid.replace('{"path":"/summary/text"}', '"/summary/text"'),
        valid.replace('"title":{"path":"/summary/text"}',
          '"title":"Summary","body":"/summary/text"'),
        valid.replace('{"path":"/summary/text"}', '{"path":"/summary/private"}'),
        valid.replace('"component":"MetricGrid","title"', '"component":"MetricGrid","properties":{},"title"')
      ];
      for (let index = 0; index < invalid.length; index++) {
        expect(mergeA2uiLayout(
          bindingBaseline,
          invalid[index],
          SURFACE_ID,
          [],
          UI_AGENT_LAB_COMPONENT_CATALOG_JSON
        )).assertEqual(bindingBaseline);
      }
      const dataModelCandidate =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test",' +
        '"path":"/metrics/followers","value":42}}';
      expect(mergeA2uiLayout(
        bindingBaseline,
        dataModelCandidate,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(bindingBaseline);
    });

    it('validates item-relative array mappings against the current snapshot sample', 0, () => {
      const mappingBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/activity","value":[' +
        '{"label":"Push","time":"08-07 10:00","summary":"Pushed commits",' +
        '"details":{"text":"Pushed commits"},"epoch":1},' +
        '{"label":"Issue"},{"label":"Release","summary":null,"time":null}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test",' +
        '"path":"/activityWithoutValues","value":[' +
        '{"label":"Push"},{"label":"Issue","summary":null}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/languages","value":[' +
        '{"name":"TypeScript","share":80,"textShare":"80"},' +
        '{"name":"ArkTS","share":20,"textShare":"20"}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/singleLanguage","value":[' +
        '{"name":"TypeScript","share":100}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/manyLanguages","value":[' +
        '{"name":"TypeScript","share":30},{"name":"ArkTS","share":20},' +
        '{"name":"Java","share":12},{"name":"Go","share":10},{"name":"Rust","share":8},' +
        '{"name":"Python","share":7},{"name":"Kotlin","share":5},{"name":"Swift","share":4},' +
        '{"name":"C++","share":4}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/noLanguages","value":[]}}\n';
      const objectMappingBaseline = mappingBaseline +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/profile",' +
        '"value":{"name":"Octocat","company":"GitHub"}}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","activity","ring"]},' +
        '{"id":"hero","component":"HeroBanner","title":"Repository"},' +
        '{"id":"activity","component":"InfoRows","dataPath":"/activity",' +
        '"labelPath":"/label","valuePath":"/summary","timePath":"/time"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/languages",' +
        '"labelPath":"/name","valuePath":"/share"}]}}';
      const merged = mergeA2uiLayoutWithStatus(
        mappingBaseline,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged.accepted).assertTrue();
      expect(merged.reason).assertEqual('accepted');
      expect(merged.jsonl.includes('"dataPath":"/activity"')).assertTrue();
      expect(merged.jsonl.includes('"labelPath":"/label"')).assertTrue();
      expect(merged.jsonl.includes('"timePath":"/time"')).assertTrue();
      expect(merged.jsonl.includes('"valuePath":"/share"')).assertTrue();

      const singleLanguage = valid.replace('"dataPath":"/languages"', '"dataPath":"/singleLanguage"');
      const singleLanguageMerged = mergeA2uiLayoutWithStatus(
        mappingBaseline,
        singleLanguage,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(singleLanguageMerged.accepted).assertTrue();
      expect(singleLanguageMerged.jsonl.includes('"dataPath":"/singleLanguage"')).assertTrue();

      const manyLanguages = valid.replace('"dataPath":"/languages"', '"dataPath":"/manyLanguages"');
      const manyLanguagesMerged = mergeA2uiLayoutWithStatus(
        mappingBaseline,
        manyLanguages,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(manyLanguagesMerged.accepted).assertTrue();
      expect(manyLanguagesMerged.jsonl.includes('"dataPath":"/manyLanguages"')).assertTrue();

      const noLanguages = valid.replace('"dataPath":"/languages"', '"dataPath":"/noLanguages"');
      const noLanguagesMerged = mergeA2uiLayoutWithStatus(
        mappingBaseline,
        noLanguages,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(noLanguagesMerged.accepted).assertFalse();
      expect(noLanguagesMerged.diagnostic?.componentId).assertEqual('ring');
      expect(noLanguagesMerged.diagnostic?.rule).assertEqual('mapping_source_size_invalid');

      const ordinaryObject = valid.replace(
        '{"id":"activity","component":"InfoRows","dataPath":"/activity",' +
          '"labelPath":"/label","valuePath":"/summary","timePath":"/time"}',
        '{"id":"activity","component":"InfoRows","dataPath":"/profile"}'
      );
      const ordinaryObjectMerged = mergeA2uiLayoutWithStatus(
        objectMappingBaseline,
        ordinaryObject,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(ordinaryObjectMerged.accepted).assertTrue();
      expect(ordinaryObjectMerged.jsonl.includes('"dataPath":"/profile"')).assertTrue();

      const inventedObjectMapping = ordinaryObject.replace(
        '"dataPath":"/profile"',
        '"dataPath":"/profile","labelPath":"/key","valuePath":"/value"'
      );
      const objectMappingRejected = mergeA2uiLayoutWithStatus(
        objectMappingBaseline,
        inventedObjectMapping,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(objectMappingRejected.accepted).assertFalse();
      expect(objectMappingRejected.reason).assertEqual('candidate_rejected');
      expect(objectMappingRejected.diagnostic?.componentId).assertEqual('activity');
      expect(objectMappingRejected.diagnostic?.rule).assertEqual('mapping_source_not_array');

      const invalid: string[] = [
        valid.replace(',"valuePath":"/summary"', ''),
        valid.replace('"valuePath":"/summary"', '"valuePath":"summary"'),
        valid.replace('"labelPath":"/label"', '"labelPath":"/missing"'),
        valid.replace('"valuePath":"/summary"', '"valuePath":"/details"'),
        valid.replace('"timePath":"/time"', '"timePath":"/epoch"'),
        valid.replace('"dataPath":"/activity"', '"dataPath":"/activityWithoutValues"'),
        valid.replace('"valuePath":"/share"', '"valuePath":"/textShare"')
      ];
      for (let index = 0; index < invalid.length; index++) {
        expect(mergeA2uiLayout(
          mappingBaseline,
          invalid[index],
          SURFACE_ID,
          [],
          UI_AGENT_LAB_COMPONENT_CATALOG_JSON
        )).assertEqual(mappingBaseline);
      }
    });

    it('derives exact binding paths recursively from parent data values', 0, () => {
      const parentValueBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test",' +
        '"path":"/results","value":[{"data":{"profile":{"name":"Octocat"},' +
        '"slash/key":{"til~de":"escaped"}}}]}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"hero"},' +
        '{"id":"hero","component":"HeroBanner",' +
        '"title":{"path":"/results/0/data/slash~1key/til~0de"}}]}}';
      const missingSibling = valid.replace(
        '/results/0/data/slash~1key/til~0de',
        '/results/0/data/profile/missing'
      );
      const componentOnlyBaseline = parentValueBaseline.replace(
        '"dataPath":"/genericToolResults"',
        '"dataPath":"/component-only"'
      );
      const componentOnlyPath = valid.replace(
        '/results/0/data/slash~1key/til~0de',
        '/component-only'
      );

      expect(mergeA2uiLayout(
        parentValueBaseline,
        valid,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === parentValueBaseline).assertFalse();
      expect(mergeA2uiLayout(
        parentValueBaseline,
        missingSibling,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(parentValueBaseline);
      expect(mergeA2uiLayout(
        componentOnlyBaseline,
        componentOnlyPath,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(componentOnlyBaseline);
    });

    it('accepts an official List template and rejects unbound or invalid scoped layouts', 0, () => {
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"items"},' +
        '{"id":"items","component":"List","children":{"path":"/genericToolResults","componentId":"item-card"}},' +
        '{"id":"item-card","component":"ExpandableCard"}]}}';
      const unbound = valid.replace(
        '"children":{"path":"/genericToolResults","componentId":"item-card"}',
        '"children":["item-card"]'
      );
      const invalidPath = valid.replace('/genericToolResults', '/secret');
      const listAction = valid.replace(
        '"component":"List","children"',
        '"component":"List","actions":[],"children"'
      );
      const templateAction = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"ExpandableCard","actions":[]}'
      );
      const heroTemplate = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"HeroBanner","title":"Repeated summary"}'
      );
      const templateRootScope = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"ExpandableCard","dataPath":"/"}'
      );
      const nestedList = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"List","children":' +
        '{"path":"/genericToolResults","componentId":"nested-card"}},' +
        '{"id":"nested-card","component":"ExpandableCard"}'
      );
      const nestedTemplateAction = valid.replace(
        '{"id":"item-card","component":"ExpandableCard"}',
        '{"id":"item-card","component":"Column","children":["nested-action"]},' +
        '{"id":"nested-action","component":"ActionBar","actions":[]}'
      );
      const rootScope = valid.replace(
        '{"id":"root","component":"SurfaceRoot","child":"items"}',
        '{"id":"root","component":"SurfaceRoot","child":"items","dataPath":"/"}'
      );
      const scopeBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/","value":{}}}\n';
      const merged = mergeA2uiLayout(BASELINE, valid, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON);

      expect(merged === BASELINE).assertFalse();
      expect(merged.includes('"component":"List"')).assertTrue();
      expect(merged.includes('"componentId":"item-card"')).assertTrue();
      expect(mergeA2uiLayout(BASELINE, unbound, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, invalidPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, listAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, templateAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, heroTemplate, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        templateRootScope,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === BASELINE).assertFalse();
      expect(mergeA2uiLayout(BASELINE, nestedList, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, nestedTemplateAction, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(BASELINE);
      expect(mergeA2uiLayout(scopeBaseline, rootScope, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON)).assertEqual(scopeBaseline);
    });

    it('validates List template catalog bindings against each array item scope', 0, () => {
      const itemBaseline = BASELINE +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/","value":' +
        '{"summary":{"text":"Recent activity"},"results":[{"data":{"providerData":{"recentActivity":[' +
        '{"kind":"PushEvent","summary":"Pushed commits"},' +
        '{"kind":"IssueEvent","summary":"Opened issue"}]}}}]}}}\n';
      const valid =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"items"},' +
        '{"id":"items","component":"List","title":{"path":"/summary/text"},"children":{' +
        '"path":"/results/0/data/providerData/recentActivity","componentId":"item-column"}},' +
        '{"id":"item-column","component":"Column","children":["item-card"]},' +
        '{"id":"item-card","component":"ExpandableCard",' +
        '"title":{"path":"/kind"},"body":{"path":"/summary"}}]}}';
      const missing = valid.replace('{"path":"/summary"}', '{"path":"/missing"}');
      const absoluteInItem = valid.replace('{"path":"/kind"}',
        '{"path":"/results/0/data/providerData/recentActivity/0/kind"}');
      const textTemplate = valid.replace('"component":"ExpandableCard"', '"component":"Text"');
      const literalTitlePath = textTemplate.replace('{"path":"/kind"}', '"/kind"');
      const literalBodyPath = textTemplate.replace('{"path":"/summary"}', '"/summary"');
      const literalListTitlePath = valid.replace('{"path":"/summary/text"}', '"/summary/text"');
      const directRows = valid.replace(
        '"body":{"path":"/summary"}',
        '"rows":[{"label":"摘要","value":{"path":"/summary"}},' +
          '{"label":{"path":"/kind"},"value":{"path":"/summary"}}]'
      );
      const missingRowPath = directRows.replace(
        '"value":{"path":"/summary"}',
        '"value":{"path":"/missing"}'
      );
      const absoluteRowPath = directRows.replace(
        '"value":{"path":"/summary"}',
        '"value":{"path":"/results/0/data/providerData/recentActivity/0/summary"}'
      );
      const literalRowValue = directRows.replace(
        '"value":{"path":"/summary"}',
        '"value":"Pushed commits"'
      );
      const numericRowValue = directRows.replace(
        '"value":{"path":"/summary"}',
        '"value":1'
      );
      const rowsWithDataPath = directRows.replace(
        '"component":"ExpandableCard",',
        '"component":"ExpandableCard","dataPath":"/",'
      );

      const merged = mergeA2uiLayout(
        itemBaseline, valid, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(merged === itemBaseline).assertFalse();
      expect(merged).assertContain('"title":{"path":"/kind"}');
      expect(mergeA2uiLayout(
        itemBaseline, textTemplate, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === itemBaseline).assertFalse();
      expect(mergeA2uiLayout(
        itemBaseline, missing, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, absoluteInItem, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, literalTitlePath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, literalBodyPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, literalListTitlePath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, directRows, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      ) === itemBaseline).assertFalse();
      expect(mergeA2uiLayout(
        itemBaseline, missingRowPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, absoluteRowPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, literalRowValue, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, numericRowValue, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
      expect(mergeA2uiLayout(
        itemBaseline, rowsWithDataPath, SURFACE_ID, [], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(itemBaseline);
    });

    it('validates mapped arrays within every List item scope', 0, () => {
      const rootCollisions =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/details",' +
        '"value":[{"label":"Wrong root details","value":{"nested":true}}]}}\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/shares",' +
        '"value":[{"name":"Wrong root shares","share":"not-a-number"}]}}\n';
      const validGroups =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/groups","value":[' +
        '{"details":[{"label":"Repositories","value":12}],"shares":[' +
        '{"name":"TypeScript","share":75},{"name":"ArkTS","share":25}]},' +
        '{"details":[{"label":"Repositories","value":8}],"shares":[' +
        '{"name":"Java","share":60},{"name":"Kotlin","share":40}]}]}}\n';
      const invalidInfoGroups =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/groups","value":[' +
        '{"details":[{"label":"Repositories","value":12}],"shares":[' +
        '{"name":"TypeScript","share":100}]},' +
        '{"details":{"label":"Repositories","value":8},"shares":[' +
        '{"name":"Java","share":100}]}]}}\n';
      const invalidRingGroups =
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/groups","value":[' +
        '{"details":[{"label":"Repositories","value":12}],"shares":[' +
        '{"name":"TypeScript","share":100}]},' +
        '{"details":[{"label":"Repositories","value":8}],"shares":' +
        '{"name":"Java","share":100}}]}}\n';
      const candidate =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"surface-layout-test","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"groups"},' +
        '{"id":"groups","component":"List","children":{"path":"/groups","componentId":"group"}},' +
        '{"id":"group","component":"Column","children":["details","ring"]},' +
        '{"id":"details","component":"InfoRows","dataPath":"/details",' +
        '"labelPath":"/label","valuePath":"/value"},' +
        '{"id":"ring","component":"SegmentedRingChart","dataPath":"/shares",' +
        '"labelPath":"/name","valuePath":"/share"}]}}';

      const validMerged = mergeA2uiLayoutWithStatus(
        BASELINE + rootCollisions + validGroups,
        candidate,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(validMerged.accepted).assertTrue();
      expect(validMerged.jsonl).assertContain('"dataPath":"/details"');
      expect(validMerged.jsonl).assertContain('"dataPath":"/shares"');

      const infoRejected = mergeA2uiLayoutWithStatus(
        BASELINE + rootCollisions + invalidInfoGroups,
        candidate,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(infoRejected.accepted).assertFalse();
      expect(infoRejected.diagnostic?.componentId).assertEqual('details');
      expect(infoRejected.diagnostic?.rule).assertEqual('mapping_source_not_array');

      const ringRejected = mergeA2uiLayoutWithStatus(
        BASELINE + rootCollisions + invalidRingGroups,
        candidate,
        SURFACE_ID,
        [],
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      expect(ringRejected.accepted).assertFalse();
      expect(ringRejected.diagnostic?.componentId).assertEqual('ring');
      expect(ringRejected.diagnostic?.rule).assertEqual('mapping_source_not_array');
    });

    it('rejects business components when the UI Lab catalog is selected', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE,
        SURFACE_ID,
        offers(),
        UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for wrong surface or extra envelopes', 0, () => {
      const wrongSurface = VALID_CANDIDATE.replace(SURFACE_ID, 'other-surface');
      const extra = VALID_CANDIDATE + '\n' +
        '{"version":"v0.9.1","updateDataModel":{"surfaceId":"surface-layout-test","path":"/summary","value":{}}}';
      expect(mergeA2uiLayout(BASELINE, wrongSurface, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, extra, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for unknown components and data paths', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('GenericToolResults', 'UnknownCard'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('/genericToolResults', '/secret'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('/genericToolResults', '/genericToolResults/private'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for literal actions and unknown offers', 0, () => {
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('{"offerId":"detail:1"}', '{"id":"hotel.detail","args":{"hotelId":2}}'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
      expect(mergeA2uiLayout(
        BASELINE,
        VALID_CANDIDATE.replace('detail:1', 'detail:unknown'),
        SURFACE_ID,
        offers()
      )).assertEqual(BASELINE);
    });

    it('falls back exactly for duplicate offers and disconnected trees', 0, () => {
      const duplicate = VALID_CANDIDATE.replace(
        '{"offerId":"detail:1"}',
        '{"offerId":"detail:1"},{"offerId":"detail:1"}'
      );
      const disconnected = VALID_CANDIDATE.replace(
        '"children":["title","results","actions"]',
        '"children":["title","results"]'
      );
      expect(mergeA2uiLayout(BASELINE, duplicate, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, disconnected, SURFACE_ID, offers())).assertEqual(BASELINE);
    });

    it('falls back exactly for cycles and unknown fields', 0, () => {
      const cycle = VALID_CANDIDATE.replace(
        '{"id":"title","component":"Text","text":"酒店结果","variant":"h3"}',
        '{"id":"title","component":"Text","child":"root","text":"酒店结果","variant":"h3"}'
      );
      const unknownField = VALID_CANDIDATE.replace(
        '"component":"Column"',
        '"component":"Column","onClick":"unsafe"'
      );
      expect(mergeA2uiLayout(BASELINE, cycle, SURFACE_ID, offers())).assertEqual(BASELINE);
      expect(mergeA2uiLayout(BASELINE, unknownField, SURFACE_ID, offers())).assertEqual(BASELINE);
    });
  });
}
