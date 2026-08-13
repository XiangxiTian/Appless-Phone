import {
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource
} from './UiPresentationTypes';
import { UiPresentationAdapter } from './UiPresentationAdapter';

export class UiPresentationAdapterRegistry {
  private readonly adapters: UiPresentationAdapter[] = [];

  register(adapter: UiPresentationAdapter): void {
    if (adapter.id().length === 0 || adapter.version() <= 0) {
      throw new Error('INVALID_PRESENTATION_ADAPTER');
    }
    this.adapters.push(adapter);
  }

  resolve(source: UiPresentationSource): UiPresentationAdapter | null {
    for (let index = 0; index < this.adapters.length; index++) {
      if (this.adapters[index].supports(source)) return this.adapters[index];
    }
    return null;
  }

  adapt(source: UiPresentationSource, context: UiPresentationContext): UiPresentationEnvelope {
    const adapter = this.resolve(source);
    if (adapter === null) throw new Error('PRESENTATION_ADAPTER_NOT_FOUND:' + source.outputSchemaRef);
    const output = adapter.adapt(source, context);
    if (output.viewModelType.length === 0 || output.viewModelVersion <= 0) {
      throw new Error('INVALID_PRESENTATION_VIEW_MODEL');
    }
    return output;
  }

  ids(): string[] {
    return this.adapters.map((adapter: UiPresentationAdapter): string => adapter.id());
  }
}
