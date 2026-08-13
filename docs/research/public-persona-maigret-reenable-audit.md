# Public Persona：关闭来源复核与高价值替代源审计

更新时间：2026-08-13

## 结论

当前 18 个 enabled 来源不应因为本报告自动扩容；下面所有“可重测”仍需在**同一最终 HAP、同一台 HarmonyOS 真机**上用 claimed / unclaimed 两个 fixture 各跑一次，且 `found` 必须完成用户名、canonical URL 和 HTTPS 头像绑定。Mac、Maigret CLI 或 `curl` 成功只证明模板当前有活性，不等于手机闭环。

## 真机准入结果

最终 release HAP `5b33e253da5b271a87eb130d72c29bd911e9bb90b04d116c86bc0a0d17443c6a` 在
`6WS0226304000257` 完成微博双 fixture：`clairekuo → found/PASS`，随机不存在昵称
`→ not_found/PASS`。因此最终 enabled catalog 为 **18 个**：原 17 个已准入来源加微博。

同设备对照确认 ClashBox 关闭时 Bluesky claimed 为 `timeout/unknown`，开启 VPN 后 claimed 曾为
`found`；但其 unclaimed 在规则与全局代理下仍分别为 `timeout/unknown`、`client_error/unknown`。
Docker Hub、Hugging Face、Medium、Substack、Dailymotion、Mixcloud、YouTube 的 claimed 在全局代理下
也均为 `client_error/unknown`。Scratch、V2EX、X 等此前为 timeout，Chess 为 HTTP 401，豆瓣为
HTTP 200 但没有命中账号身份信号。按照双 fixture 门槛，这些来源继续 disabled；VPN 可证明部分域名的
路由影响，但不能把单次可达或单向成功变成产品准入。

