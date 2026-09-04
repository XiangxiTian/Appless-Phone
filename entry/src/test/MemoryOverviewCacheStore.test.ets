import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  MEMORY_OVERVIEW_CACHE_KEY,
  MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
  MemoryOverviewCacheEntry,
  MemoryOverviewCacheStore,
  memoryOverviewCacheStoreNameForOwner
} from '../main/ets/memory/MemoryOverviewCacheStore';
import {
  MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
  MEMORY_OVERVIEW_PROMPT_VERSION
} from '../main/ets/memory/MemoryOverview';

class MemoryPreferences {
  private readonly values: Map<string, preferences.ValueType> = new Map();

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }

  deleteSync(key: string): void {
    this.values.delete(key);
  }

  flush(): Promise<void> {
    return Promise.resolve();
  }
}

export default function memoryOverviewCacheStoreTest(): void {
  describe('MemoryOverviewCacheStore', () => {
    it('persists only the overview and evidence IDs and fails safe on malformed data', 0, () => {
      const native = new MemoryPreferences();
      const store = new MemoryOverviewCacheStore(native as Object as preferences.Preferences);
      const saved = store.save({
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 123,
        evidenceFingerprint: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        overview: {
          title: '长期记忆', summary: '概览',
          claims: [{ heading: '偏好', body: '喜欢咖啡', evidenceMemoryIds: ['memory-1'] }]
        }
      });
      expect(saved?.overview.claims[0].evidenceMemoryIds[0]).assertEqual('memory-1');
      const raw = native.getSync(MEMORY_OVERVIEW_CACHE_KEY, '') as string;
      expect(raw.indexOf('memory-1')).assertLarger(-1);
      expect(raw.indexOf('createdAt')).assertEqual(-1);
      expect(raw.indexOf('updatedAt')).assertEqual(-1);
      expect(raw.indexOf('personaTag')).assertEqual(-1);
      expect(raw.indexOf('authority')).assertEqual(-1);
      expect(raw.indexOf('0123456789abcdef')).assertLarger(-1);
      native.putSync(MEMORY_OVERVIEW_CACHE_KEY, '{');
      expect(new MemoryOverviewCacheStore(native as Object as preferences.Preferences).load()).assertNull();
    });

    it('rejects stale prompt identity and clears the persisted overview', 0, () => {
      const native = new MemoryPreferences();
      const stale: MemoryOverviewCacheEntry = {
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: 'old-prompt',
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 123,
        evidenceFingerprint: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        overview: {
          title: '长期记忆', summary: '概览',
          claims: [{ heading: '偏好', body: '喜欢咖啡', evidenceMemoryIds: ['memory-1'] }]
        }
      };
      native.putSync(MEMORY_OVERVIEW_CACHE_KEY, JSON.stringify(stale));
      const store = new MemoryOverviewCacheStore(native as Object as preferences.Preferences);
      expect(store.load()).assertNull();
      store.clear();
      expect(native.getSync(MEMORY_OVERVIEW_CACHE_KEY, '')).assertEqual('');
    });

    it('invalidates the previous cache schema that had no evidence fingerprint', 0, () => {
      const native = new MemoryPreferences();
      native.putSync(MEMORY_OVERVIEW_CACHE_KEY,
        '{"schemaVersion":1,"promptVersion":"' + MEMORY_OVERVIEW_PROMPT_VERSION + '",' +
        '"outputSchemaVersion":"' + MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION + '","generatedAt":123,' +
        '"overview":{"title":"旧概览","summary":"没有来源版本","claims":[' +
        '{"heading":"偏好","body":"旧内容","evidenceMemoryIds":["memory-1"]}]}}');
      const store = new MemoryOverviewCacheStore(native as Object as preferences.Preferences);
      expect(store.load()).assertNull();
    });

    it('derives distinct account-scoped stores for late owner mutation callbacks', 0, () => {
      const first = memoryOverviewCacheStoreNameForOwner('owner-a');
      const second = memoryOverviewCacheStoreNameForOwner('owner-b');
      expect(first === second).assertFalse();
      expect(first.indexOf('__owner_owner-a')).assertLarger(-1);
      expect(second.indexOf('__owner_owner-b')).assertLarger(-1);
    });
  });
}
