# Cursor setup

Anyone can pick this up as a **user hook**. That is the smallest official surface that fires when a chat, agent, or Task finishes.

## Enable

1. Clone this repo.
2. From the repo root, run `npm run install-hooks` (or `.\install.ps1`).
3. Open **Settings → Hooks**. You should see `play-completion-sound.ps1` on:
   - `stop`
   - `afterAgentResponse`
   - `subagentStop`
4. If the list is empty, restart Cursor. Cursor reloads `~/.cursor/hooks.json` on save; a first install sometimes needs a restart.
5. Optional: turn off Cursor’s own finish sound under **Settings → Features → Chat → Play sound on finish** (or **Notifications → Completion Sound**).

User hooks live at `~/.cursor/hooks.json` and run with cwd `~/.cursor/`. They apply to every local workspace. Do not put this only in one project’s `.cursor/hooks.json` unless you want the sound in that repo alone.

## What “done” means here

| You finished… | Hook event |
| --- | --- |
| An Agent / Chat turn | `stop` (and often `afterAgentResponse`) |
| An Ask-mode reply | `afterAgentResponse` (and possibly `stop`) |
| A Task / subagent | `subagentStop` |

Cancelled turns (`aborted`) stay silent. `stop` + `afterAgentResponse` on the same turn chime once (800ms debounce). A finished Task always chimes.

## Debug

- **Hooks** output channel — did the script spawn?
- `npm run dev` in this repo — can Windows play the WAV at all?
- Confirm the installed files exist: `~/.cursor/hooks/play-completion-sound.ps1` and `completion.wav`

## What this is not

- Not a Marketplace plugin (those are reviewed Git repos submitted to Cursor).
- Not a VS Code extension. There is no documented `onDidCompleteChat` API.
- Not loaded by Cloud / background Agents (`~/.cursor/hooks.json` is ignored there).
- Grok Bot hook coverage is undocumented. The same events are registered; they may or may not fire.

See [AGENTS.md](AGENTS.md) if an agent is installing or changing this for you.
