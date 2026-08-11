type ScannerJsonValue = Object | string | number | boolean | null | undefined;
type ScannerJsonRecord = Record<string, ScannerJsonValue>;

export class A2uiStreamComponentBatch {
  version: string;
  surfaceId: string;
  components: Object[];

  constructor(version: string, surfaceId: string, components: Object[]) {
    this.version = version;
    this.surfaceId = surfaceId;
    this.components = components;
  }
}

export class A2uiStreamComponentScanResult {
  batches: A2uiStreamComponentBatch[];
  error: string;

  constructor(batches: A2uiStreamComponentBatch[] = [], error: string = '') {
    this.batches = batches;
    this.error = error;
  }
}

const DEFAULT_MAX_BUFFERED_CHARACTERS: number = 10 * 1024 * 1024;

/**
 * Extracts complete component objects from streaming updateComponents envelopes.
 *
 * This scanner deliberately does not understand markdown fences, protocol tags,
 * or partial Text/Markdown values. A component is published only after its JSON
 * object is structurally complete and JSON.parse succeeds.
 */
export class A2uiUpdateComponentsStreamScanner {
  private readonly maxBufferedCharacters: number;
  private buffer: string = '';
  private envelopeStarted: boolean = false;
  private envelopeStart: number = -1;
  private envelopeEnd: number = -1;
  private scanPosition: number = 0;
  private braceDepth: number = 0;
  private arrayDepth: number = 0;
  private inString: boolean = false;
  private escaped: boolean = false;
  private stringStart: number = -1;
  private stringRole: string = '';
  private candidateString: string = '';
  private candidateBraceDepth: number = -1;
  private candidateArrayDepth: number = -1;
  private expectedValueRole: string = '';
  private updateObjectDepth: number = -1;
  private updateObjectArrayDepth: number = -1;
  private componentsArrayStart: number = -1;
  private componentsArrayDepth: number = -1;
  private componentScanPosition: number = -1;
  private componentsArrayClosed: boolean = false;
  private componentStart: number = -1;
  private componentDepth: number = 0;
  private componentInString: boolean = false;
  private componentEscaped: boolean = false;
  private componentArrayState: string = 'expect_value_or_end';
  private pendingComponents: Object[] = [];
  private version: string = '';
  private versionResolved: boolean = false;
  private surfaceId: string = '';
  private surfaceIdResolved: boolean = false;
  private versionKeySeen: boolean = false;
  private updateComponentsKeySeen: boolean = false;
  private surfaceIdKeySeen: boolean = false;
  private componentsKeySeen: boolean = false;
  private metadataPublished: boolean = false;

  constructor(maxBufferedCharacters: number = DEFAULT_MAX_BUFFERED_CHARACTERS) {
    this.maxBufferedCharacters = Math.max(1, maxBufferedCharacters);
  }

  feed(delta: string): A2uiStreamComponentScanResult {
    if (this.buffer.length + delta.length > this.maxBufferedCharacters) {
      this.reset();
      return new A2uiStreamComponentScanResult([], 'A2UI component stream buffer limit exceeded');
    }
    if (delta.length > 0) {
      this.buffer += delta;
    }

    const batches: A2uiStreamComponentBatch[] = [];
    while (true) {
      const startError: string = this.ensureEnvelopeStarted();
      if (startError.length > 0) {
        return this.fail(batches, startError);
      }
      if (!this.envelopeStarted) {
        break;
      }

      const scanError: string = this.scanEnvelope();
      if (scanError.length > 0) {
        return this.fail(batches, scanError);
      }
      const componentError: string = this.extractCompleteComponents();
      if (componentError.length > 0) {
        return this.fail(batches, componentError);
      }

      if (this.envelopeEnd < 0) {
        this.flushPendingComponents(batches);
        break;
      }

      const envelopeError: string = this.completeEnvelope();
      if (envelopeError.length > 0) {
        return this.fail(batches, envelopeError);
      }
      this.flushPendingComponents(batches, true);
      this.buffer = this.buffer.substring(this.envelopeEnd + 1);
      this.clearEnvelopeState();
    }
    return new A2uiStreamComponentScanResult(batches, '');
  }

