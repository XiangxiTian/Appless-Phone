# 上海出差连续 Agent 流程落地清单

> 工作分支：`Appless-Phone-travel-dev`
> 基线分支：`travel_dev`
> 场景基准：用户说“我下周五要去上海出差”
> 文档用途：实施、联调、验收时逐项勾选；不是产品对用户展示的流程。
> 当前产品形态（2026-08-14）：已取消出差任务对象、专用流程界面和专用上下文；由通用 Agent 对话上下文串联各个独立工具。
> 历史说明：第 5–19 节和实施记录保留旧方案轨迹，不再代表当前架构或待上线功能。

## 1. 使用规则

- `[ ]`：未完成。
- `[x]`：已完成，并且满足该项的完成证据要求。
- 开始开发时在条目末尾补充负责人或关联提交，例如：`（owner: xxx，commit: abc123）`。
- 只有“代码完成 + 自动化测试通过 + 对应界面/真机证据确认”后才能勾选阶段验收项。
- 供应商网页已打开不能作为预订成功证据。
- 用户口头确认和供应商确认必须使用不同状态，不得合并成“已预订”。
- 跨轮参数只来自通用 `recentMessages`、当前用户输入和模型的工具参数，不再维护 `TravelTask`。
- 交通工具执行前仅做安全预检：具体出发日期、出发地、目的地不完整时禁止调用供应商；是否追问及追问文案由模型基于通用上下文决定。
- 外跳返回后回到原通用结果页；不恢复出差任务步骤、进度卡或汇总卡。
- 每完成一个阶段，同步更新本文末尾的“实施记录”。

## 2. 本轮范围

本轮实现以下闭环：

```text
理解出差需求
→ 确认日期、出发地、目的地
→ 检查日历冲突
→ 同时搜索高铁和航班
→ 选择并承接交通预订与供应商支付
→ 核验预订结果
→ 写入日历
→ 搜索、选择并承接酒店预订与供应商支付
→ 核验酒店结果
→ 写入日历
→ 在当前对话确认流程完成并归档内部上下文
→ 用户需要时根据日历和已确认酒店导航或打车
```

本轮不包含：

- 返程交通。
- 改签、退票和酒店取消。
- 报销、发票和归档。
- 独立行程管理中心。
- 常驻出差卡、行程草稿、出差汇总卡或固定悬浮的出差信息卡。
- App代替用户自动支付；支付由供应商页面承接并在返回后核验。
- 绕过供应商确认或未经用户确认的真实叫车。

## 3. 总体验收标准

- [ ] `TRIP-GATE-001` 用户只需说“我下周五要去上海出差”，Agent 能以最少补问开始执行任务。
- [ ] `TRIP-GATE-002` 用户不需要重复说明日期、出发地、目的地、已选交通或已选酒店。
- [ ] `TRIP-GATE-003` 跳转供应商页面、返回 App、杀进程重启后都能恢复到正确操作步骤，且不出现常驻出差进度卡。
- [ ] `TRIP-GATE-004` 交通和酒店的“已选择、已打开页面、用户确认、供应商确认”展示准确。
- [ ] `TRIP-GATE-005` 交通和酒店日历事件不会重复创建，并保存真实 `eventId`。
- [ ] `TRIP-GATE-006` 用户提出导航或打车时，Agent 能从日历和已确认酒店中解析正确目的地，无需常驻任务卡。
- [ ] `TRIP-GATE-007` 所有外部写入操作都有明确确认、真实回执和失败状态。
- [ ] `TRIP-GATE-008` 完整主路径及关键异常路径通过自动化测试和真机验收。
- [ ] `TRIP-GATE-009` 正式构建中没有“继续某次出差”常驻入口、行程草稿、任务中心或流程汇总卡。

## 4. 当前能力基线

以下项目表示仓库已经有可复用的底层能力，不表示上海出差场景已经完成。

- [x] `TRIP-BASE-001` 已有 `travel.search`，可聚合高铁和航班候选。
- [x] `TRIP-BASE-002` 已有 `train.search`，可查询真实12306车次、余票和价格。
- [x] `TRIP-BASE-003` 已有 `flight.search`，可查询航班数据。
- [x] `TRIP-BASE-004` 已有日历查询、创建、更新和删除能力。
- [x] `TRIP-BASE-005` 已有酒店搜索、房型详情、价格和取消政策能力。
- [x] `TRIP-BASE-006` 已有12306网页购票和高铁预售任务承接。
- [x] `TRIP-BASE-007` 已有RollingGo酒店预订网页承接。
- [x] `TRIP-BASE-008` 已有酒店导航、地点搜索和地图路线能力。
- [x] `TRIP-BASE-009` 已有打车估价、确认下单、取消订单和司机位置能力。
- [x] `TRIP-BASE-010` 已有BIM事项持久化能力，可复用其存储和恢复模式。
- [ ] `TRIP-BASE-011` 将上述独立能力串成同一个可恢复的 Agent 内部流程，不要求用户创建或管理出差任务。

## 5. 历史方案：内部短期流程上下文（已退役）

本节及后续专用 `TravelTask` 阶段仅作历史实施记录。相关模型、存储、编排器、固定界面和动作已从产品代码删除。

已删除的历史模块：

```text
agent_core/src/main/ets/aiphone/runtime/TravelTaskTypes.ets
entry/src/main/ets/pages/A2uiHome/travel/TravelTaskStore.ets
entry/src/main/ets/pages/A2uiHome/travel/TravelTaskOrchestrator.ets
entry/src/main/ets/pages/A2uiHome/travel/TravelTaskActions.ets
```

### 数据模型

- [x] `TRIP-CTX-001` 定义 `TravelTask`、`TravelLeg`、`TravelBooking`、`TravelHotelStay` 和 `TravelTaskStep`。（owner: Codex）
- [x] `TRIP-CTX-002` 每次出差生成唯一、稳定的 `taskId`。（owner: Codex）
- [x] `TRIP-CTX-003` 保存绝对日期、时区、出发地、目的城市、最终目的地、出差目的。（owner: Codex）
- [x] `TRIP-CTX-004` 保存会议开始/结束时间、会议地点及坐标。（owner: Codex）
- [x] `TRIP-CTX-005` 保存日历冲突查询结果和查询时间。（owner: Codex）
- [x] `TRIP-CTX-006` 保存交通搜索条件、结果快照、已选方案和选择时间。（owner: Codex）
- [x] `TRIP-CTX-007` 保存交通预订状态、证据等级、订单号和供应商回执。（owner: Codex）
- [x] `TRIP-CTX-008` 保存交通日历 `eventId` 和写入结果。（owner: Codex）
- [x] `TRIP-CTX-009` 保存酒店搜索条件、已选酒店、房型、价格、取消政策、地址和坐标。（owner: Codex）
- [x] `TRIP-CTX-010` 保存酒店预订状态、证据等级、订单号和供应商回执。（owner: Codex）
- [x] `TRIP-CTX-011` 保存酒店日历 `eventId` 和写入结果。（owner: Codex）
- [x] `TRIP-CTX-012` 保存当前步骤、下一步动作、最后更新时间和最近错误。（owner: Codex）

