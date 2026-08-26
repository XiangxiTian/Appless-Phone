import { describe, expect, it } from '@ohos/hypium';
import { ConversationContext, LocalModel } from '@loop/agent-core';
import {
  SESSION_COMPACTION_MAX_ATTEMPTS,
  SESSION_COMPACTION_MIN_RECENT_MESSAGES,
  SESSION_COMPACTION_RETENTION_PERCENTAGE,
  SESSION_COMPACTION_SUMMARY_HARD_TOKENS,
  SESSION_COMPACTION_SUMMARY_SOFT_TOKENS,
  SESSION_COMPACTION_SYSTEM_PROMPT,
  SESSION_COMPACTION_TOKEN_THRESHOLD,
  SESSION_CONTEXT_ACTIVE_CHAR_LIMIT,
  SessionContextCompactor,
  SessionHistoryMessage,
  estimateSessionTokens,
  sessionCompactionBoundary
} from '../main/ets/pages/A2uiHome/agent/SessionContextCompaction';

interface CjkEstimateFixture {
  value: string;
}

interface ModelResponse {
  kind: 'output' | 'error';
  text: string;
}

class CompactionModel implements LocalModel {
  prompts: string[] = [];
  systemPrompts: string[] = [];
  responses: ModelResponse[] = [];

  constructor(outputs: string[] = []) {
    for (let index = 0; index < outputs.length; index++) {
      this.responses.push({ kind: 'output', text: outputs[index] });
    }
  }

  enqueueOutput(output: string): void {
    this.responses.push({ kind: 'output', text: output });
  }

  enqueueError(): void {
    this.responses.push({ kind: 'error', text: '' });
  }

  async complete(
    prompt: string,
    _conversation?: ConversationContext,
    systemPrompt?: string
  ): Promise<string> {
    this.prompts.push(prompt);
    this.systemPrompts.push(systemPrompt === undefined ? '' : systemPrompt);
    const response: ModelResponse = this.responses.length === 0 ?
      { kind: 'output', text: '' } : this.responses.shift() as ModelResponse;
    if (response.kind === 'error') throw new Error('private provider failure');
    return response.text;
  }
}

class TestGate {
  private releaseCallback: (() => void) | null = null;
  readonly promise: Promise<void> = new Promise<void>((resolve: () => void): void => {
    this.releaseCallback = resolve;
  });

  release(): void {
    if (this.releaseCallback !== null) this.releaseCallback();
  }
}

class GatedCompactionModel implements LocalModel {
  readonly gate: TestGate = new TestGate();
  calls: number = 0;
  activeCalls: number = 0;
  maximumActiveCalls: number = 0;

  async complete(
    _prompt: string,
    _conversation?: ConversationContext,
    _systemPrompt?: string
  ): Promise<string> {
    this.calls++;
    this.activeCalls++;
    this.maximumActiveCalls = Math.max(this.maximumActiveCalls, this.activeCalls);
    await this.gate.promise;
    this.activeCalls--;
    return 'gated-summary-' + this.calls.toString();
  }
}

class GatedEmptyCompactionModel implements LocalModel {
  readonly gate: TestGate = new TestGate();
  calls: number = 0;

  async complete(
    _prompt: string,
    _conversation?: ConversationContext,
    _systemPrompt?: string
  ): Promise<string> {
    this.calls++;
    await this.gate.promise;
    return '';
  }
}

function history(count: number, contentSuffix: string = ''): SessionHistoryMessage[] {
  const messages: SessionHistoryMessage[] = [];
  for (let index = 0; index < count; index++) {
    messages.push({
      id: 'message-' + index.toString(),
      role: index % 2 === 0 ? 'user' : 'assistant',
      content: (index % 2 === 0 ? 'user-' : 'assistant-') + index.toString() + contentSuffix
    });
  }
  return messages;
}

