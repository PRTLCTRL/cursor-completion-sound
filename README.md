# Cursor completion sound

A **Cursor Plugin** that plays a local WAV when an agent or chat turn finishes. Official local install is `~/.cursor/plugins/local` (Customize → Plugins lists it after reload). Marketplace publish is not required.

This is not a VS Code extension. Cursor has no documented `onDidCompleteChat` API.

## Hook events

| Event | When it fires |
| --- | --- |
| `stop` | Agent loop ends (`completed` / `error`; `aborted` is silent) |
| `afterAgentResponse` | An assistant message is finished |
| `subagentStop` | A Task-tool subagent ends |

Same `conversation_id` is debounced for 4 seconds (parent + children + `stop`/`afterAgentResponse` = one chime). A different chat still chimes.

No Grok-specific event exists. Cloud / background Agents do not load this plugin.

## Install the plugin (this machine)

```powershell
cd C:\Users\Arsal\Projects\cursor-completion-sound
npm test
npm run install-plugin
```

That copies a self-contained plugin to:

`C:\Users\Arsal\.cursor\plugins\local\completion-sound`

and **removes** the old user-hook files from `C:\Users\Arsal\.cursor\hooks\` / `hooks.json` so you do not get two chimes.

Then:

1. **Developer: Reload Window** (or restart Cursor).
2. Open **Customize → Plugins** and confirm `completion-sound`.
3. Open **Customize → Hooks** and confirm `play-completion-sound.ps1` on `stop`, `afterAgentResponse`, and `subagentStop`.

Cursor’s built-in finish sound can stay off if you only want this chime.

## How this differs from the user-hook install

| | Plugin (`npm run install-plugin`) | User hook (`npm run install-user-hooks`) |
| --- | --- | --- |
| Where | `~/.cursor/plugins/local/completion-sound` | `~/.cursor/hooks.json` |
| Shown in | Customize → Plugins | Customize → Hooks only |
| Default | Yes | Fallback if the plugin does not load |

Each installer **uninstalls the other** so they never run together.

## Verify

1. Agent / Chat: `Reply with ping and stop.`
2. Ask mode: same prompt.
3. A Task subagent finishing in the same chat should not play a second chime.
4. A second, independent chat should play again.
5. Grok Bot: try a short message. If silent, that surface has no documented hook.
6. `npm run dev` plays the WAV without Cursor.

## Swap the sound

Replace `sounds/completion.wav` (16-bit PCM WAV), then `npm run install-plugin`. Or:

```powershell
setx CURSOR_COMPLETION_SOUND "C:\path\to\your.wav"
```

Restart Cursor after `setx`.

## Limitations

- **Grok Bots:** no documented hook events.
- **Cloud / background Agents:** do not load `~/.cursor/plugins/local` or user hooks.
- **sessionEnd / afterAgentThought:** not hooked (conversation close / thinking blocks, not a finished task).
- Audio failures fail open (`{}`, exit 0).

## Scripts

| Command | Purpose |
| --- | --- |
| `npm run dev` | Play the chime once |
| `npm test` | Fake `stop` / `subagentStop` / `afterAgentResponse` payloads |
| `npm run install-plugin` | Install local plugin; strip leftover user hooks |
| `npm run install-user-hooks` | Fallback user hooks; strip the plugin |
| `npm run uninstall-plugin` | Remove both |
