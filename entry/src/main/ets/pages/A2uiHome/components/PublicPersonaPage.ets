import {
  PublicPersonaCandidate,
  PublicPersonaInference,
  PublicPersonaPhase,
  PublicPersonaPlatform,
  PublicPersonaProgress,
  PublicPersonaSearchMode,
  PublicPersonaSnapshot,
  PublicPersonaSourceRef,
  parsePublicPersonaMarkdown,
  publicPersonaEditableMarkdown,
  publicPersonaPlatformLabel,
} from '../../../publicpersona/PublicPersonaModel';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_SOFT,
  COLOR_CARD,
  COLOR_CARD_EDGE,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_LINE,
  COLOR_MUTED,
  COLOR_PANEL,
  COLOR_TEXT,
  COLOR_WARNING,
  COLOR_WARNING_SOFT
} from '../style/A2uiHomeTheme';
import {
  A2UI_MOTION_CURVE,
  A2UI_MOTION_MOVE_CURVE,
  A2UI_MOTION_NORMAL_MS
} from '../style/A2uiHomeMotion';

export function publicPersonaDraftAfterDefaultChange(
  current: string,
  touched: boolean,
  defaultDisplayName: string
): string {
  return touched ? current : defaultDisplayName.trim();
}

export type PublicPersonaMarkdownSurfaceKind = 'readonly_text' | 'editable_area';

export function publicPersonaMarkdownSurfaceKind(editing: boolean): PublicPersonaMarkdownSurfaceKind {
  return editing ? 'editable_area' : 'readonly_text';
}

export interface PublicPersonaImportButtonViewState {
  label: string;
  enabled: boolean;
}

export function publicPersonaImportButtonViewState(
  imported: boolean,
  importing: boolean,
  editing: boolean
): PublicPersonaImportButtonViewState {
  if (imported) return { label: '已导入长期记忆', enabled: false };
  if (importing) return { label: '导入中', enabled: false };
  return { label: '将画像导入长期记忆', enabled: !editing };
}

@Component
export struct PublicPersonaPage {
  @StorageProp('a2uiSystemTopInsetVp') systemTopInsetVp: number = 24;
  @Prop phase: PublicPersonaPhase = 'input';
  @Prop candidates: PublicPersonaCandidate[] = [];
  @Prop progress: PublicPersonaProgress | null = null;
  @Prop snapshot: PublicPersonaSnapshot | null = null;
  @Prop errorMessage: string = '';
  @Prop imported: boolean = false;
  @Prop importing: boolean = false;
  @Prop @Watch('onDefaultDisplayNameChanged') defaultDisplayName: string = '';
  @State username: string = '';
  @State usernameTouched: boolean = false;
  @State searchMode: PublicPersonaSearchMode = 'fuzzy';
  @State possibleExpanded: boolean = false;
  @State selectedIds: string[] = [];
  @State selectionTouched: boolean = false;
  @State editingMarkdown: boolean = false;
  @State markdownExpanded: boolean = false;
  @State draftMarkdown: string = '';
  @State mbtiMenuOpen: boolean = false;
  @State deleteConfirm: boolean = false;
  @State deleteWorking: boolean = false;
  @State importRequested: boolean = false;
  @State confirmedDisplayName: string = '';
  @State displayNameTouched: boolean = false;

  onBack: () => void = () => {};
  onChooseSetup: () => void = () => {};
  onSkip: () => void = () => {};
  onStartDiscovery: (username: string, mode: PublicPersonaSearchMode) => void =
    (_username: string, _mode: PublicPersonaSearchMode): void => {};
  onConfirm: (candidateIds: string[], confirmedDisplayName: string) => void =
    (_candidateIds: string[], _confirmedDisplayName: string): void => {};
  onSaveMarkdown: (markdown: string) => boolean = (_markdown: string): boolean => false;
  onReinferMbti: () => void = () => {};
  onSetMbtiHidden: (hidden: boolean) => void = (_hidden: boolean): void => {};
  onImport: () => Promise<boolean> = (): Promise<boolean> => Promise.resolve(false);
  onDelete: () => Promise<boolean> = (): Promise<boolean> => Promise.resolve(false);

  aboutToAppear(): void {
    this.username = publicPersonaDraftAfterDefaultChange(
      this.username, this.usernameTouched, this.defaultDisplayName);
    this.confirmedDisplayName = publicPersonaDraftAfterDefaultChange(
      this.confirmedDisplayName, this.displayNameTouched, this.defaultDisplayName);
  }