  finalize(): A2uiStreamComponentScanResult {
    const result: A2uiStreamComponentScanResult = this.feed('');
    if (result.error.length > 0) {
      return result;
    }
    if (this.buffer.trim().length > 0 || this.envelopeStarted) {
      return this.fail(result.batches, 'Incomplete A2UI JSON envelope at end of stream');
    }
    this.reset();
    return result;
  }

  reset(): void {
    this.buffer = '';
    this.clearEnvelopeState();
  }

  bufferedLength(): number {
    return this.buffer.length;
  }

  private ensureEnvelopeStarted(): string {
    if (this.envelopeStarted) {
      return '';
    }
    let index: number = 0;
    while (index < this.buffer.length && this.isWhitespace(this.buffer.charAt(index))) {
      index++;
    }
    if (index >= this.buffer.length) {
      return '';
    }
    if (this.buffer.charAt(index) !== '{') {
      return 'A2UI component stream expects a JSON envelope';
    }
    this.envelopeStarted = true;
    this.envelopeStart = index;
    this.scanPosition = index;
    return '';
  }

  private scanEnvelope(): string {
    for (let index: number = this.scanPosition; index < this.buffer.length; index++) {
      const character: string = this.buffer.charAt(index);
      if (this.inString) {
        if (this.escaped) {
          this.escaped = false;
        } else if (character === '\\') {
          this.escaped = true;
        } else if (character === '"') {
          const stringError: string = this.finishString(index);
          if (stringError.length > 0) {
            return stringError;
          }
        }
        this.scanPosition = index + 1;
        continue;
      }

      if (character === '"') {
        this.inString = true;
        this.escaped = false;
        this.stringStart = index;
        this.stringRole = this.expectedValueRole;
        if (this.stringRole.length > 0) {
          this.expectedValueRole = '';
        }
      } else if (character === '{') {
        this.braceDepth++;
        if (this.expectedValueRole === 'updateComponents') {
          this.updateObjectDepth = this.braceDepth;
          this.updateObjectArrayDepth = this.arrayDepth;
          this.expectedValueRole = '';
        }
      } else if (character === '}') {
        if (this.braceDepth <= 0) {
          return 'A2UI component stream has an unmatched object terminator';
        }
        if (this.braceDepth === this.updateObjectDepth && this.arrayDepth === this.updateObjectArrayDepth) {
          this.updateObjectDepth = -1;
          this.updateObjectArrayDepth = -1;
        }
        this.braceDepth--;
        this.clearCandidate();
        if (this.braceDepth === 0) {
          this.envelopeEnd = index;
          this.scanPosition = index + 1;
          return '';
        }
      } else if (character === '[') {
        this.arrayDepth++;
        if (this.expectedValueRole === 'components') {
          this.componentsArrayStart = index;
          this.componentsArrayDepth = this.arrayDepth;
          this.componentScanPosition = index + 1;
          this.expectedValueRole = '';
        }
      } else if (character === ']') {
        if (this.arrayDepth <= 0) {
          return 'A2UI component stream has an unmatched array terminator';
        }
        this.arrayDepth--;
        this.clearCandidate();
      } else if (character === ':') {
        const keyError: string = this.applyCandidateAsKey();
        if (keyError.length > 0) return keyError;
      } else if (character === ',' || !this.isWhitespace(character)) {
        if (character === ',') {
          this.clearCandidate();
          this.expectedValueRole = '';
        } else if (this.expectedValueRole.length > 0) {
          this.expectedValueRole = '';
        }
      }
      this.scanPosition = index + 1;
    }
    return '';
  }

  private finishString(end: number): string {
    let value: string = '';
    try {
      value = JSON.parse(this.buffer.substring(this.stringStart, end + 1)) as string;
    } catch (error) {
      return 'A2UI component stream contains an invalid JSON string';
    }
    this.inString = false;
    this.escaped = false;
    this.stringStart = -1;
    if (this.stringRole === 'version') {
      this.version = value;
      this.versionResolved = true;
    } else if (this.stringRole === 'surfaceId') {
      this.surfaceId = value;
      this.surfaceIdResolved = true;
    } else {
      this.candidateString = value;
      this.candidateBraceDepth = this.braceDepth;
      this.candidateArrayDepth = this.arrayDepth;
    }
    this.stringRole = '';
    return '';
  }

