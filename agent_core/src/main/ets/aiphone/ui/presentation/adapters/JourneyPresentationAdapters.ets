import {
  envelopeFor,
  numberAt,
  objectArrayAt,
  stringAt,
  UiPresentationAdapter
} from '../UiPresentationAdapter';
import {
  UiJourneyOption,
  UiJourneyOptionCollection,
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource,
  UiPriceValue
} from '../UiPresentationTypes';

interface JourneyMapping {
  sourceSchemaRef: string;
  adapterId: string;
  kind: 'train' | 'flight' | 'bus' | 'mixed';
  itemsPath: string;
  idPath: string;
  titlePath: string;
  originPath: string;
  destinationPath: string;
  departAtPath: string;
  arriveAtPath: string;
  durationPath?: string;
  pricePath?: string;
  currencyPath?: string;
}

class MappedJourneyAdapter implements UiPresentationAdapter {
  private readonly mapping: JourneyMapping;

  constructor(mapping: JourneyMapping) {
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
    const items: UiJourneyOption[] = [];
    objectArrayAt(source.data, this.mapping.itemsPath).forEach((record: Object): void => {
      const id = stringAt(record, this.mapping.idPath);
      const origin = stringAt(record, this.mapping.originPath);
      const destination = stringAt(record, this.mapping.destinationPath);
      const departAt = stringAt(record, this.mapping.departAtPath);
      const arriveAt = stringAt(record, this.mapping.arriveAtPath);
      if (id === null || origin === null || destination === null || departAt === null || arriveAt === null) return;
      const item: UiJourneyOption = {
        id,
        kind: this.mapping.kind,
        title: stringAt(record, this.mapping.titlePath) ?? (origin + ' → ' + destination),
        origin,
        destination,
        departAt,
        arriveAt,
        actionRefs: context.actionRefsByItemId.get(id)
      };
      if (this.mapping.durationPath !== undefined) item.duration = stringAt(record, this.mapping.durationPath) ?? undefined;
      if (this.mapping.pricePath !== undefined) {
        const amount = numberAt(record, this.mapping.pricePath);
        const currency = this.mapping.currencyPath === undefined ? null : stringAt(record, this.mapping.currencyPath);
        if (amount !== null && currency !== null && currency.length > 0) {
          const price: UiPriceValue = { amount, currency };
          item.price = price;
        }
      }
      items.push(item);
    });
    const model: UiJourneyOptionCollection = { schemaId: 'ui.journey-option-collection', schemaVersion: 1, items };
    return envelopeFor(this, source, 'ui.journey-option-collection', 1, model as Object);
  }
}

export function createJourneyPresentationAdapters(): UiPresentationAdapter[] {
  const common = {
    itemsPath: '/items',
    idPath: '/id',
    titlePath: '/title',
    originPath: '/origin',
    destinationPath: '/destination',
    departAtPath: '/departAt',
    arriveAtPath: '/arriveAt',
    durationPath: '/duration',
    pricePath: '/price',
    currencyPath: '/currency'
  };
  return [
    new MappedJourneyAdapter({ ...common, sourceSchemaRef: 'train-search-result.v1', adapterId: 'train-journey-adapter', kind: 'train' }),
    new MappedJourneyAdapter({ ...common, sourceSchemaRef: 'flight-search-result.v1', adapterId: 'flight-journey-adapter', kind: 'flight' }),
    new MappedJourneyAdapter({ ...common, sourceSchemaRef: 'travel-search-result.v1', adapterId: 'travel-journey-adapter', kind: 'mixed' })
  ];
}
