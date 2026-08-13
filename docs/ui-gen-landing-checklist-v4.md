# Appless 生成式 UI v4：落地执行清单

状态：v4 execution checklist / 2026-08-13
方案文档：`docs/ui-gen-refactor-plan-v4.md`
当前实施记录：`docs/ui-gen-landing-checklist.md`

本轮执行状态：PR-V4-0 Node 验收通过；PR-V4-1/1A/1B 已建立首批宿主无关契约代码，主 UI 未接入。Hypium、真机和完整 ArkTS 构建待设备/IDE 环境执行。

---

## 0. 执行原则

- 保留 v3 当前工作区变更，不覆盖、不回退已通过的 Phase 1 实现。
- 先完成当前真机验收，再切换内部状态模型。
- 每个 PR 只跨一个主要边界，必须可独立回滚。
- 每个宿主都必须先 shadow/double-write 再切可见路径；初期只有 UI Lab shadow，主 UI 延后到 PR-V4-12。
- JSON 生产路径在 UI Lang 达到灰度门槛前始终保留。
- 新增类型不得继续扩大 `A2uiComponent` 和 `A2uiSurfaceState` 的职责。
- 所有模型输出必须先验证并 canonicalize，禁止直接进入 Renderer。
- 用户编辑与敏感 Action 的正确性优先于 confirm 率和首屏速度。
- 新增 Tool/Provider/intent 不得默认新增 UI Component；先验证能否映射为既有 Semantic View Model。
- 模型主要使用 Semantic Catalog；Foundation 用于组合，Extension 必须单独评审准入。
- v4 Core 必须位于 `agent_core` 并保持宿主无关，不依赖 UI Lab、主页面或具体 `MultiAgentCanaryRuntime` class。
- `UiRunCoordinator` 位于现有 MultiAgent/Capability Runtime 下游，只协调 UI session，不重复任务规划、Tool 执行或真实 Action 执行。
- UI Lab 是 v4 初期唯一消费者；主 UI 在 Lab 退出门槛满足前继续使用现有 legacy pipeline，不接 v4 双写。
- v4 按 `ui_lab_legacy → ui_lab_v4_shadow → ui_lab_v4_visible` 逐步切换，每一步必须可独立回退。

---

## 1. 当前基线与冻结项

### 1.1 已完成，v4 不重复实现

| 能力 | 当前锚点 | v4 处理 |
| --- | --- | --- |
| SSE + 增量 UTF-8 解码 | `agent_core/src/main/ets/a2ui/OpenAiA2uiModel.ets` | 保留，接入 adapter 接口 |
| updateComponents 流式扫描 | `agent_core/src/main/ets/a2ui/A2uiUpdateComponentsStreamScanner.ets` | 作为 JSON adapter 底层 |
| 快速 intent 骨架 | `agent_core/src/main/ets/aiphone/skeleton/SkeletonPlanner.ets` | 保留，输出改接 Candidate/Runtime Overlay |
| 同 Surface ID 复用 | `UiAgent` + `Index.seedFastSubmissionSkeleton()` | 保留 |
| patch/reconcile | `A2uiSurfaceStore.ets` | 兼容期保留，逐步迁往 v4 Reconciler |
| 闭合树流式投影 | `StreamedLayoutProjection.ets` | 迁入 Compiler/Validator |
| 流式 Candidate 合并 | `StructuredToolUiRenderer.ets` | 拆分职责，不重写业务 baseline |
| WebView phase patch | `NodeRenderStatePatch.ets` + `HtmlHomeSurfaceView.ets` | 扩展为通用 ChangeSet |
| ArkUI shimmer | `A2uiNodeView.ets` | 改读 Render Projection phase |
| generation/lease gate | `Index.ets`、`UiAgent`、Runtime writer | 纳入 epoch/revision gate |
| MultiAgent/Capability Runtime | `MultiAgentCanaryRuntime.ets`、`capability/runtime/` | 继续负责 Agent、Tool 和 Action；v4 只通过 Host Ports 消费结果 |
| UI Lab WebView 与固定 Renderer | `UiAgentLab.ets`、`UiAgentLabHtml.ets` | 作为 v4 第一个宿主和 WebView Renderer 迁移基线，不在 core 中重写页面壳 |

### 1.2 当前未完成，必须先收口

- [ ] 真实 SSE 页面真机跑通。
- [ ] 采集至少三类主场景的 confirm/replace/insert/remove 数据。
- [ ] 验证旧 turn 晚到和新 turn 抢占。
- [ ] 演练 SSE 断流和 provider error。
- [ ] BIM route takeover 回归。
- [ ] multi-task surface 回归。
- [ ] 记录实际 first meaningful paint，而非仅 Store seed 时间。
- [ ] 明确 HTML insert/move：实现或长期回退 full projection reload。
- [ ] 盘点当前场景组件及其直接绑定的 Tool/Provider schema，形成 legacy → semantic 迁移表。

完成门槛：当前 `docs/ui-gen-landing-checklist.md` 的 PR-5 尚未完成项全部有结果记录。

---

## 2. 目标目录

以下为建议的新目录；具体导出入口同步到 `agent_core/Index.ets`：

