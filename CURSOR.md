# Cursor setup

This is a **Cursor Plugin**. Local install copies it to `~/.cursor/plugins/local/completion-sound`.

## Enable

1. Clone https://github.com/PRTLCTRL/cursor-completion-sound
2. `npm run install-plugin`
3. **Developer: Reload Window**
4. **Customize → Plugins** should list `completion-sound`
5. **Customize → Hooks** should list `play-completion-sound.ps1` on `beforeSubmitPrompt`, `stop`, `afterAgentResponse`, `subagentStop`

## Settings

There is no Customize settings form. Edit `~/.cursor/completion-sound.json` or run `npm run configure`.

See [README.md](README.md) for knobs and env overrides.

Marketplace listing requires a submit at https://cursor.com/marketplace/publish — this repo is ready, not listed until reviewed.