本次追加复核固定 Maigret 最新 `main` 提交 [`b69f70f9`](https://github.com/soxoj/maigret/tree/b69f70f942afcc791875ca642ab4f8e62573b7be)。相较前一轮固定的 `b6fe0cd0`，本轮精查的 X、YouTube、Bluesky、Docker Hub、Medium、Substack 站点配置及 checker/activation 语义没有变化；最新提交只改 Web UI ribbon。因此下文旧 `b6fe0cd0` 永久链接仍指向相同内容，本节新增结论统一引用 `b69f70f9`。

按最小成本排序：

1. **已准入**：微博。
2. **可直接重测但本轮未准入**：YouTube、豆瓣、Docker Hub、Medium。
3. **需最小代码或网络修复后重测**：Scratch、Chess.com、X。
4. **当前通用用户名模型不可闭环**：Bilibili、Mastodon、NPM、知乎、DeviantArt。
5. **新增候选优先级**：Bluesky、Substack、Dailymotion、Mixcloud、HackerNoon、Hugging Face；次级为 Telegram。Reddit、Instagram 暂不进入最小修复批次。

## 审计方法与判定边界

Maigret 的 `url` 是展示地址，`urlProbe` 才是存在性探针；当前 App 已采用同样的展示/探测分离。[checking.py](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/checking.py#L1013-L1031)

- `message`：必须命中至少一个 `presenseStrs` 且不命中 `absenceStrs`；`status_code`：仅把 2xx 当 claimed。[checking.py](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/checking.py#L843-L864)
- 限流、验证码、403、5xx 或配置的错误页应为 `UNKNOWN`，不能算不存在。[CONTRIBUTING.md](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/CONTRIBUTING.md#L84-L108)
- `activation` 只在首个响应命中 marks 时运行，随后重试原请求一次；X 和微博都使用这一模式。[activation.py](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/activation.py#L9-L24) · [activation.py](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/activation.py#L153-L179)
- `tls_fingerprint` 会切换到 `curl_cffi` 的 Chrome impersonation；HarmonyOS `@ohos.net.http` 加浏览器 UA 仍不等价。[checking.py](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/checking.py#L943-L967)
- Maigret 自己要求 re-enable 做两层过滤：记录的 claimed/unclaimed 自检，再用明确随机用户名排除软 200。[CONTRIBUTING.md](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/CONTRIBUTING.md#L116-L130)

本轮只读运行了最新 Maigret 的 13 组 claimed/unclaimed。13 组在当前 Mac 出口均能区分；其中微博 claimed 依赖 activation。该结果只用于判断“模板是否仍值得真机测”，不作为产品放行证据。

## 关闭的 13 个来源逐项复核

| 来源 | Maigret 最新模板与状态判定 | fixtures | 上一轮无法闭环的具体原因 | 登录 / key / TLS / VPN | 最小动作与分类 |
| --- | --- | --- | --- | --- | --- |
| Bilibili | `api.bilibili.com/x/web-interface/card?mid={username}`；`message`；`"card":{` / `啥都木有`；类型为 `bilibili_id`、数字 regex。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L25-L44) | `2` / `999999999999` | HTTP 探针本身干净，但产品只输入通用 username，无法从 `luoyige` 推出数字 UID；把它加入全平台 username 扫描会是错误模型。 | 无登录/key；不是 VPN 问题。 | **当前不可闭环**。只有用户输入 B 站 profile URL/UID，或其他已确认 profile 明确链接出 B 站 UID 时，才走一次定向探测；不要加入裸用户名全扫。 |
| 知乎 | `/api/v4/members/{username}`；`message`；`"url_token"` / `用户不存在`；错误 `account/unhuman`，并标记 `tls_fingerprint`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L2252-L2274) | `kaifulee` / `noonewouldeverusethis7` | 旧真机结果在 success/unknown 间波动；上游明确依赖 Chrome TLS 指纹。普通 HTTP 即使 UA 相同，也可能进入反爬页。 | 无官方 key；需要浏览器级 TLS，VPN不能补 TLS 指纹。 | **当前不可闭环**。若现有 ArkWeb 能取回结构化 API/页面并把请求与当前 HAP 封装为只读一次，可做独立实验；否则不恢复。 |
| 微博 | 展示 `/n/{username}`，probe `/ajax/profile/info?screen_name={username}`；`message`；`ok:1/data/user` / “该昵称当前没有人使用”；先 `genvisitor2` 获取 `SUB/SUBP`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L955-L988) · [activation](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/activation.py#L153-L179) | `clairekuo` / `noonewouldeverusethis7` | 旧 fixture 曾混用数字 UID 与昵称；本轮已固定昵称路径并补齐明确缺失文案。最终同 HAP 双 fixture 分别为 `found/PASS` 与 `not_found/PASS`。 | 无登录/key；依赖匿名 visitor cookie；部分出口可能风控。 | **已准入**。保留当前 visitor activation、昵称 fixture 与双 fixture 真机门禁。 |
| Scratch | `api.scratch.mit.edu/users/{username}`；`status_code`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L893-L905) | `griffpatch` / `noonewould` | API 有结构化头像与 bio，旧真机既有一次 found，也多次 timeout；最新 6WS 仍为 timeout。上游没有 activation、镜像或备用 probe，说明不是缺模板。 | 无登录/key/TLS 特殊要求；疑似设备 DNS/路由或并发超时。 | **需网络诊断后重测**。先把该域名单独串行请求，记录 DNS/connect/read 分层；若仍 timeout 就保持关闭，不为它引入代理。 |
| Chess.com | `api.chess.com/pub/player/{username}`；`message`；`player_id`/API `@id` 与多个 404 marker；固定旧 Chrome UA。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L8016-L8044) | `sexytwerker69` / `aublurbrxm` | 2* 旧证据出现过 found，但 6WS 多轮明确 HTTP 401/unknown；当前代码已对齐上游 UA，上游无 activation/备用 API。 | 无登录/key；可能是出口/IP或服务端策略，不应把 401 当不存在。 | **需网络重测**。用单线程 exact 双 fixture；仍 401 即关闭。无需再改 parser。 |
| Mastodon | Maigret 只查固定 `mastodon.social/@{username}`、`status_code`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L14034-L14046)；官方 `accounts/lookup` 是公开 lookup，可返回 Account 或 404。[官方 API](https://docs.joinmastodon.org/methods/accounts/) | `Gargron` / `noonewouldeverusethis7` | 当前 App 更固定为 `fosstodon.org`；Fediverse 用户名跨实例不唯一，裸 `luoyige` 不能决定目标实例。旧真机 found/timeout 混合也只代表一个实例。 | 通常无登录/key；核心不是 VPN，而是缺实例域。 | **当前不可闭环**。输入模型改成 `user@instance` 或从已确认链接提取实例后再恢复；不要遍历任意实例。 |
| DeviantArt | 上游仍用 `https://{username}.deviantart.com`、`status_code`，且标记 `tls_fingerprint`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L2212-L2226) | `blue` / `noonewouldeverusethis7` | 旧真机一次 found 后同一来源又变 unknown；6WS 持续 timeout。Chrome UA 不能代替 TLS impersonation，且 status-only 缺身份正文绑定。 | 无登录/key；需要浏览器 TLS；VPN不保证解决。 | **当前不可闭环**。除非 ArkWeb 方案能稳定拿 canonical + HTTPS avatar，并用双 fixture 证明，否则不恢复。 |
| X | GraphQL `UserByScreenName`；Bearer + guest token activation；`message`；`"legacy"` / ` not found`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L124-L161) | `blue` / `noonewould123` | Mac/Maigret 当前可分正反，但旧手机对 x/twitter/API 域名 timeout/解析异常；query id、公开 bearer 和 guest token 还会漂移。当前 App 已有 activation，却未在手机出口稳定闭环。 | 不需用户登录，但依赖内部 web bearer/guest token；需要可达出口，VPN只解决路由，不解决 query 漂移。官方 v2 username lookup 要开发者 Bearer Token。[X 官方](https://docs.x.com/enterprise-api/getting-started/make-your-first-request) | **需最小维护后重测**。先同步最新 Maigret query/template，再在可达真机跑双 fixture；如果仍 timeout，关闭。若要长期稳定，改官方 token 配置，不把内部 bearer 当永久接口。 |
| YouTube | `https://www.youtube.com/@{username}/about`；`message`；`visitorData`/`userAgent` 与 `404 Not Found`；curl UA。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L66-L90) | `test` / `noonewouldeverusethis777` | 旧手机主要是 timeout；Maigret marker 偏站点壳，当前 App 的 canonical handle + HTTPS avatar 校验更严格。Mac 当前页面可分 200/404，仅说明模板活。 | 网页无需登录/key；中国网络出口可能不可达。官方 `channels.list(forHandle=)` 更稳定，但每次需 API key，单次 quota cost 1。[YouTube 官方](https://developers.google.com/youtube/v3/docs/channels/list) | **可直接重测**。优先网页双 fixture；可达且身份绑定通过则恢复。不要为广扫引入 YouTube key，除非网页路径持续不稳。 |
| 豆瓣 | `/people/{username}/`；`message`；`db-usr-profile` / `返回首页`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L3227-L3243) | `darkmage` / `noonewouldeverusethis7` | 无上游 protection/activation；Mac 当前为 200/404，但两台真机多轮 claimed 均 unknown。最可能是旧 App 要求 canonical+HTTPS 头像，而页面头像/canonical解析或设备响应不同。 | 无登录/key；不是已知 TLS 特例；可能有地区/UA风控。 | **可直接重测，必要时最小 parser 修复**。先保存脱敏 body 元数据，确认失败发生在 classify 还是 identity；只修 canonical/`userface` HTTPS 头像解析。 |
| NPM | registry search `maintainer:{username}&size=1`；`message`；`objects:[{` / `total:0`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L2597-L2615) | `sindresorhus` / `noonewouldeverusethis7` | 真机曾得到 found，但搜索结果证明“至少一个包的 publisher/maintainer 字符串匹配”，不稳定证明用户账号；响应没有用户头像，违反候选卡必须显示账号头像的产品要求。 | 无登录/key/TLS；不是网络问题。 | **当前不可闭环**。不要为凑来源放宽头像；找到公开、账号级、带稳定 avatar 的 endpoint 后再恢复。 |
| Docker Hub | `/v2/users/{username}/`；`status_code`；结构化 user JSON。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L1868-L1879) | `blue` / `noonewouldeverusethis7` | Mac 当前 200/404；旧 2* 真机是 timeout/unknown。当前 parser 已支持 username、full_name、avatar，逻辑缺口小。Docker 官方说明多数 Hub API 需要认证，但该 legacy public profile endpoint 仍是 Maigret 当前无鉴权探针，可能随时变动。[Docker 官方](https://docs.docker.com/reference/api/hub/latest/) | 当前探针无需 key；有速率限制/端点非稳定承诺风险。 | **可直接重测**。单独双 fixture、校验 avatar HTTPS；通过再恢复。若转 401/403，不引入用户 Docker 凭据。 |
| Medium | RSS `/feed/@{username}`；`status_code`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L713-L725) | `blue` / `noonewouldeverusethis7` | Mac 当前 200/404；旧真机 timeout/unknown。当前 App 已有 RSS canonical、title、avatar parser，主要风险是设备路由与 RSS 格式。 | 无登录/key；可能依赖可达出口。 | **可直接重测**。串行双 fixture；found 必须由 RSS link 的 `@username` 和 HTTPS `<url>` 头像共同证明。 |

