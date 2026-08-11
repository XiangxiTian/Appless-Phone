import { describe, it, expect } from '@ohos/hypium';
import {
  A2uiStreamComponentBatch,
  A2uiStreamComponentScanResult,
  A2uiUpdateComponentsStreamScanner
} from '@loop/agent-core';

type TestJsonValue = Object | string | number | boolean | null | undefined;
type TestJsonRecord = Record<string, TestJsonValue>;

function appendBatches(target: A2uiStreamComponentBatch[], result: A2uiStreamComponentScanResult): void {
  result.batches.forEach((batch: A2uiStreamComponentBatch) => {
    target.push(batch);
  });
}

function componentId(batch: A2uiStreamComponentBatch, index: number): string {
  const component: TestJsonRecord = batch.components[index] as TestJsonRecord;
  const id: TestJsonValue = component['id'];
  return typeof id === 'string' ? id : '';
}

export default function a2uiUpdateComponentsStreamScannerTest() {
  describe('a2uiUpdateComponentsStreamScanner', () => {
    it('emits a complete component while retaining a following partial component', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const first = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"lab","components":[' +
        '{"id":"first","component":"Text","text":"ready"},' +
        '{"id":"second","component":"Text","text":"par'
      );

      expect(first.error).assertEqual('');
      expect(first.batches.length).assertEqual(1);
      expect(first.batches[0].version).assertEqual('v0.9.1');
      expect(first.batches[0].surfaceId).assertEqual('lab');
      expect(first.batches[0].components.length).assertEqual(1);
      expect(componentId(first.batches[0], 0)).assertEqual('first');

      const second = scanner.feed('tial"}]}}');
      expect(second.error).assertEqual('');
      expect(second.batches.length).assertEqual(1);
      expect(second.batches[0].components.length).assertEqual(1);
      expect(componentId(second.batches[0], 0)).assertEqual('second');
      expect(scanner.finalize().error).assertEqual('');
    });

    it('handles every UTF-16 code unit arriving separately without duplicate emission', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const envelope =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"char-stream","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"message"},' +
        '{"id":"message","component":"Text","text":"你好😀"}]}}';
      const batches: A2uiStreamComponentBatch[] = [];
      for (let index: number = 0; index < envelope.length; index++) {
        const result = scanner.feed(envelope.charAt(index));
        expect(result.error).assertEqual('');
        appendBatches(batches, result);
      }

      expect(batches.length).assertEqual(2);
      expect(componentId(batches[0], 0)).assertEqual('root');
      expect(componentId(batches[1], 0)).assertEqual('message');
      expect(scanner.finalize().error).assertEqual('');
    });

    it('ignores structural characters and escaped quotes inside component strings', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const first = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"strings","components":[' +
        '{"id":"text","component":"Text","text":"brace } array ] and escaped \\\"quote\\\"'
      );
      expect(first.batches.length).assertEqual(0);
      const second = scanner.feed(' plus slash \\\\ end"}]}}');

      expect(second.error).assertEqual('');
      expect(second.batches.length).assertEqual(1);
      expect(second.batches[0].components.length).assertEqual(1);
      const component = second.batches[0].components[0] as TestJsonRecord;
      expect(component['text'] as string).assertEqual('brace } array ] and escaped "quote" plus slash \\ end');
    });

    it('scans consecutive envelopes without requiring JSONL newlines', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const result = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"one","components":[' +
        '{"id":"a","component":"Text","text":"A"}]}}' +
        '{"version":"v0.9.2","updateComponents":{"surfaceId":"two","components":[' +
        '{"id":"b","component":"Text","text":"B"}]}}'
      );

      expect(result.error).assertEqual('');
      expect(result.batches.length).assertEqual(2);
      expect(result.batches[0].surfaceId).assertEqual('one');
      expect(result.batches[1].surfaceId).assertEqual('two');
      expect(result.batches[1].version).assertEqual('v0.9.2');
      expect(componentId(result.batches[1], 0)).assertEqual('b');
    });

    it('waits for late surface and version metadata before publishing queued components', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const first = scanner.feed(
        '{"updateComponents":{"components":[{"id":"late","component":"Text","text":"ready"}]'
      );
      expect(first.error).assertEqual('');
      expect(first.batches.length).assertEqual(0);

      const second = scanner.feed(',"surfaceId":"late-surface"},"version":"v0.9.1"}');
      expect(second.error).assertEqual('');
      expect(second.batches.length).assertEqual(1);
      expect(second.batches[0].surfaceId).assertEqual('late-surface');
      expect(second.batches[0].version).assertEqual('v0.9.1');
      expect(componentId(second.batches[0], 0)).assertEqual('late');
    });

    it('keeps an envelope alive when a chunk ends exactly after the components array', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const first = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"split-tail","components":[' +
        '{"id":"only","component":"Text","text":"ready"}]'
      );

      expect(first.error).assertEqual('');
      expect(first.batches.length).assertEqual(1);
      expect(componentId(first.batches[0], 0)).assertEqual('only');
      expect(scanner.bufferedLength() > 0).assertTrue();

      const second = scanner.feed('}}');
      expect(second.error).assertEqual('');
      expect(second.batches.length).assertEqual(0);
      expect(scanner.bufferedLength()).assertEqual(0);
    });

    it('reports an incomplete tail on finalize and can be reused afterward', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      const partial = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"partial","components":[' +
        '{"id":"done","component":"Text","text":"done"},{"id":"half"'
      );
      expect(partial.error).assertEqual('');
      expect(partial.batches.length).assertEqual(1);

      const finalResult = scanner.finalize();
      expect(finalResult.error.indexOf('Incomplete')).assertLarger(-1);
      expect(scanner.bufferedLength()).assertEqual(0);

      const recovered = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"recovered","components":[' +
        '{"id":"ok","component":"Text","text":"ok"}]}}'
      );
      expect(recovered.error).assertEqual('');
      expect(recovered.batches.length).assertEqual(1);
      expect(componentId(recovered.batches[0], 0)).assertEqual('ok');
    });

    it('reset discards an unfinished envelope without leaking its component state', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner();
      scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"old","components":[' +
        '{"id":"old","component":"Text","text":"old"},'
      );
      scanner.reset();

      const result = scanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"new","components":[' +
        '{"id":"new","component":"Text","text":"new"}]}}'
      );
      expect(result.error).assertEqual('');
      expect(result.batches.length).assertEqual(1);
      expect(result.batches[0].surfaceId).assertEqual('new');
      expect(result.batches[0].components.length).assertEqual(1);
      expect(componentId(result.batches[0], 0)).assertEqual('new');
    });

    it('resets after buffer overflow', 0, () => {
      const scanner = new A2uiUpdateComponentsStreamScanner(32);
      const overflow = scanner.feed('{"updateComponents":{"surfaceId":"too-large"');
      expect(overflow.error.indexOf('limit')).assertLarger(-1);
      expect(scanner.bufferedLength()).assertEqual(0);

      const smallScanner = new A2uiUpdateComponentsStreamScanner(128);
      const recovered = smallScanner.feed(
        '{"updateComponents":{"surfaceId":"s","components":[{"id":"x"}]}}'
      );
      expect(recovered.error).assertEqual('');
      expect(recovered.batches.length).assertEqual(1);
    });

    it('rejects markdown fences and protocol tags instead of silently stripping them', 0, () => {
      const markdownScanner = new A2uiUpdateComponentsStreamScanner();
      const markdown = markdownScanner.feed('```json\n{"updateComponents":{"surfaceId":"s","components":[]}}\n```');
      expect(markdown.error.length > 0).assertTrue();

      const tagScanner = new A2uiUpdateComponentsStreamScanner();
      const tagged = tagScanner.feed('<a2ui-json>{"updateComponents":{"surfaceId":"s","components":[]}}</a2ui-json>');
      expect(tagged.error.length > 0).assertTrue();
    });

    it('strictly rejects missing, leading, repeated, and trailing component separators', 0, () => {
      const prefix = '{"version":"v0.9.1","updateComponents":{"surfaceId":"s","components":[';
      const suffix = ']}}';
      const missing = new A2uiUpdateComponentsStreamScanner().feed(
        prefix + '{"id":"a"}{"id":"b"}' + suffix
      );
      const leading = new A2uiUpdateComponentsStreamScanner().feed(
        prefix + ',{"id":"a"}' + suffix
      );
      const repeated = new A2uiUpdateComponentsStreamScanner().feed(
        prefix + '{"id":"a"},,{"id":"b"}' + suffix
      );
      const trailing = new A2uiUpdateComponentsStreamScanner().feed(
        prefix + '{"id":"a"},' + suffix
      );

      expect(missing.error.length > 0).assertTrue();
      expect(leading.error.length > 0).assertTrue();
      expect(repeated.error.length > 0).assertTrue();
      expect(trailing.error.length > 0).assertTrue();
      expect(missing.batches.length + leading.batches.length + repeated.batches.length +
        trailing.batches.length).assertEqual(0);
    });

    it('rejects duplicate critical metadata and freezes metadata after publication', 0, () => {
      const duplicateVersionScanner = new A2uiUpdateComponentsStreamScanner();
      const published = duplicateVersionScanner.feed(
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"s","components":[{"id":"a"}]}'
      );
      expect(published.error).assertEqual('');
      expect(published.batches.length).assertEqual(1);
      const changedAfterPublication = duplicateVersionScanner.feed(',"version":"v0.9.2"}');
      expect(changedAfterPublication.error.indexOf('duplicate version')).assertLarger(-1);
      expect(changedAfterPublication.batches.length).assertEqual(0);

      const duplicateVersion = new A2uiUpdateComponentsStreamScanner().feed(
        '{"version":"v0.9.1","version":"v0.9.2",' +
        '"updateComponents":{"surfaceId":"s","components":[]}}'
      );
      const duplicateUpdate = new A2uiUpdateComponentsStreamScanner().feed(
        '{"updateComponents":{"surfaceId":"s","components":[]},' +
        '"updateComponents":{"surfaceId":"s","components":[]}}'
      );
      const duplicateSurface = new A2uiUpdateComponentsStreamScanner().feed(
        '{"updateComponents":{"surfaceId":"s","surfaceId":"other","components":[]}}'
      );
      const duplicateComponents = new A2uiUpdateComponentsStreamScanner().feed(
        '{"updateComponents":{"surfaceId":"s","components":[],"components":[]}}'
      );
      expect(duplicateVersion.error.indexOf('duplicate version')).assertLarger(-1);
      expect(duplicateUpdate.error.indexOf('duplicate updateComponents')).assertLarger(-1);
      expect(duplicateSurface.error.indexOf('duplicate surfaceId')).assertLarger(-1);
      expect(duplicateComponents.error.indexOf('duplicate components')).assertLarger(-1);
    });

    it('discards earlier batches when a later envelope fails in the same feed result', 0, () => {
      const result = new A2uiUpdateComponentsStreamScanner().feed(
        '{"updateComponents":{"surfaceId":"ok","components":[{"id":"ok"}]}}' +
        '{"updateComponents":{"surfaceId":"bad","components":[,{"id":"bad"}]}}'
      );
      expect(result.error.length > 0).assertTrue();
      expect(result.batches.length).assertEqual(0);
    });
  });
}