### 持久化与恢复

- [x] `TRIP-CTX-013` 实现 `TravelTaskStore` 的创建、读取、更新和归档。（owner: Codex）
- [x] `TRIP-CTX-014` 所有任务更新采用幂等写入，不因重复动作产生重复数据。（owner: Codex）
- [x] `TRIP-CTX-015` App退到后台前保存任务状态。（owner: Codex）
- [x] `TRIP-CTX-016` 打开第三方页面前保存 `returnStep` 和待核验对象。（owner: Codex；已接入当前12306与RollingGo入口）
- [x] `TRIP-CTX-017` App恢复时根据 `taskId + returnStep` 直接恢复当前操作界面或下一步提示，不展示出差进度卡。（owner: Codex；阶段5.5自动化与真机验收通过）
- [x] `TRIP-CTX-018` App被杀后重新启动仍能恢复未完成任务。（owner: Codex）
- [x] `TRIP-CTX-019` 增加数据版本和迁移策略，旧数据无法解析时安全降级。（owner: Codex）
- [x] `TRIP-CTX-024` 酒店写入日历或用户明确结束流程后自动归档内部上下文，不在首页形成常驻入口。
- [ ] `TRIP-CTX-025` 归档后保留订单证据和日历 `eventId` 的必要索引，供后续自然语言导航或打车解析。

### 状态真实性

- [x] `TRIP-CTX-020` 统一预订状态：`not_selected`、`selected`、`handoff_opened`、`user_confirmed`、`provider_confirmed`、`calendar_added`。（owner: Codex）
- [x] `TRIP-CTX-021` 网页打开或App恢复不得自动进入 `provider_confirmed`。（owner: Codex）
- [x] `TRIP-CTX-022` 用户自报完成只能进入 `user_confirmed`。（owner: Codex）
- [x] `TRIP-CTX-023` 只有供应商回执或可信订单查询结果才能进入 `provider_confirmed`。（owner: Codex）

### 阶段验收

- [ ] `TRIP-CTX-GATE` 序列化、迁移、幂等更新、非法状态跳转、当前步骤恢复、自动归档和无常驻卡均通过测试。（当前步骤直达和无常驻卡已完成；酒店流程收尾后的自动归档待补）

## 6. 阶段二：需求理解与最少补问

- [x] `TRIP-INTENT-001` 将“下周五”解析为用户时区下的绝对日期。
- [x] `TRIP-INTENT-002` 在界面中显示绝对日期供用户确认。
- [x] `TRIP-INTENT-003` 按当前位置、常驻地或历史偏好推断出发地，并记录推断来源。
- [x] `TRIP-INTENT-004` 无法可靠推断出发地时只追问出发地。
- [x] `TRIP-INTENT-005` 将“上海”补充为会议地点或最终目的地；缺失时只追问具体地点。
- [x] `TRIP-INTENT-006` 获取会议时间；没有会议时间时允许继续搜索，但不声称完成冲突筛选。
- [x] `TRIP-INTENT-007` 获取住宿晚数；默认一晚时必须可修改。
- [x] `TRIP-INTENT-008` 将确认结果写入内部短期流程上下文，而不是仅保留在对话文本中；该上下文不作为用户可见任务。
- [x] `TRIP-INTENT-009` 修改日期、出发地或目的地后，使旧日历检查和交通搜索结果失效。
- [x] `TRIP-INTENT-010` 已产生真实订单时修改关键信息必须警告，不得静默覆盖。
- [x] `TRIP-INTENT-016` 模型选择 `travel.search`、`train.search` 或 `flight.search` 后，工具执行前校验具体日期、出发地和目的地；缺失时改为一次性中文追问，不调用供应商。（owner: Codex）
- [x] `TRIP-INTENT-017` 完整参数只从当前输入、近期用户消息和可信当前surface上下文补齐；模型生成但未出现在可信文本中的默认城市不得通过预检。（owner: Codex）

### 界面与动作

- [x] `TRIP-INTENT-011` 展示当前步骤的简洁需求确认界面；进入下一步后不作为常驻卡保留。
- [x] `TRIP-INTENT-012` 实现原地编辑日期、出发地、目的地和最晚到达时间。
- [x] `TRIP-INTENT-013` 实现 `travel.task.confirm`。
- [x] `TRIP-INTENT-014` 实现 `travel.task.edit`。
- [x] `TRIP-INTENT-015` 实现 `travel.task.check_calendar`。

### 阶段验收

- [x] `TRIP-INTENT-GATE` “我下周五去上海出差”在已知常驻地和未知常驻地两种条件下都能进入正确下一步。（自动化覆盖已知/未知出发地两条路径；真机完成确认、原地修改出发地、重新确认、进入查日历入口和杀进程重启恢复）

## 7. 阶段三：日历冲突检查

- [x] `TRIP-CAL-001` 根据出差日期生成正确的日历查询区间。
- [x] `TRIP-CAL-002` 查询出发前、出行中和到达后的日程。
- [x] `TRIP-CAL-003` 将会议开始时间转换为交通方案的最晚到达约束。
- [x] `TRIP-CAL-004` 区分硬冲突、可调整日程和不相关日程。
- [x] `TRIP-CAL-005` 保存冲突事件的真实 `eventId`、时间和地点。
- [x] `TRIP-CAL-006` 日历权限拒绝时允许继续，但内部流程上下文记录“未完成冲突检查”。

### 界面与动作

- [x] `TRIP-CAL-007` 展示冲突摘要、时间缓冲和会议约束。
- [x] `TRIP-CAL-008` 实现“查看当天日程”。
- [x] `TRIP-CAL-009` 实现“调整出差条件”。
- [x] `TRIP-CAL-010` 实现“搜索交通”，进入交通聚合结果。

### 阶段验收

- [x] `TRIP-CAL-GATE` 有冲突、无冲突和无日历权限三条路径均有正确界面和下一步。（自动化覆盖三条结果路径；真机实际验证无权限状态、调整条件、搜索交通及杀进程重启恢复）

## 8. 阶段四：交通搜索、排序与选择

### 查询与归一化

- [x] `TRIP-SEARCH-001` 并行调用高铁和航班查询。
- [x] `TRIP-SEARCH-002` 将高铁和航班归一化为可比较的交通方案结构。
- [x] `TRIP-SEARCH-003` 保留供应商、查询时间和数据来源。
- [x] `TRIP-SEARCH-004` 交通结果过期后不能直接预订，必须刷新。
- [x] `TRIP-SEARCH-005` 单侧供应商失败时展示另一侧结果和真实失败原因。

### 门到门计算

- [x] `TRIP-SEARCH-006` 计算出发地到机场/车站的时间。
- [x] `TRIP-SEARCH-007` 为机场和车站分别配置提前到达时间。
- [x] `TRIP-SEARCH-008` 计算交通运行时间。
- [x] `TRIP-SEARCH-009` 计算到达机场/车站到会议地点的时间。
- [x] `TRIP-SEARCH-010` 加入换乘、安检和延误安全缓冲。
- [x] `TRIP-SEARCH-011` 计算最终到达会议地点时间。
- [x] `TRIP-SEARCH-012` 标记“可赶上会议”“风险较高”“确定来不及”。

