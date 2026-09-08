import assert from 'node:assert/strict';
import { generateKeyPairSync, sign, constants } from 'node:crypto';
import { once } from 'node:events';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { aliyunSmsSender, createAgcSmsServer, signAliyunParams } from '../tool-gateway/agc-sms-server.mjs';

test('AGC login SMS authenticates requests, preserves the code and prevents duplicate sends', async () => {
  assert.equal(signAliyunParams({ Action: 'Test', Value: "a b!*'()" }, 'testsecret'), 'P+7d+DHgwLW4RcYeIcTgysGtiT4=');
  const identityCalls = [];
  const roleSender = aliyunSmsSender({ roleName: 'appless-sms-relay', signName: '测试签名', validMinutes: 5,
    fetchImpl: async (url, options) => {
      identityCalls.push(url);
      if (url.endsWith('/api/token')) {
        assert.equal(options.method, 'PUT');
        return { ok: true, text: async () => 'metadata-token' };
      }
      if (url.includes('/security-credentials/')) {
        assert.equal(options.headers['X-aliyun-ecs-metadata-token'], 'metadata-token');
        return { ok: true, json: async () => ({ Code: 'Success', AccessKeyId: 'temporary-id', AccessKeySecret: 'temporary-secret',
          SecurityToken: 'temporary-token', Expiration: new Date(Date.now() + 60000).toISOString() }) };
      }
      const params = new URLSearchParams(options.body);
      assert.equal(params.get('AccessKeyId'), 'temporary-id');
      assert.equal(params.get('SecurityToken'), 'temporary-token');
      return { ok: true, json: async () => ({ Code: 'OK', Success: true }) };
    } });
  await roleSender({ phoneNumber: '+86-13800000000', verifyCode: '012345', taskId: 'role-test' });
  assert.equal(identityCalls.length, 3);
  const pair = generateKeyPairSync('rsa', { modulusLength: 3072 });
  const callbackUrl = 'https://example.com/auth/agc/sms';
  const projectId = '101653523864733533';
  let time = Date.now(), sends = 0, fail = false;
  const sender = aliyunSmsSender({ accessKeyId: 'testid', accessKeySecret: 'testsecret', signName: '测试签名', validMinutes: 5,
    fetchImpl: async (url, options) => {
      assert.equal(url, 'https://dypnsapi.aliyuncs.com/');
      const params = new URLSearchParams(options.body);
      assert.equal(params.get('Action'), 'SendSmsVerifyCode');
      assert.deepEqual(JSON.parse(params.get('TemplateParam')), { code: '012345', min: '5' });
      assert.equal(params.get('PhoneNumber'), '13800000000');
      assert.equal(params.get('ReturnVerifyCode'), 'false');
      assert.ok(!options.body.includes('testsecret'));
      sends++;
      return { ok: !fail, json: async () => ({ Code: fail ? 'ERROR' : 'OK', Success: !fail }) };
    } });
  const directory = mkdtempSync(join(tmpdir(), 'appless-sms-'));
  const statePath = join(directory, 'state.json');
  const privatePath = join(directory, 'test-key.pem');
  const certificatePath = join(directory, 'test-cert.pem');
  writeFileSync(privatePath, pair.privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
  execFileSync('openssl', ['req', '-new', '-x509', '-key', privatePath, '-out', certificatePath,
    '-days', '1', '-subj', '/CN=SMS test'], { stdio: 'pipe' });
  const spki = pair.publicKey.export({ type: 'spki', format: 'pem' });
  const config = { callbackUrl, projectId, statePath,
    publicKeys: [readFileSync(certificatePath, 'utf8'), spki, spki.replaceAll('PUBLIC KEY', 'CERTIFICATE')],
    sendSms: sender, now: () => time };
  assert.throws(() => createAgcSmsServer({ ...config, publicKeys: ['invalid key'] }));
  let server = createAgcSmsServer(config);
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  let url = `http://127.0.0.1:${server.address().port}/auth/agc/sms`;
  // AGC console sends a bare mainland number; the documented callback uses +86-.
  const body = { action: '1001', phoneNumber: '13800000000', productId: projectId, taskId: 'task-1', verifyCode: '012345' };
  const headers = (value = body, timestamp = time, signedUrl = callbackUrl) => ({
    'content-type': 'application/json', 'x-agc-timestamp': String(timestamp),
    'x-agc-auth': sign('RSA-SHA256', Buffer.from(['POST', signedUrl, timestamp, JSON.stringify(value)].join('\n')), {
      key: pair.privateKey, padding: constants.RSA_PKCS1_PSS_PADDING, saltLength: constants.RSA_PSS_SALTLEN_DIGEST
    }).toString('base64')
  });
  const post = (value = body, signedHeaders = headers(value)) => fetch(url, {
    method: 'POST', headers: signedHeaders, body: JSON.stringify(value)
  });
  try {
    assert.equal((await post(body, {})).status, 401);
    assert.equal((await post({ ...body, verifyCode: '999999' }, headers())).status, 401);
    assert.equal((await post(body, headers(body, time - 180001))).status, 401);
    assert.equal((await post(body, headers(body, time + 180001))).status, 401);
    assert.equal((await post(body, headers(body, time, callbackUrl + '/wrong'))).status, 401);
    assert.equal((await post({ ...body, productId: '999' })).status, 400);
    assert.equal((await post({ ...body, action: '1003', verifyCode: '' })).status, 400);
    assert.equal((await post({ ...body, phoneNumber: '+1-13800000000' })).status, 400);
    assert.equal((await post({ ...body, phoneNumber: '8613800000000' })).status, 400);
    assert.equal((await post({ ...body, extra: 'x'.repeat(5000) })).status, 413);
    assert.equal(sends, 0);
    const results = await Promise.all([post(), post()]);
    assert.equal(sends, 1);
    assert.ok((await Promise.all(results.map(r => r.json()))).some(r => r.code === '0'));
    const repeated = await (await post()).json();
    assert.deepEqual(repeated, { code: '0', message: 'OK', requestId: 'task-1' });
    assert.ok(!JSON.stringify(repeated).includes(body.verifyCode));
    assert.equal(sends, 1);
    assert.equal((await post({ ...body, phoneNumber: '+86-13800000000', taskId: 'task-2' })).status, 429);
    time += 61000; fail = true;
    assert.equal((await (await post({ ...body, phoneNumber: '+86-13800000000', taskId: 'task-2' })).json()).code, 'SEND_FAILED');
    assert.equal(sends, 2);
    await post({ ...body, taskId: 'task-2' });
    assert.equal(sends, 2);
    const stored = readFileSync(statePath, 'utf8');
    assert.ok(!stored.includes(body.phoneNumber) && !stored.includes(body.verifyCode));
    server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
    server = createAgcSmsServer(config);
    server.listen(0, '127.0.0.1'); await once(server, 'listening');
    url = `http://127.0.0.1:${server.address().port}/auth/agc/sms`;
    assert.equal((await (await post()).json()).code, '0');
    assert.equal((await (await post({ ...body, taskId: 'task-2' })).json()).code, 'DUPLICATE');
    assert.equal((await post({ ...body, taskId: 'task-3' })).status, 429);
    assert.equal(sends, 2);
  } finally {
    server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
    rmSync(directory, { recursive: true });
  }
});
