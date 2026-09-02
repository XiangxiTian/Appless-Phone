import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import {
  DefaultLegacyAccountClaimCoordinator,
  LegacyAccountMigrationBackend,
  legacyAccountPreferenceStoreNames
} from '../main/ets/account/LegacyAccountMigration';
import { accountScopedStoreName } from '../main/ets/account/AccountStorageScope';

const MARKER_STORE_NAME: string = 'aiphone_account_migration_v1';
const CLAIMANT_KEY: string = 'first_claimant_owner_id';
const COMPLETE_KEY: string = 'first_claim_complete';

class MemoryMigrationPreferences {
  private readonly values: Map<string, preferences.ValueType> = new Map<string, preferences.ValueType>();
  private readonly storeName: string;
  private readonly events: string[];
  failNextFlush: boolean = false;

  constructor(storeName: string, events: string[]) {
    this.storeName = storeName;
    this.events = events;
  }

  getSync(key: string, defaultValue: preferences.ValueType): preferences.ValueType {
    return this.values.has(key) ? this.values.get(key) as preferences.ValueType : defaultValue;
  }

  putSync(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
    this.events.push('put:' + this.storeName + ':' + key + ':' + value.toString());
  }

  hasSync(key: string): boolean {
    return this.values.has(key);
  }

  getAllSync(): Object {
    const all: Record<string, preferences.ValueType> = {};
    this.values.forEach((value: preferences.ValueType, key: string): void => {
      all[key] = value;
    });
    return all;
  }

  flushSync(): void {
    this.events.push('flush:' + this.storeName);
    if (this.failNextFlush) {
      this.failNextFlush = false;
      throw new Error('simulated preferences flush failure');
    }
  }

  seed(key: string, value: preferences.ValueType): void {
    this.values.set(key, value);
  }
}

class MemoryMigrationBackend implements LegacyAccountMigrationBackend {
  private readonly stores: Map<string, MemoryMigrationPreferences> =
    new Map<string, MemoryMigrationPreferences>();
  readonly events: string[] = [];
  readonly memoryOwners: string[] = [];
  failMemoryClaims: number = 0;

  preferenceStore(name: string): preferences.Preferences {
    this.events.push('open:' + name);
    return this.store(name) as Object as preferences.Preferences;
  }

  async claimLegacyMemoryOwner(ownerId: string): Promise<number> {
    this.events.push('memory:' + ownerId);
    this.memoryOwners.push(ownerId);
    if (this.failMemoryClaims > 0) {
      this.failMemoryClaims -= 1;
      throw new Error('simulated memory claim failure');
    }
    return 1;
  }

  store(name: string): MemoryMigrationPreferences {
    let store = this.stores.get(name);
    if (store === undefined) {
      store = new MemoryMigrationPreferences(name, this.events);
      this.stores.set(name, store);
    }
    return store;
  }
}

class FakeMigrationContext {
}

function coordinator(backend: MemoryMigrationBackend): DefaultLegacyAccountClaimCoordinator {
  return new DefaultLegacyAccountClaimCoordinator(new FakeMigrationContext() as Object as common.Context, backend);
}

async function rejects(task: Promise<void>): Promise<boolean> {
  try {
    await task;
    return false;
  } catch (_error) {
    return true;
  }
}

export default function legacyAccountMigrationTest() {
  describe('legacyAccountMigration', () => {
    it('pre-locks the first claimant and never lets another account take legacy data', 0, async () => {
      const backend = new MemoryMigrationBackend();
      backend.failMemoryClaims = 1;
      const claim = coordinator(backend);

      expect(await rejects(claim.claimLegacyDataForFirstAccountIfNeeded('owner-first'))).assertTrue();
      const marker = backend.store(MARKER_STORE_NAME);
      expect(marker.getSync(CLAIMANT_KEY, '')).assertEqual('owner-first');
      expect(marker.getSync(COMPLETE_KEY, false)).assertFalse();
      const lockFlush = backend.events.indexOf('flush:' + MARKER_STORE_NAME);
      const firstLegacyOpen = backend.events.indexOf('open:' + legacyAccountPreferenceStoreNames()[0]);
      expect(lockFlush >= 0).assertTrue();
      expect(firstLegacyOpen > lockFlush).assertTrue();

      const eventCount = backend.events.length;
      await claim.claimLegacyDataForFirstAccountIfNeeded('owner-second');
      expect(backend.memoryOwners.length).assertEqual(1);
      expect(backend.events.slice(eventCount).some((event: string): boolean =>
        event.indexOf('__owner_owner-second') >= 0
      )).assertFalse();
      expect(marker.getSync(CLAIMANT_KEY, '')).assertEqual('owner-first');
    });

    it('copies only missing preference keys and marks complete after memory claiming succeeds', 0, async () => {
      const backend = new MemoryMigrationBackend();
      const owner = 'owner-alpha';
      const baseName = legacyAccountPreferenceStoreNames()[0];
      const legacy = backend.store(baseName);
      const scoped = backend.store(accountScopedStoreName(baseName, owner));
      legacy.seed('missing', 'legacy-value');
      legacy.seed('preserved', 'legacy-should-not-win');
      scoped.seed('preserved', 'account-value');

      await coordinator(backend).claimLegacyDataForFirstAccountIfNeeded(owner);

      expect(scoped.getSync('missing', '')).assertEqual('legacy-value');
      expect(scoped.getSync('preserved', '')).assertEqual('account-value');
      expect(backend.memoryOwners.length).assertEqual(1);
      expect(backend.memoryOwners[0]).assertEqual(owner);
      const marker = backend.store(MARKER_STORE_NAME);
      expect(marker.getSync(COMPLETE_KEY, false)).assertTrue();
      const memoryIndex = backend.events.indexOf('memory:' + owner);
      const completeIndex = backend.events.indexOf('put:' + MARKER_STORE_NAME + ':' + COMPLETE_KEY + ':true');
      expect(memoryIndex >= 0).assertTrue();
      expect(completeIndex > memoryIndex).assertTrue();

      await coordinator(backend).claimLegacyDataForFirstAccountIfNeeded(owner);
      expect(backend.memoryOwners.length).assertEqual(1);
    });

    it('keeps an incomplete claim retryable only by the same owner', 0, async () => {
      const backend = new MemoryMigrationBackend();
      backend.failMemoryClaims = 1;
      const claim = coordinator(backend);

      expect(await rejects(claim.claimLegacyDataForFirstAccountIfNeeded('owner-retry'))).assertTrue();
      expect(backend.store(MARKER_STORE_NAME).getSync(COMPLETE_KEY, false)).assertFalse();

      await claim.claimLegacyDataForFirstAccountIfNeeded('owner-retry');
      expect(backend.memoryOwners.length).assertEqual(2);
      expect(backend.memoryOwners[0]).assertEqual('owner-retry');
      expect(backend.memoryOwners[1]).assertEqual('owner-retry');
      expect(backend.store(MARKER_STORE_NAME).getSync(COMPLETE_KEY, false)).assertTrue();
    });
  });
}
