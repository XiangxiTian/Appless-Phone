const ACCOUNT_SCOPED_PREFERENCE_BASE_NAMES: string[] = [
  'aiphone_discovery_memory_projection',
  'aiphone_waterfall_preferences',
  'aiphone_public_persona',
  'aiphone_persona_store',
  'aiphone_bim_store',
  'aiphone_daily_brief_store',
  'aiphone_food_address_book',
  'aiphone_food_favorites',
  'aiphone_train_presale_tasks',
  'navigation_card_snapshot_store',
  'loop_conversation'
];

/** Complete Preferences migration allowlist for first-account legacy claiming. */
export function accountScopedPreferenceStoreBaseNames(): string[] {
  return ACCOUNT_SCOPED_PREFERENCE_BASE_NAMES.slice();
}

/**
 * Returns the Preferences name for one signed-in account.
 *
 * An omitted owner keeps the historical application-wide name so existing callers and
 * pre-account installations remain compatible. Production owner IDs are SHA-256 hex strings;
 * the fallback encoding keeps test or future identifiers out of filesystem-facing names.
 */
export function accountScopedStoreName(baseName: string, ownerId: string = ''): string {
  const base: string = baseName.trim();
  if (base.length === 0) throw new Error('Preferences base store name must not be empty.');
  const owner: string = ownerId.trim();
  if (owner.length === 0) return base;
  return base + '__owner_' + safeStoreScope(owner);
}

function safeStoreScope(ownerId: string): string {
  let safe: boolean = true;
  for (let index = 0; index < ownerId.length; index += 1) {
    const code: number = ownerId.charCodeAt(index);
    const digit: boolean = code >= 48 && code <= 57;
    const lower: boolean = code >= 97 && code <= 122;
    const upper: boolean = code >= 65 && code <= 90;
    if (!digit && !lower && !upper && code !== 45 && code !== 95) {
      safe = false;
      break;
    }
  }
  if (safe) return ownerId;
  let encoded: string = 'u';
  for (let index = 0; index < ownerId.length; index += 1) {
    const hex: string = ownerId.charCodeAt(index).toString(16);
    for (let padding = hex.length; padding < 4; padding += 1) encoded += '0';
    encoded += hex;
  }
  return encoded;
}
