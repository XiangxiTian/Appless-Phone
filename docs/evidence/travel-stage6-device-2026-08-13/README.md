# 阶段六真机验收证据

- 日期：2026-08-13
- 设备：`6HR0226506005010`
- 场景：非真实订单样例 `TESTG600`，深圳北到上海虹桥
- 范围：交通日历确认、真实系统日历写入、重复写入保护、杀进程恢复和样例清理

## 结果

- 已将样例交通写入系统日历，并在内部流程中保存真实事件 ID。
- 最终幂等验收使用事件 `293`：再次提交同一个 `taskId + legId` 后，页面显示“已更新同一事件 293，未创建重复日程”。
- 杀掉应用进程并重启后，仍恢复“已加入系统日历”状态和事件 ID `293`。
- 验收结束后已删除测试日程，并恢复原来的 `G3020` 出行任务。
- 未执行真实购票、支付或出票。

## 截图说明

- `01-original-task.jpeg`：验收前的原出行任务。
- `02-calendar-confirmation.jpeg`、`02b-calendar-confirmation-detail.jpeg`：固定非真实样例的写入确认和详情。
- `03-calendar-created.jpeg`、`03b-calendar-created-detail.jpeg`：首次原生日历写入成功；中间样例事件 `292` 随后已清理。
- `04-existing-retry.jpeg`：写入成功后的重复保护和清理入口。
- `05-idempotency-pass.jpeg`、`05b-idempotency-detail.jpeg`：最终事件 `293` 的状态与重复写入保护通过证据。
- `06-after-restart.jpeg`、`06b-after-restart-detail.jpeg`：杀进程重启后事件 `293` 仍被正确恢复。
- `07-original-task-restored.jpeg`：删除测试日程后恢复原 `G3020` 任务。
