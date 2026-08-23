# Installs this folder as a Cursor Plugin at ~/.cursor/plugins/local
# and removes the leftover user-hook copy so the chime cannot fire twice.
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "hooks-json.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$shortSound = Join-Path $repoRoot "sounds\completion.wav"
$longSound = Join-Path $repoRoot "sounds\long-completion.wav"
$cursorDirectory = Join-Path $env:USERPROFILE ".cursor"
$localPluginsDirectory = Join-Path $cursorDirectory "plugins\local"
$pluginInstallDirectory = Join-Path $localPluginsDirectory "completion-sound"
$playerScript = Join-Path $pluginInstallDirectory "scripts\play-completion-sound.ps1"
$userHooksPath = Join-Path $cursorDirectory "hooks.json"
$legacyHookFiles = @(
    (Join-Path $cursorDirectory "hooks\play-completion-sound.ps1"),
    (Join-Path $cursorDirectory "hooks\play-wav-only.ps1"),
    (Join-Path $cursorDirectory "hooks\play-completion-sound.cmd"),
    (Join-Path $cursorDirectory "hooks\completion.wav"),
    (Join-Path $cursorDirectory "hooks\long-completion.wav"),
    (Join-Path $cursorDirectory "hooks\completion-sound")
)

if (-not (Test-Path -LiteralPath $shortSound)) {
    & (Join-Path $PSScriptRoot "generate-completion-wav.ps1")
}
if (-not (Test-Path -LiteralPath $longSound)) {
    & (Join-Path $PSScriptRoot "generate-long-completion-wav.ps1")
}

if (Test-Path -LiteralPath $pluginInstallDirectory) {
    Remove-Item -LiteralPath $pluginInstallDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path (Join-Path $pluginInstallDirectory "scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pluginInstallDirectory "sounds") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pluginInstallDirectory "hooks") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pluginInstallDirectory ".cursor-plugin") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pluginInstallDirectory "assets") -Force | Out-Null

Copy-Item -Force (Join-Path $repoRoot ".cursor-plugin\plugin.json") (Join-Path $pluginInstallDirectory ".cursor-plugin\plugin.json")
Copy-Item -Force (Join-Path $repoRoot "config.json") (Join-Path $pluginInstallDirectory "config.json")
Copy-Item -Force (Join-Path $repoRoot "config.example.json") (Join-Path $pluginInstallDirectory "config.example.json")
& (Join-Path $PSScriptRoot "write-user-settings.ps1") | Out-Null
Copy-Item -Force (Join-Path $repoRoot "scripts\play-completion-sound.ps1") (Join-Path $pluginInstallDirectory "scripts\play-completion-sound.ps1")
Copy-Item -Force (Join-Path $repoRoot "scripts\play-wav-only.ps1") (Join-Path $pluginInstallDirectory "scripts\play-wav-only.ps1")
Copy-Item -Force (Join-Path $repoRoot "scripts\play-completion-sound.cmd") (Join-Path $pluginInstallDirectory "scripts\play-completion-sound.cmd")
Copy-Item -Force $shortSound (Join-Path $pluginInstallDirectory "sounds\completion.wav")
Copy-Item -Force $longSound (Join-Path $pluginInstallDirectory "sounds\long-completion.wav")
Copy-Item -Force $shortSound (Join-Path $pluginInstallDirectory "scripts\completion.wav")
Copy-Item -Force $longSound (Join-Path $pluginInstallDirectory "scripts\long-completion.wav")
Copy-Item -Force (Join-Path $repoRoot "assets\logo.svg") (Join-Path $pluginInstallDirectory "assets\logo.svg")
Copy-Item -Force (Join-Path $repoRoot "README.md") (Join-Path $pluginInstallDirectory "README.md")

$absolutePlayerCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$playerScript`""
$hookEntry = [pscustomobject]@{
    command = $absolutePlayerCommand
    timeout = 8
}
$pluginHooksConfig = [pscustomobject]@{
    version = 1
    hooks   = [pscustomobject]@{
        beforeSubmitPrompt = @($hookEntry)
        stop               = @($hookEntry)
        afterAgentResponse = @($hookEntry)
        subagentStop       = @($hookEntry)
    }
}
Write-Utf8NoBomFile -filePath (Join-Path $pluginInstallDirectory "hooks\hooks.json") -contents (ConvertTo-CursorHooksJson -config $pluginHooksConfig)

Remove-CompletionSoundUserHooks -userHooksPath $userHooksPath
foreach ($legacyPath in $legacyHookFiles) {
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
    }
}

Write-Host "Installed Cursor plugin: $pluginInstallDirectory"
Write-Host "Removed leftover user-hook copies so this cannot double-play."
Write-Host "Reload Cursor (Developer: Reload Window) or restart, then confirm Customize -> Plugins and Customize -> Hooks."
