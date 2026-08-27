import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const MODULE_DIR = path.dirname(fileURLToPath(import.meta.url));
const MAX_BODY_BYTES = 1024 * 1024;
const shareRate = new Map();
let shareRateStartedAt = Date.now();
// ponytail: this deploy-only server mirrors the gateway contract until the full gateway is hosted here.

function sendJson(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type'
  });
  res.end(body);
}

function sendHtml(res, statusCode, body) {
  res.writeHead(statusCode, {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': statusCode === 200 ? 'public, max-age=300' : 'no-store',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin'
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', chunk => {
      total += chunk.length;
      if (total > MAX_BODY_BYTES) {
        reject(new Error('Request body is too large.'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8').trim();
        resolve(raw.length > 0 ? JSON.parse(raw) : {});
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function boundedText(value, limit) {
  return typeof value === 'string' ? value.trim().slice(0, limit) : '';
}

function publicUrl(value, cover = false) {
  const raw = boundedText(value, 2048);
  if (raw.length === 0) return '';
  try {
    const parsed = new URL(raw);
    if (parsed.protocol !== 'https:' && (!cover && parsed.protocol !== 'http:')) return '';
    return parsed.toString();
  } catch (_error) {
    return '';
  }
}

function shareSnapshot(value) {
  const raw = value && typeof value === 'object' ? value : {};
  const source = boundedText(raw.source, 80);
  const mediaType = boundedText(raw.mediaType, 24);
  const format = boundedText(raw.format, 24);
  const snapshot = {
    title: boundedText(raw.title, 160) || (source ? source + ' 内容' : '分享内容'),
    summary: boundedText(raw.summary, 600),
    source,
    author: boundedText(raw.author, 120),
    coverUrl: publicUrl(raw.coverUrl, true),
    mediaType: ['video', 'image_text', 'post'].includes(mediaType) ? mediaType : '',
    mediaUrl: publicUrl(raw.mediaUrl),
    format: ['landscape_video', 'portrait_video', 'image_text', 'text'].includes(format) ? format : '',
    originalUrl: publicUrl(raw.originalUrl),
    publishedAt: boundedText(raw.publishedAt, 40)
  };
  return snapshot.originalUrl.length > 0 ? snapshot : null;
}

function rateLimited(req) {
  const key = boundedText(req.headers['x-real-ip'], 80) || req.socket.remoteAddress || 'unknown';
  const limit = Math.max(1, Number.parseInt(process.env.WATERFALL_SHARE_RATE_LIMIT || '30', 10) || 30);
  const now = Date.now();
  if (now - shareRateStartedAt >= 60_000) {
    shareRate.clear();
    shareRateStartedAt = now;
  }
  const current = shareRate.get(key);
  if (!current || now - current.startedAt >= 60_000) {
    shareRate.set(key, { startedAt: now, count: 1 });
    return false;
  }
  if (current.count >= limit) return true;
  current.count += 1;
  return false;
}

function storeDir() {
  return process.env.WATERFALL_SHARE_STORE_DIR || path.join(MODULE_DIR, '.shares');
}

function publicBaseUrl() {
  return (process.env.WATERFALL_SHARE_PUBLIC_BASE_URL || 'https://jiuwenappless.com/s/').replace(/\/*$/, '/');
}

function sharePath(id) {
  return path.join(storeDir(), id + '.json');
}

function storeShare(snapshot) {
  fs.mkdirSync(storeDir(), { recursive: true });
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const id = crypto.randomBytes(9).toString('base64url');
    const target = sharePath(id);
    if (fs.existsSync(target)) continue;
    const temporary = target + '.' + process.pid.toString() + '.tmp';
    fs.writeFileSync(temporary, JSON.stringify({ ...snapshot, createdAt: new Date().toISOString() }), {
      encoding: 'utf8', flag: 'wx'
    });
    fs.renameSync(temporary, target);
    return id;
  }
  throw new Error('Could not allocate a share id.');
}

function loadShare(id) {
  if (!/^[A-Za-z0-9_-]{12}$/.test(id)) return null;
  try {
    return JSON.parse(fs.readFileSync(sharePath(id), 'utf8'));
  } catch (_error) {
    return null;
  }
}

function shareUrl(id) {
  return publicBaseUrl() + id;
}

function sharePage(id, snapshot) {
  const canonical = shareUrl(id);
  const title = escapeHtml(snapshot.title);
  const summary = escapeHtml(snapshot.summary);
  const cover = escapeHtml(snapshot.coverUrl);
  const source = escapeHtml(snapshot.source || 'Appless');
  const author = escapeHtml(snapshot.author);
  const published = escapeHtml(snapshot.publishedAt);
  const original = escapeHtml(snapshot.originalUrl);
  const mediaUrl = escapeHtml(snapshot.mediaUrl);
  const openApp = 'com.jiuwen.appless://share/' + encodeURIComponent(id);
  const imageMeta = cover.length > 0 ? '<meta property="og:image" content="' + cover + '">' +
    '<meta name="twitter:card" content="summary_large_image">' : '<meta name="twitter:card" content="summary">';
  const media = snapshot.mediaType === 'video' && mediaUrl.length > 0 ?
    '<video class="cover" src="' + mediaUrl + '"' + (cover ? ' poster="' + cover + '"' : '') +
    ' controls playsinline preload="metadata"></video>' :
    (cover.length > 0 ? '<img class="cover" src="' + cover + '" alt="" referrerpolicy="no-referrer">' : '');
  const byline = [source, author, published].filter(Boolean).map(value => '<span>' + value + '</span>').join('');
  return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">' +
    '<title>' + title + ' · Appless</title><meta name="description" content="' + summary + '">' +
    '<link rel="canonical" href="' + canonical + '">' +
    '<meta property="og:type" content="article"><meta property="og:site_name" content="Appless">' +
    '<meta property="og:title" content="' + title + '"><meta property="og:description" content="' + summary + '">' +
    '<meta property="og:url" content="' + canonical + '">' + imageMeta +
    '<style>:root{color-scheme:light;--paper:#f5f2ee;--panel:#fbfcfd;--ink:#211b17;--muted:#746b64;--accent:#995f4c}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 50% -10%,#fff 0,transparent 40%),var(--paper);color:var(--ink);font-family:"HarmonyOS Sans SC","PingFang SC",system-ui,sans-serif}main{width:min(100% - 32px,560px);margin:0 auto;padding:24px 0 42px}.brand{display:flex;align-items:center;gap:9px;height:48px;font-weight:760}.mark{display:grid;width:28px;height:28px;place-items:center;border-radius:9px;background:var(--accent);color:#fff}.shared{margin:10px 0 14px;color:var(--muted);font-size:12px}.card{overflow:hidden;border:1px solid rgba(33,27,23,.06);border-radius:24px;background:var(--panel);box-shadow:0 18px 46px rgba(44,36,30,.12)}.cover{display:block;width:100%;max-height:360px;object-fit:cover}.copy{padding:20px}.byline{display:flex;flex-wrap:wrap;gap:7px 12px;color:var(--muted);font-size:12px}.byline span+span:before{content:"·";margin-right:12px}h1{margin:14px 0 0;font-size:clamp(27px,7vw,38px);line-height:1.1;letter-spacing:-.03em}p{margin:12px 0 0;color:#5f6569;font-size:15px;line-height:1.65}.actions{display:grid;gap:10px;margin-top:16px}.actions a{display:flex;min-height:50px;align-items:center;justify-content:center;border-radius:14px;text-decoration:none;font-size:14px;font-weight:740}.primary{background:var(--accent);color:#fff;box-shadow:0 10px 24px rgba(153,95,76,.2)}.secondary{color:var(--accent);border:1px solid rgba(153,95,76,.18);background:rgba(255,255,255,.5)}footer{margin-top:18px;color:var(--muted);font-size:11px;line-height:1.6;text-align:center}@media(min-width:640px){main{padding-top:42px}.copy{padding:24px}}</style></head>' +
    '<body><main><div class="brand"><span class="mark">A</span><span>Appless</span></div>' +
    '<div class="shared">由朋友分享</div><article class="card">' + media + '<div class="copy"><div class="byline">' +
    byline + '</div><h1>' + title + '</h1><p>' + summary + '</p></div></article>' +
    '<div class="actions"><a class="primary" href="' + openApp + '">在 Appless 中打开</a>' +
    '<a class="secondary" href="' + original + '" rel="noopener noreferrer">查看原文</a></div>' +
    '<footer>长期有效的公开快照 · 不包含搜索词、推荐理由或个人偏好</footer></main></body></html>';
}

function unavailablePage() {
  return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>分享卡片不可用 · Appless</title><style>body{margin:0;display:grid;min-height:100vh;place-items:center;background:#f5f2ee;color:#211b17;font-family:system-ui,sans-serif}main{width:min(100% - 40px,480px);text-align:center}h1{font-size:28px}p{color:#746b64;line-height:1.6}a{color:#995f4c}</style></head>' +
    '<body><main><h1>这张分享卡片暂时不可用</h1><p>内容可能已被原来源移除，或分享链接不存在。</p><a href="https://jiuwenappless.com/">返回 Appless</a></main></body></html>';
}

function landingPage() {
  return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">' +
    '<title>Appless · 分享值得完整抵达</title>' +
    '<meta name="description" content="从 Appless 分享 Waterfall 卡片，对方无需登录即可看到原卡内容。">' +
    '<meta property="og:type" content="website"><meta property="og:site_name" content="Appless">' +
    '<meta property="og:title" content="Appless · 分享值得完整抵达">' +
    '<meta property="og:description" content="从 Appless 分享 Waterfall 卡片，对方无需登录即可看到原卡内容。">' +
    '<meta property="og:url" content="https://jiuwenappless.com/">' +
    '<style>:root{color-scheme:light;--paper:#f5f2ee;--ink:#211b17;--muted:#746b64;--accent:#995f4c}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 50% -8%,#fff 0,transparent 42%),var(--paper);color:var(--ink);font-family:"HarmonyOS Sans SC","PingFang SC",system-ui,sans-serif}main{display:flex;width:min(100% - 40px,920px);min-height:100vh;margin:auto;flex-direction:column;padding:28px 0}.brand{display:flex;align-items:center;gap:10px;font-weight:760}.mark{display:grid;width:30px;height:30px;place-items:center;border-radius:10px;background:var(--accent);color:#fff}.hero{margin:auto 0;padding:72px 0 110px}.eyebrow{color:var(--accent);font-size:12px;font-weight:760;letter-spacing:.14em}h1{max-width:720px;margin:18px 0 0;font-size:clamp(48px,9vw,92px);font-weight:760;line-height:.96;letter-spacing:-.055em}p{max-width:560px;margin:26px 0 0;color:var(--muted);font-size:clamp(16px,2.2vw,20px);line-height:1.7}.note{display:flex;gap:9px;margin-top:32px;color:var(--muted);font-size:13px}.dot{width:7px;height:7px;margin-top:6px;border-radius:50%;background:var(--accent);box-shadow:0 0 0 5px rgba(153,95,76,.1)}footer{padding-bottom:8px;color:var(--muted);font-size:11px}</style></head>' +
    '<body><main><div class="brand"><span class="mark">A</span><span>Appless</span></div>' +
    '<section class="hero"><div class="eyebrow">WATERFALL SHARING</div><h1>分享值得<br>完整抵达。</h1>' +
    '<p>从 Appless 分享一张卡片，接收者打开链接即可看到原卡内容。无需登录，也不会只落到首页。</p>' +
    '<div class="note"><span class="dot"></span><span>公开快照只保留卡片内容，不包含搜索词、推荐理由或个人偏好。</span></div>' +
    '</section><footer>Appless · jiuwenappless.com</footer></main></body></html>';
}

export async function handleWaterfallShareRequest(req, res, url) {
  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return true;
  }
  if (url.pathname === '/') {
    if (req.method === 'GET') sendHtml(res, 200, landingPage());
    else sendJson(res, 405, { ok: false, error: 'Method not allowed.' });
    return true;
  }
  if (url.pathname === '/health') {
    if (req.method === 'GET') sendJson(res, 200, { ok: true, service: 'Appless Waterfall Share' });
    else sendJson(res, 405, { ok: false, error: 'Method not allowed.' });
    return true;
  }
  if (url.pathname === '/.well-known/applinking.json') {
    if (req.method === 'GET') {
      sendJson(res, 200, {
        applinking: { apps: [{ appIdentifier: process.env.WATERFALL_SHARE_APP_IDENTIFIER || '6917613462213244123' }] }
      });
    } else sendJson(res, 405, { ok: false, error: 'Method not allowed.' });
    return true;
  }
  if (url.pathname === '/v1/waterfall/shares') {
    if (req.method !== 'POST') {
      sendJson(res, 405, { ok: false, error: 'Method not allowed.' });
      return true;
    }
    const snapshot = shareSnapshot(await readJson(req));
    if (snapshot === null) {
      sendJson(res, 400, { ok: false, error: 'title and originalUrl are required.' });
      return true;
    }
    if (rateLimited(req)) {
      sendJson(res, 429, { ok: false, error: 'Too many share requests.' });
      return true;
    }
    const shareId = storeShare(snapshot);
    sendJson(res, 201, { ok: true, shareId, url: shareUrl(shareId) });
    return true;
  }
  const route = url.pathname.match(/^\/s\/([A-Za-z0-9_-]{12})$/);
  if (route !== null) {
    if (req.method !== 'GET') {
      sendJson(res, 405, { ok: false, error: 'Method not allowed.' });
      return true;
    }
    const snapshot = loadShare(route[1]);
    sendHtml(res, snapshot === null ? 404 : 200, snapshot === null ? unavailablePage() : sharePage(route[1], snapshot));
    return true;
  }
  return false;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const host = process.env.TOOL_GATEWAY_HOST || '127.0.0.1';
  const port = Number.parseInt(process.env.TOOL_GATEWAY_PORT || '8787', 10);
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url || '/', `http://${req.headers.host || host}`);
      if (!await handleWaterfallShareRequest(req, res, url)) sendJson(res, 404, { ok: false, error: 'Not found.' });
    } catch (error) {
      console.error('[waterfall-share]', error);
      if (!res.headersSent) sendJson(res, 500, { ok: false, error: 'Internal server error.' });
      else res.end();
    }
  });
  server.listen(port, host, () => console.log(`Appless Waterfall Share listening on http://${host}:${port}`));
}