  private applyCandidateAsKey(): string {
    const key: string = this.candidateString;
    const keyBraceDepth: number = this.candidateBraceDepth;
    const keyArrayDepth: number = this.candidateArrayDepth;
    this.clearCandidate();
    if (keyBraceDepth === 1 && keyArrayDepth === 0) {
      if (key === 'version') {
        if (this.versionKeySeen) return 'A2UI component stream contains duplicate version metadata';
        this.versionKeySeen = true;
        this.expectedValueRole = 'version';
      } else if (key === 'updateComponents') {
        if (this.updateComponentsKeySeen) {
          return 'A2UI component stream contains duplicate updateComponents metadata';
        }
        this.updateComponentsKeySeen = true;
        this.expectedValueRole = 'updateComponents';
      }
      return '';
    }
    if (this.updateObjectDepth > 0 && keyBraceDepth === this.updateObjectDepth &&
      keyArrayDepth === this.updateObjectArrayDepth) {
      if (key === 'surfaceId') {
        if (this.surfaceIdKeySeen) return 'A2UI component stream contains duplicate surfaceId metadata';
        this.surfaceIdKeySeen = true;
        this.expectedValueRole = 'surfaceId';
      } else if (key === 'components') {
        if (this.componentsKeySeen) return 'A2UI component stream contains duplicate components metadata';
        this.componentsKeySeen = true;
        this.expectedValueRole = 'components';
      }
    }
    return '';
  }

  private extractCompleteComponents(): string {
    if (this.componentsArrayStart < 0 || this.componentScanPosition < 0 || this.componentsArrayClosed) {
      return '';
    }
    const limit: number = this.envelopeEnd >= 0 ? this.envelopeEnd + 1 : this.buffer.length;
    let index: number = this.componentScanPosition;
    while (index < limit) {
      const character: string = this.buffer.charAt(index);
      if (this.componentStart < 0) {
        if (this.isWhitespace(character)) {
          index++;
          this.componentScanPosition = index;
          continue;
        }
        if (this.componentArrayState === 'expect_comma_or_end') {
          if (character === ',') {
            this.componentArrayState = 'expect_value';
            index++;
            this.componentScanPosition = index;
            continue;
          }
          if (character !== ']') {
            return 'A2UI updateComponents.components requires a comma between objects';
          }
        } else if (character === ',') {
          return 'A2UI updateComponents.components contains an unexpected comma';
        } else if (character === ']' && this.componentArrayState === 'expect_value') {
          return 'A2UI updateComponents.components contains a trailing comma';
        }
        if (character === ']') {
          this.componentScanPosition = index + 1;
          this.componentsArrayClosed = true;
          return '';
        }
        if (character !== '{') {
          return 'A2UI updateComponents.components only accepts JSON objects';
        }
        this.componentStart = index;
        this.componentDepth = 1;
        this.componentInString = false;
        this.componentEscaped = false;
        index++;
        this.componentScanPosition = index;
        continue;
      }

      if (this.componentInString) {
        if (this.componentEscaped) {
          this.componentEscaped = false;
        } else if (character === '\\') {
          this.componentEscaped = true;
        } else if (character === '"') {
          this.componentInString = false;
        }
      } else if (character === '"') {
        this.componentInString = true;
      } else if (character === '{') {
        this.componentDepth++;
      } else if (character === '}') {
        this.componentDepth--;
        if (this.componentDepth === 0) {
          try {
            this.pendingComponents.push(JSON.parse(
              this.buffer.substring(this.componentStart, index + 1)
            ) as Object);
          } catch (error) {
            return 'A2UI updateComponents contains an invalid component object';
          }
          this.componentStart = -1;
          this.componentInString = false;
          this.componentEscaped = false;
          this.componentArrayState = 'expect_comma_or_end';
        }
      }
      index++;
      this.componentScanPosition = index;
    }
    return '';
  }

