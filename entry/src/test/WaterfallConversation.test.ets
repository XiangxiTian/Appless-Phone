import { describe, expect, it } from '@ohos/hypium';
import { Want } from '@kit.AbilityKit';
import { waterfallConversationTypedTestPromptFromWant } from '../main/ets/entryability/EntryAbility';
import {
  applyWaterfallConversationCommand,
  directWaterfallConversationCommand,
  parseWaterfallConversationCommand,
  WaterfallConversationCommand,
  WaterfallConversationState
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallConversation';

export default function waterfallConversationTest() {
  describe('waterfallConversation', () => {
    it('accepts only the strict bounded command schema', 0, () => {
      const command = parseWaterfallConversationCommand(
        '{"operation":"apply","summary":"多看 AI，少看视频","rules":[' +
          '{"dimension":"topic","key":"AI","effect":"boost"},' +
          '{"dimension":"format","key":"landscape_video","effect":"downweight"}]}'
      );
      expect(command === null).assertFalse();
      expect(command?.rules.length).assertEqual(2);
      expect(parseWaterfallConversationCommand(
        '好的，{"operation":"reset","summary":"恢复默认","rules":[]}') === null).assertTrue();
      expect(parseWaterfallConversationCommand(
        '{"operation":"apply","summary":"未知来源","rules":[' +
          '{"dimension":"source","key":"unknown","effect":"boost"}]}') === null).assertTrue();
      expect(parseWaterfallConversationCommand(
        '{"operation":"apply","summary":"空规则","rules":[]}') === null).assertTrue();
    });

    it('handles simple refinements, undo, and reset locally without a model call', 0, () => {
      expect(directWaterfallConversationCommand('撤销刚才调整')?.operation).assertEqual('undo');
      expect(directWaterfallConversationCommand('恢复默认')?.operation).assertEqual('reset');
      const local = directWaterfallConversationCommand('多看科技');
      expect(local?.operation).assertEqual('apply');
      expect(local?.rules[0].key).assertEqual('科技');
      expect(local?.rules[0].effect).assertEqual('boost');
      const mixed = directWaterfallConversationCommand('接下来多看人工智能和鸿蒙开发，少看体育');
      expect(mixed?.rules.length).assertEqual(2);
      expect(mixed?.rules[0].effect).assertEqual('boost');
      expect(mixed?.rules[1].effect).assertEqual('downweight');
      expect(directWaterfallConversationCommand('多看科技但少看体育') === null).assertTrue();
      expect(directWaterfallConversationCommand('多看科技，帮我平衡新鲜度') === null).assertTrue();
    });

    it('accepts only a bounded typed device probe', 0, () => {
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: '  多看科技  ' }
      } as Want)).assertEqual('多看科技');
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: 42 }
      } as Want)).assertEqual('');
      expect(waterfallConversationTypedTestPromptFromWant({
        parameters: { waterfallConversationPrompt: 'x'.repeat(241) }
      } as Want)).assertEqual('');
    });

    it('merges refinements and deterministically replays undo and reset', 0, () => {
      const empty: WaterfallConversationState = { history: [], rules: [], summary: '' };
      const firstCommand: WaterfallConversationCommand = {
        operation: 'apply', summary: '多看 AI',
        rules: [{ dimension: 'topic', key: 'AI', effect: 'boost' }]
      };
      const first = applyWaterfallConversationCommand(empty, firstCommand);
      const secondCommand: WaterfallConversationCommand = {
        operation: 'apply', summary: '只看 Reddit',
        rules: [{ dimension: 'source', key: 'reddit', effect: 'boost' },
          { dimension: 'source', key: 'youtube', effect: 'block' }]
      };
      const second = applyWaterfallConversationCommand(first, secondCommand);
      expect(second.rules.length).assertEqual(3);
      const undoCommand: WaterfallConversationCommand = {
        operation: 'undo', summary: '已撤销', rules: []
      };
      const undone = applyWaterfallConversationCommand(second, undoCommand);
      expect(undone.rules.length).assertEqual(1);
      expect(undone.rules[0].key).assertEqual('AI');
      const resetCommand: WaterfallConversationCommand = {
        operation: 'reset', summary: '恢复默认', rules: []
      };
      const reset = applyWaterfallConversationCommand(undone, resetCommand);
      expect(reset.rules.length).assertEqual(0);
      expect(reset.history.length).assertEqual(0);
    });
  });
}
