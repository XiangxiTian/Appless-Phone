import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiAction,
  A2uiCallResult,
  A2uiComponent,
  A2uiGenericToolResultData,
  A2uiGenericToolResultRowData,
  A2uiSurfaceState,
  aggregateSearchSearchSourceIds,
  AggregateSearchResult,
  AggregateSearchSourceStatus,
  WaterfallFeedState
} from '@loop/agent-core';
import {
  DailyBriefGenerationOptions,
  DailyBriefLiveLoaders,
  DailyBriefLoadResult,
  generateDailyBrief,
  normalizeDailyBriefGenericCall,
  normalizeDailyBriefWaterfallCall
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefGenerator';
import {
  dailyBriefWaterfallInput,
  defaultDailyBriefPreference
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefCore';
import {
  DailyBriefItem,
  DailyBriefPreference,
  DailyBriefSection,
  DailyBriefSnapshot,
  DailyBriefSourceState
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefTypes';
import {
  parseDailyBriefSnapshots,
  serializeDailyBriefSnapshots
} from '../main/ets/pages/A2uiHome/dailybrief/DailyBriefStore';

class Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T) => void = (_value: T): void => {};

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void): void => {
      this.resolve = resolve;
    });
  }
}

interface PoisonedDailyBriefItem extends DailyBriefItem {
  rawPreview: string;
}

interface PoisonedWaterfallFeedState extends WaterfallFeedState {
  rawPreview: string;
}

interface GenericTestModel {
  genericToolResults: A2uiGenericToolResultData[];
}

interface AggregateTestModel {
  aggregateSearch: AggregateSearchResult;
}

function gatewayCall(
  dataModelJson: string,
  status: string = 'ready',
  components: A2uiComponent[] = [],
  surfaceError: string = '',
  callError: string = ''
): A2uiCallResult {
  const surface: A2uiSurfaceState = {
    surfaceId: 'daily-brief-test',
    rootId: 'root',
    title: 'Provider result',
    intent: 'test',
    status: status,
    components: components,
    dataModelJson: dataModelJson,
    error: surfaceError,
    sequence: 1
  };
  return {
    ok: callError.length === 0,
    raw: 'not persisted',
    error: callError,
    requestDebug: 'not persisted',
    assistantDebug: 'not persisted',
    surface: surface
  };
}

function genericCard(
  status: string,
  summary: string,
  rows: A2uiGenericToolResultRowData[]
): A2uiGenericToolResultData {
  return {
    sourceTag: 'Provider',
    toolName: 'calendar.events.search',
    title: 'Daily event',
    status: status,
    summary: summary,
    rows: rows,
    rawPreview: 'private provider payload'
  };
}

function genericCall(results: A2uiGenericToolResultData[]): A2uiCallResult {
  const model: GenericTestModel = { genericToolResults: results };
  return gatewayCall(JSON.stringify(model));
}

function aggregateCall(
  statuses: AggregateSearchSourceStatus[],
  waterfall: WaterfallFeedState
): A2uiCallResult {
  const aggregate: AggregateSearchResult = {
    query: waterfall.query,
    videos: [],
    posts: [],
    sourceStatuses: statuses,
    summary: 'Visible aggregate summary',
    waterfall: waterfall
  };
  const model: AggregateTestModel = { aggregateSearch: aggregate };
  return gatewayCall(JSON.stringify(model));
}

function item(id: string, sourceId: 'calendar' | 'mail'): DailyBriefItem {
  return {
    id: id,
    sourceId: sourceId,
    sourceRecordId: id + '-record',
    title: id + ' title',
    summary: id + ' visible summary',
    timeLabel: '09:30',
    startsAt: '2026-08-10T09:30:00+08:00',
    dueAt: '',
    leaveBy: '',
    completed: false,
    needsAction: sourceId === 'mail',
    severity: 'none'
  };
}

function result(
  sourceId: 'calendar' | 'mail' | 'waterfall',
  state: DailyBriefSourceState = 'success',
  items: DailyBriefItem[] = [],
  waterfall: WaterfallFeedState | null = null,
  retryable: boolean = false
): DailyBriefLoadResult {
  return {
    sourceId: sourceId,
    state: state,
    message: sourceId + ' ' + state,
    items: items,
    waterfall: waterfall,
    retryable: retryable
  };
}

