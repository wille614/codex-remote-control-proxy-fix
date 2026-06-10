Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$envPath = Join-Path $env:USERPROFILE ".codex\.env"
$displayEnvPath = "%USERPROFILE%\.codex\.env"
if (-not (Test-Path -LiteralPath $envPath)) {
    throw "Missing Codex env file: $displayEnvPath"
}

Get-Content -LiteralPath $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) {
        return
    }

    $parts = $line.Split("=", 2)
    if ($parts.Count -ne 2) {
        throw "Invalid .env line: $line"
    }

    $value = $parts[1].Trim().Trim('"')
    [Environment]::SetEnvironmentVariable($parts[0].Trim(), $value, "Process")
}

$runningCodex = Get-Process -Name "Codex" -ErrorAction SilentlyContinue
if ($runningCodex) {
    Write-Host "Codex is already running. Close Codex completely, then run this script again."
    exit 2
}

$package = Get-AppxPackage -Name "OpenAI.Codex" | Sort-Object Version -Descending | Select-Object -First 1
if (-not $package) {
    throw "OpenAI.Codex app package was not found."
}

$codexExe = Join-Path $package.InstallLocation "app\Codex.exe"
if (-not (Test-Path -LiteralPath $codexExe)) {
    throw "Codex.exe was not found at expected package path: $codexExe"
}

Start-Process -FilePath $codexExe
Write-Host "Started Codex App with environment from $displayEnvPath"
