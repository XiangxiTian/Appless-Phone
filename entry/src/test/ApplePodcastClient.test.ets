import { describe, expect, it } from '@ohos/hypium';
import {
  AggregateSearchPolicy,
  AggregateSearchRowData,
  ApplePodcastHttpResult,
  ApplePodcastRssEvent,
  aggregateMediaCandidates,
  applePodcastBatchFromHttpResult,
  applePodcastEpisodeFromRss,
  applePodcastEpisodeFromRssEvents,
  applePodcastPostsFromPayload,
  applePodcastRssBodySizeAllowed,
  applePodcastResolverFailure,
  applePodcastRssErrorFromEvents,
  applePodcastRssRequestOptions,
  applePodcastsCountryForPolicy,
  applePodcastsSearchUrl,
  validApplePodcastPublicHttpsUrl
} from '@loop/agent-core';

const CHINESE_POLICY: AggregateSearchPolicy = { domesticOnly: false, multilingual: false };
const MULTILINGUAL_POLICY: AggregateSearchPolicy = { domesticOnly: false, multilingual: true };

interface ApplePodcastFixtureItem {
  collectionId: number;
  artistName: string;
  collectionName: string;
  collectionViewUrl?: string;
  feedUrl?: string;
  artworkUrl600?: string;
  primaryGenreName?: string;
  genres?: string[];
  releaseDate?: string;
  trackCount?: number;
  country?: string;
}

interface ApplePodcastFixturePayload {
  resultCount: number;
  results: ApplePodcastFixtureItem[];
}

const PODCAST_FIXTURE: ApplePodcastFixturePayload = {
  resultCount: 2,
  results: [{
    collectionId: 1531947193,
    artistName: 'Lex Fridman',
    collectionName: 'Lex Fridman Podcast',
    collectionViewUrl: 'https://podcasts.apple.com/us/podcast/id1531947193',
    feedUrl: 'https://lexfridman.com/feed/podcast/',
    artworkUrl600: 'https://example.test/lex-600.jpg',
    primaryGenreName: 'Technology',
    genres: ['Technology', 'Science'],
    releaseDate: '2026-08-12T12:00:00Z',
    trackCount: 501,
    country: 'USA'
  }, {
    collectionId: 2,
    artistName: 'Missing URL',
    collectionName: 'Dropped result'
  }]
};
const PODCAST_PAYLOAD: string = JSON.stringify(PODCAST_FIXTURE);

const EMPTY_RESPONSE: ApplePodcastHttpResult = {
  code: 200,
  text: '{"resultCount":0,"results":[]}'
};
const UNAVAILABLE_RESPONSE: ApplePodcastHttpResult = {
  code: 503,
  text: 'unavailable'
};
const MALFORMED_RESPONSE: ApplePodcastHttpResult = {
  code: 200,
  text: '{bad json'
};

function rowValue(rows: AggregateSearchRowData[], label: string): string {
  for (let index = 0; index < rows.length; index++) {
    if (rows[index].label === label) {
      return rows[index].value;
    }
  }
  return '';
}

function rssItemEvents(
  title: string,
  publishedAt: string,
  enclosureUrl: string,
  enclosureType: string,
  duration: string = ''
): ApplePodcastRssEvent[] {
  const events: ApplePodcastRssEvent[] = [
    { kind: 'start', name: 'item' },
    { kind: 'text', name: 'title', value: title },
    { kind: 'text', name: 'pubDate', value: publishedAt }
  ];
  if (duration.length > 0) events.push({ kind: 'text', name: 'itunes:duration', value: duration });
  events.push(
    { kind: 'start', name: 'enclosure' },
    { kind: 'attribute', tagName: 'enclosure', name: 'url', value: enclosureUrl },
    { kind: 'attribute', tagName: 'enclosure', name: 'type', value: enclosureType },
    { kind: 'end', name: 'enclosure' },
    { kind: 'end', name: 'item' }
  );
  return events;
}

