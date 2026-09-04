import { describe, expect, it } from '@ohos/hypium';
import {
  WaterfallCandidate,
  WaterfallPreferenceSnapshot,
  WaterfallSourcePoolContainer,
  WaterfallSourcePoolEntry
} from '@loop/agent-core';

function poolCandidate(id: string, source: string = 'youtube', title: string = ''): WaterfallCandidate {
  return {
    id,
    source,
    provider: 'test',
    mediaType: 'video',
    title: title.length > 0 ? title : id,
    summary: '人工智能视频',
    url: 'https://example.com/' + id,
    coverUrl: '',
    publishedAt: '',
    originalIndex: 0
  };
}

function emptyProfile(): WaterfallPreferenceSnapshot {
  return {
    topicWeights: [],
    sourceWeights: [],
    formatWeights: [],
    explicitRules: []
  };
}

export default function waterfallSourcePoolContainerTest() {
  describe('WaterfallSourcePoolContainer', () => {
    it('stores only its own source and records insertion metadata', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube', 2);
      const result = container.put([
        poolCandidate('one', 'youtube', '大模型进展'),
        poolCandidate('foreign', 'bilibili')
      ], { keyword: '人工智能', insertedAt: 1234 });
      const entries = container.entries();

      expect(result.inserted).assertEqual(1);
      expect(result.rejected).assertEqual(1);
      expect(entries.length).assertEqual(1);
      expect(entries[0].insertedAt).assertEqual(1234);
      expect(entries[0].searchKeywords.join(',')).assertEqual('人工智能');
      expect((entries[0].candidate.searchKeywords ?? []).join(',')).assertEqual('人工智能');
      expect(entries[0].keywords.indexOf('人工智能') >= 0).assertTrue();
      expect(entries[0].candidate.title).assertEqual('大模型进展');
    });

    it('updates duplicates without changing FIFO age', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube', 2);
      container.putOne(poolCandidate('one'), { keyword: '旧关键词', insertedAt: 100 });
      const result = container.putOne(
        poolCandidate('one', 'youtube', '更新后的标题'),
        { keyword: '新关键词', insertedAt: 999 }
      );
      const entry = container.entries()[0];

      expect(result.updated).assertEqual(1);
      expect(container.size).assertEqual(1);
      expect(entry.insertedAt).assertEqual(100);
      expect(entry.candidate.title).assertEqual('更新后的标题');
      expect(entry.searchKeywords.join(',')).assertEqual('旧关键词,新关键词');
      expect((entry.candidate.searchKeywords ?? []).join(',')).assertEqual('旧关键词,新关键词');
      expect(entry.keywords.indexOf('旧关键词') >= 0).assertTrue();
      expect(entry.keywords.indexOf('新关键词') >= 0).assertTrue();
    });

    it('evicts the oldest entry when capacity is exceeded', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube', 2);
      container.putOne(poolCandidate('one'), { insertedAt: 100 });
      container.putOne(poolCandidate('two'), { insertedAt: 200 });
      const result = container.putOne(poolCandidate('three'), { insertedAt: 300 });
      const entries = container.entries();

      expect(result.evicted.length).assertEqual(1);
      expect(result.evicted[0].candidate.id).assertEqual('one');
      expect(entries[0].candidate.id).assertEqual('two');
      expect(entries[1].candidate.id).assertEqual('three');
    });

    it('expands capacity without moving or evicting existing entries', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube', 2);
      container.putOne(poolCandidate('one'), { insertedAt: 100 });
      container.putOne(poolCandidate('two'), { insertedAt: 200 });

      expect(container.expandCapacity(4)).assertTrue();
      expect(container.capacity).assertEqual(4);
      expect(container.entries().map((entry: WaterfallSourcePoolEntry): string =>
        entry.candidate.id).join(',')).assertEqual('one,two');
      container.putOne(poolCandidate('three'), { insertedAt: 300 });
      container.putOne(poolCandidate('four'), { insertedAt: 400 });
      expect(container.size).assertEqual(4);
      expect(container.expandCapacity(3)).assertFalse();
      expect(container.capacity).assertEqual(4);
    });

    it('selects the strongest title match even when a newer item does not match', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(poolCandidate('ai', 'youtube', '人工智能模型进展'), { insertedAt: 100 });
      container.putOne(poolCandidate('sports', 'youtube', '足球比赛集锦'), { insertedAt: 200 });
      const profile = emptyProfile();
      profile.topicWeights = [{ key: '人工智能', weight: 3, updatedAt: 100 }];

      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('ai');
      expect(container.size).assertEqual(1);
      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('sports');
      expect(container.size).assertEqual(0);
    });

    it('takes the requested profile recall before unrelated cached content', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(poolCandidate('generic', 'youtube', '普通缓存内容'), { insertedAt: 200 });
      const football = poolCandidate('football', 'youtube', '英超赛后分析');
      football.recallRoute = 'profile';
      football.searchQuery = '足球';
      container.putOne(football, { insertedAt: 100 });

      expect(container.takeForProfile(emptyProfile(), '足球')?.candidate.id).assertEqual('football');
      expect(container.size).assertEqual(1);
    });

    it('matches a preferred recall retained in merged search provenance', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      const football = poolCandidate('shared', 'youtube', '英超赛后分析');
      football.recallRoute = 'profile';
      football.searchQuery = '足球';
      container.putOne(football, { keyword: '足球', insertedAt: 100 });
      const sports = poolCandidate('shared', 'youtube', '英超赛后分析');
      sports.recallRoute = 'profile';
      sports.searchQuery = '体育';
      container.putOne(sports, { keyword: '体育', insertedAt: 200 });

      expect(container.takeForProfile(emptyProfile(), '足球')?.candidate.id).assertEqual('shared');
    });

    it('removes only the cancelled query when another recall provenance remains', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      const football = poolCandidate('shared', 'youtube', '英超赛后分析');
      football.recallRoute = 'profile';
      football.searchQuery = '足球';
      container.putOne(football, { keyword: '足球', insertedAt: 100 });
      const sports = poolCandidate('shared', 'youtube', '英超赛后分析');
      sports.recallRoute = 'profile';
      sports.searchQuery = '体育';
      container.putOne(sports, { keyword: '体育', insertedAt: 200 });

      expect(container.removeProfileRecallQueries(['足球'])).assertEqual(0);
      expect(container.size).assertEqual(1);
      expect(container.entries()[0].searchKeywords.length).assertEqual(1);
      expect(container.takeForProfile(emptyProfile(), '体育')?.candidate.id).assertEqual('shared');
    });

    it('fuzzy matches reordered and partially overlapping Chinese title text', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(
        poolCandidate('visa', 'youtube', '加拿大签证旅游申请教程'), { insertedAt: 100 });
      container.putOne(
        poolCandidate('unrelated', 'youtube', '今日热门内容推荐'), { insertedAt: 200 });
      const profile = emptyProfile();
      profile.topicWeights = [{ key: '加拿大旅游签证', weight: 10, updatedAt: 100 }];

      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('visa');
    });

    it('uses search provenance as fuzzy recall evidence when title does not contain the keyword', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(
        poolCandidate('provenance', 'youtube', '手把手网上申请攻略'),
        { keyword: '加拿大旅游签证', insertedAt: 100 });
      container.putOne(
        poolCandidate('unrelated', 'youtube', '今日热门内容推荐'), { insertedAt: 200 });
      const profile = emptyProfile();
      profile.topicWeights = [{ key: '加拿大旅游签证', weight: 10, updatedAt: 100 }];

      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('provenance');
    });

    it('matches an English alias by token overlap despite different word order', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(
        poolCandidate('english', 'youtube', 'Language Models for Large Scale Applications'),
        { insertedAt: 100 });
      container.putOne(
        poolCandidate('unrelated', 'youtube', 'Daily Sports Highlights'), { insertedAt: 200 });
      const profile = emptyProfile();
      profile.topicWeights = [{
        key: '大语言模型', aliases: ['large language models'], weight: 10, updatedAt: 100
      }];

      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('english');
    });

    it('applies explicit blocks and uses newest insertion as the zero-score fallback', 0, () => {
      const container = new WaterfallSourcePoolContainer('youtube');
      container.putOne(poolCandidate('old', 'youtube', '科技旧闻'), { insertedAt: 100 });
      container.putOne(poolCandidate('blocked', 'youtube', '八卦新闻'), { insertedAt: 300 });
      container.putOne(poolCandidate('new', 'youtube', '旅行新鲜事'), { insertedAt: 200 });
      const profile = emptyProfile();
      profile.explicitRules = [{ dimension: 'topic', key: '八卦', effect: 'block' }];

      expect(container.takeForProfile(profile)?.candidate.id).assertEqual('new');
      profile.explicitRules = [{ dimension: 'source', key: 'youtube', effect: 'block' }];
      expect(container.takeForProfile(profile)).assertNull();
      expect(container.size).assertEqual(2);
    });
  });
}
