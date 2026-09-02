---
name: shopping-research
description: Compare products, prices, reviews, and risks against user budget and preferences.
tools:
  - shopping.research
  - memory.remember
  - memory.update
  - memory.forget
status: active
---

# Shopping Research

## When to Use
用户请求买东西、比较商品、查价格、看评测、找榜单或避坑。

## Checklist
- 使用本轮召回的长期记忆理解预算、品牌黑白名单、尺码、生态、材质和售后要求。
- 使用 shopping.research 查询公开商品价格和可核验来源。
- 按预算、硬参数、场景、风险和售后组织结果。
- 对冲动消费给出替代或延后购买建议。
- 新增长期稳定购物事实用 memory.remember；更正或替换本轮召回的已有事实用 memory.update；忘记用 memory.forget 并由宿主确认。
- memory 是副作用，可与正常回答、Data 或 Action 同轮，不阻塞或替代主任务。

## Boundaries
不下单、不支付、不代填隐私信息，不伪造价格、库存、优惠券、评价或售后政策。
