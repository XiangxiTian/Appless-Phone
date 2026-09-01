import { describe, expect, it } from '@ohos/hypium';
import {
  filterWaterfallPoolCandidates,
  WaterfallCandidate,
  WaterfallMetric
} from '@loop/agent-core';

interface QualityCase {
  adapterId: string;
  candidate: WaterfallCandidate;
  accepted: boolean;
}

function qualityCandidate(
  id: string,
  metrics: WaterfallMetric[] = [],
  publishedAt: string = '2026-08-31T00:00:00.000Z',
  url: string = ''
): WaterfallCandidate {
  return {
    id,
    source: 'test',
    provider: 'test',
    mediaType: 'post',
    title: id,
    summary: id,
    url: url.length > 0 ? url : 'https://example.com/' + id,
    coverUrl: '',
    publishedAt,
    originalIndex: 0,
    metrics: metrics.length > 0 ? metrics : undefined
  };
}

function metric(kind: string, value: number): WaterfallMetric {
  return { kind, value };
}

export default function waterfallPoolQualityPolicyTest() {
  describe('WaterfallPoolQualityPolicy', () => {
    it('applies the configured quality signal for every registered adapter', 0, () => {
      const oldDate = '2025-01-01T00:00:00.000Z';
      const cases: QualityCase[] = [
        { adapterId: 'bilibili.search', candidate: qualityCandidate('bili', [metric('view', 1999)]), accepted: false },
        { adapterId: 'youtube.search', candidate: qualityCandidate('youtube', [metric('view', 4999)]), accepted: false },
        { adapterId: 'youtube.most_popular', candidate: qualityCandidate('youtube-hot'), accepted: true },
        { adapterId: 'zhihu.search', candidate: qualityCandidate('zhihu', [metric('like', 29)]), accepted: false },
        { adapterId: 'zhihu.hot_list', candidate: qualityCandidate('zhihu-hot'), accepted: true },
        { adapterId: 'github.search', candidate: qualityCandidate('github', [metric('star', 99)]), accepted: false },
        { adapterId: 'github.public_discovery', candidate: qualityCandidate('github-release'), accepted: true },
        { adapterId: 'x.search', candidate: qualityCandidate('x', [metric('view', 100), metric('like', 9), metric('repost', 2)]), accepted: false },
        { adapterId: 'reddit.search', candidate: qualityCandidate('reddit', [metric('score', 19), metric('comment', 9)]), accepted: false },
        { adapterId: 'hackernews.search', candidate: qualityCandidate('hn', [metric('score', 19), metric('comment', 9)]), accepted: false },
        { adapterId: 'twitch.search', candidate: qualityCandidate('twitch-search'), accepted: true },
        { adapterId: 'twitch.live_discovery', candidate: qualityCandidate('twitch-live', [metric('viewer', 19)]), accepted: false },
        { adapterId: 'applepodcasts.search', candidate: qualityCandidate('podcast'), accepted: true },
        { adapterId: 'globalnews.search', candidate: qualityCandidate('global-search', [], oldDate), accepted: false },
        { adapterId: 'globalnews.latest', candidate: qualityCandidate('global-latest', [], oldDate), accepted: false },
        { adapterId: 'cnnews.latest', candidate: qualityCandidate('cnnews', [], oldDate), accepted: false },
        { adapterId: 'steam.news', candidate: qualityCandidate('steam', [], oldDate), accepted: false }
      ];
      const now = Date.parse('2026-09-01T00:00:00.000Z');

      cases.forEach((testCase: QualityCase): void => {
        const result = filterWaterfallPoolCandidates(testCase.adapterId, [testCase.candidate], now);
        expect(result.items.length === 1).assertEqual(testCase.accepted);
      });
    });

    it('allows missing engagement metrics and accepts any strong social signal', 0, () => {
      expect(filterWaterfallPoolCandidates(
        'bilibili.search', [qualityCandidate('missing')]).items.length).assertEqual(1);
      expect(filterWaterfallPoolCandidates(
        'x.search', [qualityCandidate('shared', [metric('view', 100), metric('like', 1), metric('repost', 3)])]
      ).items.length).assertEqual(1);
      expect(filterWaterfallPoolCandidates(
        'reddit.search', [qualityCandidate('discussed', [metric('score', 1), metric('comment', 10)])]
      ).items.length).assertEqual(1);
    });

    it('rejects structurally empty candidates before adapter-specific checks', 0, () => {
      const candidate = qualityCandidate('empty');
      candidate.id = '';
      candidate.title = '';
      candidate.url = '';
      expect(filterWaterfallPoolCandidates('zhihu.hot_list', [candidate]).items.length).assertEqual(0);
    });
  });
}
