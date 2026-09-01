import { describe, expect, it } from '@ohos/hypium';
import { steamNewsPostsFromPayload } from '@loop/agent-core';

export default function steamNewsClientTest(): void {
  describe('steamNewsClient', () => {
    it('maps official app news as Steam cards without game source labels', 0, () => {
      const payload = '{"appnews":{"appid":730,"newsitems":[{"gid":"1",' +
        '"title":"Major update available","url":"https://store.steampowered.com/news/app/730/view/1",' +
        '"is_external_url":false,"author":"Steam Team","contents":"<p>Update notes &amp; fixes.</p>",' +
        '"feedlabel":"Community Announcements","date":1787558400,' +
        '"feedname":"steam_community_announcements"}],"count":1}}';
      const posts = steamNewsPostsFromPayload(payload, 4);

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('steam');
      expect(posts[0].provider).assertEqual('Steam');
      expect(posts[0].title).assertEqual('Major update available');
      expect(posts[0].text).assertEqual('Update notes & fixes.');
      expect(posts[0].rows.length).assertEqual(0);
    });

    it('deduplicates, rejects malformed links, and honors the requested limit', 0, () => {
      const payload = '{"appnews":{"appid":570,"newsitems":[' +
        '{"gid":"1","title":"One","url":"https://store.steampowered.com/news/app/570/view/1","author":"","contents":"","date":1},' +
        '{"gid":"1","title":"Duplicate","url":"https://store.steampowered.com/news/app/570/view/2","author":"","contents":"","date":2},' +
        '{"gid":"3","title":"Unsafe","url":"http://example.com/3","author":"","contents":"","date":3},' +
        '{"gid":"4","title":"Four","url":"https://store.steampowered.com/news/app/570/view/4","author":"","contents":"","date":4},' +
        '{"gid":"5","title":"Five","url":"https://store.steampowered.com/news/app/570/view/5","author":"","contents":"","date":5}],"count":5}}';
      const posts = steamNewsPostsFromPayload(payload, 2);

      expect(posts.length).assertEqual(2);
      expect(posts[0].title).assertEqual('One');
      expect(posts[1].title).assertEqual('Four');
      expect(steamNewsPostsFromPayload('{"appnews":{"newsitems":{}}}', 4).length).assertEqual(0);
    });

    it('keeps the complete article body for details', 0, () => {
      const body = '完整更新正文。'.repeat(100) + '正文结尾';
      const payload = '{"appnews":{"newsitems":[{"gid":"full","title":"Full update",' +
        '"url":"https://store.steampowered.com/news/app/730/view/full","author":"Steam Team",' +
        '"contents":"' + body + '","date":1}]}}';

      expect(steamNewsPostsFromPayload(payload, 1)[0].text).assertEqual(body);
    });

    it('honors requested limits above the old four-post cap', 0, () => {
      const items: string[] = [];
      for (let index = 0; index < 6; index++) {
        items.push('{"gid":"' + index.toString() + '","title":"News ' + index.toString() +
          '","url":"https://store.steampowered.com/news/app/730/view/' + index.toString() +
          '","author":"","contents":"","date":' + index.toString() + '}');
      }
      const payload = '{"appnews":{"newsitems":[' + items.join(',') + ']}}';

      expect(steamNewsPostsFromPayload(payload, 6).length).assertEqual(6);
    });
  });
}
