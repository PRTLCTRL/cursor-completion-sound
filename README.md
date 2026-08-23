# Cursor completion sound

A **Cursor Plugin** that plays a local WAV when an agent or chat turn finishes. Longer turns play an 8-second clip.

Official local install: copy into `~/.cursor/plugins/local`. This repo is Marketplace-ready (public, MIT, `.cursor-plugin/plugin.json`). It is **not listed on the Cursor Marketplace until Anysphere reviews a submit** at [cursor.com/marketplace/publish](https://cursor.com/marketplace/publish).

This is not a VS Code extension. Cursor has no documented `onDidCompleteChat` API.

## Install

### Marketplace (after listing)

1. **Customize → Plugins**
2. Search **completion-sound**
3. **Install** at user scope
4. Reload Cursor

Until it is listed, use local install.

### Local (works today)

```powershell
git clone https://github.com/PRTLCTRL/cursor-completion-sound.git
cd cursor-completion-sound
npm test
npm run install-plugin
```

Then **Developer: Reload Window**. Confirm **Customize → Plugins** (`completion-sound`) and **Customize → Hooks** (`beforeSubmitPrompt`, `stop`, `afterAgentResponse`, `subagentStop`).

Community catalog (not the official Marketplace): [cursor.directory/plugins/new](https://cursor.directory/plugins/new).

## Settings (no Customize form)

Cursor plugins have **no** Customize → Plugins settings panel. Dashboard `variables` is for team secrets / MCP, not this hook.

Edit this file (survives plugin reinstall):

`C:\Users\Arsal\.cursor\completion-sound.json`

```json
{
  "enabled": true,
  "longTurnMs": 30000,
  "shortSoundPath": "",
  "longSoundPath": ""
}
```

Or run `npm run configure` to create it (if missing) and open it.

| Knob | Meaning | Default |
| --- | --- | --- |
| `enabled` | Play any sound | `true` |
| `longTurnMs` | Play the 8s clip at or above this duration | `30000` |
| `shortSoundPath` | Optional 16-bit PCM WAV for short turns | bundled `completion.wav` |
| `longSoundPath` | Optional 16-bit PCM WAV for long turns | bundled `long-completion.wav` |

Save the file. The next hook run reads it — no reinstall.

Power-user env overrides (win over the file):

| Env | Maps to |
| --- | --- |
| `CURSOR_COMPLETION_ENABLED` | `enabled` (`0` / `false` / `off` disables) |
| `CURSOR_COMPLETION_LONG_MS` | `longTurnMs` |
| `CURSOR_COMPLETION_SOUND` | `shortSoundPath` |
| `CURSOR_COMPLETION_SOUND_LONG` | `longSoundPath` |

`setx` needs a Cursor restart. The JSON file does not.

Bundled `config.json` is only the plugin default. User settings win.

## Hook events

| Event | When it fires |
| --- | --- |
| `beforeSubmitPrompt` | User sends a prompt — records turn start, no sound |
| `stop` | Agent loop ends (`completed` / `error`; `aborted` is silent) |
| `afterAgentResponse` | An assistant message is finished |
| `subagentStop` | A Task-tool subagent ends |

Duration: `duration_ms` if Cursor sends it, else elapsed time since `beforeSubmitPrompt` for that chat.

## Limitations

- **Grok Bots:** no documented hook events.
- **Cloud / background Agents:** do not load this plugin.
- Audio failures fail open (`{}`, exit 0).

## Scripts

| Command | Purpose |
| --- | --- |
| `npm run configure` | Create/open `~/.cursor/completion-sound.json` |
| `npm run install-plugin` | Install local plugin; keep user settings |
| `npm test` | Fake hook payloads |
| `npm run dev` | Play the short chime |
| `npm run play-long` | Play the 8s clip |

## License

MIT. Repo: https://github.com/PRTLCTRL/cursor-completion-sound