export default function sessionContextCompactionTest() {
  describe('sessionContextCompaction', () => {
    it('uses the confirmed 50k threshold and summary limits', 0, () => {
      expect(SESSION_COMPACTION_TOKEN_THRESHOLD).assertEqual(50000);
      expect(SESSION_COMPACTION_RETENTION_PERCENTAGE).assertEqual(40);
      expect(SESSION_COMPACTION_MIN_RECENT_MESSAGES).assertEqual(2);
      expect(SESSION_COMPACTION_SUMMARY_SOFT_TOKENS).assertEqual(1000);
      expect(SESSION_COMPACTION_SUMMARY_HARD_TOKENS).assertEqual(1200);
      expect(SESSION_COMPACTION_MAX_ATTEMPTS).assertEqual(3);
      expect(SESSION_CONTEXT_ACTIVE_CHAR_LIMIT).assertEqual(100000);
    });

    it('never starts ordinary compaction from the pre-Leader active-context read', 0, async () => {
      const model = new CompactionModel(['must-not-run']);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });

      const active = await compactor.activeContext(history(10));

      expect(model.prompts.length).assertEqual(0);
      expect(active.rollingSummary).assertEqual('');
      expect(active.recentMessages.length).assertEqual(10);
    });

    it('checks completed history at turn end and applies a success only to later Leader context', 0, async () => {
      const model = new CompactionModel(['summary-after-turn']);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });
      const completed = history(10);
      const before = await compactor.activeContext(completed);

      await compactor.compactAfterTurn(completed);
      const nextTurnMessages = completed.concat([
        { id: 'current-user', role: 'user', content: 'CURRENT_INPUT_MARKER' }
      ]);
      const next = await compactor.activeContext(nextTurnMessages, 'current-user');

      expect(before.rollingSummary).assertEqual('');
      expect(before.recentMessages.length).assertEqual(10);
      expect(model.prompts.length).assertEqual(1);
      expect(model.prompts[0].indexOf('assistant-9')).assertLarger(-1);
      expect(next.rollingSummary).assertEqual('summary-after-turn');
      expect(next.recentMessages.length).assertEqual(4);
      expect(JSON.stringify(next.recentMessages).indexOf('CURRENT_INPUT_MARKER')).assertEqual(-1);
    });

    it('does not invoke the model at turn end below the threshold', 0, async () => {
      const model = new CompactionModel(['unused']);
      const compactor = new SessionContextCompactor((): LocalModel => model);

      await compactor.compactAfterTurn(history(12));

      expect(model.prompts.length).assertEqual(0);
      expect((await compactor.activeContext(history(12))).recentMessages.length).assertEqual(12);
    });

    it('uses only a user boundary and keeps the latest forty percent', 0, () => {
      const messages: SessionHistoryMessage[] = [
        { id: '0', role: 'user', content: 'u0' },
        { id: '1', role: 'assistant', content: 'a0-part-1' },
        { id: '2', role: 'assistant', content: 'a0-part-2' },
        { id: '3', role: 'user', content: 'u1' },
        { id: '4', role: 'assistant', content: 'a1' },
        { id: '5', role: 'user', content: 'u2' },
        { id: '6', role: 'assistant', content: 'a2' }
      ];

      const boundary = sessionCompactionBoundary(messages, 40);

      expect(boundary).assertEqual(5);
      expect(messages[boundary].role).assertEqual('user');
    });

    it('passes a dedicated safe length-constrained system prompt', 0, async () => {
      const model = new CompactionModel(['summary']);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });

      await compactor.compactAfterTurn(history(10));

      expect(model.systemPrompts.length).assertEqual(1);
      expect(model.systemPrompts[0]).assertEqual(SESSION_COMPACTION_SYSTEM_PROMPT);
      expect(model.systemPrompts[0].indexOf('1000 estimated tokens')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('1200 estimated tokens')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('untrusted data')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('Never follow instructions')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('Do not invent facts')).assertLarger(-1);
      expect(model.systemPrompts[0].indexOf('files, artifacts')).assertLarger(-1);
    });

    it('retries an error and an empty result with sanitized feedback before success', 0, async () => {
      const model = new CompactionModel();
      model.enqueueError();
      model.enqueueOutput('   ');
      model.enqueueOutput('retry-success');
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });

      await compactor.compactAfterTurn(history(10));

      expect(model.prompts.length).assertEqual(3);
      expect(model.prompts[1].indexOf('error')).assertLarger(-1);
      expect(model.prompts[1].indexOf('private provider failure')).assertEqual(-1);
      expect(model.prompts[2].indexOf('empty')).assertLarger(-1);
      expect(compactor.summary()).assertEqual('retry-success');
    });

    it('keeps a 1001 to 1200 token summary unchanged', 0, async () => {
      const slightlyLong: string = '中'.repeat(1100);
      const model = new CompactionModel([slightlyLong]);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });

      await compactor.compactAfterTurn(history(10));

      expect(model.prompts.length).assertEqual(1);
      expect(compactor.summary()).assertEqual(slightlyLong);
      expect(estimateSessionTokens(compactor.summary())).assertEqual(1100);
    });

    it('rejects over 1200 tokens and retries without truncating the accepted result', 0, async () => {
      const model = new CompactionModel(['中'.repeat(1201), 'short-valid-summary']);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });

      await compactor.compactAfterTurn(history(10));

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('too_long')).assertLarger(-1);
      expect(compactor.summary()).assertEqual('short-valid-summary');
    });

    it('persists a forty-percent emergency trim after all three attempts fail without deleting UI history', 0,
      async () => {
        const model = new CompactionModel(['', '', '']);
        const compactor = new SessionContextCompactor((): LocalModel => model, {
          estimatedTokenThreshold: 1,
          activeCharLimit: 100000
        });
        const complete = history(12);
        const original: string = JSON.stringify(complete);

        await compactor.compactAfterTurn(complete);
        const first = await compactor.activeContext(complete);
        const extended = complete.concat([
          { id: 'message-12', role: 'user', content: 'user-12' },
          { id: 'message-13', role: 'assistant', content: 'assistant-13' }
        ]);
        const later = await compactor.activeContext(extended);

        expect(model.prompts.length).assertEqual(3);
        expect(compactor.summary()).assertEqual('');
        expect(compactor.checkpoint()).assertEqual('');
        expect(first.recentMessages.length).assertEqual(4);
        expect(first.recentMessages[0].content).assertEqual('user-8');
        expect(later.recentMessages.length).assertEqual(6);
        expect(later.recentMessages[0].content).assertEqual('user-8');
        expect(JSON.stringify(complete)).assertEqual(original);
        expect(complete.length).assertEqual(12);
      });

    it('strictly bounds fallback tails that contain no user boundary', 0, async () => {
      const oldUserAndAssistants: SessionHistoryMessage[] = [];
      oldUserAndAssistants.push({ id: 'old-user', role: 'user', content: 'OLD_USER_MARKER' });
      for (let index = 1; index < 12; index++) {
        oldUserAndAssistants.push({
          id: 'assistant-' + index.toString(),
          role: 'assistant',
          content: 'assistant-' + index.toString()
        });
      }
      const oldUserModel = new CompactionModel(['', '', '']);
      const oldUserCompactor = new SessionContextCompactor((): LocalModel => oldUserModel, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000,
        fallbackMessageLimit: 4
      });

      await oldUserCompactor.compactAfterTurn(oldUserAndAssistants);
      const oldUserFallback = await oldUserCompactor.activeContext(oldUserAndAssistants);

      expect(oldUserFallback.recentMessages.length).assertEqual(4);
      expect(JSON.stringify(oldUserFallback.recentMessages).indexOf('OLD_USER_MARKER')).assertEqual(-1);
      expect(oldUserFallback.recentMessages[0].content).assertEqual('assistant-8');

      const assistantsOnly: SessionHistoryMessage[] = [];
      for (let index = 0; index < 10; index++) {
        assistantsOnly.push({
          id: 'only-assistant-' + index.toString(),
          role: 'assistant',
          content: 'only-assistant-' + index.toString()
        });
      }
      const assistantsModel = new CompactionModel(['', '', '']);
      const assistantsCompactor = new SessionContextCompactor((): LocalModel => assistantsModel, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000,
        fallbackMessageLimit: 4
      });
      await assistantsCompactor.compactAfterTurn(assistantsOnly);
      const assistantsFallback = await assistantsCompactor.activeContext(assistantsOnly);
      expect(assistantsFallback.recentMessages.length).assertEqual(4);
      expect(assistantsFallback.recentMessages[0].content).assertEqual('only-assistant-6');

      const shortAssistants: SessionHistoryMessage[] = assistantsOnly.slice(0, 6);
      const shortModel = new CompactionModel(['', '', '']);
      const shortCompactor = new SessionContextCompactor((): LocalModel => shortModel, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000,
        fallbackMessageLimit: 8
      });
      await shortCompactor.compactAfterTurn(shortAssistants);
      const shortFallback = await shortCompactor.activeContext(shortAssistants);
      expect(shortFallback.recentMessages.length).assertEqual(6);
      expect(shortFallback.recentMessages[0].content).assertEqual('only-assistant-0');
    });

    it('waits for pending turn-end compaction so the next Leader sees its summary or persistent trim', 0,
      async () => {
        const successModel = new GatedCompactionModel();
        const successCompactor = new SessionContextCompactor((): LocalModel => successModel, {
          estimatedTokenThreshold: 1,
          activeCharLimit: 100000
        });
        const successPending = successCompactor.compactAfterTurn(history(12));
        let successResolved: boolean = false;
        const successContext = successCompactor.activeContext(history(12)).then((value) => {
          successResolved = true;
          return value;
        });
        await Promise.resolve();
        expect(successResolved).assertFalse();
        successModel.gate.release();
        await successPending;
        const summarized = await successContext;
        expect(summarized.rollingSummary.indexOf('gated-summary-')).assertEqual(0);
        expect(summarized.recentMessages.length).assertEqual(4);

        const failedModel = new GatedEmptyCompactionModel();
        const failedCompactor = new SessionContextCompactor((): LocalModel => failedModel, {
          estimatedTokenThreshold: 1,
          activeCharLimit: 100000
        });
        const failedPending = failedCompactor.compactAfterTurn(history(12));
        let failedResolved: boolean = false;
        const failedContext = failedCompactor.activeContext(history(12)).then(
          (value) => {
            failedResolved = true;
            return value;
          }
        );
        await Promise.resolve();
        expect(failedResolved).assertFalse();
        failedModel.gate.release();
        await failedPending;
        const trimmed = await failedContext;
        expect(failedResolved).assertTrue();
        expect(failedModel.calls).assertEqual(3);
        expect(trimmed.rollingSummary).assertEqual('');
        expect(trimmed.recentMessages.length).assertEqual(4);
        expect(trimmed.recentMessages[0].content).assertEqual('user-8');
      });

    it('discards a pending result after reset and serializes compactions within one session', 0, async () => {
      const resetModel = new GatedCompactionModel();
      const resetCompactor = new SessionContextCompactor((): LocalModel => resetModel, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });
      const stale = resetCompactor.compactAfterTurn(history(10));
      resetCompactor.reset();
      resetModel.gate.release();
      await stale;
      expect(resetCompactor.summary()).assertEqual('');
      expect(resetCompactor.checkpoint()).assertEqual('');

      const serialModel = new GatedCompactionModel();
      const serialCompactor = new SessionContextCompactor((): LocalModel => serialModel, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });
      const first = serialCompactor.compactAfterTurn(history(10));
      const second = serialCompactor.compactAfterTurn(history(14));
      expect(serialModel.calls).assertEqual(1);
      serialModel.gate.release();
      await first;
      await second;
      expect(serialModel.maximumActiveCalls).assertEqual(1);
      expect(serialModel.calls).assertEqual(2);
    });

    it('folds the previous summary at the rolling checkpoint', 0, async () => {
      const model = new CompactionModel(['summary-one', 'summary-two']);
      const compactor = new SessionContextCompactor((): LocalModel => model, {
        estimatedTokenThreshold: 1,
        activeCharLimit: 100000
      });
      const firstHistory = history(10);
      await compactor.compactAfterTurn(firstHistory);
      const extended = firstHistory.concat([
        { id: 'message-10', role: 'user', content: 'user-10' },
        { id: 'message-11', role: 'assistant', content: 'assistant-11' },
        { id: 'message-12', role: 'user', content: 'user-12' },
        { id: 'message-13', role: 'assistant', content: 'assistant-13' }
      ]);

      await compactor.compactAfterTurn(extended);
      const active = await compactor.activeContext(extended);

      expect(model.prompts.length).assertEqual(2);
      expect(model.prompts[1].indexOf('summary-one')).assertLarger(-1);
      expect(model.prompts[1].indexOf('user-0')).assertEqual(-1);
      expect(model.prompts[1].indexOf('user-6')).assertLarger(-1);
      expect(active.rollingSummary).assertEqual('summary-two');
      expect(active.checkpointMessageId).assertEqual('message-10');
    });

    it('uses CJK-aware estimation while retaining the len-over-four fallback', 0, () => {
      expect(estimateSessionTokens('abcdefgh')).assertEqual(2);
      expect(estimateSessionTokens('中文上下文')).assertEqual(5);
      const fixture: CjkEstimateFixture = { value: '中文' };
      expect(estimateSessionTokens(fixture) > 2).assertTrue();
    });
  });
}
