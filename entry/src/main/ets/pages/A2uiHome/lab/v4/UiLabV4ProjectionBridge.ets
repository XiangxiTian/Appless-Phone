import { LegacyA2uiSurfaceAdapter, UiCanonicalSurface } from '@loop/agent-core';

export interface UiLabV4ProjectionCallbacks {
  pushSurfaceJson: (surfaceJson: string, revision: number) => void;
  pushDiagnostic: (code: string, detail: string) => void;
}

export class UiLabV4ProjectionBridge {
  private readonly callbacks: UiLabV4ProjectionCallbacks;
  private revision: number = 0;

  constructor(callbacks: UiLabV4ProjectionCallbacks) {
    this.callbacks = callbacks;
  }

  pushSurfaceJson(surfaceJson: string): number {
    if (surfaceJson.length === 0) {
      this.callbacks.pushDiagnostic('EMPTY_UI_PROJECTION', 'surfaceJson');
      return this.revision;
    }
    this.revision++;
    this.callbacks.pushSurfaceJson(surfaceJson, this.revision);
    return this.revision;
  }

  pushCanonicalSurface(surface: UiCanonicalSurface): number {
    const legacy = new LegacyA2uiSurfaceAdapter().toLegacy(surface);
    return this.pushSurfaceJson(JSON.stringify(legacy));
  }

  diagnostic(code: string, detail: string): void {
    this.callbacks.pushDiagnostic(code, detail);
  }

  currentRevision(): number {
    return this.revision;
  }

  reset(): void {
    this.revision = 0;
  }
}