```text
agent_core/src/main/ets/aiphone/ui/
├── host/
│   ├── UiRuntimeHostPorts.ets
│   ├── UiRuntimeHostTypes.ets
│   └── UiSurfaceRequest.ets
├── catalog/
│   ├── UiCatalog.ets
│   ├── UiCatalogItem.ets
│   ├── UiCatalogPromptBuilder.ets
│   ├── UiCatalogRegistry.ets
│   ├── foundation/
│   │   └── FoundationCatalog.ets
│   ├── semantic/
│   │   └── SemanticCatalog.ets
│   └── extensions/
│       ├── CalendarCatalog.ets
│       ├── MapsCatalog.ets
│       ├── TravelCatalog.ets
│       ├── MailCatalog.ets
│       ├── PaymentCatalog.ets
│       └── MediaCatalog.ets
├── presentation/
│   ├── UiPresentationTypes.ets
│   ├── UiPresentationAdapter.ets
│   ├── UiPresentationAdapterRegistry.ets
│   └── adapters/
│       ├── ChoicePresentationAdapters.ets
│       ├── JourneyPresentationAdapters.ets
│       ├── MessagingPresentationAdapters.ets
│       └── StatusPresentationAdapters.ets
├── compiler/
│   ├── UiModelOutputAdapter.ets
│   ├── A2uiJsonOutputAdapter.ets
│   ├── ApplessUiLangOutputAdapter.ets
│   ├── ApplessUiLangParser.ets
│   ├── UiCandidateValidator.ets
│   └── UiCanonicalizer.ets
├── ir/
│   ├── UiCanonicalTypes.ets
│   ├── UiBindingTypes.ets
│   ├── UiMutationTypes.ets
│   └── UiRevisionTypes.ets
├── runtime/
│   ├── UiRunCoordinator.ets
│   ├── UiSurfaceController.ets
│   ├── UiLayoutStore.ets
│   ├── UiDataModelStore.ets
│   ├── UiRuntimeOverlayStore.ets
│   ├── UiUserOverlayStore.ets
│   ├── UiReconciler.ets
│   └── LegacyA2uiSurfaceAdapter.ets
├── events/
│   ├── AgentUiEventTypes.ets
│   ├── UiEventTypes.ets
│   ├── UiActionOfferStore.ets
│   └── UiActionRouter.ets
├── speculation/
│   ├── UiLayoutCache.ets
│   ├── UiLayoutTemplate.ets
│   └── UiPredictionMetrics.ets
└── render/
    ├── UiRenderProjection.ets
    └── UiRenderChangeSet.ets

entry/src/main/ets/pages/A2uiHome/lab/v4/
├── UiLabV4HostAdapter.ets
├── UiLabV4RuntimeFactory.ets
├── UiLabV4ProjectionBridge.ets
└── UiLabV4FeatureFlags.ets
```

测试建议：

```text
entry/src/test/UiCanonicalIr.test.ets
entry/src/test/UiCatalog.test.ets
entry/src/test/UiPresentationAdapters.test.ets
entry/src/test/UiCompiler.test.ets
entry/src/test/ApplessUiLangParser.test.ets
entry/src/test/UiReconcilerV4.test.ets
entry/src/test/UiRevisionGate.test.ets
entry/src/test/UiOverlay.test.ets
entry/src/test/UiLayoutCacheV4.test.ets
entry/src/test/UiActionRouter.test.ets
entry/src/test/UiRenderProjection.test.ets
entry/src/test/UiRunCoordinator.test.ets
entry/src/test/UiLabV4Integration.test.ets
```

---

## 3. PR-V4-0：当前 Phase 1 验收收口

目标：冻结可工作的旧主链，形成 v4 迁移基线。

### 修改/补充

- [ ] 在 `Index.ets` 增加实际 Web/ArkUI 首次 paint 回调打点。
- [ ] 将 `A2uiSurfaceStore.getStats()` 接到当前 turn 终态指标。
- [ ] 为断流路径记录 `fallbackReason`，区分 timeout/scanner/provider/validation。
- [ ] 记录 HTML full reload 次数和 node patch 次数。
- [ ] 将真机证据回写当前 landing checklist，不回写 v4 设计假设。

### 测试

- [x] 现有 `scripts/ui-gen-pipeline.test.mjs` 全绿（本轮 9/9）。
- [x] `scripts/node-render-patch.test.mjs` 全绿（本轮 6/6）。
- [x] `scripts/patch-concurrency.test.mjs` 全绿（本轮 3/3）。
- [x] `scripts/streamed-layout-projection.test.mjs` 全绿（本轮 6/6）。
- [ ] Hypium 全量无新增失败。
- [ ] 真机：travel、food、status 各至少 10 次。
- [ ] 真机：断流、401、旧 turn、BIM takeover、multi-task。

### 退出门槛

- [ ] `firstMeaningfulPaint` 有可复现数据。
- [ ] confirm precision 可计算，不仅有 confirm 数量。
- [ ] 当前 JSON 生产路径形成可回滚基线 tag/commit。

---

## 4. PR-V4-1：Canonical IR 与基础类型

目标：建立新模型，但不改变生产渲染行为。

### 新增

- [ ] `UiCanonicalTypes.ets`：Surface、Node、CatalogRef、nodeKey。
- [ ] `UiBindingTypes.ets`：business/local/agent binding。
- [ ] `UiRevisionTypes.ets`：epoch + layout/data/runtime/user revisions。
- [ ] `UiMutationTypes.ets`：Layout/Runtime/Data/User mutation。
- [ ] `LegacyA2uiSurfaceAdapter.ets`：旧 Surface ↔ 新 snapshot 的兼容映射。

### 约束

- [ ] Canonical Node 不得包含 `renderState/pinned/hidden/orderHint`。
- [ ] Canonical Node 不得包含 runtimeOwner/runtimeGeneration。
- [ ] `nodeKey` 与 `surfaceId` 解耦。
- [ ] 内部 `schemaVersion` 与 `A2UI_VERSION` 解耦。
- [ ] 自定义 `patchComponents` 在注释和文档中标记为 internal/legacy extension。

### 测试

- [ ] 现有典型 `A2uiSurfaceState` 可无损转成 v4 snapshot，再 materialize 为等价 legacy view。
- [ ] Canonical serialization 稳定。
- [ ] Canonicalization 两次执行结果相同。
- [ ] runtime/user 字段不会进入 canonical fingerprint。

### 退出门槛

- [ ] 无生产调用点切换。
- [ ] 所有旧测试保持全绿。
- [ ] 20 个代表性 surface 完成 golden snapshot。

---

## 4A. PR-V4-1A：三层 Catalog 与 Presentation View Model

目标：先建立通用组件和标准展示数据契约，阻止场景组件继续扩散；不立即替换现有 Renderer。

### Catalog 基础

- [ ] 新增 `UiCatalogItem.ets`，包含 `layer/groups/version/propsSchema/positionalFields/childPolicy/rendererKey/allowedEvents`。
- [ ] 新增 `UiCatalog.ets` 和 `UiCatalogRegistry.ets`。
- [ ] 建立 `FoundationCatalog.ets`。
- [ ] 建立 `SemanticCatalog.ets`。
- [ ] Extension Catalog 按需注册，不默认注入 Prompt。
- [ ] 生成 `catalogVersion` 和 `capabilityHash`。

### Foundation 首版

- [ ] `Surface/Stack/Row/Grid/Card`。
- [ ] `Text/Icon/Image/Badge/Divider/Progress/Spacer`。
- [ ] `Button/Tabs`。

### Semantic 首版

