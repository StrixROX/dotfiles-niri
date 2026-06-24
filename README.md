# How to Use

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
// include "noctalia/main.kdl"
```
