import { CloudAccountService, CloudAccountIdentity, validatedPhone } from '../main/ets/account/CloudAccountService';
import { validatedWechatCode } from '../main/ets/account/WechatAccountService';
import { describe, it, expect } from '@ohos/hypium';
import { MemoryCredentialStore } from '@loop/agent-core';
import {
  AccountSessionStore,
  HUAWEI_UNION_ID_CREDENTIAL_REF,
  LegacyAccountClaimCoordinator
} from '../main/ets/account/AccountSessionStore';
import { AccountSessionSnapshot, AccountSessionStatus } from '../main/ets/account/AccountModels';
import {
  HuaweiAccountIdentity,
  HuaweiAccountProfile,
  HuaweiAccountService,
  HuaweiAuthorizationState,
  huaweiLoginErrorMessage,
  missingHuaweiClientIdMessage,
  validateHuaweiProfileAuthorizationResponse
} from '../main/ets/account/HuaweiAccountService';
import { deriveHuaweiOwnerId } from '../main/ets/account/OwnerId';
import {
  ActiveAccountOwnerStore,
  isValidAccountOwnerId
} from '../main/ets/account/ActiveAccountOwnerStore';
import { AccountProfileSink } from '../main/ets/account/AccountProfileStore';

class FakeHuaweiAccountService implements HuaweiAccountService {
  loginIdentity: HuaweiAccountIdentity = { unionId: 'union-login' };
  authorization: HuaweiAuthorizationState = HuaweiAuthorizationState.AUTHORIZED;
  loginCalls: number = 0;
  profileCalls: number = 0;
  profileUnionIds: string[] = [];
  throwOnRestore: string = '';
  throwOnProfile: boolean = false;
  profile: HuaweiAccountProfile = { nickName: '华为昵称', avatarUri: 'avatar://huawei' };

  async login(_clientId: string): Promise<HuaweiAccountIdentity> {
    this.loginCalls++;
    return this.loginIdentity;
  }

  async authorizeProfile(expectedUnionId: string): Promise<HuaweiAccountProfile> {
    this.profileCalls++;
    this.profileUnionIds.push(expectedUnionId);
    if (this.throwOnProfile) {
      throw new Error('profile authorization canceled');
    }
    return this.profile;
  }

  async getAuthorizationState(_unionId: string): Promise<HuaweiAuthorizationState> {
    if (this.throwOnRestore.length > 0) {
      throw new Error(this.throwOnRestore);
    }
    return this.authorization;
  }
}

class FakeAccountProfileSink implements AccountProfileSink {
  authorizedOwners: string[] = [];
  unavailableOwners: string[] = [];
  profiles: HuaweiAccountProfile[] = [];

  recordAuthorized(ownerId: string, profile: HuaweiAccountProfile): void {
    this.authorizedOwners.push(ownerId);
    this.profiles.push(profile);
  }

  recordUnavailable(ownerId: string): void {
    this.unavailableOwners.push(ownerId);
  }
}

class FakeLegacyClaimCoordinator implements LegacyAccountClaimCoordinator {
  owners: string[] = [];

  async claimLegacyDataForFirstAccountIfNeeded(ownerId: string): Promise<void> {
    this.owners.push(ownerId);
  }
}

class FakeActiveAccountOwnerStore implements ActiveAccountOwnerStore {
  ownerId: string = '';

  read(): string {
    return this.ownerId;
  }

  write(ownerId: string): void {
    this.ownerId = ownerId;
  }

  clear(): void {
    this.ownerId = '';
  }
}

function publicSnapshotText(snapshot: AccountSessionSnapshot): string {
  return snapshot.status.toString() + '|' + snapshot.ownerId + '|' + snapshot.errorMessage;
}

