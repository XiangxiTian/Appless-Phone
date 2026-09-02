import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PhoneLocalMemoryRuntime } from '../memory/PhoneLocalMemoryRuntime';
import { LegacyAccountClaimCoordinator } from './AccountSessionStore';
import {
  accountScopedPreferenceStoreBaseNames,
  accountScopedStoreName
} from './AccountStorageScope';

const ACCOUNT_MIGRATION_STORE_NAME: string = 'aiphone_account_migration_v1';
const FIRST_CLAIMANT_OWNER_KEY: string = 'first_claimant_owner_id';
const FIRST_CLAIM_COMPLETE_KEY: string = 'first_claim_complete';

/** Narrow persistence seam used to test the first-account claim protocol without ArkData. */
export interface LegacyAccountMigrationBackend {
  preferenceStore(name: string): preferences.Preferences;
  claimLegacyMemoryOwner(ownerId: string): Promise<number>;
}

class ArkDataLegacyAccountMigrationBackend implements LegacyAccountMigrationBackend {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  preferenceStore(name: string): preferences.Preferences {
    return preferences.getPreferencesSync(this.context, { name });
  }

  async claimLegacyMemoryOwner(ownerId: string): Promise<number> {
    return await new PhoneLocalMemoryRuntime(this.context, { ownerId }).claimLegacyOwner();
  }
}

function preferenceText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

/**
 * Claims pre-account local data for the first account which begins migration.
 *
 * The claimant is persisted before any copy starts. A failed attempt is therefore retried only
 * by that same account; another account can use a fresh scope but can never take the legacy data.
 */
export class DefaultLegacyAccountClaimCoordinator implements LegacyAccountClaimCoordinator {
  private readonly backend: LegacyAccountMigrationBackend;

  constructor(context: common.Context, backend?: LegacyAccountMigrationBackend) {
    this.backend = backend === undefined ? new ArkDataLegacyAccountMigrationBackend(context) : backend;
  }

  async claimLegacyDataForFirstAccountIfNeeded(ownerId: string): Promise<void> {
    const owner: string = ownerId.trim();
    if (owner.length === 0) {
      throw new Error('Cannot migrate legacy data without an account owner.');
    }
    const marker = this.backend.preferenceStore(ACCOUNT_MIGRATION_STORE_NAME);
    let claimant: string = preferenceText(marker.getSync(FIRST_CLAIMANT_OWNER_KEY, '')).trim();
    if (claimant.length === 0) {
      marker.putSync(FIRST_CLAIMANT_OWNER_KEY, owner);
      marker.putSync(FIRST_CLAIM_COMPLETE_KEY, false);
      marker.flushSync();
      claimant = owner;
    }
    if (claimant !== owner || marker.getSync(FIRST_CLAIM_COMPLETE_KEY, false) === true) {
      return;
    }

    const storeNames: string[] = accountScopedPreferenceStoreBaseNames();
    for (let index = 0; index < storeNames.length; index += 1) {
      this.copyMissingValues(storeNames[index], owner);
    }
    await this.backend.claimLegacyMemoryOwner(owner);
    marker.putSync(FIRST_CLAIM_COMPLETE_KEY, true);
    marker.flushSync();
  }

  private copyMissingValues(baseName: string, ownerId: string): void {
    const legacy = this.backend.preferenceStore(baseName);
    const scoped = this.backend.preferenceStore(accountScopedStoreName(baseName, ownerId));
    const all = legacy.getAllSync() as Record<string, preferences.ValueType>;
    const keys: string[] = Object.keys(all);
    let changed: boolean = false;
    for (let index = 0; index < keys.length; index += 1) {
      const key: string = keys[index];
      if (scoped.hasSync(key)) {
        continue;
      }
      scoped.putSync(key, all[key]);
      changed = true;
    }
    if (changed) {
      scoped.flushSync();
    }
  }
}

export function legacyAccountPreferenceStoreNames(): string[] {
  return accountScopedPreferenceStoreBaseNames();
}
