import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiSurfaceRequest,
  UiSurfaceSession
} from './UiRuntimeHostTypes';

export interface UiRuntimeHostPorts {
  requestLayout(request: UiSurfaceRequest): void;
  emitAction(event: UiEvent): void;
  onSessionChanged(session: UiSurfaceSession): void;
  onDiagnostic(code: string, detail: string): void;
}

export interface UiRuntimeHostSink {
  onAgentEvent(event: AgentUiEvent): void;
  onToolResult(result: UiHostToolResult): void;
  onModelDelta(delta: UiModelDelta): void;
  onModelCompleted(result: UiModelResult): void;
}
