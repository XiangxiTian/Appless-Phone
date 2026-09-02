import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const renderer = readFileSync(
  new URL('entry/src/main/ets/pages/A2uiHome/html/HtmlTravelHomeRenderer.ets', root),
  'utf8'
);
const snapshot = readFileSync(
  new URL('entry/src/main/ets/pages/A2uiHome/html/HtmlHomeSnapshot.ets', root),
  'utf8'
);
const reference = readFileSync(new URL('docs/design/AIOS-Demo/css/home.css', root), 'utf8');

test('copies the AIOS Demo travel result hierarchy into the dynamic renderer', () => {
  assert.match(renderer, /AIOS Demo travel results: query header -> route -> filters -> flat options/);
  assert.match(renderer, /add\(map, 'p', 'route-label', '行程'\)/);
  assert.doesNotMatch(renderer, /add\(dateRow, 'dt', '', '出发日期'\)/);
  assert.doesNotMatch(renderer, /travel-date-details/);
  assert.match(renderer, /var controls = add\(shell, 'nav', 'travel-controls'\)/);
  assert.match(renderer, /var board = add\(shell, 'section', 'journey-board'\)/);
  assert.doesNotMatch(renderer, /setExpanded\(text\(cardBlocks\[0\]\.id\)/);
  assert.match(renderer, /add\(titleCopy, 'h1', '', queryHeadline\)/);
  assert.doesNotMatch(renderer, /client_flight_direct/);
  assert.doesNotMatch(renderer, /client_flight_airport/);
  assert.doesNotMatch(renderer, /client_flight_airline/);
  assert.doesNotMatch(renderer, /client_flight_cabin/);
});

test('uses one shared filter rail for mixed and flight-only travel results', () => {
  assert.match(renderer, /var localControls = \[[\s\S]*?travel_show_all[\s\S]*?travel_filter_train[\s\S]*?travel_filter_flight[\s\S]*?client_sort_fastest[\s\S]*?client_filter_available[\s\S]*?client_show_more[\s\S]*?\];/);
  assert.match(renderer, /var controlActions = localControls\.concat\(list\(data\.actions\)\);/);
  assert.doesNotMatch(renderer, /var localControls = flightOnly \?/);
  assert.doesNotMatch(renderer, /var primary = flightOnly/);
});

test('uses the reference gradient, city pills, filters and flat option card dimensions', () => {
  const gradient = /#b9d3ff 0%,\s*#cae2ff 18%,\s*#e4f0fb 38%,\s*#f5f8fb 62%,\s*#f8fafc 100%/;
  assert.match(reference, gradient);
  assert.match(renderer, gradient);
  assert.match(renderer, /\.route-city\s*\{[^}]*min-width:\s*88px[^}]*border-radius:\s*22px[^}]*rgba\(244, 247, 250, 0\.7\)/s);
  assert.match(renderer, /\.travel-primary-tabs \.travel-control,[\s\S]*?height:\s*37px[\s\S]*?border-radius:\s*19px/s);
  assert.match(renderer, /\.journey-card,[\s\S]*?min-height:\s*104px[\s\S]*?border-radius:\s*24px[\s\S]*?background:\s*#eef1f3/s);
  assert.match(renderer, /html,\s*body,\s*\.itinerary-shell \{ background: transparent; \}/s);
  assert.match(renderer, /resource:\/\/rawfile\/travel\/airlines\/shenzhen-airlines-symbol\.png/);
});

test('keeps travel, train and flight semantics and the native action bridge intact', () => {
  assert.match(renderer, /kind === 'travel-option' \|\| kind === 'train-option' \|\| kind === 'flight-option'/);
  assert.match(renderer, /window\.AIPhoneHome\.postAction/);
  assert.match(renderer, /travel_filter_train/);
  assert.match(renderer, /travel_filter_flight/);
  assert.match(renderer, /event\.stopPropagation\(\)/);
});

test('keeps compact travel cards to booking and calendar actions', () => {
  assert.doesNotMatch(snapshot, /html_pin_travel/);
  assert.doesNotMatch(snapshot, /html_pin_train/);
  assert.doesNotMatch(snapshot, /html_pin_flight/);
  assert.match(snapshot, /flight\.booking\.ctrip\.open/);
  assert.match(snapshot, /travelCalendarActionFor(?:Option|Train|Flight)/);
});
