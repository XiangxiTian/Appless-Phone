import { describe, expect, it } from '@ohos/hypium';
import {
  AggregateSearchPolicy,
  AggregateSearchSource,
  AggregateSearchSourceBatch,
  AggregateZhihuConfig,
  WaterfallContinuation,
  WaterfallLoadRequest,
  aggregateSearchRegistrySourceIds,
  callAggregateSearchContinuationForContext,
  configureWaterfallEnabledSourcesForRuntime
} from '@loop/agent-core';
import {
  WaterfallPoolWorkerClient,
  WaterfallPoolWorkerCommand
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallPoolWorkerClient';
import { applyWaterfallPoolWorkerSearchPolicy } from '../main/ets/workers/WaterfallPoolWorkerPolicy';

function emptyPolicyBatch(source: AggregateSearchSource): AggregateSearchSourceBatch {
  return {
    source,
    videos: [],
    posts: [],
    status: {
      source,
      label: source,
      status: 'empty',
      message: 'test',
      count: 0
    },
    continuation: null
  };
}

async function policyObservedByAdapter(source: AggregateSearchSource): Promise<AggregateSearchPolicy> {
  const observed: AggregateSearchPolicy[] = [];
  const requests: WaterfallLoadRequest[] = [{
    source,
    continuation: null,
    limit: 1,
    phase: 'loading',
    message: '',
    mode: 'search'
  }];
  await callAggregateSearchContinuationForContext(
    'interest', '', requests, '', { apiKey: '' },
    (_batch: AggregateSearchSourceBatch): void => {},
    (
      requestedSource: AggregateSearchSource,
      _query: string,
      _youtubeApiKey: string,
      _zhihuConfig: AggregateZhihuConfig,
      _continuation: WaterfallContinuation | null,
      _limit: number,
      policy: AggregateSearchPolicy
    ): Promise<AggregateSearchSourceBatch> => {
      observed.push(policy);
      return Promise.resolve(emptyPolicyBatch(requestedSource));
    }
  );
  const policy = observed[0];
  if (policy === undefined) throw new Error('Adapter did not receive a search policy.');
  return policy;
}

function applyLatestPolicyCommand(command: WaterfallPoolWorkerCommand | null): void {
  if (command === null || command.type !== 'set_search_policy' || command.searchPolicy === undefined) {
    throw new Error('Client did not emit a Worker search-policy command.');
  }
  applyWaterfallPoolWorkerSearchPolicy(command.searchPolicy);
}

export default function waterfallPoolPolicyPropagationTest(): void {
  describe('WaterfallPoolPolicyPropagation', () => {
    it('applies Client policy changes to the next Worker Adapter request without rebuilding the Worker', 0, async () => {
      let latestCommand: WaterfallPoolWorkerCommand | null = null;
      const client = new WaterfallPoolWorkerClient('{}', '{}', {
        domesticOnly: false,
        multilingual: true
      }, (command: WaterfallPoolWorkerCommand): void => {
        latestCommand = command;
      });
      configureWaterfallEnabledSourcesForRuntime(['bilibili', 'twitch']);

      try {
        client.setSearchPolicy({ domesticOnly: true, multilingual: false });
        applyLatestPolicyCommand(latestCommand);
        const domestic = await policyObservedByAdapter('bilibili');
        expect(domestic.domesticOnly).assertTrue();
        expect(domestic.multilingual).assertFalse();

        client.setSearchPolicy({ domesticOnly: false, multilingual: true });
        applyLatestPolicyCommand(latestCommand);
        const global = await policyObservedByAdapter('twitch');
        expect(global.domesticOnly).assertFalse();
        expect(global.multilingual).assertTrue();
      } finally {
        client.dispose();
        configureWaterfallEnabledSourcesForRuntime(aggregateSearchRegistrySourceIds());
        applyWaterfallPoolWorkerSearchPolicy({ domesticOnly: true, multilingual: false });
      }
    });
  });
}
