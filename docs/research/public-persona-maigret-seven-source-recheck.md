# Public Persona：原 7 个高价值来源的 Maigret 复核

更新时间：2026-08-11

## 结论先行

此前把这 7 个来源统一归结为“无法搜索”并不准确。源码复核后的分类是：

| 来源 | 是否主要可能是 VPN / 出口问题 | Maigret 是否有现成办法 | 当前产品判断 |
| --- | --- | --- | --- |
| X（Twitter） | **是**；中国网络可达性会直接影响 guest activation 和 GraphQL probe | **有**：固定 Bearer、guest token、失效后 activation，再重试一次 | 当前出口已完成 claimed / unclaimed 分离，恢复原生探测 |
| YouTube | **是** | 有公开 `@handle/about` 模板，但没有特殊绕过 | 当前出口已完成 claimed / unclaimed 分离，以精确 handle canonical + HTTPS 头像取代弱正文标记并恢复 |
| Reddit | **部分是**，但普通 VPN 可能更糟 | 有 `/about.json` probe；`ip_reputation` 只能靠外部住宅/移动出口或代理改善 | 值得用干净住宅出口重测，不应把数据中心/VPN IP 的 403 当“不存在” |
| Instagram | VPN 只能解决地区可达，**不能单独解决 TLS 指纹** | **有**：公开 web profile API + `x-ig-app-id` / `referer` + `curl_cffi` Chrome TLS 模拟 | 普通 HarmonyOS HTTP 与 Maigret 不等价；补浏览器级 TLS 后才值得恢复 |
| LinkedIn | **不是主要原因**；已拿到统一 200 落地页时，换 VPN 不会修复存在性信号 | 条目存在，但只是 `status_code`；Maigret 本身也会把软 200 误判为 CLAIMED | 暂不恢复；需要账号级正文/结构化信号或官方授权，不应照抄 Maigret 条目 |
| 小红书 | **不是** | **没有条目，也没有 Maigret 现成模板** | 不能当作 Maigret 式“输入用户名直查”来源；应走明确 profile 链接、平台 ID 或公开搜索发现后再确认 |
| 抖音 | **不是**；Maigret 的 TikTok 是国际站，不是抖音 | **没有抖音条目**；只有 `tiktok.com/@{username}` | 官方接口以用户授权后的 `open_id` 为键；普通昵称不是可直接套模板的公开唯一 username |

因此，本轮恢复 **X、YouTube**；Reddit、Instagram 仍需不同出口或请求栈验证，LinkedIn 需要换判定信号，小红书/抖音需要换输入模型，而不是换 VPN。

## 审计范围

