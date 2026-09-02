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

export default function accountSessionStoreTest() {
  describe('accountSessionStore', () => {
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
