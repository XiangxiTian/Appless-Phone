import {
  AggregateSearchPolicy,
  configureWaterfallSearchPolicyForRuntime
} from '@loop/agent-core';

export function applyWaterfallPoolWorkerSearchPolicy(policy: AggregateSearchPolicy): void {
  configureWaterfallSearchPolicyForRuntime({
    domesticOnly: policy.domesticOnly,
    multilingual: policy.multilingual
  });
}
