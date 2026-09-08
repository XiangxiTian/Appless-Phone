import assert from 'node:assert/strict';
import { generateKeyPairSync, verify, constants } from 'node:crypto';
import { once } from 'node:events';
import { test } from 'node:test';
import { createWechatAuthServer } from '../tool-gateway/wechat-auth-server.mjs';

const keys = generateKeyPairSync('rsa', { modulusLength: 3072 });
test('WeChat exchange validates upstream identity, signs AGC credentials, and rejects bad requests', async () => {
  let calls = 0;
  const server = createWechatAuthServer({
    appId: 'wx1234567890abcdef', appSecret: 'server-secret', privateKey: keys.privateKey,
    fetchImpl: async url => {
      calls++;
      assert.equal(url.origin, 'https://api.weixin.qq.com');
      assert.equal(url.searchParams.get('appid'), 'wx1234567890abcdef');
      assert.equal(url.searchParams.get('secret'), 'server-secret');
      return Response.json(url.searchParams.get('code') === 'valid-code' ?
        { access_token: 'private-upstream-token', openid: 'verified-openid' } :
        { errcode: 40029, errmsg: 'upstream-secret-must-not-leak' });
    }
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const endpoint = `http://127.0.0.1:${server.address().port}/auth/wechat`;
  const send = (body, ip = '') => fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Real-IP': ip }, body: JSON.stringify(body) });
  try {
    const rejected = await send({ code: '', openid: 'forged' });
    assert.equal(rejected.status, 400);
    assert.equal(calls, 0);
    const invalid = await send({ code: 'bad-code' });
    assert.equal(invalid.status, 401);
    assert.ok(!(await invalid.text()).includes('upstream-secret'));
    const result = await send({ code: 'valid-code', openid: 'attacker', uid: 'admin' });
    assert.equal(result.status, 200);
    assert.equal(result.headers.get('cache-control'), 'no-store');
    const json = await result.json();
    const [header, payload, signature] = json.accessToken.split('.');
    const claims = JSON.parse(Buffer.from(payload, 'base64').toString());
    assert.equal(claims.uid, 'wechat:wx1234567890abcdef:verified-openid');
    assert.ok(claims.exp > Date.now() / 1000 && claims.exp <= Date.now() / 1000 + 301);
    assert.ok(verify('RSA-SHA256', Buffer.from(header + '.' + payload), {
      key: keys.publicKey, padding: constants.RSA_PKCS1_PSS_PADDING, saltLength: constants.RSA_PSS_SALTLEN_DIGEST
    }, Buffer.from(signature, 'base64url')));
    assert.ok(!JSON.stringify(json).includes('private-upstream-token'));
    for (let client = 1; client <= 62; client++) {
      assert.equal((await send({ code: 'valid-code' }, `198.51.100.${client}`)).status, 200);
    }
    for (let attempt = 1; attempt < 60; attempt++) {
      assert.equal((await send({ code: 'valid-code' }, '198.51.100.1')).status, 200);
    }
    assert.equal((await send({ code: 'valid-code' }, '198.51.100.1')).status, 429);
    const large = await send({ code: 'a'.repeat(5000) });
    assert.equal(large.status, 413);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
