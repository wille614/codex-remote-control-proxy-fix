# LLM Operational Runbook / LLM 操作手册

This file is written for ChatGPT, Codex, Claude, Claude Code, and other LLM agents. It is safe to paste into an LLM session when a user reports local agent network failures under Clash, VPN, VCN, v2rayN, Shadowrocket, or corporate proxy environments.

本文件面向 ChatGPT、Codex、Claude、Claude Code 及其他 LLM Agent。用户在 Clash、VPN、VCN、v2rayN、Shadowrocket 或企业代理环境下遇到本地 Agent 网络失败时，可以直接把本文件交给 LLM 阅读并执行。

## Mission / 目标

English:

Diagnose and fix local proxy environment issues without exposing user privacy and without confusing local mobile remote-control with SSH remote development.

中文：

在不暴露用户隐私、不混淆手机本机控制链路与 SSH 远程开发链路的前提下，诊断并修复本地代理环境问题。

## Hard Safety Rules / 强制安全规则

English:

1. Do not modify Clash, VPN, VCN, system proxy, registry, firewall, or SSH config unless the user explicitly asks.
2. Do not delete SSH hosts, keys, or remote project settings for a mobile remote-control issue.
3. Do not ask the user for private keys, API keys, cookies, raw logs, or full screenshots.
4. Do not publish real usernames, proxy ports, IP addresses, SSH aliases, environment IDs, or installation IDs.
5. Preserve unrelated `.env` entries.
6. Restart the target process after env changes.

中文：

1. 除非用户明确要求，不要修改 Clash、VPN、VCN、系统代理、注册表、防火墙或 SSH 配置。
2. 手机 remote-control 问题不要删除 SSH host、密钥或远程项目设置。
3. 不要向用户索要私钥、API key、cookie、原始日志或完整截图。
4. 不要发布真实用户名、代理端口、IP、SSH alias、environment ID 或 installation ID。
5. 保留 `.env` 中无关配置。
6. 修改 env 后必须重启目标进程。

## First Classification / 第一步分类

Ask or infer:

询问或推断：

```text
OS: Windows / macOS / Linux / WSL / Docker / SSH remote
Tool: Codex / Claude Code / OpenClaw / other
Proxy: Clash / Mihomo / v2rayN / Shadowrocket / VPN / VCN / corporate proxy / unknown
Failure: mobile offline / CLI timeout / WebSocket timeout / provider API unreachable / web-search failure / SSH failure
```

If the failure is clearly SSH-only, stop this runbook and use an SSH workflow.

如果问题明显只属于 SSH，停止本手册，改用 SSH 排障流程。

## Connection Type Heuristic / 连接类型判断

Use log identifiers carefully:

谨慎使用日志标识：

```text
remote-control:env_e_<redacted>
```

Means local mobile remote-control path. For Codex iOS offline, this is relevant.

表示本机 mobile remote-control 链路。对 Codex iOS 离线问题相关。

```text
remote-ssh-discovered:<SSH_ALIAS>
```

Means SSH remote-development path. Do not edit it for mobile offline unless user asks.

表示 SSH 远程开发链路。手机离线问题中不要修改它，除非用户明确要求。

## Proxy Endpoint Discovery / 代理端点发现

### Windows system proxy / Windows 系统代理

Run:

```powershell
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Get-ItemProperty -Path $key | Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
```

Rules:

规则：

- If `ProxyEnable` is `1` and `ProxyServer` contains an endpoint, parse it.
- If PAC mode is used, inspect the proxy client UI instead of guessing.
- If the user uses TUN mode, still verify whether CLI/subprocesses need explicit env.
- Never hard-code examples from another machine.

### Proxy process check / 代理进程检查

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'clash|verge|mihomo|sing-box|v2ray|vpn|proxy' } |
  Select-Object ProcessName,Id,Path | Format-List
```

### Listener check / 监听端口检查

```powershell
$port = <HTTP_OR_MIXED_PROXY_PORT>
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess,
    @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Format-Table -AutoSize
```

Do not paste real output into public docs.

不要把真实输出贴到公开文档中。

## Tool-Specific Actions / 分工具操作

### Codex

Use when:

适用：

- ChatGPT iOS shows local Codex host but it is offline.
- Codex reports WebSocket timeout, reachability failure, or reconnect loops.

Target file:

```text
%USERPROFILE%\.codex\.env
```

Required keys:

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
```

Use script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1
```

Or explicit:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1 `
  -ProxyUrl "http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

Verify:

```powershell
codex doctor --summary --ascii --no-color
```

Expected:

