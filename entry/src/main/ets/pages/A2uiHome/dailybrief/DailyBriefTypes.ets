import { A2uiAction, WaterfallFeedState } from '@loop/agent-core';

export type DailyBriefSourceId =
  'calendar' | 'todo' | 'yesterday' | 'mail' | 'waterfall' |
  'weather' | 'commute' | 'health' | 'spending';

export type DailyBriefSourceState =
  'success' | 'fixture' | 'empty' | 'needs_auth' | 'error' | 'timeout';

export type DailyBriefSeverity = 'none' | 'notice' | 'warn' | 'severe';
export type DailyBriefHighlightSlot = 'time_constraint' | 'action_needed' | 'status_alert';

export interface DailyBriefPreference {
  topics: string[];
  language: '中文优先' | '中英混合';
  timeBudgetMinutes: number;
  formats: string[];
  negativePreference: string;
  targetTime: string;
}

export interface DailyBriefItem {
  id: string;
  sourceId: DailyBriefSourceId;
  sourceRecordId: string;
  title: string;
  summary: string;
  timeLabel: string;
  startsAt: string;
  dueAt: string;
  leaveBy: string;
  completed: boolean;
  needsAction: boolean;
  severity: DailyBriefSeverity;
  action?: A2uiAction;
}

export interface DailyBriefSection {
  id: 'today' | 'yesterday' | 'mail' | 'weather_commute' | 'health' | 'spending';
  title: string;
  state: DailyBriefSourceState;
  message: string;
  items: DailyBriefItem[];
}

export interface DailyBriefHighlight {
  slot: DailyBriefHighlightSlot;
  item: DailyBriefItem;
}

export interface DailyBriefDiscoveryItem {
  id: string;
  source: string;
  mediaType: 'video' | 'image_text' | 'post';
  title: string;
  summary: string;
  url: string;
  reason: string;
  timeBudgetLabel: string;
}

export interface DailyBriefDemoScenario {
  routeLabel: string;
  origin: string;
  originLongitude: number;
  originLatitude: number;
  destination: string;
  destinationLongitude: number;
  destinationLatitude: number;
  departureLabel: string;
  preferredVehicle: string;
  outfitTitle: string;
  outfitSummary: string;
  outfitImage: string;
}

export interface DailyBriefSourceSummary {
  sourceId: DailyBriefSourceId;
  state: DailyBriefSourceState;
  message: string;
}

export interface DailyBriefSnapshot {
  schemaVersion: 1;
  date: string;
  generatedAt: string;
  status: 'complete' | 'partial';
  profile: DailyBriefPreference;
  topThree: DailyBriefHighlight[];
  sections: DailyBriefSection[];
  discovery: DailyBriefDiscoveryItem[];
  sources: DailyBriefSourceSummary[];
  waterfall: WaterfallFeedState | null;
  actions: A2uiAction[];
}
