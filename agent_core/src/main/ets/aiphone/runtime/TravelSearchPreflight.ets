export type TravelSearchMissingField = 'departure_date' | 'origin' | 'destination';

export interface TravelSearchPreflightResult {
  complete: boolean;
  departureDate: string;
  origin: string;
  destination: string;
  missingFields: TravelSearchMissingField[];
}

interface CalendarDateParts {
  year: number;
  month: number;
  day: number;
}

const WEEKDAY_VALUES: string[] = ['一', '二', '三', '四', '五', '六', '日', '天'];
const KNOWN_CITY_NAMES: string[] = [
  '北京', '上海', '天津', '重庆', '深圳', '广州', '杭州', '南京', '苏州', '成都', '武汉',
  '西安', '长沙', '郑州', '青岛', '厦门', '福州', '昆明', '贵阳', '南宁', '海口', '三亚',
  '乌鲁木齐', '拉萨', '哈尔滨', '长春', '沈阳', '大连', '济南', '合肥', '宁波', '珠海'
];

function twoDigits(value: number): string {
  return value.toString().padStart(2, '0');
}

function dateParts(value: string): CalendarDateParts | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (match === null) return null;
  const parsed = new Date(match[1] + '-' + match[2] + '-' + match[3] + 'T00:00:00Z');
  if (isNaN(parsed.getTime())) return null;
  if (parsed.toISOString().substring(0, 10) !== match[1] + '-' + match[2] + '-' + match[3]) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

function formattedDate(year: number, month: number, day: number): string {
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (isNaN(parsed.getTime())) return '';
  if (parsed.getUTCFullYear() !== year || parsed.getUTCMonth() + 1 !== month || parsed.getUTCDate() !== day) {
    return '';
  }
  return year.toString() + '-' + twoDigits(month) + '-' + twoDigits(day);
}

function dateAfterDays(date: string, days: number): string {
  const parts = dateParts(date);
  if (parts === null || !Number.isInteger(days)) return '';
  const parsed = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
  return parsed.getUTCFullYear().toString() + '-' + twoDigits(parsed.getUTCMonth() + 1) + '-' +
    twoDigits(parsed.getUTCDate());
}

function weekdayNumber(date: string): number {
  const parts = dateParts(date);
  if (parts === null) return 0;
  const weekday = new Date(Date.UTC(parts.year, parts.month - 1, parts.day)).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}

function weekdayFromText(value: string): number {
  const index = WEEKDAY_VALUES.indexOf(value);
  if (index < 0) return 0;
  return index >= 6 ? 7 : index + 1;
}

function travelDateFromText(prompt: string, nowIso: string): string {
  const base = dateParts(nowIso);
  if (base === null) return '';
  const baseDate = formattedDate(base.year, base.month, base.day);
  const iso = /(20\d{2})-(\d{1,2})-(\d{1,2})/.exec(prompt);
  if (iso !== null) return formattedDate(Number(iso[1]), Number(iso[2]), Number(iso[3]));
  const full = /(20\d{2})年(\d{1,2})月(\d{1,2})[日号]/.exec(prompt);
  if (full !== null) return formattedDate(Number(full[1]), Number(full[2]), Number(full[3]));
  const nextWeek = /下周([一二三四五六日天])/.exec(prompt);
  if (nextWeek !== null) {
    return dateAfterDays(baseDate, 7 + weekdayFromText(nextWeek[1]) - weekdayNumber(baseDate));
  }
  const thisWeek = /(?:本周|这周)([一二三四五六日天])/.exec(prompt);
  if (thisWeek !== null) {
    const offset = weekdayFromText(thisWeek[1]) - weekdayNumber(baseDate);
    return dateAfterDays(baseDate, offset < 0 ? offset + 7 : offset);
  }
  if (prompt.indexOf('后天') >= 0) return dateAfterDays(baseDate, 2);
  if (prompt.indexOf('明天') >= 0) return dateAfterDays(baseDate, 1);
  if (prompt.indexOf('今天') >= 0) return baseDate;
  const nextMonth = /下个月(\d{1,2})[日号]/.exec(prompt);
  if (nextMonth !== null) {
    const monthIndex = base.month;
    return formattedDate(base.year + Math.floor(monthIndex / 12), monthIndex % 12 + 1, Number(nextMonth[1]));
  }
  const monthDay = /(\d{1,2})月(\d{1,2})(?:[日号])?(?!\d)/.exec(prompt);
  if (monthDay === null) return '';
  let result = formattedDate(base.year, Number(monthDay[1]), Number(monthDay[2]));
  if (result.length > 0 && result < baseDate) {
    result = formattedDate(base.year + 1, Number(monthDay[1]), Number(monthDay[2]));
  }
  return result;
}

