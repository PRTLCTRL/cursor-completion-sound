# Plays a local WAV when a Cursor agent/chat turn finishes.
# Reads optional hook JSON on stdin. Always exits 0 and prints {} so a
# playback failure cannot block or loop the agent.

$ErrorActionPreference = "Stop"
$debounceWindow = [TimeSpan]::FromMilliseconds(1200)
$debounceDirectory = Join-Path $env:LOCALAPPDATA "cursor-completion-sound"
$defaultLongTurnMs = 30000
$userSettingsPath = Join-Path $env:USERPROFILE ".cursor\completion-sound.json"

function Read-SettingsFile {
    param([string]$settingsPath)

    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Merge-SettingsLayer {
    param($baseSettings, $overlaySettings)

    if ($null -eq $overlaySettings) {
        return $baseSettings
    }

    if ($null -ne $overlaySettings.enabled) {
        $baseSettings.enabled = [bool]$overlaySettings.enabled
    }
    if ($null -ne $overlaySettings.longTurnMs -and $overlaySettings.longTurnMs -ne "") {
        $baseSettings.longTurnMs = [int]$overlaySettings.longTurnMs
    }
    if ($overlaySettings.shortSoundPath) {
        $baseSettings.shortSoundPath = [string]$overlaySettings.shortSoundPath
    }
    if ($overlaySettings.longSoundPath) {
        $baseSettings.longSoundPath = [string]$overlaySettings.longSoundPath
    }
    return $baseSettings
}

function Get-MergedSettings {
    $mergedSettings = [pscustomobject]@{
        enabled        = $true
        longTurnMs     = $defaultLongTurnMs
        shortSoundPath = ""
        longSoundPath  = ""
    }

    $pluginConfigPaths = @(
        (Join-Path $PSScriptRoot "config.json"),
        (Join-Path $PSScriptRoot "..\config.json")
    )
    foreach ($pluginConfigPath in $pluginConfigPaths) {
        $pluginConfig = Read-SettingsFile -settingsPath $pluginConfigPath
        if ($pluginConfig) {
            $mergedSettings = Merge-SettingsLayer -baseSettings $mergedSettings -overlaySettings $pluginConfig
            break
        }
    }

    $mergedSettings = Merge-SettingsLayer -baseSettings $mergedSettings -overlaySettings (Read-SettingsFile -settingsPath $userSettingsPath)

    $enabledEnv = $env:CURSOR_COMPLETION_ENABLED
    if ($enabledEnv -and ($enabledEnv -match '^(0|false|no|off)$')) {
        $mergedSettings.enabled = $false
    } elseif ($enabledEnv -and ($enabledEnv -match '^(1|true|yes|on)$')) {
        $mergedSettings.enabled = $true
    }

    if ($env:CURSOR_COMPLETION_LONG_MS -and ($env:CURSOR_COMPLETION_LONG_MS -match '^\d+$')) {
        $mergedSettings.longTurnMs = [int]$env:CURSOR_COMPLETION_LONG_MS
    }
    if ($env:CURSOR_COMPLETION_SOUND) {
        $mergedSettings.shortSoundPath = $env:CURSOR_COMPLETION_SOUND
    }
    if ($env:CURSOR_COMPLETION_SOUND_LONG) {
        $mergedSettings.longSoundPath = $env:CURSOR_COMPLETION_SOUND_LONG
    }

    return $mergedSettings
}

$pluginSettings = Get-MergedSettings
$longTurnThreshold = [TimeSpan]::FromMilliseconds([double]$pluginSettings.longTurnMs)

function Resolve-CompletionSoundPath {
    param([bool]$preferLongClip = $false)

    if ($preferLongClip) {
        $longLookupPaths = @(
            $pluginSettings.longSoundPath,
            $env:CURSOR_COMPLETION_SOUND_LONG,
            (Join-Path $PSScriptRoot "long-completion.wav"),
            (Join-Path $PSScriptRoot "sounds\long-completion.wav"),
            (Join-Path $PSScriptRoot "..\sounds\long-completion.wav")
        )
        foreach ($candidatePath in $longLookupPaths) {
            if ($candidatePath -and (Test-Path -LiteralPath $candidatePath)) {
                return (Resolve-Path -LiteralPath $candidatePath).Path
            }
        }
        # No long clip installed: fall through to the short chime.
    }

    if ($pluginSettings.shortSoundPath -and (Test-Path -LiteralPath $pluginSettings.shortSoundPath)) {
        return (Resolve-Path -LiteralPath $pluginSettings.shortSoundPath).Path
    }

    if ($env:CURSOR_COMPLETION_SOUND -and (Test-Path -LiteralPath $env:CURSOR_COMPLETION_SOUND)) {
        return $env:CURSOR_COMPLETION_SOUND
    }

    $lookupPaths = @(
        (Join-Path $PSScriptRoot "zelda-fairy-fountain-3s.wav"),
        (Join-Path $PSScriptRoot "completion.wav"),
        (Join-Path $PSScriptRoot "sounds\completion.wav"),
        (Join-Path $PSScriptRoot "..\sounds\completion.wav"),
        "C:\Windows\Media\Windows Notify Calendar.wav",
        "C:\Windows\Media\chord.wav"
    )

    foreach ($candidatePath in $lookupPaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return (Resolve-Path -LiteralPath $candidatePath).Path
        }
    }

    return $null
}

