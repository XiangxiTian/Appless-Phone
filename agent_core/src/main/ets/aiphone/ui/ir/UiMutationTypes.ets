import { UiMutationMeta } from './UiRevisionTypes';

export type UiMutationKind = 'layout' | 'data' | 'runtime' | 'user';

export interface UiMutation {
  kind: UiMutationKind;
  meta: UiMutationMeta;
  payload: Object;
}

export interface UiLayoutMutationPayload {
  operation: 'insert' | 'replace' | 'remove' | 'move';
  nodeKey: string;
  parentNodeKey?: string;
  afterNodeKey?: string;
  node?: Object;
}

export interface UiDataMutationPayload {
  path: string;
  value: Object | string | number | boolean | null;
}

export interface UiRuntimeMutationPayload {
  nodeKey: string;
  phase: 'predicted' | 'confirmed' | 'hydrated' | 'error';
  error?: string;
}

export interface UiUserMutationPayload {
  nodeKey: string;
  operation: 'pin' | 'unpin' | 'hide' | 'show' | 'move';
  afterNodeKey?: string;
}
