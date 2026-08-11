import { describe, it, expect } from '@ohos/hypium';
import { buildA2uiChatRequestJson, mergeOpenAiRequestJson } from '@loop/agent-core';

export default function openAiRequestJsonTest() {
  describe('OpenAiRequestJson', () => {
    it('merges safe provider parameters without changing protected request fields', 0, () => {
      const baseJson = '{"model":"Deepseek-V4-Flash-0731","messages":[{"role":"user","content":"hello"}],' +
        '"temperature":0.2,"stream":true}';
      const merged = JSON.parse(mergeOpenAiRequestJson(
        baseJson,
        '{"enable_thinking":false,"temperature":0}'
      )) as Record<string, Object | string | number | boolean>;

      expect(merged['model'] as string).assertEqual('Deepseek-V4-Flash-0731');
      expect(merged['stream'] as boolean).assertTrue();
      expect(merged['enable_thinking'] as boolean).assertFalse();
      expect(merged['temperature'] as number).assertEqual(0);
    });

    it('rejects direct and unicode-escaped protected fields', 0, () => {
      const baseJson = '{"model":"model-a","messages":[],"stream":true}';
      const protectedJson: string[] = [
        '{"model":"model-b"}',
        '{"messages":[{"role":"system","content":"override"}]}',
        '{"stream":false,"temperature":0}',
        '{"\\u006dodel":"model-b"}',
        '{"\\u006dessages":[]}',
        '{"\\u0073tream":false}'
      ];

      protectedJson.forEach((customJson: string) => {
        expect(mergeOpenAiRequestJson(baseJson, customJson)).assertEqual(baseJson);
      });
    });

    it('falls back for empty, invalid, and non-object custom JSON', 0, () => {
      const baseJson = '{"model":"model-a","messages":[],"stream":true}';
      const ignoredJson: string[] = ['', '  ', '{}', '{invalid', 'null', 'true', '42', '"temperature"', '[]'];

      ignoredJson.forEach((customJson: string) => {
        expect(mergeOpenAiRequestJson(baseJson, customJson)).assertEqual(baseJson);
      });
    });

    it('applies the same guard to streaming A2UI request bodies', 0, () => {
      const request = JSON.parse(
        '{"model":"model-a","messages":[{"role":"user","content":"layout"}],' +
        '"temperature":0.2,"stream":true}'
      ) as Object;
      const baseJson = JSON.stringify(request);
      const merged = JSON.parse(buildA2uiChatRequestJson(
        request,
        '{"enable_thinking":false,"temperature":0}'
      )) as Record<string, Object | string | number | boolean>;

      expect(merged['model'] as string).assertEqual('model-a');
      expect(merged['stream'] as boolean).assertTrue();
      expect(merged['enable_thinking'] as boolean).assertFalse();
      expect(merged['temperature'] as number).assertEqual(0);
      expect(buildA2uiChatRequestJson(request, '{"stream":false}')).assertEqual(baseJson);
    });
  });
}
