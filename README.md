# Termux Config

Personal dotfiles and setup automation for [Termux](https://termux.dev/), the Android terminal emulator. Handles package installation, dotfile symlinking, Nord theming, and a few custom CLI tools — all in pure bash, no build system required.

## What it sets up

- **Dotfiles** — `.bashrc`, nvim config, starship prompt, topgrade, Termux color/property files, symlinked from `home/` into `$HOME`
- **Nord theme** — truecolor Termux styling and matching wallpaper
- **Boot & services** — `termux-services` boot scripts enabled on setup
- **Custom tools** (installed to `$PREFIX/bin`):
  - `blk` — app blocker via OwnDroid broadcast intents, with an fzf blocklist manager
  - `wpm` — wireproxy SOCKS5 tunnel manager, run as `runit` services
  - `yearwall` — daily-updating lock-screen wallpaper showing year progress as a dot grid

## Requirements

Termux on Android. `setup.sh` installs its own package dependencies; some tools need companion apps (e.g. OwnDroid for `blk`).

## Setup

```bash
git clone https://github.com/jehan593/termux-config.git ~/termux-config
cd ~/termux-config
bash setup.sh
```

## Reset

Reverses everything `setup.sh` did (dotfile symlinks, boot scripts, services, theme, tools), asking per-feature before removing anything with side effects (VPN tunnels, wallpaper, SSH):

```bash
bash reset.sh
```
