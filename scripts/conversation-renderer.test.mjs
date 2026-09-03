import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';

const rendererSource = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/html/HtmlHomeRenderer.ets', import.meta.url),
  'utf8'
);
const surfaceSource = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/components/HtmlHomeSurfaceView.ets', import.meta.url),
  'utf8'
);
const indexSource = fs.readFileSync(
  new URL('../entry/src/main/ets/pages/A2uiHome/Index.ets', import.meta.url),
  'utf8'
);

function sourceBody(source, signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} must exist`);
  const bodyStart = start + signature.length;
  let depth = 1;
  for (let index = bodyStart; index < source.length; index += 1) {
    if (source[index] === '{') depth += 1;
    if (source[index] === '}') depth -= 1;
    if (depth === 0) return source.slice(bodyStart, index);
  }
  throw new Error(`${signature} body is incomplete`);
}

test('restored assistant replies render immediately instead of replaying reveal', () => {
  const addPlainChat = sourceBody(rendererSource, 'function addPlainChat(parent, history) {');

  assert.match(
    addPlainChat,
    /add\(response, 'p', 'plain-chat-response-copy', text\(assistant\.content\)\);/
  );
  assert.doesNotMatch(addPlainChat, /queueConversationAssistantReveal/);
});

test('conversation stream restoration skips the already-delivered prefix', () => {
  assert.match(surfaceSource, /conversationStreamInitialSyncPending: boolean = true;/);
  assert.match(surfaceSource, /const reveal = !this\.conversationStreamInitialSyncPending;/);
  assert.match(
    surfaceSource,
    /__aiphoneSetConversationAssistantTarget\('\s*\+ JSON\.stringify\(targetText\)\s*\+ ','/
  );
  assert.match(surfaceSource, /conversationStreamInitialSyncPending = false;/);
});

test('secondary pages overlay the persistent home WebView', () => {
  const buildBody = sourceBody(indexSource, 'build() {');

  assert.match(buildBody, /Stack\(\) \{\s*Swiper[\s\S]*HomePage\(/);
  assert.match(buildBody, /this\.showConfigPage/);
  assert.match(buildBody, /this\.ConfigPageContent\(\)/);
});
