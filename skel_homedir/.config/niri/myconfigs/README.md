# niri dotfiles (myconfigs)

Personal [niri](https://github.com/YaLTeR/niri) window manager config, split into small
per-concern `.kdl` files and included from a single entry point, with optional
shell-specific integrations (Noctalia / DankMaterialShell) kept in their own subfolders.

## How to Use

1. Clone the repo into `myconfigs` folder under the niri configs folder (`~/.config/niri`).

```bash
cd ~/.config/niri
git clone https://github.com/StrixROX/dotfiles-niri.git myconfigs
```

2. Include the `myconfigs/main.kdl` file from the repo into Niri's `config.kdl` file.

```kdl
// ~/.config/niri/config.kdl

include "myconfigs/main.kdl"
```

3. Based on which shell you are using, include their respective `main.kdl` files (e.g. `dms/main.kdl` or `noctalia/main.kdl`) into the `myconfigs/main.kdl` file.

```kdl
// ~/.config/niri/myconfigs/main.kdl

// Uncomment to enable the shell-specific settings
// include "dms/main.kdl"
include "noctalia/main.kdl" // uncommented to enable Noctalia-specifc settings
```

## Configs Structure

```
myconfigs/
├── dms/
│   ├── main.kdl                         # optionally imported from myconfigs/main.kdl to apply DankMaterialShell-specific niri configs
│   ├── startup.kdl                      # mainly spawns the dms shell process
│   └── window_rules.kdl                 # window rules for dms's own windows/panels
├── noctalia/
│   ├── hooks/                           # session hook scripts (shutdown, reboot, lock/unlock)
│   ├── scripts/                         # noctalia-specific helper scripts
│   ├── settings/noctalia-config.toml    # backup of noctalia's live settings file
│   ├── binds.kdl                        # noctalia-specific keybindings
│   ├── main.kdl                         # optionally imported from myconfigs/main.kdl to apply noctalia-specific niri configs
│   ├── misc.kdl                         # noctalia-specific misc settings
│   ├── startup.kdl                      # mainly spawns the noctalia shell process
│   └── window_rules.kdl                 # window rules for noctalia's own windows/panels
├── scripts/                             # standalone helper scripts available to binds/startup
│   └── linux-wallpaperengine-controller.sh
├── animations.kdl                       # compositor animation settings
├── binds.kdl                            # global keybindings
├── input.kdl                            # keyboard/mouse/touchpad input settings
├── layer_rules.kdl                      # rules for layer-shell surfaces (bars, launchers, etc.)
├── layout.kdl                           # window/column layout settings
├── main.kdl                             # imported from main niri config.kdl file to apply all the configs stored here
├── misc.kdl                             # misc settings (hot-corners, screenshot path, env vars)
├── outputs.kdl                          # per-monitor output settings
├── startup.kdl                          # commands spawned at niri startup
├── theme.kdl                            # colors/border/focus-ring theming
└── window_rules.kdl                     # per-app window rules
```
