import {
  AgentUiEvent,
  UiEvent,
  UiHostToolResult,
  UiModelDelta,
  UiModelResult,
  UiSurfaceRequest,
  UiSurfaceSession
} from './UiRuntimeHostTypes';
import { UiCanonicalSurface } from '../ir/UiCanonicalTypes';

export interface UiRuntimeHostPorts {
  requestLayout(request: UiSurfaceRequest): void;
  emitAction(event: UiEvent): void;
  publishSurface(surface: UiCanonicalSurface): void;
  onSessionChanged(session: UiSurfaceSession): void;
  onDiagnostic(code: string, detail: string): void;
}

export interface UiRuntimeHostSink {
  onAgentEvent(event: AgentUiEvent): void;
  onToolResult(result: UiHostToolResult): void;
  onModelDelta(delta: UiModelDelta): void;
  onModelCompleted(result: UiModelResult): void;
}
