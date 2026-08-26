import { describe, expect, it } from '@ohos/hypium';
import {
  BGE_WORDPIECE_SEQUENCE_LENGTH,
  BGE_WORDPIECE_VOCAB_RAWFILE,
  BertWordPieceTokenizer,
  decodeBgeWordPieceVocabulary
} from '../main/ets/memory/BertWordPieceTokenizer';

function fakeVocabulary(): string {
  return [
    '[PAD]', '[unused1]', '[unused2]', '[unused3]', '[UNK]', '[CLS]', '[SEP]', '[MASK]',
    '咖', '啡', '，', '。', 'work', '##ing', 'Hello', 'hello', '中'
  ].join('\n') + '\n';
}

function selectedRealBgeVocabulary(): string {
  const tokens: string[] = [];
  for (let index = 0; index <= 7474; index += 1) tokens.push('[contract-' + index + ']');
  tokens[0] = '[PAD]';
  tokens[100] = '[UNK]';
  tokens[101] = '[CLS]';
  tokens[102] = '[SEP]';
  tokens[103] = '[MASK]';
  // The real vocab contains U+2028 at id 343. It must not be treated as a line delimiter.
  tokens[343] = '\u2028';
  tokens[2769] = '我';
  tokens[1599] = '喜';
  tokens[3614] = '欢';
  tokens[2128] = '安';
  tokens[7474] = '静';
  tokens[510] = '、';
  tokens[1045] = '光';
  tokens[5296] = '线';
  tokens[1041] = '充';
  tokens[6639] = '足';
  tokens[5445] = '而';
  tokens[684] = '且';
  tokens[1377] = '可';
  tokens[809] = '以';
  tokens[1600] = '喝';
  tokens[1476] = '咖';
  tokens[1565] = '啡';
  tokens[4638] = '的';
  tokens[2339] = '工';
  tokens[868] = '作';
  tokens[1765] = '地';
  tokens[4157] = '点';
  tokens[511] = '。';
  return tokens.join('\n') + '\n';
}

function prefix(values: Int32Array, count: number): number[] {
  const output: number[] = [];
  for (let index = 0; index < count; index += 1) output.push(values[index]);
  return output;
}

