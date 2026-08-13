# Public Persona 20 Native Sources Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add exactly 20 real-device-verified native public-profile sources to the existing four-source catalog while keeping the initial username scan completely independent of Firecrawl.

**Architecture:** Extend the existing `PublicPersonaProbe` catalog and `probePublicPersonaProfile()` path instead of adding a crawler runtime or per-source client classes. The catalog builds display/probe URLs, classifies Maigret-style message/status responses, and binds every claimed response to an account username, canonical URL, and HTTPS avatar. The current orchestrator remains concurrent and non-blocking; exact discovery uses only native HTTP, while fuzzy discovery retains one optional Search call after every native source terminates.

**Tech Stack:** HarmonyOS ArkTS, `@ohos.net.http`, Hypium, existing Node smoke runner, existing hvigor/Loopy verification scripts.

## Global Constraints

- Base and PR target remain `multiagent-backend`; branch remains `codex/public-persona-demo`.
- Keep the existing Bilibili, Zhihu, Weibo, and GitHub sources and add exactly 20 enabled sources.
- Do not add a Python runtime, Maigret dependency, crawler dependency, device cache, or discovery snapshot.
- Initial native scan and explicit-link verification call neither `web.research.search` nor `web.page.read`.
- Fuzzy mode may call `web.research.search` at most once, only after all native terminal states, and must natively re-verify every returned row.
- A source passes only when one final signed HAP returns claimed=`found`, unclaimed=`not_found`, and a fresh random fake=`not_found` on one real device.
- Timeout, login wall, CAPTCHA, 401, 403, 429, 5xx, transport error, soft-200, or generic shell is `unknown`, never pass.
- Every found account must expose its own HTTPS avatar, display name or username, and canonical profile URL; a platform logo cannot satisfy this gate.
- Candidate display remains capped at 10 accounts; discovery still scans all 24 enabled sources.
- No changes to `agent_core`, existing memory/context integration, snapshot schema, or model inference contract.

---

### Task 1: Make the probe catalog data-driven

**Files:**
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaModel.ets`
- Test: `entry/src/test/PublicPersona.test.ets`

**Interfaces:**
- Produces: `PublicPersonaProbeCheckType = 'message' | 'status_code'`
- Extends: `PublicPersonaProbe` with `checkType`, `enabled`, `usernameClaimed`, `usernameUnclaimed`, and optional `requestHeaders`
- Produces: `publicPersonaPlatformLabel(platform): string`
- Keeps: `publicPersonaCatalog(): PublicPersonaProbe[]`
- Keeps: `publicPersonaProfileUrl`, `parsePublicProfileUrl`, and `publicPersonaUsernameFromProfileUrl`, but makes them template-driven for path and subdomain URLs

- [ ] **Step 1: Write failing catalog and template tests**

Add focused Hypium cases with the following assertions:

```ts
const probes = publicPersonaCatalog();
expect(probes.length).assertEqual(4);
expect(probes.every((probe): boolean =>
  probe.usernameClaimed.length > 0 && probe.usernameUnclaimed.length > 0)).assertTrue();

const syntheticPathProbe = {
  ...probes[0], displayUrlTemplate: 'https://example.com/people/{username}/',
  probeUrlTemplate: 'https://example.com/api/{username}'
};
expect(publicPersonaProfileUrl(syntheticPathProbe, 'FooBar'))
  .assertEqual('https://example.com/people/FooBar/');

const syntheticHostProbe = {
  ...probes[0], displayUrlTemplate: 'https://{username}.example.com/',
  probeUrlTemplate: 'https://{username}.example.com/'
};
expect(publicPersonaProfileUrl(syntheticHostProbe, 'foto'))
  .assertEqual('https://foto.example.com/');
```

Also assert that reserved non-profile paths remain rejected and that case-sensitive platforms preserve the original path segment.

- [ ] **Step 2: Run Hypium and verify RED**

Run:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test \
  -p product=default -p module=entry@default -p testType=unit --no-daemon
```