function Read-HookPayload {
    # A malformed payload must never prevent playback: Windows PowerShell 5.1
    # rejects JSON with a BOM / encoding artifacts at the start of the stream
    # ("Invalid JSON primitive"), which is exactly what Cursor's stdin pipe
    # delivers. Trim to the first "{" and treat any parse failure as "no
    # payload" so the chime still fires.
    try {
        if (-not [Console]::IsInputRedirected) {
            return $null
        }

        $rawInput = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($rawInput)) {
            return $null
        }

        $jsonStart = $rawInput.IndexOf("{")
        if ($jsonStart -lt 0) {
            return $null
        }

        return $rawInput.Substring($jsonStart) | ConvertFrom-Json
    } catch {
        Write-HookError -failedStage "read-payload" -caughtError $_
        return $null
    }
}

function Test-CancelledAgentLoop {
    param($hookPayload)

    if ($null -eq $hookPayload) {
        return $false
    }

    return [string]$hookPayload.status -eq "aborted"
}

function Get-ConversationKey {
    param($hookPayload)

    $conversationKey = "global"
    if ($hookPayload -and $hookPayload.conversation_id) {
        $conversationKey = [string]$hookPayload.conversation_id
    } elseif ($hookPayload -and $hookPayload.generation_id) {
        $conversationKey = [string]$hookPayload.generation_id
    }

    $safeKey = ($conversationKey -replace '[^\w\-.]+', '_')
    if ([string]::IsNullOrWhiteSpace($safeKey)) {
        $safeKey = "global"
    }

    return $safeKey
}

function Get-ConversationDebouncePath {
    param($hookPayload)

    return Join-Path $debounceDirectory "last-play-$(Get-ConversationKey -hookPayload $hookPayload).txt"
}

function Get-TurnStartStampPath {
    param($hookPayload)

    return Join-Path $debounceDirectory "turn-start-$(Get-ConversationKey -hookPayload $hookPayload).txt"
}

function Write-TurnStartStamp {
    param($hookPayload)

    if (-not (Test-Path -LiteralPath $debounceDirectory)) {
        New-Item -ItemType Directory -Path $debounceDirectory -Force | Out-Null
    }
    [DateTime]::UtcNow.ToBinary() | Set-Content -LiteralPath (Get-TurnStartStampPath -hookPayload $hookPayload)
}

function Get-CompletedTurnDuration {
    param($hookPayload)

    # Documented on subagentStop / sessionEnd. stop/afterAgentResponse omit it.
    if ($hookPayload -and $null -ne $hookPayload.duration_ms -and $hookPayload.duration_ms -ne "") {
        return [TimeSpan]::FromMilliseconds([double]$hookPayload.duration_ms)
    }
    if ($hookPayload -and $null -ne $hookPayload.duration -and $hookPayload.duration -ne "") {
        return [TimeSpan]::FromSeconds([double]$hookPayload.duration)
    }
    if ($hookPayload -and $hookPayload.started_at) {
        try {
            $startedAtUtc = [DateTime]::Parse([string]$hookPayload.started_at, $null, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
            $fromStartedAt = [DateTime]::UtcNow - $startedAtUtc
            if ($fromStartedAt -gt [TimeSpan]::Zero) {
                return $fromStartedAt
            }
        } catch {
        }
    }

    $stampPath = Get-TurnStartStampPath -hookPayload $hookPayload
    if (-not (Test-Path -LiteralPath $stampPath)) {
        return [TimeSpan]::Zero
    }

    $rawTicks = Get-Content -LiteralPath $stampPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $rawTicks) {
        return [TimeSpan]::Zero
    }

    $turnStartedUtc = [DateTime]::FromBinary([int64]$rawTicks)
    Remove-Item -LiteralPath $stampPath -Force -ErrorAction SilentlyContinue
    $turnDuration = [DateTime]::UtcNow - $turnStartedUtc
    if ($turnDuration -lt [TimeSpan]::Zero) {
        return [TimeSpan]::Zero
    }
    return $turnDuration
}

function Test-RecentConversationChime {
    param([string]$debouncePath)

    if (-not (Test-Path -LiteralPath $debouncePath)) {
        return $false
    }

    $rawTicks = (Get-Content -LiteralPath $debouncePath -ErrorAction SilentlyContinue | Select-Object -First 1)
    if (-not $rawTicks) {
        return $false
    }

    $lastPlayedUtc = [DateTime]::FromBinary([int64]$rawTicks)
    return (([DateTime]::UtcNow) - $lastPlayedUtc) -lt $debounceWindow
}

function Write-ConversationChimeStamp {
    param([string]$debouncePath)

    if (-not (Test-Path -LiteralPath $debounceDirectory)) {
        New-Item -ItemType Directory -Path $debounceDirectory -Force | Out-Null
    }
    [DateTime]::UtcNow.ToBinary() | Set-Content -LiteralPath $debouncePath
}

