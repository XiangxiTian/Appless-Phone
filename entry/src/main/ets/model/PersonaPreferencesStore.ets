import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PersonaEditableSnapshot } from './PersonaTypes';
import { applyPersonaEditableSnapshots, personaEditableSnapshots } from './PersonaStore';

export const PERSONA_STORE_NAME: string = 'aiphone_persona_store';
const PERSONA_STORE_KEY: string = 'editable_personas';
const PERSONA_STORE_VERSION_KEY: string = 'editable_personas_version';
const PERSONA_STORE_VERSION: string = 'persona_skill_memory_v2';

function textFromValue(value: preferences.ValueType | string | number | boolean | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function snapshotsFromJson(raw: string): PersonaEditableSnapshot[] {
  if (raw.trim().length === 0) {
    return [];
  }
  const parsed = JSON.parse(raw) as PersonaEditableSnapshot[];
  return Array.isArray(parsed) ? parsed : [];
}

export class PreferencesPersonaPackStore {
  private context: common.Context;
  private injected: preferences.Preferences | null;
  private storeName: string;

  constructor(context: common.Context, injected: preferences.Preferences | null = null,
    storeName: string = PERSONA_STORE_NAME) {
    this.context = context;
    this.injected = injected;
    this.storeName = storeName;
  }

  private preferences(): preferences.Preferences | null {
    if (this.injected !== null) return this.injected;
    try {
      return preferences.getPreferencesSync(this.context, { name: this.storeName });
    } catch (_error) {
      return null;
    }
  }

  loadSync(): void {
    const store = this.preferences();
    if (store === null) {
      return;
    }
    try {
      if (textFromValue(store.getSync(PERSONA_STORE_VERSION_KEY, '')) !== PERSONA_STORE_VERSION) {
        return;
      }
      applyPersonaEditableSnapshots(snapshotsFromJson(textFromValue(store.getSync(PERSONA_STORE_KEY, ''))));
    } catch (_error) {
    }
  }

  saveSync(): boolean {
    const store = this.preferences();
    if (store === null) {
      return false;
    }
    try {
      store.putSync(PERSONA_STORE_KEY, JSON.stringify(personaEditableSnapshots()));
      store.putSync(PERSONA_STORE_VERSION_KEY, PERSONA_STORE_VERSION);
      store.flushSync();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