- [ ] `ResultCollection/ChoiceList/OptionCard/JourneyOptionList`。
- [ ] `ComparisonTable/KeyValueList/MetricGrid`。
- [ ] `Timeline/Schedule`。
- [ ] `MessageFeed/ThreadList/DetailPanel`。
- [ ] `Form/FormField/FilterBar/ActionBar`。
- [ ] `ApprovalPanel/AccountStatus/StatusNotice/ActivityFeed/MediaGallery`。

### Presentation View Model

- [ ] 新增 `UiPresentationTypes.ets`。
- [ ] 定义 `UiOptionItem/UiOptionCollection`。
- [ ] 定义 `UiKeyValueItem/UiKeyValueGroup`。
- [ ] 定义 `UiMessageItem/UiMessageThread`。
- [ ] 定义 `UiJourneyOption`。
- [ ] 定义 `UiTimelineItem/UiMetricItem/UiStatusValue/UiMediaRef`。
- [ ] 定义 `UiFormModel/UiApprovalModel`。
- [ ] 所有 View Model 都有稳定 schema version。

### Adapter 接口

- [ ] 新增 `UiPresentationAdapter.ets`。
- [ ] 新增 `UiPresentationAdapterRegistry.ets`。
- [ ] Adapter 输入保持原 Tool Result 和 provenance；输出只包含验证过的 View Model。
- [ ] Adapter 不调用 LLM、不执行 Tool、不生成布局、不生成 Action Offer。
- [ ] Action 只引用已签发 offerId。

### 首批映射

- [ ] Food Provider results → `UiOptionCollection`。
- [ ] Hotel results → `UiOptionCollection`。
- [ ] Product/shopping results → `UiOptionCollection`。
- [ ] Train/Flight/Travel results → `UiJourneyOption[]`。
- [ ] Mail/Social results → `UiMessageItem[]`。
- [ ] Generic structured result → 已知 View Model；无法映射时才进入 `ResultCollection` fallback。

### Extension 准入

每个 Extension PR 必须填写：

- [ ] 为什么 Foundation/Semantic + View Model 无法表达。
- [ ] 独特交互状态机、平台能力或复杂布局算法是什么。
- [ ] 安全差异为什么不能仅由 ActionRouter/ApprovalPanel 表达。
- [ ] Renderer、无障碍、测试和降级路径。
- [ ] 是否可被至少两个场景复用；若不能，说明硬性领域理由。

以下差异不得作为 Extension 理由：

- [ ] 仅字段名不同。
- [ ] 仅 Provider/Tool 不同。
- [ ] 仅文案、颜色、图标或排列不同。
- [ ] 仅 intent 名称不同。

### Legacy 迁移表

- [ ] `FoodChoices` → `ChoiceList`。
- [ ] `TrainOptions/FlightBoard/TravelOptions` → `JourneyOptionList` 或 `ChoiceList`。
- [ ] `InfoRows` → `KeyValueList`。
- [ ] `SocialHub` → `MessageFeed` + 通用 `AccountStatus/StatusNotice`。
- [ ] `ConfirmPanel` → `ApprovalPanel`。
- [ ] `ThinkingStream` → `ActivityFeed`。
- [ ] `ErrorNotice` → `StatusNotice`。
- [ ] `ScheduleStack` → `Schedule/Timeline`。
- [ ] `StripeReceivingAccountCard` → `AccountStatus` + 必要 `PaymentSummary` Extension。

### 测试

- [ ] Catalog schema 与 Prompt signature 来自同一 `UiCatalogItem`。
- [ ] Foundation/Semantic/Extension group 选择稳定。
- [ ] Food/Hotel/Product 映射为同一 `UiOptionCollection` schema。
- [ ] Train/Flight 映射为同一 `UiJourneyOption` schema。
- [ ] Mail/Social 映射为同一 `UiMessageItem` schema。
- [ ] Adapter 保留 provenance，不伪造缺失字段。
- [ ] Action Offer identity 不被 Adapter 改写。
- [ ] legacy 和 semantic Renderer 输出完成 golden 对照。

### 退出门槛

- [ ] 首批五类 View Model schema 冻结。
- [ ] 新增 Tool 的默认接入说明改为“先写 Presentation Adapter”。
- [ ] 新 Prompt 可只暴露 Foundation + Semantic groups。
- [ ] legacy 场景组件仍可回退，但不再作为新功能默认选择。

---

## 4B. PR-V4-1B：宿主边界、UiRunCoordinator 与 UI Lab 首接

目标：建立宿主无关的 v4 UI Runtime 入口，让 UI Lab 成为第一个且初期唯一消费者；不改变主 UI。

### Core Host Ports

- [ ] 新增 `UiRuntimeHostTypes.ets` 和 `UiSurfaceRequest.ets`。
- [ ] 新增 `UiRuntimeHostPorts.ets`，定义 Agent Event、Tool Result、Action Offer、UI model stream 和 Action sink 边界。
- [ ] Host Ports 不引用 `MultiAgentCanaryRuntime`、ArkUI Page、WebView Controller 或 UI Lab 类型。
- [ ] v4 Core 不导入 `entry/` 下任何文件。
- [ ] Host Tool Result 只携带必要 payload、schema identity、provenance 和 correlation identity。

### UiRunCoordinator

- [ ] 新增 `UiRunCoordinator.ets`。
- [ ] 负责 `runId/surfaceId/epoch` 和一次 UI session 生命周期。
- [ ] 协调 Presentation Adapter、模型输出 Adapter、Speculation、Reconciler、Store 和 SurfaceController。
- [ ] 接收 Agent Event，但不规划任务或选择 Tool。
- [ ] 接收 Tool Result，但不执行 Tool。
- [ ] 接收 Action Offer 和 UiEvent，但真实 Action 通过 host action sink 交还现有 Runtime。
- [ ] 不新增 Leader、DataAgent、Tool Executor、ApprovalBroker 或第二套 Conversation Runtime。

### UI Lab Adapter

- [ ] 新增 `UiLabV4HostAdapter.ets`，把现有 `MultiAgentCanaryRuntime` 输出转换为 v4 Host Ports。
- [ ] 新增 `UiLabV4RuntimeFactory.ets`，只负责组装依赖，不在页面内 new 全部 v4 模块。
- [ ] 新增 `UiLabV4ProjectionBridge.ets`，将 v4 Render Projection 推送给现有 UI Lab WebView。
- [ ] 新增 `UiLabV4FeatureFlags.ets`。
- [ ] 支持 `ui_lab_legacy`、`ui_lab_v4_shadow`、`ui_lab_v4_visible`。
- [ ] UI Lab legacy fallback 不依赖 v4 Store 的可用性。

