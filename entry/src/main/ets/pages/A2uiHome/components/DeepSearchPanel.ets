import { common } from '@kit.AbilityKit';
import { aiLogError, LocalModelSettings } from '@loop/agent-core';
import {
  COLOR_ACCENT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PAGE,
  COLOR_PANEL,
  COLOR_SUCCESS,
  COLOR_TEXT,
  COLOR_WARNING
} from '../style/A2uiHomeTheme';
import {
  DeepSearchComplexity,
  DeepSearchContext,
  DeepSearchEngine,
  DeepSearchProgress,
  DeepSearchReportView,
  DeepSearchSourceView,
  DeepSearchStageStatus,
  DeepSearchStageView,
  usableSource
} from '../deepsearch/DeepSearchEngine';
import { deepSearchPortsOf } from '../deepsearch/DeepSearchPortsFactory';

function stageColor(status: DeepSearchStageStatus): string {
  if (status === 'done') {
    return COLOR_SUCCESS;
  }
  if (status === 'running') {
    return COLOR_ACCENT;
  }
  if (status === 'warn') {
    return COLOR_WARNING;
  }
  if (status === 'error') {
    return COLOR_ERROR;
  }
  return COLOR_LINE;
}

function stageStatusLabel(status: DeepSearchStageStatus): string {
  if (status === 'done') {
    return '完成';
  }
  if (status === 'running') {
    return '进行中';
  }
  if (status === 'warn') {
    return '部分完成';
  }
  if (status === 'error') {
    return '失败';
  }
  return '等待';
}

function elapsedLabel(elapsedMs: number): string {
  if (elapsedMs <= 0) {
    return '';
  }
  if (elapsedMs < 1000) {
    return elapsedMs.toString() + 'ms';
  }
  return (Math.round(elapsedMs / 100) / 10).toString() + 's';
}

/**
 * DeepSearch 主页面内嵌面板：在 HomePage 内容区展示深度搜索结果，
 * 不跳转新页面。支持连续多轮：query 变化时自动取消旧引擎并启动新引擎，
 * 底部输入框保持可用以持续对话。
 */
@Component
export struct DeepSearchPanel {
  @Prop @Watch('onQueryChanged') query: string = '';
  @Prop settingsJson: string = '';
  @Prop contextJson: string = '';
  onClose: () => void = () => {};
  onComplete: (answer: string) => void = () => {};
  @State stages: DeepSearchStageView[] = [];
  @State sources: DeepSearchSourceView[] = [];
  @State reports: DeepSearchReportView[] = [];
  @State answer: string = '';
  @State complexity: DeepSearchComplexity = 'complex';
  @State modelStatus: string = '';
  @State errorText: string = '';
  @State running: boolean = false;
  @State timelineExpanded: boolean = false;
  @State expandedReportIds: string[] = [];
  @State expandedSourceReportIds: string[] = [];
  private engine: DeepSearchEngine | null = null;
  private reportExpansionInitialized: boolean = false;
  private completionNotified: boolean = false;
  private startedQuery: string = '';

  aboutToAppear(): void {
    this.startSearch();
  }

  aboutToDisappear(): void {
    if (this.engine !== null) {
      this.engine.cancel();
    }
  }

  private onQueryChanged(): void {
    // 面板已存在且收到新查询时，重启引擎（连续对话）。
    const trimmed = this.query.trim();
    if (trimmed.length === 0 || trimmed === this.startedQuery) {
      return;
    }
    this.startSearch();
  }