function feed(): WaterfallFeedState {
  return {
    query: 'Agent HarmonyOS',
    enabledSources: ['youtube', 'bilibili', 'x', 'hackernews', 'reddit', 'zhihu'],
    preferenceDescription: '中文优先；15 分钟内',
    shown: [],
    current: null,
    stable: [],
    tail: [],
    sources: []
  };
}

function options(loaders: DailyBriefLiveLoaders, budgetMs: number = 1000): DailyBriefGenerationOptions {
  return {
    now: new Date('2026-08-10T08:31:00+08:00'),
    preference: defaultDailyBriefPreference(),
    budgetMs: budgetMs,
    loaders: loaders
  };
}

function sourceState(snapshotText: string, sourceId: string): string {
  const parsed = JSON.parse(snapshotText) as Object;
  const sources = (parsed as Record<string, Object | string | number | boolean | null | undefined>)['sources'] as Object[];
  for (let index = 0; index < sources.length; index += 1) {
    const source = sources[index] as Record<string, Object | string | number | boolean | null | undefined>;
    if (source['sourceId'] === sourceId) {
      return source['state'] as string;
    }
  }
  return '';
}

function snapshotSection(snapshot: DailyBriefSnapshot, id: string): DailyBriefSection {
  for (let index = 0; index < snapshot.sections.length; index += 1) {
    if (snapshot.sections[index].id === id) return snapshot.sections[index];
  }
  throw new Error('Missing daily brief section: ' + id);
}

