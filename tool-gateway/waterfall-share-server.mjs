import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const MODULE_DIR = path.dirname(fileURLToPath(import.meta.url));
const MAX_BODY_BYTES = 1024 * 1024;
const APP_ICONS = [
  ['gmail.svg', 'Gmail'], ['qqmail.svg', 'QQ Mail'], ['outlook.svg', 'Outlook'],
  ['google-calendar.svg', 'Google Calendar'], ['google-maps.svg', 'Google Maps'],
  ['youtube.svg', 'YouTube'], ['bilibili.svg', 'Bilibili'], ['github.svg', 'GitHub'],
  ['google-drive.svg', 'Google Drive'], ['google-docs.svg', 'Google Docs'], ['slack.svg', 'Slack'],
  ['wecom.svg', 'WeCom'], ['x.svg', 'X'], ['notion.svg', 'Notion'], ['linear.svg', 'Linear'],
  ['asana.svg', 'Asana'], ['trello.svg', 'Trello'], ['hubspot.svg', 'HubSpot'],
  ['salesforce.svg', 'Salesforce'], ['discord.svg', 'Discord'], ['linkedin.svg', 'LinkedIn'],
  ['whatsapp.svg', 'WhatsApp'], ['instagram.svg', 'Instagram'], ['spotify.svg', 'Spotify'],
  ['tiktok.svg', 'TikTok'], ['ticketmaster.svg', 'Ticketmaster'], ['paypal.svg', 'PayPal'],
  ['stripe.svg', 'Stripe'], ['google-pay.svg', 'Google Pay'], ['amap.jpg', 'Amap'],
  ['baidu-maps.jpg', 'Baidu Maps'], ['tencent-maps.jpg', 'Tencent Maps'], ['meituan.jpg', 'Meituan'],
  ['taobao.jpg', 'Taobao'], ['luckin.svg', 'Luckin Coffee'], ['mcdonalds.jpg', "McDonald's"],
  ['kfc.jpg', 'KFC'], ['reddit.svg', 'Reddit'], ['hackernews.svg', 'Hacker News'],
  ['zhihu.svg', 'Zhihu'], ['didi.svg', 'Didi']
];
const SITE_ASSETS = new Map([
  ['/assets/appless.svg', path.resolve(MODULE_DIR, '../entry/src/main/resources/base/media/logo_appless.svg')],
  ['/assets/appless-display-sc.woff2', path.resolve(MODULE_DIR, '../docs/assets/brand/appless-display-sc.woff2')],
  ...APP_ICONS.map(([file]) => [
    '/assets/app-icons/' + file,
    path.resolve(MODULE_DIR, '../docs/assets/app-icons', file)
  ])
]);
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

