import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiRuntimeHostPorts,
  UiSurfaceRequest,
  UiSurfaceSession
} from '@loop/agent-core';

export interface UiLabV4HostCallbacks {
  onLayoutRequest: (request: UiSurfaceRequest) => void;
  onActionEvent: (event: UiEvent) => void;
  onSession: (session: UiSurfaceSession) => void;
  onDiagnostic: (code: string, detail: string) => void;
}

export class UiLabV4HostAdapter implements UiRuntimeHostPorts {
  private readonly callbacks: UiLabV4HostCallbacks;

  constructor(callbacks: UiLabV4HostCallbacks) {
    this.callbacks = callbacks;
  }

  requestLayout(request: UiSurfaceRequest): void {
    this.callbacks.onLayoutRequest(request);
  }

  emitAction(event: UiEvent): void {
    this.callbacks.onActionEvent(event);
  }

  onSessionChanged(session: UiSurfaceSession): void {
    this.callbacks.onSession(session);
  }

  onDiagnostic(code: string, detail: string): void {
    this.callbacks.onDiagnostic(code, detail);
  }

  acceptAgentEvent(coordinator: { onAgentEvent: (event: AgentUiEvent) => void }, event: AgentUiEvent): void {
    coordinator.onAgentEvent(event);
  }

  acceptToolResult(coordinator: { onToolResult: (result: UiHostToolResult) => void }, result: UiHostToolResult): void {
    coordinator.onToolResult(result);
  }

  acceptModelDelta(coordinator: { onModelDelta: (delta: UiModelDelta) => void }, delta: UiModelDelta): void {
    coordinator.onModelDelta(delta);
  }

  acceptModelCompleted(coordinator: { onModelCompleted: (result: UiModelResult) => void }, result: UiModelResult): void {
    coordinator.onModelCompleted(result);
  }
}
