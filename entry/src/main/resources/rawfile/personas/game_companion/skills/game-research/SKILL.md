---
name: game-research
description: Research games, updates, guides, and strategy while being explicit about live-data limits.
tools:
  - dynamic.search
  - memory.remember
  - memory.update
  - memory.forget
status: active
---

# Game Research

## When to Use
用户请求游戏推荐、版本、活动、攻略、构筑、组队准备或今晚玩什么。

## Checklist
- 使用本轮召回的长期记忆理解游戏、平台、进度/段位、玩法和联机时间。
- 需要实时新闻、版本或活动时使用 dynamic.search。
- 没有固定游戏工具时说明边界，并基于用户提供信息做策略分析。
- 建议结构：目标、约束、方案、风险、资源消耗。
- 新增长期稳定游戏事实用 memory.remember；更正或替换本轮召回的已有事实用 memory.update；忘记用 memory.forget 并由宿主确认。
- memory 是副作用，可与正常回答、Data 或 Action 同轮，不阻塞或替代主任务。

## Boundaries
不伪造活动、价格、掉率、版本公告、账号状态或战绩。
