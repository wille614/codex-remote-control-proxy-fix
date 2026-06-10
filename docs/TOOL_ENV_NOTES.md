# Tool Configuration Notes / 工具配置矩阵

This page maps the same proxy principle to Codex, Claude Code, OpenClaw, and generic LLM CLI tools.

本文把同一套代理原则映射到 Codex、Claude Code、OpenClaw 和通用 LLM CLI 工具。

## Shared Rule / 共同原则

English:

Configure the environment of the process that actually performs network requests. Restart that process after changes.

中文：

配置实际发起网络请求的进程环境变量。修改后必须重启该进程。

Common variables / 常见变量：

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
NO_PROXY="localhost,127.0.0.1,::1"
```

Do not add `NO_PROXY` blindly. Use it only when local/internal calls break because they are being proxied.

不要盲目添加 `NO_PROXY`。只有当本地或内网调用因为被代理而失败时再加。

## Codex

Official reference / 官方参考：

- <https://developers.openai.com/codex/remote-connections>

### Env surface / 环境变量位置

For Codex on Windows, this runbook uses:

```text
%USERPROFILE%\.codex\.env
```

Recommended:

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
```

### Diagnostics / 诊断

```powershell
codex doctor --summary --ascii --no-color
```

Fallback path:

```powershell
& "$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe" doctor --summary --ascii --no-color
```

Expected:

```text
websocket    connected
reachability active provider endpoints are reachable
```

### Mobile remote-control / 手机 remote-control

Codex mobile setup starts from Codex App. The iOS app connects to the Codex App host, not directly to an SSH remote host.

Codex mobile setup 从 Codex App 发起。iPhone 连接的是 Codex App host，不是直接连接 SSH 远程主机。

### Windows remote-control command note / Windows 命令说明

On native Windows, `codex remote-control start --json` may return a Unix daemon lifecycle error. Do not use that message alone as proof that proxy configuration failed.

原生 Windows 上，`codex remote-control start --json` 可能返回 Unix daemon lifecycle 相关错误。不要仅凭这条错误判断代理失败。

## Claude Code

Official references / 官方参考：

- <https://code.claude.com/docs/en/network-config>
- <https://code.claude.com/docs/en/settings>

### Important details / 关键点

English:

- Claude Code documents standard `HTTPS_PROXY`, `HTTP_PROXY`, and `NO_PROXY` environment variables.
- The official network configuration states that Claude Code does not support SOCKS proxies.
- If your client exposes only SOCKS, enable an HTTP proxy port or use an HTTP-compatible adapter.
- Environment variables can be set in the shell or in Claude Code settings under `env`, according to the official settings docs.

中文：

- Claude Code 官方文档说明支持标准 `HTTPS_PROXY`、`HTTP_PROXY` 和 `NO_PROXY` 环境变量。
- 官方网络配置说明 Claude Code 不支持 SOCKS 代理。
- 如果代理客户端只暴露 SOCKS，需要启用 HTTP 代理端口，或使用 HTTP 兼容转换。
- 根据官方 settings 文档，环境变量可在 shell 中设置，也可在 Claude Code settings 的 `env` 字段中配置。

### Shell example / Shell 示例

PowerShell:

```powershell
$env:HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
$env:HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
claude
```

Bash:

```bash
export HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
export HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
claude
```

Add `NO_PROXY` only when needed:

```bash
export NO_PROXY="localhost,127.0.0.1,::1"
```

### LLM instruction / 给 LLM 的指令

If helping a user configure Claude Code, do not write to `%USERPROFILE%\.codex\.env`. Ask or inspect where Claude Code is configured, then use shell env or Claude Code settings.

如果是在配置 Claude Code，不要写入 `%USERPROFILE%\.codex\.env`。应询问或检查 Claude Code 的配置位置，然后使用 shell 环境变量或 Claude Code settings。

## OpenClaw

Official references / 官方参考：

- <https://docs.openclaw.ai/help/environment>
- <https://docs.openclaw.ai/providers/litellm>