Expected: new config fields and template-driven assertions fail against the current catalog.

- [ ] **Step 3: Implement the minimal catalog contract**

Add these fields to the existing interface rather than introducing a second source model:

```ts
export type PublicPersonaProbeCheckType = 'message' | 'status_code';

export interface PublicPersonaProbe {
  platform: PublicPersonaPlatform;
  label: string;
  domains: string[];
  profilePathPatterns: string[];
  displayUrlTemplate: string;
  probeUrlTemplate: string;
  usernamePattern: string;
  caseSensitiveUsername: boolean;
  checkType: PublicPersonaProbeCheckType;
  enabled: boolean;
  usernameClaimed: string;
  usernameUnclaimed: string;
  presenceMarkers: string[];
  missingMarkers: string[];
  errorMarkers: string[];
  requestHeaders?: Record<string, string>;
}
```

Replace the platform-specific `profilePathAllowed()` / `profileUsername()` growth path with one bounded `{username}` template matcher supporting username in the host or path. Retain the existing GitHub/X reserved-root checks and existing Weibo numeric display special case. `publicPersonaCatalog()` filters `enabled` and returns defensive copies.

- [ ] **Step 4: Run Hypium and verify GREEN**

Run the Step 2 command and verify the generated `test_result.txt` reports `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/publicpersona/PublicPersonaModel.ets entry/src/test/PublicPersona.test.ets
git commit -m "refactor(public-persona): make native probes data driven"
```

---

### Task 2: Enforce Maigret-style states without soft-200 false positives

**Files:**
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaModel.ets`
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets`
- Test: `entry/src/test/PublicPersona.test.ets`

**Interfaces:**
- Keeps: `classifyPublicPersonaProbe(probe, statusCode, body): PublicPersonaProbeState`
- Changes: `PublicPersonaHttpCaller` to accept a `PublicPersonaHttpRequest` containing URL and optional headers
- Keeps: `probePublicPersonaProfile(probe, username, httpCaller)` as the production/device test seam

- [ ] **Step 1: Write failing classifier and identity tests**

Add cases proving this order:

```ts
expect(classifyPublicPersonaProbe(douban, 200, '验证码 db-usr-profile')).assertEqual('unknown');
expect(classifyPublicPersonaProbe(douban, 429, 'db-usr-profile')).assertEqual('unknown');
expect(classifyPublicPersonaProbe(douban, 404, '')).assertEqual('not_found');
expect(classifyPublicPersonaProbe(douban, 410, '返回首页')).assertEqual('unknown');
expect(classifyPublicPersonaProbe(douban, 200, '返回首页')).assertEqual('not_found');
expect(classifyPublicPersonaProbe(douban, 200, 'db-usr-profile')).assertEqual('found');
expect(classifyPublicPersonaProbe(douban, 200, '<html>generic shell</html>')).assertEqual('unknown');
```

Add a complete generic OG-shell fixture whose canonical/OG image are site-generic and assert the final native result is `unknown`. Add a claimed profile fixture bound to the requested username and assert `found` with its account avatar.

- [ ] **Step 2: Run Hypium and verify RED**

Run the Task 1 command. Expected: 200 account-specific absence and request-header tests fail.

- [ ] **Step 3: Implement classification and request metadata**

Use this exact classification order:

```ts
if (transportOrErrorMarker) return 'unknown';
if ([401, 403, 429].includes(statusCode) || statusCode >= 500 || statusCode <= 0) return 'unknown';
if (statusCode === 404) return 'not_found';
if (statusCode === 410) return 'unknown';
if (probe.checkType === 'message' && bodyHasMarker(body, probe.missingMarkers)) return 'not_found';
if (probe.checkType === 'message' && !bodyHasMarker(body, probe.presenceMarkers)) return 'unknown';
return statusCode >= 200 && statusCode < 300 ? 'found' : 'unknown';
```

Merge configured probe headers with the existing mobile User-Agent/Accept headers. Do not add automatic retries. A found response becomes a candidate only after username/canonical/avatar identity binding succeeds.

