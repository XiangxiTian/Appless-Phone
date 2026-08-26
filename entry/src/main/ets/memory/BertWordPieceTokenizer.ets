import { common } from '@kit.AbilityKit';
import { BgeTokenizedInput, BgeTokenizerPort } from './BgeEmbeddingTypes';

export const BGE_WORDPIECE_SEQUENCE_LENGTH: number = 128;
export const BGE_WORDPIECE_VOCAB_RAWFILE: string = 'memory/bge-small-zh-v1.5-vocab.txt';
const WORDPIECE_CONTINUATION_PREFIX: string = '##';
const MAX_INPUT_CHARACTERS_PER_WORD: number = 100;

function isWhitespace(codePoint: number): boolean {
  return codePoint === 0x20 || codePoint === 0x09 || codePoint === 0x0A || codePoint === 0x0D ||
    codePoint === 0x00A0 || codePoint === 0x1680 ||
    (codePoint >= 0x2000 && codePoint <= 0x200A) ||
    codePoint === 0x2028 || codePoint === 0x2029 || codePoint === 0x202F ||
    codePoint === 0x205F || codePoint === 0x3000;
}

function isControl(codePoint: number): boolean {
  if (codePoint === 0x09 || codePoint === 0x0A || codePoint === 0x0D) return false;
  return codePoint === 0 || codePoint === 0xFFFD ||
    (codePoint >= 0x0001 && codePoint <= 0x001F) ||
    (codePoint >= 0x007F && codePoint <= 0x009F) ||
    codePoint === 0x00AD || codePoint === 0x061C ||
    (codePoint >= 0x200B && codePoint <= 0x200F) ||
    (codePoint >= 0x202A && codePoint <= 0x202E) ||
    (codePoint >= 0x2060 && codePoint <= 0x2064) ||
    (codePoint >= 0x2066 && codePoint <= 0x206F) ||
    codePoint === 0xFEFF || (codePoint >= 0xFFF9 && codePoint <= 0xFFFB);
}

function isChineseCharacter(codePoint: number): boolean {
  return (codePoint >= 0x4E00 && codePoint <= 0x9FFF) ||
    (codePoint >= 0x3400 && codePoint <= 0x4DBF) ||
    (codePoint >= 0x20000 && codePoint <= 0x2A6DF) ||
    (codePoint >= 0x2A700 && codePoint <= 0x2B73F) ||
    (codePoint >= 0x2B740 && codePoint <= 0x2B81F) ||
    (codePoint >= 0x2B820 && codePoint <= 0x2CEAF) ||
    (codePoint >= 0xF900 && codePoint <= 0xFAFF) ||
    (codePoint >= 0x2F800 && codePoint <= 0x2FA1F);
}

function isPunctuation(codePoint: number): boolean {
  const asciiPunctuation = (codePoint >= 33 && codePoint <= 47) ||
    (codePoint >= 58 && codePoint <= 64) ||
    (codePoint >= 91 && codePoint <= 96) ||
    (codePoint >= 123 && codePoint <= 126);
  return asciiPunctuation ||
    (codePoint >= 0x2000 && codePoint <= 0x206F) ||
    (codePoint >= 0x2E00 && codePoint <= 0x2E7F) ||
    (codePoint >= 0x3000 && codePoint <= 0x303F) ||
    (codePoint >= 0xFE10 && codePoint <= 0xFE1F) ||
    (codePoint >= 0xFE30 && codePoint <= 0xFE4F) ||
    (codePoint >= 0xFF01 && codePoint <= 0xFF65);
}

function codePointStrings(value: string): string[] {
  const output: string[] = [];
  for (let index = 0; index < value.length;) {
    const codePoint = value.codePointAt(index) ?? 0;
    output.push(String.fromCodePoint(codePoint));
    index += codePoint > 0xFFFF ? 2 : 1;
  }
  return output;
}

function cleanAndSpaceChineseCharacters(value: string): string {
  const output: string[] = [];
  for (let index = 0; index < value.length;) {
    const codePoint = value.codePointAt(index) ?? 0;
    index += codePoint > 0xFFFF ? 2 : 1;
    if (isControl(codePoint)) continue;
    if (isWhitespace(codePoint)) {
      output.push(' ');
      continue;
    }
    const character = String.fromCodePoint(codePoint);
    if (isChineseCharacter(codePoint)) {
      output.push(' ');
      output.push(character);
      output.push(' ');
    } else {
      output.push(character);
    }
  }
  return output.join('');
}

