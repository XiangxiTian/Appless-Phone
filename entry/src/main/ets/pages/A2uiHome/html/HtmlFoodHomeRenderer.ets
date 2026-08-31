import { HtmlHomeBlock, HtmlHomeDocument, HtmlHomeMetric } from './HtmlHomeTypes';
import { A2uiFoodData, rideAmapWebKeyForUi } from '@loop/agent-core';
import { APP_LOGO_AMAP, APP_LOGO_BAIDU_MAPS, APP_LOGO_GOOGLE_MAPS, APP_LOGO_KFC, APP_LOGO_LUCKIN, APP_LOGO_MCDONALDS, APP_LOGO_MEITUAN, APP_LOGO_TAOBAO, APP_LOGO_TENCENT_MAPS } from './AppLogoDataUri';
import { personaAvatarDataUri } from './PersonaAvatarDataUri';
import { renderFoodLocationPickerHtml } from './FoodLocationPickerHtmlRenderer';
import { FoodLocationViewModel, FoodSavedAddressViewModel } from '../FoodAddressBookStore';
import { FoodFavoriteViewModel, foodFavoriteId } from '../FoodFavoritesStore';

type HtmlFoodTextValue = Object | string | number | boolean | null | undefined;

interface HtmlFoodHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
  personaAvatarDataUri?: string;
  foodLocation?: FoodLocationViewModel;
  foodAddressBook?: FoodSavedAddressViewModel[];
  foodFavorites?: FoodFavoriteViewModel[];
  foodLocationPickerHtml?: string;
  foodAmapKey?: string;
}

function metricValue(block: HtmlHomeBlock, label: string): string {
  for (let index = 0; index < block.metrics.length; index++) {
    const metric: HtmlHomeMetric = block.metrics[index];
    if (metric.label === label) {
      return metric.value;
    }
  }
  return '';
}

function foodFromBlock(block: HtmlHomeBlock): A2uiFoodData {
  const source = block.source === undefined ? '' : block.source;
  return {
    name: block.title,
    category: metricValue(block, 'category'),
    address: metricValue(block, 'address'),
    distance: metricValue(block, 'distance'),
    location: metricValue(block, 'location'),
    sourceTags: source.length === 0 ? [] : source.split(' / '),
    priceText: metricValue(block, 'priceText'),
    ratingText: metricValue(block, 'ratingText'),
    businessStatusLabel: metricValue(block, 'businessStatusLabel')
  };
}

function foodBlocksWithFavorites(blocks: HtmlHomeBlock[], favorites: FoodFavoriteViewModel[]): HtmlHomeBlock[] {
  const favoriteIds: Set<string> = new Set<string>();
  favorites.forEach((favorite: FoodFavoriteViewModel): void => {
    favoriteIds.add(favorite.favoriteId);
  });
  const resolvedBlocks = blocks.map((block: HtmlHomeBlock): HtmlHomeBlock => {
    if (block.kind !== 'food-result') {
      return block;
    }
    const food = foodFromBlock(block);
    const favoriteId = foodFavoriteId(food);
    block.foodFavoriteId = favoriteId;
    block.foodFavorite = favoriteIds.has(favoriteId);
    return block;
  });
  resolvedBlocks.sort((left: HtmlHomeBlock, right: HtmlHomeBlock): number => {
    const leftFavorite = left.kind === 'food-result' && left.foodFavorite === true;
    const rightFavorite = right.kind === 'food-result' && right.foodFavorite === true;
    return leftFavorite === rightFavorite ? 0 : (leftFavorite ? -1 : 1);
  });
  return resolvedBlocks;
}

const FOOD_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #fffdf9;
  --panel: rgba(255, 255, 255, 0.88);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #7a6e64;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --cream: #ffffff;
  --tomato: #d8492f;
  --gold: #d8a63f;
  --food-amap: #16875b;
  --food-tencent: #1f79a9;
  --food-baidu: #b94b65;
  --food-meituan: #c27a10;
  --food-taobao: #d95d1b;
  --food-mcd: #b97908;
  --food-kfc: #c8102e;
  --food-luckin: #356fc0;
  --food-google-maps: #4285f4;
  --food-local: #815f3e;
  --shadow: 0 10px 28px rgba(44, 34, 26, 0.08);
  --radius-xl: 20px;
  --radius-lg: 16px;
  --radius-md: 12px;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
