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
    it('invalidates pre-MBTI v3 caches and preserves inference separately from tags', 0, () => {
      const native = new MemoryPreferences();
      const store = new MemoryOverviewCacheStore(native as Object as preferences.Preferences);
      const entry: MemoryOverviewCacheEntry = {
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 123,
        evidenceFingerprint: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        overview: {
          title: '关于你', summary: '喜欢咖啡', tagList: ['咖啡迷'],
          mbtiType: 'INTP', mbtiConfidence: 68,
          claims: [{ category: 'interests', heading: '偏好', body: '喜欢咖啡', evidenceMemoryIds: ['memory-1'] }]
        }
      };
      expect(store.save(entry)?.overview.claims[0].category).assertEqual('interests');
      entry.overview.tagList[0] = '已改变';
      entry.overview.mbtiType = 'ENFP';
      entry.overview.mbtiConfidence = 90;
      expect(store.load()?.overview.tagList[0]).assertEqual('咖啡迷');
      expect(store.load()?.overview.mbtiType).assertEqual('INTP');
      expect(store.load()?.overview.mbtiConfidence).assertEqual(68);
      entry.overview.mbtiConfidence = 101;
      expect(store.save(entry)?.overview.mbtiType).assertEqual('');
      expect(store.load()?.overview.mbtiConfidence).assertEqual(0);
      entry.schemaVersion = 3;
      native.putSync(MEMORY_OVERVIEW_CACHE_KEY, JSON.stringify(entry));
      expect(store.load()).assertNull();
    });

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
          mbtiType: '', mbtiConfidence: 0,
          tagList: [], claims: [{ category: 'interests', heading: '偏好', body: '喜欢咖啡', evidenceMemoryIds: ['memory-1'] }]
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
          mbtiType: '', mbtiConfidence: 0,
          tagList: [], claims: [{ category: 'interests', heading: '偏好', body: '喜欢咖啡', evidenceMemoryIds: ['memory-1'] }]
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

    it('persists a claim with more than 24 evidence IDs', 0, () => {
      const native = new MemoryPreferences();
      const store = new MemoryOverviewCacheStore(native as Object as preferences.Preferences);
      const ids: string[] = [];
      for (let position = 0; position < 25; position += 1) ids.push('memory-' + position.toString());
      const saved = store.save({
        schemaVersion: MEMORY_OVERVIEW_CACHE_SCHEMA_VERSION,
        promptVersion: MEMORY_OVERVIEW_PROMPT_VERSION,
        outputSchemaVersion: MEMORY_OVERVIEW_OUTPUT_SCHEMA_VERSION,
        generatedAt: 123,
        evidenceFingerprint: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        overview: {
          title: '长期记忆', summary: '概览',
          mbtiType: '', mbtiConfidence: 0,
          tagList: [], claims: [{ category: 'interests', heading: '偏好', body: '很多依据', evidenceMemoryIds: ids }]
        }
      });
      expect(saved?.overview.claims[0].evidenceMemoryIds.length).assertEqual(25);
    });
  });
}
