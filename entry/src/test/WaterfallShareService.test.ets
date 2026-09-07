import { describe, expect, it } from '@ohos/hypium';
import {
  parseWaterfallShareRequest,
  waterfallShareLinkFromResponse,
  waterfallShareRecord
} from '../main/ets/pages/A2uiHome/waterfall/WaterfallShareService';
import { waterfallShareUrlFromWant } from '../main/ets/entryability/EntryAbility';

export default function waterfallShareServiceTest(): void {
  describe('WaterfallShareService', (): void => {
    it('keeps only the immutable public card fields', 0, (): void => {
      const parsed = parseWaterfallShareRequest(JSON.stringify({
        title: '  一座球场  ',
        summary: ' 灯光与网络协同 ',
        source: 'GlobalNews',
        author: '现场编辑部',
        coverUrl: 'https://images.example.test/stadium.jpg',
        originalUrl: 'https://news.example.test/stadium',
        publishedAt: '2026-08-25',
        reason: '不应分享',
        searchQuery: '不应分享'
      }));

      expect(parsed === null).assertFalse();
      expect(JSON.stringify(parsed)).assertEqual(JSON.stringify({
        title: '一座球场',
        summary: '灯光与网络协同',
        source: 'GlobalNews',
        author: '现场编辑部',
        coverUrl: 'https://images.example.test/stadium.jpg',
        mediaType: '',
        mediaUrl: '',
        format: '',
        originalUrl: 'https://news.example.test/stadium',
        publishedAt: '2026-08-25'
      }));
    });

    it('uses the visible fallback title for otherwise shareable cards', 0, (): void => {
      const parsed = parseWaterfallShareRequest(JSON.stringify({
        title: '',
        source: 'YouTube',
        mediaType: 'video',
        mediaUrl: 'https://media.example.test/video.mp4',
        format: 'landscape_video',
        originalUrl: 'https://youtube.com/watch?v=abc'
      }));
      expect(parsed === null).assertFalse();
      expect(parsed?.title).assertEqual('YouTube 内容');
      expect(parsed?.mediaType).assertEqual('video');
      expect(parsed?.mediaUrl).assertEqual('https://media.example.test/video.mp4');
      expect(parsed?.format).assertEqual('landscape_video');
    });

    it('rejects a card without a public original URL', 0, (): void => {
      expect(parseWaterfallShareRequest('{"title":"卡片","originalUrl":"file:///private/card"}') === null)
        .assertTrue();
    });

    it('accepts only the canonical Appless share link from the API', 0, (): void => {
      expect(waterfallShareLinkFromResponse(
        '{"ok":true,"url":"https://jiuwenappless.com/s/AbCdEf0123_-"}'
      )).assertEqual('https://jiuwenappless.com/s/AbCdEf0123_-');
      expect(waterfallShareLinkFromResponse(
        '{"ok":true,"url":"https://lookalike.example/s/AbCdEf0123_-"}'
      )).assertEqual('');
    });

    it('routes only canonical public card links into the app', 0, (): void => {
      expect(waterfallShareUrlFromWant({
        uri: 'https://jiuwenappless.com/s/AbCdEf0123_-'
      })).assertEqual('https://jiuwenappless.com/s/AbCdEf0123_-');
      expect(waterfallShareUrlFromWant({
        uri: 'com.jiuwen.appless://share/AbCdEf0123_-'
      })).assertEqual('https://jiuwenappless.com/s/AbCdEf0123_-');
      expect(waterfallShareUrlFromWant({
        uri: 'https://lookalike.example/s/AbCdEf0123_-'
      })).assertEqual('');
    });

    it('attaches bounded thumbnail bytes without changing the shared link', 0, (): void => {
      const card = parseWaterfallShareRequest('{"title":"有封面的内容","originalUrl":"https://example.test/card"}');
      if (card === null) throw new Error('invalid test card');
      const thumbnail = new Uint8Array([255, 216, 255, 217]);
      const record = waterfallShareRecord(card, 'https://jiuwenappless.com/s/AbCdEf0123_-', thumbnail);
      expect(record.thumbnail).assertEqual(thumbnail);
      expect(record.content).assertEqual('https://jiuwenappless.com/s/AbCdEf0123_-');
      expect(waterfallShareRecord(card, '', new Uint8Array(32768)).thumbnail === undefined).assertTrue();
      expect(waterfallShareRecord(card, '', new Uint8Array(0)).thumbnail === undefined).assertTrue();
      expect(waterfallShareRecord(card, '').content).assertEqual(card.originalUrl);
    });
  });
}