export default function applePodcastClientTest(): void {
  describe('applePodcastClient', () => {
    it('builds an anonymous podcast search URL without treating lang as content language', 0, () => {
      const url = applePodcastsSearchUrl('AI 中文', 999, 'CN');
      expect(url).assertEqual('https://itunes.apple.com/search?term=AI%20%E4%B8%AD%E6%96%87&country=CN&media=podcast&entity=podcast&limit=50');
      expect(url.indexOf('lang=')).assertEqual(-1);
      expect(applePodcastsCountryForPolicy(CHINESE_POLICY)).assertEqual('CN');
      expect(applePodcastsCountryForPolicy(MULTILINGUAL_POLICY)).assertEqual('US');
    });

    it('maps show metadata and artwork to an aggregate image-text post', 0, () => {
      const posts = applePodcastPostsFromPayload(PODCAST_PAYLOAD, 10);
      expect(posts.length).assertEqual(1);
      expect(posts[0].id).assertEqual('applepodcasts-1531947193');
      expect(posts[0].source).assertEqual('applepodcasts');
      expect(posts[0].title).assertEqual('Lex Fridman Podcast');
      expect(posts[0].author).assertEqual('Lex Fridman');
      expect(posts[0].url).assertEqual('https://podcasts.apple.com/us/podcast/id1531947193');
      expect(posts[0].publishedAt).assertEqual('2026-08-12T12:00:00Z');
      expect(posts[0].feedUrl).assertEqual('https://lexfridman.com/feed/podcast/');
      expect(rowValue(posts[0].rows, 'Cover')).assertEqual('https://example.test/lex-600.jpg');
      expect(rowValue(posts[0].rows, 'Feed URL')).assertEqual('https://lexfridman.com/feed/podcast/');
      expect(rowValue(posts[0].rows, 'Genre')).assertEqual('Technology / Science');
      expect(rowValue(posts[0].rows, 'Episodes')).assertEqual('501');
      const candidates = aggregateMediaCandidates([], posts, 0, 'AI');
      expect(candidates.length).assertEqual(1);
      expect(candidates[0].mediaType).assertEqual('image_text');
      expect(candidates[0].coverUrl).assertEqual('https://example.test/lex-600.jpg');
      expect(candidates[0].feedUrl).assertEqual('https://lexfridman.com/feed/podcast/');
    });

    it('parses the newest valid audio enclosure from RSS without accepting unsafe URLs', 0, () => {
      expect(validApplePodcastPublicHttpsUrl('https://cdn.example.com/feed.xml')).assertTrue();
      const events = rssItemEvents('Older episode', 'Mon, 17 Aug 2026 08:00:00 GMT',
        'https://cdn.example.com/older.mp3', 'audio/mpeg')
        .concat(rssItemEvents('Newest video is ignored', 'Wed, 19 Aug 2026 08:00:00 GMT',
          'https://cdn.example.com/video.mp4', 'video/mp4'))
        .concat(rssItemEvents('Newest audio', 'Tue, 18 Aug 2026 08:00:00 GMT',
          'https://cdn.example.com/newest.mp3', 'audio/mpeg; charset=binary', '42:10'));
      const episode = applePodcastEpisodeFromRssEvents(events);
      expect(episode === null).assertFalse();
      expect(episode?.mediaUrl).assertEqual('https://cdn.example.com/newest.mp3');
      expect(episode?.audioTitle).assertEqual('Newest audio');
      expect(episode?.audioMimeType).assertEqual('audio/mpeg');
      expect(episode?.audioDuration).assertEqual('42:10');
      expect(validApplePodcastPublicHttpsUrl('http://cdn.example.com/feed.xml')).assertFalse();
      expect(validApplePodcastPublicHttpsUrl('https://user:pass@cdn.example.com/feed.xml')).assertFalse();
      expect(validApplePodcastPublicHttpsUrl('https://localhost/feed.xml')).assertFalse();
      expect(validApplePodcastPublicHttpsUrl('https://device.local/feed.xml')).assertFalse();
      expect(validApplePodcastPublicHttpsUrl('https://127.0.0.1/feed.xml')).assertFalse();
      expect(validApplePodcastPublicHttpsUrl('https://[::1]/feed.xml')).assertFalse();
      const httpOnly = rssItemEvents('HTTP only', 'Tue, 18 Aug 2026 08:00:00 GMT',
        'http://cdn.example.com/http-only.mp3', 'audio/mpeg');
      expect(applePodcastRssErrorFromEvents(httpOnly)).assertEqual('rss_audio_requires_https');
      expect(applePodcastResolverFailure(new Error('rss_audio_requires_https')).retryable).assertFalse();
      expect(applePodcastResolverFailure(new Error('rss_audio_requires_https')).message)
        .assertEqual('该节目仅提供 HTTP 音频，请在来源页收听');
    });

    it('caps RSS parsing at fifty items and enforces the ten MiB response limit', 0, () => {
      const events: ApplePodcastRssEvent[] = [];
      for (let index = 0; index < 51; index += 1) {
        rssItemEvents('Episode ' + index.toString(),
          index === 50 ? 'Tue, 18 Aug 2030 08:00:00 GMT' : 'Tue, 18 Aug 2026 08:00:00 GMT',
          'https://cdn.example.com/' + index.toString() + '.mp3', 'audio/mpeg').forEach(
          (event: ApplePodcastRssEvent): void => { events.push(event); });
      }
      const episode = applePodcastEpisodeFromRssEvents(events);
      expect(episode?.mediaUrl).assertEqual('https://cdn.example.com/0.mp3');
      const tenMiB = 10 * 1024 * 1024;
      expect(applePodcastRssBodySizeAllowed(tenMiB)).assertTrue();
      expect(applePodcastRssBodySizeAllowed(tenMiB + 1)).assertFalse();
      expect(applePodcastRssRequestOptions().maxLimit).assertEqual(tenMiB);
      expect(applePodcastEpisodeFromRss('<rss>' + 'x'.repeat(tenMiB) + '</rss>') === null).assertTrue();
      expect(applePodcastResolverFailure(new Error('rss_body_too_large')).message)
        .assertEqual('RSS 超过 10MB，资源解析失败，请在来源页收听');
      expect(applePodcastResolverFailure(new Error('rss_audio_enclosure_not_found')).retryable).assertFalse();
      expect(applePodcastResolverFailure(new Error('rss_audio_enclosure_not_found')).message)
        .assertEqual('该节目未提供可播放音频，请在来源页收听');
      expect(applePodcastResolverFailure(new Error('timeout')).retryable).assertTrue();
      expect(applePodcastResolverFailure(new Error('timeout')).message).assertEqual('播客音频加载失败，可重试');
      expect(applePodcastResolverFailure(new Error('rss_network_failure')).retryable).assertTrue();
      expect(applePodcastResolverFailure(new Error('rss_network_failure')).message)
        .assertEqual('RSS 网络连接失败，可重试');
    });

    it('turns empty, HTTP, and malformed responses into terminal source statuses', 0, () => {
      const empty = applePodcastBatchFromHttpResult(EMPTY_RESPONSE, 10);
      const unavailable = applePodcastBatchFromHttpResult(UNAVAILABLE_RESPONSE, 10);
      const malformed = applePodcastBatchFromHttpResult(MALFORMED_RESPONSE, 10);
      expect(empty.status.status).assertEqual('empty');
      expect(empty.continuation === null).assertTrue();
      expect(unavailable.status.status).assertEqual('error');
      expect(unavailable.status.message.indexOf('503') >= 0).assertTrue();
      expect(malformed.status.status).assertEqual('error');
      expect(malformed.status.message.indexOf('解析失败') >= 0).assertTrue();
    });
  });
}
