# Fix Codex iOS Offline and LLM Agent Proxy Timeouts

# 修复 Codex iOS 离线与本地 LLM Agent 代理超时

This guide helps fix proxy-related connection failures for Codex and similar local LLM agent tools on Windows.

本文用于修复 Windows 上 Codex 以及类似本地 LLM Agent 工具在代理网络下的连接失败问题。

It focuses on practical symptoms and concrete fixes. If you are using an LLM assistant such as ChatGPT, Codex, Claude, or Claude Code to help troubleshoot, you can paste this repository link or the relevant sections directly into the assistant.

本文重点描述问题现象和可执行解决方案。如果你正在让 ChatGPT、Codex、Claude 或 Claude Code 协助排查，可以直接把这个仓库链接或相关章节交给它阅读。

## Problems This Solves / 可解决的问题

Typical symptoms:

常见现象：

- Codex repeatedly shows `Reconnecting 5/5 request timed out`.
- Codex CLI or Codex App has WebSocket timeout, provider reachability failure, or request timeout.
- The iPhone ChatGPT App can see the local Codex device name, but it always shows `Offline`.
- Tapping `Reconnect` in the iPhone ChatGPT App does not help.
- Rebinding the phone still fails because the desktop Codex App was started before proxy environment variables were configured.
- Browser access works, but Codex, Claude Code, OpenClaw, web search tools, subprocesses, or local agent plugins still cannot reach external provider endpoints.

对应中文描述：

- Codex 多次出现 `Reconnecting 5/5 request timed out`。
- Codex CLI 或 Codex App 出现 WebSocket timeout、provider reachability failure 或 request timeout。
- iPhone 的 ChatGPT App 里能看到本机 Codex 设备名，但一直显示“离线”。
- 在 iPhone ChatGPT App 里点击“重新连接”无效。
- 重新绑定手机仍失败，因为桌面端 Codex App 是在代理环境变量配置之前启动的。
- 浏览器可以访问网络，但 Codex、Claude Code、OpenClaw、web search 工具、子进程或本地 Agent 插件仍无法访问外部 provider endpoint。

## Why This Happens / 为什么会这样

Many proxy clients make browsers work, but local agent tools may not automatically inherit the same proxy route.

很多代理客户端能让浏览器正常联网，但本地 Agent 工具不一定会自动继承同一条代理链路。

Common causes:

常见原因：

- The proxy client is running, but Codex or another CLI process does not have `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`.
- The proxy client changed its local HTTP or mixed port after restart, profile switch, service mode change, VPN reconnect, or reinstall.
- Codex App was already running before the `.env` file was created or updated.
- Only `HTTP_PROXY` and `HTTPS_PROXY` were set, while subprocesses or other network stacks also need `ALL_PROXY`.
- A SOCKS-only endpoint was used for a tool that only supports HTTP/HTTPS proxies.

## Quick Fix For Codex On Windows / Windows 上 Codex 的快速修复

### 1. Find the active proxy endpoint / 找到当前实际代理端点

On Windows, first check the system proxy:

在 Windows 上，先检查系统代理：

```powershell
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Get-ItemProperty -Path $key | Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
```

If this shows a local endpoint, use its HTTP or mixed proxy port.

如果这里显示本地代理端点，使用其中的 HTTP 或 mixed 代理端口。

If the system proxy does not show the real route, open your proxy client UI and check the current HTTP or mixed port directly.

如果系统代理没有显示真实出口，请打开代理客户端 UI，直接查看当前 HTTP 或 mixed 端口。

Useful process check:

可选的进程检查：

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'clash|verge|mihomo|sing-box|v2ray|vpn|proxy' } |
  Select-Object ProcessName,Id,Path | Format-List
```

Listener check after you know the port:

已知端口后的监听检查：

```powershell
$port = <HTTP_OR_MIXED_PROXY_PORT>
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess,
    @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Format-Table -AutoSize
```

### 2. Update Codex user-level `.env` / 更新 Codex 用户级 `.env`

Codex on Windows can read:

Windows 上 Codex 可读取：

```text
%USERPROFILE%\.codex\.env
```

Add or update:

添加或更新：

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
```

For a proxy client running on the same Windows host, `<PROXY_HOST>` is usually `127.0.0.1`.

如果代理客户端运行在同一台 Windows 主机上，`<PROXY_HOST>` 通常是 `127.0.0.1`。

You can use the helper script:

