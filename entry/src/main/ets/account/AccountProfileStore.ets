import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { accountScopedStoreName } from './AccountStorageScope';
import { HuaweiAccountProfile } from './HuaweiAccountService';

export const ACCOUNT_PROFILE_STORE_NAME: string = 'aiphone_account_profile';

const HUAWEI_NICK_NAME_KEY: string = 'huawei_nick_name_v1';
const CUSTOM_NAME_KEY: string = 'custom_name_v1';
const PROFILE_AUTHORIZATION_STATUS_KEY: string = 'profile_authorization_status_v1';
const PROFILE_AUTHORIZATION_UPDATED_AT_KEY: string = 'profile_authorization_updated_at_v1';
const DEFAULT_ACCOUNT_DISPLAY_NAME: string = '华为用户';

export enum AccountProfileAuthorizationStatus {
  NOT_REQUESTED = 'not_requested',
  AUTHORIZED = 'authorized',
  UNAVAILABLE = 'unavailable'
}

export interface AccountProfileSnapshot {
  huaweiNickName: string;
  customName: string;
  profileAuthorizationStatus: AccountProfileAuthorizationStatus;
  profileAuthorizationUpdatedAt: number;
}

export interface AccountProfileSink {
  recordAuthorized(ownerId: string, profile: HuaweiAccountProfile): void;
  recordUnavailable(ownerId: string): void;
}

function storedText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value.trim() : '';
}

function storedTimestamp(value: preferences.ValueType): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : 0;
}

function storedAuthorizationStatus(value: preferences.ValueType): AccountProfileAuthorizationStatus {
  const status = storedText(value);
  if (status === AccountProfileAuthorizationStatus.AUTHORIZED) {
    return AccountProfileAuthorizationStatus.AUTHORIZED;
  }
  if (status === AccountProfileAuthorizationStatus.UNAVAILABLE) {
    return AccountProfileAuthorizationStatus.UNAVAILABLE;
  }
  return AccountProfileAuthorizationStatus.NOT_REQUESTED;
}

export function emptyAccountProfileSnapshot(): AccountProfileSnapshot {
  return {
    huaweiNickName: '',
    customName: '',
    profileAuthorizationStatus: AccountProfileAuthorizationStatus.NOT_REQUESTED,
    profileAuthorizationUpdatedAt: 0
  };
}

export function effectiveAccountDisplayName(profile: AccountProfileSnapshot): string {
  const customName = profile.customName.trim();
  if (customName.length > 0) {
    return customName;
  }
  const huaweiNickName = profile.huaweiNickName.trim();
  return huaweiNickName.length > 0 ? huaweiNickName : DEFAULT_ACCOUNT_DISPLAY_NAME;
}

export class AccountProfileStore {
  private readonly store: preferences.Preferences;

  constructor(store: preferences.Preferences) {
    this.store = store;
  }

  static fromContext(context: common.Context, ownerId: string): AccountProfileStore {
    if (ownerId.trim().length === 0) {
      throw new Error('Account profile requires an authenticated owner.');
    }
    const name = accountScopedStoreName(ACCOUNT_PROFILE_STORE_NAME, ownerId);
    return new AccountProfileStore(preferences.getPreferencesSync(context, { name: name }));
  }

  load(): AccountProfileSnapshot {
    return {
      huaweiNickName: storedText(this.store.getSync(HUAWEI_NICK_NAME_KEY, '')),
      customName: storedText(this.store.getSync(CUSTOM_NAME_KEY, '')),
      profileAuthorizationStatus: storedAuthorizationStatus(
        this.store.getSync(PROFILE_AUTHORIZATION_STATUS_KEY, AccountProfileAuthorizationStatus.NOT_REQUESTED)),
      profileAuthorizationUpdatedAt: storedTimestamp(
        this.store.getSync(PROFILE_AUTHORIZATION_UPDATED_AT_KEY, 0))
    };
  }

  effectiveName(): string {
    return effectiveAccountDisplayName(this.load());
  }

  recordAuthorized(profile: HuaweiAccountProfile, updatedAt: number = Date.now()): AccountProfileSnapshot {
    this.store.putSync(HUAWEI_NICK_NAME_KEY, profile.nickName.trim());
    this.store.putSync(PROFILE_AUTHORIZATION_STATUS_KEY, AccountProfileAuthorizationStatus.AUTHORIZED);
    this.store.putSync(PROFILE_AUTHORIZATION_UPDATED_AT_KEY, Math.max(0, Math.floor(updatedAt)));
    this.store.flushSync();
    return this.load();
  }

  recordUnavailable(updatedAt: number = Date.now()): AccountProfileSnapshot {
    this.store.putSync(PROFILE_AUTHORIZATION_STATUS_KEY, AccountProfileAuthorizationStatus.UNAVAILABLE);
    this.store.putSync(PROFILE_AUTHORIZATION_UPDATED_AT_KEY, Math.max(0, Math.floor(updatedAt)));
    this.store.flushSync();
    return this.load();
  }

  setCustomName(name: string): AccountProfileSnapshot {
    const normalized = name.trim();
    if (normalized.length === 0) {
      this.store.deleteSync(CUSTOM_NAME_KEY);
    } else {
      this.store.putSync(CUSTOM_NAME_KEY, normalized);
    }
    this.store.flushSync();
    return this.load();
  }

  clearCustomName(): AccountProfileSnapshot {
    return this.setCustomName('');
  }
}

export class PreferencesAccountProfileSink implements AccountProfileSink {
  private readonly context: common.Context;

  constructor(context: common.Context) {
    this.context = context;
  }

  recordAuthorized(ownerId: string, profile: HuaweiAccountProfile): void {
    AccountProfileStore.fromContext(this.context, ownerId).recordAuthorized(profile);
  }

  recordUnavailable(ownerId: string): void {
    AccountProfileStore.fromContext(this.context, ownerId).recordUnavailable();
  }
}