function whitespaceTokens(value: string): string[] {
  const candidates = value.trim().split(' ');
  const output: string[] = [];
  for (let index = 0; index < candidates.length; index += 1) {
    if (candidates[index].length > 0) output.push(candidates[index]);
  }
  return output;
}

function punctuationTokens(value: string): string[] {
  const characters = codePointStrings(value);
  const output: string[] = [];
  let current: string[] = [];
  for (let index = 0; index < characters.length; index += 1) {
    const codePoint = characters[index].codePointAt(0) ?? 0;
    if (isPunctuation(codePoint)) {
      if (current.length > 0) {
        output.push(current.join(''));
        current = [];
      }
      output.push(characters[index]);
    } else {
      current.push(characters[index]);
    }
  }
  if (current.length > 0) output.push(current.join(''));
  return output;
}

export function decodeBgeWordPieceVocabulary(bytes: Uint8Array): string {
  if (bytes.length === 0) {
    throw new Error('BGE vocabulary rawfile is empty: ' + BGE_WORDPIECE_VOCAB_RAWFILE);
  }
  const characters: string[] = [];
  for (let index = 0; index < bytes.length;) {
    const leading = bytes[index];
    let codePoint = 0;
    let continuationCount = 0;
    if (leading <= 0x7F) {
      codePoint = leading;
    } else if (leading >= 0xC2 && leading <= 0xDF) {
      codePoint = leading & 0x1F;
      continuationCount = 1;
    } else if (leading >= 0xE0 && leading <= 0xEF) {
      codePoint = leading & 0x0F;
      continuationCount = 2;
    } else if (leading >= 0xF0 && leading <= 0xF4) {
      codePoint = leading & 0x07;
      continuationCount = 3;
    } else {
      throw invalidVocabularyUtf8Error();
    }
    if (index + continuationCount >= bytes.length) throw invalidVocabularyUtf8Error();
    for (let offset = 1; offset <= continuationCount; offset += 1) {
      const continuation = bytes[index + offset];
      if (continuation < 0x80 || continuation > 0xBF) throw invalidVocabularyUtf8Error();
      codePoint = (codePoint << 6) | (continuation & 0x3F);
    }
    if ((continuationCount === 1 && codePoint < 0x80) ||
      (continuationCount === 2 && codePoint < 0x800) ||
      (continuationCount === 3 && codePoint < 0x10000) ||
      (codePoint >= 0xD800 && codePoint <= 0xDFFF) || codePoint > 0x10FFFF) {
      throw invalidVocabularyUtf8Error();
    }
    characters.push(String.fromCodePoint(codePoint));
    index += continuationCount + 1;
  }
  if (characters.length > 0 && characters[0] === '\uFEFF') characters.shift();
  return characters.join('');
}

function invalidVocabularyUtf8Error(): Error {
  return new Error('BGE vocabulary rawfile is not valid UTF-8: ' + BGE_WORDPIECE_VOCAB_RAWFILE);
}

/**
 * Phone-local BERT BasicTokenizer + greedy WordPiece tokenizer used by
 * BAAI/bge-small-zh-v1.5. Case and accents are intentionally preserved.
 */
export class BertWordPieceTokenizer implements BgeTokenizerPort {
  private vocabulary: Map<string, number> = new Map<string, number>();
  private unknownTokenId: number;
  private classificationTokenId: number;
  private separatorTokenId: number;
  private paddingTokenId: number;
  private neverSplit: Set<string> = new Set<string>();

  constructor(vocabularyText: string) {
    const vocabularyLines = vocabularyText.split('\n');
    if (vocabularyLines.length > 0 && vocabularyLines[vocabularyLines.length - 1].length === 0) {
      vocabularyLines.pop();
    }
    for (let index = 0; index < vocabularyLines.length; index += 1) {
      let token = vocabularyLines[index];
      if (token.endsWith('\r')) token = token.substring(0, token.length - 1);
      this.vocabulary.set(token, index);
    }
    this.paddingTokenId = this.requiredTokenId('[PAD]');
    this.unknownTokenId = this.requiredTokenId('[UNK]');
    this.classificationTokenId = this.requiredTokenId('[CLS]');
    this.separatorTokenId = this.requiredTokenId('[SEP]');
    this.neverSplit.add('[PAD]');
    this.neverSplit.add('[UNK]');
    this.neverSplit.add('[CLS]');
    this.neverSplit.add('[SEP]');
    this.neverSplit.add('[MASK]');
  }

