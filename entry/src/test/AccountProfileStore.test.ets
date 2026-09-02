import { preferences } from '@kit.ArkData';
import { describe, expect, it } from '@ohos/hypium';
import {
  AccountProfileAuthorizationStatus,
  AccountProfileStore,
  effectiveAccountDisplayName,
  emptyAccountProfileSnapshot
} from '../main/ets/account/AccountProfileStore';

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

  flushSync(): void {
  }
}

function createStore(): AccountProfileStore {
  return new AccountProfileStore(new MemoryPreferences() as Object as preferences.Preferences);
}

export default function accountProfileStoreTest() {
  describe('AccountProfileStore', () => {
    it('falls back to a stable generic display name before profile authorization', 0, () => {
      const store = createStore();
      const snapshot = store.load();

      expect(snapshot.profileAuthorizationStatus).assertEqual(AccountProfileAuthorizationStatus.NOT_REQUESTED);
      expect(snapshot.profileAuthorizationUpdatedAt).assertEqual(0);
      expect(store.effectiveName()).assertEqual('华为用户');
      expect(effectiveAccountDisplayName(emptyAccountProfileSnapshot())).assertEqual('华为用户');
    });

    it('stores the authorized Huawei nickname and uses it by default', 0, () => {
      const store = createStore();

      const saved = store.recordAuthorized({ nickName: '  小明  ', avatarUri: '  https://avatar.test/a  ' }, 1234);

      expect(saved.huaweiNickName).assertEqual('小明');
      expect(saved.profileAuthorizationStatus).assertEqual(AccountProfileAuthorizationStatus.AUTHORIZED);
      expect(saved.profileAuthorizationUpdatedAt).assertEqual(1234);
      expect(store.effectiveName()).assertEqual('小明');
    });

    it('prefers a custom name and clearing it restores the Huawei nickname', 0, () => {
      const store = createStore();
      store.recordAuthorized({ nickName: '华为昵称', avatarUri: '' }, 11);

      expect(store.setCustomName('  阿昼  ').customName).assertEqual('阿昼');
      expect(store.effectiveName()).assertEqual('阿昼');
      expect(store.clearCustomName().customName).assertEqual('');
      expect(store.effectiveName()).assertEqual('华为昵称');
    });

    it('records an unavailable authorization without discarding a prior name', 0, () => {
      const store = createStore();
      store.recordAuthorized({ nickName: '旧昵称', avatarUri: 'avatar://old' }, 20);
      store.setCustomName('自定义');

      const unavailable = store.recordUnavailable(30);

      expect(unavailable.profileAuthorizationStatus).assertEqual(AccountProfileAuthorizationStatus.UNAVAILABLE);
      expect(unavailable.profileAuthorizationUpdatedAt).assertEqual(30);
      expect(unavailable.huaweiNickName).assertEqual('旧昵称');
      expect(store.effectiveName()).assertEqual('自定义');
    });
  });
}
