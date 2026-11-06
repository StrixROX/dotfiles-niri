# rclone_mounts

Bar widget + tooltip + panel + headless service for rclone rc-managed VFS
mounts.

## Install (local dev source)

```sh
noctalia msg plugins source add dotfiles path ~/.config/niri/myconfigs/noctalia/plugins
noctalia msg plugins enable strixrox/rclone_mounts
```

Edits to `.luau` files hot-reload automatically; edit `plugin.toml` and run
`noctalia msg plugins update dotfiles` (or just toggle the plugin off/on)
to pick up manifest changes.

## Requires

- `rclone rcd` already running, started however you prefer (shell startup
  script, systemd user service, manually - this plugin doesn't start or
  manage it). Use `--rc-no-auth`: this is meant for localhost-only access,
  so skipping `--rc-user`/`--rc-pass` is fine and simpler; set them (and
  the matching `rc_user`/`rc_pass` settings below) only if you've chosen to
  expose rc beyond localhost. Example (how this setup's `rcd` is started,
  from `~/.config/niri/myconfigs/startup.kdl`):
  ```sh
  rclone rcd --rc-addr=http://127.0.0.1:5572 --rc-no-auth
  ```
- One of `zenity`, `kdialog`, or `yad` installed, for the panel's directory
  picker on "Add".

## Encrypted rclone.conf

No handling needed, and there's none here on purpose. Every rc call this
plugin makes (`operations/about`, `config/listremotes`, `mount/mount`, ...)
goes over `rclone rcd`'s already-running rc HTTP API via `noctalia.http` -
never a fresh `rclone` CLI subprocess. Whoever starts `rclone rcd` decrypts
the config once, at its own startup (`RCLONE_CONFIG_PASS` or
`--password-command`); every rc call after that, from this plugin or
anywhere else, reuses that same in-memory decrypted config. If `rcd` isn't
up or isn't decrypted, `core/pid` just fails and the plugin shows "rc
server unreachable".

## Settings (Settings → Plugins → gear icon)

- `rc_addr` (default `127.0.0.1:5572`)
- `rc_user` / `rc_pass` (blank = `--rc-no-auth`)
- `poll_seconds` (default 3)

## What it shows

- **Bar widget**: server glyph + count of mounted remotes.
- **Tooltip**: per mount, `name: mountpoint` then `cache: <mode>` below it,
  in `mount/listmounts` order (same order `rclone_status.sh` prints).
- **Panel**: remote dropdown + cache-mode dropdown (Full/Write/Minimal/Off,
  default Off) + max cache size (GiB) input + "Add" (picks a directory via
  zenity/kdialog/yad, mounts with the chosen options) above a tab bar (one
  tab per mount, same order) and that mount's details below:
  - **Mount Point** heading, path + **Unmount** button. Unmount shows an
    inline confirmation only when the mount's cache mode is `full` and it
    has active transfers (other cache modes unmount immediately - rclone
    resumes pending uploads from its VFS cache on the next mount either
    way).
  - **Remote Storage** (`rclone about` via `operations/about`), horizontal
    Used/Free/Total.
  - **VFS Cache** (mode, used/max, cache dir).
  - **Upload Queue** (queued/in-progress/errored counts, per mount).
  - **Transfers In Progress** - per-mount via `vfs/queue`'s `uploading`
    items, enriched with live percentage cross-referenced from the global
    `core/stats.transferring` list by filename.
  - **Completed Transfers (Global)** - `core/transferred` has no per-VFS
    scoping, so this one stays global across every mount's tab; heading row
    shows "Total: N" on the right.
  Only the details section scrolls; the add-row and tab bar stay pinned.
