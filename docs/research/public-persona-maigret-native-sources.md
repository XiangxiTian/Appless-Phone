# Public Persona: Maigret 原生来源调研

更新时间：2026-08-10

## 结论

目标是新增 **20 个**来源，但不预先把任何候选写死为可用：按下列 43 个 active Maigret fixture 做真机验证，只保留任意一台真机上稳定满足 `usernameClaimed → found`、`usernameUnclaimed → not_found` 的最高优先级 20 个。若前 20 名有失败或 UNKNOWN，就顺序启用后备项补位；广搜阶段始终为零 Firecrawl。

QQ、百度贴吧、豆瓣、NPM 的官方配置有独立 probe 或较完整正文信号。CSDN、Reddit、Instagram 需要额外反爬能力；Gitee、语雀、博客园、V2EX、Hugging Face 等仅按状态码判断，不能在未排除软 200 前直接加入产品。SegmentFault、PyPI、Replit、Kaggle 的官方 Maigret 条目当前已禁用，不计入 43 个 active 候选。

本文只完成官方源代码审计，没有运行 HDC 或真机网络请求。Maigret 的 `cn` 标签只用于排序，不是 HarmonyOS 手机在中国网络下可达的证据；每个来源仍须用同一最终 HAP 对 claimed/unclaimed fixture 各请求一次，才能进入 catalog。

## 43 个候选的验证优先级

排序综合画像价值、Maigret 信号质量、中国网络环境下的域名优先级和当前实现成本；它不是可达性结论。

| 顺位 | 候选（按验证顺序） | 用法 |
| --- | --- | --- |
| 1–10 | QQ、百度贴吧、豆瓣、NPM、LeetCode CN、Gitee、GitCode、语雀、博客园、V2EX | 国内/开发者优先批；状态码项仍须正文或可靠 404 佐证 |
| 11–20 | 图虫、Stack Overflow、GitLab、Bitbucket、Docker Hub、DEV Community、Product Hunt、Keybase、Hugging Face、CSDN | 暂定新增 20 的后半；失败即由下一组补位 |
| 21–32 | Codecademy、Pinterest、Medium、Reddit、Instagram、Behance、Dribbble、SoundCloud、Spotify、Goodreads、Letterboxd、Last.fm | 高价值国际后备；反爬/网络错误只记 UNKNOWN |
| 33–43 | Telegram、Steam、Tumblr、mastodon.social、Flickr、About.me、VK、Facebook、Quora、Patreon、Substack | 第二后备；按各自正文/状态/保护规则验证 |

## 判定规则

