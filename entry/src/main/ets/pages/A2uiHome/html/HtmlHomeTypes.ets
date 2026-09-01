import {
  A2uiComponent,
  A2uiFoodSearchContext,
  WaterfallFeedState,
  WaterfallFormat,
  WaterfallRankedCandidate,
  WaterfallSourceState
} from '@loop/agent-core';
import { DailyBriefPreference, DailyBriefSnapshot } from '../dailybrief/DailyBriefTypes';
import { WaterfallCardReaction, WaterfallSavedCard } from '../waterfall/WaterfallPreferencesStore';

export type HtmlHomeSource = 'welcome' | 'pending' | 'model' | 'tool';
export type HtmlHomeKind = 'welcome' | 'thinking' | 'travel' | 'hotel' | 'food' | 'social' | 'dynamic-tools' | 'gmail' | 'media' | 'payment' | 'aggregate-search' | 'luckin' | 'multi-task' | 'daily-brief' | 'generic';

export interface HtmlHomeChip {
  label: string;
  value?: string;
}

export interface HtmlHomeMetric {
  label: string;
  value: string;
}

export interface HtmlHomeTimelineItem {
  title: string;
  subtitle?: string;
  status?: string;
}

export interface HtmlHomeAction {
  id: string;
  label: string;
  prompt: string;
  variant: string;
  kind: string;
  sourceComponentId?: string;
  sourceToolId?: string;
  args?: Object;
}

export interface HtmlHomeMediaEmbed {
  provider: string;
  title: string;
  embedUrl: string;
  pageUrl: string;
  thumbnail?: string;
}

export interface HtmlHomeStripeReceiving {
  status: string;
  message: string;
  stripeAccountId: string;
  onboardingUrl: string;
  currentlyDue: string[];
}

export interface HtmlHomeMemoryCandidate {
  candidateKey: string;
  fact: string;
}

export interface HtmlHomeBlock {
  id: string;
  kind: string;
  title: string;
  subtitle?: string;
  status?: string;
  source?: string;
  calendarConflict?: boolean;
  calendarConflictTitle?: string;
  credentialName?: string;
  credentialRef?: string;
  toolId?: string;
  sectionId?: string;
  prompt?: string;
  completionReply?: string;
  metrics: HtmlHomeMetric[];
  rows: HtmlHomeMetric[];
  actions: HtmlHomeAction[];
  rawPreview?: string;
  mailTerminalBody?: string;
  mailTerminalError?: string;
  mediaEmbed?: HtmlHomeMediaEmbed;
  stripeReceiving?: HtmlHomeStripeReceiving;
  embeddedDocument?: HtmlHomeDocument;
  foodFavoriteId?: string;
  foodFavorite?: boolean;
  memorySelectionId?: string;
  memorySelectionRevision?: number;
  memoryCandidates?: HtmlHomeMemoryCandidate[];
}

export interface HtmlHomeHistoryItem {
  id: string;
  role: string;
  content: string;
}

export interface HtmlHomePersona {
  id: string;
  name: string;
  avatarKey: string;
  status: string;
  reason: string;
}

export interface HtmlHomePersonaMemory {
  summary: string;
  preferences: string[];
}

export interface WaterfallHomePayload {
  surfaceId: string;
  feedRevision: number;
  mode?: 'search' | 'interest';
  query: string;
  currentId: string;
  stableIds: string[];
  aggregateHtml: string;
  candidates: WaterfallRankedCandidate[];
  mediaEmbeds: Record<string, string>;
  enabledSources: string[];
  sources: WaterfallSourceState[];
  cardStates: WaterfallCardViewState[];
  savedCards: WaterfallSavedCardView[];
  replenishing: boolean;
  exhausted: boolean;
}

export interface WaterfallHomeSnapshotUpdate {
  kind: 'snapshot';
  revision: number;
  payload: WaterfallHomePayload;
}

export interface WaterfallHomePatchUpdate {
  kind: 'patch';
  revision: number;
  baseRevision: number;
  surfaceId: string;
  feedRevision: number;
  currentId: string;
  stableIds: string[];
  appendRenderedCandidateIds: string[];
  updateRenderedCandidateIds: string[];
  candidateIds?: string[];
  upsertCandidates: WaterfallRankedCandidate[];
  removedCandidateIds: string[];
  aggregateHtml?: string;
  mediaEmbeds: Record<string, string>;
  sources: WaterfallSourceState[];
  cardStates: WaterfallCardViewState[];
  savedCards: WaterfallSavedCardView[];
  replenishing: boolean;
  exhausted: boolean;
}

export type WaterfallHomeUpdate = WaterfallHomeSnapshotUpdate | WaterfallHomePatchUpdate;

export interface WaterfallCardViewState {
  candidateId: string;
  reaction: WaterfallCardReaction;
  saved: boolean;
}

export interface WaterfallSavedCardView extends WaterfallSavedCard {
  savedAt: number;
}

export interface WaterfallCardActionArgs {
  surfaceId: string;
  candidateId: string;
  action: 'like' | 'dislike' | 'save';
  active: boolean;
  restoreSavedAt: boolean;
}

export interface WaterfallBehaviorActionArgs {
  surfaceId: string;
  candidateId: string;
  topics: string[];
  source: string;
  format: WaterfallFormat;
  behavior: 'play_complete' | 'read_complete' | 'dwell' | 'quick_skip';
  durationMs: number;
  timestamp: number;
}

export interface HtmlHomeDocument {
  version: number;
  surfaceId?: string;
  source: HtmlHomeSource;
  kind: HtmlHomeKind;
  title: string;
  subtitle: string;
  chips: HtmlHomeChip[];
  metrics: HtmlHomeMetric[];
  timeline: HtmlHomeTimelineItem[];
  blocks: HtmlHomeBlock[];
  actions: HtmlHomeAction[];
  history: HtmlHomeHistoryItem[];
  persona: HtmlHomePersona;
  personaMemory: HtmlHomePersonaMemory;
  rawSurfaceRoot: A2uiComponent | null;
  waterfall?: WaterfallFeedState;
  dailyBrief?: DailyBriefSnapshot;
  dailyBriefPreference?: DailyBriefPreference;
  activeSectionId?: string;
  executionMode?: 'parallel' | 'serial';
  foodSearchContext?: A2uiFoodSearchContext;
  deepSearch?: boolean;
  generatedAt: string;
}
