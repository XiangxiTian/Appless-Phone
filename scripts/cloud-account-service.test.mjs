import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { runInNewContext } from 'node:vm';
import { test } from 'node:test';

// Use the same installed compiler as the HarmonyOS build; exercise the service, not a copy of its logic.
const require = createRequire(import.meta.url);
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');
const source = readFileSync(new URL('../entry/src/main/ets/account/CloudAccountService.ets', import.meta.url), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText;

test('first login skips SDK signOut without a user; later logout is idempotent and real failures propagate', async () => {
  let user = null;
  let signIns = 0;
  let signOuts = 0;
  let lookupFailure = false;
  const auth = {
    init() {},
    async getCurrentUser() { if (lookupFailure) throw new Error('session read failed'); return user; },
    async signOut() {
      if (user === null) throw new Error('1210002: no user signed in');
      signOuts++;
      user = null;
    },
    async signIn() {
      signIns++;
      user = {
        getUid: () => 'verified-user', getDisplayName: () => '', isAnonymous: () => false,
        async getToken() { throw new Error('network offline'); }
      };
      return { getUser: () => user };
    }
  };
  const dependencies = {
    '@ohos.util': { default: { TextDecoder: { create: () => ({ decodeToString: () => '{}' }) } } },
    '@hw-agconnect/auth': { default: auth },
    '@kit.PerformanceAnalysisKit': { hilog: { error() {} } },
    './HuaweiAccountService': { HuaweiAccountPublicError: class extends Error {} },
    './WechatAccountService': {}
  };
  const exports = {};
  runInNewContext(compiled, { exports, require: name => {
    assert.ok(Object.hasOwn(dependencies, name), `unexpected import: ${name}`);
    return dependencies[name];
  }, Error });
  const service = new exports.AgcCloudAccountService({ resourceManager: { getRawFileContentSync: () => new Uint8Array() } });
  assert.equal((await service.loginPhone('13800138000', '123456')).uid, 'verified-user');
  assert.equal(signOuts, 0);
  const reopened = new exports.AgcCloudAccountService({ resourceManager: { getRawFileContentSync: () => new Uint8Array() } });
  assert.equal((await reopened.restore()).uid, 'verified-user', 'persisted SDK session restores local data offline');
  await service.loginHuawei();
  assert.equal(signOuts, 1);
  await service.signOut();
  await service.signOut();
  assert.equal(signOuts, 2);
  assert.equal(await reopened.restore(), null, 'signed-out SDK state must not restore an account');
  lookupFailure = true;
  await assert.rejects(reopened.restore(), /session read failed/);
  await assert.rejects(service.loginPhone('13800138000', '123456'), /session read failed/);
  assert.equal(signIns, 2);
});