- [ ] **Step 4: Run Hypium and verify GREEN**

Run the Task 1 command and verify `Failure: 0, Error: 0`.

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/publicpersona/PublicPersonaModel.ets \
  entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets entry/src/test/PublicPersona.test.ets
git commit -m "fix(public-persona): reject native soft profile shells"
```

---

### Task 3: Add the first 20 candidate templates and reusable identity extraction

**Files:**
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaModel.ets`
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets`
- Test: `entry/src/test/PublicPersona.test.ets`

**Interfaces:**
- Adds platform literals for the ordered first batch in the design spec
- Extends the existing JSON parser only for response shapes that cannot use canonical/OG metadata
- Keeps generic HTML parsing for candidate sources with account-specific canonical, title, avatar, and bio tags

- [ ] **Step 1: Add failing source-table tests**

Use the exact templates and fixtures from `docs/research/public-persona-maigret-native-sources.md`. Assert at minimum:

```ts
assertProbe('qq', '10001',
  'https://users.qzone.qq.com/fcg-bin/cgi_get_portrait.fcg?uins=10001');
assertProbe('tieba', 'maigret',
  'https://tieba.baidu.com/i/sys/user_json?un=maigret&ie=utf-8');
assertProbe('npm', 'sindresorhus',
  'https://registry.npmjs.org/-/v1/search?text=maintainer:sindresorhus&size=1');
assertProbe('stackoverflow', 'maigret',
  'https://api.stackexchange.com/2.3/users?order=desc&sort=name&inname=maigret&site=stackoverflow');
assertProbe('gitlab', 'blue', 'https://gitlab.com/api/v4/users?username=blue');
assertProbe('dockerhub', 'blue', 'https://hub.docker.com/v2/users/blue/');
assertProbe('keybase', 'blue',
  'https://keybase.io/_/api/1.0/user/lookup.json?usernames=blue');
```

For each enabled source, inject a claimed body, unclaimed body/status, and generic shell. Assert claimed returns a bound identity with HTTPS avatar, unclaimed returns `not_found`, and generic shell returns `unknown`.

- [ ] **Step 2: Run Hypium and verify RED**

Run the Task 1 command. Expected: new source/platform fixtures fail because the catalog entries and identity shapes do not exist.

- [ ] **Step 3: Add the ordered source configs**

Add the first 20 candidate configs in the design-spec order using their official Maigret URL, probe, regex, presence, absence, errors, claimed, and unclaimed values. Mark this first batch enabled only in the local validation build so the existing page and smoke path exercise production code; do not push or describe this provisional batch as supported. Existing four sources remain enabled.

Implement only the JSON shapes required by candidates that survive fixture tests. Use the existing `jsonRecord`, `recordText`, `childRecord`, meta extraction, and canonical parsing helpers. If an API existence response lacks identity/avatar fields, perform one native GET of `displayUrl` and require account-specific canonical and avatar metadata before returning `found`.

- [ ] **Step 4: Run Hypium and verify GREEN for disabled candidates**

Run the Task 1 command. Verify all per-source parser tests pass and the provisional validation catalog contains 24 sources: the existing four plus the first 20 candidates.

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/publicpersona/PublicPersonaModel.ets \
  entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets entry/src/test/PublicPersona.test.ets
git commit -m "feat(public-persona): add native source candidates"
```

---

### Task 4: Keep orchestration and UI catalog-driven

**Files:**
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaClient.ets`
- Modify: `entry/src/main/ets/pages/A2uiHome/components/PublicPersonaPage.ets`
- Modify: `scripts/multi-agent-smoke-evidence.test.mjs`
- Test: `entry/src/test/PublicPersona.test.ets`

**Interfaces:**
- Keeps: `discover(username, mode, onProgress)` and concurrency 3
- Uses: `publicPersonaPlatformLabel(platform)` for all user-facing labels
- Uses: one generic `app.media.icon_social` badge for a source lacking a dedicated platform asset; confirmed rows still require their account avatar

- [ ] **Step 1: Write failing Firecrawl-budget and UI-source tests**

Add tests proving:

```ts
await client.discover('known', 'exact', progressListener);
expect(toolIds.length).assertEqual(0);
expect(terminalProgress.length).assertEqual(publicPersonaCatalog().length);

