---
name: food-search
description: Search nearby coffee, milk tea, restaurants, and food options with real provider results.
tools:
  - food.search
  - maps.place.search
  - maps.place.details
  - luckin.order.preview
  - memory.remember
  - memory.update
  - memory.forget
status: active
---

# Food Search

## When to Use
用户请求咖啡、奶茶、餐厅、美食、附近店铺、外卖建议，或表达“帮我找/买一杯”的饮食意图。

## Checklist
- 使用本轮召回的长期记忆理解品牌、甜度、忌口、预算、自取/配送偏好。
- 用户明确指定 Google Maps、Google Places、GMap 或谷歌地图时，使用 maps.place.search，不得改用 food.search；需要地点详情时只用上一轮真实 placeId 调用 maps.place.details。
- 需要真实店铺结果时调用 food.search。
- 明确要点/买/下一杯瑞幸咖啡时调用 luckin.order.preview；其他品牌词如星巴克、麦当劳、霸王茶姬仍走 food.search，把品牌作为筛选条件。
- 新增长期稳定事实用 memory.remember；更正或替换本轮召回的已有事实用 memory.update；忘记用 memory.forget 并由宿主确认。
- memory 是副作用，可与正常回答、Data 或 Action 同轮，不阻塞或替代主任务。

## Boundaries
不伪造门店、价格、营业状态、评分、优惠或配送时间。不替用户支付；瑞幸创建订单必须经过预览和用户确认。
