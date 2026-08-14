import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiComponent,
  A2uiSurfaceState,
  UiCanonicalSurface,
  UiEvent,
  UiHostToolResult,
  UiSurfaceRequest,
  UiSurfaceSession
} from '@loop/agent-core';
import {
  defaultUiLabV4FeatureFlags,
  uiLabV4Shadow,
  uiLabV4Visible,
  uiLabV4WithMode
} from '../main/ets/pages/A2uiHome/lab/v4/UiLabV4FeatureFlags';
import {
  UiLabV4HostAdapter,
  UiLabV4HostCallbacks
} from '../main/ets/pages/A2uiHome/lab/v4/UiLabV4HostAdapter';
import { createUiLabV4Runtime } from '../main/ets/pages/A2uiHome/lab/v4/UiLabV4RuntimeFactory';
import {
  UiLabV4ProjectionBridge,
  UiLabV4ProjectionCallbacks
} from '../main/ets/pages/A2uiHome/lab/v4/UiLabV4ProjectionBridge';
import { UiLabV4ShadowMirror } from '../main/ets/pages/A2uiHome/lab/v4/UiLabV4ShadowMirror';
import { UiSurfaceController } from '@loop/agent-core';

interface UiLabV4TestRestaurantItem {
  shop_id: string;
  shop_name: string;
}

interface UiLabV4TestRestaurantData {
  items: UiLabV4TestRestaurantItem[];
}

interface UiLabV4TestActionArgs {
  cardId: string;
}

