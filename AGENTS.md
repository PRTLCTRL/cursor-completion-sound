# Agent instructions

This repo is a Windows-first Cursor **user hook** that plays a local WAV when an AI turn or Task finishes. Read [CURSOR.md](CURSOR.md) for the product surface. Do not treat this as a Cloudflare OS, Marketplace, or VS Code-extension project.

## Install for the current user

From the repo root:

```powershell
npm run generate-sound
npm test
npm run install-hooks
```

That is the deploy. User hooks in `~/.cursor/hooks.json` cover every local workspace. Do not add project-level `.cursor/hooks.json` unless the user asked for a single-repo install.

After install, tell the user to check **Settings → Hooks** or restart Cursor.

## Change the sound

- Edit `scripts/generate-completion-wav.ps1` and run `npm run generate-sound`, **or** replace `sounds/completion.wav` with a 16-bit PCM WAV.
- Re-run `npm run install-hooks` so `~/.cursor/hooks/completion.wav` updates.
- Validate with `npm run dev` (play once) and `npm test` (stdin JSON, fail-open `{}`).

The default chime is an original two-note sparkle. Do not copy a copyrighted game soundtrack into the WAV.

## Safety rules (do not regress)

- Always exit `0` and print only `{}` on stdout. Never print `followup_message` — that would loop the agent.
- Fail open on audio errors. Never set `failClosed: true` on these hooks.
- Skip `status: aborted`.
- Keep `subagentStop` hooked; do not debounce it. Debounce only `stop` / `afterAgentResponse` (~800ms) so one turn does not double-chime.
- No network. Playback is local (`System.Media.SoundPlayer` or a Windows system WAV fallback).
- Keep hook commands as `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`.
- When writing `~/.cursor/hooks.json`, emit **JSON arrays** per event (Windows PowerShell `ConvertTo-Json` unwraps single-item arrays) and write UTF-8 **without BOM**.

## Layout

| Path | Role |
| --- | --- |
| `scripts/play-completion-sound.ps1` | Hook player |
| `scripts/generate-completion-wav.ps1` | Builds `sounds/completion.wav` |
| `scripts/install-user-hooks.ps1` | Merges user `hooks.json` |
| `install.ps1` / `uninstall.ps1` | Wrappers |
| `hooks/hooks.json` | Plugin-shaped hook list |
| `user-hooks.json` | Template for `~/.cursor/hooks.json` |

## Naming

Name functions by what they do in this domain (`Resolve-CompletionSoundPath`, `Play-CompletionWav`). No `executeThis` / `runThat`, no single-word variables.

## Out of scope

Do not publish to the Cursor Marketplace unless the user explicitly asks. Do not add MCP, skills, or automations just to play a sound.
