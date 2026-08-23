# Installs the user hook globally and preserves the local Fairy Fountain clip.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "hooks-json.ps1")

$repoRoot = Split-Path -Parent $PSScriptRoot
$bundledPlayer = Join-Path $PSScriptRoot "play-completion-sound.ps1"
$bundledWavPlayer = Join-Path $PSScriptRoot "play-wav-only.ps1"
$bundledCmd = Join-Path $PSScriptRoot "play-completion-sound.cmd"
$bundledSound = Join-Path $repoRoot "sounds\completion.wav"
$cursorDirectory = Join-Path $env:USERPROFILE ".cursor"
$hooksDirectory = Join-Path $cursorDirectory "hooks"
$userHooksPath = Join-Path $cursorDirectory "hooks.json"
$installedPlayer = Join-Path $hooksDirectory "play-completion-sound.ps1"
$installedWavPlayer = Join-Path $hooksDirectory "play-wav-only.ps1"
$installedCmd = Join-Path $hooksDirectory "play-completion-sound.cmd"
$installedSound = Join-Path $hooksDirectory "completion.wav"
$userClipPath = Join-Path $hooksDirectory "zelda-fairy-fountain-3s.wav"
$userLongClipPath = Join-Path $hooksDirectory "zelda-fairy-fountain-8s.wav"
$pluginInstallDirectory = Join-Path $cursorDirectory "plugins\local\completion-sound"
$customSoundsDirectory = Join-Path $env:APPDATA "Cursor\User\globalStorage\customSounds"
$cursorSettingsPath = Join-Path $env:APPDATA "Cursor\User\settings.json"

# Cursor on Windows runs: Get-Content payload.json | <command>
# Nested powershell -File is the reliable form inside that wrapper.
$hookCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installedPlayer"
$playerMarker = "play-completion-sound"

function Find-FairyFountainSourceClip {
    return Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE "Downloads") -Filter "*.mp3" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*Fairy Fountain*" } |
        Select-Object -First 1
}

