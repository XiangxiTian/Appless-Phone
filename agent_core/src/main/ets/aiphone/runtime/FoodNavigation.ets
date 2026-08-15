export interface FoodNavigationUriDebug {
  uri: string;
  mode: string;
  destination: string;
  origin: string;
  name: string;
}

function cleanCoordinate(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const parsed = Number(trimmed);
  if (!Number.isFinite(parsed)) {
    return '';
  }
  return trimmed;
}

export function foodMapsLatLng(location: string): string {
  const parts = location.split(',');
  if (parts.length < 2) {
    return '';
  }
  const longitude = cleanCoordinate(parts[0]);
  const latitude = cleanCoordinate(parts[1]);
  if (longitude.length === 0 || latitude.length === 0) {
    return '';
  }
  return latitude + ',' + longitude;
}

function encodeMapParam(value: string): string {
  return encodeURIComponent(value)
    .replace(/\(/g, '%28')
    .replace(/\)/g, '%29')
    .replace(/'/g, '%27');
}

function cleanDestinationName(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length > 0) {
    return trimmed;
  }
  return '目的地';
}

export function describeSystemFoodNavigationUri(destinationLocation: string, originLocation: string,
  destinationName: string = ''): FoodNavigationUriDebug {
  const destination = foodMapsLatLng(destinationLocation);
  if (destination.length === 0) {
    return { uri: '', mode: 'invalid_destination', destination: '', origin: '', name: '' };
  }
  const origin = foodMapsLatLng(originLocation);
  const name = cleanDestinationName(destinationName);
  return {
    uri: 'petalmaps://poidetail?center=' + destination + '&z=16&marker=' + destination +
      '&name=' + encodeMapParam(name) + '&utm_source=com.jiuwen.appless',
    mode: 'destination_poi_detail',
    destination: destination,
    origin: origin,
    name: name
  };
}

export function buildSystemFoodNavigationUri(destinationLocation: string, originLocation: string,
  destinationName: string = ''): string {
  return describeSystemFoodNavigationUri(destinationLocation, originLocation, destinationName).uri;
}

export function buildSystemPlaceNavigationUri(destinationName: string): string {
  const name = destinationName.trim();
  if (name.length === 0) {
    return '';
  }
  return 'petalmaps://navigation?daddr=' + encodeMapParam(name) +
    '&language=zh&type=drive&utm_source=com.jiuwen.appless';
}

export function normalizeFoodPhoneNumber(phone: string): string {
  const value = phone.trim();
  if (value.length === 0 || /[\u0000-\u001F\u007F]/.test(value)) {
    return '';
  }
  if (value.indexOf(',') >= 0 || value.indexOf(';') >= 0 || value.indexOf('*') >= 0 || value.indexOf('#') >= 0) {
    return '';
  }
  if (!/^\+?[0-9][0-9 ()-]*$/.test(value)) {
    return '';
  }
  const normalized = value.replace(/[ ()-]/g, '');
  const digits = normalized.charAt(0) === '+' ? normalized.substring(1) : normalized;
  if (digits.length < 6 || digits.length > 15 || !/^[0-9]+$/.test(digits)) {
    return '';
  }
  return (normalized.charAt(0) === '+' ? '+' : '') + digits;
}

export function buildFoodPhoneUri(phone: string): string {
  const normalized = normalizeFoodPhoneNumber(phone);
  return normalized.length > 0 ? 'tel:' + normalized : '';
}
