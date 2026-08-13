import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiJsonOutputAdapter,
  createDefaultUiCatalogRegistry,
  emptyA2uiSurface,
  LegacyA2uiSurfaceAdapter,
  UiCompileContext,
  canonicalSurfaceFingerprint
} from '@loop/agent-core';

function context(): UiCompileContext {
  return {
    surfaceId: 'compiler-surface',
    runId: 'compiler-run',
    epoch: 1,
    catalogGroups: ['foundation', 'semantic'],
    catalogRegistry: createDefaultUiCatalogRegistry(),
    title: 'Compiler test',
    intent: 'status'
  };
}

function validJson(): string {
  return JSON.stringify({
    version: 'v0.9.1',
    createSurface: {
      surfaceId: 'compiler-surface',
      root: 'root',
      title: 'Status',
      intent: 'status'
    }
  }) + '\n' + JSON.stringify({
    version: 'v0.9.1',
    updateComponents: {
      surfaceId: 'compiler-surface',
      components: [
        { id: 'root', component: 'Surface', children: ['status'] },
        { id: 'status', component: 'StatusNotice' }
      ]
    }
  });
}

export default function uiV4CompilerTest(): void {
  describe('UiV4Compiler', (): void => {
    it('compiles A2UI JSON into canonical IR', 0, (): void => {
      const result = new A2uiJsonOutputAdapter().compile(validJson(), context());
      expect(result.ok).assertTrue();
      expect(result.surface?.rootNodeKey).assertEqual('root');
      expect(result.surface?.nodes.length).assertEqual(2);
      expect(result.surface?.nodes[1].catalogRef.layer).assertEqual('semantic');
      expect(result.surface === null ? '' : canonicalSurfaceFingerprint(result.surface).length > 0)
        .assertTrue();
    });

    it('rejects unknown component, duplicate id and invalid binding', 0, (): void => {
      const raw = JSON.stringify({
        updateComponents: {
          surfaceId: 'compiler-surface',
          components: [
            { id: 'root', component: 'Surface', children: ['bad'] },
            { id: 'bad', component: 'NotInCatalog', bindings: { value: { store: 'business', path: 'bad', expectedType: 'string' } } },
            { id: 'bad', component: 'Text' },
            { id: 'bad-binding', component: 'Text', bindings: { value: { store: 'business', path: 'bad', expectedType: 'string' } } }
          ]
        }
      });
      const result = new A2uiJsonOutputAdapter().compile(raw, context());
      expect(result.ok).assertFalse();
      expect(result.errors.map((value): string => value.code)).assertContain('UNKNOWN_COMPONENT');
      expect(result.errors.map((value): string => value.code)).assertContain('DUPLICATE_COMPONENT_ID');
      expect(result.errors.map((value): string => value.code)).assertContain('INVALID_BINDING');
    });

    it('accepts only paths declared by the Presentation View Model schema', 0, (): void => {
      const raw = JSON.stringify({
        updateComponents: {
          surfaceId: 'compiler-surface',
          components: [
            { id: 'root', component: 'Surface', children: ['choices'] },
            { id: 'choices', component: 'ChoiceList', bindings: {
              items: { store: 'business', path: '/items', expectedType: 'array' }
            } }
          ]
        }
      });
      const accepted = new A2uiJsonOutputAdapter().compile(raw, context());
      expect(accepted.ok).assertTrue();
      expect(accepted.metadata?.adapterId).assertEqual('a2ui-json');
      const rejected = new A2uiJsonOutputAdapter().compile(raw.replace('/items', '/private'), context());
      expect(rejected.ok).assertFalse();
      expect(rejected.errors.map((value): string => value.code)).assertContain('INVALID_BINDING_SCHEMA');

      const rawBusiness = JSON.stringify({ updateComponents: { surfaceId: 'compiler-surface', components: [
        { id: 'root', component: 'Surface', children: ['text'] },
        { id: 'text', component: 'Text', bindings: { value: { store: 'business', path: '/rawProviderPayload', expectedType: 'string' } } }
      ] } });
      const rawBusinessResult = new A2uiJsonOutputAdapter().compile(rawBusiness, context());
      expect(rawBusinessResult.errors.map((value): string => value.code)).assertContain('INVALID_BINDING_SCHEMA');
    });

    it('produces a stable canonical fingerprint across node arrival order', 0, (): void => {
      const first = JSON.stringify({ updateComponents: { surfaceId: 'compiler-surface', components: [
        { id: 'root', component: 'Surface', children: ['b', 'a'] },
        { id: 'b', component: 'Text', text: 'B' }, { id: 'a', component: 'Text', text: 'A' }
      ] } });
      const second = JSON.stringify({ updateComponents: { surfaceId: 'compiler-surface', components: [
        { id: 'a', component: 'Text', text: 'A' }, { id: 'b', component: 'Text', text: 'B' },
        { id: 'root', component: 'Surface', children: ['b', 'a'] }
      ] } });
      const firstResult = new A2uiJsonOutputAdapter().compile(first, context());
      const secondResult = new A2uiJsonOutputAdapter().compile(second, context());
      const repeatedResult = new A2uiJsonOutputAdapter().compile(first, context());
      expect(firstResult.ok && secondResult.ok).assertTrue();
      const firstFingerprint = firstResult.surface === null ? '' : canonicalSurfaceFingerprint(firstResult.surface);
      const secondFingerprint = secondResult.surface === null ? '' : canonicalSurfaceFingerprint(secondResult.surface);
      const repeatedFingerprint = repeatedResult.surface === null ? '' : canonicalSurfaceFingerprint(repeatedResult.surface);
      expect(firstFingerprint.length > 0).assertTrue();
      expect(firstFingerprint).assertEqual(secondFingerprint);
      expect(firstFingerprint).assertEqual(repeatedFingerprint);
    });

    it('rejects cycles, orphan children and an unknown root', 0, (): void => {
      const raw = JSON.stringify({ updateComponents: { surfaceId: 'compiler-surface', components: [
        { id: 'a', component: 'Stack', children: ['b', 'missing'] },
        { id: 'b', component: 'Stack', children: ['a'] }
      ] } });
      const result = new A2uiJsonOutputAdapter().compile(raw, context());
      expect(result.ok).assertFalse();
      const codes = result.errors.map((value): string => value.code);
      expect(codes).assertContain('UNKNOWN_ROOT');
      expect(codes).assertContain('ORPHAN_CHILD');
      expect(codes).assertContain('COMPONENT_CYCLE');
    });

    it('reuses the A2UI scanner across chunk boundaries', 0, (): void => {
      const adapter = new A2uiJsonOutputAdapter();
      const input = JSON.stringify({
        version: 'v0.9.1',
        updateComponents: {
          surfaceId: 'compiler-surface',
          components: [
            { id: 'root', component: 'Surface', children: ['text'] },
            { id: 'text', component: 'Text', text: '中文' }
          ]
        }
      });
      const first = adapter.feed(input.substring(0, 40), context());
      expect(first === null || first.ok).assertTrue();
      adapter.feed(input.substring(40, input.length - 2), context());
      const final = adapter.feed(input.substring(input.length - 2), context());
      expect(final === null || final.ok).assertTrue();
      const completed = adapter.finalize(context());
      expect(completed.ok).assertTrue();
      expect(completed.surface?.nodes[1].props['text']).assertEqual('中文');
    });

    it('rejects a partial or malformed stream without producing a surface', 0, (): void => {
      const adapter = new A2uiJsonOutputAdapter();
      const result = adapter.feed('{"updateComponents":', context());
      expect(result === null).assertTrue();
      const completed = adapter.finalize(context());
      expect(completed.ok).assertFalse();
      expect(completed.surface === null).assertTrue();
    });

    it('round-trips a legacy A2UI surface through canonical IR', 0, (): void => {
      const legacy = emptyA2uiSurface('legacy-surface');
      legacy.rootId = 'root';
      legacy.title = 'Legacy';
      legacy.intent = 'status';
      legacy.sequence = 4;
      legacy.components = [
        { id: 'root', component: 'SurfaceRoot', children: ['text'] },
        { id: 'text', component: 'Text', text: 'hello', dataPath: '/message' }
      ];
      const adapter = new LegacyA2uiSurfaceAdapter();
      const canonical = adapter.toCanonical(legacy, 'legacy-run', 2);
      expect(canonical.rootNodeKey).assertEqual('root');
      expect(canonical.revision.layout).assertEqual(4);
      expect(canonical.nodes[1].bindings['data'].path).assertEqual('/message');
      const materialized = adapter.toLegacy(canonical, legacy);
      expect(materialized.components.length).assertEqual(2);
      expect(materialized.components[0].id).assertEqual('root');
      expect(materialized.components[1].dataPath).assertEqual('/message');
      expect(materialized.sequence).assertEqual(4);
    });
  });
}
