import { describe, expect, it } from '@ohos/hypium';
import {
  canSaveUserDisplayName,
  normalizedUserDisplayName,
  userDisplayNameSaveAction
} from '../main/ets/pages/A2uiHome/components/UserManagementPage';
import {
  MANAGEMENT_CARD_BACKGROUND,
  MANAGEMENT_CARD_EDGE,
  MANAGEMENT_CARD_RADIUS,
  MANAGEMENT_CARD_SHADOW,
  MANAGEMENT_CARD_SHADOW_OFFSET_Y,
  MANAGEMENT_CARD_SHADOW_RADIUS,
  MANAGEMENT_DISCLOSURE_ARROW_ROTATION
} from '../main/ets/pages/A2uiHome/components/ManagementPageVisualStyle';

export default function userManagementPageTest(): void {
  describe('UserManagementPage', () => {
    it('trims a user-confirmed display name before saving', 0, () => {
      expect(normalizedUserDisplayName('  小罗  ')).assertEqual('小罗');
    });

    it('only enables save for a non-empty changed name', 0, () => {
      expect(canSaveUserDisplayName('  ', '华为用户')).assertFalse();
      expect(canSaveUserDisplayName(' 华为用户 ', '华为用户')).assertFalse();
      expect(canSaveUserDisplayName('小罗', '华为用户')).assertTrue();
    });

    it('lets the floppy action close unchanged edits without writing', 0, () => {
      expect(userDisplayNameSaveAction('', '华为用户')).assertEqual('disabled');
      expect(userDisplayNameSaveAction(' 华为用户 ', '华为用户')).assertEqual('close');
      expect(userDisplayNameSaveAction('小罗', '华为用户')).assertEqual('save');
    });

    it('shares the raised-card depth and right-arrow direction across management pages', 0, () => {
      expect(MANAGEMENT_CARD_BACKGROUND).assertEqual('#FAFFFFFF');
      expect(MANAGEMENT_CARD_EDGE).assertEqual('#7AFFFFFF');
      expect(MANAGEMENT_CARD_SHADOW).assertEqual('#21000000');
      expect(MANAGEMENT_CARD_RADIUS).assertEqual(30);
      expect(MANAGEMENT_CARD_SHADOW_RADIUS).assertEqual(22);
      expect(MANAGEMENT_CARD_SHADOW_OFFSET_Y).assertEqual(12);
      expect(MANAGEMENT_DISCLOSURE_ARROW_ROTATION).assertEqual(180);
    });
  });
}
