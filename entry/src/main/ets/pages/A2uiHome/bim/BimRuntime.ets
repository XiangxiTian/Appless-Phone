import {
  LocalModel,
  LeaderBimDashboardItem,
  calendarDateFromPrompt,
  emptyA2uiSurface,
  extractJsonObjects,
  mapsRouteInputFromPrompt,
  validLeaderBimDashboardItems
} from '@loop/agent-core';
import {
  BimContextSnapshot,
  BimPublishedState,
  BimRecord,
  BimRetrievalIndex,
  BimStore,
  createBimRecord
} from './BimStore';

const MAX_SENTINEL_EVENTS: number = 10;
const MAX_ATTENTIONS_PER_BIM: number = 8;
const MAX_ATTENTION_CHARS: number = 480;
const MAX_BIM_EVIDENCE_CHARS: number = 2000;
const CONFIRMED_WRITE_TOOL_IDS: string[] = [
  'calendar.event.create',
  'calendar.event.update',
  'calendar.event.delete',
  'gmail.message.send',
  'luckin.order.create',
  'ride.order.create',
  'ride.order.cancel',
  'web.monitor.create',
  'whatsapp.message.send'
];

export interface BimSnapshotItem {
  id: string;
  title: string;
  version: number;
  lifecycle: 'active' | 'quiet' | 'tucked';
  markdown: string;
}

export interface BimLoadedContext {
  id: string;
  title: string;
  version: number;
  fullContextMarkdown: string;
  contextJson: string;
  retrievalIndex: BimRetrievalIndex;
  dashboardSurfaceJsons: string[];
}

export function activeBimSnapshots(records: BimRecord[]): BimSnapshotItem[] {
  const snapshots: BimSnapshotItem[] = [];
  for (let index = 0; index < records.length; index++) {
    const record = records[index];
    if (record.lifecycle === 'ended') continue;
    snapshots.push({
      id: record.id,
      title: record.title,
      version: record.snapshotVersion,
      lifecycle: record.lifecycle,
      markdown: record.snapshotMarkdown
    });
  }
  return snapshots;
}

export function buildBimSnapshotPrompt(query: string, records: BimRecord[]): string {
  const snapshots = activeBimSnapshots(records);
  const blocks: string[] = [];
  for (let index = 0; index < snapshots.length; index++) {
    const item = snapshots[index];
    blocks.push('## ' + item.title + '\n- bimId: ' + item.id +
      '\n- version: ' + item.version.toString() + '\n- lifecycle: ' + item.lifecycle +
      '\n\n' + item.markdown);
  }
  return '[BIM_SNAPSHOTS]\n' + blocks.join('\n\n') +
    '\n[/BIM_SNAPSHOTS]\n\n' + query.trim();
}

export interface BimForegroundRequest {
  query: string;
  prompt: string;
  sourceBimId: string;
}

export function buildBimForegroundRequest(
  query: string,
  records: BimRecord[],
  sourceBimId: string = ''
): BimForegroundRequest {
  const trimmed = query.trim();
  return {
    query: trimmed,
    prompt: buildBimSnapshotPrompt(trimmed, records),
    sourceBimId
  };
}

export function bimDetailSubmitError(baseUrl: string): string {
  return baseUrl.trim().length === 0 ? '请先填写 Base URL。' : '';
}

export function safeBimToolResultSummary(summary: string): string {
  return summary.split('\n')
    .filter((line: string): boolean => line.toLowerCase().indexOf('credential') < 0)
    .join('\n')
    .substring(0, MAX_BIM_EVIDENCE_CHARS);
}

export class BimSkill {
  private readonly store: BimStore;

  constructor(store: BimStore) {
    this.store = store;
  }

  load(ids: string[]): BimLoadedContext[] {
    const loaded: BimLoadedContext[] = [];
    const seen: string[] = [];
    for (let index = 0; index < ids.length && seen.length < 10; index++) {
      const id = ids[index].trim();
      if (id.length === 0 || seen.indexOf(id) >= 0) continue;
      seen.push(id);
      const record = this.store.get(id);
      if (record === undefined || record.lifecycle === 'ended') continue;
      loaded.push({
        id: record.id,
        title: record.title,
        version: record.snapshotVersion,
        fullContextMarkdown: record.fullContextMarkdown,
        contextJson: record.contextJson,
        retrievalIndex: record.retrievalIndex,
        dashboardSurfaceJsons: record.dashboardSurfaceJsons === undefined ?
          [] : record.dashboardSurfaceJsons.slice()
      });
    }
    return loaded;
  }
}