  private onDefaultDisplayNameChanged(): void {
    this.username = publicPersonaDraftAfterDefaultChange(
      this.username, this.usernameTouched, this.defaultDisplayName);
    this.confirmedDisplayName = publicPersonaDraftAfterDefaultChange(
      this.confirmedDisplayName, this.displayNameTouched, this.defaultDisplayName);
  }

  private platformLabel(platform: PublicPersonaPlatform): string {
    return publicPersonaPlatformLabel(platform);
  }

  private platformLogo(platform: PublicPersonaPlatform): Resource {
    switch (platform) {
      case 'bilibili': return $r('app.media.logo_bilibili');
      case 'zhihu': return $r('app.media.logo_zhihu');
      case 'weibo': return $r('app.media.logo_weibo');
      case 'github': return $r('app.media.logo_github');
      case 'x': return $r('app.media.logo_x');
      case 'youtube': return $r('app.media.logo_youtube');
      case 'linkedin': return $r('app.media.logo_linkedin');
      default: return $r('app.media.icon_social');
    }
  }

  private highCandidates(): PublicPersonaCandidate[] {
    return this.candidates.filter((candidate: PublicPersonaCandidate): boolean => candidate.ownershipBand === 'high');
  }

  private possibleCandidates(): PublicPersonaCandidate[] {
    return this.candidates.filter((candidate: PublicPersonaCandidate): boolean => candidate.ownershipBand === 'possible');
  }

  private isSelected(candidate: PublicPersonaCandidate): boolean {
    return this.selectionTouched ? this.selectedIds.indexOf(candidate.id) >= 0 : candidate.selected;
  }

