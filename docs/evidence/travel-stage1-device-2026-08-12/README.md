# 阶段一真机验收证据

- 日期：2026-08-12
- 设备：HOP-AL10，HarmonyOS 6.1.0.135
- 应用：`com.example.aiphonedemo`，Debug 1.0.2（1000002）
- 测试任务：2026-08-21，深圳 → 上海，出差
- Debug 测试口令：`travel-stage1-test`（Release 构建不可用）

## 验收结果

- Debug 测试任务可创建并立即渲染恢复卡。
- 卡片展示绝对日期、路线、当前步骤、交通状态和酒店状态。
- 卡片提供“继续安排”动作。
- 强制结束 App 进程后重新启动，任务无需依赖测试口令对话文本即可恢复。
- 使用相同签名覆盖安装最终 Debug 包后，任务数据仍能恢复。

## 文件

- `created.png` / `created-layout.json`：任务创建后的恢复卡。
- `restarted.png` / `restarted-layout.json`：杀进程重启后的恢复卡。
- `restarted-details.png` / `restarted-details-layout.json`：日期、路线、步骤及交通/酒店状态。
- `final.png` / `final-layout.json`：最终 Debug 门禁版本覆盖安装后的恢复结果。
