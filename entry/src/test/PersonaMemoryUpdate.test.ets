import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { describe, it, expect } from '@ohos/hypium';
import { actionsOf, labelValues } from '@loop/agent-core';
import { WaterfallExplicitPreference } from '@loop/agent-core';
import { configureDefaultPersonaStoreForTests } from '../main/ets/model/PersonaStore';
import { PreferencesPersonaPackStore } from '../main/ets/model/PersonaPreferencesStore';
import {
  mergePersonaStablePreference,
  memoryUpdateSurface,
  parsePersonaMemoryUpdateInput,
  isStableWaterfallContentPreference,
  waterfallExplicitPreferencesFromStatement,
  PersonaMemorySuggestedAction,
  PersonaMemoryUpdateRequest
} from '../main/ets/model/PersonaMemoryUpdate';

class FailingPersonaPreferences {
  putSync(_key: string, _value: preferences.ValueType): void {}

  flushSync(): void {
    throw new Error('durable write failed');
  }
}

export default function personaMemoryUpdateTest() {
  describe('personaMemoryUpdate', () => {
    it('recognizes only stable Waterfall content preferences', 0, () => {
      expect(isStableWaterfallContentPreference('以后多推荐 AI 视频')).assertTrue();
      expect(isStableWaterfallContentPreference('我不喜欢娱乐八卦')).assertTrue();
      expect(isStableWaterfallContentPreference('少给我看 X 的内容')).assertTrue();
      expect(isStableWaterfallContentPreference('我喜欢清淡口味')).assertFalse();
      expect(isStableWaterfallContentPreference('帮我搜索 AI 视频')).assertFalse();
      expect(isStableWaterfallContentPreference('今天聊聊电影')).assertFalse();
    });

    it('compiles stable content preferences into deterministic rules', 0, () => {
      const ai: WaterfallExplicitPreference[] = waterfallExplicitPreferencesFromStatement('以后多推荐 AI 视频');
      expect(ai.map((rule: WaterfallExplicitPreference): string =>
        rule.dimension + ':' + rule.key + ':' + rule.effect).join(',')).assertEqual(
        'format:landscape_video:boost,format:portrait_video:boost,topic:AI:boost');
      const gossip: WaterfallExplicitPreference[] =
        waterfallExplicitPreferencesFromStatement('我不喜欢娱乐八卦');
      expect(gossip[0].dimension + ':' + gossip[0].key + ':' + gossip[0].effect)
        .assertEqual('topic:娱乐八卦:block');
      const x: WaterfallExplicitPreference[] = waterfallExplicitPreferencesFromStatement('少给我看 X 的内容');
      expect(x.length).assertEqual(1);
      expect(x[0].dimension + ':' + x[0].key + ':' + x[0].effect)
        .assertEqual('source:x:downweight');
      expect(waterfallExplicitPreferencesFromStatement('帮我搜索 AI 视频').length).assertEqual(0);
    });

    it('reports a durable persona memory write failure', 0, () => {
      configureDefaultPersonaStoreForTests();
      const native = new FailingPersonaPreferences() as Object as preferences.Preferences;
      const context = new Object() as common.Context;
      expect(new PreferencesPersonaPackStore(context, native).saveSync()).assertFalse();
    });
    it('parses a valid memory.update input for the active persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput('{"personaId":"food_companion","summary":"只喝瑞幸咖啡","memoryText":"用户咖啡偏好：只喝瑞幸咖啡。","reason":"用户明确表达长期饮品偏好","suggestedAction":{"label":"按新偏好重新查咖啡","prompt":"点一杯咖啡","toolId":"food.search"}}', 'food_companion');

      expect(update === null).assertFalse();
      const parsed = update as PersonaMemoryUpdateRequest;
      expect(parsed.personaId).assertEqual('food_companion');
      expect(parsed.summary).assertEqual('只喝瑞幸咖啡');
      expect(parsed.memoryText).assertEqual('用户咖啡偏好：只喝瑞幸咖啡。');
      expect(parsed.suggestedAction === undefined).assertFalse();
      expect((parsed.suggestedAction as PersonaMemorySuggestedAction).label).assertEqual('按新偏好重新查咖啡');
    });

    it('defaults an empty personaId to the active persona', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput(JSON.stringify({
        summary: '只喝瑞幸咖啡',
        memoryText: '用户咖啡偏好：只喝瑞幸咖啡。'
      }), 'food_companion');

      expect(update === null).assertFalse();
      expect((update as PersonaMemoryUpdateRequest).personaId).assertEqual('food_companion');
    });

    it('uses the active persona when model-supplied personaId differs', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'shopping_companion',
        summary: '只坐高铁二等座',
        memoryText: '用户出行偏好：只坐高铁二等座。'
      }), 'travel_companion');

      expect(update === null).assertFalse();
      expect((update as PersonaMemoryUpdateRequest).personaId).assertEqual('travel_companion');
    });

    it('rejects unknown active personas and empty memory text', 0, () => {
      configureDefaultPersonaStoreForTests();
      expect(parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'food_companion',
        summary: '偏好',
        memoryText: '用户偏好：测试。'
      }), 'missing') === null).assertTrue();

      expect(parsePersonaMemoryUpdateInput(JSON.stringify({
        personaId: 'food_companion',
        summary: '偏好',
        memoryText: ''
      }), 'food_companion') === null).assertTrue();
    });

    it('inserts durable memory only into Stable Preferences and preserves the document', 0, () => {
      const current = [
        '---',
        'owner: food_companion',
        '---',
        '# 饮食搭子 Memory',
        '',
        '## Stable Preferences',
        '- 半糖',
        '',
        '## Evidence',
        '- 历史示例必须原样保留。'
      ].join('\n');
      const merged: string =
        mergePersonaStablePreference(current, '用户咖啡偏好：只喝瑞幸咖啡。');

      expect(merged.indexOf('owner: food_companion')).assertLarger(-1);
      expect(merged.indexOf('- 半糖')).assertLarger(-1);
      expect(merged.indexOf('- 用户咖啡偏好：只喝瑞幸咖啡。')).assertLarger(-1);
      expect(merged.indexOf('## Evidence')).assertLarger(-1);
      expect(merged.indexOf('历史示例必须原样保留。')).assertLarger(-1);
      expect(merged.indexOf('用户咖啡偏好：只喝瑞幸咖啡。') <
        merged.indexOf('## Evidence')).assertTrue();
      expect(mergePersonaStablePreference(merged, '用户咖啡偏好：只喝瑞幸咖啡。'))
        .assertEqual(merged);
    });

    it('creates Stable Preferences before Evidence when the section is absent', 0, () => {
      const current = '# Memory\n\n## Evidence\n- 保留来源证据。';
      const merged = mergePersonaStablePreference(current, '用户常驻北京。');

      expect(merged.indexOf('## Stable Preferences')).assertLarger(-1);
      expect(merged.indexOf('- 用户常驻北京。')).assertLarger(-1);
      expect(merged.indexOf('## Stable Preferences') < merged.indexOf('## Evidence')).assertTrue();
      expect(merged.indexOf('- 保留来源证据。')).assertLarger(-1);
    });

    it('builds a summarized InfoRows surface with rerun and edit actions', 0, () => {
      configureDefaultPersonaStoreForTests();
      const update = parsePersonaMemoryUpdateInput('{"personaId":"food_companion","summary":"只喝瑞幸咖啡","memoryText":"用户咖啡偏好：只喝瑞幸咖啡。","suggestedAction":{"label":"按新偏好重新查咖啡","prompt":"点一杯咖啡","toolId":"food.search"}}', 'food_companion') as PersonaMemoryUpdateRequest;

      const surface = memoryUpdateSurface('surface_model', update);
      const card = surface.components[1];
      const rows = labelValues(surface, card);
      const actions = actionsOf(card);

      expect(surface.title).assertEqual('饮食搭子已更新记忆');
      expect(rows[0].label).assertEqual('已记录');
      expect(rows[1].label).assertEqual('原因');
      expect(rows[2].label).assertEqual('Memory 摘要');
      expect(rows[2].value).assertEqual('用户咖啡偏好：只喝瑞幸咖啡。');
      expect(rows[3].label).assertEqual('Soul 摘要');
      expect(actions[0].label).assertEqual('按新偏好重新查咖啡');
      expect(actions[0].kind).assertEqual('prompt');
      expect(actions[0].prompt).assertEqual('点一杯咖啡');
      expect(actions[1].id).assertEqual('persona_memory_edit');
      expect(actions[1].kind).assertEqual('client');
      expect(actions[1].prompt).assertEqual('food_companion');
      expect(actions[2].id).assertEqual('persona_soul_edit');
      expect(actions[2].kind).assertEqual('client');
    });
  });
}
