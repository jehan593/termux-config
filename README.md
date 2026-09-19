# Termux Config

> FYI: This project is fully vibe coded.

Personal configuration and setup scripts for [Termux](https://termux.dev/), the Android terminal app. Installs packages, links configuration files, applies the Nord theme, and adds command-line tools.

## What it sets up

- **Configuration** — Bash, Neovim, Starship, Topgrade, and Termux settings, linked from `home/` into your home folder
- **Nord theme** — terminal colors and matching wallpaper
- **Services** — SSH and service startup scripts
- **Custom tools** (installed to `$PREFIX/bin`):
  - `wpm` — manage wireproxy SOCKS5 tunnels
  - `yearwall` — show year progress on your lock screen, updated daily
  - `shell` — access the Android shell through Shizuku. Run `shell setup` to configure it, `shell` to open it, or `shell scripts` to choose a bundled script

## Requirements

Termux on Android. `setup.sh` installs its own package dependencies; some tools need companion apps.

## Setup

```bash
git clone https://github.com/jehan593/termux-config.git ~/termux-config
cd ~/termux-config
bash setup.sh
```

## Reset

Removes configuration links and tools, restores available backups, and lets you choose whether to remove tunnels, wallpaper setup, and SSH startup. Packages must be uninstalled separately:

```bash
bash reset.sh
```
