import http from 'node:http';
import { constants, createHash, createHmac, createPublicKey, randomUUID, verify } from 'node:crypto';
import { closeSync, fsyncSync, openSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { dirname } from 'node:path';

const encode = value => encodeURIComponent(value).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase());
const hash = value => createHash('sha256').update(value).digest('hex');

// Alibaba Cloud RPC v2 signing. All parameters travel in the HTTPS POST body, never in logs.
export function signAliyunParams(params, secret) {
  const canonical = Object.keys(params).sort().map(k => `${encode(k)}=${encode(params[k])}`).join('&');
  return createHmac('sha1', secret + '&').update('POST&%2F&' + encode(canonical)).digest('base64');
}

export function aliyunSmsSender({ accessKeyId, accessKeySecret, securityToken, roleName, signName, validMinutes, fetchImpl = fetch }) {
  if ((!accessKeyId || !accessKeySecret) && !roleName || roleName && !/^[A-Za-z0-9_-]{1,64}$/.test(roleName) ||
      !signName || !Number.isSafeInteger(validMinutes) || validMinutes < 1 || validMinutes > 60) {
    throw new Error('Configure server-side Aliyun credentials, SMS_SIGN_NAME and SMS_CODE_VALID_MINUTES matching AGC.');
  }
  return async ({ phoneNumber, verifyCode, taskId }) => {
    let credentials = { accessKeyId, accessKeySecret, securityToken };
    if (roleName) {
      const metadata = 'http://100.100.100.200/latest/';
      const tokenResponse = await fetchImpl(metadata + 'api/token', {
        method: 'PUT', headers: { 'X-aliyun-ecs-metadata-token-ttl-seconds': '60' },
        redirect: 'error', signal: AbortSignal.timeout(1000)
      });
      if (!tokenResponse.ok) throw new Error('ECS identity unavailable');
      const response = await fetchImpl(metadata + 'meta-data/ram/security-credentials/' + encode(roleName), {
        headers: { 'X-aliyun-ecs-metadata-token': await tokenResponse.text() },
        redirect: 'error', signal: AbortSignal.timeout(1000)
      });
      const value = await response.json();
      if (!response.ok || value.Code !== 'Success' || !value.AccessKeyId || !value.AccessKeySecret ||
          !value.SecurityToken || !(Date.parse(value.Expiration) > Date.now() + 10000)) throw new Error('ECS identity unavailable');
      credentials = { accessKeyId: value.AccessKeyId, accessKeySecret: value.AccessKeySecret, securityToken: value.SecurityToken };
    }
    const params = {
      AccessKeyId: credentials.accessKeyId, Action: 'SendSmsVerifyCode', Version: '2017-05-25', Format: 'JSON',
      SignatureMethod: 'HMAC-SHA1', SignatureVersion: '1.0', SignatureNonce: randomUUID(),
      Timestamp: new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
      CountryCode: '86', PhoneNumber: phoneNumber.slice(4), SignName: signName, TemplateCode: '100001',
      // AGC owns the code and its validation. Never ask Aliyun to replace it with a generated code.
      TemplateParam: JSON.stringify({ code: verifyCode, min: String(validMinutes) }),
      Interval: '60', ReturnVerifyCode: 'false', AutoRetry: '0', OutId: taskId
    };
    if (credentials.securityToken) params.SecurityToken = credentials.securityToken;
    params.Signature = signAliyunParams(params, credentials.accessKeySecret);
    const response = await fetchImpl('https://dypnsapi.aliyuncs.com/', {
      method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(params).toString(), redirect: 'error', signal: AbortSignal.timeout(7000)
    });
    const result = await response.json();
    if (!response.ok || result?.Code !== 'OK' || result?.Success !== true) throw new Error('SMS provider rejected request.');
  };
}

function reply(res, status, code, message, requestId = '') {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  res.end(JSON.stringify({ code, message, requestId }));
}