### 主 UI 隔离

- [ ] 主页面 `Index.ets` 的现有 UI submit/render/action 路径不接 v4。
- [ ] 现有主 UI `A2uiSurfaceStore` 不写入 v4 shadow Store。
- [ ] 主 UI 不读取 v4 Catalog、Store、Cache 或 Projection。
- [ ] 本 PR 不新增主流程 feature flag。
- [ ] 用依赖检查阻止 `entry/.../lab` 被 `agent_core/.../ui` 反向引用。

### 测试

- [ ] 使用 fake host 验证 UiRunCoordinator，不启动 MultiAgent Runtime。
- [ ] 同一 Host Event 重放不会重复创建 Surface。
- [ ] Tool Result、模型 delta 和 Agent Event 乱序时结果确定。
- [ ] UiEvent 只经 host action sink 返回，不在 UiRunCoordinator 内执行 Tool。
- [ ] UI Lab `legacy` 模式 snapshot 与改造前一致。
- [ ] UI Lab `v4_shadow` 不改变可见 Surface。
- [ ] 主 UI golden、工具调用次数和 Action 执行次数保持不变。

### 退出门槛

- [ ] v4 Core 通过无 UI Lab/无页面依赖构建检查。
- [ ] UI Lab 能独立选择 legacy 或 v4 shadow。
- [ ] 主 UI 无 v4 新调用点，行为和指标无变化。
- [ ] 设计评审确认 UiRunCoordinator 没有复制 MultiAgent Runtime 职责。

---

## 5. PR-V4-2：四 Store 与 SurfaceController shadow 模式

目标：在 UI Lab 内将 Layout、Data、Runtime Overlay、User Overlay 分离，但 UI Lab legacy Renderer 继续作为可见结果；主 UI 不接入。

### 新增

- [ ] `UiLayoutStore.ets`。
- [ ] `UiDataModelStore.ets`。
- [ ] `UiRuntimeOverlayStore.ets`。
- [ ] `UiUserOverlayStore.ets`。
- [ ] `UiSurfaceController.ets`。

### 接线

- [ ] UI Lab legacy `A2uiSurfaceStore.apply()` 成功后，通过 Host Adapter shadow 写入新 SurfaceController。
- [ ] 新 Controller materialize legacy view，与当前 UI Lab Surface 做 snapshot compare。
- [ ] mismatch 仅记录，不影响用户界面。
- [ ] 对 mismatch 分类：canonical、data、phase、user overlay、revision。
- [ ] 不修改主 UI `A2uiSurfaceStore.apply()` 调用点。

### 迁移规则

- [ ] `renderState` → Runtime Overlay phase。
- [ ] `pinned/hidden/orderHint` → User Overlay。
- [ ] `dataModelJson` 中供 UI 绑定的数据 → 经验证的 Presentation View Model → DataModel Store。
- [ ] Tool/Provider 原始结果继续留在 Tool/Agent 域，不作为 Semantic Component 的直接 binding schema。
- [ ] DataModel Store 记录 `viewModelType/schemaVersion/provenance`，支持按标准类型校验 path。
- [ ] `components/rootId/title/intent` → Layout Store；title/intent 是否属于 layout 必须以 ADR 固定。
- [ ] 兼容 view 在 Renderer 迁移前继续填回旧字段。

### 测试

- [ ] shimmer → confirmed → hydrated 独立改变 runtime revision。
- [ ] Data path 更新不改变 layout revision。
- [ ] pin/hide/order 不改变 canonical fingerprint。
- [ ] authoritative replace 后兼容用户编辑保留。
- [ ] 被删除节点的 user overlay 进入 orphan retention。

### 退出门槛

- [ ] UI Lab shadow compare 在全部现有自动场景中 100% 可解释。
- [ ] 不允许存在未分类 mismatch。
- [ ] 主 UI 未产生 v4 mutation、Store 或日志事件。

---

## 6. PR-V4-3：Revision Gate、幂等与 Snapshot

目标：替换单 sequence 的混合并发语义。

### 新增

- [ ] `UiSurfaceRevision`。
- [ ] `UiMutationMeta`。
- [ ] mutationId dedupe ring/LRU。
- [ ] baseRevision gate。
- [ ] Surface snapshot export/import。
- [ ] rejection reason codes。

### 与现有 gate 对接

- [ ] UI Lab Host Adapter 将现有 `runtimeGeneration` 映射为 epoch，兼容期不删除。
- [ ] UI Lab host generation/lease 校验后再进入 revision gate。
- [ ] UI Lab legacy `applySurface()` sequence gate 保留到 `ui_lab_v4_visible` 稳定。
- [ ] 主 UI 的 generation/lease/sequence gate 在本阶段保持不变。
- [ ] layout/data/runtime/user mutations 分别比较对应 revision。

### 必测交错

- [ ] old epoch layout after new epoch skeleton。
- [ ] data revision 3 before data revision 2。
- [ ] duplicate mutationId。
- [ ] layout baseRevision mismatch。
- [ ] user edit between speculative and authoritative layout。
- [ ] snapshot restore 后重复接收最后一个 mutation。
- [ ] tool data 先于节点到达。

### 退出门槛

- [ ] 所有并发结果确定且可重放。
- [ ] 每个拒绝有稳定 reason code 和测试。

---

## 7. PR-V4-4：UI Compiler 与 A2UI JSON Adapter

目标：先让 UI Lab 的现有 JSON 链路 shadow 通用 Compiler，不改变模型输出和主 UI。

### 新增

- [ ] `UiModelOutputAdapter.ets`。
- [ ] `A2uiJsonOutputAdapter.ets`，复用现有 scanner。
- [ ] `UiCandidateValidator.ets`。
- [ ] `UiCanonicalizer.ets`。
- [ ] `UiCompileError` 与 source span/reason code。

### Catalog 与数据契约

- [ ] Validator 只接受当前请求选中的 Foundation/Semantic/Extension Catalog groups。
- [ ] Canonical binding 的目标 path 必须属于已注册的 Presentation View Model schema。
- [ ] Candidate 不得引用 Tool/Provider 原始字段路径。
- [ ] legacy 场景组件只允许通过兼容 Adapter 进入，不接受新模型输出。
- [ ] Compiler 输出记录 `catalogVersion`、`viewModelSchemaVersion` 和 Adapter provenance。

