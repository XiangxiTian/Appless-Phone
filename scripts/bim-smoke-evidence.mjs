import { multiAgentEvidenceRecords } from './multi-agent-smoke-evidence.mjs';

function parsedLayout(layout) {
  if (typeof layout !== 'string') return layout && typeof layout === 'object' ? layout : {};
  try {
    return JSON.parse(layout);
  } catch (_error) {
    return {};
  }
}

function layoutText(layout) {
  const values = [];
  const visit = (node) => {
    if (node === null || typeof node !== 'object') return;
    for (const key of ['text', 'content', 'description', 'hint', 'accessibilityText']) {
      if (typeof node[key] === 'string' && node[key].trim().length > 0) values.push(node[key].trim());
    }
    visit(node.attributes);
    for (const child of node.children || node.nodes || []) visit(child);
  };
  visit(parsedLayout(layout));
  return values;
}

function childNodes(node) {
  if (node === null || typeof node !== 'object') return [];
  return node.children || node.nodes || [];
}

function nodeValue(node, key) {
  if (node === null || typeof node !== 'object') return undefined;
  if (node[key] !== undefined) return node[key];
  return node.attributes && typeof node.attributes === 'object' ? node.attributes[key] : undefined;
}

function pointFromBounds(bounds) {
  const match = typeof bounds === 'string' ? /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds) : null;
  if (match === null) return null;
  return {
    x: Math.round((Number(match[1]) + Number(match[3])) / 2),
    y: Math.round((Number(match[2]) + Number(match[4])) / 2)
  };
}

function headerHeartNode(layout) {
  let result = null;
  const visit = (node) => {
    if (result !== null || node === null || typeof node !== 'object') return;
    const children = childNodes(node);
    const titleIndex = children.findIndex((child) => nodeValue(child, 'text') === 'Appless');
    if (titleIndex >= 0) {
      result = children.slice(titleIndex + 1).find((child) => {
        const clickable = nodeValue(child, 'clickable');
        return clickable === true || clickable === 'true';
      }) || null;
    }
    for (const child of children) visit(child);
  };
  visit(parsedLayout(layout));
  return result;
}

export function heartPointFromLayout(layout) {
  const heart = headerHeartNode(layout);
  return heart === null ? null : pointFromBounds(nodeValue(heart, 'bounds'));
}

export function bimDeleteConfirmationPoint(layout) {
  let result = null;
  const hasExactDelete = (node) => nodeValue(node, 'text') === '删除' ||
    childNodes(node).some(hasExactDelete);
  const visit = (node, insideDialog = false) => {
    if (result !== null || node === null || typeof node !== 'object') return;
    const inDialog = insideDialog || nodeValue(node, 'type') === 'Dialog';
    const clickable = nodeValue(node, 'clickable');
    if (inDialog && nodeValue(node, 'type') === 'Button' &&
      (clickable === true || clickable === 'true') && hasExactDelete(node)) {
      result = pointFromBounds(nodeValue(node, 'bounds'));
      if (result !== null) return;
    }
    for (const child of childNodes(node)) visit(child, inDialog);
  };
  visit(parsedLayout(layout));
  return result;
}

export function heartCountFromLayout(layout) {
  for (const value of layoutText(layout)) {
    const count = /打开心上事\s*[，,]?\s*共\s*(\d+)\s*件/.exec(value);
    if (count !== null) return Number.parseInt(count[1], 10);
    if (value === '打开心上事') return 0;
  }
  const heart = headerHeartNode(layout);
  if (heart === null) return null;
  const count = layoutText(heart).find((value) => /^\d+$/.test(value));
  return count === undefined ? 0 : Number.parseInt(count, 10);
}

export function hasBimDirectory(layout) {
  const text = layoutText(layout);
  return text.includes('心上事') &&
    ['进行中', '沉静', '已收起', '还没有心上事', '正在发生', '最近沉静']
      .some((marker) => text.includes(marker));
}

export function hasBimHome(layout) {
  const text = layoutText(layout);
  return text.includes('Appless') &&
    heartCountFromLayout(layout) !== null &&
    !hasBimDirectory(layout);
}

