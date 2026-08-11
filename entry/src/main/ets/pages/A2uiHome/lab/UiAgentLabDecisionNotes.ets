const UI_LAB_DECISION_NOTES_OPEN: string = '<ui_decision_notes>';
const UI_LAB_DECISION_NOTES_CLOSE: string = '</ui_decision_notes>';
const UI_LAB_DECISION_NOTES_TEXT_MAX: number = 2400;

type UiLabDecisionJson = Object | string | number | boolean | null | undefined;
type UiLabDecisionRecord = Record<string, UiLabDecisionJson>;

export interface UiAgentLabDecisionOutput {
  protocolCandidate: string;
  decisionNotes: string | null;
}

export class UiAgentLabDecisionNotesState {
  private surfaceId: string = '';
  private notes: string | null = null;

  update(surfaceId: string, notes: string | null): void {
    this.surfaceId = surfaceId;
    this.notes = notes;
  }

  clear(): void {
    this.surfaceId = '';
    this.notes = null;
  }

  read(surfaceId: string): string | null {
    return this.surfaceId === surfaceId ? this.notes : null;
  }
}

function recordOf(value: UiLabDecisionJson): UiLabDecisionRecord | null {
  if (value === null || value === undefined || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as UiLabDecisionRecord;
}

function exactKeys(record: UiLabDecisionRecord, keys: string[]): boolean {
  return Object.keys(record).sort().join(',') === keys.slice().sort().join(',');
}

function protocolLineOf(line: string): string | null {
  if (line.length === 0 || line !== line.trim() || line.indexOf('\n') >= 0 || line.indexOf('\r') >= 0) return null;
  try {
    const envelope = recordOf(JSON.parse(line) as Object);
    if (envelope === null || !exactKeys(envelope, ['version', 'updateComponents']) ||
      typeof envelope['version'] !== 'string' || recordOf(envelope['updateComponents']) === null) {
      return null;
    }
    return line;
  } catch (_error) {
    return null;
  }
}

function closedProtocolLine(lines: string[], closeIndex: number): string | null {
  let end = lines.length;
  if (end > closeIndex + 1 && lines[end - 1] === '') end--;
  if (end !== closeIndex + 2) return null;
  return protocolLineOf(lines[closeIndex + 1]);
}

export function parseUiAgentLabDecisionOutput(raw: string, enabled: boolean): UiAgentLabDecisionOutput {
  if (!enabled) return { protocolCandidate: raw, decisionNotes: null };

  const singleProtocol = protocolLineOf(raw);
  if (singleProtocol !== null) return { protocolCandidate: singleProtocol, decisionNotes: null };

  const lines = raw.split(/\r?\n/);
  if (lines.length < 3 || lines[0] !== UI_LAB_DECISION_NOTES_OPEN) {
    return { protocolCandidate: raw, decisionNotes: null };
  }
  let closeIndex: number = -1;
  for (let index = 1; index < lines.length; index++) {
    if (lines[index] === UI_LAB_DECISION_NOTES_CLOSE) {
      closeIndex = index;
      break;
    }
  }
  if (closeIndex < 0) return { protocolCandidate: raw, decisionNotes: null };

  const protocolCandidate = closedProtocolLine(lines, closeIndex);
  if (protocolCandidate === null) return { protocolCandidate: raw, decisionNotes: null };

  const noteLines = lines.slice(1, closeIndex);
  const decisionNotes = noteLines.indexOf(UI_LAB_DECISION_NOTES_OPEN) < 0 ? noteLines.join('\n').trim() : '';
  if (decisionNotes.length === 0 || decisionNotes.length > UI_LAB_DECISION_NOTES_TEXT_MAX) {
    return { protocolCandidate, decisionNotes: null };
  }
  return { protocolCandidate, decisionNotes };
}