可以使用仓库内脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1
```

Or pass the endpoint explicitly:

或显式传入代理端点：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1 `
  -ProxyUrl "http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

The script preserves unrelated lines in `%USERPROFILE%\.codex\.env` and only updates:

脚本会保留 `%USERPROFILE%\.codex\.env` 中无关配置，只更新：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
```

### 3. Verify Codex network health / 验证 Codex 网络状态

Open a fresh PowerShell and run:

打开新的 PowerShell，运行：

```powershell
codex doctor --summary --ascii --no-color
```

If `codex` is not in `PATH`, try the standalone path:

如果 `codex` 不在 `PATH` 中，可以尝试 standalone 路径：

```powershell
& "$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe" doctor --summary --ascii --no-color
```

Expected result:

预期结果：

```text
websocket    connected
reachability active provider endpoints are reachable
```

If WebSocket passes but reachability fails, check whether `ALL_PROXY` is missing.

如果 WebSocket 通过但 reachability 失败，检查是否缺少 `ALL_PROXY`。

### 4. Fully restart Codex App / 完全重启 Codex App

This is important. Environment changes do not affect an already-running desktop app.

这一步很关键。环境变量变更不会自动进入已经运行的桌面 App。

Check process start time and `.env` update time:

检查 Codex App 启动时间和 `.env` 修改时间：

```powershell
Get-Process -Name Codex -ErrorAction SilentlyContinue |
  Sort-Object StartTime |
  Select-Object Id,ProcessName,
    @{Name='StartTime';Expression={$_.StartTime.ToString('yyyy-MM-dd HH:mm:ss')}},
    Path |
  Format-List

$envPath = Join-Path $env:USERPROFILE ".codex\.env"
Get-Item -LiteralPath $envPath | Select-Object FullName,LastWriteTime
```

If Codex App started before `.env` was updated, fully quit Codex App, including tray and background processes, then start it again.

如果 Codex App 的启动时间早于 `.env` 修改时间，请完全退出 Codex App，包括托盘和后台进程，然后重新启动。

You can launch it through:

可以通过脚本启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-Codex-App-With-Env.ps1
```

The script refuses to launch a duplicate instance if Codex is still running.

如果 Codex 仍在运行，该脚本会拒绝启动第二个实例。

### 5. Rebind iPhone ChatGPT App / 重新绑定 iPhone ChatGPT App

Only do this after `codex doctor` passes and Codex App has restarted with the corrected environment.

请在 `codex doctor` 通过，并且 Codex App 已用正确环境重启后，再执行这一步。

Steps:

步骤：

1. Open Codex App on Windows.
2. Start Codex mobile setup.
3. Scan the new QR code or open the new setup link with the iPhone ChatGPT App.
4. Confirm the same ChatGPT account and workspace.
5. If the phone still lists an old offline device, remove that stale device entry if the UI allows it, then bind again.

中文：

1. 打开 Windows Codex App。
2. 启动 Codex mobile setup。
3. 用 iPhone ChatGPT App 扫描新的二维码或打开新的 setup link。
4. 确认使用同一个 ChatGPT 账号和同一个 workspace。
5. 如果手机端仍显示旧的离线设备记录，能删除的话先删除旧记录，再重新绑定。

## After Restarting Clash, v2rayN, Shadowrocket, VPN, Or VCN

## 重启 Clash、v2rayN、Shadowrocket、VPN 或 VCN 后怎么办

Proxy clients can change local ports or routing behavior after restart, profile switch, service mode change, VPN reconnect, or reinstall.

代理客户端在重启、切换配置、切换服务模式、VPN 重连或重装后，可能改变本地端口或路由行为。

Recommended routine:

推荐流程：

1. Start the proxy/VPN/VCN service first.
2. Re-check the active HTTP or mixed proxy endpoint.
3. Update `%USERPROFILE%\.codex\.env`.
4. Fully restart Codex App or the target LLM tool.
5. Run diagnostics again.
6. Retry iPhone binding, WebSocket features, web search, or provider calls only after diagnostics pass.

中文：

1. 先启动代理、VPN 或 VCN 服务。
2. 重新确认当前 HTTP 或 mixed 代理端点。
3. 更新 `%USERPROFILE%\.codex\.env`。
4. 完全重启 Codex App 或目标 LLM 工具。
5. 重新运行诊断命令。
6. 诊断通过后，再尝试 iPhone 绑定、WebSocket、web search 或 provider 请求。

## Proxy Client Notes / 不同代理客户端说明

### Clash / Clash Verge / Mihomo

