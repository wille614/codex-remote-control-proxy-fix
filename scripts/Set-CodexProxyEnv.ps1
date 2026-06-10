[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [string]$HostName = "127.0.0.1",
    [int]$Port,
    [ValidateSet("http", "socks5")]
    [string]$Scheme = "http",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-WindowsProxyCandidate {
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $settings = Get-ItemProperty -Path $key

    if ($settings.ProxyEnable -ne 1) {
        throw "Windows system proxy is not enabled. Pass -ProxyUrl or -Port explicitly."
    }

    $proxyServer = [string]$settings.ProxyServer
    if ([string]::IsNullOrWhiteSpace($proxyServer)) {
        throw "Windows ProxyServer is empty. Pass -ProxyUrl or -Port explicitly."
    }

    $entries = $proxyServer -split ";"
    foreach ($entry in $entries) {
        $candidate = $entry.Trim()
        if ($candidate -match "^(http|https)=(.+)$") {
            return $Matches[2].Trim()
        }
    }

    foreach ($entry in $entries) {
        $candidate = $entry.Trim()
        if ($candidate -match "^(socks|socks5)=(.+)$") {
            return $Matches[2].Trim()
        }
    }

    return $proxyServer.Trim()
}

function ConvertTo-ProxyUrl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Candidate,
        [Parameter(Mandatory=$true)]
        [string]$DefaultScheme
    )

    $value = $Candidate.Trim()
    if ($value -match "^[a-zA-Z][a-zA-Z0-9+.-]*://") {
        return $value
    }

    if ($value -match "^(?<host>\[[^\]]+\]|[^:]+):(?<port>\d+)$") {
        return ("{0}://{1}:{2}" -f $DefaultScheme, $Matches["host"], $Matches["port"])
    }

    throw "Could not parse proxy endpoint: $Candidate"
}

if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
    if ($Port -gt 0) {
        $ProxyUrl = ("{0}://{1}:{2}" -f $Scheme, $HostName, $Port)
    } else {
        $ProxyUrl = ConvertTo-ProxyUrl -Candidate (Get-WindowsProxyCandidate) -DefaultScheme $Scheme
    }
}

$keysToUpdate = [ordered]@{
    "HTTP_PROXY" = $ProxyUrl
    "HTTPS_PROXY" = $ProxyUrl
    "ALL_PROXY" = $ProxyUrl
}

$envPath = Join-Path $env:USERPROFILE ".codex\.env"
$displayEnvPath = "%USERPROFILE%\.codex\.env"
$envDir = Split-Path -Parent $envPath
New-Item -ItemType Directory -Force -Path $envDir | Out-Null

$existingLines = @()
if (Test-Path -LiteralPath $envPath) {
    $existingLines = @(Get-Content -LiteralPath $envPath)
}

$seen = @{}
$newLines = New-Object System.Collections.Generic.List[string]

foreach ($line in $existingLines) {
    if ($line -match "^\s*(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY)\s*=") {
        $key = $Matches[1]
        if (-not $seen.ContainsKey($key)) {
            $newLines.Add(("{0}=""{1}""" -f $key, $keysToUpdate[$key]))
            $seen[$key] = $true
        }
    } else {
        $newLines.Add($line)
    }
}

foreach ($key in $keysToUpdate.Keys) {
    if (-not $seen.ContainsKey($key)) {
        $newLines.Add(("{0}=""{1}""" -f $key, $keysToUpdate[$key]))
    }
}

if ($DryRun) {
    Write-Host "Dry run: would update $displayEnvPath"
    foreach ($key in $keysToUpdate.Keys) {
        Write-Host ("{0}=""{1}""" -f $key, $keysToUpdate[$key])
    }
    $preservedCount = 0
    foreach ($line in $existingLines) {
        if ($line -notmatch "^\s*(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY)\s*=") {
            $preservedCount++
        }
    }
    Write-Host "Preserved unrelated lines: $preservedCount"
    exit 0
}

Set-Content -LiteralPath $envPath -Value $newLines -Encoding UTF8
Write-Host "Updated $displayEnvPath"
Write-Host "Restart Codex App or the target LLM tool so it can read the updated proxy environment."