export default function bertWordPieceTokenizerTest() {
  describe('BertWordPieceTokenizer', () => {
    it('cleans controls, normalizes whitespace, splits Chinese and punctuation, and keeps case', 0, () => {
      const tokenizer = new BertWordPieceTokenizer(fakeVocabulary());
      const tokens = tokenizer.tokenize('\t咖啡\u0000，working  Hello hello\r\n中。');
      expect(tokens.join('|')).assertEqual('咖|啡|，|work|##ing|Hello|hello|中|。');
    });

    it('adds special tokens, right pads to 1x128, and returns three int32 inputs', 0, () => {
      const tokenizer = new BertWordPieceTokenizer(fakeVocabulary());
      const encoded = tokenizer.encode('咖啡', BGE_WORDPIECE_SEQUENCE_LENGTH);
      expect(encoded.inputIds.length).assertEqual(128);
      expect(encoded.attentionMask.length).assertEqual(128);
      expect(encoded.tokenTypeIds.length).assertEqual(128);
      expect(prefix(encoded.inputIds, 5).join(',')).assertEqual('5,8,9,6,0');
      expect(prefix(encoded.attentionMask, 5).join(',')).assertEqual('1,1,1,1,0');
      expect(prefix(encoded.tokenTypeIds, 5).join(',')).assertEqual('0,0,0,0,0');
    });

    it('uses unknown for an indivisible token and right truncates before SEP', 0, () => {
      const tokenizer = new BertWordPieceTokenizer(fakeVocabulary());
      const unknown = tokenizer.encode('missing', BGE_WORDPIECE_SEQUENCE_LENGTH);
      expect(prefix(unknown.inputIds, 3).join(',')).assertEqual('5,4,6');

      let longText = '';
      for (let index = 0; index < 130; index += 1) longText += '中';
      const truncated = tokenizer.encode(longText, BGE_WORDPIECE_SEQUENCE_LENGTH);
      expect(truncated.inputIds[0]).assertEqual(5);
      expect(truncated.inputIds[126]).assertEqual(16);
      expect(truncated.inputIds[127]).assertEqual(6);
      expect(truncated.attentionMask[127]).assertEqual(1);
    });

    it('rejects a shape that differs from the frozen BGE export contract', 0, () => {
      const tokenizer = new BertWordPieceTokenizer(fakeVocabulary());
      let rejected = false;
      try {
        tokenizer.encode('咖啡', 64);
      } catch (_error) {
        rejected = true;
      }
      expect(rejected).assertTrue();
    });

    it('decodes ASCII, Chinese, four-byte Unicode, and an optional UTF-8 BOM', 0, () => {
      const source = '[PAD]\n词😀\n[UNK]\n[CLS]\n[SEP]\n';
      const bytes = new Uint8Array([
        0xEF, 0xBB, 0xBF, 0x5B, 0x50, 0x41, 0x44, 0x5D, 0x0A,
        0xE8, 0xAF, 0x8D, 0xF0, 0x9F, 0x98, 0x80, 0x0A,
        0x5B, 0x55, 0x4E, 0x4B, 0x5D, 0x0A,
        0x5B, 0x43, 0x4C, 0x53, 0x5D, 0x0A,
        0x5B, 0x53, 0x45, 0x50, 0x5D, 0x0A
      ]);
      expect(decodeBgeWordPieceVocabulary(bytes)).assertEqual(source);
      expect(BGE_WORDPIECE_VOCAB_RAWFILE).assertEqual('memory/bge-small-zh-v1.5-vocab.txt');
    });

    it('fails explicitly for an empty or malformed UTF-8 vocabulary resource', 0, () => {
      let emptyMessage = '';
      let invalidMessage = '';
      try {
        decodeBgeWordPieceVocabulary(new Uint8Array(0));
      } catch (error) {
        emptyMessage = error instanceof Error ? error.message : 'unknown';
      }
      try {
        decodeBgeWordPieceVocabulary(new Uint8Array([0xC3, 0x28]));
      } catch (error) {
        invalidMessage = error instanceof Error ? error.message : 'unknown';
      }
      expect(emptyMessage).assertEqual(
        'BGE vocabulary rawfile is empty: memory/bge-small-zh-v1.5-vocab.txt'
      );
      expect(invalidMessage).assertEqual(
        'BGE vocabulary rawfile is not valid UTF-8: memory/bge-small-zh-v1.5-vocab.txt'
      );
    });

    it('rejects overlong, truncated, surrogate, and out-of-range UTF-8 sequences', 0, () => {
      const invalidInputs: Uint8Array[] = [
        new Uint8Array([0xC0, 0xAF]),
        new Uint8Array([0xE4, 0xB8]),
        new Uint8Array([0xED, 0xA0, 0x80]),
        new Uint8Array([0xF4, 0x90, 0x80, 0x80])
      ];
      for (let index = 0; index < invalidInputs.length; index += 1) {
        let message = '';
        try {
          decodeBgeWordPieceVocabulary(invalidInputs[index]);
        } catch (error) {
          message = error instanceof Error ? error.message : 'unknown';
        }
        expect(message).assertEqual(
          'BGE vocabulary rawfile is not valid UTF-8: memory/bge-small-zh-v1.5-vocab.txt'
        );
      }
    });

    it('matches the committed BGE golden token ids without a PC tokenizer', 0, () => {
      const tokenizer = new BertWordPieceTokenizer(selectedRealBgeVocabulary());
      const encoded = tokenizer.encode(
        '我喜欢安静、光线充足而且可以喝咖啡的工作地点。', BGE_WORDPIECE_SEQUENCE_LENGTH
      );
      const expected: number[] = [
        101, 2769, 1599, 3614, 2128, 7474, 510, 1045, 5296, 1041, 6639, 5445, 684,
        1377, 809, 1600, 1476, 1565, 4638, 2339, 868, 1765, 4157, 511, 102
      ];
      expect(prefix(encoded.inputIds, expected.length).join(',')).assertEqual(expected.join(','));
      expect(encoded.attentionMask[expected.length - 1]).assertEqual(1);
      expect(encoded.attentionMask[expected.length]).assertEqual(0);
      expect(encoded.inputIds[expected.length]).assertEqual(0);
    });
  });
}