function Install-UserLongChimeWav {
    # The long chime plays for turns over the long-turn threshold. The bundled
    # long clip is the fallback when no personal clip can be built; the player
    # falls back to the short chime when neither file exists.
    $bundledLongSound = Join-Path $repoRoot "sounds\long-completion.wav"
    if (Test-Path -LiteralPath $bundledLongSound) {
        Copy-Item -LiteralPath $bundledLongSound -Destination (Join-Path $hooksDirectory "long-completion.wav") -Force
    }

    if (Test-Path -LiteralPath $userLongClipPath) {
        return
    }

    $downloadClip = Find-FairyFountainSourceClip
    if (-not $downloadClip) {
        return
    }

    $ffmpeg = (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
    if ($ffmpeg) {
        & $ffmpeg -y -loglevel error -i $downloadClip.FullName -t 8 -af "afade=t=out:st=7.2:d=0.8" -acodec pcm_s16le -ar 44100 -ac 1 $userLongClipPath
    }
}

function Install-UserChimeWav {
    if (Test-Path -LiteralPath $userClipPath) {
        Copy-Item -LiteralPath $userClipPath -Destination $installedSound -Force
        return $userClipPath
    }

    $downloadClip = Find-FairyFountainSourceClip

    if ($downloadClip) {
        $ffmpeg = (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue).Source
        if ($ffmpeg) {
            & $ffmpeg -y -i $downloadClip.FullName -t 3 -af "afade=t=out:st=2.55:d=0.45" -acodec pcm_s16le -ar 44100 -ac 1 $userClipPath
            if (Test-Path -LiteralPath $userClipPath) {
                Copy-Item -LiteralPath $userClipPath -Destination $installedSound -Force
                return $userClipPath
            }
        }
    }

    if (Test-Path -LiteralPath $installedSound) {
        return $installedSound
    }

    if (-not (Test-Path -LiteralPath $bundledSound)) {
        & (Join-Path $PSScriptRoot "generate-completion-wav.ps1")
    }
    Copy-Item -LiteralPath $bundledSound -Destination $installedSound -Force
    return $installedSound
}

function Set-CursorCompletionSoundSetting {
    param([string]$soundPath)

    if (-not (Test-Path -LiteralPath $cursorSettingsPath)) {
        return
    }

    $settingsRaw = Get-Content -LiteralPath $cursorSettingsPath -Raw
    $forwardSlashPath = $soundPath.Replace("\", "/")
    if ($settingsRaw -notmatch '"cursor.composer.shouldChimeAfterChatFinishes"') {
        $settingsRaw = $settingsRaw -replace "\{", "{`r`n    `"cursor.composer.shouldChimeAfterChatFinishes`": true,"
    } else {
        $settingsRaw = $settingsRaw -replace '"cursor.composer.shouldChimeAfterChatFinishes"\s*:\s*false', '"cursor.composer.shouldChimeAfterChatFinishes": true'
    }

    if ($settingsRaw -match '"cursor.composer.customChimeSoundPath"') {
        $settingsRaw = $settingsRaw -replace '"cursor.composer.customChimeSoundPath"\s*:\s*"[^"]*"', "`"cursor.composer.customChimeSoundPath`": `"$forwardSlashPath`""
    } else {
        $settingsRaw = $settingsRaw -replace '"cursor.composer.shouldChimeAfterChatFinishes": true,', "`"cursor.composer.shouldChimeAfterChatFinishes`": true,`r`n    `"cursor.composer.customChimeSoundPath`": `"$forwardSlashPath`","
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($cursorSettingsPath, $settingsRaw, $utf8NoBom)
}

if (Test-Path -LiteralPath $pluginInstallDirectory) {
    Remove-Item -LiteralPath $pluginInstallDirectory -Recurse -Force
}

if (-not (Test-Path -LiteralPath $hooksDirectory)) {
    New-Item -ItemType Directory -Path $hooksDirectory -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $customSoundsDirectory)) {
    New-Item -ItemType Directory -Path $customSoundsDirectory -Force | Out-Null
}

Copy-Item -LiteralPath $bundledPlayer -Destination $installedPlayer -Force
Copy-Item -LiteralPath $bundledWavPlayer -Destination $installedWavPlayer -Force
# Seed config.json only on first install so personal settings survive updates.
$bundledConfig = Join-Path $repoRoot "config.json"
$installedConfig = Join-Path $hooksDirectory "config.json"
if ((Test-Path -LiteralPath $bundledConfig) -and -not (Test-Path -LiteralPath $installedConfig)) {
    Copy-Item -LiteralPath $bundledConfig -Destination $installedConfig -Force
}
if (Test-Path -LiteralPath $bundledCmd) {
    Copy-Item -LiteralPath $bundledCmd -Destination $installedCmd -Force
}

$chimePath = Install-UserChimeWav
Install-UserLongChimeWav
Copy-Item -LiteralPath $installedSound -Destination (Join-Path $customSoundsDirectory "custom-chime.wav") -Force
Set-CursorCompletionSoundSetting -soundPath $installedSound

$hookEntry = [pscustomobject]@{
    command = $hookCommand
    timeout = 12
}

function Remove-ExistingPlayerHooks {
    param($eventHooks)
    if ($null -eq $eventHooks) {
        return @()
    }
    return @($eventHooks | Where-Object { $_.command -notmatch [regex]::Escape($playerMarker) })
}

if (Test-Path -LiteralPath $userHooksPath) {
    $hooksConfig = Get-Content -LiteralPath $userHooksPath -Raw | ConvertFrom-Json
} else {
    $hooksConfig = [pscustomobject]@{
        version = 1
        hooks   = [pscustomobject]@{}
    }
}

if (-not $hooksConfig.version) {
    $hooksConfig | Add-Member -NotePropertyName version -NotePropertyValue 1
}
if (-not $hooksConfig.hooks) {
    $hooksConfig | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{})
}

# beforeSubmitPrompt records the turn start time so completion events can pick
# the long chime for long agent runs. The player never chimes on that event.
foreach ($eventName in @("beforeSubmitPrompt", "stop", "afterAgentResponse", "subagentStop")) {
    $eventHooks = Remove-ExistingPlayerHooks -eventHooks $hooksConfig.hooks.$eventName
    $eventHooks += $hookEntry
    $hooksConfig.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @($eventHooks) -Force
}

Write-Utf8NoBomFile -filePath $userHooksPath -contents (ConvertTo-CursorHooksJson -config $hooksConfig)

Write-Host "Installed chime: $chimePath"
Write-Host "Hook player:     $installedPlayer"
Write-Host "User hooks:      $userHooksPath"
Write-Host "Cursor setting:  cursor.composer.customChimeSoundPath -> $installedSound"
Write-Host "Fully quit and reopen Cursor so every window reloads hooks + Completion Sound."
