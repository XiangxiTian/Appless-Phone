import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const source = readFileSync(
  new URL('entry/src/main/ets/pages/A2uiHome/components/ConfigPage.ets', root),
  'utf8'
);

test('uses the base-conversation cold white glass backdrop on the config page', () => {
  assert.match(source, /ConfigBackdrop\(\)/);
  assert.match(source, /colors: \[\['#F8FAFD', 0\], \['#E9EEF5', 0\.52\], \['#F4F0F7', 1\]\]/);
  assert.match(source, /\.width\('92%'\)[\s\S]*?\.height\('88%'\)[\s\S]*?\.backgroundColor\('#52FFFFFF'\)/);
  assert.doesNotMatch(source, /app\.media\.home_light_aurora_background/);
});

test('keeps config styling local and adopts glass controls with a slate accent', () => {
  assert.match(source, /Keep the configuration palette local/);
  assert.match(source, /const COLOR_ACCENT_DEEP: string = '#5F6978'/);
  assert.match(source, /const CONFIG_GUIDE_CARD_BACKGROUND: string = '#A6FFFFFF'/);
  assert.match(source, /\.backgroundColor\(CONFIG_HEADER_BUTTON_BACKGROUND\)/);
  assert.match(source, /Button\(this\.isBusy \? '检查中' : '测试连接'\)[\s\S]*?\.borderRadius\(22\)/);
});

test('keeps interactive config content inside the system safe area', () => {
  assert.match(
    source,
    /ConfigBackdrop\(\)[\s\S]*?\.expandSafeArea\(\[SafeAreaType\.SYSTEM\], \[SafeAreaEdge\.TOP, SafeAreaEdge\.BOTTOM\]\)/
  );
  assert.doesNotMatch(
    source,
    /\.backgroundColor\('#F4F6FA'\)\s*\.expandSafeArea\(\[SafeAreaType\.SYSTEM\]/
  );
});
