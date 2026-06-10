# 修复 Codex iOS 离线与本地 LLM Agent 代理超时

> English documentation: [README.md](README.md)

本文用于修复 Windows 上 Codex 以及类似本地 LLM Agent 工具在代理网络下的连接失败问题。

如果你遇到 Codex 反复重连、iPhone ChatGPT App 显示本机 Codex 设备离线，或者浏览器能联网但本地 Agent 工具仍然超时，可以按本文排查。

## 可解决的问题

如果你遇到以下一个或多个现象，本文可能适用：

- Codex 多次出现 `Reconnecting 5/5 request timed out`。
- `codex doctor` 显示 WebSocket timeout 或 provider reachability failure。
- iPhone 的 ChatGPT App 里能看到本机 Codex 设备名，但一直显示 `Offline`。
- 在 iPhone ChatGPT App 里点击 `Reconnect` 无效。
- 重新绑定手机仍失败。
- 浏览器可以访问网络，但 Codex、Claude Code、OpenClaw、web search 工具、MCP server 或本地 Agent 子进程仍然超时。

## 为什么会这样

很多图形代理客户端能让浏览器正常联网，但本地 Agent 工具不一定会自动继承同一条代理链路。

常见原因：

- Codex 或其他 CLI 进程没有 `HTTP_PROXY`、`HTTPS_PROXY` 或 `ALL_PROXY`。
- 代理客户端在重启、切换配置、VPN 重连或重装后改变了本地 HTTP 或 mixed 端口。
- Codex App 在 `.env` 文件创建或更新之前就已经启动。
- 只配置了 `HTTP_PROXY` 和 `HTTPS_PROXY`，但子进程或 WebSocket 相关组件还需要 `ALL_PROXY`。
- 给只支持 HTTP/HTTPS 代理的工具配置了 SOCKS 端点。

## Windows 上 Codex 的快速修复

### 1. 找到当前实际代理端点

先检查 Windows 系统代理：

```powershell
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Get-ItemProperty -Path $key | Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
```

如果这里显示了本地 HTTP 或 mixed 代理端点，就使用这个 host 和 port。

如果系统代理没有显示真实出口，请打开代理客户端 UI，直接查看当前 HTTP 或 mixed 端口。

可选的进程检查：

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'clash|verge|mihomo|sing-box|v2ray|vpn|proxy' } |
  Select-Object ProcessName,Id,Path | Format-List
```

已知端口后的监听检查：

```powershell
$port = <HTTP_OR_MIXED_PROXY_PORT>
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess,
    @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Format-Table -AutoSize
```

### 2. 更新 Codex 用户级 `.env`

Windows 上 Codex 可读取：

```text
%USERPROFILE%\.codex\.env
```

添加或更新：

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
```

如果代理客户端运行在同一台 Windows 主机上，`<PROXY_HOST>` 通常是 `127.0.0.1`。

可以使用仓库内脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1
```

也可以显式传入代理端点：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1 `
  -ProxyUrl "http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

脚本会保留 `%USERPROFILE%\.codex\.env` 中的无关配置，只更新：

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
```

### 3. 验证 Codex 网络状态

打开新的 PowerShell，运行：

```powershell
codex doctor --summary --ascii --no-color
```

如果 `codex` 不在 `PATH` 中，可以尝试 standalone 路径：

```powershell
& "$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe" doctor --summary --ascii --no-color
```

预期结果：

```text
websocket    connected
reachability active provider endpoints are reachable
```

如果 WebSocket 通过但 reachability 失败，检查是否缺少 `ALL_PROXY`。

### 4. 完全重启 Codex App

这一步很关键。环境变量变更不会自动进入已经运行的桌面 App。

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

如果 Codex App 的启动时间早于 `.env` 修改时间，请完全退出 Codex App，包括托盘和后台进程，然后重新启动。

可以通过脚本启动：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-Codex-App-With-Env.ps1
```

如果 Codex 仍在运行，该脚本会拒绝启动第二个实例。