export interface BimTurnEvidence {
  query: string;
  sourceBimId: string;
  visibleSource: string;
  assistantReply: string;
  surfaceSummary: string;
  toolResultSummary: string;
  userConfirmedCompletion: boolean;
  userConfirmedCreate: boolean;
}

export interface BimCuratorResult {
  updatedBimIds: string[];
  createdBimIds: string[];
  error: string;
}

interface BimCuratorUpdate extends BimPublishedState {
  bimId: string;
  expectedVersion: number;
}

interface BimCuratorCreate {
  id: string;
  title: string;
  fullContextMarkdown: string;
  snapshotMarkdown: string;
  context: BimContextSnapshot;
  retrievalIndex: BimRetrievalIndex;
}

interface BimCuratorEnvelope {
  updates: BimCuratorUpdate[];
  creates: BimCuratorCreate[];
}

type BimJsonValue = Object | string | number | boolean | null | undefined;

function exactObjectKeys(value: Object, expected: string[]): boolean {
  return Object.keys(value).sort().join(',') === expected.slice().sort().join(',');
}

function oneJsonObject(raw: string): Object | null {
  try {
    const objects = extractJsonObjects(raw);
    if (objects.length !== 1) return null;
    const parsed = JSON.parse(objects[0]) as Object;
    return parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : null;
  } catch (_error) {
    return null;
  }
}

function parsedLoadBimIds(raw: string, records: BimRecord[]): string[] | null {
  const object = oneJsonObject(raw);
  if (object === null || !exactObjectKeys(object, ['loadBimIds'])) return null;
  const value = object as Record<string, BimJsonValue>;
  const rawIds = value['loadBimIds'];
  if (!Array.isArray(rawIds) || rawIds.length > 10) return null;
  const allowed: string[] = [];
  for (let index = 0; index < records.length; index++) {
    if (records[index].lifecycle !== 'ended') allowed.push(records[index].id);
  }
  const ids: string[] = [];
  const values = rawIds as Object[];
  for (let index = 0; index < values.length; index++) {
    const id = values[index];
    if (typeof id !== 'string' || allowed.indexOf(id) < 0 || ids.indexOf(id) >= 0) return null;
    ids.push(id);
  }
  return ids;
}

function parsedSentinelLoadBimIds(raw: string, records: BimRecord[]): string[] | null {
  const strict = parsedLoadBimIds(raw, records);
  if (strict !== null) return strict;
  const match = /loadBimIds\s*\[\s*(\[[^\]]*\])\s*\]/.exec(raw);
  if (match === null) return null;
  try {
    const parsed = JSON.parse(match[1]) as Object;
    if (!Array.isArray(parsed) || parsed.length > 10) return null;
    const values = parsed as Object[];
    const ids: string[] = [];
    for (let index = 0; index < values.length; index++) {
      if (typeof values[index] !== 'string') return null;
      const value = values[index] as string;
      const matches = records.filter((record: BimRecord): boolean =>
        record.lifecycle !== 'ended' && (record.id === value || record.title === value));
      if (matches.length !== 1 || ids.indexOf(matches[0].id) >= 0) return null;
      ids.push(matches[0].id);
    }
    return ids;
  } catch (_error) {
    return null;
  }
}

function curatorSelectionPrompt(records: BimRecord[], evidence: BimTurnEvidence): string {
  return 'You are the BIM Curator selector. Read only BIM Snapshots and turn evidence. ' +
    'Return one JSON object only: {"loadBimIds":[...]}. Select only clearly related non-ended BIM IDs. ' +
    'A correction can replace old locations, dates, status, or next steps; those conflicts are evidence of an ' +
    'update, not evidence that the matter is unrelated. A valid sourceBimId is strong relation evidence. ' +
    'Return an empty list when none is clearly related. Do not update BIM or call tools.\n' +
    JSON.stringify({ snapshots: activeBimSnapshots(records), evidence });
}

