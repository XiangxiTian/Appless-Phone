import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const renderer = readFileSync(
  new URL('entry/src/main/ets/pages/A2uiHome/html/HtmlFoodHomeRenderer.ets', root),
  'utf8'
);
const reference = readFileSync(new URL('docs/design/AIOS-Demo/css/home.css', root), 'utf8');

test('copies the AIOS Demo dining result hierarchy into the dynamic renderer', () => {
  assert.match(renderer, /AIOS Demo dining results: summary -> query -> location -> filters -> restaurant list/);
  assert.match(renderer, /'附近餐饮 · ' \+ String\(blocks\.length\) \+ ' 条结果'/);
  assert.match(renderer, /add\(heroContent, 'h1', '', '周边有什么好吃的？'\)/);
  assert.match(renderer, /var locationBar = add\(heroContent, 'div', 'editorial-location-bar'\)/);
  assert.match(renderer, /var tabs = add\(shell, 'nav', 'editorial-tabs appless-v2-food-tabs'\)/);
  assert.match(renderer, /var filters = add\(shell, 'section', 'food-filters appless-v2-food-filters'\)/);
  assert.match(renderer, /var listNode = add\(shell, 'section', 'editorial-list'\)/);
});

test('uses the reference dining gradient, location pill, filters and restaurant dimensions', () => {
  const gradient = /#ffecd5 0%,\s*#fff5e9 17%,\s*#f8fafc 39%,\s*#f8fafc 100%/;
  assert.match(reference, gradient);
  assert.match(renderer, gradient);
  assert.match(renderer, /\.food-current-address\s*\{[^}]*min-height:\s*42px[^}]*border-radius:\s*21px[^}]*rgba\(218, 244, 185, 0\.72\)/s);
  assert.match(renderer, /\.editorial-tab\s*\{[^}]*height:\s*36px[^}]*border-radius:\s*18px[^}]*background:\s*#eceff1/s);
  assert.match(renderer, /\.editorial-feature,[\s\S]*?min-height:\s*128px[\s\S]*?grid-template-columns:\s*112px minmax\(0, 1fr\)[\s\S]*?border-radius:\s*27px/s);
  assert.match(renderer, /resource:\/\/rawfile\/food-v2\/baheli-restaurant\.jpg/);
  assert.match(renderer, /resource:\/\/rawfile\/food-v2\/nawa-xinjiang\.jpg/);
  assert.match(renderer, /html,\s*body,\s*\.editorial-food-shell \{ background: transparent; \}/s);
  assert.match(renderer, /\.food-map-icon \{ display: none; \}/);
  assert.match(renderer, /featuredRestaurant\.focus\(\{ preventScroll: true \}\)/);
});

test('keeps nearby-food filters, local expansion and the native action bridge intact', () => {
  assert.match(renderer, /window\.AIPhoneHome\.postAction/);
  assert.match(renderer, /food_filter_1km/);
  assert.match(renderer, /food_filter_coffee/);
  assert.match(renderer, /food_filter_late/);
  assert.match(renderer, /feature\.addEventListener\('click'/);
  assert.match(renderer, /card\.addEventListener\('click'/);
  assert.match(renderer, /food_store_map_open/);
  assert.match(renderer, /food_favorite_toggle/);
  assert.match(renderer, /event\.stopPropagation\(\)/);
});