### 从现有文件迁移职责

- [ ] `StreamedLayoutProjection` 的闭合树逻辑进入 Validator/Projector。
- [ ] `projectLayoutCandidate()` 的 Catalog/路径校验进入 Validator。
- [ ] `mergeA2uiLayout()` 中纯语义规范化部分进入 Canonicalizer。
- [ ] `restoreCanonicalComponentActions()` 改为 Action Offer 绑定步骤。
- [ ] `streamedPatchJsonl()` 不再是核心入口；Candidate 进入 v4 Reconciler。

### 兼容路径

```text
模型 JSON
  → A2uiJsonOutputAdapter
  → Validator
  → Canonicalizer
  → UI Lab v4 Reconciler shadow
  → LegacyA2uiSurfaceAdapter
  → UI Lab 当前 WebView Renderer
```

### 测试

- [ ] SSE 每种 chunk boundary。
- [ ] UTF-8 中文跨 chunk。
- [ ] 重复 id、环、孤儿节点、未知 root。
- [ ] 未知组件/字段、非法 binding/action。
- [ ] 部分合法、尾部断流。
- [ ] 当前 UI Lab JSON golden cases canonical fingerprint 不变。
- [ ] 主 UI 生产 JSON 不进入 v4 Compiler。

### 退出门槛

- [ ] UI Lab JSON 路径可切 feature flag 到 v4 Compiler。
- [ ] 关闭 UI Lab flag 可完整回退旧 Lab 路径。
- [ ] 主 UI 仍无 v4 Compiler feature flag。

---

## 8. PR-V4-5：Appless UI Lang Parser PoC

目标：借鉴 OpenUI Lang，在 UI Lab 验证紧凑模型语言；主 UI 继续使用现有 JSON。

### 语言冻结

- [ ] 完成首版 EBNF。
- [ ] 确认 positional prop 顺序由 Catalog 唯一决定。
- [ ] 支持 component call、array、literal、reference、binding、ActionRef。
- [ ] 支持 root first 和 forward reference。
- [ ] 支持 identifier 重新赋值形成 Candidate Program revision。
- [ ] 明确禁止 Query/Mutation、任意函数、表达式和脚本。

### 新增

- [ ] `ApplessUiLangToken.ets`。
- [ ] `ApplessUiLangLexer.ets`。
- [ ] `ApplessUiLangParser.ets`。
- [ ] `ApplessUiLangProgram.ets`。
- [ ] `ApplessUiLangOutputAdapter.ets`。
- [ ] `UiCatalogPromptBuilder.ets`。

### Parser 要求

- [ ] 每行闭合即可提交 statement。
- [ ] 字符串、转义、中文、数字、布尔和 null 正确。
- [ ] forward reference pending set 有界。
- [ ] identifier/statement/stream 长度有上限。
- [ ] 未知组件在 Validator 拒绝。
- [ ] 最近合法 Candidate 可在断流后继续使用。
- [ ] 错误包含行、列、statement id 和 reason code。

### Catalog Prompt

- [ ] 从 Catalog 生成组件签名。
- [ ] required props 在前、optional props 在后。
- [ ] 根据 `taskShape + 已知 View Model + renderer capability + policy` 选择 Foundation/Semantic groups。
- [ ] Extension 仅在能力确实需要且已注册时注入，不按 Tool/Provider 名称自动选择。
- [ ] 已迁移的 legacy 场景组件不再注入新 Prompt。
- [ ] 自动注入 root、streaming、binding、ActionRef 规则。
- [ ] 示例与 Catalog 版本绑定。

### Golden cases

- [ ] travel search。
- [ ] food choices。
- [ ] status report。
- [ ] mail list/detail/draft。
- [ ] calendar search/confirm create。
- [ ] multi-task board。
- [ ] error/auth required。
- [ ] UI Lab dashboard/chart/list。

每个 case 必须满足：

```text
JSON input → Canonical IR
UI Lang input → Canonical IR
两者 fingerprint 相等
```

并额外满足：

- [ ] food/hotel/product 使用同一 `UiOptionCollection + ChoiceList` 契约。
- [ ] train/flight 使用同一 `UiJourneyOption` 契约。
- [ ] Prompt 和 Candidate 中不出现已迁移的 legacy 场景组件名。

### 离线 A/B

- [ ] 至少 100 条真实匿名化 prompt。
- [ ] 至少两个云模型档位。
- [ ] 若有可用小模型，再加入一个小模型档位。
- [ ] 记录 token、首个合法 Candidate、完整 Surface、语法/语义失败和修复率。

### 退出门槛

- [ ] Canonical equivalence ≥ 99%。
- [ ] 高风险 action case 为 100%。
- [ ] 输出 token 或 first valid candidate 至少一项显著优于 JSON。
- [ ] 尚不改变默认生产格式。
- [ ] UI Lang 仅能由 UI Lab feature flag 启用，主 UI 不可见。

---

## 9. PR-V4-6：Reconciler v4 与 Prediction Metrics

目标：先在 UI Lab v4 Runtime 中正式将 confirm 从 layout patch 中抽离。

### 新增

- [ ] `UiReconciler.ets`。
- [ ] canonical semantic signature。
- [ ] nodeKey-based match。
- [ ] LayoutMutation/RuntimeMutation 输出。
- [ ] `UiPredictionMetrics.ets`。

### 规则

- [ ] 相同 nodeKey + signature → `markConfirmed`。
- [ ] 相同 nodeKey + signature 不同 → `upsertNode + markConfirmed`。
- [ ] authoritative 新 nodeKey → `upsertNode + markConfirmed`。
- [ ] authoritative 缺失 speculative nodeKey → `removeNode`。
- [ ] 用户 overlay 在 commit 后重新投影。
- [ ] renderer-specific 字段不参与 signature。

### 兼容

- [ ] 旧 `patchComponents.confirm` 映射 RuntimeMutation。
- [ ] 旧 Store 继续可接收由 adapter materialize 的 patch。
- [ ] 新指标与旧 getStats 同时输出一个灰度周期。

### 指标

- [ ] predictionCoverage。
- [ ] confirmPrecision。
- [ ] replacementRate。
- [ ] insertMissRate。
- [ ] userOverlayRetention。

