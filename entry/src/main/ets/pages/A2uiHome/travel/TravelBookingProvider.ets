import {
  A2uiFlightData,
  A2uiTravelOptionData
} from '@loop/agent-core';

const CTRIP_MOBILE_FLIGHT_BOOKING_PREFIX: string =
  'https://m.ctrip.com/html5/flight/swift/domestic/';

export interface CtripFlightBookingSelection {
  flightNumber: string;
  travelDate: string;
  fromCode: string;
  toCode: string;
}

export function isAllowedCtripFlightBookingUrl(url: string): boolean {
  const value = url.trim();
  if (!value.startsWith(CTRIP_MOBILE_FLIGHT_BOOKING_PREFIX) || value.indexOf('\\') >= 0 ||
    value.indexOf('@') >= 0 || value.indexOf('?') >= 0 || value.indexOf('#') >= 0) return false;
  const routeAndDate = value.substring(CTRIP_MOBILE_FLIGHT_BOOKING_PREFIX.length);
  return /^[A-Z]{3}\/[A-Z]{3}\/\d{4}-\d{2}-\d{2}$/.test(routeAndDate);
}

function isFlightAirportCode(value: string): boolean {
  return /^[A-Z]{3}$/.test(value.trim());
}

function isFlightTravelDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value.trim());
}

function flightCityCodeFromText(value: string): string {
  const text = value.trim();
  if (/^[A-Za-z]{3}$/.test(text)) return text.toUpperCase();
  const cities: string[][] = [
    ['北京', 'BJS'], ['上海', 'SHA'], ['广州', 'CAN'], ['深圳', 'SZX'], ['杭州', 'HGH'],
    ['成都', 'CTU'], ['重庆', 'CKG'], ['西安', 'SIA'], ['南京', 'NKG'], ['武汉', 'WUH'],
    ['厦门', 'XMN'], ['青岛', 'TAO'], ['长沙', 'CSX'], ['昆明', 'KMG'], ['海口', 'HAK'],
    ['三亚', 'SYX']
  ];
  for (let index = 0; index < cities.length; index++) {
    if (text.indexOf(cities[index][0]) >= 0) return cities[index][1];
  }
  return '';
}

export function ctripFlightBookingSelection(item: A2uiFlightData): CtripFlightBookingSelection {
  const suppliedDeparture = item.depCode === undefined ? '' : item.depCode;
  const suppliedArrival = item.arrCode === undefined ? '' : item.arrCode;
  let departureCode = flightCityCodeFromText(suppliedDeparture);
  let arrivalCode = flightCityCodeFromText(suppliedArrival);
  if (departureCode.length === 0) departureCode = flightCityCodeFromText(item.dep);
  if (arrivalCode.length === 0) arrivalCode = flightCityCodeFromText(item.arr);
  let date = item.travelDate === undefined ? '' : item.travelDate.trim();
  if (!isFlightTravelDate(date)) {
    const dateMatch = /\d{4}-\d{2}-\d{2}/.exec(item.depTime);
    date = dateMatch === null ? '' : dateMatch[0];
  }
  return {
    flightNumber: item.flightNo.trim(),
    travelDate: date,
    fromCode: departureCode,
    toCode: arrivalCode
  };
}

export function ctripTravelOptionBookingSelection(item: A2uiTravelOptionData): CtripFlightBookingSelection {
  const suppliedDeparture = item.fromCode === undefined ? '' : item.fromCode;
  const suppliedArrival = item.toCode === undefined ? '' : item.toCode;
  let departureCode = flightCityCodeFromText(suppliedDeparture);
  let arrivalCode = flightCityCodeFromText(suppliedArrival);
  if (departureCode.length === 0) departureCode = flightCityCodeFromText(item.from);
  if (arrivalCode.length === 0) arrivalCode = flightCityCodeFromText(item.to);
  const date = item.travelDate === undefined ? '' : item.travelDate.trim();
  return {
    flightNumber: item.title.trim(),
    travelDate: isFlightTravelDate(date) ? date : '',
    fromCode: departureCode,
    toCode: arrivalCode
  };
}

export function buildCtripFlightSearchUrl(selection: CtripFlightBookingSelection): string {
  if (!isFlightAirportCode(selection.fromCode) || !isFlightAirportCode(selection.toCode) ||
    !isFlightTravelDate(selection.travelDate)) return '';
  return CTRIP_MOBILE_FLIGHT_BOOKING_PREFIX + selection.fromCode + '/' +
    selection.toCode + '/' + selection.travelDate;
}

export function buildCtripFlightSelectionContext(selection: CtripFlightBookingSelection): string {
  const serviceNumber = selection.flightNumber.length > 0 ? selection.flightNumber : '待核对航班';
  return '已选 ' + serviceNumber + ' · ' + selection.travelDate + ' · ' +
    selection.fromCode + ' → ' + selection.toCode;
}
