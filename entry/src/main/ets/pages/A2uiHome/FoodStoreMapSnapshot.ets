import {
  A2UI_COMPONENT_FOOD_CHOICES,
  A2uiFoodData,
  A2uiSurfaceState,
  foodOptions
} from '@loop/agent-core';
import { foodFavoriteId } from './FoodFavoritesStore';

export interface FoodStoreMapPoint {
  id: string;
  name: string;
  address: string;
  location: string;
  source: string;
}

export interface FoodStoreMapCenter {
  longitude: number;
  latitude: number;
  name: string;
  address: string;
}

export interface FoodStoreMapSnapshot {
  sequence: number;
  center: FoodStoreMapCenter;
  points: FoodStoreMapPoint[];
}

export function validFoodStoreLocation(location: string | undefined): string {
  if (location === undefined) {
    return '';
  }
  const parts = location.trim().split(',');
  if (parts.length !== 2) {
    return '';
  }
  const longitude = Number(parts[0]);
  const latitude = Number(parts[1]);
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
    !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    return '';
  }
  return longitude.toString() + ',' + latitude.toString();
}

export function foodStoreLocation(food: A2uiFoodData): string {
  if (food.longitude !== undefined && food.latitude !== undefined) {
    const coordinateLocation = validFoodStoreLocation(
      food.longitude.toString() + ',' + food.latitude.toString()
    );
    if (coordinateLocation.length > 0) {
      return coordinateLocation;
    }
  }
  return validFoodStoreLocation(food.location);
}

export function foodStoreMapPoints(surface: A2uiSurfaceState): FoodStoreMapPoint[] {
  for (let componentIndex = 0; componentIndex < surface.components.length; componentIndex++) {
    const component = surface.components[componentIndex];
    if (component.component !== A2UI_COMPONENT_FOOD_CHOICES) {
      continue;
    }
    const foods = foodOptions(surface, component);
    const points: FoodStoreMapPoint[] = [];
    foods.forEach((food: A2uiFoodData): void => {
      const location = foodStoreLocation(food);
      if (location.length === 0 || food.name.trim().length === 0) {
        return;
      }
      points.push({
        id: foodFavoriteId(food),
        name: food.name,
        address: food.address,
        location: location,
        source: food.sourceTags === undefined ? '' : food.sourceTags.join(' · ')
      });
    });
    return points;
  }
  return [];
}

export function buildFoodStoreMapSnapshot(
  surface: A2uiSurfaceState,
  centerLongitude: number,
  centerLatitude: number,
  centerName: string = '',
  centerAddress: string = ''
): FoodStoreMapSnapshot {
  return {
    sequence: surface.sequence,
    center: {
      longitude: centerLongitude,
      latitude: centerLatitude,
      name: centerName,
      address: centerAddress
    },
    points: foodStoreMapPoints(surface)
  };
}