function curatorUpdatePrompt(loaded: BimLoadedContext[], evidence: BimTurnEvidence): string {
  return 'You are the BIM Curator. Return one JSON object only with exactly updates and creates arrays. ' +
    'Each update must contain bimId, expectedVersion, title, fullContextMarkdown, snapshotMarkdown, context, ' +
    'retrievalIndex, and relatedBimIds. context.dashboardItems is required, even when empty. ' +
    'Return one complete next Context + View, never patches, and replace superseded facts everywhere. ' +
    'Creates may contain at most one item with id, title, fullContextMarkdown, snapshotMarkdown, context, ' +
    'and retrievalIndex, and only when the user explicitly asked to remember or keep following the matter. ' +
    'context and retrievalIndex MUST be JSON objects, never strings. ' +
    'The top-level updates/creates wrapper is mandatory; never return a bare update or create item. ' +
    'Use this exact shape: {"updates":[{"bimId":"...","expectedVersion":1,"title":"...",' +
    '"fullContextMarkdown":"...","snapshotMarkdown":"...",' +
    '"context":{"summary":"...","facts":[],"constraints":[],"decisions":[],"dashboardItems":[]},' +
    '"retrievalIndex":{"summary":"...","entities":[],"timeAnchors":[],"locations":[],' +
    '"commitments":[],"keywords":[]},"relatedBimIds":[]}],"creates":[{"id":"...","title":"...",' +
    '"fullContextMarkdown":"...","snapshotMarkdown":"...",' +
    '"context":{"summary":"...","facts":[],"constraints":[],"decisions":[]},' +
    '"retrievalIndex":{"summary":"...","entities":[],"timeAnchors":[],"locations":[],' +
    '"commitments":[],"keywords":[]}}]}. ' +
    'Never claim payment, booking, ticketing, or completion without the user assertion or provider receipt ' +
    'in the evidence. Do not call business tools.\n' + JSON.stringify({ loaded, evidence });
}

function parsedContext(value: BimJsonValue): BimContextSnapshot | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) return null;
  const raw = value as Record<string, BimJsonValue>;
  if (!exactObjectKeys(value as Object, ['summary', 'facts', 'constraints', 'decisions']) &&
    !exactObjectKeys(value as Object, ['summary', 'facts', 'constraints', 'decisions', 'dashboardItems'])) {
    return null;
  }
  if (typeof raw['summary'] !== 'string' || !Array.isArray(raw['facts']) ||
    !Array.isArray(raw['constraints']) || !Array.isArray(raw['decisions']) ||
    !validLeaderBimDashboardItems(raw['dashboardItems'] as LeaderBimDashboardItem[] | undefined)) return null;
  return value as BimContextSnapshot;
}

function parsedIndex(value: BimJsonValue): BimRetrievalIndex | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value) ||
    !exactObjectKeys(value as Object,
      ['summary', 'entities', 'timeAnchors', 'locations', 'commitments', 'keywords'])) return null;
  const raw = value as Record<string, BimJsonValue>;
  if (typeof raw['summary'] !== 'string' || !Array.isArray(raw['entities']) ||
    !Array.isArray(raw['timeAnchors']) || !Array.isArray(raw['locations']) ||
    !Array.isArray(raw['commitments']) || !Array.isArray(raw['keywords'])) return null;
  return value as BimRetrievalIndex;
}

function parsedStringList(value: BimJsonValue): string[] | null {
  if (!Array.isArray(value)) return null;
  const raw = value as Object[];
  const result: string[] = [];
  for (let index = 0; index < raw.length; index++) {
    if (typeof raw[index] !== 'string') return null;
    result.push(raw[index] as string);
  }
  return result;
}

function parsedCuratorUpdate(value: Object): BimCuratorUpdate | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value) || !exactObjectKeys(value,
    ['bimId', 'expectedVersion', 'title', 'fullContextMarkdown', 'snapshotMarkdown', 'context',
      'retrievalIndex', 'relatedBimIds'])) return null;
  const raw = value as Record<string, BimJsonValue>;
  const context = parsedContext(raw['context']);
  const retrievalIndex = parsedIndex(raw['retrievalIndex']);
  const relatedBimIds = parsedStringList(raw['relatedBimIds']);
  if (typeof raw['bimId'] !== 'string' || typeof raw['expectedVersion'] !== 'number' ||
    typeof raw['title'] !== 'string' || context?.dashboardItems === undefined ||
    typeof raw['fullContextMarkdown'] !== 'string' || typeof raw['snapshotMarkdown'] !== 'string' ||
    context === null || retrievalIndex === null || relatedBimIds === null) return null;
  return {
    bimId: raw['bimId'] as string,
    expectedVersion: raw['expectedVersion'] as number,
    title: raw['title'] as string,
    fullContextMarkdown: raw['fullContextMarkdown'] as string,
    snapshotMarkdown: raw['snapshotMarkdown'] as string,
    context,
    retrievalIndex,
    relatedBimIds
  };
}

