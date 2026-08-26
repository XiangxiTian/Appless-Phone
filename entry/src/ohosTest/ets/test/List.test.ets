import abilityTest from './Ability.test';
import phoneLocalMemoryDeviceTest from './PhoneLocalMemoryDevice.test';
import sharedUnitTests from '../../../test/List.test';

export default function testsuite() {
  abilityTest();
  phoneLocalMemoryDeviceTest();
  sharedUnitTests();
}
