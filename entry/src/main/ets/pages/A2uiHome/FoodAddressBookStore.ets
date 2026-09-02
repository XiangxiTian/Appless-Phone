import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const FOOD_ADDRESS_BOOK_STORE_NAME: string = 'aiphone_food_address_book';
const FOOD_ADDRESS_BOOK_KEY: string = 'saved_addresses';
const FOOD_ADDRESS_BOOK_VERSION_KEY: string = 'saved_addresses_version';
const FOOD_ADDRESS_BOOK_VERSION: string = 'food_address_book_v1';
const MAX_FOOD_SAVED_ADDRESSES: number = 50;

export interface FoodLocationViewModel {
  longitude: number;
  latitude: number;
  radiusMeters: number;
  name: string;
  address: string;
}

export interface FoodSavedAddressViewModel extends FoodLocationViewModel {
  id: string;
}

function textFromPreference(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

function finiteNumber(value: Object | string | number | boolean | null | undefined): number | null {
  const numberValue = Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function savedAddressFromValue(value: Object | null | undefined): FoodSavedAddressViewModel | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const raw = value as Record<string, Object | string | number | boolean | null | undefined>;
  const id = typeof raw.id === 'string' ? raw.id.trim() : '';
  const longitude = finiteNumber(raw.longitude);
  const latitude = finiteNumber(raw.latitude);
  const radiusMeters = finiteNumber(raw.radiusMeters);
  if (id.length === 0 || longitude === null || latitude === null || radiusMeters === null ||
    longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90 ||
    radiusMeters < 100 || radiusMeters > 50000) {
    return null;
  }
  return {
    id: id,
    longitude: longitude,
    latitude: latitude,
    radiusMeters: radiusMeters,
    name: typeof raw.name === 'string' ? raw.name : '',
    address: typeof raw.address === 'string' ? raw.address : ''
  };
}

function addressesFromJson(raw: string): FoodSavedAddressViewModel[] {
  if (raw.trim().length === 0) {
    return [];
  }
  const parsed = JSON.parse(raw) as Object;
  if (!Array.isArray(parsed)) {
    return [];
  }
  const addresses: FoodSavedAddressViewModel[] = [];
  parsed.forEach((value: Object | null | undefined) => {
    const address = savedAddressFromValue(value);
    if (address !== null && addresses.length < MAX_FOOD_SAVED_ADDRESSES) {
      addresses.push(address);
    }
  });
  return addresses;
}

function copyAddress(address: FoodSavedAddressViewModel): FoodSavedAddressViewModel {
  return {
    id: address.id,
    longitude: address.longitude,
    latitude: address.latitude,
    radiusMeters: address.radiusMeters,
    name: address.name,
    address: address.address
  };
}

export class FoodAddressBookStore {
  private store: preferences.Preferences;
  private addresses: FoodSavedAddressViewModel[] = [];

  constructor(context: common.Context, storeName: string = FOOD_ADDRESS_BOOK_STORE_NAME) {
    this.store = preferences.getPreferencesSync(context, { name: storeName });
    this.addresses = this.loadFromPreferences();
  }

  private loadFromPreferences(): FoodSavedAddressViewModel[] {
    try {
      if (textFromPreference(this.store.getSync(FOOD_ADDRESS_BOOK_VERSION_KEY, '')) !==
        FOOD_ADDRESS_BOOK_VERSION) {
        return [];
      }
      return addressesFromJson(textFromPreference(this.store.getSync(FOOD_ADDRESS_BOOK_KEY, '')));
    } catch (_error) {
      return [];
    }
  }

  private async persist(): Promise<void> {
    this.store.putSync(FOOD_ADDRESS_BOOK_KEY, JSON.stringify(this.addresses));
    this.store.putSync(FOOD_ADDRESS_BOOK_VERSION_KEY, FOOD_ADDRESS_BOOK_VERSION);
    await this.store.flush();
  }

  list(): FoodSavedAddressViewModel[] {
    return this.addresses.map((address: FoodSavedAddressViewModel) => copyAddress(address));
  }

  async upsert(address: FoodSavedAddressViewModel): Promise<FoodSavedAddressViewModel[]> {
    const next: FoodSavedAddressViewModel[] = [copyAddress(address)];
    this.addresses.forEach((saved: FoodSavedAddressViewModel) => {
      if (saved.id !== address.id &&
        (saved.longitude !== address.longitude || saved.latitude !== address.latitude) &&
        next.length < MAX_FOOD_SAVED_ADDRESSES) {
        next.push(copyAddress(saved));
      }
    });
    this.addresses = next;
    await this.persist();
    return this.list();
  }

  async delete(addressId: string): Promise<boolean> {
    const next = this.addresses.filter((address: FoodSavedAddressViewModel) => address.id !== addressId);
    if (next.length === this.addresses.length) {
      return false;
    }
    this.addresses = next;
    await this.persist();
    return true;
  }
}
