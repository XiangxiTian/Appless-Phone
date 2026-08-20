import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult } from '@loop/agent-core';
import {
  remainingReadStructuredDataResult,
  youtubeMostPopularUrl,
  youtubeSearchUrl,
  youtubeVideoResultsFromPopularPayload,
  youtubeVideoResultsFromSearchPayload
} from '@loop/agent-core';

export default function youtubeApiClientTest() {
  describe('youTubeApiClient', () => {
    it('builds and parses the verified YouTube most-popular endpoint', 0, () => {
      const url: string = youtubeMostPopularUrl('api-key-123', 10, 'next-page');
      expect(url.indexOf('https://www.googleapis.com/youtube/v3/videos?')).assertEqual(0);
      expect(url.indexOf('part=snippet')).assertLarger(-1);
      expect(url.indexOf('chart=mostPopular')).assertLarger(-1);
      expect(url.indexOf('maxResults=10')).assertLarger(-1);
      expect(url.indexOf('pageToken=next-page')).assertLarger(-1);
      const results: DynamicGenericToolResult[] = youtubeVideoResultsFromPopularPayload(
        '{"nextPageToken":"next-2","items":[{"id":"popular-1","snippet":{' +
        '"title":"Popular AI video","description":"Real description","channelTitle":"Channel",' +
        '"publishedAt":"2026-08-12T00:00:00Z","thumbnails":{"medium":{' +
        '"url":"https://img.test/popular.jpg"}}}}]}');
      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('Popular AI video');
      expect(results[0].summary).assertEqual('Real description');
      expect(results[0].rows[3].value).assertEqual('https://www.youtube.com/watch?v=popular-1');
      expect(JSON.stringify(results[0].providerData).indexOf('next-2')).assertLarger(-1);
    });
    it('builds a search URL for public video search', 0, () => {
      const url = youtubeSearchUrl('qwen max 官方介绍', 'api-key-123');

      expect(url.indexOf('https://www.googleapis.com/youtube/v3/search?')).assertEqual(0);
      expect(url.indexOf('part=snippet')).assertLarger(-1);
      expect(url.indexOf('type=video')).assertLarger(-1);
      expect(url.indexOf('q=qwen%20max%20%E5%AE%98%E6%96%B9%E4%BB%8B%E7%BB%8D')).assertLarger(-1);
      expect(url.indexOf('key=api-key-123')).assertLarger(-1);
    });

    it('supports view-count ordering and five-result searches', 0, () => {
      const url = youtubeSearchUrl('world cup', 'api-key-123', 'viewCount', 5, 'next-page-token');

      expect(url.indexOf('order=viewCount')).assertLarger(-1);
      expect(url.indexOf('maxResults=5')).assertLarger(-1);
      expect(url.indexOf('pageToken=next-page-token')).assertLarger(-1);
      expect(url.indexOf('q=world%20cup')).assertLarger(-1);
    });

    it('adds a supported relevance language without changing legacy URLs', 0, () => {
      const chinese = youtubeSearchUrl('codex', 'api-key-123', 'relevance', 10, 'zh-CN');
      const unsupported = youtubeSearchUrl('codex', 'api-key-123', 'relevance', 10, 'auto');

      expect(chinese.indexOf('relevanceLanguage=zh-Hans')).assertLarger(-1);
      expect(unsupported.indexOf('relevanceLanguage=')).assertEqual(-1);
    });

    it('maps YouTube search payload into generic tool rows', 0, () => {
      const payload = '{"items":[{"id":{"videoId":"abc123"},"snippet":{"title":"Qwen Max official intro","channelTitle":"Qwen Channel","publishedAt":"2026-06-01T00:00:00Z","thumbnails":{"medium":{"url":"https://i.ytimg.com/vi/abc123/mqdefault.jpg"}}}}]}';
      const results = youtubeVideoResultsFromSearchPayload(payload, 'qwen max');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('YouTube Data API');
      expect(results[0].toolName).assertEqual('youtube.video.search');
      expect(results[0].title).assertEqual('Qwen Max official intro');
      expect(results[0].rows[0].label).assertEqual('Channel');
      expect(results[0].rows[3].value).assertEqual('https://www.youtube.com/watch?v=abc123');
    });

    it('keeps authenticated playlist IDs and URLs distinct from public video search', 0, () => {
      const playlist: DynamicGenericToolResult = {
        sourceTag: 'Composio YouTube',
        toolName: 'youtube.mine.playlists',
        title: 'My real playlist',
        status: 'success',
        summary: 'Authenticated account result',
        rows: [
          { label: 'Playlist ID', value: 'PL-ACCOUNT-REAL-1' },
          { label: 'URL', value: 'https://www.youtube.com/playlist?list=PL-ACCOUNT-REAL-1' }
        ],
        rawPreview: '{"playlists":[{"id":"PL-ACCOUNT-REAL-1","url":"https://www.youtube.com/playlist?list=PL-ACCOUNT-REAL-1"}]}',
        providerPhase: 'execution'
      };
      const structured = remainingReadStructuredDataResult(
        'youtube.mine.playlists', 'youtubePlaylists', [playlist]
      );
      const serialized = JSON.stringify(structured.data);

      expect(structured.status).assertEqual('success');
      expect(serialized.indexOf('PL-ACCOUNT-REAL-1')).assertLarger(-1);
      expect(serialized.indexOf('youtube.com/playlist')).assertLarger(-1);
      expect(serialized.indexOf('youtube.video.search')).assertEqual(-1);
      expect(serialized.indexOf('YouTube Data API')).assertEqual(-1);
    });

    it('separates YouTube account auth empty and attempted provider errors', 0, () => {
      const auth = remainingReadStructuredDataResult('youtube.mine.subscriptions', 'youtubeSubscriptions', [{
        sourceTag: 'Composio YouTube', toolName: 'youtube.mine.subscriptions', title: 'Composio 未配置',
        status: 'needs_auth', summary: 'Composio 未配置，无法查询已授权应用工具。', rows: [], rawPreview: ''
      }]);
      const empty = remainingReadStructuredDataResult('youtube.mine.subscriptions', 'youtubeSubscriptions', [{
        sourceTag: 'Composio YouTube', toolName: 'youtube.mine.subscriptions', title: '没有订阅',
        status: 'success', summary: '授权账号查询成功但结果为空。', rows: [{ label: '结果数量', value: '0' }],
        rawPreview: '{"subscriptions":[]}', providerPhase: 'execution'
      }]);
      const transport = remainingReadStructuredDataResult('youtube.mine.subscriptions', 'youtubeSubscriptions', [{
        sourceTag: 'Composio YouTube', toolName: 'youtube.mine.subscriptions', title: 'YouTube 调用失败',
        status: 'error', summary: 'Provider transport timeout', rows: [], rawPreview: '', providerPhase: 'execution'
      }]);

      expect(auth.error?.code).assertEqual('AUTH_REQUIRED');
      expect(auth.sources.length).assertEqual(0);
      expect(empty.status).assertEqual('empty');
      expect(empty.sources.length).assertEqual(1);
      expect(transport.error?.code).assertEqual('PROVIDER_ERROR');
      expect(transport.error?.retryable).assertTrue();
      expect(transport.sources.length).assertEqual(1);
    });
  });
}