.editorial-food-shell {
  width: min(100%, 760px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(84px + env(safe-area-inset-bottom, 0px));
  background: var(--paper);
}
.editorial-cover {
  position: relative;
  min-height: 360px;
  padding: 22px 18px 22px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  background: linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  color: #fff;
}
.editorial-cover-media {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(24, 13, 8, 0.18) 0%, rgba(24, 13, 8, 0.2) 38%, rgba(24, 13, 8, 0.76) 100%),
    url("https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80"),
    linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  background-size: cover;
  background-position: center;
  transform: scale(1.02);
}
.editorial-cover::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 58px;
  background: linear-gradient(180deg, rgba(248, 242, 232, 0), var(--paper));
}
.editorial-cover-content {
  position: relative;
  z-index: 1;
}
.persona-banner {
  position: relative;
  z-index: 1;
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: 14px;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 18px;
  padding: 10px 12px;
  background: rgba(23, 18, 13, 0.38);
  color: #fffaf1;
  backdrop-filter: blur(16px);
}
.persona-avatar {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 14px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--food-luckin);
  font-size: 15px;
  font-weight: 840;
}
.persona-avatar img {
  width: 30px;
  height: 30px;
  object-fit: contain;
}
.persona-copy {
  min-width: 0;
  flex: 1 1 auto;
}
.persona-title {
  font-size: 14px;
  font-weight: 840;
  line-height: 1.25;
}
.persona-subtitle {
  margin-top: 4px;
  color: rgba(255, 250, 241, 0.78);
  font-size: 12px;
  line-height: 1.4;
}
.editorial-location-bar {
  display: grid;
  grid-template-columns: auto minmax(0, 132px) 36px 36px;
  align-items: center;
  gap: 10px;
  width: 100%;
}
.editorial-kicker {
  display: inline-flex;
  align-items: center;
  justify-self: start;
  min-height: 28px;
  padding: 7px 10px;
  border: 1px solid rgba(255, 255, 255, 0.34);
  border-radius: 999px;
  background: rgba(23, 18, 13, 0.28);
  color: #fff7e9;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  backdrop-filter: blur(14px);
}
.food-current-address { min-width: 0; overflow: hidden; border: 0; border-bottom: 1px solid rgba(255,255,255,.72); padding: 5px 1px 4px; background: transparent; color: #fff9ee; font-size: 12px; font-weight: 780; text-align: left; text-overflow: ellipsis; white-space: nowrap; }
.food-current-address::after { content: '▼'; margin-left: 5px; font-size: 8px; }
.food-map-icon { box-sizing: border-box; display: flex; width: 36px; height: 36px; align-items: center; justify-content: center; padding: 0; border: 1px solid rgba(255,255,255,.34); border-radius: 12px; background: rgba(23,18,13,.30); color: #fff; line-height: 0; }
.food-map-icon svg { display: block; width: 19px; height: 19px; }
.food-favorites-icon { position: relative; font-size: 20px; line-height: 1; }
.food-favorites-count { position: absolute; top: -5px; right: -5px; display: grid; place-items: center; min-width: 17px; height: 17px; padding: 0 4px; border-radius: 9px; background: var(--gold); color: #211b17; font-size: 9px; font-weight: 900; }
.editorial-cover h1 {
  margin: 18px 0 10px;
  max-width: 7.4em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 48px;
  line-height: 0.96;
  font-weight: 760;
}
.editorial-cover p {
  margin: 0;
  max-width: 27em;
  overflow-wrap: anywhere;
  color: rgba(255, 250, 241, 0.86);
  font-size: 14px;
  line-height: 1.55;
}
.food-location-map {
  position: relative;
  height: 104px;
  margin-top: 12px;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.38);
  border-radius: 16px;
  background: #e6ece5;
  box-shadow: 0 8px 20px rgba(24, 13, 8, 0.18);
}
.food-location-frame { width: 100%; height: 100%; border: 0; pointer-events: none; }
.food-location-actions { position: absolute; z-index: 2; top: 8px; right: 8px; display: flex; gap: 7px; }
.food-location-action { min-height: 32px; padding: 7px 10px; border: 1px solid rgba(38, 34, 29, 0.13); border-radius: 999px; background: rgba(255, 255, 255, 0.96); color: #3f382f; font-size: 11px; font-weight: 820; box-shadow: 0 4px 12px rgba(26, 22, 18, 0.16); }
.food-location-label { position: absolute; z-index: 2; left: 8px; bottom: 8px; max-width: calc(100% - 16px); padding: 6px 10px; overflow: hidden; border-radius: 999px; background: rgba(30, 27, 23, 0.78); color: #fff; font-size: 11px; font-weight: 760; text-overflow: ellipsis; white-space: nowrap; }
.food-map-overlay { position: fixed; z-index: 80; inset: 0; display: none; flex-direction: column; background: #f6f3ec; }
.food-map-overlay.open { display: flex; }
.food-map-overlay-head { display: flex; align-items: center; min-height: 54px; padding: 8px 12px; gap: 10px; background: #f6f3ec; }
.food-map-overlay-title { flex: 1; color: var(--ink); font-size: 17px; font-weight: 820; }
.food-map-overlay-close { min-height: 34px; padding: 7px 12px; border: 0; border-radius: 999px; background: #e9e3d9; color: var(--ink); font-weight: 760; }
.food-map-picker-frame { flex: 1; width: 100%; border: 0; }
.food-address-overlay { position: fixed; z-index: 90; inset: 0; display: none; flex-direction: column; overflow: hidden; background: var(--paper); color: var(--ink); }
.food-address-overlay.open { display: flex; }
.food-favorites-overlay { position: fixed; z-index: 95; inset: 0; display: none; flex-direction: column; overflow: hidden; background: var(--paper); color: var(--ink); }
.food-favorites-overlay.open { display: flex; }
.food-menu-overlay { position: fixed; z-index: 110; inset: 0; display: none; flex-direction: column; overflow: hidden; background: #f4f6fb; color: var(--ink); }
.food-menu-overlay.open { display: flex; }
.food-menu-head { display: grid; grid-template-columns: 38px minmax(0, 1fr); align-items: center; gap: 9px; padding: 12px 14px; border-bottom: 1px solid rgba(53,111,192,.14); background: #fff; }
.food-menu-title { overflow: hidden; font-size: 18px; font-weight: 840; text-overflow: ellipsis; white-space: nowrap; }
.food-menu-store { padding: 13px 16px 10px; background: #fff; color: #356fc0; font-size: 13px; font-weight: 760; }
.food-menu-scroll { flex: 1; overflow-y: auto; padding: 12px 14px 28px; }
.food-menu-state { margin-top: 48px; color: var(--muted); text-align: center; line-height: 1.65; }
.food-menu-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 11px; }
.food-menu-product { min-width: 0; overflow: hidden; border: 1px solid rgba(53,111,192,.12); border-radius: 16px; background: #fff; box-shadow: 0 8px 20px rgba(39,61,94,.07); }
.food-menu-picture { width: 100%; aspect-ratio: 1; display: block; object-fit: cover; background: #edf1f8; }
.food-menu-picture-empty { display: grid; place-items: center; color: #356fc0; font-size: 28px; }
.food-menu-copy { padding: 10px; }
.food-menu-product-name { min-height: 40px; font-size: 14px; font-weight: 780; line-height: 1.4; }
.food-menu-price { margin-top: 7px; color: #356fc0; font-size: 16px; font-weight: 850; }
.food-menu-original-price { margin-left: 6px; color: #a1a6af; font-size: 11px; font-weight: 500; text-decoration: line-through; }
.food-menu-tags { margin-top: 6px; color: #c58b25; font-size: 11px; }
.food-menu-options { margin-top: 6px; color: #7e8794; font-size: 10px; line-height: 1.45; }
.food-menu-order { width: 100%; min-height: 36px; margin-top: 10px; border: 0; border-radius: 11px; background: linear-gradient(135deg, #356fc0, #224f94); color: #fff; font-size: 12px; font-weight: 800; }
.food-menu-order:disabled { background: #d9dde5; color: #8c929d; }
.food-menu-order.mcd { background: linear-gradient(135deg, #d71920, #a80e13); }
.food-menu-detail { display: grid; gap: 14px; }
.food-menu-detail-hero { display: grid; grid-template-columns: 108px minmax(0, 1fr); gap: 14px; align-items: center; padding: 14px; border: 1px solid rgba(215,25,32,.12); border-radius: 18px; background: #fff; }
.food-menu-detail-hero .food-menu-picture { border-radius: 13px; }
.food-menu-detail-name { font-size: 19px; font-weight: 850; line-height: 1.35; }
.food-menu-detail-price { margin-top: 7px; color: #d71920; font-size: 20px; font-weight: 850; }
.food-menu-detail-rows { overflow: hidden; border: 1px solid rgba(73,63,56,.1); border-radius: 16px; background: #fff; }
.food-menu-detail-row { display: grid; grid-template-columns: 90px minmax(0, 1fr); gap: 10px; padding: 11px 13px; border-bottom: 1px solid rgba(73,63,56,.08); font-size: 13px; line-height: 1.5; }
.food-menu-detail-row:last-child { border-bottom: 0; }
.food-menu-detail-row b { color: #51443c; }
.food-menu-detail-row span { color: #74665c; overflow-wrap: anywhere; }
.food-menu-quantity { display: flex; align-items: center; justify-content: space-between; padding: 13px 14px; border-radius: 16px; background: #fff; }
.food-menu-stepper { display: flex; align-items: center; gap: 13px; }
.food-menu-stepper button { width: 34px; height: 34px; border: 0; border-radius: 11px; background: #f2ece8; color: #5e4d43; font-size: 20px; font-weight: 800; }
.food-menu-stepper strong { min-width: 20px; text-align: center; }
.food-menu-checkout-actions { display: grid; gap: 9px; }
.food-menu-checkout-primary, .food-menu-checkout-secondary { min-height: 46px; border: 0; border-radius: 14px; font-size: 14px; font-weight: 830; }
.food-menu-checkout-primary { background: linear-gradient(135deg, #d71920, #a80e13); color: #fff; }
.food-menu-checkout-primary:disabled { background: #d9dde5; color: #8c929d; }
.food-menu-checkout-secondary { border: 1px solid rgba(73,63,56,.12); background: #fff; color: #5e4d43; }
.food-menu-warning { padding: 11px 13px; border-radius: 13px; background: #fff4df; color: #8a5b16; font-size: 12px; line-height: 1.55; }
.food-menu-success { padding: 14px; border-radius: 16px; background: #edf8ef; color: #236233; font-size: 14px; font-weight: 760; line-height: 1.55; }
.food-favorites-head { display: grid; grid-template-columns: 38px minmax(0, 1fr); align-items: center; gap: 9px; padding: 12px 14px; border-bottom: 1px solid var(--line); }
.food-favorites-title { font-size: 18px; font-weight: 840; }
.food-favorites-scroll { flex: 1; overflow-y: auto; padding: 14px; }
.food-favorite-saved-card.editorial-card { margin: 0 0 12px; padding: 12px; border: 1px solid var(--line); border-radius: 18px; background: #fff; box-shadow: 0 10px 24px rgba(37,24,13,.07); }
.food-favorite-saved-card.editorial-card::before { display: none; }
.food-address-top { display: grid; grid-template-columns: 38px minmax(0, 1fr); align-items: center; gap: 9px; padding: 12px 14px 8px; }
.food-address-back { width: 38px; height: 40px; border: 0; background: transparent; color: var(--ink); font-size: 27px; }
.food-address-search-wrap { display: flex; min-width: 0; height: 42px; align-items: center; gap: 7px; padding: 0 12px; border-radius: 22px; background: #fff; }
.food-address-search-icon { color: #9b9b9b; font-size: 18px; }
.food-address-search { min-width: 0; flex: 1; border: 0; outline: 0; background: transparent; color: var(--ink); font-size: 14px; }
.food-address-scroll { flex: 1; overflow-y: auto; padding: 8px 14px 24px; }
.food-address-current-choice { padding: 10px 14px 14px; color: #969696; font-size: 13px; }
.food-address-card { box-sizing: border-box; width: 100%; margin-bottom: 12px; overflow: hidden; border-radius: 18px; background: #fff; }
.food-address-section-head { display: flex; align-items: center; gap: 10px; padding: 15px 15px 8px; color: #999; font-size: 13px; }
.food-address-section-head b { flex: 1; color: #999; font-weight: 500; }
.food-address-section-action { border: 0; background: transparent; color: #1681d8; font-size: 13px; }
.food-current-location-row { display: flex; align-items: center; gap: 10px; padding: 8px 15px 17px; }
.food-current-location-copy { min-width: 0; flex: 1; }
.food-current-location-name { overflow: hidden; font-size: 16px; font-weight: 680; text-overflow: ellipsis; white-space: nowrap; }
.food-current-location-detail { margin-top: 4px; overflow: hidden; color: #999; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.food-address-empty { padding: 20px 15px; color: var(--muted); text-align: center; line-height: 1.6; }
.food-address-list { display: grid; }
.food-address-row { box-sizing: border-box; display: grid; grid-template-columns: minmax(0, 1fr) 48px; align-items: center; gap: 8px; width: 100%; min-height: 68px; padding: 12px 15px; overflow: hidden; border-top: 1px solid #f0f0f0; background: #fff; }
.food-address-copy { min-width: 0; max-width: 100%; overflow: hidden; }
.food-address-name { overflow: hidden; color: var(--ink); font-weight: 780; text-overflow: ellipsis; white-space: nowrap; }
.food-address-detail { margin-top: 3px; overflow: hidden; color: var(--muted); font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.food-address-delete { box-sizing: border-box; width: 48px; min-width: 48px; min-height: 34px; padding: 7px 4px; border: 0; background: transparent; color: #a35a50; font-weight: 720; white-space: nowrap; }
.food-location-results { display: none; }
.food-location-results.active { display: block; }
.food-location-result { width: 100%; padding: 15px; border: 0; border-top: 1px solid #f0f0f0; background: #fff; text-align: left; }
.food-location-result:first-child { border-top: 0; }
.food-location-result-name { overflow: hidden; color: var(--ink); font-size: 16px; font-weight: 680; text-overflow: ellipsis; white-space: nowrap; }
.food-location-result-address { margin-top: 5px; overflow: hidden; color: #999; font-size: 12px; text-overflow: ellipsis; white-space: nowrap; }
.food-location-status { padding: 26px 15px; color: #999; text-align: center; }
.source-cloud {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 18px;
}
.source-pill {
  --source-accent: var(--food-local);
  border: 1px solid rgba(255, 255, 255, 0.26);
  border-radius: 999px;
  padding: 8px 10px;
  max-width: 100%;
  background: rgba(23, 18, 13, 0.44);
  color: #fffaf1;
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
  box-shadow: inset 0 -2px 0 var(--source-accent);
  backdrop-filter: blur(16px);
}
.source-pill[data-source-key="food-amap"], .editorial-card[data-source-key="food-amap"], .editorial-feature[data-source-key="food-amap"] { --source-accent: var(--food-amap); }
.source-pill[data-source-key="food-tencent"], .editorial-card[data-source-key="food-tencent"], .editorial-feature[data-source-key="food-tencent"] { --source-accent: var(--food-tencent); }
.source-pill[data-source-key="food-baidu"], .editorial-card[data-source-key="food-baidu"], .editorial-feature[data-source-key="food-baidu"] { --source-accent: var(--food-baidu); }
.source-pill[data-source-key="food-meituan"], .editorial-card[data-source-key="food-meituan"], .editorial-feature[data-source-key="food-meituan"] { --source-accent: var(--food-meituan); }
.source-pill[data-source-key="food-taobao"], .editorial-card[data-source-key="food-taobao"], .editorial-feature[data-source-key="food-taobao"] { --source-accent: var(--food-taobao); }
.source-pill[data-source-key="food-mcd"], .editorial-card[data-source-key="food-mcd"], .editorial-feature[data-source-key="food-mcd"] { --source-accent: var(--food-mcd); }
.source-pill[data-source-key="food-kfc"], .editorial-card[data-source-key="food-kfc"], .editorial-feature[data-source-key="food-kfc"] { --source-accent: var(--food-kfc); }
.source-pill[data-source-key="food-luckin"], .editorial-card[data-source-key="food-luckin"], .editorial-feature[data-source-key="food-luckin"] { --source-accent: var(--food-luckin); }
.source-pill[data-source-key="food-google-maps"], .editorial-card[data-source-key="food-google-maps"], .editorial-feature[data-source-key="food-google-maps"] { --source-accent: var(--food-google-maps); }
.source-pill[data-source-key="food-local"], .editorial-card[data-source-key="food-local"], .editorial-feature[data-source-key="food-local"] { --source-accent: var(--food-local); }
.cover-stats {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 9px;
  margin-top: 14px;
}
.cover-stat {
  border-radius: 999px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ink);
  font-size: 11px;
  font-weight: 840;
  line-height: 1;
}
.editorial-tabs {
  position: sticky;
  top: 0;
  z-index: 6;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  background: rgba(248, 242, 232, 0.9);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.editorial-tabs::-webkit-scrollbar { display: none; }
.editorial-tab {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 38px;
  padding: 10px 14px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 780;
  line-height: 1;
  box-shadow: 0 8px 18px rgba(37, 24, 13, 0.06);
  transition: transform 140ms ease, box-shadow 140ms ease, background 140ms ease;
}
.editorial-tab.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--cream);
  box-shadow: 0 12px 24px rgba(37, 24, 13, 0.18);
}
.editorial-tab:active { transform: translateY(1px); }
.food-filters {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  padding: 12px 14px 6px;
}
.food-control { display: grid; gap: 5px; color: var(--muted); font-size: 11px; font-weight: 760; }
.food-control select {
  width: 100%; min-height: 38px; border: 1px solid var(--line); border-radius: 12px; padding: 8px 10px;
  background: rgba(255, 250, 241, 0.94); color: var(--ink); font: inherit; font-size: 12px;
}
.food-filters > button { align-self: end; }
@media (min-width: 620px) { .food-filters { grid-template-columns: repeat(5, minmax(0, 1fr)); padding-left: 22px; padding-right: 22px; } }
.editorial-feature {
  --source-accent: var(--food-local);
  position: relative;
  margin: 10px 14px 18px;
  overflow: hidden;
  border-radius: var(--radius-xl);
  background: #17120d;
  color: #fffaf1;
  box-shadow: var(--shadow);
}
.editorial-feature-media {
  min-height: 160px;
  background:
    linear-gradient(180deg, rgba(23, 18, 13, 0.02) 0%, rgba(23, 18, 13, 0.08) 48%, rgba(23, 18, 13, 0.36) 100%),
    url("https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=900&q=80"),
    linear-gradient(135deg, #17120d 0%, var(--source-accent) 72%, #e8b451 100%);
  background-size: cover;
  background-position: center;
}
.editorial-feature-copy {
  padding: 14px;
}
.editorial-feature-label {
  color: var(--gold);
  font-size: 11px;
  font-weight: 860;
  line-height: 1;
}
.editorial-feature h2 {
  margin: 9px 0 8px;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 29px;
  line-height: 1.02;
  font-weight: 760;
}
.editorial-feature p {
  margin: 0;
  color: rgba(255, 250, 241, 0.78);
  font-size: 13px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.editorial-list {
  display: grid;
  gap: 10px;
  padding: 0 14px 18px;
}
.editorial-card {
  --source-accent: var(--food-local);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.92)),
    rgba(255, 250, 241, 0.94);
  box-shadow: 0 14px 34px rgba(37, 24, 13, 0.1);
}
.food-favorite-toggle { position: absolute; z-index: 3; right: 12px; bottom: 12px; display: grid; place-items: center; width: 38px; height: 38px; padding: 0; border: 1px solid rgba(122,103,79,.25); border-radius: 13px; background: rgba(255,250,241,.94); color: #9b9084; font-size: 23px; line-height: 1; box-shadow: 0 7px 16px rgba(37,24,13,.09); }
.food-favorite-toggle.active { border-color: rgba(216,166,63,.55); background: #fff7df; color: #d39a24; }
.food-card-footer { display: flex; align-items: center; justify-content: space-between; gap: 10px; margin-top: 10px; }
.food-card-footer .editorial-source-row { flex: 1; min-width: 0; margin: 0; }
.food-card-footer .food-favorite-toggle { position: static; flex: 0 0 auto; }
.editorial-feature .food-favorite-toggle { color: rgba(255,250,241,.58); background: rgba(23,18,13,.58); border-color: rgba(255,255,255,.24); }
.editorial-feature .food-favorite-toggle.active { color: #f2bf4a; background: rgba(23,18,13,.78); }
.editorial-card::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 6px;
  background: linear-gradient(180deg, var(--source-accent), rgba(216, 166, 63, 0.36));
}
.editorial-card-head {
  display: grid;
  grid-template-columns: 46px minmax(0, 1fr) auto;
  gap: 10px;
  align-items: start;
}
.merchant-avatar {
  position: relative;
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.08);
  border-radius: 16px;
  background: var(--cream);
  box-shadow: 0 10px 22px rgba(37, 24, 13, 0.12);
}
.merchant-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.merchant-avatar.multi {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  padding: 5px;
}
.merchant-avatar.multi img {
  width: 25px;
  height: 25px;
  flex: 0 0 auto;
  margin-left: -8px;
  border: 1px solid var(--cream);
  border-radius: 9px;
}
.merchant-avatar.multi img:first-child {
  margin-left: 0;
}
.merchant-avatar-fallback {
  color: #fffaf1;
  font-size: 18px;
  font-weight: 900;
  line-height: 1;
}
.editorial-title { min-width: 0; }
.editorial-title h2 {
  margin: 0;
  overflow-wrap: anywhere;
  font-size: 19px;
  line-height: 1.12;
  font-weight: 860;
}
.editorial-meta {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-source-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 9px;
}
.editorial-source {
  border-radius: 999px;
  padding: 6px 8px;
  background: rgba(23, 18, 13, 0.06);
  color: var(--source-accent);
  font-size: 10px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
}
.editorial-expand {
  flex: 0 0 auto;
  appearance: none;
  -webkit-appearance: none;
  border: 0;
  border-radius: 0;
  min-width: 0;
  min-height: 0;
  padding: 2px 0 4px;
  background: transparent;
  color: var(--muted);
  font: inherit;
  font-size: 11px;
  font-weight: 760;
  line-height: 1.2;
  white-space: nowrap;
  box-shadow: none;
  border-bottom: 1px solid rgba(122, 103, 79, 0.34);
}
.editorial-card.expanded .editorial-expand {
  color: var(--source-accent);
  border-bottom-color: currentColor;
}
.editorial-card:not(.expanded) .editorial-detail {
  display: none;
}
.editorial-detail {
  margin-top: 10px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.editorial-detail-grid {
  display: grid;
  gap: 7px;
}
.editorial-detail-row {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-detail-row b {
  color: var(--ink);
  font-weight: 760;
}
.editorial-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.editorial-action {
  border: 0;
  border-radius: 999px;
  min-height: 42px;
  padding: 10px 16px;
  background: linear-gradient(135deg, var(--tomato), #a82f1e);
  color: var(--cream);
  font-size: 13px;
  font-weight: 820;
  box-shadow: 0 12px 22px rgba(216, 73, 47, 0.22);
}
.editorial-action.secondary {
  background: linear-gradient(135deg, var(--ink), #3c2b1d);
  color: var(--cream);
  box-shadow: 0 12px 22px rgba(37, 24, 13, 0.2);
}
.editorial-action.luckin-menu { background: linear-gradient(135deg, #356fc0, #224f94); color: #fff; box-shadow: 0 12px 22px rgba(53,111,192,.2); }
.editorial-action.mcd-menu { background: linear-gradient(135deg, #d71920, #a80e13); color: #fff; box-shadow: 0 12px 22px rgba(215,25,32,.18); }
.editorial-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: var(--radius-md);
  padding: 18px;
  background: rgba(255, 250, 241, 0.7);
  color: var(--muted);
  line-height: 1.55;
  overflow-wrap: anywhere;
}
@media (min-width: 620px) {
  .editorial-cover { min-height: 430px; padding: 36px 28px 30px; }
  .editorial-cover h1 { font-size: 58px; }
  .editorial-feature { margin-left: 22px; margin-right: 22px; }
  .editorial-list { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 360px) {
  .editorial-cover h1 { font-size: 40px; }
  .editorial-feature h2 { font-size: 29px; }
  .merchant-avatar { width: 42px; height: 42px; border-radius: 15px; }
  .merchant-avatar img { width: 100%; height: 100%; }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
.editorial-cover {
  min-height: 280px;
}
.editorial-cover h1 {
  font-family: inherit;
  font-size: 34px;
  line-height: 1.04;
}
.editorial-feature h2 {
  font-family: inherit;
  font-size: 24px;
}
.editorial-card {
  box-shadow: none;
}
.merchant-avatar {
  border-radius: 12px;
  box-shadow: none;
}
.editorial-tab,
.editorial-expand,
.editorial-action {
  transition: transform 140ms ease, background-color 140ms ease, border-color 140ms ease;
}
.editorial-tab:active,
.editorial-expand:active,
.editorial-action:active {
  transform: scale(0.98);
}

/* v2 scene polish: keep the existing data/actions, but use the compact glass
   surface, editorial hierarchy, and pill controls from appless-scene-redesign-v2. */
.editorial-food-shell {
  width: min(100%, 820px);
  min-height: 0;
  padding: 10px 15px 104px;
  background: transparent;
}
html,
body {
  min-height: 100%;
  background: transparent;
}
.editorial-cover {
  min-height: 0;
  padding: 11px 3px 6px;
  overflow: visible;
  display: block;
  background: transparent;
  color: #3f2f27;
}
.editorial-cover-media,
.editorial-cover::after,
.persona-banner,
.source-cloud,
.cover-stats { display: none; }
.editorial-cover-content { width: 100%; }
.food-scene-kicker {
  display: block;
  margin: 0 0 4px;
  color: #8b7d73;
  font-size: 12px;
  line-height: 1.3;
  font-weight: 400;
}
.editorial-cover h1 {
  max-width: none;
  margin: 0;
  font-family: inherit;
  color: #3f2f27;
  font-size: 32px;
  line-height: 1.15;
  font-weight: 500;
  letter-spacing: -.025em;
}
.editorial-cover p {
  margin: 6px 0 16px;
  max-width: none;
  color: #74665c;
  font-size: 14px;
  line-height: 1.45;
}
.editorial-location-bar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 40px 40px;
  gap: 7px;
  width: 100%;
  margin: 0 0 10px;
}
.editorial-kicker { display: none; }
.food-current-address {
  display: flex;
  align-items: center;
  gap: 8px;
  min-height: 47px;
  padding: 8px 10px;
  overflow: hidden;
  border: 1px solid rgba(73,63,56,.1);
  border-radius: 15px;
  background: rgba(255,255,255,.62);
  color: #5e4d43;
  font-size: 13px;
  font-weight: 500;
  text-align: left;
  white-space: normal;
}
.food-current-address::after { display: none; }
.food-location-symbol {
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  border-radius: 8px;
  background: rgba(153,95,76,.1);
  color: #995f4c;
}
.food-location-symbol svg { width: 14px; height: 14px; }
.food-location-copy { min-width: 0; flex: 1; }
.food-location-copy small { display: block; color: #8b7d73; font-size: 10px; }
.food-location-copy strong { display: block; margin-top: 2px; overflow: hidden; font-size: 13px; font-weight: 500; text-overflow: ellipsis; white-space: nowrap; }
.food-location-chevron { display: grid; place-items: center; color: #8b7d73; }
.food-location-chevron svg { width: 14px; height: 14px; }
.food-map-icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 47px;
  padding: 0;
  border: 1px solid rgba(73,63,56,.1);
  border-radius: 15px;
  background: rgba(255,255,255,.62);
  color: #995f4c;
}
.food-map-icon svg { width: 18px; height: 18px; }
.food-card-topline {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 8px;
}
.food-card-topline .editorial-badge { margin-bottom: 0; }
.food-card-head-actions {
  display: flex;
  align-self: stretch;
  flex-direction: column;
  align-items: flex-end;
  justify-content: space-between;
  gap: 8px;
}
.food-card-topline .food-favorite-toggle,
.food-card-head-actions .food-favorite-toggle {
  position: static;
  width: 32px;
  height: 32px;
  flex: 0 0 auto;
  border-radius: 11px;
  font-size: 19px;
  box-shadow: none;
}
.editorial-feature .food-card-topline .food-favorite-toggle {
  border-color: rgba(122,103,79,.25);
  background: rgba(255,250,241,.94);
  color: #9b9084;
}
.editorial-feature .food-card-topline .food-favorite-toggle.active {
  border-color: rgba(216,166,63,.55);
  background: #fff7df;
  color: #d39a24;
}
.editorial-tabs {
  position: static;
  gap: 6px;
  margin: 0;
  padding: 4px 0 5px;
  overflow-x: auto;
  background: transparent;
  border-bottom: 0;
  backdrop-filter: none;
}
.appless-v2-food-tabs { display: flex; }
.editorial-tab {
  min-height: 31px;
  padding: 6px 9px;
  border: 1px solid rgba(73,63,56,.1);
  border-radius: 999px;
  background: rgba(255,255,255,.57);
  color: #68584e;
  font-size: 12px;
  font-weight: 500;
  box-shadow: none;
}
.editorial-tab.active {
  border-color: #995f4c;
  background: #995f4c;
  color: #fff;
  box-shadow: none;
}
.food-filters {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 6px;
  margin: 1px 0 10px;
  padding: 0;
  overflow: visible;
}
.appless-v2-food-filters { display: grid; }
.food-control {
  display: inline-flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  min-width: 0;
  min-height: 31px;
  border: 1px dashed rgba(73,63,56,.16);
  border-radius: 999px;
  background: rgba(255,255,255,.57);
  white-space: nowrap;
}
.food-control span { display: none; }
.food-control select {
  appearance: none;
  -webkit-appearance: none;
  width: auto;
  flex: 1 1 auto;
  min-width: 0;
  max-width: 100%;
  height: 29px;
  padding: 0 0 0 9px;
  border: 0;
  outline: 0;
  background: transparent;
  color: #68584e;
  font-size: 12px;
  line-height: 1;
}
.food-control::after {
  content: '';
  position: static;
  width: 5px;
  height: 5px;
  margin: 0 9px 3px 6px;
  border-right: 1.3px solid #8b7d73;
  border-bottom: 1.3px solid #8b7d73;
  transform: rotate(45deg);
  pointer-events: none;
}
.food-filters > button.editorial-tab { min-height: 31px; }
.editorial-feature {
  --source-accent: var(--food-local);
  margin: 0 0 10px;
  overflow: hidden;
  border: 1px solid rgba(73,63,56,.11);
  border-radius: 21px;
  background: rgba(255,255,255,.69);
  color: var(--ink);
  box-shadow: 0 10px 26px rgba(82,59,44,.07);
  backdrop-filter: blur(22px);
}
.editorial-feature-media {
  position: relative;
  display: grid;
  place-items: center;
  min-height: 94px;
  background: radial-gradient(circle at 52% 45%,rgba(255,246,225,.95),transparent 22%), linear-gradient(135deg,#d8b493,#a8795d);
  color: #fff;
}
.editorial-feature-media { display: none; }
.editorial-feature-media::after { content: none; }
.editorial-feature-media > span.editorial-badge {
  position: absolute;
  top: 9px;
  left: 9px;
  padding: 4px 7px;
  border-radius: 999px;
  background: rgba(255,255,255,.75);
  color: #795c4a;
  font-size: 8px;
}
.food-feature-icon { display: grid; place-items: center; color: rgba(255,255,255,.92); font-style: normal; }
.food-feature-icon svg { width: 30px; height: 30px; }
.editorial-feature-copy { padding: 12px; }
.editorial-feature-copy .editorial-badge {
  display: inline-flex;
  align-items: center;
  min-height: 22px;
  margin-bottom: 8px;
  padding: 4px 8px;
  border: 1px solid rgba(153,95,76,.14);
  border-radius: 999px;
  background: rgba(153,95,76,.08);
  color: #795c4a;
  font-size: 10px;
  line-height: 1;
}
.editorial-feature-label { display: none; }
.editorial-feature .editorial-card-head { grid-template-columns: minmax(0,1fr); }
.editorial-feature .editorial-title h2 {
  margin: 3px 0 0;
  font-size: 18px;
  font-weight: 500;
}
.editorial-feature .editorial-title small { color: #995f4c; font-size: 11px; }
.editorial-feature p {
  margin: 7px 0 0;
  color: #786a60;
  font-size: 13px;
  line-height: 1.45;
}
.editorial-feature .editorial-detail { display: block; margin-top: 9px; padding-top: 0; border-top: 0; }
.editorial-feature .editorial-detail-grid { grid-template-columns: 1.2fr .9fr .9fr; gap: 6px; }
.editorial-feature .editorial-detail-row {
  display: block;
  min-width: 0;
  padding: 7px;
  border-radius: 10px;
  background: rgba(245,240,235,.66);
  font-size: 11px;
  line-height: 1.25;
}
.editorial-feature .editorial-detail-row b { display: block; color: #8b7d73; font-size: 10px; font-weight: 400; }
.editorial-feature .editorial-detail-row span { display: block; margin-top: 3px; overflow: hidden; color: var(--ink); text-overflow: ellipsis; white-space: nowrap; }
.editorial-feature .editorial-detail-row:nth-child(n+4) { display: none; }
.editorial-feature .editorial-actions { margin-top: 10px; }
.editorial-feature .editorial-action { min-height: 38px; padding: 8px 12px; border: 1px solid rgba(153,95,76,.16); border-radius: 11px; background: rgba(255,255,255,.72); color: #795c4a; font-size: 12px; font-weight: 500; box-shadow: none; }
.editorial-feature .editorial-action,
.editorial-card .editorial-action { display: inline-flex; align-items: center; justify-content: center; gap: 4px; }
.food-action-icon { display: inline-grid; place-items: center; }
.food-action-icon svg { width: 12px; height: 12px; }
.editorial-feature .editorial-action:first-child { border-color: #995f4c; background: #995f4c; color: #fff; }
.editorial-card .editorial-expand {
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  gap: 5px;
  line-height: 1;
  white-space: nowrap;
}
.editorial-card .editorial-expand::after {
  content: '';
  display: inline-block;
  width: 5px;
  height: 5px;
  flex: 0 0 auto;
  border-right: 1.3px solid currentColor;
  border-bottom: 1.3px solid currentColor;
  transform: rotate(45deg);
}
.editorial-card.expanded .editorial-expand::after { transform: rotate(225deg); }
.editorial-list { display: grid; gap: 9px; padding: 0 0 18px; }
.editorial-card {
  display: grid;
  grid-template-columns: 42px minmax(0,1fr) auto;
  align-items: center;
  gap: 9px;
  margin: 0;
  padding: 9px;
  border: 0;
  border-radius: 15px;
  background: rgba(255,255,255,.5);
  box-shadow: none;
}
.appless-v2-food-list-card { display: grid; }
.editorial-card::before { display: none; }
.editorial-card-head { display: contents; }
.merchant-avatar { width: 42px; height: 42px; border: 0; border-radius: 12px; background: rgba(57,122,85,.1); box-shadow: none; }
.merchant-avatar.multi { padding: 5px; }
.merchant-avatar-fallback { color: #397a55; font-size: 18px; }
.editorial-title h2 { font-size: 14px; font-weight: 500; }
.editorial-meta { margin-top: 3px; font-size: 11px; line-height: 1.4; }
.editorial-source-row { grid-column: 2; gap: 4px; margin-top: 3px; }
.editorial-source { padding: 0; background: transparent; color: #995f4c; font-size: 10px; font-weight: 400; }
.editorial-source + .editorial-source::before { content: ' · '; color: #8b7d73; }
.editorial-expand { grid-column: 3; grid-row: 1 / 4; padding: 0; border: 0; color: #995f4c; font-size: 12px; font-weight: 400; }
.editorial-card .editorial-detail { grid-column: 1 / -1; }
.editorial-card:not(.expanded) .editorial-detail { display: none; }
.editorial-card.expanded { display: block; }
.editorial-card.expanded .editorial-card-head { display: grid; }
.editorial-card.expanded .editorial-source-row { grid-column: 1 / -1; }
.editorial-card.expanded .editorial-expand { float: right; }
.editorial-card.expanded .editorial-detail { margin-top: 10px; padding-top: 10px; border-top: 1px solid var(--line); }
.editorial-card.expanded .editorial-actions { display: flex; }
.editorial-card .editorial-actions { display: none; }
.editorial-card .editorial-detail-grid { gap: 7px; }
.editorial-card .editorial-detail-row { font-size: 12px; }
.editorial-card .editorial-action { min-height: 38px; padding: 8px 12px; border-radius: 11px; font-size: 12px; }
.editorial-empty { grid-column: 1 / -1; margin-top: 0; }
.appless-v2-address-functions {
  display: grid;
  grid-template-columns: 34px minmax(0,1fr) auto;
  align-items: center;
  gap: 9px;
  margin: 0 0 12px;
  padding: 11px;
  border-radius: 17px;
  background: rgba(255,255,255,.5);
}
.appless-v2-address-functions > i {
  display: grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border-radius: 11px;
  background: rgba(71,111,159,.1);
  color: #476f9f;
  font-style: normal;
}
.appless-v2-address-functions > i svg { width: 17px; height: 17px; }
.appless-v2-address-functions strong { display: block; margin-top: 2px; font-size: 12px; font-weight: 500; }
.appless-v2-address-functions p { margin: 3px 0 0; color: #8b7d73; font-size: 10px; line-height: 1.4; }
.appless-v2-address-functions button { border: 0; background: transparent; color: #995f4c; font: inherit; font-size: 12px; }
@media (max-width: 430px) {
  .editorial-feature .editorial-detail-grid { grid-template-columns: 1fr 1fr; }
  .editorial-feature .editorial-detail-row:first-child { grid-column: 1 / -1; }
  .appless-v2-address-functions { grid-template-columns: 32px minmax(0,1fr); }
  .appless-v2-address-functions button { grid-column: 2; justify-self: start; }
}
`;

const FOOD_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var state = { filter: 'all', price: 'all', rating: 'all', business: 'all', sort: 'smart', expandedKey: '' };
  var AVATAR_MCDONALDS = '${APP_LOGO_MCDONALDS}';
  var AVATAR_KFC = '${APP_LOGO_KFC}';
  var AVATAR_TAOBAO = '${APP_LOGO_TAOBAO}';
  var AVATAR_AMAP = '${APP_LOGO_AMAP}';
  var AVATAR_TENCENT = '${APP_LOGO_TENCENT_MAPS}';
  var AVATAR_BAIDU = '${APP_LOGO_BAIDU_MAPS}';
  var AVATAR_MEITUAN = '${APP_LOGO_MEITUAN}';
  var AVATAR_LUCKIN = '${APP_LOGO_LUCKIN}';
  var AVATAR_GOOGLE_MAPS = '${APP_LOGO_GOOGLE_MAPS}';
  var AVATAR_LOCAL = '';
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function distanceMeters(value) {
    var raw = text(value).toLowerCase();
    var n = numberIn(raw);
    if (!(n >= 0)) { return Number.POSITIVE_INFINITY; }
    return raw.indexOf('km') >= 0 || raw.indexOf('公里') >= 0 ? n * 1000 : n;
  }
  function sourceParts(block) {
    var raw = text(block && block.source) || metric(block, ['source', 'provider', 'sourceTag']);
    return raw.split(/[\\/|,，、]+/).map(function (part) { return part.trim(); }).filter(Boolean);
  }
  function sourceKey(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return 'food-local'; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return 'food-amap'; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return 'food-tencent'; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return 'food-baidu'; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return 'food-meituan'; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return 'food-taobao'; }
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return 'food-mcd'; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return 'food-kfc'; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return 'food-luckin'; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return 'food-google-maps'; }
    return 'food-local';
  }
  function avatarData(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return AVATAR_LOCAL; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return AVATAR_MCDONALDS; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return AVATAR_KFC; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return AVATAR_TAOBAO; }
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return AVATAR_AMAP; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return AVATAR_TENCENT; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return AVATAR_BAIDU; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return AVATAR_MEITUAN; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return AVATAR_LUCKIN; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return AVATAR_GOOGLE_MAPS; }
    return AVATAR_LOCAL;
  }
  function avatarInitial(block) {
    var raw = text(block && block.title).trim() || sourceParts(block).join('').trim() || '食';
    return raw.slice(0, 1);
  }
  function addAvatar(parent, block) {
    var wrap = add(parent, 'div', 'merchant-avatar');
    var sources = sourceParts(block);
    if (sources.length > 1) {
      wrap.className += ' multi';
      sources.slice(0, 3).forEach(function (source) {
        var sourceAvatar = avatarData({ source: source });
        if (sourceAvatar === AVATAR_LOCAL) { return; }
        var sourceImg = add(wrap, 'img');
        sourceImg.src = sourceAvatar;
        sourceImg.alt = '';
        sourceImg.setAttribute('aria-hidden', 'true');
      });
      if (wrap.children.length > 0) { return; }
    }
    var src = avatarData(block);
    if (src.length > 0) {
      var img = add(wrap, 'img');
      img.src = src;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      return;
    }
    add(wrap, 'span', 'merchant-avatar-fallback', avatarInitial(block));
  }
  function hasLocation(block) {
    return text(metric(block, ['location'])).length > 0;
  }
  function hasLuckinSource(block) {
    return sourceParts(block).indexOf('瑞幸') >= 0;
  }
  function hasMcDonaldsSource(block) {
    return sourceParts(block).indexOf('麦当劳') >= 0;
  }
  function isFoodMenuAction(id) {
    return id === 'food_luckin_menu_open' || id === 'food_mcd_menu_open';
  }
  function foodMenuActionAllowed(block, id) {
    return id === 'food_luckin_menu_open' ? hasLuckinSource(block) :
      (id === 'food_mcd_menu_open' && hasMcDonaldsSource(block));
  }
  function foodMenuButtonClass(id) {
    return id === 'food_mcd_menu_open' ? 'editorial-action mcd-menu' : 'editorial-action luckin-menu';
  }
  function postAction(action) {
    if (isBusy) { return false; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
        return true;
      }
    } catch (error) {}
    return false;
  }
  function favoriteAction(block) {
    var actions = list(block && block.actions);
    for (var index = 0; index < actions.length; index += 1) {
      if (text(actions[index] && actions[index].id) === 'food_favorite_toggle') { return actions[index]; }
    }
    return null;
  }
  function addFavoriteToggle(parent, block) {
    var action = favoriteAction(block);
    if (!action) { return; }
    var active = block && block.foodFavorite === true;
    var favoriteId = text(block && block.foodFavoriteId);
    var button = add(parent, 'button', 'food-favorite-toggle' + (active ? ' active' : ''), active ? '★' : '☆');
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-favorite-id', favoriteId);
    button.setAttribute('aria-label', active ? '取消收藏' : '收藏门店');
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      var nextActive = button.getAttribute('aria-pressed') !== 'true';
      button.disabled = true;
      applyFavoriteState(block, nextActive);
      if (!postAction(action)) {
        applyFavoriteState(block, !nextActive);
      }
      window.setTimeout(function () {
        Array.prototype.slice.call(document.querySelectorAll('.food-favorite-toggle')).forEach(function (candidate) {
          if (candidate.getAttribute('data-favorite-id') === favoriteId) { candidate.disabled = isBusy; }
        });
      }, 500);
    });
  }
  function setFavoriteToggleState(button, active) {
    button.classList.toggle('active', active);
    button.textContent = active ? '★' : '☆';
    button.setAttribute('aria-label', active ? '取消收藏' : '收藏门店');
    button.setAttribute('aria-pressed', active ? 'true' : 'false');
  }
  function favoriteEntryFromBlock(block) {
    return {
      favoriteId: text(block && block.foodFavoriteId),
      savedAt: Date.now(),
      name: text(block && block.title),
      category: metric(block, ['category']),
      address: metric(block, ['address']),
      distance: metric(block, ['distance']),
      location: metric(block, ['location']),
      sourceTags: sourceParts(block),
      phone: metric(block, ['phone']),
      phoneSource: metric(block, ['phoneSource']),
      openHoursToday: metric(block, ['openHoursToday']),
      openHoursWeek: metric(block, ['openHoursWeek']),
      pricePerPerson: metric(block, ['pricePerPerson']),
      priceText: metric(block, ['priceText']),
      priceSource: metric(block, ['priceSource']),
      rating: metric(block, ['rating']),
      ratingText: metric(block, ['ratingText']),
      ratingSource: metric(block, ['ratingSource']),
      businessStatus: metric(block, ['businessStatus']),
      businessStatusLabel: metric(block, ['businessStatusLabel'])
    };
  }
  function favoriteBlock(favorite, index) {
    var metrics = [];
    function append(label, value) {
      if (text(value).length > 0) { metrics.push({ label: label, value: text(value) }); }
    }
    append('category', favorite.category);
    append('address', favorite.address);
    append('distance', favorite.distance);
    append('location', favorite.location);
    append('phone', favorite.phone);
    append('phoneSource', favorite.phoneSource);
    append('openHoursToday', favorite.openHoursToday);
    append('openHoursWeek', favorite.openHoursWeek);
    append('pricePerPerson', favorite.pricePerPerson);
    append('priceText', favorite.priceText);
    append('priceSource', favorite.priceSource);
    append('rating', favorite.rating);
    append('ratingText', favorite.ratingText);
    append('ratingSource', favorite.ratingSource);
    append('businessStatus', favorite.businessStatus);
    append('businessStatusLabel', favorite.businessStatusLabel);
    var favoriteId = text(favorite.favoriteId);
    var actionArgs = { surfaceId: text(data.surfaceId), favoriteId: favoriteId };
    var actions = [];
    if (text(favorite.location).length > 0) {
      actions.push({ id: 'food_favorite_pin', label: '固定到桌面', prompt: '固定收藏门店', kind: 'client', variant: 'secondary', args: actionArgs });
      actions.push({ id: 'food_favorite_map', label: '导航去', prompt: '导航到收藏门店', kind: 'client', variant: 'primary', args: actionArgs });
    }
    if (text(favorite.phone).length > 0) {
      actions.push({ id: 'food_favorite_call', label: '拨打电话', prompt: '拨打收藏门店电话', kind: 'client', variant: 'secondary', args: actionArgs });
    }
    if (list(favorite.sourceTags).map(function (source) { return text(source).trim(); }).indexOf('瑞幸') >= 0) {
      actions.push({ id: 'food_luckin_menu_open', label: '查询菜单', prompt: '查询瑞幸门店菜单', kind: 'client', variant: 'secondary', args: actionArgs });
    }
    if (list(favorite.sourceTags).map(function (source) { return text(source).trim(); }).indexOf('麦当劳') >= 0) {
      actions.push({ id: 'food_mcd_menu_open', label: '查询菜单', prompt: '查询麦当劳门店菜单', kind: 'client', variant: 'secondary', args: actionArgs });
    }
    return {
      id: 'favorite-' + (text(favorite.favoriteId) || String(index)),
      foodFavoriteId: favoriteId,
      foodFavorite: true,
      title: text(favorite.name),
      subtitle: text(favorite.category),
      source: list(favorite.sourceTags).map(text).filter(Boolean).join(' / '),
      metrics: metrics,
      actions: actions
    };
  }
  function addFavoriteRemoveButton(parent, favorite, block) {
    var favoriteId = text(favorite && favorite.favoriteId);
    var button = add(parent, 'button', 'food-favorite-toggle active', '★');
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-favorite-id', favoriteId);
    button.setAttribute('aria-label', '取消收藏');
    button.setAttribute('aria-pressed', 'true');
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      button.disabled = true;
      applyFavoriteState(block, false);
      if (!postAction({
        id: 'food_favorite_remove', label: '取消收藏', prompt: '取消收藏门店', kind: 'client', variant: 'secondary',
        args: { surfaceId: text(data.surfaceId), favoriteId: favoriteId }
      })) {
        applyFavoriteState(block, true);
      }
    });
  }
  function renderFavoriteCount() {
    if (!favoritesEntryButton) { return; }
    var existing = favoritesEntryButton.querySelector('.food-favorites-count');
    if (existing) { existing.remove(); }
    if (favoriteEntries.length > 0) {
      add(favoritesEntryButton, 'span', 'food-favorites-count', String(favoriteEntries.length));
    }
  }
  function renderFavoriteEntries() {
    if (!favoritesScroll) { return; }
    favoritesScroll.textContent = '';
    if (favoriteEntries.length === 0) {
      add(favoritesScroll, 'div', 'food-address-empty', '还没有收藏门店，点一下卡片右上角的星星试试。');
      return;
    }
    favoriteEntries.forEach(function (favorite, index) {
      var block = favoriteBlock(favorite, index);
      var key = text(favorite.favoriteId) || String(index);
      var savedCard = add(favoritesScroll, 'article', 'editorial-card food-favorite-saved-card');
      savedCard.setAttribute('data-favorite-card-key', key);
      savedCard.setAttribute('aria-expanded', 'false');
      var head = add(savedCard, 'div', 'editorial-card-head');
      addAvatar(head, block);
      var title = add(head, 'div', 'editorial-title');
      add(title, 'h2', '', text(block.title) || '未命名门店');
      add(title, 'div', 'editorial-meta', [metric(block, ['distance']), metric(block, ['address']),
        metric(block, ['ratingText', 'rating']), metric(block, ['priceText', 'pricePerPerson']),
        metric(block, ['businessStatusLabel']), metric(block, ['openHoursToday']) || metric(block, ['openHoursWeek'])].filter(Boolean).join(' · '));
      var headActions = add(head, 'div', 'food-card-head-actions');
      addFavoriteRemoveButton(headActions, favorite, block);
      var expand = add(headActions, 'button', 'editorial-expand', '展开');
      expand.type = 'button';
      expand.addEventListener('click', function (event) { event.stopPropagation(); setFavoriteExpanded(key); });
      savedCard.addEventListener('click', function () { setFavoriteExpanded(key); });
      var sources = sourceParts(block);
      if (sources.length > 0) {
        var sourceRow = add(savedCard, 'div', 'editorial-source-row');
        sources.forEach(function (source) { add(sourceRow, 'span', 'editorial-source', source); });
      }
      renderFoodCardDetail(savedCard, block, true);
    });
    applyFavoriteExpansion();
  }
  function applyFavoriteState(block, active) {
    var favoriteId = text(block && block.foodFavoriteId);
    block.foodFavorite = active;
    Array.prototype.slice.call(document.querySelectorAll('.food-favorite-toggle')).forEach(function (button) {
      if (button.getAttribute('data-favorite-id') === favoriteId) { setFavoriteToggleState(button, active); }
    });
    favoriteEntries = favoriteEntries.filter(function (favorite) { return text(favorite.favoriteId) !== favoriteId; });
    if (active) { favoriteEntries.unshift(favoriteEntryFromBlock(block)); }
    renderFavoriteCount();
    renderFavoriteEntries();
  }
  function applyFavoriteExpansion() {
    if (!favoritesScroll) { return; }
    Array.prototype.slice.call(favoritesScroll.querySelectorAll('.food-favorite-saved-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-favorite-card-key') === favoriteExpandedId;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.editorial-expand');
      if (button) { button.textContent = expanded ? '收起' : '展开'; }
    });
  }
  function setFavoriteExpanded(key) {
    favoriteExpandedId = favoriteExpandedId === key ? '' : key;
    applyFavoriteExpansion();
  }
  var menuOverlay = null;
  var menuTitle = null;
  var menuStore = null;
  var menuScroll = null;
  var activeMenuRequestKey = '';
  var activeMenuPatch = null;
  function menuRequestKey(block) {
    return text(block && block.title) + '|' + text(metric(block, ['address']));
  }
  function menuAction(block) {
    var actions = list(block && block.actions);
    for (var index = 0; index < actions.length; index += 1) {
      if (isFoodMenuAction(text(actions[index] && actions[index].id))) { return actions[index]; }
    }
    return null;
  }
  function renderMenuState(message) {
    if (!menuScroll) { return; }
    menuScroll.textContent = '';
    add(menuScroll, 'div', 'food-menu-state', message);
  }
  function renderMenuProducts(patch) {
    if (!menuScroll) { return; }
    menuScroll.textContent = '';
    var products = list(patch && patch.products);
    if (products.length === 0) {
      renderMenuState(text(patch && patch.error) || '这家门店暂时没有返回可展示的商品。');
      return;
    }
    var grid = add(menuScroll, 'div', 'food-menu-grid');
    products.forEach(function (product) {
      var card = add(grid, 'article', 'food-menu-product');
      var isMcDonalds = text(patch && patch.brand) === 'mcdonalds';
      var picture = text(product && product.pictureUrl);
      if (picture) {
        var image = add(card, 'img', 'food-menu-picture');
        image.src = picture;
        image.alt = text(product.name);
      } else {
        add(card, 'div', 'food-menu-picture food-menu-picture-empty', isMcDonalds ? '🍔' : '☕');
      }
      var copy = add(card, 'div', 'food-menu-copy');
      add(copy, 'div', 'food-menu-product-name', text(product && product.name) || (isMcDonalds ? '麦当劳商品' : '瑞幸商品'));
      var price = add(copy, 'div', 'food-menu-price', text(product && product.priceText) || '价格以结算页为准');
      var originalPrice = text(product && product.originalPriceText);
      if (originalPrice && originalPrice !== text(product && product.priceText)) {
        add(price, 'span', 'food-menu-original-price', originalPrice);
      }
      var tags = list(product && product.tags).map(text).filter(Boolean);
      if (tags.length > 0) { add(copy, 'div', 'food-menu-tags', tags.join(' · ')); }
      var options = list(product && product.options).map(function (group) {
        return text(group && group.name) + '：' + list(group && group.choices).map(text).filter(Boolean).join('/');
      }).filter(Boolean);
      if (options.length > 0) { add(copy, 'div', 'food-menu-options', options.join(' · ')); }
      var orderButton = add(copy, 'button', isMcDonalds ? 'food-menu-order mcd' : 'food-menu-order',
        isMcDonalds ? '查看详情' : '去点餐');
      orderButton.type = 'button';
      var canOrder = isMcDonalds ? text(product && product.productId).length > 0 :
        text(patch && patch.deptId).length > 0 && text(patch && patch.storeLocation).length > 0 &&
          text(product && product.productId).length > 0 && text(product && product.skuCode).length > 0;
      orderButton.disabled = isBusy || !canOrder;
      if (!canOrder) { orderButton.textContent = '暂不可点'; }
      orderButton.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isMcDonalds) {
          renderMenuState('正在加载菜品详情…');
          postAction({
            id: 'food_mcd_menu_detail', label: '查看详情', prompt: '查看' + text(product && product.name),
            kind: 'client', variant: 'primary',
            args: {
              surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey),
              productId: text(product && product.productId)
            }
          });
          return;
        }
        postAction({
          id: 'food_luckin_order_preview', label: '去点餐', prompt: '点一份' + text(product && product.name),
          kind: 'client', variant: 'primary',
          args: {
            surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey),
            deptId: text(patch && patch.deptId), deptName: text(patch && patch.storeName),
            address: text(patch && patch.storeAddress), location: text(patch && patch.storeLocation),
            productId: text(product && product.productId), productName: text(product && product.name),
            skuCode: text(product && product.skuCode), pictureUrl: text(product && product.pictureUrl)
          }
        });
      });
    });
  }
  function renderMcDonaldsRows(container, rows) {
    var listRows = list(rows);
    if (listRows.length === 0) { return; }
    var wrap = add(container, 'div', 'food-menu-detail-rows');
    listRows.forEach(function (row) {
      var line = add(wrap, 'div', 'food-menu-detail-row');
      add(line, 'b', '', text(row && row.label));
      add(line, 'span', '', text(row && row.value));
    });
  }
  function renderMcDonaldsHero(container, patch) {
    var hero = add(container, 'div', 'food-menu-detail-hero');
    var picture = text(patch && patch.selectedPictureUrl);
    if (picture) {
      var image = add(hero, 'img', 'food-menu-picture');
      image.src = picture;
      image.alt = text(patch && patch.selectedProductName);
    } else {
      add(hero, 'div', 'food-menu-picture food-menu-picture-empty', '🍔');
    }
    var copy = add(hero, 'div', '');
    add(copy, 'div', 'food-menu-detail-name', text(patch && patch.selectedProductName) || '麦当劳商品');
    add(copy, 'div', 'food-menu-detail-price', text(patch && patch.selectedPriceText) || '以核价结果为准');
  }
  function renderMcDonaldsMenuBack(container, patch) {
    var back = add(container, 'button', 'food-menu-checkout-secondary', '返回菜单');
    back.type = 'button';
    back.addEventListener('click', function () {
      renderMenuProducts(patch);
    });
  }
  function renderMcDonaldsDetail(patch) {
    if (!menuScroll) { return; }
    menuScroll.textContent = '';
    var detail = add(menuScroll, 'div', 'food-menu-detail');
    renderMcDonaldsHero(detail, patch);
    renderMcDonaldsRows(detail, patch && patch.rows);
    if (text(patch && patch.error)) {
      add(detail, 'div', 'food-menu-warning', text(patch.error) + '，仍可按菜单默认配置核价。');
    }
    var quantity = Math.max(1, Math.min(20, Number(patch && patch.quantity) || 1));
    var quantityRow = add(detail, 'div', 'food-menu-quantity');
    add(quantityRow, 'b', '', '数量');
    var stepper = add(quantityRow, 'div', 'food-menu-stepper');
    var minus = add(stepper, 'button', '', '−');
    minus.type = 'button';
    var quantityText = add(stepper, 'strong', '', String(quantity));
    var plus = add(stepper, 'button', '', '+');
    plus.type = 'button';
    function syncQuantity() {
      quantityText.textContent = String(quantity);
      minus.disabled = quantity <= 1;
      plus.disabled = quantity >= 20;
    }
    minus.addEventListener('click', function () { quantity = Math.max(1, quantity - 1); syncQuantity(); });
    plus.addEventListener('click', function () { quantity = Math.min(20, quantity + 1); syncQuantity(); });
    syncQuantity();
    var actions = add(detail, 'div', 'food-menu-checkout-actions');
    var quote = add(actions, 'button', 'food-menu-checkout-primary', '核算价格');
    quote.type = 'button';
    quote.addEventListener('click', function () {
      renderMenuState('正在向麦当劳核算真实价格…');
      postAction({
        id: 'food_mcd_order_quote', label: '核算价格', prompt: '核算麦当劳订单价格',
        kind: 'client', variant: 'primary',
        args: {
          surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey),
          productId: text(patch && patch.selectedProductId), quantity: quantity
        }
      });
    });
    renderMcDonaldsMenuBack(actions, patch);
  }
  function renderMcDonaldsQuote(patch) {
    if (!menuScroll) { return; }
    menuScroll.textContent = '';
    var detail = add(menuScroll, 'div', 'food-menu-detail');
    renderMcDonaldsHero(detail, patch);
    renderMcDonaldsRows(detail, patch && patch.rows);
    if (text(patch && patch.error)) { add(detail, 'div', 'food-menu-warning', text(patch.error)); }
    var actions = add(detail, 'div', 'food-menu-checkout-actions');
    var create = add(actions, 'button', 'food-menu-checkout-primary', '确认下单（将创建真实订单）');
    create.type = 'button';
    create.disabled = !(patch && patch.canCreate) || !text(patch && patch.quoteToken);
    create.addEventListener('click', function () {
      renderMenuState('正在创建真实麦当劳订单，请勿重复点击…');
      postAction({
        id: 'food_mcd_order_create', label: '确认下单', prompt: '确认创建真实麦当劳订单',
        kind: 'client', variant: 'primary',
        args: {
          surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey),
          productId: text(patch && patch.selectedProductId), quantity: Number(patch && patch.quantity) || 1,
          quoteToken: text(patch && patch.quoteToken)
        }
      });
    });
    renderMcDonaldsMenuBack(actions, patch);
  }
  function renderMcDonaldsOrder(patch) {
    if (!menuScroll) { return; }
    menuScroll.textContent = '';
    var detail = add(menuScroll, 'div', 'food-menu-detail');
    if (text(patch && patch.orderId)) {
      add(detail, 'div', 'food-menu-success', '麦当劳订单已创建' +
        (text(patch && patch.statusText) ? ' · ' + text(patch.statusText) : ''));
    }
    renderMcDonaldsRows(detail, patch && patch.rows);
    if (text(patch && patch.error)) { add(detail, 'div', 'food-menu-warning', text(patch.error)); }
    var actions = add(detail, 'div', 'food-menu-checkout-actions');
    if (text(patch && patch.payUrl)) {
      var pay = add(actions, 'button', 'food-menu-checkout-primary', '打开支付页面');
      pay.type = 'button';
      pay.addEventListener('click', function () {
        postAction({
          id: 'food_mcd_pay_open', label: '打开支付页面', prompt: '打开麦当劳支付页面',
          kind: 'client', variant: 'primary',
          args: { surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey), orderId: text(patch && patch.orderId) }
        });
      });
    }
    if (text(patch && patch.orderId)) {
      var refresh = add(actions, 'button', 'food-menu-checkout-secondary', '刷新订单状态');
      refresh.type = 'button';
      refresh.addEventListener('click', function () {
        renderMenuState('正在刷新订单状态…');
        postAction({
          id: 'food_mcd_order_status', label: '刷新订单状态', prompt: '查询麦当劳订单状态',
          kind: 'client', variant: 'secondary',
          args: { surfaceId: text(data.surfaceId), requestKey: text(patch && patch.requestKey), orderId: text(patch && patch.orderId) }
        });
      });
    }
    renderMcDonaldsMenuBack(actions, patch);
  }
  function applyMenuPatch(patchJson) {
    var patch = patchJson;
    try { if (typeof patchJson === 'string') { patch = JSON.parse(patchJson); } } catch (error) { patch = null; }
    if (!patch || text(patch.kind) !== 'food-menu') { return false; }
    if (text(patch.requestKey) && text(patch.requestKey) !== activeMenuRequestKey) { return false; }
    activeMenuPatch = patch;
    var brandName = text(patch.brand) === 'mcdonalds' ? '麦当劳' : '瑞幸';
    if (menuTitle) { menuTitle.textContent = text(patch.storeName) || brandName + '菜单'; }
    if (menuStore) { menuStore.textContent = [text(patch.storeName), text(patch.storeAddress)].filter(Boolean).join(' · '); }
    if (text(patch.status) === 'ready' && text(patch.brand) === 'mcdonalds' && text(patch.step) === 'detail') {
      renderMcDonaldsDetail(patch);
    } else if (text(patch.status) === 'ready' && text(patch.brand) === 'mcdonalds' && text(patch.step) === 'quote') {
      renderMcDonaldsQuote(patch);
    } else if (text(patch.brand) === 'mcdonalds' && text(patch.step) === 'order') {
      renderMcDonaldsOrder(patch);
    } else if (text(patch.status) === 'ready') { renderMenuProducts(patch); }
    else { renderMenuState(text(patch.error) || '菜单查询失败，请稍后再试。'); }
    return true;
  }
  function openFoodMenu(block, action) {
    if (!menuOverlay || !action) { return; }
    var isMcDonalds = text(action && action.id) === 'food_mcd_menu_open';
    var brandName = isMcDonalds ? '麦当劳' : '瑞幸';
    activeMenuRequestKey = menuRequestKey(block);
    activeMenuPatch = null;
    if (menuTitle) { menuTitle.textContent = text(block && block.title) || brandName + '菜单'; }
    if (menuStore) { menuStore.textContent = [text(block && block.title), text(metric(block, ['address']))].filter(Boolean).join(' · '); }
    renderMenuState('正在匹配' + brandName + '门店并查询菜单…');
    menuOverlay.classList.add('open');
    if (!postAction(action)) { renderMenuState('暂时无法连接原生能力，请稍后重试。'); }
  }
  window.AIPhoneFoodMenu = { applyPatch: applyMenuPatch };
  function renderFoodCardDetail(card, block, includeActions) {
    var detail = add(card, 'div', 'editorial-detail');
    var grid = add(detail, 'div', 'editorial-detail-grid');
    detailRow(grid, '地址', metric(block, ['address']));
    detailRow(grid, '分类', metric(block, ['category']) || text(block.subtitle));
    detailRow(grid, '距离', metric(block, ['distance']));
    detailRow(grid, '评分', metric(block, ['ratingText', 'rating']));
    detailRow(grid, '人均价格', metric(block, ['priceText', 'pricePerPerson']));
    detailRow(grid, '营业状态', metric(block, ['businessStatusLabel']));
    detailRow(grid, '今日营业', metric(block, ['openHoursToday']) || metric(block, ['openHoursWeek']));
    detailRow(grid, '营业时间', metric(block, ['openHoursWeek']));
    detailRow(grid, '坐标', metric(block, ['location']));
    detailRow(grid, '来源', sourceParts(block).join(' / '));
    detailRow(grid, '电话', metric(block, ['phone']));
    detailRow(grid, '电话来源', metric(block, ['phoneSource']));
    if (!includeActions) { return; }
    var canNavigate = hasLocation(block);
    var availableActions = list(block.actions).filter(function (action) {
      var id = text(action && action.id);
      var mapAction = id === 'html_open_food_map' || id === 'food_favorite_map';
      var pinAction = id === 'html_pin_food' || id === 'food_favorite_pin';
      var callAction = id === 'html_call_food' || id === 'food_favorite_call';
      var menuAction = isFoodMenuAction(id);
      if (!mapAction && !pinAction && !callAction && !menuAction) { return false; }
      if (!callAction && !menuAction && !canNavigate) { return false; }
      if (menuAction && !foodMenuActionAllowed(block, id)) { return false; }
      return true;
    });
    if (availableActions.length > 0) {
      var row = add(detail, 'div', 'editorial-actions');
      availableActions.forEach(function (action) {
        var id = text(action && action.id);
        var mapAction = id === 'html_open_food_map' || id === 'food_favorite_map';
        var callAction = id === 'html_call_food' || id === 'food_favorite_call';
        var menuAction = isFoodMenuAction(id);
        var button = add(row, 'button', menuAction ? foodMenuButtonClass(id) : (mapAction ? 'editorial-action' : 'editorial-action secondary'),
          menuAction ? '查询菜单' : (mapAction ? '导航去' : (callAction ? '拨打电话' : '固定到桌面')));
        button.type = 'button';
        button.disabled = isBusy;
        button.addEventListener('click', function (event) {
          event.stopPropagation();
          if (menuAction) { openFoodMenu(block, action); } else { postAction(action); }
        });
      });
    }
  }
  function decorateFoodActionButton(button, id) {
    var icon = add(button, 'span', 'food-action-icon');
    var path = isFoodMenuAction(id) ? '<path d="M6 7h10v7a5 5 0 0 1-10 0V7Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M16 9h1.5a2.5 2.5 0 0 1 0 5H16M8 4.5c1 1 2 1 3 0s2-1 3 0" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>' :
      (id === 'html_open_food_map' ? '<path d="M12 21s6-5.4 6-11a6 6 0 1 0-12 0c0 5.6 6 11 6 11Z" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="10" r="2.2" fill="none" stroke="currentColor" stroke-width="1.7"/>' :
        (id === 'html_call_food' ? '<path d="M7.2 4.5 9.8 7 8.2 8.8a13.5 13.5 0 0 0 7 7l1.8-1.6 2.5 2.6-1.7 2.1c-.5.6-1.4.8-2.1.5C9.1 17.1 6.9 14.9 4.6 8.3c-.3-.8-.1-1.6.5-2.1l2.1-1.7Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>' :
          '<path d="M6 4.5h12v15l-6-3-6 3v-15Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 8h6M9 11h6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>'));
    icon.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true">' + path + '</svg>';
    button.insertBefore(icon, button.firstChild);
  }
  function setExpanded(key) {
    state.expandedKey = state.expandedKey === key ? '' : key;
    Array.prototype.slice.call(document.querySelectorAll('.editorial-list > .editorial-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-card-key') === state.expandedKey;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.editorial-expand');
      if (button) { button.textContent = expanded ? '收起' : '展开'; }
    });
  }
  function numericAttribute(node, name) {
    var raw = text(node.getAttribute(name)).trim();
    if (raw.length === 0) { return Number.NaN; }
    var value = Number(raw);
    return Number.isFinite(value) ? value : Number.NaN;
  }
  function matchesFilter(node, filter) {
    var activeFilter = filter || state.filter;
    var haystack = text(node.getAttribute('data-search')).toLowerCase();
    if (activeFilter === 'featured' && node.getAttribute('data-featured') !== 'true') { return false; }
    if (activeFilter === 'within_1km' && distanceMeters(node.getAttribute('data-distance')) > 1000) { return false; }
    if (activeFilter === 'source' && text(node.getAttribute('data-sources')).length === 0) { return false; }
    if (activeFilter === 'coffee' && haystack.indexOf('咖啡') < 0 && haystack.indexOf('coffee') < 0 && haystack.indexOf('瑞幸') < 0 && haystack.indexOf('luckin') < 0) { return false; }
    if (activeFilter === 'late' && haystack.indexOf('深夜') < 0 && haystack.indexOf('夜') < 0 && haystack.indexOf('宵夜') < 0) { return false; }
    if (activeFilter === 'group' && haystack.indexOf('聚餐') < 0 && haystack.indexOf('火锅') < 0 && haystack.indexOf('烧烤') < 0) { return false; }
    if (activeFilter === 'light' && haystack.indexOf('轻食') < 0 && haystack.indexOf('沙拉') < 0 && haystack.indexOf('简餐') < 0) { return false; }
    var price = numericAttribute(node, 'data-price');
    if (state.price !== 'all' && !Number.isFinite(price)) { return false; }
    if (state.price === '0_50' && !(price >= 0 && price < 50)) { return false; }
    if (state.price === '50_100' && !(price >= 50 && price < 100)) { return false; }
    if (state.price === '100_200' && !(price >= 100 && price < 200)) { return false; }
    if (state.price === '200_plus' && !(price >= 200)) { return false; }
    var rating = numericAttribute(node, 'data-rating');
    if (state.rating !== 'all' && !Number.isFinite(rating)) { return false; }
    if (state.rating === '4' && rating < 4) { return false; }
    if (state.rating === '4_5' && rating < 4.5) { return false; }
    if (state.rating === '4_8' && rating < 4.8) { return false; }
    if (state.business === 'open' && node.getAttribute('data-business-status') !== 'open') { return false; }
    return true;
  }
  function sortCards(cards) {
    var sort = state.sort;
    cards.sort(function (a, b) {
      var av = sort === 'distance' ? distanceMeters(a.getAttribute('data-distance')) : (sort === 'rating' ? numericAttribute(a, 'data-rating') : (sort === 'price' ? numericAttribute(a, 'data-price') : Number(a.getAttribute('data-order'))));
      var bv = sort === 'distance' ? distanceMeters(b.getAttribute('data-distance')) : (sort === 'rating' ? numericAttribute(b, 'data-rating') : (sort === 'price' ? numericAttribute(b, 'data-price') : Number(b.getAttribute('data-order'))));
      if (!Number.isFinite(av)) { av = Number.POSITIVE_INFINITY; }
      if (!Number.isFinite(bv)) { bv = Number.POSITIVE_INFINITY; }
      if (av !== bv) { return sort === 'rating' ? bv - av : av - bv; }
      return Number(a.getAttribute('data-order')) - Number(b.getAttribute('data-order'));
    });
  }
  function applyFilter() {
    var cards = Array.prototype.slice.call(document.querySelectorAll('.editorial-list > .editorial-card'));
    var feature = document.querySelector('.editorial-feature');
    if (feature) { feature.style.display = matchesFilter(feature) ? '' : 'none'; }
    sortCards(cards);
    var list = document.querySelector('.editorial-list');
    cards.forEach(function (card) { if (list) { list.appendChild(card); } });
    var visible = 0;
    cards.forEach(function (card) { var keep = matchesFilter(card); if (keep) { visible += 1; } card.style.display = keep ? '' : 'none'; });
    var count = document.getElementById('editorial-count');
    var featureVisible = feature && matchesFilter(feature) ? 1 : 0;
    var visibleTotal = visible + featureVisible;
    var total = cards.length + (feature ? 1 : 0);
    if (count) {
      count.textContent = visibleTotal === total ? text(count.getAttribute('data-default-summary')) : String(visibleTotal) + ' 条结果 · 来源结果已合并';
    }
    var kicker = document.getElementById('editorial-kicker-count');
    if (kicker) { kicker.textContent = '附近餐饮 · ' + String(visibleTotal) + ' 条结果'; }
    var empty = document.getElementById('editorial-filter-empty');
    if (empty) { empty.style.display = cards.length > 0 && visible === 0 && featureVisible === 0 ? '' : 'none'; }
    Array.prototype.slice.call(document.querySelectorAll('.editorial-tab')).forEach(function (button) { button.classList.toggle('active', button.getAttribute('data-filter') === state.filter); });
  }
  function selectValue(label, values, current, setter) {
    var wrap = add(filters, 'label', 'food-control');
    var select = add(wrap, 'select');
    select.setAttribute('aria-label', label);
    values.forEach(function (item) {
      var optionLabel = item[0] === 'all' ? label : item[1];
      var option = add(select, 'option', '', optionLabel);
      option.value = item[0];
      option.selected = item[0] === current;
    });
    select.addEventListener('change', function () { setter(select.value); applyFilter(); });
  }
  function handleFilter(action) {
    var id = text(action && action.id);
    if (id === 'food_filter_featured') { state.filter = 'featured'; applyFilter(); return true; }
    if (id === 'food_filter_1km') { state.filter = 'within_1km'; applyFilter(); return true; }
    if (id === 'food_filter_source') { state.filter = 'source'; applyFilter(); return true; }
    if (id === 'food_filter_coffee') { state.filter = 'coffee'; applyFilter(); return true; }
    if (id === 'food_filter_late') { state.filter = 'late'; applyFilter(); return true; }
    if (id === 'food_filter_group') { state.filter = 'group'; applyFilter(); return true; }
    if (id === 'food_filter_light') { state.filter = 'light'; applyFilter(); return true; }
    if (id === 'food_show_all') { state.filter = 'all'; applyFilter(); return true; }
    return false;
  }
  function detailRow(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'editorial-detail-row');
    add(row, 'b', '', label);
    add(row, 'span', '', value);
  }
  function renderPersonaBanner(parent) {
    var persona = data.persona || {};
    var name = text(persona.name);
    if (text(persona.id).length === 0 || name.length === 0) {
      return;
    }
    var banner = add(parent, 'section', 'persona-banner');
    var avatar = add(banner, 'div', 'persona-avatar');
    var avatarSrc = text(data.personaAvatarDataUri);
    if (avatarSrc.length > 0) {
      var img = add(avatar, 'img');
      img.src = avatarSrc;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
    } else {
      avatar.textContent = name.slice(0, 1);
    }
    var copy = add(banner, 'div', 'persona-copy');
    add(copy, 'div', 'persona-title', name + '上线');
  }
  function confirmFoodLocation(location, label) {
    location = location || {};
    postAction({
      id: 'food_change_location', label: label || '确认新位置', prompt: label || '确认新位置', kind: 'client', variant: 'secondary',
      args: {
        surfaceId: text(data.surfaceId),
        searchArea: {
          longitude: Number(location.longitude), latitude: Number(location.latitude),
          radiusMeters: Number(location.radiusMeters) || Number(data.foodLocation && data.foodLocation.radiusMeters) || 3000,
          name: text(location.name), address: text(location.address)
        }
      }
    });
  }
  app.textContent = '';
  var shell = add(app, 'main', 'editorial-food-shell');
  var blocks = list(data.blocks).filter(function (block) { return text(block && block.kind) === 'food-result'; });
  var hero = add(shell, 'header', 'editorial-cover');
  add(hero, 'div', 'editorial-cover-media');
  var heroContent = add(hero, 'div', 'editorial-cover-content');
  var sceneKicker = add(heroContent, 'small', 'food-scene-kicker', '附近餐饮 · ' + String(blocks.length) + ' 条结果');
  sceneKicker.id = 'editorial-kicker-count';
  add(heroContent, 'h1', '', '今天附近值得吃');
  var resultSummary = add(heroContent, 'p', '', String(blocks.filter(hasLocation).length) + ' 家可导航 · 来源结果已合并');
  resultSummary.id = 'editorial-count';
  resultSummary.setAttribute('data-default-summary', resultSummary.textContent);
  var locationBar = add(heroContent, 'div', 'editorial-location-bar');
  var currentAddressButton = add(locationBar, 'button', 'food-current-address');
  currentAddressButton.type = 'button';
  var locationSymbol = add(currentAddressButton, 'span', 'food-location-symbol');
  locationSymbol.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 5-8 11-8 11S4 15 4 10a8 8 0 1 1 16 0Z" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="10" r="2.5" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>';
  var currentLocationCopy = add(currentAddressButton, 'span', 'food-location-copy');
  add(currentLocationCopy, 'small', '', '当前搜索位置');
  add(currentLocationCopy, 'strong', '', text(data.foodLocation && (data.foodLocation.name || data.foodLocation.address)) || '选择地址');
  var locationChevron = add(currentAddressButton, 'span', 'food-location-chevron');
  locationChevron.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 18 6-6-6-6" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  currentAddressButton.addEventListener('click', function () {
    postAction({ id: 'food_store_map_open', label: '打开店铺地图', prompt: '打开店铺地图',
      kind: 'client', variant: 'secondary', args: { surfaceId: text(data.surfaceId) } });
  });
  var mapEntryButton = add(locationBar, 'button', 'food-map-icon');
  mapEntryButton.type = 'button';
  mapEntryButton.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s6-5.4 6-11a6 6 0 1 0-12 0c0 5.6 6 11 6 11Z" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="10" r="2.3" fill="currentColor"/></svg>';
  mapEntryButton.setAttribute('aria-label', '地图选点');
  mapEntryButton.addEventListener('click', function () {
    var overlay = document.getElementById('food-address-overlay');
    if (overlay) { overlay.classList.add('open'); }
  });
  var favoriteEntries = list(data.foodFavorites).slice();
  var favoriteExpandedId = '';
  var favoritesEntryButton = add(locationBar, 'button', 'food-map-icon food-favorites-icon');
  favoritesEntryButton.type = 'button';
  favoritesEntryButton.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3.5 6.5h6l1.8 2H20.5v9.5a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2V6.5Z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M3.5 9h17" fill="none" stroke="currentColor" stroke-width="1.8"/></svg>';
  favoritesEntryButton.setAttribute('aria-label', '打开收藏夹');
  renderFavoriteCount();
  favoritesEntryButton.addEventListener('click', function () {
    var overlay = document.getElementById('food-favorites-overlay');
    if (overlay) { overlay.classList.add('open'); }
  });
  renderPersonaBanner(heroContent);
  if (data.foodLocationPickerHtml) {
    var mapOverlay = add(shell, 'section', 'food-map-overlay');
    mapOverlay.id = 'food-map-overlay';
    var mapOverlayHead = add(mapOverlay, 'div', 'food-map-overlay-head');
    var mapClose = add(mapOverlayHead, 'button', 'food-address-back', '‹');
    mapClose.type = 'button';
    add(mapOverlayHead, 'div', 'food-map-overlay-title', '选择搜索位置');
    function closePicker() {
      mapOverlay.classList.remove('open');
      pickerFrame.srcdoc = '';
    }
    mapClose.addEventListener('click', closePicker);
    var pickerFrame = add(mapOverlay, 'iframe', 'food-map-picker-frame');
    pickerFrame.setAttribute('title', '选择搜索位置');
    pickerFrame.setAttribute('sandbox', 'allow-scripts allow-same-origin');
    function handlePickerPayload(payload) {
      payload = payload || {};
      if (text(payload.type) !== 'confirm') { return; }
      closePicker();
      confirmFoodLocation(payload, '确认新位置');
    }
    window.AIPhoneFoodLocationPickerBridge = handlePickerPayload;
    window.addEventListener('message', function (event) {
      var bridgeMessage = event && event.data;
      if (!bridgeMessage || bridgeMessage.source !== 'AIPhoneFoodLocationPicker') { return; }
      handlePickerPayload(bridgeMessage.payload);
    });
  }
  var favoritesOverlay = add(shell, 'section', 'food-favorites-overlay');
  favoritesOverlay.id = 'food-favorites-overlay';
  var favoritesHead = add(favoritesOverlay, 'div', 'food-favorites-head');
  var favoritesClose = add(favoritesHead, 'button', 'food-address-back', '‹');
  favoritesClose.type = 'button';
  add(favoritesHead, 'div', 'food-favorites-title', '我的收藏');
  favoritesClose.addEventListener('click', function () { favoritesOverlay.classList.remove('open'); });
  var favoritesScroll = add(favoritesOverlay, 'div', 'food-favorites-scroll');
  renderFavoriteEntries();
  menuOverlay = add(shell, 'section', 'food-menu-overlay');
  menuOverlay.id = 'food-menu-overlay';
  var menuHead = add(menuOverlay, 'div', 'food-menu-head');
  var menuClose = add(menuHead, 'button', 'food-address-back', '‹');
  menuClose.type = 'button';
  menuTitle = add(menuHead, 'div', 'food-menu-title', '瑞幸菜单');
  menuClose.addEventListener('click', function () {
    menuOverlay.classList.remove('open');
    activeMenuRequestKey = '';
    activeMenuPatch = null;
  });
  menuStore = add(menuOverlay, 'div', 'food-menu-store');
  menuScroll = add(menuOverlay, 'div', 'food-menu-scroll');
  var addressOverlay = add(shell, 'section', 'food-address-overlay');
  addressOverlay.id = 'food-address-overlay';
  var addressTop = add(addressOverlay, 'div', 'food-address-top');
  var addressClose = add(addressTop, 'button', 'food-address-back', '‹');
  addressClose.type = 'button';
  var searchWrap = add(addressTop, 'div', 'food-address-search-wrap');
  add(searchWrap, 'span', 'food-address-search-icon', '⌕');
  var addressSearch = add(searchWrap, 'input', 'food-address-search');
  addressSearch.type = 'search';
  addressSearch.placeholder = '城市/区县/商场等地点';
  var addressScroll = add(addressOverlay, 'div', 'food-address-scroll');
  var defaultAddressContent = add(addressScroll, 'div', 'food-address-default');
  add(defaultAddressContent, 'div', 'food-address-current-choice', '当前选择：' +
    (text(data.foodLocation && (data.foodLocation.name || data.foodLocation.address)) || '未选择'));
  var currentCard = add(defaultAddressContent, 'section', 'food-address-card');
  var currentHead = add(currentCard, 'div', 'food-address-section-head');
  add(currentHead, 'b', '', '当前定位');
  var relocateButton = add(currentHead, 'button', 'food-address-section-action', '⌖ 重新定位');
  relocateButton.type = 'button';
  relocateButton.disabled = isBusy;
  relocateButton.addEventListener('click', function () {
    if (isBusy || relocateButton.disabled) { return; }
    relocateButton.disabled = true;
    relocateButton.textContent = '定位中…';
    postAction({
      id: 'food_relocate_current', label: '重新定位', prompt: '重新获取当前设备位置',
      kind: 'client', variant: 'secondary', args: { surfaceId: text(data.surfaceId) }
    });
    window.setTimeout(function () {
      relocateButton.disabled = false;
      relocateButton.textContent = '⌖ 重新定位';
    }, 10000);
  });
  var currentRow = add(currentCard, 'div', 'food-current-location-row');
  var currentCopy = add(currentRow, 'div', 'food-current-location-copy');
  add(currentCopy, 'div', 'food-current-location-name', text(data.foodLocation && data.foodLocation.name) || '当前搜索位置');
  add(currentCopy, 'div', 'food-current-location-detail', text(data.foodLocation && data.foodLocation.address));
  var bookCard = add(defaultAddressContent, 'section', 'food-address-card');
  var bookHead = add(bookCard, 'div', 'food-address-section-head');
  add(bookHead, 'b', '', '我的地址簿');
  var addressSave = add(bookHead, 'button', 'food-address-section-action', '保存当前地址');
  addressSave.type = 'button';
  addressSave.disabled = isBusy || !data.foodLocation;
  addressSave.addEventListener('click', function () {
    var location = data.foodLocation || {};
    var localAddressId = 'food-address-web-' + String(Date.now());
    savedAddresses = savedAddresses.filter(function (saved) {
      return Number(saved.longitude) !== Number(location.longitude) ||
        Number(saved.latitude) !== Number(location.latitude);
    });
    savedAddresses.unshift({
      id: localAddressId,
      longitude: Number(location.longitude), latitude: Number(location.latitude),
      radiusMeters: Number(location.radiusMeters) || 3000,
      name: text(location.name), address: text(location.address)
    });
    renderSavedAddresses();
    postAction({
      id: 'food_address_book_save', label: '保存当前位置', prompt: '保存当前位置', kind: 'client', variant: 'secondary',
      args: { surfaceId: text(data.surfaceId), addressId: localAddressId }
    });
  });
  var savedAddresses = list(data.foodAddressBook).slice();
  var addressList = add(bookCard, 'div', 'food-address-list');
  function renderSavedAddresses() {
    addressList.textContent = '';
    if (savedAddresses.length === 0) {
      add(addressList, 'div', 'food-address-empty', '还没有保存的地址');
      return;
    }
    savedAddresses.forEach(function (entry) {
      var row = add(addressList, 'div', 'food-address-row');
      var copy = add(row, 'div', 'food-address-copy');
      add(copy, 'div', 'food-address-name', text(entry.name) || text(entry.address) || '常用地址');
      add(copy, 'div', 'food-address-detail', text(entry.address) || (text(entry.longitude) + ', ' + text(entry.latitude)));
      copy.addEventListener('click', function () {
        addressOverlay.classList.remove('open');
        confirmFoodLocation(entry, '使用常用地址');
      });
      var deleteButton = add(row, 'button', 'food-address-delete', '删除');
      deleteButton.type = 'button';
      deleteButton.addEventListener('click', function () {
        savedAddresses = savedAddresses.filter(function (saved) { return text(saved.id) !== text(entry.id); });
        renderSavedAddresses();
        postAction({
          id: 'food_address_book_delete', label: '删除常用地址', prompt: '删除常用地址', kind: 'client', variant: 'secondary',
          args: { surfaceId: text(data.surfaceId), addressId: text(entry.id) }
        });
      });
    });
  }
  renderSavedAddresses();
  addressClose.addEventListener('click', function () { addressOverlay.classList.remove('open'); });
  var locationResults = add(addressScroll, 'section', 'food-address-card food-location-results');
  var locationSearchTimer = 0;
  var locationSearchGeneration = 0;
  function renderLocationSearchStatus(message) {
    locationResults.textContent = '';
    locationResults.classList.add('active');
    defaultAddressContent.style.display = 'none';
    add(locationResults, 'div', 'food-location-status', message);
  }
  function runLocationSearch() {
    var keyword = text(addressSearch.value).trim();
    locationSearchGeneration += 1;
    var generation = locationSearchGeneration;
    if (!keyword) {
      locationResults.classList.remove('active');
      locationResults.textContent = '';
      defaultAddressContent.style.display = '';
      return;
    }
    renderLocationSearchStatus('正在搜索…');
    var url = 'https://restapi.amap.com/v3/place/text?extensions=base&offset=20&page=1&keywords=' +
      encodeURIComponent(keyword) + '&key=' + encodeURIComponent(text(data.foodAmapKey));
    fetch(url).then(function (response) { return response.json(); }).then(function (result) {
      if (generation !== locationSearchGeneration) { return; }
      var pois = result && Array.isArray(result.pois) ? result.pois : [];
      locationResults.textContent = '';
      if (pois.length === 0) {
        add(locationResults, 'div', 'food-location-status', '没有找到相关地点');
        return;
      }
      pois.forEach(function (poi) {
        var parts = text(poi.location).split(',');
        if (parts.length !== 2) { return; }
        var resultButton = add(locationResults, 'button', 'food-location-result');
        resultButton.type = 'button';
        add(resultButton, 'div', 'food-location-result-name', text(poi.name) || keyword);
        add(resultButton, 'div', 'food-location-result-address', text(poi.pname) + text(poi.cityname) + text(poi.adname) + text(poi.address));
        resultButton.addEventListener('click', function () {
          addressOverlay.classList.remove('open');
          confirmFoodLocation({
            longitude: Number(parts[0]), latitude: Number(parts[1]),
            radiusMeters: Number(data.foodLocation && data.foodLocation.radiusMeters) || 3000,
            name: text(poi.name), address: text(poi.address) || text(poi.adname)
          }, '使用搜索地址');
        });
      });
    }).catch(function () {
      if (generation === locationSearchGeneration) { renderLocationSearchStatus('搜索失败，请稍后重试'); }
    });
  }
  addressSearch.addEventListener('input', function () {
    if (locationSearchTimer) { window.clearTimeout(locationSearchTimer); }
    locationSearchTimer = window.setTimeout(runLocationSearch, 350);
  });
  addressSearch.addEventListener('keydown', function (event) {
    if (event.key === 'Enter') {
      if (locationSearchTimer) { window.clearTimeout(locationSearchTimer); }
      runLocationSearch();
    }
  });
  var sourceCloud = add(hero, 'div', 'source-cloud');
  var seenSources = {};
  blocks.forEach(function (block) {
    sourceParts(block).forEach(function (source) {
      if (seenSources[source]) { return; }
      seenSources[source] = true;
      var pill = add(sourceCloud, 'span', 'source-pill', source);
      pill.setAttribute('data-source-key', sourceKey({ source: source }));
    });
  });
  if (Object.keys(seenSources).length === 0) { sourceCloud.style.display = 'none'; }
  var stats = add(hero, 'div', 'cover-stats');
  var count = add(stats, 'span', 'cover-stat', String(blocks.length) + ' 条');
  add(stats, 'span', 'cover-stat', String(blocks.filter(hasLocation).length) + ' 家可导航');
  var tabs = add(shell, 'nav', 'editorial-tabs appless-v2-food-tabs');
  var filters = add(shell, 'section', 'food-filters appless-v2-food-filters');
  var filterItems = [
    ['food_show_all', '全部', 'all'],
    ['food_filter_featured', '精选', 'featured'],
    ['food_filter_1km', '1公里内', 'within_1km'],
    ['food_filter_source', '来源', 'source'],
    ['food_filter_coffee', '咖啡', 'coffee'],
    ['food_filter_late', '深夜', 'late'],
    ['food_filter_group', '聚餐', 'group'],
    ['food_filter_light', '轻食', 'light']
  ];
  selectValue('价格', [['all', '不限'], ['0_50', '¥0-50'], ['50_100', '¥50-100'], ['100_200', '¥100-200'], ['200_plus', '¥200+']], state.price, function (value) { state.price = value; });
  selectValue('评分', [['all', '不限'], ['4', '4.0+'], ['4_5', '4.5+'], ['4_8', '4.8+']], state.rating, function (value) { state.rating = value; });
  selectValue('营业', [['all', '不限'], ['open', '营业中']], state.business, function (value) { state.business = value; });
  selectValue('排序', [['smart', '智能排序'], ['distance', '距离最近'], ['rating', '评分最高'], ['price', '价格最低']], state.sort, function (value) { state.sort = value; });
  if (blocks.length > 0) {
    var featureBlock = blocks[0];
    var feature = add(shell, 'section', 'editorial-feature appless-v2-food-card featured');
    feature.setAttribute('data-card-key', text(featureBlock.id) || '0');
    feature.setAttribute('data-source-key', sourceKey(featureBlock));
    feature.setAttribute('data-distance', metric(featureBlock, ['distance']));
    feature.setAttribute('data-price', metric(featureBlock, ['pricePerPerson']));
    feature.setAttribute('data-rating', metric(featureBlock, ['rating']));
    feature.setAttribute('data-business-status', metric(featureBlock, ['businessStatus']));
    feature.setAttribute('data-featured', 'true');
    feature.setAttribute('data-sources', sourceParts(featureBlock).join(' / '));
    feature.setAttribute('data-search', [text(featureBlock.title), text(featureBlock.subtitle), metric(featureBlock, ['category']), metric(featureBlock, ['address']), sourceParts(featureBlock).join(' ')].join(' '));
    var featureMedia = add(feature, 'div', 'editorial-feature-media appless-v2-food-photo');
    add(featureMedia, 'span', 'editorial-badge', '为你推荐');
    var featureIcon = add(featureMedia, 'i', 'food-feature-icon');
    featureIcon.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 8h12M7 8v8.5A2.5 2.5 0 0 0 9.5 19h5A2.5 2.5 0 0 0 17 16.5V8M9 5h6l1 3H8l1-3Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/><path d="M10 3.5c1.2 1 2.8 1 4 0" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>';
    var featureCopy = add(feature, 'div', 'editorial-feature-copy appless-v2-food-copy');
    var featureTopline = add(featureCopy, 'div', 'food-card-topline');
    add(featureTopline, 'span', 'editorial-badge', '为你推荐');
    addFavoriteToggle(featureTopline, featureBlock);
    var featureHead = add(featureCopy, 'div', 'editorial-card-head appless-v2-card-head');
    var featureTitle = add(featureHead, 'div', 'editorial-title');
    add(featureTitle, 'small', '', sourceParts(featureBlock).join(' · ') || '附近餐饮');
    add(featureTitle, 'h2', '', text(featureBlock.title) || '餐饮结果');
    add(featureCopy, 'p', '', [metric(featureBlock, ['category']), metric(featureBlock, ['distance']), metric(featureBlock, ['ratingText', 'rating']), metric(featureBlock, ['priceText', 'pricePerPerson']), metric(featureBlock, ['businessStatusLabel']), metric(featureBlock, ['openHoursToday'])].filter(Boolean).join(' · '));
    var featureDetail = add(featureCopy, 'div', 'editorial-detail appless-v2-food-detail');
    var featureGrid = add(featureDetail, 'div', 'editorial-detail-grid');
    detailRow(featureGrid, '地址', metric(featureBlock, ['address']));
    detailRow(featureGrid, '今日营业', metric(featureBlock, ['openHoursToday']) || metric(featureBlock, ['openHoursWeek']));
    detailRow(featureGrid, '电话', metric(featureBlock, ['phone']));
    var featureActions = list(featureBlock.actions).filter(function (action) {
      var id = text(action && action.id);
      var menuAction = isFoodMenuAction(id);
      if (id !== 'html_open_food_map' && id !== 'html_pin_food' && id !== 'html_call_food' && !menuAction) { return false; }
      if (id !== 'html_call_food' && !menuAction && !hasLocation(featureBlock)) { return false; }
      if (menuAction && !foodMenuActionAllowed(featureBlock, id)) { return false; }
      return true;
    });
    if (featureActions.length > 0) {
      var featureActionRow = add(featureDetail, 'div', 'editorial-actions food-actions appless-v2-card-actions');
      featureActions.forEach(function (action) {
        var id = text(action && action.id);
        var menuAction = isFoodMenuAction(id);
        var button = add(featureActionRow, 'button', menuAction ? foodMenuButtonClass(id) : 'editorial-action',
          menuAction ? '查询菜单' : (id === 'html_open_food_map' ? '导航去' : (id === 'html_call_food' ? '拨打电话' : '固定到桌面')));
        button.type = 'button';
        button.disabled = isBusy;
        decorateFoodActionButton(button, id);
        button.addEventListener('click', function (event) {
          event.stopPropagation();
          if (menuAction) { openFoodMenu(featureBlock, action); } else { postAction(action); }
        });
      });
    }
  }
  var listNode = add(shell, 'section', 'editorial-list');
  var empty = add(listNode, 'div', 'editorial-empty', '当前筛选下暂无匹配餐饮。');
  empty.id = 'editorial-filter-empty';
  empty.style.display = 'none';
  blocks.forEach(function (block, index) {
    if (index === 0) { return; }
    var key = text(block.id) || String(index);
    var card = add(listNode, 'article', 'editorial-card appless-v2-food-list-card');
    card.setAttribute('data-card-key', key);
    card.setAttribute('data-source-key', sourceKey(block));
    card.setAttribute('data-distance', metric(block, ['distance']));
    card.setAttribute('data-price', metric(block, ['pricePerPerson']));
    card.setAttribute('data-rating', metric(block, ['rating']));
    card.setAttribute('data-business-status', metric(block, ['businessStatus']));
    card.setAttribute('data-order', String(index));
    card.setAttribute('data-featured', index === 0 ? 'true' : 'false');
    card.setAttribute('data-sources', sourceParts(block).join(' / '));
    card.setAttribute('data-search', [text(block.title), text(block.subtitle), metric(block, ['category']), metric(block, ['address']), sourceParts(block).join(' ')].join(' '));
    card.setAttribute('aria-expanded', 'false');
    var head = add(card, 'div', 'editorial-card-head');
    addAvatar(head, block);
    var title = add(head, 'div', 'editorial-title');
    add(title, 'h2', '', text(block.title) || '餐饮结果');
    add(title, 'div', 'editorial-meta', [metric(block, ['category']) || text(block.subtitle), metric(block, ['distance']), metric(block, ['ratingText', 'rating']), metric(block, ['priceText', 'pricePerPerson']), metric(block, ['businessStatusLabel'])].filter(Boolean).join(' · '));
    var headActions = add(head, 'div', 'food-card-head-actions');
    addFavoriteToggle(headActions, block);
    var expand = add(headActions, 'button', 'editorial-expand', '展开');
    expand.type = 'button';
    expand.addEventListener('click', function (event) { event.stopPropagation(); setExpanded(key); });
    card.addEventListener('click', function () { setExpanded(key); });
    var sources = sourceParts(block);
    if (sources.length > 0) {
      var sourceRow = add(card, 'div', 'editorial-source-row');
      sources.forEach(function (source) { add(sourceRow, 'span', 'editorial-source', source); });
    }
    var detail = add(card, 'div', 'editorial-detail');
    var grid = add(detail, 'div', 'editorial-detail-grid');
    detailRow(grid, '地址', metric(block, ['address']));
    detailRow(grid, '分类', metric(block, ['category']) || text(block.subtitle));
    detailRow(grid, '距离', metric(block, ['distance']));
    detailRow(grid, '评分', metric(block, ['ratingText', 'rating']));
    detailRow(grid, '人均价格', metric(block, ['priceText', 'pricePerPerson']));
    detailRow(grid, '营业状态', metric(block, ['businessStatusLabel']));
    detailRow(grid, '今日营业', metric(block, ['openHoursToday']) || metric(block, ['openHoursWeek']));
    detailRow(grid, '营业时间', metric(block, ['openHoursWeek']));
    detailRow(grid, '坐标', metric(block, ['location']));
    detailRow(grid, '来源', sourceParts(block).join(' / '));
    detailRow(grid, '电话', metric(block, ['phone']));
    detailRow(grid, '电话来源', metric(block, ['phoneSource']));
    var canNavigate = hasLocation(block);
    var availableActions = list(block.actions).filter(function (action) {
      var id = text(action && action.id);
      var menuAction = isFoodMenuAction(id);
      if (id !== 'html_open_food_map' && id !== 'html_pin_food' && id !== 'html_call_food' && !menuAction) { return false; }
      if (id !== 'html_call_food' && !menuAction && !canNavigate) { return false; }
      if (menuAction && !foodMenuActionAllowed(block, id)) { return false; }
      return true;
    });
    if (availableActions.length > 0) {
      var row = add(detail, 'div', 'editorial-actions');
      availableActions.forEach(function (action) {
        var id = text(action && action.id);
        var menuAction = isFoodMenuAction(id);
        var button = add(row, 'button', menuAction ? foodMenuButtonClass(id) :
          (id === 'html_open_food_map' ? 'editorial-action' : 'editorial-action secondary'),
          menuAction ? '查询菜单' : (id === 'html_open_food_map' ? '导航去' : (id === 'html_call_food' ? '拨打电话' : '固定到桌面')));
        button.type = 'button';
        button.disabled = isBusy;
        decorateFoodActionButton(button, id);
        button.addEventListener('click', function (event) {
          event.stopPropagation();
          if (menuAction) { openFoodMenu(block, action); } else { postAction(action); }
        });
      });
    }
  });
  var addressFunctions = add(shell, 'section', 'appless-v2-address-functions');
  var addressFunctionIcon = add(addressFunctions, 'i');
  addressFunctionIcon.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10.5 12 4l8 6.5v8a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 18.5v-8Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 20v-5h6v5M8 10h.01M12 10h.01M16 10h.01" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg>';
  var addressFunctionCopy = add(addressFunctions, 'div');
  add(addressFunctionCopy, 'strong', '', '位置与地址簿功能保持');
  add(addressFunctionCopy, 'p', '', '地址搜索、地图选点、重新定位、保存地址、使用常用地址、删除地址');
  var addressFunctionButton = add(addressFunctions, 'button', '', '换位置');
  addressFunctionButton.type = 'button';
  addressFunctionButton.disabled = isBusy;
  addressFunctionButton.addEventListener('click', function () {
    var overlay = document.getElementById('food-address-overlay');
    if (overlay) { overlay.classList.add('open'); }
  });
  filterItems.forEach(function (item) {
    var button = add(tabs, 'button', 'editorial-tab', item[1]);
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-action', item[0]);
    button.setAttribute('data-filter', item[2]);
    button.addEventListener('click', function () { handleFilter({ id: item[0], label: item[1] }); });
  });
  applyFilter();
})();
`;

export function shouldRenderFoodHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'food') {
    return false;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    if (blocks[index].kind === 'food-result') {
      return true;
    }
  }
  return false;
}

export function renderFoodHomeDocument(
  document: HtmlHomeDocument,
  isBusy: boolean = false,
  foodLocation?: FoodLocationViewModel,
  foodAddressBook: FoodSavedAddressViewModel[] = [],
  foodFavorites: FoodFavoriteViewModel[] = []
): string {
  const surfaceArea = document.foodSearchContext === undefined ? undefined :
    document.foodSearchContext.searchArea;
  const effectiveLocation: FoodLocationViewModel | undefined = surfaceArea === undefined ? foodLocation : {
    longitude: surfaceArea.longitude,
    latitude: surfaceArea.latitude,
    radiusMeters: surfaceArea.radiusMeters,
    name: surfaceArea.name,
    address: surfaceArea.address
  };
  const renderDocument: HtmlFoodHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: foodBlocksWithFavorites(document.blocks, foodFavorites),
    actions: document.actions,
    history: [],
    persona: document.persona,
    personaMemory: document.personaMemory,
    personaAvatarDataUri: personaAvatarDataUri(document.persona.avatarKey),
    surfaceId: document.surfaceId,
    foodLocation: effectiveLocation,
    foodAddressBook: foodAddressBook,
    foodFavorites: foodFavorites,
    foodAmapKey: rideAmapWebKeyForUi(),
    foodLocationPickerHtml: effectiveLocation === undefined ? '' : renderFoodLocationPickerHtml({
      amapKey: rideAmapWebKeyForUi(),
      amapSecurityJsCode: '',
      initialLongitude: effectiveLocation.longitude,
      initialLatitude: effectiveLocation.latitude
    }),
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlFoodHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '今日附近值得吃');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${FOOD_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${FOOD_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlFoodTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
