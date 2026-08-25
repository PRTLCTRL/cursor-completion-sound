#!/usr/bin/env bash
# Play a bundled WAV when a Grok turn ends. Fail-open: always exit 0, stdout is {}.
# Usage: play-grok-sound.sh [done|error]
# No network. No matcher. Safe if no audio player exists.

# Drain hook stdin so the event JSON cannot leak into the player.
cat >/dev/null 2>&1 || true

printf '%s\n' '{}'

event="${1:-done}"
root="${GROK_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-}}"
if [ -z "$root" ]; then
  root="$(cd "$(dirname "$0")/.." && pwd)"
fi
data="${GROK_PLUGIN_DATA:-${CLAUDE_PLUGIN_DATA:-}}"

if [ -n "$data" ] && [ -f "$data/muted" ]; then
  exit 0
fi
if [ -f "${HOME}/.grok/sounds/muted" ]; then
  exit 0
fi

if [ "$event" = "error" ]; then
  wav="$root/sounds/error.wav"
else
  wav="$root/sounds/completion.wav"
fi

if [ ! -f "$wav" ]; then
  exit 0
fi

play_wav() {
  if command -v afplay >/dev/null 2>&1; then
    afplay "$wav" >/dev/null 2>&1 &
    return 0
  fi
  if command -v paplay >/dev/null 2>&1; then
    paplay "$wav" >/dev/null 2>&1 &
    return 0
  fi
  if command -v pw-play >/dev/null 2>&1; then
    pw-play "$wav" >/dev/null 2>&1 &
    return 0
  fi
  if command -v aplay >/dev/null 2>&1; then
    aplay -q "$wav" >/dev/null 2>&1 &
    return 0
  fi
  if command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit -loglevel quiet "$wav" >/dev/null 2>&1 &
    return 0
  fi
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
      "try { (New-Object Media.SoundPlayer -ArgumentList '$wav').PlaySync() } catch { }" \
      >/dev/null 2>&1 &
    return 0
  fi
  return 0
}

play_wav || true
exit 0
