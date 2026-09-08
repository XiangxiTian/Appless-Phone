import { describe, it, expect } from '@ohos/hypium';
import { parseAboutYouAction, ABOUT_YOU_BOOTSTRAP_URL, ABOUT_YOU_DOCUMENT_URL,
  aboutYouAllowsNavigation } from '../main/ets/pages/A2uiHome/components/AboutYouPageModel';
import { buildAboutYouUpdate, renderAboutYouDocument, buildAboutYouDocumentUrl } from '../main/ets/pages/A2uiHome/html/AboutYouRenderer';

export default function aboutYouPageTests(): void {
  describe('AboutYouPage', (): void => {
    it('allows_only_the_owned_bootstrap_and_document_navigation', 0, (): void => {
      expect(ABOUT_YOU_BOOTSTRAP_URL.indexOf('data:text/html;') === 0).assertTrue();
      const ownedDocument = buildAboutYouDocumentUrl('test-token');
      expect(aboutYouAllowsNavigation(ownedDocument, ownedDocument)).assertTrue();
      expect(aboutYouAllowsNavigation(ABOUT_YOU_BOOTSTRAP_URL, ownedDocument)).assertFalse();
      expect(aboutYouAllowsNavigation(ABOUT_YOU_DOCUMENT_URL, ownedDocument)).assertFalse();
      expect(aboutYouAllowsNavigation('data:text/html,<script>evil()</script>')).assertFalse();
      expect(aboutYouAllowsNavigation('https://about-you.aiphone.local.evil/')).assertFalse();
      expect(aboutYouAllowsNavigation('https://example.com/')).assertFalse();
    });
    it('rejects_untrusted_tokens_and_unrecognized_actions', 0, (): void => {
      expect(parseAboutYouAction('{"type":"social_discard","token":"other"}', 'local') === null).assertTrue();
      expect(parseAboutYouAction('{"type":"open_url","token":"local"}', 'local') === null).assertTrue();
      expect(parseAboutYouAction('null', 'local') === null).assertTrue();
      expect(parseAboutYouAction('{broken', 'local') === null).assertTrue();
    });
    it('requires_a_revision_and_an_integer_claim_index_for_corrections', 0, (): void => {
      expect(parseAboutYouAction('{"type":"correct","token":"local","text":"修改","claimIndex":0}', 'local') === null).assertTrue();
      expect(parseAboutYouAction('{"type":"correct","token":"local","text":"修改","claimIndex":0.5,"overviewRevision":1}', 'local') === null).assertTrue();
      const action = parseAboutYouAction('{"type":"correct","token":"local","text":" 修改 ","claimIndex":2,"overviewRevision":5}', 'local');
      expect(action !== null).assertTrue();
      if (action !== null) {
        expect(action.claimIndex).assertEqual(2);
        expect(action.overviewRevision).assertEqual(5);
        expect(action.text).assertEqual('修改');
      }
    });
    it('validates_candidate_ids_and_search_modes_before_host_dispatch', 0, (): void => {
      expect(parseAboutYouAction('{"type":"social_search","token":"local","username":"name","mode":"other"}', 'local') === null).assertTrue();
      expect(parseAboutYouAction('{"type":"social_confirm","token":"local","candidateIds":[42],"displayName":"name"}', 'local') === null).assertTrue();
      const action = parseAboutYouAction('{"type":"social_confirm","token":"local","candidateIds":["a","a","b"],"displayName":"name"}', 'local');
      expect(action !== null).assertTrue();
      if (action !== null && action.candidateIds !== undefined) expect(action.candidateIds.length).assertEqual(2);
    });
    it('retains_empty_edits_but_rejects_empty_imports', 0, (): void => {
      expect(parseAboutYouAction('{"type":"social_edit","token":"local","markdown":""}', 'local') !== null).assertTrue();
      expect(parseAboutYouAction('{"type":"social_import","token":"local","markdown":"  "}', 'local') === null).assertTrue();
    });
    it('serializes_payload_as_data_and_escapes_document_token', 0, (): void => {
      const payload = '{"summary":"</script><script>evil()</script>"}';
      expect(buildAboutYouUpdate(payload, 24, 12).indexOf(JSON.stringify(payload)) >= 0).assertTrue();
      const html = renderAboutYouDocument('</script><script>evil()</script>');
      expect(html.indexOf('</script><script>evil()') < 0).assertTrue();
      expect(html.indexOf("connect-src 'none'") >= 0).assertTrue();
      expect(html.indexOf('https://cdn.') < 0).assertTrue();
    });
  });
}