本次固定审计 Maigret `main` 提交 [`7c34b804`](https://github.com/soxoj/maigret/tree/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c)。官方规则是：

- `message` 必须命中至少一个 `presenseStrs`，且不能命中 `absenceStrs`；反爬、限流、验证码应进入 `errors`，结果为 UNKNOWN，而不是不存在。[CONTRIBUTING.md](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/CONTRIBUTING.md#L84-L106)
- `urlProbe` 可把存在性检查放到公开 JSON/XHR 接口，同时保留面向用户的资料页 URL。[CONTRIBUTING.md](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/CONTRIBUTING.md#L94-L104)
- `status_code` 只看 HTTP 状态；实现中任何 2xx 都是 CLAIMED。官方也明确指出，软 200 是这种模式最常见的假阳性来源。[checking.py](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L747-L778) · [CONTRIBUTING.md](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/CONTRIBUTING.md#L88-L96)
- `activation` 是站点配置显式指定的二次 token/cookie 交换；没有 `activation` 字段就没有对应激活流程。Maigret 在挑战标记命中后只重试一次。[activation.py](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/activation.py#L9-L40) · [checking.py](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/checking.py#L1010-L1043)

## 首批候选的精确配置

表中的“无”表示该站点条目没有配置该字段，不代表服务端永远不需要通用浏览器 User-Agent。

| 来源 | URL / probe | `checkType` 与标记 | 用户名约束与 fixtures | headers / activation / protection | 不依赖 Firecrawl 的判断 |
| --- | --- | --- | --- | --- | --- |
| [QQ](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3-L24) | 展示 `https://user.qzone.qq.com/{username}`；probe `https://users.qzone.qq.com/fcg-bin/cgi_get_portrait.fcg?uins={username}` | `message`；存在 `portraitCallBack(`；不存在 `"",0]` 或 `"error"` | regex <code>^[1-9][0-9]{4,8}$&#124;^[1-3][0-9]{9}$</code>；claimed `10001`；unclaimed `3999999999` | headers 无；activation 无；protection 无；响应编码 `gbk` | **可以**，probe 与正反标记完整；但它不是通用用户名来源，只适合数字 QQ ID 或显式关联链接。 |
| [百度贴吧](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L727-L739) | `https://tieba.baidu.com/i/sys/user_json?un={username}&ie=utf-8`；无单独 `urlProbe`，该 JSON URL 同时是检查/报告 URL | `message`；存在 `"raw_name"`；不存在标记无 | regex 无；claimed `maigret`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **可以做候选**，但只有正标记；超时、错误 JSON、反爬页必须保持 UNKNOWN，不能把“未命中”直接当不存在。产品展示 URL 后续宜另取可点击资料页。 |
| [豆瓣](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3227-L3244) | `https://www.douban.com/people/{username}/`；无单独 probe | `message`；存在 `db-usr-profile`；不存在 `返回首页` | regex 无；claimed `darkmage`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **可以**，HTML 正反标记均有；仍需确认手机端没有统一登录/验证码壳页。 |
| [NPM](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L2597-L2616) | 展示 `https://www.npmjs.com/~{username}`；probe `https://registry.npmjs.org/-/v1/search?text=maintainer:{username}&size=1` | `message`；存在 `"objects":[{`；不存在 `"total":0` | regex 无；claimed `sindresorhus`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **可以**，公开 registry JSON 可直接判定；注意它证明“至少维护一个可搜索包”，不一定等价于 NPM 账号不存在。 |
| [LeetCode CN](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3863-L3876) | `https://leetcode.cn/u/{username}/`；无单独 probe | `message`；存在 `"userAvatar"`；不存在标记无 | regex 无；claimed `leetcode`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **有条件可以**；必须证明未注册页面不会在通用 hydration 数据中也包含 `userAvatar`，并把挑战/空壳保持 UNKNOWN。 |
| [GitCode](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3838-L3851) | `https://gitcode.com/{username}`；无单独 probe | `message`；存在 <code>AtomGit &#124; GitCode</code>；不存在标记无 | regex 无；claimed `chatgpt`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **暂缓**；标记看起来像站点级标题而非账号级信号，真机双样本必须证明它不会同时出现在软 404。 |
| [图虫](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L624-L638) | `https://{username}.tuchong.com/`；无单独 probe | `message`；存在 `- 图博 - 图虫`；不存在标记无 | regex `^[a-zA-Z0-9]+$`；claimed `foto`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；protection 无 | **有条件可以**；只适合纯字母数字用户名，并需确认子域软 404 与 DNS/证书错误不会被误判。 |
| [CSDN](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L43219-L43238) | `https://blog.csdn.net/{username}`；无单独 probe | `message`；存在 `data-username="`；不存在标记无 | regex 无；claimed `csdnnews`；unclaimed `noonewouldeverusethis7` | headers 无；activation 无；`protection=["tls_fingerprint","custom_bot_protection"]` | **当前不应直接加入**；Maigret 需要浏览器 TLS 指纹和自定义反爬路径，HarmonyOS 普通 HTTP GET 不能据此宣称等价可用。 |

## 高价值国际候选

| 来源 | 精确配置 | 判断 |
| --- | --- | --- |
| [Reddit](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L577-L600) | 展示 `https://www.reddit.com/user/{username}`；probe `https://www.reddit.com/user/{username}/about.json`；`message`；存在 `"name":`；不存在 `Not Found`；regex/headers/activation 无；claimed `AutoModerator`；unclaimed `noonewouldeverusethis7`；`protection=["ip_reputation"]` | JSON 信号本身可脱离 Firecrawl，但 IP reputation 明确是前置风险；只在真机双样本都稳定时加入。 |
| [Instagram](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L91-L123) | 展示 `https://www.instagram.com/{username}/`；probe `/api/v1/users/web_profile_info/?username={username}`；`message`；存在 `"biography"`；不存在 `Sorry, this page isn&#39;t available.` / `dialog-404`；headers `x-ig-app-id: 936619743392459`, `referer: https://www.instagram.com/`；activation/regex 无；claimed `cristiano`；unclaimed `noonewouldeverusethis77777`；另有登录/限流 errors 和 `tls_fingerprint` protection | Maigret 可在带 Chrome 指纹的客户端中无 Firecrawl 判断，但普通 HarmonyOS HTTP 还缺该能力；不列入国内首批。 |

## 其余 28 个 active 候选的精确配置

以下条目与前文 15 个详细条目合计 43 个。未注明的 regex、headers、activation、protection 均为“无配置”。

- [Stack Overflow](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1217)：URL `https://stackoverflow.com/users/filter?search={username}`；probe `https://api.stackexchange.com/2.3/users?order=desc&sort=name&inname={username}&site=stackoverflow`；`message`；存在 `"items":[{`；不存在 `"items":[]`；claimed/unclaimed `maigret` / `noonewouldeverusethis7`。
- [GitLab](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1106)：URL `https://gitlab.com/{username}`；probe `https://gitlab.com/api/v4/users?username={username}`；`message`；存在标记无，Maigret 对任意非空响应视为 presence；不存在 `[]`；fixtures `blue` / `noonewouldeverusethis7`。
- [Bitbucket](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3143)：URL `https://bitbucket.org/{username}/`；probe `https://api.bitbucket.org/2.0/workspaces/{username}`；`status_code`；regex `^[a-zA-Z0-9-_]{1,30}$`；正文标记无；fixtures `atlassian` / `noonewouldeverusethis7`。
- [Docker Hub](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1868)：URL `https://hub.docker.com/u/{username}/`；probe `https://hub.docker.com/v2/users/{username}/`；`status_code`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [DEV Community](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3793)：URL `https://dev.to/{username}`；无 probe；`status_code`；regex `^[a-zA-Z][a-zA-Z0-9_-]*$`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [Product Hunt](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3984)：URL `https://www.producthunt.com/@{username}`；无 probe；`message`；存在 `:{"data":{"profile":{"__typename"`；不存在 `We seem to have lost this page`；fixtures `rajiv_ayyangar` / `noonewouldeverusethis7`。
- [Keybase](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L7522)：URL `https://keybase.io/{username}`；probe `https://keybase.io/_/api/1.0/user/lookup.json?usernames={username}`；`message`；存在标记无；不存在 `them":[null]` / `bad list value`；fixtures `blue` / `noonewouldeverusethis7`。
- [Codecademy](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L4478)：URL `https://www.codecademy.com/profiles/{username}`；无 probe；`message`；存在 `Codecademy profile page for`；不存在 `This profile could not be found`；fixtures `blue` / `noonewouldeverusethis7`。
- [Pinterest](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L325)：URL `https://www.pinterest.com/{username}/`；无 probe；`message`；存在 `"@type":"ProfilePage"`；不存在 `User not found.`；fixtures `blue` / `noonewouldeverusethis7`。
- [Medium](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L713)：URL `https://medium.com/@{username}`；probe `https://medium.com/feed/@{username}`；`status_code`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [Behance](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1201)：URL `https://www.behance.net/{username}`；无 probe；`status_code`；header `User-Agent: Curl`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [Dribbble](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1993)：URL `https://dribbble.com/{username}`；无 probe；`message`；regex `^[a-zA-Z][a-zA-Z0-9_-]*$`；存在标记无；不存在 `Whoops, that page is gone.`；fixtures `blue` / `noonewouldeverusethis7`。
- [SoundCloud](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L740)：URL `https://soundcloud.com/{username}`；无 probe；`message`；存在 `"hydratable":"user"`；不存在 `SoundCloud - Hear the world’s sounds`；fixtures `blue` / `noonewouldeverusethis7`；`protection=["tls_fingerprint"]`。
- [Spotify](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L639)：URL `https://open.spotify.com/user/{username}`；probe `https://api.stats.fm/api/v1/users/{username}`；`status_code`；正文标记无；fixtures `alex` / `noonewouldeverusethis7`。注意 probe 是第三方 stats.fm，不是 Spotify 官方接口。
- [Goodreads](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1695)：URL `https://www.goodreads.com/{username}`；无 probe；`message`；存在 `og:type" content="profile"`；不存在标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [Letterboxd](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L7032)：URL `https://letterboxd.com/{username}`；无 probe；`message`；存在标记无；不存在 `Sorry, we can’t find the page you’ve requested.`；fixtures `blue` / `noonewouldeverusethis7`；`protection=["tls_fingerprint"]`。
- [Last.fm](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3170)：URL `https://last.fm/user/{username}`；无 probe；`status_code`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`；`protection=["tls_fingerprint"]`。
- [Telegram](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L522)：URL `https://t.me/{username}`；无 probe；`message`；regex `^[a-zA-Z][a-zA-Z0-9_]{4,}$`；存在标记无；不存在 `<meta name="robots" content="noindex, nofollow">` / `<meta property="twitter:title" content="Telegram: Contact`；fixtures `BotFather` / `noonewouldevereverusethis9`。
- [Steam](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L2903)：URL `https://steamcommunity.com/id/{username}`；无 probe；`message`；存在标记无；不存在 `The specified profile could not be found`；fixtures `blue` / `noonewouldeverusethis7`。
- [Tumblr](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L601)：URL `https://www.tumblr.com/{username}`；无 probe；`message`；regex `^[^\.]+$`；存在 `profile` / ` title=`；不存在 `Not found.` / `:404,` / `userAgent`；fixtures `soxoj` / `zdbimdoqyt`。
- [mastodon.social](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L14029)：URL `https://mastodon.social/@{username}`；无 probe；`status_code`；regex `^[a-zA-Z0-9_]+$`；正文标记无；fixtures `Gargron` / `noonewouldeverusethis7`。
- [Flickr](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L673)：URL `https://www.flickr.com/photos/{username}`；无 probe；`status_code`；正文标记无；fixtures `blue` / `noonewouldeverusethis7`。
- [About.me](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L2966)：URL `https://about.me/{username}`；无 probe；`status_code`；正文标记无；fixtures `jeff` / `noonewouldeverusethis7`。
- [VK](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L819)：URL `https://vk.com/{username}`；无 probe；`status_code`；regex `^(?!id\d)[a-zA-Z0-9_]*$`；正文标记无；fixtures `smith` / `blah62831`。
- [Facebook](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L45)：URL `https://www.facebook.com/{username}`；无 probe；`message`；regex `^[a-zA-Z0-9_\.]{3,49}(?<!\.com|\.org|\.net)$`；存在 `first_name`；不存在 `rsrcTags`；fixtures `zuck` / `noonewouldeverusethis7`；header 是 Maigret 固定 Chrome 74 Windows User-Agent。
- [Quora](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L2011)：URL `https://www.quora.com/profile/{username}`；无 probe；`response_url`；正文标记无；fixtures `Matt-Riggsby` / `noonewouldeverusethis7`；`protection=["cf_js_challenge","tls_fingerprint"]`。
- [Patreon](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L2196)：URL `https://www.patreon.com/{username}`；无 probe；`status_code`；正文标记无；fixtures `annetlovart` / `noonewouldeverusethis7`；`protection=["cf_js_challenge"]`。
- [Substack](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L1257)：URL `https://substack.com/@{username}`；probe `https://substack.com/api/v1/user/{username}/public_profile`；`status_code`；正文标记无；fixtures `user23` / `noonewouldeverusethis7`。

## 仅状态码：软 200 风险清单

以下条目都没有 `urlProbe`、regex、headers、activation 或正文标记；Maigret 只把 2xx 当存在。它们可以作为真机研究对象，但在 claimed/unclaimed 同机响应差异得到证明前，不应成为产品来源。

| 来源 | URL | claimed / unclaimed | 风险 |
| --- | --- | --- | --- |
| [Gitee](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3827-L3837) | `https://gitee.com/{username}` | `wizzer` / `noonewouldeverusethis7` | `status_code`；高价值但必须排除登录壳、风控页和软 404 均返回 200。 |
| [语雀](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3852-L3862) | `https://www.yuque.com/{username}` | `yuque` / `noonewouldeverusethis7` | `status_code`；可能返回统一前端壳。 |
| [博客园](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L39227-L39235) | `https://cnblogs.com/{username}` | `adam` / `noonewouldeverusethis7` | `status_code`；缺正文负标记。 |
| [V2EX](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L40885-L40893) | `https://v2ex.com/member/{username}` | `adam` / `noonewouldeverusethis7` | `status_code`；还需把 403/429/风控响应保持 UNKNOWN。 |
| [Hugging Face](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L3081-L3093) | `https://huggingface.co/{username}` | `blue` / `noonewouldeverusethis7` | `status_code`；画像价值高，但不是国内优先域名且没有正文确认。 |

## 明确暂缓

- [SegmentFault](https://github.com/soxoj/maigret/blob/7c34b8042a57d9b8c52ef94b62a53250bee9ff0c/maigret/resources/data.json#L9415-L9433)：`disabled: true`；虽配置 `message`、存在 `- SegmentFault 思否</title>`、不存在 `message":"Not Found"`，claimed/unclaimed 为 `john` / `noonewouldeverusethis7`，但官方数据库默认跳过禁用站点，不能作为当前可用来源。
- Kaggle 同样已禁用且有 reCAPTCHA 错误标记；Medium 仍是 `status_code`；两者都不值得挤占首轮国内真机验证预算。

## 进入 catalog 的最小门槛

每个候选只做一组最小真机检查：

1. 同一 HAP、同一网络、同一请求实现依次请求官方 `usernameClaimed` 与 `usernameUnclaimed`。
2. 记录最终 URL、状态码、正文长度、命中的存在/不存在/error 标记；不保存完整个人资料正文。
3. claimed 必须命中账号级存在信号；unclaimed 必须命中独立负信号或可靠 404/410。两者相同、超时、403、429、5xx、验证码、登录壳、通用 SPA 壳一律为 UNKNOWN。
4. 通过后再决定展示 URL、身份字段解析和画像内容价值；“可判断存在”不等于“有足够内容生成画像”。
