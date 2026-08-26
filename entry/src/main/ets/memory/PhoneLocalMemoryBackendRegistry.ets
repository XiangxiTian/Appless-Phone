import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';

export type PhoneLocalMemoryBackendId = 'vector' | 'blob';

export const PHONE_LOCAL_MEMORY_BACKEND_REGISTRY_DB_NAME: string =
  'pocketagent_conversation_memory_backend_v1.db';
export const PHONE_LOCAL_MEMORY_BACKEND_MARKER_KEY: string = 'selected_backend';
export const PHONE_LOCAL_MEMORY_BACKEND_REGISTRY_SCHEMA_SQL: string =
  'CREATE TABLE IF NOT EXISTS conversation_memory_backend_registry (' +
    'metadata_key TEXT PRIMARY KEY, metadata_value TEXT NOT NULL, updated_at INTEGER NOT NULL)';

export interface PhoneLocalMemoryBackendRegistryPort {
  getSelectedBackend(): Promise<PhoneLocalMemoryBackendId | null>;
  setSelectedBackend(backendId: PhoneLocalMemoryBackendId): Promise<void>;
}

export class ArkDataPhoneLocalMemoryBackendRegistry implements PhoneLocalMemoryBackendRegistryPort {
  private context: common.Context;
  private store: relationalStore.RdbStore | null = null;
  private initializing: Promise<void> | null = null;

  constructor(context: common.Context) {
    this.context = context;
  }

  private async initialize(): Promise<void> {
    if (this.store !== null) return;
    if (this.initializing !== null) return this.initializing;
    this.initializing = this.open();
    try {
      await this.initializing;
    } finally {
      this.initializing = null;
    }
  }

  private async open(): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: PHONE_LOCAL_MEMORY_BACKEND_REGISTRY_DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const opened = await relationalStore.getRdbStore(this.context, config);
    await opened.execute(PHONE_LOCAL_MEMORY_BACKEND_REGISTRY_SCHEMA_SQL);
    this.store = opened;
  }

  private async readyStore(): Promise<relationalStore.RdbStore> {
    await this.initialize();
    if (this.store === null) throw new Error('Memory backend registry did not initialize.');
    return this.store;
  }

  async getSelectedBackend(): Promise<PhoneLocalMemoryBackendId | null> {
    const result = await (await this.readyStore()).querySql(
      'SELECT metadata_value FROM conversation_memory_backend_registry ' +
      'WHERE metadata_key = ? LIMIT 1', [PHONE_LOCAL_MEMORY_BACKEND_MARKER_KEY]
    );
    try {
      if (!result.goToFirstRow()) return null;
      const value = result.getString(result.getColumnIndex('metadata_value'));
      return value === 'vector' || value === 'blob' ? value : null;
    } finally {
      result.close();
    }
  }

  async setSelectedBackend(backendId: PhoneLocalMemoryBackendId): Promise<void> {
    await this.setValue(PHONE_LOCAL_MEMORY_BACKEND_MARKER_KEY, backendId);
  }

  private async setValue(key: string, value: string): Promise<void> {
    const store = await this.readyStore();
    try {
      await store.execute(
        'INSERT OR REPLACE INTO conversation_memory_backend_registry ' +
        '(metadata_key, metadata_value, updated_at) VALUES (?, ?, ?)',
        [key, value, Date.now()]
      );
    } catch (error) {
      throw error instanceof Error ? error : new Error('Memory backend marker write failed.');
    }
  }
}
