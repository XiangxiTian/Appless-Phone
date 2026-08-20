# 豆瓣公开书影音 Playwright MCP Demo

这是一个给内部演示使用的实验来源：PocketAgent 连接云端运行的官方 Playwright MCP，读取豆瓣无需登录即可访问的图书、电影和音乐纵向搜索页，并把真实页面结果交给聚合瀑布流。

边界如下：

- 仅访问 `search.douban.com/{book,movie,music}/subject_search`，不接受模型传入 URL、选择器或 JavaScript。
- 不支持豆瓣社区综合搜索、广播、小组、用户主页和登录后内容。豆瓣综合搜索 API 匿名访问会返回 `need_login`，本 Demo 不绕过它。
- HAP 内部固定依次调用 `browser_navigate`、`browser_evaluate` 和 `browser_close`；这些原始浏览器工具不会注册给 Leader Agent。
- 不在手机上启动 Chromium/Node/npm。浏览器和官方 Playwright MCP 都运行在云服务器。
- 未配置服务地址时来源显示停用状态；云入口返回 401/403 时显示需要鉴权；不会生成模拟豆瓣结果。

## 云端启动

在云服务器安装 Node.js 和 Chrome/Chromium，然后启动官方 Playwright MCP。开发机本地演示可以直接运行：

```powershell
npx -y @playwright/mcp@latest --headless --isolated --browser chrome --host 127.0.0.1 --port 8931 --allowed-hosts 127.0.0.1:8931,localhost:8931 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"
```

MCP 地址为 `http://127.0.0.1:8931/mcp`。正式对手机提供时，不要把该端口直接暴露到公网；应当使用 HTTPS 反向代理或 API Gateway，并至少配置：

`--allowed-hosts` 需要填写请求实际携带的 `Host`（包含端口）。例如 HDC `rport` 后手机请求 `127.0.0.1:8931`，就必须允许 `127.0.0.1:8931`；只写 `127.0.0.1` 会被官方 MCP 以 HTTP 403 拒绝。显式桌面 UA 也必须保留：本地实测不传该 UA 时豆瓣静态脚本可能被浏览器 ORB 拦截，页面会一直停在“正在搜索”。

- Bearer 鉴权；
- 请求频率、并发数和超时限制；
- 请求体大小限制；
- 仅允许 MCP 路径；
- 服务端网络出口和运行用户隔离。

Playwright MCP 本身不是安全边界。当前 HAP 虽然只会执行固定豆瓣流程，但拥有云端 MCP URL 和令牌的其他客户端仍可能尝试调用完整浏览器工具，所以云入口必须限制可信调用方。

## PocketAgent 配置

在本机 ignored provider 配置中增加：

```json
{
  "DOUBAN_PLAYWRIGHT_MCP_URL": "https://playwright.example.com/mcp",
  "DOUBAN_PLAYWRIGHT_MCP_TOKEN": "replace-with-cloud-ingress-token"
}
```

`DOUBAN_PLAYWRIGHT_MCP_TOKEN` 是云入口令牌，不是豆瓣账号 Cookie 或登录 token。若内网 Demo 没有鉴权层，可留空；公网部署不应留空。

客户端实现位于 `agent_core/src/main/ets/aiphone/runtime/DoubanPlaywrightMcpClient.ets`。一次搜索会初始化一个 MCP session，在同一 session 中完成多个书影音页面的导航和提取，最后关闭浏览器上下文。结果字段包括标题、豆瓣 subject URL、封面、评分、评价数和公开元数据。

## 本地到真机演示

如果暂时不部署云入口，可让官方 MCP 仍监听电脑回环地址，再使用 HDC 反向端口映射：

```powershell
hdc rport tcp:8931 tcp:8931
```

手机配置使用 `http://127.0.0.1:8931/mcp`。这只用于有线调试，最终向 mentor 演示云服务器方案时应换成 HTTPS 地址。
