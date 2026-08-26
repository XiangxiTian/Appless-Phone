import { A2uiAction, actionsOf, labelValues } from '@loop/agent-core';
import { describe, expect, it } from '@ohos/hypium';
import {
  MemoryCandidatesForgetActionArgs,
  memoryCandidatesForgetActionArgs,
  memoryCandidateSelectionSurface,
  memoryForgetConfirmationSurface
} from '../main/ets/model/MemoryCandidateSelectionSurface';

interface ForgedMemoryCandidatesForgetActionArgs {
  selectionId: string;
  revision: number;
  candidateKeys: string[];
  memoryId: string;
}

export default function memoryCandidateSelectionTest() {
  describe('memoryCandidateSelection', () => {
    it('renders bounded facts with only one opaque final delete template', 0, () => {
      const surface = memoryCandidateSelectionSurface('memory-selection:test', {
        selectionId: 'selection-test',
        revision: 1,
        candidates: [{
          candidateKey: 'candidate-a', fact: '用户喝咖啡时选择半糖。',
          personaTag: 'food_companion', authority: 'leader'
        }, {
          candidateKey: 'candidate-b', fact: '用户喝咖啡时优先选择燕麦奶。',
          personaTag: 'food_companion', authority: 'leader'
        }]
      });
      const card = surface.components[1];
      const rows = labelValues(surface, card);
      const actions = actionsOf(card);
      const serializedArgs = JSON.stringify(actions[0].args);

      expect(surface.intent).assertEqual('memory.forget.selection');
      expect(rows.length).assertEqual(2);
      expect(actions.length).assertEqual(1);
      expect(actions[0].id).assertEqual('memory_candidates_forget');
      expect(memoryCandidatesForgetActionArgs(actions[0]) === null).assertTrue();
      expect(serializedArgs.indexOf('selection-test')).assertLarger(-1);
      expect(serializedArgs.indexOf('candidate-a')).assertEqual(-1);
      expect(serializedArgs.indexOf('memoryId')).assertEqual(-1);
      expect(serializedArgs.indexOf('用户喝咖啡')).assertEqual(-1);
      expect(surface.dataModelJson.indexOf('candidate-a')).assertLarger(-1);
      expect(surface.dataModelJson.indexOf('memoryId')).assertEqual(-1);
    });

    it('accepts only opaque unique non-empty final delete payloads', 0, () => {
      const deleteArgs: MemoryCandidatesForgetActionArgs = {
        selectionId: 'selection-test', revision: 2, candidateKeys: ['candidate-a', 'candidate-b']
      };
      const forgedArgs: ForgedMemoryCandidatesForgetActionArgs = {
        selectionId: 'selection-test', revision: 2, candidateKeys: ['candidate-a'], memoryId: 'forged'
      };
      const deleteAction: A2uiAction = {
        id: 'memory_candidates_forget', label: '删除已选（2）', prompt: '', variant: 'primary',
        kind: 'client', args: deleteArgs
      };
      const forged: A2uiAction = {
        id: deleteAction.id, label: deleteAction.label, prompt: deleteAction.prompt,
        variant: deleteAction.variant, kind: deleteAction.kind, args: forgedArgs
      };

      expect(memoryCandidatesForgetActionArgs(deleteAction)?.revision).assertEqual(2);
      expect(memoryCandidatesForgetActionArgs(deleteAction)?.candidateKeys.length).assertEqual(2);
      expect(memoryCandidatesForgetActionArgs(forged) === null).assertTrue();
      const empty: A2uiAction = {
        id: deleteAction.id, label: deleteAction.label, prompt: deleteAction.prompt,
        variant: deleteAction.variant, kind: deleteAction.kind,
        args: { selectionId: 'selection-test', revision: 2, candidateKeys: [] } as MemoryCandidatesForgetActionArgs
      };
      const duplicate: A2uiAction = {
        id: deleteAction.id, label: deleteAction.label, prompt: deleteAction.prompt,
        variant: deleteAction.variant, kind: deleteAction.kind,
        args: {
          selectionId: 'selection-test', revision: 2, candidateKeys: ['candidate-a', 'candidate-a']
        } as MemoryCandidatesForgetActionArgs
      };
      expect(memoryCandidatesForgetActionArgs(empty) === null).assertTrue();
      expect(memoryCandidatesForgetActionArgs(duplicate) === null).assertTrue();
    });

    it('creates a non-actionable confirmation surface', 0, () => {
      const surface = memoryForgetConfirmationSurface(
        'memory-forget-confirmation:test', 2
      );
      expect(surface.intent).assertEqual('memory.forget.confirmation');
      expect(actionsOf(surface.components[1]).length).assertEqual(0);
      expect(labelValues(surface, surface.components[1])[0].value).assertEqual('已删除 2 条长期记忆。');
    });
  });
}
