import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import {
  bimDeleteConfirmationPoint,
  bimScenarioStatus,
  bimSentinelEvidence,
  bimSentinelUsesInAppTimer,
  hasBimDirectory,
  hasBimHome,
  hasBimReadOnlyContext,
  hasConversationTranscript,
  hasMainAgentResult,
  hasSnapshotOnlyMainAgent,
  bimSmokeStatus,
  completeBimScenarios,
  heartCountFromLayout,
  heartPointFromLayout,
  sanitizeBimFailureReason
} from './bim-smoke-evidence.mjs';

function fixture(nodes) {
  return JSON.stringify({ nodes });
}

test('finds heart count and rejects transcript residue', () => {
  const layout = fixture([
    { text: 'Appless' },
    { accessibilityText: '打开心上事，共 1 件', text: '1' },
    { text: '心上事' },
    { text: '进行中' },
    { text: '东京旅行' },
    { text: '当前安排' }
  ]);
  assert.equal(heartCountFromLayout(layout), 1);
  assert.equal(hasBimDirectory(layout), true);
  assert.equal(hasConversationTranscript(layout), false);
});

test('requires an exact directory surface and an exact Home surface', () => {
  const home = fixture([
    { text: 'Appless' },
    { accessibilityText: '打开心上事，共 1 件' }
  ]);
  const directory = fixture([{ text: '心上事' }, { text: '进行中' }]);
  assert.equal(hasBimDirectory(home), false);
  assert.equal(hasBimDirectory(fixture([{ text: '返回心上事列表' }, { text: '当前状态' }])), false);
  assert.equal(hasBimDirectory(directory), true);
  assert.equal(hasBimHome(home), true);
  assert.equal(hasBimHome(directory), false);
});

test('finds the real header heart when the device omits accessibilityText', () => {
  const home = JSON.stringify({
    children: [{
      attributes: { type: 'Row' },
      children: [
        { attributes: { text: 'Appless', type: 'Text' } },
        {
          attributes: { clickable: 'true', bounds: '[554,178][708,332]', type: 'Stack' },
          children: [
            { attributes: { type: 'Image' } },
            { attributes: { text: '3', type: 'Text' } }
          ]
        }
      ]
    }]
  });
  assert.equal(heartCountFromLayout(home), 3);
  assert.deepEqual(heartPointFromLayout(home), { x: 631, y: 255 });
  assert.equal(hasBimHome(home), true);
});

test('detects the real HistoryPanel transcript without mistaking the app header', () => {
  assert.equal(hasConversationTranscript(fixture([{ text: 'Appless' }])), false);
  assert.equal(hasConversationTranscript(fixture([
    { text: '生成轨迹' },
    { text: '2' },
    { text: '你' },
    { text: '帮我规划东京旅行' },
    { text: 'Appless' },
    { text: '这是当前安排' }
  ])), true);
  assert.equal(hasConversationTranscript(fixture([
    { text: '生成轨迹' },
    { text: '暂无对话轨迹' }
  ])), true);
});

test('requires both read-only Snapshot and Full Context sections in BIM detail', () => {
  assert.equal(hasBimReadOnlyContext(fixture([
    { text: '当前 Snapshot · v2' },
    { text: '完整上下文' },
    { text: '东京旅行四人同行' }
  ])), true);
  assert.equal(hasBimReadOnlyContext(fixture([{ text: '当前状态' }])), false);
  assert.equal(hasBimReadOnlyContext(fixture([
    { text: '当前 Snapshot · v2' },
    { text: '完整上下文' },
    { text: '编辑完整上下文' }
  ])), false);
  assert.equal(hasBimReadOnlyContext(
    fixture([{ text: '当前 Snapshot · v2' }]),
    fixture([{ text: '完整上下文' }])
  ), true);
});

test('targets only the exact delete action inside the BIM confirmation dialog', () => {
  const layout = {
    children: [{
      attributes: { type: 'Button', text: '删除', bounds: '[974,202][1170,351]' }
    }, {
      attributes: { type: 'Text', text: '验证完成后结束并删除该事项', bounds: '[165,1333][1116,1400]' }
    }, {
      attributes: { type: 'Dialog', accessibilityText: '删除这件已结束的心上事？' },
      children: [{
        attributes: { type: 'Text', text: '删除这件已结束的心上事？' }
      }, {
        attributes: { type: 'Button', clickable: 'true', bounds: '[135,1410][1089,1545]' },
        children: [{ attributes: { type: 'Text', text: '删除', bounds: '[558,1446][666,1509]' } }]
      }]
    }]
  };
  assert.deepEqual(bimDeleteConfirmationPoint(layout), { x: 612, y: 1478 });
});

test('accepts exactly one main-agent terminal without legacy BIM routing or gate markers', () => {
  const logs = [
    '[AIPhone][MultiAgentInput] conversation=c1 turn=t1 task=input-1',
    '[AIPhone][MultiAgentTurnResult] conversation=c1 turn=t1 task=input-1 status=success surface=none roundCount=0 messageChars=12'
  ].join('\n');
  assert.equal(hasSnapshotOnlyMainAgent(logs), true);
  const dualChannel = [
    '08-10 17:07:28.668  1  1 I A00000/app/AIPhone: ' + logs.split('\n')[0],
    '08-10 17:07:28.668  1  1 I A03D00/app/JSAPP: ' + logs.split('\n')[0],
    '08-10 17:07:41.017  1  1 I A00000/app/AIPhone: ' + logs.split('\n')[1],
    '08-10 17:07:41.017  1  1 I A03D00/app/JSAPP: ' + logs.split('\n')[1]
  ].join('\n');
  assert.equal(hasSnapshotOnlyMainAgent(dualChannel), true);
  assert.equal(hasSnapshotOnlyMainAgent(logs + '\n[AIPhone][BimRoute] status=none'), false);
  assert.equal(hasSnapshotOnlyMainAgent(logs + '\n' + logs), false);
  assert.equal(hasMainAgentResult(logs), true);
  assert.equal(hasMainAgentResult(logs.replace('messageChars=12', 'messageChars=0')), false);
});