export default function dailyBriefGeneratorTest() {
  describe('DailyBriefGenerator', () => {
    it('requires a real Calendar Event ID before accepting a success row', 0, () => {
      const placeholder = normalizeDailyBriefGenericCall('calendar', genericCall([
        genericCard('success', 'Provider returned a placeholder', [
          { label: 'Start', value: '2026-08-10T09:30:00+08:00' }
        ])
      ]));
      const real = normalizeDailyBriefGenericCall('calendar', genericCall([
        genericCard('success', 'Real event summary', [
          { label: 'Event ID', value: 'event-real-1' },
          { label: 'Start', value: '2026-08-10T09:30:00+08:00' }
        ])
      ]));

      expect(placeholder.state).assertEqual('empty');
      expect(placeholder.items.length).assertEqual(0);
      expect(JSON.stringify(placeholder).indexOf('calendar-0')).assertEqual(-1);
      expect(real.state).assertEqual('success');
      expect(real.items.length).assertEqual(1);
      expect(real.items[0].sourceRecordId).assertEqual('event-real-1');
    });

    it('keeps unsupported mail visible without exposing an unreadable mail action', 0, () => {
      const normalized = normalizeDailyBriefGenericCall('mail', genericCall([
        genericCard('success', 'Visible Outlook message', [
          { label: 'Provider', value: 'outlook' },
          { label: 'Thread ID', value: 'outlook-thread' },
          { label: 'Message ID', value: 'outlook-message' }
        ]),
        genericCard('success', 'Visible Gmail thread without a message identity', [
          { label: 'Provider', value: 'gmail' },
          { label: 'Thread ID', value: 'gmail-thread-only' }
        ]),
        genericCard('success', 'Visible QQ message with an unsupported identity', [
          { label: 'Provider', value: 'qq' },
          { label: 'Message ID', value: 'not-numeric' }
        ]),
        genericCard('success', 'Readable Gmail message', [
          { label: 'Provider', value: 'gmail' },
          { label: 'Thread ID', value: 'gmail-thread' },
          { label: 'Message ID', value: 'gmail-message' }
        ])
      ]));

      expect(normalized.items.length).assertEqual(4);
      expect(normalized.items[0].summary).assertEqual('Visible Outlook message');
      expect(normalized.items[0].needsAction).assertFalse();
      expect(normalized.items[0].action).assertUndefined();
      expect(normalized.items[1].needsAction).assertFalse();
      expect(normalized.items[1].action).assertUndefined();
      expect(normalized.items[2].needsAction).assertFalse();
      expect(normalized.items[2].action).assertUndefined();
      expect(normalized.items[3].needsAction).assertTrue();
      expect(normalized.items[3].action === undefined).assertFalse();
    });

    it('keeps successful mail summaries out of source diagnostics and qualifies provider identities', 0, () => {
      const mixed = normalizeDailyBriefGenericCall('mail', genericCall([
        genericCard('success', '正文不应进入来源诊断', [
          { label: 'Provider', value: 'gmail' },
          { label: 'Message ID', value: '123' },
          { label: 'Received', value: '2026-08-11T08:00:00+08:00' }
        ]),
        genericCard('success', 'QQ 邮件摘要', [
          { label: 'Provider', value: 'qq' },
          { label: 'Message ID', value: '123' },
          { label: 'Received', value: '2026-08-11T07:00:00+08:00' }
        ]),
        genericCard('error', 'OUTLOOK_SEARCH_MESSAGES personal account unsupported', [])
      ]));

      expect(mixed.state).assertEqual('error');
      expect(mixed.items.length).assertEqual(2);
      expect(mixed.items[0].sourceRecordId).assertEqual('gmail:123');
      expect(mixed.items[1].sourceRecordId).assertEqual('qq:123');
      expect(mixed.message.indexOf('正文不应进入来源诊断')).assertEqual(-1);
      expect(mixed.message.indexOf('QQ 邮件摘要')).assertEqual(-1);
      expect(mixed.message.indexOf('OUTLOOK_SEARCH_MESSAGES')).assertLarger(-1);
    });

    it('renders successful daily mail content without exposing a partial provider error in the section', 0, async () => {
      const mixed = normalizeDailyBriefGenericCall('mail', genericCall([
        genericCard('success', '当日 Gmail 摘要', [
          { label: 'Provider', value: 'gmail' },
          { label: 'Message ID', value: 'message-1' },
          { label: 'Received', value: '2026-08-11T08:00:00+08:00' }
        ]),
        genericCard('error', 'OUTLOOK_SEARCH_MESSAGES personal account unsupported', [])
      ]));
      const loaders: DailyBriefLiveLoaders = {
        calendar: async (): Promise<DailyBriefLoadResult> => result('calendar'),
        mail: async (): Promise<DailyBriefLoadResult> => mixed,
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      };
      const input = options(loaders);
      input.now = new Date('2026-08-11T08:31:00+08:00');

      const snapshot = await generateDailyBrief(input);
      const mail = snapshotSection(snapshot, 'mail');

      expect(mail.state).assertEqual('success');
      expect(mail.items.length).assertEqual(1);
      expect(mail.message.indexOf('今天共 1 封邮件')).assertEqual(0);
      expect(mail.message.indexOf('OUTLOOK_SEARCH_MESSAGES')).assertEqual(-1);
      expect(JSON.stringify(snapshot.sources).indexOf('OUTLOOK_SEARCH_MESSAGES')).assertLarger(-1);
    });

    it('uses the real sender when a mail provider has no snippet', 0, () => {
      const mail = normalizeDailyBriefGenericCall('mail', genericCall([
        genericCard('success', '', [
          { label: 'Provider', value: 'qq' },
          { label: 'Message ID', value: '7412' },
          { label: 'From', value: 'Yanke Deng' },
          { label: 'Received', value: '2026-08-13T08:27:49+08:00' }
        ])
      ]));

      expect(mail.items.length).assertEqual(1);
      expect(mail.items[0].summary).assertEqual('来自：Yanke Deng');
    });

    it('keeps an exhausted empty Waterfall as empty while retaining its finite state', 0, () => {
      const waterfall = feed();
      waterfall.sources = [{
        source: 'youtube', phase: 'empty', continuation: null, inFlight: false,
        reservedCount: 0, message: 'No videos'
      }];
      const normalized = normalizeDailyBriefWaterfallCall(aggregateCall([{
        source: 'youtube', label: 'YouTube', status: 'empty', message: 'No videos', count: 0
      }], waterfall));

      expect(normalized.state).assertEqual('empty');
      expect(normalized.waterfall === null).assertFalse();
      expect(normalized.waterfall?.sources[0].phase).assertEqual('empty');
      expect(normalized.retryable).assertFalse();
    });

    it('derives Waterfall retryability only from explicit failing source evidence', 0, () => {
      const retryableError = normalizeDailyBriefWaterfallCall(aggregateCall([{
        source: 'youtube', label: 'YouTube', status: 'error',
        message: 'Provider transport failure: request timeout', count: 0
      }], feed()));
      const blocked = normalizeDailyBriefWaterfallCall(aggregateCall([{
        source: 'youtube', label: 'YouTube', status: 'error',
        message: 'Blocked by provider policy', count: 0
      }], feed()));
      const auth = normalizeDailyBriefWaterfallCall(aggregateCall([{
        source: 'youtube', label: 'YouTube', status: 'needs_auth',
        message: 'OAuth account is not connected', count: 0
      }], feed()));

      expect(retryableError.state).assertEqual('error');
      expect(retryableError.retryable).assertTrue();
      expect(retryableError.message.indexOf('Provider transport failure')).assertLarger(-1);
      expect(blocked.state).assertEqual('error');
      expect(blocked.retryable).assertFalse();
      expect(auth.state).assertEqual('needs_auth');
      expect(auth.retryable).assertFalse();
    });

    it('uses visible ErrorNotice and failed surface truth when generic rows are absent', 0, () => {
      const timeoutNotice: A2uiComponent = {
        id: 'notice', component: 'ErrorNotice', title: 'Calendar failed',
        body: 'Provider HTTP 503 temporarily unavailable', status: 'error'
      };
      const authNotice: A2uiComponent = {
        id: 'notice', component: 'ErrorNotice', title: 'Calendar authorization required',
        body: 'OAuth account is not connected', status: 'needs_auth'
      };
      const errorNotice: A2uiComponent = {
        id: 'notice', component: 'ErrorNotice', title: 'Calendar failed',
        body: 'Blocked by provider policy', status: 'error'
      };
      const retryableError = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'needs_input', [timeoutNotice])
      );
      const auth = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'needs_input', [authNotice])
      );
      const error = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'ready', [errorNotice])
      );
      const failed = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'failed')
      );

      expect(retryableError.state).assertEqual('error');
      expect(retryableError.retryable).assertTrue();
      expect(retryableError.message).assertEqual('Calendar failed：Provider HTTP 503 temporarily unavailable');
      expect(auth.state).assertEqual('needs_auth');
      expect(auth.retryable).assertFalse();
      expect(error.state).assertEqual('error');
      expect(error.retryable).assertFalse();
      expect(failed.state).assertEqual('error');
    });

    it('finite-copies Waterfall state without caller runtime fields', 0, () => {
      const waterfall = feed() as PoisonedWaterfallFeedState;
      waterfall.rawPreview = 'private waterfall payload';
      const normalized = normalizeDailyBriefWaterfallCall(aggregateCall([{
        source: 'youtube', label: 'YouTube', status: 'success', message: 'Provider completed', count: 0
      }], waterfall));

      expect(normalized.state).assertEqual('success');
      expect(JSON.stringify(normalized.waterfall).indexOf('rawPreview')).assertEqual(-1);
      expect(waterfall.rawPreview).assertEqual('private waterfall payload');
    });

    it('starts all three live sources before any one finishes', 0, async () => {
      const started: string[] = [];
      const calendar = new Deferred<DailyBriefLoadResult>();
      const mail = new Deferred<DailyBriefLoadResult>();
      const waterfall = new Deferred<DailyBriefLoadResult>();
      const loaders: DailyBriefLiveLoaders = {
        calendar: (): Promise<DailyBriefLoadResult> => {
          started.push('calendar');
          return calendar.promise;
        },
        mail: (): Promise<DailyBriefLoadResult> => {
          started.push('mail');
          return mail.promise;
        },
        waterfall: (): Promise<DailyBriefLoadResult> => {
          started.push('waterfall');
          return waterfall.promise;
        }
      };

      const pending = generateDailyBrief(options(loaders));
      await Promise.resolve();

      expect(started.join(',')).assertEqual('calendar,mail,waterfall');
      calendar.resolve(result('calendar'));
      mail.resolve(result('mail'));
      waterfall.resolve(result('waterfall', 'success', [], feed()));
      const snapshot = await pending;
      expect(snapshot.status).assertEqual('complete');
    });

    it('retries only an explicitly retryable result once', 0, async () => {
      let calendarCalls = 0;
      let mailCalls = 0;
      let waterfallCalls = 0;
      const loaders: DailyBriefLiveLoaders = {
        calendar: async (): Promise<DailyBriefLoadResult> => {
          calendarCalls += 1;
          return calendarCalls === 1
            ? result('calendar', 'error', [], null, true)
            : result('calendar');
        },
        mail: async (): Promise<DailyBriefLoadResult> => {
          mailCalls += 1;
          return result('mail', 'needs_auth');
        },
        waterfall: async (): Promise<DailyBriefLoadResult> => {
          waterfallCalls += 1;
          return result('waterfall', 'empty');
        }
      };

      const snapshot = await generateDailyBrief(options(loaders));

      expect(calendarCalls).assertEqual(2);
      expect(mailCalls).assertEqual(1);
      expect(waterfallCalls).assertEqual(1);
      expect(snapshot.status).assertEqual('partial');
    });

    it('retries an HTTP 503 error once and preserves the second error state', 0, async () => {
      let calendarCalls = 0;
      const providerError = genericCall([
        genericCard('error', 'Provider HTTP 503 temporarily unavailable', [])
      ]);
      const loaders: DailyBriefLiveLoaders = {
        calendar: async (): Promise<DailyBriefLoadResult> => {
          calendarCalls += 1;
          return normalizeDailyBriefGenericCall('calendar', providerError);
        },
        mail: async (): Promise<DailyBriefLoadResult> => result('mail'),
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      };

      const snapshot = await generateDailyBrief(options(loaders));

      expect(calendarCalls).assertEqual(2);
      expect(sourceState(JSON.stringify(snapshot), 'calendar')).assertEqual('error');
    });

    it('retries the exact local ToolGateway provider-exception surface once', 0, async () => {
      const providerNotice: A2uiComponent = {
        id: 'notice', component: 'ErrorNotice', title: '工具供应商调用异常',
        body: 'connection reset', status: 'needs_input'
      };
      const localCatch = gatewayCall('{}', 'needs_input', [providerNotice]);
      let calendarCalls = 0;
      const loaders: DailyBriefLiveLoaders = {
        calendar: async (): Promise<DailyBriefLoadResult> => {
          calendarCalls += 1;
          return normalizeDailyBriefGenericCall('calendar', localCatch);
        },
        mail: async (): Promise<DailyBriefLoadResult> => result('mail'),
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      };

      const normalized = normalizeDailyBriefGenericCall('calendar', localCatch);
      const snapshot = await generateDailyBrief(options(loaders));

      expect(normalized.state).assertEqual('error');
      expect(calendarCalls).assertEqual(2);
      expect(normalized.retryable).assertTrue();
      expect(sourceState(JSON.stringify(snapshot), 'calendar')).assertEqual('error');
    });

    it('normalizes common auth and invalid-argument errors without retrying', 0, async () => {
      const messages: string[] = [
        'authentication required: HTTP 503',
        'auth required: temporarily unavailable',
        'unauthorized: HTTP 502',
        'invalid argument: timeout must be positive',
        'invalid arguments: HTTP 504'
      ];
      const states: DailyBriefSourceState[] = [
        'needs_auth', 'needs_auth', 'needs_auth', 'error', 'error'
      ];
      for (let index = 0; index < messages.length; index += 1) {
        const providerError = genericCall([genericCard('error', messages[index], [])]);
        let calendarCalls = 0;
        let mailCalls = 0;
        let waterfallCalls = 0;
        const loaders: DailyBriefLiveLoaders = {
          calendar: async (): Promise<DailyBriefLoadResult> => {
            calendarCalls += 1;
            return normalizeDailyBriefGenericCall('calendar', providerError);
          },
          mail: async (): Promise<DailyBriefLoadResult> => {
            mailCalls += 1;
            return result('mail');
          },
          waterfall: async (): Promise<DailyBriefLoadResult> => {
            waterfallCalls += 1;
            return result('waterfall', 'success', [], feed());
          }
        };

        const normalized = normalizeDailyBriefGenericCall('calendar', providerError);
        const snapshot = await generateDailyBrief(options(loaders));

        expect(normalized.state).assertEqual(states[index]);
        expect(normalized.retryable).assertFalse();
        expect(calendarCalls).assertEqual(1);
        expect(mailCalls).assertEqual(1);
        expect(waterfallCalls).assertEqual(1);
        expect(sourceState(JSON.stringify(snapshot), 'calendar')).assertEqual(states[index]);
      }
    });

    it('suppresses retry for needs-input blocked and auth wording collisions', 0, async () => {
      const inputNotice: A2uiComponent = {
        id: 'input', component: 'ErrorNotice', title: 'Calendar input invalid',
        body: 'timeout parameter invalid', status: 'needs_input'
      };
      const authNotice: A2uiComponent = {
        id: 'auth', component: 'ErrorNotice', title: 'Calendar authorization required',
        body: 'temporarily unavailable', status: 'needs_auth'
      };
      const calls: A2uiCallResult[] = [
        gatewayCall('{}', 'needs_input', [inputNotice]),
        genericCall([genericCard('blocked', 'unsupported transport', [])]),
        gatewayCall('{}', 'needs_input', [authNotice])
      ];
      const states: DailyBriefSourceState[] = ['error', 'error', 'needs_auth'];
      for (let index = 0; index < calls.length; index += 1) {
        let calendarCalls = 0;
        const loaders: DailyBriefLiveLoaders = {
          calendar: async (): Promise<DailyBriefLoadResult> => {
            calendarCalls += 1;
            return normalizeDailyBriefGenericCall('calendar', calls[index]);
          },
          mail: async (): Promise<DailyBriefLoadResult> => result('mail'),
          waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
        };
        const snapshot = await generateDailyBrief(options(loaders));
        const normalized = normalizeDailyBriefGenericCall('calendar', calls[index]);
        expect(calendarCalls).assertEqual(1);
        expect(normalized.retryable).assertFalse();
        expect(sourceState(JSON.stringify(snapshot), 'calendar')).assertEqual(states[index]);
      }
      const bareTransport = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'failed', [], '', 'transport')
      );
      const transportFailure = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'failed', [], '', 'Transport exception: connection reset')
      );
      const invalidFailure = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'failed', [], '', 'timeout parameter invalid: HTTP 503')
      );
      const blockedFailure = normalizeDailyBriefGenericCall(
        'calendar', gatewayCall('{}', 'failed', [], '', 'blocked by provider: HTTP 503')
      );
      expect(bareTransport.retryable).assertFalse();
      expect(transportFailure.retryable).assertTrue();
      expect(transportFailure.state).assertEqual('error');
      expect(invalidFailure.retryable).assertFalse();
      expect(blockedFailure.retryable).assertFalse();
    });

    it('does not retry invalid input empty auth or ordinary provider errors', 0, async () => {
      const states: DailyBriefSourceState[] = ['needs_auth', 'empty', 'error', 'error'];
      const messages: string[] = ['authentication required', 'no results', 'invalid input', 'blocked by provider'];
      for (let index = 0; index < states.length; index += 1) {
        let calls = 0;
        const loaders: DailyBriefLiveLoaders = {
          calendar: async (): Promise<DailyBriefLoadResult> => {
            calls += 1;
            const value = result('calendar', states[index], [], null, false);
            value.message = messages[index];
            return value;
          },
          mail: async (): Promise<DailyBriefLoadResult> => result('mail'),
          waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
        };
        await generateDailyBrief(options(loaders));
        expect(calls).assertEqual(1);
      }
    });

    it('never substitutes fixture Calendar or mail content for live source truth', 0, async () => {
      const never = new Promise<DailyBriefLoadResult>(() => {});
      const loaders: DailyBriefLiveLoaders = {
        calendar: (): Promise<DailyBriefLoadResult> => never,
        mail: async (): Promise<DailyBriefLoadResult> => result('mail', 'success', [item('mail-1', 'mail')]),
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      };

      const snapshot = await generateDailyBrief(options(loaders, 20));
      const serialized = JSON.stringify(snapshot);

      expect(snapshot.status).assertEqual('partial');
      expect(sourceState(serialized, 'calendar')).assertEqual('timeout');
      expect(sourceState(serialized, 'mail')).assertEqual('success');
      expect(sourceState(serialized, 'todo')).assertEqual('fixture');
      expect(serialized.indexOf('mail-1 visible summary')).assertLarger(-1);
      expect(serialized.indexOf('日报体验评审')).assertEqual(-1);
      expect(snapshotSection(snapshot, 'today').state).assertEqual('timeout');
      expect(snapshotSection(snapshot, 'today').items.length).assertEqual(0);

      const empty = await generateDailyBrief(options({
        calendar: async (): Promise<DailyBriefLoadResult> => result('calendar', 'empty'),
        mail: async (): Promise<DailyBriefLoadResult> => result('mail', 'error'),
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      }));
      expect(snapshotSection(empty, 'today').items.length).assertEqual(0);
      expect(snapshotSection(empty, 'mail').items.length).assertEqual(0);
      expect(JSON.stringify(empty).indexOf('晨间专注时间')).assertEqual(-1);
      expect(JSON.stringify(empty).indexOf('日报界面评审反馈')).assertEqual(-1);
    });

    it('keeps fallback discovery persistable when Waterfall exceeds the deadline', 0, async () => {
      const never = new Promise<DailyBriefLoadResult>(() => {});
      const snapshot = await generateDailyBrief(options({
        calendar: async (): Promise<DailyBriefLoadResult> => result('calendar', 'success', [item('calendar-1', 'calendar')]),
        mail: async (): Promise<DailyBriefLoadResult> => result('mail', 'success', [item('mail-1', 'mail')]),
        waterfall: (): Promise<DailyBriefLoadResult> => never
      }, 20));

      const loaded = parseDailyBriefSnapshots(serializeDailyBriefSnapshots([snapshot]));
      expect(snapshot.discovery.length).assertEqual(3);
      expect(snapshot.waterfall === null).assertFalse();
      expect(loaded.length).assertEqual(1);
    });

    it('constructs fresh normalized snapshots without mutating loader values', 0, async () => {
      const poisoned = item('calendar-1', 'calendar') as PoisonedDailyBriefItem;
      poisoned.rawPreview = 'private provider preview';
      const poisonedMail = item('mail-1', 'mail') as PoisonedDailyBriefItem;
      poisonedMail.rawPreview = 'private mail preview';
      const mailAction: A2uiAction = {
        id: 'daily.brief.mail.read',
        label: '查看邮件',
        prompt: '查看邮件',
        variant: 'secondary',
        kind: 'client',
        args: JSON.parse('{"provider":"gmail","threadId":"thread-1","messageId":"message-1",' +
          '"requestKey":"gmail:message-1","rawPreview":"private action preview"}') as Object
      };
      poisonedMail.action = mailAction;
      const inputBefore = JSON.stringify(poisoned);
      const mailBefore = JSON.stringify(poisonedMail);
      const loaders: DailyBriefLiveLoaders = {
        calendar: async (): Promise<DailyBriefLoadResult> => result('calendar', 'success', [poisoned]),
        mail: async (): Promise<DailyBriefLoadResult> => result('mail', 'success', [poisonedMail]),
        waterfall: async (): Promise<DailyBriefLoadResult> => result('waterfall', 'success', [], feed())
      };

      const first = await generateDailyBrief(options(loaders));
      const firstBefore = JSON.stringify(first);
      const second = await generateDailyBrief(options(loaders));

      expect(first === second).assertFalse();
      expect(JSON.stringify(first)).assertEqual(firstBefore);
      expect(JSON.stringify(poisoned)).assertEqual(inputBefore);
      expect(JSON.stringify(poisonedMail)).assertEqual(mailBefore);
      expect(JSON.stringify(first).indexOf('private provider preview')).assertEqual(-1);
      expect(JSON.stringify(first).indexOf('private mail preview')).assertEqual(-1);
      expect(JSON.stringify(first).indexOf('private action preview')).assertEqual(-1);
      expect(JSON.stringify(first).indexOf('calendar-1-record')).assertLarger(-1);
      expect(JSON.stringify(first).indexOf('calendar-1 visible summary')).assertLarger(-1);
      expect(JSON.stringify(first).indexOf('mail-1-record')).assertLarger(-1);
      expect(JSON.stringify(first).indexOf('mail-1 visible summary')).assertLarger(-1);
    });

    it('derives all registered Waterfall sources and visible preference query', 0, () => {
      const preference: DailyBriefPreference = defaultDailyBriefPreference();
      preference.topics = ['AI 产品', 'HarmonyOS'];

      const input = dailyBriefWaterfallInput(preference, '个人日报 Demo');

      expect(input.sources.join(',')).assertEqual(aggregateSearchSearchSourceIds().join(','));
      expect(input.query).assertEqual('AI 产品 HarmonyOS 个人日报 Demo');
      expect(input.preferenceDescription.indexOf('中文优先')).assertLarger(-1);
      expect(input.preferenceDescription.indexOf('15 分钟内')).assertLarger(-1);
    });
  });
}
