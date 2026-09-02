import { common } from '@kit.AbilityKit';
import { AssetCredentialStore, CredentialStore } from '@loop/agent-core';
import {
  AccountSessionSnapshot,
  AccountSessionStatus,
  emptyAccountSessionSnapshot
} from './AccountModels';
import {
  AccountKitHuaweiAccountService,
  HuaweiAccountIdentity,
  HuaweiAccountProfile,
  HuaweiAccountPublicError,
  HuaweiAccountService,
  HuaweiAuthorizationState,
  missingHuaweiClientIdMessage
} from './HuaweiAccountService';
import { deriveHuaweiOwnerId } from './OwnerId';
import {
  ActiveAccountOwnerStore,
  PreferencesActiveAccountOwnerStore
} from './ActiveAccountOwnerStore';
import {
  AccountProfileSink,
  PreferencesAccountProfileSink
} from './AccountProfileStore';

export const HUAWEI_UNION_ID_CREDENTIAL_REF: string = 'account:huawei:union-id:v1';

export interface LegacyAccountClaimCoordinator {
  claimLegacyDataForFirstAccountIfNeeded(ownerId: string): Promise<void>;
}

class NoopLegacyAccountClaimCoordinator implements LegacyAccountClaimCoordinator {
  async claimLegacyDataForFirstAccountIfNeeded(_ownerId: string): Promise<void> {
  }
}

class NoopActiveAccountOwnerStore implements ActiveAccountOwnerStore {
  read(): string {
    return '';
  }

  write(_ownerId: string): void {
  }

  clear(): void {
  }
}

class NoopAccountProfileSink implements AccountProfileSink {
  recordAuthorized(_ownerId: string, _profile: HuaweiAccountProfile): void {
  }

  recordUnavailable(_ownerId: string): void {
  }
}

function copySnapshot(snapshot: AccountSessionSnapshot): AccountSessionSnapshot {
  return {
    status: snapshot.status,
    ownerId: snapshot.ownerId,
    errorMessage: snapshot.errorMessage
  };
}

export class AccountSessionStore {
  private readonly accountService: HuaweiAccountService;
  private readonly credentialStore: CredentialStore;
  private readonly clientId: string;
  private readonly legacyClaimCoordinator: LegacyAccountClaimCoordinator;
  private readonly activeOwnerStore: ActiveAccountOwnerStore;
  private readonly accountProfileSink: AccountProfileSink;
  private snapshotValue: AccountSessionSnapshot = emptyAccountSessionSnapshot();

  constructor(
    accountService: HuaweiAccountService,
    credentialStore: CredentialStore,
    clientId: string,
    legacyClaimCoordinator?: LegacyAccountClaimCoordinator,
    activeOwnerStore?: ActiveAccountOwnerStore,
    accountProfileSink?: AccountProfileSink
  ) {
    this.accountService = accountService;
    this.credentialStore = credentialStore;
    this.clientId = clientId;
    this.legacyClaimCoordinator = legacyClaimCoordinator === undefined ?
      new NoopLegacyAccountClaimCoordinator() : legacyClaimCoordinator;
    this.activeOwnerStore = activeOwnerStore === undefined ? new NoopActiveAccountOwnerStore() : activeOwnerStore;
    this.accountProfileSink = accountProfileSink === undefined ? new NoopAccountProfileSink() : accountProfileSink;
  }

  snapshot(): AccountSessionSnapshot {
    return copySnapshot(this.snapshotValue);
  }

  currentOwnerId(): string {
    return this.snapshotValue.status === AccountSessionStatus.AUTHENTICATED ? this.snapshotValue.ownerId : '';
  }

  isAuthenticated(): boolean {
    return this.currentOwnerId().length > 0;
  }

