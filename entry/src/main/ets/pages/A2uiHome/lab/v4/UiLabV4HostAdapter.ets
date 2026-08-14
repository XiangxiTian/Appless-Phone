import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiRuntimeHostPorts,
  UiSurfaceRequest,
  UiSurfaceSession,
  UiCanonicalSurface
} from '@loop/agent-core';

export interface UiLabV4HostCallbacks {
  onLayoutRequest: (request: UiSurfaceRequest) => void;
  onActionEvent: (event: UiEvent) => void;
  onCanonicalSurface: (surface: UiCanonicalSurface) => void;
  onSession: (session: UiSurfaceSession) => void;
  onDiagnostic: (code: string, detail: string) => void;
}

export interface UiLabV4AgentEventConsumer {
  onAgentEvent(event: AgentUiEvent): void;
}

export interface UiLabV4ToolResultConsumer {
  onToolResult(result: UiHostToolResult): void;
}

export interface UiLabV4ModelDeltaConsumer {
  onModelDelta(delta: UiModelDelta): void;
}

export interface UiLabV4ModelResultConsumer {
  onModelCompleted(result: UiModelResult): void;
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

  publishSurface(surface: UiCanonicalSurface): void {
    this.callbacks.onCanonicalSurface(surface);
  }

  onSessionChanged(session: UiSurfaceSession): void {
    this.callbacks.onSession(session);
  }

  onDiagnostic(code: string, detail: string): void {
    this.callbacks.onDiagnostic(code, detail);
  }

  acceptAgentEvent(coordinator: UiLabV4AgentEventConsumer, event: AgentUiEvent): void {
    coordinator.onAgentEvent(event);
  }

  acceptToolResult(coordinator: UiLabV4ToolResultConsumer, result: UiHostToolResult): void {
    coordinator.onToolResult(result);
  }

  acceptModelDelta(coordinator: UiLabV4ModelDeltaConsumer, delta: UiModelDelta): void {
    coordinator.onModelDelta(delta);
  }

  acceptModelCompleted(coordinator: UiLabV4ModelResultConsumer, result: UiModelResult): void {
    coordinator.onModelCompleted(result);
  }
}