### 推荐与界面

- [x] `TRIP-SEARCH-013` 按日历约束、到达时间、总耗时和价格进行稳定排序。
- [x] `TRIP-SEARCH-014` 展示“Agent推荐”“最早到达”“来不及”等有依据的标签。
- [x] `TRIP-SEARCH-015` 保留全部、航班和高铁筛选。
- [x] `TRIP-SEARCH-016` 每个候选增加“选择此方案”。
- [x] `TRIP-SEARCH-017` 选择后高亮并写入 `TravelTask`。
- [x] `TRIP-SEARCH-018` 实现“换一个方案”，返回结果时不丢失筛选和任务上下文。
- [x] `TRIP-SEARCH-019` 统一原生卡片和WebView卡片的能力文案。

### 动作

- [x] `TRIP-SEARCH-020` 注册并校验 `travel.option.select`。
- [x] `TRIP-SEARCH-021` 注册并校验 `travel.option.change`。
- [x] `TRIP-SEARCH-022` action参数只引用当前surface真实候选，不接受模型临时拼接票价、车次或航班。

### 阶段验收

- [x] `TRIP-SEARCH-GATE` 航班推荐、高铁推荐、高铁来不及、单供应商失败和结果过期均通过测试。

## 9. 阶段五：交通预订承接与返回核验

### 高铁

- [x] `TRIP-BOOK-TRAIN-001` 将现有12306入口绑定到当前已选高铁方案。
- [x] `TRIP-BOOK-TRAIN-002` 保留支付宝购票作为次级入口。
- [x] `TRIP-BOOK-TRAIN-003` 预售车次进入现有预售任务设置面板。
- [x] `TRIP-BOOK-TRAIN-004` 打开12306前保存 `taskId`、已选方案和 `returnStep`。
- [x] `TRIP-BOOK-TRAIN-005` 返回App后进入交通预订核验，而不是显示“已订票”。

### 航班

- [x] `TRIP-BOOK-FLIGHT-001` 确定首个航班预订供应商及产品边界。
- [x] `TRIP-BOOK-FLIGHT-002` 建立航班预订供应商适配接口。
- [x] `TRIP-BOOK-FLIGHT-003` 实现可信航班预订URL生成和白名单校验。
- [x] `TRIP-BOOK-FLIGHT-004` 航班卡增加“去预订航班”。
- [x] `TRIP-BOOK-FLIGHT-005` 跳转前保存 `taskId`、已选航班和 `returnStep`。
- [x] `TRIP-BOOK-FLIGHT-006` 返回App后进入交通预订核验。

### 返回与订单证据

- [x] `TRIP-BOOK-001` 注册并校验 `travel.booking.open`。
- [x] `TRIP-BOOK-002` 实现 App/WebView 返回监听。
- [x] `TRIP-BOOK-003` 返回后展示“尚未获得服务商确认”。
- [x] `TRIP-BOOK-004` 实现“重新打开预订页”。
- [x] `TRIP-BOOK-005` 实现 `travel.order.sync`。
- [x] `TRIP-BOOK-006` 同步成功后保存订单号、支付状态、出票状态和供应商回执。
- [x] `TRIP-BOOK-007` 无订单查询接口时提供“我已完成预订”，状态记为 `user_confirmed`。
- [x] `TRIP-BOOK-008` 供应商回执明确成功后状态记为 `provider_confirmed`。
- [x] `TRIP-BOOK-009` 同步失败、用户取消、订单待支付和订单不存在均有独立状态。
- [x] `TRIP-BOOK-010` 防止重复点击产生重复预订动作。

### 阶段验收

- [x] `TRIP-BOOK-GATE` 高铁和航班均通过“打开 → 返回 → 核验 → 用户确认/供应商确认”的完整测试。

## 10. 阶段六：交通写入日历

- [x] `TRIP-TCAL-001` 仅从当前已选并已核验的交通方案生成日历事件。（owner: Codex）
- [x] `TRIP-TCAL-002` 日历事件包含车次/航班号、机场/车站、时间、订单证据等级。（owner: Codex）
- [x] `TRIP-TCAL-003` 航班和高铁使用不同的出发提醒策略。（owner: Codex）
- [x] `TRIP-TCAL-004` 创建成功后保存真实 `calendarEventId`。（owner: Codex）
- [x] `TRIP-TCAL-005` 使用 `taskId + legId` 作为幂等键，避免重复创建。（owner: Codex）
- [x] `TRIP-TCAL-006` 已存在事件时更新或提示，不再次创建。（owner: Codex）
- [x] `TRIP-TCAL-007` 创建失败时保留重试动作和真实错误。（owner: Codex）
- [x] `TRIP-TCAL-008` 用户确认的预订在日历描述中标明“用户确认，未同步供应商”。（owner: Codex）
- [x] `TRIP-TCAL-009` 实现 `travel.calendar.add`。（owner: Codex）
- [x] `TRIP-TCAL-010` 写入成功后进入酒店搜索步骤。（owner: Codex）

### 阶段验收

- [x] `TRIP-TCAL-GATE` 创建、重试、更新、防重复和权限拒绝均通过测试。（自动化覆盖生成、状态机、失败重试、权限异常和幂等匹配；真机事件`293`重复写入后仍为`293`，杀进程恢复后仍为`293`）

## 11. 阶段七：酒店搜索、详情与选择

- [x] `TRIP-HOTEL-001` 从内部流程上下文自动读取入住、离店日期和住宿晚数，不要求用户重新输入。
- [x] `TRIP-HOTEL-002` 默认以会议地点为酒店搜索中心，而不是只使用“上海”。
- [x] `TRIP-HOTEL-003` 使用交通到达站作为第二位置参考。
- [x] `TRIP-HOTEL-004` 计算酒店到会议地点的距离和时间。
- [x] `TRIP-HOTEL-005` 计算酒店到到达机场/车站的距离和时间。
- [x] `TRIP-HOTEL-006` 结合位置、价格、取消政策生成可解释推荐。
- [x] `TRIP-HOTEL-007` 酒店结果展示会议距离、到达站距离和推荐理由。
- [x] `TRIP-HOTEL-008` 复用“查看实时房型”进入酒店详情。
- [x] `TRIP-HOTEL-009` 用户选择房型后保存酒店、`hotelId`、`ratePlanId`、价格和取消政策。
- [x] `TRIP-HOTEL-010` 返回酒店结果时恢复原搜索结果和内部流程上下文，不生成常驻入口。
- [x] `TRIP-HOTEL-011` 房价或房态过期时要求刷新详情。

### 阶段验收

- [x] `TRIP-HOTEL-GATE` 酒店搜索、房型查看、返回恢复、过期刷新和无结果路径通过测试。（自动化覆盖主路径、过期、失败和恢复；真机通过真实 RollingGo 搜索、详情、返回、房型选择、覆盖安装重启恢复与信息完整展示）