function parsedCuratorCreate(value: Object): BimCuratorCreate | null {
  if (value === null || typeof value !== 'object' || Array.isArray(value) || !exactObjectKeys(value,
    ['id', 'title', 'fullContextMarkdown', 'snapshotMarkdown', 'context', 'retrievalIndex'])) return null;
  const raw = value as Record<string, BimJsonValue>;
  const context = parsedContext(raw['context']);
  const retrievalIndex = parsedIndex(raw['retrievalIndex']);
  if (typeof raw['id'] !== 'string' || typeof raw['title'] !== 'string' ||
    typeof raw['fullContextMarkdown'] !== 'string' || typeof raw['snapshotMarkdown'] !== 'string' ||
    context === null || retrievalIndex === null) return null;
  return {
    id: raw['id'] as string,
    title: raw['title'] as string,
    fullContextMarkdown: raw['fullContextMarkdown'] as string,
    snapshotMarkdown: raw['snapshotMarkdown'] as string,
    context,
    retrievalIndex
  };
}

function parsedCuratorEnvelope(raw: string): BimCuratorEnvelope | null {
  const object = oneJsonObject(raw);
  if (object === null || !exactObjectKeys(object, ['updates', 'creates'])) return null;
  const value = object as Record<string, BimJsonValue>;
  if (!Array.isArray(value['updates']) || !Array.isArray(value['creates'])) return null;
  const rawUpdates = value['updates'] as Object[];
  const rawCreates = value['creates'] as Object[];
  if (rawCreates.length > 1 || rawUpdates.length > 10) return null;
  const updates: BimCuratorUpdate[] = [];
  const creates: BimCuratorCreate[] = [];
  for (let index = 0; index < rawUpdates.length; index++) {
    const update = parsedCuratorUpdate(rawUpdates[index]);
    if (update === null || updates.some((item: BimCuratorUpdate): boolean =>
      item.bimId === update.bimId)) return null;
    updates.push(update);
  }
  for (let index = 0; index < rawCreates.length; index++) {
    const create = parsedCuratorCreate(rawCreates[index]);
    if (create === null) return null;
    creates.push(create);
  }
  return { updates, creates };
}

export function explicitBimCreateRequest(query: string): boolean {
  return /帮我记住|记在心上|持续跟进/.test(query);
}

function unverifiedCompletionClaim(update: BimCuratorUpdate, evidence: BimTurnEvidence): boolean {
  const state = update.fullContextMarkdown + '\n' + update.snapshotMarkdown + '\n' +
    JSON.stringify(update.context);
  const providerClaim = /已支付|已预订|已出票/;
  const completionClaim = /已完成/;
  let receipt = false;
  if ((providerClaim.test(evidence.toolResultSummary) || completionClaim.test(evidence.toolResultSummary)) &&
    evidence.toolResultSummary.indexOf('status=success') >= 0) {
    for (let index = 0; index < CONFIRMED_WRITE_TOOL_IDS.length; index++) {
      if (evidence.toolResultSummary.indexOf('toolId: ' + CONFIRMED_WRITE_TOOL_IDS[index]) >= 0) {
        receipt = true;
        break;
      }
    }
  }
  const userAssertedCompletion = /已完成|已经完成|完成了/.test(evidence.query) &&
    !/如果|若|是否|有没有|吗|？|\?/.test(evidence.query);
  return (providerClaim.test(state) || (completionClaim.test(state) && !userAssertedCompletion)) &&
    !evidence.userConfirmedCompletion && !receipt;
}

function curatorError(message: string): BimCuratorResult {
  return { updatedBimIds: [], createdBimIds: [], error: message };
}