Use the HTTP or mixed port shown in the client UI. Browser success or TUN mode does not guarantee that CLI tools and subprocesses inherit the same route.

使用客户端 UI 中显示的 HTTP 或 mixed 端口。浏览器可用或 TUN 模式可用，并不代表 CLI 工具和子进程一定继承同一条链路。

### v2rayN

Prefer the HTTP proxy port. Avoid SOCKS endpoints unless the target tool explicitly supports SOCKS.

优先使用 HTTP 代理端口。除非目标工具明确支持 SOCKS，否则不要优先使用 SOCKS 端点。

### Shadowrocket

Shadowrocket is often on iOS. If Codex or another LLM tool runs on Windows, the iPhone's `127.0.0.1` is not the Windows machine's `127.0.0.1`.

Shadowrocket 常运行在 iOS 上。如果 Codex 或其他 LLM 工具运行在 Windows 上，iPhone 的 `127.0.0.1` 不是 Windows 机器的 `127.0.0.1`。

For Windows-hosted tools, use Shadowrocket only if it exposes a LAN HTTP proxy that Windows can reach, or if your VPN/VCN route actually applies to the Windows process.

对于运行在 Windows 上的工具，只有在 Shadowrocket 暴露了 Windows 可访问的局域网 HTTP 代理，或 VPN/VCN 路由确实作用于 Windows 进程时，才应使用它。

### Corporate proxy / 企业代理

Use the HTTP/HTTPS proxy endpoint provided by IT. A custom CA certificate or proxy authentication may also be required.

使用 IT 提供的 HTTP/HTTPS 代理端点。可能还需要自定义 CA 证书或代理认证。

## Other LLM Agent Tools / 其他 LLM Agent 工具

The same principle applies to Claude Code, OpenClaw, LiteLLM-backed tools, MCP servers, browser automation helpers, and other local LLM CLIs:

同样的原则适用于 Claude Code、OpenClaw、通过 LiteLLM 路由的工具、MCP server、浏览器自动化辅助进程和其他本地 LLM CLI：

1. Identify the process that actually makes the external request.
2. Configure the environment variables that this process reads.
3. Prefer HTTP or mixed proxy endpoints unless the tool documents SOCKS support.
4. Restart the tool after changing env.
5. Verify with the tool's own diagnostic command or a minimal provider request.

中文：

1. 找到真正发起外部请求的进程。
2. 配置该进程实际读取的环境变量。
3. 除非工具文档明确支持 SOCKS，否则优先使用 HTTP 或 mixed 代理端点。
4. 修改 env 后重启工具。
5. 用工具自己的诊断命令或最小 provider 请求验证。

More details:

更多细节：

- [LLM operational runbook / LLM 操作手册](docs/LLM_RUNBOOK.md)
- [Network scenarios / 网络场景](docs/NETWORK_SCENARIOS.md)
- [Tool configuration notes / 工具配置矩阵](docs/TOOL_ENV_NOTES.md)

## Extra Reminder: Do Not Mix This With SSH Remote Hosts

## 额外提醒：不要和 SSH 远程主机混淆

iPhone ChatGPT App remote-control and SSH remote development are different paths.

iPhone ChatGPT App remote-control 和 SSH 远程开发是不同链路。

```text
iPhone ChatGPT App -> local Codex App host
Codex App -> optional SSH remote development host
```

If logs mention `remote-control:env_e_<redacted>`, that is the mobile/local Codex remote-control path.

如果日志中出现 `remote-control:env_e_<redacted>`，这通常是手机/本机 Codex remote-control 链路。

If logs mention `remote-ssh-discovered:<SSH_ALIAS>`, SSH timeout, or remote `codex` not found, that belongs to the SSH remote-development path.

如果日志中出现 `remote-ssh-discovered:<SSH_ALIAS>`、SSH timeout 或远程 `codex` not found，这属于 SSH 远程开发链路。

Do not delete or modify SSH hosts when the problem is simply iPhone showing the local Codex device as offline.

如果问题只是 iPhone 上本机 Codex 设备显示离线，不要因此删除或修改 SSH host。

## References / 参考资料

- OpenAI Codex Remote Connections: <https://developers.openai.com/codex/remote-connections>
- Claude Code network configuration: <https://code.claude.com/docs/en/network-config>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- OpenClaw environment variables: <https://docs.openclaw.ai/help/environment>
- OpenClaw LiteLLM provider: <https://docs.openclaw.ai/providers/litellm>