export function hasBimReadOnlyContext(...layouts) {
  const text = layouts.flatMap(layoutText);
  return text.some((value) => /^当前 Snapshot · v\d+$/.test(value)) &&
    text.includes('完整上下文') &&
    !text.some((value) => /编辑.*(?:Snapshot|完整上下文)|保存.*(?:Snapshot|完整上下文)/.test(value));
}

export function hasConversationTranscript(layout) {
  const text = layoutText(layout);
  return text.includes('生成轨迹') || text.includes('暂无对话轨迹') || text.some((value) =>
    /^(?:用户|我|你|助手|用户消息|助手消息|聊天记录|对话记录|user|assistant)\s*(?:[:：]|消息|记录)/i.test(value));
}

export function hasMainAgentResult(logText) {
  return String(logText || '').split('\n').some((line) =>
    /\[AIPhone\]\[MultiAgentTurnResult\][^\n]*\bstatus=(?:success|partial|empty)\b/.test(line) &&
    /\bmessageChars=[1-9]\d*\b/.test(line));
}

export function hasSnapshotOnlyMainAgent(logText) {
  const value = String(logText || '');
  if (/\[AIPhone\]\[(?:BimRoute|BimGate)\]|BIM_MAIN_TURN_NOT_ADMITTED|bim_takeover/.test(value)) return false;
  const records = multiAgentEvidenceRecords(value);
  const inputs = records.filter((item) => item.marker === 'MultiAgentInput');
  const terminals = records.filter((item) => item.marker === 'MultiAgentTurnResult' &&
    ['success', 'partial', 'empty'].includes(item.fields.status) &&
    /^[1-9]\d*$/.test(item.fields.messageChars || ''));
  return inputs.length === 1 && terminals.length === 1;
}

export function bimSmokeStatus(statuses) {
  if (statuses.includes('FAIL')) return 'FAIL';
  return statuses.includes('BLOCKED') ? 'BLOCKED' : 'PASS';
}

export function bimScenarioStatus(ok, blockedReason) {
  if (String(blockedReason || '').length > 0) return 'BLOCKED';
  return ok ? 'PASS' : 'FAIL';
}

export function bimSentinelEvidence(logText) {
  const value = String(logText || '');
  const eventMatch = value.match(/\[AIPhone\]\[BimSentinel\] mode=mock events=(\d+) ok=true/);
  const reminderScheduled = /\[AIPhone\]\[BimSentinelMockScheduled\] reminderId=\d+/.test(value);
  const inAppScheduled = /\[AIPhone\]\[BimSentinelMockScheduled\] transport=in_app_timer/.test(value);
  return {
    scheduled: reminderScheduled || inAppScheduled,
    triggered: /\[AIPhone\]\[BimSentinelMockTriggered\]/.test(value),
    completed: eventMatch !== null,
    eventCount: eventMatch === null ? null : Number.parseInt(eventMatch[1], 10),
    transport: reminderScheduled ? 'reminder' : inAppScheduled ? 'in_app_timer' : ''
  };
}

export function bimSentinelUsesInAppTimer(text) {
  return text.join('\n').includes('系统提醒已满，10 秒后应用内测试');
}

export function sanitizeBimFailureReason(error) {
  const raw = error instanceof Error ? error.message : String(error || '');
  return raw
    .replace(/([?&](?:api[_-]?key|access[_-]?token|token|secret|password)=)[^&\s]*/gi, '$1<redacted>')
    .replace(/\b(Bearer|Basic)\s+\S+/gi, '$1 <redacted>')
    .replace(/\bsk-[A-Za-z0-9_-]{8,}\b/g, '<redacted>')
    .slice(0, 500);
}

const BIM_SCENARIO_IDS = [
  'home', 'main-agent', 'curator-create', 'directory', 'sentinel', 'detail', 'cleanup'
];

export function completeBimScenarios(scenarios, failureReason, failedId = '') {
  const completed = scenarios.slice();
  const reason = sanitizeBimFailureReason(failureReason);
  if (failedId.length > 0 && !completed.some((scenario) => scenario.id === failedId)) {
    completed.push({ id: failedId, status: 'FAIL', ok: false, reason });
  }
  for (const id of BIM_SCENARIO_IDS) {
    if (!completed.some((scenario) => scenario.id === id)) {
      completed.push({ id, status: 'BLOCKED', ok: false, reason: `Blocked by prerequisite: ${reason}` });
    }
  }
  return completed;
}