export default function uiLabV4IntegrationTest(): void {
  describe('UiLabV4Integration', (): void => {
    it('defaults to legacy and makes shadow/visible explicit', 0, (): void => {
      const flags = defaultUiLabV4FeatureFlags();
      expect(flags.mode).assertEqual('ui_lab_legacy');
      expect(uiLabV4Shadow(flags)).assertFalse();
      const shadow = uiLabV4WithMode(flags, 'ui_lab_v4_shadow');
      expect(uiLabV4Shadow(shadow)).assertTrue();
      expect(uiLabV4Visible(shadow)).assertFalse();
      expect(uiLabV4Visible(uiLabV4WithMode(flags, 'ui_lab_v4_visible'))).assertTrue();
    });

    it('keeps the UI Lab adapter as a host boundary', 0, (): void => {
      const requests: UiSurfaceRequest[] = [];
      const sessions: UiSurfaceSession[] = [];
      const actions: UiEvent[] = [];
      const surfaces: string[] = [];
      const diagnostics: string[] = [];
      const callbacks: UiLabV4HostCallbacks = {
        onLayoutRequest: (request: UiSurfaceRequest): void => { requests.push(request); },
        onActionEvent: (event: UiEvent): void => { actions.push(event); },
        onCanonicalSurface: (surface: UiCanonicalSurface): void => { surfaces.push(surface.surfaceId); },
        onSession: (session: UiSurfaceSession): void => { sessions.push(session); },
        onDiagnostic: (code: string, detail: string): void => { diagnostics.push(code + detail); }
      };
      const bundle = createUiLabV4Runtime(
        uiLabV4WithMode(defaultUiLabV4FeatureFlags(), 'ui_lab_v4_shadow'), callbacks
      );
      bundle.coordinator.startSurface({
        runId: 'lab-run', surfaceId: 'lab-surface', epoch: 1, userInput: 'status',
        taskShape: 'status-report', catalogGroups: ['foundation', 'semantic'], renderer: 'test'
      });
      bundle.coordinator.onUiEvent({
        eventId: 'event-1', runId: 'lab-run', surfaceId: 'lab-surface', epoch: 1,
        nodeKey: 'action', eventType: 'activate', offerId: 'offer-1'
      });
      const toolData: UiLabV4TestRestaurantData = {
        items: [{ shop_id: 'r-1', shop_name: 'Test Kitchen' }]
      };
      const toolResult: UiHostToolResult = {
        runId: 'lab-run', surfaceId: 'lab-surface', epoch: 1,
        toolId: 'restaurant.search', outputSchemaRef: 'restaurant-search-result.v1',
        provider: 'test-provider', status: 'ok',
        data: toolData
      };
      bundle.coordinator.onToolResult(toolResult);
      bundle.coordinator.onModelCompleted({
        runId: 'lab-run', surfaceId: 'lab-surface', format: 'a2ui-json', accepted: true,
        text: '{"updateComponents":{"surfaceId":"lab-surface","components":[{"id":"root","component":"Surface"}]}}'
      });
      expect(requests.length).assertEqual(1);
      expect(sessions.length).assertEqual(1);
      expect(actions.length).assertEqual(1);
      expect(surfaces.length).assertEqual(1);
      expect(diagnostics.length).assertEqual(0);
      expect(bundle.surfaceController.snapshot('lab-surface').data?.viewModelType)
        .assertEqual('ui.option-collection');
      expect(bundle.surfaceController.snapshot('lab-surface').layout?.rootNodeKey).assertEqual('root');
      const directAdapter = new UiLabV4HostAdapter(callbacks);
      expect(directAdapter !== null).assertTrue();
    });

    it('serializes projection pushes and rejects empty payloads', 0, (): void => {
      const pushed: string[] = [];
      const revisions: number[] = [];
      const diagnostics: string[] = [];
      const callbacks: UiLabV4ProjectionCallbacks = {
        pushSurfaceJson: (json: string, revision: number): void => {
          pushed.push(json);
          revisions.push(revision);
        },
        pushDiagnostic: (code: string, detail: string): void => { diagnostics.push(code + detail); }
      };
      const bridge = new UiLabV4ProjectionBridge(callbacks);
      expect(bridge.pushSurfaceJson('')).assertEqual(0);
      expect(bridge.pushSurfaceJson('{"surfaceId":"s"}')).assertEqual(1);
      expect(bridge.pushSurfaceJson('{"surfaceId":"s2"}')).assertEqual(2);
      expect(pushed.length).assertEqual(2);
      expect(revisions[1]).assertEqual(2);
      expect(diagnostics.length).assertEqual(1);
    });

    it('migrates legacy data, overlays and trusted actions without shadow differences', 0, (): void => {
      const pushed: string[] = [];
      const bridgeCallbacks: UiLabV4ProjectionCallbacks = {
        pushSurfaceJson: (json: string): void => { pushed.push(json); },
        pushDiagnostic: (): void => undefined
      };
      const bridge = new UiLabV4ProjectionBridge(bridgeCallbacks);
      const controller = new UiSurfaceController();
      const mirror = new UiLabV4ShadowMirror(controller, bridge);
      const actionArgs: UiLabV4TestActionArgs = { cardId: 'card-1' };
      const action: A2uiAction = {
        id: 'open-card', label: 'Open', prompt: 'Open card', variant: 'primary', kind: 'tool', args: actionArgs
      };
      const components: A2uiComponent[] = [
        { id: 'root', component: 'SurfaceRoot', children: ['card'], renderState: 'ready' },
        { id: 'card', component: 'Text', text: 'Card', pinned: true, actions: [action] }
      ];
      const legacy: A2uiSurfaceState = {
        surfaceId: 'mirror-surface', rootId: 'root', title: 'Mirror', intent: 'test', status: 'ok',
        sequence: 2, dataModelJson: '{"items":[{"id":"item-1"}]}', error: '',
        components
      };
      const result = mirror.apply(legacy, 'mirror-run', 1, true);
      expect(result.match).assertTrue();
      expect(result.categories.length).assertEqual(0);
      expect(controller.snapshot('mirror-surface').data?.viewModelType).assertEqual('legacy-a2ui-data');
      expect(controller.snapshot('mirror-surface').runtime?.nodePhases['root']).assertEqual('confirmed');
      expect(controller.snapshot('mirror-surface').user?.pinnedNodeKeys).assertContain('card');
      expect(result.projected.components[1].actions?.[0].prompt).assertEqual('Open card');
      const projectedArgs = result.projected.components[1].actions?.[0].args as UiLabV4TestActionArgs;
      expect(projectedArgs.cardId).assertEqual('card-1');
      expect(pushed.length).assertEqual(1);
    });
  });
}
