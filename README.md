# Fix Codex iOS Offline and Local LLM Agent Proxy Timeouts

> 中文文档: [README_zh.md](README_zh.md)

This guide explains how to fix proxy-related connection failures for Codex and similar local LLM agent tools on Windows.

It is written for users who see symptoms such as Codex reconnect loops, iPhone ChatGPT showing a local Codex device as offline, or local agent tools failing even though the browser can access the internet.

## Symptoms

This guide is relevant if you see one or more of these problems:

- Codex repeatedly shows `Reconnecting 5/5 request timed out`.
- `codex doctor` reports WebSocket timeout or provider reachability failure.
- The iPhone ChatGPT app can see your local Codex device name, but the device stays `Offline`.
- Tapping `Reconnect` in the iPhone ChatGPT app does not fix it.
- Rebinding the phone still fails.
- Browser access works, but Codex, Claude Code, OpenClaw, web-search tools, MCP servers, or local agent subprocesses still time out.

## Why This Happens

GUI proxy clients often make browsers work, but local agent tools may not automatically inherit the same proxy route.

Common causes:

- Codex or another CLI process does not have `HTTP_PROXY`, `HTTPS_PROXY`, or `ALL_PROXY`.
- The proxy client changed its local HTTP or mixed port after restart, profile switch, VPN reconnect, or reinstall.
- Codex App was already running before the `.env` file was created or updated.
- Only `HTTP_PROXY` and `HTTPS_PROXY` were set, but subprocesses or WebSocket-related components also need `ALL_PROXY`.
- A SOCKS endpoint was used for a tool that only supports HTTP/HTTPS proxies.

## Quick Fix For Codex On Windows

### 1. Find The Active Proxy Endpoint

Check the Windows system proxy:

```powershell
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Get-ItemProperty -Path $key | Select-Object ProxyEnable,ProxyServer,AutoConfigURL | Format-List
```

If this shows a local HTTP or mixed proxy endpoint, use that host and port.

If the system proxy does not show the real route, open your proxy client UI and check the current HTTP or mixed port directly.

Optional process check:

```powershell
Get-Process | Where-Object { $_.ProcessName -match 'clash|verge|mihomo|sing-box|v2ray|vpn|proxy' } |
  Select-Object ProcessName,Id,Path | Format-List
```

Optional listener check after you know the port:

```powershell
$port = <HTTP_OR_MIXED_PROXY_PORT>
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -eq $port } |
  Select-Object LocalAddress,LocalPort,OwningProcess,
    @{Name='ProcessName';Expression={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Format-Table -AutoSize
```

### 2. Update The Codex User `.env`

Codex on Windows can read:

```text
%USERPROFILE%\.codex\.env
```

Add or update:

```env
HTTP_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
HTTPS_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
ALL_PROXY="http://<PROXY_HOST>:<HTTP_OR_MIXED_PROXY_PORT>"
```

For a proxy client running on the same Windows host, `<PROXY_HOST>` is usually `127.0.0.1`.

You can use the helper script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1
```

Or pass the endpoint explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Set-CodexProxyEnv.ps1 `
  -ProxyUrl "http://127.0.0.1:<HTTP_OR_MIXED_PROXY_PORT>"
```

The script preserves unrelated lines in `%USERPROFILE%\.codex\.env` and only updates:

```text
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
```

### 3. Verify Codex Connectivity

Open a fresh PowerShell and run:

```powershell
codex doctor --summary --ascii --no-color
```

If `codex` is not in `PATH`, try the standalone path:

```powershell
& "$env:LOCALAPPDATA\Programs\OpenAI\Codex\bin\codex.exe" doctor --summary --ascii --no-color
```

Expected result:

```text
websocket    connected
reachability active provider endpoints are reachable
```

If WebSocket passes but reachability fails, check whether `ALL_PROXY` is missing.

### 4. Fully Restart Codex App

Environment changes do not affect an already-running desktop app.

Check the Codex App process start time and the `.env` update time:

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

You can launch it through:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-Codex-App-With-Env.ps1
```

The script refuses to launch a duplicate instance if Codex is still running.

### 5. Rebind The iPhone ChatGPT App

Only do this after `codex doctor` passes and Codex App has restarted with the corrected environment.

1. Open Codex App on Windows.
2. Start Codex mobile setup.
3. Scan the new QR code or open the new setup link with the iPhone ChatGPT app.
4. Confirm the same ChatGPT account and workspace.
5. If the phone still lists an old offline device, remove that stale device entry if the UI allows it, then bind again.

## After Restarting Proxy, VPN, Or VCN Services

Proxy clients can change local ports or routing behavior after restart, profile switch, service mode change, VPN reconnect, or reinstall.

Recommended routine:

1. Start the proxy, VPN, or VCN service first.
2. Re-check the active HTTP or mixed proxy endpoint.
3. Update `%USERPROFILE%\.codex\.env`.
4. Fully restart Codex App or the target local LLM tool.
5. Run diagnostics again.
6. Retry iPhone binding, WebSocket features, web search, or provider calls only after diagnostics pass.

## Proxy Client Notes

### Clash / Clash Verge / Mihomo

Use the HTTP or mixed port shown in the client UI. Browser success or TUN mode does not guarantee that CLI tools and subprocesses inherit the same route.

### v2rayN

Prefer the HTTP proxy port. Avoid SOCKS endpoints unless the target tool explicitly supports SOCKS.

### Shadowrocket

Shadowrocket is often used on iOS. If Codex or another LLM tool runs on Windows, the iPhone's `127.0.0.1` is not the Windows machine's `127.0.0.1`.

For Windows-hosted tools, use Shadowrocket only if it exposes a LAN HTTP proxy that Windows can reach, or if your VPN/VCN route actually applies to the Windows process.

### Corporate Proxy

Use the HTTP/HTTPS proxy endpoint provided by IT. A custom CA certificate or proxy authentication may also be required.

## Other Local LLM Agent Tools

The same principle applies to Claude Code, OpenClaw, LiteLLM-backed tools, MCP servers, browser automation helpers, and other local LLM CLIs:

1. Identify the process that actually makes the external request.
2. Configure the environment variables that this process reads.
3. Prefer HTTP or mixed proxy endpoints unless the tool documents SOCKS support.
4. Restart the tool after changing env.
5. Verify with the tool's own diagnostic command or a minimal provider request.

Important: do not assume non-Codex tools read `%USERPROFILE%\.codex\.env`. Configure the environment surface used by the specific tool.

## Extra Reminder: Do Not Mix This With SSH Remote Hosts

iPhone ChatGPT App remote-control and SSH remote development are different paths:

```text
iPhone ChatGPT App -> local Codex App host
Codex App -> optional SSH remote development host
```

If logs mention `remote-control:env_e_<redacted>`, that is the mobile/local Codex remote-control path.

If logs mention `remote-ssh-discovered:<SSH_ALIAS>`, SSH timeout, or remote `codex` not found, that belongs to the SSH remote-development path.

Do not delete or modify SSH hosts when the problem is simply iPhone showing the local Codex device as offline.

## More Details

- [LLM operational runbook](docs/LLM_RUNBOOK.md)
- [Network scenarios](docs/NETWORK_SCENARIOS.md)
- [Tool configuration notes](docs/TOOL_ENV_NOTES.md)

## References

- OpenAI Codex Remote Connections: <https://developers.openai.com/codex/remote-connections>
- Claude Code network configuration: <https://code.claude.com/docs/en/network-config>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- OpenClaw environment variables: <https://docs.openclaw.ai/help/environment>
- OpenClaw LiteLLM provider: <https://docs.openclaw.ai/providers/litellm>

