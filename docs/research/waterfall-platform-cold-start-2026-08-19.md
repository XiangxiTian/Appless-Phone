# 发现流冷启动参考（2026-08-19）

实现只采用各平台公开材料能支持的共同做法：无偏好时用热门/趋势或有限探索兜底，随后用完成、跳过、显式喜欢/不感兴趣和搜索等会话信号快速调整；先做安全、重复和连续同类门禁，再排序。

- YouTube：无有效观看历史时首页推荐可为空；Explore/Trending 是明确的非个性化入口。[推荐说明](https://support.google.com/youtube/answer/16533387?hl=en) · [Trending](https://support.google.com/youtube/answer/7239739?hl=en)
- TikTok：未选主题时可从通用热门内容开始，再用完播、跳过、观看时长和显式互动学习。[官方说明](https://www.tiktok.com/safety/en/making-your-feed-for-you)
- Reddit：登出默认 Popular；候选会过滤 spam、已看和已屏蔽内容，并避免连续相似帖子。[官方说明](https://support.reddithelp.com/hc/en-us/articles/23511859482388-Reddit-s-Approach-to-Content-Recommendations)
- Instagram：公开材料支持推荐重置后逐步重学，但不足以断言新账号首批就是全站热门。[官方说明](https://about.fb.com/news/2024/11/introducing-recommendations-reset-instagram/)
- Bilibili/知乎：公开材料不足以复刻精确冷启动机制，因此缺少原生热门 provider 时只能标记为通用探索，不能伪称平台推荐。

Waterfall 因此不复制未知平台权重：所有来源、格式同优先级；使用现有原生热门能力或一个有界探索请求，配合本地去重、多样性和会话内快速学习。