await fuzzyClient.discover('known', 'fuzzy', progressListener);
expect(toolIds.join(',')).assertEqual('web.research.search');
expect(firstToolCallAfterNativeTerminalCount).assertEqual(publicPersonaCatalog().length);
expect(fuzzyCandidates.every((item): boolean => item.providerState === 'success')).assertTrue();
```

Update Node source assertions so platform text resolves through catalog metadata and the progress total is derived from `publicPersonaCatalog().length`, not a static 4/11/24 literal.

- [ ] **Step 2: Run Hypium and Node tests and verify RED**

Run the Task 1 command, then:

```bash
node --test scripts/multi-agent-smoke-evidence.test.mjs
```

Expected: the catalog-label and new tool-order assertions fail.

- [ ] **Step 3: Make the minimal orchestration/UI changes**

Keep the current concurrency-3 worker pool. Do not change ranking, candidate cap, selection behavior, snapshot generation, or fuzzy alias rules. Replace the page label switch with `publicPersonaPlatformLabel()`. Keep dedicated assets for existing platforms and return `$r('app.media.icon_social')` from the default badge branch.

Ensure every native source records one terminal state. A skipped invalid username is `not_found` only when the platform regex proves it cannot be an account; transport/provider failures remain `unknown`.

- [ ] **Step 4: Run Hypium and Node tests and verify GREEN**

Run both Step 2 commands and verify zero failures/errors.

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/publicpersona/PublicPersonaClient.ets \
  entry/src/main/ets/pages/A2uiHome/components/PublicPersonaPage.ets \
  scripts/multi-agent-smoke-evidence.test.mjs entry/src/test/PublicPersona.test.ets
git commit -m "feat(public-persona): drive expanded discovery from catalog"
```

---

### Task 5: Add a truthful per-source device admission matrix

**Files:**
- Modify: `scripts/aiphone-device-smoke.mjs`
- Modify: `scripts/multi-agent-smoke-evidence.test.mjs`
- Create at runtime only: `output/public-persona-native-20-<timestamp>/matrix.json`

**Interfaces:**
- Consumes env: `AIPHONE_PUBLIC_PERSONA_EXPECTED_PLATFORM`, `AIPHONE_PUBLIC_PERSONA_USERNAME`, `AIPHONE_PUBLIC_PERSONA_EXPECTED_STATE`
- Produces one JSON row with: `platform`, `fixtureClass`, `username`, `hapSha256`, `device`, `status`, `bodyLength`, `matchedRule`, `state`, `timestamp`
- Exits nonzero unless the expected platform reaches the exact expected terminal state

- [ ] **Step 1: Add failing Node assertions for the admission contract**

Assert the smoke runner rejects `unknown`, `timeout`, `rate_limited`, missing platform state, and claimed rows without a visible account avatar/username. Assert an unclaimed pass requires a structured `not_found` state for the requested platform rather than only a global count or HiLog string.

- [ ] **Step 2: Run Node tests and verify RED**

```bash
node --test scripts/multi-agent-smoke-evidence.test.mjs
```

Expected: structured expected-platform/expected-state checks are absent.

- [ ] **Step 3: Implement the smallest matrix mode**

Reuse the existing public-persona smoke route and evidence directory. Add only the three env inputs and structured state assertion. Do not add a second device controller or clear application data. Redact response bodies and secrets; retain only lengths and matched rule names.

- [ ] **Step 4: Run Node tests and verify GREEN**

Run the Step 2 command and `node --check scripts/aiphone-device-smoke.mjs`.

- [ ] **Step 5: Commit**

