import {
  envelopeFor,
  numberAt,
  objectArrayAt,
  stringAt,
  UiPresentationAdapter
} from '../UiPresentationAdapter';
import {
  UiOptionCollection,
  UiOptionItem,
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource
} from '../UiPresentationTypes';

interface UiOptionMapping {
  sourceSchemaRef: string;
  adapterId: string;
  kind: string;
  itemsPath: string;
  idPath: string;
  titlePath: string;
  subtitlePath?: string;
  descriptionPath?: string;
}

class MappedOptionAdapter implements UiPresentationAdapter {
  private readonly mapping: UiOptionMapping;

  constructor(mapping: UiOptionMapping) {
    this.mapping = mapping;
  }

  id(): string {
    return this.mapping.adapterId;
  }

  version(): number {
    return 1;
  }

  supports(source: UiPresentationSource): boolean {
    return source.outputSchemaRef === this.mapping.sourceSchemaRef;
  }

  adapt(source: UiPresentationSource, context: UiPresentationContext): UiPresentationEnvelope {
    const records = objectArrayAt(source.data, this.mapping.itemsPath);
    const items: UiOptionItem[] = [];
    records.forEach((record: Object, index: number): void => {
      const id = stringAt(record, this.mapping.idPath);
      const title = stringAt(record, this.mapping.titlePath);
      if (id === null || title === null || id.length === 0 || title.length === 0) return;
      const item: UiOptionItem = {
        id,
        kind: this.mapping.kind,
        title,
        actionRefs: context.actionRefsByItemId.get(id)
      };
      if (this.mapping.subtitlePath !== undefined) item.subtitle = stringAt(record, this.mapping.subtitlePath) ?? undefined;
      if (this.mapping.descriptionPath !== undefined) item.description = stringAt(record, this.mapping.descriptionPath) ?? undefined;
      const amount = numberAt(record, '/price');
      const currency = stringAt(record, '/currency');
      if (amount !== null && currency !== null && currency.length > 0) item.price = { amount, currency };
      items.push(item);
    });
    const model: UiOptionCollection = {
      schemaId: 'ui.option-collection',
      schemaVersion: 1,
      items
    };
    return envelopeFor(this, source, 'ui.option-collection', 1, model as Object);
  }
}

export function createChoicePresentationAdapters(): UiPresentationAdapter[] {
  return [
    new MappedOptionAdapter({
      sourceSchemaRef: 'restaurant-search-result.v1',
      adapterId: 'food-option-adapter',
      kind: 'restaurant',
      itemsPath: '/items',
      idPath: '/shop_id',
      titlePath: '/shop_name',
      subtitlePath: '/score',
      descriptionPath: '/address'
    }),
    new MappedOptionAdapter({
      sourceSchemaRef: 'hotel-search-result.v1',
      adapterId: 'hotel-option-adapter',
      kind: 'hotel',
      itemsPath: '/items',
      idPath: '/hotelCode',
      titlePath: '/displayName',
      subtitlePath: '/starRating',
      descriptionPath: '/address'
    }),
    new MappedOptionAdapter({
      sourceSchemaRef: 'product-search-result.v1',
      adapterId: 'product-option-adapter',
      kind: 'product',
      itemsPath: '/items',
      idPath: '/sku',
      titlePath: '/title',
      subtitlePath: '/inventoryStatus'
    })
  ];
}
