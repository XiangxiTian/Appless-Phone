export interface AggregateSearchPolicy {
  onlyDomesticSources: boolean;
  includeMultilingualResults: boolean;
}

export const DEFAULT_AGGREGATE_SEARCH_POLICY: AggregateSearchPolicy = {
  onlyDomesticSources: true,
  includeMultilingualResults: false
};

type AggregateSearchArgValue = Object | string | number | boolean | null | undefined;
type AggregateSearchArgRecord = Record<string, AggregateSearchArgValue>;

export function aggregateSearchArgsWithPolicy(
  toolId: string,
  args: Object | null,
  policy: AggregateSearchPolicy
): Object | null {
  if (toolId !== 'media.aggregate.search') {
    return args;
  }
  const merged: AggregateSearchArgRecord = {};
  if (args !== null) {
    const original = args as AggregateSearchArgRecord;
    Object.keys(original).forEach((key: string): void => {
      merged[key] = original[key];
    });
  }
  merged.onlyDomesticSources = policy.onlyDomesticSources;
  merged.includeMultilingualResults = policy.includeMultilingualResults;
  return merged;
}
