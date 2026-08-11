import { describe, expect, it } from '@ohos/hypium';
import {
  uiAgentLabThemeForToggle,
  uiAgentLabThemeScript
} from '../main/ets/pages/A2uiHome/lab/UiAgentLabTheme';

export default function uiAgentLabThemeTest() {
  describe('uiAgentLabTheme', () => {
    it('maps the off state to warm and the on state to cool', 0, () => {
      expect(uiAgentLabThemeForToggle(false)).assertEqual('warm');
      expect(uiAgentLabThemeForToggle(true)).assertEqual('cool');
    });

    it('encodes theme and lifecycle generation for the ArkWeb apply entry', 0, () => {
      const script = uiAgentLabThemeScript('cool', 7);
      expect(script).assertContain('window.__applyUiAgentLabTheme(JSON.parse(');
      expect(script).assertContain('\\u0022\\u0074\\u0068\\u0065\\u006d\\u0065\\u0022');
      expect(script).assertContain('\\u0022\\u0063\\u006f\\u006f\\u006c\\u0022');
      expect(script).assertContain('\\u0022\\u0067\\u0065\\u006e\\u0065\\u0072\\u0061\\u0074\\u0069\\u006f\\u006e\\u0022');
      expect(script).assertContain('\\u0037');
    });
  });
}