function sendAsset(res, filePath) {
  const extension = path.extname(filePath).toLowerCase();
  const contentType = extension === '.svg' ? 'image/svg+xml; charset=utf-8' :
    (extension === '.png' ? 'image/png' : (extension === '.woff2' ? 'font/woff2' : 'image/jpeg'));
  res.writeHead(200, {
    'Content-Type': contentType,
    'Cache-Control': 'public, max-age=300',
    'X-Content-Type-Options': 'nosniff'
  });
  res.end(fs.readFileSync(filePath));
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
  const icons = (hidden = false) => APP_ICONS.map(([file, name]) =>
    '<img data-app-icon src="/assets/app-icons/' + file + '" width="48" height="48" alt="' +
    (hidden ? '' : escapeHtml(name)) + '" loading="eager" decoding="async">').join('');
  return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">' +
    '<title>Appless · 少开应用，多完成事情</title>' +
    '<meta name="description" content="告诉 Appless 你想完成什么。">' +
    '<meta property="og:type" content="website"><meta property="og:site_name" content="Appless">' +
    '<meta property="og:title" content="Appless · 少开应用，多完成事情">' +
    '<meta property="og:description" content="告诉 Appless 你想完成什么。">' +
    '<meta property="og:url" content="https://jiuwenappless.com/">' +
    '<style>@font-face{font-family:"Appless Display SC";src:url("/assets/appless-display-sc.woff2") format("woff2");font-style:normal;font-weight:540;font-display:swap}:root{color-scheme:light;--paper:#f7f8fa;--ink:#202124;--muted:#777b82;--accent:#a9634b}*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;min-width:320px;background:var(--paper);color:var(--ink);font-family:"HarmonyOS Sans SC","PingFang SC","SF Pro Display",system-ui,sans-serif}.page{position:relative;display:grid;min-height:100svh;overflow:hidden;grid-template-rows:auto 1fr auto auto}.shell{width:min(calc(100% - 152px),1400px);margin-inline:auto}.brand{display:flex;align-items:center;gap:11px;padding-top:38px;color:var(--ink);font-size:18px;font-weight:650;letter-spacing:-.02em;text-decoration:none}.brand img{width:36px;height:36px}.ghost{position:absolute;z-index:-1;top:-5%;right:4vw;width:min(65vw,840px);height:auto;opacity:.045;pointer-events:none}.hero{align-self:center;padding:56px 0 36px 52px;transform:translateY(-38px)}.hero h1{max-width:790px;margin:0;font-family:"Appless Display SC","PingFang SC",sans-serif;font-size:clamp(62px,6vw,92px);font-weight:540;line-height:.98;letter-spacing:-.04em}.hero p{margin:30px 0 0;color:var(--muted);font-size:clamp(17px,1.45vw,21px);letter-spacing:-.02em}.learn{display:inline-flex;align-items:center;gap:10px;margin-top:34px;color:var(--accent);font-size:13px;text-decoration:none}.learn span{transition:transform 180ms ease}.learn:hover span{transform:translateX(4px)}.brand:focus-visible,.learn:focus-visible,footer a:focus-visible{outline:2px solid var(--accent);outline-offset:6px;border-radius:3px}.marquee{width:100%;overflow:hidden;padding:25px 0 29px;border-block:1px solid rgba(32,33,36,.06);background:rgba(255,255,255,.3);-webkit-mask-image:linear-gradient(90deg,transparent,#000 7%,#000 93%,transparent);mask-image:linear-gradient(90deg,transparent,#000 7%,#000 93%,transparent)}.track{display:flex;width:max-content;animation:marquee 96s linear infinite;will-change:transform}.icon-group{display:flex;flex:none;align-items:center;gap:32px;padding-right:32px}.icon-group img{display:block;width:40px;height:40px;object-fit:contain;filter:saturate(.9);opacity:.88}@keyframes marquee{to{transform:translate3d(-50%,0,0)}}footer{display:flex;align-items:center;justify-content:flex-start;gap:18px;padding:0 0 26px;color:#8a8d92;font-size:11px;letter-spacing:.01em}footer .divider{width:1px;height:11px;background:rgba(32,33,36,.16)}footer a{color:inherit;text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:3px}footer a:hover{color:var(--ink)}@media(max-width:720px){.shell{width:min(calc(100% - 44px),1240px)}.brand{padding-top:24px;font-size:16px}.brand img{width:32px;height:32px}.ghost{top:19%;right:-46vw;width:112vw;opacity:.035}.hero{padding:54px 0 38px;transform:none}.hero h1{font-size:clamp(50px,15vw,72px);line-height:.98}.hero p{margin-top:22px;font-size:16px}.learn{margin-top:28px}.marquee{padding:18px 0 24px}.icon-group{gap:34px;padding-right:34px}.icon-group img{width:42px;height:42px}footer{gap:10px;padding-bottom:max(20px,env(safe-area-inset-bottom));font-size:10px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}.track{animation:none}.learn span{transition:none}}</style></head>' +
    '<body><main class="page"><img class="ghost" src="/assets/appless.svg" alt="">' +
    '<header class="shell"><a class="brand" href="/" aria-label="Appless 首页"><img src="/assets/appless.svg" alt=""><span>Appless</span></a></header>' +
    '<section class="hero shell"><h1>少开应用，<br>多完成事情。</h1><p>告诉 Appless 你想完成什么。</p>' +
    '<a class="learn" href="#connected-apps">了解 Appless <span aria-hidden="true">→</span></a></section>' +
    '<section class="marquee" id="connected-apps" aria-label="Appless 已接入的 41 个应用"><div class="track">' +
    '<div class="icon-group">' + icons() + '</div><div class="icon-group" aria-hidden="true">' + icons(true) + '</div>' +
    '</div></section><footer class="shell"><span>© 2026 Appless</span><span class="divider" aria-hidden="true"></span>' +
    '<a href="https://beian.miit.gov.cn" rel="noopener noreferrer">粤ICP备2026124642号</a>' +
    '</footer></main></body></html>';
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
  const asset = SITE_ASSETS.get(url.pathname);
  if (asset) {
    if (req.method === 'GET') sendAsset(res, asset);
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
