import { WaterfallCandidate, WaterfallMetric } from './WaterfallAnythingCore';

const DAY_MS: number = 24 * 60 * 60 * 1000;

export interface WaterfallPoolQualityFilterResult {
  items: WaterfallCandidate[];
  rejected: number;
}

function metricValue(candidate: WaterfallCandidate, kind: string): number | undefined {
  const metrics: WaterfallMetric[] = candidate.metrics ?? [];
  for (let index = 0; index < metrics.length; index += 1) {
    if (metrics[index].kind === kind) return metrics[index].value;
  }
  return undefined;
}

function passesMetric(candidate: WaterfallCandidate, kind: string, minimum: number): boolean {
  const value = metricValue(candidate, kind);
  return value === undefined || value >= minimum;
}

function passesAnyMetric(
  candidate: WaterfallCandidate,
  firstKind: string,
  firstMinimum: number,
  secondKind: string,
  secondMinimum: number,
  thirdKind: string = '',
  thirdMinimum: number = 0
): boolean {
  const first = metricValue(candidate, firstKind);
  const second = metricValue(candidate, secondKind);
  const third = thirdKind.length === 0 ? undefined : metricValue(candidate, thirdKind);
  if (first === undefined && second === undefined && third === undefined) return true;
  return (first !== undefined && first >= firstMinimum) ||
    (second !== undefined && second >= secondMinimum) ||
    (third !== undefined && third >= thirdMinimum);
}

function passesMaximumAge(candidate: WaterfallCandidate, maximumAgeMs: number, now: number): boolean {
  const publishedAt = candidate.publishedAt.trim();
  if (publishedAt.length === 0) return true;
  const timestamp = Date.parse(publishedAt);
  if (!Number.isFinite(timestamp)) return true;
  return timestamp > now || now - timestamp <= maximumAgeMs;
}

function hasExternalLocation(candidate: WaterfallCandidate): boolean {
  return candidate.url.trim().length > 0 || (candidate.mediaUrl ?? '').trim().length > 0 ||
    (candidate.feedUrl ?? '').trim().length > 0;
}

function passesCommonQuality(candidate: WaterfallCandidate): boolean {
  return candidate.title.trim().length > 0 &&
    (candidate.id.trim().length > 0 || hasExternalLocation(candidate));
}

function passesAdapterQuality(adapterId: string, candidate: WaterfallCandidate, now: number): boolean {
  if (!passesCommonQuality(candidate)) return false;
  if (adapterId === 'bilibili.search') return passesMetric(candidate, 'view', 2000);
  if (adapterId === 'youtube.search') return passesMetric(candidate, 'view', 5000);
  if (adapterId === 'zhihu.search') return passesMetric(candidate, 'like', 30);
  if (adapterId === 'github.search' || adapterId === 'github.public_discovery') {
    return passesMetric(candidate, 'star', 100);
  }
  if (adapterId === 'x.search') {
    return passesAnyMetric(candidate, 'view', 2000, 'like', 10, 'repost', 3);
  }
  if (adapterId === 'reddit.search' || adapterId === 'hackernews.search') {
    return passesAnyMetric(candidate, 'score', 20, 'comment', 10);
  }
  if (adapterId === 'twitch.live_discovery') return passesMetric(candidate, 'viewer', 20);
  if (adapterId === 'applepodcasts.search') return hasExternalLocation(candidate);
  if (adapterId === 'globalnews.search' || adapterId === 'globalnews.latest' ||
    adapterId === 'cnnews.latest') {
    return hasExternalLocation(candidate) && passesMaximumAge(candidate, 7 * DAY_MS, now);
  }
  if (adapterId === 'steam.news') {
    return hasExternalLocation(candidate) && passesMaximumAge(candidate, 30 * DAY_MS, now);
  }
  // Platform-curated feeds and adapters without trustworthy engagement metrics
  // still receive the common structural gate.
  return true;
}

export function filterWaterfallPoolCandidates(
  adapterId: string,
  items: WaterfallCandidate[],
  now: number = Date.now()
): WaterfallPoolQualityFilterResult {
  const accepted: WaterfallCandidate[] = [];
  items.forEach((candidate: WaterfallCandidate): void => {
    if (passesAdapterQuality(adapterId, candidate, now)) accepted.push(candidate);
  });
  return { items: accepted, rejected: items.length - accepted.length };
}