function Start-DetachedWavPlayback {
    param([string]$soundPath)

    $wavPlayer = Join-Path $PSScriptRoot "play-wav-only.ps1"
    if (-not (Test-Path -LiteralPath $wavPlayer)) {
        Add-Type -AssemblyName System.Windows.Forms
        $soundPlayer = New-Object System.Media.SoundPlayer
        try {
            $soundPlayer.SoundLocation = $soundPath
            $soundPlayer.Load()
            $soundPlayer.PlaySync()
        } finally {
            $soundPlayer.Dispose()
        }
        return
    }

    # Cursor kills the hook process tree as soon as {} is returned (~300ms).
    # `start` launches playback outside that job so the 3s clip can finish.
    $argumentList = "/c start `"`" /min powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File `"$wavPlayer`" -SoundPath `"$soundPath`""
    Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList $argumentList -WindowStyle Hidden
}

function Play-SystemFallback {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Media.SystemSounds]::Exclamation.Play()
    Start-Sleep -Milliseconds 400
}

function Write-HookError {
    param([string]$failedStage, $caughtError)
    try {
        if (-not (Test-Path -LiteralPath $debounceDirectory)) {
            New-Item -ItemType Directory -Path $debounceDirectory -Force | Out-Null
        }
        $errorLine = "{0:o} stage={1} error={2}" -f [DateTime]::UtcNow, $failedStage, $caughtError.Exception.Message
        Add-Content -LiteralPath (Join-Path $debounceDirectory "hook-error.log") -Value $errorLine
    } catch {
    }
}

function Write-HookTrace {
    param($hookPayload, [string]$extraDetail)
    try {
        if (-not (Test-Path -LiteralPath $debounceDirectory)) {
            New-Item -ItemType Directory -Path $debounceDirectory -Force | Out-Null
        }
        $eventName = "none"
        $statusName = "none"
        if ($hookPayload) {
            if ($hookPayload.hook_event_name) { $eventName = [string]$hookPayload.hook_event_name }
            if ($hookPayload.status) { $statusName = [string]$hookPayload.status }
        }
        $traceLine = "{0:o} event={1} status={2}" -f [DateTime]::UtcNow, $eventName, $statusName
        if ($extraDetail) {
            $traceLine = "$traceLine $extraDetail"
        }
        Add-Content -LiteralPath (Join-Path $debounceDirectory "hook-trace.log") -Value $traceLine
    } catch {
    }
}

try {
    $hookPayload = Read-HookPayload
    Write-HookTrace -hookPayload $hookPayload

    # beforeSubmitPrompt marks the start of a turn so the completion events can
    # tell a 20-minute agent run apart from a quick reply. Never chimes.
    if ($hookPayload -and [string]$hookPayload.hook_event_name -eq "beforeSubmitPrompt") {
        try {
            Write-TurnStartStamp -hookPayload $hookPayload
        } catch {
            Write-HookError -failedStage "turn-start-stamp" -caughtError $_
        }
        return
    }

    $shouldChime = [bool]$pluginSettings.enabled
    if (-not $shouldChime) {
        Write-HookTrace -hookPayload $hookPayload -extraDetail "enabled=False"
    }
    if (Test-CancelledAgentLoop -hookPayload $hookPayload) {
        $shouldChime = $false
    }

    # A finished Task always chimes: debounce only dedupes stop +
    # afterAgentResponse firing for the same turn.
    $isSubagentStop = $hookPayload -and [string]$hookPayload.hook_event_name -eq "subagentStop"

    if ($shouldChime -and -not $isSubagentStop) {
        # Debounce is best-effort: a broken stamp file must not mute the chime.
        try {
            $debouncePath = Get-ConversationDebouncePath -hookPayload $hookPayload
            if (Test-RecentConversationChime -debouncePath $debouncePath) {
                $shouldChime = $false
            } else {
                Write-ConversationChimeStamp -debouncePath $debouncePath
            }
        } catch {
            Write-HookError -failedStage "debounce" -caughtError $_
        }
    }

    if ($shouldChime) {
        $preferLongClip = $false
        try {
            $turnDuration = Get-CompletedTurnDuration -hookPayload $hookPayload
            $preferLongClip = $turnDuration -ge $longTurnThreshold
            Write-HookTrace -hookPayload $hookPayload -extraDetail ("duration={0:n0}s long={1}" -f $turnDuration.TotalSeconds, $preferLongClip)
        } catch {
            Write-HookError -failedStage "turn-duration" -caughtError $_
        }

        $soundPath = Resolve-CompletionSoundPath -preferLongClip $preferLongClip
        if ($soundPath) {
            Start-DetachedWavPlayback -soundPath $soundPath
        } else {
            Play-SystemFallback
        }
    }
} catch {
    # Fail open: never interrupt the agent loop for audio problems.
    Write-HookError -failedStage "main" -caughtError $_
} finally {
    Write-Output "{}"
    exit 0
}