export async function runBimCurator(
  store: BimStore,
  model: LocalModel,
  evidence: BimTurnEvidence,
  nowIso: string
): Promise<BimCuratorResult> {
  const records = store.list();
  let loadIds: string[] | null = null;
  for (let attempt = 0; attempt < 2 && loadIds === null; attempt++) {
    try {
      loadIds = parsedLoadBimIds(
        await model.complete(curatorSelectionPrompt(records, evidence)), records
      );
    } catch (_error) {
      loadIds = null;
    }
  }
  if (loadIds === null) return curatorError('BIM_CURATOR_SELECTION_INVALID');
  const explicitCreate = explicitBimCreateRequest(evidence.query) && evidence.userConfirmedCreate;
  if (loadIds.length === 0 && !explicitCreate) {
    return { updatedBimIds: [], createdBimIds: [], error: '' };
  }
  const loaded = new BimSkill(store).load(loadIds);
  let envelope: BimCuratorEnvelope | null = null;
  for (let attempt = 0; attempt < 2 && envelope === null; attempt++) {
    try {
      const repair = attempt === 0 ? '' :
        '\nPrevious output was invalid. dashboardItems must be inside the context object, not beside context: ' +
        '"context":{"summary":"...","facts":[],"constraints":[],"decisions":[],' +
        '"dashboardItems":[...]}. When evidence contains a date, progress, status, or next step, ' +
        'dashboardItems must include those visible cards and must not be empty. ' +
        'Each dashboard item has exactly kind, title, value, detail, status. Allowed kind values are ' +
        'progress, metric, person, timeline, task, hotel, flight, transport, event. Example: ' +
        '{"kind":"task","title":"下一步","value":"确认展位","detail":"","status":"待处理"}. ' +
        'Never use type or label keys. ' +
        'Return the complete wrapper again; do not omit or relocate any required field.';
      envelope = parsedCuratorEnvelope(await model.complete(curatorUpdatePrompt(loaded, evidence) + repair));
    } catch (_error) {
      envelope = null;
    }
  }
  if (envelope === null) return curatorError('BIM_CURATOR_UPDATE_INVALID');
  const loadedIds = loaded.map((item: BimLoadedContext): string => item.id);
  const updatedBimIds: string[] = [];
  const createdBimIds: string[] = [];
  let error = '';
  for (let index = 0; index < envelope.updates.length; index++) {
    const update = envelope.updates[index];
    if (loadedIds.indexOf(update.bimId) < 0 || unverifiedCompletionClaim(update, evidence) ||
      !store.publishState(update.bimId, update.expectedVersion, update, nowIso)) {
      error = 'BIM_CURATOR_PUBLISH_REJECTED';
      continue;
    }
    updatedBimIds.push(update.bimId);
  }
  if (explicitCreate && envelope.creates.length === 1) {
    const create = envelope.creates[0];
    const surface = emptyA2uiSurface('surface-' + create.id);
    surface.title = create.title;
    surface.intent = 'bim';
    surface.status = 'ready';
    const record = createBimRecord(
      create.id, create.title, create.context, create.retrievalIndex, JSON.stringify(surface), nowIso
    );
    record.snapshotMarkdown = create.snapshotMarkdown;
    record.fullContextMarkdown = create.fullContextMarkdown;
    if (store.create(record)) {
      createdBimIds.push(record.id);
    } else {
      error = 'BIM_CURATOR_CREATE_REJECTED';
    }
  }
  return { updatedBimIds, createdBimIds, error };
}

export interface BimAttentionEvent {
  bimId: string;
  title: string;
  observedAt: string;
  attentions: string[];
}

function sentinelSelectionPrompt(records: BimRecord[]): string {
  return 'You are the read-only BIM Sentinel selector. Read only BIM Snapshots. ' +
    'Return one JSON object only: {"loadBimIds":[...]}. Select only BIMs that may need attention now. ' +
    'Use bimId values, never titles. Never return Execution or Action text. ' +
    'Return an empty list when none does. Do not update BIM or call tools.\n' +
    JSON.stringify({ snapshots: activeBimSnapshots(records) });
}

function sentinelAttentionPrompt(loaded: BimLoadedContext[]): string {
  return 'You are the read-only BIM Sentinel. Return one JSON object only: ' +
    '{"events":[{"bimId":"...","attentions":["..."]}]}. ' +
    'Use only loaded BIM IDs and concrete attention supported by the Full Context. ' +
    'Return an empty events list when no user attention is needed. Do not update BIM or call tools.\n' +
    JSON.stringify({ loaded });
}

