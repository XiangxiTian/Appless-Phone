import { describe, it, expect } from '@ohos/hypium';
import {
  WaterfallCandidate,
  WaterfallOrderInput,
  WaterfallRankedCandidate,
  rankWaterfallCandidates
} from '@loop/agent-core';
import {
  WATERFALL_REPLAY_CASES,
  WaterfallReplayCandidate,
  WaterfallReplayCase
} from './WaterfallRankingReplayFixtures';

interface WaterfallReplayMetrics {
  ndcgAt10: number;
  recallAt20: number;
  duplicateRateAt10: number;
  sourceCoverageAt10: number;
  deterministicDifferences: number;
}

function gradeFor(items: WaterfallReplayCandidate[], id: string): number {
  for (let index = 0; index < items.length; index += 1) {
    if (items[index].candidate.id === id) {
      return items[index].grade;
    }
  }
  return 0;
}

function dcg(grades: number[], limit: number): number {
  let score = 0;
  const count = Math.min(limit, grades.length);
  for (let index = 0; index < count; index += 1) {
    score += (Math.pow(2, grades[index]) - 1) / (Math.log(index + 2) / Math.log(2));
  }
  return score;
}

function ndcgAt10(result: WaterfallCandidate[], labels: WaterfallReplayCandidate[]): number {
  const actual: number[] = result.map((item: WaterfallCandidate): number => gradeFor(labels, item.id));
  const ideal: number[] = labels.map((item: WaterfallReplayCandidate): number => item.grade);
  ideal.sort((left: number, right: number): number => right - left);
  const idealScore = dcg(ideal, 10);
  return idealScore === 0 ? 0 : dcg(actual, 10) / idealScore;
}

function recallAt20(result: WaterfallCandidate[], labels: WaterfallReplayCandidate[]): number {
  let relevant = 0;
  labels.forEach((item: WaterfallReplayCandidate): void => {
    if (item.grade >= 2) relevant += 1;
  });
  let recalled = 0;
  result.slice(0, 20).forEach((item: WaterfallCandidate): void => {
    if (gradeFor(labels, item.id) >= 2) recalled += 1;
  });
  return relevant === 0 ? 1 : recalled / relevant;
}

function normalizedReplayTitle(value: string): string {
  return value.trim().toLowerCase().replace(/[^a-z0-9\u4e00-\u9fff]+/g, '');
}

function nearDuplicate(left: WaterfallCandidate, right: WaterfallCandidate): boolean {
  if (left.url === right.url) return true;
  const leftTitle = normalizedReplayTitle(left.title);
  const rightTitle = normalizedReplayTitle(right.title);
  if (leftTitle.length < 8 || rightTitle.length < 8) return false;
  return leftTitle === rightTitle || leftTitle.indexOf(rightTitle) >= 0 || rightTitle.indexOf(leftTitle) >= 0;
}

function duplicateRateAt10(result: WaterfallCandidate[]): number {
  const top = result.slice(0, 10);
  let duplicates = 0;
  for (let index = 0; index < top.length; index += 1) {
    for (let other = 0; other < index; other += 1) {
      if (nearDuplicate(top[index], top[other])) {
        duplicates += 1;
        break;
      }
    }
  }
  return top.length === 0 ? 0 : duplicates / top.length;
}

function sourceCoverageAt10(result: WaterfallCandidate[], labels: WaterfallReplayCandidate[]): number {
  const sources: string[] = [];
  result.slice(0, 10).forEach((item: WaterfallCandidate): void => {
    if (gradeFor(labels, item.id) > 0 && sources.indexOf(item.source) < 0) sources.push(item.source);
  });
  return sources.length;
}

function orderInput(replay: WaterfallReplayCase): WaterfallOrderInput {
  return {
    query: replay.query,
    candidates: replay.candidates.map((item: WaterfallReplayCandidate): WaterfallCandidate => item.candidate),
    enabledSources: replay.successfulSources,
    shownIds: [],
    stableIds: [],
    preferenceDescription: '',
    mode: 'search',
    surfaceId: 'replay|' + replay.query,
    profile: replay.profile
  };
}

function providerOrder(replay: WaterfallReplayCase): WaterfallCandidate[] {
  const items = replay.candidates.map((item: WaterfallReplayCandidate): WaterfallCandidate => item.candidate);
  items.sort((left: WaterfallCandidate, right: WaterfallCandidate): number =>
    left.originalIndex - right.originalIndex);
  return items;
}

function meanMetrics(kind: string): WaterfallReplayMetrics {
  let ndcg = 0;
  let recall = 0;
  let duplicateRate = 0;
  let sourceCoverage = 0;
  let deterministicDifferences = 0;
  WATERFALL_REPLAY_CASES.forEach((replay: WaterfallReplayCase): void => {
    let first: WaterfallCandidate[] = providerOrder(replay);
    let second: WaterfallCandidate[] = providerOrder(replay);
    if (kind === 'production') {
      first = rankWaterfallCandidates(orderInput(replay), 1786579200000);
      second = rankWaterfallCandidates(orderInput(replay), 1786579200000);
    }
    ndcg += ndcgAt10(first, replay.candidates);
    recall += recallAt20(first, replay.candidates);
    duplicateRate += duplicateRateAt10(first);
    sourceCoverage += sourceCoverageAt10(first, replay.candidates);
    if (first.map((item: WaterfallCandidate): string => item.id).join(',') !==
      second.map((item: WaterfallCandidate): string => item.id).join(',')) {
      deterministicDifferences += 1;
    }
  });
  const count = WATERFALL_REPLAY_CASES.length;
  return {
    ndcgAt10: ndcg / count,
    recallAt20: recall / count,
    duplicateRateAt10: duplicateRate / count,
    sourceCoverageAt10: sourceCoverage / count,
    deterministicDifferences
  };
}

function metricLine(name: string, value: WaterfallReplayMetrics): string {
  return '[WaterfallReplay] ' + name +
    ' ndcg@10=' + value.ndcgAt10.toFixed(4) +
    ' recall@20=' + value.recallAt20.toFixed(4) +
    ' duplicate@10=' + value.duplicateRateAt10.toFixed(4) +
    ' relevantSources@10=' + value.sourceCoverageAt10.toFixed(4) +
    ' deterministicDiffs=' + value.deterministicDifferences;
}

export default function waterfallRankingReplayTest() {
  describe('waterfallRankingReplay', () => {
    it('keeps the approved production ranking floors on fixed real-provider replay', 0, () => {
      const production = meanMetrics('production');
      console.info(metricLine('production', production));

      expect(WATERFALL_REPLAY_CASES.length).assertEqual(20);
      expect(production.ndcgAt10 >= 0.829).assertTrue();
      expect(production.recallAt20 >= 0.912).assertTrue();
      expect(production.duplicateRateAt10 <= 0.005).assertTrue();
      expect(production.sourceCoverageAt10 >= 2.8).assertTrue();
      expect(production.deterministicDifferences).assertEqual(0);
    });
  });
}