test('keeps an earlier smoke assertion failure as FAIL when later steps are blocked', () => {
  assert.equal(bimSmokeStatus(['FAIL', 'BLOCKED']), 'FAIL');
  assert.equal(bimSmokeStatus(['BLOCKED']), 'BLOCKED');
  assert.equal(bimSmokeStatus(['PASS', 'PASS']), 'PASS');
});

test('lets a same-scenario provider blocker override stale passing UI', () => {
  assert.equal(bimScenarioStatus(true, 'model unavailable'), 'BLOCKED');
  assert.equal(bimScenarioStatus(false, 'model unavailable'), 'BLOCKED');
  assert.equal(bimScenarioStatus(false, ''), 'FAIL');
});

test('sanitizes an orchestration exception and completes all seven scenarios', () => {
  const raw = 'hdc failed https://example.test?a=1&api_key=secret Authorization: Bearer token123';
  const reason = sanitizeBimFailureReason(new Error(raw));
  const scenarios = completeBimScenarios([
    { id: 'home', status: 'PASS', ok: true }
  ], reason, 'directory');
  assert.equal(reason.includes('secret'), false);
  assert.equal(reason.includes('token123'), false);
  assert.equal(sanitizeBimFailureReason(''), '');
  assert.equal(scenarios.length, 7);
  assert.equal(scenarios.find((scenario) => scenario.id === 'directory')?.status, 'FAIL');
  assert.equal(scenarios.find((scenario) => scenario.id === 'detail')?.status, 'BLOCKED');
  assert.equal(scenarios.find((scenario) => scenario.id === 'sentinel')?.status, 'BLOCKED');
});

test('requires scheduled, triggered, and completed Sentinel evidence', () => {
  assert.deepEqual(bimSentinelEvidence([
    '[AIPhone][BimSentinelMockScheduled] reminderId=17 delaySeconds=10',
    '[AIPhone][BimSentinelMockTriggered] ok=true',
    '[AIPhone][BimSentinel] mode=mock events=2 ok=true'
  ].join('\n')), {
    scheduled: true,
    triggered: true,
    completed: true,
    eventCount: 2,
    transport: 'reminder'
  });
  assert.deepEqual(bimSentinelEvidence(
    '[AIPhone][BimSentinelMockScheduled] reminderId=17 delaySeconds=10'
  ), {
    scheduled: true,
    triggered: false,
    completed: false,
    eventCount: null,
    transport: 'reminder'
  });
  assert.deepEqual(bimSentinelEvidence([
    '[AIPhone][BimSentinelMockScheduled] transport=in_app_timer delaySeconds=10',
    '[AIPhone][BimSentinelMockTriggered] ok=true',
    '[AIPhone][BimSentinel] mode=mock events=0 ok=true'
  ].join('\n')), {
    scheduled: true,
    triggered: true,
    completed: true,
    eventCount: 0,
    transport: 'in_app_timer'
  });
});

test('keeps the app foreground for the explicit Sentinel timer fallback', () => {
  assert.equal(bimSentinelUsesInAppTimer([
    '心上事', '系统提醒已满，10 秒后应用内测试'
  ]), true);
  assert.equal(bimSentinelUsesInAppTimer(['检查心上事（测试）']), false);
});

test('lists the standalone BIM smoke case without requiring a device', () => {
  const result = spawnSync(process.execPath, [
    'scripts/aiphone-device-smoke.mjs', '--bim', '--list-cases'
  ], { cwd: process.cwd(), encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), [{
    id: 'BIM',
    mode: 'device-smoke',
    automated: true,
    preservesAppData: true,
    requires: ['local-model', 'heart-things']
  }]);
});

test('captures target-discovery failure while ignoring sibling evidence directories', () => {
  const outDir = mkdtempSync(join(tmpdir(), 'aiphone-bim-smoke-target-'));
  try {
    mkdirSync(join(outDir, 'bim-existing-directory'));
    const result = spawnSync(process.execPath, [
      'scripts/aiphone-device-smoke.mjs', '--bim'
    ], {
      cwd: process.cwd(),
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: '',
        AIPHONE_SMOKE_CLEAN_DATA: '0',
        AIPHONE_SMOKE_OUT_DIR: outDir,
        AIPHONE_HDC_TARGET: ''
      }
    });
    assert.equal(result.status, 1, result.stderr);
    const summary = JSON.parse(readFileSync(join(outDir, 'bim-summary.json'), 'utf8'));
    assert.equal(summary.status, 'FAIL');
    assert.equal(summary.scenarios.length, 7);
    assert.match(summary.reason, /hdc list targets failed/);
    assert.match(readFileSync(join(outDir, 'screenshots-index.md'), 'utf8'), /真机场景截图索引/);
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
});
