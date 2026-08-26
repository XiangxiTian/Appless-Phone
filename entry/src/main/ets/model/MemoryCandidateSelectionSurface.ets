import {
  A2uiAction,
  A2uiComponent,
  A2uiLabelValueData,
  A2uiSurfaceState
} from '@loop/agent-core';

export const MEMORY_CANDIDATE_SELECTION_COMPONENT_ID: string = 'memory_candidate_selection';
export const MEMORY_FORGET_CONFIRMATION_COMPONENT_ID: string = 'memory_forget_confirmation';
export const MEMORY_CANDIDATES_FORGET_ACTION_ID: string = 'memory_candidates_forget';

type MemoryCandidateActionValue = Object | string[] | string | number | boolean | null | undefined;

export interface MemoryCandidateSelectionItem {
  candidateKey: string;
  fact: string;
  personaTag: string;
  authority: 'leader' | 'seed';
}

export interface MemoryCandidateSelectionSurfaceInput {
  selectionId: string;
  revision: number;
  candidates: MemoryCandidateSelectionItem[];
}

export interface MemoryCandidatesForgetActionArgs {
  selectionId: string;
  revision: number;
  candidateKeys: string[];
}

export interface MemoryCandidateSelectionDataCandidate {
  candidateKey: string;
  fact: string;
}

export interface MemoryCandidateSelectionData {
  selectionId: string;
  revision: number;
  candidates: MemoryCandidateSelectionDataCandidate[];
}

interface MemoryCandidateSelectionDataModel {
  rows: A2uiLabelValueData[];
  memoryCandidateSelection: MemoryCandidateSelectionData;
}

function boundedFact(fact: string): string {
  const value = fact.trim();
  return value.length <= 240 ? value : value.substring(0, 240);
}

function candidateActions(input: MemoryCandidateSelectionSurfaceInput): A2uiAction[] {
  const args: MemoryCandidatesForgetActionArgs = {
    selectionId: input.selectionId,
    revision: input.revision,
    candidateKeys: []
  };
  const action: A2uiAction = {
    id: MEMORY_CANDIDATES_FORGET_ACTION_ID,
    label: '删除已选（0）',
    prompt: '',
    variant: 'primary',
    kind: 'client',
    args
  };
  return [action];
}

export function memoryCandidateSelectionSurface(
  surfaceId: string,
  input: MemoryCandidateSelectionSurfaceInput
): A2uiSurfaceState {
  const rows: A2uiLabelValueData[] = input.candidates.map(
    (candidate: MemoryCandidateSelectionItem, index: number): A2uiLabelValueData => ({
      label: '候选 ' + (index + 1).toString(),
      value: boundedFact(candidate.fact)
    })
  );
  const root: A2uiComponent = {
    id: 'root',
    component: 'SurfaceRoot',
    child: MEMORY_CANDIDATE_SELECTION_COMPONENT_ID,
    title: '选择要忘记的长期记忆',
    status: 'ready'
  };
  const card: A2uiComponent = {
    id: MEMORY_CANDIDATE_SELECTION_COMPONENT_ID,
    component: 'InfoRows',
    title: '选择要忘记的长期记忆',
    body: '请选择一条或多条记忆，再统一删除；未点击删除前不会修改长期记忆。',
    status: 'confirm_required',
    dataPath: '/rows',
    actions: candidateActions(input)
  };
  const candidates: MemoryCandidateSelectionDataCandidate[] = input.candidates.map(
    (candidate: MemoryCandidateSelectionItem): MemoryCandidateSelectionDataCandidate => ({
      candidateKey: candidate.candidateKey,
      fact: boundedFact(candidate.fact)
    })
  );
  const memoryCandidateSelection: MemoryCandidateSelectionData = {
    selectionId: input.selectionId,
    revision: input.revision,
    candidates
  };
  const model: MemoryCandidateSelectionDataModel = { rows, memoryCandidateSelection };
  return {
    surfaceId,
    rootId: 'root',
    title: '选择要忘记的长期记忆',
    intent: 'memory.forget.selection',
    status: 'ready',
    components: [root, card],
    dataModelJson: JSON.stringify(model),
    error: '',
    sequence: Date.now()
  };
}

export function memoryForgetConfirmationSurface(surfaceId: string, deletedCount: number): A2uiSurfaceState {
  const rows: A2uiLabelValueData[] = [{
    label: '删除结果', value: '已删除 ' + deletedCount.toString() + ' 条长期记忆。'
  }];
  return {
    surfaceId,
    rootId: 'root',
    title: '已忘记长期记忆',
    intent: 'memory.forget.confirmation',
    status: 'ready',
    components: [
      {
        id: 'root',
        component: 'SurfaceRoot',
        child: MEMORY_FORGET_CONFIRMATION_COMPONENT_ID,
        title: '已忘记长期记忆',
        status: 'ready'
      },
      {
        id: MEMORY_FORGET_CONFIRMATION_COMPONENT_ID,
        component: 'InfoRows',
        title: '已忘记长期记忆',
        body: '已选记录已从手机端长期记忆中删除。',
        status: 'ready',
        dataPath: '/rows',
        actions: []
      }
    ],
    dataModelJson: JSON.stringify({ rows }),
    error: '',
    sequence: Date.now()
  };
}

function actionRecord(action: A2uiAction): Record<string, MemoryCandidateActionValue> | null {
  if (action.kind !== 'client' ||
    action.args === undefined || action.args === null || typeof action.args !== 'object' ||
    Array.isArray(action.args)) {
    return null;
  }
  return action.args as Record<string, MemoryCandidateActionValue>;
}

export function memoryCandidatesForgetActionArgs(action: A2uiAction): MemoryCandidatesForgetActionArgs | null {
  if (action.id !== MEMORY_CANDIDATES_FORGET_ACTION_ID) return null;
  const values = actionRecord(action);
  if (values === null || Object.keys(values).sort().join(',') !== 'candidateKeys,revision,selectionId' ||
    typeof values.selectionId !== 'string' || values.selectionId.trim().length === 0 ||
    typeof values.revision !== 'number' || !Number.isSafeInteger(values.revision) || values.revision < 1 ||
    !Array.isArray(values.candidateKeys) || values.candidateKeys.length < 1 || values.candidateKeys.length > 5) {
    return null;
  }
  const candidateKeys: string[] = [];
  const rawCandidateKeys: Object[] = values.candidateKeys as Object[];
  for (let index = 0; index < rawCandidateKeys.length; index++) {
    const candidateKey: Object = rawCandidateKeys[index];
    if (typeof candidateKey !== 'string' || candidateKey.trim().length === 0 ||
      candidateKey.length > 128 || candidateKeys.indexOf(candidateKey) >= 0) return null;
    candidateKeys.push(candidateKey);
  }
  return { selectionId: values.selectionId, revision: values.revision, candidateKeys };
}
