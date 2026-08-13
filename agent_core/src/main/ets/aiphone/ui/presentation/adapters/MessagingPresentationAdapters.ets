import {
  envelopeFor,
  objectArrayAt,
  stringAt,
  UiPresentationAdapter
} from '../UiPresentationAdapter';
import {
  UiMessageFeed,
  UiMessageItem,
  UiPresentationContext,
  UiPresentationEnvelope,
  UiPresentationSource
} from '../UiPresentationTypes';

interface MessageMapping {
  sourceSchemaRef: string;
  adapterId: string;
  senderPath: string;
  previewPath: string;
  subjectPath?: string;
  timestampPath?: string;
}

class MappedMessageAdapter implements UiPresentationAdapter {
  private readonly mapping: MessageMapping;

  constructor(mapping: MessageMapping) {
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
    const items: UiMessageItem[] = [];
    objectArrayAt(source.data, '/items').forEach((record: Object, index: number): void => {
      const id = stringAt(record, '/id') ?? stringAt(record, '/messageId') ?? ('message-' + index.toString());
      const sender = stringAt(record, this.mapping.senderPath);
      const preview = stringAt(record, this.mapping.previewPath);
      if (sender === null || preview === null) return;
      const item: UiMessageItem = { id, sender, preview, actionRefs: context.actionRefsByItemId.get(id) };
      if (this.mapping.subjectPath !== undefined) item.subject = stringAt(record, this.mapping.subjectPath) ?? undefined;
      if (this.mapping.timestampPath !== undefined) item.timestamp = stringAt(record, this.mapping.timestampPath) ?? undefined;
      items.push(item);
    });
    const model: UiMessageFeed = { schemaId: 'ui.message-feed', schemaVersion: 1, items };
    return envelopeFor(this, source, 'ui.message-feed', 1, model as Object);
  }
}

export function createMessagingPresentationAdapters(): UiPresentationAdapter[] {
  return [
    new MappedMessageAdapter({
      sourceSchemaRef: 'mail-search-result.v1',
      adapterId: 'mail-message-adapter',
      senderPath: '/sender',
      previewPath: '/preview',
      subjectPath: '/subject',
      timestampPath: '/timestamp'
    }),
    new MappedMessageAdapter({
      sourceSchemaRef: 'social-feed-result.v1',
      adapterId: 'social-message-adapter',
      senderPath: '/author',
      previewPath: '/text',
      timestampPath: '/createdAt'
    })
  ];
}
