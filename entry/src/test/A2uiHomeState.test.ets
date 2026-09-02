import { describe, it, expect } from '@ohos/hypium';
import { A2uiAction, A2uiGenericToolResultData, A2uiSurfaceState } from '@loop/agent-core';
import {
  A2UI_SEND_SPINNER_STEP_DEG,
  createInitialConnectionPanelState,
  createTurnConversationSurface,
  createTurnFailureSurface,
  deepSearchRouteDecisionFromModelText,
  deepSearchRouteDecisionPrompt,
  explicitDeepSearchRouteDecision,
  inputTextAfterPromptSubmit,
  isWelcomeSurface,
  isPromptInputEnabled,
  nextPendingToolRenderTick,
  nextSendSpinnerRotation,
  runtimeCallbackIsCurrent,
  runtimeOwnerAllowsSurfaceAction,
  runtimeSurfaceIdentityMatches,
  sessionResetDeletesPersistedConversation,
  shouldShowDeepSearchPendingSurface,
  shouldShowFirecrawlPendingSurface,
  shouldShowWelcome,
  shouldShowQueryPendingSurface,
  shouldApplySurfaceUpdate,
  updateConnectionPanelState,
  visibleTurnFailureMessage,
  voiceInputTextAfterRecognition
} from '../main/ets/pages/A2uiHome/state/A2uiHomeState';
import { buildRideToolPanelState } from '../main/ets/pages/A2uiHome/state/RideToolResultsState';

function surface(
  sequence: number,
  status: string,
  surfaceId: string = 'surface_model',
  runtimeOwner: 'multi_agent' | 'legacy' = 'multi_agent',
  runtimeGeneration: number = 1
): A2uiSurfaceState {
  return {
    surfaceId: surfaceId,
    rootId: 'root',
    title: '测试',
    intent: 'food',
    status: status,
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: sequence,
    runtimeOwner,
    runtimeGeneration
  };
}

