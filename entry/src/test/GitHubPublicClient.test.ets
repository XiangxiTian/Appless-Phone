import { describe, expect, it } from '@ohos/hypium';
import {
  githubDiscoveryPostsFromPayload,
  githubSearchPostsFromPayload
} from '@loop/agent-core';

export default function githubPublicClientTest(): void {
  describe('githubPublicClient', () => {
    it('maps only star-ranked public repositories for keyword search', 0, () => {
      const repositories = '{"total_count":1,"incomplete_results":false,"items":[{' +
        '"id":101,"name":"appless","full_name":"example/appless",' +
        '"html_url":"https://github.com/example/appless","description":"HarmonyOS agent app",' +
        '"stargazers_count":120,"forks_count":8,"language":"ArkTS",' +
        '"updated_at":"2026-08-24T08:00:00Z",' +
        '"owner":{"login":"example","avatar_url":"https://avatars.githubusercontent.com/u/1?v=4"}}]}';
      const posts = githubSearchPostsFromPayload(repositories, 4);

      expect(posts.length).assertEqual(1);
      expect(posts[0].source).assertEqual('github');
      expect(posts[0].provider).assertEqual('GitHub');
      expect(posts[0].title).assertEqual('example/appless');
      expect(posts[0].rows[0].value).assertEqual('Repository');
    });

    it('combines active popular repositories with detailed releases from famous repositories', 0, () => {
      const trending = '{"items":[{"id":101,"full_name":"example/appless",' +
        '"html_url":"https://github.com/example/appless","description":"HarmonyOS agent app",' +
        '"stargazers_count":120,"forks_count":8,"language":"ArkTS",' +
        '"updated_at":"2026-08-24T08:00:00Z","owner":{"login":"example","avatar_url":""}}]}';
      const codexRelease = '{"id":303,"name":"Codex 1.0","tag_name":"v1.0.0",' +
        '"body":"Highlights and a detailed list of fixes.",' +
        '"html_url":"https://github.com/openai/codex/releases/tag/v1.0.0",' +
        '"published_at":"2026-08-24T10:00:00Z",' +
        '"author":{"login":"openai","avatar_url":"https://avatars.githubusercontent.com/u/14957082?v=4"}}';
      const badRelease = '{"id":304,"name":"Bad","tag_name":"bad","body":"",' +
        '"html_url":"http://example.com/bad","published_at":"2026-08-24T11:00:00Z"}';
      const posts = githubDiscoveryPostsFromPayload(trending, [codexRelease, badRelease], 4);

      expect(posts.length).assertEqual(2);
      expect(posts[0].rows[0].value).assertEqual('Trending Repository');
      expect(posts[1].title).assertEqual('openai/codex · Codex 1.0');
      expect(posts[1].text).assertEqual('Highlights and a detailed list of fixes.');
      expect(posts[1].rows[0].value).assertEqual('Release');
    });

    it('reports all failed discovery requests instead of empty content', 0, () => {
      let message = '';
      try {
        githubDiscoveryPostsFromPayload('', ['', ''], 4);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      expect(message).assertEqual('github_all_requests_failed');
    });

    it('keeps the complete release body for details', 0, () => {
      const body = 'Detailed release note. '.repeat(100) + 'release body end';
      const release = '{"id":303,"name":"Codex 1.0","tag_name":"v1.0.0","body":"' + body + '",' +
        '"html_url":"https://github.com/openai/codex/releases/tag/v1.0.0",' +
        '"published_at":"2026-08-24T10:00:00Z"}';

      expect(githubDiscoveryPostsFromPayload('{"items":[]}', [release], 1)[0].text).assertEqual(body);
    });
  });
}
