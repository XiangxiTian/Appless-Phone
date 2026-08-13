export interface UiPriceValue {
  amount: number;
  currency: string;
  label?: string;
}

export interface UiFactValue {
  label: string;
  value: string;
}

export type UiStatusTone = 'neutral' | 'positive' | 'warning' | 'negative';

export interface UiStatusValue {
  code: string;
  label: string;
  tone: UiStatusTone;
}

export interface UiMediaRef {
  assetKey: string;
  alt: string;
}

export interface UiOptionItem {
  id: string;
  kind: string;
  title: string;
  subtitle?: string;
  description?: string;
  media?: UiMediaRef;
  badges?: string[];
  facts?: UiFactValue[];
  price?: UiPriceValue;
  status?: UiStatusValue;
  actionRefs?: string[];
}

export interface UiOptionCollection {
  schemaId: 'ui.option-collection';
  schemaVersion: number;
  items: UiOptionItem[];
}

export interface UiKeyValueItem {
  id: string;
  label: string;
  value: string;
}

export interface UiKeyValueGroup {
  schemaId: 'ui.key-value-group';
  schemaVersion: number;
  items: UiKeyValueItem[];
}

export interface UiMessageItem {
  id: string;
  sender: string;
  senderDetail?: string;
  subject?: string;
  preview: string;
  timestamp?: string;
  unread?: boolean;
  badges?: string[];
  actionRefs?: string[];
}

export interface UiMessageFeed {
  schemaId: 'ui.message-feed';
  schemaVersion: number;
  items: UiMessageItem[];
}

export interface UiJourneyOption {
  id: string;
  kind: 'train' | 'flight' | 'bus' | 'mixed';
  title: string;
  origin: string;
  destination: string;
  departAt: string;
  arriveAt: string;
  duration?: string;
  price?: UiPriceValue;
  status?: UiStatusValue;
  badges?: string[];
  actionRefs?: string[];
}

export interface UiJourneyOptionCollection {
  schemaId: 'ui.journey-option-collection';
  schemaVersion: number;
  items: UiJourneyOption[];
}

export interface UiResultItem {
  id: string;
  title: string;
  summary?: string;
  fields?: UiFactValue[];
  status?: UiStatusValue;
  actionRefs?: string[];
}

export interface UiResultCollection {
  schemaId: 'ui.result-collection';
  schemaVersion: number;
  items: UiResultItem[];
}

export interface UiTimelineItem {
  id: string;
  title: string;
  timestamp?: string;
  description?: string;
  status?: UiStatusValue;
}

export interface UiTimeline {
  schemaId: 'ui.timeline';
  schemaVersion: number;
  items: UiTimelineItem[];
}

export interface UiMetricItem {
  id: string;
  label: string;
  value: string;
  unit?: string;
  trend?: 'up' | 'down' | 'flat';
  tone?: UiStatusTone;
}

export interface UiMetricGrid {
  schemaId: 'ui.metric-grid';
  schemaVersion: number;
  items: UiMetricItem[];
}

export interface UiFormFieldModel {
  id: string;
  label: string;
  type: 'text' | 'number' | 'date' | 'select' | 'checkbox';
  value?: string | number | boolean | null;
  required?: boolean;
  options?: string[];
}

export interface UiFormModel {
  schemaId: 'ui.form-model';
  schemaVersion: number;
  fields: UiFormFieldModel[];
  actionRefs?: string[];
}

export interface UiApprovalModel {
  schemaId: 'ui.approval-model';
  schemaVersion: number;
  title: string;
  summary: string;
  consequences?: string[];
  actionRefs: string[];
}

export interface UiPresentationSource {
  toolId: string;
  outputSchemaRef: string;
  provider: string;
  data: Object;
  surfaceId: string;
  runId: string;
}

export interface UiPresentationContext {
  actionRefsByItemId: Map<string, string[]>;
}

export interface UiPresentationProvenance {
  toolId: string;
  outputSchemaRef: string;
  provider: string;
  adapterId: string;
  adapterVersion: number;
}

export interface UiPresentationEnvelope {
  viewModelType: string;
  viewModelVersion: number;
  data: Object;
  provenance: UiPresentationProvenance;
}