```bash
git add scripts/aiphone-device-smoke.mjs scripts/multi-agent-smoke-evidence.test.mjs
git commit -m "test(public-persona): verify native source states on device"
```

---

### Task 6: Admit the highest-value 20 sources on one real device

**Files:**
- Modify: `entry/src/main/ets/publicpersona/PublicPersonaModel.ets`
- Modify only when a surviving source needs a proven parser fix: `entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets`
- Test: `entry/src/test/PublicPersona.test.ets`
- Evidence: `output/public-persona-native-20-<timestamp>/matrix.json`

**Interfaces:**
- Changes only `enabled` values and fixture-backed parser rules already introduced in Tasks 1–3
- Produces exactly 20 added enabled sources and 24 total enabled sources

- [ ] **Step 1: Confirm one device is idle without changing it**

List devices and verify the selected serial has no AIPhoneDemo PID, fport, smoke, uitest, or hilog owner. If occupied, use the other explicitly free device. Do not touch both devices.

- [ ] **Step 2: Build and hash one signed HAP**

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw assembleHap \
  -p product=default -p module=entry@default -p buildMode=debug --no-daemon
shasum -a 256 entry/build/default/outputs/default/entry-default-signed.hap
```

Install that exact HAP without clearing app data.

- [ ] **Step 3: Run three fixtures per candidate in priority order**

For each candidate, run claimed, official unclaimed, and a freshly generated valid random username through the production page/smoke path. Admit only this exact tuple:

```json
{"claimed":"found","unclaimed":"not_found","randomFake":"not_found"}
```

Also require the claimed UI row to show account avatar, platform label, display name, and username. Any other tuple rejects the candidate and advances to the next source in the design order. Do not weaken markers, add retries, or use Firecrawl to turn a rejection into a pass.

- [ ] **Step 4: Enable the first 20 passers and rerun the same final-HAP matrix**

Set `enabled: true` only for the 20 passed additions, update the catalog-count test to 24, rebuild once, reinstall, and rerun all 60 fixture checks using the new final HAP hash. A source that regresses in the final matrix is disabled and replaced.

- [ ] **Step 5: Run the final visible UI check**

Verify the page reports 24 source terminal states, a known claimed fixture produces its account row, a known unclaimed fixture produces no candidate, and exact mode records zero Firecrawl tool calls.

- [ ] **Step 6: Release the device**

Force-stop the app, stop this task's hilog/uitest/smoke processes, remove only this task's temporary device files, and verify PID and fport are empty.

- [ ] **Step 7: Commit the admitted catalog**

```bash
git add entry/src/main/ets/publicpersona/PublicPersonaModel.ets \
  entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets entry/src/test/PublicPersona.test.ets
git commit -m "feat(public-persona): enable 20 verified native sources"
```

---

### Task 7: Final regression and branch handoff

**Files:**
- No production files unless a failing gate identifies a root-cause defect

**Interfaces:**
- Produces verified test/build/device evidence for the existing PR branch

- [ ] **Step 1: Run all static gates**

```bash
git diff --check origin/multiagent-backend...HEAD
node --test scripts/multi-agent-smoke-evidence.test.mjs
node --check scripts/aiphone-device-smoke.mjs
node scripts/verify-loopy-backend.mjs
```

Run the full Hypium command from Task 1 and verify the generated `test_result.txt`, not only `BUILD SUCCESSFUL`.

- [ ] **Step 2: Build and hash the final signed HAP**

Run the Task 6 build/hash commands and verify the hash matches the final matrix evidence.

- [ ] **Step 3: Review scope**

Confirm no changes under `agent_core`, existing memory/context integration, snapshot schema, model inference, or unrelated UI. Confirm exactly 20 newly enabled sources and no candidate counted from an `unknown` device state.

- [ ] **Step 4: Push the branch and update the existing PR**

```bash
git push origin codex/public-persona-demo
```

Report separately: local tests, build, real-device source matrix, visible UI, rejected-source boundaries, final HAP hash, and device release state.