export function createAgcSmsServer({ callbackUrl, projectId, publicKeys, sendSms, statePath, now = Date.now, dailyLimit = 100 }) {
  const url = new URL(callbackUrl);
  if (url.protocol !== 'https:' || url.username || url.password || url.hash || url.search ||
      !/^\d+$/.test(projectId) || !Number.isSafeInteger(dailyLimit) || dailyLimit < 1 || typeof sendSms !== 'function' || !statePath) {
    throw new Error('Configure the exact public HTTPS callback URL, AGC project and SMS sender.');
  }
  const keys = publicKeys.map(key => {
    try { return createPublicKey(key); }
    catch (error) {
      // The live AGC endpoint also wraps SPKI DER in CERTIFICATE boundaries.
      // Parse real X.509 certificates normally before handling that legacy format.
      if (typeof key !== 'string' || !key.startsWith('-----BEGIN CERTIFICATE-----')) throw error;
      return createPublicKey(key.replace('-----BEGIN CERTIFICATE-----', '-----BEGIN PUBLIC KEY-----')
        .replace('-----END CERTIFICATE-----', '-----END PUBLIC KEY-----'));
    }
  });
  if (!keys.length || keys.some(key => key.asymmetricKeyType !== 'rsa')) throw new Error('AGC RSA signing keys required.');
  // ponytail: one process owns this file; use a transactional shared store before adding workers.
  let saved = { tasks: [], phones: [], day: '', sentToday: 0 };
  try { saved = JSON.parse(readFileSync(statePath, 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (!Array.isArray(saved.tasks) || !Array.isArray(saved.phones) || typeof saved.day !== 'string' ||
      !Number.isSafeInteger(saved.sentToday) || saved.sentToday < 0) throw new Error('Invalid SMS state file');
  const tasks = new Map(saved.tasks), phones = new Map(saved.phones);
  let { day, sentToday } = saved;
  const persist = () => {
    const fd = openSync(statePath + '.tmp', 'w', 0o600);
    try { writeFileSync(fd, JSON.stringify({ tasks: [...tasks], phones: [...phones], day, sentToday })); fsyncSync(fd); }
    finally { closeSync(fd); }
    renameSync(statePath + '.tmp', statePath);
    const directory = openSync(dirname(statePath), 'r');
    try { fsyncSync(directory); } finally { closeSync(directory); }
  };
  persist(); // Fail startup if the durable state cannot be written.
  const server = http.createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== url.pathname) return reply(res, 404, 'NOT_FOUND', 'Not found');
    const timestamp = req.headers['x-agc-timestamp'];
    const signature = req.headers['x-agc-auth'];
    const time = now();
    if (typeof timestamp !== 'string' || !/^\d{13}$/.test(timestamp) || Math.abs(time - Number(timestamp)) > 180000 ||
        typeof signature !== 'string' || !/^[A-Za-z0-9+/]{128,2048}={0,2}$/.test(signature)) {
      return reply(res, 401, 'AUTH_FAILED', 'Invalid signature or timestamp');
    }
    if (!/^application\/json(?:;|$)/i.test(req.headers['content-type'] || '')) return reply(res, 415, 'INVALID_BODY', 'JSON required');
    try {
      const chunks = []; let size = 0;
      for await (const chunk of req) {
        size += chunk.length;
        if (size > 4096) return reply(res, 413, 'INVALID_BODY', 'Body too large');
        chunks.push(chunk);
      }
      let body;
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
      catch { return reply(res, 400, 'INVALID_BODY', 'Invalid JSON'); }
      if (!body || body.productId !== projectId || body.action !== '1001' ||
          typeof body.phoneNumber !== 'string' || !/^(?:\+86-)?1[3-9]\d{9}$/.test(body.phoneNumber) ||
          typeof body.verifyCode !== 'string' || !/^\d{4,8}$/.test(body.verifyCode) ||
          typeof body.taskId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(body.taskId)) {
        return reply(res, 400, 'INVALID_BODY', 'Invalid login SMS request');
      }
      const canonical = ['POST', callbackUrl, timestamp, JSON.stringify(body)].join('\n');
      const valid = keys.some(key => verify('RSA-SHA256', Buffer.from(canonical), {
        key, padding: constants.RSA_PKCS1_PSS_PADDING, saltLength: constants.RSA_PSS_SALTLEN_DIGEST
      }, Buffer.from(signature, 'base64')));
      if (!valid) return reply(res, 401, 'AUTH_FAILED', 'Invalid signature');
      // Recheck freshness after receiving a potentially slow request body.
      if (Math.abs(now() - Number(timestamp)) > 180000) return reply(res, 401, 'AUTH_FAILED', 'Expired request');
      for (const [id, task] of tasks) if (time - task.time > 360000) tasks.delete(id);
      const digest = hash(JSON.stringify(body));
      const previous = tasks.get(body.taskId);
      if (previous) return reply(res, 200, previous.done && previous.digest === digest ? '0' : 'DUPLICATE',
        previous.done && previous.digest === digest ? 'OK' : 'Already attempted', body.taskId);
      const today = new Date(time).toISOString().slice(0, 10);
      if (day !== today) { day = today; sentToday = 0; phones.clear(); }
      // Console tests omit +86-. Verify the original body before normalizing either form.
      const phoneNumber = '+86-' + body.phoneNumber.slice(-11);
      const phoneKey = hash(phoneNumber);
      const phone = phones.get(phoneKey);
      if (sentToday >= dailyLimit || tasks.size >= 10000 || phone && (time - phone.last < 60000 || phone.count >= 10)) {
        return reply(res, 429, 'RATE_LIMIT', 'SMS limit reached', body.taskId);
      }
      // Reserve before awaiting the provider; a timeout must not cause an automatic duplicate send.
      const task = { time, done: false, digest }; tasks.set(body.taskId, task);
      phones.set(phoneKey, { last: time, count: (phone?.count || 0) + 1 }); sentToday++;
      persist(); // Reserve on disk before any paid API call, including calls that time out.
      try { await sendSms({ ...body, phoneNumber }); task.done = true; persist(); }
      catch { return reply(res, 200, 'SEND_FAILED', 'SMS provider unavailable', body.taskId); }
      return reply(res, 200, '0', 'OK', body.taskId);
    } catch {
      if (!res.headersSent) reply(res, 500, 'INTERNAL_ERROR', 'SMS service unavailable');
    }
  });
  server.requestTimeout = 10000;
  server.headersTimeout = 5000;
  return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = process.env;
  // Download the public keys from Huawei's documented /agc/auth/keys endpoint, never from an incoming request.
  const downloaded = JSON.parse(readFileSync(config.AGC_SMS_PUBLIC_KEYS_PATH, 'utf8'));
  const publicKeys = Object.values(downloaded);
  createAgcSmsServer({ callbackUrl: config.AGC_SMS_CALLBACK_URL, projectId: config.AGC_SMS_PROJECT_ID, publicKeys,
    statePath: config.AGC_SMS_STATE_PATH,
    dailyLimit: Number(config.SMS_DAILY_LIMIT || 100), sendSms: aliyunSmsSender({
      accessKeyId: config.ALIBABA_CLOUD_ACCESS_KEY_ID, accessKeySecret: config.ALIBABA_CLOUD_ACCESS_KEY_SECRET,
      roleName: config.ALIBABA_CLOUD_ECS_METADATA,
      securityToken: config.ALIBABA_CLOUD_SECURITY_TOKEN, signName: config.SMS_SIGN_NAME,
      validMinutes: Number(config.SMS_CODE_VALID_MINUTES)
    }) }).listen(Number(config.AGC_SMS_PORT || 8790), '127.0.0.1', () => {
    console.log('AGC SMS callback listening on loopback; expose only the configured HTTPS path.');
  });
}
