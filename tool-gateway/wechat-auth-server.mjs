import http from 'node:http';
import { isIP } from 'node:net';
import { constants, createPrivateKey, sign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

function reply(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify(value));
}

export function createWechatAuthServer({ appId, appSecret, privateKey, fetchImpl = fetch }) {
  if (!/^wx[a-zA-Z0-9]{16}$/.test(appId) || !appSecret || !privateKey) {
    throw new Error('Configure WECHAT_APP_ID, WECHAT_APP_SECRET and AGC_AUTH_PRIVATE_KEY_PATH.');
  }
  const key = typeof privateKey === 'string' ? createPrivateKey(privateKey) : privateKey;
  if (key.asymmetricKeyType !== 'rsa' || key.asymmetricKeyDetails.modulusLength < 3072) {
    throw new Error('AGC requires an RSA private key of at least 3072 bits.');
  }
  // ponytail: one-process IP throttling; use the reverse proxy rate limiter before scaling to multiple instances.
  const requests = new Map();
  let windowStart = Date.now();
  const server = http.createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== '/auth/wechat') {
      reply(res, 404, { message: '接口不存在。' }); return;
    }
    if (Date.now() - windowStart >= 60_000) { requests.clear(); windowStart = Date.now(); }
    // Only a trusted loopback reverse proxy may supply X-Real-IP; it must overwrite the client header.
    const peer = req.socket.remoteAddress;
    const forwarded = req.headers['x-real-ip'];
    const loopback = peer === '127.0.0.1' || peer === '::1' || peer === '::ffff:127.0.0.1';
    const ip = loopback && typeof forwarded === 'string' && isIP(forwarded) ? forwarded : peer;
    const count = requests.get(ip) || 0;
    if (count >= 60 || requests.size >= 10000 && !requests.has(ip)) {
      reply(res, 429, { message: '请求过于频繁，请稍后重试。' }); return;
    }
    requests.set(ip, count + 1);
    if (!/^application\/json(?:;|$)/i.test(req.headers['content-type'] || '')) {
      reply(res, 415, { message: '请求格式错误。' }); return;
    }
    let bytes = 0;
    const chunks = [];
    try {
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 4096) { reply(res, 413, { message: '请求过大。' }); return; }
        chunks.push(chunk);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch {
        reply(res, 400, { message: '请求格式错误。' }); return;
      }
      if (!body || typeof body.code !== 'string' || !/^[A-Za-z0-9_-]{1,256}$/.test(body.code)) {
        reply(res, 400, { message: '微信授权码无效。' }); return;
      }
      const url = new URL('https://api.weixin.qq.com/sns/oauth2/access_token');
      url.search = new URLSearchParams({ appid: appId, secret: appSecret, code: body.code, grant_type: 'authorization_code' });
      const upstream = await fetchImpl(url, { signal: AbortSignal.timeout(10000), redirect: 'error' });
      if (!upstream.ok) throw new Error('WeChat unavailable');
      const identity = await upstream.json();
      if (!identity || identity.errcode || typeof identity.access_token !== 'string' || !identity.access_token ||
          typeof identity.openid !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(identity.openid)) {
        reply(res, 401, { message: '微信授权已失效，请重新登录。' }); return;
      }
      // AGC's documented self-account format uses an RS256 header with RSA-PSS signing,
      // matching @agconnect/auth-server 1.2.0 Auth.sign (not a general-purpose JWT implementation).
      const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64');
      const payload = Buffer.from(JSON.stringify({ uid: `wechat:${appId}:${identity.openid}`,
        photoUrl: '', displayName: '微信用户', exp: Math.floor(Date.now() / 1000) + 300 })).toString('base64');
      const unsigned = header + '.' + payload;
      const signature = sign('RSA-SHA256', Buffer.from(unsigned), {
        key, padding: constants.RSA_PKCS1_PSS_PADDING, saltLength: constants.RSA_PSS_SALTLEN_DIGEST
      }).toString('base64url');
      reply(res, 200, { accessToken: unsigned + '.' + signature });
    } catch {
      if (!res.headersSent) reply(res, 502, { message: '微信登录服务暂不可用，请稍后重试。' });
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const privateKey = readFileSync(process.env.AGC_AUTH_PRIVATE_KEY_PATH, 'utf8');
  createWechatAuthServer({ appId: process.env.WECHAT_APP_ID, appSecret: process.env.WECHAT_APP_SECRET, privateKey })
    .listen(Number(process.env.WECHAT_AUTH_PORT || 8789), '127.0.0.1', () => {
      console.log('WeChat auth service listening on loopback; expose /auth/wechat through HTTPS.');
    });
}
