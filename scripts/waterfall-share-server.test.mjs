import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import net from 'node:net';
import { tmpdir } from 'node:os';
import path from 'node:path';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const storeDir = await mkdtemp(path.join(tmpdir(), 'appless-share-'));

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  assert.equal(typeof address, 'object');
  const port = address.port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

async function waitForHealth(baseUrl) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await fetch(baseUrl + '/health');
      if (response.ok) return;
    } catch (_error) {
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error('gateway did not start');
}

const port = await freePort();
const baseUrl = `http://127.0.0.1:${port}`;
const gateway = spawn(process.execPath, ['tool-gateway/waterfall-share-server.mjs'], {
  cwd: root,
  env: {
    ...process.env,
    TOOL_GATEWAY_HOST: '127.0.0.1',
    TOOL_GATEWAY_PORT: String(port),
    WATERFALL_SHARE_STORE_DIR: storeDir,
    WATERFALL_SHARE_PUBLIC_BASE_URL: 'https://jiuwenappless.com/s/',
    WATERFALL_SHARE_RATE_LIMIT: '2'
  },
  stdio: ['ignore', 'pipe', 'pipe']
});

try {
  await waitForHealth(baseUrl);
  const snapshot = {
    title: '一座球场如何完成灯光与网络协同',
    summary: '从照明、转播到观众网络，一场比赛背后是多套实时系统的精密协作。',
    source: 'GlobalNews',
    author: '现场编辑部',
    coverUrl: 'https://images.example.test/stadium.jpg',
    mediaType: 'video',
    mediaUrl: 'https://media.example.test/stadium.mp4',
    format: 'landscape_video',
    originalUrl: 'https://news.example.test/stadium',
    publishedAt: '2026-08-25',
    reason: '不应公开的推荐理由',
    searchQuery: '不应公开的搜索词'
  };
  const created = await fetch(baseUrl + '/v1/waterfall/shares', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(snapshot)
  });
  assert.equal(created.status, 201);
  const payload = await created.json();
  assert.match(payload.shareId, /^[A-Za-z0-9_-]{12}$/);
  assert.equal(payload.url, `https://jiuwenappless.com/s/${payload.shareId}`);

  const page = await fetch(`${baseUrl}/s/${payload.shareId}`);
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-type'), /^text\/html/);
  const html = await page.text();
  assert.match(html, /<meta property="og:title" content="一座球场如何完成灯光与网络协同">/);
  assert.match(html, /<meta property="og:image" content="https:\/\/images\.example\.test\/stadium\.jpg">/);
  assert.match(html, /<video[^>]*src="https:\/\/media\.example\.test\/stadium\.mp4"/);
  assert.match(html, /从照明、转播到观众网络/);
  assert.match(html, />GlobalNews</);
  assert.match(html, />现场编辑部</);
  assert.match(html, />在 Appless 中打开</);
  assert.match(html, />查看原文</);
  assert.doesNotMatch(html, /不应公开的推荐理由|不应公开的搜索词/);

  const association = await fetch(baseUrl + '/.well-known/applinking.json');
  assert.equal(association.status, 200);
  assert.deepEqual(await association.json(), {
    applinking: { apps: [{ appIdentifier: '6917613462213244123' }] }
  });

  const landing = await fetch(baseUrl + '/');
  assert.equal(landing.status, 200);
  const landingHtml = await landing.text();
  assert.match(landingHtml, /少开应用，[\s\S]*多完成事情。/);
  assert.match(landingHtml, /告诉 Appless 你想完成什么。/);
  assert.match(landingHtml, /href="https:\/\/beian\.miit\.gov\.cn"[^>]*>粤ICP备2026124642号<\/a>/);
  assert.doesNotMatch(landingHtml, /href="https:\/\/beian\.miit\.gov\.cn"[^>]*target="_blank"/);
  assert.match(landingHtml, /animation:marquee 96s linear infinite/);
  assert.match(landingHtml, /@media\(prefers-reduced-motion:reduce\)[\s\S]*animation:none/);
  assert.equal((landingHtml.match(/data-app-icon/g) || []).length, 82);

  const appIcon = await fetch(baseUrl + '/assets/app-icons/gmail.svg');
  assert.equal(appIcon.status, 200);
  assert.match(appIcon.headers.get('content-type'), /^image\/svg\+xml/);
  assert.equal(appIcon.headers.get('cache-control'), 'public, max-age=300');

  const displayFont = await fetch(baseUrl + '/assets/appless-display-sc.woff2');
  assert.equal(displayFont.status, 200);
  assert.match(displayFont.headers.get('content-type'), /^font\/woff2/);

  const unknownAsset = await fetch(baseUrl + '/assets/app-icons/not-connected.svg');
  assert.equal(unknownAsset.status, 404);

  const missing = await fetch(baseUrl + '/s/____________');
  assert.equal(missing.status, 404);
  assert.match(await missing.text(), /这张分享卡片暂时不可用/);

  const second = await fetch(baseUrl + '/v1/waterfall/shares', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(snapshot)
  });
  assert.equal(second.status, 201);
  const limited = await fetch(baseUrl + '/v1/waterfall/shares', {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(snapshot)
  });
  assert.equal(limited.status, 429);
} finally {
  gateway.kill('SIGTERM');
  await new Promise((resolve) => gateway.once('exit', resolve));
  await rm(storeDir, { recursive: true, force: true });
}
