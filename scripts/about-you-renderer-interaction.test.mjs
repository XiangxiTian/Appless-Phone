// Run: node --test scripts/about-you-renderer-interaction.test.mjs
// Install Playwright, set NODE_PATH, or provide its directory in PLAYWRIGHT_MODULE_PATH.
// This launches real Chromium and executes every browser assertion. Fixtures are test-only.
import fs from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test from 'node:test';
const require = createRequire(import.meta.url);
const run = async (page, fixture) => {
  const assert = {
    equal(a,b){if(a!==b)throw Error('Expected '+JSON.stringify(b)+', got '+JSON.stringify(a));},
    notEqual(a,b){if(a===b)throw Error('Unexpected '+JSON.stringify(a));},
    ok(value){if(!value)throw Error('Expected truthy value');},
    deepEqual(a,b){if(JSON.stringify(a)!==JSON.stringify(b))throw Error('Expected '+JSON.stringify(b)+', got '+JSON.stringify(a));}
  };
  const backdrop = fixture.backdrop;
  await page.setViewportSize({ width: 390, height: 844 });
  await page.route('https://about-you-preview.test/avatar.svg',route=>route.fulfill({contentType:'image/svg+xml',body:'<svg xmlns="http://www.w3.org/2000/svg" width="68" height="68" viewBox="0 0 68 68"><rect width="68" height="68" fill="#dceae4"/><circle cx="34" cy="26" r="12" fill="#8dab9c"/><ellipse cx="34" cy="65" rx="24" ry="22" fill="#8dab9c"/></svg>'}));
  await page.route('https://about-you-preview.test/missing.png',route=>route.fulfill({status:404,body:''}));
  await page.addInitScript(() => {
    window.actions=[];
    window.AboutYouHost={postAction(raw){window.actions.push(JSON.parse(raw));}};
  });
  // Navigate to the exact shipping data URL, including its CSP. ArkWeb's native
  // image is represented only by a preview-only background style after loading.
  await page.goto(fixture.documentUrl);
  assert.equal(page.url(),fixture.documentUrl);
  assert.equal(await page.locator('#back').isVisible(),true);
  assert.equal((await page.evaluate(() => window.actions))[0].type,'ready');
  await page.addStyleTag({content:'body{background:url(data:image/jpeg;base64,'+backdrop+') center/cover fixed}'});
  const initial = {
    displayName: '小林', summary: '喜欢把新想法变成看得见的东西，也在忙碌的日常里，为好奇心留一点空间。',
    tagList: ['动手派', '灵感收集者', '周末漫游'], overviewState: 'ready', overviewError: '', updating: false,
    mbtiType: 'INTJ', mbtiConfidence: 65,
    correctionDisabled: false, updateError: '', correctionRevision: 0, overviewRevision:0,
    sections: [
      { id: 'identity', title: '身份与经历', inferred: false, claims: [{ index: 0, heading: '工作与探索', body: '从事产品设计，最近在尝试把设计想法做成可以使用的小工具。' }] },
      { id: 'interests', title: '兴趣与偏好', inferred: false, claims: [{ index: 1, heading: '日常里的小发现', body: '喜欢摄影和城市漫步，也会收集有趣的独立游戏。' }] },
      { id: 'personality', title: '性格推断', inferred: true, claims: [{ index: 2, heading: '对新事物保持好奇', body: '从主动探索不同领域的分享来看，可能偏好亲手尝试和验证想法。' }] }
    ],
    platformLogos:fixture.platformLogos,
    accounts: [
      { id: 'a', platform: 'github', displayName: '小林的实验室', handle: 'xiaolin', avatarUrl:'https://about-you-preview.test/avatar.svg' },
      { id: 'b', platform: 'bilibili', displayName: '小林的日常', handle: '@xiaolin_daily', avatarUrl:'' },
      { id: 'c', platform: 'matrix', displayName: '小林', handle: 'xiaolin_chat', avatarUrl:'https://about-you-preview.test/missing.png' }
    ],
    social: { phase: 'idle', username: '小林', mode: 'fuzzy', candidates: [], progress: '', error: '', markdown: '', draftId: '', importing: false }
  };
  const update = async (data) => await page.evaluate(data => window.AboutYou.receive(JSON.stringify(data), {top:24,bottom:20}), data);
  await update(initial);
  assert.equal(await page.locator('#name').innerText(), '小林');
  assert.equal(await page.locator('#sections .card').count(), 3);
  assert.equal(await page.locator('#mbti-tag').textContent(), 'INTJ · 65%推测');
  assert.ok((await page.locator('#mbti-tag').getAttribute('aria-label')).includes('模型推测'));
  assert.equal(await page.locator('#tags .tag').count(), 3);
  assert.equal(await page.locator('#refresh').isVisible(), false);
  assert.equal(await page.locator('#update-card #accounts .account').count(), 3);
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),true);
  const output = fixture.output;
  // MBTI is independent of the five ordinary tags and always reflects the latest snapshot.
  await update({...initial,mbtiType:'enfp',mbtiConfidence:82,tagList:['INTJ','ENFP','动手派','灵感收集者','周末漫游','摄影','游戏']});
  assert.equal(await page.locator('#mbti-tag').textContent(), 'ENFP · 82%推测');
  assert.equal(await page.locator('#tags .tag').count(), 5);
  assert.equal((await page.locator('#tags .tag').allTextContents()).includes('INTJ'), false);
  await update({...initial,mbtiConfidence:0.1});
  assert.equal(await page.locator('#mbti-tag').textContent(), 'INTJ · <1%推测');
  assert.equal(await page.locator('#mbti-tag').getAttribute('title'), '模型推测的 MBTI，置信度 <1%');
  assert.equal(await page.locator('#mbti-tag').getAttribute('aria-label'), '模型推测的 MBTI，置信度 <1%，INTJ');
  for(const [mbtiType,mbtiConfidence] of [['INTJ',0],['XXXX',65],['INTJ',-1],['INTJ',101],['INTJ','65'],['',65]]){
    await update({...initial,mbtiType,mbtiConfidence});
    assert.equal(await page.locator('#mbti-tag').innerText(), 'MBTI 暂缺');
  }
  await update(initial);
  const missingMbti={...initial};delete missingMbti.mbtiType;delete missingMbti.mbtiConfidence;
  await update(missingMbti);
  assert.equal(await page.locator('#mbti-tag').innerText(), 'MBTI 暂缺');
  await page.locator('.profile').screenshot({path:output+'/about-you-mbti-empty-390.png'});
  await update(initial);
  await page.locator('#accounts').scrollIntoViewIfNeeded();
  await page.waitForFunction(()=>document.querySelector('.account-avatar img')?.naturalWidth>0);
  await page.waitForFunction(()=>Array.from(document.querySelectorAll('.platform-logo img')).every(image=>image.naturalWidth>0));
  assert.equal(await page.locator('.platform-logo img').count(),2);
  assert.equal(await page.locator('.platform-short').innerText(),'MA');
  assert.equal(await page.locator('.account-handle').nth(1).innerText(),'@xiaolin_daily');
  await page.waitForFunction(()=>document.querySelectorAll('.account-avatar img').length===1);
  assert.equal(await page.locator('.account-avatar svg').nth(2).isVisible(),true);
  await page.locator('#update-card').screenshot({path:output+'/about-you-accounts-390.png'});
  // A corrupt built-in asset falls back to the short site label, never a remote logo.
  const brokenLogo=JSON.parse(JSON.stringify(initial));
  brokenLogo.platformLogos.github='data:image/svg+xml;base64,broken';
  await update(brokenLogo);
  await page.waitForFunction(()=>document.querySelector('.platform-logo .platform-short')?.textContent==='GH');
  await update(initial);
  await page.evaluate(()=>window.scrollTo(0,0));
  await page.screenshot({ path: output + '/about-you-390.png', fullPage: true });
  await page.locator('#correction').fill('其实现在更喜欢室内摄影');
  await page.evaluate(() => window.scrollTo(0, 300));
  const scroll = await page.evaluate(() => window.scrollY);
  const changed = JSON.parse(JSON.stringify(initial));
  changed.summary = '这是更新后的概览，应该立即显示。';
  changed.mbtiType = 'INFP'; changed.mbtiConfidence = 73;
  changed.sections[1].claims[0].body = '更喜欢室内摄影。';
  await update(changed);
  assert.equal(await page.locator('#summary').innerText(), changed.summary);
  assert.equal(await page.locator('#mbti-tag').textContent(), 'INFP · 73%推测');
  assert.equal(await page.locator('#correction').inputValue(), '其实现在更喜欢室内摄影');
  assert.equal(await page.evaluate(() => window.scrollY), scroll);
  await page.getByRole('button', { name: '修改日常里的小发现' }).click();
  await page.locator('#correct').click();
  let actions = await page.evaluate(() => window.actions);
  assert.deepEqual(actions.at(-1), { type: 'correct', token: 'test-token', text: '其实现在更喜欢室内摄影', claimIndex: 1, overviewRevision:0 });
  changed.correctionRevision++;
  await update(changed);
  assert.equal(await page.locator('#correction').inputValue(), '');
  await page.locator('#social-open').click();
  assert.equal(await page.locator('#username').inputValue(), '小林');
  await page.locator('#username').fill('xiaolin');
  await page.locator('#mode-exact').click();
  await page.locator('#search').click();
  actions = await page.evaluate(() => window.actions);
  assert.deepEqual(actions.at(-1), { type:'social_search',token:'test-token', username:'xiaolin',mode:'exact' });
  changed.social.phase = 'confirm';
  changed.social.candidates = [
    {id:'a',platform:'GitHub',displayName:'xiaolin',handle:'xiaolin',summary:'公开项目与分享',selected:true},
    {id:'b',platform:'知乎',displayName:'另一个小林',handle:'lin2',summary:'待确认账号',selected:false}
  ];
  await update(changed);
  await page.locator('#confirm').click();
  actions = await page.evaluate(() => window.actions);
  assert.deepEqual(actions.at(-1).candidateIds, ['a']);
  changed.social.phase = 'draft';
  changed.social.draftId = 'draft-1';
  changed.social.markdown = '# 关于小林\n\n## 兴趣与偏好\n- 喜欢摄影，也分享自己的设计实验。\n\n## 近期关注\n正在探索让生活更方便的小工具。';
  await update(changed);
  assert.equal(await page.locator('#review-overlay').isVisible(), true);
  assert.equal(await page.locator('#markdown img').count(), 0);
  assert.equal(await page.evaluate(() => !!window.injected), false);
  const bounds = await page.locator('.modal').boundingBox();
  assert.ok(bounds.y >= 24);
  assert.ok(bounds.y + bounds.height <= 824);
  await page.screenshot({ path: output + '/about-you-review-390.png', fullPage: false });
  changed.social.draftId='draft-2';
  changed.social.markdown+='\n\n<script>window.injected=true</script>\n<img src=x onerror="window.injected=true">';
  await update(changed);
  assert.equal(await page.locator('#markdown img').count(), 0);
  assert.equal(await page.evaluate(() => !!window.injected), false);
  await page.locator('#edit-toggle').click();
  await page.locator('#markdown-editor').fill('# 我确认的资料\n\n更喜欢室内摄影。');
  await page.locator('#review-close').click();
  assert.equal(await page.locator('#review-overlay').isVisible(), false);
  actions = await page.evaluate(() => window.actions);
  assert.equal(actions.at(-1).type, 'social_edit');
  assert.ok(actions.at(-1).markdown.includes('室内摄影'));
  await update(changed);
  assert.equal(await page.locator('#review-overlay').isVisible(), false);
  await page.locator('#resume-draft').click();
  assert.equal(await page.locator('#markdown-editor').inputValue(), '# 我确认的资料\n\n更喜欢室内摄影。');
  await page.locator('#import').click();
  actions = await page.evaluate(() => window.actions);
  assert.equal(actions.at(-1).type, 'social_import');
  assert.equal(actions.at(-1).markdown, '# 我确认的资料\n\n更喜欢室内摄影。');
  changed.social.importing = true;
  await update(changed);
  assert.equal(await page.locator('#discard').isDisabled(), true);
  assert.equal(await page.locator('#review-close').isDisabled(), true);
  await page.keyboard.press('Escape');
  assert.equal(await page.locator('#review-overlay').isVisible(), true);
  changed.social.importing = false;
  await update(changed);
  await page.locator('#discard').click();
  assert.equal(await page.locator('#review-overlay').isVisible(), false);
  actions = await page.evaluate(() => window.actions);
  assert.equal(actions.at(-1).type, 'social_discard');
  changed.social.phase = 'error'; changed.social.draftId = ''; changed.social.markdown='';changed.social.error='暂时未能完成查找，请重试。';
  await update(changed);
  await page.locator('#retry').click();
  actions = await page.evaluate(() => window.actions);
  assert.equal(actions.at(-1).type, 'social_retry');
  changed.correctionDisabled = true;
  await update(changed);
  assert.equal(await page.locator('#refresh').isVisible(), true);
  await page.locator('#correction').fill('不应提交过期概览');
  assert.equal(await page.locator('#correct').isDisabled(), true);
  await page.locator('#refresh').click();
  assert.equal((await page.evaluate(() => window.actions)).at(-1).type, 'overview_refresh');
  changed.correctionDisabled=false;
  changed.overviewRevision++;
  await update(changed);
  assert.equal(await page.locator('#correction-context').isVisible(), false);
  assert.equal(await page.locator('#correction').inputValue(), '不应提交过期概览');
  changed.overviewState='empty'; changed.sections=[];
  await update(changed);
  assert.equal(await page.locator('#correction').isDisabled(), true);
  assert.equal(await page.locator('#correct').isDisabled(), true);
  assert.ok((await page.locator('#overview-status').innerText()).includes('聊天时告诉我'));
  // Leave the preview in its calm ready state for visual review.
  await update(initial);
  await page.evaluate(() => window.scrollTo(0,0));
  return { passed: true, checks: 'MBTI confidence, inferred label, independent tags, deduplication, invalid/zero/missing fallback, ready updates, scroll/input retention, claim index, search mode, candidates, XSS, draft editing/resume/import/discard, insets, stale protection, built-in site logos, unknown/broken logo fallback, avatar success/error', screenshots: [output+'/about-you-390.png',output+'/about-you-review-390.png',output+'/about-you-accounts-390.png',output+'/about-you-mbti-empty-390.png'] };
};
const root = new URL('../', import.meta.url);
const rendererSource=fs.readFileSync(new URL('entry/src/main/ets/pages/A2uiHome/html/AboutYouRenderer.ets',root),'utf8');
// This renderer has only string/number annotations and no platform imports.
const renderer=Function(rendererSource.replaceAll(': string','').replaceAll(': number','').replaceAll('export function','function')+';return {buildAboutYouDocumentUrl};')();
const fixture = {
  output:path.resolve(process.env.ABOUT_YOU_PREVIEW_DIR||fileURLToPath(new URL('../tmp/about-you-preview-20260907/',root))).replaceAll('\\','/'),
  documentUrl:renderer.buildAboutYouDocumentUrl('test-token'),
  backdrop: fs.readFileSync(new URL('entry/src/main/resources/base/media/home_light_aurora_background.jpg',root)).toString('base64'),
  platformLogos:Object.fromEntries(['github','bilibili'].map(platform=>[platform,'data:image/svg+xml;base64,'+fs.readFileSync(new URL('entry/src/main/resources/base/media/logo_'+platform+'.svg',root)).toString('base64')]))
};
fs.mkdirSync(fixture.output, {recursive:true});
test('AboutYou renderer: actual Chromium interactions and mobile visual captures', async () => {
  let playwright;
  try { playwright=require(process.env.PLAYWRIGHT_MODULE_PATH||'playwright'); }
  catch (error) {
    throw new Error('Playwright is required for this browser test. Install playwright, set NODE_PATH, or set PLAYWRIGHT_MODULE_PATH to its module directory.', {cause:error});
  }
  const browser=await playwright.chromium.launch({channel:process.env.ABOUT_YOU_BROWSER_CHANNEL||'chrome',headless:true});
  try {
    const page=await browser.newPage();
    const result=await run(page,fixture);
    console.log(JSON.stringify(result));
  } finally { await browser.close(); }
});
