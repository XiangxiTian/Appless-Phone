import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS,
  HTML_HOME_DEBUG_EXPORT_FILE_NAME,
  htmlHomeDebugExportJson,
  normalizeFoodPartialThrottleMs,
  normalizeFoodProviderDelayMs
} from '../main/ets/pages/A2uiHome/state/A2uiHomeDebugSettings';
import { HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';
import { WaterfallRankedCandidate } from '@loop/agent-core';

function htmlHomeDocumentFixture(): HtmlHomeDocument {
  const candidate: WaterfallRankedCandidate = {
    id: 'youtube-1', source: 'youtube', mediaType: 'video', title: 'OpenAI Codex', summary: 'Agent tools',
    url: 'https://youtube.test/codex', coverUrl: '', publishedAt: '2026-08-13T00:00:00.000Z', originalIndex: 0,
    sourceRank: 1, topics: ['openai', 'codex'], format: 'landscape_video', recallRoute: 'search', recallWeight: 1,
    normalizedUrl: 'https://youtube.test/codex',
    signals: { relevanceTier: 3, titleHits: 1, summaryHits: 0, freshnessTier: 4 }, reason: '标题命中查询'
  };
  const document: HtmlHomeDocument = {
    version: 1,
    source: 'tool',
    kind: 'food',
    title: '附近咖啡',
    subtitle: '真实餐饮结果',
    chips: [],
    metrics: [],
    timeline: [],
    blocks: [{
      id: 'food-0',
      kind: 'food-result',
      title: '瑞幸咖啡',
      subtitle: '咖啡',
      source: '高德',
      metrics: [{ label: 'distance', value: '120米' }],
      rows: [],
      actions: []
    }],
    actions: [],
    history: [{ id: 'm1', role: 'user', content: '帮我找咖啡' }],
    persona: { id: 'food_companion', name: 'Foodie', avatarKey: 'chef', status: 'active', reason: '餐饮场景' },
    personaMemory: { summary: '用户喜欢咖啡', preferences: ['咖啡'] },
    rawSurfaceRoot: {
      id: 'root',
      component: 'surfaceRoot',
      children: []
    },
    generatedAt: '2026-07-08T00:00:00.000Z',
    waterfall: {
      query: 'OpenAI Codex', enabledSources: ['youtube'], preferenceDescription: '', shown: [], current: candidate,
      stable: [], tail: [candidate], sources: [{
        source: 'youtube', phase: 'success', continuation: null, inFlight: false, reservedCount: 0, message: 'ok'
      }]
    }
  };
  return document;
}

export default function a2uiHomeDebugSettingsTest() {
  describe('a2uiHomeDebugSettings', () => {
    it('normalizes food provider delay milliseconds for debug settings', 0, () => {
      expect(normalizeFoodProviderDelayMs('')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs(' 2500 ')).assertEqual(2500);
      expect(normalizeFoodProviderDelayMs('-3')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('abc')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('90000')).assertEqual(30000);
    });

    it('defaults and bounds food partial render throttle milliseconds', 0, () => {
      expect(A2UI_FOOD_PARTIAL_THROTTLE_DEFAULT_MS).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs('')).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs(' 750 ')).assertEqual(750);
      expect(normalizeFoodPartialThrottleMs('-1')).assertEqual(0);
      expect(normalizeFoodPartialThrottleMs('abc')).assertEqual(500);
      expect(normalizeFoodPartialThrottleMs('90000')).assertEqual(5000);
    });

    it('serializes the html home debug export as pretty JSON for file dumps', 0, () => {
      const json = htmlHomeDebugExportJson(htmlHomeDocumentFixture(), true);
      const parsed = JSON.parse(json) as Record<string, Object | string | number | boolean | null>;

      expect(HTML_HOME_DEBUG_EXPORT_FILE_NAME).assertEqual('html-home-document-debug.json');
      expect(json.indexOf('\n  "kind": "food"')).assertLarger(-1);
      expect(parsed['kind'] as string).assertEqual('food');
      expect(parsed['isBusy'] as boolean).assertTrue();
      expect(parsed['rawSurfaceRoot']).assertEqual(null);
      expect(parsed['generatedAt'] as string).assertEqual('');
      expect((parsed['history'] as Object[]).length).assertEqual(0);
      expect((parsed['personaAvatarDataUri'] as string).length).assertLarger(0);
      const waterfall = parsed['waterfall'] as Record<string, Object | string | number | boolean | null>;
      const current = waterfall['current'] as Record<string, Object | string | number | boolean | null>;
      const tail = waterfall['tail'] as Object[];
      expect(current['sourceRank'] as number).assertEqual(1);
      expect((current['topics'] as string[]).join(',')).assertEqual('openai,codex');
      expect(current['format'] as string).assertEqual('landscape_video');
      expect(current['recallRoute'] as string).assertEqual('search');
      expect(tail.length).assertEqual(1);
    });
  });
}
