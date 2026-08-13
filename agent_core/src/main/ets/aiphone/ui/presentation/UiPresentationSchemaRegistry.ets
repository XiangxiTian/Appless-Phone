export interface UiPresentationSchema {
  schemaId: string;
  schemaVersion: number;
  allowedPaths: string[];
}

export class UiPresentationSchemaRegistry {
  private readonly schemas: Map<string, UiPresentationSchema> = new Map<string, UiPresentationSchema>();

  register(schema: UiPresentationSchema): void {
    if (schema.schemaId.length === 0 || schema.schemaVersion <= 0) {
      throw new Error('INVALID_PRESENTATION_SCHEMA');
    }
    this.schemas.set(schema.schemaId, {
      schemaId: schema.schemaId,
      schemaVersion: schema.schemaVersion,
      allowedPaths: schema.allowedPaths.slice()
    });
  }

  resolve(schemaId: string): UiPresentationSchema | null {
    const schema = this.schemas.get(schemaId);
    return schema === undefined ? null : {
      schemaId: schema.schemaId,
      schemaVersion: schema.schemaVersion,
      allowedPaths: schema.allowedPaths.slice()
    };
  }

  allows(schemaId: string, path: string): boolean {
    const schema = this.schemas.get(schemaId);
    if (schema === undefined || path.length === 0 || path.charAt(0) !== '/') return false;
    return schema.allowedPaths.some((allowed: string): boolean => {
      return path === allowed || path.startsWith(allowed + '/');
    });
  }

  ids(): string[] {
    return Array.from(this.schemas.keys()).sort();
  }
}

export function createDefaultUiPresentationSchemaRegistry(): UiPresentationSchemaRegistry {
  const registry = new UiPresentationSchemaRegistry();
  registry.register({ schemaId: 'ui.option-collection', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.journey-option-collection', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.result-collection', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.key-value-group', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.message-feed', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.message-thread', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.timeline', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.metric-grid', schemaVersion: 1, allowedPaths: ['/items'] });
  registry.register({ schemaId: 'ui.form-model', schemaVersion: 1, allowedPaths: ['/fields'] });
  registry.register({ schemaId: 'ui.approval-model', schemaVersion: 1, allowedPaths: ['/summary', '/consequences'] });
  registry.register({ schemaId: 'ui.status-value', schemaVersion: 1, allowedPaths: ['/code', '/label', '/tone'] });
  return registry;
}