### 5. 重新绑定 iPhone ChatGPT App

请在 `codex doctor` 通过，并且 Codex App 已经用正确环境重启后，再执行这一步。

1. 打开 Windows Codex App。
2. 启动 Codex mobile setup。
3. 用 iPhone ChatGPT App 扫描新的二维码或打开新的 setup link。
4. 确认使用同一个 ChatGPT 账号和同一个 workspace。
5. 如果手机端仍显示旧的离线设备记录，能删除的话先删除旧记录，再重新绑定。

## 重启代理、VPN 或 VCN 服务后怎么办

代理客户端在重启、切换配置、切换服务模式、VPN 重连或重装后，可能改变本地端口或路由行为。

推荐流程：

1. 先启动代理、VPN 或 VCN 服务。
2. 重新确认当前 HTTP 或 mixed 代理端点。
3. 更新 `%USERPROFILE%\.codex\.env`。
4. 完全重启 Codex App 或目标本地 LLM 工具。
5. 重新运行诊断命令。
6. 诊断通过后，再尝试 iPhone 绑定、WebSocket、web search 或 provider 请求。

## 不同代理客户端说明

### Clash / Clash Verge / Mihomo

使用客户端 UI 中显示的 HTTP 或 mixed 端口。浏览器可用或 TUN 模式可用，并不代表 CLI 工具和子进程一定继承同一条链路。

### v2rayN

优先使用 HTTP 代理端口。除非目标工具明确支持 SOCKS，否则不要优先使用 SOCKS 端点。

### Shadowrocket

Shadowrocket 常运行在 iOS 上。如果 Codex 或其他 LLM 工具运行在 Windows 上，iPhone 的 `127.0.0.1` 不是 Windows 机器的 `127.0.0.1`。

对于运行在 Windows 上的工具，只有在 Shadowrocket 暴露了 Windows 可访问的局域网 HTTP 代理，或 VPN/VCN 路由确实作用于 Windows 进程时，才应使用它。

### 企业代理

使用 IT 提供的 HTTP/HTTPS 代理端点。可能还需要自定义 CA 证书或代理认证。

## 其他本地 LLM Agent 工具

同样的原则适用于 Claude Code、OpenClaw、通过 LiteLLM 路由的工具、MCP server、浏览器自动化辅助进程和其他本地 LLM CLI：

1. 找到真正发起外部请求的进程。
2. 配置该进程实际读取的环境变量。
3. 除非工具文档明确支持 SOCKS，否则优先使用 HTTP 或 mixed 代理端点。
4. 修改 env 后重启工具。
5. 用工具自己的诊断命令或最小 provider 请求验证。

注意：不要假设非 Codex 工具会读取 `%USERPROFILE%\.codex\.env`。应配置具体工具实际使用的环境变量入口。

## 额外提醒：不要和 SSH 远程主机混淆

iPhone ChatGPT App remote-control 和 SSH 远程开发是不同链路：

```text
iPhone ChatGPT App -> local Codex App host
Codex App -> optional SSH remote development host
```

如果日志中出现 `remote-control:env_e_<redacted>`，这通常是手机/本机 Codex remote-control 链路。

如果日志中出现 `remote-ssh-discovered:<SSH_ALIAS>`、SSH timeout 或远程 `codex` not found，这属于 SSH 远程开发链路。

如果问题只是 iPhone 上本机 Codex 设备显示离线，不要因此删除或修改 SSH host。

## 更多细节

- [LLM 操作手册](docs/LLM_RUNBOOK.md)
- [网络场景](docs/NETWORK_SCENARIOS.md)
- [工具配置说明](docs/TOOL_ENV_NOTES.md)

## 参考资料

- OpenAI Codex Remote Connections: <https://developers.openai.com/codex/remote-connections>
- Claude Code network configuration: <https://code.claude.com/docs/en/network-config>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- OpenClaw environment variables: <https://docs.openclaw.ai/help/environment>
- OpenClaw LiteLLM provider: <https://docs.openclaw.ai/providers/litellm>