## 12. 阶段八：酒店预订承接与返回核验

- [x] `TRIP-HBOOK-001` RollingGo预订承接使用当前surface真实 `hotelId` 和白名单URL。
- [x] `TRIP-HBOOK-002` 打开预订页前保存已选酒店、房型、`taskId` 和 `returnStep`。
- [x] `TRIP-HBOOK-003` WebView关闭或App恢复后进入酒店订单核验。
- [x] `TRIP-HBOOK-004` 网页打开或返回不得自动显示“酒店已确认”。
- [x] `TRIP-HBOOK-005` 实现“重新打开预订页”。
- [x] `TRIP-HBOOK-006` 实现 `hotel.order.sync` 或供应商适配层等价动作。
- [x] `TRIP-HBOOK-007` 同步订单号、房型、入住人、支付状态和供应商确认状态。
- [x] `TRIP-HBOOK-008` 无订单接口时提供“我已完成预订”，状态记为 `user_confirmed`。
- [x] `TRIP-HBOOK-009` 保存最终酒店名称、地址、电话和可信坐标。
- [x] `TRIP-HBOOK-010` 保存免费取消截止时间。
- [x] `TRIP-HBOOK-011` 供应商失败、用户取消和订单待支付均有独立状态。

### 阶段验收

- [x] `TRIP-HBOOK-GATE` 酒店“打开 → 返回 → 核验 → 用户确认/供应商确认”完整通过测试。

## 13. 阶段九：酒店写入日历与流程收尾

### 酒店日历

- [x] `TRIP-HCAL-001` 从已核验酒店结果生成入住日历事件。
- [x] `TRIP-HCAL-002` 事件包含酒店名称、地址、电话、订单号、房型和证据等级。
- [x] `TRIP-HCAL-003` 设置入住和退房时间。
- [x] `TRIP-HCAL-004` 可配置免费取消截止提醒。
- [x] `TRIP-HCAL-005` 保存真实 `calendarEventId`。
- [x] `TRIP-HCAL-006` 使用 `taskId + stayId` 防止重复创建。
- [x] `TRIP-HCAL-007` 写入失败可重试且不会丢失酒店订单信息。
- [x] `TRIP-HCAL-008` 实现 `hotel.calendar.add` 或等价受控动作。

### 流程收尾

- [x] `TRIP-FINISH-001` 酒店日历写入完成后，在当前对话显示一次性完成结果，不生成出差汇总卡或首页入口。
- [x] `TRIP-FINISH-002` 完成结果分别说明交通、酒店和日历的真实状态，打开供应商页面不得显示为预订完成。
- [x] `TRIP-FINISH-003` 提供当次可用的“查看日历”“继续处理未完成项”动作；离开该界面后不常驻。
- [x] `TRIP-FINISH-004` 交通或酒店缺失时准确指出下一步，不显示“准备完成”，并继续使用同一内部上下文。
- [x] `TRIP-FINISH-005` 全部必要步骤完成或用户明确结束后自动归档内部上下文。
- [x] `TRIP-FINISH-006` 自动归档不得删除已确认订单证据、酒店地址、可信坐标和日历 `eventId` 的必要索引。
- [x] `TRIP-FINISH-007` App重启后不重建完成汇总卡；用户后续提问时按日历、订单证据和当次语义重新生成所需界面。

### 阶段验收

- [x] `TRIP-FINISH-GATE` 完成、部分完成、用户结束和重启后无常驻卡四种路径均展示正确并完成内部归档。

## 14. 阶段十：出差当天、导航与打车

### 用户触发与目的地解析

- [x] `TRIP-DAY-001` 识别“导航到酒店”“打车去酒店”等当次自然语言请求，不要求用户先打开出差卡。
- [ ] `TRIP-DAY-002` 查询当前日期附近的交通、会议和酒店日历事件，并读取必要的已确认订单索引。
- [x] `TRIP-DAY-003` 从可信日历事件或已确认酒店中解析名称、地址和坐标，不依赖未归档任务或常驻卡。
- [x] `TRIP-DAY-004` 存在多个可能酒店时只追问一次目的地，不静默选择错误酒店。
- [x] `TRIP-DAY-005` 在用户授权后获取当前位置；拒绝时允许用户手动确认起点。
- [x] `TRIP-DAY-006` 已能唯一确定酒店时不再次询问酒店名称和地址。
- [x] `TRIP-DAY-007` 只为当前请求展示“导航到酒店”和“查看打车价格”。

### 导航

- [x] `TRIP-NAV-001` 使用当次解析出的可信酒店名称、地址和坐标构建导航动作。
- [x] `TRIP-NAV-002` 地图动作参数绑定当次已确认目的地，模型不能替换目的地。
- [x] `TRIP-NAV-003` 返回App后恢复本次导航结果或对话上下文，不生成上海出差当天常驻界面。（真机从Petal Maps返回Appless后，到达动作卡和酒店目的地仍保留）
- [ ] `TRIP-NAV-004` 坐标缺失时先解析地点，解析失败则不打开错误导航。

### 打车

- [x] `TRIP-RIDE-001` 自动使用当前位置作为起点、已确认酒店作为终点进行估价。
- [x] `TRIP-RIDE-002` 展示真实车型、价格、接驾时间和供应商状态。
- [x] `TRIP-RIDE-003` 选择车型只进入确认界面，不直接下单。
- [x] `TRIP-RIDE-004` 明确点击“确认叫车”后才调用 `ride.order.create`。
- [x] `TRIP-RIDE-005` 下单参数绑定当前估价的路线、车型和 `traceId`。
- [x] `TRIP-RIDE-006` 保存真实订单号并刷新司机位置。
- [x] `TRIP-RIDE-007` 展示司机、车辆、ETA和订单状态。
- [x] `TRIP-RIDE-008` 取消订单必须二次确认并使用真实订单号。
- [x] `TRIP-RIDE-009` 服务商不可用时提供滴滴/高德App跳转降级，不声称已叫车。

### 阶段验收

- [ ] `TRIP-DAY-GATE` 自然语言触发、日历/订单目的地解析、导航、估价、确认下单、司机位置和取消确认全部通过测试，且全程无需常驻卡。

## 15. 界面与按钮跳转矩阵

