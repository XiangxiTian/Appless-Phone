import {
  AgentMessage,
  MemoryRecallObservation,
  MemoryRecallOrigin,
  UserInputPayload
} from '../message/AgentMessage';
import { ToolBackendType, ToolRiskLevel } from '../../aiphone/runtime/ToolDefinitionTypes';

export const MAX_LEADER_DATA_TASKS_PER_ROUND: number = 8;
export const MAX_LEADER_DATA_TASKS_PER_TURN: number = 24;
export const MEMORY_RECALL_DEFAULT_TOP_K: number = 5;
export const MEMORY_RECALL_MIN_TOP_K: number = 1;
export const MEMORY_RECALL_MAX_TOP_K: number = 20;
export const MEMORY_RECALL_FACT_MAX_CHARS: number = 240;
export const MEMORY_RECALL_TOTAL_MAX_CHARS: number = 4800;

export function validMemoryRecallTopK(topK: number): boolean {
  return Number.isSafeInteger(topK) && topK >= MEMORY_RECALL_MIN_TOP_K &&
    topK <= MEMORY_RECALL_MAX_TOP_K;
}

export function memoryRecallTotalMaxChars(topK: number): number {
  return Math.min(topK * MEMORY_RECALL_FACT_MAX_CHARS, MEMORY_RECALL_TOTAL_MAX_CHARS);
}

export type InputUserPayload = UserInputPayload;

export interface LeaderUiTask {
  taskId: string;
  intent: string;
  expectedOutputSchema: string;
}

export interface LeaderDataTask {
  taskId: string;
  toolId: string;
  outputSchema: string;
  args: Object;
}

export type LeaderRoundAction = 'execute' | 'answer' | 'clarify';

export interface LeaderActionIntent {
  goal: string;
  allowedActionIds: string[];
}

export interface LeaderMemoryRememberFact {
  fact: string;
}

export interface LeaderMemoryRememberMutation {
  operation: 'remember';
  facts: LeaderMemoryRememberFact[];
}

export interface LeaderMemoryUpdateMutation {
  operation: 'update';
  updates: LeaderMemoryUpdateItem[];
}

export interface LeaderMemoryUpdateItem {
  memoryId: string;
  fact: string;
}

export interface LeaderMemoryForgetMutation {
  operation: 'forget';
  memoryId: string;
}

export interface LeaderMemoryForgetClarification {
  operation: 'forget';
}

export type LeaderMemoryMutation = LeaderMemoryRememberMutation |
  LeaderMemoryUpdateMutation | LeaderMemoryForgetMutation;

export interface LeaderMemoryToolRequest {
  conversationId: string;
  turnId: string;
  sourceTaskId: string;
  personaId: string;
  mutation: LeaderMemoryMutation;
}

export interface LeaderMemoryToolResult {
  status: 'success' | 'partial' | 'error';
  message: string;
}

export interface LeaderMemoryToolExecutionGuard {
  isActive(): boolean;
}

export interface LeaderMemoryToolExecutor {
  execute(
    request: LeaderMemoryToolRequest,
    guard: LeaderMemoryToolExecutionGuard
  ): Promise<LeaderMemoryToolResult>;
}

export interface LeaderMemoryRecallToolCall {
  toolId: 'memory.recall';
  query: string;
  topK?: number;
}

export interface LeaderMemoryRecallToolRequest {
  callId: string;
  conversationId: string;
  turnId: string;
  sourceTaskId: string;
  origin: MemoryRecallOrigin;
  query: string;
  topK: number;
}

export interface LeaderMemoryRecallToolExecutor {
  recall(
    request: LeaderMemoryRecallToolRequest,
    guard: LeaderMemoryToolExecutionGuard
  ): Promise<MemoryRecallObservation>;
}

export interface LeaderDecisionDataTask {
  localId: string;
  goal: string;
  allowedToolIds: string[];
  toolId: string;
  input: Object;
  required: boolean;
}

export interface LeaderUiIntent {
  purpose: string;
  preferredDensity: string;
  requiredSections: string[];
}

export interface LeaderBimSuggestion {
  title: string;
  summary: string;
  reason: string;
  keywords: string[];
}

export type LeaderBimDashboardItemKind =
  'progress' | 'metric' | 'person' | 'timeline' | 'task' |
  'hotel' | 'flight' | 'transport' | 'event';

