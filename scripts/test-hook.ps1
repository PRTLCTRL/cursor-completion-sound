# Exercises the player the same way Cursor will: JSON on stdin, {} on stdout.

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$playerPath = Join-Path $PSScriptRoot "play-completion-sound.ps1"
$shortSound = Join-Path $repoRoot "sounds\completion.wav"
$longSound = Join-Path $repoRoot "sounds\long-completion.wav"
$debounceDirectory = Join-Path $env:LOCALAPPDATA "cursor-completion-sound"
$tracePath = Join-Path $debounceDirectory "hook-trace.log"

if (-not (Test-Path -LiteralPath $shortSound)) {
    & (Join-Path $PSScriptRoot "generate-completion-wav.ps1")
}
if (-not (Test-Path -LiteralPath $longSound)) {
    & (Join-Path $PSScriptRoot "generate-long-completion-wav.ps1")
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

function Get-TurnStartPath {
    param([string]$conversationId)
    return Join-Path $debounceDirectory "turn-start-$conversationId.txt"
}

$env:CURSOR_COMPLETION_LONG_MS = "30000"
Remove-Item Env:CURSOR_COMPLETION_ENABLED -ErrorAction SilentlyContinue

Write-Host "Checking enabled=false stays silent..."
$env:CURSOR_COMPLETION_ENABLED = "false"
$disabledStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-disabled"
    status          = "completed"
    duration_ms     = 4000
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $disabledStop) -caseName "stop/disabled"
if (Test-Path -LiteralPath (Get-ConversationStampPath -conversationId "chat-disabled")) {
    throw "enabled=false must not play a chime."
}
$env:CURSOR_COMPLETION_ENABLED = "true"

Write-Host "Recording turn start (beforeSubmitPrompt, no chime)..."
$turnStartPayload = @{
    hook_event_name = "beforeSubmitPrompt"
    conversation_id = "chat-stamp"
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $turnStartPayload) -caseName "beforeSubmitPrompt"
if (-not (Test-Path -LiteralPath (Get-TurnStartPath -conversationId "chat-stamp"))) {
    throw "beforeSubmitPrompt should write a turn-start stamp."
}
if (Test-Path -LiteralPath (Get-ConversationStampPath -conversationId "chat-stamp")) {
    throw "beforeSubmitPrompt must not play a chime."
}

Write-Host "Playing short chime (agent stop, chat A)..."
$chatAStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-a"
    status          = "completed"
    duration_ms     = 4000
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $chatAStop) -caseName "stop/completed"

$sameChatBurst = @(
    @{ hook_event_name = "afterAgentResponse"; conversation_id = "chat-a"; text = "Done." },
    @{ hook_event_name = "subagentStop"; conversation_id = "chat-a"; status = "completed"; duration_ms = 1200; loop_count = 0 }
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

Write-Host "Playing short chime for an independent chat (chat B)..."
$chatBStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-b"
    status          = "completed"
    duration_ms     = 8000
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

Write-Host "Playing 8s long clip (duration_ms at the 30s threshold)..."
$longStop = @{
    hook_event_name = "stop"
    conversation_id = "chat-long"
    status          = "completed"
    duration_ms     = 30000
    loop_count      = 0
} | ConvertTo-Json -Compress
Assert-EmptyHookResponse -stdout (Invoke-PlayerWithPayload -payloadJson $longStop) -caseName "stop/long-turn"

if (-not (Test-Path -LiteralPath $tracePath)) {
    throw "Expected hook-trace.log after a long-turn play."
}
$traceText = Get-Content -LiteralPath $tracePath -Raw
if ($traceText -notmatch "long=True") {
    throw "Expected hook-trace.log to record long=True for a 30s turn."
}
if ($traceText -notmatch "long=False") {
    throw "Expected hook-trace.log to record long=False for a short turn."
}

Write-Host "Hook tests passed."
