interface TaskNoticeMessage {
  id: string;
  role: string;
  content: string;
}

export interface WaterfallTaskSnapshot {
  id: string;
  prompt: string;
  reply: string;
  running: boolean;
  failed: boolean;
}

export interface WaterfallTaskNoticeState {
  id: string;
  running: boolean;
  mode: 'hidden' | 'capsule' | 'preview' | 'sheet';
}

export interface WaterfallTaskDisplay {
  summary: string;
  body: string;
  source: string;
}

export function taskNoticeDisplay(reply: string): WaterfallTaskDisplay {
  const sourceLine = reply.match(/\n\n来源[：:]([^\n]+)$/);
  let body = sourceLine ? reply.slice(0, sourceLine.index).trim() : reply.trim();
  let summary = body.split('\n')[0];
  if (sourceLine && sourceLine[1].trim().startsWith('高德天气')) {
    const current = summary.match(/^(.+?)当前天气[：:]\s*(.+)$/);
    if (current) {
      const city = current[1].replace(/市$/, '');
      summary = city + ' · ' + current[2].replace(/[。.]$/, '');
      body = body.replace(/^.+?当前天气[：:]\s*/, city + '现在')
        .replace(/^风向 ([东西南北]+)，/m, '$1风，');
    }
  }
  return {
    summary, body,
    source: sourceLine ? sourceLine[1].trim().replace(/(\d{2}:\d{2}):\d{2}$/, '$1') : ''
  };
}

export function taskNoticeSnapshot(
  messages: TaskNoticeMessage[], id: string, running: boolean, error: string, resultText: string = ''
): WaterfallTaskSnapshot {
  const start = messages.findIndex((message: TaskNoticeMessage): boolean => message.id === id);
  if (start < 0 || id.length === 0) {
    return { id: '', prompt: '', reply: '', running: false, failed: false };
  }
  const replies: string[] = [];
  for (let index = start + 1; index < messages.length; index++) {
    if (messages[index].role === 'user') break;
    if (messages[index].role === 'assistant') replies.push(messages[index].content);
  }
  return {
    id, prompt: messages[start].content, running, failed: !running && error.length > 0,
    reply: !running && error.length > 0 ? error :
      (!running && resultText.length > 0 ? resultText : replies.join('\n\n'))
  };
}

export function emptyTaskNotice(): WaterfallTaskNoticeState {
  return { id: '', running: false, mode: 'hidden' };
}

export function syncTaskNotice(
  previous: WaterfallTaskNoticeState, task: WaterfallTaskSnapshot, active: boolean
): WaterfallTaskNoticeState {
  if (task.id.length === 0) return emptyTaskNotice();
  let mode = previous.mode;
  if (!active) {
    mode = task.running ? 'capsule' : 'hidden';
  } else if (previous.id !== task.id) {
    mode = previous.mode === 'sheet' ? 'sheet' : (task.running ? 'capsule' : 'hidden');
  } else if (task.running) {
    mode = previous.mode === 'sheet' ? 'sheet' : 'capsule';
  } else if (previous.running && previous.mode !== 'sheet') {
    mode = 'preview';
  }
  return { id: task.id, running: task.running, mode };
}

export function dismissTaskNotice(state: WaterfallTaskNoticeState): WaterfallTaskNoticeState {
  return { id: state.id, running: state.running, mode: state.running ? 'capsule' : 'hidden' };
}

// Only a new background gesture after the readable interval can dismiss a result.
export function taskNoticeGestureCanDismiss(
  mode: string, presentedAt: number, gestureStartedAt: number
): boolean {
  return mode === 'sheet' || (mode === 'preview' && gestureStartedAt >= presentedAt + 1800);
}
