import { describe, expect, it } from '@ohos/hypium';
import {
  accountScopedPreferenceStoreBaseNames,
  accountScopedStoreName
} from '../main/ets/account/AccountStorageScope';

const OWNER_A: string = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const OWNER_B: string = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

export default function accountStorageScopeTest() {
  describe('AccountStorageScope', () => {
    it('keeps the legacy store name when no owner is supplied', 0, () => {
      expect(accountScopedStoreName('aiphone_bim_store')).assertEqual('aiphone_bim_store');
      expect(accountScopedStoreName('aiphone_bim_store', '   ')).assertEqual('aiphone_bim_store');
    });

    it('gives different owners stable isolated Preferences names', 0, () => {
      const first = accountScopedStoreName('aiphone_bim_store', OWNER_A);
      const second = accountScopedStoreName('aiphone_bim_store', OWNER_B);
      expect(first).assertEqual('aiphone_bim_store__owner_' + OWNER_A);
      expect(second).assertEqual('aiphone_bim_store__owner_' + OWNER_B);
      expect(first === second).assertFalse();
      expect(accountScopedStoreName('aiphone_bim_store', OWNER_A)).assertEqual(first);
    });

    it('encodes unsafe future owner identifiers instead of exposing them as store paths', 0, () => {
      const scoped = accountScopedStoreName('aiphone_public_persona', 'union/id:1');
      expect(scoped).assertEqual('aiphone_public_persona__owner_u0075006e0069006f006e002f00690064003a0031');
      expect(scoped.indexOf('/')).assertEqual(-1);
      expect(scoped.indexOf(':')).assertEqual(-1);
    });

    it('publishes the complete Preferences allowlist for first-account legacy claiming', 0, () => {
      const names = accountScopedPreferenceStoreBaseNames();
      expect(names.length).assertEqual(11);
      expect(names.indexOf('aiphone_bim_store') >= 0).assertTrue();
      expect(names.indexOf('aiphone_daily_brief_store') >= 0).assertTrue();
      expect(names.indexOf('navigation_card_snapshot_store') >= 0).assertTrue();
      expect(names.indexOf('loop_conversation') >= 0).assertTrue();
      names.splice(0, names.length);
      expect(accountScopedPreferenceStoreBaseNames().length).assertEqual(11);
    });
  });
}
