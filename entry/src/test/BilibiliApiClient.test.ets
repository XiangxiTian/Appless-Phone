import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult } from '@loop/agent-core';
import {
  bilibiliApiSearchUrl,
  bilibiliCommentsFromReplyPayload,
  bilibiliPlayerUrl,
  bilibiliReplyUrl,
  bilibiliSearchUrl,
  bilibiliVideoResultsFromSearchHtml,
  bilibiliVideoResultsFromSearchPayload
} from '@loop/agent-core';

export default function bilibiliApiClientTest() {
  describe('bilibiliApiClient', () => {
    it('builds and parses five public hot replies without login state', 0, () => {
      const url = bilibiliReplyUrl('456');
      const comments = bilibiliCommentsFromReplyPayload('{"code":0,"message":"0","data":{"replies":[' +
        '{"rpid":1,"ctime":1780000100,"like":17,"rcount":3,"member":{"uname":"阿明",' +
        '"avatar":"https://i0.hdslb.com/avatar.jpg"},"content":{"message":"第一条 B 站评论"}}]}}');

      expect(url.indexOf('https://api.bilibili.com/x/v2/reply?')).assertEqual(0);
      expect(url.indexOf('type=1')).assertLarger(-1);
      expect(url.indexOf('oid=456')).assertLarger(-1);
      expect(url.indexOf('pn=1')).assertLarger(-1);
      expect(url.indexOf('ps=5')).assertLarger(-1);
      expect(url.indexOf('sort=2')).assertLarger(-1);
      expect(comments.length).assertEqual(1);
      expect(comments[0].text).assertEqual('第一条 B 站评论');
      expect(comments[0].authorName).assertEqual('阿明');
      expect(comments[0].authorAvatarUrl).assertEqual('https://i0.hdslb.com/avatar.jpg');
      expect(comments[0].likeCount).assertEqual(17);
      expect(comments[0].replyCount).assertEqual(3);
    });

    it('builds search and player URLs without credentials', 0, () => {
      const searchUrl: string = bilibiliSearchUrl('qwen max 官方介绍');
      const apiUrl: string = bilibiliApiSearchUrl('qwen max 官方介绍', 2);

      expect(searchUrl.indexOf('https://search.bilibili.com/video?')).assertEqual(0);
      expect(searchUrl.indexOf('keyword=qwen%20max%20%E5%AE%98%E6%96%B9%E4%BB%8B%E7%BB%8D')).assertLarger(-1);
      expect(apiUrl.indexOf('https://api.bilibili.com/x/web-interface/search/all/v2?')).assertEqual(0);
      expect(apiUrl.indexOf('page=2')).assertLarger(-1);
      expect(bilibiliPlayerUrl('BV1h57y6pE5o')).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
    });

    it('maps Bilibili API JSON into playable generic tool rows', 0, () => {
      const payload: string = '{"code":0,"message":"OK","data":{"result":[{"result_type":"video","data":[{"bvid":"BV1h57y6pE5o","title":"Qwen <em class=\\"keyword\\">Max</em> 官方介绍","description":"真实视频简介","pic":"//i1.hdslb.com/bfs/archive/cover.jpg","author":"通义实验室","upic":"//i1.hdslb.com/bfs/face/avatar.jpg","play":98659,"like":361,"favorites":178,"review":186,"video_review":148}]}]}}';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchPayload(payload, 'qwen max');
      const rows = JSON.stringify(results[0].rows);

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].summary).assertEqual('真实视频简介');
      expect(results[0].rows[1].value).assertEqual('BV1h57y6pE5o');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
      expect(rows.indexOf('"label":"Author","value":"通义实验室"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Author Avatar","value":"https://i1.hdslb.com/bfs/face/avatar.jpg"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Views","value":"98659"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Likes","value":"361"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Favorites","value":"178"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Comments","value":"186"')).assertLarger(-1);
      expect(rows.indexOf('"label":"Danmaku","value":"148"')).assertLarger(-1);
    });

    it('maps Bilibili search HTML into playable generic tool rows', 0, () => {
      const html: string = 'http:\\u002F\\u002Fwww.bilibili.com\\u002Fvideo\\u002Fav116698019534672","BV1h57y6pE5o","Qwen \\u003Cem class=\\"keyword\\"\\u003EMax\\u003C\\u002Fem\\u003E 官方介绍","desc","\\u002F\\u002Fi1.hdslb.com\\u002Fbfs\\u002Farchive\\u002Fcover.jpg",98359';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml(html, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].rows[1].label).assertEqual('BVID');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
    });

    it('maps current Bilibili pinia search payloads into playable generic tool rows', 0, () => {
      const html: string = '<script>window.__pinia=(function(a,b,c,d,e,f){return {result:[{bvid:d,title:e,pic:f},{bvid:"BV2222222222",title:b,pic:b}]}}("",0,null,"BV1h57y6pE5o","Qwen \\u003Cem class=\\"keyword\\"\\u003EMax\\u003C\\u002Fem\\u003E 官方介绍","\\u002F\\u002Fi1.hdslb.com\\u002Fbfs\\u002Farchive\\u002Fcover.jpg"))</script>';
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml(html, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('哔哩哔哩');
      expect(results[0].title).assertEqual('Qwen Max 官方介绍');
      expect(results[0].rows[1].value).assertEqual('BV1h57y6pE5o');
      expect(results[0].rows[2].value).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
      expect(results[0].rows[3].value).assertEqual('https://i1.hdslb.com/bfs/archive/cover.jpg');
    });

    it('returns empty-result rows without fake videos', 0, () => {
      const results: DynamicGenericToolResult[] = bilibiliVideoResultsFromSearchHtml('<html></html>', 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].status).assertEqual('success');
      expect(results[0].title).assertEqual('没有找到 B 站视频');
      expect(results[0].rows[0].value).assertEqual('qwen max');
    });
  });
}
