import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const root = new URL('../', import.meta.url);
const renderer = readFileSync(
  new URL('entry/src/main/ets/pages/A2uiHome/html/HtmlAggregateSearchHomeRenderer.ets', root),
  'utf8'
);

test('uses a white discovery background and cold-white conversation card surfaces', () => {
  assert.match(renderer, /\.waterfall-track\s*\{[^}]*background:\s*#ffffff/s);
  assert.match(renderer, /body\.waterfall-direct \.waterfall-track \{ background: #ffffff; \}/);
  assert.match(renderer, /\.waterfall-card-shell\s*\{[^}]*background:\s*rgba\(239, 243, 248, 0\.94\)/s);
  assert.match(renderer, /\.waterfall-card--text \.waterfall-card-shell \{ background: rgba\(239, 243, 248, 0\.94\); \}/);
  assert.match(renderer, /\.waterfall-reader\s*\{[^}]*background:\s*#ffffff/s);
});

test('uses the base-conversation slate palette for discovery source preferences', () => {
  assert.match(renderer, /\.waterfall-overlay\s*\{[^}]*--accent:\s*#5f6978[^}]*--accent-soft:\s*rgba\(95, 105, 120, 0\.14\)/s);
  assert.match(renderer, /\.waterfall-preferences\s*\{[^}]*rgba\(239, 243, 248, 0\.88\)/s);
  assert.match(renderer, /\.waterfall-preferences input:checked \{ background: var\(--accent\); \}/);
  assert.match(renderer, /\.waterfall-source-reason \{ color: #6f7783;/);
  assert.doesNotMatch(renderer, /\.waterfall-preferences input:checked \{ background: #995f4c;/);
});
