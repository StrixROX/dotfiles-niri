# Noctalia settings

`settings/noctalia-config.toml` is a backup of my Noctalia shell settings overrides I've made on top of Noctalia's defaults (bar layout, widgets, audio, theme-related options, etc.).

## How to use

1. Install and launch Noctalia at least once so `~/.local/state/noctalia/` exists.
2. Copy this file to `~/.local/state/noctalia/settings.toml`, overwriting the generated default:
```bash
cp noctalia-config.toml ~/.local/state/noctalia/settings.toml
```
3. Restart Noctalia (or reload quickshell) to pick up the settings.

Done!
