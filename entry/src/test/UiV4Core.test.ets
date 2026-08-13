import { describe, expect, it } from '@ohos/hypium';
import {
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiPresentationAdapterRegistry,
  UiPresentationContext,
  UiPresentationSource,
  UiRunCoordinator,
  UiRuntimeHostPorts,
  UiSurfaceRequest,
  UiSurfaceSession,
  buildUiCatalogPrompt,
  canonicalSurfaceFingerprint,
  createChoicePresentationAdapters,
  createDefaultUiCatalogRegistry,
  initialUiRevision
} from '@loop/agent-core';

class RecordingHost implements UiRuntimeHostPorts {
  readonly requested: UiSurfaceRequest[] = [];
  readonly sessions: UiSurfaceSession[] = [];
  readonly actions: UiEvent[] = [];
  readonly diagnostics: string[] = [];

  requestLayout(request: UiSurfaceRequest): void {
    this.requested.push(request);
  }

  emitAction(event: UiEvent): void {
    this.actions.push(event);
  }

  onSessionChanged(session: UiSurfaceSession): void {
    this.sessions.push(session);
  }

  onDiagnostic(code: string, detail: string): void {
    this.diagnostics.push(code + ':' + detail);
  }
}

export default function uiV4CoreTest(): void {
  describe('UiV4Core', (): void => {
    it('builds a layered catalog and stable prompt signature', 0, (): void => {
      const registry = createDefaultUiCatalogRegistry();
      const prompt = buildUiCatalogPrompt(registry, ['foundation', 'semantic']);
      expect(registry.resolve('ChoiceList') !== null).assertTrue();
      expect(registry.resolve('RouteMap') === null).assertTrue();
      expect(prompt.includes('ChoiceList')).assertTrue();
      expect(prompt.includes('RouteMap')).assertFalse();
      expect(registry.snapshot(['foundation', 'semantic']).capabilityHash.length > 0).assertTrue();
    });

    it('maps different option schemas into one view model', 0, (): void => {
      const registry = new UiPresentationAdapterRegistry();
      createChoicePresentationAdapters().forEach((adapter): void => registry.register(adapter));
      const context: UiPresentationContext = { actionRefsByItemId: new Map<string, string[]>() };
      const source: UiPresentationSource = {
        toolId: 'restaurant.search',
        outputSchemaRef: 'restaurant-search-result.v1',
        provider: 'test-provider',
        surfaceId: 'surface-1',
        runId: 'run-1',
        data: {
          items: [{ shop_id: 'r-1', shop_name: 'Test Kitchen', address: 'Shenzhen' }]
        }
      };
      const output = registry.adapt(source, context);
      const data = output.data as Record<string, Object>;
      const items = data['items'] as Object[];
      expect(output.viewModelType).assertEqual('ui.option-collection');
      expect(items.length).assertEqual(1);
      expect((items[0] as Record<string, Object>)['id']).assertEqual('r-1');
      expect(output.provenance.provider).assertEqual('test-provider');
    });

    it('keeps UiRunCoordinator downstream of the host runtime', 0, (): void => {
      const host = new RecordingHost();
      const presentation = new UiPresentationAdapterRegistry();
      const coordinator = new UiRunCoordinator(host, presentation);
      const request: UiSurfaceRequest = {
        runId: 'run-1',
        surfaceId: 'surface-1',
        epoch: 3,
        userInput: 'show status',
        taskShape: 'status-report',
        catalogGroups: ['foundation', 'semantic'],
        renderer: 'test'
      };
      coordinator.startSurface(request);
      const delta: UiModelDelta = {
        runId: 'run-1', surfaceId: 'surface-1', format: 'a2ui-json', text: '{}'
      };
      coordinator.onModelDelta(delta);
      const result: UiModelResult = {
        runId: 'run-1', surfaceId: 'surface-1', format: 'a2ui-json',
        text: '{"updateComponents":{"surfaceId":"surface-1","components":[{"id":"root","component":"Surface"}]}}',
        accepted: true
      };
      coordinator.onModelCompleted(result);
      coordinator.onUiEvent({
        eventId: 'event-1', runId: 'run-1', surfaceId: 'surface-1', epoch: 3,
        nodeKey: 'button-1', eventType: 'activate', offerId: 'offer-1'
      });
      expect(host.requested.length).assertEqual(1);
      expect(host.actions.length).assertEqual(1);
      expect(coordinator.session('run-1')?.status).assertEqual('completed');
    });

    it('rejects stale events and keeps revision shape runtime-neutral', 0, (): void => {
      const host = new RecordingHost();
      const coordinator = new UiRunCoordinator(host, new UiPresentationAdapterRegistry());
      coordinator.startSurface({
        runId: 'run-2', surfaceId: 'surface-2', epoch: 4, userInput: '',
        taskShape: 'empty', catalogGroups: ['foundation'], renderer: 'test'
      });
      coordinator.onModelDelta({
        runId: 'run-2', surfaceId: 'surface-2', format: 'ui-lang', text: 'x'
      });
      coordinator.onUiEvent({
        eventId: 'stale', runId: 'run-2', surfaceId: 'surface-2', epoch: 3,
        nodeKey: 'x', eventType: 'activate'
      });
      expect(host.actions.length).assertEqual(0);
      expect(host.diagnostics.length).assertEqual(1);
      const revision = initialUiRevision(4);
      expect(canonicalSurfaceFingerprint({
        schemaVersion: 1, surfaceId: 'surface-2', runId: 'run-2', epoch: 4,
        rootNodeKey: 'root', title: '', intent: '', catalogVersion: 'v1', nodes: [], revision
      }).length > 0).assertTrue();
    });
  });
}
