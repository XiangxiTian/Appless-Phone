import { describe, it, expect } from '@ohos/hypium';
import { aboutYouSocialOperationIsCurrent } from '../main/ets/publicpersona/PublicPersonaOperationState';

export default function aboutYouOperationStateTests(): void {
  describe('AboutYouOperationState', (): void => {
    it('allows_only_the_current_authenticated_page_operation', 0, (): void => {
      expect(aboutYouSocialOperationIsCurrent(true, true, 4, 4, 2, 2)).assertTrue();
      expect(aboutYouSocialOperationIsCurrent(false, true, 4, 4, 2, 2)).assertFalse();
      expect(aboutYouSocialOperationIsCurrent(true, false, 4, 4, 2, 2)).assertFalse();
    });
    it('rejects_discarded_drafts_and_account_switches_even_after_reopen', 0, (): void => {
      expect(aboutYouSocialOperationIsCurrent(true, true, 4, 5, 2, 2)).assertFalse();
      expect(aboutYouSocialOperationIsCurrent(true, true, 4, 4, 2, 3)).assertFalse();
      expect(aboutYouSocialOperationIsCurrent(true, true, 4, 5, 2, 3)).assertFalse();
    });
  });
}
