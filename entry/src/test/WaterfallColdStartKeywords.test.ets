import { describe, expect, it } from '@ohos/hypium';
import {
  WATERFALL_COLD_START_KEYWORD_COUNT,
  WATERFALL_COLD_START_QUERY_VARIANT_COUNT,
  WATERFALL_COLD_START_TOPIC_COUNT,
  WATERFALL_COLD_START_TOPICS,
  WATERFALL_DOMESTIC_COLD_START_KEYWORDS,
  WATERFALL_GLOBAL_COLD_START_KEYWORDS
} from '@loop/agent-core';

export default function waterfallColdStartKeywordsTest() {
  describe('WaterfallColdStartKeywords', () => {
    it('contains 100 bilingual topics with 200 unique query variants', 0, () => {
      const all = WATERFALL_DOMESTIC_COLD_START_KEYWORDS.concat(WATERFALL_GLOBAL_COLD_START_KEYWORDS);
      const domesticUnique = new Set<string>(WATERFALL_DOMESTIC_COLD_START_KEYWORDS);
      const globalUnique = new Set<string>(
        WATERFALL_GLOBAL_COLD_START_KEYWORDS.map((keyword: string): string => keyword.toLowerCase())
      );

      expect(WATERFALL_DOMESTIC_COLD_START_KEYWORDS.length).assertEqual(100);
      expect(WATERFALL_GLOBAL_COLD_START_KEYWORDS.length).assertEqual(100);
      expect(WATERFALL_COLD_START_TOPICS.length).assertEqual(100);
      expect(WATERFALL_COLD_START_TOPIC_COUNT).assertEqual(100);
      expect(WATERFALL_COLD_START_KEYWORD_COUNT).assertEqual(100);
      expect(WATERFALL_COLD_START_QUERY_VARIANT_COUNT).assertEqual(200);
      expect(all.length).assertEqual(200);
      expect(domesticUnique.size).assertEqual(100);
      expect(globalUnique.size).assertEqual(100);
      expect(WATERFALL_COLD_START_TOPICS[0].domesticQuery).assertEqual('人工智能');
      expect(WATERFALL_COLD_START_TOPICS[0].globalQuery).assertEqual('artificial intelligence');
    });

    it('remains an independent data set for the new pool', 0, () => {
      expect(WATERFALL_COLD_START_TOPICS[99].domesticQuery.length > 0).assertTrue();
      expect(WATERFALL_COLD_START_TOPICS[99].globalQuery.length > 0).assertTrue();
    });
  });
}
