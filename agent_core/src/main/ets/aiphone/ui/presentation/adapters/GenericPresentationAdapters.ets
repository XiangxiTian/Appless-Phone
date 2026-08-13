import {
  envelopeFor,
  objectArrayAt,
  stringAt,
  UiPresentationAdapter
} from '../UiPresentationAdapter';
import {
  UiFactValue,
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource,
  UiResultCollection,
  UiResultItem
} from '../UiPresentationTypes';

class GenericResultAdapter implements UiPresentationAdapter {
  id(): string {
    return 'generic-result-adapter';
  }

  version(): number {
    return 1;
  }

  supports(source: UiPresentationSource): boolean {
    return source.outputSchemaRef === 'generic-structured-result.v1';
  }

  adapt(source: UiPresentationSource, context: UiPresentationContext): UiPresentationEnvelope {
    const items: UiResultItem[] = [];
    objectArrayAt(source.data, '/items').forEach((record: Object, index: number): void => {
      const id = stringAt(record, '/id') ?? stringAt(record, '/key') ?? ('result-' + index.toString());
      const title = stringAt(record, '/title');
      if (title === null || title.length === 0) return;
      const item: UiResultItem = {
        id,
        title,
        summary: stringAt(record, '/summary') ?? undefined,
        actionRefs: context.actionRefsByItemId.get(id)
      };
      const fields: UiFactValue[] = [];
      Object.keys(record).forEach((key: string): void => {
        if (key === 'id' || key === 'key' || key === 'title' || key === 'summary') return;
        const value = stringAt(record, '/' + key.replace(/~/g, '~0').replace(/\//g, '~1'));
        if (value !== null) fields.push({ label: key, value });
      });
      if (fields.length > 0) item.fields = fields;
      items.push(item);
    });
    const model: UiResultCollection = { schemaId: 'ui.result-collection', schemaVersion: 1, items };
    return envelopeFor(this, source, 'ui.result-collection', 1, model as Object);
  }
}

export function createGenericPresentationAdapters(): UiPresentationAdapter[] {
  return [new GenericResultAdapter()];
}