class FakeCloudAccountService implements CloudAccountService {
  identity: CloudAccountIdentity = { uid: 'cloud-user', displayName: '手机用户' };
  restored: CloudAccountIdentity | null = null;
  fail: boolean = false;
  failSignOut: boolean = false;
  restoreWait: Promise<void> | null = null;
  async requestPhoneCode(_phone: string): Promise<number> { return 60; }
  async loginPhone(_phone: string, _code: string): Promise<CloudAccountIdentity> {
    if (this.fail) throw new Error('secret upstream error');
    this.restored = this.identity;
    return this.identity;
  }
  async loginWechat(): Promise<CloudAccountIdentity> { return this.loginPhone('', ''); }
  async loginHuawei(): Promise<CloudAccountIdentity> { return this.loginPhone('', ''); }
  async restore(): Promise<CloudAccountIdentity | null> {
    const identity = this.restored;
    if (this.restoreWait !== null) await this.restoreWait;
    return identity;
  }
  async linkPhone(_uid: string, _phone: string, _code: string): Promise<CloudAccountIdentity> { return this.identity; }
  async linkWechat(_uid: string): Promise<CloudAccountIdentity> { return this.identity; }
  async signOut(): Promise<void> {
    if (this.failSignOut) throw new Error('provider sign-out unavailable');
    this.restored = null;
  }
}

