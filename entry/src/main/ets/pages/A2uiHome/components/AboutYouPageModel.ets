export const ABOUT_YOU_BOOTSTRAP_URL: string =
  'data:text/html;charset=utf-8,<html><body style="margin:0;background:transparent"></body></html>';
export const ABOUT_YOU_DOCUMENT_URL: string = 'https://about-you.aiphone.local/';

export function aboutYouAllowsNavigation(url: string, ownedDocumentUrl: string = ''): boolean {
  return (ownedDocumentUrl.length > 0 && url === ownedDocumentUrl) || url === 'about:blank';
}

export interface AboutYouClaim {
  index: number;
  heading: string;
  body: string;
}

export interface AboutYouSection {
  id: string;
  title: string;
  inferred: boolean;
  claims: AboutYouClaim[];
}

export interface AboutYouAccount {
  id: string;
  platform: string;
  displayName: string;
  handle: string;
  avatarUrl?: string;
}

export interface AboutYouCandidate extends AboutYouAccount {
  summary: string;
  selected: boolean;
}

export interface AboutYouSocialState {
  phase: 'idle' | 'input' | 'searching' | 'confirm' | 'generating' | 'draft' | 'error';
  username: string;
  mode: 'exact' | 'fuzzy';
  candidates: AboutYouCandidate[];
  progress: string;
  error: string;
  markdown: string;
  draftId: string;
  importing: boolean;
}

export interface AboutYouViewModel {
  platformLogos?: Record<string, string>;
  displayName: string;
  summary: string;
  tagList: string[];
  mbtiType: string;
  mbtiConfidence: number;
  sections: AboutYouSection[];
  overviewState: 'empty' | 'loading' | 'ready' | 'error';
  overviewError: string;
  updating: boolean;
  correctionDisabled: boolean;
  updateError: string;
  correctionRevision: number;
  overviewRevision: number;
  accounts: AboutYouAccount[];
  social: AboutYouSocialState;
}

export interface AboutYouAction {
  type: string;
  text?: string;
  claimIndex?: number;
  overviewRevision?: number;
  username?: string;
  mode?: 'exact' | 'fuzzy';
  candidateIds?: string[];
  displayName?: string;
  markdown?: string;
}

interface AboutYouBridgeEnvelope extends AboutYouAction {
  token: string;
}

export function emptyAboutYouViewModel(): AboutYouViewModel {
  return {
    displayName: '', summary: '', tagList: [], mbtiType: '', mbtiConfidence: 0, sections: [], overviewState: 'empty',
    overviewError: '', updating: false, correctionDisabled: false, updateError: '', correctionRevision: 0, overviewRevision: 0, accounts: [],
    social: { phase: 'idle', username: '', mode: 'fuzzy', candidates: [], progress: '', error: '',
      markdown: '', draftId: '', importing: false }
  };
}

// The bridge accepts only narrowly scoped user actions from this local document.
export function parseAboutYouAction(raw: string, token: string): AboutYouAction | null {
  if (raw.length > 150000) return null;
  try {
    const message = JSON.parse(raw) as AboutYouBridgeEnvelope;
    if (message === null || typeof message !== 'object' || message.token !== token) return null;
    const type = message.type;
    if (type === 'back' || type === 'ready' || type === 'social_open' || type === 'social_retry' ||
      type === 'social_discard' || type === 'overview_refresh') return { type };
    if (type === 'correct' && typeof message.text === 'string' && message.text.trim().length > 0 &&
      message.text.length <= 8000 && typeof message.claimIndex === 'number' &&
      Number.isInteger(message.claimIndex) && message.claimIndex >= -1 &&
      typeof message.overviewRevision === 'number' && Number.isInteger(message.overviewRevision) &&
      message.overviewRevision >= 0) {
      return { type, text: message.text.trim(), claimIndex: message.claimIndex, overviewRevision: message.overviewRevision };
    }
    if (type === 'social_search' && typeof message.username === 'string' &&
      message.username.trim().length > 0 && message.username.length <= 160 &&
      (message.mode === 'exact' || message.mode === 'fuzzy')) {
      return { type, username: message.username.trim(), mode: message.mode };
    }
    if (type === 'social_confirm' && Array.isArray(message.candidateIds) &&
      message.candidateIds.length > 0 && message.candidateIds.length <= 200 &&
      typeof message.displayName === 'string' && message.displayName.length <= 160) {
      const candidateIds: string[] = [];
      for (let index = 0; index < message.candidateIds.length; index++) {
        const id = message.candidateIds[index];
        if (typeof id !== 'string' || id.length === 0 || id.length > 512) return null;
        if (candidateIds.indexOf(id) < 0) candidateIds.push(id);
      }
      return { type, candidateIds, displayName: message.displayName.trim() };
    }
    if ((type === 'social_edit' || type === 'social_import') && typeof message.markdown === 'string' &&
      message.markdown.length <= 60000 && (type === 'social_edit' || message.markdown.trim().length > 0)) {
      return { type, markdown: message.markdown };
    }
  } catch (_error) { return null; }
  return null;
}
