# Plays a local WAV when a Cursor agent/chat turn finishes.
# Reads optional hook JSON on stdin. Always exits 0 and prints {} so a
# playback failure cannot block or loop the agent.

$ErrorActionPreference = "Stop"
$debounceWindow = [TimeSpan]::FromSeconds(4)
$debounceDirectory = Join-Path $env:LOCALAPPDATA "cursor-completion-sound"

function Resolve-CompletionSoundPath {
    if ($env:CURSOR_COMPLETION_SOUND -and (Test-Path -LiteralPath $env:CURSOR_COMPLETION_SOUND)) {
        return $env:CURSOR_COMPLETION_SOUND
    }

    $lookupPaths = @(
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
    if (-not [Console]::IsInputRedirected) {
        return $null
    }

    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        return $null
    }

    return $rawInput | ConvertFrom-Json
}

function Test-CancelledAgentLoop {
    param($hookPayload)

    if ($null -eq $hookPayload) {
        return $false
    }

    return [string]$hookPayload.status -eq "aborted"
}

function Get-ConversationDebouncePath {
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

    return Join-Path $debounceDirectory "last-play-$safeKey.txt"
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

function Play-CompletionWav {
    param([string]$soundPath)

    Add-Type -AssemblyName System.Windows.Forms
    $soundPlayer = New-Object System.Media.SoundPlayer
    try {
        $soundPlayer.SoundLocation = $soundPath
        $soundPlayer.Load()
        $soundPlayer.PlaySync()
    } finally {
        $soundPlayer.Dispose()
    }
}

function Play-SystemFallback {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Media.SystemSounds]::Exclamation.Play()
    Start-Sleep -Milliseconds 400
}

try {
    $hookPayload = Read-HookPayload
    if (Test-CancelledAgentLoop -hookPayload $hookPayload) {
        return
    }

    $debouncePath = Get-ConversationDebouncePath -hookPayload $hookPayload
    if (Test-RecentConversationChime -debouncePath $debouncePath) {
        return
    }

    Write-ConversationChimeStamp -debouncePath $debouncePath

    $soundPath = Resolve-CompletionSoundPath
    if ($soundPath) {
        Play-CompletionWav -soundPath $soundPath
    } else {
        Play-SystemFallback
    }
} catch {
    # Fail open: never interrupt the agent loop for audio problems.
} finally {
    Write-Output "{}"
    exit 0
}
