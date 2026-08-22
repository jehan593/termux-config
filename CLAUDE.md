# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Termux (Android terminal emulator) dotfiles/config repo. Pure bash, no build system, no package manager, no test suite. Everything runs on-device inside Termux (`$PREFIX` = `/data/data/com.termux/files/usr`), not on a normal Linux host — many commands here (`termux-wallpaper`, `termux-setup-storage`, `sv`/`sv-enable` from `termux-services`, `am broadcast`, `cmd package`) only exist in that environment and cannot be run or tested from a regular shell.

## Commands

There is no build/lint/test tooling. The only "commands" are the scripts themselves:

```bash
bash setup.sh   # installs packages, symlinks dotfiles, enables services, sets wallpaper/font
bash reset.sh   # reverses setup.sh (interactive per-feature teardown)
```

Since there's no automated test suite, verify changes to shell scripts with `bash -n <script>` (syntax check) and manual reasoning; there's no CI in this repo to lean on.

## Architecture

**Two-layer script structure:**
- `helpers/*.sh` — sourced libraries, never executed directly. Each helper is named after what it backs (e.g. `wpm-helper.sh` backs `tools/wpm.sh`) and its functions are prefixed `_` (e.g. `_remove_wpm_tunnel`, `_blk_send_intent`). Helpers are shared between a `tools/*.sh` script and `reset.sh`, so the removal logic lives in exactly one place. Helpers are silent: they communicate via return codes and result variables (`_MISSING_DEPS`, `_DOT_LINKED`, ...) while callers own all colored output — necessary because `setup.sh`/`reset.sh` and `.bashrc`/`tools/*` use different palettes.
- `tools/*.sh` — user-facing CLIs. `setup.sh` symlinks every file under `tools/` into `$PREFIX/bin/<name>` (stripping `.sh`), so `tools/wpm.sh` becomes the `wpm` command, `tools/blk.sh` becomes `blk`, etc. Each follows the same `case "$1" in ...) ;; esac` subcommand-router pattern with a bare `_test_dependencies` guard near the top.

**Two color palettes, chosen by what's running when:**
- `helpers/colors-standard.sh` (plain ANSI codes) — used only by `setup.sh`/`reset.sh`, since those run before the Nord Termux theme is symlinked in (or after it's torn down).
- `helpers/colors-nord.sh` (truecolor escapes matching the Nord palette) — used by everything else (`.bashrc`, `tools/*.sh`), which only run once the Nord theme is already active.

All colored output goes through `printfc` (`helpers/printer.sh`): `printfc "$COLOR" "fmt" args...` (newline) or `printfc -n "$COLOR" "fmt" args...` (no newline, e.g. inline prompts).

**Config path propagation:** `setup.sh` writes `TERMUX_CONFIG_PATH` into `$PREFIX/etc/profile.d/termux_config.sh` so it's available system-wide (every new shell, and scripts invoked outside an interactive shell like boot scripts and `sv` services). Every `tools/*.sh` script sources its helpers via `$TERMUX_CONFIG_PATH/helpers/...`, not a relative path — so they only work correctly after `setup.sh` has run once.

**Dotfile linking (`setup.sh` step 2):** every file under `home/` is symlinked to the same relative path under `$HOME` (e.g. `home/.bashrc` → `~/.bashrc`, `home/.config/nvim/init.lua` → `~/.config/nvim/init.lua`). If a real (non-symlink) file already exists at the destination, it's backed up to `<dest>.bak` once; `reset.sh` restores from `.bak` when removing the symlink. This backup/restore pairing must be kept in sync between `setup.sh` and `reset.sh` — they walk the same `find "$CONFIG_PATH/home" -type f -print0` loop.

**reset.sh mirrors setup.sh's side effects in reverse**, feature by feature (symlinks → boot scripts/binaries → env var → wpm tunnels → yearwall → font cache → trash → services → nvim → blk). Several teardown steps are interactive opt-outs (wpm tunnels, yearwall, trash, SSH); if the user opts out, `reset.sh` sets a `kept_*` flag so the final "packages you can manually uninstall" summary and the shared boot-services script (`~/.termux/boot/10-services.sh`) aren't removed out from under a still-active feature. When adding a new feature with its own teardown, follow this pattern — add a `kept_<feature>` flag and account for it in the boot-script-cleanup and final-summary sections.

**Runtime-generated state** lives under `~/.config/termux-config-files/<tool>/` (e.g. `blk/config` holding an API key, `wpm/<name>.conf` proxy configs, `yearwall/yearwall_update.sh`), separate from the repo itself — never commit or assume the presence of anything there.

### Tool-specific notes

- **`tools/blk.sh` (`blk`)** — app blocker via broadcast intents to OwnDroid (`com.bintianqi.owndroid/.ApiReceiver`); requires an API key stored at `~/.config/termux-config-files/blk/config` (mode 600). `blk` (no args) opens an fzf multi-select blocklist manager; `blk key` sets the API key; `blk wa` toggles WhatsApp's Contacts permission.
- **`tools/wpm.sh` (`wpm`)** — manages wireproxy SOCKS5 tunnels as `runit` services (`$PREFIX/var/service/<name>-wpm`), each backed by a config at `~/.config/termux-config-files/wpm/<name>.conf`. Subcommands: `add <name> <conf> <port>`, `rm`, `start`/`stop`/`restart` (fzf multi-select), `ls`, `refresh`.
- **`tools/yearwall.sh` (`yearwall`)** — generates a lock-screen wallpaper showing year-progress as a dot grid via ImageMagick (`magick`), scheduled daily through `cronie`, re-applied on boot, and caught up via a `profile.d` drop-in (`$PREFIX/etc/profile.d/yearwall-catchup.sh`) that regenerates it on the next opened session if cron missed midnight (device off / Termux not running). Subcommands: `setup`, `status`, `rm`.

### `.bashrc` (`home/.bashrc`)

Sourced live via symlink (not copied), so edits here take effect on `reload` without re-running `setup.sh`. Guards on `_test_dependencies` for `starship`, `zoxide`, `nvim`, `fzf`, `fd`, `trash-put`/`trash-empty`, `termux-open-url` at the top — if any are missing, it falls back to a bare prompt and skips the rest of the file rather than erroring partway through. Defines the interactive shell functions (`sys`, `cup`/`upp`/`upall`/`upc`, `inst`/`uinst`, `cleanup`, `ff`, `_fhist` bound to Ctrl-H, `wa`, `tage`, `sz`, `trash`) and aliases used day-to-day; `sys` runs once at shell init and is re-run on every `clear`.
