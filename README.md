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
├── main.kdl                             # imported from main niri config.kdl file to apply all the configs stored here
├── input.kdl                            # keyboard/mouse/touchpad input settings
├── binds.kdl                            # global keybindings
├── layout.kdl                           # window/column layout settings
├── animations.kdl                       # compositor animation settings
├── theme.kdl                            # colors/border/focus-ring theming
├── outputs.kdl                          # per-monitor output settings
├── layer_rules.kdl                      # rules for layer-shell surfaces (bars, launchers, etc.)
├── window_rules.kdl                     # per-app window rules
├── misc.kdl                             # misc settings (hot-corners, screenshot path, env vars)
├── startup.kdl                          # commands spawned at niri startup
├── scripts/                             # standalone helper scripts available to binds/startup
│   └── linux-wallpaperengine-controller.sh
├── noctalia/
│   ├── main.kdl                         # optionally imported from myconfigs/main.kdl to apply noctalia-specific niri configs
│   ├── binds.kdl                        # noctalia-specific keybindings
│   ├── misc.kdl                         # noctalia-specific misc settings
│   ├── startup.kdl                      # mainly spawns the noctalia shell process
│   ├── window_rules.kdl                 # window rules for noctalia's own windows/panels
│   ├── settings/noctalia-config.toml    # backup of noctalia's live settings file
│   ├── hooks/                           # session hook scripts (shutdown, reboot, lock/unlock)
│   └── scripts/                         # noctalia-specific helper scripts
└── dms/
    ├── main.kdl                         # optionally imported from myconfigs/main.kdl to apply DankMaterialShell-specific niri configs
    ├── startup.kdl                      # mainly spawns the dms shell process
    └── window_rules.kdl                 # window rules for dms's own windows/panels
```