### 退出门槛

- [ ] confirm precision = 100%。
- [ ] 所有误差都表现为 replace/insert/remove，而不是错误 confirm。
- [ ] 指标只来自 UI Lab v4 session，不与主 UI legacy 指标混记。

---

## 10. PR-V4-7：LayoutCache v4

目标：在 UI Lab 的状态分层后实现真正可用的投机缓存；主 UI 不读写该缓存。

### 新增

- [ ] `UiLayoutTemplate.ets`。
- [ ] `UiLayoutCache.ets`。
- [ ] preferences persistence。
- [ ] LRU 与容量控制。
- [ ] semantic task-shape index 和 full-key index。

### Cache Key

- [ ] 快速索引：`taskShape`。
- [ ] 快速索引：`viewModelShapeHash`。
- [ ] 快速索引：`catalogGroupSet`。
- [ ] 快速索引：`viewportClass + locale`。
- [ ] 完整校验：`semanticTemplateKey + presentationAdapterVersion`。
- [ ] 完整校验：`toolSchemaHash + catalogVersion + rendererCapabilityHash`。
- [ ] `intent/Tool/Provider` 名称不得成为跨场景模板的首级分区键。

### Sanitization

- [ ] 移除 surfaceId/wire id，保留 nodeKey。
- [ ] 移除业务数据。
- [ ] 移除 Runtime/User Overlay。
- [ ] 移除 provider 临时身份。
- [ ] 移除 Action Offer 和敏感 args。
- [ ] 绑定只保留 path shape，不保留敏感值。
- [ ] 移除 legacy 场景组件名和 Tool/Provider 专属字段。
- [ ] 只保留标准 Presentation View Model shape reference。

### 接线

- [ ] UI Lab Speculation Coordinator 优先查 cache template。
- [ ] template 重新实例化 wire ids。
- [ ] authoritative 完成后执行准入评估。
- [ ] 首版仅为 UI Lab read-only、低风险 case 启用。
- [ ] 使用独立 cache namespace，主 UI legacy SkeletonPlanner 不读取 v4 条目。

### 测试

- [ ] food/hotel/product 在相同 taskShape 和 View Model shape 下可复用同一模板。
- [ ] 相同 taskShape 但 View Model shape 不兼容时必须 miss。
- [ ] 同 Tool schema 升级由完整 key 正确命中或失效。
- [ ] Catalog 升级自动 miss。
- [ ] viewport/locale 隔离。
- [ ] action offer 不进入缓存。
- [ ] 用户 overlay 不污染下一请求。
- [ ] legacy 场景组件和 Provider 字段不进入缓存。
- [ ] LRU、损坏条目和升级迁移。

### 退出门槛

- [ ] 缓存模板通过安全扫描。
- [ ] 命中后的 confirm precision 不低于规则骨架。
- [ ] first meaningful paint 有统计提升。

---

## 11. PR-V4-8：Agent Event Plane

目标：通过 UI Lab Host Adapter 将现有 Agent 执行生命周期投影到独立 Event Plane，不替换 MultiAgent Runtime。

### 新增

- [ ] `AgentUiEventTypes.ets`。
- [ ] Event reducer/store。
- [ ] snapshot/delta 支持。
- [ ] run/tool/activity/interrupt/error 事件。

### 生产者接入

- [ ] UI Lab Host Adapter 消费 LeaderAgent / MultiAgentRuntime 已有回调。
- [ ] 映射 UiAgent / DataAgent / ActionAgent 生命周期，不修改其调度权。
- [ ] 映射 Tool gateway 调用、Provider error 与 timeout。
- [ ] 映射 ApprovalBroker interrupt/resolve。
- [ ] v4 Event Plane 不反向控制 Agent 调度。

### 消费者接入

- [ ] UI Lab busy/progress 状态。
- [ ] UI Lab Tool activity/debug panel。
- [ ] UI Lab Interrupt/confirm UI。
- [ ] UI Lab 运行结束和错误提示。
- [ ] 主 UI 继续使用现有状态来源。

### 兼容

- [ ] `surface.status` 继续 materialize 一个版本周期。
- [ ] UI 节点不得直接持有整个 Agent Event Store。
- [ ] Tool Result 经注册的 Presentation Adapter 转为标准 View Model 后更新 DataModel；原始 schema 不直达组件。

### 测试

- [ ] run success/error/interrupt。
- [ ] tool call args stream/result。
- [ ] snapshot + delta 重建。
- [ ] 旧事件、重复事件和跨 run 事件。
- [ ] interrupt resume identity。

### 退出门槛

- [ ] UI busy/progress 不再依赖猜测 surface.status。
- [ ] Run 可从事件 snapshot 恢复。

---

## 12. PR-V4-9：UiEvent 与 ActionRouter

目标：先在 UI Lab v4 path 移除以 prompt 为执行契约的 UI Action；真实执行仍交回现有 Runtime。

### 新增

- [ ] `UiEventTypes.ets`。
- [ ] `UiActionOfferStore.ets`。
- [ ] `UiActionRouter.ets`。
- [ ] event/action replay guard。

### Action Offer

- [ ] offerId 唯一且不可由模型生成。
- [ ] actionId、policy、input schema、target identity 由宿主签发。
- [ ] 支持 expiry。
- [ ] 敏感场景绑定当前 run/surface/target。

### Renderer 接线

- [ ] Web bridge 发送结构化 UiEvent。
- [ ] ArkUI action handler 可完成相同 UiEvent 的契约测试，但不接管主 UI。
- [ ] visible label/prompt 不参与执行身份。
- [ ] UI Lang 只允许 `ActionRef(offerId)`。

### 路由

- [ ] local reducer。
- [ ] agent continuation。
- [ ] read tool call。
- [ ] draft action。
- [ ] confirm_required interrupt/approval。
- [ ] agent continuation/tool/approval 最终通过 Host Action Sink 进入现有 MultiAgent/Capability Runtime。
- [ ] UiRunCoordinator 和 ActionRouter 不直接执行 Tool 或外部写操作。

### 高风险测试

- [ ] Gmail reply target 不可替换。
- [ ] Calendar eventId 不可由 label 推断。
- [ ] Payment/ride/social send 必须确认。
- [ ] 重复 eventId 不重复执行。
- [ ] 过期、伪造和跨 Surface offer 拒绝。
- [ ] provider 未明确成功时不显示成功。

