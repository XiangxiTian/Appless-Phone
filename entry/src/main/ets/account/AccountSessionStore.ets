import { AgcCloudAccountService, CloudAccountService, CloudAccountIdentity, validatedPhone, validatedPhoneCode } from './CloudAccountService';
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
import { deriveHuaweiOwnerId, deriveCloudOwnerId } from './OwnerId';
import {
  ActiveAccountOwnerStore,
  PreferencesActiveAccountOwnerStore
} from './ActiveAccountOwnerStore';
import {
  AccountProfileSink,
  PreferencesAccountProfileSink
} from './AccountProfileStore';

const CLOUD_UID_CREDENTIAL_REF: string = 'account:agc:uid:v1';
const CLOUD_OWNER_PREFIX: string = 'account:agc:owner:v1:';
const PHONE_LOGIN_HINT_PREFIX: string = 'account:phone-hint:v1:';

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
  private readonly cloudService: CloudAccountService | null;
  private accountOperation: Promise<void> = Promise.resolve();
  private snapshotValue: AccountSessionSnapshot = emptyAccountSessionSnapshot();

  constructor(
    accountService: HuaweiAccountService,
    credentialStore: CredentialStore,
    clientId: string,
    legacyClaimCoordinator?: LegacyAccountClaimCoordinator,
    activeOwnerStore?: ActiveAccountOwnerStore,
    accountProfileSink?: AccountProfileSink,
    cloudService?: CloudAccountService
  ) {
    this.cloudService = cloudService === undefined ? null : cloudService;
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

  private runAccountOperation(action: () => Promise<AccountSessionSnapshot>): Promise<AccountSessionSnapshot> {
    const result = this.accountOperation.then(action);
    this.accountOperation = result.then((): void => {}, (_error: Error): void => {});
    return result;
  }

  restore(): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(() => this.restoreSession());
  }

  private async restoreSession(): Promise<AccountSessionSnapshot> {
    this.setSnapshot(AccountSessionStatus.RESTORING, '', '');
    try {
      this.activeOwnerStore.clear();
      const storedCloudUid = await this.credentialStore.get(CLOUD_UID_CREDENTIAL_REF);
      if (storedCloudUid.length > 0) {
        const identity = await this.cloud().restore();
        if (identity === null || identity.uid !== storedCloudUid) {
          return this.setSnapshot(AccountSessionStatus.ACCOUNT_MISMATCH, '', '登录已失效，请重新登录。');
        }
        return await this.activateCloud(identity);
      }
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

  login(): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(() => this.loginHuawei());
  }

  private async loginHuawei(): Promise<AccountSessionSnapshot> {
    if (this.clientId.trim().length === 0) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', missingHuaweiClientIdMessage());
    }
    try {
      const identity = await this.accountService.login(this.clientId);
      await this.clearCloudSessionBestEffort();
      await this.credentialStore.put(HUAWEI_UNION_ID_CREDENTIAL_REF, identity.unionId);
      await this.credentialStore.remove(CLOUD_UID_CREDENTIAL_REF);
      const ownerId = deriveHuaweiOwnerId(identity.unionId);
      await this.captureProfileBestEffort(identity, ownerId);
      return await this.activate(identity);
    } catch (error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', this.publicErrorMessage(error,
        '华为账号登录失败，请稍后重试。'));
    }
  }

  clearLocalSession(): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(() => this.clearSession());
  }

  private async clearCloudSessionBestEffort(): Promise<void> {
    try {
      if (this.cloudService !== null) await this.cloudService.signOut();
    } catch (_error) {
      // Provider cleanup must not block local logout or an independently verified Huawei login.
    }
  }

  private async clearSession(): Promise<AccountSessionSnapshot> {
    await this.clearCloudSessionBestEffort();
    try {
      await this.credentialStore.remove(HUAWEI_UNION_ID_CREDENTIAL_REF);
      await this.credentialStore.remove(CLOUD_UID_CREDENTIAL_REF);
    } catch (_error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '', '本地账号状态清理失败，请稍后重试。');
    }
    try {
      this.activeOwnerStore.clear();
    } catch (_error) {
    }
    return this.setSnapshot(AccountSessionStatus.SIGNED_OUT, '', '');
  }

  private cloud(): CloudAccountService {
    if (this.cloudService === null) throw new HuaweiAccountPublicError('手机号登录暂不可用，请使用华为账号。');
    return this.cloudService;
  }

  async requestPhoneCode(phone: string): Promise<number> {
    try { return await this.cloud().requestPhoneCode(validatedPhone(phone)); } catch (error) {
      throw new HuaweiAccountPublicError(this.publicErrorMessage(error, '验证码发送失败，请稍后重试。'));
    }
  }

  async loginPhone(phone: string, code: string): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(async (): Promise<AccountSessionSnapshot> => {
      const snapshot = await this.cloudLogin(async (): Promise<CloudAccountIdentity> =>
        this.cloud().loginPhone(validatedPhone(phone), validatedPhoneCode(code)));
      if (snapshot.status === AccountSessionStatus.AUTHENTICATED) {
        await this.rememberPhoneLoginHint(snapshot.ownerId, phone);
      }
      return snapshot;
    });
  }

  async phoneLoginHint(): Promise<string> {
    const ownerId = this.currentOwnerId();
    if (ownerId.length === 0) return '';
    try {
      const hint = await this.credentialStore.get(PHONE_LOGIN_HINT_PREFIX + ownerId);
      return /^1[3-9][0-9]\*{4}[0-9]{4}$/.test(hint) ? hint : '';
    } catch (_error) { return ''; }
  }

  private async rememberPhoneLoginHint(ownerId: string, phone: string): Promise<void> {
    // Display only: this hint never resolves an owner or authorizes login/linking.
    try {
      const normalized = validatedPhone(phone);
      await this.credentialStore.put(PHONE_LOGIN_HINT_PREFIX + ownerId,
        normalized.slice(0, 3) + '****' + normalized.slice(-4));
    } catch (_error) {}
  }

  async loginWechat(): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(() => this.cloudLogin(async (): Promise<CloudAccountIdentity> => this.cloud().loginWechat()));
  }

  private async cloudLogin(action: () => Promise<CloudAccountIdentity>): Promise<AccountSessionSnapshot> {
    try {
      this.activeOwnerStore.clear();
      this.setSnapshot(AccountSessionStatus.SIGNED_OUT, '', '');
      return await this.activateCloud(await action());
    } catch (error) {
      return this.setSnapshot(AccountSessionStatus.ERROR, '',
        this.publicErrorMessage(error, '登录失败，请检查验证码或稍后重试。'));
    }
  }

  private async cloudOwner(identity: CloudAccountIdentity): Promise<string> {
    const key = CLOUD_OWNER_PREFIX + deriveCloudOwnerId(identity.uid);
    const stored = await this.credentialStore.get(key);
    if (stored.length > 0 && !/^[a-f0-9]{64}$/.test(stored)) throw new HuaweiAccountPublicError('账号数据校验失败。');
    return stored.length > 0 ? stored : deriveCloudOwnerId(identity.uid);
  }

  private async activateCloud(identity: CloudAccountIdentity): Promise<AccountSessionSnapshot> {
    const ownerId = await this.cloudOwner(identity);
    await this.credentialStore.put(CLOUD_OWNER_PREFIX + deriveCloudOwnerId(identity.uid), ownerId);
    await this.credentialStore.put(CLOUD_UID_CREDENTIAL_REF, identity.uid);
    await this.credentialStore.remove(HUAWEI_UNION_ID_CREDENTIAL_REF);
    // New providers must not claim unowned legacy data; Huawei's existing migration stays unchanged.
    this.activeOwnerStore.write(ownerId);
    if (ownerId === deriveCloudOwnerId(identity.uid)) {
      try { this.accountProfileSink.recordAuthorized(ownerId, { nickName: identity.displayName, avatarUri: '' }); } catch (_error) {}
    }
    return this.setSnapshot(AccountSessionStatus.AUTHENTICATED, ownerId, '');
  }

  async bindPhone(phone: string, code: string): Promise<AccountSessionSnapshot> {
    const normalized = validatedPhone(phone);
    const verifiedCode = validatedPhoneCode(code);
    return this.runAccountOperation(async (): Promise<AccountSessionSnapshot> => {
      const snapshot = await this.bindCloud(async (uid: string): Promise<CloudAccountIdentity> =>
        this.cloud().linkPhone(uid, normalized, verifiedCode));
      await this.rememberPhoneLoginHint(snapshot.ownerId, normalized);
      return snapshot;
    });
  }

  async bindWechat(): Promise<AccountSessionSnapshot> {
    return this.runAccountOperation(() => this.bindCloud(async (uid: string): Promise<CloudAccountIdentity> => this.cloud().linkWechat(uid)));
  }

  private async bindCloud(action: (uid: string) => Promise<CloudAccountIdentity>): Promise<AccountSessionSnapshot> {
    const ownerId = this.currentOwnerId();
    if (ownerId.length === 0) throw new HuaweiAccountPublicError('请先登录后再绑定账号。');
    try {
      const storedUid = await this.credentialStore.get(CLOUD_UID_CREDENTIAL_REF);
      let identity: CloudAccountIdentity | null;
      if (storedUid.length > 0) {
        identity = await this.cloud().restore();
        if (identity === null || identity.uid !== storedUid) throw new HuaweiAccountPublicError('请重新登录后绑定。');
      } else {
        // Explicitly reauthenticate the device account before linking it to a cloud identity.
        const huawei = await this.accountService.login(this.clientId);
        if (deriveHuaweiOwnerId(huawei.unionId) !== ownerId) throw new HuaweiAccountPublicError('华为账号已变化，请重新登录。');
        identity = await this.cloud().loginHuawei();
        const confirmed = await this.accountService.login(this.clientId);
        if (confirmed.unionId !== huawei.unionId) throw new HuaweiAccountPublicError('华为账号已变化，请重新登录。');
      }
      const key = CLOUD_OWNER_PREFIX + deriveCloudOwnerId(identity.uid);
      const previousOwner = await this.credentialStore.get(key);
      if (previousOwner.length > 0 && previousOwner !== ownerId) {
        throw new HuaweiAccountPublicError('该账号已有独立数据，暂不支持合并，请使用原登录方式。');
      }
      // Keep this verified mapping even if the later network response is lost after a successful link.
      await this.credentialStore.put(key, ownerId);
      const linked = await action(identity.uid);
      if (linked.uid !== identity.uid) throw new HuaweiAccountPublicError('账号绑定校验失败。');
      await this.credentialStore.put(CLOUD_UID_CREDENTIAL_REF, identity.uid);
      await this.credentialStore.remove(HUAWEI_UNION_ID_CREDENTIAL_REF);
      return this.setSnapshot(AccountSessionStatus.AUTHENTICATED, ownerId, '');
    } catch (error) {
      throw new HuaweiAccountPublicError(this.publicErrorMessage(error,
        '绑定失败，请重新登录后重试。已绑定其他账号的登录方式暂不支持合并。'));
    }
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
    new PreferencesAccountProfileSink(context),
    new AgcCloudAccountService(context)
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