| 当前界面 | 主要动作 | 下一界面/结果 | 是否外部写入 | 确认要求 |
| --- | --- | --- | --- | --- |
| 需求确认 | `travel.task.edit` | 原地编辑 | 否 | 无 |
| 需求确认 | `travel.task.check_calendar` | 日历冲突摘要 | 否 | 无 |
| 日历冲突摘要 | `travel.search` | 高铁/航班聚合结果 | 否 | 无 |
| 交通结果 | `travel.option.select` | 已选交通确认 | 否 | 用户点击选择 |
| 已选交通 | `travel.booking.open` | 12306/航班供应商页 | 否 | 用户点击打开 |
| 供应商返回 | `travel.order.sync` | 交通订单核验结果 | 否 | 无 |
| 交通订单核验 | `travel.calendar.add` | 交通日历写入结果 | 是 | 当前可见动作 |
| 交通日历结果 | `hotel.search` | 酒店搜索结果 | 否 | 无 |
| 酒店结果 | `hotel.detail` | 房型和取消政策 | 否 | 用户点击查看 |
| 酒店详情 | `travel.hotel.booking.open` | RollingGo预订页 | 否 | 用户点击打开 |
| 酒店供应商返回 | `hotel.order.sync` | 酒店订单核验结果 | 否 | 无 |
| 酒店订单核验 | `hotel.calendar.add` | 酒店日历写入结果 | 是 | 当前可见动作 |
| 酒店日历结果 | `travel.flow.finish` | 当前对话完成提示并归档内部上下文 | 否 | 无 |
| 用户说“导航到酒店” | `hotel.resolve_destination` → `hotel.navigate`/`maps.route.open` | 地图导航 | 否 | 目的地唯一或用户确认 |
| 用户说“打车去酒店” | `hotel.resolve_destination` → `ride.estimate` | 打车估价 | 否 | 目的地唯一或用户确认 |
| 打车估价 | `ride.order.confirm` | 下单并显示订单状态 | 是 | 明确确认 |
| 打车订单 | `ride.order.cancel` | 取消结果 | 是 | 二次确认 |

### 跳转通用要求

- [ ] `TRIP-ROUTE-001` 所有动作使用固定、受控、可校验的action ID。
- [ ] `TRIP-ROUTE-002` 外部URL必须来自可信供应商返回或App生成的白名单URL。
- [ ] `TRIP-ROUTE-003` 外部跳转前必须持久化内部流程上下文和返回步骤，但不创建用户可见任务入口。
- [ ] `TRIP-ROUTE-004` 动作执行中禁用重复点击。
- [ ] `TRIP-ROUTE-005` 写操作展示执行中、成功和失败状态。
- [ ] `TRIP-ROUTE-006` 当前surface之外的旧动作不可重放。
- [ ] `TRIP-ROUTE-007` 页面展示状态只从内部上下文、日历、订单证据和真实工具结果生成，不由模型自由声称成功。
- [x] `TRIP-ROUTE-008` 每次只展示当前步骤surface；完成或离开后不得保留常驻出差卡、汇总卡或任务中心入口。（owner: Codex；阶段一至五恢复入口已改为固定当前步骤分发器）

## 16. 异常恢复清单

- [ ] `TRIP-ERR-001` 日历权限拒绝。
- [ ] `TRIP-ERR-002` 定位权限拒绝。
- [ ] `TRIP-ERR-003` 高铁查询失败或无票。
- [ ] `TRIP-ERR-004` 航班查询失败或缺少供应商配置。
- [ ] `TRIP-ERR-005` 高铁与航班都失败。
- [ ] `TRIP-ERR-006` 交通价格、余票或航班结果过期。
- [x] `TRIP-ERR-007` 用户取消交通预订。
- [x] `TRIP-ERR-008` 返回App但没有交通订单。
- [x] `TRIP-ERR-009` 交通订单同步超时或状态待支付。
- [ ] `TRIP-ERR-010` 交通日历写入失败或重复写入。
- [ ] `TRIP-ERR-011` 酒店查询失败或无结果。
- [ ] `TRIP-ERR-012` 酒店房价、房态或取消政策过期。
- [ ] `TRIP-ERR-013` 用户取消酒店预订。
- [ ] `TRIP-ERR-014` 返回App但没有酒店订单。
- [ ] `TRIP-ERR-015` 酒店订单同步超时或待支付。
- [x] `TRIP-ERR-016` 酒店日历写入失败或重复写入。（失败保留酒店订单并支持重试；稳定幂等键和原生更新逻辑已覆盖）
- [ ] `TRIP-ERR-017` App在任一步骤被杀后恢复到当前可操作步骤，不落到常驻进度卡。
- [ ] `TRIP-ERR-018` 地图App不存在或地图URI打开失败。
- [ ] `TRIP-ERR-019` 打车估价失败。
- [ ] `TRIP-ERR-020` 打车下单失败或没有订单回执。
- [x] `TRIP-ERR-025` 交通查询缺少具体日期、出发地或目的地时，在供应商调用前转为补问，不渲染12306/飞常准参数错误结果。（owner: Codex；相关解析、Leader与Canary运行时测试通过，Debug HAP构建通过；待真机交互复核）
- [ ] `TRIP-ERR-021` 司机位置查询失败。
- [ ] `TRIP-ERR-022` 取消订单失败。
- [ ] `TRIP-ERR-023` 用户修改已产生订单的出行条件。
- [ ] `TRIP-ERR-024` 内部上下文归档失败时不丢失已写入日历和订单证据，也不生成常驻卡作为降级。

## 17. 测试清单

### 单元测试

- [ ] `TRIP-TEST-U001` 相对日期和时区解析。
- [x] `TRIP-TEST-U002` `TravelTask`序列化、迁移和恢复。
- [x] `TRIP-TEST-U003` 合法和非法状态迁移。
- [x] `TRIP-TEST-U004` 门到门时间计算。
- [ ] `TRIP-TEST-U005` 日历冲突判断。
- [x] `TRIP-TEST-U006` 交通排序和推荐标签。
- [x] `TRIP-TEST-U007` 交通和酒店结果过期判断。
- [x] `TRIP-TEST-U008` 预订证据等级判断。
- [x] `TRIP-TEST-U009` 日历幂等键和防重复逻辑。（交通日历已覆盖；酒店日历在阶段九继续覆盖）
- [ ] `TRIP-TEST-U010` 所有新增action参数校验。（阶段四交通action已覆盖；后续阶段新增action完成后统一验收）
- [x] `TRIP-TEST-U011` 供应商URL白名单。
- [ ] `TRIP-TEST-U012` 日历或已确认酒店索引到地图/打车参数映射。

### 集成测试

- [ ] `TRIP-TEST-I001` 日历查询与冲突摘要。
- [x] `TRIP-TEST-I002` 高铁和航班并行搜索及部分失败。
- [x] `TRIP-TEST-I003` 交通选择、持久化和页面恢复。
- [x] `TRIP-TEST-I004` 高铁预订网页打开和返回核验。
- [x] `TRIP-TEST-I005` 航班预订网页打开和返回核验。
- [x] `TRIP-TEST-I006` 交通日历创建、更新和防重复。（真机创建真实事件并以同一幂等键更新，事件ID保持`293`）
- [x] `TRIP-TEST-I007` 酒店搜索、详情和返回恢复。（`docs/evidence/travel-stage7-device-2026-08-13/`）
- [ ] `TRIP-TEST-I008` 酒店预订网页打开和返回核验。
- [x] `TRIP-TEST-I009` 酒店日历创建、更新和防重复。（状态机与固定界面自动化覆盖；真机完成真实事件创建并确认事件ID保存）
- [ ] `TRIP-TEST-I010` 自然语言请求经日历/已确认酒店解析到导航和打车的参数传递。