### 退出门槛

- [ ] 所有写操作不再依赖 `A2uiAction.prompt`。
- [ ] 高风险 action identity 测试 100% 通过。

---

## 13. PR-V4-10：Renderer Projection 与通用 ChangeSet

目标：先让 UI Lab WebView 消费 runtime-neutral 更新，并完成 ArkUI parity 实现；主 UI 暂不切换。

### 新增

- [ ] `UiRenderProjection.ets`。
- [ ] `UiRenderChangeSet.ets`。
- [ ] projection fingerprint。

### ChangeSet

- [ ] insertNode。
- [ ] replaceNode。
- [ ] removeNode。
- [ ] moveNode。
- [ ] updateProps。
- [ ] updatePhase。

### WebView

- [ ] 从 `NodeRenderStatePatch` 扩展到完整 ChangeSet。
- [ ] parentId/afterNodeId 严格验证。
- [ ] insert/replace HTML 仅由本地 renderer 生成。
- [ ] ChangeSet 失败后受控 full projection reload。
- [ ] 记录 reload reason。

### ArkUI

- [ ] 实现读取 projection phase 的 v4 ArkUI Renderer 或测试宿主，不替换主 UI legacy Renderer。
- [ ] 验证 Data path 依赖节点局部刷新。
- [ ] 验证无关 data/runtime revision 不导致整树 rebuild。

### Parity

- [ ] 相同 projection 在两个 Renderer 的结构、文本、action refs 等价。
- [ ] move/order/user overlay 结果等价。
- [ ] error/empty/loading/hydrated 状态等价。

### 退出门槛

- [ ] UI Lab 普通流式请求首帧后 WebView full reload = 0；恢复 reload 单独计数。
- [ ] v4 ArkUI 测试宿主中，无关数据更新不重建整棵树。
- [ ] 主 UI Renderer 文件无行为切换。

---

## 14. PR-V4-11：UI Lang 灰度

目标：在 UI Lab 中验证 UI Lang 的收益并完成 v4 可见切换；主 UI 默认格式不变。

### Feature Flags

- [ ] `ui_lab_legacy`。
- [ ] `ui_lab_v4_json_shadow`。
- [ ] `ui_lab_v4_json_visible`。
- [ ] `ui_lab_v4_ui_lang_shadow`。
- [ ] `ui_lab_v4_ui_lang_visible`。

### Shadow

- [ ] UI Lab 用户仍看到 legacy 或 v4 JSON 结果。
- [ ] 同请求后台生成 UI Lang 候选。
- [ ] 比较 canonical fingerprint 和指标。
- [ ] 不执行 shadow Action、不调用写工具。
- [ ] 主 UI 请求不触发 UI Lang shadow。

### UI Lab 实验顺序

1. [ ] fixed golden dashboard/chart/list。
2. [ ] status/read-only dynamic Tool。
3. [ ] travel/food read-only result。
4. [ ] 跨 Tool 共用 Presentation View Model。
5. [ ] 带本地筛选的交互页面。
6. [ ] draft/confirm 场景。
7. [ ] 写操作只在 ActionRouter 和 Host Action Sink 完成后评估。

### UI Lab v4 visible 门槛

- [ ] canonical equivalence ≥ 99%。
- [ ] 高风险 action equivalence = 100%。
- [ ] parse + semantic validation failure 不高于 JSON。
- [ ] token 或首个合法 Candidate 有显著收益。
- [ ] fallback 到 JSON/baseline 成功率满足目标。
- [ ] 至少一个完整灰度周期无 P0/P1 安全问题。
- [ ] UI Lab 可一键回退 `ui_lab_legacy`。
- [ ] 主 UI 仍完全运行在 legacy pipeline。

---

## 14A. PR-V4-12：主 UI shadow、canary 与切换

前置条件：PR-V4-0～11 全部退出门槛通过，UI Lab 已稳定运行 `v4_visible` 一个完整实验周期。

目标：在不重复 Tool/Action 副作用的前提下，将已验证的宿主无关 v4 Runtime 接入主 UI。

### 主流程 Host Adapter

- [ ] 新增主 UI Host Adapter，复用与 UI Lab 相同的 `UiRuntimeHostPorts`。
- [ ] Adapter 只转换宿主事件和结果，不复制 Catalog、Compiler、Store 或 Reconciler。
- [ ] 主 UI 与 UI Lab 使用相同 v4 Runtime factory/core configuration，宿主差异仅体现在 capabilities 和 Renderer。

### Feature Flags

- [ ] `main_ui_legacy`。
- [ ] `main_ui_v4_shadow`。
- [ ] `main_ui_v4_canary`。
- [ ] `main_ui_v4_default`。
- [ ] 所有 flag 可独立回退，不依赖持久化数据清理。

### Shadow 安全

- [ ] 用户仍看到 legacy 主 UI。
- [ ] 相同 Tool Result 和 Agent Event 被镜像给 v4，不重复调用 Tool。
- [ ] shadow ActionRouter 永远不调用 Host Action Sink。
- [ ] shadow 不签发新的外部写操作，不显示虚假成功状态。
- [ ] 比较 Surface 语义、View Model、Action identity、首帧和 fallback 指标。

### Canary 顺序

1. [ ] internal/debug 用户。
2. [ ] status/read-only dashboard。
3. [ ] travel/food read-only result。
4. [ ] 多 Tool 聚合。
5. [ ] 本地筛选、展开、排序。
6. [ ] draft/confirm。
7. [ ] 支付、发送、删除等高风险操作。

### 退出门槛

- [ ] 主 UI shadow 不增加 Tool 调用次数或外部副作用。
- [ ] canary 期间可以按 surface/run 独立回退 legacy。
- [ ] 高风险 Action identity、确认、重放保护 100% 通过。
- [ ] 至少一个稳定版本周期后才评估删除 legacy 主链。

---

## 15. 文档与 ADR 清单