  private toggleCandidate(candidate: PublicPersonaCandidate): void {
    if (!this.selectionTouched) {
      this.selectedIds = this.candidates
        .filter((item: PublicPersonaCandidate): boolean => item.selected)
        .map((item: PublicPersonaCandidate): string => item.id);
      this.selectionTouched = true;
    }
    const index = this.selectedIds.indexOf(candidate.id);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(candidate.id);
    }
    this.selectedIds = this.selectedIds.slice();
  }

  private selectedCandidateIds(): string[] {
    if (this.selectionTouched) {
      return this.selectedIds.slice();
    }
    return this.candidates
      .filter((candidate: PublicPersonaCandidate): boolean => candidate.selected)
      .map((candidate: PublicPersonaCandidate): string => candidate.id);
  }

  private sourceUsername(source: PublicPersonaSourceRef): string {
    if ((source.username ?? '').trim().length > 0) {
      return (source.username ?? '').replace(/^@/, '').trim();
    }
    const value = source.profileUrl.substring(source.profileUrl.lastIndexOf('/') + 1);
    return value.replace(/^@/, '').trim();
  }

  private mbtiLine(markdown: string): string {
    const lines = markdown.replace(/\r\n/g, '\n').split('\n');
    for (let index = 0; index < lines.length; index++) {
      if (/^[EI][NS][TF][JP] · [0-9]+%/.test(lines[index])) {
        return lines[index];
      }
    }
    return 'MBTI 暂无';
  }

  private progressText(): string {
    if (this.progress === null) {
      return this.phase === 'discovering' ? '正在检查公开主页…' : '正在整理已确认账号…';
    }
    return this.progress.message + '  ' + this.progress.completed.toString() + '/' + this.progress.total.toString();
  }

  private providerFailureMessage(): string {
    if (this.progress === null) {
      return '';
    }
    switch (this.progress.state) {
      case 'needs_auth': return '公开资料服务需要配置或授权，当前没有读取任何主页。';
      case 'blocked_by_site': return '目标站点暂时限制公开读取，当前没有确认账号。';
      case 'rate_limited': return '公开资料服务触发频率限制，请稍后重试。';
      case 'credits_exhausted': return '公开资料服务额度不足，当前没有读取任何主页。';
      case 'timeout': return '公开资料读取超时，当前没有确认账号。';
      case 'error': return '公开资料服务调用失败，当前没有确认账号。';
      default: return '';
    }
  }

  private markdownForEdit(): string {
    return publicPersonaEditableMarkdown(
      this.editingMarkdown,
      this.draftMarkdown,
      this.snapshot === null ? '' : this.snapshot.personaMarkdown
    );
  }

  @Builder
  private Header(title: string, subtitle: string = '') {
    Row() {
      Button('返回')
        .height(38)
        .width(72)
        .fontSize(13)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_CARD)
        .borderRadius(10)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        .onClick(() => {
          this.onBack();
        })

      Column() {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_INK)
        if (subtitle.length > 0) {
          Text(subtitle)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 16 })
  }

  @Builder
  private PlatformBadge(platform: PublicPersonaPlatform) {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.platformLogo(platform))
        .width(20)
        .height(20)
        .objectFit(ImageFit.Contain)
    }
    .width(28)
    .height(28)
    .backgroundColor(COLOR_CARD)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private AccountRow(candidate: PublicPersonaCandidate) {
    Row() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        if (candidate.avatarUrl.length > 0) {
          Image(candidate.avatarUrl)
            .width(44)
            .height(44)
            .objectFit(ImageFit.Cover)
            .borderRadius(22)
        } else {
          Image(this.platformLogo(candidate.platform))
            .width(44)
            .height(44)
            .objectFit(ImageFit.Contain)
            .padding(9)
            .backgroundColor(COLOR_PANEL)
            .borderRadius(22)
        }
        this.PlatformBadge(candidate.platform)
      }
      Column() {
        Text(candidate.displayName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('@' + candidate.username.replace(/^@/, '') + '  ·  ' + this.platformLabel(candidate.platform))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10, right: 10 })
      Text(this.isSelected(candidate) ? '已选' : '选择')
        .fontSize(12)
        .fontColor(this.isSelected(candidate) ? COLOR_ACCENT : COLOR_MUTED)
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor(this.isSelected(candidate) ? COLOR_ACCENT_SOFT : COLOR_PANEL)
        .borderRadius(9)
    }
    .width('100%')
    .padding(12)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(COLOR_CARD)
    .borderRadius(12)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .onClick(() => {
      this.toggleCandidate(candidate);
    })
    .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
    .margin({ bottom: 8 })
  }

  @Builder
  private SourceRow(source: PublicPersonaSourceRef) {
    Row() {
      if (source.avatarUrl.length > 0) {
        Image(source.avatarUrl)
          .width(34)
          .height(34)
          .objectFit(ImageFit.Cover)
          .borderRadius(17)
      } else {
        Image(this.platformLogo(source.platform))
          .width(34)
          .height(34)
          .objectFit(ImageFit.Contain)
          .borderRadius(17)
          .padding(6)
          .backgroundColor(COLOR_PANEL)
      }
      this.PlatformBadge(source.platform)
      Column() {
        Text((source.displayName ?? '').trim().length > 0 ? (source.displayName ?? '') : this.platformLabel(source.platform))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
        Text('@' + this.sourceUsername(source))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('已确认')
        .fontSize(11)
        .fontColor(COLOR_ACCENT)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private WelcomeView() {
    this.Header('我的画像', '只读取你主动确认的公开账号')
    Column() {
      Text('相见如故')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_INK)
      Text('从公开资料开始，整理一份可以查看和编辑的 persona.md。账号会先展示给你确认，未确认的资料不会被读取。')
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(22)
        .margin({ top: 12, bottom: 20 })
      Button('开始设置')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(COLOR_ACCENT)
        .borderRadius(12)
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        .onClick(() => {
          this.onChooseSetup();
        })
      Button('先跳过')
        .width('100%')
        .height(42)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(12)
        .margin({ top: 8 })
        .onClick(() => {
          this.onSkip();
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private InputView() {
    this.Header('找到你的公开账号', '输入一个你常用的用户名')
    Column() {
      Text('一个用户名就够了')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      Text('先用同名模板直接检查支持可靠验证的平台；模糊模式会再做一次有边界的别名查找。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 7, bottom: 16 })
      TextInput({ placeholder: '例如 XiaoLuoLYG', text: this.username })
        .width('100%')
        .height(48)
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(11)
        .border({ width: 1, color: COLOR_CARD_EDGE })
        .padding({ left: 12, right: 12 })
        .onChange((value: string) => {
          this.username = value;
          this.usernameTouched = true;
        })
      Row() {
        Button('精确')
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontColor(this.searchMode === 'exact' ? Color.White : COLOR_TEXT)
          .backgroundColor(this.searchMode === 'exact' ? COLOR_ACCENT : COLOR_PANEL)
          .borderRadius(10)
          .onClick(() => {
            this.searchMode = 'exact';
          })
        Button('模糊')
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontColor(this.searchMode === 'fuzzy' ? Color.White : COLOR_TEXT)
          .backgroundColor(this.searchMode === 'fuzzy' ? COLOR_ACCENT : COLOR_PANEL)
          .borderRadius(10)
          .margin({ left: 8 })
          .onClick(() => {
            this.searchMode = 'fuzzy';
          })
      }
      .width('100%')
      .margin({ top: 10 })
      Text(this.searchMode === 'exact' ? '只检查这个用户名。' : '还会考虑大小写、分隔符、姓名顺序和包含该字符的账号。')
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ top: 7 })
      Button('开始查找')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor(COLOR_ACCENT)
        .borderRadius(12)
        .enabled(this.username.trim().length > 0)
        .margin({ top: 14 })
        .onClick(() => {
          this.selectionTouched = false;
          this.selectedIds = [];
          this.possibleExpanded = false;
          this.onStartDiscovery(this.username.trim(), this.searchMode);
        })
      Text('只读取公开页面，不会尝试登录或绕过站点限制。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private BusyView() {
    this.Header(this.phase === 'discovering' ? '正在查找公开账号' : '正在整理你的画像', '页面可以随时返回，任务会在后台继续')
    Column() {
      Row() {
        Circle({ width: 10, height: 10 })
          .fill(COLOR_ACCENT)
        Text(this.progressText())
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .margin({ left: 10 })
      }
      .width('100%')
      .padding({ top: 6, bottom: 14 })
      Text(this.phase === 'discovering' ? '正在检查公开用户名与关联账号。' : '只会读取你在上一步确认的账号。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
  }

  @Builder
  private ConfirmationView() {
    this.Header('确认这些账号', '只选择你能确认属于自己的账号')
    Column() {
      Text('确认画像姓名')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .margin({ bottom: 7 })
      Text('默认使用华为账号名称，你可以在生成画像前修改。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ bottom: 9 })
      TextInput({ placeholder: '请输入画像姓名', text: this.confirmedDisplayName })
        .width('100%')
        .height(46)
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(11)
        .border({ width: 1, color: this.confirmedDisplayName.trim().length > 0 ? COLOR_CARD_EDGE : COLOR_WARNING })
        .padding({ left: 12, right: 12 })
        .maxLength(64)
        .margin({ bottom: this.confirmedDisplayName.trim().length > 0 ? 14 : 5 })
        .onChange((value: string) => {
          this.confirmedDisplayName = value;
          this.displayNameTouched = true;
        })
      if (this.confirmedDisplayName.trim().length === 0) {
        Text('姓名不能为空')
          .fontSize(11)
          .fontColor(COLOR_WARNING)
          .margin({ bottom: 10 })
      }
      if (this.highCandidates().length > 0) {
        Text('可以确认 · ' + this.highCandidates().length.toString())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .margin({ bottom: 9 })
        ForEach(this.highCandidates(), (candidate: PublicPersonaCandidate) => {
          this.AccountRow(candidate)
        }, (candidate: PublicPersonaCandidate) => candidate.id)
      }
      if (this.progress !== null && this.progress.completed >= this.progress.total) {
        Text('已尝试 ' + this.progress.total.toString() + ' 个公开平台')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 2 })
        Text('明确结果 ' + (this.progress.found + this.progress.notFound).toString() + ' · 找到 ' +
          this.progress.found.toString() + ' · 未找到 ' + this.progress.notFound.toString() +
          ' · 未完成 ' + this.progress.unknown.toString())
          .fontSize(12)
          .fontColor(this.progress.unknown > 0 ? COLOR_WARNING : COLOR_MUTED)
          .margin({ top: 3, bottom: 8 })
        if (this.progress.message === '模糊搜索未完成') {
          Text('模糊搜索未完成，已保留直接确认的账号')
            .fontSize(12)
            .fontColor(COLOR_WARNING)
            .margin({ bottom: 8 })
        }
      }
      if (this.possibleCandidates().length > 0) {
        Row() {
          Column() {
            Text('可能是你 · ' + this.possibleCandidates().length.toString())
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT)
            Text('折叠显示，点开后自行判断')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.possibleExpanded ? '收起' : '展开')
            .fontSize(12)
            .fontColor(COLOR_ACCENT)
        }
        .width('100%')
        .padding({ top: 12, bottom: 10 })
        .onClick(() => {
          this.possibleExpanded = !this.possibleExpanded;
        })
        if (this.possibleExpanded) {
          ForEach(this.possibleCandidates(), (candidate: PublicPersonaCandidate) => {
            this.AccountRow(candidate)
          }, (candidate: PublicPersonaCandidate) => candidate.id)
        }
      }
      if (this.candidates.length === 0) {
        if (this.providerFailureMessage().length > 0) {
          Text(this.providerFailureMessage())
            .fontSize(13)
            .fontColor(COLOR_WARNING)
            .lineHeight(20)
            .padding(16)
        }
        Text('暂时没有能确认的公开账号。')
          .fontSize(14)
          .fontColor(COLOR_MUTED)
          .padding(16)
        Button('重新输入')
          .width('100%')
          .height(44)
          .fontSize(14)
          .fontColor(COLOR_INK)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(11)
          .onClick(() => {
            this.onChooseSetup();
          })
      } else {
        Button('确认并生成画像')
          .width('100%')
          .height(46)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(12)
          .enabled(this.selectedCandidateIds().length > 0 && this.confirmedDisplayName.trim().length > 0)
          .margin({ top: 8 })
          .onClick(() => {
            this.onConfirm(this.selectedCandidateIds(), this.confirmedDisplayName.trim());
          })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private ErrorView() {
    this.Header('这次没有完成', '公开资料可能暂时不可读')
    Column() {
      Text(this.errorMessage.length > 0 ? this.errorMessage : '请稍后重试。')
        .fontSize(14)
        .fontColor(COLOR_ERROR)
        .lineHeight(21)
        .padding(16)
        .backgroundColor(COLOR_ERROR_SOFT)
        .borderRadius(12)
      Button('重新开始')
        .width('100%')
        .height(44)
        .fontSize(14)
        .fontColor(COLOR_INK)
        .backgroundColor(COLOR_PANEL)
        .borderRadius(11)
        .margin({ top: 12 })
        .onClick(() => {
          this.onChooseSetup();
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
  }

  @Builder
  private CompleteView() {
    if (this.snapshot === null) {
      this.ErrorView()
    } else {
      this.CompleteContent(this.snapshot)
    }
  }

  @Builder
  private ProfileSection(title: string, values: string[]) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_ACCENT)
        .margin({ bottom: 9 })
      if (values.length === 0) {
        Text('暂无公开信息')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
      } else {
        ForEach(values, (value: string, index: number) => {
          Row() {
            Text('•')
              .fontSize(13)
              .fontColor(COLOR_ACCENT)
              .margin({ right: 8 })
            Text(value)
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .lineHeight(21)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .margin({ bottom: index === values.length - 1 ? 0 : 7 })
        }, (value: string, index: number) => title + index.toString() + value)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ProfileDetailRow(title: string, values: string[], showDivider: boolean = true) {
    Column() {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_MUTED)
      Text(values.length > 0 ? values.join(' · ') : '暂无公开信息')
        .fontSize(14)
        .fontColor(values.length > 0 ? COLOR_TEXT : COLOR_MUTED)
        .lineHeight(21)
        .margin({ top: 6, bottom: showDivider ? 13 : 0 })
      if (showDivider) {
        Divider()
          .color(COLOR_LINE)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: showDivider ? 13 : 12 })
  }

  @Builder
  private MbtiControl(snapshot: PublicPersonaSnapshot) {
    Column() {
      if (!snapshot.mbtiHidden) {
        Row() {
          Text(this.mbtiLine(snapshot.personaMarkdown))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_ACCENT)
          Text('›')
            .fontSize(17)
            .fontColor(COLOR_MUTED)
            .margin({ left: 7 })
        }
        .height(38)
        .padding({ left: 12, right: 12 })
        .backgroundColor(COLOR_ACCENT_SOFT)
        .borderRadius(10)
        .onClick(() => {
          this.mbtiMenuOpen = !this.mbtiMenuOpen;
        })
        .animation({ duration: 120, curve: A2UI_MOTION_CURVE })
        if (this.mbtiMenuOpen) {
          Row() {
            Button('重新推测')
              .height(36)
              .fontSize(12)
              .fontColor(COLOR_INK)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(9)
              .onClick(() => {
                this.mbtiMenuOpen = false;
                this.onReinferMbti();
              })
            Button('隐藏 MBTI')
              .height(36)
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(9)
              .margin({ left: 8 })
              .onClick(() => {
                this.mbtiMenuOpen = false;
                this.onSetMbtiHidden(true);
              })
          }
          .margin({ top: 8 })
        }
      } else {
        Button('显示 MBTI')
          .height(38)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(10)
          .onClick(() => {
            this.onSetMbtiHidden(false);
          })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private ProfileView(snapshot: PublicPersonaSnapshot, inference: PublicPersonaInference) {
    Column() {
      Row() {
        if (snapshot.primaryAvatarUrl.length > 0) {
          Image(snapshot.primaryAvatarUrl)
            .width(82)
            .height(82)
            .objectFit(ImageFit.Cover)
            .borderRadius(41)
            .border({ width: 2, color: COLOR_CARD_EDGE })
        } else if (snapshot.sources.length > 0) {
          Image(this.platformLogo(snapshot.sources[0].platform))
            .width(82)
            .height(82)
            .objectFit(ImageFit.Contain)
            .padding(19)
            .backgroundColor(COLOR_PANEL)
            .borderRadius(41)
            .border({ width: 2, color: COLOR_CARD_EDGE })
        }
        Column() {
          Text('公开资料画像')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_ACCENT)
          Text(inference.titleName)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_INK)
            .maxLines(2)
            .margin({ top: 5 })
          Text(inference.oneLineSummary)
            .fontSize(14)
            .fontColor(COLOR_TEXT)
            .lineHeight(21)
            .maxLines(3)
            .margin({ top: 7 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column() {
        this.MbtiControl(snapshot)
        Button('重新认识我')
          .height(38)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(10)
          .margin({ top: 10 })
          .onClick(() => {
            this.onChooseSetup();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })

    Column() {
      this.ProfileSection('身份与经历', inference.identityAndExperience)
      Divider()
        .color(COLOR_LINE)
        .margin({ top: 16, bottom: 16 })
      GridRow({
        columns: 12,
        gutter: 18,
        breakpoints: { value: ['480vp'], reference: BreakpointsReference.ComponentSize }
      }) {
        GridCol({ span: { xs: 12, sm: 6 } }) {
          this.ProfileSection('专长', inference.expertise)
        }
        GridCol({ span: { xs: 12, sm: 6 } }) {
          this.ProfileSection('兴趣与偏好', inference.interestsAndPreferences)
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })

    Column() {
      Text('行为侧写')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
      this.ProfileDetailRow('沟通风格', inference.communicationStyle)
      this.ProfileDetailRow('近期关注', inference.recentFocus)
      this.ProfileDetailRow('性格推断', inference.personalityInference, false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })
  }

  @Builder
  private MarkdownEditor(snapshot: PublicPersonaSnapshot) {
    Column() {
      Row() {
        Text('persona.md')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_INK)
          .layoutWeight(1)
        Button('收起')
          .height(34)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .backgroundColor(Color.Transparent)
          .borderRadius(8)
          .margin({ right: 4 })
          .onClick(() => {
            this.markdownExpanded = false;
          })
        Button(this.editingMarkdown ? '保存' : '编辑')
          .height(34)
          .fontSize(12)
          .fontColor(Color.White)
          .backgroundColor(COLOR_ACCENT)
          .borderRadius(8)
          .onClick(() => {
            if (this.editingMarkdown) {
              const saved = this.onSaveMarkdown(this.markdownForEdit());
              if (saved) {
                this.editingMarkdown = false;
                this.draftMarkdown = '';
              }
            } else {
              this.draftMarkdown = snapshot.personaMarkdown;
              this.editingMarkdown = true;
            }
          })
      }
      .width('100%')
      if (publicPersonaMarkdownSurfaceKind(this.editingMarkdown) === 'editable_area') {
        TextArea({ text: this.markdownForEdit() })
          .width('100%')
          .height(420)
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .padding(12)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(10)
          .margin({ top: 10 })
          .onChange((value: string) => {
            this.draftMarkdown = value;
          })
      } else {
        Text(snapshot.personaMarkdown)
          .width('100%')
          .constraintSize({ minHeight: 420 })
          .fontSize(13)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .padding(12)
          .backgroundColor(COLOR_PANEL)
          .borderRadius(10)
          .margin({ top: 10 })
      }
      Button(publicPersonaImportButtonViewState(
        this.imported, this.importing || this.importRequested, this.editingMarkdown).label)
        .width('100%')
        .height(42)
        .fontSize(13)
        .fontColor(this.imported ? COLOR_ACCENT : Color.White)
        .backgroundColor(this.imported ? COLOR_ACCENT_SOFT : COLOR_ACCENT)
        .borderRadius(10)
        .margin({ top: 10 })
        .enabled(publicPersonaImportButtonViewState(
          this.imported, this.importing || this.importRequested, this.editingMarkdown).enabled)
        .onClick(() => {
          const state = publicPersonaImportButtonViewState(
            this.imported, this.importing || this.importRequested, this.editingMarkdown);
          if (!state.enabled) return;
          this.importRequested = true;
          this.onImport().then((): void => {
            this.importRequested = false;
          }, (): void => {
            this.importRequested = false;
          });
        })
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })
  }

  @Builder
  private CompleteContent(snapshot: PublicPersonaSnapshot) {
    this.Header('你的画像', '可查看、编辑，也可以随时删除')
    if (parsePublicPersonaMarkdown(snapshot.personaMarkdown) !== null) {
      this.ProfileView(snapshot, parsePublicPersonaMarkdown(snapshot.personaMarkdown) as PublicPersonaInference)
    } else {
      Text('画像内容需要修复，请在 persona.md 中检查固定章节。')
        .fontSize(13)
        .fontColor(COLOR_WARNING)
        .lineHeight(20)
        .padding(16)
        .backgroundColor(COLOR_WARNING_SOFT)
        .borderRadius(12)
        .onClick(() => {
          this.markdownExpanded = true;
        })
    }

    if (!this.markdownExpanded) {
      Row() {
        Text('查看 persona.md')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_ACCENT)
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 8 })
      .accessibilityText('查看 persona.md')
      .onClick(() => {
        this.markdownExpanded = true;
      })
    } else {
      this.MarkdownEditor(snapshot)
    }

    Column() {
      Text('已确认账号')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_INK)
        .margin({ bottom: 6 })
      ForEach(snapshot.sources, (source: PublicPersonaSourceRef) => {
        this.SourceRow(source)
      }, (source: PublicPersonaSourceRef) => source.platform + source.profileUrl)
      if (this.deleteConfirm) {
        Column() {
          Text('删除本地 persona.md 和已保存的账号资料？')
            .fontSize(13)
            .fontColor(COLOR_WARNING)
            .lineHeight(19)
          Row() {
            Button('取消')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
              .backgroundColor(COLOR_PANEL)
              .borderRadius(8)
              .onClick(() => {
                this.deleteConfirm = false;
              })
            Button(this.deleteWorking ? '删除中' : '确认删除')
              .height(34)
              .fontSize(12)
              .fontColor(COLOR_ERROR)
              .backgroundColor(COLOR_ERROR_SOFT)
              .borderRadius(8)
              .margin({ left: 8 })
              .enabled(!this.deleteWorking)
              .onClick(() => {
                if (this.deleteWorking) return;
                this.deleteWorking = true;
                this.onDelete().then((deleted: boolean): void => {
                  if (deleted) this.deleteConfirm = false;
                  this.deleteWorking = false;
                }, (): void => {
                  this.deleteWorking = false;
                });
              })
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(COLOR_WARNING_SOFT)
        .borderRadius(10)
        .margin({ top: 8 })
      } else {
        Button('删除画像')
          .height(36)
          .fontSize(12)
          .fontColor(COLOR_ERROR)
          .backgroundColor(COLOR_ERROR_SOFT)
          .borderRadius(9)
          .alignSelf(ItemAlign.Center)
          .margin({ top: 8 })
          .onClick(() => {
            this.deleteConfirm = true;
          })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .border({ width: 1, color: COLOR_CARD_EDGE })
    .margin({ top: 12 })
  }

  build() {
    Scroll() {
      Column() {
        if (this.phase === 'welcome') {
          this.WelcomeView()
        } else if (this.phase === 'input') {
          this.InputView()
        } else if (this.phase === 'discovering' || this.phase === 'reading' || this.phase === 'summarizing') {
          this.BusyView()
        } else if (this.phase === 'awaiting_confirmation') {
          this.ConfirmationView()
        } else if (this.phase === 'complete') {
          this.CompleteView()
        } else {
          this.ErrorView()
        }
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 16 + this.systemTopInsetVp, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_PANEL)
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_MOVE_CURVE })
  }
}