  async restore(): Promise<AccountSessionSnapshot> {
    this.setSnapshot(AccountSessionStatus.RESTORING, '', '');
    try {
      this.activeOwnerStore.clear();
      const storedUnionId = await this.credentialStore.get(HUAWEI_UNION_ID_CREDENTIAL_REF);
      if (storedUnionId.length === 0) {
        return this.setSnapshot(AccountSessionStatus.SIGNED_OUT, '', '');
      }

      const authorization = await this.accountService.getAuthorizationState(storedUnionId);
      if (authorization === HuaweiAuthorizationState.UNLOGGED_IN) {
        return this.setSnapshot(AccountSessionStatus.SIGNED_OUT, '', '');
      }
      if (authorization === HuaweiAuthorizationState.UNAUTHORIZED) {
        return this.setSnapshot(AccountSessionStatus.ACCOUNT_MISMATCH, '',
          '已保存的华为账号授权已失效或账号已变更，请重新登录。');
      }
      return await this.activate({ unionId: storedUnionId });
    } catch (error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', this.publicErrorMessage(error,
        '账号状态恢复失败，请稍后重试。'));
    }
  }

  async login(): Promise<AccountSessionSnapshot> {
    if (this.clientId.trim().length === 0) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', missingHuaweiClientIdMessage());
    }
    try {
      const identity = await this.accountService.login(this.clientId);
      await this.credentialStore.put(HUAWEI_UNION_ID_CREDENTIAL_REF, identity.unionId);
      const ownerId = deriveHuaweiOwnerId(identity.unionId);
      await this.captureProfileBestEffort(identity, ownerId);
      return await this.activate(identity);
    } catch (error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', this.publicErrorMessage(error,
        '华为账号登录失败，请稍后重试。'));
    }
  }

  async clearLocalSession(): Promise<AccountSessionSnapshot> {
    try {
      await this.credentialStore.remove(HUAWEI_UNION_ID_CREDENTIAL_REF);
    } catch (_error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', '本地账号状态清理失败，请稍后重试。');
    }
    try {
      this.activeOwnerStore.clear();
    } catch (_error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', '本地账号状态清理失败，请稍后重试。');
    }
    return this.setSnapshot(AccountSessionStatus.SIGNED_OUT, '', '');
  }

  private async activate(identity: HuaweiAccountIdentity): Promise<AccountSessionSnapshot> {
    const ownerId = deriveHuaweiOwnerId(identity.unionId);
    await this.legacyClaimCoordinator.claimLegacyDataForFirstAccountIfNeeded(ownerId);
    this.activeOwnerStore.write(ownerId);
    return this.setSnapshot(AccountSessionStatus.AUTHENTICATED, ownerId, '');
  }

  private async captureProfileBestEffort(identity: HuaweiAccountIdentity, ownerId: string): Promise<void> {
    try {
      const profile = await this.accountService.authorizeProfile(identity.unionId);
      this.accountProfileSink.recordAuthorized(ownerId, profile);
    } catch (_error) {
      try {
        this.accountProfileSink.recordUnavailable(ownerId);
      } catch (_storeError) {
      }
    }
  }

  private publicErrorMessage(
    error: Error | Object | string | number | boolean | null | undefined,
    fallback: string
  ): string {
    if (error instanceof HuaweiAccountPublicError) {
      return error.message;
    }
    return fallback;
  }

  private setSnapshot(status: AccountSessionStatus, ownerId: string, errorMessage: string): AccountSessionSnapshot {
    this.snapshotValue = { status: status, ownerId: ownerId, errorMessage: errorMessage };
    return this.snapshot();
  }
}

let globalAccountSessionStore: AccountSessionStore | null = null;

export function createDefaultAccountSessionStore(
  context: common.Context,
  clientId: string,
  legacyClaimCoordinator?: LegacyAccountClaimCoordinator
): AccountSessionStore {
  return new AccountSessionStore(
    new AccountKitHuaweiAccountService(context),
    new AssetCredentialStore(),
    clientId,
    legacyClaimCoordinator,
    new PreferencesActiveAccountOwnerStore(context),
    new PreferencesAccountProfileSink(context)
  );
}

export function installGlobalAccountSessionStore(store: AccountSessionStore): void {
  globalAccountSessionStore = store;
}

export function requireGlobalAccountSessionStore(): AccountSessionStore {
  if (globalAccountSessionStore === null) {
    throw new Error('Global account session store has not been installed');
  }
  return globalAccountSessionStore;
}

export function resetGlobalAccountSessionStoreForTesting(): void {
  globalAccountSessionStore = null;
}
