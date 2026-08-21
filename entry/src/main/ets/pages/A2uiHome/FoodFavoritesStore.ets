import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { A2uiFoodData } from '@loop/agent-core';

const FOOD_FAVORITES_STORE_NAME: string = 'aiphone_food_favorites';
const FOOD_FAVORITES_KEY: string = 'favorites';
const FOOD_FAVORITES_VERSION_KEY: string = 'favorites_version';
const FOOD_FAVORITES_VERSION: string = 'food_favorites_v1';
const MAX_FOOD_FAVORITES: number = 200;

export interface FoodFavoriteViewModel extends A2uiFoodData {
  favoriteId: string;
  savedAt: number;
}

function preferenceText(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

function normalizedIdentityText(value: string): string {
  return value.toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[·•\-_/|｜,，.。:：;；（）()【】\[\]{}]/g, '')
    .replace(/北京市|北京城区|北京|上海市|上海城区|上海|深圳市|深圳|广州市|广州|杭州市|杭州|成都市|成都|重庆市|重庆|天津市|天津|南京市|南京|武汉市|武汉|西安市|西安|苏州市|苏州/g, '');
}

function normalizedLocation(value: string | undefined): string {
  if (value === undefined) {
    return '';
  }
  const parts = value.split(',');
  if (parts.length !== 2) {
    return '';
  }
  const longitude = Number(parts[0]);
  const latitude = Number(parts[1]);
  if (!Number.isFinite(longitude) || !Number.isFinite(latitude)) {
    return '';
  }
  return longitude.toFixed(5) + ',' + latitude.toFixed(5);
}

export function foodFavoriteId(item: A2uiFoodData): string {
  const name = normalizedIdentityText(item.name);
  const coordinateLocation = item.longitude === undefined || item.latitude === undefined ? undefined :
    item.longitude.toString() + ',' + item.latitude.toString();
  const location = normalizedLocation(item.location === undefined || item.location.length === 0 ?
    coordinateLocation : item.location);
  if (location.length > 0) {
    return 'food:' + name + '@' + location;
  }
  return 'food:' + name + '@' + normalizedIdentityText(item.address);
}

export function findFoodFavoriteIndex(favorites: FoodFavoriteViewModel[], item: A2uiFoodData): number {
  const favoriteId = foodFavoriteId(item);
  return favorites.findIndex((favorite: FoodFavoriteViewModel): boolean => favorite.favoriteId === favoriteId);
}

function copyFoodFavorite(value: FoodFavoriteViewModel): FoodFavoriteViewModel {
  return {
    favoriteId: value.favoriteId,
    savedAt: value.savedAt,
    name: value.name,
    category: value.category,
    address: value.address,
    distance: value.distance,
    longitude: value.longitude,
    latitude: value.latitude,
    location: value.location,
    sourceTags: value.sourceTags === undefined ? undefined : value.sourceTags.slice(),
    phone: value.phone,
    phoneSource: value.phoneSource,
    openHoursToday: value.openHoursToday,
    openHoursWeek: value.openHoursWeek,
    pricePerPerson: value.pricePerPerson,
    priceText: value.priceText,
    priceSource: value.priceSource,
    rating: value.rating,
    ratingText: value.ratingText,
    ratingSource: value.ratingSource,
    businessStatus: value.businessStatus,
    businessStatusLabel: value.businessStatusLabel
  };
}

function favoriteFromValue(value: Object | null | undefined): FoodFavoriteViewModel | null {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    return null;
  }
  const raw = value as Record<string, Object | string | number | boolean | string[] | null | undefined>;
  const name = typeof raw.name === 'string' ? raw.name.trim() : '';
  const address = typeof raw.address === 'string' ? raw.address : '';
  const category = typeof raw.category === 'string' ? raw.category : '';
  const distance = typeof raw.distance === 'string' ? raw.distance : '';
  const longitude = typeof raw.longitude === 'number' && Number.isFinite(raw.longitude) ? raw.longitude : undefined;
  const latitude = typeof raw.latitude === 'number' && Number.isFinite(raw.latitude) ? raw.latitude : undefined;
  const location = typeof raw.location === 'string' ? raw.location : undefined;
  const favoriteId = typeof raw.favoriteId === 'string' ? raw.favoriteId.trim() : '';
  const savedAt = typeof raw.savedAt === 'number' && Number.isFinite(raw.savedAt) ? raw.savedAt : 0;
  if (name.length === 0 || favoriteId.length === 0) {
    return null;
  }
  const sourceTags: string[] = [];
  if (Array.isArray(raw.sourceTags)) {
    raw.sourceTags.forEach((tag: string): void => {
      if (tag.length > 0 && sourceTags.indexOf(tag) < 0) {
        sourceTags.push(tag);
      }
    });
  }
  return {
    favoriteId: favoriteId,
    savedAt: savedAt,
    name: name,
    category: category,
    address: address,
    distance: distance,
    longitude: longitude,
    latitude: latitude,
    location: location,
    sourceTags: sourceTags,
    phone: typeof raw.phone === 'string' ? raw.phone : undefined,
    phoneSource: typeof raw.phoneSource === 'string' ? raw.phoneSource : undefined,
    openHoursToday: typeof raw.openHoursToday === 'string' ? raw.openHoursToday : undefined,
    openHoursWeek: typeof raw.openHoursWeek === 'string' ? raw.openHoursWeek : undefined,
    pricePerPerson: typeof raw.pricePerPerson === 'number' ? raw.pricePerPerson : undefined,
    priceText: typeof raw.priceText === 'string' ? raw.priceText : undefined,
    priceSource: typeof raw.priceSource === 'string' ? raw.priceSource : undefined,
    rating: typeof raw.rating === 'number' ? raw.rating : undefined,
    ratingText: typeof raw.ratingText === 'string' ? raw.ratingText : undefined,
    ratingSource: typeof raw.ratingSource === 'string' ? raw.ratingSource : undefined,
    businessStatus: typeof raw.businessStatus === 'string' ? raw.businessStatus : undefined,
    businessStatusLabel: typeof raw.businessStatusLabel === 'string' ? raw.businessStatusLabel : undefined
  };
}

