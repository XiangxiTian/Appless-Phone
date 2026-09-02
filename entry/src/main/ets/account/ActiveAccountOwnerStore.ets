import { common } from '@kit.AbilityKit';
import preferences from '@ohos.data.preferences';

export const ACCOUNT_DEVICE_STATE_STORE_NAME: string = 'appless_account_device_state';
export const ACTIVE_ACCOUNT_OWNER_ID_KEY: string = 'active_owner_id';

export interface ActiveAccountOwnerStore {
  read(): string;
  write(ownerId: string): void;
  clear(): void;
}

export function isValidAccountOwnerId(ownerId: string): boolean {
  return /^[0-9a-f]{64}$/.test(ownerId);
}

function preferenceText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value.trim() : '';
}

export class PreferencesActiveAccountOwnerStore implements ActiveAccountOwnerStore {
  private readonly store: preferences.Preferences;

  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: ACCOUNT_DEVICE_STATE_STORE_NAME });
  }

  read(): string {
    const value = preferenceText(this.store.getSync(ACTIVE_ACCOUNT_OWNER_ID_KEY, ''));
    return isValidAccountOwnerId(value) ? value : '';
  }

  write(ownerId: string): void {
    if (!isValidAccountOwnerId(ownerId)) {
      throw new Error('Invalid account owner identifier');
    }
    this.store.putSync(ACTIVE_ACCOUNT_OWNER_ID_KEY, ownerId);
    this.store.flushSync();
  }

  clear(): void {
    this.store.deleteSync(ACTIVE_ACCOUNT_OWNER_ID_KEY);
    this.store.flushSync();
  }
}

export function activeAccountOwnerId(context: common.Context): string {
  try {
    return new PreferencesActiveAccountOwnerStore(context).read();
  } catch (_error) {
    return '';
  }
}
