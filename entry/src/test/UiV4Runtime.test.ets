import { describe, expect, it } from '@ohos/hypium';
import {
  UiCanonicalNode,
  UiCanonicalSurface,
  UiReconciler,
  UiSurfaceController,
  UiUserMutationPayload,
  UiLayoutStore,
  UiDataModelStore,
  UiRuntimeOverlayStore,
  UiUserOverlayStore,
  initialUiRevision
} from '@loop/agent-core';

function surface(
  surfaceId: string,
  nodes: UiCanonicalNode[],
  layoutRevision: number = 1,
  userRevision: number = 0
): UiCanonicalSurface {
  return {
    schemaVersion: 1,
    surfaceId,
    runId: 'run-' + surfaceId,
    epoch: 1,
    rootNodeKey: 'root',
    title: 'Test surface',
    intent: 'test',
    catalogVersion: 'ui-catalog-v1',
    nodes,
    revision: {
      epoch: 1,
      layout: layoutRevision,
      data: 0,
      runtime: 0,
      user: userRevision
    }
  };
}

function node(nodeKey: string, text: string): UiCanonicalNode {
  return {
    nodeKey,
    component: 'Text',
    catalogRef: { name: 'Text', version: 1, layer: 'foundation' },
    props: { text },
    bindings: {},
    actionRefs: [],
    children: []
  };
}

export default function uiV4RuntimeTest(): void {
  describe('UiV4Runtime', (): void => {
    it('keeps layout independent from overlay state', 0, (): void => {
      const store = new UiLayoutStore();
      const original = surface('s-1', [node('root', 'hello')]);
      store.set(original);
      const fingerprint = store.fingerprint('s-1');
      const copy = store.get('s-1');
      expect(copy !== null).assertTrue();
      (copy as UiCanonicalSurface).nodes[0].props = { text: 'changed' };
      expect(store.fingerprint('s-1')).assertEqual(fingerprint);
    });

    it('updates data paths without changing layout', 0, (): void => {
      const data = new UiDataModelStore();
      data.setRoot('s-2', { result: { count: 1 } }, 1, 'ui.option-collection', 1);
      expect(data.setPath('s-2', '/result/count', 2, 2)).assertTrue();
      expect(data.resolve('s-2', '/result/count')).assertEqual(2);
      expect(data.setPath('s-2', '/missing/count', 3, 3)).assertFalse();
      expect(data.get('s-2')?.revision).assertEqual(2);
      expect(data.get('s-2')?.viewModelType).assertEqual('ui.option-collection');
    });

    it('keeps runtime and user overlays separate', 0, (): void => {
      const runtime = new UiRuntimeOverlayStore();
      runtime.setPhase('s-3', 'card-1', 'predicted', 1);
      runtime.setPhase('s-3', 'card-1', 'hydrated', 2);
      runtime.setProvenance('s-3', 'card-1', 'cloud', 2);
      expect(runtime.get('s-3')?.nodePhases['card-1']).assertEqual('hydrated');
      expect(runtime.get('s-3')?.provenance['card-1']).assertEqual('cloud');

      const user = new UiUserOverlayStore();
      user.setPinned('s-3', 'card-1', true, 1);
      user.setHidden('s-3', 'card-2', true, 2);
      user.move('s-3', 'card-1', undefined, 3);
      user.retainOrphans('s-3', ['card-1'], 4);
      expect(user.get('s-3')?.pinnedNodeKeys.length).assertEqual(1);
      expect(user.get('s-3')?.hiddenNodeKeys.length).assertEqual(1);
      expect(user.get('s-3')?.orphanedNodeKeys).assertContain('card-2');
    });

    it('coordinates four stores and preserves canonical layout', 0, (): void => {
      const controller = new UiSurfaceController();
      const candidate = surface('s-4', [node('root', 'hello'), node('card-1', 'card')]);
      controller.commitLayout(candidate);
      const fingerprint = controller.layoutStore.fingerprint('s-4');
      controller.setDataModel('s-4', { items: [] }, 1, 'ui.option-collection', 1);
      expect(controller.setDataPath('s-4', '/items', [{ id: 'x' }], 2)).assertTrue();
      controller.setRuntimePhase('s-4', 'card-1', 'confirmed', 1);
      const mutation: UiUserMutationPayload = { nodeKey: 'card-1', operation: 'pin' };
      controller.applyUserMutation('s-4', mutation, 1);
      controller.applyUserMutation('s-4', { nodeKey: 'card-1', operation: 'move' }, 2);
      controller.applyUserMutation('s-4', { nodeKey: 'root', operation: 'hide' }, 3);
      const snapshot = controller.snapshot('s-4');
      expect(snapshot.layout !== null).assertTrue();
      expect(snapshot.runtime?.nodePhases['card-1']).assertEqual('confirmed');
      expect(snapshot.user?.pinnedNodeKeys).assertContain('card-1');
      expect(snapshot.user?.hiddenNodeKeys).assertContain('root');
      expect(controller.layoutStore.fingerprint('s-4')).assertEqual(fingerprint);
      expect(snapshot.data?.revision).assertEqual(2);
    });

    it('classifies speculative nodes against authoritative nodes', 0, (): void => {
      const reconciler = new UiReconciler();
      const speculative = surface('s-5', [node('root', 'same'), node('replace', 'old'), node('remove', 'gone')]);
      const authoritative = surface('s-5', [node('root', 'same'), node('replace', 'new'), node('insert', 'new')], 2);
      const result = reconciler.reconcile(speculative, authoritative);
      expect(result.confirmedNodeKeys).assertContain('root');
      expect(result.replacedNodeKeys).assertContain('replace');
      expect(result.insertedNodeKeys).assertContain('insert');
      expect(result.removedNodeKeys).assertContain('remove');
      expect(result.surface.nodes.length).assertEqual(3);
      expect(result.surface.revision.layout).assertEqual(2);

      const controller = new UiSurfaceController();
      controller.commitLayout(speculative);
      controller.applyUserMutation('s-5', { nodeKey: 'replace', operation: 'pin' }, 1);
      controller.commitLayout(result.surface);
      expect(controller.snapshot('s-5').user?.pinnedNodeKeys).assertContain('replace');
    });

    it('initializes a stable revision vector for future gates', 0, (): void => {
      const revision = initialUiRevision(7);
      expect(revision.epoch).assertEqual(7);
      expect(revision.layout).assertEqual(0);
      expect(revision.data).assertEqual(0);
      expect(revision.runtime).assertEqual(0);
      expect(revision.user).assertEqual(0);
    });
  });
}
