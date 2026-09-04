import { describe, expect, it } from '@ohos/hypium';
import { scoreWaterfallPreferenceText, WaterfallCandidate } from '@loop/agent-core';
import {
  applyWaterfallLlmBatch,
  emptyWaterfallLlmProfile,
  parseWaterfallLlmBatchOutput,
  pendingWaterfallLlmTasks,
  recordWaterfallLlmSignal,
  waterfallLlmBatchPrompt,
  waterfallLlmTopEqualWeights,
  waterfallLlmTopWeights,
  WaterfallLlmCardTask,
  WATERFALL_LLM_RESPONSE_FORMAT_JSON
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallLlmProfile';

function candidate(): WaterfallCandidate {
  return { id: 'card-1', source: 'youtube', mediaType: 'video',
    title: '大模型推荐系统实践', summary: '用语言模型抽取用户兴趣',
    url: 'https://example.com/card-1', coverUrl: '', publishedAt: '', originalIndex: 0 };
}

export default function waterfallLlmProfileTest() {
  describe('WaterfallLlmProfile', () => {
    it('uses the strongest card signal without double counting', 0, () => {
      let profile = recordWaterfallLlmSignal(emptyWaterfallLlmProfile(), candidate(), 'dwell', 100);
      profile = recordWaterfallLlmSignal(profile, candidate(), 'open', 101);
      profile = recordWaterfallLlmSignal(profile, candidate(), 'like', 102);
      profile = recordWaterfallLlmSignal(profile, candidate(), 'dwell', 103);

      expect(profile.tasks.length).assertEqual(1);
      expect(profile.tasks[0].heat).assertEqual(5);
      expect(pendingWaterfallLlmTasks(profile).length).assertEqual(1);
    });

    it('requires exactly three bilingual keywords and seeds each new keyword once', 0, () => {
      let profile = recordWaterfallLlmSignal(emptyWaterfallLlmProfile(), candidate(), 'dwell', 100);
      const tasks: WaterfallLlmCardTask[] = pendingWaterfallLlmTasks(profile);
      const raw = '{"tasks":[{"taskId":"' + tasks[0].taskId + '","keywords":[' +
        '{"zh":"大语言模型","en":"large language models"},' +
        '{"zh":"推荐系统","en":"recommender systems"},' +
        '{"zh":"用户画像","en":"user profiling"}]}]}';
      const parsed = parseWaterfallLlmBatchOutput(raw, tasks);
      expect(parsed.length).assertEqual(1);
      const applied = applyWaterfallLlmBatch(profile, parsed, 200);
      profile = applied.profile;
      expect(applied.priorityTopics.length).assertEqual(3);
      expect(profile.keywords[0].heat).assertEqual(1);

      profile = recordWaterfallLlmSignal(profile, candidate(), 'like', 300);
      expect(profile.keywords[0].heat).assertEqual(5);
      expect(pendingWaterfallLlmTasks(profile).length).assertEqual(0);
    });

    it('sends both title and summary under a strict three-keyword schema', 0, () => {
      const profile = recordWaterfallLlmSignal(emptyWaterfallLlmProfile(), candidate(), 'dwell', 100);
      const tasks = pendingWaterfallLlmTasks(profile);
      const prompt = waterfallLlmBatchPrompt(tasks);
      expect(prompt.indexOf('大模型推荐系统实践') >= 0).assertTrue();
      expect(prompt.indexOf('用语言模型抽取用户兴趣') >= 0).assertTrue();
      const responseFormat = JSON.parse(WATERFALL_LLM_RESPONSE_FORMAT_JSON) as Record<string, Object>;
      expect(responseFormat['type']).assertEqual('json_schema');
      expect(WATERFALL_LLM_RESPONSE_FORMAT_JSON.indexOf('"minItems":3') >= 0).assertTrue();
      expect(WATERFALL_LLM_RESPONSE_FORMAT_JSON.indexOf('"maxItems":3') >= 0).assertTrue();
      expect(WATERFALL_LLM_RESPONSE_FORMAT_JSON.indexOf('"strict":true') >= 0).assertTrue();
    });

    it('projects the hottest ten bilingual concepts into pool-only matching weights', 0, () => {
      let profile = recordWaterfallLlmSignal(emptyWaterfallLlmProfile(), candidate(), 'like', 100);
      const tasks = pendingWaterfallLlmTasks(profile);
      const parsed = parseWaterfallLlmBatchOutput('{"tasks":[{"taskId":"' + tasks[0].taskId +
        '","keywords":[{"zh":"人工智能","en":"artificial intelligence"},' +
        '{"zh":"模型训练","en":"model training"},{"zh":"内容推荐","en":"content recommendation"}]}]}', tasks);
      profile = applyWaterfallLlmBatch(profile, parsed, 200).profile;
      const weights = waterfallLlmTopWeights(profile);
      const score = scoreWaterfallPreferenceText('youtube', 'video',
        'A practical artificial intelligence guide', {
          topicWeights: weights, sourceWeights: [], formatWeights: [], explicitRules: []
        });
      expect(weights.length).assertEqual(3);
      expect(weights[0].weight).assertEqual(10);
      expect(score.historical).assertEqual(10);
    });

    it('projects the ranking profile with equal bilingual keyword weights', 0, () => {
      let profile = recordWaterfallLlmSignal(emptyWaterfallLlmProfile(), candidate(), 'like', 100);
      const tasks = pendingWaterfallLlmTasks(profile);
      const parsed = parseWaterfallLlmBatchOutput('{"tasks":[{"taskId":"' + tasks[0].taskId +
        '","keywords":[{"zh":"人工智能","en":"artificial intelligence"},' +
        '{"zh":"模型训练","en":"model training"},{"zh":"内容推荐","en":"content recommendation"}]}]}', tasks);
      profile = applyWaterfallLlmBatch(profile, parsed, 200).profile;

      const weights = waterfallLlmTopEqualWeights(profile);

      expect(weights.length).assertEqual(3);
      expect(weights.every((weight): boolean => weight.weight === 1)).assertTrue();
      expect((weights[0].aliases ?? []).indexOf('artificial intelligence') >= 0).assertTrue();
    });
  });
}
