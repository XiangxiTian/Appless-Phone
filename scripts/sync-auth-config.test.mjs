import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { syncAuthConfig } from './sync-auth-config.mjs';

test('build provisions matching private AGC config and rejects missing or mismatched config', () => {
  const root = mkdtempSync(join(tmpdir(), 'appless-auth-config-'));
  try {
    mkdirSync(join(root, 'AppScope'));
    mkdirSync(join(root, 'entry/src/main'), { recursive: true });
    writeFileSync(join(root, 'AppScope/app.json5'), '{ "app": { "bundleName": "test.app" } }');
    writeFileSync(join(root, 'entry/src/main/module.json5'), '{ "metadata": [{ "name": "client_id", "value": "123" }] }');
    const source = join(root, 'private.json');
    assert.throws(() => syncAuthConfig(root, source), /Missing AGC/);
    const config = { client: { package_name: 'test.app', app_id: '123', project_id: '1', product_id: '2', api_key: 'test' } };
    writeFileSync(source, JSON.stringify(config));
    syncAuthConfig(root, source);
    const output = join(root, 'entry/src/main/resources/rawfile/agconnect-services.json');
    assert.deepEqual(JSON.parse(readFileSync(output)), config);
    config.client.app_id = 'another-app';
    writeFileSync(source, JSON.stringify(config));
    assert.throws(() => syncAuthConfig(root, source), /does not match/);
    assert.equal(JSON.parse(readFileSync(output)).client.app_id, '123');
  } finally { rmSync(root, { recursive: true, force: true }); }
});
