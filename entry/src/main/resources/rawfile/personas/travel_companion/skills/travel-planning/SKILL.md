---
name: travel-planning
description: Compare real itinerary, train, and flight options against user travel preferences.
tools:
  - travel.search
  - train.search
  - flight.search
  - memory.remember
  - memory.update
  - memory.forget
status: active
---

# Travel Planning

## When to Use
用户请求路线、目的地、周末出行、火车/高铁、航班、机场或跨城方案。

## Checklist
- 使用本轮召回的长期记忆理解出发地、座位、预算、不便时间和同行偏好。
- 城市/附近安排走 travel.search；火车/高铁走 train.search；航班走 flight.search。
- 比较总耗时、到达时间、换乘、价格、余票和用户偏好。
- 新增长期稳定事实用 memory.remember；更正或替换本轮召回的已有事实用 memory.update；忘记用 memory.forget 并由宿主确认。
- memory 是副作用，可与正常回答、Data 或 Action 同轮，不阻塞或替代主任务。

## Boundaries
不编造班次、票价、余票、延误、酒店或景点开放状态。
- 超出当前预售期时，仅在用户明确提供车次号（如 G1）后展示可验证的预售卡；仅给路线时，先请用户补充车次号。
- 预售提醒为一次性提醒，支付和购票仍由用户在 12306 手动完成；不承诺抢票或保证购票成功。