- [ ] ADR-001：Canonical UI IR 是内部唯一事实。
- [ ] ADR-002：模型 Candidate 与客户端 Mutation 分离。
- [ ] ADR-003：Foundation/Semantic/Extension Catalog 分层与组件准入。
- [ ] ADR-004：Presentation View Model 与 Tool Adapter 边界。
- [ ] ADR-005：Runtime/User Overlay 分离。
- [ ] ADR-006：Revision 与幂等模型。
- [ ] ADR-007：Appless UI Lang 安全子集。
- [ ] ADR-008：Action Offer 与敏感执行边界。
- [ ] ADR-009：A2UI adapter/version 策略。
- [ ] ADR-010：Agent Event Plane 边界。
- [ ] ADR-011：LayoutCache sanitization、语义键和 privacy。
- [ ] ADR-012：Renderer ChangeSet 与恢复策略。
- [ ] ADR-013：宿主无关 v4 Core、Host Ports 与 UiRunCoordinator 职责边界。
- [ ] ADR-014：UI Lab 首接、主 UI 延后 shadow/canary 的迁移策略。

需要同步的长期文档：

- [ ] `docs/a2ui.md`：区分官方 A2UI 与 Appless internal extension。
- [ ] `docs/current-capabilities.md`：更新 UI Lang/Runtime 可用范围。
- [ ] `docs/quickstart.md`：新增 feature flag 和 debug 指标。
- [ ] `docs/ui-gen-pipeline-sequence.mermaid`：更新为 v4 双状态线。

---

## 16. 每个 PR 的统一门禁

### 代码

- [ ] 无未知 dirty file 被覆盖。
- [ ] 新文件从明确的 `agent_core/Index.ets` 导出。
- [ ] ArkTS API/类型符合目标 SDK。
- [ ] 无模型产物直达 Renderer。
- [ ] 无 secret/provider token 进入 IR、cache、日志或 UI Lang。
- [ ] 新 Tool/Provider 默认通过 Presentation Adapter 接入，没有新增同名场景组件。
- [ ] 新 Extension 有组件准入说明、降级路径和至少一个跨场景复用证明或硬性领域理由。
- [ ] `agent_core/.../ui` 不导入 `entry/`、UI Lab 页面或具体 `MultiAgentCanaryRuntime`。
- [ ] UiRunCoordinator 中没有任务规划、Tool Executor、网络 Tool 调用或真实 Action 执行实现。
- [ ] PR-V4-1～11 不增加主 UI 对 v4 Core 的生产调用点。

### 自动测试

- [ ] 新纯逻辑 Hypium 用例注册进 `List.test.ets`。
- [ ] 相关 Node 脚本全绿。
- [ ] 现有 Renderer、多任务、支付、邮件、日历测试无回归。
- [ ] golden snapshot 变更有明确审阅说明。

### 可观测性

- [ ] 新拒绝路径有 reason code。
- [ ] 新 fallback 有计数和阶段时间戳。
- [ ] mutation/event 带 correlation identity，但日志不包含敏感 payload。
- [ ] 指标标明 `host=ui_lab|main_ui` 和 `mode=legacy|v4_shadow|v4_visible`，禁止混算。

### 安全

- [ ] Action Offer 不可伪造、跨 Surface 或重放。
- [ ] UI Lang 不产生任意代码/工具调用。
- [ ] WebView patch 只使用本地 renderer 产物。
- [ ] 缓存条目完成数据和身份清洗。

### 回滚

- [ ] 有 feature flag 或兼容 adapter 可回退。
- [ ] 新持久化格式有版本和损坏恢复策略。
- [ ] 回滚不会丢失用户本地编辑或执行重复写操作。
- [ ] UI Lab v4 回滚不修改主 UI；主 UI canary 回滚不要求删除 v4 Core 数据。

---

## 17. 建议里程碑

| 里程碑 | 范围 | 结果 |
| --- | --- | --- |
| M0 | PR-V4-0 | 当前 JSON/投机主链完整验收基线 |
| M1 | PR-V4-1、1A、1B | Canonical 契约、三层 Catalog、Presentation View Model、Host Ports 和 UiRunCoordinator 建立；UI Lab 可 shadow |
| M2 | PR-V4-2～4、6 | UI Lab 中四 Store、Revision、Compiler/Reconciler shadow 贯通 |
| M3 | PR-V4-5 | UI Lab UI Lang PoC 和离线 A/B 完成 |
| M4 | PR-V4-7 | LayoutCache 在 UI Lab 低风险 case 启用 |
| M5 | PR-V4-8～9 | UI Lab Event Plane、UiEvent、ActionRouter 完成 |
| M6 | PR-V4-10 | UI Lab WebView 使用 Projection/ChangeSet，ArkUI parity 完成但不切主 UI |
| M7 | PR-V4-11 | UI Lab 切 `v4_visible` 并决定 v4 默认模型格式 |
| M8 | PR-V4-12 | 主 UI legacy-visible/v4-shadow、canary 和最终切换 |

---

## 18. 最终发布检查

- [ ] v4 Core 可在 fake host 下独立运行，不依赖 UI Lab、主 UI 或具体 MultiAgent Runtime。
- [ ] UiRunCoordinator 明确处于现有 MultiAgent/Capability Runtime 下游。
- [ ] UI Lab 已完成 `legacy → v4_shadow → v4_visible` 并可独立回退。
- [ ] UI Lab 实验阶段主 UI 的 Store、Renderer、Action 和 Tool 调用链保持不变。
- [ ] JSON 与 UI Lang 均可关闭或独立启用。
- [ ] A2UI adapter 版本与内部 IR 版本分离。
- [ ] 新模型 Prompt 默认只暴露 Foundation、Semantic 和审核通过的 Extension。
- [ ] 餐厅/酒店/商品等同构数据已共享标准 View Model 与 Semantic Component。
- [ ] 已迁移的 legacy 场景组件不再出现在 Prompt、Canonical 新产物或 LayoutCache 中。
- [ ] 所有 confirm 来自 Canonical diff。
- [ ] LayoutCache 不含 runtime/user/data/action identity。
- [ ] 旧 epoch、旧 revision 和重复 mutation 可安全处理。
- [ ] Interrupt/Resume 和敏感 Action 可审计、可重放保护。
- [ ] ArkUI/WebView 对 golden surfaces 语义等价。
- [ ] 真机完成网络抖动、断流、后台恢复和连续多轮。
- [ ] first meaningful paint、prediction quality 和 UI Lang A/B 指标达到门槛。
- [ ] 主 UI shadow 不重复调用 Tool、不执行 shadow Action、不产生外部副作用。
- [ ] 主 UI canary 按风险顺序完成，且可按 surface/run 回退 legacy。
- [ ] 当前 v3 legacy path 至少保留一个稳定版本周期后再删除。
