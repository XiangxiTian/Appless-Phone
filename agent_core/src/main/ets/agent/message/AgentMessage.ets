import { LeaderBimContextUpdate, LeaderBimSuggestion } from '../leader/LeaderTypes';
import { MemoryAuthority } from '../../memory/MemoryTypes';

export enum AgentMessageType {
  INPUT_USER = 'INPUT.USER',
  TASK_CREATE_UI = 'TASK.CREATE.UI',
  TASK_CREATE_DATA = 'TASK.CREATE.DATA',
  TASK_RESULT_UI = 'TASK.RESULT.UI',
  TASK_RESULT_DATA = 'TASK.RESULT.DATA',
  TASK_RESULT_DATA_PARTIAL = 'TASK.RESULT.DATA.PARTIAL',
  TASK_ERROR = 'TASK.ERROR',
  ACTION_PLAN_DRAFT = 'ACTION.PLAN.DRAFT',
  ACTION_OFFERS_READY = 'ACTION.OFFERS.READY',
  ACTION_PLAN_READY = 'ACTION.PLAN.READY',
  ACTION_RUN = 'ACTION.RUN',
  ACTION_PROGRESS = 'ACTION.PROGRESS',
  ACTION_RESULT = 'ACTION.RESULT',
  TURN_CANCEL = 'TURN.CANCEL',
  ACTION_PLAN_REQUEST = 'ACTION.PLAN.REQUEST',
  TURN_RESULT = 'TURN.RESULT'
}

export interface AgentMessage {
  type: AgentMessageType;
  conversationId: string;
  turnId: string;
  taskId: string;
  payload: Object;
}

export type RuntimeOwner = 'multi_agent' | 'legacy';

export type TurnConversationRole = 'user' | 'assistant';

export interface ConversationTurnMessage {
  role: TurnConversationRole;
  content: string;
}

export interface CurrentSurfaceSummary {
  surfaceId: string;
  kind: string;
  status: string;
  entityRefs: string[];
  actionOfferIds: string[];
}

export interface ObservationDigest {
  taskId: string;
  toolId: string;
  status: string;
  summary: string;
  entityRefs: string[];
}

/**
 * A bounded projection of one phone-local long-term memory for Leader planning.
 * It intentionally excludes embeddings, hashes, source turns, and storage fields.
 */
export interface RecalledMemoryContext {
  memoryId: string;
  fact: string;
  personaTag: string;
  authority: MemoryAuthority;
}

export type MemoryRecallOrigin = 'prefetch' | 'leader';
export type MemoryRecallStatus = 'success' | 'empty' | 'error';
/** Matches the per-message model-visible context bound used by the session pipeline. */
export const MEMORY_RECALL_OBSERVATION_QUERY_MAX_CHARS: number = 2000;

/**
 * One bounded, model-visible item returned by the Leader-local memory.recall tool.
 * Retrieval order carries relevance rank. Numeric retrieval scores remain internal and
 * are intentionally excluded from the model-visible observation.
 */
export interface MemoryRecallItem extends RecalledMemoryContext {}

/** First-class internal tool observation; it is serialized as text for non-tool-call models. */
export interface MemoryRecallObservation {
  callId: string;
  origin: MemoryRecallOrigin;
  query: string;
  status: MemoryRecallStatus;
  items: MemoryRecallItem[];
}

export interface MemorySelectionPayload {
  operation: 'forget';
  originTurnId: string;
  sourceTaskId: string;
  personaId: string;
  /** Every bounded memory recalled for the origin turn, in its original order (1-5 items). */
  candidates: RecalledMemoryContext[];
}

export interface UserInputPayload {
  text: string;
  recentMessages?: ConversationTurnMessage[];
  /** Rolling, model-generated summary of older session messages. Untrusted conversation context only. */
  sessionSummary?: string;
  recalledMemories?: RecalledMemoryContext[];
  /** Optional continuity hint only; every new turn still selects its own persona. */
  lastTurnPersonaId?: string;
  /** @deprecated compatibility alias for callers not yet migrated. */
  previousPersonaId?: string;
  memoryRecallObservation?: MemoryRecallObservation;
  currentSurfaceSummary?: CurrentSurfaceSummary;
  recentObservations?: ObservationDigest[];
  orderedContinuationAuthorized?: boolean;
}

export type TurnResultStatus = 'success' | 'partial' | 'empty' | 'error' | 'canceled';

export interface TurnResultPayload {
  status: TurnResultStatus;
  surfaceId?: string;
  roundCount: number;
  message: string;
  personaId?: string;
  skillId?: string;
  bimSuggestion?: LeaderBimSuggestion;
  bimContextUpdate?: LeaderBimContextUpdate;
  memorySelection?: MemorySelectionPayload;
}

export interface UiTaskPayload {
  component: string;
  data: Object;
}

export interface DataTaskPayload {
  toolId: string;
  input: Object;
}

export interface UiResultPayload {
  surfaceId: string;
  data: Object;
}

export interface TaskErrorPayload {
  code: string;
  message: string;
  retryable?: boolean;
}
