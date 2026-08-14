import {
  cloneUiRevision,
  initialUiRevision,
  UiMutationMeta,
  UiRevisionDomain,
  UiRevisionGateResult,
  UiRevisionRejectReason,
  UiRevisionVector
} from '../ir/UiRevisionTypes';

export interface UiRevisionGateSnapshot {
  surfaceId: string;
  runId: string;
  epoch: number;
  revision: UiRevisionVector;
  acceptedMutationIds: string[];
}

interface UiRevisionGateState extends UiRevisionGateSnapshot {
  mutationIdSet: Set<string>;
}

function cloneSnapshot(snapshot: UiRevisionGateSnapshot): UiRevisionGateSnapshot {
  return {
    surfaceId: snapshot.surfaceId,
    runId: snapshot.runId,
    epoch: snapshot.epoch,
    revision: cloneUiRevision(snapshot.revision),
    acceptedMutationIds: snapshot.acceptedMutationIds.slice()
  };
}

function result(
  accepted: boolean,
  reason: UiRevisionRejectReason,
  revision: UiRevisionVector
): UiRevisionGateResult {
  return { accepted, reason, revision: cloneUiRevision(revision) };
}

function domainRevision(revision: UiRevisionVector, domain: UiRevisionDomain): number {
  if (domain === 'layout') return revision.layout;
  if (domain === 'data') return revision.data;
  if (domain === 'runtime') return revision.runtime;
  return revision.user;
}

function setDomainRevision(revision: UiRevisionVector, domain: UiRevisionDomain, value: number): void {
  if (domain === 'layout') revision.layout = value;
  else if (domain === 'data') revision.data = value;
  else if (domain === 'runtime') revision.runtime = value;
  else revision.user = value;
}

/**
 * Serializes per-surface mutation admission. It intentionally gates one
 * revision domain at a time so data hydration can race layout without
 * invalidating an unrelated layout revision.
 */
export class UiRevisionGate {
  private readonly states: Map<string, UiRevisionGateState> = new Map<string, UiRevisionGateState>();
  private readonly mutationCapacity: number;

  constructor(mutationCapacity: number = 128) {
    if (mutationCapacity <= 0) throw new Error('INVALID_MUTATION_CAPACITY');
    this.mutationCapacity = mutationCapacity;
  }

  openSurface(
    surfaceId: string,
    runId: string,
    epoch: number,
    revision: UiRevisionVector = initialUiRevision(epoch)
  ): void {
    if (surfaceId.length === 0 || runId.length === 0 || epoch < 0 || revision.epoch !== epoch) {
      throw new Error('INVALID_REVISION_SURFACE');
    }
    const existing = this.states.get(surfaceId);
    if (existing !== undefined && existing.epoch === epoch && existing.runId === runId) return;
    this.states.set(surfaceId, {
      surfaceId,
      runId,
      epoch,
      revision: cloneUiRevision(revision),
      acceptedMutationIds: [],
      mutationIdSet: new Set<string>()
    });
  }

  evaluate(meta: UiMutationMeta, domain: UiRevisionDomain): UiRevisionGateResult {
    const state = this.states.get(meta.surfaceId);
    if (meta.mutationId.length === 0 || meta.runId.length === 0 || meta.surfaceId.length === 0) {
      return result(false, 'INVALID_MUTATION', state === undefined ? initialUiRevision(meta.epoch) : state.revision);
    }
    if (state === undefined || state.runId !== meta.runId) {
      return result(false, 'SURFACE_MISMATCH', state === undefined ? initialUiRevision(meta.epoch) : state.revision);
    }
    if (meta.epoch !== state.epoch || meta.baseRevision.epoch !== state.epoch || meta.nextRevision.epoch !== state.epoch) {
      return result(false, 'STALE_EPOCH', state.revision);
    }
    if (state.mutationIdSet.has(meta.mutationId)) {
      return result(false, 'DUPLICATE_MUTATION', state.revision);
    }
    if (domainRevision(meta.baseRevision, domain) !== domainRevision(state.revision, domain)) {
      return result(false, 'BASE_REVISION_MISMATCH', state.revision);
    }
    const next = domainRevision(meta.nextRevision, domain);
    const current = domainRevision(state.revision, domain);
    if (next <= current) return result(false, 'REVISION_REGRESSION', state.revision);
    if (next !== current + 1) return result(false, 'REVISION_GAP', state.revision);

    setDomainRevision(state.revision, domain, next);
    state.acceptedMutationIds.push(meta.mutationId);
    state.mutationIdSet.add(meta.mutationId);
    while (state.acceptedMutationIds.length > this.mutationCapacity) {
      const removed = state.acceptedMutationIds.shift();
      if (removed !== undefined) state.mutationIdSet.delete(removed);
    }
    return result(true, 'accepted', state.revision);
  }

  current(surfaceId: string): UiRevisionVector | null {
    const state = this.states.get(surfaceId);
    return state === undefined ? null : cloneUiRevision(state.revision);
  }

  syncDomain(
    surfaceId: string,
    runId: string,
    epoch: number,
    domain: UiRevisionDomain,
    revision: number
  ): void {
    if (revision < 0) throw new Error('INVALID_REVISION');
    let state = this.states.get(surfaceId);
    if (state === undefined || state.epoch !== epoch || state.runId !== runId) {
      this.openSurface(surfaceId, runId, epoch, initialUiRevision(epoch));
      state = this.states.get(surfaceId);
    }
    if (state !== undefined && revision > domainRevision(state.revision, domain)) {
      setDomainRevision(state.revision, domain, revision);
    }
  }

  snapshot(surfaceId: string): UiRevisionGateSnapshot | null {
    const state = this.states.get(surfaceId);
    return state === undefined ? null : cloneSnapshot(state);
  }

  restore(snapshot: UiRevisionGateSnapshot): boolean {
    if (snapshot.surfaceId.length === 0 || snapshot.runId.length === 0 || snapshot.epoch < 0 ||
      snapshot.revision.epoch !== snapshot.epoch) return false;
    const mutationIdSet: Set<string> = new Set<string>();
    const acceptedMutationIds: string[] = [];
    for (let index = 0; index < snapshot.acceptedMutationIds.length; index++) {
      const mutationId = snapshot.acceptedMutationIds[index];
      if (mutationId.length === 0 || mutationIdSet.has(mutationId)) return false;
      mutationIdSet.add(mutationId);
      acceptedMutationIds.push(mutationId);
    }
    while (acceptedMutationIds.length > this.mutationCapacity) acceptedMutationIds.shift();
    this.states.set(snapshot.surfaceId, {
      surfaceId: snapshot.surfaceId,
      runId: snapshot.runId,
      epoch: snapshot.epoch,
      revision: cloneUiRevision(snapshot.revision),
      acceptedMutationIds,
      mutationIdSet: new Set<string>(acceptedMutationIds)
    });
    return true;
  }

  remove(surfaceId: string): boolean {
    return this.states.delete(surfaceId);
  }
}