### Important details / 关键点

English:

- OpenClaw has its own environment-loading rules. Check the current official docs before editing.
- If OpenClaw runs as a gateway, configure the environment for the gateway process account.
- If OpenClaw routes through LiteLLM, decide whether the proxy belongs at the OpenClaw process, the LiteLLM process, or both.
- Do not assume a Codex env file affects OpenClaw.

中文：

- OpenClaw 有自己的环境变量加载规则。编辑前应查看当前官方文档。
- 如果 OpenClaw 作为 gateway 运行，需要配置 gateway 进程账号的环境。
- 如果 OpenClaw 通过 LiteLLM 路由，需要判断代理应配置在 OpenClaw 进程、LiteLLM 进程，还是两者都需要。
- 不要假设 Codex 的 env 文件会影响 OpenClaw。

### Process env example / 进程环境示例

Bash:

```bash
export HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
export HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
export ALL_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
openclaw
```

PowerShell:

```powershell
$env:HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
$env:HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
$env:ALL_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
openclaw
```

### LiteLLM routing / LiteLLM 路由

If OpenClaw uses LiteLLM:

如果 OpenClaw 使用 LiteLLM：

```text
OpenClaw -> LiteLLM Proxy -> LLM provider
```

Then check both:

需要同时检查：

1. Can OpenClaw reach LiteLLM?
2. Can LiteLLM reach the upstream LLM provider?

Do not put provider API keys or LiteLLM keys into public docs.

不要把 provider API key 或 LiteLLM key 写进公开文档。

## Generic LLM CLI Tools / 通用 LLM CLI 工具

Use this process for tools such as local wrappers, provider CLIs, MCP servers, browser automation helpers, and web-search tools:

适用于本地 wrapper、provider CLI、MCP server、浏览器自动化辅助进程、web-search 工具等：

1. Identify the process making the external request.
2. Identify whether it supports HTTP proxy, HTTPS proxy, SOCKS, or custom CA.
3. Set environment variables for that process.
4. Restart the process.
5. Test with the tool's own network diagnostic or a minimal provider request.

中文简表：

1. 找到真正发起外部请求的进程。
2. 确认它支持 HTTP proxy、HTTPS proxy、SOCKS 或自定义 CA。
3. 为该进程设置环境变量。
4. 重启该进程。
5. 用该工具自己的网络诊断或最小 provider 请求测试。

## Common Failure Patterns / 常见失败模式

| Pattern | Likely cause | Action |
| --- | --- | --- |
| Browser works but CLI times out | CLI did not inherit GUI proxy | Set process env and restart CLI |
| WebSocket fails | Proxy env missing or unsupported | Use HTTP/mixed proxy and restart |
| API reachability fails but WebSocket passes | Missing `ALL_PROXY` or child process env | Add `ALL_PROXY`, restart |
| SOCKS URL ignored | Tool does not support SOCKS | Use HTTP/mixed proxy |
| Mobile device still offline after rebind | Host app started before env update or stale pairing | Restart host app, then rebind |
| SSH host timeout | Separate remote-development path | Do not edit mobile proxy settings for this |

| 现象 | 可能原因 | 操作 |
| --- | --- | --- |
| 浏览器可用但 CLI 超时 | CLI 没继承图形代理 | 设置进程 env 并重启 CLI |
| WebSocket 失败 | 代理 env 缺失或不被支持 | 使用 HTTP/mixed 代理并重启 |
| WebSocket 通过但 API reachability 失败 | 缺少 `ALL_PROXY` 或子进程 env | 添加 `ALL_PROXY` 并重启 |
| SOCKS URL 被忽略 | 工具不支持 SOCKS | 改用 HTTP/mixed 代理 |
| 手机重新绑定后仍离线 | host app 早于 env 更新启动，或配对缓存陈旧 | 重启 host app 后重新绑定 |
| SSH host 超时 | 独立远程开发链路 | 不要用手机代理流程修 SSH |

