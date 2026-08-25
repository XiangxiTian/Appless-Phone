import { describe, expect, it } from '@ohos/hypium';
import {
  guardianPostsFromPayload,
  mergeGlobalNewsPosts,
  newsApiPostsFromPayload
} from '@loop/agent-core';

export default function globalNewsClientTest(): void {
  describe('globalNewsClient', () => {
    it('keeps the real publisher under one GlobalNews source', 0, () => {
      const guardianRaw = '{"response":{"status":"ok","userTier":"developer","total":1,' +
        '"startIndex":1,"pageSize":10,"currentPage":1,"pages":1,"orderBy":"newest","results":[{' +
        '"id":"technology/2026/aug/24/appless","type":"article","sectionId":"technology",' +
        '"sectionName":"Technology","webPublicationDate":"2026-08-24T08:00:00Z",' +
        '"webTitle":"Guardian technology report","webUrl":"https://www.theguardian.com/technology/2026/aug/24/appless",' +
        '"apiUrl":"https://content.guardianapis.com/technology/2026/aug/24/appless",' +
        '"fields":{"trailText":"<p>Guardian summary.</p>","byline":"Reporter",' +
        '"thumbnail":"https://media.guim.co.uk/example.jpg"}}]}}';
      const newsApiRaw = '{"status":"ok","totalResults":1,"articles":[{' +
        '"source":{"id":"reuters","name":"Reuters"},"author":"Reuters",' +
        '"title":"Global market update","description":"Market summary.",' +
        '"url":"https://www.reuters.com/world/market-update/","urlToImage":"https://www.reuters.com/image.jpg",' +
        '"publishedAt":"2026-08-24T09:00:00Z","content":"Market summary content."}]}';

      const posts = mergeGlobalNewsPosts(
        guardianPostsFromPayload(guardianRaw, 4), newsApiPostsFromPayload(newsApiRaw, 4), 4);

      expect(posts.length).assertEqual(2);
      expect(posts[0].source).assertEqual('globalnews');
      expect(posts[0].provider).assertEqual('The Guardian');
      expect(posts[1].provider).assertEqual('Reuters');
      expect(posts[1].title).assertEqual('Global market update');
    });

    it('deduplicates canonical URLs and rejects malformed or unsafe records', 0, () => {
      const guardian = guardianPostsFromPayload('{"response":{"status":"ok","results":[{' +
        '"id":"one","webTitle":"One","webUrl":"https://example.com/one#top",' +
        '"webPublicationDate":"2026-08-24T08:00:00Z","fields":{"trailText":"Summary"}}]}}', 4);
      const newsApi = newsApiPostsFromPayload('{"status":"ok","articles":[{' +
        '"source":{"id":"example","name":"Example News"},"title":"Duplicate",' +
        '"description":"Duplicate","url":"https://example.com/one","publishedAt":"2026-08-24T09:00:00Z"},' +
        '{"source":{"id":"bad","name":"Bad"},"title":"Unsafe","description":"",' +
        '"url":"http://example.com/bad","publishedAt":"2026-08-24T10:00:00Z"}]}', 4);

      expect(mergeGlobalNewsPosts(guardian, newsApi, 4).length).assertEqual(1);
      expect(newsApiPostsFromPayload('{"status":"ok","articles":{}}', 4).length).assertEqual(0);
      expect(guardianPostsFromPayload('{"response":{"status":"ok","results":[]}}', 4).length).assertEqual(0);
    });

    it('uses Guardian body text instead of the short trail text', 0, () => {
      const body = '完整正文段落。'.repeat(1000) + '正文结尾';
      const raw = '{"response":{"status":"ok","results":[{' +
        '"id":"world/2026/aug/25/live","webTitle":"Live report",' +
        '"webUrl":"https://www.theguardian.com/world/2026/aug/25/live",' +
        '"fields":{"trailText":"Follow live","bodyText":"' + body + '"}}]}}';

      const posts = guardianPostsFromPayload(raw, 1);

      expect(posts.length).assertEqual(1);
      expect(posts[0].text).assertEqual(body);
      expect(posts[0].text.indexOf('Follow live')).assertEqual(-1);
    });
  });
}
