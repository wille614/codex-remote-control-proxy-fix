# Network Scenarios / 网络场景

This document explains how to map common proxy clients and network setups to agent environment variables without exposing private machine details.

本文说明如何把常见代理客户端和网络环境映射到 Agent 环境变量，同时避免暴露私人机器信息。

## Universal Rule / 通用规则

English:

Agent tools need the proxy endpoint reachable from the process that makes the network request.

中文：

Agent 工具需要的是“发起网络请求的那个进程可以访问到的代理端点”。

Common endpoint shapes / 常见端点形式：

```text
http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>
http://<LAN_PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>
https://<CORPORATE_PROXY_HOST>:<CORPORATE_PROXY_PORT>
socks5://127.0.0.1:<SOCKS_PORT>
```

Prefer HTTP or mixed proxy endpoints for LLM tools unless the tool explicitly supports SOCKS.

除非工具明确支持 SOCKS，否则本地 LLM 工具优先使用 HTTP 或 mixed 代理端点。

## How To Discover The Endpoint On Windows / Windows 上如何发现端点

### Windows system proxy / Windows 系统代理

```powershell
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Get-ItemProperty -Path $key | Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
```

Interpretation / 解释：

- `ProxyEnable : 1` means system proxy is enabled.
- `ProxyServer` may show `host:port`, `http=host:port`, or multiple entries.
- `AutoConfigURL` means PAC mode; inspect the proxy client UI if the actual endpoint is unclear.

### Process discovery / 进程发现

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'clash|verge|mihomo|sing-box|v2ray|vpn|proxy' } |
  Select-Object ProcessName,Id,Path | Format-List
```

### Listener check / 端口监听检查

```powershell
$port = <HTTP_OR_MIXED_PROXY_PORT>
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess,
    @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Format-Table -AutoSize
```

Do not publish the real port or process output in public issues unless redacted.

不要在公开 issue 中发布真实端口或未经脱敏的进程输出。

## Clash / Clash Verge / Mihomo

English:

- Use the HTTP or mixed port shown by Clash / Clash Verge / Mihomo.
- TUN mode or browser success does not guarantee child processes use the proxy.
- If the local agent times out, configure the agent process env explicitly.
- Use `http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>` when the proxy client runs on the same Windows host.

中文：

- 使用 Clash / Clash Verge / Mihomo 显示的 HTTP 或 mixed 端口。
- TUN 模式可用或浏览器能访问，不代表子进程一定走代理。
- 本地 Agent 超时时，应显式配置 Agent 进程环境变量。
- 如果代理客户端运行在同一台 Windows 主机，通常使用 `http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>`。

Recommended env / 推荐环境变量：

```env
HTTP_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

## v2rayN

English:

- v2rayN commonly exposes separate HTTP and SOCKS ports.
- Prefer the HTTP port for tools that do not explicitly support SOCKS.
- If a tool supports only HTTP/HTTPS proxy variables, do not use a SOCKS URL unless the tool documents SOCKS support.
- Re-check the port after profile or service changes.

中文：

- v2rayN 通常会暴露 HTTP 和 SOCKS 两类端口。
- 对于未明确支持 SOCKS 的工具，优先使用 HTTP 端口。
- 如果工具只声明支持 HTTP/HTTPS 代理变量，不要直接填 SOCKS URL，除非该工具文档明确支持 SOCKS。
- 切换配置或服务模式后，需要重新确认端口。

Example / 示例：

```env
HTTP_PROXY="http://127.0.0.1:<V2RAYN_HTTP_PORT>"
HTTPS_PROXY="http://127.0.0.1:<V2RAYN_HTTP_PORT>"
ALL_PROXY="http://127.0.0.1:<V2RAYN_HTTP_PORT>"
```

## Shadowrocket

English:

Shadowrocket is often used on iOS. If the LLM tool runs on Windows, a proxy running only on the iPhone is not automatically available as `127.0.0.1` on Windows.

Use Shadowrocket for a Windows-hosted agent only if one of these is true:

- The Windows machine itself runs a reachable proxy endpoint.
- The iOS device exposes a LAN HTTP proxy and Windows can reach it.
- A VPN/VCN setup routes Windows traffic and the target tool process actually uses that route.

中文：

Shadowrocket 常见于 iOS。如果 LLM 工具运行在 Windows 上，只在 iPhone 上运行的代理并不会自动变成 Windows 的 `127.0.0.1`。

只有在以下情况之一成立时，才把 Shadowrocket 纳入 Windows Agent 排障：

- Windows 机器本身运行了可访问的代理端点。
- iOS 设备暴露了局域网 HTTP 代理，且 Windows 可以访问。
- VPN/VCN 已经路由 Windows 流量，并且目标工具进程确实使用了这条路由。

LAN proxy example / 局域网代理示例：

```env
HTTP_PROXY="http://<LAN_PROXY_HOST>:<HTTP_PROXY_PORT>"
HTTPS_PROXY="http://<LAN_PROXY_HOST>:<HTTP_PROXY_PORT>"
ALL_PROXY="http://<LAN_PROXY_HOST>:<HTTP_PROXY_PORT>"
```

Do not publish `<LAN_PROXY_HOST>` if it reveals a private network.

如果 `<LAN_PROXY_HOST>` 会暴露内网信息，不要公开发布。

## Corporate Proxy / 企业代理

English:

- Use the corporate HTTP/HTTPS proxy endpoint supplied by IT.
- Custom CA certificates may be required.
- Proxy auth may be required.
- Do not publish proxy usernames, domains, or internal hostnames.

中文：

- 使用企业 IT 提供的 HTTP/HTTPS 代理端点。
- 可能需要自定义 CA 证书。
- 可能需要代理认证。
- 不要发布代理用户名、域名或内部 hostname。

Example / 示例：

```env
HTTPS_PROXY="http://<CORPORATE_PROXY_HOST>:<CORPORATE_PROXY_PORT>"
HTTP_PROXY="http://<CORPORATE_PROXY_HOST>:<CORPORATE_PROXY_PORT>"
NO_PROXY="localhost,127.0.0.1,::1,<INTERNAL_DOMAIN>"
```

Only add `NO_PROXY` when needed. Over-broad `NO_PROXY` can bypass the proxy and break provider calls.

仅在需要时添加 `NO_PROXY`。过宽的 `NO_PROXY` 可能绕过代理并导致 provider 请求失败。

## WSL, Docker, And Remote Shells

English:

`127.0.0.1` is relative to the process namespace:

- Windows process: `127.0.0.1` means Windows host.
- WSL process: `127.0.0.1` means the WSL VM, not necessarily Windows.
- Docker container: `127.0.0.1` means the container.
- SSH remote shell: `127.0.0.1` means the remote machine.

中文：

`127.0.0.1` 是相对于进程所在环境的：

- Windows 进程：`127.0.0.1` 是 Windows 主机。
- WSL 进程：`127.0.0.1` 是 WSL VM，不一定是 Windows。
- Docker 容器：`127.0.0.1` 是容器自身。
- SSH 远程 shell：`127.0.0.1` 是远程机器。

Therefore, configure env inside the environment where the tool actually runs.

因此，应在工具实际运行的环境内配置 env。

## SOCKS-Only Proxy

English:

Some tools do not support SOCKS proxies. If the proxy client only exposes SOCKS:

1. Enable an HTTP or mixed port in the proxy client.
2. Use a local HTTP-to-SOCKS adapter if appropriate.
3. Verify with the target tool's official docs.

中文：

部分工具不支持 SOCKS 代理。如果代理客户端只暴露 SOCKS：

1. 在代理客户端中启用 HTTP 或 mixed 端口。
2. 必要时使用本地 HTTP-to-SOCKS 转换器。
3. 以目标工具官方文档为准。

## Restart Checklist / 重启检查清单

After starting or restarting any proxy client:

启动或重启任何代理客户端后：

1. Re-detect endpoint / 重新检测端点。
2. Update target env / 更新目标工具 env。
3. Restart target process / 重启目标进程。
4. Run diagnostics / 运行诊断。
5. Retry feature / 再尝试功能。