  private startSearch(): void {
    if (this.engine !== null) {
      this.engine.cancel();
    }
    this.engine = null;
    this.completionNotified = false;
    this.reportExpansionInitialized = false;
    this.stages = [];
    this.sources = [];
    this.reports = [];
    this.answer = '';
    this.modelStatus = '';
    this.errorText = '';
    this.timelineExpanded = false;
    this.expandedReportIds = [];
    this.expandedSourceReportIds = [];
    const trimmed = this.query.trim();
    this.startedQuery = trimmed;
    if (trimmed.length === 0) {
      this.running = false;
      this.errorText = '缺少需要研究的问题。';
      return;
    }
    let settings: LocalModelSettings | null = null;
    if (this.settingsJson.trim().length > 0) {
      try {
        settings = JSON.parse(this.settingsJson) as LocalModelSettings;
      } catch (_error) {
        settings = null;
      }
    }
    if (settings === null) {
      this.errorText = '模型配置缺失，无法开始深度搜索。';
      this.running = false;
      return;
    }
    let context: DeepSearchContext | null = null;
    if (this.contextJson.trim().length > 0) {
      try {
        context = JSON.parse(this.contextJson) as DeepSearchContext;
      } catch (_error) {
        context = null;
      }
    }
    this.running = true;
    const engine = new DeepSearchEngine(deepSearchPortsOf(settings));
    this.engine = engine;
    engine.run(trimmed, (progress: DeepSearchProgress): void => {
      if (this.engine !== engine) {
        return;
      }
      const wasRunning = this.running;
      this.stages = progress.stages;
      this.sources = progress.sources;
      this.reports = progress.reports;
      this.answer = progress.answer;
      this.complexity = progress.complexity;
      this.modelStatus = progress.modelStatus;
      this.running = progress.running;
      this.errorText = progress.error;
      if (wasRunning && !progress.running) {
        if (!this.reportExpansionInitialized && progress.reports.length > 0 &&
          progress.complexity === 'complex') {
          const reportIds: string[] = [];
          for (let index = 0; index < progress.reports.length; index++) {
            reportIds.push(progress.reports[index].id);
          }
          this.expandedReportIds = reportIds;
          this.reportExpansionInitialized = true;
        }
        if (!this.completionNotified && progress.answer.trim().length > 0) {
          this.completionNotified = true;
          this.onComplete(progress.answer);
        }
      }
    }, context).catch((error: Error) => {
      if (this.engine !== engine) {
        return;
      }
      const message = error.message !== undefined && error.message.length > 0 ?
        error.message : JSON.stringify(error);
      this.errorText = message;
      this.running = false;
      aiLogError('[AIPhone][DeepSearchPanelRunError] ' + message.substring(0, 240));
    });
  }

  private currentStage(): DeepSearchStageView | null {
    for (let index = 0; index < this.stages.length; index++) {
      if (this.stages[index].status === 'running') {
        return this.stages[index];
      }
    }
    for (let index = this.stages.length - 1; index >= 0; index--) {
      if (this.stages[index].status !== 'pending') {
        return this.stages[index];
      }
    }
    return null;
  }

  private latestLine(stage: DeepSearchStageView): string {
    if (stage.lines.length > 0) {
      return stage.lines[stage.lines.length - 1];
    }
    return stage.detail;
  }

  private finishedStageCount(): number {
    let count = 0;
    for (let index = 0; index < this.stages.length; index++) {
      const status = this.stages[index].status;
      if (status === 'done' || status === 'warn' || status === 'error') {
        count++;
      }
    }
    return count;
  }

  private totalElapsedLabel(): string {
    let total = 0;
    for (let index = 0; index < this.stages.length; index++) {
      total += this.stages[index].elapsedMs;
    }
    return elapsedLabel(total);
  }

  private toggleId(ids: string[], id: string): string[] {
    const index = ids.indexOf(id);
    if (index < 0) {
      return ids.concat([id]);
    }
    const next = ids.slice(0);
    next.splice(index, 1);
    return next;
  }

  private toggleReport(reportId: string): void {
    this.expandedReportIds = this.toggleId(this.expandedReportIds, reportId);
  }

  private toggleReportSources(reportId: string): void {
    this.expandedSourceReportIds = this.toggleId(this.expandedSourceReportIds, reportId);
  }

  private async openSource(url: string): Promise<void> {
    const uri = url.trim();
    if (!uri.startsWith('https://') && !uri.startsWith('http://')) {
      this.errorText = '该来源地址无效，无法打开。';
      return;
    }
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      try {
        await context.openLink(uri);
      } catch (_linkError) {
        await context.startAbility({
          action: 'ohos.want.action.viewData',
          entities: ['entity.system.browsable'],
          uri: uri
        });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.errorText = '来源打开失败：' + message;
      aiLogError('[AIPhone][DeepSearchPanelOpenSourceError] ' + message.substring(0, 240));
    }
  }

  private usableSourceCount(): number {
    let count = 0;
    for (let index = 0; index < this.sources.length; index++) {
      if (usableSource(this.sources[index])) {
        count++;
      }
    }
    return count;
  }