  private completeEnvelope(): string {
    let root: ScannerJsonRecord;
    try {
      root = JSON.parse(this.buffer.substring(this.envelopeStart, this.envelopeEnd + 1)) as ScannerJsonRecord;
    } catch (error) {
      return 'A2UI component stream contains an invalid JSON envelope';
    }
    const updateValue: ScannerJsonValue = root['updateComponents'];
    if (updateValue === undefined || updateValue === null) {
      return this.pendingComponents.length === 0 ? '' : 'A2UI component stream lost updateComponents metadata';
    }
    if (typeof updateValue !== 'object' || Array.isArray(updateValue)) {
      return 'A2UI updateComponents must be an object';
    }
    const update: ScannerJsonRecord = updateValue as ScannerJsonRecord;
    const parsedSurfaceId: ScannerJsonValue = update['surfaceId'];
    const parsedComponents: ScannerJsonValue = update['components'];
    if (typeof parsedSurfaceId !== 'string' || parsedSurfaceId.length === 0 || !Array.isArray(parsedComponents)) {
      return 'A2UI updateComponents requires surfaceId and components';
    }
    if (this.surfaceIdResolved && this.surfaceId !== parsedSurfaceId) {
      return this.metadataPublished ?
        'A2UI component stream surfaceId metadata changed after publication' :
        'A2UI component stream surfaceId metadata changed after parsing';
    }
    if (!this.surfaceIdResolved) {
      this.surfaceId = parsedSurfaceId;
      this.surfaceIdResolved = true;
    }
    const parsedVersion: ScannerJsonValue = root['version'];
    const finalVersion: string = typeof parsedVersion === 'string' ? parsedVersion : '';
    if (this.versionResolved && this.version !== finalVersion) {
      return this.metadataPublished ?
        'A2UI component stream version metadata changed after publication' :
        'A2UI component stream version metadata changed after parsing';
    }
    if (!this.versionResolved) {
      this.version = finalVersion;
      this.versionResolved = true;
    }
    return '';
  }

  private flushPendingComponents(batches: A2uiStreamComponentBatch[], force: boolean = false): void {
    if (this.pendingComponents.length === 0 || !this.surfaceIdResolved || (!this.versionResolved && !force)) {
      return;
    }
    batches.push(new A2uiStreamComponentBatch(this.version, this.surfaceId, this.pendingComponents));
    this.pendingComponents = [];
    this.metadataPublished = true;
  }

  private fail(_batches: A2uiStreamComponentBatch[], message: string): A2uiStreamComponentScanResult {
    this.reset();
    return new A2uiStreamComponentScanResult([], message);
  }

  private clearCandidate(): void {
    this.candidateString = '';
    this.candidateBraceDepth = -1;
    this.candidateArrayDepth = -1;
  }

  private clearEnvelopeState(): void {
    this.envelopeStarted = false;
    this.envelopeStart = -1;
    this.envelopeEnd = -1;
    this.scanPosition = 0;
    this.braceDepth = 0;
    this.arrayDepth = 0;
    this.inString = false;
    this.escaped = false;
    this.stringStart = -1;
    this.stringRole = '';
    this.clearCandidate();
    this.expectedValueRole = '';
    this.updateObjectDepth = -1;
    this.updateObjectArrayDepth = -1;
    this.componentsArrayStart = -1;
    this.componentsArrayDepth = -1;
    this.componentScanPosition = -1;
    this.componentsArrayClosed = false;
    this.componentStart = -1;
    this.componentDepth = 0;
    this.componentInString = false;
    this.componentEscaped = false;
    this.componentArrayState = 'expect_value_or_end';
    this.pendingComponents = [];
    this.version = '';
    this.versionResolved = false;
    this.surfaceId = '';
    this.surfaceIdResolved = false;
    this.versionKeySeen = false;
    this.updateComponentsKeySeen = false;
    this.surfaceIdKeySeen = false;
    this.componentsKeySeen = false;
    this.metadataPublished = false;
  }

  private isWhitespace(character: string): boolean {
    return character === ' ' || character === '\t' || character === '\r' || character === '\n';
  }
}
