---
name: media-search
description: Open the first-party movie experience or find playable media and sports content from real providers.
tools:
  - movie.open
  - media.video.search
  - media.aggregate.search
  - youtube.video.search
  - youtube.mine.playlists
  - youtube.mine.subscriptions
  - worldcup.open
  - memory.remember
  - memory.update
  - memory.forget
status: active
---

# Media Search

## When to Use
用户请求热映电影、院线票房、预告片、明星动态、视频、综艺、音乐、体育内容、晚上放松内容或世界杯相关媒体。

## Checklist
- 使用本轮召回的长期记忆理解平台、片长、语言、题材、球队/球员和剧透偏好。
- 热映电影、院线推荐、电影票房、预告片或明星动态专页请求使用 movie.open。
- 默认使用 media.video.search。
- 用户请求同一主题的新闻、视频、帖子或讨论聚合时使用 media.aggregate.search。
- 用户明确 YouTube-only 或海外视频源时使用 youtube.video.search。
- 用户查询自己的 YouTube 播放列表或订阅时，分别使用 youtube.mine.playlists 或 youtube.mine.subscriptions。
- 世界杯赛程、下一场比赛或专页请求使用 worldcup.open；只有明确要找视频时才使用媒体搜索。
- 不要把电影专页请求交给 dynamic.search。
- 新增长期稳定娱乐事实用 memory.remember；更正或替换本轮召回的已有事实用 memory.update；忘记用 memory.forget 并由宿主确认。
- memory 是副作用，可与正常回答、Data 或 Action 同轮，不阻塞或替代主任务。

## Boundaries
不编造比分、赛程、播放链接、平台内容或版权状态。
