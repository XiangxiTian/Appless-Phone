import fs from 'node:fs';
import path from 'node:path';

const repoRoot = path.resolve(new URL('..', import.meta.url).pathname);
const uiRoot = path.join(repoRoot, 'agent_core', 'src', 'main', 'ets', 'aiphone', 'ui');
const forbidden = [
  /(?:^|["'])entry\//,
  /@ohos\//,
  /WebView(?:Controller|Surface|Renderer)/i,
  /MultiAgent(?:Canary)?Runtime/
];

function filesIn(directory) {
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...filesIn(fullPath));
    else if (entry.isFile() && fullPath.endsWith('.ets')) result.push(fullPath);
  }
  return result;
}

const violations = [];
for (const file of filesIn(uiRoot)) {
  const content = fs.readFileSync(file, 'utf8');
  for (const pattern of forbidden) {
    if (pattern.test(content)) violations.push(`${path.relative(repoRoot, file)} matches ${pattern}`);
  }
}

if (violations.length > 0) {
  console.error('ui-v4 dependency boundary failed');
  violations.forEach((value) => console.error(value));
  process.exitCode = 1;
} else {
  console.log(`ui-v4 dependency boundary passed (${filesIn(uiRoot).length} ETS files)`);
}
