import { describe, expect, it } from '@ohos/hypium';
import {
  buildCtripFlightSearchUrl,
  buildCtripFlightSelectionContext,
  ctripFlightBookingSelection,
  ctripTravelOptionBookingSelection,
  isAllowedCtripFlightBookingUrl
} from '../main/ets/pages/A2uiHome/travel/TravelBookingProvider';

export default function travelBookingProviderTest() {
  describe('travelBookingProvider', () => {
    it('builds a Ctrip handoff from a flight result row', 0, () => {
      const selection = ctripFlightBookingSelection({
        flightNo: '9C7556', airline: '春秋航空', dep: '深圳宝安', arr: '上海虹桥',
        depTime: '2026-08-21 05:55', arrTime: '2026-08-21 07:55', status: '计划', price: ''
      });
      const url = buildCtripFlightSearchUrl(selection);
      expect(selection.fromCode).assertEqual('SZX');
      expect(selection.toCode).assertEqual('SHA');
      expect(selection.travelDate).assertEqual('2026-08-21');
      expect(url).assertEqual(
        'https://m.ctrip.com/html5/flight/swift/domestic/SZX/SHA/2026-08-21'
      );
      expect(isAllowedCtripFlightBookingUrl(url)).assertTrue();
      expect(buildCtripFlightSelectionContext(selection)).assertEqual(
        '已选 9C7556 · 2026-08-21 · SZX → SHA'
      );
    });

    it('builds a Ctrip handoff from a mixed travel result row', 0, () => {
      const selection = ctripTravelOptionBookingSelection({
        id: 'flight-9C7556-05:55', source: 'flight', sourceTag: '飞机 · 飞常准', title: '9C7556',
        from: '深圳宝安', to: '上海虹桥', depart: '05:55', arrive: '07:55', duration: '2小时',
        price: '', availability: '', status: '计划', detail: '春秋航空', travelDate: '2026-08-28',
        fromCode: 'SZX', toCode: 'SHA'
      });
      const url = buildCtripFlightSearchUrl(selection);
      expect(url).assertEqual(
        'https://m.ctrip.com/html5/flight/swift/domestic/SZX/SHA/2026-08-28'
      );
      expect(isAllowedCtripFlightBookingUrl(url)).assertTrue();
    });

    it('rejects incomplete or untrusted Ctrip URLs', 0, () => {
      expect(buildCtripFlightSearchUrl({
        flightNumber: '9C7556', travelDate: '', fromCode: 'SZX', toCode: 'SHA'
      })).assertEqual('');
      expect(isAllowedCtripFlightBookingUrl(
        'https://flights.ctrip.com.evil.example/online/list/oneway-szx-sha?depdate=2026-08-21&cabin=y_s_c_f&adult=1&child=0&infant=0'
      )).assertFalse();
      expect(isAllowedCtripFlightBookingUrl(
        'https://m.ctrip.com.evil.example/html5/flight/swift/domestic/SZX/SHA/2026-08-21'
      )).assertFalse();
      expect(isAllowedCtripFlightBookingUrl(
        'https://m.ctrip.com/html5/flight/swift/domestic/SZX/SHA/2026-08-21?redirect=https://evil.example'
      )).assertFalse();
    });
  });
}