  @Builder
  StageNode(stage: DeepSearchStageView, index: number) {
    Row() {
      Column() {
        Circle({ width: 14, height: 14 })
          .fill(stageColor(stage.status))
        if (index < this.stages.length - 1) {
          Column()
            .width(2)
            .height(20)
            .backgroundColor(stage.status === 'pending' ? COLOR_LINE : stageColor(stage.status))
            .opacity(0.45)
            .margin({ top: 4 })
        }
      }
      .width(20)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Row() {
          Text(stage.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .layoutWeight(1)
          if (stage.status === 'running') {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(COLOR_ACCENT)
              .margin({ right: 6 })
          }
          Text(stageStatusLabel(stage.status) +
            (elapsedLabel(stage.elapsedMs).length > 0 ? ' · ' + elapsedLabel(stage.elapsedMs) : ''))
            .fontSize(11)
            .fontColor(stageColor(stage.status))
        }
        .width('100%')

        if (stage.detail.length > 0) {
          Text(stage.detail)
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .margin({ top: 3 })
            .width('100%')
        }
        if (stage.lines.length > 0) {
          Column() {
            ForEach(stage.lines, (line: string) => {
              Text('· ' + line)
                .fontSize(11)
                .fontColor(COLOR_MUTED)
                .width('100%')
                .margin({ top: 2 })
            }, (line: string, lineIndex: number) => stage.id + '_' + lineIndex.toString())
          }
          .width('100%')
          .padding(8)
          .margin({ top: 4 })
          .borderRadius(8)
          .backgroundColor(COLOR_PANEL)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 10, bottom: 8 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  SourceCard(source: DeepSearchSourceView) {
    Row() {
      Column() {
        Text(source.title)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(source.deepRead ? '已精读 · 点击打开原文' : '第' + source.round.toString() + '轮 · 点击打开原文')
          .fontSize(10)
          .fontColor(source.deepRead ? COLOR_SUCCESS : COLOR_MUTED)
          .margin({ top: 3 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(22)
        .fontColor(COLOR_ACCENT)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 9, bottom: 9 })
    .borderRadius(8)
    .backgroundColor(COLOR_PANEL)
    .margin({ top: 6 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openSource(source.url);
    })
  }

  @Builder
  ReportCard(report: DeepSearchReportView) {
    Column() {
      Row() {
        Text(report.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(report.confidence)
          .fontSize(10)
          .fontColor(report.sources.length > 1 ? COLOR_SUCCESS : COLOR_WARNING)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(8)
          .backgroundColor(COLOR_PANEL)
      }
      .width('100%')

      Text(report.overview)
        .fontSize(12)
        .fontColor(COLOR_TEXT)
        .lineHeight(19)
        .margin({ top: 7 })
        .maxLines(this.expandedReportIds.indexOf(report.id) >= 0 ? 6 : 2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.expandedReportIds.indexOf(report.id) >= 0) {
        ForEach(report.findings, (finding: string, index: number) => {
          Row() {
            Text('•')
              .fontSize(13)
              .fontColor(COLOR_ACCENT)
              .margin({ right: 6 })
            Text(finding)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
              .lineHeight(19)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ top: index === 0 ? 8 : 5 })
        }, (finding: string, index: number) => report.id + '_finding_' + index.toString())
      }

      Row() {
        Text(this.expandedReportIds.indexOf(report.id) >= 0 ? '收起摘要' : '查看摘要')
          .fontSize(11)
          .fontColor(COLOR_ACCENT)
          .onClick(() => {
            this.toggleReport(report.id);
          })
        Blank()
        if (report.sources.length > 0) {
          Text(this.expandedSourceReportIds.indexOf(report.id) >= 0 ?
            '收起来源' : '来源 ' + report.sources.length.toString())
            .fontSize(11)
            .fontColor(COLOR_ACCENT)
            .onClick(() => {
              this.toggleReportSources(report.id);
            })
        }
      }
      .width('100%')
      .margin({ top: 10 })

      if (this.expandedSourceReportIds.indexOf(report.id) >= 0) {
        ForEach(report.sources, (source: DeepSearchSourceView) => {
          this.SourceCard(source)
        }, (source: DeepSearchSourceView, index: number) => report.id + '_source_' + index.toString())
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(COLOR_CARD)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ bottom: 10 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ThinkingBubble() {
    Column() {
      Row() {
        if (this.running) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(COLOR_ACCENT)
            .margin({ right: 8 })
        } else {
          Circle({ width: 12, height: 12 })
            .fill(this.errorText.length > 0 ? COLOR_ERROR : COLOR_SUCCESS)
            .margin({ right: 8 })
        }
        Column() {
          if (this.running && this.currentStage() !== null) {
            Text(this.currentStage()!.title)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
            if (this.latestLine(this.currentStage()!).length > 0) {
              Text(this.latestLine(this.currentStage()!))
                .fontSize(11)
                .fontColor(COLOR_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 })
                .width('100%')
            }
          } else {
            Text(this.errorText.length > 0 ?
              '深度搜索中断' :
              '已完成 ' + this.finishedStageCount().toString() + ' 个阶段' +
              (this.totalElapsedLabel().length > 0 ? ' · 用时 ' + this.totalElapsedLabel() : ''))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.errorText.length > 0 ? COLOR_ERROR : COLOR_INK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.timelineExpanded ? '▲' : '▼')
          .fontSize(12)
          .fontColor(COLOR_ACCENT)
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.timelineExpanded = !this.timelineExpanded;
      })

      if (this.timelineExpanded) {
        Column() {
          ForEach(this.stages, (stage: DeepSearchStageView, index: number) => {
            this.StageNode(stage, index)
          }, (stage: DeepSearchStageView) => stage.id + '_' + stage.status +
            '_' + stage.lines.length.toString())
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(14)
    .backgroundColor(COLOR_CARD)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('DeepSearch')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
          Text(this.query)
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.running) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(COLOR_ACCENT)
            .margin({ right: 10 })
        }

        Text('✕')
          .fontSize(18)
          .fontColor(COLOR_MUTED)
          .padding({ left: 10, right: 2, top: 2, bottom: 2 })
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ bottom: 12 })

      Scroll() {
        Column() {
          Column() {
            Text(this.running ?
              '深度搜索进行中…' :
              (this.errorText.length > 0 ? '深度搜索中断' : '深度搜索完成 · 可用来源 ' +
                this.usableSourceCount().toString() + ' 个'))
              .fontSize(11)
              .fontColor(this.errorText.length > 0 ? COLOR_ERROR : COLOR_MUTED)
              .margin({ top: 4 })
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          this.ThinkingBubble()

          if (this.errorText.length > 0) {
            Text(this.errorText)
              .fontSize(12)
              .fontColor(COLOR_ERROR)
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(COLOR_CARD)
              .border({ width: 1, color: COLOR_ERROR })
              .margin({ top: 4, bottom: 12 })
          }

          if (this.modelStatus.length > 0) {
            Text(this.modelStatus)
              .fontSize(11)
              .fontColor(COLOR_WARNING)
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .borderRadius(8)
              .backgroundColor(COLOR_PANEL)
              .margin({ bottom: 10 })
          }

          if (!this.running && this.answer.length > 0) {
            Column() {
              Text(this.complexity === 'simple' ? '概况' : '总览')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_INK)
                .width('100%')
              Text(this.answer)
                .fontSize(13)
                .fontColor(COLOR_TEXT)
                .lineHeight(21)
                .margin({ top: 8 })
                .width('100%')
                .copyOption(CopyOptions.LocalDevice)
            }
            .width('100%')
            .padding(14)
            .borderRadius(8)
            .backgroundColor(COLOR_CARD)
            .border({ width: 1, color: COLOR_CARD_EDGE })
            .margin({ top: 4, bottom: 16 })
            .alignItems(HorizontalAlign.Start)
          }

          if (this.reports.length > 0) {
            Text(this.complexity === 'simple' ? '相关明细（可展开）' : '按主题整理')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .width('100%')
              .margin({ bottom: 8 })
            ForEach(this.reports, (report: DeepSearchReportView) => {
              this.ReportCard(report)
            }, (report: DeepSearchReportView) => report.id + '_' + report.overview + '_' +
              report.findings.length.toString() + '_' + report.sources.length.toString())
          }

          if (this.reports.length === 0 && this.sources.length > 0) {
            Text('检索来源（' + this.sources.length.toString() + '）')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_INK)
              .width('100%')
              .margin({ bottom: 8 })
            ForEach(this.sources, (source: DeepSearchSourceView) => {
              this.SourceCard(source)
            }, (source: DeepSearchSourceView, index: number) => 'fallback_source_' + index.toString())
          }
        }
        .width('100%')
        .padding({ left: 2, right: 2, top: 4, bottom: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor(COLOR_PAGE)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .shadow({ radius: 24, color: COLOR_CARD_EDGE, offsetX: 0, offsetY: 6 })
  }
}
