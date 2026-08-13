import { describe, expect, it } from '@ohos/hypium';
import {
  A2uiJsonOutputAdapter,
  createDefaultUiCatalogRegistry,
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
  });
}