function favoritesFromJson(raw: string): FoodFavoriteViewModel[] {
  if (raw.trim().length === 0) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as Object;
    if (!Array.isArray(parsed)) {
      return [];
    }
    const favorites: FoodFavoriteViewModel[] = [];
    parsed.forEach((value: Object | null | undefined): void => {
      const favorite = favoriteFromValue(value);
      if (favorite !== null && favorites.length < MAX_FOOD_FAVORITES &&
        favorites.findIndex((item: FoodFavoriteViewModel): boolean => item.favoriteId === favorite.favoriteId) < 0) {
        favorites.push(favorite);
      }
    });
    return favorites;
  } catch (_error) {
    return [];
  }
}

export function favoriteFromFood(item: A2uiFoodData): FoodFavoriteViewModel {
  return {
    favoriteId: foodFavoriteId(item),
    savedAt: Date.now(),
    name: item.name,
    category: item.category,
    address: item.address,
    distance: item.distance,
    longitude: item.longitude,
    latitude: item.latitude,
    location: item.location,
    sourceTags: item.sourceTags === undefined ? undefined : item.sourceTags.slice(),
    phone: item.phone,
    phoneSource: item.phoneSource,
    openHoursToday: item.openHoursToday,
    openHoursWeek: item.openHoursWeek,
    pricePerPerson: item.pricePerPerson,
    priceText: item.priceText,
    priceSource: item.priceSource,
    rating: item.rating,
    ratingText: item.ratingText,
    ratingSource: item.ratingSource,
    businessStatus: item.businessStatus,
    businessStatusLabel: item.businessStatusLabel
  };
}

export class FoodFavoritesStore {
  private readonly store: preferences.Preferences;
  private favorites: FoodFavoriteViewModel[];

  constructor(context: common.Context) {
    this.store = preferences.getPreferencesSync(context, { name: FOOD_FAVORITES_STORE_NAME });
    this.favorites = this.loadFromPreferences();
  }

  private loadFromPreferences(): FoodFavoriteViewModel[] {
    try {
      if (preferenceText(this.store.getSync(FOOD_FAVORITES_VERSION_KEY, '')) !== FOOD_FAVORITES_VERSION) {
        return [];
      }
      return favoritesFromJson(preferenceText(this.store.getSync(FOOD_FAVORITES_KEY, '')));
    } catch (_error) {
      return [];
    }
  }

  private async persist(): Promise<void> {
    this.store.putSync(FOOD_FAVORITES_KEY, JSON.stringify(this.favorites));
    this.store.putSync(FOOD_FAVORITES_VERSION_KEY, FOOD_FAVORITES_VERSION);
    await this.store.flush();
  }

  list(): FoodFavoriteViewModel[] {
    return this.favorites.map((favorite: FoodFavoriteViewModel): FoodFavoriteViewModel => copyFoodFavorite(favorite));
  }

  find(favoriteId: string): FoodFavoriteViewModel | null {
    const normalizedId = favoriteId.trim();
    const favorite = this.favorites.find((item: FoodFavoriteViewModel): boolean =>
      item.favoriteId === normalizedId);
    return favorite === undefined ? null : copyFoodFavorite(favorite);
  }

  async remove(favoriteId: string): Promise<boolean> {
    const normalizedId = favoriteId.trim();
    const existingIndex = this.favorites.findIndex((favorite: FoodFavoriteViewModel): boolean =>
      favorite.favoriteId === normalizedId);
    if (existingIndex < 0) {
      return false;
    }
    this.favorites.splice(existingIndex, 1);
    await this.persist();
    return true;
  }

  async toggle(item: A2uiFoodData): Promise<boolean> {
    const existingIndex = findFoodFavoriteIndex(this.favorites, item);
    if (existingIndex >= 0) {
      this.favorites.splice(existingIndex, 1);
      await this.persist();
      return false;
    }
    this.favorites.unshift(favoriteFromFood(item));
    if (this.favorites.length > MAX_FOOD_FAVORITES) {
      this.favorites.splice(MAX_FOOD_FAVORITES);
    }
    await this.persist();
    return true;
  }
}