function normalizedCity(value: string): string {
  let text = value.trim().replace(/^[从在到去往前往]+/, '').replace(/[市县区]$/, '');
  text = text.replace(/(?:出发|出差|开会|办事|旅游|旅行).*$/, '').trim();
  return text === '未记录' || text === '暂无' ? '' : text.substring(0, 16);
}

function originFromText(prompt: string): string {
  const from = /从([\u4e00-\u9fa5A-Za-z]{2,16}?)(?:出发|去|到|前往)/.exec(prompt);
  if (from !== null) return normalizedCity(from[1]);
  const located = /我在([\u4e00-\u9fa5A-Za-z]{2,16}?)(?:[，,。 ]|下周|本周|这周|今天|明天|后天|要去|去|到|出差|$)/
    .exec(prompt);
  if (located !== null) return normalizedCity(located[1]);
  for (let index = 0; index < KNOWN_CITY_NAMES.length; index++) {
    const city = KNOWN_CITY_NAMES[index];
    if (prompt === city || prompt.indexOf(city + '出发') >= 0) return city;
  }
  const directMatch = /^(?:我在|当前位置是|出发地是|出发地[：:])?\s*([\u4e00-\u9fa5A-Za-z]{2,8})$/
    .exec(prompt.trim());
  if (directMatch === null || /周|今天|明天|后天|出差|开会|旅游|旅行|要去|前往/.test(prompt)) return '';
  const direct = normalizedCity(directMatch[1]);
  return direct.length >= 2 && direct.length <= 8 ? direct : '';
}

function destinationFromText(prompt: string): string {
  const directed = /(?:去|到|前往)([\u4e00-\u9fa5A-Za-z]{2,16}?)(?:出差|开会|办事|旅游|旅行)/.exec(prompt);
  if (directed !== null) return normalizedCity(directed[1]);
  for (let index = 0; index < KNOWN_CITY_NAMES.length; index++) {
    if (prompt.indexOf(KNOWN_CITY_NAMES[index]) >= 0) return KNOWN_CITY_NAMES[index];
  }
  return '';
}

function orderedKnownCities(prompt: string): string[] {
  const matches: string[] = [];
  const offsets: number[] = [];
  for (let index = 0; index < KNOWN_CITY_NAMES.length; index++) {
    const city = KNOWN_CITY_NAMES[index];
    const offset = prompt.indexOf(city);
    if (offset < 0) continue;
    let insertion = 0;
    while (insertion < offsets.length && offsets[insertion] <= offset) insertion++;
    offsets.splice(insertion, 0, offset);
    matches.splice(insertion, 0, city);
  }
  return matches;
}

export function travelSearchPreflight(
  prompt: string,
  nowIso: string
): TravelSearchPreflightResult {
  const firstSegment = prompt.split('；')[0];
  let departureDate = travelDateFromText(firstSegment, nowIso);
  if (departureDate.length === 0) departureDate = travelDateFromText(prompt, nowIso);
  let origin = '';
  let destination = '';
  const knownCities = orderedKnownCities(prompt);
  if (origin.length === 0) {
    origin = originFromText(prompt);
    if (origin.length === 0 && knownCities.length >= 2) origin = knownCities[0];
  }
  if (destination.length === 0) {
    destination = destinationFromText(prompt);
    if (knownCities.length >= 2 && destination === origin) destination = knownCities[1];
  }
  const missingFields: TravelSearchMissingField[] = [];
  if (departureDate.length === 0) missingFields.push('departure_date');
  if (origin.length === 0) missingFields.push('origin');
  if (destination.length === 0 || destination === origin) missingFields.push('destination');
  return { complete: missingFields.length === 0, departureDate, origin, destination, missingFields };
}
