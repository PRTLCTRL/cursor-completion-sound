# Creates ~/.cursor/completion-sound.json if missing. Never overwrites
# an existing user file (plugin reinstall must not reset preferences).
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$defaultsPath = Join-Path $repoRoot "config.json"
$userSettingsPath = Join-Path $env:USERPROFILE ".cursor\completion-sound.json"

if (-not (Test-Path -LiteralPath (Split-Path -Parent $userSettingsPath))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $userSettingsPath) -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $userSettingsPath)) {
    if (Test-Path -LiteralPath $defaultsPath) {
        Copy-Item -LiteralPath $defaultsPath -Destination $userSettingsPath
    } else {
        '{ "enabled": true, "longTurnMs": 30000, "shortSoundPath": "", "longSoundPath": "" }' |
            Set-Content -LiteralPath $userSettingsPath -Encoding utf8
    }
    Write-Host "Created user settings: $userSettingsPath"
} else {
    Write-Host "User settings already exist: $userSettingsPath"
}

Write-Output $userSettingsPath
