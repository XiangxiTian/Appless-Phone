import { describe, it, expect } from '@ohos/hypium';
import {
  ActionOffer,
  A2uiSurfaceStore,
  mergeA2uiLayoutWithStatus,
  parseA2uiEnvelope,
  parseA2uiJsonl,
  UI_AGENT_LAB_COMPONENT_CATALOG_JSON
} from '@loop/agent-core';

interface StoreActionArgs {
  source: string;
}

export default function a2uiSurfaceStoreTest() {
  describe('a2uiSurfaceStore', () => {
    it('keeps parsed catalog presentation fields through upsert and snapshot clones', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"lab-store","root":"metrics","title":"Bindings"}}'
      ));
      store.apply(parseA2uiEnvelope(
        '{"updateComponents":{"surfaceId":"lab-store","components":[' +
        '{"id":"metrics","component":"MetricGrid","items":[' +
        '{"label":"Stars","value":{"path":"/dashboard/stars"}}]}]}}',
        'ui-lab'
      ));

      const first = store.getSurface();
      const firstJson = first.components[0].catalogFieldsJson as string;
      first.components[0].catalogFieldsJson = '';
      const second = store.getSurface();
      const fields = JSON.parse(second.components[0].catalogFieldsJson as string) as Record<string, Object>;
      const items = fields['items'] as Object[];
      const value = (items[0] as Record<string, Object>)['value'] as Record<string, string>;
      expect(firstJson.length).assertLarger(0);
      expect(value['path']).assertEqual('/dashboard/stars');
    });

    it('keeps direct bindings when a valid wire offer becomes a normalized runtime action', 0, () => {
      const baseline =
        '{"createSurface":{"surfaceId":"lab-action","root":"root","title":"Bindings"}}\n' +
        '{"updateComponents":{"surfaceId":"lab-action","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"card"},' +
        '{"id":"card","component":"ExpandableCard","title":"Card","dataPath":"/card"}]}}\n' +
        '{"updateDataModel":{"surfaceId":"lab-action","path":"/card","value":{}}}\n' +
        '{"updateDataModel":{"surfaceId":"lab-action","path":"/card/title","value":"Bound card"}}\n';
      const candidate =
        '{"version":"v0.9.1","updateComponents":{"surfaceId":"lab-action","components":[' +
        '{"id":"root","component":"SurfaceRoot","child":"content"},' +
        '{"id":"content","component":"Column","children":["hero","card"]},' +
        '{"id":"hero","component":"HeroBanner","title":{"path":"/card/title"}},' +
        '{"id":"card","component":"ExpandableCard","title":{"path":"/card/title"},' +
        '"dataPath":"/card","actions":[{"offerId":"open:1"}]}]}}';
      const args: StoreActionArgs = { source: 'test' };
      const offer: ActionOffer = {
        offerId: 'open:1', actionId: 'card.open', label: 'Open', variant: 'primary', args: args
      };
      const merged = mergeA2uiLayoutWithStatus(
        baseline, candidate, 'lab-action', [offer], UI_AGENT_LAB_COMPONENT_CATALOG_JSON
      );
      const parsed = parseA2uiJsonl(merged.jsonl, 'ui-lab');
      const store = new A2uiSurfaceStore();
      parsed.envelopes.forEach(envelope => store.apply(envelope));
      const components = store.getSurface().components;
      let card = components[0];
      for (let index = 0; index < components.length; index++) {
        if (components[index].id === 'card') card = components[index];
      }
      const fields = JSON.parse(card.catalogFieldsJson as string) as Record<string, Object>;
      expect(merged.accepted).assertTrue();
      expect(parsed.error).assertEqual('');
      expect((fields['title'] as Record<string, string>)['path']).assertEqual('/card/title');
      expect(card.actions?.[0].id).assertEqual('card.open');
      expect(card.actions?.[0].label).assertEqual('Open');
    });

    it('keeps action sourceSectionId through strict parsing and store snapshots', 0, () => {
      const store = new A2uiSurfaceStore();
      store.apply(parseA2uiEnvelope(
        '{"createSurface":{"surfaceId":"lab-action-source","root":"actions","title":"Actions"}}'
      ));
      store.apply(parseA2uiEnvelope(
        '{"updateComponents":{"surfaceId":"lab-action-source","components":[' +
        '{"id":"actions","component":"ActionBar","actions":[' +
        '{"id":"github.open","label":"Open GitHub","prompt":"Open GitHub","variant":"primary",' +
        '"kind":"prompt","sourceSectionId":"tool.github"}]}]}}',
        'ui-lab'
      ));

      const first = store.getSurface();
      first.components[0].actions?.splice(0, 1);
      const second = store.getSurface();
      expect(second.components[0].actions?.[0].sourceSectionId).assertEqual('tool.github');
    });
  });
}
