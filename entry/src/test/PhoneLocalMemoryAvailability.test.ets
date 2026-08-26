import { describe, expect, it } from '@ohos/hypium';
import { CachedPhoneLocalMemoryAvailability } from '../main/ets/memory/PhoneLocalMemoryAvailability';

export default function phoneLocalMemoryAvailabilityTest() {
  describe('PhoneLocalMemoryAvailability', () => {
    it('caches a missing model probe and emits one sanitized disabled log', 0, () => {
      let probes: number = 0;
      const logs: string[] = [];
      const gate = new CachedPhoneLocalMemoryAvailability(
        (): boolean => {
          probes++;
          return false;
        },
        (message: string): void => { logs.push(message); }
      );

      expect(gate.isAvailable()).assertFalse();
      expect(gate.isAvailable()).assertFalse();
      expect(probes).assertEqual(1);
      expect(logs.length).assertEqual(1);
      expect(logs[0]).assertEqual(
        '[AIPhone][PhoneLocalMemoryAvailability] status=disabled reason=model_rawfile_unavailable'
      );
      expect(logs[0].indexOf('bge-small')).assertEqual(-1);
    });

    it('keeps an available model enabled without a disabled log', 0, () => {
      const logs: string[] = [];
      const gate = new CachedPhoneLocalMemoryAvailability(
        (): boolean => true,
        (message: string): void => { logs.push(message); }
      );
      expect(gate.isAvailable()).assertTrue();
      expect(logs.length).assertEqual(0);
    });
  });
}