export interface LeaderBimDashboardItem {
  kind: LeaderBimDashboardItemKind;
  title: string;
  value: string;
  detail: string;
  status: string;
}

function validDashboardKind(value: string): boolean {
  return value === 'progress' || value === 'metric' || value === 'person' ||
    value === 'timeline' || value === 'task' || value === 'hotel' ||
    value === 'flight' || value === 'transport' || value === 'event';
}

function validDashboardText(value: string, maximum: number, required: boolean = false): boolean {
  return typeof value === 'string' && value.length <= maximum && value === value.trim() &&
    (!required || value.length > 0);
}

export function validLeaderBimDashboardItems(
  items: LeaderBimDashboardItem[] | undefined
): boolean {
  if (items === undefined) return true;
  if (!Array.isArray(items) || items.length > 32) return false;
  const seen: string[] = [];
  for (let index = 0; index < items.length; index++) {
    const item = items[index];
    if (item === null || item === undefined ||
      Object.keys(item).sort().join(',') !== 'detail,kind,status,title,value' ||
      !validDashboardKind(item.kind) ||
      !validDashboardText(item.title, 80, true) ||
      !validDashboardText(item.value, 80) ||
      !validDashboardText(item.detail, 240) ||
      !validDashboardText(item.status, 40)) return false;
    const identity = item.kind + '\n' + item.title;
    if (seen.indexOf(identity) >= 0) return false;
    seen.push(identity);
  }
  return true;
}

export interface LeaderBimContextUpdate {
  summary: string;
  facts: string[];
  constraints: string[];
  decisions: string[];
  entities: string[];
  timeAnchors: string[];
  locations: string[];
  commitments: string[];
  keywords: string[];
  dashboardItems?: LeaderBimDashboardItem[];
}

export interface LeaderDecision {
  personaId: string;
  skillId: string;
  requestedCapabilityIds: string[];
  roundAction: LeaderRoundAction;
  dataTasks: LeaderDecisionDataTask[];
  uiIntent: LeaderUiIntent;
  normalizationCurrentLocalDate?: string;
  normalizedActionInputText?: string;
  actionIntent?: LeaderActionIntent;
  memoryMutation?: LeaderMemoryMutation;
  memoryClarification?: LeaderMemoryForgetClarification;
  leaderToolCall?: LeaderMemoryRecallToolCall;
  answer?: string;
  bimSuggestion?: LeaderBimSuggestion;
  bimContextUpdate?: LeaderBimContextUpdate;
  reasonCode: string;
}

export interface LeaderPlan {
  personaId: string;
  skillId: string;
  roundAction: LeaderRoundAction;
  ui: LeaderUiTask;
  dataTasks: LeaderDataTask[];
  actionIntent?: LeaderActionIntent;
  answer?: string;
  reasonCode: string;
}

export interface LeaderToolMetadata {
  toolId: string;
  domain: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  registeredBackends: ToolBackendType[];
  inputSchema: string;
  outputSchema: string;
  actions: string[];
  planningHint?: string;
}

export interface LeaderSkillMetadata {
  skillId: string;
  description: string;
  instructions: string;
  status: string;
  toolIds: string[];
}

export interface LeaderPersonaMetadata {
  personaId: string;
  name: string;
  domains: string[];
  previous: boolean;
  activeSkills: LeaderSkillMetadata[];
}

export interface LeaderPlanningContext {
  tools: LeaderToolMetadata[];
  personas: LeaderPersonaMetadata[];
  lockedPersonaId?: string;
  lockedSkillId?: string;
}

export type LeaderDataTaskInputNormalizer = (
  input: InputUserPayload,
  task: LeaderDecisionDataTask,
  currentLocalDate: string
) => Object;

export type LeaderCurrentLocalDateProvider = () => string;

export type LeaderPlannerResult = LeaderPlan | LeaderDecision;
export type LeaderPlanningSignal = () => boolean;

export interface LeaderPlanner {
  plan(
    message: AgentMessage,
    input: InputUserPayload,
    context: LeaderPlanningContext,
    round?: number,
    signal?: LeaderPlanningSignal,
    currentLocalDate?: string
  ): Promise<LeaderPlannerResult>;
}
