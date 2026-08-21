import { describe, expect, it } from '@ohos/hypium';
import {
  aggregateSearchArgsWithPolicy,
  DEFAULT_AGGREGATE_SEARCH_POLICY
} from '../main/ets/pages/A2uiHome/state/AggregateSearchPolicy';

interface AggregatePolicyArgsFixture {
  query?: string;
  onlyDomesticSources?: boolean;
  includeMultilingualResults?: boolean;
}

export default function aggregateSearchPolicyTest(): void {
  describe('aggregateSearchPolicy', () => {
    it('defaults to all enabled discovery sources', 0, () => {
      expect(DEFAULT_AGGREGATE_SEARCH_POLICY.onlyDomesticSources).assertFalse();
      expect(DEFAULT_AGGREGATE_SEARCH_POLICY.includeMultilingualResults).assertTrue();
    });

    it('injects the host policy into aggregate search args', 0, () => {
      const args: AggregatePolicyArgsFixture = {
        query: 'Codex',
        onlyDomesticSources: true,
        includeMultilingualResults: false
      };
      const merged = aggregateSearchArgsWithPolicy('media.aggregate.search', args, {
        onlyDomesticSources: false,
        includeMultilingualResults: true
      }) as AggregatePolicyArgsFixture;
      expect(merged.query).assertEqual('Codex');
      expect(merged.onlyDomesticSources).assertFalse();
      expect(merged.includeMultilingualResults).assertTrue();
    });

    it('does not mutate or decorate unrelated tool args', 0, () => {
      const args: AggregatePolicyArgsFixture = { query: 'Codex' };
      const merged = aggregateSearchArgsWithPolicy('media.video.search', args, {
        onlyDomesticSources: false,
        includeMultilingualResults: true
      });
      expect(merged === args).assertTrue();
      const untouched = merged as AggregatePolicyArgsFixture;
      expect(untouched.onlyDomesticSources === undefined).assertTrue();
      expect(untouched.includeMultilingualResults === undefined).assertTrue();
    });
  });
}