function parsedAttentionEvents(raw: string, loaded: BimLoadedContext[]): BimAttentionEvent[] | null {
  const object = oneJsonObject(raw);
  if (object === null || !exactObjectKeys(object, ['events'])) return null;
  const values = object as Record<string, BimJsonValue>;
  if (!Array.isArray(values['events'])) return null;
  const rawEvents = values['events'] as Object[];
  if (rawEvents.length > MAX_SENTINEL_EVENTS) return null;
  const result: BimAttentionEvent[] = [];
  for (let index = 0; index < rawEvents.length; index++) {
    const rawEvent = rawEvents[index];
    if (rawEvent === null || typeof rawEvent !== 'object' || Array.isArray(rawEvent) ||
      !exactObjectKeys(rawEvent, ['bimId', 'attentions'])) return null;
    const event = rawEvent as Record<string, BimJsonValue>;
    const attentions = parsedStringList(event['attentions']);
    if (typeof event['bimId'] !== 'string' || attentions === null || attentions.length === 0 ||
      attentions.length > MAX_ATTENTIONS_PER_BIM) return null;
    const bimId = event['bimId'] as string;
    const loadedItem = loaded.find((item: BimLoadedContext): boolean => item.id === bimId);
    if (loadedItem === undefined) return null;
    let target = result.find((item: BimAttentionEvent): boolean => item.bimId === bimId);
    if (target === undefined) {
      target = { bimId, title: loadedItem.title, observedAt: '', attentions: [] };
      result.push(target);
    }
    for (let attentionIndex = 0; attentionIndex < attentions.length; attentionIndex++) {
      const attention = attentions[attentionIndex].trim();
      if (attention.length === 0 || attention.length > MAX_ATTENTION_CHARS) return null;
      if (target.attentions.indexOf(attention) < 0 &&
        target.attentions.length >= MAX_ATTENTIONS_PER_BIM) return null;
      if (target.attentions.indexOf(attention) < 0) target.attentions.push(attention);
    }
  }
  return result;
}

export async function runBimSentinel(
  store: BimStore,
  model: LocalModel,
  observedAt: string = new Date().toISOString()
): Promise<BimAttentionEvent[]> {
  const records = store.list();
  const loadIds = parsedSentinelLoadBimIds(await model.complete(sentinelSelectionPrompt(records)), records);
  if (loadIds === null) throw new Error('BIM_SENTINEL_SELECTION_INVALID');
  if (loadIds.length === 0) return [];
  const loaded = new BimSkill(store).load(loadIds);
  const events = parsedAttentionEvents(await model.complete(sentinelAttentionPrompt(loaded)), loaded);
  if (events === null) throw new Error('BIM_SENTINEL_ATTENTION_INVALID');
  for (let index = 0; index < events.length; index++) events[index].observedAt = observedAt;
  return events;
}

export function bimAttentionVisibleText(event: BimAttentionEvent): string {
  return '来自心上事「' + event.title + '」';
}

export function buildBimAttentionPrompt(event: BimAttentionEvent): string {
  return '[BIM_ATTENTION]\n' + JSON.stringify({
    bimId: event.bimId,
    observedAt: event.observedAt,
    attentions: event.attentions
  }) + '\n[/BIM_ATTENTION]\n请根据这些待关注事项主动帮助用户。';
}

export function refreshedSelectedBimRecord(
  selectedBimId: string,
  records: BimRecord[]
): BimRecord | null {
  for (let index = 0; index < records.length; index++) {
    if (records[index].id === selectedBimId) return records[index];
  }
  return null;
}

export function selectedBimRecordForRender(
  selectedBimId: string,
  snapshot: BimRecord | null
): BimRecord | null {
  return snapshot !== null && snapshot.id === selectedBimId ? snapshot : null;
}

export function bimDetailRenderKey(recordId: string, renderTick: number): string {
  return recordId + '-' + renderTick.toString();
}

export function originalQueryFromBimPrompt(prompt: string): string {
  if (prompt.indexOf('[BIM_SNAPSHOTS]\n') !== 0) return prompt;
  const end = prompt.indexOf('[/BIM_SNAPSHOTS]\n\n');
  return end < 0 ? prompt : prompt.substring(end + '[/BIM_SNAPSHOTS]\n\n'.length);
}

export function bimTravelQueryIsComplete(query: string, now: Date = new Date()): boolean {
  const value = query.trim();
  const flightNumber = /\b[A-Z0-9]{2,3}\d{1,4}\b/i.exec(value);
  const hasFlightNumber = flightNumber !== null && /[A-Z]/i.test(flightNumber[0]);
  return (mapsRouteInputFromPrompt(value) !== null || hasFlightNumber) &&
    calendarDateFromPrompt(value, now).length > 0;
}
