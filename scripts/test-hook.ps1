# Exercises the player the same way Cursor will: JSON on stdin, {} on stdout.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$playerPath = Join-Path $PSScriptRoot "play-completion-sound.ps1"
$soundPath = Join-Path $repoRoot "sounds\completion.wav"
$debounceDirectory = Join-Path $env:LOCALAPPDATA "cursor-completion-sound"

if (-not (Test-Path -LiteralPath $soundPath)) {
    & (Join-Path $PSScriptRoot "generate-completion-wav.ps1")
}

if (Test-Path -LiteralPath $debounceDirectory) {
    Remove-Item -LiteralPath $debounceDirectory -Recurse -Force
}

function Invoke-PlayerWithPayload {
    param([string]$payloadJson)
    $stdout = $payloadJson | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $playerPath
    return ($stdout | Select-Object -Last 1)
}

function Assert-EmptyHookResponse {
    param([string]$stdout, [string]$caseName)
    if ($stdout -ne "{}") {
        throw "Expected '{}' from $caseName, got '$stdout'"
    }
}

function Get-ConversationStampPath {
    param([string]$conversationId)
    return Join-Path $debounceDirectory "last-play-$conversationId.txt"
}

Write-Host "Playing completion chime (agent stop, chat A)..."
$chatAStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-a"
    status          = "completed"
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $chatAStop) -caseName "stop/completed"

$sameChatBurst = @(
    @{ hook_event_name = "afterAgentResponse"; conversation_id = "chat-a"; text = "Done." },
    @{ hook_event_name = "subagentStop"; conversation_id = "chat-a"; status = "completed"; loop_count = 0 }
)
foreach ($burstPayload in $sameChatBurst) {
    $burstJson = $burstPayload | ConvertTo-Json -Compress
    Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $burstJson) -caseName "$($burstPayload.hook_event_name)/debounced"
}

$chatAStamp = Get-ConversationStampPath -conversationId "chat-a"
if (-not (Test-Path -LiteralPath $chatAStamp)) {
    throw "Expected a debounce stamp for conversation chat-a."
}
$stampAfterChatA = Get-Content -LiteralPath $chatAStamp -Raw

Write-Host "Playing again for an independent chat (chat B)..."
$chatBStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-b"
    status          = "completed"
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $chatBStop) -caseName "stop/independent-chat"

$abortedPayload = @{
    hook_event_name = "stop"
    conversation_id = "chat-a"
    status          = "aborted"
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $abortedPayload) -caseName "stop/aborted"

$stampAfterAbort = Get-Content -LiteralPath $chatAStamp -Raw
if ($stampAfterAbort -ne $stampAfterChatA) {
    throw "Aborted status should not record a new playback."
}

Write-Host "Hook tests passed."
