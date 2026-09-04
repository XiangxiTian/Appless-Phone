import { describe, expect, it } from '@ohos/hypium';
import { MemoryOverview } from '../main/ets/memory/MemoryOverview';
import {
  LONG_TERM_MEMORY_CORRECTION_SUCCESS_TOAST,
  longTermMemoryOverviewDisplaySections,
  shouldScrollLongTermMemoryApplyResultToTop
} from '../main/ets/pages/A2uiHome/components/LongTermMemoryPage';

export default function longTermMemoryPageTest(): void {
  describe('LongTermMemoryPage', () => {
    it('exposes only model-organized claim copy to the overview content block', 0, () => {
      const overview: MemoryOverview = {
        title: '你的长期记忆',
        summary: '这是整理后的概览。',
        claims: [{
          heading: '休闲偏好',
          body: '偏爱安静的文化活动。',
          evidenceMemoryIds: ['private-memory-id']
        }]
      };
      const sections = longTermMemoryOverviewDisplaySections(overview);
      expect(sections.length).assertEqual(1);
      expect(sections[0].heading).assertEqual('休闲偏好');
      expect(sections[0].body).assertEqual('偏爱安静的文化活动。');
      expect(JSON.stringify(sections).indexOf('private-memory-id')).assertEqual(-1);
      expect(JSON.stringify(sections).indexOf('evidenceMemoryIds')).assertEqual(-1);
    });

    it('uses a short success toast instead of persistent page copy', 0, () => {
      expect(LONG_TERM_MEMORY_CORRECTION_SUCCESS_TOAST).assertEqual('长期记忆已按确认方案修改');
    });

    it('scrolls every visible apply outcome including a freshness conflict to the page top', 0, () => {
      expect(shouldScrollLongTermMemoryApplyResultToTop('conflict')).assertTrue();
      expect(shouldScrollLongTermMemoryApplyResultToTop('success')).assertTrue();
      expect(shouldScrollLongTermMemoryApplyResultToTop('partial')).assertTrue();
      expect(shouldScrollLongTermMemoryApplyResultToTop('error')).assertTrue();
      expect(shouldScrollLongTermMemoryApplyResultToTop('inactive')).assertFalse();
    });
  });
}
