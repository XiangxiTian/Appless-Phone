import { describe, expect, it } from '@ohos/hypium';
import { Want } from '@kit.AbilityKit';
import { LocalModelSettings, WaterfallExplicitPreference } from '@loop/agent-core';
import { waterfallConversationTypedTestPromptFromWant } from '../main/ets/entryability/EntryAbility';
import { waterfallTagFallbackSettings } from '../main/ets/pages/A2uiHome/Index';
import {
  applyWaterfallPreferenceAdjustment,
  mergeWaterfallPreferenceTagSuggestions,
  parseWaterfallPreferenceTagSuggestions,
  parseWaterfallPreferenceToolInput,
  waterfallImmediatePreferenceRecallQuery,
  waterfallPreferencePromptExample,
  waterfallPreferenceTagPrompt,
  waterfallPreferenceTagsDue,
  waterfallPreferenceTagAdjustment,
  WaterfallPreferenceTagEvidence,
  waterfallVisiblePreferenceTags,
  waterfallPreferenceToolIsExclusive,
  WaterfallPreferenceAdjustment,
  WaterfallConversationState
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallConversation';

export default function waterfallConversationTest() {
  describe('waterfallConversation', () => {
    it('accepts only strict bounded preference tool input', 0, () => {
      const command = parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","summary":"多看 AI，少看视频","preferences":[' +
          '{"dimension":"topic","key":"AI","state":"boost"},' +
          '{"dimension":"format","key":"landscape_video","state":"downweight"}]}'
      );
      expect(command === null).assertFalse();
      expect(command?.preferences.length).assertEqual(2);
      expect(command?.summary).assertEqual('推荐偏好已更新');
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","summary":"用户想看更多足球相关的内容","preferences":[' +
          '{"dimension":"topic","key":"足球","state":"boost"}]}'
      )?.summary).assertEqual('足球内容会多一些');
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","summary":"未知来源","preferences":[' +
          '{"dimension":"source","key":"unknown","state":"boost"}]}'
      ) === null).assertTrue();
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","summary":"不能屏蔽","preferences":[' +
          '{"dimension":"topic","key":"体育","state":"block"}]}'
      ) === null).assertTrue();
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","summary":"空规则","preferences":[]}'
      ) === null).assertTrue();
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"reset","summary":"恢复默认","preferences":[]}'
      )?.operation).assertEqual('reset');
      expect(parseWaterfallPreferenceToolInput(
        '{"operation":"adjust","preferences":[' +
          '{"dimension":"topic","key":"科学技术","state":"boost"}]}'
      )?.summary).assertEqual('科学技术内容会多一些');
    });

    it('stays in Waterfall only for the exclusive preference tool', 0, () => {
      expect(waterfallPreferenceToolIsExclusive(['waterfall.preference.adjust'])).assertTrue();
      expect(waterfallPreferenceToolIsExclusive([])).assertFalse();
      expect(waterfallPreferenceToolIsExclusive(['food.search'])).assertFalse();
      expect(waterfallPreferenceToolIsExclusive([
        'waterfall.preference.adjust', 'food.search'
      ])).assertFalse();
    });

    it('keeps selected topics first and hides negative preferences', 0, () => {
      const tags = waterfallVisiblePreferenceTags([
        { dimension: 'topic', key: '足球', effect: 'boost' },
        { dimension: 'topic', key: 'Kpop', effect: 'downweight' },
        { dimension: 'source', key: 'reddit', effect: 'boost' }
      ], ['Kpop', '英超', '商业']);
      expect(tags.slice(0, 3).join(',')).assertEqual('足球,英超,商业');
      expect(tags.indexOf('足球') >= 0).assertTrue();
      expect(tags.indexOf('Kpop')).assertEqual(-1);
      expect(waterfallPreferenceTagAdjustment('足球', false)?.preferences[0].state)
        .assertEqual('boost');
      expect(waterfallPreferenceTagAdjustment('足球', true)?.preferences[0].state)
        .assertEqual('neutral');
      expect(waterfallPreferenceTagAdjustment('   ', false) === null).assertTrue();
      const lockedRules: WaterfallExplicitPreference[] = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'].map(
        (key: string): WaterfallExplicitPreference => ({ dimension: 'topic', key, effect: 'boost' }));
      expect(waterfallVisiblePreferenceTags(lockedRules, ['新标签']).join(','))
        .assertEqual('A,B,C,D,E,F,G,H');
      expect(waterfallPreferencePromptExample(['足球'], ['头条新闻', '足球']))
        .assertEqual('试试说：多给我推荐点足球内容');
      expect(waterfallPreferencePromptExample([], ['头条新闻', 'Kpop']))
        .assertEqual('试试说：多给我推荐点Kpop内容');
      expect(waterfallPreferencePromptExample([], ['头条新闻', '科学技术', '商业', '娱乐']))
        .assertEqual('试试说：多给我推荐点足球内容');
    });

    it('starts immediate recall only for one boosted topic', 0, () => {
      const contextualRecallQuery = waterfallImmediatePreferenceRecallQuery as Object as (
        adjustment: WaterfallPreferenceAdjustment,
        preferenceChanged: boolean,
        mode: 'interest' | 'search'
      ) => string;
      expect(waterfallImmediatePreferenceRecallQuery({
        operation: 'adjust', summary: '足球内容会多一些',
        preferences: [{ dimension: 'topic', key: '足球', state: 'boost' }]
      })).assertEqual('足球');
      expect(waterfallImmediatePreferenceRecallQuery({
        operation: 'adjust', summary: '足球已恢复正常',
        preferences: [{ dimension: 'topic', key: '足球', state: 'neutral' }]
      })).assertEqual('');
      expect(waterfallImmediatePreferenceRecallQuery({
        operation: 'adjust', summary: '推荐偏好已更新',
        preferences: [
          { dimension: 'topic', key: '足球', state: 'boost' },
          { dimension: 'topic', key: 'Kpop', state: 'boost' }
        ]
      })).assertEqual('');
      const boosted: WaterfallPreferenceAdjustment = {
        operation: 'adjust', summary: '足球内容会多一些',
        preferences: [{ dimension: 'topic', key: '足球', state: 'boost' }]
      };
      expect(contextualRecallQuery(boosted, true, 'interest')).assertEqual('足球');
      expect(contextualRecallQuery(boosted, false, 'interest')).assertEqual('');
      expect(contextualRecallQuery(boosted, true, 'search')).assertEqual('');
    });

    it('accepts bounded generated tags and triggers without a time cooldown', 0, () => {
      expect(parseWaterfallPreferenceTagSuggestions('{"tags":["足球","Kpop"]}')?.join(','))
        .assertEqual('足球,Kpop');
      expect(parseWaterfallPreferenceTagSuggestions('{"tags":["足球"],"extra":true}') === null)
        .assertTrue();
      expect(parseWaterfallPreferenceTagSuggestions('{"tags":[]}') === null).assertTrue();
      expect(mergeWaterfallPreferenceTagSuggestions(
        ['头条新闻', '科学技术', '商业', '娱乐'], ['足球']
      ).join(',')).assertEqual('头条新闻,科学技术,商业,足球');
      expect(mergeWaterfallPreferenceTagSuggestions(
        ['头条新闻', '科学技术', '商业', '娱乐'], ['商业', 'Kpop']
      ).join(',')).assertEqual('头条新闻,科学技术,商业,Kpop');
      const evidence: WaterfallPreferenceTagEvidence[] = [
        { behavior: 'play_complete', durationMs: 12000, timestamp: 1 },
        { behavior: 'read_complete', durationMs: 12000, timestamp: 2 }
      ];
      expect(waterfallPreferenceTagsDue(evidence, 0, false)).assertTrue();
      expect(waterfallPreferenceTagsDue(evidence.slice(0, 1), 0, false)).assertTrue();
      expect(waterfallPreferenceTagsDue(evidence, 2, false)).assertFalse();
      expect(waterfallPreferenceTagsDue([], 0, true)).assertTrue();
      expect(waterfallPreferenceTagsDue(evidence, 0, false, 2)).assertFalse();
      expect(waterfallPreferenceTagsDue([], 0, true, 0, 1, 1)).assertFalse();
      expect(waterfallPreferenceTagsDue([], 0, true, 0, 2, 1)).assertTrue();
      expect(waterfallPreferenceTagPrompt({
        currentTags: ['头条新闻'], lockedTags: [], explicitRules: [], positiveTopics: [], rejectedTopics: [],
        personaInterests: [], personaExpertise: [], personaRecentFocus: [], recentContent: []
      }).indexOf('现有标签未覆盖') >= 0).assertTrue();
    });

    it('falls back only when tag generation hits a model permission error', 0, () => {
      const settings: LocalModelSettings = {
        provider: 'CSI.AI', baseUrl: 'https://model.example.test/v1/chat/completions',
        model: 'Deepseek-V4-Flash-0731', apiKey: 'key',
        customParametersJson: '{"enable_thinking":false}', ignoreToolSurfaceUpdates: false
      };
      expect(waterfallTagFallbackSettings(settings, 'HTTP 403')?.model).assertEqual('Qwen3.7-Plus');
      expect(waterfallTagFallbackSettings(settings, 'HTTP 500') === null).assertTrue();
      const fallbackSettings: LocalModelSettings = {
        provider: settings.provider, baseUrl: settings.baseUrl, model: 'Qwen3.7-Plus', apiKey: settings.apiKey,
        customParametersJson: settings.customParametersJson,
        ignoreToolSurfaceUpdates: settings.ignoreToolSurfaceUpdates
      };
      expect(waterfallTagFallbackSettings(fallbackSettings, 'HTTP 403') === null)
        .assertTrue();
    });

    it('accepts only a bounded typed device probe', 0, () => {
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: '  多看科技  ' }
      } as Want)).assertEqual('多看科技');
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: 42 }
      } as Want)).assertEqual('');
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: 'x'.repeat(241) }
      } as Want)).assertEqual('');
    });

    it('applies idempotent tri-state preferences and restores the prior state', 0, () => {
      const empty: WaterfallConversationState = {
        history: [{ rules: [], summary: '' }], rules: [], summary: ''
      };
      const firstCommand: WaterfallPreferenceAdjustment = {
        operation: 'adjust', summary: '多看 AI',
        preferences: [{ dimension: 'topic', key: 'AI', state: 'boost' }]
      };
      const first = applyWaterfallPreferenceAdjustment(empty, firstCommand);
      const repeated = applyWaterfallPreferenceAdjustment(first, firstCommand);
      expect(repeated.rules.length).assertEqual(1);
      expect(repeated.history.length).assertEqual(first.history.length);
      const secondCommand: WaterfallPreferenceAdjustment = {
        operation: 'adjust', summary: '少看 AI，多看 Reddit',
        preferences: [
          { dimension: 'topic', key: 'AI', state: 'downweight' },
          { dimension: 'source', key: 'reddit', state: 'boost' }
        ]
      };
      const second = applyWaterfallPreferenceAdjustment(first, secondCommand);
      expect(second.rules.length).assertEqual(2);
      expect(second.rules[0].effect).assertEqual('downweight');
      const neutralCommand: WaterfallPreferenceAdjustment = {
        operation: 'adjust', summary: 'AI 恢复正常',
        preferences: [{ dimension: 'topic', key: 'AI', state: 'neutral' }]
      };
      const neutral = applyWaterfallPreferenceAdjustment(second, neutralCommand);
      expect(neutral.rules.length).assertEqual(1);
      expect(neutral.rules[0].key).assertEqual('reddit');
      const undoCommand: WaterfallPreferenceAdjustment = {
        operation: 'undo', summary: '已撤销', preferences: []
      };
      const undone = applyWaterfallPreferenceAdjustment(neutral, undoCommand);
      expect(undone.rules.length).assertEqual(2);
      expect(undone.rules[0].effect).assertEqual('downweight');
      const resetCommand: WaterfallPreferenceAdjustment = {
        operation: 'reset', summary: '恢复默认', preferences: []
      };
      const reset = applyWaterfallPreferenceAdjustment(undone, resetCommand);
      expect(reset.rules.length).assertEqual(0);
      const resetUndone = applyWaterfallPreferenceAdjustment(reset, undoCommand);
      expect(resetUndone.rules.length).assertEqual(2);
      const restoredSession: WaterfallConversationState = {
        history: [{ rules: second.rules, summary: '' }], rules: second.rules, summary: ''
      };
      expect(applyWaterfallPreferenceAdjustment(restoredSession, undoCommand).rules.length)
        .assertEqual(2);
    });
  });
}
