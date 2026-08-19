import { describe, it, expect } from '@ohos/hypium';
import {
  directModelRequestDebug,
  directModelSystemPrompt
} from '../main/ets/model/LocalModelClient';
import {
  cloudModelSettingsForPreset,
  configureLocalModelSettingsFromRawJson,
  dashScopeModelSettings,
  defaultLocalModelSettings
} from '@loop/agent-core';

export default function localModelClientTest() {
  describe('localModelClient', () => {
    it('uses a tool-free direct model prompt for non-orchestration utilities', 0, () => {
      const baseline = directModelSystemPrompt();
      expect(baseline.length > 0).assertTrue();
      expect(baseline.indexOf('Do not call tools.')).assertLarger(-1);
      expect(baseline.indexOf('ReAct')).assertEqual(-1);
      expect(baseline.indexOf('A2UI')).assertEqual(-1);
    });

    it('reports a direct model request without a tool-loop endpoint', 0, () => {
      const settings = defaultLocalModelSettings();
      const debug = directModelRequestDebug(settings, 'reply', 3);
      expect(debug.indexOf('OpenAiCompatibleModel.direct')).assertLarger(-1);
      expect(debug.indexOf('LoopBackend')).assertEqual(-1);
      expect(debug.indexOf('"historyTurns":3')).assertLarger(-1);
    });

    it('defaults to CSI DeepSeek V4 Flash and preserves the DashScope DeepSeek fallback preset', 0, () => {
      configureLocalModelSettingsFromRawJson('{"DASHSCOPE_API_KEY":"old-key","DEEPSEEK_API_KEY":"new-key",' +
        '"DEEPSEEK_BASE_URL":"https://model.example.test/v1/chat/completions"}');
      const settings = defaultLocalModelSettings();
      expect(settings.provider).assertEqual('CSI.AI');
      expect(settings.baseUrl).assertEqual('https://model.example.test/v1/chat/completions');
      expect(settings.model).assertEqual('Deepseek-V4-Flash-0731');
      expect(settings.apiKey).assertEqual('new-key');
      expect(settings.customParametersJson).assertEqual('{"enable_thinking":false}');
      expect(settings.ignoreToolSurfaceUpdates).assertFalse();
      const dashScope = dashScopeModelSettings();
      expect(dashScope.provider).assertEqual('DashScope');
      expect(dashScope.baseUrl).assertEqual('https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions');
      expect(dashScope.model).assertEqual('deepseek-v4-flash-0731');
      expect(dashScope.apiKey).assertEqual('old-key');
      expect(cloudModelSettingsForPreset('qwen')?.model).assertEqual('deepseek-v4-flash-0731');
      expect(cloudModelSettingsForPreset('unknown')).assertNull();
      configureLocalModelSettingsFromRawJson('{"DEEPSEEK_API_KEY":"new-key",' +
        '"DEEPSEEK_BASE_URL":"javascript:alert(1)"}');
      expect(defaultLocalModelSettings().baseUrl).assertEqual('https://api.jiuwenappless.com/v1/chat/completions');
      configureLocalModelSettingsFromRawJson('{}');
    });
  });
}