### 端到端与真机测试

- [ ] `TRIP-TEST-E001` 航班主路径完整跑通。
- [ ] `TRIP-TEST-E002` 高铁主路径完整跑通。
- [ ] `TRIP-TEST-E003` 高铁预售路径完整跑通。
- [ ] `TRIP-TEST-E004` 日历存在冲突路径。
- [ ] `TRIP-TEST-E005` 日历无权限路径。
- [ ] `TRIP-TEST-E006` 交通预订取消返回路径。
- [ ] `TRIP-TEST-E007` 用户确认和供应商确认两种证据路径。
- [ ] `TRIP-TEST-E008` 酒店预订取消返回路径。
- [x] `TRIP-TEST-E009` App杀进程后直接恢复当前操作步骤且不展示出差进度卡。（`docs/evidence/travel-stage55-device-2026-08-13/`）
- [ ] `TRIP-TEST-E010` 到达后导航路径。
- [ ] `TRIP-TEST-E011` 打车估价、确认下单和司机位置路径。
- [ ] `TRIP-TEST-E012` 打车取消二次确认路径。
- [ ] `TRIP-TEST-E013` 全流程截图或录屏证据归档。
- [ ] `TRIP-TEST-E014` 从需求确认到流程收尾全程无常驻出差卡、行程草稿、任务中心或汇总卡。

## 18. 上线门禁

- [ ] `TRIP-RELEASE-001` 所有`TRIP-*-GATE`阶段验收项已勾选。
- [ ] `TRIP-RELEASE-002` 没有“打开网页即显示预订成功”的路径。
- [ ] `TRIP-RELEASE-003` 没有未经确认的日历写入、真实下单或取消订单。
- [ ] `TRIP-RELEASE-004` 所有新增权限都有用途说明、拒绝降级和隐私披露。
- [ ] `TRIP-RELEASE-005` 日志不记录身份证、完整手机号、支付信息或供应商凭证。
- [ ] `TRIP-RELEASE-006` 外部URL和深链通过白名单与参数校验。
- [ ] `TRIP-RELEASE-007` 全量自动化回归通过。
- [ ] `TRIP-RELEASE-008` 真机主路径与关键异常路径通过。
- [ ] `TRIP-RELEASE-009` 更新`docs/current-capabilities.md`中的真实能力边界。
- [ ] `TRIP-RELEASE-010` Release构建无法进入Debug验收任务卡，正式流程不会生成常驻出差入口或完成汇总卡。

## 19. 推荐实施顺序

1. `TRIP-CTX-*`：内部短期上下文、状态真实性、外跳返回、当前步骤恢复和自动归档。
2. `TRIP-INTENT-*`、`TRIP-CAL-*`：需求确认和日历冲突。
3. `TRIP-SEARCH-*`：交通聚合、门到门计算和选择。
4. `TRIP-BOOK-*`：高铁/航班预订承接、返回和订单核验。
5. `TRIP-TCAL-*`：交通日历幂等写入。
6. `TRIP-HOTEL-*`、`TRIP-HBOOK-*`：酒店搜索、选择和预订核验。
7. `TRIP-HCAL-*`、`TRIP-FINISH-*`：酒店日历、一次性流程收尾和内部上下文归档。
8. `TRIP-DAY-*`、`TRIP-NAV-*`、`TRIP-RIDE-*`：自然语言触发、日历/订单目的地解析、导航和打车。
9. `TRIP-ERR-*`、`TRIP-TEST-*`、`TRIP-RELEASE-*`：异常、回归和上线门禁。

## 20. 主要代码落点

| 领域 | 当前主要入口 |
| --- | --- |
| 工具定义与动作暴露 | `agent_core/src/main/ets/aiphone/runtime/ToolDefinitionRegistry.ets` |
| 工具调用与Provider网关 | `agent_core/src/main/ets/aiphone/runtime/ToolGatewayClient.ets` |
| A2UI类型与动作结构 | `agent_core/src/main/ets/aiphone/runtime/A2uiTypes.ets` |
| 通用对话上下文与任务执行 | `entry/src/main/ets/pages/A2uiHome/agent/MultiAgentLeaderPlanner.ets`、`entry/src/main/ets/pages/A2uiHome/agent/MultiAgentCanaryRuntime.ets` |
| 交通工具执行前必填参数预检 | `agent_core/src/main/ets/aiphone/runtime/TravelSearchPreflight.ets` |
| 交通聚合界面 | `entry/src/main/ets/pages/A2uiHome/components/TravelOptionsView.ets` |
| 高铁界面 | `entry/src/main/ets/pages/A2uiHome/components/TrainOptionsView.ets` |
| 航班界面 | `entry/src/main/ets/pages/A2uiHome/components/FlightBoardView.ets` |
| 交通WebView动作 | `entry/src/main/ets/pages/A2uiHome/html/HtmlHomeSnapshot.ets` |
| 交通预订供应商适配与白名单 | `entry/src/main/ets/pages/A2uiHome/travel/TravelBookingProvider.ets` |
| 酒店动作 | `agent_core/src/main/ets/aiphone/runtime/HotelActions.ets` |
| 酒店A2UI数据 | `agent_core/src/main/ets/aiphone/runtime/HotelToolA2ui.ets` |
| 页面动作路由和外部跳转 | `entry/src/main/ets/pages/A2uiHome/Index.ets` |
| 打车界面状态 | `entry/src/main/ets/pages/A2uiHome/state/RideToolResultsState.ets` |
| 打车结果界面 | `entry/src/main/ets/pages/A2uiHome/components/RideToolResultsView.ets` |

## 21. 实施记录