export default function accountSessionStoreTest() {
  describe('accountSessionStore', () => {
    it('phone and WeChat restore the same linked owner without claiming legacy data', 0, async () => {
      const cloud = new FakeCloudAccountService();
      const creds = new MemoryCredentialStore();
      const active = new FakeActiveAccountOwnerStore();
      const migration = new FakeLegacyClaimCoordinator();
      const store = new AccountSessionStore(new FakeHuaweiAccountService(), creds, 'client', migration, active, undefined, cloud);
      const phone = await store.loginPhone('13800138000', '123456');
      expect(phone.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
      expect(isValidAccountOwnerId(phone.ownerId)).assertTrue();
      expect(migration.owners.length).assertEqual(0);
      expect((await store.restore()).ownerId).assertEqual(phone.ownerId);
      await store.clearLocalSession();
      expect((await store.restore()).status).assertEqual(AccountSessionStatus.SIGNED_OUT);
      expect((await store.loginWechat()).ownerId).assertEqual(phone.ownerId);
      cloud.restored = { uid: 'another-cloud-user', displayName: '' };
      expect((await store.restore()).status).assertEqual(AccountSessionStatus.ACCOUNT_MISMATCH);
      expect(active.ownerId).assertEqual('');
    });

    it('binding preserves Huawei local ownership and rejects unverified login', 0, async () => {
      const cloud = new FakeCloudAccountService();
      const store = new AccountSessionStore(new FakeHuaweiAccountService(), new MemoryCredentialStore(), 'client',
        undefined, new FakeActiveAccountOwnerStore(), undefined, cloud);
      const huawei = await store.login();
      expect(await store.phoneLoginHint()).assertEqual('');
      const linked = await store.bindPhone('13800138000', '123456');
      expect(linked.ownerId).assertEqual(huawei.ownerId);
      expect(await store.phoneLoginHint()).assertEqual('138****8000');
      await store.clearLocalSession();
      expect(await store.phoneLoginHint()).assertEqual('');
      expect((await store.loginPhone('13800138000', '123456')).ownerId).assertEqual(huawei.ownerId);
      expect(await store.phoneLoginHint()).assertEqual('138****8000');
      await store.clearLocalSession();
      expect((await store.login()).ownerId).assertEqual(huawei.ownerId);
      expect(await store.phoneLoginHint()).assertEqual('138****8000');
      await store.clearLocalSession();
      cloud.fail = true;
      const failed = await store.loginWechat();
      expect(failed.status).assertEqual(AccountSessionStatus.ERROR);
      expect(failed.ownerId).assertEqual('');
      expect(failed.errorMessage.indexOf('secret')).assertEqual(-1);
    });

    it('logout stays signed out when a previously started cloud restore finishes late', 0, async () => {
      const cloud = new FakeCloudAccountService();
      const active = new FakeActiveAccountOwnerStore();
      const store = new AccountSessionStore(new FakeHuaweiAccountService(), new MemoryCredentialStore(), 'client',
        undefined, active, undefined, cloud);
      await store.loginPhone('13800138000', '123456');
      let release: () => void = () => {};
      cloud.restoreWait = new Promise<void>((resolve) => { release = resolve; });
      const restoring = store.restore();
      await new Promise<void>((resolve) => { setTimeout(resolve, 0); });
      const clearing = store.clearLocalSession();
      setTimeout(() => { release(); }, 10);
      await Promise.all([restoring, clearing]);
      expect(store.snapshot().status).assertEqual(AccountSessionStatus.SIGNED_OUT);
      expect(active.ownerId).assertEqual('');
      expect((await store.restore()).status).assertEqual(AccountSessionStatus.SIGNED_OUT);
    });

    it('cloud cleanup failure does not prevent local logout or Huawei login', 0, async () => {
      const cloud = new FakeCloudAccountService();
      const credentials = new MemoryCredentialStore();
      const active = new FakeActiveAccountOwnerStore();
      const store = new AccountSessionStore(new FakeHuaweiAccountService(), credentials, 'client',
        undefined, active, undefined, cloud);
      await store.loginPhone('13800138000', '123456');
      cloud.failSignOut = true;
      expect((await store.clearLocalSession()).status).assertEqual(AccountSessionStatus.SIGNED_OUT);
      expect(active.ownerId).assertEqual('');
      expect(await credentials.get('account:agc:uid:v1')).assertEqual('');
      expect(await credentials.get(HUAWEI_UNION_ID_CREDENTIAL_REF)).assertEqual('');
      const restarted = new AccountSessionStore(new FakeHuaweiAccountService(), credentials, 'client',
        undefined, active, undefined, cloud);
      expect((await restarted.restore()).status).assertEqual(AccountSessionStatus.SIGNED_OUT);
      expect((await restarted.login()).status).assertEqual(AccountSessionStatus.AUTHENTICATED);
      expect(restarted.currentOwnerId()).assertEqual(deriveHuaweiOwnerId('union-login'));
    });

    it('failed binding keeps the current owner and refuses a changed Huawei account', 0, async () => {
      const huaweiService = new FakeHuaweiAccountService();
      const cloud = new FakeCloudAccountService();
      const active = new FakeActiveAccountOwnerStore();
      const store = new AccountSessionStore(huaweiService, new MemoryCredentialStore(), 'client', undefined, active, undefined, cloud);
      const original = await store.login();
      huaweiService.loginIdentity = { unionId: 'another-device-account' };
      let rejected = false;
      try { await store.bindWechat(); } catch (_error) { rejected = true; }
      expect(rejected).assertTrue();
      expect(store.currentOwnerId()).assertEqual(original.ownerId);
      expect(active.ownerId).assertEqual(original.ownerId);
      expect(cloud.restored === null).assertTrue();
    });

    it('rejects malformed phone numbers and mismatched WeChat callback state', 0, () => {
      expect(validatedPhone(' 13800138000 ')).assertEqual('13800138000');
      let invalidPhone = false;
      let invalidState = false;
      try { validatedPhone('13800138000&admin=true'); } catch (_error) { invalidPhone = true; }
      try { validatedWechatCode('request-a', 'request-b', 'valid-code', 0); } catch (_error) { invalidState = true; }
      expect(invalidPhone).assertTrue();
      expect(invalidState).assertTrue();
      expect(validatedWechatCode('request-a', 'request-a', 'valid-code', 0)).assertEqual('valid-code');
    });

    it('derives stable lowercase SHA-256 owner IDs', 0, () => {
      const first = deriveHuaweiOwnerId('union-alpha');
      const second = deriveHuaweiOwnerId('union-alpha');

      expect(first).assertEqual('a52845bf69d2dda56123df4ba51f5e48ee6017631460e080843e00581a76e069');
      expect(second).assertEqual(first);
      expect(first.length).assertEqual(64);
      expect(first.indexOf('union-alpha')).assertEqual(-1);
      expect(isValidAccountOwnerId(first)).assertTrue();
      expect(isValidAccountOwnerId('union-alpha')).assertFalse();
      expect(deriveHuaweiOwnerId('测试用户-001')).assertEqual(
        '78ba055e3e4b90499ec46cc86f061d60269a4ed5050b69dc1f37227c9bd0a5f2');
    });

    it('restores an authorized matching account and coordinates first-account claiming', 0, async () => {
      const rawUnionId = 'private-union-matching';
      const credentials = new MemoryCredentialStore();
      await credentials.put(HUAWEI_UNION_ID_CREDENTIAL_REF, rawUnionId);
      const service = new FakeHuaweiAccountService();
      const claims = new FakeLegacyClaimCoordinator();
      const activeOwner = new FakeActiveAccountOwnerStore();
      const store = new AccountSessionStore(service, credentials, 'configured-client', claims, activeOwner);

      const snapshot = await store.restore();
      const expectedOwnerId = deriveHuaweiOwnerId(rawUnionId);

      expect(snapshot.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
      expect(snapshot.ownerId).assertEqual(expectedOwnerId);
      expect(store.currentOwnerId()).assertEqual(expectedOwnerId);
      expect(store.isAuthenticated()).assertTrue();
      expect(claims.owners.length).assertEqual(1);
      expect(claims.owners[0]).assertEqual(expectedOwnerId);
      expect(activeOwner.read()).assertEqual(expectedOwnerId);
      expect(publicSnapshotText(snapshot).indexOf(rawUnionId)).assertEqual(-1);
    });

    it('stays signed out when the device has no current Huawei account', 0, async () => {
      const credentials = new MemoryCredentialStore();
      await credentials.put(HUAWEI_UNION_ID_CREDENTIAL_REF, 'private-union-signed-out');
      const service = new FakeHuaweiAccountService();
      service.authorization = HuaweiAuthorizationState.UNLOGGED_IN;
      const activeOwner = new FakeActiveAccountOwnerStore();
      activeOwner.ownerId = deriveHuaweiOwnerId('stale-owner');
      const store = new AccountSessionStore(service, credentials, 'configured-client', undefined, activeOwner);

      const snapshot = await store.restore();

      expect(snapshot.status).assertEqual(AccountSessionStatus.SIGNED_OUT);
      expect(snapshot.ownerId).assertEqual('');
      expect(store.isAuthenticated()).assertFalse();
      expect(activeOwner.read()).assertEqual('');
    });

    it('detects a device account that does not match the securely stored account', 0, async () => {
      const storedUnionId = 'private-union-stored';
      const credentials = new MemoryCredentialStore();
      await credentials.put(HUAWEI_UNION_ID_CREDENTIAL_REF, storedUnionId);
      const service = new FakeHuaweiAccountService();
      service.authorization = HuaweiAuthorizationState.UNAUTHORIZED;
      const activeOwner = new FakeActiveAccountOwnerStore();
      activeOwner.ownerId = deriveHuaweiOwnerId('stale-owner');
      const store = new AccountSessionStore(service, credentials, 'configured-client', undefined, activeOwner);

      const snapshot = await store.restore();

      expect(snapshot.status).assertEqual(AccountSessionStatus.ACCOUNT_MISMATCH);
      expect(snapshot.ownerId).assertEqual('');
      expect(snapshot.errorMessage.length > 0).assertTrue();
      expect(publicSnapshotText(snapshot).indexOf(storedUnionId)).assertEqual(-1);
      expect(activeOwner.read()).assertEqual('');
    });

    it('rejects login when Client ID is absent without invoking a fake provider', 0, async () => {
      const service = new FakeHuaweiAccountService();
      const store = new AccountSessionStore(service, new MemoryCredentialStore(), '  ');

      const snapshot = await store.login();

      expect(snapshot.status).assertEqual(AccountSessionStatus.ERROR);
      expect(snapshot.errorMessage).assertEqual(missingHuaweiClientIdMessage());
      expect(service.loginCalls).assertEqual(0);
    });

    it('turns Account Kit configuration errors into actionable public messages', 0, () => {
      expect(huaweiLoginErrorMessage(1001500001)).assertContain('证书指纹');
      expect(huaweiLoginErrorMessage(1001502003)).assertContain('Client ID');
    });

    it('validates profile authorization state and matching returned UnionID', 0, () => {
      const profile = validateHuaweiProfileAuthorizationResponse(
        'union-current', 'state-1', 'state-1', 'union-current', '  小明 ', ' avatar://one ');
      expect(profile.nickName).assertEqual('小明');
      expect(profile.avatarUri).assertEqual('avatar://one');
      let stateRejected = false;
      let ownerRejected = false;
      try {
        validateHuaweiProfileAuthorizationResponse(
          'union-current', 'state-1', 'state-other', 'union-current', undefined, undefined);
      } catch (_error) {
        stateRejected = true;
      }
      try {
        validateHuaweiProfileAuthorizationResponse(
          'union-current', 'state-1', 'state-1', 'union-other', undefined, undefined);
      } catch (_error) {
        ownerRejected = true;
      }
      expect(stateRejected).assertTrue();
      expect(ownerRejected).assertTrue();
    });

    it('keeps provider errors and raw UnionID out of public session state', 0, async () => {
      const rawUnionId = 'private-union-must-not-leak';
      const credentials = new MemoryCredentialStore();
      await credentials.put(HUAWEI_UNION_ID_CREDENTIAL_REF, rawUnionId);
      const service = new FakeHuaweiAccountService();
      service.throwOnRestore = rawUnionId;
      const store = new AccountSessionStore(service, credentials, 'configured-client');

      const snapshot = await store.restore();

      expect(snapshot.status).assertEqual(AccountSessionStatus.ERROR);
      expect(publicSnapshotText(snapshot).indexOf(rawUnionId)).assertEqual(-1);
      expect(HUAWEI_UNION_ID_CREDENTIAL_REF.indexOf(rawUnionId)).assertEqual(-1);
    });

    it('persists login identity only through the credential abstraction and exposes the owner hash', 0, async () => {
      const rawUnionId = 'private-union-login';
      const credentials = new MemoryCredentialStore();
      const service = new FakeHuaweiAccountService();
      service.loginIdentity = { unionId: rawUnionId };
      const store = new AccountSessionStore(service, credentials, 'configured-client');

      const snapshot = await store.login();

      expect(snapshot.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
      expect(snapshot.ownerId).assertEqual(deriveHuaweiOwnerId(rawUnionId));
      expect(publicSnapshotText(snapshot).indexOf(rawUnionId)).assertEqual(-1);
      expect(await credentials.get(HUAWEI_UNION_ID_CREDENTIAL_REF)).assertEqual(rawUnionId);
    });

    it('requests profile immediately after login and persists it for the derived owner', 0, async () => {
      const rawUnionId = 'private-union-profile';
      const service = new FakeHuaweiAccountService();
      service.loginIdentity = { unionId: rawUnionId };
      const sink = new FakeAccountProfileSink();
      const store = new AccountSessionStore(service, new MemoryCredentialStore(), 'configured-client',
        undefined, undefined, sink);

      const snapshot = await store.login();

      expect(snapshot.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
      expect(service.profileCalls).assertEqual(1);
      expect(service.profileUnionIds[0]).assertEqual(rawUnionId);
      expect(sink.authorizedOwners[0]).assertEqual(deriveHuaweiOwnerId(rawUnionId));
      expect(sink.profiles[0].nickName).assertEqual('华为昵称');
      expect(sink.unavailableOwners.length).assertEqual(0);
    });

    it('keeps base login authenticated when profile authorization is canceled and does not retry on restore', 0,
      async () => {
        const rawUnionId = 'private-union-canceled-profile';
        const credentials = new MemoryCredentialStore();
        const service = new FakeHuaweiAccountService();
        service.loginIdentity = { unionId: rawUnionId };
        service.throwOnProfile = true;
        const sink = new FakeAccountProfileSink();
        const store = new AccountSessionStore(service, credentials, 'configured-client', undefined, undefined, sink);

        const loginSnapshot = await store.login();
        expect(loginSnapshot.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
        expect(sink.unavailableOwners[0]).assertEqual(deriveHuaweiOwnerId(rawUnionId));
        expect(service.profileCalls).assertEqual(1);

        const restoreSnapshot = await store.restore();
        expect(restoreSnapshot.status).assertEqual(AccountSessionStatus.AUTHENTICATED);
        expect(service.profileCalls).assertEqual(1);
      });
  });
}