## 高价值替代来源

优先选择公开结构化 JSON，避免为 HTML 站点引入 Firecrawl、账号登录或浏览器运行时。前六项代码目录里已经有探针草案，因此最小工作是修正模板、双 fixture 和真机准入，不需要新抽象。

| 优先级 | 来源 | Maigret / 官方探针 | fixtures | HarmonyOS 原生 HTTP 可实现性 | 建议 |
| --- | --- | --- | --- | --- | --- |
| 1 | Bluesky | `public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor={username}.bsky.social`；`did` / `Profile not found`；JSON 有 handle、displayName、avatar、description。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L1238-L1255) | `shamerli` / `noonewouldeverusethis7` | 高；公开 HTTPS JSON，无 key/activation。 | **第一批真机准入**。注意当前模板默认追加 `.bsky.social`，自定义域 handle 需要以后单独支持。 |
| 2 | Substack | `/api/v1/user/{username}/public_profile`，200/404；JSON 有 handle/name/photo_url/bio。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L1257-L1269) | `user23` / `noonewouldeverusethis7` | 高；公开 JSON，无 key。 | **第一批真机准入**。严格绑定返回 handle。 |
| 3 | Dailymotion | `api.dailymotion.com/user/{username}`，200/404；可请求 username、screenname、avatar、description、url。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L1359-L1375) | `blue` / `rstnodkwzr` | 高；公开 JSON，无 key。 | **第一批真机准入**。现有代码 fixture/template 版本需与最新上游对齐。 |
| 4 | Mixcloud | `api.mixcloud.com/{username}/`，200/404；JSON 有 username/name/pictures/biog/url。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L2545-L2561) | `jenny` / fake | 高；公开 JSON，无 key。 | **第一批真机准入**。 |
| 5 | HackerNoon | Cloud Function `profilesApi?handle={username}`，200/404；JSON profile 含 handle/displayName/avatar。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L4546-L4562) | `god` / `noonewouldeverusethis71` | 中高；公开 JSON，无 key，但 Google Cloud Function 在目标网络可能受影响。 | **第一批真机准入**，若目标设备 timeout 就关闭，不做代理。 |
| 6 | Hugging Face | Maigret 仅 HTML `status_code`，信号弱。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L3081-L3092)；更合适的公开路径为 `/api/users/{username}/overview`，需在真机验证返回 username/fullname/avatar。 | 上游 `blue` / fake | 高潜力；公开 JSON，无登录/key，但该 API 需要作为实际产品探针验证而不是照抄 HTML。 | **第一批研究/准入**。先固定响应契约测试，再开 enabled。 |
| 7 | Telegram | `t.me/{username}`；HTML absence markers；需 meta title/头像做严格身份绑定。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L522-L540) | `BotFather` / `noonewouldevereverusethis9` | 中；无 key，但中国网络可达性与 HTML 壳不稳定。 | **第二批**。先于真机验证网络，再考虑 parser。 |
| 8 | Reddit | `/user/{username}/about.json`；JSON marker 明确，但 Maigret 标注 `ip_reputation`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L577-L600) | `AutoModerator` / fake | 低至中；此前 Mac 出口也 403。 | **暂缓**。只有真实手机住宅/移动出口双 fixture 稳定才加；普通 VPN 不等于可用。 |
| 9 | Instagram | web profile JSON + `x-ig-app-id`/Referer；但上游明确 `tls_fingerprint`。[配置](https://github.com/soxoj/maigret/blob/b6fe0cd0e3c4cdbef6e86641a666a7e960292dbc/maigret/resources/data.json#L91-L122) | `cristiano` / fake | 低；普通 HarmonyOS HTTP 不等价于浏览器 TLS。 | **暂缓**，与知乎/DeviantArt 共用未来 ArkWeb/TLS 研究，不在本轮最小修复范围。 |

## 建议的下一轮最小执行顺序

1. 不改架构；微博已准入。后续只对 **YouTube、豆瓣、Docker Hub、Medium** 做同 HAP 双 fixture；只在具体 parser/activation 失败时修一处共享根因。
2. 再跑 **Scratch、Chess.com、X** 的单域名串行诊断；DNS/connect/read/HTTP/identity 分层。网络超时和 401 始终是 `UNKNOWN`。
3. 从现有 disabled 草案中按 **Bluesky → Substack → Dailymotion → Mixcloud → HackerNoon → Hugging Face** 逐个准入；每通过一个再开启一个，避免再次产生“候选池数量 = 可用来源数量”的口径混乱。
4. 不在本轮恢复 Bilibili、Mastodon、NPM、知乎、DeviantArt；它们分别需要新输入类型、实例域、账号级头像信号或浏览器 TLS，已超出最小修复。

这一路径保持 exact 广扫零 Firecrawl，也不引入新的运行时依赖、用户登录或平台凭据。

## 2026-08-13：X、YouTube 与 VPN 回归候选精查

本节只选 X、YouTube，以及最有希望在当前 **HarmonyOS 原生 HTTP + 用户已有 VPN** 条件下重新准入的四个来源：Bluesky、Docker Hub、Medium、Substack。选择标准是无需用户登录、无需平台 API key、Maigret 未标记 `tls_fingerprint`/`ip_reputation`，且现有 App 已有 parser 或结构化 identity 契约。VPN 只改变域名路由/出口 IP；它不会提供 Chrome TLS 指纹，也不会修复软 200、内部 API query-id 漂移或身份字段缺失。

| 来源 | 最新 Maigret 精确配置（`b69f70f9`） | VPN / TLS / IP 边界 | 当前 App 差异与重新准入门槛 |
| --- | --- | --- | --- |
| X / Twitter | 展示 `https://twitter.com/{username}`；probe `https://twitter.com/i/api/graphql/ZRnOhhXPwue_JGILb9TNug/UserByScreenName?...screen_name={username}...`；headers 为 Chrome 87 UA、`sec-ch-ua`、固定 web Bearer、`x-guest-token`；`message`；presence `"legacy"`；absence ` not found`；error `Bad guest token`；命中后 POST `https://api.twitter.com/1.1/guest/activate.json` 取得 `guest_token` 并只重试一次；fixtures `blue` / `noonewould123`；无 protection 标签。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L124-L161) · [activation.py](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/activation.py#L9-L24) | VPN 可能解决 `twitter.com`、`api.twitter.com` 的 DNS/路由；无 TLS/IP-reputation 标签。但内部 GraphQL query id、公开 Bearer/guest-token 都可漂移，VPN不能修。403、Bad guest token、timeout 必须 `UNKNOWN`。注意 unclaimed 实际可返回空 `data` 而不含 absence marker；Maigret 仍因 presence 未命中判 AVAILABLE，负例不要求必须命中 absence。 | 当前 catalog 错用 `https://x.com/{username}` HTML；虽然 request client 有 Twitter activation 分支，但该分支永远不会被当前 probe URL 触发。若恢复，最小修复应先把 probe/headers/markers/fixtures完整对齐 Maigret，再在 VPN 真机同 HAP 跑双 fixture；只同步 URL 而不跑双 fixture不可准入。 |
| YouTube | `url` 即 `https://www.youtube.com/@{username}/about`，无独立 `urlProbe`；headers `User-Agent: curl/8.6.0`、`Accept: */*`；`message`；presence `visitorData` 或 `userAgent`；absence `404 Not Found`；无 errors、activation、protection；regex `^[^/]+$`；fixtures `test` / `noonewouldeverusethis777`。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L66-L90) | VPN 可能解决 YouTube 路由；没有 TLS/IP-reputation标签。但 Maigret presence 是站点壳级信号，VPN 可达不等于账号存在。 | 当前 App 比 Maigret 严：要求 canonical handle 和 HTTPS `og:image`。但 catalog claimed 是 `YouTube` 而非 `test`，unclaimed 少末尾 `77`；presence 缺 `userAgent`，missing 缺 `404 Not Found`，regex 也比上游更窄。且 classify 对任意 2xx 先判 found，再靠 identity parser 降为 unknown。恢复门槛应为上游双 fixture 在同 HAP 完成 `found/not_found`，并证明 canonical + avatar；不能只看 2xx/`visitorData`。 |
| Bluesky | 展示 `https://bsky.app/profile/{username}.bsky.social`；probe `https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor={username}.bsky.social`；`message`；presence `"did"`；absence `Profile not found`；fixtures `shamerli` / `noonewouldeverusethis7`；无专用 headers、errors、activation、protection。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L1238-L1255) | VPN 曾让 claimed 从 timeout 变 found，说明路由相关；但 unclaimed 在规则/全局代理仍 unknown，说明 VPN/TUN 可能没有稳定接管 App 全部请求。无 TLS/IP-reputation标签。 | 当前 App 已严格绑定 handle、displayName、avatar、description，并要求 `.bsky.social` suffix。最有希望恢复，但必须先解决同一代理模式下 unclaimed 的 transport/client_error；只修超时不应改分类。自定义域 handle 不在本轮范围。 |
| Docker Hub | 展示 `https://hub.docker.com/u/{username}/`；probe `https://hub.docker.com/v2/users/{username}/`；`status_code`；fixtures `blue` / `noonewouldeverusethis7`；无专用 headers、presence/absence/errors、activation、protection。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L1868-L1879) | VPN 可能解决路由，未标 TLS/IP reputation；但 legacy Hub endpoint 与匿名 rate limit 会变化，401/403/429均应 `UNKNOWN`。 | App parser 已绑定返回 `username` 与 HTTPS avatar，严格度高于 Maigret。当前 fixture 是 `jpetazzo`，可保留更丰富头像样本，但双 fixture 真机必须在相同 VPN 模式通过；此前全局代理 `client_error` 表明先查 VPN/TUN而非 parser。 |
| Medium | 展示 `https://medium.com/@{username}`；probe RSS `https://medium.com/feed/@{username}`；`status_code`；fixtures `blue` / `noonewouldeverusethis7`；无专用 headers、markers、activation、protection。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L713-L725) | VPN 可能解决 Medium 路由；无 TLS/IP reputation。但 status-only 不能抵御未来软 200。 | 当前 App 已用 RSS link 的 `@username`、title 与 HTTPS `<url>` 头像做身份绑定，比 Maigret 严；catalog claimed 可继续用更丰富的 `sindresorhus`。全局代理下曾 `client_error`，先解决 App 是否实际走 VPN。双 fixture加随机第三样本通过后才恢复。 |
| Substack | 展示 `https://substack.com/@{username}`；probe `https://substack.com/api/v1/user/{username}/public_profile`；`status_code`；fixtures `user23` / `noonewouldeverusethis7`；无专用 headers、markers、activation、protection。[data.json](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/resources/data.json#L1257-L1269) | VPN 可能解决路由；无 TLS/IP reputation。此前全局代理为 client_error，不能解释为账号不存在。 | 当前 App 已声明 JSON identity `handle/name/photo_url/bio`，结构化程度足够。准入顺序可排在 Bluesky 后；同 HAP 双 fixture必须同时 terminal，claimed 还需 HTTPS photo。 |

Maigret 的 checker 会先合并站点 headers，再按 `urlProbe` 发请求；站点 errors、通用反爬文案、403 和 5xx 优先变为 UNKNOWN，之后才执行 message/status 判定。[checking.py](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/checking.py#L920-L967) · [checking.py](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/checking.py#L1013-L1073) · [error_detection.py](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/error_detection.py#L7-L36) 但 Maigret 的通用 detector 不自动覆盖 401/429：在 `status_code` 站点上可能把它们落成 AVAILABLE。产品实现不得照抄这个缺口，401/403/429/5xx、timeout、DNS/TLS/challenge 都必须是 `UNKNOWN`，只有平台明确的 404/不存在语义才能是 `not_found`。这六项都没有 `tls_fingerprint` 或 `ip_reputation` 标签，因此**理论上**可由 HarmonyOS 原生 HTTP 在可达 VPN 出口工作；这不是设备已经闭环的结论。

上述六源在 Maigret 中都走普通 `aiohttp`，而非 `curl_cffi` 浏览器 TLS impersonation。[checking.py](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/maigret/checking.py#L62-L112) Maigret 对 SOCKS5 transport 会把主机名交给代理解析，并在[排障文档](https://github.com/soxoj/maigret/blob/b69f70f942afcc791875ca642ab4f8e62573b7be/TROUBLESHOOTING.md#L5-L37)中建议降低并发、重试和住宅/移动出口；HarmonyOS App 没有可直接复制的 Python resolver/proxy 层。VPN 单次成功只能证明该设备当时的出口条件，不能证明任意用户网络都能闭环，也不能降低系统 TLS 校验。

当前 Mac 出口的正反旁证为：YouTube 200/404 且 markers 可分；Bluesky 为 200 + `did` / 400 + `Profile not found`；Docker Hub、Medium RSS、Substack API 均为 200/404。X 的静态 guest token 两例均返回 403 `Bad guest token`；执行 activation 取得 fresh token 后，`blue` 返回 200 且含 `legacy`，`noonewould123` 返回 200 空 `data`，可按 presence 缺失判负。它们只证明固定模板当前活跃，不是 HarmonyOS、VPN 或最终 HAP 的准入证据。

## 当前画像生成链路与 Maigret 的关系

结论：**运行时不依赖也不调用 Maigret/Sherlock。** 全仓生产路径没有 Maigret import、进程、Python、数据库或远端 Maigret 服务；只在 catalog 设计上借鉴了 `url/urlProbe`、claimed/unclaimed fixture、三态和 activation。当前画像生成链是 App 内独立实现：

1. 用户输入 username 和 exact/fuzzy 模式；`PublicPersonaClient.discover()` 读取 enabled catalog，以 3 个 worker 对每个平台调用 HarmonyOS 原生 `probePublicPersonaProfile()`。[PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L505-L583)
2. `probePublicPersonaProfile()` 用 `@ohos.net.http` 请求 probe，先做 `found/not_found/unknown` 分类；只有结构化用户名、canonical profile URL、HTTPS avatar 全部匹配才产生 identity/evidence。401/403/429/5xx/超时仍是 unknown。[PublicPersonaProbeClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaProbeClient.ets#L816-L897) · [PublicPersonaModel.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaModel.ets#L1009-L1062)
3. 精确模式到此结束，零 Firecrawl。模糊模式在原生扫描后至多调用一次 `web.research.search` 生成 URL 候选；每个 URL 仍必须回到原生 probe 复验，搜索摘要本身不能成为账号或画像证据。[PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L601-L650)
4. `found` identity 被写入内存 `nativeEvidence`，候选卡包含 platform/profile/displayName/username/avatar/bio；用户在 UI 显式确认 candidate IDs 后，Index 只把选中的候选交给 `buildSnapshot()`。[PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L533-L550) · [Index.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/pages/A2uiHome/Index.ets#L1634-L1665)
5. `buildSnapshot()` 优先复用 native evidence，不会为每个账号再抓页面。只有缺 native evidence/头像的最佳 fallback 会调用一次 `web.page.read`；返回 Markdown 最多取 12,000 字为 bio。随后 `compactEvidence()` 只保留 platform、profileUrl、displayName、username、bio、posts，**不把搜索排名、found/not_found/unknown、ownership confidence、搜索摘要或 Maigret marker送入模型**。[PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L418-L429) · [PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L667-L739)
6. `callDirectModel()` 接收 `{"accounts":[...]}` 和独立 system prompt，要求返回受限 `PublicPersonaInference` JSON；本地 parser 校验字段/MBTI，再由确定性 renderer 生成 `persona.md`，最后 snapshot sanitizer 校验并保存。[PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L64-L72) · [PublicPersonaClient.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaClient.ets#L738-L762) · [PublicPersonaModel.ets](/Users/luoyige/DevEcoStudioProjects/AIPhoneDemo/entry/src/main/ets/publicpersona/PublicPersonaModel.ets#L1164-L1285)

因此“参考 Maigret”只影响**发现与存在性判定**；模型看到的是用户确认后的紧凑公开资料，不知道 Maigret，也不会依据“某平台没搜到”推断人格。当前链路的实际信息上限也很明确：native probe 通常只提供 profile bio，`posts` 当前为空；除非触发唯一 fallback page-read，否则画像不会深读各账号内容。若未来要提升画像丰富度，应单独设计“确认后深读预算”，不要把广搜阶段或 Maigret markers直接塞进模型。

## 2026-08-13：6WS VPN 复核与画像生成实测

目标设备 `6WS0226304000257`，测试 HAP SHA-256
`a6ef1fcf73818b1a35ae149f5efabb764c0207e55873e3428bd74da02b1087f5`。候选 catalog 临时对齐最新
Maigret 的 X GraphQL activation 和 YouTube `/@handle/about` 模板；每个来源仍必须满足 claimed→`found`、
unclaimed→`not_found`，timeout/TLS/client error 均为 `unknown`。

| VPN 模式 / 节点 | X claimed `blue` | YouTube claimed `test` | 同轮边界 | 结论 |
| --- | --- | --- | --- | --- |
| 全局 / 新加坡 ② | `unknown`；guest activation POST 10 秒 timeout | `unknown`；TLS curl 35 | 20 个来源中 7 个 unknown | 节点破坏多站点路由/TLS，不准入 |
| 规则 / 新加坡 ② | `unknown`；connect timeout | `unknown`；connect timeout | 20 个来源中 5 个 unknown | 两站均未收到 HTTP 状态，不准入 |
| 规则 / 加拿大 ① | `unknown`；connect timeout | `unknown`；connect timeout | 20 个来源中 5 个 unknown | 换出口仍失败，不准入 |

所以 X、YouTube 候选生产改动已全部回退，正式 catalog 仍为 18 个；没有把 timeout 伪装成 `not_found`，
也没有为了通过而放宽 canonical、头像或身份绑定。VPN 已恢复为测试前的规则模式、关闭状态与新加坡节点。

画像链另用用户明确提供的 GitHub `XiaoLuoLYG` 真机闭环验证。精确搜索完成 18/18 明确终态，发现
GitHub、Gitee、GitLab；第二轮在候选页实际排除 Gitee/GitLab，只保留 GitHub。固定公开输入为 GitHub
profile 的 `login/name/avatar/html_url/bio`，其中 bio 是
`Master of Engineering, University of Cambridge (2023) | Senior AI Engineer at Huawei 2012 Lab`。
模型输出中的剑桥硕士、华为 2012 实验室因此有直接来源，不是无依据补全。

最终单来源 snapshot：

- `generatedAt=2026-08-13T02:53:37.516Z`；`sources.length=1`，唯一来源
  `https://github.com/XiaoLuoLYG`；头像是 HTTPS；
- `persona.md` 具备身份、专长、兴趣、沟通、近期关注、性格、MBTI、已确认账号全部章节；
- 顶部只显示一个主头像，MBTI 显示 `INTJ · 60%`；
- force-stop 后重启并重新进入画像页，Preferences 中 snapshot 逐字一致；
- 当前生成质量主要受 profile bio 上限约束，`posts` 仍为空；本轮没有把深读内容或上下文接入产品。

正式 18-source HAP SHA-256 为
`ede306418579242c95d998d6cec10d8ea6be1e17b4b90316f9f95be568069029`。运行时 HiLog 缓冲区未保留
画像业务 marker，因此“真机发现→排除→生成→保存→展示→重启回读”由 UI 与 Preferences 取证；“精确模式和
native evidence 不调用 Firecrawl”由上述生产分支与测试门禁证明，不能伪称为本轮 HiLog 证据。