  static async fromRawfile(context: common.Context): Promise<BertWordPieceTokenizer> {
    let vocabularyBytes: Uint8Array;
    try {
      vocabularyBytes = await context.resourceManager.getRawFileContent(BGE_WORDPIECE_VOCAB_RAWFILE);
    } catch (_error) {
      throw new Error('BGE vocabulary rawfile is missing or unreadable: ' + BGE_WORDPIECE_VOCAB_RAWFILE);
    }
    return new BertWordPieceTokenizer(decodeBgeWordPieceVocabulary(vocabularyBytes));
  }

  encode(text: string, sequenceLength: number): BgeTokenizedInput {
    if (sequenceLength !== BGE_WORDPIECE_SEQUENCE_LENGTH) {
      throw new Error('BGE WordPiece tokenizer requires sequence length 128');
    }
    const wordPieceTokens = this.tokenize(text);
    const contentLimit = sequenceLength - 2;
    const inputIds = new Int32Array(sequenceLength);
    const attentionMask = new Int32Array(sequenceLength);
    const tokenTypeIds = new Int32Array(sequenceLength);
    inputIds.fill(this.paddingTokenId);
    inputIds[0] = this.classificationTokenId;
    attentionMask[0] = 1;
    const contentCount = Math.min(wordPieceTokens.length, contentLimit);
    for (let index = 0; index < contentCount; index += 1) {
      inputIds[index + 1] = this.vocabulary.get(wordPieceTokens[index]) ?? this.unknownTokenId;
      attentionMask[index + 1] = 1;
    }
    const separatorIndex = contentCount + 1;
    inputIds[separatorIndex] = this.separatorTokenId;
    attentionMask[separatorIndex] = 1;
    return { inputIds, attentionMask, tokenTypeIds };
  }

  tokenize(text: string): string[] {
    const basicTokens = this.basicTokenize(text);
    const output: string[] = [];
    for (let index = 0; index < basicTokens.length; index += 1) {
      const pieces = this.wordPieceTokenize(basicTokens[index]);
      for (let pieceIndex = 0; pieceIndex < pieces.length; pieceIndex += 1) {
        output.push(pieces[pieceIndex]);
      }
    }
    return output;
  }

  private requiredTokenId(token: string): number {
    const tokenId = this.vocabulary.get(token);
    if (tokenId === undefined) throw new Error('BGE vocabulary is missing required token ' + token);
    return tokenId;
  }

  private basicTokenize(text: string): string[] {
    const initialTokens = whitespaceTokens(cleanAndSpaceChineseCharacters(text));
    const output: string[] = [];
    for (let index = 0; index < initialTokens.length; index += 1) {
      const token = initialTokens[index];
      if (this.neverSplit.has(token)) {
        output.push(token);
        continue;
      }
      const pieces = punctuationTokens(token);
      for (let pieceIndex = 0; pieceIndex < pieces.length; pieceIndex += 1) {
        output.push(pieces[pieceIndex]);
      }
    }
    return output;
  }

  private wordPieceTokenize(token: string): string[] {
    if (this.neverSplit.has(token)) return [token];
    const characters = codePointStrings(token);
    if (characters.length > MAX_INPUT_CHARACTERS_PER_WORD) return ['[UNK]'];
    const pieces: string[] = [];
    let start = 0;
    while (start < characters.length) {
      let end = characters.length;
      let currentPiece = '';
      while (start < end) {
        const prefix = start > 0 ? WORDPIECE_CONTINUATION_PREFIX : '';
        const candidate = prefix + characters.slice(start, end).join('');
        if (this.vocabulary.has(candidate)) {
          currentPiece = candidate;
          break;
        }
        end -= 1;
      }
      if (currentPiece.length === 0) return ['[UNK]'];
      pieces.push(currentPiece);
      start = end;
    }
    return pieces;
  }
}