| 日期 | 条目/阶段 | 状态 | 完成证据 | 备注 |
| --- | --- | --- | --- | --- |
| 2026-08-12 | 清单建立 | 完成 | `docs/travel-business-trip-implementation-checklist.md` | 后续按条目ID更新 |
| 2026-08-12 | 阶段一：数据模型与状态真实性 | 完成 | `TravelTaskTypes.ets`；序列化、迁移、非法跳转和证据等级测试通过 | 不保存第三方URL、令牌或支付凭证 |
| 2026-08-12 | 阶段一：持久化与进程恢复 | 完成 | `TravelTaskStore.ets`、`TravelTaskOrchestrator.ets`；App生命周期已接入检查点与恢复 | 创建/读取/幂等更新/归档/失败回滚已覆盖 |
| 2026-08-12 | 阶段一：自动化验证 | 完成 | Hypium `Tests run: 1905, Failure: 0, Error: 0, Pass: 1905` | 新增18条阶段一测试；本机DevEco覆盖率报告生成器另有JSON解析告警，不影响测试结果文件 |
| 2026-08-12 | `TRIP-CTX-016` | 完成 | 当前12306与RollingGo入口在绑定出行任务时先持久化待核验对象和返回步骤 | 独立旧流程无活动出行任务时保持原行为 |
| 2026-08-12 | `TRIP-CTX-017`旧形态 | 已被新需求替代 | 外跳返回点与杀进程恢复曾映射为出差进度卡；恢复卡渲染测试通过 | 2026-08-13决定取消常驻卡；保留底层恢复能力，界面改为直接恢复当前步骤 |
| 2026-08-12 | 阶段一：真机验收 | 完成 | `docs/evidence/travel-stage1-device-2026-08-12/`；创建、杀进程重启、覆盖安装后均恢复成功 | `travel-stage1-test` 仅在Debug构建可用；真机Debug 1.0.2（1000002） |
| 2026-08-12 | 阶段二：需求理解与最少补问 | 完成 | 日期解析、定位/常驻地/历史出发地推断、单字段补问、城市级最终目的地和可修改住宿晚数已接入 `TravelTask` | 修改需求会递增版本并使旧日历、交通和酒店结果按影响范围失效；确认订单禁止静默覆盖 |
| 2026-08-12 | 阶段二：界面与动作 | 完成 | 当前步骤需求确认界面；原地编辑日期、出发地、目的地、会议地点/时间、最晚到达和住宿晚数；三个固定动作均已接入 | 该界面只服务当前步骤，不作为首页常驻卡；`travel.task.check_calendar`仅进入阶段三执行链路 |
| 2026-08-12 | 阶段二：自动化验证 | 完成 | Hypium `Tests run: 1918, Failure: 0, Error: 0, Pass: 1918`；Debug HAP 构建成功 | 本机DevEco覆盖率报告生成器仍有既有JSON解析告警，不影响测试结果文件 |
| 2026-08-12 | 阶段二：真机验收 | 完成 | 阶段二Debug包覆盖安装成功；当前步骤确认界面、字段编辑和固定动作均可操作 | 将出发地原地修改为广州后界面显示“广州 → 上海”；重新确认后出现“检查日历冲突”，杀进程重启后确认状态与路线保持 |
| 2026-08-12 | 阶段三：日历查询与冲突判断 | 完成 | `TravelCalendarPlanner.ets`；全天查询区间、会议前90分钟到达约束、事件分类及真实事件字段持久化 | 修改日期、地点、会议时间或最晚到达后会使旧检查结果失效；schema v2 自动迁移到 v3 |
| 2026-08-12 | 阶段三：界面与动作 | 完成 | 日历冲突摘要卡；查看/收起当天日程、调整出差条件、重新检查、连接日历和搜索交通动作已接入 | 无权限或失败时明确显示“未完成冲突检查”，仍允许进入交通搜索 |
| 2026-08-12 | 阶段三：自动化验证 | 完成 | Hypium `Tests run: 1929, Failure: 0, Error: 0, Pass: 1929`；阶段三Debug HAP构建并覆盖安装成功 | 有冲突、无冲突和无权限三条界面路径均有测试；既有覆盖率JSON告警不影响测试结果 |
| 2026-08-12 | 阶段三：真机验收 | 完成 | 阶段三Debug包覆盖安装；schema v2任务迁移恢复、实际无权限结果卡、按钮跳转与杀进程重启均通过 | 无权限卡明确显示“未完成冲突检查”；“调整出差条件”返回原地编辑卡；“搜索交通”进入高铁/航班聚合页；重启后恢复交通搜索步骤 |
| 2026-08-12 | 阶段四：交通搜索、排序与选择 | 完成 | `TravelTransportPlanner.ets`、`TravelTransportSurface.ets`；任务schema升级到v4；查询、归一化、门到门计算、稳定排序、筛选、选择、换选和过期保护均已接入 | WebView使用固定渲染器和当前surface可信候选生成动作，不接受模型拼接票价、车次或航班 |
| 2026-08-12 | 阶段四：自动化验证 | 完成 | Hypium `Tests run: 1942, Failure: 0, Error: 0, Pass: 1942`；Debug HAP构建成功 | 新增测试覆盖航班推荐、高铁推荐、高铁来不及、单供应商失败、结果过期与重新查询、可信action参数、选择/换选及恢复；既有覆盖率JSON告警不影响测试结果文件 |
| 2026-08-12 | 阶段四：真机验收 | 完成 | `docs/evidence/travel-stage4-device-2026-08-12/`；实际查询返回30个高铁方案及航班侧空结果；供应商证据、过期刷新、筛选、选择、换选和杀进程恢复均通过 | 真机发现并修复“已选结果过期后无法重新查询”的状态回退缺陷；最终保持G3020已选、高铁筛选激活和`6 / 30`计数 |
| 2026-08-12 | 阶段五：交通预订承接与返回核验 | 完成 | `TravelBookingProvider.ets`、`TravelBookingSurface.ets`；任务schema升级到v5；高铁12306/支付宝、预售提醒和航班携程入口均绑定当前已选方案 | 外跳前保存供应商、渠道、尝试号和返回步骤；不持久化URL、令牌或支付凭证；携程首期产品边界为官方机票搜索页 |
| 2026-08-12 | 阶段五：订单证据与自动化验证 | 完成 | Hypium `Tests run: 1959, Failure: 0, Error: 0, Pass: 1959`；Debug HAP构建成功 | 无供应商订单接口时如实返回`unsupported`并允许用户确认；供应商确认、用户确认、待支付、取消、失败、无订单和重复动作均有测试；新增非实时航班真机样例及原任务保护测试；既有覆盖率JSON告警不影响测试结果文件 |
| 2026-08-12 | 阶段五：高铁真机验收 | 完成 | `docs/evidence/travel-stage5-device-2026-08-12/`；设备`6HR0226506005010`覆盖安装；12306打开、返回核验、重启恢复和重新打开通过 | 真机发现12306网页未可靠回显URL日期，App安全页头已固定显示可信目标日期供核对；未执行真实下单或支付 |
| 2026-08-12 | 阶段五：航班真机验收 | 部分完成 | `docs/evidence/travel-stage5-flight-device-2026-08-12/`；非实时Debug航班样例完成携程跳转、返回核验、订单同步边界、杀进程恢复及原高铁任务还原 | 携程官方域名已打开，但页面正文被设备浏览器WhaleGuard拦截；真实航班查询、登录、下单、支付和出票未验证，因此`TRIP-TEST-E001`保持未完成 |
| 2026-08-13 | 产品形态调整：取消常驻出差卡 | 清单已更新 | 总体门禁、阶段一、阶段九、阶段十、跳转矩阵、测试与上线门禁均已改为“当前步骤surface + 内部短期上下文” | 重开`TRIP-CTX-017`、`TRIP-CTX-GATE`和`TRIP-TEST-E009`；新增自动归档、日历/订单目的地解析及无常驻卡验收项；既有数据模型和阶段二至五业务能力继续复用 |
| 2026-08-13 | 阶段5.5：当前步骤直达与无常驻卡 | 完成 | `TravelTaskCurrentSurface.ets`；Hypium `Tests run: 1961, Failure: 0, Error: 0, Pass: 1961`；`docs/evidence/travel-stage55-device-2026-08-13/` | 删除旧恢复进度卡和`travel.task.resume`动作；首次启动、创建样例、杀进程重启及清理样例后均直接恢复固定当前步骤；原厦门任务已还原 |
| 2026-08-13 | 阶段六：交通写入日历 | 代码完成 | `TravelTransportCalendarEvent.ets`、`HuaweiCalendarClient.ets`、`TravelTransportCalendarSurface.ets`；任务schema升级到v6 | 仅允许已确认交通写入；保存真实事件ID；使用`taskId + legId`查询并更新已有事件；成功后进入酒店搜索步骤；中断、失败和权限异常保留真实重试状态 |
| 2026-08-13 | 阶段六：自动化验证 | 完成 | Hypium `Tests run: 1973, Failure: 0, Error: 0, Pass: 1973`；最终修复通过测试编译与Debug签名HAP构建并覆盖安装 | 新增交通日程生成、提醒策略、幂等匹配、界面状态、动作身份、schema迁移、状态机及真机样例保护测试；最终修复取消非法的流程倒退，改为直接验证原生幂等更新 |
| 2026-08-13 | 阶段六：真机验收 | 完成 | `docs/evidence/travel-stage6-device-2026-08-13/`；设备`6HR0226506005010`创建系统日历事件并保存真实ID；事件`293`重复写入后仍为`293`；杀进程重启后仍恢复`293` | 真机发现并修复“重复写入验收错误尝试从酒店步骤倒退”的缺陷；最终页面显示“已更新同一事件 293，未创建重复日程”；测试日程已删除，原`G3020`任务已恢复 |
| 2026-08-13 | 阶段七：酒店搜索、详情与选择 | 完成 | `TravelHotelNormalizer.ets`、`TravelHotelSurface.ets`、真实`hotel.search`/`hotel.detail`接入；Hypium `Tests run: 1983, Failure: 0, Error: 0, Pass: 1983`；`docs/evidence/travel-stage7-device-2026-08-13/` | 真机发现并修复 A2UI 信息行路径未渲染缺陷；真实 RollingGo 搜索、详情、返回、房型选择及覆盖安装重启恢复通过；预订URL不持久化，阶段八再接入当前流程的真实预订承接与返回核验 |
| 2026-08-13 | 阶段八：酒店预订承接与返回核验 | 完成 | `TravelHotelBookingProvider.ets`、`TravelHotelBookingSurface.ets`；任务schema升级到v8；Hypium `Tests run: 1992, Failure: 0, Error: 0, Pass: 1992`；Debug HAP构建成功；`docs/evidence/travel-stage8-device-2026-08-13/` | 真机完成“打开RollingGo → 返回订单核验 → 无接口明确提示 → 本次没有完成”闭环；修复酒店预订动作与旧注册动作冲突，以及核验结果在首屏不可见的问题；用户确认和供应商确认分支由自动化测试覆盖；DevEco覆盖率JSON生成器仍有既有解析告警，不影响测试结果文件 |
| 2026-08-13 | 阶段九：酒店写入日历与流程收尾 | 完成 | `TravelHotelCalendarEvent.ets`、`TravelHotelCalendarSurface.ets`、`TravelFlowFinishSurface.ets`；Hypium `Tests run: 1992, Failure: 0, Error: 0, Pass: 1992`；Debug HAP构建成功 | 酒店日历写入使用`taskId + stayId`幂等键，保留真实事件ID、订单证据和地址；成功后只在当前对话显示完成结果，支持查看日历、继续处理未完成项和完成归档 |
| 2026-08-13 | 阶段九：真机验收 | 完成 | `docs/evidence/travel-stage9-device-2026-08-13/`；设备`6HR0226506005010`运行“验收阶段九酒店日历流程”样例，酒店日历事件ID为`294` | 真机完成“加入系统日历 → 完成并归档 → 杀进程重启”；完成页分别显示交通/酒店已加入日历及事件ID，归档后重启回到普通首页且无常驻出差卡；“清理阶段九酒店日历样例”已执行并恢复原酒店核验现场 |
| 2026-08-13 | 阶段十：到达目的地解析、导航与打车承接 | 部分完成，真机主动作通过 | `TravelArrivalResolver.ets`、`TravelArrivalSurface.ets`、`Index.ets` 到达请求路由；`ToolGatewayClient.ets` 支持起终点直传坐标；`assembleHap` 构建成功；新增到达解析与界面测试已完成 ArkTS 编译；设备`6HR0226506005010`运行阶段十样例 | 真机成功读取“阶段九验收酒店”（上海市浦东新区世纪大道1号），展示“导航到酒店/查看打车价格”；导航跳转Petal Maps并返回Appless后上下文保留；打车估价页显示“当前位置 → 阶段九验收酒店”、4种车型和示例价格；未点击“确认叫车”，未产生真实订单；实时系统日历查询、坐标缺失时地名解析、真实叫车/司机/取消和完整门禁仍未完成 |
| 2026-08-13 | 交通工具执行前预检 | 代码完成 | `TravelIntentResolver.ets`、`MultiAgentLeaderPlanner.ets`；新增解析、Leader决策与Canary终态测试通过；Debug签名HAP构建成功 | 模型仍负责理解意图和选择工具；宿主只在执行前校验具体日期、出发地、目的地且不改写完整原始query。真机日志发现并修复预检追问保留`requestedCapabilityIds`导致`LEADER_UNOBSERVED_TERMINAL`的问题。全量Hypium为`Tests run: 2013, Failure: 2, Error: 0, Pass: 2011`；剩余失败是既有酒店日历文案与到达候选按钮断言，和本项文件无关；修复包待真机复核 |
| 2026-08-13 | 携程航班预订深链与App内承接 | 代码完成 | `TravelBookingProvider.ets`按已选机场码和日期生成携程单程结果页；`CheckoutWebOverlay.ets`新增携程App内WebView、安全域名限制和已选航班上下文；Debug签名HAP构建成功 | 携程没有稳定的单航班公开深链，因此地址携带航线和日期，App页头固定展示已选航班号供用户核对；返回后恢复交通订单核验步骤。新增深链参数、恶意URL和WebView导航测试已通过ArkTS编译；全量Hypium执行器在报告落盘前持续无输出，已停止，既有两条无关失败仍单独记录。 |
| 2026-08-14 | 旅行搭子航班卡直达携程 | 代码完成 | `A2uiFlightData`保留机场码与日期；`HtmlHomeSnapshot.ets`和`FlightBoardView.ets`均新增“去携程订票”；`Index.ets`校验当前真实航班行后在App内打开携程；Debug签名HAP构建成功 | 修复旅行搭子`flight.search`结果只显示“固定到桌面”的旧链路；航班号、航线、日期继续显示在App安全页头，关闭后原地返回航班结果，不误恢复其他出行任务。 |
| 2026-08-14 | 移除旧出差任务架构 | 代码完成 | 删除 `TravelTask`、`TravelIntentResolver`、专用 Store/Orchestrator/Surface 及对应测试；新增 `TravelSearchPreflight.ets` | 模型通过通用 `recentMessages` 理解多轮信息；宿主仅在交通工具执行前校验日期、出发地、目的地，不再生成或恢复出差任务界面。 |
