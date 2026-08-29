const MAX_LEADER_ANSWER_STREAM_CHARS: number = 120000;

function hexValue(char: string): number {
  const code = char.charCodeAt(0);
  if (code >= 48 && code <= 57) return code - 48;
  if (code >= 65 && code <= 70) return code - 65 + 10;
  if (code >= 97 && code <= 102) return code - 97 + 10;
  return -1;
}

function unicodeValue(source: string, offset: number): number {
  if (offset + 4 > source.length) return -1;
  let value = 0;
  for (let index = 0; index < 4; index++) {
    const digit = hexValue(source.charAt(offset + index));
    if (digit < 0) return -1;
    value = value * 16 + digit;
  }
  return value;
}

function answerValueStart(source: string): number {
  const match = /"answer"\s*:\s*"/.exec(source);
  return match === null || match.index === undefined ? -1 : match.index + match[0].length;
}

export function leaderAnswerPrefix(source: string): string | null {
  const start = answerValueStart(source);
  if (start < 0) return null;
  let result = '';
  let index = start;
  while (index < source.length) {
    const char = source.charAt(index);
    if (char === '"') return result;
    if (char !== '\\') {
      if (char === '\r' || char === '\n') return result;
      result += char;
      index++;
      continue;
    }
    if (index + 1 >= source.length) return result;
    const escaped = source.charAt(index + 1);
    if (escaped === '"' || escaped === '\\' || escaped === '/') {
      result += escaped;
      index += 2;
      continue;
    }
    if (escaped === 'b' || escaped === 'f' || escaped === 'n' || escaped === 'r' || escaped === 't') {
      if (escaped === 'b') result += '\b';
      if (escaped === 'f') result += '\f';
      if (escaped === 'n') result += '\n';
      if (escaped === 'r') result += '\r';
      if (escaped === 't') result += '\t';
      index += 2;
      continue;
    }
    if (escaped !== 'u') return result;
    const high = unicodeValue(source, index + 2);
    if (high < 0) return result;
    if (high >= 0xD800 && high <= 0xDBFF) {
      if (index + 12 > source.length || source.substring(index + 6, index + 8) !== '\\u') return result;
      const low = unicodeValue(source, index + 8);
      if (low < 0xDC00 || low > 0xDFFF) return result;
      result += String.fromCodePoint(0x10000 + (high - 0xD800) * 0x400 + low - 0xDC00);
      index += 12;
      continue;
    }
    result += String.fromCharCode(high);
    index += 6;
  }
  return result;
}

export class LeaderAnswerStreamScanner {
  private buffer: string = '';
  private lastAnswer: string = '';

  feed(delta: string): string | null {
    if (delta.length === 0 || this.buffer.length >= MAX_LEADER_ANSWER_STREAM_CHARS) return null;
    this.buffer = (this.buffer + delta).substring(0, MAX_LEADER_ANSWER_STREAM_CHARS);
    const answer = leaderAnswerPrefix(this.buffer);
    if (answer === null || answer.length === 0 || answer === this.lastAnswer) return null;
    this.lastAnswer = answer;
    return answer;
  }
}
