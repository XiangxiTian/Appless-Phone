import { describe, expect, it } from '@ohos/hypium';
import {
  createDefaultUiPresentationAdapterRegistry,
  createDefaultUiPresentationSchemaRegistry,
  UiPresentationContext,
  UiPresentationSource
} from '@loop/agent-core';

function source(schema: string, data: Object): UiPresentationSource {
  return {
    toolId: 'test.tool', outputSchemaRef: schema, provider: 'test-provider',
    data, surfaceId: 'presentation-surface', runId: 'presentation-run'
  };
}

const context: UiPresentationContext = { actionRefsByItemId: new Map<string, string[]>([['item-1', ['offer-1']]]) };

export default function uiV4PresentationTest(): void {
  describe('UiV4Presentation', (): void => {
    it('maps train, flight and travel results to one journey schema', 0, (): void => {
      const registry = createDefaultUiPresentationAdapterRegistry();
      const data = { items: [{ id: 'item-1', title: 'G 1', origin: 'SZ', destination: 'GZ',
        departAt: '09:00', arriveAt: '10:00', currency: 'CNY', price: 100 }] };
      ['train-search-result.v1', 'flight-search-result.v1', 'travel-search-result.v1'].forEach((schema: string): void => {
        const output = registry.adapt(source(schema, data), context);
        expect(output.viewModelType).assertEqual('ui.journey-option-collection');
        expect(output.provenance.toolId).assertEqual('test.tool');
        expect(((output.data as Record<string, Object>)['items'] as Object[]).length).assertEqual(1);
        const actionRefs = (((output.data as Record<string, Object>)['items'] as Object[])[0] as Record<string, Object>)['actionRefs'] as string[];
        expect(actionRefs[0]).assertEqual('offer-1');
      });
    });

    it('maps mail and social results to message feed without inventing content', 0, (): void => {
      const registry = createDefaultUiPresentationAdapterRegistry();
      const mail = registry.adapt(source('mail-search-result.v1', {
        items: [{ id: 'item-1', sender: 'A', subject: 'Hello', preview: 'Preview' }]
      }), context);
      expect(mail.viewModelType).assertEqual('ui.message-feed');
      const social = registry.adapt(source('social-feed-result.v1', {
        items: [{ id: 'item-1', author: 'A' }]
      }), context);
      expect(((social.data as Record<string, Object>)['items'] as Object[]).length).assertEqual(0);
    });

    it('maps generic structured results only through the known fallback schema', 0, (): void => {
      const registry = createDefaultUiPresentationAdapterRegistry();
      const output = registry.adapt(source('generic-structured-result.v1', {
        items: [{ id: 'item-1', title: 'Known', extra: 'value' }, { id: 'item-2' }]
      }), context);
      expect(output.viewModelType).assertEqual('ui.result-collection');
      expect(output.provenance.adapterId).assertEqual('generic-result-adapter');
      expect(((output.data as Record<string, Object>)['items'] as Object[]).length).assertEqual(1);
    });

    it('keeps the presentation schema registry explicit and versioned', 0, (): void => {
      const schemas = createDefaultUiPresentationSchemaRegistry();
      expect(schemas.allows('ui.option-collection', '/items/0/title')).assertTrue();
      expect(schemas.allows('ui.option-collection', '/rawProviderPayload')).assertFalse();
      expect(schemas.resolve('ui.form-model')?.schemaVersion).assertEqual(1);
    });
  });
}
