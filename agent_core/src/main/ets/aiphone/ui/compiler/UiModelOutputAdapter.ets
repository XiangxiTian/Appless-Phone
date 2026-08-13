import { UiCanonicalSurface } from '../ir/UiCanonicalTypes';
import { UiBindingSet } from '../ir/UiBindingTypes';
import { UiCatalogRegistry } from '../catalog/UiCatalogRegistry';

export type UiModelOutputFormat = 'a2ui-json' | 'ui-lang';

export interface UiCompileContext {
  surfaceId: string;
  runId: string;
  epoch: number;
  catalogGroups: string[];
  catalogRegistry: UiCatalogRegistry;
  title?: string;
  intent?: string;
}

export interface UiComponentCandidate {
  id: string;
  component: string;
  children: string[];
  props: Object;
  bindings: UiBindingSet;
  actionRefs: string[];
}

export interface UiModelCandidate {
  surfaceId: string;
  rootId: string;
  title: string;
  intent: string;
  catalogVersion: string;
  components: UiComponentCandidate[];
  sourceFormat: UiModelOutputFormat;
}

export interface UiCompileError {
  code: string;
  message: string;
  source?: string;
}

export interface UiCompileResult {
  ok: boolean;
  candidate: UiModelCandidate | null;
  surface: UiCanonicalSurface | null;
  errors: UiCompileError[];
}

export interface UiModelOutputAdapter {
  format(): UiModelOutputFormat;
  compile(text: string, context: UiCompileContext): UiCompileResult;
}

export function compileFailure(errors: UiCompileError[]): UiCompileResult {
  return { ok: false, candidate: null, surface: null, errors };
}
