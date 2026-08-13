import { UiPresentationAdapterRegistry } from '../presentation/UiPresentationAdapterRegistry';
import { UiPresentationContext, UiPresentationSource } from '../presentation/UiPresentationTypes';
import { UiRuntimeHostPorts } from '../host/UiRuntimeHostPorts';
import { A2uiJsonOutputAdapter } from '../compiler/A2uiJsonOutputAdapter';
import { UiCompileContext } from '../compiler/UiModelOutputAdapter';
import { UiCatalogRegistry } from '../catalog/UiCatalogRegistry';
import { createDefaultUiCatalogRegistry } from '../catalog/DefaultUiCatalog';
import { UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiReconciler } from './UiReconciler';
import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiSurfaceRequest,
  UiSurfaceSession
} from '../host/UiRuntimeHostTypes';
import { UiSurfaceController } from './UiSurfaceController';

interface UiRunState {
  session: UiSurfaceSession;
  request: UiSurfaceRequest;
  modelDeltaCount: number;
  toolResultCount: number;
  lastEventId: string;
  jsonAdapter: A2uiJsonOutputAdapter;
}

export class UiRunCoordinator {
  private readonly host: UiRuntimeHostPorts;
  private readonly presentation: UiPresentationAdapterRegistry;
  private readonly catalogRegistry: UiCatalogRegistry;
  private readonly reconciler: UiReconciler = new UiReconciler();
  readonly surfaceController: UiSurfaceController;
  private readonly runs: Map<string, UiRunState> = new Map<string, UiRunState>();

  constructor(
    host: UiRuntimeHostPorts,
    presentation: UiPresentationAdapterRegistry,
    surfaceController: UiSurfaceController = new UiSurfaceController(),
    catalogRegistry: UiCatalogRegistry = createDefaultUiCatalogRegistry()
  ) {
    this.host = host;
    this.presentation = presentation;
    this.surfaceController = surfaceController;
    this.catalogRegistry = catalogRegistry;
  }

  startSurface(request: UiSurfaceRequest): UiSurfaceSession {
    if (request.runId.length === 0 || request.surfaceId.length === 0) {
      throw new Error('INVALID_UI_SURFACE_REQUEST');
    }
    const session: UiSurfaceSession = {
      runId: request.runId,
      surfaceId: request.surfaceId,
      epoch: request.epoch,
      startedAtMs: Date.now(),
      status: 'active'
    };
    this.runs.set(request.runId, {
      session,
      request,
      modelDeltaCount: 0,
      toolResultCount: 0,
      lastEventId: '',
      jsonAdapter: new A2uiJsonOutputAdapter()
    });
    this.host.onSessionChanged(session);
    this.host.requestLayout(request);
    return session;
  }

  onAgentEvent(event: AgentUiEvent): void {
    const state = this.stateFor(event.runId, event.surfaceId, event.epoch);
    if (state === null) return;
    if (event.eventId === state.lastEventId) return;
    state.lastEventId = event.eventId;
    if (event.kind === 'error') this.updateStatus(state, 'error');
    if (event.kind === 'completed') this.updateStatus(state, 'completed');
  }

  onToolResult(result: UiHostToolResult): void {
    const state = this.stateFor(result.runId, result.surfaceId, result.epoch);
    if (state === null) return;
    state.toolResultCount++;
    const context: UiPresentationContext = { actionRefsByItemId: new Map<string, string[]>() };
    const source: UiPresentationSource = {
      toolId: result.toolId,
      outputSchemaRef: result.outputSchemaRef,
      provider: result.provider,
      data: result.data,
      surfaceId: result.surfaceId,
      runId: result.runId
    };
    try {
      const envelope = this.presentation.adapt(source, context);
      this.surfaceController.setDataModel(
        result.surfaceId,
        envelope.data,
        state.toolResultCount,
        envelope.viewModelType,
        envelope.viewModelVersion,
        envelope.provenance as Object
      );
    } catch (error) {
      this.host.onDiagnostic('PRESENTATION_ADAPTER_FAILURE', String(error));
    }
  }

  onModelDelta(delta: UiModelDelta): void {
    const state = this.stateFor(delta.runId, delta.surfaceId, this.epochFor(delta.runId));
    if (state === null) return;
    state.modelDeltaCount++;
    if (delta.format !== 'a2ui-json') return;
    const compiled = state.jsonAdapter.feed(delta.text, this.compileContext(state));
    if (compiled !== null && compiled.ok && compiled.surface !== null) {
      this.commitCompiledSurface(compiled.surface);
    }
  }

  onModelCompleted(result: UiModelResult): void {
    const state = this.stateFor(result.runId, result.surfaceId, this.epochFor(result.runId));
    if (state === null) return;
    if (!result.accepted) {
      this.host.onDiagnostic('MODEL_CANDIDATE_REJECTED', result.format);
      return;
    }
    if (result.format === 'a2ui-json') {
      const compiled = state.jsonAdapter.compile(result.text, this.compileContext(state));
      if (!compiled.ok || compiled.surface === null) {
        this.host.onDiagnostic('MODEL_CANDIDATE_REJECTED', this.compileErrorSummary(compiled.errors));
        return;
      }
      this.commitCompiledSurface(compiled.surface);
    } else {
      this.host.onDiagnostic('MODEL_FORMAT_UNSUPPORTED', result.format);
      return;
    }
    this.updateStatus(state, 'completed');
  }

  onUiEvent(event: UiEvent): void {
    const state = this.stateFor(event.runId, event.surfaceId, event.epoch);
    if (state === null) return;
    this.host.emitAction(event);
  }

  cancelSurface(runId: string, reason: string): void {
    const state = this.runs.get(runId);
    if (state === undefined) return;
    this.updateStatus(state, 'canceled');
    this.host.onDiagnostic('UI_SURFACE_CANCELED', reason);
  }

  session(runId: string): UiSurfaceSession | null {
    const state = this.runs.get(runId);
    return state === undefined ? null : { ...state.session };
  }

  private stateFor(runId: string, surfaceId: string, epoch: number): UiRunState | null {
    const state = this.runs.get(runId);
    if (state === undefined || state.session.surfaceId !== surfaceId || state.session.epoch !== epoch) {
      if (state !== undefined) this.host.onDiagnostic('STALE_UI_EVENT', runId + ':' + surfaceId);
      return null;
    }
    return state;
  }

  private epochFor(runId: string): number {
    const state = this.runs.get(runId);
    return state === undefined ? -1 : state.session.epoch;
  }

  private compileContext(state: UiRunState): UiCompileContext {
    return {
      surfaceId: state.session.surfaceId,
      runId: state.session.runId,
      epoch: state.session.epoch,
      catalogGroups: state.request.catalogGroups,
      catalogRegistry: this.catalogRegistry
    };
  }

  private commitCompiledSurface(surface: UiCanonicalSurface): void {
    const previous = this.surfaceController.layoutStore.get(surface.surfaceId);
    const next = previous === null ? surface : this.reconciler.reconcile(previous, surface).surface;
    this.surfaceController.commitLayout(next);
    this.host.publishSurface(next);
  }

  private compileErrorSummary(errors: { code: string; message: string }[]): string {
    if (errors.length === 0) return 'unknown compiler error';
    return errors.map((error): string => error.code + ':' + error.message).join('|');
  }

  private updateStatus(state: UiRunState, status: 'completed' | 'error' | 'canceled'): void {
    if (state.session.status !== 'active') return;
    state.session.status = status;
    this.host.onSessionChanged({ ...state.session });
  }
}