- 固定版本：Maigret [`7c34b8042a57d9b8c52ef94b62a53250bee9ff0c`](https://github.com/soxoj/maigret/tree/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c)。
- 最新主线：2026-08-11 拉取到的 [`34a1669974892a42abbb2a2bbbb654a63a1e257f`](https://github.com/soxoj/maigret/tree/34a1669974892a42abbb2a2bbbb654a63a1e257f)。
- 将 `YouTube`、`Instagram`、`Twitter`、`TikTok`、`Reddit`、`LinkedIn` 六个对象排序后计算 SHA-256，两版同为 `bbaa9ee63ee24330a54473aabbabc6bb888dc2dfe27dfe8bc8d1a0498ed4e4b6`；`checking.py` 与 `activation.py` 两版也逐文件一致。因此下列固定 commit 结论仍代表当前主线。官方 [compare](https://github.com/soxoj/maigret/compare/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c...34a1669974892a42abbb2a2bbbb654a63a1e257f) 中没有这六个条目的改动。
- `data.json` 全部 site keys 在两版都没有 Xiaohongshu / RED / Douyin；官方仍开放的中国站支持 issue 也把抖音、小红书列为待支持项，维护者随后列出的已支持中国站不包含二者。[issue #2634](https://github.com/soxoj/maigret/issues/2634) · [维护者的当前支持清单](https://github.com/soxoj/maigret/issues/2634#issuecomment-4882782373)
- 本轮完成官方源码、文档和 issue 审计，并在当前 Mac 出口直接验证 X、YouTube 的 claimed / unclaimed 分离；真机请求仍待提交后用同一签名 HAP 验证。

## Maigret 的网络与反爬能力到底做了什么

### 代理与 VPN

Maigret 的 `--proxy` 会把所有明网站点请求交给指定 HTTP/SOCKS 代理；`--tor-proxy` 只服务 `.onion`，并不会替明网站点自动翻墙。VPN 由操作系统透明接管，Maigret 没有“自动选择 VPN”逻辑。[代理参数](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/command-line-options.rst#L66-L91) · [Tor 与明网的区分](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/tor-and-proxies.rst#L6-L29)

官方 FAQ 明确提醒：常见 VPN 出口本身可能被 WAF 拉黑，住宅/移动代理通常比普通 VPN 或 Tor 更适合修复 403；所以“开了 VPN”不等于“出口适合用户名探测”。[VPN 说明](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/faq.rst#L60-L80) · [403 排查顺序](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/faq.rst#L139-L152)

### TLS 指纹

`protection: ["tls_fingerprint"]` 是目前唯一会自动改变请求实现的 protection 标签：Maigret 改用 `curl_cffi` 并模拟 Chrome TLS；`ip_reputation` 只是说明标签，不会自动换 IP。[protection 语义](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/development.rst#L142-L160)

代码中 `CurlCffiChecker` 确实传入 `impersonate='chrome'`，并可继续使用显式 proxy；依赖也直接包含 `curl-cffi`。[checker 实现](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L304-L373) · [路由选择](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L847-L871) · [依赖](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/pyproject.toml#L55-L67)

### Cookie、activation 与重试

- `--cookies-jar-file` 会导入 Netscape cookie jar，并传给普通 `aiohttp` checker。[cookie 参数](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/command-line-options.rst#L89-L91) · [运行时装载](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L1162-L1170)
- 但固定 commit 中 `CurlCffiChecker` 构造器只接收 `proxy`，没有接收上述 cookie jar；因此 Instagram 走 TLS 模拟路径时，不能把“Maigret 支持 cookie 文件”直接理解为“Instagram 的 curl 路径已经使用这些 cookie”。这是源码推断，不是官方承诺。[TLS checker 构造](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L307-L345) · [实例化参数](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L864-L869)
- `activation` 不是通用浏览器登录。只有响应命中站点配置的 marks，Maigret 才调用对应 handler，更新 header/cookie/token，然后把原检查**再请求一次**。[activation 调度](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L1007-L1047)
- X 的 activation handler 会新建 `ClientSession(trust_env=True)`，但没有把 CLI 的显式 `--proxy` 参数传进去；因此系统 VPN / 环境代理可能覆盖 activation，请求级 `--proxy` 却不保证覆盖这第二跳。这是当前实现的边界。[Twitter handler](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/activation.py#L9-L24)
- `--retries N` 只重跑临时错误站点。timeout、DNS、连接、proxy 等可重试；站点正文标出的 captcha、login/rate-limit 会成为 `Site-specific`，不在临时错误表里，因此不会靠加 retries 自动恢复。[失败站点筛选](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L1081-L1089) · [重试循环](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L1231-L1301) · [错误分类](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/error_detection.py#L7-L35) · [临时错误表](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/errors.py#L103-L118)
- Maigret 没有通用、内置的完整 JS 浏览器模式；官方开发指南把确实依赖 DOM/JS 的站点留给未来的 `checkType: browser` 讨论。[SPA 处理阶梯](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/CONTRIBUTING.md#L100-L108)

## 逐平台复核

### 1. X（Maigret 条目名为 Twitter）

Maigret 使用：

- 展示 URL `https://twitter.com/{username}`；
- 私有 GraphQL `UserByScreenName` 作为 `urlProbe`；
- 固定 Bearer、浏览器 UA、`x-guest-token`；
- `"legacy"` 判存在，` not found` 判不存在；
- 仅当响应出现 `Bad guest token` 时，POST `https://api.twitter.com/1.1/guest/activate.json` 获取新 token，然后重试一次。

配置和 handler 均为启用状态。[Twitter 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L124-L161) · [activation handler](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/activation.py#L9-L24)

官方 issue 显示，旧版 X/Twitter 检查和域名匹配确实曾坏过；维护者在 2026-03 说明 Twitter check 和域名匹配已修复。[issue #2253](https://github.com/soxoj/maigret/issues/2253#issuecomment-4121346356) · [issue #299](https://github.com/soxoj/maigret/issues/299#issuecomment-4202693535) 但随后合入 activation 并发修复的 [PR #2765](https://github.com/soxoj/maigret/pull/2765) 也如实记录：当时 live Twitter GraphQL 测试仍返回 HTTP 403。

**本轮验证：**当前出口上，`X` 经 guest activation 后 GraphQL 返回 HTTP 200，并在 `data.user.legacy` 中得到账号资料；随机不存在用户名 `noonewouldeverusethis7` 同样返回 HTTP 200，但正文是明确的 `{"data":{}}`。产品已复用 Maigret 的 guest activation，并兼容 `data.user.legacy` 与 `data.user.result.legacy`；仅明确空 `data` 判 `not_found`，403、限流与超时仍判 `unknown`。

**判断：**X 已满足 claimed / unclaimed 分离，可恢复。Bearer、GraphQL query id、guest 流程和出口风控仍可能漂移，所以真机验收必须要求探测真正 terminal，不能把 timeout 当成功。

### 2. YouTube

Maigret 直接 GET `https://www.youtube.com/@{username}/about`，只加 `curl/8.6.0` UA 与 `Accept: */*`，正文含 `visitorData` 或 `userAgent` 就判存在，含 `404 Not Found` 判不存在；没有 activation、proxy 特例或 protection 标签。[YouTube 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L66-L90)

YouTube 官方明确说明 handle 是唯一 channel identifier，`youtube.com/@handle` 是正式分享 URL，因此“用户名模型不成立”不适用于 YouTube。[YouTube Handle 官方说明](https://support.google.com/youtube/answer/11585688?hl=en)

但 Maigret 的 `visitorData` / `userAgent` 不是账号级字段，且官方仓库有错误命中报告，例如 [#2166](https://github.com/soxoj/maigret/issues/2166) 与 [#2190](https://github.com/soxoj/maigret/issues/2190)。

**本轮验证：**当前出口上，`https://www.youtube.com/@YouTube/about` 返回 HTTP 200，页面包含精确的 handle canonical `https://www.youtube.com/@YouTube/about` 和 HTTPS `og:image`；随机不存在用户名 `noonewouldeverusethis7` 返回 HTTP 404。旧解析失败的根因是只认结构化 `canonicalBaseUrl`，没有接受当前页面直接输出的 handle canonical。

**判断：**YouTube 已满足 claimed / unclaimed 分离，可恢复。产品不照抄 Maigret 的 `visitorData` / `userAgent` 弱标记，而是同时要求精确 handle canonical 与 HTTPS 头像；普通 channel canonical 或通用软壳仍判 `unknown`。

### 3. Reddit

Maigret 用 `https://www.reddit.com/user/{username}/about.json`，正文含 `"name":` 判存在，含 `Not Found` 判不存在；条目标记 `protection: ["ip_reputation"]`，仍保持启用。[Reddit 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L577-L600)

该 JSON probe 是维护者在 [issue #501](https://github.com/soxoj/maigret/issues/501#issuecomment-4106945084) 明确合入的。官方 development 文档同时说明 `ip_reputation` 无自动绕过，建议普通住宅网络或 `--proxy`；数据中心、云和部分 VPN 出口仍会被拦。[ip reputation 说明](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/docs/source/development.rst#L154-L160)

**判断：**这不是“Reddit 无法按用户名搜索”，而是出口信誉约束。应使用干净住宅/移动出口对照；普通商业 VPN 可能比手机原生住宅网络更差。403、timeout、限流只能是 UNKNOWN。

### 4. Instagram

Maigret 的 probe 是 `https://www.instagram.com/api/v1/users/web_profile_info/?username={username}`，加 `x-ig-app-id` 与 `referer`；正文 `"biography"` 判存在，并显式把登录墙、session blocked 和 rate limit 记为错误。条目启用了 `tls_fingerprint`，因此会走 `curl_cffi` Chrome 模拟。[Instagram 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L91-L123)

官方 issue 记录 Instagram 在连续请求后会要求登录；最近的 [#2846](https://github.com/soxoj/maigret/issues/2846) 则说明 existence 可以 CLAIMED，但扩展资料解析曾因响应 JSON 结构变化失效，后来由 socid-extractor 修复。这说明“账号存在性”和“足够资料生成画像”必须分别验证。

**判断：**VPN 只能解决域名可达或更换 IP，无法模拟 JA3/JA4。要与 Maigret 等价，手机端需要浏览器级 TLS 客户端或 ArkWeb 类浏览器通路；仅补 headers、timeout 或 Firecrawl 都不是同一个修复。

### 5. LinkedIn

Maigret 条目只有 `https://linkedin.com/in/{username}` + 浏览器 headers，`checkType` 为 `status_code`；没有 `urlProbe`、正文正负标记、activation、protection 或 cookie 配置。[LinkedIn 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L42307-L42327)

Maigret 的实现把任意 2xx 直接判为 CLAIMED；官方贡献指南也明确警告：站点如果用 HTTP 200 返回软 404，`status_code` 是最常见的假阳性来源。[判定实现](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L747-L768) · [checkType 规则](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/CONTRIBUTING.md#L84-L96)

LinkedIn 官方确认 `/in/...` 是可定制、大小写不敏感且先到先得的公开 profile URL，所以输入 URL slug 的模型本身成立；但用户可关闭/限制公开资料，旧 URL 也会经历保留和 `Profile Not Found` 状态。[LinkedIn 官方帮助](https://www.linkedin.com/help/linkedin/answer/a542685/manage-your-public-profile-url?lang=en) · [公开资料可见性](https://www.linkedin.com/help/linkedin/answer/a528138/control-your-public-linkedin-profile?lang=en)

**判断：**如果 claimed 与随机 unclaimed 都是同一 200 商业页，VPN 已经完成“可达”，问题是没有账号级存在信号。Maigret 现成条目并不能解决，暂缓是正确的。

### 6. 小红书

固定 commit 与最新主线都没有 Xiaohongshu / RED site；官方中国站支持 issue 仍把小红书列在需求中，维护者公布的已加入站点也没有它。[issue #2634](https://github.com/soxoj/maigret/issues/2634#issuecomment-4503100921) · [已支持清单](https://github.com/soxoj/maigret/issues/2634#issuecomment-4882782373)

小红书公开的开放平台页面聚焦小程序/商家授权，并要求在小红书 App 内完成授权，没有公开“按任意用户名查询个人账号”的接口可直接替代 Maigret template。[小红书授权文档](https://miniapp.xiaohongshu.com/third/api-3rd-doc/guideAuth)

**判断：**当前不能把普通输入字符串稳定映射为一个可构造、可判存在的 Maigret profile URL。VPN 不是缺失模板的解法；demo 若要支持，应从用户提供的 profile 链接、页面内明确账号 ID，或公开搜索结果开始，再让用户确认归属。

### 7. 抖音（不是 TikTok）

Maigret 只有 TikTok：`https://www.tiktok.com/@{username}`，正文 `"nickname":` 判存在、`serverCode":404` 判不存在，captcha 记错误；无 activation 或 protection 标签。[TikTok 条目](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L370-L393)

TikTok 检查在 2026-04、2026-07 都出现过随机用户名假阳性报告；一个被维护者判为无法复现，另一个直接关闭，没有形成新的专用绕过器。[issue #2456](https://github.com/soxoj/maigret/issues/2456) · [issue #2830](https://github.com/soxoj/maigret/issues/2830)

抖音官方开放平台的用户信息接口要求用户授权的 `access_token` 和 `open_id`，返回昵称、头像等；`open_id` 才是应用内唯一标识，昵称不是公开唯一查询键。[抖音用户信息接口](https://developer.open-douyin.com/docs/resource/zh-CN/dop/develop/openapi/account-permission/get-account-open-info) · [OAuth 标识定义](https://open.douyin.com/platform/resource/docs/develop/permission/overall-permission/)

**判断：**国际版 TikTok 的模板不能视为抖音实现。VPN 可以帮助访问 TikTok，但不会让 `douyin.com` 获得相同的用户名模型。抖音应改为“授权账号 / 明确 profile 链接或 ID”，而不是盲扫昵称。

## 对下一轮验证的最小建议

1. **X、YouTube：**用提交后的同一签名 HAP 在真机分别跑 claimed + unclaimed，要求真实 terminal；found 必须产生候选，not_found 不得产生候选，广搜 Firecrawl 调用数必须为 0。
2. **Reddit：**不要只换普通商业 VPN；优先住宅/移动出口，并记录 403/429/timeout 与最终正文标记。
3. **Instagram：**先补等价于 `curl_cffi` 的浏览器 TLS 路径，再测；否则重复普通 HTTP 没有信息增量。
4. **LinkedIn：**除非先找到独立账号级信号，否则不消耗更多 VPN 轮次。
5. **小红书、抖音：**先改输入模型为 URL/平台 ID/用户授权；不再把显示昵称当全局 username。

这份复核支持把已完成 claimed / unclaimed 分离的 X、YouTube 恢复到 catalog；其余五个平台继续保持禁用，直到各自缺失的账号级信号、出口或请求能力得到验证。