```text
websocket    connected
reachability active provider endpoints are reachable
```

Restart:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-Codex-App-With-Env.ps1
```

Then re-run Codex mobile setup and rebind iOS.

然后重新运行 Codex mobile setup，并重新绑定 iPhone。

### Claude Code

Use when:

适用：

- Claude Code CLI cannot reach Anthropic/provider endpoints.
- Requests time out behind proxy.
- Shell works differently from the editor or desktop process.

Official docs state that Claude Code respects standard HTTP proxy variables and does not support SOCKS proxies. Use HTTP/HTTPS proxy endpoints.

官方文档说明 Claude Code 支持标准 HTTP 代理变量，不支持 SOCKS 代理。应使用 HTTP/HTTPS 代理端点。

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

If the user wants persistent config, check Claude Code settings and use the `env` field according to official docs.

如果用户需要持久配置，应检查 Claude Code settings，并按官方文档使用 `env` 字段。

Do not write Claude Code proxy settings into Codex's `.codex\.env`.

不要把 Claude Code 代理配置写进 Codex 的 `.codex\.env` 并以为它会生效。

### OpenClaw

Use when:

适用：

- OpenClaw gateway, provider calls, web search, or plugins fail under proxy.
- OpenClaw is routed through LiteLLM or another local provider gateway.

Rules:

规则：

1. Identify the process account running OpenClaw.
2. Configure env for that process.
3. If LiteLLM is used, also verify LiteLLM's upstream network.
4. Check current OpenClaw docs before editing config files.

Process env example:

进程环境示例：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
$env:HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
$env:ALL_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
openclaw
```

If OpenClaw uses LiteLLM:

如果 OpenClaw 使用 LiteLLM：

```text
OpenClaw -> LiteLLM Proxy -> Provider
```

Verify both:

同时验证：

1. OpenClaw can reach LiteLLM.
2. LiteLLM can reach the upstream provider.

### Generic local LLM CLI / 通用本地 LLM CLI

Use this fallback:

通用流程：

1. Discover the proxy endpoint.
2. Confirm whether the tool supports HTTP, HTTPS, SOCKS, or custom CA.
3. Set env in the process that launches the tool.
4. Restart the tool.
5. Run a minimal provider/network diagnostic.

Generic shell env:

```bash
export HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
export HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
export ALL_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

## Network Client Matrix / 网络客户端矩阵

| Client | Use this endpoint | Notes |
| --- | --- | --- |
| Clash / Clash Verge / Mihomo | HTTP or mixed port | TUN/browser success may not propagate to subprocesses |
| v2rayN | HTTP port preferred | Avoid SOCKS unless tool supports SOCKS |
| Shadowrocket | LAN HTTP proxy only if Windows can reach it | iPhone `127.0.0.1` is not Windows `127.0.0.1` |
| Corporate proxy | IT-provided HTTP/HTTPS proxy | Custom CA and auth may be required |
| VPN/VCN | Depends on route and process | Still set env if CLI/WebSocket times out |
| WSL/Docker | Env inside WSL/container | `127.0.0.1` changes meaning by namespace |

| 客户端 | 使用端点 | 注意 |
| --- | --- | --- |
| Clash / Clash Verge / Mihomo | HTTP 或 mixed 端口 | TUN/浏览器成功不代表子进程成功 |
| v2rayN | 优先 HTTP 端口 | 除非工具支持 SOCKS，否则避免 SOCKS |
| Shadowrocket | Windows 可访问的局域网 HTTP 代理 | iPhone 的 `127.0.0.1` 不是 Windows 的 `127.0.0.1` |
| 企业代理 | IT 提供的 HTTP/HTTPS 代理 | 可能需要 CA 和认证 |
| VPN/VCN | 取决于路由和进程 | CLI/WebSocket 超时时仍建议设置 env |
| WSL/Docker | 在 WSL/容器内部设置 env | `127.0.0.1` 随命名空间变化 |

## Restart Rule / 重启规则

Any time the proxy service restarts or changes profile:

每当代理服务重启或切换配置：

1. Re-detect endpoint / 重新检测端点。
2. Update env / 更新 env。
3. Restart target process / 重启目标进程。
4. Run diagnostics / 运行诊断。
5. Retry feature / 再尝试功能。

## Source References / 官方参考

- Codex Remote Connections: <https://developers.openai.com/codex/remote-connections>
- Claude Code network configuration: <https://code.claude.com/docs/en/network-config>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- OpenClaw environment variables: <https://docs.openclaw.ai/help/environment>
- OpenClaw LiteLLM provider: <https://docs.openclaw.ai/providers/litellm>
