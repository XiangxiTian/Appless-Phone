export interface UiRevisionVector {
  epoch: number;
  layout: number;
  data: number;
  runtime: number;
  user: number;
}

export function initialUiRevision(epoch: number = 0): UiRevisionVector {
  return { epoch, layout: 0, data: 0, runtime: 0, user: 0 };
}

export function cloneUiRevision(value: UiRevisionVector): UiRevisionVector {
  return {
    epoch: value.epoch,
    layout: value.layout,
    data: value.data,
    runtime: value.runtime,
    user: value.user
  };
}

export function uiRevisionEqual(left: UiRevisionVector, right: UiRevisionVector): boolean {
  return left.epoch === right.epoch &&
    left.layout === right.layout &&
    left.data === right.data &&
    left.runtime === right.runtime &&
    left.user === right.user;
}

export interface UiMutationMeta {
  mutationId: string;
  runId: string;
  surfaceId: string;
  epoch: number;
  baseRevision: UiRevisionVector;
  nextRevision: UiRevisionVector;
}

export type UiRevisionDomain = 'layout' | 'data' | 'runtime' | 'user';

export type UiRevisionRejectReason =
  'accepted' |
  'INVALID_MUTATION' |
  'SURFACE_MISMATCH' |
  'STALE_EPOCH' |
  'DUPLICATE_MUTATION' |
  'BASE_REVISION_MISMATCH' |
  'REVISION_REGRESSION' |
  'REVISION_GAP' |
  'INVALID_SNAPSHOT';

export interface UiRevisionGateResult {
  accepted: boolean;
  reason: UiRevisionRejectReason;
  revision: UiRevisionVector;
}
