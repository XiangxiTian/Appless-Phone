import { describe, expect, it } from '@ohos/hypium';
import {
  PublicFeedEvent,
  publicFeedEventCallbackCount,
  publicFeedPostsFromEvents,
} from '@loop/agent-core';

function event(kind: 'start' | 'end' | 'text' | 'attribute', name: string, value: string = '', tagName: string = ''): PublicFeedEvent {
  return { kind: kind, name: name, value: value, tagName: tagName };
}

export default function publicFeedClientTest(): void {
  describe('publicFeedClient', () => {
    it('keeps a valid CNNews item when its RSS summary is shorter than 100 characters', 0, () => {
      const shortPosts = publicFeedPostsFromEvents('cnnews', 'IT 之家', [
        event('start', 'item'), event('text', 'title', '短正文'),
        event('text', 'link', 'https://www.ithome.com/short.htm'),
        event('text', 'description', '<p>' + '短'.repeat(99) + '</p>'), event('end', 'item')
      ], 4);

      expect(shortPosts.length).assertEqual(1);
      expect(shortPosts[0].text.length).assertEqual(99);
    });

    it('maps RSS fields into a bounded source post', 0, () => {
      const posts = publicFeedPostsFromEvents('cnnews', 'IT 之家', [
        event('start', 'item'),
        event('text', 'title', 'AI &amp; 鸿蒙'),
        event('text', 'link', 'https://www.ithome.com/0/1.htm'),
        event('text', 'description', '<p>摘要</p>'),
        event('text', 'pubDate', 'Mon, 24 Aug 2026 10:00:00 +0800'),
        event('text', 'author', 'IT 之家编辑'),
        event('end', 'item')
      ], 4);

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('AI & 鸿蒙');
      expect(posts[0].text).assertEqual('摘要');
      expect(posts[0].url).assertEqual('https://www.ithome.com/0/1.htm');
      expect(posts[0].publishedAt).assertEqual('Mon, 24 Aug 2026 10:00:00 +0800');
      expect(posts[0].author).assertEqual('IT 之家编辑');
      expect(posts[0].source).assertEqual('cnnews');
      expect(posts[0].provider).assertEqual('IT 之家');
    });

    it('maps unnamed XmlPullParser text events using the current element', 0, () => {
      const posts = publicFeedPostsFromEvents('cnnews', 'IT 之家', [
        event('start', 'item'),
        event('start', 'title'),
        event('text', '', 'HarmonyOS RSS'),
        event('end', 'title'),
        event('start', 'link'),
        event('text', '', 'https://www.ithome.com/0/1.htm'),
        event('end', 'link'),
        event('end', 'item')
      ], 4);

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('HarmonyOS RSS');
      expect(posts[0].url).assertEqual('https://www.ithome.com/0/1.htm');
    });

    it('maps Atom href links and rejects duplicate or non-HTTPS entries', 0, () => {
      const posts = publicFeedPostsFromEvents('cnnews', '爱范儿', [
        event('start', 'entry'),
        event('text', 'title', '第一条'),
        event('start', 'link'),
        event('attribute', 'href', 'https://www.ifanr.com/1', 'link'),
        event('end', 'link'),
        event('text', 'summary', '<div>Atom 摘要</div>'),
        event('text', 'published', '2026-08-24T10:00:00+08:00'),
        event('end', 'entry'),
        event('start', 'entry'),
        event('text', 'title', '重复链接'),
        event('start', 'link'),
        event('attribute', 'href', 'https://www.ifanr.com/1', 'link'),
        event('end', 'link'),
        event('end', 'entry'),
        event('start', 'entry'),
        event('text', 'title', 'HTTP 链接'),
        event('start', 'link'),
        event('attribute', 'href', 'http://www.ifanr.com/2', 'link'),
        event('end', 'link'),
        event('end', 'entry')
      ], 4);

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('第一条');
      expect(posts[0].text).assertEqual('Atom 摘要');
      expect(posts[0].url).assertEqual('https://www.ifanr.com/1');
    });

    it('uses feed article content instead of a view-full-text placeholder', 0, () => {
      const body = '这是订阅源提供的正文内容。'.repeat(120);
      const posts = publicFeedPostsFromEvents('cnnews', '爱范儿', [
        event('start', 'item'),
        event('text', 'title', '正文测试'),
        event('text', 'link', 'https://www.ifanr.com/1'),
        event('text', 'description', '&gt;查看全文'),
        event('text', 'content:encoded', '<p>' + body + '</p>'),
        event('end', 'item')
      ], 1);

      expect(posts.length).assertEqual(1);
      expect(posts[0].text.length).assertLarger(1000);
      expect(posts[0].text.indexOf('这是订阅源提供的正文内容')).assertEqual(0);
      expect(posts[0].text.indexOf('查看全文')).assertEqual(-1);
    });

    it('keeps a useful description when feed content is only markup', 0, () => {
      const posts = publicFeedPostsFromEvents('cnnews', '爱范儿', [
        event('start', 'item'),
        event('text', 'title', '图片新闻'),
        event('text', 'link', 'https://www.ifanr.com/2'),
        event('text', 'description', '这是一段可读的新闻摘要。'),
        event('text', 'content:encoded', '<figure><img src="https://img.example/' + 'x'.repeat(200) + '"></figure>'),
        event('end', 'item')
      ], 1);

      expect(posts.length).assertEqual(1);
      expect(posts[0].text).assertEqual('这是一段可读的新闻摘要。');
    });

    it('keeps complete summaries and honors limits above the old four-post cap', 0, () => {
      const events: PublicFeedEvent[] = [];
      const summary = '摘要'.repeat(4000) + '正文结尾';
      for (let index = 0; index < 5; index += 1) {
        events.push(
          event('start', 'item'),
          event('text', 'title', '新闻 ' + index.toString()),
          event('text', 'link', 'https://www.chinanews.com.cn/' + index.toString()),
          event('text', 'description', '<p>' + summary + '</p>'),
          event('end', 'item')
        );
      }
      const posts = publicFeedPostsFromEvents('cnnews', '中国新闻网', events, 5);

      expect(posts.length).assertEqual(5);
      expect(posts[0].text).assertEqual(summary);
      expect(posts[4].title).assertEqual('新闻 4');
    });

    it('stops feed event collection after the eightieth completed item', 0, () => {
      const events: PublicFeedEvent[] = [event('start', 'rss'), event('start', 'channel')];
      for (let index = 0; index < 80; index += 1) {
        events.push(
          event('start', 'item'),
          event('start', 'title'),
          event('text', 'title', '新闻 ' + index.toString()),
          event('end', 'title'),
          event('start', 'link'),
          event('text', 'link', 'https://www.ithome.com/' + index.toString()),
          event('end', 'link'),
          event('end', 'item')
        );
      }
      events.push(event('start', 'item'));

      expect(publicFeedEventCallbackCount(events)).assertEqual(642);
    });

    it('filters the recent feed by keyword before applying the four-post cap', 0, () => {
      const events: PublicFeedEvent[] = [];
      for (let index = 0; index < 5; index += 1) {
        events.push(
          event('start', 'item'),
          event('text', 'title', index === 4 ? 'OpenAI Codex 发布更新' : '普通新闻 ' + index.toString()),
          event('text', 'link', 'https://www.ithome.com/' + index.toString()),
          event('text', 'description', index === 4 ? '面向开发者的 Codex 工具' : '无关内容'),
          event('end', 'item')
        );
      }

      const posts = publicFeedPostsFromEvents('cnnews', 'IT 之家', events, 4, 'OpenAI Codex');

      expect(posts.length).assertEqual(1);
      expect(posts[0].title).assertEqual('OpenAI Codex 发布更新');
    });
  });
}
