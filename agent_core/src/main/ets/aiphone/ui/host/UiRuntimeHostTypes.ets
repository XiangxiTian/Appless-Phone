export type UiHostRenderer = 'webview' | 'arkui' | 'test';

export interface UiSurfaceRequest {
  runId: string;
  surfaceId: string;
  epoch: number;
  userInput: string;
  taskShape: string;
  catalogGroups: string[];
  renderer: UiHostRenderer;
}

export interface UiSurfaceSession {
  runId: string;
  surfaceId: string;
  epoch: number;
  startedAtMs: number;
  status: 'active' | 'completed' | 'canceled' | 'error';
}

export interface UiHostToolResult {
  /** Stable host correlation id; optional for legacy producers. */
  resultId?: string;
  runId: string;
  surfaceId: string;
  epoch: number;
  toolId: string;
  outputSchemaRef: string;
  provider: string;
  data: Object;
  status: string;
}

export interface UiModelDelta {
  runId: string;
  surfaceId: string;
  format: 'a2ui-json' | 'ui-lang';
  text: string;
}

export interface UiModelResult {
  runId: string;
  surfaceId: string;
  format: 'a2ui-json' | 'ui-lang';
  text: string;
  accepted: boolean;
}

export interface UiHostActionOffer {
  offerId: string;
  actionId: string;
  label: string;
  targetIdentity: string;
  risk: 'read' | 'draft' | 'confirm_required' | 'blocked';
}

export interface UiEvent {
  eventId: string;
  runId: string;
  surfaceId: string;
  epoch: number;
  nodeKey: string;
  eventType: 'activate' | 'change' | 'select' | 'approve' | 'reject' | 'local_mutation';
  offerId?: string;
  payload?: Object;
}

export type AgentUiEventKind = 'run' | 'tool' | 'activity' | 'interrupt' | 'error' | 'completed';

export interface AgentUiEvent {
  eventId: string;
  runId: string;
  surfaceId: string;
  epoch: number;
  kind: AgentUiEventKind;
  status: string;
  message?: string;
}
