import { describe, expect, it } from '@ohos/hypium';
import {
  UiEvent,
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
      const diagnostics: string[] = [];
      const callbacks: UiLabV4HostCallbacks = {
        onLayoutRequest: (request: UiSurfaceRequest): void => requests.push(request),
        onActionEvent: (event: UiEvent): void => actions.push(event),
        onSession: (session: UiSurfaceSession): void => sessions.push(session),
        onDiagnostic: (code: string, detail: string): void => diagnostics.push(code + detail)
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
      expect(requests.length).assertEqual(1);
      expect(sessions.length).assertEqual(1);
      expect(actions.length).assertEqual(1);
      expect(diagnostics.length).assertEqual(0);
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
        pushDiagnostic: (code: string, detail: string): void => diagnostics.push(code + detail)
      };
      const bridge = new UiLabV4ProjectionBridge(callbacks);
      expect(bridge.pushSurfaceJson('')).assertEqual(0);
      expect(bridge.pushSurfaceJson('{"surfaceId":"s"}')).assertEqual(1);
      expect(bridge.pushSurfaceJson('{"surfaceId":"s2"}')).assertEqual(2);
      expect(pushed.length).assertEqual(2);
      expect(revisions[1]).assertEqual(2);
      expect(diagnostics.length).assertEqual(1);
    });
  });
}