export default function a2uiHomeStateTest() {
  describe('a2uiHomeState', () => {
    it('deletes persisted conversation only for the user reset action', 0, () => {
      expect(sessionResetDeletesPersistedConversation('account_scope_invalidated')).assertFalse();
      expect(sessionResetDeletesPersistedConversation('user_requested')).assertTrue();
    });

    it('updates panel state after a successful connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: true,
        status: 'ready',
        message: '模型连接正常',
        requestDebug: 'POST /chat/completions',
        assistantDebug: '{"version":"v0.9.1"}',
        error: ''
      });

      expect(next.connectionStatus).assertEqual('ready');
      expect(next.connectionMessage).assertEqual('模型连接正常');
      expect(next.lastModelRequest).assertEqual('POST /chat/completions');
      expect(next.lastModelOutput).assertEqual('{"version":"v0.9.1"}');
      expect(next.lastError).assertEqual('');
      expect(next.refreshTick).assertEqual(1);
    });

    it('updates panel state after a failed connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: false,
        status: 'error',
        message: '模型连接异常',
        requestDebug: '',
        assistantDebug: '',
        error: 'ECONNREFUSED'
      });

      expect(next.connectionStatus).assertEqual('error');
      expect(next.connectionMessage).assertEqual('模型连接异常');
      expect(next.lastError).assertEqual('ECONNREFUSED');
      expect(next.refreshTick).assertEqual(1);
    });

    it('skips applying the same surface sequence twice', 0, () => {
      expect(shouldApplySurfaceUpdate(surface(12, 'ready'), surface(12, 'ready'))).assertFalse();
      expect(shouldApplySurfaceUpdate(surface(12, 'calling_tool'), surface(13, 'ready'))).assertTrue();
    });

    it('accepts only exact-owner actions and rejects stale or late owner changes', 0, () => {
      const multi = surface(12, 'ready', 'surface_multi', 'multi_agent', 4);
      const legacy = surface(12, 'ready', 'surface_legacy', 'legacy', 4);

      expect(runtimeOwnerAllowsSurfaceAction(multi, 'multi_agent')).assertTrue();
      expect(runtimeOwnerAllowsSurfaceAction(multi, 'legacy')).assertFalse();
      expect(runtimeOwnerAllowsSurfaceAction(legacy, 'legacy')).assertTrue();
      expect(runtimeOwnerAllowsSurfaceAction(legacy, 'multi_agent')).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(99, 'ready', 'surface_old', 'legacy', 3)
      )).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(13, 'ready', 'surface_mutated', 'legacy', 4)
      )).assertFalse();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(1, 'ready', 'surface_next', 'legacy', 5)
      )).assertTrue();
      expect(shouldApplySurfaceUpdate(
        multi,
        surface(12, 'ready', 'surface_multi', 'multi_agent', 5)
      )).assertTrue();
    });

    it('accepts callback state only for the generation and owner captured at submit', 0, () => {
      expect(runtimeCallbackIsCurrent('multi_agent', 7, 'multi_agent', 7)).assertTrue();
      expect(runtimeCallbackIsCurrent('multi_agent', 8, 'multi_agent', 7)).assertFalse();
      expect(runtimeCallbackIsCurrent('legacy', 7, 'multi_agent', 7)).assertFalse();

      let activeOwner: 'multi_agent' | 'legacy' = 'multi_agent';
      let activeGeneration = 10;
      let mutations = 0;
      const mutate = (owner: 'multi_agent' | 'legacy', generation: number): void => {
        if (runtimeCallbackIsCurrent(activeOwner, activeGeneration, owner, generation)) {
          mutations++;
        }
      };
      const oldMultiAgent = (): void => mutate('multi_agent', 10);
      const oldLegacyStream = (): void => mutate('legacy', 10);
      const oldToolStream = (): void => mutate('multi_agent', 10);
      activeGeneration = 11;
      oldMultiAgent();
      oldLegacyStream();
      oldToolStream();
      expect(mutations).assertEqual(0);
      mutate('multi_agent', 11);
      expect(mutations).assertEqual(1);
    });

    it('requires exact current host and retained snapshot identity for page actions', 0, () => {
      const current = surface(20, 'ready', 'surface-current', 'multi_agent', 9);
      const retained = surface(20, 'ready', 'surface-current', 'multi_agent', 9);
      expect(runtimeSurfaceIdentityMatches(current, retained, 'multi_agent', 9)).assertTrue();
      expect(runtimeSurfaceIdentityMatches(
        surface(21, 'ready', 'surface-newer', 'multi_agent', 10),
        retained,
        'multi_agent',
        10
      )).assertFalse();
      expect(runtimeSurfaceIdentityMatches(
        current,
        surface(20, 'ready', 'surface-current', 'legacy', 9),
        'multi_agent',
        9
      )).assertFalse();
      expect(runtimeSurfaceIdentityMatches(current, retained, 'legacy', 9)).assertFalse();
    });

    it('uses only the model routing decision and falls back to the normal agent', 0, () => {
      expect(deepSearchRouteDecisionFromModelText('{"route":"deepsearch"}')).assertEqual('deepsearch');
      expect(deepSearchRouteDecisionFromModelText('```json\n{"route":"agent"}\n```')).assertEqual('agent');
      expect(deepSearchRouteDecisionFromModelText('{"route":"search"}')).assertEqual('agent');
      expect(deepSearchRouteDecisionFromModelText('not json')).assertEqual('agent');
      expect(deepSearchRouteDecisionPrompt('比较两款芯片的最新进展').indexOf('比较两款芯片的最新进展'))
        .assertLarger(-1);
      expect(deepSearchRouteDecisionPrompt('今天深圳天气怎么样').indexOf('天气')).assertLarger(-1);
    });

    it('lets explicit DeepSearch requests and refusals override model routing', 0, () => {
      expect(explicitDeepSearchRouteDecision('请深度搜索 Firecrawl 的限制')).assertEqual('deepsearch');
      expect(explicitDeepSearchRouteDecision('不要联网搜索，直接回答')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('不要为这个问题调用深度搜索')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('深度搜索就免了')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('不要用 DeepSearch')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('不需要 DeepSearch')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('不必联网搜索')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('我不想用 DeepSearch')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('我不希望联网搜索')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('DeepSearch 我不想用')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('DeepSearch 我不希望用')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('No DeepSearch')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('DeepSearch is not needed')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('Answer without DeepSearch')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('DeepSearch, no thanks')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('Use another DeepSearch query')).assertEqual('deepsearch');
      expect(explicitDeepSearchRouteDecision('Use techno DeepSearch sources')).assertEqual('deepsearch');
      expect(explicitDeepSearchRouteDecision('Not only DeepSearch, compare sources')).assertEqual('deepsearch');
      expect(explicitDeepSearchRouteDecision('请勿深度搜索')).assertEqual('agent');
      expect(explicitDeepSearchRouteDecision('不要普通搜索，请深度搜索')).assertEqual('deepsearch');
      expect(explicitDeepSearchRouteDecision('今天深圳天气怎么样')).assertEqual(null);
      expect(explicitDeepSearchRouteDecision('查深圳到上海的出行方案，也告诉我深圳天气')).assertEqual(null);
      expect(explicitDeepSearchRouteDecision('比较两款芯片的最新进展')).assertEqual(null);
    });

    it('replaces a stale tool surface with the current turn result or failure', 0, () => {
      const conversation = createTurnConversationSurface(12);
      const failureMessage = visibleTurnFailureMessage('HTTP 429 throttling_error');
      const failure = createTurnFailureSurface(failureMessage, 13);

      expect(conversation.intent).assertEqual('general');
      expect(conversation.status).assertEqual('ready');
      expect(conversation.runtimeGeneration).assertEqual(12);
      expect(failure.intent).assertEqual('general');
      expect(failure.status).assertEqual('error');
      expect(failure.runtimeGeneration).assertEqual(13);
      expect(failure.error).assertEqual('模型请求过于频繁，请稍后重试。');
      expect(failure.components[2].component).assertEqual('ErrorNotice');
      expect(visibleTurnFailureMessage('LEADER_PLAN_FAILED')).assertEqual('这次请求没有完成，请稍后重试。');
    });

    it('keeps send spinner rotation monotonic while loading', 0, () => {
      expect(nextSendSpinnerRotation(360 - A2UI_SEND_SPINNER_STEP_DEG, true)).assertEqual(360);
      expect(nextSendSpinnerRotation(360, true)).assertEqual(360 + A2UI_SEND_SPINNER_STEP_DEG);
      expect(nextSendSpinnerRotation(360 + A2UI_SEND_SPINNER_STEP_DEG, false)).assertEqual(0);
    });

    it('locks prompt input while busy and clears submitted text', 0, () => {
      expect(isPromptInputEnabled(false)).assertTrue();
      expect(isPromptInputEnabled(true)).assertFalse();
      expect(inputTextAfterPromptSubmit('帮我查深圳北站附近餐馆')).assertEqual('');
    });

    it('appends recognized voice input to the current draft', 0, () => {
      expect(voiceInputTextAfterRecognition('', ' 明天的天气 ')).assertEqual('明天的天气');
      expect(voiceInputTextAfterRecognition('帮我查深圳北站', '附近餐馆')).assertEqual('帮我查深圳北站 附近餐馆');
      expect(voiceInputTextAfterRecognition('帮我查深圳北站 ', '附近餐馆')).assertEqual('帮我查深圳北站 附近餐馆');
      expect(voiceInputTextAfterRecognition('原始草稿 ', '   ')).assertEqual('原始草稿 ');
    });

    it('shows the query pending surface only before the first new render arrives', 0, () => {
      expect(shouldShowQueryPendingSurface(true, true)).assertTrue();
      expect(shouldShowQueryPendingSurface(true, false)).assertFalse();
      expect(shouldShowQueryPendingSurface(false, true)).assertFalse();
    });

    it('keeps the normal pending conversation visible while DeepSearch runs', 0, () => {
      expect(shouldShowDeepSearchPendingSurface(true, true)).assertTrue();
      expect(shouldShowDeepSearchPendingSurface(true, false)).assertFalse();
      expect(shouldShowDeepSearchPendingSurface(false, true)).assertFalse();
    });

    it('reveals Firecrawl partial results while the tool is still busy', 0, () => {
      const pending = surface(7, 'calling_tool');
      pending.intent = 'social.public.search';
      pending.components = [{
        id: 'thinking',
        component: 'ThinkingStream'
      }];
      const partial = surface(8, 'ready');
      partial.intent = 'social.public.search';
      partial.components = [{
        id: 'results',
        component: 'GenericToolResults'
      }];

      expect(shouldShowFirecrawlPendingSurface(
        true,
        'social.public.search',
        pending
      )).assertTrue();
      expect(shouldShowFirecrawlPendingSurface(
        true,
        'social.public.search',
        partial
      )).assertFalse();
    });

    it('forces an HTML refresh when the pending Firecrawl tool changes', 0, () => {
      expect(nextPendingToolRenderTick(7, '', 'shopping.research')).assertEqual(8);
      expect(nextPendingToolRenderTick(8, 'shopping.research', 'shopping.research'))
        .assertEqual(8);
      expect(nextPendingToolRenderTick(8, 'shopping.research', '')).assertEqual(9);
    });

    it('keeps the welcome landing visible with restored context', 0, () => {
      const welcome = surface(1, 'idle', 'surface_seed');
      expect(isWelcomeSurface(welcome)).assertTrue();
      expect(shouldShowWelcome(false, 0, welcome, false)).assertTrue();
      expect(shouldShowWelcome(true, 0, welcome, false)).assertFalse();
      expect(shouldShowWelcome(false, 1, welcome, false)).assertFalse();
      expect(shouldShowWelcome(false, 1, welcome, true)).assertTrue();
      expect(shouldShowWelcome(false, 0, surface(2, 'ready', 'surface_food'), true)).assertFalse();
    });

    it('matches each ride estimate to its exact vehicle confirmation action', 0, () => {
      const actions: A2uiAction[] = [
        {
          id: 'ride.order.confirm',
          label: '确认叫特惠快车',
          prompt: '确认下单：特惠快车 10',
          kind: 'prompt',
          variant: 'primary'
        },
        {
          id: 'ride.order.confirm',
          label: '确认叫快车',
          prompt: '确认下单：快车 15',
          kind: 'prompt',
          variant: 'secondary'
        }
      ];
      const result: A2uiGenericToolResultData = {
        sourceTag: '滴滴',
        toolName: 'ride.estimate',
        title: '滴滴价格预估',
        status: 'success',
        summary: 'summary',
        rows: [
          { label: '特惠快车（discount）', value: '10' },
          { label: '快车（express）', value: '15' }
        ],
        rawPreview: '',
        actions: actions
      };
      const panel = buildRideToolPanelState([result]);

      expect(panel.estimateCards[1].action === null).assertFalse();
      if (panel.estimateCards[1].action !== null) {
        expect(panel.estimateCards[1].action?.label).assertEqual('确认叫快车');
      }
    });
  });
}
