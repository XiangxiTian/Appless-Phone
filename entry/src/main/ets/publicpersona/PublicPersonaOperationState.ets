import {
  PublicPersonaSnapshot,
  sanitizePublicPersonaSnapshot
} from './PublicPersonaModel';

export function serializePublicPersonaViewModel(snapshot: PublicPersonaSnapshot | null): string {
  if (snapshot === null) return '';
  try {
    const safe = sanitizePublicPersonaSnapshot(snapshot as Object);
    return safe === null ? '' : JSON.stringify(safe);
  } catch (_error) {
    return '';
  }
}

export function parsePublicPersonaViewModel(raw: string): PublicPersonaSnapshot | null {
  const source = raw.trim();
  if (source.length === 0) return null;
  try {
    return sanitizePublicPersonaSnapshot(JSON.parse(source) as Object);
  } catch (_error) {
    return null;
  }
}

export function publicPersonaTagGenerationIsCurrent(
  operationGeneration: number,
  currentGeneration: number
): boolean {
  return operationGeneration === currentGeneration;
}

/** A draft may only commit for the page and account that started this operation. */
export function aboutYouSocialOperationIsCurrent(
  pageOpen: boolean,
  authenticated: boolean,
  operationGeneration: number,
  currentGeneration: number,
  operationOwnerGeneration: number,
  currentOwnerGeneration: number
): boolean {
  return pageOpen && authenticated && operationGeneration === currentGeneration &&
    operationOwnerGeneration === currentOwnerGeneration;
}

export function publicPersonaResetFailureMessage(message: string, snapshotRestored: boolean): string {
  return snapshotRestored ? message : message + ' 当前画像恢复失败，请重新进入页面确认。';
}
