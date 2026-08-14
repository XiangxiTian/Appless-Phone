import { describe, expect, it } from '@ohos/hypium';
import {
  travelSearchPreflight
} from '@loop/agent-core';

const NOW: string = '2026-08-12T12:00:00+08:00';

export default function travelSearchPreflightTest() {
  describe('travelSearchPreflight', () => {
    it('asks only for fields that are absent from the model tool query', 0, () => {
      const result = travelSearchPreflight('我下周要去上海出差', NOW);
      expect(result.complete).assertFalse();
      expect(result.missingFields.length).assertEqual(2);
      expect(result.missingFields[0]).assertEqual('departure_date');
      expect(result.missingFields[1]).assertEqual('origin');
    });

    it('accepts a complete query normalized by the model from standard conversation context', 0, () => {
      const result = travelSearchPreflight(
        '8月28从深圳出发去上海', NOW
      );
      expect(result.complete).assertTrue();
      expect(result.departureDate).assertEqual('2026-08-28');
      expect(result.origin).assertEqual('深圳');
      expect(result.destination).assertEqual('上海');
    });

    it('prefers a current-turn date over an older date', 0, () => {
      const result = travelSearchPreflight(
        '明天从北京到上海；我下周五从北京到上海', NOW
      );
      expect(result.departureDate).assertEqual('2026-08-13');
    });
  });
}
