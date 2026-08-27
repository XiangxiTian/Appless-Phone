import { aiLogError, LocalModelSettings } from '@loop/agent-core';
import {
  DeepSearchContext,
  DeepSearchEngine,
  DeepSearchProgress,
  DeepSearchSourceView,
  usableSource
} from '../deepsearch/DeepSearchEngine';
import { deepSearchPortsOf } from '../deepsearch/DeepSearchPortsFactory';

export function deepSearchCompletionText(progress: DeepSearchProgress): string {
  const answer = progress.answer.trim();
  return answer.length > 0 ? answer : progress.error.trim();
}

@Component
export struct DeepSearchPanel {
  @Prop @Watch('onQueryChanged') query: string = '';
  @Prop @Watch('onStartReadyChanged') startReady: boolean = false;
  @Prop settingsJson: string = '';
  @Prop contextJson: string = '';
  onProgress: (progressJson: string) => void = (_progressJson: string) => {};
  onComplete: (answer: string) => void = (_answer: string) => {};
  private engine: DeepSearchEngine | null = null;
  private completionNotified: boolean = false;
  private startedQuery: string = '';

  aboutToAppear(): void {
    this.startIfReady();
  }

  aboutToDisappear(): void {
    if (this.engine !== null) this.engine.cancel();
  }

  private onQueryChanged(): void {
    if (this.engine !== null) this.engine.cancel();
    this.engine = null;
    this.startedQuery = '';
  }

  private onStartReadyChanged(): void {
    this.startIfReady();
  }

  private notifyComplete(answer: string): void {
    if (this.completionNotified) return;
    this.completionNotified = true;
    this.onComplete(answer.trim());
  }

  private publish(progress: DeepSearchProgress): void {
    const sources: DeepSearchSourceView[] = [];
    for (let index = 0; index < progress.sources.length; index++) {
      if (usableSource(progress.sources[index])) sources.push(progress.sources[index]);
    }
    this.onProgress(JSON.stringify({
      stages: progress.stages,
      sources: sources,
      modelStatus: progress.modelStatus,
      running: progress.running,
      error: progress.error
    }));
  }

  private publishError(message: string): void {
    this.onProgress(JSON.stringify({
      stages: [],
      sources: [],
      modelStatus: '',
      running: false,
      error: message
    }));
  }

  private startIfReady(): void {
    const trimmed = this.query.trim();
    if (!this.startReady || trimmed.length === 0 || trimmed === this.startedQuery) return;
    if (this.engine !== null) this.engine.cancel();
    this.engine = null;
    this.completionNotified = false;
    this.startedQuery = trimmed;
    let settings: LocalModelSettings | null = null;
    try {
      settings = JSON.parse(this.settingsJson) as LocalModelSettings;
    } catch (_error) {
      settings = null;
    }
    if (settings === null) {
      const message = '模型配置缺失，无法开始深度搜索。';
      this.publishError(message);
      this.notifyComplete(message);
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
    const engine = new DeepSearchEngine(deepSearchPortsOf(settings));
    this.engine = engine;
    engine.run(trimmed, (progress: DeepSearchProgress): void => {
      if (this.engine !== engine) return;
      this.publish(progress);
      if (!progress.running) this.notifyComplete(deepSearchCompletionText(progress));
    }, context).catch((error: Error): void => {
      if (this.engine !== engine) return;
      const message = error.message.length > 0 ? error.message : JSON.stringify(error);
      this.publishError(message);
      this.notifyComplete(message);
      aiLogError('[AIPhone][DeepSearchPanelRunError] ' + message.substring(0, 240));
    });
  }

  build() {
    Blank()
      .width(0)
      .height(0)
  }
}
