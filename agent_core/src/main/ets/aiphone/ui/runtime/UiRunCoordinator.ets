import { UiPresentationAdapterRegistry } from '../presentation/UiPresentationAdapterRegistry';
import { UiPresentationContext, UiPresentationSource } from '../presentation/UiPresentationTypes';
import { UiRuntimeHostPorts } from '../host/UiRuntimeHostPorts';
import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiSurfaceRequest,
  UiSurfaceSession
} from '../host/UiRuntimeHostTypes';

interface UiRunState {
  session: UiSurfaceSession;
  modelDeltaCount: number;
  toolResultCount: number;
  lastEventId: string;
  dataByTool: Map<string, Object>;
}

export class UiRunCoordinator {
  private readonly host: UiRuntimeHostPorts;
  private readonly presentation: UiPresentationAdapterRegistry;
  private readonly runs: Map<string, UiRunState> = new Map<string, UiRunState>();

  constructor(host: UiRuntimeHostPorts, presentation: UiPresentationAdapterRegistry) {
    this.host = host;
    this.presentation = presentation;
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
      modelDeltaCount: 0,
      toolResultCount: 0,
      lastEventId: '',
      dataByTool: new Map<string, Object>()
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
    state.dataByTool.set(result.toolId, result.data);
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
      this.presentation.adapt(source, context);
    } catch (error) {
      this.host.onDiagnostic('PRESENTATION_ADAPTER_FAILURE', String(error));
    }
  }

  onModelDelta(delta: UiModelDelta): void {
    const state = this.stateFor(delta.runId, delta.surfaceId, this.epochFor(delta.runId));
    if (state === null) return;
    state.modelDeltaCount++;
  }

  onModelCompleted(result: UiModelResult): void {
    const state = this.stateFor(result.runId, result.surfaceId, this.epochFor(result.runId));
    if (state === null) return;
    if (!result.accepted) {
      this.host.onDiagnostic('MODEL_CANDIDATE_REJECTED', result.format);
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

  private updateStatus(state: UiRunState, status: 'completed' | 'error' | 'canceled'): void {
    if (state.session.status !== 'active') return;
    state.session.status = status;
    this.host.onSessionChanged({ ...state.session });
  }
}
