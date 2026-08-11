import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiAgentRunner,
  A2uiModel,
  A2uiTextDeltaListener,
  ConversationContext
} from '@loop/agent-core';

class DeltaModel implements A2uiModel {
  async generate(
    _userTask: string,
    _surfaceId: string,
    _conversation?: ConversationContext,
    onTextDelta?: A2uiTextDeltaListener
  ): Promise<string> {
    if (onTextDelta !== undefined) {
      onTextDelta('{"first":');
      onTextDelta('true}');
    }
    return '{"first":true}';
  }
}

export default function a2uiAgentRunnerTest() {
  describe('a2uiAgentRunner', () => {
    it('forwards decoded text deltas while preserving the final candidate', 0, async () => {
      const runner = new A2uiAgentRunner(new DeltaModel());
      const deltas: string[] = [];
      const candidate = await runner.plan('render', 'surface-delta', (delta: string): void => {
        deltas.push(delta);
      });

      expect(deltas.join('')).assertEqual('{"first":true}');
      expect(candidate).assertEqual('{"first":true}');
    });
  });
}
